LiquidLime = {}

local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"
LiquidLime.FILL_TYPE_NAME = "LIQUIDLIME"

LiquidLime.precisionFarmingPatched = false
LiquidLime.precisionFarmingOriginalGetCurrentSprayerMode = nil
LiquidLime.precisionFarmingPatchedGetCurrentSprayerMode = nil
LiquidLime.precisionFarmingOriginalGetSprayerUsage = nil
LiquidLime.precisionFarmingPatchedGetSprayerUsage = nil
LiquidLime.precisionFarmingOriginalOnChangedFillType = nil
LiquidLime.precisionFarmingPatchedOnChangedFillType = nil
LiquidLime.precisionFarmingOriginalUpdateNozzleEffectState = nil
LiquidLime.precisionFarmingPatchedUpdateNozzleEffectState = nil
LiquidLime.precisionFarmingOriginalUpdateSprayerEffectState = nil
LiquidLime.precisionFarmingPatchedUpdateSprayerEffectState = nil
LiquidLime.precisionFarmingOriginalOnEndWorkAreaProcessing = nil
LiquidLime.precisionFarmingPatchedOnEndWorkAreaProcessing = nil
LiquidLime.precisionFarmingOriginalHudDraw = nil
LiquidLime.precisionFarmingPatchedHudDraw = nil
LiquidLime.precisionFarmingEnvironment = nil
LiquidLime.globalEnvironment = nil
LiquidLime.liquidLimeFillTypeIndex = nil
LiquidLime.liquidLimeSprayTypeIndex = nil
LiquidLime.liquidLimeUsageFactor = nil
LiquidLime.precisionFarmingPatchWarningShown = false
LiquidLime.precisionFarmingUsagePatched = false
LiquidLime.precisionFarmingFillTypeChangePatched = false
LiquidLime.precisionFarmingNozzleEffectsPatched = false
LiquidLime.precisionFarmingSprayerEffectsPatched = false
LiquidLime.precisionFarmingStatsPatched = false
LiquidLime.precisionFarmingHudPatched = false
LiquidLime.precisionFarmingHudVisibilityPatched = false
LiquidLime.precisionFarmingOriginalGetShowHudExtension = nil
LiquidLime.precisionFarmingPatchedGetShowHudExtension = nil
LiquidLime.precisionFarmingFunctionCopyPatchRecords = {}
LiquidLime.precisionFarmingPatchedFunctionSet = {}
LiquidLime.precisionFarmingFunctionCopyPatchLog = {}
LiquidLime.precisionFarmingFunctionCopyPatchTimer = 0
LiquidLime.precisionFarmingLiquidLimeDetectionLogged = false
LiquidLime.precisionFarmingHudVisibilityActiveLogged = false
LiquidLime.precisionFarmingHudDrawActiveLogged = false
LiquidLime.vehicleXmlPatchInstalled = false
LiquidLime.originalLoadXMLFile = nil
LiquidLime.originalXMLFileLoad = nil
LiquidLime.vehicleXmlPatchLog = {}
LiquidLime.vehicleXmlPatchWarningShown = false
LiquidLime.helperFillPatchInstalled = false
LiquidLime.originalSprayerGetExternalFill = nil
LiquidLime.patchedSprayerGetExternalFill = nil
LiquidLime.helperFillCopyPatchRecords = {}
LiquidLime.helperFillPatchedFunctionSet = {}
LiquidLime.helperFillCopyPatchLogged = false
LiquidLime.vehicleFillTypeTargets = {
    ["vehicles/abi/watertrailer550/watertrailer550.xml"] = true,
    ["vehicles/abi/watertrailer1600/watertrailer1600.xml"] = true,
    ["vehicles/lizard/mks8/mks8.xml"] = true,
    ["vehicles/lizard/mks32/mks32.xml"] = true
}

