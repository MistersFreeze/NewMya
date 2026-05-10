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
local chams           = false

local aim_fov         = 120        -- pixels radius
local aim_speed       = 0.25       -- 0.0 (slow) -> 0.99 (fast) -> 1.0 (instant snap)
local aim_key         = Enum.UserInputType.MouseButton2
local show_fov_circle = false
local vis_check       = false      -- false = track through walls, true = visible only

-- Customisable colors (overridable from UI/config)
local color_tracer     = Color3.new(1, 1, 1)
local color_box        = Color3.new(1, 1, 1)
local color_skel_vis   = Color3.fromRGB(0, 255, 0)
local color_skel_hid   = Color3.new(1, 1, 1)
local color_fov_circle = Color3.new(1, 1, 1)
local color_chams      = Color3.fromRGB(255, 50, 50)
local color_throwable  = Color3.fromRGB(255, 60, 60)
local color_placeable  = Color3.fromRGB(255, 170, 0)
local color_box_vis    = Color3.fromRGB(0, 255, 0)


--[[ begin main script ]]--

local menu_key = Enum.KeyCode.RightShift
local pad = 4

local cloneref_support = cloneref ~= nil
local gethui_support   = gethui ~= nil

local runservice   = cloneref_support and cloneref(game:GetService("RunService"))        or game:GetService("RunService")
local uis          = cloneref_support and cloneref(game:GetService("UserInputService"))  or game:GetService("UserInputService")
local players      = cloneref_support and cloneref(game:GetService("Players"))           or game:GetService("Players")
local collection   = cloneref_support and cloneref(game:GetService("CollectionService")) or game:GetService("CollectionService")
local lighting_svc = game:GetService("Lighting")

local local_player = players.LocalPlayer

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
local chams_list    = {}
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
fov_circle.Thickness = 1; fov_circle.Transparency = 1
fov_circle.Filled = false; fov_circle.NumSides = 64

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

-- -------------------- Chams --------------------
local function remove_chams(character)
    if chams_list[character] then
        chams_list[character]:Destroy()
        chams_list[character] = nil
    end
end

local function update_chams(character)
    if chams and not is_teammate(character) then
        if not chams_list[character] then
            local hl = Instance.new("Highlight")
            hl.FillColor           = color_chams
            hl.FillTransparency    = 0.35
            hl.OutlineColor        = color_chams
            hl.OutlineTransparency = 0.5
            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee             = character
            hl.Parent              = screen_gui
            chams_list[character]  = hl
        else
            chams_list[character].FillColor   = color_chams
            chams_list[character].OutlineColor = color_chams
        end
    else
        remove_chams(character)
    end
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

-- -------------------- Global toggles --------------------
_G.toggle_boxes      = function() boxes      = not boxes;      if _G.set_boxes      then _G.set_boxes(boxes)           end end
_G.toggle_skeletons  = function() skeletons  = not skeletons;  if _G.set_skeletons  then _G.set_skeletons(skeletons)   end end
_G.toggle_tracers    = function() tracers    = not tracers;    if _G.set_tracers    then _G.set_tracers(tracers)       end end
_G.toggle_healthbars = function() healthbars = not healthbars; if _G.set_healthbars then _G.set_healthbars(healthbars) end end
_G.toggle_names      = function() names      = not names;      if _G.set_names      then _G.set_names(names)           end end
_G.toggle_gadgets    = function() gadgets    = not gadgets;    if _G.set_gadgets    then _G.set_gadgets(gadgets)       end end
_G.toggle_team_check = function() team_check = not team_check; if _G.set_team_check then _G.set_team_check(team_check) end end
_G.toggle_fullbright = function()
    fullbright = not fullbright; apply_fullbright(fullbright)
    if _G.set_fullbright then _G.set_fullbright(fullbright) end
end
_G.toggle_aim_assist = function() aim_assist = not aim_assist; if _G.set_aim_assist then _G.set_aim_assist(aim_assist) end end
_G.toggle_show_fov   = function() show_fov_circle = not show_fov_circle; if _G.set_show_fov then _G.set_show_fov(show_fov_circle) end end
_G.toggle_vis_check  = function() vis_check = not vis_check; if _G.set_vis_check then _G.set_vis_check(vis_check) end end
_G.toggle_chams = function()
    chams = not chams
    if not chams then
        for char in pairs(chams_list) do remove_chams(char) end
    end
    if _G.set_chams then _G.set_chams(chams) end
