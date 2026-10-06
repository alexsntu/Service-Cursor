<?php
/**
 * iRepair: избранные услуги для личного кабинета (/personal/).
 * index.php?dispatch=irepair_wishlist.list → JSON со списком избранного CS-Cart текущего посетителя
 * (то же избранное, что на странице /wishlist/; хранится в сессии браузера). Только чтение:
 * удаление делает штатный wishlist.delete.
 */

defined('BOOTSTRAP') or die('Access denied');

if ($mode === 'list') {
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

return [CONTROLLER_STATUS_NO_PAGE];