function LiquidLime:loadMap()
    LiquidLime:installVehicleXmlFillTypePatch()

    LiquidLime:Log("========================================")
    LiquidLime:Log("Initializing LiquidLime Mod")
    LiquidLime:Log("========================================")

    local XMLDir = modDirectory .. "xml/sprayTypes.xml"

    if fileExists(XMLDir) then
        LiquidLime:Log("Found sprayTypes.xml at: " .. XMLDir)
        local xmlFile = loadXMLFile("sprayTypes", XMLDir)

        local i = 0
        while true do
            LiquidLime:Log("Processing XML entry at index: " .. i)
            local xmlKey = string.format("map.sprayTypes.sprayType(%d)", i)

            if not hasXMLProperty(xmlFile, xmlKey) then
                LiquidLime:Log("No further entries found. Stopping processing.")
                break
            end

            LiquidLime:Log("Extracting data for sprayType at: " .. xmlKey)
            local name = getXMLString(xmlFile, xmlKey .. "#name")
            local litersPerSecond = getXMLFloat(xmlFile, xmlKey .. "#litersPerSecond")
            local typeName = getXMLString(xmlFile, xmlKey .. "#type")
            local sprayGroundType = g_currentMission.fieldGroundSystem:getFieldSprayValueByName(
                getXMLString(xmlFile, xmlKey .. "#sprayGroundType")
            )

            if name and litersPerSecond and typeName and sprayGroundType then
                local existingSprayType = g_sprayTypeManager:getSprayTypeByName(name)

                if existingSprayType == nil then
                    LiquidLime:Log("Adding SprayType - Name: " .. name .. ", Liters/Sec: " .. litersPerSecond .. ", Type: " .. typeName)
                    local isBaseType = true
                    g_sprayTypeManager:addSprayType(name, litersPerSecond, typeName, sprayGroundType, isBaseType)
                else
                    LiquidLime:Log("SprayType already registered - Name: " .. name)
                end

                if g_dedicatedServerInfo == nil and g_materialManager ~= nil then
                    local materialHolderPath = modDirectory .. "material_holders/liquidLime_materialHolder.i3d"
                    LiquidLime:Log("Adding MaterialHolder at: " .. materialHolderPath)
                    g_materialManager:addModMaterialHolder(materialHolderPath)
                end
            else
                LiquidLime:Log("ERROR: Missing or invalid data for sprayType at: " .. xmlKey)
            end

            i = i + 1
        end
    else
        LiquidLime:Log("ERROR: sprayTypes.xml not found at: " .. XMLDir)
    end

    LiquidLime:patchPrecisionFarming()
    LiquidLime:patchPrecisionFarmingUsage()
    LiquidLime:patchPrecisionFarmingFillTypeChanges()
    LiquidLime:patchPrecisionFarmingNozzleEffects()
    LiquidLime:patchPrecisionFarmingSprayerEffects()
    LiquidLime:patchPrecisionFarmingStatistics()
    LiquidLime:patchPrecisionFarmingHudVisibility()
    LiquidLime:patchPrecisionFarmingHud()
    LiquidLime:patchHelperExternalFill()

    LiquidLime:Log("========================================")
    LiquidLime:Log("LiquidLime Mod Initialization Complete")
    LiquidLime:Log("========================================")
end

function LiquidLime:isLiquidLimeFillType(fillType)
    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    return liquidLimeFillType ~= nil and fillType == liquidLimeFillType
end

function LiquidLime:getLiquidLimeFillTypeIndex()
    if LiquidLime.liquidLimeFillTypeIndex == nil and g_fillTypeManager ~= nil then
        LiquidLime.liquidLimeFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(LiquidLime.FILL_TYPE_NAME)
    end

    return LiquidLime.liquidLimeFillTypeIndex
end

function LiquidLime:getLiquidLimeSprayTypeDesc()
    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    if liquidLimeFillType == nil or g_sprayTypeManager == nil or g_sprayTypeManager.getSprayTypeByFillTypeIndex == nil then
        return nil
    end

    return g_sprayTypeManager:getSprayTypeByFillTypeIndex(liquidLimeFillType)
end

function LiquidLime:getLiquidLimeSprayTypeIndex()
    if LiquidLime.liquidLimeSprayTypeIndex == nil then
        local sprayTypeDesc = LiquidLime:getLiquidLimeSprayTypeDesc()

        if sprayTypeDesc ~= nil then
            LiquidLime.liquidLimeSprayTypeIndex = sprayTypeDesc.index
        end
    end

    return LiquidLime.liquidLimeSprayTypeIndex
