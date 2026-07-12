-- StarterPlayerScripts/BrainQuizQuickAutoButton.client.lua
-- Standalone AUTO control. The UI is created before the server RemoteEvent is available.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function enumFont(name, fallback)
	local ok, value = pcall(function()
		return Enum.Font[name]
	end)
	if ok and value then
		return value
	end
	return fallback
end

local BUTTON_FONT = enumFont("BuilderSansBold", Enum.Font.GothamBold)

local oldGui = playerGui:FindFirstChild("BrainQuizAutoUI")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainQuizAutoUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 10000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Enabled = true
screenGui.Parent = playerGui

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Position = UDim2.fromOffset(17, 74)
shadow.Size = UDim2.fromOffset(210, 54)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.62
shadow.BorderSizePixel = 0
shadow.ZIndex = 1000
shadow.Parent = screenGui
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 10)
shadowCorner.Parent = shadow

local button = Instance.new("TextButton")
button.Name = "QuizAutoButton"
button.Position = UDim2.fromOffset(12, 68)
button.Size = UDim2.fromOffset(210, 54)
button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.Font = BUTTON_FONT
button.Text = "QUIZ AUTO: ON"
button.TextColor3 = Color3.fromRGB(18, 22, 28)
button.TextSize = 21
button.TextStrokeTransparency = 1
button.Visible = true
button.Active = true
button.Selectable = true
button.ZIndex = 1001
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button

local stroke = Instance.new("UIStroke")
stroke.Name = "StateBorder"
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(39, 137, 76)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button

local autoEnabled = true
local toggleRemote = nil
local stateRemote = nil
local stateConnection = nil
local togglePending = false

local function refreshButton()
	button.Text = autoEnabled and "QUIZ AUTO: ON" or "QUIZ AUTO: OFF"
	stroke.Color = autoEnabled and Color3.fromRGB(39, 137, 76) or Color3.fromRGB(190, 56, 64)
end

local function connectStateRemote(remote)
	if stateConnection then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	stateRemote = remote
	stateConnection = stateRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.AutoEnabled) == "boolean" then
			autoEnabled = payload.AutoEnabled
			togglePending = false
			refreshButton()
		end
	end)
end

local function discoverRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return false
	end
	local foundToggle = remotes:FindFirstChild("BrainQuizAutoToggle")
	local foundState = remotes:FindFirstChild("BrainQuizState")
	if foundToggle and foundToggle:IsA("RemoteEvent") then
		toggleRemote = foundToggle
	end
	if foundState and foundState:IsA("RemoteEvent") and foundState ~= stateRemote then
		connectStateRemote(foundState)
	end
	return toggleRemote ~= nil
end

button.Activated:Connect(function()
	if togglePending then
		return
	end
	if not toggleRemote and not discoverRemotes() then
		button.Text = "QUIZ AUTO: LOADING"
		task.delay(1, refreshButton)
		return
	end
	togglePending = true
	autoEnabled = not autoEnabled
	refreshButton()
	toggleRemote:FireServer(autoEnabled)
	task.delay(1.5, function()
		togglePending = false
	end)
end)

task.spawn(function()
	while player.Parent do
		discoverRemotes()
		screenGui.Enabled = true
		screenGui.DisplayOrder = 10000
		button.Visible = true
		button.Active = true
		shadow.Visible = true
		task.wait(0.5)
	end
end)

refreshButton()
print("[BrainQuizAutoUI] Ready standalone=true createdBeforeRemote=true alwaysVisible=true displayOrder=10000")
