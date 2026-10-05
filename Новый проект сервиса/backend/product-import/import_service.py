"""Импорт одной услуги (со всеми вариантами) из RemOnline в CS-Cart — по процедуре из памяти Claude
(project_cscart_product_import): главный товар = самый дешёвый вариант, ему название и URL старого сайта
(`_` → `-`) + 301-редирект; всем вариантам — картинки, title, meta description, описание (prep_desc.py),
гарантия (столбец L таблицы → характеристика 4; старый адрес — по столбцу B через старую базу), время ремонта (upc старого товара → характеристика 5).
Картинки после создания обрезаются по контуру объекта (crop_images.py).
Товары создаются СРАЗУ в нужной категории и ВКЛЮЧЁННЫМИ.

  python3 import_service.py --cat 48 --feature 3 60709691 60709695

Доступы — только через переменные окружения (в репозиторий не кладём):
  CSCART_AUTH="admin@irepair.ru:<api key>"   RO_KEY="<RemOnline key>"   SSHPASS="<пароль старого сервера>"
Флаг --dry-run: только собрать и показать данные, ничего не создавать.

MacBook (один товар на категорию, два выбора — модель и тип запчасти, как на старом сайте):
  python3 import_service.py --cat 90 --feature 7 --model-feature 6 64111819 38457879 …
  Модель = столбец N (MODEL №) → «процессор | A-номера» (как в прайсе, процессор по CHIP_MAP из
  main-page/scripts/build-repair-prices.py); нового значения в характеристике --model-feature нет — скрипт его добавит.
  Гарантия: столбец L, а если пусто — из строки «Модуль» этой услуги (столбец N вида «AASP 12 | ОЕМ 3»), а если и там нет — 1 месяц.
  Старый адрес: столбец D, а если пусто — путь категории товара в старой базе.

Apple Watch: --feature 10 (тип запчасти) --model-feature 11 (размер корпуса: столбец N «44 mm» → «44 мм», по возрастанию).

Вид опций в карточке: --feature (тип запчасти) — плитки, --model-feature (модель / конфигурация / размер) — выпадающий
список; скрипт сам выставляет это характеристикам (feature_style dropdown_labels / dropdown).

Услуги нет в RemOnline/таблице (iMac): --old-product <старый product_id> вместо RO id — варианты и цены из опций
старого товара, код товара OLD-<товар>-<опция>; когда владелец заведёт услугу в RO — заменить код на RO-<id>.
"""
import argparse
import base64
import importlib.util
import html
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

import openpyxl

