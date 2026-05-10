--[[
  Operation One — Fluent Modded shell (New_Mya standard).
  Same runtime hooks / config / unload contract as legacy mya_game_ui build.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerName = localPlayer and localPlayer.DisplayName or "User"

local CONFIG_FOLDER = "mya_op1_configs"

local function ensure_config_dir()
	if not makefolder then
		return
	end
	pcall(function()
		local exists = false
		if isfolder then
			local ok, res = pcall(isfolder, CONFIG_FOLDER)
			if ok and res then
				exists = true
			end
		end
		if not exists then
			makefolder(CONFIG_FOLDER)
		end
	end)
end
ensure_config_dir()

local function strToEnumFromSerialized(s)
	if typeof(s) ~= "string" then
		return nil
	end
	local et, en = s:match("^(.+)%.(.+)$")
	if not et then
		return nil
	end
	local ok, r = pcall(function()
		return Enum[et][en]
	end)
	return ok and r or nil
end

local function formatBindDisplay(bind)
	if typeof(bind) ~= "EnumItem" then
		return "(unknown)"
	end
	if bind.EnumType == Enum.UserInputType then
		if bind == Enum.UserInputType.MouseButton1 then
			return "Mouse 1"
		elseif bind == Enum.UserInputType.MouseButton2 then
			return "Mouse 2"
		elseif bind == Enum.UserInputType.MouseButton3 then
			return "Mouse 3"
		end
		return bind.Name
	end
	return bind.Name
end

local function bindTextFromConfigField(serializedOrNil)
	if serializedOrNil == nil then
		return "(see runtime default)"
	end
	if typeof(serializedOrNil) == "EnumItem" then
		return formatBindDisplay(serializedOrNil)
	end
	local e = strToEnumFromSerialized(tostring(serializedOrNil))
	if e then
		return formatBindDisplay(e)
	end
	return tostring(serializedOrNil)
end

local FLUENT_URL = "https://github.com/StyearX/Fluent-Modded/releases/download/FluentBeta/Fluent.lua"

local function getFluentSingleton()
	local g = _G
	local cached = g.MYA_FLUENT_SINGLETON
	if typeof(cached) == "table" and cached.CreateWindow then
		return cached
	end
	local fetch = _G.MYA_FETCH
	local repoBase = _G.MYA_REPO_BASE
	local src = nil
	if typeof(fetch) == "function" and typeof(repoBase) == "string" and #repoBase > 0 then
		for _, suffix in ipairs({ "New_Mya/lib/FluentModded.lua", "lib/FluentModded.lua" }) do
			local okFetch, body = pcall(function()
				return fetch(repoBase .. suffix)
			end)
			if okFetch and typeof(body) == "string" and #body > 500 then
				src = body
				break
			end
		end
	end
	if typeof(src) ~= "string" or #src < 500 then
		local okSrc, remote = pcall(function()
			return game:HttpGet(FLUENT_URL, true)
		end)
		if okSrc and typeof(remote) == "string" and #remote > 0 then
			src = remote
		end
	end
	if typeof(src) ~= "string" or #src == 0 then
		error("[Operation One] Fluent source missing (host New_Mya/lib/FluentModded.lua or GitHub).")
	end
	local loaderFn = loadstring(src, "@FluentModded")
	if typeof(loaderFn) ~= "function" then
		error("[Operation One] Fluent compile failed")
	end
	local lib = loaderFn()
	if typeof(lib) ~= "table" or not lib.CreateWindow then
		error("[Operation One] Fluent invalid")
	end
	g.MYA_FLUENT_SINGLETON = lib
	return lib
end

local Fluent = getFluentSingleton()
local SaveManager = Fluent.SaveManager
local InterfaceManager = Fluent.InterfaceManager

local function FluentNotify(title, content, duration)
	Fluent:Notify({
		Title = title,
		Content = content,
		Duration = duration or 3,
	})
end

_G.mya_notify = function(title, content, duration)
	FluentNotify(tostring(title), tostring(content), duration)
end

-- Fluent Modded allows one main window per cached library instance; hub auto-load tears the hub window down
-- but the singleton can still think a window exists — clear cache + retry (same pattern as hub.luau).
local windowOpts = {
	Title = "Operation One",
	SubTitle = "Mya",
	TabWidth = 160,
	Size = UDim2.fromOffset(560, 520),
	Acrylic = false,
	Theme = "Blood Red",
	MinimizeKey = nil,
	UserInfoTop = true,
	UserInfoTitle = playerName,
	UserInfoSubtitle = "Mya User",
	UserInfoColor = Color3.fromRGB(180, 30, 90),
	Search = true,
}

local function recreateFluentLibrary()
	_G.MYA_FLUENT_SINGLETON = nil
	for _ = 1, 4 do
		RunService.Heartbeat:Wait()
	end
	local fresh = getFluentSingleton()
	return fresh
end

local Window = Fluent:CreateWindow(windowOpts)
if not Window or typeof(Window.AddTab) ~= "function" then
	warn("[Operation One] Fluent CreateWindow returned nil — resetting MYA_FLUENT_SINGLETON and retrying once.")
	Fluent = recreateFluentLibrary()
	SaveManager = Fluent.SaveManager
	InterfaceManager = Fluent.InterfaceManager
	Window = Fluent:CreateWindow(windowOpts)
end
if not Window or typeof(Window.AddTab) ~= "function" then
	error(
		"[Operation One] Fluent CreateWindow failed after reset. Close any remaining Mya UI, reinject, or load from hub manually."
	)
end

local LAYOUT_FOLDER = "MyaOperationOne"
local LAYOUT_FILE = LAYOUT_FOLDER .. "/layout.json"

local function readLayout()
	if typeof(readfile) ~= "function" then
		return nil
	end
	local okRead, raw = pcall(readfile, LAYOUT_FILE)
	if not okRead or typeof(raw) ~= "string" or #raw == 0 then
		return nil
	end
	local okDecode, parsed = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or typeof(parsed) ~= "table" then
		return nil
	end
	return parsed
end

local function writeLayout(layout)
	if typeof(writefile) ~= "function" then
		return
	end
	if typeof(makefolder) == "function" then
		pcall(makefolder, LAYOUT_FOLDER)
	end
	local okEncode, payload = pcall(function()
		return HttpService:JSONEncode(layout)
	end)
	if not okEncode or typeof(payload) ~= "string" then
		return
	end
	pcall(writefile, LAYOUT_FILE, payload)
end

local function findWindowFrame(titleText)
	local best = nil
	local bestArea = 0
	for _, inst in ipairs(CoreGui:GetDescendants()) do
		if inst:IsA("Frame") and inst.Visible and inst.AbsoluteSize.X > 300 and inst.AbsoluteSize.Y > 250 then
			local hasTitle = false
			for _, child in ipairs(inst:GetDescendants()) do
				if child:IsA("TextLabel") and child.Text == titleText then
					hasTitle = true
					break
				end
			end
			if hasTitle then
				local area = inst.AbsoluteSize.X * inst.AbsoluteSize.Y
				if area > bestArea then
					bestArea = area
					best = inst
				end
			end
		end
	end
	return best
end

local savedLayout = readLayout()
local latestLayout = savedLayout
local rootFrameRef = nil

local function applyLayoutToRoot(force)
	local rootFrame = rootFrameRef or findWindowFrame("Operation One")
	if not rootFrame then
		return
	end
	rootFrameRef = rootFrame
	local src = latestLayout or readLayout()
	if not src then
		return
	end
	local sx = tonumber(src.sx)
	local sy = tonumber(src.sy)
	local pxs = tonumber(src.pxs)
	local pxo = tonumber(src.pxo)
	local pys = tonumber(src.pys)
	local pyo = tonumber(src.pyo)
	if not sx or not sy or not pxs or not pxo or not pys or not pyo then
		return
	end
	if force or rootFrame.Size.X.Offset ~= math.floor(sx) or rootFrame.Size.Y.Offset ~= math.floor(sy) then
		rootFrame.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
	end
	if
		force
		or rootFrame.Position.X.Scale ~= pxs
		or rootFrame.Position.X.Offset ~= math.floor(pxo)
		or rootFrame.Position.Y.Scale ~= pys
		or rootFrame.Position.Y.Offset ~= math.floor(pyo)
	then
		rootFrame.Position = UDim2.new(pxs, math.floor(pxo), pys, math.floor(pyo))
	end
end

task.delay(0.2, function()
	local rootFrame = findWindowFrame("Operation One")
	if not rootFrame then
		return
	end
	rootFrameRef = rootFrame
	if savedLayout then
		local sx = tonumber(savedLayout.sx) or rootFrame.Size.X.Offset
		local sy = tonumber(savedLayout.sy) or rootFrame.Size.Y.Offset
		local pxs = tonumber(savedLayout.pxs)
		local pxo = tonumber(savedLayout.pxo)
		local pys = tonumber(savedLayout.pys)
		local pyo = tonumber(savedLayout.pyo)
		rootFrame.Size = UDim2.fromOffset(math.floor(sx), math.floor(sy))
		if pxs and pxo and pys and pyo then
			rootFrame.Position = UDim2.new(pxs, math.floor(pxo), pys, math.floor(pyo))
		end
	end

	local last = {
		sx = rootFrame.Size.X.Offset,
		sy = rootFrame.Size.Y.Offset,
		pxs = rootFrame.Position.X.Scale,
		pxo = rootFrame.Position.X.Offset,
		pys = rootFrame.Position.Y.Scale,
		pyo = rootFrame.Position.Y.Offset,
	}
	local function maybeSave()
		if rootFrame.Size.X.Offset < 420 or rootFrame.Size.Y.Offset < 320 then
			return
		end
		local now = {
			sx = rootFrame.Size.X.Offset,
			sy = rootFrame.Size.Y.Offset,
			pxs = rootFrame.Position.X.Scale,
			pxo = rootFrame.Position.X.Offset,
			pys = rootFrame.Position.Y.Scale,
			pyo = rootFrame.Position.Y.Offset,
		}
		if
			now.sx ~= last.sx
			or now.sy ~= last.sy
			or now.pxs ~= last.pxs
			or now.pxo ~= last.pxo
			or now.pys ~= last.pys
			or now.pyo ~= last.pyo
		then
			last = now
			latestLayout = now
			writeLayout(now)
		end
	end

	rootFrame:GetPropertyChangedSignal("Size"):Connect(maybeSave)
	rootFrame:GetPropertyChangedSignal("Position"):Connect(maybeSave)
end)

task.spawn(function()
	for _ = 1, 36 do
		applyLayoutToRoot(true)
		task.wait(0.05)
	end
end)

-- ScreenGui bridge: runtime toggles `user_interface.Enabled` (menu bind). Fluent uses Minimize as show/hide.
local menuHolder = Instance.new("ScreenGui")
menuHolder.Name = "MyaOp1MenuBridge"
menuHolder.ResetOnSpawn = false
menuHolder.IgnoreGuiInset = true
menuHolder.Enabled = true
menuHolder.Parent = CoreGui

menuHolder:GetPropertyChangedSignal("Enabled"):Connect(function()
	pcall(function()
		if Window and Window.Minimize then
			Window:Minimize()
		end
	end)
end)

menuHolder.Destroying:Connect(function()
	pcall(function()
		if Window and Window.Destroy then
			Window:Destroy()
		end
	end)
end)

local function safeCall(obj, method, ...)
	if typeof(obj) ~= "table" then
		return false
	end
	local fn = obj[method]
	if typeof(fn) ~= "function" then
		return false
	end
	local ok = pcall(fn, obj, ...)
	return ok
end

local function safeToggleSet(obj, v)
	if typeof(v) ~= "boolean" then
		return
	end
	if safeCall(obj, "Set", v) then
		return
	end
	safeCall(obj, "SetValue", v)
end

local function safeSliderSet(obj, v)
	if typeof(v) ~= "number" then
		return
	end
	if safeCall(obj, "Set", v) then
		return
	end
	safeCall(obj, "SetValue", v)
end

local function safeColorSet(obj, c)
	if typeof(c) ~= "Color3" then
		return
	end
	-- For colorpickers, force static mode unless rainbow is explicitly requested.
	-- This prevents previously-enabled rainbow loops from surviving config loads.
	if safeCall(obj, "SetValueRGB", c, (obj.Transparency or 0), false) then
		return
	end
	if safeCall(obj, "Set", c) then
		return
	end
	safeCall(obj, "SetValue", c)
end

local function safeDropdownSet(obj, val)
	if typeof(val) ~= "string" then
		return
	end
	if safeCall(obj, "Set", val) then
		return
	end
	if safeCall(obj, "SetValue", val) then
		return
	end
	safeCall(obj, "Refresh", { val })
end

local HITPART_OPTIONS = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso" }

local combatTab = Window:AddTab({ Title = "Combat", Icon = "solar/target-bold" })
local visualsTab = Window:AddTab({ Title = "Visuals", Icon = "solar/eye-bold" })
local configsTab = Window:AddTab({ Title = "Configs", Icon = "gravity/archive" })
local settingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

local aimSection = combatTab:AddSection("Aim Assist")
local silentSection = combatTab:AddSection("Silent aim")

local espSection = visualsTab:AddSection("Player ESP")
local gadgetSection = visualsTab:AddSection("Gadgets")
local worldSection = visualsTab:AddSection("World")

local ifaceSection = settingsTab:AddSection("Interface")
local scriptSection = settingsTab:AddSection("Script")

local configsSection = configsTab:AddSection("Profiles")

-- Forward declarations for sync
local aim_key_update
local silent_key_update
local menu_key_update
local silentHitDropdown
local upd_col_box
local upd_col_tracer
local upd_col_skel_vis
local upd_col_skel_hid
local upd_col_fov
local upd_col_silent_fov
local upd_col_throw
local upd_col_place

local toggles = {}
local sliders = {}
local colorPickers = {}

local function bindToggle(id, obj, toggleFnName)
	toggles[id] = obj
	local setName = "set_" .. toggleFnName:gsub("toggle_", "")
	_G[setName] = function(s)
		safeToggleSet(obj, s)
	end
end

-- -------- Aim Assist --------
bindToggle(
	"aim_assist",
	aimSection:AddToggle("Op1AimAssist", {
		Title = "Aim Assist",
		Icon = "solar/crosshair-bold",
		Default = false,
		Callback = function(v)
			if _G.toggle_aim_assist then
				local cur = false
				pcall(function()
					cur = _G.get_config and _G.get_config().aim_assist or false
				end)
				if v ~= cur then
					_G.toggle_aim_assist()
				end
			end
		end,
	}),
	"toggle_aim_assist"
)

bindToggle(
	"show_fov",
	aimSection:AddToggle("Op1ShowFov", {
		Title = "Show FOV",
		Icon = "solar/ruler-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().show_fov_circle or false
			end)
			if v ~= cur and _G.toggle_show_fov then
				_G.toggle_show_fov()
			end
		end,
	}),
	"toggle_show_fov"
)

local colFovPick = aimSection:AddColorpicker("Op1FovColor", {
	Title = "FOV ring color",
	Icon = "solar/pallete-bold",
	Default = Color3.fromRGB(245, 118, 168),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_fov then
			_G.set_color_fov(c)
		end
	end,
})
colorPickers.fov = colFovPick
upd_col_fov = function(c)
	safeColorSet(colFovPick, c)
end

bindToggle(
	"vis_check",
	aimSection:AddToggle("Op1VisCheck", {
		Title = "Visibility Check",
		Icon = "solar/eye-scan-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().vis_check or false
			end)
			if v ~= cur and _G.toggle_vis_check then
				_G.toggle_vis_check()
			end
		end,
	}),
	"toggle_vis_check"
)

