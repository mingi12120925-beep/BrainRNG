-- StarterPlayerScripts/NoNeonTextStyle.client.lua
-- Permanent client policy: all UI text uses flat Gotham fonts without glow strokes or text gradients.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local styledText = 0
local disabledGradients = 0

local function looksLikeHeading(instance)
	local lowerName = string.lower(instance.Name)
	return string.find(lowerName, "title", 1, true)
		or string.find(lowerName, "header", 1, true)
		or string.find(lowerName, "label", 1, true)
		or string.find(lowerName, "sign", 1, true)
end

local function enforce(instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		instance.TextStrokeTransparency = 1
		if instance:IsA("TextButton") or looksLikeHeading(instance) then
			instance.Font = Enum.Font.GothamBold
		else
			instance.Font = Enum.Font.GothamMedium
		end
		styledText += 1
	elseif instance:IsA("UIGradient") then
		local parent = instance.Parent
		if parent and (parent:IsA("TextLabel") or parent:IsA("TextButton") or parent:IsA("TextBox")) then
			instance.Enabled = false
			disabledGradients += 1
		end
	end
end

for _, descendant in ipairs(playerGui:GetDescendants()) do
	enforce(descendant)
end

playerGui.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		if descendant.Parent then
			enforce(descendant)
		end
	end)
end)

print(
	"[NoNeonTextStyle] Ready font=Gotham flatText=true"
		.. " styledText=" .. tostring(styledText)
		.. " disabledGradients=" .. tostring(disabledGradients)
)
