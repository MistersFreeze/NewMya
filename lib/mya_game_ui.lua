--[[
  Shared in-game GUI shell for Mya game modules (hub-style window + sidebar + tabs).

  Loading (repo root = same folder as `lib/`, e.g. hub `ctx.baseUrl`):
    local fetch = ...  -- HttpGet + MYA_LOCAL_ROOT, same as your game init
    local repoBase = ... -- e.g. normalizeBase(ctx.baseUrl)
    local UI = loadstring(fetch(repoBase .. "lib/mya_game_ui.lua"), "@lib/mya_game_ui")()
    local THEME, C = UI.defaultTheme()
    local ui = Instance.new("ScreenGui"); ui.Parent = ...
    local notify, notifGui = UI.createNotifyStack({ C = C, THEME = THEME, ts = game:GetService("TweenService"), gethui_support = gethui ~= nil })
    local shell = UI.createHubShell({
      ui = ui, THEME = THEME, C = C, ts = ts, uis = uis,
      titleText = "Mya  ·  Your Game",
      tabNames = { "Main", "Settings" },
      subPages = { Main = { "Tab A", "Tab B" } },  -- omit keys for tabs with no sub-rows
      statusDefault = "Ready",
      discordInvite = "https://discord.gg/...",  -- or false to hide Discord button
    })
    -- shell.tab_containers["Main"], shell.make_page(), shell.switch_tab("Main"), etc.

  Mya Universal uses this module from `games/MyaUniversal/gui.lua`.
]]

local M = {}

--- Default rose/plum palette + derived control colors (`C`).
function M.defaultTheme(overrides: { [string]: any }?)
	local THEME: { [string]: any } = {
		bg = Color3.fromRGB(18, 12, 22),
		bgElevated = Color3.fromRGB(28, 18, 32),
		surface = Color3.fromRGB(40, 26, 48),
		border = Color3.fromRGB(72, 48, 88),
		text = Color3.fromRGB(255, 244, 250),
		textMuted = Color3.fromRGB(188, 158, 205),
		accent = Color3.fromRGB(245, 118, 168),
		danger = Color3.fromRGB(255, 108, 138),
		corner = 5,
		cornerSm = 3,
	}
	if type(overrides) == "table" then
		for k, v in pairs(overrides) do
			THEME[k] = v
		end
	end
	local C = {
		bg = THEME.bg,
		panel = THEME.bgElevated,
		header = THEME.bgElevated,
		tab_off = THEME.bgElevated,
		tab_on = THEME.surface,
		accent = THEME.accent,
		row_hover = Color3.fromRGB(48, 32, 56),
		tog_off = Color3.fromRGB(34, 22, 40),
		tog_on = THEME.accent,
		text = THEME.text,
		dim = THEME.textMuted,
		slid_bg = Color3.fromRGB(34, 22, 42),
		slid_fg = THEME.accent,
		input_bg = Color3.fromRGB(32, 20, 38),
		sub_off = THEME.bgElevated,
		sub_on = THEME.surface,
		red = THEME.danger,
		green = Color3.fromRGB(96, 214, 168),
	}
	return THEME, C
end

