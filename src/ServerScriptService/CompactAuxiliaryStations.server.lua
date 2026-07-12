-- ServerScriptService/CompactAuxiliaryStations.server.lua
-- Reduces the visual footprint of auxiliary lobby stations after all legacy
-- structure and overlap passes finish. Gameplay prompts, chests, portal parts,
-- and the school remain unchanged.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local UPGRADE_FOLDER_NAME = "SimulatorStructureUpgrade"
local FIND_TIMEOUT_SECONDS = 25
local WORLD_SCALE = 2.5

local ATTACHED_ATTRIBUTE = "CompactStationsAttachedV1"
local IN_PROGRESS_ATTRIBUTE = "CompactStationsInProgressV1"
local COMPLETE_ATTRIBUTE = "CompactStationsCompleteV1"

local PROTECTED_NAMES = {
	PlayerSpawn = true,
	SpawnLocation = true,
	NextAreaGate_Door = true,
	Area2EntranceTrigger = true,
	Area2ReturnTrigger = true,
	ChestPromptPart = true,
	WorldChestModel = true,
	WorldChestLid = true,
	WorldChestBand = true,
	P0_BasicChestPedestal = true,
	P0_RareChestPedestal = true,
	P0_EpicChestPedestal = true,
}

local STATIONS = {
	{
		Name = "Quest",
		Center = Vector3.new(-47, 0, -6),
		Scale = 0.78,
		ModelName = "QuestStation",
		PartNames = {
			"P0_QuestBooth_Floor",
			"P0_QuestBooth_Back",
			"P0_QuestBooth_Roof",
			"P0_QuestBooth_PostFront",
			"P0_QuestBooth_PostBack",
			"P0_QuestBoard",
		},
	},
	{
		Name = "Chest",
		Center = Vector3.new(47, 0, -6),
		Scale = 0.78,
		ModelName = "ChestStation",
		PartNames = {
			"P0_ChestBooth_Floor",
			"P0_ChestBooth_Back",
			"P0_ChestBooth_Roof",
			"P0_ChestBooth_PostFront",
			"P0_ChestBooth_PostBack",
			"P0_ChestSign",
		},
	},
	{
		Name = "Research",
		Center = Vector3.new(-54, 0, -55),
		Scale = 0.82,
		ModelName = "ResearchStation",
		PartNames = {
			"P0_ResearchKiosk_Base",
			"P0_ResearchKiosk_Back",
			"P0_ResearchKiosk_Roof",
			"P0_ResearchBoard",
		},
	},
	{
		Name = "Shop",
		Center = Vector3.new(66, 0, 38),
		Scale = 0.78,
		ModelName = "ShopStation",
		PartNames = {
			"P0_ShopBase",
			"P0_ShopBack",
			"P0_ShopRoof",
			"P0_ShopCounter",
			"P0_ShopSign",
		},
	},
	{
		Name = "Ranking",
		Center = Vector3.new(-67, 0, 39),
		Scale = 0.85,
		ModelName = "RankingStation",
		PartNames = {
			"P0_RankingBase",
			"P0_RankingWall",
		},
	},
	{
		Name = "Attendance",
		Center = Vector3.new(48, 0, -61),
		Scale = 0.85,
		ModelName = "AttendanceStation",
		PartNames = {
			"P0_AttendanceBase",
			"P0_AttendanceBoard",
		},
	},
}

local function w(value)
	return value * WORLD_SCALE
end

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function isProtected(part)
	if PROTECTED_NAMES[part.Name] then
		return true
	end
	if part:FindFirstChildOfClass("ProximityPrompt") then
		return true
	end
	return false
end

local function compactPart(part, center, scale)
	if not part or not part.Parent or not part:IsA("BasePart") or isProtected(part) then
		return false
	end
	if part:GetAttribute("CompactStationScaledV1") then
		return false
	end

	local offset = part.Position - center
	part.Position = center + (offset * scale)
	part.Size = Vector3.new(
		math.max(part.Size.X * scale, 0.2),
		math.max(part.Size.Y * scale, 0.2),
		math.max(part.Size.Z * scale, 0.2)
	)
	part:SetAttribute("CompactStationScaledV1", true)
	return true
end

local function compactNamedParts(map, config, center)
	local compacted = 0
	for _, name in ipairs(config.PartNames) do
		local part = findDescendant(map, name)
		if compactPart(part, center, config.Scale) then
			compacted += 1
		end
	end
	return compacted
end

local function compactUpgradeModel(upgradeFolder, config, center)
	local model = upgradeFolder and upgradeFolder:FindFirstChild(config.ModelName)
	if not model then
		return 0
	end

	local compacted = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and compactPart(descendant, center, config.Scale) then
			compacted += 1
		end
	end
	return compacted
end

local function waitForReady(map)
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	while os.clock() < deadline do
		local upgradeFolder = map:FindFirstChild(UPGRADE_FOLDER_NAME)
		local cleanupReady = map:GetAttribute("OverlapCleanupCompleteV2") == true
		local schoolReady = map:GetAttribute("SchoolRebuildCompleteV5") == true
		if upgradeFolder and cleanupReady and schoolReady then
			task.wait(0.2)
			return upgradeFolder
		end
		task.wait(0.05)
	end
	return map:FindFirstChild(UPGRADE_FOLDER_NAME)
end

local function applyCompactLayout(map)
	if not map or not map.Parent then
		return
	end
	if map:GetAttribute(COMPLETE_ATTRIBUTE) or map:GetAttribute(IN_PROGRESS_ATTRIBUTE) then
		return
	end

	map:SetAttribute(IN_PROGRESS_ATTRIBUTE, true)
	local success, failure = xpcall(function()
		local upgradeFolder = waitForReady(map)
		if not upgradeFolder then
			error("SimulatorStructureUpgrade missing")
		end

		local totalCompacted = 0
		for _, config in ipairs(STATIONS) do
			local center = w(config.Center)
			local stationCount = compactNamedParts(map, config, center)
			stationCount += compactUpgradeModel(upgradeFolder, config, center)
			totalCompacted += stationCount
			map:SetAttribute("Compact" .. config.Name .. "Scale", config.Scale)
		end

		map:SetAttribute(COMPLETE_ATTRIBUTE, true)
		map:SetAttribute("CompactStationPartCount", totalCompacted)
		print(
			"[CompactAuxiliaryStations] complete=true compactedParts="
				.. tostring(totalCompacted)
				.. " quest=0.78 chest=0.78 shop=0.78 research=0.82 ranking=0.85 attendance=0.85"
		)
	end, debug.traceback)

	map:SetAttribute(IN_PROGRESS_ATTRIBUTE, false)
	if not success then
		warn("[CompactAuxiliaryStations] Failed: " .. tostring(failure))
	end
end

local function attach(map)
	if not map or not map.Parent or map:GetAttribute(ATTACHED_ATTRIBUTE) then
		return
	end
	map:SetAttribute(ATTACHED_ATTRIBUTE, true)
	task.spawn(function()
		applyCompactLayout(map)
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		attach(child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	attach(existingMap)
else
	local map = Workspace:WaitForChild(MAP_NAME, FIND_TIMEOUT_SECONDS)
	if map then
		attach(map)
	else
		warn("[CompactAuxiliaryStations] SimpleMap missing; compact layout disabled.")
	end
end
