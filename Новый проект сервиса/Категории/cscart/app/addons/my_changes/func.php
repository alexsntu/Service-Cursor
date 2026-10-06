<?php
/**
 * iRepair: функции модуля my_changes (CS-Cart сам подключает func.php включённого модуля).
 */

if (!defined('BOOTSTRAP')) { die('Access denied'); }

/**
 * Сетка группы вариаций для прайса «iRepair — Список услуг»: услуга с двумя выборами
 * (MacBook: модель × тип запчасти) — в данных списка CS-Cart отдаёт варианты только относительно
 * текущего товара, полной сетки там нет.
 *
 * @param int $group_id id группы вариаций ($product.variation_group_id)
 *
 * @return array [
 *   'features' => [feature_id => ['name' => …, 'variants' => [variant_id => ['name' => …, 'note' => описание значения]]]],
 *   'products' => [product_id => ['price' => …, 'values' => [feature_id => variant_id]]],
 * ] — только включённые товары; значения характеристик — в порядке позиции значения
 */
function fn_my_changes_irepair_variation_matrix($group_id)
{
    static $cache = [];
    $group_id = (int) $group_id;
    if (!$group_id) {
        return [];
    }
    if (isset($cache[$group_id])) {
        return $cache[$group_id];
    }

    $result = ['features' => [], 'products' => []];

    $product_ids = db_get_fields(
        'SELECT gp.product_id FROM ?:product_variation_group_products AS gp'
        . ' INNER JOIN ?:products AS p ON p.product_id = gp.product_id AND p.status = ?s'
        . ' WHERE gp.group_id = ?i',
        'A', $group_id
    );
    // порядок выборов — по позиции характеристики (модель 0, тип запчасти 10), как в карточке товара
    $feature_ids = db_get_fields(
        'SELECT gf.feature_id FROM ?:product_variation_group_features AS gf'
        . ' INNER JOIN ?:product_features AS f ON f.feature_id = gf.feature_id'
        . ' WHERE gf.group_id = ?i ORDER BY f.position, gf.feature_id',
        $group_id
    );
    if (!$product_ids || !$feature_ids) {
        return $cache[$group_id] = $result;
    }

    foreach ($feature_ids as $feature_id) {
        $result['features'][$feature_id] = [
            'name' => (string) db_get_field(
                'SELECT description FROM ?:product_features_descriptions WHERE feature_id = ?i AND lang_code = ?s',
                $feature_id, CART_LANGUAGE
            ),
            'variants' => [],
            // вид характеристики: dropdown_labels = плитки (тип запчасти) — в списке категории показываем только их
            'style' => (string) db_get_field('SELECT feature_style FROM ?:product_features WHERE feature_id = ?i', $feature_id),
        ];
    }

    $prices = db_get_hash_single_array(
        'SELECT product_id, MIN(price) AS price FROM ?:product_prices'
        . ' WHERE product_id IN (?n) AND lower_limit = 1 AND usergroup_id = 0 GROUP BY product_id',
        ['product_id', 'price'], $product_ids
    );
    foreach ($product_ids as $product_id) {
        $result['products'][$product_id] = ['price' => (float) ($prices[$product_id] ?? 0), 'values' => []];
    }

    $values = db_get_array(
        'SELECT fv.product_id, fv.feature_id, fv.variant_id, vd.variant, vd.description'
        . ' FROM ?:product_features_values AS fv'
        . ' INNER JOIN ?:product_feature_variants AS v ON v.variant_id = fv.variant_id'
        . ' INNER JOIN ?:product_feature_variant_descriptions AS vd ON vd.variant_id = fv.variant_id AND vd.lang_code = ?s'
        . ' WHERE fv.product_id IN (?n) AND fv.feature_id IN (?n) AND fv.lang_code = ?s'
        . ' ORDER BY v.position, vd.variant',
        CART_LANGUAGE, $product_ids, $feature_ids, CART_LANGUAGE
    );
    foreach ($values as $row) {
        $result['products'][$row['product_id']]['values'][$row['feature_id']] = (int) $row['variant_id'];
        $result['features'][$row['feature_id']]['variants'][$row['variant_id']] = [
            'name' => trim($row['variant']),
            'note' => trim(strip_tags((string) $row['description'])),
        ];
    }

    return $cache[$group_id] = $result;
}

/**
 * Условия синхронизации характеристик вариаций (schemas/product_variations/product_data_sync.post.php):
 * стандартные (без характеристик группы) + без «Гарантии» (4) и «Времени ремонта» (5) — у вариантов свои.
 */
function fn_my_changes_irepair_sync_feature_conditions($product_id)
{
    $conditions = function_exists('fn_product_variations_get_product_sync_feature_conditions')
        ? fn_product_variations_get_product_sync_feature_conditions($product_id)
        : [];
    $conditions[] = ['NOT IN', 'feature_id', [4, 5]];

    return $conditions;
}

/**
 * Последние статьи блога для блока «Полезные статьи» на главной (main-page/index-blog.html).
 * Вызывается из «HTML блока с поддержкой Smarty», где CS-Cart разрешает только функции из схемы
 * block_manager/smarty_allowed_functions — поэтому всё готовим здесь: ссылка, картинка, дата по-русски, анонс.
 */
