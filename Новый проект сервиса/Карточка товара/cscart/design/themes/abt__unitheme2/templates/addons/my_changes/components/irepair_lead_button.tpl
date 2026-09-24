{* iRepair — кнопка «Оформить заявку» (add-to-cart) в карточке услуги открывает наш попап заявки
   (из хедера: `data-call-popup-trigger`, форма #callPopupForm → /ajax/send-lead.php → Bitrix24) вместо добавления в корзину.
   Контекст для попапа (услуга + цена) лежит в скрытом элементе и обновляется при переключении варианта (cm-reload-*).
   Услуга = название без суффикса « | …» + выбранные значения вариаций в скобках: «Замена аккумулятора iPhone 17 (OEM)». *}
{$irp_lead_name = $product.product|strip_tags|regex_replace:"/\s*\|.*$/":""|trim}
{$irp_lead_vs = ""}
{foreach $product.variation_features_variants as $irp_lf}
    {if $irp_lf.variant_id && $irp_lf.variants[$irp_lf.variant_id].variant}
        {if $irp_lead_vs}{$irp_lead_vs = $irp_lead_vs|cat:", "}{/if}
        {$irp_lead_vs = $irp_lead_vs|cat:$irp_lf.variants[$irp_lf.variant_id].variant}
    {/if}
{/foreach}
{if $irp_lead_vs}
    {$irp_lead_service = $irp_lead_name|cat:" ("|cat:$irp_lead_vs|cat:")"}
{else}
    {$irp_lead_service = $irp_lead_name}
{/if}
<span class="irepair-lead-ctx cm-reload-{$obj_id}" id="irepair_lead_ctx_{$obj_id}" hidden
      data-call-popup-trigger
      data-product-id="{$product.product_id}"
      data-service="{$irp_lead_service}"
      data-price="{$product.price|intval}"><!--irepair_lead_ctx_{$obj_id}--></span>

{literal}
<script>
(function () {
  if (window.irpLeadButton) {
    return;
  }
  window.irpLeadButton = true;

  /* capture-фаза: срабатываем раньше обработчиков CS-Cart и не даём отправить форму в корзину */
  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.ty-btn__add-to-cart') : null;
    if (!btn) {
      return;
    }
    var ctx = document.querySelector('.irepair-lead-ctx');
    if (!ctx) {
      return;
    }
    var isThisProduct = btn.id === 'button_cart_' + ctx.getAttribute('data-product-id')
      || !!btn.closest('.ut2-pb, #ut2_pb__sticky_add_to_cart, .ut2-pb__sticky-add-to-cart');
    if (!isThisProduct) {
      return;
    }
    e.preventDefault();
    e.stopPropagation();
    if (e.stopImmediatePropagation) {
      e.stopImmediatePropagation();
    }
    /* клик по скрытому триггеру — попап из хедера сам возьмёт data-service / data-price */
    ctx.click();
  }, true);
}());
</script>
{/literal}
