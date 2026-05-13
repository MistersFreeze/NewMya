return function(ctx)
	local visualsTab       = ctx.visualsTab
	local themeSync        = ctx.themeSync
	local bindRegistry     = ctx.bindRegistry
	local localPlayer      = ctx.localPlayer
	local Fluent           = ctx.Fluent
	local Workspace        = ctx.Workspace
	local UserInputService = ctx.UserInputService

	local HttpService = game:GetService("HttpService")

	local enabled = false

	-- ── Theme ─────────────────────────────────────────────────────────────────────

	local C_ACCENT = Color3.fromRGB(245, 92, 177)
	local C_TEXT   = Color3.fromRGB(245, 245, 250)
	local C_MUTED  = Color3.fromRGB(200, 170, 210)

	local function syncTheme()
		if themeSync then
			C_ACCENT = themeSync.getAccent()
			C_TEXT   = themeSync.getText()
			C_MUTED  = themeSync.getMuted()
		end
	end
	syncTheme()

	local function hex(c)
		return string.format("#%02x%02x%02x",
			math.clamp(math.floor(c.R * 255), 0, 255),
			math.clamp(math.floor(c.G * 255), 0, 255),
			math.clamp(math.floor(c.B * 255), 0, 255))
	end

	-- ── Key name formatter ────────────────────────────────────────────────────────

	local function fmtKey(k)
		if not k or k == "None" or k == "" then return nil end
		if k == "MouseLeft"    then return "LMB" end
		if k == "MouseRight"   then return "RMB" end
		if k == "MouseMiddle"  then return "MMB" end
		if k == "MouseButton4" then return "M4"  end
		if k == "MouseButton5" then return "M5"  end
		return k
	end

	-- ── Position persistence ──────────────────────────────────────────────────────

	local POS_FILE = "MyaUniversal/keybind_pos.json"
	local posX, posY = 14, 80

	pcall(function()
		if typeof(isfile) == "function" and isfile(POS_FILE) and typeof(readfile) == "function" then
			local ok, t = pcall(function() return HttpService:JSONDecode(readfile(POS_FILE)) end)
			if ok and type(t) == "table" and type(t.x) == "number" and type(t.y) == "number" then
				posX, posY = math.floor(t.x), math.floor(t.y)
			end
		end
	end)

	local function savePos()
		pcall(function()
			if typeof(writefile) ~= "function" then return end
			if typeof(makefolder) == "function" then pcall(makefolder, "MyaUniversal") end
			writefile(POS_FILE, HttpService:JSONEncode({ x = posX, y = posY }))
		end)
	end

	-- ── GUI ───────────────────────────────────────────────────────────────────────

	local kbGui, frame, label, frameStroke
	local dragConns = {}

	pcall(function()
		local guiParent = (typeof(gethui) == "function" and gethui())
			or localPlayer:WaitForChild("PlayerGui")

		kbGui = Instance.new("ScreenGui")
		kbGui.Name           = "MyaKeybindDisplay"
		kbGui.ResetOnSpawn   = false
		kbGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		kbGui.DisplayOrder   = 199
		kbGui.Enabled        = false
		pcall(function() kbGui.IgnoreGuiInset = true end)
		kbGui.Parent = guiParent

		frame = Instance.new("Frame")
		frame.BackgroundColor3       = C_ACCENT
		frame.BackgroundTransparency = 0.72
		frame.BorderSizePixel        = 0
		frame.Position               = UDim2.fromOffset(posX, posY)
		frame.Parent                 = kbGui
		pcall(function() frame.AutomaticSize = Enum.AutomaticSize.XY end)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent       = frame

		frameStroke = Instance.new("UIStroke")
		frameStroke.Color        = C_ACCENT
		frameStroke.Transparency = 0.4
		frameStroke.Thickness    = 1.5
		pcall(function() frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
		frameStroke.Parent = frame

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft   = UDim.new(0, 12)
		pad.PaddingRight  = UDim.new(0, 12)
		pad.PaddingTop    = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent        = frame

		label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.RichText               = true
		label.Font                   = Enum.Font.GothamSemibold
		label.TextSize               = 14
		label.TextColor3             = C_TEXT
		label.TextXAlignment         = Enum.TextXAlignment.Left
		label.TextYAlignment         = Enum.TextYAlignment.Top
		label.Size                   = UDim2.new(0, 160, 0, 20)
		pcall(function() label.AutomaticSize = Enum.AutomaticSize.XY end)
		label.Parent = frame

		-- ── Drag ──────────────────────────────────────────────────────────────────

		local dragging       = false
		local dragMouseStart = Vector2.zero
		local dragPosStart   = Vector2.zero

		local function isGuiOpen()
			local ok, v = pcall(function() return Fluent and Fluent.GUI and Fluent.GUI.Enabled end)
			return ok and v == true
		end

		dragConns[1] = frame.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not isGuiOpen() then return end
			dragging       = true
			dragMouseStart = UserInputService:GetMouseLocation()
			dragPosStart   = Vector2.new(posX, posY)
		end)

		dragConns[2] = UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local mouse = UserInputService:GetMouseLocation()
			local delta = mouse - dragMouseStart
			local wc = Workspace.CurrentCamera
			local vp = (wc and wc.ViewportSize) or Vector2.new(1920, 1080)
			posX = math.clamp(math.floor(dragPosStart.X + delta.X), 0, vp.X - 20)
			posY = math.clamp(math.floor(dragPosStart.Y + delta.Y), 0, vp.Y - 20)
			frame.Position = UDim2.fromOffset(posX, posY)
		end)

		dragConns[3] = UserInputService.InputEnded:Connect(function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			dragging = false
			savePos()
		end)
	end)

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(_data)
		if not enabled or not label then return end
		if themeSync and themeSync.isRGB() then themeSync.update() end
		syncTheme()

		local ha = hex(C_ACCENT)
		local ht = hex(C_TEXT)
		local hm = hex(C_MUTED)

		local lines = {}
		lines[1] = string.format('<font color="%s"><b>Keybinds</b></font>', ha)

		if bindRegistry then
			for _, entry in ipairs(bindRegistry) do
				if not entry.getEnabled() then continue end
				local key  = fmtKey(entry.getKey())
				local mode = entry.getMode and entry.getMode() or "Always"

				-- Only show entries with a real key bound (skip "Always" mode / no key).
				if not key and mode == "Always" then continue end

				local displayKey = key or "—"
				local active     = entry.isActive()
				local dot        = active
					and string.format('<font color="#78dc78">●</font>')
					or  string.format('<font color="%s">○</font>', hm)
				local keyTag = string.format('<font color="%s">[%s]</font>', ht, displayKey)
				lines[#lines + 1] = string.format(
					'<font color="%s">%s</font> %s %s',
					ht, entry.displayName, keyTag, dot
				)
			end
		end

		if #lines == 1 then
			lines[2] = string.format('<font color="%s">No binds set</font>', hm)
		end

		label.Text = table.concat(lines, "\n")

		if frame       then frame.BackgroundColor3 = C_ACCENT end
		if frameStroke then frameStroke.Color      = C_ACCENT end
	end

	-- ── UI section ────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Keybind Display")

	section:AddToggle("kbDispEn1x", {
		Title    = "Show Keybind Display",
		Icon     = "solar/keyboard-bold",
		Default  = false,
		Callback = function(v)
			enabled = v
			if kbGui then kbGui.Enabled = v end
		end,
	})

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		for _, c in ipairs(dragConns) do pcall(function() c:Disconnect() end) end
		if kbGui then pcall(function() kbGui:Destroy() end) end
	end

	return { update = update, unmount = unmount }
end
