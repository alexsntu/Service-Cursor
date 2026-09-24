{* iRepair — бонусный блок «N вернем баллами» (дизайн со старого сайта, .newCard2__point).
   Число = $product.points_info.reward.amount (аддон «Бонусные баллы», правила начисления — в админке, не трогаем).
   Стандартная строка «Бонусные баллы: N баллов» в блоке опций скрыта CSS ниже (только в нашем шаблоне).
   Обновляется при переключении варианта (cm-reload-*). *}
<div class="irepair-reward cm-reload-{$obj_id}" id="irepair_reward_{$obj_id}">
{if $product.points_info.reward.amount}
    <div class="irepair-reward__card">
        <div class="irepair-reward__row">
            <div class="irepair-reward__main">
                <span class="irepair-reward__count">
                    <svg class="irepair-reward__star" width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M8.99993 0C4.0294 0 0 4.0295 0 9C0 13.9705 4.0294 18 8.99993 18C13.9706 18 18 13.9705 18 9C18 4.0295 13.9706 0 8.99993 0ZM14.6436 9.29157C14.0103 10.0803 13.6876 11.0734 13.7365 12.0837L13.7986 13.3716C13.982 14.559 12.746 15.4569 11.6736 14.9155L10.4679 14.4584C9.52217 14.0997 8.47783 14.0997 7.532 14.4584L6.32644 14.9155C5.25384 15.4569 4.01782 14.559 4.20136 13.3716L4.26351 12.0837C4.31229 11.0734 3.98958 10.0803 3.35641 9.29157L2.5492 8.28623C1.70273 7.43329 2.17482 5.98039 3.36095 5.78803L4.60483 5.4492C5.58083 5.18339 6.42565 4.56952 6.98 3.72374L7.68675 2.64523C8.23627 1.57678 9.764 1.57678 10.3135 2.64523L11.0201 3.7236C11.5743 4.56966 12.4194 5.18353 13.3953 5.4492L14.6392 5.78803C15.8252 5.98039 16.2973 7.43315 15.4509 8.28623L14.6436 9.29157Z" fill="#ffffff"></path></svg>
                    <span class="irepair-reward__num">{$product.points_info.reward.amount}</span>
                </span>
                <span class="irepair-reward__label">вернем баллами</span>
            </div>
            <span class="irepair-reward__help" tabindex="0" role="button" aria-label="Как начисляются баллы">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M10.9297 12.0674H9.40527C9.40983 11.6436 9.44629 11.2881 9.51465 11.001C9.58301 10.7093 9.69694 10.445 9.85645 10.208C10.0205 9.97103 10.237 9.72038 10.5059 9.45605C10.7155 9.25553 10.9046 9.06641 11.0732 8.88867C11.2419 8.70638 11.3763 8.51497 11.4766 8.31445C11.5768 8.10938 11.627 7.87467 11.627 7.61035C11.627 7.32324 11.5791 7.07943 11.4834 6.87891C11.3877 6.67839 11.2464 6.52572 11.0596 6.4209C10.8773 6.31608 10.6494 6.26367 10.376 6.26367C10.1481 6.26367 9.93392 6.30924 9.7334 6.40039C9.53288 6.48698 9.37109 6.6237 9.24805 6.81055C9.125 6.99284 9.05892 7.23438 9.0498 7.53516H7.40234C7.41146 6.96094 7.54818 6.47786 7.8125 6.08594C8.07682 5.69401 8.43229 5.40007 8.87891 5.2041C9.32552 5.00814 9.82454 4.91016 10.376 4.91016C10.9867 4.91016 11.5085 5.01497 11.9414 5.22461C12.3743 5.42969 12.7048 5.73047 12.9326 6.12695C13.165 6.51888 13.2812 6.99284 13.2812 7.54883C13.2812 7.94987 13.2015 8.31445 13.042 8.64258C12.8825 8.96615 12.6751 9.26921 12.4199 9.55176C12.1647 9.82975 11.889 10.1077 11.5928 10.3857C11.3376 10.6182 11.1644 10.8711 11.0732 11.1445C10.9821 11.4134 10.9342 11.721 10.9297 12.0674ZM9.26855 14.2002C9.26855 13.9541 9.35286 13.7467 9.52148 13.5781C9.6901 13.4049 9.92025 13.3184 10.2119 13.3184C10.5036 13.3184 10.7337 13.4049 10.9023 13.5781C11.071 13.7467 11.1553 13.9541 11.1553 14.2002C11.1553 14.4463 11.071 14.6559 10.9023 14.8291C10.7337 14.9977 10.5036 15.082 10.2119 15.082C9.92025 15.082 9.6901 14.9977 9.52148 14.8291C9.35286 14.6559 9.26855 14.4463 9.26855 14.2002Z" fill="#C4C4C4"></path><circle cx="10" cy="10" r="9.5" stroke="#C4C4C4"></circle></svg>
                <span class="irepair-reward__tip">
                    <span class="irepair-reward__tip-title">1&nbsp;&#8381; = 1&nbsp;балл</span>
                    <a class="irepair-reward__tip-link" href="/programma-loyalnosti/" target="_blank">Подробнее о&nbsp;кешбэке</a>
                </span>
            </span>
        </div>
    </div>
{/if}
<!--irepair_reward_{$obj_id}--></div>

