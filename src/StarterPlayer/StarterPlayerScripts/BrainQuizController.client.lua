-- StarterPlayerScripts/BrainQuizController.client.lua
-- Per-player world display for Brain Quiz Hall.
-- The question appears above the rooms and each answer appears above its own doorway.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BrainQuizState = remotes:WaitForChild("BrainQuizState")

local oldBrainGui = playerGui:FindFirstChild("BrainRNG_UI")
local oldPanel = oldBrainGui and oldBrainGui:FindFirstChild("BrainQuizPanel")
if oldPanel then
	oldPanel:Destroy()
end

local function enumFont(name, fallback)
	local ok, value = pcall(function()
		return Enum.Font[name]
	end)
	if ok and value then
		return value
	end
	return fallback
end

local TITLE_FONT = enumFont("FredokaOne", Enum.Font.GothamBlack)
local BODY_FONT = enumFont("BuilderSansBold", Enum.Font.GothamBold)

local activePayload = nil
local resultUntil = 0
local resultTitle = nil
local resultMeta = nil
local boundHall = nil
local displayObjects = {}
local questionLabel = nil
local metaLabel = nil
local answerLabels = {}
local renderAccumulator = 0
local searchAccumulator = 0

local function destroyDisplays()
	for _, object in ipairs(displayObjects) do
		if object and object.Parent then
			object:Destroy()
		end
	end
	table.clear(displayObjects)
	questionLabel = nil
	metaLabel = nil
	table.clear(answerLabels)
end

