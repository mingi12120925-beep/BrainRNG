-- ServerScriptService/SchoolRebuild.server.lua
-- Deletes the old school facade and rebuilds a clean, non-overlapping school.
-- The existing gate door and ProximityPrompt instances are preserved so the
-- progression and teleport connections remain intact.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local LOBBY_NAME = "Lobby_Prestige0_School"
local GATE_AREA_NAME = "GateArea"
local BUILD_NAME = "P0_SchoolBuilding_Rebuilt"
local FIND_TIMEOUT_SECONDS = 25
local WORLD_SCALE = 2.5

local COLORS = {
	Brick = Color3.fromRGB(202, 94, 74),
	BrickDark = Color3.fromRGB(164, 70, 58),
	Blue = Color3.fromRGB(60, 112, 166),
	BlueDark = Color3.fromRGB(35, 68, 105),
	BlueLight = Color3.fromRGB(116, 183, 224),
	Cream = Color3.fromRGB(239, 230, 204),
	Stone = Color3.fromRGB(178, 187, 194),
	Glass = Color3.fromRGB(46, 92, 126),
	Gold = Color3.fromRGB(222, 166, 56),
	Ink = Color3.fromRGB(25, 38, 56),
	White = Color3.fromRGB(245, 248, 252),
}

local function w(value)
	return value * WORLD_SCALE
end

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function makePart(parent, name, size, position, color, material, options)
	options = options or {}
	local item = Instance.new("Part")
	item.Name = name
	item.Size = w(size)
	item.Position = w(position)
	item.Anchored = true
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Transparency = options.Transparency or 0
	item.Reflectance = 0
	item.CanCollide = options.CanCollide ~= false
	item.CanTouch = options.CanTouch == true
	item.CanQuery = options.CanQuery ~= false
	item.CastShadow = options.CastShadow ~= false
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

local function clearEffects(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Sparkles")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Highlight")
		then
			descendant:Destroy()
		end
	end
end

local function configureDoor(door)
	if not door or not door:IsA("BasePart") then
		return false
	end

	-- Bottom is Y=2.0, leaving a gap above the upper step. Back face is
	-- separated from the frame and from CenterHall.
	door.Size = w(Vector3.new(13.5, 15.4, 0.3))
	door.Position = w(Vector3.new(0, 9.7, 66.55))
	door.Material = Enum.Material.SmoothPlastic
	door.Color = COLORS.Blue
	door.Transparency = 0.16
	door.Reflectance = 0
	door.Anchored = true
	door.CanCollide = false
	door.CanTouch = false
	door.CanQuery = true
	door.CastShadow = false
	door.TopSurface = Enum.SurfaceType.Smooth
	door.BottomSurface = Enum.SurfaceType.Smooth
	clearEffects(door)
	return true
end

local function preserveTextLabel(signPart, name)
	local label = signPart and signPart:FindFirstChild(name, true)
	if label and label:IsA("TextLabel") then
		label.Parent = nil
		return label
	end
	return nil
end

local function configureLabel(label, name, text, position, size, font, textSize, color)
	label = label or Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 1
	label.TextScaled = false
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local function configureSign(signPart)
	if not signPart or not signPart:IsA("BasePart") then
		return false
	end

	local title = preserveTextLabel(signPart, "NextAreaGateTitle")
	local subtitle = preserveTextLabel(signPart, "NextAreaGateSubtitle")

	for _, child in ipairs(signPart:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end

	signPart.Size = w(Vector3.new(22, 5.2, 0.4))
	signPart.Position = w(Vector3.new(0, 25.8, 65.8))
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.Color = COLORS.Ink
	signPart.Transparency = 0
	signPart.Reflectance = 0
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.CanTouch = false
	signPart.CanQuery = false
	signPart.CastShadow = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "NextAreaGateSurfaceGui"
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1100, 260)
	gui.Parent = signPart

	local panel = Instance.new("Frame")
	panel.Name = "SignPanel"
	panel.BackgroundColor3 = COLORS.Ink
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = gui

	local accent = Instance.new("Frame")
	accent.Name = "AccentBar"
	accent.BackgroundColor3 = COLORS.BlueLight
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromScale(0, 0)
	accent.Size = UDim2.fromScale(1, 0.1)
	accent.Parent = panel

	title = configureLabel(
		title,
		"NextAreaGateTitle",
		title and title.Text ~= "" and title.Text or "ELEMENTARY SCHOOL",
		UDim2.fromScale(0.03, 0.13),
		UDim2.fromScale(0.94, 0.49),
		Enum.Font.GothamBlack,
		78,
		COLORS.White
	)
	title.Parent = panel

	subtitle = configureLabel(
		subtitle,
		"NextAreaGateSubtitle",
		subtitle and subtitle.Text ~= "" and subtitle.Text or "IQ 80.500 REQUIRED",
		UDim2.fromScale(0.04, 0.63),
		UDim2.fromScale(0.92, 0.27),
		Enum.Font.GothamBold,
		42,
		COLORS.BlueLight
	)
	subtitle.Parent = panel

	return true
