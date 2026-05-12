return function(ctx)
	local visualsTab = ctx.visualsTab
	local isSameTeam = ctx.isSameTeam

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled = false
	local origin  = "Bottom"
	local color   = Color3.fromRGB(255, 100, 150)

	-- ── Drawing pool ──────────────────────────────────────────────────────────────

	local pool = {}

	local function make()
		local line = Drawing.new("Line")
		line.Visible   = false
		line.Thickness = 1.2
		line.Color     = color
		return line
	end

	local function remove(player)
		local line = pool[player]
		if not line then return end
		pcall(function() line:Remove() end)
		pool[player] = nil
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Tracers")

	section:AddToggle("gKu1lBzOh2", {
		Title    = "Enable Tracers",
		Icon     = "solar/share-bold",
		Default  = false,
		Callback = function(v)
			enabled = v
			if not v then
				for _, line in pairs(pool) do pcall(function() line.Visible = false end) end
			end
		end,
	})
	section:AddDropdown("hRj4nCwEf8", {
		Title    = "Origin",
		Values   = { "Bottom", "Center" },
		Default  = "Bottom",
		NoSearch = true,
		Callback = function(v) origin = v end,
	})
	section:AddColorpicker("iYs6pDxMk0", {
		Title        = "Tracer Color",
		Default      = color,
		Transparency = 0,
		Callback     = function(c)
			color = c
			for _, line in pairs(pool) do pcall(function() line.Color = c end) end
		end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(data)
		if not enabled then
			for _, line in pairs(pool) do pcall(function() line.Visible = false end) end
			return
		end

		local screenSize   = data.screenSize
		local screenCenter = data.screenCenter
		local fromPos      = Vector2.new(
			screenCenter.X,
			origin == "Center" and screenCenter.Y or screenSize.Y
		)

		local active = {}
		for _, e in ipairs(data.players) do
			if isSameTeam(e.player) then continue end
			if not e.onScreen then continue end
			active[e.player] = true

			local line = pool[e.player]
			if not line then
				line = make()
				pool[e.player] = line
			end
			line.From    = fromPos
			line.To      = e.rootSp
			line.Color   = color
			line.Visible = true
		end

		-- Hide lines for players no longer on screen; remove for players who left.
		local stale = {}
		for p in pairs(pool) do
			if not active[p] then stale[#stale + 1] = p end
		end
		for _, p in ipairs(stale) do
			pcall(function() pool[p].Visible = false end)
		end
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		local all = {}
		for p in pairs(pool) do all[#all + 1] = p end
		for _, p in ipairs(all) do remove(p) end
	end

	return { update = update, unmount = unmount, onPlayerRemoving = remove }
end
