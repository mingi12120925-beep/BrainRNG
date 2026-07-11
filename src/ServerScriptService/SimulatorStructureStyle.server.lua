-- ServerScriptService/SimulatorStructureStyle.server.lua
-- Restyles the existing lobby into readable Roblox simulator-style stations.
-- Functional parts, prompts, remotes, and persistence logic are left untouched.
-- Project rule: no floating BillboardGui world UI.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local UPGRADE_FOLDER_NAME = "SimulatorStructureUpgrade"
local FIND_TIMEOUT_SECONDS = 25
local WORLD_SCALE = 2.5

local COLORS = {
	WarmWhite = Color3.fromRGB(245, 241, 226),
	Ink = Color3.fromRGB(31, 42, 58),
	Blue = Color3.fromRGB(73, 132, 197),
	LightBlue = Color3.fromRGB(143, 210, 255),
	Lime = Color3.fromRGB(112, 214, 92),
	Yellow = Color3.fromRGB(235, 181, 44),
	Gold = Color3.fromRGB(213, 145, 39),
	Purple = Color3.fromRGB(136, 91, 213),
	Pink = Color3.fromRGB(225, 93, 145),
	Cyan = Color3.fromRGB(47, 168, 195),
	Wood = Color3.fromRGB(126, 84, 52),
	DarkWood = Color3.fromRGB(88, 56, 39),
	Stone = Color3.fromRGB(181, 191, 201),
	DarkStone = Color3.fromRGB(95, 108, 123),
	Bronze = Color3.fromRGB(169, 103, 58),
	Silver = Color3.fromRGB(184, 194, 205),
}

local function w(value)
	return value * WORLD_SCALE
