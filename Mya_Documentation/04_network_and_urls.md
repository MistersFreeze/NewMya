# Network and URLs

## Static tree

All assets are plain files fetched by path. No REST API.

## Loader chain

1. User runs `loader.luau` (paste or HttpGet).
2. Loader HttpGets `New_Mya/config/config.luau` → compile → table.
3. Loader HttpGets `New_Mya/loaders/hub.luau` → compile → call returned `function(BASE_URL, config)`.
4. Hub initializes Fluent Modded UI and exposes script/module launch actions from config and hosted paths.

## Failure modes

- Wrong branch or missing `New_Mya/` prefix → 404 or HTML error page.
- Private repo without token → HTML; `loadstring` fails with a clear message if `util` detects HTML.
- Executor blocks HTTP → user must allow requests.

## External data
- **Discord Webhooks**: Used by `lib/analytics.luau` for execution logging.
- **ip-api.com**: Used for optional geolocation data in analytics.

## Trailing slash

Normalize `BASE_URL` to end with `/` in loaders and when setting `MYA_BASE_URL`.
