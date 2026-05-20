return function(ctx)
	local securityTab    = ctx.securityTab
	local localPlayer    = ctx.localPlayer
	local Players        = ctx.Players
	local Workspace      = ctx.Workspace
	local RunService     = ctx.RunService
	local UserInputService = ctx.UserInputService
	local Fluent         = ctx.Fluent
	local bindRegistry   = ctx.bindRegistry

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TeleportService   = game:GetService("TeleportService")
	local HttpService       = game:GetService("HttpService")

	-- ── Shared helpers ────────────────────────────────────────────────────────────

	local function notify(title, msg, dur)
		pcall(function() Fluent:Notify({ Title = title, Content = msg, Duration = dur or 5 }) end)
	end

	local function tpTo(pos)
		local char = localPlayer.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end) end
	end

	-- ── Safe Point ────────────────────────────────────────────────────────────────

	local _safePoint   = nil
	local _autoTp      = { enabled = false, threshold = 30 }
	local _safeConns   = {}
	local _safeBind    = nil
	local _safeBindMode = "Always"
	local _safeToggle  = false

	local function isSafeBindActive()
		if safeBindMode == "Always" then return true end  -- typo safety
		local kv = _safeBind and _safeBind.Value
		if not kv or kv == "None" or kv == "" or _safeBindMode == "Always" then return true end
		if _safeBindMode == "Toggle" then return _safeToggle end
		local ok, kc = pcall(function() return Enum.KeyCode[kv] end)
		return ok and kc and kc ~= Enum.KeyCode.Unknown and UserInputService:IsKeyDown(kc)
	end

	local function setupAutoTPWatcher(char)
		for _, c in ipairs(_safeConns) do pcall(function() c:Disconnect() end) end
		_safeConns = {}
		if not char then return end
		local hum = char:FindFirstChildWhichIsA("Humanoid")
		if not hum then return end
		local triggered = false
		local c = hum.HealthChanged:Connect(function(hp)
			if not _autoTp.enabled or not _safePoint then triggered = false; return end
			local pct = (hp / math.max(hum.MaxHealth, 1)) * 100
			if pct <= _autoTp.threshold and not triggered then
				triggered = true
				tpTo(_safePoint)
				task.delay(4, function() triggered = false end)
			end
		end)
		table.insert(_safeConns, c)
	end

	local charAddedConn = localPlayer.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		setupAutoTPWatcher(char)
	end)
	setupAutoTPWatcher(localPlayer.Character)

	-- Safe point section
	local spSec  = securityTab:AddSection("Safe Point")

	-- Use Input as a read-only display — SetValue works reliably unlike SetContent.
	local spInfoInput = spSec:AddInput("SPInfo", {
		Title       = "Saved Position",
		Placeholder = "None",
		Numeric     = false,
		Callback    = function() end,
	})

	spSec:AddButton({ Title = "Save Current Position", Icon = "solar/map-point-wave-bold", Callback = function()
		local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			_safePoint = hrp.Position
			pcall(function()
				spInfoInput:SetValue(string.format("%.0f, %.0f, %.0f", _safePoint.X, _safePoint.Y, _safePoint.Z))
			end)
			notify("Safe Point", "Position saved", 2)
		end
	end })

	spSec:AddButton({ Title = "Teleport to Safe Point", Icon = "solar/map-point-bold", Callback = function()
		if _safePoint then tpTo(_safePoint)
		else notify("Safe Point", "No position saved yet", 3) end
	end })

	_safeBind = spSec:AddKeybind("SafePointBind", {
		Title   = "TP Bind",
		Default = "None",
	})

	spSec:AddDropdown("SafePointBindMode", {
		Title = "Bind Mode", Values = { "Always", "Hold", "Toggle" }, Default = "Always", NoSearch = true,
		Callback = function(v) _safeBindMode = v; _safeToggle = false end,
	})

	-- Toggle latch
	local _safeToggleConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or _safeBindMode ~= "Toggle" then return end
		local kv = _safeBind and _safeBind.Value
		if not kv or kv == "None" or kv == "" then return end
		local ok, kc = pcall(function() return Enum.KeyCode[kv] end)
		if ok and kc and kc ~= Enum.KeyCode.Unknown and input.KeyCode == kc then
			_safeToggle = not _safeToggle
			if _safeToggle and _safePoint then tpTo(_safePoint) end
		end
	end)

	-- Key-hold TP (checked in update)
	local _safePrevHeld = false

	spSec:AddToggle("AutoTPEnable", {
		Title = "Auto TP on Low HP", Icon = "solar/heart-pulse-bold", Default = false,
		Callback = function(v) _autoTp.enabled = v end,
	})
	spSec:AddSlider("AutoTPThreshold", {
		Title = "HP Threshold (%)", Default = 30, Min = 1, Max = 100, Rounding = 0,
		Callback = function(v) _autoTp.threshold = v end,
	})

	if bindRegistry then
		bindRegistry[#bindRegistry + 1] = {
			displayName = "Safe Point TP",
			getKey      = function() return _safeBind and _safeBind.Value or nil end,
			getMode     = function() return _safeBindMode end,
			isActive    = isSafeBindActive,
			getEnabled  = function() return _safePoint ~= nil end,
		}
	end

	-- ── Chakra Sense Alert ────────────────────────────────────────────────────────

	local _csAlertEnabled = false
	local _csAlertDrawing = nil
	local _csLastNotify   = 0
	local _csWasActive    = false

	local function initCSAlert()
		if _csAlertDrawing then pcall(function() _csAlertDrawing:Remove() end) end
		_csAlertDrawing = Drawing.new("Text")
		_csAlertDrawing.Text         = "!! CHAKRA SENSE !!"
		_csAlertDrawing.Size         = 20
		_csAlertDrawing.Color        = Color3.fromRGB(255, 55, 55)
		_csAlertDrawing.Outline      = true
		_csAlertDrawing.OutlineColor = Color3.fromRGB(0, 0, 0)
		_csAlertDrawing.Bold         = true
		_csAlertDrawing.Center       = true
		_csAlertDrawing.ZIndex       = 10
		_csAlertDrawing.Visible      = false
	end

	local function isSensing(player)
		local char = player.Character
		if not char then return false end
		local s = char:FindFirstChild("Settings")
		if s then
			local cs = s:FindFirstChild("CurrentSkill")
			if cs and cs.Value == "Chakra Sense" then return true end
		end
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if torso and torso:FindFirstChild("ChakraSense") then return true end
		local rsS = ReplicatedStorage:FindFirstChild("Settings")
		local ps  = rsS and rsS:FindFirstChild(player.Name)
		if ps then
			local cs = ps:FindFirstChild("CurrentSkill")
			if cs and cs.Value == "Chakra Sense" then return true end
		end
		return false
	end

	local csSec = securityTab:AddSection("Chakra Sense Alert")
	csSec:AddToggle("SecCSAlert", {
		Title = "Alert When Sensed", Icon = "solar/eye-bold", Default = false,
		Callback = function(v)
			_csAlertEnabled = v
			if v then initCSAlert() elseif _csAlertDrawing then
				pcall(function() _csAlertDrawing.Visible = false end)
			end
		end,
	})

	-- ── Moderation Detection ──────────────────────────────────────────────────────

	local MOD_USERNAMES = { "maxy1221648", "ArkhamDeluxe", "Pr1maryPath", "Spearess", "Etheriox", "Blahiren", "Ako_Shiba" }
	local modResponse   = "Notification"
	local _modConns     = {}
	local _notifiedMods = {}

	local function serverHop()
		pcall(function()
			TeleportService:Teleport(game.PlaceId, localPlayer)
		end)
	end

	local function kickSelf()
		-- Can't truly kick self; teleport as a "leave" instead
		serverHop()
	end

	local function handleModDetected(player, reason)
		local key = player.Name
		if _notifiedMods[key] then return end
		_notifiedMods[key] = true

		if modResponse == "Notification" then
			notify("Staff Detected", player.Name .. " — " .. reason, 10)
		elseif modResponse == "ServerHop" then
			notify("Staff Detected", "Hopping server — " .. player.Name, 5)
			task.delay(1.5, serverHop)
		elseif modResponse == "Kick" then
			notify("Staff Detected", "Leaving server — " .. player.Name, 5)
			task.delay(1.5, kickSelf)
		end
	end

	local function checkPlayer(player)
		if player == localPlayer then return end
		for _, name in ipairs(MOD_USERNAMES) do
			if player.Name:lower() == name:lower() then
				handleModDetected(player, "Known Staff")
				return
			end
		end
		-- Check Settings for moderator rank
		local function scanSettings(char)
			if not char then return end
			local s = char:FindFirstChild("Settings")
				   or (ReplicatedStorage:FindFirstChild("Settings") and ReplicatedStorage.Settings:FindFirstChild(player.Name))
			if not s then return end
			for _, v in ipairs(s:GetChildren()) do
				local n = v.Name:lower()
				if n == "moderator" or n == "ismod" or n == "rank" or n == "staff" then
					local val = v.Value
					if val and val ~= false and val ~= "" and val ~= 0 then
						handleModDetected(player, "Rank: " .. tostring(val))
						return
					end
				end
			end
		end
		if player.Character then task.spawn(scanSettings, player.Character) end
		local rc; rc = player.CharacterAdded:Connect(function(char)
			task.wait(1); task.spawn(scanSettings, char)
			if _notifiedMods[player.Name] then rc:Disconnect() end
		end)
		table.insert(_modConns, rc)
	end

	for _, p in ipairs(Players:GetPlayers()) do checkPlayer(p) end
	table.insert(_modConns, Players.PlayerAdded:Connect(checkPlayer))
	Players.PlayerRemoving:Connect(function(p) _notifiedMods[p.Name] = nil end)

	local modSec = securityTab:AddSection("Moderation Detection")
	modSec:AddDropdown("ModResponse", {
		Title    = "Response to Staff",
		Values   = { "Notification", "ServerHop", "Kick" },
		Default  = "Notification",
		NoSearch = true,
		Callback = function(v) modResponse = v end,
	})

	-- ── Update ────────────────────────────────────────────────────────────────────

	local function update(data)
		-- Safe Point hold-mode TP
		if _safePoint and _safeBind then
			local kv = _safeBind.Value
			if kv and kv ~= "None" and kv ~= "" and _safeBindMode == "Hold" then
				local ok, kc = pcall(function() return Enum.KeyCode[kv] end)
				local held = ok and kc and kc ~= Enum.KeyCode.Unknown and UserInputService:IsKeyDown(kc)
				if held and not _safePrevHeld then tpTo(_safePoint) end
				_safePrevHeld = held
			end
		end

		-- CS Alert
		if _csAlertEnabled and _csAlertDrawing then
			local sensing = false
			local _isWL   = _G.MYA_BL_IsWL
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= localPlayer then
					if not (_isWL and _isWL(p, "widgets")) and isSensing(p) then
						sensing = true; break
					end
				end
			end
			if sensing then
				local cam = Workspace.CurrentCamera
				if cam then
					_csAlertDrawing.Position = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5 - 100)
				end
				_csAlertDrawing.Visible = true
				local now = tick()
				if not _csWasActive and (now - _csLastNotify) >= 5 then
					_csLastNotify = now
					notify("Chakra Sense", "Someone is sensing!", 4)
				end
				_csWasActive = true
			else
				_csAlertDrawing.Visible = false
				_csWasActive = false
			end
		end
	end

	-- ── Unmount ───────────────────────────────────────────────────────────────────

	local function unmount()
		charAddedConn:Disconnect()
		for _, c in ipairs(_safeConns) do pcall(function() c:Disconnect() end) end
		for _, c in ipairs(_modConns)  do pcall(function() c:Disconnect() end) end
		pcall(function() _safeToggleConn:Disconnect() end)
		if _csAlertDrawing then pcall(function() _csAlertDrawing:Remove() end) end
	end

	return { update = update, unmount = unmount }
end
