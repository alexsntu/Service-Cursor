{* iRepair — мобильная карточка: после выбора опции (варианта) плавно прокручиваем страницу к заголовку услуги.
   Подключается только в мобильном шаблоне (irepair_service_mobile.tpl). При первой загрузке страницы не срабатывает.
   Скрипт может попасть в ajax-ответ повторно — защищён флагом window.irpMobileVariantScroll. *}
{literal}
<script>
(function (_, $) {
  if (!$ || window.irpMobileVariantScroll) {
    return;
  }
  window.irpMobileVariantScroll = true;

  var pendingUntil = 0;
  var OPTIONS_SELECTOR = '.ut2-pb-mobile .cm-picker-product-variation-features';

  /* высота закреплённой сверху шапки (fixed/sticky элементы у верхнего края экрана) */
  function irpTopOffset() {
    var offset = 0;
    var els = document.elementsFromPoint ? document.elementsFromPoint(window.innerWidth / 2, 2) : [];
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      while (el && el !== document.body && el !== document.documentElement) {
        var pos = window.getComputedStyle(el).position;
        if (pos === 'fixed' || pos === 'sticky') {
          var r = el.getBoundingClientRect();
          if (r.top <= 2 && r.bottom > offset && r.bottom < window.innerHeight / 2) {
            offset = r.bottom;
          }
          break;
        }
        el = el.parentElement;
      }
    }
    return offset;
  }

  function irpScrollToTitle() {
    var title = document.querySelector('.ut2-pb-mobile .ut2-pb__title');
    if (!title) {
      return;
    }
    var top = title.getBoundingClientRect().top + window.pageYOffset - irpTopOffset() - 12;
    window.scrollTo({ top: Math.max(0, top), behavior: 'smooth' });
  }

  /* пользователь выбрал опцию — ждём обновления карточки (до 10 секунд) */
  $(document).on('click change', OPTIONS_SELECTOR + ' input, ' + OPTIONS_SELECTOR + ' label, ' + OPTIONS_SELECTOR + ' a, ' + OPTIONS_SELECTOR + ' select', function () {
    pendingUntil = Date.now() + 10000;
  });

  function irpAfterUpdate() {
    if (!pendingUntil || Date.now() > pendingUntil) {
      return;
    }
    pendingUntil = 0;
    window.setTimeout(irpScrollToTitle, 60);
  }

  $.ceEvent('on', 'ce.commoninit', irpAfterUpdate);
  $.ceEvent('on', 'ce.ajaxdone', irpAfterUpdate);
}(window.Tygh, window.Tygh && window.Tygh.$));
</script>
{/literal}
