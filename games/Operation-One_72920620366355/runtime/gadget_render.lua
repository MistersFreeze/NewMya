
-- -------------------- Gadget ESP helpers --------------------
local function get_gadget_color(category)
    return category == "throwable" and color_throwable or color_placeable
end

local function create_gadget_entry(instance, display_name, category)
    if gadget_data[instance] then return gadget_data[instance] end
    local color = get_gadget_color(category)
    local text = Drawing.new("Text")
    text.Visible = false; text.Color = color; text.Size = 13; text.Center = true
    text.Outline = true; text.OutlineColor = Color3.new(0,0,0); text.Transparency = 1; text.Text = display_name

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency    = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor        = color
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee             = instance
    highlight.Parent              = screen_gui

    gadget_data[instance] = { text = text, highlight = highlight, category = category }
    return gadget_data[instance]
end

local function cleanup_gadget(instance)
    local data = gadget_data[instance]
    if data then data.text:Remove(); data.highlight:Destroy(); gadget_data[instance] = nil end
end

-- -------------------- Main render loop --------------------
connections[#connections+1] = runservice.RenderStepped:Connect(function()
    if unloaded then return end

    if _G.new_menu_key then menu_key = _G.new_menu_key; _G.new_menu_key = nil end

    update_esp_arrows()

    -- FOV circles (only while the matching feature is on)
    if aim_assist and show_fov_circle then
        local vp = camera.ViewportSize
        fov_circle.Position = Vector2.new(vp.X/2, vp.Y/2)
        fov_circle.Radius   = aim_fov
        fov_circle.Color    = color_fov_circle
        fov_circle.Visible  = true
    else
        fov_circle.Visible = false
    end

    if silent_aim_on and show_silent_aim_fov_circle then
        local vp = camera.ViewportSize
        local anchor = silent_aim_fov_follow_cursor and uis:GetMouseLocation() or Vector2.new(vp.X / 2, vp.Y / 2)
        fov_circle_silent.Position = anchor
        fov_circle_silent.Radius = silent_aim_fov
        fov_circle_silent.Color = color_fov_silent
        fov_circle_silent.Visible = true
    else
        fov_circle_silent.Visible = false
    end

    -- -- Aim Assist --
    if aim_assist then
        local pressing = false
        if typeof(aim_key) == "EnumItem" then
            if aim_key.EnumType == Enum.UserInputType then
                pressing = uis:IsMouseButtonPressed(aim_key)
            else
                pressing = uis:IsKeyDown(aim_key)
            end
        end

        if pressing then
            local vp       = camera.ViewportSize
            local center   = Vector2.new(vp.X/2, vp.Y/2)
            local cam_pos  = camera.CFrame.Position
            local best_pos, best_dist = nil, math.huge

            for character in pairs(esp_list) do
                if not is_valid(character) or is_teammate(character) then continue end
                local skel = skeleton_list[character]
                if not skel then continue end

                for _, bone_name in ipairs(aim_bone_priority) do
                    local bone = skel.bones[bone_name]
                    if not bone then continue end
                    local vp_pos, on_screen = camera:WorldToViewportPoint(bone.Position)
                    if not on_screen or vp_pos.Z <= 0 then continue end
                    local screen_pos = Vector2.new(vp_pos.X, vp_pos.Y)
                    local dist = (screen_pos - center).Magnitude
                    if dist > aim_fov then continue end
                    -- vis_check ON -> walk bone priority until a visible one is found
                    -- vis_check OFF -> take first on-screen bone immediately (head priority)
                    if vis_check then
                        if check_visibility(cam_pos, bone.Position, character) then
                            if dist < best_dist then best_dist = dist; best_pos = screen_pos end
                            break
                        end
                        -- bone occluded: keep iterating to next priority bone
                    else
                        if dist < best_dist then best_dist = dist; best_pos = screen_pos end
                        break
                    end
                end
            end

            if best_pos then
                local dx = best_pos.X - center.X
                local dy = best_pos.Y - center.Y
                
                -- Cubic scaling for smoothness: makes lower range (1-10%) extremely smooth
                local actual_speed = math.pow(aim_speed, 3)
                
                if aim_speed >= 1.0 then
                    mousemoverel(dx, dy)
                    aim_remainder_x, aim_remainder_y = 0, 0
                else
                    -- Precision precision: accumulate small movements to prevent stopping short
                    aim_remainder_x = aim_remainder_x + (dx * actual_speed)
                    aim_remainder_y = aim_remainder_y + (dy * actual_speed)
                    
                    local move_x = math.round(aim_remainder_x)
                    local move_y = math.round(aim_remainder_y)
                    
                    if move_x ~= 0 or move_y ~= 0 then
                        mousemoverel(move_x, move_y)
                        aim_remainder_x = aim_remainder_x - move_x
                        aim_remainder_y = aim_remainder_y - move_y
                    end
                end
            else
                aim_remainder_x, aim_remainder_y = 0, 0
            end
        else
            aim_remainder_x, aim_remainder_y = 0, 0
        end
    end


    -- -- Player ESP --
    for character, data in pairs(esp_list) do
        local box    = data.box
        local folder = data.folder

        if not character or not character.Parent or not is_valid(character) then
            box.Visible = false; hide_drawings(character); remove_drawings(character)
            folder:Destroy(); esp_list[character] = nil
            remove_skeleton(character)
            continue
        end

        local torso = character:FindFirstChild("torso")
        if not torso or torso.Transparency >= 1 or is_teammate(character) then
            box.Visible = false; hide_drawings(character)
            local skel = skeleton_list[character]
            if skel then
                for _, line in ipairs(skel.lines) do line.l1.Visible = false; line.l2.Visible = false end
                if skel.head_circle then skel.head_circle.Visible = false end
            end
            continue
        end

        if not skeleton_list[character] and (aim_assist or silent_aim_on) then
            create_skeleton(character)
        end

        local _, on_screen = camera:WorldToScreenPoint(torso.Position)

        if on_screen and (camera.CFrame.Position - torso.Position).Magnitude <= 3571.4 then
            local needs_bones = boxes or skeletons or tracers or healthbars or names

            if needs_bones then
                if not skeleton_list[character] then create_skeleton(character) end
                local skel = skeleton_list[character]
                if skel then

                local min_x, min_y   = math.huge,  math.huge
                local max_x, max_y   = -math.huge, -math.huge
                local vp_min_x, vp_min_y = math.huge,  math.huge
                local vp_max_x, vp_max_y = -math.huge, -math.huge
                local head_vp_x, head_vp_y, head_on = 0, 0, false

                local cam_pos = camera.CFrame.Position
                local bone_vis = {}
                if skeletons then
                    for _, bname in ipairs(required_bones) do
                        local b = skel.bones[bname]
                        if b then bone_vis[bname] = check_visibility(cam_pos, b.Position, character) end
                    end
                end

                -- Torso visibility drives box/tracer color (visibility-linked ESP)
                local target_vis = check_visibility(cam_pos, torso.Position, character)

                for i, conn in ipairs(bones) do
                    local b1 = skel.bones[conn[1]]; local b2 = skel.bones[conn[2]]
                    if b1 and b2 then
                        local p1, on1 = camera:WorldToViewportPoint(b1.Position)
                        local p2, on2 = camera:WorldToViewportPoint(b2.Position)
                        local s1, son1 = camera:WorldToScreenPoint(b1.Position)
                        local s2, son2 = camera:WorldToScreenPoint(b2.Position)

                        if son1 then min_x=math.min(min_x,s1.X); max_x=math.max(max_x,s1.X); min_y=math.min(min_y,s1.Y); max_y=math.max(max_y,s1.Y) end
                        if son2 then min_x=math.min(min_x,s2.X); max_x=math.max(max_x,s2.X); min_y=math.min(min_y,s2.Y); max_y=math.max(max_y,s2.Y) end
                        if on1 then vp_min_x=math.min(vp_min_x,p1.X); vp_max_x=math.max(vp_max_x,p1.X); vp_min_y=math.min(vp_min_y,p1.Y); vp_max_y=math.max(vp_max_y,p1.Y) end
                        if on2 then vp_min_x=math.min(vp_min_x,p2.X); vp_max_x=math.max(vp_max_x,p2.X); vp_min_y=math.min(vp_min_y,p2.Y); vp_max_y=math.max(vp_max_y,p2.Y) end
                        if conn[2] == "head" and on2 then head_vp_x, head_vp_y, head_on = p2.X, p2.Y, true end

                        if skeletons and on1 and on2 then
                            local pm = Vector2.new((p1.X+p2.X)/2, (p1.Y+p2.Y)/2)
                            skel.lines[i].l1.From  = Vector2.new(p1.X, p1.Y); skel.lines[i].l1.To = pm
                            skel.lines[i].l2.From  = pm;                       skel.lines[i].l2.To = Vector2.new(p2.X, p2.Y)
                            skel.lines[i].l1.Color = (bone_vis[conn[1]]) and color_skel_vis or color_skel_hid
                            skel.lines[i].l2.Color = (bone_vis[conn[2]]) and color_skel_vis or color_skel_hid
                            skel.lines[i].l1.Visible = true; skel.lines[i].l2.Visible = true
                        else
                            skel.lines[i].l1.Visible = false; skel.lines[i].l2.Visible = false
                        end
                    else
                        skel.lines[i].l1.Visible = false; skel.lines[i].l2.Visible = false
                    end
                end

                -- Head circle
                if skeletons and head_on then
                    local hb  = skel.bones["head"]
                    local top = camera:WorldToViewportPoint(hb.Position + Vector3.new(0,0.5,0))
                    local rad = math.max(math.abs(head_vp_y - top.Y), 4)
                    skel.head_circle.Position = Vector2.new(head_vp_x, head_vp_y)
                    skel.head_circle.Radius   = rad
                    skel.head_circle.Color    = bone_vis["head"] and color_skel_vis or color_skel_hid
                    skel.head_circle.Visible  = true
                else
                    skel.head_circle.Visible = false
                end

                local has_sc = min_x    ~= math.huge
                local has_vp = vp_min_x ~= math.huge

                local vp_left     = vp_min_x - pad
                local vp_bottom   = vp_max_y + pad
                local vp_top      = vp_min_y - pad
                local vp_center_x = (vp_min_x + vp_max_x) / 2

                -- Box  visibility-linked: green when visible, user color when hidden
                if boxes and has_sc then
                    data.stroke.Color = target_vis and color_box_vis or color_box
                    box.Visible  = true
                    box.Position = UDim2.fromOffset(min_x-pad, min_y-pad)

                    box.Size     = UDim2.fromOffset(max_x-min_x+pad*2, max_y-min_y+pad*2)
                else
                    box.Visible = false
                end

                -- Tracer
                if tracers and has_vp then
                    local vps = camera.ViewportSize
                    data.tracer.Color   = color_tracer
                    data.tracer.From    = Vector2.new(vps.X/2, vps.Y)
                    data.tracer.To      = Vector2.new(vp_center_x, vp_bottom)
                    data.tracer.Visible = true
                else
                    data.tracer.Visible = false
                end

                -- Health bar
                if healthbars and has_vp then
                    local hp, max_hp = get_health(character)
                    if hp and max_hp and max_hp > 0 then
                        local hb  = skel.bones["head"]; local l1b = skel.bones["leg1"]; local l2b = skel.bones["leg2"]; local tb = skel.bones["torso"]
                        local top_vp = camera:WorldToViewportPoint(hb.Position + Vector3.new(0,0.35,0))
                        local bot_vp = camera:WorldToViewportPoint((l1b.Position+l2b.Position)*0.5 - Vector3.new(0,0.4,0))
                        local tz     = camera:WorldToViewportPoint(tb.Position).Z
                        if tz>0 and top_vp.Z>0 and bot_vp.Z>0 then
                            local by_top = math.min(top_vp.Y, bot_vp.Y); local by_bot = math.max(top_vp.Y, bot_vp.Y)
                            local bh = by_bot - by_top
                            if bh > 1 then
                                local bx = vp_left - 4; local pct = math.clamp(hp/max_hp,0,1)
                                data.health_bg.From=Vector2.new(bx,by_top); data.health_bg.To=Vector2.new(bx,by_bot); data.health_bg.Visible=true
                                data.health_fill.From=Vector2.new(bx,by_bot-bh*pct); data.health_fill.To=Vector2.new(bx,by_bot)
                                data.health_fill.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0); data.health_fill.Visible=true
                            else
                                data.health_bg.Visible=false; data.health_fill.Visible=false
                            end
                        else
                            data.health_bg.Visible=false; data.health_fill.Visible=false
                        end
                    else
                        data.health_bg.Visible=false; data.health_fill.Visible=false
                    end
                else
                    data.health_bg.Visible=false; data.health_fill.Visible=false
                end

                -- Names
                if names and has_vp then
                    data.name_text.Text     = get_player_name(character)
                    data.name_text.Position = Vector2.new(vp_center_x, vp_top - 16)
                    data.name_text.Visible  = true
                else
                    data.name_text.Visible = false
                end

                end -- if skel
            else
                remove_skeleton(character); box.Visible=false
                data.tracer.Visible=false; data.health_bg.Visible=false; data.health_fill.Visible=false; data.name_text.Visible=false
            end
        else
            box.Visible=false; hide_drawings(character); remove_skeleton(character)
        end
    end

    -- -- Gadget ESP --
    if gadgets then
        local seen = {}
        for _, info in ipairs(all_gadget_tags) do
            local ok, tagged = pcall(collection.GetTagged, collection, info.tag)
            if not ok then continue end
            for _, instance in ipairs(tagged) do
                if instance.Parent and instance:IsDescendantOf(workspace)
                    and not is_friendly_gadget(instance)
                    and not (info.tag == "DefaultCamera" and is_camera_broken(instance))
                then
                    seen[instance] = true
                    local root = instance:FindFirstChild("Root")
                    local part = root or (instance:IsA("BasePart") and instance) or instance:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local _, s_on = camera:WorldToScreenPoint(part.Position)
                        if s_on and (camera.CFrame.Position - part.Position).Magnitude <= 3571.4 then
                            local gdata    = create_gadget_entry(instance, info.name, info.category)
                            local cur_col  = get_gadget_color(info.category)
                            gdata.text.Color            = cur_col
                            gdata.highlight.OutlineColor = cur_col
                            local v_pos = camera:WorldToViewportPoint(part.Position)
                            gdata.text.Position = Vector2.new(v_pos.X, v_pos.Y - 20)
                            gdata.text.Visible  = true
                            gdata.highlight.Enabled = true
                        else
                            local gdata = gadget_data[instance]
                            if gdata then gdata.text.Visible=false; gdata.highlight.Enabled=false end
                        end
                    end
                end
            end
        end
        for instance in pairs(gadget_data) do
            if not seen[instance] then cleanup_gadget(instance) end
        end
    else
        for instance in pairs(gadget_data) do cleanup_gadget(instance) end
        gadget_data = {}
    end
end)
