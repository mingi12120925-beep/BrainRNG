-- ServerScriptService/SchoolRebuild.server.lua
-- Final owner of the school facade.
-- Waits for legacy styling passes, removes their school visuals, then builds once.
-- No repeated full rebuilds and no coplanar decorative layers.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local LOBBY_NAME = "Lobby_Prestige0_School"
local GATE_AREA_NAME = "GateArea"
local BUILD_NAME = "P0_SchoolBuilding_Rebuilt"
local FIND_TIMEOUT_SECONDS = 25
local LEGACY_SETTLE_TIMEOUT_SECONDS = 4
local WORLD_SCALE = 2.5
local BUILD_VERSION = "ScratchRebuildV2_StableSinglePass"

local COLORS = {
	Brick = Color3.fromRGB(202, 94, 74),
	BrickDark = Color3.fromRGB(164, 70, 58),
	Blue = Color3.fromRGB(60, 112, 166),
	BlueDark = Color3.fromRGB(35, 68, 105),
	BlueLight = Color3.fromRGB(116, 183, 224),
	Cream = Color3.fromRGB(239, 230, 204),
	Stone = Color3.fromRGB(178, 187, 194),
	Window = Color3.fromRGB(40, 83, 116),
	Gold = Color3.fromRGB(222, 166, 56),
	Ink = Color3.fromRGB(25, 38, 56),
	White = Color3.fromRGB(245, 248, 252),
}

local doorApplying = false

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
	item.CanTouch = false
	item.CanQuery = options.CanQuery ~= false
	item.CastShadow = options.CastShadow ~= false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
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
	if doorApplying or not door or not door.Parent or not door:IsA("BasePart") then
		return false
	end

	doorApplying = true
	door.Size = w(Vector3.new(13.5, 15.2, 0.3))
	door.Position = w(Vector3.new(0, 9.8, 66.6))
	door.Material = Enum.Material.SmoothPlastic
	door.Color = COLORS.Blue
	door.Transparency = 0
	door.Reflectance = 0
	door.Anchored = true
	door.CanCollide = false
	door.CanTouch = false
	door.CanQuery = true
	door.CastShadow = false
	door.TopSurface = Enum.SurfaceType.Smooth
	door.BottomSurface = Enum.SurfaceType.Smooth
	clearEffects(door)
	doorApplying = false
	return true
end

local function connectDoorGuard(door)
	if door:GetAttribute("StableSchoolDoorGuard") then
		configureDoor(door)
		return
	end

	door:SetAttribute("StableSchoolDoorGuard", true)
	for _, propertyName in ipairs({
		"Size",
		"Position",
		"Material",
		"Color",
		"Transparency",
		"Reflectance",
		"CanCollide",
		"CanTouch",
		"CanQuery",
	}) do
		door:GetPropertyChangedSignal(propertyName):Connect(function()
			task.defer(function()
				configureDoor(door)
			end)
		end)
	end
	configureDoor(door)
end

local function readExistingSignText(signPart, name, fallback)
	local label = signPart and signPart:FindFirstChild(name, true)
	if label and label:IsA("TextLabel") and label.Text ~= "" then
		return label.Text
	end
	return fallback
end

