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
            <li class="irepair-sl__row">
                <a class="irepair-sl__name" href="{$irp_sl_url}">{$irp_sl_name nofilter}</a>

                <div class="irepair-sl__price">
                    <p class="irepair-sl__price-value">{if $product.variation_group_id}от {/if}{include file="common/price.tpl" value=$product.price}</p>
                    {* время ремонта — характеристика id 5 «Время ремонта» (в списке категории CS-Cart характеристики не грузит — берём сами) *}
                    {$irp_sl_features = ["product_id" => $product.product_id]|fn_get_product_features_list:"A"}
                    {if $irp_sl_features.5.value}
                        <span class="irepair-sl__time">{$irp_sl_features.5.value}</span>
                    {/if}
                </div>

                <div class="irepair-sl__action">
                    <a class="irepair-sl__btn" href="{$irp_sl_url}"
                       data-call-popup-trigger
                       data-service="{$irp_sl_name}"
                       data-price="{$product.price|intval}"><span>Заказать ремонт</span></a>
                </div>

                {* телефон: вся строка — ссылка на услугу *}
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
  font-size: 48px;
  line-height: 56px;
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
.irepair-sl .irepair-sl__name {
  grid-column: 1 / 8;
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
  .irepair-sl .irepair-sl__name {
    grid-column: 1 / 6;
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
{/literal}

{/if}
