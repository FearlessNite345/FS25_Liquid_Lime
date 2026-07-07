-- Precision Farming compatibility for Liquid Lime.

local PRECISION_FARMING_MOD_NAME = "FS25_precisionFarming"

function LiquidLime:getGlobalEnvironment()
    if LiquidLime.globalEnvironment ~= nil then
        return LiquidLime.globalEnvironment
    end

    local environment = _G
    local metaTable = getmetatable(_G)

    if metaTable ~= nil and type(metaTable.__index) == "table" then
        environment = metaTable.__index
    end

    LiquidLime.globalEnvironment = environment

    return environment
end

function LiquidLime:getPrecisionFarmingEnvironment()
    if LiquidLime.precisionFarmingEnvironment ~= nil then
        return LiquidLime.precisionFarmingEnvironment
    end

    local environment = nil
    local globalEnvironment = LiquidLime:getGlobalEnvironment()

    if g_thGlobalEnv ~= nil then
        local modEnvironment = g_thGlobalEnv[PRECISION_FARMING_MOD_NAME]

        if modEnvironment ~= nil then
            environment = modEnvironment._G or modEnvironment
        end
    end

    if environment == nil and globalEnvironment ~= nil then
        local modEnvironment = globalEnvironment[PRECISION_FARMING_MOD_NAME]

        if modEnvironment ~= nil then
            environment = modEnvironment._G or modEnvironment
        end
    end

    if environment == nil and g_modManager ~= nil then
        local modData = nil

        if g_modManager.getModByName ~= nil then
            modData = g_modManager:getModByName(PRECISION_FARMING_MOD_NAME)
        end

        if modData == nil and g_modManager.nameToMod ~= nil then
            modData = g_modManager.nameToMod[PRECISION_FARMING_MOD_NAME]
                or g_modManager.nameToMod[string.upper(PRECISION_FARMING_MOD_NAME)]
                or g_modManager.nameToMod[string.lower(PRECISION_FARMING_MOD_NAME)]
        end

        if modData ~= nil then
            environment = modData.environment or modData._G
        end
    end

    if environment == nil and PrecisionFarming ~= nil then
        environment = _G
    end

    if environment == nil and globalEnvironment ~= nil and globalEnvironment.PrecisionFarming ~= nil then
        environment = globalEnvironment
    end

    if environment ~= nil and environment.PrecisionFarming ~= nil then
        LiquidLime.precisionFarmingEnvironment = environment
        return environment
    end

    return nil
end

function LiquidLime:getPrecisionFarmingClass(className)
    local environment = LiquidLime:getPrecisionFarmingEnvironment()

    if environment ~= nil then
        return environment[className]
    end

    local globalEnvironment = LiquidLime:getGlobalEnvironment()

    if globalEnvironment ~= nil and globalEnvironment[className] ~= nil then
        return globalEnvironment[className]
    end

    return _G[className]
end

function LiquidLime:getPrecisionFarmingExtendedSprayer()
    return LiquidLime:getPrecisionFarmingClass("ExtendedSprayer")
end

function LiquidLime:getPrecisionFarmingHUDExtension()
    return LiquidLime:getPrecisionFarmingClass("ExtendedSprayerHUDExtension")
end

function LiquidLime:rememberPrecisionFarmingPatchedFunction(func)
    if func ~= nil then
        LiquidLime.precisionFarmingPatchedFunctionSet[func] = true
    end
end

function LiquidLime:isPrecisionFarmingFunctionAlreadyPatched(func)
    return func ~= nil and LiquidLime.precisionFarmingPatchedFunctionSet[func] == true
end

function LiquidLime:patchPrecisionFarmingFunctionTarget(functionName, target, createPatchedFunction)
    if target == nil or target[functionName] == nil then
        return false
    end

    local currentFunction = target[functionName]

    if LiquidLime:isPrecisionFarmingFunctionAlreadyPatched(currentFunction) then
        return false
    end

    local functionRecords = LiquidLime.precisionFarmingFunctionCopyPatchRecords[functionName]

    if functionRecords == nil then
        functionRecords = {}
        LiquidLime.precisionFarmingFunctionCopyPatchRecords[functionName] = functionRecords
    end

    local patchedFunction = createPatchedFunction(currentFunction)

    functionRecords[target] = {
        original = currentFunction,
        patched = patchedFunction
    }

    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedFunction)
    target[functionName] = patchedFunction

    return true
end

function LiquidLime:patchPrecisionFarmingFunctionCopies(functionName, ExtendedSprayer, createPatchedFunction, createCopiedPatchedFunction)
    local patchedTypeCount = 0
    local patchedVehicleCount = 0
    local createTargetPatchedFunction = createCopiedPatchedFunction or createPatchedFunction

    if g_vehicleTypeManager ~= nil and g_vehicleTypeManager.types ~= nil then
        for _, vehicleType in pairs(g_vehicleTypeManager.types) do
            if vehicleType ~= nil
                and vehicleType.functions ~= nil
                and vehicleType.specializations ~= nil
                and SpecializationUtil ~= nil
                and SpecializationUtil.hasSpecialization(ExtendedSprayer, vehicleType.specializations) then
                if LiquidLime:patchPrecisionFarmingFunctionTarget(functionName, vehicleType.functions, createTargetPatchedFunction) then
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
                and SpecializationUtil ~= nil
                and SpecializationUtil.hasSpecialization(ExtendedSprayer, vehicle.specializations) then
                if LiquidLime:patchPrecisionFarmingFunctionTarget(functionName, vehicle, createTargetPatchedFunction) then
                    patchedVehicleCount = patchedVehicleCount + 1
                end
            end
        end
    end

    if (patchedTypeCount > 0 or patchedVehicleCount > 0)
        and not LiquidLime.precisionFarmingFunctionCopyPatchLog[functionName] then
        LiquidLime:Log(string.format(
            "Precision Farming copied function patch applied for %s (%d vehicle types, %d loaded vehicles).",
            functionName,
            patchedTypeCount,
            patchedVehicleCount
        ))
        LiquidLime.precisionFarmingFunctionCopyPatchLog[functionName] = true
    end
end

