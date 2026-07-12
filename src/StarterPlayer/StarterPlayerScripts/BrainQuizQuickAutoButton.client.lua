-- StarterPlayerScripts/BrainQuizQuickAutoButton.client.lua
-- Always-visible, high-contrast quiz AUTO control.
-- Character overhead IQ/WINS UI is intentionally untouched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BrainQuizState = remotes:WaitForChild("BrainQuizState")
local BrainQuizAutoToggle = remotes:WaitForChild("BrainQuizAutoToggle")

local playerGui = player:WaitForChild("PlayerGui")
local brainGui = playerGui:WaitForChild("BrainRNG_UI", 20)
if not brainGui or not brainGui:IsA("ScreenGui") then
	warn("[BrainQuizQuickAuto] BrainRNG_UI missing")
	return
end

local oldButton = brainGui:FindFirstChild("QuizAutoQuickButton")
if oldButton then
	oldButton:Destroy()
end

local button = Instance.new("TextButton")
button.Name = "QuizAutoQuickButton"
button.AnchorPoint = Vector2.new(0, 0)
button.Position = UDim2.fromOffset(12, 62)
button.Size = UDim2.fromOffset(156, 42)
button.BackgroundColor3 = Color3.fromRGB(248, 246, 239)
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.Font = Enum.Font.GothamBold
button.Text = "QUIZ AUTO  ON"
button.TextColor3 = Color3.fromRGB(24, 29, 35)
button.TextSize = 17
button.TextStrokeTransparency = 1
button.Visible = true
button.ZIndex = 120
button.Parent = brainGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local border = Instance.new("UIStroke")
border.Thickness = 3
border.Color = Color3.fromRGB(42, 126, 72)
border.Transparency = 0
border.Parent = button

local autoEnabled = true
local togglePending = false

local function updateButton()
	button.Text = autoEnabled and "QUIZ AUTO  ON" or "QUIZ AUTO  OFF"
	button.BackgroundColor3 = Color3.fromRGB(248, 246, 239)
	button.TextColor3 = Color3.fromRGB(24, 29, 35)
	border.Color = autoEnabled
		and Color3.fromRGB(42, 126, 72)
		or Color3.fromRGB(155, 55, 61)
end

local function hideDuplicatePanelButton()
	local panel = brainGui:FindFirstChild("BrainQuizPanel")
	local duplicate = panel and panel:FindFirstChild("AutoToggleButton")
	if duplicate and duplicate:IsA("GuiObject") then
		duplicate.Visible = false
		duplicate.Active = false
	end
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
	hideDuplicatePanelButton()
end)

brainGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "AutoToggleButton" then
		task.defer(hideDuplicatePanelButton)
	end
end)

task.spawn(function()
	while button.Parent do
		button.Visible = true
		hideDuplicatePanelButton()
		task.wait(0.5)
	end
end)

updateButton()
hideDuplicatePanelButton()
print("[BrainQuizQuickAuto] Ready alwaysVisible=true position=12,62 size=156x42 highContrast=true overheadUIException=true")
