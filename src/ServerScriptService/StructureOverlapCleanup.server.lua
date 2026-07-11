-- ServerScriptService/StructureOverlapCleanup.server.lua
-- Repairs known structure intersections, removes exact duplicate geometry,
-- and reports any remaining deep overlaps after the simulator-style pass.
-- Functional prompt, portal, chest, and persistence parts are never moved arbitrarily.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local UPGRADE_FOLDER_NAME = "SimulatorStructureUpgrade"
local FIND_TIMEOUT_SECONDS = 25
local WORLD_SCALE = 2.5
local APPLY_DELAY_SECONDS = 0.35

local COLORS = {
	Blue = Color3.fromRGB(73, 132, 197),
	LightBlue = Color3.fromRGB(143, 210, 255),
}

local PROTECTED_NAMES = {
	PlayerSpawn = true,
	SpawnLocation = true,
	NextAreaGate_Door = true,
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
	if found and found:IsA("Model") then
		return found
	end
	return nil
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
	if not model then
		return false
	end
	return setPart(model:FindFirstChild(name, true), size, position, options)
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
	local instance = findDescendant(root, name)
	if instance then
		instance:Destroy()
		return true
	end
	return false
end

local function repairSchoolGate(map)
	-- The add-on arch duplicated the school's own door frame. Keep only the
	-- original frame and place it just outside the portal surface.
	destroyNamed(map, "SchoolPortalArch")
	destroyNamed(map, "SchoolGateOverlapFix")

	setNamedPart(map, "P0_School_DoorFrame_Left", Vector3.new(2, 18, 1.6), Vector3.new(-8.4, 9.5, 67.5), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = true,
	})
	setNamedPart(map, "P0_School_DoorFrame_Right", Vector3.new(2, 18, 1.6), Vector3.new(8.4, 9.5, 67.5), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = true,
	})
	setNamedPart(map, "P0_School_DoorFrame_Top", Vector3.new(18.8, 2, 1.6), Vector3.new(0, 17.5, 67.5), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = true,
	})
	setNamedPart(map, "NextAreaGateFrame_BottomGlow", Vector3.new(15, 0.18, 2.4), Vector3.new(0, 1.11, 66.2), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	})
end

local function repairQuestStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "QuestStation")
	if not model then
		return
	end

	-- Move the customer counter in front of the professor instead of through
	-- the NPC body, while keeping clear gaps from the two booth posts.
	setModelPart(model, "Counter", Vector3.new(2.2, 4.2, 11.5), Vector3.new(-37.9, 2.9, -6), nil)
	setModelPart(model, "CounterTop", Vector3.new(3, 0.5, 12.5), Vector3.new(-37.5, 5.25, -6), nil)

	for index, data in ipairs({
		{ Vector3.new(-37.4, 5.75, -9.5) },
		{ Vector3.new(-37.4, 5.75, -6) },
		{ Vector3.new(-37.4, 5.75, -2.5) },
	}) do
		setModelPart(model, "BookStack_" .. tostring(index), Vector3.new(2.6, 0.45, 3), data[1], nil)
	end

	-- Put trim just outside the roof faces instead of embedding it inside.
	setModelPart(model, "RoofTrimFront", Vector3.new(27.2, 0.45, 0.45), Vector3.new(-47, 13.8, -16.75), nil)
	setModelPart(model, "RoofTrimBack", Vector3.new(27.2, 0.45, 0.45), Vector3.new(-47, 13.8, 4.75), nil)
end

