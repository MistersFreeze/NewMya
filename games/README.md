# games

Per-experience modules. Each exports a table with `mount(ctx)` and optionally `unmount`.

Convention: `New_Mya/games/<Name>_<PlaceId>/init.luau` or single-file `New_Mya/games/example.luau`.

Register PlaceIds in `New_Mya/config/config.luau` under `SUPPORTED_GAMES` with paths relative to **repository root** (include `New_Mya/games/...` prefix).

Current active mappings in `config/config.luau` `SUPPORTED_GAMES`:

| Game | PlaceId(s) | Folder |
|------|-----------|--------|
| Aftermath | 112237800564065 | Aftermath_112237800564065 |
| Operation One | 72920620366355 | Operation-One_72920620366355 |
| Prison Life | 155615604 | PrisonLife_155615604 |
| Apocalypse Rising 2 | 863266079, 93911318070665 | ApocalypseRising2_863266079 |
| Booga Booga | 11729688377 | BoogaBooga_11729688377 |
| Bite By Night | 70845479499574 | BiteByNight_70845479499574 |
| Flex Your FPS | 18667984660 | FlexYourFPS_18667984660 |
| MicUp / Corner | 15546218972, 112399855119586 | MicUp_15546218972 |
| Neighbors | 110400717151509, 12699642568 | Neighbors_110400717151509 |
| Project Delta | 7353845952, 7336302630 | ProjectDelta_7353845952 |
| Desolate Valley | 11574110446 | DesolateValley_11574110446 |
| Secours De France RP | 8392374718 | SecoursDeFranceRP_8392374718 |
| Violence District | 93978595733734 | ViolenceDistrict_93978595733734 |

Removed game modules should not remain in `SUPPORTED_GAMES`.

**Mya Universal** (hub “Launch Mya Universal”) loads the modular bundle under `New_Mya/games/MyaUniversal/` (`init.lua`, `config.lua`, `runtime.lua`, `runtime/*.lua`, `gui.lua`, `GUI/*`), bootstrapped by `New_Mya/universal/mya_universal.luau`; it does not require a PlaceId entry in `SUPPORTED_GAMES`.
