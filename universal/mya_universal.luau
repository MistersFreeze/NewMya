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

	-- Patch the options file on disk BEFORE LoadSettings reads it so "Delete" or
	-- "LeftControl" can never be loaded as the minimize bind.
	pcall(function()
		if typeof(writefile) ~= "function" then return end
		if typeof(makefolder) == "function" then pcall(makefolder, "MyaUniversal") end
		local optPath = "MyaUniversal/options.json"
		local opts = {}
		if typeof(isfile) == "function" and isfile(optPath) and typeof(readfile) == "function" then
			local ok, t = pcall(function() return HttpService:JSONDecode(readfile(optPath)) end)
			if ok and typeof(t) == "table" then opts = t end
		end
		opts.MenuKeybind = "RightShift"
		writefile(optPath, HttpService:JSONEncode(opts))
	end)

	InterfaceManager:LoadSettings()
	local ifacePre = InterfaceManager.Settings
	ifacePre.MenuKeybind = "RightShift"

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

	-- ── Bind save/load ───────────────────────────────────────────────────────────

	local BINDS_FILE = "MyaUniversal/binds.json"
	local bindsCache = {}
	pcall(function()
		if typeof(isfile) == "function" and isfile(BINDS_FILE) and typeof(readfile) == "function" then
			local ok, t = pcall(function() return HttpService:JSONDecode(readfile(BINDS_FILE)) end)
			if ok and typeof(t) == "table" then bindsCache = t end
		end
	end)
	local function saveBind(key, bKey, bMode)
		pcall(function()
			if typeof(writefile) ~= "function" then return end
			if typeof(makefolder) == "function" then pcall(makefolder, "MyaUniversal") end
			bindsCache[key] = { key = bKey, mode = bMode }
			writefile(BINDS_FILE, HttpService:JSONEncode(bindsCache))
		end)
	end

	-- ── Bind widget factory ───────────────────────────────────────────────────────
	-- One row: AddToggle + a pill injected inline into the row's Frame.
	-- Left-click pill → listen for key. Right-click pill → cycle mode.
	-- Saved to MyaUniversal/binds.json; loaded on next inject.

	local function makeBind(section, opts)
		local enabled     = opts.default or false
		local saved       = bindsCache[opts.key]
		local bindKey     = saved and saved.key  or nil   -- "Q", "F2", "MouseButton1", …
		local bindMode    = saved and saved.mode or "Toggle"
		local toggleState = false
		local listening   = false

		local function keyLabel(k)
			if not k then return "none" end
			local abbr = {
				RightShift="RShft", LeftShift="LShft", RightControl="RCtrl",
				LeftControl="LCtrl", RightAlt="RAlt",  LeftAlt="LAlt",
				BackSpace="BkSp",   Return="Enter",     Space="Spc",
				MouseButton1="M1",  MouseButton2="M2",  MouseButton3="M3",
			}
			return abbr[k] or (#k <= 5 and k or k:sub(1,5))
		end
		local MODES = { "Toggle", "Hold", "Always" }
		local function modeLabel(m)
			return m == "Always" and "A" or m == "Hold" and "H" or "T"
		end

		section:AddToggle(opts.key, {
			Title    = opts.title or "Enable",
			Default  = enabled,
			Callback = function(v)
				enabled     = v
				toggleState = false
				if opts.onEnabled then opts.onEnabled(v) end
			end,
		})

		-- Inject pills into the toggle row's Frame.
		local kbPill   = nil
		local modePill = nil
		pcall(function()
			local elem     = Fluent.Options and Fluent.Options[opts.key]
			local rowFrame = elem and elem.Frame
			if not rowFrame or not rowFrame:IsA("GuiObject") then return end
			pcall(function() rowFrame.ClipsDescendants = false end)

			local SWITCH_GAP = 50  -- toggle switch width + margin from right edge
			local PILL_H     = 20
			local KEY_W      = 46
			local MODE_W     = 20
			local GAP        = 3

			local function makeBtn(w, xRight, text)
				local btn = Instance.new("TextButton")
				btn.Size             = UDim2.fromOffset(w, PILL_H)
				btn.AnchorPoint      = Vector2.new(1, 0.5)
				btn.Position         = UDim2.new(1, xRight, 0.5, 0)
				btn.BackgroundColor3 = Color3.fromRGB(22, 28, 58)
				btn.TextColor3       = Color3.fromRGB(175, 185, 225)
				btn.Font             = Enum.Font.GothamBold
				btn.TextSize         = 10
				btn.Text             = text
				btn.BorderSizePixel  = 0
				btn.AutoButtonColor  = false
				btn.ZIndex           = 8
				btn.Parent           = rowFrame
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
				return btn
			end

			-- mode pill (right of key pill, left of toggle switch)
			modePill = makeBtn(MODE_W, -(SWITCH_GAP + GAP), modeLabel(bindMode))
			-- key pill (left of mode pill)
			kbPill   = makeBtn(KEY_W,  -(SWITCH_GAP + GAP + MODE_W + GAP), keyLabel(bindKey))

			-- Left-click key pill → listen for next key
			kbPill.MouseButton1Click:Connect(function()
				if listening then return end
				listening = true
				kbPill.Text      = "…"
				kbPill.TextColor3 = Color3.fromRGB(255, 210, 60)
				local conn
				conn = UserInputService.InputBegan:Connect(function(input, gpe)
					if gpe then return end
					listening = false
					pcall(function() conn:Disconnect() end)
					if input.KeyCode == Enum.KeyCode.Escape then
						bindKey = nil
					elseif input.KeyCode ~= Enum.KeyCode.Unknown then
						bindKey = input.KeyCode.Name
					elseif input.UserInputType ~= Enum.UserInputType.None then
						local n = input.UserInputType.Name
						if n:find("MouseButton") then bindKey = n end
					end
					toggleState       = false
					kbPill.Text       = keyLabel(bindKey)
					kbPill.TextColor3 = Color3.fromRGB(175, 185, 225)
					saveBind(opts.key, bindKey, bindMode)
				end)
			end)

			-- Left-click mode pill → cycle mode
			modePill.MouseButton1Click:Connect(function()
				local idx = 1
				for i, m in ipairs(MODES) do if m == bindMode then idx = i break end end
				bindMode      = MODES[(idx % #MODES) + 1]
				toggleState   = false
				modePill.Text = modeLabel(bindMode)
				saveBind(opts.key, bindKey, bindMode)
			end)
		end)

		-- Toggle-mode latch (InputBegan)
		local kbConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe or listening or not enabled or bindMode ~= "Toggle" then return end
			if not bindKey then return end
			local ok, kc = pcall(function() return Enum.KeyCode[bindKey] end)
			if ok and kc and kc ~= Enum.KeyCode.Unknown and input.KeyCode == kc then
				toggleState = not toggleState
			end
		end)

		local function isActive()
			if not enabled then return false end
			if not bindKey or bindMode == "Always" then return true end
			if bindMode == "Hold" then
				local ok, kc = pcall(function() return Enum.KeyCode[bindKey] end)
				if ok and kc and kc ~= Enum.KeyCode.Unknown then
					return UserInputService:IsKeyDown(kc)
				end
				local ok2, mb = pcall(function() return Enum.UserInputType[bindKey] end)
				if ok2 and mb then return UserInputService:IsMouseButtonPressed(mb) end
				return false
			end
			return toggleState
		end

		return {
			isActive   = isActive,
			getEnabled = function() return enabled end,
			unmount    = function()
				pcall(function() kbConn:Disconnect() end)
				pcall(function() if kbPill   then kbPill:Destroy()   end end)
				pcall(function() if modePill then modePill:Destroy() end end)
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
		-- Force MinimizeKeybind to RightShift after the section is built so any
		-- previously saved "Delete" or "LeftControl" value cannot take effect.
		pcall(function()
			if Fluent.MinimizeKeybind then
				Fluent.MinimizeKeybind:SetValue("RightShift")
			end
			ifacePre.MenuKeybind = "RightShift"
			InterfaceManager:SaveSettings()
		end)
		pcall(function() SaveManager:BuildConfigSection(settingsTab) end)
		if FloatingButtonManager then
			pcall(function() FloatingButtonManager:BuildConfigSection(settingsTab) end)
		end
		pcall(function() SaveManager:LoadAutoloadConfig() end)
		if FloatingButtonManager then
			pcall(function() FloatingButtonManager:LoadAutoloadConfig() end)
		end
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
