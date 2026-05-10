--[[
    Mya - Operation One
    edit these variables to set defaults
]]--

local boxes           = false
local skeletons       = true
local tracers         = false
local healthbars      = false
local names           = false
local team_check      = true
local gadgets         = false
local fullbright      = false
local aim_assist      = false

-- Crosshair-ring arrows (Drawing), same behavior as Mya Universal / AR2 (off-screen + visibility).
local arrows_esp_on = false
local arrows_esp_ring_radius = 72
local arrows_esp_tip_len = 14
local arrows_esp_half_width = 7
local arrows_esp_distance_on = true

local aim_fov         = 120        -- pixels radius
local aim_speed       = 0.25       -- 0.0 (slow) -> 0.99 (fast) -> 1.0 (instant snap)
local aim_key         = Enum.UserInputType.MouseButton2
local menu_key        = Enum.KeyCode.RightShift -- toggles Mya menu (Misc → Menu bind)
local show_fov_circle = false
local vis_check       = false      -- false = track through walls, true = visible only

-- Silent aim — state names match Mya Universal (silent_aim.lua + exports)
local silent_aim_on = false
local silent_aim_fov = 100
local silent_aim_fov_follow_cursor = false
local silent_aim_require_bind = false
local silent_aim_bind = Enum.UserInputType.MouseButton2
local silent_aim_vis_check_on = true
local silent_aim_team_check_on = true
local show_silent_aim_fov_circle = false
local silent_aim_part = Combat.parse_hit_part(nil, "silent_aim_part", "HumanoidRootPart")

-- Customisable colors (overridable from UI/config)
local color_tracer     = Color3.new(1, 1, 1)
local color_box        = Color3.new(1, 1, 1)
local color_skel_vis   = Color3.fromRGB(0, 255, 0)
local color_skel_hid   = Color3.new(1, 1, 1)
local color_fov_circle = Color3.fromRGB(245, 118, 168)
local color_fov_silent = Color3.fromRGB(160, 120, 220)
local color_throwable  = Color3.fromRGB(255, 60, 60)
local color_placeable  = Color3.fromRGB(255, 170, 0)
local color_box_vis    = Color3.fromRGB(0, 255, 0)


--[[ begin main script ]]--

local pad = 4

local cloneref_support = cloneref ~= nil
local gethui_support   = gethui ~= nil

local runservice   = cloneref_support and cloneref(game:GetService("RunService"))        or game:GetService("RunService")
local uis          = cloneref_support and cloneref(game:GetService("UserInputService"))  or game:GetService("UserInputService")
local players      = cloneref_support and cloneref(game:GetService("Players"))           or game:GetService("Players")
local collection   = cloneref_support and cloneref(game:GetService("CollectionService")) or game:GetService("CollectionService")
local lighting_svc = game:GetService("Lighting")

local local_player = players.LocalPlayer

-- Mya Universal silent aim service aliases (silent_aim.lua)
local Players = players
local lp = local_player
local RunService = runservice
local UserInputService = uis

local StateObject = nil
pcall(function()
    StateObject = require(game.ReplicatedStorage.Modules.StateObject)
end)

local bones = {
    { "torso", "head" },
    { "torso", "shoulder1" }, { "torso", "shoulder2" },
    { "shoulder1", "arm1" },  { "shoulder2", "arm2" },
    { "torso", "hip1" },      { "torso", "hip2" },
    { "hip1", "leg1" },       { "hip2", "leg2" },
}

local required_bones    = { "torso", "head", "shoulder1", "shoulder2", "arm1", "arm2", "hip1", "hip2", "leg1", "leg2" }
local aim_bone_priority = { "head", "torso", "shoulder1", "shoulder2", "arm1", "arm2", "hip1", "hip2", "leg1", "leg2" }

-- -------------------- Gadget categories --------------------
local throwable_tags = {
    { tag = "FragGrenade",       name = "Frag",        category = "throwable" },
    { tag = "StunGrenade",       name = "Flash",        category = "throwable" },
    { tag = "IncendiaryGrenade", name = "Incendiary",   category = "throwable" },
    { tag = "SmokeGrenade",      name = "Smoke",        category = "throwable" },
    { tag = "RemoteC4",          name = "C4",           category = "throwable" },
    { tag = "StickyCamera",      name = "Sticky Cam",   category = "throwable" },
    { tag = "ToxicCharge",       name = "Toxic",        category = "throwable" },
    { tag = "Drone",             name = "Drone",        category = "throwable" },
    { tag = "ProximityAlarm",    name = "Prox Alarm",   category = "throwable" },
}

