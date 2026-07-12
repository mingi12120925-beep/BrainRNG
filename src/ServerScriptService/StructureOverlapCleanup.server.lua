-- ServerScriptService/StructureOverlapCleanup.server.lua
-- Final one-pass overlap cleanup for non-school lobby stations.
-- Waits until the stable school and simulator styling are complete, repairs known
-- intersections, removes exact duplicate decorations, and audits once.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local UPGRADE_FOLDER_NAME = "SimulatorStructureUpgrade"
local FIND_TIMEOUT_SECONDS = 25
local WORLD_SCALE = 2.5
local ATTACHED_ATTRIBUTE = "OverlapCleanupAttachedV2"
local IN_PROGRESS_ATTRIBUTE = "OverlapCleanupInProgressV2"
local COMPLETE_ATTRIBUTE = "OverlapCleanupCompleteV2"

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
}

local function w(value)
	return value * WORLD_SCALE
end

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function findModel(root, name)
	local found = findDescendant(root, name)
	return found and found:IsA("Model") and found or nil
end

local function setPart(part, size, position, options)
	if not part or not part:IsA("BasePart") then
		return false
	end

	options = options or {}
	if size then
		part.Size = w(size)
	end
	if position then
		part.Position = w(position)
	end
	if options.Orientation then
		part.Orientation = options.Orientation
	end
	if options.Color then
		part.Color = options.Color
	end
	if options.Material then
		part.Material = options.Material
	end
	if options.Transparency ~= nil then
		part.Transparency = options.Transparency
	end
	if options.CanCollide ~= nil then
		part.CanCollide = options.CanCollide
	end
	if options.CanTouch ~= nil then
		part.CanTouch = options.CanTouch
	end
	if options.CanQuery ~= nil then
		part.CanQuery = options.CanQuery
	end
	if options.CastShadow ~= nil then
		part.CastShadow = options.CastShadow
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return true
end

local function setNamedPart(root, name, size, position, options)
	return setPart(findDescendant(root, name), size, position, options)
end

local function setModelPart(model, name, size, position, options)
	return model and setPart(model:FindFirstChild(name, true), size, position, options) or false
end

local function hideNamedPart(root, name)
	local part = findDescendant(root, name)
	if not part or not part:IsA("BasePart") then
		return false
	end
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return true
end

local function destroyNamed(root, name)
	local instance = root and findDescendant(root, name)
	if instance then
		instance:Destroy()
		return true
	end
	return false
end

local function repairQuestStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "QuestStation")
	if not model then
		return
	end

	-- Booth floor ends at X=-34. Branch path begins at X=-34: edge contact only.
	setNamedPart(map, "P0_QuestBooth_Floor", Vector3.new(26, 0.8, 20), Vector3.new(-47, 0.4, -6), nil)
	setNamedPart(map, "P0_QuestBranchPath", Vector3.new(26, 0.36, 12), Vector3.new(-21, 0.45, -6), nil)
	-- Post bottoms are Y=0.9, leaving 0.1 stud above the Y=0.8 floor top.
	setNamedPart(map, "P0_QuestBooth_PostFront", Vector3.new(1.5, 12, 1.5), Vector3.new(-38.5, 6.9, -13), nil)
	setNamedPart(map, "P0_QuestBooth_PostBack", Vector3.new(1.5, 12, 1.5), Vector3.new(-38.5, 6.9, 1), nil)

	setModelPart(model, "Counter", Vector3.new(2.2, 4.2, 11.5), Vector3.new(-37.9, 2.9, -6), nil)
	setModelPart(model, "CounterTop", Vector3.new(3, 0.5, 12.5), Vector3.new(-37.5, 5.25, -6), nil)
	for index, z in ipairs({ -9.5, -6, -2.5 }) do
		setModelPart(model, "BookStack_" .. tostring(index), Vector3.new(2.6, 0.45, 3), Vector3.new(-37.4, 5.75, z), nil)
	end
	setModelPart(model, "RoofTrimFront", Vector3.new(27.2, 0.45, 0.45), Vector3.new(-47, 13.8, -16.75), nil)
	setModelPart(model, "RoofTrimBack", Vector3.new(27.2, 0.45, 0.45), Vector3.new(-47, 13.8, 4.75), nil)
end