function LiquidLime:restorePrecisionFarmingFunctionCopyPatches()
    if LiquidLime.precisionFarmingFunctionCopyPatchRecords == nil then
        return
    end

    for functionName, functionRecords in pairs(LiquidLime.precisionFarmingFunctionCopyPatchRecords) do
        for target, record in pairs(functionRecords) do
            if target ~= nil and record ~= nil and target[functionName] == record.patched then
                target[functionName] = record.original
            end
        end
    end
end

function LiquidLime:storeTemporaryValue(state, target, key, value)
    if state == nil or target == nil or key == nil then
        return
    end

    table.insert(state.values, {
        target = target,
        key = key,
        value = rawget(target, key),
        hadOwnValue = rawget(target, key) ~= nil
    })

    target[key] = value
end

function LiquidLime:restorePrecisionFarmingLimeMapping(state)
    if state == nil then
        return
    end

    if state.pHMap ~= nil and state.pHMapUsagePatched then
        if state.pHMapHadOwnUsageFunction then
            state.pHMap.getLimeUsageByStateChange = state.pHMapOwnUsageFunction
        else
            state.pHMap.getLimeUsageByStateChange = nil
        end
    end

    if state.sourceVehicle ~= nil and state.sourceFillTypePatched then
        if state.sourceHadOwnFillTypeFunction then
            state.sourceVehicle.getFillUnitFillType = state.sourceOwnFillTypeFunction
        else
            state.sourceVehicle.getFillUnitFillType = nil
        end
    end

    for i = #state.values, 1, -1 do
        local valueState = state.values[i]

        if valueState.target ~= nil and valueState.key ~= nil then
            if valueState.hadOwnValue then
                valueState.target[valueState.key] = valueState.value
            else
                valueState.target[valueState.key] = nil
            end
        end
    end
end

function LiquidLime:runWithPrecisionFarmingLimeMapping(vehicle, options, callback, ...)
    local state = LiquidLime:applyPrecisionFarmingLimeMapping(vehicle, options)
    local results = {pcall(callback, ...)}

    LiquidLime:restorePrecisionFarmingLimeMapping(state)

    if not results[1] then
        error(results[2])
    end

    return unpack(results, 2)
end

function LiquidLime:applyPrecisionFarmingLimeMapping(vehicle, options)
    options = options or {}

    local state = {
        values = {}
    }

    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    if liquidLimeFillType == nil then
        return state
    end

    if FillType ~= nil and FillType.LIME ~= nil then
        LiquidLime:storeTemporaryValue(state, FillType, "LIME", liquidLimeFillType)
    end

    local liquidLimeSprayType = LiquidLime:getLiquidLimeSprayTypeIndex()

    if SprayType ~= nil and SprayType.LIME ~= nil and liquidLimeSprayType ~= nil then
        LiquidLime:storeTemporaryValue(state, SprayType, "LIME", liquidLimeSprayType)
    end

    if options.patchSourceFillType then
        LiquidLime:patchPrecisionFarmingSourceFillType(state, vehicle, liquidLimeFillType)
    end

    if options.patchEffectFillType then
        LiquidLime:patchPrecisionFarmingEffectFillType(state, vehicle, liquidLimeFillType)
    end

    if options.setSprayerFlags then
        LiquidLime:applyPrecisionFarmingSprayerFlags(state, vehicle)
    end

    if options.forceLiming then
        LiquidLime:applyPrecisionFarmingLimingMode(state, vehicle)
    end

    if options.scalePHUsage then
        LiquidLime:patchPrecisionFarmingPHUsage(state, vehicle)
    end

    if options.hud ~= nil then
        LiquidLime:patchPrecisionFarmingHudHeadline(state, options.hud)
    end

    return state
end

function LiquidLime:patchPrecisionFarmingSourceFillType(state, vehicle, liquidLimeFillType)
    local sourceVehicle, fillUnitIndex = LiquidLime:getPrecisionFarmingFillSource(vehicle)

    if sourceVehicle == nil
        or fillUnitIndex == nil
        or sourceVehicle.getFillUnitFillType == nil
        or sourceVehicle.getFillUnitLastValidFillType == nil then
        return
    end

    local currentFillType = sourceVehicle:getFillUnitFillType(fillUnitIndex)
    local lastValidFillType = sourceVehicle:getFillUnitLastValidFillType(fillUnitIndex)

    if FillType == nil
        or currentFillType ~= FillType.UNKNOWN
        or lastValidFillType ~= liquidLimeFillType then
        return
    end

    local originalGetFillUnitFillType = sourceVehicle.getFillUnitFillType

    state.sourceVehicle = sourceVehicle
    state.sourceFillTypePatched = true
    state.sourceHadOwnFillTypeFunction = rawget(sourceVehicle, "getFillUnitFillType") ~= nil
    state.sourceOwnFillTypeFunction = rawget(sourceVehicle, "getFillUnitFillType")

    sourceVehicle.getFillUnitFillType = function(vehicleObject, requestedFillUnitIndex, ...)
        if requestedFillUnitIndex == fillUnitIndex then
            return liquidLimeFillType
        end

        return originalGetFillUnitFillType(vehicleObject, requestedFillUnitIndex, ...)
    end
end

function LiquidLime:patchPrecisionFarmingEffectFillType(state, vehicle, liquidLimeFillType)
    if vehicle == nil or vehicle.getSprayerFillUnitIndex == nil then
        return
    end

    local fillUnitIndex = vehicle:getSprayerFillUnitIndex()

    if fillUnitIndex == nil then
        return
    end

    local function patchFillUnitFunction(functionName)
        local originalFunction = vehicle[functionName]

        if originalFunction == nil then
            return
        end

        LiquidLime:storeTemporaryValue(state, vehicle, functionName, function(vehicleObject, requestedFillUnitIndex, ...)
            if requestedFillUnitIndex == fillUnitIndex then
                return liquidLimeFillType
            end

            return originalFunction(vehicleObject, requestedFillUnitIndex, ...)
        end)
    end

    patchFillUnitFunction("getFillUnitFillType")
    patchFillUnitFunction("getFillUnitLastValidFillType")
end

