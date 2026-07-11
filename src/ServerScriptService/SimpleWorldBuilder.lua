local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local SimpleWorldBuilder = {}

local MAP_NAME = "SimpleMap"
local LOBBY_NAME = "Lobby_Prestige0_School"
local WORLD_SCALE = 2.5
local PROMPT_DISTANCE = 18
local COLORS = {
	WarmWhite = Color3.fromRGB(244, 239, 221),
	SchoolBlue = Color3.fromRGB(73, 132, 197),
	LightBlue = Color3.fromRGB(143, 210, 255),
	GrassGreen = Color3.fromRGB(104, 199, 91),
	GrassDark = Color3.fromRGB(70, 166, 70),
	RollLime = Color3.fromRGB(112, 255, 92),
	QuestYellow = Color3.fromRGB(255, 207, 64),
	ChestBlue = Color3.fromRGB(74, 155, 255),
	ChestGold = Color3.fromRGB(234, 171, 54),
	ResearchPurple = Color3.fromRGB(151, 107, 255),
	SchoolBrick = Color3.fromRGB(211, 103, 82),
	DarkText = Color3.fromRGB(32, 48, 64),
	Path = Color3.fromRGB(232, 216, 176),
	PathTrim = Color3.fromRGB(188, 177, 145),
	Plaza = Color3.fromRGB(195, 207, 216),
	Wood = Color3.fromRGB(126, 84, 52),
	Slate = Color3.fromRGB(72, 84, 98),
	Rock = Color3.fromRGB(133, 147, 151),
	Earth = Color3.fromRGB(111, 91, 63),
	OuterGrass = Color3.fromRGB(78, 176, 75),
}

local function worldVector(value)
	return value * WORLD_SCALE
end

local function tag(instance, tagName)
	if not CollectionService:HasTag(instance, tagName) then
		CollectionService:AddTag(instance, tagName)
	end
end

local function folder(parent, name)
	local item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

local function part(parent, name, size, position, options)
	options = options or {}

	local item = Instance.new("Part")
	item.Name = name
	item.Size = worldVector(size)
	item.Position = worldVector(position)
	item.Anchored = true
	item.Material = options.Material or Enum.Material.SmoothPlastic
	item.Color = options.Color or COLORS.WarmWhite
	item.Transparency = options.Transparency or 0
	item.Reflectance = options.Reflectance or 0
	item.CanCollide = options.CanCollide ~= false
	item.CanTouch = options.CanTouch == true
	item.CanQuery = options.CanQuery ~= false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.CastShadow = options.CastShadow ~= false

	if options.Shape then
		item.Shape = options.Shape
	end

	if options.Orientation then
		item.Orientation = options.Orientation
	end

	if options.Decorative then
		item.CanCollide = false
		item.CanTouch = false
		item.CanQuery = false
		item.CastShadow = options.CastShadow == true
		item:SetAttribute("Decorative", true)
	end

	item.Parent = parent
	return item
end

local function surfaceText(parent, name, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.15
	gui.PixelsPerStud = 60
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color or COLORS.WarmWhite
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.48
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	return label
end

local function sign(parent, name, text, position, size, color, orientation)
	local item = part(parent, name, size or Vector3.new(24, 5, 0.4), position, {
		Color = COLORS.DarkText,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
		Orientation = orientation,
	})
	surfaceText(item, "SurfaceGui", text, color or COLORS.WarmWhite)
	return item
end

local function gateSurfaceSign(parent, name, position)
	local item = part(parent, name, Vector3.new(28, 6, 0.5), position, {
		Color = COLORS.DarkText,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "NextAreaGateSurfaceGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.15
	gui.PixelsPerStud = 70
	gui.Parent = item

	local title = Instance.new("TextLabel")
	title.Name = "NextAreaGateTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0.05, 0, 0.08, 0)
	title.Size = UDim2.new(0.9, 0, 0.42, 0)
	title.Text = "ELEMENTARY SCHOOL"
	title.TextColor3 = COLORS.LightBlue
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.45
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "NextAreaGateSubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Position = UDim2.new(0.08, 0, 0.52, 0)
	subtitle.Size = UDim2.new(0.84, 0, 0.34, 0)
	subtitle.Text = "REQUIRED IQ 80.500"
	subtitle.TextColor3 = COLORS.WarmWhite
	subtitle.TextScaled = true
	subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.TextStrokeTransparency = 0.58
	subtitle.Parent = gui

	return item
end

local function prompt(parent, name, actionText, objectText)
	local item = Instance.new("ProximityPrompt")
	item.Name = name
	item.ActionText = actionText
	item.ObjectText = objectText
	item.HoldDuration = 0
	item.MaxActivationDistance = PROMPT_DISTANCE
	item.RequiresLineOfSight = false
	item.Enabled = true
	item.Parent = parent
	return item
end

local function makeBench(parent, name, position, orientation)
	local seat = part(parent, name .. "_Seat", Vector3.new(7, 0.7, 2), position + Vector3.new(0, 1.5, 0), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		Orientation = orientation,
	})
	part(parent, name .. "_Back", Vector3.new(7, 2.5, 0.6), position + Vector3.new(0, 2.6, 1), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		Orientation = orientation,
	})
	return seat
end

local function makeTree(parent, name, position)
	part(parent, name .. "_Trunk", Vector3.new(2.4, 7, 2.4), position + Vector3.new(0, 3.5, 0), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		CastShadow = true,
	})
	part(parent, name .. "_LeavesMain", Vector3.new(9, 9, 9), position + Vector3.new(0, 10, 0), {
		Color = COLORS.GrassDark,
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Decorative = true,
		CastShadow = true,
	})
	part(parent, name .. "_LeavesLeft", Vector3.new(6, 6, 6), position + Vector3.new(-3.5, 9, 0), {
		Color = COLORS.GrassGreen,
		Shape = Enum.PartType.Ball,
		Decorative = true,
		CastShadow = true,
	})
	part(parent, name .. "_LeavesRight", Vector3.new(6, 6, 6), position + Vector3.new(3.5, 9.2, 0.5), {
		Color = COLORS.GrassGreen,
		Shape = Enum.PartType.Ball,
		Decorative = true,
		CastShadow = true,
	})
