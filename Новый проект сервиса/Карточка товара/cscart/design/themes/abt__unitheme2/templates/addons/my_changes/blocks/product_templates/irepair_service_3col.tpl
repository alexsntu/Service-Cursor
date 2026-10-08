{** template-description:irepair_service_3col **}
{* iRepair: пробный макет карточки услуги в три колонки — на основе шаблона UniTheme2 «AB: Трехколоночный»
   (abt__ut2_three_columns_template.tpl), элементы расставлены как в карточке услуги старого сайта:
     заголовок на всю ширину;
     1-я колонка — фото;
     2-я колонка — выбор варианта (тип запчасти, модель), пояснение к варианту, преимущества (ремонт / курьер / гарантия);
     3-я колонка — серая плашка «вернём баллами» + «К оплате: цена», под ней кнопка «Оформить заявку».
   Наши компоненты те же, что в шаблоне «iRepair — Услуга» (irepair_service_template.tpl).
   На телефоне выводится прежняя мобильная карточка (irepair_service_mobile.tpl) — этот макет только для компьютера. *}
{script src="js/tygh/exceptions.js"}

{if $settings.ab__device !== "mobile"}

    {assign var="pd_image_gallery_width" value=$settings.abt__ut2.products.view.image_width[$settings.ab__device]|default:$settings.Thumbnails.product_details_thumbnail_width|default:430}
    {assign var="pd_image_gallery_height" value=$settings.abt__ut2.products.view.image_height[$settings.ab__device]|default:$settings.Thumbnails.product_details_thumbnail_height|default:430}

    {$is_add_to_cart_mv=true}
    {$abt__shareb_mute=true}
    {if "MULTIVENDOR"|fn_allowed_for && ($product.master_product_id || !$product.company_id)}{$is_add_to_cart_mv=false}{/if}

    {hook name="products:ab__product_images_count"}
        {$product_images_count = $product.image_pairs|@count}
    {/hook}

    <div class="ut2-pb ty-product-block irepair-card3{if $product_images_count < 1} --single{/if}" style="--pd-image-gallery-width: {$pd_image_gallery_width};--pd-image-gallery-height: {$pd_image_gallery_height}">

        <div class="ut2-breadcrumbs__wrapper">
            {hook name="products:ut2_main_info_breadcrumbs"}
                {include file="common/breadcrumbs.tpl"}
            {/hook}
        </div>

        {hook name="products:view_main_info"}
            {if $product}
                {assign var="obj_id" value=$product.product_id}
                {* флаг для нашего шаблона выбора вариаций (overrides/addons/product_variations/…/product_option_content.pre.tpl):
                   короткая подпись и цена в плитке варианта *}
                {$irp_card3 = true}
                {* iRepair: hide_compare_list_button=true — без кнопки «Сравнить» в карточке услуги *}
                {include file="common/product_data.tpl" product=$product but_role="big" but_text=__("add_to_cart") product_labels_position="right-top" hide_qty_label=true hide_compare_list_button=true}

                <div class="ut2-pb__wrapper clearfix">
                    {assign var="form_open" value="form_open_`$obj_id`"}
                    {$smarty.capture.$form_open nofilter}

                    {assign var="old_price" value="old_price_`$obj_id`"}
                    {assign var="price" value="price_`$obj_id`"}
                    {assign var="clean_price" value="clean_price_`$obj_id`"}
                    {assign var="list_discount" value="list_discount_`$obj_id`"}
                    {assign var="discount_label" value="discount_label_`$obj_id`"}

                    {* заголовок — на всю ширину над колонками, как на старом сайте *}
                    <div class="irepair-card3__title ut2-pb__title">
                        {if !$hide_title}
                            <h1 {live_edit name="product:product:{$product.product_id}"}>{$product.product nofilter}</h1>
                        {/if}
                        {* код услуги — под названием *}
                        {if $show_sku == "true" && $product.product_code|trim}
                            <div class="ut2-pb__sku irepair-card3__sku">
                                {assign var="sku" value="sku_`$obj_id`"}
                                {$smarty.capture.$sku nofilter}
                            </div>
                        {/if}
                    </div>

                    <div class="irepair-card3__grid">

                        {* 1-я колонка: фото *}
                        <div class="irepair-card3__media">
                            {hook name="products:image_wrap"}
                            {if !$no_images}
                                <div class="ut2-pb__img cm-reload-{$product.product_id} images-1" data-ca-previewer="true" id="product_images_{$product.product_id}_update">
                                    {include file="views/products/components/product_images.tpl" product=$product show_detailed_link="Y" image_width=$pd_image_gallery_width image_height=$pd_image_gallery_height lazy_load=false}
                                    <!--product_images_{$product.product_id}_update--></div>
                            {/if}
                            {/hook}
                        </div>

                        {* 2-я колонка: варианты, пояснение, преимущества *}
                        <div class="irepair-card3__mid">
                            {if $capture_options_vs_qty}{capture name="product_options"}{$smarty.capture.product_options nofilter}{/if}
                            <div class="ut2-pb__options">
                                {assign var="product_options" value="product_options_`$obj_id`"}
                                {$smarty.capture.$product_options nofilter}
                                {* расшифровка выбранной опции под опциями *}
                                {include file="addons/my_changes/components/irepair_variant_note.tpl"}
                            </div>
                            {if $capture_options_vs_qty}{/capture}{/if}

                            {assign var="product_edp" value="product_edp_`$obj_id`"}
                            {$smarty.capture.$product_edp nofilter}

                            {* преимущества: ремонт / курьер / гарантия *}
                            {include file="addons/my_changes/components/irepair_product_promo.tpl"}

                            {hook name="products:promo_text"}
                            {if $product.promo_text}
                                <div class="ut2-pb__note">
                                    {$product.promo_text nofilter}
                                </div>
                            {/if}
                            {/hook}
                        </div>

                        {* 3-я колонка: баллы + цена, кнопка *}
                        <div class="irepair-card3__side">
                            <div class="irepair-card3__box">
                                {* бонусные баллы «N вернем баллами» *}
                                {include file="addons/my_changes/components/irepair_reward_points.tpl"}

                                <div class="irepair-card3__pay">
                                    <span class="irepair-card3__pay-label">К оплате:</span>
                                    {* характеристика 19 «Цена «от»» — цена ориентировочная, CSS (irepair-old-header.css) пишет «от» перед ценой *}
                                    {$irp_pf = ["product_id" => $product.product_id]|fn_get_product_features_list:"A"}
                                    <div class="irepair-card3__pay-price{if $irp_pf.19.value == "Y"} irepair-price-from{/if}">
                                        {include file="blocks/product_templates/components/product_price.tpl"}
                                    </div>
                                </div>
                            </div>

                            <div class="ut2-pb__advanced-options">
                                {if $capture_options_vs_qty}{capture name="product_options"}{$smarty.capture.product_options nofilter}{/if}
                                {assign var="advanced_options" value="advanced_options_`$obj_id`"}
                                {$smarty.capture.$advanced_options nofilter}
                                {if $capture_options_vs_qty}{/capture}{/if}
                            </div>

                            {if $capture_buttons}{capture name="buttons"}{/if}
                            <div class="ut2-pb__button ty-product-block__button">
                                {if $show_details_button}
                                    {include file="buttons/button.tpl" but_href="products.view?product_id=`$product.product_id`" but_text=__("view_details") but_role="submit"}
                                {/if}

                                {assign var="add_to_cart" value="add_to_cart_`$obj_id`"}
                                {$smarty.capture.$add_to_cart nofilter}

                                {assign var="list_buttons" value="list_buttons_`$obj_id`"}
                                {$smarty.capture.$list_buttons nofilter}

                                {* своё окно «Поделиться» (стандартное от темы скрыто стилями ниже) *}
                                {include file="addons/my_changes/components/irepair_share.tpl"}
                            </div>
                            {if $capture_buttons}{/capture}{/if}

                            {* «Оформить заявку» открывает попап заявки вместо корзины *}
                            {include file="addons/my_changes/components/irepair_lead_button.tpl"}

                            {hook name="products:ab__motivation_block"}{/hook}
                        </div>
                    </div>

                    {hook name="products:product_form_close_tag"}
                    {$form_close="form_close_`$obj_id`"}
                    {$smarty.capture.$form_close nofilter}
                    {/hook}

                    {if $show_product_tabs}
                        {include file="views/tabs/components/product_popup_tabs.tpl"}
                        {$smarty.capture.popupsbox_content nofilter}
                    {/if}

                    <div class="ut2-pb__tabs-wrapper">

                        {if $settings.abt__ut2.products.custom_block_id|intval}
                            <div class="ut2-pb__custom-block">
                                {render_block block_id=$settings.abt__ut2.products.custom_block_id|intval dispatch="products.view" use_cache=false parse_js=false}
                            </div>
                        {/if}

                        {hook name="products:buy_together"}{/hook}

                        {hook name="products:product_tabs_pre"}
                            <div class="ut2-pb__tabs{if $settings.Appearance.product_details_in_tab === "YesNo::NO"|enum} tabs-list{/if}">
                                {if $show_product_tabs}
                                    {hook name="products:product_tabs"}
                                        {include file="views/tabs/components/product_tabs.tpl"}

                                    {if $blocks.$tabs_block_id.properties.wrapper}
                                        {include file=$blocks.$tabs_block_id.properties.wrapper content=$smarty.capture.tabsbox_content title=$blocks.$tabs_block_id.description}
                                    {else}
                                        {$smarty.capture.tabsbox_content nofilter}
                                    {/if}
                                    {/hook}
                                {/if}
                            </div>
                        {/hook}
                    </div>

                    {hook name="products:product_detail_bottom"}{/hook}

                </div>
            {/if}
        {/hook}

        {if $smarty.capture.hide_form_changed == "Y"}
            {assign var="hide_form" value=$smarty.capture.orig_val_hide_form}
        {/if}

        {hook name="products:bottom_product_layer"}{/hook}
    </div>

    <div class="product-details">
    </div>

    {capture name="mainbox_title"}{assign var="details_page" value=true}{/capture}

