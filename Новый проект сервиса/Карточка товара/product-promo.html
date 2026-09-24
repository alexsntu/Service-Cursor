{* iRepair — промо-блок карточки товара: срок ремонта / курьер / гарантия.
   Тип блока CS-Cart: «HTML блок с поддержкой Smarty», размещается в макете страницы товара.
   Гарантия берётся из характеристики товара id 4 «Гарантия» (число месяцев);
   если у товара она не заполнена — строка гарантии не выводится. *}
{assign var="irp_warranty" value=""}
{if $product.product_features.4.value}
    {assign var="irp_warranty" value=$product.product_features.4.value|trim}
{/if}

<div class="irepair-product-promo">
  <ul class="irepair-product-promo__list">

    <li class="irepair-product-promo__item">
      <span class="irepair-product-promo__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="8.6" stroke="currentColor" stroke-width="1.7"></circle>
          <path d="M12 7.6V12.4H15.4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"></path>
        </svg>
      </span>
      <span class="irepair-product-promo__text">Ремонт от 90&nbsp;минут</span>
    </li>

    <li class="irepair-product-promo__item">
      <span class="irepair-product-promo__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M3.5 12H19.2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"></path>
          <path d="M14.4 6.8L19.6 12L14.4 17.2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"></path>
        </svg>
      </span>
      <span class="irepair-product-promo__text">Курьер от 30&nbsp;минут</span>
    </li>

    {if $irp_warranty}
    {assign var="irp_w_mod100" value=$irp_warranty % 100}
    {assign var="irp_w_mod10" value=$irp_warranty % 10}
    {if $irp_w_mod100 >= 11 && $irp_w_mod100 <= 14}
        {assign var="irp_w_word" value="месяцев"}
    {elseif $irp_w_mod10 == 1}
        {assign var="irp_w_word" value="месяц"}
    {elseif $irp_w_mod10 >= 2 && $irp_w_mod10 <= 4}
        {assign var="irp_w_word" value="месяца"}
    {else}
        {assign var="irp_w_word" value="месяцев"}
    {/if}
    <li class="irepair-product-promo__item">
      <span class="irepair-product-promo__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M6.4 12.6L10.4 16.6L18 7.6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"></path>
        </svg>
      </span>
      <span class="irepair-product-promo__text">Гарантия {$irp_warranty}&nbsp;{$irp_w_word}</span>
    </li>
    {/if}

  </ul>
</div>

{literal}
<style>
.irepair-product-promo,
.irepair-product-promo * {
  box-sizing: border-box;
}
.irepair-product-promo {
  margin: 24px 0;
}
/* в правой колонке карточки (рядом с ценой) — без внешних отступов, вровень с ценой */
.ut2-pb__last .irepair-product-promo {
  margin: 0;
}
.irepair-product-promo .irepair-product-promo__list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin: 0;
  padding: 0;
  list-style: none;
}
.irepair-product-promo .irepair-product-promo__item {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
}
.irepair-product-promo .irepair-product-promo__item::before {
  content: none;
}
.irepair-product-promo .irepair-product-promo__icon {
  flex: 0 0 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, rgba(74, 229, 128, 0.16), rgba(32, 204, 190, 0.16));
  color: #20CCBE;
}
.irepair-product-promo .irepair-product-promo__icon svg {
  display: block;
  width: 20px;
  height: 20px;
}
.irepair-product-promo .irepair-product-promo__text {
  font-size: 16px;
  line-height: 20px;
  color: #5c5b5b;
}

@media (max-width: 767px) {
  .irepair-product-promo {
    margin: 20px 0;
  }
  .irepair-product-promo .irepair-product-promo__list {
    gap: 12px;
  }
  .irepair-product-promo .irepair-product-promo__icon {
    flex-basis: 32px;
    width: 32px;
    height: 32px;
  }
  .irepair-product-promo .irepair-product-promo__icon svg {
    width: 18px;
    height: 18px;
  }
  .irepair-product-promo .irepair-product-promo__text {
    font-size: 15px;
  }
}
</style>
{/literal}
