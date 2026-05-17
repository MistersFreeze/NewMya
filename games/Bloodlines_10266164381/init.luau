-- Bloodlines script for New_Mya
-- PlaceId: 10266164381

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local LocalPlayer   = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local module = {}

local _active = {
    connections      = {},
    playerESPs       = {},   -- keyed by Player instance
    worldESPs        = {},   -- keyed by Model instance (NPCs + Mobs)
    layoutConn       = nil,
    Window           = nil,
    windowFrame      = nil,
    InterfaceManager = nil,
    layoutFile       = "Mya/Bloodlines/layout.json",
    -- widgets
    themeSync        = nil,
    watermark        = nil,
    keybindDisplay   = nil,
    usersOverlay     = nil,
    widgetConn       = nil,
}

-- ─── Feature state ────────────────────────────────────────────────────────────

local playerEsp = {
    enabled  = false,
    name     = true,
    distance = true,
    health   = false,
    color    = Color3.fromRGB(255, 255, 255),
    maxDist  = 1000,
}

local npcEsp = {
    enabled = false,
    color   = Color3.fromRGB(100, 200, 255),
    maxDist = 500,
}

local mobEsp = {
    enabled = false,
    health  = false,
    color   = Color3.fromRGB(255, 80, 80),
    maxDist = 500,
}

local fly = {
    enabled = false,
    speed   = 50,
    bodyVel = nil,
    bodyGyr = nil,
    conn    = nil,
}

local noclip = {
    enabled = false,
}

local walkspeed = {
    enabled = false,
    speed   = 50,
}

local jumppower = {
    enabled = false,
    power   = 100,
}

-- ─── Entity classification ────────────────────────────────────────────────────

local function isPlayerChar(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

-- Returns "player", "npc" (dialog), "mob" (combat), or nil
local function getEntityKind(model)
    if not model:IsA("Model") then return nil end
    if isPlayerChar(model) then return "player" end
    if not model:FindFirstChildWhichIsA("Humanoid") then return nil end
    local npcVal = model:FindFirstChild("NPC")
    if not npcVal then return nil end
    if tostring(npcVal.Value):lower() == "dialog" then return "npc" end
    return "mob"
end

-- ─── Player ESP ───────────────────────────────────────────────────────────────

local function removePlayerESP(player)
    local entry = _active.playerESPs[player]
    if not entry then return end
    if entry.conn        then entry.conn:Disconnect()        end
    if entry.respawnConn then entry.respawnConn:Disconnect() end
    local d = entry.drawings
    for _, key in ipairs({ "box", "outline", "name", "dist", "hpBg", "hpBar" }) do
        if d[key] then d[key].Visible = false; d[key]:Remove() end
    end
    for _, ln in ipairs(d.corners or {}) do ln.Visible = false; ln:Remove() end
    _active.playerESPs[player] = nil
end

local function addPlayerESP(player)
    removePlayerESP(player)

    local corners = {}
    for i = 1, 8 do
        local ln = Drawing.new("Line")
        ln.Visible = false; ln.ZIndex = 2
        corners[i] = ln
    end

    local d = {
        box     = Drawing.new("Square"),
        outline = Drawing.new("Square"),
        name    = Drawing.new("Text"),
        dist    = Drawing.new("Text"),
        hpBg    = Drawing.new("Square"),
        hpBar   = Drawing.new("Square"),
        corners = corners,
    }

    d.name.Center       = true
    d.name.Outline      = true
    d.name.OutlineColor = Color3.fromRGB(0, 0, 0)
    d.name.Size         = 14
    d.name.Visible      = false

    d.dist.Center       = true
    d.dist.Outline      = true
    d.dist.OutlineColor = Color3.fromRGB(0, 0, 0)
    d.dist.Size         = 13
    d.dist.Visible      = false

    d.hpBg.Filled    = true
    d.hpBg.Color     = Color3.fromRGB(30, 30, 30)
    d.hpBg.Thickness = 1
    d.hpBg.ZIndex    = 1
    d.hpBg.Visible   = false

    d.hpBar.Filled    = true
    d.hpBar.Thickness = 1
    d.hpBar.ZIndex    = 2
    d.hpBar.Visible   = false

    local function hideAll()
        d.box.Visible = false; d.outline.Visible = false
        d.name.Visible = false; d.dist.Visible = false
        d.hpBg.Visible = false; d.hpBar.Visible = false
        for _, ln in ipairs(corners) do ln.Visible = false end
    end

    local entry = { drawings = d, conn = nil, respawnConn = nil }
    _active.playerESPs[player] = entry

    entry.conn = RunService.RenderStepped:Connect(function()
        if not playerEsp.enabled then hideAll(); return end

        local char = player.Character
        if not char then hideAll(); return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChildWhichIsA("BasePart")
        if not hrp then hideAll(); return end

        local camPos = CurrentCamera.CFrame.Position
        local dist   = (hrp.Position - camPos).Magnitude
        if dist > playerEsp.maxDist then hideAll(); return end

        local sp, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
        if not onScreen or sp.Z <= 0 then hideAll(); return end

        local topSP    = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
        local bottomSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, -3.0, 0))
        local x      = math.floor(sp.X)
        local by     = math.floor(math.min(topSP.Y, bottomSP.Y))
        local height = math.max(1, math.abs(math.floor(bottomSP.Y - topSP.Y)))
        local width  = math.max(1, math.floor(height * 0.55))
        local bx     = math.floor(x - width * 0.5)

        local col = playerEsp.color

        for _, ln in ipairs(corners) do ln.Visible = false end
        d.outline.Visible  = false
        d.box.Size         = Vector2.new(width, height)
        d.box.Position     = Vector2.new(bx, by)
        d.box.Color        = col
        d.box.Filled       = false
        d.box.Thickness    = 1
        d.box.ZIndex       = 2
        d.box.Visible      = true

        d.name.Position = Vector2.new(x, by - 16)
        d.name.Text     = player.Name
        d.name.Color    = col
        d.name.Visible  = playerEsp.name
        d.name.ZIndex   = 3

        d.dist.Position = Vector2.new(x, by + height + 4)
        d.dist.Text     = string.format("%.0f m", dist)
        d.dist.Color    = col
        d.dist.Visible  = playerEsp.distance
        d.dist.ZIndex   = 3

        if playerEsp.health then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.MaxHealth > 0 then
                local hp    = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local barH  = math.max(1, height)
                local barW  = 3
                local barX  = bx - barW - 2
                local hpH   = math.max(1, math.floor(barH * hp))
                d.hpBg.Size     = Vector2.new(barW, barH)
                d.hpBg.Position = Vector2.new(barX, by)
                d.hpBg.Visible  = true
                d.hpBar.Size     = Vector2.new(barW, hpH)
                d.hpBar.Position = Vector2.new(barX, by + barH - hpH)
                d.hpBar.Color    = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(255*hp), 0)
                d.hpBar.Visible  = true
            else
                d.hpBg.Visible = false; d.hpBar.Visible = false
            end
        else
            d.hpBg.Visible = false; d.hpBar.Visible = false
        end
    end)

    entry.respawnConn = player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Players:FindFirstChild(player.Name) then addPlayerESP(player) end
    end)
end

-- ─── World ESP (NPCs + Mobs) ──────────────────────────────────────────────────

local function removeWorldESP(model)
    local entry = _active.worldESPs[model]
    if not entry then return end
    if entry.conn then entry.conn:Disconnect() end
    local d = entry.drawings
    for _, key in ipairs({ "box", "name", "dist", "hpBg", "hpBar" }) do
        if d[key] then d[key].Visible = false; d[key]:Remove() end
    end
    _active.worldESPs[model] = nil
end

local function addWorldESP(model, kind)
    removeWorldESP(model)

    local d = {
        box   = Drawing.new("Square"),
        name  = Drawing.new("Text"),
        dist  = Drawing.new("Text"),
        hpBg  = Drawing.new("Square"),
        hpBar = Drawing.new("Square"),
    }

    d.name.Center       = true
    d.name.Outline      = true
    d.name.OutlineColor = Color3.fromRGB(0, 0, 0)
    d.name.Size         = 13
    d.name.Visible      = false

    d.dist.Center       = true
    d.dist.Outline      = true
    d.dist.OutlineColor = Color3.fromRGB(0, 0, 0)
    d.dist.Size         = 12
    d.dist.Visible      = false

    d.hpBg.Filled    = true
    d.hpBg.Color     = Color3.fromRGB(30, 30, 30)
    d.hpBg.Thickness = 1
    d.hpBg.ZIndex    = 1
    d.hpBg.Visible   = false

    d.hpBar.Filled    = true
    d.hpBar.Thickness = 1
    d.hpBar.ZIndex    = 2
    d.hpBar.Visible   = false

    local function hideAll()
        d.box.Visible  = false; d.name.Visible = false
        d.dist.Visible = false
        d.hpBg.Visible = false; d.hpBar.Visible = false
    end

    local entry = { drawings = d, conn = nil, kind = kind }
    _active.worldESPs[model] = entry

    entry.conn = RunService.RenderStepped:Connect(function()
        local cfg = kind == "mob" and mobEsp or npcEsp
        if not cfg.enabled then hideAll(); return end

        if not model:IsDescendantOf(workspace) then
            removeWorldESP(model)
            return
        end

        local hrp = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChildWhichIsA("BasePart")
        if not hrp then hideAll(); return end

        local camPos = CurrentCamera.CFrame.Position
        local dist   = (hrp.Position - camPos).Magnitude
        if dist > cfg.maxDist then hideAll(); return end

        local sp, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
        if not onScreen or sp.Z <= 0 then hideAll(); return end

        local topSP    = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
        local bottomSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, -3.0, 0))
        local x      = math.floor(sp.X)
        local by     = math.floor(math.min(topSP.Y, bottomSP.Y))
        local height = math.max(1, math.abs(math.floor(bottomSP.Y - topSP.Y)))
        local width  = math.max(1, math.floor(height * 0.55))
        local bx     = math.floor(x - width * 0.5)

        d.box.Size      = Vector2.new(width, height)
        d.box.Position  = Vector2.new(bx, by)
        d.box.Color     = cfg.color
        d.box.Filled    = false
        d.box.Thickness = 1
        d.box.ZIndex    = 2
        d.box.Visible   = true

        -- Prefer NPCName from Settings folder, fall back to model name
        local displayName = model.Name
        local settings = model:FindFirstChild("Settings")
        if settings then
            local npcNameVal = settings:FindFirstChild("NPCName")
            if npcNameVal and #tostring(npcNameVal.Value) > 0 then
                displayName = tostring(npcNameVal.Value)
            end
        end

        d.name.Position = Vector2.new(x, by - 15)
        d.name.Text     = displayName
        d.name.Color    = cfg.color
        d.name.Visible  = true
        d.name.ZIndex   = 3

        d.dist.Position = Vector2.new(x, by + height + 4)
        d.dist.Text     = string.format("%.0f m", dist)
        d.dist.Color    = cfg.color
        d.dist.Visible  = true
        d.dist.ZIndex   = 3

        -- Health bar for mobs
        if kind == "mob" and mobEsp.health then
            local hum = model:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.MaxHealth > 0 then
                local hp   = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local barH = math.max(1, height)
                local barW = 3
                local barX = bx - barW - 2
                local hpH  = math.max(1, math.floor(barH * hp))
                d.hpBg.Size     = Vector2.new(barW, barH)
                d.hpBg.Position = Vector2.new(barX, by)
                d.hpBg.Visible  = true
                d.hpBar.Size     = Vector2.new(barW, hpH)
                d.hpBar.Position = Vector2.new(barX, by + barH - hpH)
                d.hpBar.Color    = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(255*hp), 0)
                d.hpBar.Visible  = true
            else
                d.hpBg.Visible = false; d.hpBar.Visible = false
            end
        else
            d.hpBg.Visible = false; d.hpBar.Visible = false
        end
    end)
