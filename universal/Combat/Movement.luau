return function(ctx)
	local movementTab      = ctx.movementTab
	local makeBind         = ctx.makeBind
	local localPlayer      = ctx.localPlayer
	local Workspace        = ctx.Workspace
	local RunService       = ctx.RunService
	local UserInputService = ctx.UserInputService

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Shared helpers
	-- ─────────────────────────────────────────────────────────────────────────────

	local function getChar() return localPlayer.Character end
	local function getHum()
		local c = getChar()
		return c and c:FindFirstChildWhichIsA("Humanoid")
	end
	local function getHrp()
		local c = getChar()
		return c and c:FindFirstChild("HumanoidRootPart")
	end

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Startup cleanup: destroy Mya-named fly movers left from a previous session
	-- and clear PlatformStand. Do NOT touch CanCollide here — HumanoidRootPart is
	-- intentionally CanCollide=false in all Roblox characters and forcing it to true
	-- makes the physics shell solid, sinking the character into the ground.
	-- ─────────────────────────────────────────────────────────────────────────────

	pcall(function()
		local hrp = getHrp()
		if hrp then
			local bv = hrp:FindFirstChild("MyaFlyBV")
			local bg = hrp:FindFirstChild("MyaFlyBG")
			if bv then bv:Destroy() end
			if bg then bg:Destroy() end
		end
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end)

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Fly
	-- ─────────────────────────────────────────────────────────────────────────────

	local flySpeed = 50
	local flyOn    = false
	local flyBv    = nil
	local flyBg    = nil
	local flyConn  = nil

	local function stopFly()
		flyOn = false
		if flyConn then pcall(function() flyConn:Disconnect() end); flyConn = nil end
		if flyBv   then pcall(function() flyBv:Destroy() end);  flyBv   = nil end
		if flyBg   then pcall(function() flyBg:Destroy() end);  flyBg   = nil end
		local hum = getHum()
		if hum then pcall(function() hum.PlatformStand = false end) end
	end

	local function startFly()
		stopFly()
		local hrp = getHrp()
		local hum = getHum()
		if not hrp or not hum then return end

		hum.PlatformStand = true

		local bv = Instance.new("BodyVelocity")
		bv.Name     = "MyaFlyBV"
		bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		bv.Velocity = Vector3.zero
		bv.Parent   = hrp
		flyBv = bv

		local bg = Instance.new("BodyGyro")
		bg.Name      = "MyaFlyBG"
		bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		bg.D         = 400
		bg.CFrame    = hrp.CFrame
		bg.Parent    = hrp
		flyBg = bg

		flyOn = true

		flyConn = RunService.RenderStepped:Connect(function()
			if not flyOn then return end
			local cam = Workspace.CurrentCamera
			if not cam or not flyBv or not flyBg then return end

			local cf  = cam.CFrame
			-- Full 3D movement: W/S follow camera pitch so looking up = flying up.
			local fwd = cf.LookVector
			local rgt = cf.RightVector

			local vel = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + fwd end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - fwd end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - rgt end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + rgt end
			-- Explicit vertical for fine control when camera is level.
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				vel = vel + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				vel = vel - Vector3.new(0, 1, 0)
			end

			flyBv.Velocity = vel.Magnitude > 0.001 and vel.Unit * flySpeed or Vector3.zero
			flyBg.CFrame   = cf
		end)
	end

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Noclip
	-- ─────────────────────────────────────────────────────────────────────────────

	local noclipOn      = false
	local noclipConn   = nil
	local noclipOrig   = {}  -- { [part] = originalCanCollide }

	local function stopNoclip()
		noclipOn = false
		if noclipConn then pcall(function() noclipConn:Disconnect() end); noclipConn = nil end
		-- Restore each part's original CanCollide exactly as it was.
		for part, original in pairs(noclipOrig) do
			pcall(function() part.CanCollide = original end)
		end
		noclipOrig = {}
	end

	local function startNoclip()
		stopNoclip()
		-- Snapshot original CanCollide values before touching anything.
		local c = getChar()
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then
					noclipOrig[p] = p.CanCollide
				end
			end
		end
		noclipOn   = true
		noclipConn = RunService.Stepped:Connect(function()
			local char = getChar()
			if not char then return end
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end)
	end

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Walk Speed & Jump Power
	-- ─────────────────────────────────────────────────────────────────────────────

	local wsOn     = false
	local wsTarget = 30
	local wsOrig   = nil
	local jpOn     = false
	local jpTarget = 100
	local jpOrig   = nil

	local function applyWalkSpeed()
		local hum = getHum()
		if not hum then return end
		if wsOrig == nil then wsOrig = hum.WalkSpeed end
		hum.WalkSpeed = wsTarget
	end

	local function restoreWalkSpeed()
		local hum = getHum()
		if hum and wsOrig then pcall(function() hum.WalkSpeed = wsOrig end) end
		wsOrig = nil
	end

	local function applyJumpPower()
		local hum = getHum()
		if not hum then return end
		if jpOrig == nil then jpOrig = hum.JumpPower end
		pcall(function() hum.JumpPower  = jpTarget end)
		pcall(function() hum.JumpHeight = jpTarget end)
	end

	local function restoreJumpPower()
		local hum = getHum()
		if hum and jpOrig then
			pcall(function() hum.JumpPower  = jpOrig end)
			pcall(function() hum.JumpHeight = jpOrig end)
		end
		jpOrig = nil
	end

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Character respawn handling
	-- ─────────────────────────────────────────────────────────────────────────────

	local charConn = localPlayer.CharacterAdded:Connect(function()
		wsOrig, jpOrig = nil, nil
		-- Fully reset fly so update() sees flyOn=false and calls startFly() on next tick.
		flyOn = false
		flyBv, flyBg = nil, nil
		if flyConn then pcall(function() flyConn:Disconnect() end); flyConn = nil end
		-- Restore noclip on new character after a short delay to let it finish loading.
		if noclipOn then
			noclipOn = false
			if noclipConn then pcall(function() noclipConn:Disconnect() end); noclipConn = nil end
			task.wait(0.15)
			startNoclip()
		end
		-- Clear PlatformStand on the new character; noclipOrig is already reset by stopNoclip.
		task.defer(function()
			local hum = getHum()
			if hum then pcall(function() hum.PlatformStand = false end) end
		end)
	end)

	-- Heartbeat: re-apply walk/jump each tick so games can't reset them.
	local heartbeatConn = RunService.Heartbeat:Connect(function()
		if wsOn then applyWalkSpeed() end
		if jpOn then applyJumpPower() end
	end)

	-- ─────────────────────────────────────────────────────────────────────────────
	-- UI
	-- ─────────────────────────────────────────────────────────────────────────────

	-- Fly -------------------------------------------------------------------------
	local flySection = movementTab:AddSection("Fly")

	local flyBind = makeBind(flySection, {
		key   = "mvFlyOn01x",
		title = "Fly",
	})

	flySection:AddSlider("mvFlySp1x", {
		Title    = "Speed",
		Default  = 50,
		Min      = 5,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) flySpeed = v end,
	})

	-- Walk Speed ------------------------------------------------------------------
	local wsSection = movementTab:AddSection("Walk Speed")

	wsSection:AddToggle("mvWsOn001x", {
		Title    = "Enable",
		Icon     = "solar/running-bold",
		Default  = false,
		Callback = function(v) wsOn = v; if not v then restoreWalkSpeed() end end,
	})
	wsSection:AddSlider("mvWsVal1x", {
		Title    = "Speed",
		Default  = 30,
		Min      = 0,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) wsTarget = v end,
	})

	-- Jump Power ------------------------------------------------------------------
	local jpSection = movementTab:AddSection("Jump Power")

	jpSection:AddToggle("mvJpOn001x", {
		Title    = "Enable",
		Icon     = "solar/arrow-up-bold",
		Default  = false,
		Callback = function(v) jpOn = v; if not v then restoreJumpPower() end end,
	})
	jpSection:AddSlider("mvJpVal1x", {
		Title    = "Power",
		Default  = 100,
		Min      = 0,
		Max      = 500,
		Rounding = 0,
		Callback = function(v) jpTarget = v end,
	})

	-- Noclip ----------------------------------------------------------------------
	local ncSection = movementTab:AddSection("Noclip")

	local noclipBind = makeBind(ncSection, {
		key   = "mvNcOn001x",
		title = "Noclip",
	})

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Update: poll bind states → start/stop fly and noclip
	-- ─────────────────────────────────────────────────────────────────────────────

	local function update(_data)
		-- Fly state machine driven by bind widget.
		local flyWanted = flyBind.isActive()
		if flyWanted and not flyOn then
			startFly()
		elseif not flyWanted and flyOn then
			stopFly()
		end

		-- Noclip state machine.
		local ncWanted = noclipBind.isActive()
		if ncWanted and not noclipOn then
			startNoclip()
		elseif not ncWanted and noclipOn then
			stopNoclip()
		end
	end

	-- ─────────────────────────────────────────────────────────────────────────────
	-- Cleanup
	-- ─────────────────────────────────────────────────────────────────────────────

	local function unmount()
		stopFly()
		stopNoclip()
		restoreWalkSpeed()
		restoreJumpPower()
		flyBind.unmount()
		noclipBind.unmount()
		pcall(function() heartbeatConn:Disconnect() end)
		pcall(function() charConn:Disconnect() end)
	end

	return { update = update, unmount = unmount }
end
