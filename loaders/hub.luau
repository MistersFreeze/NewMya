return function(BASE_URL: string, config: { [string]: any })
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local CoreGui = game:GetService("CoreGui")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")

	local function sanitizeSource(src)
		if string.byte(src, 1) == 239 and string.byte(src, 2) == 187 and string.byte(src, 3) == 191 then
			return string.sub(src, 4)
		end
		return src
	end

	local function looksLikeHtmlOrError(src)
		local sample = string.lower(string.sub(src, 1, 256))
		return string.find(sample, "<!doctype html", 1, true) ~= nil
			or string.find(sample, "<html", 1, true) ~= nil
			or string.find(sample, "<head", 1, true) ~= nil
			or string.find(sample, "error response", 1, true) ~= nil
			or string.find(sample, "404", 1, true) ~= nil
	end

	local function fetchPath(pathSuffix: string): (string?, string?)
		local variants = {}
		local cleanSuffix = tostring(pathSuffix)
		local strippedSuffix = string.gsub(cleanSuffix, "^New_Mya/", "")
		local prefixedSuffix = "New_Mya/" .. strippedSuffix

		local function addUrl(u: string)
			for _, existing in ipairs(variants) do
				if existing == u then
					return
				end
			end
			table.insert(variants, u)
		end

		addUrl(BASE_URL .. cleanSuffix)
		addUrl(BASE_URL .. strippedSuffix)
		addUrl(BASE_URL .. prefixedSuffix)

		local lastErr = "no response"
		for _, url in ipairs(variants) do
			local ok, res = pcall(function()
				return game:HttpGet(url, true)
			end)
			-- Fallback for executors that don't support the cache argument correctly
			if not ok or (ok and typeof(res) ~= "string") then
				ok, res = pcall(function()
					return game:HttpGet(url)
				end)
			end
			if ok and typeof(res) == "string" and #res > 0 then
				local clean = sanitizeSource(res)
				if not looksLikeHtmlOrError(clean) then
					return clean, nil
				end
				lastErr = "html/error response from " .. url
			else
				lastErr = tostring(res)
			end
		end
		return nil, lastErr
	end

	local function notify(Fluent, title: string, content: string, duration: number?)
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
		local src = nil
		local genv = typeof(getgenv) == "function" and getgenv()
		local pre = genv and genv.MYA_PREFETCH_FLUENT_SRC
		if typeof(pre) == "string" and #pre > 500 then
			src = pre
			pcall(function()
				genv.MYA_PREFETCH_FLUENT_SRC = nil
			end)
		else
			src = select(1, fetchPath("New_Mya/lib/FluentModded.lua"))
		end
		if typeof(src) ~= "string" or #src < 500 then
			local okSrc, remote = pcall(function()
				return game:HttpGet(FLUENT_URL, true)
			end)
			if not okSrc or (okSrc and typeof(remote) ~= "string") then
				okSrc, remote = pcall(function()
					return game:HttpGet(FLUENT_URL)
				end)
			end
			if okSrc and typeof(remote) == "string" and #remote > 0 then
				src = sanitizeSource(remote)
			end
		end
		if typeof(src) ~= "string" or #src == 0 then
			error("Fluent source missing (host New_Mya/lib/FluentModded.lua or GitHub release).")
		end
		local loaderFn = loadstring(src, "@FluentModded")
		if typeof(loaderFn) ~= "function" then
			error("Fluent compile failed")
		end
		local lib = loaderFn()
		if typeof(lib) ~= "table" or not lib.CreateWindow then
			error("Fluent returned invalid library")
		end
		pcall(function()
			g.MYA_FLUENT_SINGLETON = lib
		end)
		return lib
	end

	local function runAnalytics(logType, extra)
		local webhook = config.ANON_ANALYTICS_WEBHOOK_URL
		if typeof(webhook) ~= "string" or #webhook < 10 then return end
		
		task.spawn(pcall, function()
			local src = fetchPath("New_Mya/lib/analytics.luau")
			if not src then return end
			local chunk = loadstring(src, "@Analytics")
			if typeof(chunk) ~= "function" then return end
			local analytics = chunk()
			if typeof(analytics) ~= "table" or typeof(analytics.sendLog) ~= "function" then return end
			analytics.sendLog(webhook, logType, extra)
		end)
	end

	local player = Players.LocalPlayer
	local playerName = if player then player.DisplayName else "User"

	local Fluent = getFluentSingleton()
	local SaveManager = Fluent.SaveManager
	local InterfaceManager = Fluent.InterfaceManager
	local FloatingButtonManager = Fluent.FloatingButtonManager

	SaveManager:SetLibrary(Fluent)
	InterfaceManager:SetLibrary(Fluent)
	FloatingButtonManager:SetLibrary(Fluent)
	InterfaceManager:SetFolder("MyaHub")
	SaveManager:SetFolder("MyaHub/Config")
	FloatingButtonManager:SetFolder("MyaHub/Floating")

	InterfaceManager:LoadSettings()
	local ifacePre = InterfaceManager.Settings

	local ifaceOptionsExist = typeof(isfile) == "function" and isfile("MyaHub/options.json")

	local layoutFile = "MyaHub/layout.json"
	local function readLayoutEarly(): any
		if typeof(readfile) ~= "function" then
			return nil
		end
		local okRead, raw = pcall(readfile, layoutFile)
		if not okRead or typeof(raw) ~= "string" or #raw == 0 then
			return nil
		end
		local okDecode, parsed = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not okDecode or typeof(parsed) ~= "table" then
			return nil
		end
		return parsed
	end

	local savedLayoutPre = readLayoutEarly()

	local function pickFluentTheme(name)
		if typeof(name) == "string" and table.find(Fluent.Themes, name) then
			return name
		end
		return "Blood Red"
	end

	local windowOpts = {
		Title = tostring(config.BRAND or "Mya Universal"),
		SubTitle = "",
		TabWidth = 160,
		Size = UDim2.fromOffset(540, 500),
		Acrylic = ifaceOptionsExist and ifacePre.Acrylic == true or false,
		Theme = pickFluentTheme(ifacePre.Theme),
		MinimizeKey = Enum.KeyCode.RightShift,
		UserInfoTop = true,
		UserInfoTitle = playerName,
		UserInfoSubtitle = "Mya User",
		UserInfoColor = Color3.fromRGB(180, 10, 20),
		Search = false,
	}
	do
		local sx = savedLayoutPre and tonumber(savedLayoutPre.sx)
		local sy = savedLayoutPre and tonumber(savedLayoutPre.sy)
		if sx and sy and sx >= 420 and sy >= 320 then
			windowOpts.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
		end
	end

	local function hideFluentGui(hidden)
		local rootGui = Fluent and Fluent.GUI
		if typeof(rootGui) ~= "Instance" then
			return
		end
		pcall(function()
			rootGui.Enabled = not hidden
		end)
	end

	hideFluentGui(true)

	local function recreateFluentAndManagers()
		pcall(function()
			_G.MYA_FLUENT_SINGLETON = nil
		end)
		local fresh = getFluentSingleton()
		Fluent = fresh
		SaveManager = fresh.SaveManager
		InterfaceManager = fresh.InterfaceManager
		FloatingButtonManager = fresh.FloatingButtonManager
		SaveManager:SetLibrary(Fluent)
		InterfaceManager:SetLibrary(Fluent)
		FloatingButtonManager:SetLibrary(Fluent)
		InterfaceManager:SetFolder("MyaHub")
		SaveManager:SetFolder("MyaHub/Config")
		FloatingButtonManager:SetFolder("MyaHub/Floating")
		InterfaceManager:LoadSettings()
		ifacePre = InterfaceManager.Settings
		ifaceOptionsExist = typeof(isfile) == "function" and isfile("MyaHub/options.json")
	end

	local Window = Fluent:CreateWindow(windowOpts)
	if not Window or typeof(Window.AddTab) ~= "function" then
		recreateFluentAndManagers()
		ifacePre = InterfaceManager.Settings
		ifaceOptionsExist = typeof(isfile) == "function" and isfile("MyaHub/options.json")
		windowOpts.Theme = pickFluentTheme(ifacePre.Theme)
		windowOpts.Acrylic = ifaceOptionsExist and ifacePre.Acrylic == true or false
		do
			local sx = savedLayoutPre and tonumber(savedLayoutPre.sx)
			local sy = savedLayoutPre and tonumber(savedLayoutPre.sy)
			if sx and sy and sx >= 420 and sy >= 320 then
				windowOpts.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
			end
		end
		hideFluentGui(true)
		Window = Fluent:CreateWindow(windowOpts)
	end
	if not Window or typeof(Window.AddTab) ~= "function" then
		error("Mya Loader: Fluent could not create the hub window (still nil after reset).")
	end

	pcall(function()
		getgenv().ShineEnabled = ifacePre.Animated ~= false
		Fluent:SetTheme(pickFluentTheme(ifacePre.Theme))
	end)
	pcall(function()
		Fluent:ToggleTransparency(ifacePre.Transparency ~= false)
	end)
	local discordTag = "@fubelt"

	local function readLayout(): { [string]: number }?
		return readLayoutEarly()
	end

	local function writeLayout(layout: { [string]: number })
		if typeof(writefile) ~= "function" then
			return
		end
		if typeof(makefolder) == "function" then
			pcall(makefolder, "MyaHub")
		end
		local okEncode, payload = pcall(function()
			return HttpService:JSONEncode(layout)
		end)
		if not okEncode or typeof(payload) ~= "string" then
			return
		end
		pcall(writefile, layoutFile, payload)
	end

	local function findWindowFrame(brandTitle: string): Frame?
		local best = nil
		local bestArea = 0
		for _, inst in ipairs(CoreGui:GetDescendants()) do
			if inst:IsA("Frame") and inst.Visible and inst.AbsoluteSize.X > 300 and inst.AbsoluteSize.Y > 250 then
				local hasTitle = false
				for _, child in ipairs(inst:GetDescendants()) do
					if child:IsA("TextLabel") and child.Text == brandTitle then
						hasTitle = true
						break
			end
		end
				if hasTitle then
					local area = inst.AbsoluteSize.X * inst.AbsoluteSize.Y
					if area > bestArea then
						bestArea = area
						best = inst
			end
		end
			end
		end
		return best
	end

	local brandTitle = tostring(config.BRAND or "Mya Universal")
	local savedLayout = savedLayoutPre
	local latestLayout = savedLayout
	local rootFrameRef: Frame? = nil

	local function applyLayoutToRoot(force: boolean?)
		local rootFrame = rootFrameRef or Window.Root or findWindowFrame(brandTitle)
		if not rootFrame then
			return
		end
		rootFrameRef = rootFrame
		local src = latestLayout or readLayout()
		if not src then
			return
		end
		local sx = tonumber(src.sx)
		local sy = tonumber(src.sy)
		local pxs = tonumber(src.pxs)
		local pxo = tonumber(src.pxo)
		local pys = tonumber(src.pys)
		local pyo = tonumber(src.pyo)
		if not sx or not sy or not pxs or not pxo or not pys or not pyo then
			return
		end
		if force or rootFrame.Size.X.Offset ~= math.floor(sx) or rootFrame.Size.Y.Offset ~= math.floor(sy) then
			rootFrame.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
		end
		if
			force
			or rootFrame.Position.X.Scale ~= pxs
			or rootFrame.Position.X.Offset ~= math.floor(pxo)
			or rootFrame.Position.Y.Scale ~= pys
			or rootFrame.Position.Y.Offset ~= math.floor(pyo)
		then
			rootFrame.Position = UDim2.new(pxs, math.floor(pxo), pys, math.floor(pyo))
		end
	end

	do
		local rootFrame = Window and Window.Root
		if not rootFrame then
			rootFrame = findWindowFrame(brandTitle)
		end
		if rootFrame then
			rootFrameRef = rootFrame
			if savedLayout then
				local sx = tonumber(savedLayout.sx) or rootFrame.Size.X.Offset
				local sy = tonumber(savedLayout.sy) or rootFrame.Size.Y.Offset
				local pxs = tonumber(savedLayout.pxs)
				local pxo = tonumber(savedLayout.pxo)
				local pys = tonumber(savedLayout.pys)
				local pyo = tonumber(savedLayout.pyo)
				if sx and sy and sx >= 420 and sy >= 320 then
					rootFrame.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
					pcall(function()
						if Window then
							Window.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
						end
					end)
				end
				if pxs and pxo and pys and pyo then
					local pos = UDim2.new(pxs, math.floor(pxo), pys, math.floor(pyo))
					rootFrame.Position = pos
					pcall(function()
						if Window then
							Window.Position = pos
						end
					end)
				end
			end

			local last = {
				sx = rootFrame.Size.X.Offset,
				sy = rootFrame.Size.Y.Offset,
				pxs = rootFrame.Position.X.Scale,
				pxo = rootFrame.Position.X.Offset,
				pys = rootFrame.Position.Y.Scale,
				pyo = rootFrame.Position.Y.Offset,
			}
			local function maybeSave()
				if rootFrame.Size.X.Offset < 420 or rootFrame.Size.Y.Offset < 320 then
					return
				end
				local now = {
					sx = rootFrame.Size.X.Offset,
					sy = rootFrame.Size.Y.Offset,
					pxs = rootFrame.Position.X.Scale,
					pxo = rootFrame.Position.X.Offset,
					pys = rootFrame.Position.Y.Scale,
					pyo = rootFrame.Position.Y.Offset,
				}
				if
					now.sx ~= last.sx
					or now.sy ~= last.sy
					or now.pxs ~= last.pxs
					or now.pxo ~= last.pxo
					or now.pys ~= last.pys
					or now.pyo ~= last.pyo
				then
					last = now
					latestLayout = now
					writeLayout(now)
				end
			end

			rootFrame:GetPropertyChangedSignal("Size"):Connect(maybeSave)
			rootFrame:GetPropertyChangedSignal("Position"):Connect(maybeSave)
		end

	end

	local MainTab = Window:AddTab({ Title = "Main", Icon = "solar/home-bold" })
	local GamesTab = Window:AddTab({ Title = "Games", Icon = "solar/gamepad-bold" })
	local ScriptsTab = Window:AddTab({ Title = "Scripts", Icon = "solar/code-bold" })
	local CreditsTab = Window:AddTab({ Title = "Credits", Icon = "solar/star-bold" })
	local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

	local mainSection = MainTab:AddSection("Main Controls")
	mainSection:AddParagraph({
		Title = "Session",
		Content = "PlaceId: " .. tostring(game.PlaceId) .. " | Version: " .. tostring(config.VERSION or "0.0.0"),
	})

	local gameSection = GamesTab:AddSection("Supported Games")
	local supportedGames = if typeof(config.SUPPORTED_GAMES) == "table" then config.SUPPORTED_GAMES else {}
	local gameCount = 0
	for _ in pairs(supportedGames) do
		gameCount += 1
	end
	gameSection:AddParagraph({
		Title = "Configured",
		Content = "Found " .. tostring(gameCount) .. " mapped place IDs.",
	})

	local OpenGui
	local function teardownForSecondaryUI()
		pcall(function()
			if Window and Window.Destroy then
				Window:Destroy()
			end
		end)
		pcall(function()
			if OpenGui and OpenGui.Parent then
				OpenGui:Destroy()
			end
		end)
		for _ = 1, 2 do
			RunService.Heartbeat:Wait()
		end
		_G.MYA_FLUENT_SINGLETON = nil
		pcall(function()
			_G.MYA_FLUENT_SINGLETON = nil
		end)
		RunService.Heartbeat:Wait()
	end

	local _activeGameModule = nil
	local function launchGameModule(): (boolean, string?)
		local modulePath = supportedGames[game.PlaceId]
		if typeof(modulePath) ~= "string" or #modulePath == 0 then
			return false, "no_module"
		end
		local src, err = fetchPath(modulePath)
		if not src then
			return false, "fetch:" .. tostring(err)
		end
		local chunk, compileErr = loadstring(src, "@Mya/" .. modulePath)
		if typeof(chunk) ~= "function" then
			return false, "compile:" .. tostring(compileErr)
		end

		local ok, runResult = pcall(chunk)
		if not ok then
			return false, "runtime:" .. tostring(runResult)
		end

		if typeof(runResult) == "table" and typeof(runResult.mount) == "function" then
			-- Module is valid and ready. Now we can clear the Hub and mount.
			teardownForSecondaryUI()
			
			local okMount, mountErr = pcall(function()
				_activeGameModule = runResult
				runResult.mount({
					Fluent = Fluent,
					SaveManager = SaveManager,
					InterfaceManager = InterfaceManager,
					notify = function(title, text, dur)
						notify(Fluent, title, text, dur or 3)
					end,
					getPlaceId = function()
						return game.PlaceId
					end,
					baseUrl = BASE_URL,
					gameScriptPath = modulePath,
				})
			end)
			
			if not okMount then
				return false, "mount:" .. tostring(mountErr)
			end
			
			runAnalytics("GameModuleLaunch", modulePath)
			return true, modulePath
		else
			return false, "Invalid module return (expected table with mount function)"
		end
	end

	gameSection:AddButton({
		Title = "Load Current Game Module",
		Icon = "solar/play-bold",
		Callback = function()
			local ok, info = launchGameModule()
			if not ok then
				if info == "no_module" then
					notify(Fluent, "Mya", "No mapped module for this PlaceId.", 3)
				else
					notify(Fluent, "Mya", "Module failed: " .. tostring(info), 4)
				end
				return
			end
			notify(Fluent, "Mya", "Module launched: " .. tostring(info), 3)
		end,
	})

	local scriptsSection = ScriptsTab:AddSection("Universal Scripts")
	local function launchMyaUniversalFallback()
		teardownForSecondaryUI()
		local fLib = getFluentSingleton()
		if typeof(fLib) ~= "table" or typeof(fLib.CreateWindow) ~= "function" then
			return
		end
		local fSave = fLib.SaveManager
		local fInterface = fLib.InterfaceManager
		local uWindow = fLib:CreateWindow({
			Title = "Mya Universal",
			SubTitle = "",
			TabWidth = 160,
			Size = UDim2.fromOffset(520, 480),
			Acrylic = false,
			Theme = "Blood Red",
			MinimizeKey = Enum.KeyCode.RightShift,
			UserInfoTop = true,
			UserInfoTitle = playerName,
			UserInfoSubtitle = "Mya User",
			UserInfoColor = Color3.fromRGB(180, 10, 20),
			Search = false,
		})
		if not uWindow or typeof(uWindow.AddTab) ~= "function" then
			return
		end

		local visualsTab = uWindow:AddTab({ Title = "Visuals", Icon = "solar/eye-bold" })
		local combatTab = uWindow:AddTab({ Title = "Combat", Icon = "solar/target-bold" })
		local miscTab = uWindow:AddTab({ Title = "Misc", Icon = "solar/widget-bold" })
		local settingsTab = uWindow:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

		local visuals = visualsTab:AddSection("Visuals")
		visuals:AddToggle("UniversalESP", {
			Title = "ESP",
			Icon = "solar/eye-bold",
			Default = false,
			Callback = function(v)
				notify(fLib, "Visuals", "ESP " .. (v and "enabled" or "disabled"), 2)
			end,
		})
		visuals:AddToggle("UniversalTracers", {
			Title = "Tracers",
			Icon = "solar/share-bold",
			Default = false,
			Callback = function(v)
				notify(fLib, "Visuals", "Tracers " .. (v and "enabled" or "disabled"), 2)
			end,
		})

		local combat = combatTab:AddSection("Combat")
		combat:AddToggle("UniversalSilentAim", {
			Title = "Silent Aim",
			Icon = "solar/target-bold",
			Default = false,
			Callback = function(v)
				notify(fLib, "Combat", "Silent Aim " .. (v and "enabled" or "disabled"), 2)
			end,
		})
		combat:AddToggle("UniversalAimAssist", {
			Title = "Aim Assist",
			Icon = "solar/crosshair-bold",
			Default = false,
			Callback = function(v)
				notify(fLib, "Combat", "Aim Assist " .. (v and "enabled" or "disabled"), 2)
			end,
		})

		local misc = miscTab:AddSection("Misc")
		misc:AddButton({
			Title = "Run Dumper",
			Icon = "solar/document-bold",
			Callback = function()
				local src, err = fetchPath("universal/dumper.lua")
				if not src then
					notify(fLib, "Misc", "Dumper fetch failed: " .. tostring(err), 4)
					return
				end
				local chunk, compileErr = loadstring(src, "@Mya/universal/dumper.lua")
				if typeof(chunk) ~= "function" then
					notify(fLib, "Misc", "Dumper compile failed: " .. tostring(compileErr), 4)
				return
			end
				local ok, runErr = pcall(chunk)
				if not ok then
					notify(fLib, "Misc", "Dumper runtime failed: " .. tostring(runErr), 4)
					return
				end
				notify(fLib, "Misc", "Dumper launched", 3)
			end,
		})

				pcall(function()
			if fInterface then
				fInterface:SetLibrary(fLib)
				fInterface:SetFolder("MyaUniversalFallback")
				fInterface:BuildInterfaceSection(settingsTab)
			end
		end)
		pcall(function()
			if fSave then
				fSave:SetLibrary(fLib)
				fSave:SetFolder("MyaUniversalFallback/Config")
				fSave:BuildConfigSection(settingsTab)
			end
		end)
		pcall(function()
			if fSave then
				fSave:LoadAutoloadConfig()
			end
		end)
		uWindow:SelectTab(1)
	end

	scriptsSection:AddButton({
		Title = "Launch Mya Universal",
		Icon = "solar/rocket-bold",
		Callback = function()
			local src, err = fetchPath("universal/mya_universal.luau")
			if not src then
				notify(Fluent, "Mya Universal", "Hosted file missing, launching fallback.", 3)
				launchMyaUniversalFallback()
				return
			end
			local chunk, compileErr = loadstring(src, "@Mya/universal/mya_universal.luau")
			if typeof(chunk) ~= "function" then
				notify(Fluent, "Mya Universal", "Compile failed, launching fallback.", 3)
				launchMyaUniversalFallback()
			return
		end
			local ok, entryOrErr = pcall(chunk)
			if not ok then
				notify(Fluent, "Mya Universal", "Init failed, launching fallback.", 3)
				launchMyaUniversalFallback()
				return
			end
			if typeof(entryOrErr) == "function" then
				teardownForSecondaryUI()
				local rok, rerr = pcall(entryOrErr, BASE_URL, config)
				if not rok then
					notify(Fluent, "Mya Universal", "Runtime failed, launching fallback.", 3)
					launchMyaUniversalFallback()
					return
				end
				notify(Fluent, "Mya Universal", "Launched", 3)
				return
			end
			notify(Fluent, "Mya Universal", "Invalid export, launching fallback.", 3)
			launchMyaUniversalFallback()
		end,
	})
	scriptsSection:AddButton({
		Title = "Run Dumper",
		Icon = "solar/document-bold",
		Callback = function()
			local src, err = fetchPath("universal/dumper.lua")
			if not src then
				notify(Fluent, "Dumper", "Fetch failed: " .. tostring(err), 4)
				return
			end
			local chunk, compileErr = loadstring(src, "@Mya/universal/dumper.lua")
			if typeof(chunk) ~= "function" then
				notify(Fluent, "Dumper", "Compile failed: " .. tostring(compileErr), 4)
			return
		end
			local ok, runErr = pcall(chunk)
			if not ok then
				notify(Fluent, "Dumper", "Runtime failed: " .. tostring(runErr), 4)
			return
		end
			notify(Fluent, "Dumper", "Launched", 3)
		end,
	})

	local creditsSection = CreditsTab:AddSection("Credits")
	creditsSection:AddParagraph({
		Title = "Discord",
		Content = tostring(discordTag),
	})
	creditsSection:AddParagraph({
		Title = "GUI Credits",
		Content = "Fluent Modded UI by StyearX and EvilFish",
	})

	InterfaceManager:BuildInterfaceSection(SettingsTab)
	SaveManager:BuildConfigSection(SettingsTab)
	FloatingButtonManager:BuildConfigSection(SettingsTab)

	-- Yield once so window + tabs paint before heavier config IO / JSON decode (reduces perceived inject freeze).
			task.defer(function()
		pcall(function()
			SaveManager:LoadAutoloadConfig()
		end)
		pcall(function()
			FloatingButtonManager:LoadAutoloadConfig()
		end)
	end)

	local autoLoadDone = false
	local unloadingNow = false
	task.defer(function()
		if autoLoadDone then
			return
		end
		local wantAuto = config.AUTOLOAD_GAME_MODULE ~= false
		if not wantAuto then
			return
		end
		local modulePath = supportedGames[game.PlaceId]
		if typeof(modulePath) ~= "string" or #modulePath == 0 then
			return
		end
		task.wait(0.2)
		if autoLoadDone then
			return
		end
		autoLoadDone = true
		local ok, infoOrErr = launchGameModule()
		if not ok then
			autoLoadDone = false
			notify(Fluent, "Mya", "Auto-load failed: " .. tostring(infoOrErr), 5)
			return
				end
			end)

	task.spawn(function()
		pcall(function()
			InterfaceManager:ApplyFont(ifacePre.Font or "GothamSSm")
		end)
		for _ = 1, 4 do
			applyLayoutToRoot(true)
			RunService.Heartbeat:Wait()
		end
		hideFluentGui(false)
	end)

	pcall(function()
		local function isMyaName(name)
			if typeof(name) ~= "string" then
				return false
			end
			local n = string.lower(name)
			return string.find(n, "mya", 1, true) ~= nil
				or n == "openui"
				or n == "myaopenui"
				or n == "menuholder"
		end

		local function destroyMyaInstances(root)
			if not root then
				return
			end
			for _, inst in ipairs(root:GetDescendants()) do
				if isMyaName(inst.Name) then
					pcall(function()
						inst:Destroy()
					end)
				end
			end
		end

		local function runKnownUnloadHooks()
			if _activeGameModule and typeof(_activeGameModule.unmount) == "function" then
				pcall(_activeGameModule.unmount)
			end
			local hooks = {
				"unload_mya",
				"unload_mya_universal",
				"unload_op1",
			}
			for _, key in ipairs(hooks) do
				local fn = rawget(_G, key)
				if typeof(fn) == "function" then
					pcall(fn)
		end
	end
			for key, val in pairs(_G) do
				if typeof(key) == "string" and typeof(val) == "function" then
					local lk = string.lower(key)
					if
						key ~= "unload_new_mya"
						and string.sub(lk, 1, 7) == "unload_"
						and (string.find(lk, "mya", 1, true) or string.find(lk, "aftermath", 1, true))
					then
						pcall(val)
					end
				end
			end
		end

		local function clearMyaGlobals()
			local explicit = {
				"MYA_FLUENT_SINGLETON",
				"MYA_FETCH",
				"MYA_REPO_BASE",
				"MYA_LOCAL_ROOT",
				"MYA_UNIVERSAL",
				"MYA_UNIVERSAL_CONFIG",
				"MYA_UNIVERSAL_SYNC_UI",
				"MYA_COMBAT_HELPERS",
				"MYA_OP1_RUN_UI_SYNC",
				"MYA_SILENT_AIM_HOOK_OK",
				"user_interface",
				"mya_universal_ui",
				"mya_universal_notif_ui",
				"mya_notify",
				"new_menu_key",
				"aftermath_purge_residual_visuals",
			}
			for _, key in ipairs(explicit) do
				pcall(function()
					_G[key] = nil
				end)
			end
			for key, _ in pairs(_G) do
				if typeof(key) == "string" then
					local lk = string.lower(key)
					if string.sub(key, 1, 4) == "MYA_" then
						pcall(function()
							_G[key] = nil
						end)
					elseif string.find(lk, "mya", 1, true) ~= nil then
						pcall(function()
							_G[key] = nil
						end)
					elseif string.sub(lk, 1, 7) == "unload_" and string.find(lk, "aftermath", 1, true) ~= nil then
						pcall(function()
							_G[key] = nil
						end)
					end
				end
			end
		end

		local function hardSweep()
			runKnownUnloadHooks()
			pcall(function()
				if Window and Window.Destroy then
					Window:Destroy()
				end
			end)
			pcall(function()
				if OpenGui and OpenGui.Parent then
					OpenGui:Destroy()
				end
			end)
			pcall(function()
				destroyMyaInstances(CoreGui)
			end)
			pcall(function()
				local lp = Players.LocalPlayer
				if lp and lp:FindFirstChild("PlayerGui") then
					destroyMyaInstances(lp.PlayerGui)
				end
			end)
			pcall(function()
				destroyMyaInstances(workspace)
			end)
			pcall(function()
				_G.MYA_FLUENT_SINGLETON = nil
			end)
			clearMyaGlobals()
		end

		-- Define the global hook that triggers the cleanup
		_G.unload_new_mya = function()
			if unloadingNow then return end
			unloadingNow = true
			
			-- Run now, then across a few frames for anything created late by async callbacks.
			hardSweep()
			task.defer(function()
				for _ = 1, 8 do
					RunService.Heartbeat:Wait()
					hardSweep()
				end
			end)
		end
	end)

	notify(Fluent, "Mya Loader", "Mya Loader has been initialized", 4)
	runAnalytics("HubBoot", "New_Mya/loaders/hub.luau")
	Window:SelectTab(1)
end
