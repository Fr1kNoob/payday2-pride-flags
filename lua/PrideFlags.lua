_G.PrideFlags = _G.PrideFlags or {}

PrideFlags.ModPath = PrideFlags.ModPath or ModPath
PrideFlags.Version = "1.1.4"
PrideFlags.MessageId = "PrideFlags:hello"
PrideFlags.SaveFile = SavePath .. "PrideFlags.json"
PrideFlags.ValidFlags = {
    rainbow = true,
    trans = true,
    bi = true,
    lesbian = true,
    ace = true,
    nonbinary = true
}
PrideFlags.Defaults = {
    enabled = true,
    alpha = 90,
    flag = "trans",
    position = "right"
}
PrideFlags.Settings = PrideFlags.Settings or {}
PrideFlags.Peers = PrideFlags.Peers or {}
PrideFlags.Elements = PrideFlags.Elements or setmetatable({}, { __mode = "k" })

function PrideFlags:Log(message)
    log("[Pride Flags] " .. tostring(message))
end

function PrideFlags:SanitizeFlag(value)
    value = type(value) == "string" and string.lower(value) or ""
    return self.ValidFlags[value] and value or "rainbow"
end

function PrideFlags:LoadSettings()
    for key, value in pairs(self.Defaults) do
        self.Settings[key] = value
    end
    local file = io.open(self.SaveFile, "r")
    if file then
        local ok, data = pcall(json.decode, file:read("*all"))
        file:close()
        if ok and type(data) == "table" then
            for key, default in pairs(self.Defaults) do
                if type(data[key]) == type(default) then
                    self.Settings[key] = data[key]
                end
            end
        end
    end
    self.Settings.alpha = math.clamp(tonumber(self.Settings.alpha) or 90, 10, 100)
    self.Settings.flag = self:SanitizeFlag(self.Settings.flag)
    if self.Settings.position ~= "left" and self.Settings.position ~= "right" then
        self.Settings.position = "right"
    end
end

function PrideFlags:SaveSettings()
    local file = io.open(self.SaveFile, "w+")
    if file then
        file:write(json.encode(self.Settings))
        file:close()
    end
    self:RefreshAll()
end

function PrideFlags:Texture(flag)
    flag = self:SanitizeFlag(flag)
    local path = "guis/textures/pride_flags/" .. flag
    if DB and DB:has(Idstring("texture"), Idstring(path)) then
        return path
    end
    return "guis/textures/pride_flags/rainbow"
end

function PrideFlags:RegisterTextures()
    if self.TexturesRegistered or not BLT or not BLT.AssetManager then
        return
    end
    for flag in pairs(self.ValidFlags) do
        BLT.AssetManager:CreateEntry(
            Idstring("guis/textures/pride_flags/" .. flag),
            Idstring("texture"),
            self.ModPath .. "assets/pride_flags/" .. flag .. ".texture"
        )
    end
    self.TexturesRegistered = true
end

function PrideFlags:LocalPeerId()
    local session = managers.network and managers.network:session()
    local peer = session and session:local_peer()
    return peer and peer:id()
end

function PrideFlags:IsLocalPeer(peer_id)
    local local_peer_id = self:LocalPeerId()
    return peer_id == 0 or (local_peer_id ~= nil and peer_id == local_peer_id)
end

function PrideFlags:ShouldShow(peer_id)
    if not self.Settings.enabled or type(peer_id) ~= "number" then
        return false
    end
    if self:IsLocalPeer(peer_id) then
        return true
    end
    return self.Peers[peer_id] ~= nil
end

function PrideFlags:FlagForPeer(peer_id)
    if self:IsLocalPeer(peer_id) then
        return self.Settings.flag
    end
    return self.Peers[peer_id] and self.Peers[peer_id].flag or "rainbow"
end

function PrideFlags:ApplyBitmap(bitmap, peer_id, scale)
    if not alive(bitmap) then
        return
    end
    scale = tonumber(scale) or 1
    local size = math.max(4, 16 * scale)
    bitmap:set_image(self:Texture(self:FlagForPeer(peer_id)))
    bitmap:set_size(size * 1.5, size)
    bitmap:set_alpha(self.Settings.alpha / 100)
    bitmap:set_visible(self:ShouldShow(peer_id))
end

function PrideFlags:RegisterElement(owner, refresh)
    if owner and type(refresh) == "function" then
        self.Elements[owner] = refresh
    end
end

function PrideFlags:RefreshAll()
    for owner, refresh in pairs(self.Elements) do
        if not owner or (owner._panel and not alive(owner._panel)) then
            self.Elements[owner] = nil
        else
            local ok = pcall(refresh)
            if not ok then
                self.Elements[owner] = nil
            end
        end
    end