function LiquidLime:applyPrecisionFarmingSprayerFlags(state, vehicle)
    if vehicle == nil then
        return
    end

    local sprayerSpec = vehicle.spec_sprayer

    if sprayerSpec ~= nil then
        LiquidLime:storeTemporaryValue(state, sprayerSpec, "isFertilizerSprayer", true)
        LiquidLime:storeTemporaryValue(state, sprayerSpec, "isManureSpreader", false)
        LiquidLime:storeTemporaryValue(state, sprayerSpec, "isSlurryTanker", false)
    end

    local precisionFarmingSpec = LiquidLime:getPrecisionFarmingSpec(vehicle)

    if precisionFarmingSpec ~= nil then
        LiquidLime:storeTemporaryValue(state, precisionFarmingSpec, "isSolidFertilizerSprayer", true)
        LiquidLime:storeTemporaryValue(state, precisionFarmingSpec, "isLiquidFertilizerSprayer", true)
        LiquidLime:storeTemporaryValue(state, precisionFarmingSpec, "isManureSpreader", false)
        LiquidLime:storeTemporaryValue(state, precisionFarmingSpec, "isSlurryTanker", false)
    end
end

function LiquidLime:applyPrecisionFarmingLimingMode(state, vehicle)
    local precisionFarmingSpec = LiquidLime:getPrecisionFarmingSpec(vehicle)

    if precisionFarmingSpec == nil then
        return
    end

    LiquidLime:storeTemporaryValue(state, precisionFarmingSpec, "isLiming", true)
    LiquidLime:storeTemporaryValue(state, precisionFarmingSpec, "isFertilizing", false)
end

function LiquidLime:patchPrecisionFarmingPHUsage(state, vehicle)
    local precisionFarmingSpec = LiquidLime:getPrecisionFarmingSpec(vehicle)
    local pHMap = precisionFarmingSpec ~= nil and precisionFarmingSpec.pHMap or nil

    if pHMap == nil or pHMap.getLimeUsageByStateChange == nil then
        return
    end

    local usageFactor = LiquidLime:getLiquidLimeUsageFactor()

    if usageFactor == nil or usageFactor <= 0 or usageFactor == 1 then
        return
    end

    local originalGetLimeUsageByStateChange = pHMap.getLimeUsageByStateChange

    state.pHMap = pHMap
    state.pHMapUsagePatched = true
    state.pHMapHadOwnUsageFunction = rawget(pHMap, "getLimeUsageByStateChange") ~= nil
    state.pHMapOwnUsageFunction = rawget(pHMap, "getLimeUsageByStateChange")

    pHMap.getLimeUsageByStateChange = function(map, ...)
        local results = {originalGetLimeUsageByStateChange(map, ...)}

        if type(results[1]) == "number" then
            results[1] = results[1] * usageFactor
        end

        return unpack(results)
    end
end

function LiquidLime:patchPrecisionFarmingHudHeadline(state, hud)
    if hud == nil or hud.texts == nil or hud.texts.headline_ph_lime == nil then
        return
    end

    local title = LiquidLime:getLiquidLimeApplicationTitle()

    if title == nil or title == "" then
        return
    end

    local originalHeadline = hud.texts.headline_ph_lime

    if string.find(originalHeadline, "%%s") ~= nil then
        LiquidLime:storeTemporaryValue(state, hud.texts, "headline_ph_lime", string.gsub(originalHeadline, "%%s", title))
        return
    end

    local headlinePrefix = originalHeadline
    local separatorStart = string.find(originalHeadline, " - ", 1, true)

    if separatorStart ~= nil then
        headlinePrefix = string.sub(originalHeadline, 1, separatorStart - 1)
    end

    if headlinePrefix == nil or headlinePrefix == "" then
        headlinePrefix = "pH Value"
    end

    LiquidLime:storeTemporaryValue(state, hud.texts, "headline_ph_lime", string.format("%s - %s", headlinePrefix, title))
end

function LiquidLime:getPrecisionFarmingSpec(vehicle)
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if vehicle == nil or ExtendedSprayer == nil or ExtendedSprayer.SPEC_TABLE_NAME == nil then
        return nil
    end

    return vehicle[ExtendedSprayer.SPEC_TABLE_NAME]
end

function LiquidLime:getPrecisionFarmingFillSource(vehicle)
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if vehicle == nil or ExtendedSprayer == nil or ExtendedSprayer.getFillTypeSourceVehicle == nil then
        return nil, nil
    end

    return ExtendedSprayer.getFillTypeSourceVehicle(vehicle)
end

function LiquidLime:isKnownFillType(fillType)
    return fillType ~= nil and (FillType == nil or fillType ~= FillType.UNKNOWN)
end

function LiquidLime:getFillUnitFillContext(sourceVehicle, fillUnitIndex, sourceName)
    if sourceVehicle == nil or fillUnitIndex == nil then
        return nil
    end

    local context = {
        sourceName = sourceName,
        sourceVehicle = sourceVehicle,
        fillUnitIndex = fillUnitIndex,
        currentFillType = nil,
        lastValidFillType = nil,
        fillLevel = nil,
        hasKnownCurrentFillType = false,
        hasKnownLastValidFillType = false,
        hasLoadedFill = true,
        canUseLastValidFillType = true
    }

    if sourceVehicle.getFillUnitFillType ~= nil then
        context.currentFillType = sourceVehicle:getFillUnitFillType(fillUnitIndex)
        context.hasKnownCurrentFillType = LiquidLime:isKnownFillType(context.currentFillType)
    end

    if sourceVehicle.getFillUnitLastValidFillType ~= nil then
        context.lastValidFillType = sourceVehicle:getFillUnitLastValidFillType(fillUnitIndex)
        context.hasKnownLastValidFillType = LiquidLime:isKnownFillType(context.lastValidFillType)
    end

    if sourceVehicle.getFillUnitFillLevel ~= nil then
        context.fillLevel = sourceVehicle:getFillUnitFillLevel(fillUnitIndex)

        if context.fillLevel ~= nil then
            context.hasLoadedFill = context.fillLevel > 0
        end
    end

    context.canUseLastValidFillType = not context.hasKnownCurrentFillType or not context.hasLoadedFill

    if context.hasKnownCurrentFillType then
        context.detectedFillType = context.currentFillType
        context.detectedSource = "current"
    elseif context.canUseLastValidFillType and context.hasKnownLastValidFillType then
        context.detectedFillType = context.lastValidFillType
        context.detectedSource = "lastValid"
    else
        context.detectedFillType = context.currentFillType
        context.detectedSource = "unknown"
    end

    return context
