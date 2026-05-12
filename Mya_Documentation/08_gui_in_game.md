# In-game GUI

Game modules must build control-panel UI with:

- Fluent Modded windows/tabs (same library used by loader and universal)

Gameplay overlays (ESP boxes, tracers, highlights) may still use dedicated Roblox instances or Drawing APIs as needed, but menu/config UI should remain Fluent Modded.

**Rule:** gameplay and state logic stay **Luau** under `New_Mya/games/`. For project consistency, use Fluent Modded for all game-script user-facing menus.

Document each game’s GUI approach in the game folder README or a short `CONTEXT.md` beside `init.luau`.

## Current in-game standards

- Default GUI/menu bind baseline is `Enum.KeyCode.RightShift`
- Bind must remain changeable from in-game GUI settings where supported
- In-game config systems should preserve user-selected menu bind values
- Operation One GUI persists window size/position to `MyaOperationOne/layout.json`
- Operation One config UI includes manual autoload selection via `mya_universal_configs/autoload.txt`
- Operation One silent aim has been removed from runtime load order and GUI controls
- Universal and game GUIs should preload saved interface settings before window creation to avoid one-frame default-theme/layout flashes
