/* iRepair: живой поиск по сайту (свой, не стандартный CS-Cart).
   На сервере: /ajax/irepair-search.js, подключается в коде шапки (блок 190). Стили — в общем irepair-old-header.css.
   Индекс: /ajax/search-index.php (JSON, пересобирается раз в сутки ночью) — грузится один раз при первом открытии поиска.
   - Лупа в шапке (компьютер и телефон) → окно поиска: компьютер — как Spotlight в macOS, телефон — как поиск в iOS.
   - Результаты сразу при вводе: Модели → Услуги (с ценой «от») → Страницы → Статьи. ↑↓ — выбор, Enter — страница
     результатов /search/?q=… (или выбранный результат), Esc — закрыть.
   - Синонимы (айфон/iphone, батарея/аккумулятор…), опечатки, окончания, неправильная раскладка (fqajy → айфон).
   - Ничего не нашли → кнопка «Оставить заявку» (наше окно заявки, data-call-popup-trigger) + популярные услуги.
   - Страница результатов: CS-Cart страница с адресом /search/ и блоком <div data-irepair-search-page></div>. */
(function () {
  'use strict';
  if (window.IrepairSearch) return;

  var INDEX_URL = '/ajax/search-index.php';
  var RESULTS_URL = '/search/';
  var GROUPS = [
    { key: 'c', title: 'Модели', limit: 4 },
    { key: 'sv', title: 'Услуги', limit: 6 },
    { key: 'p', title: 'Страницы', limit: 3 },
    { key: 'b', title: 'Статьи', limit: 2 }
  ];
  var TYPE_WEIGHT = { c: 0.6, v: 0.5, s: 0.4, p: 0.3, b: 0 };

  /* ---------- индекс ---------- */
  var index = null;
  var loading = null;
  var synMap = {};
  var synStems = [];
  var stop = {};
  var vocab = [];
  var serviceWord = {};
  var DEVICES = { iphone: 1, ipad: 1, macbook: 1, imac: 1, watch: 1, airpods: 1 };

  function load() {
    if (index) return Promise.resolve(index);
    if (loading) return loading;
    loading = fetch(INDEX_URL, { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        (d.stop || []).forEach(function (w) { stop[w] = 1; });
        (d.syn || []).forEach(function (group) {
          var canon = group[0];
          group.forEach(function (w) {
            w = basicNorm(w);
            if (w.indexOf(' ') !== -1) return;
            synMap[w] = canon;
            if (w.length >= 4) synStems.push([w, canon]);
          });
        });
        synStems.sort(function (a, b) { return b[0].length - a[0].length; });
        d.items = d.items.map(function (it) {
          var o = { t: it[0], n: it[1], u: it[2], p: it[3], c: it[4], pos: it[5] || 0 };
          o.tk = tokens(o.n);
          return o;
        });
        // словари: слова моделей (из названий категорий) и слова услуг (есть только в услугах)
        var vc = {}, vs = {};
        d.items.forEach(function (it) {
          it.tk.forEach(function (w) { (it.t === 'c' ? vc : vs)[w] = 1; });
        });
        vocab = Object.keys(vc).concat(Object.keys(vs).filter(function (w) { return !vc[w]; }));
        serviceWord = {};
        Object.keys(vs).forEach(function (w) { if (!vc[w]) serviceWord[w] = 1; });
        index = d;
        return d;
      })
      .catch(function (e) { loading = null; throw e; });
    return loading;
  }

  /* ---------- нормализация ---------- */
  function basicNorm(s) {
    return String(s).toLowerCase()
      .replace(/ё/g, 'е')
      .replace(/(\d)[.,](\d)/g, '$1_$2')          // 21.5 / 12,9 — одно число
      .replace(/[^a-zа-я0-9_]+/g, ' ')
      .replace(/([a-zа-я])(\d)/g, '$1 $2')        // iphone13 → iphone 13
      .replace(/(\d)([a-zа-я])/g, '$1 $2')        // 13pro → 13 pro
      .replace(/_/g, '.')
      .trim();
  }
  function canon(w) {
    if (synMap[w]) return synMap[w];
    for (var i = 0; i < synStems.length; i++) {
      var s = synStems[i][0];
      if (w.length > s.length && w.lastIndexOf(s, 0) === 0 && w.length - s.length <= 4) return synStems[i][1];
    }
    return w;
  }
  function tokens(s) {
    var out = [];
    basicNorm(s).split(' ').forEach(function (w) {
      if (!w || stop[w]) return;
      out.push(canon(w));
    });
    return out;
  }

  /* неправильная раскладка: qwerty ↔ йцукен */
  var EN = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`";
  var RU = 'йцукенгшщзхъфывапролджэячсмитьбюё';
  function swapLayout(s) {
    var toRu = /[a-z]/i.test(s) && !/[а-яё]/i.test(s);
    var from = toRu ? EN : RU, to = toRu ? RU : EN;
    return s.toLowerCase().split('').map(function (ch) {
      var i = from.indexOf(ch);
      return i === -1 ? ch : to.charAt(i);
    }).join('');
  }

  /* ---------- сравнение слов ---------- */
  function dist(a, b) {                          // Дамерау-Левенштейн (коротко)
    var m = a.length, n = b.length, d = [], i, j;
    for (i = 0; i <= m; i++) { d[i] = [i]; }
    for (j = 0; j <= n; j++) { d[0][j] = j; }
    for (i = 1; i <= m; i++) {
      for (j = 1; j <= n; j++) {
        var c = a.charAt(i - 1) === b.charAt(j - 1) ? 0 : 1;
        d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + c);
        if (i > 1 && j > 1 && a.charAt(i - 1) === b.charAt(j - 2) && a.charAt(i - 2) === b.charAt(j - 1)) {
          d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
        }
      }
    }
    return d[m][n];
  }
  function matchWord(q, t, isLast) {
    if (q === t) return 3;
    var isNum = /^\d/.test(q);
    if (t.lastIndexOf(q, 0) === 0) {
      if (isNum) return isLast ? 2 : 0;          // «13» не должно находить «130», пока слово не дописано
      if (q.length >= 2 || isLast) return 2 + q.length / t.length * 0.5;
      return 0;
    }
    if (isNum || /^\d/.test(t)) return 0;
    if (q.length >= 5 && t.length >= 5) {       // окончания: аккумулятору / аккумулятора
      var k = 0;
      while (k < q.length && k < t.length && q.charAt(k) === t.charAt(k)) k++;
      if (k >= Math.min(q.length, t.length) - 2) return 1.5;
    }
    if (q.length === 3 && t.length === 4 && dist(q, t) === 1) return 1;   // ipd → ipad
    if (q.length >= 4) {                         // опечатки
      var lim = q.length >= 8 ? 2 : 1;
      if (dist(q, t.slice(0, q.length)) <= lim || dist(q, t) <= lim) return 1;
    }
    return 0;
  }
  // слово запроса можно не найти в названии: у модели — слово услуги («экран iphone 15» → «Ремонт iPhone 15»),
  // у страницы «Выбор модели» — номер/уточнение модели («экран iphone 15» → «Замена экрана Айфон»)
  function optional(it, w) {
    if (it.t === 'c') return !!serviceWord[w];
    if (it.t === 'v') return /^\d/.test(w) || (!serviceWord[w] && !DEVICES[w]);
    return false;
  }
  function scoreItem(it, qt) {
    var total = 0, used = {}, hit = 0, skipped = 0, specific = 0;
    for (var i = 0; i < qt.length; i++) {
      var best = 0, bestJ = -1;
      for (var j = 0; j < it.tk.length; j++) {
        var s = matchWord(qt[i], it.tk[j], i === qt.length - 1);
        if (s > best || (s === best && s > 0 && used[bestJ] && !used[j])) { best = s; bestJ = j; }
      }
      if (!best) {
        if (!optional(it, qt[i])) return 0;
        total -= 1.2;
        skipped++;
        continue;
      }
      hit++;
      if (!DEVICES[qt[i]]) specific++;
      used[bestJ] = 1;
      total += best;
    }
    if (!hit) return 0;
    // «замена экрана айфон» — модели, совпавшие только по названию устройства, не показываем (шум);
    // «экран iphone 15» — «Ремонт iPhone 15» показываем (совпал номер модели)
    if (it.t === 'c' && skipped && !specific) return 0;
    var extra = it.tk.length - Object.keys(used).length;
    return total - extra * 0.12 + (TYPE_WEIGHT[it.t] || 0) - it.n.length * 0.002;
  }
  function known(w, isLast) {
    for (var i = 0; i < vocab.length; i++) { if (matchWord(w, vocab[i], isLast)) return true; }
    return false;
  }
  function run(q) {
    var all = tokens(q);
    // слова, которых нет нигде на сайте («разбил», «ин»), не мешают поиску
    var qt = all.filter(function (w, i) { return known(w, i === all.length - 1); });
    if (!qt.length) return [];
    var res = [];
    index.items.forEach(function (it) {
      var s = scoreItem(it, qt);
      if (s > 0) res.push({ it: it, s: s });
    });
    res.sort(function (a, b) { return b.s - a.s || a.it.pos - b.it.pos; });
    return res.map(function (r) { return r.it; });
  }
  function search(q) {
    var res = run(q);
    var fixed = null;
    if (!res.length && q.trim()) {
      var alt = swapLayout(q.trim());
      if (alt !== q.trim().toLowerCase()) {
        res = run(alt);
        if (res.length) fixed = alt;
      }
    }
    return { items: res, fixed: fixed };
  }

  /* ---------- отрисовка ---------- */
  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function price(p) {
    return 'от ' + String(p).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' ₽';
  }
  function highlight(name, q) {
    var qw = basicNorm(q).split(' ').filter(function (w) { return w && !stop[w]; });
    var qc = qw.map(canon);
    return name.split(/(\s+)/).map(function (part) {
      var w = basicNorm(part);
      if (!w || w.indexOf(' ') !== -1) return esc(part);
      var cw = canon(w);
      for (var i = 0; i < qw.length; i++) {
        if (qw[i].length >= 2 && w.lastIndexOf(qw[i], 0) === 0) {       // начало слова совпало буквально
          var n = Math.min(part.length, qw[i].length);
          return '<mark>' + esc(part.slice(0, n)) + '</mark>' + esc(part.slice(n));
        }
        if (qc[i] === cw && qw[i].length >= 2) return '<mark>' + esc(part) + '</mark>';   // через синоним
      }
      return esc(part);
    }).join('');
  }
  var ICONS = {
    c: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="2.5" width="12" height="19" rx="3"/><path d="M10.5 18.5h3"/></svg>',
    v: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.2L3.5 17.3l3.2 3.2 5.8-5.8a4 4 0 0 0 5.2-5.4l-2.5 2.5-2.4-.6-.6-2.4z"/></svg>',
    s: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.2L3.5 17.3l3.2 3.2 5.8-5.8a4 4 0 0 0 5.2-5.4l-2.5 2.5-2.4-.6-.6-2.4z"/></svg>',
    p: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 2.5h7l5 5v14H7z"/><path d="M14 2.5v5h5"/></svg>',
    b: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5.5h16M4 10h16M4 14.5h10M4 19h7"/></svg>'
  };
  var CHEVRON = '<svg class="irepair-search__chev" viewBox="0 0 8 14" aria-hidden="true"><path d="M1 1l6 6-6 6"/></svg>';

  function row(it, q) {
    var t = it.t === 'v' ? 'v' : it.t;
    return '<a class="irepair-search__row" href="' + esc(it.u) + '">'
      + '<span class="irepair-search__icon irepair-search__icon--' + t + '">' + ICONS[t] + '</span>'
      + '<span class="irepair-search__text"><span class="irepair-search__name">' + highlight(it.n, q) + '</span>'
      + (it.c && it.t !== 's' ? '<span class="irepair-search__ctx">' + esc(it.c) + '</span>' : '') + '</span>'
      + (it.p ? '<span class="irepair-search__price">' + price(it.p) + '</span>' : '')
      + CHEVRON + '</a>';
  }
  function grouped(items, full) {
    var html = '';
    // группы — по порядку лучшего результата: «замена экрана айфон» → сначала Услуги, «айфон 13» → сначала Модели
    var first = function (g) {
      for (var i = 0; i < items.length; i++) { if (g.key.indexOf(items[i].t) !== -1) return i; }
      return 1e9;
    };
    GROUPS.slice().sort(function (a, b) { return first(a) - first(b); }).forEach(function (g) {
      var list = items.filter(function (it) { return g.key.indexOf(it.t) !== -1; });
      if (!list.length) return;
      var shown = full ? list : list.slice(0, g.limit);
      html += '<div class="irepair-search__group"><div class="irepair-search__group-title">' + g.title
        + (full ? ' <span>' + list.length + '</span>' : '') + '</div><div class="irepair-search__list">'
        + shown.map(function (it) { return row(it, qCurrent); }).join('') + '</div></div>';
    });
    return html;
  }
  var qCurrent = '';
  function emptyState(q) {
    var pop = (index && index.popular) || [];
    return '<div class="irepair-search__empty">'
      + '<div class="irepair-search__empty-icon"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/></svg></div>'
      + '<div class="irepair-search__empty-title">Ничего не нашли по запросу «' + esc(q) + '»</div>'
      + '<div class="irepair-search__empty-text">Опишите, что случилось с устройством, — мастер перезвонит, подскажет стоимость и сроки. Диагностика бесплатно.</div>'
      + '<button type="button" class="irepair-search__lead" data-call-popup-trigger data-service="' + esc('Поиск: ' + q) + '">Оставить заявку</button>'
      + '</div>'
      + (pop.length ? '<div class="irepair-search__group"><div class="irepair-search__group-title">Популярные услуги</div><div class="irepair-search__list">'
        + pop.map(function (p) { return row({ t: 'v', n: p[0], u: p[1], c: 'Все модели' }, ''); }).join('')
        + '</div></div>' : '');
  }

  /* ---------- окно поиска (шапка) ---------- */
  var overlay, input, results, activeIdx = -1, timer;
  function build() {
    overlay = document.createElement('div');
    overlay.className = 'irepair-search';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Поиск по сайту');
    overlay.innerHTML = '<div class="irepair-search__backdrop"></div>'
      + '<div class="irepair-search__panel">'
      + '<form class="irepair-search__bar" action="' + RESULTS_URL + '" method="get" role="search">'
      + '<label class="irepair-search__field"><svg class="irepair-search__glass" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/></svg>'
      + '<input class="irepair-search__input" type="search" name="q" placeholder="Поиск: модель, поломка или услуга" autocomplete="off" autocorrect="off" spellcheck="false" enterkeyhint="search">'
      + '<button type="button" class="irepair-search__clear" aria-label="Очистить"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M9 9l6 6M15 9l-6 6"/></svg></button></label>'
      + '<button type="button" class="irepair-search__cancel">Отмена</button>'
      + '</form>'
      + '<div class="irepair-search__results"></div>'
      + '<div class="irepair-search__hints"><span><kbd>↑</kbd><kbd>↓</kbd> выбрать</span><span><kbd>↵</kbd> все результаты</span><span><kbd>esc</kbd> закрыть</span></div>'
      + '</div>';
    document.body.appendChild(overlay);
    input = overlay.querySelector('.irepair-search__input');
    results = overlay.querySelector('.irepair-search__results');

    overlay.querySelector('.irepair-search__backdrop').addEventListener('click', close);
    overlay.querySelector('.irepair-search__cancel').addEventListener('click', close);
    overlay.querySelector('.irepair-search__clear').addEventListener('click', function () {
      input.value = ''; input.focus(); render();
    });
    input.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(render, 60); });
    input.addEventListener('keydown', onKey);
    overlay.querySelector('form').addEventListener('submit', function (e) {
      e.preventDefault();
      var sel = rows()[activeIdx];
      if (sel) { location.href = sel.getAttribute('href'); return; }
      if (input.value.trim()) location.href = RESULTS_URL + '?q=' + encodeURIComponent(input.value.trim());
    });
    // заявка из поиска: закрываем поиск, окно заявки откроет общий обработчик шапки
    results.addEventListener('click', function (e) {
      if (e.target.closest('[data-call-popup-trigger]')) close();
    });
  }
  function rows() { return results ? results.querySelectorAll('.irepair-search__row') : []; }
  function setActive(i) {
    var r = rows();
    if (activeIdx >= 0 && r[activeIdx]) r[activeIdx].classList.remove('is-active');
    activeIdx = i;
    if (i >= 0 && r[i]) { r[i].classList.add('is-active'); r[i].scrollIntoView({ block: 'nearest' }); }
  }
  function onKey(e) {
    var r = rows();
    if (e.key === 'ArrowDown') { e.preventDefault(); setActive(Math.min(activeIdx + 1, r.length - 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(Math.max(activeIdx - 1, -1)); }
    else if (e.key === 'Escape') { e.preventDefault(); close(); }
  }
  function render() {
    var q = input.value;
    qCurrent = q;
    activeIdx = -1;
    overlay.classList.toggle('has-query', !!q.trim());
    if (!q.trim()) { results.innerHTML = ''; return; }
    if (!index) {
      results.innerHTML = '<div class="irepair-search__loading">Загружаем…</div>';
      load().then(render, function () {
        results.innerHTML = '<div class="irepair-search__loading">Поиск временно недоступен</div>';
      });
      return;
    }
    var r = search(q);
    results.innerHTML = (r.fixed ? '<div class="irepair-search__fixed">Показаны результаты для «' + esc(r.fixed) + '»</div>' : '')
      + (r.items.length ? grouped(r.items, false)
        + '<a class="irepair-search__all" href="' + RESULTS_URL + '?q=' + encodeURIComponent(q.trim()) + '">Все результаты (' + r.items.length + ')</a>'
        : emptyState(q.trim()));
  }
  function open() {
    if (!overlay) build();
    load().catch(function () {});
    overlay.classList.add('is-open');
    document.documentElement.classList.add('irepair-search-lock');
    setTimeout(function () { input.focus(); input.select(); }, 30);
    if (input.value) render();
  }
  function close() {
    if (!overlay) return;
    overlay.classList.remove('is-open');
    document.documentElement.classList.remove('irepair-search-lock');
    input.blur();
  }

  document.addEventListener('click', function (e) {
    var t = e.target.closest('.header__wrapper-right-search, .headerMob__wrapper-mobMenu-search, .headerMob__wrapper-search, [data-irepair-search-open]');
    if (!t) return;
    e.preventDefault();
    e.stopPropagation();
    open();
  }, true);
  document.addEventListener('keydown', function (e) {        // ⌘K / Ctrl+K — как Spotlight
    if ((e.metaKey || e.ctrlKey) && (e.key === 'k' || e.key === 'л')) { e.preventDefault(); open(); }
  });

  /* ---------- страница результатов /search/?q= ---------- */
  function initPage() {
    var box = document.querySelector('[data-irepair-search-page]');
    if (!box) return;
    var q = new URLSearchParams(location.search).get('q') || '';
    box.classList.add('irepair-search-page');
    box.innerHTML = '<form class="irepair-search__bar irepair-search__bar--page" action="' + RESULTS_URL + '" method="get" role="search">'
      + '<label class="irepair-search__field"><svg class="irepair-search__glass" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/></svg>'
      + '<input class="irepair-search__input" type="search" name="q" placeholder="Поиск: модель, поломка или услуга" autocomplete="off" autocorrect="off" spellcheck="false" enterkeyhint="search"></label>'
      + '<button type="submit" class="irepair-search__submit">Найти</button></form>'
      + '<div class="irepair-search__results irepair-search__results--page"></div>';
    var inp = box.querySelector('input');
    var out = box.querySelector('.irepair-search__results');
    inp.value = q;
    function draw() {
      var v = inp.value.trim();
      qCurrent = v;
      if (!v) { out.innerHTML = '<div class="irepair-search__loading">Введите модель устройства, поломку или услугу</div>'; return; }
      var r = search(v);
      out.innerHTML = '<div class="irepair-search__summary">'
        + (r.items.length ? 'Найдено: ' + r.items.length : '') + '</div>'
        + (r.fixed ? '<div class="irepair-search__fixed">Показаны результаты для «' + esc(r.fixed) + '»</div>' : '')
        + (r.items.length ? grouped(r.items, true) : emptyState(v));
    }
    out.innerHTML = '<div class="irepair-search__loading">Загружаем…</div>';
    load().then(function () {
      draw();
      inp.addEventListener('input', function () {
        clearTimeout(timer);
        timer = setTimeout(function () {
          draw();
          history.replaceState(null, '', RESULTS_URL + (inp.value.trim() ? '?q=' + encodeURIComponent(inp.value.trim()) : ''));
        }, 120);
      });
    }, function () { out.innerHTML = '<div class="irepair-search__loading">Поиск временно недоступен</div>'; });
    box.querySelector('form').addEventListener('submit', function (e) { e.preventDefault(); draw(); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initPage);
  else initPage();

  window.IrepairSearch = { open: open, close: close, search: function (q) { return load().then(function () { return search(q); }); } };
})();
