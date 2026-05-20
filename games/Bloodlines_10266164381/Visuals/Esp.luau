return function(ctx)
	local visualsTab   = ctx.visualsTab
	local Players      = ctx.Players
	local Workspace    = ctx.Workspace
	local localPlayer  = ctx.localPlayer

	local Lighting            = game:GetService("Lighting")
	local ReplicatedStorage   = game:GetService("ReplicatedStorage")
	local InterfaceManager    = ctx.InterfaceManager

	-- ── Config tables ─────────────────────────────────────────────────────────────

	local playerEsp = {
		enabled    = false,
		name       = true,
		distance   = true,
		health     = false,
		color      = Color3.fromRGB(255, 255, 255),
		maxDist    = 1000,
		showClan   = true,
		showInfo   = true,
		showBox    = true,
		scaleText  = false,
		bloodBar   = false,  -- second HP bar on right side of box
		chakraBar  = false,  -- chakra bar below box
	}
	local npcEsp = {
		enabled = false,
		color   = Color3.fromRGB(100, 200, 255),
		maxDist = 500,
	}
	local mobEsp = {
		enabled = false,
		health  = false,
		color   = Color3.fromRGB(255, 80, 80),
		maxDist = 500,
	}

	-- ── O(1) player-character set ─────────────────────────────────────────────────
	-- Keeps a dictionary of character models → true so isPlayerChar is O(1).

	-- Declared here so the _prConn closure below can safely reference it before
	-- the full info-cache section initialises later in the file.
	local _playerInfoCache = {}

	local _playerChars = {}

	local function trackPlayer(p)
		if p.Character then _playerChars[p.Character] = true end
		p.CharacterAdded:Connect(function(c)   _playerChars[c] = true  end)
		p.CharacterRemoving:Connect(function(c) _playerChars[c] = nil   end)
	end
	for _, p in ipairs(Players:GetPlayers()) do trackPlayer(p) end
	local _paConn = Players.PlayerAdded:Connect(trackPlayer)
	local _prConn = Players.PlayerRemoving:Connect(function(p)
		if p.Character then _playerChars[p.Character] = nil end
		_playerInfoCache[p] = nil
	end)

	local function isPlayerChar(model) return _playerChars[model] == true end

	-- ── Entity kind resolver (used once at add-time, not per frame) ───────────────

	local function getEntityKind(model)
		if not model:IsA("Model") then return nil end
		if isPlayerChar(model) then return nil end
		if not model:FindFirstChildWhichIsA("Humanoid") then return nil end
		local npcVal = model:FindFirstChild("NPC")
		if not npcVal then return nil end
		return tostring(npcVal.Value):lower() == "dialog" and "npc" or "mob"
	end

	local function getDisplayName(model)
		local s   = model:FindFirstChild("Settings")
		local nv  = s and s:FindFirstChild("NPCName")
		if nv and typeof(nv.Value) == "string" and #nv.Value > 0 then return nv.Value end
		return model.Name
	end

	-- ── Focal-length cache ────────────────────────────────────────────────────────
	-- Recomputed only when the camera FOV or viewport size changes.

	local _focalLen   = 0
	local _lastFov    = 0
	local _lastVpY    = 0

	local function getFocalLen(cam)
		local fov = cam.FieldOfView
		local vpY = cam.ViewportSize.Y
		if fov ~= _lastFov or vpY ~= _lastVpY then
			_lastFov    = fov
			_lastVpY    = vpY
			_focalLen   = (vpY * 0.5) / math.tan(math.rad(fov * 0.5))
		end
		return _focalLen
	end

	-- ── Drawing font state ────────────────────────────────────────────────────────
	-- Maps Fluent/Roblox font names to Drawing.Fonts enum indices.
	-- Synced once per second in the update loop.

	local FONT_UI   = (typeof(Drawing) == "table" and Drawing.Fonts and Drawing.Fonts.UI)       or 0
	local FONT_SYS  = (typeof(Drawing) == "table" and Drawing.Fonts and Drawing.Fonts.System)   or 1
	local FONT_MONO = (typeof(Drawing) == "table" and Drawing.Fonts and Drawing.Fonts.Monospace) or 3

	local FONT_MAP = {
		GothamSSm    = FONT_UI,  Gotham        = FONT_UI,  GothamMedium  = FONT_UI,
		GothamBold   = FONT_UI,  Roboto        = FONT_UI,  Ubuntu        = FONT_UI,
		SourceSans   = FONT_UI,  SourceSansBold= FONT_UI,
		Arial        = FONT_SYS, ArialBold     = FONT_SYS,
		Code         = FONT_MONO,RobotoMono    = FONT_MONO,
	}

	local _curFont     = FONT_UI
	local _fontSyncTick = 0

	local function readFluentFont()
		local name = "GothamSSm"
		pcall(function()
			local s = InterfaceManager and InterfaceManager.Settings
			if s and type(s.Font) == "string" then name = s.Font end
		end)
		return FONT_MAP[name] or FONT_UI
	end

	-- Apply current font to every text Drawing in a drawings table.
	-- Tries both the Drawing.Fonts enum value and the raw integer index since
	-- different executor versions expose the property differently.
	local function applyFont(drawings, fontIdx)
		for _, d in pairs(drawings) do
			pcall(function() d.Font = fontIdx end)
		end
	end

	-- ── Drawing factories ─────────────────────────────────────────────────────────

	local function newText(size)
		local t = Drawing.new("Text")
		t.Center = true; t.Outline = true
		t.OutlineColor = Color3.fromRGB(0, 0, 0)
		t.Size = size or 13
		t.Visible = false
		pcall(function() t.Font = _curFont end)
		return t
	end

	local function newSquare(filled, zi)
		local s = Drawing.new("Square")
		s.Filled    = filled or false
		s.Thickness = 1
		s.ZIndex    = zi or 1
		s.Visible   = false
		return s
	end

	local function makeDrawings()
		local d = {
			box      = newSquare(false, 2),
			name     = newText(14),
			clan     = newText(11),
			dist     = newText(13),
			info     = newText(11),
			hpBg     = newSquare(true, 1),
			hpBar    = newSquare(true, 2),
			-- Blood bar (right side, mirrors hpBar in red)
			bloodBg  = newSquare(true, 1),
			bloodBar = newSquare(true, 2),
			-- Chakra bar (below box, blue)
			chakraBg  = newSquare(true, 1),
			chakraBar = newSquare(true, 2),
		}
		applyFont(d, _curFont)
		d.hpBg.Color     = Color3.fromRGB(30, 30, 30)
		d.bloodBg.Color  = Color3.fromRGB(30, 30, 30)
		d.chakraBg.Color = Color3.fromRGB(30, 30, 30)
		return d
	end

	-- Minimum rendered box height (px) below which text labels are hidden.
	-- Prevents unreadable overlapping text on far-away targets.
	local TEXT_MIN_H = 13

	-- ── Player info cache ─────────────────────────────────────────────────────────
	-- All fields confirmed from dump analysis:
	--   Settings.Bloodline       (StringValue) — clan name
	--   Settings.Awakened        (StringValue) — active awakening/eye string e.g. "Shisui's Mangekyo"
	--   Settings.RecentDamage    (NumberValue) — 0 = sub available, >0 = gated
	--   Settings.CurrentSkill    (StringValue) — "Chakra Sense" when sensing
	--   char.Torso.ChakraSense   (Part)        — present while sensing
	--   Freshie: empty Bloodline or plant-like child on character

	local INFO_TTL = 1.5

	local FRESHIE_PATS = { "vine", "plant", "sprout", "leaf", "freshie", "sapling", "flower", "grass", "twig" }

	-- extractPlayerInfo takes the Player object (not just Character) so it can
	-- check both char.Settings (local replicated copy) AND
	-- ReplicatedStorage.Settings[playerName] (server-authoritative settings).
	-- From the dump, other players' bloodline / awakened / skill state lives in
	-- ReplicatedStorage.Settings — char.Settings may be empty or partial for
	-- remote players.
	local function extractPlayerInfo(player)
		local out = {
			bloodline  = nil,
			awakening  = nil,
			sub        = nil,
			sensing    = false,
			freshie    = false,
			chakraPct  = nil,   -- 0-1 chakra fraction, nil if unknown
		}
		if not player then return out end
		local char = player.Character
		if not char then return out end

		-- Build a priority list of Settings objects to try.
		-- ReplicatedStorage.Settings[name] is the authoritative source for remote players.
		local rsRoot     = ReplicatedStorage:FindFirstChild("Settings")
		local rsSettings = rsRoot and rsRoot:FindFirstChild(player.Name)
		local charSettings = char:FindFirstChild("Settings")

		-- Helper: read a child from any available settings object.
		local function findInSettings(childName)
			if rsSettings then
				local v = rsSettings:FindFirstChild(childName)
				if v then return v end
			end
			if charSettings then
				local v = charSettings:FindFirstChild(childName)
				if v then return v end
			end
			return nil
		end

		-- Bloodline — no field or empty value = freshie (no clan yet)
		local bl = findInSettings("Bloodline")
		if bl and typeof(bl.Value) == "string" then
			local blVal = bl.Value
			if blVal ~= "" and blVal ~= "None" and blVal ~= "Default" then
				out.bloodline = blVal
			else
				out.freshie = true
			end
		else
			-- Bloodline field missing = new player without a clan
			out.freshie = true
		end

		-- Awakened/Eye state (confirmed from dump: Settings.Awakened StringValue)
		local awk = findInSettings("Awakened")
		if awk and typeof(awk.Value) == "string" and awk.Value ~= "" then
			out.awakening = awk.Value
		end

		-- Sub availability via RecentDamage
		local rd = findInSettings("RecentDamage")
		if rd and (rd:IsA("NumberValue") or rd:IsA("IntValue")) then
			out.sub = (rd.Value == 0)
		end

		-- CS sensing via CurrentSkill
		local cs = findInSettings("CurrentSkill")
		if cs and typeof(cs.Value) == "string" then
			out.sensing = (cs.Value == "Chakra Sense")
		end

		-- Also check Torso for active ChakraSense part
		if not out.sensing then
			local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			if torso and torso:FindFirstChild("ChakraSense") then
				out.sensing = true
			end
		end

		-- Chakra percentage: scan Settings for chakra / maxChakra values
		do
			local c  = findInSettings("chakra") or findInSettings("Chakra")
			local mc = findInSettings("maxChakra") or findInSettings("MaxChakra")
			if c and mc and (mc:IsA("NumberValue") or mc:IsA("IntValue")) and mc.Value > 0 then
				local cv = (c:IsA("NumberValue") or c:IsA("IntValue")) and c.Value or 0
				out.chakraPct = math.clamp(cv / mc.Value, 0, 1)
			end
		end

		-- Freshie detection: scan character children for plant/vine visual
		if not out.freshie then
			for _, child in ipairs(char:GetChildren()) do
				local n = child.Name:lower()
				for _, pat in ipairs(FRESHIE_PATS) do
					if n:find(pat, 1, true) then
						out.freshie = true
						break
					end
				end
				if out.freshie then break end
			end
		end

		return out
	end

	local function getPlayerInfo(player)
		local now    = tick()
		local cached = _playerInfoCache[player]
		if cached and (now - cached.t) < INFO_TTL then return cached.d end
		local d = extractPlayerInfo(player)    -- pass player, not just character
		_playerInfoCache[player] = { d = d, t = now }
		return d
	end

	local function destroyDrawings(d)
		for _, v in pairs(d) do pcall(function() v:Remove() end) end
	end

	local function hideDrawings(d)
		for _, v in pairs(d) do v.Visible = false end
	end

	-- ── Active ESP tables ─────────────────────────────────────────────────────────

	local activeESPs = {
		players = {},   -- [Player] = { drawings, respawnConn }
		world   = {},   -- [Model]  = { kind, hum, displayName, drawings, conns }
	}

	-- ── Player ESP management ─────────────────────────────────────────────────────

	local function removePlayerESP(player)
		local e = activeESPs.players[player]
		if not e then return end
		if e.respawnConn then pcall(function() e.respawnConn:Disconnect() end) end
		destroyDrawings(e.drawings)
		activeESPs.players[player] = nil
	end

	local function addPlayerESP(player)
		removePlayerESP(player)
		local entry = {
			drawings    = makeDrawings(),
			respawnConn = nil,
		}
		-- Init the static dark background for hp bar
		entry.drawings.hpBg.Color = Color3.fromRGB(30, 30, 30)
		activeESPs.players[player] = entry

		entry.respawnConn = player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if Players:FindFirstChild(player.Name) then addPlayerESP(player) end
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer then addPlayerESP(p) end
	end
	local _pAddConn = Players.PlayerAdded:Connect(function(p)   addPlayerESP(p)   end)
	local _pRemConn = Players.PlayerRemoving:Connect(function(p) removePlayerESP(p) end)

	-- ── World ESP management ──────────────────────────────────────────────────────

	local function removeWorldESP(model)
		local e = activeESPs.world[model]
		if not e then return end
		for _, c in ipairs(e.conns) do pcall(function() c:Disconnect() end) end
		destroyDrawings(e.drawings)
		activeESPs.world[model] = nil
	end

	local function addWorldESP(model, kind)
		if activeESPs.world[model] then return end
		local hum  = model:FindFirstChildWhichIsA("Humanoid")
		local d    = makeDrawings()
		d.hpBg.Color = Color3.fromRGB(30, 30, 30)

		local entry = {
			kind        = kind,
			hum         = hum,
			displayName = getDisplayName(model),
			drawings    = d,
			conns       = {},
		}
		activeESPs.world[model] = entry

		-- Reactive cleanup: remove when model is parented out of the game.
		local ancestryConn = model.AncestryChanged:Connect(function(_, parent)
			if not parent then removeWorldESP(model) end
		end)
		table.insert(entry.conns, ancestryConn)

		-- Cleanup when the mob/NPC dies.
		if hum then
			local diedConn = hum.Died:Connect(function()
				task.delay(2, function() removeWorldESP(model) end)
			end)
			table.insert(entry.conns, diedConn)
		end
	end

	local function tryAddWorldEntity(obj)
		if not obj:IsA("Model") then return end
		if isPlayerChar(obj) then return end
		if activeESPs.world[obj] then return end
		local kind = getEntityKind(obj)
		if kind then addWorldESP(obj, kind) end
	end

	-- Initial scan of existing workspace children.
	for _, obj in ipairs(Workspace:GetChildren()) do
		tryAddWorldEntity(obj)
	end

	-- Watch for entities added while running.
	local _wsAddConn = Workspace.ChildAdded:Connect(function(obj)
		task.defer(tryAddWorldEntity, obj)
	end)

	-- ── Environment toggles ───────────────────────────────────────────────────────

	local _origFogEnd        = nil
	local _origGlobalShadows = nil
	local _origAmbient       = nil
	local _rainConn          = nil
	local _snowConn          = nil
	local _origRain          = {}
	local _origSnow          = {}

	local RAIN_PATS = { "rain","drizzle","precipitation","raindrop","downpour","raineffect","weatherrain" }
	local SNOW_PATS = { "snow","blizzard","flake","hail","frost","sleet" }

	local function matchPats(name, pats)
		name = name:lower()
		for _, p in ipairs(pats) do if name:find(p, 1, true) then return true end end
		return false
	end

	local function applyNoFog()
		if not _origFogEnd then _origFogEnd = Lighting.FogEnd end
		Lighting.FogEnd = 1e5
	end
	local function restoreFog()
		if _origFogEnd then Lighting.FogEnd = _origFogEnd; _origFogEnd = nil end
	end

	local function disableParticle(p, store)
		if not p.Parent then return end
		if not store[p] then store[p] = p.Enabled end
		pcall(function() p.Enabled = false end)
	end
	local function scanParticles(root, pats, store)
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("ParticleEmitter") and matchPats(p.Name, pats) then
				disableParticle(p, store)
			end
		end
	end

	local function applyNoRain()
		scanParticles(Workspace, RAIN_PATS, _origRain)
		scanParticles(Lighting,  RAIN_PATS, _origRain)
		if not _rainConn then
			_rainConn = Workspace.DescendantAdded:Connect(function(p)
				if p:IsA("ParticleEmitter") and matchPats(p.Name, RAIN_PATS) then
					task.defer(disableParticle, p, _origRain)
				end
			end)
		end
	end
	local function restoreRain()
		if _rainConn then _rainConn:Disconnect(); _rainConn = nil end
		for p, orig in pairs(_origRain) do pcall(function() p.Enabled = orig end) end
		table.clear(_origRain)
	end

	local function applyNoSnow()
		scanParticles(Workspace, SNOW_PATS, _origSnow)
		scanParticles(Lighting,  SNOW_PATS, _origSnow)
		if not _snowConn then
			_snowConn = Workspace.DescendantAdded:Connect(function(p)
				if p:IsA("ParticleEmitter") and matchPats(p.Name, SNOW_PATS) then
					task.defer(disableParticle, p, _origSnow)
				end
			end)
		end
	end
	local function restoreSnow()
		if _snowConn then _snowConn:Disconnect(); _snowConn = nil end
		for p, orig in pairs(_origSnow) do pcall(function() p.Enabled = orig end) end
		table.clear(_origSnow)
	end

	local function applyFullBright()
		if not _origGlobalShadows then _origGlobalShadows = Lighting.GlobalShadows end
		if not _origAmbient       then _origAmbient       = Lighting.Ambient end
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.new(1, 1, 1)
	end
	local function restoreFullBright()
		if _origGlobalShadows ~= nil then Lighting.GlobalShadows = _origGlobalShadows; _origGlobalShadows = nil end
		if _origAmbient            then Lighting.Ambient = _origAmbient;       _origAmbient = nil end
	end

	-- ── UI Sections ───────────────────────────────────────────────────────────────

	local playerSec = visualsTab:AddSection("Player ESP")
	playerSec:AddToggle("PlayerESPEnabled", {
		Title = "Enable", Icon = "solar/user-bold", Default = false,
		Callback = function(v) playerEsp.enabled = v end,
	})
	playerSec:AddColorpicker("PlayerESPColor", {
		Title = "Color", Default = playerEsp.color,
		Callback = function(v) playerEsp.color = v end,
	})
	playerSec:AddToggle("PlayerESPName", {
		Title = "Name", Default = true,
		Callback = function(v) playerEsp.name = v end,
	})
	playerSec:AddToggle("PlayerESPDistance", {
		Title = "Distance", Default = true,
		Callback = function(v) playerEsp.distance = v end,
	})
	playerSec:AddToggle("PlayerESPHealth", {
		Title = "Health Bar", Default = false,
		Callback = function(v) playerEsp.health = v end,
	})
	playerSec:AddToggle("PlayerESPClan", {
		Title = "Show Clan", Default = true,
		Callback = function(v) playerEsp.showClan = v end,
	})
	playerSec:AddToggle("PlayerESPInfo", {
		Title = "Show Info (Eyes / Sub)", Default = true,
		Callback = function(v) playerEsp.showInfo = v end,
	})
	playerSec:AddToggle("PlayerESPShowBox", {
		Title = "Show Box", Default = true,
		Callback = function(v) playerEsp.showBox = v end,
	})
	playerSec:AddToggle("PlayerESPBloodBar", {
		Title = "Blood Bar", Default = false,
		Callback = function(v) playerEsp.bloodBar = v end,
	})
	playerSec:AddToggle("PlayerESPChakraBar", {
		Title = "Chakra Bar", Default = false,
		Callback = function(v) playerEsp.chakraBar = v end,
	})
	playerSec:AddToggle("PlayerESPScaleText", {
		Title = "Scale Text at Distance",
		Default = false,
		Callback = function(v) playerEsp.scaleText = v end,
	})
	playerSec:AddSlider("PlayerESPMaxDist", {
		Title = "Max Distance", Default = 1000, Min = 100, Max = 3000, Rounding = 0,
		Callback = function(v) playerEsp.maxDist = v end,
	})

	local npcSec = visualsTab:AddSection("NPC ESP")
	npcSec:AddToggle("NPCESPEnabled", {
		Title = "Enable", Icon = "solar/user-speak-bold", Default = false,
		Callback = function(v) npcEsp.enabled = v end,
	})
	npcSec:AddColorpicker("NPCESPColor", {
		Title = "Color", Default = npcEsp.color,
		Callback = function(v) npcEsp.color = v end,
	})
	npcSec:AddSlider("NPCESPMaxDist", {
		Title = "Max Distance", Default = 500, Min = 50, Max = 5000, Rounding = 0,
		Callback = function(v) npcEsp.maxDist = v end,
	})

	local mobSec = visualsTab:AddSection("Mob ESP")
	mobSec:AddToggle("MobESPEnabled", {
		Title = "Enable", Icon = "solar/danger-bold", Default = false,
		Callback = function(v) mobEsp.enabled = v end,
	})
	mobSec:AddColorpicker("MobESPColor", {
		Title = "Color", Default = mobEsp.color,
		Callback = function(v) mobEsp.color = v end,
	})
	mobSec:AddToggle("MobESPHealth", {
		Title = "Health Bar", Default = false,
		Callback = function(v) mobEsp.health = v end,
	})
	mobSec:AddSlider("MobESPMaxDist", {
		Title = "Max Distance", Default = 500, Min = 50, Max = 5000, Rounding = 0,
		Callback = function(v) mobEsp.maxDist = v end,
	})

	local envSec = visualsTab:AddSection("Environment")
	envSec:AddToggle("NoFog",      { Title = "Remove Fog",  Icon = "solar/cloud-bold",         Default = false, Callback = function(v) if v then applyNoFog()      else restoreFog()      end end })
	envSec:AddToggle("NoRain",     { Title = "Remove Rain", Icon = "solar/cloud-drizzle-bold", Default = false, Callback = function(v) if v then applyNoRain()     else restoreRain()     end end })
	envSec:AddToggle("NoSnow",     { Title = "Remove Snow", Icon = "solar/snowflake-bold",     Default = false, Callback = function(v) if v then applyNoSnow()     else restoreSnow()     end end })
	envSec:AddToggle("FullBright", { Title = "Fullbright",  Icon = "solar/sun-bold",           Default = false, Callback = function(v) if v then applyFullBright() else restoreFullBright() end end })

	-- ── Render helpers ────────────────────────────────────────────────────────────

	-- Renders a box + name + dist + optional health bar using the focal-length shortcut.
	-- sp = Vector2 screen position of HRP, depth = Z depth (studs),
	-- topOff/botOff = world studs above/below HRP for box edges.
	local function renderBox(d, sp, depth, focalLen, topOff, botOff, color)
		local topPx  = math.floor(topOff * focalLen / depth)
		local botPx  = math.floor(botOff * focalLen / depth)
		local h      = math.max(1, topPx + botPx)
		local w      = math.max(1, math.floor(h * 0.55))
		local x      = math.floor(sp.X)
		local topY   = math.floor(sp.Y - topPx)

		d.box.Size     = Vector2.new(w, h)
		d.box.Position = Vector2.new(x - w * 0.5, topY)
		d.box.Color    = color
		d.box.Visible  = true
		return x, topY, w, h
	end

	local function renderHealthBar(d, x, topY, w, h, hpPct, visible)
		if not visible then
			d.hpBg.Visible = false
			d.hpBar.Visible = false
			return
		end
		local barW  = 3
		local barX  = math.floor(x - w * 0.5) - barW - 2
		local hpH   = math.max(1, math.floor(h * hpPct))
		d.hpBg.Size     = Vector2.new(barW, h)
		d.hpBg.Position = Vector2.new(barX, topY)
		d.hpBg.Visible  = true
		d.hpBar.Size     = Vector2.new(barW, hpH)
		d.hpBar.Position = Vector2.new(barX, topY + h - hpH)
		d.hpBar.Color    = Color3.fromRGB(math.floor(255 * (1 - hpPct)), math.floor(255 * hpPct), 0)
		d.hpBar.Visible  = true
	end

	-- ── Per-frame rendering ───────────────────────────────────────────────────────

	-- Reused table to track which players were rendered this frame.
	-- Avoids allocating a new table every RenderStepped call.
	local _frameDrawn = {}

	local C_CLAN = Color3.fromRGB(190, 160, 220)  -- soft muted purple for clan label
	local C_INFO = Color3.fromRGB(210, 210, 210)  -- light grey for info line

	local function renderPlayerESP(d, shared, info, focalLen)
		-- Box (optional)
		if playerEsp.showBox then
			renderBox(d, shared.rootSp, shared.depth, focalLen, 3.5, 3.0, playerEsp.color)
		else
			d.box.Visible = false
		end
		local x   = math.floor(shared.rootSp.X)
		local topPx = math.floor(3.5 * focalLen / shared.depth)
		local botPx = math.floor(3.0 * focalLen / shared.depth)
		local h   = math.max(1, topPx + botPx)
		local w   = math.max(1, math.floor(h * 0.55))
		local topY = math.floor(shared.rootSp.Y - topPx)

		-- Scale text size with distance when the option is enabled.
		-- Further away → larger text so names stay readable even with tiny boxes.
		local baseTextSize = 14
		if playerEsp.scaleText then
			local distFrac = math.clamp(shared.dist / math.max(playerEsp.maxDist, 1), 0, 1)
			baseTextSize = math.floor(14 + distFrac * 10)  -- 14px close → 24px at max dist
		end

		-- Text is shown when: scale mode is on (always show), OR box is tall enough to read.
		local textOk = playerEsp.scaleText or h >= TEXT_MIN_H

		-- Name + clan gap depends on whether both labels are shown.
		local clanSize = math.max(9, math.floor(baseTextSize * 0.8))
		local nameGap  = math.floor(baseTextSize * 1.2)
		local clanGap  = math.floor(clanSize * 1.1)

		local hasClan = textOk and playerEsp.showClan and info and info.bloodline
		if playerEsp.name and textOk then
			d.name.Text     = shared.name
			d.name.Size     = baseTextSize
			d.name.Color    = playerEsp.color
			d.name.Position = Vector2.new(x, hasClan and (topY - nameGap - clanGap) or (topY - nameGap))
			d.name.Visible  = true
		else
			d.name.Visible = false
		end

		if hasClan then
			d.clan.Text     = info.bloodline
			d.clan.Size     = clanSize
			d.clan.Color    = C_CLAN
			d.clan.Position = Vector2.new(x, topY - clanGap)
			d.clan.Visible  = true
		else
			d.clan.Visible = false
		end

		local distSize = math.max(9, math.floor(baseTextSize * 0.9))
		if playerEsp.distance and textOk then
			d.dist.Text     = string.format("%.0f m", shared.dist)
			d.dist.Size     = distSize
			d.dist.Color    = playerEsp.color
			d.dist.Position = Vector2.new(x, topY + h + 4)
			d.dist.Visible  = true
		else
			d.dist.Visible = false
		end

		-- Info line: awakening · sub · CS · Freshie
		local infoSize = math.max(9, math.floor(baseTextSize * 0.8))
		if playerEsp.showInfo and info and textOk then
			local pieces = {}
			if info.awakening  then pieces[#pieces+1] = info.awakening  end
			if info.sub == false then pieces[#pieces+1] = "No Sub"      end
			if info.sensing    then pieces[#pieces+1] = "CS"            end
			if info.freshie    then pieces[#pieces+1] = "Freshie"       end
			if #pieces > 0 then
				d.info.Text     = table.concat(pieces, " · ")
				d.info.Size     = infoSize
				d.info.Color    = C_INFO
				d.info.Position = Vector2.new(x, topY + h + 4 + distSize + 3)
				d.info.Visible  = true
			else
				d.info.Visible = false
			end
		else
			d.info.Visible = false
		end

		-- Left HP bar (existing)
		renderHealthBar(d, x, topY, w, h, shared.hpPct, playerEsp.health and playerEsp.showBox)

		-- Blood bar (right side): dark red fill proportional to HP.
		-- Blood damage mirrors HP damage (server confirmed from dump).
		-- Always dark red — visually distinct from the green/red HP bar on the left.
		if playerEsp.bloodBar and playerEsp.showBox then
			local barW      = 4
			local barX      = math.floor(x + w * 0.5) + 3
			local barH_fill = math.floor(h * shared.hpPct)
			d.bloodBg.Size     = Vector2.new(barW, h)
			d.bloodBg.Position = Vector2.new(barX, topY)
			d.bloodBg.Visible  = true
			if barH_fill > 0 then
				d.bloodBar.Size     = Vector2.new(barW, barH_fill)
				d.bloodBar.Position = Vector2.new(barX, topY)
				d.bloodBar.Color    = Color3.fromRGB(160, 0, 0)  -- always dark red
				d.bloodBar.Visible  = true
			else
				d.bloodBar.Visible = false
			end
		else
			d.bloodBg.Visible  = false
			d.bloodBar.Visible = false
		end

		-- Chakra bar (below box): only renders when chakraPct data is available.
		-- Backpack.chakra is not replicated for other players, so this only works
		-- when the game exposes chakra in ReplicatedStorage.Settings[playerName].
		if playerEsp.chakraBar then
			local chakraPct = info and info.chakraPct   -- nil when unavailable
			if chakraPct and chakraPct >= 0 then
				local barH2 = 4
				local barY  = topY + h + (playerEsp.distance and (distSize + 8) or 4)
				local barX  = math.floor(x - w * 0.5)
				local chakW = math.max(0, math.floor(w * chakraPct))
				d.chakraBg.Size     = Vector2.new(w, barH2)
				d.chakraBg.Position = Vector2.new(barX, barY)
				d.chakraBg.Visible  = true
				if chakW > 0 then
					d.chakraBar.Size     = Vector2.new(chakW, barH2)
					d.chakraBar.Position = Vector2.new(barX, barY)
					d.chakraBar.Color    = Color3.fromRGB(30, 100, 255)
					d.chakraBar.Visible  = true
				else
					d.chakraBar.Visible = false
				end
			else
				-- No chakra data available — hide both background and fill.
				d.chakraBg.Visible  = false
				d.chakraBar.Visible = false
			end
		else
			d.chakraBg.Visible  = false
			d.chakraBar.Visible = false
		end
	end

	local function renderWorldESP(model, entry, camPos, cam, focalLen)
		local cfg = entry.kind == "mob" and mobEsp or npcEsp
		if not cfg.enabled then hideDrawings(entry.drawings); return end

		local hum = entry.hum
		if hum and hum.Health <= 0 then hideDrawings(entry.drawings); return end

		-- Use HRP or any BasePart for screen position.
		local hrp = model:FindFirstChild("HumanoidRootPart")
			     or model:FindFirstChildWhichIsA("BasePart")
		if not hrp then hideDrawings(entry.drawings); return end

		local dist = (hrp.Position - camPos).Magnitude
		if dist > cfg.maxDist then hideDrawings(entry.drawings); return end

		local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
		if not onScreen or sp.Z <= 0 then hideDrawings(entry.drawings); return end

		local d = entry.drawings
		-- NPCs/Mobs are roughly the same size as player characters.
		local x, topY, w, h = renderBox(d, Vector2.new(sp.X, sp.Y), sp.Z, focalLen, 3.5, 3.0, cfg.color)

		local textOk = h >= TEXT_MIN_H

		d.name.Text     = entry.displayName
		d.name.Color    = cfg.color
		d.name.Position = Vector2.new(x, topY - 15)
		d.name.Visible  = textOk

		d.dist.Text     = string.format("%.0f m", dist)
		d.dist.Color    = cfg.color
		d.dist.Position = Vector2.new(x, topY + h + 4)
		d.dist.Visible  = textOk

		-- Health bar for mobs
		if entry.kind == "mob" and mobEsp.health and hum and hum.MaxHealth > 0 then
			local max   = hum.MaxHealth
			local hpPct = math.clamp(hum.Health / max, 0, 1)
			renderHealthBar(d, x, topY, w, h, hpPct, true)
		else
			d.hpBg.Visible  = false
			d.hpBar.Visible = false
		end
	end

	-- ── Main update (called every RenderStepped from init.luau) ──────────────────

	local function update(data)
		local cam = data.cam
		if not cam then return end

		local focalLen = getFocalLen(cam)

		-- ── Player ESP ─────────────────────────────────────────────────────────────
		-- Use the pre-computed player entries from the shared render loop.
		-- No WorldToViewportPoint calls needed here.

		table.clear(_frameDrawn)

		-- Font sync: check once per second if the Fluent font changed and propagate
		-- to all active Drawing.Text objects so ESP text matches the GUI font.
		local now = tick()
		if now - _fontSyncTick >= 1 then
			_fontSyncTick = now
			local newFont = readFluentFont()
			if newFont ~= _curFont then
				_curFont = newFont
				for _, e in pairs(activeESPs.players) do applyFont(e.drawings, newFont) end
				for _, e in pairs(activeESPs.world)   do applyFont(e.drawings, newFont) end
			end
		end

		local _isWL = _G.MYA_BL_IsWL

		if playerEsp.enabled then
			for _, shared in ipairs(data.players) do
				local espEntry = activeESPs.players[shared.player]
				if not espEntry then continue end
				-- Whitelisted players: hide their ESP and skip rendering
				if _isWL and _isWL(shared.player, "esp") then
					hideDrawings(espEntry.drawings)
					_frameDrawn[shared.player] = true
					continue
				end
				if shared.onScreen and shared.depth > 0 and shared.dist <= playerEsp.maxDist then
					renderPlayerESP(espEntry.drawings, shared, getPlayerInfo(shared.player), focalLen)
					_frameDrawn[shared.player] = true
				end
			end
		end

		-- Hide any player whose drawings were not refreshed this frame.
		for player, espEntry in pairs(activeESPs.players) do
			if not _frameDrawn[player] then
				hideDrawings(espEntry.drawings)
			end
		end

		-- ── World ESP (NPC + Mob) ─────────────────────────────────────────────────
		-- Entities are tracked via the event-driven cache above.
		-- One WorldToViewportPoint call per entity per frame (down from three).

		local camPos = cam.CFrame.Position
		for model, entry in pairs(activeESPs.world) do
			renderWorldESP(model, entry, camPos, cam, focalLen)
		end
	end

	-- ── Unmount ───────────────────────────────────────────────────────────────────

	local function unmount()
		_paConn:Disconnect(); _prConn:Disconnect()
		_pAddConn:Disconnect(); _pRemConn:Disconnect()
		_wsAddConn:Disconnect()

		for p in pairs(activeESPs.players) do removePlayerESP(p) end
		for m in pairs(activeESPs.world)   do removeWorldESP(m)  end

		restoreFog(); restoreRain(); restoreSnow(); restoreFullBright()
	end

	return { update = update, unmount = unmount }
end