end

local function makeLamp(parent, name, position)
	local pole = part(parent, name .. "_Pole", Vector3.new(0.8, 9, 0.8), position + Vector3.new(0, 4.5, 0), {
		Color = COLORS.Slate,
		Material = Enum.Material.Metal,
		Decorative = true,
	})
	local head = part(parent, name .. "_Head", Vector3.new(2.2, 1.2, 2.2), position + Vector3.new(0, 9.6, 0), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	local light = Instance.new("PointLight")
	light.Name = "SoftCampusLight"
	light.Color = COLORS.WarmWhite
	light.Range = 14 * WORLD_SCALE
	light.Brightness = 0.65
	light.Parent = head
	return pole
end

local function makeRock(parent, name, position, scale, rotation)
	part(parent, name, Vector3.new(4.5, 2.8, 3.6) * scale, position + Vector3.new(0, 1.2 * scale, 0), {
		Color = COLORS.Rock,
		Material = Enum.Material.Slate,
		Decorative = true,
		CastShadow = true,
		Orientation = Vector3.new(0, rotation or 0, 0),
	})
end

local function makeFlowerPatch(parent, name, position, color)
	for index, offset in ipairs({
		Vector3.new(-1.2, 0, -0.8),
		Vector3.new(0.8, 0, -1.1),
		Vector3.new(-0.4, 0, 1),
		Vector3.new(1.4, 0, 0.8),
	}) do
		part(parent, name .. "_Stem_" .. tostring(index), Vector3.new(0.22, 1.1, 0.22), position + offset + Vector3.new(0, 0.55, 0), {
			Color = COLORS.GrassDark,
			Decorative = true,
		})
		part(parent, name .. "_Bloom_" .. tostring(index), Vector3.new(0.8, 0.8, 0.8), position + offset + Vector3.new(0, 1.25, 0), {
			Color = color,
			Shape = Enum.PartType.Ball,
			Decorative = true,
		})
	end
end

local function makeFence(parent, name, position, length, orientation)
	local horizontal = orientation == "X"
	local railSize = horizontal and Vector3.new(length, 0.5, 0.5) or Vector3.new(0.5, 0.5, length)
	local endOffset = (length / 2) - 1

	part(parent, name .. "_RailLow", railSize, position + Vector3.new(0, 2, 0), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		CastShadow = true,
	})
	part(parent, name .. "_RailHigh", railSize, position + Vector3.new(0, 3.7, 0), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		CastShadow = true,
	})

	for index, offset in ipairs({ -endOffset, 0, endOffset }) do
		local postPosition = horizontal and (position + Vector3.new(offset, 2.2, 0)) or (position + Vector3.new(0, 2.2, offset))
		part(parent, name .. "_Post_" .. tostring(index), Vector3.new(0.8, 4.4, 0.8), postPosition, {
			Color = COLORS.Wood,
			Material = Enum.Material.Wood,
			Decorative = true,
			CastShadow = true,
		})
	end
end

local function makeBoundaryHill(parent, name, position, size)
	part(parent, name, size, position, {
		Color = COLORS.GrassDark,
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Ball,
		Decorative = true,
		CastShadow = true,
	})
end

