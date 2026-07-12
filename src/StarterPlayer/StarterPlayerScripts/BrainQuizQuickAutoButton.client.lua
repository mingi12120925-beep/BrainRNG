-- StarterPlayerScripts/BrainQuizQuickAutoButton.client.lua
-- Standalone, always-visible AUTO control for the Brain Quiz.
-- This does not depend on BrainRNG_UI and intentionally leaves overhead IQ/WINS UI untouched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BrainQuizState = remotes:WaitForChild("BrainQuizState")
local BrainQuizAutoToggle = remotes:WaitForChild("BrainQuizAutoToggle")

local oldStandalone = playerGui:FindFirstChild("BrainQuizAutoUI")
if oldStandalone then
	oldStandalone:Destroy()
end

local function removeLegacyButtons()
	local brainGui = playerGui:FindFirstChild("BrainRNG_UI")
	if not brainGui then
		return
	end

	local oldQuickButton = brainGui:FindFirstChild("QuizAutoQuickButton")
	if oldQuickButton then
		oldQuickButton:Destroy()
	end

	local panel = brainGui:FindFirstChild("BrainQuizPanel")
	local internalButton = panel and panel:FindFirstChild("AutoToggleButton")
	if internalButton and internalButton:IsA("GuiObject") then
		internalButton.Visible = false
		internalButton.Active = false
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainQuizAutoUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 10000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Enabled = true
screenGui.Parent = playerGui

pcall(function()
	screenGui.OnTopOfCoreBlur = true
end)

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Position = UDim2.fromOffset(15, 11)
shadow.Size = UDim2.fromOffset(184, 50)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.55
shadow.BorderSizePixel = 0
shadow.ZIndex = 1000
shadow.Parent = screenGui

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 10)
shadowCorner.Parent = shadow

local button = Instance.new("TextButton")
button.Name = "QuizAutoButton"
button.Position = UDim2.fromOffset(10, 6)
button.Size = UDim2.fromOffset(184, 50)
button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.Font = Enum.Font.GothamBold
button.Text = "QUIZ AUTO: ON"
button.TextColor3 = Color3.fromRGB(18, 22, 28)
button.TextSize = 19
button.TextStrokeTransparency = 1
button.TextWrapped = false
button.Visible = true
button.Active = true
button.Selectable = true
button.ZIndex = 1001
button.Parent = screenGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = button

local buttonStroke = Instance.new("UIStroke")
buttonStroke.Name = "StateBorder"
buttonStroke.Thickness = 4
buttonStroke.Color = Color3.fromRGB(39, 137, 76)
buttonStroke.Transparency = 0
buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
buttonStroke.Parent = button

local sizeConstraint = Instance.new("UITextSizeConstraint")
sizeConstraint.MinTextSize = 16
sizeConstraint.MaxTextSize = 20
sizeConstraint.Parent = button

local autoEnabled = true
local togglePending = false

local function updateButton()
	button.Text = autoEnabled and "QUIZ AUTO: ON" or "QUIZ AUTO: OFF"
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.TextColor3 = Color3.fromRGB(18, 22, 28)
	buttonStroke.Color = autoEnabled
		and Color3.fromRGB(39, 137, 76)
		or Color3.fromRGB(190, 56, 64)
end

button.Activated:Connect(function()
	if togglePending then
		return
	end

	togglePending = true
	autoEnabled = not autoEnabled
	updateButton()
	BrainQuizAutoToggle:FireServer(autoEnabled)

	task.delay(1.5, function()
		togglePending = false
	end)
end)

BrainQuizState.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.AutoEnabled) == "boolean" then
		autoEnabled = payload.AutoEnabled
		togglePending = false
		updateButton()
	end
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "BrainRNG_UI" then
		task.defer(removeLegacyButtons)
	end
end)

removeLegacyButtons()
updateButton()

-- Defensive visibility guard: no other UI script may hide or reparent this control.
task.spawn(function()
	while player.Parent do
		if screenGui.Parent ~= playerGui then
			screenGui.Parent = playerGui
		end
		screenGui.Enabled = true
		screenGui.DisplayOrder = 10000
		button.Visible = true
		button.Active = true
		shadow.Visible = true
		removeLegacyButtons()
		task.wait(0.5)
	end
end)

print("[BrainQuizAutoUI] Ready standalone=true alwaysVisible=true displayOrder=10000 size=184x50 overheadUIException=true")
