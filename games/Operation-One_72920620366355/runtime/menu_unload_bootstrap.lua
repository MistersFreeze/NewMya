
-- Menu toggle: matches KeyCode (default Delete) or mouse buttons from Misc → Menu bind.
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
	if _G.new_menu_key then
		menu_key = _G.new_menu_key
		_G.new_menu_key = nil
	end
	-- Allow menu key even when Roblox marks input as processed (chat/UI/game handlers).
	local allowProcessed = false
	if typeof(menu_key) == "EnumItem" then
		if menu_key.EnumType == Enum.KeyCode then
			allowProcessed = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == menu_key
		elseif menu_key.EnumType == Enum.UserInputType then
			allowProcessed = input.UserInputType == menu_key
		end
	end
	if processed and not allowProcessed then
		return
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
    fov_circle_silent:Remove()
    for character, data in pairs(esp_list) do
        remove_drawings(character); remove_skeleton(character)
        if data.folder then data.folder:Destroy() end
    end
    esp_list = {}; skeleton_list = {}
	pcall(function()
		if _G.clear_op1_esp_arrows then
			_G.clear_op1_esp_arrows()
		end
	end)
	_G.clear_op1_esp_arrows = nil
    for instance in pairs(gadget_data) do cleanup_gadget(instance) end
    gadget_data = {}
    apply_fullbright(false)
    if screen_gui        then screen_gui:Destroy()        end
    if _G.user_interface then _G.user_interface:Destroy() end
    _G.MYA_FLUENT_SINGLETON = nil
    _G.MYA_SILENT_AIM_HOOK_OK = nil
    for _, k in ipairs({
        "toggle_boxes","toggle_skeletons","toggle_tracers","toggle_healthbars","toggle_names",
        "toggle_gadgets","toggle_fullbright","toggle_aim_assist","toggle_show_fov",
        "toggle_silent_aim","toggle_show_silent_fov","toggle_silent_fov_follow",
        "toggle_silent_require_bind","toggle_silent_vis_check","toggle_silent_team_check",
        "toggle_vis_check","toggle_team_check","toggle_arrows_esp","toggle_arrows_esp_distance",
        "set_boxes","set_skeletons","set_tracers","set_healthbars","set_names","set_gadgets","set_team_check",
        "set_fullbright","set_aim_assist","set_show_fov",
        "set_silent_aim","set_show_silent_fov","set_silent_fov_follow",
        "set_silent_require_bind","set_silent_vis_check","set_silent_team_check","set_vis_check",
        "set_arrows_esp","set_arrows_esp_distance",
        "set_aim_fov","set_aim_speed","set_aim_fov_value","set_aim_speed_value","set_aim_key_value",
        "set_silent_aim_fov","set_silent_aim_fov_value","set_silent_aim_bind_value",
        "get_silent_aim_part","set_silent_aim_part",
        "ui_set_silent_bind","ui_refresh_silent_hitpart",
        "set_color_tracer","set_color_box","set_color_skel_vis","set_color_skel_hid",
        "set_color_fov","set_color_fov_silent","set_color_throwable","set_color_placeable",
        "set_arrows_esp_ring_value","set_arrows_ring_slider",
        "get_config","apply_config","new_menu_key","user_interface","unload_mya",
        "ui_set_aim_key","ui_set_menu_key","mya_notify",
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
        remove_skeleton(v)
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