{literal}
<style>
/* iRepair: макет карточки услуги в три колонки (только компьютер) */
/* тема раскладывает .ut2-pb__wrapper сеткой в две колонки — здесь колонки свои */
.irepair-card3 .ut2-pb__wrapper {
  display: block;
}
.irepair-card3 .irepair-card3__title {
  float: none;
  width: auto;
  margin: 8px 0 32px;
  padding: 0;
}
.irepair-card3 .irepair-card3__sku {
  margin: 8px 0 0;
  padding: 0;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 13px;
  line-height: 18px;
  color: #86868b;
}
.irepair-card3 .irepair-card3__title h1 {
  margin: 0;
  padding: 0;
  font-family: 'Montserrat-SemiBold', 'Montserrat-Bold', Arial, sans-serif;
  font-size: 24px;
  line-height: 1.25;
  font-weight: 400;
  color: #010306;
}
.irepair-card3 .irepair-card3__grid {
  display: grid;
  grid-template-columns: minmax(0, 0.9fr) minmax(0, 1fr) minmax(0, 420px);
  gap: 20px 56px;
  align-items: start;
  margin-bottom: 64px;
}
.irepair-card3 .irepair-card3__media,
.irepair-card3 .irepair-card3__mid,
.irepair-card3 .irepair-card3__side {
  min-width: 0;
}

