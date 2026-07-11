-- ServerScriptService/SimulatorSignStyle.server.lua
-- Applies simple, readable physical signs whose text fits each sign's real size.
-- Project rule: no floating BillboardGui world UI.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25
local STYLE_ATTRIBUTE = "CleanAutoFitPhysicalV2"
local PIXELS_PER_STUD = 36

local COLORS = {
	Panel = Color3.fromRGB(244, 239, 221),
	Ink = Color3.fromRGB(27, 38, 52),
	MutedInk = Color3.fromRGB(82, 92, 105),
	Blue = Color3.fromRGB(73, 132, 197),
	Lime = Color3.fromRGB(112, 214, 92),
	Yellow = Color3.fromRGB(235, 181, 44),
	Gold = Color3.fromRGB(213, 145, 39),
	Purple = Color3.fromRGB(136, 91, 213),
	Pink = Color3.fromRGB(225, 93, 145),
	Cyan = Color3.fromRGB(47, 168, 195),
}

local SIGN_CONFIGS = {
	{
		PartName = "P0_RollPedestal_FixedSign",
		Title = "BRAIN RNG",
		Subtitle = "SCHOOL PLAZA",
		Accent = COLORS.Lime,
		Face = Enum.NormalId.Front,
		Orientation = Vector3.zero,
	},
	{
		PartName = "P0_GateFixedSign",
		GuiName = "NextAreaGateSurfaceGui",
		TitleName = "NextAreaGateTitle",
		SubtitleName = "NextAreaGateSubtitle",
		Title = "ELEMENTARY SCHOOL",
		Subtitle = "REQUIRED IQ 80.500",
		Accent = COLORS.Blue,
		Face = Enum.NormalId.Front,
	},
	{
		PartName = "P0_QuestBoard",
		TitleName = "QuestBoardText",
		SubtitleName = "QuestBoardSubtitle",
		Title = "QUESTS",
		Subtitle = "COMPLETE AND CLAIM",
		Accent = COLORS.Yellow,
		Face = Enum.NormalId.Right,
		Orientation = Vector3.zero,
	},
	{
		PartName = "P0_ChestSign",
		TitleName = "ChestSignText",
		SubtitleName = "ChestSignSubtitle",
		Title = "CHESTS",
		Subtitle = "OPEN FOR REWARDS",
		Accent = COLORS.Gold,
		Face = Enum.NormalId.Left,
		Orientation = Vector3.zero,
	},
	{
		PartName = "P0_ResearchBoard",
		TitleName = "ResearchBoardText",
		SubtitleName = "ResearchBoardSubtitle",
		Title = "INDEX",
		Subtitle = "CONCEPTS AND TITLES",
		Accent = COLORS.Purple,
		Face = Enum.NormalId.Back,
	},
	{
		PartName = "P0_RankingWall",
		TitleName = "RankingWallText",
		SubtitleName = "RankingWallSubtitle",
		Title = "LEADERBOARD",
		Subtitle = "TOP IQ",
		Accent = COLORS.Yellow,
		Face = Enum.NormalId.Front,
	},
	{
		PartName = "P0_ShopSign",
		Title = "SHOP",
		Subtitle = "BOOSTS AND UPGRADES",
		Accent = COLORS.Cyan,
		Face = Enum.NormalId.Front,
	},
	{
		PartName = "P0_AttendanceBoard",
		TitleName = "AttendanceText",
		SubtitleName = "AttendanceSubtitle",
		Title = "DAILY REWARDS",
		Subtitle = "COMING SOON",
		Accent = COLORS.Pink,
		Face = Enum.NormalId.Back,
	},
	{
		PartName = "P0_Area2ReturnFixedSign",
		Title = "RETURN",
		Subtitle = "BACK TO SCHOOL",
		Accent = COLORS.Blue,
		Face = Enum.NormalId.Back,
	},
	{
		PartName = "WinPad_Plaza_Sign",
		Title = "+1 WIN",
		Subtitle = "STEP ON THE PAD",
		Accent = COLORS.Gold,
		Face = Enum.NormalId.Front,
	},
}