end

function LiquidLime:getFillUnitDetectedFillType(sourceVehicle, fillUnitIndex)
    local context = LiquidLime:getFillUnitFillContext(sourceVehicle, fillUnitIndex)

    return context ~= nil and context.detectedFillType or nil
end

function LiquidLime:getPrecisionFarmingSourceFillType(vehicle)
    local sourceVehicle, fillUnitIndex = LiquidLime:getPrecisionFarmingFillSource(vehicle)

    return LiquidLime:getFillUnitDetectedFillType(sourceVehicle, fillUnitIndex)
end

function LiquidLime:addPrecisionFarmingFillContext(contexts, fallbackContexts, sourceVehicle, fillUnitIndex, sourceName)
    local context = LiquidLime:getFillUnitFillContext(sourceVehicle, fillUnitIndex, sourceName)

    if context == nil then
        return nil
    end

    table.insert(contexts, context)

    if context.canUseLastValidFillType and context.hasKnownLastValidFillType then
        table.insert(fallbackContexts, context)
    end

    return context
end

function LiquidLime:addPrecisionFarmingFillTypeSourceContexts(contexts, fallbackContexts, fillTypeSources, sourceName)
    if fillTypeSources == nil then
        return
    end

    for _, sourceData in ipairs(fillTypeSources) do
        if sourceData ~= nil then
            LiquidLime:addPrecisionFarmingFillContext(
                contexts,
                fallbackContexts,
                sourceData.vehicle,
                sourceData.fillUnitIndex,
                sourceName
            )
        end
    end
end

function LiquidLime:getPrecisionFarmingOrderedFillContexts(vehicle)
    local contexts = {}
    local fallbackContexts = {}

    local sourceVehicle, fillUnitIndex = LiquidLime:getPrecisionFarmingFillSource(vehicle)
    LiquidLime:addPrecisionFarmingFillContext(contexts, fallbackContexts, sourceVehicle, fillUnitIndex, "precisionFarmingSource")

    if vehicle ~= nil and vehicle.getSprayerFillUnitIndex ~= nil then
        local sprayerFillUnitIndex = vehicle:getSprayerFillUnitIndex()

        LiquidLime:addPrecisionFarmingFillContext(contexts, fallbackContexts, vehicle, sprayerFillUnitIndex, "sprayerFillUnit")
    end

    local sprayerSpec = vehicle ~= nil and vehicle.spec_sprayer or nil

    if sprayerSpec ~= nil and sprayerSpec.fillTypeSources ~= nil then
        if sprayerSpec.supportedSprayTypes ~= nil and #sprayerSpec.supportedSprayTypes > 0 then
            for supportedIndex = 1, #sprayerSpec.supportedSprayTypes do
                local sprayTypeIndex = sprayerSpec.supportedSprayTypes[supportedIndex]

                LiquidLime:addPrecisionFarmingFillTypeSourceContexts(
                    contexts,
                    fallbackContexts,
                    sprayerSpec.fillTypeSources[sprayTypeIndex],
                    "sprayerSource"
                )
            end
        else
            for _, fillTypeSources in pairs(sprayerSpec.fillTypeSources) do
                LiquidLime:addPrecisionFarmingFillTypeSourceContexts(contexts, fallbackContexts, fillTypeSources, "sprayerSource")
            end
        end
    end

    return contexts, fallbackContexts
end

function LiquidLime:getPrecisionFarmingFillContexts(vehicle)
    local contexts = LiquidLime:getPrecisionFarmingOrderedFillContexts(vehicle)

    return contexts
end

function LiquidLime:getPrecisionFarmingActiveFillContext(vehicle)
    local contexts, fallbackContexts = LiquidLime:getPrecisionFarmingOrderedFillContexts(vehicle)

    for _, context in ipairs(contexts) do
        if context.hasKnownCurrentFillType and context.hasLoadedFill then
            return context, nil
        end
    end

    return nil, fallbackContexts[1]
end

function LiquidLime:getPrecisionFarmingSprayerSourceFillType(vehicle)
    local activeContext, fallbackContext = LiquidLime:getPrecisionFarmingActiveFillContext(vehicle)

    if activeContext ~= nil
        and activeContext.hasKnownCurrentFillType
        and LiquidLime:isLiquidLimeFillType(activeContext.currentFillType) then
        return activeContext.currentFillType
    end

    if fallbackContext ~= nil
        and fallbackContext.hasKnownLastValidFillType
        and LiquidLime:isLiquidLimeFillType(fallbackContext.lastValidFillType) then
        return fallbackContext.lastValidFillType
    end

    return nil
end

function LiquidLime:getPrecisionFarmingWorkAreaFillType(vehicle)
    local sprayerSpec = vehicle ~= nil and vehicle.spec_sprayer or nil

    if sprayerSpec == nil or sprayerSpec.workAreaParameters == nil then
        return nil
    end

    return sprayerSpec.workAreaParameters.sprayFillType
end

function LiquidLime:formatPrecisionFarmingFillContext(context)
    if context == nil then
        return "context=nil"
    end

    return string.format(
        "source=%s, fillUnit=%s, current=%s, lastValid=%s, fillLevel=%s, loaded=%s, detected=%s:%s",
        tostring(context.sourceName),
        tostring(context.fillUnitIndex),
        LiquidLime:getFillTypeDebugName(context.currentFillType),
        LiquidLime:getFillTypeDebugName(context.lastValidFillType),
        tostring(context.fillLevel),
        tostring(context.hasLoadedFill),
        tostring(context.detectedSource),
        LiquidLime:getFillTypeDebugName(context.detectedFillType)
    )
end

