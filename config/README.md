# config

`config.luau` returns branding, `THEME`, `SUPPORTED_GAMES`, and hub flags. It is fetched as `BASE_URL .. "New_Mya/config/config.luau"`.

Notable behavior tied to current config and runtime:

- `AUTOLOAD_GAME_MODULE` controls PlaceId-based module autoload from `SUPPORTED_GAMES`
- `SUPPORTED_GAMES` should only contain currently shipped modules (removed games must be removed from this map)
- GUI bind defaults are enforced in runtime/UI layers (current default baseline is `RightShift`)
