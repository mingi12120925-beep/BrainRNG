-- ServerScriptService/SchoolVisualArtifactFix.server.lua
-- Removes the animated white ForceField shimmer from the school portal and
-- hides facade trims that can flicker against the school wall.
-- The gate prompt and all functional portal objects are preserved.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25
local PORTAL_COLOR = Color3.fromRGB(143, 210, 255)

local WHITE_TRIM_NAMES = {
	"P0_School_LeftTrim",
	"P0_School_RightTrim",
	"P0_School_TopTrim",
}

local applyingDoorStyle = false

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function hideWhiteTrim(map, name)
	local part = findDescendant(map, name)
	if not part or not part:IsA("BasePart") then
		return false
	end

	part.Transparency = 1
	part.Reflectance = 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return true
end

local function removeAnimatedEffects(door)
	for _, descendant in ipairs(door:GetDescendants()) do
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

local function applyDoorStyle(door)
	if applyingDoorStyle or not door or not door.Parent or not door:IsA("BasePart") then
		return false
	end

	applyingDoorStyle = true
	door.Material = Enum.Material.SmoothPlastic
	door.Color = PORTAL_COLOR
	door.Transparency = 0.5
	door.Reflectance = 0
	door.CastShadow = false
	door.CanCollide = false
	door.CanTouch = false
	door.CanQuery = true
	door.TopSurface = Enum.SurfaceType.Smooth
	door.BottomSurface = Enum.SurfaceType.Smooth
	removeAnimatedEffects(door)
	applyingDoorStyle = false
	return true
end

local function watchDoor(door)
	if door:GetAttribute("SchoolVisualArtifactFixConnected") then
		applyDoorStyle(door)
		return
	end

	door:SetAttribute("SchoolVisualArtifactFixConnected", true)
	for _, propertyName in ipairs({ "Material", "Color", "Transparency", "Reflectance" }) do
		door:GetPropertyChangedSignal(propertyName):Connect(function()
			task.defer(function()
				applyDoorStyle(door)
			end)
		end)
	end
	applyDoorStyle(door)
end

local function applyFix(map)
	if not map or not map.Parent then
		return
	end

	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	local door = findDescendant(map, "NextAreaGate_Door")
	while not door and os.clock() < deadline do
		task.wait(0.1)
		door = findDescendant(map, "NextAreaGate_Door")
	end

	local hiddenTrims = 0
	for _, name in ipairs(WHITE_TRIM_NAMES) do
		if hideWhiteTrim(map, name) then
			hiddenTrims += 1
		end
	end

	if door and door:IsA("BasePart") then
		watchDoor(door)
	else
		warn("[SchoolVisualArtifactFix] NextAreaGate_Door missing; portal shimmer fix skipped.")
	end

	map.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "NextAreaGate_Door" and descendant:IsA("BasePart") then
			task.defer(function()
				watchDoor(descendant)
			end)
		elseif table.find(WHITE_TRIM_NAMES, descendant.Name) and descendant:IsA("BasePart") then
			task.defer(function()
				hideWhiteTrim(map, descendant.Name)
			end)
		end
	end)

	map:SetAttribute("SchoolVisualArtifactFix", "StaticPortalNoWhiteTrimV1")
	print(
		"[SchoolVisualArtifactFix] Portal shimmer removed; hiddenWhiteTrims="
			.. tostring(hiddenTrims)
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
