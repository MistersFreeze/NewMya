return function(ctx)
    local miscTab = ctx.miscTab
    local visualsTab = ctx.visualsTab
    local localPlayer = ctx.localPlayer
    local Players = ctx.Players
    local Workspace = ctx.Workspace
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Fluent = ctx.Fluent
    local UserInputService = ctx.UserInputService
    local themeSync = ctx.themeSync
    local baseUrl = ctx.baseUrl

    local _conns = {}

    local function normName(s) return s:lower():gsub("[%s_%-]", "") end

    -- Returns true when value is "truthy" for both BoolValue and NumberValue/IntValue.
    local function isValActive(v)
        if v:IsA("BoolValue") then return v.Value == true end
        if v:IsA("NumberValue") or v:IsA("IntValue") then return v.Value ~= 0 end
        return false
    end

    -- Patterns stripped of separators (normName applied).
    local CS_PATS    = { "chakrasense","cs","chakrasensing","sensechakra","csability","hascs","cskill" }
    local SENSE_PATS = { "sensing","usingsense","senseon","chakrasensing","sensechakra","cssensing",
                         "activesense","senseactive","issensing","sensechakra","csSensing" }

    local function scanValues(container, csP, senseP)
        local hasCS, sensing = false, false
        if not container then return hasCS, sensing end
        for _, v in ipairs(container:GetDescendants()) do
            local isBool = v:IsA("BoolValue")
            local isNum  = v:IsA("NumberValue") or v:IsA("IntValue")
            if not (isBool or isNum) then continue end
            local n = normName(v.Name)
            for _, pat in ipairs(csP) do
                if n == pat then
                    hasCS = true
                    if isValActive(v) then sensing = true end
                    break
                end
            end
            for _, pat in ipairs(senseP) do
                if n == pat and isValActive(v) then hasCS = true; sensing = true; break end
            end
        end
        return hasCS, sensing
    end

    local function scanPlayerCS(player)
        local char = player.Character
        local hasCS, sensing = false, false

        if char then
            -- Scan character's Settings folder and the character itself.
            local h1, s1 = scanValues(char:FindFirstChild("Settings"), CS_PATS, SENSE_PATS)
            local h2, s2 = scanValues(char, CS_PATS, SENSE_PATS)
            hasCS   = h1 or h2
            sensing = s1 or s2

            -- Character attributes (some Bloodlines builds use SetAttribute).
            pcall(function()
                for k, v in pairs(char:GetAttributes()) do
                    local n = normName(k)
                    for _, pat in ipairs(CS_PATS) do
                        if n == pat then hasCS = true; if v == true or v == 1 then sensing = true end; break end
                    end
                    for _, pat in ipairs(SENSE_PATS) do
                        if n == pat and (v == true or v == 1) then hasCS = true; sensing = true; break end
                    end
                end
            end)
        end

        -- ReplicatedStorage.Settings.<playerName>
        local rsS = ReplicatedStorage:FindFirstChild("Settings")
        local ps  = rsS and rsS:FindFirstChild(player.Name)
        if ps then
            local h3, s3 = scanValues(ps, CS_PATS, SENSE_PATS)
            hasCS   = hasCS   or h3
            sensing = sensing or s3
        end

        return hasCS, sensing
    end

    local function getNearestPlayer()
        local char = localPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, 0 end
        local nearP, nearDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == localPlayer then continue end
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then continue end
            local d = (r.Position - hrp.Position).Magnitude
            if d < nearDist then nearDist = d; nearP = p end
        end
        return nearP, nearDist
    end

    local function scrapeCSText(t, total, active)
        local stripped = t:gsub("<[^>]+>", "")
        if stripped:find("people with chakra") then
            local n = stripped:match("people.-(%d+)") or stripped:match("(%d+)")
            if n then local v = tonumber(n) or 0; if v > total then total = v end end
        end
        if stripped:find("active chakra") or stripped:find("using chakra") then
            local n = stripped:match("chakra.-(%d+)") or stripped:match("(%d+)")
            if n then local v = tonumber(n) or 0; if v > active then active = v end end
        end
        return total, active
    end

    local _wsLabels = {}
    task.spawn(function()
        task.wait(3)
        local objs = Workspace:GetDescendants()
        local CHUNK = 150
        for i = 1, #objs, CHUNK do
            for j = i, math.min(i + CHUNK - 1, #objs) do
                local obj = objs[j]
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then _wsLabels[obj] = true end
            end
            task.wait()
        end
        table.insert(_conns, Workspace.DescendantAdded:Connect(function(obj)
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then _wsLabels[obj] = true end
        end))
    end)

    local _csCache = { total = 0, active = 0, lastScan = 0 }
    local function getCSCounts()
        local now = tick()
        if now - _csCache.lastScan < 2 then return _csCache.total, _csCache.active end
        _csCache.lastScan = now
        local total, active = 0, 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p == localPlayer then continue end
            local has, using = scanPlayerCS(p)
            if using then has = true end
            if has   then total  = total  + 1 end
            if using then active = active + 1 end
        end
        pcall(function()
            for _, gui in ipairs(localPlayer.PlayerGui:GetChildren()) do
                local gn = gui.Name:lower()
                if gn:find("mya") or gn:find("fluent") then continue end
                for _, lbl in ipairs(gui:GetDescendants()) do
                    if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
                        total, active = scrapeCSText(lbl.Text:lower(), total, active)
                    end
                end
            end
        end)
        for lbl in pairs(_wsLabels) do
            if not lbl.Parent or not lbl:IsDescendantOf(Workspace) then _wsLabels[lbl] = nil; continue end
            total, active = scrapeCSText(lbl.Text:lower(), total, active)
        end
        _csCache.total = total; _csCache.active = active
        return total, active
    end

    -- Mod Detection
    local MOD_USERNAMES = { "maxy1221648", "ArkhamDeluxe", "Pr1maryPath", "Spearess", "Etheriox", "Blahiren", "Ako_Shiba" }
    local function detectModAndNotify(player)
        if player == localPlayer then return end
        for _, name in ipairs(MOD_USERNAMES) do
            if player.Name:lower() == name:lower() then
                pcall(function() Fluent:Notify({ Title = "Staff Joined", Content = player.Name .. " (Dev / Staff) is in this server.", Duration = 8 }) end)
                return
            end
        end
        local notified = false
        local function scanSettings(char)
            if notified or not char then return end
            local s = char:FindFirstChild("Settings") or (ReplicatedStorage:FindFirstChild("Settings") and ReplicatedStorage.Settings:FindFirstChild(player.Name))
            if not s then return end
            for _, v in ipairs(s:GetChildren()) do
                local n = v.Name:lower()
                if n == "moderator" or n == "ismod" or n == "rank" or n == "staff" then
                    local val = v.Value
                    if val and val ~= false and val ~= "" and val ~= 0 then
                        notified = true
                        pcall(function() Fluent:Notify({ Title = "Moderator Detected", Content = player.Name .. " — rank: " .. tostring(val), Duration = 8 }) end)
                        return
                    end
                end
            end
        end
        if player.Character then task.spawn(scanSettings, player.Character) end
        local respConn; respConn = player.CharacterAdded:Connect(function(char)
            task.wait(1); task.spawn(scanSettings, char); if notified then respConn:Disconnect() end
        end)
        table.insert(_conns, respConn)
    end
    for _, p in ipairs(Players:GetPlayers()) do detectModAndNotify(p) end
    table.insert(_conns, Players.PlayerAdded:Connect(detectModAndNotify))

    -- UI Section
    local _csAlertDrawing = nil
    local _csAlertEnabled = false
    local function initCSAlertDrawing()
        if _csAlertDrawing then pcall(function() _csAlertDrawing:Remove() end) end
        _csAlertDrawing = Drawing.new("Text")
        _csAlertDrawing.Text = "⚠  CHAKRA SENSE  ⚠"
        _csAlertDrawing.Size = 20; _csAlertDrawing.Color = Color3.fromRGB(255, 55, 55)
        _csAlertDrawing.Outline = true; _csAlertDrawing.OutlineColor = Color3.fromRGB(0, 0, 0)
        _csAlertDrawing.Bold = true; _csAlertDrawing.Center = true
        _csAlertDrawing.ZIndex = 10; _csAlertDrawing.Visible = false
    end

    local csAlertSec = visualsTab:AddSection("Chakra Sense Alert")
    csAlertSec:AddToggle("CSAlertEnable", { Title = "Show Alert When Sensed", Icon = "solar/eye-bold", Default = false, Callback = function(v) _csAlertEnabled = v; if v then initCSAlertDrawing() else if _csAlertDrawing then pcall(function() _csAlertDrawing.Visible = false end) end end end })

    -- Users Overlay
    local usersEnabled = false
    local usersLastUpdate = 0
    local usersOv = nil

    task.spawn(function()
        if typeof(baseUrl) ~= "string" or #baseUrl == 0 then return end
        local base = baseUrl:sub(-1) == "/" and baseUrl or baseUrl .. "/"
        local variants = {
            base .. "New_Mya/lib/widgets.luau",
            base .. "lib/widgets.luau",
        }
        local widgetsSrc
        for _, url in ipairs(variants) do
            local ok, body = pcall(function() return game:HttpGet(url, true) end)
            if ok and typeof(body) == "string" and #body > 100 then
                local s = body:sub(1, 200):lower()
                if not s:find("<!doctype", 1, true) and not s:find("<html", 1, true) then
                    widgetsSrc = body; break
                end
            end
        end
        if not widgetsSrc then return end
        local fn = loadstring(widgetsSrc, "@widgets")
        if not fn then return end
        local ok, widgets = pcall(fn)
        if not ok or typeof(widgets) ~= "table" or not widgets.newOverlayFrame then return end
        pcall(function()
            usersOv = widgets.newOverlayFrame({
                name = "MyaUsersOverlay", displayOrder = 198, defaultX = 14, defaultY = 150, posFile = "Mya/Bloodlines/users_pos.json",
                Fluent = Fluent, UIS = UserInputService, textSize = 13, minWidth = 160,
                padL = 14, padR = 14, padT = 8, padB = 8, accentColor = Color3.fromRGB(245, 92, 177), textAlign = Enum.TextXAlignment.Center,
            })
            if usersOv and usersOv.label then usersOv.label.TextXAlignment = Enum.TextXAlignment.Center end
        end)
    end)

    local usersSec = miscTab:AddSection("Users")
    usersSec:AddToggle("UsersOverlayEn", { Title = "Show Users Widget", Icon = "solar/users-group-rounded-bold", Default = false, Callback = function(v) usersEnabled = v; pcall(function() if usersOv and usersOv.gui then usersOv.gui.Enabled = v end end) end })

    local function h(c) return string.format("#%02x%02x%02x", math.clamp(math.floor(c.R*255),0,255), math.clamp(math.floor(c.G*255),0,255), math.clamp(math.floor(c.B*255),0,255)) end

    local function update(data)
        -- Alert Drawing
        if _csAlertEnabled and _csAlertDrawing then
            local _, active = getCSCounts()
            if active > 0 then
                _csAlertDrawing.Position = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2 - 100)
                _csAlertDrawing.Visible = true
            else
                _csAlertDrawing.Visible = false
            end
        end

        -- Users Widget
        if not usersEnabled or not (usersOv and usersOv.label) then return end
        local now = tick()
        if now - usersLastUpdate < 0.3 then return end
        usersLastUpdate = now
        pcall(function()
            local ts = themeSync
            local ha = ts and h(ts.getAccent()) or "#f55cb1"
            local ht = ts and h(ts.getText())   or "#f5f5fa"
            local hm = ts and h(ts.getMuted())  or "#c8aad4"

            local nearP, nearDist = getNearestPlayer()
            local csTotal, csActive = getCSCounts()

            local lines = { string.format('<font color="%s"><b>Users</b></font>', ha) }
            if nearP then lines[#lines+1] = string.format('<font color="%s">Nearest  </font><font color="%s">%s</font><font color="%s"> %.0fm</font>', hm, ht, nearP.Name, hm, nearDist)
            else lines[#lines+1] = string.format('<font color="%s">Nearest  —</font>', hm) end
            lines[#lines+1] = string.format('<font color="%s">CS Users  </font><font color="%s">%d</font>', hm, ht, csTotal)
            lines[#lines+1] = string.format('<font color="%s">Sensing   </font><font color="%s">%d</font>', hm, ht, csActive)

            usersOv.label.Text = table.concat(lines, "\n")
            usersOv.setAccent(ts and ts.getAccent() or Color3.fromRGB(245, 92, 177))
        end)
    end

    local function unmount()
        for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
        if _csAlertDrawing then pcall(function() _csAlertDrawing:Remove() end) end
        if usersOv and usersOv.gui then pcall(function() usersOv.gui:Destroy() end) end
    end

    return { update = update, unmount = unmount }
end
