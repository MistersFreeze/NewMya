return function(ctx)
	local combatTab        = ctx.combatTab
	local makeBind         = ctx.makeBind
	local Players          = ctx.Players
	local localPlayer      = ctx.localPlayer
	local Workspace        = ctx.Workspace
	local UserInputService = ctx.UserInputService

	-- ── State ─────────────────────────────────────────────────────────────────────

	local aimFov       = 140
	local aimSpeed     = 35
	local targetPart   = "Head"
	local teamCheck    = false
	local visCheck     = false
	local keepTarget   = false
	local followCursor = false
	local showCircle   = false
	local lockedPlayer = nil

	-- ── FOV circle ────────────────────────────────────────────────────────────────

	local fovCircle = Drawing.new("Circle")
	fovCircle.Visible      = false
	fovCircle.Filled       = false
	fovCircle.Thickness    = 1.5
	fovCircle.NumSides     = 64
	fovCircle.Color        = Color3.fromRGB(230, 120, 175)
	fovCircle.Transparency = 0.35

	local fovColor  = Color3.fromRGB(230, 120, 175)
	local fovStyle  = "Solid"
	local DASH_COUNT = 24
	local fovDashLines = {}
	for i = 1, DASH_COUNT do
		local l = Drawing.new("Line")
		l.Visible   = false
		l.Thickness = 1.5
		fovDashLines[i] = l
	end
	local DOT_COUNT = 40
	local fovDots = {}
	for i = 1, DOT_COUNT do
		local d = Drawing.new("Circle")
		d.Visible   = false
		d.Filled    = true
		d.Radius    = 2.5
		d.NumSides  = 8
		d.Color     = fovColor
		fovDots[i]  = d
	end
	fovCircle.Color = fovColor

	local function drawFovCircle(center, radius)
		if not showCircle then
			fovCircle.Visible = false
			for _, l in ipairs(fovDashLines) do l.Visible = false end
			for _, d in ipairs(fovDots) do d.Visible = false end
			return
		end
		if fovStyle == "Solid" then
			fovCircle.Position = center
			fovCircle.Radius   = radius
			fovCircle.Color    = fovColor
			fovCircle.Visible  = true
			for _, l in ipairs(fovDashLines) do l.Visible = false end
			for _, d in ipairs(fovDots) do d.Visible = false end
		elseif fovStyle == "Dashed" then
			fovCircle.Visible = false
			for _, d in ipairs(fovDots) do d.Visible = false end
			local step = (2 * math.pi) / DASH_COUNT
			for i = 1, DASH_COUNT do
				local l = fovDashLines[i]
				if i % 2 == 1 then
					local a1 = (i - 1) * step
					local a2 = i * step
					l.From    = Vector2.new(center.X + math.cos(a1) * radius, center.Y + math.sin(a1) * radius)
					l.To      = Vector2.new(center.X + math.cos(a2) * radius, center.Y + math.sin(a2) * radius)
					l.Color   = fovColor
					l.Visible = true
				else
					l.Visible = false
				end
			end
		elseif fovStyle == "Dotted" then
			fovCircle.Visible = false
			for _, l in ipairs(fovDashLines) do l.Visible = false end
			local step = (2 * math.pi) / DOT_COUNT
			for i = 1, DOT_COUNT do
				local angle = (i - 1) * step
				fovDots[i].Position = Vector2.new(center.X + math.cos(angle) * radius, center.Y + math.sin(angle) * radius)
				fovDots[i].Color    = fovColor
				fovDots[i].Visible  = true
			end
		end
	end

	-- ── Vis-check raycast ─────────────────────────────────────────────────────────

	local function getAnchor(cam)
		local vp     = cam.ViewportSize
		local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
		if not followCursor then return center end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return center end
		return UserInputService:GetMouseLocation()
	end

	local function inViewport(sp, vp)
		return sp.X >= -50 and sp.X <= vp.X + 50
			and sp.Y >= -50 and sp.Y <= vp.Y + 50
	end

	-- Uses shared data.players (same source as ESP) so visibility check is
	-- always in sync with what ESP shows. e.visible is the shared LOS result.
	local function getBestTarget(cam, anchor, entries)
		local vp = cam.ViewportSize

		if keepTarget and lockedPlayer then
			local plr  = lockedPlayer
			local char = plr.Parent and plr.Character
			local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
			if char and hum and hum.Health > 0 and not ctx.isSameTeam(plr) then
				local part = char:FindFirstChild(targetPart)
				if part and part:IsA("BasePart") then
					local sv = cam:WorldToViewportPoint(part.Position)
					if sv.Z > 0 then
						local sp = Vector2.new(sv.X, sv.Y)
						if inViewport(sp, vp) and (sp - anchor).Magnitude <= aimFov then
							-- Find this player's shared visibility from entries.
							local vis = true
							for _, e in ipairs(entries) do
								if e.player == plr then vis = e.visible ~= false break end
							end
							if not visCheck or vis then
								return sp
							end
						end
					end
				end
			end
			lockedPlayer = nil
		end

		local bestDist = math.huge
		local bestSp, bestPlr = nil, nil

		for _, e in ipairs(entries) do
			if ctx.isSameTeam(e.player) then continue end
			if not e.onScreen then continue end
			-- Visibility: use the shared e.visible (same raycast the ESP uses).
			if visCheck and e.visible == false then continue end
			local char = e.char
			if not char then continue end
			local part = char:FindFirstChild(targetPart)
			if not part or not part:IsA("BasePart") then continue end
			local sv = cam:WorldToViewportPoint(part.Position)
			if sv.Z <= 0 then continue end
			local sp = Vector2.new(sv.X, sv.Y)
			if not inViewport(sp, vp) then continue end
			local dist = (sp - anchor).Magnitude
			if dist < aimFov and dist < bestDist then
				bestDist = dist
				bestSp   = sp
				bestPlr  = e.player
			end
		end

		if keepTarget then lockedPlayer = bestPlr end
		return bestSp
	end

	local remX, remY = 0, 0

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = combatTab:AddSection("Aim Assist")

	local aimBind = makeBind(section, {
		key         = "aaEnable01x",
		title       = "Enable",
		displayName = "Aim Assist",
	})

	section:AddSlider("aaFov001x", {
		Title    = "FOV",
		Default  = 140,
		Min      = 10,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) aimFov = v end,
	})
	section:AddSlider("aaSpeed01x", {
		Title    = "Speed",
		Default  = 35,
		Min      = 1,
		Max      = 100,
		Rounding = 0,
		Callback = function(v) aimSpeed = v end,
	})
	section:AddDropdown("aaTarget1x", {
		Title    = "Target Part",
		Values   = { "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" },
		Default  = "Head",
		NoSearch = true,
		Callback = function(v) targetPart = v end,
	})
	section:AddToggle("aaTeamCk1x", {
		Title    = "Team Check",
		Default  = false,
		Callback = function(v) teamCheck = v end,
	})
	section:AddToggle("aaVisCk01x", {
		Title    = "Visibility Check",
		Default  = false,
		Callback = function(v) visCheck = v end,
	})
	section:AddToggle("aaLockTg1x", {
		Title    = "Keep on Target",
		Default  = false,
		Callback = function(v) keepTarget = v; if not v then lockedPlayer = nil end end,
	})
	section:AddToggle("aaFolCur1x", {
		Title    = "FOV Follows Cursor",
		Default  = false,
		Callback = function(v) followCursor = v end,
	})
	section:AddToggle("aaFovC01x", {
		Title    = "Show FOV Circle",
		Default  = false,
		Callback = function(v) showCircle = v; if not v then fovCircle.Visible = false end end,
	})
	section:AddColorpicker("aaFovCol1x", {
		Title        = "FOV Color",
		Default      = fovColor,
		Transparency = 0,
		Callback     = function(c)
			fovColor = c
			fovCircle.Color = c
			for _, l in ipairs(fovDashLines) do l.Color = c end
			for _, d in ipairs(fovDots) do d.Color = c end
		end,
	})
	section:AddDropdown("aaFovSty1x", {
		Title    = "FOV Style",
		Values   = { "Solid", "Dashed", "Dotted" },
		Default  = "Solid",
		NoSearch = true,
		Callback = function(v)
			fovStyle = v
			if v == "Solid" then
				for _, l in ipairs(fovDashLines) do l.Visible = false end
				for _, d in ipairs(fovDots) do d.Visible = false end
			elseif v == "Dashed" then
				fovCircle.Visible = false
				for _, d in ipairs(fovDots) do d.Visible = false end
			elseif v == "Dotted" then
				fovCircle.Visible = false
				for _, l in ipairs(fovDashLines) do l.Visible = false end
			end
		end,
	})

	-- ── Update (RenderStepped) ────────────────────────────────────────────────────

	local function update(data)
		local cam = data.cam or Workspace.CurrentCamera
		if not cam then return end

		local anchor = getAnchor(cam)

		drawFovCircle(anchor, aimFov)

		if not aimBind.isActive() then
			remX, remY   = 0, 0
			lockedPlayer = nil
			return
		end

		local bestSp = getBestTarget(cam, anchor, data.players)
		if not bestSp then remX, remY = 0, 0 return end

		local dx = bestSp.X - anchor.X
		local dy = bestSp.Y - anchor.Y

		-- Hard cap per-frame movement to the FOV radius.
		-- Prevents a sudden large delta (dying target, edge-of-camera Z flip, etc.)
		-- from spinning the camera 360° or launching into the sky.
		local maxMove = math.max(aimFov, 50)
		local mag = math.sqrt(dx * dx + dy * dy)
		if mag > maxMove then
			local s = maxMove / mag
			dx, dy  = dx * s, dy * s
		end

		if typeof(mousemoverel) ~= "function" then return end

		local spd = (aimSpeed / 100) ^ 3
		if spd >= 1 then
			mousemoverel(dx, dy)
			remX, remY = 0, 0
		else
			remX = remX + dx * spd
			remY = remY + dy * spd
			local mx = math.round(remX)
			local my = math.round(remY)
			if mx ~= 0 or my ~= 0 then
				mousemoverel(mx, my)
				remX = remX - mx
				remY = remY - my
			end
		end
	end

	local function unmount()
		aimBind.unmount()
		fovCircle.Visible = false
		pcall(function() fovCircle:Remove() end)
		for _, l in ipairs(fovDashLines) do pcall(function() l:Remove() end) end
		for _, d in ipairs(fovDots) do pcall(function() d:Remove() end) end
	end

	return { update = update, unmount = unmount }
end