end

local function tryRegisterWorkspaceEntity(obj)
    if not obj:IsA("Model") then return end
    if isPlayerChar(obj) then return end
    task.defer(function()
        if not obj:IsDescendantOf(workspace) then return end
        local kind = getEntityKind(obj)
        if kind == "npc" or kind == "mob" then
            addWorldESP(obj, kind)
        end
    end)
end

-- ─── Fly ──────────────────────────────────────────────────────────────────────

local function disableFly()
    if fly.conn then fly.conn:Disconnect(); fly.conn = nil end
    pcall(function() if fly.bodyVel then fly.bodyVel:Destroy() end end)
    pcall(function() if fly.bodyGyr then fly.bodyGyr:Destroy() end end)
    fly.bodyVel = nil
    fly.bodyGyr = nil

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

local function enableFly()
    disableFly()

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.PlatformStand = true end

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent   = hrp
    fly.bodyVel = bv

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.CFrame    = hrp.CFrame
    bg.P         = 1e4
    bg.D         = 500
    bg.Parent    = hrp
    fly.bodyGyr  = bg

    fly.conn = RunService.RenderStepped:Connect(function()
        if not fly.enabled then return end
        local char2 = LocalPlayer.Character
        if not char2 then return end
        local hrp2 = char2:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return end
        if not (fly.bodyVel and fly.bodyVel.Parent) then return end
        if not (fly.bodyGyr and fly.bodyGyr.Parent) then return end

        local cf  = workspace.CurrentCamera.CFrame
        local dir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)      then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)  then dir = dir - Vector3.yAxis end

        fly.bodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * fly.speed or Vector3.zero
        fly.bodyGyr.CFrame   = cf
    end)
end

-- ─── Noclip ───────────────────────────────────────────────────────────────────
-- Parts are cached on CharacterAdded so the Stepped loop never calls GetDescendants.

local _noclipParts = {}

local function refreshNoclipParts(char)
    table.clear(_noclipParts)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then _noclipParts[#_noclipParts + 1] = v end
    end
end

local function applyNoclip()
    for _, part in ipairs(_noclipParts) do
        pcall(function() part.CanCollide = false end)
    end
end

-- ─── WalkSpeed ────────────────────────────────────────────────────────────────

local function applyWalkSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.WalkSpeed = walkspeed.speed end
end

local function resetWalkSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end

-- ─── JumpPower ────────────────────────────────────────────────────────────────

local function applyJumpPower()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.JumpPower = jumppower.power end
end

local function resetJumpPower()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.JumpPower = 50 end
end

-- ─── Chakra Sense / Users helpers ────────────────────────────────────────────

local function getPlayerSettings(player)
    local char = player.Character
    local s = char and char:FindFirstChild("Settings")
    if s then return s end
    local rsS = ReplicatedStorage:FindFirstChild("Settings")
    return rsS and rsS:FindFirstChild(player.Name)
end

-- Normalize a name: lowercase, strip spaces/underscores/hyphens
local function normName(s) return s:lower():gsub("[%s_%-]", "") end

-- Deep-scan a model/folder for a child whose normalized name matches any pattern
local function deepFind(root, patterns)
    for _, v in ipairs(root:GetDescendants()) do
        local n = normName(v.Name)
        for _, pat in ipairs(patterns) do
            if n == pat or n:find(pat, 1, true) then return v end
        end
    end
    return nil
end

-- Returns has-CS, is-actively-sensing for a given player
local function scanPlayerCS(player)
    local char = player.Character
    local hasCS, sensing = false, false

    -- 1. Scan character hierarchy (Settings descendants + whole character)
    if char then
        local CS_NAMES    = { "chakrasense", "cs", "chakrasensing", "sensechakra" }
        local SENSE_NAMES = { "sensing", "usingsense", "senseon", "chakrasensing", "sensechakra" }

        -- direct descendants of char
        for _, v in ipairs(char:GetDescendants()) do
            local n = normName(v.Name)
            for _, pat in ipairs(CS_NAMES) do
                if n == pat then
                    hasCS = true
                    if v:IsA("BoolValue") and v.Value then sensing = true end
                end
            end
            for _, pat in ipairs(SENSE_NAMES) do
                if n == pat and v:IsA("BoolValue") and v.Value then
                    hasCS = true; sensing = true
                end
            end
        end

        -- character attributes
        pcall(function()
            for k, v in pairs(char:GetAttributes()) do
                local n = normName(k)
                if n == "chakrasense" or n == "cs" then
                    hasCS = true
                    if v == true then sensing = true end
                end
                if n == "sensing" and v == true then hasCS = true; sensing = true end
            end
        end)
    end

    -- 2. ReplicatedStorage.Settings.[playerName] descendants
    local rsS = ReplicatedStorage:FindFirstChild("Settings")
    local ps  = rsS and rsS:FindFirstChild(player.Name)
    if ps then
        for _, v in ipairs(ps:GetDescendants()) do
            local n = normName(v.Name)
            if n == "chakrasense" or n == "cs" then
                hasCS = true
                if v:IsA("BoolValue") and v.Value then sensing = true end
            end
            if n == "sensing" and v:IsA("BoolValue") and v.Value then
                hasCS = true; sensing = true
            end
        end
    end

    return hasCS, sensing
end

-- Returns nearest other player and distance, or nil/0
local function getNearestPlayer()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 0 end
    local nearP, nearDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local c = p.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then continue end
        local d = (r.Position - hrp.Position).Magnitude
        if d < nearDist then nearDist = d; nearP = p end
    end
    return nearP, nearDist
end

-- Returns total CS holders and active count.
-- Falls back to reading the game's own PlayerGui labels if character scan yields 0.
-- Scrape a text string for CS counts. Returns updated (total, active).
local function scrapeCSText(t, total, active)
    -- "people with chakra sense" = holders (total)
    -- Must NOT use broad "chakra sense" which also matches "active chakra sense players"
    if t:find("people with chakra") then
        local n = t:match("(%d+)")
        if n then local v = tonumber(n) or 0; if v > total then total = v end end
    end
    -- "active chakra" = currently sensing (active)
    if t:find("active chakra") or t:find("using chakra sense") then
        local n = t:match("(%d+)")
        if n then local v = tonumber(n) or 0; if v > active then active = v end end
    end
    return total, active
end

-- Cache so getCSCounts() is safe to call at 60fps without freezing.
-- Workspace is scanned once asynchronously at startup (chunked, no freeze).
local _csCache = { total = 0, active = 0, lastScan = -100 }

local function getCSCounts()
    local now = tick()
    if now - _csCache.lastScan < 2 then             -- return cached value
        return _csCache.total, _csCache.active
    end
    _csCache.lastScan = now

    local total, active = 0, 0

    -- Character scan
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local has, using = scanPlayerCS(p)
        if using then has = true end
        if has   then total  = total  + 1 end
        if using then active = active + 1 end
    end

    -- PlayerGui scan (fast — hundreds of objects at most)
    pcall(function()
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if not gui:IsA("ScreenGui") then continue end
            local gn = gui.Name:lower()
            if gn:find("mya") or gn:find("fluent") then continue end
            for _, lbl in ipairs(gui:GetDescendants()) do
                if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
                    total, active = scrapeCSText(lbl.Text:lower(), total, active)
                end
            end
        end
    end)

    -- Blend with any higher values the workspace async scan found
    if _csCache.total  > total  then total  = _csCache.total  end
    if _csCache.active > active then active = _csCache.active end

    _csCache.total  = total
    _csCache.active = active
    return total, active
end

-- Async workspace scan (done once at startup in chunks to avoid freezing).
task.spawn(function()
    task.wait(3)
    local objs = workspace:GetDescendants()
    local total, active = 0, 0
    local CHUNK = 150
    for i = 1, #objs, CHUNK do
        for j = i, math.min(i + CHUNK - 1, #objs) do
            local obj = objs[j]
            if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then continue end
            local t = obj.Text:lower()
            total, active = scrapeCSText(t, total, active)

            -- Event-driven: connect Changed on any label that carries CS counts
            -- so the cache updates the instant the game changes the number.
            if t:find("people with chakra") or t:find("active chakra") then
                pcall(function()
                    local conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
                        local nt = obj.Text:lower()
                        -- Scrape from this label only; use 0 base to avoid stale carryover
                        local lt, la = scrapeCSText(nt, 0, 0)
                        if lt > 0 then _csCache.total  = lt end
                        if la > 0 then _csCache.active = la end
                        -- Push the TTL far into the future — no need to re-poll now
                        _csCache.lastScan = tick() + 30
                    end)
                    -- Store for cleanup — _active is module-level, accessible here
                    table.insert(_active.connections, conn)
                end)
            end
        end
        task.wait()   -- yield between chunks — no frame spikes
    end
    if total  > _csCache.total  then _csCache.total  = total  end
    if active > _csCache.active then _csCache.active = active end
end)

-- ─── Moderator detection ─────────────────────────────────────────────────────
-- Known staff usernames from the game dump (hardcoded in the client scripts).
local MOD_USERNAMES = {
    "maxy1221648",   -- Dev / super-admin
    "ArkhamDeluxe",  -- Senior admin
    "Pr1maryPath",   -- Senior admin
    "Spearess",      -- Admin
    "Etheriox",      -- Senior admin
    "Blahiren",      -- Senior admin
    "Ako_Shiba",     -- Admin
}

-- Called whenever a player joins; shows a Fluent notification if they appear to be staff.
local function detectModAndNotify(player, Fluent)
    if player == LocalPlayer then return end

    -- Layer 1: hardcoded username list
    for _, name in ipairs(MOD_USERNAMES) do
        if player.Name:lower() == name:lower() then
            pcall(function()
                Fluent:Notify({
                    Title    = "Staff Joined",
                    Content  = player.Name .. " (Dev / Staff) is in this server.",
                    Duration = 8,
                })
            end)
            return
        end
    end

    -- Layer 2: scan character Settings for a moderator-rank value
    local notified = false
    local function scanSettings(char)
        if notified or not char then return end
        local s = char:FindFirstChild("Settings")
            or (ReplicatedStorage:FindFirstChild("Settings")
                and ReplicatedStorage.Settings:FindFirstChild(player.Name))
        if not s then return end
        for _, v in ipairs(s:GetChildren()) do
            local n = v.Name:lower()
            if n == "moderator" or n == "ismod" or n == "rank" or n == "staff" then
                local val = v.Value
                if val and val ~= false and val ~= "" and val ~= 0 then
                    notified = true
                    pcall(function()
                        Fluent:Notify({
                            Title    = "Moderator Detected",
                            Content  = player.Name .. " — rank: " .. tostring(val),
                            Duration = 8,
                        })
                    end)
                    return
                end
            end
        end
    end

    if player.Character then task.spawn(scanSettings, player.Character) end
    -- Re-check on respawn (character might not be loaded yet)
    local respConn
    respConn = player.CharacterAdded:Connect(function(char)
        task.wait(1)
        task.spawn(scanSettings, char)
        if notified then respConn:Disconnect() end
    end)
end

-- ─── CS visual alert ─────────────────────────────────────────────────────────
-- A persistent Drawing label shown when another player has Chakra Sense active
-- (i.e. _csCache.active > 0). Toggle-controlled from the Visuals tab.

local _csAlertDrawing = nil
local _csAlertEnabled = false

local function initCSAlertDrawing()
    if _csAlertDrawing then pcall(function() _csAlertDrawing:Remove() end) end
    _csAlertDrawing               = Drawing.new("Text")
    _csAlertDrawing.Text          = "⚠  CHAKRA SENSE  ⚠"
    _csAlertDrawing.Size          = 20
    _csAlertDrawing.Color         = Color3.fromRGB(255, 55, 55)
    _csAlertDrawing.Outline       = true
    _csAlertDrawing.OutlineColor  = Color3.fromRGB(0, 0, 0)
    _csAlertDrawing.Bold          = true
    _csAlertDrawing.Center        = true
    _csAlertDrawing.ZIndex        = 10
    _csAlertDrawing.Visible       = false
end

-- ─── Lighting / visual extras ─────────────────────────────────────────────────

local _litOrig = {}  -- stores restored values

local function applyNoFog()
    _litOrig.fogEnd   = Lighting.FogEnd
    _litOrig.fogStart = Lighting.FogStart
    Lighting.FogEnd   = 100000
    Lighting.FogStart = 99999
end
local function restoreFog()
    if _litOrig.fogEnd   then Lighting.FogEnd   = _litOrig.fogEnd   end
    if _litOrig.fogStart then Lighting.FogStart = _litOrig.fogStart end
end

local _rainParts = {}
local function applyNoRain()
    local function disableIn(parent)
        pcall(function()
            for _, v in ipairs(parent:GetDescendants()) do
                if v:IsA("ParticleEmitter") then
                    local n = v.Name:lower()
                    if n:find("rain") or n:find("drop") or n:find("drizzle") then
                        _rainParts[v] = v.Enabled
                        pcall(function() v.Enabled = false end)
                    end
                end
            end
        end)
    end
    disableIn(Lighting); disableIn(workspace)
end
local function restoreRain()
    for v, was in pairs(_rainParts) do pcall(function() v.Enabled = was end) end
    _rainParts = {}
end

local function applyFullBright()
    _litOrig.brightness = Lighting.Brightness
    _litOrig.ambient    = Lighting.Ambient
    _litOrig.outdoor    = Lighting.OutdoorAmbient
    Lighting.Brightness     = 2
    Lighting.Ambient        = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end
local function restoreFullBright()
    if _litOrig.brightness then Lighting.Brightness     = _litOrig.brightness end
    if _litOrig.ambient    then Lighting.Ambient        = _litOrig.ambient    end
    if _litOrig.outdoor    then Lighting.OutdoorAmbient = _litOrig.outdoor    end
end

-- ─── Player features ──────────────────────────────────────────────────────────

local noFallDmg  = { enabled = false }
local noM1CD     = { enabled = false }
local noStun     = { enabled = false }
local _stunConns  = {}
local _noFallConns = {}

-- No fall damage: watch Humanoid state transitions and restore health after landing.
-- SetStateEnabled(FallingDown) only prevents the tumble animation, not the damage.
-- The real fix is capturing health before a jump/fall and restoring it on landing.
local function applyNoFallDmg(char)
    for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
    table.clear(_noFallConns)
    char = char or LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return end
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)

    local inFall       = false
    local savedHealth  = hum.Health

    local sc = hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Jumping
            or new == Enum.HumanoidStateType.Freefall then
            inFall = true
            savedHealth = hum.Health
        elseif inFall and (new == Enum.HumanoidStateType.Landed
            or new == Enum.HumanoidStateType.Running
            or new == Enum.HumanoidStateType.RunningNoPhysics
            or new == Enum.HumanoidStateType.GettingUp) then
            local h = savedHealth
            inFall = false
            task.delay(0.08, function()
                if noFallDmg.enabled and hum and hum.Parent then
                    pcall(function() hum.Health = math.max(hum.Health, h) end)
                end
            end)
        end
    end)
    table.insert(_noFallConns, sc)
