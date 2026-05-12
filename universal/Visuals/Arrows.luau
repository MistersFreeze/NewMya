return function(ctx)
	local visualsTab = ctx.visualsTab
	local isSameTeam = ctx.isSameTeam
	local Workspace  = ctx.Workspace

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled     = false
	local orbitRadius = 72
	local tipLen      = 14
	local halfWidth   = 7
	local color       = Color3.fromRGB(255, 130, 175)
	local notVisColor = Color3.fromRGB(255, 165, 0)
	local visCheck    = false
	local arrowStyle  = "Chevron"

	-- ── Pool: pre-allocated per-slot drawings ─────────────────────────────────────

	local MAX_TARGETS = 20
	local pool = {}

	local function newSlot()
		local function newLine()
			local l = Drawing.new("Line")
			l.Visible   = false
			l.Color     = color
			l.Thickness = 2
			return l
		end
		local tri = Drawing.new("Triangle")
		tri.Visible   = false
		tri.Filled    = true
		tri.Color     = color
		tri.Thickness = 1

		local dot = Drawing.new("Circle")
		dot.Visible   = false
		dot.Filled    = true
		dot.Color     = color
		dot.Radius    = 5
		dot.NumSides  = 12
		dot.Thickness = 1

		return { l1 = newLine(), l2 = newLine(), l3 = newLine(), tri = tri, dot = dot }
	end

	local function ensurePool(n)
		while #pool < n do
			pool[#pool + 1] = newSlot()
		end
	end

	local function hideSlot(s)
		s.l1.Visible  = false
		s.l2.Visible  = false
		s.l3.Visible  = false
		s.tri.Visible = false
		s.dot.Visible = false
	end

	local function hideAll()
		for _, s in ipairs(pool) do hideSlot(s) end
	end

	local function applyColor(s, c)
		s.l1.Color  = c
		s.l2.Color  = c
		s.l3.Color  = c
		s.tri.Color = c
		s.dot.Color = c
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Off-Screen Arrows")

	section:AddToggle("nVc5vJwSt8", {
		Title    = "Enable Arrows",
		Icon     = "solar/arrow-right-bold",
		Default  = false,
		Callback = function(v)
			enabled = v
			if not v then hideAll() end
		end,
	})
	section:AddDropdown("arrStyle01x", {
		Title    = "Arrow Style",
		Values   = { "Chevron", "Arrow", "Triangle", "Line", "Diamond" },
		Default  = "Chevron",
		NoSearch = true,
		Callback = function(v) arrowStyle = v end,
	})
	section:AddSlider("oArwOrbit1x", {
		Title    = "Ring Radius",
		Default  = 72,
		Min      = 32,
		Max      = 220,
		Rounding = 0,
		Callback = function(v) orbitRadius = v end,
	})
	section:AddSlider("oArwSize02x", {
		Title    = "Arrow Size",
		Default  = 14,
		Min      = 6,
		Max      = 40,
		Rounding = 0,
		Callback = function(v) tipLen = v end,
	})
	section:AddColorpicker("pZe7xLyUv9", {
		Title        = "Arrow Color",
		Default      = color,
		Transparency = 0,
		Callback     = function(c)
			color = c
			for _, s in ipairs(pool) do applyColor(s, c) end
		end,
	})
	section:AddToggle("arrVisCk01x", {
		Title    = "Visibility Check",
		Default  = false,
		Callback = function(v) visCheck = v end,
	})
	section:AddColorpicker("arrNVCol01x", {
		Title        = "Hidden Color",
		Default      = notVisColor,
		Transparency = 0,
		Callback     = function(c) notVisColor = c end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function drawSlot(s, sx, sy, center, useColor)
		hideSlot(s)
		applyColor(s, useColor)

		local base = Vector2.new(center.X + sx * orbitRadius,          center.Y + sy * orbitRadius)
		local tip  = Vector2.new(center.X + sx * (orbitRadius + tipLen), center.Y + sy * (orbitRadius + tipLen))
		local perp = Vector2.new(-sy, sx)
		local bL   = base + perp * halfWidth
		local bR   = base - perp * halfWidth

		if arrowStyle == "Chevron" then
			s.l1.From = bL; s.l1.To = tip; s.l1.Visible = true
			s.l2.From = bR; s.l2.To = tip; s.l2.Visible = true

		elseif arrowStyle == "Arrow" then
			s.l1.From = bL; s.l1.To = tip; s.l1.Visible = true
			s.l2.From = bR; s.l2.To = tip; s.l2.Visible = true
			s.l3.From = bL; s.l3.To = bR;  s.l3.Visible = true

		elseif arrowStyle == "Triangle" then
			s.tri.PointA  = tip
			s.tri.PointB  = bL
			s.tri.PointC  = bR
			s.tri.Filled  = true
			s.tri.Color   = useColor
			s.tri.Visible = true

		elseif arrowStyle == "Line" then
			s.l1.From    = base
			s.l1.To      = tip
			s.l1.Visible = true

		elseif arrowStyle == "Diamond" then
			local mid  = (base + tip) * 0.5
			local dTip = tip
			local dBot = base
			local dL   = mid + perp * halfWidth
			local dR   = mid - perp * halfWidth
			-- Top half via triangle outline (tip -> L -> R).
			s.tri.PointA  = dTip
			s.tri.PointB  = dL
			s.tri.PointC  = dR
			s.tri.Filled  = false
			s.tri.Color   = useColor
			s.tri.Visible = true
			-- Bottom half via two lines (L -> bot, R -> bot).
			s.l1.From = dL; s.l1.To = dBot; s.l1.Visible = true
			s.l2.From = dR; s.l2.To = dBot; s.l2.Visible = true
		end
	end

	local function update(data)
		if not enabled then hideAll() return end

		local cam = data.cam or Workspace.CurrentCamera
		if not cam then hideAll() return end

		local camCF    = cam.CFrame
		local center   = data.screenCenter
		local scrSize  = data.screenSize

		local off = {}
		for _, e in ipairs(data.players) do
			if isSameTeam(e.player) then continue end
			-- Robust off-screen check: use depth + bounds rather than onScreen alone.
			-- Some games return onScreen=true even for players outside the viewport.
			local depth = e.depth or 0
			local sp    = e.rootSp
			local trulyOffScreen = depth <= 0
				or sp.X < -20 or sp.X > scrSize.X + 20
				or sp.Y < -20 or sp.Y > scrSize.Y + 20
			if not trulyOffScreen then continue end
			off[#off + 1] = e
		end
		table.sort(off, function(a, b) return a.dist < b.dist end)

		local n = math.min(#off, MAX_TARGETS)
		ensurePool(n)

		for i = n + 1, #pool do hideSlot(pool[i]) end
		if n == 0 then return end

		for i = 1, n do
			local e  = off[i]
			local ld = camCF:VectorToObjectSpace(e.rootPos - camCF.Position)
			local sx = ld.X
			local sy = -ld.Y
			if ld.Z >= 0 then sx, sy = -sx, -sy end
			local mag = math.sqrt(sx * sx + sy * sy)
			if mag < 0.001 then sx, sy = 1, 0 else sx, sy = sx / mag, sy / mag end

			local useColor = color
			if visCheck then
				useColor = (e.visible ~= false) and color or notVisColor
			end

			drawSlot(pool[i], sx, sy, center, useColor)
		end
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		for _, s in ipairs(pool) do
			pcall(function() s.l1:Remove() end)
			pcall(function() s.l2:Remove() end)
			pcall(function() s.l3:Remove() end)
			pcall(function() s.tri:Remove() end)
			pcall(function() s.dot:Remove() end)
		end
		pool = {}
	end

	return { update = update, unmount = unmount }
end
