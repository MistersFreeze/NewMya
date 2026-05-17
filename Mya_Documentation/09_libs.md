# Libraries

## `lib/widgets.luau`

Shared draggable overlay widget factory. Extracted from `universal/Visuals/Watermark.luau` and `KeybindDisplay.luau`.

**Public API**

| Export | Purpose |
|--------|---------|
| `newThemeSync(Fluent)` | Live accent/text/muted color provider; hooks `SetTheme`; supports RGB mode |
| `newOverlayFrame(opts)` | Draggable ScreenGui frame with position + scale persistence (`{x,y,scale}` → posFile) |
| `newWatermark(opts)` | Watermark overlay: Mya · username · game · injector · FPS · ping |
| `newKeybindDisplay(opts)` | Keybind list: shows `[KEY] Feature` rows, accent = active / muted = inactive |

**`newOverlayFrame` opts:** `name, displayOrder, defaultX, defaultY, posFile, Fluent, UIS, textSize, minWidth, padL, padR, padT, padB, accentColor, textAlign`

**Resize behavior:** A 22×22 `TextButton` (clipping arc) sits at the widget's inner bottom-right corner. Drag it diagonally to scale via `UIScale` (0.4 × – 3.0 ×). Position and scale are persisted to `posFile` as `{x,y,scale}`. The arc stroke is invisible by default; appears as a subtle white arc only on hover.

**Performance notes**
- Heartbeat position update skips if `frame.AbsolutePosition/Size` is unchanged (no per-frame write when static)
- `newThemeSync` hooks `Fluent.SetTheme` so color cache updates automatically on theme change

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

**Current registered libs:**
- `lib/util.luau` — HTTP, loadstring, module loader
- `lib/ui.luau` — legacy helper layer
- `lib/FluentModded.lua` — primary UI runtime
- `lib/analytics.luau` — Discord webhook logging
- `lib/widgets.luau` — overlay widget factory (Watermark, KeybindDisplay, ThemeSync)
