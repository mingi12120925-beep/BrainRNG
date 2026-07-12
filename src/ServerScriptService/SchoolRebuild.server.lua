-- ServerScriptService/SchoolRebuild.server.lua
-- Owns the final school facade. The old school is removed and rebuilt exactly once
-- after legacy structure/sign passes have settled. Functional gate objects survive.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local LOBBY_NAME = "Lobby_Prestige0_School"
local GATE_AREA_NAME = "GateArea"
local FIND_TIMEOUT_SECONDS = 25
local LEGACY_SETTLE_TIMEOUT_SECONDS = 4
local WORLD_SCALE = 2.5
local BUILD_NAME = "P0_SchoolBuilding_Rebuilt"
local BUILD_VERSION = "ScratchRebuildV4_AtomicSinglePass"
local ATTACHED_ATTRIBUTE = "SchoolRebuildAttachedV4"
local IN_PROGRESS_ATTRIBUTE = "SchoolRebuildInProgressV4"
local COMPLETE_ATTRIBUTE = "SchoolStableBuildCompleteV4"

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
	door.Size = w(Vector3.new(13.2, 15.2, 0.3))
	door.Position = w(Vector3.new(0, 9.8, 67.4))
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
	if door:GetAttribute("StableSchoolDoorGuardV4") then
		configureDoor(door)
		return
	end

	door:SetAttribute("StableSchoolDoorGuardV4", true)
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

