main = {};

modDirectory = g_currentModDirectory or ""

modName = g_currentModName or "unknown"

function main:loadMap()
	main:Log("LiquidLime started");

	local XMLDir = modDirectory .. "xml/sprayTypes.xml";

	if fileExists(XMLDir) then
		local xmlFile = loadXMLFile("sprayTypes", XMLDir);
		main:Log("Loading file: " .. XMLDir);

		local i = 0;
		while true do
			main:Log("Creating xmlkey")
			local xmlKey = string.format("map.sprayTypes.sprayType(%d)", i);
			if not hasXMLProperty(xmlFile, xmlKey) then
				break;
			end;
			main:Log("Getting all XML Strings from the XML file")
            local name = getXMLString(xmlFile, xmlKey .."#name")
            local litersPerSecond = getXMLFloat(xmlFile, xmlKey .."#litersPerSecond")
            local typeName = getXMLString(xmlFile, xmlKey .."#type")
            local sprayGroundType = g_currentMission.fieldGroundSystem:getFieldSprayValueByName(getXMLString(xmlFile, xmlKey .."#sprayGroundType")) -- index 1
            local isBaseType = true
			main:Log("Adding SprayType 'LiquidLime'")
			g_sprayTypeManager:addSprayType(name, litersPerSecond, typeName, sprayGroundType, isBaseType)
			main:Log("Adding MaterialHolder")
			g_materialManager:addModMaterialHolder(modDirectory .. "material_holders/liquidLime_materialHolder.i3d")
			i = i + 1;
		end;	
	else
		main:Log("XML does not exist at " .. XMLDir);
	end;
	main:Log("LiquidLime finished");
end;

function main:Log(msg)
	print("[" .. modName .. "] - " .. msg .. "\n");
end;

addModEventListener(main);