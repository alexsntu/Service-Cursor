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
COL_PRICE = 51   # AY — Текущая цена

SHEET_NAME = "МСервис"
DATA_START_ROW = 10


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

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    ws = wb[SHEET_NAME]

    rows = []
    skipped_no_id = 0
    skipped_no_price = 0

    for r in range(DATA_START_ROW, ws.max_row + 1):
        c_id = ws.cell(row=r, column=COL_ID).value
        if not c_id:
            skipped_no_id += 1
            continue

        device = clean(ws.cell(row=r, column=COL_DEVICE).value)
        model = clean(ws.cell(row=r, column=COL_MODEL).value)
        part = clean(ws.cell(row=r, column=COL_PART).value)
        service = clean(ws.cell(row=r, column=COL_SERVICE).value)
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
        if approx:
            entry["approx"] = True
        rows.append(entry)

    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "repair-prices.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))

    devices = sorted(set(x["d"] for x in rows))
    print(f"Источник: {xlsx_path}")
    print(f"Строк экспортировано: {len(rows)}")
    print(f"Пропущено (нет ID): {skipped_no_id}, пропущено (нет цены): {skipped_no_price}")
    print(f"Устройства: {devices}")
    for d in devices:
        models = sorted(set(x["m"] for x in rows if x["d"] == d))
        print(f"  {d}: {len(models)} моделей")
    print(f"Сохранено: {out_path} ({os.path.getsize(out_path)} байт)")


if __name__ == "__main__":
    main()
