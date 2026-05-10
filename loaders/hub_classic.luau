--[[
  New_Mya modern loader hub.
  Fresh design direction:
  - modern shell and cards
  - old-loader functionality (Home, Games, Credits, Universal actions)
  - mobile-friendly responsive behavior
]]

return function(BASE_URL: string, config: { [string]: any })
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")

	local PREFIX = "New_Mya/"
	local theme = config.THEME or {}
	local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

	local function sanitizeSource(src: string): string
		if string.byte(src, 1) == 239 and string.byte(src, 2) == 187 and string.byte(src, 3) == 191 then
			return string.sub(src, 4)
		end
		return src
	end

	local function looksLikeHtml(src: string): boolean
		local sample = string.lower(string.sub(src, 1, 256))
		return string.find(sample, "<!doctype html", 1, true) ~= nil
			or string.find(sample, "<html", 1, true) ~= nil
			or string.find(sample, "<head", 1, true) ~= nil
			or string.find(sample, "error response", 1, true) ~= nil
	end

	local function fetchPath(pathSuffix: string): (string?, string?)
		local primaryUrl = BASE_URL .. PREFIX .. pathSuffix
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
		return nil, "failed to fetch: " .. pathSuffix
	end

	local utilSrc, utilErr = fetchPath("lib/util.luau")
	if not utilSrc then
		error("[New_Mya] util: " .. tostring(utilErr))
	end
	local utilChunk, utilCompileErr = loadstring(utilSrc, "@New_Mya/lib/util.luau")
	if typeof(utilChunk) ~= "function" then
		error("[New_Mya] util compile failed: " .. tostring(utilCompileErr))
	end
	local Util = utilChunk()

	local uiSrc, uiErr = fetchPath("lib/ui.luau")
	if not uiSrc then
		error("[New_Mya] ui: " .. tostring(uiErr))
	end
	local uiChunk, uiCompileErr = loadstring(uiSrc, "@New_Mya/lib/ui.luau")
	if typeof(uiChunk) ~= "function" then
		error("[New_Mya] ui compile failed: " .. tostring(uiCompileErr))
	end
	local makeUi = uiChunk()
	if typeof(makeUi) ~= "function" then
		error("[New_Mya] ui must return function(theme)")
	end
	local UI = makeUi(theme)

	local function c(name: string, fallback: Color3): Color3
		local value = theme[name]
		return if typeof(value) == "Color3" then value else fallback
	end

	local C = {
		bg = c("bg", Color3.fromRGB(13, 13, 18)),
		bgElevated = c("bgElevated", Color3.fromRGB(28, 18, 30)),
		surface = c("surface", Color3.fromRGB(36, 22, 40)),
		border = c("border", Color3.fromRGB(66, 40, 72)),
		text = c("text", Color3.fromRGB(245, 245, 250)),
		textMuted = c("textMuted", Color3.fromRGB(188, 165, 196)),
		accent = c("accent", Color3.fromRGB(245, 92, 177)),
		danger = c("danger", Color3.fromRGB(255, 100, 120)),
	}

	local SUPPORTED_GAMES = if typeof(config.SUPPORTED_GAMES) == "table" then config.SUPPORTED_GAMES else {}
	local activeModule = nil
	local activePage = "home"
	local minimized = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "MyaHubModern"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Util.loaderScreenGuiParent()
	Util.configureLoaderScreenGui(gui)

	local main = Instance.new("Frame")
	main.BackgroundColor3 = C.bg
	main.BorderSizePixel = 0
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromOffset(340, 320)
	main.Parent = gui
	UI.corner(main)
	UI.stroke(main)

	local function getTargetSize(): Vector2
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local mobile = vp.X < 860
		local width = math.clamp(math.floor(vp.X * (mobile and 0.96 or 0.88)), 320, mobile and 620 or 1080)
		local height = math.clamp(math.floor(vp.Y * (mobile and 0.88 or 0.86)), 320, mobile and 700 or 700)
		return Vector2.new(width, height)
	end

	local function applyResponsive()
		local size = getTargetSize()
		main.Size = UDim2.fromOffset(size.X, minimized and 62 or size.Y)
	end
	applyResponsive()
	task.spawn(function()
		while gui.Parent do
			applyResponsive()
			task.wait(0.35)
		end
	end)

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundTransparency = 1
	titleBar.Position = UDim2.fromOffset(14, 10)
	titleBar.Size = UDim2.new(1, -28, 0, 38)
	titleBar.Parent = main

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Size = UDim2.new(0.55, 0, 1, 0)
	brand.Font = Enum.Font.GothamBold
	brand.TextSize = 20
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.TextColor3 = C.text
	brand.Text = tostring(config.BRAND or "Mya") .. " Loader"
	brand.Parent = titleBar

	local rightButtons = Instance.new("Frame")
	rightButtons.BackgroundTransparency = 1
	rightButtons.AnchorPoint = Vector2.new(1, 0)
	rightButtons.Position = UDim2.new(1, 0, 0, 0)
	rightButtons.Size = UDim2.fromOffset(190, 38)
	rightButtons.Parent = titleBar
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.FillDirection = Enum.FillDirection.Horizontal
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightLayout.Padding = UDim.new(0, 8)
	rightLayout.Parent = rightButtons

	local function headerBtn(text: string, w: number, bg: Color3): TextButton
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(w, 30)
		b.BackgroundColor3 = bg
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 12
		b.TextColor3 = C.text
		b.Text = text
		b.Parent = rightButtons
		UI.corner(b)
		return b
	end

	local discordBtn = headerBtn("Discord", 76, C.surface)
	local minBtn = headerBtn("—", 30, C.surface)
	local closeBtn = headerBtn("×", 30, C.danger)

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(14, 56)
	body.Size = UDim2.new(1, -28, 1, -112)
	body.Parent = main

	local sidebar = Instance.new("Frame")
	sidebar.BackgroundColor3 = C.bgElevated
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.new(0.29, 0, 1, 0)
	sidebar.Parent = body
	UI.corner(sidebar)
	UI.stroke(sidebar)

	local sidePad = Instance.new("UIPadding")
	sidePad.PaddingTop = UDim.new(0, 12)
	sidePad.PaddingLeft = UDim.new(0, 10)
	sidePad.PaddingRight = UDim.new(0, 10)
	sidePad.PaddingBottom = UDim.new(0, 10)
	sidePad.Parent = sidebar

	local sideList = Instance.new("UIListLayout")
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Padding = UDim.new(0, 8)
	sideList.Parent = sidebar

	local contentHost = Instance.new("Frame")
	contentHost.BackgroundColor3 = C.bgElevated
	contentHost.BorderSizePixel = 0
	contentHost.Position = UDim2.new(0.31, 0, 0, 0)
	contentHost.Size = UDim2.new(0.69, 0, 1, 0)
	contentHost.Parent = body
	UI.corner(contentHost)
	UI.stroke(contentHost)

	local statusBar = Instance.new("Frame")
	statusBar.BackgroundColor3 = C.surface
	statusBar.BorderSizePixel = 0
	statusBar.Position = UDim2.new(0, 14, 1, -42)
	statusBar.Size = UDim2.new(1, -28, 0, 30)
	statusBar.Parent = main
	UI.corner(statusBar)
	local statusText = Instance.new("TextLabel")
	statusText.BackgroundTransparency = 1
	statusText.Position = UDim2.fromOffset(10, 0)
	statusText.Size = UDim2.new(1, -20, 1, 0)
	statusText.Font = Enum.Font.Gotham
	statusText.TextSize = 12
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.TextColor3 = C.textMuted
	statusText.Text = "Ready"
	statusText.Parent = statusBar
	local function notify(msg: string)
		statusText.Text = tostring(msg)
	end

	local pages = {}
	local tabButtons = {}
	local function mkPage(name: string): ScrollingFrame
		local s = Instance.new("ScrollingFrame")
		s.Name = name
		s.Visible = false
		s.BackgroundTransparency = 1
		s.BorderSizePixel = 0
		s.Position = UDim2.fromOffset(10, 10)
		s.Size = UDim2.new(1, -20, 1, -20)
		s.AutomaticCanvasSize = Enum.AutomaticSize.Y
		s.CanvasSize = UDim2.fromOffset(0, 0)
		s.ScrollBarThickness = 5
		s.ScrollBarImageColor3 = C.accent
		s.Parent = contentHost
		local l = Instance.new("UIListLayout")
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 10)
		l.Parent = s
		pages[name] = s
		return s
	end

	local homePage = mkPage("home")
	local gamesPage = mkPage("games")
	local creditsPage = mkPage("credits")

	local function card(parent: Instance): Frame
		local cframe = UI.card(parent)
		cframe.BackgroundColor3 = C.surface
		for _, child in ipairs(cframe:GetChildren()) do
			if child:IsA("UIStroke") then
				child.Color = C.border
			end
		end
		return cframe
	end

	local homeIntro = card(homePage)
	UI.label(homeIntro, "Welcome to Mya", 24, false)
	UI.label(homeIntro, "Modern loader shell with support detection and module launch controls.", 14, true)
	UI.label(homeIntro, "Current PlaceId: " .. tostring(game.PlaceId), 16, false)

	local gamesStatusCard = card(gamesPage)
	local gamesStatusTitle = UI.label(gamesStatusCard, "", 17, false)
	local gamesStatusPath = UI.label(gamesStatusCard, "", 13, true)
	local modulePanel = UI.panel(gamesPage)

	local function unmountCurrent()
		if typeof(activeModule) == "table" and typeof(activeModule.unmount) == "function" then
			pcall(function()
				activeModule.unmount()
			end)
		end
		activeModule = nil
	end

	local function mountPath(path: string)
		unmountCurrent()
		local moduleObj, modErr = Util.loadModuleFromUrl(BASE_URL .. path, path)
		if not moduleObj then
			notify("Load failed: " .. tostring(modErr))
			return
		end
		if typeof(moduleObj) ~= "table" or typeof(moduleObj.mount) ~= "function" then
			notify("Invalid module export for " .. path)
			return
		end
		local ctx = {
			baseUrl = BASE_URL,
			notify = notify,
			theme = theme,
			uiFactory = makeUi,
			panel = modulePanel,
			getPlaceId = function()
				return game.PlaceId
			end,
			gameScriptPath = path,
		}
		local ok, mountErr = pcall(function()
			moduleObj.mount(ctx)
		end)
		if not ok then
			notify("Mount error: " .. tostring(mountErr))
			return
		end
		activeModule = moduleObj
		notify("Mounted module: " .. path)
	end

	local function refreshGamesStatus()
		local placeId = game.PlaceId
		local path = SUPPORTED_GAMES[placeId]
		if typeof(path) == "string" and #path > 0 then
			gamesStatusTitle.Text = "This game is supported"
			gamesStatusPath.Text = "Mapped module: " .. path
		else
			gamesStatusTitle.Text = "This game is not supported yet"
			gamesStatusPath.Text = "Add the PlaceId in config.SUPPORTED_GAMES"
		end
	end

	UI.primaryButton(gamesStatusCard, "Load current game module", function()
		local path = SUPPORTED_GAMES[game.PlaceId]
		if typeof(path) ~= "string" or #path == 0 then
			notify("No module mapped for this PlaceId")
			return
		end
		mountPath(path)
	end)
	UI.button(gamesStatusCard, "Unmount current module", function()
		unmountCurrent()
		notify("Unmounted current module")
	end)

	local allGamesCard = card(gamesPage)
	UI.label(allGamesCard, "Configured supported games", 16, false)
	do
		local count = 0
		for placeId, path in pairs(SUPPORTED_GAMES) do
			count += 1
			local row = UI.button(allGamesCard, tostring(placeId) .. " • " .. tostring(path), function()
				mountPath(path)
			end)
			row.Size = UDim2.new(1, 0, 0, 34)
		end
		if count == 0 then
			UI.label(allGamesCard, "No supported games configured yet.", 13, true)
		end
	end

	local creditsCard = card(creditsPage)
	UI.label(creditsCard, "Credits", 24, false)
	UI.label(creditsCard, "Mya project contributors", 16, false)
	UI.label(creditsCard, "Use this page for team attributions, version notes, and release contact details.", 14, true)

	local function runRemote(path: string, label: string)
		local src, err = Util.httpGet(BASE_URL .. path)
		if not src then
			notify(label .. " fetch failed: " .. tostring(err))
			return
		end
		local fn, cerr = Util.loadstringCompile(src, label)
		if not fn then
			notify(label .. " compile failed: " .. tostring(cerr))
			return
		end
		local ok, rerr = pcall(fn)
		if not ok then
			notify(label .. " runtime failed: " .. tostring(rerr))
			return
		end
		notify(label .. " launched")
	end

	local function launchModernUniversal()
		local src, err = fetchPath("loaders/hub.luau")
		if not src then
			notify("Mya Universal fetch failed: " .. tostring(err))
			return
		end
		local chunk, compileErr = loadstring(src, "@New_Mya/loaders/hub.luau")
		if typeof(chunk) ~= "function" then
			notify("Mya Universal compile failed: " .. tostring(compileErr))
			return
		end
		local hubMain = chunk()
		if typeof(hubMain) ~= "function" then
			notify("Mya Universal export invalid")
			return
		end
		local ok, runErr = pcall(hubMain, BASE_URL, config)
		if not ok then
			notify("Mya Universal runtime failed: " .. tostring(runErr))
			return
		end
		if gui.Parent then
			gui:Destroy()
		end
	end

	local function sideButton(text: string, onClick: () -> (), isTab: boolean?): TextButton
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.new(1, 0, 0, 34)
		b.BackgroundColor3 = C.surface
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.TextColor3 = C.text
		b.Text = text
		b.Parent = sidebar
		UI.corner(b)
		b.MouseButton1Click:Connect(onClick)
		if isTab then
			table.insert(tabButtons, b)
		end
		return b
	end

	local function setPage(id: string)
		activePage = id
		for pageId, page in pairs(pages) do
			page.Visible = pageId == id
		end
		for i, btn in ipairs(tabButtons) do
			local selected = (id == "home" and i == 1) or (id == "games" and i == 2) or (id == "credits" and i == 3)
			btn.BackgroundColor3 = selected and C.accent or C.surface
		end
		if id == "games" then
			refreshGamesStatus()
		end
	end

	sideButton("Home", function()
		setPage("home")
	end, true)
	sideButton("Games", function()
		setPage("games")
	end, true)
	sideButton("Credits", function()
		setPage("credits")
	end, true)

	local section = Instance.new("TextLabel")
	section.BackgroundTransparency = 1
	section.Size = UDim2.new(1, 0, 0, 18)
	section.Font = Enum.Font.GothamBold
	section.TextSize = 11
	section.TextXAlignment = Enum.TextXAlignment.Left
	section.TextColor3 = C.textMuted
	section.Text = "UNIVERSAL"
	section.Parent = sidebar

	sideButton("Mya Universal", function()
		launchModernUniversal()
	end)
	sideButton("Dumper", function()
		runRemote("universal/dumper.lua", "Dumper")
	end)
	sideButton("Anti VC Ban", function()
		local url = config.ANTI_VC_BAN_URL
		if typeof(url) ~= "string" or #url == 0 then
			notify("Set ANTI_VC_BAN_URL in config")
			return
		end
		local src, err = Util.httpGet(url)
		if not src then
			notify("Anti VC Ban fetch failed: " .. tostring(err))
			return
		end
		local fn, cerr = Util.loadstringCompile(src, "AntiVCBan")
		if not fn then
			notify("Anti VC Ban compile failed: " .. tostring(cerr))
			return
		end
		local ok, rerr = pcall(fn)
		if not ok then
			notify("Anti VC Ban failed: " .. tostring(rerr))
			return
		end
		notify("Anti VC Ban launched")
	end)

	local function closeHub()
		unmountCurrent()
		if gui.Parent then
			gui:Destroy()
		end
	end
	_G.unload_new_mya = closeHub

	closeBtn.MouseButton1Click:Connect(closeHub)
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
		statusBar.Visible = not minimized
		local target = getTargetSize()
		local h = minimized and 62 or target.Y
		TweenService:Create(main, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(target.X, h),
		}):Play()
	end)
	discordBtn.MouseButton1Click:Connect(function()
		notify("Discord button clicked")
	end)

	local dragConn: RBXScriptConnection? = nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = input.Position
		local origin = main.Position
		if dragConn then
			dragConn:Disconnect()
		end
		dragConn = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
				local d = changed.Position - start
				main.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
			end
		end)
	end)
	titleBar.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightShift then
			gui.Enabled = not gui.Enabled
		end
	end)

	setPage("home")
	refreshGamesStatus()
	notify("Ready · press RightShift anytime to hide or show this window")
end
