-- bind_pressed + get_fov_screen_anchor (Mya Universal: targeting.lua + state_config.lua) — required by silent_aim.lua

local function bind_pressed(bind)
	if typeof(bind) ~= "EnumItem" then
		return false
	end
	if bind.EnumType == Enum.UserInputType then
		return UserInputService:IsMouseButtonPressed(bind)
	end
	if bind.EnumType == Enum.KeyCode then
		return UserInputService:IsKeyDown(bind)
	end
	return false
end

local function get_fov_screen_anchor(follow_cursor)
	if not camera then
		return Vector2.zero
	end
	local vp = camera.ViewportSize
	local center = Vector2.new(vp.X / 2, vp.Y / 2)
	if not follow_cursor then
		return center
	end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return center
	end
	return UserInputService:GetMouseLocation()
end
