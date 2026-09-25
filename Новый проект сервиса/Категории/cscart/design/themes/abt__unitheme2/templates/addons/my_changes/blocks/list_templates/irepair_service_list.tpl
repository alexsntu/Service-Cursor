{* iRepair: список услуг категории — по образцу прайса старого сайта (.repairService-prices).
   Основан на blocks/list_templates/compact_list.tpl (UniTheme2), вёрстка строки заменена целиком.
   Строка: название (ссылка на услугу) | цена («от», если у услуги есть варианты) + срок | кнопка «Заказать ремонт»
   (открывает наш попап заявки: data-call-popup-trigger + data-service / data-price).
   На телефоне (≤650px) строка целиком ведёт на страницу услуги, справа стрелка — как на старом сайте. *}
{if $products}

    {$tmpl='short_list'}

    {if !$no_pagination}
        {include file="common/pagination.tpl"}
    {/if}

    {* заголовок блока: «Стоимость услуг по ремонту iPhone 17» — из названия категории («Ремонт iPhone 17») *}
    {$irp_sl_subject = $category_data.category|default:""|strip_tags|regex_replace:"/^\s*Ремонт\s+/u":""|trim}

    <div class="irepair-sl">
        {if $irp_sl_subject && !$no_sorting}
            <h2 class="irepair-sl__title">Стоимость услуг<br> по ремонту <span class="irepair-sl__nowrap">{$irp_sl_subject}</span></h2>
            <p class="irepair-sl__lead">В стоимость работы включена запчасть и работа мастера. Это окончательная цена. Диагностика в нашем сервисе осуществляется бесплатно.</p>
        {/if}

        <ul class="irepair-sl__list">
        {foreach from=$products item="product" name="products"}
            {$irp_sl_url = "products.view?product_id=`$product.product_id`"|fn_url}
            {$irp_sl_name = $product.product|strip_tags|trim}
            {* варианты услуги (AASP / OEM …) — товары группы вариаций; в списке их загружает модуль product_variations.
               Выводим только если вариантов больше одного, иначе строка как раньше. *}
            {$irp_sl_opts = []}
            {foreach $product.variation_features_variants|default:[] as $irp_sl_feature}
                {if $irp_sl_feature.variants|count > 1}
                    {* цен вариантов в этих данных нет — берём их одним запросом fn_get_products (вместе с дочерними вариациями) *}
                    {$irp_sl_ids = []}
                    {foreach $irp_sl_feature.variants as $irp_sl_v}
                        {if $irp_sl_v.product_id}{$irp_sl_ids[] = $irp_sl_v.product_id}{/if}
                    {/foreach}
                    {$irp_sl_found = ["pid" => $irp_sl_ids, "include_child_variations" => true, "status" => "A"]|fn_get_products}
                    {$irp_sl_prices = $irp_sl_found.0|default:[]}
                    {foreach $irp_sl_feature.variants as $irp_sl_v}
                        {if $irp_sl_v.product_id && $irp_sl_prices[$irp_sl_v.product_id]}
                            {$irp_sl_opts[] = [
                                "id" => $irp_sl_v.product_id,
                                "name" => $irp_sl_v.variant,
                                "price" => $irp_sl_prices[$irp_sl_v.product_id].price,
                                "variant_id" => $irp_sl_v.variant_id,
                                "active" => ($irp_sl_v.product_id == $product.product_id)
                            ]}
                        {/if}
                    {/foreach}
                    {break}
                {/if}
            {/foreach}
            {if $irp_sl_opts|count < 2}{$irp_sl_opts = []}{/if}
            {$irp_sl_active = ""}
            {foreach $irp_sl_opts as $irp_sl_o}{if $irp_sl_o.active}{$irp_sl_active = $irp_sl_o}{/if}{/foreach}
            {if $irp_sl_opts && !$irp_sl_active}{$irp_sl_active = $irp_sl_opts.0}{/if}

            <li class="irepair-sl__row{if $irp_sl_opts} irepair-sl__row--opts{/if}">
                <div class="irepair-sl__main">
                    <a class="irepair-sl__name" href="{$irp_sl_url}">{$irp_sl_name nofilter}</a>
                    {if $irp_sl_opts}
                        <div class="irepair-sl__opts" role="group" aria-label="Варианты услуги">
                            {$irp_sl_notes = []}
                            {foreach $irp_sl_opts as $irp_sl_o}
                                {$irp_sl_vdata = $irp_sl_o.variant_id|fn_get_product_feature_variant}
                                {$irp_sl_note = $irp_sl_vdata.description|default:""|strip_tags|trim}
                                {if $irp_sl_note}{$irp_sl_notes[$irp_sl_o.id] = $irp_sl_note}{/if}
                                <button type="button"
                                        class="irepair-sl__opt{if $irp_sl_o.id == $irp_sl_active.id} is-active{/if}"
                                        data-irp-opt="{$irp_sl_o.id}"
                                        data-service="{$irp_sl_name} | {$irp_sl_o.name}"
                                        data-price="{$irp_sl_o.price|intval}"
                                        aria-pressed="{if $irp_sl_o.id == $irp_sl_active.id}true{else}false{/if}">{$irp_sl_o.name}</button>
                            {/foreach}
                        </div>
                        {* пояснение к выбранному типу запчасти — «Описание» значения характеристики (как в карточке товара) *}
                        {foreach $irp_sl_notes as $irp_sl_note_id => $irp_sl_note}
                            <p class="irepair-sl__note" data-irp-opt-note="{$irp_sl_note_id}"{if $irp_sl_note_id != $irp_sl_active.id} hidden{/if}>{$irp_sl_note}</p>
                        {/foreach}
                    {/if}
                </div>

                <div class="irepair-sl__price">
                    {if $irp_sl_opts}
                        {* цена каждого варианта; видна цена выбранного *}
                        {foreach $irp_sl_opts as $irp_sl_o}
                            <p class="irepair-sl__price-value" data-irp-opt-price="{$irp_sl_o.id}"{if $irp_sl_o.id != $irp_sl_active.id} hidden{/if}>{include file="common/price.tpl" value=$irp_sl_o.price}</p>
                        {/foreach}
                    {else}
                        <p class="irepair-sl__price-value">{if $product.variation_group_id}от {/if}{include file="common/price.tpl" value=$product.price}</p>
                    {/if}
                    {* время ремонта — характеристика id 5 «Время ремонта» (в списке категории CS-Cart характеристики не грузит — берём сами) *}
                    {$irp_sl_features = ["product_id" => $product.product_id]|fn_get_product_features_list:"A"}
                    {if $irp_sl_features.5.value}
                        <span class="irepair-sl__time">{$irp_sl_features.5.value}</span>
                    {/if}
                </div>

                <div class="irepair-sl__action">
                    <a class="irepair-sl__btn" href="{$irp_sl_url}"
                       data-call-popup-trigger
                       data-service="{if $irp_sl_opts}{$irp_sl_name} | {$irp_sl_active.name}{else}{$irp_sl_name}{/if}"
                       data-price="{if $irp_sl_opts}{$irp_sl_active.price|intval}{else}{$product.price|intval}{/if}"><span>Заказать ремонт</span></a>
                </div>

                {* телефон: вся строка — ссылка на услугу (кнопки вариантов — поверх неё) *}
                <a class="irepair-sl__row-link" href="{$irp_sl_url}" aria-label="{$irp_sl_name}">
                    <svg width="10" height="18" viewBox="0 0 10 18" fill="none" aria-hidden="true"><path d="M1.5 1.5L8.5 9L1.5 16.5" stroke="#b5b5b5" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
                </a>
            </li>
        {/foreach}
        </ul>
    </div>

    {if !$no_pagination}
        {include file="common/pagination.tpl" force_ajax=$force_ajax}
    {/if}

