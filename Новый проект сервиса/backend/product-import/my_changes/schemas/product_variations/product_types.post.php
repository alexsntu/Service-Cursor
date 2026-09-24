<?php
/**
 * iRepair: variation products keep their own name (e.g. "Замена аккумулятора iPhone 17 | AASP")
 * instead of inheriting the parent product name through variation sync.
 */

use Tygh\Addons\ProductVariations\Product\Type\Type;

defined("BOOTSTRAP") or die("Access denied");

if (isset($schema[Type::PRODUCT_TYPE_VARIATION]["fields"])) {
    $schema[Type::PRODUCT_TYPE_VARIATION]["fields"][] = "product";
}

return $schema;