end

function PrideFlags:ClearPeer(peer_id)
    self.Peers[tonumber(peer_id)] = nil
    self:RefreshAll()
end

function PrideFlags:Receive(sender, data)
    sender = tonumber(sender)
    if not sender or sender < 1 or sender > 4 or type(data) ~= "string" or #data > 32 then
        return
    end
    local version, flag = data:match("^([%d]+%.[%d]+%.[%d]+)|([%a]+)$")
    if not version or not flag then
        return
    end
    self.Peers[sender] = { version = version, flag = self:SanitizeFlag(flag) }
    self:RefreshAll()
end

function PrideFlags:Payload()
    return self.Version .. "|" .. self:SanitizeFlag(self.Settings.flag)
end

function PrideFlags:Send(peer_id)
    if not LuaNetworking then
        return
    end
    if peer_id then
        peer_id = tonumber(peer_id)
        if peer_id and peer_id ~= self:LocalPeerId() then
            LuaNetworking:SendToPeer(peer_id, self.MessageId, self:Payload())
        end
    else
        LuaNetworking:SendToPeers(self.MessageId, self:Payload())
    end
end

function PrideFlags:PeerIdByName(name)
    if type(name) ~= "string" then
        return nil
    end
    local account = managers.network and managers.network.account
    local local_name = account and account.username and account:username()
    if local_name == name then
        return self:LocalPeerId() or 0
    end
    local session = managers.network and managers.network:session()
    if not session then
        return nil
    end
    for peer_id = 1, 4 do
        local peer = session:peer(peer_id)
        if peer and peer:name() == name then
            return peer_id
        end
    end
end

if not PrideFlags.CoreLoaded then
    PrideFlags:LoadSettings()
    PrideFlags:RegisterTextures()
    Hooks:Add("NetworkReceivedData", "PrideFlags_NetworkReceivedData", function(sender, message_id, data)
        if message_id == PrideFlags.MessageId then
            PrideFlags:Receive(sender, data)
        end
    end)
    PrideFlags.CoreLoaded = true
    PrideFlags:Log("Loaded v" .. PrideFlags.Version)
end

if RequiredScript == "lib/managers/localizationmanager" then
    Hooks:Add("LocalizationManagerPostInit", "PrideFlags_Localization", function(localization_manager)
        localization_manager:load_localization_file(PrideFlags.ModPath .. "loc/english.txt")
    end)
elseif RequiredScript == "lib/managers/menumanager" then
    MenuCallbackHandler.PrideFlagsEnabled = function(_, item)
        PrideFlags.Settings.enabled = item:value() == "on"
        PrideFlags:SaveSettings()
    end
    MenuCallbackHandler.PrideFlagsNumber = function(_, item)
        PrideFlags.Settings[item:name():gsub("pride_flags_", "")] = tonumber(item:value())
        PrideFlags:SaveSettings()
    end
    MenuCallbackHandler.PrideFlagsPosition = function(_, item)
        local position = item:value()
        if position ~= "left" and position ~= "right" then
            position = "right"
        end
        PrideFlags.Settings.position = position
        PrideFlags:SaveSettings()
    end
    MenuCallbackHandler.PrideFlagsVariant = function(_, item)
        PrideFlags.Settings.flag = PrideFlags:SanitizeFlag(item:value())
        PrideFlags:SaveSettings()
        PrideFlags:Send()
    end
    MenuHelper:LoadFromJsonFile(PrideFlags.ModPath .. "menu/options.json", PrideFlags, PrideFlags.Settings)
elseif RequiredScript == "lib/network/base/basenetworksession" then
    Hooks:PostHook(BaseNetworkSession, "on_entered_lobby", "PrideFlags_EnteredLobby", function()
        PrideFlags:Send()
    end)
    Hooks:PostHook(BaseNetworkSession, "on_peer_entered_lobby", "PrideFlags_PeerEnteredLobby", function(_, peer)
        PrideFlags:Send(peer and peer:id())
    end)
    Hooks:PostHook(BaseNetworkSession, "on_load_complete", "PrideFlags_LoadComplete", function()
        PrideFlags:Send()
    end)
    Hooks:PostHook(BaseNetworkSession, "_on_peer_removed", "PrideFlags_PeerRemoved", function(_, _, peer_id)
        PrideFlags:ClearPeer(peer_id)
    end)
elseif RequiredScript == "lib/managers/networkmanager" then
    Hooks:PostHook(NetworkManager, "on_peer_added", "PrideFlags_PeerAdded", function(_, peer, peer_id)
        PrideFlags:Send(peer_id or (peer and peer:id()))
    end)
end
