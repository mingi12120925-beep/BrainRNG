-- StarterPlayerScripts/BrainQuizController.client.lua
-- Large quiz panel for auto-first Brain Quiz play.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
panel.Position = UDim2.new(0.5, 0, 0, 6)
panel.Size = UDim2.new(0.62, 0, 0, 148)
panel.BackgroundColor3 = Color3.fromRGB(26, 37, 58)
panel.BackgroundTransparency = 0.03
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 80
panel.Parent = brainGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 148)
sizeConstraint.MaxSize = Vector2.new(680, 148)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(100, 170, 255)
stroke.Transparency = 0.05
stroke.Parent = panel

local function constrainText(label, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local header = Instance.new("TextLabel")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(14, 6)
header.Size = UDim2.new(1, -28, 0, 28)
header.Font = Enum.Font.GothamBold
header.Text = "BRAIN QUIZ"
header.TextColor3 = Color3.fromRGB(170, 215, 255)
header.TextScaled = true
header.TextXAlignment = Enum.TextXAlignment.Left
header.ZIndex = 81
header.Parent = panel
constrainText(header, 16, 23)

local question = Instance.new("TextLabel")
question.Name = "Question"
question.BackgroundTransparency = 1
question.Position = UDim2.fromOffset(14, 35)
question.Size = UDim2.new(1, -28, 0, 47)
question.Font = Enum.Font.GothamBlack
question.Text = ""
question.TextColor3 = Color3.fromRGB(255, 255, 255)
question.TextScaled = true
question.TextWrapped = true
question.ZIndex = 81
question.Parent = panel
constrainText(question, 17, 30)

local choices = Instance.new("TextLabel")
choices.Name = "Choices"
choices.BackgroundTransparency = 1
choices.Position = UDim2.fromOffset(14, 84)
choices.Size = UDim2.new(1, -28, 0, 32)
choices.Font = Enum.Font.GothamBold
choices.Text = ""
choices.TextColor3 = Color3.fromRGB(255, 230, 125)
choices.TextScaled = true
choices.TextWrapped = false
choices.ZIndex = 81
choices.Parent = panel
constrainText(choices, 17, 27)

local feedback = Instance.new("TextLabel")
feedback.Name = "Feedback"
feedback.BackgroundTransparency = 1
feedback.Position = UDim2.fromOffset(14, 118)
feedback.Size = UDim2.new(1, -28, 0, 23)
feedback.Font = Enum.Font.GothamMedium
feedback.Text = ""
feedback.TextColor3 = Color3.fromRGB(195, 215, 235)
feedback.TextScaled = true
feedback.TextWrapped = false
feedback.ZIndex = 81
feedback.Parent = panel
constrainText(feedback, 13, 18)

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

local function showResult(titleText, questionText, feedbackText, strokeColor, duration)
	hideToken += 1
	activePayload = nil
	panel.Visible = true
	header.Text = titleText
	question.Text = questionText
	choices.Text = ""
	feedback.Text = feedbackText or ""
	stroke.Color = strokeColor
	scheduleHide(duration or 3.5)
end

local function getChancePercent(payload)
	if payload.AutoSolveGuaranteed == true then
		return 100
	end
	local chance = math.clamp(tonumber(payload.AutoSolveChance) or 0, 0, 1)
	return math.floor(chance * 100 + 0.5)
end

local function renderActive(payload)
	hideToken += 1
	activePayload = payload
	activePayload.BaseFeedback = tostring(payload.Feedback or "AUTO IS RUNNING")
	panel.Visible = true
	stroke.Color = Color3.fromRGB(100, 170, 255)
	question.Text = tostring(payload.Prompt or "QUESTION")

	local options = type(payload.Options) == "table" and payload.Options or {}
	choices.Text = "A  " .. tostring(options[1] or "?")
		.. "      B  " .. tostring(options[2] or "?")
		.. "      C  " .. tostring(options[3] or "?")

	local winsEarned = tonumber(payload.WinsEarned) or 0
	local chancePercent = getChancePercent(payload)
	local autoDelay = tonumber(payload.AutoSolveDelay) or 8
	if payload.AutoMoving == true then
		feedback.Text = "AUTO FOUND ANSWER · MOVING CHARACTER · +" .. tostring(winsEarned) .. " WINS"
	else
		feedback.Text = activePayload.BaseFeedback
			.. " · AUTO " .. tostring(chancePercent) .. "%"
			.. " · " .. tostring(autoDelay) .. "s"
			.. " · +" .. tostring(winsEarned) .. " WINS"
	end
end

BrainQuizState.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	local phase = tostring(payload.Phase or "")
	if phase == "Active" then
		renderActive(payload)
	elseif phase == "Difficulty" then
		showResult(
			"DIFFICULTY SELECTED",
			tostring(payload.Difficulty or "NORMAL"),
			tostring(payload.TimeLimit or 60) .. " SECONDS · AUTO IS DEFAULT",
			Color3.fromRGB(255, 205, 70),
			2.5
		)
	elseif phase == "Complete" then
		local winsEarned = tonumber(payload.WinsEarned) or 0
		showResult(
			"QUIZ COMPLETE · " .. tostring(payload.Difficulty or "NORMAL"),
			"+" .. tostring(winsEarned) .. " WINS",
			"Auto and manual answers were both rewarded",
			Color3.fromRGB(80, 225, 135),
			4
		)
	elseif phase == "Expired" then
		local winsEarned = tonumber(payload.WinsEarned) or 0
		showResult(
			"TIME UP · " .. tostring(payload.Difficulty or "NORMAL"),
			"SCORE " .. tostring(payload.Score or 0) .. "/" .. tostring(payload.Goal or 5),
			"+" .. tostring(winsEarned) .. " WINS KEPT",
			Color3.fromRGB(255, 105, 105),
			4
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

	local now = Workspace:GetServerTimeNow()
	local endsAt = tonumber(activePayload.EndsAt) or now
	local remaining = math.max(0, endsAt - now)
	local score = tonumber(activePayload.Score) or 0
	local goal = tonumber(activePayload.Goal) or 5
	local difficulty = tostring(activePayload.Difficulty or "NORMAL")
	local chancePercent = getChancePercent(activePayload)
	header.Text = "BRAIN QUIZ · " .. difficulty
		.. "   " .. tostring(score) .. "/" .. tostring(goal)
		.. "   " .. tostring(math.ceil(remaining)) .. "s"
		.. "   AUTO " .. tostring(chancePercent) .. "%"

	local winsEarned = tonumber(activePayload.WinsEarned) or 0
	local autoSolveAt = tonumber(activePayload.AutoSolveAt)
	if activePayload.AutoMoving == true then
		feedback.Text = "AUTO FOUND ANSWER · MOVING CHARACTER · +" .. tostring(winsEarned) .. " WINS"
	elseif autoSolveAt and remaining > 0 then
		local autoRemaining = math.max(0, autoSolveAt - now)
		feedback.Text = tostring(activePayload.BaseFeedback or "AUTO IS RUNNING")
			.. " · TRY IN " .. tostring(math.ceil(autoRemaining)) .. "s"
			.. " · +" .. tostring(winsEarned) .. " WINS"
	end

	if remaining <= 0 then
		feedback.Text = "TIME UP · +" .. tostring(winsEarned) .. " WINS KEPT"
	end
end)

print(
	"[BrainQuizUI] Ready largeText=true difficulty=true rewardPerCorrect=1"
		.. " autoDefault=true chanceDisplay=true characterMove=true parent=" .. brainGui:GetFullName()
)
