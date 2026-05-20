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

    -- ── CS detection (confirmed from dump) ───────────────────────────────────────
    -- Settings.CurrentSkill.Value == "Chakra Sense" → player is actively sensing.
    -- char.Torso:FindFirstChild("ChakraSense") → visible particle part when sensing.
    -- Both are reliable; the CurrentSkill check is primary.

    local function isSensing(player)
        local char = player.Character
        if not char then return false end

        -- Primary: Settings.CurrentSkill == "Chakra Sense"
        local settings = char:FindFirstChild("Settings")
        if settings then
            local cs = settings:FindFirstChild("CurrentSkill")
            if cs and typeof(cs.Value) == "string" and cs.Value == "Chakra Sense" then
                return true
            end
        end

        -- Secondary: ChakraSense Part in Torso (present while ability is active)
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if torso and torso:FindFirstChild("ChakraSense") then
            return true
        end

        -- Fallback: ReplicatedStorage.Settings path
        local rsS = ReplicatedStorage:FindFirstChild("Settings")
        local ps  = rsS and rsS:FindFirstChild(player.Name)
        if ps then
            local cs = ps:FindFirstChild("CurrentSkill")
            if cs and typeof(cs.Value) == "string" and cs.Value == "Chakra Sense" then
                return true
            end
        end

        return false
    end

    -- Kept for API compatibility; hasCS = sensing in this game (can't reliably
    -- detect if a player owns the skill without them actively using it).
    local function scanPlayerCS(player)
        local sensing = isSensing(player)
        return sensing, sensing
    end

    local function getNearestPlayer()
        local char = localPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, 0 end
        local nearP, nearDist = nil, math.huge
        local _isWL = _G.MYA_BL_IsWL
        for _, p in ipairs(Players:GetPlayers()) do
            if p == localPlayer then continue end
            if _isWL and _isWL(p, "widgets") then continue end
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then continue end
            local d = (r.Position - hrp.Position).Magnitude
            if d < nearDist then nearDist = d; nearP = p end
        end
        return nearP, nearDist
    end

    -- CS counts with sticky set.
    -- "CS Users" = players who were seen sensing recently (persists for CS_STICKY_TTL seconds).
    -- "Sensing"  = players actively sensing RIGHT NOW.
    -- This prevents the count bouncing to 0 every time someone briefly stops sensing.

    local CS_STICKY_TTL = 30  -- seconds to remember a CS user after last seen sensing
    local _csStickySet  = {}  -- [Player] = lastSeenSensingTick
    local _csCache      = { total = 0, active = 0, lastScan = 0 }

    local function getCSCounts()
        local now  = tick()
        if now - _csCache.lastScan < 0.5 then return _csCache.total, _csCache.active end
        _csCache.lastScan = now

        local _isWL = _G.MYA_BL_IsWL

        -- 1. Update sticky set with current sensing state
        for _, p in ipairs(Players:GetPlayers()) do
            if p == localPlayer then continue end
            if _isWL and _isWL(p, "widgets") then continue end
            if isSensing(p) then
                _csStickySet[p] = now
            end
        end

        -- 2. Expire old entries and count
        local total, active = 0, 0
        for p, lastSeen in pairs(_csStickySet) do
            -- Remove if player left the server
            if not Players:FindFirstChild(p.Name) then
                _csStickySet[p] = nil
                continue
            end
            -- Expire if not seen sensing for CS_STICKY_TTL seconds
            if now - lastSeen > CS_STICKY_TTL then
                _csStickySet[p] = nil
                continue
            end
            total = total + 1
            if isSensing(p) then active = active + 1 end
        end

        _csCache.total  = total
        _csCache.active = active
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
        _csAlertDrawing.Text = "!! CHAKRA SENSE !!"
        _csAlertDrawing.Size = 20; _csAlertDrawing.Color = Color3.fromRGB(255, 55, 55)
        _csAlertDrawing.Outline = true; _csAlertDrawing.OutlineColor = Color3.fromRGB(0, 0, 0)
        _csAlertDrawing.Bold = true; _csAlertDrawing.Center = true
        _csAlertDrawing.ZIndex = 10; _csAlertDrawing.Visible = false
    end

    local csAlertSec = visualsTab:AddSection("Chakra Sense Alert")
    csAlertSec:AddToggle("CSAlertEnable", { Title = "Show Alert When Sensed", Icon = "solar/eye-bold", Default = false, Callback = function(v) _csAlertEnabled = v; if v then initCSAlertDrawing() else if _csAlertDrawing then pcall(function() _csAlertDrawing.Visible = false end) end end end })

    -- Users Overlay
    local usersEnabled    = false
    local usersLastUpdate = 0
    local usersOv         = nil

    -- Hover tooltip: shows CS players with status colors
    -- Orange = has CS (in sticky set, not currently sensing)
    -- Red    = actively sensing right now
    local hoverGui, hoverFrame, hoverLabel
    local guiParent = (typeof(gethui) == "function" and gethui())
        or localPlayer:WaitForChild("PlayerGui")

    pcall(function()
        hoverGui = Instance.new("ScreenGui")
        hoverGui.Name = "MyaUsersHover"; hoverGui.ResetOnSpawn = false
        hoverGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        hoverGui.DisplayOrder   = 200; hoverGui.Enabled = false
        pcall(function() hoverGui.IgnoreGuiInset = true end)
        hoverGui.Parent = guiParent

        hoverFrame = Instance.new("Frame")
        hoverFrame.BackgroundColor3       = Color3.fromRGB(8, 8, 8)
        hoverFrame.BackgroundTransparency = 0.15
        hoverFrame.BorderSizePixel        = 0
        hoverFrame.Position               = UDim2.fromOffset(200, 150)
        pcall(function() hoverFrame.AutomaticSize = Enum.AutomaticSize.XY end)
        hoverFrame.Parent = hoverGui

        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = hoverFrame
        local stroke = Instance.new("UIStroke"); stroke.Thickness = 1.5; stroke.Transparency = 0.3
        pcall(function() stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
        stroke.Parent = hoverFrame
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft   = UDim.new(0, 10); pad.PaddingRight  = UDim.new(0, 10)
        pad.PaddingTop    = UDim.new(0, 7);  pad.PaddingBottom = UDim.new(0, 7)
        pad.Parent = hoverFrame

        hoverLabel = Instance.new("TextLabel")
        hoverLabel.BackgroundTransparency = 1; hoverLabel.RichText = true
        hoverLabel.Font          = Enum.Font.GothamSemibold
        hoverLabel.TextSize      = 13
        hoverLabel.TextColor3    = Color3.fromRGB(245, 245, 250)
        hoverLabel.TextXAlignment = Enum.TextXAlignment.Left
        hoverLabel.Size           = UDim2.new(0, 130, 0, 20)
        pcall(function() hoverLabel.AutomaticSize = Enum.AutomaticSize.XY end)
        hoverLabel.Parent = hoverFrame
    end)

    -- Loads widgets.luau and creates the Users overlay frame
    task.spawn(function()
        if typeof(baseUrl) ~= "string" or #baseUrl == 0 then return end
        local base = baseUrl:sub(-1) == "/" and baseUrl or baseUrl .. "/"
        local widgetsSrc
        for _, url in ipairs({ base.."New_Mya/lib/widgets.luau", base.."lib/widgets.luau" }) do
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
                name = "MyaUsersOverlay", displayOrder = 198,
                defaultX = 14, defaultY = 150, posFile = "Mya/Bloodlines/users_pos.json",
                Fluent = Fluent, UIS = UserInputService, textSize = 13, minWidth = 160,
                padL = 14, padR = 14, padT = 8, padB = 8,
                accentColor = Color3.fromRGB(245, 92, 177),
                textAlign = Enum.TextXAlignment.Center,
            })
            if usersOv and usersOv.label then
                usersOv.label.TextXAlignment = Enum.TextXAlignment.Center
            end
            -- Remove the resize-handle TextButton added by newOverlayFrame.
            task.defer(function()
                if usersOv and usersOv.gui then
                    for _, v in ipairs(usersOv.gui:GetDescendants()) do
                        if v:IsA("TextButton") then pcall(function() v:Destroy() end) end
                    end
                end
            end)
        end)
    end)

    local usersSec = miscTab:AddSection("Users")
    usersSec:AddToggle("UsersOverlayEn", {
        Title = "Show Users Widget", Icon = "solar/users-group-rounded-bold", Default = false,
        Callback = function(v)
            usersEnabled = v
            pcall(function() if usersOv and usersOv.gui then usersOv.gui.Enabled = v end end)
            if not v and hoverGui then hoverGui.Enabled = false end
        end,
    })

    local function h(c)
        return string.format("#%02x%02x%02x",
            math.clamp(math.floor(c.R*255),0,255),
            math.clamp(math.floor(c.G*255),0,255),
            math.clamp(math.floor(c.B*255),0,255))
    end

    local _csWasActive  = false
    local _csLastNotify = 0
    local CS_NOTIFY_CD  = 5

    local function update(data)
        -- CS Alert
        if _csAlertEnabled then
            local _, active = getCSCounts()
            local isActive  = active > 0
            if _csAlertDrawing then
                if isActive then
                    local cam = Workspace.CurrentCamera
                    if cam then
                        _csAlertDrawing.Position = Vector2.new(
                            cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5 - 100)
                    end
                    _csAlertDrawing.Visible = true
                else
                    _csAlertDrawing.Visible = false
                end
            end
            local now = tick()
            if isActive and not _csWasActive and (now - _csLastNotify) >= CS_NOTIFY_CD then
                _csLastNotify = now
                pcall(function()
                    Fluent:Notify({ Title = "Chakra Sense",
                        Content = active .. " player" .. (active == 1 and " is" or "s are") .. " sensing",
                        Duration = 4 })
                end)
            end
            _csWasActive = isActive
        end

        -- Users Widget
        if not usersEnabled or not (usersOv and usersOv.label) then
            if hoverGui then hoverGui.Enabled = false end
            return
        end

        local now = tick()
        if now - usersLastUpdate < 0.3 then
            -- Still update hover even between main ticks
        else
            usersLastUpdate = now
            pcall(function()
                local ts = themeSync
                local ha = ts and h(ts.getAccent()) or "#f55cb1"
                local ht = ts and h(ts.getText())   or "#f5f5fa"
                local hm = ts and h(ts.getMuted())  or "#c8aad4"

                local nearP, nearDist = getNearestPlayer()
                local csTotal, csActive = getCSCounts()

                local lines = { string.format('<font color="%s"><b>Users</b></font>', ha) }
                if nearP then
                    lines[#lines+1] = string.format(
                        '<font color="%s">Nearest  </font><font color="%s">%s</font><font color="%s"> %.0fm</font>',
                        hm, ht, nearP.Name, hm, nearDist)
                else
                    lines[#lines+1] = string.format('<font color="%s">Nearest  —</font>', hm)
                end
                lines[#lines+1] = string.format('<font color="%s">CS Users  </font><font color="%s">%d</font>', hm, ht, csTotal)
                lines[#lines+1] = string.format('<font color="%s">Sensing   </font><font color="%s">%d</font>', hm, ht, csActive)

                usersOv.label.Text = table.concat(lines, "\n")
                usersOv.setAccent(ts and ts.getAccent() or Color3.fromRGB(245, 92, 177))
            end)
        end

        -- ── Hover tooltip ─────────────────────────────────────────────────────────
        -- Hide when there are no CS users at all (nothing to show).
        if not (hoverGui and hoverFrame and hoverLabel and usersOv.label) then return end

        local hasCSUsers = next(_csStickySet) ~= nil
        if not hasCSUsers then
            hoverGui.Enabled = false
            return
        end

        pcall(function()
            local mouse = UserInputService:GetMouseLocation()
            local lbl   = usersOv.label

            -- Use label AbsolutePosition as the reliable anchor.
            -- The widget frame surrounds the label with padL=14, padR=14, padT=8, padB=8.
            local labAbs = lbl.AbsolutePosition
            local labSz  = lbl.AbsoluteSize

            -- Hover area = full widget frame bounds (label + padding on all sides).
            local hitL = labAbs.X - 14
            local hitT = labAbs.Y - 8
            local hitR = labAbs.X + labSz.X + 14
            local hitB = labAbs.Y + labSz.Y + 8

            local isOver = mouse.X >= hitL and mouse.X <= hitR
                and mouse.Y >= hitT and mouse.Y <= hitB

            if not isOver then
                hoverGui.Enabled = false
                return
            end

            -- Build hover content.
            local ts  = themeSync
            local ha  = ts and h(ts.getAccent()) or "#f55cb1"
            local hLines = { string.format('<font color="%s"><b>CS Players</b></font>', ha) }

            local entries = {}
            for p in pairs(_csStickySet) do
                if Players:FindFirstChild(p.Name) then entries[#entries + 1] = p end
            end
            table.sort(entries, function(a, b) return a.Name < b.Name end)

            for _, p in ipairs(entries) do
                local color = isSensing(p) and "#ff4040" or "#ff9900"
                hLines[#hLines + 1] = string.format('<font color="%s">%s</font>', color, p.Name)
            end

            hoverLabel.Text = table.concat(hLines, "\n")

            -- Position BELOW the widget: just under the bottom edge of the widget frame.
            -- hitB = bottom edge; add a small gap.
            local hx = math.floor(hitL)
            local hy = math.floor(hitB + 6)

            -- Clamp to viewport.
            local cam = Workspace.CurrentCamera
            if cam then
                local vp  = cam.ViewportSize
                local hSz = hoverFrame.AbsoluteSize
                if hx + hSz.X > vp.X - 10 then hx = math.floor(vp.X - hSz.X - 10) end
                if hy + hSz.Y > vp.Y - 10 then hy = math.floor(hitT - hSz.Y - 6) end
            end
            hoverFrame.Position = UDim2.fromOffset(hx, hy)

            local strokeInst = hoverFrame:FindFirstChildWhichIsA("UIStroke")
            if strokeInst and ts then strokeInst.Color = ts.getAccent() end

            hoverGui.Enabled = true
        end)
    end

    local function unmount()
        for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
        if _csAlertDrawing then pcall(function() _csAlertDrawing:Remove() end) end
        if usersOv and usersOv.gui then pcall(function() usersOv.gui:Destroy() end) end
        if hoverGui then pcall(function() hoverGui:Destroy() end) end
    end

    return { update = update, unmount = unmount }
end
