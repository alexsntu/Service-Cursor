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
            {* услуга с двумя и более выборами (MacBook: модель × тип запчасти) — «сетка» группы вариаций:
               все включённые товары группы с их значениями (fn_my_changes_irepair_variation_matrix, app/addons/my_changes/func.php).
               У iPhone в группе одна характеристика — там прежняя логика ниже. *}
            {$irp_sl_mx = []}
            {if $product.variation_group_id}{$irp_sl_mx = $product.variation_group_id|fn_my_changes_irepair_variation_matrix}{/if}
            {$irp_sl_mx_on = ($irp_sl_mx.features|default:[]|count > 1 && $irp_sl_mx.products|count > 1 && $irp_sl_mx.products[$product.product_id])}
            {$irp_sl_opts = []}
            {* Глобально (владелец 2026-10-02): в списке категории показываем только выбор типа запчасти (характеристика-плитки,
               feature_style dropdown_labels); модель, конфигурацию, размер корпуса и др. — нет. У каждого типа цена самой
               дешёвой конфигурации с «от». В карточке товара все выборы остаются. *}
            {$irp_sl_cfg = false}
            {$irp_sl_hide = false}
            {$irp_sl_tiles = false}
            {foreach $irp_sl_mx.features|default:[] as $irp_sl_fid => $irp_sl_f}
                {if $irp_sl_f.style == "dropdown_labels"}{$irp_sl_tiles = true}{else}{$irp_sl_hide = true}{/if}
            {/foreach}
            {if $irp_sl_mx_on && $irp_sl_hide && $irp_sl_tiles}
                {$irp_sl_cfg = true}
                {$irp_sl_mx_on = false}
                {foreach $irp_sl_mx.features as $irp_sl_fid => $irp_sl_f}
                    {if $irp_sl_f.style == "dropdown_labels"}
                        {foreach $irp_sl_f.variants as $irp_sl_vid => $irp_sl_v}
                            {$irp_sl_best = 0}
                            {$irp_sl_bestp = 0}
                            {foreach $irp_sl_mx.products as $irp_sl_pid => $irp_sl_p}
                                {if $irp_sl_p.values[$irp_sl_fid] == $irp_sl_vid && (!$irp_sl_best || $irp_sl_p.price < $irp_sl_bestp)}
                                    {$irp_sl_best = $irp_sl_pid}
                                    {$irp_sl_bestp = $irp_sl_p.price}
                                {/if}
                            {/foreach}
                            {if $irp_sl_best}
                                {$irp_sl_opts[] = [
                                    "id" => $irp_sl_best,
                                    "name" => $irp_sl_v.name,
                                    "price" => $irp_sl_bestp,
                                    "variant_id" => $irp_sl_vid,
                                    "active" => ($irp_sl_vid == $irp_sl_mx.products[$product.product_id].values[$irp_sl_fid])
                                ]}
                            {/if}
                        {/foreach}
                    {/if}
                {/foreach}
            {/if}
            {if !$irp_sl_mx_on && !$irp_sl_cfg}
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
            {/if}
            {if $irp_sl_opts|count < 2}{$irp_sl_opts = []}{/if}
            {if $irp_sl_mx_on}
                {* выбранный по умолчанию товар — тот, что в списке (главный = самый дешёвый); подпись услуги — «название | модель | тип» *}
                {$irp_sl_mx_cur = $irp_sl_mx.products[$product.product_id]}
                {$irp_sl_mx_label = []}
                {foreach $irp_sl_mx.products as $irp_sl_pid => $irp_sl_p}
                    {$irp_sl_parts = [$irp_sl_name]}
                    {foreach $irp_sl_mx.features as $irp_sl_fid => $irp_sl_f}
                        {if $irp_sl_p.values[$irp_sl_fid]}{$irp_sl_parts[] = $irp_sl_f.variants[$irp_sl_p.values[$irp_sl_fid]].name}{/if}
                    {/foreach}
                    {$irp_sl_mx_label[$irp_sl_pid] = " | "|implode:$irp_sl_parts}
                {/foreach}
            {/if}
            {$irp_sl_active = ""}
            {foreach $irp_sl_opts as $irp_sl_o}{if $irp_sl_o.active}{$irp_sl_active = $irp_sl_o}{/if}{/foreach}
            {if $irp_sl_opts && !$irp_sl_active}{$irp_sl_active = $irp_sl_opts.0}{/if}

            <li class="irepair-sl__row{if $irp_sl_opts} irepair-sl__row--opts{/if}{if $irp_sl_opts|count > 2 || $irp_sl_mx_on} irepair-sl__row--opts-many{/if}{if $irp_sl_mx_on} irepair-sl__row--mx{/if}">
                <div class="irepair-sl__main">
                    <a class="irepair-sl__name" href="{$irp_sl_url}">{$irp_sl_name nofilter}</a>
                    {if $irp_sl_mx_on}
                        {* по ряду «таблеток» на каждый выбор, где значений больше одного *}
                        {foreach $irp_sl_mx.features as $irp_sl_fid => $irp_sl_f}
                            {if $irp_sl_f.variants|count > 1}
                                <div class="irepair-sl__opts" role="group" aria-label="{$irp_sl_f.name}">
                                    {foreach $irp_sl_f.variants as $irp_sl_vid => $irp_sl_v}
                                        <button type="button"
                                                class="irepair-sl__opt{if $irp_sl_mx_cur.values[$irp_sl_fid] == $irp_sl_vid} is-active{/if}"
                                                data-irp-mx-f="{$irp_sl_fid}" data-irp-mx-v="{$irp_sl_vid}"
                                                aria-pressed="{if $irp_sl_mx_cur.values[$irp_sl_fid] == $irp_sl_vid}true{else}false{/if}">{$irp_sl_v.name}</button>
                                    {/foreach}
                                </div>
                            {/if}
                        {/foreach}
                        {* пояснения к значениям (тип запчасти) — видно пояснение значения выбранного товара *}
                        {foreach $irp_sl_mx.features as $irp_sl_fid => $irp_sl_f}
                            {foreach $irp_sl_f.variants as $irp_sl_vid => $irp_sl_v}
                                {if $irp_sl_v.note && $irp_sl_f.variants|count > 1}
                                    <p class="irepair-sl__note" data-irp-mx-note="{$irp_sl_fid}:{$irp_sl_vid}"{if $irp_sl_mx_cur.values[$irp_sl_fid] != $irp_sl_vid} hidden{/if}>{$irp_sl_v.note}</p>
                                {/if}
                            {/foreach}
                        {/foreach}
                    {elseif $irp_sl_opts}
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

                {* характеристики товара (в списке категории CS-Cart их не грузит — берём сами): 5 «Время ремонта», 19 «Цена «от»» *}
                {$irp_sl_features = ["product_id" => $product.product_id]|fn_get_product_features_list:"A"}
                {$irp_sl_from = ($irp_sl_features.19.value == "Y")}
                {* «от» у группы вариантов — только если в ней больше одного товара (у групп из одного товара цена точная) *}
                {$irp_sl_vcount = 0}
                {foreach $product.variation_features_variants|default:[] as $irp_sl_vf}
                    {$irp_sl_vc = 0}
                    {foreach $irp_sl_vf.variants as $irp_sl_vv}{if $irp_sl_vv.product.product_id}{$irp_sl_vc = $irp_sl_vc + 1}{/if}{/foreach}
                    {if $irp_sl_vc > $irp_sl_vcount}{$irp_sl_vcount = $irp_sl_vc}{/if}
                {/foreach}
                <div class="irepair-sl__price">
                    {if $irp_sl_mx_on}
                        {* цена каждого товара группы (видна выбранного) + его значения и подпись для кнопки заявки *}
                        {foreach $irp_sl_mx.products as $irp_sl_pid => $irp_sl_p}
                            {$irp_sl_vals = []}
                            {foreach $irp_sl_p.values as $irp_sl_fid => $irp_sl_vid}{$irp_sl_vals[] = "`$irp_sl_fid`:`$irp_sl_vid`"}{/foreach}
                            <p class="irepair-sl__price-value" data-irp-mx-p="{$irp_sl_pid}" data-irp-mx-vals="{","|implode:$irp_sl_vals}"
                               data-service="{$irp_sl_mx_label[$irp_sl_pid]}" data-price="{$irp_sl_p.price|intval}"{if $irp_sl_pid != $product.product_id} hidden{/if}>{if $irp_sl_from}от {/if}{include file="common/price.tpl" value=$irp_sl_p.price}</p>
                        {/foreach}
                    {elseif $irp_sl_opts}
                        {* цена каждого варианта; видна цена выбранного *}
                        {foreach $irp_sl_opts as $irp_sl_o}
                            <p class="irepair-sl__price-value" data-irp-opt-price="{$irp_sl_o.id}"{if $irp_sl_o.id != $irp_sl_active.id} hidden{/if}>{if $irp_sl_from || $irp_sl_cfg}от {/if}{include file="common/price.tpl" value=$irp_sl_o.price}</p>
                        {/foreach}
                    {else}
                        <p class="irepair-sl__price-value">{if ($product.variation_group_id && $irp_sl_vcount > 1) || $irp_sl_from}от {/if}{include file="common/price.tpl" value=$product.price}</p>
                    {/if}
                    {* время ремонта — характеристика id 5 (загружены выше) *}
                    {if $irp_sl_features.5.value}
                        <span class="irepair-sl__time">{$irp_sl_features.5.value}</span>
                    {/if}
                </div>

                <div class="irepair-sl__action">
                    <a class="irepair-sl__btn" href="{$irp_sl_url}"
                       data-call-popup-trigger
                       data-service="{if $irp_sl_mx_on}{$irp_sl_mx_label[$product.product_id]}{elseif $irp_sl_opts}{$irp_sl_name} | {$irp_sl_active.name}{else}{$irp_sl_name}{/if}"
                       data-price="{if $irp_sl_mx_on}{$irp_sl_mx_cur.price|intval}{elseif $irp_sl_opts}{$irp_sl_active.price|intval}{else}{$product.price|intval}{/if}"><span>Заказать ремонт</span></a>
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
.irepair-sl .irepair-sl__opt.is-na {
  border-style: dashed;
  color: #b5b5b5;
}
.irepair-sl .irepair-sl__row--mx .irepair-sl__opts + .irepair-sl__opts {
  margin-top: 8px;
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
    grid-row: 2;
    margin-top: 8px;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__price {
    grid-column: 2;
    grid-row: 2;
    margin-top: 8px;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__price-value {
    /* ровно по центру «таблетки» варианта (её высота 32px), цена крупнее */
    display: flex;
    align-items: center;
    height: 32px;
    font-size: 20px;
    line-height: 1;
  }
  .irepair-sl .irepair-sl__row--opts .irepair-sl__price-value[hidden] {
    display: none;
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
  /* 3–4 варианта (максимум у нас 4) в одну строку с ценой не помещаются: варианты — вся строка, цена — под ними */
  .irepair-sl .irepair-sl__row--opts-many .irepair-sl__opts {
    grid-column: 1 / -1;
  }
  .irepair-sl .irepair-sl__row--opts-many .irepair-sl__price {
    grid-column: 1 / -1;
    grid-row: 3;
    margin-top: 6px;
  }
  .irepair-sl .irepair-sl__row--opts-many .irepair-sl__note {
    grid-row: 4;
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
    if (opt.hasAttribute('data-irp-mx-f')) {
      e.preventDefault();
      e.stopPropagation();
      irpSlMatrix(opt);
      return;
    }
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

  /* услуга с двумя выборами (модель × тип запчасти): ищем товар с выбранными значениями;
     если такого сочетания нет — ближайший (совпадает нажатое значение и больше всего остальных) */
  function vals(el) {
    var o = {};
    (el.getAttribute('data-irp-mx-vals') || '').split(',').forEach(function (pair) {
      var kv = pair.split(':');
      if (kv[1]) o[kv[0]] = kv[1];
    });
    return o;
  }
  function irpSlMatrix(opt) {
    var row = opt.closest('.irepair-sl__row');
    if (!row) return;
    var f = opt.getAttribute('data-irp-mx-f');
    var v = opt.getAttribute('data-irp-mx-v');
    var prices = Array.prototype.slice.call(row.querySelectorAll('[data-irp-mx-p]'));
    var cur = prices.filter(function (p) { return !p.hidden; })[0] || prices[0];
    var want = vals(cur);
    want[f] = v;
    var best = null, bestScore = -1;
    prices.forEach(function (p) {
      var pv = vals(p);
      if (pv[f] !== v) return;
      var score = 0;
      Object.keys(want).forEach(function (k) { if (pv[k] === want[k]) score++; });
      if (score > bestScore) { best = p; bestScore = score; }
    });
    if (!best) return;
    irpSlMatrixShow(row, best, prices);
  }
  function irpSlMatrixShow(row, sel, prices) {
    var sv = vals(sel);
    prices.forEach(function (p) { p.hidden = p !== sel; });
    row.querySelectorAll('[data-irp-mx-f]').forEach(function (b) {
      var bf = b.getAttribute('data-irp-mx-f'), bv = b.getAttribute('data-irp-mx-v');
      var on = sv[bf] === bv;
      b.classList.toggle('is-active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
      /* есть ли товар с этим значением при прочих выбранных — иначе «таблетка» бледная (нажать можно) */
      var ok = prices.some(function (p) {
        var pv = vals(p);
        if (pv[bf] !== bv) return false;
        return Object.keys(sv).every(function (k) { return k === bf || pv[k] === sv[k]; });
      });
      b.classList.toggle('is-na', !ok && !on);
    });
    row.querySelectorAll('[data-irp-mx-note]').forEach(function (n) {
      var kv = n.getAttribute('data-irp-mx-note').split(':');
      n.hidden = sv[kv[0]] !== kv[1];
    });
    var btn = row.querySelector('.irepair-sl__btn');
    if (btn) {
      btn.setAttribute('data-service', sel.getAttribute('data-service'));
      btn.setAttribute('data-price', sel.getAttribute('data-price'));
    }
  }
  /* при загрузке — отметить недоступные сочетания для выбранного по умолчанию */
  function irpSlMatrixInit() {
    document.querySelectorAll('.irepair-sl__row--mx').forEach(function (row) {
      var prices = Array.prototype.slice.call(row.querySelectorAll('[data-irp-mx-p]'));
      var cur = prices.filter(function (p) { return !p.hidden; })[0];
      if (cur) irpSlMatrixShow(row, cur, prices);
    });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', irpSlMatrixInit);
  } else {
    irpSlMatrixInit();
  }
})();
</script>
{/literal}

{/if}