{literal}
<script>
/* iRepair: на ПК держим блок бонусов на одной линии с кнопкой «Оформить заявку»
   (кнопка сдвигается, когда меняется расшифровка опции под опциями). */
(function (_, $) {
  function irpAlignReward() {
    var cards = document.querySelectorAll('.ut2-pb__last .irepair-reward__card');
    for (var i = 0; i < cards.length; i++) {
      var card = cards[i];
      var box = card.closest('.ut2-pb__content-wrapper');
      var btn = box && box.querySelector('.ut2-pb__first .ut2-pb__button .ty-btn');
      card.style.marginTop = '';
      if (!btn || window.innerWidth < 768) continue;
      var btnR = btn.getBoundingClientRect();
      var cardR = card.getBoundingClientRect();
      /* колонки не рядом (узкий экран) — ничего не делаем */
      if (cardR.left < btnR.right) continue;
      var baseMargin = parseFloat(window.getComputedStyle(card).marginTop) || 0;
      var delta = (btnR.top + btnR.height / 2) - (cardR.top + cardR.height / 2);
      card.style.marginTop = Math.max(12, baseMargin + delta) + 'px';
    }
  }
  function irpSchedule() { window.setTimeout(irpAlignReward, 0); }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', irpSchedule);
  } else {
    irpSchedule();
  }
  window.addEventListener('load', irpSchedule);
  window.addEventListener('resize', irpSchedule);
  if ($ && $.ceEvent) {
    $.ceEvent('on', 'ce.commoninit', irpSchedule);
  }
}(window.Tygh, window.Tygh && window.Tygh.$));
</script>
{/literal}

{literal}
<style>
/* стандартная строка «Бонусные баллы: N баллов» из блока опций — заменена этим блоком */
.ut2-pb__advanced-options .ty-reward-group {
  display: none !important;
}

.irepair-reward,
.irepair-reward * {
  box-sizing: border-box;
}
.ut2-pb__last .irepair-reward .irepair-reward__card {
  margin-top: 24px;
}
.irepair-reward .irepair-reward__card {
  margin-top: 20px;
  padding: 20px 24px;
  background-color: #f8f8f8;
  border-radius: 15px;
}
.irepair-reward .irepair-reward__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  position: relative;
}
.irepair-reward .irepair-reward__main {
  display: flex;
  align-items: center;
  min-width: 0;
}
.irepair-reward .irepair-reward__count {
  display: inline-flex;
  align-items: center;
  flex: 0 0 auto;
  padding: 6px 10px 6px 8px;
  border-radius: 35px;
  background: linear-gradient(106.08deg, #64c3f9 4.34%, #8a37f4 100%);
}
.irepair-reward .irepair-reward__star {
  display: block;
  flex: 0 0 18px;
  margin-right: 8px;
}
.irepair-reward .irepair-reward__num {
  font-size: 20px;
  line-height: 20px;
  font-weight: 500;
  color: #ffffff;
  white-space: nowrap;
}
.irepair-reward .irepair-reward__label {
  display: inline-block;
  margin-left: 16px;
  font-size: 18px;
  line-height: 22px;
  color: #3e3e3e;
}
.irepair-reward .irepair-reward__help {
  position: relative;
  display: inline-flex;
  align-items: center;
  flex: 0 0 auto;
  cursor: pointer;
  outline: none;
}
.irepair-reward .irepair-reward__help svg {
  display: block;
}
.irepair-reward .irepair-reward__tip {
  position: absolute;
  top: 34px;
  right: -14px;
  z-index: 5;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 211px;
  padding: 12px 18px 16px;
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 0 17px rgba(0, 0, 0, 0.15);
  text-align: center;
  opacity: 0;
  visibility: hidden;
  transition: opacity 0.3s, visibility 0.3s;
}
.irepair-reward .irepair-reward__tip::after {
  content: '';
  position: absolute;
  top: -19px;
  right: 14px;
  border: 10px solid transparent;
  border-bottom: 10px solid #ffffff;
}
.irepair-reward .irepair-reward__help:hover .irepair-reward__tip,
.irepair-reward .irepair-reward__help:focus .irepair-reward__tip,
.irepair-reward .irepair-reward__help:focus-within .irepair-reward__tip {
  opacity: 1;
  visibility: visible;
}
.irepair-reward .irepair-reward__tip-title {
  display: block;
  margin-bottom: 8px;
  font-size: 18px;
  line-height: 20px;
  font-weight: 700;
  color: #010306;
}
.irepair-reward .irepair-reward__tip-link {
  display: inline-block;
  font-size: 16px;
  line-height: 18px;
  color: #37d97b;
  text-decoration: none;
  transition: color 0.3s;
}
.irepair-reward .irepair-reward__tip-link:hover {
  color: #12b857;
}

/* узкая правая колонка карточки: подпись в одну строку */
.ut2-pb__last .irepair-reward .irepair-reward__card {
  padding: 16px 18px;
}
.ut2-pb__last .irepair-reward .irepair-reward__label {
  margin-left: 12px;
  font-size: 16px;
  line-height: 20px;
  white-space: nowrap;
}

@media (max-width: 767px) {
  .irepair-reward .irepair-reward__card {
    padding: 16px 18px;
  }
  .irepair-reward .irepair-reward__num {
    font-size: 18px;
    line-height: 18px;
  }
  .irepair-reward .irepair-reward__label {
    margin-left: 12px;
    font-size: 16px;
    line-height: 20px;
  }
}
</style>
{/literal}
