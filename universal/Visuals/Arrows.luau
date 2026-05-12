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

	-- ── Pool: pre-allocated chevron pairs (2 lines each) ──────────────────────────
	-- Indexed pool keyed by slot index, not by player.
	-- The legacy pattern: grow pool on demand, reuse slots each frame.

	local MAX_TARGETS = 20
	local pool        = {}  -- pool[i] = { l1, l2 }

	local function ensurePool(n)
		while #pool < n do
			local l1 = Drawing.new("Line")
			l1.Visible   = false
			l1.Color     = color
			l1.Thickness = 2
			local l2 = Drawing.new("Line")
			l2.Visible   = false
			l2.Color     = color
			l2.Thickness = 2
			pool[#pool + 1] = { l1 = l1, l2 = l2 }
		end
	end

	local function hideSlot(i)
		local p = pool[i]
		if p then
			p.l1.Visible = false
			p.l2.Visible = false
		end
	end

	local function hideAll()
		for i = 1, #pool do hideSlot(i) end
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
	section:AddSlider("oArwOrbit1x", {
		Title    = "Ring Radius",
		Default  = 72,
		Min      = 32,
		Max      = 220,
		Rounding = 0,
		Callback = function(v) orbitRadius = v end,
	})
	section:AddSlider("oArwSize02x", {
		Title    = "Arrow Length",
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
			for _, p in ipairs(pool) do
				p.l1.Color = c
				p.l2.Color = c
			end
		end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(data)
		if not enabled then hideAll() return end

		local cam = data.cam or Workspace.CurrentCamera
		if not cam then hideAll() return end

		local camCF  = cam.CFrame
		local center = data.screenCenter

		-- Collect off-screen candidates sorted by distance (closest first).
		local off = {}
		for _, e in ipairs(data.players) do
			if isSameTeam(e.player) then continue end
			if e.onScreen then continue end
			off[#off + 1] = e
		end
		table.sort(off, function(a, b) return a.dist < b.dist end)

		local n = math.min(#off, MAX_TARGETS)
		ensurePool(n)

		-- Hide unused slots.
		for i = n + 1, #pool do hideSlot(i) end
		if n == 0 then return end

		for i = 1, n do
			local e   = off[i]
			-- Camera-local direction — robust for any target position including behind camera.
			local ld  = camCF:VectorToObjectSpace(e.rootPos - camCF.Position)
			-- Camera: X=right, Y=up, Z=backward. Screen: X=right, Y=down.
			local sx  = ld.X
			local sy  = -ld.Y
			if ld.Z >= 0 then sx, sy = -sx, -sy end  -- flip when behind camera

			local mag = math.sqrt(sx * sx + sy * sy)
			if mag < 0.001 then sx, sy = 1, 0 else sx, sy = sx / mag, sy / mag end

			-- Chevron: base at ring edge, tip beyond ring.
			local base = Vector2.new(center.X + sx * orbitRadius,         center.Y + sy * orbitRadius)
			local tip  = Vector2.new(center.X + sx * (orbitRadius + tipLen), center.Y + sy * (orbitRadius + tipLen))
			local perp = Vector2.new(-sy, sx)

			local p = pool[i]
			p.l1.From    = base + perp * halfWidth
			p.l1.To      = tip
			p.l1.Color   = color
			p.l1.Visible = true
			p.l2.From    = base - perp * halfWidth
			p.l2.To      = tip
			p.l2.Color   = color
			p.l2.Visible = true
		end
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		for _, p in ipairs(pool) do
			pcall(function() p.l1:Remove() end)
			pcall(function() p.l2:Remove() end)
		end
		pool = {}
	end

	return { update = update, unmount = unmount }
end
