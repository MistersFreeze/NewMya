return function(BASE_URL, config)
	local Players = game:GetService("Players")

	local function looksLikeHtml(src)
		local sample = string.lower(string.sub(src, 1, 256))
		return string.find(sample, "<!doctype html", 1, true) ~= nil
			or string.find(sample, "<html", 1, true) ~= nil
			or string.find(sample, "<head", 1, true) ~= nil
			or string.find(sample, "error response", 1, true) ~= nil
			or string.find(sample, "404", 1, true) ~= nil
	end

	local function sanitizeSource(src)
		if string.byte(src, 1) == 239 and string.byte(src, 2) == 187 and string.byte(src, 3) == 191 then
			return string.sub(src, 4)
		end
		return src
	end

	local function fetchPath(pathSuffix)
		local primaryUrl = BASE_URL .. "New_Mya/" .. pathSuffix
		local okPrimary, primaryRes = pcall(function()
			return game:HttpGet(primaryUrl, true)
		end)
		if okPrimary and typeof(primaryRes) == "string" and not looksLikeHtml(primaryRes) then
			return sanitizeSource(primaryRes), nil
		end

		local fallbackUrl = BASE_URL .. pathSuffix
		local okFallback, fallbackRes = pcall(function()
			return game:HttpGet(fallbackUrl, true)
		end)
		if okFallback and typeof(fallbackRes) == "string" and not looksLikeHtml(fallbackRes) then
			return sanitizeSource(fallbackRes), nil
		end

		return nil, "failed to fetch " .. tostring(pathSuffix)
	end

	local function notify(Fluent, title, content, duration)
		Fluent:Notify({
			Title = title,
			Content = content,
			Duration = duration or 3,
		})
	end

	local FLUENT_URL = "https://github.com/StyearX/Fluent-Modded/releases/download/FluentBeta/Fluent.lua"
	local function getFluentSingleton()
		local g = _G
		local cached = g.MYA_FLUENT_SINGLETON
		if typeof(cached) == "table" and cached.CreateWindow then
			return cached
		end
		local src = select(1, fetchPath("lib/FluentModded.lua"))
		if typeof(src) ~= "string" or #src < 500 then
			local okSrc, remote = pcall(function()
				return game:HttpGet(FLUENT_URL, true)
			end)
			if okSrc and typeof(remote) == "string" and #remote > 0 then
				src = sanitizeSource(remote)
			end
		end
		if typeof(src) ~= "string" or #src == 0 then
			error("[Mya Universal] Fluent source missing (New_Mya/lib/FluentModded.lua or GitHub).")
		end
		local loaderFn = loadstring(src, "@FluentModded")
		if typeof(loaderFn) ~= "function" then
			error("[Mya Universal] Fluent compile failed")
		end
		local lib = loaderFn()
		if typeof(lib) ~= "table" or not lib.CreateWindow then
			error("[Mya Universal] Fluent invalid")
		end
		g.MYA_FLUENT_SINGLETON = lib
		return lib
	end

	local Fluent = getFluentSingleton()
	local SaveManager = Fluent.SaveManager
	local InterfaceManager = Fluent.InterfaceManager

	local player = Players.LocalPlayer
	local playerName = player and player.DisplayName or "User"

	local Window = Fluent:CreateWindow({
		Title = "Mya Universal",
		SubTitle = "Universal Toolkit",
		TabWidth = 160,
		Size = UDim2.fromOffset(520, 480),
		Acrylic = false,
		Theme = "Blood Red",
		MinimizeKey = Enum.KeyCode.RightShift,
		UserInfoTop = true,
		UserInfoTitle = playerName,
		UserInfoSubtitle = "Mya User",
		UserInfoColor = Color3.fromRGB(180, 10, 20),
		Search = true,
	})

	local VisualsTab = Window:AddTab({ Title = "Visuals", Icon = "solar/eye-bold" })
	local CombatTab = Window:AddTab({ Title = "Combat", Icon = "solar/target-bold" })
	local MiscTab = Window:AddTab({ Title = "Misc", Icon = "solar/widget-bold" })
	local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "gravity/archive" })

	local visualsSection = VisualsTab:AddSection("Visuals")
	visualsSection:AddToggle("UniversalESP", {
		Title = "ESP",
		Icon = "solar/eye-bold",
		Default = false,
		Callback = function(value)
			notify(Fluent, "Visuals", "ESP " .. (value and "enabled" or "disabled"), 2)
		end,
	})
	visualsSection:AddToggle("UniversalTracers", {
		Title = "Tracers",
		Icon = "solar/share-bold",
		Default = false,
		Callback = function(value)
			notify(Fluent, "Visuals", "Tracers " .. (value and "enabled" or "disabled"), 2)
		end,
	})
	visualsSection:AddSlider("UniversalFov", {
		Title = "Visual FOV",
		Icon = "solar/ruler-bold",
		Default = 120,
		Min = 30,
		Max = 300,
		Rounding = 1,
		Callback = function(value)
			notify(Fluent, "Visuals", "FOV: " .. tostring(value), 2)
		end,
	})

	local combatSection = CombatTab:AddSection("Combat")
	combatSection:AddToggle("UniversalSilentAim", {
		Title = "Silent Aim",
		Icon = "solar/target-bold",
		Default = false,
		Callback = function(value)
			notify(Fluent, "Combat", "Silent Aim " .. (value and "enabled" or "disabled"), 2)
		end,
	})
	combatSection:AddToggle("UniversalAimAssist", {
		Title = "Aim Assist",
		Icon = "solar/crosshair-bold",
		Default = false,
		Callback = function(value)
			notify(Fluent, "Combat", "Aim Assist " .. (value and "enabled" or "disabled"), 2)
		end,
	})
	combatSection:AddSlider("UniversalHitChance", {
		Title = "Hit Chance",
		Icon = "solar/chart-bold",
		Default = 75,
		Min = 0,
		Max = 100,
		Rounding = 1,
		Callback = function(value)
			notify(Fluent, "Combat", "Hit chance: " .. tostring(value) .. "%", 2)
		end,
	})

	local miscSection = MiscTab:AddSection("Misc")
	miscSection:AddButton({
		Title = "Run Dumper",
		Icon = "solar/document-bold",
		Callback = function()
			local src, err = fetchPath("universal/dumper.lua")
			if not src then
				notify(Fluent, "Misc", "Dumper fetch failed: " .. tostring(err), 4)
				return
			end
			local fn, compileErr = loadstring(src, "@Mya/universal/dumper.lua")
			if typeof(fn) ~= "function" then
				notify(Fluent, "Misc", "Dumper compile failed: " .. tostring(compileErr), 4)
				return
			end
			local ok, runErr = pcall(fn)
			if not ok then
				notify(Fluent, "Misc", "Dumper runtime failed: " .. tostring(runErr), 4)
				return
			end
			notify(Fluent, "Misc", "Dumper launched", 3)
		end,
	})
	miscSection:AddButton({
		Title = "Run Anti VC Ban",
		Icon = "solar/shield-bold",
		Callback = function()
			local url = config and config.ANTI_VC_BAN_URL
			if typeof(url) ~= "string" or #url == 0 then
				notify(Fluent, "Misc", "Set ANTI_VC_BAN_URL in config.", 4)
				return
			end
			local ok, src = pcall(function()
				return game:HttpGet(url, true)
			end)
			if not ok or typeof(src) ~= "string" then
				notify(Fluent, "Misc", "Anti VC Ban fetch failed.", 4)
				return
			end
			local fn, compileErr = loadstring(src, "@Mya/AntiVCBan")
			if typeof(fn) ~= "function" then
				notify(Fluent, "Misc", "Anti VC Ban compile failed: " .. tostring(compileErr), 4)
				return
			end
			local rok, runErr = pcall(fn)
			if not rok then
				notify(Fluent, "Misc", "Anti VC Ban runtime failed: " .. tostring(runErr), 4)
				return
			end
			notify(Fluent, "Misc", "Anti VC Ban launched", 3)
		end,
	})
	miscSection:AddButton({
		Title = "Copy PlaceId",
		Icon = "solar/copy-bold",
		Callback = function()
			if typeof(setclipboard) == "function" then
				setclipboard(tostring(game.PlaceId))
				notify(Fluent, "Misc", "PlaceId copied.", 2)
			else
				notify(Fluent, "Misc", "setclipboard unavailable.", 3)
			end
		end,
	})

	SaveManager:SetLibrary(Fluent)
	InterfaceManager:SetLibrary(Fluent)
	InterfaceManager:SetFolder("MyaHub")
	SaveManager:SetFolder("MyaHub/Config")
	pcall(function()
		InterfaceManager:BuildInterfaceSection(SettingsTab)
	end)
	pcall(function()
		SaveManager:BuildConfigSection(SettingsTab)
	end)
	local okLoad = pcall(function()
		SaveManager:LoadAutoloadConfig()
	end)
	if not okLoad then
		notify(Fluent, "Mya Universal", "Config mismatch detected. Open Settings and save new config.", 4)
	end

	notify(Fluent, "Mya Universal", "Ready", 3)
	Window:SelectTab(1)
end