sliders.aim_fov = aimSection:AddSlider("Op1AimFov", {
	Title = "FOV Radius",
	Icon = "solar/ruler-bold",
	Default = 120,
	Min = 20,
	Max = 400,
	Rounding = 0,
	Callback = function(v)
		if _G.set_aim_fov_value then
			_G.set_aim_fov_value(v)
		end
	end,
})

sliders.aim_speed = aimSection:AddSlider("Op1AimSmooth", {
	Title = "Smoothness",
	Icon = "solar/graph-up-bold",
	Default = 25,
	Min = 0,
	Max = 100,
	Rounding = 0,
	Callback = function(v)
		if _G.set_aim_speed_value then
			_G.set_aim_speed_value(v / 100)
		end
	end,
})

_G.set_aim_fov = function(v)
	safeSliderSet(sliders.aim_fov, v)
end
_G.set_aim_speed = function(v)
	safeSliderSet(sliders.aim_speed, v * 100)
end

local aimBindButton

do
	local listening = false
	local conn = nil
	aimBindButton = aimSection:AddButton({
		Title = "Set aim bind",
		Icon = "solar/keyboard-bold",
		Description = "Current: (loading)",
		Callback = function()
			if listening then
				return
			end
			listening = true
			if typeof(aimBindButton.SetDesc) == "function" then
				aimBindButton:SetDesc("Current: … press key or mouse button …")
			end
			FluentNotify("Bind", "Listening — click Mouse 1/2/3 or press a key.", 4)
			if conn then
				conn:Disconnect()
				conn = nil
			end
			conn = UserInputService.InputBegan:Connect(function(inp, _processed)
				if not listening then
					return
				end
				local bind = nil
				if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode ~= Enum.KeyCode.Unknown then
					bind = inp.KeyCode
				elseif
					inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.MouseButton2
					or inp.UserInputType == Enum.UserInputType.MouseButton3
				then
					bind = inp.UserInputType
				end
				if bind == nil then
					return
				end
				listening = false
				if conn then
					conn:Disconnect()
					conn = nil
				end
				if _G.set_aim_key_value then
					_G.set_aim_key_value(bind)
				end
				if typeof(aimBindButton.SetDesc) == "function" then
					aimBindButton:SetDesc("Current: " .. formatBindDisplay(bind))
				end
				FluentNotify("Bind", "Aim: " .. formatBindDisplay(bind), 2)
			end)
		end,
	})