from crop_images import _run, crop_products
import title_check

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.expanduser('~/Документы/Сервис/Новая таблица888.xlsx')
PRICE_ID = 543835
OLD_SSH = 'www-root@31.31.207.64'
NEW_SSH = ['ssh', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151']
API = 'https://dev.irepair.ru/api.php?_d='

ap = argparse.ArgumentParser()
ap.add_argument('--cat', type=int, required=True, help='id категории CS-Cart')
# Правило владельца: тип запчасти не указан (RemOnline без «| тип», в таблице «-») → опцию НЕ присваиваем: запуск без --feature,
# одиночный товар без группы вариаций. Указан (даже один) → --feature, опция выводится всегда.
ap.add_argument('--feature', type=int, help='id характеристики вариантов (напр. 3 = тип запчасти аккумулятора); '
                                         'без неё — только --old-product без опций (один товар без выбора)')
ap.add_argument('--model-feature', type=int, help='id характеристики модели (MacBook: 6) — второй выбор в группе вариаций')
ap.add_argument('--slug', help='свой адрес (seo_name) главного товара вместо старого slug — если старый кривой; со старого адреса будет 301')
ap.add_argument('--name', help='своё название услуги вместо старого (если старое общее, напр. «iPad Pro 13» на две категории M4/M5)')
ap.add_argument('--old-product', type=int, help='услуги нет в RemOnline/таблице: варианты и цены — из опций старого товара '
                                               '(«Выберите модель» × «Тип запчасти»), код OLD-<товар>-<опция>; потом привязать к RO')
ap.add_argument('--position', type=int, default=0, help='позиция услуги в категории (порядок услуг владельца: ранг×10, '
                                                       'напр. аккумулятор iPhone 10, дисплей 20); категории сортируются по позиции')
ap.add_argument('--old-id', type=int, help='свой старый товар вместо столбца B таблицы — если в таблице ссылка перепутана (напр. 6S ↔ 6 Plus)')
ap.add_argument('--skip-title-check', nargs='*', default=[], help='RO id, у которых кривое название в RemOnline — сверено вручную')
ap.add_argument('--time', help='своё время ремонта вместо старого (если на старом сайте опечатка/мусор)')
ap.add_argument('--old-types-json', help='с --old-product: файл {название старой опции «Тип запчасти»: [тип, значение второй характеристики, позиция, цена]} — '
                'старый выбор модели отбрасываем, цены и названия свои (SSD MacBook: тип HQ/AASP × объём, решение владельца 2026-10-04)')
ap.add_argument('--old-models-json', help='с --old-product: файл {название старой опции «Выберите модель»: [значение характеристики --feature, цена]} — '
                'старый выбор модели становится выбором варианта плитками (термопаста MacBook: процессор M1 / остальные)')
ap.add_argument('--multi-model', action='store_true', help='в одной категории несколько моделей таблицы (iPad Pro 12.9 S1–S5, Air 6 11/13): не считать это ошибкой столбца B')
ap.add_argument('--old-ignore-options', action='store_true', help='с --old-product: опции старого товара не переносим (общая услуга на все модели с ценой --price)')
ap.add_argument('--code-suffix', help='с --old-product: хвост к кодам OLD-… (товар-копия для другой модели, чтобы коды не совпали с исходным, напр. -pro14)')
ap.add_argument('--price', type=int, help='своя цена для всех вариантов (владелец назвал цену: на старом сайте 0 или цены выравниваем)')
ap.add_argument('--price-from', action='store_true', help='цена ориентировочная — показывать «от …» (характеристика 19)')
ap.add_argument('--no-redirect', action='store_true', help='не ставить 301 со старого адреса (товар-копия другой модели, напр. 17e по данным 17)')
ap.add_argument('--code', help='свой код товара (напр. OLD-9074-17e — копия, чтобы не совпасть с кодом исходного товара)')
ap.add_argument('--rename-model', nargs=2, metavar=('FROM', 'TO'), help='копия другой модели: заменить «iPhone 17» → «iPhone 17e» в мета и описании '
                                                                       '(не трогая «iPhone 17 Pro», «17 Air» и т. п.)')
ap.add_argument('--type-with-service', action='store_true', help='значение опции = тип + услуга таблицы: «OEM (Замена матрицы)» (MacBook дисплей)')
ap.add_argument('--model-n-alias', nargs=2, action='append', default=[], metavar=('FROM', 'TO'),
                help='заменить столбец N «FROM» на «TO» (одна конфигурация вместо двух, напр. Pro 14 M5 «A3434» → «A3434 / A3426 / A3427»)')
ap.add_argument('--dry-run', action='store_true')
ap.add_argument('ro_ids', nargs='*')
ap.add_argument('--table-row', type=int, nargs='*', default=[], help='услуги нет в RemOnline (владелец 2026-10-01: «Ремонт материнской платы»): '
                                                                  'берём строки таблицы по номерам — цена AY («от …» → признак 19 «Цена «от»»), '
                                                                  'старый товар B, код товара OLD-<старый товар>; обновлять потом из таблицы/вручную')
args = ap.parse_args()
assert sum(map(bool, (args.ro_ids, args.old_product, args.table_row))) == 1, 'нужны либо RO id, либо --old-product, либо --table-row'

AUTH = 'Basic ' + base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()


def cs(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={'Authorization': AUTH, 'Content-Type': 'application/json'})
    return json.loads(urllib.request.urlopen(req, timeout=180).read() or b'{}')


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


def head(url):
    """HTTP-код и Location без перехода по редиректам."""
    try:
        r = urllib.request.build_opener(_NoRedirect).open(urllib.request.Request(url, method='HEAD'), timeout=60)
        return r.status, None
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get('Location')


def ro(sid):
    req = urllib.request.Request(f'https://api.roapp.io/v2/catalog/services/{sid}',
                                 headers={'Authorization': 'Bearer ' + os.environ['RO_KEY']})
    d = json.loads(urllib.request.urlopen(req, timeout=60).read())
    d = d.get('data', d)
    price = next(float(p['price']) for p in d['prices'] if p['id'] == PRICE_ID)
    return d['title'].strip(), int(round(price))


# процессор по A-номеру — общий справочник с прайсом/калькулятором
_spec = importlib.util.spec_from_file_location('build_prices', os.path.join(HERE, '..', '..', 'main-page', 'scripts', 'build-repair-prices.py'))
_bp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_bp)
CHIP_RANK = [('Intel', 0), ('M1', 1), ('M2', 2), ('M3', 3), ('M4', 4), ('M5', 5)]


def model_label(modelno, model=''):
    """Столбец N → (подпись, позиция для сортировки).
    MacBook (A-номера есть в CHIP_MAP): «процессор | A-номера», Intel → M1 → … → M5, внутри — по A-номеру.
    Остальные (iPad): «A-номера» как в столбце N, по первому A-номеру; если в столбце H есть поколение
    («Pro 11 S5 M4») — «5 поколение (M4) | A-номера», по поколению."""
    mm = re.fullmatch(r'\s*(\d+)\s*(mm|мм)\s*', modelno, re.I)  # Apple Watch: размер корпуса «44 mm» → «44 мм»
    if mm:
        return f'{mm.group(1)} мм', int(mm.group(1))
    parts = [p.strip() for p in modelno.split('/') if p.strip()]
    assert parts and all(re.fullmatch(r'A\d{4}', p) for p in parts), f'в столбце N не A-номера: «{modelno}»'
    if not all(p in _bp.CHIP_MAP for p in parts):
        assert not any(p in _bp.CHIP_MAP for p in parts), f'часть A-номеров «{modelno}» есть в CHIP_MAP, часть нет — спросить владельца'
        gen = re.search(r'\bS(\d+)\b', model or '')
        if gen:
            chip = re.search(r'\b[MМ](\d+)\b', model)  # бывает кириллическая «М»
            prefix = f"{gen.group(1)} поколение" + (f" (M{chip.group(1)})" if chip else '')
            return f"{prefix} | {' / '.join(parts)}", int(gen.group(1)) * 10000 + int(parts[0][1:])
        size = re.search(r'-(11|13)\b', model or '')  # iPad Air 6/7: «Air 6-11 M2» → 11"
        if size:
            chip = re.search(r'\b[MМ](\d+)\b', model)
            prefix = f'{size.group(1)}"' + (f" (M{chip.group(1)})" if chip else '')
            return f"{prefix} | {' / '.join(parts)}", int(size.group(1)) * 10000 + int(parts[0][1:])
        return ' / '.join(parts), int(parts[0][1:])
    chips = []
    for p in parts:
        if _bp.CHIP_MAP[p] not in chips:
            chips.append(_bp.CHIP_MAP[p])
    rank = next(v for k, v in CHIP_RANK if chips[0].startswith(k))
    return f"{' / '.join(chips)} | {' / '.join(parts)}", rank * 10000 + int(parts[0][1:])


