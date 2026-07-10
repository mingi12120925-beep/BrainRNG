local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local SimpleWorldBuilder = {}

local MAP_NAME = "SimpleMap"

local COLORS = {
	Floor = Color3.fromRGB(218, 222, 218),
	FloorAlt = Color3.fromRGB(190, 202, 214),
	Grass = Color3.fromRGB(94, 176, 82),
	Blue = Color3.fromRGB(85, 175, 245),
	Mint = Color3.fromRGB(86, 205, 150),
	Gold = Color3.fromRGB(255, 205, 70),
	Purple = Color3.fromRGB(145, 105, 220),
	Pink = Color3.fromRGB(235, 120, 190),
	Red = Color3.fromRGB(235, 90, 90),
	Green = Color3.fromRGB(105, 205, 120),
	Slate = Color3.fromRGB(110, 124, 138),
	Dark = Color3.fromRGB(38, 45, 54),
	White = Color3.fromRGB(245, 245, 245),
}

local function addTag(instance, tag)
	if not CollectionService:HasTag(instance, tag) then
		CollectionService:AddTag(instance, tag)
	end
end

local function makeDecorative(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part:SetAttribute("Decorative", true)
end

local function createPart(parent, name, size, position, options)
	options = options or {}

	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = options.Anchored ~= false
	part.Material = options.Material or Enum.Material.SmoothPlastic
	part.Color = options.Color or COLORS.Floor
	part.Transparency = options.Transparency or 0
	part.Reflectance = options.Reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if options.Decorative then
		makeDecorative(part)
	else
		part.CanCollide = options.CanCollide ~= false
		part.CanTouch = options.CanTouch ~= false
		part.CanQuery = options.CanQuery ~= false
	end

	part.Parent = parent
	return part
end

local function createFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createSign(parent, name, text, position, size, color)
	local sign = createPart(parent, name, size or Vector3.new(24, 6, 0.4), position, {
		Color = COLORS.Dark,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SurfaceGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 60
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color or COLORS.White
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	return sign
end

local function createQuestStatusBillboard(parent)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QuestStatusBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 78
	billboard.Size = UDim2.new(0, 210, 0, 82)
	billboard.StudsOffset = Vector3.new(0, 4.9, 0)
	billboard.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "StatusFrame"
	frame.BackgroundColor3 = COLORS.Dark
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "StatusStroke"
	stroke.Color = COLORS.Green
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "QuestStatusTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0, 10, 0, 8)
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Text = "QUESTS"
	title.TextColor3 = COLORS.Green
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.35
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "QuestStatusSubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Position = UDim2.new(0, 10, 0, 43)
	subtitle.Size = UDim2.new(1, -20, 0, 24)
	subtitle.Text = "Check Progress"
	subtitle.TextColor3 = COLORS.White
	subtitle.TextScaled = true
	subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Parent = frame

	return billboard
end

local function createChestStatusBillboard(parent)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChestStatusBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 82
	billboard.Size = UDim2.new(0, 210, 0, 78)
	billboard.StudsOffset = Vector3.new(0, 5.1, 0)
	billboard.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "StatusFrame"
	frame.BackgroundColor3 = COLORS.Dark
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "StatusStroke"
	stroke.Color = COLORS.Gold
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "ChestStatusTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0, 10, 0, 8)
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Text = "CHESTS"
	title.TextColor3 = COLORS.Gold
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.35
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "ChestStatusSubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Position = UDim2.new(0, 10, 0, 43)
	subtitle.Size = UDim2.new(1, -20, 0, 24)
	subtitle.Text = "Spend CP for Rewards"
	subtitle.TextColor3 = COLORS.White
	subtitle.TextScaled = true
	subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Parent = frame

	return billboard
end

local function createNeonLine(parent, name, size, position, color)
	return createPart(parent, name, size, position, {
		Color = color,
		Material = Enum.Material.Neon,
		Decorative = true,
	})
end

local function createRing(parent, prefix, center, width, depth, color)
	createNeonLine(parent, prefix .. "_Front", Vector3.new(width, 0.15, 1.2), Vector3.new(center.X, center.Y, center.Z - depth / 2), color)
	createNeonLine(parent, prefix .. "_Back", Vector3.new(width, 0.15, 1.2), Vector3.new(center.X, center.Y, center.Z + depth / 2), color)
	createNeonLine(parent, prefix .. "_Left", Vector3.new(1.2, 0.15, depth), Vector3.new(center.X - width / 2, center.Y, center.Z), color)
	createNeonLine(parent, prefix .. "_Right", Vector3.new(1.2, 0.15, depth), Vector3.new(center.X + width / 2, center.Y, center.Z), color)
end

local function createPortal(parent, name, position, color, requiredIQ, targetPartName)
	local model = Instance.new("Model")
	model.Name = name .. "_Visual"
	model:SetAttribute("Decorative", true)
	model.Parent = parent

	createPart(model, name .. "_LeftPillar", Vector3.new(2.2, 18, 2.2), Vector3.new(position.X - 15, 9, position.Z), {
		Color = color,
		Material = Enum.Material.Neon,
		Decorative = true,
	})

	createPart(model, name .. "_RightPillar", Vector3.new(2.2, 18, 2.2), Vector3.new(position.X + 15, 9, position.Z), {
		Color = color,
		Material = Enum.Material.Neon,
		Decorative = true,
	})

	createPart(model, name .. "_TopBeam", Vector3.new(32, 2.2, 2.2), Vector3.new(position.X, 18, position.Z), {
		Color = color,
		Material = Enum.Material.Neon,
		Decorative = true,
	})

	local gate = createPart(parent, name, Vector3.new(34, 18, 4), Vector3.new(position.X, 9, position.Z), {
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanTouch = true,
		CanQuery = true,
	})
	gate:SetAttribute("RequiredIQ", requiredIQ)
	gate:SetAttribute("TargetPartName", targetPartName)
	addTag(gate, "IQGate")

	createSign(parent, name .. "_Sign", "IQ " .. tostring(requiredIQ) .. "+", Vector3.new(position.X, 22, position.Z - 2), Vector3.new(24, 5, 0.4), color)

	return gate
end

local function createPlaceholderGate(parent, name, position, color, label)
	local model = Instance.new("Model")
	model.Name = name .. "_Placeholder"
	model:SetAttribute("Decorative", true)
	model.Parent = parent

	createPart(model, name .. "_LeftPillar", Vector3.new(2.2, 16, 2.2), Vector3.new(position.X - 14, 8, position.Z), {
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createPart(model, name .. "_RightPillar", Vector3.new(2.2, 16, 2.2), Vector3.new(position.X + 14, 8, position.Z), {
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createPart(model, name .. "_TopBeam", Vector3.new(30, 2.2, 2.2), Vector3.new(position.X, 16, position.Z), {
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createPart(model, name .. "_Door", Vector3.new(30, 16, 3), Vector3.new(position.X, 8, position.Z), {
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Decorative = true,
	})

	createSign(parent, name .. "_Sign", label, Vector3.new(position.X, 21, position.Z - 2), Vector3.new(24, 5, 0.4), color)
end

local function createNextAreaGate(parent, position)
	local model = Instance.new("Model")
	model.Name = "NextAreaGate"
	model:SetAttribute("Decorative", true)
	model.Parent = parent

	createPart(model, "NextAreaGateFrame_LeftPost", Vector3.new(3, 17, 3), Vector3.new(position.X - 14, 8.5, position.Z), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(model, "NextAreaGateFrame_RightPost", Vector3.new(3, 17, 3), Vector3.new(position.X + 14, 8.5, position.Z), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	local topFrame = createPart(model, "NextAreaGateFrame_Top", Vector3.new(31, 3, 3), Vector3.new(position.X, 17.5, position.Z), {
		Color = COLORS.Mint,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(model, "NextAreaGateFrame_BottomGlow", Vector3.new(29, 0.35, 2), Vector3.new(position.X, 1.15, position.Z - 0.3), {
		Color = COLORS.Mint,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Decorative = true,
	})
	local door = createPart(model, "NextAreaGate_Door", Vector3.new(25, 13, 1.2), Vector3.new(position.X, 7.2, position.Z), {
		Color = Color3.fromRGB(190, 235, 255),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.45,
		Decorative = true,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NextAreaPrompt"
	prompt.ActionText = "Enter"
	prompt.ObjectText = "Area 2"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = door

	createPart(model, "NextAreaLockIcon", Vector3.new(4.5, 4.5, 0.8), Vector3.new(position.X, 9, position.Z - 1), {
		Color = COLORS.Gold,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.08,
		Decorative = true,
	})
	createPart(model, "NextAreaLockShackle", Vector3.new(3.2, 2.4, 0.7), Vector3.new(position.X, 12.1, position.Z - 1), {
		Color = COLORS.Gold,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.1,
		Decorative = true,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NextAreaGateBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 95
	billboard.Size = UDim2.new(0, 240, 0, 86)
	billboard.StudsOffset = Vector3.new(0, 4.8, 0)
	billboard.Parent = topFrame

	local frame = Instance.new("Frame")
	frame.Name = "NextAreaGateBillboardFrame"
	frame.BackgroundColor3 = Color3.fromRGB(16, 28, 34)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Mint
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "NextAreaGateTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0, 12, 0, 8)
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Text = "NEXT AREA"
	title.TextColor3 = COLORS.Mint
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.35
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "NextAreaGateSubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Position = UDim2.new(0, 12, 0, 48)
	subtitle.Size = UDim2.new(1, -24, 0, 28)
	subtitle.Text = "Coming Soon"
	subtitle.TextColor3 = COLORS.White
	subtitle.TextScaled = true
	subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Parent = frame

	createSign(parent, "NextAreaGateSign", "AREA 2", Vector3.new(position.X, 23, position.Z - 2), Vector3.new(28, 5, 0.4), COLORS.Mint)
	createSign(parent, "NextAreaRequirementSign", "Unlock Soon", Vector3.new(position.X, 14, position.Z - 3), Vector3.new(24, 4, 0.4), COLORS.White)
end

local function createArea2Preview(parent, position)
	-- Area 2 Preview Freeze v1:
	-- This is a preview placeholder, not the final Area 2 map.
	-- Keep Area2ArrivalPad and Area2ReturnPrompt names stable because server movement
	-- and client prompt wiring resolve them by name. This area provides round-trip
	-- travel only; do not add CurrentArea, UnlockedAreas, saves, or formal Area 2
	-- systems here without a separate design pass.
	--
	-- Protected preview names:
	-- Area2PreviewZone, Area2ArrivalPad, Area2ReturnPrompt, Area2ReturnPad
	-- Area2PreviewBillboard, Area2ReturnBillboard
	local model = Instance.new("Model")
	model.Name = "Area2PreviewZone"
	model:SetAttribute("PreviewOnly", true)
	model.Parent = parent

	createPart(model, "Area2PlaceholderPlatform", Vector3.new(54, 1, 54), Vector3.new(position.X, position.Y - 0.4, position.Z), {
		Color = Color3.fromRGB(190, 232, 218),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})

	local arrivalPad = createPart(model, "Area2ArrivalPad", Vector3.new(18, 0.35, 18), Vector3.new(position.X, position.Y + 0.28, position.Z), {
		Color = COLORS.Mint,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	createPart(model, "Area2ReturnPad", Vector3.new(13, 0.22, 13), Vector3.new(position.X + 17, position.Y + 0.2, position.Z + 13), {
		Color = Color3.fromRGB(70, 155, 225),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	local returnPart = createPart(model, "Area2ReturnPromptPart", Vector3.new(9, 0.3, 9), Vector3.new(position.X + 17, position.Y + 0.48, position.Z + 13), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.Name = "Area2ReturnPrompt"
	returnPrompt.ActionText = "Return"
	returnPrompt.ObjectText = "Lobby"
	returnPrompt.HoldDuration = 0
	returnPrompt.MaxActivationDistance = 12
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.Enabled = true
	returnPrompt.Parent = returnPart

	createPart(model, "Area2PreviewTrim", Vector3.new(58, 0.25, 58), Vector3.new(position.X, position.Y - 0.95, position.Z), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	createPart(model, "Area2PreviewBoundary_North", Vector3.new(56, 2, 1.2), Vector3.new(position.X, position.Y + 0.75, position.Z - 27), {
		Color = Color3.fromRGB(95, 180, 225),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = false,
	})
	createPart(model, "Area2PreviewBoundary_South", Vector3.new(56, 2, 1.2), Vector3.new(position.X, position.Y + 0.75, position.Z + 27), {
		Color = Color3.fromRGB(95, 180, 225),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = false,
	})
	createPart(model, "Area2PreviewBoundary_West", Vector3.new(1.2, 2, 56), Vector3.new(position.X - 27, position.Y + 0.75, position.Z), {
		Color = Color3.fromRGB(95, 180, 225),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = false,
	})
	createPart(model, "Area2PreviewBoundary_East", Vector3.new(1.2, 2, 56), Vector3.new(position.X + 27, position.Y + 0.75, position.Z), {
		Color = Color3.fromRGB(95, 180, 225),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = false,
	})

	local sign = createSign(model, "Area2PreviewSign", "AREA 2 PREVIEW", Vector3.new(position.X, position.Y + 9, position.Z - 24), Vector3.new(32, 5, 0.4), COLORS.Mint)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Area2PreviewBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 110
	billboard.Size = UDim2.new(0, 260, 0, 86)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.Parent = arrivalPad

	local frame = Instance.new("Frame")
	frame.Name = "Area2PreviewBillboardFrame"
	frame.BackgroundColor3 = Color3.fromRGB(18, 34, 34)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Mint
	stroke.Thickness = 2
	stroke.Transparency = 0.16
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Area2PreviewTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0, 12, 0, 8)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Text = "AREA 2 PREVIEW"
	title.TextColor3 = COLORS.Mint
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.35
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Area2PreviewSubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Position = UDim2.new(0, 12, 0, 48)
	subtitle.Size = UDim2.new(1, -24, 0, 28)
	subtitle.Text = "Full area coming soon"
	subtitle.TextColor3 = COLORS.White
	subtitle.TextScaled = true
	subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Parent = frame

	local returnBillboard = Instance.new("BillboardGui")
	returnBillboard.Name = "Area2ReturnBillboard"
	returnBillboard.AlwaysOnTop = true
	returnBillboard.MaxDistance = 90
	returnBillboard.Size = UDim2.new(0, 220, 0, 76)
	returnBillboard.StudsOffset = Vector3.new(0, 4, 0)
	returnBillboard.Parent = returnPart

	local returnFrame = Instance.new("Frame")
	returnFrame.Name = "Area2ReturnBillboardFrame"
	returnFrame.BackgroundColor3 = Color3.fromRGB(20, 32, 42)
	returnFrame.BackgroundTransparency = 0.08
	returnFrame.BorderSizePixel = 0
	returnFrame.Size = UDim2.fromScale(1, 1)
	returnFrame.Parent = returnBillboard

	local returnCorner = Instance.new("UICorner")
	returnCorner.CornerRadius = UDim.new(0, 12)
	returnCorner.Parent = returnFrame

	local returnStroke = Instance.new("UIStroke")
	returnStroke.Color = COLORS.Blue
	returnStroke.Thickness = 2
	returnStroke.Transparency = 0.18
	returnStroke.Parent = returnFrame

	local returnTitle = Instance.new("TextLabel")
	returnTitle.Name = "Area2ReturnTitle"
	returnTitle.BackgroundTransparency = 1
	returnTitle.Font = Enum.Font.GothamBlack
	returnTitle.Position = UDim2.new(0, 10, 0, 7)
	returnTitle.Size = UDim2.new(1, -20, 0, 30)
	returnTitle.Text = "RETURN TO LOBBY"
	returnTitle.TextColor3 = COLORS.White
	returnTitle.TextScaled = true
	returnTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	returnTitle.TextStrokeTransparency = 0.35
	returnTitle.Parent = returnFrame

	local returnSubtitle = Instance.new("TextLabel")
	returnSubtitle.Name = "Area2ReturnSubtitle"
	returnSubtitle.BackgroundTransparency = 1
	returnSubtitle.Font = Enum.Font.GothamBold
	returnSubtitle.Position = UDim2.new(0, 10, 0, 42)
	returnSubtitle.Size = UDim2.new(1, -20, 0, 24)
	returnSubtitle.Text = "Back to v1 Lobby"
	returnSubtitle.TextColor3 = Color3.fromRGB(220, 240, 255)
	returnSubtitle.TextScaled = true
	returnSubtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	returnSubtitle.TextStrokeTransparency = 0.55
	returnSubtitle.Parent = returnFrame

	sign.CFrame = CFrame.lookAt(sign.Position, Vector3.new(position.X, sign.Position.Y, position.Z))
end

local function createWinPad(parent, name, position, rewardWins, color)
	local pad = createPart(parent, name, Vector3.new(18, 1, 18), position, {
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	pad:SetAttribute("RewardWins", rewardWins)
	addTag(pad, "WinPad")

	createRing(parent, name .. "_Ring", Vector3.new(position.X, position.Y + 0.7, position.Z), 26, 26, COLORS.Gold)
	createSign(parent, name .. "_Sign", "+" .. tostring(rewardWins) .. " WINS", Vector3.new(position.X, 12, position.Z - 15), Vector3.new(24, 5, 0.4), COLORS.Gold)

	return pad
end

local function createZone(parent, name, centerZ, color, label)
	createPart(parent, name .. "_Floor", Vector3.new(90, 1, 90), Vector3.new(0, 0, centerZ), {
		Color = color,
		Material = Enum.Material.Concrete,
		Reflectance = 0,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})

	createPart(parent, name .. "_BorderFront", Vector3.new(90, 0.2, 2), Vector3.new(0, 0.65, centerZ - 45), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createPart(parent, name .. "_BorderBack", Vector3.new(90, 0.2, 2), Vector3.new(0, 0.65, centerZ + 45), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createPart(parent, name .. "_BorderLeft", Vector3.new(2, 0.2, 90), Vector3.new(-45, 0.65, centerZ), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createPart(parent, name .. "_BorderRight", Vector3.new(2, 0.2, 90), Vector3.new(45, 0.65, centerZ), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createSign(parent, name .. "_Title", label, Vector3.new(0, 15, centerZ - 38), Vector3.new(34, 6, 0.4), color)
end

local function createAcademyMarker(parent, name, label, position, color)
	createPart(parent, name .. "_Pad", Vector3.new(18, 0.8, 18), position, {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})

	createPart(parent, name .. "_ColorBar", Vector3.new(16, 0.35, 2), Vector3.new(position.X, position.Y + 0.65, position.Z - 7), {
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createSign(parent, name .. "_Sign", label, Vector3.new(position.X, 10, position.Z - 11), Vector3.new(22, 4.5, 0.4), color)
end

local function createPlaceholderPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlaceholderPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.Enabled = false
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = parent
	return prompt
end

local function createRankingBoardGui(board, titleText, accentColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RankingWallBoard"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 70
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "RankingWallRows"
	frame.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 3
	stroke.Transparency = 0.18
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "RankingWallTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0.06, 0, 0.06, 0)
	title.Size = UDim2.new(0.88, 0, 0.18, 0)
	title.Text = titleText
	title.TextColor3 = accentColor
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.35
	title.Parent = frame

	local soon = Instance.new("TextLabel")
	soon.Name = "ComingSoon"
	soon.BackgroundTransparency = 1
	soon.Font = Enum.Font.GothamBold
	soon.Position = UDim2.new(0.08, 0, 0.25, 0)
	soon.Size = UDim2.new(0.84, 0, 0.13, 0)
	soon.Text = "Coming Soon"
	soon.TextColor3 = COLORS.White
	soon.TextScaled = true
	soon.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	soon.TextStrokeTransparency = 0.55
	soon.Parent = frame

	for index = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Name = "PlaceholderRow" .. tostring(index)
		row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(22, 26, 34) or Color3.fromRGB(18, 22, 30)
		row.BackgroundTransparency = 0.12
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBold
		row.Position = UDim2.new(0.08, 0, 0.4 + ((index - 1) * 0.13), 0)
		row.Size = UDim2.new(0.84, 0, 0.1, 0)
		row.Text = tostring(index) .. ". ??? - Soon"
		row.TextColor3 = index == 1 and Color3.fromRGB(255, 235, 150) or Color3.fromRGB(230, 235, 245)
		row.TextScaled = true
		row.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		row.TextStrokeTransparency = 0.7
		row.Parent = frame
	end

	return gui
end

local function createChestStation(parent, position)
	local station = Instance.new("Model")
	station.Name = "WorldChestStation"
	station.Parent = parent

	createAcademyMarker(station, "WorldChestStation", "CHEST", position, COLORS.Gold)

	local chest = createPart(station, "WorldChestModel", Vector3.new(10, 5.5, 7), Vector3.new(position.X, position.Y + 3, position.Z), {
		Color = Color3.fromRGB(138, 96, 52),
		Material = Enum.Material.Wood,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	createChestStatusBillboard(chest)

	createPart(station, "WorldChestLid", Vector3.new(10.8, 1.3, 7.8), Vector3.new(position.X, position.Y + 6.1, position.Z), {
		Color = COLORS.Gold,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(station, "WorldChestBand", Vector3.new(1.2, 6.2, 7.8), Vector3.new(position.X, position.Y + 3.2, position.Z), {
		Color = COLORS.Gold,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	local promptPart = createPart(station, "ChestPromptPart", Vector3.new(12, 1, 9), Vector3.new(position.X, position.Y + 0.9, position.Z), {
		Color = Color3.fromRGB(255, 230, 130),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.55,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})

	local chestPrompt = createPlaceholderPrompt(promptPart, "Open Chest", "Basic Chest")
	chestPrompt.Name = "ChestOpenPrompt"
	chestPrompt.Enabled = true
	chestPrompt.HoldDuration = 0
	chestPrompt.MaxActivationDistance = 12
	chestPrompt.RequiresLineOfSight = false
	local readyIcon = createPart(station, "ChestReadyIcon", Vector3.new(1.5, 1.5, 1.5), Vector3.new(position.X + 6.2, position.Y + 7.2, position.Z), {
		Color = COLORS.Slate,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Decorative = true,
	})
	readyIcon.Shape = Enum.PartType.Ball
	createSign(parent, "ChestSign", "CHEST", Vector3.new(position.X, 14, position.Z - 12), Vector3.new(24, 5, 0.4), COLORS.Gold)
end

local function createRankingWall(parent, position)
	local model = Instance.new("Model")
	model.Name = "RankingWall"
	model.Parent = parent

	createPart(model, "RankingWall_Base", Vector3.new(28, 1, 10), position, {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	createPart(model, "RankingWall_Back", Vector3.new(30, 15, 2), Vector3.new(position.X, position.Y + 8, position.Z + 4), {
		Color = COLORS.Dark,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	local boardY = position.Y + 8
	local boardZ = position.Z + 2.6
	local topIQBoard = createPart(model, "TopIQBoard", Vector3.new(8, 9, 0.6), Vector3.new(position.X - 9, boardY, boardZ), {
		Color = Color3.fromRGB(18, 22, 28),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	local rarestBoard = createPart(model, "RarestBoard", Vector3.new(8, 9, 0.6), Vector3.new(position.X, boardY, boardZ), {
		Color = Color3.fromRGB(18, 22, 28),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	local indexBoard = createPart(model, "IndexBoard", Vector3.new(8, 9, 0.6), Vector3.new(position.X + 9, boardY, boardZ), {
		Color = Color3.fromRGB(18, 22, 28),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createRankingBoardGui(topIQBoard, "IQ LEADERBOARD", COLORS.Gold)
	createRankingBoardGui(rarestBoard, "RAREST FINDS", Color3.fromRGB(255, 150, 220))
	createRankingBoardGui(indexBoard, "INDEX MASTERS", COLORS.Blue)

	createSign(parent, "RankingWallSign", "TOP GENIUSES", Vector3.new(position.X, position.Y + 18, position.Z + 1.8), Vector3.new(28, 4.5, 0.4), COLORS.Gold)
	createSign(parent, "TopIQBoardSign", "TOP IQ", Vector3.new(position.X - 9, position.Y + 9, position.Z + 1.6), Vector3.new(7, 3, 0.4), COLORS.White)
	createSign(parent, "RarestBoardSign", "RAREST", Vector3.new(position.X, position.Y + 9, position.Z + 1.6), Vector3.new(7, 3, 0.4), COLORS.Gold)
	createSign(parent, "IndexBoardSign", "INDEX", Vector3.new(position.X + 9, position.Y + 9, position.Z + 1.6), Vector3.new(7, 3, 0.4), COLORS.White)
end

local function createQuestNpc(parent, position)
	createAcademyMarker(parent, "QuestNpcSpot", "QUEST", position, COLORS.Green)

	local body = createPart(parent, "ProfessorBrain_Body", Vector3.new(4, 6, 3), Vector3.new(position.X, position.Y + 4, position.Z), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createPart(parent, "ProfessorBrain_Head", Vector3.new(3.5, 3.5, 3.5), Vector3.new(position.X, position.Y + 8.5, position.Z), {
		Color = Color3.fromRGB(245, 216, 184),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createSign(parent, "ProfessorBrain_Billboard", "QUEST", Vector3.new(position.X, 14, position.Z - 4), Vector3.new(16, 4, 0.4), COLORS.Green)
	createQuestStatusBillboard(body)

	local readyIcon = createPart(parent, "QuestReadyIcon", Vector3.new(1.4, 1.4, 1.4), Vector3.new(position.X + 3.4, position.Y + 10.5, position.Z), {
		Color = COLORS.Slate,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Decorative = true,
	})
	readyIcon.Shape = Enum.PartType.Ball

	local questPrompt = createPlaceholderPrompt(body, "Talk", "Quest NPC")
	questPrompt.Name = "QuestOpenPrompt"
	questPrompt.Enabled = true
end

local function createTrainingDummy(parent, position)
	createAcademyMarker(parent, "TrainingDummySpot", "TRAINING", position, COLORS.Red)

	local area = Instance.new("Model")
	area.Name = "TrainingDummyArea"
	area:SetAttribute("Decorative", true)
	area.Parent = parent

	createPart(area, "TrainingDummyBase", Vector3.new(11, 1, 9), Vector3.new(position.X, position.Y + 0.65, position.Z), {
		Color = Color3.fromRGB(72, 54, 64),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = false,
		CanQuery = true,
	})

	local dummy = createPart(area, "TrainingDummyBody", Vector3.new(4.5, 7, 3.4), Vector3.new(position.X, position.Y + 5, position.Z), {
		Color = COLORS.Red,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createPart(area, "TrainingDummyHead", Vector3.new(3.2, 3.2, 3.2), Vector3.new(position.X, position.Y + 10.3, position.Z), {
		Color = COLORS.Gold,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	createPart(area, "TrainingDummyLeftArm", Vector3.new(1.2, 5.5, 1.2), Vector3.new(position.X - 3.6, position.Y + 5.6, position.Z), {
		Color = Color3.fromRGB(190, 72, 100),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(area, "TrainingDummyRightArm", Vector3.new(1.2, 5.5, 1.2), Vector3.new(position.X + 3.6, position.Y + 5.6, position.Z), {
		Color = Color3.fromRGB(190, 72, 100),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(area, "TrainingDummyTarget", Vector3.new(2.3, 2.3, 0.35), Vector3.new(position.X, position.Y + 5.7, position.Z - 1.75), {
		Color = Color3.fromRGB(245, 185, 195),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainingDummyBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 68
	billboard.Size = UDim2.new(0, 210, 0, 78)
	billboard.StudsOffset = Vector3.new(0, 5.3, 0)
	billboard.Parent = dummy

	local frame = Instance.new("Frame")
	frame.Name = "TrainingDummyBillboardFrame"
	frame.BackgroundColor3 = Color3.fromRGB(38, 24, 32)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Red
	stroke.Thickness = 2
	stroke.Transparency = 0.25
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "TrainingDummyTitle"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.new(0, 12, 0, 8)
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Text = "TRAINING"
	title.TextColor3 = COLORS.Red
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.35
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "TrainingDummySubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Position = UDim2.new(0, 12, 0, 42)
	subtitle.Size = UDim2.new(1, -24, 0, 24)
	subtitle.Text = "Coming Soon"
	subtitle.TextColor3 = COLORS.White
	subtitle.TextScaled = true
	subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Parent = frame
end

local function setupLighting()
	Lighting.Brightness = 2.8
	Lighting.ClockTime = 14
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(130, 135, 155)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 175)

	local bloom = Lighting:FindFirstChild("BrainRNG_Bloom") or Instance.new("BloomEffect")
	bloom.Name = "BrainRNG_Bloom"
	bloom.Intensity = 0.12
	bloom.Size = 24
	bloom.Threshold = 1.05
	bloom.Parent = Lighting

	local color = Lighting:FindFirstChild("BrainRNG_ColorCorrection") or Instance.new("ColorCorrectionEffect")
	color.Name = "BrainRNG_ColorCorrection"
	color.Brightness = 0.04
	color.Contrast = 0.12
	color.Saturation = 0.12
	color.Parent = Lighting
end

function SimpleWorldBuilder.CreateMap()
	setupLighting()

	local oldMap = Workspace:FindFirstChild(MAP_NAME)
	if oldMap then
		oldMap:Destroy()
	end

	local map = createFolder(Workspace, MAP_NAME)

	createPart(map, "LobbyGrass", Vector3.new(118, 0.6, 118), Vector3.new(0, -0.25, 0), {
		Color = COLORS.Grass,
		Material = Enum.Material.Grass,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	createZone(map, "SimulatorLobby", 0, COLORS.Floor, "SIMULATOR LOBBY")

	local spawnPart = createPart(map, "PlayerSpawn", Vector3.new(14, 1, 14), Vector3.new(0, 0.6, 0), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = spawnPart.Position + Vector3.new(0, 1, 0)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.CanTouch = false
	spawnLocation.CanQuery = false
	spawnLocation.Neutral = true
	spawnLocation.Parent = map

	createPart(map, "MainPath_North", Vector3.new(12, 0.25, 46), Vector3.new(0, 0.72, -22), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createPart(map, "MainPath_South", Vector3.new(12, 0.25, 32), Vector3.new(0, 0.72, 25), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createPart(map, "MainPath_West", Vector3.new(36, 0.25, 10), Vector3.new(-22, 0.72, -4), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})
	createPart(map, "MainPath_East", Vector3.new(36, 0.25, 10), Vector3.new(22, 0.72, -4), {
		Color = COLORS.FloorAlt,
		Material = Enum.Material.Concrete,
		Decorative = true,
	})

	createPart(map, "RollPlatform", Vector3.new(22, 1, 18), Vector3.new(0, 0.9, -24), {
		Color = COLORS.Blue,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	})
	createPart(map, "RollPlatform_InnerTile", Vector3.new(16, 0.3, 12), Vector3.new(0, 1.45, -24), {
		Color = Color3.fromRGB(235, 248, 255),
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(map, "RollPlatform_FrontEdge", Vector3.new(24, 0.6, 1), Vector3.new(0, 1.6, -33), {
		Color = COLORS.White,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(map, "RollPlatform_BackEdge", Vector3.new(24, 0.6, 1), Vector3.new(0, 1.6, -15), {
		Color = COLORS.White,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(map, "RollPlatform_LeftEdge", Vector3.new(1, 0.6, 18), Vector3.new(-11.5, 1.6, -24), {
		Color = COLORS.White,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createPart(map, "RollPlatform_RightEdge", Vector3.new(1, 0.6, 18), Vector3.new(11.5, 1.6, -24), {
		Color = COLORS.White,
		Material = Enum.Material.SmoothPlastic,
		Decorative = true,
	})
	createSign(map, "RollPlatform_Sign", "ROLL", Vector3.new(0, 12, -39), Vector3.new(28, 5.5, 0.4), COLORS.Blue)

	-- v1 Lobby Freeze:
	-- This is the approved simulator lobby layout. Keep these object names stable because
	-- UIController resolves several world objects by name for prompts, billboards, and chest animation.
	-- Position/visual polish is allowed, but do not mix lobby polish with saves, rewards,
	-- ranking data, training rewards, teleport/unlock logic, or new persistence fields.
	--
	-- Protected world names:
	-- ProfessorBrain_Body, QuestStatusBillboard, QuestReadyIcon
	-- WorldChestStation, WorldChestModel, ChestStatusBillboard, ChestReadyIcon
	-- RankingWall, TopIQBoard, RarestBoard, IndexBoard
	-- NextAreaGate, NextAreaGateBillboard, NextAreaLockIcon
	-- TrainingDummyArea, TrainingDummyBillboard
	--
	-- v1 Lobby QA checklist before approval:
	-- Spawn can distinguish Quest, Chest, Gate, Ranking, and Training at a glance.
	-- Billboards do not overlap, glow/neon is restrained, and main paths are not blocked.
	-- Placeholder content keeps Coming Soon/Soon wording.
	-- UIController loads without local register errors and Output has no red errors.
	createRankingWall(map, Vector3.new(-42, 1, -30))
	createAcademyMarker(map, "AchievementBoard", "ACHIEVEMENT", Vector3.new(34, 1, 12), COLORS.Purple)
	createChestStation(map, Vector3.new(34, 1, -20))
	createQuestNpc(map, Vector3.new(-34, 1, 12))
	createTrainingDummy(map, Vector3.new(0, 1, 34))

	createNextAreaGate(map, Vector3.new(0, 0, -62))
	createArea2Preview(map, Vector3.new(600, 1, 0))
	createPart(map, "Zone2_Target", Vector3.new(8, 1, 8), Vector3.new(0, 0.6, 92), {
		Color = COLORS.Mint,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})

	createSign(map, "Plaza_Info_Sign", "ROLL  QUEST  CHEST  INDEX", Vector3.new(0, 12, 18), Vector3.new(34, 4.5, 0.4), COLORS.White)
	createWinPad(map, "WinPad_Plaza", Vector3.new(22, 1, 34), 1, COLORS.Gold)

	createZone(map, "LegacyZone2", 130, COLORS.Blue, "ZONE 2 ARCHIVE")
	createWinPad(map, "WinPad_Zone2", Vector3.new(28, 1, 145), 3, COLORS.Gold)

	createPortal(map, "Gate_Zone3", Vector3.new(0, 0, 185), COLORS.Purple, 2500, "Zone3_Target")
	createPart(map, "Zone3_Target", Vector3.new(8, 1, 8), Vector3.new(0, 0.6, 222), {
		Color = COLORS.Purple,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	})

	createZone(map, "LegacyZone3", 260, COLORS.Purple, "ZONE 3 ARCHIVE")
	createWinPad(map, "WinPad_Zone3", Vector3.new(28, 1, 275), 10, COLORS.Gold)

	createSign(map, "Legacy_Info_Sign", "LEGACY TRAINING AREA", Vector3.new(-28, 14, 110), Vector3.new(30, 5, 0.4), COLORS.Pink)
	createSign(map, "Rebirth_ComingSoon_Sign", "REBIRTH SOON", Vector3.new(-28, 14, 275), Vector3.new(30, 5, 0.4), COLORS.White)

	print("[SimpleWorldBuilder] Simple simulator lobby greybox created. Children:", #map:GetChildren())

	return map
end

function SimpleWorldBuilder.BuildMap()
	return SimpleWorldBuilder.CreateMap()
end

function SimpleWorldBuilder.Init()
	return SimpleWorldBuilder.CreateMap()
end

return SimpleWorldBuilder
