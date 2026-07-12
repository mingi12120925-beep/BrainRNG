-- ServerScriptService/NoNeonTextSignGuard.server.lua
-- Permanent visual policy: sign-like world parts may not use Neon or glow lights.
-- Text fonts, outlines, colors, ScreenGui, and character overhead UI are intentionally untouched.

local Workspace = game:GetService("Workspace")

local SIGN_WORDS = {
	"sign",
	"board",
	"label",
	"title",
	"text",
	"panel",
	"poster",
	"notice",
	"display",
}

local changedMaterials = 0
local disabledLights = 0

local function nameLooksLikeSign(instance)
	local lowerName = string.lower(instance.Name)
	for _, word in ipairs(SIGN_WORDS) do
		if string.find(lowerName, word, 1, true) then
			return true
		end
	end
	return false
end

local function hasSurfaceText(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("SurfaceGui") then
			return true
		end
	end
	return false
end

local function nearestBasePart(instance)
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("BasePart") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function removeSignLighting(part)
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("PointLight") or descendant:IsA("SurfaceLight") or descendant:IsA("SpotLight") then
			if descendant.Enabled then
				descendant.Enabled = false
				disabledLights += 1
			end
		end
	end
end

local function enforcePart(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	local signLike = nameLooksLikeSign(part) or hasSurfaceText(part)
	if not signLike then
		return
	end
	if part.Material == Enum.Material.Neon then
		part.Material = Enum.Material.SmoothPlastic
		changedMaterials += 1
	end
	removeSignLighting(part)
end

local function enforce(instance)
	if instance:IsA("BasePart") then
		enforcePart(instance)
	elseif instance:IsA("SurfaceGui") then
		local part = nearestBasePart(instance)
		enforcePart(part)
	end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	enforce(descendant)
end

Workspace.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		if not descendant.Parent then
			return
		end
		enforce(descendant)
		local part = nearestBasePart(descendant)
		enforcePart(part)
	end)
end)

print(
	"[NoNeonTextSignGuard] Ready policy=materialsAndLightsOnly"
		.. " changedMaterials=" .. tostring(changedMaterials)
		.. " disabledLights=" .. tostring(disabledLights)
		.. " overheadUIException=true"
)
