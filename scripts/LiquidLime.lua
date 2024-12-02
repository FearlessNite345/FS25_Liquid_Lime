LiquidLime = {}

modDirectory = g_currentModDirectory or ""
modName = g_currentModName or "unknown"

function LiquidLime:loadMap()
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
                LiquidLime:Log("Adding SprayType - Name: " .. name .. ", Liters/Sec: " .. litersPerSecond .. ", Type: " .. typeName)
                local isBaseType = true
                g_sprayTypeManager:addSprayType(name, litersPerSecond, typeName, sprayGroundType, isBaseType)

                local materialHolderPath = modDirectory .. "material_holders/liquidLime_materialHolder.i3d"
                LiquidLime:Log("Adding MaterialHolder at: " .. materialHolderPath)
                g_materialManager:addModMaterialHolder(materialHolderPath)
            else
                LiquidLime:Log("ERROR: Missing or invalid data for sprayType at: " .. xmlKey)
            end

            i = i + 1
        end
    else
        LiquidLime:Log("ERROR: sprayTypes.xml not found at: " .. XMLDir)
    end

    LiquidLime:Log("========================================")
    LiquidLime:Log("LiquidLime Mod Initialization Complete")
    LiquidLime:Log("========================================")
end

function LiquidLime:Log(msg)
    print(string.format("[%s] - %s", modName, msg))
end

addModEventListener(LiquidLime)
