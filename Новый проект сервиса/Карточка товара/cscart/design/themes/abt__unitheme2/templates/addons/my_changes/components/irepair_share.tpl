{* iRepair — «Поделиться» в карточке услуги: окно в духе меню «Поделиться» на iOS.
   Сверху — что отправляем (фото, название, сайт); ряд приложений: Telegram, MAX, Почта, «Ещё» (системное меню
   устройства, если браузер его поддерживает); ниже — «Скопировать ссылку».
   На компьютере окно по центру экрана, на телефоне выезжает снизу. Закрытие: крестик, клик мимо окна, Esc.
   Отправляется адрес открытой страницы (с выбранным вариантом) и название услуги.
   Стандартная кнопка «Поделиться» темы (Twitter / Facebook / Pinterest) в нашем макете скрыта. *}
<button type="button" class="irepair-share__open" data-irp-share-open>
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 15V3.5M12 3.5L7.5 8M12 3.5L16.5 8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M8 11H6.5A1.5 1.5 0 0 0 5 12.5v7A1.5 1.5 0 0 0 6.5 21h11a1.5 1.5 0 0 0 1.5-1.5v-7a1.5 1.5 0 0 0-1.5-1.5H16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span>Поделиться</span>
</button>

<div class="irepair-share" data-irp-share hidden>
    <div class="irepair-share__sheet" role="dialog" aria-modal="true" aria-label="Поделиться">
        <div class="irepair-share__head">
            <span class="irepair-share__thumb"><img data-irp-share-img src="" alt="" width="48" height="48" hidden></span>
            <span class="irepair-share__what">
                <span class="irepair-share__name" data-irp-share-name></span>
                <span class="irepair-share__site" data-irp-share-site></span>
            </span>
            <button type="button" class="irepair-share__close" data-irp-share-close aria-label="Закрыть">
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true"><path d="M1 1L11 11M11 1L1 11" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
            </button>
        </div>

        <div class="irepair-share__apps">
            <a class="irepair-share__app" data-irp-share-to="telegram" href="#" target="_blank" rel="noopener nofollow">
                <span class="irepair-share__icon irepair-share__icon_telegram"><svg width="30" height="30" viewBox="0 0 24 24" aria-hidden="true"><path fill="#ffffff" d="M20.67 4.2 2.93 11.04c-1.21.49-1.2 1.16-.22 1.46l4.55 1.42 10.54-6.65c.5-.3.95-.14.58.19l-8.54 7.7h0l-.31 4.7c.46 0 .66-.21.92-.46l2.21-2.15 4.6 3.4c.85.47 1.46.23 1.67-.79l3.02-14.25c.31-1.24-.47-1.8-1.28-1.41z"/></svg></span>
                <span class="irepair-share__label">Telegram</span>
            </a>
            <a class="irepair-share__app" data-irp-share-to="max" href="#" target="_blank" rel="noopener nofollow">
                <span class="irepair-share__icon irepair-share__icon_max"><svg width="30" height="30" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3.2c-4.86 0-8.8 3.82-8.8 8.53 0 1.55.43 3.06 1.24 4.38l-.9 3.6c-.12.5.34.94.83.79l3.47-1.03a8.98 8.98 0 0 0 4.16 1.02c4.86 0 8.8-3.82 8.8-8.53S16.86 3.2 12 3.2z" fill="#ffffff"/><circle cx="12" cy="11.75" r="3.6" fill="none" stroke="#5b5bf5" stroke-width="2.2"/></svg></span>
                <span class="irepair-share__label">MAX</span>
            </a>
            <a class="irepair-share__app" data-irp-share-to="mail" href="#">
                <span class="irepair-share__icon irepair-share__icon_mail"><svg width="30" height="30" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="5.5" width="18" height="13" rx="2.4" fill="#ffffff"/><path d="M4 7.2l8 6 8-6" stroke="#1e8bf0" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg></span>
                <span class="irepair-share__label">Почта</span>
            </a>
            <button type="button" class="irepair-share__app" data-irp-share-to="more" hidden>
                <span class="irepair-share__icon irepair-share__icon_more"><svg width="30" height="30" viewBox="0 0 24 24" aria-hidden="true"><circle cx="6" cy="12" r="1.9" fill="#3e3e3e"/><circle cx="12" cy="12" r="1.9" fill="#3e3e3e"/><circle cx="18" cy="12" r="1.9" fill="#3e3e3e"/></svg></span>
                <span class="irepair-share__label">Ещё</span>
            </button>
        </div>

        <div class="irepair-share__actions">
            <button type="button" class="irepair-share__action" data-irp-share-to="copy">
                <span class="irepair-share__action-text" data-irp-share-copy-text>Скопировать ссылку</span>
                <svg class="irepair-share__action-icon" width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="8.5" y="8.5" width="11" height="12" rx="2.4" stroke="currentColor" stroke-width="1.7"/><path d="M15.5 5.9V5.4A2.4 2.4 0 0 0 13.1 3H6.9A2.4 2.4 0 0 0 4.5 5.4v7.2A2.4 2.4 0 0 0 6.9 15h.2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
            </button>
        </div>
    </div>
