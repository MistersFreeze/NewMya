return function(ctx)
	local autoFarmTab = ctx.autoFarmTab
	local localPlayer = ctx.localPlayer
	local Workspace   = ctx.Workspace
	local Fluent      = ctx.Fluent
	local Players     = ctx.Players

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DataEvent = nil
	pcall(function() DataEvent = ReplicatedStorage.Events.DataEvent end)

	local maskFarm = { enabled = false, delay = 1.5 }
	local _active  = true

	-- ── Helpers ───────────────────────────────────────────────────────────────────

	local function notify(msg)
		pcall(function() Fluent:Notify({ Title = "Mask Farm", Content = msg, Duration = 3 }) end)
	end

	local function tpTo(pos)
		local char = localPlayer.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) end) end
	end

	local function getPos(obj)
		if obj:IsA("Model") then
			local ok, pv = pcall(function() return obj:GetPivot().Position end)
			if ok then return pv end
			local pp = obj:FindFirstChildWhichIsA("BasePart", true)
			return pp and pp.Position
		end
		return obj:IsA("BasePart") and obj.Position or nil
	end

	-- Returns true if the object is a dropped/world mask (not worn by a player).
	local function isWorldMask(obj)
		local n = obj.Name:lower()
		if not n:find("mask", 1, true) then return false end
		-- Exclude masks that are accessories worn by player characters.
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char and obj:IsDescendantOf(char) then return false end
		end
		return true
	end

	-- Try every available interaction method on the object.
	local function interact(obj)
		-- 1. Bloodlines' primary interaction: ActivateButton child
		--    Fires DataEvent:FireServer("ActivateButton", model)
		local function tryActivate(root)
			for _, v in ipairs(root:GetDescendants()) do
				if v:IsA("BasePart") and v.Name == "ActivationButton" then
					if DataEvent then
						pcall(function() DataEvent:FireServer("ActivateButton", v.Parent) end)
						return true
					end
				end
			end
			return false
		end

		-- 2. Standard ClickDetector
		local function tryClick(root)
			local cd = root:FindFirstChildWhichIsA("ClickDetector", true)
			if cd then
				if typeof(fireclickdetector) == "function" then
					pcall(fireclickdetector, cd)
					return true
				end
			end
			return false
		end

		-- 3. ProximityPrompt
		local function tryPrompt(root)
			local pp = root:FindFirstChildWhichIsA("ProximityPrompt", true)
			if pp then
				if typeof(fireproximityprompt) == "function" then
					pcall(fireproximityprompt, pp)
					return true
				end
				-- Roblox API fallback
				pcall(function()
					game:GetService("ProximityPromptService"):TriggerPrompt(pp, localPlayer)
				end)
				return true
			end
			return false
		end

		-- 4. Generic item pickup (ground-dropped items)
		local function tryPickUp(root)
			if DataEvent then
				pcall(function() DataEvent:FireServer("PickUp", root) end)
			end
		end

		if not tryActivate(obj) then
			if not tryClick(obj) then
				if not tryPrompt(obj) then
					tryPickUp(obj)
				end
			end
		end
	end

	-- ── Scan ─────────────────────────────────────────────────────────────────────

	local function scanMasks()
		local found = {}
		local seen  = {}
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if not isWorldMask(obj) then continue end
			if seen[obj] then continue end
			seen[obj] = true
			local pos = getPos(obj)
			if pos then
				found[#found + 1] = { obj = obj, pos = pos, name = obj.Name }
			end
		end
		return found
	end

	-- ── Farm loop ─────────────────────────────────────────────────────────────────

	local function runFarm()
		task.spawn(function()
			while maskFarm.enabled and _active do
				local masks = scanMasks()

				if #masks == 0 then
					task.wait(3)
					continue
				end

				for _, entry in ipairs(masks) do
					if not maskFarm.enabled or not _active then break end
					if not entry.obj.Parent then continue end   -- already gone

					-- Teleport to mask
					tpTo(entry.pos)
					task.wait(0.25)

					-- Interact (click / activate)
					if entry.obj.Parent then
						interact(entry.obj)
					end

					task.wait(maskFarm.delay)
				end
			end
		end)
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local sec = autoFarmTab:AddSection("Mask Farm")

	sec:AddToggle("MaskFarmEn", {
		Title    = "Enable Mask Farm",
		Icon     = "solar/map-point-bold",
		Default  = false,
		Callback = function(v)
			maskFarm.enabled = v
			if v then runFarm() end
		end,
	})

	sec:AddSlider("MaskFarmDelay", {
		Title    = "Delay Between Masks (s)",
		Default  = 1.5,
		Min      = 0.3,
		Max      = 10,
		Rounding = 1,
		Callback = function(v) maskFarm.delay = v end,
	})

	sec:AddButton({ Title = "Scan Now", Icon = "solar/magnifer-bold", Callback = function()
		local masks = scanMasks()
		notify("Found " .. #masks .. " mask(s) in world")
	end })

	sec:AddParagraph({
		Title   = "How it works",
		Content = "Scans workspace for dropped/world Mask items, TPs to each, then triggers interaction (ActivateButton / ClickDetector / ProximityPrompt).",
	})

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function update(data) end
	local function unmount() _active = false end
	return { update = update, unmount = unmount }
end
