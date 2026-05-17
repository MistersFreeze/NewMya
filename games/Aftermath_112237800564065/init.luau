-- Aftermath ESP module for New_Mya
-- PlaceId: 112237800564065

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findAsset(name)
    local rs = ReplicatedStorage:FindFirstChild(name, true)
    if rs then return rs end
    local rf = game:GetService("ReplicatedFirst"):FindFirstChild(name, true)
    if rf then return rf end
    return nil
end

local CustomCharacter = nil
local startTime = tick()
while not CustomCharacter do
    CustomCharacter = findAsset("CustomCharacter")
    if not CustomCharacter then
        if tick() - startTime > 20 then startTime = tick() end
        task.wait(2)
    end
end

local PlayerListMod = CustomCharacter:FindFirstChild("PlayerList", true)
    or CustomCharacter:WaitForChild("PlayerList", 20)

if not PlayerListMod then
    error("Aftermath: 'PlayerList' module not found.")
end

local PlayerList    = require(PlayerListMod)
local LocalPlayer   = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local module = {}

local _active = {
    connections      = {},
    ESPs             = {},
    layoutConn       = nil,
    Window           = nil,
    windowFrame      = nil,
    InterfaceManager = nil,
    layoutFile       = "Mya/Aftermath/layout.json",
}

-- ─── Feature state ────────────────────────────────────────────────────────────

local esp = {
    enabled     = false,
    selfESP     = false,
    style       = "Box",  -- "Box" | "Corners" | "Filled" | "Outline"
    name        = false,
    distance    = false,
    boxColor    = Color3.fromRGB(255, 255, 255),
    nameColor   = Color3.fromRGB(255, 255, 255),
    distColor   = Color3.fromRGB(255, 255, 255),
    maxDist     = 1000,
    visCheck    = false,
    visColor    = Color3.fromRGB(50,  255, 100),
    hidColor    = Color3.fromRGB(255, 50,  50),
    vehicles    = false,
    vehicleDist = 1000,
    graves      = false,
    graveDist   = 1000,
}

local zombie = {
    enabled  = false,
    visCheck = false,
    visColor = Color3.fromRGB(255, 210,  30),
    hidColor = Color3.fromRGB(180,  90,   0),
}

local _entityESPs = {}
local _zombieESPs = {} -- keyed by NPC UUID (number)

-- ─── Utility ──────────────────────────────────────────────────────────────────

local function w2s(worldPos)
    local sp, vis = CurrentCamera:WorldToViewportPoint(worldPos)
    if vis and sp.Z > 0 then
        return Vector2.new(sp.X, sp.Y), true
    end
    return Vector2.new(0, 0), false
end


local function checkVisible(origin, targetPos, ignoreModel)
    local dir = targetPos - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { CurrentCamera }
    if LocalPlayer.Character then
        table.insert(ignore, LocalPlayer.Character)
    end
    params.FilterDescendantsInstances = ignore
    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end
    if ignoreModel and result.Instance:IsDescendantOf(ignoreModel) then return true end
    return false
end

-- ─── Entity ESP (vehicles / graves) ──────────────────────────────────────────

local function removeEntityESP(obj)
    local entry = _entityESPs[obj]
    if not entry then return end
    if entry.conn then entry.conn:Disconnect() end
    for _, d in pairs(entry.drawings) do d.Visible = false; d:Remove() end
    _entityESPs[obj] = nil
end

local function addEntityESP(obj, text, color, distKey, enabledKey)
    removeEntityESP(obj)
    local d = { text = Drawing.new("Text") }
    d.text.Size    = 16
    d.text.Center  = true
    d.text.Outline = true
    d.text.Color   = color
    d.text.Visible = false

    local entry = { drawings = d, conn = nil }
    _entityESPs[obj] = entry

    entry.conn = RunService.RenderStepped:Connect(function()
        if not esp[enabledKey] then d.text.Visible = false; return end
        if not obj:IsDescendantOf(workspace) then removeEntityESP(obj); return end

        local pos3d
        if obj:IsA("Model") then
            if obj.PrimaryPart then
                pos3d = obj.PrimaryPart.Position
            else
                local part = obj:FindFirstChildWhichIsA("BasePart", true)
                if part then pos3d = part.Position end
                if not pos3d then pcall(function() pos3d = obj:GetPivot().Position end) end
            end
        elseif obj:IsA("BasePart") then
            pos3d = obj.Position
        end
        if not pos3d then d.text.Visible = false; return end

        local dist = (pos3d - CurrentCamera.CFrame.Position).Magnitude
        if dist > esp[distKey] then d.text.Visible = false; return end

        local sp, onScreen = CurrentCamera:WorldToViewportPoint(pos3d)
        if not onScreen or sp.Z <= 0 then d.text.Visible = false; return end

        d.text.Position = Vector2.new(sp.X, sp.Y)
        d.text.Text     = string.format("[%s]\n%d m", text, math.floor(dist))
        d.text.Visible  = true
    end)