/* 1-я колонка: фото */
.irepair-card3 .irepair-card3__media .ut2-pb__img {
  float: none;
  width: 100%;
  max-width: 100%;
  margin: 0;
  padding: 0;
}

/* 2-я колонка */
.irepair-card3 .irepair-card3__mid .ut2-pb__options {
  margin: 0 0 28px;
}
.irepair-card3 .irepair-card3__mid .irepair-product-promo {
  margin: 0;
}

/* плитки вариантов: название и цена, выбранная — с зелёной рамкой (как на старом сайте) */
.irepair-card3 .irepair-card3__mid .ty-product-options__item {
  margin: 0 0 16px;
  padding: 0;
}
.irepair-card3 .irepair-card3__mid .ty-product-options__item-label {
  float: none;
  display: block;
  width: auto;
  margin: 0 0 10px;
  padding: 0;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 14px;
  line-height: 18px;
  font-weight: 400;
  color: #86868b;
  text-align: left;
}
.irepair-card3 .irepair-card3__mid .ty-product-options__radio--label {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
  min-width: 122px;
  height: auto;
  margin: 0 8px 8px 0;
  padding: 10px 18px 12px;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  background: #ffffff;
  box-shadow: none;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 15px;
  line-height: 20px;
  color: #3e3e3e;
  text-align: center;
  white-space: nowrap;
  cursor: pointer;
  transition: border-color 0.2s ease;
}
.irepair-card3 .irepair-card3__mid .ty-product-options__radio--label::before,
.irepair-card3 .irepair-card3__mid .ty-product-options__radio--label::after,
.irepair-card3 .irepair-card3__mid .ty-product-options__radio--label .ty-product-option-checkbox:empty {
  display: none;
}
.irepair-card3 .irepair-card3__mid .ty-product-options__radio--label:hover {
  border-color: #37d97b;
}
.irepair-card3 .irepair-card3__mid .ty-product-options__radio:checked + .ty-product-options__radio--label {
  border-color: #37d97b;
  box-shadow: inset 0 0 0 1px #37d97b;
  color: #010306;
}
.irepair-card3 .irepair-card3__mid .irepair-card3__vprice,
.irepair-card3 .irepair-card3__mid .irepair-card3__vprice .ty-price-num {
  font-family: 'Montserrat-Medium', 'Montserrat-Bold', Arial, sans-serif;
  font-size: 16px;
  line-height: 22px;
  font-weight: 400;
  color: #010306;
}
.irepair-card3 .irepair-card3__mid .irepair-card3__vprice {
  display: block;
  margin-top: 6px;
}

