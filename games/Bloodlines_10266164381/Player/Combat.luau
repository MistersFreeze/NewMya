return function(ctx)
    local playerTab = ctx.playerTab
    local localPlayer = ctx.localPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local noFallDmg  = { enabled = false }
    local noM1CD     = { enabled = false }
    local noStun     = { enabled = false }
    local infStamina = { enabled = false }
    local infChakra  = { enabled = false }
    local autoSprint = { enabled = false }

    local _noFallConns  = {}
    local _stunConns    = {}
    local _staminaCache = {}
    local _chakraCache  = {}
    local _sprintConns  = {}
    local _sprintVals   = {}
    local _sprintClock  = 0

    -- No Fall Damage
    local function applyNoFallDmg(char)
        for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
        table.clear(_noFallConns)
        char = char or localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hum then return end
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
        local inFall, savedHealth = false, hum.Health
        local sc = hum.StateChanged:Connect(function(old, new)
            if new == Enum.HumanoidStateType.Freefall then
                inFall = true; savedHealth = hum.Health
            elseif inFall and (new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.RunningNoPhysics or new == Enum.HumanoidStateType.GettingUp) then
                local h = savedHealth
                inFall = false
                task.delay(0.08, function()
                    if noFallDmg.enabled and hum and hum.Parent then
                        pcall(function() hum.Health = math.max(hum.Health, h) end)
                    end
                end)
            end
        end)
        table.insert(_noFallConns, sc)
    end

    local function restoreNoFallDmg(char)
        for _, c in ipairs(_noFallConns) do pcall(function() c:Disconnect() end) end
        table.clear(_noFallConns)
        char = char or localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end) end
    end

    -- M1 Cooldown
    local function applyNoM1CD()
        if typeof(getgc) ~= "function" then return end
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) ~= "table" then continue end
                for k, val in pairs(v) do
                    local ks = tostring(k):lower()
                    if (ks == "m1" or ks == "m1cd" or ks == "m1cooldown" or ks == "basiccooldown" or ks == "attackcooldown" or ks == "punchcooldown") and type(val) == "number" then
                        rawset(v, k, 0)
                    end
                end
            end
        end)
    end

    -- No Stun
    local function setupNoStun(char)
        for _, c in ipairs(_stunConns) do pcall(function() c:Disconnect() end) end
        _stunConns = {}
        if not char then return end
        local function watchSettings(s)
            if not s then return end
            local st = s:FindFirstChild("Stunned")
            if st and st:IsA("BoolValue") then
                local c = st.Changed:Connect(function(v)
                    if v and noStun.enabled then pcall(function() st.Value = false end) end
                end)
                table.insert(_stunConns, c)
            end
        end
        watchSettings(char:FindFirstChild("Settings"))
        local rsS = ReplicatedStorage:FindFirstChild("Settings")
        if rsS then watchSettings(rsS:FindFirstChild(char.Name)) end
    end

    -- Inf Stamina/Chakra — scans Settings + Backpack (chakra/stamina live in Backpack per game source)
    local function findMax(container, name)
        local tries = { "Max"..name, "max"..name, name.."Max", name.."max" }
        for _, t in ipairs(tries) do
            local v = container:FindFirstChild(t)
            if v and (v:IsA("NumberValue") or v:IsA("IntValue")) and v.Value > 0 then return v end
        end
        return nil
    end

    local function buildStatCache(char, keywords, cache)
        table.clear(cache)
        if not char then return end
        local function scanContainer(s)
            if not s then return end
            for _, v in ipairs(s:GetDescendants()) do
                if not (v:IsA("NumberValue") or v:IsA("IntValue")) then continue end
                local n = v.Name:lower()
                if n:sub(1, 3) == "max" then continue end  -- skip max values themselves
                for _, kw in ipairs(keywords) do
                    if n == kw or n:find(kw, 1, true) then
                        local maxV = findMax(s, v.Name)
                        local cap = (maxV and maxV.Value > 0) and maxV.Value or 100
                        cache[#cache + 1] = { val = v, cap = cap }
                        break
                    end
                end
            end
        end
        scanContainer(char:FindFirstChild("Settings"))
        scanContainer(localPlayer.Backpack)
        local rsS = ReplicatedStorage:FindFirstChild("Settings")
        if rsS then scanContainer(rsS:FindFirstChild(char.Name)) end
    end

    local function applyStatCache(cache)
        for _, e in ipairs(cache) do
            pcall(function()
                if e.val and e.val.Parent and e.val.Value < e.cap then
                    e.val.Value = e.cap
                end
            end)
        end
    end

    -- Auto Sprint — primary path: Backpack.running (confirmed from game source dump).
    -- Fallback: broader Settings/attribute/getgc sweep.

    local SPRINT_NAMES = { "sprinting","sprint","issprinting","issprint","sprintstate","sprintactive","running","isrunning" }
    local function normSprint(s) return s:lower():gsub("[%s_%-]","") end

    local function setSprintEntry(entry, active)
        pcall(function()
            if entry.isAttr then
                if entry.numType then entry.char:SetAttribute(entry.key, active and 1 or 0)
                else                  entry.char:SetAttribute(entry.key, active) end
            else
                local v = entry.val; if not v.Parent then return end
                if entry.isBool then v.Value = active else v.Value = active and 1 or 0 end
            end
        end)
    end

    local function cacheSprintVals(char)
        table.clear(_sprintVals)
        if not char then return end
        local function scan(s)
            if not s then return end
            for _, v in ipairs(s:GetDescendants()) do
                local isBool = v:IsA("BoolValue"); local isNum = v:IsA("NumberValue") or v:IsA("IntValue")
                if not (isBool or isNum) then continue end
                local n = normSprint(v.Name)
                if n == "running" then continue end  -- handled via Backpack directly
                for _, pat in ipairs(SPRINT_NAMES) do
                    if n == pat then _sprintVals[#_sprintVals + 1] = { val=v, isBool=isBool }; break end
                end
            end
        end
        scan(char:FindFirstChild("Settings"))
        local rsS = ReplicatedStorage:FindFirstChild("Settings")
        if rsS then scan(rsS:FindFirstChild(char.Name)) end
        pcall(function()
            for k, v in pairs(char:GetAttributes()) do
                local n = normSprint(k)
                for _, pat in ipairs(SPRINT_NAMES) do
                    if n == pat then _sprintVals[#_sprintVals + 1] = { isAttr=true, char=char, key=k, numType=type(v)=="number" }; break end
                end
            end
        end)
    end

    local function gcSprintSweep(active)
        if typeof(getgc) ~= "function" then return end
        pcall(function()
            for _, obj in ipairs(getgc(true)) do
                if type(obj) ~= "table" then continue end
                for k, v in pairs(obj) do
                    if type(k) ~= "string" then continue end
                    local n = normSprint(k)
                    if type(v) == "boolean" then
                        for _, pat in ipairs(SPRINT_NAMES) do if n == pat then rawset(obj, k, active); break end end
                    elseif type(v) == "number" and v <= 1 then
                        for _, pat in ipairs(SPRINT_NAMES) do if n == pat then rawset(obj, k, active and 1 or 0); break end end
                    end
                end
            end
        end)
    end

    local function applyAutoSprint(char)
        for _, c in ipairs(_sprintConns) do pcall(function() c:Disconnect() end) end
        _sprintConns = {}
        char = char or localPlayer.Character
        if not char then return end

        -- Primary: Backpack.running (the actual sprint toggle in Bloodlines)
        local function watchRunVal(runVal)
            if not (runVal and runVal:IsA("BoolValue")) then return end
            pcall(function() runVal.Value = true end)
            local c = runVal.Changed:Connect(function(v)
                if not v and autoSprint.enabled then pcall(function() runVal.Value = true end) end
            end)
            table.insert(_sprintConns, c)
        end
        local bp = localPlayer.Backpack
        local runVal = bp and bp:FindFirstChild("running")
        if runVal then
            watchRunVal(runVal)
        elseif bp then
            local addConn = bp.ChildAdded:Connect(function(child)
                if child.Name == "running" then watchRunVal(child) end
            end)
            table.insert(_sprintConns, addConn)
        end

        -- Fallback: broader scan + getgc
        cacheSprintVals(char)
        for _, entry in ipairs(_sprintVals) do
            setSprintEntry(entry, true)
            if entry.isAttr then
                local c = entry.char:GetAttributeChangedSignal(entry.key):Connect(function()
                    if not autoSprint.enabled then return end
                    local v = entry.char:GetAttribute(entry.key)
                    if v == false or v == 0 then setSprintEntry(entry, true) end
                end)
                table.insert(_sprintConns, c)
            else
                local v = entry.val
                local c = v.Changed:Connect(function(val)
                    if not autoSprint.enabled then return end
                    if val == false or val == 0 then setSprintEntry(entry, true) end
                end)
                table.insert(_sprintConns, c)
            end
        end
        gcSprintSweep(true)
    end

    local function stopAutoSprint()
        for _, c in ipairs(_sprintConns) do pcall(function() c:Disconnect() end) end
        _sprintConns = {}
        pcall(function()
            local runVal = localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("running")
            if runVal then runVal.Value = false end
        end)
        for _, entry in ipairs(_sprintVals) do setSprintEntry(entry, false) end
        gcSprintSweep(false)
    end

    -- UI Setup
    local fallSec = playerTab:AddSection("Fall Damage")
    local fallToggle = fallSec:AddToggle("NoFallDmgToggle", { Title = "No Fall Damage", Icon = "solar/arrow-down-bold", Default = false, Callback = function(v) noFallDmg.enabled = v; if v then applyNoFallDmg() else restoreNoFallDmg() end end })
    fallSec:AddKeybind("NoFallBind", { Title = "Bind", Mode = "Toggle", Default = "", Callback = function(v) noFallDmg.enabled = v; if v then applyNoFallDmg() else restoreNoFallDmg() end; pcall(function() fallToggle:SetValue(v) end) end })

    local m1Sec = playerTab:AddSection("M1 Attack")
    m1Sec:AddToggle("NoM1CD", { Title = "Remove M1 Cooldown", Icon = "solar/hand-shake-bold", Default = false, Callback = function(v) noM1CD.enabled = v; if v then applyNoM1CD() end end })

    local staminaSec = playerTab:AddSection("Stamina")
    staminaSec:AddToggle("InfStamina", { Title = "Infinite Stamina", Icon = "solar/running-bold", Default = false, Callback = function(v) infStamina.enabled = v end })

    local chakraSec = playerTab:AddSection("Chakra")
    chakraSec:AddToggle("InfChakra", { Title = "Infinite Chakra", Icon = "solar/bolt-circle-bold", Default = false, Callback = function(v) infChakra.enabled = v end })

    local stunSec = playerTab:AddSection("Stun")
    stunSec:AddToggle("NoStun", { Title = "No Stun", Icon = "solar/danger-bold", Default = false, Callback = function(v) noStun.enabled = v; if v then setupNoStun(localPlayer.Character) end end })

    local sprintSec = playerTab:AddSection("Sprint")
    sprintSec:AddToggle("AutoSprintToggle", {
        Title    = "Auto Sprint",
        Icon     = "solar/running-2-bold",
        Default  = false,
        Callback = function(v)
            autoSprint.enabled = v
            if v then applyAutoSprint() else stopAutoSprint() end
        end,
    })

    local charAddedConn = localPlayer.CharacterAdded:Connect(function(char)
        if noFallDmg.enabled then task.delay(0.5, function() applyNoFallDmg(char) end) end
        if noStun.enabled then task.delay(0.5, function() setupNoStun(char) end) end
        if autoSprint.enabled then task.delay(0.5, function() applyAutoSprint(char) end) end
        task.delay(0.5, function()
            buildStatCache(char, {"stamina"}, _staminaCache)
            buildStatCache(char, {"chakra"}, _chakraCache)
        end)
    end)

    if localPlayer.Character then
        if noFallDmg.enabled then applyNoFallDmg(localPlayer.Character) end
        if noStun.enabled then setupNoStun(localPlayer.Character) end
        buildStatCache(localPlayer.Character, {"stamina"}, _staminaCache)
        buildStatCache(localPlayer.Character, {"chakra"}, _chakraCache)
    end

    local function update(data)
        if infStamina.enabled then applyStatCache(_staminaCache) end
        if infChakra.enabled then applyStatCache(_chakraCache) end
        if autoSprint.enabled then
            local now = os.clock()
            if now - _sprintClock >= 1.0 then
                _sprintClock = now
                pcall(function()
                    local runVal = localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("running")
                    if runVal and not runVal.Value then runVal.Value = true end
                end)
                for _, entry in ipairs(_sprintVals) do
                    pcall(function()
                        if entry.isAttr then
                            local v = entry.char:GetAttribute(entry.key)
                            if v == false or v == 0 then setSprintEntry(entry, true) end
                        else
                            local v = entry.val
                            if v.Parent and (v.Value == false or v.Value == 0) then setSprintEntry(entry, true) end
                        end
                    end)
                end
                gcSprintSweep(true)
            end
        end
    end

    local function unmount()
        restoreNoFallDmg()
        for _, c in ipairs(_stunConns) do pcall(function() c:Disconnect() end) end
        stopAutoSprint()
        charAddedConn:Disconnect()
    end

    return { update = update, unmount = unmount }
end
