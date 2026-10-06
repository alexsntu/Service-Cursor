<?php
/**
 * Личный кабинет iRepair — серверная часть. На сервере: /ajax/lk/api.php
 *
 * Повторяет кабинет старого сайта (OpenCart: account/login + account/account):
 *   вход по коду из СМС (sms.ru) → только для клиентов, которые есть в RemOnline;
 *   бонусы и уровень карты — BonusPlus; заказы и состав заказа — RemOnline;
 *   «Списать баллы» — скидка на позиции заказа в RemOnline + продажа со списанием в BonusPlus.
 *
 * Все ключи и доступ к базе — в config.php рядом (в git не попадает, образец: config.sample.php).
 * Принимает только POST с заголовком X-Requested-With: irepair-lk, отвечает JSON.
 */
declare(strict_types=1);

define('IREPAIR_LK', true);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');

const LK_COOKIE = 'irepair_lk';
const LK_OTP_TTL = 300;          // код живёт 5 минут
const LK_OTP_ATTEMPTS = 5;       // попыток ввода на один код
const LK_RESEND_WAIT = 60;       // пауза между СМС на один номер
const LK_SMS_PER_PHONE_HOUR = 4;
const LK_SMS_PER_PHONE_DAY = 8;
const LK_REQ_PER_IP_HOUR = 20;   // запросов кода с одного IP (включая «не найден»)
const LK_SESSION_TTL = 2592000;  // 30 дней

function lk_out(array $data, int $code = 200): void
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function lk_fail(string $error, int $code = 400, array $extra = []): void
{
    lk_out(['ok' => false, 'error' => $error] + $extra, $code);
}

function lk_log(string $msg): void
{
    error_log('[irepair-lk] ' . $msg);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST' || ($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') !== 'irepair-lk') {
    lk_fail('bad_request', 400);
}
// Запросы только со своего сайта
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '' && parse_url($origin, PHP_URL_HOST) !== preg_replace('/:\d+$/', '', $_SERVER['HTTP_HOST'] ?? '')) {
    lk_fail('bad_origin', 403);
}

$cfg = @include __DIR__ . '/config.php';
if (!is_array($cfg)) {
    lk_log('нет config.php');
    lk_fail('not_configured', 503);
}

try {
    $pdo = new PDO(
        'mysql:host=' . $cfg['db']['host'] . ';dbname=' . $cfg['db']['name'] . ';charset=utf8mb4',
        $cfg['db']['user'],
        $cfg['db']['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES => false]
    );
} catch (Throwable $e) {
    lk_log('база: ' . $e->getMessage());
    lk_fail('server', 503);
}

$now = time();
$ip = $_SERVER['REMOTE_ADDR'] ?? '';

/* ---------- общие функции ---------- */

function lk_phone(string $raw): ?string
{
    $d = preg_replace('/\D+/', '', $raw);
    if (strlen($d) === 10) {
        $d = '7' . $d;
    } elseif (strlen($d) === 11 && $d[0] === '8') {
        $d = '7' . substr($d, 1);
    }
    return preg_match('/^7[3489]\d{9}$/', $d) ? $d : null;
}

/** HTTP-запрос к внешнему сервису. Возвращает [код ответа, разобранный JSON|null]. */
function lk_http(string $method, string $url, array $headers = [], ?string $body = null): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    }
    $resp = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    if ($resp === false) {
        lk_log("$method " . preg_replace('/\?.*/', '', $url) . ': ' . curl_error($ch));
    }
    curl_close($ch);
    return [$code, is_string($resp) ? json_decode($resp, true) : null];
}

function lk_ro(string $method, string $path, ?array $json = null): array
{
    global $cfg;
    $headers = ['accept: application/json', 'authorization: Bearer ' . $cfg['remonline']['token']];
    if ($json !== null) {
        $headers[] = 'content-type: application/json';
    }
    return lk_http($method, 'https://api.remonline.app/' . $path, $headers, $json === null ? null : json_encode($json, JSON_UNESCAPED_UNICODE));
}

