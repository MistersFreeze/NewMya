--[[
  New_Mya Junkie bridge loader.
  Upload this script to your Junkie product.

  It only does three things:
  1) normalize MYA_BASE_URL
  2) optionally set SCRIPT_KEY from JUNKIE_LICENSE_KEY
  3) fetch and run New_Mya/loaders/loader.luau from your host
]]

local MYA_BASE_URL = "https://raw.githubusercontent.com/MistersFreeze/NewMya/main/"
local JUNKIE_LICENSE_KEY = ""
local LOADER_PATH = "New_Mya/loaders/loader.luau"

local function normalizeUrl(url: string): string
	url = tostring(url or "")
	url = string.gsub(url, "^%s+", "")
	url = string.gsub(url, "%s+$", "")
	if string.sub(url, -1) ~= "/" then
		return url .. "/"
	end
	return url
end

local function sanitizeSource(src: string): string
	if string.byte(src, 1) == 239 and string.byte(src, 2) == 187 and string.byte(src, 3) == 191 then
		return string.sub(src, 4)
	end
	return src
end

local function looksLikeHtmlOrError(src: string): boolean
	local sample = string.lower(string.sub(src, 1, 300))
	return string.find(sample, "<!doctype html", 1, true) ~= nil
		or string.find(sample, "<html", 1, true) ~= nil
		or string.find(sample, "<head", 1, true) ~= nil
		or string.find(sample, "error response", 1, true) ~= nil
		or string.find(sample, "404", 1, true) ~= nil
end

local function httpGetSafe(url: string): (string?, string?)
	local ok, res = pcall(function()
		return game:HttpGet(url, true)
	end)
	if not ok then
		return nil, tostring(res)
	end
	if typeof(res) ~= "string" or #res == 0 then
		return nil, "empty response"
	end
	local clean = sanitizeSource(res)
	if looksLikeHtmlOrError(clean) then
		return nil, "received HTML/error page from " .. url
	end
	return clean, nil
end

local function fetchLoaderSource(base: string): (string?, string?)
	local tries = {
		base .. LOADER_PATH,
		base .. "loaders/loader.luau",
	}
	local lastErr = "unknown"
	for _, url in ipairs(tries) do
		local src, err = httpGetSafe(url)
		if src then
			return src, nil
		end
		lastErr = tostring(err)
	end
	return nil, lastErr
end

local function showError(message: string)
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

	local parent = localPlayer:WaitForChild("PlayerGui")
	if typeof(gethui) == "function" then
		parent = gethui()
	end

	local existing = parent:FindFirstChild("MyaNewJunkieError")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MyaNewJunkieError"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2147483647
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.None
	end)
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(480, 160)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	frame.Parent = gui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = frame

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -24, 1, -24)
	text.Position = UDim2.fromOffset(12, 12)
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(200, 180, 255)
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = "[New_Mya/Junkie] " .. tostring(message)
	text.Parent = frame
end

local function waitForGameReady()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local deadline = os.clock() + 3
	while game.PlaceId == 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

local function run()
	if typeof(getgenv) ~= "function" then
		error("getgenv is required for New_Mya Junkie loader.")
	end
	if typeof(loadstring) ~= "function" then
		error("loadstring is not available in this executor.")
	end

	waitForGameReady()

	local g = getgenv()
	local base = g.MYA_BASE_URL
	if typeof(base) ~= "string" or #base == 0 then
		base = MYA_BASE_URL
	end
	base = normalizeUrl(base)
	if #base < 8 or (string.sub(base, 1, 7) ~= "http://" and string.sub(base, 1, 8) ~= "https://") then
		error("MYA_BASE_URL must be a valid http/https URL.")
	end
	g.MYA_BASE_URL = base

	if typeof(JUNKIE_LICENSE_KEY) == "string" and #JUNKIE_LICENSE_KEY > 0 then
		g.SCRIPT_KEY = JUNKIE_LICENSE_KEY
	end

	local source, fetchErr = fetchLoaderSource(base)
	if not source then
		error("Failed to fetch New_Mya loader: " .. tostring(fetchErr))
	end
	local chunk, compileErr = loadstring(source, "@New_Mya/loaders/loader.luau")
	if typeof(chunk) ~= "function" then
		error("Failed to compile New_Mya loader: " .. tostring(compileErr))
	end
	chunk()
end

local ok, err = pcall(run)
if not ok then
	showError(tostring(err))
end
