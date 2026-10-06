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
date_default_timezone_set('Europe/Moscow');
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
            // номера приводим к одному виду (+7…, 8…, с пробелами и скобками → 7XXXXXXXXXX)
            $phones = array_map(static fn($p) => lk_phone((string) $p), (array) ($o['client']['phone'] ?? []));
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

/**
 * Статусы заказов RemOnline: id → группа (1 новый, 2 в работе, 3 ожидание, 4 готов, 5 доставка, 6 закрыт успешно, 7 закрыт неуспешно).
 * Список меняется редко — храним сутки в базе.
 */
function lk_status_groups(): array
{
    global $pdo, $now;
    $st = $pdo->prepare("SELECT v FROM irepair_lk_cache WHERE k = 'status_groups' AND expires_at > ?");
    $st->execute([$now]);
    $cached = json_decode((string) $st->fetchColumn(), true);
    if (is_array($cached) && $cached) {
        return $cached;
    }
    [$code, $r] = lk_ro('GET', 'statuses/');
    $map = [];
    foreach (($code === 200 && is_array($r)) ? ($r['data'] ?? $r) : [] as $row) {
        if (is_array($row) && isset($row['id'])) {
            $map[(int) $row['id']] = (int) ($row['group'] ?? 0);
        }
    }
    if ($map) {
        $pdo->prepare("REPLACE INTO irepair_lk_cache (k, v, expires_at) VALUES ('status_groups', ?, ?)")->execute([json_encode($map), $now + 86400]);
    }
    return $map;
}

function lk_ts($v): int
{
    if ($v === null || $v === '') {
        return 0;
    }
    return (int) (is_numeric($v) ? ($v > 100000000000 ? $v / 1000 : $v) : strtotime((string) $v));
}

function lk_date($v): string
{
    $ts = lk_ts($v);
    return $ts ? date('d.m.Y', $ts) : '';
}

/** 1 месяц, 3 месяца, 6 месяцев */
function lk_plural(int $n, array $forms): string
{
    $a = abs($n) % 100;
    $b = $a % 10;
    return $n . ' ' . ($a > 10 && $a < 20 ? $forms[2] : ($b === 1 ? $forms[0] : ($b >= 2 && $b <= 4 ? $forms[1] : $forms[2])));
}

/**
 * Гарантия на позицию заказа по-русски. Если заказ закрыт — ещё и срок: с даты закрытия заказа по дату окончания.
 * RemOnline отдаёт period + period_units (days / weeks / months / years).
 */