local function repairChestStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "ChestStation")
	if not model then
		return
	end

	-- Mirror of Quest: floor and branch path touch only at X=34.
	setNamedPart(map, "P0_ChestBooth_Floor", Vector3.new(26, 0.8, 20), Vector3.new(47, 0.4, -6), nil)
	setNamedPart(map, "P0_ChestBranchPath", Vector3.new(26, 0.36, 12), Vector3.new(21, 0.45, -6), nil)
	setNamedPart(map, "P0_ChestBooth_PostFront", Vector3.new(1.5, 12, 1.5), Vector3.new(38.5, 6.9, -13), nil)
	setNamedPart(map, "P0_ChestBooth_PostBack", Vector3.new(1.5, 12, 1.5), Vector3.new(38.5, 6.9, 1), nil)

	destroyNamed(model, "Counter")
	destroyNamed(model, "CounterTop")
	setModelPart(model, "RoofTrimFront", Vector3.new(27.2, 0.45, 0.45), Vector3.new(47, 13.8, -16.75), nil)
	setModelPart(model, "RoofTrimBack", Vector3.new(27.2, 0.45, 0.45), Vector3.new(47, 13.8, 4.75), nil)
	setModelPart(model, "RareGem_Base", nil, Vector3.new(49, 3.05, -11), nil)
	setModelPart(model, "RareGem_Core", nil, Vector3.new(49, 4.7, -11), nil)
	setModelPart(model, "EpicGem_Base", nil, Vector3.new(49, 3.05, -1), nil)
	setModelPart(model, "EpicGem_Core", nil, Vector3.new(49, 4.7, -1), nil)
end

local function repairResearchStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "ResearchStation")
	if not model then
		return
	end
	hideNamedPart(map, "P0_ResearchBook")
	setModelPart(model, "Desk", Vector3.new(16, 3.6, 4.5), Vector3.new(-54, 2.6, -50), nil)
	setModelPart(model, "DeskTop", Vector3.new(17, 0.5, 5.2), Vector3.new(-54, 4.65, -50), nil)
	setModelPart(model, "OpenIndexBook_Left", nil, Vector3.new(-56.25, 5.2, -50), nil)
	setModelPart(model, "OpenIndexBook_Right", nil, Vector3.new(-51.75, 5.2, -50), nil)
	setModelPart(model, "OpenIndexBook_Spine", nil, Vector3.new(-54, 5.08, -50), nil)
end

local function repairShopStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "ShopStation")
	if not model then
		return
	end
	setNamedPart(map, "P0_ShopCounter", Vector3.new(17, 3.2, 3.5), Vector3.new(66, 2.4, 31), nil)
	for index = 1, 7 do
		local x = 56.4 + ((index - 1) * 3.2)
		setModelPart(model, "AwningStripe_" .. tostring(index), Vector3.new(2.95, 0.45, 4.5), Vector3.new(x, 11.6, 27), {
			Orientation = Vector3.new(-12, 0, 0),
		})
	end
	setModelPart(model, "LeftShelf", Vector3.new(4.5, 7, 0.5), Vector3.new(59, 5.2, 43.7), nil)
	setModelPart(model, "RightShelf", Vector3.new(4.5, 7, 0.5), Vector3.new(73, 5.2, 43.7), nil)
	for index, position in ipairs({
		Vector3.new(59, 3.5, 42.35),
		Vector3.new(59, 7.1, 42.35),
		Vector3.new(73, 3.5, 42.35),
		Vector3.new(73, 7.1, 42.35),
	}) do
		setModelPart(model, "ShopBox_" .. tostring(index), Vector3.new(2.7, 2.2, 2.2), position, nil)
	end
end