end

aim_key_update = function(k)
	if typeof(aimBindButton) == "table" and typeof(aimBindButton.SetDesc) == "function" then
		aimBindButton:SetDesc("Current: " .. formatBindDisplay(k))
	end
end

-- -------- Silent --------
bindToggle(
	"silent_aim",
	silentSection:AddToggle("Op1Silent", {
		Title = "Silent aim",
		Icon = "solar/target-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and (_G.get_config().silent_aim_on or _G.get_config().silent_aim) or false
			end)
			if v ~= cur and _G.toggle_silent_aim then
				_G.toggle_silent_aim()
			end
		end,
	}),
	"toggle_silent_aim"
)

bindToggle(
	"silent_require_bind",
	silentSection:AddToggle("Op1SilentHeld", {
		Title = "Only while bind held",
		Icon = "solar/hand-stop-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().silent_aim_require_bind or false
			end)
			if v ~= cur and _G.toggle_silent_require_bind then
				_G.toggle_silent_require_bind()
			end
		end,
	}),
	"toggle_silent_require_bind"
)

sliders.silent_fov = silentSection:AddSlider("Op1SilentFov", {
	Title = "Silent aim FOV",
	Icon = "solar/ruler-bold",
	Default = 100,
	Min = 20,
	Max = 400,
	Rounding = 0,
	Callback = function(v)
		if _G.set_silent_aim_fov_value then
			_G.set_silent_aim_fov_value(v)
		end
	end,
})

