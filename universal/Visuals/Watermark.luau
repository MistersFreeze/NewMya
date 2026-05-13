return function(ctx)
	local visualsTab  = ctx.visualsTab
	local localPlayer = ctx.localPlayer
	local Fluent      = ctx.Fluent

	-- ── Options ───────────────────────────────────────────────────────────────────

	local enabled  = false
	local showUser = true
	local showGame = true
	local showExec = false
	local showFPS  = true
	local showPing = true

	-- ── Theme colors ──────────────────────────────────────────────────────────────

	local C_ACCENT = Color3.fromRGB(245, 92, 177)
	local C_TEXT   = Color3.fromRGB(245, 245, 250)
	local C_MUTED  = Color3.fromRGB(200, 170, 210)

	local function syncTheme()
		pcall(function()
			if not (Fluent and Fluent.Colors) then return end
			local fc = Fluent.Colors
			C_ACCENT = fc.Accent  or fc.Toggle or C_ACCENT
			C_TEXT   = fc.Text    or C_TEXT
			C_MUTED  = fc.SubText or C_MUTED
		end)
	end
	syncTheme()

	local function hex(c)
		return string.format("#%02x%02x%02x",
			math.clamp(math.floor(c.R * 255), 0, 255),
			math.clamp(math.floor(c.G * 255), 0, 255),
			math.clamp(math.floor(c.B * 255), 0, 255))
	end

	-- ── Static data ───────────────────────────────────────────────────────────────

	local execName = "Unknown"
	pcall(function()
		if typeof(getexecutorname) == "function" then
			local ok, n = pcall(getexecutorname)
			if ok and typeof(n) == "string" and #n > 0 then execName = n return end
		end
		if typeof(identifyexecutor) == "function" then
			local ok, n = pcall(identifyexecutor)
			if ok and typeof(n) == "string" and #n > 0 then execName = n return end
		end
	end)

	local gameName = "…"
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		local raw = (ok and info and info.Name) and tostring(info.Name)
			or (game.Name or "Roblox")
		gameName = #raw > 26 and raw:sub(1, 24) .. "…" or raw
	end)

	-- ── FPS & Ping ────────────────────────────────────────────────────────────────

	local fpsDisplay = 60
	local fpsClock   = os.clock()
	local fpsFrames  = 0

	local function tickFPS()
		fpsFrames = fpsFrames + 1
		local now = os.clock()
		local dt  = now - fpsClock
		if dt >= 0.5 then
			fpsDisplay = math.max(1, math.floor(fpsFrames / dt))
			fpsFrames  = 0
			fpsClock   = now
		end
	end

	local pingDisplay = 0
	local pingClock   = os.clock() - 2

	local function refreshPing()
		local now = os.clock()
		if now - pingClock < 1 then return end
		pingClock = now
		local ok, val = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value
		end)
		if ok and type(val) == "number" and val >= 0 then pingDisplay = math.floor(val) return end
		local ok2, val2 = pcall(function()
			for _, d in ipairs(game:GetService("Stats"):GetDescendants()) do
				if d:IsA("StatsItem") and d.Name:lower():find("ping") then return d.Value end
			end
		end)
		if ok2 and type(val2) == "number" and val2 >= 0 then pingDisplay = math.floor(val2) end
	end

	-- ── GUI (ScreenGui + Frame + UICorner for rounded look) ───────────────────────

	local wmGui, frame, label, frameStroke
	pcall(function()
		local guiParent = (typeof(gethui) == "function" and gethui())
			or localPlayer:WaitForChild("PlayerGui")

		wmGui = Instance.new("ScreenGui")
		wmGui.Name           = "MyaWatermark"
		wmGui.ResetOnSpawn   = false
		wmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		wmGui.DisplayOrder   = 200
		wmGui.Enabled        = false
		pcall(function() wmGui.IgnoreGuiInset = true end)
		wmGui.Parent = guiParent

		frame = Instance.new("Frame")
		frame.BackgroundColor3       = C_ACCENT
		frame.BackgroundTransparency = 0.72
		frame.BorderSizePixel        = 0
		frame.Position               = UDim2.fromOffset(14, 14)
		frame.Parent                 = wmGui
		pcall(function() frame.AutomaticSize = Enum.AutomaticSize.XY end)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent       = frame

		frameStroke = Instance.new("UIStroke")
		frameStroke.Color       = C_ACCENT
		frameStroke.Transparency = 0.4
		frameStroke.Thickness   = 1.5
		pcall(function() frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
		frameStroke.Parent = frame

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft   = UDim.new(0, 14)
		pad.PaddingRight  = UDim.new(0, 14)
		pad.PaddingTop    = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent        = frame

		label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.RichText               = true
		label.Font                   = Enum.Font.GothamSemibold
		label.TextSize               = 16
		label.TextColor3             = C_TEXT
		label.TextXAlignment         = Enum.TextXAlignment.Left
		label.Size                   = UDim2.new(0, 200, 0, 22)
		pcall(function() label.AutomaticSize = Enum.AutomaticSize.XY end)
		label.Parent = frame
	end)

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(_data)
		if not enabled or not wmGui or not label then return end

		tickFPS()
		refreshPing()
		syncTheme()

		local ha  = hex(C_ACCENT)
		local ht  = hex(C_TEXT)
		local hm  = hex(C_MUTED)
		local dot = string.format(' <font color="%s"> · </font>', hm)

		local parts = {}
		parts[#parts + 1] = string.format('<font color="%s"><b>Mya</b></font>', ha)

		if showUser then
			local pname = localPlayer.DisplayName
			if pname == "" then pname = localPlayer.Name end
			parts[#parts + 1] = string.format('<font color="%s">%s</font>', ht, pname)
		end
		if showGame then
			parts[#parts + 1] = string.format('<font color="%s">%s</font>', hm, gameName)
		end
		if showExec then
			parts[#parts + 1] = string.format('<font color="%s">%s</font>', hm, execName)
		end
		if showFPS then
			parts[#parts + 1] = string.format('<font color="%s">%d FPS</font>', ht, fpsDisplay)
		end
		if showPing then
			parts[#parts + 1] = string.format('<font color="%s">%d ms</font>', ht, pingDisplay)
		end

		label.Text = table.concat(parts, dot)

		if frame then
			frame.BackgroundColor3 = C_ACCENT
		end
		if frameStroke then
			frameStroke.Color = C_ACCENT
		end
	end

	-- ── UI (added regardless of ScreenGui success) ────────────────────────────────

	local section = visualsTab:AddSection("Watermark")

	section:AddToggle("wmEnable01x", {
		Title    = "Show Watermark",
		Icon     = "solar/star-bold",
		Default  = false,
		Callback = function(v)
			enabled = v
			if wmGui then wmGui.Enabled = v end
		end,
	})
	section:AddToggle("wmUser001x", {
		Title    = "Username",
		Default  = true,
		Callback = function(v) showUser = v end,
	})
	section:AddToggle("wmGame001x", {
		Title    = "Game Name",
		Default  = true,
		Callback = function(v) showGame = v end,
	})
	section:AddToggle("wmExec01x", {
		Title    = "Injector Name",
		Default  = false,
		Callback = function(v) showExec = v end,
	})
	section:AddToggle("wmFPS0001x", {
		Title    = "FPS",
		Default  = true,
		Callback = function(v) showFPS = v end,
	})
	section:AddToggle("wmPing01x", {
		Title    = "Ping",
		Default  = true,
		Callback = function(v) showPing = v end,
	})

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		if wmGui then pcall(function() wmGui:Destroy() end) end
	end

	return { update = update, unmount = unmount }
end
