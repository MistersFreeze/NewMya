return function(ctx)
	local visualsTab = ctx.visualsTab

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled = false
	local radius  = 120
	local style   = "Line"
	local color   = Color3.fromRGB(255, 255, 255)

	-- ── Drawing objects ───────────────────────────────────────────────────────────

	local circle = Drawing.new("Circle")
	circle.Visible   = false
	circle.Radius    = radius
	circle.Thickness = 1.5
	circle.Color     = color
	circle.Filled    = false
	circle.NumSides  = 64

	local DOT_COUNT = 48
	local dots = {}
	for i = 1, DOT_COUNT do
		local d = Drawing.new("Circle")
		d.Visible  = false
		d.Radius   = 2.5
		d.Filled   = true
		d.NumSides = 8
		d.Color    = color
		dots[i] = d
	end

	local function hideDots()
		for _, d in ipairs(dots) do d.Visible = false end
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("FOV Circle")

	section:AddToggle("jQn7rFyNl5", {
		Title    = "Enable FOV",
		Icon     = "solar/target-bold",
		Default  = false,
		Callback = function(v)
			enabled = v
			if not v then
				circle.Visible = false
				hideDots()
			end
		end,
	})
	section:AddSlider("kTm3sGvOp1", {
		Title    = "Radius",
		Default  = 120,
		Min      = 10,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) radius = v end,
	})
	section:AddDropdown("lWo9tHxPq6", {
		Title    = "Style",
		Values   = { "Line", "Dotted" },
		Default  = "Line",
		NoSearch = true,
		Callback = function(v)
			style = v
			if not enabled then return end
			if v == "Line" then hideDots() else circle.Visible = false end
		end,
	})
	section:AddColorpicker("mXb2uIzRs4", {
		Title        = "FOV Color",
		Default      = color,
		Transparency = 0,
		Callback     = function(c)
			color = c
			circle.Color = c
			for _, d in ipairs(dots) do d.Color = c end
		end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local TWO_PI = math.pi * 2

	local function update(data)
		if not enabled then return end
		local cx = data.screenCenter.X
		local cy = data.screenCenter.Y
		if style == "Line" then
			hideDots()
			circle.Position = data.screenCenter
			circle.Radius   = radius
			circle.Color    = color
			circle.Visible  = true
		else
			circle.Visible = false
			for i, d in ipairs(dots) do
				local angle = (i / DOT_COUNT) * TWO_PI
				d.Position = Vector2.new(
					cx + math.cos(angle) * radius,
					cy + math.sin(angle) * radius
				)
				d.Color   = color
				d.Visible = true
			end
		end
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		pcall(function() circle:Remove() end)
		for _, d in ipairs(dots) do pcall(function() d:Remove() end) end
	end

	return { update = update, unmount = unmount }
end