end


-- Value setters (called by sliders)
_G.set_aim_fov_value        = function(v) aim_fov        = v end
_G.set_aim_speed_value      = function(v) aim_speed      = v end
_G.set_aim_key_value        = function(v) aim_key        = v end

-- Color setters (called by color pickers & config loader)
local function refresh_esp_colors()
    fov_circle.Color        = color_fov_circle
    for _, data in pairs(esp_list) do
        if data.stroke then data.stroke.Color = color_box    end
        if data.tracer then data.tracer.Color  = color_tracer end
    end
end

_G.set_color_tracer     = function(c) color_tracer     = c; refresh_esp_colors() end
_G.set_color_box        = function(c) color_box        = c; refresh_esp_colors() end
_G.set_color_skel_vis   = function(c) color_skel_vis   = c end
_G.set_color_skel_hid   = function(c) color_skel_hid   = c end
_G.set_color_fov        = function(c) color_fov_circle = c; refresh_esp_colors() end
_G.set_color_chams      = function(c)
    color_chams = c
    for _, hl in pairs(chams_list) do hl.FillColor = c; hl.OutlineColor = c end
end
_G.set_color_throwable  = function(c) color_throwable = c end
_G.set_color_placeable  = function(c) color_placeable = c end
_G.set_box_color_value        = _G.set_color_box
_G.set_skel_color_value       = _G.set_color_skel_vis
_G.set_tracer_color_value     = _G.set_color_tracer
_G.set_placeable_color_value  = _G.set_color_placeable
_G.set_throwable_color_value  = _G.set_color_throwable


-- -------------------- Config system --------------------
local function enum_to_str(e)
    if typeof(e) ~= "EnumItem" then return nil end
    return tostring(e):gsub("^Enum%.", "")
end
local function color_to_t(c)
    return { r = c.R, g = c.G, b = c.B }
end
local function t_to_color(t)
    if not t then return nil end
    return Color3.new(t.r or 1, t.g or 1, t.b or 1)
end
local function str_to_enum(s)
    if not s then return nil end
    local etype, ename = s:match("^(.+)%.(.+)$")
    if not etype or not ename then return nil end
    local ok, result = pcall(function() return Enum[etype][ename] end)
    return ok and result or nil
end

_G.get_config = function()
    return {
        -- toggles
        boxes = boxes, skeletons = skeletons, tracers = tracers, healthbars = healthbars,
        names = names, gadgets = gadgets, team_check = team_check,
        fullbright = fullbright, aim_assist = aim_assist, show_fov_circle = show_fov_circle,
        vis_check = vis_check,
        chams = chams,
        -- values
        aim_fov = aim_fov, aim_speed = aim_speed,
        -- keybinds (serialised as strings)
        aim_key        = enum_to_str(aim_key),
        menu_key       = enum_to_str(menu_key),
        -- colors
        color_tracer     = color_to_t(color_tracer),
        color_box        = color_to_t(color_box),
        color_skel_vis   = color_to_t(color_skel_vis),
        color_skel_hid   = color_to_t(color_skel_hid),
        color_fov        = color_to_t(color_fov_circle),
        color_chams      = color_to_t(color_chams),
        color_throwable  = color_to_t(color_throwable),
        color_placeable  = color_to_t(color_placeable),
    }
end


