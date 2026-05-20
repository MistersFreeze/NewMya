return function(ctx)
    local autoFarmTab = ctx.autoFarmTab
    local localPlayer = ctx.localPlayer
    local Players = ctx.Players

    local safeSpot = {
        pos = nil,
        autoTp = false,
        proxCheck = 1000,
    }

    local safeSpotSec = autoFarmTab:AddSection("Safe Spot Settings")
    local safeSpotInfo = safeSpotSec:AddParagraph({ Title = "Current Safe Spot", Content = "None" })
    
    safeSpotSec:AddButton({
        Title = "Get Safe Spot Coordinates",
        Callback = function()
            local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                safeSpot.pos = hrp.CFrame
                safeSpotInfo:SetContent(string.format("%.1f, %.1f, %.1f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
            end
        end
    })
    
    safeSpotSec:AddButton({
        Title = "Delete Safe Spot",
        Callback = function()
            safeSpot.pos = nil
            safeSpotInfo:SetContent("None")
        end
    })
    
    safeSpotSec:AddButton({
        Title = "Teleport to Safe Spot",
        Callback = function()
            if safeSpot.pos then
                local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then pcall(function() hrp.CFrame = safeSpot.pos end) end
            end
        end
    })
    
    safeSpotSec:AddSlider("SafeSpotProx", {
        Title    = "Player Proximity Check",
        Default  = 1000,
        Min      = 100,
        Max      = 3000,
        Rounding = 0,
        Callback = function(v) safeSpot.proxCheck = v end,
    })
    
    safeSpotSec:AddToggle("AutoTpSafeSpot", {
        Title    = "Auto TP when player near",
        Default  = false,
        Callback = function(v) safeSpot.autoTp = v end,
    })

    local active = true
    task.spawn(function()
        while active and task.wait(0.5) do
            if safeSpot.autoTp and safeSpot.pos then
                local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local isAtSafeSpot = (hrp.Position - safeSpot.pos.Position).Magnitude < 10
                    if not isAtSafeSpot then
                        local needTp = false
                        local _isWL  = _G.MYA_BL_IsWL
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= localPlayer and p.Character then
                                if _isWL and _isWL(p, "proximity") then continue end
                                local phrp = p.Character:FindFirstChild("HumanoidRootPart")
                                if phrp then
                                    local dist = (phrp.Position - hrp.Position).Magnitude
                                    if dist <= safeSpot.proxCheck then
                                        needTp = true
                                        break
                                    end
                                end
                            end
                        end
                        if needTp then
                            pcall(function() hrp.CFrame = safeSpot.pos end)
                        end
                    end
                end
            end
        end
    end)

    local function update(data) end
    local function unmount() active = false end

    return { update = update, unmount = unmount }
end
