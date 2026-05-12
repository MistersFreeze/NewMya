# Hooks and extensions

Index of extension points. Expand rows as features land.

| Name | Location | Purpose |
|------|----------|---------|
| `MYA_BASE_URL` | `getgenv()` | Overrides loader base URL |
| `MYA_LOCAL_ROOT` | `getgenv()` | Enables `readfile` for local dev in `Util.httpGet` |
| `MYA_AUTOLOAD_GAME_MODULE` | config / `getgenv()` | Planned: mirror legacy autoload behavior when hub gains full Games tab |
| Hub `notify` | `ctx.notify` | Status line updates for modules |
| `_G.MYA_UNIVERSAL_SYNC_UI` | Universal modules | Optional UI refresh hook when used from migrated games |
| `_G.unload_new_mya` | global | Centralized full unload entrypoint for New_Mya |
| `MenuKeybind` (`InterfaceManager`) | Fluent settings | User-changeable minimize/show keybind; default is `RightShift` |
| `MyaOperationOne/layout.json` | Operation One local file | Persists Fluent window size/position |
| `mya_universal_configs/autoload.txt` | Operation One local file | Stores selected autoload profile name for manual autoload |
| `MYA_PREFETCH_FLUENT_SRC` | `getgenv()` | Loader-prefetched Fluent source reused by hub/game/universal windows |

| `ANON_ANALYTICS_ENABLED` | `config.luau` | Global toggle for Discord execution logging |
| `ANON_ANALYTICS_WEBHOOK_URL` | `config.luau` | Discord webhook URL for logging |

## Planned

- Junkie-specific loader under `loaders/`
- Game card actions wired to `Util.loadModuleFromUrl`