end

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function waitForDescendant(root, name, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	repeat
		local found = findDescendant(root, name)
		if found then
			return found
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local function styleExisting(root, name, size, position, color, material, options)
	local item = findDescendant(root, name)
	if not item or not item:IsA("BasePart") then
		return nil
	end

	options = options or {}
	if size then
		item.Size = w(size)
	end
	if position then
		item.Position = w(position)
	end
	if color then
		item.Color = color
	end
	if material then
		item.Material = material
	end
	if options.Orientation then
		item.Orientation = options.Orientation
	end
	if options.Transparency ~= nil then
		item.Transparency = options.Transparency
	end
	if options.CanCollide ~= nil then
		item.CanCollide = options.CanCollide
	end
	if options.CanTouch ~= nil then
		item.CanTouch = options.CanTouch
	end
	if options.CanQuery ~= nil then
		item.CanQuery = options.CanQuery
	end
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	return item
end

local function createPart(parent, name, size, position, color, material, options)
	options = options or {}
	local item = Instance.new("Part")
	item.Name = name
	item.Size = w(size)
	item.Position = w(position)
	item.Anchored = true
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.CanCollide = options.CanCollide == true
	item.CanTouch = false
	item.CanQuery = false
	item.CastShadow = options.CastShadow ~= false
	item.Transparency = options.Transparency or 0
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	if options.Shape then
		item.Shape = options.Shape
	end
	if options.Orientation then
		item.Orientation = options.Orientation
	end
	item.Parent = parent
	return item
end

local function createModel(parent, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function createCylinder(parent, name, diameter, height, position, color, material)
	return createPart(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		position,
		color,
		material,
		{
			Shape = Enum.PartType.Cylinder,
			Orientation = Vector3.new(0, 0, 90),
		}
	)
end

local function createBook(parent, name, position, color)
	createPart(parent, name .. "_Left", Vector3.new(4.8, 0.45, 6), position + Vector3.new(-2.25, 0, 0), color, Enum.Material.SmoothPlastic, {
		Orientation = Vector3.new(0, 0, -10),
	})
	createPart(parent, name .. "_Right", Vector3.new(4.8, 0.45, 6), position + Vector3.new(2.25, 0, 0), color, Enum.Material.SmoothPlastic, {
		Orientation = Vector3.new(0, 0, 10),
	})
	createPart(parent, name .. "_Spine", Vector3.new(0.45, 0.7, 6.1), position + Vector3.new(0, -0.12, 0), COLORS.DarkWood, Enum.Material.SmoothPlastic)
end

local function createGem(parent, name, position, color, scale)
	scale = scale or 1
	createPart(parent, name .. "_Core", Vector3.new(2.7, 4.8, 2.7) * scale, position, color, Enum.Material.Neon, {
		Orientation = Vector3.new(0, 45, 0),
	})
	createPart(parent, name .. "_Base", Vector3.new(3.4, 0.6, 3.4) * scale, position - Vector3.new(0, 2.5 * scale, 0), COLORS.Ink, Enum.Material.SmoothPlastic)
end

local function upgradeCentralPlaza(map, parent)
	local model = createModel(parent, "CentralKnowledgePlaza")

	styleExisting(map, "P0_RollPedestal_Lower", Vector3.new(1.2, 16, 16), Vector3.new(0, 0.9, -6), COLORS.Stone, Enum.Material.Concrete, {
		Orientation = Vector3.new(0, 0, 90),
		CanCollide = true,
	})
	styleExisting(map, "P0_RollPedestal_Upper", Vector3.new(0.65, 12, 12), Vector3.new(0, 1.85, -6), COLORS.Blue, Enum.Material.SmoothPlastic, {
		Orientation = Vector3.new(0, 0, 90),
		CanCollide = true,
	})

	local rollButton = styleExisting(map, "RollButton", nil, nil, nil, nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	if rollButton then
		rollButton:SetAttribute("VisualOnly", true)
	end

	createBook(model, "KnowledgeBook", Vector3.new(0, 4.1, -6), COLORS.WarmWhite)
	createGem(model, "KnowledgeCrystal", Vector3.new(0, 8.3, -6), COLORS.Lime, 0.85)

	for index, offset in ipairs({
		Vector3.new(-6.4, 2.1, -6),
		Vector3.new(6.4, 2.1, -6),
		Vector3.new(0, 2.1, -12.4),
		Vector3.new(0, 2.1, 0.4),
	}) do
		createPart(model, "PlazaLight_" .. index, Vector3.new(1.1, 0.45, 1.1), offset, COLORS.LightBlue, Enum.Material.Neon)
	end
end

local function upgradeGate(map, parent)
	local model = createModel(parent, "SchoolPortalArch")

	createPart(model, "LeftPillar", Vector3.new(4.5, 20, 4.5), Vector3.new(-10.5, 10.5, 66.4), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "RightPillar", Vector3.new(4.5, 20, 4.5), Vector3.new(10.5, 10.5, 66.4), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "TopBeam", Vector3.new(25.5, 4.2, 4.5), Vector3.new(0, 20.7, 66.4), COLORS.Blue, Enum.Material.SmoothPlastic)
	createCylinder(model, "LeftCap", 5.5, 1.2, Vector3.new(-10.5, 21.9, 66.4), COLORS.LightBlue, Enum.Material.SmoothPlastic)
	createCylinder(model, "RightCap", 5.5, 1.2, Vector3.new(10.5, 21.9, 66.4), COLORS.LightBlue, Enum.Material.SmoothPlastic)
	createPart(model, "PortalFloorGlow", Vector3.new(16, 0.28, 5.8), Vector3.new(0, 1.05, 66.2), COLORS.LightBlue, Enum.Material.Neon, {
		Transparency = 0.25,
	})

	styleExisting(map, "NextAreaGate_Door", Vector3.new(14, 15, 0.8), Vector3.new(0, 8.5, 66.1), COLORS.LightBlue, Enum.Material.ForceField, {
		Transparency = 0.48,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})
end

local function upgradeQuestStation(map, parent)
	local model = createModel(parent, "QuestStation")

	styleExisting(map, "P0_QuestBooth_Floor", Vector3.new(26, 0.8, 20), Vector3.new(-47, 0.4, -6), COLORS.Stone, Enum.Material.Concrete, { CanCollide = true })
	styleExisting(map, "P0_QuestBooth_Back", Vector3.new(2, 12, 18), Vector3.new(-55, 6.5, -6), COLORS.Yellow, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_QuestBooth_Roof", Vector3.new(27, 1.5, 21), Vector3.new(-47, 13.8, -6), COLORS.Yellow, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_QuestBooth_PostFront", Vector3.new(1.5, 12, 1.5), Vector3.new(-38.5, 6.5, -13), COLORS.WarmWhite, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_QuestBooth_PostBack", Vector3.new(1.5, 12, 1.5), Vector3.new(-38.5, 6.5, 1), COLORS.WarmWhite, Enum.Material.SmoothPlastic, { CanCollide = true })

	createPart(model, "Counter", Vector3.new(2.4, 4.2, 14), Vector3.new(-42.8, 2.5, -6), COLORS.Wood, Enum.Material.WoodPlanks)
	createPart(model, "CounterTop", Vector3.new(3.3, 0.55, 15), Vector3.new(-42.2, 4.7, -6), COLORS.DarkWood, Enum.Material.WoodPlanks)
	createPart(model, "RoofTrimFront", Vector3.new(27.5, 0.65, 1), Vector3.new(-47, 13.2, -15.8), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "RoofTrimBack", Vector3.new(27.5, 0.65, 1), Vector3.new(-47, 13.2, 3.8), COLORS.WarmWhite, Enum.Material.SmoothPlastic)

	for index, data in ipairs({
		{ Vector3.new(-41.3, 5.45, -10), COLORS.Blue },
		{ Vector3.new(-41.3, 5.55, -6), COLORS.Pink },
		{ Vector3.new(-41.3, 5.45, -2), COLORS.Lime },
	}) do
		createPart(model, "BookStack_" .. index, Vector3.new(2.6, 0.45, 3.2), data[1], data[2], Enum.Material.SmoothPlastic)
	end

	createPart(model, "ProfessorHat", Vector3.new(4.2, 0.8, 4.2), Vector3.new(-41.5, 10.6, -6), COLORS.Ink, Enum.Material.SmoothPlastic)
	createPart(model, "ProfessorHatTop", Vector3.new(2.4, 1.5, 2.4), Vector3.new(-41.5, 11.6, -6), COLORS.Ink, Enum.Material.SmoothPlastic)
end

local function upgradeChestStation(map, parent)
	local model = createModel(parent, "ChestStation")

	styleExisting(map, "P0_ChestBooth_Floor", Vector3.new(26, 0.8, 20), Vector3.new(47, 0.4, -6), COLORS.Stone, Enum.Material.Concrete, { CanCollide = true })
	styleExisting(map, "P0_ChestBooth_Back", Vector3.new(2, 12, 18), Vector3.new(55, 6.5, -6), COLORS.Blue, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ChestBooth_Roof", Vector3.new(27, 1.5, 21), Vector3.new(47, 13.8, -6), COLORS.Blue, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ChestBooth_PostFront", Vector3.new(1.5, 12, 1.5), Vector3.new(38.5, 6.5, -13), COLORS.WarmWhite, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ChestBooth_PostBack", Vector3.new(1.5, 12, 1.5), Vector3.new(38.5, 6.5, 1), COLORS.WarmWhite, Enum.Material.SmoothPlastic, { CanCollide = true })

	createPart(model, "Counter", Vector3.new(2.4, 4.2, 14), Vector3.new(42.8, 2.5, -6), COLORS.Wood, Enum.Material.WoodPlanks)
	createPart(model, "CounterTop", Vector3.new(3.3, 0.55, 15), Vector3.new(42.2, 4.7, -6), COLORS.Gold, Enum.Material.Metal)
	createPart(model, "RoofTrimFront", Vector3.new(27.5, 0.65, 1), Vector3.new(47, 13.2, -15.8), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "RoofTrimBack", Vector3.new(27.5, 0.65, 1), Vector3.new(47, 13.2, 3.8), COLORS.WarmWhite, Enum.Material.SmoothPlastic)

	styleExisting(map, "P0_BasicChestPedestal", Vector3.new(7.5, 2.2, 7.5), Vector3.new(41.5, 1.5, -6), COLORS.WarmWhite, Enum.Material.Marble, { CanCollide = true })
	styleExisting(map, "P0_RareChestPedestal", Vector3.new(6.2, 1.8, 6.2), Vector3.new(49, 1.2, -11), COLORS.Purple, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_EpicChestPedestal", Vector3.new(6.2, 1.8, 6.2), Vector3.new(49, 1.2, -1), COLORS.Gold, Enum.Material.SmoothPlastic, { CanCollide = true })

	styleExisting(map, "WorldChestModel", Vector3.new(8.5, 5.5, 7.5), Vector3.new(41.5, 5.3, -6), COLORS.Wood, Enum.Material.WoodPlanks, { CanCollide = true, CanQuery = true })
	styleExisting(map, "WorldChestLid", Vector3.new(9.3, 1.25, 8.1), Vector3.new(41.5, 8.25, -6), COLORS.Gold, Enum.Material.Metal)
	styleExisting(map, "WorldChestBand", Vector3.new(1.15, 6.1, 8.2), Vector3.new(41.5, 5.45, -6), COLORS.Gold, Enum.Material.Metal)

	createGem(model, "RareGem", Vector3.new(49, 5.1, -11), COLORS.Purple, 0.55)
	createGem(model, "EpicGem", Vector3.new(49, 5.1, -1), COLORS.Gold, 0.55)
end

local function upgradeResearchStation(map, parent)
	local model = createModel(parent, "ResearchStation")

	styleExisting(map, "P0_ResearchKiosk_Base", Vector3.new(24, 0.8, 16), Vector3.new(-54, 0.4, -55), COLORS.Stone, Enum.Material.Concrete, { CanCollide = true })
	styleExisting(map, "P0_ResearchKiosk_Back", Vector3.new(22, 12, 2), Vector3.new(-54, 6.5, -61), COLORS.Purple, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ResearchKiosk_Roof", Vector3.new(24, 1.6, 17), Vector3.new(-54, 13.5, -55), COLORS.Purple, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ResearchBook", Vector3.new(8, 1, 6), Vector3.new(-54, 2.4, -51.2), COLORS.Blue, Enum.Material.SmoothPlastic)

	createPart(model, "LeftPost", Vector3.new(1.4, 11, 1.4), Vector3.new(-64.5, 6, -49), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "RightPost", Vector3.new(1.4, 11, 1.4), Vector3.new(-43.5, 6, -49), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "Desk", Vector3.new(16, 3.6, 4.5), Vector3.new(-54, 2.25, -50), COLORS.DarkStone, Enum.Material.SmoothPlastic)
	createPart(model, "DeskTop", Vector3.new(17, 0.5, 5.2), Vector3.new(-54, 4.25, -50), COLORS.WarmWhite, Enum.Material.Marble)
	createBook(model, "OpenIndexBook", Vector3.new(-54, 5, -50), COLORS.WarmWhite)
	createGem(model, "ResearchCrystal", Vector3.new(-54, 8.4, -56.5), COLORS.Purple, 0.8)
end

local function upgradeShopStation(map, parent)
	local model = createModel(parent, "ShopStation")

	styleExisting(map, "P0_ShopBase", Vector3.new(22, 0.8, 18), Vector3.new(66, 0.4, 38), COLORS.Stone, Enum.Material.Concrete, { CanCollide = true })
	styleExisting(map, "P0_ShopBack", Vector3.new(20, 12, 2), Vector3.new(66, 6.5, 45), COLORS.Blue, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ShopRoof", Vector3.new(22, 1.6, 18), Vector3.new(66, 13.5, 38), COLORS.Blue, Enum.Material.SmoothPlastic, { CanCollide = true })
	styleExisting(map, "P0_ShopCounter", Vector3.new(17, 3.2, 3.5), Vector3.new(66, 2.25, 31), COLORS.Wood, Enum.Material.WoodPlanks, { CanCollide = true })

	for index = 1, 7 do
		local color = index % 2 == 0 and COLORS.WarmWhite or COLORS.Cyan
		local x = 56.5 + ((index - 1) * 3.15)
		createPart(model, "AwningStripe_" .. index, Vector3.new(3.2, 0.55, 6.5), Vector3.new(x, 11.8, 30.6), color, Enum.Material.SmoothPlastic, {
			Orientation = Vector3.new(-14, 0, 0),
		})
	end

	createPart(model, "LeftShelf", Vector3.new(4.5, 7, 1.2), Vector3.new(59, 5.2, 43.3), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	createPart(model, "RightShelf", Vector3.new(4.5, 7, 1.2), Vector3.new(73, 5.2, 43.3), COLORS.WarmWhite, Enum.Material.SmoothPlastic)
	for index, data in ipairs({
		{ Vector3.new(59, 3.5, 42.2), COLORS.Lime },
		{ Vector3.new(59, 7.1, 42.2), COLORS.Pink },
		{ Vector3.new(73, 3.5, 42.2), COLORS.Gold },
		{ Vector3.new(73, 7.1, 42.2), COLORS.Purple },
	}) do
		createPart(model, "ShopBox_" .. index, Vector3.new(2.7, 2.2, 2.2), data[1], data[2], Enum.Material.SmoothPlastic)
	end
end

local function upgradeRankingStation(map, parent)
	local model = createModel(parent, "RankingStation")

	styleExisting(map, "P0_RankingBase", Vector3.new(24, 0.8, 16), Vector3.new(-67, 0.4, 39), COLORS.Stone, Enum.Material.Concrete, { CanCollide = true })
	styleExisting(map, "P0_RankingWall", Vector3.new(20, 14, 2), Vector3.new(-67, 7.5, 45), COLORS.Ink, Enum.Material.SmoothPlastic, { CanCollide = true })

	createPart(model, "FrameTop", Vector3.new(22, 1.2, 2.6), Vector3.new(-67, 14.8, 45), COLORS.Gold, Enum.Material.Metal)
	createPart(model, "FrameBottom", Vector3.new(22, 1.2, 2.6), Vector3.new(-67, 0.2, 45), COLORS.Gold, Enum.Material.Metal)
	createPart(model, "FrameLeft", Vector3.new(1.2, 14, 2.6), Vector3.new(-77.6, 7.5, 45), COLORS.Gold, Enum.Material.Metal)
	createPart(model, "FrameRight", Vector3.new(1.2, 14, 2.6), Vector3.new(-56.4, 7.5, 45), COLORS.Gold, Enum.Material.Metal)

	createPart(model, "PodiumSecond", Vector3.new(5.5, 3, 5.5), Vector3.new(-73, 1.9, 34), COLORS.Silver, Enum.Material.Metal)
	createPart(model, "PodiumFirst", Vector3.new(5.5, 5, 5.5), Vector3.new(-67, 2.9, 34), COLORS.Gold, Enum.Material.Metal)
	createPart(model, "PodiumThird", Vector3.new(5.5, 2, 5.5), Vector3.new(-61, 1.4, 34), COLORS.Bronze, Enum.Material.Metal)
end

local function upgradeAttendanceStation(map, parent)
	local model = createModel(parent, "AttendanceStation")

	styleExisting(map, "P0_AttendanceBase", Vector3.new(22, 0.8, 14), Vector3.new(48, 0.4, -61), COLORS.Stone, Enum.Material.Concrete, { CanCollide = true })
	styleExisting(map, "P0_AttendanceBoard", Vector3.new(18, 10, 1.5), Vector3.new(48, 5.5, -67), COLORS.Pink, Enum.Material.SmoothPlastic, { CanCollide = true })

	for day = 1, 7 do
		local x = 40.5 + ((day - 1) * 2.5)
		local color = day == 7 and COLORS.Gold or (day % 2 == 0 and COLORS.WarmWhite or COLORS.Pink)
		createPart(model, "DayPad_" .. day, Vector3.new(2, 0.65, 3.2), Vector3.new(x, 1, -58.5), color, day == 7 and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		createPart(model, "DayGift_" .. day, Vector3.new(1.25, 1.25, 1.25), Vector3.new(x, 2, -58.5), color, Enum.Material.SmoothPlastic)
	end
end

local function applyToMap(map)
	if not map or not map.Parent then
		return
	end

	waitForDescendant(map, "P0_RollPedestal_Lower", FIND_TIMEOUT_SECONDS)

	local oldFolder = map:FindFirstChild(UPGRADE_FOLDER_NAME)
	if oldFolder then
		oldFolder:Destroy()
	end

	local upgradeFolder = Instance.new("Folder")
	upgradeFolder.Name = UPGRADE_FOLDER_NAME
	upgradeFolder.Parent = map

	upgradeCentralPlaza(map, upgradeFolder)
	upgradeGate(map, upgradeFolder)
	upgradeQuestStation(map, upgradeFolder)
	upgradeChestStation(map, upgradeFolder)
	upgradeResearchStation(map, upgradeFolder)
	upgradeShopStation(map, upgradeFolder)
	upgradeRankingStation(map, upgradeFolder)
	upgradeAttendanceStation(map, upgradeFolder)

	map:SetAttribute("StructureStyle", "RobloxSimulatorStationsV1")
	print("[SimulatorStructureStyle] Applied polished simulator structures=8")
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		task.spawn(applyToMap, child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	task.spawn(applyToMap, existingMap)
else
	local map = Workspace:WaitForChild(MAP_NAME, FIND_TIMEOUT_SECONDS)
	if map then
		task.spawn(applyToMap, map)
	else
		warn("[SimulatorStructureStyle] SimpleMap missing; structure upgrade disabled.")
	end
end
