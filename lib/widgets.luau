--[[
  lib/widgets.luau — Shared draggable overlay widget factory for New_Mya game scripts.

  Public API:
    widgets.newThemeSync(Fluent)         → { getAccent, getText, getMuted, isRGB, update }
    widgets.newOverlayFrame(opts)         → { gui, frame, label, frameStroke, setAccent, destroy }
    widgets.newWatermark(opts)            → { update, unmount }
    widgets.newKeybindDisplay(opts)       → { update, unmount }

  newOverlayFrame opts:
    name, displayOrder, defaultX, defaultY, posFile,
    Fluent, UIS, textSize, minWidth, padL, padR, padT, padB, accentColor, textAlign

  Each overlay saves { x, y, scale } to posFile automatically.
  Bottom-right ◢ grip resizes the widget via UIScale (0.5 – 3.0).
]]

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- ─── Utilities ────────────────────────────────────────────────────────────────

local function hex(c)
    return string.format("#%02x%02x%02x",
        math.clamp(math.floor(c.R * 255), 0, 255),
        math.clamp(math.floor(c.G * 255), 0, 255),
        math.clamp(math.floor(c.B * 255), 0, 255))
end

local function fmtKey(k)
    if not k or k == "None" or k == "" then return nil end
    if k == "MouseLeft"    then return "LMB" end
    if k == "MouseRight"   then return "RMB" end
    if k == "MouseMiddle"  then return "MMB" end
    if k == "MouseButton4" then return "M4"  end
    if k == "MouseButton5" then return "M5"  end
    return k
end

local function shortKey(k)
    if not k or #k == 0 then return "?" end
    if #k <= 2 then return k:upper() end
    local map = {
        RightShift="RS", LeftShift="LS", LeftControl="LC", RightControl="RC",
        LeftAlt="LA", RightAlt="RA", Space="SP", Return="EN",
        BackSpace="BS", Tab="TB", Delete="DL", Insert="IN",
        Home="HM", PageUp="PU", PageDown="PD",
    }
    if map[k] then return map[k] end
    if k:match("^F%d+$") then return k end
    return k:sub(1, 2):upper()
end

-- ─── ThemeSync ────────────────────────────────────────────────────────────────

local R = Color3.fromRGB

local ACCENTS = {
    ["AMOLED"]=R(255,255,255),["RGB"]=R(0,255,180),
    ["Neon Cyber"]=R(57,255,20),["Arctic Frost"]=R(100,180,240),["Cotton Candy"]=R(255,130,190),
    ["Blackhole"]=R(255,140,30),["Cyanic"]=R(57,197,187),["Amber Glow"]=R(255,170,40),
    ["Deep Violet"]=R(97,62,167),["Cyan Frost"]=R(60,165,165),["Ash Gray"]=R(150,150,150),
    ["Hot Pink"]=R(255,120,160),["Sky Blue"]=R(96,205,255),["Honey Gold"]=R(255,200,90),
    ["Lime Green"]=R(60,200,120),["Neon Purple"]=R(180,0,255),["Deep Ocean"]=R(0,150,200),
    ["Dark Forest"]=R(60,180,80),["Sunset Red"]=R(255,100,80),["Midnight Blue"]=R(100,80,200),
    ["Soft Lavender"]=R(180,130,255),["Mint Breeze"]=R(80,220,160),["Coral Flame"]=R(255,90,100),
    ["Dark Indigo"]=R(75,0,130),["Acid Lime"]=R(150,255,50),["Ruby Red"]=R(224,17,95),
    ["Royal Blue"]=R(15,82,186),["Emerald Green"]=R(80,200,120),["Jade Stone"]=R(0,180,140),
    ["Rose Quartz"]=R(200,180,220),["Deep Shadow"]=R(60,65,75),["Dark Purple"]=R(80,45,120),
    ["Void Black"]=R(25,30,45),["Eclipse Dark"]=R(50,45,60),["Twilight Purple"]=R(120,80,150),
    ["Aurora Teal"]=R(80,220,180),["Galaxy Purple"]=R(160,60,220),["Nebula Pink"]=R(200,100,160),
    ["Meteor Blaze"]=R(255,120,40),["Dragon Fire"]=R(220,50,20),["Phoenix Flame"]=R(255,100,50),
    ["Demon Blood"]=R(160,20,20),["Angelic White"]=R(220,220,250),["Shadow Black"]=R(50,50,60),
}

