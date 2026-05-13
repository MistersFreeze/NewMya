--!nocheck
-- Aftermath (PlaceId: 112237800564065)
-- Ported from CatHook; GUI replaced with Fluent Modded per New_Mya standards.

local _module = {}

do
	-- ── Shared state (accessible by both mount and unmount) ──────────────
	local _conns     = {}  -- RBXScriptConnection[]
	local _drawings  = {}  -- Drawing[]
	local _window    = nil -- Fluent window handle
	local _previewSound = nil

	-- Per-feature cleanup handles
	local _origLighting   = {}
	local _origAtmDensity = 0.5
	local _origClouds     = true
	local _origSkybox     = nil

	local _ESPs       = {}
	local _graveESP   = { Enabled=false, ShowDistance=true, Outline=true, Size=16, Color=Color3.fromRGB(128,0,128), ActiveDrawings={} }
	local _ammoESP    = { Enabled=false, Outline=true, Size=14, Color=Color3.fromRGB(255,69,0), ShowDistance=true, RenderDistance=1000, ActiveDrawings={} }
	local _weaponsESP = { Enabled=false, Size=16, Outline=true, Color=Color3.fromRGB(0,191,255), ExcludeMelee=false, ShowDistance=true, RenderRange=500, ActiveDrawings={} }
	local _carData    = {}
	local _tracers    = {}
	local _silentThread     = nil
	local _manipAnchor      = nil
	local _hitsoundThreads  = {}
	local _noRecoilRestore  = nil
	local _origOffsets      = {}

	local function _addConn(c)  table.insert(_conns, c);    return c end
	local function _addDraw(d)  table.insert(_drawings, d); return d end

	-- ── Cleanup helpers ──────────────────────────────────────────────────
	local function _cleanESPs()
		for _, ed in pairs(_ESPs) do
			if ed.Connection then pcall(function() ed.Connection:Disconnect() end) end
			for _, d in pairs(ed.Drawings) do pcall(function() d.Visible=false; d:Remove() end) end
		end
		_ESPs = {}
	end

	local function _cleanTracers()
		for _, tr in ipairs(_tracers) do pcall(function() tr.part:Destroy() end) end
		table.clear(_tracers)
	end

	local function _restoreOffsets()
		local RS = game:GetService("ReplicatedStorage")
		for gunName, orig in pairs(_origOffsets) do
			pcall(function()
				local df = RS:FindFirstChild("GunData") and RS.GunData:FindFirstChild(gunName)
				if df then
					local ov = df.Stats and df.Stats:FindFirstChild("Offset")
					if ov and ov:IsA("Vector3Value") then ov.Value = orig end
				end
			end)
		end
		table.clear(_origOffsets)
	end

	-- ════════════════════════════════════════════════════════════════════
	_module.mount = function(ctx)
		local baseUrl = (ctx and ctx.baseUrl) or (typeof(getgenv)=="function" and getgenv().MYA_BASE_URL) or ""

		local RunService      = game:GetService("RunService")
		local Players         = game:GetService("Players")
		local UserInputService= game:GetService("UserInputService")
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Debris          = game:GetService("Debris")
		local SoundService    = game:GetService("SoundService")
		local HttpService     = game:GetService("HttpService")
		local lighting        = game:GetService("Lighting")

		local LocalPlayer = Players.LocalPlayer
		local Camera      = workspace.CurrentCamera

		-- ── Fluent load ─────────────────────────────────────────────────
		local FLUENT_URL = "https://github.com/StyearX/Fluent-Modded/releases/download/FluentBeta/Fluent.lua"
		local function stripBOM(s)
			if string.byte(s,1)==239 and string.byte(s,2)==187 and string.byte(s,3)==191 then return string.sub(s,4) end
			return s
		end
		local function isHtml(s) local l=string.lower(string.sub(s,1,200)); return l:find("<!doctype",1,true) or l:find("<html",1,true) end

		local Fluent
		do
			local src
			local genv = typeof(getgenv)=="function" and getgenv()
			local pre  = genv and genv.MYA_PREFETCH_FLUENT_SRC
			if typeof(pre)=="string" and #pre>500 then
				src = pre; genv.MYA_PREFETCH_FLUENT_SRC = nil
			end
			if not src and #baseUrl>0 then
				local ok,raw = pcall(game.HttpGet, game, baseUrl.."New_Mya/lib/FluentModded.lua", true)
				if ok and typeof(raw)=="string" and #raw>500 and not isHtml(raw) then src = stripBOM(raw) end
			end
			if not src then
				local ok2,raw2 = pcall(game.HttpGet, game, FLUENT_URL, true)
				if ok2 and typeof(raw2)=="string" and #raw2>500 then src = stripBOM(raw2) end
			end
			assert(src and #src>0, "[Aftermath] Fluent source unavailable.")
			local fn = assert(loadstring(src,"@FluentModded"), "[Aftermath] Fluent compile failed.")
			Fluent = fn()
			assert(Fluent and Fluent.CreateWindow, "[Aftermath] Fluent library invalid.")
		end

		local SaveManager      = Fluent.SaveManager
		local InterfaceManager = Fluent.InterfaceManager

		SaveManager:SetLibrary(Fluent)
		InterfaceManager:SetLibrary(Fluent)
		InterfaceManager:SetFolder("MyaAftermath")
		SaveManager:SetFolder("MyaAftermath/Config")

		-- Patch options.json to enforce RightShift before LoadSettings
		pcall(function()
			if typeof(makefolder)=="function" then pcall(makefolder,"MyaAftermath") end
			if typeof(readfile)=="function" and typeof(writefile)=="function" then
				local optPath = "MyaAftermath/options.json"
				local opts = {}
				local ok,raw = pcall(readfile, optPath)
				if ok and typeof(raw)=="string" and #raw>0 then
					pcall(function() opts = HttpService:JSONDecode(raw) end)
				end
				opts.MenuKeybind = "RightShift"
				pcall(writefile, optPath, HttpService:JSONEncode(opts))
			end
		end)

		InterfaceManager:LoadSettings()
		local ifacePre = InterfaceManager.Settings

		-- Read saved layout
		local layoutFile = "MyaAftermath/layout.json"
		local savedLayout
		pcall(function()
			if typeof(readfile)=="function" then
				local raw = readfile(layoutFile)
				if typeof(raw)=="string" and #raw>0 then savedLayout = HttpService:JSONDecode(raw) end
			end
		end)
		local winSize = UDim2.fromOffset(600, 560)
		if savedLayout then
			local sx,sy = tonumber(savedLayout.sx), tonumber(savedLayout.sy)
			if sx and sy and sx>=400 and sy>=300 then winSize = UDim2.fromOffset(math.floor(sx),math.floor(sy)) end
		end

		-- Hide until theme applied
		pcall(function() if Fluent.GUI then Fluent.GUI.Enabled = false end end)

		local Window = Fluent:CreateWindow({
			Title        = "Mya | Aftermath",
			SubTitle     = "Aftermath",
			TabWidth     = 160,
			Size         = winSize,
			Acrylic      = false,
			Theme        = (ifacePre and ifacePre.Theme) or "Blood Red",
			MinimizeKey  = Enum.KeyCode.RightShift,
			Search       = false,
		})
		assert(Window and Window.AddTab, "[Aftermath] Fluent CreateWindow failed.")
		_window = Window

		-- Reveal after theme sync
		task.defer(function()
			pcall(function()
				local s = InterfaceManager.Settings
				if s and s.Theme then Fluent:SetTheme(s.Theme) end
				Fluent:ToggleTransparency(s and s.Transparency ~= false or true)
				if Fluent.GUI then Fluent.GUI.Enabled = true end
			end)
		end)

		-- Periodic layout save (every 10 s)
		task.spawn(function()
			while _window do
				task.wait(10)
				pcall(function()
					if not _window then return end
					local rf = Window.Root
					if rf and rf:IsA("Frame") and rf.AbsoluteSize.X>=400 then
						if typeof(makefolder)=="function" then pcall(makefolder,"MyaAftermath") end
						if typeof(writefile)=="function" then
							writefile(layoutFile, HttpService:JSONEncode({sx=rf.AbsoluteSize.X, sy=rf.AbsoluteSize.Y}))
						end
					end
				end)
			end
		end)

		-- Capture original lighting
		_origLighting   = { Brightness=lighting.Brightness, ClockTime=lighting.ClockTime, GlobalShadows=lighting.GlobalShadows, OutdoorAmbient=lighting.OutdoorAmbient }
		_origAtmDensity = lighting:FindFirstChild("Atmosphere") and lighting.Atmosphere.Density or 0.5
		_origClouds     = workspace.Terrain:FindFirstChild("Clouds") and workspace.Terrain.Clouds.Enabled or true
		do
			local sky = lighting:FindFirstChild("Sky")
			if sky then _origSkybox = {SkyboxBk=sky.SkyboxBk,SkyboxDn=sky.SkyboxDn,SkyboxFt=sky.SkyboxFt,SkyboxLf=sky.SkyboxLf,SkyboxRt=sky.SkyboxRt,SkyboxUp=sky.SkyboxUp} end
		end

		-- ── Feature state ────────────────────────────────────────────────
		-- Player ESP
		local espEnabled, boxEnabled, boxFilledEnabled, boxOutlineEnabled = false, false, false, false
		local nameEnabled, distEnabled = false, false
		local maxESPDist = 1000
		local boxColor = Color3.fromRGB(255, 255, 255)
		local boxOutlineColor = Color3.fromRGB(0, 0, 0)
		local nameColor = Color3.fromRGB(255, 255, 255)
		local distColor = Color3.fromRGB(255, 255, 255)

		-- Aimbot
		local aimbot = {
			enabled=false, showFOV=false, fovRadius=200, fovThickness=2, smoothing=0.5,
			fovColor=Color3.fromRGB(255,255,255), fovRainbow=false,
			keybind=Enum.UserInputType.MouseButton2, aiming=false,
			predXAdjust=1, predYAdjust=1, GRAVITY=60,
		}
		local fovCircle = _addDraw(Drawing.new("Circle"))
		fovCircle.Radius=200; fovCircle.Thickness=2; fovCircle.NumSides=64
		fovCircle.Color=Color3.fromRGB(255,255,255); fovCircle.Transparency=1
		fovCircle.Filled=false; fovCircle.Visible=false

		-- Gunmods
		local offsetEnabled, offsetX, offsetY, offsetZ = false, 5, 0, -5

		-- Hitsounds
		local HITSOUNDS = {
			Rust=5043539486, Minecraft=140322880337590, Pop=6586979979,
			CS=5764885315, Neverlose=97643101798871, Gamesense=4817809188, ["nn dog"]=5902468562
		}
		local hitsoundsEnabled, hitmarkerName, headshotName = false, "Rust", "CS"
		_previewSound = Instance.new("Sound"); _previewSound.Parent=SoundService; _previewSound.Volume=2

		-- Crosshair
		local ch = {
			Enabled=false, Color=Color3.new(1,1,1), Rainbow=false, Style="Default",
			Size=20, Thickness=2, Gap=5, Outline=true, Dot=true,
			RotationSpeed=2, Pulse=true, PulseSpeed=3, ScreenCenter=true,
		}
		local chLines = {}
		for i=1,4 do chLines[i]={main=_addDraw(Drawing.new("Line")),outline=_addDraw(Drawing.new("Line"))} end
		local chDot    = _addDraw(Drawing.new("Circle")); chDot.Radius=2; chDot.Filled=true; chDot.ZIndex=3; chDot.Visible=false
		local chCircle = _addDraw(Drawing.new("Circle")); chCircle.NumSides=24; chCircle.Filled=false; chCircle.ZIndex=2; chCircle.Visible=false
		for _,l in ipairs(chLines) do l.main.Visible=false; l.outline.Visible=false end
		local chRainbow,chPulse,chRot = 0,0,0

		-- Lightning tracers
		local ltEnabled, ltAutoFire = false, false
		local ltFireRate, ltThick, ltDuration = 10, 1, 1
		local ltColor = Color3.fromRGB(0, 200, 255)
		local ltMouseBegin, ltMouseEnd, ltHB, ltLastFire = nil, nil, nil, 0

		-- World
		local fullbright, noFog, timeEnabled, removeClouds = false, false, false, false
		local timeVal = 12

		-- Skybox table
		local SKYBOXES = {
			["Standard"]    = {"91458024","91457980","91458024","91458024","91458024","91458002"},
			["Blue Sky"]    = {"591058823","591059876","591058104","591057861","591057625","591059642"},
			["Vaporwave"]   = {"1417494030","1417494146","1417494253","1417494402","1417494499","1417494643"},
			["Redshift"]    = {"401664839","401664862","401664960","401664881","401664901","401664936"},
			["Blaze"]       = {"150939022","150939038","150939047","150939056","150939063","150939082"},
			["Dark Night"]  = {"6285719338","6285721078","6285722964","6285724682","6285726335","6285730635"},
			["Bright Pink"] = {"271042516","271077243","271042556","271042310","271042467","271077958"},
			["Galaxy"]      = {"15125283003","15125281008","15125277539","15125279325","15125274388","15125275800"},
		}

		-- Anti-aim
		local antiAimEnabled, antiAimAngle = false, "Among Us"
		local cae = ReplicatedStorage:FindFirstChild("CameraAngleEvent")

		-- FOV changer
		local fovChangerEnabled, targetFov = false, 80

		-- Chams
		local bodyChamsEnabled = false
		local bodyChamsColor = Color3.fromRGB(255, 255, 255)
		local chamsMat = Enum.Material.ForceField
		local weapChamsEnabled = false
		local weapChamsColor = Color3.fromRGB(244, 224, 155)
		local weapChamsMat = Enum.Material.ForceField

		-- Manipulation
		local manipEnabled, manipActive = false, false
		local manipSpeed, manipOrigCF, manipStartPos = 0.5, nil, nil
		local distLabel = _addDraw(Drawing.new("Text"))
		distLabel.Visible=false; distLabel.Center=true; distLabel.Outline=true
		distLabel.Font=2; distLabel.Size=16; distLabel.Color=Color3.new(1,1,1)
		distLabel.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/4)

		-- No Blur / No Tree
		local noBlurEnabled, noTreeEnabled = false, false
		local noTreeCache, noTreeLastCheck = {}, 0

		-- Melee blacklist for weapons ESP
		local MELEE = {
			AxeFire=true,ChemLight=true,Cleaver=true,CombatKnife=true,Crowbar=true,
			HandSaw=true,Shovel=true,KitchenKnife=true,GrenadeSmokeMakeshift=true,
			GrenadeSmoke=true,AxeMakeshift=true,Cuffs=true,Fists=true,
			GenericItemThrow=true,Generic_consumable=true,GrenadeFrag=true,
			GrenadeGas=true,GrenadeMolotov=true,GrenadePipebomb=true,Snowball=true,
			ThrowableBottle=true,Wrench=true,SteakKnife=true,
		}

		-- Gun data mesh cache
		local gunMeshCache = {}
		local gunDataFolder = ReplicatedStorage:WaitForChild("GunData",5)
		if gunDataFolder then
			for _,f in ipairs(gunDataFolder:GetChildren()) do
				local wm = f:FindFirstChild("WorldModel")
				if wm then
					local info={}
					for _,c in ipairs(wm:GetChildren()) do
						if c:IsA("MeshPart") then
							local cn={}; for _,ch in ipairs(c:GetChildren()) do table.insert(cn,ch.Name) end; table.sort(cn)
							table.insert(info,{Name=c.Name,MeshId=c.MeshId,CN=cn})
						end
					end
					table.sort(info,function(a,b) return a.Name<b.Name end)
					gunMeshCache[f.Name]=info
				end
			end
		end

		-- ── Logic helpers ────────────────────────────────────────────────

		local function removePlayerESP(player)
			local ed = _ESPs[player]; if not ed then return end
			if ed.Connection then pcall(function() ed.Connection:Disconnect() end) end
			for _,d in pairs(ed.Drawings) do pcall(function() d.Visible=false; d:Remove() end) end
			_ESPs[player] = nil
		end

		local function setupPlayerESP(player)
			removePlayerESP(player)
			local D = {
				Box        = Drawing.new("Square"),
				BoxOutline = Drawing.new("Square"),
				Name       = Drawing.new("Text"),
				Distance   = Drawing.new("Text"),
			}
			D.Name.Color=nameColor; D.Name.Center=true; D.Name.Outline=true
			D.Name.OutlineColor=Color3.fromRGB(0,0,0); D.Name.Size=14; D.Name.Visible=false
			D.Distance.Color=distColor; D.Distance.Center=true; D.Distance.Outline=true
			D.Distance.OutlineColor=Color3.fromRGB(0,0,0); D.Distance.Size=14; D.Distance.Visible=false
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not espEnabled then for _,d in pairs(D) do d.Visible=false end; return end
				local char=player.Character
				if not char then for _,d in pairs(D) do d.Visible=false end; return end
				local hrp=char:FindFirstChild("HumanoidRootPart")
				if not hrp then for _,d in pairs(D) do d.Visible=false end; return end
				local dist=(hrp.Position-Camera.CFrame.Position).Magnitude
				if dist>maxESPDist then for _,d in pairs(D) do d.Visible=false end; return end
				local adjPos=hrp.Position+Vector3.new(0,1.5,0)
				local pos,onS=Camera:WorldToViewportPoint(adjPos)
				if onS then
					local scale=1/(pos.Z*math.tan(math.rad(Camera.FieldOfView*0.5))*2)*1000
					local w,h=math.floor(4.5*scale),math.floor(6*scale)
					local x,y=math.floor(pos.X),math.floor(pos.Y)
					local yp=math.floor((y-h*0.5)+(0.5*scale)-15)
					local xp=math.floor(x-w*0.5)
					D.Box.Size=Vector2.new(w,h); D.Box.Position=Vector2.new(xp,yp)
					D.Box.Visible=boxEnabled; D.Box.Color=boxColor; D.Box.Thickness=1
					D.Box.Filled=boxFilledEnabled; D.Box.Transparency=boxFilledEnabled and 0.5 or 0
					D.BoxOutline.Size=Vector2.new(w,h); D.BoxOutline.Position=Vector2.new(xp,yp)
					D.BoxOutline.Visible=boxOutlineEnabled; D.BoxOutline.Color=boxOutlineColor
					D.BoxOutline.Thickness=2; D.BoxOutline.ZIndex=1; D.Box.ZIndex=2
					D.Name.Position=Vector2.new(x,yp-15); D.Name.Text="("..player.Name..")"
					D.Name.Visible=nameEnabled; D.Name.Color=nameColor; D.Name.ZIndex=3
					D.Distance.Position=Vector2.new(x,yp+h+5); D.Distance.Text=string.format("(%.0fm)",dist)
					D.Distance.Visible=distEnabled; D.Distance.Color=distColor; D.Distance.ZIndex=3
				else
					for _,d in pairs(D) do d.Visible=false end
				end
			end)
			_ESPs[player]={Connection=conn,Drawings=D}
			local function onCharAdded(char)
				local hum=char:WaitForChild("Humanoid")
				hum.Died:Connect(function() removePlayerESP(player) end)
				task.delay(0.1,function() setupPlayerESP(player) end)
			end
			if player.Character then onCharAdded(player.Character) end
			player.CharacterAdded:Connect(onCharAdded)
		end

		local function updateGraveESP()
			for _,model in ipairs(workspace:GetChildren()) do
				if model:IsA("Model") and model.Name=="Default" and not _graveESP.ActiveDrawings[model] then
					local mp=model:FindFirstChildWhichIsA("MeshPart")
					if mp then
						local t=Drawing.new("Text"); t.Size=_graveESP.Size; t.Center=true; t.Outline=_graveESP.Outline
						t.Color=_graveESP.Color; t.Visible=false
						_graveESP.ActiveDrawings[model]={text=t,part=mp}
					end
				end
			end
			for model,data in pairs(_graveESP.ActiveDrawings) do
				if not model:IsDescendantOf(workspace) or not data.part then
					pcall(function() data.text:Remove() end); _graveESP.ActiveDrawings[model]=nil
				else
					local sp,onS=Camera:WorldToViewportPoint(data.part.Position)
					if onS and _graveESP.Enabled then
						local name=data.part:GetAttribute("DisplayName") or "Grave"
						local searched=data.part:GetAttribute("Searched")
						local distStr=""
						if typeof(searched)=="boolean" and searched then name="[S] "..name end
						if _graveESP.ShowDistance then distStr=string.format(" [%.1fm]",(Camera.CFrame.Position-data.part.Position).Magnitude) end
						data.text.Text=name..distStr; data.text.Position=Vector2.new(sp.X,sp.Y)
						data.text.Size=_graveESP.Size; data.text.Color=_graveESP.Color
						data.text.Outline=_graveESP.Outline; data.text.Visible=true
					else data.text.Visible=false end
				end
			end
		end

		local function extractId(str)
			if type(str)~="string" then return tostring(str) end
			return str:match("(%d+)") or str
		end

		local function scanAmmo()
			if not _ammoESP.Enabled then return end
			local wa=workspace:FindFirstChild("world_assets"); if not wa then return end
			local so=wa:FindFirstChild("StaticObjects"); if not so then return end
			local misc=so:FindFirstChild("Misc"); if not misc then return end
			local af=ReplicatedStorage:FindFirstChild("Assets"); if not af then return end
			af=af:FindFirstChild("ViewModels"); if not af then return end
			af=af:FindFirstChild("Combat"); if not af then return end
			af=af:FindFirstChild("Ammo"); if not af then return end
			for _,mc in ipairs(misc:GetChildren()) do
				if mc:IsA("Model") then
					local src=mc:FindFirstChild("Main")
					if src and src:IsA("MeshPart") and not _ammoESP.ActiveDrawings[src] then
						local smesh,stex=extractId(src.MeshId),extractId(src.TextureID)
						for _,am in ipairs(af:GetChildren()) do
							if am:IsA("Model") and am.Name~="Model" then
								local amain=am:FindFirstChild("Main")
								if amain and amain:IsA("MeshPart") then
									if extractId(amain.MeshId)==smesh and extractId(amain.TextureID)==stex then
										local t=Drawing.new("Text"); t.Center=true; t.Visible=false
										t.Text=am.Name; t.Outline=_ammoESP.Outline; t.Size=_ammoESP.Size; t.Color=_ammoESP.Color
										_ammoESP.ActiveDrawings[src]={drawing=t,label=am.Name}
									end
								end
							end
						end
					end
				end
			end
		end

		local function getMeshInfo(model)
			local info={}
			for _,c in ipairs(model:GetChildren()) do
				if c:IsA("MeshPart") then
					local cn={}; for _,ch in ipairs(c:GetChildren()) do table.insert(cn,ch.Name) end; table.sort(cn)
					table.insert(info,{Name=c.Name,MeshId=c.MeshId,CN=cn})
				end
			end
			table.sort(info,function(a,b) return a.Name<b.Name end); return info
		end

		local function meshInfoMatch(a,b)
			if #a~=#b then return false end
			for i=1,#a do
				if a[i].Name~=b[i].Name or a[i].MeshId~=b[i].MeshId then return false end
				local c1,c2=a[i].CN,b[i].CN; if #c1~=#c2 then return false end
				for j=1,#c1 do if c1[j]~=c2[j] then return false end end
			end
			return true
		end

		local function getSortedNames(model,descendants)
			local names={}
			local iter=descendants and model:GetDescendants() or model:GetChildren()
			for _,c in ipairs(iter) do table.insert(names,c.Name) end
			table.sort(names); return names
		end

		local function nameListMatch(a,b)
			if #a~=#b then return false end
			for i=1,#a do if a[i]~=b[i] then return false end end
			return true
		end

		local function identifyGun(model)
			if not model:IsA("Model") then return nil end
			local mi=getMeshInfo(model)
			if #mi>0 then
				for name,ref in pairs(gunMeshCache) do if meshInfoMatch(mi,ref) then return name end end
			else
				local cn=getSortedNames(model,false); local cands={}
				for name,_ in pairs(gunMeshCache) do
					local gd=gunDataFolder and gunDataFolder:FindFirstChild(name)
					if gd and gd:FindFirstChild("WorldModel") and nameListMatch(cn,getSortedNames(gd.WorldModel,false)) then
						table.insert(cands,name)
					end
				end
				if #cands==1 then return cands[1]
				elseif #cands>1 then
					local dn=getSortedNames(model,true)
					for _,name in ipairs(cands) do
						local gd=gunDataFolder and gunDataFolder:FindFirstChild(name)
						if gd and nameListMatch(dn,getSortedNames(gd.WorldModel,true)) then return name end
					end
				end
			end
			return nil
		end

		local function checkWeaponESP(model)
			local gunName=identifyGun(model); if not gunName then return end
			if _weaponsESP.ExcludeMelee and MELEE[gunName] then return end
			local handle=model:FindFirstChild("Handle")
			if not (handle and handle:IsA("BasePart")) then return end
			if _weaponsESP.ActiveDrawings[model] then return end
			local t=Drawing.new("Text"); t.Size=_weaponsESP.Size; t.Color=_weaponsESP.Color
			t.Center=true; t.Outline=_weaponsESP.Outline; t.OutlineColor=Color3.new(0,0,0)
			_weaponsESP.ActiveDrawings[model]={drawing=t,name=gunName}
		end

		local function scanWeapons()
			local wa=workspace:FindFirstChild("world_assets"); if not wa then return end
			local so=wa:FindFirstChild("StaticObjects"); if not so then return end
			local misc=so:FindFirstChild("Misc"); if not misc then return end
			for _,m in ipairs(misc:GetChildren()) do checkWeaponESP(m) end
		end

		local function updateWeaponsESP()
			if not _weaponsESP.Enabled then
				for _,d in pairs(_weaponsESP.ActiveDrawings) do if d.drawing then d.drawing.Visible=false end end; return
			end
			local camPos=Camera.CFrame.Position
			for model,data in pairs(_weaponsESP.ActiveDrawings) do
				local handle=model:FindFirstChild("Handle")
				if not handle or not model.Parent then
					pcall(function() data.drawing:Remove() end); _weaponsESP.ActiveDrawings[model]=nil
				else
					local dist=(handle.Position-camPos).Magnitude
					local pos,onS=Camera:WorldToViewportPoint(handle.Position)
					if onS and dist<=_weaponsESP.RenderRange then
						data.drawing.Text=_weaponsESP.ShowDistance and string.format("[G] %s [%dm]",data.name,math.floor(dist)) or "[G] "..data.name
						data.drawing.Position=Vector2.new(pos.X,pos.Y); data.drawing.Visible=true
					else data.drawing.Visible=false end
				end
			end
		end

		-- Car ESP
		local function refreshCars()
			for _,info in ipairs(_carData) do
				pcall(function() if info.txt then info.txt:Remove() end end)
				pcall(function() if info.dist then info.dist:Remove() end end)
			end
			table.clear(_carData)
			for _,obj in ipairs(workspace:GetChildren()) do
				if obj:IsA("Model") and obj.Name=="WorldModel" then table.insert(_carData,{modelo=obj}) end
			end
		end
		refreshCars()
		_addConn(workspace.ChildAdded:Connect(function(c) if c:IsA("Model") and c.Name=="WorldModel" then refreshCars() end end))
		_addConn(workspace.ChildRemoved:Connect(function(c) if c:IsA("Model") and c.Name=="WorldModel" then refreshCars() end end))

		local carEspEnabled = false
		local function updateCarESP()
			if not carEspEnabled then
				for _,info in ipairs(_carData) do
					pcall(function() if info.txt then info.txt.Visible=false end end)
					pcall(function() if info.dist then info.dist.Visible=false end end)
				end
				return
			end
			local camPos=Camera.CFrame.Position
			for i=#_carData,1,-1 do
				local info=_carData[i]
				if not info.modelo or not info.modelo.Parent then
					pcall(function() if info.txt then info.txt:Remove() end end)
					pcall(function() if info.dist then info.dist:Remove() end end)
					table.remove(_carData,i)
				else
					local ok,piv=pcall(function() return info.modelo:GetPivot() end)
					if ok and piv then
						local pp=piv.Position; local dist=(camPos-pp).Magnitude
						local pos2d,onS=Camera:WorldToViewportPoint(pp+Vector3.new(0,5,0))
						if dist<=4000 and onS and pos2d.Z>0 then
							if not info.txt then
								info.txt=Drawing.new("Text"); info.txt.Font=2; info.txt.Size=19
								info.txt.Color=Color3.fromRGB(255,0,0); info.txt.Center=true; info.txt.Outline=true
							end
							info.txt.Text="Car"; info.txt.Position=Vector2.new(pos2d.X,pos2d.Y); info.txt.Visible=true
							if not info.dist then
								info.dist=Drawing.new("Text"); info.dist.Font=1; info.dist.Size=15
								info.dist.Color=Color3.fromRGB(255,105,180); info.dist.Center=true; info.dist.Outline=true
							end
							info.dist.Text=string.format("(%dm)",math.floor(dist/3.6))
							info.dist.Position=Vector2.new(pos2d.X,pos2d.Y+15); info.dist.Visible=true
						else
							pcall(function() if info.txt then info.txt.Visible=false end end)
							pcall(function() if info.dist then info.dist.Visible=false end end)
						end
					end
				end
			end
		end

		-- Aimbot helpers
		local function worldToScreen(pos)
			local pt,onS=Camera:WorldToViewportPoint(pos); return Vector2.new(pt.X,pt.Y),onS
		end
		local function getBulletSpeed()
			local sel=LocalPlayer.CurrentSelectedObject and LocalPlayer.CurrentSelectedObject.Value
			if typeof(sel)~="Instance" then return 2200 end
			local inv=LocalPlayer:FindFirstChild("GunInventory"); local slot=inv and inv:FindFirstChild(sel.Name)
			if not (slot and slot.Value) then return 2200 end
			local gunName=typeof(slot.Value)=="string" and slot.Value or tostring(slot.Value)
			local data=ReplicatedStorage:FindFirstChild("GunData") and ReplicatedStorage.GunData:FindFirstChild(gunName)
			if not data then return 2200 end
			local bs=data.Stats and data.Stats:FindFirstChild("BulletSettings"); if not bs then return 2200 end
			local spd=bs:FindFirstChild("BulletSpeed")
			return (spd and spd:IsA("IntValue")) and spd.Value or 2200
		end
		local function calcDrop(dist,speed)
			if not speed or speed<=0 then return 0 end; local t=dist/speed; return 0.5*aimbot.GRAVITY*t*t
		end

		_addConn(UserInputService.InputBegan:Connect(function(inp,gp)
			if gp then return end
			if inp.UserInputType==aimbot.keybind then aimbot.aiming=true end
		end))
		_addConn(UserInputService.InputEnded:Connect(function(inp)
			if inp.UserInputType==aimbot.keybind then aimbot.aiming=false end
		end))

		-- Silent reload
		local function handleSilentReload()
			if _silentThread then task.cancel(_silentThread); _silentThread=nil end
			if not (task and game) then return end
			_silentThread = task.spawn(function()
				while true do
					if not _silentThread then break end
					pcall(function() ReplicatedStorage.GunEvent.GunReloadStart:FireServer() end)
					task.wait(0)
				end
			end)
		end
		local silentReloadEnabled=false

		-- Gun offsets
		local function applyOffset()
			pcall(function()
				local sel=LocalPlayer.CurrentSelectedObject and LocalPlayer.CurrentSelectedObject.Value; if not sel then return end
				local inv=LocalPlayer:FindFirstChild("GunInventory"); local item=inv and inv:FindFirstChild(sel.Name)
				if not (item and item.Value) then return end
				local df=ReplicatedStorage:FindFirstChild("GunData") and ReplicatedStorage.GunData:FindFirstChild(item.Value.Name); if not df then return end
				local ov=df.Stats and df.Stats:FindFirstChild("Offset"); if not (ov and ov:IsA("Vector3Value")) then return end
				if not _origOffsets[item.Value.Name] then _origOffsets[item.Value.Name]=ov.Value end
				ov.Value=Vector3.new(offsetX,offsetY,offsetZ)
			end)
		end

		-- Hitsounds
		local SOUNDS_PATH = {"Assets","Sounds","DefaultHitmarker"}
		local function findSoundsFolder()
			local cur=ReplicatedStorage
			for _,n in ipairs(SOUNDS_PATH) do cur=cur:FindFirstChild(n); if not cur then return nil end end
			return cur
		end
		local function startHitsounds()
			local repl={
				Hitmarker="rbxassetid://"..tostring(HITSOUNDS[hitmarkerName] or HITSOUNDS.Rust),
				Headshot ="rbxassetid://"..tostring(HITSOUNDS[headshotName]  or HITSOUNDS.CS),
			}
			table.insert(_hitsoundThreads,task.spawn(function()
				local sf; while not sf do sf=findSoundsFolder(); if not sf then task.wait(1) end end
				while hitsoundsEnabled do
					for sName,newId in pairs(repl) do
						local s=sf:FindFirstChild(sName)
						if s and s:IsA("Sound") and s.SoundId~=newId then s.SoundId=newId; s.Volume=2 end
					end
					task.wait(0.5)
				end
			end))
		end
		local function stopHitsounds()
			for _,t in ipairs(_hitsoundThreads) do pcall(function() task.cancel(t) end) end
			table.clear(_hitsoundThreads)
		end

		-- Lightning tracers
		local function fireTracer()
			local cam=workspace.CurrentCamera; if not cam then return end
			local part=Instance.new("Part"); part.Anchored=true; part.CanCollide=false; part.Transparency=1
			part.Size=Vector3.new(0.1,0.1,0.1); part.CFrame=cam.CFrame; part.Parent=workspace
			local a0=Instance.new("Attachment"); a0.Parent=part
			local a1=Instance.new("Attachment"); a1.Position=cam.CFrame.LookVector*1000; a1.Parent=part
			local beam=Instance.new("Beam")
			beam.Texture="rbxassetid://446111271"; beam.TextureSpeed=3+math.random()*2; beam.TextureLength=0.5
			beam.LightEmission=1; beam.Color=ColorSequence.new(ltColor)
			beam.Width0=ltThick; beam.Width1=ltThick*0.8; beam.FaceCamera=true
			beam.Transparency=NumberSequence.new(0); beam.Attachment0=a0; beam.Attachment1=a1; beam.Parent=part
			table.insert(_tracers,{part=part,startTime=os.clock()})
		end
		local function updateTracers()
			local now=os.clock()
			for i=#_tracers,1,-1 do
				if now-_tracers[i].startTime>=ltDuration then
					pcall(function() _tracers[i].part:Destroy() end); table.remove(_tracers,i)
				end
			end
		end
		local function startLightning()
			ltMouseBegin=_addConn(UserInputService.InputBegan:Connect(function(inp,gp)
				if not ltEnabled or gp then return end
				if inp.UserInputType==Enum.UserInputType.MouseButton1 then
					fireTracer()
					if ltAutoFire then
						ltHB=_addConn(RunService.Heartbeat:Connect(function()
							if os.clock()-ltLastFire>=1/ltFireRate then fireTracer(); ltLastFire=os.clock() end
						end))
					end
				end
			end))
			ltMouseEnd=_addConn(UserInputService.InputEnded:Connect(function(inp)
				if inp.UserInputType==Enum.UserInputType.MouseButton1 and ltHB then ltHB:Disconnect(); ltHB=nil end
			end))
		end
		local function stopLightning()
			if ltMouseBegin then ltMouseBegin:Disconnect(); ltMouseBegin=nil end
			if ltMouseEnd  then ltMouseEnd:Disconnect();  ltMouseEnd=nil end
			if ltHB        then ltHB:Disconnect();        ltHB=nil end
			_cleanTracers()
		end

		-- Skybox
		local function applySkybox(name)
			local sky=lighting:FindFirstChild("Sky")
			if name=="Default" then
				if sky then sky:Destroy() end
				if _origSkybox then
					local ns=Instance.new("Sky"); ns.Parent=lighting
					ns.SkyboxBk=_origSkybox.SkyboxBk; ns.SkyboxDn=_origSkybox.SkyboxDn; ns.SkyboxFt=_origSkybox.SkyboxFt
					ns.SkyboxLf=_origSkybox.SkyboxLf; ns.SkyboxRt=_origSkybox.SkyboxRt; ns.SkyboxUp=_origSkybox.SkyboxUp
				end
			else
				local data=SKYBOXES[name]; if not data then return end
				if not sky then sky=Instance.new("Sky"); sky.Parent=lighting end
				sky.SkyboxBk="rbxassetid://"..data[1]; sky.SkyboxDn="rbxassetid://"..data[2]
				sky.SkyboxFt="rbxassetid://"..data[3]; sky.SkyboxLf="rbxassetid://"..data[4]
				sky.SkyboxRt="rbxassetid://"..data[5]; sky.SkyboxUp="rbxassetid://"..data[6]
			end
		end

		-- FOV changer
		local function applyFOV()
			pcall(function()
				local ctrl=require(LocalPlayer.PlayerScripts:WaitForChild("CameraFovController"))
				ctrl.ClientFov=targetFov; ctrl:Enable()
			end)
		end
		local function resetFOV()
			pcall(function()
				local ctrl=require(LocalPlayer.PlayerScripts:WaitForChild("CameraFovController"))
				ctrl.ClientFov=80; ctrl:Enable()
			end)
		end

		-- Chams
		local function isArm(p) return table.find({"LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand"},p.Name)~=nil end
		local function chamPart(part)
			if not part:IsA("BasePart") then return end
			for _,c in ipairs(part:GetChildren()) do if c:IsA("SurfaceAppearance") then c:Destroy() end end
			part.Material=chamsMat; part.Color=isArm(part) and bodyChamsColor or bodyChamsColor
		end
		local function applyBodyChams()
			if not bodyChamsEnabled then return end
			local folder=workspace:FindFirstChild("Characters"); if not folder then return end
			for _,char in pairs(folder:GetChildren()) do
				for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then chamPart(part) end end
			end
			for _,obj in pairs(workspace.Camera:GetDescendants()) do
				if obj.Name=="Skin" and obj:IsA("BasePart") then
					obj.Material=chamsMat; obj.Color=bodyChamsColor
					for _,c in pairs(obj:GetChildren()) do if c:IsA("SurfaceAppearance") then c:Destroy() end end
				end
			end
		end
		local function applyWeaponChams(gun)
			if not weapChamsEnabled or not gun then return end
			local parts=gun:FindFirstChild("Weapon"); if not parts then return end
			for _,v in pairs(parts:GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency<1 then v.Material=weapChamsMat; v.Color=weapChamsColor end
				if v:IsA("SurfaceAppearance") then v:Destroy() end
			end
		end
		_addConn(workspace.Camera.DescendantAdded:Connect(function(obj)
			if obj.Name=="Skin" and obj:IsA("BasePart") and bodyChamsEnabled then task.delay(0.1,applyBodyChams) end
			if obj.Name=="CurrentWeapon" then task.delay(0.1,function() applyWeaponChams(obj) end) end
		end))
		do local cw=workspace.Camera:FindFirstChild("CurrentWeapon"); if cw then applyWeaponChams(cw) end end

		-- ── Main loops ───────────────────────────────────────────────────

		_addConn(RunService.RenderStepped:Connect(function(delta)
			-- Aimbot + FOV circle
			local center2d=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
			fovCircle.Position=center2d; fovCircle.Visible=aimbot.showFOV
			fovCircle.Color=aimbot.fovRainbow and Color3.fromHSV(tick()%5/5,1,1) or aimbot.fovColor
			if aimbot.enabled and aimbot.aiming then
				local heads={}
				local chars=workspace:FindFirstChild("Characters")
				if chars then for _,m in ipairs(chars:GetChildren()) do if m:IsA("Model") and m:FindFirstChild("Head") then table.insert(heads,m.Head) end end end
				local myHead=LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("ServerColliderHead") or LocalPlayer.Character:FindFirstChild("Head"))
				local ignIdx,ignDist=nil,math.huge
				if myHead then for i,h in ipairs(heads) do local d=(h.Position-myHead.Position).Magnitude; if d<ignDist then ignDist=d;ignIdx=i end end end
				local targetHead,minDist=nil,math.huge
				for i,h in ipairs(heads) do
					if i~=ignIdx then
						local p2d,onS=worldToScreen(h.Position)
						if onS then local d=(p2d-center2d).Magnitude; if d<=aimbot.fovRadius and d<minDist then minDist=d;targetHead=h end end
					end
				end
				if targetHead then
					local camPos=Camera.CFrame.Position; local hp=targetHead.Position
					local hd=(Vector3.new(hp.X,camPos.Y,hp.Z)-camPos).Magnitude
					local spd=getBulletSpeed(); local drop=calcDrop(hd,spd)*1.4*aimbot.predYAdjust
					local predOff=Vector3.zero
					for _,plr in ipairs(Players:GetPlayers()) do
						if plr~=LocalPlayer and plr.Character then
							local sch=plr.Character:FindFirstChild("ServerColliderHead")
							if sch and (sch.Position-hp).Magnitude<10 then
								predOff=sch.Velocity*(hd/spd)*aimbot.predXAdjust; break
							end
						end
					end
					local comp=hp+Vector3.new(0,drop*1.5,0)+predOff
					local c2d,onS=worldToScreen(comp)
					if onS and typeof(mousemoverel)=="function" then
						local dv=c2d-center2d; mousemoverel(dv.X*aimbot.smoothing,dv.Y*aimbot.smoothing)
					end
				end
			end

			-- Crosshair
			local cPos=ch.ScreenCenter and center2d or UserInputService:GetMouseLocation()
			if not ch.Enabled then
				chDot.Visible=false; chCircle.Visible=false
				for _,l in ipairs(chLines) do l.main.Visible=false; l.outline.Visible=false end
			else
				chRainbow=(chRainbow+delta*0.5)%1
				local col=ch.Rainbow and Color3.fromHSV(chRainbow,1,1) or ch.Color
				if ch.Pulse then chPulse=(chPulse+delta*ch.PulseSpeed)%(math.pi*2) end
				local pm=ch.Pulse and (math.sin(chPulse)*0.25+0.75) or 1
				chRot=(chRot+delta*ch.RotationSpeed)%(math.pi*2)
				chDot.Visible=false; chCircle.Visible=false
				for _,l in ipairs(chLines) do l.main.Visible=false; l.outline.Visible=false end
				local sty=ch.Style
				if sty=="Default" or sty=="Swastika" then
					for i=1,4 do
						local ang=chRot+math.rad(i*90); local dir=Vector2.new(math.cos(ang),math.sin(ang))
						local sp=cPos+dir*ch.Gap; local ep=cPos+dir*ch.Size*pm
						chLines[i].main.Visible=true; chLines[i].main.From=sp; chLines[i].main.To=ep
						chLines[i].main.Color=col; chLines[i].main.Thickness=ch.Thickness
						if ch.Outline then
							if sty=="Swastika" then
								local mp=cPos+dir*ch.Size*0.5*pm; local perp=Vector2.new(math.cos(ang+math.rad(90)),math.sin(ang+math.rad(90)))
								chLines[i].outline.Visible=true; chLines[i].outline.From=mp
								chLines[i].outline.To=mp+perp*ch.Size*0.5*pm; chLines[i].outline.Color=col; chLines[i].outline.Thickness=ch.Thickness
							else
								chLines[i].outline.Visible=true; chLines[i].outline.From=sp-Vector2.new(1,1); chLines[i].outline.To=ep-Vector2.new(1,1)
								chLines[i].outline.Color=Color3.new(0,0,0); chLines[i].outline.Thickness=ch.Thickness+2
							end
						end
					end
				elseif sty=="Circle" then
					chCircle.Visible=true; chCircle.Position=cPos; chCircle.Radius=ch.Size*pm; chCircle.Color=col; chCircle.Thickness=ch.Thickness
				elseif sty=="Dot" then
					chDot.Visible=true; chDot.Position=cPos; chDot.Color=col; chDot.Radius=ch.Size*0.5*pm
				end
				if ch.Dot and sty~="Dot" then
					chDot.Visible=true; chDot.Position=cPos; chDot.Color=col; chDot.Radius=ch.Thickness*pm
				end
			end

			-- World effects
			if fullbright then lighting.Brightness=10; lighting.ClockTime=12; lighting.GlobalShadows=false; lighting.OutdoorAmbient=Color3.fromRGB(255,255,255) end
			if noFog and lighting:FindFirstChild("Atmosphere") then lighting.Atmosphere.Density=0 end
			if timeEnabled then lighting.ClockTime=timeVal end

			-- No Blur
			if noBlurEnabled then
				local blur=workspace.CurrentCamera:FindFirstChild("Blur")
				if blur then blur.Enabled=false end
			end

			-- Grave / Weapons / Car ESP
			updateGraveESP()
			updateWeaponsESP()
			updateCarESP()
		end))

		-- Ammo ESP update
		_addConn(RunService.RenderStepped:Connect(function()
			if not _ammoESP.Enabled then return end
			local camPos=Camera.CFrame.Position
			for src,data in pairs(_ammoESP.ActiveDrawings) do
				if not src.Parent then
					pcall(function() data.drawing:Remove() end); _ammoESP.ActiveDrawings[src]=nil
				else
					local dist=(src.Position-camPos).Magnitude
					if dist>_ammoESP.RenderDistance then data.drawing.Visible=false
					else
						data.drawing.Outline=_ammoESP.Outline; data.drawing.Size=_ammoESP.Size; data.drawing.Color=_ammoESP.Color
						data.drawing.Text=_ammoESP.ShowDistance and string.format("[A] %s [%dm]",data.label,math.floor(dist)) or "[A] "..data.label
						local sp,onS=Camera:WorldToViewportPoint(src.Position)
						data.drawing.Position=Vector2.new(sp.X,sp.Y); data.drawing.Visible=onS
					end
				end
			end
		end))

		-- Heartbeat: offsets, anti-aim, chams, no-tree, cleanup
		_addConn(RunService.Heartbeat:Connect(function()
			if offsetEnabled then applyOffset() end
			if antiAimEnabled and antiAimAngle=="Among Us" and cae then
				pcall(function() cae:FireServer(0, math.random()*1e200) end)
			end
			if bodyChamsEnabled then applyBodyChams() end
			if noTreeEnabled then
				local now=tick()
				if now-noTreeLastCheck>5 or #noTreeCache==0 then
					noTreeLastCheck=now; noTreeCache={}
					for _,p in ipairs(workspace:GetDescendants()) do
						if p:IsA("BasePart") and (p.Name=="Leaves" or p.Name=="Tree") then table.insert(noTreeCache,p) end
					end
				end
				for _,p in ipairs(noTreeCache) do
					if p.Transparency~=1 then p.Transparency=1 end
					if p.CanCollide then p.CanCollide=false end
					if not p.Anchored then p.Anchored=true end
				end
			end
			updateTracers()
			-- Ammo cleanup
			for src,data in pairs(_ammoESP.ActiveDrawings) do
				if not src.Parent then pcall(function() data.drawing:Remove() end); _ammoESP.ActiveDrawings[src]=nil end
			end
		end))

		-- Manipulation RenderStepped
		_addConn(RunService.RenderStepped:Connect(function()
			if not manipEnabled then return end
			local char=LocalPlayer.Character; if not char then return end
			local hrp=char:FindFirstChild("HumanoidRootPart"); local hum=char:FindFirstChild("Humanoid")
			if not hrp or not hum then return end
			if manipActive and not _manipAnchor then
				manipOrigCF=hrp.CFrame; manipStartPos=hrp.Position; distLabel.Visible=true
				_manipAnchor=Instance.new("Part",workspace); _manipAnchor.Name="MyaManipAnchor"
				_manipAnchor.Anchored=true; _manipAnchor.CanCollide=true; _manipAnchor.Transparency=1
				_manipAnchor.Size=Vector3.new(1,1,1); _manipAnchor.CFrame=hrp.CFrame*CFrame.new(0,-10,0)
				local weld=Instance.new("WeldConstraint",_manipAnchor); weld.Part0=_manipAnchor; weld.Part1=hrp
				hum.PlatformStand=true
			elseif not manipActive and _manipAnchor then
				_manipAnchor:Destroy(); _manipAnchor=nil; hum.PlatformStand=false; distLabel.Visible=false
				if manipOrigCF then hrp.CFrame=manipOrigCF end
			end
			if manipActive and _manipAnchor then
				hrp.Anchored=false; local mv=Vector3.new(); local cam=workspace.CurrentCamera
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv+=cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv-=cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv-=cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv+=cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv+=Vector3.new(0,1,0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv-=Vector3.new(0,1,0) end
				if mv.Magnitude>0 then mv=mv.Unit end
				hrp.CFrame+=mv*manipSpeed; _manipAnchor.CFrame=hrp.CFrame*CFrame.new(0,-10,0)
				local d=(hrp.Position-(manipStartPos or hrp.Position)).Magnitude
				distLabel.Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/4)
				if d>18 then distLabel.Text=string.format("DANGER: %.2f studs",d); distLabel.Color=Color3.new(1,0,0)
				elseif d>16 then distLabel.Text=string.format("Warning: %.2f studs",d); distLabel.Color=Color3.new(1,1,0)
				else distLabel.Text=string.format("Distance: %.2f studs",d); distLabel.Color=Color3.new(1,1,1) end
			end
		end))

		-- Player ESP initialization
		for _,plr in pairs(Players:GetPlayers()) do
			if plr~=LocalPlayer then coroutine.wrap(setupPlayerESP)(plr) end
		end
		_addConn(Players.PlayerAdded:Connect(function(plr) task.delay(1,function() coroutine.wrap(setupPlayerESP)(plr) end) end))
		_addConn(Players.PlayerRemoving:Connect(function(plr) removePlayerESP(plr) end))

		-- Weapons ESP world connections
		local function wireWeaponESP()
			local wa=workspace:FindFirstChild("world_assets"); if not wa then return end
			local so=wa:FindFirstChild("StaticObjects"); if not so then return end
			local misc=so:FindFirstChild("Misc"); if not misc then return end
			_addConn(misc.ChildAdded:Connect(function(m) task.wait(0.1); checkWeaponESP(m) end))
		end
		wireWeaponESP()

		-- Ammo ESP world connections
		local function wireAmmoESP()
			local wa=workspace:FindFirstChild("world_assets"); if not wa then return end
			local so=wa:FindFirstChild("StaticObjects"); if not so then return end
			local misc=so:FindFirstChild("Misc"); if not misc then return end
			_addConn(misc.ChildAdded:Connect(function() task.defer(scanAmmo) end))
		end
		wireAmmoESP()

		-- ── Tabs ─────────────────────────────────────────────────────────
		local VisualsTab  = Window:AddTab({ Title="Visuals",  Icon="solar/eye-bold" })
		local CombatTab   = Window:AddTab({ Title="Combat",   Icon="solar/target-bold" })
		local WorldTab    = Window:AddTab({ Title="World",    Icon="solar/map-bold" })
		local MiscTab     = Window:AddTab({ Title="Misc",     Icon="solar/widget-bold" })
		local ConfigTab   = Window:AddTab({ Title="Config",   Icon="solar/diskette-bold" })
		local SettingsTab = Window:AddTab({ Title="Settings", Icon="solar/settings-bold" })

		-- ── VISUALS ──────────────────────────────────────────────────────
		local espSec = VisualsTab:AddSection("Player ESP")
		espSec:AddToggle("ESPEnabled",{Title="Enable Player ESP",Icon="solar/eye-bold",Default=false,Callback=function(v)
			espEnabled=v; if not v then for _,ed in pairs(_ESPs) do for _,d in pairs(ed.Drawings) do d.Visible=false end end end
		end})
		espSec:AddToggle("ESPBox",       {Title="Boxes",          Default=false, Callback=function(v) boxEnabled=v end})
		espSec:AddToggle("ESPBoxFilled", {Title="Filled Boxes",   Default=false, Callback=function(v) boxFilledEnabled=v end})
		espSec:AddToggle("ESPBoxOutline",{Title="Box Outline",    Default=false, Callback=function(v) boxOutlineEnabled=v end})
		espSec:AddToggle("ESPNames",     {Title="Names",          Default=false, Callback=function(v) nameEnabled=v end})
		espSec:AddToggle("ESPDist",      {Title="Distance",       Default=false, Callback=function(v) distEnabled=v end})
		espSec:AddColorpicker("ESPBoxCol",     {Title="Box Color",         Default=Color3.fromRGB(255,255,255), Callback=function(v) boxColor=v end})
		espSec:AddColorpicker("ESPOutlineCol", {Title="Box Outline Color", Default=Color3.fromRGB(0,0,0),       Callback=function(v) boxOutlineColor=v end})
		espSec:AddColorpicker("ESPNameCol",    {Title="Name Color",        Default=Color3.fromRGB(255,255,255), Callback=function(v) nameColor=v end})
		espSec:AddColorpicker("ESPDistCol",    {Title="Distance Color",    Default=Color3.fromRGB(255,255,255), Callback=function(v) distColor=v end})
		espSec:AddSlider("ESPMaxDist",{Title="Max Distance",Default=1000,Min=100,Max=5000,Rounding=0,Callback=function(v) maxESPDist=v end})

		local graveSec = VisualsTab:AddSection("Grave ESP")
		graveSec:AddToggle("GraveESP",{Title="Enable Grave ESP",Icon="solar/map-point-bold",Default=false,Callback=function(v)
			_graveESP.Enabled=v; if not v then for _,d in pairs(_graveESP.ActiveDrawings) do d.text.Visible=false end end
		end})
		graveSec:AddToggle("GraveESPDist",{Title="Show Distance",Default=true,Callback=function(v) _graveESP.ShowDistance=v end})
		graveSec:AddToggle("GraveESPOutline",{Title="Outline",Default=true,Callback=function(v)
			_graveESP.Outline=v; for _,d in pairs(_graveESP.ActiveDrawings) do d.text.Outline=v end
		end})
		graveSec:AddSlider("GraveESPSize",{Title="Text Size",Default=16,Min=10,Max=24,Rounding=0,Callback=function(v)
			_graveESP.Size=v; for _,d in pairs(_graveESP.ActiveDrawings) do d.text.Size=v end
		end})
		graveSec:AddColorpicker("GraveESPCol",{Title="Grave Color",Default=Color3.fromRGB(128,0,128),Callback=function(v)
			_graveESP.Color=v; for _,d in pairs(_graveESP.ActiveDrawings) do d.text.Color=v end
		end})

		local ammoSec = VisualsTab:AddSection("Ammo ESP")
		ammoSec:AddToggle("AmmoESP",{Title="Enable Ammo ESP",Icon="solar/box-bold",Default=false,Callback=function(v)
			_ammoESP.Enabled=v
			if not v then for _,d in pairs(_ammoESP.ActiveDrawings) do d.drawing.Visible=false end else scanAmmo() end
		end})
		ammoSec:AddToggle("AmmoESPDist",{Title="Show Distance",Default=true,Callback=function(v) _ammoESP.ShowDistance=v end})
		ammoSec:AddSlider("AmmoESPSize",{Title="Text Size",Default=14,Min=10,Max=24,Rounding=0,Callback=function(v)
			_ammoESP.Size=v; for _,d in pairs(_ammoESP.ActiveDrawings) do d.drawing.Size=v end
		end})
		ammoSec:AddSlider("AmmoESPRender",{Title="Render Distance",Default=1000,Min=100,Max=5000,Rounding=0,Callback=function(v) _ammoESP.RenderDistance=v end})
		ammoSec:AddColorpicker("AmmoESPCol",{Title="Ammo Color",Default=Color3.fromRGB(255,69,0),Callback=function(v)
			_ammoESP.Color=v; for _,d in pairs(_ammoESP.ActiveDrawings) do d.drawing.Color=v end
		end})

		local weapSec = VisualsTab:AddSection("Weapons ESP")
		weapSec:AddToggle("WeapESP",{Title="Enable Weapons ESP",Icon="solar/gun-bold",Default=false,Callback=function(v)
			_weaponsESP.Enabled=v
			if not v then for _,d in pairs(_weaponsESP.ActiveDrawings) do d.drawing.Visible=false end else scanWeapons() end
		end})
		weapSec:AddToggle("WeapESPDist",{Title="Show Distance",Default=true,Callback=function(v) _weaponsESP.ShowDistance=v end})
		weapSec:AddToggle("WeapESPMelee",{Title="Exclude Melee",Default=false,Callback=function(v)
			_weaponsESP.ExcludeMelee=v
			if v then for model,d in pairs(_weaponsESP.ActiveDrawings) do if MELEE[d.name] then d.drawing.Visible=false end end end
		end})
		weapSec:AddSlider("WeapESPSize",{Title="Text Size",Default=16,Min=10,Max=24,Rounding=0,Callback=function(v)
			_weaponsESP.Size=v; for _,d in pairs(_weaponsESP.ActiveDrawings) do d.drawing.Size=v end
		end})
		weapSec:AddSlider("WeapESPRange",{Title="Render Range",Default=500,Min=100,Max=2000,Rounding=0,Callback=function(v) _weaponsESP.RenderRange=v end})
		weapSec:AddColorpicker("WeapESPCol",{Title="Weapons Color",Default=Color3.fromRGB(0,191,255),Callback=function(v)
			_weaponsESP.Color=v; for _,d in pairs(_weaponsESP.ActiveDrawings) do d.drawing.Color=v end
		end})

		local carSec = VisualsTab:AddSection("Car ESP")
		carSec:AddToggle("CarESP",{Title="Car ESP",Icon="solar/car-bold",Default=false,Callback=function(v) carEspEnabled=v end})

		local chSec = VisualsTab:AddSection("Crosshair")
		chSec:AddToggle("CHEnabled",  {Title="Enable Crosshair",Icon="solar/crosshair-bold",Default=false, Callback=function(v) ch.Enabled=v end})
		chSec:AddToggle("CHRainbow",  {Title="Rainbow",          Default=false, Callback=function(v) ch.Rainbow=v end})
		chSec:AddToggle("CHCenter",   {Title="Screen Center",    Default=true,  Callback=function(v) ch.ScreenCenter=v end})
		chSec:AddToggle("CHDot",      {Title="Center Dot",       Default=true,  Callback=function(v) ch.Dot=v end})
		chSec:AddToggle("CHOutline",  {Title="Outline",          Default=true,  Callback=function(v) ch.Outline=v end})
		chSec:AddToggle("CHPulse",    {Title="Pulse Effect",     Default=true,  Callback=function(v) ch.Pulse=v end})
		chSec:AddDropdown("CHStyle",  {Title="Style",Values={"Default","Circle","Dot","Swastika"},Default=1,Multi=false,Callback=function(v) ch.Style=v end})
		chSec:AddSlider("CHSize",     {Title="Size",            Default=20,Min=4,  Max=100,Rounding=0,Callback=function(v) ch.Size=v end})
		chSec:AddSlider("CHThick",    {Title="Thickness",       Default=2, Min=1,  Max=10, Rounding=0,Callback=function(v) ch.Thickness=v end})
		chSec:AddSlider("CHGap",      {Title="Gap",             Default=5, Min=0,  Max=50, Rounding=0,Callback=function(v) ch.Gap=v end})
		chSec:AddSlider("CHPulseSpd", {Title="Pulse Speed",     Default=3, Min=1,  Max=10, Rounding=0,Callback=function(v) ch.PulseSpeed=v end})
		chSec:AddSlider("CHRotSpd",   {Title="Rotation Speed",  Default=2, Min=0,  Max=20, Rounding=0,Callback=function(v) ch.RotationSpeed=v end})
		chSec:AddColorpicker("CHColor",{Title="Color",Default=Color3.new(1,1,1),Callback=function(v) ch.Color=v end})

		-- ── COMBAT ───────────────────────────────────────────────────────
		local abSec = CombatTab:AddSection("Aimbot")
		abSec:AddToggle("ABEnabled",  {Title="Enable Aimbot",    Icon="solar/target-bold",   Default=false, Callback=function(v) aimbot.enabled=v end})
		abSec:AddToggle("ABShowFOV",  {Title="Show FOV Circle",  Default=false, Callback=function(v) aimbot.showFOV=v; fovCircle.Visible=v end})
		abSec:AddToggle("ABRainbowFOV",{Title="Rainbow FOV",     Default=false, Callback=function(v) aimbot.fovRainbow=v end})
		abSec:AddDropdown("ABHitPart",{Title="Hit Part",Values={"Head","UpperTorso","HumanoidRootPart"},Default=1,Multi=false,Callback=function(_) end})
		abSec:AddSlider("ABFOVRadius",{Title="FOV Radius",   Default=200,Min=10,Max=500,Rounding=0,Callback=function(v) aimbot.fovRadius=v; fovCircle.Radius=v end})
		abSec:AddSlider("ABFOVThick", {Title="FOV Thickness",Default=2,  Min=1, Max=10, Rounding=0,Callback=function(v) aimbot.fovThickness=v; fovCircle.Thickness=v end})
		abSec:AddSlider("ABSmoothing",{Title="Smoothing",    Default=50, Min=1, Max=100,Rounding=0,Callback=function(v) aimbot.smoothing=v/100 end})
		abSec:AddSlider("ABPredX",    {Title="Prediction X", Default=100,Min=1, Max=200,Rounding=0,Callback=function(v) aimbot.predXAdjust=v/100 end})
		abSec:AddSlider("ABPredY",    {Title="Prediction Y", Default=100,Min=1, Max=200,Rounding=0,Callback=function(v) aimbot.predYAdjust=v/100 end})
		abSec:AddColorpicker("ABFOVCol",{Title="FOV Color",Default=Color3.fromRGB(255,255,255),Callback=function(v) aimbot.fovColor=v; fovCircle.Color=v end})
		abSec:AddKeybind("ABKey",{Title="Aimbot Key",Default="MB2",Mode="Hold",Callback=function() end})

		local gmSec = CombatTab:AddSection("Gunmods")
		gmSec:AddToggle("NoRecoil",{Title="No Recoil",Icon="solar/wind-bold",Default=false,Callback=function(state)
			if state then
				pcall(function()
					local spring=require(LocalPlayer.PlayerScripts.GunController.Data.Spring)
					local oSP,oImp,oNI=spring.SetPosition,spring.Impulse,spring.__newindex
					spring.SetPosition=function() end; spring.Impulse=function() end; spring.__newindex=function() end
					_noRecoilRestore=function() spring.SetPosition=oSP; spring.Impulse=oImp; spring.__newindex=oNI end
				end)
			else if _noRecoilRestore then pcall(_noRecoilRestore) end end
		end})
		gmSec:AddToggle("InstantAim",{Title="Instant Aim",Default=false,Callback=function(state)
			if state then
				pcall(function()
					for _,v in next,getgc(true) do
						if type(v)=="table" then
							for i,val in next,v do
								if type(i)=="string" and i:find("GunAim") then
									if type(val)=="number" then v[i]=100000000
									elseif type(val)=="function" then hookfunction(val,function() return 100000000 end) end
								end
							end
						end
					end
				end)
			end
		end})
		gmSec:AddToggle("SilentReload",{Title="Silent Reload",Default=false,Callback=function(v)
			silentReloadEnabled=v
			if v then handleSilentReload()
			else if _silentThread then task.cancel(_silentThread); _silentThread=nil end end
		end})
		gmSec:AddToggle("GunOffsets",{Title="Gun Offsets",Default=false,Callback=function(v)
			offsetEnabled=v; if not v then _restoreOffsets() end
		end})
		gmSec:AddSlider("OffX",{Title="Offset X",Default=5, Min=-20,Max=20,Rounding=1,Callback=function(v) offsetX=v end})
		gmSec:AddSlider("OffY",{Title="Offset Y",Default=0, Min=-20,Max=20,Rounding=1,Callback=function(v) offsetY=v end})
		gmSec:AddSlider("OffZ",{Title="Offset Z",Default=-5,Min=-20,Max=20,Rounding=1,Callback=function(v) offsetZ=v end})

		local hsSec = CombatTab:AddSection("Hitsounds")
		hsSec:AddToggle("Hitsounds",{Title="Hitsounds",Icon="solar/volume-loud-bold",Default=false,Callback=function(v)
			hitsoundsEnabled=v; if v then startHitsounds() else stopHitsounds() end
		end})
		hsSec:AddDropdown("HitmarkerSnd",{Title="Hitmarker Sound",Values={"Rust","Minecraft","Pop","CS","Neverlose","Gamesense","nn dog"},Default=1,Multi=false,Callback=function(v)
			hitmarkerName=v
			pcall(function() _previewSound.SoundId="rbxassetid://"..tostring(HITSOUNDS[v]); _previewSound:Play() end)
		end})
		hsSec:AddDropdown("HeadshotSnd",{Title="Headshot Sound",Values={"Rust","Minecraft","Pop","CS","Neverlose","Gamesense","nn dog"},Default=4,Multi=false,Callback=function(v)
			headshotName=v
			pcall(function() _previewSound.SoundId="rbxassetid://"..tostring(HITSOUNDS[v]); _previewSound:Play() end)
		end})

		-- ── WORLD ────────────────────────────────────────────────────────
		local lightSec = WorldTab:AddSection("Lighting")
		lightSec:AddToggle("Fullbright",{Title="Fullbright",Icon="solar/sun-bold",Default=false,Callback=function(v)
			fullbright=v
			if not v then lighting.Brightness=_origLighting.Brightness; lighting.ClockTime=_origLighting.ClockTime; lighting.GlobalShadows=_origLighting.GlobalShadows; lighting.OutdoorAmbient=_origLighting.OutdoorAmbient end
		end})
		lightSec:AddToggle("NoFog",{Title="No Fog",Default=false,Callback=function(v)
			noFog=v; if not v and lighting:FindFirstChild("Atmosphere") then lighting.Atmosphere.Density=_origAtmDensity end
		end})
		lightSec:AddToggle("RemoveClouds",{Title="Remove Clouds",Default=false,Callback=function(v)
			removeClouds=v
			local clouds=workspace.Terrain:FindFirstChild("Clouds"); if clouds then clouds.Enabled=not v end
		end})
		lightSec:AddToggle("TimeChanger",{Title="Time Changer",Default=false,Callback=function(v)
			timeEnabled=v; if not v then lighting.ClockTime=_origLighting.ClockTime end
		end})
		lightSec:AddSlider("TimeOfDay",{Title="Time of Day",Default=12,Min=0,Max=24,Rounding=1,Callback=function(v) timeVal=v end})

		local skySec = WorldTab:AddSection("Skybox")
		skySec:AddDropdown("SkyboxDD",{Title="Skybox",Values={"Default","Standard","Blue Sky","Vaporwave","Redshift","Blaze","Dark Night","Bright Pink","Galaxy"},Default=1,Multi=false,Callback=function(v) applySkybox(v) end})
		skySec:AddButton({Title="Reset Skybox",Callback=function() applySkybox("Default") end})
		skySec:AddColorpicker("EnvTint",{Title="Environment Tint",Default=Color3.new(1,1,1),Callback=function(v)
			local cc=lighting:FindFirstChild("ColorCorrection"); if cc then cc.TintColor=v end
		end})

		local envSec = WorldTab:AddSection("Environment")
		envSec:AddToggle("RemoveGrass",{Title="Remove Grass",Icon="solar/leaf-bold",Default=false,Callback=function(v)
			pcall(function() sethiddenproperty(workspace.Terrain,"Decoration",not v) end)
		end})
		envSec:AddToggle("NoTree",{Title="No Trees",Default=false,Callback=function(v)
			noTreeEnabled=v
			if not v then
				for _,p in ipairs(workspace:GetDescendants()) do
					if p:IsA("BasePart") and (p.Name=="Leaves" or p.Name=="Tree") then p.Transparency=0; p.CanCollide=true end
				end
				noTreeCache={}
			end
		end})

		-- ── MISC ─────────────────────────────────────────────────────────
		local aaSec = MiscTab:AddSection("Anti-Aim")
		aaSec:AddToggle("AntiAim",{Title="Anti-Aim",Icon="solar/shield-bold",Default=false,Callback=function(v) antiAimEnabled=v end})
		aaSec:AddDropdown("AAAngle",{Title="Angle",Values={"Up","Down","Default","Random","Among Us"},Default=5,Multi=false,Callback=function(v) antiAimAngle=v end})

		local fovSec = MiscTab:AddSection("FOV Changer")
		fovSec:AddToggle("FOVChanger",{Title="FOV Changer",Icon="solar/camera-bold",Default=false,Callback=function(v)
			fovChangerEnabled=v; if v then applyFOV() else resetFOV() end
		end})
		fovSec:AddSlider("FOVVal",{Title="Field of View",Default=80,Min=30,Max=120,Rounding=0,Callback=function(v)
			targetFov=v; if fovChangerEnabled then applyFOV() end
		end})

		local chamsSec = MiscTab:AddSection("Character Chams")
		chamsSec:AddToggle("BodyChams",{Title="Body Chams",Icon="solar/user-bold",Default=false,Callback=function(v)
			bodyChamsEnabled=v; if v then applyBodyChams() end
		end})
		chamsSec:AddColorpicker("BodyChamsCol",{Title="Body Color",Default=Color3.fromRGB(255,255,255),Callback=function(v)
			bodyChamsColor=v; if bodyChamsEnabled then applyBodyChams() end
		end})
		chamsSec:AddDropdown("BodyChamsMat",{Title="Body Material",Values={"ForceField","Plastic","SmoothPlastic","Neon","Glass","Metal","Wood","Concrete"},Default=1,Multi=false,Callback=function(v)
			pcall(function() chamsMat=Enum.Material[v] end); if bodyChamsEnabled then applyBodyChams() end
		end})
		chamsSec:AddToggle("WeapChams",{Title="Weapon Chams",Default=false,Callback=function(v)
			weapChamsEnabled=v
			if v then local cw=workspace.Camera:FindFirstChild("CurrentWeapon"); if cw then applyWeaponChams(cw) end end
		end})
		chamsSec:AddColorpicker("WeapChamsCol",{Title="Weapon Color",Default=Color3.fromRGB(244,224,155),Callback=function(v)
			weapChamsColor=v
			if weapChamsEnabled then local cw=workspace.Camera:FindFirstChild("CurrentWeapon"); if cw then applyWeaponChams(cw) end end
		end})
		chamsSec:AddDropdown("WeapChamsMat",{Title="Weapon Material",Values={"ForceField","Plastic","SmoothPlastic","Neon","Glass","Metal","Wood","Concrete"},Default=1,Multi=false,Callback=function(v)
			pcall(function() weapChamsMat=Enum.Material[v] end)
		end})

		local manipSec = MiscTab:AddSection("Manipulation")
		manipSec:AddToggle("ManipEnabled",{Title="Enable Manipulation",Icon="solar/wind-bold",Default=false,Callback=function(v) manipEnabled=v end})
		manipSec:AddKeybind("ManipKey",{Title="Manip Key",Default="V",Mode="Toggle",Callback=function() manipActive=not manipActive end})
		manipSec:AddSlider("ManipSpeed",{Title="Speed",Default=50,Min=1,Max=100,Rounding=0,Callback=function(v) manipSpeed=v/100*5 end})

		local ltSec = MiscTab:AddSection("Lightning Tracers")
		ltSec:AddToggle("LTEnabled",{Title="Lightning Tracers",Icon="solar/bolt-bold",Default=false,Callback=function(v)
			ltEnabled=v; if v then startLightning() else stopLightning() end
		end})
		ltSec:AddToggle("LTAutoFire",{Title="Auto Fire",Default=false,Callback=function(v) ltAutoFire=v end})
		ltSec:AddSlider("LTRate",  {Title="Fire Rate (shots/sec)",Default=10,Min=1,Max=20,Rounding=0,Callback=function(v) ltFireRate=v end})
		ltSec:AddSlider("LTThick", {Title="Thickness",            Default=10,Min=5,Max=30,Rounding=0,Callback=function(v) ltThick=v/10 end})
		ltSec:AddSlider("LTDur",   {Title="Duration (×0.1 sec)",  Default=10,Min=5,Max=30,Rounding=0,Callback=function(v) ltDuration=v/10 end})
		ltSec:AddColorpicker("LTColor",{Title="Tracer Color",Default=Color3.fromRGB(0,200,255),Callback=function(v) ltColor=v end})

		local blurSec = MiscTab:AddSection("No Blur")
		blurSec:AddToggle("NoBlur",{Title="No Inventory Blur",Icon="solar/eye-bold",Default=false,Callback=function(v) noBlurEnabled=v end})

		-- ── CONFIG ───────────────────────────────────────────────────────
		local cfgSec = ConfigTab:AddSection("Configs")
		cfgSec:AddParagraph({Title="How to use",Content="Type a name, then Create Config.\nSelect a config and Load it.\nSet as autoload for auto-apply on next run."})
		SaveManager:BuildConfigSection(ConfigTab)

		-- ── SETTINGS ─────────────────────────────────────────────────────
		InterfaceManager:BuildInterfaceSection(SettingsTab)

		-- Lock keybind and persist
		pcall(function()
			Fluent.MinimizeKeybind:SetValue("RightShift")
			InterfaceManager:SaveSettings()
		end)

		pcall(function() SaveManager:LoadAutoloadConfig() end)

		Window:SelectTab(1)

		if ctx and ctx.notify then ctx.notify("Aftermath loaded") end
	end

	-- ════════════════════════════════════════════════════════════════════
	_module.unmount = function()
		-- Stop active systems
		if _silentThread then pcall(function() task.cancel(_silentThread) end); _silentThread=nil end
		for _,t in ipairs(_hitsoundThreads) do pcall(function() task.cancel(t) end) end; table.clear(_hitsoundThreads)
		_cleanTracers()
		_restoreOffsets()
		if _noRecoilRestore then pcall(_noRecoilRestore) end
		if _manipAnchor then pcall(function() _manipAnchor:Destroy() end); _manipAnchor=nil end

		-- Restore lighting
		pcall(function()
			local lit=game:GetService("Lighting")
			lit.Brightness=_origLighting.Brightness or lit.Brightness
			lit.ClockTime=_origLighting.ClockTime or lit.ClockTime
			if _origLighting.GlobalShadows~=nil then lit.GlobalShadows=_origLighting.GlobalShadows end
			if _origLighting.OutdoorAmbient then lit.OutdoorAmbient=_origLighting.OutdoorAmbient end
			if lit:FindFirstChild("Atmosphere") then lit.Atmosphere.Density=_origAtmDensity end
		end)
		pcall(function()
			local clouds=workspace.Terrain:FindFirstChild("Clouds"); if clouds then clouds.Enabled=_origClouds end
		end)

		-- Disconnect all connections
		for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end; table.clear(_conns)

		-- Remove all tracked drawings
		for _,d in ipairs(_drawings) do pcall(function() d:Remove() end) end; table.clear(_drawings)

		-- Remove ESP drawings
		_cleanESPs()
		for _,d in pairs(_graveESP.ActiveDrawings)  do pcall(function() d.text:Remove() end) end; table.clear(_graveESP.ActiveDrawings)
		for _,d in pairs(_ammoESP.ActiveDrawings)   do pcall(function() d.drawing:Remove() end) end; table.clear(_ammoESP.ActiveDrawings)
		for _,d in pairs(_weaponsESP.ActiveDrawings) do pcall(function() d.drawing:Remove() end) end; table.clear(_weaponsESP.ActiveDrawings)

		-- Remove car ESP drawings
		for _,info in ipairs(_carData) do
			pcall(function() if info.txt then info.txt:Remove() end end)
			pcall(function() if info.dist then info.dist:Remove() end end)
		end; table.clear(_carData)

		-- Preview sound
		if _previewSound then pcall(function() _previewSound:Destroy() end); _previewSound=nil end

		-- Destroy Fluent window
		if _window then pcall(function() _window:Destroy() end); _window=nil end
	end
end

return _module
