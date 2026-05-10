local s = { -- pro script dumper settings
	decompile = true,
	dump_debug = false, -- output will include debug info such as constants, upvalues, protos, etc
	detailed_info = false, -- if dump_debug is enabled, it will dump more, detailed debug info
	threads = 5, -- how many scripts can be decompiled at a time
	timeout = 5, -- if decompilation takes longer than this duration (seconds), it will skip that script
	max_decompile_retries = 4, -- attempts before accepting failure (was infinite retry loop)
	delay = 0.1,
	include_nil = false, -- set to true if u want to include nil scripts
	replace_username = true, -- replaces the localplayer's username in any objects with LocalPlayer
	disable_render = true, -- disables 3d rendering while dumping scripts
	-- Upgrades (v2)
	scope_fast = false, -- only scan core trees (faster than full DataModel)
	write_manifest_json = true, -- _dump_manifest.json (paths, timing, status)
	write_summary_txt = true, -- _dump_summary.txt human-readable stats
	write_remotes_txt = true, -- _remotes_list.txt all RemoteEvent/RemoteFunction paths
	log_failures_txt = true, -- _decompile_failures.txt for scripts that failed or timed out
	write_pickup_hints_txt = true, -- _pickup_target_entity_packet_prompt.txt cross-game interaction hints
}

-- Capture globals before any locals shadow executor APIs.
local decompile_global = typeof(decompile) == "function" and decompile or nil
local disassemble_global = typeof(disassemble) == "function" and disassemble or nil
local primary_decompiler = decompile_global or disassemble_global
local bytecode_get = (typeof(getscriptbytecode) == "function" and getscriptbytecode)
	or (typeof(get_script_bytecode) == "function" and get_script_bytecode)
	or nil
local getnilinstances = getnilinstances or get_nil_instances
local getscripthash = getscripthash or get_script_hash
local getscriptclosure = getscriptclosure
local getconstants = getconstants or debug.getconstants
local getprotos = getprotos or debug.getprotos
local getinfo = getinfo or debug.getinfo
local format = string.format
local concat = table.concat

-- Lua 5.1-friendly clamp (some executors loadstring without Luau / math.clamp).
local function clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

local threads = 0
local scriptsdumped = 0
local timedoutscripts = {}
local failedscripts = {}
local pickup_hints = {}
-- Keyed by GetDebugId() — safe for parallel dump tasks (distinct keys).
local manifest_by_id = {}
local HttpService = game:GetService("HttpService")
local decompilecache = {}
local progressbind = Instance.new("BindableEvent")
local threadbind = Instance.new("BindableEvent")
local plr = game:GetService("Players").LocalPlayer.Name
local ignoredservices = {"Chat", "CoreGui", "CorePackages"}
local ignored = {"PlayerModule", "RbxCharacterSounds", "PlayerScriptsLoader", "ChatScript", "BubbleChat"}
local RunService = game:GetService("RunService")
local overlay = Instance.new("Frame", game:GetService("CoreGui").RobloxGui)
overlay.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false

local maindir = "Pro Script Dumper"
local placeid = game.PlaceId
local placename = game:GetService("MarketplaceService"):GetProductInfo(placeid).Name:gsub("[\\/:*?\"<>|\n\r]", " ")
local foldername = format("%s/[%s] %s", maindir, placeid, placename)
local exploit, version = (identifyexecutor and identifyexecutor()) or "Unknown Exploit"

local function checkdirectories()
	if not isfolder(maindir) then
		makefolder(maindir)
	end
	if not isfolder(foldername) then
		makefolder(foldername)
	end
end
local function isignored(a)
	for _, v in next, ignoredservices do
		if a:FindFirstAncestor(v) then
			return true
		end
	end
	for _, v in next, ignored do
		if a.Name == v or a:FindFirstAncestor(v) then
			return true
		end
	end
	return false
end
local function delay()
	repeat
		task.wait(s.delay)
	until threads < s.threads
end

-- Many executors return a failure *string* (e.g. Madium: "-- Failed to decompile Script.") instead of erroring.
-- Only inspect a short first line so real sources whose body mentions decompilation are not misclassified.
local function is_rejected_decompiler_output(output)
	if typeof(output) ~= "string" then
		return true
	end
	if output:gsub("%s", "") == "" then
		return true
	end
	local first = output:match("^[^\n]*") or output
	if #first > 220 then
		return false
	end
	local probe = first:lower()
	if probe:find("failed to decompile", 1, true) then
		return true
	end
	if probe:find("could not decompile", 1, true) then
		return true
	end
	if probe:find("unable to decompile", 1, true) then
		return true
	end
	return false
