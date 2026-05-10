# Libraries

## `lib/util.luau`

- `httpGet(url)` — local `readfile` when URL is under `MYA_LOCAL_ROOT`, else `game:HttpGet`
- `loadstringCompile(source, chunkName)` — BOM strip, HTML guard, `loadstring`
- `loadModuleFromUrl(url, chunkName)` — fetch, compile, run once, return module table
- `loaderScreenGuiParent()`, `configureLoaderScreenGui(gui)` — loader error UI placement

## `lib/ui.luau`

Legacy helper layer for manual UI construction. The default loader/universal GUI should use Fluent Modded instead.

## `lib/FluentModded.lua`

Primary UI runtime used by loader, universal, and in-game Fluent surfaces.

- Default `MinimizeKey` and `InterfaceManager` menu keybind are `RightShift`
- Includes save/autoload helpers (`SaveManager`, `FloatingButtonManager`)
- Includes colorpicker rainbow persistence (`rainbow` saved/loaded with color data)
- Colorpicker interaction is patched for robust drag/click behavior in executor-variant environments

## `lib/analytics.luau`

- `sendLog(webhookUrl, type, extraInfo)` — Gathers user, game, executor, HWID, and geolocation info, sending it to the specified Discord webhook as a rich embed.

## Future

Combat helpers, game shell, and modern card UI can be added as separate files under `lib/` and documented here.