</div>

{literal}
<script>
/* iRepair: окно «Поделиться» в карточке услуги */
(function () {
  if (window.irpShareSheet) { return; }
  window.irpShareSheet = true;

  var copyTimer = null;

  function sheet() {
    return document.querySelector('[data-irp-share]');
  }

  // что отправляем: адрес открытой страницы (без якоря) и название услуги
  function shareData() {
    var h1 = document.querySelector('.ut2-pb h1');
    var title = h1 ? h1.textContent.replace(/\s+/g, ' ').trim() : document.title;
    return { title: title, url: window.location.href.split('#')[0] };
  }

  function openSheet() {
    var box = sheet();
    if (!box) { return; }
    var data = shareData();
    var enc = encodeURIComponent;

    box.querySelector('[data-irp-share-name]').textContent = data.title;
    box.querySelector('[data-irp-share-site]').textContent = window.location.hostname.replace(/^www\./, '');
    var img = box.querySelector('[data-irp-share-img]');
    var photo = document.querySelector('.ut2-pb__img img');
    if (photo && (photo.currentSrc || photo.src)) {
      img.src = photo.currentSrc || photo.src;
      img.hidden = false;
    }

    box.querySelector('[data-irp-share-to="telegram"]').href = 'https://t.me/share/url?url=' + enc(data.url) + '&text=' + enc(data.title);
    box.querySelector('[data-irp-share-to="max"]').href = 'https://max.ru/:share?text=' + enc(data.title + ' ' + data.url);
    box.querySelector('[data-irp-share-to="mail"]').href = 'mailto:?subject=' + enc(data.title) + '&body=' + enc(data.title + '\n\n' + data.url);
    // «Ещё» — системное меню «Поделиться» устройства, если браузер его умеет
    box.querySelector('[data-irp-share-to="more"]').hidden = !navigator.share;
    resetCopy(box);

    // окно переносим в конец страницы, чтобы его не обрезали блоки карточки;
    // прежние копии (остаются после смены варианта услуги) убираем
    Array.prototype.forEach.call(document.querySelectorAll('[data-irp-share]'), function (old) {
      if (old !== box && old.parentNode) { old.parentNode.removeChild(old); }
    });
    if (box.parentNode !== document.body) { document.body.appendChild(box); }
    box.hidden = false;
    document.documentElement.classList.add('irepair-share-lock');
    // следующий кадр — чтобы сработала анимация появления
    window.requestAnimationFrame(function () { box.classList.add('is-open'); });
  }

  function closeSheet() {
    var box = sheet();
    if (!box || box.hidden) { return; }
    box.classList.remove('is-open');
    document.documentElement.classList.remove('irepair-share-lock');
    window.setTimeout(function () { box.hidden = true; }, 220);
  }

  function resetCopy(box) {
    window.clearTimeout(copyTimer);
    box.querySelector('[data-irp-share-copy-text]').textContent = 'Скопировать ссылку';
    box.querySelector('[data-irp-share-to="copy"]').classList.remove('is-done');
  }

  function copyLink(box) {
    var url = shareData().url;
    function done() {
      box.querySelector('[data-irp-share-copy-text]').textContent = 'Ссылка скопирована';
      box.querySelector('[data-irp-share-to="copy"]').classList.add('is-done');
      window.clearTimeout(copyTimer);
      copyTimer = window.setTimeout(function () { resetCopy(box); }, 2200);
    }
    function fallback() {
      var area = document.createElement('textarea');
      area.value = url;
      area.setAttribute('readonly', '');
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.appendChild(area);
      area.select();
      try { document.execCommand('copy'); done(); } catch (e) { /* не получилось — текст кнопки не меняем */ }
      document.body.removeChild(area);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(done, fallback);
    } else {
      fallback();
    }
  }

  document.addEventListener('click', function (e) {
    var target = e.target;
    if (!target.closest) { return; }

    if (target.closest('[data-irp-share-open]')) {
      e.preventDefault();
      openSheet();
      return;
    }
    var box = target.closest('[data-irp-share]');
    if (!box) { return; }

    // клик по затемнению или по крестику
    if (target === box || target.closest('[data-irp-share-close]')) {
      e.preventDefault();
      closeSheet();
      return;
    }
    var item = target.closest('[data-irp-share-to]');
    if (!item) { return; }
    var kind = item.getAttribute('data-irp-share-to');
    if (kind === 'copy') {
      e.preventDefault();
      copyLink(box);
    } else if (kind === 'more') {
      e.preventDefault();
      var data = shareData();
      navigator.share({ title: data.title, text: data.title, url: data.url }).then(closeSheet, function () {});
    } else {
      // Telegram / MAX / Почта — обычный переход по ссылке; окно закрываем
      window.setTimeout(closeSheet, 150);
    }
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { closeSheet(); }
  });
}());
</script>

