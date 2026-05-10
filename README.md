# New_Mya

Next-generation Mya layout: documentation-first, separated loaders, shared libs, and a Krokmou-style hub shell. Game logic stays **Luau**; loader/hub UI source can be authored in **TypeScript** under `packages/` and compiled with **roblox-ts** (see [Mya_Documentation/07_gui_loader.md](Mya_Documentation/07_gui_loader.md)).

## Read first

1. [Mya_Documentation/00_index.md](Mya_Documentation/00_index.md)
2. [Mya_Documentation/03_directory_structure.md](Mya_Documentation/03_directory_structure.md)
3. [Mya_Documentation/10_workflows.md](Mya_Documentation/10_workflows.md)

## Hosting paths

If your git root is `https://raw.githubusercontent.com/USER/REPO/BRANCH/`, set:

```lua
getgenv().MYA_BASE_URL = "https://raw.githubusercontent.com/USER/REPO/BRANCH/"
```

Then run:

```lua
loadstring(game:HttpGet(MYA_BASE_URL .. "New_Mya/loaders/loader.luau", true))()
```

The loader fetches `New_Mya/config/config.luau` and `New_Mya/loaders/hub.luau` relative to that root.

## Local injector flow

From repo root:

```bash
python -m http.server 8080
```

Inject:

```lua
getgenv().MYA_BASE_URL = "http://127.0.0.1:8080/"
loadstring(game:HttpGet("http://127.0.0.1:8080/New_Mya/loaders/loader.luau", true))()
```

This mirrors the legacy flow, but points to `New_Mya/loaders/loader.luau`.

## Build TypeScript hub (optional)

```bash
cd New_Mya/packages/loader-hub
npm install
npm run build
```

Compiled output is written to `packages/loader-hub/out/`. The **hosted** hub used by `loader.luau` is currently the Luau file `loaders/hub.luau` so a single `HttpGet` works everywhere. See docs for the TS/Luau split strategy.
"# NewMya" 