{literal}
<style>
.irepair-sl,
.irepair-sl * {
  box-sizing: border-box;
}
.irepair-sl {
  /* ширина как у баннеров главной (.g-wrapper): максимум 1370px по центру, поля 35px → контент до 1300px */
  max-width: 1370px;
  margin: 0 auto 40px;
  padding: 0 35px;
  /* как на старом сайте: Roboto (на новом сайте загружены Roboto 400/500, Montserrat-Bold/Medium; SemiBold нет) */
  font-family: 'Roboto', Arial, sans-serif;
}
.irepair-sl .irepair-sl__title {
  max-width: 700px;
  margin: 0 auto;
  font-family: 'Montserrat-Medium', Arial, sans-serif;
  font-size: 36px;
  line-height: 44px;
  font-weight: 400;
  text-align: center;
  color: #010306;
}
.irepair-sl .irepair-sl__nowrap {
  white-space: nowrap;
}
.irepair-sl .irepair-sl__lead {
  max-width: 600px;
  margin: 12px auto 0;
  font-size: 16px;
  line-height: 23px;
  font-weight: 300;
  text-align: center;
  color: #5c5b5b;
}
.irepair-sl .irepair-sl__list {
  margin: 40px 0 0;
  padding: 0;
  list-style: none;
}
.irepair-sl .irepair-sl__row {
  position: relative;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  grid-gap: 20px;
  margin: 0;
  padding: 16px 0;
  border-bottom: 1px solid #dddddd;
  list-style: none;
}
.irepair-sl .irepair-sl__row:last-child {
  border-bottom: 0;
}
.irepair-sl .irepair-sl__row::before {
  content: none;
}
.irepair-sl .irepair-sl__main {
  grid-column: 1 / 8;
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-width: 0;
}
.irepair-sl .irepair-sl__name {
  display: flex;
  align-items: center;
  font-size: 24px;
  line-height: 28px;
  font-weight: 300;
  color: #010306;
  text-decoration: none;
  transition: color 0.2s ease;
}
.irepair-sl .irepair-sl__name:hover {
  color: #37d97b;
}
.irepair-sl .irepair-sl__price {
  grid-column: 8 / 10;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.irepair-sl .irepair-sl__price-value {
  margin: 0;
  font-family: 'Montserrat-Bold', 'Montserrat-SemiBold', Arial, sans-serif;
  font-size: 24px;
  line-height: 24px;
  font-weight: 400;
  color: #010306;
  white-space: nowrap;
}
.irepair-sl .irepair-sl__time {
  display: inline-block;
  margin-top: 4px;
  font-size: 14px;
  line-height: 23px;
  color: #939393;
}
.irepair-sl .irepair-sl__price-value .ty-price,
.irepair-sl .irepair-sl__price-value .ty-price-num {
  font: inherit;
  color: inherit;
}
.irepair-sl .irepair-sl__action {
  grid-column: 11 / 13;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}
.irepair-sl .irepair-sl__btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 10px 26px;
  /* скругление как у кнопки «Оформить заявку» в карточке товара (40px) */
  border-radius: 40px;
  background: linear-gradient(103.87deg, #36d97b 29.3%, #19d4e0 96.89%);
  background-size: 200% 100%;
  font-size: 16px;
  line-height: 16px;
  font-weight: 500;
  color: #ffffff;
  white-space: nowrap;
  text-decoration: none;
  transition: background-position 0.3s ease;
}
.irepair-sl .irepair-sl__btn:hover {
  color: #ffffff;
  background-position: 100% 0;
}
.irepair-sl .irepair-sl__row-link {
  display: none;
}
/* варианты услуги (AASP / OEM …) — «таблетки» как опции в карточке товара */
.irepair-sl .irepair-sl__opts {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.irepair-sl .irepair-sl__opt {
  margin: 0;
  padding: 6px 16px;
  border: 1px solid #d9d9d9;
  border-radius: 40px;
  background: #ffffff;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 14px;
  line-height: 18px;
  font-weight: 500;
  color: #555555;
  cursor: pointer;
  transition: border-color 0.2s ease, background-color 0.2s ease, color 0.2s ease;
  -webkit-tap-highlight-color: transparent;
}
.irepair-sl .irepair-sl__opt:hover {
  border-color: #37d97b;
  color: #010306;
}
.irepair-sl .irepair-sl__opt.is-active {
  border-color: #37d97b;
  background: #eefaf3;
  color: #010306;
}
.irepair-sl .irepair-sl__price-value[hidden],
.irepair-sl .irepair-sl__note[hidden] {
  display: none;
}
.irepair-sl .irepair-sl__note {
  margin: 8px 0 0;
  padding: 0;
  font-size: 13px;
  line-height: 18px;
  color: #7a7a7a;
}

@media (max-width: 1180px) {
  .irepair-sl .irepair-sl__title {
    max-width: 370px;
    font-size: 36px;
    line-height: 40px;
  }
  .irepair-sl .irepair-sl__lead {
    max-width: 461px;
    margin-top: 16px;
    line-height: 20px;
  }
  .irepair-sl .irepair-sl__list {
    margin-top: 32px;
  }
  .irepair-sl .irepair-sl__main {
    grid-column: 1 / 6;
  }
  .irepair-sl .irepair-sl__name {
    font-size: 18px;
    line-height: 22px;
  }
  .irepair-sl .irepair-sl__price {
    grid-column: 6 / 9;
  }
  .irepair-sl .irepair-sl__price-value {
    font-size: 20px;
    line-height: 20px;
  }
  .irepair-sl .irepair-sl__action {
    grid-column: 9 / 13;
  }
}

@media (max-width: 767px) {
  /* на телефоне поля даёт контейнер CS-Cart (~16px, как на старом сайте) — свои не добавляем */
  .irepair-sl {
    padding: 0;
  }
}

@media (max-width: 650px) {
  /* телефон — по образцу мобильной версии старого сайта */
  .irepair-sl .irepair-sl__title {
    max-width: 253px;
    font-family: 'Montserrat-Bold', Arial, sans-serif;
    font-size: 24px;
    line-height: 28px;
  }
  .irepair-sl .irepair-sl__lead {
    max-width: 340px;
    margin-top: 16px;
    font-size: 14px;
    line-height: 20px;
    color: #939393;
  }
  .irepair-sl .irepair-sl__list {
    margin-top: 36px;
  }
  .irepair-sl .irepair-sl__row {
    display: flex;
    flex-direction: column;
    grid-gap: 0;
    padding: 18px 14px 18px 0;
  }
  .irepair-sl .irepair-sl__name {
    font-size: 24px;
    line-height: 28px;
    font-weight: 300;
  }
  .irepair-sl .irepair-sl__price {
    margin-top: 6px;
  }
  .irepair-sl .irepair-sl__price-value {
    font-size: 16px;
    line-height: 20px;
  }
  .irepair-sl .irepair-sl__time {
    margin-top: 2px;
    font-size: 12px;
    line-height: 16px;
  }
  .irepair-sl .irepair-sl__action {
    display: none;
  }
  .irepair-sl .irepair-sl__opts {
    position: relative;
    z-index: 3;
    margin-top: 8px;
  }
  .irepair-sl .irepair-sl__opt {
    padding: 6px 14px;
    font-size: 13px;
  }
  /* телефон, услуга с вариантами: варианты и цена — на одной строке под названием */
  .irepair-sl .irepair-sl__row.irepair-sl__row--opts {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    column-gap: 14px;
    align-items: start;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__main {
    display: contents;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__name {
    grid-column: 1 / -1;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__opts {
    grid-column: 1;
    margin-top: 8px;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__price {
    grid-column: 2;
    margin-top: 8px;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__price-value {
    /* по высоте «таблетки» варианта — цена на одной линии с ней */
    line-height: 32px;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__time {
    margin-top: 0;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__note {
    grid-column: 1 / -1;
    grid-row: 3;
    font-size: 12px;
    line-height: 16px;
  }
  .irepair-sl .irepair-sl__row-link {
    position: absolute;
    top: 0;
    left: 0;
    z-index: 2;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    width: 100%;
    height: 100%;
    padding-right: 2px;
  }
}
</style>
<script>
/* iRepair: переключение вариантов услуги в прайсе — цена в строке и данные для кнопки «Заказать ремонт» */
(function () {
  if (window.irepairSlOpts) return;
  window.irepairSlOpts = true;
  document.addEventListener('click', function (e) {
    var opt = e.target.closest ? e.target.closest('.irepair-sl__opt') : null;
    if (!opt) return;
    e.preventDefault();
    e.stopPropagation();
    var row = opt.closest('.irepair-sl__row');
    if (!row) return;
    var id = opt.getAttribute('data-irp-opt');
    row.querySelectorAll('.irepair-sl__opt').forEach(function (b) {
      var on = b === opt;
      b.classList.toggle('is-active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    row.querySelectorAll('[data-irp-opt-price]').forEach(function (p) {
      p.hidden = p.getAttribute('data-irp-opt-price') !== id;
    });
    row.querySelectorAll('[data-irp-opt-note]').forEach(function (n) {
      n.hidden = n.getAttribute('data-irp-opt-note') !== id;
    });
    var btn = row.querySelector('.irepair-sl__btn');
    if (btn) {
      btn.setAttribute('data-service', opt.getAttribute('data-service'));
      btn.setAttribute('data-price', opt.getAttribute('data-price'));
    }
  }, true);
})();
</script>
{/literal}

{/if}