local function newThemeSync(Fluent)
    local cache = { accent=R(245,92,177), text=R(245,245,250), muted=R(200,170,210) }

    local function scanGUI()
        pcall(function()
            if not (Fluent and Fluent.GUI) then return end
            for _, d in ipairs(Fluent.GUI:GetDescendants()) do
                if d:IsA("Frame") then
                    local c = d.BackgroundColor3
                    if c.R + c.G + c.B > 0.05 then cache.accent = c; return end
                end
            end
        end)
    end

    local function update()
        local name; pcall(function() name = Fluent and Fluent.Theme end)
        if name and ACCENTS[name] then cache.accent = ACCENTS[name] else scanGUI() end
        pcall(function()
            if Fluent and Fluent.Colors then
                if Fluent.Colors.Text    then cache.text  = Fluent.Colors.Text    end
                if Fluent.Colors.SubText then cache.muted = Fluent.Colors.SubText end
            end
        end)
    end

    pcall(function()
        local orig = Fluent.SetTheme
        Fluent.SetTheme = function(self, theme)
            local r = orig(self, theme)
            task.defer(update); return r
        end
    end)

    update()
    return {
        getAccent = function() return cache.accent end,
        getText   = function() return cache.text   end,
        getMuted  = function() return cache.muted  end,
        isRGB     = function() local n; pcall(function() n=Fluent and Fluent.Theme end); return n=="RGB" end,
        update    = update,
    }
end

-- ─── Shared draggable overlay frame ──────────────────────────────────────────
-- Saves { x, y, scale } to posFile. Bottom-right ◢ grip resizes via UIScale.