function fn_my_changes_irepair_latest_blog_posts($limit = 4)
{
    $limit = max(1, min(12, (int) $limit));
    $months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    list($pages) = fn_get_pages([
        'page_type'  => defined('PAGE_TYPE_BLOG') ? PAGE_TYPE_BLOG : 'B',
        'status'     => 'A',
        'sort_by'    => 'timestamp',
        'sort_order' => 'desc',
        'get_image'  => true,
    ], $limit + 2);

    $posts = [];
    foreach ((array) $pages as $page) {
        if (empty($page['parent_id'])) {
            continue; // корневая страница «Блог»
        }
        $image = '';
        if (!empty($page['main_pair']['icon']['image_path'])) {
            $image = $page['main_pair']['icon']['image_path'];
        } elseif (!empty($page['main_pair']['detailed']['image_path'])) {
            $image = $page['main_pair']['detailed']['image_path'];
        }
        $text = trim(preg_replace('/\s+/u', ' ', html_entity_decode(strip_tags((string) (!empty($page['spoiler']) ? $page['spoiler'] : $page['description'])), ENT_QUOTES, 'UTF-8')));
        if (mb_strlen($text) > 170) {
            $text = rtrim(mb_substr($text, 0, 170)) . '…';
        }
        $ts = (int) $page['timestamp'];
        $posts[] = [
            'title'    => $page['page'],
            'url'      => fn_url('pages.view?page_id=' . $page['page_id']),
            'image'    => $image,
            'date'     => date('j', $ts) . ' ' . $months[(int) date('n', $ts) - 1] . ' ' . date('Y', $ts),
            'date_iso' => date('Y-m-d', $ts),
            'text'     => $text,
            'blog_url' => fn_url('pages.view?page_id=' . $page['parent_id']),
        ];
        if (count($posts) >= $limit) {
            break;
        }
    }

    return $posts;
}

/* ------------------------------------------------------------------------------------------------
 * Избранные услуги, привязанные к клиенту личного кабинета.
 *
 * Избранное CS-Cart живёт в сессии браузера. Чтобы список был у клиента на любом устройстве, для вошедшего
 * в кабинет (/personal/) он дублируется в таблице irepair_lk_favorites (телефон + услуга):
 *   - при открытии кабинета списки объединяются (слияние) — см. fn_my_changes_irepair_fav_sync(true);
 *   - дальше любое изменение избранного на сайте (сердечко, страница /wishlist/, кабинет) сразу записывается
 *     клиенту — хук save_cart_content_pre.
 * Вход в кабинет — свой (кука irepair_lk, таблица irepair_lk_sessions), пользователей CS-Cart нет.
 * ---------------------------------------------------------------------------------------------- */

/** Телефон клиента, вошедшего в личный кабинет, или '' */
function fn_my_changes_irepair_lk_phone()
{
    static $phone = null;
    if ($phone === null) {
        $token = isset($_COOKIE['irepair_lk']) ? (string) $_COOKIE['irepair_lk'] : '';
        $phone = preg_match('/^[a-f0-9]{64}$/', $token)
            ? (string) db_get_field('SELECT phone FROM irepair_lk_sessions WHERE token_hash = ?s AND expires_at > ?i', hash('sha256', $token), TIME)
            : '';
    }

    return $phone;
}

/**
 * Синхронизация избранного браузера с избранным клиента.
 *
 * @param bool $merge true — слияние (кабинет открыт): услуги клиента с других устройств добавляются в избранное
 *                    этого браузера. false — только запись изменений клиенту.
 */
function fn_my_changes_irepair_fav_sync($merge = false, $wishlist = null)
{
    static $busy = false;
    $phone = fn_my_changes_irepair_lk_phone();
    if ($busy || $phone === '' || !function_exists('fn_add_product_to_wishlist')) {
        return;
    }
    $busy = true;

    $session = &Tygh::$app['session'];
    if ($wishlist === null) {
        $wishlist = isset($session['wishlist']) ? $session['wishlist'] : [];
    }
    $in_browser = [];
    foreach ((!empty($wishlist['products']) ? $wishlist['products'] : []) as $item) {
        if (!empty($item['product_id'])) {
            $in_browser[(int) $item['product_id']] = true;
        }
    }
    $in_account = array_fill_keys(array_map('intval', db_get_fields('SELECT product_id FROM irepair_lk_favorites WHERE phone = ?s', $phone)), true);
    // этот браузер уже объединён с избранным этого клиента → браузер — точная копия, удаления тоже переносим
    $merged = isset($session['irepair_fav_phone']) && $session['irepair_fav_phone'] === $phone;

    foreach (array_diff_key($in_browser, $in_account) as $product_id => $_) {
        db_query('INSERT IGNORE INTO irepair_lk_favorites (phone, product_id, created_at) VALUES (?s, ?i, ?i)', $phone, $product_id, TIME);
    }
    $missing = array_diff_key($in_account, $in_browser);
    if ($merged) {
        if ($missing) {
            db_query('DELETE FROM irepair_lk_favorites WHERE phone = ?s AND product_id IN (?n)', $phone, array_keys($missing));
        }
    } elseif ($merge) {
        if ($missing) {
            if (empty($session['wishlist'])) {
                $session['wishlist'] = ['products' => []];
            }
            $auth = &Tygh::$app['session']['auth'];
            $add = [];
            foreach (array_keys($missing) as $product_id) {
                $add[$product_id] = ['product_id' => $product_id, 'amount' => 1];
            }
            fn_add_product_to_wishlist($add, $session['wishlist'], $auth);
            fn_save_cart_content($session['wishlist'], isset($auth['user_id']) ? $auth['user_id'] : 0, 'W');
        }
        $session['irepair_fav_phone'] = $phone;
    }

    $busy = false;
}

/** Хук: любое сохранение избранного CS-Cart → записать изменения клиенту кабинета */
function fn_my_changes_save_cart_content_pre(&$cart, $user_id, $type, $user_type)
{
    if ($type === 'W') {
        fn_my_changes_irepair_fav_sync(false, $cart);
    }
}