local placeable_tags = {
    { tag = "BarbedWire",        name = "Barbed Wire",  category = "placeable" },
    { tag = "BreachCharge",      name = "Breach Charge",category = "placeable" },
    { tag = "HardBreachCharge",  name = "Hard Breach",  category = "placeable" },
    { tag = "Claymore",          name = "Claymore",     category = "placeable" },
    { tag = "BulletproofCamera", name = "BP Camera",    category = "placeable" },
    { tag = "Defuser",           name = "Defuser",      category = "placeable" },
    { tag = "DeployableShield",  name = "Shield",       category = "placeable" },
    { tag = "ShockBattery",      name = "Shock Battery",category = "placeable" },
    { tag = "SignalDisruptor",   name = "Jammer",       category = "placeable" },
    { tag = "ThermiteCharge",    name = "Thermite",     category = "placeable" },
    { tag = "DefaultCamera",     name = "Camera",       category = "placeable" },
}

local all_gadget_tags = {}
for _, t in ipairs(throwable_tags) do table.insert(all_gadget_tags, t) end
for _, t in ipairs(placeable_tags)  do table.insert(all_gadget_tags, t) end

-- -------------------- State --------------------
local esp_list      = {}
local skeleton_list = {}
local gadget_data   = {}
local connections   = {}
local viewmodels    = workspace:FindFirstChild("Viewmodels")
local camera        = workspace.CurrentCamera
local unloaded      = false

connections[#connections+1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
end)

local aim_remainder_x, aim_remainder_y = 0, 0


-- -------------------- Teammate detection --------------------
local teammate_highlights = {}
connections[#connections+1] = workspace.ChildAdded:Connect(function(c)
    if c:IsA("Highlight") then teammate_highlights[c] = true end
end)
connections[#connections+1] = workspace.ChildRemoved:Connect(function(c)
    if c:IsA("Highlight") then teammate_highlights[c] = nil end
end)
for _, c in ipairs(workspace:GetChildren()) do
    if c:IsA("Highlight") then teammate_highlights[c] = true end
end

local function is_teammate(model)
    if not team_check then return false end
    for h in pairs(teammate_highlights) do
        if h.Adornee == model then return true end
    end
    return false
end

local function is_friendly_gadget(instance)
    if not team_check then return false end
    if not StateObject then return false end
    local ok, result = pcall(function()
        local all = StateObject.get_all_global()
        local obj = all[instance]
        if obj and obj.owner then
            local owner = obj.owner:get()
            if owner then
                if owner == local_player then return true end
                if owner.Character and is_teammate(owner.Character) then return true end
            end
        end
        return false
    end)
    return ok and result
end

local function is_camera_broken(instance)
    local cam = instance:FindFirstChild("Cam")
    return cam and cam:IsA("BasePart") and cam.Transparency >= 1
end

local function is_valid(model)
    if not model or not model.Parent then return false end
    if model.Name == "LocalViewmodel" then return false end
    if not viewmodels or model.Parent ~= viewmodels then return false end
    local torso = model:FindFirstChild("torso")
    return torso and torso:IsA("BasePart")
end

-- -------------------- Robust player resolver --------------------
-- Resolves a player from a viewmodel at creation time and caches it.
-- Priority: ObjectValue "Player" child -> attribute -> name/userId match -> nearby HRP fallback.
local function resolve_player_for_viewmodel(character)
    -- 1. ObjectValue named "Player" inside the viewmodel
    local pval = character:FindFirstChild("Player")
    if pval and pval:IsA("ObjectValue") and pval.Value and pval.Value:IsA("Player") then
        return pval.Value
    end
    -- 2. Attribute "UserId" or "Player"
    local uid_attr = character:GetAttribute("UserId") or character:GetAttribute("Player")
    if uid_attr then
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= local_player and (p.UserId == tonumber(uid_attr) or p.Name == tostring(uid_attr)) then return p end
        end
    end
    -- 3. Model name matches a player's Name or UserId string
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= local_player and (character.Name == p.Name or character.Name == tostring(p.UserId)) then
            return p
        end
    end

    -- 4. Tight HumanoidRootPart proximity fallback (15 studs max)
    local torso = character:FindFirstChild("torso")
    if torso then
        local pos = torso.Position
        local best_p, best_d = nil, 15
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= local_player and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (hrp.Position - pos).Magnitude
                    if d < best_d then best_d = d; best_p = p end
                end
            end
        end
        return best_p
    end
    return nil
