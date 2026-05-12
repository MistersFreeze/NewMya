local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local AFTERMATH_FOLDER_NAME = "xKr4vNpQz7"
local KNOWN_MYA_INSTANCE_NAMES = {
	bFx9mTjWq2 = true,
	nHd6pLsRc1 = true,
	wYt3gKvBm8 = true,
	qJe5uAzNk0 = true,
	cVb7rXoDs4 = true,
}

local function notify(Fluent, title, content, duration)
	Fluent:Notify({
		Title = title,
		Content = content,
		Duration = duration or 3,
	})
end

local FLUENT_URL = "https://github.com/StyearX/Fluent-Modded/releases/download/FluentBeta/Fluent.lua"
local function getFluentSingleton()
	local g = _G
	local cached = g.MYA_FLUENT_SINGLETON
	if typeof(cached) == "table" and cached.CreateWindow then
		return cached
	end
	local src = nil
	local base = nil
	pcall(function()
		local ge = getgenv and getgenv()
		base = ge and ge.MYA_BASE_URL
	end)
	if typeof(base) == "string" and #base > 0 then
		for _, suffix in ipairs({ "New_Mya/lib/FluentModded.lua", "lib/FluentModded.lua" }) do
			local url = base .. suffix
			local okg, body = pcall(function()
				return game:HttpGet(url, true)
			end)
			if okg and typeof(body) == "string" and #body > 500 then
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
		error("UI library source unavailable.")
	end
	local loaderFn = loadstring(src, "@FluentModded")
	if typeof(loaderFn) ~= "function" then
		error("UI library compile failed.")
	end
	local lib = loaderFn()
	if typeof(lib) ~= "table" or not lib.CreateWindow then
		error("UI library invalid.")
	end
	g.MYA_FLUENT_SINGLETON = lib
	return lib
end

local Fluent = getFluentSingleton()
local SaveManager = Fluent.SaveManager
local InterfaceManager = Fluent.InterfaceManager

local playerName = localPlayer and localPlayer.DisplayName or "User"
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("gVs5nTwQr2")
SaveManager:SetFolder("gVs5nTwQr2/Config")
InterfaceManager:LoadSettings()
local ifacePre = InterfaceManager.Settings

local function pickFluentTheme(name)
	if typeof(name) == "string" and table.find(Fluent.Themes, name) then
		return name
	end
	return "Blood Red"
end

local function hideFluentGui(hidden)
	local rootGui = Fluent and Fluent.GUI
	if typeof(rootGui) ~= "Instance" then
		return
	end
	pcall(function()
		rootGui.Enabled = not hidden
	end)
end
hideFluentGui(true)
local customPlayerList = nil
do
	local ok, mod = pcall(function()
		local cc = ReplicatedStorage:FindFirstChild("CustomCharacter")
		if not cc then
			return nil
		end
		local playerListModule = cc:FindFirstChild("PlayerList")
		if not playerListModule then
			return nil
		end
		return require(playerListModule)
	end)
	if ok and typeof(mod) == "table" then
		customPlayerList = mod
	end
end

local Window = Fluent:CreateWindow({
	Title = "Aftermath",
	SubTitle = "Mya Game Module",
	TabWidth = 160,
	Size = UDim2.fromOffset(520, 470),
	Acrylic = false,
	Theme = pickFluentTheme(ifacePre.Theme),
	MinimizeKey = Enum.KeyCode.RightShift,
	UserInfoTop = true,
	UserInfoTitle = playerName,
	UserInfoSubtitle = "Mya User",
	UserInfoColor = Color3.fromRGB(180, 10, 20),
	Search = false,
})
if not Window or typeof(Window.AddTab) ~= "function" then
	error("Window creation failed. Close any existing window first, then reload.")
end

local visualsTab = Window:AddTab({ Title = "Visuals", Icon = "solar/eye-bold" })
local settingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

local visualSection = visualsTab:AddSection("ESP")

local espEnabled = false
local tracerEnabled = false
local teamCheck = false
local zombieTargets = true
local espColor = Color3.fromRGB(255, 115, 155)
local renderStore = {}