def warranty_text(n, days=False):
    # гарантия хранится текстом (характеристика 4): «1 месяц», «3 месяца», «12 месяцев», «14 дней»
    n = int(n)
    forms = ('день', 'дня', 'дней') if days else ('месяц', 'месяца', 'месяцев')
    w = forms[2] if 11 <= n % 100 <= 14 else forms[0] if n % 10 == 1 else forms[1] if 2 <= n % 10 <= 4 else forms[2]
    return f'{n} {w}'


def sql_new(q):
    # _run: SSH до dev иногда рвётся («Connection closed», 255) — до 6 попыток
    return _run(NEW_SSH + ['mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e ' + json.dumps(q)],
                capture_output=True, text=True).stdout


def old_sql(q):
    """Запрос к базе старого сайта (только чтение), вывод --batch построчно, повторы при обрыве SSH."""
    remote = ('cd ~/www/irepair.ru && P=$(php -r "include \\"config.php\\"; echo DB_PASSWORD;") && '
              f"mysql -uocstore -p\"$P\" ocstore --batch -e '{q}' 2>/dev/null")
    for attempt in range(4):
        try:
            return subprocess.run(['sshpass', '-e', 'ssh', '-o', 'ConnectTimeout=20', OLD_SSH, remote],
                                  capture_output=True, check=True).stdout.decode('utf-8').split('\n')
        except subprocess.CalledProcessError:
            if attempt == 3:
                raise
            time.sleep(10)


items = []
if args.old_product:
    # 1'. Услуги ещё нет в RemOnline и таблице (напр. iMac): варианты = опции старого товара.
    # Цена опции на старом сайте — полная цена услуги (price_prefix пустой). Главная цена — у выбора модели,
    # если он есть; иначе — у типа запчасти. Гарантии в старой базе нет → 1 месяц (правило владельца).
    rows_ = old_sql('select od.name oname, pov.product_option_value_id vid, ovd.name vname, pov.price, pov.price_prefix '
                    'from oc_product_option_value pov '
                    'join oc_product_option po on po.product_option_id = pov.product_option_id '
                    'join oc_option_description od on od.option_id = po.option_id and od.language_id = 1 '
                    'join oc_option_value_description ovd on ovd.option_value_id = pov.option_value_id and ovd.language_id = 1 '
                    f'where pov.product_id = {args.old_product} order by pov.product_option_value_id')
    opts = {}
    for line in rows_[1:]:
        if line.strip():
            oname, vid, vname, price, prefix = line.split('\t')
            assert prefix.strip() in ('', '='), f'опция «{vname}»: цена с префиксом «{prefix}» — разобрать вручную'
            opts.setdefault(oname.strip(), []).append((vid, html.unescape(vname).strip(), int(float(price))))
    if args.old_ignore_options:
        opts = {}
    models = opts.pop('Выберите модель', [])
    types = opts.pop('Тип запчасти', [])
    if args.old_models_json:
        _mm = json.load(open(args.old_models_json, encoding='utf-8'))
        types, models = [(vid, _mm[v][0], _mm[v][1]) for vid, v, _ in models], []
    if args.old_types_json:
        _tm = json.load(open(args.old_types_json, encoding='utf-8'))
        models = []
        types = [(vid, '|'.join(map(str, _tm[v][:3])), _tm[v][3]) for vid, v, _ in types]
    assert not opts, f'неизвестные опции старого товара: {list(opts)}'
    if not models and not types:
        # опций нет (напр. «Чистка системы охлаждения iMac 27») — один товар без выбора, цена товара
        assert not args.feature and not args.model_feature, 'у старого товара нет опций — запускать без --feature/--model-feature'
        price = int(float(old_sql(f'select price from oc_product where product_id = {args.old_product}')[1]))
        types = [(None, '', price)]
    assert types, 'у старого товара нет опции «Тип запчасти»'
    assert args.feature or types == [(None, '', types[0][2])], 'у старого товара есть опции — нужен --feature'
    assert not (len(models) > 1 and len(types) > 1), 'и моделей, и типов больше одного — цены не разложить, спросить владельца'
    assert args.old_types_json or bool(models) == bool(args.model_feature), 'опция «Выберите модель» ↔ --model-feature должны совпадать'
    for mvid, mname, mprice in (models or [(None, '', None)]):
        for tvid, tname, tprice in types:
            it = {'ro': f"OLD-{args.old_product}" + (f"-{mvid or tvid}" if (mvid or tvid) else ''), 'value': tname, 'price': mprice or tprice,
                  'ro_price': 0, 'old_id': args.old_product, 'warranty': warranty_text(1)}
            if models:
                mlabel = re.sub(r'^Модель\s+', '', mname)
                ext = re.fullmatch(r'(A\d{4})\s+(\S.*)', mlabel)  # iMac 21.5: «A1418 2K» / «A1418 4K» — подпись как есть; позиция = A-номер (при равной CS-Cart сортирует по названию)
                it['model'], it['model_pos'] = (mlabel, int(ext.group(1)[1:])) if ext else model_label(mlabel)
            items.append(it)
    if args.old_types_json:
        for it in items:
            it['value'], it['model'], _pos = it['value'].split('|')
            it['model_pos'] = int(_pos)
    items.sort(key=lambda x: (x['price'], x.get('model_pos', 0), x['value']))
    print(f'!!! старый товар {args.old_product}: нет в RemOnline/таблице — цены со старого сайта, код OLD-…, гарантия 1 мес.')

