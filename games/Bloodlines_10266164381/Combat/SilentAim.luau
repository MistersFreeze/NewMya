return function(ctx)
	local combatTab      = ctx.combatTab
	local localPlayer    = ctx.localPlayer
	local Players        = ctx.Players
	local Workspace      = ctx.Workspace
	local UserInputService = ctx.UserInputService

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- ── State ─────────────────────────────────────────────────────────────────

	local silentAim  = { enabled = false }
	local fovRadius  = 120
	local fovColor   = Color3.fromRGB(255, 255, 255)
	local fovFilled  = false
	local fovThick   = 1.5
	local showFov    = false
	local teamCheck  = false

	-- ── FOV circle (Drawing API) ──────────────────────────────────────────────

	local fovCircle = Drawing.new("Circle")
	fovCircle.Radius      = fovRadius
	fovCircle.Color       = fovColor
	fovCircle.Transparency = 0.5
	fovCircle.Thickness   = fovThick
	fovCircle.Filled      = fovFilled
	fovCircle.NumSides    = 64
	fovCircle.ZIndex      = 5
	fovCircle.Visible     = false

	-- ── Target selection ──────────────────────────────────────────────────────

	local function getClosestTarget()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local cursor = UserInputService:GetMouseLocation()
		local closest, closestDist = nil, math.huge
		for _, player in ipairs(Players:GetPlayers()) do
			if player == localPlayer then continue end
			local char = player.Character
			if not char then continue end
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if not hum or hum.Health <= 0 then continue end
			if teamCheck and player.Team and localPlayer.Team and player.Team == localPlayer.Team then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end
			local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
			if not onScreen or sp.Z <= 0 then continue end
			local dist = (Vector2.new(sp.X, sp.Y) - cursor).Magnitude
			if dist < fovRadius and dist < closestDist then
				closestDist = dist
				closest = player
			end
		end
		return closest
	end

	-- ── Namecall hook (intercepts DataEvent:FireServer("CheckMeleeHit", ...)) ─

	local DataEvent = nil
	pcall(function() DataEvent = ReplicatedStorage.Events.DataEvent end)
	local hooked    = false
	local origNC    = nil

	local function hookNC()
		if hooked then return end
		if not (typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function") then return end
		local mt = getrawmetatable(game)
		if not mt then return end
		pcall(function() setreadonly(mt, false) end)
		origNC = mt.__namecall
		mt.__namecall = function(self, ...)
			local ok, method = pcall(getnamecallmethod)
			if ok and method == "FireServer" and self == DataEvent and silentAim.enabled then
				local args = { ... }
				if args[1] == "CheckMeleeHit" then
					local tgt = getClosestTarget()
					if tgt and tgt.Character then
						local hrp = tgt.Character:FindFirstChild("HumanoidRootPart")
						if hrp then args[2] = hrp.Position end
					end
					return origNC(self, table.unpack(args))
				end
			end
			return origNC(self, ...)
		end
		pcall(function() setreadonly(mt, true) end)
		hooked = true
	end

	local function unhookNC()
		if not hooked or not origNC then return end
		if not (typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function") then return end
		local mt = getrawmetatable(game)
		if mt then
			pcall(function()
				setreadonly(mt, false)
				mt.__namecall = origNC
				setreadonly(mt, true)
			end)
		end
		hooked  = false
		origNC  = nil
	end

	-- ── UI ────────────────────────────────────────────────────────────────────

	local aimSec = combatTab:AddSection("Silent Aim")
	aimSec:AddToggle("SilentAimEn", {
		Title    = "Silent Aim",
		Icon     = "solar/target-bold",
		Default  = false,
		Callback = function(v)
			silentAim.enabled = v
			if v then hookNC() end
		end,
	})
	aimSec:AddToggle("SATeamCheck", {
		Title    = "Team Check",
		Icon     = "solar/users-group-rounded-bold",
		Default  = false,
		Callback = function(v) teamCheck = v end,
	})

	local fovSec = combatTab:AddSection("FOV Circle")
	fovSec:AddToggle("SAShowFov", {
		Title    = "Show FOV",
		Icon     = "solar/eye-bold",
		Default  = false,
		Callback = function(v) showFov = v; if not v then fovCircle.Visible = false end end,
	})
	fovSec:AddSlider("SAFovRadius", {
		Title    = "Radius",
		Default  = 120,
		Min      = 10,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) fovRadius = v; fovCircle.Radius = v end,
	})
	fovSec:AddColorpicker("SAFovColor", {
		Title    = "Color",
		Default  = fovColor,
		Callback = function(v) fovColor = v; fovCircle.Color = v end,
	})
	fovSec:AddSlider("SAFovThick", {
		Title    = "Thickness",
		Default  = 2,
		Min      = 1,
		Max      = 6,
		Rounding = 0,
		Callback = function(v) fovThick = v; fovCircle.Thickness = v end,
	})
	fovSec:AddToggle("SAFovFilled", {
		Title    = "Filled",
		Default  = false,
		Callback = function(v) fovFilled = v; fovCircle.Filled = v end,
	})

	-- ── Update / unmount ──────────────────────────────────────────────────────

	local function update(data)
		if not showFov then fovCircle.Visible = false; return end
		fovCircle.Position = UserInputService:GetMouseLocation()
		fovCircle.Visible  = true
	end

	local function unmount()
		unhookNC()
		pcall(function() fovCircle:Remove() end)
	end

	return { update = update, unmount = unmount }
end
