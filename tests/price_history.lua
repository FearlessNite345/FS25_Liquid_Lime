-- Engine-independent checks; run from the repository root with Lua 5.1+.
unpack = unpack or table.unpack
g_currentModDirectory = "/mods/FS25_Liquid_Lime/"
LiquidLime = {Log = function() end}
dofile("scripts/PriceHistory.lua")
local migration = LiquidLimePriceHistory
local count = 0
local factors = {1.05, 1.15, 1.10, 0.95, 0.90, 0.90, 1.05, 1.15, 1.10, 0.95, 0.90, 0.95}
local root = "economy.liquidLimePriceHistory"

local function equal(a, b)
    assert(math.abs(a - b) < 1e-10, tostring(a) .. " ~= " .. tostring(b))
end
local function copy(source)
    local result = {}
    for k, v in pairs(source) do result[k] = v end
    return result
end
local function xmlHandle()
    return {values = {}, writes = 0}
end
XMLFile = {wrap = function(handle)
    return {
        hasProperty = function(_, key)
            for k in pairs(handle.values) do
                if k == key or k:sub(1, #key + 1) == key .. "#" or k:sub(1, #key + 1) == key .. "." then return true end
            end
            return false
        end,
        getString = function(_, key)
            local value = handle.values[key]
            return value ~= nil and tostring(value) or nil
        end,
        setString = function(_, key, value) handle.values[key] = tostring(value); handle.writes = handle.writes + 1 end,
        setInt = function(_, key, value) handle.values[key] = tostring(value); handle.writes = handle.writes + 1 end,
        setFloat = function(_, key, value) handle.values[key] = string.format("%.17g", value); handle.writes = handle.writes + 1 end,
        delete = function() end
    }
end}

local function fixture(isServer)
    migration:deleteMap()
    local fillType = {index = 2, name = "LIQUIDLIME", pricePerLiter = 0.45,
        economy = {factors = copy(factors), history = {}, sychronizeData = true}}
    for p = 1, 12 do fillType.economy.history[p] = 0.45 * factors[p] end
    local otherHistory = {0.8, 0.9, 1.2}
    local calls = {load = 0, save = 0, finished = 0, add = 0, remove = 0, sync = {}}
    EconomyManager = {
        loadFromXMLFile = function(_, handle)
            calls.load = calls.load + 1
            if handle.loadedHistory ~= nil then
                for p = 1, 12 do fillType.economy.history[p] = handle.loadedHistory[p] end
            end
            return "loaded", nil, 12
        end,
        saveToXMLFile = function(_, handle)
            calls.save = calls.save + 1
            handle.loadedHistory = copy(fillType.economy.history)
            return "saved", nil, 7
        end,
        addSellingStation = function(self, station)
            calls.add = calls.add + 1
            self.sellingStations[#self.sellingStations + 1] = {station = station}
            return "added"
        end,
        removeSellingStation = function(self, station)
            calls.remove = calls.remove + 1
            for i, entry in ipairs(self.sellingStations) do
                if entry.station == station then table.remove(self.sellingStations, i); break end
            end
        end,
        sendPeriodFillTypeHistory = function(_, p)
            if calls.failSync then error("temporary sync failure") end
            calls.sync[#calls.sync + 1] = p
        end,
        getCostPerLiter = function() return 0.45 * 1.05 end,
        getPricePerLiter = function() return 0.45 * 1.05 end,
        updateFillTypeHistory = function() fillType.economy.history[1] = 0.237 end
    }
    FSBaseMission = {onFinishedLoading = function(mission)
        calls.finished = calls.finished + 1
        mission.isLoaded = true
        calls.historyAtFinished = copy(fillType.economy.history)
        return "finished", nil, 17
    end}
    local manager = setmetatable({sellingStations = {}}, {__index = EconomyManager})
    g_currentMission = {economyManager = manager, money = 123456,
        getIsServer = function() return isServer ~= false end}
    g_fillTypeManager = {getFillTypeByName = function(_, name)
        if name == "LIQUIDLIME" then return fillType end
    end}
    g_server = {}
    local originals = copy(EconomyManager)
    local originalFinished = FSBaseMission.onFinishedLoading
    migration:loadMap()
    local function station(path, price, accepted)
        return {acceptedFillTypes = {[accepted or 2] = true},
            owningPlaceable = {configFileName = path or "/mods/FS25_Liquid_Lime/placeables/LiquidLimeSellPoint/liquidLimeSellPoint.xml"},
            originalFillTypePrices = {[accepted or 2] = price or 0.225},
            fillTypePrices = {[accepted or 2] = 0.233}, priceMultipliers = {[accepted or 2] = 1},
            getEffectiveFillTypePrice = function() return 0.233 end}
    end
    return {fillType = fillType, manager = manager, calls = calls, station = station,
        otherHistory = otherHistory, originals = originals, originalFinished = originalFinished,
        finish = function() return FSBaseMission.onFinishedLoading(g_currentMission) end}
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err)) end
    count = count + 1
    print("PASS " .. name)
end

test("native seed correction preserves every pricing input and other goods", function()
    local f = fixture()
    local station = f.station()
    f.manager:addSellingStation(station)
    local history, oldHistory = f.fillType.economy.history, copy(f.fillType.economy.history)
    local a, b, c = f.finish()
    assert(a == "finished" and b == nil and c == 17)
    assert(f.fillType.economy.history == history and migration.state.done)
    for p = 1, 12 do
        equal(history[p], 0.225 * factors[p])
        equal(migration.state.backup[p], oldHistory[p])
        equal(f.calls.historyAtFinished[p], history[p])
        equal(f.fillType.economy.factors[p], factors[p])
    end
    equal(f.fillType.pricePerLiter, 0.45)
    equal(station.originalFillTypePrices[2], 0.225)
    equal(station.fillTypePrices[2], 0.233)
    equal(station:getEffectiveFillTypePrice(2), 0.233)
    equal(f.manager:getCostPerLiter(2), 0.4725)
    equal(f.manager:getPricePerLiter(2), 0.4725)
    assert(EconomyManager.getCostPerLiter == f.originals.getCostPerLiter)
    assert(EconomyManager.getPricePerLiter == f.originals.getPricePerLiter)
    assert(EconomyManager.updateFillTypeHistory == f.originals.updateFillTypeHistory)
    assert(g_currentMission.money == 123456 and #f.calls.sync == 0)
    assert(f.otherHistory[1] == 0.8 and f.otherHistory[2] == 0.9 and f.otherHistory[3] == 1.2)
    -- Same native difficulty multiplier is applied by the unchanged graph.
    for _, difficulty in ipairs({1, 1.8, 3}) do
        equal(math.min(unpack(history)) * 1000 * difficulty, 202.5 * difficulty)
        equal(math.max(unpack(history)) * 1000 * difficulty, 258.75 * difficulty)
    end
end)

test("existing genuine samples are backed up, not heuristically halved", function()
    local f = fixture()
    local xml = xmlHandle()
    xml.loadedHistory = {0.233, 0.257, 0.218, 0.192, 0.199, 0.222, 0.205, 0.25, 0.3, 0.21, 0.198, 0.209}
    local a, b, c = f.manager:loadFromXMLFile(xml, "economy")
    assert(a == "loaded" and b == nil and c == 12)
    f.manager:addSellingStation(f.station())
    f.finish()
    for p = 1, 12 do equal(migration.state.backup[p], xml.loadedHistory[p]) end
    f.manager:updateFillTypeHistory()
    equal(f.fillType.economy.history[1], 0.237)
    f.finish()
    equal(f.fillType.economy.history[1], 0.237)
end)

test("save reload roundtrip keeps marker, original backup and later history", function()
    local f = fixture()
    f.manager:addSellingStation(f.station())
    local old = copy(f.fillType.economy.history)
    f.finish()
    f.manager:updateFillTypeHistory()
    local xml = xmlHandle()
    local a, b, c = f.manager:saveToXMLFile(xml, "economy")
    assert(a == "saved" and b == nil and c == 7 and xml.values[root .. "#version"] == "1")
    for p = 1, 12 do equal(tonumber(xml.values[root .. ".backup.period(" .. (p - 1) .. ")"]), old[p]) end
    local savedValues = copy(xml.values)
    f = fixture()
    f.manager:loadFromXMLFile(xml, "economy")
    f.manager:addSellingStation(f.station())
    f.finish()
    equal(f.fillType.economy.history[1], 0.237)
    local second = xmlHandle()
    f.manager:saveToXMLFile(second, "economy")
    for key, value in pairs(savedValues) do assert(second.values[key] == value) end
end)

for _, version in ipairs({"2", "broken", ""}) do
    test("existing unsupported marker never resets history: " .. version, function()
        local f, xml = fixture(), xmlHandle()
        xml.values[root .. "#version"] = version
        xml.values[root .. ".backup.period(0)"] = "0.123456789"
        f.manager:loadFromXMLFile(xml, "economy")
        f.fillType.economy.history[1] = 0.123
        f.manager:addSellingStation(f.station()); f.finish()
        equal(f.fillType.economy.history[1], 0.123)
        local saved = xmlHandle(); f.manager:saveToXMLFile(saved, "economy")
        assert(saved.values[root .. "#version"] == version)
        assert(saved.values[root .. ".backup.period(0)"] == "0.123456789")
    end)
end

test("missing marker version is retained as blocked, never reset again", function()
    local f, xml = fixture(), xmlHandle()
    xml.values[root .. ".backup.period(0)"] = "malformed"
    f.manager:loadFromXMLFile(xml, "economy")
    local before = f.fillType.economy.history[1]
    f.manager:addSellingStation(f.station()); f.finish()
    equal(f.fillType.economy.history[1], before)
    local saved = xmlHandle(); f.manager:saveToXMLFile(saved, "economy")
    assert(saved.values[root .. "#version"] == "invalid")
    assert(saved.values[root .. ".backup.period(0)"] == "malformed")
end)

test("version-one marker with missing backup fails closed", function()
    local f, xml = fixture(), xmlHandle()
    xml.values[root .. "#version"] = "1"
    f.manager:loadFromXMLFile(xml, "economy")
    f.fillType.economy.history[1] = 0.199
    f.manager:addSellingStation(f.station()); f.finish()
    equal(f.fillType.economy.history[1], 0.199)
    assert(migration.state.backup == nil)
    local saved = xmlHandle(); f.manager:saveToXMLFile(saved, "economy")
    assert(saved.values[root .. "#version"] == "1")
end)

test("client never changes history or writes migration metadata", function()
    local f, xml = fixture(false), xmlHandle()
    f.manager:addSellingStation(f.station()); f.finish(); migration:update(1001)
    for p = 1, 12 do equal(f.fillType.economy.history[p], 0.45 * factors[p]) end
    f.manager:saveToXMLFile(xml, "economy")
    assert(not migration.state.done and xml.writes == 0 and #f.calls.sync == 0)
end)

test("multiple own stations with consistent bases work on normalized paths", function()
    local f = fixture()
    f.manager:addSellingStation(f.station())
    f.manager:addSellingStation(f.station("\\mods\\FS25_Liquid_Lime\\placeables\\LiquidLimeSellPoint\\liquidLimeSellPoint.xml"))
    f.manager:addSellingStation(f.station("foreign.xml", 0.8, 1))
    f.finish(); assert(migration.state.done)
end)

for _, bad in ipairs({"foreign", "hidden", "missingOwner", "missingPrice", "mismatchedPrice", "nan", "infinite", "zero"}) do
    test("ambiguous accepting station fails closed: " .. bad, function()
        local f = fixture()
        f.manager:addSellingStation(f.station())
        local s = f.station()
        if bad == "foreign" or bad == "hidden" then s.owningPlaceable.configFileName = "map/sellingStation.xml"; s.hideFromPricesMenu = true end
        if bad == "missingOwner" then s.owningPlaceable = nil end
        if bad == "missingPrice" then s.originalFillTypePrices = nil end
        if bad == "mismatchedPrice" then s.originalFillTypePrices[2] = 0.3 end
        if bad == "nan" then s.originalFillTypePrices[2] = 0 / 0 end
        if bad == "infinite" then s.originalFillTypePrices[2] = math.huge end
        if bad == "zero" then s.originalFillTypePrices[2] = 0 end
        f.manager:addSellingStation(s); f.finish(); migration:update(1001)
        assert(not migration.state.done and migration.state.backup == nil)
        for p = 1, 12 do equal(f.fillType.economy.history[p], 0.45 * factors[p]) end
        local xml = xmlHandle(); f.manager:saveToXMLFile(xml, "economy"); assert(xml.writes == 0)
    end)
end

test("missing station defers until placement completes and syncs all months once", function()
    local f = fixture(); f.finish(); assert(not migration.state.done)
    local s = f.station(); local owner = s.owningPlaceable; s.owningPlaceable = nil
    f.manager:addSellingStation(s)
    assert(not migration.state.done)
    s.owningPlaceable = owner
    migration:update(16)
    assert(migration.state.done and #f.calls.sync == 12)
    for p = 1, 12 do assert(f.calls.sync[p] == p) end
    migration:update(1001); assert(#f.calls.sync == 12)
end)

test("removing a foreign seller permits deferred correction", function()
    local f = fixture()
    local foreign = f.station("foreign.xml")
    f.manager:addSellingStation(f.station()); f.manager:addSellingStation(foreign)
    f.finish(); assert(not migration.state.done)
    f.manager:removeSellingStation(foreign); migration:update(16)
    assert(migration.state.done and #f.calls.sync == 12)
end)

test("late correction without a sync route leaves history intact", function()
    local f = fixture(); f.finish(); g_server = nil
    f.manager:addSellingStation(f.station()); migration:update(16)
    assert(not migration.state.done)
    equal(f.fillType.economy.history[1], 0.45 * factors[1])
end)

test("temporary client sync failure retries without repeating correction", function()
    local f = fixture(); f.finish(); f.calls.failSync = true
    f.manager:addSellingStation(f.station()); migration:update(16)
    assert(migration.state.done and migration.state.syncPending)
    local backup = migration.state.backup
    f.manager:updateFillTypeHistory()
    f.calls.failSync = false; migration:update(1001)
    assert(#f.calls.sync == 12 and not migration.state.syncPending)
    assert(migration.state.backup == backup); equal(f.fillType.economy.history[1], 0.237)
end)

for _, bad in ipairs({"factor", "history"}) do
    test("malformed twelve-month input fails closed: " .. bad, function()
        local f = fixture(); f.manager:addSellingStation(f.station())
        if bad == "factor" then f.fillType.economy.factors[7] = nil else f.fillType.economy.history[7] = -1 end
        f.finish(); assert(not migration.state.done and migration.state.backup == nil)
    end)
end

test("delete reload restores hooks and resets state for a different save", function()
    local f = fixture(); f.manager:addSellingStation(f.station()); f.finish()
    migration:deleteMap()
    assert(EconomyManager.loadFromXMLFile == f.originals.loadFromXMLFile)
    assert(EconomyManager.saveToXMLFile == f.originals.saveToXMLFile)
    assert(FSBaseMission.onFinishedLoading == f.originalFinished)
    assert(migration.state == nil)
    migration:loadMap(); assert(not migration.state.done)
    f.fillType.economy.history[1] = 0.99
    f.finish(); equal(migration.state.backup[1], 0.99)
end)

test("later third-party wrapper survives unload and old generation stays inert", function()
    local f = fixture()
    local oldWrapper = EconomyManager.saveToXMLFile
    local outer = function(...) return oldWrapper(...) end
    EconomyManager.saveToXMLFile = outer
    migration:deleteMap(); assert(EconomyManager.saveToXMLFile == outer)
    migration:loadMap(); f.manager:addSellingStation(f.station()); f.finish()
    local xml = xmlHandle(); f.manager:saveToXMLFile(xml, "economy")
    assert(f.calls.save == 1 and xml.writes == 14)
end)

test("missing game hook leaves native behavior untouched", function()
    local f = fixture(); migration:deleteMap(); FSBaseMission.onFinishedLoading = nil
    migration:loadMap()
    assert(not migration.enabled and EconomyManager.loadFromXMLFile == f.originals.loadFromXMLFile)
end)

test("disabled native history synchronization fails closed", function()
    local f = fixture(); f.fillType.economy.sychronizeData = false
    f.manager:addSellingStation(f.station()); f.finish()
    assert(not migration.state.done)
    equal(f.fillType.economy.history[1], 0.45 * factors[1])
end)

test("original callback errors are propagated before marker is written", function()
    local f = fixture(); migration:deleteMap()
    EconomyManager.saveToXMLFile = function() error("save failed") end
    migration:loadMap(); f.manager:addSellingStation(f.station()); f.finish()
    local xml = xmlHandle()
    local ok, err = pcall(f.manager.saveToXMLFile, f.manager, xml, "economy")
    assert(not ok and tostring(err):find("save failed", 1, true))
    assert(xml.writes == 0 and migration.state.backup ~= nil)
end)

migration:deleteMap()
print(string.format("%d price-history cases passed", count))
