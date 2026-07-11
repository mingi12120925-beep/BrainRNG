-- ServerScriptService/SimulatorSignStyle.server.lua
-- Applies large, simple physical signs that remain readable from normal play distance.
-- Project rule: no floating BillboardGui world UI.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25
local STYLE_ATTRIBUTE = "LargeReadablePhysicalV3"
local CANVAS_HEIGHT = 512

local COLORS = {
	Panel = Color3.fromRGB(246, 243, 231),
	Ink = Color3.fromRGB(24, 34, 46),
	MutedInk = Color3.fromRGB(61, 72, 84),
	Blue = Color3.fromRGB(73, 132, 197),
	Lime = Color3.fromRGB(92, 188, 75),
	Yellow = Color3.fromRGB(221, 164, 32),
	Gold = Color3.fromRGB(197, 126, 27),
	Purple = Color3.fromRGB(126, 79, 196),
	Pink = Color3.fromRGB(210, 77, 130),
	Cyan = Color3.fromRGB(37, 148, 174),
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

local function addCorner(parent, radiusScale)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radiusScale, 0)
	corner.Parent = parent
	return corner
end

local function addSizeConstraint(label, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
	return constraint
end

local function enforceTextStyle(label, color, font, minSize, maxSize)
	local applying = false

	local function apply()
		if applying or not label.Parent then
			return
		end

		applying = true
		label.TextColor3 = color
		label.TextTransparency = 0
		label.TextStrokeTransparency = 1
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = font
		label.LineHeight = 0.9

		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then
			constraint.MinTextSize = minSize
			constraint.MaxTextSize = maxSize
		end
		applying = false
	end

	apply()

	for _, propertyName in ipairs({
		"TextColor3",
		"TextTransparency",
		"TextStrokeTransparency",
		"TextScaled",
		"TextWrapped",
		"Font",
	}) do
		label:GetPropertyChangedSignal(propertyName):Connect(function()
			task.defer(apply)
		end)
	end
end

local function createLabel(parent, name, text, position, size, font, color, minSize, maxSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	addSizeConstraint(label, minSize, maxSize)
	enforceTextStyle(label, color, font, minSize, maxSize)
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
	local aspectRatio = math.clamp(surfaceWidthStuds / math.max(surfaceHeightStuds, 0.1), 1.1, 4.2)
	local canvasWidth = math.floor(CANVAS_HEIGHT * aspectRatio)

	signPart.Color = darken(config.Accent, 0.7)
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.Transparency = 0
	signPart.Reflectance = 0

	local gui = Instance.new("SurfaceGui")
	gui.Name = config.GuiName or "SimulatorSignSurfaceGui"
	gui.Face = config.Face
	gui.LightInfluence = 0.08
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(canvasWidth, CANVAS_HEIGHT)
	gui.Parent = signPart

	local card = Instance.new("Frame")
	card.Name = "SignCard"
	card.Position = UDim2.fromScale(0.018, 0.035)
	card.Size = UDim2.fromScale(0.964, 0.93)
	card.BackgroundColor3 = COLORS.Panel
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = gui
	addCorner(card, 0.045)

	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Position = UDim2.fromScale(0, 0)
	accentBar.Size = UDim2.fromScale(1, 0.055)
	accentBar.BackgroundColor3 = config.Accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card

	local titleColor = darken(config.Accent, 0.48)
	local title = createLabel(
		card,
		config.TitleName or "Title",
		config.Title,
		UDim2.fromScale(0.025, 0.08),
		UDim2.fromScale(0.95, 0.64),
		Enum.Font.GothamBlack,
		titleColor,
		34,
		230
	)

	local subtitle = createLabel(
		card,
		config.SubtitleName or "Subtitle",
		config.Subtitle,
		UDim2.fromScale(0.04, 0.73),
		UDim2.fromScale(0.92, 0.2),
		Enum.Font.GothamBold,
		COLORS.MutedInk,
		22,
		78
	)

	title:SetAttribute("LargeReadableSignText", true)
	subtitle:SetAttribute("LargeReadableSignText", true)
	signPart:SetAttribute("SimulatorSignStyle", STYLE_ATTRIBUTE)
	signPart:SetAttribute("SignCanvasWidth", canvasWidth)
	signPart:SetAttribute("SignCanvasHeight", CANVAS_HEIGHT)
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
		"[SimulatorSignStyle] Applied large readable signs="
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