# 1. RemOnline
for sid in args.ro_ids:
    title, price = ro(sid)
    _v = title.split('|')[-1].strip() if '|' in title else ''
    _v = {'ОЕМ': 'OEM', 'ОЕM': 'OEM', 'OЕМ': 'OEM'}.get(_v, _v)  # в RemOnline бывает кириллица
    if re.match(r'\(?\s*A\d{4}', _v):
        _v = ''  # после последней «|» — A-номера, а не тип запчасти («… iPad 10 - 2022 | (A2696 / …)») → тип берём из таблицы
    items.append({'ro': sid, 'title': title, 'price': price, 'value': _v})
    time.sleep(0.4)
items.sort(key=lambda x: x['price'])

# 2. Таблица: RO id → старый product_id, гарантия (L), старый URL (D)
ws = openpyxl.load_workbook(TABLE, read_only=True, data_only=True)['МСервис']
all_rows = list(ws.iter_rows(values_only=True))
rows = {str(r[4]).replace('.0', ''): r for r in all_rows if r[4] is not None}
# гарантия из строки «Модуль» (столбец N «AASP 12 | ОЕМ 3») — для строк, где столбец L пуст (MacBook)
module_warranty, cur_mod = {}, {}
for r in all_rows:
    if r[0] == 'Модуль':
        # «AASP 12 | ОЕМ 3 | HQ 14д» → месяцы, «д» — дни
        cur_mod = {k.upper().replace('ОЕМ', 'OEM'): warranty_text(v, bool(d)) for k, v, d in re.findall(r'(AASP|OEM|ОЕМ|HQ)\s+(\d+)\s*(д)?', str(r[13] or ''))}
    elif r[4] is not None:
        module_warranty[str(r[4]).replace('.0', '')] = cur_mod

# 1''. Строки таблицы без кода RemOnline (--table-row)
for _n_row in args.table_row:
    r = all_rows[_n_row - 1]
    _m = re.search(r'product_id=(\d+)', str(r[1] or ''))
    _oid = int(_m.group(1)) if _m else (args.old_id or None)  # нет ссылки и нет --old-id — товара на старом сайте нет: без описания и фото
    if _oid is None:
        assert args.code and args.name and args.slug, f'строка {_n_row}: нет старого товара — нужны --code, --name, --slug'
    _price, _approx = _bp.parse_price(r[50])
    assert _price, f'строка {_n_row}: нет цены в столбце AY ({r[50]!r})'
    _part = str(r[8] or '').strip()
    items.append({'ro': f'OLD-{_oid}' if _oid else (args.code or ''), 'title': args.name or '', 'price': int(_price), 'ro_price': 0, 'from_price': bool(_approx), 'row': r,
                  'value': '' if _part in ('', '-') else _part, 'old_id': _oid,
                  'warranty': warranty_text(r[11]) if r[11] not in (None, '') else warranty_text(1)})
    if args.model_feature:
        # несколько строк одной услуги без кодов RemOnline (Watch SE 3: размеры корпуса) — модель из столбца N, свой код на строку
        items[-1]['model'], items[-1]['model_pos'] = model_label(str(r[13] or '').strip(), str(r[7] or ''))
        if len(args.table_row) > 1:
            items[-1]['ro'] = f'TAB-{_n_row}'
    print(f'строка таблицы {_n_row}: {r[9]} {r[6]} {r[7]} | цена {"от " if _approx else ""}{int(_price)} | старый товар {_oid or "нет"}')