local function makeSurface(part, name, canvasSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.LightInfluence = 1
	gui.CanvasSize = canvasSize
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.Parent = playerGui
	table.insert(displayObjects, gui)
	return gui
end

local function makeTextLabel(parent, name, position, size, font, color, minSize, maxSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = 1
	label.ZIndex = 10
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
	return label
end

local function findHall()
	local map = Workspace:FindFirstChild("SimpleMap")
	local hall = map and map:FindFirstChild("BrainQuizHall")
	if hall and hall:IsA("Model") then
		return hall
	end
	return nil
end

local function setIdleText()
	if questionLabel then
		questionLabel.Text = "ENTER TO START"
	end
	if metaLabel then
		metaLabel.Text = "CHOOSE A LEVEL, THEN WALK THROUGH THE ENTRANCE"
	end
	for index, label in ipairs(answerLabels) do
		label.Text = ({ "A", "B", "C" })[index]
	end
end

local function bindHall(hall)
	if not hall or hall == boundHall then
		return
	end
	destroyDisplays()
	boundHall = hall

	local questionBoard = hall:FindFirstChild("QuestionBoard", true)
	if not questionBoard or not questionBoard:IsA("BasePart") then
		return
	end

	local questionGui = makeSurface(questionBoard, "LocalQuestionDisplay", Vector2.new(1800, 520))
	questionLabel = makeTextLabel(
		questionGui,
		"Question",
		UDim2.fromScale(0.04, 0.06),
		UDim2.fromScale(0.92, 0.62),
		TITLE_FONT,
		Color3.fromRGB(18, 23, 29),
		42,
		112
	)
	metaLabel = makeTextLabel(
		questionGui,
		"Meta",
		UDim2.fromScale(0.05, 0.72),
		UDim2.fromScale(0.90, 0.20),
		BODY_FONT,
		Color3.fromRGB(48, 57, 68),
		20,
		36
	)

	for index = 1, 3 do
		local board = hall:FindFirstChild("AnswerBoard_" .. tostring(index), true)
		if board and board:IsA("BasePart") then
			local answerGui = makeSurface(board, "LocalAnswerDisplay_" .. tostring(index), Vector2.new(900, 300))
			local label = makeTextLabel(
				answerGui,
				"Answer",
				UDim2.fromScale(0.04, 0.05),
				UDim2.fromScale(0.92, 0.90),
				TITLE_FONT,
				Color3.fromRGB(18, 23, 29),
				48,
				128
			)
			answerLabels[index] = label
		end
	end

	setIdleText()
	print("[BrainQuizHallUI] Bound hall=" .. hall:GetFullName() .. " questionBoard=true answerBoards=" .. tostring(#answerLabels))
end

local function updateActiveDisplay(payload, now)
	if not questionLabel or not metaLabel then
		return
	end
	questionLabel.Text = tostring(payload.Prompt or "QUESTION")
	local options = type(payload.Options) == "table" and payload.Options or {}
	for index, label in ipairs(answerLabels) do
		label.Text = tostring(options[index] or "?")
	end

	local endsAt = tonumber(payload.EndsAt) or now
	local remaining = math.max(0, endsAt - now)
	local difficulty = tostring(payload.Difficulty or "NORMAL")
	local score = tonumber(payload.Score) or 0
	local goal = tonumber(payload.Goal) or 5
	local wins = tonumber(payload.WinsEarned) or 0
	local autoEnabled = payload.AutoEnabled ~= false
	local autoText
	if not autoEnabled then
		autoText = "AUTO OFF"
	elseif payload.AutoMoving == true then
		autoText = "AUTO MOVING"
	elseif payload.AutoSolveGuaranteed == true then
		autoText = "AUTO 100%"
	else
		local chance = math.clamp(tonumber(payload.AutoSolveChance) or 0, 0, 1)
		autoText = "AUTO " .. tostring(math.floor(chance * 100 + 0.5)) .. "%"
	end
	metaLabel.Text = difficulty
		.. "   |   " .. tostring(score) .. "/" .. tostring(goal)
		.. "   |   " .. tostring(math.ceil(remaining)) .. "s"
		.. "   |   " .. autoText
		.. "   |   WINS " .. tostring(wins)
end

local function showTemporaryResult(title, meta, duration)
	activePayload = nil
	resultTitle = title
	resultMeta = meta
	resultUntil = os.clock() + duration
	if questionLabel then
		questionLabel.Text = title
	end
	if metaLabel then
		metaLabel.Text = meta
	end
	for index, label in ipairs(answerLabels) do
		label.Text = ({ "A", "B", "C" })[index]
	end
end

BrainQuizState.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	local hall = findHall()
	if hall and hall ~= boundHall then
		bindHall(hall)
	end

	local phase = tostring(payload.Phase or "")
	if phase == "Active" then
		activePayload = payload
		resultUntil = 0
		updateActiveDisplay(payload, Workspace:GetServerTimeNow())
	elseif phase == "Difficulty" then
		showTemporaryResult(
			tostring(payload.Difficulty or "NORMAL") .. " SELECTED",
			tostring(payload.TimeLimit or 60) .. " SECONDS   |   ENTER THE HALL",
			2.5
		)
	elseif phase == "Complete" then
		showTemporaryResult(
			"QUIZ COMPLETE",
			"+" .. tostring(tonumber(payload.WinsEarned) or 0) .. " WINS",
			4
		)
	elseif phase == "Expired" then
		showTemporaryResult(
			"TIME UP",
			"SCORE " .. tostring(payload.Score or 0) .. "/" .. tostring(payload.Goal or 5)
				.. "   |   WINS KEPT " .. tostring(tonumber(payload.WinsEarned) or 0),
			4
		)
	elseif phase == "Cancelled" then
		activePayload = nil
		setIdleText()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	renderAccumulator += deltaTime
	searchAccumulator += deltaTime

	if searchAccumulator >= 0.5 then
		searchAccumulator = 0
		local hall = findHall()
		if hall ~= boundHall then
			if not hall then
				boundHall = nil
				destroyDisplays()
			else
				bindHall(hall)
			end
		end
	end

	if renderAccumulator < 0.1 then
		return
	end
	renderAccumulator = 0

	if resultUntil > 0 then
		if os.clock() < resultUntil then
			if questionLabel then
				questionLabel.Text = resultTitle or ""
			end
			if metaLabel then
				metaLabel.Text = resultMeta or ""
			end
			return
		end
		resultUntil = 0
		resultTitle = nil
		resultMeta = nil
		setIdleText()
	end

	if activePayload then
		updateActiveDisplay(activePayload, Workspace:GetServerTimeNow())
	end
end)

local initialHall = findHall()
if initialHall then
	bindHall(initialHall)
end

print("[BrainQuizHallUI] Ready worldQuestion=true roomAnswers=true screenQuizPanel=false")
