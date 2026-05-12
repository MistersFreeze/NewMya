# Loader and hub

## Bootstrap

`loader.luau` waits for `game.Loaded` and a non-zero `PlaceId` when possible, then:

1. HttpGets `New_Mya/config/config.luau`
2. HttpGets `New_Mya/loaders/hub.luau`
3. Prefetches `New_Mya/lib/FluentModded.lua` in parallel and stores it in `getgenv().MYA_PREFETCH_FLUENT_SRC`
4. Invokes `hubMain(BASE_URL, config)` to open the Fluent Modded window

## Mya Universal (hub script)

From **Scripts → Launch Mya Universal**, the hub runs `New_Mya/universal/mya_universal.luau`, which fetches `New_Mya/games/MyaUniversal/init.lua` (with the same URL variants as other game modules) and mounts the full bundle: `config.lua`, `runtime.lua` (concatenates `runtime/*.lua` plus `lib/mya_combat_helpers.lua`), then `gui.lua` / `GUI/*`. Failures fall back to the small in-hub Fluent placeholder if the bootstrap file is missing.

## Hub responsibilities

- Initialize **Fluent Modded UI Library** as the standard shell
- Provide tabs for main actions, game module launch, universal scripts, credits, and settings
- Keep launcher responsibilities lightweight; heavy feature UI should be launched as separate scripts/modules
- Use `Enum.KeyCode.RightShift` as the default minimize/show bind for hub windows
- Keep menu bind user-changeable through Fluent `InterfaceManager` settings (`MenuKeybind`)
- Preload saved interface settings before `CreateWindow` and reveal GUI only after first-paint sync to avoid default-theme flash

## Environment overrides

- `getgenv().MYA_BASE_URL` overrides baked-in `BASE_URL` in `loader.luau`
- `getgenv().MYA_LOCAL_ROOT` enables `readfile` for matching URLs in `Util.httpGet`

## Display order

Fluent handles top-level window rendering; additional custom ScreenGui layers should only be used for dedicated tools that are separate from the main Fluent shell.

## Unload behavior

- Hub-level unload is centralized through `_G.unload_new_mya`
- Unload flow is guarded to avoid recursive freeze loops
- Close-confirm "Yes" in Fluent routes to full Mya teardown (UI, hooks, and Mya-named leftovers across common containers)
