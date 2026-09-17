#!/usr/bin/env python3
"""
Генерирует repair-prices.json (данные для калькулятора стоимости ремонта на главной
странице) из мастер-таблицы пользователя (Документы/Сервис/Новая таблица<NNN>.xlsx,
лист "МСервис").

Повторяемо: при обновлении цен пользователь присылает новый файл той же структуры,
достаточно перезапустить с новым путём — колонки не меняются (см. память проекта
project_opencart_options_audit.md).

Использование:
    python3 build-repair-prices.py "/Users/a0000/Документы/Сервис/Новая таблица888.xlsx"

Результат кладётся рядом со скриптом: ../data/repair-prices.json
(main-page/data/repair-prices.json), откуда его подключает index-calculator.html.
"""
import sys
import os
import re
import json
import openpyxl

COL_ID = 3       # C  — ID услуги (opt_XXXX / p_XXXX)
COL_DEVICE = 7   # G  — Устройство
COL_MODEL = 8    # H  — Модель
COL_PART = 9     # I  — Запчасть (AASP/OEM/...)
COL_SERVICE = 10 # J  — Услуга
COL_MODELNO = 14 # N  — MODEL № (конфигурация/поколение MacBook, чип)
COL_PRICE = 51   # AY — Текущая цена

SHEET_NAME = "МСервис"
DATA_START_ROW = 10

# MacBook: соответствие номера модели Apple (A-номер) -> чип.
# Подтверждено пользователем 2026-09-17 (в т.ч. для самых новых A3xxx моделей,
# которых нет в открытых источниках на момент написания).
CHIP_MAP = {
    # MacBook 12"
    "A1534": "Intel Core M",
    # Air 11"
    "A1465": "Intel",
    # Air 13"
    "A1466": "Intel", "A1369": "Intel",
    "A1932": "Intel", "A2179": "Intel",
    "A2337": "M1", "A2681": "M2", "A3113": "M3", "A3240": "M4", "A3449": "M5",
    # Air 15"
    "A2941": "M2", "A3114": "M3", "A3241": "M4",
    # Pro 13"
    "A1278": "Intel", "A1425": "Intel", "A1502": "Intel",
    "A1706": "Intel", "A1708": "Intel", "A1989": "Intel",
    "A2159": "Intel", "A2251": "Intel", "A2289": "Intel",
    "A2338": "M1",
    # Pro 15"
    "A1286": "Intel", "A1398": "Intel", "A1707": "Intel", "A1990": "Intel",
    # Pro 14"
    "A2442": "M1 Pro/Max", "A2779": "M2 Pro/Max",
    "A2918": "M3", "A2992": "M3 Pro/Max",
    "A3112": "M4", "A3185": "M4 Max", "A3401": "M4 Pro",
    "A3434": "M5", "A3426": "M5 Pro", "A3427": "M5 Max",
    # Pro 16"
    "A2141": "Intel", "A2485": "M1 Pro/Max", "A2780": "M2 Pro/Max",
    "A2991": "M3 Pro/Max", "A3403": "M4 Pro", "A3186": "M4 Max",
}

# Особые (не-A-номер) значения MODEL№ — либо просто подпись без чипа (услуга не
# зависит от поколения, а от эры/сложности), либо чип-подпись в собственной
# формулировке (термопаста: цена зависит от того, M1(-M4) чип или нет).
MODELNO_SPECIAL = {
    "До 2020 года": "До 2020 года",
    "После 2020 года": "После 2020 года",
    "Без разбора клавиатуры": "Без разбора клавиатуры",
    "С разбором клавиатуры": "С разбором клавиатуры",
    "На процессоре M1": "M1",
    "На процессоре M1 - M4": "M1-M4",
}
# "Остальные" означает разное в зависимости от модели (подтверждено
# пользователем на примере строк 1087/1088 и 1090/1091 исходной таблицы).
MODELNO_OSTALNYE_BY_MODEL = {
    "Pro 13": "Не на чипе M1",
    "Air 13": "Не на чипах M1-M4",
}