end

function LiquidLime:getBaseLimeSprayTypeDesc()
    if g_sprayTypeManager == nil then
        return nil
    end

    if g_sprayTypeManager.getSprayTypeByName ~= nil then
        local sprayTypeDesc = g_sprayTypeManager:getSprayTypeByName("LIME")

        if sprayTypeDesc ~= nil then
            return sprayTypeDesc
        end
    end

    if FillType ~= nil and FillType.LIME ~= nil and g_sprayTypeManager.getSprayTypeByFillTypeIndex ~= nil then
        local sprayTypeDesc = g_sprayTypeManager:getSprayTypeByFillTypeIndex(FillType.LIME)

        if sprayTypeDesc ~= nil then
            return sprayTypeDesc
        end
    end

    return nil
end

function LiquidLime:getLiquidLimeUsageFactor()
    if LiquidLime.liquidLimeUsageFactor ~= nil then
        return LiquidLime.liquidLimeUsageFactor
    end

    local liquidLimeSprayType = LiquidLime:getLiquidLimeSprayTypeDesc()
    local baseLimeSprayType = LiquidLime:getBaseLimeSprayTypeDesc()
    local liquidLimeRate = liquidLimeSprayType ~= nil and tonumber(liquidLimeSprayType.litersPerSecond) or nil
    local baseLimeRate = baseLimeSprayType ~= nil and tonumber(baseLimeSprayType.litersPerSecond) or nil

    if liquidLimeSprayType == nil
        or baseLimeSprayType == nil
        or liquidLimeRate == nil
        or baseLimeRate == nil
        or baseLimeRate <= 0 then
        LiquidLime.liquidLimeUsageFactor = 1
    else
        LiquidLime.liquidLimeUsageFactor = math.max(liquidLimeRate / baseLimeRate, 0.001)
    end

    return LiquidLime.liquidLimeUsageFactor
end

function LiquidLime:getLiquidLimeTitle()
    local liquidLimeFillType = LiquidLime:getLiquidLimeFillTypeIndex()

    if liquidLimeFillType ~= nil and g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(liquidLimeFillType)

        if fillTypeDesc ~= nil and fillTypeDesc.title ~= nil and fillTypeDesc.title ~= "" then
            return fillTypeDesc.title
        end
    end

    return "Liquid Lime"
end

function LiquidLime:update(dt)
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()
    local ExtendedSprayerHUDExtension = LiquidLime:getPrecisionFarmingHUDExtension()
    local refreshPrecisionFarmingCopies = false

    LiquidLime.precisionFarmingFunctionCopyPatchTimer = LiquidLime.precisionFarmingFunctionCopyPatchTimer + (dt or 0)

    if LiquidLime.precisionFarmingFunctionCopyPatchTimer > 1000 then
        LiquidLime.precisionFarmingFunctionCopyPatchTimer = 0
        refreshPrecisionFarmingCopies = true
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.getCurrentSprayerMode ~= LiquidLime.precisionFarmingPatchedGetCurrentSprayerMode) then
        LiquidLime:patchPrecisionFarming()
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.getSprayerUsage ~= LiquidLime.precisionFarmingPatchedGetSprayerUsage) then
        LiquidLime:patchPrecisionFarmingUsage()
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.onChangedFillType ~= LiquidLime.precisionFarmingPatchedOnChangedFillType) then
        LiquidLime:patchPrecisionFarmingFillTypeChanges()
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.updateExtendedSprayerNozzleEffectState ~= LiquidLime.precisionFarmingPatchedUpdateNozzleEffectState) then
        LiquidLime:patchPrecisionFarmingNozzleEffects()
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.updateSprayerEffectState ~= LiquidLime.precisionFarmingPatchedUpdateSprayerEffectState) then
        LiquidLime:patchPrecisionFarmingSprayerEffects()
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.onEndWorkAreaProcessing ~= LiquidLime.precisionFarmingPatchedOnEndWorkAreaProcessing) then
        LiquidLime:patchPrecisionFarmingStatistics()
    end

    if ExtendedSprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or ExtendedSprayer.getShowExtendedSprayerHudExtension ~= LiquidLime.precisionFarmingPatchedGetShowHudExtension) then
        LiquidLime:patchPrecisionFarmingHudVisibility()
    end

    if ExtendedSprayerHUDExtension ~= nil
        and ExtendedSprayerHUDExtension.draw ~= LiquidLime.precisionFarmingPatchedHudDraw then
        LiquidLime:patchPrecisionFarmingHud()
    end

    if Sprayer ~= nil
        and (refreshPrecisionFarmingCopies
            or Sprayer.getExternalFill ~= LiquidLime.patchedSprayerGetExternalFill) then
        LiquidLime:patchHelperExternalFill()
    end