end

local function restoreNoFallDmg(char)
    for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
    table.clear(_noFallConns)
    char = char or LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end) end
end

local function applyNoM1CD()
    if typeof(getgc) ~= "function" then return end
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if type(v) ~= "table" then continue end
            for k, val in pairs(v) do
                local ks = tostring(k):lower()
                if (ks == "m1" or ks == "m1cd" or ks == "m1cooldown"
                    or ks == "basiccooldown" or ks == "attackcooldown"
                    or ks == "punchcooldown") and type(val) == "number" then
                    rawset(v, k, 0)
                end
            end
        end
    end)
end

local function setupNoStun(char)
    for _, c in ipairs(_stunConns) do pcall(function() c:Disconnect() end) end
    _stunConns = {}
    if not char then return end
    local function watchSettings(s)
        if not s then return end
        local st = s:FindFirstChild("Stunned")
        if st and st:IsA("BoolValue") then
            local c = st.Changed:Connect(function(v)
                if v and noStun.enabled then pcall(function() st.Value = false end) end
            end)
            table.insert(_stunConns, c)
        end
    end
    watchSettings(char:FindFirstChild("Settings"))
    local rsS = ReplicatedStorage:FindFirstChild("Settings")
    if rsS then watchSettings(rsS:FindFirstChild(char.Name)) end
end

-- ─── Infinite Stamina / Chakra ───────────────────────────────────────────────

local infStamina = { enabled = false }
local infChakra  = { enabled = false }

-- Safe point + auto-teleport (shared between teleport do-block and CharacterAdded)
local _safePoint = nil    -- Vector3 saved by the user
local _autoTP    = { enabled = false, threshold = 30 }
local _autoTPFn  = nil    -- set inside mount's teleport block, used by CharacterAdded

-- Stamina / Chakra: cache the found NumberValues once per character spawn
-- so the Heartbeat loop never calls GetDescendants each frame.
local _staminaCache = {}   -- {val=NumberValue|IntValue, cap=number}
local _chakraCache  = {}