local function repairRankingStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "RankingStation")
	if not model then
		return
	end
	setNamedPart(map, "P0_RankingWall", Vector3.new(20, 14, 2), Vector3.new(-67, 7.8, 45), nil)
	setModelPart(model, "PodiumSecond", Vector3.new(5.5, 3, 5.5), Vector3.new(-73, 2.3, 34), nil)
	setModelPart(model, "PodiumFirst", Vector3.new(5.5, 5, 5.5), Vector3.new(-67, 3.3, 34), nil)
	setModelPart(model, "PodiumThird", Vector3.new(5.5, 2, 5.5), Vector3.new(-61, 1.8, 34), nil)
	setModelPart(model, "FrameTop", Vector3.new(22, 1, 0.5), Vector3.new(-67, 15.3, 43.7), nil)
	setModelPart(model, "FrameBottom", Vector3.new(22, 1, 0.5), Vector3.new(-67, 1.3, 43.7), nil)
	setModelPart(model, "FrameLeft", Vector3.new(1, 13, 0.5), Vector3.new(-77.5, 8.3, 43.7), nil)
	setModelPart(model, "FrameRight", Vector3.new(1, 13, 0.5), Vector3.new(-56.5, 8.3, 43.7), nil)
end

local function repairAttendanceStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "AttendanceStation")
	if not model then
		return
	end
	setNamedPart(map, "P0_AttendanceBoard", Vector3.new(18, 10, 1.5), Vector3.new(48, 5.8, -67), nil)
	for day = 1, 7 do
		local x = 40.5 + ((day - 1) * 2.5)
		setModelPart(model, "DayPad_" .. tostring(day), Vector3.new(2, 0.65, 3.2), Vector3.new(x, 1.125, -58.5), nil)
		setModelPart(model, "DayGift_" .. tostring(day), Vector3.new(1.25, 1.25, 1.25), Vector3.new(x, 2.075, -58.5), nil)
	end
end

local function isProtected(part)
	return PROTECTED_NAMES[part.Name] or part:FindFirstChildOfClass("ProximityPrompt") ~= nil
end

local function rounded(value)
	return math.floor((value * 10) + 0.5) / 10
end

local function geometryKey(part)
	local p, s, o = part.Position, part.Size, part.Orientation
	return table.concat({
		rounded(p.X), rounded(p.Y), rounded(p.Z),
		rounded(s.X), rounded(s.Y), rounded(s.Z),
		rounded(o.X), rounded(o.Y), rounded(o.Z),
	}, ":")
end

local function removeExactDuplicates(map, upgradeFolder)
	local byGeometry = {}
	local removed = 0
	for _, part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") and part.Anchored and part.Transparency < 0.98 then
			local key = geometryKey(part)
			local existing = byGeometry[key]
			if not existing or not existing.Parent then
				byGeometry[key] = part
			else
				local target
				if part:IsDescendantOf(upgradeFolder) and not isProtected(part) then
					target = part
				elseif existing:IsDescendantOf(upgradeFolder) and not isProtected(existing) then
					target = existing
				elseif not isProtected(part) and not isProtected(existing) then
					target = part
				end
				if target then
					if target == existing then
						byGeometry[key] = part
					end
					target:Destroy()
					removed += 1
				end
			end
		end
	end
	return removed
end

local function isAxisAligned(part)
	local o = part.Orientation
	local function nearRightAngle(value)
		local normalized = math.abs(value) % 90
		return normalized < 0.5 or normalized > 89.5
	end
	return nearRightAngle(o.X) and nearRightAngle(o.Y) and nearRightAngle(o.Z)
end

local function intersectionData(a, b)
	local delta = a.Position - b.Position
	local overlapX = ((a.Size.X + b.Size.X) * 0.5) - math.abs(delta.X)
	local overlapY = ((a.Size.Y + b.Size.Y) * 0.5) - math.abs(delta.Y)
	local overlapZ = ((a.Size.Z + b.Size.Z) * 0.5) - math.abs(delta.Z)
	if overlapX <= 0 or overlapY <= 0 or overlapZ <= 0 then
		return nil
	end
	local overlapVolume = overlapX * overlapY * overlapZ
	local smallerVolume = math.min(a.Size.X * a.Size.Y * a.Size.Z, b.Size.X * b.Size.Y * b.Size.Z)
	return overlapX, overlapY, overlapZ, overlapVolume / math.max(smallerVolume, 0.001)
end

local function intentionalPair(a, b)
	local combined = a.Name .. "|" .. b.Name
	if a.Parent == b.Parent then
		if combined:find("Book") or combined:find("Gem") or combined:find("ProfessorHat") then
			return true
		end
		if combined:find("Counter") and combined:find("Top") then
			return true
		end
		if combined:find("Desk") and combined:find("Top") then
			return true
		end
	end
	if a.Name:find("WorldChest") and b.Name:find("WorldChest") then
		return true
	end
	if (a.Name:find("DayPad_") and b.Name:find("DayGift_")) or (b.Name:find("DayPad_") and a.Name:find("DayGift_")) then
		return true
	end
	return false