title_errors = []
_models = {re.sub(r'\s+', ' ', str(rows[it['ro']][7]).replace('.0', '')).strip().lower() for it in items if not it['ro'].startswith('OLD-') and it['ro'] in rows}
assert args.multi_model or len(_models) <= 1, f'в одном запуске строки разных моделей: {_models} — проверить столбец B таблицы (один старый товар на две модели?)'
for it in items:
    if it['ro'].startswith('OLD-') or it.get('row') is not None:
        continue  # --old-product / --table-row: данные уже взяты
    r = rows[it['ro']]
    # Проверка (владелец 2026-09-30): название услуги в RemOnline должно соответствовать таблице (title_check.py) —
    # иначе код перепутан; все расхождения собираем и останавливаемся до создания
    _err = None if it['ro'] in args.skip_title_check else title_check.check(it['title'], r)
    if _err:
        title_errors.append(f"RO {it['ro']} «{it['title']}»: {_err}")
    elif title_check.extra_type(it['title'], r):
        print(f"!!! RO {it['ro']}: в RemOnline есть тип «{title_check.extra_type(it['title'], r)}», в таблице тип не указан («-») — опцию не присваиваем")
    # цена — из нашей таблицы (столбец AY «Текущая цена», как у прайса/калькулятора); RemOnline — только для сверки
    it['ro_price'] = it['price']
    tab_price, approx = _bp.parse_price(r[50])
    it['price'] = int(tab_price or 0)
    assert not approx, f"RO {it['ro']}: в таблице цена «от …» ({r[50]}) — уточнить у владельца"
    if it['ro_price'] != it['price']:
        print(f"!!! RO {it['ro']}: цена в таблице {it['price']}, в RemOnline {it['ro_price']} — берём из таблицы")
    _m = re.search(r'product_id=(\d+)', str(r[1] or ''))
    # нет ссылки на старый товар (услуги не было на старом сайте) — владелец 2026-10-01: создаём без описания и фото
    it['old_id'] = int(_m.group(1)) if _m else None
    mod = module_warranty.get(it['ro'], {})
    # тип запчасти не указан (в таблице «-»), а в «Модуле» у всех типов один срок («AASP 12 | ОЕМ 12») — берём его
    mod_same = next(iter(mod.values())) if mod and len(set(mod.values())) == 1 else ''
    it['warranty'] = warranty_text(r[11]) if r[11] not in (None, '') else mod.get(it['value'].upper(), '' if it['value'] else mod_same)
    # владелец 2026-09-28: гарантия нигде не указана → всегда 1 месяц
    it['warranty'] = it['warranty'] or warranty_text(1)
    if not it['value'] and str(r[8] or '').strip() not in ('', '-'):
        it['value'] = str(r[8]).strip()  # в названии RemOnline нет «| тип» — берём тип из таблицы
    if '💎' in str(r[9]):
        # Watch «Замена стекла 💎» (владелец 2026-10-05): сапфировое стекло — та же услуга, отдельная опция с припиской
        it['value'] = f"{str(r[8]).strip()} (Сапфир)"
    if args.type_with_service:
        # MacBook дисплей: «OEM (Замена матрицы)» / «AASP (Замена дисплея в сборе)» — тип + услуга таблицы
        it['value'] = f"{it['value']} ({str(r[9]).split('|')[0].strip()})"
    if args.model_feature:
        _nval = str(r[13] or '').strip()
        _nval = dict((a.strip(), b.strip()) for a, b in args.model_n_alias).get(_nval, _nval)
        it['model'], it['model_pos'] = model_label(_nval, str(r[7] or ''))
if args.code_suffix:
    for it in items:
        it['ro'] += args.code_suffix
if args.price:
    for it in items:
        it['price'] = args.price
if args.price_from:
    for it in items:
        it['from_price'] = True
assert not title_errors, 'название услуги в RemOnline не совпадает с таблицей:\n  ' + '\n  '.join(title_errors)
items.sort(key=lambda x: x['price'])
bad = [it['ro'] for it in items if not it['price']]
if bad:
    print('!!! нет цены в таблице (столбец AY) — такие услуги не заливаем:', ', '.join(bad))
    items = [it for it in items if it['price']]
    assert items, 'не осталось услуг с ценой'
if args.model_feature:
    # главный товар — самый дешёвый; при равной цене — более старая модель
    items.sort(key=lambda x: (x['price'], x['model_pos'], x['value']))
    combos = [(it['model'], it['value']) for it in items]
    assert len(combos) == len(set(combos)), f'повторяются пары модель/тип: {combos}'
if args.old_id:
    print(f'старый товар задан вручную: {args.old_id} (в таблице: {sorted({it["old_id"] for it in items})})')
    for it in items:
        it['old_id'] = args.old_id
        if it['ro'].startswith('OLD-') and it.get('row') is not None:
            it['ro'] = f'OLD-{args.old_id}'  # строка таблицы на серию: код — по своему старому товару модели
_known = {it['old_id'] for it in items if it['old_id']}
if len(_known) == 1:
    for it in items:
        if not it['old_id']:
            it['old_id'] = next(iter(_known))  # строка без ссылки на старый товар — в товар своей группы
old_ids = {it['old_id'] for it in items}
assert len(old_ids) == 1, f'варианты ссылаются на разные старые товары: {old_ids}'
old_id = old_ids.pop()

