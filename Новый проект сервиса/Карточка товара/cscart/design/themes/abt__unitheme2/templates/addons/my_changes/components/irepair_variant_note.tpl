{* iRepair — расшифровка выбранной опции (значения характеристики вариации, например AASP / OEM).
   Текст берётся из «Описания» значения характеристики: Товары → Характеристики → <характеристика> → значение → Описание.
   Если описания нет — ничего не выводится. Блок обновляется вместе с опциями (cm-reload-*) при переключении варианта. *}
{if $product.variation_features_variants}
<div class="irepair-variant-note cm-reload-{$obj_id}" id="irepair_variant_note_{$obj_id}">
    {* $irp_vf.variant_id — значение, выбранное у текущего товара (так же его отмечает переключатель опций) *}
    {foreach $product.variation_features_variants as $irp_vf}
        {if $irp_vf.variant_id}
            {$irp_variant = $irp_vf.variant_id|fn_get_product_feature_variant}
            {$irp_note = $irp_variant.description|default:""|strip_tags|trim}
            {if $irp_note}
                <p class="irepair-variant-note__text">{$irp_note nofilter}</p>
            {/if}
        {/if}
    {/foreach}
<!--irepair_variant_note_{$obj_id}--></div>
{/if}

{literal}
<style>
.irepair-variant-note .irepair-variant-note__text {
  margin: 6px 0 0;
  padding: 0;
  font-size: 13px;
  line-height: 18px;
  color: #7a7a7a;
}
.irepair-variant-note .irepair-variant-note__text:first-child {
  margin-top: 8px;
}
/* ПК: резерв под 2 строки расшифровки — кнопка не прыгает при переключении опций,
   и блок бонусов в правой колонке остаётся на одной линии с ней */
@media (min-width: 768px) {
  .ut2-pb__options .irepair-variant-note {
    min-height: 44px;
  }
}
/* карточка услуги (2026-10-02): плитки «Тип запчасти» одинакового размера, по 2 в ряд,
   длинное название — в 2 строки целыми словами (без переноса с дефисом) */
.ut2-pb .cm-picker-product-variation-features .ty-product-options__item .ty-clear-both {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  grid-auto-rows: 1fr;
  gap: 8px;
}
.ut2-pb .cm-picker-product-variation-features .ty-product-options__item .ty-product-options__radio--label {
  box-sizing: border-box;
  width: 100%;
  min-height: 40px;
  margin: 0;
  padding: 6px 10px;
  justify-content: center;
  align-items: center;
  text-align: center;
  line-height: 1.25;
}
.ut2-pb .cm-picker-product-variation-features .ty-product-options__radio--label,
.ut2-pb .cm-picker-product-variation-features .ty-product-options__radio--label * {
  -webkit-hyphens: manual !important;
  hyphens: manual !important;
  word-break: normal !important;
  overflow-wrap: normal !important;
}
@media (max-width: 767px) {
  .ut2-pb .cm-picker-product-variation-features .ty-product-options__item .ty-product-options__radio--label {
    padding: 6px 4px;
  }
}
</style>
{/literal}
