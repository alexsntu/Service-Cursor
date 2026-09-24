# Карточка товара и импорт — новый сайт iRepair (CS-Cart + UniTheme2)

> Вид списка категории «iRepair — Список услуг» и всё по категориям — в `../Категории/README.md`.

Работа от 2026-09-24. Всё выложено на dev.irepair.ru (FirstVDS, 188.120.249.151).
Доступы — в памяти Claude / `credentials.local.md`, в репозиторий не кладём.

## 1. Где что лежит

Папка `cscart/` повторяет путь на сервере от корня сайта
(`/var/www/www-root/data/www/dev.irepair.ru/`). Всё наше — в модуле **`my_changes`**,
поэтому обновления UniTheme2 это не затирают.

| Файл (в `design/themes/abt__unitheme2/templates/addons/my_changes/`) | Что делает |
|---|---|
| `blocks/product_templates/irepair_service_template.tpl` | Шаблон карточки **«iRepair — Услуга»** (копия «Стандартного шаблона» UT2) — ПК |
| `blocks/product_templates/components/irepair_service_mobile.tpl` | Мобильная часть этого шаблона (UT2 на телефонах рендерит отдельный файл — правки делать в ОБОИХ) |
| `components/irepair_product_promo.tpl` | Промо «Ремонт от 90 минут / Курьер от 30 минут / Гарантия N месяцев» (гарантия — характеристика 4) |
| `components/irepair_variant_note.tpl` | Расшифровка выбранной опции под опциями (текст = «Описание» значения характеристики) |
| `components/irepair_reward_points.tpl` | Блок «N вернем баллами» как на старом сайте + подсказка «1 ₽ = 1 балл»; на ПК выравнивается по кнопке |
| `components/irepair_lead_button.tpl` | Кнопка «Оформить заявку» открывает наш попап заявки (услуга + цена → Bitrix24) вместо корзины |
| `components/irepair_mobile_variant_scroll.tpl` | Телефон: после выбора опции прокрутка к заголовку услуги |

Ещё в модуле `my_changes` (копия в `../backend/product-import/my_changes/`):
`app/addons/my_changes/schemas/product_variations/product_types.post.php` — у вариантов своё название
(«Замена аккумулятора iPhone 17 | AASP»), иначе CS-Cart копирует название главного товара.

`product-promo.html` в корне папки — копия промо-блока для просмотра (источник — `components/irepair_product_promo.tpl`).

## 2. Как выкладывать правки шаблонов

1. Правим файл здесь, в `cscart/…`.
2. `scp -i ~/.ssh/irepair_firstvds <файл> root@188.120.249.151:/var/www/www-root/data/www/dev.irepair.ru/<тот же путь>`
3. `chown www-root:www-root <файл>`
4. Кэш: `rm -rf var/cache/templates/* var/cache/registry/block_content_*`
   (кэш блоков хранит готовый HTML страницы товара — без его очистки ПК показывает старое).

Шаблоны карточки/списка переключает сам владелец в админке (товар / категория / настройки).
Названия в выпадающих списках — языковые переменные `irepair_service_template`, `irepair_service_list`.

## 3. Хедер и общий CSS

- Хедер: `../header/irepair-old-header.html` → блок **190 «Header code»** (в БД `cscart_bm_blocks_content`,
  PHP-serialize, строка `ru`). Меню «iPhone» на ПК: первый пункт «Ремонт iPhone ›» → серии → модели;
  мобильное меню: «Серия iPhone N» → «Ремонт iPhone …», жидкое стекло. Меню собраны из категорий CS-Cart —
  при изменении категорий iPhone пересобрать.
- Общий CSS: `../irepair-old-header.css` → файл стиля темы `styles/data/New iRepair.css` (на сервере CRLF).
  После замены: очистить `var/cache/misc/assets`, `var/cache/registry`, `var/cache/templates` **и** обновить
  `cscart_storage_data.cache_id` (иначе браузеры держат старый CSS).
- В CSS: пункты выпадающих меню крупнее, отступ контента под хедером на ПК 40px (`.desktop-screen .tygh-content`).

## 4. Настройки и данные, изменённые в CS-Cart

- Рубль: 0 знаков после запятой (цены без копеек).
- Категории iPhone переименованы: серии «Серия iPhone N», модели «Ремонт iPhone …» (URL не менялись).
- Характеристики: 3 «Тип запчасти аккумулятора iPhone» (5 AASP, 6 OEM, описания = расшифровки),
  4 «Гарантия» (число, суффикс « мес.»), 5 «Время ремонта» (текст, «от 90 минут»).
- ⚠️ Модуль «Баннеры категорий» пропатчен для своих видов списка — подробности в `../Категории/README.md`.

## 5. Импорт услуг из RemOnline (коротко)

Товар создаётся из услуги RemOnline через API CS-Cart; цена — только из RemOnline (прайс 543835), дальше
синхронизируется только цена. Варианты (AASP/OEM…) — отдельные товары в группе вариаций по характеристике;
главный — самый дешёвый: ему название и URL старого сайта (`_` → `-`, 301-редирект со старого адреса).
Всем вариантам — картинки, title, meta description, описание (через `../backend/product-import/prep_desc.py`:
относительные ссылки + CSS заголовков под `.mm-block`), гарантия (столбец L таблицы → характеристика 4),
время ремонта (`upc` старого товара → характеристика 5). Создаём выключенными, сразу в категории,
которую называет владелец. Полная пошаговая процедура — в памяти Claude (`project_cscart_product_import`).

## 6. При переезде на боевой домен перенести

Модуль `my_changes` целиком (шаблоны + схема вариаций) и его включение, языковые переменные,
стиль темы, блок хедера, настройку валюты, характеристики 3/4/5 с описаниями значений,
переименованные категории, патч `ab__category_banners`.
