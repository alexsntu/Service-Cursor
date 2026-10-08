{* iRepair — стили макета карточки услуги «3 колонки» (компьютер и телефон). *}
{literal}
<style>
/* iRepair: макет карточки услуги «3 колонки» — общие стили (компьютер: irepair_service_3col.tpl,
   телефон: components/irepair_service_3col_mobile.tpl, там у корня ещё класс irepair-card3_m) */
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
  /* три равные колонки — каждая ровно треть ширины */
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 20px 48px;
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

/* ---------- телефон: те же блоки в одну колонку ---------- */
.irepair-card3.irepair-card3_m .irepair-card3__title {
  margin: 14px 0 16px;
}
.irepair-card3.irepair-card3_m .irepair-card3__title h1.ut2-pb__title {
  float: none;
  width: auto;
}
.irepair-card3.irepair-card3_m .irepair-card3__title h1 {
  font-size: 22px;
  line-height: 1.25;
}
.irepair-card3.irepair-card3_m .irepair-card3__grid {
  display: block;
  margin-bottom: 28px;
}
.irepair-card3.irepair-card3_m .irepair-card3__media {
  float: none;
  width: auto;
  margin: 0 0 20px;
  padding: 0;
}
/* фото: у темы обёртка картинки в мобильной галерее получает нулевую ширину (картинка внутри неё
   позиционирована абсолютно) — задаём ширину сами, высота считается из пропорций галереи */
.irepair-card3.irepair-card3_m .irepair-card3__media .ut2-pb__img {
  padding: 0;
}
.irepair-card3.irepair-card3_m .irepair-card3__media .ty-product-img {
  display: block;
}
.irepair-card3.irepair-card3_m .irepair-card3__media .ty-image-zoom__wrapper,
.irepair-card3.irepair-card3_m .irepair-card3__media .ty-image-zoom__wrapper > a {
  display: block;
  width: 100%;
}
.irepair-card3.irepair-card3_m .irepair-card3__media .ty-image-zoom__wrapper > a {
  position: relative;
  aspect-ratio: 16 / 10;
}
.irepair-card3.irepair-card3_m .irepair-card3__media .ty-image-zoom__wrapper > a img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.irepair-card3.irepair-card3_m .irepair-card3__mid .ut2-pb__options {
  margin: 0 0 20px;
}
/* плитки вариантов — в две равные колонки на всю ширину */
.irepair-card3.irepair-card3_m .irepair-card3__mid .ty-product-options__item > .ty-clear-both {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.irepair-card3.irepair-card3_m .irepair-card3__mid .ty-product-options__radio--label {
  min-width: 0;
  width: auto;
  margin: 0;
  white-space: normal;
}
.irepair-card3.irepair-card3_m .irepair-card3__box {
  padding: 20px;
  border-radius: 18px;
}
.irepair-card3.irepair-card3_m .irepair-card3__box .irepair-reward__card {
  margin: 0 0 18px;
  padding: 0 0 18px;
}
.irepair-card3.irepair-card3_m .irepair-card3__pay-label {
  font-size: 16px;
}
.irepair-card3.irepair-card3_m .irepair-card3__pay-price .ty-price,
.irepair-card3.irepair-card3_m .irepair-card3__pay-price .ty-price-num {
  font-size: 28px;
  line-height: 36px;
}
.irepair-card3.irepair-card3_m .irepair-card3__side .ut2-pb__button {
  margin: 16px 0 0;
  justify-content: center;
}
.irepair-card3.irepair-card3_m .irepair-card3__promo-m {
  margin: 24px 0 0;
}
.irepair-card3.irepair-card3_m .irepair-card3__promo-m .irepair-product-promo {
  margin: 0;
}
</style>
{/literal}