/* 3-я колонка: серая плашка, как на старом сайте */
.irepair-card3 .irepair-card3__box {
  padding: 30px;
  border-radius: 20px;
  background: #f6f6f6;
}
.irepair-card3 .irepair-card3__box .irepair-reward {
  margin: 0;
}
.irepair-card3 .irepair-card3__box .irepair-reward__card {
  margin: 0 0 26px;
  padding: 0 0 26px;
  border-radius: 0;
  border-bottom: 1px solid #dcdcdc;
  background: none;
}
.irepair-card3 .irepair-card3__pay {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}
.irepair-card3 .irepair-card3__pay-label {
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 18px;
  line-height: 24px;
  color: #3e3e3e;
  white-space: nowrap;
}
.irepair-card3 .irepair-card3__pay-price,
.irepair-card3 .irepair-card3__pay-price .ut2-pb__price-wrap,
.irepair-card3 .irepair-card3__pay-price .ut2-pb__price-actual {
  margin: 0;
  padding: 0;
}
.irepair-card3 .irepair-card3__pay-price .ty-price,
.irepair-card3 .irepair-card3__pay-price .ty-price-num {
  font-family: 'Montserrat-SemiBold', 'Montserrat-Bold', Arial, sans-serif;
  font-size: 32px;
  line-height: 40px;
  font-weight: 400;
  color: #010306;
  white-space: nowrap;
}
.irepair-card3 .irepair-card3__side .ut2-pb__advanced-options {
  margin: 0;
}
/* кнопка «Оформить заявку» — на всю ширину колонки */
.irepair-card3 .irepair-card3__side .ut2-pb__button {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  margin: 20px 0 0;
  padding: 0;
}
.irepair-card3 .irepair-card3__side .ut2-pb__button .ty-btn__add-to-cart,
.irepair-card3 .irepair-card3__side .ut2-pb__button .ty-btn__primary {
  flex: 1 1 auto;
  width: auto;
  min-height: 52px;
  margin: 0;
}

