"""Сверка названия услуги в RemOnline с таблицей (владелец 2026-09-30: коды бывают перепутаны между моделями/услугами).

Таблица: услуга (столбец J), устройство (G), модель (H), тип запчасти (I, «-» = без типа).
RemOnline: «<услуга> <устройство> <модель ...> | <тип>». У iPhone название точное; у MacBook / iPad / Watch
в названии ещё год, A-номера, размер корпуса — поэтому проверяем: услуга в начале, все части модели есть
в названии (чип «M4» в таблице может отсутствовать в RemOnline), тип совпадает.
"""
import re


def _n(x):
    x = str(x or '').replace('ё', 'е').replace('Ё', 'Е').replace('М', 'M')  # кириллическая «М4» в таблице
    return re.sub(r'\s+', ' ', x).strip().lower()


def _tokens(x):
    return re.findall(r'[a-zа-я0-9]+(?:[.,][0-9]+)?', _n(x))


def check(title, row):
    """None — совпадает; иначе строка с описанием расхождения."""
    service, device, model, part = str(row[9]).split('|')[0], str(row[6] or ''), str(row[7] or '').replace('.0', ''), row[8]
    main, _, typ = str(title).rpartition('|') if '|' in str(title) else (str(title), '', '')
    # тип — после последней «|»; у MacBook в середине названия тоже бывают «|» (A-номера)
    ttype = '' if _n(part) in ('', '-', 'none') else _n(part)
    if ttype and _n(typ) != ttype:
        return f'тип: в RemOnline «{typ.strip()}», в таблице «{part}»'
    if not _n(main).startswith(_n(service)):
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
