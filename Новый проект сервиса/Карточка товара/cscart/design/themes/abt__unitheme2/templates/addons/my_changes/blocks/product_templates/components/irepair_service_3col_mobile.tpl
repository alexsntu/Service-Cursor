{* iRepair: мобильная версия макета «3 колонки» — те же блоки, что на компьютере, в одну колонку:
   название и код → фото → плитки вариантов с ценой и пояснение → серая плашка «вернём баллами / К оплате» →
   кнопка «Оформить заявку» → «Отложить» и «Поделиться» → преимущества (ремонт / курьер / гарантия).
   Основа — мобильный шаблон UniTheme2 (abt__ut2_mobile_template.tpl); наши компоненты те же, что на компьютере.
   Стили — addons/my_changes/components/irepair_card3_styles.tpl (правила с классом irepair-card3_m). *}
{script src="js/tygh/exceptions.js"}

{assign var="pd_image_gallery_width" value=$settings.abt__ut2.products.view.image_width[$settings.ab__device]|default:430}
{assign var="pd_image_gallery_height" value=$settings.abt__ut2.products.view.image_height[$settings.ab__device]|default:430}

{$is_add_to_cart_mv=true}
{$abt__shareb_mute=false}
{if "MULTIVENDOR"|fn_allowed_for && ($product.master_product_id || !$product.company_id)}{$is_add_to_cart_mv=false}{/if}

