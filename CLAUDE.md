# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the content and SEO workspace for **iRepair** (irepair.ru) — an Apple repair service center in Moscow. The repo contains:

- SEO HTML pages for OpenCart categories (iPhone, MacBook, iPad, Apple Watch repairs)
- Cursor rules and skills for AI-assisted page generation
- A CS-Cart MCP server (`cscart-mcp-server/`) — Node.js MCP server, run with `npm start`
- Blog articles, calculators, and utility scripts

## MCP Server (`cscart-mcp-server/`)

```bash
cd cscart-mcp-server
npm start          # runs src/index.js
node src/pixelplus.js  # pixelplus integration
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
| `seo-service-meta-tags-builder` | Generates H1/title/description/og tags |
| `seo-service-page-workflow` | Overview of the page generation process |

Skills live in `.cursor/skills/`.

## File Naming

- Main category block: `irepair-seo-block.html`
- Device model pages: `iphone-17-pro-max-repair.html`, `macbook-pro-repair.html`
- All output in `Категории/` subfolders: `iPhone/`, `MacBook/`, `iPad/`, `AppleWatch/`

## Competitors (Moscow Apple services)

isupport.ru, kibercentre.ru, planetiphone.ru, apple-pro.ru, dabro.center — analyze their pages before generating content if the user provides competitor URLs.
