local BASE_URL = "https://raw.githubusercontent.com/MistersFreeze/NewMya/main/"
if typeof(getgenv) == "function" and typeof(getgenv().MYA_BASE_URL) == "string" and #getgenv().MYA_BASE_URL > 0 then
	local u = getgenv().MYA_BASE_URL
	if string.sub(u, -1) ~= "/" then
		u = u .. "/"
	end
	BASE_URL = u
end

local PREFIX = "New_Mya/"
local CONFIG_PATH = "config/config.luau"
local HUB_PATH = "loaders/hub.luau"
local FLUENT_LIB_PATH = "lib/FluentModded.lua"

local function waitForGameReady()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local deadline = os.clock() + 2
	while game.PlaceId == 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

local function sanitizeSource(src: string): string
	if string.byte(src, 1) == 239 and string.byte(src, 2) == 187 and string.byte(src, 3) == 191 then
		return string.sub(src, 4)
	end
	return src
end

local function looksLikeHtml(src: string): boolean
	local sample = string.lower(string.sub(src, 1, 256))
	return string.find(sample, "<!doctype html", 1, true) ~= nil
		or string.find(sample, "<html", 1, true) ~= nil
		or string.find(sample, "<head", 1, true) ~= nil
		or string.find(sample, "error response", 1, true) ~= nil
		or string.find(sample, "404", 1, true) ~= nil
end

local function get(url: string): (string?, string?)
	local ok, res = pcall(function()
		return game:HttpGet(url, true)
	end)
	-- Fallback for executors that don't support the cache argument correctly
	if not ok or (ok and typeof(res) ~= "string") then
		ok, res = pcall(function()
			return game:HttpGet(url)
		end)
	end
	if ok and typeof(res) == "string" then
		return sanitizeSource(res), nil
	end
	return nil, tostring(res)
end

local function getCandidatePath(pathSuffix: string): (string?, string?)
	local primaryUrl = BASE_URL .. PREFIX .. pathSuffix
	local primary, primaryErr = get(primaryUrl)
	if primary and not looksLikeHtml(primary) then
		return primary, nil
	end
	local fallbackUrl = BASE_URL .. pathSuffix
	local fallback, fallbackErr = get(fallbackUrl)
	if fallback and not looksLikeHtml(fallback) then
		return fallback, nil
	end
	return nil,
		"primary("
			.. primaryUrl
			.. "): "
			.. tostring(primaryErr)
			.. " | fallback("
			.. fallbackUrl
			.. "): "
			.. tostring(fallbackErr)
end

local function runAnalytics(baseUrl: string, config: { [string]: any })
	if typeof(config) ~= "table" or config.ANON_ANALYTICS_ENABLED ~= true then
		return
	end
	local webhook = config.ANON_ANALYTICS_WEBHOOK_URL
	if typeof(webhook) ~= "string" or #webhook == 0 then
		warn("[Mya Analytics] Enabled but webhook is empty.")
		return
	end

	task.spawn(function()
		local src, err = getCandidatePath("lib/analytics.luau")
		if not src then
			warn("[Mya Analytics] fetch failed: " .. tostring(err))
			return
		end
		local chunk, compileErr = loadstring(src)
		if typeof(chunk) ~= "function" then
			warn("[Mya Analytics] compile failed: " .. tostring(compileErr))
			return
		end
		local okModule, analyticsOrErr = pcall(chunk)
		if not okModule then
			warn("[Mya Analytics] runtime failed: " .. tostring(analyticsOrErr))
			return
		end
		if typeof(analyticsOrErr) ~= "table" or typeof(analyticsOrErr.sendLog) ~= "function" then
			warn("[Mya Analytics] invalid module export.")
			return
		end
		local okSend, sendErr = analyticsOrErr.sendLog(webhook, "LoaderBoot", baseUrl .. "New_Mya/loaders/loader.luau")
		if not okSend then
			warn("[Mya Analytics] send failed: " .. tostring(sendErr))
		end
	end)