end

local function shouldAudit(part, upgradeFolder)
	if not part:IsA("BasePart") or not part.Anchored or part.Transparency >= 0.98 or not isAxisAligned(part) then
		return false
	end
	if part:IsDescendantOf(upgradeFolder) then
		return true
	end
	for _, prefix in ipairs({ "P0_Quest", "P0_Chest", "P0_Research", "P0_Shop", "P0_Ranking", "P0_Attendance" }) do
		if string.sub(part.Name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function auditRemainingOverlaps(map, upgradeFolder)
	local parts = {}
	for _, descendant in ipairs(map:GetDescendants()) do
		if shouldAudit(descendant, upgradeFolder) then
			table.insert(parts, descendant)
		end
	end

	local suspicious = 0
	for index = 1, #parts - 1 do
		local a = parts[index]
		for otherIndex = index + 1, #parts do
			local b = parts[otherIndex]
			if a.Parent and b.Parent and not intentionalPair(a, b) then
				local overlapX, overlapY, overlapZ, ratio = intersectionData(a, b)
				if ratio and ratio >= 0.2 and math.min(overlapX, overlapY, overlapZ) >= 0.5 then
					suspicious += 1
					warn("[StructureOverlapAudit] Remaining suspicious pair: " .. a:GetFullName() .. " <-> " .. b:GetFullName())
				end
			end
		end
	end
	return suspicious
end

local function waitForReady(map)
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	local upgradeFolder
	repeat
		upgradeFolder = map:FindFirstChild(UPGRADE_FOLDER_NAME)
		local signReady = map:GetAttribute("SignStyle") ~= nil
		local schoolReady = map:GetAttribute("SchoolRebuildCompleteV5") == true
		if upgradeFolder and signReady and schoolReady then
			task.wait(0.25)
			return upgradeFolder
		end
		task.wait(0.05)
	until os.clock() >= deadline
	return upgradeFolder
end

local function applyCleanup(map)
	if not map or not map.Parent or map:GetAttribute(COMPLETE_ATTRIBUTE) or map:GetAttribute(IN_PROGRESS_ATTRIBUTE) then
		return
	end
	map:SetAttribute(IN_PROGRESS_ATTRIBUTE, true)

	local success, failure = xpcall(function()
		local upgradeFolder = waitForReady(map)
		if not upgradeFolder then
			error("SimulatorStructureUpgrade missing")
		end

		repairQuestStation(map, upgradeFolder)
		repairChestStation(map, upgradeFolder)
		repairResearchStation(map, upgradeFolder)
		repairShopStation(map, upgradeFolder)
		repairRankingStation(map, upgradeFolder)
		repairAttendanceStation(map, upgradeFolder)

		local duplicatesRemoved = removeExactDuplicates(map, upgradeFolder)
		local suspiciousRemaining = auditRemainingOverlaps(map, upgradeFolder)
		map:SetAttribute("OverlapCleanupVersion", 2)
		map:SetAttribute("ExactDuplicatesRemoved", duplicatesRemoved)
		map:SetAttribute("SuspiciousOverlapCount", suspiciousRemaining)
		map:SetAttribute(COMPLETE_ATTRIBUTE, true)
		print(
			"[StructureOverlapCleanup] stableSinglePass=true adjusted=6 duplicatesRemoved="
				.. tostring(duplicatesRemoved)
				.. " suspiciousRemaining="
				.. tostring(suspiciousRemaining)
		)
	end, debug.traceback)

	map:SetAttribute(IN_PROGRESS_ATTRIBUTE, false)
	if not success then
		warn("[StructureOverlapCleanup] Failed: " .. tostring(failure))
	end
end

local function attach(map)
	if not map or not map.Parent or map:GetAttribute(ATTACHED_ATTRIBUTE) then
		return
	end
	map:SetAttribute(ATTACHED_ATTRIBUTE, true)
	task.spawn(function()
		applyCleanup(map)
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
		warn("[StructureOverlapCleanup] SimpleMap missing; cleanup disabled.")
	end
end