--- Right-side toast stack; returns `notify(title, text, duration?)` and the ScreenGui.
--- opts: C, THEME, ts, notifParent?, gethui_support?
function M.createNotifyStack(opts: { [string]: any }): (any, ScreenGui)
	local C = opts.C
	local THEME = opts.THEME
	local ts = opts.ts
	local gethui_support = opts.gethui_support == true
	local notif_ui = Instance.new("ScreenGui")
	notif_ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	notif_ui.Name = "MyaNotif_" .. tostring(math.random(100000, 999999))
	notif_ui.IgnoreGuiInset = true
	notif_ui.DisplayOrder = 100
	notif_ui.Enabled = true
	notif_ui.ResetOnSpawn = false
	notif_ui.Parent = opts.notifParent
		or ((opts.gethui_support and typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui"))

	local notif_top = Instance.new("Frame")
	notif_top.BackgroundTransparency = 1
	notif_top.Size = UDim2.fromScale(1, 1)
	notif_top.Parent = notif_ui

	local notif_container = Instance.new("Frame", notif_top)
	notif_container.BackgroundTransparency = 1
	notif_container.Size = UDim2.fromOffset(260, 400)
	notif_container.Position = UDim2.new(1, -270, 1, -420)

	local n_layout = Instance.new("UIListLayout", notif_container)
	n_layout.FillDirection = Enum.FillDirection.Vertical
	n_layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	n_layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	n_layout.Padding = UDim.new(0, 8)

	local function notify(title: string, text: string, duration: number?)
		duration = duration or 3
		local f = Instance.new("Frame")
		f.BackgroundColor3 = C.panel
		f.Size = UDim2.fromOffset(250, 55)
		f.Position = UDim2.fromOffset(260, 0)
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, THEME.corner)
		local str = Instance.new("UIStroke", f)
		str.Color = THEME.border

		local lbl_t = Instance.new("TextLabel", f)
		lbl_t.BackgroundTransparency = 1
		lbl_t.Position = UDim2.fromOffset(16, 8)
		lbl_t.Size = UDim2.new(1, -24, 0, 16)
		lbl_t.Font = Enum.Font.GothamBold
		lbl_t.Text = title
		lbl_t.TextColor3 = C.accent
		lbl_t.TextSize = 12
		lbl_t.TextXAlignment = Enum.TextXAlignment.Left

		local lbl_d = Instance.new("TextLabel", f)
		lbl_d.BackgroundTransparency = 1
		lbl_d.Position = UDim2.fromOffset(16, 26)
		lbl_d.Size = UDim2.new(1, -24, 0, 16)
		lbl_d.Font = Enum.Font.Gotham
		lbl_d.Text = text
		lbl_d.TextColor3 = C.text
		lbl_d.TextSize = 11
		lbl_d.TextXAlignment = Enum.TextXAlignment.Left
		lbl_d.TextWrapped = true

		local stripe = Instance.new("Frame", f)
		stripe.BackgroundColor3 = C.accent
		stripe.BorderSizePixel = 0
		stripe.Size = UDim2.new(0, 3, 1, 0)
		Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, THEME.cornerSm)

		f.Parent = notif_container
		ts:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()

		task.spawn(function()
			task.wait(duration)
			if not f or not f.Parent then
				return
			end
			local t_out = ts:Create(
				f,
				TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(260, 0), BackgroundTransparency = 1 }
			)
			t_out:Play()
			ts:Create(str, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			ts:Create(lbl_t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			ts:Create(lbl_d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			ts:Create(stripe, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			t_out.Completed:Wait()
			f:Destroy()
		end)
	end

	return notify, notif_ui
end

--- Hub-style window: title bar, sidebar tabs, optional sub-tab row, content host, status bar.
function M.createHubShell(opts: { [string]: any })
	local THEME = opts.THEME
	local C = opts.C
	local ts = opts.ts
	local uis = opts.uis
	local ui = opts.ui
	local TAB_NAMES = opts.tabNames
	local SUB_PAGES = opts.subPages
	local WIN_W = opts.winW or 540
	local WIN_H = opts.winH or 400
	local INNER_CONTENT_W = WIN_W - 162

	local main = Instance.new("Frame")
	main.Name = "main"
	main.BackgroundColor3 = C.bg
	main.BorderSizePixel = 0
	local gap = typeof(opts.winEdgeGap) == "number" and opts.winEdgeGap or 12
	local place = opts.winPlacement
	if place == "topRight" then
		main.AnchorPoint = Vector2.new(1, 0)
		main.Position = UDim2.new(1, -gap, 0, gap)
	elseif place == "topLeft" then
		main.AnchorPoint = Vector2.new(0, 0)
		main.Position = UDim2.new(0, gap, 0, gap)
	elseif place == "bottomRight" then
		main.AnchorPoint = Vector2.new(1, 1)
		main.Position = UDim2.new(1, -gap, 1, -gap)
	elseif place == "bottomLeft" then
		main.AnchorPoint = Vector2.new(0, 1)
		main.Position = UDim2.new(0, gap, 1, -gap)
	else
		main.AnchorPoint = Vector2.new(0.5, 0.5)
		main.Position = UDim2.fromScale(0.5, 0.5)
	end
	main.Size = UDim2.fromOffset(WIN_W, WIN_H)
	main.Parent = ui
	Instance.new("UICorner", main).CornerRadius = UDim.new(0, THEME.corner)

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundColor3 = C.header
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 44)
	titleBar.Parent = main
	local titleRound = Instance.new("UICorner", titleBar)
	titleRound.CornerRadius = UDim.new(0, THEME.corner)
	titleBar.ClipsDescendants = true

	local title_lbl = Instance.new("TextLabel")
	title_lbl.BackgroundTransparency = 1
	title_lbl.Position = UDim2.new(0, 14, 0, 0)
	title_lbl.Size = UDim2.new(1, -200, 1, 0)
	title_lbl.Font = Enum.Font.GothamBold
	title_lbl.TextSize = 16
	title_lbl.TextXAlignment = Enum.TextXAlignment.Left
	title_lbl.TextColor3 = C.text
	title_lbl.Text = opts.titleText
	title_lbl.Parent = titleBar

	local function openDiscord(url: string)
		pcall(function()
			local g = typeof(getgenv) == "function" and getgenv()
			if g and typeof(g.openbrowser) == "function" then
				g.openbrowser(url)
			end
		end)
		pcall(function()
			game:GetService("GuiService"):OpenBrowserWindow(url)
		end)
		if typeof(setclipboard) == "function" then
			setclipboard(url)
		end
	end

	local btnRow = Instance.new("Frame")
	btnRow.BackgroundTransparency = 1
	btnRow.AnchorPoint = Vector2.new(1, 0.5)
	btnRow.Position = UDim2.new(1, -8, 0.5, 0)
	btnRow.Size = UDim2.new(0, 146, 0, 28)
	btnRow.Parent = titleBar

	local discordInvite = opts.discordInvite
	local discordBtn: TextButton? = nil
	if discordInvite ~= false then
		local url = (typeof(discordInvite) == "string" and discordInvite) or "https://discord.gg/YeyepQG6K9"
		discordBtn = Instance.new("TextButton")
		discordBtn.BorderSizePixel = 0
		discordBtn.Size = UDim2.new(0, 68, 1, 0)
		discordBtn.Position = UDim2.new(0, 0, 0, 0)
		discordBtn.BackgroundColor3 = C.tab_on
		discordBtn.Text = "Discord"
		discordBtn.TextColor3 = C.accent
		discordBtn.Font = Enum.Font.GothamSemibold
		discordBtn.TextSize = 12
		discordBtn.AutoButtonColor = false
		discordBtn.Parent = btnRow
		Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, THEME.corner)
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, 0, 0, 44)
	body.Size = UDim2.new(1, 0, 1, -44)
	body.Parent = main

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.new(0, 132, 1, -16)
	sidebar.Position = UDim2.new(0, 10, 0, 8)
	sidebar.Parent = body
	local sideLayout = Instance.new("UIListLayout", sidebar)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Padding = UDim.new(0, 6)

	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "Content"
	rightPanel.BackgroundTransparency = 1
	rightPanel.BorderSizePixel = 0
	rightPanel.Position = UDim2.new(0, 152, 0, 8)
	rightPanel.Size = UDim2.new(1, -162, 1, -52)
	rightPanel.ClipsDescendants = true
	rightPanel.Parent = body

	local statusBar = Instance.new("Frame")
	statusBar.Name = "Status"
	statusBar.BackgroundColor3 = C.header
	statusBar.BorderSizePixel = 0
	statusBar.AnchorPoint = Vector2.new(0, 1)
	statusBar.Position = UDim2.new(0, 10, 1, -8)
	statusBar.Size = UDim2.new(1, -20, 0, 26)
	statusBar.Parent = body
	Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, THEME.corner)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.new(0, 10, 0, 0)
	statusLabel.Size = UDim2.new(1, -20, 1, 0)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center
	statusLabel.TextColor3 = C.dim
	statusLabel.Text = opts.statusDefault or "Ready"
	statusLabel.Parent = statusBar

	if discordBtn then
		discordBtn.MouseButton1Click:Connect(function()
			openDiscord((typeof(discordInvite) == "string" and discordInvite) or "https://discord.gg/YeyepQG6K9")
			statusLabel.Text = "Discord invite copied or opened in browser"
			task.delay(2.5, function()
				if statusLabel.Parent then
					statusLabel.Text = opts.statusDefault or "Ready"
				end
			end)
		end)
	end

	local minimized = false
	local minBtn = Instance.new("TextButton")
	minBtn.BorderSizePixel = 0
	minBtn.Size = UDim2.new(0, 32, 1, 0)
	minBtn.Position = UDim2.new(0, 74, 0, 0)
	minBtn.BackgroundColor3 = C.tab_on
	minBtn.Text = "—"
	minBtn.TextColor3 = C.dim
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 14
	minBtn.AutoButtonColor = false
	minBtn.Parent = btnRow
	Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, THEME.corner)
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
		main.Size = if minimized then UDim2.fromOffset(WIN_W, 44) else UDim2.fromOffset(WIN_W, WIN_H)
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.BorderSizePixel = 0
	closeBtn.Size = UDim2.new(0, 32, 1, 0)
	closeBtn.Position = UDim2.new(0, 110, 0, 0)
	closeBtn.BackgroundColor3 = C.tab_on
	closeBtn.Text = "×"
	closeBtn.TextColor3 = THEME.danger
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = btnRow
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, THEME.corner)
	closeBtn.MouseButton1Click:Connect(function()
		if opts.onClose then
			opts.onClose()
		else
			ui.Enabled = false
		end
	end)

	local sub_bar = Instance.new("Frame")
	sub_bar.BackgroundTransparency = 1
	sub_bar.BorderSizePixel = 0
	sub_bar.Position = UDim2.new(0, 0, 0, 0)
	sub_bar.Size = UDim2.new(1, 0, 0, 26)
	sub_bar.Visible = false
	sub_bar.Parent = rightPanel
	local _sub_layout = Instance.new("UIListLayout", sub_bar)
	_sub_layout.FillDirection = Enum.FillDirection.Horizontal
	_sub_layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	_sub_layout.Padding = UDim.new(0, 4)
	_sub_layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.new(0, 0, 0, 0)
	content.Size = UDim2.new(1, 0, 1, 0)
	content.ClipsDescendants = true
	content.Parent = rightPanel

	local tab_buttons: { [string]: TextButton } = {}
	local tab_containers: { [string]: Frame } = {}
	local all_sub_buttons: { [string]: { [string]: TextButton } } = {}
	local all_sub_pages: { [string]: { [string]: ScrollingFrame } } = {}

	local function make_page(): ScrollingFrame
		local page = Instance.new("ScrollingFrame")
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.fromScale(1, 1)
		page.CanvasSize = UDim2.fromOffset(0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = THEME.border
		local ul = Instance.new("UIListLayout")
		ul.SortOrder = Enum.SortOrder.LayoutOrder
		ul.Padding = UDim.new(0, 0)
		ul.Parent = page
		local up = Instance.new("UIPadding")
		up.PaddingTop = UDim.new(0, 6)
		up.PaddingBottom = UDim.new(0, 12)
		up.Parent = page
		return page
	end

	local function switch_sub(tab_name: string, sub_name: string)
		local subs = all_sub_pages[tab_name]
		local btns = all_sub_buttons[tab_name]
		if not subs then
			return
		end
		for n, pg in pairs(subs) do
			pg.Visible = (n == sub_name)
		end
		if btns then
			for n, b in pairs(btns) do
				local on = (n == sub_name)
				b.BackgroundColor3 = on and C.sub_on or C.sub_off
				b.TextColor3 = on and C.accent or C.dim
			end
		end
	end

	local function switch_tab(name: string)
		local has_subs = SUB_PAGES[name] ~= nil
		for n, cont in pairs(tab_containers) do
			cont.Visible = (n == name)
		end
		for n, b in pairs(tab_buttons) do
			local on = (n == name)
			b.BackgroundColor3 = on and C.tab_on or C.tab_off
			b.TextColor3 = on and C.accent or C.dim
		end
		sub_bar.Visible = has_subs
		if has_subs then
			content.Position = UDim2.new(0, 0, 0, 26)
			content.Size = UDim2.new(1, 0, 1, -26)
		else
			content.Position = UDim2.new(0, 0, 0, 0)
			content.Size = UDim2.new(1, 0, 1, 0)
		end
		for _, c in ipairs(sub_bar:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		if has_subs then
			local sub_names = SUB_PAGES[name]
			all_sub_buttons[name] = all_sub_buttons[name] or {}
			for i, sn in ipairs(sub_names) do
				local sb = Instance.new("TextButton")
				sb.LayoutOrder = i
				sb.BackgroundColor3 = C.sub_off
				sb.BorderSizePixel = 0
				sb.Size = UDim2.fromOffset(math.floor((INNER_CONTENT_W - 8 - (#sub_names - 1) * 4) / #sub_names), 22)
				sb.Font = Enum.Font.GothamSemibold
				sb.Text = sn
				sb.TextColor3 = C.dim
				sb.TextSize = 10
				sb.AutoButtonColor = false
				sb.Parent = sub_bar
				Instance.new("UICorner", sb).CornerRadius = UDim.new(0, THEME.corner)
				sb.MouseButton1Click:Connect(function()
					switch_sub(name, sn)
				end)
				all_sub_buttons[name][sn] = sb
			end
			switch_sub(name, sub_names[1])
		end
	end

	for i, name in ipairs(TAB_NAMES) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Name = name
		b.Text = name
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.BackgroundColor3 = C.tab_off
		b.TextColor3 = C.dim
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, -8, 0, 34)
		b.LayoutOrder = i
		b.Parent = sidebar
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, THEME.corner)
		tab_buttons[name] = b
		b.MouseButton1Click:Connect(function()
			switch_tab(name)
		end)
	end

	for _, name in ipairs(TAB_NAMES) do
		local cont = Instance.new("Frame")
		cont.BackgroundTransparency = 1
		cont.Size = UDim2.fromScale(1, 1)
		cont.Visible = false
		cont.Parent = content
		tab_containers[name] = cont
		if SUB_PAGES[name] then
			all_sub_pages[name] = {}
			for _, sn in ipairs(SUB_PAGES[name]) do
				local pg = make_page()
				pg.Visible = false
				pg.Parent = cont
				all_sub_pages[name][sn] = pg
			end
		end
	end

	local drag_con: RBXScriptConnection? = nil
	titleBar.InputBegan:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local st, sp = inp.Position, main.Position
		if drag_con then
			drag_con:Disconnect()
		end
		drag_con = uis.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				local d = i.Position - st
				main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
			end
		end)
	end)
	titleBar.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 and drag_con then
			drag_con:Disconnect()
			drag_con = nil
		end
	end)

	return {
		main = main,
		body = body,
		sidebar = sidebar,
		rightPanel = rightPanel,
		content = content,
		sub_bar = sub_bar,
		statusLabel = statusLabel,
		titleBar = titleBar,
		tab_buttons = tab_buttons,
		tab_containers = tab_containers,
		all_sub_buttons = all_sub_buttons,
		all_sub_pages = all_sub_pages,
		switch_tab = switch_tab,
		switch_sub = switch_sub,
		make_page = make_page,
		WIN_W = WIN_W,
		WIN_H = WIN_H,
		INNER_CONTENT_W = INNER_CONTENT_W,
	}
end

return M
