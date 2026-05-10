
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
_G.toggle_silent_aim = function()
	silent_aim_on = not silent_aim_on
	if _G.set_silent_aim then
		_G.set_silent_aim(silent_aim_on)
	end
end
_G.toggle_show_silent_fov = function()
	show_silent_aim_fov_circle = not show_silent_aim_fov_circle
	if _G.set_show_silent_fov then
		_G.set_show_silent_fov(show_silent_aim_fov_circle)
	end
end
_G.toggle_silent_fov_follow = function()
	silent_aim_fov_follow_cursor = not silent_aim_fov_follow_cursor
	if _G.set_silent_fov_follow then
		_G.set_silent_fov_follow(silent_aim_fov_follow_cursor)
	end
end
_G.toggle_silent_require_bind = function()
	silent_aim_require_bind = not silent_aim_require_bind
	if _G.set_silent_require_bind then
		_G.set_silent_require_bind(silent_aim_require_bind)
	end
end
_G.toggle_silent_vis_check = function()
	silent_aim_vis_check_on = not silent_aim_vis_check_on
	if _G.set_silent_vis_check then
		_G.set_silent_vis_check(silent_aim_vis_check_on)
	end
end
_G.toggle_silent_team_check = function()
	silent_aim_team_check_on = not silent_aim_team_check_on
	if _G.set_silent_team_check then
		_G.set_silent_team_check(silent_aim_team_check_on)
	end
end
_G.toggle_arrows_esp = function()
	arrows_esp_on = not arrows_esp_on
	if _G.set_arrows_esp then
		_G.set_arrows_esp(arrows_esp_on)
	end
end
_G.toggle_arrows_esp_distance = function()
	arrows_esp_distance_on = not arrows_esp_distance_on
	if _G.set_arrows_esp_distance then
		_G.set_arrows_esp_distance(arrows_esp_distance_on)
	end
end

-- Value setters (called by sliders)
_G.set_aim_fov_value        = function(v) aim_fov        = v end
_G.set_aim_speed_value      = function(v) aim_speed      = v end
_G.set_aim_key_value        = function(v) aim_key        = v end
_G.set_silent_aim_fov_value = function(v) silent_aim_fov = v end
_G.set_silent_aim_bind_value = function(v) silent_aim_bind = v end
_G.set_arrows_esp_ring_value = function(v)
	arrows_esp_ring_radius = math.clamp(v, 32, 220)
end
_G.get_silent_aim_part = function()
	return silent_aim_part
end
_G.set_silent_aim_part = function(name)
	silent_aim_part = Combat.parse_hit_part({ silent_aim_part = name }, "silent_aim_part", "HumanoidRootPart")
end

