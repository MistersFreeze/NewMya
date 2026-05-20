return function(ctx)
	local movementTab      = ctx.movementTab
	local bindRegistry     = ctx.bindRegistry
	local RunService       = ctx.RunService
	local UserInputService = ctx.UserInputService
	local localPlayer      = ctx.localPlayer
	local Workspace        = ctx.Workspace

	local fly       = { enabled = false, speed = 50 }
	local noclip    = { enabled = false }
	local walkspeed = { enabled = false, speed = 50 }
	local jumppower = { enabled = false, power = 100 }

	local flyConn = nil

	-- ── Fly ───────────────────────────────────────────────────────────────────────

	local function stopFly()
		if flyConn then flyConn:Disconnect(); flyConn = nil end
		local char = localPlayer.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, v in ipairs(hrp:GetChildren()) do
				if v.Name == "_MYA_BV" or v.Name == "_MYA_BG" then v:Destroy() end
			end
		end
		local hum = char:FindFirstChildWhichIsA("Humanoid")
		if hum then hum.PlatformStand = false end
	end

	local function startFly()
		stopFly()
		local char = localPlayer.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local hum = char:FindFirstChildWhichIsA("Humanoid")
		if hum then hum.PlatformStand = true end

		local bv = Instance.new("BodyVelocity")
		bv.Name = "_MYA_BV"; bv.Velocity = Vector3.zero
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5); bv.Parent = hrp

		local bg = Instance.new("BodyGyro")
		bg.Name = "_MYA_BG"; bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		bg.P = 1e4; bg.D = 500; bg.Parent = hrp

		flyConn = RunService.RenderStepped:Connect(function()
			if not fly.enabled then return end
			local bv2 = hrp:FindFirstChild("_MYA_BV")
			local bg2 = hrp:FindFirstChild("_MYA_BG")
			if not bv2 or not bg2 then return end
			local cam = Workspace.CurrentCamera
			if not cam then return end
			local dir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W)          then dir += cam.CFrame.LookVector  end
			if UserInputService:IsKeyDown(Enum.KeyCode.S)          then dir -= cam.CFrame.LookVector  end
			if UserInputService:IsKeyDown(Enum.KeyCode.A)          then dir -= cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D)          then dir += cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space)      then dir += Vector3.yAxis          end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)  then dir -= Vector3.yAxis          end
			bv2.Velocity = dir.Magnitude > 0 and dir.Unit * fly.speed or Vector3.zero
			bg2.CFrame   = cam.CFrame
		end)
	end

	-- ── Noclip ────────────────────────────────────────────────────────────────────

	local noclipConn = nil

	local function stopNoclip()
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
		local char = localPlayer.Character
		if not char then return end
		for _, v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") then
				pcall(function() v.CanCollide = true end)
			end
		end
	end

	local function startNoclip()
		stopNoclip()
		noclipConn = RunService.Stepped:Connect(function()
			if not noclip.enabled then return end
			local char = localPlayer.Character
			if not char then return end
			for _, v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					pcall(function() v.CanCollide = false end)
				end
			end
		end)
	end

	-- ── WalkSpeed & JumpPower ─────────────────────────────────────────────────────

	local function applyWalkSpeed()
		local char = localPlayer.Character
		local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
		if hum then hum.WalkSpeed = walkspeed.speed end
	end
	local function resetWalkSpeed()
		local char = localPlayer.Character
		local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
		if hum then hum.WalkSpeed = 16 end
	end

	local function applyJumpPower()
		local char = localPlayer.Character
		local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
		if hum then hum.JumpPower = jumppower.power end
	end
	local function resetJumpPower()
		local char = localPlayer.Character
		local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
		if hum then hum.JumpPower = 50 end
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local flySec = movementTab:AddSection("Fly")
	local flySwitch = flySec:AddToggle("FlySwitch", {
		Title = "Fly", Icon = "solar/wind-bold", Default = false,
		Callback = function(v) fly.enabled = v; if v then startFly() else stopFly() end end,
	})
	local flyKb = flySec:AddKeybind("FlyBind", { Title = "Bind", Default = "",
		Callback = function(v) fly.enabled = v; if v then startFly() else stopFly() end; pcall(function() flySwitch:SetValue(v) end) end,
	})
	flySec:AddSlider("FlySpeed", { Title = "Speed", Default = 50, Min = 10, Max = 1000, Rounding = 0,
		Callback = function(v) fly.speed = v end,
	})

	local noclipSec = movementTab:AddSection("Noclip")
	local noclipSwitch = noclipSec:AddToggle("NoclipSwitch", {
		Title = "Noclip", Icon = "solar/ghost-bold", Default = false,
		Callback = function(v) noclip.enabled = v; if v then startNoclip() else stopNoclip() end end,
	})
	local noclipKb = noclipSec:AddKeybind("NoclipBind", { Title = "Bind", Default = "",
		Callback = function(v) noclip.enabled = v; if v then startNoclip() else stopNoclip() end; pcall(function() noclipSwitch:SetValue(v) end) end,
	})

	local wsSec = movementTab:AddSection("Walk Speed")
	local wsSwitch = wsSec:AddToggle("WalkSpeedSwitch", {
		Title = "Walk Speed", Icon = "solar/running-bold", Default = false,
		Callback = function(v) walkspeed.enabled = v; if v then applyWalkSpeed() else resetWalkSpeed() end end,
	})
	local wsKb = wsSec:AddKeybind("WalkSpeedBind", { Title = "Bind", Default = "",
		Callback = function(v) walkspeed.enabled = v; if v then applyWalkSpeed() else resetWalkSpeed() end; pcall(function() wsSwitch:SetValue(v) end) end,
	})
	wsSec:AddSlider("WalkSpeedValue", { Title = "Speed", Default = 50, Min = 16, Max = 500, Rounding = 0,
		Callback = function(v) walkspeed.speed = v; if walkspeed.enabled then applyWalkSpeed() end end,
	})

	local jpSec = movementTab:AddSection("Jump Power")
	local jpSwitch = jpSec:AddToggle("JumpPowerSwitch", {
		Title = "Jump Power", Icon = "solar/arrow-up-bold", Default = false,
		Callback = function(v) jumppower.enabled = v; if v then applyJumpPower() else resetJumpPower() end end,
	})
	local jpKb = jpSec:AddKeybind("JumpPowerBind", { Title = "Bind", Default = "",
		Callback = function(v) jumppower.enabled = v; if v then applyJumpPower() else resetJumpPower() end; pcall(function() jpSwitch:SetValue(v) end) end,
	})
	jpSec:AddSlider("JumpPowerValue", { Title = "Power", Default = 100, Min = 50, Max = 500, Rounding = 0,
		Callback = function(v) jumppower.power = v; if jumppower.enabled then applyJumpPower() end end,
	})

	-- ── Keybind registry ──────────────────────────────────────────────────────────

	if bindRegistry then
		for _, e in ipairs({
			{ name = "Fly",        kb = flyKb,     active = function() return fly.enabled       end },
			{ name = "Noclip",     kb = noclipKb,  active = function() return noclip.enabled    end },
			{ name = "Walk Speed", kb = wsKb,       active = function() return walkspeed.enabled end },
			{ name = "Jump Power", kb = jpKb,       active = function() return jumppower.enabled end },
		}) do
			bindRegistry[#bindRegistry + 1] = {
				displayName = e.name,
				getKey      = function() return e.kb and e.kb.Value or nil end,
				getMode     = function() return "Toggle" end,
				isActive    = e.active,
				getEnabled  = function() return true end,
			}
		end
	end

	-- ── Character respawn ─────────────────────────────────────────────────────────

	local charConn = localPlayer.CharacterAdded:Connect(function()
		if fly.enabled      then task.delay(0.5, startFly)       end
		if noclip.enabled   then task.delay(0.5, startNoclip)    end
		if walkspeed.enabled then task.delay(0.5, applyWalkSpeed) end
		if jumppower.enabled then task.delay(0.5, applyJumpPower) end
	end)

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update()
		if walkspeed.enabled then applyWalkSpeed() end
		if jumppower.enabled then applyJumpPower() end
	end

	local function unmount()
		stopFly()
		stopNoclip()
		resetWalkSpeed()
		resetJumpPower()
		charConn:Disconnect()
	end

	return { update = update, unmount = unmount }
end
