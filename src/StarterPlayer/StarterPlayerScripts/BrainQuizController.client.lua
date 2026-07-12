-- StarterPlayerScripts/BrainQuizController.client.lua
-- High-contrast quiz panel. AUTO is controlled by the separate always-visible button.

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
panel.Position = UDim2.new(0.5, 0, 0, 58)
panel.Size = UDim2.new(0.64, 0, 0, 174)
panel.BackgroundColor3 = Color3.fromRGB(250, 248, 241)
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 100
panel.Parent = brainGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 174)
sizeConstraint.MaxSize = Vector2.new(700, 174)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local border = Instance.new("UIStroke")
border.Thickness = 3
border.Color = Color3.fromRGB(31, 38, 46)
border.Transparency = 0
border.Parent = panel

local function constrainText(label, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local header = Instance.new("TextLabel")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(16, 8)
header.Size = UDim2.new(1, -32, 0, 28)
header.Font = Enum.Font.GothamBold
header.Text = "BRAIN QUIZ"
header.TextColor3 = Color3.fromRGB(25, 33, 43)
header.TextScaled = true
header.TextStrokeTransparency = 1
header.TextXAlignment = Enum.TextXAlignment.Left
header.ZIndex = 101
header.Parent = panel
constrainText(header, 16, 22)

local question = Instance.new("TextLabel")
question.Name = "Question"
question.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
question.BackgroundTransparency = 0
question.Position = UDim2.fromOffset(14, 40)
question.Size = UDim2.new(1, -28, 0, 50)
question.Font = Enum.Font.GothamBold
question.Text = ""
question.TextColor3 = Color3.fromRGB(10, 14, 18)
question.TextScaled = true
question.TextStrokeTransparency = 1
question.TextWrapped = true
question.ZIndex = 101
question.Parent = panel
constrainText(question, 19, 29)

local questionCorner = Instance.new("UICorner")
questionCorner.CornerRadius = UDim.new(0, 7)
questionCorner.Parent = question

local questionBorder = Instance.new("UIStroke")
questionBorder.Thickness = 1
questionBorder.Color = Color3.fromRGB(166, 171, 177)
questionBorder.Parent = question

local choicesFrame = Instance.new("Frame")
choicesFrame.Name = "Choices"
choicesFrame.BackgroundTransparency = 1
choicesFrame.Position = UDim2.fromOffset(14, 96)
choicesFrame.Size = UDim2.new(1, -28, 0, 42)
choicesFrame.ZIndex = 101
choicesFrame.Parent = panel

local choicesLayout = Instance.new("UIListLayout")
choicesLayout.FillDirection = Enum.FillDirection.Horizontal
choicesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
choicesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
choicesLayout.Padding = UDim.new(0, 8)
choicesLayout.Parent = choicesFrame

local choiceLabels = {}
local choiceLetters = { "A", "B", "C" }
local choiceBackgrounds = {
	Color3.fromRGB(246, 226, 228),
	Color3.fromRGB(224, 236, 247),
	Color3.fromRGB(247, 238, 213),
}

for index, letter in ipairs(choiceLetters) do
	local label = Instance.new("TextLabel")
	label.Name = "Choice" .. letter
	label.Size = UDim2.new(1 / 3, -6, 1, 0)
	label.BackgroundColor3 = choiceBackgrounds[index]
	label.BackgroundTransparency = 0
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = letter .. "  ?"
	label.TextColor3 = Color3.fromRGB(20, 25, 31)
	label.TextScaled = true
	label.TextStrokeTransparency = 1
	label.TextWrapped = false
	label.ZIndex = 102
	label.Parent = choicesFrame
	constrainText(label, 17, 24)

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 7)
	labelCorner.Parent = label

	local labelBorder = Instance.new("UIStroke")
	labelBorder.Thickness = 2
	labelBorder.Color = Color3.fromRGB(78, 84, 91)
	labelBorder.Parent = label

	choiceLabels[index] = label
end

local feedback = Instance.new("TextLabel")
feedback.Name = "Feedback"
feedback.BackgroundTransparency = 1
feedback.Position = UDim2.fromOffset(14, 143)
feedback.Size = UDim2.new(1, -28, 0, 24)
feedback.Font = Enum.Font.GothamBold
feedback.Text = ""
feedback.TextColor3 = Color3.fromRGB(39, 47, 57)
feedback.TextScaled = true
feedback.TextStrokeTransparency = 1
feedback.TextWrapped = false
feedback.ZIndex = 101
feedback.Parent = panel
constrainText(feedback, 13, 17)

local activePayload = nil
local hideToken = 0
local autoEnabled = true

