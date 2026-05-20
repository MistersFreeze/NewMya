return function(ctx)
	local visualsTab      = ctx.visualsTab
	local Workspace       = ctx.Workspace
	local localPlayer     = ctx.localPlayer
	local UserInputService = ctx.UserInputService
	local Fluent          = ctx.Fluent
	local themeSync       = ctx.themeSync
	local baseUrl         = ctx.baseUrl

	local riftEsp    = { enabled = false, color = Color3.fromRGB(0, 0, 0), maxDist = 8000 }
	local riftWidget = { enabled = false }

	-- ── Font sync (mirrors Esp.luau approach) ────────────────────────────────────

	local InterfaceManager = ctx.InterfaceManager

	local FONT_UI   = (typeof(Drawing) == "table" and Drawing.Fonts and Drawing.Fonts.UI)       or 0
	local FONT_SYS  = (typeof(Drawing) == "table" and Drawing.Fonts and Drawing.Fonts.System)   or 1
	local FONT_MONO = (typeof(Drawing) == "table" and Drawing.Fonts and Drawing.Fonts.Monospace) or 3
	local FONT_MAP  = {
		GothamSSm = FONT_UI, Gotham = FONT_UI, GothamMedium = FONT_UI, GothamBold = FONT_UI,
		Roboto = FONT_UI, Ubuntu = FONT_UI, SourceSans = FONT_UI,
		Arial = FONT_SYS, ArialBold = FONT_SYS,
		Code = FONT_MONO, RobotoMono = FONT_MONO,
	}
	local _curFont      = FONT_UI
	local _fontSyncTick = 0

	local function readFluentFont()
		local name = "GothamSSm"
		pcall(function()
			local s = InterfaceManager and InterfaceManager.Settings
			if s and type(s.Font) == "string" then name = s.Font end
		end)
		return FONT_MAP[name] or FONT_UI
	end

	-- ── Hardcoded rift name list ───────────────────────────────────────────────────
	-- All known rift destinations in the game (user-confirmed).
	-- The widget displays this static list so players can use it as a quick
	-- reference for which rifts exist; no dynamic detection needed for the widget.

	local RIFT_NAMES = {
		"Cancel",
		"Sorythia 1", "Sorythia 2",
		"Durana 1",   "Durana 2",   "Durana 3", "Durana 4",
		"Expanse 1",  "Expanse 2",
		"Training 1", "Training 2",
		"Snow 1",     "Snow 2",     "Snow 3",
		"Rain",       "Mello",      "Rose",     "Chakra",
	}

	-- ── Rift label drawings ───────────────────────────────────────────────────────
	-- workspace.Rifts folder confirmed from dump (line 214).

	local activeRifts = {}  -- [model] = { label = Drawing.Text, conn = RBXConn }

	local function getRiftName(model)
		-- Prefer any visible TextLabel text (BillboardGui shows destination name)
		for _, v in ipairs(model:GetDescendants()) do
			if v:IsA("TextLabel") and v.Text ~= "" and #v.Text < 60 then
				return v.Text
			end
		end
		-- StringValue children
		for _, v in ipairs(model:GetChildren()) do
			if v:IsA("StringValue") and v.Value ~= "" then return v.Value end
		end
		-- Model Name when it looks descriptive
		if model.Name ~= "" and model.Name ~= "Model" and model.Name ~= "Rift" then
			return model.Name
		end
		local id = model:GetAttribute("ID")
		return id and ("Rift " .. tostring(id)) or "Rift"
	end

	local function getRiftPos(model)
		if model:IsA("Model") then
			local ok, pv = pcall(function() return model:GetPivot().Position end)
			if ok and pv then return pv end
			local pp = model:FindFirstChildWhichIsA("BasePart", true)
			return pp and pp.Position or nil
		end
		return model:IsA("BasePart") and model.Position or nil
	end

	local function addRift(model)
		if activeRifts[model] then return end
		local d = Drawing.new("Text")
		d.Text         = "⬡ " .. getRiftName(model)
		d.Color        = riftEsp.color
		d.Size         = 14
		d.Center       = true
		d.Outline      = true
		d.OutlineColor = Color3.fromRGB(255, 255, 255)
		d.ZIndex       = 5
		d.Visible      = false
		pcall(function() d.Font = _curFont end)

		local conn = model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				local e = activeRifts[model]
				if e then
					pcall(function() e.label:Remove() end)
					pcall(function() e.conn:Disconnect() end)
					activeRifts[model] = nil
				end
			end
		end)
		activeRifts[model] = { label = d, conn = conn }
	end

	local function removeRift(model)
		local e = activeRifts[model]
		if not e then return end
		pcall(function() e.label:Remove() end)
		pcall(function() e.conn:Disconnect() end)
		activeRifts[model] = nil
	end

	local _conns = {}

	local function hookFolder(folder)
		if not folder then return end
		for _, child in ipairs(folder:GetChildren()) do addRift(child) end
		table.insert(_conns, folder.ChildAdded:Connect(function(c) task.defer(addRift, c) end))
		table.insert(_conns, folder.ChildRemoved:Connect(function(c) removeRift(c) end))
	end

	local riftsFolder = Workspace:FindFirstChild("Rifts")
	if riftsFolder then
		hookFolder(riftsFolder)
	else
		table.insert(_conns, Workspace.ChildAdded:Connect(function(child)
			if child.Name == "Rifts" then hookFolder(child) end
		end))
	end

	-- ── Rift Names Widget (same visual system as Users widget) ────────────────────
	-- Loaded via widgets.luau → newOverlayFrame for exact visual consistency.
	-- Shows only rift names, no distance. Applies Fluent theme accent.

	local riftOv = nil  -- set async after widgets.luau loads

	task.spawn(function()
		if typeof(baseUrl) ~= "string" or #baseUrl == 0 then return end
		local base = baseUrl:sub(-1) == "/" and baseUrl or baseUrl .. "/"
		local widgetsSrc
		for _, url in ipairs({ base.."New_Mya/lib/widgets.luau", base.."lib/widgets.luau" }) do
			local ok, body = pcall(function() return game:HttpGet(url, true) end)
			if ok and typeof(body) == "string" and #body > 100 then
				local s = body:sub(1, 200):lower()
				if not s:find("<!doctype", 1, true) and not s:find("<html", 1, true) then
					widgetsSrc = body; break
				end
			end
		end
		if not widgetsSrc then return end
		local fn = loadstring(widgetsSrc, "@widgets")
		if not fn then return end
		local ok, widgets = pcall(fn)
		if not ok or typeof(widgets) ~= "table" or not widgets.newOverlayFrame then return end
		pcall(function()
			riftOv = widgets.newOverlayFrame({
				name         = "MyaRiftWidget",
				displayOrder = 197,
				defaultX     = 14,
				defaultY     = 340,
				posFile      = "Mya/Bloodlines/rift_widget_pos.json",
				Fluent       = Fluent,
				UIS          = UserInputService,
				textSize     = 13,
				minWidth     = 140,
				padL = 12, padR = 12, padT = 8, padB = 8,
				accentColor  = Color3.fromRGB(245, 92, 177),
				textAlign    = Enum.TextXAlignment.Left,
			})
			-- Remove resize handle TextButton added by newOverlayFrame.
			task.defer(function()
				if riftOv and riftOv.gui then
					for _, v in ipairs(riftOv.gui:GetDescendants()) do
						if v:IsA("TextButton") then pcall(function() v:Destroy() end) end
					end
				end
			end)
		end)
	end)

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local sec = visualsTab:AddSection("Rift ESP")

	sec:AddToggle("RiftESPEnable", {
		Title = "Enable", Icon = "solar/map-point-bold", Default = false,
		Callback = function(v) riftEsp.enabled = v end,
	})
	sec:AddColorpicker("RiftESPColor", {
		Title = "Color", Default = Color3.fromRGB(0, 0, 0),
		Callback = function(v) riftEsp.color = v end,
	})
	sec:AddSlider("RiftESPMaxDist", {
		Title = "Max Distance", Default = 8000, Min = 500, Max = 20000, Rounding = 0,
		Callback = function(v) riftEsp.maxDist = v end,
	})
	sec:AddToggle("RiftWidgetEn", {
		Title = "Rift Names Widget", Icon = "solar/map-point-wave-bold", Default = false,
		Callback = function(v)
			riftWidget.enabled = v
			pcall(function() if riftOv and riftOv.gui then riftOv.gui.Enabled = v end end)
		end,
	})

	-- ── Helpers ───────────────────────────────────────────────────────────────────

	local function h(c)
		return string.format("#%02x%02x%02x",
			math.clamp(math.floor(c.R*255), 0, 255),
			math.clamp(math.floor(c.G*255), 0, 255),
			math.clamp(math.floor(c.B*255), 0, 255))
	end

	-- ── Update ────────────────────────────────────────────────────────────────────

	local wLastUpdate = 0

	local function update(data)
		local cam = data.cam
		if not cam then return end
		local myChar = localPlayer.Character
		local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local myPos  = myHrp and myHrp.Position

		local now = tick()

		-- Font sync: once per second, propagate Fluent font changes to rift labels
		if now - _fontSyncTick >= 1 then
			_fontSyncTick = now
			local newFont = readFluentFont()
			if newFont ~= _curFont then
				_curFont = newFont
				for _, entry in pairs(activeRifts) do
					pcall(function() entry.label.Font = newFont end)
				end
			end
		end

		-- In-world ESP labels
		for model, entry in pairs(activeRifts) do
			if not riftEsp.enabled then entry.label.Visible = false; continue end
			local pos = getRiftPos(model)
			if not pos then entry.label.Visible = false; continue end
			local dist = myPos and (myPos - pos).Magnitude or (cam.CFrame.Position - pos).Magnitude
			if dist > riftEsp.maxDist then entry.label.Visible = false; continue end
			local sp, onScreen = cam:WorldToViewportPoint(pos + Vector3.new(0, 5, 0))
			if not onScreen or sp.Z <= 0 then entry.label.Visible = false; continue end
			entry.label.Position = Vector2.new(sp.X, sp.Y)
			entry.label.Color    = riftEsp.color
			entry.label.Visible  = true
		end

		-- Rift Names Widget — static hardcoded list, update theme colors every second
		if not (riftWidget.enabled and riftOv and riftOv.label) then return end
		if now - wLastUpdate < 1 then return end
		wLastUpdate = now

		pcall(function()
			local ts = themeSync
			local ha = ts and h(ts.getAccent()) or "#f55cb1"
			local ht = ts and h(ts.getText())   or "#f5f5fa"

			local lines = { string.format('<font color="%s"><b>Rifts</b></font>', ha) }
			for _, name in ipairs(RIFT_NAMES) do
				lines[#lines + 1] = string.format('<font color="%s">%s</font>', ht, name)
			end

			riftOv.label.Text = table.concat(lines, "\n")
			riftOv.setAccent(ts and ts.getAccent() or Color3.fromRGB(245, 92, 177))
		end)
	end

	-- ── Unmount ───────────────────────────────────────────────────────────────────

	local function unmount()
		for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
		for model in pairs(activeRifts) do removeRift(model) end
		if riftOv and riftOv.gui then pcall(function() riftOv.gui:Destroy() end) end
	end

	return { update = update, unmount = unmount }
end
