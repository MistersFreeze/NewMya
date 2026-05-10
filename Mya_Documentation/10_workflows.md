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

## Local test

Set `MYA_LOCAL_ROOT` to your clone path; use `loader_local` pattern or HttpGet to `http://127.0.0.1:8080/` with repo root served.

## Documentation rule

Any new hook, flag, or package gets a row in [12_hooks_and_extensions.md](12_hooks_and_extensions.md) and a mention in `00_index.md` if it is user-facing.

## Current defaults snapshot

- Global/default GUI minimize bind baseline: `RightShift`
- In-game menu key defaults should map to `RightShift` and remain configurable unless explicitly locked by design
- Deprecated defaults (`Delete`, `LeftControl`) should not be used as startup defaults
