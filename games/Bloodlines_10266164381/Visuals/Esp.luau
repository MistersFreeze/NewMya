return function(ctx)
    local visualsTab = ctx.visualsTab
    local RunService = ctx.RunService
    local Workspace = ctx.Workspace
    local Players = ctx.Players
    local isPlayerChar = ctx.isPlayerChar
    local getEntityKind = ctx.getEntityKind
    
    local CurrentCamera = Workspace.CurrentCamera
    local Lighting = game:GetService("Lighting")

    local playerEsp = { enabled = false, name = true, distance = true, health = false, color = Color3.fromRGB(255, 255, 255), maxDist = 1000 }
    local npcEsp    = { enabled = false, color = Color3.fromRGB(100, 200, 255), maxDist = 500 }
    local mobEsp    = { enabled = false, health = false, color = Color3.fromRGB(255, 80, 80), maxDist = 500 }

    local activeESPs = { players = {}, world = {} }
    
    -- ESP UI Sections
    local playerSec = visualsTab:AddSection("Player ESP")
    playerSec:AddToggle("PlayerESPEnabled", { Title = "Enable", Icon = "solar/user-bold", Default = false, Callback = function(v) playerEsp.enabled = v end })
    playerSec:AddColorpicker("PlayerESPColor", { Title = "Color", Default = playerEsp.color, Callback = function(v) playerEsp.color = v end })
    playerSec:AddToggle("PlayerESPName", { Title = "Name", Default = true, Callback = function(v) playerEsp.name = v end })
    playerSec:AddToggle("PlayerESPDistance", { Title = "Distance", Default = true, Callback = function(v) playerEsp.distance = v end })
    playerSec:AddToggle("PlayerESPHealth", { Title = "Health Bar", Default = false, Callback = function(v) playerEsp.health = v end })
    playerSec:AddSlider("PlayerESPMaxDist", { Title = "Max Distance", Default = 1000, Min = 100, Max = 3000, Rounding = 0, Callback = function(v) playerEsp.maxDist = v end })

    local npcSec = visualsTab:AddSection("NPC ESP")
    npcSec:AddToggle("NPCESPEnabled", { Title = "Enable", Icon = "solar/user-speak-bold", Default = false, Callback = function(v) npcEsp.enabled = v end })
    npcSec:AddColorpicker("NPCESPColor", { Title = "Color", Default = npcEsp.color, Callback = function(v) npcEsp.color = v end })
    npcSec:AddSlider("NPCESPMaxDist", { Title = "Max Distance", Default = 500, Min = 50, Max = 5000, Rounding = 0, Callback = function(v) npcEsp.maxDist = v end })

    local mobSec = visualsTab:AddSection("Mob ESP")
    mobSec:AddToggle("MobESPEnabled", { Title = "Enable", Icon = "solar/danger-bold", Default = false, Callback = function(v) mobEsp.enabled = v end })
    mobSec:AddColorpicker("MobESPColor", { Title = "Color", Default = mobEsp.color, Callback = function(v) mobEsp.color = v end })
    mobSec:AddToggle("MobESPHealth", { Title = "Health Bar", Default = false, Callback = function(v) mobEsp.health = v end })
    mobSec:AddSlider("MobESPMaxDist", { Title = "Max Distance", Default = 500, Min = 50, Max = 5000, Rounding = 0, Callback = function(v) mobEsp.maxDist = v end })

    local envSec = visualsTab:AddSection("Environment")
    
    local _origLighting = {}
    local function applyNoFog()
        if not _origLighting.FogEnd then _origLighting.FogEnd = Lighting.FogEnd end
        Lighting.FogEnd = 1e5
    end
    local function restoreFog()
        if _origLighting.FogEnd then Lighting.FogEnd = _origLighting.FogEnd end
    end
    
    -- Rain removal — broad name matching + watches for dynamically spawned particles
    local _origRain   = {}
    local _rainConn   = nil
    local RAIN_PATS   = { "rain", "drizzle", "precipitation", "raindrop", "downpour", "raineffect", "weatherrain" }
    local function isRainLike(name)
        name = name:lower()
        for _, pat in ipairs(RAIN_PATS) do
            if name:find(pat, 1, true) then return true end
        end
        return false
    end
    local function disableRainParticle(p)
        if not p.Parent then return end
        if not _origRain[p] then _origRain[p] = p.Enabled end
        pcall(function() p.Enabled = false end)
    end
    local function scanRain(root)
        for _, p in ipairs(root:GetDescendants()) do
            if p:IsA("ParticleEmitter") and isRainLike(p.Name) then
                disableRainParticle(p)
            end
        end
    end
    local function applyNoRain()
        scanRain(Workspace)
        scanRain(Lighting)
        if not _rainConn then
            _rainConn = Workspace.DescendantAdded:Connect(function(p)
                if p:IsA("ParticleEmitter") and isRainLike(p.Name) then
                    task.defer(function() disableRainParticle(p) end)
                end
            end)
        end
    end
    local function restoreRain()
        if _rainConn then _rainConn:Disconnect(); _rainConn = nil end
        for p, orig in pairs(_origRain) do pcall(function() p.Enabled = orig end) end
        table.clear(_origRain)
    end

    -- Snow removal
    local _origSnow  = {}
    local _snowConn  = nil
    local SNOW_PATS  = { "snow", "blizzard", "flake", "hail", "frost", "sleet" }
    local function isSnowLike(name)
        name = name:lower()
        for _, pat in ipairs(SNOW_PATS) do
            if name:find(pat, 1, true) then return true end
        end
        return false
    end
    local function disableSnowParticle(p)
        if not p.Parent then return end
        if not _origSnow[p] then _origSnow[p] = p.Enabled end
        pcall(function() p.Enabled = false end)
    end
    local function scanSnow(root)
        for _, p in ipairs(root:GetDescendants()) do
            if p:IsA("ParticleEmitter") and isSnowLike(p.Name) then
                disableSnowParticle(p)
            end
        end
    end
    local function applyNoSnow()
        scanSnow(Workspace)
        scanSnow(Lighting)
        if not _snowConn then
            _snowConn = Workspace.DescendantAdded:Connect(function(p)
                if p:IsA("ParticleEmitter") and isSnowLike(p.Name) then
                    task.defer(function() disableSnowParticle(p) end)
                end
            end)
        end
    end
    local function restoreSnow()
        if _snowConn then _snowConn:Disconnect(); _snowConn = nil end
        for p, orig in pairs(_origSnow) do pcall(function() p.Enabled = orig end) end
        table.clear(_origSnow)
    end
    
    local function applyFullBright()
        if not _origLighting.GlobalShadows then _origLighting.GlobalShadows = Lighting.GlobalShadows end
        if not _origLighting.Ambient then _origLighting.Ambient = Lighting.Ambient end
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
    end
    local function restoreFullBright()
        if _origLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = _origLighting.GlobalShadows end
        if _origLighting.Ambient then Lighting.Ambient = _origLighting.Ambient end
    end

    envSec:AddToggle("NoFog",      { Title = "Remove Fog",  Icon = "solar/cloud-bold",         Default = false, Callback = function(v) if v then applyNoFog()    else restoreFog()    end end })
    envSec:AddToggle("NoRain",     { Title = "Remove Rain", Icon = "solar/cloud-drizzle-bold", Default = false, Callback = function(v) if v then applyNoRain()   else restoreRain()   end end })
    envSec:AddToggle("NoSnow",     { Title = "Remove Snow", Icon = "solar/snowflake-bold",     Default = false, Callback = function(v) if v then applyNoSnow()   else restoreSnow()   end end })
    envSec:AddToggle("FullBright", { Title = "Fullbright",  Icon = "solar/sun-bold",           Default = false, Callback = function(v) if v then applyFullBright() else restoreFullBright() end end })

    -- ESP Rendering Functions
    local function hideDrawings(d)
        for _, obj in pairs(d) do
            if type(obj) == "table" then for _, ln in ipairs(obj) do ln.Visible = false end
            else obj.Visible = false end
        end
    end

    local function removePlayerESP(player)
        local e = activeESPs.players[player]
        if not e then return end
        if e.respawnConn then e.respawnConn:Disconnect() end
        for k, v in pairs(e.drawings) do
            if type(v) == "table" then for _, ln in ipairs(v) do ln:Remove() end
            else v:Remove() end
        end
        activeESPs.players[player] = nil
    end

    local function addPlayerESP(player)
        removePlayerESP(player)
        local corners = {}
        for i = 1, 8 do local ln = Drawing.new("Line"); ln.Visible = false; ln.ZIndex = 2; corners[i] = ln end
        local d = { box = Drawing.new("Square"), outline = Drawing.new("Square"), name = Drawing.new("Text"), dist = Drawing.new("Text"), hpBg = Drawing.new("Square"), hpBar = Drawing.new("Square"), corners = corners }
        d.name.Center = true; d.name.Outline = true; d.name.OutlineColor = Color3.fromRGB(0, 0, 0); d.name.Size = 14; d.name.Visible = false
        d.dist.Center = true; d.dist.Outline = true; d.dist.OutlineColor = Color3.fromRGB(0, 0, 0); d.dist.Size = 13; d.dist.Visible = false
        d.hpBg.Filled = true; d.hpBg.Color = Color3.fromRGB(30, 30, 30); d.hpBg.Thickness = 1; d.hpBg.ZIndex = 1; d.hpBg.Visible = false
        d.hpBar.Filled = true; d.hpBar.Thickness = 1; d.hpBar.ZIndex = 2; d.hpBar.Visible = false
        
        local entry = { drawings = d, respawnConn = nil }
        activeESPs.players[player] = entry

        entry.respawnConn = player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Players:FindFirstChild(player.Name) then addPlayerESP(player) end
        end)
    end

    local function removeWorldESP(model)
        local e = activeESPs.world[model]
        if not e then return end
        for k, v in pairs(e.drawings) do v:Remove() end
        activeESPs.world[model] = nil
    end

    local function addWorldESP(model, kind)
        removeWorldESP(model)
        local d = { box = Drawing.new("Square"), name = Drawing.new("Text"), dist = Drawing.new("Text"), hpBg = Drawing.new("Square"), hpBar = Drawing.new("Square") }
        d.name.Center = true; d.name.Outline = true; d.name.OutlineColor = Color3.fromRGB(0, 0, 0); d.name.Size = 13; d.name.Visible = false
        d.dist.Center = true; d.dist.Outline = true; d.dist.OutlineColor = Color3.fromRGB(0, 0, 0); d.dist.Size = 12; d.dist.Visible = false
        d.hpBg.Filled = true; d.hpBg.Color = Color3.fromRGB(30, 30, 30); d.hpBg.Thickness = 1; d.hpBg.ZIndex = 1; d.hpBg.Visible = false
        d.hpBar.Filled = true; d.hpBar.Thickness = 1; d.hpBar.ZIndex = 2; d.hpBar.Visible = false
        activeESPs.world[model] = { drawings = d, kind = kind }
    end

    -- Initialization
    for _, p in ipairs(Players:GetPlayers()) do if p ~= ctx.localPlayer then addPlayerESP(p) end end
    local paConn = Players.PlayerAdded:Connect(function(p) addPlayerESP(p) end)
    local prConn = Players.PlayerRemoving:Connect(function(p) removePlayerESP(p) end)

    local function updateWorldEntity(model, entry, camPos)
        local cfg = entry.kind == "mob" and mobEsp or npcEsp
        if not cfg.enabled or not model:IsDescendantOf(Workspace) then hideDrawings(entry.drawings); if not model:IsDescendantOf(Workspace) then removeWorldESP(model) end return end
        local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
        if not hrp then hideDrawings(entry.drawings); return end
        
        local dist = (hrp.Position - camPos).Magnitude
        if dist > cfg.maxDist then hideDrawings(entry.drawings); return end

        local sp, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
        if not onScreen or sp.Z <= 0 then hideDrawings(entry.drawings); return end

        local topSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
        local bottomSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, -3.0, 0))
        local x = math.floor(sp.X); local by = math.floor(math.min(topSP.Y, bottomSP.Y))
        local height = math.max(1, math.abs(math.floor(bottomSP.Y - topSP.Y)))
        local width = math.max(1, math.floor(height * 0.55)); local bx = math.floor(x - width * 0.5)

        local d = entry.drawings
        d.box.Size = Vector2.new(width, height); d.box.Position = Vector2.new(bx, by)
        d.box.Color = cfg.color; d.box.Filled = false; d.box.Thickness = 1; d.box.Visible = true

        local displayName = model.Name
        local settings = model:FindFirstChild("Settings")
        if settings then
            local npcNameVal = settings:FindFirstChild("NPCName")
            if npcNameVal and #tostring(npcNameVal.Value) > 0 then displayName = tostring(npcNameVal.Value) end
        end

        d.name.Position = Vector2.new(x, by - 15); d.name.Text = displayName; d.name.Color = cfg.color; d.name.Visible = true
        d.dist.Position = Vector2.new(x, by + height + 4); d.dist.Text = string.format("%.0f m", dist); d.dist.Color = cfg.color; d.dist.Visible = true

        if entry.kind == "mob" and mobEsp.health then
            local hum = model:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.MaxHealth > 0 then
                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local barH = math.max(1, height); local barW = 3; local barX = bx - barW - 2; local hpH = math.max(1, math.floor(barH * hp))
                d.hpBg.Size = Vector2.new(barW, barH); d.hpBg.Position = Vector2.new(barX, by); d.hpBg.Visible = true
                d.hpBar.Size = Vector2.new(barW, hpH); d.hpBar.Position = Vector2.new(barX, by + barH - hpH)
                d.hpBar.Color = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(255*hp), 0); d.hpBar.Visible = true
            else d.hpBg.Visible = false; d.hpBar.Visible = false end
        else d.hpBg.Visible = false; d.hpBar.Visible = false end
    end

    local function updatePlayerEntity(player, entry, camPos)
        if not playerEsp.enabled then hideDrawings(entry.drawings); return end
        local char = player.Character
        if not char then hideDrawings(entry.drawings); return end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
        if not hrp then hideDrawings(entry.drawings); return end

        local dist = (hrp.Position - camPos).Magnitude
        if dist > playerEsp.maxDist then hideDrawings(entry.drawings); return end

        local sp, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
        if not onScreen or sp.Z <= 0 then hideDrawings(entry.drawings); return end

        local topSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
        local bottomSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, -3.0, 0))
        local x = math.floor(sp.X); local by = math.floor(math.min(topSP.Y, bottomSP.Y))
        local height = math.max(1, math.abs(math.floor(bottomSP.Y - topSP.Y)))
        local width = math.max(1, math.floor(height * 0.55)); local bx = math.floor(x - width * 0.5)

        local d = entry.drawings
        for _, ln in ipairs(d.corners) do ln.Visible = false end
        d.box.Size = Vector2.new(width, height); d.box.Position = Vector2.new(bx, by)
        d.box.Color = playerEsp.color; d.box.Filled = false; d.box.Thickness = 1; d.box.Visible = true

        d.name.Position = Vector2.new(x, by - 16); d.name.Text = player.Name; d.name.Color = playerEsp.color; d.name.Visible = playerEsp.name
        d.dist.Position = Vector2.new(x, by + height + 4); d.dist.Text = string.format("%.0f m", dist); d.dist.Color = playerEsp.color; d.dist.Visible = playerEsp.distance

        if playerEsp.health then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.MaxHealth > 0 then
                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local barH = math.max(1, height); local barW = 3; local barX = bx - barW - 2; local hpH = math.max(1, math.floor(barH * hp))
                d.hpBg.Size = Vector2.new(barW, barH); d.hpBg.Position = Vector2.new(barX, by); d.hpBg.Visible = true
                d.hpBar.Size = Vector2.new(barW, hpH); d.hpBar.Position = Vector2.new(barX, by + barH - hpH)
                d.hpBar.Color = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(255*hp), 0); d.hpBar.Visible = true
            else d.hpBg.Visible = false; d.hpBar.Visible = false end
        else d.hpBg.Visible = false; d.hpBar.Visible = false end
    end

    local function update(data)
        local camPos = CurrentCamera.CFrame.Position
        for player, entry in pairs(activeESPs.players) do updatePlayerEntity(player, entry, camPos) end
        for model, entry in pairs(activeESPs.world) do updateWorldEntity(model, entry, camPos) end
        
        -- World ESP Scan
        if npcEsp.enabled or mobEsp.enabled then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and not isPlayerChar(obj) and not activeESPs.world[obj] then
                    local kind = getEntityKind(obj)
                    if kind == "npc" or kind == "mob" then addWorldESP(obj, kind) end
                end
            end
        end
    end

    local function unmount()
        paConn:Disconnect()
        prConn:Disconnect()
        for p in pairs(activeESPs.players) do removePlayerESP(p) end
        for m in pairs(activeESPs.world) do removeWorldESP(m) end
        restoreFog(); restoreRain(); restoreSnow(); restoreFullBright()
    end

    return { update = update, unmount = unmount }
end