_G.apply_config = function(cfg)
    -- Toggles: only flip if state differs
    local function apply_toggle(key, cur_fn, toggle_fn)
        if cfg[key] ~= nil and cfg[key] ~= cur_fn() then toggle_fn() end
    end
    if cfg.boxes          ~= nil and cfg.boxes          ~= boxes          then _G.toggle_boxes()           end
    if cfg.skeletons      ~= nil and cfg.skeletons      ~= skeletons      then _G.toggle_skeletons()       end
    if cfg.tracers        ~= nil and cfg.tracers        ~= tracers        then _G.toggle_tracers()         end
    if cfg.healthbars     ~= nil and cfg.healthbars     ~= healthbars     then _G.toggle_healthbars()      end
    if cfg.names          ~= nil and cfg.names          ~= names          then _G.toggle_names()           end
    if cfg.gadgets        ~= nil and cfg.gadgets        ~= gadgets        then _G.toggle_gadgets()         end
    if cfg.team_check     ~= nil and cfg.team_check     ~= team_check     then _G.toggle_team_check()      end
    if cfg.fullbright     ~= nil and cfg.fullbright     ~= fullbright     then _G.toggle_fullbright()      end
    if cfg.aim_assist     ~= nil and cfg.aim_assist     ~= aim_assist     then _G.toggle_aim_assist()      end
    if cfg.show_fov_circle ~= nil and cfg.show_fov_circle ~= show_fov_circle then _G.toggle_show_fov()    end
    if cfg.vis_check      ~= nil and cfg.vis_check      ~= vis_check      then _G.toggle_vis_check()       end
    if cfg.chams          ~= nil and cfg.chams          ~= chams          then _G.toggle_chams()           end

    -- Sliders
    if cfg.aim_fov       ~= nil then aim_fov       = cfg.aim_fov;       if _G.set_aim_fov       then _G.set_aim_fov(aim_fov)             end end
    if cfg.aim_speed     ~= nil then aim_speed     = cfg.aim_speed;     if _G.set_aim_speed     then _G.set_aim_speed(aim_speed)         end end

    -- Keybinds
    local ak = str_to_enum(cfg.aim_key)
    if ak then aim_key  = ak; if _G.ui_set_aim_key  then _G.ui_set_aim_key(ak)   end end
    local mk = str_to_enum(cfg.menu_key)
    if mk == Enum.KeyCode.Insert then
        mk = Enum.KeyCode.RightShift
    end
    if mk then menu_key = mk; if _G.ui_set_menu_key then _G.ui_set_menu_key(mk)  end end

    -- Colors
    local function ac(key, setter)
        local c = t_to_color(cfg[key]); if c and setter then setter(c) end
    end
    ac("color_tracer",     _G.set_color_tracer)
    ac("color_box",        _G.set_color_box)
    ac("color_skel_vis",   _G.set_color_skel_vis)
    ac("color_skel_hid",   _G.set_color_skel_hid)
    ac("color_fov",        _G.set_color_fov)
    ac("color_chams",      _G.set_color_chams)
    ac("color_throwable",  _G.set_color_throwable)
    ac("color_placeable",  _G.set_color_placeable)
end


-- -------------------- Astro-style runtime setup (mirrors shared_runtime:applyToEnv) --------------------
do
    local env = (type(getgenv) == "function" and getgenv()) or _G
    env.dbg = env.dbg or (type(debug) == "table" and debug) or { info = function() return nil end }
    env.sstack = env.sstack or (type(setstack) == "function" and setstack) or (env.dbg and env.dbg.setstack) or function() end
    env.gstack = env.gstack or (type(getstack) == "function" and getstack) or (env.dbg and env.dbg.getstack) or function() return 0 end
end

warn("[Mya] Runtime: dbg=" .. type(dbg) .. " dbg.info=" .. type(dbg and dbg.info) .. " sstack=" .. type(sstack) .. " gstack=" .. type(gstack) .. " hookfn=" .. type(hookfunction) .. " clonefn=" .. type(clonefunction) .. " newcc=" .. type(newcclosure))

-- -------------------- Visibility check --------------------
local vis_params = RaycastParams.new()
vis_params.FilterType = Enum.RaycastFilterType.Exclude
vis_params.RespectCanCollide = true

local function check_visibility(cam_pos, target_pos, target_char)
    local dir    = target_pos - cam_pos
    local ignore = { camera }
    if local_player.Character then table.insert(ignore, local_player.Character) end
    if viewmodels              then table.insert(ignore, viewmodels)             end
    if target_char             then table.insert(ignore, target_char)            end
    vis_params.FilterDescendantsInstances = ignore
    for _ = 1, 8 do
        local hit = workspace:Raycast(cam_pos, dir, vis_params)
        if not hit then return true end
        local p = hit.Instance
        if p.Transparency > 0.2 or not p.CanCollide or p.Name == "HumanoidRootPart" then
            table.insert(ignore, p)
            vis_params.FilterDescendantsInstances = ignore
        else
            return false
        end
    end
    return false
end

