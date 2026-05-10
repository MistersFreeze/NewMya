--[[
  Shared helpers for New_Mya (HttpGet, safe compile/run).
  MYA_LOCAL_ROOT + readfile maps URLs under the repo root to local files for dev.
]]

local Util = {}

local function norm(p: string): string
	return (p:gsub("\\", "/"))
end

local function tryReadfile(path: string): (string?, string?)
	if typeof(readfile) ~= "function" then
		return nil, "readfile unavailable"
	end
	local variants = { path, path:gsub("/", "\\"), norm(path) }
	local seen = {}
	for _, p in ipairs(variants) do
		if not seen[p] then
			seen[p] = true
			local ok, body = pcall(readfile, p)
			if ok and typeof(body) == "string" then
				return body, nil
			end
		end
	end
	return nil, "readfile failed"
end

function Util.httpGet(url: string): (string?, string?)
	local g = typeof(getgenv) == "function" and getgenv()
	local root = g and g.MYA_LOCAL_ROOT
	if root and typeof(root) == "string" and #root > 0 and typeof(readfile) == "function" then
		local nr = norm(root)
		if string.sub(nr, -1) ~= "/" then
			nr = nr .. "/"
		end
		local nu = norm(url)
		if string.sub(nu, 1, #nr) == nr then
			local body, err = tryReadfile(url)
			if body then
				return body, nil
			end
			return nil, err or "Local file read failed"
		end
	end
	local ok, result = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok then
		return result :: string, nil
	end
	return nil, tostring(result)
end

function Util.loadstringCompile(source: string, chunkName: string?): (any?, string?)
	local name = chunkName or "MyaChunk"
	if typeof(source) ~= "string" then
		return nil, "source is not a string"
	end
	if string.sub(source, 1, 3) == "\239\187\191" then
		source = string.sub(source, 4)
	end
	if #source == 0 then
		return nil, "empty source (check URL / hosting)"
	end
	local trimmed = source:match("^%s*(.-)%s*$") or source
	local headLo = string.lower(string.sub(trimmed, 1, 48))
	if string.sub(trimmed, 1, 1) == "<" or string.find(headLo, "<!doctype", 1, true) or string.find(headLo, "<html", 1, true) then
		return nil, "download looks like HTML, not Lua (wrong BASE_URL or private repo)"
	end
	local fn, compileErr = loadstring(source, "@" .. name)
	if typeof(fn) == "function" then
		return fn, nil
	end
	local detail = typeof(compileErr) == "string" and compileErr or ""
	if #detail > 0 then
		return nil, "[" .. name .. "] " .. detail
	end
	return nil, "[" .. name .. "] loadstring returned nil"
end

function Util.runChunk(fn: () -> ...any, ...: any): (...any)
	return fn(...)
end

function Util.loadModuleFromUrl(url: string, chunkName: string?): (any?, string?)
	local body, err = Util.httpGet(url)
	if not body then
		return nil, err or "HttpGet failed"
	end
	task.wait()
	local fn, cerr = Util.loadstringCompile(body, chunkName)
	if not fn then
		return nil, tostring(cerr) .. "\n" .. url
	end
	task.wait()
	local ok, result = pcall(fn)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

local LOADER_DISPLAY_ORDER = 2147483647

function Util.loaderScreenGuiParent(): Instance
	if typeof(gethui) == "function" then
		return gethui()
	end
	local ok, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and cg then
		return cg
	end
	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

function Util.configureLoaderScreenGui(gui: ScreenGui)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = LOADER_DISPLAY_ORDER
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.None
	end)
end

return Util
