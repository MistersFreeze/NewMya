return function(ctx)
	local visualsTab  = ctx.visualsTab
	local localPlayer = ctx.localPlayer
	local Fluent      = ctx.Fluent

	-- ── Options ───────────────────────────────────────────────────────────────────

	local enabled     = false
	local showUser    = true
	local showGame    = true
	local showExec    = false
	local showFPS     = true
	local showPing    = true

	-- ── Theme color sync ──────────────────────────────────────────────────────────
	-- Reads Fluent's live color palette so the watermark follows theme changes.

	local C_ACCENT = Color3.fromRGB(245, 92, 177)
	local C_BG     = Color3.fromRGB(13,  13,  20)
	local C_TEXT   = Color3.fromRGB(245, 245, 250)
	local C_MUTED  = Color3.fromRGB(188, 165, 196)
	local C_BORDER = Color3.fromRGB(66,  40,  72)

	local function syncTheme()
		pcall(function()
			if not (Fluent and Fluent.Colors) then return end
			local fc = Fluent.Colors
			C_ACCENT = fc.Accent         or fc.Toggle         or C_ACCENT
			C_BG     = fc.Background     or fc.Darker         or C_BG
			C_TEXT   = fc.Text           or C_TEXT
			C_MUTED  = fc.SubText        or C_MUTED
			C_BORDER = fc.InElementBorder or C_BORDER
		end)
	end
	syncTheme()

	-- ── Static data ───────────────────────────────────────────────────────────────

	-- Executor name (detected once)
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

	-- Game name (async fetch)
	local gameName = "…"
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		local raw = (ok and info and info.Name) and tostring(info.Name) or (game.Name or "Roblox")
		gameName = #raw > 24 and raw:sub(1, 22) .. "…" or raw
	end)

	-- ── FPS & Ping trackers ───────────────────────────────────────────────────────

	local fpsDisplay = 60
	local fpsClock   = os.clock()
	local fpsFrames  = 0

	local pingDisplay = 0
	local pingClock   = os.clock()

	local function updateFPS()
		fpsFrames = fpsFrames + 1
		local now = os.clock()
		local dt  = now - fpsClock
		if dt >= 0.5 then
			fpsDisplay = math.max(1, math.floor(fpsFrames / dt))
			fpsFrames  = 0
			fpsClock   = now
		end
	end

	local function updatePing()
		local now = os.clock()
		if now - pingClock < 1 then return end
		pingClock = now
		pcall(function()
			pingDisplay = math.floor(
				game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value
			)
		end)
	end

	-- ── Drawing objects ───────────────────────────────────────────────────────────

	local OUT = Color3.fromRGB(0, 0, 0)

	local function newText(sz, col)
		local t = Drawing.new("Text")
		t.Visible      = false
		t.Size         = sz
		t.Font         = Drawing.Fonts.UI
		t.Color        = col
		t.Outline      = true
		t.OutlineColor = OUT
		t.Center       = false
		return t
	end

	-- Background layers
	local shadow     = Drawing.new("Square")
	shadow.Filled       = true
	shadow.Color        = OUT
	shadow.Transparency = 0.65
	shadow.Visible      = false

	local bg         = Drawing.new("Square")
	bg.Filled           = true
	bg.Transparency     = 0.12
	bg.Visible          = false

	local accentTop  = Drawing.new("Square")
	accentTop.Filled    = true
	accentTop.Transparency = 0
	accentTop.Visible   = false

	local leftBar    = Drawing.new("Square")
	leftBar.Filled      = true
	leftBar.Transparency = 0
	leftBar.Visible     = false

	local botLine    = Drawing.new("Line")
	botLine.Thickness   = 1
	botLine.Transparency = 0.4
	botLine.Visible     = false

	-- Text segments: title + optional items separated by dots
	local titleTxt  = newText(17, C_ACCENT)   titleTxt.Text = "Mya"
	local userTxt   = newText(15, C_TEXT)
	local gameTxt   = newText(15, C_MUTED)
	local execTxt   = newText(15, C_MUTED)
	local fpsTxt    = newText(15, C_TEXT)
	local pingTxt   = newText(15, C_TEXT)

	-- Separators (one per possible gap: up to 5)
	local SEPS = {}
	for i = 1, 5 do
		local s = newText(15, C_BORDER)
		s.Text = "·"
		SEPS[i] = s
	end

	local ALL_DRAW = { shadow, bg, accentTop, leftBar, botLine,
		titleTxt, userTxt, gameTxt, execTxt, fpsTxt, pingTxt }
	for _, s in ipairs(SEPS) do ALL_DRAW[#ALL_DRAW + 1] = s end

	local function hideAll()
		for _, d in ipairs(ALL_DRAW) do d.Visible = false end
	end

	-- ── Layout constants ──────────────────────────────────────────────────────────

	local PX       = 14    -- screen X origin
	local PY       = 14    -- screen Y origin
	local PAD_X    = 14    -- horizontal inner padding
	local PAD_Y    = 9     -- vertical inner padding
	local TOP_H    = 3     -- top accent bar height
	local LEFT_W   = 4     -- left accent stripe width
	local GAP      = 12    -- gap between segments
	local TITLE_SZ = 17
	local ITEM_SZ  = 15

	-- Rough char-width estimate for Drawing.Fonts.UI
	local function tw(str, sz) return #tostring(str) * sz * 0.55 end

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(_data)
		if not enabled then return end

		syncTheme()
		updateFPS()
		updatePing()

		-- Apply live theme colors
		bg.Color        = C_BG
		accentTop.Color = C_ACCENT
		leftBar.Color   = C_ACCENT
		botLine.Color   = C_BORDER
		titleTxt.Color  = C_ACCENT
		userTxt.Color   = C_TEXT
		gameTxt.Color   = C_MUTED
		execTxt.Color   = C_MUTED
		fpsTxt.Color    = C_TEXT
		pingTxt.Color   = C_TEXT
		for _, s in ipairs(SEPS) do s.Color = C_BORDER end

		-- Build the list of active segments this frame
		local pname = localPlayer.DisplayName
		if pname == "" then pname = localPlayer.Name end

		local segments = {}  -- { drawObj, text, fontSize }
		if showUser then
			userTxt.Text = pname
			segments[#segments + 1] = { userTxt, pname, ITEM_SZ }
		end
		if showGame then
			gameTxt.Text = gameName
			segments[#segments + 1] = { gameTxt, gameName, ITEM_SZ }
		end
		if showExec then
			execTxt.Text = execName
			segments[#segments + 1] = { execTxt, execName, ITEM_SZ }
		end
		if showFPS then
			local fstr = fpsDisplay .. " FPS"
			fpsTxt.Text = fstr
			segments[#segments + 1] = { fpsTxt, fstr, ITEM_SZ }
		end
		if showPing then
			local pstr = pingDisplay .. " ms"
			pingTxt.Text = pstr
			segments[#segments + 1] = { pingTxt, pstr, ITEM_SZ }
		end

		-- Measure total width
		local totalContentW = tw("Mya", TITLE_SZ)
		local sepW = tw("·", ITEM_SZ)
		for i = 1, #segments do
			totalContentW = totalContentW + GAP + sepW + GAP + tw(segments[i][2], ITEM_SZ)
		end

		local totalW = LEFT_W + PAD_X + totalContentW + PAD_X
		local totalH = TOP_H  + PAD_Y + TITLE_SZ + PAD_Y

		-- Position background layers
		shadow.Position   = Vector2.new(PX + 3, PY + 3)
		shadow.Size       = Vector2.new(totalW, totalH)
		bg.Position       = Vector2.new(PX, PY)
		bg.Size           = Vector2.new(totalW, totalH)
		accentTop.Position = Vector2.new(PX, PY)
		accentTop.Size    = Vector2.new(totalW, TOP_H)
		leftBar.Position  = Vector2.new(PX, PY + TOP_H)
		leftBar.Size      = Vector2.new(LEFT_W, totalH - TOP_H)
		botLine.From      = Vector2.new(PX,          PY + totalH)
		botLine.To        = Vector2.new(PX + totalW, PY + totalH)

		-- Position text segments
		local textY = PY + TOP_H + PAD_Y
		local cx    = PX + LEFT_W + PAD_X

		titleTxt.Position = Vector2.new(cx, textY)
		titleTxt.Visible  = true
		cx = cx + tw("Mya", TITLE_SZ)

		-- Hide all separators and item texts first, then re-show as needed
		for _, s in ipairs(SEPS)  do s.Visible      = false end
		userTxt.Visible  = false
		gameTxt.Visible  = false
		execTxt.Visible  = false
		fpsTxt.Visible   = false
		pingTxt.Visible  = false

		for i, seg in ipairs(segments) do
			local sep = SEPS[i]
			cx = cx + GAP
			sep.Position = Vector2.new(cx, textY)
			sep.Visible  = true
			cx = cx + sepW + GAP

			seg[1].Position = Vector2.new(cx, textY)
			seg[1].Visible  = true
			cx = cx + tw(seg[2], ITEM_SZ)
		end

		shadow.Visible    = true
		bg.Visible        = true
		accentTop.Visible = true
		leftBar.Visible   = true
		botLine.Visible   = true
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Watermark")

	section:AddToggle("wmEnable01x", {
		Title    = "Show Watermark",
		Icon     = "solar/star-bold",
		Default  = false,
		Callback = function(v) enabled = v; if not v then hideAll() end end,
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
		for _, d in ipairs(ALL_DRAW) do pcall(function() d:Remove() end) end
	end

	return { update = update, unmount = unmount }
end
