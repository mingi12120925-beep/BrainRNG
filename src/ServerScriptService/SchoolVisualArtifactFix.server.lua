-- ServerScriptService/SchoolVisualArtifactFix.server.lua
-- Separates the school sign, door frame, windows, and facade trims from the
-- brick wall so no two visible surfaces occupy the same depth.
-- Functional prompts and portal requests remain attached to the original door.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25
local WORLD_SCALE = 2.5
local STYLE_VERSION = "SeparatedSchoolFacadeV2"

local COLORS = {
	Frame = Color3.fromRGB(42, 78, 116),
	Door = Color3.fromRGB(70, 124, 174),
	Window = Color3.fromRGB(38, 76, 105),
	Trim = Color3.fromRGB(73, 132, 197),
	Sign = Color3.fromRGB(30, 48, 70),
	SignAccent = Color3.fromRGB(73, 132, 197),
	Title = Color3.fromRGB(244, 248, 252),
	Subtitle = Color3.fromRGB(156, 205, 235),
}

-- Design-space depth reference:
-- Main school wall front face: Z=69
-- Center tower front face: Z=68
-- Tower cap front face: Z=66
-- Every visible facade part below is placed fully in front with a real gap.
local GEOMETRY = {
	P0_GateFixedSign = {
		Size = Vector3.new(28, 6, 0.4),
		Position = Vector3.new(0, 27, 65.6),
		Color = COLORS.Sign,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	},
	P0_School_LeftTrim = {
		Size = Vector3.new(3.2, 21, 0.25),
		Position = Vector3.new(-25, 11, 68.55),
		Color = COLORS.Trim,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	},
	P0_School_RightTrim = {
		Size = Vector3.new(3.2, 21, 0.25),
		Position = Vector3.new(25, 11, 68.55),
		Color = COLORS.Trim,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	},
	P0_School_TopTrim = {
		Size = Vector3.new(56, 2, 0.25),
		Position = Vector3.new(0, 21, 68.55),
		Color = COLORS.Trim,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	},
	P0_School_LeftWindow = {
		Size = Vector3.new(9.5, 8.5, 0.25),
		Position = Vector3.new(-17, 12.5, 68.45),
		Color = COLORS.Window,
		Material = Enum.Material.Glass,
		Transparency = 0.12,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	},
	P0_School_RightWindow = {
		Size = Vector3.new(9.5, 8.5, 0.25),
		Position = Vector3.new(17, 12.5, 68.45),
		Color = COLORS.Window,
		Material = Enum.Material.Glass,
		Transparency = 0.12,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	},
	P0_School_DoorFrame_Left = {
		Size = Vector3.new(2, 16.5, 0.45),
		Position = Vector3.new(-8, 9.25, 67.55),
		Color = COLORS.Frame,
		CanCollide = true,
		CanQuery = true,
	},
	P0_School_DoorFrame_Right = {
		Size = Vector3.new(2, 16.5, 0.45),
		Position = Vector3.new(8, 9.25, 67.55),
		Color = COLORS.Frame,
		CanCollide = true,
		CanQuery = true,
	},
	P0_School_DoorFrame_Top = {
		Size = Vector3.new(18, 1.5, 0.45),
		Position = Vector3.new(0, 18.25, 67.55),
		Color = COLORS.Frame,
		CanCollide = true,
		CanQuery = true,
	},
	NextAreaGate_Door = {
		Size = Vector3.new(14, 16.3, 0.25),
		Position = Vector3.new(0, 9.15, 67.0),
		Color = COLORS.Door,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.16,
		CanCollide = false,
		CanQuery = true,
		CastShadow = false,
	},
}

local HIDDEN_PART_NAMES = {
	NextAreaGateFrame_BottomGlow = true,
	NextAreaLockIcon = true,
}

local applying = setmetatable({}, { __mode = "k" })
local connected = setmetatable({}, { __mode = "k" })

local function worldVector(value)
	return value * WORLD_SCALE
end

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

local function applyGeometry(part, config)
	if applying[part] or not part or not part.Parent or not part:IsA("BasePart") then
		return false
	end

	applying[part] = true
	part.Size = worldVector(config.Size)
	part.Position = worldVector(config.Position)
	part.Material = config.Material or Enum.Material.SmoothPlastic
	part.Color = config.Color
	part.Transparency = config.Transparency or 0
	part.Reflectance = 0
	part.CanCollide = config.CanCollide == true
	part.CanTouch = false
	part.CanQuery = config.CanQuery ~= false
	part.CastShadow = config.CastShadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	removeAnimatedEffects(part)
	applying[part] = nil
	return true
end

local function watchGeometry(part, config)
	if connected[part] then
		applyGeometry(part, config)
		return
	end

	connected[part] = true
	for _, propertyName in ipairs({
		"Position",
		"Size",
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
				applyGeometry(part, config)
			end)
		end)
	end
	applyGeometry(part, config)
end

local function styleGateSign(map)
	local signPart = findDescendant(map, "P0_GateFixedSign")
	if not signPart or not signPart:IsA("BasePart") then
		return false
	end

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

	local separated = 0
	local hidden = 0

	for name, config in pairs(GEOMETRY) do
		local part = findDescendant(map, name)
		if part and part:IsA("BasePart") then
			watchGeometry(part, config)
			separated += 1
		end
	end

	for name in pairs(HIDDEN_PART_NAMES) do
		if hidePart(findDescendant(map, name)) then
			hidden += 1
		end
	end

	styleGateSign(map)
	map:SetAttribute("SchoolVisualArtifactFix", STYLE_VERSION)
	map:SetAttribute("SchoolFacadeSeparatedParts", separated)
	print(
		"[SchoolVisualArtifactFix] Geometry separated="
			.. tostring(separated)
			.. " hidden="
			.. tostring(hidden)
	)
end

local function attachToMap(map)
	local scheduled = false
	local function scheduleFix(delaySeconds)
		if scheduled then
			return
		end
		scheduled = true
		task.delay(delaySeconds or 0.1, function()
			scheduled = false
			applyFix(map)
		end)
	end

	map.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and (GEOMETRY[descendant.Name] or HIDDEN_PART_NAMES[descendant.Name]) then
			scheduleFix(0.05)
		elseif descendant.Name == "SignCard"
			or descendant.Name == "NextAreaGateTitle"
			or descendant.Name == "NextAreaGateSubtitle"
		then
			scheduleFix(0.05)
		end
	end)

	for _, delaySeconds in ipairs({ 0.35, 0.8, 1.5, 2.8 }) do
		task.delay(delaySeconds, function()
			applyFix(map)
		end)
	end
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		attachToMap(child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	attachToMap(existingMap)
else
	local map = Workspace:WaitForChild(MAP_NAME, FIND_TIMEOUT_SECONDS)
	if map then
		attachToMap(map)
	else
		warn("[SchoolVisualArtifactFix] SimpleMap missing; overlap fix disabled.")
	end
end
