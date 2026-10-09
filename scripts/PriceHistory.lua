-- Correct the initial LIQUIDLIME history, not the game's pricing or its GUI.
-- Capture existing history first; its backup and marker persist on the next save.
LiquidLimePriceHistory = {}

local modDirectory = g_currentModDirectory or ""
local VERSION = 1
local SAVE_KEY = ".liquidLimePriceHistory"
local unpackValues = unpack or table.unpack

local function pack(...)
    return {n = select("#", ...), ...}
end

local function finite(value, allowZero)
    return type(value) == "number" and value == value and value < math.huge
        and (value > 0 or (allowZero and value == 0))
end

local function normalizePath(path)
    if type(path) ~= "string" then return nil end
    return (path:gsub("\\", "/"):gsub("/+", "/")):lower()
end

local function log(message)
    if LiquidLime ~= nil and LiquidLime.Log ~= nil then
        LiquidLime:Log(message)
    else
        print("[LiquidLime] " .. message)
    end
end

function LiquidLimePriceHistory:isServer(manager)
    local mission = g_currentMission
    return self.enabled and mission ~= nil and mission.economyManager == manager
        and type(mission.getIsServer) == "function" and mission:getIsServer()
end

-- The native history combines all accepting stations, including hidden ones.
-- Do not impose this mod's baseline on a map or another mod's selling points.
function LiquidLimePriceHistory:getPlan(manager)
    if not self:isServer(manager) or type(manager.sellingStations) ~= "table"
        or g_fillTypeManager == nil
        or type(g_fillTypeManager.getFillTypeByName) ~= "function" then return nil end
    local fillType = g_fillTypeManager:getFillTypeByName("LIQUIDLIME")
    if fillType == nil or fillType.index == nil or type(fillType.economy) ~= "table"
        or type(fillType.economy.factors) ~= "table"
        or type(fillType.economy.history) ~= "table"
        or fillType.economy.sychronizeData ~= true then return nil end

    local ownFilename = normalizePath(modDirectory .. "placeables/LiquidLimeSellPoint/liquidLimeSellPoint.xml")
    local baseline, count = nil, 0
    for _, entry in pairs(manager.sellingStations) do
        local station = type(entry) == "table" and entry.station or nil
        if type(station) ~= "table" or type(station.acceptedFillTypes) ~= "table" then
            return nil
        end
        if station.acceptedFillTypes[fillType.index] then
            local placeable = station.owningPlaceable
            local price = type(station.originalFillTypePrices) == "table"
                and station.originalFillTypePrices[fillType.index] or nil
            if type(placeable) ~= "table" or normalizePath(placeable.configFileName) ~= ownFilename
                or not finite(price, false) then return nil end
            if baseline ~= nil and math.abs(price - baseline) > math.max(price, baseline) * 1e-7 then
                return nil
            end
            baseline = baseline or price
            count = count + 1
        end
    end
    if count == 0 then return nil end

    local backup, replacement = {}, {}
    for period = 1, 12 do
        local factor = fillType.economy.factors[period]
        local old = fillType.economy.history[period]
        if not finite(factor, true) or not finite(old, true) then return nil end
        local price = baseline * factor
        if not finite(price, true) or price * 1000 > 2147483647 then return nil end
        backup[period], replacement[period] = old, price
    end
    return {history = fillType.economy.history, backup = backup,
        replacement = replacement, baseline = baseline}
end

function LiquidLimePriceHistory:loadMarker(manager, xmlFileHandle, key)
    if not self:isServer(manager) then return end
    local xml = XMLFile.wrap(xmlFileHandle)
    local root = key .. SAVE_KEY
    if xml:hasProperty(root) then
        local state = self.state
        -- Any existing marker prevents another reset, even if damaged/newer.
        state.done = true
        state.rawMarker = {version = xml:getString(root .. "#version"),
            baseline = xml:getString(root .. "#baseline"), backup = {}}
        for period = 1, 12 do
            state.rawMarker.backup[period] = xml:getString(string.format("%s.backup.period(%d)", root, period - 1))
        end
        if tonumber(state.rawMarker.version) ~= VERSION then
            log("Price history marker is unsupported; existing history will be preserved.")
        end
    end
    xml:delete()
end