local function newOverlayFrame(opts)
    local posX         = opts.defaultX or 14
    local posY         = opts.defaultY or 14
    local posFile      = opts.posFile
    local UIS          = opts.UIS
    local Fl           = opts.Fluent
    local currentScale = 1.0   -- upvalue shared by savePos + drag closures

    -- Load saved position and scale
    pcall(function()
        if not posFile or typeof(isfile) ~= "function" or not isfile(posFile)
            or typeof(readfile) ~= "function" then return end
        local ok, t = pcall(function() return HttpService:JSONDecode(readfile(posFile)) end)
        if not ok or type(t) ~= "table" then return end
        if type(t.x) == "number" and type(t.y) == "number" then
            posX, posY = math.floor(t.x), math.floor(t.y)
        end
        if type(t.scale) == "number" then
            currentScale = math.clamp(t.scale, 0.5, 3.0)
        end
    end)

    local function savePos()
        pcall(function()
            if not posFile or typeof(writefile) ~= "function" then return end
            if typeof(makefolder) == "function" then
                -- Create every directory level so "Mya/Bloodlines" works even
                -- if the executor doesn't auto-create intermediate directories.
                local dir = posFile:match("^(.+)/[^/]+$")
                if dir and dir ~= "" then
                    local parts = {}
                    for seg in dir:gmatch("[^/]+") do
                        parts[#parts + 1] = seg
                        pcall(makefolder, table.concat(parts, "/"))
                    end
                end
            end
            writefile(posFile, HttpService:JSONEncode({ x = posX, y = posY, scale = currentScale }))
        end)
    end

    local accent      = opts.accentColor or R(245, 92, 177)
    local gui         = nil
    local frame       = nil
    local label       = nil
    local frameStroke = nil
    local resizeGrip  = nil   -- exposed to setAccent
    local gripStroke  = nil   -- exposed to setAccent
    local dragConns   = {}
    local mouseInside = false

    pcall(function()
        local guiParent = (typeof(gethui) == "function" and gethui())
            or LocalPlayer:WaitForChild("PlayerGui")

        gui = Instance.new("ScreenGui")
        gui.Name           = opts.name or "MyaOverlay"
        gui.ResetOnSpawn   = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder   = opts.displayOrder or 200
        gui.Enabled        = false
        pcall(function() gui.IgnoreGuiInset = true end)
        gui.Parent = guiParent

        frame = Instance.new("Frame")
        frame.BackgroundColor3       = accent
        frame.BackgroundTransparency = 0.72
        frame.BorderSizePixel        = 0
        frame.Position               = UDim2.fromOffset(posX, posY)
        frame.Parent                 = gui
        pcall(function() frame.AutomaticSize = Enum.AutomaticSize.XY end)

        do
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent       = frame
        end

        frameStroke = Instance.new("UIStroke")
        frameStroke.Color        = accent
        frameStroke.Transparency = 0.4
        frameStroke.Thickness    = 1.5
        pcall(function() frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
        frameStroke.Parent = frame

        do
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft   = UDim.new(0, opts.padL or 14)
            pad.PaddingRight  = UDim.new(0, opts.padR or 14)
            pad.PaddingTop    = UDim.new(0, opts.padT or 8)
            pad.PaddingBottom = UDim.new(0, opts.padB or 8)
            pad.Parent        = frame
        end

        -- UIScale — lets the resize grip scale everything uniformly
        local uiScale = Instance.new("UIScale")
        uiScale.Scale  = currentScale
        uiScale.Parent = frame

        label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.RichText               = true
        label.Font                   = Enum.Font.GothamSemibold
        label.TextSize               = opts.textSize or 14
        label.TextColor3             = R(245, 245, 250)
        label.TextXAlignment         = opts.textAlign or Enum.TextXAlignment.Left
        label.TextYAlignment         = Enum.TextYAlignment.Top
        label.Size                   = UDim2.new(0, opts.minWidth or 160, 0, 20)
        pcall(function() label.AutomaticSize = Enum.AutomaticSize.XY end)
        label.Parent = frame

        -- ── Resize grip: arc anchored to the BOTTOM-RIGHT corner of the frame ───
        -- AnchorPoint (1,1) + Position (1,0,1,0) keeps it at the exact corner
        -- with no Heartbeat needed. The 44×44 circle inside is centred on the
        -- clip's bottom-right corner; ClipsDescendants shows only the top-left
        -- quadrant → a curved arc at the bottom-right that sweeps right→bottom.
        resizeGrip = Instance.new("TextButton")
        resizeGrip.Name                   = "_arcClip"
        resizeGrip.BackgroundTransparency = 1
        resizeGrip.BorderSizePixel        = 0
        resizeGrip.AutoButtonColor        = false
        resizeGrip.Text                   = ""
        resizeGrip.Selectable             = false   -- prevent UI-nav focus stealing Escape
        resizeGrip.Size                   = UDim2.fromOffset(22, 22)
        resizeGrip.AnchorPoint            = Vector2.new(1, 1)   -- grip's BR at frame's BR
        resizeGrip.Position               = UDim2.new(1, 0, 1, 0)
        resizeGrip.ZIndex                 = 10
        resizeGrip.ClipsDescendants       = true
        resizeGrip.Visible                = false
        resizeGrip.Parent                 = frame   -- child of frame → always correct corner

        local arcCircle = Instance.new("Frame")
        arcCircle.BackgroundTransparency = 1
        arcCircle.BorderSizePixel        = 0
        arcCircle.Size                   = UDim2.fromOffset(44, 44)  -- 2× clip = radius 22
        arcCircle.Position               = UDim2.fromOffset(0, 0)   -- centre at (22,22) = clip BR
        arcCircle.ZIndex                 = 51
        arcCircle.Parent                 = resizeGrip

        do
            local ac = Instance.new("UICorner")
            ac.CornerRadius = UDim.new(1, 0)
            ac.Parent       = arcCircle
        end

        gripStroke = Instance.new("UIStroke")
        gripStroke.Color        = Color3.fromRGB(255, 255, 255)  -- white, visible on any theme
        gripStroke.Transparency = 1.0                            -- invisible by default
        gripStroke.Thickness    = 2.0
        pcall(function() gripStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
        gripStroke.Parent = arcCircle

        -- ── Drag / resize state ───────────────────────────────────────────────
        local dragging     = false
        local resizing     = false
        local dragStart    = Vector2.zero
        local dragPosStart = Vector2.zero
        local rsScaleStart = currentScale

        local function isGuiOpen()
            local ok, v = pcall(function() return Fl and Fl.GUI and Fl.GUI.Enabled end)
            return ok and v == true
        end

        -- [1] Hover: show/hide grip when mouse enters/leaves the frame.
        -- arcClip is inside the frame so MouseLeave only fires on the outer boundary.
        dragConns[1] = frame.MouseEnter:Connect(function()
            mouseInside = true
            resizeGrip.Visible = true
            pcall(function() if gripStroke then gripStroke.Transparency = 0.35 end end)
        end)
        dragConns[2] = frame.MouseLeave:Connect(function()
            mouseInside = false
            if not resizing then
                resizeGrip.Visible = false
                pcall(function() if gripStroke then gripStroke.Transparency = 1.0 end end)
            end
        end)

        -- [3] Resize begins on grip click (arcClip is inside frame; fires before frame.InputBegan)
        dragConns[3] = resizeGrip.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            resizing     = true
            dragStart    = UIS:GetMouseLocation()
            rsScaleStart = currentScale
        end)

        -- [4] Frame drag (skip when resize is active)
        dragConns[4] = frame.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if resizing then return end
            if not isGuiOpen() then return end
            dragging     = true
            dragStart    = UIS:GetMouseLocation()
            dragPosStart = Vector2.new(posX, posY)
        end)

        -- [5] Single move handler for both drag and resize
        dragConns[5] = UIS.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            if not (dragging or resizing) then return end
            local mouse = UIS:GetMouseLocation()
            if resizing then
                local delta = mouse - dragStart
                currentScale  = math.clamp(rsScaleStart + (delta.X + delta.Y) / 250, 0.4, 3.0)
                uiScale.Scale = currentScale
            else
                local delta = mouse - dragStart
                local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                    or Vector2.new(1920, 1080)
                posX = math.clamp(math.floor(dragPosStart.X + delta.X), 0, vp.X - 20)
                posY = math.clamp(math.floor(dragPosStart.Y + delta.Y), 0, vp.Y - 20)
                frame.Position = UDim2.fromOffset(posX, posY)
            end
        end)

        -- [6] End drag or resize
        dragConns[6] = UIS.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if dragging or resizing then
                dragging = false; resizing = false
                savePos()
                if not mouseInside then
                    resizeGrip.Visible = false
                    pcall(function() if gripStroke then gripStroke.Transparency = 1.0 end end)
                end
            end
        end)
    end)

    return {
        gui         = gui,
        frame       = frame,
        label       = label,
        frameStroke = frameStroke,
        setAccent   = function(c)
            pcall(function()
                if frame       then frame.BackgroundColor3 = c end
                if frameStroke then frameStroke.Color      = c end
                -- gripStroke stays white (rgba 255,255,255) so it's visible on any theme
            end)
        end,
        destroy = function()
            for _, c in ipairs(dragConns) do pcall(function() c:Disconnect() end) end
            if gui then pcall(function() gui:Destroy() end) end
        end,
    }