bindToggle(
	"silent_fov_follow",
	silentSection:AddToggle("Op1SilentFovFollow", {
		Title = "FOV follows cursor",
		Icon = "solar/cursor-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().silent_aim_fov_follow_cursor or false
			end)
			if v ~= cur and _G.toggle_silent_fov_follow then
				_G.toggle_silent_fov_follow()
			end
		end,
	}),
	"toggle_silent_fov_follow"
)

bindToggle(
	"show_silent_fov",
	silentSection:AddToggle("Op1ShowSilentFov", {
		Title = "Show silent FOV ring",
		Icon = "solar/siren-rounded-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and (_G.get_config().show_silent_aim_fov_circle or _G.get_config().show_silent_fov_circle) or false
			end)
			if v ~= cur and _G.toggle_show_silent_fov then
				_G.toggle_show_silent_fov()
			end
		end,
	}),
	"toggle_show_silent_fov"
)

local colSilentPick = silentSection:AddColorpicker("Op1SilentFovCol", {
	Title = "Silent FOV color",
	Icon = "solar/pallete-bold",
	Default = Color3.fromRGB(160, 120, 220),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_fov_silent then
			_G.set_color_fov_silent(c)
		end
	end,
})
upd_col_silent_fov = function(c)
	safeColorSet(colSilentPick, c)
end

bindToggle(
	"silent_vis",
	silentSection:AddToggle("Op1SilentVis", {
		Title = "Visibility check",
		Icon = "solar/eye-scan-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and (_G.get_config().silent_aim_vis_check_on or _G.get_config().silent_aim_vis_check) or false
			end)
			if v ~= cur and _G.toggle_silent_vis_check then
				_G.toggle_silent_vis_check()
			end
		end,
	}),
	"toggle_silent_vis_check"
)

bindToggle(
	"silent_team",
	silentSection:AddToggle("Op1SilentTeam", {
		Title = "Team check",
		Icon = "solar/users-group-rounded-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().silent_aim_team_check_on or false
			end)
			if v ~= cur and _G.toggle_silent_team_check then
				_G.toggle_silent_team_check()
			end
		end,
	}),
	"toggle_silent_team_check"
)

silentHitDropdown = silentSection:AddDropdown("Op1SilentHit", {
	Title = "Hit part",
	Icon = "solar/body-bold",
	Values = HITPART_OPTIONS,
	Default = (function()
		local name = "HumanoidRootPart"
		pcall(function()
			if typeof(_G.get_silent_aim_part) == "function" then
				name = _G.get_silent_aim_part()
			end
		end)
		return table.find(HITPART_OPTIONS, name) or 1
	end)(),
	Callback = function(opt)
		if _G.set_silent_aim_part then
			_G.set_silent_aim_part(opt)
		end
	end,
})

_G.ui_refresh_silent_hitpart = function()
	local name = "HumanoidRootPart"
	pcall(function()
		if typeof(_G.get_silent_aim_part) == "function" then
			name = _G.get_silent_aim_part()
		end
	end)
	safeDropdownSet(silentHitDropdown, name)
end

