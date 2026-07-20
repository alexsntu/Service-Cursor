# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the content and SEO workspace for **iRepair** (irepair.ru) — an Apple repair service center in Moscow. The repo contains:

- SEO HTML pages for OpenCart categories (iPhone, MacBook, iPad, Apple Watch repairs)
- Cursor rules and skills for AI-assisted page generation
- A PixelPlus MCP server (`cscart-mcp-server/src/pixelplus.js`) for SEO rank tracking — see MCP Servers below
- Blog articles, calculators, and utility scripts

## MCP Servers

`.mcp.json` (repo root) registers one project-scoped server:

```json
"pixelplus": { "command": "node", "args": ["cscart-mcp-server/src/pixelplus.js"], "env": { "PIXELPLUS_API_TOKEN": "..." } }
```

- **`pixelplus` (project server, tools prefixed `mcp__pixelplus__*`)** — the only server actually wired to this repo. Talks to the PixelPlus SEO API (`https://tools.pixelplus.ru/projects/api/v1/`) for the iRepair project (`project_id = 63755`, domain `irepair.ru`). Tools: `pixelplus_get_project`, `pixelplus_get_groups`, `pixelplus_get_queries`, `pixelplus_add_queries`, `pixelplus_get_positions`, `pixelplus_get_updates`. Source: `cscart-mcp-server/src/pixelplus.js` (also duplicated at repo-root `pixelplus.js` — keep both in sync if edited, or remove the duplicate).
- **`pixelplus-mcp` (global, tools prefixed `mcp__pixelplus-mcp__*`)** — a *different* PixelPlus account (GOODMi/Maxmobiles), configured outside this repo. Do **not** use it for iRepair work — `project_id = 63755` will not resolve there. Always use the project-scoped `pixelplus` server for iRepair.
- **`wordstat-mcp` (global, tools prefixed `mcp__wordstat-mcp__*`)** — Yandex Wordstat keyword-frequency lookups (`wordstat_bulk`, `wordstat_top`, `wordstat_regions`, `wordstat_dynamics`), used by the `seo-service-meta-tags-builder-v2` skill. Configured globally, not in this repo's `.mcp.json`.

`cscart-mcp-server/` is otherwise a mostly-unused boilerplate: `src/index.js` (the `npm start` entry point, and the CS-Cart product/order/category tools described in `cscart-mcp-server/README.md`) is an empty stub, as are `src/wordstat.js`, `Dockerfile*`, `docker-compose.yml`, and `project.config.js`. Don't trust that README for current behavior — only `src/pixelplus.js` is real.

```bash
cd cscart-mcp-server
node src/pixelplus.js  # run the PixelPlus MCP server directly (normally launched by the MCP client via .mcp.json)
```

## HTML Page Generation Workflow

All HTML pages for OpenCart are **self-contained**: every page includes its own `<style>` block — no external CSS file.

### Page structure (strict order)
1. `<script type="application/ld+json">` — JSON-LD (LocalBusiness + WebPage + FAQPage)
2. `<style>` — full CSS for the page
3. HTML content inside `.mm-block`

### Before generating any HTML page — always ask:
> «Применить CSS дизайн-систему iRepair из `.cursor/rules/css-design-system.mdc`?»  
> «Нужны ли картинки для этой страницы?»

If images are needed, collect URLs first. Never leave `src="#"` placeholders.

This confirmation is enforced by an `alwaysApply: true` rule, `.cursor/rules/page-generation-hook.mdc` — skip asking only when the user already said "как обычно"/"в нашем стиле", pointed at an existing page as the template, or the task is editing (not creating) a page.

A second `alwaysApply: true` rule, `.cursor/rules/opencart-html-gutters-fix.mdc`, mandates stable side gutters on the root `.mm-block` (desktop `width: min(1300px, calc(100% - 48px))`; mobile `≤640px`: `calc(100% - 20px)`) with `box-sizing: border-box`, plus an `!important` guard block at the end of the document if the OpenCart theme overrides them. Don't leave duplicate guard blocks or duplicate `style` attributes on `.mm-block`.

### CSS isolation rule (critical)
Every CSS selector must start with `.mm-block` to avoid conflicts with OpenCart theme selectors (specificity (0,1,1)). Single-class selectors like `.mm-h2` lose to theme styles.

```css
/* Wrong */ .mm-h2 { font-size: 28px; }
/* Correct */ .mm-block .mm-h2 { font-size: 28px; }
```

This applies inside `@media` blocks too.

### Brand constants (never change)
- Brand name: `iRepair` (exactly — not IRepair or IREPAIR)
- Phone: `8 800 555-21-90` / `href="tel:+78005552190"`
- All visible phone numbers in HTML body: wrap in `<span class="phone_alloka">…</span>` (for call tracking). Phone in JSON-LD and `href` — no span.
- Address: `ул. Большая Садовая, д. 5, под. 2, этаж 1А, офис А25, Москва`
- Hours: ежедневно 10:00–20:00
- Telegram: `https://t.me/iRepair_Moscow_bot`
- Diagnostics: always free — use «Диагностика бесплатно» everywhere

### Prices — forbidden in HTML
Never include specific ruble amounts in HTML text or JSON-LD descriptions. Prices are managed via the OpenCart price list. Only `"priceRange": "&#8381;&#8381;"` is allowed in JSON-LD `LocalBusiness`.

