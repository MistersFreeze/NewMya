return function(ctx)
	local miscTab    = ctx.miscTab
	local localPlayer = ctx.localPlayer
	local RunService  = ctx.RunService
	local Fluent      = ctx.Fluent

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DataEvent = nil
	pcall(function() DataEvent = ReplicatedStorage.Events.DataEvent end)

	-- Chakra Sense (from dump):
	--   ChakraCost = 0, Cooldown = 0.1
	--   Activation: startSkill "Chakra Sense"
	--   Requirements: player must have the skill unlocked

	local csTech = {
		enabled   = false,
		autoSense = false,   -- automatically activate CS when off cooldown
	}

	local _lastActivate = 0
	local CS_COOLDOWN   = 0.5   -- seconds between activation attempts

	local function activateCS()
		if not DataEvent then return end
		local now = tick()
		if now - _lastActivate < CS_COOLDOWN then return end
		_lastActivate = now

		local char = localPlayer.Character
		if not char then return end

		-- Check if already sensing
		local s = char:FindFirstChild("Settings")
		if s then
			local cs = s:FindFirstChild("CurrentSkill")
			if cs and cs.Value == "Chakra Sense" then return end
		end

		-- Fire startSkill for Chakra Sense
		-- Arguments from dump: (skillName, targetPosition, direction, mouseButton)
		pcall(function()
			local cam = workspace.CurrentCamera
			local pos = cam and cam.CFrame.Position or Vector3.zero
			DataEvent:FireServer("startSkill", "Chakra Sense", pos, Vector3.zero, "MouseButton1")
		end)
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local sec = miscTab:AddSection("Chakra Sense Technique")

	sec:AddToggle("CSTechAutoSense", {
		Title    = "Auto-Activate Chakra Sense",
		Icon     = "solar/eye-bold",
		Default  = false,
		Callback = function(v) csTech.autoSense = v end,
	})

	sec:AddButton({ Title = "Activate Now", Icon = "solar/bolt-bold", Callback = activateCS })

	sec:AddParagraph({
		Title   = "Note",
		Content = "Requires Chakra Sense skill to be unlocked on your character.",
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(data)
		if csTech.autoSense then activateCS() end
	end

	local function unmount() end
	return { update = update, unmount = unmount }
end