local function readSignText(signPart, name, fallback)
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

	local titleText = readSignText(signPart, "NextAreaGateTitle", "ELEMENTARY SCHOOL")
	local subtitleText = readSignText(signPart, "NextAreaGateSubtitle", "IQ 80.500 REQUIRED")

	for _, child in ipairs(signPart:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end

	signPart.Size = w(Vector3.new(22, 5.2, 0.4))
	signPart.Position = w(Vector3.new(0, 25.6, 65.2))
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

	makeSignLabel(panel, "NextAreaGateTitle", titleText, UDim2.fromScale(0.03, 0.13), UDim2.fromScale(0.94, 0.49), Enum.Font.GothamBlack, 78, COLORS.White)
	makeSignLabel(panel, "NextAreaGateSubtitle", subtitleText, UDim2.fromScale(0.04, 0.63), UDim2.fromScale(0.92, 0.27), Enum.Font.GothamBold, 42, COLORS.BlueLight)
	return true
end

local function buildSchool(gateArea)
	local build = Instance.new("Model")
	build.Name = BUILD_NAME
	build.Parent = gateArea

	-- Foundation and approach use different heights, so no horizontal surfaces overlap.
	makePart(build, "Foundation", Vector3.new(66, 1.2, 24), Vector3.new(0, 0.6, 79), COLORS.Stone, Enum.Material.Concrete)
	makePart(build, "FrontStepLower", Vector3.new(22, 0.7, 6.5), Vector3.new(0, 0.35, 62.8), COLORS.Stone, Enum.Material.Concrete)
	makePart(build, "FrontStepUpper", Vector3.new(18, 0.7, 3.5), Vector3.new(0, 1.2, 64.8), COLORS.Cream, Enum.Material.Concrete)

	-- The three building blocks are separated by 0.5-stud X gaps.
	makePart(build, "LeftWing", Vector3.new(21.5, 19.5, 18), Vector3.new(-19.5, 11.35, 79), COLORS.Brick, Enum.Material.Brick)
	makePart(build, "RightWing", Vector3.new(21.5, 19.5, 18), Vector3.new(19.5, 11.35, 79), COLORS.Brick, Enum.Material.Brick)
	makePart(build, "CenterHall", Vector3.new(16, 25.5, 14), Vector3.new(0, 14.25, 75), COLORS.BrickDark, Enum.Material.Brick)

	-- Roofs have visible vertical gaps above their walls.
	makePart(build, "LeftRoof", Vector3.new(23.5, 2.2, 20), Vector3.new(-19.5, 22.5, 79), COLORS.Blue)
	makePart(build, "RightRoof", Vector3.new(23.5, 2.2, 20), Vector3.new(19.5, 22.5, 79), COLORS.Blue)
	makePart(build, "CenterRoof", Vector3.new(18, 2.4, 16), Vector3.new(0, 30.7, 75), COLORS.BlueDark)

	-- Opaque single-piece windows avoid transparent-layer sorting and z-fighting.
	makePart(build, "LeftWindow", Vector3.new(9.5, 8.5, 0.45), Vector3.new(-19.5, 12, 69.55), COLORS.Window, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	makePart(build, "RightWindow", Vector3.new(9.5, 8.5, 0.45), Vector3.new(19.5, 12, 69.55), COLORS.Window, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})

	-- Door frame is fully in front of the hall; side pieces and top beam have gaps.
	makePart(build, "DoorFrameLeft", Vector3.new(1.5, 15.5, 0.45), Vector3.new(-7.5, 10.05, 66.8), COLORS.Cream)
	makePart(build, "DoorFrameRight", Vector3.new(1.5, 15.5, 0.45), Vector3.new(7.5, 10.05, 66.8), COLORS.Cream)
	makePart(build, "DoorFrameTop", Vector3.new(15.2, 1.4, 0.45), Vector3.new(0, 18.65, 66.8), COLORS.Cream)

	-- Simple crest parts are vertically separated.
	makePart(build, "CrestBase", Vector3.new(7, 1.1, 3), Vector3.new(0, 32.6, 75), COLORS.Gold)
	makePart(build, "CrestStem", Vector3.new(1.1, 3.4, 1.1), Vector3.new(0, 35.0, 75), COLORS.Gold)
	makePart(build, "CrestTop", Vector3.new(4, 0.9, 1), Vector3.new(0, 37.4, 75), COLORS.Gold)

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
		-- Lobby is nested under SimpleMap.World, not directly under SimpleMap.
		lobby = findDescendant(map, LOBBY_NAME)
		gateArea = lobby and lobby:FindFirstChild(GATE_AREA_NAME)
		gateModel = map:FindFirstChild("NextAreaGate")
		door = gateModel and gateModel:FindFirstChild("NextAreaGate_Door")
		signPart = gateModel and gateModel:FindFirstChild("P0_GateFixedSign")
		if gateArea and gateModel and door and signPart then
			break
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return gateArea, gateModel, door, signPart
end

local function waitForLegacyPasses(map)
	local deadline = os.clock() + LEGACY_SETTLE_TIMEOUT_SECONDS
	while os.clock() < deadline do
		local structureDone = map:FindFirstChild("SimulatorStructureUpgrade") ~= nil
		local signDone = map:GetAttribute("SignStyle") ~= nil
		if structureDone and signDone then
			task.wait(0.35)
			return true
		end
		task.wait(0.05)
	end
	return false
end

local function rebuildOnce(map)
	if not map or not map.Parent then
		return
	end
	if map:GetAttribute(COMPLETE_ATTRIBUTE) or map:GetAttribute(IN_PROGRESS_ATTRIBUTE) then
		return
	end

	-- Acquire before the first yield. Workspace.ChildAdded and WaitForChild can both
	-- call attach for the same map during creation; only the first coroutine may continue.
	map:SetAttribute(IN_PROGRESS_ATTRIBUTE, true)

	local success, failure = xpcall(function()
		local gateArea, gateModel, door, signPart = waitForDependencies(map)
		if not gateArea or not gateModel or not door or not signPart then
			error("Required nested gate objects missing")
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

		map:SetAttribute(COMPLETE_ATTRIBUTE, true)
		map:SetAttribute("SchoolBuildVersion", BUILD_VERSION)
		map:SetAttribute("SchoolOldPartsRemoved", removedOldParts + legacyRemoved + archRemoved)
		print(
			"[SchoolRebuild] atomicSinglePass=true rebuilt="
				.. tostring(build ~= nil)
				.. " removedOldParts="
				.. tostring(removedOldParts + legacyRemoved + archRemoved)
				.. " preservedPrompt="
				.. tostring(door:FindFirstChildOfClass("ProximityPrompt") ~= nil)
				.. " signReady="
				.. tostring(signReady)
		)
	end, debug.traceback)

	map:SetAttribute(IN_PROGRESS_ATTRIBUTE, false)
	if not success then
		warn("[SchoolRebuild] Failed: " .. tostring(failure))
	end
end

local function attach(map)
	if not map or not map.Parent or map:GetAttribute(ATTACHED_ATTRIBUTE) then
		return
	end

	-- Acquire immediately so ChildAdded and WaitForChild cannot install two listeners
	-- or spawn two rebuild coroutines for the same map.
	map:SetAttribute(ATTACHED_ATTRIBUTE, true)
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
