return function(ctx)
	local visualsTab = ctx.visualsTab
	local isSameTeam = ctx.isSameTeam
	local Workspace  = ctx.Workspace

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled   = false
	local color     = Color3.fromRGB(255, 100, 150)
	local headDotOn = false
	local HEAD_DOT_RADIUS = 5  -- fixed screen-space radius in pixels

	-- ── Bone definitions ──────────────────────────────────────────────────────────

	local R15_BONES = {
		{ "Head",          "UpperTorso"    },
		{ "UpperTorso",    "LowerTorso"    },
		{ "UpperTorso",    "LeftUpperArm"  },
		{ "LeftUpperArm",  "LeftLowerArm"  },
		{ "LeftLowerArm",  "LeftHand"      },
		{ "UpperTorso",    "RightUpperArm" },
		{ "RightUpperArm", "RightLowerArm" },
		{ "RightLowerArm", "RightHand"     },
		{ "LowerTorso",    "LeftUpperLeg"  },
		{ "LeftUpperLeg",  "LeftLowerLeg"  },
		{ "LeftLowerLeg",  "LeftFoot"      },
		{ "LowerTorso",    "RightUpperLeg" },
		{ "RightUpperLeg", "RightLowerLeg" },
		{ "RightLowerLeg", "RightFoot"     },
	}

	local R6_BONES = {
		{ "Head",  "Torso"    },
		{ "Torso", "Left Arm" },
		{ "Torso", "Right Arm"},
		{ "Torso", "Left Leg" },
		{ "Torso", "Right Leg"},
	}

	local MAX_LINES = #R15_BONES  -- 14

	-- ── Drawing pool ──────────────────────────────────────────────────────────────
	-- pool[player] = { lines, dot, char, partRefs, bones }

	local pool = {}

	local function makeEntry()
		local lines = {}
		for i = 1, MAX_LINES do
			local l = Drawing.new("Line")
			l.Visible   = false
			l.Thickness = 1.2
			l.Color     = color
			lines[i] = l
		end

		local dot = Drawing.new("Circle")
		dot.Visible      = false
		dot.Filled       = false
		dot.Thickness    = 1.2
		dot.NumSides     = 16
		dot.Color        = color
		dot.Radius       = HEAD_DOT_RADIUS

		return { lines = lines, dot = dot, char = nil, partRefs = {}, bones = nil }
	end

	local function removeEntry(player)
		local p = pool[player]
		if not p then return end
		for _, l in ipairs(p.lines) do pcall(function() l:Remove() end) end
		pcall(function() p.dot:Remove() end)
		pool[player] = nil
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = visualsTab:AddSection("Skeleton")

	section:AddToggle("sKelEsp01x", {
		Title    = "Enable Skeleton",
		Icon     = "solar/people-nearby-bold",
		Default  = false,
		Callback = function(v) enabled = v end,
	})
	section:AddToggle("sKelDot01x", {
		Title    = "Head Dot",
		Default  = false,
		Callback = function(v)
			headDotOn = v
			if not v then
				for _, p in pairs(pool) do pcall(function() p.dot.Visible = false end) end
			end
		end,
	})
	section:AddColorpicker("sKelEsp02x", {
		Title        = "Skeleton Color",
		Default      = color,
		Transparency = 0,
		Callback     = function(c)
			color = c
			for _, p in pairs(pool) do
				for _, l in ipairs(p.lines) do pcall(function() l.Color = c end) end
				pcall(function() p.dot.Color = c end)
			end
		end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(data)
		if not enabled then
			for _, p in pairs(pool) do
				for _, l in ipairs(p.lines) do pcall(function() l.Visible = false end) end
				pcall(function() p.dot.Visible = false end)
			end
			return
		end

		local cam = data.cam or Workspace.CurrentCamera
		if not cam then return end

		local active = {}

		for _, e in ipairs(data.players) do
			if not e.onScreen then continue end
			if isSameTeam(e.player) then continue end
			active[e.player] = true

			local char = e.char or e.player.Character
			if not char then continue end

			local p = pool[e.player]
			if not p then
				p = makeEntry()
				pool[e.player] = p
			end

			-- Invalidate cached refs on respawn.
			if char ~= p.char then
				p.char     = char
				p.partRefs = {}
				p.bones    = nil
			end

			if not p.bones then
				p.bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
			end

			-- Project a part name to screen space; cache Part refs to skip FindFirstChild each frame.
			local function getSP(partName)
				local part = p.partRefs[partName]
				if part == false then return nil end
				if not part then
					part = char:FindFirstChild(partName)
					p.partRefs[partName] = part or false
					if not part then return nil end
				end
				local v = cam:WorldToViewportPoint(part.Position)
				return Vector2.new(v.X, v.Y)
			end

			-- Skeleton lines.
			local lineIdx = 0
			for _, bone in ipairs(p.bones) do
				local a = getSP(bone[1])
				local b = getSP(bone[2])
				if a and b then
					lineIdx = lineIdx + 1
					local l = p.lines[lineIdx]
					l.From    = a
					l.To      = b
					l.Color   = color
					l.Visible = true
				end
			end
			for i = lineIdx + 1, MAX_LINES do
				p.lines[i].Visible = false
			end

			-- Head dot: circle at the Head part's screen position.
			if headDotOn then
				local headSP = getSP("Head")
				if headSP then
					p.dot.Position = headSP
					p.dot.Radius   = HEAD_DOT_RADIUS
					p.dot.Color    = color
					p.dot.Visible  = true
				else
					p.dot.Visible = false
				end
			else
				p.dot.Visible = false
			end
		end

		-- Hide entries for off-screen / gone players.
		local stale = {}
		for pl in pairs(pool) do
			if not active[pl] then stale[#stale + 1] = pl end
		end
		for _, pl in ipairs(stale) do
			local p = pool[pl]
			for _, l in ipairs(p.lines) do pcall(function() l.Visible = false end) end
			pcall(function() p.dot.Visible = false end)
		end
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		local all = {}
		for pl in pairs(pool) do all[#all + 1] = pl end
		for _, pl in ipairs(all) do removeEntry(pl) end
	end

	return { update = update, unmount = unmount, onPlayerRemoving = removeEntry }
end
