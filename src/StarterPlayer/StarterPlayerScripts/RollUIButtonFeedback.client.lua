-- StarterPlayer/StarterPlayerScripts/RollUIButtonFeedback.client.lua
-- Temporary feedback for the existing on-screen ROLL button only.
-- Project rule: do not create floating world UI, BillboardGui, overlays, or extra labels.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FIND_TIMEOUT_SECONDS = 30
local HOVER_SCALE = 1.025
local PRESS_SCALE = 0.94
local RESULT_SCALE = 1.075

local activeTween = nil
local animationToken = 0
local hovered = false
local pressed = false

local function findRollButton()
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS

	repeat
		local candidate = playerGui:FindFirstChild("RollButton", true)
		if candidate and candidate:IsA("GuiButton") then
			return candidate
		end

		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local rollButton = findRollButton()
if not rollButton then
	warn("[RollUIButtonFeedback] RollButton missing; UI feedback disabled.")
	return
end

local oldScale = rollButton:FindFirstChild("RollUIButtonFeedbackScale")
if oldScale then
	oldScale:Destroy()
end

local scale = Instance.new("UIScale")
scale.Name = "RollUIButtonFeedbackScale"
scale.Scale = 1
scale.Parent = rollButton

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function tweenScale(targetScale, duration, easingStyle, easingDirection)
	cancelTween()

	activeTween = TweenService:Create(
		scale,
		TweenInfo.new(
			duration,
			easingStyle or Enum.EasingStyle.Quad,
			easingDirection or Enum.EasingDirection.Out
		),
		{ Scale = targetScale }
	)
	activeTween:Play()
	return activeTween
end

local function idleTarget()
	if pressed then
		return PRESS_SCALE
	end

	if hovered then
		return HOVER_SCALE
	end

	return 1
end

rollButton.MouseEnter:Connect(function()
	hovered = true
	if not pressed then
		tweenScale(HOVER_SCALE, 0.12)
	end
end)

rollButton.MouseLeave:Connect(function()
	hovered = false
	pressed = false
	tweenScale(1, 0.14)
end)

rollButton.MouseButton1Down:Connect(function()
	pressed = true
	tweenScale(PRESS_SCALE, 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end)

rollButton.MouseButton1Up:Connect(function()
	pressed = false
	tweenScale(hovered and HOVER_SCALE or 1, 0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end)

local remotes = ReplicatedStorage:WaitForChild("Remotes", FIND_TIMEOUT_SECONDS)
local popupEvent = remotes and remotes:WaitForChild("PopupEvent", FIND_TIMEOUT_SECONDS)

if popupEvent and popupEvent:IsA("RemoteEvent") then
	popupEvent.OnClientEvent:Connect(function(_, popupType)
		if tostring(popupType or "") ~= "Roll" then
			return
		end

		animationToken += 1
		local token = animationToken
		pressed = false

		tweenScale(RESULT_SCALE, 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		task.delay(0.12, function()
			if token ~= animationToken or not scale.Parent then
				return
			end

			tweenScale(idleTarget(), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end)
	end)
else
	warn("[RollUIButtonFeedback] PopupEvent missing; press feedback remains enabled.")
end

print("[RollUIButtonFeedback] Connected button=" .. rollButton:GetFullName())
