local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local SimpleWorldBuilder = {}

local MAP_NAME = "SimpleMap"
local LOBBY_NAME = "Lobby_Prestige0_School"
local NEXT_AREA_REQUIRED_IQ = 80500

local COLORS = {
	WarmWhite = Color3.fromRGB(242, 239, 229),
	SchoolBlue = Color3.fromRGB(64, 125, 210),
	LightBlue = Color3.fromRGB(138, 196, 235),
	GrassGreen = Color3.fromRGB(89, 157, 76),
	RollLime = Color3.fromRGB(123, 255, 94),
	QuestYellow = Color3.fromRGB(255, 205, 72),
	ChestGold = Color3.fromRGB(234, 171, 54),
	ResearchPurple = Color3.fromRGB(139, 96, 210),
	DarkText = Color3.fromRGB(35, 43, 58),
	Path = Color3.fromRGB(223, 218, 205),
	Campus = Color3.fromRGB(207, 190, 156),
	Wood = Color3.fromRGB(112, 76, 48),
	Slate = Color3.fromRGB(58, 68, 82),
}

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
	item.Size = size
	item.Position = position
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
	item.CastShadow = options.CastShadow == true

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

local function billboard(parent, name, title, subtitle, accentColor, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Size = UDim2.new(0, 240, 0, 82)
	gui.StudsOffset = offset or Vector3.new(0, 5, 0)
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "StatusFrame"
	frame.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "StatusStroke"
	stroke.Color = accentColor
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Position = UDim2.new(0, 10, 0, 8)
	titleLabel.Size = UDim2.new(1, -20, 0, 30)
	titleLabel.Text = title
	titleLabel.TextColor3 = accentColor
	titleLabel.TextScaled = true
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.Position = UDim2.new(0, 10, 0, 43)
	subtitleLabel.Size = UDim2.new(1, -20, 0, 24)
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = COLORS.WarmWhite
	subtitleLabel.TextScaled = true
	subtitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitleLabel.TextStrokeTransparency = 0.62
	subtitleLabel.Parent = frame

	return gui
end

local function namedBillboardLabels(gui, titleName, subtitleName)
	local frame = gui:FindFirstChild("StatusFrame")
	if not frame then
		return
	end

	local title = frame:FindFirstChild("TitleLabel")
	if title then
		title.Name = titleName
	end

	local subtitle = frame:FindFirstChild("SubtitleLabel")
	if subtitle then
		subtitle.Name = subtitleName
	end
end

local function prompt(parent, name, actionText, objectText)
	local item = Instance.new("ProximityPrompt")
	item.Name = name
	item.ActionText = actionText
	item.ObjectText = objectText
	item.HoldDuration = 0
	item.MaxActivationDistance = 12
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
	part(parent, name .. "_Trunk", Vector3.new(2, 8, 2), position + Vector3.new(0, 4, 0), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		CastShadow = true,
	})
	part(parent, name .. "_Leaves", Vector3.new(8, 8, 8), position + Vector3.new(0, 11, 0), {
		Color = Color3.fromRGB(76, 142, 72),
		Material = Enum.Material.Grass,
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
	light.Range = 14
	light.Brightness = 0.65
	light.Parent = head
	return pole
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
	local ground = lobby.Ground
	part(ground, "P0_MainGround", Vector3.new(190, 2, 190), Vector3.new(0, -1, 0), {
		Color = COLORS.GrassGreen,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
	part(ground, "P0_CampusBase", Vector3.new(150, 0.3, 150), Vector3.new(0, 0.15, 0), {
		Color = COLORS.Campus,
		Material = Enum.Material.Ground,
		CanCollide = true,
	})
	part(ground, "P0_Border_NorthLeft", Vector3.new(64, 0.8, 2), Vector3.new(-43, 0.7, 75), { Color = COLORS.WarmWhite, Material = Enum.Material.Concrete })
	part(ground, "P0_Border_NorthRight", Vector3.new(64, 0.8, 2), Vector3.new(43, 0.7, 75), { Color = COLORS.WarmWhite, Material = Enum.Material.Concrete })
	part(ground, "P0_Border_SouthLeft", Vector3.new(54, 0.8, 2), Vector3.new(-48, 0.7, -75), { Color = COLORS.WarmWhite, Material = Enum.Material.Concrete })
	part(ground, "P0_Border_SouthRight", Vector3.new(54, 0.8, 2), Vector3.new(48, 0.7, -75), { Color = COLORS.WarmWhite, Material = Enum.Material.Concrete })
	part(ground, "P0_Border_West", Vector3.new(2, 0.8, 150), Vector3.new(-75, 0.7, 0), { Color = COLORS.WarmWhite, Material = Enum.Material.Concrete })
	part(ground, "P0_Border_East", Vector3.new(2, 0.8, 150), Vector3.new(75, 0.7, 0), { Color = COLORS.WarmWhite, Material = Enum.Material.Concrete })
end

local function createPaths(lobby)
	local paths = lobby.Paths
	part(paths, "P0_Path_SpawnToRoll", Vector3.new(18, 0.4, 58), Vector3.new(0, 0.45, -38), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(paths, "P0_Path_RollToGate", Vector3.new(20, 0.4, 56), Vector3.new(0, 0.45, 36), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(paths, "P0_Path_RollToQuest_A", Vector3.new(24, 0.35, 12), Vector3.new(-20, 0.47, -4), { Color = COLORS.Path, Material = Enum.Material.Concrete, Orientation = Vector3.new(0, -12, 0) })
	part(paths, "P0_Path_RollToQuest_B", Vector3.new(24, 0.35, 12), Vector3.new(-40, 0.47, 0), { Color = COLORS.Path, Material = Enum.Material.Concrete, Orientation = Vector3.new(0, -6, 0) })
	part(paths, "P0_Path_RollToQuest_C", Vector3.new(22, 0.35, 12), Vector3.new(-56, 0.47, 2), { Color = COLORS.Path, Material = Enum.Material.Concrete })
	part(paths, "P0_Path_RollToChest_A", Vector3.new(24, 0.35, 12), Vector3.new(20, 0.47, -3), { Color = COLORS.Path, Material = Enum.Material.Concrete, Orientation = Vector3.new(0, 11, 0) })
	part(paths, "P0_Path_RollToChest_B", Vector3.new(24, 0.35, 12), Vector3.new(41, 0.47, 1), { Color = COLORS.Path, Material = Enum.Material.Concrete, Orientation = Vector3.new(0, 6, 0) })
	part(paths, "P0_Path_RollToChest_C", Vector3.new(22, 0.35, 12), Vector3.new(57, 0.47, 2), { Color = COLORS.Path, Material = Enum.Material.Concrete })
end

local function createSpawn(map, lobby)
	local area = lobby.SpawnArea
	part(area, "P0_SpawnPlatform", Vector3.new(38, 1.5, 20), Vector3.new(0, 0.75, -76), { Color = COLORS.WarmWhite })
	local playerSpawn = part(map, "PlayerSpawn", Vector3.new(10, 0.5, 10), Vector3.new(0, 1.2, -76), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Position = Vector3.new(0, 2, -76)
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = map

	part(area, "P0_SpawnArch_Left", Vector3.new(4, 16, 4), Vector3.new(-17, 8, -87), { Color = COLORS.WarmWhite })
	part(area, "P0_SpawnArch_Right", Vector3.new(4, 16, 4), Vector3.new(17, 8, -87), { Color = COLORS.WarmWhite })
	part(area, "P0_SpawnArch_Top", Vector3.new(38, 4, 4), Vector3.new(0, 16, -87), { Color = COLORS.WarmWhite })
	sign(area, "P0_SpawnArch_Sign", "BRAIN RNG SCHOOL", Vector3.new(0, 19.5, -89.2), Vector3.new(34, 4, 0.4), COLORS.SchoolBlue)

	return playerSpawn
end

local function createRollArea(map, lobby)
	local area = lobby.RollArea
	part(area, "P0_RollPlaza_Base", Vector3.new(42, 1.6, 42), Vector3.new(0, 0.8, 0), { Color = COLORS.WarmWhite })
	part(area, "P0_RollPlaza_Trim_N", Vector3.new(42, 0.4, 2), Vector3.new(0, 1.8, 21), { Color = COLORS.LightBlue, Decorative = true })
	part(area, "P0_RollPlaza_Trim_S", Vector3.new(42, 0.4, 2), Vector3.new(0, 1.8, -21), { Color = COLORS.LightBlue, Decorative = true })
	part(area, "P0_RollPlaza_Trim_E", Vector3.new(2, 0.4, 42), Vector3.new(21, 1.8, 0), { Color = COLORS.LightBlue, Decorative = true })
	part(area, "P0_RollPlaza_Trim_W", Vector3.new(2, 0.4, 42), Vector3.new(-21, 1.8, 0), { Color = COLORS.LightBlue, Decorative = true })
	part(area, "P0_RollPedestal_Lower", Vector3.new(16, 2.5, 16), Vector3.new(0, 2.1, 0), { Color = COLORS.SchoolBlue })
	part(area, "P0_RollPedestal_Upper", Vector3.new(11, 1.4, 11), Vector3.new(0, 4, 0), { Color = Color3.fromRGB(234, 241, 250) })

	local rollButton = part(map, "RollButton", Vector3.new(8, 1.4, 8), Vector3.new(0, 5.3, 0), {
		Color = COLORS.RollLime,
		Material = Enum.Material.Neon,
		CanCollide = true,
		CanQuery = true,
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})
	rollButton:SetAttribute("VisualOnly", true)
	billboard(rollButton, "RollButtonBillboard", "ROLL IQ", "TAP TO GROW", COLORS.RollLime, Vector3.new(0, 6, 0))

	part(area, "P0_BookDecor_A", Vector3.new(6, 0.5, 4), Vector3.new(-14, 2.2, 13), { Color = COLORS.QuestYellow, Decorative = true })
	part(area, "P0_BookDecor_B", Vector3.new(5, 0.45, 3.5), Vector3.new(14, 2.15, 13), { Color = COLORS.ResearchPurple, Decorative = true, Orientation = Vector3.new(0, 12, 0) })
	makeBench(area, "P0_RollBench_Left", Vector3.new(-17, 0, -13), Vector3.new(0, 20, 0))
	makeBench(area, "P0_RollBench_Right", Vector3.new(17, 0, -13), Vector3.new(0, -20, 0))
end

local function createGateArea(map, lobby)
	local area = lobby.GateArea
	part(area, "P0_GatePlatform", Vector3.new(46, 1.6, 28), Vector3.new(0, 0.8, 68), { Color = COLORS.WarmWhite })
	part(area, "P0_Gate_LeftPillar", Vector3.new(6, 20, 6), Vector3.new(-18, 10, 68), { Color = COLORS.SchoolBlue })
	part(area, "P0_Gate_RightPillar", Vector3.new(6, 20, 6), Vector3.new(18, 10, 68), { Color = COLORS.SchoolBlue })
	part(area, "P0_Gate_TopBeam", Vector3.new(42, 6, 6), Vector3.new(0, 21, 68), { Color = COLORS.LightBlue })

	local gate = Instance.new("Model")
	gate.Name = "NextAreaGate"
	gate.Parent = map
	local door = part(gate, "NextAreaGate_Door", Vector3.new(25, 18, 2), Vector3.new(0, 10, 68), {
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.42,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})
	prompt(door, "NextAreaPrompt", "Enter", "Elementary School")
	part(gate, "NextAreaGateFrame_BottomGlow", Vector3.new(29, 0.35, 2), Vector3.new(0, 1.25, 67), {
		Color = COLORS.LightBlue,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		Decorative = true,
	})
	part(gate, "NextAreaLockIcon", Vector3.new(4.5, 4.5, 0.8), Vector3.new(0, 9, 66.6), {
		Color = COLORS.ChestGold,
		Transparency = 0.12,
		Decorative = true,
	})
	local top = part(gate, "NextAreaGateBillboardMount", Vector3.new(8, 1, 1), Vector3.new(0, 24, 67), { Color = COLORS.LightBlue, Decorative = true })
	local gui = billboard(top, "NextAreaGateBillboard", "ELEMENTARY SCHOOL", "REQUIRED IQ 80.500", COLORS.LightBlue, Vector3.new(0, 2.8, 0))
	gui.Name = "NextAreaGateBillboard"
	namedBillboardLabels(gui, "NextAreaGateTitle", "NextAreaGateSubtitle")

	sign(area, "P0_GateRequirementSign", "LOCKED - REQUIRED IQ 80.500", Vector3.new(0, 27, 64), Vector3.new(36, 4, 0.4), COLORS.ChestGold)
	part(area, "P0_GateSchoolPreview", Vector3.new(70, 28, 4), Vector3.new(0, 14, 87), {
		Color = Color3.fromRGB(226, 235, 245),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.08,
		Decorative = true,
	})
end

local function createQuestArea(map, lobby)
	local area = lobby.QuestArea
	part(area, "P0_QuestBase", Vector3.new(36, 1.6, 30), Vector3.new(-62, 0.8, 2), { Color = COLORS.WarmWhite })
	local board = part(area, "P0_QuestBoard", Vector3.new(2, 16, 28), Vector3.new(-72, 9, 2), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		Decorative = true,
		Orientation = Vector3.new(0, 90, 0),
	})
	surfaceText(board, "QuestBoardText", "QUESTS\nHOMEWORK BOARD\n\nROLL 10 TIMES\nFIND A RARE CONCEPT\nOPEN A CHEST", COLORS.QuestYellow)

	local body = part(map, "ProfessorBrain_Body", Vector3.new(4, 6, 3), Vector3.new(-62, 4.3, 10), {
		Color = COLORS.SchoolBlue,
		CanCollide = false,
		CanQuery = true,
	})
	part(map, "ProfessorBrain_Head", Vector3.new(3.5, 3.5, 3.5), Vector3.new(-62, 9.1, 10), {
		Color = Color3.fromRGB(245, 216, 184),
		Shape = Enum.PartType.Ball,
		Decorative = true,
	})
	prompt(body, "QuestOpenPrompt", "Talk", "Quest Board")
	local questGui = billboard(body, "QuestStatusBillboard", "QUESTS", "Check Progress", COLORS.QuestYellow, Vector3.new(0, 5.2, 0))
	namedBillboardLabels(questGui, "QuestStatusTitle", "QuestStatusSubtitle")
	local readyIcon = part(map, "QuestReadyIcon", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-58.5, 11, 10), {
		Color = COLORS.Slate,
		Shape = Enum.PartType.Ball,
		Transparency = 0.35,
		Decorative = true,
	})
	readyIcon.Name = "QuestReadyIcon"

	for index = 1, 5 do
		part(area, "P0_QuestPaper_" .. tostring(index), Vector3.new(0.25, 3.2, 3.8), Vector3.new(-73.1, 5.5 + index, -9 + (index * 3.5)), {
			Color = Color3.fromRGB(255, 246, 210),
			Material = Enum.Material.SmoothPlastic,
			Decorative = true,
			Orientation = Vector3.new(0, 90, index % 2 == 0 and 4 or -4),
		})
	end
	makeBench(area, "P0_QuestBench_A", Vector3.new(-55, 0, -12), Vector3.new(0, 12, 0))
	makeBench(area, "P0_QuestBench_B", Vector3.new(-52, 0, 17), Vector3.new(0, -20, 0))
end

local function createChestArea(map, lobby)
	local area = lobby.ChestArea
	part(area, "P0_ChestBase", Vector3.new(38, 1.6, 30), Vector3.new(62, 0.8, 2), { Color = COLORS.WarmWhite })
	for _, offset in ipairs({ -16, 16 }) do
		part(area, "P0_ChestCanopy_Post_" .. tostring(offset), Vector3.new(3, 13, 3), Vector3.new(62 + offset, 7, -11), { Color = COLORS.SchoolBlue })
		part(area, "P0_ChestCanopy_BackPost_" .. tostring(offset), Vector3.new(3, 13, 3), Vector3.new(62 + offset, 7, 15), { Color = COLORS.SchoolBlue })
	end
	part(area, "P0_ChestCanopy_Roof", Vector3.new(40, 2, 30), Vector3.new(62, 14, 2), { Color = COLORS.LightBlue, Decorative = true })

	local station = Instance.new("Model")
	station.Name = "WorldChestStation"
	station.Parent = map
	part(station, "P0_BasicChestPedestal", Vector3.new(8, 3, 8), Vector3.new(52, 2.5, 2), { Color = COLORS.ChestGold })
	part(area, "P0_RareChestPedestal", Vector3.new(8, 3, 8), Vector3.new(62, 2.5, 2), { Color = COLORS.ResearchPurple })
	part(area, "P0_EpicChestPedestal", Vector3.new(8, 3, 8), Vector3.new(72, 2.5, 2), { Color = Color3.fromRGB(255, 222, 110) })

	local chest = part(station, "WorldChestModel", Vector3.new(9, 5, 7), Vector3.new(52, 6, 2), {
		Color = COLORS.Wood,
		Material = Enum.Material.Wood,
		CanCollide = true,
		CanQuery = true,
	})
	local chestGui = billboard(chest, "ChestStatusBillboard", "CHESTS", "Spend CP for Rewards", COLORS.ChestGold, Vector3.new(0, 5, 0))
	namedBillboardLabels(chestGui, "ChestStatusTitle", "ChestStatusSubtitle")
	part(station, "WorldChestLid", Vector3.new(10, 1.2, 7.8), Vector3.new(52, 8.9, 2), { Color = COLORS.ChestGold, Decorative = true })
	part(station, "WorldChestBand", Vector3.new(1.1, 5.8, 7.8), Vector3.new(52, 6.2, 2), { Color = COLORS.ChestGold, Decorative = true })
	local promptPart = part(station, "ChestPromptPart", Vector3.new(12, 1, 9), Vector3.new(52, 3.95, 2), {
		Color = Color3.fromRGB(255, 230, 130),
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
	})
	prompt(promptPart, "ChestOpenPrompt", "Open Chest", "Basic Chest")
	local icon = part(station, "ChestReadyIcon", Vector3.new(1.5, 1.5, 1.5), Vector3.new(58, 10.2, 2), {
		Color = COLORS.Slate,
		Shape = Enum.PartType.Ball,
		Transparency = 0.35,
		Decorative = true,
	})
	icon.Name = "ChestReadyIcon"

	sign(area, "P0_ChestSign", "KNOWLEDGE CHESTS\nBASIC OPEN\nRARE / EPIC COMING SOON", Vector3.new(62, 17, -14), Vector3.new(32, 5, 0.4), COLORS.ChestGold)
end

local function createResearchArea(lobby)
	local area = lobby.ResearchArea
	part(area, "P0_ResearchBase", Vector3.new(48, 1.4, 22), Vector3.new(0, 0.7, -52), { Color = COLORS.WarmWhite })
	local board = part(area, "P0_ResearchBoard", Vector3.new(34, 15, 2), Vector3.new(0, 9, -60), { Color = COLORS.ResearchPurple, Decorative = true })
	surfaceText(board, "ResearchBoardText", "RESEARCH\nCONCEPT INDEX\nTITLES\nUNLOCKS AFTER EARLY PROGRESS", COLORS.WarmWhite)
	part(area, "P0_ResearchBook_A", Vector3.new(8, 1, 5), Vector3.new(-14, 2, -49), { Color = COLORS.SchoolBlue, Decorative = true })
	part(area, "P0_ResearchBook_B", Vector3.new(8, 1, 5), Vector3.new(0, 2, -48), { Color = COLORS.QuestYellow, Decorative = true, Orientation = Vector3.new(0, 12, 0) })
	part(area, "P0_ResearchFlask_A", Vector3.new(2.5, 4, 2.5), Vector3.new(13, 3.3, -49), { Color = COLORS.LightBlue, Transparency = 0.25, Decorative = true })
end

local function createRankingAndShop(lobby)
	local ranking = lobby.RankingArea
	part(ranking, "P0_RankingBase", Vector3.new(34, 1.2, 18), Vector3.new(-65, 0.6, -50), { Color = COLORS.WarmWhite })
	local wall = part(ranking, "P0_RankingWall", Vector3.new(30, 18, 2), Vector3.new(-65, 9, -55), { Color = COLORS.Slate, Decorative = true })
	surfaceText(wall, "RankingWallText", "TOP GENIUSES\n\n1st  - SERVER TOP\n2nd - COMING SOON\n3rd  - COMING SOON", COLORS.ChestGold)

	local shop = lobby.ShopArea
	part(shop, "P0_ShopBase", Vector3.new(28, 1.2, 18), Vector3.new(65, 0.6, -50), { Color = COLORS.WarmWhite })
	part(shop, "P0_ShopBack", Vector3.new(28, 15, 2), Vector3.new(65, 7.5, -59), { Color = COLORS.LightBlue, Decorative = true })
	part(shop, "P0_ShopCounter", Vector3.new(20, 3, 3), Vector3.new(65, 2.4, -46), { Color = COLORS.SchoolBlue, Decorative = true })
	sign(shop, "P0_ShopSign", "SCHOOL SHOP\nBOOSTS\nCOMING SOON", Vector3.new(65, 15.8, -60), Vector3.new(24, 4.5, 0.4), COLORS.RollLime)
end

local function createAttendance(lobby)
	local area = lobby.AttendanceArea
	part(area, "P0_AttendanceBase", Vector3.new(16, 1, 12), Vector3.new(25, 0.5, -68), { Color = COLORS.WarmWhite })
	local board = part(area, "P0_AttendanceBoard", Vector3.new(14, 9, 1.5), Vector3.new(25, 5.5, -72), { Color = COLORS.QuestYellow, Decorative = true })
	surfaceText(board, "AttendanceText", "DAILY ATTENDANCE\nCOMING SOON", COLORS.DarkText)
end

local function createDecorations(lobby)
	local decorations = lobby.Decorations
	for index, pos in ipairs({
		Vector3.new(-84, 0, -84), Vector3.new(84, 0, -84), Vector3.new(-84, 0, 84), Vector3.new(84, 0, 84),
		Vector3.new(-46, 0, -72), Vector3.new(46, 0, -72), Vector3.new(-72, 0, 38), Vector3.new(72, 0, 38),
		Vector3.new(-42, 0, 42), Vector3.new(42, 0, 42), Vector3.new(-28, 0, -26), Vector3.new(28, 0, -26),
	}) do
		makeTree(decorations, "P0_Tree_" .. tostring(index), pos)
	end

	for index, pos in ipairs({
		Vector3.new(-14, 0, -38), Vector3.new(14, 0, -38), Vector3.new(-24, 0, 18), Vector3.new(24, 0, 18),
		Vector3.new(-54, 0, -13), Vector3.new(54, 0, -13), Vector3.new(-73, 0, 32), Vector3.new(73, 0, 32),
	}) do
		makeBench(decorations, "P0_Bench_" .. tostring(index), pos, Vector3.new(0, index % 2 == 0 and 20 or -20, 0))
	end

	for index, pos in ipairs({
		Vector3.new(-12, 0, -63), Vector3.new(12, 0, -63), Vector3.new(-18, 0, 28), Vector3.new(18, 0, 28),
		Vector3.new(-51, 0, -23), Vector3.new(51, 0, -23), Vector3.new(-78, 0, 5), Vector3.new(78, 0, 5),
		Vector3.new(-34, 0, 62), Vector3.new(34, 0, 62),
	}) do
		makeLamp(decorations, "P0_Lamp_" .. tostring(index), pos)
	end
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
	billboard(promptPart, "Area2ReturnBillboard", "RETURN", "Back to Lobby", COLORS.LightBlue)
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.Ambient = Color3.fromRGB(120, 125, 135)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 165)
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
	color.Saturation = 0.05
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
	createDecorations(lobby)
	createArea2Preview(map)
	createWinPad(map, "WinPad_Plaza", Vector3.new(22, 1, 34), 1)

	print("[SimpleWorldBuilder] Prestige 0 school lobby created. Children:", #map:GetChildren())
	return map
end

function SimpleWorldBuilder.BuildMap()
	return SimpleWorldBuilder.CreateMap()
end

function SimpleWorldBuilder.Init()
	return SimpleWorldBuilder.CreateMap()
end

return SimpleWorldBuilder
