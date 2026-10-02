{* iRepair (my_changes, 2026-10-02): копия шаблона UnitTheme2 addons/product_variations/hooks/products/product_option_content.pre.tpl
   с ОДНОЙ правкой — в выпадающем списке (select) у атрибута data-ca-products-product-option-content-enable-caching
   не было закрывающей кавычки, браузер «съедал» первый вариант списка (напр. Intel | A2141 у MacBook Pro 16).
   После обновления темы — сверить с оригиналом. *}
{if $product.variation_features_variants && $product.detailed_params.info_type === "D"}
    {script src="js/addons/product_variations/picker_features.js"}
    <div id="features_{$obj_prefix}{$obj_id}_AOC">
        {$container = "ut2_pb__sticky_add_to_cart,product_detail_page"}
        {$product_url = "products.view"}
        {$show_all_possible_feature_variants = $addons.product_variations.variations_show_all_possible_feature_variants === "YesNo::YES"|enum}
        {$allow_negative_amount = $allow_negative_amount|default:$settings.General.allow_negative_amount === "YesNo::YES"|enum}
        {if !isset($enable_product_options_cache)}
            {$enable_product_options_cache = true}
        {/if}

        {if $quick_view}
            {$container = "product_main_info_form_{$obj_prefix}{$quick_view_additional_container}"}
            {$product_url = "products.quick_view?product_id=`$product.product_id`&prev_url=`$redirect_url|escape:url`"|trim}
        {/if}

        {if $is_microstore}
            {$product_url = $product_url|fn_link_attach:"is_microstore=Y"}

            {if $product.company_id}
                {$product_url = $product_url|fn_link_attach:"microstore_company_id=`$product.company_id`"}
            {/if}
        {/if}

        {if $ut2_select_variation}
            {$container = "ut2_select_variation_wrapper_{$obj_prefix}"}
            {$product_url = "products.ut2_select_variation?product_id=`$product.product_id`&prev_url=`$current_url`"|trim}
        {/if}

        {if $product.detailed_params.is_preview}
            {$product_url = $product_url|fn_link_attach:"action=preview"}
        {/if}

        {$settings.Thumbnails.product_variant_normal_icon_width = $settings.Thumbnails.product_variant_mini_icon_width * 1.5}
        {$settings.Thumbnails.product_variant_normal_icon_height = $settings.Thumbnails.product_variant_mini_icon_height * 1.5}

        <div class="cm-picker-product-variation-features ty-product-options" style="--tb-var-image-width: {$settings.Thumbnails.product_variant_normal_icon_width};--tb-var-image-height: {$settings.Thumbnails.product_variant_normal_icon_height}">
            {$feature_style_dropdown = "\Tygh\Enum\ProductFeatureStyles::DROP_DOWN"|constant}
            {$feature_style_images = "\Tygh\Enum\ProductFeatureStyles::DROP_DOWN_IMAGES"|constant}
            {$feature_style_labels = "\Tygh\Enum\ProductFeatureStyles::DROP_DOWN_LABELS"|constant}
            {$purpose_create_variations = "\Tygh\Addons\ProductVariations\Product\FeaturePurposes::CREATE_VARIATION_OF_CATALOG_ITEM"|constant}
            {$total_varints_with_images = 0}

            {foreach $product.variation_features_variants as $feature}

                {$is_feature_default_style = !in_array($feature.feature_style, [$feature_style_images, $feature_style_labels, $feature_style_dropdown])}
                <div class="ty-control-group ty-product-options__item clearfix">
                    <div class="ut2{if $feature.feature_style === $feature_style_images}-vimg{else}-vopt{/if}__wrap">
                    <label class="ty-control-group__label ty-product-options__item-label">{$feature.description}:</label>
                        {if $feature.feature_style === $feature_style_images}
                            {foreach $feature.variants as $variant}
                                {if $feature.variant_id != $variant.variant_id}
                                    {continue}
                                {/if}
                                {if $variant.product.status || $show_all_possible_feature_variants}
                                    <div class="ty-product-option-container ty-product-option-container--feature-style-images">
                                        <div class="ty-product-option-child">{if $feature.prefix}{$feature.prefix} {/if}{$variant.variant}{if $feature.suffix} {$feature.suffix}{/if}</div>
                                    </div>
                                {/if}
                            {/foreach}
                        {elseif $feature.feature_style === $feature_style_dropdown || $is_feature_default_style}
                            <div class="ty-product-option-container">
                                <div class="ty-product-option-child">
                                    <select class="{if $feature.purpose === $purpose_create_variations || $quick_view || $ut2_select_variation}cm-ajax{/if} {if $details_page}cm-history{/if} cm-ajax-force"
                                            data-ca-target-id="{$container}"
                                            data-ca-products-product-option-content-enable-caching="{($enable_product_options_cache) ? "true" : "false"}"
                                    >
                                        {foreach $feature.variants as $variant}
                                            {if $variant.product.status}
                                                <option
                                                        data-ca-variant-id="{$variant.variant_id}"
                                                        data-ca-product-url="{$product_url|fn_link_attach:"product_id={$variant.product.product_id}"|fn_url}"
                                                        {if $feature.variant_id == $variant.variant_id}selected="selected"{/if}
                                                >
                                                    {if $feature.prefix}{$feature.prefix} {/if}{$variant.variant}{if $feature.suffix} {$feature.suffix}{/if}
                                                </option>
                                            {elseif $show_all_possible_feature_variants}
                                                <option disabled>{$variant.variant}</option>
                                            {/if}
                                        {/foreach}
                                    </select>
                                </div>
                            </div>
                        {/if}
                    </div>

                    {if $feature.feature_style === $feature_style_images}
                        {capture name="variant_images"}
                            {foreach $feature.variants as $variant}

                                {$total_varints_with_images=$total_varints_with_images + 1}

                                {if $variant.showed_product_id}
                                    {$variant_product_id = $variant.showed_product_id}
                                {else}
                                    {$variant_product_id = $variant.product.product_id}
                                {/if}
                                {if $variant_product_id && $variant.product.status}

                                    {* Change main product image on variation image hover *}
                                    {if $settings.abt__ut2.general.change_main_image_on_variation_hover.{$settings.ab__device} == "YesNo::YES"|enum}
                                        {if $quick_view}
                                            {$image_width=$settings.Thumbnails.product_quick_view_thumbnail_width}
                                            {$image_height=$settings.Thumbnails.product_quick_view_thumbnail_height}
                                        {elseif $product.details_layout !='bigpicture_template'}
                                            {$image_width=$settings.Thumbnails.product_details_thumbnail_width}
                                            {$image_height=$settings.Thumbnails.product_details_thumbnail_height}
                                        {/if}
                                        {include file="common/image.tpl"
                                            images=$variant.product.main_pair
                                            capture_image=true
                                        }
                                    {/if}
                                    <a
                                        {if $variant.product.amount >= 1 || $allow_negative_amount || $details_page}href="{$product_url|fn_link_attach:"product_id={$variant_product_id}"|fn_url}"{/if}
                                        class="ut2-scroll-item ty-product-options__image--wrapper {if $variant.product.abt__ut2_is_in_stock < 1 && $settings.abt__ut2.products.highlight_unavailable_variations[$settings.ab__device] == "YesNo::YES"|enum}ty-product-options__image--wrapper--disabled{/if} {if $settings.ab__device=='desktop'}cm-tooltip{/if} {if $variant.variant_id == $feature.variant_id}ty-product-options__image--wrapper--active{/if} {if $feature.purpose === $purpose_create_variations || $quick_view || $ut2_select_variation}cm-ajax {if !$ut2_select_variation}cm-history {/if}{if $enable_product_options_cache}cm-ajax-cache{/if}{/if}"
                                        title="{$feature.prefix} {$variant.variant} {$feature.suffix}"
                                        {if $feature.purpose === $purpose_create_variations || $quick_view || $ut2_select_variation}data-ca-target-id="{$container}"{/if}
                                        {if $variant.variant_id != $feature.variant_id}
                                            {if $smarty.capture.icon_image_path|trim} data-ca-variation-image="{$smarty.capture.icon_image_path}"{/if}
                                            {if $smarty.capture.icon_image_path_hidpi|trim} data-ca-variation-image-hidpi="{$smarty.capture.icon_image_path_hidpi}"{/if}
                                        {/if}
                                    >
                                        {include file="common/image.tpl"
                                            obj_id="image_feature_variant_{$feature.feature_id}_{$variant.variant_id}_{$obj_prefix}{$obj_id}"
                                            class="ty-product-options__image"
                                            images=$variant.product.main_pair
                                            image_width=$settings.Thumbnails.product_variant_normal_icon_width
                                            image_height=$settings.Thumbnails.product_variant_normal_icon_height
                                            image_additional_attrs = [
                                                "width" => $settings.Thumbnails.product_variant_normal_icon_width,
                                                "height" => $settings.Thumbnails.product_variant_normal_icon_height
                                            ]
                                        }
                                        <span><span>{if $feature.prefix}{$feature.prefix} {/if}{$variant.variant}{if $feature.suffix} {$feature.suffix}{/if}</span></span>
                                    </a>
                                {elseif $show_all_possible_feature_variants}
                                    <div class="ut2-scroll-item ty-product-options__image--wrapper ty-product-options__image--wrapper--disabled{if $settings.ab__device === 'desktop'} cm-tooltip{/if}" title="{$feature.prefix} {$variant.variant} {$feature.suffix}" style="--var-no-image_width: {$settings.Thumbnails.product_variant_normal_icon_width};--var-no-image_height: {$settings.Thumbnails.product_variant_normal_icon_height};">
                                        {include file="common/image.tpl"
                                        obj_id="image_feature_variant_{$feature.feature_id}_{$variant.variant_id}_{$obj_prefix}{$obj_id}"
                                        class="ty-product-options__image"
                                        images=$variant.product.main_pair
                                        image_width=$settings.Thumbnails.product_variant_normal_icon_width
                                        image_height=$settings.Thumbnails.product_variant_normal_icon_height
                                        image_additional_attrs = [
                                        "width" => $settings.Thumbnails.product_variant_normal_icon_width,
                                        "height" => $settings.Thumbnails.product_variant_normal_icon_height
                                        ]
                                        }
                                        <span><span>{if $feature.prefix}{$feature.prefix} {/if}{$variant.variant}{if $feature.suffix} {$feature.suffix}{/if}</span></span>
                                    </div>
                                {/if}
                            {/foreach}
                        {/capture}

                        {if $smarty.capture.variant_images|trim}

                            {$id="scroll_list_`$product.product_id`"}

                            <input class="ut2-po-all-vars--toggle hidden" type="checkbox" name="ab_po_vars{$id}" id="ab_po_vars{$id}">
                            <label for="ab_po_vars{$id}"><span class="show-more">{__("show_more")} ({$total_varints_with_images})</span><span class="show-less hidden">{__("show_less")}</span> <i class="ut2-icon-outline-expand_more"></i></label>

                            <div class="ty-clear-both ut2-scroll-container" id={$id}>
                                <button class="ut2-scroll-left" type="button"><span class="ut2-icon-arrow_back_black"></span></button>
                                <div class="ut2-scroll-content">
                                    {$smarty.capture.variant_images nofilter}
                                </div>
                                <button class="ut2-scroll-right" type="button"><span class="ut2-icon-arrow_forward_black"></span></button>
                            </div>

                            {include file="common/simple_scroller_init.tpl" block_id=$id elements_to_scroll=$elements_to_scroll|default: 3}
                        {/if}
                    {elseif $feature.feature_style === $feature_style_labels}
                        <div class="ty-clear-both">
                            {foreach $feature.variants as $variant}
                                {if $variant.product.product_id && $variant.product.status}
                                    <input type="radio"
                                           name="feature_{$feature.feature_id}"
                                           value="{$variant.variant_id}"
                                           {if $feature.variant_id == $variant.variant_id}
                                               checked
                                           {/if}
                                           id="feature_{$feature.feature_id}_variant_{$variant.variant_id}_{$obj_prefix}{$obj_id}"
                                           data-ca-variant-id="{$variant.variant_id}"
                                           data-ca-product-url="{$product_url|fn_link_attach:"product_id={$variant.product.product_id}"|fn_url}"
                                           class="hidden ty-product-options__radio {if $feature.purpose === $purpose_create_variations || $quick_view || $ut2_select_variation}cm-ajax{/if} {if $details_page}cm-history{/if} cm-ajax-force"
                                           data-ca-target-id="{$container}"
                                           data-ca-products-product-option-content-enable-caching="{($enable_product_options_cache) ? "true" : "false"}"
                                    />
                                    <label for="feature_{$feature.feature_id}_variant_{$variant.variant_id}_{$obj_prefix}{$obj_id}"
                                           class="ty-product-options__radio--label {if !$variant.product.abt__ut2_is_in_stock && $settings.abt__ut2.products.highlight_unavailable_variations[$settings.ab__device] == "YesNo::YES"|enum}ty-product-options__radio--label--disabled{/if}"
                                    >
                                        <span class="ty-product-option-checkbox">{$feature.prefix}</span>
                                        <bdi>{$variant.variant}</bdi>
                                        <span class="ty-product-option-checkbox">{$feature.suffix}</span>
                                    </label>

                                {* hidden variation *}
                                {elseif $show_all_possible_feature_variants}
                                    <label class="ty-product-options__radio--label ty-product-options__radio--label--disabled">
                                        <span class="ty-product-option-checkbox">{$feature.prefix}</span>
                                        <bdi>{$variant.variant}</bdi>
                                        <span class="ty-product-option-checkbox">{$feature.suffix}</span>
                                    </label>
                                {/if}
                            {/foreach}
                        </div>
                    {/if}
                </div>
            {/foreach}
        </div>
    </div>
{/if}