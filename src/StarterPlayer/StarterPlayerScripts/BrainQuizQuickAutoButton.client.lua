-- StarterPlayerScripts/BrainQuizQuickAutoButton.client.lua
-- Flat, non-neon quick AUTO toggle shown near the Brain Quiz Arena.
-- Character overhead IQ/WINS UI is intentionally untouched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
button.AnchorPoint = Vector2.new(0.5, 0)
button.Position = UDim2.new(0.5, 0, 0, 58)
button.Size = UDim2.fromOffset(168, 38)
button.BackgroundColor3 = Color3.fromRGB(63, 128, 84)
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.Font = Enum.Font.GothamBold
button.Text = "QUIZ AUTO: ON"
button.TextColor3 = Color3.fromRGB(250, 250, 250)
button.TextSize = 16
button.TextStrokeTransparency = 1
button.Visible = false
button.ZIndex = 95
button.Parent = brainGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = button

local border = Instance.new("UIStroke")
border.Thickness = 1
border.Color = Color3.fromRGB(29, 34, 39)
border.Transparency = 0
border.Parent = button

local autoEnabled = true
local quizActive = false
local togglePending = false
local arena = nil
local accumulated = 0

local function updateButton()
	button.Text = autoEnabled and "QUIZ AUTO: ON" or "QUIZ AUTO: OFF"
	button.BackgroundColor3 = autoEnabled
		and Color3.fromRGB(63, 128, 84)
		or Color3.fromRGB(137, 71, 75)
end

local function findArena()
	local map = Workspace:FindFirstChild("SimpleMap")
	local found = map and map:FindFirstChild("BrainQuizArena")
	if found and found:IsA("Model") then
		arena = found
	else
		arena = nil
	end
end

local function getArenaPosition()
	if not arena or not arena.Parent then
		findArena()
	end
	if not arena then
		return nil
	end
	local platform = arena:FindFirstChild("ArenaPlatform")
	if platform and platform:IsA("BasePart") then
		return platform.Position
	end
	local ok, pivot = pcall(function()
		return arena:GetPivot()
	end)
	return ok and pivot.Position or nil
end

local function hideDuplicatePanelButton()
	local panel = brainGui:FindFirstChild("BrainQuizPanel")
	local duplicate = panel and panel:FindFirstChild("AutoToggleButton")
	if duplicate and duplicate:IsA("GuiObject") then
		duplicate.Visible = false
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
	local phase = tostring(payload.Phase or "")
	if phase == "Active" then
		quizActive = true
	elseif phase == "Complete" or phase == "Expired" or phase == "Cancelled" then
		quizActive = false
	end
	hideDuplicatePanelButton()
end)

brainGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "AutoToggleButton" then
		task.defer(hideDuplicatePanelButton)
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	accumulated += deltaTime
	if accumulated < 0.25 then
		return
	end
	accumulated = 0

	hideDuplicatePanelButton()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local arenaPosition = getArenaPosition()
	local nearArena = false
	if root and arenaPosition then
		nearArena = (root.Position - arenaPosition).Magnitude <= 185
	end
	button.Visible = quizActive or nearArena
end)

updateButton()
findArena()
print("[BrainQuizQuickAuto] Ready nearDistance=185 overheadUIException=true flatStyle=true")
