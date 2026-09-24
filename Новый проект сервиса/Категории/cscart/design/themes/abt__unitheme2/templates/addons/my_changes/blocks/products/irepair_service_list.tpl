{** block-description:irepair_service_list_block **}
{* iRepair: шаблон блока товаров «iRepair — Список услуг (блок)» — копия blocks/products/short_list.tpl
   («Компактный список»), но строки выводит наш прайс-список услуг (как в категории).
   Заголовок «Стоимость услуг…» в блоке не выводится (no_sorting) — вместо него название блока. *}

{if $block.properties.hide_add_to_cart_button == "YesNo::YES"|enum}
    {assign var="_show_add_to_cart" value=false}
{else}
    {assign var="_show_add_to_cart" value=true}
{/if}

{$tmpl='short_list'}
{include file="addons/my_changes/blocks/product_list_templates/default_params/irepair_service_list.tpl"}
{include file="addons/my_changes/blocks/list_templates/irepair_service_list.tpl"
products=$items
no_sorting="YesNo::YES"|enum
no_pagination="YesNo::YES"|enum
obj_prefix="`$block.block_id`000"
show_add_to_cart=$_show_add_to_cart}
