return function(ctx)
	local playerTab   = ctx.friendsTab or ctx.playerTab
	local Players     = ctx.Players
	local localPlayer = ctx.localPlayer
	local Fluent      = ctx.Fluent
	local SaveManager = ctx.SaveManager

	local HttpService = game:GetService("HttpService")

	-- ── Config persistence via readfile/writefile ─────────────────────────────────
	-- SaveManager only saves Fluent element values; the whitelist player list is
	-- stored separately in a JSON file so it persists across sessions.

	local WL_FILE = "Mya/Bloodlines/whitelist.json"

	local function saveWLFile()
		pcall(function()
			if typeof(writefile) ~= "function" then return end
			if typeof(makefolder) == "function" then
				pcall(makefolder, "Mya"); pcall(makefolder, "Mya/Bloodlines")
			end
			local names = {}
			for k in pairs(wl and wl.players or {}) do names[#names + 1] = k end
			writefile(WL_FILE, HttpService:JSONEncode(names))
		end)
	end

	local function loadWLFile()
		pcall(function()
			if typeof(isfile) ~= "function" or not isfile(WL_FILE) then return end
			if typeof(readfile) ~= "function" then return end
			local ok, t = pcall(function() return HttpService:JSONDecode(readfile(WL_FILE)) end)
			if ok and type(t) == "table" then
				for _, name in ipairs(t) do
					if type(name) == "string" and name ~= "" then
						wl.players[name:lower()] = true
					end
				end
			end
		end)
	end

	-- ── Global whitelist state ────────────────────────────────────────────────────
	-- All modules that need whitelist access read from _G.MYA_BL_WL / _G.MYA_BL_IsWL
	-- rather than holding a direct reference, so everything stays in sync.

	_G.MYA_BL_WL = {
		enabled = false,
		players = {},        -- { [lowercaseName] = true }
		flags   = {
			esp       = true,   -- hide Player ESP boxes for whitelisted players
			silentAim = true,   -- do not target whitelisted players with silent aim
			widgets   = true,   -- exclude from CS / Users widget counts
			proximity = true,   -- ignore in SafeSpot proximity auto-TP check
			autoTp    = true,   -- ignore in Teleport auto-TP health check
		},
	}

	-- Shared helper stored in _G so every module can call it at runtime.
	_G.MYA_BL_IsWL = function(player, flag)
		local wl = _G.MYA_BL_WL
		if not (wl and wl.enabled) then return false end
		local name = player and player.Name
		if not name then return false end
		if not wl.players[name:lower()] then return false end
		if flag ~= nil and wl.flags then
			return wl.flags[flag] ~= false
		end
		return true
	end

	local wl = _G.MYA_BL_WL

	-- ── Helpers ───────────────────────────────────────────────────────────────────

	local function trimmed(s)
		return type(s) == "string" and s:match("^%s*(.-)%s*$") or ""
	end

	-- _listLabel is set after UI is built.
	local _listLabel = nil

	local function refreshListPara(_ignored)
		local names = {}
		for k in pairs(wl.players) do names[#names + 1] = k end
		table.sort(names)
		local text = #names > 0 and table.concat(names, ", ") or "None"
		-- Update via the Label element if available.
		if _listLabel then
			pcall(function() _listLabel:SetValue(text) end)
		end
		-- Save to file every time the list changes.
		saveWLFile()
	end

	local function addName(raw, para)
		local name = trimmed(raw)
		if name == "" then return end
		if name:lower() == localPlayer.Name:lower() then
			pcall(function() Fluent:Notify({ Title = "Whitelist", Content = "Can't whitelist yourself", Duration = 2 }) end)
			return
		end
		wl.players[name:lower()] = true
		refreshListPara(para)
		pcall(function() Fluent:Notify({ Title = "Whitelist", Content = name .. " added", Duration = 2 }) end)
	end

	local function removeName(raw, para)
		local name = trimmed(raw)
		if name == "" then return end
		wl.players[name:lower()] = nil
		refreshListPara(para)
	end

	local function getServerNames()
		local t = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer then t[#t + 1] = p.Name end
		end
		return #t > 0 and t or { "— no players —" }
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local sec = playerTab:AddSection("Friends / Whitelist")

	sec:AddToggle("WLEnable", {
		Title    = "Enable Whitelist",
		Icon     = "solar/shield-user-bold",
		Default  = false,
		Callback = function(v) wl.enabled = v end,
	})

	-- Use AddInput as a read-only display for the whitelist contents.
	-- Fluent Input elements update their displayed value via :SetValue().
	_listLabel = sec:AddInput("WLList", {
		Title       = "Whitelisted",
		Placeholder = "None",
		Numeric     = false,
		Callback    = function() end,   -- read-only: we set value programmatically
	})
	local listPara = nil  -- kept for API compatibility (refreshListPara ignores it)

	-- Load persisted whitelist from file.
	loadWLFile()
	refreshListPara(nil)

	-- Dropdown of server players
	local pNames = getServerNames()
	local selectedDD = pNames[1]
	local playerDD = sec:AddDropdown("WLPlayerDD", {
		Title    = "Select Player",
		Values   = pNames,
		Default  = pNames[1],
		NoSearch = false,
		Callback = function(v) selectedDD = v end,
	})

	sec:AddButton({ Title = "Refresh Players", Icon = "solar/refresh-bold", Callback = function()
		local names = getServerNames()
		pcall(function() playerDD:SetValues(names); playerDD:SetValue(names[1]) end)
		selectedDD = names[1]
	end })

	sec:AddButton({ Title = "Add Selected", Icon = "solar/user-plus-bold", Callback = function()
		if selectedDD and selectedDD ~= "— no players —" then
			addName(selectedDD, listPara)
		end
	end })

	sec:AddButton({ Title = "Remove Selected", Icon = "solar/user-minus-bold", Callback = function()
		if selectedDD and selectedDD ~= "— no players —" then
			removeName(selectedDD, listPara)
		end
	end })

	-- Manual text entry
	local manualInput = ""
	sec:AddInput("WLManualInput", {
		Title       = "Manual Username",
		Placeholder = "Enter username...",
		Numeric     = false,
		Callback    = function(v) manualInput = v end,
	})

	sec:AddButton({ Title = "Add Manually", Icon = "solar/pen-bold", Callback = function()
		addName(manualInput, listPara)
	end })

	sec:AddButton({ Title = "Remove Manually", Icon = "solar/minus-circle-bold", Callback = function()
		removeName(manualInput, listPara)
	end })

	sec:AddButton({ Title = "Clear All", Icon = "solar/trash-bin-trash-bold", Callback = function()
		table.clear(wl.players)
		refreshListPara(listPara)
		pcall(function() Fluent:Notify({ Title = "Whitelist", Content = "Cleared", Duration = 2 }) end)
	end })

	-- ── Feature flags ─────────────────────────────────────────────────────────────

	local flagSec = playerTab:AddSection("Whitelist — Features")

	flagSec:AddToggle("WLFlagESP", {
		Title    = "Player ESP",
		Icon     = "solar/eye-bold",
		Default  = true,
		Callback = function(v) wl.flags.esp = v end,
	})

	flagSec:AddToggle("WLFlagSA", {
		Title    = "Silent Aim",
		Icon     = "solar/target-bold",
		Default  = true,
		Callback = function(v) wl.flags.silentAim = v end,
	})

	flagSec:AddToggle("WLFlagWidgets", {
		Title    = "CS / Users Widget",
		Icon     = "solar/users-group-rounded-bold",
		Default  = true,
		Callback = function(v) wl.flags.widgets = v end,
	})

	flagSec:AddToggle("WLFlagProximity", {
		Title    = "Proximity Checks",
		Icon     = "solar/map-point-wave-bold",
		Default  = true,
		Callback = function(v) wl.flags.proximity = v end,
	})

	flagSec:AddToggle("WLFlagAutoTP", {
		Title    = "Auto Teleport Trigger",
		Icon     = "solar/map-arrow-square-bold",
		Default  = true,
		Callback = function(v) wl.flags.autoTp = v end,
	})

	-- ── Update / unmount ──────────────────────────────────────────────────────────

	local function update(data) end

	local function unmount()
		saveWLFile()   -- persist on unload
		_G.MYA_BL_WL   = nil
		_G.MYA_BL_IsWL  = nil
	end

	return { update = update, unmount = unmount }
end
