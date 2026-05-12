# Critical constraints

## Platform and legal

Automating gameplay in experiences you do not own may violate [Roblox Terms of Use](https://en.help.roblox.com/hc/en-us/articles/203625345). Treat New_Mya as high-risk; maintainers and users are responsible for compliance.

## URLs and hosting

- `BASE_URL` / `MYA_BASE_URL` must resolve to the folder that contains `New_Mya/` when using the paths in this tree.
- Config paths are **HTTP suffixes**, not local disk paths at runtime.

## Secrets

Never commit live keys. Use gitignored local files or executor-specific secret storage.

## Executor variance

Without `loadstring`, nothing loads. Features that need `readfile`, `writefile`, or `gethui` degrade gracefully when documented.

## Default keybind — RightShift only

- Every window (`CreateWindow`) must set `MinimizeKey = Enum.KeyCode.RightShift`.
- Before calling `InterfaceManager:LoadSettings()`, patch `<Folder>/options.json` on disk to set `MenuKeybind = "RightShift"` so a previously saved "Delete" or "LeftControl" is never restored.
- After `LoadSettings`, also force `InterfaceManager.Settings.MenuKeybind = "RightShift"` in memory.
- After `BuildInterfaceSection`, call `Fluent.MinimizeKeybind:SetValue("RightShift")` and `InterfaceManager:SaveSettings()` to lock the live widget and persist the correct value.
- Users may change the bind from the Settings tab. The above steps only run at load time and write the file once; a user-selected bind set via the Settings tab is saved and respected on subsequent loads — but the next fresh load will reset it to RightShift again by design.
- **Never** use `Delete` or `LeftControl` as a default bind anywhere in the codebase.

## User-facing copy

No parenthetical asides in hub labels, toasts, or hints. Avoid long explanatory blocks unless explicitly requested.
