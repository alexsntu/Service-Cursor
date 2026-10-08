{** template-description:irepair_service_3col **}
{* iRepair: пробный макет карточки услуги в три колонки — на основе шаблона UniTheme2 «AB: Трехколоночный»
   (abt__ut2_three_columns_template.tpl), элементы расставлены как в карточке услуги старого сайта:
     заголовок на всю ширину;
     1-я колонка — фото;
     2-я колонка — выбор варианта (тип запчасти, модель), пояснение к варианту, преимущества (ремонт / курьер / гарантия);
     3-я колонка — серая плашка «вернём баллами» + «К оплате: цена», под ней кнопка «Оформить заявку».
   Наши компоненты те же, что в шаблоне «iRepair — Услуга» (irepair_service_template.tpl).
   На телефоне — тот же макет в одну колонку: components/irepair_service_3col_mobile.tpl.
   Стили общие: addons/my_changes/components/irepair_card3_styles.tpl. *}
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

    {* стили макета — общие для компьютера и телефона *}
    {include file="addons/my_changes/components/irepair_card3_styles.tpl"}
{else}
    {* iRepair: на телефоне — тот же макет в одну колонку *}
    {include file="addons/my_changes/blocks/product_templates/components/irepair_service_3col_mobile.tpl" features=$product.header_features}
{/if}