function lk_bonusplus(string $method, string $path, ?array $json = null): array
{
    global $cfg;
    return lk_http(
        $method,
        'https://bonusplus.pro/api/' . $path,
        ['Authorization: ApiKey ' . $cfg['bonusplus']['api_key'], 'Content-Type: application/json'],
        $json === null ? null : json_encode($json, JSON_UNESCAPED_UNICODE)
    );
}

/** Уровень карты, баллы и проценты клиента из BonusPlus. */
function lk_bonus_info(string $phone): array
{
    global $cfg;
    [$code, $r] = lk_bonusplus('GET', 'customer?phone=' . $phone);
    $card = is_array($r) ? strtoupper(trim((string) ($r['discountCardName'] ?? ''))) : '';
    $tier = $cfg['tiers'][$card] ?? $cfg['tiers']['SILVER'];
    $debit = is_array($r) && isset($r['baseBonusDebitPercent']) ? (float) $r['baseBonusDebitPercent'] : (float) $tier['debit'];
    return [
        'found' => $code === 200 && is_array($r) && $card !== '',
        'card' => $card,
        'points' => is_array($r) ? (int) floor((float) ($r['availableBonuses'] ?? 0)) : 0,
        'cashback_percent' => (float) $tier['cashback'],
        'debit_percent' => $debit,
    ];
}

/** Все заказы клиента из RemOnline (до 6 страниц по 50). null — сервис не ответил. */
function lk_ro_orders(string $phone): ?array
{
    $all = [];
    for ($page = 1; $page <= 6; $page++) {
        [$code, $r] = lk_ro('GET', 'orders?client_phones=' . $phone . '&page=' . $page);
        if ($code !== 200 || !is_array($r)) {
            return $page === 1 ? null : $all;
        }
        $rows = $r['data'] ?? [];
        foreach ($rows as $o) {
            // RemOnline молча игнорирует незнакомый фильтр и отдаёт заказы всех клиентов — поэтому сверяем телефон
            $phones = array_map(static fn($p) => preg_replace('/\D+/', '', (string) $p), (array) ($o['client']['phone'] ?? []));
            if (in_array($phone, $phones, true)) {
                $all[] = $o;
            }
        }
        if (count($rows) < 50 || $page * 50 >= (int) ($r['count'] ?? 0)) {
            break;
        }
    }
    return $all;
}

function lk_date($v): string
{
    if ($v === null || $v === '') {
        return '';
    }
    $ts = is_numeric($v) ? (int) ($v > 100000000000 ? $v / 1000 : $v) : strtotime((string) $v);
    return $ts ? date('d.m.Y', $ts) : '';
}

function lk_session(): ?array
{
    global $pdo, $now;
    $token = $_COOKIE[LK_COOKIE] ?? '';
    if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
        return null;
    }
    $st = $pdo->prepare('SELECT * FROM irepair_lk_sessions WHERE token_hash = ? AND expires_at > ?');
    $st->execute([hash('sha256', $token), $now]);
    return $st->fetch() ?: null;
}

function lk_cookie(string $value, int $expires): void
{
    setcookie(LK_COOKIE, $value, ['expires' => $expires, 'path' => '/', 'secure' => true, 'httponly' => true, 'samesite' => 'Lax']);
}

function lk_require_session(): array
{
    $s = lk_session();
    if (!$s) {
        lk_fail('auth', 401);
    }
    return $s;
}

/* ---------- действия ---------- */

$action = (string) ($_POST['action'] ?? '');

// Редкая уборка просроченного
if (random_int(1, 50) === 1) {
    $pdo->prepare('DELETE FROM irepair_lk_sessions WHERE expires_at < ?')->execute([$now]);
    $pdo->prepare('DELETE FROM irepair_lk_otp WHERE expires_at < ?')->execute([$now - 3600]);
    $pdo->prepare('DELETE FROM irepair_lk_sms_log WHERE created_at < ?')->execute([$now - 172800]);
}