function LiquidLimePriceHistory:saveMarker(manager, xmlFileHandle, key)
    if not self:isServer(manager) or not self.state.done then return end
    local xml = XMLFile.wrap(xmlFileHandle)
    local root, state = key .. SAVE_KEY, self.state
    if state.rawMarker ~= nil then
        -- Retain the known backup values independently of subsequent prices.
        -- Unsupported markers remain non-reset sentinels; unknown future fields
        -- are not interpreted by this version.
        xml:setString(root .. "#version", state.rawMarker.version or "invalid")
        if state.rawMarker.baseline ~= nil then xml:setString(root .. "#baseline", state.rawMarker.baseline) end
        for period = 1, 12 do
            local value = state.rawMarker.backup[period]
            if value ~= nil then xml:setString(string.format("%s.backup.period(%d)", root, period - 1), value) end
        end
    elseif state.backup ~= nil then
        xml:setInt(root .. "#version", VERSION)
        xml:setFloat(root .. "#baseline", state.baseline)
        for period = 1, 12 do
            xml:setString(string.format("%s.backup.period(%d)", root, period - 1), string.format("%.17g", state.backup[period]))
        end
    end
    xml:delete()
end

function LiquidLimePriceHistory:syncHistory(manager)
    if not self:isServer(manager) or not self.state.syncPending then return end
    local ok, err = pcall(function()
        for period = 1, 12 do manager:sendPeriodFillTypeHistory(period) end
    end)
    if ok then
        self.state.syncPending = false
    elseif not self.state.syncWarning then
        self.state.syncWarning = true
        log("Price history synchronization will be retried: " .. tostring(err))
    end
end

function LiquidLimePriceHistory:tryApply(manager, syncClients)
    if not self:isServer(manager) or self.state.done then return false end
    -- Late placement may happen with players already connected.
    if syncClients and (g_server == nil or type(manager.sendPeriodFillTypeHistory) ~= "function") then
        return false
    end
    local plan = self:getPlan(manager)
    if plan == nil then return false end
    self.state.backup, self.state.baseline = plan.backup, plan.baseline
    for period = 1, 12 do plan.history[period] = plan.replacement[period] end
    self.state.done = true
    self.state.syncPending = syncClients == true
    log("Corrected Liquid Lime starting price history once; original history will be retained in economy.xml. Selling and buying prices are unchanged.")
    self:syncHistory(manager)
    return true
end

function LiquidLimePriceHistory:installHook(owner, name, before, after)
    local original = owner[name]
    local generation = self.generation
    local wrapper = function(...)
        local active = self.enabled and self.generation == generation
        if active and before ~= nil then before(...) end
        local result = pack(original(...))
        if active and after ~= nil then after(...) end
        return unpackValues(result, 1, result.n)
    end
    owner[name] = wrapper
    self.hooks[#self.hooks + 1] = {owner = owner, name = name, original = original, wrapper = wrapper}
end

function LiquidLimePriceHistory:loadMap()
    self:deleteMap()
    self.generation = (self.generation or 0) + 1
    self.state = {done = false, ready = false, pending = false, retryTimer = 0}
    self.hooks = {}
    if EconomyManager == nil or FSBaseMission == nil
        or type(EconomyManager.loadFromXMLFile) ~= "function"
        or type(EconomyManager.saveToXMLFile) ~= "function"
        or type(EconomyManager.addSellingStation) ~= "function"
        or type(FSBaseMission.onFinishedLoading) ~= "function" then
        log("Price history correction unavailable for this game API; existing history is unchanged.")
        return
    end
    self.enabled = true
    self:installHook(EconomyManager, "loadFromXMLFile", nil, function(manager, xml, key)
        self:loadMarker(manager, xml, key)
    end)
    self:installHook(EconomyManager, "saveToXMLFile", nil, function(manager, xml, key)
        self:saveMarker(manager, xml, key)
    end)
    self:installHook(FSBaseMission, "onFinishedLoading", function(mission)
        local manager = mission.economyManager
        if self:isServer(manager) then
            self.state.ready = true
            self:tryApply(manager, false)
        end
    end)
    local onStationsChanged = function(manager)
        if self:isServer(manager) and not self.state.done then self.state.pending = true end
    end
    self:installHook(EconomyManager, "addSellingStation", nil, onStationsChanged)
    if type(EconomyManager.removeSellingStation) == "function" then
        self:installHook(EconomyManager, "removeSellingStation", nil, onStationsChanged)
    end
end

function LiquidLimePriceHistory:update(dt)
    local manager = g_currentMission ~= nil and g_currentMission.economyManager or nil
    if not self:isServer(manager) or not self.state.ready then return end
    if self.state.pending and not self.state.done then
        self.state.pending = false
        self:tryApply(manager, true)
    end
    if self.state.syncPending then
        self.state.retryTimer = self.state.retryTimer + (dt or 0)
        if self.state.retryTimer >= 1000 then
            self.state.retryTimer = 0
            self:syncHistory(manager)
        end
    end
end

function LiquidLimePriceHistory:deleteMap()
    self.enabled = false
    for _, hook in ipairs(self.hooks or {}) do
        if hook.owner[hook.name] == hook.wrapper then hook.owner[hook.name] = hook.original end
    end
    self.hooks = {}
    self.state = nil
end