if old_id is not None:
    # 3. Старый сайт (только чтение)
    q = (f'select name, meta_title, meta_description, description from oc_product_description where product_id={old_id} and language_id=1;'
         f'select keyword from oc_seo_url where query="product_id={old_id}";'
         f'select image, upc from oc_product where product_id={old_id};'
         f'select image from oc_product_image where product_id={old_id} order by sort_order;'
         # путь главной категории товара (для старого адреса, если столбец D пуст)
         f'select cp.level, su.keyword as cat_keyword from oc_product_to_category p2c '
         f'join oc_category_path cp on cp.category_id = p2c.category_id '
         f'join oc_seo_url su on su.query = concat("category_id=", cp.path_id) and su.language_id = 1 '
         f'where p2c.product_id = {old_id} and p2c.main_category = 1 order by cp.level;')
    remote = ('cd ~/www/irepair.ru && P=$(php -r "include \\"config.php\\"; echo DB_PASSWORD;") && '
              f"mysql -uocstore -p\"$P\" ocstore --batch -e '{q}' 2>/dev/null")
    # байты, а не text=True: в старых данных бывает \r, текстовый режим превратил бы его в перенос строки
    # SSH до старого сервера иногда отвечает 255, бывает по минуте подряд — повторяем (до 8 попыток, пауза 20 с)
    for attempt in range(8):
        try:
            out = subprocess.run(['sshpass', '-e', 'ssh', '-o', 'ConnectTimeout=20', OLD_SSH, remote],
                                 capture_output=True, check=True).stdout.decode('utf-8').split('\n')
            break
        except subprocess.CalledProcessError:
            if attempt == 7:
                raise
            time.sleep(20)


    def unesc(s):
        return s.replace('\\\\', '\x00').replace('\\n', '\n').replace('\\t', '\t').replace('\\r', '\r').replace('\x00', '\\')


    # вывод --batch: заголовок + строки для каждого запроса
    blocks, cur, cat_path_rows = [], None, []
    for line in out:
        if line in ('name\tmeta_title\tmeta_description\tdescription', 'keyword', 'image\tupc', 'image', 'level\tcat_keyword'):
            cur = []
            blocks.append(cur)
            if line == 'level\tcat_keyword':
                cat_path_rows = cur
        elif cur is not None and line:
            cur.append(line)
    name, meta_title, meta_desc, desc_raw = blocks[0][0].split('\t')
    name, meta_title, meta_desc = [html.unescape(unesc(x)).strip() for x in (name, meta_title, meta_desc)]
    # Проверка (2026-09-30): старый товар должен быть той же модели, что строка таблицы (ссылка в столбце B бывает перепутана)
    if not args.old_product:
        _oerr = title_check.check_old_name(name, items[0].get('row') or rows[items[0]['ro']])
        assert not _oerr, f'старый товар {old_id} «{name}» не той модели: {_oerr} — поправить столбец B таблицы или --old-id'
    name = re.sub(r'\s+', ' ', name).strip()  # на старом сайте бывают двойные пробелы
    if args.name:
        print(f'название: «{name}» → «{args.name}»')
        name = args.name
    slug = blocks[1][0].strip()
    main_img, upc = (blocks[2][0].split('\t') + [''])[:2]
    extra_imgs = [x.strip() for x in blocks[3]] if len(blocks) > 3 and blocks[3] is not cat_path_rows else []
    upc = upc.strip()
    if args.time:
        print(f'время ремонта: «{upc}» → «{args.time}»')
        upc = args.time
    desc_in = html.unescape(unesc(desc_raw))
    assert not any(ord(ch) > 0xFFFF for ch in name + meta_title + meta_desc + desc_in), '4-байтовые символы (эмодзи) — CS-Cart их не сохранит'
    # старый адрес — только по столбцу B (номер старого товара) через старую базу: путь главной категории + slug товара.
    # Столбец D не используем: там бывали чужие адреса (9005) и мусор (у iPad 10 — число 160).
    old_url = ''
    if cat_path_rows:
        old_url = 'https://irepair.ru/' + '/'.join(x.split('\t')[1].strip() for x in cat_path_rows) + '/' + slug + '/'
        code = head(old_url)[0]
        if code != 200:
            print(f'!!! старый адрес {old_url} отвечает {code} — редирект не создаём, проверить вручную')
            old_url = ''
    else:
        print('!!! у старого товара нет главной категории — старый адрес не найден, редирект не создаём')
else:
    # услуги нет на старом сайте: название — из RemOnline («… iPhone 17e -» → без «-»), адрес — --slug (обязателен),
    # без описания, мета, фото, времени ремонта и редиректа (владелец добавит сам)
    assert args.slug, 'услуги нет на старом сайте — нужен --slug'
    name = args.name or re.sub(r'\s*[-|]\s*$', '', items[0]['title'].split('|')[0]).strip()
    meta_title = meta_desc = desc_in = upc = main_img = ''
    extra_imgs, cat_path_rows, old_url = [], [], ''
    slug = args.slug
    print(f'!!! услуги нет на старом сайте (столбец B пуст) — создаём без описания и фото: «{name}»')

with tempfile.TemporaryDirectory() as tmp:
    open(os.path.join(tmp, 'in.html'), 'w', encoding='utf-8').write(desc_in)
    subprocess.run([sys.executable, os.path.join(HERE, 'prep_desc.py'), os.path.join(tmp, 'in.html'), os.path.join(tmp, 'out.html')], check=True)
    desc = open(os.path.join(tmp, 'out.html'), encoding='utf-8').read() if desc_in.strip() else ''

