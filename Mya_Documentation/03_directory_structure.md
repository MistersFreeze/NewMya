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