local function buildStatCache(char, keywords, cache)
    table.clear(cache)
    if not char then return end
    local function scanSettings(s)
        if not s then return end
        for _, v in ipairs(s:GetDescendants()) do
            if not (v:IsA("NumberValue") or v:IsA("IntValue")) then continue end
            local n = v.Name:lower()
            for _, kw in ipairs(keywords) do
                if n == kw or n:find(kw, 1, true) then
                    local maxV = s:FindFirstChild("Max" .. v.Name)
                              or s:FindFirstChild(v.Name .. "Max")
                    local cap = (maxV and maxV.Value and maxV.Value > 0) and maxV.Value or 100
                    cache[#cache + 1] = { val = v, cap = cap }
                    break
                end
            end
        end
    end
    scanSettings(char:FindFirstChild("Settings"))
    local rsS = ReplicatedStorage:FindFirstChild("Settings")
    if rsS then scanSettings(rsS:FindFirstChild(char.Name)) end
end

local function applyStatCache(cache)
    for _, e in ipairs(cache) do
        pcall(function()
            if e.val and e.val.Parent and e.val.Value < e.cap then
                e.val.Value = e.cap
            end
        end)
    end
end

-- ─── Streamer mode & watermark patch ─────────────────────────────────────────

local streamer = { enabled = false }
local _streamerOrig = {}

local function applyStreamer(char)
    char = char or LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then
        _streamerOrig.dispName = hum.DisplayName
        pcall(function() hum.DisplayName = "Mya Script" end)
    end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextButton") then
            if v.Text == LocalPlayer.Name or v.Text == LocalPlayer.DisplayName
                or (_streamerOrig.dispName and v.Text == _streamerOrig.dispName) then
                _streamerOrig[v] = v.Text
                pcall(function() v.Text = "Mya Script" end)
            end
        end
    end
end
local function restoreStreamer(char)
    char = char or LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum and _streamerOrig.dispName then
        pcall(function() hum.DisplayName = _streamerOrig.dispName end)
    end
    for v, orig in pairs(_streamerOrig) do
        if typeof(v) == "Instance" then pcall(function() v.Text = orig end) end
    end
    _streamerOrig = {}
end

local function patchWatermarkLabel(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        local t = obj.Text or ""
        if t:lower():find("ilovehewho") then
            -- Replace the entire string — gsub would leave trailing content like "| 1826236298"
            pcall(function() obj.Text = "Mya Script" end)
        end
    end
end

-- ─── mount ────────────────────────────────────────────────────────────────────

function module.mount(ctx)

    -- ── Pre-creation cleanup: destroy all hub Fluent artifacts ───────────────────
    -- Also lobotomize the old singleton so Fluent can't recreate its ScreenGui.
    _G.MYA_FLUENT_SINGLETON = nil
    pcall(function()
        local old = _G.MYA_FLUENT_SINGLETON
        if typeof(old) == "table" then
            -- Stop old Fluent from doing anything further
            pcall(function() old.Notify = function() end end)
            pcall(function() old.CreateWindow = function() end end)
            -- Walk up from old.GUI to destroy the ScreenGui ancestor
            if typeof(old.GUI) == "Instance" then
                local node = old.GUI
                for _ = 1, 12 do
                    if node:IsA("ScreenGui") then pcall(function() node:Destroy() end); break end
                    local p = node.Parent
                    if not p or p == game then pcall(function() old.GUI:Destroy() end); break end
                    node = p
                end
            end
        end
    end)

    -- Wipe ALL of gethui() — it is our exclusive script sandbox.
    pcall(function()
        if typeof(gethui) ~= "function" then return end
        local hui = gethui()
        if not hui then return end
        for _, c in ipairs(hui:GetChildren()) do pcall(function() c:Destroy() end) end
    end)

    -- In PlayerGui and CoreGui only destroy by NAME — never by structure,
    -- otherwise the game's own full-screen UI gets killed and breaks all input.
    local function sweepByName(parent)
        if not parent then return end
        pcall(function()
            for _, sg in ipairs(parent:GetChildren()) do
                if not sg:IsA("ScreenGui") then continue end
                local n = sg.Name:lower()
                if n == "fluent" or n == "fluentui" or n:sub(1, 6) == "fluent" then
                    pcall(function() sg:Destroy() end)
                end
            end
        end)
    end
    pcall(function() sweepByName(LocalPlayer:FindFirstChild("PlayerGui")) end)
    -- CoreGui is NOT swept — touching it can break Roblox's own input handling (Escape, Alt+F4).

    -- ── Fresh Fluent instance (own ScreenGui, no shared state with hub) ──────────
    local Fluent
    do
        -- Reuse prefetched source bytes to avoid a re-download.
        local src = getgenv and getgenv().MYA_PREFETCH_FLUENT_SRC or nil
        if typeof(src) ~= "string" or #src < 500 then
            local ok, s = pcall(game.HttpGet, game, ctx.baseUrl .. "New_Mya/lib/FluentModded.lua", true)
            if ok and typeof(s) == "string" and #s > 500 then src = s end
        end
        if typeof(src) ~= "string" or #src < 500 then
            src = game:HttpGet(
                "https://github.com/StyearX/Fluent-Modded/releases/download/FluentBeta/Fluent.lua",
                true
            )
        end
        local fn = assert(loadstring(src, "@FluentModded"), "Fluent compile failed")
        Fluent = fn()
        _G.MYA_FLUENT_SINGLETON = Fluent
    end

    local SaveManager      = Fluent.SaveManager
    local InterfaceManager = Fluent.InterfaceManager

    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    InterfaceManager:SetFolder("Mya/Bloodlines")
    SaveManager:SetFolder("Mya/Bloodlines/Config")

    -- ── SaveManager notification hooks ────────────────────────────────────────
    -- Wrap SaveConfig and SetAutoloadConfig to emit Fluent notifications.
    -- Must be done after SetLibrary/SetFolder and before BuildConfigSection.
    pcall(function()
        local origSave = SaveManager.SaveConfig
        if origSave then
            SaveManager.SaveConfig = function(self, name)
                local ok, err = pcall(origSave, self, name)
                pcall(function()
                    Fluent:Notify({
                        Title    = ok and "Config Saved" or "Save Failed",
                        Content  = ok and ("\"" .. tostring(name) .. "\" saved.")
                                       or tostring(err),
                        Duration = 3,
                    })
                end)
                return ok, err
            end
        end

        local origAutoload = SaveManager.SetAutoloadConfig
        if origAutoload then
            SaveManager.SetAutoloadConfig = function(self, name)
                local ok, err = pcall(origAutoload, self, name)
                pcall(function()
                    Fluent:Notify({
                        Title    = "Autoload Set",
                        Content  = "\"" .. tostring(name or "none") .. "\" will auto-apply on load.",
                        Duration = 4,
                    })
                end)
                return ok, err
            end
        end
    end)

    -- Force RightShift before LoadSettings
    pcall(function()
        if typeof(isfile) == "function" and isfile("Mya/Bloodlines/options.json") then
            local raw = readfile("Mya/Bloodlines/options.json")
            local ok, opts = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and typeof(opts) == "table" then
                opts.MenuKeybind = "RightShift"
                pcall(writefile, "Mya/Bloodlines/options.json", HttpService:JSONEncode(opts))
            end
        end
    end)

    InterfaceManager:LoadSettings()
    InterfaceManager.Settings.MenuKeybind = "RightShift"
    _active.InterfaceManager = InterfaceManager

    -- Read saved window size
    local savedLayout
    pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function"
            and isfile(_active.layoutFile) then
            local raw = readfile(_active.layoutFile)
            local ok, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and typeof(parsed) == "table" then savedLayout = parsed end
        end
    end)

    local windowSize = UDim2.fromOffset(540, 520)
    if savedLayout then
        local sx, sy = tonumber(savedLayout.sx), tonumber(savedLayout.sy)
        if sx and sy and sx >= 400 and sy >= 300 then
            windowSize = UDim2.fromOffset(math.floor(sx), math.floor(sy))
        end
    end

    -- Fluent.GUI is the window Frame; walk up to find the ScreenGui to toggle.
    local function setGuiVisible(v)
        pcall(function()
            local gui = Fluent and Fluent.GUI
            if typeof(gui) ~= "Instance" then return end
            local node = gui
            for _ = 1, 12 do
                if node:IsA("ScreenGui") then node.Enabled = v; return end
                if not node.Parent or node.Parent == game then break end
                node = node.Parent
            end
            -- Fallback: toggle the frame itself
            gui.Enabled = v
        end)
    end
    setGuiVisible(false)

    local ifacePre = InterfaceManager.Settings
    local function pickTheme(name)
        if typeof(name) == "string" and table.find(Fluent.Themes, name) then return name end
        return "Deep Shadow"
    end

    local Window = Fluent:CreateWindow({
        Title       = "Bloodlines",
        SubTitle    = "by Mya",
        TabWidth    = 150,
        Size        = windowSize,
        Acrylic     = false,
        Theme       = pickTheme(ifacePre.Theme),
        MinimizeKey = Enum.KeyCode.RightShift,
    })
    _active.Window = Window

    task.defer(function()
        pcall(function() Fluent:SetTheme(pickTheme(ifacePre.Theme)) end)
        pcall(function() Fluent:ToggleTransparency(ifacePre.Transparency ~= false) end)
        pcall(function()
            local gui = Fluent.GUI
            if typeof(gui) ~= "Instance" then return end
            local frame
            pcall(function() frame = Window.Holder end)
            if not (frame and typeof(frame) == "Instance" and frame:IsA("Frame")) then
                frame = gui:FindFirstChildOfClass("Frame")
            end
            if frame and typeof(frame) == "Instance" then
                _active.windowFrame = frame
                if savedLayout and savedLayout.px and savedLayout.py then
                    local vp = workspace.CurrentCamera.ViewportSize
                    local px = math.clamp(math.floor(savedLayout.px), 0, math.max(0, vp.X - 200))
                    local py = math.clamp(math.floor(savedLayout.py), 0, math.max(0, vp.Y - 100))
                    frame.Position = UDim2.fromOffset(px, py)
                end
            end
        end)
        setGuiVisible(true)
    end)

    -- ── Tabs ──────────────────────────────────────────────────────────────────

    local VisualsTab  = Window:AddTab({ Title = "Visuals",  Icon = "solar/eye-bold"               })
    local MovementTab  = Window:AddTab({ Title = "Movement",  Icon = "solar/wind-bold"               })
    local PlayerTab    = Window:AddTab({ Title = "Player",    Icon = "solar/user-bold"               })
    local TeleportTab  = Window:AddTab({ Title = "Teleport",  Icon = "solar/map-point-bold"          })
    local MiscTab      = Window:AddTab({ Title = "Misc",      Icon = "solar/widget-5-bold"           })
    local ConfigTab    = Window:AddTab({ Title = "Config",    Icon = "solar/diskette-bold"           })
    local SettingsTab  = Window:AddTab({ Title = "Settings",  Icon = "solar/settings-bold"          })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Player ESP
    -- ════════════════════════════════════════════════════════════════════════

    local playerSec = VisualsTab:AddSection("Player ESP")

    playerSec:AddToggle("PlayerESPEnabled", {
        Title    = "Enable",
        Icon     = "solar/user-bold",
        Default  = false,
        Callback = function(v) playerEsp.enabled = v end,
    })

    playerSec:AddColorpicker("PlayerESPColor", {
        Title    = "Color",
        Default  = Color3.fromRGB(255, 255, 255),
        Callback = function(v) playerEsp.color = v end,
    })

    playerSec:AddToggle("PlayerESPName", {
        Title    = "Name",
        Default  = true,
        Callback = function(v) playerEsp.name = v end,
    })

    playerSec:AddToggle("PlayerESPDistance", {
        Title    = "Distance",
        Default  = true,
        Callback = function(v) playerEsp.distance = v end,
    })

    playerSec:AddToggle("PlayerESPHealth", {
        Title    = "Health Bar",
        Default  = false,
        Callback = function(v) playerEsp.health = v end,
    })

    playerSec:AddSlider("PlayerESPMaxDist", {
        Title    = "Max Distance",
        Default  = 1000,
        Min      = 100,
        Max      = 3000,
        Rounding = 0,
        Callback = function(v) playerEsp.maxDist = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: NPC ESP (dialog / friendly NPCs)
    -- ════════════════════════════════════════════════════════════════════════

    local npcSec = VisualsTab:AddSection("NPC ESP")

    npcSec:AddToggle("NPCESPEnabled", {
        Title    = "Enable",
        Icon     = "solar/user-speak-bold",
        Default  = false,
        Callback = function(v) npcEsp.enabled = v end,
    })

    npcSec:AddColorpicker("NPCESPColor", {
        Title    = "Color",
        Default  = Color3.fromRGB(100, 200, 255),
        Callback = function(v) npcEsp.color = v end,
    })

    npcSec:AddSlider("NPCESPMaxDist", {
        Title    = "Max Distance",
        Default  = 500,
        Min      = 50,
        Max      = 5000,
        Rounding = 0,
        Callback = function(v) npcEsp.maxDist = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Mob ESP (combat enemies)
    -- ════════════════════════════════════════════════════════════════════════

    local mobSec = VisualsTab:AddSection("Mob ESP")

    mobSec:AddToggle("MobESPEnabled", {
        Title    = "Enable",
        Icon     = "solar/danger-bold",
        Default  = false,
        Callback = function(v) mobEsp.enabled = v end,
    })

    mobSec:AddColorpicker("MobESPColor", {
        Title    = "Color",
        Default  = Color3.fromRGB(255, 80, 80),
        Callback = function(v) mobEsp.color = v end,
    })

    mobSec:AddToggle("MobESPHealth", {
        Title    = "Health Bar",
        Default  = false,
        Callback = function(v) mobEsp.health = v end,
    })

    mobSec:AddSlider("MobESPMaxDist", {
        Title    = "Max Distance",
        Default  = 500,
        Min      = 50,
        Max      = 5000,
        Rounding = 0,
        Callback = function(v) mobEsp.maxDist = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Environment (Visuals tab)
    -- ════════════════════════════════════════════════════════════════════════

    local envSec = VisualsTab:AddSection("Environment")

    envSec:AddToggle("NoFog", {
        Title    = "Remove Fog",
        Icon     = "solar/cloud-bold",
        Default  = false,
        Callback = function(v) if v then applyNoFog() else restoreFog() end end,
    })

    envSec:AddToggle("NoRain", {
        Title    = "Remove Rain",
        Icon     = "solar/cloud-drizzle-bold",
        Default  = false,
        Callback = function(v) if v then applyNoRain() else restoreRain() end end,
    })

    envSec:AddToggle("FullBright", {
        Title    = "Fullbright",
        Icon     = "solar/sun-bold",
        Default  = false,
        Callback = function(v) if v then applyFullBright() else restoreFullBright() end end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Chakra Sense Alert (Visuals tab)
    -- ════════════════════════════════════════════════════════════════════════

    local csAlertSec = VisualsTab:AddSection("Chakra Sense Alert")

    csAlertSec:AddToggle("CSAlertEnable", {
        Title    = "Show Alert When Sensed",
        Icon     = "solar/eye-bold",
        Default  = false,
        Callback = function(v)
            _csAlertEnabled = v
            if v then
                initCSAlertDrawing()
            else
                if _csAlertDrawing then
                    pcall(function() _csAlertDrawing.Visible = false end)
                end
            end
        end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Fly
    -- ════════════════════════════════════════════════════════════════════════

    local flySec = MovementTab:AddSection("Fly")

    -- Toggle switch (the "button" the user sees) is the primary control.
    -- The keybind syncs its value so both stay in sync.
    local flySwitch = flySec:AddToggle("FlySwitch", {
        Title    = "Fly",
        Icon     = "solar/wind-bold",
        Default  = false,
        Callback = function(v)
            fly.enabled = v
            if v then enableFly() else disableFly() end
        end,
    })
    flySec:AddKeybind("FlyBind", {
        Title    = "Bind",
        Mode     = "Toggle",
        Default  = "",
        Callback = function(v)
            fly.enabled = v
            if v then enableFly() else disableFly() end
            pcall(function() flySwitch:SetValue(v) end)
        end,
    })
    flySec:AddSlider("FlySpeed", {
        Title    = "Speed",
        Default  = 50, Min = 10, Max = 300, Rounding = 0,
        Callback = function(v) fly.speed = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Noclip
    -- ════════════════════════════════════════════════════════════════════════

    local noclipSec = MovementTab:AddSection("Noclip")

    local noclipSwitch = noclipSec:AddToggle("NoclipSwitch", {
        Title    = "Noclip",
        Icon     = "solar/ghost-bold",
        Default  = false,
        Callback = function(v) noclip.enabled = v end,
    })
    noclipSec:AddKeybind("NoclipBind", {
        Title    = "Bind",
        Mode     = "Toggle",
        Default  = "",
        Callback = function(v)
            noclip.enabled = v
            pcall(function() noclipSwitch:SetValue(v) end)
        end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Walk Speed
    -- ════════════════════════════════════════════════════════════════════════

    local wsSec = MovementTab:AddSection("Walk Speed")

    local wsSwitch = wsSec:AddToggle("WalkSpeedSwitch", {
        Title    = "Walk Speed",
        Icon     = "solar/running-bold",
        Default  = false,
        Callback = function(v)
            walkspeed.enabled = v
            if v then applyWalkSpeed() else resetWalkSpeed() end
        end,
    })
    wsSec:AddKeybind("WalkSpeedBind", {
        Title    = "Bind",
        Mode     = "Toggle",
        Default  = "",
        Callback = function(v)
            walkspeed.enabled = v
            if v then applyWalkSpeed() else resetWalkSpeed() end
            pcall(function() wsSwitch:SetValue(v) end)
        end,
    })
    wsSec:AddSlider("WalkSpeedValue", {
        Title    = "Speed",
        Default  = 50, Min = 16, Max = 500, Rounding = 0,
        Callback = function(v)
            walkspeed.speed = v
            if walkspeed.enabled then applyWalkSpeed() end
        end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Jump Power
    -- ════════════════════════════════════════════════════════════════════════

    local jpSec = MovementTab:AddSection("Jump Power")

    local jpSwitch = jpSec:AddToggle("JumpPowerSwitch", {
        Title    = "Jump Power",
        Icon     = "solar/arrow-up-bold",
        Default  = false,
        Callback = function(v)
            jumppower.enabled = v
            if v then applyJumpPower() else resetJumpPower() end
        end,
    })
    jpSec:AddKeybind("JumpPowerBind", {
        Title    = "Bind",
        Mode     = "Toggle",
        Default  = "",
        Callback = function(v)
            jumppower.enabled = v
            if v then applyJumpPower() else resetJumpPower() end
            pcall(function() jpSwitch:SetValue(v) end)
        end,
    })
    jpSec:AddSlider("JumpPowerValue", {
        Title    = "Power",
        Default  = 100, Min = 50, Max = 500, Rounding = 0,
        Callback = function(v)
            jumppower.power = v
            if jumppower.enabled then applyJumpPower() end
        end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- PLAYER TAB
    -- ════════════════════════════════════════════════════════════════════════

    -- ── No Fall Damage ────────────────────────────────────────────────────────
    local fallSec = PlayerTab:AddSection("Fall Damage")
    local fallToggle = fallSec:AddToggle("NoFallDmgToggle", {
        Title    = "No Fall Damage",
        Icon     = "solar/arrow-down-bold",
        Default  = false,
        Callback = function(v)
            noFallDmg.enabled = v
            if v then applyNoFallDmg() else restoreNoFallDmg() end
        end,
    })
    fallSec:AddKeybind("NoFallBind", {
        Title    = "Bind",
        Mode     = "Toggle",
        Default  = "",
        Callback = function(v)
            noFallDmg.enabled = v
            if v then applyNoFallDmg() else restoreNoFallDmg() end
            pcall(function() fallToggle:SetValue(v) end)
        end,
    })

    -- ── M1 Cooldown ───────────────────────────────────────────────────────────
    local m1Sec = PlayerTab:AddSection("M1 Attack")
    m1Sec:AddToggle("NoM1CD", {
        Title    = "Remove M1 Cooldown",
        Icon     = "solar/hand-shake-bold",
        Default  = false,
        Callback = function(v)
            noM1CD.enabled = v
            if v then applyNoM1CD() end
        end,
    })

    -- ── Infinite Stamina ──────────────────────────────────────────────────────
    local staminaSec = PlayerTab:AddSection("Stamina")
    staminaSec:AddToggle("InfStamina", {
        Title    = "Infinite Stamina",
        Icon     = "solar/running-bold",
        Default  = false,
        Callback = function(v) infStamina.enabled = v end,
    })

    -- ── Infinite Chakra ───────────────────────────────────────────────────────
    local chakraSec = PlayerTab:AddSection("Chakra")
    chakraSec:AddToggle("InfChakra", {
        Title    = "Infinite Chakra",
        Icon     = "solar/bolt-circle-bold",
        Default  = false,
        Callback = function(v) infChakra.enabled = v end,
    })

    -- ── No Stun ───────────────────────────────────────────────────────────────
    local stunSec = PlayerTab:AddSection("Stun")
    stunSec:AddToggle("NoStun", {
        Title    = "No Stun",
        Icon     = "solar/danger-bold",
        Default  = false,
        Callback = function(v)
            noStun.enabled = v
            if v then setupNoStun(LocalPlayer.Character) end
        end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- WIDGETS (load lib/widgets.luau, build themeSync + watermark + keybindDisplay)
    -- ════════════════════════════════════════════════════════════════════════

    -- Load the shared widget lib from the hosted URL
    local widgets
    do
        local src
        local ok, s = pcall(game.HttpGet, game, ctx.baseUrl .. "New_Mya/lib/widgets.luau", true)
        if ok and typeof(s) == "string" and #s > 200 then src = s end
        if src then
            local fn, err = loadstring(src, "@widgets")
            if fn then
                local ok2, w = pcall(fn)
                if ok2 then widgets = w end
            end
        end
    end

    -- updateUsersWidget is defined here so the RenderStepped below always has it in scope.
    -- It stays a no-op until the users overlay is fully set up inside the widgets block.
    local updateUsersWidget = function() end

    if widgets then
        pcall(function() _active.themeSync = widgets.newThemeSync(Fluent) end)

        -- Watermark
        pcall(function()
            _active.watermark = widgets.newWatermark({
                Fluent     = Fluent,
                UIS        = UserInputService,
                themeSync  = _active.themeSync,
                tab        = MiscTab,
                folder     = "Mya/Bloodlines",
            })
        end)

        -- bindRegistry: read current key from Fluent.Options at call time.
        -- Fluent Modded stores the bound key as opt.Value (a string like "F", "RightShift").
        -- opt.Toggled holds the boolean toggle state; opt.Value holds the key string.
        local function readKey(id)
            if not (Fluent and Fluent.Options) then return nil end
            local opt = Fluent.Options[id]
            if not opt then return nil end
            local val = opt.Value
            if typeof(val) == "string" and val ~= "" and val ~= "None" then
                return val
            end
            return nil
        end

        local bindRegistry = {
            { displayName = "Fly",        getKey = function() return readKey("FlyBind")       end, getMode = function() return "Toggle" end, isActive = function() return fly.enabled       end },
            { displayName = "Noclip",     getKey = function() return readKey("NoclipBind")    end, getMode = function() return "Toggle" end, isActive = function() return noclip.enabled    end },
            { displayName = "Walk Speed", getKey = function() return readKey("WalkSpeedBind") end, getMode = function() return "Toggle" end, isActive = function() return walkspeed.enabled end },
            { displayName = "Jump Power", getKey = function() return readKey("JumpPowerBind") end, getMode = function() return "Toggle" end, isActive = function() return jumppower.enabled end },
        }

        -- Keybind Display
        pcall(function()
            _active.keybindDisplay = widgets.newKeybindDisplay({
                Fluent       = Fluent,
                UIS          = UserInputService,
                themeSync    = _active.themeSync,
                tab          = MiscTab,
                folder       = "Mya/Bloodlines",
                bindRegistry = bindRegistry,
            })
        end)

        -- Users overlay
        local usersEnabled    = false
        local usersLastUpdate = 0
        local usersOv         = nil

        pcall(function()
            usersOv = widgets.newOverlayFrame({
                name         = "MyaUsersOverlay",
                displayOrder = 198,
                defaultX     = 14,
                defaultY     = 150,
                posFile      = "Mya/Bloodlines/users_pos.json",
                Fluent       = Fluent,
                UIS          = UserInputService,
                textSize     = 13,
                minWidth     = 160,
                padL = 14, padR = 14, padT = 8, padB = 8,
                accentColor  = Color3.fromRGB(245, 92, 177),
                textAlign    = Enum.TextXAlignment.Center,
            })
            -- Centre the text
            if usersOv and usersOv.label then
                usersOv.label.TextXAlignment = Enum.TextXAlignment.Center
            end
            _active.usersOverlay = usersOv
        end)

        -- ════════════════════════════════════════════════════════════════════
        -- SECTION: Users (Misc tab)
        -- ════════════════════════════════════════════════════════════════════

        local usersSec = MiscTab:AddSection("Users")
        usersSec:AddToggle("UsersOverlayEn", {
            Title    = "Show Users Widget",
            Icon     = "solar/users-group-rounded-bold",
            Default  = false,
            Callback = function(v)
                usersEnabled = v
                pcall(function() if usersOv and usersOv.gui then usersOv.gui.Enabled = v end end)
            end,
        })

        local ts = _active.themeSync
        local function h(c) return string.format("#%02x%02x%02x",
            math.clamp(math.floor(c.R*255),0,255),
            math.clamp(math.floor(c.G*255),0,255),
            math.clamp(math.floor(c.B*255),0,255))
        end

        -- Redefine the outer no-op now that we have usersOv in scope
        updateUsersWidget = function()
            if not usersEnabled or not (usersOv and usersOv.label) then return end
            local now = tick()
            if now - usersLastUpdate < 0.3 then return end
            usersLastUpdate = now
            pcall(function()
                local ha = ts and h(ts.getAccent()) or "#f55cb1"
                local ht = ts and h(ts.getText())   or "#f5f5fa"
                local hm = ts and h(ts.getMuted())  or "#c8aad4"

                local nearP, nearDist = getNearestPlayer()
                local csTotal, csActive = getCSCounts()

                local lines = { string.format('<font color="%s"><b>Users</b></font>', ha) }
                if nearP then
                    lines[#lines+1] = string.format(
                        '<font color="%s">Nearest  </font><font color="%s">%s</font><font color="%s"> %.0fm</font>',
                        hm, ht, nearP.Name, hm, nearDist)
                else
                    lines[#lines+1] = string.format('<font color="%s">Nearest  —</font>', hm)
                end
                lines[#lines+1] = string.format('<font color="%s">CS Users  </font><font color="%s">%d</font>', hm, ht, csTotal)
                lines[#lines+1] = string.format('<font color="%s">Sensing   </font><font color="%s">%d</font>', hm, ht, csActive)

                usersOv.label.Text = table.concat(lines, "\n")
                usersOv.setAccent(ts and ts.getAccent() or Color3.fromRGB(245, 92, 177))
            end)
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- STREAMER MODE (Misc tab)
    -- ════════════════════════════════════════════════════════════════════════

    local streamerSec = MiscTab:AddSection("Streamer Mode")
    streamerSec:AddToggle("StreamerMode", {
        Title    = "Streamer Mode",
        Icon     = "solar/camera-bold",
        Default  = false,
        Callback = function(v)
            streamer.enabled = v
            if v then applyStreamer() else restoreStreamer() end
        end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- PLAYER TELEPORT (Teleport tab)
    -- ════════════════════════════════════════════════════════════════════════

    do
        local playerTpSec = TeleportTab:AddSection("Players")
        local selPlayerTP = nil

        -- Build initial list
        local function getPlayerNames()
            local names = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(names, p.Name) end
            end
            return names
        end

        local initPNames = getPlayerNames()
        local playerTPDD = nil

        if #initPNames > 0 then
            playerTPDD = playerTpSec:AddDropdown("PlayerTPDD", {
                Title    = "Select Player",
                Values   = initPNames,
                Default  = initPNames[1],
                Callback = function(v) selPlayerTP = v end,
            })
            selPlayerTP = initPNames[1]
        else
            playerTPDD = playerTpSec:AddDropdown("PlayerTPDD", {
                Title   = "Select Player",
                Values  = { "No players" },
                Default = "No players",
                Callback = function(v) selPlayerTP = v ~= "No players" and v or nil end,
            })
        end

        playerTpSec:AddButton({
            Title    = "Refresh List",
            Icon     = "solar/refresh-bold",
            Callback = function()
                local names = getPlayerNames()
                if #names == 0 then names = { "No players" } end
                pcall(function() playerTPDD:SetValues(names); playerTPDD:SetValue(names[1]) end)
            end,
        })

        playerTpSec:AddButton({
            Title    = "Teleport to Player",
            Icon     = "solar/map-point-bold",
            Callback = function()
                if not selPlayerTP or selPlayerTP == "No players" then return end
                local tp = Players:FindFirstChild(selPlayerTP)
                if not tp then return end
                local c = tp.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then tpTo(r.Position) end
            end,
        })
    end

    -- ── Widget render loop — always runs regardless of widget load success ────────
    _active.widgetConn = RunService.RenderStepped:Connect(function()
        if _active.watermark      then pcall(_active.watermark.update)      end
        if _active.keybindDisplay then pcall(_active.keybindDisplay.update) end
        pcall(updateUsersWidget)
    end)

    -- ════════════════════════════════════════════════════════════════════════
    -- CHAKRA SENSE NOTIFICATION
    -- ════════════════════════════════════════════════════════════════════════

    do
        local lastNotify    = 0
        local DEBOUNCE_SECS = 3

        local function fireNotify(Fl)
            local now = tick()
            if now - lastNotify < DEBOUNCE_SECS then return end
            lastNotify = now
            -- Fluent notification
            pcall(function()
                Fl:Notify({
                    Title    = "Chakra Sense",
                    Content  = "A player is sensing your chakra!",
                    Duration = 4,
                })
            end)
        end

        -- 1. Watch DataEvent for server-sent sense notifications
        local rsEvents  = ReplicatedStorage:FindFirstChild("Events")
        local dataEvent = rsEvents and rsEvents:FindFirstChild("DataEvent")
        if dataEvent then
            table.insert(_active.connections, dataEvent.OnClientEvent:Connect(function(action, ...)
                if type(action) ~= "string" then return end
                local al = action:lower()
                if al:find("sense") or al:find("chakra") or al:find("detect") then
                    fireNotify(Fluent)
                end
            end))
        end

        -- 2. Watch LocalPlayer character Settings for sensing BoolValues
        local function watchSettingsSense(settings)
            if not settings then return end
            local function checkVal(v)
                local n = v.Name:lower()
                if (n:find("sens") or n:find("detect")) and v:IsA("BoolValue") then
                    table.insert(_active.connections, v.Changed:Connect(function(val)
                        if val then fireNotify(Fluent) end
                    end))
                    if v.Value then fireNotify(Fluent) end
                end
            end
            for _, v in ipairs(settings:GetChildren()) do checkVal(v) end
            table.insert(_active.connections, settings.ChildAdded:Connect(function(v)
                task.defer(function() if v and v.Parent then checkVal(v) end end)
            end))
        end

        local function onCharForSense(char)
            task.wait(0.5)
            watchSettingsSense(char:FindFirstChild("Settings"))
            local rsS = ReplicatedStorage:FindFirstChild("Settings")
            if rsS then watchSettingsSense(rsS:FindFirstChild(LocalPlayer.Name)) end
        end

        if LocalPlayer.Character then task.spawn(onCharForSense, LocalPlayer.Character) end
        table.insert(_active.connections, LocalPlayer.CharacterAdded:Connect(function(char)
            task.spawn(onCharForSense, char)
        end))

        -- 3. Watch the game's own "Active Chakra Sense Players" counter.
        -- Fires a notification when it goes from 0 → any positive value.
        local lastActiveCS = 0
        local senseCheckClock = 0
        table.insert(_active.connections, RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - senseCheckClock < 2 then return end
            senseCheckClock = now
            local _, active = getCSCounts()
            if active > 0 and lastActiveCS == 0 then
                fireNotify(Fluent)
            end
            lastActiveCS = active
        end))
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- TELEPORTATION TAB
    -- ════════════════════════════════════════════════════════════════════════

    do
        -- ── Helpers ──────────────────────────────────────────────────────────

        local function getObjPos(obj)
            if obj:IsA("Model") then
                if obj.PrimaryPart then return obj.PrimaryPart.Position end
                local p = obj:FindFirstChildWhichIsA("BasePart", true)
                if p then return p.Position end
                local ok, pv = pcall(function() return obj:GetPivot().Position end)
                if ok then return pv end
            elseif obj:IsA("BasePart") then
                return obj.Position
            end
            return nil
        end

        local function tpTo(pos)
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        end

        -- ── Scan workspace ───────────────────────────────────────────────────

        local tpChakra    = {}
        local tpNPCs      = {}
        local tpMerchants = {}
        local tpWeapons   = {}   -- weapon stands / item displays (not NPCs)
        local tpArmor     = {}   -- armor stands / item displays (not NPCs)

        -- Deduplicate by name (NPCs) or by position (world objects)
        local function dedupPos(list, pos, prox)
            for _, e in ipairs(list) do
                if (e.pos - pos).Magnitude < (prox or 8) then return false end
            end
            return true
        end
        local npcNameSet = {}   -- dedup NPCs by name

        -- Returns the first ancestor folder name that matches a village
        local VILLAGES = { "sorythia", "durana", "rain", "snow", "rogue", "akatsuki",
                           "winter", "leaf", "sand", "mist", "stone", "cloud" }
        local function getVillageAncestor(obj)
            local node = obj.Parent
            for _ = 1, 6 do
                if not node or node == workspace or node == game then break end
                local nl = node.Name:lower()
                for _, v in ipairs(VILLAGES) do
                    if nl:find(v) then return node.Name end
                end
                node = node.Parent
            end
            return nil
        end

        -- ── 1. Chakra points: ONLY scan workspace.ChakraPoints folder ─────────
        pcall(function()
            local cpFolder = workspace:FindFirstChild("ChakraPoints")
            if cpFolder then
                for _, obj in ipairs(cpFolder:GetChildren()) do
                    local pos = getObjPos(obj)
                    if not pos then continue end
                    -- Each chakra point model has a PointName StringValue
                    local nameVal = obj:FindFirstChild("PointName")
                    local nm = (nameVal and typeof(nameVal.Value) == "string"
                        and nameVal.Value ~= "") and nameVal.Value or obj.Name
                    if nm ~= "" and dedupPos(tpChakra, pos, 20) then
                        table.insert(tpChakra, { name = nm, pos = pos })
                    end
                end
            end
            -- Fallback if folder not found: look for a Part/Model literally named ChakraPoint
            if #tpChakra == 0 then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end
                    if obj.Name:lower() ~= "chakrapoint" then continue end
                    local pos = getObjPos(obj)
                    if pos and dedupPos(tpChakra, pos, 20) then
                        local village = getVillageAncestor(obj)
                        local nm = village and (village .. " Chakra Point") or obj.Name
                        table.insert(tpChakra, { name = nm, pos = pos })
                    end
                end
            end
        end)

        -- ── 2. NPCs: dedup by name, label with village context ────────────────
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if not obj:IsA("Model") then continue end
                if not obj:FindFirstChild("NPC") then continue end
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                local settings = obj:FindFirstChild("Settings")
                local nv = settings and settings:FindFirstChild("NPCName")
                local baseName = (nv and nv.Value ~= "") and nv.Value or obj.Name
                if baseName == "" then continue end
                -- Add village prefix for generic names to disambiguate
                local village = getVillageAncestor(obj)
                local dname = (village and baseName:lower():find("^(merchant|food|inn)")
                    and baseName ~= "Merchant")
                    and (village .. " " .. baseName)
                    or baseName
                if not npcNameSet[dname] then
                    npcNameSet[dname] = true
                    table.insert(tpNPCs, { name = dname, pos = hrp.Position })
                end
            end
        end)

        -- ── 3. Merchants: "Merchant" NPCs with village context ────────────────
        -- The game uses generic "Merchant" names; parent folder gives the village.
        -- Food merchants, Rogue variants, Chefs, InnKeepers all included.
        local merchantNameSet = {}
        pcall(function()
            local MERCHANT_NAMES = {
                "merchant", "food merchant", "rogue merchant", "rogue food merchant",
                "chef", "rogue chef", "lady chef", "innkeeper", "rogue innkeeper",
                "outkeeper",
            }
            for _, obj in ipairs(workspace:GetDescendants()) do
                if not obj:IsA("Model") then continue end
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                local settings = obj:FindFirstChild("Settings")
                local nv = settings and settings:FindFirstChild("NPCName")
                local base = (nv and nv.Value ~= "") and nv.Value:lower() or obj.Name:lower()
                local isMerchant = false
                for _, mn in ipairs(MERCHANT_NAMES) do
                    if base == mn then isMerchant = true; break end
                end
                if not isMerchant then continue end
                local village = getVillageAncestor(obj)
                local displayName = village
                    and (village .. " " .. ((nv and nv.Value ~= "") and nv.Value or obj.Name))
                    or  ((nv and nv.Value ~= "") and nv.Value or obj.Name)
                if not merchantNameSet[displayName] then
                    merchantNameSet[displayName] = true
                    table.insert(tpMerchants, { name = displayName, pos = hrp.Position })
                end
            end
        end)

        -- ── 4. Weapon / armor STANDS — static world objects, not NPCs ────────────
        -- These are Models/Parts on display stands (no NPC/Humanoid child).
        local WEAPON_KW = { "katana","sword","blade","dagger","kunai","shuriken",
                             "weapon","staff","spear","bow","axe","hammer" }
        local ARMOR_KW  = { "armor","armour","vest","helmet","chestplate",
                             "shield","robe","cloak","cape","gear","boots","gauntlet" }
        local weaponNameSet = {}
        local armorNameSet  = {}
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if not obj:IsA("Model") then continue end
                if obj:FindFirstChild("NPC") then continue end
                if obj:FindFirstChildWhichIsA("Humanoid") then continue end
                local pos = getObjPos(obj)
                if not pos then continue end
                local nl = obj.Name:lower()
                local village = getVillageAncestor(obj)
                local function displayName()
                    return village and (village .. " " .. obj.Name) or obj.Name
                end
                -- Weapon stands
                for _, kw in ipairs(WEAPON_KW) do
                    if nl:find(kw, 1, true) and not weaponNameSet[displayName()] then
                        weaponNameSet[displayName()] = true
                        table.insert(tpWeapons, { name = displayName(), pos = pos })
                        break
                    end
                end
                -- Armor stands
                for _, kw in ipairs(ARMOR_KW) do
                    if nl:find(kw, 1, true) and not armorNameSet[displayName()] then
                        armorNameSet[displayName()] = true
                        table.insert(tpArmor, { name = displayName(), pos = pos })
                        break
                    end
                end
            end
        end)

        table.sort(tpChakra,    function(a, b) return a.name < b.name end)
        table.sort(tpNPCs,      function(a, b) return a.name < b.name end)
        table.sort(tpMerchants, function(a, b) return a.name < b.name end)
        table.sort(tpWeapons,   function(a, b) return a.name < b.name end)
        table.sort(tpArmor,     function(a, b) return a.name < b.name end)

        -- ── Helpers to build name list ───────────────────────────────────────

        local function names(t)
            local r = {}
            for _, e in ipairs(t) do table.insert(r, e.name) end
            return r
        end

        local function posForName(t, v)
            for _, e in ipairs(t) do if e.name == v then return e.pos end end
            return nil
        end

        -- ── SECTION: Chakra Points ───────────────────────────────────────────

        local cpSec = TeleportTab:AddSection("Chakra Points")
        local selCP = #tpChakra > 0 and tpChakra[1].pos or nil

        if #tpChakra > 0 then
            local cpNames = names(tpChakra)
            cpSec:AddDropdown("CPDropdown", {
                Title    = "Select Chakra Point",
                Values   = cpNames,
                Default  = cpNames[1],
                Callback = function(v) selCP = posForName(tpChakra, v) end,
            })
            cpSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold",
                Callback = function() if selCP then tpTo(selCP) end end })
        else
            cpSec:AddParagraph({ Title = "None found",
                Content = "No chakra / training points detected in workspace." })
        end

        -- ── SECTION: Merchants ───────────────────────────────────────────────
        -- The game uses generic NPC types (Merchant, Food Merchant, Chef, InnKeeper)
        -- prefixed with the village name for disambiguation.

        local merchantSec = TeleportTab:AddSection("Merchants")
        local selMerchant = #tpMerchants > 0 and tpMerchants[1].pos or nil

        if #tpMerchants > 0 then
            local mNames = names(tpMerchants)
            merchantSec:AddDropdown("MerchantDropdown", {
                Title    = "Select Merchant",
                Values   = mNames,
                Default  = mNames[1],
                Callback = function(v) selMerchant = posForName(tpMerchants, v) end,
            })
            merchantSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold",
                Callback = function() if selMerchant then tpTo(selMerchant) end end })
        else
            merchantSec:AddParagraph({ Title = "None found", Content = "No merchants detected." })
        end

        -- ── SECTION: Weapon Stands ───────────────────────────────────────────────

        local wStandSec = TeleportTab:AddSection("Weapon Stands")
        local selWStand = #tpWeapons > 0 and tpWeapons[1].pos or nil

        if #tpWeapons > 0 then
            local wNames = names(tpWeapons)
            wStandSec:AddDropdown("WStandDropdown", {
                Title    = "Select Weapon",
                Values   = wNames,
                Default  = wNames[1],
                Callback = function(v) selWStand = posForName(tpWeapons, v) end,
            })
            wStandSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold",
                Callback = function() if selWStand then tpTo(selWStand) end end })
        else
            wStandSec:AddParagraph({ Title = "None found", Content = "No weapon stands detected in workspace." })
        end

        -- ── SECTION: Armor Stands ────────────────────────────────────────────────

        local aStandSec = TeleportTab:AddSection("Armor Stands")
        local selAStand = #tpArmor > 0 and tpArmor[1].pos or nil

        if #tpArmor > 0 then
            local aNames = names(tpArmor)
            aStandSec:AddDropdown("AStandDropdown", {
                Title    = "Select Armor",
                Values   = aNames,
                Default  = aNames[1],
                Callback = function(v) selAStand = posForName(tpArmor, v) end,
            })
            aStandSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold",
                Callback = function() if selAStand then tpTo(selAStand) end end })
        else
            aStandSec:AddParagraph({ Title = "None found", Content = "No armor stands detected in workspace." })
        end

        -- ── SECTION: NPCs ────────────────────────────────────────────────────

        local npcTpSec = TeleportTab:AddSection("NPCs")
        local selNPC = #tpNPCs > 0 and tpNPCs[1].pos or nil

        if #tpNPCs > 0 then
            local npcNames = names(tpNPCs)
            npcTpSec:AddDropdown("NPCTpDropdown", {
                Title    = "Select NPC",
                Values   = npcNames,
                Default  = npcNames[1],
                Callback = function(v) selNPC = posForName(tpNPCs, v) end,
            })
            npcTpSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold",
                Callback = function() if selNPC then tpTo(selNPC) end end })
        else
            npcTpSec:AddParagraph({ Title = "None found", Content = "No NPCs detected." })
        end

        -- Expose tpTo so CharacterAdded can use it for auto-TP
        _autoTPFn = tpTo

        -- ── SECTION: Safe Point ──────────────────────────────────────────────────

        local safeSec = TeleportTab:AddSection("Safe Point")

        safeSec:AddButton({ Title = "Save Current Position", Icon = "solar/map-point-wave-bold",
            Callback = function()
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    _safePoint = hrp.Position
                    pcall(function()
                        Fluent:Notify({
                            Title    = "Safe Point Saved",
                            Content  = string.format("(%.0f, %.0f, %.0f)",
                                           _safePoint.X, _safePoint.Y, _safePoint.Z),
                            Duration = 3,
                        })
                    end)
                end
            end,
        })

        safeSec:AddButton({ Title = "Teleport to Safe Point", Icon = "solar/map-point-bold",
            Callback = function() if _safePoint then tpTo(_safePoint) end end,
        })

        -- ── SECTION: Auto-Teleport on Low Health ─────────────────────────────────

        local autoTPSec = TeleportTab:AddSection("Auto Teleport")

        autoTPSec:AddToggle("AutoTPEnable", {
            Title    = "Teleport on Low Health",
            Icon     = "solar/heart-pulse-bold",
            Default  = false,
            Callback = function(v) _autoTP.enabled = v end,
        })

        autoTPSec:AddSlider("AutoTPThreshold", {
            Title    = "HP Threshold (%)",
            Default  = 30,
            Min      = 1,
            Max      = 100,
            Rounding = 0,
            Callback = function(v) _autoTP.threshold = v end,
        })

        -- Set up health watcher for auto-TP (also called from CharacterAdded)
        local function setupAutoTPWatcher(char)
            if not char then return end
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if not hum then return end
            local triggered = false
            local c = hum.HealthChanged:Connect(function(hp)
                if not _autoTP.enabled or not _safePoint then triggered = false; return end
                local pct = (hp / math.max(hum.MaxHealth, 1)) * 100
                if pct <= _autoTP.threshold and not triggered then
                    triggered = true
                    tpTo(_safePoint)
                    task.delay(4, function() triggered = false end)
                end
            end)
            table.insert(_active.connections, c)
        end

        setupAutoTPWatcher(LocalPlayer.Character)
        -- Future spawns handled in CharacterAdded via _autoTPFn flag
        table.insert(_active.connections, LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            setupAutoTPWatcher(char)
        end))
    end

    -- ── Config tab ────────────────────────────────────────────────────────────

    local cfgInfoSec = ConfigTab:AddSection("Configs")
    cfgInfoSec:AddParagraph({
        Title   = "How to use",
        Content = "Type a name → Create config.\nSelect → Load config.\nSet as autoload for auto-apply.",
    })

    -- Read the saved autoload name and show it in the Config tab
    local autoloadDisplay = cfgInfoSec:AddParagraph({
        Title   = "Active Autoload",
        Content = "None",
    })
    task.defer(function()
        pcall(function()
            local autoFile = "Mya/Bloodlines/Config/autoload.cfg"
            if typeof(isfile) == "function" and isfile(autoFile) then
                local saved = readfile(autoFile)
                if saved and #saved > 0 then
                    pcall(function() autoloadDisplay:SetContent(saved) end)
                end
            end
        end)
        -- Also update when autoload is changed via the UI
        local origAL = SaveManager.SetAutoloadConfig
        if origAL then
            local prevWrap = SaveManager.SetAutoloadConfig
            SaveManager.SetAutoloadConfig = function(self, name)
                local ok, err = prevWrap(self, name)
                pcall(function()
                    autoloadDisplay:SetContent(name and name ~= "" and name or "None")
                end)
                return ok, err
            end
        end
    end)

    SaveManager:BuildConfigSection(ConfigTab)

    -- ── Settings tab ──────────────────────────────────────────────────────────

    -- Suppress the "Press RightShift to toggle the interface" notification
    -- that Fluent fires from both BuildInterfaceSection and SetValue.
    pcall(function()
        local orig = Fluent.Notify
        Fluent.Notify = function() end
        InterfaceManager:BuildInterfaceSection(SettingsTab)
        Fluent.MinimizeKeybind:SetValue("RightShift")
        InterfaceManager:SaveSettings()
        Fluent.Notify = orig
    end)

    -- ── Player tracking ───────────────────────────────────────────────────────

    -- Initialize CS alert drawing
    initCSAlertDrawing()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            addPlayerESP(p)
            task.spawn(detectModAndNotify, p, Fluent)
        end
    end

    table.insert(_active.connections, Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            addPlayerESP(p)
            -- Small delay so the player's character/GUI has time to load
            task.delay(2, detectModAndNotify, p, Fluent)
        end
    end))
    table.insert(_active.connections, Players.PlayerRemoving:Connect(removePlayerESP))

    -- Re-apply all character features after respawn and rebuild caches
    table.insert(_active.connections, LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        -- Rebuild part/stat caches first (no cost at call site later)
        refreshNoclipParts(char)
        buildStatCache(char, { "stamina" }, _staminaCache)
        buildStatCache(char, { "chakra", "energy", "ki", "mana" }, _chakraCache)
        -- Re-apply features
        if fly.enabled        then enableFly()          end
        if walkspeed.enabled  then applyWalkSpeed()     end
        if jumppower.enabled  then applyJumpPower()     end
        if noFallDmg.enabled  then applyNoFallDmg(char) end
        if noStun.enabled     then setupNoStun(char)    end
        if streamer.enabled   then applyStreamer(char)  end
    end))

    -- Scan and patch "ilovehewho" watermark text now and on new GUI elements
    do
        for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do patchWatermarkLabel(v) end
        table.insert(_active.connections, LocalPlayer.PlayerGui.DescendantAdded:Connect(function(v)
            task.defer(function() patchWatermarkLabel(v) end)
        end))
    end

    -- Noclip loop: continuously clear CanCollide on character parts
    table.insert(_active.connections, RunService.Stepped:Connect(function()
        if not noclip.enabled then return end
        applyNoclip()
    end))

    -- Build initial stat caches for the current character (if already loaded)
    do
        local char = LocalPlayer.Character
        if char then
            refreshNoclipParts(char)
            buildStatCache(char, { "stamina" }, _staminaCache)
            buildStatCache(char, { "chakra", "energy", "ki", "mana" }, _chakraCache)
        end
    end

    -- Infinite Stamina loop — sets cached NumberValues to max each frame
    table.insert(_active.connections, RunService.Heartbeat:Connect(function()
        if infStamina.enabled then applyStatCache(_staminaCache) end
    end))

    -- Infinite Chakra — simulates holding C to charge via VirtualInputManager.
    -- Bloodlines charges chakra while C is held; firing the key event every frame
    -- keeps the charge going indefinitely.
    local _vim; pcall(function() _vim = game:GetService("VirtualInputManager") end)
    table.insert(_active.connections, RunService.Heartbeat:Connect(function()
        if not infChakra.enabled then return end
        if _vim then
            pcall(function() _vim:SendKeyEvent(true, Enum.KeyCode.C, false, game) end)
        else
            -- Fallback: try to max chakra via cached values
            applyStatCache(_chakraCache)
        end
    end))

    -- ── World entity tracking (NPCs + Mobs) ───────────────────────────────────

    -- Initial scan
    for _, obj in ipairs(workspace:GetChildren()) do
        pcall(tryRegisterWorkspaceEntity, obj)
    end

    table.insert(_active.connections, workspace.ChildAdded:Connect(function(obj)
        tryRegisterWorkspaceEntity(obj)
    end))

    table.insert(_active.connections, workspace.ChildRemoved:Connect(function(obj)
        if _active.worldESPs[obj] then removeWorldESP(obj) end
    end))

    -- ── Layout save heartbeat ─────────────────────────────────────────────────

    local lastSave = 0
    _active.layoutConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastSave < 10 then return end
        lastSave = now
        pcall(function()
            if typeof(writefile) ~= "function" then return end
            local gui = Fluent and Fluent.GUI
            if typeof(gui) ~= "Instance" then return end
            local sz = gui.AbsoluteSize
            if sz.X < 100 or sz.Y < 100 then return end
            local data = { sx = sz.X, sy = sz.Y }
            local frame = _active.windowFrame
            if frame and typeof(frame) == "Instance" then
                local ap = frame.AbsolutePosition
                data.px = math.floor(ap.X)
                data.py = math.floor(ap.Y)
            end
            writefile(_active.layoutFile, HttpService:JSONEncode(data))
        end)
        pcall(function() InterfaceManager:SaveSettings() end)
    end)

    -- ── Autoload ──────────────────────────────────────────────────────────────

    task.defer(function() pcall(function() SaveManager:LoadAutoloadConfig() end) end)

    if ctx and typeof(ctx.notify) == "function" then
        ctx.notify("Bloodlines loaded")
    end
end

-- ─── unmount ──────────────────────────────────────────────────────────────────

function module.unmount()
    -- Disable and reset all features
    fly.enabled       = false
    noclip.enabled    = false
    walkspeed.enabled = false
    jumppower.enabled = false
    disableFly()
    resetWalkSpeed()
    resetJumpPower()
    -- Restore lighting
    restoreFog(); restoreRain(); restoreFullBright()
    -- Restore character features
    restoreNoFallDmg(); restoreStreamer()
    for _, c in ipairs(_stunConns)   do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
    _stunConns = {}; _noFallConns = {}

    if _active.widgetConn then
        _active.widgetConn:Disconnect()
        _active.widgetConn = nil
    end
    if _active.watermark      then pcall(function() _active.watermark.unmount()      end) end
    if _active.keybindDisplay then pcall(function() _active.keybindDisplay.unmount() end) end
    if _active.usersOverlay   then pcall(function() _active.usersOverlay.destroy()   end) end
    _active.watermark      = nil
    _active.keybindDisplay = nil
    _active.usersOverlay   = nil
    _active.themeSync      = nil

    if _active.layoutConn then
        _active.layoutConn:Disconnect()
        _active.layoutConn = nil
    end

    pcall(function()
        if _active.InterfaceManager then
            _active.InterfaceManager:SaveSettings()
        end
    end)

    -- Persist window size + position
    pcall(function()
        if typeof(writefile) ~= "function" then return end
        local Fluent = _G.MYA_FLUENT_SINGLETON
        local gui    = Fluent and Fluent.GUI
        if typeof(gui) ~= "Instance" then return end
        local sz = gui.AbsoluteSize
        if sz.X >= 100 and sz.Y >= 100 then
            local data = { sx = sz.X, sy = sz.Y }
            local frame = _active.windowFrame
            if frame and typeof(frame) == "Instance" then
                local ap = frame.AbsolutePosition
                data.px = math.floor(ap.X)
                data.py = math.floor(ap.Y)
            end
            writefile(_active.layoutFile, HttpService:JSONEncode(data))
        end
    end)

    for _, conn in ipairs(_active.connections) do conn:Disconnect() end
    _active.connections = {}

    for player in pairs(_active.playerESPs) do removePlayerESP(player) end
    for model  in pairs(_active.worldESPs)  do removeWorldESP(model)   end

    pcall(function()
        if _active.Window and typeof(_active.Window.Destroy) == "function" then
            _active.Window:Destroy()
        end
    end)
    _active.Window           = nil
    _active.windowFrame      = nil
    _active.InterfaceManager = nil
end

return module
