<?php
/**
 * iRepair: ежедневное обновление цен услуг сайта из RemOnline (RO App). На сервере: /ajax/price-sync.php.
 * Только из командной строки (из браузера — 404).
 *
 *   php price-sync.php            пробный прогон: показывает, что изменилось бы, ничего не меняет
 *   php price-sync.php --run      провести (так запускает расписание, каждую ночь в 03:00 по Москве)
 *   php price-sync.php --run --force   провести, даже если изменений больше PS_MAX_CHANGES
 *
 * Что делает: для каждой услуги сайта с кодом «RO-<id услуги RemOnline>» берёт цену из прайса «Стандартная цена»
 * и, если она отличается от цены на сайте, ставит её на сайте. Меняется ТОЛЬКО цена: название, описание,
 * категории, статус услуги не трогаются.
 *
 * Обязательное правило владельца (2026-10-08): цена в RemOnline равна 0 или не получена — цену на сайте НЕ меняем.
 *  - не удалось получить список услуг RemOnline целиком (ошибка, обрыв, подозрительно короткий список) — прогон
 *    прекращается, на сайте ничего не меняется;
 *  - услуги нет в списке RemOnline, у неё нет записи стандартной цены, цена 0, отрицательная или не число —
 *    услуга пропускается и попадает в отчёт.
 * Предохранитель: если изменений больше PS_MAX_CHANGES за один прогон — ничего не меняется (цены меняются редко,
 * массовое изменение похоже на ошибку); проверить отчёт и запустить с --force.
 *
 * Услуги со своими кодами (TAB-…, OLD-…) не затрагиваются. Услуги на сайте не отключаются, даже если
 * в RemOnline услуги больше нет — это только строка в отчёте.
 *
 * Журнал: /var/www/www-root/data/irepair-price-sync/sync.log (каждый прогон и каждое изменение «было → стало»).
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

define('PS_SITE_ROOT', dirname(__DIR__));
define('PS_LOG_DIR', dirname(PS_SITE_ROOT, 2) . '/irepair-price-sync');   // вне папки сайта: из браузера журнал не открыть
define('PS_PRICE_LIST', 543835);   // прайс RemOnline «Стандартная цена» (прайс «Авито» не используем)
define('PS_MIN_SERVICES', 1000);   // в RemOnline около 1 400 услуг: список короче — считаем, что он получен не полностью
define('PS_MAX_CHANGES', 50);

// CS-Cart подключаем до первого вывода на экран (иначе он ругается на настройки сессии)
define('AREA', 'C');
define('NO_SESSION', true);
$_SERVER['HTTP_HOST'] = $_SERVER['HTTP_HOST'] ?? 'localhost';
$_SERVER['REQUEST_METHOD'] = 'GET';
chdir(PS_SITE_ROOT);
require PS_SITE_ROOT . '/init.php';

$run = in_array('--run', $argv, true);
$force = in_array('--force', $argv, true);

if (!is_dir(PS_LOG_DIR)) {
    mkdir(PS_LOG_DIR, 0755, true);
}
function ps_log(string $line): void
{
    echo $line . "\n";
    file_put_contents(PS_LOG_DIR . '/sync.log', date('Y-m-d H:i:s') . ' ' . $line . "\n", FILE_APPEND);
}

$lock = fopen(PS_LOG_DIR . '/sync.lock', 'c');
if (!flock($lock, LOCK_EX | LOCK_NB)) {
    ps_log('уже выполняется другой прогон — выход');
    exit(1);
}

// ключ RemOnline — из настроек личного кабинета (в git не хранится)
define('IREPAIR_LK', 1);
$lk = require PS_SITE_ROOT . '/ajax/lk/config.php';
$token = (string) ($lk['remonline']['token'] ?? '');
if ($token === '') {
    ps_log('нет ключа RemOnline — выход, на сайте ничего не изменено');
    exit(1);
}

/** Запрос к RemOnline: [код ответа, разобранный JSON]. Превышение лимита запросов и обрыв связи — повтор. */
function ps_ro(string $path, string $token): array
{
    $code = 0;
    for ($try = 0; $try < 5; $try++) {
        $ch = curl_init('https://api.roapp.io/v2/' . $path);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 60,
            CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $token, 'Accept: application/json'],
        ]);
        $body = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($code === 429 || $code === 0 || $code >= 500) {
            sleep(3);
            continue;
        }
        return [$code, json_decode((string) $body, true)];
    }
    return [$code, null];
}

ps_log(($run ? 'ПРОВЕДЕНИЕ' : 'ПРОБНЫЙ ПРОГОН (ничего не меняется)') . ': обновление цен из RemOnline');