-- MyaUniversal-style: RBXScriptConnection list + globals so teardown is complete even if unload races render.
local aftermathActive = true
local trackedConnections = {}
local function trackConn(c)
	if c and typeof(c) == "RBXScriptConnection" then
		trackedConnections[#trackedConnections + 1] = c
	end
	return c
end

local function disconnectTracked()
	for i = #trackedConnections, 1, -1 do
		local c = trackedConnections[i]
		trackedConnections[i] = nil
		pcall(function()
			c:Disconnect()
		end)
	end
end

local renderConn = nil
local zombieCache = {}
local zombieCacheAt = 0

local function makeBoxGui(targetPart, targetName)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "bFx9mTjWq2"
	billboard.Adornee = targetPart
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = targetPart.Parent or targetPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "rQn1sWkLb5"
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = targetName or "Target"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextSize = 14
	nameLabel.Parent = billboard

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "pZo8hMcEt3"
	imageLabel.Size = UDim2.new(0, 20, 0, 20)
	imageLabel.Position = UDim2.new(0.5, -10, 0, 20)
	imageLabel.BackgroundTransparency = 1
	imageLabel.Image = "rbxassetid://266543268"
	imageLabel.ImageColor3 = espColor
	imageLabel.ImageTransparency = 0.3
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.Parent = billboard

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "jUv4dRyHf6"
	distLabel.Size = UDim2.new(1, 0, 0, 18)
	distLabel.Position = UDim2.new(0, 0, 0, 42)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = "0 m"
	distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	distLabel.Font = Enum.Font.SourceSansBold
	distLabel.TextSize = 14
	distLabel.Parent = billboard

	return billboard
end

local function getTracerHoldFolder()
	local existing = Workspace:FindFirstChild(AFTERMATH_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = AFTERMATH_FOLDER_NAME
	f.Parent = Workspace
	return f
end

local function makeTracerObjects(targetPart)
	local targetAttach = Instance.new("Attachment")
	targetAttach.Name = "nHd6pLsRc1"
	targetAttach.Parent = targetPart

	local originPart = Instance.new("Part")
	originPart.Name = "qJe5uAzNk0"
	originPart.Size = Vector3.new(0.2, 0.2, 0.2)
	originPart.Transparency = 1
	originPart.CanCollide = false
	originPart.CanQuery = false
	originPart.CanTouch = false
	originPart.Anchored = true
	originPart.Parent = getTracerHoldFolder()

	local originAttach = Instance.new("Attachment")
	originAttach.Name = "eLw0fBxKm9"
	originAttach.Parent = originPart

	local beam = Instance.new("Beam")
	beam.Name = "wYt3gKvBm8"
	beam.Attachment0 = originAttach
	beam.Attachment1 = targetAttach
	beam.Enabled = false
	beam.Color = ColorSequence.new(espColor)
	beam.Width0 = 0.18
	beam.Width1 = 0.14
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Parent = originPart

	return originPart, targetAttach, beam
end

local function ensureTargetFrames(targetKey, targetModel, targetPart, targetName)
	local existing = renderStore[targetKey]
	if existing and existing.targetModel == targetModel and existing.targetAttach and existing.targetAttach.Parent == targetPart then
		return existing
	end
	if existing then
		if existing.billboard then
			existing.billboard:Destroy()
		end
		if existing.beam then
			existing.beam:Destroy()
		end
		if existing.targetAttach then
			existing.targetAttach:Destroy()
		end
		if existing.originPart then
			existing.originPart:Destroy()
		end
		renderStore[targetKey] = nil
	end

	local billboard = makeBoxGui(targetPart, targetName)
	local originPart, targetAttach, beam = makeTracerObjects(targetPart)
	local data = {
		billboard = billboard,
		targetModel = targetModel,
		originPart = originPart,
		targetAttach = targetAttach,
		beam = beam,
	}
	renderStore[targetKey] = data
	return data
end

local function clearTargetFrames(targetKey)
	local data = renderStore[targetKey]
	if not data then
		return
	end
	if data.billboard then
		data.billboard:Destroy()
	end
	if data.beam then
		data.beam:Destroy()
	end
	if data.targetAttach then
		data.targetAttach:Destroy()
	end
	if data.originPart then
		data.originPart:Destroy()
	end
	renderStore[targetKey] = nil
end

local function sameTeam(player)
	if not teamCheck then
		return false
	end
	local pTeam = nil
	local lpTeam = localPlayer.Team
	local okTeam, resultTeam = pcall(function()
		return player.Team
	end)
	if okTeam then
		pTeam = resultTeam
	end
	return lpTeam ~= nil and pTeam ~= nil and lpTeam == pTeam
end

local function updateEspColor(color)
	espColor = color
	for _, data in pairs(renderStore) do
		if data.billboard then
			local dot = data.billboard:FindFirstChild("pZo8hMcEt3")
			if dot and dot:IsA("ImageLabel") then
				dot.ImageColor3 = color
			end
		end
		if data.beam then
			data.beam.Color = ColorSequence.new(color)
		end
	end
end

local function getCharacterFromAny(playerObj)
	local ok, char = pcall(function()
		return playerObj.Character
	end)
	if ok and typeof(char) == "Instance" and char:IsA("Model") then
		return char
	end
	return nil
end

local function getRootPart(character)
	if not character then
		return nil
	end
	if character.PrimaryPart and character.PrimaryPart:IsA("BasePart") then
		return character.PrimaryPart
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function getLocalOriginPartAndPosition()
	local char = localPlayer.Character
	local root = char and getRootPart(char)
	if root then
		return root, root.Position
	end

	local cam = Workspace.CurrentCamera
	if cam then
		return nil, cam.CFrame.Position
	end

	if char then
		local any = char:FindFirstChildWhichIsA("BasePart", true)
		if any then
			return nil, any.Position
		end
	end

	return nil, nil
end

local function enumeratePlayerTargets()
	local out = {}
	local seenCharacter = {}

	local function tryAdd(character, mappedPlayer, preferredRoot)
		if not character or not character:IsA("Model") or seenCharacter[character] then
			return
		end
		local rootPart = preferredRoot
		if not (rootPart and rootPart:IsA("BasePart")) then
			rootPart = getRootPart(character)
		end
		if not rootPart then
			return
		end
		seenCharacter[character] = true
		out[#out + 1] = {
			player = mappedPlayer,
			character = character,
			root = rootPart,
		}
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer then
			local char = nil
			if customPlayerList and typeof(customPlayerList.GetCharacterFromPlayer) == "function" then
				local okC, maybeChar = pcall(function()
					return customPlayerList:GetCharacterFromPlayer(p)
				end)
				if okC and typeof(maybeChar) == "Instance" then
					char = maybeChar
				end
			end
			if not char then
				char = getCharacterFromAny(p)
			end
			tryAdd(char, p, nil)
		end
	end

	for _, tagged in ipairs(CollectionService:GetTagged("PlayerListCharacterRootPart")) do
		local char = tagged and tagged.Parent
		local mappedPlayer = Players:GetPlayerFromCharacter(char)
		if not mappedPlayer and customPlayerList and typeof(customPlayerList.GetPlayerFromCharacter) == "function" then
			local okM, mp = pcall(function()
				return customPlayerList:GetPlayerFromCharacter(char)
			end)
			if okM then
				mappedPlayer = mp
			end
		end
		tryAdd(char, mappedPlayer, tagged)
	end

	return out
end

local function isLikelyZombieModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	local lower = string.lower(model.Name)
	if string.find(lower, "zombie", 1, true) then
		return true
	end

	local parent = model.Parent
	if parent and string.find(string.lower(parent.Name), "zombie", 1, true) then
		return true
	end

	local okType, npcType = pcall(function()
		return model:GetAttribute("NPCType")
	end)
	if okType and typeof(npcType) == "string" and string.find(string.lower(npcType), "zombie", 1, true) then
		return true
	end

	local okTagZombie, hasZombieTag = pcall(function()
		return CollectionService:HasTag(model, "Zombie") or CollectionService:HasTag(model, "zombie")
	end)
	if okTagZombie and hasZombieTag then
		return true
	end

	return false
end

local function enumerateZombieTargets(localCharacter)
	if not zombieTargets then
		return {}
	end

	local now = os.clock()
	if now - zombieCacheAt < 0.75 then
		return zombieCache
	end

	local out = {}
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst ~= localCharacter then
			if Players:GetPlayerFromCharacter(inst) == nil then
				local hum = inst:FindFirstChildWhichIsA("Humanoid")
				if hum and hum.Health > 0 and isLikelyZombieModel(inst) then
					local root = getRootPart(inst)
					if root then
						out[#out + 1] = inst
					end
				end
			end
		end
	end
	zombieCache = out
	zombieCacheAt = now
	return out
end

local function updateVisuals()
	if not aftermathActive then
		return
	end
	local myChar = localPlayer.Character
	local myHrp, myPos = getLocalOriginPartAndPosition()
	if not myPos then
		return
	end

	local activeKeys = {}

	for _, entry in ipairs(enumeratePlayerTargets()) do
		local player = entry.player
		local char = entry.character
		local hrp = entry.root or (char and getRootPart(char))
		local hum = char and char:FindFirstChildWhichIsA("Humanoid")
		local alive = (hum == nil) or hum.Health > 0
		if hrp and char and alive then
			if player == nil or (player ~= localPlayer and not sameTeam(player)) then
				local targetKey = char
				local nameText = player and player.Name or char.Name
				local data = ensureTargetFrames(targetKey, char, hrp, nameText)
				if data then
					activeKeys[targetKey] = true
					if data.billboard then
						data.billboard.Enabled = espEnabled
						local distLabel = data.billboard:FindFirstChild("jUv4dRyHf6")
						if distLabel and distLabel:IsA("TextLabel") then
							local dist = (myPos - hrp.Position).Magnitude
							distLabel.Text = string.format("%.0f m", dist)
						end
					end
					if data.beam then
						data.beam.Enabled = false
					end
					if tracerEnabled and data.beam then
						local originPos = nil
						if myHrp then
							originPos = myHrp.Position + Vector3.new(0, 1.2, 0)
						elseif myPos then
							originPos = myPos
						elseif Workspace.CurrentCamera then
							originPos = Workspace.CurrentCamera.CFrame.Position
						end
						if originPos and data.originPart then
							data.originPart.CFrame = CFrame.new(originPos)
							data.beam.Enabled = true
						end
					end
				end
			end
		end
	end

	for _, zombieModel in ipairs(enumerateZombieTargets(myChar)) do
		local hrp = getRootPart(zombieModel)
		local hum = zombieModel:FindFirstChildWhichIsA("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local data = ensureTargetFrames(zombieModel, zombieModel, hrp, zombieModel.Name)
			if data then
				activeKeys[zombieModel] = true
				if data.billboard then
					data.billboard.Enabled = espEnabled
					local distLabel = data.billboard:FindFirstChild("jUv4dRyHf6")
					if distLabel and distLabel:IsA("TextLabel") then
						local dist = (myPos - hrp.Position).Magnitude
						distLabel.Text = string.format("%.0f m", dist)
					end
				end
				if data.beam then
					data.beam.Enabled = false
				end
				if tracerEnabled and data.beam then
					local originPos = nil
					if myHrp then
						originPos = myHrp.Position + Vector3.new(0, 1.2, 0)
					elseif myPos then
						originPos = myPos
					elseif Workspace.CurrentCamera then
						originPos = Workspace.CurrentCamera.CFrame.Position
					end
					if originPos and data.originPart then
						data.originPart.CFrame = CFrame.new(originPos)
						data.beam.Enabled = true
					end
				end
			end
		end
	end

	for key, data in pairs(renderStore) do
		if not activeKeys[key] then
			if data.billboard then
				data.billboard.Enabled = false
			end
			if data.beam then
				data.beam.Enabled = false
			end
		end
	end
end

local function startEspLoop()
	if renderConn then
		return
	end
	local conn = RunService.RenderStepped:Connect(function()
		if not aftermathActive then
			return
		end
		if not espEnabled and not tracerEnabled then
			for _, data in pairs(renderStore) do
				if data.billboard then
					data.billboard.Enabled = false
				end
				if data.beam then
					data.beam.Enabled = false
				end
			end
			return
		end
		updateVisuals()
	end)
	renderConn = conn
	trackConn(conn)
end

local function flushRenderStore()
	-- Do not use `for k in pairs(renderStore)` — clearing entries while iterating skips keys in Luau/Lua.
	while true do
		local k = next(renderStore)
		if k == nil then
			break
		end
		clearTargetFrames(k)
	end
end

local moduleUnloaded = false

local function sweepResidualMyaVisuals()
	local roots = { Workspace, CoreGui }
	local pg = localPlayer and localPlayer:FindFirstChildWhichIsA("PlayerGui")
	if pg then
		table.insert(roots, pg)
	end

	for _, root in ipairs(roots) do
		local okDesc, descendants = pcall(function()
			return root:GetDescendants()
		end)
		if okDesc and descendants then
			for idx = #descendants, 1, -1 do
				local inst = descendants[idx]
				if KNOWN_MYA_INSTANCE_NAMES[inst.Name] then
					pcall(function()
						inst:Destroy()
					end)
				end
			end
		end
	end

	local hold = Workspace:FindFirstChild(AFTERMATH_FOLDER_NAME)
	if hold then
		pcall(function()
			hold:Destroy()
		end)
	end
end

local function stopEspLoop()
	espEnabled = false
	tracerEnabled = false
	disconnectTracked()
	renderConn = nil
	flushRenderStore()
	sweepResidualMyaVisuals()
	zombieCache = {}
	zombieCacheAt = 0
end

visualSection:AddToggle("dKx8vZpRm4", {
	Title = "Player ESP",
	Icon = "solar/eye-bold",
	Default = false,
	Callback = function(v)
		espEnabled = v
		startEspLoop()
	end,
})
visualSection:AddToggle("uJb3cFyNh7", {
	Title = "Tracer",
	Icon = "solar/share-bold",
	Default = false,
	Callback = function(v)
		tracerEnabled = v
		startEspLoop()
	end,
})
visualSection:AddToggle("oWe6aGiLq9", {
	Title = "Team Check",
	Icon = "solar/users-group-rounded-bold",
	Default = false,
	Callback = function(v)
		teamCheck = v
	end,
})
visualSection:AddToggle("yPt1zXkDs5", {
	Title = "Include Zombies",
	Icon = "solar/ghost-bold",
	Default = true,
	Callback = function(v)
		zombieTargets = v
		zombieCache = {}
		zombieCacheAt = 0
	end,
})
visualSection:AddColorpicker("hCn0rMwOj6", {
	Title = "ESP Color",
	Icon = "solar/pallete-bold",
	Default = espColor,
	Transparency = 0,
	Callback = function(color)
		updateEspColor(color)
	end,
})

task.defer(function()
	if not aftermathActive then
		return
	end
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
	task.wait()
	pcall(function()
		getgenv().ShineEnabled = ifacePre.Animated ~= false
		Fluent:SetTheme(pickFluentTheme(ifacePre.Theme))
	end)
	pcall(function()
		Fluent:ToggleTransparency(ifacePre.Transparency ~= false)
	end)
	pcall(function()
		InterfaceManager:ApplyFont(ifacePre.Font or "GothamSSm")
	end)
	hideFluentGui(false)
end)

local function unloadAftermathModule()
	if moduleUnloaded then
		return
	end
	moduleUnloaded = true

	_G.tPx7kNqZv3 = false
	aftermathActive = false

	stopEspLoop()

	_G.mRo2jHcYn8 = nil
	pcall(function()
		if Window and Window.Destroy then
			Window:Destroy()
		end
	end)

	_G.sLf9wDvGp1 = nil
end

_G.sLf9wDvGp1 = unloadAftermathModule
_G.tPx7kNqZv3 = true
_G.mRo2jHcYn8 = sweepResidualMyaVisuals

notify(Fluent, "Aftermath", "Module loaded", 3)
Window:SelectTab(1)
