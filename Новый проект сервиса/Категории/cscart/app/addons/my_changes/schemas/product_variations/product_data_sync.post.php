<?php
/**
 * iRepair: при синхронизации вариаций не копировать с главного товара на варианты
 * «Гарантию» (id 4) и «Время ремонта» (id 5) — у OEM и AASP они разные
 * (MacBook: OEM 3 мес., AASP 12 мес.). Остальные характеристики синхронизируются как раньше.
 */

use Tygh\Addons\ProductVariations\Product\Sync\Table\OneToManyViaPrimaryKeyTable;

defined('BOOTSTRAP') or die('Access denied');

if (isset($schema['product_features_values'])) {
    $schema['product_features_values'] = OneToManyViaPrimaryKeyTable::create(
        'product_features_values',
        ['product_id', 'feature_id', 'variant_id', 'lang_code'],
        'product_id', [],
        ['conditions' => 'fn_my_changes_irepair_sync_feature_conditions']
    );
}

return $schema;
