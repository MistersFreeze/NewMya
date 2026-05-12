# loaders

Entry scripts executed by the executor.

| File | Role |
|------|------|
| `loader.luau` | HttpGets `config` + `hub`, shows bootstrap errors |
| `hub.luau` | Returns `function(BASE_URL, config)`; builds Krokmou-style hub UI |
| `loader_jnkie.luau` | Junkie bridge: sets env and fetches `loader.luau` |

Hosted URLs are `BASE_URL .. "New_Mya/loaders/<file>"` when the repo root is the host root.

## Local dev injection

Serve `New_Mya` folder:

```bash
python -m http.server 8080
```

Inject:

```lua
getgenv().MYA_BASE_URL = "http://127.0.0.1:8080/"
loadstring(game:HttpGet("http://127.0.0.1:8080/loaders/loader.luau", true))()
```

## Public injection

If hosted on GitHub raw:

```lua
getgenv().MYA_BASE_URL = "https://raw.githubusercontent.com/USER/REPO/BRANCH/"
loadstring(game:HttpGet(getgenv().MYA_BASE_URL .. "New_Mya/loaders/loader.luau", true))()
```

For Junkie products, upload `loader_jnkie.luau` as the product script, then run your Junkie CDN URL.