local function findDescendantWithTimeout(root, name, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds

	repeat
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local function darken(color, multiplier)
	return Color3.new(
		math.clamp(color.R * multiplier, 0, 1),
		math.clamp(color.G * multiplier, 0, 1),
		math.clamp(color.B * multiplier, 0, 1)
	)
end

local function getSurfaceStudSize(signPart, face)
	local size = signPart.Size

	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return size.Z, size.Y
	end

	if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		return size.X, size.Z
	end

	return size.X, size.Y
end

local function removePreviousStyle(signPart)
	for _, child in ipairs(signPart:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end

	local parent = signPart.Parent
	if parent then
		for _, suffix in ipairs({ "_BoldFrame", "_CleanFrame", "_SimulatorFrame" }) do
			local oldFrame = parent:FindFirstChild(signPart.Name .. suffix)
			if oldFrame then
				oldFrame:Destroy()
			end
		end
	end
end

local function addCorner(parent, scaleRadius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scaleRadius, 0)
	corner.Parent = parent
	return corner
end

local function addSizeConstraint(label, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = math.max(minSize, maxSize)
	constraint.Parent = label
	return constraint
end

local function createLabel(parent, name, text, position, size, font, color, minSize, maxSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 1
	label.TextScaled = true
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	addSizeConstraint(label, minSize, maxSize)
	return label
end

local function styleSign(signPart, config)
	if not signPart:IsA("BasePart") then
		return false
	end

	if config.Orientation then
		signPart.Orientation = config.Orientation
	end

	removePreviousStyle(signPart)

	local surfaceWidthStuds, surfaceHeightStuds = getSurfaceStudSize(signPart, config.Face)
	local canvasWidth = math.max(320, math.floor(surfaceWidthStuds * PIXELS_PER_STUD))
	local canvasHeight = math.max(150, math.floor(surfaceHeightStuds * PIXELS_PER_STUD))
	local shortSign = canvasHeight < 300

	signPart.Color = darken(config.Accent, 0.72)
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.Transparency = 0
	signPart.Reflectance = 0

	local gui = Instance.new("SurfaceGui")
	gui.Name = config.GuiName or "SimulatorSignSurfaceGui"
	gui.Face = config.Face
	gui.LightInfluence = 0.12
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(canvasWidth, canvasHeight)
	gui.Parent = signPart

	local card = Instance.new("Frame")
	card.Name = "SignCard"
	card.Position = UDim2.fromScale(0.035, 0.065)
	card.Size = UDim2.fromScale(0.93, 0.87)
	card.BackgroundColor3 = COLORS.Panel
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = gui
	addCorner(card, 0.07)

	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Position = UDim2.fromScale(0, 0)
	accentBar.Size = UDim2.fromScale(1, shortSign and 0.11 or 0.13)
	accentBar.BackgroundColor3 = config.Accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card

	local titleTop = shortSign and 0.17 or 0.18
	local titleHeight = shortSign and 0.48 or 0.45
	local subtitleTop = shortSign and 0.65 or 0.66
	local subtitleHeight = shortSign and 0.23 or 0.20
	local titleMax = math.floor(canvasHeight * (shortSign and 0.38 or 0.34))
	local subtitleMax = math.floor(canvasHeight * (shortSign and 0.18 or 0.15))

	createLabel(
		card,
		config.TitleName or "Title",
		config.Title,
		UDim2.fromScale(0.06, titleTop),
		UDim2.fromScale(0.88, titleHeight),
		Enum.Font.GothamBlack,
		COLORS.Ink,
		12,
		titleMax
	)

	createLabel(
		card,
		config.SubtitleName or "Subtitle",
		config.Subtitle,
		UDim2.fromScale(0.08, subtitleTop),
		UDim2.fromScale(0.84, subtitleHeight),
		Enum.Font.GothamBold,
		COLORS.MutedInk,
		10,
		subtitleMax
	)

	signPart:SetAttribute("SimulatorSignStyle", STYLE_ATTRIBUTE)
	signPart:SetAttribute("SignCanvasWidth", canvasWidth)
	signPart:SetAttribute("SignCanvasHeight", canvasHeight)
	return true
end

local function applyToMap(map)
	if not map or not map.Parent then
		return
	end

	task.wait(0.25)

	local upgraded = 0
	for _, config in ipairs(SIGN_CONFIGS) do
		local signPart = findDescendantWithTimeout(map, config.PartName, FIND_TIMEOUT_SECONDS)
		if signPart and styleSign(signPart, config) then
			upgraded += 1
		else
			warn("[SimulatorSignStyle] Missing sign part=" .. config.PartName)
		end
	end

	local removedBillboards = 0
	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			descendant:Destroy()
			removedBillboards += 1
		end
	end

	map.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BillboardGui") then
			task.defer(function()
				if descendant.Parent then
					descendant:Destroy()
				end
			end)
		end
	end)

	map:SetAttribute("SignStyle", STYLE_ATTRIBUTE)
	print(
		"[SimulatorSignStyle] Applied clean fitted signs="
			.. tostring(upgraded)
			.. " removedBillboards="
			.. tostring(removedBillboards)
	)
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
		warn("[SimulatorSignStyle] SimpleMap missing; sign upgrade disabled.")
	end
end