local silentBindParagraph = silentSection:AddParagraph({
	Title = "Current silent aim bind",
	Content = "(loading)",
})

do
	local listening = false
	local conn = nil
	silentSection:AddButton({
		Title = "Set silent bind",
		Icon = "solar/keyboard-bold",
		Callback = function()
			if listening then
				return
			end
			listening = true
			if typeof(silentBindParagraph.SetDesc) == "function" then
				silentBindParagraph:SetDesc("… press key or mouse …")
			end
			FluentNotify("Bind", "Listening — Mouse 1/2/3 or key.", 4)
			if conn then
				conn:Disconnect()
				conn = nil
			end
			conn = UserInputService.InputBegan:Connect(function(inp, _processed)
				if not listening then
					return
				end
				local bind = nil
				if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode ~= Enum.KeyCode.Unknown then
					bind = inp.KeyCode
				elseif
					inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.MouseButton2
					or inp.UserInputType == Enum.UserInputType.MouseButton3
				then
					bind = inp.UserInputType
				end
				if bind == nil then
					return
				end
				listening = false
				if conn then
					conn:Disconnect()
					conn = nil
				end
				if _G.set_silent_aim_bind_value then
					_G.set_silent_aim_bind_value(bind)
				end
				if typeof(silentBindParagraph.SetDesc) == "function" then
					silentBindParagraph:SetDesc(formatBindDisplay(bind))
				end
				FluentNotify("Bind", "Silent: " .. formatBindDisplay(bind), 2)
			end)
		end,
	})
end

_G.set_silent_aim_fov = function(v)
	safeSliderSet(sliders.silent_fov, v)
end

silent_key_update = function(k)
	if typeof(silentBindParagraph) == "table" and typeof(silentBindParagraph.SetDesc) == "function" then
		silentBindParagraph:SetDesc(formatBindDisplay(k))
	end
end
_G.ui_set_silent_bind = function(k)
	silent_key_update(k)
end

-- -------- Visuals ESP --------
bindToggle(
	"boxes",
	espSection:AddToggle("Op1Boxes", {
		Title = "Boxes",
		Icon = "solar/box-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().boxes or false
			end)
			if v ~= cur and _G.toggle_boxes then
				_G.toggle_boxes()
			end
		end,
	}),
	"toggle_boxes"
)

local colBoxPick = espSection:AddColorpicker("Op1BoxCol", {
	Title = "Box color",
	Icon = "solar/pallete-bold",
	Default = Color3.new(1, 1, 1),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_box then
			_G.set_color_box(c)
		end
	end,
})
upd_col_box = function(c)
	safeColorSet(colBoxPick, c)
end

bindToggle(
	"skeletons",
	espSection:AddToggle("Op1Skel", {
		Title = "Skeleton",
		Icon = "solar/body-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().skeletons or false
			end)
			if v ~= cur and _G.toggle_skeletons then
				_G.toggle_skeletons()
			end
		end,
	}),
	"toggle_skeletons"
)

local colSkelVis = espSection:AddColorpicker("Op1SkelVis", {
	Title = "Skeleton visible",
	Icon = "solar/pallete-bold",
	Default = Color3.fromRGB(0, 255, 0),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_skel_vis then
			_G.set_color_skel_vis(c)
		end
	end,
})
local colSkelHid = espSection:AddColorpicker("Op1SkelHid", {
	Title = "Skeleton hidden",
	Icon = "solar/pallete-bold",
	Default = Color3.new(1, 1, 1),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_skel_hid then
			_G.set_color_skel_hid(c)
		end
	end,
})
upd_col_skel_vis = function(c)
	safeColorSet(colSkelVis, c)
end
upd_col_skel_hid = function(c)
	safeColorSet(colSkelHid, c)
end

bindToggle(
	"tracers",
	espSection:AddToggle("Op1Tracers", {
		Title = "Tracers",
		Icon = "solar/share-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().tracers or false
			end)
			if v ~= cur and _G.toggle_tracers then
				_G.toggle_tracers()
			end
		end,
	}),
	"toggle_tracers"
)

local colTracerPick = espSection:AddColorpicker("Op1TracerCol", {
	Title = "Tracer color",
	Icon = "solar/pallete-bold",
	Default = Color3.new(1, 1, 1),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_tracer then
			_G.set_color_tracer(c)
		end
	end,
})
upd_col_tracer = function(c)
	safeColorSet(colTracerPick, c)
end

bindToggle(
	"healthbars",
	espSection:AddToggle("Op1Hp", {
		Title = "Health Bars",
		Icon = "solar/heart-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().healthbars or false
			end)
			if v ~= cur and _G.toggle_healthbars then
				_G.toggle_healthbars()
			end
		end,
	}),
	"toggle_healthbars"
)

bindToggle(
	"names",
	espSection:AddToggle("Op1Names", {
		Title = "Names",
		Icon = "solar/text-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().names or false
			end)
			if v ~= cur and _G.toggle_names then
				_G.toggle_names()
			end
		end,
	}),
	"toggle_names"
)

bindToggle(
	"team_check",
	espSection:AddToggle("Op1Team", {
		Title = "Team Check",
		Icon = "solar/users-group-rounded-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().team_check or false
			end)
			if v ~= cur and _G.toggle_team_check then
				_G.toggle_team_check()
			end
		end,
	}),
	"toggle_team_check"
)

bindToggle(
	"arrows",
	espSection:AddToggle("Op1Arrows", {
		Title = "Crosshair arrows (off-screen)",
		Icon = "solar/compass-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().arrows_esp_on or false
			end)
			if v ~= cur and _G.toggle_arrows_esp then
				_G.toggle_arrows_esp()
			end
		end,
	}),
	"toggle_arrows_esp"
)

