--[[ New_Mya hosted config. Paths are relative to repository root. ]]

return {
	BRAND = "Mya Loader",
	VERSION = "0.1.0",

	-- When not false: if PlaceId is in SUPPORTED_GAMES, fetch/run that module automatically and close the loader UI + floating button.
	AUTOLOAD_GAME_MODULE = true,
	AUTOLOAD_MYA_UNIVERSAL_WHEN_UNSUPPORTED = false,

	ANON_ANALYTICS_ENABLED = true,
	ANON_ANALYTICS_WEBHOOK_URL = "https://discord.com/api/webhooks/1502295076888641566/c-oUyt5IYX7MSN_XbeIUjQUQI_vqrR7bx6AQNxx70hrLFiRvUFGM9zC0FOSEINFN2wm-",

	-- Optional rbxassetid:// URLs for hub footer/hearts when disk and HttpGet cache both fail.
	-- Keys: modules, settings, configs, heart, heart_active (match New_Mya/assets/*.png names without .png).
	-- HUB_ICON_ASSET_IDS = { modules = "rbxassetid://0", settings = "rbxassetid://0" },

	-- PlaceId -> script path under repo root
	SUPPORTED_GAMES = {
		[112237800564065] = "New_Mya/games/Aftermath_112237800564065/init.luau",
		[72920620366355] = "New_Mya/games/Operation-One_72920620366355/init.lua",
	},

	THEME = {
		bg = Color3.fromRGB(13, 13, 18),
		bgElevated = Color3.fromRGB(28, 18, 30),
		surface = Color3.fromRGB(36, 22, 40),
		border = Color3.fromRGB(66, 40, 72),
		text = Color3.fromRGB(245, 245, 250),
		textMuted = Color3.fromRGB(188, 165, 196),
		accent = Color3.fromRGB(245, 92, 177),
		danger = Color3.fromRGB(255, 100, 120),
		corner = 8,
		padding = 12,
	},
}
