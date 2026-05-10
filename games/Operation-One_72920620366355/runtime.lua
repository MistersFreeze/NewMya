--[[
  Operation One — runtime entry.
  Prepends lib/mya_combat_helpers.lua as `Combat` (same as Mya Universal).
  Ordered fragments in runtime/ share one chunk scope.
]]
return function(env)
	local repoBase = env.repoBase
	if type(repoBase) ~= "string" or #repoBase == 0 then
		error("Operation One: repoBase missing — init must pass repoBase (hub ctx.baseUrl)")
	end
	local combatSrc = env.fetch(repoBase .. "lib/mya_combat_helpers.lua")
	if type(combatSrc) ~= "string" or #combatSrc == 0 then
		error("Operation One: missing lib/mya_combat_helpers.lua")
	end
	local combatFn, cErr = loadstring(combatSrc, "@lib/mya_combat_helpers")
	if typeof(combatFn) ~= "function" then
		error("Operation One: mya_combat_helpers compile failed: " .. tostring(cErr))
	end
	_G.MYA_COMBAT_HELPERS = combatFn()

	local order = {
		"runtime/state_visuals_helpers.lua",
		"runtime/globals_config.lua",
		"runtime/env_combat_movement.lua",
		"runtime/targeting_compat.lua",
		"runtime/esp_arrows.lua",
		"runtime/gadget_render.lua",
		"runtime/silent_aim.lua",
		"runtime/menu_unload_bootstrap.lua",
	}
	local buf = {
		"local Combat = _G.MYA_COMBAT_HELPERS\n",
	}
	for i = 1, #order do
		local rel = order[i]
		local src = env.fetch(env.base .. rel)
		if type(src) ~= "string" or #src == 0 then
			error("Operation One: missing or empty fragment: " .. rel)
		end
		buf[#buf + 1] = src
	end
	local fn, cerr = loadstring(table.concat(buf, "\n"), "@Operation-One/runtime_bundle")
	if typeof(fn) ~= "function" then
		error("Operation One: runtime bundle compile failed: " .. tostring(cerr))
	end
	fn()
	_G.MYA_COMBAT_HELPERS = nil
end