bindToggle(
	"arrows_dist",
	espSection:AddToggle("Op1ArrowsDist", {
		Title = "Distance under arrows",
		Icon = "solar/ruler-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().arrows_esp_distance_on or false
			end)
			if v ~= cur and _G.toggle_arrows_esp_distance then
				_G.toggle_arrows_esp_distance()
			end
		end,
	}),
	"toggle_arrows_esp_distance"
)

sliders.arrows_ring = espSection:AddSlider("Op1ArrowsRing", {
	Title = "Arrows ring radius",
	Icon = "solar/ruler-bold",
	Default = 72,
	Min = 32,
	Max = 220,
	Rounding = 0,
	Callback = function(v)
		if _G.set_arrows_esp_ring_value then
			_G.set_arrows_esp_ring_value(v)
		end
	end,
})

_G.set_arrows_ring_slider = function(v)
	safeSliderSet(sliders.arrows_ring, v)
end

-- -------- Gadgets --------
bindToggle(
	"gadgets",
	gadgetSection:AddToggle("Op1Gadgets", {
		Title = "Gadgets",
		Icon = "solar/bomb-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().gadgets or false
			end)
			if v ~= cur and _G.toggle_gadgets then
				_G.toggle_gadgets()
			end
		end,
	}),
	"toggle_gadgets"
)

local colThrow = gadgetSection:AddColorpicker("Op1ThrowCol", {
	Title = "Throwable",
	Icon = "solar/pallete-bold",
	Default = Color3.fromRGB(255, 60, 60),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_throwable then
			_G.set_color_throwable(c)
		end
	end,
})
local colPlace = gadgetSection:AddColorpicker("Op1PlaceCol", {
	Title = "Placeable",
	Icon = "solar/pallete-bold",
	Default = Color3.fromRGB(255, 170, 0),
	Transparency = 0,
	Callback = function(c)
		if _G.set_color_placeable then
			_G.set_color_placeable(c)
		end
	end,
})
upd_col_throw = function(c)
	safeColorSet(colThrow, c)
end
upd_col_place = function(c)
	safeColorSet(colPlace, c)
end

-- -------- World --------
bindToggle(
	"fullbright",
	worldSection:AddToggle("Op1Fullbright", {
		Title = "Fullbright",
		Icon = "solar/sun-2-bold",
		Default = false,
		Callback = function(v)
			local cur = false
			pcall(function()
				cur = _G.get_config and _G.get_config().fullbright or false
			end)
			if v ~= cur and _G.toggle_fullbright then
				_G.toggle_fullbright()
			end
		end,
	}),
	"toggle_fullbright"
)

-- -------- Misc --------
local menuBindParagraph = ifaceSection:AddParagraph({
	Title = "Current menu key",
	Content = "(loading)",
})

do
	local listening = false
	local conn = nil
	ifaceSection:AddButton({
		Title = "Set menu key",
		Icon = "solar/keyboard-bold",
		Callback = function()
			if listening then
				return
			end
			listening = true
			if typeof(menuBindParagraph.SetDesc) == "function" then
				menuBindParagraph:SetDesc("… press key or mouse …")
			end
			FluentNotify("Bind", "Listening — Mouse 1/2/3 or key.", 4)
			if conn then
				conn:Disconnect()
				conn = nil
			end
			conn = UserInputService.InputBegan:Connect(function(inp, _processed)
				if not listening then
					return
				end
				local bind = nil
				if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode ~= Enum.KeyCode.Unknown then
					bind = inp.KeyCode
				elseif
					inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.MouseButton2
					or inp.UserInputType == Enum.UserInputType.MouseButton3
				then
					bind = inp.UserInputType
				end
				if bind == nil then
					return
				end
				listening = false
				if conn then
					conn:Disconnect()
					conn = nil
				end
				_G.new_menu_key = bind
				if typeof(menuBindParagraph.SetDesc) == "function" then
					menuBindParagraph:SetDesc(formatBindDisplay(bind))
				end
				FluentNotify("Bind", "Menu: " .. formatBindDisplay(bind), 2)
			end)
		end,
	})
end

menu_key_update = function(k)
	if typeof(menuBindParagraph) == "table" and typeof(menuBindParagraph.SetDesc) == "function" then
		menuBindParagraph:SetDesc(formatBindDisplay(k))
	end
end
_G.ui_set_menu_key = function(k)
	menu_key_update(k)
end

-- -------- Config profiles --------
local profileNames = {}
local selectedProfile = ""
local CUSTOM_AUTOLOAD_FILE = CONFIG_FOLDER .. "/autoload.txt"

local function scanProfiles()
	profileNames = {}
	pcall(function()
		ensure_config_dir()
		if listfiles then
			for _, p in ipairs(listfiles(CONFIG_FOLDER)) do
				local n = p:match("([^\\/]+)%.json$")
				if n then
					table.insert(profileNames, n)
				end
			end
		end
	end)
	table.sort(profileNames)
	if #profileNames == 0 then
		table.insert(profileNames, "(create below)")
	end
	selectedProfile = profileNames[1] or ""
end
scanProfiles()

local profileDropdown = configsSection:AddDropdown("Op1Profiles", {
	Title = "Profile",
	Icon = "gravity/archive",
	Values = profileNames,
	Default = 1,
	Callback = function(v)
		selectedProfile = v
	end,
})

configsSection:AddButton({
	Title = "Refresh profile list",
	Icon = "solar/refresh-bold",
	Callback = function()
		scanProfiles()
		safeDropdownSet(profileDropdown, profileNames[1])
		pcall(function()
			safeCall(profileDropdown, "SetValues", profileNames)
		end)
		FluentNotify("Configs", table.concat(profileNames, ", "), 4)
	end,
})

