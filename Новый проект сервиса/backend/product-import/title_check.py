"""Сверка названия услуги в RemOnline с таблицей (владелец 2026-09-30: коды бывают перепутаны между моделями/услугами).

Таблица: услуга (столбец J), устройство (G), модель (H), тип запчасти (I, «-» = без типа).
RemOnline: «<услуга> <устройство> <модель ...> | <тип>». У iPhone название точное; у MacBook / iPad / Watch
в названии ещё год, A-номера, размер корпуса — поэтому проверяем: услуга в начале, все части модели есть
в названии (чип «M4» в таблице может отсутствовать в RemOnline), тип совпадает.
"""
import re


def _n(x):
    x = str(x or '').replace('ё', 'е').replace('Ё', 'Е').replace('М', 'M')  # кириллическая «М4» в таблице
    x = re.sub(r'(?<=\d)[еЕ]\b', 'e', x)  # «16е» кириллицей = «16e»
    x = re.sub(r'\s*/\s*', '/', x)  # «громкости/блокировки» = «громкости / блокировки»
    return re.sub(r'\s+', ' ', x).strip().lower()


def _tokens(x):
    return re.findall(r'[a-zа-я0-9]+(?:[.,][0-9]+)?', _n(x))


def check(title, row):
    """None — совпадает; иначе строка с описанием расхождения."""
    service, _, subtype = str(row[9]).partition('|')
    device, model, part = str(row[6] or ''), str(row[7] or '').replace('.0', ''), row[8]
    if subtype.strip():
        # составная услуга «Замена камеры| Задняя камера» → в RemOnline «Замена камеры iPhone 17 | Задняя камера[ | тип]»
        parts = str(title).split('|')
        if len(parts) < 2 or _n(parts[1]) != _n(subtype):
            return f'вид услуги: в RemOnline «{title}», в таблице «{row[9]}»'
        main, typ = parts[0], '|'.join(parts[2:])
    else:
        # тип — после последней «|»; у MacBook в середине названия тоже бывают «|» (A-номера)
        main, _, typ = str(title).rpartition('|') if '|' in str(title) else (str(title), '', '')
    ttype = '' if _n(part) in ('', '-', 'none') else _n(part)
    if ttype and _n(typ) != ttype:
        return f'тип: в RemOnline «{typ.strip()}», в таблице «{part}»'
    if not _n(main).startswith(_n(service)):
        # вариант RemOnline «Замена динамика iPhone 16 | Замена слухового динамика»: общая услуга + модель, после «|» — услуга таблицы
        parts = [p.strip() for p in str(title).split('|')]
        if not subtype.strip() and len(parts) >= 2 and _n(parts[1]) == _n(service) and not ttype:
            toks = _tokens(parts[0])
            dev = _tokens(device)
            if dev and dev[0] in toks:
                got = toks[toks.index(dev[0]) + len(dev):]
                if got == [t for t in _tokens(model) if t not in dev or t in ('se',)] or (device.strip().lower() != 'iphone' and all(t in got for t in need_tokens(model, device))):
                    return None
        return f'услуга: в RemOnline «{main.strip()}», в таблице «{service}»'
    rest = _tokens(_n(main)[len(_n(service)):])
    need = [t for t in _tokens(model) if t not in _tokens(device) or t in ('se',)]
    need = [t for t in need if not re.fullmatch(r'm\d', t)]  # чип M1–M5 может не быть в названии RemOnline
    if device.strip().lower() == 'iphone':
        # iPhone: модель должна совпасть целиком («iPhone 12» ≠ «iPhone 12 Pro»)
        exp = _tokens(f'{device} {model}')
        if rest != exp:
            return f'модель: в RemOnline «{main.strip()}», в таблице «{device} {model}»'
        return None
    missing = [t for t in need if t not in rest]
    if missing:
        return f'модель: в RemOnline «{main.strip()}», в таблице «{device} {model}» (нет: {", ".join(missing)})'
    return None


def extra_type(title, row):
    """Тип запчасти, указанный в RemOnline, когда в таблице тип «-» (для предупреждения), иначе ''."""
    if str(row[8] or '').strip() not in ('', '-', 'None'):
        return ''
    parts = [p.strip() for p in str(title).split('|')]
    if '|' in str(row[9]):
        return '|'.join(parts[2:]).strip()
    if len(parts) > 1 and _n(parts[1]) == _n(str(row[9])):
        return '|'.join(parts[2:]).strip()  # «… | Замена слухового динамика» — это услуга, а не тип
    return parts[-1] if len(parts) > 1 else ''


def check_old_name(name, row):
    """Название старого товара («Замена камеры iPhone 6 Plus») против модели строки таблицы. None — совпадает.
    Проверяем только iPhone (у остальных устройств старые названия слишком разные)."""
    device, model = str(row[6] or '').strip(), str(row[7] or '').replace('.0', '')
    if device.lower() != 'iphone':
        return None
    toks = _tokens(name)
    # модель — в конце названия: собираем «модельные» слова с конца («… блокировки 15 Pro Max» — без слова iPhone тоже)
    got = []
    for t in reversed(toks):
        if re.fullmatch(r'\d+[es]?|se|x|xr|xs|pro|max|plus|mini|air', t):
            got.insert(0, t)
        else:
            break
    exp = _tokens(model)
    ok = got == exp or (exp == ['se', '1'] and got == ['se']) or (exp == ['17', 'air'] and got == ['air'])
    return None if ok else f'в названии «iPhone {" ".join(got)}», в таблице «iPhone {model}»'


def need_tokens(model, device):
    need = [t for t in _tokens(model) if t not in _tokens(device) or t in ('se',)]
    return [t for t in need if not re.fullmatch(r'm\d', t)]
