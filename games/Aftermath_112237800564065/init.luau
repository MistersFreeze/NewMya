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
print("[Mya Aftermath] Initializing asset discovery...")

-- Wait loop with feedback
local startTime = tick()
while not CustomCharacter do
    CustomCharacter = findAsset("CustomCharacter")
    if not CustomCharacter then
        if tick() - startTime > 20 then
            warn("[Mya Aftermath] Still waiting for 'CustomCharacter' folder. Are you sure you are in a match?")
            startTime = tick() -- Reset warning timer
        end
        task.wait(2)
    end
end

print("[Mya Aftermath] Found 'CustomCharacter' at: " .. CustomCharacter:GetFullName())

local PlayerListMod = CustomCharacter:FindFirstChild("PlayerList", true)
if not PlayerListMod then
    print("[Mya Aftermath] Waiting for 'PlayerList' module...")
    PlayerListMod = CustomCharacter:WaitForChild("PlayerList", 20)
end

if not PlayerListMod then
    error("Aftermath initialization failed: 'PlayerList' module not found anywhere inside 'CustomCharacter'.")
end

local PlayerList = require(PlayerListMod)
print("[Mya Aftermath] PlayerList required successfully.")

local LocalPlayer   = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local module = {}

-- Shared across mount/unmount
local _active = {
    connections = {},
    ESPs        = {},
    layoutConn  = nil,
    Window      = nil,
    layoutFile  = "MyaAftermath/layout.json",
}

-- ─── ESP state ───────────────────────────────────────────────────────────────

local esp = {
    enabled         = false,
    box             = false,
    boxFilled       = false,
    boxOutline      = false,
    name            = false,
    distance        = false,
    boxColor        = Color3.fromRGB(255, 255, 255),
    boxFilledColor  = Color3.fromRGB(255, 255, 255),
    boxOutlineColor = Color3.fromRGB(0,   0,   0),
    nameColor       = Color3.fromRGB(255, 255, 255),
    distColor       = Color3.fromRGB(255, 255, 255),
    maxDist         = 1000,
}

-- ─── Drawing helpers ─────────────────────────────────────────────────────────

local function removeESP(player)
    local entry = _active.ESPs[player]
    if not entry then return end
    if entry.conn then entry.conn:Disconnect() end
    if entry.respawnConn then entry.respawnConn:Disconnect() end
    for _, d in pairs(entry.drawings) do
        d.Visible = false
        d:Remove()
    end
    _active.ESPs[player] = nil
end