end

-- ─── Player ESP ──────────────────────────────────────────────────────────────

local function removeESP(player)
    local entry = _active.ESPs[player]
    if not entry then return end
    if entry.conn then entry.conn:Disconnect() end
    if entry.respawnConn then entry.respawnConn:Disconnect() end
    local d = entry.drawings
    for _, key in ipairs({ "box", "outline", "name", "dist" }) do
        if d[key] then d[key].Visible = false; d[key]:Remove() end
    end
    for _, ln in ipairs(d.corners or {}) do ln.Visible = false; ln:Remove() end
    _active.ESPs[player] = nil
end

local function addESP(player)
    removeESP(player)

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
    d.dist.Size         = 14
    d.dist.Visible      = false

    local function hideAll()
        d.box.Visible = false; d.outline.Visible = false
        d.name.Visible = false; d.dist.Visible = false
        for _, ln in ipairs(d.corners) do ln.Visible = false end
    end

    local entry = { drawings = d, conn = nil, respawnConn = nil }
    _active.ESPs[player] = entry

    local isSelf = player == LocalPlayer
    entry.conn = RunService.RenderStepped:Connect(function()
        if isSelf then
            if not esp.selfESP then hideAll(); return end
        else
            if not esp.enabled then hideAll(); return end
        end

        local char = PlayerList:GetCharacterFromPlayer(player)
        if not char then char = player.Character end
        if not char then hideAll(); return end

        local hrp = char.PrimaryPart
            or char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("RootPart")
            or char:FindFirstChildWhichIsA("BasePart")
        if not hrp then hideAll(); return end

        local camPos = CurrentCamera.CFrame.Position
        local dist   = (hrp.Position - camPos).Magnitude

        local isVis = true
        if esp.visCheck then isVis = checkVisible(camPos, hrp.Position, char) end

        if dist <= esp.maxDist then
            local sp, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
            if onScreen and sp.Z > 0 then
                local col = esp.visCheck
                    and (isVis and esp.visColor or esp.hidColor)
                    or  esp.boxColor

                local topSP    = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 6.0, 0))
                local bottomSP = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, -3.0, 0))
                local x      = math.floor(sp.X)
                local by     = math.floor(math.min(topSP.Y, bottomSP.Y))
                local height = math.max(1, math.abs(math.floor(bottomSP.Y - topSP.Y)))
                local width  = math.max(1, math.floor(height * 0.55))
                local bx     = math.floor(x - width * 0.5)

                local style = esp.style

                if style == "Corners" then
                    d.box.Visible     = false
                    d.outline.Visible = false
                    local cw = math.max(4, math.floor(width  * 0.22))
                    local ch = math.max(4, math.floor(height * 0.22))
                    local segs = {
                        { Vector2.new(bx,         by),          Vector2.new(bx + cw,       by)          },
                        { Vector2.new(bx,         by),          Vector2.new(bx,             by + ch)     },
                        { Vector2.new(bx + width, by),          Vector2.new(bx + width-cw,  by)          },
                        { Vector2.new(bx + width, by),          Vector2.new(bx + width,     by + ch)     },
                        { Vector2.new(bx,         by + height), Vector2.new(bx + cw,        by + height) },
                        { Vector2.new(bx,         by + height), Vector2.new(bx,             by+height-ch)},
                        { Vector2.new(bx + width, by + height), Vector2.new(bx+width-cw,   by + height) },
                        { Vector2.new(bx + width, by + height), Vector2.new(bx + width,     by+height-ch)},
                    }
                    for i, seg in ipairs(segs) do
                        local ln = d.corners[i]
                        ln.From = seg[1]; ln.To = seg[2]
                        ln.Color = col; ln.Thickness = 2; ln.Visible = true
                    end

                elseif style == "Filled" then
                    for _, ln in ipairs(d.corners) do ln.Visible = false end
                    d.outline.Visible  = false
                    d.box.Size         = Vector2.new(width, height)
                    d.box.Position     = Vector2.new(bx, by)
                    d.box.Color        = col
                    d.box.Filled       = true
                    d.box.Transparency = 0.5
                    d.box.Thickness    = 1
                    d.box.ZIndex       = 2
                    d.box.Visible      = true

                elseif style == "Outline" then
                    for _, ln in ipairs(d.corners) do ln.Visible = false end
                    d.outline.Size      = Vector2.new(width + 2, height + 2)
                    d.outline.Position  = Vector2.new(bx - 1,    by - 1)
                    d.outline.Color     = Color3.fromRGB(0, 0, 0)
                    d.outline.Filled    = false
                    d.outline.Thickness = 1
                    d.outline.ZIndex    = 1
                    d.outline.Visible   = true
                    d.box.Size      = Vector2.new(width, height)
                    d.box.Position  = Vector2.new(bx, by)
                    d.box.Color     = col
                    d.box.Filled    = false
                    d.box.Thickness = 1
                    d.box.ZIndex    = 2
                    d.box.Visible   = true

                else -- "Box" default
                    for _, ln in ipairs(d.corners) do ln.Visible = false end
                    d.outline.Visible  = false
                    d.box.Size         = Vector2.new(width, height)
                    d.box.Position     = Vector2.new(bx, by)
                    d.box.Color        = col
                    d.box.Filled       = false
                    d.box.Transparency = 0
                    d.box.Thickness    = 1
                    d.box.ZIndex       = 2
                    d.box.Visible      = true
                end

                d.name.Position = Vector2.new(x, by - 15)
                d.name.Text     = player.Name
                d.name.Color    = esp.nameColor
                d.name.Visible  = esp.name
                d.name.ZIndex   = 3

                d.dist.Position = Vector2.new(x, by + height + 5)
                d.dist.Text     = string.format("%.0f m", dist)
                d.dist.Color    = esp.distColor
                d.dist.Visible  = esp.distance
                d.dist.ZIndex   = 3
            else
                hideAll()
            end
        else
            hideAll()
        end
    end)

    local respawnOk = pcall(function()
        entry.respawnConn = PlayerList:GetCharacterAddedSignal(player):Connect(function()
            task.wait(0.5)
            if Players:FindFirstChild(player.Name) then addESP(player) end
        end)
    end)
    if not respawnOk then
        entry.respawnConn = player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Players:FindFirstChild(player.Name) then addESP(player) end
        end)
    end
