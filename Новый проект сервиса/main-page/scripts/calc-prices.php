<?php
/**
 * iRepair: данные калькулятора ремонта — собираются из услуг (товаров) CS-Cart, а не из таблицы.
 * На сервере: /ajax/calc-prices.php. Читает блок главной main-page/index-calculator-products.html.
 *
 * GET  /ajax/calc-prices.php           → JSON из кэша (var/irepair-calc/prices.json).
 * CLI  php calc-prices.php rebuild      → пересобрать кэш (cron раз в сутки ночью, 03:40).
 *
 * Кэш пересобирается сам при запросе, если:
 *  - его нет или он старше 26 часов (cron не отработал);
 *  - после сборки меняли услуги в админке/через API (модуль my_changes ставит отметку var/irepair-calc/dirty),
 *    но не чаще раза в 5 минут — массовая загрузка цен не устраивает пересборку на каждый товар.
 *
 * Что берётся: включённые услуги каталога ремонта (категории 3/…), каждая вариация — отдельная строка со своей ценой.
 * Модель = категория, к которой привязана услуга (общие услуги привязаны ко всем моделям устройства сразу).
 * Ссылки относительные (переезд dev.irepair.ru → irepair.ru ничего не ломает).
 */

define('IRC_SITE_ROOT', dirname(__DIR__));
define('IRC_CACHE_DIR', IRC_SITE_ROOT . '/var/irepair-calc');
define('IRC_CACHE_FILE', IRC_CACHE_DIR . '/prices.json');
define('IRC_DIRTY_FILE', IRC_CACHE_DIR . '/dirty');
define('IRC_MAX_AGE', 26 * 3600);
define('IRC_DIRTY_DELAY', 300);

define('IRC_CATALOG_ROOT', 3);          // категория «Каталог»: её дочерние — устройства
define('IRC_FEATURE_WARRANTY', 4);      // «Гарантия» (текст)
define('IRC_FEATURE_TIME', 5);          // «Время ремонта» (текст)
define('IRC_FEATURE_APPROX', 19);       // «Цена „от“» (флажок)

/**
 * Устройства: корневая категория → [ключ, подпись вкладки, характеристика-«конфигурация», её подпись, новые модели сверху].
 * Конфигурация — то, что клиент выбирает после модели (чип MacBook, поколение iPad, размер корпуса часов).
 * Порядок здесь = порядок вкладок. Новое устройство без записи попадёт в конец с названием категории.
 * Порядок моделей — как в каталоге (позиции категорий). У MacBook и iPad серии идут как в каталоге,
 * а модели внутри серии — от новых к старым (в каталоге они стоят от старых к новым).
 */
function irc_devices()
{
    return [
        4 => ['iPhone', 'iPhone', 0, '', false],
        5 => ['MacBook', 'MacBook', 6, 'Конфигурация', true],
        6 => ['iPad', 'iPad', 9, 'Конфигурация', true],
        8 => ['Watch', 'Watch', 11, 'Размер корпуса', false],
        7 => ['iMac', 'iMac', 13, 'Конфигурация', false],
    ];
}

$is_cli = PHP_SAPI === 'cli';

if (!$is_cli) {
    if (irc_is_stale()) {
        irc_build();
    }
    $etag = '"' . filemtime(IRC_CACHE_FILE) . '"';
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: public, max-age=600');
    header('ETag: ' . $etag);
    header('X-Robots-Tag: noindex');
    if (isset($_SERVER['HTTP_IF_NONE_MATCH']) && trim($_SERVER['HTTP_IF_NONE_MATCH']) === $etag) {
        http_response_code(304);
        exit;
    }
    readfile(IRC_CACHE_FILE);
    exit;
}

if (($argv[1] ?? '') === 'rebuild') {
    $n = irc_build();
    echo date('c') . " irepair-calc: {$n} rows\n";
}

function irc_is_stale()
{
    if (!is_file(IRC_CACHE_FILE)) {
        return true;
    }
    $built = filemtime(IRC_CACHE_FILE);
    if (time() - $built > IRC_MAX_AGE) {
        return true;
    }
    return is_file(IRC_DIRTY_FILE) && filemtime(IRC_DIRTY_FILE) >= $built && time() - $built > IRC_DIRTY_DELAY;
}