function LiquidLime:logPrecisionFarmingLiquidLimeContext(vehicle, explicitFillType, context)
    if context == nil then
        return
    end

    local decision = "inactive"

    if context.isActive then
        decision = "active"
    elseif context.blocksLiquidLime then
        decision = "blocked"
    end

    local contextFillType = context.fillType

    if contextFillType == nil and context.context ~= nil then
        contextFillType = context.context.detectedFillType
    end

    local sourceName = context.context ~= nil and context.context.sourceName or "none"
    local key = string.format(
        "pfLiquidLime:%s:%s:%s:%s:%s",
        decision,
        tostring(context.reason),
        sourceName,
        LiquidLime:getFillTypeDebugName(contextFillType),
        LiquidLime:getFillTypeDebugName(explicitFillType)
    )
    local details = ""

    if context.context ~= nil then
        details = " (" .. LiquidLime:formatPrecisionFarmingFillContext(context.context) .. ")"
    end

    LiquidLime:LogOnce(key, string.format(
        "Precision Farming Liquid Lime %s: reason=%s, vehicle=%s, resolvedFillType=%s, explicitFillType=%s%s.",
        decision,
        tostring(context.reason),
        LiquidLime:getVehicleDebugName(vehicle),
        LiquidLime:getFillTypeDebugName(contextFillType),
        LiquidLime:getFillTypeDebugName(explicitFillType),
        details
    ))
end

function LiquidLime:getPrecisionFarmingLiquidLimeFillContext(vehicle, fillType, allowLastValidFillType)
    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    if liquidLimeFillType == nil then
        return {
            isActive = false,
            blocksLiquidLime = true,
            reason = "missingLiquidLimeFillType"
        }
    end

    if allowLastValidFillType == nil then
        allowLastValidFillType = true
    end

    local explicitFillTypeIsKnown = LiquidLime:isKnownFillType(fillType)
    local explicitFillTypeIsLiquidLime = fillType == liquidLimeFillType

    local activeContext, fallbackContext = LiquidLime:getPrecisionFarmingActiveFillContext(vehicle)

    if activeContext ~= nil and activeContext.hasKnownCurrentFillType then
        if activeContext.currentFillType ~= liquidLimeFillType then
            return {
                isActive = false,
                blocksLiquidLime = true,
                fillType = activeContext.currentFillType,
                reason = "currentFillType",
                context = activeContext
            }
        end

        return {
            isActive = true,
            fillType = liquidLimeFillType,
            reason = "currentFillType",
            context = activeContext
        }
    end

    if explicitFillTypeIsLiquidLime then
        return {
            isActive = true,
            fillType = liquidLimeFillType,
            reason = "explicitFillType"
        }
    end

    if explicitFillTypeIsKnown then
        return {
            isActive = false,
            blocksLiquidLime = true,
            fillType = fillType,
            reason = "explicitFillType"
        }
    end

    if allowLastValidFillType and fallbackContext ~= nil and fallbackContext.hasKnownLastValidFillType then
        if fallbackContext.lastValidFillType == liquidLimeFillType then
            return {
                isActive = true,
                fillType = liquidLimeFillType,
                reason = "lastValidFillType",
                context = fallbackContext
            }
        end

        return {
            isActive = false,
            blocksLiquidLime = true,
            fillType = fallbackContext.lastValidFillType,
            reason = "lastValidFillType",
            context = fallbackContext
        }
    end

    local workAreaFillType = LiquidLime:getPrecisionFarmingWorkAreaFillType(vehicle)

    if LiquidLime:isKnownFillType(workAreaFillType) then
        return {
            isActive = workAreaFillType == liquidLimeFillType,
            blocksLiquidLime = workAreaFillType ~= liquidLimeFillType,
            fillType = workAreaFillType,
            reason = "workAreaFillType"
        }
    end

    return {
        isActive = false,
        blocksLiquidLime = false,
        reason = "unknown"
    }
end

function LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle, fillType)
    local context = LiquidLime:getPrecisionFarmingLiquidLimeFillContext(vehicle, fillType)

    LiquidLime:logPrecisionFarmingLiquidLimeContext(vehicle, fillType, context)

    if context ~= nil and context.isActive then
        return true
    end

    return false
end

