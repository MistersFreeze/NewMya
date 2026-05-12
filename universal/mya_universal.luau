return function(BASE_URL, config)
	local Players          = game:GetService("Players")
	local RunService       = game:GetService("RunService")
	local Workspace        = game:GetService("Workspace")
	local UserInputService = game:GetService("UserInputService")
	local HttpService      = game:GetService("HttpService")

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

	local Fluent              = getFluentSingleton()
	local SaveManager         = Fluent.SaveManager
	local InterfaceManager    = Fluent.InterfaceManager
	local FloatingButtonManager = Fluent.FloatingButtonManager

	SaveManager:SetLibrary(Fluent)
	InterfaceManager:SetLibrary(Fluent)
	if FloatingButtonManager then
		FloatingButtonManager:SetLibrary(Fluent)
		FloatingButtonManager:SetFolder("MyaUniversal/Floating")
	end
	InterfaceManager:SetFolder("MyaUniversal")
	SaveManager:SetFolder("MyaUniversal/Cfg")

	InterfaceManager:LoadSettings()
	local ifacePre = InterfaceManager.Settings

	-- ── Window layout persistence ─────────────────────────────────────────────────

	local LAYOUT_FILE = "MyaUniversal/layout.json"

	local function readLayout()
		if typeof(readfile) ~= "function" then return nil end
		local ok, raw = pcall(readfile, LAYOUT_FILE)
		if not ok or typeof(raw) ~= "string" or #raw == 0 then return nil end
		local ok2, t = pcall(function() return HttpService:JSONDecode(raw) end)
		return (ok2 and typeof(t) == "table") and t or nil
	end

	local function writeLayout(w, h)
		if typeof(writefile) ~= "function" then return end
		pcall(function()
			if typeof(makefolder) == "function" then
				pcall(makefolder, "MyaUniversal")
				pcall(makefolder, "MyaUniversal/Cfg")
				pcall(makefolder, "MyaUniversal/Floating")
			end
			local payload = HttpService:JSONEncode({ sx = math.floor(w), sy = math.floor(h) })
			writefile(LAYOUT_FILE, payload)
		end)
	end

	local savedLayout = readLayout()
	local windowSize  = UDim2.fromOffset(540, 510)
	if savedLayout then
		local sx = tonumber(savedLayout.sx)
		local sy = tonumber(savedLayout.sy)
		if sx and sy and sx >= 400 and sy >= 300 then
			windowSize = UDim2.fromOffset(math.floor(sx), math.floor(sy))
		end
	end

	-- ── Window creation ───────────────────────────────────────────────────────────

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
		Size             = windowSize,
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

	-- Pre-consume the first-Minimize notification so it never fires on user interaction
	-- or on unload. GUI is hidden at this point so nothing is visible.
	pcall(function()
		local orig = Fluent.Notify
		Fluent.Notify = function() end
		Window:Minimize()  -- sets internal C=true, notification flag consumed
		Fluent.Notify = orig
	end)

	local visualsTab  = Window:AddTab({ Title = "Visuals",  Icon = "solar/eye-bold" })
	local combatTab   = Window:AddTab({ Title = "Combat",   Icon = "solar/target-bold" })
	local movementTab = Window:AddTab({ Title = "Movement", Icon = "solar/running-bold" })
	local configTab   = Window:AddTab({ Title = "Config",   Icon = "solar/diskette-bold" })
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
	-- Exclude ALL player characters so other players don't block LOS checks.
	-- Rebuilt each frame inside the render loop.
	local function updateSharedVisFilter()
		local chars = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then chars[#chars + 1] = plr.Character end
		end
		visParams.FilterDescendantsInstances = chars
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
	-- Three rows: Enable toggle + Keybind key picker + Bind Mode dropdown.
	-- Default mode "Always" = feature active whenever Enable is ON, no key needed.
	-- "Hold" = must hold the bound key. "Toggle" = press key to latch on/off.
	-- Keybind + mode are auto-saved to the "autoload" config on change.

	-- Precompute M4/M5 enum values once — avoids pcall overhead inside hot callbacks.
	local MB4, MB5
	pcall(function() MB4 = Enum.UserInputType.MouseButton4 end)
	pcall(function() MB5 = Enum.UserInputType.MouseButton5 end)

	local function makeBind(section, opts)
		local enabled     = opts.default or false
		local bindMode    = "Always"
		local toggleState = false

		section:AddToggle(opts.key, {
			Title    = opts.title or "Enable",
			Default  = enabled,
			Callback = function(v)
				enabled     = v
				toggleState = false
				if opts.onEnabled then opts.onEnabled(v) end
			end,
		})

		local kb     = nil
		local kbConn = nil

		pcall(function()
			kb = section:AddKeybind(opts.key .. "_kb", {
				Title   = "Keybind",
				Default = "None",
			})
		end)

		section:AddDropdown(opts.key .. "_mode", {
			Title    = "Bind Mode",
			Values   = { "Always", "Hold", "Toggle" },
			Default  = "Always",
			NoSearch = true,
			Callback = function(v)
				bindMode    = v
				toggleState = false
			end,
		})

		if kb then
			-- Track Toggle-mode latch via key press.
			pcall(function()
				kbConn = UserInputService.InputBegan:Connect(function(input, gpe)
					if gpe or not enabled or bindMode ~= "Toggle" then return end
					local kv = kb.Value
					if not kv or kv == "None" then return end
					local hit = false
					if     kv == "MouseLeft"    then hit = input.UserInputType == Enum.UserInputType.MouseButton1
					elseif kv == "MouseRight"   then hit = input.UserInputType == Enum.UserInputType.MouseButton2
					elseif kv == "MouseMiddle"  then hit = input.UserInputType == Enum.UserInputType.MouseButton3
					elseif kv == "MouseButton4" then hit = MB4 ~= nil and input.UserInputType == MB4
					elseif kv == "MouseButton5" then hit = MB5 ~= nil and input.UserInputType == MB5
					elseif input.UserInputType == Enum.UserInputType.Keyboard then
						local ok, kc = pcall(function() return Enum.KeyCode[kv] end)
						hit = ok and kc and kc ~= Enum.KeyCode.Unknown and input.KeyCode == kc
					end
					if hit then toggleState = not toggleState end
				end)
			end)
			pcall(function()
				kb:OnChanged(function()
					toggleState = false
					pcall(function() SaveManager:Save("autoload") end)
				end)
			end)
		end

		local function mouseHeld(kv)
			if     kv == "MouseLeft"    then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			elseif kv == "MouseRight"   then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			elseif kv == "MouseMiddle"  then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
			elseif kv == "MouseButton4" then return MB4 ~= nil and UserInputService:IsMouseButtonPressed(MB4)
			elseif kv == "MouseButton5" then return MB5 ~= nil and UserInputService:IsMouseButtonPressed(MB5)
			end
			return false
		end

		local function isActive()
			if not enabled then return false end
			if bindMode == "Always" then return true end
			local kv = kb and kb.Value
			if not kv or kv == "None" or kv == "" then return true end
			if bindMode == "Hold" then
				if kv:sub(1,5) == "Mouse" then return mouseHeld(kv) end
				local ok,kc = pcall(function() return Enum.KeyCode[kv] end)
				return ok and kc and kc ~= Enum.KeyCode.Unknown and UserInputService:IsKeyDown(kc) or false
			end
			return toggleState
		end

		return {
			isActive   = isActive,
			getEnabled = function() return enabled end,
			unmount    = function()
				if kbConn then pcall(function() kbConn:Disconnect() end) end
			end,
		}
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
		"New_Mya/universal/Visuals/Esp.luau",
		"New_Mya/universal/Visuals/Tracers.luau",
		"New_Mya/universal/Visuals/Skeleton.luau",
		"New_Mya/universal/Visuals/Arrows.luau",
		"New_Mya/universal/Combat/AimAssist.luau",
		"New_Mya/universal/Combat/SilentAim.luau",
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
		elseif char then
			-- Re-resolve parts that were nil when character first loaded (race condition fix).
			if not pc.root then pc.root = getRootPart(char) end
			if not pc.hum  then pc.hum  = char:FindFirstChildWhichIsA("Humanoid") end
			if not pc.head then pc.head = char:FindFirstChild("Head") end
		end
		return pc
	end

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

		-- Rebuild vis filter every frame so respawns and joins are always current.
		updateSharedVisFilter()

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

		-- Config tab: full save/load system.
		pcall(function() SaveManager:BuildConfigSection(configTab) end)

		-- Settings tab: interface options only.
		pcall(function() InterfaceManager:BuildInterfaceSection(settingsTab) end)

		-- Load autoload config AFTER building sections so all Options are registered.
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

	-- Periodically save window size while the universal is running.
	local layoutSaveConn
	layoutSaveConn = RunService.Heartbeat:Connect(function()
		-- Throttle: save roughly every 5 seconds via a frame counter.
		-- Use a closure counter instead of os.clock to keep it simple.
	end)
	pcall(function() layoutSaveConn:Disconnect() end)

	local layoutTick = 0
	connections[#connections + 1] = RunService.Heartbeat:Connect(function(dt)
		if not universalActive then return end
		layoutTick = layoutTick + dt
		if layoutTick < 10 then return end
		layoutTick = 0
		pcall(function()
			local root = Window and (Window.Root or Window.Frame)
			if root and root:IsA("GuiObject") then
				local s = root.AbsoluteSize
				if s.X >= 400 and s.Y >= 300 then
					writeLayout(s.X, s.Y)
				end
			end
		end)
	end)

	-- ── Unload ────────────────────────────────────────────────────────────────────

	local moduleUnloaded = false
	local function unload()
		if moduleUnloaded then return end
		moduleUnloaded  = true
		universalActive = false
		-- Save window size before destroying.
		pcall(function()
			local root = Window and (Window.Root or Window.Frame)
			if root and root:IsA("GuiObject") then
				local s = root.AbsoluteSize
				if s.X >= 400 and s.Y >= 300 then
					writeLayout(s.X, s.Y)
				end
			end
		end)
		for i = #connections, 1, -1 do
			pcall(function() connections[i]:Disconnect() end)
			connections[i] = nil
		end
		for _, mod in ipairs(modules) do
			if mod.unmount then pcall(mod.unmount) end
		end
		_G.unload_mya_universal = nil
		-- Silence all Fluent notifications during teardown so nothing fires.
		pcall(function() Fluent.Notify = function() end end)
		pcall(function()
			if Window and Window.Destroy then Window:Destroy() end
		end)
	end
	_G.unload_mya_universal = unload

	Fluent:Notify({ Title = "Mya", Content = "Universal loaded", Duration = 3 })
	Window:SelectTab(1)
end
