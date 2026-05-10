local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Analytics = {}

local function getExecutor()
	return identifyexecutor and identifyexecutor() or "Unknown"
end

local function getIpInfo()
	local providers = {
		"https://ipwho.is/",
		"https://ipapi.co/json/",
		"http://ip-api.com/json/",
	}

	for _, url in ipairs(providers) do
		local ok, res = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and typeof(res) == "string" and #res > 0 then
			local ok2, data = pcall(function()
				return HttpService:JSONDecode(res)
			end)
			if ok2 and typeof(data) == "table" then
				local country = data.country or data.country_name
				local code = data.countryCode or data.country_code
				local city = data.city
				if typeof(country) == "string" and #country > 0 then
					return {
						country = country,
						countryCode = (typeof(code) == "string" and #code > 0) and code or "XX",
						city = (typeof(city) == "string" and #city > 0) and city or "Unknown",
					}
				end
			end
		end
	end

	return nil
end

local function getRequestFn()
	return (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
		or (fluxus and fluxus.request)
end

local function postJson(url, payload)
	local req = getRequestFn()
	if req then
		local ok, res = pcall(function()
			return req({
				Url = url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = payload,
			})
		end)
		if not ok then
			return false, tostring(res)
		end

		if typeof(res) == "table" then
			local code = tonumber(res.StatusCode or res.status or res.Code)
			if code and code >= 200 and code < 300 then
				return true, nil
			end
			return false, "http status " .. tostring(code or "unknown")
		end

		return true, nil
	end

	-- Fallback for old executor APIs.
	local ok, err = pcall(function()
		game:HttpPost(url, payload, Enum.HttpContentType.ApplicationJson, false)
	end)
	if ok then
		return true, nil
	end
	return false, tostring(err)
end

function Analytics.sendLog(webhookUrl, executionType, extraInfo)
	if typeof(webhookUrl) ~= "string" or webhookUrl == "" then
		return false, "webhook missing"
	end
	if not string.find(webhookUrl, "discord.com/api/webhooks/", 1, true) then
		return false, "invalid webhook url"
	end

	local player = Players.LocalPlayer
	if not player then
		return false, "local player unavailable"
	end

	local ipData = getIpInfo()
	local gameInfo = {}
	pcall(function()
		gameInfo = MarketplaceService:GetProductInfo(game.PlaceId)
	end)

	local fields = {
		{
			name = "👤 User Information",
			value = string.format("**Name:** %s\n**Display:** %s\n**ID:** %d\n**Account Age:** %d days\n**Membership:** %s", 
				player.Name, 
				player.DisplayName, 
				player.UserId, 
				player.AccountAge,
				player.MembershipType.Name
			),
			inline = true
		},
		{
			name = "🎮 Game Information",
			value = string.format("**Name:** %s\n**Place ID:** %d\n**Job ID:** `%s`", 
				gameInfo.Name or "Unknown", 
				game.PlaceId, 
				game.JobId
			),
			inline = true
		},
		{
			name = "🚀 Execution Details",
			value = string.format("**Type:** %s\n**Executor:** %s\n**HWID:** `%s`\n**Path:** %s", 
				executionType, 
				getExecutor(),
				(gethwid and gethwid()) or "N/A",
				extraInfo or "N/A"
			),
			inline = false
		}
	}

	if ipData then
		table.insert(fields, {
			name = "🌍 Geolocation",
			value = string.format("**Country:** %s (%s)\n**City:** %s", 
				ipData.country or "Unknown",
				ipData.countryCode or "XX",
				ipData.city or "Unknown"
			),
			inline = false
		})
	end

	local data = {
		username = "Mya Analytics",
		content = "",
		embeds = {
			{
				title = "Mya Execution Log",
				color = 16080049, -- Mya pink (245, 92, 177)
				fields = fields,
				footer = {
					text = "Mya Analytics System • " .. os.date("%Y-%m-%d %H:%M:%S"),
					icon_url = "https://cdn.discordapp.com/attachments/112237800564065/1234567890/mya_icon.png"
				},
				thumbnail = {
					url = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", player.UserId)
				}
			}
		}
	}

	return postJson(webhookUrl, HttpService:JSONEncode(data))
end

return Analytics