end

local function buildWindow(parent, prefix, centerX)
	-- Each layer has a physical Z gap. Frame corners only touch at edges:
	-- horizontal pieces end exactly at the inner faces of vertical pieces.
	makePart(parent, prefix .. "_Recess", Vector3.new(10, 10, 0.45), Vector3.new(centerX, 12, 68.65), COLORS.BlueDark)
	makePart(parent, prefix .. "_Glass", Vector3.new(8.2, 8.2, 0.25), Vector3.new(centerX, 12, 68.25), COLORS.Glass, Enum.Material.Glass, {
		Transparency = 0.12,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	makePart(parent, prefix .. "_FrameTop", Vector3.new(8.1, 0.55, 0.35), Vector3.new(centerX, 16.325, 67.95), COLORS.Cream, nil, { CanCollide = false, CanQuery = false })
	makePart(parent, prefix .. "_FrameBottom", Vector3.new(8.1, 0.55, 0.35), Vector3.new(centerX, 7.675, 67.95), COLORS.Cream, nil, { CanCollide = false, CanQuery = false })
	makePart(parent, prefix .. "_FrameLeft", Vector3.new(0.55, 8.1, 0.35), Vector3.new(centerX - 4.325, 12, 67.95), COLORS.Cream, nil, { CanCollide = false, CanQuery = false })
	makePart(parent, prefix .. "_FrameRight", Vector3.new(0.55, 8.1, 0.35), Vector3.new(centerX + 4.325, 12, 67.95), COLORS.Cream, nil, { CanCollide = false, CanQuery = false })
end

local function buildSchool(gateArea)
	local oldBuild = gateArea:FindFirstChild(BUILD_NAME)
	if oldBuild then
		oldBuild:Destroy()
	end

	local build = Instance.new("Model")
	build.Name = BUILD_NAME
	build.Parent = gateArea

	-- Foundation and steps meet only on their boundary planes.
	makePart(build, "Foundation", Vector3.new(66, 1.4, 24), Vector3.new(0, 0.7, 79), COLORS.Stone, Enum.Material.Concrete)
	makePart(build, "FrontStepLower", Vector3.new(22, 0.8, 7), Vector3.new(0, 0.4, 63), COLORS.Stone, Enum.Material.Concrete)
	makePart(build, "FrontStepUpper", Vector3.new(18, 0.8, 4), Vector3.new(0, 1.2, 65), COLORS.Cream, Enum.Material.Concrete)

	-- Three bodies meet only on their X edges; none occupies another volume.
	makePart(build, "LeftWing", Vector3.new(22, 20, 18), Vector3.new(-19, 11.4, 79), COLORS.Brick, Enum.Material.Brick)
	makePart(build, "RightWing", Vector3.new(22, 20, 18), Vector3.new(19, 11.4, 79), COLORS.Brick, Enum.Material.Brick)
	makePart(build, "CenterHall", Vector3.new(16, 26, 14), Vector3.new(0, 14.4, 75), COLORS.BrickDark, Enum.Material.Brick)

	-- Roof slabs sit above each body with a visible vertical air gap.
	makePart(build, "LeftRoof", Vector3.new(24, 2.4, 20), Vector3.new(-19, 22.75, 79), COLORS.Blue)
	makePart(build, "RightRoof", Vector3.new(24, 2.4, 20), Vector3.new(19, 22.75, 79), COLORS.Blue)
	makePart(build, "CenterRoof", Vector3.new(18, 2.6, 16), Vector3.new(0, 28.75, 75), COLORS.BlueDark)

	buildWindow(build, "LeftWindow", -19)
	buildWindow(build, "RightWindow", 19)

	-- Door frame starts above the top step. Side pieces and top beam touch at
	-- Y=18 but never share volume. Door sits behind the frame with a Z gap.
	makePart(build, "DoorFrameLeft", Vector3.new(1.5, 16, 0.5), Vector3.new(-7.5, 10, 66.0), COLORS.Cream)
	makePart(build, "DoorFrameRight", Vector3.new(1.5, 16, 0.5), Vector3.new(7.5, 10, 66.0), COLORS.Cream)
	makePart(build, "DoorFrameTop", Vector3.new(16.5, 1.5, 0.5), Vector3.new(0, 18.75, 66.0), COLORS.Cream)

	makePart(build, "LeftColumn", Vector3.new(2.4, 20, 2.4), Vector3.new(-30.5, 11.4, 68.5), COLORS.Cream)
	makePart(build, "RightColumn", Vector3.new(2.4, 20, 2.4), Vector3.new(30.5, 11.4, 68.5), COLORS.Cream)

	-- Roof crest pieces meet only on their boundary planes.
	makePart(build, "CrestBase", Vector3.new(7, 1.2, 3), Vector3.new(0, 30.75, 75), COLORS.Gold)
	makePart(build, "CrestStem", Vector3.new(1.2, 4, 1.2), Vector3.new(0, 33.35, 75), COLORS.Gold)
	makePart(build, "CrestTop", Vector3.new(4, 1, 1), Vector3.new(0, 35.85, 75), COLORS.Gold)

	return build
end

local function removeLegacyGateVisuals(gateModel, door, signPart)
	local removed = 0
	for _, child in ipairs(gateModel:GetChildren()) do
		if child ~= door and child ~= signPart then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

local function rebuild(map)
	if not map or not map.Parent then
		return
	end

	local lobby = map:FindFirstChild(LOBBY_NAME)
	local gateArea = lobby and lobby:FindFirstChild(GATE_AREA_NAME)
	local gateModel = map:FindFirstChild("NextAreaGate")
	local door = gateModel and gateModel:FindFirstChild("NextAreaGate_Door")
	local signPart = gateModel and gateModel:FindFirstChild("P0_GateFixedSign")
	if not gateArea or not gateModel or not door or not signPart then
		return
	end

	local removedOldParts = 0
	for _, child in ipairs(gateArea:GetChildren()) do
		child:Destroy()
		removedOldParts += 1
	end

	local legacyRemoved = removeLegacyGateVisuals(gateModel, door, signPart)
	local build = buildSchool(gateArea)
	local doorReady = configureDoor(door)
	local signReady = configureSign(signPart)

	local addOnArch = findDescendant(map, "SchoolPortalArch")
	if addOnArch then
		addOnArch:Destroy()
	end

	map:SetAttribute("SchoolBuildVersion", "ScratchRebuildV1")
	map:SetAttribute("SchoolOldPartsRemoved", removedOldParts + legacyRemoved)
	print(
		"[SchoolRebuild] rebuilt="
			.. tostring(build ~= nil)
			.. " removedOldParts="
			.. tostring(removedOldParts + legacyRemoved)
			.. " preservedPrompt="
			.. tostring(doorReady and door:FindFirstChildOfClass("ProximityPrompt") ~= nil)
			.. " signReady="
			.. tostring(signReady)
	)
end

local function attach(map)
	local scheduled = false
	local function schedule(delaySeconds)
		if scheduled then
			return
		end
		scheduled = true
		task.delay(delaySeconds or 0.1, function()
			scheduled = false
			rebuild(map)
		end)
	end

	map.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "SchoolPortalArch" then
			task.defer(function()
				if descendant.Parent then
					descendant:Destroy()
				end
				schedule(0.05)
			end)
		elseif descendant.Name == "P0_GateFixedSign" or descendant.Name == "NextAreaGate_Door" then
			schedule(0.05)
		end
	end)

	for _, delaySeconds in ipairs({ 0.35, 0.9, 1.8, 3.2 }) do
		task.delay(delaySeconds, function()
			rebuild(map)
		end)
	end
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
		warn("[SchoolRebuild] SimpleMap missing; rebuild disabled.")
	end
end