function irc_build()
{
    if (!is_dir(IRC_CACHE_DIR)) {
        mkdir(IRC_CACHE_DIR, 0755, true);
    }
    $lock = fopen(IRC_CACHE_DIR . '/build.lock', 'c');
    flock($lock, LOCK_EX);
    // пока ждали блокировку, файл мог собрать другой запрос
    if (PHP_SAPI !== 'cli' && is_file(IRC_CACHE_FILE) && time() - filemtime(IRC_CACHE_FILE) < 60) {
        flock($lock, LOCK_UN);
        return 0;
    }

    if (!defined('AREA')) {
        define('AREA', 'C');
        define('NO_SESSION', true);
        if (PHP_SAPI === 'cli') {
            $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_HOST'] ?? 'localhost';
            $_SERVER['REQUEST_METHOD'] = 'GET';
        }
        $cwd = getcwd();
        chdir(IRC_SITE_ROOT);
        require IRC_SITE_ROOT . '/init.php';
        chdir($cwd);
    }

    $clean = function ($s) {
        return trim(preg_replace('/\s+/u', ' ', html_entity_decode(strip_tags((string) $s), ENT_QUOTES, 'UTF-8')));
    };

    // 1. Категории каталога: устройства (дочерние «Каталога») и модели (любая категория ниже, где есть услуги)
    $cats = db_get_hash_array(
        'SELECT c.category_id, c.parent_id, c.id_path, c.position, d.category FROM ?:categories AS c'
        . ' INNER JOIN ?:category_descriptions AS d ON d.category_id = c.category_id AND d.lang_code = ?s'
        . " WHERE c.status IN ('A', 'H') AND c.id_path LIKE '" . IRC_CATALOG_ROOT . "/%'",
        'category_id', 'ru'
    );
    $known = irc_devices();
    $device_of = [];   // category_id → id корневой категории устройства
    $sort_key = [];    // category_id → позиции по пути (порядок как в каталоге)
    $series_key = [];  // category_id → то же без последнего уровня (серия)
    foreach ($cats as $id => $c) {
        $path = explode('/', $c['id_path']);
        if (count($path) < 2) {
            continue;
        }
        $device_of[$id] = (int) $path[1];
        $key = [];
        foreach (array_slice($path, 2) as $pid) {
            $key[] = sprintf('%06d.%06d', isset($cats[$pid]) ? $cats[$pid]['position'] : 0, $pid);
        }
        $sort_key[$id] = implode('/', $key);
        // модель без серии (MacBook 12, iMac) сама себе серия
        $series_key[$id] = count($key) > 1 ? implode('/', array_slice($key, 0, -1)) : $sort_key[$id];
    }

    // 2. Услуги: включённые товары и вариации; своя цена у каждой вариации
    $products = db_get_hash_array(
        'SELECT p.product_id, p.parent_product_id, d.product,'
        . ' (SELECT MIN(pp.price) FROM ?:product_prices AS pp WHERE pp.product_id = p.product_id AND pp.lower_limit = 1 AND pp.usergroup_id = 0) AS price'
        . ' FROM ?:products AS p'
        . ' INNER JOIN ?:product_descriptions AS d ON d.product_id = p.product_id AND d.lang_code = ?s'
        . ' WHERE p.status = ?s ORDER BY p.product_id',
        'product_id', 'ru', 'A'
    );
    $links = db_get_array(
        'SELECT product_id, category_id, link_type, position FROM ?:products_categories WHERE product_id IN (?n)',
        array_keys($products) ?: [0]
    );
    $product_cats = [];
    $product_main = [];
    $product_pos = [];   // место услуги в списке категории (у услуги оно одинаковое во всех её категориях)
    foreach ($links as $l) {
        if (!isset($device_of[$l['category_id']])) {
            continue;
        }
        $product_cats[$l['product_id']][] = (int) $l['category_id'];
        $product_pos[$l['product_id']] = max($product_pos[$l['product_id']] ?? 0, (int) $l['position']);
        if ($l['link_type'] === 'M') {
            $product_main[$l['product_id']] = (int) $l['category_id'];
        }
    }

    // 3. Характеристики: гарантия, время, цена «от», конфигурация и «варианты» (тип запчасти, объём и т. п.)
    $features = db_get_hash_array(
        'SELECT f.feature_id, f.purpose, f.position, d.description FROM ?:product_features AS f'
        . ' INNER JOIN ?:product_features_descriptions AS d ON d.feature_id = f.feature_id AND d.lang_code = ?s',
        'feature_id', 'ru'
    );
    $values = db_get_array(
        'SELECT v.product_id, v.feature_id, v.value, vd.variant, vd.description'
        . ' FROM ?:product_features_values AS v'
        . ' LEFT JOIN ?:product_feature_variant_descriptions AS vd ON vd.variant_id = v.variant_id AND vd.lang_code = ?s'
        . ' WHERE v.lang_code = ?s AND v.product_id IN (?n) ORDER BY v.product_id, v.feature_id',
        'ru', 'ru', array_keys($products) ?: [0]
    );
    $feats = [];
    foreach ($values as $v) {
        $text = $v['variant'] !== null && $v['variant'] !== '' ? $v['variant'] : $v['value'];
        $feats[$v['product_id']][(int) $v['feature_id']] = [$clean($text), $clean($v['description'])];
    }

    // 4. Строки
    $models = [];      // device root → [category_id => true]
    $notes = [];       // пояснения к вариантам (словарь, в строке — номер)
    $note_idx = [];
    $rows = [];
    foreach ($products as $pid => $p) {
        if (empty($product_cats[$pid]) || $p['price'] === null || $p['price'] <= 0) {
            continue;
        }
        $main = $product_main[$pid] ?? $product_cats[$pid][0];
        $root = $device_of[$main];
        $config_feature = isset($known[$root]) ? $known[$root][2] : 0;
        $f = $feats[$pid] ?? [];

        // модели: все привязанные категории ниже корня устройства
        $model_ids = [];
        foreach ($product_cats[$pid] as $cid) {
            if ($device_of[$cid] === $root && $cid !== $root) {
                $model_ids[] = $cid;
                $models[$root][$cid] = true;
            }
        }
        if (!$model_ids) {
            continue;
        }

        // название услуги — по главному товару группы, без модели в конце
        $parent = $p['parent_product_id'] && isset($products[$p['parent_product_id']]) ? $products[$p['parent_product_id']] : $p;
        $name = irc_service_name($clean(preg_replace('/\s*\|.*$/u', '', $parent['product'])));
        $pos = $product_pos[$parent['product_id']] ?? ($product_pos[$pid] ?? 0);

        // варианты: всё, по чему собраны вариации, кроме конфигурации
        $opt = [];
        $opt_label = [];
        $note = '';
        foreach ($f as $fid => $val) {
            if ($fid === $config_feature || !isset($features[$fid]) || $features[$fid]['purpose'] !== 'group_variation_catalog_item' || $val[0] === '') {
                continue;
            }
            $opt[] = $val[0];
            $opt_label[] = irc_feature_label($clean($features[$fid]['description']));
            if ($val[1] !== '' && $note === '') {
                $note = $val[1];
            }
        }

        $row = [
            'd' => $root,
            'm' => $model_ids,
            's' => $name,
            'p' => (int) round($p['price']),
            'o' => $pos,
            'u' => preg_replace('#^https?://[^/]+#', '', fn_url('products.view?product_id=' . $pid, 'C')),
        ];
        if ($config_feature && !empty($f[$config_feature][0])) {
            $row['c'] = $f[$config_feature][0];
        }
        if ($opt) {
            $row['q'] = implode(' · ', $opt);
            $row['ql'] = count($opt) === 1 ? $opt_label[0] : 'Вариант';
            if ($note !== '') {
                if (!isset($note_idx[$note])) {
                    $note_idx[$note] = count($notes);
                    $notes[] = $note;
                }
                $row['n'] = $note_idx[$note];
            }
        }
        if (!empty($f[IRC_FEATURE_APPROX][0]) && $f[IRC_FEATURE_APPROX][0] === 'Y') {
            $row['a'] = 1;
        }
        if (!empty($f[IRC_FEATURE_WARRANTY][0])) {
            $row['w'] = $f[IRC_FEATURE_WARRANTY][0];
        }
        if (!empty($f[IRC_FEATURE_TIME][0])) {
            $row['t'] = $f[IRC_FEATURE_TIME][0];
        }
        $rows[] = $row;
    }

    // 5. Устройства и модели в порядке каталога; в строках — номера вместо id категорий
    $order = array_keys($known);
    foreach (array_keys($models) as $root) {
        if (!in_array($root, $order, true)) {
            $order[] = $root;
        }
    }
    $devices = [];
    $device_idx = [];
    $model_idx = [];
    foreach ($order as $root) {
        if (empty($models[$root])) {
            continue;
        }
        $ids = array_keys($models[$root]);
        $newest_first = isset($known[$root]) && $known[$root][4];
        usort($ids, function ($a, $b) use ($sort_key, $series_key, $cats, $newest_first) {
            if (!$newest_first) {
                return strcmp($sort_key[$a], $sort_key[$b]);
            }
            return strcmp($series_key[$a], $series_key[$b]) ?: strnatcasecmp(trim($cats[$b]['category']), trim($cats[$a]['category']));
        });
        $names = [];
        foreach ($ids as $i => $cid) {
            $model_idx[$cid] = $i;
            $names[] = preg_replace('/^Ремонт\s+/u', '', $clean($cats[$cid]['category']));
        }
        $device_idx[$root] = count($devices);
        $devices[] = [
            'k' => isset($known[$root]) ? $known[$root][0] : 'dev' . $root,
            't' => isset($known[$root]) ? $known[$root][1] : preg_replace('/^Ремонт\s+/u', '', $clean($cats[$root]['category'])),
            'cl' => isset($known[$root]) ? $known[$root][3] : '',
            'm' => $names,
        ];
    }
    foreach ($rows as &$row) {
        $row['m'] = array_map(function ($cid) use ($model_idx) {
            return $model_idx[$cid];
        }, $row['m']);
        sort($row['m']);
        $row['d'] = $device_idx[$row['d']];
    }
    unset($row);

    $out = json_encode([
        'v'       => date('YmdHis'),
        'devices' => $devices,
        'notes'   => $notes,
        'rows'    => $rows,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $tmp = IRC_CACHE_FILE . '.tmp';
    file_put_contents($tmp, $out);
    rename($tmp, IRC_CACHE_FILE);
    flock($lock, LOCK_UN);

    return count($rows);
}

/**
 * «Замена аккумулятора iPhone 17 Pro» → «Замена аккумулятора»: модель клиент уже выбрал.
 * Убираем только хвост вида «[на] <устройство> <обозначение модели>»; если после устройства идут слова
 * («Чистка MacBook после попадания жидкости») или перед ним определение («…на новый iPhone») — не трогаем.
 */
function irc_service_name($name)
{
    $device = '(?:iPhone|MacBook|iPad|iMac|Apple\s+Watch)';
    $name = preg_replace('#\s+/\s+#u', '/', $name);   // «громкости / блокировки» и «громкости/блокировки» — одна услуга
    // в обозначении модели допускаем русскую «М» (iPad Pro 13 М5)
    $re = '/^(.+?)\s+(?:(?:на|для)\s+)?' . $device . '(?:\s+[A-Za-zМ0-9][A-Za-zМ0-9.,]*["\'”″]*){0,4}$/u';
    if (preg_match($re, $name, $m) && !preg_match('/(?:^|\s)(?:на|для|в|с|новый|нового|новом)$/ui', $m[1])) {
        return $m[1];
    }
    // «Чистка слухового динамика iPhone (хрип)» → «Чистка слухового динамика (хрип)»
    return preg_replace('/\s+' . $device . '(?=\s+\()/u', '', $name);
}

/** «Тип запчасти аккумулятора iPhone» → «Тип запчасти», «Объём накопителя MacBook» → «Объём накопителя». */
function irc_feature_label($name)
{
    if (preg_match('/^Тип запчасти/u', $name)) {
        return 'Тип запчасти';
    }
    return trim(preg_replace('/\s+(?:iPhone|MacBook|iPad|iMac|Apple\s+Watch)$/u', '', $name));
}