# Apple Watch (владелец 2026-09-29): шаблонный FAQ старого сайта «Популярные вопросы» («Какие есть варианты качества
# аккумулятора?…», гарантия 3 месяца, курьер Dostavista) не переносим — вырезаем его, остальной текст оставляем.
_faq = re.search(r'<h3[^>]*>\s*Популярные вопросы\s*</h3>', desc)
if _faq and 'Apple Watch' in desc and 'Какие есть варианты качества аккумулятора' in desc[_faq.start():]:
    _tail = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<(svg|style|script)\b.*?</\1>|<[^>]+>', ' ', desc[_faq.start():], flags=re.S)))
    assert len(_tail) < 1200, f'после FAQ «Популярные вопросы» есть ещё текст ({len(_tail)} симв.) — проверить вручную'
    desc = desc[:_faq.start()].strip()
    print('убран FAQ «Популярные вопросы» (Apple Watch) — описание', f'{len(desc)} симв.' if desc else 'пустое')

# Все остальные (владелец 2026-09-30): в FAQ старого сайта убираем заголовок «Популярные вопросы» и зелёные
# иконки-кружки (svg с #59B561) — выглядят плохо; сами вопросы и ответы оставляем
_n = len(re.findall(r'<svg\b(?:(?!</svg>).)*?59B561', desc, flags=re.S))
desc = re.sub(r'<h3[^>]*>\s*Популярные вопросы\s*</h3>\s*', '', desc)
desc = re.sub(r'<svg\b(?:(?!</svg>).)*?59B561.*?</svg>\s*', '', desc, flags=re.S)
if _n:
    print(f'FAQ: убраны заголовок «Популярные вопросы» и {_n} иконок')

if args.rename_model:
    _from, _to = args.rename_model
    _rx = re.compile(re.escape(_from) + r'(?![0-9A-Za-zА-Яа-я]|\s+(?:Pro|Plus|Max|Mini|mini|Air|e|E)\b)')
    _cnt = sum(len(_rx.findall(x)) for x in (meta_title, meta_desc, desc))
    meta_title, meta_desc, desc = (_rx.sub(_to, x) for x in (meta_title, meta_desc, desc))
    print(f'«{_from}» → «{_to}» в мета и описании: {_cnt} замен')

# значения характеристики вариантов
variant_ids = {}
if args.feature:
    feat = cs('GET', f'features/{args.feature}')
    variant_ids = {v['variant'].strip(): str(v['variant_id']) for v in feat['variants'].values()}
    for it in items:
        assert it['value'] in variant_ids, f"нет значения «{it['value']}» у характеристики {args.feature}: {list(variant_ids)}"
model_ids = {}
if args.model_feature:
    mfeat = cs('GET', f'features/{args.model_feature}')
    model_ids = {v['variant'].strip(): str(v['variant_id']) for v in (mfeat.get('variants') or {}).values()}
    new_models = sorted({(it['model'], it['model_pos']) for it in items if it['model'] not in model_ids}, key=lambda x: x[1])
    for label, pos in new_models:
        print(f'  новое значение «{label}» у характеристики {args.model_feature}' + (' (dry-run — не создаём)' if args.dry_run else ''))

print(f'Старый товар {old_id}: «{name}» | slug {slug}' + (f' → новый {args.slug}' if args.slug else '') + f' | upc «{upc}» | картинок {(1 if main_img else 0) + len(extra_imgs)} | описание {len(desc)} симв.')
print('Старый URL:', old_url)
for it in items:
    print(f"  RO {it['ro']} {it.get('model', '') + ' · ' if args.model_feature else ''}{it['value']} {it['price']} ₽ гарантия «{it['warranty']}»")
if args.dry_run:
    sys.exit(0)

# Вид опций в карточке (правило владельца 2026-09-30): плитками — только тип запчасти (--feature),
# всё остальное (модель, конфигурация, размер корпуса, --model-feature) — выпадающим списком
for fid, style in ((args.feature, 'dropdown_labels'), (args.model_feature, 'dropdown')):
    if fid:
        sql_new(f"UPDATE cscart_product_features SET feature_style='{style}' WHERE feature_id={int(fid)}")

if args.model_feature and new_models:
    # существующие значения передаём с id (иначе API их удалит), новые — без id, с позицией для сортировки
    keep = [{'variant_id': v['variant_id'], 'variant': v['variant'], 'position': v.get('position', 0)}
            for v in (mfeat.get('variants') or {}).values()]
    cs('PUT', f'features/{args.model_feature}', {'variants': keep + [{'variant': l, 'position': p} for l, p in new_models]})
    mfeat = cs('GET', f'features/{args.model_feature}')
    model_ids = {v['variant'].strip(): str(v['variant_id']) for v in (mfeat.get('variants') or {}).values()}
    assert all(it['model'] in model_ids for it in items), 'значения модели не создались'

# 4-5. Создание (сразу в категории, включёнными)
def variant_name(it):
    return f"{name} | {it['model']} | {it['value']}" if args.model_feature else f"{name} | {it['value']}"


