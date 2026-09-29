<?php
/**
 * iRepair: индекс живого поиска (свой поиск вместо стандартного CS-Cart).
 * На сервере: /ajax/search-index.php (рядом /ajax/search-synonyms.json, /ajax/irepair-search.js, /ajax/irepair-search.css).
 *
 * GET  /ajax/search-index.php          → JSON-индекс из кэша (var/irepair-search/index.json).
 * CLI  php search-index.php rebuild     → пересобрать индекс (cron раз в сутки ночью, 03:30).
 * Если кэша нет или он старше 26 часов (cron не отработал) — индекс собирается при запросе.
 *
 * В индексе: модели/серии (категории каталога), страницы «Выбор модели» (категории 127/…),
 * услуги (главный товар группы вариаций, цена «от» = минимальная по группе), страницы CS-Cart и статьи блога.
 * Ссылки относительные (переезд dev.irepair.ru → irepair.ru ничего не ломает).
 */

define('IRP_SITE_ROOT', dirname(__DIR__));
define('IRP_CACHE_DIR', IRP_SITE_ROOT . '/var/irepair-search');
define('IRP_CACHE_FILE', IRP_CACHE_DIR . '/index.json');
define('IRP_MAX_AGE', 26 * 3600);

$is_cli = PHP_SAPI === 'cli';

if (!$is_cli) {
    if (!is_file(IRP_CACHE_FILE) || time() - filemtime(IRP_CACHE_FILE) > IRP_MAX_AGE) {
        irp_build();
    }
    $etag = '"' . filemtime(IRP_CACHE_FILE) . '"';
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: public, max-age=3600');
    header('ETag: ' . $etag);
    header('X-Robots-Tag: noindex');
    if (isset($_SERVER['HTTP_IF_NONE_MATCH']) && trim($_SERVER['HTTP_IF_NONE_MATCH']) === $etag) {
        http_response_code(304);
        exit;
    }
    readfile(IRP_CACHE_FILE);
    exit;
}

if (($argv[1] ?? '') === 'rebuild') {
    $n = irp_build();
    echo date('c') . " irepair-search: {$n} items\n";
}

function irp_build()
{
    if (!is_dir(IRP_CACHE_DIR)) {
        mkdir(IRP_CACHE_DIR, 0755, true);
    }
    $lock = fopen(IRP_CACHE_DIR . '/build.lock', 'c');
    flock($lock, LOCK_EX);
    // пока ждали блокировку, индекс мог собрать другой запрос
    if (PHP_SAPI !== 'cli' && is_file(IRP_CACHE_FILE) && time() - filemtime(IRP_CACHE_FILE) < 60) {
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
        chdir(IRP_SITE_ROOT);
        require IRP_SITE_ROOT . '/init.php';
        chdir($cwd);
    }

    $rel = function ($dispatch) {
        return preg_replace('#^https?://[^/]+#', '', fn_url($dispatch, 'C'));
    };
    $clean = function ($s) {
        return trim(preg_replace('/\s+/u', ' ', html_entity_decode(strip_tags((string) $s), ENT_QUOTES, 'UTF-8')));
    };

    $items = [];

    // 1. Категории: каталог ремонта (3/…) — модели/серии, «Выбор модели» (127/…) — услуга по всем моделям
    $cats = db_get_hash_array(
        'SELECT c.category_id, c.parent_id, c.id_path, c.position, d.category FROM ?:categories AS c'
        . ' INNER JOIN ?:category_descriptions AS d ON d.category_id = c.category_id AND d.lang_code = ?s'
        . " WHERE c.status IN ('A', 'H') AND (c.id_path LIKE '3/%' OR c.id_path LIKE '127/%')",
        'category_id', 'ru'
    );
    foreach ($cats as $id => $c) {
        $parent = isset($cats[$c['parent_id']]) ? $clean($cats[$c['parent_id']]['category']) : '';
        $is_vm = strpos($c['id_path'], '127/') === 0;
        $items[] = [
            $is_vm ? 'v' : 'c',
            $clean($c['category']),
            $rel('categories.view?category_id=' . $id),
            null,
            $is_vm ? 'Все модели' : $parent,
            (int) $c['position'],
        ];
    }

    // 2. Услуги: главные товары, цена «от» — минимальная по группе вариаций (только включённые варианты)
    $products = db_get_array(
        'SELECT p.product_id, d.product, pc.category_id,'
        . ' COALESCE((SELECT MIN(pp.price) FROM ?:product_variation_group_products AS g1'
        . '   INNER JOIN ?:product_variation_group_products AS g2 ON g2.group_id = g1.group_id'
        . '   INNER JOIN ?:products AS p2 ON p2.product_id = g2.product_id AND p2.status = ?s'
        . '   INNER JOIN ?:product_prices AS pp ON pp.product_id = g2.product_id AND pp.lower_limit = 1'
        . '   WHERE g1.product_id = p.product_id),'
        . '  (SELECT MIN(pp.price) FROM ?:product_prices AS pp WHERE pp.product_id = p.product_id AND pp.lower_limit = 1)) AS price'
        . ' FROM ?:products AS p'
        . ' INNER JOIN ?:product_descriptions AS d ON d.product_id = p.product_id AND d.lang_code = ?s'
        . ' LEFT JOIN ?:products_categories AS pc ON pc.product_id = p.product_id AND pc.link_type = ?s'
        . ' WHERE p.status = ?s AND p.parent_product_id = 0',
        'A', 'ru', 'M', 'A'
    );
    foreach ($products as $p) {
        $cat = isset($cats[$p['category_id']]) ? $clean($cats[$p['category_id']]['category']) : '';
        $items[] = [
            's',
            $clean($p['product']),
            $rel('products.view?product_id=' . $p['product_id']),
            $p['price'] !== null ? (int) round($p['price']) : null,
            preg_replace('/^Ремонт\s+/u', '', $cat),
            0,
        ];
    }

    // 3. Страницы и статьи блога
    $pages = db_get_array(
        'SELECT p.page_id, p.page_type, p.parent_id, d.page FROM ?:pages AS p'
        . ' INNER JOIN ?:page_descriptions AS d ON d.page_id = p.page_id AND d.lang_code = ?s'
        . " WHERE p.status = 'A' AND p.page_type IN ('T', 'B')",
        'ru'
    );
    foreach ($pages as $p) {
        $is_post = $p['page_type'] === 'B' && $p['parent_id'];
        $items[] = [
            $is_post ? 'b' : 'p',
            $clean($p['page']),
            $rel('pages.view?page_id=' . $p['page_id']),
            null,
            $is_post ? 'Статья блога' : '',
            0,
        ];
    }

    // 4. Синонимы и популярные услуги (редактируемый файл рядом)
    $cfg = json_decode((string) @file_get_contents(__DIR__ . '/search-synonyms.json'), true) ?: [];
    $popular = [];
    foreach ((array) ($cfg['popular_categories'] ?? []) as $cid) {
        if (isset($cats[$cid])) {
            $popular[] = [$clean($cats[$cid]['category']), $rel('categories.view?category_id=' . $cid)];
        }
    }

    $out = json_encode([
        'v'       => date('YmdHis'),
        'syn'     => $cfg['synonyms'] ?? [],
        'stop'    => $cfg['stopwords'] ?? [],
        'popular' => $popular,
        'items'   => $items,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $tmp = IRP_CACHE_FILE . '.tmp';
    file_put_contents($tmp, $out);
    rename($tmp, IRP_CACHE_FILE);
    flock($lock, LOCK_UN);

    return count($items);
}
