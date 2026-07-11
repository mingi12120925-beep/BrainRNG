-- ServerScriptService/SimulatorSignStyle.server.lua
-- Replaces long test-map sign text with bold physical simulator signs.
-- Project rule: no floating BillboardGui world UI. All signs stay attached to parts.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25
local STYLE_ATTRIBUTE = "BoldPhysicalSimulatorV1"

local COLORS = {
	DarkPanel = Color3.fromRGB(18, 27, 43),
	White = Color3.fromRGB(255, 255, 255),
	SoftWhite = Color3.fromRGB(224, 234, 245),
	Ink = Color3.fromRGB(17, 24, 39),
	Lime = Color3.fromRGB(112, 255, 92),
	Blue = Color3.fromRGB(92, 181, 255),
	Yellow = Color3.fromRGB(255, 207, 64),
	Gold = Color3.fromRGB(255, 184, 54),
	Purple = Color3.fromRGB(174, 118, 255),
	Pink = Color3.fromRGB(255, 122, 168),
	Cyan = Color3.fromRGB(93, 236, 255),
}

local SIGN_CONFIGS = {
	{
		PartName = "P0_RollPedestal_FixedSign",
		Title = "BRAIN RNG",
		Subtitle = "SCHOOL PLAZA",
		Icon = "IQ",
		Accent = COLORS.Lime,
		Face = Enum.NormalId.Front,
		Orientation = Vector3.zero,
	},
	{
		PartName = "P0_GateFixedSign",
		GuiName = "NextAreaGateSurfaceGui",
		TitleName = "NextAreaGateTitle",
		SubtitleName = "NextAreaGateSubtitle",
		Title = "ELEMENTARY",
		Subtitle = "IQ 80.500 REQUIRED",
		Icon = "IQ",
		Accent = COLORS.Blue,
		Face = Enum.NormalId.Front,
	},
	{
		PartName = "P0_QuestBoard",
		TitleName = "QuestBoardText",
		SubtitleName = "QuestBoardSubtitle",
		Title = "QUESTS",
		Subtitle = "COMPLETE  •  CLAIM",
		Icon = "!",
		Accent = COLORS.Yellow,
		Face = Enum.NormalId.Right,
		Orientation = Vector3.zero,
	},
	{
		PartName = "P0_ChestSign",
		TitleName = "ChestSignText",
		SubtitleName = "ChestSignSubtitle",
		Title = "CHESTS",
		Subtitle = "OPEN  •  EARN REWARDS",
		Icon = "C",
		Accent = COLORS.Gold,
		Face = Enum.NormalId.Left,
		Orientation = Vector3.zero,
	},
	{
		PartName = "P0_ResearchBoard",
		TitleName = "ResearchBoardText",
		SubtitleName = "ResearchBoardSubtitle",
		Title = "INDEX",
		Subtitle = "CONCEPTS  •  TITLES",
		Icon = "?",
		Accent = COLORS.Purple,
		Face = Enum.NormalId.Back,
	},
	{
		PartName = "P0_RankingWall",
		TitleName = "RankingWallText",
		SubtitleName = "RankingWallSubtitle",
		Title = "LEADERBOARD",
		Subtitle = "TOP IQ",
		Icon = "#",
		Accent = COLORS.Yellow,
		Face = Enum.NormalId.Front,
	},
	{
		PartName = "P0_ShopSign",
		Title = "SHOP",
		Subtitle = "BOOSTS  •  UPGRADES",
		Icon = "$",
		Accent = COLORS.Cyan,
		Face = Enum.NormalId.Front,
	},
	{
		PartName = "P0_AttendanceBoard",
		TitleName = "AttendanceText",
		SubtitleName = "AttendanceSubtitle",
		Title = "DAILY REWARDS",
		Subtitle = "COMING SOON",
		Icon = "D",
		Accent = COLORS.Pink,
		Face = Enum.NormalId.Back,
	},
	{
		PartName = "P0_Area2ReturnFixedSign",
		Title = "RETURN",
		Subtitle = "BACK TO SCHOOL",
		Icon = "<",
		Accent = COLORS.Blue,
		Face = Enum.NormalId.Back,
	},
	{
		PartName = "WinPad_Plaza_Sign",
		Title = "+1 WIN",
		Subtitle = "STEP ON THE PAD",
		Icon = "+",
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

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Thickness = thickness
	item.Transparency = transparency
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Parent = parent
	return item
end

local function textStroke(parent, thickness)
	local item = Instance.new("UIStroke")
	item.Color = Color3.fromRGB(0, 0, 0)
	item.Thickness = thickness
	item.Transparency = 0.2
	item.Parent = parent
	return item
end

local function removeOldSignGui(signPart)
	for _, child in ipairs(signPart:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end
end

local function makeFramePart(parent, name, size, cframe, color)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.CastShadow = false
	item.Material = Enum.Material.Neon
	item.Color = color
	item.Transparency = 0.05
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function addPhysicalFrame(signPart, face, accent)
	local oldFrame = signPart.Parent:FindFirstChild(signPart.Name .. "_BoldFrame")
	if oldFrame then
		oldFrame:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = signPart.Name .. "_BoldFrame"
	model.Parent = signPart.Parent

	local size = signPart.Size
	local frameThickness
	local frameDepth = 0.5

	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		local width = size.X
		local height = size.Y
		frameThickness = math.clamp(math.min(width, height) * 0.055, 0.45, 1.2)
		local direction = face == Enum.NormalId.Front and -1 or 1
		local z = direction * ((size.Z * 0.5) + (frameDepth * 0.5) + 0.03)

		makeFramePart(model, "Top", Vector3.new(width + frameThickness * 2, frameThickness, frameDepth), signPart.CFrame * CFrame.new(0, (height + frameThickness) * 0.5, z), accent)
		makeFramePart(model, "Bottom", Vector3.new(width + frameThickness * 2, frameThickness, frameDepth), signPart.CFrame * CFrame.new(0, -(height + frameThickness) * 0.5, z), accent)
		makeFramePart(model, "Left", Vector3.new(frameThickness, height, frameDepth), signPart.CFrame * CFrame.new(-(width + frameThickness) * 0.5, 0, z), accent)
		makeFramePart(model, "Right", Vector3.new(frameThickness, height, frameDepth), signPart.CFrame * CFrame.new((width + frameThickness) * 0.5, 0, z), accent)
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		local width = size.Z
		local height = size.Y
		frameThickness = math.clamp(math.min(width, height) * 0.055, 0.45, 1.2)
		local direction = face == Enum.NormalId.Left and -1 or 1
		local x = direction * ((size.X * 0.5) + (frameDepth * 0.5) + 0.03)

		makeFramePart(model, "Top", Vector3.new(frameDepth, frameThickness, width + frameThickness * 2), signPart.CFrame * CFrame.new(x, (height + frameThickness) * 0.5, 0), accent)
		makeFramePart(model, "Bottom", Vector3.new(frameDepth, frameThickness, width + frameThickness * 2), signPart.CFrame * CFrame.new(x, -(height + frameThickness) * 0.5, 0), accent)
		makeFramePart(model, "Left", Vector3.new(frameDepth, height, frameThickness), signPart.CFrame * CFrame.new(x, 0, -(width + frameThickness) * 0.5), accent)
		makeFramePart(model, "Right", Vector3.new(frameDepth, height, frameThickness), signPart.CFrame * CFrame.new(x, 0, (width + frameThickness) * 0.5), accent)
	end
end

local function createTextLabel(parent, name, text, position, size, font, color, maxTextSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 18
	constraint.MaxTextSize = maxTextSize
	constraint.Parent = label

	return label
end

local function styleSign(signPart, config)
	if not signPart:IsA("BasePart") then
		return false
	end

	if config.Orientation then
		signPart.Orientation = config.Orientation
	end

	removeOldSignGui(signPart)
	signPart.Color = COLORS.DarkPanel
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.Transparency = 0
	signPart.Reflectance = 0

	local gui = Instance.new("SurfaceGui")
	gui.Name = config.GuiName or "SimulatorSignSurfaceGui"
	gui.Face = config.Face
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.Parent = signPart

	local root = Instance.new("Frame")
	root.Name = "SignCard"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = COLORS.DarkPanel
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = gui
	corner(root, 28)
	stroke(root, config.Accent, 8, 0.08)

	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(1, 0, 0.14, 0)
	accentBar.BackgroundColor3 = config.Accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = root

	local iconCard = Instance.new("Frame")
	iconCard.Name = "IconCard"
	iconCard.AnchorPoint = Vector2.new(0, 0.5)
	iconCard.Position = UDim2.new(0.035, 0, 0.57, 0)
	iconCard.Size = UDim2.new(0.15, 0, 0.52, 0)
	iconCard.BackgroundColor3 = config.Accent
	iconCard.BorderSizePixel = 0
	iconCard.Parent = root
	corner(iconCard, 999)

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.GothamBlack
	icon.Text = config.Icon
	icon.TextColor3 = COLORS.Ink
	icon.TextScaled = true
	icon.Parent = iconCard

	local iconConstraint = Instance.new("UITextSizeConstraint")
	iconConstraint.MinTextSize = 18
	iconConstraint.MaxTextSize = 74
	iconConstraint.Parent = icon

	local title = createTextLabel(
		root,
		config.TitleName or "Title",
		config.Title,
		UDim2.new(0.22, 0, 0.18, 0),
		UDim2.new(0.74, 0, 0.42, 0),
		Enum.Font.GothamBlack,
		COLORS.White,
		96
	)
	textStroke(title, 3)

	local subtitle = createTextLabel(
		root,
		config.SubtitleName or "Subtitle",
		config.Subtitle,
		UDim2.new(0.22, 0, 0.6, 0),
		UDim2.new(0.74, 0, 0.23, 0),
		Enum.Font.GothamBold,
		COLORS.SoftWhite,
		48
	)

	addPhysicalFrame(signPart, config.Face, config.Accent)
	signPart:SetAttribute("SimulatorSignStyle", STYLE_ATTRIBUTE)
	return true
end

local function removeFloatingBillboard(instance)
	if not instance:IsA("BillboardGui") then
		return false
	end

	instance:Destroy()
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
		if removeFloatingBillboard(descendant) then
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
		"[SimulatorSignStyle] Applied physical signs="
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
