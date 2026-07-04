-- Runtime fill type patching for supported base-game trailers.

function LiquidLime:installVehicleXmlFillTypePatch()
    if loadXMLFile ~= nil and LiquidLime.originalLoadXMLFile == nil then
        LiquidLime.originalLoadXMLFile = loadXMLFile

        loadXMLFile = function(...)
            local xmlFile = LiquidLime.originalLoadXMLFile(...)
            local filename = LiquidLime:findTargetVehicleXmlFilename(...)

            if filename ~= nil then
                LiquidLime:patchVehicleXmlFillTypes(xmlFile, filename)
            end

            return xmlFile
        end
    end

    if XMLFile ~= nil and XMLFile.load ~= nil and LiquidLime.originalXMLFileLoad == nil then
        LiquidLime.originalXMLFileLoad = XMLFile.load

        XMLFile.load = function(...)
            local xmlFile = LiquidLime.originalXMLFileLoad(...)
            local filename = LiquidLime:findTargetVehicleXmlFilename(...)

            if filename ~= nil then
                LiquidLime:patchVehicleXmlFillTypes(xmlFile, filename)
            end

            return xmlFile
        end
    end

    LiquidLime.vehicleXmlPatchInstalled = LiquidLime.originalLoadXMLFile ~= nil or LiquidLime.originalXMLFileLoad ~= nil
end

function LiquidLime:findTargetVehicleXmlFilename(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)

        if type(value) == "string" and LiquidLime:isTargetVehicleXml(value) then
            return value
        end
    end

    return nil
end

function LiquidLime:isTargetVehicleXml(filename)
    local normalizedFilename = LiquidLime:normalizeFilename(filename)

    if normalizedFilename == nil then
        return false
    end

    for targetFilename, _ in pairs(LiquidLime.vehicleFillTypeTargets) do
        if normalizedFilename:sub(-#targetFilename) == targetFilename then
            return true
        end
    end

    return false
end

function LiquidLime:normalizeFilename(filename)
    if filename == nil then
        return nil
    end

    local normalizedFilename = tostring(filename):gsub("\\", "/"):lower()
    normalizedFilename = normalizedFilename:gsub("^%$data/", "data/")

    return normalizedFilename
end

function LiquidLime:patchVehicleXmlFillTypes(xmlFile, filename)
    if xmlFile == nil then
        return
    end

    local patched = false
    local configIndex = 0

    while configIndex < 32 do
        local foundConfig = false
        local fillUnitIndex = 0

        while fillUnitIndex < 32 do
            local key = string.format(
                "vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(%d).fillUnits.fillUnit(%d)#fillTypes",
                configIndex,
                fillUnitIndex
            )
            local fillTypes = LiquidLime:getXmlString(xmlFile, key)

            if fillTypes == nil then
                if fillUnitIndex == 0 then
                    break
                end
            else
                foundConfig = true

                if not LiquidLime:fillTypesContain(fillTypes, LiquidLime.FILL_TYPE_NAME) then
                    local patchedFillTypes = fillTypes .. " " .. LiquidLime.FILL_TYPE_NAME

                    if LiquidLime:setXmlString(xmlFile, key, patchedFillTypes) then
                        patched = true
                    elseif not LiquidLime.vehicleXmlPatchWarningShown then
                        LiquidLime:Log("Unable to patch base-game trailer fillTypes because this XML object does not support writing.")
                        LiquidLime.vehicleXmlPatchWarningShown = true
                    end
                end
            end

            fillUnitIndex = fillUnitIndex + 1
        end

        if not foundConfig then
            break
        end

        configIndex = configIndex + 1
    end

    if patched then
        local normalizedFilename = LiquidLime:normalizeFilename(filename) or tostring(filename)

        if LiquidLime.vehicleXmlPatchLog[normalizedFilename] == nil then
            LiquidLime:Log("Added LIQUIDLIME fillType support to base-game trailer XML: " .. tostring(filename))
            LiquidLime.vehicleXmlPatchLog[normalizedFilename] = true
        end
    end
end

function LiquidLime:getXmlString(xmlFile, key)
    if type(xmlFile) == "table" and xmlFile.getString ~= nil then
        return xmlFile:getString(key)
    end

    if getXMLString ~= nil then
        return getXMLString(xmlFile, key)
    end

    return nil
end

function LiquidLime:setXmlString(xmlFile, key, value)
    if type(xmlFile) == "table" and xmlFile.setString ~= nil then
        xmlFile:setString(key, value)
        return true
    end

    if setXMLString ~= nil then
        setXMLString(xmlFile, key, value)
        return true
    end

    return false
end

function LiquidLime:fillTypesContain(fillTypes, fillTypeName)
    for existingFillType in string.gmatch(fillTypes or "", "%S+") do
        if string.upper(existingFillType) == fillTypeName then
            return true
        end
    end

    return false
end