-- Color setters (called by color pickers & config loader)
local function refresh_esp_colors()
    fov_circle.Color        = color_fov_circle
    fov_circle_silent.Color = color_fov_silent
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
_G.set_color_fov_silent = function(c) color_fov_silent = c; refresh_esp_colors() end
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
        silent_aim_on = silent_aim_on,
        show_silent_aim_fov_circle = show_silent_aim_fov_circle,
        silent_aim_fov_follow_cursor = silent_aim_fov_follow_cursor,
        silent_aim_require_bind = silent_aim_require_bind,
        silent_aim_vis_check_on = silent_aim_vis_check_on,
        silent_aim_team_check_on = silent_aim_team_check_on,
        silent_aim_part = silent_aim_part,
        arrows_esp_on = arrows_esp_on,
        arrows_esp_distance_on = arrows_esp_distance_on,
        arrows_esp_ring_radius = arrows_esp_ring_radius,
        -- values
        aim_fov = aim_fov, aim_speed = aim_speed,
        silent_aim_fov = silent_aim_fov,
        -- keybinds (serialised as strings)
        aim_key        = enum_to_str(aim_key),
        silent_aim_bind = enum_to_str(silent_aim_bind),
        menu_key       = enum_to_str(menu_key),
        -- colors
        color_tracer     = color_to_t(color_tracer),
        color_box        = color_to_t(color_box),
        color_skel_vis   = color_to_t(color_skel_vis),
        color_skel_hid   = color_to_t(color_skel_hid),
        color_fov        = color_to_t(color_fov_circle),
        color_fov_silent = color_to_t(color_fov_silent),
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
    do
        local want_on = cfg.silent_aim_on
        if want_on == nil then want_on = cfg.silent_aim end
        if want_on ~= nil and want_on ~= silent_aim_on then _G.toggle_silent_aim() end
    end
    do
        local want_ring = cfg.show_silent_aim_fov_circle
        if want_ring == nil then want_ring = cfg.show_silent_fov_circle end
        if want_ring ~= nil and want_ring ~= show_silent_aim_fov_circle then _G.toggle_show_silent_fov() end
    end
    if cfg.silent_aim_fov_follow_cursor ~= nil and cfg.silent_aim_fov_follow_cursor ~= silent_aim_fov_follow_cursor then _G.toggle_silent_fov_follow() end
    if cfg.silent_aim_require_bind ~= nil and cfg.silent_aim_require_bind ~= silent_aim_require_bind then _G.toggle_silent_require_bind() end
    do
        local want_vis = cfg.silent_aim_vis_check_on
        if want_vis == nil then want_vis = cfg.silent_aim_vis_check end
        if want_vis ~= nil and want_vis ~= silent_aim_vis_check_on then _G.toggle_silent_vis_check() end
    end
    if cfg.silent_aim_team_check_on ~= nil and cfg.silent_aim_team_check_on ~= silent_aim_team_check_on then _G.toggle_silent_team_check() end
    if cfg.arrows_esp_on ~= nil and cfg.arrows_esp_on ~= arrows_esp_on then
		_G.toggle_arrows_esp()
	end
	if cfg.arrows_esp_distance_on ~= nil and cfg.arrows_esp_distance_on ~= arrows_esp_distance_on then
		_G.toggle_arrows_esp_distance()
	end

    -- Sliders
    if cfg.aim_fov       ~= nil then aim_fov       = cfg.aim_fov;       if _G.set_aim_fov       then _G.set_aim_fov(aim_fov)             end end
    if cfg.aim_speed     ~= nil then aim_speed     = cfg.aim_speed;     if _G.set_aim_speed     then _G.set_aim_speed(aim_speed)         end end
    if cfg.silent_aim_fov ~= nil then silent_aim_fov = cfg.silent_aim_fov; if _G.set_silent_aim_fov then _G.set_silent_aim_fov(silent_aim_fov) end end
	if cfg.arrows_esp_ring_radius ~= nil and _G.set_arrows_esp_ring_value then
		_G.set_arrows_esp_ring_value(cfg.arrows_esp_ring_radius)
		if _G.set_arrows_ring_slider then
			_G.set_arrows_ring_slider(arrows_esp_ring_radius)
		end
	end

    -- Keybinds
    local ak = str_to_enum(cfg.aim_key)
    if ak then aim_key  = ak; if _G.ui_set_aim_key  then _G.ui_set_aim_key(ak)   end end
    local sb = str_to_enum(cfg.silent_aim_bind)
    if sb then silent_aim_bind = sb; if _G.ui_set_silent_bind then _G.ui_set_silent_bind(sb) end end
    local mk = str_to_enum(cfg.menu_key)
    if mk == Enum.KeyCode.Insert then
        mk = Enum.KeyCode.RightShift
    end
    if mk then menu_key = mk; if _G.ui_set_menu_key then _G.ui_set_menu_key(mk)  end end
    if cfg.silent_aim_part ~= nil and type(cfg.silent_aim_part) == "string" and _G.set_silent_aim_part then
        _G.set_silent_aim_part(cfg.silent_aim_part)
        if _G.ui_refresh_silent_hitpart then _G.ui_refresh_silent_hitpart() end
    end

    -- Colors
    local function ac(key, setter)
        local c = t_to_color(cfg[key]); if c and setter then setter(c) end
    end
    ac("color_tracer",     _G.set_color_tracer)
    ac("color_box",        _G.set_color_box)
    ac("color_skel_vis",   _G.set_color_skel_vis)
    ac("color_skel_hid",   _G.set_color_skel_hid)
    ac("color_fov",        _G.set_color_fov)
    ac("color_fov_silent", _G.set_color_fov_silent)
    ac("color_throwable",  _G.set_color_throwable)
    ac("color_placeable",  _G.set_color_placeable)
end