ids = []
for n, it in enumerate(items):
    features = {str(args.feature): variant_ids[it['value']]} if args.feature else {}
    if args.model_feature:
        features[str(args.model_feature)] = model_ids[it['model']]
    if it['warranty']:
        features['4'] = it['warranty']
    if upc:
        features['5'] = upc
    if it.get('from_price'):
        features['19'] = 'Y'  # «Цена «от»» — карточка и список показывают «от 35 000 ₽»
    it['features'] = features
    body = dict(product=name if n == 0 else variant_name(it), price=it['price'], product_code=(args.code if args.code and n == 0 else it['ro'] if it['ro'].startswith(('OLD-', 'TAB-')) else f"RO-{it['ro']}"),
                status='A', category_ids=[args.cat], main_category=args.cat, company_id=1,
                page_title=meta_title, meta_description=meta_desc, full_description=desc, product_features=features,
                **({'main_pair': {'detailed': {'image_path': 'https://irepair.ru/image/' + main_img, 'alt': name}}} if main_img else {}))
    if extra_imgs:
        body['image_pairs'] = [{'detailed': {'image_path': 'https://irepair.ru/image/' + x, 'alt': name}} for x in extra_imgs]
    if n == 0:
        body['seo_name'] = args.slug or slug.replace('_', '-')
    ids.append(cs('POST', 'products', body)['product_id'])
    print('создан товар', ids[-1])

# 6. Группа вариаций + имена вариантов. Правило владельца: опция выводится ВСЕГДА, даже если она одна
# (потом в услуге могут появиться другие) — группа создаётся и для одного товара
if len(ids) > 1 or args.model_feature or args.feature:
    code = f"{re.sub(r'[^a-z0-9]+', '-', slug.replace('_', '-'))}-{args.cat}"
    gfeatures = [{'feature_id': args.feature, 'purpose': 'group_variation_catalog_item'}]
    if args.model_feature:
        # модель — первым выбором, тип запчасти — вторым
        gfeatures.insert(0, {'feature_id': args.model_feature, 'purpose': 'group_variation_catalog_item'})
    g = cs('POST', 'product_variations_groups', {'product_ids': ids, 'code': code, 'features': gfeatures})
    print('группа', g['group']['id'], code)
    for pid, it in zip(ids[1:], items[1:]):
        cs('PUT', f'products/{pid}', {'product': variant_name(it)})
    # при создании группы CS-Cart копирует характеристики главного товара на варианты — гарантию/время
    # (у OEM и AASP разные) записываем каждому заново; дальше их не трогает синхронизация
    # (my_changes: schemas/product_variations/product_data_sync.post.php исключает характеристики 4 и 5)
    for pid, it in zip(ids, items):
        cs('PUT', f'products/{pid}', {'product_features': it['features']})

# 6a. Позиция услуги в категории (порядок услуг владельца)
if args.position:
    sql_new(f"update cscart_products_categories set position={args.position} where category_id={args.cat} and product_id in ({','.join(map(str, ids))})")
    print('позиция в категории', args.position)

# 7. Редиректы: удалить авто-редирект, созданный при создании главного товара; добавить 301 со старого адреса
main = ids[0]
auto = sql_new(f"select redirect_id, src from cscart_seo_redirects where type='p' and object_id in ({','.join(map(str, ids))})")
for line in filter(None, auto.split('\n')):
    rid, src = line.split('\t')
    sql_new(f'delete from cscart_seo_redirects where redirect_id={rid}')
    print('удалён авто-редирект', rid, src)
src = re.sub(r'^https?://[^/]+', '', old_url).rstrip('/') if old_url and not args.no_redirect else ''
if args.no_redirect:
    print('редирект со старого адреса не ставим (--no-redirect)')
if src:
    # если новый адрес товара совпадает со старым — редирект не нужен
    if head('https://dev.irepair.ru' + src + '/')[0] == 200:
        print('старый адрес совпадает с новым — редирект не нужен:', src + '/')
        src = ''
if src:
    sql_new("insert into cscart_seo_redirects (src,dest,type,object_id,company_id,lang_code) "
            f"values ('{src}','','p',{main},1,'ru')")
# 7a. Картинки: обрезать белые/прозрачные поля по контуру объекта (crop_images.py)
print('обрезка картинок:')
crop_products(ids)
_run(NEW_SSH + ['rm -rf /var/www/www-root/data/www/dev.irepair.ru/var/cache/registry/block_content_*'])

# 8. Проверка
for pid in ids:
    p = cs('GET', f'products/{pid}')
    f = p.get('product_features', {})
    print(f"{pid} | {p['product']} | {p['price']} | {p['product_code']} | {p['status']} | seo {p.get('seo_name')} | parent {p.get('parent_product_id')} "
          f"| cat {p.get('category_ids')} | desc same {p.get('full_description') == desc} | img {bool(p.get('main_pair'))} "
          f"| f{args.feature} {f.get(str(args.feature), {}).get('variant')}"
          + (f" | f{args.model_feature} {f.get(str(args.model_feature), {}).get('variant')}" if args.model_feature else '') + f" | f4 {f.get('4', {}).get('value')} | f5 {f.get('5', {}).get('value')}")
if src:
    print('старый URL →', *head('https://dev.irepair.ru' + src + '/'))
