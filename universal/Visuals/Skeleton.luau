return function(ctx)
	local visualsTab  = ctx.visualsTab
	local isSameTeam  = ctx.isSameTeam
	local Workspace   = ctx.Workspace
	local Players     = ctx.Players
	local localPlayer = ctx.localPlayer

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled     = false
	local color       = Color3.fromRGB(255, 100, 150)
	local notVisColor = Color3.fromRGB(255, 165, 0)
	local headDotOn   = false
	local visCheck    = false
	local HEAD_DOT_RADIUS = 5

	-- ── R15 bones: { partA, attachA, partB, attachB } ────────────────────────────
	-- Uses RigAttachment WorldPosition so arms/legs follow actual joint positions.

	local R15_BONES = {
		{ "Head",          "NeckRigAttachment",         "UpperTorso",    "NeckRigAttachment"         },
		{ "UpperTorso",    "UpperWaistRigAttachment",   "LowerTorso",    "UpperWaistRigAttachment"   },
		{ "UpperTorso",    "LeftShoulderRigAttachment", "LeftUpperArm",  "LeftShoulderRigAttachment" },
		{ "LeftUpperArm",  "LeftElbowRigAttachment",    "LeftLowerArm",  "LeftElbowRigAttachment"    },
		{ "LeftLowerArm",  "LeftWristRigAttachment",    "LeftHand",      "LeftWristRigAttachment"    },
		{ "UpperTorso",    "RightShoulderRigAttachment","RightUpperArm", "RightShoulderRigAttachment"},
		{ "RightUpperArm", "RightElbowRigAttachment",   "RightLowerArm", "RightElbowRigAttachment"   },
		{ "RightLowerArm", "RightWristRigAttachment",   "RightHand",     "RightWristRigAttachment"   },
		{ "LowerTorso",    "LeftHipRigAttachment",      "LeftUpperLeg",  "LeftHipRigAttachment"      },
		{ "LeftUpperLeg",  "LeftKneeRigAttachment",     "LeftLowerLeg",  "LeftKneeRigAttachment"     },
		{ "LeftLowerLeg",  "LeftAnkleRigAttachment",    "LeftFoot",      "LeftAnkleRigAttachment"    },
		{ "LowerTorso",    "RightHipRigAttachment",     "RightUpperLeg", "RightHipRigAttachment"     },
		{ "RightUpperLeg", "RightKneeRigAttachment",    "RightLowerLeg", "RightKneeRigAttachment"    },
		{ "RightLowerLeg", "RightAnkleRigAttachment",   "RightFoot",     "RightAnkleRigAttachment"   },
	}

	local R6_BONES = {
		{ "Head",  nil, "Torso",     nil },
		{ "Torso", nil, "Left Arm",  nil },
		{ "Torso", nil, "Right Arm", nil },
		{ "Torso", nil, "Left Leg",  nil },
		{ "Torso", nil, "Right Leg", nil },
	}

	local MAX_LINES = #R15_BONES

	-- ── Drawing pool ──────────────────────────────────────────────────────────────
	-- pool[player] = { lines, dot, char, partRefs, attRefs, bones }

	local pool        = {}
	local playerConns = {}

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
		dot.Visible   = false
		dot.Filled    = false
		dot.Thickness = 1.2
		dot.NumSides  = 16
		dot.Color     = color
		dot.Radius    = HEAD_DOT_RADIUS
		return { lines = lines, dot = dot, char = nil, partRefs = {}, attRefs = {}, bones = nil }
	end

	local function removeEntry(player)
		local p = pool[player]
		if not p then return end
		for _, l in ipairs(p.lines) do pcall(function() l:Remove() end) end
		pcall(function() p.dot:Remove() end)
		pool[player] = nil
	end

	local function clearCharCache(p)
		p.char     = nil
		p.partRefs = {}
		p.attRefs  = {}
		p.bones    = nil
		for _, l in ipairs(p.lines) do pcall(function() l.Visible = false end) end
		pcall(function() p.dot.Visible = false end)
	end

	local function attachPlayer(player)
		if player == localPlayer then return end
		local c1 = player.CharacterAdded:Connect(function()
			task.defer(function()
				local p = pool[player]
				if p then clearCharCache(p) end
			end)
		end)
		local c2 = player.CharacterRemoving:Connect(function()
			local p = pool[player]
			if p then
				for _, l in ipairs(p.lines) do pcall(function() l.Visible = false end) end
				pcall(function() p.dot.Visible = false end)
			end
		end)
		playerConns[player] = { c1, c2 }
	end

	local function detachPlayer(player)
		removeEntry(player)
		local cs = playerConns[player]
		if cs then
			for _, c in ipairs(cs) do pcall(function() c:Disconnect() end) end
			playerConns[player] = nil
		end
	end

	local paConn = Players.PlayerAdded:Connect(attachPlayer)
	for _, player in ipairs(Players:GetPlayers()) do attachPlayer(player) end

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
	section:AddToggle("sKelVisCk1x", {
		Title    = "Visibility Check",
		Default  = false,
		Callback = function(v) visCheck = v end,
	})
	section:AddColorpicker("sKelNVCol1x", {
		Title        = "Hidden Color",
		Default      = notVisColor,
		Transparency = 0,
		Callback     = function(c) notVisColor = c end,
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
			if isSameTeam(e.player) then continue end
			active[e.player] = true

			local char = e.char or e.player.Character
			if not char then continue end

			if not e.onScreen then
				local p = pool[e.player]
				if p then
					for _, l in ipairs(p.lines) do pcall(function() l.Visible = false end) end
					pcall(function() p.dot.Visible = false end)
				end
				continue
			end

			local p = pool[e.player]
			if not p then
				p = makeEntry()
				pool[e.player] = p
			end

			if char ~= p.char then
				clearCharCache(p)
				p.char = char
			end

			if not p.bones then
				p.bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
			end

			local lineColor = color
			if visCheck then
				lineColor = (e.visible ~= false) and color or notVisColor
			end

			local function getJointSP(partName, attachName)
				if not partName then return nil end
				local part = p.partRefs[partName]
				if part == nil then
					part = char:FindFirstChild(partName)
					p.partRefs[partName] = part or false
				end
				if not part or part == false then return nil end

				if attachName then
					local key = partName .. "/" .. attachName
					local att = p.attRefs[key]
					if att == nil then
						att = part:FindFirstChild(attachName)
						p.attRefs[key] = att or false
					end
					if att and att ~= false then
						local v = cam:WorldToViewportPoint(att.WorldPosition)
						return Vector2.new(v.X, v.Y)
					end
				end

				local v = cam:WorldToViewportPoint(part.Position)
				return Vector2.new(v.X, v.Y)
			end

			local lineIdx = 0
			for _, bone in ipairs(p.bones) do
				local a = getJointSP(bone[1], bone[2])
				local b = getJointSP(bone[3], bone[4])
				if a and b then
					lineIdx = lineIdx + 1
					local l = p.lines[lineIdx]
					l.From    = a
					l.To      = b
					l.Color   = lineColor
					l.Visible = true
				end
			end
			for i = lineIdx + 1, MAX_LINES do
				p.lines[i].Visible = false
			end

			if headDotOn then
				local headSP = getJointSP("Head", nil)
				if headSP then
					p.dot.Position = headSP
					p.dot.Radius   = HEAD_DOT_RADIUS
					p.dot.Color    = lineColor
					p.dot.Visible  = true
				else
					p.dot.Visible = false
				end
			else
				p.dot.Visible = false
			end
		end

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
		pcall(function() paConn:Disconnect() end)
		for player in pairs(playerConns) do detachPlayer(player) end
		local all = {}
		for pl in pairs(pool) do all[#all + 1] = pl end
		for _, pl in ipairs(all) do removeEntry(pl) end
	end

	return { update = update, unmount = unmount, onPlayerRemoving = detachPlayer }
end