local function repairChestStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "ChestStation")
	if not model then
		return
	end

	-- The added counter occupied the same volume as the functional basic chest.
	-- The chest itself is the interaction station, so the counter is removed.
	destroyNamed(model, "Counter")
	destroyNamed(model, "CounterTop")

	setModelPart(model, "RoofTrimFront", Vector3.new(27.2, 0.45, 0.45), Vector3.new(47, 13.8, -16.75), nil)
	setModelPart(model, "RoofTrimBack", Vector3.new(27.2, 0.45, 0.45), Vector3.new(47, 13.8, 4.75), nil)

	-- Seat decorative gems on their pedestals instead of leaving their bases
	-- floating above them.
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

	-- The old closed book was fully buried inside the new research desk.
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

	-- Rest the counter on the floor instead of sinking it into the slab.
	setNamedPart(map, "P0_ShopCounter", Vector3.new(17, 3.2, 3.5), Vector3.new(66, 2.4, 31), nil)

	-- Give every awning stripe a visible gap and place the awning in front of
	-- the roof rather than running through the roof volume.
	for index = 1, 7 do
		local x = 56.4 + ((index - 1) * 3.2)
		setModelPart(model, "AwningStripe_" .. tostring(index), Vector3.new(2.95, 0.45, 4.5), Vector3.new(x, 11.6, 27), {
			Orientation = Vector3.new(-12, 0, 0),
		})
	end

	-- Turn the solid shelf blocks into thin back panels and place boxes in
	-- front of them, eliminating the half-buried appearance.
	setModelPart(model, "LeftShelf", Vector3.new(4.5, 7, 0.5), Vector3.new(59, 5.2, 43.7), nil)
	setModelPart(model, "RightShelf", Vector3.new(4.5, 7, 0.5), Vector3.new(73, 5.2, 43.7), nil)
	for index, data in ipairs({
		{ Vector3.new(59, 3.5, 42.35) },
		{ Vector3.new(59, 7.1, 42.35) },
		{ Vector3.new(73, 3.5, 42.35) },
		{ Vector3.new(73, 7.1, 42.35) },
	}) do
		setModelPart(model, "ShopBox_" .. tostring(index), Vector3.new(2.7, 2.2, 2.2), data[1], nil)
	end
end

local function repairRankingStation(map, upgradeFolder)
	local model = findModel(upgradeFolder, "RankingStation")
	if not model then
		return
	end

	-- Raise the board and podiums so their bottoms sit on the base instead of
	-- penetrating halfway through it.
	setNamedPart(map, "P0_RankingWall", Vector3.new(20, 14, 2), Vector3.new(-67, 7.8, 45), nil)
	setModelPart(model, "PodiumSecond", Vector3.new(5.5, 3, 5.5), Vector3.new(-73, 2.3, 34), nil)
	setModelPart(model, "PodiumFirst", Vector3.new(5.5, 5, 5.5), Vector3.new(-67, 3.3, 34), nil)
	setModelPart(model, "PodiumThird", Vector3.new(5.5, 2, 5.5), Vector3.new(-61, 1.8, 34), nil)

	-- Put the decorative frame on the front face instead of inside the wall.
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
	if PROTECTED_NAMES[part.Name] then
		return true
	end
	if part:FindFirstChildOfClass("ProximityPrompt") then
		return true
	end
	return false
end

local function rounded(value)
	return math.floor((value * 10) + 0.5) / 10
end

local function geometryKey(part)
	local p = part.Position
	local s = part.Size
	local o = part.Orientation
	return table.concat({
		rounded(p.X), rounded(p.Y), rounded(p.Z),
		rounded(s.X), rounded(s.Y), rounded(s.Z),
		rounded(o.X), rounded(o.Y), rounded(o.Z),
	}, ":")
end

local function removeExactDuplicates(map, upgradeFolder)
	local byGeometry = {}
	local removed = 0

	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Anchored and descendant.Transparency < 0.98 then
			local key = geometryKey(descendant)
			local existing = byGeometry[key]
			if not existing or not existing.Parent then
				byGeometry[key] = descendant
			else
				local currentUpgrade = descendant:IsDescendantOf(upgradeFolder)
				local existingUpgrade = existing:IsDescendantOf(upgradeFolder)
				local removeTarget = nil

				if currentUpgrade and not isProtected(descendant) then
					removeTarget = descendant
				elseif existingUpgrade and not isProtected(existing) then
					removeTarget = existing
				elseif not isProtected(descendant) and not isProtected(existing) then
					removeTarget = descendant
				end

				if removeTarget then
					if removeTarget == existing then
						byGeometry[key] = descendant
					end
					removeTarget:Destroy()
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
	local aName = a.Name
	local bName = b.Name
	local combined = aName .. "|" .. bName

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

	if aName:find("WorldChest") and bName:find("WorldChest") then
		return true
	end
	if (aName:find("DayPad_") and bName:find("DayGift_")) or (bName:find("DayPad_") and aName:find("DayGift_")) then
		return true
	end
	return false
