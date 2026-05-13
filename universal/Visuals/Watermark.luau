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

	-- ── Theme colors (live sync from Fluent) ──────────────────────────────────────

	local C_ACCENT = Color3.fromRGB(245, 92, 177)
	local C_TEXT   = Color3.fromRGB(245, 245, 250)
	local C_MUTED  = Color3.fromRGB(200, 170, 210)

	local function syncTheme()
		pcall(function()
			if not (Fluent and Fluent.Colors) then return end
			local fc = Fluent.Colors
			C_ACCENT = fc.Accent   or fc.Toggle or C_ACCENT
			C_TEXT   = fc.Text     or C_TEXT
			C_MUTED  = fc.SubText  or C_MUTED
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

	-- ── FPS tracker ───────────────────────────────────────────────────────────────

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

	-- ── Ping tracker (multiple fallbacks) ────────────────────────────────────────

	local pingDisplay = 0
	local pingClock   = os.clock() - 2  -- fire immediately on first update

	local function refreshPing()
		local now = os.clock()
		if now - pingClock < 1 then return end
		pingClock = now

		-- Attempt 1: Stats.Network.ServerStatsItem
		local ok, val = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value
		end)
		if ok and type(val) == "number" and val >= 0 then
			pingDisplay = math.floor(val) return
		end

		-- Attempt 2: walk Stats descendants for any "ping" named StatsItem
		local ok2, val2 = pcall(function()
			for _, d in ipairs(game:GetService("Stats"):GetDescendants()) do
				if d:IsA("StatsItem") and d.Name:lower():find("ping") then
					return d.Value
				end
			end
		end)
		if ok2 and type(val2) == "number" and val2 >= 0 then
			pingDisplay = math.floor(val2) return
		end

		-- Attempt 3: Players network info (some executors expose this)
		local ok3, val3 = pcall(function()
			return game:GetService("Players").LocalPlayer:GetNetworkPing() * 1000
		end)
		if ok3 and type(val3) == "number" and val3 >= 0 then
			pingDisplay = math.floor(val3)
		end
	end

	-- ── GUI setup (ScreenGui for rounded corners) ─────────────────────────────────

	local guiParent = (typeof(gethui) == "function" and gethui())
		or localPlayer:WaitForChild("PlayerGui")

	local wmGui = Instance.new("ScreenGui")
	wmGui.Name           = "MyaWatermark"
	wmGui.ResetOnSpawn   = false
	wmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	wmGui.DisplayOrder   = 200
	wmGui.IgnoreGuiInset = true
	wmGui.Enabled        = false
	wmGui.Parent         = guiParent

	-- Outer container (rounded, light pink transparent)
	local frame = Instance.new("Frame")
	frame.Name                 = "WatermarkFrame"
	frame.BackgroundColor3     = C_ACCENT
	frame.BackgroundTransparency = 0.72
	frame.BorderSizePixel      = 0
	frame.Position             = UDim2.fromOffset(14, 14)
	frame.AutomaticSize        = Enum.AutomaticSize.XY
	frame.Parent               = wmGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color               = C_ACCENT
	stroke.Transparency        = 0.45
	stroke.Thickness           = 1.5
	stroke.ApplyStrokeMode     = Enum.ApplyStrokeMode.Border
	stroke.Parent              = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, 14)
	pad.PaddingRight  = UDim.new(0, 14)
	pad.PaddingTop    = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent        = frame

	-- RichText label: all content in one label so UICorner/AutomaticSize work cleanly
	local label = Instance.new("TextLabel")
	label.Name                 = "WatermarkText"
	label.BackgroundTransparency = 1
	label.RichText             = true
	label.Font                 = Enum.Font.GothamSemibold
	label.TextSize             = 16
	label.TextColor3           = C_TEXT
	label.TextXAlignment       = Enum.TextXAlignment.Left
	label.AutomaticSize        = Enum.AutomaticSize.XY
	label.Size                 = UDim2.fromOffset(0, 0)
	label.Parent               = frame

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(_data)
		if not enabled then return end

		tickFPS()
		refreshPing()
		syncTheme()

		-- Rebuild RichText content
		local ha  = hex(C_ACCENT)
		local ht  = hex(C_TEXT)
		local hm  = hex(C_MUTED)
		local dot = string.format(' <font color="%s"> · </font>', hm)

		local parts = {}
		parts[#parts + 1] = string.format('<font color="%s"><b>Mya</b></font>', ha)

		if showUser then
			local pname = localPlayer.DisplayName
			if pname == "" then pname = localPlayer.Name end
			parts[#parts + 1] = string.format('<font color="%s">%s</font>', ht,
				game:GetService("HttpService"):HtmlEncode and pname or pname)
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

		-- Sync background and stroke to live theme accent
		frame.BackgroundColor3 = C_ACCENT
		stroke.Color           = C_ACCENT
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Watermark")

	section:AddToggle("wmEnable01x", {
		Title    = "Show Watermark",
		Icon     = "solar/star-bold",
		Default  = false,
		Callback = function(v)
			enabled         = v
			wmGui.Enabled   = v
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
		pcall(function() wmGui:Destroy() end)
	end

	return { update = update, unmount = unmount }
end
