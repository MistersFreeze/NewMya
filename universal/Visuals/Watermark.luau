return function(ctx)
	local visualsTab  = ctx.visualsTab
	local localPlayer = ctx.localPlayer

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled = false

	-- Palette matching Fluent Modded / Mya theme
	local C_BG      = Color3.fromRGB(13,  13,  20)
	local C_SURFACE = Color3.fromRGB(28,  18,  32)
	local C_BORDER  = Color3.fromRGB(66,  40,  72)
	local C_ACCENT  = Color3.fromRGB(245, 92,  177)
	local C_TEXT    = Color3.fromRGB(245, 245, 250)
	local C_MUTED   = Color3.fromRGB(188, 165, 196)

	-- Watermark position (top-left corner)
	local PX, PY = 12, 12

	-- Cache game name once (network call)
	local gameName = "Loading…"
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		if ok and info and info.Name then
			local n = tostring(info.Name)
			gameName = #n > 22 and n:sub(1, 20) .. "…" or n
		else
			gameName = tostring(game.Name or "Roblox")
		end
	end)

	-- ── Drawing objects ───────────────────────────────────────────────────────────

	-- Outer shadow / glow
	local shadow = Drawing.new("Square")
	shadow.Visible      = false
	shadow.Filled       = true
	shadow.Color        = Color3.fromRGB(0, 0, 0)
	shadow.Transparency = 0.6

	-- Main background
	local bg = Drawing.new("Square")
	bg.Visible      = false
	bg.Filled       = true
	bg.Color        = C_BG
	bg.Transparency = 0.15

	-- Top accent bar
	local accentBar = Drawing.new("Square")
	accentBar.Visible      = false
	accentBar.Filled       = true
	accentBar.Color        = C_ACCENT
	accentBar.Transparency = 0

	-- Bottom subtle line
	local bottomLine = Drawing.new("Line")
	bottomLine.Visible      = false
	bottomLine.Color        = C_BORDER
	bottomLine.Thickness    = 1
	bottomLine.Transparency = 0.3

	-- Left accent stripe
	local leftStripe = Drawing.new("Square")
	leftStripe.Visible      = false
	leftStripe.Filled       = true
	leftStripe.Color        = C_ACCENT
	leftStripe.Transparency = 0

	-- "Mya" title text (accent pink, bold)
	local titleTxt = Drawing.new("Text")
	titleTxt.Visible      = false
	titleTxt.Text         = "Mya"
	titleTxt.Size         = 14
	titleTxt.Font         = Drawing.Fonts.UI
	titleTxt.Color        = C_ACCENT
	titleTxt.Outline      = true
	titleTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
	titleTxt.Center       = false

	-- Separator " · "
	local sep1 = Drawing.new("Text")
	sep1.Visible      = false
	sep1.Text         = "·"
	sep1.Size         = 14
	sep1.Font         = Drawing.Fonts.UI
	sep1.Color        = C_BORDER
	sep1.Outline      = true
	sep1.OutlineColor = Color3.fromRGB(0, 0, 0)
	sep1.Center       = false

	-- Player name
	local playerTxt = Drawing.new("Text")
	playerTxt.Visible      = false
	playerTxt.Size         = 13
	playerTxt.Font         = Drawing.Fonts.UI
	playerTxt.Color        = C_TEXT
	playerTxt.Outline      = true
	playerTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
	playerTxt.Center       = false

	-- Separator " · "
	local sep2 = Drawing.new("Text")
	sep2.Visible      = false
	sep2.Text         = "·"
	sep2.Size         = 14
	sep2.Font         = Drawing.Fonts.UI
	sep2.Color        = C_BORDER
	sep2.Outline      = true
	sep2.OutlineColor = Color3.fromRGB(0, 0, 0)
	sep2.Center       = false

	-- Game name
	local gameTxt = Drawing.new("Text")
	gameTxt.Visible      = false
	gameTxt.Size         = 13
	gameTxt.Font         = Drawing.Fonts.UI
	gameTxt.Color        = C_MUTED
	gameTxt.Outline      = true
	gameTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
	gameTxt.Center       = false

	local function hideAll()
		shadow.Visible    = false
		bg.Visible        = false
		accentBar.Visible = false
		bottomLine.Visible = false
		leftStripe.Visible = false
		titleTxt.Visible  = false
		sep1.Visible      = false
		playerTxt.Visible = false
		sep2.Visible      = false
		gameTxt.Visible   = false
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Watermark")

	section:AddToggle("wmEnable01x", {
		Title    = "Show Watermark",
		Icon     = "solar/star-bold",
		Default  = false,
		Callback = function(v)
			enabled = v
			if not v then hideAll() end
		end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	-- Approximate character width for Drawing.Fonts.UI at given size.
	-- Rough: ~0.6 × size per character works for most Latin text.
	local function textWidth(str, size)
		return #str * size * 0.55
	end

	local PADDING_X = 10
	local PADDING_Y = 6
	local ACCENT_H  = 2   -- top accent bar height
	local STRIPE_W  = 3   -- left stripe width
	local GAP       = 8   -- gap between text segments

	local function update(_data)
		if not enabled then return end

		-- Build text content this frame
		local pname = localPlayer.DisplayName
		if pname == "" then pname = localPlayer.Name end

		local titleStr  = "Mya"
		local playerStr = pname
		local gameStr   = gameName

		playerTxt.Text = playerStr
		gameTxt.Text   = gameStr

		local titleW  = textWidth(titleStr,  14)
		local playerW = textWidth(playerStr, 13)
		local sepW    = textWidth("·",       14)
		local gameW   = textWidth(gameStr,   13)

		local totalW  = STRIPE_W + PADDING_X
			+ titleW + GAP + sepW + GAP + playerW + GAP + sepW + GAP + gameW
			+ PADDING_X
		local totalH  = ACCENT_H + PADDING_Y + 14 + PADDING_Y

		-- Shadow (1px offset, slightly larger)
		shadow.Position = Vector2.new(PX + 2, PY + 2)
		shadow.Size     = Vector2.new(totalW, totalH)

		-- Background
		bg.Position = Vector2.new(PX, PY)
		bg.Size     = Vector2.new(totalW, totalH)

		-- Top accent bar
		accentBar.Position = Vector2.new(PX, PY)
		accentBar.Size     = Vector2.new(totalW, ACCENT_H)

		-- Left stripe (under accent bar)
		leftStripe.Position = Vector2.new(PX, PY + ACCENT_H)
		leftStripe.Size     = Vector2.new(STRIPE_W, totalH - ACCENT_H)

		-- Bottom border line
		local byBot = PY + totalH
		bottomLine.From = Vector2.new(PX,             byBot)
		bottomLine.To   = Vector2.new(PX + totalW,    byBot)

		-- Text vertical center (one text line)
		local textY = PY + ACCENT_H + PADDING_Y

		-- "Mya" title
		local cx = PX + STRIPE_W + PADDING_X
		titleTxt.Position = Vector2.new(cx, textY)
		cx = cx + titleW + GAP

		-- · separator
		sep1.Position = Vector2.new(cx, textY)
		cx = cx + sepW + GAP

		-- Player name
		playerTxt.Position = Vector2.new(cx, textY)
		cx = cx + playerW + GAP

		-- · separator
		sep2.Position = Vector2.new(cx, textY)
		cx = cx + sepW + GAP

		-- Game name
		gameTxt.Position = Vector2.new(cx, textY)

		-- Show all
		shadow.Visible     = true
		bg.Visible         = true
		accentBar.Visible  = true
		bottomLine.Visible = true
		leftStripe.Visible = true
		titleTxt.Visible   = true
		sep1.Visible       = true
		playerTxt.Visible  = true
		sep2.Visible       = true
		gameTxt.Visible    = true
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		pcall(function() shadow:Remove()     end)
		pcall(function() bg:Remove()         end)
		pcall(function() accentBar:Remove()  end)
		pcall(function() bottomLine:Remove() end)
		pcall(function() leftStripe:Remove() end)
		pcall(function() titleTxt:Remove()   end)
		pcall(function() sep1:Remove()       end)
		pcall(function() playerTxt:Remove()  end)
		pcall(function() sep2:Remove()       end)
		pcall(function() gameTxt:Remove()    end)
	end

	return { update = update, unmount = unmount }
end