local function addESP(player)
    removeESP(player)

    local d = {
        box        = Drawing.new("Square"),
        boxOutline = Drawing.new("Square"),
        name       = Drawing.new("Text"),
        dist       = Drawing.new("Text"),
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

    local entry = { drawings = d, conn = nil, lastChar = nil }
    _active.ESPs[player] = entry

    entry.conn = RunService.RenderStepped:Connect(function()
        if not esp.enabled then
            for _, dr in pairs(d) do dr.Visible = false end
            return
        end

        local char = PlayerList:GetCharacterFromPlayer(player)
        if not char then
            for _, dr in pairs(d) do dr.Visible = false end
            return
        end

        local hrp = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("RootPart")
        if not hrp then
            -- Fallback: try to find any part if PrimaryPart is missing (common during loading)
            hrp = char:FindFirstChildWhichIsA("BasePart")
        end

        if not hrp then
            for _, dr in pairs(d) do dr.Visible = false end
            return
        end

        local dist = (hrp.Position - CurrentCamera.CFrame.Position).Magnitude
        if dist > esp.maxDist then
            for _, dr in pairs(d) do dr.Visible = false end
            return
        end

        local pos, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
        if not onScreen then
            for _, dr in pairs(d) do dr.Visible = false end
            return
        end

        local scale  = 1 / (pos.Z * math.tan(math.rad(CurrentCamera.FieldOfView * 0.5)) * 2) * 1000
        local width  = math.floor(4.5 * scale)
        local height = math.floor(6.0 * scale)
        local x      = math.floor(pos.X)
        local y      = math.floor(pos.Y)
        local bx     = math.floor(x - width * 0.5)
        local by     = math.floor((y - height * 0.5) + (0.5 * scale) - 15)

        -- Outline drawn below box (lower ZIndex)
        d.boxOutline.Size      = Vector2.new(width, height)
        d.boxOutline.Position  = Vector2.new(bx, by)
        d.boxOutline.Color     = esp.boxOutlineColor
        d.boxOutline.Thickness = 2
        d.boxOutline.Filled    = false
        d.boxOutline.Visible   = esp.boxOutline
        d.boxOutline.ZIndex    = 1

        d.box.Size         = Vector2.new(width, height)
        d.box.Position     = Vector2.new(bx, by)
        d.box.Color        = esp.boxFilled and esp.boxFilledColor or esp.boxColor
        d.box.Thickness    = 1
        d.box.Filled       = esp.boxFilled
        d.box.Transparency = esp.boxFilled and 0.5 or 0
        d.box.Visible      = esp.box
        d.box.ZIndex       = 2

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
    end)

    -- Reconnect drawings after the player respawns
    entry.respawnConn = PlayerList:GetCharacterAddedSignal(player):Connect(function()
        task.wait(0.5) -- Give the new character a moment to settle
        if Players:FindFirstChild(player.Name) then
            addESP(player)
        end
    end)
end

-- ─── mount ───────────────────────────────────────────────────────────────────

function module.mount(ctx)
    -- Fluent: use singleton so we never double-load the library
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
    InterfaceManager:SetFolder("MyaAftermath")
    SaveManager:SetFolder("MyaAftermath/Config")

    -- Force RightShift in saved options before LoadSettings so a stale bind is never restored
    pcall(function()
        if typeof(isfile) == "function" and isfile("MyaAftermath/options.json") then
            local raw = readfile("MyaAftermath/options.json")
            local ok, opts = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and typeof(opts) == "table" then
                opts.MenuKeybind = "RightShift"
                pcall(writefile, "MyaAftermath/options.json", HttpService:JSONEncode(opts))
            end
        end
    end)

    InterfaceManager:LoadSettings()
    InterfaceManager.Settings.MenuKeybind = "RightShift"

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

    local windowSize = UDim2.fromOffset(520, 480)
    if savedLayout then
        local sx = tonumber(savedLayout.sx)
        local sy = tonumber(savedLayout.sy)
        if sx and sy and sx >= 400 and sy >= 300 then
            windowSize = UDim2.fromOffset(math.floor(sx), math.floor(sy))
        end
    end

    -- Hide while building to avoid theme flash
    local function setGuiVisible(visible)
        local rootGui = Fluent and Fluent.GUI
        if typeof(rootGui) == "Instance" then
            pcall(function() rootGui.Enabled = visible end)
        end
    end
    setGuiVisible(false)

    local ifacePre = InterfaceManager.Settings

    local function pickTheme(name)
        if typeof(name) == "string" and table.find(Fluent.Themes, name) then
            return name
        end
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

    -- Apply saved theme/transparency after first paint to avoid flash
    task.defer(function()
        pcall(function() Fluent:SetTheme(pickTheme(ifacePre.Theme)) end)
        pcall(function() Fluent:ToggleTransparency(ifacePre.Transparency ~= false) end)
        setGuiVisible(true)
    end)

    -- ── Tabs ─────────────────────────────────────────────────────────────────

    local VisualsTab  = Window:AddTab({ Title = "Visuals",  Icon = "solar/eye-bold" })
    local ConfigTab   = Window:AddTab({ Title = "Config",   Icon = "solar/diskette-bold" })
    local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

    -- ── Visuals → Player ESP ─────────────────────────────────────────────────

    local espSec = VisualsTab:AddSection("Player ESP")

    espSec:AddToggle("ESPEnabled", {
        Title    = "Enable ESP",
        Default  = false,
        Callback = function(v) esp.enabled = v end,
    })

    espSec:AddToggle("BoxEnabled", {
        Title    = "Box",
        Default  = false,
        Callback = function(v) esp.box = v end,
    })

    espSec:AddColorpicker("BoxColor", {
        Title    = "Box Color",
        Default  = Color3.fromRGB(255, 255, 255),
        Callback = function(v) esp.boxColor = v end,
    })

    espSec:AddToggle("BoxFilledEnabled", {
        Title    = "Filled Box",
        Default  = false,
        Callback = function(v) esp.boxFilled = v end,
    })

    espSec:AddColorpicker("BoxFilledColor", {
        Title    = "Fill Color",
        Default  = Color3.fromRGB(255, 255, 255),
        Callback = function(v) esp.boxFilledColor = v end,
    })

    espSec:AddToggle("BoxOutlineEnabled", {
        Title    = "Box Outline",
        Default  = false,
        Callback = function(v) esp.boxOutline = v end,
    })

    espSec:AddColorpicker("BoxOutlineColor", {
        Title    = "Outline Color",
        Default  = Color3.fromRGB(0, 0, 0),
        Callback = function(v) esp.boxOutlineColor = v end,
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

    -- ── Config tab ───────────────────────────────────────────────────────────

    local cfgInfoSec = ConfigTab:AddSection("Configs")
    cfgInfoSec:AddParagraph({
        Title   = "How to use",
        Content = "Type a name → Create config.\nSelect → Load config.\nSet as autoload for auto-apply.",
    })
    SaveManager:BuildConfigSection(ConfigTab)

    -- ── Settings tab ─────────────────────────────────────────────────────────

    InterfaceManager:BuildInterfaceSection(SettingsTab)

    -- Lock keybind to RightShift in the live widget and persist it
    pcall(function()
        Fluent.MinimizeKeybind:SetValue("RightShift")
        InterfaceManager:SaveSettings()
    end)

    -- ─── Track existing players ──────────────────────────────────────────────
    
    local function setupTracking()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then addESP(p) end
        end

        -- Try to hook PlayerList's custom signals if they exist
        pcall(function()
            if PlayerList and PlayerList.PlayerAdded and typeof(PlayerList.PlayerAdded.Connect) == "function" then
                table.insert(_active.connections, PlayerList.PlayerAdded:Connect(function(p)
                    if p ~= LocalPlayer then addESP(p) end
                end))
                print("[Mya Aftermath] Hooked custom PlayerList.PlayerAdded signal.")
            else
                table.insert(_active.connections, Players.PlayerAdded:Connect(function(p)
                    if p ~= LocalPlayer then addESP(p) end
                end))
                print("[Mya Aftermath] Falling back to standard Players.PlayerAdded.")
            end
        end)
    end

    setupTracking()
    print("[Mya Aftermath] Tracking system active.")

    local removingConn = Players.PlayerRemoving:Connect(removeESP)
    table.insert(_active.connections, removingConn)


    -- ── Layout save (every 10 s) ─────────────────────────────────────────────

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
            writefile(_active.layoutFile, HttpService:JSONEncode({ sx = sz.X, sy = sz.Y }))
        end)
    end)

    -- ── Autoload config ──────────────────────────────────────────────────────

    task.defer(function()
        pcall(function() SaveManager:LoadAutoloadConfig() end)
    end)

    if ctx and typeof(ctx.notify) == "function" then
        ctx.notify("Aftermath ESP loaded")
    end
end

-- ─── unmount ──────────────────────────────────────────────────────────────────

function module.unmount()
    -- Stop layout heartbeat
    if _active.layoutConn then
        _active.layoutConn:Disconnect()
        _active.layoutConn = nil
    end

    -- Save layout one final time
    pcall(function()
        if typeof(writefile) ~= "function" then return end
        local Fluent = _G.MYA_FLUENT_SINGLETON
        local gui = Fluent and Fluent.GUI
        if typeof(gui) ~= "Instance" then return end
        local sz = gui.AbsoluteSize
        if sz.X >= 100 and sz.Y >= 100 then
            writefile(_active.layoutFile, HttpService:JSONEncode({ sx = sz.X, sy = sz.Y }))
        end
    end)

    -- Disconnect player connections
    for _, conn in ipairs(_active.connections) do
        conn:Disconnect()
    end
    _active.connections = {}

    -- Remove all ESP drawings
    for player in pairs(_active.ESPs) do
        removeESP(player)
    end

    -- Destroy Fluent window
    pcall(function()
        if _active.Window and typeof(_active.Window.Destroy) == "function" then
            _active.Window:Destroy()
        end
    end)
    _active.Window = nil
end

return module
