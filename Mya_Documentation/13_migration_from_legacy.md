# Migration from legacy Mya tree

Legacy files live at repo root: `loader.lua`, `hub.lua`, `config.lua`, `lib/`, `games/`, `PROJECT CONTEXT/`.

| Legacy | New_Mya |
|--------|---------|
| `loader.lua` | `New_Mya/loaders/loader.luau` |
| `hub.lua` | `New_Mya/loaders/hub.luau` (Fluent Modded shell) |
| `config.lua` | `New_Mya/config/config.luau` |
| `lib/*` | `New_Mya/lib/*` |
| `games/*` | `New_Mya/games/*` copy or symlink during migration |
| `PROJECT CONTEXT/` | `New_Mya/Mya_Documentation/` |

`SUPPORTED_GAMES` values must gain the `New_Mya/games/...` prefix when switching hosts.

You can run **both** trees during transition by pointing different `BASE_URL` branches or paths.