end

function LiquidLime:deleteMap()
    local ExtendedSprayer = LiquidLime:getPrecisionFarmingExtendedSprayer()
    local ExtendedSprayerHUDExtension = LiquidLime:getPrecisionFarmingHUDExtension()

    if LiquidLime.precisionFarmingPatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.getCurrentSprayerMode == LiquidLime.precisionFarmingPatchedGetCurrentSprayerMode
        and LiquidLime.precisionFarmingOriginalGetCurrentSprayerMode ~= nil then
        ExtendedSprayer.getCurrentSprayerMode = LiquidLime.precisionFarmingOriginalGetCurrentSprayerMode
    end

    if LiquidLime.precisionFarmingUsagePatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.getSprayerUsage == LiquidLime.precisionFarmingPatchedGetSprayerUsage
        and LiquidLime.precisionFarmingOriginalGetSprayerUsage ~= nil then
        ExtendedSprayer.getSprayerUsage = LiquidLime.precisionFarmingOriginalGetSprayerUsage
    end

    if LiquidLime.precisionFarmingFillTypeChangePatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.onChangedFillType == LiquidLime.precisionFarmingPatchedOnChangedFillType
        and LiquidLime.precisionFarmingOriginalOnChangedFillType ~= nil then
        ExtendedSprayer.onChangedFillType = LiquidLime.precisionFarmingOriginalOnChangedFillType
    end

    if LiquidLime.precisionFarmingNozzleEffectsPatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.updateExtendedSprayerNozzleEffectState == LiquidLime.precisionFarmingPatchedUpdateNozzleEffectState
        and LiquidLime.precisionFarmingOriginalUpdateNozzleEffectState ~= nil then
        ExtendedSprayer.updateExtendedSprayerNozzleEffectState = LiquidLime.precisionFarmingOriginalUpdateNozzleEffectState
    end

    if LiquidLime.precisionFarmingSprayerEffectsPatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.updateSprayerEffectState == LiquidLime.precisionFarmingPatchedUpdateSprayerEffectState
        and LiquidLime.precisionFarmingOriginalUpdateSprayerEffectState ~= nil then
        ExtendedSprayer.updateSprayerEffectState = LiquidLime.precisionFarmingOriginalUpdateSprayerEffectState
    end

    if LiquidLime.precisionFarmingStatsPatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.onEndWorkAreaProcessing == LiquidLime.precisionFarmingPatchedOnEndWorkAreaProcessing
        and LiquidLime.precisionFarmingOriginalOnEndWorkAreaProcessing ~= nil then
        ExtendedSprayer.onEndWorkAreaProcessing = LiquidLime.precisionFarmingOriginalOnEndWorkAreaProcessing
    end

    if LiquidLime.precisionFarmingHudVisibilityPatched
        and ExtendedSprayer ~= nil
        and ExtendedSprayer.getShowExtendedSprayerHudExtension == LiquidLime.precisionFarmingPatchedGetShowHudExtension
        and LiquidLime.precisionFarmingOriginalGetShowHudExtension ~= nil then
        ExtendedSprayer.getShowExtendedSprayerHudExtension = LiquidLime.precisionFarmingOriginalGetShowHudExtension
    end

    if LiquidLime.helperFillPatchInstalled
        and Sprayer ~= nil
        and Sprayer.getExternalFill == LiquidLime.patchedSprayerGetExternalFill
        and LiquidLime.originalSprayerGetExternalFill ~= nil then
        Sprayer.getExternalFill = LiquidLime.originalSprayerGetExternalFill
    end

    if LiquidLime.precisionFarmingHudPatched
        and ExtendedSprayerHUDExtension ~= nil
        and ExtendedSprayerHUDExtension.draw == LiquidLime.precisionFarmingPatchedHudDraw
        and LiquidLime.precisionFarmingOriginalHudDraw ~= nil then
        ExtendedSprayerHUDExtension.draw = LiquidLime.precisionFarmingOriginalHudDraw
    end

    LiquidLime:restoreHelperExternalFillCopyPatches()
    LiquidLime.precisionFarmingPatched = false
    LiquidLime.precisionFarmingOriginalGetCurrentSprayerMode = nil
    LiquidLime.precisionFarmingPatchedGetCurrentSprayerMode = nil
    LiquidLime.precisionFarmingUsagePatched = false
    LiquidLime.precisionFarmingOriginalGetSprayerUsage = nil
    LiquidLime.precisionFarmingPatchedGetSprayerUsage = nil
    LiquidLime.precisionFarmingFillTypeChangePatched = false
    LiquidLime.precisionFarmingOriginalOnChangedFillType = nil
    LiquidLime.precisionFarmingPatchedOnChangedFillType = nil
    LiquidLime.precisionFarmingNozzleEffectsPatched = false
    LiquidLime.precisionFarmingOriginalUpdateNozzleEffectState = nil
    LiquidLime.precisionFarmingPatchedUpdateNozzleEffectState = nil
    LiquidLime.precisionFarmingSprayerEffectsPatched = false
    LiquidLime.precisionFarmingOriginalUpdateSprayerEffectState = nil
    LiquidLime.precisionFarmingPatchedUpdateSprayerEffectState = nil
    LiquidLime.precisionFarmingStatsPatched = false
    LiquidLime.precisionFarmingOriginalOnEndWorkAreaProcessing = nil
    LiquidLime.precisionFarmingPatchedOnEndWorkAreaProcessing = nil
    LiquidLime.precisionFarmingHudVisibilityPatched = false
    LiquidLime.precisionFarmingOriginalGetShowHudExtension = nil
    LiquidLime.precisionFarmingPatchedGetShowHudExtension = nil
    LiquidLime.precisionFarmingHudPatched = false
    LiquidLime.precisionFarmingOriginalHudDraw = nil
    LiquidLime.precisionFarmingPatchedHudDraw = nil
    LiquidLime:restorePrecisionFarmingFunctionCopyPatches()
    LiquidLime.precisionFarmingFunctionCopyPatchRecords = {}
    LiquidLime.precisionFarmingPatchedFunctionSet = {}
    LiquidLime.precisionFarmingFunctionCopyPatchLog = {}
    LiquidLime.precisionFarmingFunctionCopyPatchTimer = 0
    LiquidLime.precisionFarmingLiquidLimeDetectionLogged = false
    LiquidLime.precisionFarmingHudVisibilityActiveLogged = false
    LiquidLime.precisionFarmingHudDrawActiveLogged = false
    LiquidLime.precisionFarmingEnvironment = nil
    LiquidLime.globalEnvironment = nil
    LiquidLime.liquidLimeFillTypeIndex = nil
    LiquidLime.liquidLimeSprayTypeIndex = nil
    LiquidLime.liquidLimeUsageFactor = nil
    LiquidLime.precisionFarmingPatchWarningShown = false
    LiquidLime.helperFillPatchInstalled = false
    LiquidLime.originalSprayerGetExternalFill = nil
    LiquidLime.patchedSprayerGetExternalFill = nil
    LiquidLime.helperFillCopyPatchRecords = {}
    LiquidLime.helperFillPatchedFunctionSet = {}
    LiquidLime.helperFillCopyPatchLogged = false
    LiquidLime.vehicleXmlPatchLog = {}
end

function LiquidLime:Log(msg)
    print(string.format("[%s] - %s", modName, msg))
end
