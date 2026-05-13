return function(ctx)
	local combatTab        = ctx.combatTab
	local makeBind         = ctx.makeBind
	local Players          = ctx.Players
	local localPlayer      = ctx.localPlayer
	local Workspace        = ctx.Workspace
	local UserInputService = ctx.UserInputService
	local RunService       = ctx.RunService

	-- ── State ─────────────────────────────────────────────────────────────────────

	local enabled      = false
	local silentFov    = 100
	local targetPart   = "HumanoidRootPart"
	local teamCheck    = true
	local visCheck     = false
	local followCursor = false
	local showCircle   = false
	local closestPart  = nil

	-- ── FOV circle ────────────────────────────────────────────────────────────────

	local fovColor  = Color3.fromRGB(160, 120, 220)
	local fovStyle  = "Solid"

	local fovCircle = Drawing.new("Circle")
	fovCircle.Visible      = false
	fovCircle.Filled       = false
	fovCircle.Thickness    = 1.5
	fovCircle.NumSides     = 64
	fovCircle.Color        = fovColor
	fovCircle.Transparency = 0.35

	local DASH_COUNT   = 24
	local fovDashLines = {}
	for i = 1, DASH_COUNT do
		local l = Drawing.new("Line")
		l.Visible   = false
		l.Thickness = 1.5
		fovDashLines[i] = l
	end
	local DOT_COUNT = 40
	local fovDots   = {}
	for i = 1, DOT_COUNT do
		local d = Drawing.new("Circle")
		d.Visible  = false
		d.Filled   = true
		d.Radius   = 2.5
		d.NumSides = 8
		d.Color    = fovColor
		fovDots[i] = d
	end

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

	-- ── Helpers ───────────────────────────────────────────────────────────────────

	local function getAnchor()
		local cam = Workspace.CurrentCamera
		if not cam then return Vector2.zero end
		local vp     = cam.ViewportSize
		local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
		if not followCursor then return center end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return center end
		return UserInputService:GetMouseLocation()
	end

	local function getClosestPart()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end

		local anchor      = getAnchor()
		local bestDist    = silentFov
		local bestPart    = nil
		local camPos      = cam.CFrame.Position

		for _, player in ipairs(Players:GetPlayers()) do
			if player == localPlayer then continue end
			if teamCheck then
				local lpT = localPlayer.Team
				local ok, pT = pcall(function() return player.Team end)
				if ok and lpT ~= nil and pT ~= nil and lpT == pT then continue end
			end
			local char = player.Character
			if not char then continue end
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if not hum or hum.Health <= 0 then continue end
			local part = char:FindFirstChild(targetPart)
			if not part or not part:IsA("BasePart") then continue end

			local sv, onScreen = cam:WorldToViewportPoint(part.Position)
			if not onScreen or sv.Z <= 0 then continue end

			local screenDist = (Vector2.new(sv.X, sv.Y) - anchor).Magnitude
			if screenDist >= bestDist then continue end

			if visCheck then
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { char }
				rp.IgnoreWater = true
				local result = Workspace:Raycast(camPos, part.Position - camPos, rp)
				if result and not result.Instance:IsDescendantOf(char) then continue end
			end

			bestDist = screenDist
			bestPart = part
		end
		return bestPart
	end

	-- silentBind declared forward so heartbeat can reference it.
	local silentBind

	-- ── Heartbeat: keep closestPart fresh ─────────────────────────────────────────

	local heartbeatConn = RunService.Heartbeat:Connect(function()
		if not (silentBind and silentBind.isActive()) then
			closestPart = nil
			return
		end
		closestPart = getClosestPart()
	end)

	-- ── __namecall hook ───────────────────────────────────────────────────────────
	-- Hooks game (not workspace) exactly as the working reference implementation.
	-- Uses { ... } + unpack() — no hookDepth guard which caused recursion issues.

	local hookInstalled = false
	local oldNamecall

	local canHook = typeof(hookmetamethod)    == "function"
		and typeof(getnamecallmethod) == "function"
		and typeof(newcclosure)       == "function"

	if canHook then
		pcall(function()
			oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
				local method = getnamecallmethod()
				local args   = { ... }
				local self   = args[1]

				if silentBind and silentBind.isActive()
					and self == Workspace
					and method == "Raycast"
					and not checkcaller()
				then
					local hit = closestPart
					if hit and hit:IsA("BasePart") and hit.Parent then
						local origin = args[2]
						if typeof(origin) == "Vector3" then
							args[3] = (hit.Position - origin).Unit * 1000
							return oldNamecall(unpack(args))
						end
					end
				end

				return oldNamecall(...)
			end))
			hookInstalled = typeof(oldNamecall) == "function"
		end)
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = combatTab:AddSection("Silent Aim")

	section:AddParagraph({
		Title   = "Hook Status",
		Content = hookInstalled and "Hook active." or "Hook unavailable on this executor.",
	})

	silentBind = makeBind(section, {
		key         = "saEnable01x",
		title       = "Enable",
		displayName = "Silent Aim",
		onEnabled   = function(v)
			enabled = v
			if not v then closestPart = nil end
		end,
	})

	section:AddSlider("saFov0001x", {
		Title    = "FOV",
		Default  = 100,
		Min      = 10,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) silentFov = v end,
	})

	section:AddDropdown("saTarget1x", {
		Title    = "Target Part",
		Values   = { "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" },
		Default  = "HumanoidRootPart",
		NoSearch = true,
		Callback = function(v) targetPart = v end,
	})

	section:AddToggle("saTeamCk1x", {
		Title    = "Team Check",
		Default  = true,
		Callback = function(v) teamCheck = v end,
	})

	section:AddToggle("saVisCk01x", {
		Title    = "Visibility Check",
		Default  = false,
		Callback = function(v) visCheck = v end,
	})

	section:AddToggle("saFolCur1x", {
		Title    = "FOV Follows Cursor",
		Default  = false,
		Callback = function(v) followCursor = v end,
	})

	section:AddToggle("saFovC01x", {
		Title    = "Show FOV Circle",
		Default  = false,
		Callback = function(v)
			showCircle = v
			if not v then
				fovCircle.Visible = false
				for _, l in ipairs(fovDashLines) do l.Visible = false end
			end
		end,
	})

	section:AddColorpicker("saFovCol1x", {
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

	section:AddDropdown("saFovSty1x", {
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

	-- ── Update (FOV circle) ───────────────────────────────────────────────────────

	local function update(data)
		local cam = data.cam or Workspace.CurrentCamera
		if not cam then
			fovCircle.Visible = false
			for _, l in ipairs(fovDashLines) do l.Visible = false end
			return
		end
		drawFovCircle(getAnchor(), silentFov)
	end

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function unmount()
		enabled     = false
		closestPart = nil
		if silentBind then silentBind.unmount() end
		fovCircle.Visible = false
		pcall(function() fovCircle:Remove() end)
		for _, l in ipairs(fovDashLines) do pcall(function() l:Remove() end) end
		for _, d in ipairs(fovDots) do pcall(function() d:Remove() end) end
		pcall(function() heartbeatConn:Disconnect() end)
	end

	return { update = update, unmount = unmount }
end
