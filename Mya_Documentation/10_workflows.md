# Workflows

## Host files

1. Push repo with `New_Mya/` visible on the raw host.
2. Set `MYA_BASE_URL` to repo root with trailing `/`.
3. Run `loadstring(game:HttpGet(MYA_BASE_URL .. "New_Mya/loaders/loader.luau", true))()`.

## Add a game

1. Create `New_Mya/games/MyGame_<PlaceId>/init.luau` with `mount`/`unmount`.
2. Add `[PlaceId] = "New_Mya/games/..."` to `config.luau` → `SUPPORTED_GAMES`.
3. Add display name map in hub if you maintain one.
4. Update this documentation set if routing or contracts change.

If a game module is removed, also remove its `SUPPORTED_GAMES` entry and any docs mentions in the same change.

## GUI workflow standard

1. Keep `loaders/hub.luau` on Fluent Modded as the canonical shell.
2. Add new launcher actions under Fluent tabs (`Main`, `Games`, `Scripts`, `Credits`, `Settings`).
3. If a feature needs a separate interface, launch it from the `Scripts` tab rather than replacing the shell.

## New game script UI rules (mandatory)

Every new game script under `New_Mya/games/` or `New_Mya/universal/` **must** follow these rules:

### UI library
- Use **Fluent Modded** exclusively. No custom shell implementations.
- Load via `MYA_PREFETCH_FLUENT_SRC` prefetch → fallback to `lib/FluentModded.lua` → fallback to upstream URL.

### Theme and interface settings
- Always call `InterfaceManager:SetFolder("MyaYourName")` and `InterfaceManager:LoadSettings()` before `CreateWindow`.
- Apply saved theme/font/transparency in a `task.defer` after window creation.
- Add `InterfaceManager:BuildInterfaceSection(settingsTab)` so users can change theme.

### Window size / layout persistence
- Read `"MyaYourName/layout.json"` with `readfile` before `CreateWindow`; apply saved `sx`/`sy` as the `Size` offset if ≥ 400×300.
- Save the window's `AbsoluteSize` to `layout.json` with `writefile` on both unload and on a periodic heartbeat (every ~10 s).
- Use `HttpService:JSONEncode/JSONDecode` for the file format: `{ sx = w, sy = h }`.
- Guard all `readfile`/`writefile` calls — not all executors support them.

### Default keybind
- `MinimizeKey = Enum.KeyCode.RightShift` on `CreateWindow`.
- Add `MenuKeybind` via `InterfaceManager:BuildInterfaceSection` so users can change it.

### Tab and section structure (mandatory)

Every window **must** organize its UI as: **one tab per category → one section per feature**. This mirrors how Visuals and Combat are structured in the Universal.

**Tab layout rules:**
- Each major category (Visuals, Combat, Movement, Config, Settings) is a top-level tab with `Window:AddTab({ Title = "...", Icon = "solar/..." })`.
- Never put unrelated features in the same tab.
- Always include a dedicated **Config** tab (`Window:AddTab({ Title = "Config", Icon = "solar/diskette-bold" })`) with `SaveManager:BuildConfigSection(configTab)` and a brief instruction paragraph above it.
- Always include a **Settings** tab with `InterfaceManager:BuildInterfaceSection(settingsTab)`.

**Section layout rules:**
- Each feature gets its own section: `tab:AddSection("Feature Name")`.
- The first element in every feature section **must** be the enable toggle or `makeBind` call, with an `Icon` matching the feature (e.g. `"solar/eye-bold"` for ESP, `"solar/wind-bold"` for Fly).
- Section order within a tab should go from most-used to least-used.
- Fluent does not have a `AddFolder` element — sections are the correct grouping primitive.

**Config tab template:**
```lua
local cfgInfoSec = configTab:AddSection("Configs")
cfgInfoSec:AddParagraph({
    Title   = "How to use",
    Content = "Type a name → Create config.\nSelect → Load config.\nSet as autoload for auto-apply.",
})
SaveManager:BuildConfigSection(configTab)
```

## Local test

Set `MYA_LOCAL_ROOT` to your clone path; use `loader_local` pattern or HttpGet to `http://127.0.0.1:8080/` with repo root served.

## Documentation rule

Any new hook, flag, or package gets a row in [12_hooks_and_extensions.md](12_hooks_and_extensions.md) and a mention in `00_index.md` if it is user-facing.

## Current defaults snapshot

- Global/default GUI minimize bind baseline: `RightShift`
- In-game menu key defaults should map to `RightShift` and remain configurable unless explicitly locked by design
- Deprecated defaults (`Delete`, `LeftControl`) should not be used as startup defaults