end

local function boot()
	if typeof(loadstring) ~= "function" then
		error("loadstring is not available.")
	end
	waitForGameReady()

	-- Fetch config + hub + Fluent library in parallel (one wall-clock wait for bootstrap network).
	local fetchState = {
		configReady = false,
		hubReady = false,
		fluentReady = false,
		configSrc = nil,
		configErr = nil,
		hubSrc = nil,
		hubErr = nil,
		fluentSrc = nil,
		fluentErr = nil,
	}
	task.spawn(function()
		local src, err = getCandidatePath(CONFIG_PATH)
		fetchState.configSrc, fetchState.configErr, fetchState.configReady = src, err, true
	end)
	task.spawn(function()
		local src, err = getCandidatePath(HUB_PATH)
		fetchState.hubSrc, fetchState.hubErr, fetchState.hubReady = src, err, true
	end)
	task.spawn(function()
		local src, err = getCandidatePath(FLUENT_LIB_PATH)
		fetchState.fluentSrc, fetchState.fluentErr, fetchState.fluentReady = src, err, true
	end)
	while not (fetchState.configReady and fetchState.hubReady and fetchState.fluentReady) do
		task.wait()
	end

	local configSrc, configErr = fetchState.configSrc, fetchState.configErr
	if not configSrc then
		error("config fetch failed: " .. tostring(configErr))
	end
	if #configSrc == 0 then
		local advice = ""
		if string.find(BASE_URL, "127.0.0.1", 1, true) or string.find(BASE_URL, "localhost", 1, true) then
			advice = "\nTip: Potassium may not support 127.0.0.1. Try using your actual local IP (e.g. 192.168.x.x)."
		end
		error("config fetch returned an empty string." .. advice)
	end
	local configChunk, configCompileErr = loadstring(configSrc)
	if typeof(configChunk) ~= "function" then
		error("config failed to compile: " .. tostring(configCompileErr))
	end
	local okConfig, configOrErr = pcall(configChunk)
	if not okConfig then
		error("config runtime error: " .. tostring(configOrErr))
	end
	if typeof(configOrErr) ~= "table" then
		warn("[Mya Debug] Config Source Start: " .. string.sub(configSrc, 1, 100))
		error("config must return a table (got " .. typeof(configOrErr) .. ").")
	end
	local config = configOrErr

	if typeof(fetchState.fluentSrc) == "string" and #fetchState.fluentSrc > 500 and not looksLikeHtml(fetchState.fluentSrc) then
		local genv = typeof(getgenv) == "function" and getgenv()
		if genv then
			pcall(function()
				genv.MYA_PREFETCH_FLUENT_SRC = sanitizeSource(fetchState.fluentSrc)
			end)
		end
	end
	runAnalytics(BASE_URL, config)

	local hubSrc, hubErr = fetchState.hubSrc, fetchState.hubErr
	if not hubSrc then
		error("hub fetch failed: " .. tostring(hubErr))
	end
	local hubChunk, hubCompileErr = loadstring(hubSrc)
	if typeof(hubChunk) ~= "function" then
		error("hub failed to compile: " .. tostring(hubCompileErr))
	end
	local hubMain = hubChunk()
	if typeof(hubMain) ~= "function" then
		error("hub must return function(BASE_URL, config).")
	end

	-- Previous session / partial unload can leave Fluent Modded thinking a window still exists while
	-- our hub `Window` reference is nil → "cannot create more than one window" + AddTab on nil. Purge first.
	pcall(function()
		if typeof(_G.unload_new_mya) == "function" then
			_G.unload_new_mya()
		end
	end)
	pcall(function()
		_G.MYA_FLUENT_SINGLETON = nil
	end)

	hubMain(BASE_URL, config)
end

local ok, err = pcall(boot)
if not ok then
	warn("[Mya Loader] " .. tostring(err))
end