# Порядок моделей MacBook в пилюлях калькулятора — держать в синхроне с
# MACBOOK_MODEL_ORDER в Новый проект сервиса/main-page/index-calculator.html.
# Используется только для диагностики: новая модель MacBook, которой здесь
# нет, будет отсортирована в JS по умолчанию (indexOf === -1), это надо
# заметить и добавить вручную в оба места.
MACBOOK_MODEL_ORDER = [
    "MacBook Pro 16", "MacBook Pro 15", "MacBook Pro 14", "MacBook Pro 13",
    "MacBook Air 15", "MacBook Air 13", "MacBook Air 11", "MacBook 12",
]

# Устройства, для которых в калькуляторе уже есть вкладка (index-calculator.html).
KNOWN_DEVICES = ["iPhone", "Macbook", "iPad", "Watch"]


def build_watch_config_label(modelno):
    """Возвращает подпись размера корпуса Watch ("42 мм") или None, если
    для этой строки размер не задан."""
    if not modelno:
        return None
    m = re.match(r"(\d+)\s*mm", modelno, re.IGNORECASE)
    if m:
        return "{} мм".format(m.group(1))
    return modelno


def build_config_label(model, modelno):
    """Возвращает подпись конфигурации ("M1 Pro/Max | A2485") или None, если
    для этой строки конфигурация не задана (MODEL№ пусто)."""
    if not modelno:
        return None
    if modelno == "Остальные":
        label = MODELNO_OSTALNYE_BY_MODEL.get(model)
        return label if label else modelno
    if modelno in MODELNO_SPECIAL:
        return MODELNO_SPECIAL[modelno]
    # Обычный случай: один или несколько A-номеров через " / "
    parts = [p.strip() for p in modelno.split("/")]
    chips = [CHIP_MAP.get(p, "?") for p in parts]
    return "{} | {}".format(" / ".join(chips), modelno)


def clean(value):
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


