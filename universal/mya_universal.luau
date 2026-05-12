return function(BASE_URL, config)
	local Players          = game:GetService("Players")
	local RunService       = game:GetService("RunService")
	local Workspace        = game:GetService("Workspace")
	local UserInputService = game:GetService("UserInputService")

	local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

	-- ── Fluent bootstrap ──────────────────────────────────────────────────────────

	local FLUENT_URL = "https://github.com/StyearX/Fluent-Modded/releases/download/FluentBeta/Fluent.lua"

	local function getFluentSingleton()
		local cached = _G.MYA_FLUENT_SINGLETON
		if typeof(cached) == "table" and cached.CreateWindow then return cached end
		local src
		pcall(function()
			local ge = getgenv and getgenv()
			local pre = ge and ge.MYA_PREFETCH_FLUENT_SRC
			if typeof(pre) == "string" and #pre > 500 then src = pre end
		end)
		if not src then
			local base = typeof(BASE_URL) == "string" and BASE_URL or ""
			if #base > 0 then
				base = base:sub(-1) == "/" and base or base .. "/"
				for _, suf in ipairs({ "New_Mya/lib/FluentModded.lua", "lib/FluentModded.lua" }) do
					local ok, body = pcall(function() return game:HttpGet(base .. suf, true) end)
					if ok and typeof(body) == "string" and #body > 500 then src = body break end
				end
			end
		end
		if not src then
			local ok, r = pcall(function() return game:HttpGet(FLUENT_URL, true) end)
			if ok and typeof(r) == "string" and #r > 0 then src = r end
		end
		assert(typeof(src) == "string" and #src > 0, "UI library unavailable.")
		local fn = assert(loadstring(src, "@FluentModded"), "UI library compile failed.")
		local lib = fn()
		assert(typeof(lib) == "table" and lib.CreateWindow, "UI library invalid.")
		_G.MYA_FLUENT_SINGLETON = lib
		return lib
	end

	local Fluent          = getFluentSingleton()
	local SaveManager     = Fluent.SaveManager
	local InterfaceManager = Fluent.InterfaceManager

	SaveManager:SetLibrary(Fluent)
	InterfaceManager:SetLibrary(Fluent)
	InterfaceManager:SetFolder("vRp4nZxKw9")
	SaveManager:SetFolder("vRp4nZxKw9/Cfg")
	InterfaceManager:LoadSettings()
	local ifacePre = InterfaceManager.Settings

	local function pickTheme(name)
		if typeof(name) == "string" and table.find(Fluent.Themes, name) then return name end
		return "Blood Red"
	end

	local function hideGui(hidden)
		local g = Fluent and Fluent.GUI
		if typeof(g) == "Instance" then pcall(function() g.Enabled = not hidden end) end
	end

	hideGui(true)

	local playerName = localPlayer and localPlayer.DisplayName or "User"
	local Window = Fluent:CreateWindow({
		Title            = "Mya",
		SubTitle         = "Universal",
		TabWidth         = 160,
		Size             = UDim2.fromOffset(540, 510),
		Acrylic          = false,
		Theme            = pickTheme(ifacePre.Theme),
		MinimizeKey      = Enum.KeyCode.RightShift,
		UserInfoTop      = true,
		UserInfoTitle    = playerName,
		UserInfoSubtitle = "Mya User",
		UserInfoColor    = Color3.fromRGB(180, 10, 20),
		Search           = false,
	})
	assert(Window and typeof(Window.AddTab) == "function", "Window creation failed.")

	local visualsTab  = Window:AddTab({ Title = "Visuals",  Icon = "solar/eye-bold" })
	local combatTab   = Window:AddTab({ Title = "Combat",   Icon = "solar/target-bold" })
	local movementTab = Window:AddTab({ Title = "Movement", Icon = "solar/running-bold" })
	local settingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

	-- ── Shared helpers ────────────────────────────────────────────────────────────

	local function getRootPart(char)
		if not char then return nil end
		if char.PrimaryPart and char.PrimaryPart:IsA("BasePart") then return char.PrimaryPart end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		local t = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
		if t and t:IsA("BasePart") then return t end
		return nil
	end

	local teamCheck = false

	local visParams = RaycastParams.new()
	visParams.FilterType  = Enum.RaycastFilterType.Exclude
	visParams.IgnoreWater = true
	local function updateSharedVisFilter()
		local c = localPlayer.Character
		visParams.FilterDescendantsInstances = c and { c } or {}
	end
	updateSharedVisFilter()

	-- ── Module loader ─────────────────────────────────────────────────────────────

	local function fetchModule(suffix)
		local base = typeof(BASE_URL) == "string" and BASE_URL or ""
		if #base == 0 then return nil end
		base = base:sub(-1) == "/" and base or base .. "/"
		local clean    = suffix:gsub("^/", "")
		local stripped = clean:gsub("^New_Mya/", "")
		local prefixed = "New_Mya/" .. stripped
		for _, rel in ipairs({ clean, stripped, prefixed }) do
			local ok, body = pcall(function() return game:HttpGet(base .. rel, true) end)
			if ok and typeof(body) == "string" and #body > 20 then
				local s = body:sub(1, 256):lower()
				if not s:find("<!doctype", 1, true) and not s:find("<html", 1, true) then
					return body
				end
			end
		end
		return nil
	end

	-- ── Bind widget factory ───────────────────────────────────────────────────────
	-- Thin wrapper around section:AddBind (implemented directly in FluentModded.lua).
	-- Pills are built inside the library and parented to the toggle row Frame — they
	-- hide with the GUI automatically and never need external position tracking.
	-- Modes: "Always" (no key) | "Hold" (held down) | "Toggle" (latching press).

	local function makeBind(section, opts)
		local h = section:AddBind(opts.key, {
			Title     = opts.title or "Enable",
			Default   = opts.default or false,
			onEnabled = opts.onEnabled,
		})
		if not h then
			return { isActive = function() return false end, getEnabled = function() return false end, unmount = function() end }
		end
		return { isActive = h.isActive, getEnabled = h.getEnabled, unmount = h.bindUnmount or function() end }
	end

	local ctx = {
		visualsTab        = visualsTab,
		combatTab         = combatTab,
		movementTab       = movementTab,
		Fluent            = Fluent,
		localPlayer       = localPlayer,
		Players           = Players,
		RunService        = RunService,
		UserInputService  = UserInputService,
		Workspace         = Workspace,
		makeBind          = makeBind,
		isSameTeam        = function(p)
			if not teamCheck then return false end
			local lpT = localPlayer.Team
			local ok, pT = pcall(function() return p.Team end)
			return ok and lpT ~= nil and pT ~= nil and lpT == pT
		end,
	}

	local modules = {}
	local MODULE_PATHS = {
		-- Visuals (FOV circles removed: they live inside AimAssist and SilentAim)
		"New_Mya/universal/Visuals/Esp.luau",
		"New_Mya/universal/Visuals/Tracers.luau",
		"New_Mya/universal/Visuals/Skeleton.luau",
		"New_Mya/universal/Visuals/Arrows.luau",
		-- Combat
		"New_Mya/universal/Combat/AimAssist.luau",
		"New_Mya/universal/Combat/SilentAim.luau",
		-- Movement
		"New_Mya/universal/Combat/Movement.luau",
	}

	for _, path in ipairs(MODULE_PATHS) do
		local src = fetchModule(path)
		if src then
			local fn = loadstring(src, "@" .. path)
			if fn then
				local ok, ctor = pcall(fn)
				if ok and typeof(ctor) == "function" then
					local okI, inst = pcall(ctor, ctx)
					if okI and typeof(inst) == "table" and typeof(inst.update) == "function" then
						modules[#modules + 1] = inst
					end
				end
			end
		end
	end

	-- ── Shared render loop ────────────────────────────────────────────────────────
	-- Runs every RenderStepped (no throttle) so drawings track camera without lag.
	-- Per-player character references are cached so FindFirstChild isn't called every frame.

	local universalActive = true
	local connections     = {}

	-- Character cache: keyed by Player, stores { char, root, hum, head, name }
	local playerCache = {}

	local function refreshCache(player)
		local pc = playerCache[player]
		if not pc then
			pc = { name = player.Name }
			playerCache[player] = pc
		end
		local char = player.Character
		if char ~= pc.char then
			pc.char = char
			if char then
				pc.root = getRootPart(char)
				pc.hum  = char:FindFirstChildWhichIsA("Humanoid")
				pc.head = char:FindFirstChild("Head")
			else
				pc.root = nil
				pc.hum  = nil
				pc.head = nil
			end
		end
		return pc
	end

	connections[#connections + 1] = localPlayer.CharacterAdded:Connect(function()
		task.defer(updateSharedVisFilter)
	end)

	connections[#connections + 1] = Players.PlayerRemoving:Connect(function(p)
		playerCache[p] = nil
		for _, mod in ipairs(modules) do
			if mod.onPlayerRemoving then pcall(mod.onPlayerRemoving, p) end
		end
	end)

	connections[#connections + 1] = RunService.RenderStepped:Connect(function()
		if not universalActive then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end

		local screenSize   = cam.ViewportSize
		local screenCenter = screenSize / 2
		local myChar = localPlayer.Character
		local myRoot = myChar and getRootPart(myChar)
		local myPos  = myRoot and myRoot.Position

		local entries = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player == localPlayer then continue end

			local pc   = refreshCache(player)
			local root = pc.root
			local hum  = pc.hum
			if not (root and hum and hum.Health > 0) then continue end

			local rootPos = root.Position
			local rv, rin = cam:WorldToViewportPoint(rootPos)
			local depth   = rv.Z
			local onScr   = rin and depth > 0

			local entryVisible = true
			if onScr then
				local camPos = cam.CFrame.Position
				local ok, ray = pcall(Workspace.Raycast, Workspace, camPos, rootPos - camPos, visParams)
				if ok and ray and ray.Instance then
					entryVisible = ray.Instance:IsDescendantOf(pc.char)
				end
			end

			entries[#entries + 1] = {
				player   = player,
				char     = pc.char,
				name     = pc.name,
				rootPos  = rootPos,
				rootSp   = Vector2.new(rv.X, rv.Y),
				depth    = depth,
				onScreen = onScr,
				visible  = entryVisible,
				dist     = myPos and (myPos - rootPos).Magnitude or 0,
				hpPct    = (function()
					local hp  = hum.Health
					local max = hum.MaxHealth
					-- Guard against math.huge, NaN, and 0 (many games set MaxHealth = math.huge).
					if max ~= max or max <= 0 or max >= 1e15 then max = 100 end
					return math.clamp(hp / max, 0, 1)
				end)(),
			}
		end

		local shared = {
			cam          = cam,
			screenSize   = screenSize,
			screenCenter = screenCenter,
			myPos        = myPos,
			players      = entries,
		}

		for _, mod in ipairs(modules) do
			pcall(mod.update, shared)
		end
	end)

	-- ── Misc section ──────────────────────────────────────────────────────────────

	local miscSection = visualsTab:AddSection("Misc")
	miscSection:AddToggle("qAf4yMzVw6", {
		Title    = "Team Check",
		Icon     = "solar/users-group-rounded-bold",
		Default  = false,
		Callback = function(v) teamCheck = v end,
	})

	-- ── Settings ──────────────────────────────────────────────────────────────────

	task.defer(function()
		if not universalActive then return end
		pcall(function() InterfaceManager:BuildInterfaceSection(settingsTab) end)
		pcall(function() SaveManager:BuildConfigSection(settingsTab) end)
		pcall(function() SaveManager:LoadAutoloadConfig() end)
	end)

	task.defer(function()
		task.wait()
		pcall(function()
			getgenv().ShineEnabled = ifacePre.Animated ~= false
			Fluent:SetTheme(pickTheme(ifacePre.Theme))
		end)
		pcall(function() Fluent:ToggleTransparency(ifacePre.Transparency ~= false) end)
		pcall(function() InterfaceManager:ApplyFont(ifacePre.Font or "GothamSSm") end)
		hideGui(false)
	end)

	-- ── Unload ────────────────────────────────────────────────────────────────────

	local moduleUnloaded = false
	local function unload()
		if moduleUnloaded then return end
		moduleUnloaded  = true
		universalActive = false
		for i = #connections, 1, -1 do
			pcall(function() connections[i]:Disconnect() end)
			connections[i] = nil
		end
		for _, mod in ipairs(modules) do
			if mod.unmount then pcall(mod.unmount) end
		end
		_G.unload_mya_universal = nil
		pcall(function()
			if Window and Window.Destroy then Window:Destroy() end
		end)
	end
	_G.unload_mya_universal = unload

	Fluent:Notify({ Title = "Mya", Content = "Universal loaded", Duration = 3 })
	Window:SelectTab(1)
end
