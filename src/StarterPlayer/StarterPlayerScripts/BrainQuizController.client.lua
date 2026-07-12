-- StarterPlayerScripts/BrainQuizController.client.lua
-- Adds a compact per-player quiz panel inside the existing BrainRNG ScreenGui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BrainQuizState = remotes:WaitForChild("BrainQuizState")

local playerGui = player:WaitForChild("PlayerGui")
local brainGui = playerGui:WaitForChild("BrainRNG_UI", 20)
if not brainGui or not brainGui:IsA("ScreenGui") then
	warn("[BrainQuizUI] BrainRNG_UI missing; quiz panel not created")
	return
end

local oldPanel = brainGui:FindFirstChild("BrainQuizPanel")
if oldPanel then
	oldPanel:Destroy()
end

local panel = Instance.new("Frame")
panel.Name = "BrainQuizPanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 10)
panel.Size = UDim2.new(0.48, 0, 0, 108)
panel.BackgroundColor3 = Color3.fromRGB(26, 37, 58)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 80
panel.Parent = brainGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 108)
sizeConstraint.MaxSize = Vector2.new(520, 108)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(100, 170, 255)
stroke.Transparency = 0.1
stroke.Parent = panel

local header = Instance.new("TextLabel")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(12, 5)
header.Size = UDim2.new(1, -24, 0, 22)
header.Font = Enum.Font.GothamBold
header.Text = "BRAIN QUIZ"
header.TextColor3 = Color3.fromRGB(170, 215, 255)
header.TextScaled = true
header.TextXAlignment = Enum.TextXAlignment.Left
header.ZIndex = 81
header.Parent = panel

local question = Instance.new("TextLabel")
question.Name = "Question"
question.BackgroundTransparency = 1
question.Position = UDim2.fromOffset(12, 29)
question.Size = UDim2.new(1, -24, 0, 32)
question.Font = Enum.Font.GothamBlack
question.Text = ""
question.TextColor3 = Color3.fromRGB(255, 255, 255)
question.TextScaled = true
question.TextWrapped = true
question.ZIndex = 81
question.Parent = panel

local choices = Instance.new("TextLabel")
choices.Name = "Choices"
choices.BackgroundTransparency = 1
choices.Position = UDim2.fromOffset(12, 63)
choices.Size = UDim2.new(1, -24, 0, 24)
choices.Font = Enum.Font.GothamBold
choices.Text = ""
choices.TextColor3 = Color3.fromRGB(255, 230, 125)
choices.TextScaled = true
choices.TextWrapped = false
choices.ZIndex = 81
choices.Parent = panel

local feedback = Instance.new("TextLabel")
feedback.Name = "Feedback"
feedback.BackgroundTransparency = 1
feedback.Position = UDim2.fromOffset(12, 88)
feedback.Size = UDim2.new(1, -24, 0, 15)
feedback.Font = Enum.Font.GothamMedium
feedback.Text = ""
feedback.TextColor3 = Color3.fromRGB(195, 205, 225)
feedback.TextScaled = true
feedback.ZIndex = 81
feedback.Parent = panel

local activePayload = nil
local hideToken = 0

local function scheduleHide(delaySeconds)
	hideToken += 1
	local token = hideToken
	task.delay(delaySeconds, function()
		if hideToken == token then
			panel.Visible = false
			activePayload = nil
		end
	end)
end

local function showResult(titleText, questionText, feedbackText, strokeColor)
	hideToken += 1
	activePayload = nil
	panel.Visible = true
	header.Text = titleText
	question.Text = questionText
	choices.Text = ""
	feedback.Text = feedbackText or ""
	stroke.Color = strokeColor
	scheduleHide(3)
end

local function renderActive(payload)
	hideToken += 1
	activePayload = payload
	panel.Visible = true
	stroke.Color = Color3.fromRGB(100, 170, 255)
	question.Text = tostring(payload.Prompt or "QUESTION")

	local options = type(payload.Options) == "table" and payload.Options or {}
	choices.Text = "A  " .. tostring(options[1] or "?") .. "     B  " .. tostring(options[2] or "?") .. "     C  " .. tostring(options[3] or "?")
	feedback.Text = tostring(payload.Feedback or "STEP ON A, B, OR C")
end

BrainQuizState.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	local phase = tostring(payload.Phase or "")
	if phase == "Active" then
		renderActive(payload)
	elseif phase == "Complete" then
		local reward = tonumber(payload.RewardWins) or 0
		local perfect = payload.Perfect == true
		showResult(
			perfect and "PERFECT QUIZ!" or "QUIZ COMPLETE!",
			"+" .. tostring(reward) .. " WINS",
			"Return after the cooldown to play again",
			Color3.fromRGB(80, 225, 135)
		)
	elseif phase == "Expired" then
		showResult(
			"TIME UP",
			"SCORE " .. tostring(payload.Score or 0) .. "/" .. tostring(payload.Goal or 5),
			"Step on START to retry",
			Color3.fromRGB(255, 105, 105)
		)
	elseif phase == "Cancelled" then
		panel.Visible = false
		activePayload = nil
	end
end)

RunService.RenderStepped:Connect(function()
	if not activePayload or not panel.Visible then
		return
	end

	local endsAt = tonumber(activePayload.EndsAt) or Workspace:GetServerTimeNow()
	local remaining = math.max(0, endsAt - Workspace:GetServerTimeNow())
	local score = tonumber(activePayload.Score) or 0
	local goal = tonumber(activePayload.Goal) or 5
	header.Text = "BRAIN QUIZ   " .. tostring(score) .. "/" .. tostring(goal) .. "   " .. tostring(math.ceil(remaining)) .. "s"

	if remaining <= 0 then
		feedback.Text = "TIME UP"
	end
end)

print("[BrainQuizUI] Ready parent=" .. brainGui:GetFullName())
