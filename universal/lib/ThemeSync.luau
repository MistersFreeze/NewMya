--[[
  ThemeSync — shared Fluent theme color provider.

  Usage in any widget:
      local ts = ctx.themeSync
      local accent = ts.getAccent()
      local text   = ts.getText()
      local muted  = ts.getMuted()

  Colors update automatically when the user changes the theme.
  For RGB mode, call ts.update() each frame (ts.isRGB() returns true).
]]

return function(Fluent)

	-- ── Complete accent table (all FluentModded themes) ───────────────────────────
	-- Source: extracted from FluentModded.lua Accent = Color3.fromRGB(...) lines.
	-- Add new themes here; the GUI-scan fallback handles unknown custom themes.

	local R = Color3.fromRGB
	local ACCENTS = {
		-- ─ Standard palette ─────────────────────────────────────────────────────
		["Blood Red"]      = R(180,  10,  20),
		["AMOLED"]         = R(255, 255, 255),
		["RGB"]            = R(  0, 255, 180),  -- dynamic; caller should ts.update() each frame
		["Neon Cyber"]     = R( 57, 255,  20),
		["Arctic Frost"]   = R(100, 180, 240),
		["Cotton Candy"]   = R(255, 130, 190),
		["Blackhole"]      = R(255, 140,  30),
		["Cyanic"]         = R( 57, 197, 187),
		["Amber Glow"]     = R(255, 170,  40),
		-- ─ Module-defined themes ─────────────────────────────────────────────────
		["Deep Violet"]    = R( 97,  62, 167),
		["Cyan Frost"]     = R( 60, 165, 165),
		["Ash Gray"]       = R(150, 150, 150),
		["Charcoal"]       = R(102, 102, 102),
		["Pearl White"]    = R(214, 214, 214),
		["Hot Pink"]       = R(255, 120, 160),
		["Sky Blue"]       = R( 96, 205, 255),
		["Honey Gold"]     = R(255, 200,  90),
		["Lime Green"]     = R( 60, 200, 120),
		["Neon Purple"]    = R(180,   0, 255),
		["Deep Ocean"]     = R(  0, 150, 200),
		["Dark Forest"]    = R( 60, 180,  80),
		["Sunset Red"]     = R(255, 100,  80),
		["Midnight Blue"]  = R(100,  80, 200),
		["Soft Lavender"]  = R(180, 130, 255),
		["Mint Breeze"]    = R( 80, 220, 160),
		["Peach Glow"]     = R(255, 160, 120),
		["Coral Flame"]    = R(255,  90, 100),
		["Dark Indigo"]    = R( 75,   0, 130),
		["Acid Lime"]      = R(150, 255,  50),
		["Ruby Red"]       = R(224,  17,  95),
		["Royal Blue"]     = R( 15,  82, 186),
		["Emerald Green"]  = R( 80, 200, 120),
		["Warm Topaz"]     = R(255, 180,  80),
		["Onyx Black"]     = R(100, 100, 100),
		["Jade Stone"]     = R(  0, 180, 140),
		["Amber Gold"]     = R(255, 140,   0),
		["Rose Quartz"]    = R(200, 180, 220),
		["Obsidian Black"] = R( 80,  80,  90),
		["White Marble"]   = R(180, 180, 190),
		["Slate Blue"]     = R(120, 140, 160),
		["Warm Copper"]    = R(184, 115,  51),
		["Dark Bronze"]    = R(205, 127,  50),
		["Bright Silver"]  = R(192, 192, 192),
		["Platinum Gray"]  = R(229, 228, 226),
		["Titanium Gray"]  = R(135, 140, 145),
		["Cold Steel"]     = R(100, 110, 120),
		["Dark Iron"]      = R( 80,  85,  90),
		["Cool Nickel"]    = R(140, 145, 150),
		["Zinc Gray"]      = R(160, 165, 170),
		["Tin Gray"]       = R(150, 155, 160),
		["Lead Gray"]      = R( 85,  90, 100),
		["Mirror Chrome"]  = R(210, 215, 220),
		["Antique Brass"]  = R(181, 166,  66),
		["Dark Graphite"]  = R( 90,  95, 100),
		["Carbon Black"]   = R( 70,  75,  80),
		["Phantom Blue"]   = R( 80,  85, 110),
		["Spectre Indigo"] = R(100,  95, 130),
		["Ghost Gray"]     = R(110, 115, 125),
		["Deep Shadow"]    = R( 60,  65,  75),
		["Dark Purple"]    = R( 80,  45, 120),
		["Void Black"]     = R( 25,  30,  45),
		["Eclipse Dark"]   = R( 50,  45,  60),
		["Twilight Purple"]= R(120,  80, 150),
		["Golden Dawn"]    = R(255, 180, 100),
		["Dusk Violet"]    = R(100,  70, 130),
		["Aurora Teal"]    = R( 80, 220, 180),
		["Galaxy Purple"]  = R(160,  60, 220),
		["Nebula Pink"]    = R(200, 100, 160),
		["Comet Gold"]     = R(220, 200, 100),
		["Meteor Blaze"]   = R(255, 120,  40),
		["Silver Stardust"]= R(210, 210, 230),
		["Cosmic Violet"]  = R( 80,  60, 140),
		["Astral Purple"]  = R(130, 110, 200),
		["Celestial Blue"] = R(170, 150, 220),
		["Ethereal Violet"]= R(200, 180, 240),
		["Mystic Purple"]  = R(140, 100, 180),
		["Arcane Blue"]    = R( 80, 120, 200),
		["Runic Ember"]    = R(180, 100,  80),
		["Enchanted Violet"]= R(160, 120, 200),
		["Magical Pink"]   = R(220, 140, 200),
		["Dark Sorcery"]   = R(100,  80, 160),
		["Wizard Blue"]    = R( 80,  80, 180),
		["Dragon Fire"]    = R(220,  50,  20),
		["Phoenix Flame"]  = R(255, 100,  50),
		["Griffin Gold"]   = R(180, 160, 100),
		["Cloud White"]    = R(200, 200, 230),
		["Unicorn Pink"]   = R(255, 150, 200),
		["Fairy Green"]    = R(150, 220, 150),
		["Elven Green"]    = R(100, 180, 100),
		["Forge Brown"]    = R(160, 120,  80),
		["War Green"]      = R(100, 120,  60),
		["Swamp Green"]    = R(120, 140,  80),
		["Poison Green"]   = R( 80, 100,  50),
		["Demon Blood"]    = R(160,  20,  20),
		["Angelic White"]  = R(220, 220, 250),
		["Valkyrie Mauve"] = R(200, 160, 220),
		["Shadow Black"]   = R( 50,  50,  60),
		["Rust Brown"]     = R(140,  80,  60),
		["Dark Steel"]     = R( 90,  90, 100),
	}

	-- ── Cached colors ─────────────────────────────────────────────────────────────

	local cache = {
		accent = R(245, 92, 177),
		text   = R(245, 245, 250),
		muted  = R(200, 170, 210),
	}

	-- ── GUI scan fallback (for unknown/custom themes) ─────────────────────────────
	-- After UpdateTheme(), Frame instances tagged with BackgroundColor3="Accent"
	-- carry the live accent. Used when the theme name isn't in the ACCENTS table.

	local function scanGUIForAccent()
		pcall(function()
			if not (Fluent and Fluent.GUI) then return end
			for _, d in ipairs(Fluent.GUI:GetDescendants()) do
				if d:IsA("Frame") then
					local c   = d.BackgroundColor3
					local lum = c.R + c.G + c.B
					if lum > 0.05 then  -- reject near-pure-black only
						cache.accent = c
						return
					end
				end
			end
		end)
	end

	-- ── Main update ───────────────────────────────────────────────────────────────

	local function update()
		local name = nil
		pcall(function() name = Fluent and Fluent.Theme end)

		-- Layer 1: hardcoded table (instant, covers all 90+ known themes)
		if name and ACCENTS[name] then
			cache.accent = ACCENTS[name]
		else
			-- Layer 2: GUI scan (handles custom/unknown themes)
			scanGUIForAccent()
		end

		-- Text / SubText: consistent across almost all themes; read from GUI if possible
		pcall(function()
			if Fluent and Fluent.Colors then
				if Fluent.Colors.Text    then cache.text  = Fluent.Colors.Text    end
				if Fluent.Colors.SubText then cache.muted = Fluent.Colors.SubText end
			end
		end)
	end

	-- ── Hook SetTheme so widgets auto-update on theme change ──────────────────────

	pcall(function()
		local orig = Fluent.SetTheme
		Fluent.SetTheme = function(self, theme)
			local r = orig(self, theme)
			task.defer(update)  -- defer so UpdateTheme() finishes first
			return r
		end
	end)

	update()

	-- ── Public API ────────────────────────────────────────────────────────────────

	return {
		getAccent = function() return cache.accent end,
		getText   = function() return cache.text   end,
		getMuted  = function() return cache.muted  end,
		isRGB     = function()
			local n = nil
			pcall(function() n = Fluent and Fluent.Theme end)
			return n == "RGB"
		end,
		update    = update,
	}
end
