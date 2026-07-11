-- StarterPlayerScripts/PortalTransitionController.client.lua
-- Lightweight full-screen transition used by the temporary Area 2 touch portals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local transitionEvent = remotes:WaitForChild("PortalTransitionEvent")

local FADE_OUT_SECONDS = 0.16
local FADE_IN_SECONDS = 0.24
local FAILSAFE_SECONDS = 2

local activeTween = nil
local transitionToken = 0

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PortalTransitionGui"
screenGui.DisplayOrder = 1000
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.Position = UDim2.fromScale(0, 0)
overlay.BackgroundColor3 = Color3.fromRGB(8, 13, 22)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.ZIndex = 100
overlay.Parent = screenGui

local destination = Instance.new("TextLabel")
destination.Name = "Destination"
destination.AnchorPoint = Vector2.new(0.5, 0.5)
destination.Position = UDim2.fromScale(0.5, 0.53)
destination.Size = UDim2.new(0.8, 0, 0, 54)
destination.BackgroundTransparency = 1
destination.Font = Enum.Font.GothamBlack
destination.Text = ""
destination.TextColor3 = Color3.fromRGB(235, 244, 255)
destination.TextScaled = true
destination.TextTransparency = 1
destination.TextStrokeTransparency = 0.72
destination.ZIndex = 101
destination.Parent = overlay

local sizeConstraint = Instance.new("UITextSizeConstraint")
sizeConstraint.MinTextSize = 18
sizeConstraint.MaxTextSize = 34
sizeConstraint.Parent = destination

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function fadeInFromBlack(token)
	if token ~= transitionToken then
		return
	end

	cancelTween()
	activeTween = TweenService:Create(
		overlay,
		TweenInfo.new(FADE_IN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)

	local textTween = TweenService:Create(
		destination,
		TweenInfo.new(FADE_IN_SECONDS * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 1 }
	)

	activeTween:Play()
	textTween:Play()
	activeTween.Completed:Wait()

	if token == transitionToken then
		screenGui.Enabled = false
		destination.Text = ""
	end
end

local function beginTransition(destinationText)
	transitionToken += 1
	local token = transitionToken

	cancelTween()
	screenGui.Enabled = true
	overlay.BackgroundTransparency = 1
	destination.TextTransparency = 1
	destination.Text = tostring(destinationText or "")

	activeTween = TweenService:Create(
		overlay,
		TweenInfo.new(FADE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 0 }
	)

	local textTween = TweenService:Create(
		destination,
		TweenInfo.new(FADE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 0 }
	)

	activeTween:Play()
	textTween:Play()

	task.delay(FAILSAFE_SECONDS, function()
		if token == transitionToken and screenGui.Enabled then
			fadeInFromBlack(token)
		end
	end)
end

transitionEvent.OnClientEvent:Connect(function(action, destinationText)
	if action == "Begin" then
		beginTransition(destinationText)
	elseif action == "Finish" then
		local token = transitionToken
		task.spawn(fadeInFromBlack, token)
	end
end)

print("[PortalTransition] Client ready")