end

local function decompile_attempt_succeeded(output)
	return typeof(output) == "string" and not is_rejected_decompiler_output(output)
end

local function decomp(a)
	local hash
	if getscripthash then
		local ok, h = pcall(getscripthash, a)
		if ok and typeof(h) == "string" and h ~= "" then
			hash = h
		end
	end
	if not hash then
		hash = a:GetDebugId()
	end
	local cached = decompilecache[hash]
	if cached then
		return cached
	end

	local function run_dec(fn, arg)
		if typeof(fn) ~= "function" or arg == nil then
			return nil
		end
		local ok, res = pcall(fn, arg)
		if ok and decompile_attempt_succeeded(res) then
			return res
		end
		return nil
	end

	local out = run_dec(primary_decompiler, a)
	if not out and bytecode_get and primary_decompiler then
		local bc_ok, bc = pcall(bytecode_get, a)
		if bc_ok and typeof(bc) == "string" and #bc > 0 then
			out = run_dec(primary_decompiler, bc)
		end
	end
	if not out and disassemble_global and disassemble_global ~= primary_decompiler then
		out = run_dec(disassemble_global, a)
		if not out and bytecode_get then
			local bc_ok, bc = pcall(bytecode_get, a)
			if bc_ok and typeof(bc) == "string" and #bc > 0 then
				out = run_dec(disassemble_global, bc)
			end
		end
	end

	if not out then
		return "-- Failed to decompile script"
	end
	decompilecache[hash] = out
	return out
end
local function getfullname(a)
	local name = a:GetFullName()
	local split = name:split(".")
	if not a:IsDescendantOf(game) then -- this means its a nil script
		return name
	end
	for i, v in next, split do -- for instances with spaces or hyphens in the name
		if v:find("[%s%-]+") then
			split[i] = format("['%s']", v)
		end
	end
	name = concat(split, ".")
	local service = split[1]
	local fullname = format('game:GetService("%s")%s', service, name:sub(service:len() + 1, -1))
	fullname = fullname:gsub("(%.%[)", function() -- remove period from .[]
		return "["
	end)
	if s.replace_username then
		fullname = fullname:gsub(plr, "LocalPlayer")
	end
	return fullname
end

local function gather_scripts()
	local list = {}
	local function scan_root(root)
		if not root then
			return
		end
		for _, v in root:GetDescendants() do
			if (v:IsA("LocalScript") or v:IsA("ModuleScript")) and not isignored(v) then
				table.insert(list, v)
			end
		end
	end
	if s.scope_fast then
		pcall(function()
			scan_root(game:GetService("ReplicatedFirst"))
		end)
		pcall(function()
			scan_root(game:GetService("ReplicatedStorage"))
		end)
		pcall(function()
			scan_root(game:GetService("StarterPlayer"))
		end)
		pcall(function()
			scan_root(game:GetService("StarterGui"))
		end)
		local lp = game:GetService("Players").LocalPlayer
		if lp then
			pcall(function()
				scan_root(lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5))
			end)
			pcall(function()
				scan_root(lp:FindFirstChild("PlayerScripts") or lp:WaitForChild("PlayerScripts", 5))
			end)
			pcall(function()
				scan_root(lp:FindFirstChild("Backpack") or lp:WaitForChild("Backpack", 3))
			end)
		end
		pcall(function()
			scan_root(workspace)
		end)
	else
		for _, v in game:GetDescendants() do
			if (v:IsA("LocalScript") or v:IsA("ModuleScript")) and not isignored(v) then
				table.insert(list, v)
			end
		end
	end
	return list
end

