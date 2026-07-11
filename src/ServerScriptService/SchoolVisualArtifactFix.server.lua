-- ServerScriptService/SchoolVisualArtifactFix.server.lua
-- Removes the bright white/cyan facade panels visible around the school gate.
-- Functional prompts, portal requests, and gate labels are preserved.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25

local COLORS = {
	Frame = Color3.fromRGB(42, 78, 116),
	Door = Color3.fromRGB(70, 124, 174),
	Window = Color3.fromRGB(38, 76, 105),
	Sign = Color3.fromRGB(30, 48, 70),
	SignAccent = Color3.fromRGB(73, 132, 197),
	Title = Color3.fromRGB(244, 248, 252),
	Subtitle = Color3.fromRGB(156, 205, 235),
}

local HIDDEN_PART_NAMES = {
	P0_School_LeftTrim = true,
	P0_School_RightTrim = true,
	P0_School_TopTrim = true,
	NextAreaGateFrame_BottomGlow = true,
	NextAreaLockIcon = true,
}

local FRAME_PART_NAMES = {
	P0_School_DoorFrame_Left = true,
	P0_School_DoorFrame_Right = true,
	P0_School_DoorFrame_Top = true,
}

local WINDOW_PART_NAMES = {
	P0_School_LeftWindow = true,
	P0_School_RightWindow = true,
}

local applying = setmetatable({}, { __mode = "k" })

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function removeAnimatedEffects(instance)
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

local function hidePart(part)
	if not part or not part.Parent or not part:IsA("BasePart") then
		return false
	end

	part.Transparency = 1
	part.Reflectance = 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	removeAnimatedEffects(part)
	return true
end

local function applyBasePartStyle(part, style)
	if applying[part] or not part or not part.Parent or not part:IsA("BasePart") then
		return false
	end

	applying[part] = true
	part.Material = style.Material or Enum.Material.SmoothPlastic
	part.Color = style.Color
	part.Transparency = style.Transparency or 0
	part.Reflectance = 0
	part.CastShadow = style.CastShadow ~= false
	part.CanCollide = style.CanCollide == true
	part.CanTouch = false
	part.CanQuery = style.CanQuery ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	removeAnimatedEffects(part)
	applying[part] = nil
	return true
end

local function watchBasePart(part, style)
	local attributeName = "SchoolFacadeStyle_" .. part.Name
	if part:GetAttribute(attributeName) then
		applyBasePartStyle(part, style)
		return
	end

	part:SetAttribute(attributeName, true)
	for _, propertyName in ipairs({
		"Material",
		"Color",
		"Transparency",
		"Reflectance",
		"CanCollide",
		"CanTouch",
		"CanQuery",
	}) do
		part:GetPropertyChangedSignal(propertyName):Connect(function()
			task.defer(function()
				applyBasePartStyle(part, style)
			end)
		end)
	end
	applyBasePartStyle(part, style)
end

local function styleGateSign(map)
	local signPart = findDescendant(map, "P0_GateFixedSign")
	if not signPart or not signPart:IsA("BasePart") then
		return false
	end

	watchBasePart(signPart, {
		Color = COLORS.Sign,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})

	local card = signPart:FindFirstChild("SignCard", true)
	if card and card:IsA("Frame") then
		card.BackgroundColor3 = COLORS.Sign
		card.BackgroundTransparency = 0
		card.BorderSizePixel = 0
	end

	local accentBar = signPart:FindFirstChild("AccentBar", true)
	if accentBar and accentBar:IsA("Frame") then
		accentBar.BackgroundColor3 = COLORS.SignAccent
		accentBar.BackgroundTransparency = 0
	end

	local title = signPart:FindFirstChild("NextAreaGateTitle", true)
	if title and title:IsA("TextLabel") then
		title.TextColor3 = COLORS.Title
		title.TextStrokeTransparency = 1
	end

	local subtitle = signPart:FindFirstChild("NextAreaGateSubtitle", true)
	if subtitle and subtitle:IsA("TextLabel") then
		subtitle.TextColor3 = COLORS.Subtitle
		subtitle.TextStrokeTransparency = 1
	end

	return true
end

local function applyFix(map)
	if not map or not map.Parent then
		return
	end

	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	while os.clock() < deadline and not findDescendant(map, "NextAreaGate_Door") do
		task.wait(0.1)
	end

	local hiddenCount = 0
	local styledCount = 0

	for name in pairs(HIDDEN_PART_NAMES) do
		if hidePart(findDescendant(map, name)) then
			hiddenCount += 1
		end
	end

	for name in pairs(FRAME_PART_NAMES) do
		local part = findDescendant(map, name)
		if part and part:IsA("BasePart") then
			watchBasePart(part, {
				Color = COLORS.Frame,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0,
				CanCollide = true,
				CanQuery = true,
			})
			styledCount += 1
		end
	end

	for name in pairs(WINDOW_PART_NAMES) do
		local part = findDescendant(map, name)
		if part and part:IsA("BasePart") then
			watchBasePart(part, {
				Color = COLORS.Window,
				Material = Enum.Material.Glass,
				Transparency = 0.18,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			styledCount += 1
		end
	end

	local door = findDescendant(map, "NextAreaGate_Door")
	if door and door:IsA("BasePart") then
		watchBasePart(door, {
			Color = COLORS.Door,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.2,
			CanCollide = false,
			CanQuery = true,
			CastShadow = false,
		})
		styledCount += 1
	else
		warn("[SchoolVisualArtifactFix] NextAreaGate_Door missing; door cleanup skipped.")
	end

	if styleGateSign(map) then
		styledCount += 1
	end

	map.DescendantAdded:Connect(function(descendant)
		if not descendant:IsA("BasePart") then
			return
		end

		if HIDDEN_PART_NAMES[descendant.Name] then
			task.defer(function()
				hidePart(descendant)
			end)
		elseif FRAME_PART_NAMES[descendant.Name] then
			task.defer(function()
				watchBasePart(descendant, {
					Color = COLORS.Frame,
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0,
					CanCollide = true,
					CanQuery = true,
				})
			end)
		elseif WINDOW_PART_NAMES[descendant.Name] then
			task.defer(function()
				watchBasePart(descendant, {
					Color = COLORS.Window,
					Material = Enum.Material.Glass,
					Transparency = 0.18,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
				})
			end)
		elseif descendant.Name == "NextAreaGate_Door" then
			task.defer(function()
				watchBasePart(descendant, {
					Color = COLORS.Door,
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.2,
					CanCollide = false,
					CanQuery = true,
					CastShadow = false,
				})
			end)
		end
	end)

	for _, delaySeconds in ipairs({ 0.35, 1.35, 2.85 }) do
		task.delay(delaySeconds, function()
			if map.Parent then
				for name in pairs(HIDDEN_PART_NAMES) do
					hidePart(findDescendant(map, name))
				end
				styleGateSign(map)
			end
		end)
	end

	map:SetAttribute("SchoolVisualArtifactFix", "DarkFacadeNoBrightPanelsV2")
	print(
		"[SchoolVisualArtifactFix] Bright facade removed hidden="
			.. tostring(hiddenCount)
			.. " styled="
			.. tostring(styledCount)
	)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		task.spawn(applyFix, child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	task.spawn(applyFix, existingMap)
else
	local map = Workspace:WaitForChild(MAP_NAME, FIND_TIMEOUT_SECONDS)
	if map then
		task.spawn(applyFix, map)
	else
		warn("[SchoolVisualArtifactFix] SimpleMap missing; fix disabled.")
	end
end