local function updateResponsivePosition()
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 1000
	if width <= 600 then
		panel.Position = UDim2.new(0.5, 0, 0, 112)
		panel.Size = UDim2.new(0.9, 0, 0, 174)
	else
		panel.Position = UDim2.new(0.5, 0, 0, 58)
		panel.Size = UDim2.new(0.64, 0, 0, 174)
	end
end

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

local function setChoices(options)
	for index, label in ipairs(choiceLabels) do
		label.Text = choiceLetters[index] .. "  " .. tostring(options[index] or "?")
		label.Visible = true
	end
end

local function clearChoices()
	for _, label in ipairs(choiceLabels) do
		label.Visible = false
	end
end

local function showResult(titleText, mainText, detailText, duration)
	hideToken += 1
	activePayload = nil
	panel.Visible = true
	header.Text = titleText
	question.Text = mainText
	clearChoices()
	feedback.Text = detailText or ""
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
	if type(payload.AutoEnabled) == "boolean" then
		autoEnabled = payload.AutoEnabled
	end
	panel.Visible = true
	question.Text = tostring(payload.Prompt or "QUESTION")
	setChoices(type(payload.Options) == "table" and payload.Options or {})

	local winsEarned = tonumber(payload.WinsEarned) or 0
	if not autoEnabled then
		feedback.Text = "AUTO OFF   |   MANUAL ANSWER   |   WINS " .. tostring(winsEarned)
	elseif payload.AutoMoving == true then
		feedback.Text = "AUTO FOUND THE ANSWER   |   MOVING   |   WINS " .. tostring(winsEarned)
	else
		feedback.Text = "AUTO " .. tostring(getChancePercent(payload)) .. "%   |   WINS " .. tostring(winsEarned)
	end
end

BrainQuizState.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.AutoEnabled) == "boolean" then
		autoEnabled = payload.AutoEnabled
	end

	local phase = tostring(payload.Phase or "")
	if phase == "Active" then
		renderActive(payload)
	elseif phase == "AutoToggle" then
		return
	elseif phase == "Difficulty" then
		showResult(
			"DIFFICULTY SELECTED",
			tostring(payload.Difficulty or "NORMAL"),
			tostring(payload.TimeLimit or 60) .. " SECONDS   |   AUTO " .. (autoEnabled and "ON" or "OFF"),
			2.5
		)
	elseif phase == "Complete" then
		showResult(
			"QUIZ COMPLETE",
			"+" .. tostring(tonumber(payload.WinsEarned) or 0) .. " WINS",
			tostring(payload.Difficulty or "NORMAL"),
			4
		)
	elseif phase == "Expired" then
		showResult(
			"TIME UP",
			"SCORE " .. tostring(payload.Score or 0) .. "/" .. tostring(payload.Goal or 5),
			"WINS KEPT: " .. tostring(tonumber(payload.WinsEarned) or 0),
			4
		)
	elseif phase == "Cancelled" then
		panel.Visible = false
		activePayload = nil
	end
end)

RunService.RenderStepped:Connect(function()
	updateResponsivePosition()
	if not activePayload or not panel.Visible then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local endsAt = tonumber(activePayload.EndsAt) or now
	local remaining = math.max(0, endsAt - now)
	local score = tonumber(activePayload.Score) or 0
	local goal = tonumber(activePayload.Goal) or 5
	local difficulty = tostring(activePayload.Difficulty or "NORMAL")
	header.Text = difficulty .. "   |   " .. tostring(score) .. "/" .. tostring(goal) .. "   |   " .. tostring(math.ceil(remaining)) .. "s"

	local winsEarned = tonumber(activePayload.WinsEarned) or 0
	if not autoEnabled then
		feedback.Text = "AUTO OFF   |   MOVE TO A, B, OR C   |   WINS " .. tostring(winsEarned)
	elseif activePayload.AutoMoving == true then
		feedback.Text = "AUTO FOUND THE ANSWER   |   MOVING   |   WINS " .. tostring(winsEarned)
	else
		local autoSolveAt = tonumber(activePayload.AutoSolveAt)
		if autoSolveAt and remaining > 0 then
			local autoRemaining = math.max(0, autoSolveAt - now)
			feedback.Text = "AUTO " .. tostring(getChancePercent(activePayload)) .. "%   |   TRY IN " .. tostring(math.ceil(autoRemaining)) .. "s   |   WINS " .. tostring(winsEarned)
		end
	end

	if remaining <= 0 then
		feedback.Text = "TIME UP   |   WINS KEPT " .. tostring(winsEarned)
	end
end)

updateResponsivePosition()
print("[BrainQuizUI] Ready highContrast=true separateChoices=true responsive=true internalAutoButton=false")
