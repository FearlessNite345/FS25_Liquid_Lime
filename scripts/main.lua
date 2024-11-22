main = {}

modDirectory = g_currentModDirectory or ""
modName = g_currentModName or "unknown"

function main:loadMap()
    main:Log("========================================")
    main:Log("Initializing LiquidLime Mod")
    main:Log("========================================")

    local XMLDir = modDirectory .. "xml/sprayTypes.xml"

    if fileExists(XMLDir) then
        main:Log("Found sprayTypes.xml at: " .. XMLDir)
        local xmlFile = loadXMLFile("sprayTypes", XMLDir)

        local i = 0
        while true do
            main:Log("Processing XML entry at index: " .. i)
            local xmlKey = string.format("map.sprayTypes.sprayType(%d)", i)

            if not hasXMLProperty(xmlFile, xmlKey) then
                main:Log("No further entries found. Stopping processing.")
                break
            end

            main:Log("Extracting data for sprayType at: " .. xmlKey)
            local name = getXMLString(xmlFile, xmlKey .. "#name")
            local litersPerSecond = getXMLFloat(xmlFile, xmlKey .. "#litersPerSecond")
            local typeName = getXMLString(xmlFile, xmlKey .. "#type")
            local sprayGroundType = g_currentMission.fieldGroundSystem:getFieldSprayValueByName(
                getXMLString(xmlFile, xmlKey .. "#sprayGroundType")
            )

            if name and litersPerSecond and typeName and sprayGroundType then
                main:Log("Adding SprayType - Name: " .. name .. ", Liters/Sec: " .. litersPerSecond .. ", Type: " .. typeName)
                local isBaseType = true
                g_sprayTypeManager:addSprayType(name, litersPerSecond, typeName, sprayGroundType, isBaseType)

                local materialHolderPath = modDirectory .. "material_holders/liquidLime_materialHolder.i3d"
                main:Log("Adding MaterialHolder at: " .. materialHolderPath)
                g_materialManager:addModMaterialHolder(materialHolderPath)
            else
                main:Log("ERROR: Missing or invalid data for sprayType at: " .. xmlKey)
            end

            i = i + 1
        end
    else
        main:Log("ERROR: sprayTypes.xml not found at: " .. XMLDir)
    end

    main:Log("========================================")
    main:Log("LiquidLime Mod Initialization Complete")
    main:Log("========================================")
end

function main:Log(msg)
    print(string.format("[%s] - %s", modName, msg))
end

addModEventListener(main)