local function build_remotes_dump()
	local lines = {}
	for _, d in game:GetDescendants() do
		local cn = d.ClassName
		if cn == "RemoteEvent" or cn == "RemoteFunction" or cn == "UnreliableRemoteEvent" then
			lines[#lines + 1] = cn .. "\t" .. d:GetFullName()
		end
	end
	table.sort(lines)
	return concat(lines, "\n")
end

local function dumpscript(v, isnil)
	checkdirectories()
	task.spawn(function()
		local function dump()
			threads = threads + 1

			-- File Name
			local id = v:GetDebugId()
			local name = v.Name
			local path = (isnil and "[nil] " or "") .. v:GetFullName()
			if s.replace_username then
				path = path:gsub(plr, "LocalPlayer")
			end
			local filename = format("%s/%s (%s).lua", foldername, path:gsub("[\\/:*?\"<>|\n\r]", " "), id)
			if filename:len() > 199 then
				filename = filename:sub(0, 195) .. ".lua"
			end
			filename = filename:gsub("%.%.", ". .") -- prevent it from trying to escape directory

			-- Script Output
			local time = os.clock()
			local _, output
			local status = "ok"
			local err_detail = nil
			if s.decompile then
				local retries = math.max(1, math.floor(tonumber(s.max_decompile_retries) or 4))
				local attempt = 0
				while true do
					attempt = attempt + 1
					local ok_xp, res = xpcall(decomp, function()
						return "-- Failed to decompile script"
					end, v)
					output = res
					if ok_xp and decompile_attempt_succeeded(output) then
						break
					end
					if (os.clock() - time) > s.timeout then
						output = "-- Decompilation timed out"
						status = "timeout"
						table.insert(timedoutscripts, format("Name: %s\nPath: %s\nClass: %s\nDebug Id: %s", name, path, v.ClassName, id))
						err_detail = "timeout"
						break
					end
					if attempt >= retries then
						output = output or "-- Failed to decompile script"
						status = "failed"
						err_detail = "decompile_failed"
						table.insert(failedscripts, format("Name: %s\nPath: %s\nClass: %s\nDebug Id: %s\nReason: max retries (%d)", name, path, v.ClassName, id, retries))
						break
					end
					task.wait(0.2)
				end
				if typeof(output) == "string" and output:gsub(" ", "") == "" then
					output = "-- Decompiler returned nothing. This script may not have bytecode or has anti-decompile implemented."
					status = "empty"
					err_detail = "empty_output"
				end
			else
				output = "-- Script decompilation is disabled"
				status = "skipped"
			end

			-- Information
			local class = v.ClassName

			local content = {
				[1] = "-- Name: %s",
				[2] = "-- Path: %s",
				[3] = "-- Class: %s",
				[4] = "-- Exploit: %s %s",
				[5] = "-- Time to decompile: %s",
				[6] = "\n%s",
			}

			local gotclosure, closure = pcall(getscriptclosure, v)
			local constants, constantsnum, protos, protosnum

			if s.dump_debug then
				if gotclosure then
					content[6] = "\n-- Debug Info"
					content[7] = "-- # of Constants: %s"
					content[8] = "-- # of Protos: %s"
					content[9] = "\n%s"

					constants = getconstants(closure)
					constantsnum = #constants
					protos = getprotos(closure)
					protosnum = #protos

					if s.detailed_info then
						content[9] = "\n-- Constants"
						local function searchconstants(t, count)
							for i, v in next, t do
								local i_type = typeof(i)
								local v_type = typeof(v)
								if v_type ~= "table" then
									v = tostring(v):gsub("%%", "%%%%")
								end
								content[#content + 1] = format(
									"-- %s[%s%s%s] (%s) = %s (%s)",
									string.rep("  ", count),
									i_type == "string" and "'" or "",
									i_type == "Instance" and getfullname(i) or tostring(i),
									i_type == "string" and "'" or "",
									i_type,
									tostring(v),
									v_type
								)

								if v_type == "table" then
									searchconstants(v, count + 1)
								end
							end
						end
						searchconstants(constants, 0)

						content[#content + 1] = "\n-- Proto Info"
						local function getprotoinfo(t)
							for _, v in next, t do
								local info = getinfo(v)
								content[#content + 1] = "-- '" .. info.name .. "'"
								for i2, v2 in next, info do
									v2 = tostring(v2):gsub("%%", "%%%%")
									content[#content + 1] = format("--   ['%s'] = %s", i2, v2)
								end
							end
						end
						getprotoinfo(protos)

						content[#content + 1] = "\n%s"
					end
				else
					content[6] = "\n-- Debug Info (Could not get script closure)"
				end
			end

			local elapsed = os.clock() - time
			if s.write_pickup_hints_txt and typeof(output) == "string" then
				local low = string.lower(output)
				local has_pickup = low:find("pickup", 1, true) ~= nil
				local has_entity_id = low:find("entityid", 1, true) ~= nil
				local has_packet_send = low:find(".send(", 1, true) ~= nil
					or low:find("fireserver(", 1, true) ~= nil
					or low:find("bytereliable", 1, true) ~= nil
					or low:find("definepacket", 1, true) ~= nil
				local has_prompt = low:find("proximityprompt", 1, true) ~= nil
					or low:find("fireproximityprompt", 1, true) ~= nil
					or low:find("inputholdbegin", 1, true) ~= nil
					or low:find("inputholdend", 1, true) ~= nil

				local has_interact = low:find("interact", 1, true) ~= nil
					or low:find("collect", 1, true) ~= nil
					or low:find("loot", 1, true) ~= nil
					or low:find("grab", 1, true) ~= nil
					or low:find("take", 1, true) ~= nil
					or low:find("actiontext", 1, true) ~= nil
					or low:find("objecttext", 1, true) ~= nil

				local has_targeting = low:find("raycast", 1, true) ~= nil
					or low:find("viewportpointtoray", 1, true) ~= nil
					or low:find("getmouselocation", 1, true) ~= nil
					or low:find("hastag(\"pickup\")", 1, true) ~= nil
					or low:find("collectionservice", 1, true) ~= nil

				if has_pickup or has_entity_id or has_packet_send or has_prompt or has_interact or has_targeting then
					local tags = {}
					if has_pickup then tags[#tags + 1] = "Pickup" end
					if has_entity_id then tags[#tags + 1] = "EntityID" end
					if has_packet_send then tags[#tags + 1] = "PacketSend" end
					if has_prompt then tags[#tags + 1] = "PromptPath" end
					if has_interact then tags[#tags + 1] = "InteractTerms" end
					if has_targeting then tags[#tags + 1] = "TargetingPath" end
					pickup_hints[#pickup_hints + 1] = string.format(
						"[%s]\nPath: %s\nClass: %s\nDebugId: %s\n",
						table.concat(tags, " / "),
						path,
						class,
						id
					)
				end
			end
			local header_hash = ""
			pcall(function()
				if getscripthash then
					header_hash = getscripthash(v)
				end
			end)
			local file_body = format(
				concat(content, "\n"),
				name,
				getfullname(v),
				class,
				exploit,
				version or "",
				elapsed .. " seconds",
				s.dump_debug and constantsnum or output,
				protosnum,
				output,
				"",
				"",
				""
			)
			if header_hash ~= "" then
				file_body = "-- ScriptHash: " .. header_hash .. "\n" .. file_body
			end
			local w_ok, w_err = pcall(writefile, filename, file_body)
			if not w_ok then
				status = "write_error"
				err_detail = tostring(w_err)
				pcall(function()
					table.insert(failedscripts, format("Write failed: %s\nPath: %s", tostring(w_err), filename))
				end)
			end
			manifest_by_id[id] = {
				name = name,
				path = path,
				className = class,
				debugId = id,
				nilScript = isnil and true or false,
				status = status,
				error = err_detail,
				seconds = elapsed,
				bytes = typeof(file_body) == "string" and #file_body or 0,
				file = filename:gsub("^" .. maindir .. "/", ""),
			}
			scriptsdumped = scriptsdumped + 1
			progressbind:Fire(scriptsdumped)
			threads = threads - 1
		end

		local function queue()
			delay()
			if threads < s.threads then
				dump()
			else
				queue()
			end
		end

		if threads < s.threads then
			dump()
		else
			queue()
		end
	end)
	delay()
end

-- Shared with unload (stop thread HUD loop); declared before unload_dumper closes over it.
local dump_in_progress = false

-- === Mya UI (lib/mya_game_ui.lua) - pass hosted repo root as first arg (hub passes BASE_URL). ===

local function normalize_repo_base(u)
	if typeof(u) ~= "string" or #u == 0 then
		return nil
	end
	if not string.match(u, "^https?://") then
		return nil
	end
	if string.sub(u, -1) == "/" then
		return u
	end
	return u .. "/"
end

local MYA_REPO_BASE = normalize_repo_base(...)
if not MYA_REPO_BASE and typeof(getgenv) == "function" then
	local g = getgenv()
	if g and typeof(g.MYA_BASE_URL) == "string" then
		MYA_REPO_BASE = normalize_repo_base(g.MYA_BASE_URL)
	end
end
if not MYA_REPO_BASE then
	error("[Pro Script Dumper] Missing repo URL - launch from the Mya hub or set getgenv().MYA_BASE_URL to your hosted root.")
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")

local gethui_support = typeof(gethui) == "function"
local cloneref_fn = typeof(cloneref) == "function" and cloneref or function(x)
	return x
end
local uis = cloneref_fn(UserInputService)

local libOk, libSrc = pcall(function()
	return game:HttpGet(MYA_REPO_BASE .. "lib/mya_game_ui.lua", true)
end)
if not libOk or typeof(libSrc) ~= "string" or #libSrc == 0 then
	error("[Pro Script Dumper] Could not download lib/mya_game_ui.lua from your host.")
end
local compileOk, libFn = pcall(loadstring, libSrc, "@lib/mya_game_ui")
if not compileOk or typeof(libFn) ~= "function" then
	error("[Pro Script Dumper] Failed to compile lib/mya_game_ui.lua")
end
local MyaUI = libFn()
local THEME, C = MyaUI.defaultTheme()

local unloadConns = {}
local function track_conn(c)
	table.insert(unloadConns, c)
	return c
end

local uiDestroyed = false
local ui = Instance.new("ScreenGui")
ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ui.Name = "MyaProScriptDumper"
ui.IgnoreGuiInset = true
ui.DisplayOrder = 45
ui.ResetOnSpawn = false
ui.Parent = gethui_support and gethui() or game:GetService("CoreGui")

local notify, notif_ui = MyaUI.createNotifyStack({
	C = C,
	THEME = THEME,
	ts = TweenService,
	notifParent = playerGui,
	gethui_support = gethui_support,
})

local shell
local unload_dumper
shell = MyaUI.createHubShell({
	ui = ui,
	THEME = THEME,
	C = C,
	ts = TweenService,
	uis = uis,
	titleText = "Mya - Pro Script Dumper",
	tabNames = { "Dump", "Settings" },
	subPages = {},
	statusDefault = "Ready - original tool by zzerexx",
	discordInvite = false,
	winW = 460,
	winH = 620,
	onClose = function()
		unload_dumper()
	end,
})

unload_dumper = function()
	if uiDestroyed then
		return
	end
	uiDestroyed = true
	dump_in_progress = false
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)
	overlay.Visible = false
	if overlay.Parent then
		overlay:Destroy()
	end
	for _, c in unloadConns do
		pcall(function()
			c:Disconnect()
		end)
	end
	for i = #unloadConns, 1, -1 do
		unloadConns[i] = nil
	end
	if notif_ui and notif_ui.Parent then
		notif_ui:Destroy()
	end
	if ui and ui.Parent then
		ui:Destroy()
	end
	_G.unload_mya_dumper = nil
end
_G.unload_mya_dumper = unload_dumper

local switch_tab = shell.switch_tab
local tab_containers = shell.tab_containers
local make_page = shell.make_page
local statusLabel = shell.statusLabel

local dump_page = make_page()
dump_page.Visible = true
dump_page.Parent = tab_containers["Dump"]
local settings_page = make_page()
settings_page.Parent = tab_containers["Settings"]

for _, pg in ipairs({ dump_page, settings_page }) do
	for _, ch in ipairs(pg:GetChildren()) do
		if ch:IsA("UIListLayout") then
			ch.Padding = UDim.new(0, 5)
			break
		end
	end
end

local ROW_CORNER = THEME.cornerSm + 3

local function section_label(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.LayoutOrder = order
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = "  " .. string.upper(text)
	lbl.TextColor3 = C.accent
	lbl.TextSize = 10
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
end

local function make_row(parent, order, h)
	h = h or 34
	local base = C.panel
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.BackgroundColor3 = base
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, h)
	row.ClipsDescendants = true
	row.Parent = parent
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, ROW_CORNER)
	local sep = Instance.new("Frame")
	sep.BackgroundColor3 = THEME.border
	sep.BackgroundTransparency = 0.35
	sep.BorderSizePixel = 0
	sep.AnchorPoint = Vector2.new(0.5, 1)
	sep.Position = UDim2.new(0.5, 0, 1, -1)
	sep.Size = UDim2.new(1, -2 * ROW_CORNER, 0, 1)
	sep.Parent = row
	row.MouseEnter:Connect(function()
		row.BackgroundColor3 = C.row_hover
	end)
	row.MouseLeave:Connect(function()
		row.BackgroundColor3 = base
	end)
	return row
end

local function make_slider(parent, label, order, min_v, max_v, def, fmt, on_change)
	local row = make_row(parent, order, 48)
	local lbl = Instance.new("TextLabel")
	lbl.Font = Enum.Font.Gotham
	lbl.TextColor3 = C.text
	lbl.TextSize = 12
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(14, 4)
	lbl.Size = UDim2.new(1, -28, 0, 16)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = label
	lbl.Parent = row
	local val_lbl = Instance.new("TextLabel")
	val_lbl.Font = Enum.Font.GothamSemibold
	val_lbl.TextColor3 = C.accent
	val_lbl.TextSize = 11
	val_lbl.BackgroundTransparency = 1
	val_lbl.Position = UDim2.fromOffset(14, 4)
	val_lbl.Size = UDim2.new(1, -28, 0, 16)
	val_lbl.TextXAlignment = Enum.TextXAlignment.Right
	val_lbl.Parent = row
	local track = Instance.new("Frame")
	track.BackgroundColor3 = C.slid_bg
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(14, 28)
	track.Size = UDim2.new(1, -28, 0, 6)
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.slid_fg
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	fill.Parent = track
	local thumb = Instance.new("Frame")
	thumb.BackgroundColor3 = Color3.new(1, 1, 1)
	thumb.BorderSizePixel = 0
	thumb.Size = UDim2.fromOffset(12, 12)
	thumb.Position = UDim2.new(0, -6, 0.5, -6)
	Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
	thumb.Parent = track
	local cur = def
	local dragging = false
	local function set_val(v)
		cur = clamp(v, min_v, max_v)
		local pct = (cur - min_v) / (max_v - min_v)
		fill.Size = UDim2.fromScale(pct, 1)
		thumb.Position = UDim2.new(pct, -6, 0.5, -6)
		val_lbl.Text = string.format(fmt or "%g", cur)
		if on_change then
			on_change(cur)
		end
	end
	set_val(def)
	local function from_x(x)
		local abs = track.AbsolutePosition
		local sz = track.AbsoluteSize
		set_val(min_v + clamp((x - abs.X) / sz.X, 0, 1) * (max_v - min_v))
	end
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			from_x(inp.Position.X)
		end
	end)
	track_conn(
		uis.InputChanged:Connect(function(inp)
			if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
				from_x(inp.Position.X)
			end
		end)
	)
	track_conn(
		uis.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	)
	return set_val
end

local function make_toggle_row(parent, label, order, initial_on, on_click)
	local row = make_row(parent, order)
	local state = initial_on
	local lbl = Instance.new("TextLabel")
	lbl.Font = Enum.Font.Gotham
	lbl.Text = label
	lbl.TextColor3 = C.text
	lbl.TextSize = 13
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(14, 0)
	lbl.Size = UDim2.new(1, -56, 1, 0)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = state and C.tog_on or C.tog_off
	pill.BorderSizePixel = 0
	pill.Position = UDim2.new(1, -46, 0.5, -9)
	pill.Size = UDim2.fromOffset(36, 18)
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	pill.Parent = row
	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Size = UDim2.fromOffset(12, 12)
	knob.Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	knob.Parent = pill
	local function refresh()
		pill.BackgroundColor3 = state and C.tog_on or C.tog_off
		knob.Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
	end
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.Text = ""
	hit.Parent = row
	hit.MouseButton1Click:Connect(function()
		state = not state
		refresh()
		on_click(state)
	end)
end

local function row_button(parent, order, text, callback, danger)
	local row = make_row(parent, order, 40)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = danger and THEME.danger or C.accent
	btn.TextColor3 = danger and Color3.fromRGB(255, 245, 248) or Color3.fromRGB(28, 14, 22)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.Text = text
	btn.Size = UDim2.new(1, -28, 0, 30)
	btn.Position = UDim2.new(0.5, 0, 0.5, 0)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.AutoButtonColor = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, ROW_CORNER)
	btn.Parent = row
	btn.MouseButton1Click:Connect(callback)
end

local progRef = { total = 0 }
track_conn(
	progressbind.Event:Connect(function(count)
		if progRef.label and progRef.total > 0 then
			progRef.label.Text = string.format("%d / %d scripts", count, progRef.total)
		end
		if progRef.fill and progRef.total > 0 then
			progRef.fill.Size = UDim2.fromScale(clamp(count / progRef.total, 0, 1), 1)
		end
		if statusLabel and statusLabel.Parent and progRef.total > 0 then
			statusLabel.Text = string.format("Dumping %d / %d", count, progRef.total)
		end
	end)
)

local activeThreadLabel = Instance.new("TextLabel")
activeThreadLabel.BackgroundTransparency = 1
activeThreadLabel.Font = Enum.Font.Gotham
activeThreadLabel.TextSize = 12
activeThreadLabel.TextColor3 = C.dim
activeThreadLabel.TextXAlignment = Enum.TextXAlignment.Left
activeThreadLabel.Text = "Active threads: 0"

track_conn(
	threadbind.Event:Connect(function(a, b)
		activeThreadLabel.Text = tostring(a) .. " " .. tostring(b)
	end)
)

section_label(settings_page, "Credit", 1)
local credit_row = make_row(settings_page, 2, 56)
local credit_txt = Instance.new("TextLabel")
credit_txt.BackgroundTransparency = 1
credit_txt.Position = UDim2.fromOffset(14, 6)
credit_txt.Size = UDim2.new(1, -28, 1, -12)
credit_txt.Font = Enum.Font.Gotham
credit_txt.TextSize = 12
credit_txt.TextColor3 = C.dim
credit_txt.TextXAlignment = Enum.TextXAlignment.Left
credit_txt.TextWrapped = true
credit_txt.Text = "Pro Script Dumper credits goes to zzerexx"
credit_txt.Parent = credit_row

section_label(settings_page, "Options", 10)
make_toggle_row(settings_page, "Decompile scripts", 11, s.decompile, function(v)
	s.decompile = v
end)
make_toggle_row(settings_page, "Dump debug info", 12, s.dump_debug, function(v)
	s.dump_debug = v
end)
make_toggle_row(settings_page, "Detailed debug info", 13, s.detailed_info, function(v)
	s.detailed_info = v
end)
make_slider(settings_page, "Max threads", 14, 1, 20, s.threads, "%.0f", function(v)
	s.threads = math.floor(v + 0.5)
	s.threads = clamp(s.threads, 1, 20)
end)
make_slider(settings_page, "Delay between jobs (s)", 15, 0, 1, s.delay, "%.2f", function(v)
	s.delay = v
end)
make_slider(settings_page, "Decompile timeout (s)", 16, 5, 30, s.timeout, "%.2f", function(v)
	s.timeout = v
end)
make_toggle_row(settings_page, "Include nil scripts", 17, s.include_nil, function(v)
	s.include_nil = v
end)
make_toggle_row(settings_page, "Replace username with LocalPlayer", 18, s.replace_username, function(v)
	s.replace_username = v
end)
make_toggle_row(settings_page, "Disable 3D rendering while dumping", 19, s.disable_render, function(v)
	s.disable_render = v
end)

section_label(settings_page, "Scope & output", 30)
make_toggle_row(settings_page, "Fast scope (RS / Starter* / LP / Workspace only)", 31, s.scope_fast, function(v)
	s.scope_fast = v
end)
make_toggle_row(settings_page, "Write _dump_manifest.json", 32, s.write_manifest_json, function(v)
	s.write_manifest_json = v
end)
make_toggle_row(settings_page, "Write _dump_summary.txt", 33, s.write_summary_txt, function(v)
	s.write_summary_txt = v
end)
make_toggle_row(settings_page, "Write _remotes_list.txt", 34, s.write_remotes_txt, function(v)
	s.write_remotes_txt = v
end)
make_toggle_row(settings_page, "Write _decompile_failures.txt", 35, s.log_failures_txt, function(v)
	s.log_failures_txt = v
end)
make_toggle_row(settings_page, "Write _pickup_target_entity_packet_prompt.txt", 36, s.write_pickup_hints_txt, function(v)
	s.write_pickup_hints_txt = v
end)
make_slider(settings_page, "Max decompile retries", 37, 1, 12, s.max_decompile_retries, "%.0f", function(v)
	s.max_decompile_retries = math.floor(v + 0.5)
	s.max_decompile_retries = clamp(s.max_decompile_retries, 1, 12)
end)

section_label(dump_page, "Run", 1)
row_button(dump_page, 3, "Start dumping", function()
	if dump_in_progress then
		notify("Dumper", "A dump is already running.", 3)
		return
	end

	if s.disable_render then
		overlay.Visible = true
		RunService:Set3dRenderingEnabled(false)
	end

	local scripts = {}
	local nilscripts = {}
	timedoutscripts = {}
	failedscripts = {}
	pickup_hints = {}
	manifest_by_id = {}
	scriptsdumped = 0

	for _, v in ipairs(gather_scripts()) do
		table.insert(scripts, v)
	end
	if s.include_nil and getnilinstances then
		for _, v in next, getnilinstances() do
			if (v:IsA("LocalScript") or v:IsA("ModuleScript")) and not isignored(v) then
				table.insert(nilscripts, v)
			end
		end
	end

	dump_in_progress = true
	task.spawn(function()
		repeat
			threadbind:Fire("Active threads:", threads)
			task.wait()
		until not dump_in_progress
	end)

	local total = #scripts + #nilscripts
	local progress_row = make_row(dump_page, 4, 52)
	local prog_lbl = Instance.new("TextLabel")
	prog_lbl.BackgroundTransparency = 1
	prog_lbl.Font = Enum.Font.GothamSemibold
	prog_lbl.TextSize = 12
	prog_lbl.TextColor3 = C.text
	prog_lbl.Position = UDim2.fromOffset(14, 4)
	prog_lbl.Size = UDim2.new(1, -28, 0, 18)
	prog_lbl.TextXAlignment = Enum.TextXAlignment.Left
	prog_lbl.Text = string.format("0 / %d scripts", total)
	prog_lbl.Parent = progress_row

	local track = Instance.new("Frame")
	track.BackgroundColor3 = C.slid_bg
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(14, 26)
	track.Size = UDim2.new(1, -28, 0, 8)
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	track.Parent = progress_row
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.slid_fg
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	fill.Parent = track

	progRef.total = total
	progRef.label = prog_lbl
	progRef.fill = fill

	notify("Dumper", total .. " scripts queued - dumping...", 4)

	local time = os.clock()

	for _, v in next, scripts do
		dumpscript(v)
	end
	delay()

	if s.include_nil and getnilinstances then
		for _, v in next, nilscripts do
			dumpscript(v, true)
		end
		delay()
	end

	repeat
		task.wait()
	until threads == 0

	local result = format(
		"Done in %s s.%s",
		string.format("%.2f", os.clock() - time),
		#timedoutscripts > 0 and (" " .. #timedoutscripts .. " timed out.") or ""
	)
	notify("Dumper", result, 6)

	if #timedoutscripts > 0 then
		pcall(writefile, format("%s/! Timed out scripts.txt", foldername), concat(timedoutscripts, "\n\n"))
	end

	local ok_count, fail_count, timeout_count = 0, 0, 0
	local total_bytes = 0
	local manifest_list = {}
	for _, entry in pairs(manifest_by_id) do
		table.insert(manifest_list, entry)
		if entry.status == "ok" or entry.status == "skipped" then
			ok_count = ok_count + 1
		elseif entry.status == "timeout" then
			timeout_count = timeout_count + 1
			fail_count = fail_count + 1
		else
			fail_count = fail_count + 1
		end
		total_bytes = total_bytes + (entry.bytes or 0)
	end
	table.sort(manifest_list, function(a, b)
		return (a.path or "") < (b.path or "")
	end)

	if s.write_manifest_json then
		local pack = {
			generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			placeId = placeid,
			placeName = placename,
			exploit = exploit,
			exploitVersion = version,
			scopeFast = s.scope_fast,
			scripts = manifest_list,
		}
		pcall(function()
			writefile(foldername .. "/_dump_manifest.json", HttpService:JSONEncode(pack))
		end)
	end

	if s.write_summary_txt then
		local summary = {
			format("Pro Script Dumper — summary\n"),
			format("Place: %s (%s)\n", placename, tostring(placeid)),
			format("Exploit: %s %s\n", exploit, tostring(version or "")),
			format("Scope: %s\n", s.scope_fast and "fast (core services only)" or "full (entire DataModel)"),
			format("Total scripts processed: %d\n", #manifest_list),
			format("OK / skipped: %d\n", ok_count),
			format("Failed (incl. timeout): %d\n", fail_count),
			format("Timeouts: %d\n", timeout_count),
			format("Approx. total output bytes: %d\n", total_bytes),
			format("Elapsed wall time: %s s\n", string.format("%.2f", os.clock() - time)),
		}
		pcall(writefile, foldername .. "/_dump_summary.txt", concat(summary))
	end

	if s.write_remotes_txt then
		pcall(function()
			writefile(foldername .. "/_remotes_list.txt", build_remotes_dump())
		end)
	end

	if s.log_failures_txt and (#failedscripts > 0 or #timedoutscripts > 0) then
		local chunks = {}
		if #failedscripts > 0 then
			chunks[#chunks + 1] = "=== Failures (decompile / write / empty) ===\n" .. concat(failedscripts, "\n\n---\n\n")
		end
		if #timedoutscripts > 0 then
			chunks[#chunks + 1] = "=== Timed out ===\n" .. concat(timedoutscripts, "\n\n")
		end
		pcall(writefile, foldername .. "/_decompile_failures.txt", concat(chunks, "\n"))
	end
	if s.write_pickup_hints_txt then
		local body
		if #pickup_hints > 0 then
			body = concat(pickup_hints, "\n")
		else
			body = "No interaction scripts matched Pickup / EntityID / PacketSend / PromptPath / InteractTerms / TargetingPath."
		end
		pcall(writefile, foldername .. "/_pickup_target_entity_packet_prompt.txt", body)
	end

	if s.disable_render then
		RunService:Set3dRenderingEnabled(true)
		overlay.Visible = false
	end

	task.wait(1)
	progress_row:Destroy()
	progRef.total = 0
	progRef.label = nil
	progRef.fill = nil
	dump_in_progress = false
	if statusLabel and statusLabel.Parent then
		statusLabel.Text = "Ready - original tool by zzerexx"
	end
end)

local thread_row = make_row(dump_page, 5, 30)
activeThreadLabel.Size = UDim2.new(1, -28, 1, 0)
activeThreadLabel.Position = UDim2.fromOffset(14, 0)
activeThreadLabel.Parent = thread_row

section_label(dump_page, "Exit", 20)
row_button(dump_page, 21, "Unload dumper", function()
	unload_dumper()
end, true)

switch_tab("Dump")