/* 1. Все услуги RemOnline: id → цена из стандартного прайса (null — записи цены нет) */
$ro = [];
for ($page = 1; $page <= 200; $page++) {
    [$code, $r] = ps_ro('catalog/services?limit=50&page=' . $page, $token);
    if ($code === 404 && $page > 1) {
        break;   // страницы закончились
    }
    if ($code !== 200 || !is_array($r) || !isset($r['data']) || !is_array($r['data'])) {
        ps_log("RemOnline не ответил (страница $page, код $code) — прогон прекращён, на сайте ничего не изменено");
        exit(1);
    }
    if (!$r['data']) {
        break;
    }
    foreach ($r['data'] as $s) {
        if (!is_array($s) || !isset($s['id'])) {
            continue;
        }
        $price = null;
        foreach ((array) ($s['prices'] ?? []) as $p) {
            if (is_array($p) && (int) ($p['id'] ?? 0) === PS_PRICE_LIST && isset($p['price']) && is_numeric($p['price'])) {
                $price = (float) $p['price'];
            }
        }
        $ro[(int) $s['id']] = $price;
    }
    usleep(400000);   // лимит RemOnline — 3 запроса в секунду
}
if (count($ro) < PS_MIN_SERVICES) {
    ps_log('RemOnline отдал только ' . count($ro) . ' услуг (ожидается не меньше ' . PS_MIN_SERVICES . ') — список неполный, прогон прекращён, на сайте ничего не изменено');
    exit(1);
}

/* 2. Услуги сайта с кодом RemOnline */

$products = db_get_array(
    'SELECT p.product_id, p.product_code, d.product, pr.price FROM ?:products AS p'
    . ' INNER JOIN ?:product_descriptions AS d ON d.product_id = p.product_id AND d.lang_code = ?s'
    . ' LEFT JOIN ?:product_prices AS pr ON pr.product_id = p.product_id AND pr.lower_limit = 1 AND pr.usergroup_id = 0'
    . " WHERE p.product_code LIKE 'RO-%' ORDER BY p.product_id",
    'ru'
);

$changes = [];
$skipped = ['zero' => [], 'no_price' => [], 'missing' => [], 'no_site_price' => [], 'bad_code' => []];
$same = 0;
foreach ($products as $p) {
    $label = "товар {$p['product_id']} {$p['product_code']} «{$p['product']}»";
    if (!preg_match('/^RO-(\d+)$/', (string) $p['product_code'], $m)) {
        $skipped['bad_code'][] = $label;
        continue;
    }
    $id = (int) $m[1];
    if ($p['price'] === null) {
        $skipped['no_site_price'][] = $label;
        continue;
    }
    if (!array_key_exists($id, $ro)) {
        $skipped['missing'][] = $label;
        continue;
    }
    if ($ro[$id] === null) {
        $skipped['no_price'][] = $label;
        continue;
    }
    $new = (int) round($ro[$id]);
    if ($new <= 0) {
        $skipped['zero'][] = $label . ', на сайте ' . (int) round((float) $p['price']);
        continue;
    }
    $old = (int) round((float) $p['price']);
    if ($new === $old) {
        $same++;
        continue;
    }
    $changes[] = ['id' => (int) $p['product_id'], 'old' => $old, 'new' => $new, 'label' => $label];
}

$titles = [
    'zero' => 'в RemOnline цена 0 — цена на сайте оставлена',
    'no_price' => 'в RemOnline нет стандартной цены — цена на сайте оставлена',
    'missing' => 'услуги нет в RemOnline — цена на сайте оставлена, услуга не отключена',
    'no_site_price' => 'на сайте у товара нет записи цены — пропущен',
    'bad_code' => 'код не вида RO-<число> — пропущен',
];
foreach ($skipped as $k => $list) {
    foreach ($list as $line) {
        ps_log('ПРОПУСК (' . $titles[$k] . '): ' . $line);
    }
}

if ($run && count($changes) > PS_MAX_CHANGES && !$force) {
    foreach ($changes as $c) {
        ps_log("НЕ ИЗМЕНЕНО: {$c['label']}: {$c['old']} → {$c['new']}");
    }
    ps_log('изменений ' . count($changes) . ' — больше предохранителя ' . PS_MAX_CHANGES . ': на сайте ничего не изменено. Проверить и запустить с --run --force');
    exit(2);
}

$done = 0;
foreach ($changes as $c) {
    if ($run) {
        db_query('UPDATE ?:product_prices SET price = ?d WHERE product_id = ?i AND lower_limit = 1 AND usergroup_id = 0', $c['new'], $c['id']);
        $done++;
    }
    ps_log(($run ? 'ИЗМЕНЕНО' : 'ИЗМЕНИЛОСЬ БЫ') . ": {$c['label']}: {$c['old']} → {$c['new']}");
}

if ($done) {
    // калькулятор и поиск держат цены в своих кэшах
    if (function_exists('fn_my_changes_irepair_calc_dirty')) {
        fn_my_changes_irepair_calc_dirty();
    }
    foreach (['calc-prices.php', 'search-index.php'] as $script) {
        if (is_file(PS_SITE_ROOT . '/ajax/' . $script)) {
            exec('/usr/bin/php -d date.timezone=Europe/Moscow ' . escapeshellarg(PS_SITE_ROOT . '/ajax/' . $script) . ' rebuild 2>&1', $out, $rc);
            ps_log("пересборка $script: " . ($rc === 0 ? 'ок' : 'ошибка ' . $rc));
        }
    }
}

ps_log(sprintf(
    'ИТОГО: услуг RemOnline %d, услуг сайта с кодом RO- %d, без изменений %d, %s %d, пропущено %d (цена 0: %d, нет цены: %d, нет в RemOnline: %d)',
    count($ro), count($products), $same, $run ? 'изменено' : 'изменилось бы', count($changes),
    array_sum(array_map('count', $skipped)), count($skipped['zero']), count($skipped['no_price']), count($skipped['missing'])
));
