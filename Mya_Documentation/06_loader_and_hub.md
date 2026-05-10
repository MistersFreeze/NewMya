# Loader and hub

## Bootstrap

`loader.luau` waits for `game.Loaded` and a non-zero `PlaceId` when possible, then:

1. HttpGets `New_Mya/config/config.luau`
2. HttpGets `New_Mya/loaders/hub.luau`
3. Invokes `hubMain(BASE_URL, config)` to open the Fluent Modded window

## Hub responsibilities

- Initialize **Fluent Modded UI Library** as the standard shell
- Provide tabs for main actions, game module launch, universal scripts, credits, and settings
- Keep launcher responsibilities lightweight; heavy feature UI should be launched as separate scripts/modules
- Use `Enum.KeyCode.RightShift` as the default minimize/show bind for hub windows
- Keep menu bind user-changeable through Fluent `InterfaceManager` settings (`MenuKeybind`)

## Environment overrides

- `getgenv().MYA_BASE_URL` overrides baked-in `BASE_URL` in `loader.luau`
- `getgenv().MYA_LOCAL_ROOT` enables `readfile` for matching URLs in `Util.httpGet`

## Display order

Fluent handles top-level window rendering; additional custom ScreenGui layers should only be used for dedicated tools that are separate from the main Fluent shell.

## Unload behavior

- Hub-level unload is centralized through `_G.unload_new_mya`
- Unload flow is guarded to avoid recursive freeze loops
- Close-confirm "Yes" in Fluent routes to full Mya teardown (UI, hooks, and Mya-named leftovers across common containers)
