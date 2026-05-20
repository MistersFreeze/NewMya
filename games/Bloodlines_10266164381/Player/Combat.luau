return function(ctx)
	local playerTab         = ctx.playerTab
	local bindRegistry      = ctx.bindRegistry
	local localPlayer       = ctx.localPlayer
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService        = game:GetService("RunService")

	local noFallDmg   = { enabled = false }
	local noM1CD      = { enabled = false }
	local noStun      = { enabled = false }
	local infStamina  = { enabled = false }
	local infChakra   = { enabled = false }
	local autoSprint  = { enabled = false }
	local allCooldowns = { enabled = false }
	local highJump    = { enabled = false, multiplier = 3.0 }

	local _noFallConns  = {}
	local _stunConns    = {}
	local _staminaCache = {}

	-- ── No Fall Damage ────────────────────────────────────────────────────────────
	-- Uses the game's own FallDamageImmunity attribute (line 6080 check in dump).

	local function applyNoFallDmg(char)
		for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
		table.clear(_noFallConns)
		char = char or localPlayer.Character
		if not char then return end
		pcall(function() char:SetAttribute("FallDamageImmunity", true) end)
		local c = char:GetAttributeChangedSignal("FallDamageImmunity"):Connect(function()
			if noFallDmg.enabled then
				task.defer(function()
					if noFallDmg.enabled and char.Parent then
						pcall(function() char:SetAttribute("FallDamageImmunity", true) end)
					end
				end)
			end
		end)
		table.insert(_noFallConns, c)
	end

	local function restoreNoFallDmg(char)
		for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
		table.clear(_noFallConns)
		char = char or localPlayer.Character
		if not char then return end
		pcall(function() char:SetAttribute("FallDamageImmunity", false) end)
	end

	-- ── M1 Cooldown ──────────────────────────────────────────────────────────────
	-- The game checks `tick() - u98.MeleeCooldown > 0.1` before each M1.
	-- Setting MeleeCooldown = 0 makes this always pass.
	-- Also resets Settings.MeleeCooldown BoolValue.

	local function applyNoM1CD()
		-- GC table patch (same u98 table used by auto sprint)
		if _sprintState then
			pcall(function()
				if type(_sprintState.MeleeCooldown) == "number" then
					_sprintState.MeleeCooldown = 0
				end
			end)
		end
		-- Settings.MeleeCooldown BoolValue
		local char = localPlayer.Character
		local settings = char and char:FindFirstChild("Settings")
		if settings then
			local mcd = settings:FindFirstChild("MeleeCooldown")
			if mcd and mcd.Value then
				pcall(function() mcd.Value = false end)
			end
		end
	end

	-- ── No Stun ───────────────────────────────────────────────────────────────────
	-- Server replicates Settings.Stunned.Value = true via DataEvent.
	-- We fight back with a Changed listener + every-frame reset in update().

	local function watchStunned(sv)
		if not (sv and sv:IsA("BoolValue")) then return end
		if sv.Value then pcall(function() sv.Value = false end) end
		local c = sv.Changed:Connect(function(v)
			if v and noStun.enabled then
				pcall(function() sv.Value = false end)
			end
		end)
		table.insert(_stunConns, c)
	end

	local function setupNoStun(char)
		for _, c in ipairs(_stunConns) do pcall(function() c:Disconnect() end) end
		_stunConns = {}
		char = char or localPlayer.Character
		if not char then return end
		local settings = char:FindFirstChild("Settings")
		if settings then watchStunned(settings:FindFirstChild("Stunned")) end
		local rsS = ReplicatedStorage:FindFirstChild("Settings")
		local ps  = rsS and rsS:FindFirstChild(char.Name)
		if ps then watchStunned(ps:FindFirstChild("Stunned")) end
	end

	-- ── Infinite Stamina (Jump Counters) ─────────────────────────────────────────
	-- Confirmed from dump (line 3784-3797):
	--   char.Settings.JumpCounters (NumberValue/IntValue) drives the purple segment UI
	--   above the hotbar. Each segment = 1 counter. Default max = 5 (line 405).
	--   Consumed by: double jump, triple jump, tree jump, substitution (server-side).
	--   UI update: Changed → show/hide numbered child frames in the JumpCounters frame.
	--
	-- Strategy: watch Changed and immediately restore to JUMP_MAX so counters never
	-- visually deplete. Per-frame fill is a second layer of defence.

	local JUMP_MAX  = 99   -- > any skill cost; all UI segments (1-5+) always show as lit
	local _jumpVal  = nil
	local _jumpConns = {}

	local function fillJumpCounters()
		if not (_jumpVal and _jumpVal.Parent) then return end
		if _jumpVal.Value < JUMP_MAX then
			pcall(function() _jumpVal.Value = JUMP_MAX end)
		end
	end

	local function cacheJumpVals()
		for _, c in ipairs(_jumpConns) do pcall(function() c:Disconnect() end) end
		table.clear(_jumpConns)
		_jumpVal = nil

		-- JumpCounters lives in char.Settings (confirmed: u98.Settings.JumpCounters)
		local char     = localPlayer.Character
		local settings = char and char:FindFirstChild("Settings")
		local jc       = settings and settings:FindFirstChild("JumpCounters")

		-- Fallback: ReplicatedStorage.Settings[playerName]
		if not jc then
			local rsS = ReplicatedStorage:FindFirstChild("Settings")
			local ps  = rsS and rsS:FindFirstChild(char and char.Name or "")
			jc = ps and ps:FindFirstChild("JumpCounters")
		end

		if not (jc and (jc:IsA("NumberValue") or jc:IsA("IntValue"))) then return end
		_jumpVal = jc

		if infStamina.enabled then
			-- Instant-refill watcher: fires synchronously when server decrements counters.
			local c = jc.Changed:Connect(function(newVal)
				if not infStamina.enabled then return end
				if newVal < JUMP_MAX then
					task.defer(function()
						if infStamina.enabled and _jumpVal and _jumpVal.Parent then
							pcall(function() _jumpVal.Value = JUMP_MAX end)
						end
					end)
				end
			end)
			table.insert(_jumpConns, c)
		end

		fillJumpCounters()
	end

	local function applyInfStaminaFrame()
		if not (_jumpVal and _jumpVal.Parent) then cacheJumpVals() end
		fillJumpCounters()
	end

	local function stopInfStamina()
		for _, c in ipairs(_jumpConns) do pcall(function() c:Disconnect() end) end
		table.clear(_jumpConns)
		_jumpVal = nil
	end

	-- ── Infinite Chakra ───────────────────────────────────────────────────────────
	-- Confirmed from dump: Backpack.chakra (NumberValue) + Backpack.maxChakra.
	-- Previous scan-based approach searched Settings — wrong container.

	local _chakraVal    = nil
	local _maxChakraVal = nil

	local function cacheChakraVals()
		local bp = localPlayer.Backpack
		if not bp then return end
		local c  = bp:FindFirstChild("chakra")
		local mc = bp:FindFirstChild("maxChakra")
		_chakraVal    = (c  and c:IsA("NumberValue"))  and c  or nil
		_maxChakraVal = (mc and mc:IsA("NumberValue")) and mc or nil
	end

	local function applyInfChakra()
		if not (_chakraVal and _chakraVal.Parent) then cacheChakraVals() end
		if _chakraVal and _maxChakraVal and _chakraVal.Parent then
			local maxVal = _maxChakraVal.Value
			if maxVal > 0 and _chakraVal.Value < maxVal then
				pcall(function() _chakraVal.Value = maxVal end)
			end
		end
	end

	-- ── Auto Sprint ───────────────────────────────────────────────────────────────

	local SPRINT_SPEED = 28

	local _sprintConns   = {}
	local _sprintClock   = 0
	local _sprintRunVal  = nil
	local _sprintState   = nil  -- u98 table (Running, CanRun, WDash, DashCooldown, MeleeCooldown…)

	-- Animation track (u120.Run) — confirmed from dump line 877.
	-- Needed because u120.Run:Play() is only called in the W-key handler,
	-- not in any continuous loop, so setting u98.Running=true alone is insufficient.
	local _runAnimTrack  = nil
	local _runAnimScan   = false   -- true once we've tried to find it

	local function findRunTrack()
		if typeof(getgc) ~= "function" then return end
		pcall(function()
			for _, obj in ipairs(getgc(true)) do
				if type(obj) ~= "table" then continue end
				-- u120 is identified by having both Run and Swimming as AnimationTracks
				local r = rawget(obj, "Run")
				local sw = rawget(obj, "Swimming")
				if typeof(r)  == "Instance" and r:IsA("AnimationTrack")
				and typeof(sw) == "Instance" and sw:IsA("AnimationTrack") then
					_runAnimTrack = r
					return
				end
			end
		end)
	end

	local function findSprintState()
		if typeof(getgc) ~= "function" then return end
		pcall(function()
			for _, obj in ipairs(getgc(true)) do
				if type(obj) ~= "table" then continue end
				if type(obj.Running)       == "boolean"
				and type(obj.CanRun)       == "boolean"
				and type(obj.WDash)        == "boolean"
				and type(obj.DashCooldown) == "boolean" then
					_sprintState = obj
					return
				end
			end
		end)
	end

	local function isOtsutsuki(char)
		char = char or localPlayer.Character
		if not char then return false end
		-- Primary: game sets this attribute on the character for Otsutsuki players.
		-- The Animate script reads it to swap in the float animation (dump line ~168).
		if char:GetAttribute("otsuAnimations") then return true end
		-- Fallback: check Settings.Bloodline (char-local and RS copy)
		local s  = char:FindFirstChild("Settings")
		local bl = s and s:FindFirstChild("Bloodline")
		if bl and bl.Value == "Otsutsuki" then return true end
		local rsS = ReplicatedStorage:FindFirstChild("Settings")
		local ps  = rsS and rsS:FindFirstChild(localPlayer.Name)
		local bl2 = ps and ps:FindFirstChild("Bloodline")
		return bl2 ~= nil and bl2.Value == "Otsutsuki"
	end

	local function assertSprint(hum)
		-- Otsutsuki uses a floating animation that the game manages via the Animate script.
		-- Touching Backpack.running or u98.Running triggers the game's sprint handler which
		-- forces the normal run animation. For Otsutsuki, only boost WalkSpeed.
		if isOtsutsuki() then
			if hum and hum.WalkSpeed < SPRINT_SPEED then
				pcall(function() hum.WalkSpeed = SPRINT_SPEED end)
			end
			return
		end

		if _sprintRunVal and _sprintRunVal.Parent then
			if not _sprintRunVal.Value then pcall(function() _sprintRunVal.Value = true end) end
		else
			local bp = localPlayer.Backpack
			local rv = bp and bp:FindFirstChild("running")
			if rv and rv:IsA("BoolValue") then
				_sprintRunVal = rv
				pcall(function() rv.Value = true end)
			end
		end
		if _sprintState then
			pcall(function()
				if not _sprintState.Running then _sprintState.Running = true end
				if not _sprintState.CanRun  then _sprintState.CanRun  = true end
				if not _sprintState.WDash   then _sprintState.WDash   = true end
			end)
		end
		if hum and hum.WalkSpeed < SPRINT_SPEED then
			pcall(function() hum.WalkSpeed = SPRINT_SPEED end)
		end
		if not _runAnimScan then
			_runAnimScan = true
			task.defer(findRunTrack)
		end
		if _runAnimTrack then
			pcall(function()
				if not _runAnimTrack.IsPlaying then _runAnimTrack:Play() end
			end)
		end
	end

	local function bindRunVal(rv)
		if not (rv and rv:IsA("BoolValue")) then return end
		_sprintRunVal = rv
		pcall(function() rv.Value = true end)
		local c = rv.Changed:Connect(function(v)
			if not v and autoSprint.enabled then
				task.defer(function()
					if autoSprint.enabled then pcall(function() rv.Value = true end) end
				end)
			end
		end)
		table.insert(_sprintConns, c)
	end

	local function setupAutoSprint(char)
		for _, c in ipairs(_sprintConns) do pcall(function() c:Disconnect() end) end
		table.clear(_sprintConns)
		_sprintRunVal = nil
		char = char or localPlayer.Character
		if not char then return end
		local bp = localPlayer.Backpack
		local rv = bp and bp:FindFirstChild("running")
		if rv then
			bindRunVal(rv)
		elseif bp then
			local c = bp.ChildAdded:Connect(function(child)
				if child.Name == "running" and child:IsA("BoolValue") then bindRunVal(child) end
			end)
			table.insert(_sprintConns, c)
		end
		if not _sprintState then task.defer(findSprintState) end
	end

	local function stopAutoSprint()
		for _, c in ipairs(_sprintConns) do pcall(function() c:Disconnect() end) end
		table.clear(_sprintConns)
		local char = localPlayer.Character
		local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.WalkSpeed <= SPRINT_SPEED then
			pcall(function() hum.WalkSpeed = 16 end)
		end
		if isOtsutsuki() then
			_sprintRunVal = nil
			return
		end
		if _sprintRunVal and _sprintRunVal.Parent then
			pcall(function() _sprintRunVal.Value = false end)
		end
		if _sprintState then pcall(function() _sprintState.Running = false end) end
		_sprintRunVal = nil
		if _runAnimTrack then
			pcall(function() if _runAnimTrack.IsPlaying then _runAnimTrack:Stop() end end)
		end
	end

	-- ── UI Setup ──────────────────────────────────────────────────────────────────

	local fallSec = playerTab:AddSection("Fall Damage")
	local fallToggle = fallSec:AddToggle("NoFallDmgToggle", {
		Title = "No Fall Damage", Icon = "solar/arrow-down-bold", Default = false,
		Callback = function(v)
			noFallDmg.enabled = v
			if v then applyNoFallDmg() else restoreNoFallDmg() end
		end,
	})
	local fallKb = fallSec:AddKeybind("NoFallBind", { Title = "Bind", Mode = "Toggle", Default = "",
		Callback = function(v)
			noFallDmg.enabled = v
			if v then applyNoFallDmg() else restoreNoFallDmg() end
			pcall(function() fallToggle:SetValue(v) end)
		end,
	})

	if bindRegistry then
		bindRegistry[#bindRegistry + 1] = {
			displayName = "No Fall",
			getKey      = function() return fallKb and fallKb.Value or nil end,
			getMode     = function() return "Toggle" end,
			isActive    = function() return noFallDmg.enabled end,
			getEnabled  = function() return true end,
		}
	end

	local m1Sec = playerTab:AddSection("M1 Attack")
	m1Sec:AddToggle("NoM1CD", {
		Title = "Remove M1 Cooldown", Icon = "solar/hand-shake-bold", Default = false,
		Callback = function(v) noM1CD.enabled = v end,
	})

	local staminaSec = playerTab:AddSection("Stamina")
	staminaSec:AddToggle("InfStamina", {
		Title    = "Infinite Stamina",
		Icon     = "solar/running-bold",
		Default  = false,
		Callback = function(v)
			infStamina.enabled = v
			if v then cacheJumpVals() else stopInfStamina() end
		end,
	})

	local chakraSec = playerTab:AddSection("Chakra")
	chakraSec:AddToggle("InfChakra", {
		Title = "Infinite Chakra", Icon = "solar/bolt-circle-bold", Default = false,
		Callback = function(v)
			infChakra.enabled = v
			if v then cacheChakraVals() end
		end,
	})

	local stunSec = playerTab:AddSection("Stun")
	stunSec:AddToggle("NoStun", {
		Title = "No Stun", Icon = "solar/danger-bold", Default = false,
		Callback = function(v)
			noStun.enabled = v
			if v then setupNoStun(localPlayer.Character) end
		end,
	})

	local sprintSec = playerTab:AddSection("Sprint")
	sprintSec:AddToggle("AutoSprintToggle", {
		Title = "Auto Sprint", Icon = "solar/running-2-bold", Default = false,
		Callback = function(v)
			autoSprint.enabled = v
			if v then setupAutoSprint() else stopAutoSprint() end
		end,
	})

	-- ── All Cooldowns ─────────────────────────────────────────────────────────────
	-- Zeros every cooldown boolean/number in the u98 state table every frame.
	-- Covers: DashCooldown, ShortCooldown, BlockCooldown, BlockStartCooldown,
	-- pickUpCooldown, ChakraFeetCooldown, ExtractionCooldown, AccessoryCooldown,
	-- RingCooldown, commandCooldown (all confirmed from dump).

	local coolSec = playerTab:AddSection("Cooldowns")
	coolSec:AddToggle("AllCooldownsToggle", {
		Title    = "All Cooldowns Off",
		Icon     = "solar/bolt-bold",
		Default  = false,
		Callback = function(v) allCooldowns.enabled = v end,
	})

	-- ── High Jump ─────────────────────────────────────────────────────────────────
	-- Modifies DoubleJumpMultiplier and TripleJumpMultiplier in the u98 GC table.
	-- Default in-game value: 1.6. Higher = bigger jumps.

	local jumpSec = playerTab:AddSection("High Jump")
	jumpSec:AddToggle("HighJumpToggle", {
		Title    = "High Jump",
		Icon     = "solar/arrow-up-bold",
		Default  = false,
		Callback = function(v) highJump.enabled = v end,
	})
	jumpSec:AddSlider("HighJumpMultiplier", {
		Title    = "Jump Multiplier",
		Default  = 30,
		Min      = 1,
		Max      = 100,
		Rounding = 0,
		Callback = function(v) highJump.multiplier = v end,
	})

	-- ── Character lifecycle ────────────────────────────────────────────────────────

	local charAddedConn = localPlayer.CharacterAdded:Connect(function(char)
		_chakraVal    = nil
		_maxChakraVal = nil
		-- Reset jump counter ref on respawn (new char = new Settings object).
		stopInfStamina()
		-- Reset animation track reference on respawn (new Animator = new tracks)
		_runAnimTrack = nil
		_runAnimScan  = false
		if noFallDmg.enabled then task.delay(0.5, function() applyNoFallDmg(char) end) end
		if noStun.enabled    then task.delay(0.5, function() setupNoStun(char) end) end
		if autoSprint.enabled then task.delay(0.6, function() setupAutoSprint(char) end) end
		task.delay(0.5, function()
			if infChakra.enabled  then cacheChakraVals() end
			if infStamina.enabled then cacheJumpVals()   end   -- re-wire watcher on new char's Settings
		end)
	end)

	-- Initial setup
	if localPlayer.Character then
		if noFallDmg.enabled then applyNoFallDmg(localPlayer.Character) end
		if noStun.enabled    then setupNoStun(localPlayer.Character) end
	end
	cacheChakraVals()
	-- JumpCounters watcher is attached lazily on first assertSprint or toggle-on.

	-- ── Update (called every RenderStepped) ───────────────────────────────────────

	local function update(data)
		-- Infinite Stamina: keep JumpCounters at max every frame.
		if infStamina.enabled then applyInfStaminaFrame() end

		-- Infinite chakra (direct Backpack.chakra write)
		if infChakra.enabled then applyInfChakra() end

		-- No Stun: keep Stunned.Value = false every frame as a backup to Changed signal.
		-- The Changed signal handles the instant response; this catches replication lag.
		if noStun.enabled then
			local char = localPlayer.Character
			local settings = char and char:FindFirstChild("Settings")
			local sv = settings and settings:FindFirstChild("Stunned")
			if sv and sv.Value then pcall(function() sv.Value = false end) end
			-- Also via GC state table's Settings reference when available.
			if _sprintState and _sprintState.Settings then
				local sv2 = _sprintState.Settings:FindFirstChild("Stunned")
				if sv2 and sv2.Value then pcall(function() sv2.Value = false end) end
			end
		end

		-- No M1 CD: keep MeleeCooldown = 0 every frame so the 0.1s cooldown always passes.
		if noM1CD.enabled then
			if _sprintState then
				pcall(function()
					if type(_sprintState.MeleeCooldown) == "number" and _sprintState.MeleeCooldown ~= 0 then
						_sprintState.MeleeCooldown = 0
					end
				end)
			end
			-- Settings.MeleeCooldown BoolValue
			local char = localPlayer.Character
			local settings = char and char:FindFirstChild("Settings")
			local mcd = settings and settings:FindFirstChild("MeleeCooldown")
			if mcd and mcd.Value then pcall(function() mcd.Value = false end) end
		end

		-- All Cooldowns Off: zeros every cooldown bool/number in u98 every frame.
		-- Uses the same _sprintState reference already found for sprint.
		if allCooldowns.enabled and _sprintState then
			pcall(function()
				local s = _sprintState
				-- Boolean cooldown flags (set to false = off cooldown = ready)
				if s.DashCooldown       then s.DashCooldown       = false end
				if s.ShortCooldown      then s.ShortCooldown      = false end
				if s.BlockCooldown      then s.BlockCooldown      = false end
				if s.BlockStartCooldown then s.BlockStartCooldown = false end
				if s.pickUpCooldown     then s.pickUpCooldown     = false end
				if s.ChakraFeetCooldown then s.ChakraFeetCooldown = false end
				if s.ExtractionCooldown then s.ExtractionCooldown = false end
				if s.AccessoryCooldown  then s.AccessoryCooldown  = false end
				if s.RingCooldown       then s.RingCooldown       = false end
				if s.commandCooldown    then s.commandCooldown    = false end
				-- Numeric timestamp cooldowns (set to 0 so tick()-0 is always large)
				if type(s.MeleeCooldown) == "number" then s.MeleeCooldown = 0 end
			end)
			-- Also clear Settings.MeleeCooldown BoolValue
			local char = localPlayer.Character
			local settings = char and char:FindFirstChild("Settings")
			local mcd = settings and settings:FindFirstChild("MeleeCooldown")
			if mcd and mcd.Value then pcall(function() mcd.Value = false end) end
		end

		-- High Jump: sets DoubleJumpMultiplier and TripleJumpMultiplier in u98.
		-- Default game value is 1.6; higher = bigger air.
		if highJump.enabled and _sprintState then
			pcall(function()
				local s = _sprintState
				local m = highJump.multiplier
				if type(s.DoubleJumpMultiplier) == "number" then s.DoubleJumpMultiplier = m end
				if type(s.TripleJumpMultiplier) == "number" then s.TripleJumpMultiplier = m end
				if type(s.JumpInterval)          == "number" then s.JumpInterval          = 0.05 end
			end)
		elseif not highJump.enabled and _sprintState then
			-- Restore defaults when toggled off
			pcall(function()
				local s = _sprintState
				if type(s.DoubleJumpMultiplier) == "number" then s.DoubleJumpMultiplier = 1.6 end
				if type(s.TripleJumpMultiplier) == "number" then s.TripleJumpMultiplier = 1.6 end
				if type(s.JumpInterval)          == "number" then s.JumpInterval          = 0.6 end
			end)
		end

		-- Auto Sprint: activates whenever the character is moving in any direction.
		if autoSprint.enabled then
			local char = localPlayer.Character
			local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
			if hum and hum.MoveDirection.Magnitude > 0 then
				assertSprint(hum)
			end
		end
	end

	local function unmount()
		restoreNoFallDmg()
		for _, c in ipairs(_stunConns) do pcall(function() c:Disconnect() end) end
		stopAutoSprint()
		stopInfStamina()
		charAddedConn:Disconnect()
	end

	return { update = update, unmount = unmount }
end