local function makeSignLabel(parent, name, text, position, size, font, textSize, color)
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
	label.TextScaled = false
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function configureSign(signPart)
	if not signPart or not signPart:IsA("BasePart") then
		return false
	end

	local titleText = readExistingSignText(signPart, "NextAreaGateTitle", "ELEMENTARY SCHOOL")
	local subtitleText = readExistingSignText(signPart, "NextAreaGateSubtitle", "IQ 80.500 REQUIRED")

	-- Destroy old labels instead of reusing objects carrying legacy property watchers.
	for _, child in ipairs(signPart:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end

	signPart.Size = w(Vector3.new(22, 5.2, 0.4))
	signPart.Position = w(Vector3.new(0, 25.6, 65.4))
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
	gui.LightInfluence = 0.15
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
	accent.Size = UDim2.fromScale(1, 0.1)
	accent.Parent = panel

	makeSignLabel(
		panel,
		"NextAreaGateTitle",
		titleText,
		UDim2.fromScale(0.03, 0.13),
		UDim2.fromScale(0.94, 0.49),
		Enum.Font.GothamBlack,
		78,
		COLORS.White
	)
	makeSignLabel(
		panel,
		"NextAreaGateSubtitle",
		subtitleText,
		UDim2.fromScale(0.04, 0.63),
		UDim2.fromScale(0.92, 0.27),
		Enum.Font.GothamBold,
		42,
		COLORS.BlueLight
	)
	return true
end

local function buildSchool(gateArea)
	local oldBuild = gateArea:FindFirstChild(BUILD_NAME)
	if oldBuild then
		oldBuild:Destroy()
	end

	local build = Instance.new("Model")
	build.Name = BUILD_NAME
	build.Parent = gateArea

	-- Every major block has a visible air gap. No shared coplanar faces.
	makePart(build, "Foundation", Vector3.new(66, 1.2, 24), Vector3.new(0, 0.6, 79), COLORS.Stone, Enum.Material.Concrete)
	makePart(build, "FrontStepLower", Vector3.new(22, 0.7, 6.5), Vector3.new(0, 0.35, 62.8), COLORS.Stone, Enum.Material.Concrete)
	makePart(build, "FrontStepUpper", Vector3.new(18, 0.7, 3.5), Vector3.new(0, 1.2, 64.8), COLORS.Cream, Enum.Material.Concrete)

	makePart(build, "LeftWing", Vector3.new(21.5, 19.5, 18), Vector3.new(-19.5, 11.35, 79), COLORS.Brick, Enum.Material.Brick)
	makePart(build, "RightWing", Vector3.new(21.5, 19.5, 18), Vector3.new(19.5, 11.35, 79), COLORS.Brick, Enum.Material.Brick)
	makePart(build, "CenterHall", Vector3.new(16, 25.5, 14), Vector3.new(0, 14.25, 75), COLORS.BrickDark, Enum.Material.Brick)

	makePart(build, "LeftRoof", Vector3.new(23.5, 2.2, 20), Vector3.new(-19.5, 22.5, 79), COLORS.Blue)
	makePart(build, "RightRoof", Vector3.new(23.5, 2.2, 20), Vector3.new(19.5, 22.5, 79), COLORS.Blue)
	makePart(build, "CenterRoof", Vector3.new(18, 2.4, 16), Vector3.new(0, 28.4, 75), COLORS.BlueDark)

	-- Single opaque window panels: no glass/frame layer stack and no transparency sorting.
	makePart(build, "LeftWindow", Vector3.new(9.5, 8.5, 0.45), Vector3.new(-19.5, 12, 68.5), COLORS.Window, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	makePart(build, "RightWindow", Vector3.new(9.5, 8.5, 0.45), Vector3.new(19.5, 12, 68.5), COLORS.Window, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})

	-- Frame pieces have small gaps at corners and sit in front of the opaque door.
	makePart(build, "DoorFrameLeft", Vector3.new(1.5, 15.5, 0.45), Vector3.new(-7.6, 10.05, 65.95), COLORS.Cream)
	makePart(build, "DoorFrameRight", Vector3.new(1.5, 15.5, 0.45), Vector3.new(7.6, 10.05, 65.95), COLORS.Cream)
	makePart(build, "DoorFrameTop", Vector3.new(16.4, 1.4, 0.45), Vector3.new(0, 18.65, 65.95), COLORS.Cream)

	makePart(build, "LeftColumn", Vector3.new(2.2, 19.5, 2.2), Vector3.new(-31, 11.35, 68.4), COLORS.Cream)
	makePart(build, "RightColumn", Vector3.new(2.2, 19.5, 2.2), Vector3.new(31, 11.35, 68.4), COLORS.Cream)

	makePart(build, "CrestBase", Vector3.new(7, 1.1, 3), Vector3.new(0, 30.3, 75), COLORS.Gold)
	makePart(build, "CrestStem", Vector3.new(1.1, 3.6, 1.1), Vector3.new(0, 32.85, 75), COLORS.Gold)
	makePart(build, "CrestTop", Vector3.new(4, 0.9, 1), Vector3.new(0, 35.25, 75), COLORS.Gold)

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

local function removeAllByName(root, name)
	local removed = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

local function waitForDependencies(map)
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	local lobby, gateArea, gateModel, door, signPart

	repeat
		lobby = map:FindFirstChild(LOBBY_NAME)
		gateArea = lobby and lobby:FindFirstChild(GATE_AREA_NAME)
		gateModel = map:FindFirstChild("NextAreaGate")
		door = gateModel and gateModel:FindFirstChild("NextAreaGate_Door")
		signPart = gateModel and gateModel:FindFirstChild("P0_GateFixedSign")
		if gateArea and gateModel and door and signPart then
			break
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return lobby, gateArea, gateModel, door, signPart
end

local function waitForLegacyPasses(map)
	local deadline = os.clock() + LEGACY_SETTLE_TIMEOUT_SECONDS
	while os.clock() < deadline do
		local structureDone = map:FindFirstChild("SimulatorStructureUpgrade") ~= nil
		local signDone = map:GetAttribute("SignStyle") ~= nil
		if structureDone and signDone then
			return true
		end
		task.wait(0.05)
	end
	return false
end

local function rebuildOnce(map)
	if not map or not map.Parent or map:GetAttribute("SchoolStableBuildComplete") then
		return
	end

	local _, gateArea, gateModel, door, signPart = waitForDependencies(map)
	if not gateArea or not gateModel or not door or not signPart then
		warn("[SchoolRebuild] Required gate objects missing; rebuild skipped.")
		return
	end

	waitForLegacyPasses(map)

	local removedOldParts = 0
	for _, child in ipairs(gateArea:GetChildren()) do
		child:Destroy()
		removedOldParts += 1
	end

	local legacyRemoved = removeLegacyGateVisuals(gateModel, door, signPart)
	local archRemoved = removeAllByName(map, "SchoolPortalArch")
	local build = buildSchool(gateArea)
	connectDoorGuard(door)
	local signReady = configureSign(signPart)

	map:SetAttribute("SchoolStableBuildComplete", true)
	map:SetAttribute("SchoolBuildVersion", BUILD_VERSION)
	map:SetAttribute("SchoolOldPartsRemoved", removedOldParts + legacyRemoved + archRemoved)
	print(
		"[SchoolRebuild] stableSinglePass=true rebuilt="
			.. tostring(build ~= nil)
			.. " removedOldParts="
			.. tostring(removedOldParts + legacyRemoved + archRemoved)
			.. " preservedPrompt="
			.. tostring(door:FindFirstChildOfClass("ProximityPrompt") ~= nil)
			.. " signReady="
			.. tostring(signReady)
	)
end

local function attach(map)
	map.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "SchoolPortalArch" then
			task.defer(function()
				if descendant.Parent then
					descendant:Destroy()
				end
			end)
		end
	end)

	task.spawn(function()
		rebuildOnce(map)
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
		warn("[SchoolRebuild] SimpleMap missing; rebuild disabled.")
	end
end
