return function(ctx)
	local combatTab       = ctx.combatTab
	local localPlayer     = ctx.localPlayer
	local Players         = ctx.Players
	local Workspace       = ctx.Workspace
	local UserInputService = ctx.UserInputService
	local bindRegistry    = ctx.bindRegistry

	local RunService = game:GetService("RunService")

	-- ── State ─────────────────────────────────────────────────────────────────────

	local silentAim    = { enabled = false }
	local aimLock      = { enabled = false }
	local teamCheck    = false

	-- ── Silent aim activation bind ────────────────────────────────────────────────
	-- When a key is bound, silent aim only fires while that condition is met.
	-- In Always mode (default) no key is required.

	local saBindMode    = "Always"
	local saToggleState = false
	local saKb          = nil   -- set after UI creation below

	local function isSABindActive()
		if not (silentAim.enabled or aimLock.enabled) then return false end
		local kv = saKb and saKb.Value
		if not kv or kv == "None" or kv == "" or saBindMode == "Always" then return true end
		if saBindMode == "Toggle" then return saToggleState end
		-- Hold mode
		if kv:sub(1, 5) == "Mouse" then
			local t = kv == "MouseLeft"   and Enum.UserInputType.MouseButton1
				   or kv == "MouseRight"  and Enum.UserInputType.MouseButton2
				   or kv == "MouseMiddle" and Enum.UserInputType.MouseButton3
			return t and UserInputService:IsMouseButtonPressed(t) or false
		end
		local ok, kc = pcall(function() return Enum.KeyCode[kv] end)
		return ok and kc and kc ~= Enum.KeyCode.Unknown and UserInputService:IsKeyDown(kc)
	end

	-- Toggle latch input connection (wired up after saKb is created)
	local _saToggleConn = nil
	local targetPart = "Head"
	local fovRadius  = 120
	local fovColor   = Color3.fromRGB(255, 255, 255)
	local fovLocked  = Color3.fromRGB(255, 60, 60)
	local fovFilled  = false
	local fovThick   = 1.5
	local showFov    = false
	local aimSpeed   = 0.12   -- fraction of delta per frame for smooth aim

	-- Cached closest target part, updated every Heartbeat.
	-- The hook reads this; the Heartbeat writes it.
	local closestPart = nil

	-- Cached bind-active flag, also updated by Heartbeat.
	-- The __namecall hook must NEVER call isSABindActive() directly — doing so
	-- triggers UserInputService:IsKeyDown (another namecall) from inside the hook,
	-- which causes the hook to re-enter and recurse until C stack overflow.
	-- Reading a pre-computed boolean is safe because it makes no further namecalls.
	local _saActive = true

	-- ── FOV circle ────────────────────────────────────────────────────────────────

	local fovCircle = Drawing.new("Circle")
	fovCircle.Radius       = fovRadius
	fovCircle.Color        = fovColor
	fovCircle.Transparency = 0.5
	fovCircle.Thickness    = fovThick
	fovCircle.Filled       = fovFilled
	fovCircle.NumSides     = 64
	fovCircle.ZIndex       = 5
	fovCircle.Visible      = false

	-- ── Target selection ──────────────────────────────────────────────────────────

	local function getAimPart(char)
		if not char then return nil end
		if targetPart == "Head"  then return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") end
		if targetPart == "Torso" then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart") end
		return char:FindFirstChild("HumanoidRootPart")
	end

	local function findClosest()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local cursor   = UserInputService:GetMouseLocation()
		local best, bestDist = nil, math.huge
		local _isWL = _G.MYA_BL_IsWL

		for _, player in ipairs(Players:GetPlayers()) do
			if player == localPlayer then continue end
			if _isWL and _isWL(player, "silentAim") then continue end
			local char = player.Character
			if not char then continue end
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if not hum or hum.Health <= 0 then continue end
			if teamCheck and player.Team and localPlayer.Team and player.Team == localPlayer.Team then continue end

			local part = getAimPart(char)
			if not part then continue end

			local sp, onScreen = cam:WorldToViewportPoint(part.Position)
			if not onScreen or sp.Z <= 0 then continue end

			local screenDist = (Vector2.new(sp.X, sp.Y) - cursor).Magnitude
			if screenDist < fovRadius and screenDist < bestDist then
				bestDist = screenDist
				best     = part
			end
		end

		return best
	end

	-- ── Hook (hookmetamethod pattern — MyaLoader silent_aim reference) ────────────
	--
	-- We hook workspace:Raycast via hookmetamethod(game, "__namecall").
	-- When the game fires a Raycast from its own code (not checkcaller),
	-- we redirect the ray direction to pass through the cached target part.
	-- This covers both M1 melee (workspace:Raycast hit check) and skill
	-- targeting rays (the mouse-cursor raycast that produces u2.Hit.p).
	--
	-- This approach does NOT touch DataEvent:FireServer at all, which eliminates
	-- the WorldToViewportPoint-on-DataEvent error caused by the old raw-metamethod
	-- approach.

	local hookInstalled = false
	local origNC        = nil

	local function canHook()
		return typeof(hookmetamethod)    == "function"
			and typeof(getnamecallmethod) == "function"
			and typeof(newcclosure)       == "function"
	end

	local function installHook()
		if hookInstalled or not canHook() then return end
		local ok, err = pcall(function()
			origNC = hookmetamethod(game, "__namecall", newcclosure(function(...)
				local method = getnamecallmethod()
				local args   = { ... }
				local self   = args[1]

						local callerIsGame = typeof(checkcaller) ~= "function" or not checkcaller()

				-- ── workspace:Raycast hook ───────────────────────────────────────────
				if silentAim.enabled
					and _saActive          -- pre-computed in Heartbeat, no namecall
					and method == "Raycast"
					and self   == Workspace
					and closestPart ~= nil
					and callerIsGame then

					local origin = args[2]
					if typeof(origin) == "Vector3" then
						args[3] = (closestPart.Position - origin).Unit * 1000
						return origNC(table.unpack(args))
					end
				end

				-- ── workspace:FindPartsInRegion3 hook ────────────────────────────────
				if silentAim.enabled
					and _saActive          -- pre-computed in Heartbeat, no namecall
					and (method == "FindPartsInRegion3" or method == "FindPartsInRegion3WithWhiteList")
					and self == Workspace
					and closestPart ~= nil
					and callerIsGame then

					local resultParts = origNC(...)
					-- Only inject if the target is not already in the result.
					local alreadyHit = false
					for _, part in ipairs(resultParts) do
						if part:IsDescendantOf(closestPart.Parent) then
							alreadyHit = true
							break
						end
					end
					if not alreadyHit and closestPart.Parent then
						table.insert(resultParts, closestPart)
					end
					return resultParts
				end

				return origNC(...)
			end))
		end)
		if not ok then
			warn("SilentAim: hook failed —", tostring(err))
		end
		hookInstalled = ok
	end

	local function removeHook()
		if not hookInstalled or not origNC then return end
		pcall(function() hookmetamethod(game, "__namecall", origNC) end)
		hookInstalled = false
		origNC        = nil
	end

	-- ── Heartbeat: keep closestPart fresh ─────────────────────────────────────────

	local heartConn = RunService.Heartbeat:Connect(function()
		-- Evaluate the bind state HERE (outside the hook) so the hook can
		-- safely read _saActive without making any further namecall calls.
		_saActive = isSABindActive()

		if not (silentAim.enabled or aimLock.enabled) or not _saActive then
			closestPart = nil
			return
		end
		closestPart = findClosest()
	end)

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local aimSec = combatTab:AddSection("Silent Aim")

	aimSec:AddToggle("SilentAimEn", {
		Title    = "Silent Aim",
		Icon     = "solar/target-bold",
		Default  = false,
		Callback = function(v)
			silentAim.enabled = v
			if v then installHook() end
		end,
	})

	aimSec:AddToggle("AimLockEn", {
		Title    = "Aim Lock",
		Icon     = "solar/eye-scan-bold",
		Default  = false,
		Callback = function(v) aimLock.enabled = v end,
	})

	aimSec:AddSlider("AimLockSpeed", {
		Title    = "Aim Lock Speed",
		Default  = 12,
		Min      = 1,
		Max      = 100,
		Rounding = 0,
		Callback = function(v) aimSpeed = v / 100 end,
	})

	aimSec:AddDropdown("AimPartDD", {
		Title    = "Target Part",
		Values   = { "Head", "Torso", "HRP" },
		Default  = "Head",
		NoSearch = true,
		Callback = function(v) targetPart = v end,
	})

	aimSec:AddToggle("SATeamCheck", {
		Title    = "Team Check",
		Icon     = "solar/users-group-rounded-bold",
		Default  = false,
		Callback = function(v) teamCheck = v end,
	})

	saKb = aimSec:AddKeybind("SilentAimBind", {
		Title   = "Activation Bind",
		Default = "None",
		Callback = function(_) saToggleState = false end,
	})

	aimSec:AddDropdown("SilentAimBindMode", {
		Title    = "Bind Mode",
		Values   = { "Always", "Hold", "Toggle" },
		Default  = "Always",
		NoSearch = true,
		Callback = function(v)
			saBindMode    = v
			saToggleState = false
		end,
	})

	-- Toggle-latch input connection
	_saToggleConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or saBindMode ~= "Toggle" then return end
		local kv = saKb and saKb.Value
		if not kv or kv == "None" or kv == "" then return end
		local hit = false
		if kv == "MouseLeft"   then hit = input.UserInputType == Enum.UserInputType.MouseButton1
		elseif kv == "MouseRight"  then hit = input.UserInputType == Enum.UserInputType.MouseButton2
		elseif kv == "MouseMiddle" then hit = input.UserInputType == Enum.UserInputType.MouseButton3
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local ok, kc = pcall(function() return Enum.KeyCode[kv] end)
			hit = ok and kc and kc ~= Enum.KeyCode.Unknown and input.KeyCode == kc
		end
		if hit then saToggleState = not saToggleState end
	end)

	-- Register in the global keybind registry so the Keybind Display widget shows it.
	if bindRegistry then
		bindRegistry[#bindRegistry + 1] = {
			displayName = "Silent Aim",
			getKey      = function() return saKb and saKb.Value or nil end,
			getMode     = function() return saBindMode end,
			isActive    = isSABindActive,
			getEnabled  = function() return silentAim.enabled or aimLock.enabled end,
		}
	end

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
		Callback = function(v) fovColor = v end,
	})

	fovSec:AddColorpicker("SAFovLocked", {
		Title    = "Locked Color",
		Default  = fovLocked,
		Callback = function(v) fovLocked = v end,
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

	-- ── Update (called every RenderStepped) ───────────────────────────────────────

	local function update(data)
		-- Aim Lock: directly interpolate camera CFrame toward the target.
		-- Works in both first and third person regardless of camera type because
		-- our RenderStepped fires AFTER the game's camera script (later connection),
		-- so cam.CFrame assignment overrides the game's update in the same frame.
		if aimLock.enabled and closestPart then
			local cam = data.cam
			if cam then
				local camPos    = cam.CFrame.Position
				local targetPos = closestPart.Position
				if (targetPos - camPos).Magnitude > 0.5 then
					pcall(function()
						local targetCF = CFrame.new(camPos, targetPos)
						cam.CFrame = cam.CFrame:Lerp(targetCF, math.min(aimSpeed * 4, 0.5))
					end)
				end
			end
		end

		-- FOV circle
		if showFov then
			fovCircle.Position = UserInputService:GetMouseLocation()
			fovCircle.Color    = (closestPart ~= nil) and fovLocked or fovColor
			fovCircle.Visible  = true
		else
			fovCircle.Visible = false
		end
	end

	-- ── Unmount ───────────────────────────────────────────────────────────────────

	local function unmount()
		removeHook()
		heartConn:Disconnect()
		if _saToggleConn then pcall(function() _saToggleConn:Disconnect() end) end
		pcall(function() fovCircle:Remove() end)
		closestPart = nil
	end

	return { update = update, unmount = unmount }
end
