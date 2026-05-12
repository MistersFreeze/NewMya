return function(ctx)
	local combatTab        = ctx.combatTab
	local makeBind         = ctx.makeBind
	local Players          = ctx.Players
	local localPlayer      = ctx.localPlayer
	local Workspace        = ctx.Workspace
	local UserInputService = ctx.UserInputService
	local RunService       = ctx.RunService

	-- ── State ─────────────────────────────────────────────────────────────────────

	local silentFov    = 100
	local targetPart   = "HumanoidRootPart"
	local teamCheck    = true
	local visCheck     = false
	local followCursor = false
	local showCircle   = false
	local closestPart  = nil  -- updated on Heartbeat, read inside __namecall

	-- ── FOV circle ────────────────────────────────────────────────────────────────

	local fovCircle = Drawing.new("Circle")
	fovCircle.Visible      = false
	fovCircle.Filled       = false
	fovCircle.Thickness    = 1.5
	fovCircle.NumSides     = 64
	fovCircle.Color        = Color3.fromRGB(160, 120, 220)
	fovCircle.Transparency = 0.35

	local fovColor  = Color3.fromRGB(160, 120, 220)
	local fovStyle  = "Solid"
	local DASH_COUNT = 24
	local fovDashLines = {}
	for i = 1, DASH_COUNT do
		local l = Drawing.new("Line")
		l.Visible   = false
		l.Thickness = 1.5
		fovDashLines[i] = l
	end
	fovCircle.Color = fovColor

	local function drawFovCircle(center, radius)
		if not showCircle then
			fovCircle.Visible = false
			for _, l in ipairs(fovDashLines) do l.Visible = false end
			return
		end
		if fovStyle == "Solid" then
			fovCircle.Position = center
			fovCircle.Radius   = radius
			fovCircle.Color    = fovColor
			fovCircle.Visible  = true
			for _, l in ipairs(fovDashLines) do l.Visible = false end
		else
			fovCircle.Visible = false
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
		end
	end

	-- ── Vis-check raycast ─────────────────────────────────────────────────────────

	local visParams = RaycastParams.new()
	visParams.FilterType  = Enum.RaycastFilterType.Exclude
	visParams.IgnoreWater = true

	local function updateVisFilter()
		local c = localPlayer.Character
		visParams.FilterDescendantsInstances = c and { c } or {}
	end
	updateVisFilter()

	local function getAnchor()
		local cam = Workspace.CurrentCamera
		if not cam then return Vector2.zero end
		local vp     = cam.ViewportSize
		local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
		if not followCursor then return center end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return center end
		return UserInputService:GetMouseLocation()
	end

	local function losOk(camPos, targetPos, targetChar)
		if not visCheck then return true end
		local result = Workspace:Raycast(camPos, targetPos - camPos, visParams)
		if not result then return true end
		return result.Instance ~= nil and result.Instance:IsDescendantOf(targetChar)
	end

	local function findClosest()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local camPos   = cam.CFrame.Position
		local anchor   = getAnchor()
		local bestDist = math.huge
		local bestPart = nil

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == localPlayer then continue end
			if teamCheck then
				local lpT = localPlayer.Team
				local ok, pT = pcall(function() return plr.Team end)
				if ok and lpT ~= nil and pT ~= nil and lpT == pT then continue end
			end
			local char = plr.Character
			if not char then continue end
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if not hum or hum.Health <= 0 then continue end
			local part = char:FindFirstChild(targetPart)
			if not part or not part:IsA("BasePart") then continue end
			local sv, onScreen = cam:WorldToViewportPoint(part.Position)
			if not onScreen or sv.Z <= 0 then continue end
			local dist = (Vector2.new(sv.X, sv.Y) - anchor).Magnitude
			if dist <= silentFov and dist < bestDist and losOk(camPos, part.Position, char) then
				bestDist = dist
				bestPart = part
			end
		end
		return bestPart
	end

	-- ── __namecall hook ───────────────────────────────────────────────────────────

	local hookInstalled = false
	local hookDepth     = 0

	local function canHook()
		return typeof(hookmetamethod)    == "function"
			and typeof(getnamecallmethod) == "function"
			and typeof(newcclosure)       == "function"
	end

	-- silentBind is defined after makeBind call below; captured by reference via closure.
	local silentBind  -- bind object assigned below

	if canHook() then
		pcall(function()
			local oldNamecall
			local hook = newcclosure(function(...)
				hookDepth = hookDepth + 1
				if hookDepth > 1 then
					local r = table.pack(oldNamecall(...))
					hookDepth = hookDepth - 1
					return table.unpack(r, 1, r.n)
				end

				local method = getnamecallmethod()
				local args   = { ... }

				if silentBind and silentBind.isActive()
					and method == "Raycast"
					and args[1] == Workspace
					and not checkcaller()
					and typeof(args[2]) == "Vector3"
					and typeof(args[3]) == "Vector3"
				then
					local hit = closestPart
					if hit and hit:IsA("BasePart") and hit.Parent then
						local delta = hit.Position - args[2]
						local mag   = delta.Magnitude
						if mag == mag and mag > 1e-3 then
							args[3] = delta.Unit * 1000
							local r = table.pack(oldNamecall(table.unpack(args)))
							hookDepth = hookDepth - 1
							return table.unpack(r, 1, r.n)
						end
					end
				end

				local r = table.pack(oldNamecall(...))
				hookDepth = hookDepth - 1
				return table.unpack(r, 1, r.n)
			end)

			local ok = pcall(function()
				oldNamecall = hookmetamethod(Workspace, "__namecall", hook)
			end)
			if not ok or typeof(oldNamecall) ~= "function" then
				oldNamecall = hookmetamethod(game, "__namecall", hook)
			end
			hookInstalled = true
		end)
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local section = combatTab:AddSection("Silent Aim")

	section:AddParagraph({
		Title   = "Hook Status",
		Content = hookInstalled and "Raycast hook active." or "Hook unavailable on this executor.",
	})

	-- Bind widget on the Enable row.
	silentBind = makeBind(section, {
		key   = "saEnable01x",
		title = "Enable",
		onEnabled = function(v) if not v then closestPart = nil end end,
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
		Callback = function(v) visCheck = v; updateVisFilter() end,
	})
	section:AddToggle("saFolCur1x", {
		Title    = "FOV Follows Cursor",
		Default  = false,
		Callback = function(v) followCursor = v end,
	})
	section:AddToggle("saFovC01x", {
		Title    = "Show FOV Circle",
		Default  = false,
		Callback = function(v) showCircle = v; if not v then fovCircle.Visible = false end end,
	})
	section:AddColorpicker("saFovCol1x", {
		Title        = "FOV Color",
		Default      = fovColor,
		Transparency = 0,
		Callback     = function(c)
			fovColor = c
			fovCircle.Color = c
			for _, l in ipairs(fovDashLines) do l.Color = c end
		end,
	})
	section:AddDropdown("saFovSty1x", {
		Title    = "FOV Style",
		Values   = { "Solid", "Dashed" },
		Default  = "Solid",
		NoSearch = true,
		Callback = function(v)
			fovStyle = v
			if v == "Solid" then
				for _, l in ipairs(fovDashLines) do l.Visible = false end
			else
				fovCircle.Visible = false
			end
		end,
	})

	-- ── Heartbeat: update closest target (safe outside __namecall) ────────────────

	local heartbeatConn = RunService.Heartbeat:Connect(function()
		if not silentBind or not silentBind.isActive() then
			closestPart = nil
			return
		end
		closestPart = findClosest()
	end)

	local charConn = localPlayer.CharacterAdded:Connect(function()
		task.defer(updateVisFilter)
	end)

	-- ── Update (FOV circle only; hook/heartbeat drive the actual aim) ─────────────

	local function update(data)
		local cam = data.cam or Workspace.CurrentCamera
		if not cam then
			fovCircle.Visible = false
			for _, l in ipairs(fovDashLines) do l.Visible = false end
			return
		end
		drawFovCircle(getAnchor(), silentFov)
	end

	local function unmount()
		silentBind.unmount()
		closestPart = nil
		fovCircle.Visible = false
		pcall(function() fovCircle:Remove() end)
		for _, l in ipairs(fovDashLines) do pcall(function() l:Remove() end) end
		pcall(function() heartbeatConn:Disconnect() end)
		pcall(function() charConn:Disconnect() end)
	end

	return { update = update, unmount = unmount }
end