function LiquidLime:patchPrecisionFarming()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.getCurrentSprayerMode == nil then
        return
    end

    local function createPatchedGetCurrentSprayerMode(originalGetCurrentSprayerMode)
        return function(vehicle, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        setSprayerFlags = true
                    },
                    originalGetCurrentSprayerMode,
                    vehicle,
                    ...
                )
            end

            return originalGetCurrentSprayerMode(vehicle, ...)
        end
    end

    if LiquidLime.precisionFarmingPatched
        and ExtendedSprayer.getCurrentSprayerMode == LiquidLime.precisionFarmingPatchedGetCurrentSprayerMode then
        LiquidLime:patchPrecisionFarmingFunctionCopies("getCurrentSprayerMode", ExtendedSprayer, createPatchedGetCurrentSprayerMode)
        return
    end

    if ExtendedSprayer.getFillTypeSourceVehicle == nil then
        if not LiquidLime.precisionFarmingPatchWarningShown then
            LiquidLime:Log("Precision Farming ExtendedSprayer source lookup not found. Skipping PF compatibility patch.")
            LiquidLime.precisionFarmingPatchWarningShown = true
        end

        return
    end

    LiquidLime.liquidLimeFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName("LIQUIDLIME")

    if LiquidLime.liquidLimeFillTypeIndex == nil then
        if not LiquidLime.precisionFarmingPatchWarningShown then
            LiquidLime:Log("LIQUIDLIME fill type index not found. Skipping PF compatibility patch.")
            LiquidLime.precisionFarmingPatchWarningShown = true
        end

        return
    end

    local originalGetCurrentSprayerMode = ExtendedSprayer.getCurrentSprayerMode
    local patchedGetCurrentSprayerMode = createPatchedGetCurrentSprayerMode(originalGetCurrentSprayerMode)

    LiquidLime.precisionFarmingOriginalGetCurrentSprayerMode = originalGetCurrentSprayerMode
    LiquidLime.precisionFarmingPatchedGetCurrentSprayerMode = patchedGetCurrentSprayerMode
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedGetCurrentSprayerMode)
    ExtendedSprayer.getCurrentSprayerMode = patchedGetCurrentSprayerMode
    LiquidLime:patchPrecisionFarmingFunctionCopies("getCurrentSprayerMode", ExtendedSprayer, createPatchedGetCurrentSprayerMode)
    LiquidLime.precisionFarmingPatched = true
    LiquidLime:Log("Precision Farming compatibility patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingUsage()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.getSprayerUsage == nil then
        return
    end

    local function createPatchedGetSprayerUsage(originalGetSprayerUsage)
        return function(vehicle, superFunc, fillType, dt, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle, fillType) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        setSprayerFlags = true,
                        forceLiming = true,
                        scalePHUsage = true
                    },
                    originalGetSprayerUsage,
                    vehicle,
                    superFunc,
                    fillType,
                    dt,
                    ...
                )
            end

            return originalGetSprayerUsage(vehicle, superFunc, fillType, dt, ...)
        end
    end

    local function createPatchedCopiedGetSprayerUsage(originalGetSprayerUsage)
        return function(vehicle, fillType, dt, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle, fillType) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        setSprayerFlags = true,
                        forceLiming = true,
                        scalePHUsage = true
                    },
                    originalGetSprayerUsage,
                    vehicle,
                    fillType,
                    dt,
                    ...
                )
            end

            return originalGetSprayerUsage(vehicle, fillType, dt, ...)
        end
    end

    if LiquidLime.precisionFarmingUsagePatched
        and ExtendedSprayer.getSprayerUsage == LiquidLime.precisionFarmingPatchedGetSprayerUsage then
        LiquidLime:patchPrecisionFarmingFunctionCopies("getSprayerUsage", ExtendedSprayer, createPatchedGetSprayerUsage, createPatchedCopiedGetSprayerUsage)
        return
    end

    local originalGetSprayerUsage = ExtendedSprayer.getSprayerUsage
    local patchedGetSprayerUsage = createPatchedGetSprayerUsage(originalGetSprayerUsage)

    LiquidLime.precisionFarmingOriginalGetSprayerUsage = originalGetSprayerUsage
    LiquidLime.precisionFarmingPatchedGetSprayerUsage = patchedGetSprayerUsage
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedGetSprayerUsage)
    ExtendedSprayer.getSprayerUsage = patchedGetSprayerUsage
    LiquidLime:patchPrecisionFarmingFunctionCopies("getSprayerUsage", ExtendedSprayer, createPatchedGetSprayerUsage, createPatchedCopiedGetSprayerUsage)
    LiquidLime.precisionFarmingUsagePatched = true
    LiquidLime:Log("Precision Farming usage-rate patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingFillTypeChanges()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.onChangedFillType == nil then
        return
    end

    if LiquidLime.precisionFarmingFillTypeChangePatched
        and ExtendedSprayer.onChangedFillType == LiquidLime.precisionFarmingPatchedOnChangedFillType then
        LiquidLime:patchPrecisionFarmingFunctionCopies("onChangedFillType", ExtendedSprayer, function(originalOnChangedFillType)
            return function(vehicle, fillUnitIndex, fillTypeIndex, oldFillTypeIndex, ...)
                if LiquidLime:isLiquidLimeFillType(fillTypeIndex) then
                    return LiquidLime:runWithPrecisionFarmingLimeMapping(
                        vehicle,
                        {
                            setSprayerFlags = true,
                            forceLiming = true
                        },
                        originalOnChangedFillType,
                        vehicle,
                        fillUnitIndex,
                        fillTypeIndex,
                        oldFillTypeIndex,
                        ...
                    )
                end

                return originalOnChangedFillType(vehicle, fillUnitIndex, fillTypeIndex, oldFillTypeIndex, ...)
            end
        end)
        return
    end

    local originalOnChangedFillType = ExtendedSprayer.onChangedFillType

    local patchedOnChangedFillType = function(vehicle, fillUnitIndex, fillTypeIndex, oldFillTypeIndex, ...)
        if LiquidLime:isLiquidLimeFillType(fillTypeIndex) then
            return LiquidLime:runWithPrecisionFarmingLimeMapping(
                vehicle,
                {
                    setSprayerFlags = true,
                    forceLiming = true
                },
                originalOnChangedFillType,
                vehicle,
                fillUnitIndex,
                fillTypeIndex,
                oldFillTypeIndex,
                ...
            )
        end

        return originalOnChangedFillType(vehicle, fillUnitIndex, fillTypeIndex, oldFillTypeIndex, ...)
    end

    LiquidLime.precisionFarmingOriginalOnChangedFillType = originalOnChangedFillType
    LiquidLime.precisionFarmingPatchedOnChangedFillType = patchedOnChangedFillType
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedOnChangedFillType)
    ExtendedSprayer.onChangedFillType = patchedOnChangedFillType
    LiquidLime:patchPrecisionFarmingFunctionCopies("onChangedFillType", ExtendedSprayer, function(originalCopiedOnChangedFillType)
        return function(vehicle, fillUnitIndex, fillTypeIndex, oldFillTypeIndex, ...)
            if LiquidLime:isLiquidLimeFillType(fillTypeIndex) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        setSprayerFlags = true,
                        forceLiming = true
                    },
                    originalCopiedOnChangedFillType,
                    vehicle,
                    fillUnitIndex,
                    fillTypeIndex,
                    oldFillTypeIndex,
                    ...
                )
            end

            return originalCopiedOnChangedFillType(vehicle, fillUnitIndex, fillTypeIndex, oldFillTypeIndex, ...)
        end
    end)
    LiquidLime.precisionFarmingFillTypeChangePatched = true
    LiquidLime:Log("Precision Farming fill-type flag patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingNozzleEffects()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.updateExtendedSprayerNozzleEffectState == nil then
        return
    end

    local function createPatchedUpdateNozzleEffectState(originalUpdateNozzleEffectState)
        return function(vehicle, superFunc, effectData, dt, isTurnedOn, lastSpeed, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        patchEffectFillType = true,
                        setSprayerFlags = true,
                        forceLiming = true
                    },
                    originalUpdateNozzleEffectState,
                    vehicle,
                    superFunc,
                    effectData,
                    dt,
                    isTurnedOn,
                    lastSpeed,
                    ...
                )
            end

            return originalUpdateNozzleEffectState(vehicle, superFunc, effectData, dt, isTurnedOn, lastSpeed, ...)
        end
    end

    local function createPatchedCopiedUpdateNozzleEffectState(originalUpdateNozzleEffectState)
        return function(vehicle, effectData, dt, isTurnedOn, lastSpeed, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        patchEffectFillType = true,
                        setSprayerFlags = true,
                        forceLiming = true
                    },
                    originalUpdateNozzleEffectState,
                    vehicle,
                    effectData,
                    dt,
                    isTurnedOn,
                    lastSpeed,
                    ...
                )
            end

            return originalUpdateNozzleEffectState(vehicle, effectData, dt, isTurnedOn, lastSpeed, ...)
        end
    end

    if LiquidLime.precisionFarmingNozzleEffectsPatched
        and ExtendedSprayer.updateExtendedSprayerNozzleEffectState == LiquidLime.precisionFarmingPatchedUpdateNozzleEffectState then
        LiquidLime:patchPrecisionFarmingFunctionCopies("updateExtendedSprayerNozzleEffectState", ExtendedSprayer, createPatchedUpdateNozzleEffectState, createPatchedCopiedUpdateNozzleEffectState)
        return
    end

    local originalUpdateNozzleEffectState = ExtendedSprayer.updateExtendedSprayerNozzleEffectState
    local patchedUpdateNozzleEffectState = createPatchedUpdateNozzleEffectState(originalUpdateNozzleEffectState)

    LiquidLime.precisionFarmingOriginalUpdateNozzleEffectState = originalUpdateNozzleEffectState
    LiquidLime.precisionFarmingPatchedUpdateNozzleEffectState = patchedUpdateNozzleEffectState
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedUpdateNozzleEffectState)
    ExtendedSprayer.updateExtendedSprayerNozzleEffectState = patchedUpdateNozzleEffectState
    LiquidLime:patchPrecisionFarmingFunctionCopies("updateExtendedSprayerNozzleEffectState", ExtendedSprayer, createPatchedUpdateNozzleEffectState, createPatchedCopiedUpdateNozzleEffectState)
    LiquidLime.precisionFarmingNozzleEffectsPatched = true
    LiquidLime:Log("Precision Farming nozzle effect patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingSprayerEffects()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.updateSprayerEffectState == nil then
        return
    end

    if LiquidLime.precisionFarmingSprayerEffectsPatched
        and ExtendedSprayer.updateSprayerEffectState == LiquidLime.precisionFarmingPatchedUpdateSprayerEffectState then
        LiquidLime:patchPrecisionFarmingFunctionCopies("updateSprayerEffectState", ExtendedSprayer, function(originalUpdateSprayerEffectState)
            return function(vehicle, force, ...)
                if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                    return LiquidLime:runWithPrecisionFarmingLimeMapping(
                        vehicle,
                        {
                            patchSourceFillType = true,
                            patchEffectFillType = true,
                            setSprayerFlags = true,
                            forceLiming = true
                        },
                        originalUpdateSprayerEffectState,
                        vehicle,
                        force,
                        ...
                    )
                end

                return originalUpdateSprayerEffectState(vehicle, force, ...)
            end
        end)
        return
    end

    local originalUpdateSprayerEffectState = ExtendedSprayer.updateSprayerEffectState

    local patchedUpdateSprayerEffectState = function(vehicle, force, ...)
        if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
            return LiquidLime:runWithPrecisionFarmingLimeMapping(
                vehicle,
                {
                    patchSourceFillType = true,
                    patchEffectFillType = true,
                    setSprayerFlags = true,
                    forceLiming = true
                },
                originalUpdateSprayerEffectState,
                vehicle,
                force,
                ...
            )
        end

        return originalUpdateSprayerEffectState(vehicle, force, ...)
    end

    LiquidLime.precisionFarmingOriginalUpdateSprayerEffectState = originalUpdateSprayerEffectState
    LiquidLime.precisionFarmingPatchedUpdateSprayerEffectState = patchedUpdateSprayerEffectState
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedUpdateSprayerEffectState)
    ExtendedSprayer.updateSprayerEffectState = patchedUpdateSprayerEffectState
    LiquidLime:patchPrecisionFarmingFunctionCopies("updateSprayerEffectState", ExtendedSprayer, function(originalCopiedUpdateSprayerEffectState)
        return function(vehicle, force, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        patchEffectFillType = true,
                        setSprayerFlags = true,
                        forceLiming = true
                    },
                    originalCopiedUpdateSprayerEffectState,
                    vehicle,
                    force,
                    ...
                )
            end

            return originalCopiedUpdateSprayerEffectState(vehicle, force, ...)
        end
    end)
    LiquidLime.precisionFarmingSprayerEffectsPatched = true
    LiquidLime:Log("Precision Farming sprayer effect patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingStatistics()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.onEndWorkAreaProcessing == nil then
        return
    end

    if LiquidLime.precisionFarmingStatsPatched
        and ExtendedSprayer.onEndWorkAreaProcessing == LiquidLime.precisionFarmingPatchedOnEndWorkAreaProcessing then
        LiquidLime:patchPrecisionFarmingFunctionCopies("onEndWorkAreaProcessing", ExtendedSprayer, function(originalOnEndWorkAreaProcessing)
            return function(vehicle, dt, hasProcessed, ...)
                if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                    return LiquidLime:runWithPrecisionFarmingLimeMapping(
                        vehicle,
                        {
                            setSprayerFlags = true,
                            forceLiming = true
                        },
                        originalOnEndWorkAreaProcessing,
                        vehicle,
                        dt,
                        hasProcessed,
                        ...
                    )
                end

                return originalOnEndWorkAreaProcessing(vehicle, dt, hasProcessed, ...)
            end
        end)
        return
    end

    local originalOnEndWorkAreaProcessing = ExtendedSprayer.onEndWorkAreaProcessing

    local patchedOnEndWorkAreaProcessing = function(vehicle, dt, hasProcessed, ...)
        if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
            return LiquidLime:runWithPrecisionFarmingLimeMapping(
                vehicle,
                {
                    setSprayerFlags = true,
                    forceLiming = true
                },
                originalOnEndWorkAreaProcessing,
                vehicle,
                dt,
                hasProcessed,
                ...
            )
        end

        return originalOnEndWorkAreaProcessing(vehicle, dt, hasProcessed, ...)
    end

    LiquidLime.precisionFarmingOriginalOnEndWorkAreaProcessing = originalOnEndWorkAreaProcessing
    LiquidLime.precisionFarmingPatchedOnEndWorkAreaProcessing = patchedOnEndWorkAreaProcessing
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedOnEndWorkAreaProcessing)
    ExtendedSprayer.onEndWorkAreaProcessing = patchedOnEndWorkAreaProcessing
    LiquidLime:patchPrecisionFarmingFunctionCopies("onEndWorkAreaProcessing", ExtendedSprayer, function(originalCopiedOnEndWorkAreaProcessing)
        return function(vehicle, dt, hasProcessed, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        setSprayerFlags = true,
                        forceLiming = true
                    },
                    originalCopiedOnEndWorkAreaProcessing,
                    vehicle,
                    dt,
                    hasProcessed,
                    ...
                )
            end

            return originalCopiedOnEndWorkAreaProcessing(vehicle, dt, hasProcessed, ...)
        end
    end)
    LiquidLime.precisionFarmingStatsPatched = true
    LiquidLime:Log("Precision Farming lime statistics patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingHudVisibility()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if ExtendedSprayer == nil or ExtendedSprayer.getShowExtendedSprayerHudExtension == nil then
        return
    end

    local function createPatchedGetShowHudExtension(originalGetShowHudExtension)
        return function(vehicle, ...)
            if LiquidLime:isPrecisionFarmingLiquidLimeActive(vehicle) then
                if not LiquidLime.precisionFarmingHudVisibilityActiveLogged then
                    LiquidLime:Log("Precision Farming HUD visibility mapping active for LIQUIDLIME.")
                    LiquidLime.precisionFarmingHudVisibilityActiveLogged = true
                end

                return LiquidLime:runWithPrecisionFarmingLimeMapping(
                    vehicle,
                    {
                        patchSourceFillType = true,
                        setSprayerFlags = true,
                        forceLiming = true
                    },
                    originalGetShowHudExtension,
                    vehicle,
                    ...
                )
            end

            return originalGetShowHudExtension(vehicle, ...)
        end
    end

    if LiquidLime.precisionFarmingHudVisibilityPatched
        and ExtendedSprayer.getShowExtendedSprayerHudExtension == LiquidLime.precisionFarmingPatchedGetShowHudExtension then
        LiquidLime:patchPrecisionFarmingFunctionCopies("getShowExtendedSprayerHudExtension", ExtendedSprayer, createPatchedGetShowHudExtension)
        return
    end

    local originalGetShowHudExtension = ExtendedSprayer.getShowExtendedSprayerHudExtension
    local patchedGetShowHudExtension = createPatchedGetShowHudExtension(originalGetShowHudExtension)

    LiquidLime.precisionFarmingOriginalGetShowHudExtension = originalGetShowHudExtension
    LiquidLime.precisionFarmingPatchedGetShowHudExtension = patchedGetShowHudExtension
    LiquidLime:rememberPrecisionFarmingPatchedFunction(patchedGetShowHudExtension)
    ExtendedSprayer.getShowExtendedSprayerHudExtension = patchedGetShowHudExtension
    LiquidLime:patchPrecisionFarmingFunctionCopies("getShowExtendedSprayerHudExtension", ExtendedSprayer, createPatchedGetShowHudExtension)
    LiquidLime.precisionFarmingHudVisibilityPatched = true
    LiquidLime:Log("Precision Farming HUD visibility patch applied for LIQUIDLIME.")
end

function LiquidLime:patchPrecisionFarmingHud()
    local ExtendedSprayerHUDExtension = LiquidLime:getPrecisionFarmingHUDExtension()

    if ExtendedSprayerHUDExtension == nil or ExtendedSprayerHUDExtension.draw == nil then
        return
    end

    if FillType == nil or FillType.LIME == nil then
        return
    end

    if LiquidLime.precisionFarmingHudPatched
        and ExtendedSprayerHUDExtension.draw == LiquidLime.precisionFarmingPatchedHudDraw then
        return
    end

    local originalHudDraw = ExtendedSprayerHUDExtension.draw

    local patchedHudDraw = function(hud, ...)
        if hud ~= nil and LiquidLime:isPrecisionFarmingLiquidLimeActive(hud.vehicle) then
            if not LiquidLime.precisionFarmingHudDrawActiveLogged then
                LiquidLime:Log("Precision Farming HUD draw mapping active for LIQUIDLIME.")
                LiquidLime.precisionFarmingHudDrawActiveLogged = true
            end

            return LiquidLime:runWithPrecisionFarmingLimeMapping(
                hud.vehicle,
                {
                    patchSourceFillType = true,
                    setSprayerFlags = true,
                    forceLiming = true,
                    scalePHUsage = true,
                    hud = hud
                },
                originalHudDraw,
                hud,
                ...
            )
        end

        return originalHudDraw(hud, ...)
    end

    LiquidLime.precisionFarmingOriginalHudDraw = originalHudDraw
    LiquidLime.precisionFarmingPatchedHudDraw = patchedHudDraw
    ExtendedSprayerHUDExtension.draw = patchedHudDraw
    LiquidLime.precisionFarmingHudPatched = true
    LiquidLime:Log("Precision Farming HUD patch applied for LIQUIDLIME.")
end

function LiquidLime:getPrecisionFarmingHudFillSource(hud)
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()

    if hud == nil
        or hud.vehicle == nil
        or ExtendedSprayer == nil
        or ExtendedSprayer.getFillTypeSourceVehicle == nil then
        return nil, nil
    end

    return ExtendedSprayer.getFillTypeSourceVehicle(hud.vehicle)
end
