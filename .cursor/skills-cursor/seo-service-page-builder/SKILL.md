---
name: seo-service-page-builder
description: >-
  Generates SEO-optimized HTML service pages for iRepair (Moscow Apple repair center, irepair.ru) on OpenCart.
  Use when the user provides a repair category or device model and asks to create/write/generate an SEO page,
  service block, repair page, or HTML content for the service section. Output is a self-contained HTML page
  with embedded CSS in style, ready for OpenCart. Follows .cursor/rules/seo--for-service-html-block.mdc.
---

# SEO service page builder (iRepair / OpenCart)

Исполняемый скилл: исследование SERP, опционально страницы конкурентов, внутренняя матрица ключей (пользователю не показывать), уточнение **URL перелинковки** и **изображений**, генерация **одного** готового HTML по правилу проекта.

**Норматив:** `.cursor/rules/seo--for-service-html-block.mdc` (структура, JSON-LD, палитра, без цен в ₽, телефон/Telegram из констант). Контент в `.mm-block` без collapse; вариант со свёрткой — только по `seo--for-service-html-block--with-collapse.mdc`.

**Обзор этапов** (подробнее о ролях файлов): скилл **seo-service-page-workflow**.

---

## Обязательно перед генерацией

- Вопрос про CSS дизайн-систему — по хуку `page-generation-hook.mdc` / шаг 0 в правиле SEO-блока.
- **Телефон Alloka:** на сайте включён трекинг Alloka (подмена номеров). Во **всём HTML-теле** каждый **видимый** номер `8 800 555-21-90` и текст внутри `tel:+78005552190` оборачивать в `<span class="phone_alloka">…</span>`. Пример: `<a href="tel:+78005552190" …><span class="phone_alloka">8&nbsp;800&nbsp;555-21-90</span></a>`. В **`href="tel:…"`** и в **JSON-LD** поле `telephone` — **без** `span`, только канонический номер (в JSON — строка без HTML).
- **Адрес офиса:** `ул. Большая Садовая, д. 5, под. 2, этаж 1А, офис А25, Москва` — использовать в JSON-LD `PostalAddress.streetAddress`, CTA и FAQ без отклонений.
- Внутренние ссылки: не выдумывать URL; для iPhone при отсутствии кастомных ссылок — стандартный набор из правила.
- Карточки услуг: **3 или 6** штук; stat-strip — **6** карточек.

---

## SERP и конкуренты

Параллельно несколько целевых веб-поисков по теме (модель + услуга + Москва / ремонт / симптомы / FAQ-формулировки). Если пользователь дал URL конкурентов — открыть и выписать темы и пробелы; иначе опираться на выдачу и общий список конкурентов из правила.

---

## Самопроверка перед выдачей

- **Заголовки:** собрать текст всех `<h2>`, `<h3>`, `<h4>` в `.mm-block`, нормализовать пробелы (trim + схлопнуть повторы); не должно быть двух одинаковых строк. При совпадении переформулировать один заголовок; если это FAQ — обновить JSON-LD `name` в точном соответствии.
- JSON-LD: `@graph` LocalBusiness + WebPage + FAQPage; `speakable`; FAQ `name` в JSON **=** тексту `itemprop="name"` в HTML.
- Нет конкретных цен в ₽ в тексте и описаниях.
- Эмодзи в тексте — только HTML-сущности из таблицы правила.
- Лид `.mm-intro-text`: кто/где/сроки/диагностика бесплатно/гарантия.
- Кириллица «айфон» и т.д. в FAQ и симптомах — по правилу.
- **Alloka:** все видимые номера в HTML в `phone_alloka`; JSON-LD и `tel:` без обёртки.
- Один финальный ответ: один блок кода HTML, без лишнего комментария до/после.

---

## См. также

- `.cursor/rules/seo--for-service-html-block.mdc`
- `.cursor/skills/seo-service-page-workflow/SKILL.md`
