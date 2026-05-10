# loader-hub

TypeScript sources for the Krokmou-style hub shell. Roblox runs Luau only; this package compiles to `out/` via [roblox-ts](https://roblox-ts.com/).

## Build

```bash
npm install
npm run build
```

Flags: `--type package` emits a library tree; `--luau` writes `.luau` files.

## Output layout

| Path | Role |
|------|------|
| `out/init.luau` | Package entry; re-exports `mountKrokmouShell` |
| `out/components/*.luau` | Header, tabs, grid, cards, bottom nav, `App` |
| `out/theme.luau` | Theme tokens |

The hosted single-file loader remains [../../loaders/hub.luau](../../loaders/hub.luau) until multi-file fetch or bundling is standardized.

## Usage sketch

From a Luau entry that already has the compiled files available via `require` (e.g. Rojo tree):

```lua
local hub = require(path.to.out.init)
hub.mountKrokmouShell(parentFrame, { brand = "Mya Client", version = "1.0.0" })
```

`parentFrame` should live under a `ScreenGui`. Theme overrides: optional third field `theme` with `HubTheme` fields from `theme.ts`.