-- UI loads from gui.lua (Mya hub init); sync runs after GUI builds _G.set_* hooks.
_G.MYA_OP1_RUN_UI_SYNC = function()
	task.defer(function()
		if _G.set_boxes then _G.set_boxes(boxes) end
		if _G.set_skeletons then _G.set_skeletons(skeletons) end
		if _G.set_tracers then _G.set_tracers(tracers) end
		if _G.set_healthbars then _G.set_healthbars(healthbars) end
		if _G.set_names then _G.set_names(names) end
		if _G.set_gadgets then _G.set_gadgets(gadgets) end
		if _G.set_team_check then _G.set_team_check(team_check) end
		if _G.set_fullbright then _G.set_fullbright(fullbright) end
		if _G.set_aim_assist then _G.set_aim_assist(aim_assist) end
		if _G.set_show_fov then _G.set_show_fov(show_fov_circle) end
		if _G.set_aim_fov then _G.set_aim_fov(aim_fov) end
		if _G.set_aim_speed then _G.set_aim_speed(aim_speed) end
		if _G.set_vis_check then _G.set_vis_check(vis_check) end
		if _G.set_chams then _G.set_chams(chams) end
	end)
end

-- -------------------- Gadget ESP helpers --------------------
local function get_gadget_color(category)
    return category == "throwable" and color_throwable or color_placeable
end

local function create_gadget_entry(instance, display_name, category)
    if gadget_data[instance] then return gadget_data[instance] end
    local color = get_gadget_color(category)
    local text = Drawing.new("Text")
    text.Visible = false; text.Color = color; text.Size = 13; text.Center = true
    text.Outline = true; text.OutlineColor = Color3.new(0,0,0); text.Transparency = 1; text.Text = display_name

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency    = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor        = color
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee             = instance
    highlight.Parent              = screen_gui

    gadget_data[instance] = { text = text, highlight = highlight, category = category }
    return gadget_data[instance]
end

local function cleanup_gadget(instance)
    local data = gadget_data[instance]
    if data then data.text:Remove(); data.highlight:Destroy(); gadget_data[instance] = nil end
end

