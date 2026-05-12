return function(ctx)
	local visualsTab  = ctx.visualsTab
	local isSameTeam  = ctx.isSameTeam
	local Players     = ctx.Players
	local localPlayer = ctx.localPlayer
	local Workspace   = ctx.Workspace

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled     = false
	local style       = "Chams"
	local showName    = true
	local showHealth  = true
	local showDist    = true
	local fillColor   = Color3.fromRGB(255, 100, 150)
	local visCheck    = false
	local notVisColor = Color3.fromRGB(255, 165, 0)

	local guiParent = (typeof(gethui) == "function" and gethui())
		or localPlayer:WaitForChild("PlayerGui")
	local espGui = Instance.new("ScreenGui")
	espGui.Name           = "MyaUniversalESP"
	espGui.ResetOnSpawn   = false
	espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	espGui.Parent         = guiParent

	-- ── Per-player pool ───────────────────────────────────────────────────────────

	local pool  = {}
	local conns = {}

	local function makeEntry(player)
		local char = player.Character
		if not char then return end

		local hl = Instance.new("Highlight")
		hl.Name                = "MyaESP"
		hl.Adornee             = char
		hl.FillColor           = fillColor
		hl.FillTransparency    = 0.5
		hl.OutlineTransparency = 1
		hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Enabled             = false
		hl.Parent              = espGui

		local sq = Drawing.new("Square")
		sq.Visible   = false
		sq.Filled    = false
		sq.Thickness = 1.5
		sq.Color     = fillColor

		local cl = {}
		for i = 1, 8 do
			local l = Drawing.new("Line")
			l.Visible   = false
			l.Thickness = 1.5
			l.Color     = fillColor
			cl[i] = l
		end

		local nameTxt = Drawing.new("Text")
		nameTxt.Visible      = false
		nameTxt.Size         = 13
		nameTxt.Center       = true
		nameTxt.Outline      = true
		nameTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
		nameTxt.Color        = fillColor
		nameTxt.Font         = Drawing.Fonts.UI

		local distTxt = Drawing.new("Text")
		distTxt.Visible      = false
		distTxt.Size         = 11
		distTxt.Center       = true
		distTxt.Outline      = true
		distTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
		distTxt.Color        = Color3.fromRGB(220, 220, 220)
		distTxt.Font         = Drawing.Fonts.UI

		local hpBg = Drawing.new("Line")
		hpBg.Visible      = false
		hpBg.Color        = Color3.fromRGB(40, 40, 40)
		hpBg.Thickness    = 3
		hpBg.Transparency = 0.5

		local hpFill = Drawing.new("Line")
		hpFill.Visible      = false
		hpFill.Color        = Color3.fromRGB(0, 255, 0)
		hpFill.Thickness    = 2
		hpFill.Transparency = 0

		pool[player] = {
			hl       = hl,
			sq       = sq,
			cl       = cl,
			nameTxt  = nameTxt,
			distTxt  = distTxt,
			hpBg     = hpBg,
			hpFill   = hpFill,
			char     = char,
			head     = char:FindFirstChild("Head"),
			hrp      = char:FindFirstChild("HumanoidRootPart"),
			hidden   = true,   -- track visibility state to avoid redundant property sets
			lastColor = nil,
		}
	end

	local function removeEntry(player)
		local e = pool[player]
		if not e then return end
		pcall(function() e.hl:Destroy() end)
		pcall(function() e.sq:Remove() end)
		for _, l in ipairs(e.cl) do pcall(function() l:Remove() end) end
		pcall(function() e.nameTxt:Remove() end)
		pcall(function() e.distTxt:Remove() end)
		pcall(function() e.hpBg:Remove() end)
		pcall(function() e.hpFill:Remove() end)
		pool[player] = nil
	end

	local function hideEntry(e)
		if e.hidden then return end  -- already hidden, skip redundant sets
		e.hidden        = true
		e.hl.Enabled    = false
		e.sq.Visible    = false
		for _, l in ipairs(e.cl) do l.Visible = false end
		e.nameTxt.Visible = false
		e.distTxt.Visible = false
		e.hpBg.Visible    = false
		e.hpFill.Visible  = false
	end

	-- ── Character tracking ────────────────────────────────────────────────────────

	local function attachPlayer(player)
		if player == localPlayer then return end
		local c1 = player.CharacterAdded:Connect(function()
			task.defer(function()
				removeEntry(player)
				if enabled and not isSameTeam(player) then makeEntry(player) end
			end)
		end)
		local c2 = player.CharacterRemoving:Connect(function()
			removeEntry(player)
		end)
		conns[player] = { c1, c2 }
		if enabled and not isSameTeam(player) and player.Character then
			makeEntry(player)
		end
	end

	local function detachPlayer(player)
		removeEntry(player)
		local cs = conns[player]
		if cs then
			for _, c in ipairs(cs) do pcall(function() c:Disconnect() end) end
		end
		conns[player] = nil
	end

	local paConn = Players.PlayerAdded:Connect(attachPlayer)
	for _, player in ipairs(Players:GetPlayers()) do attachPlayer(player) end

	local function refreshAll()
		for player in pairs(pool) do removeEntry(player) end
		if not enabled then return end
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and not isSameTeam(player) then
				makeEntry(player)
			end
		end
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("ESP")

	section:AddToggle("aNv3xKpRm1", {
		Title    = "Enable ESP",
		Icon     = "solar/eye-bold",
		Default  = false,
		Callback = function(v) enabled = v; refreshAll() end,
	})
	section:AddDropdown("espStyle01x", {
		Title    = "Style",
		Values   = { "Chams", "Box", "Corners" },
		Default  = "Chams",
		NoSearch = true,
		Callback = function(v) style = v end,
	})
	section:AddToggle("cVm2yHdNp9", {
		Title    = "Name",
		Default  = true,
		Callback = function(v) showName = v end,
	})
	section:AddToggle("dZo8kJwGq5", {
		Title    = "Health Bar",
		Default  = true,
		Callback = function(v) showHealth = v end,
	})
	section:AddToggle("eWr6nAiTb3", {
		Title    = "Distance",
		Default  = true,
		Callback = function(v) showDist = v end,
	})
	section:AddColorpicker("fPt9mXvSc7", {
		Title        = "ESP Color",
		Default      = fillColor,
		Transparency = 0,
		Callback     = function(c)
			fillColor = c
			for _, e in pairs(pool) do
				pcall(function()
					e.hl.FillColor  = c
					e.sq.Color      = c
					e.nameTxt.Color = c
					for _, l in ipairs(e.cl) do l.Color = c end
				end)
			end
		end,
	})
	section:AddToggle("espVisCk01x", {
		Title    = "Visibility Check",
		Default  = false,
		Callback = function(v) visCheck = v end,
	})
	section:AddColorpicker("espNVCol01x", {
		Title        = "Hidden Color",
		Default      = notVisColor,
		Transparency = 0,
		Callback     = function(c) notVisColor = c end,
	})

	-- ── Per-frame update ──────────────────────────────────────────────────────────

	local function update(data)
		local cam = data.cam or Workspace.CurrentCamera
		if not enabled or not cam then
			for _, e in pairs(pool) do hideEntry(e) end
			return
		end

		local seen = {}

		for _, entry in ipairs(data.players) do
			local player = entry.player
			if isSameTeam(player) then continue end

			local e = pool[player]
			if not e then continue end
			seen[player] = true

			if not entry.onScreen then
				hideEntry(e)
				continue
			end

			-- Refresh character refs only when char changed.
			local char = entry.char or player.Character
			if char ~= e.char then
				e.char      = char
				e.head      = char and char:FindFirstChild("Head")
				e.hrp       = char and char:FindFirstChild("HumanoidRootPart")
				e.lastColor = nil  -- force color refresh
				pcall(function() e.hl.Adornee = char end)
			end
			if char and not e.head then e.head = char:FindFirstChild("Head") end
			if char and not e.hrp  then e.hrp  = char:FindFirstChild("HumanoidRootPart") end

			local curColor = (visCheck and e.visible == false) and notVisColor or fillColor

			-- Only update Highlight properties when something changed.
			local isChams = style == "Chams"
			if e.hl.Enabled ~= isChams then e.hl.Enabled = isChams end
			if isChams and curColor ~= e.lastColor then
				e.hl.FillColor = curColor
			end
			e.lastColor = curColor
			e.hidden    = false

			-- Bounding box (skip WorldToViewportPoint for Chams — no box needed).
			local boxOk = false
			local topLeft, boxW, boxH

			if style ~= "Chams" and e.head and e.hrp then
				local topVP = cam:WorldToViewportPoint(e.head.Position + Vector3.new(0, 0.35, 0))
				local botVP = cam:WorldToViewportPoint(e.hrp.Position  - Vector3.new(0, 2.5, 0))
				if topVP.Z > 0 and botVP.Z > 0 then
					local byTop = math.min(topVP.Y, botVP.Y) - 2
					local byBot = math.max(topVP.Y, botVP.Y)
					local bh    = byBot - byTop
					if bh > 2 then
						boxOk   = true
						boxH    = bh
						boxW    = bh * 0.55
						topLeft = Vector2.new(entry.rootSp.X - boxW * 0.5, byTop)
					end
				end
			end

			-- Box / Corners
			if style == "Box" and boxOk then
				e.sq.Position = topLeft
				e.sq.Size     = Vector2.new(boxW, boxH)
				e.sq.Color    = curColor
				e.sq.Visible  = true
				if #e.cl > 0 and e.cl[1].Visible then
					for _, l in ipairs(e.cl) do l.Visible = false end
				end
			elseif style == "Corners" and boxOk then
				if e.sq.Visible then e.sq.Visible = false end
				local x1, y1 = topLeft.X, topLeft.Y
				local x2, y2 = topLeft.X + boxW, topLeft.Y + boxH
				local cw, ch = boxW * 0.25, boxH * 0.25
				local cl     = e.cl
				cl[1].From = Vector2.new(x1, y1); cl[1].To = Vector2.new(x1+cw, y1)
				cl[2].From = Vector2.new(x1, y1); cl[2].To = Vector2.new(x1, y1+ch)
				cl[3].From = Vector2.new(x2, y1); cl[3].To = Vector2.new(x2-cw, y1)
				cl[4].From = Vector2.new(x2, y1); cl[4].To = Vector2.new(x2, y1+ch)
				cl[5].From = Vector2.new(x1, y2); cl[5].To = Vector2.new(x1+cw, y2)
				cl[6].From = Vector2.new(x1, y2); cl[6].To = Vector2.new(x1, y2-ch)
				cl[7].From = Vector2.new(x2, y2); cl[7].To = Vector2.new(x2-cw, y2)
				cl[8].From = Vector2.new(x2, y2); cl[8].To = Vector2.new(x2, y2-ch)
				for i = 1, 8 do cl[i].Color = curColor; cl[i].Visible = true end
			else
				if e.sq.Visible then e.sq.Visible = false end
				for _, l in ipairs(e.cl) do
					if l.Visible then l.Visible = false end
				end
			end

			-- Health bar
			if showHealth and boxOk then
				local bx  = topLeft.X + boxW + 4
				local byT = topLeft.Y + 2
				local byB = topLeft.Y + boxH
				local pct = entry.hpPct
				e.hpBg.From    = Vector2.new(bx, byT)
				e.hpBg.To      = Vector2.new(bx, byB)
				e.hpBg.Visible = true
				e.hpFill.From    = Vector2.new(bx, byB - boxH * pct)
				e.hpFill.To      = Vector2.new(bx, byB)
				e.hpFill.Color   = Color3.fromRGB(
					math.floor(255 * (1 - pct)),
					math.floor(255 * pct), 0)
				e.hpFill.Visible = true
			else
				if e.hpBg.Visible   then e.hpBg.Visible   = false end
				if e.hpFill.Visible then e.hpFill.Visible = false end
			end

			-- Name label
			if showName and e.head then
				local hv = cam:WorldToViewportPoint(e.head.Position + Vector3.new(0, 2.45, 0))
				if hv.Z > 0 then
					local disp = player.DisplayName
					e.nameTxt.Text     = (typeof(disp)=="string" and disp~="") and disp or player.Name
					e.nameTxt.Position = Vector2.new(hv.X, hv.Y)
					e.nameTxt.Color    = curColor
					e.nameTxt.Visible  = true
				else
					if e.nameTxt.Visible then e.nameTxt.Visible = false end
				end
			else
				if e.nameTxt.Visible then e.nameTxt.Visible = false end
			end

			-- Distance label
			if showDist then
				local fv = cam:WorldToViewportPoint(entry.rootPos - Vector3.new(0, 3.2, 0))
				if fv.Z > 0 then
					e.distTxt.Text     = string.format("%.0fm", entry.dist)
					e.distTxt.Position = Vector2.new(fv.X, fv.Y)
					e.distTxt.Visible  = true
				else
					if e.distTxt.Visible then e.distTxt.Visible = false end
				end
			else
				if e.distTxt.Visible then e.distTxt.Visible = false end
			end
		end

		for player, e in pairs(pool) do
			if not seen[player] then hideEntry(e) end
		end
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		pcall(function() paConn:Disconnect() end)
		for player in pairs(conns) do detachPlayer(player) end
		for player in pairs(pool) do removeEntry(player) end
		pcall(function() espGui:Destroy() end)
	end

	return { update = update, unmount = unmount, onPlayerRemoving = detachPlayer }
end
