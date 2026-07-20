Follow the skill at `.cursor/skills/seo-service-meta-tags-builder-v2/SKILL.md` exactly.

Before starting, load every MCP tool this skill can call, in one batch:

ToolSearch with query "select:mcp__wordstat-mcp__wordstat_bulk,mcp__wordstat-mcp__wordstat_top,mcp__wordstat-mcp__wordstat_regions,mcp__wordstat-mcp__wordstat_dynamics,mcp__pixelplus__pixelplus_get_project,mcp__pixelplus__pixelplus_get_groups,mcp__pixelplus__pixelplus_get_queries,mcp__pixelplus__pixelplus_add_queries,mcp__pixelplus__pixelplus_get_positions,mcp__pixelplus__pixelplus_get_updates"

Use the project-scoped `mcp__pixelplus__*` tools only (project_id = 63755, iRepair) — never `mcp__pixelplus-mcp__*` (a different account, GOODMi/Maxmobiles).

Execute the full workflow (Steps 1–7, including Step 2b-Wordstat, Step 2d if the neural-answer flag applies, and Step 6a/6b) for the page described by the user: $ARGUMENTS

If no page is specified in $ARGUMENTS, ask the user: «Для какой страницы генерировать метатеги? Укажите устройство и тип услуги, например: "Замена аккумулятора iPhone 16 Pro"»
