# Directory structure

```
New_Mya/
├── Mya_Documentation/     # This doc set
├── README.md
├── config/
│   └── config.luau       # Branding, THEME, SUPPORTED_GAMES, flags
├── loaders/
│   ├── loader.luau       # Entry: fetch config + hub
│   └── hub.luau          # return function(BASE_URL, config) — Fluent Modded UI shell
├── lib/
│   ├── util.luau
│   ├── ui.luau
│   └── analytics.luau
├── games/                  # Per-game modules (Luau)
├── universal/              # Optional global tools
├── packages/               # Optional non-runtime tooling (not required for loader UI)
└── scripts/                # Dev helpers
```

## Hosted paths

With repo root = `BASE_URL`:

- `New_Mya/loaders/loader.luau`
- `New_Mya/config/config.luau`
- `New_Mya/loaders/hub.luau`
- `New_Mya/lib/util.luau`
- `New_Mya/lib/ui.luau`
- `New_Mya/lib/analytics.luau`
- `New_Mya/games/...`

## Naming games

Use `ReadableName_PlaceId` folders with `init.luau` when multi-file.

### Multi-File Modular Layout Example (Bloodlines)

For complex games, structure the folder to isolate functional areas into domain subdirectories:

```
New_Mya/games/Bloodlines_10266164381/
├── init.luau             # Entry point (conforms to mount/unmount contract)
├── Visuals/
│   └── Esp.luau          # Render loops, character filters, environment toggles
├── Movement/
│   └── LocalPlayer.luau  # WalkSpeed, JumpPower, Fly, Noclip connections
├── Player/
│   └── Combat.luau       # Resource caches (Stamina/Chakra), NoFall, NoCooldown, NoStun
├── Teleport/
│   └── Waypoints.luau    # Scanning logic, players/stands/merchants dropdowns, auto-TP
├── AutoFarm/
│   └── SafeSpot.luau     # PERSISTENT coordinate capturing and proximity loops
└── Misc/
    ├── ChakraSense.luau  # Warning UI drawing, overlays (Users Widget), staff check
    └── StreamerMode.luau # Local name/GUI text replacement hooks
```
