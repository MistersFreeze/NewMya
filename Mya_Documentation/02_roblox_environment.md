# Roblox executor environment

New_Mya assumes a **client** context: `Players.LocalPlayer`, UI under `PlayerGui` or `CoreGui` / `gethui()`, and **`game:HttpGet`** for modular loading.

## Core services

- `game:GetService("Players")`
- `game:HttpGet(url, true)`
- `game:GetService("UserInputService")` — input, dragging
- `game:GetService("TweenService")` — optional UI motion
- Other services as needed per game module

## Executor capabilities

| Capability | Role |
|------------|------|
| `loadstring` | Required for loader, hub, and remote modules |
| `getgenv` | `MYA_BASE_URL`, `MYA_LOCAL_ROOT`, feature flags |
| `readfile` | Optional: local dev when URL maps under `MYA_LOCAL_ROOT` |
| `gethui` | Optional: place loader/hub above default stacking |

## Local development

Set `getgenv().MYA_LOCAL_ROOT` to your cloned repo path with trailing slash. `Util.httpGet` in `New_Mya/lib/util.luau` resolves matching URLs via `readfile` when available.
