return function(ctx)
    local miscTab = ctx.miscTab
    local localPlayer = ctx.localPlayer
    local RunService = ctx.RunService

    local streamer = { enabled = false }
    local _streamerOrig = { conns = {} }

    local function applyStreamer(char)
        char = char or localPlayer.Character
        if not char then return end
        
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            if not _streamerOrig.dispName then _streamerOrig.dispName = hum.DisplayName end
            pcall(function() hum.DisplayName = "Mya Script" end)
        end
        
        local namesToHide = {}
        local function addName(n)
            if type(n) == "string" and #n > 1 and n ~= "Mya Script" then
                namesToHide[n] = true
            end
        end
        
        addName(localPlayer.Name)
        addName(localPlayer.DisplayName)
        addName(char.Name)
        if _streamerOrig.dispName then addName(_streamerOrig.dispName) end
        
        local function escapeRegex(s)
            return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
        end
        
        local function replaceNames(text)
            if type(text) ~= "string" or text == "" then return text, false end
            local replaced = false
            local newText = text
            for n in pairs(namesToHide) do
                if newText:find(n, 1, true) then
                    newText = newText:gsub(escapeRegex(n), "Mya Script")
                    replaced = true
                end
            end
            -- Strip the game's " | <UserId/number>" suffix that appears next to the display name.
            if replaced then
                newText = newText:gsub("%s*|%s*%d+", "")
                newText = newText:gsub("%s*|%s*$", "")
            end
            return newText, replaced
        end
        
        local function attachHook(v)
            if not (v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox")) then return end
            local function checkAndReplace()
                local newText, matched = replaceNames(v.Text)
                if matched then
                    if not _streamerOrig[v] then _streamerOrig[v] = v.Text end
                    pcall(function() v.Text = newText end)
                end
            end
            checkAndReplace()
            pcall(function()
                local conn = v:GetPropertyChangedSignal("Text"):Connect(checkAndReplace)
                table.insert(_streamerOrig.conns, conn)
            end)
        end
        
        local function scanAndReplace(parent)
            if not parent then return end
            for _, v in ipairs(parent:GetDescendants()) do attachHook(v) end
            local conn = parent.DescendantAdded:Connect(function(obj)
                task.delay(0.1, function() if obj.Parent then attachHook(obj) end end)
            end)
            table.insert(_streamerOrig.conns, conn)
        end

        scanAndReplace(char)
        scanAndReplace(localPlayer.PlayerGui)
    end

    local function restoreStreamer(char)
        char = char or localPlayer.Character
        if not char then return end
        for _, conn in ipairs(_streamerOrig.conns or {}) do pcall(function() conn:Disconnect() end) end
        
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum and _streamerOrig.dispName then
            pcall(function() hum.DisplayName = _streamerOrig.dispName end)
        end
        for v, orig in pairs(_streamerOrig) do
            if typeof(v) == "Instance" then pcall(function() v.Text = orig end) end
        end
        _streamerOrig = { conns = {} }
    end

    local streamerSec = miscTab:AddSection("Streamer Mode")
    streamerSec:AddToggle("StreamerModeToggle", {
        Title    = "Streamer Mode",
        Icon     = "solar/shield-user-bold",
        Default  = false,
        Callback = function(v)
            streamer.enabled = v
            if v then applyStreamer() else restoreStreamer() end
        end,
    })

    local charConn = localPlayer.CharacterAdded:Connect(function(char)
        task.delay(1, function()
            if streamer.enabled then applyStreamer(char) end
        end)
    end)

    local function update(data) end
    local function unmount()
        restoreStreamer()
        charConn:Disconnect()
    end

    return { update = update, unmount = unmount }
end