end

local function shouldAudit(part, upgradeFolder)
	if not part:IsA("BasePart") or not part.Anchored or part.Transparency >= 0.98 then
		return false
	end
	if not isAxisAligned(part) then
		return false
	end
	if part:IsDescendantOf(upgradeFolder) then
		return true
	end

	local name = part.Name
	for _, prefix in ipairs({
		"P0_School_DoorFrame_", "NextAreaGateFrame_", "P0_Quest", "P0_Chest",
		"P0_Research", "P0_Shop", "P0_Ranking", "P0_Attendance",
	}) do
		if string.sub(name, 1, #prefix) == prefix then
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
	local examples = {}
	for index = 1, #parts do
		local a = parts[index]
		if a.Parent then
			for otherIndex = index + 1, #parts do
				local b = parts[otherIndex]
				if b.Parent and not intentionalPair(a, b) then
					local overlapX, overlapY, overlapZ, ratio = intersectionData(a, b)
					if ratio and ratio >= 0.2 and math.min(overlapX, overlapY, overlapZ) >= 0.5 then
						suspicious += 1
						if #examples < 10 then
							table.insert(examples, a:GetFullName() .. " <-> " .. b:GetFullName())
						end
					end
				end
			end
		end
	end

	for _, example in ipairs(examples) do
		warn("[StructureOverlapAudit] Remaining suspicious pair: " .. example)
	end
	return suspicious
end

local function applyCleanup(map)
	if not map or not map.Parent then
		return
	end

	local upgradeFolder = map:FindFirstChild(UPGRADE_FOLDER_NAME)
	if not upgradeFolder then
		return
	end

	repairSchoolGate(map)
	repairQuestStation(map, upgradeFolder)
	repairChestStation(map, upgradeFolder)
	repairResearchStation(map, upgradeFolder)
	repairShopStation(map, upgradeFolder)
	repairRankingStation(map, upgradeFolder)
	repairAttendanceStation(map, upgradeFolder)

	local duplicatesRemoved = removeExactDuplicates(map, upgradeFolder)
	local suspiciousRemaining = auditRemainingOverlaps(map, upgradeFolder)

	map:SetAttribute("OverlapCleanupVersion", 1)
	map:SetAttribute("ExactDuplicatesRemoved", duplicatesRemoved)
	map:SetAttribute("SuspiciousOverlapCount", suspiciousRemaining)
	print(
		"[StructureOverlapCleanup] adjusted=7 duplicatesRemoved="
			.. tostring(duplicatesRemoved)
			.. " suspiciousRemaining="
			.. tostring(suspiciousRemaining)
	)
end

local function attachToMap(map)
	local scheduled = false
	local function scheduleCleanup()
		if scheduled then
			return
		end
		scheduled = true
		task.delay(APPLY_DELAY_SECONDS, function()
			scheduled = false
			applyCleanup(map)
		end)
	end

	map.ChildAdded:Connect(function(child)
		if child.Name == UPGRADE_FOLDER_NAME then
			scheduleCleanup()
		end
	end)
	map.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "SchoolPortalArch" or descendant.Name == "SchoolGateOverlapFix" then
			scheduleCleanup()
		end
	end)

	for _, delaySeconds in ipairs({ 0.5, 1.2, 2.5 }) do
		task.delay(delaySeconds, function()
			applyCleanup(map)
		end)
	end
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		attachToMap(child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	attachToMap(existingMap)
else
	local map = Workspace:WaitForChild(MAP_NAME, FIND_TIMEOUT_SECONDS)
	if map then
		attachToMap(map)
	else
		warn("[StructureOverlapCleanup] SimpleMap missing; cleanup disabled.")
	end
end