-- -------------------- Main render loop --------------------
connections[#connections+1] = runservice.RenderStepped:Connect(function()
    if unloaded then return end

    if _G.new_menu_key then menu_key = _G.new_menu_key; _G.new_menu_key = nil end

    -- FOV circles
    if show_fov_circle then
        local vp = camera.ViewportSize
        fov_circle.Position = Vector2.new(vp.X/2, vp.Y/2)
        fov_circle.Radius   = aim_fov
        fov_circle.Color    = color_fov_circle
        fov_circle.Visible  = true
    else
        fov_circle.Visible = false
    end

    -- -- Aim Assist --
    if aim_assist then
        local pressing = false
        if typeof(aim_key) == "EnumItem" then
            if aim_key.EnumType == Enum.UserInputType then
                pressing = uis:IsMouseButtonPressed(aim_key)
            else
                pressing = uis:IsKeyDown(aim_key)
            end
        end

        if pressing then
            local vp       = camera.ViewportSize
            local center   = Vector2.new(vp.X/2, vp.Y/2)
            local cam_pos  = camera.CFrame.Position
            local best_pos, best_dist = nil, math.huge

            for character in pairs(esp_list) do
                if not is_valid(character) or is_teammate(character) then continue end
                local skel = skeleton_list[character]
                if not skel then continue end

                for _, bone_name in ipairs(aim_bone_priority) do
                    local bone = skel.bones[bone_name]
                    if not bone then continue end
                    local vp_pos, on_screen = camera:WorldToViewportPoint(bone.Position)
                    if not on_screen or vp_pos.Z <= 0 then continue end
                    local screen_pos = Vector2.new(vp_pos.X, vp_pos.Y)
                    local dist = (screen_pos - center).Magnitude
                    if dist > aim_fov then continue end
                    -- vis_check ON -> walk bone priority until a visible one is found
                    -- vis_check OFF -> take first on-screen bone immediately (head priority)
                    if vis_check then
                        if check_visibility(cam_pos, bone.Position, character) then
                            if dist < best_dist then best_dist = dist; best_pos = screen_pos end
                            break
                        end
                        -- bone occluded: keep iterating to next priority bone
                    else
                        if dist < best_dist then best_dist = dist; best_pos = screen_pos end
                        break
                    end
                end
            end

            if best_pos then
                local dx = best_pos.X - center.X
                local dy = best_pos.Y - center.Y
                
                -- Cubic scaling for smoothness: makes lower range (1-10%) extremely smooth
                local actual_speed = math.pow(aim_speed, 3)
                
                if aim_speed >= 1.0 then
                    mousemoverel(dx, dy)
                    aim_remainder_x, aim_remainder_y = 0, 0
                else
                    -- Precision precision: accumulate small movements to prevent stopping short
                    aim_remainder_x = aim_remainder_x + (dx * actual_speed)
                    aim_remainder_y = aim_remainder_y + (dy * actual_speed)
                    
                    local move_x = math.round(aim_remainder_x)
                    local move_y = math.round(aim_remainder_y)
                    
                    if move_x ~= 0 or move_y ~= 0 then
                        mousemoverel(move_x, move_y)
                        aim_remainder_x = aim_remainder_x - move_x
                        aim_remainder_y = aim_remainder_y - move_y
                    end
                end
            else
                aim_remainder_x, aim_remainder_y = 0, 0
            end
        else
            aim_remainder_x, aim_remainder_y = 0, 0
        end
    end


    -- -- Player ESP --
    for character, data in pairs(esp_list) do
        local box    = data.box
        local folder = data.folder

        if not character or not character.Parent or not is_valid(character) then
            box.Visible = false; hide_drawings(character); remove_drawings(character)
            folder:Destroy(); esp_list[character] = nil
            remove_skeleton(character); remove_chams(character)
            continue
        end

        local torso = character:FindFirstChild("torso")
        if not torso or torso.Transparency >= 1 or is_teammate(character) then
            box.Visible = false; hide_drawings(character); remove_chams(character)
            local skel = skeleton_list[character]
            if skel then
                for _, line in ipairs(skel.lines) do line.l1.Visible = false; line.l2.Visible = false end
                if skel.head_circle then skel.head_circle.Visible = false end
            end
            continue
        end

        update_chams(character)

        if not skeleton_list[character] and aim_assist then
            create_skeleton(character)
        end

        local _, on_screen = camera:WorldToScreenPoint(torso.Position)

        if on_screen and (camera.CFrame.Position - torso.Position).Magnitude <= 3571.4 then
            local needs_bones = boxes or skeletons or tracers or healthbars or names

            if needs_bones then
                if not skeleton_list[character] then create_skeleton(character) end
                local skel = skeleton_list[character]
                if skel then

                local min_x, min_y   = math.huge,  math.huge
                local max_x, max_y   = -math.huge, -math.huge
                local vp_min_x, vp_min_y = math.huge,  math.huge
                local vp_max_x, vp_max_y = -math.huge, -math.huge
                local head_vp_x, head_vp_y, head_on = 0, 0, false

                local cam_pos = camera.CFrame.Position
                local bone_vis = {}
                if skeletons then
                    for _, bname in ipairs(required_bones) do
                        local b = skel.bones[bname]
                        if b then bone_vis[bname] = check_visibility(cam_pos, b.Position, character) end
                    end
                end

                -- Torso visibility drives box/tracer color (visibility-linked ESP)
                local target_vis = check_visibility(cam_pos, torso.Position, character)

                for i, conn in ipairs(bones) do
                    local b1 = skel.bones[conn[1]]; local b2 = skel.bones[conn[2]]
                    if b1 and b2 then
                        local p1, on1 = camera:WorldToViewportPoint(b1.Position)
                        local p2, on2 = camera:WorldToViewportPoint(b2.Position)
                        local s1, son1 = camera:WorldToScreenPoint(b1.Position)
                        local s2, son2 = camera:WorldToScreenPoint(b2.Position)

                        if son1 then min_x=math.min(min_x,s1.X); max_x=math.max(max_x,s1.X); min_y=math.min(min_y,s1.Y); max_y=math.max(max_y,s1.Y) end
                        if son2 then min_x=math.min(min_x,s2.X); max_x=math.max(max_x,s2.X); min_y=math.min(min_y,s2.Y); max_y=math.max(max_y,s2.Y) end
                        if on1 then vp_min_x=math.min(vp_min_x,p1.X); vp_max_x=math.max(vp_max_x,p1.X); vp_min_y=math.min(vp_min_y,p1.Y); vp_max_y=math.max(vp_max_y,p1.Y) end
                        if on2 then vp_min_x=math.min(vp_min_x,p2.X); vp_max_x=math.max(vp_max_x,p2.X); vp_min_y=math.min(vp_min_y,p2.Y); vp_max_y=math.max(vp_max_y,p2.Y) end
                        if conn[2] == "head" and on2 then head_vp_x, head_vp_y, head_on = p2.X, p2.Y, true end

                        if skeletons and on1 and on2 then
                            local pm = Vector2.new((p1.X+p2.X)/2, (p1.Y+p2.Y)/2)
                            skel.lines[i].l1.From  = Vector2.new(p1.X, p1.Y); skel.lines[i].l1.To = pm
                            skel.lines[i].l2.From  = pm;                       skel.lines[i].l2.To = Vector2.new(p2.X, p2.Y)
                            skel.lines[i].l1.Color = (bone_vis[conn[1]]) and color_skel_vis or color_skel_hid
                            skel.lines[i].l2.Color = (bone_vis[conn[2]]) and color_skel_vis or color_skel_hid
                            skel.lines[i].l1.Visible = true; skel.lines[i].l2.Visible = true
                        else
                            skel.lines[i].l1.Visible = false; skel.lines[i].l2.Visible = false
                        end
                    else
                        skel.lines[i].l1.Visible = false; skel.lines[i].l2.Visible = false
                    end
                end

                -- Head circle
                if skeletons and head_on then
                    local hb  = skel.bones["head"]
                    local top = camera:WorldToViewportPoint(hb.Position + Vector3.new(0,0.5,0))
                    local rad = math.max(math.abs(head_vp_y - top.Y), 4)
                    skel.head_circle.Position = Vector2.new(head_vp_x, head_vp_y)
                    skel.head_circle.Radius   = rad
                    skel.head_circle.Color    = bone_vis["head"] and color_skel_vis or color_skel_hid
                    skel.head_circle.Visible  = true
                else
                    skel.head_circle.Visible = false
                end

                local has_sc = min_x    ~= math.huge
                local has_vp = vp_min_x ~= math.huge

                local vp_left     = vp_min_x - pad
                local vp_bottom   = vp_max_y + pad
                local vp_top      = vp_min_y - pad
                local vp_center_x = (vp_min_x + vp_max_x) / 2

                -- Box  visibility-linked: green when visible, user color when hidden
                if boxes and has_sc then
                    data.stroke.Color = target_vis and color_box_vis or color_box
                    box.Visible  = true
                    box.Position = UDim2.fromOffset(min_x-pad, min_y-pad)

                    box.Size     = UDim2.fromOffset(max_x-min_x+pad*2, max_y-min_y+pad*2)
                else
                    box.Visible = false
                end

                -- Tracer
                if tracers and has_vp then
                    local vps = camera.ViewportSize
                    data.tracer.Color   = color_tracer
                    data.tracer.From    = Vector2.new(vps.X/2, vps.Y)
                    data.tracer.To      = Vector2.new(vp_center_x, vp_bottom)
                    data.tracer.Visible = true
                else
                    data.tracer.Visible = false
                end

                -- Health bar
                if healthbars and has_vp then
                    local hp, max_hp = get_health(character)
                    if hp and max_hp and max_hp > 0 then
                        local hb  = skel.bones["head"]; local l1b = skel.bones["leg1"]; local l2b = skel.bones["leg2"]; local tb = skel.bones["torso"]
                        local top_vp = camera:WorldToViewportPoint(hb.Position + Vector3.new(0,0.35,0))
                        local bot_vp = camera:WorldToViewportPoint((l1b.Position+l2b.Position)*0.5 - Vector3.new(0,0.4,0))
                        local tz     = camera:WorldToViewportPoint(tb.Position).Z
                        if tz>0 and top_vp.Z>0 and bot_vp.Z>0 then
                            local by_top = math.min(top_vp.Y, bot_vp.Y); local by_bot = math.max(top_vp.Y, bot_vp.Y)
                            local bh = by_bot - by_top
                            if bh > 1 then
                                local bx = vp_left - 4; local pct = math.clamp(hp/max_hp,0,1)
                                data.health_bg.From=Vector2.new(bx,by_top); data.health_bg.To=Vector2.new(bx,by_bot); data.health_bg.Visible=true
                                data.health_fill.From=Vector2.new(bx,by_bot-bh*pct); data.health_fill.To=Vector2.new(bx,by_bot)
                                data.health_fill.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0); data.health_fill.Visible=true
                            else
                                data.health_bg.Visible=false; data.health_fill.Visible=false
                            end
                        else
                            data.health_bg.Visible=false; data.health_fill.Visible=false
                        end
                    else
                        data.health_bg.Visible=false; data.health_fill.Visible=false
                    end
                else
                    data.health_bg.Visible=false; data.health_fill.Visible=false
                end

                -- Names
                if names and has_vp then
                    data.name_text.Text     = get_player_name(character)
                    data.name_text.Position = Vector2.new(vp_center_x, vp_top - 16)
                    data.name_text.Visible  = true
                else
                    data.name_text.Visible = false
                end

                end -- if skel
            else
                remove_skeleton(character); box.Visible=false
                data.tracer.Visible=false; data.health_bg.Visible=false; data.health_fill.Visible=false; data.name_text.Visible=false
            end
        else
            box.Visible=false; hide_drawings(character); remove_skeleton(character)
        end
    end

    -- -- Gadget ESP --
    if gadgets then
        local seen = {}
        for _, info in ipairs(all_gadget_tags) do
            local ok, tagged = pcall(collection.GetTagged, collection, info.tag)
            if not ok then continue end
            for _, instance in ipairs(tagged) do
                if instance.Parent and instance:IsDescendantOf(workspace)
                    and not is_friendly_gadget(instance)
                    and not (info.tag == "DefaultCamera" and is_camera_broken(instance))
                then
                    seen[instance] = true
                    local root = instance:FindFirstChild("Root")
                    local part = root or (instance:IsA("BasePart") and instance) or instance:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local _, s_on = camera:WorldToScreenPoint(part.Position)
                        if s_on and (camera.CFrame.Position - part.Position).Magnitude <= 3571.4 then
                            local gdata    = create_gadget_entry(instance, info.name, info.category)
                            local cur_col  = get_gadget_color(info.category)
                            gdata.text.Color            = cur_col
                            gdata.highlight.OutlineColor = cur_col
                            local v_pos = camera:WorldToViewportPoint(part.Position)
                            gdata.text.Position = Vector2.new(v_pos.X, v_pos.Y - 20)
                            gdata.text.Visible  = true
                            gdata.highlight.Enabled = true
                        else
                            local gdata = gadget_data[instance]
                            if gdata then gdata.text.Visible=false; gdata.highlight.Enabled=false end
                        end
                    end
                end
            end
        end
        for instance in pairs(gadget_data) do
            if not seen[instance] then cleanup_gadget(instance) end
        end
    else
        for instance in pairs(gadget_data) do cleanup_gadget(instance) end
        gadget_data = {}
    end
