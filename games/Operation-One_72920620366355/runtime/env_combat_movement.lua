

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
	local dir = target_pos - cam_pos
	local ignore = { camera }
	if local_player.Character then
		table.insert(ignore, local_player.Character)
	end
	if viewmodels then
		table.insert(ignore, viewmodels)
	end
	if target_char then
		table.insert(ignore, target_char)
	end
	vis_params.FilterDescendantsInstances = ignore
	for _ = 1, 8 do
		local hit = workspace:Raycast(cam_pos, dir, vis_params)
		if not hit then
			return true
		end
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
		if _G.set_boxes then
			_G.set_boxes(boxes)
		end
		if _G.set_skeletons then
			_G.set_skeletons(skeletons)
		end
		if _G.set_tracers then
			_G.set_tracers(tracers)
		end
		if _G.set_healthbars then
			_G.set_healthbars(healthbars)
		end
		if _G.set_names then
			_G.set_names(names)
		end
		if _G.set_gadgets then
			_G.set_gadgets(gadgets)
		end
		if _G.set_team_check then
			_G.set_team_check(team_check)
		end
		if _G.set_fullbright then
			_G.set_fullbright(fullbright)
		end
		if _G.set_aim_assist then
			_G.set_aim_assist(aim_assist)
		end
		if _G.set_show_fov then
			_G.set_show_fov(show_fov_circle)
		end
		if _G.set_silent_aim then
			_G.set_silent_aim(silent_aim_on)
		end
		if _G.set_show_silent_fov then
			_G.set_show_silent_fov(show_silent_aim_fov_circle)
		end
		if _G.set_silent_fov_follow then
			_G.set_silent_fov_follow(silent_aim_fov_follow_cursor)
		end
		if _G.set_silent_require_bind then
			_G.set_silent_require_bind(silent_aim_require_bind)
		end
		if _G.set_silent_vis_check then
			_G.set_silent_vis_check(silent_aim_vis_check_on)
		end
		if _G.set_silent_team_check then
			_G.set_silent_team_check(silent_aim_team_check_on)
		end
		if _G.ui_refresh_silent_hitpart then
			_G.ui_refresh_silent_hitpart()
		end
		if _G.set_aim_fov then
			_G.set_aim_fov(aim_fov)
		end
		if _G.set_silent_aim_fov then
			_G.set_silent_aim_fov(silent_aim_fov)
		end
		if _G.set_aim_speed then
			_G.set_aim_speed(aim_speed)
		end
		if _G.set_vis_check then
			_G.set_vis_check(vis_check)
		end
		if _G.set_arrows_esp then
			_G.set_arrows_esp(arrows_esp_on)
		end
		if _G.set_arrows_esp_distance then
			_G.set_arrows_esp_distance(arrows_esp_distance_on)
		end
		if _G.set_arrows_ring_slider then
			_G.set_arrows_ring_slider(arrows_esp_ring_radius)
		end
		if _G.ui_set_menu_key then
			_G.ui_set_menu_key(menu_key)
		end
	end)
end
