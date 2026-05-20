return function(ctx)
	local shopTab    = ctx.shopTab
	local localPlayer = ctx.localPlayer
	local Fluent     = ctx.Fluent

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DataEvent = nil
	pcall(function() DataEvent = ReplicatedStorage.Events.DataEvent end)

	local function fire(...)
		if DataEvent then pcall(function() DataEvent:FireServer(...) end) end
	end

	local function notify(msg)
		pcall(function() Fluent:Notify({ Title = "Shop", Content = msg, Duration = 3 }) end)
	end

	-- ── Helpers ───────────────────────────────────────────────────────────────────

	-- Tries to open the WipeShop GUI directly (client-side GUI toggle).
	local function openWipeShop()
		pcall(function()
			local gui = localPlayer:FindFirstChild("PlayerGui")
			local ws  = gui and gui:FindFirstChild("WipeShop")
			if ws then
				ws.Enabled = true
				notify("Wipe Shop opened")
			else
				notify("Wipe Shop GUI not found")
			end
		end)
	end

	-- ── UI ────────────────────────────────────────────────────────────────────────

	local hairSec = shopTab:AddSection("Hair Shop")

	hairSec:AddButton({ Title = "Random Hairstyle (15 Ryo)",   Icon = "solar/user-bold",      Callback = function()
		fire("buyShopItem", "RandomHairstyle", 15)
		notify("Buying random hairstyle…")
	end })

	hairSec:AddButton({ Title = "Random Bold Hairstyle (5 Ryo)", Icon = "solar/user-bold",    Callback = function()
		fire("buyShopItem", "RandomBoldHairstyle", 5)
		notify("Buying random bold hairstyle…")
	end })

	hairSec:AddButton({ Title = "Random Hair Color (15 Ryo)",  Icon = "solar/palette-bold",    Callback = function()
		fire("buyShopItem", "RandomHairColor", 15)
		notify("Buying random hair color…")
	end })

	local accSec = shopTab:AddSection("Accessories")

	accSec:AddButton({ Title = "Random Accessory (95 Ryo)",   Icon = "solar/star-bold",       Callback = function()
		fire("buyShopItem", "RandomAccessory", 95)
		notify("Buying random accessory…")
	end })

	local wipeSec = shopTab:AddSection("Wipe Shop")

	wipeSec:AddButton({ Title = "Open Wipe Shop", Icon = "solar/shop-bold", Callback = openWipeShop })

	wipeSec:AddParagraph({
		Title   = "Note",
		Content = "Shop buttons fire the game's own purchase events. Cost is deducted server-side.",
	})

	-- ── Cleanup ───────────────────────────────────────────────────────────────────

	local function update(data) end
	local function unmount() end
	return { update = update, unmount = unmount }
end
