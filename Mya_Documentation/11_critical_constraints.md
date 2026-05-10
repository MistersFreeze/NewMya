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

## User-facing copy

No parenthetical asides in hub labels, toasts, or hints. Avoid long explanatory blocks unless explicitly requested.
