<?php
/**
 * Личный кабинет iRepair — начисление кешбэка после закрытия заказа. Запуск только из командной строки (cron).
 *
 * Для каждого успешно закрытого заказа RemOnline (статусы из настройки accrual.statuses, закрыт не раньше accrual.since)
 * регистрирует продажу в BonusPlus на фактически оплаченную сумму (после скидки баллами). BonusPlus сам начисляет баллы
 * по своим правилам и учитывает сумму покупок для перехода на следующий уровень карты. Один заказ — одна продажа
 * (таблица irepair_lk_accruals, externalId = «RO-<id заказа>»).
 *
 *   php accrue.php                 — пробный прогон: ничего не меняет, показывает, что было бы начислено
 *   php accrue.php --run           — провести (работает только при accrual.enabled = true)
 *   php accrue.php --phone=79...   — только заказы одного клиента
 */
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
define('IREPAIR_LK', true);
date_default_timezone_set('Europe/Moscow');

$cfg = require __DIR__ . '/config.php';
$acc = $cfg['accrual'] ?? [];
$opts = getopt('', ['run', 'phone:']);
$run = isset($opts['run']);
if ($run && empty($acc['enabled'])) {
    fwrite(STDERR, "accrual.enabled = false — проведение выключено, возможен только пробный прогон\n");
    exit(1);
}
$pdo = new PDO(
    'mysql:host=' . $cfg['db']['host'] . ';dbname=' . $cfg['db']['name'] . ';charset=utf8mb4',
    $cfg['db']['user'],
    $cfg['db']['password'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
);

function acc_http(string $method, string $url, array $headers, ?array $json = null): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_CUSTOMREQUEST => $method, CURLOPT_HTTPHEADER => $headers, CURLOPT_CONNECTTIMEOUT => 8, CURLOPT_TIMEOUT => 25]);
    if ($json !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($json, JSON_UNESCAPED_UNICODE));
    }
    $resp = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    return [$code, is_string($resp) ? json_decode($resp, true) : null];
}
$ro = static fn(string $path): array => acc_http('GET', 'https://api.remonline.app/' . $path, ['accept: application/json', 'authorization: Bearer ' . $cfg['remonline']['token']]);
$bp = static fn(string $method, string $path, ?array $json = null): array => acc_http($method, 'https://bonusplus.pro/api/' . $path, ['Authorization: ApiKey ' . $cfg['bonusplus']['api_key'], 'Content-Type: application/json'], $json);
$phoneNorm = static function ($raw): ?string {
    $d = preg_replace('/\D+/', '', (string) $raw);
    $d = strlen($d) === 10 ? '7' . $d : (strlen($d) === 11 && $d[0] === '8' ? '7' . substr($d, 1) : $d);
    return preg_match('/^7[3489]\d{9}$/', $d) ? $d : null;
};

$since = strtotime((string) ($acc['since'] ?? '')) ?: time();
$statuses = array_map('intval', $acc['statuses'] ?? []);
$phones = isset($opts['phone']) ? [(string) $opts['phone']] : ($acc['only_phones'] ?? []);
if (!$phones) {
    // Режим «все клиенты» включается отдельно, после проверки отбора заказов по дате закрытия в RemOnline
    fwrite(STDERR, "accrual.only_phones пуст — режим для всех клиентов пока не включён\n");
    exit(1);
}

echo ($run ? 'ПРОВЕДЕНИЕ' : 'ПРОБНЫЙ ПРОГОН (ничего не меняется)') . ', заказы закрыты с ' . date('d.m.Y H:i', $since) . "\n";
$seen = $pdo->prepare('SELECT status FROM irepair_lk_accruals WHERE order_id = ?');
foreach ($phones as $phone) {
    $phone = $phoneNorm($phone);
    if (!$phone) {
        continue;
    }
    [$code, $r] = $ro('orders?client_phones=' . $phone);
    if ($code !== 200 || !is_array($r)) {
        echo "$phone: RemOnline не ответил ($code)\n";
        continue;
    }
    [$code, $cust] = $bp('GET', 'customer?phone=' . $phone);
    $card = is_array($cust) ? strtoupper((string) ($cust['discountCardName'] ?? '')) : '';
    if ($code !== 200 || $card === '') {
        echo "$phone: нет карты в BonusPlus — пропуск\n";
        continue;
    }
    $percent = (float) ($cfg['tiers'][$card]['cashback'] ?? 0);

    foreach ($r['data'] ?? [] as $o) {
        $id = (int) $o['id'];
        $closed = strtotime((string) ($o['closed_at'] ?? '')) ?: 0;
        $own = in_array($phone, array_map($phoneNorm, (array) ($o['client']['phone'] ?? [])), true);
        if (!$own || !in_array((int) $o['status']['id'], $statuses, true) || $closed < $since) {
            continue;
        }
        $seen->execute([$id]);
        if ($seen->fetchColumn()) {
            continue;                       // уже проведён (или в работе) — второй раз не трогаем
        }
        // позиции заказа: сумма к оплате по каждой = цена × количество − скидка
        [$code, $items] = $ro('orders/' . $id . '/items');
        $rows = [];
        foreach (($code === 200 && is_array($items)) ? ($items['data'] ?? $items) : [] as $it) {
            $sum = round((float) ($it['price'] ?? 0) * (float) ($it['quantity'] ?? 1) - (float) ($it['discount']['amount'] ?? 0), 2);
            if ($sum > 0) {
                $rows[] = ['sum' => $sum, 'qnt' => 1, 'product' => (string) ($it['entity']['title'] ?? 'Услуга')];
            }
        }
        $paid = array_sum(array_column($rows, 'sum'));
        if ($paid <= 0) {
            continue;
        }
        $expected = (int) floor($paid * $percent / 100);
        $body = ['phone' => $phone, 'items' => $rows, 'bonusDebit' => 0.0, 'externalId' => 'RO-' . $id, 'desc' => 'Заказ №' . $o['id_label'], 'date' => date('c', $closed)];
        [$code, $calc] = $bp('PUT', 'retail/calc', $body);
        $byRules = (int) array_sum(array_column($calc['discount'] ?? [], 'cb'));
        echo "Заказ №{$o['id_label']} ($phone, $card): оплачено $paid ₽; по программе {$percent}% = $expected баллов; BonusPlus по своим правилам начислит $byRules";
        if (!$run) {
            echo "\n";
            continue;
        }
        $pdo->prepare("INSERT INTO irepair_lk_accruals (order_id, phone, paid, bonus, status, created_at) VALUES (?, ?, ?, 0, 'pending', ?)")->execute([$id, $phone, $paid, time()]);
        [$code, $sale] = $bp('POST', 'retail', $body);
        $ok = $code >= 200 && $code < 300 && is_array($sale) && isset($sale['id']);
        $pdo->prepare('UPDATE irepair_lk_accruals SET status = ?, bonus = ?, sale_id = ? WHERE order_id = ?')->execute([$ok ? 'done' : 'review', $ok ? $byRules : 0, $ok ? (int) $sale['id'] : 0, $id]);
        echo $ok ? " → проведено, продажа {$sale['id']}\n" : " → ОШИБКА BonusPlus ($code), запись оставлена на разбор\n";
        if (!$ok) {
            error_log("[irepair-lk] начисление: заказ $id — BonusPlus ответил $code");
        }
    }
}
