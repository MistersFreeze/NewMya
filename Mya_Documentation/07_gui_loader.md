# Loader and hub GUI

## Required library

`New_Mya` loader and universal shell must use **Fluent Modded UI Library**.

- Library source: `https://github.com/StyearX/Fluent-Modded`
- Runtime loading pattern: `loadstring(game:HttpGet(...))()`
- This is the canonical GUI approach for `loaders/hub.luau`

## Loader GUI policy

- Keep `loader.luau` minimal: fetch config, fetch hub, execute
- Main visible interface belongs in the Fluent window created by `hub.luau`
- Script-specific UIs should launch from Fluent tabs/buttons (for example, Scripts tab actions)

## Standard tab structure

Recommended baseline:

- `Main`
- `Games`
- `Scripts` (contains launchers such as Mya Universal)
- `Credits`
- `Settings` (Save/Interface/Floating manager sections)

## Default bind policy

- Default menu/minimize key is `RightShift`
- `Delete` and `LeftControl` are not default binds
- Keybind remains user-changeable via Fluent interface settings

## Performance guidance

- Prefer `Acrylic = false` on lower-end environments for smoother drag
- Avoid unnecessary extra ScreenGuis layered over Fluent
- Keep heavy logic out of per-frame UI callbacks

## UI copy rules

Follow [11_critical_constraints.md](11_critical_constraints.md): no parenthetical asides in user-facing strings; keep labels short.

## Files

- Fluent shell implementation: [../loaders/hub.luau](../loaders/hub.luau)