end)

-- Menu toggle: KeyCode (default Delete) or mouse from Misc → Menu bind.
local function input_matches_menu_bind(inp, bind)
	if typeof(bind) ~= "EnumItem" then
		return false
	end
	if bind.EnumType == Enum.KeyCode then
		if bind == Enum.KeyCode.Unknown then
			return false
		end
		return inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == bind
	end
	if bind.EnumType == Enum.UserInputType then
		return inp.UserInputType == bind
	end
	return false
end

connections[#connections+1] = uis.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if _G.new_menu_key then
		menu_key = _G.new_menu_key
		_G.new_menu_key = nil
	end
	if not input_matches_menu_bind(input, menu_key) then
		return
	end
	local menu_ui = _G.user_interface
	if menu_ui then
		menu_ui.Enabled = not menu_ui.Enabled
	end
end)

-- -------------------- Unload --------------------
_G.unload_mya = function()
    unloaded = true
    for _, conn in ipairs(connections) do if conn and conn.Connected then conn:Disconnect() end end
    connections = {}
    fov_circle:Remove()
    for character, data in pairs(esp_list) do
        remove_drawings(character); remove_skeleton(character); remove_chams(character)
        if data.folder then data.folder:Destroy() end
    end
    esp_list = {}; skeleton_list = {}; chams_list = {}
    for instance in pairs(gadget_data) do cleanup_gadget(instance) end
    gadget_data = {}
    apply_fullbright(false)
    if screen_gui        then screen_gui:Destroy()        end
    if _G.user_interface then _G.user_interface:Destroy() end
    for _, k in ipairs({
        "toggle_boxes","toggle_skeletons","toggle_tracers","toggle_healthbars","toggle_names",
        "toggle_gadgets","toggle_fullbright","toggle_aim_assist","toggle_show_fov",
        "toggle_vis_check","toggle_chams","toggle_team_check",
        "set_boxes","set_skeletons","set_tracers","set_healthbars","set_names","set_gadgets","set_team_check",
        "set_fullbright","set_aim_assist","set_show_fov","set_vis_check",
        "set_chams",
        "set_aim_fov","set_aim_speed","set_aim_fov_value","set_aim_speed_value","set_aim_key_value",
        "set_color_tracer","set_color_box","set_color_skel_vis","set_color_skel_hid",
        "set_color_fov","set_color_chams","set_color_throwable","set_color_placeable",
        "get_config","apply_config","new_menu_key","user_interface","unload_mya",
        "ui_set_aim_key","ui_set_menu_key",
    }) do _G[k] = nil end
