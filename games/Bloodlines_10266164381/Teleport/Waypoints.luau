return function(ctx)
    local teleportTab = ctx.teleportTab
    local localPlayer = ctx.localPlayer
    local Players = ctx.Players
    local Workspace = ctx.Workspace
    local Fluent = ctx.Fluent
    
    local _conns = {}

    local function getObjPos(obj)
        if obj:IsA("Model") then
            if obj.PrimaryPart then return obj.PrimaryPart.Position end
            local p = obj:FindFirstChildWhichIsA("BasePart", true)
            if p then return p.Position end
            local ok, pv = pcall(function() return obj:GetPivot().Position end)
            if ok then return pv end
        elseif obj:IsA("BasePart") then
            return obj.Position
        end
        return nil
    end

    local function tpTo(pos)
        local char = localPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    end

    -- Players Section
    local playerTpSec = teleportTab:AddSection("Players")
    local selPlayerTP = nil
    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then table.insert(names, p.Name) end
        end
        return names
    end
    local initPNames = getPlayerNames()
    local playerTPDD = nil

    if #initPNames > 0 then
        playerTPDD = playerTpSec:AddDropdown("PlayerTPDD", { Title = "Select Player", Values = initPNames, Default = initPNames[1], Callback = function(v) selPlayerTP = v end })
        selPlayerTP = initPNames[1]
    else
        playerTPDD = playerTpSec:AddDropdown("PlayerTPDD", { Title = "Select Player", Values = { "No players" }, Default = "No players", Callback = function(v) selPlayerTP = v ~= "No players" and v or nil end })
    end

    playerTpSec:AddButton({ Title = "Refresh List", Icon = "solar/refresh-bold", Callback = function()
        local names = getPlayerNames()
        if #names == 0 then names = { "No players" } end
        pcall(function() playerTPDD:SetValues(names); playerTPDD:SetValue(names[1]) end)
    end })

    playerTpSec:AddButton({ Title = "Teleport to Player", Icon = "solar/map-point-bold", Callback = function()
        if not selPlayerTP or selPlayerTP == "No players" then return end
        local tp = Players:FindFirstChild(selPlayerTP)
        if not tp then return end
        local c = tp.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r then tpTo(r.Position) end
    end })

    -- Data scans
    local tpChakra, tpNPCs, tpMerchants, tpWeapons, tpArmor = {}, {}, {}, {}, {}
    local function dedupPos(list, pos, prox)
        for _, e in ipairs(list) do if (e.pos - pos).Magnitude < (prox or 8) then return false end end
        return true
    end
    local npcNameSet, merchantNameSet, weaponNameSet, armorCounts = {}, {}, {}, {}

    local VILLAGES = { "sorythia", "durana", "rain", "snow", "rogue", "akatsuki", "winter", "leaf", "sand", "mist", "stone", "cloud" }
    local function getVillageAncestor(obj)
        local node = obj.Parent
        for _ = 1, 6 do
            if not node or node == Workspace or node == game then break end
            local nl = node.Name:lower()
            for _, v in ipairs(VILLAGES) do if nl:find(v) then return node.Name end end
            node = node.Parent
        end
        return nil
    end

    local function getUniqueName(baseName, countsDict)
        countsDict[baseName] = (countsDict[baseName] or 0) + 1
        if countsDict[baseName] > 1 then return baseName .. " " .. countsDict[baseName] end
        return baseName
    end

    pcall(function()
        local cpFolder = Workspace:FindFirstChild("ChakraPoints")
        if cpFolder then
            for _, obj in ipairs(cpFolder:GetChildren()) do
                local pos = getObjPos(obj)
                if not pos then continue end
                local nameVal = obj:FindFirstChild("PointName")
                local nm = (nameVal and typeof(nameVal.Value) == "string" and nameVal.Value ~= "") and nameVal.Value or obj.Name
                if nm ~= "" and dedupPos(tpChakra, pos, 20) then table.insert(tpChakra, { name = nm, pos = pos }) end
            end
        end
        if #tpChakra == 0 then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end
                if obj.Name:lower() ~= "chakrapoint" then continue end
                local pos = getObjPos(obj)
                if pos and dedupPos(tpChakra, pos, 20) then
                    local village = getVillageAncestor(obj)
                    local nm = village and (village .. " Chakra Point") or obj.Name
                    table.insert(tpChakra, { name = nm, pos = pos })
                end
            end
        end

        local MERCHANT_NAMES = { "merchant", "food merchant", "rogue merchant", "rogue food merchant", "chef", "rogue chef", "lady chef", "innkeeper", "rogue innkeeper", "outkeeper" }
        local WEAPON_KW = { "katana","sword","blade","dagger","kunai","shuriken", "weapon","staff","spear","bow","axe","hammer", "silver", "golden" }
        local ARMOR_KW  = { "armor","armour","vest","helmet","chestplate", "shield","robe","cloak","cape","gear","boots","gauntlet" }

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if not obj:IsA("Model") then continue end
            
            -- NPCs & Merchants
            if obj:FindFirstChild("NPC") then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local settings = obj:FindFirstChild("Settings")
                    local nv = settings and settings:FindFirstChild("NPCName")
                    local baseName = (nv and nv.Value ~= "") and nv.Value or obj.Name
                    if baseName ~= "" then
                        local isMerchant = false
                        for _, mn in ipairs(MERCHANT_NAMES) do if baseName:lower() == mn then isMerchant = true; break end end
                        
                        local village = getVillageAncestor(obj)
                        if isMerchant then
                            local displayName = village and (village .. " " .. baseName) or baseName
                            if not merchantNameSet[displayName] then
                                merchantNameSet[displayName] = true
                                table.insert(tpMerchants, { name = displayName, pos = hrp.Position })
                            end
                        else
                            local dname = (village and baseName:lower():find("^(merchant|food|inn)") and baseName ~= "Merchant") and (village .. " " .. baseName) or baseName
                            if not npcNameSet[dname] then
                                npcNameSet[dname] = true
                                table.insert(tpNPCs, { name = dname, pos = hrp.Position })
                            end
                        end
                    end
                end
                continue
            end

            -- Stands
            local nl = obj.Name:lower()
            if nl:find("ascended") then continue end
            local isClothingArmor = false
            local clothingChild = obj:FindFirstChild("Clothing")
            if clothingChild and clothingChild:IsA("Model") then isClothingArmor = true end
            if not isClothingArmor and obj:FindFirstChildWhichIsA("Humanoid") then continue end
            
            local pos = getObjPos(obj)
            if not pos then continue end
            local village = getVillageAncestor(obj)
            local baseName = village and (village .. " " .. obj.Name) or obj.Name

            if not isClothingArmor then
                for _, kw in ipairs(WEAPON_KW) do
                    if nl:find(kw, 1, true) then
                        if not weaponNameSet[baseName] then
                            weaponNameSet[baseName] = true
                            table.insert(tpWeapons, { name = baseName, pos = pos })
                        end
                        break
                    end
                end
            end
            
            if isClothingArmor then
                if dedupPos(tpArmor, pos, 5) then table.insert(tpArmor, { name = getUniqueName(baseName, armorCounts), pos = pos }) end
            else
                for _, kw in ipairs(ARMOR_KW) do
                    if nl:find(kw, 1, true) then
                        if dedupPos(tpArmor, pos, 5) then table.insert(tpArmor, { name = getUniqueName(baseName, armorCounts), pos = pos }) end
                        break
                    end
                end
            end
        end
    end)

    table.sort(tpChakra, function(a, b) return a.name < b.name end)
    table.sort(tpNPCs, function(a, b) return a.name < b.name end)
    table.sort(tpMerchants, function(a, b) return a.name < b.name end)
    table.sort(tpWeapons, function(a, b) return a.name < b.name end)
    table.sort(tpArmor, function(a, b) return a.name < b.name end)

    local function names(t) local r = {}; for _, e in ipairs(t) do table.insert(r, e.name) end; return r end
    local function posForName(t, v) for _, e in ipairs(t) do if e.name == v then return e.pos end end; return nil end

    -- Chakra Points
    local cpSec = teleportTab:AddSection("Chakra Points")
    local selCP = #tpChakra > 0 and tpChakra[1].pos or nil
    if #tpChakra > 0 then
        local cpNames = names(tpChakra)
        cpSec:AddDropdown("CPDropdown", { Title = "Select Chakra Point", Values = cpNames, Default = cpNames[1], Callback = function(v) selCP = posForName(tpChakra, v) end })
        cpSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold", Callback = function() if selCP then tpTo(selCP) end end })
    else cpSec:AddParagraph({ Title = "None found", Content = "No chakra points detected." }) end

    -- Merchants
    local merchantSec = teleportTab:AddSection("Merchants")
    local selMerchant = #tpMerchants > 0 and tpMerchants[1].pos or nil
    if #tpMerchants > 0 then
        local mNames = names(tpMerchants)
        merchantSec:AddDropdown("MerchantDropdown", { Title = "Select Merchant", Values = mNames, Default = mNames[1], Callback = function(v) selMerchant = posForName(tpMerchants, v) end })
        merchantSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold", Callback = function() if selMerchant then tpTo(selMerchant) end end })
    else merchantSec:AddParagraph({ Title = "None found", Content = "No merchants detected." }) end

    -- Weapon Stands
    local wStandSec = teleportTab:AddSection("Weapon Stands")
    local selWStand = #tpWeapons > 0 and tpWeapons[1].pos or nil
    if #tpWeapons > 0 then
        local wNames = names(tpWeapons)
        wStandSec:AddDropdown("WStandDropdown", { Title = "Select Weapon", Values = wNames, Default = wNames[1], Callback = function(v) selWStand = posForName(tpWeapons, v) end })
        wStandSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold", Callback = function() if selWStand then tpTo(selWStand) end end })
    else wStandSec:AddParagraph({ Title = "None found", Content = "No weapon stands detected." }) end

    -- Armor Stands
    local aStandSec = teleportTab:AddSection("Armor Stands")
    local selAStand = #tpArmor > 0 and tpArmor[1].pos or nil
    if #tpArmor > 0 then
        local aNames = names(tpArmor)
        aStandSec:AddDropdown("AStandDropdown", { Title = "Select Armor", Values = aNames, Default = aNames[1], Callback = function(v) selAStand = posForName(tpArmor, v) end })
        aStandSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold", Callback = function() if selAStand then tpTo(selAStand) end end })
    else aStandSec:AddParagraph({ Title = "None found", Content = "No armor stands detected." }) end

    -- NPCs
    local npcTpSec = teleportTab:AddSection("NPCs")
    local selNPC = #tpNPCs > 0 and tpNPCs[1].pos or nil
    if #tpNPCs > 0 then
        local npcNames = names(tpNPCs)
        npcTpSec:AddDropdown("NPCTpDropdown", { Title = "Select NPC", Values = npcNames, Default = npcNames[1], Callback = function(v) selNPC = posForName(tpNPCs, v) end })
        npcTpSec:AddButton({ Title = "Teleport", Icon = "solar/map-point-bold", Callback = function() if selNPC then tpTo(selNPC) end end })
    else npcTpSec:AddParagraph({ Title = "None found", Content = "No NPCs detected." }) end

    -- Safe Point and Auto Teleport have been moved to the Security tab (Misc/Security.luau).

    local function update(data) end
    local function unmount()
        for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    end

    return { update = update, unmount = unmount }
end
