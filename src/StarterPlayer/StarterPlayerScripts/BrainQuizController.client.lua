-- StarterPlayerScripts/BrainQuizController.client.lua
-- Large flat quiz panel with a server-authoritative AUTO ON/OFF button.
-- No neon, glow, or text-stroke styling is used.

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
panel.Size = UDim2.new(0.62, 0, 0, 154)
panel.BackgroundColor3 = Color3.fromRGB(42, 48, 58)
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 80
panel.Parent = brainGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 154)
sizeConstraint.MaxSize = Vector2.new(700, 154)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local border = Instance.new("UIStroke")
border.Thickness = 2
border.Color = Color3.fromRGB(20, 24, 30)
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
header.Position = UDim2.fromOffset(14, 7)
header.Size = UDim2.new(1, -126, 0, 28)
header.Font = Enum.Font.GothamBold
header.Text = "BRAIN QUIZ"
header.TextColor3 = Color3.fromRGB(235, 238, 242)
header.TextScaled = true
header.TextStrokeTransparency = 1
header.TextXAlignment = Enum.TextXAlignment.Left
header.ZIndex = 81
header.Parent = panel
constrainText(header, 15, 22)

local autoButton = Instance.new("TextButton")
autoButton.Name = "AutoToggleButton"
autoButton.AnchorPoint = Vector2.new(1, 0)
autoButton.Position = UDim2.new(1, -10, 0, 7)
autoButton.Size = UDim2.fromOffset(102, 30)
autoButton.AutoButtonColor = true
autoButton.BackgroundColor3 = Color3.fromRGB(64, 145, 92)
autoButton.BorderSizePixel = 0
autoButton.Font = Enum.Font.GothamBold
autoButton.Text = "AUTO: ON"
autoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoButton.TextSize = 16
autoButton.TextStrokeTransparency = 1
autoButton.ZIndex = 82
autoButton.Parent = panel

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 7)
autoCorner.Parent = autoButton

local autoBorder = Instance.new("UIStroke")
autoBorder.Thickness = 1
autoBorder.Color = Color3.fromRGB(24, 30, 36)
autoBorder.Transparency = 0
autoBorder.Parent = autoButton

local question = Instance.new("TextLabel")
question.Name = "Question"
question.BackgroundTransparency = 1
question.Position = UDim2.fromOffset(14, 39)
question.Size = UDim2.new(1, -28, 0, 48)
question.Font = Enum.Font.GothamBold
question.Text = ""
question.TextColor3 = Color3.fromRGB(255, 255, 255)
question.TextScaled = true
question.TextStrokeTransparency = 1
question.TextWrapped = true
question.ZIndex = 81
question.Parent = panel
constrainText(question, 17, 29)

local choices = Instance.new("TextLabel")
choices.Name = "Choices"
choices.BackgroundTransparency = 1
choices.Position = UDim2.fromOffset(14, 89)
choices.Size = UDim2.new(1, -28, 0, 31)
choices.Font = Enum.Font.GothamBold
choices.Text = ""
choices.TextColor3 = Color3.fromRGB(244, 218, 138)
choices.TextScaled = true
choices.TextStrokeTransparency = 1
choices.TextWrapped = false
choices.ZIndex = 81
choices.Parent = panel
constrainText(choices, 17, 26)

local feedback = Instance.new("TextLabel")
feedback.Name = "Feedback"
feedback.BackgroundTransparency = 1
feedback.Position = UDim2.fromOffset(14, 122)
feedback.Size = UDim2.new(1, -28, 0, 24)
feedback.Font = Enum.Font.GothamMedium
feedback.Text = ""
feedback.TextColor3 = Color3.fromRGB(210, 216, 224)
feedback.TextScaled = true
feedback.TextStrokeTransparency = 1
feedback.TextWrapped = false
feedback.ZIndex = 81
feedback.Parent = panel
constrainText(feedback, 12, 17)

local activePayload = nil
local hideToken = 0
local autoEnabled = true
local togglePending = false

