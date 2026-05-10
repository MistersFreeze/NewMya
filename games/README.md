# games

Per-experience modules. Each exports a table with `mount(ctx)` and optionally `unmount`.

Convention: `New_Mya/games/<Name>_<PlaceId>/init.luau` or single-file `New_Mya/games/example.luau`.

Register PlaceIds in `New_Mya/config/config.luau` under `SUPPORTED_GAMES` with paths relative to **repository root** (include `New_Mya/games/...` prefix).

Current active mappings are maintained only in `config/config.luau` (for example, Operation One and Aftermath at time of writing). Removed game modules should not remain in `SUPPORTED_GAMES`.
