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

## Designing Modular Game Scripts (Multi-File Pattern)

For high-complexity games, monolithic modules quickly become unmaintainable. Follow the **Bloodlines Modular Standard**:

### 1. The Dynamic Entry Bootstrapper (`init.luau`)
The entry point serves as the controller that creates the UI Window, defines tabs, registers shared services/connections, and mounts domain sub-modules:
- **Contract**: Must return a table exporting `mount(ctx)` and `unmount()`.
- **Context Injection**:
  ```lua
  local module = {}
  function module.mount(ctx)
      -- Extract loader variables
      local BASE_URL = ctx.baseUrl
      local Fluent = ctx.Fluent
      local SaveManager = ctx.SaveManager
      local InterfaceManager = ctx.InterfaceManager
      
      -- Create Tabs
      local visualsTab = Window:AddTab({ Title = "Visuals", Icon = "solar/eye-bold" })
      
      -- Inject into sub-module context
      local subCtx = {
          visualsTab = visualsTab,
          Fluent = Fluent,
          baseUrl = BASE_URL,
          Players = game:GetService("Players"),
          -- Other shared variables...
      }
      
      -- Fetch and load sub-modules
      local path = "New_Mya/games/MyGame_PlaceId/Visuals/Esp.luau"
      local src = fetchModule(path)
      local fn = loadstring(src, "@" .. path)()
      local inst = fn(subCtx) -- Returns update/unmount hook
  end
  return module
  ```

### 2. Dependency Injection Contract for Sub-Modules
Sub-modules inside subfolders must be decoupled, functional files:
- **Export contract**: Must return a function accepting `subCtx` and returning an instantiation table: `{ update = function(dt), unmount = function() }`.
- **Connections & Cleanup**: Never register listeners directly to global state without tracking them. Store all connection references locally inside the submodule closure, and cleanly disconnect every listener inside `unmount()`.

### 3. Local/World Teleport Standards
- **Weapons/Armor Stands**: Deduplicate targets in the workspace by position rather than relying on exact parent folders. Ensure search parameters exclude "Ascended" or highly privileged targets if specified.
- **Village/Area Context**: Scrape ancestors to prefix generic workspace objects (e.g. "Merchant") with their regional context (e.g. "Sorythia Merchant") to prevent list ambiguity.


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

---

## Overlay widget workflow (`lib/widgets.luau`)

### Loading
```lua
local src = game:HttpGet(ctx.baseUrl .. "New_Mya/lib/widgets.luau", true)
local widgets = loadstring(src, "@widgets")()
local ts  = widgets.newThemeSync(Fluent)
local wm  = widgets.newWatermark({ Fluent=Fluent, UIS=UIS, themeSync=ts, tab=MiscTab, folder="MyaGame" })
local kbd = widgets.newKeybindDisplay({ Fluent=Fluent, UIS=UIS, themeSync=ts, tab=MiscTab,
                                        folder="MyaGame", bindRegistry=bindRegistry })
```

### bindRegistry contract
Each entry must supply: `displayName`, `getKey()→string|nil`, `getMode()→string`, `isActive()→bool`.
- `getKey()` must read from `Fluent.Options[id].Value` (Fluent Modded stores the key string there, not in `.Key`).
- Return `nil` from `getKey()` to hide the entry from the display.

### Widget sections placement
Put Watermark and Keybind Display sections in the **Misc** tab, not Visuals.

### Resize / position persistence
- Both position `{x,y}` and scale `{scale}` are saved to `posFile` as a single JSON object.
- Resize is triggered by dragging the bottom-right arc handle (22×22 TextButton).
- `UIScale` on the frame controls visual size (0.4 × – 3.0 ×). The arc stroke is white, invisible until hover.

### Update loop
```lua
_active.widgetConn = RunService.RenderStepped:Connect(function()
    if _active.watermark      then pcall(_active.watermark.update)      end
    if _active.keybindDisplay then pcall(_active.keybindDisplay.update) end
    pcall(updateUsersWidget)
end)
```

---

## Bloodlines game script — registered features (PlaceId 10266164381)

### Tab structure
Visuals · Movement · Player · Teleport · Misc · Config · Settings

### Visuals
- Player ESP (box, name, distance, health bar, max dist 3000)
- NPC ESP (dialog NPCs, color, max dist 5000)
- Mob ESP (combat enemies, health bar, color, max dist 5000)
- Environment: Remove Fog, Remove Rain, Fullbright

### Movement
- Fly (keybind + button, speed slider)
- Noclip (keybind + button) — parts cached on `CharacterAdded`
- Walk Speed (keybind + button, slider 16–500)
- Jump Power (keybind + button, slider 50–500)

### Player
- No Fall Damage (toggle + keybind, synced)
- Remove M1 Cooldown (toggle, uses `getgc()`)
- No Stun (toggle, watches `Settings.Stunned`)
- Infinite Stamina (toggle, cached `NumberValue` write on Heartbeat)
- Infinite Chakra (toggle, cached `NumberValue` write on Heartbeat)

### Teleport
- Chakra Points — scans `workspace.ChakraPoints`, reads `PointName` StringValue
- Merchants — all "Merchant"/"Food Merchant"/"Chef"/"InnKeeper" NPCs, prefixed with village ancestor name
- NPCs — all NPC-tagged workspace models, deduped by name
- Players — live dropdown + Refresh + Teleport button

### Misc (overlays)
- Watermark (via `lib/widgets.luau`)
- Keybind Display (via `lib/widgets.luau`)
- Users widget — nearest player + CS Users + Sensing, updates at 0.3 s
- Streamer Mode — replaces `Humanoid.DisplayName` with "Mya Script"

### Chakra Sense notification
Three-layer detection: `DataEvent.OnClientEvent`, `Settings.Stunned` BoolValue watcher, Heartbeat poll of `getCSCounts()` (fires when active count goes 0 → positive). 3-second debounce.

### CS counts (`getCSCounts`)
- Tries character-based scan, PlayerGui scraping, async chunked workspace scan (150 objs/frame).
- Result cached for 2 s. Event-driven: after the async scan, connects `GetPropertyChangedSignal("Text")` to any TextLabel containing "people with chakra" or "active chakra" — updates cache instantly when the game changes the number, and pushes the TTL 30 s into the future.

### Performance notes
- Noclip: character `BasePart` list cached on spawn → Stepped loop has no `GetDescendants` call.
- Infinite Stamina/Chakra: `NumberValue` + cap cached on spawn → Heartbeat loop is O(n cached values).
- Widget Heartbeat position: skipped when `AbsolutePosition`/`AbsoluteSize` unchanged.
- Workspace CS scan: single run at startup, yielding every 150 objects to prevent frame spikes.
