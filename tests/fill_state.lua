-- Run from the repository root: lua tests/fill_state.lua
-- Engine-independent regressions; these do not replace FS25/PF/Courseplay testing.
unpack = unpack or table.unpack
dofile("scripts/LiquidLime.lua")
dofile("scripts/PrecisionFarming.lua")
dofile("scripts/HelperAutoBuy.lua")

FillType = {UNKNOWN = 0, LIME = 1, LIQUIDLIME = 2, LIQUIDFERTILIZER = 3, HERBICIDE = 4}
SprayType = {LIME = 1}
LiquidLime.liquidLimeFillTypeIndex = FillType.LIQUIDLIME
LiquidLime.getLiquidLimeSprayTypeIndex = function() return 2 end
LiquidLime.getPrecisionFarmingFillSource = function(_, vehicle) return vehicle.source or vehicle, 1 end
LiquidLime.LogOnce = function() end
g_currentMission = {missionInfo = {helperBuyFertilizer = false}}

local function newVehicle(inherited)
    local methods = {
        getFillUnitFillType = function(self, index)
            return index == 1 and self.current or FillType.HERBICIDE
        end,
        getFillUnitLastValidFillType = function(self) return self.last end,
        getFillUnitFillLevel = function(self) return self.level end,
        getSprayerFillUnitIndex = function() return 1 end,
        getFillUnitSupportsFillType = function() return true end,
        getFillUnitAllowsFillType = function() return true end
    }
    local vehicle = {current = FillType.UNKNOWN, last = FillType.LIQUIDLIME, level = 10}
    if inherited then
        setmetatable(vehicle, {__index = methods})
    else
        for name, method in pairs(methods) do vehicle[name] = method end
    end
    return vehicle
end

local count = 0
local function test(name, callback)
    local ok, err = pcall(callback)
    if not ok then error(name .. ": " .. tostring(err)) end
    count = count + 1
    print("PASS " .. name)
end

for _, inherited in ipairs({false, true}) do
    test("overlapping wrappers restore getter (inherited=" .. tostring(inherited) .. ")", function()
        local vehicle = newVehicle(inherited)
        local original = vehicle.getFillUnitFillType
        local own = rawget(vehicle, "getFillUnitFillType")
        local state = LiquidLime:applyPrecisionFarmingLimeMapping(vehicle, {patchSourceFillType = true})
        -- A nested visual/third-party wrapper must unwind before the source wrapper.
        local inner = vehicle.getFillUnitFillType
        LiquidLime:storeTemporaryValue(state, vehicle, "getFillUnitFillType", function(...) return inner(...) end)
        LiquidLime:restorePrecisionFarmingLimeMapping(state)
        assert(vehicle.getFillUnitFillType == original)
        assert(rawget(vehicle, "getFillUnitFillType") == own)
        vehicle.current = FillType.LIQUIDFERTILIZER
        vehicle.level = 100
        assert(vehicle:getFillUnitFillType(1) == FillType.LIQUIDFERTILIZER)
        assert(not LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle))
        -- Model unload's type match: the reported material must debit the tank.
        local unloadedType = vehicle:getFillUnitFillType(1)
        if unloadedType == vehicle.current then vehicle.level = vehicle.level - 100 end
        assert(vehicle.level == 0)
        assert(FillType.LIME == 1 and SprayType.LIME == 1)
    end)
end

for _, level in ipairs({0, -1, false}) do
    test("empty/unknown quantity stays UNKNOWN (level=" .. tostring(level) .. ")", function()
        local vehicle = newVehicle()
        vehicle.level = level or nil
        local original = vehicle.getFillUnitFillType
        LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle,
            {patchSourceFillType = true, patchEffectFillType = true}, function()
                assert(vehicle:getFillUnitFillType(1) == FillType.UNKNOWN)
            end)
        assert(vehicle.getFillUnitFillType == original)
    end)
end

test("loaded UNKNOWN with lime history maps only the source unit", function()
    local vehicle = newVehicle()
    LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle, {patchSourceFillType = true}, function()
        assert(vehicle:getFillUnitFillType(1) == FillType.LIQUIDLIME)
        assert(vehicle:getFillUnitFillType(2) == FillType.HERBICIDE)
    end)
    assert(vehicle:getFillUnitFillType(1) == FillType.UNKNOWN)
end)

test("callback errors unwind nested mappings and inherited getters", function()
    local vehicle = newVehicle(true)
    local original = vehicle.getFillUnitFillType
    local ok = pcall(function()
        LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle,
            {patchSourceFillType = true, patchEffectFillType = true}, function()
                LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle,
                    {patchSourceFillType = true, patchEffectFillType = true}, function()
                        error("intentional callback failure")
                    end)
            end)
    end)
    assert(not ok)
    assert(vehicle.getFillUnitFillType == original)
    assert(rawget(vehicle, "getFillUnitFillType") == nil)
    assert(rawget(vehicle, "getFillUnitLastValidFillType") == nil)
    assert(FillType.LIME == 1 and SprayType.LIME == 1)
end)

test("attached source supplies lime without fabricating contents in empty sprayer", function()
    local vehicle, source = newVehicle(), newVehicle()
    vehicle.level = 0
    vehicle.source = source
    LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle,
        {patchSourceFillType = true, patchEffectFillType = true}, function()
            assert(source:getFillUnitFillType(1) == FillType.LIQUIDLIME)
            assert(vehicle:getFillUnitFillType(1) == FillType.UNKNOWN)
            assert(vehicle:getFillUnitLastValidFillType(1) == FillType.LIQUIDLIME)
        end)
    assert(source:getFillUnitFillType(1) == FillType.UNKNOWN)
end)

test("helper auto-buy retains history, respects setting and loaded fertilizer", function()
    local vehicle = newVehicle()
    vehicle.level = 0
    assert(not LiquidLime:shouldUseLiquidLimeExternalFill(vehicle, FillType.UNKNOWN))
    g_currentMission.missionInfo.helperBuyFertilizer = true
    assert(LiquidLime:shouldUseLiquidLimeExternalFill(vehicle, FillType.UNKNOWN))
    vehicle.current, vehicle.level = FillType.LIQUIDFERTILIZER, 100
    assert(not LiquidLime:shouldUseLiquidLimeExternalFill(vehicle, FillType.UNKNOWN))
    g_currentMission.missionInfo.helperBuyFertilizer = false
end)

test("known fertilizer is never remapped by source correction", function()
    local vehicle = newVehicle()
    vehicle.current = FillType.LIQUIDFERTILIZER
    LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle, {patchSourceFillType = true}, function()
        assert(vehicle:getFillUnitFillType(1) == FillType.LIQUIDFERTILIZER)
    end)
end)

print(string.format("%d regression cases passed", count))
