-- Helper and contract auto-buy support for Liquid Lime.

function LiquidLime:rememberHelperFillPatchedFunction(func)
    if func ~= nil then
        LiquidLime.helperFillPatchedFunctionSet[func] = true
    end
end

function LiquidLime:isHelperFillFunctionAlreadyPatched(func)
    return func ~= nil and LiquidLime.helperFillPatchedFunctionSet[func] == true
end

function LiquidLime:patchHelperExternalFillTarget(target, createPatchedFunction)
    if target == nil or target.getExternalFill == nil then
        return false
    end

    local currentFunction = target.getExternalFill

    if LiquidLime:isHelperFillFunctionAlreadyPatched(currentFunction) then
        return false
    end

    local patchedFunction = createPatchedFunction(currentFunction)

    LiquidLime.helperFillCopyPatchRecords[target] = {
        original = currentFunction,
        patched = patchedFunction
    }

    LiquidLime:rememberHelperFillPatchedFunction(patchedFunction)
    target.getExternalFill = patchedFunction

    return true
end

function LiquidLime:patchHelperExternalFillCopies(createPatchedFunction)
    local patchedTypeCount = 0
    local patchedVehicleCount = 0

    if g_vehicleTypeManager ~= nil and g_vehicleTypeManager.types ~= nil then
        for _, vehicleType in pairs(g_vehicleTypeManager.types) do
            if vehicleType ~= nil
                and vehicleType.functions ~= nil
                and vehicleType.specializations ~= nil
                and Sprayer ~= nil
                and SpecializationUtil ~= nil
                and SpecializationUtil.hasSpecialization(Sprayer, vehicleType.specializations) then
                if LiquidLime:patchHelperExternalFillTarget(vehicleType.functions, createPatchedFunction) then
                    patchedTypeCount = patchedTypeCount + 1
                end
            end
        end
    end

    local vehicleSystem = g_currentMission ~= nil and g_currentMission.vehicleSystem or nil

    if vehicleSystem ~= nil and vehicleSystem.vehicles ~= nil then
        for _, vehicle in pairs(vehicleSystem.vehicles) do
            if vehicle ~= nil
                and vehicle.specializations ~= nil
                and Sprayer ~= nil
                and SpecializationUtil ~= nil
                and SpecializationUtil.hasSpecialization(Sprayer, vehicle.specializations) then
                if LiquidLime:patchHelperExternalFillTarget(vehicle, createPatchedFunction) then
                    patchedVehicleCount = patchedVehicleCount + 1
                end
            end
        end
    end

    if (patchedTypeCount > 0 or patchedVehicleCount > 0) and not LiquidLime.helperFillCopyPatchLogged then
        LiquidLime:Log(string.format(
            "Helper auto-buy copied function patch applied for getExternalFill (%d vehicle types, %d loaded vehicles).",
            patchedTypeCount,
            patchedVehicleCount
        ))
        LiquidLime.helperFillCopyPatchLogged = true
    end
end

function LiquidLime:restoreHelperExternalFillCopyPatches()
    if LiquidLime.helperFillCopyPatchRecords == nil then
        return
    end

    for target, record in pairs(LiquidLime.helperFillCopyPatchRecords) do
        if target ~= nil and record ~= nil and target.getExternalFill == record.patched then
            target.getExternalFill = record.original
        end
    end
end

function LiquidLime:patchHelperExternalFill()
    if Sprayer == nil or Sprayer.getExternalFill == nil then
        return
    end

    local function createPatchedGetExternalFill(originalGetExternalFill)
        return function(vehicle, fillType, dt, ...)
            if LiquidLime:shouldUseLiquidLimeExternalFill(vehicle, fillType) then
                return LiquidLime:getLiquidLimeExternalFill(vehicle, dt)
            end

            return originalGetExternalFill(vehicle, fillType, dt, ...)
        end
    end

    if LiquidLime.helperFillPatchInstalled
        and Sprayer.getExternalFill == LiquidLime.patchedSprayerGetExternalFill then
        LiquidLime:patchHelperExternalFillCopies(createPatchedGetExternalFill)
        return
    end

    local originalGetExternalFill = Sprayer.getExternalFill
    local patchedGetExternalFill = createPatchedGetExternalFill(originalGetExternalFill)

    LiquidLime.originalSprayerGetExternalFill = originalGetExternalFill
    LiquidLime.patchedSprayerGetExternalFill = patchedGetExternalFill
    LiquidLime:rememberHelperFillPatchedFunction(patchedGetExternalFill)
    Sprayer.getExternalFill = patchedGetExternalFill
    LiquidLime:patchHelperExternalFillCopies(createPatchedGetExternalFill)
    LiquidLime.helperFillPatchInstalled = true
    LiquidLime:Log("Helper auto-buy patch applied for LIQUIDLIME.")
