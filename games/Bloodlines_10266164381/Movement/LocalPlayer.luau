return function(ctx)
    local movementTab = ctx.movementTab
    local bindRegistry = ctx.bindRegistry
    local RunService = ctx.RunService
    local UserInputService = ctx.UserInputService
    local localPlayer = ctx.localPlayer
    local Workspace = ctx.Workspace

    local fly = { enabled = false, speed = 50, bodyVel = nil, bodyGyr = nil, conn = nil }
    local noclip = { enabled = false }
    local walkspeed = { enabled = false, speed = 50 }
    local jumppower = { enabled = false, power = 100 }

    -- Fly logic
    local function disableFly()
        if fly.conn then fly.conn:Disconnect(); fly.conn = nil end
        pcall(function() if fly.bodyVel then fly.bodyVel:Destroy() end end)
        pcall(function() if fly.bodyGyr then fly.bodyGyr:Destroy() end end)
        fly.bodyVel = nil; fly.bodyGyr = nil
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end

    local function enableFly()
        disableFly()
        local char = localPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then hum.PlatformStand = true end

        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.zero; bv.MaxForce = Vector3.new(1e5, 1e5, 1e5); bv.Parent = hrp
        fly.bodyVel = bv

        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5); bg.CFrame = hrp.CFrame; bg.P = 1e4; bg.D = 500; bg.Parent = hrp
        fly.bodyGyr = bg

        fly.conn = RunService.RenderStepped:Connect(function()
            if not fly.enabled then return end
            local char2 = localPlayer.Character
            if not char2 then return end
            local hrp2 = char2:FindFirstChild("HumanoidRootPart")
            if not hrp2 or not (fly.bodyVel and fly.bodyVel.Parent) or not (fly.bodyGyr and fly.bodyGyr.Parent) then return end

            local cf = Workspace.CurrentCamera.CFrame
            local dir = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end

            fly.bodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * fly.speed or Vector3.zero
            fly.bodyGyr.CFrame = cf
        end)
    end

    -- Noclip logic
    local _noclipParts = {}
    local function refreshNoclipParts(char)
        table.clear(_noclipParts)
        if not char then return end
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then _noclipParts[#_noclipParts + 1] = v end
        end
    end
    local function applyNoclip()
        for _, part in ipairs(_noclipParts) do pcall(function() part.CanCollide = false end) end
    end

    -- WalkSpeed & JumpPower
    local function applyWalkSpeed()
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.WalkSpeed = walkspeed.speed end
        end
    end
    local function resetWalkSpeed()
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end

    local function applyJumpPower()
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.JumpPower = jumppower.power end
        end
    end
    local function resetJumpPower()
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.JumpPower = 50 end
        end
    end

    -- UI Setup
    local flySec = movementTab:AddSection("Fly")
    local flySwitch = flySec:AddToggle("FlySwitch", { Title = "Fly", Icon = "solar/wind-bold", Default = false, Callback = function(v) fly.enabled = v; if v then enableFly() else disableFly() end end })
    local flyKb = flySec:AddKeybind("FlyBind", { Title = "Bind", Mode = "Toggle", Default = "", Callback = function(v) fly.enabled = v; if v then enableFly() else disableFly() end; pcall(function() flySwitch:SetValue(v) end) end })
    flySec:AddSlider("FlySpeed", { Title = "Speed", Default = 50, Min = 10, Max = 1000, Rounding = 0, Callback = function(v) fly.speed = v end })

    local noclipSec = movementTab:AddSection("Noclip")
    local noclipSwitch = noclipSec:AddToggle("NoclipSwitch", { Title = "Noclip", Icon = "solar/ghost-bold", Default = false, Callback = function(v) noclip.enabled = v end })
    local noclipKb = noclipSec:AddKeybind("NoclipBind", { Title = "Bind", Mode = "Toggle", Default = "", Callback = function(v) noclip.enabled = v; pcall(function() noclipSwitch:SetValue(v) end) end })

    local wsSec = movementTab:AddSection("Walk Speed")
    local wsSwitch = wsSec:AddToggle("WalkSpeedSwitch", { Title = "Walk Speed", Icon = "solar/running-bold", Default = false, Callback = function(v) walkspeed.enabled = v; if v then applyWalkSpeed() else resetWalkSpeed() end end })
    local wsKb = wsSec:AddKeybind("WalkSpeedBind", { Title = "Bind", Mode = "Toggle", Default = "", Callback = function(v) walkspeed.enabled = v; if v then applyWalkSpeed() else resetWalkSpeed() end; pcall(function() wsSwitch:SetValue(v) end) end })
    wsSec:AddSlider("WalkSpeedValue", { Title = "Speed", Default = 50, Min = 16, Max = 500, Rounding = 0, Callback = function(v) walkspeed.speed = v; if walkspeed.enabled then applyWalkSpeed() end end })

    local jpSec = movementTab:AddSection("Jump Power")
    local jpSwitch = jpSec:AddToggle("JumpPowerSwitch", { Title = "Jump Power", Icon = "solar/arrow-up-bold", Default = false, Callback = function(v) jumppower.enabled = v; if v then applyJumpPower() else resetJumpPower() end end })
    local jpKb = jpSec:AddKeybind("JumpPowerBind", { Title = "Bind", Mode = "Toggle", Default = "", Callback = function(v) jumppower.enabled = v; if v then applyJumpPower() else resetJumpPower() end; pcall(function() jpSwitch:SetValue(v) end) end })
    jpSec:AddSlider("JumpPowerValue", { Title = "Power", Default = 100, Min = 50, Max = 500, Rounding = 0, Callback = function(v) jumppower.power = v; if jumppower.enabled then applyJumpPower() end end })

    -- Register keybinds so the Keybind Display overlay can show them.
    if bindRegistry then
        local entries = {
            { name = "Fly",        kb = flyKb,     active = function() return fly.enabled      end },
            { name = "Noclip",     kb = noclipKb,  active = function() return noclip.enabled   end },
            { name = "Walk Speed", kb = wsKb,       active = function() return walkspeed.enabled end },
            { name = "Jump Power", kb = jpKb,       active = function() return jumppower.enabled end },
        }
        for _, e in ipairs(entries) do
            bindRegistry[#bindRegistry + 1] = {
                displayName = e.name,
                getKey      = function() return e.kb and e.kb.Value or nil end,
                getMode     = function() return "Toggle" end,
                isActive    = e.active,
                getEnabled  = function() return true end,
            }
        end
    end

    -- Char hooks
    local charAddedConn = localPlayer.CharacterAdded:Connect(function(char)
        if fly.enabled then task.delay(0.5, enableFly) end
        if walkspeed.enabled then task.delay(0.5, applyWalkSpeed) end
        if jumppower.enabled then task.delay(0.5, applyJumpPower) end
        refreshNoclipParts(char)
        char.DescendantAdded:Connect(function() refreshNoclipParts(char) end)
    end)
    if localPlayer.Character then
        refreshNoclipParts(localPlayer.Character)
        localPlayer.Character.DescendantAdded:Connect(function() refreshNoclipParts(localPlayer.Character) end)
    end

    local function update(data)
        if noclip.enabled then applyNoclip() end
        if walkspeed.enabled then applyWalkSpeed() end
        if jumppower.enabled then applyJumpPower() end
    end

    local function unmount()
        disableFly()
        resetWalkSpeed()
        resetJumpPower()
        charAddedConn:Disconnect()
    end

    return { update = update, unmount = unmount }
end
