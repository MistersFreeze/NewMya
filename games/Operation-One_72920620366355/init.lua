--[[
  Operation One (PlaceId 72920620366355)
  Loads runtime.lua (concatenates runtime/*.lua fragments) then gui.lua from the same folder.
]]

local M = {}

local function normalizeBase(url)
	if not url or #url == 0 then
		return ""
	end
	if string.sub(url, -1) ~= "/" then
		return url .. "/"
	end
	return url
end

local function stripBom(s)
	if typeof(s) ~= "string" then
		return s
	end
	if string.byte(s, 1) == 239 and string.byte(s, 2) == 187 and string.byte(s, 3) == 191 then
		return string.sub(s, 4)
	end
	return s
end

local function looksLikeHtml(s)
	if typeof(s) ~= "string" or #s == 0 then
		return false
	end
	local sample = string.lower(string.sub(s, 1, 256))
	return string.find(sample, "<!doctype html", 1, true) ~= nil
		or string.find(sample, "<html", 1, true) ~= nil
end

-- Same shape as hub `fetchPath`: repo root may be workspace root or `New_Mya/` folder.
local function pathSuffixVariants(suffix)
	local clean = (suffix or ""):gsub("^/", "")
	local stripped = string.gsub(clean, "^New_Mya/", "")
	local prefixed = "New_Mya/" .. stripped
	local variants = {}
	local function add(v)
		for _, x in ipairs(variants) do
			if x == v then
				return
			end
		end
		table.insert(variants, v)
	end
	add(clean)
	add(stripped)
	add(prefixed)
	return variants
end

function M.mount(ctx)
	local path = (ctx.gameScriptPath or ""):gsub("\\", "/")
	local dir = path:match("^(.*)/[^/]+$") or ""
	local repoBase = normalizeBase(ctx.baseUrl)

	local function suffixFromAbsoluteUrl(u)
		local nu = u:gsub("\\", "/")
		local nb = repoBase
		if string.sub(nu, 1, #nb) == nb then
			return string.sub(nu, #nb + 1)
		end
		return nil
	end

	local function tryLocalRead(relSuffix)
		local g = typeof(getgenv) == "function" and getgenv()
		local root = g and g.MYA_LOCAL_ROOT
		if not root or typeof(readfile) ~= "function" then
			return nil, nil
		end
		local nr = root:gsub("\\", "/")
		if string.sub(nr, -1) ~= "/" then
			nr = nr .. "/"
		end
		for _, rel in ipairs(pathSuffixVariants(relSuffix)) do
			local full = nr .. rel
			for _, p in ipairs({ full, full:gsub("/", "\\") }) do
				local ok, body = pcall(readfile, p)
				if ok and typeof(body) == "string" and #body > 0 then
					return stripBom(body), rel
				end
			end
		end
		return nil, nil
	end

	local function fetchBySuffix(relSuffix)
		local body, winRel = tryLocalRead(relSuffix)
		if typeof(body) == "string" and typeof(winRel) == "string" then
			return body, winRel
		end

		local lastErr = ""
		for _, rel in ipairs(pathSuffixVariants(relSuffix)) do
			local url = repoBase .. rel
			local ok, res = pcall(function()
				return game:HttpGet(url, true)
			end)
			if ok and typeof(res) == "string" and #res > 0 then
				local cleaned = stripBom(res)
				if not looksLikeHtml(cleaned) then
					return cleaned, rel
				end
				lastErr = "html:" .. url
			else
				lastErr = tostring(res)
			end
		end
		return nil, lastErr
	end

	local function fetch(u)
		local suf = suffixFromAbsoluteUrl(u)
		if not suf then
			local ok, res = pcall(function()
				return game:HttpGet(u, true)
			end)
			if ok and typeof(res) == "string" and #res > 0 then
				return stripBom(res)
			end
			error("Operation One: fetch URL not under BASE_URL (set ctx.baseUrl to hosted repo root): " .. tostring(u))
		end
		local body, second = fetchBySuffix(suf)
		if typeof(body) ~= "string" then
			error("Operation One: fetch failed for " .. suf .. " — " .. tostring(second))
		end
		return body
	end

	_G.MYA_REPO_BASE = repoBase
	_G.MYA_FETCH = fetch

	local runSrc, runWinRel = fetchBySuffix(dir .. "/runtime.lua")
	if typeof(runSrc) ~= "string" then
		error(
			"Operation One: runtime.lua missing (local + HTTP variants). Last error: "
				.. tostring(runWinRel)
				.. ". Tried suffixes under "
				.. repoBase
		)
	end
	if looksLikeHtml(runSrc) then
		error("Operation One: runtime.lua response looked like HTML")
	end

	if typeof(runWinRel) ~= "string" then
		error("Operation One: internal — no winning path for runtime.lua")
	end
	local parentRel = string.match(runWinRel, "^(.*)/[^/]+$") or ""
	local base = repoBase .. parentRel .. "/"

	local runChunk, runCompileErr = loadstring(runSrc, "@Operation-One/runtime")
	if typeof(runChunk) ~= "function" then
		error("Operation One: runtime.lua failed to compile: " .. tostring(runCompileErr))
	end
	local runLoader = runChunk()
	if typeof(runLoader) ~= "function" then
		error("Operation One: runtime.lua must return the bundle loader")
	end
	runLoader({ base = base, fetch = fetch, repoBase = repoBase })

	local guiSrc, guiErr = fetchBySuffix(dir .. "/gui.lua")
	if typeof(guiSrc) ~= "string" then
		error("Operation One: gui.lua missing: " .. tostring(guiErr))
	end
	if looksLikeHtml(guiSrc) then
		error("Operation One: gui.lua response looked like HTML")
	end
	local guiChunk, guiCompileErr = loadstring(guiSrc, "@Operation-One/gui")
	if typeof(guiChunk) ~= "function" then
		error("Operation One: gui.lua failed to compile: " .. tostring(guiCompileErr))
	end
	guiChunk()

	if typeof(_G.MYA_OP1_RUN_UI_SYNC) == "function" then
		_G.MYA_OP1_RUN_UI_SYNC()
	end

	ctx.notify("Operation One loaded")
end

function M.unmount()
	if typeof(_G.unload_mya) == "function" then
		pcall(_G.unload_mya)
	end
end

return M
