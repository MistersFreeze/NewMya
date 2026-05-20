return function(ctx)
	local playerTab   = ctx.playerTab
	local localPlayer = ctx.localPlayer
	local RunService  = ctx.RunService

	local antiVoid = { enabled = false }

	-- ── Constants ─────────────────────────────────────────────────────────────────

	-- Y position below which we consider the character to be in the void.
	local VOID_Y = -100

	-- ── State ─────────────────────────────────────────────────────────────────────

	local _lastSafeCFrame = nil   -- last CFrame above VOID_Y
	local _lastSafeTick   = 0
	local _voidConns      = {}
	local _charConn       = nil

	-- ── Void-immunity setup ───────────────────────────────────────────────────────
	-- Three layers to make void have zero effect:
	--   1. FallDamageImmunity attribute  → game's own check at line 6080 skips TakeDamage
	--   2. NegateFall BoolValue child    → game's own check at line 6082 skips TakeDamage
	--   3. Heartbeat position monitor   → instant TP back if Y < VOID_Y

	local function applyImmunity(char)
		if not char then return end
		-- Layer 1
		pcall(function() char:SetAttribute("FallDamageImmunity", true) end)
		-- Watch for server clearing the attribute and restore it immediately.
		local c1 = char:GetAttributeChangedSignal("FallDamageImmunity"):Connect(function()
			if antiVoid.enabled and char.Parent then
				pcall(function() char:SetAttribute("FallDamageImmunity", true) end)
			end
		end)
		table.insert(_voidConns, c1)

		-- Layer 2: add NegateFall BoolValue so the game's `u69:FindFirstChild("NegateFall")`
		-- check passes, which is a second gate before TakeDamage is fired.
		if not char:FindFirstChild("NegateFall") then
			pcall(function()
				local nf = Instance.new("BoolValue")
				nf.Name   = "NegateFall"
				nf.Value  = true
				nf.Parent = char
			end)
		end
	end

	local function removeImmunity(char)
		if not char then return end
		pcall(function() char:SetAttribute("FallDamageImmunity", false) end)
		local nf = char:FindFirstChild("NegateFall")
		if nf then pcall(function() nf:Destroy() end) end
	end

	local function startLoop()
		-- Disconnect any old Heartbeat loop.
		for _, c in ipairs(_voidConns) do pcall(function() c:Disconnect() end) end
		table.clear(_voidConns)

		local char = localPlayer.Character
		applyImmunity(char)

		-- Heartbeat: track last safe position and teleport back instantly if in void.
		local hb = RunService.Heartbeat:Connect(function()
			if not antiVoid.enabled then return end
			local c2 = localPlayer.Character
			local hrp = c2 and c2:FindFirstChild("HumanoidRootPart")
			if not hrp then return end

			local pos = hrp.Position
			-- Update last safe position whenever above the void threshold.
			if pos.Y > VOID_Y then
				local now = tick()
				if now - _lastSafeTick > 0.1 then
					_lastSafeTick   = now
					_lastSafeCFrame = hrp.CFrame
				end
			else
				-- In the void — teleport back to last safe position immediately.
				if _lastSafeCFrame then
					pcall(function()
						hrp.CFrame = _lastSafeCFrame + Vector3.new(0, 5, 0)
					end)
				end
			end
		end)
		table.insert(_voidConns, hb)
	end

	local function stopLoop()
		for _, c in ipairs(_voidConns) do pcall(function() c:Disconnect() end) end
		table.clear(_voidConns)
		removeImmunity(localPlayer.Character)
		_lastSafeCFrame = nil
	end

	-- Re-apply on character respawn.
	_charConn = localPlayer.CharacterAdded:Connect(function(char)
		if antiVoid.enabled then
			_lastSafeCFrame = nil
			task.delay(0.5, function()
				if antiVoid.enabled then startLoop() end
			end)
		end
	end)

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local sec = playerTab:AddSection("Anti Void")

	sec:AddToggle("AntiVoidEn", {
		Title    = "Anti Void",
		Icon     = "solar/danger-bold",
		Default  = false,
		Callback = function(v)
			antiVoid.enabled = v
			if v then startLoop() else stopLoop() end
		end,
	})

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function update(data) end
	local function unmount()
		stopLoop()
		if _charConn then _charConn:Disconnect() end
	end

	return { update = update, unmount = unmount }
end
