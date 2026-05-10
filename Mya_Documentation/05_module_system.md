# Module system

## Routing

`config.luau` → `SUPPORTED_GAMES` maps `game.PlaceId` to a **path string** under the repo root, for example:

```lua
[123456789] = "New_Mya/games/MyGame_123456789/init.luau"
```

Universal-style modules can be launched from hub UI by URL without PlaceId registration.

## Contract

Returned module table:

| Member | Required | Purpose |
|--------|----------|-----------|
| `mount(ctx)` | Yes | Activate module |
| `unmount` | Recommended | Cleanup |

## Context `ctx`

Hub supplies at least:

- `baseUrl` — hosted root with slash
- `notify(msg)` — status line
- `theme` — from config
- `uiFactory` — from `lib/ui.luau`
- `panel` — Games tab host frame when applicable
- `getPlaceId` — function
- `gameScriptPath` — config path for this module

## File extension

Prefer **`.luau`** for new files; executors treat it like Lua when served as text.