end

-- -------------------- Entry --------------------
if viewmodels then
    for _, v in ipairs(viewmodels:GetChildren()) do
        if v:IsA("Model") then task.delay(0.1, create_esp, v) end
    end
    connections[#connections+1] = viewmodels.ChildAdded:Connect(function(v)
        if not v:IsA("Model") then return end
        task.delay(0.2, create_esp, v)
        task.delay(1.0, create_esp, v)
        task.delay(3.0, create_esp, v)
    end)
    connections[#connections+1] = viewmodels.ChildRemoved:Connect(function(v)
        if esp_list[v] then remove_drawings(v); esp_list[v].folder:Destroy(); esp_list[v] = nil end
        remove_skeleton(v); remove_chams(v)
    end)

    connections[#connections+1] = runservice.Heartbeat:Connect(function()
        if unloaded then return end
        for _, v in ipairs(viewmodels:GetChildren()) do
            if v:IsA("Model") and not esp_list[v] then
                create_esp(v)
            end
        end
    end)
end

-- -------------------- Anti-Smoke / Anti-Flash --------------------
-- Anti-Flash (always direct — simple property toggle)
pcall(function()
    local_player.PlayerGui.Flash.Enabled = false
end)
connections[#connections+1] = local_player.PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "Flash" then pcall(function() child.Enabled = false end) end
end)

