return function(ctx)
	local miscTab    = ctx.miscTab
	local Workspace  = ctx.Workspace
	local RunService = ctx.RunService

	local Lighting      = game:GetService("Lighting")
	local UserSettings  = UserSettings
	local settings      = settings

	local potatoEnabled  = false
	local _conns         = {}

	-- Snapshots
	local _lightingProps  = {}   -- { GlobalShadows, FogEnd, Brightness, etc. }
	local _postEffects    = {}   -- [Instance] = originalEnabled
	local _particles      = {}   -- [Instance] = originalEnabled
	local _decals         = {}   -- [Instance] = originalTransparency

	local POST_TYPES = {
		"BloomEffect", "BlurEffect", "ColorCorrectionEffect",
		"DepthOfFieldEffect", "SunRaysEffect", "FilmGrainEffect",
	}

	local PARTICLE_TYPES = { "ParticleEmitter", "Fire", "Smoke", "Sparkles" }

	-- ── Helpers ───────────────────────────────────────────────────────────────────

	local function snapshotAndSet(tbl, obj, prop, newVal)
		if tbl[prop] == nil then tbl[prop] = obj[prop] end
		pcall(function() obj[prop] = newVal end)
	end

	local function disablePostFX()
		for _, child in ipairs(Lighting:GetChildren()) do
			for _, t in ipairs(POST_TYPES) do
				if child:IsA(t) then
					if _postEffects[child] == nil then _postEffects[child] = child.Enabled end
					pcall(function() child.Enabled = false end)
					break
				end
			end
		end
	end

	local function restorePostFX()
		for obj, orig in pairs(_postEffects) do
			pcall(function() if obj.Parent then obj.Enabled = orig end end)
		end
		table.clear(_postEffects)
	end

	local function disableParticleInst(p)
		if _particles[p] == nil then _particles[p] = p.Enabled end
		pcall(function() p.Enabled = false end)
	end

	local function disableParticlesIn(root)
		for _, p in ipairs(root:GetDescendants()) do
			for _, t in ipairs(PARTICLE_TYPES) do
				if p:IsA(t) then disableParticleInst(p); break end
			end
		end
	end

	local function restoreParticles()
		for p, orig in pairs(_particles) do
			pcall(function() if p.Parent then p.Enabled = orig end end)
		end
		table.clear(_particles)
	end

	local function disableDecalsIn(root)
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("Decal") or p:IsA("Texture") then
				if _decals[p] == nil then _decals[p] = p.Transparency end
				pcall(function() p.Transparency = 1 end)
			end
		end
	end

	local function restoreDecals()
		for p, orig in pairs(_decals) do
			pcall(function() if p.Parent then p.Transparency = orig end end)
		end
		table.clear(_decals)
	end

	-- ── Apply / restore ───────────────────────────────────────────────────────────

	local function applyPotato()
		-- 1. Render quality → minimum
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		pcall(function()
			UserSettings():GetService("UserGameSettings").SavedQualityLevel =
				Enum.SavedQualitySetting.QualityLevel1
		end)

		-- 2. Lighting properties
		snapshotAndSet(_lightingProps, Lighting, "GlobalShadows", false)
		snapshotAndSet(_lightingProps, Lighting, "FogEnd",        1e9)
		snapshotAndSet(_lightingProps, Lighting, "Brightness",    1)
		snapshotAndSet(_lightingProps, Lighting, "ClockTime",     14)  -- noon = best visibility

		-- 3. Post-processing effects
		disablePostFX()

		-- 4. Particles (Workspace + Lighting)
		disableParticlesIn(Workspace)
		disableParticlesIn(Lighting)

		-- 5. Decals / Textures
		disableDecalsIn(Workspace)

		-- 6. Watch for newly added particles / decals while potato is active
		_conns[#_conns + 1] = Workspace.DescendantAdded:Connect(function(p)
			if not potatoEnabled then return end
			for _, t in ipairs(PARTICLE_TYPES) do
				if p:IsA(t) then task.defer(disableParticleInst, p); return end
			end
			if p:IsA("Decal") or p:IsA("Texture") then
				task.defer(function()
					if not potatoEnabled or not p.Parent then return end
					if _decals[p] == nil then _decals[p] = p.Transparency end
					pcall(function() p.Transparency = 1 end)
				end)
			end
		end)

		-- 7. Disable shadow-casting on all BaseParts (avoids shadow recalculation)
		task.spawn(function()
			local CHUNK = 200
			local parts = Workspace:GetDescendants()
			for i = 1, #parts, CHUNK do
				if not potatoEnabled then break end
				for j = i, math.min(i + CHUNK - 1, #parts) do
					local p = parts[j]
					if p:IsA("BasePart") then
						if _lightingProps["_cast_" .. tostring(p)] == nil then
							_lightingProps["_cast_" .. tostring(p)] = { obj = p, orig = p.CastShadow }
						end
						pcall(function() p.CastShadow = false end)
					end
				end
				task.wait()
			end
		end)
	end

	local function restorePotato()
		-- Disconnect DescendantAdded watcher
		for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
		table.clear(_conns)

		-- Restore render quality
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
		end)
		pcall(function()
			UserSettings():GetService("UserGameSettings").SavedQualityLevel =
				Enum.SavedQualitySetting.Automatic
		end)

		-- Restore Lighting properties
		local restore = { "GlobalShadows", "FogEnd", "Brightness", "ClockTime" }
		for _, key in ipairs(restore) do
			if _lightingProps[key] ~= nil then
				pcall(function() Lighting[key] = _lightingProps[key] end)
				_lightingProps[key] = nil
			end
		end

		-- Restore BasePart shadow-casting
		for k, v in pairs(_lightingProps) do
			if type(k) == "string" and k:sub(1, 6) == "_cast_" then
				pcall(function() if v.obj and v.obj.Parent then v.obj.CastShadow = v.orig end end)
			end
		end
		table.clear(_lightingProps)

		-- Restore everything else
		restorePostFX()
		restoreParticles()
		restoreDecals()
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local sec = miscTab:AddSection("Potato Mode")

	sec:AddToggle("PotatoModeEn", {
		Title    = "Potato Mode",
		Icon     = "solar/bolt-bold",
		Default  = false,
		Callback = function(v)
			potatoEnabled = v
			if v then applyPotato() else restorePotato() end
		end,
	})

	-- ── Update / unmount ──────────────────────────────────────────────────────────

	local function update(data) end

	local function unmount()
		if potatoEnabled then restorePotato() end
	end

	return { update = update, unmount = unmount }
end