configsSection:AddButton({
	Title = "Load selected profile",
	Icon = "solar/download-bold",
	Callback = function()
		local name = selectedProfile
		if not name or name == "(create below)" then
			FluentNotify("Configs", "Pick a profile first.", 3)
			return
		end
		local safe_path = CONFIG_FOLDER .. "/" .. name .. ".json"
		local ok, err = pcall(function()
			local raw = readfile(safe_path)
			local cfg = HttpService:JSONDecode(raw)
			if _G.apply_config then
				_G.apply_config(cfg)
			end
			sync_ui_from_config(cfg)
			FluentNotify("Configs", "Loaded " .. name, 3)
		end)
		if not ok then
			warn("[Operation One] Load failed: " .. tostring(err))
			FluentNotify("Configs", "Load failed (executor filesystem?)", 4)
		end
	end,
})

configsSection:AddButton({
	Title = "Save over selected profile",
	Icon = "solar/upload-bold",
	Callback = function()
		local name = selectedProfile
		if not name or name == "(create below)" then
			FluentNotify("Configs", "Pick or create a profile name first.", 3)
			return
		end
		local safe_path = CONFIG_FOLDER .. "/" .. name .. ".json"
		local ok, err = pcall(function()
			ensure_config_dir()
			local gc = _G.get_config
			if not gc then
				error("get_config")
			end
			writefile(safe_path, HttpService:JSONEncode(gc()))
			scanProfiles()
			FluentNotify("Configs", "Saved " .. name, 3)
		end)
		if not ok then
			warn("[Operation One] Save failed: " .. tostring(err))
		end
	end,
})

configsSection:AddButton({
	Title = "Delete selected profile",
	Icon = "solar/trash-bin-minimalistic-bold",
	Callback = function()
		local name = selectedProfile
		if not name or name == "(create below)" then
			return
		end
		local safe_path = CONFIG_FOLDER .. "/" .. name .. ".json"
		pcall(delfile, safe_path)
		scanProfiles()
		safeDropdownSet(profileDropdown, profileNames[1])
		FluentNotify("Configs", "Deleted (if existed): " .. name, 3)
	end,
})

configsSection:AddButton({
	Title = "Create new profile (auto name)",
	Icon = "solar/add-circle-bold",
	Callback = function()
		local n = 1
		pcall(function()
			ensure_config_dir()
			if isfile and listfiles then
				while true do
					local path = CONFIG_FOLDER .. "/profile_" .. tostring(n) .. ".json"
					if not isfile(path) then
						break
					end
					n += 1
				end
			end
		end)
		local name = "profile_" .. tostring(n)
		local ok, err = pcall(function()
			ensure_config_dir()
			local gc = _G.get_config
			if not gc then
				error("get_config")
			end
			writefile(CONFIG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(gc()))
		end)
		if ok then
			scanProfiles()
			selectedProfile = name
			safeDropdownSet(profileDropdown, name)
			FluentNotify("Configs", "Created " .. name, 3)
		else
			warn(err)
		end
	end,
})

configsSection:AddButton({
	Title = "Set selected as autoload",
	Icon = "solar/star-bold",
	Callback = function()
		local name = selectedProfile
		if not name or name == "(create below)" then
			FluentNotify("Configs", "Pick a profile first.", 3)
			return
		end
		local ok, err = pcall(function()
			ensure_config_dir()
			writefile(CUSTOM_AUTOLOAD_FILE, name)
		end)
		if ok then
			FluentNotify("Configs", "Autoload set to " .. name, 3)
		else
			warn("[Operation One] Set autoload failed: " .. tostring(err))
			FluentNotify("Configs", "Failed to set autoload", 4)
		end
	end,
})

