# lib

Shared Luau modules fetched by the hub or games.

| File | Role |
|------|------|
| `FluentModded.lua` | Patched **Fluent Modded** UI library (sliders, color picker input); hub/games load this first, then GitHub fallback |
| `util.luau` | HttpGet, local `readfile` via `MYA_LOCAL_ROOT`, `loadstringCompile`, `loadModuleFromUrl`, loader ScreenGui helpers |
| `ui.luau` | Themed UI factory `return function(theme)` for hub content |

Paths under host: `New_Mya/lib/<file>`.