-- Anti-Smoke
do
    local anti_smoke_src = [[
local cloneref = cloneref or function(obj) return obj end
local newcclosure = newcclosure or function(fn) return fn end
local hookfunction = hookfunction or function(fn, replacement) return fn end
local workspace = cloneref(game:GetService("Workspace"))
local tinySize = Vector3.new(0.001, 0.001, 0.001)

local hiddenParts = setmetatable({}, { __mode = "k" })
local handledSmoke = setmetatable({}, { __mode = "k" })

local originalGetPropertyChangedSignal
originalGetPropertyChangedSignal = hookfunction(
    game.GetPropertyChangedSignal,
    newcclosure(function(self, property)
        if hiddenParts[self] and (
            property == "Size" or
            property == "Transparency" or
            property == "LocalTransparencyModifier" or
            property == "Color"
        ) then
            return Instance.new("BindableEvent").Event
        end
        return originalGetPropertyChangedSignal(self, property)
    end)
)

local function hidePart(part)
    hiddenParts[part] = true
    part.LocalTransparencyModifier = 1
    part.Size = tinySize
end

local function processSmokeObject(obj)
    if handledSmoke[obj] then return end
    handledSmoke[obj] = true
    pcall(function()
        if obj:IsA("BasePart") then hidePart(obj) end
        for _, item in ipairs(obj:GetDescendants()) do
            if item:IsA("BasePart") then
                hidePart(item)
            elseif item:IsA("ParticleEmitter") or item:IsA("Smoke") then
                item.Enabled = false
            end
        end
    end)
end

for _, child in ipairs(workspace:GetChildren()) do
    if child.Name == "SmokePart" then processSmokeObject(child) end
end
workspace.ChildAdded:Connect(newcclosure(function(child)
    if child.Name == "SmokePart" then processSmokeObject(child) end
end))
]]

    local actor_ok = pcall(function()
        if type(run_on_actor) ~= "function" or type(getactors) ~= "function" then error("no actor api") end
        local actors = getactors()
        if not actors or not actors[1] then error("no actors") end
        run_on_actor(actors[1], anti_smoke_src)
    end)
    if not actor_ok then
        pcall(function() loadstring(anti_smoke_src)() end)
    end
end