function lk_warranty($w, int $closedTs): array
{
    $period = (int) (is_array($w) ? ($w['period'] ?? 0) : 0);
    $unit = strtolower((string) (is_array($w) ? ($w['period_units'] ?? '') : ''));
    $forms = ['day' => ['день', 'дня', 'дней'], 'week' => ['неделя', 'недели', 'недель'], 'month' => ['месяц', 'месяца', 'месяцев'], 'year' => ['год', 'года', 'лет']];
    $key = rtrim($unit, 's');
    if ($period <= 0 || !isset($forms[$key])) {
        return ['text' => '', 'from' => '', 'to' => '', 'active' => null];
    }
    $out = ['text' => lk_plural($period, $forms[$key]), 'from' => '', 'to' => '', 'active' => null];
    if ($closedTs) {
        $end = (new DateTime('@' . $closedTs))->setTimezone(new DateTimeZone('Europe/Moscow'))->modify('+' . $period . ' ' . $key);
        $out['from'] = date('d.m.Y', $closedTs);
        $out['to'] = $end->format('d.m.Y');
        $out['active'] = $end->format('Y-m-d') >= date('Y-m-d');
    }
    return $out;
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

        // Заказы, по которым списание не завершено (идёт или ждёт разбора менеджером)
        $locked = [];
        if ($ids) {
            $st = $pdo->prepare("SELECT order_id, status FROM irepair_lk_spend_lock WHERE status IN ('pending', 'review') AND order_id IN (" . implode(',', array_fill(0, count($ids), '?')) . ')');
            $st->execute($ids);
            foreach ($st as $h) {
                $locked[(int) $h['order_id']] = $h['status'];
            }
        }

        $groups = $raw ? lk_status_groups() : [];
        $current = $history = $map = [];
        foreach ($raw ?? [] as $o) {
            $id = (int) ($o['id'] ?? 0);
            $statusId = (int) ($o['status']['id'] ?? 0);
            $price = (float) ($o['price'] ?? 0);
            $group = (int) ($groups[$statusId] ?? 0);
            // в «Историю»: статусы из настроек (как на старом сайте) и все закрытые заказы по группе статуса
            $closed = in_array($statusId, $cfg['closed_statuses'], true) || in_array($group, $cfg['closed_groups'] ?? [], true);
            $item = [
                'id' => $id,
                'label' => (string) ($o['id_label'] ?? $id),
                'price' => (int) round($price),
                'date' => lk_date($o['created_at'] ?? null),
                'closed' => lk_date($o['closed_at'] ?? null),
                'device' => trim((string) ($o['custom_fields'][$cfg['device_field']] ?? '')),
                // названия статусов в RemOnline служебные («ПРИМЕНИТЬ СКИДКУ!», «Создать заказ в МС») — клиенту показываем
                // понятную подпись по группе статуса; если группы нет — название без приставки («С | Готов» → «Готов»)
                'status' => $cfg['status_labels'][$group] ?? trim((string) preg_replace('/^.{1,3}\|\s*/u', '', (string) ($o['status']['name'] ?? ''))),
                'cashback' => (int) floor($price * $bonus['cashback_percent'] / 100),
                'spent' => $spent[$id] ?? 0,
            ];
            if ($closed) {
                $history[] = $item;
            } else {
                $item['available'] = isset($spent[$id]) ? 0 : (int) min(floor($price * $bonus['debit_percent'] / 100), $bonus['points']);
                $item['can_spend'] = !empty($cfg['spend_enabled']) && $statusId === (int) $cfg['spend_status'] && !isset($spent[$id]) && !isset($locked[$id]) && $item['available'] > 0;
                $item['spend_review'] = isset($locked[$id]);
                $current[] = $item;
            }
            // по этому списку проверяется доступ к заказу; дата закрытия нужна для срока гарантии (отказы — без гарантии)
            $map[$id] = ['s' => $statusId, 'c' => $group === 7 ? 0 : lk_ts($o['closed_at'] ?? null)];
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
                'warranty' => lk_warranty($it['warranty'] ?? null, (int) ($own[$orderId]['c'] ?? 0)),
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
        /*
         * Состояние операции хранится в irepair_lk_spend_lock.status:
         *   pending — идёт сейчас (или оборвалась посередине);
         *   done    — баллы списаны, скидка стоит;
         *   failed  — не получилось, скидка снята, можно повторить;
         *   review  — итог неизвестен (скидка могла остаться, баллы могли списаться) → разбирает менеджер.
         * Успех клиенту показываем только после подтверждения BonusPlus.
         */
        $setState = static function (string $status, int $amount = 0, array $applied = []) use ($pdo, $orderId, $now): void {
            $pdo->prepare('UPDATE irepair_lk_spend_lock SET status = ?, amount = ?, items_json = ?, updated_at = ? WHERE order_id = ?')
                ->execute([$status, $amount, json_encode($applied), $now, $orderId]);
        };
        try {
            $pdo->prepare("INSERT INTO irepair_lk_spend_lock (order_id, phone, status, created_at, updated_at) VALUES (?, ?, 'pending', ?, ?)")->execute([$orderId, $phone, $now, $now]);
        } catch (PDOException $e) {
            // повтор разрешён только после неудачи с полностью снятой скидкой
            $st = $pdo->prepare("UPDATE irepair_lk_spend_lock SET status = 'pending', phone = ?, updated_at = ? WHERE order_id = ? AND status = 'failed'");
            $st->execute([$phone, $now, $orderId]);
            if ($st->rowCount() !== 1) {
                $st = $pdo->prepare('SELECT status FROM irepair_lk_spend_lock WHERE order_id = ?');
                $st->execute([$orderId]);
                lk_fail($st->fetchColumn() === 'done' ? 'already' : 'review', 409);
            }
        }

        $bonus = lk_bonus_info($phone);
        [$code, $r] = lk_ro('GET', 'orders/' . $orderId . '/items');
        $items = ($code === 200 && is_array($r)) ? ($r['data'] ?? $r) : null;
        if (!$bonus['found'] || $bonus['points'] <= 0 || !$items) {
            $setState('failed');
            lk_fail($items ? 'no_points' : 'service', $items ? 409 : 502);
        }

        // 1. Скидка на позиции заказа в RemOnline. Что применили — сразу записываем, чтобы след остался при любом сбое
        $left = $bonus['points'];
        $total = 0;
        $applied = $retail = [];
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
            $left -= $amount;
            $total += $amount;
            $applied[] = ['item_id' => (int) $it['id'], 'amount' => $amount];
            $retail[] = ['sum' => (float) ceil($price), 'qnt' => 1, 'product' => (string) ($it['entity']['title'] ?? '')];
            $setState('pending', $total, $applied);
        }
        if ($total <= 0) {
            $setState('failed');
            lk_fail('service', 502);
        }

        // 2. Списание баллов в BonusPlus. Нет ясного ответа (ошибка, таймаут) — сверяем по остатку баллов
        [$code, $res] = lk_bonusplus('POST', 'retail', ['phone' => $phone, 'items' => $retail, 'bonusDebit' => (float) $total]);
        $confirmed = $code >= 200 && $code < 300;
        $unknown = false;
        if (!$confirmed) {
            lk_log("списание: заказ $orderId, $total баллов — BonusPlus ответил $code: " . mb_substr(json_encode($res, JSON_UNESCAPED_UNICODE) ?: '', 0, 300));
            $after = lk_bonus_info($phone);
            if (!$after['found']) {
                $unknown = true;                                   // остаток узнать не удалось
            } elseif ($after['points'] <= $bonus['points'] - $total) {
                $confirmed = true;                                 // баллы всё-таки списаны
            }
        }

        if ($confirmed) {
            $hist = $pdo->prepare('INSERT INTO irepair_lk_bonus_history (order_id, item_id, amount, phone, created_at) VALUES (?, ?, ?, ?, ?)');
            foreach ($applied as $a) {
                $hist->execute([$orderId, $a['item_id'], $a['amount'], $phone, $now]);
            }
            $setState('done', $total, $applied);
            lk_out(['ok' => true, 'spent' => $total]);
        }
        if ($unknown) {
            $setState('review', $total, $applied);
            lk_log("списание: заказ $orderId — итог неизвестен, нужен разбор (скидка $total р стоит в RemOnline)");
            lk_fail('review', 502);
        }

        // 3. Баллы не списаны → снимаем скидку в RemOnline
        $reverted = true;
        foreach ($applied as $a) {
            [$code, $res] = lk_ro('PATCH', 'orders/' . $orderId . '/items/' . $a['item_id'], [
                'discount' => ['type' => 'value', 'sponsor' => 'company', 'amount' => 0],
                'comment' => 'Списание бонусов отменено',
            ]);
            if (!is_array($res) || !isset($res['id'])) {
                $reverted = false;
                lk_log("списание: заказ $orderId, позиция {$a['item_id']} — скидку снять не удалось, RemOnline ответил $code");
            }
        }
        $setState($reverted ? 'failed' : 'review', $reverted ? 0 : $total, $reverted ? [] : $applied);
        lk_fail($reverted ? 'bonus_failed' : 'review', 502);

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