<style>
/* кнопка «Поделиться» рядом с «Отложить» */
.irepair-share__open {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  padding: 0;
  border: 0;
  background: none;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 14px;
  line-height: 20px;
  color: #3e3e3e;
  cursor: pointer;
  transition: color 0.2s ease;
}
.irepair-share__open:hover {
  color: #1fb86a;
}

html.irepair-share-lock {
  overflow: hidden;
}
.irepair-share[hidden] {
  display: none;
}
.irepair-share {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 100000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  background: rgba(1, 3, 6, 0);
  transition: background 0.22s ease;
}
.irepair-share.is-open {
  background: rgba(1, 3, 6, 0.38);
}
.irepair-share .irepair-share__sheet {
  width: 100%;
  max-width: 400px;
  padding: 14px;
  border-radius: 26px;
  background: rgba(242, 242, 247, 0.94);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  backdrop-filter: blur(24px) saturate(180%);
  box-shadow: 0 24px 60px rgba(1, 3, 6, 0.28);
  font-family: 'Roboto', Arial, sans-serif;
  opacity: 0;
  transform: translateY(14px) scale(0.98);
  transition: opacity 0.22s ease, transform 0.22s ease;
}
.irepair-share.is-open .irepair-share__sheet {
  opacity: 1;
  transform: none;
}

/* шапка: что отправляем */
.irepair-share .irepair-share__head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 4px 14px;
}
.irepair-share .irepair-share__thumb {
  flex: 0 0 48px;
  width: 48px;
  height: 48px;
  overflow: hidden;
  border-radius: 12px;
  background: #ffffff;
}
.irepair-share .irepair-share__thumb img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.irepair-share .irepair-share__what {
  flex: 1 1 auto;
  min-width: 0;
}
.irepair-share .irepair-share__name {
  display: block;
  overflow: hidden;
  font-size: 15px;
  line-height: 20px;
  font-weight: 500;
  color: #1d1d1f;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.irepair-share .irepair-share__site {
  display: block;
  font-size: 13px;
  line-height: 18px;
  color: #86868b;
}
.irepair-share .irepair-share__close {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 30px;
  width: 30px;
  height: 30px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: rgba(118, 118, 128, 0.16);
  color: #6e6e73;
  cursor: pointer;
  transition: background 0.2s ease;
}
.irepair-share .irepair-share__close:hover {
  background: rgba(118, 118, 128, 0.28);
}

/* ряд приложений */
.irepair-share .irepair-share__apps {
  display: flex;
  gap: 6px;
  padding: 16px 6px 14px;
  border-top: 1px solid rgba(60, 60, 67, 0.14);
}
.irepair-share .irepair-share__app {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  flex: 0 0 84px;
  width: 84px;
  margin: 0;
  padding: 0;
  border: 0;
  background: none;
  text-decoration: none;
  cursor: pointer;
}
.irepair-share .irepair-share__app[hidden] {
  display: none;
}
.irepair-share .irepair-share__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 60px;
  height: 60px;
  border-radius: 15px;
  box-shadow: 0 2px 8px rgba(1, 3, 6, 0.1);
  transition: filter 0.2s ease;
}
.irepair-share .irepair-share__app:hover .irepair-share__icon {
  filter: brightness(0.93);
}
.irepair-share .irepair-share__icon_telegram {
  background: linear-gradient(180deg, #37bbfe 0%, #1d93d2 100%);
}
.irepair-share .irepair-share__icon_max {
  background: linear-gradient(135deg, #41b6ff 0%, #5b5bf5 55%, #9a45f0 100%);
}
.irepair-share .irepair-share__icon_mail {
  background: linear-gradient(180deg, #5ac8fa 0%, #1e8bf0 100%);
}
.irepair-share .irepair-share__icon_more {
  background: #ffffff;
}
.irepair-share .irepair-share__label {
  font-size: 12px;
  line-height: 16px;
  color: #1d1d1f;
}

/* действия списком */
.irepair-share .irepair-share__actions {
  overflow: hidden;
  border-radius: 14px;
  background: #ffffff;
}
.irepair-share .irepair-share__action {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
  margin: 0;
  padding: 14px 16px;
  border: 0;
  background: none;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 16px;
  line-height: 22px;
  color: #1d1d1f;
  text-align: left;
  cursor: pointer;
  transition: background 0.2s ease;
}
.irepair-share .irepair-share__action:hover {
  background: #f2f2f7;
}
.irepair-share .irepair-share__action-icon {
  flex: 0 0 auto;
  color: #3e3e3e;
}
.irepair-share .irepair-share__action.is-done,
.irepair-share .irepair-share__action.is-done .irepair-share__action-icon {
  color: #1fb86a;
}

/* телефон: окно выезжает снизу */
@media (max-width: 650px) {
  .irepair-share {
    align-items: flex-end;
    padding: 8px;
  }
  .irepair-share .irepair-share__sheet {
    max-width: none;
    padding-bottom: 20px;
    transform: translateY(40px);
  }
  .irepair-share .irepair-share__apps {
    justify-content: space-between;
  }
  .irepair-share .irepair-share__app {
    flex: 1 1 0;
    width: auto;
  }
}
</style>
{/literal}
