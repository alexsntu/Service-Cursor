<?php
/**
 * iRepair: избранные и просмотренные услуги для личного кабинета (/personal/).
 * index.php?dispatch=irepair_wishlist.viewed → JSON с просмотренными услугами (для клиента кабинета — из irepair_lk_viewed).
 * index.php?dispatch=irepair_wishlist.list → JSON со списком избранного CS-Cart текущего посетителя
 * (то же избранное, что на странице /wishlist/). Для клиента, вошедшего в кабинет, список привязан к телефону
 * и перед выдачей объединяется с сохранённым (таблица irepair_lk_favorites). Удаление — штатный wishlist.delete.
 */

defined('BOOTSTRAP') or die('Access denied');

// Клиент вышел из кабинета или вход истёк: избранное, загруженное в этот браузер из его кабинета, убираем
// (оно сохранено за клиентом и вернётся при следующем входе). Чужой гостевой список не трогаем.
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $mode === 'release') {
    $released = fn_my_changes_irepair_fav_release();
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode(['ok' => true, 'released' => $released]);
    exit;
}

if ($mode === 'list') {
    // клиент вошёл в кабинет — объединяем избранное этого браузера с сохранённым за клиентом (func.php)
    fn_my_changes_irepair_fav_sync(true);
    $wishlist = Tygh::$app['session']['wishlist'] ?? [];
    $items = [];

    foreach (($wishlist['products'] ?? []) as $cart_id => $item) {
        $product_id = (int) ($item['product_id'] ?? 0);
        $product = $product_id ? fn_get_product_data($product_id, $auth, CART_LANGUAGE, '', false, true, false, false) : [];
        if (empty($product) || ($product['status'] ?? '') !== 'A') {
            continue;
        }
        $image = $product['main_pair']['icon']['image_path'] ?? ($product['main_pair']['detailed']['image_path'] ?? '');
        $items[] = [
            'cart_id' => (string) $cart_id,
            'name'    => (string) $product['product'],
            'url'     => fn_url('products.view?product_id=' . $product_id),
            'price'   => (float) $product['price'],
            'image'   => (string) $image,
        ];
    }

    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Robots-Tag: noindex, nofollow');
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

// Просмотренные услуги: для клиента кабинета — сохранённые за ним, последние первыми
if ($mode === 'viewed') {
    $items = [];
    foreach (fn_my_changes_irepair_viewed_sync(12) as $product_id) {
        $product = fn_get_product_data($product_id, $auth, CART_LANGUAGE, '', false, true, false, false);
        if (empty($product) || ($product['status'] ?? '') !== 'A') {
            continue;
        }
        $items[] = [
            'name'  => (string) $product['product'],
            'url'   => fn_url('products.view?product_id=' . $product_id),
            'price' => (float) $product['price'],
            'image' => (string) ($product['main_pair']['icon']['image_path'] ?? ($product['main_pair']['detailed']['image_path'] ?? '')),
        ];
    }

    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Robots-Tag: noindex, nofollow');
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

return [CONTROLLER_STATUS_NO_PAGE];