<div class="ut2-pb ut2-pb-mobile ty-product-block irepair-card3 irepair-card3_m">

    <div class="ut2-breadcrumbs__wrapper">
        {hook name="products:ut2_main_info_breadcrumbs"}
            {include file="common/breadcrumbs.tpl"}
        {/hook}
    </div>

    {if $product}

        <div class="ut2-pb__wrapper clearfix">
        {hook name="products:view_main_info"}

            {assign var="obj_id" value=$product.product_id}
            {* флаг для нашего шаблона выбора вариаций: короткая подпись и цена в плитке варианта *}
            {$irp_card3 = true}
            {* hide_compare_list_button=true — без кнопки «Сравнить» в карточке услуги *}
            {include file="common/product_data.tpl" product=$product but_role="big" but_text=__("add_to_cart") product_labels_position="right-top" hide_qty_label=true hide_compare_list_button=true}

            <div class="ut2-pb__content">
                {assign var="form_open" value="form_open_`$obj_id`"}
                {$smarty.capture.$form_open nofilter}

                {assign var="old_price" value="old_price_`$obj_id`"}
                {assign var="price" value="price_`$obj_id`"}
                {assign var="clean_price" value="clean_price_`$obj_id`"}
                {assign var="list_discount" value="list_discount_`$obj_id`"}
                {assign var="discount_label" value="discount_label_`$obj_id`"}

                {* название и код услуги — сверху *}
                <div class="irepair-card3__title">
                    {if !$hide_title}
                        <h1 class="ut2-pb__title" {live_edit name="product:product:{$product.product_id}"}>{$product.product nofilter}</h1>
                    {/if}
                    {if $show_sku == "true" && $product.product_code|trim}
                        <div class="ut2-pb__sku irepair-card3__sku">
                            {assign var="sku" value="sku_`$obj_id`"}
                            {$smarty.capture.$sku nofilter}
                        </div>
                    {/if}
                </div>

                <div class="irepair-card3__grid">

                    {* фото *}
                    {* ut2-pb__img-wrapper нужен теме: по нему она задаёт высоту галереи *}
                    <div class="irepair-card3__media ut2-pb__img-wrapper">
                        {hook name="products:image_wrap"}

                        {hook name="products:ab__product_images_count"}
                            {$product_images_count = $product.image_pairs|@count}
                        {/hook}

                        {if !$no_images}
                            {if $settings.abt__ut2.products.view.thumbnails_gallery_format[$settings.ab__device] === "native"}
                                {$is_nocarousel = true}

                                {literal}<script>
                                    (function($){
                                        $.ceEvent('on', 'ce.product_image_gallery.beforeInit', owl => {
                                          if (owl.$elem.closest('.ut2-pb__img').hasClass('ut2-pb__as-native-scroll')) owl.logIn = ()=>{}
                                        });
                                    })(Tygh.$)
                               </script>{/literal}
                            {/if}

                            <div class="ut2-pb__img cm-reload-{$product.product_id} {if $settings.Appearance.thumbnails_gallery == "YesNo::YES"|enum}ut2-pb__as-gallery{else}ut2-pb__as-thumbs{/if}{if $settings.abt__ut2.products.view.thumbnails_gallery_format[$settings.ab__device] === "native"} ut2-pb__as-native-scroll{/if}" data-ca-previewer="true" style="--pd-image-gallery-width:{$pd_image_gallery_width};--pd-image-gallery-height:{$pd_image_gallery_height};" id="product_images_{$product.product_id}_update">
                                {include file="views/products/components/product_images.tpl" image_width=$pd_image_gallery_width image_height=$pd_image_gallery_height product=$product show_detailed_link="YesNo::YES"|enum lazy_load=false nocarousel=$is_nocarousel thumbnails_size=50}
                            <!--product_images_{$product.product_id}_update--></div>
                        {/if}
                        {/hook}
                    </div>

                    {* варианты и пояснение *}
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
                    </div>

                    {* баллы + цена, кнопка *}
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

                        {assign var="advanced_options" value="advanced_options_`$obj_id`"}
                        {if $smarty.capture.$advanced_options}
                        <div class="ut2-pb__advanced-options">
                            {if $capture_options_vs_qty}{capture name="product_options"}{$smarty.capture.product_options nofilter}{/if}
                            {$smarty.capture.$advanced_options nofilter}
                            {if $capture_options_vs_qty}{/capture}{/if}
                        </div>
                        {/if}

                        {if $capture_buttons}{capture name="buttons"}{/if}
                        <div class="ut2-pb__button ty-product-block__button">
                            {if $show_details_button}
                                {include file="buttons/button.tpl" but_href="products.view?product_id=`$product.product_id`" but_text=__("view_details") but_role="submit"}
                            {/if}

                            {assign var="add_to_cart" value="add_to_cart_`$obj_id`"}
                            {$smarty.capture.$add_to_cart nofilter}

                            {assign var="list_buttons" value="list_buttons_`$obj_id`"}
                            {$smarty.capture.$list_buttons nofilter}

                            {* своё окно «Поделиться» (стандартное от темы скрыто стилями) *}
                            {include file="addons/my_changes/components/irepair_share.tpl"}
                        </div>
                        {if $capture_buttons}{/capture}{/if}

                        {* «Оформить заявку» открывает попап заявки вместо корзины *}
                        {include file="addons/my_changes/components/irepair_lead_button.tpl"}
                    </div>

                    {* преимущества (ремонт / курьер / гарантия) — на телефоне после кнопки *}
                    <div class="irepair-card3__promo-m">
                        {include file="addons/my_changes/components/irepair_product_promo.tpl"}
                    </div>
                </div>

                {hook name="products:promo_text"}
                {if $product.promo_text}
                    <div class="ut2-pb__note">
                        {$product.promo_text nofilter}
                    </div>
                {/if}
                {/hook}

                {assign var="form_close" value="form_close_`$obj_id`"}
                {$smarty.capture.$form_close nofilter}

                {if $show_product_tabs}
                    {include file="views/tabs/components/product_popup_tabs.tpl"}
                    {$smarty.capture.popupsbox_content nofilter}
                {/if}
                {hook name="products:product_form_close_tag"}
                    {$form_close="form_close_`$obj_id`"}
                    {$smarty.capture.$form_close nofilter}
                {/hook}
                {hook name="products:ab__vendor_block"}{/hook}
                {hook name="products:ab__motivation_block"}{/hook}
                {hook name="products:product_detail_bottom"}{/hook}

                {if $settings.abt__ut2.products.custom_block_id|intval}
                    {render_block block_id=$settings.abt__ut2.products.custom_block_id|intval dispatch="products.view"  use_cache=false parse_js=false}
                {/if}

                {hook name="products:product_tabs_pre"}
                    <div class="ut2-pb__tabs">
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

                {hook name="products:buy_together"}{/hook}
            </div>

        {/hook}
        </div>
    {/if}

    {if $smarty.capture.hide_form_changed == "YesNo::YES"|enum}
        {assign var="hide_form" value=$smarty.capture.orig_val_hide_form}
    {/if}

    {hook name="products:bottom_product_layer"}{/hook}
</div>

<div class="product-details">
</div>

{capture name="mainbox_title"}{assign var="details_page" value=true}{/capture}
{* стили макета — общие для компьютера и телефона *}
{include file="addons/my_changes/components/irepair_card3_styles.tpl"}
{* прокрутка к названию услуги после выбора варианта (только мобильная версия) *}
{include file="addons/my_changes/components/irepair_mobile_variant_scroll.tpl"}