def parse_price(raw):
    """Возвращает (price:int, approx:bool). 'от 35000' -> (35000, True)."""
    if raw is None:
        return None, False
    if isinstance(raw, (int, float)):
        return int(raw), False
    text = str(raw).strip()
    approx = text.lower().startswith("от")
    digits = re.sub(r"[^\d]", "", text)
    if not digits:
        return None, False
    return int(digits), approx


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)

    xlsx_path = sys.argv[1]
    if not os.path.isfile(xlsx_path):
        print(f"Файл не найден: {xlsx_path}")
        sys.exit(1)

    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    out_path = os.path.join(out_dir, "repair-prices.json")
    old_rows = []
    if os.path.isfile(out_path):
        with open(out_path, "r", encoding="utf-8") as f:
            old_rows = json.load(f)

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    ws = wb[SHEET_NAME]

    rows = []
    skipped_no_id = 0
    skipped_no_price = 0
    unresolved_chips = set()

    for r in range(DATA_START_ROW, ws.max_row + 1):
        c_id = ws.cell(row=r, column=COL_ID).value
        if not c_id:
            skipped_no_id += 1
            continue

        device = clean(ws.cell(row=r, column=COL_DEVICE).value)
        model = clean(ws.cell(row=r, column=COL_MODEL).value)
        part = clean(ws.cell(row=r, column=COL_PART).value)
        service = clean(ws.cell(row=r, column=COL_SERVICE).value)
        modelno = clean(ws.cell(row=r, column=COL_MODELNO).value)
        price_raw = ws.cell(row=r, column=COL_PRICE).value

        if not device or not model or not service:
            continue

        # "17я серия" и т.п. — заглушки категорий/подпапок в таблице, а не
        # реальные модели (пользователь подтвердил 2026-09-16) — пропускаем.
        if "серия" in model.lower():
            continue

        # iPad: 3 лишние/дублирующие строки в конце таблицы (пользователь
        # подтвердил 2026-09-16) — пропускаем.
        if device == "iPad" and model in ("Для всех", "Pro 13", "Pro 11 S5"):
            continue

        # Конфигурация: для MacBook — чип/поколение (считаем до переименования
        # model в "MacBook ...", т.к. MODELNO_OSTALNYE_BY_MODEL завязан на
        # исходные названия "Pro 13"/"Air 13"); для Watch — размер корпуса.
        if device == "Macbook":
            config = build_config_label(model, modelno)
            if config:
                for token in config.split(" | ")[0].split(" / "):
                    if token == "?":
                        unresolved_chips.add(modelno)
        elif device == "Watch":
            config = build_watch_config_label(modelno)
        else:
            config = None

        if device == "iPhone" and not model.lower().startswith("iphone"):
            model = "iPhone " + model

        if device == "Macbook":
            model = "MacBook 12" if model == "12 | 12" else "MacBook " + model

        if device == "iPad" and model.split(" ", 1)[0] in ("Mini", "Pro", "Air"):
            model = "iPad " + model

        price, approx = parse_price(price_raw)
        if price is None:
            skipped_no_price += 1
            continue

        entry = {
            "d": device,
            "m": model,
            "s": service,
            "p": price,
        }
        if part and part != "-":
            entry["q"] = part
        if config:
            entry["c"] = config
        if approx:
            entry["approx"] = True
        rows.append(entry)

    os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))

    devices = sorted(set(x["d"] for x in rows))
    print(f"Источник: {xlsx_path}")
    print(f"Строк экспортировано: {len(rows)}")
    print(f"Пропущено (нет ID): {skipped_no_id}, пропущено (нет цены): {skipped_no_price}")
    if unresolved_chips:
        print(f"⚠ Нераспознанные MODEL№ (нет в CHIP_MAP): {sorted(unresolved_chips)}")
    print(f"Устройства: {devices}")
    for d in devices:
        models = sorted(set(x["m"] for x in rows if x["d"] == d))
        print(f"  {d}: {len(models)} моделей")
    print(f"Сохранено: {out_path} ({os.path.getsize(out_path)} байт)")

    unknown_devices = [d for d in devices if d not in KNOWN_DEVICES]
    if unknown_devices:
        print(f"⚠ Новое устройство, для которого нет вкладки в калькуляторе (добавить вручную в index-calculator.html): {unknown_devices}")

    # Сравнение с предыдущей версией repair-prices.json — новые/пропавшие
    # модели и услуги нужно явно показать пользователю (он сам их добавляет
    # в таблицу и должен быть уверен, что они реально попали в калькулятор).
    if old_rows:
        old_models = set((x["d"], x["m"]) for x in old_rows)
        new_models_set = set((x["d"], x["m"]) for x in rows)
        old_services = set((x["d"], x["s"]) for x in old_rows)
        new_services_set = set((x["d"], x["s"]) for x in rows)

        added_models = sorted(new_models_set - old_models)
        removed_models = sorted(old_models - new_models_set)
        added_services = sorted(new_services_set - old_services)
        removed_services = sorted(old_services - new_services_set)

        print("\n--- Сравнение с предыдущей версией ---")
        if added_models:
            print(f"🆕 Новые модели ({len(added_models)}):")
            for d, m in added_models:
                print(f"   {d}: {m}")
        if removed_models:
            print(f"🗑 Пропавшие модели ({len(removed_models)}):")
            for d, m in removed_models:
                print(f"   {d}: {m}")
        if added_services:
            print(f"🆕 Новые услуги ({len(added_services)}):")
            for d, s in added_services:
                print(f"   {d}: {s}")
        if removed_services:
            print(f"🗑 Пропавшие услуги ({len(removed_services)}):")
            for d, s in removed_services:
                print(f"   {d}: {s}")
        if not (added_models or removed_models or added_services or removed_services):
            print("Без изменений в моделях/услугах — только цены.")

        new_macbook_models = [m for d, m in added_models if d == "Macbook" and m not in MACBOOK_MODEL_ORDER]
        if new_macbook_models:
            print(f"⚠ Новые модели MacBook не прописаны в MACBOOK_MODEL_ORDER (добавить вручную в index-calculator.html): {new_macbook_models}")
    else:
        print("\n(Предыдущей версии repair-prices.json не найдено — это базовая версия для будущих сравнений.)")


if __name__ == "__main__":
    main()
