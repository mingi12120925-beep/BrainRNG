-- ServerScriptService/SchoolGateOverlapFix.server.lua
-- Removes the duplicate add-on portal arch and reuses the school's existing door frame.
-- Functional gate parts and prompts remain untouched.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local FIND_TIMEOUT_SECONDS = 25
local FIX_FOLDER_NAME = "SchoolGateOverlapFix"

local COLORS = {
	Blue = Color3.fromRGB(73, 132, 197),
	LightBlue = Color3.fromRGB(143, 210, 255),
}

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function styleFramePart(map, name, color)
	local item = findDescendant(map, name)
	if not item or not item:IsA("BasePart") then
		return false
	end

	item.Color = color
	item.Material = Enum.Material.SmoothPlastic
	item.Transparency = 0
	item.Reflectance = 0
	item.CanCollide = true
	item.CanTouch = false
	item.CanQuery = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	return true
end

local function removeDuplicateArch(instance)
	if not instance or not instance.Parent then
		return false
	end

	if instance.Name == "SchoolPortalArch" then
		instance:Destroy()
		return true
	end

	return false
end

local function ensureFloorGlow(map)
	local oldFolder = map:FindFirstChild(FIX_FOLDER_NAME)
	if oldFolder then
		oldFolder:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FIX_FOLDER_NAME
	folder.Parent = map

	local glow = Instance.new("Part")
	glow.Name = "ExistingGateFloorGlow"
	glow.Size = Vector3.new(40, 0.7, 12)
	glow.Position = Vector3.new(0, 2.6, 165.5)
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanTouch = false
	glow.CanQuery = false
	glow.CastShadow = false
	glow.Material = Enum.Material.Neon
	glow.Color = COLORS.LightBlue
	glow.Transparency = 0.58
	glow.TopSurface = Enum.SurfaceType.Smooth
	glow.BottomSurface = Enum.SurfaceType.Smooth
	glow.Parent = folder
end

local function applyFix(map)
	if not map or not map.Parent then
		return
	end

	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	while os.clock() < deadline and not findDescendant(map, "P0_School_DoorFrame_Left") do
		task.wait(0.1)
	end

	for _, descendant in ipairs(map:GetDescendants()) do
		removeDuplicateArch(descendant)
	end

	local leftReady = styleFramePart(map, "P0_School_DoorFrame_Left", COLORS.Blue)
	local rightReady = styleFramePart(map, "P0_School_DoorFrame_Right", COLORS.Blue)
	local topReady = styleFramePart(map, "P0_School_DoorFrame_Top", COLORS.LightBlue)

	ensureFloorGlow(map)

	map.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "SchoolPortalArch" then
			task.defer(function()
				if removeDuplicateArch(descendant) then
					styleFramePart(map, "P0_School_DoorFrame_Left", COLORS.Blue)
					styleFramePart(map, "P0_School_DoorFrame_Right", COLORS.Blue)
					styleFramePart(map, "P0_School_DoorFrame_Top", COLORS.LightBlue)
				end
			end)
		end
	end)

	map:SetAttribute("SchoolGateStyle", "ExistingDoorFramePortalV1")
	print(
		"[SchoolGateOverlapFix] Duplicate arch removed; existing frame ready="
			.. tostring(leftReady and rightReady and topReady)
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
		warn("[SchoolGateOverlapFix] SimpleMap missing; fix disabled.")
	end
end