end

function LiquidLime:shouldUseLiquidLimeExternalFill(vehicle, fillType)
    if g_currentMission == nil
        or g_currentMission.missionInfo == nil
        or not g_currentMission.missionInfo.helperBuyFertilizer then
        return false
    end

    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    if liquidLimeFillType == nil then
        return false
    end

    if fillType == liquidLimeFillType then
        return true
    end

    if FillType == nil or fillType ~= FillType.UNKNOWN then
        return false
    end

    if LiquidLime:isLiquidLimeFillType(LiquidLime:getPrecisionFarmingWorkAreaFillType(vehicle))
        or LiquidLime:isLiquidLimeFillType(LiquidLime:getPrecisionFarmingSourceFillType(vehicle))
        or LiquidLime:isLiquidLimeFillType(LiquidLime:getPrecisionFarmingSprayerSourceFillType(vehicle)) then
        return true
    end

    if vehicle.getSprayerFillUnitIndex == nil then
        return false
    end

    local fillUnitIndex = vehicle:getSprayerFillUnitIndex()

    if vehicle.getFillUnitSupportsFillType == nil
        or not vehicle:getFillUnitSupportsFillType(fillUnitIndex, liquidLimeFillType) then
        return false
    end

    if vehicle.getFillUnitAllowsFillType ~= nil
        and not vehicle:getFillUnitAllowsFillType(fillUnitIndex, liquidLimeFillType) then
        return false
    end

    if vehicle.getFillUnitLastValidFillType ~= nil
        and vehicle:getFillUnitLastValidFillType(fillUnitIndex) == liquidLimeFillType then
        return true
    end

    local supportedFillTypes = nil
    if vehicle.getFillUnitSupportedFillTypes ~= nil then
        supportedFillTypes = vehicle:getFillUnitSupportedFillTypes(fillUnitIndex)
    end

    if supportedFillTypes == nil then
        return false
    end

    local hasOtherHelperBuyFillType = false

    if FillType.LIME ~= nil and FillType.LIME ~= liquidLimeFillType and supportedFillTypes[FillType.LIME] then
        hasOtherHelperBuyFillType = true
    end

    if FillType.FERTILIZER ~= nil and supportedFillTypes[FillType.FERTILIZER] then
        hasOtherHelperBuyFillType = true
    end

    if FillType.LIQUIDFERTILIZER ~= nil and supportedFillTypes[FillType.LIQUIDFERTILIZER] then
        hasOtherHelperBuyFillType = true
    end

    if FillType.HERBICIDE ~= nil and supportedFillTypes[FillType.HERBICIDE] then
        hasOtherHelperBuyFillType = true
    end

    return not hasOtherHelperBuyFillType
end

function LiquidLime:getLiquidLimeExternalFill(vehicle, dt)
    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    if liquidLimeFillType == nil or vehicle.getSprayerUsage == nil then
        return FillType.UNKNOWN, 0
    end

    local usage = vehicle:getSprayerUsage(liquidLimeFillType, dt)

    if vehicle.isServer and g_currentMission ~= nil and usage > 0 then
        local pricePerLiter = nil

        if g_currentMission.economyManager ~= nil and g_currentMission.economyManager.getCostPerLiter ~= nil then
            pricePerLiter = g_currentMission.economyManager:getCostPerLiter(liquidLimeFillType, false)
        end

        if pricePerLiter ~= nil then
            local farmId = vehicle.getActiveFarm ~= nil and vehicle:getActiveFarm() or nil
            local statsFarmId = vehicle.getLastTouchedFarmlandFarmId ~= nil and vehicle:getLastTouchedFarmlandFarmId() or farmId
            local price = usage * pricePerLiter * 1.5

            if g_farmManager ~= nil and statsFarmId ~= nil then
                g_farmManager:updateFarmStats(statsFarmId, "expenses", price)
            end

            if g_currentMission.addMoney ~= nil then
                g_currentMission:addMoney(-price, farmId, MoneyType.PURCHASE_FERTILIZER)
            end
        end
    end

    return liquidLimeFillType, usage
end