/* кнопка — на всю ширину колонки; «Отложить» и «Поделиться» — одной строкой под ней */
.irepair-card3 .irepair-card3__side .ut2-pb__button {
  gap: 16px 24px;
}
/* обёртка кнопки «растворяется», чтобы «Отложить» (внутри неё) и «Поделиться» (снаружи) встали в один ряд */
.irepair-card3 .irepair-card3__side .ut2-pb__button > [id^="add_to_cart_update_"] {
  display: contents;
}
.irepair-card3 .irepair-card3__side .ut2-pb__button > [id^="add_to_cart_update_"] > div {
  flex: 1 1 100%;
  width: 100%;
}
.irepair-card3 .irepair-card3__side .ut2-pb__button .ty-btn__add-to-cart {
  display: block;
  width: 100%;
  max-width: none;
}
/* на кнопке вместо корзины — наш знак (как в значке сайта): круг со звездой, на зелёной кнопке — белый */
.irepair-card3 .irepair-card3__side .ty-btn__add-to-cart .ut2-icon-use_icon_cart {
  display: none;
}
.irepair-card3 .irepair-card3__side .ty-btn__add-to-cart > span {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}
/* текст кнопки крупнее стандартного (у темы 14 px) */
.irepair-card3 .irepair-card3__side .ty-btn__add-to-cart,
.irepair-card3 .irepair-card3__side .ty-btn__add-to-cart bdi {
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 18px;
  line-height: 24px;
  font-weight: 500;
}
.irepair-card3 .irepair-card3__side .ut2-pb__button .ty-btn__add-to-cart {
  min-height: 58px;
}
.irepair-card3 .irepair-card3__side .ty-btn__add-to-cart > span::before {
  content: '';
  flex: 0 0 28px;
  width: 28px;
  height: 28px;
  background: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 18 18'%3E%3Cpath fill='%23ffffff' d='M8.99993 0C4.0294 0 0 4.0295 0 9C0 13.9705 4.0294 18 8.99993 18C13.9706 18 18 13.9705 18 9C18 4.0295 13.9706 0 8.99993 0ZM14.6436 9.29157C14.0103 10.0803 13.6876 11.0734 13.7365 12.0837L13.7986 13.3716C13.982 14.559 12.746 15.4569 11.6736 14.9155L10.4679 14.4584C9.52217 14.0997 8.47783 14.0997 7.532 14.4584L6.32644 14.9155C5.25384 15.4569 4.01782 14.559 4.20136 13.3716L4.26351 12.0837C4.31229 11.0734 3.98958 10.0803 3.35641 9.29157L2.5492 8.28623C1.70273 7.43329 2.17482 5.98039 3.36095 5.78803L4.60483 5.4492C5.58083 5.18339 6.42565 4.56952 6.98 3.72374L7.68675 2.64523C8.23627 1.57678 9.764 1.57678 10.3135 2.64523L11.0201 3.7236C11.5743 4.56966 12.4194 5.18353 13.3953 5.4492L14.6392 5.78803C15.8252 5.98039 16.2973 7.43315 15.4509 8.28623L14.6436 9.29157Z'/%3E%3C/svg%3E") center / contain no-repeat;
}
/* «Отложить» и «Поделиться» — в одном стиле; стандартное «Поделиться» темы скрыто */
.irepair-card3 .irepair-card3__side .ut2-pb__share {
  display: none;
}
.irepair-card3 .irepair-card3__side .ut2-add-to-wish {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 14px;
  line-height: 20px;
  color: #3e3e3e;
}
.irepair-card3 .irepair-card3__side .ut2-add-to-wish:hover {
  color: #1fb86a;
}
.irepair-card3 .irepair-card3__side .ut2-add-to-wish i,
.irepair-card3 .irepair-card3__side .ut2-add-to-wish i span::before {
  color: inherit;
}

@media (max-width: 1180px) {
  .irepair-card3 .irepair-card3__grid {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 32px;
  }
  .irepair-card3 .irepair-card3__side {
    grid-column: 1 / -1;
  }
}
</style>
{/literal}
{else}
    {* iRepair: на телефоне — прежняя мобильная карточка *}
    {include file="addons/my_changes/blocks/product_templates/components/irepair_service_mobile.tpl" features=$product.header_features}
{/if}