end

-- ─── Watermark widget ─────────────────────────────────────────────────────────

local function newWatermark(opts)
    local Fluent   = opts.Fluent
    local UIS      = opts.UIS
    local ts       = opts.themeSync
    local folder   = opts.folder or "MyaWidgets"
    local tab      = opts.tab

    local enabled   = false
    local showUser  = true
    local showGame  = true
    local showExec  = false
    local showFPS   = true
    local showPing  = true

    local C_ACCENT = R(245, 92, 177)
    local C_TEXT   = R(245, 245, 250)
    local C_MUTED  = R(200, 170, 210)

    local function syncTheme()
        if ts then C_ACCENT=ts.getAccent(); C_TEXT=ts.getText(); C_MUTED=ts.getMuted() end
    end
    syncTheme()

    local fpsDisplay, fpsClock, fpsFrames = 60, os.clock(), 0
    local pingDisplay, pingClock = 0, os.clock() - 2

    local function tickFPS()
        fpsFrames = fpsFrames + 1
        local now = os.clock(); local dt = now - fpsClock
        if dt >= 0.5 then fpsDisplay = math.max(1, math.floor(fpsFrames/dt)); fpsFrames, fpsClock = 0, now end
    end

    local function refreshPing()
        local now = os.clock(); if now - pingClock < 1 then return end; pingClock = now
        local ok0, v0 = pcall(function() return LocalPlayer:GetNetworkPing() end)
        if ok0 and type(v0)=="number" and v0>=0 then pingDisplay=math.floor(v0*1000); return end
        local ok1, v1 = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value end)
        if ok1 and type(v1)=="number" and v1>=0 then pingDisplay=math.floor(v1) end
    end

    local gameName = "…"
    task.spawn(function()
        local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
        local raw = ok and info and info.Name and tostring(info.Name) or (game.Name or "Roblox")
        gameName = #raw > 26 and raw:sub(1,24).."…" or raw
    end)

    local execName = "Unknown"
    pcall(function()
        if typeof(getexecutorname)=="function" then
            local ok,n=pcall(getexecutorname); if ok and typeof(n)=="string" and #n>0 then execName=n; return end
        end
        if typeof(identifyexecutor)=="function" then
            local ok,n=pcall(identifyexecutor); if ok and typeof(n)=="string" and #n>0 then execName=n end
        end
    end)

    local ov = newOverlayFrame({
        name="MyaWatermark", displayOrder=200, defaultX=14, defaultY=14,
        posFile=folder.."/watermark_pos.json", Fluent=Fluent, UIS=UIS,
        textSize=16, minWidth=200, padL=14, padR=14, padT=8, padB=8,
        accentColor=C_ACCENT,
    })

    local section = tab:AddSection(opts.sectionTitle or "Watermark")
    section:AddToggle("wmEn_"..folder,   { Title="Show Watermark", Icon="solar/star-bold", Default=false,
        Callback=function(v) enabled=v; pcall(function() if ov.gui then ov.gui.Enabled=v end end) end })
    section:AddToggle("wmUser_"..folder, { Title="Username",       Default=true,  Callback=function(v) showUser=v end })
    section:AddToggle("wmGame_"..folder, { Title="Game Name",      Default=true,  Callback=function(v) showGame=v end })
    section:AddToggle("wmExec_"..folder, { Title="Injector Name",  Default=false, Callback=function(v) showExec=v end })
    section:AddToggle("wmFPS_"..folder,  { Title="FPS",            Default=true,  Callback=function(v) showFPS=v  end })
    section:AddToggle("wmPing_"..folder, { Title="Ping",           Default=true,  Callback=function(v) showPing=v end })

    local function update()
        if not enabled or not (ov and ov.label) then return end
        pcall(function()
            tickFPS(); refreshPing()
            if ts and ts.isRGB() then ts.update() end; syncTheme()
            local ha=hex(C_ACCENT); local ht=hex(C_TEXT); local hm=hex(C_MUTED)
            local dot=string.format(' <font color="%s"> · </font>', hm)
            local parts = { string.format('<font color="%s"><b>Mya</b></font>', ha) }
            if showUser then
                local n=LocalPlayer.DisplayName; if n=="" then n=LocalPlayer.Name end
                parts[#parts+1]=string.format('<font color="%s">%s</font>', ht, n)
            end
            if showGame  then parts[#parts+1]=string.format('<font color="%s">%s</font>',     hm, gameName)   end
            if showExec  then parts[#parts+1]=string.format('<font color="%s">%s</font>',     hm, execName)   end
            if showFPS   then parts[#parts+1]=string.format('<font color="%s">%d FPS</font>', ht, fpsDisplay) end
            if showPing  then parts[#parts+1]=string.format('<font color="%s">%d ms</font>',  ht, pingDisplay) end
            ov.label.Text = table.concat(parts, dot)
            ov.setAccent(C_ACCENT)
        end)
    end

    return { update=update, unmount=ov.destroy }
end

-- ─── Keybind Display widget ───────────────────────────────────────────────────
-- Header: "Keybinds" in accent color.
-- Each row: [KEY]  Feature Name    (only shown when a key is bound)
-- Active: accent key + white name. Inactive: muted key + muted name.

local function newKeybindDisplay(opts)
    local Fluent       = opts.Fluent
    local UIS          = opts.UIS
    local ts           = opts.themeSync
    local bindRegistry = opts.bindRegistry or {}
    local folder       = opts.folder or "MyaWidgets"
    local tab          = opts.tab

    local enabled  = false
    local C_ACCENT = R(245, 92, 177)
    local C_TEXT   = R(245, 245, 250)
    local C_MUTED  = R(200, 170, 210)

    local function syncTheme()
        if ts then C_ACCENT=ts.getAccent(); C_TEXT=ts.getText(); C_MUTED=ts.getMuted() end
    end
    syncTheme()

    local ov = newOverlayFrame({
        name="MyaKeybindDisplay", displayOrder=199, defaultX=14, defaultY=80,
        posFile=folder.."/keybind_pos.json", Fluent=Fluent, UIS=UIS,
        textSize=13, minWidth=160, padL=12, padR=14, padT=8, padB=8,
        accentColor=C_ACCENT,
    })

    local section = tab:AddSection(opts.sectionTitle or "Keybind Display")
    section:AddToggle("kbEn_"..folder, {
        Title="Show Keybind Display", Icon="solar/keyboard-bold", Default=false,
        Callback=function(v)
            enabled=v; pcall(function() if ov.gui then ov.gui.Enabled=v end end)
        end,
    })

    local function update()
        if not enabled or not (ov and ov.label) then return end
        pcall(function()
            if ts and ts.isRGB() then ts.update() end; syncTheme()
            local ha=hex(C_ACCENT); local ht=hex(C_TEXT); local hm=hex(C_MUTED)

            local lines = {
                string.format('<font color="%s"><b>Keybinds</b></font>', ha),
            }

            for _, entry in ipairs(bindRegistry) do
                local key = fmtKey(entry.getKey and entry.getKey() or nil)
                if not key then continue end   -- skip entries with no bind set
                local active = entry.isActive and entry.isActive() or false
                local abbr   = shortKey(key)
                local kc     = active and ha or hm
                local nc     = active and ht or hm
                lines[#lines+1] = string.format(
                    '<font color="%s"><b>[%s]</b></font>  <font color="%s">%s</font>',
                    kc, abbr, nc, entry.displayName
                )
            end

            if #lines == 1 then   -- only header, no entries
                lines[2] = string.format('<font color="%s">No binds set</font>', hm)
            end

            ov.label.Text = table.concat(lines, "\n")
            ov.setAccent(C_ACCENT)
        end)
    end

    return { update=update, unmount=ov.destroy }
end

-- ─── Public API ───────────────────────────────────────────────────────────────

return {
    newThemeSync      = newThemeSync,
    newOverlayFrame   = newOverlayFrame,
    newWatermark      = newWatermark,
    newKeybindDisplay = newKeybindDisplay,
}
