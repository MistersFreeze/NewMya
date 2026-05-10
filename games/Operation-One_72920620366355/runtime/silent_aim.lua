--[[
  Silent aim: __namecall hook + Heartbeat (Mya Universal–aligned).
  - Bind state only on Heartbeat (never UserInputService inside __namecall).
  - workspace __namecall first, then game fallback; re-entrancy depth; Vector3 + degenerate guards.
  - Clear closest_silent_part before getclosest so LOS Raycasts inside Combat.los_visible_exclude are not redirected.
  - Team skip: teammate Highlight.Adornee == enemy Character (OP1), else Roblox Team via Combat.same_team.
]]

local closest_silent_part = nil
local silent_aim_bind_down = false

local function silent_aim_skip_player(player)
	if not silent_aim_team_check_on then
		return false
	end
	local char = player.Character
	if not char then
		return true
	end
	for h in pairs(teammate_highlights) do
		if h.Adornee == char then
			return true
		end
	end
	return Combat.same_team(lp, player, true)
end

local function silent_aim_getclosest()
	local closestpart = nil
	local closestdistance = math.huge
	local fov_px = silent_aim_fov
	local anchor = get_fov_screen_anchor(silent_aim_fov_follow_cursor)

	for _, player in pairs(Players:GetPlayers()) do
		if player ~= lp and player.Character then
			if silent_aim_skip_player(player) then
				continue
			end
			local targetPart = player.Character:FindFirstChild(silent_aim_part)
			if not targetPart or not targetPart:IsA("BasePart") then
				-- R6 / alt rigs
				if silent_aim_part == "HumanoidRootPart" then
					targetPart = player.Character:FindFirstChild("Torso")
				end
			end
			local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
			if targetPart and targetPart:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local screenpos, onscreen = camera:WorldToViewportPoint(targetPart.Position)
				if onscreen then
					local mousepos = anchor
					local distance = (Vector2.new(screenpos.X, screenpos.Y) - mousepos).Magnitude
					if distance <= fov_px then
						local los_ok = true
						if silent_aim_vis_check_on then
							local ch = lp.Character
							if not ch then
								los_ok = false
							else
								los_ok = Combat.los_visible_exclude(
									camera.CFrame.Position,
									targetPart,
									ch,
									camera,
									workspace
								)
							end
						end
						if los_ok and distance < closestdistance then
							closestdistance = distance
							closestpart = targetPart
						end
					end
				end
			end
		end
	end
	return closestpart
end

local function raycast_redirect_ok()
	return typeof(hookmetamethod) == "function"
		and typeof(getnamecallmethod) == "function"
		and typeof(newcclosure) == "function"
end

local silent_aim_hook_installed = false
local silent_nc_depth = 0

if raycast_redirect_ok() then
	local ok_hook, _err = pcall(function()
		local oldnamecall
		local closure = newcclosure(function(...)
			silent_nc_depth = silent_nc_depth + 1
			if silent_nc_depth > 1 then
				local r = table.pack(oldnamecall(...))
				silent_nc_depth = silent_nc_depth - 1
				return table.unpack(r, 1, r.n)
			end
			local method, arguments = getnamecallmethod(), { ... }
			local self = arguments[1]
			if silent_aim_on and self == workspace and not checkcaller() and method == "Raycast" then
				if typeof(arguments[2]) == "Vector3" and typeof(arguments[3]) == "Vector3" then
					if not silent_aim_require_bind or silent_aim_bind_down then
						local hitpart = closest_silent_part
						if hitpart and hitpart:IsA("BasePart") and hitpart.Parent then
							local origin = arguments[2]
							local delta = hitpart.Position - origin
							local mag = delta.Magnitude
							if mag == mag and mag > 1e-3 then
								arguments[2] = origin
								arguments[3] = delta.Unit * 1000
								local r = table.pack(oldnamecall(unpack(arguments)))
								silent_nc_depth = silent_nc_depth - 1
								return table.unpack(r, 1, r.n)
							end
						end
					end
				end
			end
			local r = table.pack(oldnamecall(...))
			silent_nc_depth = silent_nc_depth - 1
			return table.unpack(r, 1, r.n)
		end)

		local wsOk = pcall(function()
			oldnamecall = hookmetamethod(workspace, "__namecall", closure)
		end)
		if not wsOk or typeof(oldnamecall) ~= "function" then
			oldnamecall = hookmetamethod(game, "__namecall", closure)
		end
	end)
	silent_aim_hook_installed = ok_hook
end

table.insert(
	connections,
	RunService.Heartbeat:Connect(function()
		if silent_aim_on and silent_aim_require_bind then
			silent_aim_bind_down = bind_pressed(silent_aim_bind)
		else
			silent_aim_bind_down = true
		end
		-- Must be nil while getclosest runs (LOS uses Workspace:Raycast; hook must not rewrite those rays).
		closest_silent_part = nil
		if not silent_aim_on then
			return
		end
		if silent_aim_require_bind and not silent_aim_bind_down then
			return
		end
		closest_silent_part = silent_aim_getclosest()
	end)
)

_G.MYA_SILENT_AIM_HOOK_OK = silent_aim_hook_installed
