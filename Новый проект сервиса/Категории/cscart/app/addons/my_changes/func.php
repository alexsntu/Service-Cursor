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
    // порядок выборов: как в группе (модель добавлена первой → id меньше)
    $feature_ids = db_get_fields(
        'SELECT feature_id FROM ?:product_variation_group_features WHERE group_id = ?i ORDER BY feature_id',
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
