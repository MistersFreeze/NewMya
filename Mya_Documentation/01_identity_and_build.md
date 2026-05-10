# Identity and build

## What New_Mya is

**New_Mya** is a reorganized **executor-oriented Roblox script distribution** under `New_Mya/`: loaders, hub, shared libs, games, and documentation. It follows the same runtime model as the legacy Mya tree: **static HTTP hosting** and **`loadstring` + `game:HttpGet`**.

There is **no server-side API** in-repo. “Build” means:

- Push files to a static host (e.g. GitHub `raw.githubusercontent.com/.../branch/`).
- Point `MYA_BASE_URL` / loader `BASE_URL` at the **repository root** with a trailing slash.

UI standard: loader/universal GUI must use **Fluent Modded UI Library**. Do not ship alternate custom shell implementations as the default path.

## Versioning

`config.luau` exposes `VERSION` and `BRAND` for the hub chrome.

## Relationship to hosting

All paths in `config.luau` are **HTTP suffixes** relative to the hosted repo root, not Windows paths at runtime.