function sync_ui_from_config(cfg)
	-- Keep Fluent checkboxes in sync (safe if runtime already matches).
	if cfg.boxes ~= nil and _G.set_boxes then
		_G.set_boxes(cfg.boxes)
	end
	if cfg.skeletons ~= nil and _G.set_skeletons then
		_G.set_skeletons(cfg.skeletons)
	end
	if cfg.tracers ~= nil and _G.set_tracers then
		_G.set_tracers(cfg.tracers)
	end
	if cfg.healthbars ~= nil and _G.set_healthbars then
		_G.set_healthbars(cfg.healthbars)
	end
	if cfg.names ~= nil and _G.set_names then
		_G.set_names(cfg.names)
	end
	if cfg.team_check ~= nil and _G.set_team_check then
		_G.set_team_check(cfg.team_check)
	end
	if cfg.fullbright ~= nil and _G.set_fullbright then
		_G.set_fullbright(cfg.fullbright)
	end
	if cfg.aim_assist ~= nil and _G.set_aim_assist then
		_G.set_aim_assist(cfg.aim_assist)
	end
	if cfg.show_fov_circle ~= nil and _G.set_show_fov then
		_G.set_show_fov(cfg.show_fov_circle)
	end
	if cfg.vis_check ~= nil and _G.set_vis_check then
		_G.set_vis_check(cfg.vis_check)
	end
	local wantSilent = cfg.silent_aim_on
	if wantSilent == nil then
		wantSilent = cfg.silent_aim
	end
	if wantSilent ~= nil and _G.set_silent_aim then
		_G.set_silent_aim(wantSilent)
	end
	local wantSilentRing = cfg.show_silent_aim_fov_circle
	if wantSilentRing == nil then
		wantSilentRing = cfg.show_silent_fov_circle
	end
	if wantSilentRing ~= nil and _G.set_show_silent_fov then
		_G.set_show_silent_fov(wantSilentRing)
	end
	if cfg.silent_aim_fov_follow_cursor ~= nil and _G.set_silent_fov_follow then
		_G.set_silent_fov_follow(cfg.silent_aim_fov_follow_cursor)
	end
	if cfg.silent_aim_require_bind ~= nil and _G.set_silent_require_bind then
		_G.set_silent_require_bind(cfg.silent_aim_require_bind)
	end
	local wantSilentVis = cfg.silent_aim_vis_check_on
	if wantSilentVis == nil then
		wantSilentVis = cfg.silent_aim_vis_check
	end
	if wantSilentVis ~= nil and _G.set_silent_vis_check then
		_G.set_silent_vis_check(wantSilentVis)
	end
	if cfg.silent_aim_team_check_on ~= nil and _G.set_silent_team_check then
		_G.set_silent_team_check(cfg.silent_aim_team_check_on)
	end
	if cfg.gadgets ~= nil and _G.set_gadgets then
		_G.set_gadgets(cfg.gadgets)
	end
	if cfg.arrows_esp_on ~= nil and _G.set_arrows_esp then
		_G.set_arrows_esp(cfg.arrows_esp_on)
	end
	if cfg.arrows_esp_distance_on ~= nil and _G.set_arrows_esp_distance then
		_G.set_arrows_esp_distance(cfg.arrows_esp_distance_on)
	end

	if cfg.aim_fov ~= nil and _G.set_aim_fov then
		_G.set_aim_fov(cfg.aim_fov)
	end
	if cfg.aim_speed ~= nil and _G.set_aim_speed then
		_G.set_aim_speed(cfg.aim_speed)
	end
	if cfg.silent_aim_fov ~= nil and _G.set_silent_aim_fov then
		_G.set_silent_aim_fov(cfg.silent_aim_fov)
	end
	local function str_to_enum_local(s)
		if not s then
			return nil
		end
		local et, en = s:match("^(.+)%.(.+)$")
		if not et then
			return nil
		end
		local ok, r = pcall(function()
			return Enum[et][en]
		end)
		return ok and r or nil
	end
	local ak = str_to_enum_local(cfg.aim_key)
	if ak and aim_key_update then
		aim_key_update(ak)
	end
	local sb = str_to_enum_local(cfg.silent_aim_bind)
	if sb and _G.ui_set_silent_bind then
		_G.ui_set_silent_bind(sb)
	end
	if type(cfg.silent_aim_part) == "string" and _G.set_silent_aim_part then
		_G.set_silent_aim_part(cfg.silent_aim_part)
		if _G.ui_refresh_silent_hitpart then
			_G.ui_refresh_silent_hitpart()
		end
	end
	local mk = str_to_enum_local(cfg.menu_key)
	if mk == Enum.KeyCode.Insert then
		mk = Enum.KeyCode.RightShift
	end
	if mk and menu_key_update then
		menu_key_update(mk)
	end
	if cfg.arrows_esp_ring_radius ~= nil and _G.set_arrows_ring_slider then
		_G.set_arrows_ring_slider(cfg.arrows_esp_ring_radius)
	end
	local function tc(t)
		if not t then
			return nil
		end
		return Color3.new(t.r or 1, t.g or 1, t.b or 1)
	end
	local c_box = tc(cfg.color_box)
	if c_box and upd_col_box then
		upd_col_box(c_box)
	end
	local c_tr = tc(cfg.color_tracer)
	if c_tr and upd_col_tracer then
		upd_col_tracer(c_tr)
	end
	local c_sv = tc(cfg.color_skel_vis)
	if c_sv and upd_col_skel_vis then
		upd_col_skel_vis(c_sv)
	end
	local c_sh = tc(cfg.color_skel_hid)
	if c_sh and upd_col_skel_hid then
		upd_col_skel_hid(c_sh)
	end
	local c_fov = tc(cfg.color_fov)
	if c_fov and upd_col_fov then
		upd_col_fov(c_fov)
	end
	local c_sfov = tc(cfg.color_fov_silent)
	if c_sfov and upd_col_silent_fov then
		upd_col_silent_fov(c_sfov)
	end
	local c_th = tc(cfg.color_throwable)
	if c_th and upd_col_throw then
		upd_col_throw(c_th)
	end
	local c_pl = tc(cfg.color_placeable)
	if c_pl and upd_col_place then
		upd_col_place(c_pl)
	end
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("MyaOperationOne")
SaveManager:SetFolder("MyaOperationOne/Config")

task.defer(function()
	pcall(function()
		InterfaceManager:BuildInterfaceSection(settingsTab)
	end)
	pcall(function()
		SaveManager:BuildConfigSection(settingsTab)
	end)
	pcall(function()
		SaveManager:LoadAutoloadConfig()
	end)
end)

task.defer(function()
	local ok, cfg = pcall(function()
		return _G.get_config and _G.get_config()
	end)
	if ok and cfg then
		sync_ui_from_config(cfg)
	end
end)

task.defer(function()
	local ok, err = pcall(function()
		if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
			return
		end
		if not isfile(CUSTOM_AUTOLOAD_FILE) then
			return
		end
		local name = tostring(readfile(CUSTOM_AUTOLOAD_FILE) or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" then
			return
		end
		local path = CONFIG_FOLDER .. "/" .. name .. ".json"
		if not isfile(path) then
			return
		end
		local raw = readfile(path)
		local loadedCfg = HttpService:JSONDecode(raw)
		if typeof(_G.apply_config) == "function" then
			_G.apply_config(loadedCfg)
		end
		sync_ui_from_config(loadedCfg)
		FluentNotify("Configs", "Auto-loaded " .. name, 3)
	end)
	if not ok then
		warn("[Operation One] Custom autoload failed: " .. tostring(err))
	end
end)

Window:SelectTab(1)

_G.user_interface = menuHolder

FluentNotify("Operation One", "Fluent UI ready. Menu bind toggles window (see Misc). Default: RightShift.", 4)
