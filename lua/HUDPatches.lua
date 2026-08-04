if not PrideFlags then
    dofile(ModPath .. "lua/PrideFlags.lua")
end

local function add_bitmap(panel, name)
    local bitmap = panel:child(name)
    if not alive(bitmap) then
        bitmap = panel:bitmap({ name = name, layer = 100, visible = false })
    end
    return bitmap
end

local function place_bitmap(bitmap, text, panel)
    local _, _, width, height = text:text_rect()
    local position = PrideFlags.Settings.position
    if position == "above" then
        bitmap:set_center_x(text:center_x())
        bitmap:set_bottom(text:top() - 1)
    elseif position == "left" then
        bitmap:set_right(text:left() - 3)
        bitmap:set_center_y(text:center_y())
    else
        bitmap:set_left(text:left() + width + 3)
        bitmap:set_center_y(text:center_y())
    end
    if position == "right" and bitmap:right() > panel:right() then
        bitmap:set_right(panel:right())
    elseif position == "left" and bitmap:left() < panel:left() then
        bitmap:set_left(panel:left())
    end
end

local function refresh_teammate(teammate)
    if not teammate or not alive(teammate._panel) then
        return
    end
    local name_text = teammate._panel:child("name")
    if not alive(name_text) then
        return
    end
    local bitmap = add_bitmap(teammate._panel, "pride_flags_icon")
    local is_local = teammate._main_player or (teammate.is_local_player and teammate:is_local_player())
    local peer_id = (teammate.peer_id and teammate:peer_id()) or (is_local and (PrideFlags:LocalPeerId() or 0))
    local scale = name_text:font_size() / math.max(tweak_data.hud_players.name_size, 1)
    PrideFlags:ApplyBitmap(bitmap, peer_id, scale)
    place_bitmap(bitmap, name_text, teammate._panel)
end

if RequiredScript == "lib/managers/hud/hudteammate" then
    PrideFlags:Log("Installed HUDTeammate hooks")
    Hooks:PostHook(HUDTeammate, "init", "PrideFlags_HUDTeammateInit", function(teammate)
        PrideFlags:RegisterElement(teammate, function() refresh_teammate(teammate) end)
        refresh_teammate(teammate)
    end)
    Hooks:PostHook(HUDTeammate, "set_name", "PrideFlags_HUDTeammateSetName", function(teammate)
        refresh_teammate(teammate)
    end)
elseif RequiredScript == "lib/managers/hudmanagerpd2" then
    if HUDTeammateCustom then
        PrideFlags:Log("Installed HUDTeammateCustom hook")
        Hooks:PostHook(HUDTeammateCustom, "set_name", "PrideFlags_CustomSetName", function(teammate)
            local info = teammate._player_info
            local panel = info and info._panel
            local name_text = info and info._components and info._components.name
            if not alive(panel) or not alive(name_text) then
                return
            end
            local bitmap = add_bitmap(panel, "pride_flags_icon")
            local refresh = function()
                if not alive(bitmap) or not alive(name_text) then
                    return
                end
                local peer_id = teammate:peer_id() or (teammate:is_local_player() and (PrideFlags:LocalPeerId() or 0))
                PrideFlags:ApplyBitmap(bitmap, peer_id, name_text:font_size() / 20)
                local width = 0
                for _, component_name in ipairs({ "name", "character", "rank" }) do
                    local component = info._components[component_name]
                    if alive(component) and component:visible() then
                        local _, _, component_width = component:text_rect()
                        component:set_x(width)
                        component:set_w(component_width)
                        width = width + component_width + 3
                    end
                end
                panel:set_w(math.max(width - 3, 0))
                place_bitmap(bitmap, name_text, panel)
            end
            PrideFlags:RegisterElement(teammate, refresh)
            refresh()
        end)
    end
elseif RequiredScript == "lib/managers/hud/hudchat" then
    PrideFlags:Log("Installed WolfHUD chat hook")
    Hooks:PostHook(HUDChat, "receive_message", "PrideFlags_ChatMessage", function(chat, name, message, color)
        local peer_id = PrideFlags:PeerIdByName(name)
        if not PrideFlags:ShouldShow(peer_id) then
            return
        end
        local entry = chat._messages and chat._messages[#chat._messages]
        local panel = entry and entry.panel
        local text = alive(panel) and panel:child("msg")
        if not alive(text) then
            return
        end
        local bitmap = add_bitmap(panel, "pride_flags_icon")
        PrideFlags:ApplyBitmap(bitmap, peer_id, HUDChat.LINE_HEIGHT / 20)
        local old_lines = entry.lines or 1
        local spacer = PrideFlags.Settings.position == "right" and "    " or " "
        text:set_text(tostring(name) .. ":" .. spacer .. tostring(message))
        text:set_range_color(0, utf8.len(name) + 1, color or Color.white)
        local new_lines = text:number_of_lines()
        text:set_h(HUDChat.LINE_HEIGHT * new_lines)
        panel:set_h(HUDChat.LINE_HEIGHT * new_lines)
        local background = panel:child("bg")
        if alive(background) then
            background:set_h(panel:h())
        end
        entry.lines = new_lines
        chat._total_message_lines = chat._total_message_lines + new_lines - old_lines
        local measure = panel:text({
            text = tostring(name) .. ":",
            font = tweak_data.menu.pd2_small_font,
            font_size = HUDChat.LINE_HEIGHT * 0.95,
            visible = false
        })
        local _, _, name_width = measure:text_rect()
        panel:remove(measure)
        place_bitmap(bitmap, text, panel)
        chat:_layout_output_panel()
    end)
elseif RequiredScript == "lib/managers/hud/newhudstatsscreen" then
    if LoadoutNameItem then
        PrideFlags:Log("Installed WolfHUD player-list hook")
        Hooks:PostHook(LoadoutNameItem, "set_outfit", "PrideFlags_LoadoutName", function(item)
            local panel = item._panel
            local text = item._text
            local peer_id = item._owner and item._owner.get_peer_id and item._owner:get_peer_id()
            if item._owner and item._owner.local_peer and item._owner:local_peer() then
                peer_id = peer_id or PrideFlags:LocalPeerId() or 0
            end
            if not alive(panel) or not alive(text) then
                return
            end
            local bitmap = add_bitmap(panel, "pride_flags_icon")
            local refresh = function()
                PrideFlags:ApplyBitmap(bitmap, peer_id, text:font_size() / 20)
                place_bitmap(bitmap, text, panel)
            end
            PrideFlags:RegisterElement(item, refresh)
            refresh()
        end)
    end
end