end

local function rand_str(len)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}
    for i = 1, len do result[i] = chars:sub(math.random(1,#chars), math.random(1,#chars)) end
    return table.concat(result)
end

local screen_gui = Instance.new("ScreenGui")
screen_gui.Name   = rand_str(12)
screen_gui.Parent = gethui_support and gethui() or game:GetService("CoreGui")

-- -------------------- Fullbright --------------------
local orig_lighting = {}

local function apply_fullbright(state)
    if state then
        orig_lighting.Brightness           = lighting_svc.Brightness
        orig_lighting.ClockTime            = lighting_svc.ClockTime
        orig_lighting.FogEnd               = lighting_svc.FogEnd
        orig_lighting.ExposureCompensation = lighting_svc.ExposureCompensation
        orig_lighting.GlobalShadows        = lighting_svc.GlobalShadows
        lighting_svc.Brightness            = 2
        lighting_svc.ClockTime             = 14
        lighting_svc.FogEnd                = 100000
        lighting_svc.ExposureCompensation  = 1
        lighting_svc.GlobalShadows         = false
        for _, effect in ipairs(lighting_svc:GetChildren()) do
            if effect:IsA("PostEffect") and orig_lighting[effect] == nil then
                orig_lighting[effect] = effect.Enabled
                effect.Enabled = false
            end
        end
    else
        if orig_lighting.Brightness           ~= nil then lighting_svc.Brightness           = orig_lighting.Brightness           end
        if orig_lighting.ClockTime            ~= nil then lighting_svc.ClockTime            = orig_lighting.ClockTime            end
        if orig_lighting.FogEnd               ~= nil then lighting_svc.FogEnd               = orig_lighting.FogEnd               end
        if orig_lighting.ExposureCompensation ~= nil then lighting_svc.ExposureCompensation = orig_lighting.ExposureCompensation end
        if orig_lighting.GlobalShadows        ~= nil then lighting_svc.GlobalShadows        = orig_lighting.GlobalShadows        end
        for _, effect in ipairs(lighting_svc:GetChildren()) do
            if effect:IsA("PostEffect") and orig_lighting[effect] ~= nil then
                effect.Enabled = orig_lighting[effect]; orig_lighting[effect] = nil
            end
        end
        orig_lighting = {}
    end
end

-- -------------------- FOV circles --------------------
local fov_circle = Drawing.new("Circle")
fov_circle.Visible = false; fov_circle.Color = color_fov_circle
fov_circle.Thickness = 2; fov_circle.Transparency = 1
fov_circle.Filled = false; fov_circle.NumSides = 64

local fov_circle_silent = Drawing.new("Circle")
fov_circle_silent.Visible = false; fov_circle_silent.Color = color_fov_silent
fov_circle_silent.Thickness = 2; fov_circle_silent.Transparency = 1
fov_circle_silent.Filled = false; fov_circle_silent.NumSides = 64

-- -------------------- Drawing helpers --------------------
local function remove_drawings(character)
    local data = esp_list[character]
    if not data then return end
    if data.tracer      then data.tracer:Remove()      end
    if data.health_bg   then data.health_bg:Remove()   end
    if data.health_fill then data.health_fill:Remove() end
    if data.name_text   then data.name_text:Remove()   end
end

local function hide_drawings(character)
    local data = esp_list[character]
    if not data then return end
    if data.tracer      then data.tracer.Visible      = false end
    if data.health_bg   then data.health_bg.Visible   = false end
    if data.health_fill then data.health_fill.Visible = false end
    if data.name_text   then data.name_text.Visible   = false end
end

local function remove_skeleton(character)
    local data = skeleton_list[character]
    if not data then return end
    for _, line in ipairs(data.lines) do line.l1:Remove(); line.l2:Remove() end
    if data.head_circle then data.head_circle:Remove() end
    skeleton_list[character] = nil
end

local function create_skeleton(character)
    if not character or skeleton_list[character] or not is_valid(character) then return end
    local char_bones = {}
    for _, name in ipairs(required_bones) do
        local b = character:FindFirstChild(name)
        if not b or not b:IsA("BasePart") then return end
        char_bones[name] = b
    end
    local lines = {}
    for i = 1, #bones do
        local l1 = Drawing.new("Line"); l1.Visible = false; l1.Color = color_skel_hid; l1.Thickness = 1; l1.Transparency = 1
        local l2 = Drawing.new("Line"); l2.Visible = false; l2.Color = color_skel_hid; l2.Thickness = 1; l2.Transparency = 1
        lines[i] = { l1 = l1, l2 = l2 }
    end
    local head_circle = Drawing.new("Circle")
    head_circle.Visible = false; head_circle.Color = color_skel_hid
    head_circle.Thickness = 1; head_circle.Transparency = 1
    head_circle.Filled = false; head_circle.NumSides = 24
    skeleton_list[character] = { lines = lines, bones = char_bones, head_circle = head_circle }
end

-- -------------------- ESP creation --------------------
local function create_esp(character)
    if not character or not is_valid(character) or esp_list[character] then return end
    local folder = Instance.new("Folder", screen_gui)
    local box    = Instance.new("Frame", folder)
    local stroke = Instance.new("UIStroke", box)
    box.BackgroundTransparency = 1; box.BorderSizePixel = 0
    stroke.Color = color_box; stroke.Thickness = 1

    local tracer = Drawing.new("Line")
    tracer.Visible = false; tracer.Color = color_tracer; tracer.Thickness = 1; tracer.Transparency = 1

    local health_bg = Drawing.new("Line")
    health_bg.Visible = false; health_bg.Color = Color3.fromRGB(40,40,40); health_bg.Thickness = 3; health_bg.Transparency = 0.5

    local health_fill = Drawing.new("Line")
    health_fill.Visible = false; health_fill.Color = Color3.fromRGB(0,255,0); health_fill.Thickness = 2; health_fill.Transparency = 1

    local name_text = Drawing.new("Text")
    name_text.Visible = false; name_text.Color = Color3.new(1,1,1); name_text.Size = 13
    name_text.Center = true; name_text.Outline = true; name_text.OutlineColor = Color3.new(0,0,0); name_text.Transparency = 1

    esp_list[character] = {
        folder = folder, box = box, stroke = stroke,
        tracer = tracer, health_bg = health_bg, health_fill = health_fill,
        name_text = name_text,
        player = resolve_player_for_viewmodel(character),
    }
end

-- -------------------- Health / Name helpers --------------------
local function get_health(character)
    local data = esp_list[character]
    if data and data.player and data.player.Character then
        local hum = data.player.Character:FindFirstChildOfClass("Humanoid")
        if hum then return hum.Health, hum.MaxHealth end
    end
    -- Fallback proximity (loose)
    local torso = character:FindFirstChild("torso")
    if not torso then return nil, nil end
    local pos = torso.Position
    local best_hum, best_d = nil, math.huge
    for _, p in ipairs(players:GetPlayers()) do
        if p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local d = (hrp.Position - pos).Magnitude
                if d < best_d then best_d = d; best_hum = hum end
            end
        end
    end
    if best_hum then return best_hum.Health, best_hum.MaxHealth end
    return nil, nil
end

local function get_player_name(character)
    local data = esp_list[character]
    -- Use cached player reference (robust  no distance-based guessing per frame)
    if data and data.player then
        return data.player.DisplayName or data.player.Name
    end
    -- Try to resolve lazily (e.g. player loaded after viewmodel appeared)
    local resolved = resolve_player_for_viewmodel(character)
    if resolved then
        if data then data.player = resolved end
        return resolved.DisplayName or resolved.Name
    end
    return "?"
end
