# Категории — оформление страниц категорий нового сайта iRepair (CS-Cart + UniTheme2)

Порядок работы (с 2026-09-24): **оформляем категорию → заливаем в неё все услуги → проверяем**.
Карточка товара уже готова — см. `../Карточка товара/README.md`.

## Структура папки

`cscart/` повторяет путь на сервере от корня сайта
(`/var/www/www-root/data/www/dev.irepair.ru/`). Всё наше — в модуле **`my_changes`**
(обновления UniTheme2 не затирают).

| Файл (в `design/themes/abt__unitheme2/templates/addons/my_changes/`) | Что делает |
|---|---|
| `blocks/product_list_templates/irepair_service_list.tpl` | Вид списка **«iRepair — Список услуг»** (копия «Компактного списка», `$tmpl='short_list'` — настройки UT2 для компактного списка продолжают действовать) |
| `blocks/product_list_templates/default_params/irepair_service_list.tpl` | Параметры вида (копия `default_params/short_list.tpl`) |
| `blocks/list_templates/irepair_service_list.tpl` | Вёрстка: заголовок «Стоимость услуг по ремонту …» + прайс как на старом сайте (название / «от» цена + время ремонта / «Заказать ремонт» → попап заявки; на телефоне строка целиком ведёт в услугу) |

Новые файлы для категорий кладём сюда же, сохраняя серверный путь.

## Как устроено в CS-Cart

- Виды списков CS-Cart ищет в `templates/blocks/product_list_templates/` темы **и** в
  `templates/addons/<включённый модуль>/blocks/product_list_templates/`. Название в админке —
  языковая переменная из `{** template-description:... **}` (`irepair_service_list` = «iRepair — Список услуг»).
- Вид выбирается у категории: Товары → Категории → категория → «Вид списка товаров».
  Через `?layout=` в адресе на неразрешённый вид не переключить.
- Страница категории: `views/categories/view.tpl` темы подключает шаблон выбранного вида.
- В списке категории CS-Cart **не грузит характеристики** товаров — нужные (время ремонта, id 5)
  шаблон достаёт сам: `["product_id"=>$product.product_id]|fn_get_product_features_list:"A"`.
- Тестовая категория: **47 «Ремонт iPhone 17»** — `/catalog/remont-iphone/remont-iphone-17/remont-iphone17/`.

## Выкладка

1. Правим файл здесь → `scp -i ~/.ssh/irepair_firstvds <файл> root@188.120.249.151:<корень сайта>/<тот же путь>`
2. `chown www-root:www-root <файл>`
3. `rm -rf var/cache/templates/* var/cache/registry/block_content_*`

## ⚠️ Патч модуля «Баннеры категорий»

`app/addons/ab__category_banners/func.php`, функция `fn_ab__get_category_banners`: модуль знает только
3 стандартных вида списка; для любого своего вида строил SQL с несуществующей колонкой и страница категории
падала (красный экран). Ветка `default:` исправлена на `$image_type='S'; $layout_name='short_list';`
(копия исходника на сервере: `/root/ab__category_banners.func.php.bak-20260924`).
**После обновления/переустановки модуля — повторить. На боевом сайте — тоже.**