local function createWinPad(parent, name, position, rewardWins)
	local pad = part(parent, name, Vector3.new(12, 0.35, 12), position, {
		Color = COLORS.ChestGold,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	pad:SetAttribute("RewardWins", rewardWins)
	tag(pad, "WinPad")
	sign(parent, name .. "_Sign", "+" .. tostring(rewardWins) .. " WINS", position + Vector3.new(0, 8, -8), Vector3.new(18, 4, 0.4), COLORS.ChestGold)
	return pad
end

local function createGround(lobby)
	part(lobby.Ground, "P0_WorldTerrainMass", Vector3.new(380, 20, 400), Vector3.new(0, -10, 0), {
		Color = COLORS.Earth,
		Material = Enum.Material.Ground,
		CanCollide = true,
	})
	part(lobby.Ground, "P0_GrassField_Core", Vector3.new(374, 1.6, 394), Vector3.new(0, -0.8, 0), {
		Color = COLORS.GrassGreen,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})

	-- Raised landscape outside the playable boundary hides the square edge and gives the lobby a world-scale horizon.
	part(lobby.Ground, "P0_OuterLand_West", Vector3.new(58, 4, 250), Vector3.new(-128, 0.6, 8), {
		Color = COLORS.OuterGrass,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
	part(lobby.Ground, "P0_OuterLand_East", Vector3.new(58, 4, 250), Vector3.new(128, 0.6, 8), {
		Color = COLORS.OuterGrass,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
	part(lobby.Ground, "P0_OuterLand_North", Vector3.new(246, 5.5, 72), Vector3.new(0, 1, 127), {
		Color = COLORS.OuterGrass,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
	part(lobby.Ground, "P0_OuterLand_South", Vector3.new(246, 4.5, 76), Vector3.new(0, 0.6, -127), {
		Color = COLORS.OuterGrass,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
end

local function createPaths(lobby)
	local paths = lobby.Paths
	part(paths, "P0_MainPath", Vector3.new(18, 0.4, 146), Vector3.new(0, 0.2, -5), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(paths, "P0_MainPath_LeftTrim", Vector3.new(1, 0.5, 146), Vector3.new(-9.5, 0.25, -5), { Color = COLORS.PathTrim, Material = Enum.Material.SmoothPlastic })
	part(paths, "P0_MainPath_RightTrim", Vector3.new(1, 0.5, 146), Vector3.new(9.5, 0.25, -5), { Color = COLORS.PathTrim, Material = Enum.Material.SmoothPlastic })
	part(paths, "P0_CentralPlaza", Vector3.new(0.6, 64, 64), Vector3.new(0, 0.3, -6), {
		Color = COLORS.Plaza,
		Material = Enum.Material.Concrete,
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})
	part(paths, "P0_QuestBranchPath", Vector3.new(28, 0.36, 12), Vector3.new(-35, 0.45, -6), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(paths, "P0_ChestBranchPath", Vector3.new(28, 0.36, 12), Vector3.new(35, 0.45, -6), { Color = COLORS.Path, Material = Enum.Material.Concrete })
end

local function createSpawn(map, lobby)
	local area = lobby.SpawnArea
	part(area, "P0_SpawnPlatform", Vector3.new(22, 0.6, 14), Vector3.new(0, 0.3, -78), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.SmoothPlastic,
	})
	part(area, "P0_SpawnPlatformInset", Vector3.new(17, 0.18, 10), Vector3.new(0, 0.68, -78), {
		Color = COLORS.WarmWhite,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	local playerSpawn = part(map, "PlayerSpawn", Vector3.new(10, 0.5, 10), Vector3.new(0, 1.2, -78), {
		Color = COLORS.LightBlue,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
		CastShadow = false,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Position = worldVector(Vector3.new(0, 2, -78))
	spawn.Size = worldVector(Vector3.new(8, 1, 8))
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = map

	return playerSpawn
end

local function createRollArea(map, lobby)
	local area = lobby.RollArea
	part(area, "P0_RollPedestal_Lower", Vector3.new(2.6, 15, 15), Vector3.new(0, 1.9, -6), {
		Color = COLORS.WarmWhite,
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})
	part(area, "P0_RollPedestal_Upper", Vector3.new(1.2, 11, 11), Vector3.new(0, 3.7, -6), {
		Color = COLORS.SchoolBlue,
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})

	local rollButton = part(map, "RollButton", Vector3.new(1.2, 9, 9), Vector3.new(0, 4.9, -6), {
		Color = COLORS.RollLime,
		Material = Enum.Material.Neon,
		CanCollide = true,
		CanQuery = true,
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})
	rollButton:SetAttribute("VisualOnly", true)

	part(area, "P0_RollSignPost_Left", Vector3.new(0.8, 8, 0.8), Vector3.new(-7, 5, -11), { Color = COLORS.WarmWhite })
	part(area, "P0_RollSignPost_Right", Vector3.new(0.8, 8, 0.8), Vector3.new(7, 5, -11), { Color = COLORS.WarmWhite })
	sign(area, "P0_RollPedestal_FixedSign", "ROLL IQ\nTAP TO GROW", Vector3.new(0, 10, -11), Vector3.new(16, 5, 0.5), COLORS.RollLime)

	makeBench(area, "P0_RollBench_Left", Vector3.new(-22, 0, -25), Vector3.new(0, 18, 0))
	makeBench(area, "P0_RollBench_Right", Vector3.new(22, 0, -25), Vector3.new(0, -18, 0))
end

local function createGateArea(map, lobby)
	local area = lobby.GateArea
	part(area, "P0_School_MainBody", Vector3.new(60, 22, 20), Vector3.new(0, 11, 79), { Color = COLORS.SchoolBrick, Material = Enum.Material.Brick })
	part(area, "P0_School_CenterTower", Vector3.new(22, 30, 4), Vector3.new(0, 15, 70), { Color = COLORS.SchoolBrick, Material = Enum.Material.Brick })
	part(area, "P0_School_Roof", Vector3.new(64, 3, 22), Vector3.new(0, 23.5, 79), { Color = COLORS.SchoolBlue })
	part(area, "P0_School_TowerCap", Vector3.new(26, 3, 8), Vector3.new(0, 30.5, 70), { Color = COLORS.SchoolBlue })
	part(area, "P0_School_LeftTrim", Vector3.new(4, 22, 1), Vector3.new(-25, 11, 69.5), { Color = COLORS.WarmWhite, Decorative = true })
	part(area, "P0_School_RightTrim", Vector3.new(4, 22, 1), Vector3.new(25, 11, 69.5), { Color = COLORS.WarmWhite, Decorative = true })
	part(area, "P0_School_TopTrim", Vector3.new(56, 2.5, 1), Vector3.new(0, 21, 69.5), { Color = COLORS.WarmWhite, Decorative = true })
	part(area, "P0_School_LeftWindow", Vector3.new(10, 9, 0.6), Vector3.new(-17, 12.5, 69.1), { Color = COLORS.LightBlue, Decorative = true })
	part(area, "P0_School_RightWindow", Vector3.new(10, 9, 0.6), Vector3.new(17, 12.5, 69.1), { Color = COLORS.LightBlue, Decorative = true })
	part(area, "P0_School_DoorFrame_Left", Vector3.new(2, 18, 1.6), Vector3.new(-7.5, 9.5, 67.8), { Color = COLORS.WarmWhite })
	part(area, "P0_School_DoorFrame_Right", Vector3.new(2, 18, 1.6), Vector3.new(7.5, 9.5, 67.8), { Color = COLORS.WarmWhite })
	part(area, "P0_School_DoorFrame_Top", Vector3.new(17, 2, 1.6), Vector3.new(0, 17.5, 67.8), { Color = COLORS.WarmWhite })
	part(area, "P0_School_FrontStep", Vector3.new(20, 1, 8), Vector3.new(0, 0.5, 64.5), { Color = COLORS.PathTrim, Material = Enum.Material.Concrete })

	local gate = Instance.new("Model")
	gate.Name = "NextAreaGate"
	gate.Parent = map
	local door = part(gate, "NextAreaGate_Door", Vector3.new(14, 15, 1), Vector3.new(0, 8.5, 66.8), {
		Color = COLORS.SchoolBlue,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.38,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})
	prompt(door, "NextAreaPrompt", "Enter", "Elementary School")
	part(gate, "NextAreaGateFrame_BottomGlow", Vector3.new(15, 0.35, 1.3), Vector3.new(0, 1.2, 66.5), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		Decorative = true,
	})
	part(gate, "NextAreaLockIcon", Vector3.new(3.5, 3.5, 0.7), Vector3.new(0, 9, 66.15), {
		Color = COLORS.ChestGold,
		Transparency = 0.08,
		Decorative = true,
	})
	gateSurfaceSign(gate, "P0_GateFixedSign", Vector3.new(0, 27, 67.6))
end

local function createQuestArea(map, lobby)
	local area = lobby.QuestArea
	part(area, "P0_QuestBooth_Floor", Vector3.new(24, 0.8, 18), Vector3.new(-47, 0.4, -6), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(area, "P0_QuestBooth_Back", Vector3.new(2, 13, 18), Vector3.new(-55, 7, -6), { Color = COLORS.QuestYellow })
	part(area, "P0_QuestBooth_Roof", Vector3.new(26, 2, 20), Vector3.new(-47, 14.5, -6), { Color = COLORS.QuestYellow })
	part(area, "P0_QuestBooth_PostFront", Vector3.new(2, 13, 2), Vector3.new(-38.5, 7, -13), { Color = COLORS.WarmWhite })
	part(area, "P0_QuestBooth_PostBack", Vector3.new(2, 13, 2), Vector3.new(-38.5, 7, 1), { Color = COLORS.WarmWhite })

	local board = part(area, "P0_QuestBoard", Vector3.new(0.6, 9, 13), Vector3.new(-53.8, 8.5, -6), {
		Color = COLORS.DarkText,
		Decorative = true,
		Orientation = Vector3.new(0, -90, 0),
	})
	surfaceText(board, "QuestBoardText", "QUESTS\nHOMEWORK BOARD\n\nROLL 10 TIMES\nFIND A RARE CONCEPT\nOPEN A CHEST", COLORS.QuestYellow)

	local body = part(map, "ProfessorBrain_Body", Vector3.new(4, 6, 3), Vector3.new(-41.5, 4.1, -6), {
		Color = COLORS.SchoolBlue,
		CanCollide = false,
		CanQuery = true,
	})
	part(map, "ProfessorBrain_Head", Vector3.new(3.5, 3.5, 3.5), Vector3.new(-41.5, 8.7, -6), {
		Color = Color3.fromRGB(245, 216, 184),
		Shape = Enum.PartType.Ball,
		Decorative = true,
	})
	prompt(body, "QuestOpenPrompt", "Talk", "Quest Board")
	local readyIcon = part(map, "QuestReadyIcon", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-41.5, 11.5, -6), {
		Color = COLORS.Slate,
		Shape = Enum.PartType.Ball,
		Transparency = 0.35,
		Decorative = true,
	})
	readyIcon.Name = "QuestReadyIcon"
end

local function createChestArea(map, lobby)
	local area = lobby.ChestArea
	part(area, "P0_ChestBooth_Floor", Vector3.new(24, 0.8, 18), Vector3.new(47, 0.4, -6), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(area, "P0_ChestBooth_Back", Vector3.new(2, 13, 18), Vector3.new(55, 7, -6), { Color = COLORS.ChestBlue })
	part(area, "P0_ChestBooth_Roof", Vector3.new(26, 2, 20), Vector3.new(47, 14.5, -6), { Color = COLORS.ChestBlue })
	part(area, "P0_ChestBooth_PostFront", Vector3.new(2, 13, 2), Vector3.new(38.5, 7, -13), { Color = COLORS.WarmWhite })
	part(area, "P0_ChestBooth_PostBack", Vector3.new(2, 13, 2), Vector3.new(38.5, 7, 1), { Color = COLORS.WarmWhite })

	local chestSign = part(area, "P0_ChestSign", Vector3.new(0.6, 9, 13), Vector3.new(53.8, 8.5, -6), {
		Color = COLORS.DarkText,
		Decorative = true,
		Orientation = Vector3.new(0, 90, 0),
	})
	surfaceText(chestSign, "ChestSignText", "KNOWLEDGE CHESTS\nBASIC OPEN\nRARE / EPIC COMING SOON", COLORS.LightBlue)

	local station = Instance.new("Model")
	station.Name = "WorldChestStation"
	station.Parent = map
	part(station, "P0_BasicChestPedestal", Vector3.new(8, 2.5, 8), Vector3.new(41.5, 1.65, -6), { Color = COLORS.WarmWhite })
	part(area, "P0_RareChestPedestal", Vector3.new(6, 2, 6), Vector3.new(49, 1.4, -11), { Color = COLORS.ResearchPurple })
	part(area, "P0_EpicChestPedestal", Vector3.new(6, 2, 6), Vector3.new(49, 1.4, -1), { Color = COLORS.ChestGold })

	local chest = part(station, "WorldChestModel", Vector3.new(8, 5, 7), Vector3.new(41.5, 5.1, -6), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		CanCollide = true,
		CanQuery = true,
	})
	part(station, "WorldChestLid", Vector3.new(9, 1.2, 7.8), Vector3.new(41.5, 8, -6), { Color = COLORS.ChestGold, Decorative = true })
	part(station, "WorldChestBand", Vector3.new(1.1, 5.8, 7.8), Vector3.new(41.5, 5.3, -6), { Color = COLORS.ChestGold, Decorative = true })
	local promptPart = part(station, "ChestPromptPart", Vector3.new(11, 1, 9), Vector3.new(41.5, 3.2, -6), {
		Color = COLORS.ChestGold,
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		CastShadow = false,
	})
	prompt(promptPart, "ChestOpenPrompt", "Open Chest", "Basic Chest")
	local icon = part(station, "ChestReadyIcon", Vector3.new(1.5, 1.5, 1.5), Vector3.new(41.5, 10.2, -6), {
		Color = COLORS.Slate,
		Shape = Enum.PartType.Ball,
		Transparency = 0.35,
		Decorative = true,
	})
	icon.Name = "ChestReadyIcon"
end

local function createResearchArea(lobby)
	local area = lobby.ResearchArea
	part(area, "P0_ResearchKiosk_Base", Vector3.new(22, 0.8, 14), Vector3.new(-54, 0.4, -55), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(area, "P0_ResearchKiosk_Back", Vector3.new(22, 12, 2), Vector3.new(-54, 6.5, -61), { Color = COLORS.ResearchPurple })
	part(area, "P0_ResearchKiosk_Roof", Vector3.new(24, 2, 16), Vector3.new(-54, 13.5, -55), { Color = COLORS.ResearchPurple })
	local board = part(area, "P0_ResearchBoard", Vector3.new(18, 8, 0.6), Vector3.new(-54, 7.5, -59.8), { Color = COLORS.DarkText, Decorative = true })
	surfaceText(board, "ResearchBoardText", "RESEARCH\nCONCEPT INDEX\nTITLES\nUNLOCKS AFTER EARLY PROGRESS", COLORS.WarmWhite)
	part(area, "P0_ResearchBook", Vector3.new(7, 1, 5), Vector3.new(-54, 1.5, -51), { Color = COLORS.SchoolBlue, Decorative = true })
end

local function createRankingAndShop(lobby)
	local ranking = lobby.RankingArea
	part(ranking, "P0_RankingBase", Vector3.new(20, 0.8, 12), Vector3.new(-67, 0.4, 39), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	local wall = part(ranking, "P0_RankingWall", Vector3.new(18, 14, 2), Vector3.new(-67, 7.5, 44), { Color = COLORS.Slate })
	surfaceText(wall, "RankingWallText", "TOP GENIUSES\n\n1st  - SERVER TOP\n2nd - COMING SOON\n3rd  - COMING SOON", COLORS.ChestGold)

	local shop = lobby.ShopArea
	part(shop, "P0_ShopBase", Vector3.new(20, 0.8, 16), Vector3.new(66, 0.4, 38), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(shop, "P0_ShopBack", Vector3.new(20, 12, 2), Vector3.new(66, 6.5, 45), { Color = COLORS.ChestBlue })
	part(shop, "P0_ShopRoof", Vector3.new(22, 2, 18), Vector3.new(66, 13.5, 38), { Color = COLORS.ChestBlue })
	part(shop, "P0_ShopCounter", Vector3.new(16, 3, 3), Vector3.new(66, 2.2, 31), { Color = COLORS.SchoolBlue })
	sign(shop, "P0_ShopSign", "SCHOOL SHOP\nBOOSTS\nCOMING SOON", Vector3.new(66, 9, 43.8), Vector3.new(16, 5, 0.5), COLORS.RollLime)
end

local function createAttendance(lobby)
	local area = lobby.AttendanceArea
	part(area, "P0_AttendanceBase", Vector3.new(18, 0.8, 12), Vector3.new(48, 0.4, -61), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	local board = part(area, "P0_AttendanceBoard", Vector3.new(16, 9, 1.5), Vector3.new(48, 5, -66), { Color = Color3.fromRGB(255, 122, 168) })
	surfaceText(board, "AttendanceText", "DAILY ATTENDANCE\nCOMING SOON", COLORS.WarmWhite)
end

local function createBoundary(lobby)
	local boundary = lobby.Boundary
	part(boundary, "P0_BoundaryNorth", Vector3.new(180, 24, 2), Vector3.new(0, 12, 90), { Transparency = 1, CanCollide = true, CanQuery = false, CastShadow = false })
	part(boundary, "P0_BoundarySouth", Vector3.new(180, 24, 2), Vector3.new(0, 12, -90), { Transparency = 1, CanCollide = true, CanQuery = false, CastShadow = false })
	part(boundary, "P0_BoundaryWest", Vector3.new(2, 24, 180), Vector3.new(-90, 12, 0), { Transparency = 1, CanCollide = true, CanQuery = false, CastShadow = false })
	part(boundary, "P0_BoundaryEast", Vector3.new(2, 24, 180), Vector3.new(90, 12, 0), { Transparency = 1, CanCollide = true, CanQuery = false, CastShadow = false })

	for index, data in ipairs({
		{ Vector3.new(-72, 2, -87), Vector3.new(38, 10, 18) }, { Vector3.new(-32, 2, -89), Vector3.new(44, 9, 17) },
		{ Vector3.new(34, 2, -89), Vector3.new(46, 9, 17) }, { Vector3.new(75, 2, -87), Vector3.new(34, 10, 18) },
		{ Vector3.new(-75, 2, 88), Vector3.new(30, 10, 18) }, { Vector3.new(-48, 2, 89), Vector3.new(28, 9, 17) },
		{ Vector3.new(48, 2, 89), Vector3.new(28, 9, 17) }, { Vector3.new(75, 2, 88), Vector3.new(30, 10, 18) },
		{ Vector3.new(-89, 2, -58), Vector3.new(18, 10, 36) }, { Vector3.new(-90, 2, -12), Vector3.new(18, 9, 44) },
		{ Vector3.new(-90, 2, 42), Vector3.new(18, 10, 48) }, { Vector3.new(89, 2, -58), Vector3.new(18, 10, 36) },
		{ Vector3.new(90, 2, -12), Vector3.new(18, 9, 44) }, { Vector3.new(90, 2, 42), Vector3.new(18, 10, 48) },
	}) do
		makeBoundaryHill(boundary, "P0_BoundaryHill_" .. tostring(index), data[1], data[2])
	end

	for index, data in ipairs({
		{ Vector3.new(-128, 5, -112), Vector3.new(72, 18, 48) },
		{ Vector3.new(-55, 5, -142), Vector3.new(88, 20, 44) },
		{ Vector3.new(48, 5, -144), Vector3.new(96, 19, 46) },
		{ Vector3.new(128, 5, -108), Vector3.new(70, 18, 50) },
		{ Vector3.new(-132, 6, 108), Vector3.new(72, 22, 54) },
		{ Vector3.new(-54, 6, 143), Vector3.new(92, 23, 48) },
		{ Vector3.new(52, 6, 145), Vector3.new(96, 22, 50) },
		{ Vector3.new(132, 6, 110), Vector3.new(72, 21, 54) },
		{ Vector3.new(-146, 5, -40), Vector3.new(46, 20, 92) },
		{ Vector3.new(-145, 5, 54), Vector3.new(48, 21, 98) },
		{ Vector3.new(146, 5, -38), Vector3.new(46, 20, 94) },
		{ Vector3.new(145, 5, 56), Vector3.new(48, 21, 100) },
	}) do
		makeBoundaryHill(boundary, "P0_DistantLandscape_" .. tostring(index), data[1], data[2])
	end
end

local function createDecorations(lobby)
	local decorations = lobby.Decorations
	for index, pos in ipairs({
		Vector3.new(-76, 0, -74), Vector3.new(-76, 0, -34), Vector3.new(-78, 0, 8), Vector3.new(-78, 0, 62),
		Vector3.new(-52, 0, 72), Vector3.new(-39, 0, 45), Vector3.new(-44, 0, 22), Vector3.new(-29, 0, -38),
		Vector3.new(76, 0, -74), Vector3.new(76, 0, -34), Vector3.new(78, 0, 8), Vector3.new(78, 0, 62),
		Vector3.new(52, 0, 72), Vector3.new(39, 0, 45), Vector3.new(44, 0, 22), Vector3.new(29, 0, -38),
	}) do
		makeTree(decorations, "P0_Tree_" .. tostring(index), pos)
	end

	for index, pos in ipairs({
		Vector3.new(-14, 0, -58), Vector3.new(14, 0, -58), Vector3.new(-14, 0, -32), Vector3.new(14, 0, -32),
		Vector3.new(-14, 0, 20), Vector3.new(14, 0, 20), Vector3.new(-14, 0, 46), Vector3.new(14, 0, 46),
	}) do
		makeLamp(decorations, "P0_Lamp_" .. tostring(index), pos)
	end

	for index, data in ipairs({
		{ Vector3.new(-70, 0, -58), 1, 18 }, { Vector3.new(-82, 0, -8), 0.8, -22 },
		{ Vector3.new(-70, 0, 30), 1.1, 35 }, { Vector3.new(-55, 0, 58), 0.85, -12 },
		{ Vector3.new(70, 0, -54), 1, -18 }, { Vector3.new(82, 0, -6), 0.9, 24 },
		{ Vector3.new(70, 0, 28), 1.1, -32 }, { Vector3.new(57, 0, 58), 0.85, 15 },
		{ Vector3.new(-33, 0, 70), 0.75, 8 }, { Vector3.new(33, 0, 70), 0.75, -8 },
	}) do
		makeRock(decorations, "P0_Rock_" .. tostring(index), data[1], data[2], data[3])
	end

	for index, data in ipairs({
		{ Vector3.new(-23, 0, -48), Color3.fromRGB(255, 240, 102) },
		{ Vector3.new(23, 0, -48), Color3.fromRGB(255, 122, 168) },
		{ Vector3.new(-31, 0, 28), Color3.fromRGB(255, 240, 102) },
		{ Vector3.new(31, 0, 28), Color3.fromRGB(143, 210, 255) },
		{ Vector3.new(-50, 0, 55), Color3.fromRGB(255, 122, 168) },
		{ Vector3.new(50, 0, 55), Color3.fromRGB(255, 240, 102) },
	}) do
		makeFlowerPatch(decorations, "P0_Flowers_" .. tostring(index), data[1], data[2])
	end

	makeFence(decorations, "P0_Fence_SouthLeft", Vector3.new(-31, 0, -83), 30, "X")
	makeFence(decorations, "P0_Fence_SouthRight", Vector3.new(31, 0, -83), 30, "X")
	makeFence(decorations, "P0_Fence_West", Vector3.new(-83, 0, 30), 32, "Z")
	makeFence(decorations, "P0_Fence_East", Vector3.new(83, 0, 30), 32, "Z")
end

local function createArea2Preview(map)
	local zone = Instance.new("Model")
	zone.Name = "Area2PreviewZone"
	zone:SetAttribute("PreviewOnly", true)
	zone.Parent = map

	local position = Vector3.new(600, 1, 0)
	part(zone, "Area2PlaceholderPlatform", Vector3.new(54, 1, 54), Vector3.new(position.X, position.Y - 0.4, position.Z), { Color = Color3.fromRGB(190, 232, 218) })
	part(zone, "Area2ArrivalPad", Vector3.new(18, 0.35, 18), Vector3.new(position.X, position.Y + 0.28, position.Z), { Color = COLORS.LightBlue })
	part(zone, "Area2ReturnPad", Vector3.new(13, 0.22, 13), Vector3.new(position.X + 17, position.Y + 0.2, position.Z + 13), { Color = COLORS.SchoolBlue })
	local promptPart = part(zone, "Area2ReturnPromptPart", Vector3.new(9, 0.3, 9), Vector3.new(position.X + 17, position.Y + 0.48, position.Z + 13), {
		Color = COLORS.SchoolBlue,
		CanQuery = true,
	})
	prompt(promptPart, "Area2ReturnPrompt", "Return", "Lobby")
	sign(zone, "P0_Area2ReturnFixedSign", "RETURN TO LOBBY", Vector3.new(position.X + 17, position.Y + 5.4, position.Z + 5.5), Vector3.new(18, 4, 0.5), COLORS.LightBlue)
end

local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.Ambient = Color3.fromRGB(128, 137, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 180, 190)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.25

	local atmosphere = Lighting:FindFirstChild("BrainRNG_Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "BrainRNG_Atmosphere"
	atmosphere.Density = 0.18
	atmosphere.Haze = 0.75
	atmosphere.Parent = Lighting

	local color = Lighting:FindFirstChild("BrainRNG_ColorCorrection") or Instance.new("ColorCorrectionEffect")
	color.Name = "BrainRNG_ColorCorrection"
	color.Brightness = 0.02
	color.Contrast = 0.05
	color.Saturation = 0.08
	color.Parent = Lighting

	local bloom = Lighting:FindFirstChild("BrainRNG_Bloom") or Instance.new("BloomEffect")
	bloom.Name = "BrainRNG_Bloom"
	bloom.Intensity = 0.08
	bloom.Size = 18
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end

local function createLobbyFolders(map)
	local world = folder(map, "World")
	local root = folder(world, LOBBY_NAME)
	local lobby = {
		Root = root,
	}

	for _, name in ipairs({
		"Ground",
		"SpawnArea",
		"RollArea",
		"GateArea",
		"QuestArea",
		"ChestArea",
		"ResearchArea",
		"RankingArea",
		"ShopArea",
		"AttendanceArea",
		"Paths",
		"Boundary",
		"Decorations",
		"InteractionZones",
		"Debug",
	}) do
		lobby[name] = folder(root, name)
	end

	return lobby
end

function SimpleWorldBuilder.CreateMap()
	setupLighting()

	local oldMap = Workspace:FindFirstChild(MAP_NAME)
	if oldMap then
		oldMap:Destroy()
	end

	local map = folder(Workspace, MAP_NAME)
	map:SetAttribute("Theme", "Prestige0SchoolLobby")
	map:SetAttribute("MapStyle", "ClassicSimulator")
	map:SetAttribute("LayoutVersion", 4)
	map:SetAttribute("WorldScale", WORLD_SCALE)
	map:SetAttribute("InteractionDistance", PROMPT_DISTANCE)
	map:SetAttribute("GroundStyle", "ExtendedLandscape")

	local lobby = createLobbyFolders(map)
	createGround(lobby)
	createPaths(lobby)
	createSpawn(map, lobby)
	createRollArea(map, lobby)
	createGateArea(map, lobby)
	createQuestArea(map, lobby)
	createChestArea(map, lobby)
	createResearchArea(lobby)
	createRankingAndShop(lobby)
	createAttendance(lobby)
	createBoundary(lobby)
	createDecorations(lobby)
	createArea2Preview(map)
	createWinPad(map, "WinPad_Plaza", Vector3.new(22, 1, 34), 1)

	print("[SimpleWorldBuilder] Full-scale simulator school lobby created. Children:", #map:GetChildren())
	return map
end

function SimpleWorldBuilder.BuildMap()
	return SimpleWorldBuilder.CreateMap()
end

function SimpleWorldBuilder.Init()
	return SimpleWorldBuilder.CreateMap()
end

return SimpleWorldBuilder