switch ($action) {

    /* Шаг 1: телефон → проверка в RemOnline → СМС с кодом */
    case 'send_code':
        $phone = lk_phone((string) ($_POST['phone'] ?? ''));
        if (!$phone) {
            lk_fail('bad_phone');
        }
        $cnt = function (string $where, array $args) use ($pdo): int {
            $st = $pdo->prepare('SELECT COUNT(*) FROM irepair_lk_sms_log WHERE ' . $where);
            $st->execute($args);
            return (int) $st->fetchColumn();
        };
        if ($cnt('ip = ? AND created_at > ?', [$ip, $now - 3600]) >= LK_REQ_PER_IP_HOUR) {
            lk_fail('too_many', 429);
        }
        $st = $pdo->prepare('SELECT MAX(created_at) FROM irepair_lk_sms_log WHERE phone = ? AND sent = 1');
        $st->execute([$phone]);
        $last = (int) $st->fetchColumn();
        if ($last && $now - $last < LK_RESEND_WAIT) {
            lk_fail('wait', 429, ['wait' => LK_RESEND_WAIT - ($now - $last)]);
        }
        if ($cnt('phone = ? AND sent = 1 AND created_at > ?', [$phone, $now - 3600]) >= LK_SMS_PER_PHONE_HOUR
            || $cnt('phone = ? AND sent = 1 AND created_at > ?', [$phone, $now - 86400]) >= LK_SMS_PER_PHONE_DAY) {
            lk_fail('too_many', 429);
        }
        $log = $pdo->prepare('INSERT INTO irepair_lk_sms_log (phone, ip, sent, created_at) VALUES (?, ?, ?, ?)');

        [$code, $r] = lk_ro('GET', 'clients/?phones[]=' . $phone);
        if ($code !== 200 || !is_array($r)) {
            lk_fail('service', 502);
        }
        $client = $r['data'][0] ?? null;
        if (!$client) {
            $log->execute([$phone, $ip, 0, $now]);
            lk_out(['ok' => true, 'status' => 'not_found']);
        }

        $first = trim((string) ($client['first_name'] ?? ''));
        $lastName = trim((string) ($client['last_name'] ?? ''));
        if ($first === '' && $lastName === '') {
            $first = trim((string) ($client['name'] ?? ''));
        }
        $pdo->prepare(
            'INSERT INTO irepair_lk_clients (phone, ro_client_id, first_name, last_name, email, created_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE ro_client_id = VALUES(ro_client_id), first_name = VALUES(first_name), last_name = VALUES(last_name)'
        )->execute([$phone, (int) ($client['id'] ?? 0), mb_substr($first, 0, 100), mb_substr($lastName, 0, 100), mb_substr(trim((string) ($client['email'] ?? '')), 0, 190), $now]);

        $otp = (string) random_int(1000, 9999);
        $msg = 'Ваш код для входа: ' . $otp . "\n\n@" . $cfg['otp_domain'] . ' #' . $otp;
        [$code, $sms] = lk_http('POST', 'https://sms.ru/sms/send', [], http_build_query(['api_id' => $cfg['smsru']['api_id'], 'to' => $phone, 'msg' => $msg, 'json' => 1]));
        if (!is_array($sms) || ($sms['status'] ?? '') !== 'OK' || ($sms['sms'][$phone]['status'] ?? '') !== 'OK') {
            lk_log('sms.ru: ' . json_encode(['http' => $code, 'status' => $sms['status'] ?? null, 'code' => $sms['sms'][$phone]['status_code'] ?? ($sms['status_code'] ?? null)]));
            lk_fail('sms', 502);
        }
        $log->execute([$phone, $ip, 1, $now]);
        $pdo->prepare('REPLACE INTO irepair_lk_otp (phone, code_hash, attempts, expires_at) VALUES (?, ?, 0, ?)')
            ->execute([$phone, hash_hmac('sha256', $phone . ':' . $otp, $cfg['secret']), $now + LK_OTP_TTL]);
        lk_out(['ok' => true, 'status' => 'sent', 'phone' => '+' . $phone, 'wait' => LK_RESEND_WAIT]);

    /* Шаг 2: код из СМС → вход */
    case 'check_code':
        $phone = lk_phone((string) ($_POST['phone'] ?? ''));
        $code = preg_replace('/\D+/', '', (string) ($_POST['code'] ?? ''));
        if (!$phone || strlen($code) !== 4) {
            lk_fail('bad_code');
        }
        $st = $pdo->prepare('SELECT * FROM irepair_lk_otp WHERE phone = ?');
        $st->execute([$phone]);
        $row = $st->fetch();
        if (!$row || $row['expires_at'] < $now || $row['attempts'] >= LK_OTP_ATTEMPTS) {
            lk_fail('code_expired');
        }
        if (!hash_equals($row['code_hash'], hash_hmac('sha256', $phone . ':' . $code, $cfg['secret']))) {
            $pdo->prepare('UPDATE irepair_lk_otp SET attempts = attempts + 1 WHERE phone = ?')->execute([$phone]);
            lk_fail($row['attempts'] + 1 >= LK_OTP_ATTEMPTS ? 'code_expired' : 'bad_code');
        }
        $pdo->prepare('DELETE FROM irepair_lk_otp WHERE phone = ?')->execute([$phone]);
        $token = bin2hex(random_bytes(32));
        $pdo->prepare('INSERT INTO irepair_lk_sessions (token_hash, phone, ip, created_at, expires_at) VALUES (?, ?, ?, ?, ?)')
            ->execute([hash('sha256', $token), $phone, $ip, $now, $now + LK_SESSION_TTL]);
        $pdo->prepare('UPDATE irepair_lk_clients SET last_login_at = ? WHERE phone = ?')->execute([$now, $phone]);
        lk_cookie($token, $now + LK_SESSION_TTL);
        lk_out(['ok' => true]);

    /* Данные кабинета: профиль, карта, заказы */
    case 'me':
        $s = lk_session();
        if (!$s) {
            lk_out(['ok' => true, 'auth' => false]);
        }
        $phone = $s['phone'];
        $st = $pdo->prepare('SELECT * FROM irepair_lk_clients WHERE phone = ?');
        $st->execute([$phone]);
        $c = $st->fetch() ?: [];

        $bonus = lk_bonus_info($phone);
        $raw = lk_ro_orders($phone);

        $spent = [];
        $ids = array_map(static fn($o) => (int) ($o['id'] ?? 0), $raw ?? []);
        if ($ids) {
            $st = $pdo->prepare('SELECT order_id, SUM(amount) s FROM irepair_lk_bonus_history WHERE order_id IN (' . implode(',', array_fill(0, count($ids), '?')) . ') GROUP BY order_id');
            $st->execute($ids);
            foreach ($st as $h) {
                $spent[(int) $h['order_id']] = (int) $h['s'];
            }
        }

        $current = $history = $map = [];
        foreach ($raw ?? [] as $o) {
            $id = (int) ($o['id'] ?? 0);
            $statusId = (int) ($o['status']['id'] ?? 0);
            $price = (float) ($o['price'] ?? 0);
            $closed = in_array($statusId, $cfg['closed_statuses'], true);
            $item = [
                'id' => $id,
                'label' => (string) ($o['id_label'] ?? $id),
                'price' => (int) round($price),
                'date' => lk_date($o['created_at'] ?? null),
                'device' => trim((string) ($o['custom_fields'][$cfg['device_field']] ?? '')),
                // у статусов в RemOnline служебная приставка («С | Готов») — клиенту показываем без неё
                'status' => trim((string) preg_replace('/^.{1,3}\|\s*/u', '', (string) ($o['status']['name'] ?? ''))),
                'cashback' => (int) floor($price * $bonus['cashback_percent'] / 100),
                'spent' => $spent[$id] ?? 0,
            ];
            if ($closed) {
                $history[] = $item;
            } else {
                $item['available'] = isset($spent[$id]) ? 0 : (int) min(floor($price * $bonus['debit_percent'] / 100), $bonus['points']);
                $item['can_spend'] = !empty($cfg['spend_enabled']) && $statusId === (int) $cfg['spend_status'] && !isset($spent[$id]) && $item['available'] > 0;
                $current[] = $item;
            }
            $map[$id] = $statusId;
        }
        $pdo->prepare('UPDATE irepair_lk_sessions SET orders_json = ? WHERE token_hash = ?')->execute([json_encode($map), $s['token_hash']]);

        lk_out([
            'ok' => true,
            'auth' => true,
            'profile' => [
                'first_name' => $c['first_name'] ?? '',
                'last_name' => $c['last_name'] ?? '',
                'phone' => '+' . $phone,
                'email' => $c['email'] ?? '',
                'gender' => $c['gender'] ?? '',
                'birthday' => $c['birthday'] ?? '',
            ],
            'bonus' => $bonus,
            'orders_ok' => $raw !== null,
            'orders' => $current,
            'history' => $history,
        ]);

    /* Состав заказа (только своего) */
    case 'order_items':
        $s = lk_require_session();
        $orderId = (int) ($_POST['order_id'] ?? 0);
        $own = json_decode((string) ($s['orders_json'] ?? ''), true) ?: [];
        if (!$orderId || !array_key_exists($orderId, $own)) {
            lk_fail('not_found', 404);
        }
        [$code, $r] = lk_ro('GET', 'orders/' . $orderId . '/items');
        if ($code !== 200 || !is_array($r)) {
            lk_fail('service', 502);
        }
        $items = [];
        foreach (($r['data'] ?? $r) as $it) {
            if (!is_array($it)) {
                continue;
            }
            $items[] = [
                'title' => (string) ($it['entity']['title'] ?? ''),
                'warranty' => trim(($it['warranty']['period'] ?? '') . ' ' . ($it['warranty']['period_units'] ?? '')),
                'price' => (int) round((float) ($it['price'] ?? 0)),
            ];
        }
        lk_out(['ok' => true, 'items' => $items]);

    /* Списание баллов в счёт заказа */
    case 'spend_bonus':
        $s = lk_require_session();
        if (empty($cfg['spend_enabled'])) {
            lk_fail('disabled', 403);
        }
        $phone = $s['phone'];
        $orderId = (int) ($_POST['order_id'] ?? 0);
        // Заказ и его статус проверяем заново, не по данным из браузера
        $order = null;
        foreach (lk_ro_orders($phone) ?? [] as $o) {
            if ((int) ($o['id'] ?? 0) === $orderId) {
                $order = $o;
                break;
            }
        }
        if (!$orderId || !$order) {
            lk_fail('not_found', 404);
        }
        if ((int) ($order['status']['id'] ?? 0) !== (int) $cfg['spend_status']) {
            lk_fail('bad_status', 409);
        }
        // Один заказ — одно списание: строка-замок с уникальным order_id
        try {
            $pdo->prepare('INSERT INTO irepair_lk_spend_lock (order_id, phone, created_at) VALUES (?, ?, ?)')->execute([$orderId, $phone, $now]);
        } catch (PDOException $e) {
            lk_fail('already', 409);
        }
        $unlock = static function () use ($pdo, $orderId): void {
            $pdo->prepare('DELETE FROM irepair_lk_spend_lock WHERE order_id = ?')->execute([$orderId]);
        };

        $bonus = lk_bonus_info($phone);
        [$code, $r] = lk_ro('GET', 'orders/' . $orderId . '/items');
        $items = ($code === 200 && is_array($r)) ? ($r['data'] ?? $r) : null;
        if (!$bonus['found'] || $bonus['points'] <= 0 || !$items) {
            $unlock();
            lk_fail($items ? 'no_points' : 'service', $items ? 409 : 502);
        }

        $left = $bonus['points'];
        $total = 0;
        $retail = [];
        $hist = $pdo->prepare('INSERT INTO irepair_lk_bonus_history (order_id, item_id, amount, phone, created_at) VALUES (?, ?, ?, ?, ?)');
        foreach ($items as $it) {
            if (!is_array($it) || $left <= 0) {
                continue;
            }
            $price = (float) ($it['price'] ?? 0);
            $amount = (int) min(round($price * $bonus['debit_percent'] / 100), $left);
            if ($amount <= 0) {
                continue;
            }
            [$code, $res] = lk_ro('PATCH', 'orders/' . $orderId . '/items/' . (int) $it['id'], [
                'discount' => ['type' => 'value', 'sponsor' => 'company', 'amount' => $amount],
                'comment' => 'Списали ' . $amount . ' р в счет бонусов',
            ]);
            if (!is_array($res) || !isset($res['id'])) {
                lk_log("списание: заказ $orderId, позиция " . (int) $it['id'] . ", RemOnline ответил $code");
                continue;
            }
            $hist->execute([$orderId, (int) $it['id'], $amount, $phone, $now]);
            $left -= $amount;
            $total += $amount;
            $retail[] = ['sum' => (float) ceil($price), 'qnt' => 1, 'product' => (string) ($it['entity']['title'] ?? '')];
        }
        if ($total <= 0) {
            $unlock();
            lk_fail('service', 502);
        }
        // Баллы со счёта снимает BonusPlus. Скидка в RemOnline уже стоит, поэтому при сбое — только запись в журнал.
        [$code, $res] = lk_bonusplus('POST', 'retail', ['phone' => $phone, 'items' => $retail, 'bonusDebit' => (float) $total]);
        if ($code < 200 || $code >= 300) {
            lk_log("списание: заказ $orderId, $total баллов — BonusPlus ответил $code: " . mb_substr(json_encode($res, JSON_UNESCAPED_UNICODE) ?: '', 0, 300));
        }
        lk_out(['ok' => true, 'spent' => $total, 'bonusplus_ok' => $code >= 200 && $code < 300]);

    /* Личные данные */
    case 'save_profile':
        $s = lk_require_session();
        $email = trim((string) ($_POST['email'] ?? ''));
        $gender = (string) ($_POST['gender'] ?? '');
        $birthday = trim((string) ($_POST['birthday'] ?? ''));
        if ($email !== '' && (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 190)) {
            lk_fail('bad_email');
        }
        if (!in_array($gender, ['', 'M', 'F'], true)) {
            lk_fail('bad_gender');
        }
        if ($birthday !== '') {
            $d = DateTime::createFromFormat('!Y-m-d', $birthday);
            if (!$d || $d->format('Y-m-d') !== $birthday || $d->getTimestamp() > $now || (int) $d->format('Y') < 1900) {
                lk_fail('bad_birthday');
            }
        }
        $pdo->prepare('UPDATE irepair_lk_clients SET email = ?, gender = ?, birthday = ? WHERE phone = ?')
            ->execute([$email, $gender, $birthday === '' ? null : $birthday, $s['phone']]);
        lk_out(['ok' => true]);

    case 'logout':
        $s = lk_session();
        if ($s) {
            $pdo->prepare('DELETE FROM irepair_lk_sessions WHERE token_hash = ?')->execute([$s['token_hash']]);
        }
        lk_cookie('', $now - 3600);
        lk_out(['ok' => true]);

    default:
        lk_fail('bad_action');
}
