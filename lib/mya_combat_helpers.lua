--[[
  Reusable combat/targeting helpers (team filter, LOS raycasts, hit-part names).
  Stateless: pass all services/instances in. Safe to HttpGet from any executor script.

  Mya Universal bundles this via runtime.lua; other games can load the same file from
  MYA_REPO_BASE .. "lib/mya_combat_helpers.lua".
]]
local M = {}

M.HIT_PART_NAMES = {
	Head = true,
	HumanoidRootPart = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
}

function M.parse_hit_part(configTable, key, defaultName)
	local s = configTable and configTable[key]
	if type(s) ~= "string" or not M.HIT_PART_NAMES[s] then
		return defaultName
	end
	return s
end

--- When `enabled` is false, returns false (caller treats as "not teammate" = do not skip target).
function M.same_team(localPlayer, otherPlayer, teamCheckEnabled)
	if not teamCheckEnabled then
		return false
	end
	local t0, t1 = localPlayer.Team, otherPlayer.Team
	if not t0 or not t1 then
		return false
	end
	return t0 == t1
end

--- LOS using Workspace:Raycast + Exclude filter (character + camera). Same idea as classic silent-aim LOS.
function M.los_visible_exclude(origin, targetPart, lpCharacter, cameraInstance, workspaceRef)
	workspaceRef = workspaceRef or workspace
	if not lpCharacter or not targetPart or not targetPart.Parent then
		return false
	end
	local direction = targetPart.Position - origin
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { lpCharacter, cameraInstance }
	rp.IgnoreWater = true
	local result = workspaceRef:Raycast(origin, direction, rp)
	if result then
		return result.Instance:IsDescendantOf(targetPart.Parent)
	end
	return true
end

--- LOS using existing RaycastParams (e.g. blacklist). Used by aim assist / ESP camera checks.
function M.los_visible_blacklist(workspaceRef, fromPos, targetChar, targetPoint, raycastParams)
	if not targetChar then
		return false
	end
	local dir = targetPoint - fromPos
	local dist = dir.Magnitude
	if dist < 0.05 then
		return true
	end
	local ok, result = pcall(function()
		return workspaceRef:Raycast(fromPos, dir.Unit * (dist - 0.02), raycastParams)
	end)
	if not ok or not result then
		return true
	end
	return result.Instance:IsDescendantOf(targetChar)
end

return M