local function updateAutoButton()
	autoButton.Text = autoEnabled and "AUTO: ON" or "AUTO: OFF"
	autoButton.BackgroundColor3 = autoEnabled
		and Color3.fromRGB(64, 145, 92)
		or Color3.fromRGB(155, 70, 74)
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

local function showResult(titleText, questionText, feedbackText, duration)
	hideToken += 1
	activePayload = nil
	panel.Visible = true
	header.Text = titleText
	question.Text = questionText
	choices.Text = ""
	feedback.Text = feedbackText or ""
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
		togglePending = false
		updateAutoButton()
	end
	panel.Visible = true
	question.Text = tostring(payload.Prompt or "QUESTION")
	local options = type(payload.Options) == "table" and payload.Options or {}
	choices.Text = "A  " .. tostring(options[1] or "?")
		.. "      B  " .. tostring(options[2] or "?")
		.. "      C  " .. tostring(options[3] or "?")

	local winsEarned = tonumber(payload.WinsEarned) or 0
	if not autoEnabled then
		feedback.Text = activePayload.BaseFeedback .. " · AUTO OFF · +" .. tostring(winsEarned) .. " WINS"
	elseif payload.AutoMoving == true then
		feedback.Text = "AUTO FOUND ANSWER · MOVING CHARACTER · +" .. tostring(winsEarned) .. " WINS"
	else
		feedback.Text = activePayload.BaseFeedback
			.. " · AUTO " .. tostring(getChancePercent(payload)) .. "%"
			.. " · +" .. tostring(winsEarned) .. " WINS"
	end
end

autoButton.Activated:Connect(function()
	if togglePending then
		return
	end
	togglePending = true
	autoEnabled = not autoEnabled
	updateAutoButton()
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
		updateAutoButton()
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
			tostring(payload.TimeLimit or 60) .. " SECONDS · AUTO " .. (autoEnabled and "ON" or "OFF"),
			2.5
		)
	elseif phase == "Complete" then
		local winsEarned = tonumber(payload.WinsEarned) or 0
		showResult(
			"QUIZ COMPLETE · " .. tostring(payload.Difficulty or "NORMAL"),
			"+" .. tostring(winsEarned) .. " WINS",
			"AUTO and manual answers were both rewarded",
			4
		)
	elseif phase == "Expired" then
		local winsEarned = tonumber(payload.WinsEarned) or 0
		showResult(
			"TIME UP · " .. tostring(payload.Difficulty or "NORMAL"),
			"SCORE " .. tostring(payload.Score or 0) .. "/" .. tostring(payload.Goal or 5),
			"+" .. tostring(winsEarned) .. " WINS KEPT",
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
	header.Text = "BRAIN QUIZ · " .. difficulty
		.. "   " .. tostring(score) .. "/" .. tostring(goal)
		.. "   " .. tostring(math.ceil(remaining)) .. "s"

	local winsEarned = tonumber(activePayload.WinsEarned) or 0
	if not autoEnabled then
		feedback.Text = "AUTO OFF · MOVE MANUALLY · +" .. tostring(winsEarned) .. " WINS"
	elseif activePayload.AutoMoving == true then
		feedback.Text = "AUTO FOUND ANSWER · MOVING CHARACTER · +" .. tostring(winsEarned) .. " WINS"
	else
		local autoSolveAt = tonumber(activePayload.AutoSolveAt)
		if autoSolveAt and remaining > 0 then
			local autoRemaining = math.max(0, autoSolveAt - now)
			feedback.Text = tostring(activePayload.BaseFeedback or "AUTO IS RUNNING")
				.. " · TRY IN " .. tostring(math.ceil(autoRemaining)) .. "s"
				.. " · " .. tostring(getChancePercent(activePayload)) .. "%"
				.. " · +" .. tostring(winsEarned) .. " WINS"
		end
	end
	if remaining <= 0 then
		feedback.Text = "TIME UP · +" .. tostring(winsEarned) .. " WINS KEPT"
	end
end)

updateAutoButton()
print("[BrainQuizUI] Ready largeText=true autoButton=true autoDefault=true flatStyle=true noNeon=true parent=" .. brainGui:GetFullName())