### Mandatory HTML sections (in order)
1. **Intro** — H2 + `.mm-intro-text` lede (direct answer: who/what/where + time + warranty) + `.mm-stat-badge`
2. **Stat strip** — `.mm-stat-strip` with exactly 6 `.mm-stat-card.mm-glass` tiles
3. **Services** — `.mm-services-grid` with **exactly 3 or 6** `<article>` cards (4 or 5 are forbidden)
4. **Repair process** — 3 steps + optional `.mm-process-visual` (only if user provided image URLs)
5. **Advantages** — `.mm-features` grid
6. **Symptoms** — `.mm-symptoms` grid with 6–8 typical issues
7. **FAQ** — 4–6 questions in HTML (no microdata in HTML; FAQPage only in JSON-LD)
8. **Related links** — `.mm-related` button row (iPhone pages only, exclude current service)
9. **CTA** — dark `.mm-cta` block with two buttons

### Responsive breakpoints
- `≤1000px`: stat-strip → 2 columns
- `≤900px`: services/features → 2 columns, symptoms → 2 columns
- `≤640px`: all grids → 1 column (stat-strip stays 2), `.mm-container` padding `0 14px`, `.mm-block` border-radius `0`
- `≤380px`: stat-strip → 1 column

### Design palette
| Purpose | Value |
|---|---|
| Primary accent (green) | `#4AE580` |
| Secondary accent (teal) | `#20CCBE` |
| Button gradient | `linear-gradient(90deg, #4AE580, #20CCBE)` |
| Icon gradient | `linear-gradient(135deg, #4AE580, #20CCBE)` |
| Block background | `linear-gradient(160deg, #f4fff8, #edfafa, #f0f8ff, #f5fff6)` |
| Main text | `#2C2C2C` |
| Secondary text | `#555555` |
| CTA dark bg | `#2C2C2C` |
| `transform` on hover | **Forbidden** — causes Chrome overflow:hidden bug |

### Emoji — forbidden directly
Use HTML entities only: `&#x26A1;` (⚡), `&#x1F4F1;` (📱), `&#x2714;` (✔), `&#8381;` (₽), etc.

## SEO Meta Tags Standard (`seo--for-service-meta-tags.mdc`)

- `title`: `[Action] [Device/Part] [City] | iRepair`, 45–65 chars (up to 70 for Yandex)
- `meta description`: 180–250 chars, starts with the service (not with «iRepair» or «Мы»)
- H1: 15–55 chars, format `[Action] [Device] [Model/Part]`
- No `!`, no emojis, no `₽` amounts, no HTML in `content="..."` attributes
- First sentence of description = AEO pattern (direct answer in first 10 words, includes «Москва»)
- Both Cyrillic and Latin variants in description: «айфон»/«iPhone», «аккумулятор»/«батарея», «дисплей»/«экран»

## Blog Article Formatting

Use the **blogger** Cursor agent (`.cursor/agents/blogger.md`) or the rule `.cursor/rules/apple-blog-formatting-seo.mdc`:
- Wrapper: `<div class="apple-blog-container">` with isolated `<style>` inside
- Structure: `<article>` → `<header><h1>` → `<section>`
- Remove footnotes `[1]`, citation links, and inline `style=""` attributes from source text
- Never rewrite or shorten the original text — markup only

## Cursor Skills

| Skill | Purpose |
|---|---|
| `seo-service-page-builder` | Generates full SEO HTML page for a repair category |
| `seo-service-meta-tags-builder` | Generates H1/title/description/og tags (v1, SERP-heuristic only) |
| `seo-service-meta-tags-builder-v2` | v1 + Wordstat frequency-cluster keyword analysis (`mcp__wordstat-mcp__*`, region Москва=213), USP demand-filtering, neural-answer (Яндекс Нейро/AI Overviews) strategy, hub/model/repair-type cannibalization checks, and an optional final step that sends the resulting semantic core to PixelPlus (`mcp__pixelplus__pixelplus_add_queries`, `project_id = 63755`). Prefer this over v1 when Wordstat/PixelPlus MCP access is available. |
| `seo-service-page-workflow` | Overview of the page generation process |

Skills live in `.cursor/skills/`. There is also a Cursor **agent** (not a skill) at `.cursor/agents/blogger.md` — formats raw blog article text into the `apple-blog-formatting-seo.mdc` HTML structure without rewriting the source text.

## File Naming

- Main category block: `irepair-seo-block.html`
- Device model pages: `iphone-17-pro-max-repair.html`, `macbook-pro-repair.html`
- All output in `Категории/` subfolders: `iPhone/`, `MacBook/`, `iPad/`, `AppleWatch/` (each has a `Старые/старые` subfolder for superseded page versions — don't edit those, don't treat them as current)

## Repository Layout

- `Категории/` — the actual OpenCart HTML output (see File Naming above); `Категории/Страницы/` holds non-repair pages (contacts, company info, error page)
- `Блоги/`, `Калькуляторы/`, `Служебные страницы/` — blog articles, the iPhone repair-price calculator, and shared page fragments (e.g. footer variants)
- `Работа по СЕО/`, `SEO-план/` — working SEO docs (competitor analysis, growth/action plans, GSC/Wordstat data exports) — reference material, not page output
- `cscart-mcp-server/` — Node MCP servers, see MCP Servers below

These top-level folder names are Cyrillic — quote paths with the shell tools when scripting against them.

## Competitors (Moscow Apple services)

isupport.ru, kibercentre.ru, planetiphone.ru, apple-pro.ru, dabro.center — analyze their pages before generating content if the user provides competitor URLs.