end

-- ─── Disc Zombie ESP ──────────────────────────────────────────────────────────

local function removeZombieESP(uuid)
    local d = _zombieESPs[uuid]
    if not d then return end
    if d.label then d.label.Visible = false; d.label:Remove() end
    if d.dist  then d.dist.Visible  = false; d.dist:Remove()  end
    _zombieESPs[uuid] = nil
end

local function isDiscZombie(npc)
    local equipment = rawget(npc, "Equipment")
    if not equipment then return false end
    for _, item in ipairs(equipment) do
        if type(item) == "string" then
            local s = item:lower()
            if s:find("beret") or s:find("disc") or s:find("airdrop") then return true end
        elseif type(item) == "table" then
            local cn = tostring(rawget(item, "ClassName") or rawget(item, "Class") or ""):lower()
            local nm = tostring(rawget(item, "Name") or rawget(item, "Id") or ""):lower()
            if cn:find("beret") or nm:find("beret")
                or cn:find("disc") or nm:find("disc")
                or cn:find("airdrop") or nm:find("airdrop") then
                return true
            end
        end
    end
    return false
end

-- ─── mount ───────────────────────────────────────────────────────────────────

function module.mount(ctx)
    -- ── Get NPCSimulatorService for disc-zombie detection ─────────────────────
    local NPCSvc = nil
    local function findNPCSvc()
        if NPCSvc and rawget(NPCSvc, "NPCs") then return true end
        -- getgc: no require() call, leaves no module trace
        if typeof(getgc) == "function" then
            local ok, gc = pcall(getgc, true)
            if ok then
                for _, v in ipairs(gc) do
                    if type(v) == "table" then
                        local npcs = rawget(v, "NPCs")
                        if type(npcs) == "table" then
                            local _, sample = next(npcs)
                            if sample == nil or (type(sample) == "table" and rawget(sample, "Character") ~= nil) then
                                NPCSvc = v
                                return true
                            end
                        end
                    end
                end
            end
        end
        -- Fallback: module search (may leave a trace)
        pcall(function()
            local rf  = game:GetService("ReplicatedFirst")
            local mod = rf:FindFirstChild("NPCSimulatorService", true)
            if mod then
                local svc = require(mod)
                if type(svc) == "table" and svc.NPCs then NPCSvc = svc end
            end
        end)
        return NPCSvc ~= nil
    end

    findNPCSvc()
    if not NPCSvc then
        task.spawn(function()
            for _ = 1, 15 do
                task.wait(3)
                if findNPCSvc() then break end
            end
        end)
    end

    -- ── Fluent singleton ─────────────────────────────────────────────────────
    local Fluent
    do
        local cached = _G.MYA_FLUENT_SINGLETON
        if typeof(cached) == "table" and typeof(cached.CreateWindow) == "function" then
            Fluent = cached
        else
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
    end

    local SaveManager      = Fluent.SaveManager
    local InterfaceManager = Fluent.InterfaceManager

    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    InterfaceManager:SetFolder("Mya/Aftermath")
    SaveManager:SetFolder("Mya/Aftermath/Config")

    -- Force RightShift before LoadSettings
    pcall(function()
        if typeof(isfile) == "function" and isfile("Mya/Aftermath/options.json") then
            local raw = readfile("Mya/Aftermath/options.json")
            local ok, opts = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and typeof(opts) == "table" then
                opts.MenuKeybind = "RightShift"
                pcall(writefile, "Mya/Aftermath/options.json", HttpService:JSONEncode(opts))
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

    local function setGuiVisible(v)
        local gui = Fluent and Fluent.GUI
        if typeof(gui) == "Instance" then pcall(function() gui.Enabled = v end) end
    end
    setGuiVisible(false)

    local ifacePre = InterfaceManager.Settings
    local function pickTheme(name)
        if typeof(name) == "string" and table.find(Fluent.Themes, name) then return name end
        return "Blood Red"
    end

    local Window = Fluent:CreateWindow({
        Title       = "Aftermath",
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
        -- Locate and cache the draggable window frame
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
                -- Restore saved position
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

    -- ── Tabs ─────────────────────────────────────────────────────────────────

    local VisualsTab  = Window:AddTab({ Title = "Visuals",  Icon = "solar/eye-bold"       })
    local ConfigTab   = Window:AddTab({ Title = "Config",   Icon = "solar/diskette-bold"  })
    local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold"  })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Player ESP
    -- ════════════════════════════════════════════════════════════════════════

    local espSec = VisualsTab:AddSection("Player ESP")

    espSec:AddToggle("ESPEnabled", {
        Title    = "Enable ESP",
        Default  = false,
        Callback = function(v) esp.enabled = v end,
    })

    espSec:AddToggle("SelfESP", {
        Title    = "Self ESP",
        Default  = false,
        Callback = function(v) esp.selfESP = v end,
    })

    espSec:AddToggle("ESPVisCheck", {
        Title    = "Visual Check",
        Default  = false,
        Callback = function(v) esp.visCheck = v end,
    })

    espSec:AddColorpicker("ESPVisColor", {
        Title    = "Visible Color",
        Default  = Color3.fromRGB(50, 255, 100),
        Callback = function(v) esp.visColor = v end,
    })

    espSec:AddColorpicker("ESPHidColor", {
        Title    = "Hidden Color",
        Default  = Color3.fromRGB(255, 50, 50),
        Callback = function(v) esp.hidColor = v end,
    })

    espSec:AddDropdown("ESPStyle", {
        Title   = "Style",
        Values  = { "Box", "Corners", "Filled", "Outline" },
        Default = "Box",
        Callback = function(v) esp.style = v end,
    })

    espSec:AddColorpicker("BoxColor", {
        Title    = "Box Color",
        Default  = Color3.fromRGB(255, 255, 255),
        Callback = function(v) esp.boxColor = v end,
    })

    espSec:AddToggle("NameEnabled", {
        Title    = "Name",
        Default  = false,
        Callback = function(v) esp.name = v end,
    })

    espSec:AddColorpicker("NameColor", {
        Title    = "Name Color",
        Default  = Color3.fromRGB(255, 255, 255),
        Callback = function(v) esp.nameColor = v end,
    })

    espSec:AddToggle("DistanceEnabled", {
        Title    = "Distance",
        Default  = false,
        Callback = function(v) esp.distance = v end,
    })

    espSec:AddColorpicker("DistanceColor", {
        Title    = "Distance Color",
        Default  = Color3.fromRGB(255, 255, 255),
        Callback = function(v) esp.distColor = v end,
    })

    espSec:AddSlider("MaxESPDistance", {
        Title    = "Max Distance",
        Default  = 1000,
        Min      = 100,
        Max      = 2000,
        Rounding = 0,
        Callback = function(v) esp.maxDist = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Disc Zombies
    -- ════════════════════════════════════════════════════════════════════════

    local zombieSec = VisualsTab:AddSection("Disc Zombies")

    zombieSec:AddToggle("ZombieESP", {
        Title    = "Enable ESP",
        Default  = false,
        Callback = function(v) zombie.enabled = v end,
    })

    zombieSec:AddToggle("ZombieVisCheck", {
        Title    = "Visual Check",
        Default  = false,
        Callback = function(v) zombie.visCheck = v end,
    })

    zombieSec:AddColorpicker("ZombieVisColor", {
        Title    = "Visible Color",
        Default  = Color3.fromRGB(255, 210, 30),
        Callback = function(v) zombie.visColor = v end,
    })

    zombieSec:AddColorpicker("ZombieHidColor", {
        Title    = "Hidden Color",
        Default  = Color3.fromRGB(180, 90, 0),
        Callback = function(v) zombie.hidColor = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Vehicles
    -- ════════════════════════════════════════════════════════════════════════

    local vehicleSec = VisualsTab:AddSection("Vehicles")

    vehicleSec:AddToggle("VehicleESP", {
        Title    = "Enable ESP",
        Default  = false,
        Callback = function(v) esp.vehicles = v end,
    })

    vehicleSec:AddSlider("VehicleDist", {
        Title    = "Max Distance",
        Default  = 1000,
        Min      = 100,
        Max      = 5000,
        Rounding = 0,
        Callback = function(v) esp.vehicleDist = v end,
    })

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION: Graves
    -- ════════════════════════════════════════════════════════════════════════

    local graveSec = VisualsTab:AddSection("Graves")

    graveSec:AddToggle("GraveESP", {
        Title    = "Enable ESP",
        Default  = false,
        Callback = function(v) esp.graves = v end,
    })

    graveSec:AddSlider("GraveDist", {
        Title    = "Max Distance",
        Default  = 1000,
        Min      = 100,
        Max      = 5000,
        Rounding = 0,
        Callback = function(v) esp.graveDist = v end,
    })

    -- ── Config tab ───────────────────────────────────────────────────────────

    local cfgInfoSec = ConfigTab:AddSection("Configs")
    cfgInfoSec:AddParagraph({
        Title   = "How to use",
        Content = "Type a name → Create config.\nSelect → Load config.\nSet as autoload for auto-apply.",
    })
    SaveManager:BuildConfigSection(ConfigTab)

    -- ── Settings tab ─────────────────────────────────────────────────────────

    InterfaceManager:BuildInterfaceSection(SettingsTab)

    pcall(function()
        Fluent.MinimizeKeybind:SetValue("RightShift")
        InterfaceManager:SaveSettings()
    end)

    -- ─── Player tracking ─────────────────────────────────────────────────────

    for _, p in ipairs(Players:GetPlayers()) do
        addESP(p)
    end

    pcall(function()
        local addSig
        if PlayerList and PlayerList.PlayerAdded
            and typeof(PlayerList.PlayerAdded.Connect) == "function" then
            addSig = PlayerList.PlayerAdded
        else
            addSig = Players.PlayerAdded
        end
        table.insert(_active.connections, addSig:Connect(function(p)
            addESP(p)
        end))
    end)

    table.insert(_active.connections, Players.PlayerRemoving:Connect(removeESP))

    -- ─── Entity tracking (vehicles / graves) ─────────────────────────────────

    local function registerVehicle(obj)
        if not obj or not obj:IsA("Model") then return end
        if _entityESPs[obj] then return end
        addEntityESP(obj, "Vehicle", Color3.fromRGB(255, 200, 0), "vehicleDist", "vehicles")
    end

    -- Walk up from a tagged part to the nearest Model ancestor
    local function findVehicleModel(part)
        local current = part.Parent
        while current and current ~= workspace do
            if current:IsA("Model") then return current end
            current = current.Parent
        end
        return nil
    end

    local function checkGrave(obj)
        if obj:IsA("Model") and obj.Name:lower():find("grave") then
            addEntityESP(obj, "Grave", Color3.fromRGB(200, 200, 200), "graveDist", "graves")
        end
    end

    local cs = game:GetService("CollectionService")

    -- Vehicles: parts tagged VEHICLE_COLLIDABLE → walk up to their Model
    table.insert(_active.connections, cs:GetInstanceAddedSignal("VEHICLE_COLLIDABLE"):Connect(function(part)
        local model = findVehicleModel(part)
        if model then registerVehicle(model) end
    end))
    table.insert(_active.connections, cs:GetInstanceRemovedSignal("VEHICLE_COLLIDABLE"):Connect(function(part)
        local model = findVehicleModel(part)
        if model then removeEntityESP(model) end
    end))

    table.insert(_active.connections, workspace.DescendantAdded:Connect(checkGrave))
    table.insert(_active.connections, workspace.DescendantRemoving:Connect(removeEntityESP))

    -- Initial scan
    for _, part in ipairs(cs:GetTagged("VEHICLE_COLLIDABLE")) do
        pcall(function()
            local model = findVehicleModel(part)
            if model then registerVehicle(model) end
        end)
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(checkGrave, obj)
    end

    -- ─── Disc Zombie ESP loop ─────────────────────────────────────────────────

    local zombieConn = RunService.RenderStepped:Connect(function()
        if not zombie.enabled then
            for uuid in pairs(_zombieESPs) do removeZombieESP(uuid) end
            return
        end
        if not NPCSvc then return end

        local seen = {}
        for uuid, npc in pairs(NPCSvc.NPCs) do
            if not npc.Dead and isDiscZombie(npc) then
                seen[uuid] = true

                local char    = npc.Character
                local primary = npc.PrimaryPart

                -- Create drawings on first sight
                if not _zombieESPs[uuid] then
                    local label = Drawing.new("Text")
                    label.Size    = 15
                    label.Center  = true
                    label.Outline = true
                    label.Bold    = true
                    label.Visible = false
                    label.ZIndex  = 5

                    local distTxt = Drawing.new("Text")
                    distTxt.Size    = 13
                    distTxt.Center  = true
                    distTxt.Outline = true
                    distTxt.Visible = false
                    distTxt.ZIndex  = 5

                    _zombieESPs[uuid] = { label = label, dist = distTxt }
                end

                local d      = _zombieESPs[uuid]
                local camPos = CurrentCamera.CFrame.Position

                if primary and primary:IsDescendantOf(workspace) then
                    local pos      = primary.Position
                    local distance = (pos - camPos).Magnitude
                    local sp, onScreen = CurrentCamera:WorldToViewportPoint(pos)

                    if onScreen and sp.Z > 0 then
                        local isVis = true
                        if zombie.visCheck then
                            isVis = checkVisible(camPos, pos, char)
                        end
                        local color = zombie.visCheck
                            and (isVis and zombie.visColor or zombie.hidColor)
                            or  zombie.visColor

                        d.label.Position = Vector2.new(sp.X, sp.Y - 20)
                        d.label.Text     = "[Disc Zombie]"
                        d.label.Color    = color
                        d.label.Visible  = true

                        d.dist.Position  = Vector2.new(sp.X, sp.Y - 4)
                        d.dist.Text      = string.format("%.0f m", distance)
                        d.dist.Color     = color
                        d.dist.Visible   = true
                    else
                        d.label.Visible = false
                        d.dist.Visible  = false
                    end
                else
                    d.label.Visible = false
                    d.dist.Visible  = false
                end
            end
        end

        -- Clean up removed/dead zombie ESPs
        for uuid in pairs(_zombieESPs) do
            if not seen[uuid] then removeZombieESP(uuid) end
        end
    end)

    table.insert(_active.connections, zombieConn)

    -- ── Layout save heartbeat ────────────────────────────────────────────────

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

    -- ── Autoload ─────────────────────────────────────────────────────────────

    task.defer(function() pcall(function() SaveManager:LoadAutoloadConfig() end) end)

    if ctx and typeof(ctx.notify) == "function" then
        ctx.notify("Aftermath ESP loaded")
    end
end

-- ─── unmount ──────────────────────────────────────────────────────────────────

function module.unmount()
    if _active.layoutConn then
        _active.layoutConn:Disconnect()
        _active.layoutConn = nil
    end

    -- Persist theme and interface settings before teardown
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

    for player in pairs(_active.ESPs) do removeESP(player) end
    for obj    in pairs(_entityESPs)  do removeEntityESP(obj) end
    for uuid   in pairs(_zombieESPs)  do removeZombieESP(uuid) end

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
