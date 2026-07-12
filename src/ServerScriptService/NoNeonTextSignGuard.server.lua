-- ServerScriptService/NoNeonTextSignGuard.server.lua
-- Permanent visual policy: world text and sign-like objects may never use Neon or glow lights.

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
	"billboard",
}

local changedMaterials = 0
local changedText = 0
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

local function hasWorldText(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("SurfaceGui")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("TextLabel")
			or descendant:IsA("TextButton")
			or descendant:IsA("TextBox") then
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

local function flattenWorldText(textObject)
	if textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox") then
		textObject.TextStrokeTransparency = 1
		if textObject:IsA("TextButton") or nameLooksLikeSign(textObject) then
			textObject.Font = Enum.Font.GothamBold
		else
			textObject.Font = Enum.Font.GothamMedium
		end
		changedText += 1
	end
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

local function enforce(instance)
	if instance:IsA("SurfaceGui") then
		instance.LightInfluence = 1
		local part = nearestBasePart(instance)
		if part and part.Material == Enum.Material.Neon then
			part.Material = Enum.Material.SmoothPlastic
			changedMaterials += 1
		end
	elseif instance:IsA("BillboardGui") then
		local part = nearestBasePart(instance)
		if part and part.Material == Enum.Material.Neon then
			part.Material = Enum.Material.SmoothPlastic
			changedMaterials += 1
		end
	elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		flattenWorldText(instance)
		local part = nearestBasePart(instance)
		if part and part.Material == Enum.Material.Neon then
			part.Material = Enum.Material.SmoothPlastic
			changedMaterials += 1
		end
	elseif instance:IsA("BasePart") then
		local signLike = nameLooksLikeSign(instance) or hasWorldText(instance)
		if signLike then
			if instance.Material == Enum.Material.Neon then
				instance.Material = Enum.Material.SmoothPlastic
				changedMaterials += 1
			end
			removeSignLighting(instance)
		end
	end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	enforce(descendant)
end

Workspace.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		if descendant.Parent then
			enforce(descendant)
			local part = nearestBasePart(descendant)
			if part then
				enforce(part)
			end
		end
	end)
end)

print(
	"[NoNeonTextSignGuard] Ready policy=worldTextAndSigns"
		.. " changedMaterials=" .. tostring(changedMaterials)
		.. " changedText=" .. tostring(changedText)
		.. " disabledLights=" .. tostring(disabledLights)
)
