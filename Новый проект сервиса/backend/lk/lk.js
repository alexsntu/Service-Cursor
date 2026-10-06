/* Личный кабинет iRepair — интерфейс. На сервере: /ajax/lk/lk.js. Рисует всё внутри <div id="irepair-lk">. */
(function () {
  'use strict';

  var root = document.getElementById('irepair-lk');
  if (!root) return;

  var API = '/ajax/lk/api.php';
  var ERRORS = {
    bad_phone: 'Некорректный номер телефона',
    bad_code: 'Неверный код подтверждения',
    code_expired: 'Код больше не действует. Запросите новый',
    too_many: 'Слишком много запросов. Попробуйте позже',
    sms: 'Не удалось отправить СМС. Попробуйте ещё раз',
    service: 'Сервис временно недоступен. Попробуйте позже',
    bad_email: 'Проверьте адрес почты',
    bad_birthday: 'Проверьте дату рождения',
    already: 'Баллы по этому заказу уже списаны',
    bad_status: 'По этому заказу баллы сейчас списать нельзя',
    no_points: 'Нет баллов для списания',
    disabled: 'Списание баллов временно недоступно',
    bonus_failed: 'Баллы списать не удалось, стоимость заказа не изменилась',
    review: 'Списание по этому заказу проверяет менеджер',
    in_progress: 'Списание уже выполняется, подождите несколько секунд'
  };
  var CHECK = '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true"><path d="M1 6.6l3 3.1L11 2.3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  function api(action, data) {
    var body = new URLSearchParams();
    body.set('action', action);
    Object.keys(data || {}).forEach(function (k) { body.set(k, data[k]); });
    return fetch(API, { method: 'POST', credentials: 'same-origin', headers: { 'X-Requested-With': 'irepair-lk' }, body: body })
      .then(function (r) { return r.json(); })
      .catch(function () { return { ok: false, error: 'service' }; });
  }

  function errText(res) {
    if (res && res.error === 'wait') return 'Новый код можно запросить через ' + (res.wait || 60) + ' сек.';
    return ERRORS[res && res.error] || 'Что-то пошло не так. Попробуйте ещё раз';
  }

  /* el('div.cls', {attr: value}, [children | text]) */
  function el(spec, attrs, children) {
    var parts = spec.split('.');
    var node = document.createElement(parts[0] || 'div');
    if (parts.length > 1) node.className = parts.slice(1).map(function (c) { return 'irepair-lk__' + c; }).join(' ');
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'html') node.innerHTML = attrs[k];
      else if (k.indexOf('on') === 0) node.addEventListener(k.slice(2), attrs[k]);
      else if (attrs[k] !== false && attrs[k] != null) node.setAttribute(k, attrs[k] === true ? '' : attrs[k]);
    });
    (function add(c) {
      if (c == null || c === false) return;
      if (Array.isArray(c)) c.forEach(add);
      else node.appendChild(typeof c === 'object' ? c : document.createTextNode(String(c)));
    })(children);
    return node;
  }

  function show(node) {
    root.innerHTML = '';
    root.appendChild(node);
  }

  function money(n) { return Number(n || 0).toLocaleString('ru-RU') + ' ₽'; }

  function points(n) {
    n = Number(n || 0);
    var a = Math.abs(n) % 100, b = a % 10;
    var word = a > 10 && a < 20 ? 'баллов' : b === 1 ? 'балл' : b >= 2 && b <= 4 ? 'балла' : 'баллов';
    return n.toLocaleString('ru-RU') + ' ' + word;
  }

  /* ---------- вход ---------- */

  function authCard(children) {
    return el('div.auth', null, [el('div.auth-card', null, children)]);
  }

  function renderLogin(prefill, notice) {
    var input = el('input.input', { type: 'tel', name: 'phone', placeholder: '+7 (___) ___-__-__', autocomplete: 'tel', inputmode: 'tel', required: true });
    var error = el('div.error', { role: 'alert' }, notice || '');
    var button = el('button.btn', { type: 'submit' }, 'Получить код');
    var mask = window.IMask ? window.IMask(input, { mask: '+{7} (000) 000-00-00' }) : null;
    if (prefill) { if (mask) mask.value = prefill; else input.value = prefill; }

    var form = el('form', {
      novalidate: true,
      onsubmit: function (e) {
        e.preventDefault();
        var digits = input.value.replace(/\D/g, '');
        if (digits.length !== 11) { error.textContent = ERRORS.bad_phone; return; }
        error.textContent = '';
        button.disabled = true;
        api('send_code', { phone: digits }).then(function (res) {
          button.disabled = false;
          if (res.ok && res.status === 'sent') renderCode(digits, input.value, res.wait || 60);
          else if (res.ok && res.status === 'not_found') renderNotFound(input.value);
          else error.textContent = errText(res);
        });
      }
    }, [
      input, error, button,
      el('p.note', null, ['Нажимая «Получить код», вы соглашаетесь с условиями обработки ', el('a', { href: '/privacy/' }, 'персональных данных')]),
      el('a.link', { href: '/programma-loyalnosti/' }, 'Подробнее о программе лояльности')
    ]);
    show(authCard([el('h2.auth-title', null, 'Вход в личный кабинет'), form]));
    input.focus();
  }

  function renderCode(digits, shown, wait) {
    var input = el('input.input.input-code', { type: 'text', name: 'code', maxlength: 4, inputmode: 'numeric', autocomplete: 'one-time-code', placeholder: '••••' });
    var error = el('div.error', { role: 'alert' });
    var timer = el('p.note');
    var resend = el('button.text-btn', { type: 'button', hidden: true }, 'Отправить код заново');
    var busy = false, left = wait, tick, abort;

    function countdown() {
      clearInterval(tick);
      resend.hidden = true;
      timer.hidden = false;
      timer.textContent = 'Получить новый код можно через ' + left + ' сек.';
      tick = setInterval(function () {
        left -= 1;
        if (left > 0) { timer.textContent = 'Получить новый код можно через ' + left + ' сек.'; return; }
        clearInterval(tick);
        timer.hidden = true;
        resend.hidden = false;
      }, 1000);
    }

    function leave() {
      clearInterval(tick);
      if (abort) abort.abort();
    }

    function check() {
      var code = input.value.replace(/\D/g, '');
      if (code !== input.value) input.value = code;
      error.textContent = '';
      if (code.length !== 4 || busy) return;
      busy = true;
      api('check_code', { phone: digits, code: code }).then(function (res) {
        busy = false;
        if (res.ok) { leave(); loadCabinet(); return; }
        error.textContent = errText(res);
        input.value = '';
        input.focus();
      });
    }

    input.addEventListener('input', check);
    resend.addEventListener('click', function () {
      resend.disabled = true;
      api('send_code', { phone: digits }).then(function (res) {
        resend.disabled = false;
        if (res.ok && res.status === 'sent') { left = res.wait || 60; error.textContent = ''; countdown(); }
        else error.textContent = errText(res);
      });
    });

    show(authCard([
      el('h2.auth-title', null, 'Введите код'),
      el('p.auth-text', null, ['Мы отправили код подтверждения на номер ', el('b', null, shown)]),
      el('button.text-btn', { type: 'button', onclick: function () { leave(); renderLogin(shown); } }, 'Изменить номер'),
      input, error, timer, resend
    ]));
    input.focus();
    countdown();

    // Автоподстановка кода из СМС (Android/Chrome)
    if ('OTPCredential' in window && navigator.credentials && window.AbortController) {
      abort = new AbortController();
      navigator.credentials.get({ otp: { transport: ['sms'] }, signal: abort.signal })
        .then(function (otp) { if (otp && otp.code) { input.value = otp.code; check(); } })
        .catch(function () {});
    }
  }

  function renderNotFound(shown) {
    show(authCard([
      el('h2.auth-title', null, 'Пользователь не найден'),
      el('p.auth-text', null, ['Войти могут клиенты, зарегистрированные в ', el('a', { href: '/programma-loyalnosti/' }, 'программе лояльности'), '. Проверьте номер или свяжитесь с нами — поможем.']),
      el('button.btn', { type: 'button', onclick: function () { renderLogin(shown); } }, 'Ввести другой номер'),
      el('div.contacts', null, [
        el('a', { href: 'tel:+78005552190' }, '8 800 555-21-90'),
        el('a', { href: 'https://t.me/iRepair_Moscow_bot', target: '_blank', rel: 'noopener' }, 'Telegram')
      ])
    ]));
  }

  /* ---------- кабинет ---------- */

  function row(label, value) {
    return el('li', null, [el('span.row-label', null, label), el('span.row-value', null, value)]);
  }

  /* Заказ — сворачиваемая строка: в шапке номер, устройство, статус и сумма; при раскрытии — все сведения и состав заказа */
  function orderCard(o, isCurrent, reload, open) {
    var items = el('div.items', null, el('p.empty', null, 'Загружаем состав заказа…'));
    var loaded = false;

    function warrantyLine(w) {
      if (!w || !w.text) return null;
      if (!w.to) return row('Гарантия', w.text);
      return row('Гарантия ' + w.text, [
        'с ' + w.from + ' по ' + w.to + ' ',
        el('span.badge' + (w.active ? '' : '.badge-off'), null, w.active ? 'действует' : 'истекла')
      ]);
    }

    function loadItems() {
      if (loaded) return;
      loaded = true;
      api('order_items', { order_id: o.id }).then(function (res) {
        items.innerHTML = '';
        if (!res.ok) { loaded = false; items.appendChild(el('p.empty', null, errText(res))); return; }
        if (!res.items.length) { items.appendChild(el('p.empty', null, 'В заказ пока не добавлены услуги.')); return; }
        res.items.forEach(function (it) {
          items.appendChild(el('div.item', null, [
            el('div.item-head', null, [el('span.item-title', null, it.title), el('span.item-price', null, money(it.price))]),
            el('ul.rows', null, warrantyLine(it.warranty))
          ]));
        });
      });
    }

    var card = el('details.order', { open: !!open, 'data-order-id': o.id }, [
      el('summary.order-head', null, [
        el('span.order-main', null, [el('span.order-title', null, 'Заказ №' + o.label), o.device ? el('span.order-device', null, o.device) : null]),
        el('span.order-meta', null, [
          o.status ? el('span.status' + (isCurrent ? '' : '.status-done'), null, o.status) : null,
          el('span.order-price', null, money(o.price))
        ]),
        el('span.order-arrow', { 'aria-hidden': 'true' })
      ]),
      el('div.order-body', null, [
        el('ul.rows', null, [
          row('Дата приёма', o.date),
          o.closed ? row('Дата закрытия', o.closed) : null,
          row('Стоимость', money(o.price)),
          row('Кешбэк', points(o.cashback)),
          isCurrent && !o.spent && o.available > 0 ? row('Доступно к списанию', points(o.available)) : null
        ]),
        o.spent > 0 ? el('div.success', { html: CHECK + '<span>Списано ' + points(o.spent).replace(/&/g, '&amp;') + '</span>' }) : null,
        isCurrent && o.spend_review && !o.spent ? el('p.note', null, 'Списание баллов по этому заказу проверяет менеджер. Вопросы — по телефону 8 800 555-21-90.') : null,
        items,
        isCurrent && o.can_spend ? el('div.order-actions', null, el('button.btn.btn-small', { type: 'button', onclick: function () { confirmSpend(o, reload); } }, 'Списать баллы')) : null
      ])
    ]);
    card.addEventListener('toggle', function () { if (card.open) loadItems(); });
    if (open) loadItems();
    return card;
  }

  /* Раскрыть заказ в списке и прокрутить к нему (переход из истории баллов) */
  function showOrder(id) {
    var card = root.querySelector('[data-order-id="' + id + '"]');
    if (!card) return;
    var hiddenBox = card.parentNode;
    if (hiddenBox.hidden) {                       // заказ под «Показать все заказы»
      hiddenBox.hidden = false;
      if (hiddenBox.nextSibling) hiddenBox.nextSibling.remove();
    }
    card.open = true;
    card.scrollIntoView({ behavior: 'smooth', block: 'center' });
    card.classList.add('irepair-lk__order-flash');
    setTimeout(function () { card.classList.remove('irepair-lk__order-flash'); }, 1800);
  }

  /* Список заказов: длинный хвост прячем под «Показать все» */
  function orderList(list, isCurrent, reload, limit) {
    // текущие раскрыты, если их один-два или по заказу можно списать баллы; история свёрнута
    var nodes = list.map(function (o) { return orderCard(o, isCurrent, reload, isCurrent && (list.length <= 2 || o.can_spend)); });
    if (nodes.length <= limit) return nodes;
    var rest = el('div', { hidden: true }, nodes.slice(limit));
    var more = el('button.text-btn.more', { type: 'button' }, 'Показать все заказы (' + nodes.length + ')');
    more.addEventListener('click', function () { rest.hidden = false; more.remove(); });
    return nodes.slice(0, limit).concat([rest, more]);
  }

  function renderCabinet(data) {
    var p = data.profile, b = data.bonus;
    var reload = function () { loadCabinet(true); };
    var name = [p.first_name, p.last_name].join(' ').trim();

    /* История баллов: раскрывается под картой, загружается при первом открытии */
    var bonusList = el('div.bonus-list', { hidden: true });
    var bonusLoaded = false;
    var bonusToggle = el('button.text-btn', { type: 'button' }, 'История баллов');
    bonusToggle.addEventListener('click', function () {
      bonusList.hidden = !bonusList.hidden;
      bonusToggle.textContent = bonusList.hidden ? 'История баллов' : 'Скрыть историю баллов';
      if (bonusLoaded || bonusList.hidden) return;
      bonusLoaded = true;
      bonusList.appendChild(el('p.empty', null, 'Загружаем…'));
      api('bonus_history').then(function (res) {
        bonusList.innerHTML = '';
        if (!res.ok) { bonusLoaded = false; bonusList.appendChild(el('p.empty', null, errText(res))); return; }
        if (!res.items.length) { bonusList.appendChild(el('p.empty', null, 'Операций с баллами пока не было.')); return; }
        res.items.forEach(function (it) {
          bonusList.appendChild(el('div.bonus-row', null, [
            el('span.bonus-main', null, [
              el('span.bonus-title', null, [
                it.title,
                it.order ? ' · ' : null,
                // номер заказа — ссылка: раскрывает этот заказ ниже в кабинете
                it.order_id ? el('button.text-btn.bonus-order', { type: 'button', onclick: function () { showOrder(it.order_id); } }, 'заказ №' + it.order)
                  : (it.order ? 'заказ №' + it.order : null)
              ]),
              el('span.bonus-date', null, it.date)
            ]),
            el('span.bonus-amount' + (it.amount > 0 ? '.bonus-plus' : ''), null, (it.amount > 0 ? '+' : '\u2212') + Math.abs(it.amount).toLocaleString('ru-RU'))
          ]));
        });
      });
    });

    var card = b.found
      ? el('div.card.loyalty.loyalty-' + (b.card || 'silver').toLowerCase(), null, [
          el('div.loyalty-top', null, [el('div.loyalty-tier', null, b.card), el('div.loyalty-points', null, points(b.points))]),
          el('div.loyalty-text', null, 'Кешбэк ' + b.cashback_percent + '% · оплата баллами до ' + b.debit_percent + '% стоимости ремонта'),
          el('div.loyalty-links', null, [bonusToggle, el('a.loyalty-link', { href: '/programma-loyalnosti/' }, 'Подробнее о программе лояльности')]),
          bonusList
        ])
      : el('div.card.loyalty', null, [
          el('div.loyalty-tier', null, 'Программа лояльности'),
          el('div.loyalty-text', null, 'Карта пока не найдена. Напишите нам — проверим и подключим.'),
          el('a.loyalty-link', { href: '/programma-loyalnosti/' }, 'Подробнее о программе лояльности')
        ]);

    var current = el('div.card', null, [
      el('h2.title', null, 'Текущие заказы'),
      !data.orders_ok ? el('p.empty', null, 'Не удалось загрузить заказы. Обновите страницу чуть позже.')
        : data.orders.length ? orderList(data.orders, true, reload, 10)
        : el('p.empty', null, 'Сейчас у вас нет заказов в работе.')
    ]);

    var history = el('div.card', null, [
      el('h2.title', null, 'История заказов'),
      data.history.length ? orderList(data.history, false, reload, 5)
        : el('p.empty', { html: 'У вас нет ни одного выполненного заказа.<br>Но скоро будет :)' })
    ]);

    /* Личные данные: сворачиваемый блок (как заказы), поля сохраняются сразу при изменении.
       Имя правится только в кабинете — в RemOnline и BonusPlus не уходит. */
    var firstName = el('input.input', { type: 'text', value: p.first_name, placeholder: 'Имя', autocomplete: 'given-name', maxlength: 100 });
    var lastName = el('input.input', { type: 'text', value: p.last_name, placeholder: 'Фамилия', autocomplete: 'family-name', maxlength: 100 });
    var email = el('input.input', { type: 'email', value: p.email, placeholder: 'Email', autocomplete: 'email' });
    var birthday = el('input.input', { type: 'date', value: p.birthday || '', max: new Date().toISOString().slice(0, 10) });
    var gender = el('select.input', null, [
      el('option', { value: '' }, 'Не выбрано'),
      el('option', { value: 'M', selected: p.gender === 'M' }, 'Мужской'),
      el('option', { value: 'F', selected: p.gender === 'F' }, 'Женский')
    ]);
    var saved = el('div.saved', { role: 'status' });
    var savedTimer;
    var hello = el('div.hello', null, name ? 'Здравствуйте, ' + name : 'Здравствуйте');
    var personName = el('span.person-name', null, name || 'Имя не указано');
    function save() {
      api('save_profile', {
        first_name: firstName.value.trim(), last_name: lastName.value.trim(),
        email: email.value.trim(), birthday: birthday.value, gender: gender.value
      }).then(function (res) {
        clearTimeout(savedTimer);
        saved.className = 'irepair-lk__saved' + (res.ok ? ' irepair-lk__saved-ok' : ' irepair-lk__saved-err');
        saved.textContent = res.ok ? 'Сохранено' : errText(res);
        if (!res.ok) return;
        savedTimer = setTimeout(function () { saved.textContent = ''; }, 2500);
        var full = [firstName.value.trim(), lastName.value.trim()].join(' ').trim();
        hello.textContent = full ? 'Здравствуйте, ' + full : 'Здравствуйте';
        personName.textContent = full || 'Имя не указано';
      });
    }
    [firstName, lastName, email, birthday, gender].forEach(function (f) { f.addEventListener('change', save); });
    function field(label, input) { return el('label.field', null, [el('span.field-label', null, label), input]); }

    var personal = el('details.card.person', null, [
      el('summary.person-head', null, [
        el('span.person-main', null, [
          el('span.person-title', null, 'Личные данные'),
          personName,
          el('span.person-phone', null, p.phone)
        ]),
        el('span.person-edit', null, 'Изменить'),
        el('span.order-arrow', { 'aria-hidden': 'true' })
      ]),
      el('div.person-body', null, [
        field('Имя', firstName),
        field('Фамилия', lastName),
        el('p.note.person-note', null, 'Имя меняется только в личном кабинете. Чтобы изменить телефон, обратитесь в сервис.'),
        field('Телефон', el('input.input', { type: 'tel', value: p.phone, disabled: true })),
        field('Email', email),
        field('Дата рождения', birthday),
        field('Пол', gender),
        saved
      ])
    ]);

    /* Избранные услуги — избранное CS-Cart (страница /wishlist/), привязанное к клиенту кабинета */
    var favBody = el('div.fav', null, el('p.empty', null, 'Загружаем…'));
    function loadFavorites() {
      fetch('/index.php?dispatch=irepair_wishlist.list', { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } })
        .then(function (r) { return r.json(); })
        .then(function (res) {
          favBody.innerHTML = '';
          if (!res.ok || !res.items.length) {
            favBody.appendChild(el('p.empty', null, ['Пока пусто. Нажмите на сердечко на странице услуги — она появится здесь. ', el('a', { href: '/catalog/' }, 'Перейти в каталог')]));
            return;
          }
          res.items.forEach(function (it) {
            var rowNode = el('div.fav-row', null, [
              el('a.fav-img', { href: it.url, tabindex: '-1', 'aria-hidden': 'true' }, it.image ? el('img', { src: it.image, alt: '', loading: 'lazy' }) : null),
              el('span.fav-main', null, [el('a.fav-name', { href: it.url }, it.name), el('span.fav-price', null, money(Math.round(it.price)))]),
              el('button.fav-del', {
                type: 'button', 'aria-label': 'Убрать из избранного', title: 'Убрать из избранного',
                onclick: function () {
                  rowNode.style.opacity = '0.4';
                  // CS-Cart удаляет из избранного только POST-запросом со своим защитным ключом страницы
                  var body = new URLSearchParams();
                  body.set('dispatch', 'wishlist.delete');
                  body.set('cart_id', it.cart_id);
                  body.set('security_hash', (window.Tygh && window.Tygh.security_hash) || '');
                  fetch('/index.php', { method: 'POST', credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' }, body: body })
                    .then(loadFavorites, loadFavorites);
                }
              }, '\u00d7')
            ]);
            favBody.appendChild(rowNode);
          });
        })
        .catch(function () {
          favBody.innerHTML = '';
          favBody.appendChild(el('p.empty', null, 'Не удалось загрузить избранное. Обновите страницу.'));
        });
    }
    var favorites = el('div.card', null, [el('h2.title', null, 'Избранные услуги'), favBody]);
    loadFavorites();

    /* Просмотренные услуги — сохранены за клиентом, последние первыми; показываем 4, остальные по кнопке */
    var viewedBody = el('div.fav', null, el('p.empty', null, 'Загружаем…'));
    var viewed = el('div.card', null, [el('h2.title', null, 'Просмотренные услуги'), viewedBody]);
    fetch('/index.php?dispatch=irepair_wishlist.viewed', { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } })
      .then(function (r) { return r.json(); })
      .then(function (res) {
        viewedBody.innerHTML = '';
        if (!res.ok || !res.items.length) {
          viewedBody.appendChild(el('p.empty', null, ['Здесь появятся услуги, которые вы смотрели на сайте. ', el('a', { href: '/catalog/' }, 'Перейти в каталог')]));
          return;
        }
        var rows = res.items.map(function (it) {
          return el('div.fav-row', null, [
            el('a.fav-img', { href: it.url, tabindex: '-1', 'aria-hidden': 'true' }, it.image ? el('img', { src: it.image, alt: '', loading: 'lazy' }) : null),
            el('span.fav-main', null, [el('a.fav-name', { href: it.url }, it.name), el('span.fav-price', null, money(Math.round(it.price)))])
          ]);
        });
        if (rows.length <= 4) { rows.forEach(function (n) { viewedBody.appendChild(n); }); return; }
        var rest = el('div.fav-rest', { hidden: true }, rows.slice(4));
        var more = el('button.text-btn.more', { type: 'button' }, 'Показать все (' + rows.length + ')');
        more.addEventListener('click', function () { rest.hidden = false; more.remove(); });
        rows.slice(0, 4).forEach(function (n) { viewedBody.appendChild(n); });
        viewedBody.appendChild(rest);
        viewedBody.appendChild(more);
      })
      .catch(function () { viewedBody.innerHTML = ''; viewedBody.appendChild(el('p.empty', null, 'Не удалось загрузить список. Обновите страницу.')); });

    show(el('div.cabinet', null, [
      el('div.top', null, [
        hello,
        el('button.logout', { type: 'button', onclick: function () { api('logout').then(function () { releaseFavorites(); renderLogin(); }); } }, 'Выйти')
      ]),
      // первый ряд — карта и личные данные одной высоты, второй — текущие заказы и история на одном уровне
      el('div.grid.grid-top', null, [card, personal]),
      el('div.grid', null, [el('div.col', null, [current, favorites]), el('div.col', null, [history, viewed])])
    ]));
  }

  /* ---------- окна ---------- */

  function modal(children) {
    var overlay = el('div.modal', { role: 'dialog', 'aria-modal': 'true' });
    function close() {
      document.removeEventListener('keydown', onKey);
      overlay.remove();
    }
    function onKey(e) { if (e.key === 'Escape') close(); }
    overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
    document.addEventListener('keydown', onKey);
    overlay.appendChild(el('div.modal-card', null, [el('button.modal-close', { type: 'button', 'aria-label': 'Закрыть', onclick: close }, '×')].concat(children)));
    root.appendChild(overlay);
    return close;
  }

  function confirmSpend(o, reload) {
    var error = el('div.error', { role: 'alert' });
    var button = el('button.btn', { type: 'button' }, 'Списать ' + points(o.available));
    var close = modal([
      el('h2.title', null, 'Списать баллы'),
      el('p.auth-text', null, 'В счёт заказа №' + o.label + ' будет списано до ' + points(o.available) + '. Стоимость заказа уменьшится на эту сумму. Отменить списание из кабинета нельзя.'),
      error, button
    ]);
    button.addEventListener('click', function () {
      button.disabled = true;
      error.textContent = '';
      api('spend_bonus', { order_id: o.id }).then(function (res) {
        if (res.ok) { close(); reload(); return; }
        button.disabled = false;
        error.textContent = errText(res) + '. Если ошибка сохранится, позвоните нам: 8 800 555-21-90';
      });
    });
  }

  /* Клиент вышел из кабинета (или вход истёк): избранное, загруженное в этот браузер из его кабинета, убираем —
     оно остаётся за клиентом и вернётся при следующем входе */
  function releaseFavorites() {
    var body = new URLSearchParams();
    body.set('dispatch', 'irepair_wishlist.release');
    body.set('security_hash', (window.Tygh && window.Tygh.security_hash) || '');
    fetch('/index.php', { method: 'POST', credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' }, body: body }).catch(function () {});
  }

  /* ---------- запуск ---------- */

  function loadCabinet(silent) {
    if (!silent) show(el('div.loading', null, 'Загружаем…'));
    api('me').then(function (res) {
      if (res.ok && res.auth) renderCabinet(res);
      else if (res.ok) { releaseFavorites(); renderLogin(); }
      else renderLogin('', errText(res));
    });
  }

  loadCabinet();
})();
