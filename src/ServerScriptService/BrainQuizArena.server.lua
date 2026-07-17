-- ServerScriptService/BrainQuizArena.server.lua
-- Brain Quiz Hall: enter one of three answer rooms. AUTO moves into the correct room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameLogic = require(ServerScriptService:WaitForChild("GameLogic"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name)
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		remote:Destroy()
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local BrainQuizState = getOrCreateRemoteEvent("BrainQuizState")
local BrainQuizAutoToggle = getOrCreateRemoteEvent("BrainQuizAutoToggle")
local UpdateStats = getOrCreateRemoteEvent("UpdateStats")
local PopupEvent = getOrCreateRemoteEvent("PopupEvent")

local MAP_NAME = "SimpleMap"
local HALL_NAME = "BrainQuizHall"
local QUESTIONS_TO_FINISH = 5
local WIN_PER_CORRECT = 1
local WRONG_ANSWER_PENALTY_SECONDS = 5
local COMPLETION_COOLDOWN_SECONDS = 45
local ANSWER_DEBOUNCE_SECONDS = 0.7
local START_DEBOUNCE_SECONDS = 1.5
local GUARANTEED_AUTO_IQ = 500
local LOW_IQ_MIN_CHANCE = 0.15
local LOW_IQ_MAX_CHANCE = 0.90
local LOW_IQ_RETRY_DELAY = 8
local AUTO_MOVE_TIMEOUT = 5

local DIFFICULTIES = {
	Easy = { DisplayName = "EASY", TimeLimit = 75 },
	Normal = { DisplayName = "NORMAL", TimeLimit = 60 },
	Hard = { DisplayName = "HARD", TimeLimit = 45 },
}
local DIFFICULTY_ORDER = { "Easy", "Normal", "Hard" }
local GUARANTEED_AUTO_TIERS = {
	{ RequiredIQ = 35000, Delay = 1 },
	{ RequiredIQ = 10000, Delay = 2 },
	{ RequiredIQ = 2000, Delay = 5 },
	{ RequiredIQ = GUARANTEED_AUTO_IQ, Delay = 8 },
}

local COLORS = {
	Floor = Color3.fromRGB(202, 207, 211),
	Path = Color3.fromRGB(188, 192, 196),
	Wall = Color3.fromRGB(240, 232, 212),
	Trim = Color3.fromRGB(94, 111, 128),
	Roof = Color3.fromRGB(61, 83, 105),
	Board = Color3.fromRGB(251, 248, 239),
	BoardBorder = Color3.fromRGB(38, 45, 54),
	Text = Color3.fromRGB(21, 26, 32),
	RoomA = Color3.fromRGB(166, 105, 109),
	RoomB = Color3.fromRGB(85, 121, 153),
	RoomC = Color3.fromRGB(172, 143, 86),
	Easy = Color3.fromRGB(95, 141, 107),
	Normal = Color3.fromRGB(170, 140, 83),
	Hard = Color3.fromRGB(157, 91, 96),
}

local random = Random.new()
local states = {}
local saveStates = {}
local startTouchAt = {}
local difficultyTouchAt = {}
local roomDoorways = {}
local roomTargets = {}
local roomTriggers = {}
local choicePoint = nil
local installedMap = nil
local scheduleAutoAttempt
local answerQuestion

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

local function firePopup(player, title, subtitle)
	PopupEvent:FireClient(player, tostring(title) .. "|" .. tostring(subtitle), "Info")
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function getDifficultyConfig(name)
	return DIFFICULTIES[name] or DIFFICULTIES.Normal
end

local function getState(player)
	local state = states[player.UserId]
	if state then
		return state
	end
	state = {
		Active = false,
		Difficulty = "Normal",
		Score = 0,
		Attempts = 0,
		WinsEarned = 0,
		AutoSolvedCount = 0,
		EndsAt = 0,
		CooldownUntil = 0,
		Question = nil,
		QuestionId = 0,
		ResolvedQuestionId = 0,
		Token = 0,
		LastAnswerAt = 0,
		AutoEnabled = true,
		AutoSolveDelay = LOW_IQ_RETRY_DELAY,
		AutoSolveAt = nil,
		AutoSolveChance = LOW_IQ_MIN_CHANCE,
		AutoSolveGuaranteed = false,
		CurrentIQ = 0,
		AutoMoving = false,
		AutoMoveQuestionId = 0,
		AutoMoveAnswerIndex = 0,
	}
	states[player.UserId] = state
	return state
end

local function resetActiveState(state)
	state.Active = false
	state.Score = 0
	state.Attempts = 0
	state.WinsEarned = 0
	state.AutoSolvedCount = 0
	state.EndsAt = 0
	state.Question = nil
	state.QuestionId += 1
	state.ResolvedQuestionId = 0
	state.LastAnswerAt = 0
	state.AutoSolveAt = nil
	state.AutoMoving = false
	state.AutoMoveQuestionId = 0
	state.AutoMoveAnswerIndex = 0
end

local function stopAutoMovement(player, state)
	state.AutoMoving = false
	state.AutoMoveQuestionId = 0
	state.AutoMoveAnswerIndex = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		humanoid:MoveTo(root.Position)
	end
end

local function getAutoProfile(player)
	local currentIQ = math.max(0, tonumber(GameLogic.GetIQ(player)) or 0)
	for _, tier in ipairs(GUARANTEED_AUTO_TIERS) do
		if currentIQ >= tier.RequiredIQ then
			return tier.Delay, 1, true, currentIQ
		end
	end
	local progress = math.clamp(currentIQ / GUARANTEED_AUTO_IQ, 0, 1)
	local chance = LOW_IQ_MIN_CHANCE + (LOW_IQ_MAX_CHANCE - LOW_IQ_MIN_CHANCE) * progress
	return LOW_IQ_RETRY_DELAY, chance, false, currentIQ
end

local function shuffle(values)
	for index = #values, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		values[index], values[swapIndex] = values[swapIndex], values[index]
	end
end

local function buildChoices(correct, spread)
	local values = { correct }
	local used = { [correct] = true }
	spread = math.max(3, math.floor(tonumber(spread) or 10))
	while #values < 3 do
		local candidate = math.max(0, correct + random:NextInteger(-spread, spread))
		if not used[candidate] then
			used[candidate] = true
			table.insert(values, candidate)
		end
	end
	shuffle(values)
	local options = {}
	local correctIndex = 1
	for index, value in ipairs(values) do
		options[index] = tostring(value)
		if value == correct then
			correctIndex = index
		end
	end
	return options, correctIndex
end

local function makeQuestion(promptText, correct, spread)
	local options, correctIndex = buildChoices(correct, spread)
	return {
		Prompt = promptText,
		Options = options,
		CorrectIndex = correctIndex,
	}
end

local function buildEasyQuestion()
	local questionType = random:NextInteger(1, 4)
	if questionType == 1 then
		local a = random:NextInteger(1, 20)
		local b = random:NextInteger(1, 15)
		return makeQuestion(tostring(a) .. " + " .. tostring(b) .. " = ?", a + b, 8)
	elseif questionType == 2 then
		local a = random:NextInteger(10, 35)
		local b = random:NextInteger(1, a - 1)
		return makeQuestion(tostring(a) .. " - " .. tostring(b) .. " = ?", a - b, 8)
	elseif questionType == 3 then
		local a = random:NextInteger(1, 50)
		local b = random:NextInteger(1, 50)
		while b == a do
			b = random:NextInteger(1, 50)
		end
		return makeQuestion("BIGGER: " .. tostring(a) .. " OR " .. tostring(b) .. "?", math.max(a, b), 12)
	else
		local start = random:NextInteger(1, 12)
		local step = random:NextInteger(1, 5)
		return makeQuestion(
			"NEXT: " .. tostring(start) .. ", " .. tostring(start + step) .. ", " .. tostring(start + step * 2) .. ", ?",
			start + step * 3,
			8
		)
	end
end

local function buildNormalQuestion()
	local questionType = random:NextInteger(1, 5)
	if questionType == 1 then
		local a = random:NextInteger(6, 35)
		local b = random:NextInteger(4, 28)
		return makeQuestion(tostring(a) .. " + " .. tostring(b) .. " = ?", a + b, 14)
	elseif questionType == 2 then
		local a = random:NextInteger(20, 60)
		local b = random:NextInteger(4, a - 3)
		return makeQuestion(tostring(a) .. " - " .. tostring(b) .. " = ?", a - b, 12)
	elseif questionType == 3 then
		local a = random:NextInteger(2, 12)
		local b = random:NextInteger(2, 12)
		return makeQuestion(tostring(a) .. " × " .. tostring(b) .. " = ?", a * b, 18)
	elseif questionType == 4 then
		local start = random:NextInteger(2, 18)
		local step = random:NextInteger(2, 8)
		return makeQuestion(
			"NEXT: " .. tostring(start) .. ", " .. tostring(start + step) .. ", " .. tostring(start + step * 2) .. ", ?",
			start + step * 3,
			10
		)
	else
		local a = random:NextInteger(10, 70)
		local b = random:NextInteger(10, 70)
		while b == a do
			b = random:NextInteger(10, 70)
		end
		return makeQuestion("BIGGER: " .. tostring(a) .. " OR " .. tostring(b) .. "?", math.max(a, b), 15)
	end
end

local function buildHardQuestion()
	local questionType = random:NextInteger(1, 5)
	if questionType == 1 then
		local a = random:NextInteger(35, 99)
		local b = random:NextInteger(25, 89)
		return makeQuestion(tostring(a) .. " + " .. tostring(b) .. " = ?", a + b, 24)
	elseif questionType == 2 then
		local a = random:NextInteger(70, 160)
		local b = random:NextInteger(15, 69)
		return makeQuestion(tostring(a) .. " - " .. tostring(b) .. " = ?", a - b, 22)
	elseif questionType == 3 then
		local a = random:NextInteger(6, 15)
		local b = random:NextInteger(6, 15)
		return makeQuestion(tostring(a) .. " × " .. tostring(b) .. " = ?", a * b, 30)
	elseif questionType == 4 then
		local divisor = random:NextInteger(3, 12)
		local quotient = random:NextInteger(4, 15)
		return makeQuestion(tostring(divisor * quotient) .. " ÷ " .. tostring(divisor) .. " = ?", quotient, 8)
	else
		local a = random:NextInteger(4, 12)
		local b = random:NextInteger(4, 12)
		local c = random:NextInteger(5, 30)
		return makeQuestion(tostring(a) .. " × " .. tostring(b) .. " + " .. tostring(c) .. " = ?", a * b + c, 28)
	end
end

local function buildQuestion(difficultyName)
	if difficultyName == "Easy" then
		return buildEasyQuestion()
	elseif difficultyName == "Hard" then
		return buildHardQuestion()
	end
	return buildNormalQuestion()
end

local function prepareQuestion(player, state)
	state.Question = buildQuestion(state.Difficulty)
	state.QuestionId += 1
	state.ResolvedQuestionId = 0
	state.AutoMoving = false
	state.AutoMoveQuestionId = 0
	state.AutoMoveAnswerIndex = 0
	state.AutoSolveDelay, state.AutoSolveChance, state.AutoSolveGuaranteed, state.CurrentIQ = getAutoProfile(player)
	if state.AutoEnabled then
		state.AutoSolveAt = math.min(state.EndsAt, Workspace:GetServerTimeNow() + state.AutoSolveDelay)
	else
		state.AutoSolveAt = nil
	end
end

local function sendActiveState(player, state, feedback)
	if not player.Parent or not state.Active or not state.Question then
		return
	end
	local difficulty = getDifficultyConfig(state.Difficulty)
	BrainQuizState:FireClient(player, {
		Phase = "Active",
		HallName = HALL_NAME,
		Difficulty = difficulty.DisplayName,
		Prompt = state.Question.Prompt,
		Options = state.Question.Options,
		Score = state.Score,
		Goal = QUESTIONS_TO_FINISH,
		Attempts = state.Attempts,
		WinsEarned = state.WinsEarned,
		EndsAt = state.EndsAt,
		Feedback = feedback,
		AutoEnabled = state.AutoEnabled,
		AutoSolveDelay = state.AutoSolveDelay,
		AutoSolveAt = state.AutoSolveAt,
		AutoSolveChance = state.AutoSolveChance,
		AutoSolveGuaranteed = state.AutoSolveGuaranteed,
		CurrentIQ = state.CurrentIQ,
		AutoMoving = state.AutoMoving,
	})
end

local function queueWinsSave(player)
	local userId = player.UserId
	local saveState = saveStates[userId]
	if not saveState then
		saveState = { Pending = false, Running = false }
		saveStates[userId] = saveState
	end
	saveState.Pending = true
	if saveState.Running then
		return
	end

	saveState.Running = true
	task.spawn(function()
		while player.Parent and saveState.Pending do
			saveState.Pending = false
			task.wait(0.6)
			local saved = false
			local lastError = nil
			for attempt = 1, 2 do
				if not DataManager.IsLoaded(player) then
					break
				end
				local ok, result = pcall(function()
					return DataManager.SaveProfile(player, false, { Reason = "BrainQuizCorrect" })
				end)
				if ok and result then
					saved = true
					break
				end
				lastError = result
				if attempt == 1 then
					task.wait(1)
				end
			end
			if saved then
				print("[BrainQuizHall] SaveOK player=" .. player.Name .. " wins=" .. tostring(GameLogic.GetWins(player)))
			else
				warn("[BrainQuizHall] SaveFailed player=" .. player.Name .. " error=" .. tostring(lastError))
			end
		end
		saveState.Running = false
	end)
end

local function returnPlayerToChoice(player)
	if not choicePoint or not choicePoint.Parent then
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(choicePoint.CFrame + Vector3.new(0, 3.2, 0))
	end
end

local function expireRun(player, state, reason)
	if not state.Active then
		return
	end
	local score = state.Score
	local winsEarned = state.WinsEarned
	local difficulty = getDifficultyConfig(state.Difficulty).DisplayName
	state.Token += 1
	stopAutoMovement(player, state)
	resetActiveState(state)
	returnPlayerToChoice(player)
	BrainQuizState:FireClient(player, {
		Phase = "Expired",
		HallName = HALL_NAME,
		Difficulty = difficulty,
		Score = score,
		Goal = QUESTIONS_TO_FINISH,
		WinsEarned = winsEarned,
		Message = reason or "TIME UP",
		AutoEnabled = state.AutoEnabled,
	})
	firePopup(player, "QUIZ ENDED", "Score " .. tostring(score) .. "/" .. tostring(QUESTIONS_TO_FINISH) .. " · +" .. tostring(winsEarned) .. " Wins kept")
	print("[BrainQuizHall] Expired player=" .. player.Name .. " score=" .. tostring(score) .. " winsEarned=" .. tostring(winsEarned))
end

local function completeRun(player, state)
	local attempts = state.Attempts
	local autoSolvedCount = state.AutoSolvedCount
	local winsEarned = state.WinsEarned
	local difficulty = getDifficultyConfig(state.Difficulty).DisplayName
	local timeLimit = getDifficultyConfig(state.Difficulty).TimeLimit
	local elapsed = math.max(0, timeLimit - math.max(0, state.EndsAt - Workspace:GetServerTimeNow()))
	state.Token += 1
	stopAutoMovement(player, state)
	resetActiveState(state)
	state.CooldownUntil = Workspace:GetServerTimeNow() + COMPLETION_COOLDOWN_SECONDS
	returnPlayerToChoice(player)
	BrainQuizState:FireClient(player, {
		Phase = "Complete",
		HallName = HALL_NAME,
		Difficulty = difficulty,
		WinsEarned = winsEarned,
		Attempts = attempts,
		AutoSolvedCount = autoSolvedCount,
		Elapsed = elapsed,
		CooldownUntil = state.CooldownUntil,
		AutoEnabled = state.AutoEnabled,
	})
	firePopup(player, "QUIZ COMPLETE!", "+" .. tostring(winsEarned) .. " Wins · " .. string.format("%.1fs", elapsed))
	queueWinsSave(player)
	print("[BrainQuizHall] Complete player=" .. player.Name .. " attempts=" .. tostring(attempts) .. " autoSolved=" .. tostring(autoSolvedCount) .. " winsEarned=" .. tostring(winsEarned))
end

local function horizontalDistance(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function moveToPart(player, state, runToken, questionId, targetPart)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not targetPart or not targetPart.Parent or not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	local targetPosition = Vector3.new(targetPart.Position.X, targetPart.Position.Y + 2.8, targetPart.Position.Z)
	humanoid:MoveTo(targetPosition)
	local deadline = os.clock() + AUTO_MOVE_TIMEOUT
	while os.clock() < deadline do
		if not player.Parent or not state.Active or not state.AutoEnabled or state.Token ~= runToken or state.QuestionId ~= questionId then
			return false
		end
		character = player.Character
		root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end
		if horizontalDistance(root.Position, targetPosition) <= 4.5 then
			return true
		end
		task.wait(0.1)
	end
	character = player.Character
	if not character then
		return false
	end
	character:PivotTo(CFrame.new(targetPosition))
	task.wait(0.1)
	return state.Active and state.AutoEnabled and state.Token == runToken and state.QuestionId == questionId
end

local function movePlayerToCorrectRoom(player, state, correctIndex, runToken, questionId)
	local doorway = roomDoorways[correctIndex]
	local target = roomTargets[correctIndex]
	if not doorway or not target then
		warn("[BrainQuizHall] AutoMoveFailed player=" .. player.Name .. " reason=missing_room_target")
		return
	end
	state.AutoMoving = true
	state.AutoMoveQuestionId = questionId
	state.AutoMoveAnswerIndex = correctIndex
	state.AutoSolveAt = nil
	sendActiveState(player, state, "AUTO FOUND THE CORRECT ROOM")
	task.spawn(function()
		if not moveToPart(player, state, runToken, questionId, doorway) then
			return
		end
		if not moveToPart(player, state, runToken, questionId, target) then
			return
		end
		if state.Active and state.AutoEnabled and state.Token == runToken and state.QuestionId == questionId then
			answerQuestion(player, correctIndex, true, questionId)
		end
	end)
end

scheduleAutoAttempt = function(player, state)
	if not state.Active or not state.Question or not state.AutoEnabled or not state.AutoSolveAt then
		return
	end
	local runToken = state.Token
	local questionId = state.QuestionId
	local correctIndex = state.Question.CorrectIndex
	local delaySeconds = math.max(0, state.AutoSolveAt - Workspace:GetServerTimeNow())
	task.delay(delaySeconds, function()
		if not player.Parent or not state.Active or not state.AutoEnabled or state.AutoMoving then
			return
		end
		if state.Token ~= runToken or state.QuestionId ~= questionId or Workspace:GetServerTimeNow() >= state.EndsAt then
			return
		end
		local succeeded = state.AutoSolveGuaranteed or random:NextNumber() <= state.AutoSolveChance
		print("[BrainQuizHall] AutoAttempt player=" .. player.Name .. " IQ=" .. tostring(state.CurrentIQ) .. " chance=" .. string.format("%.2f", state.AutoSolveChance) .. " guaranteed=" .. tostring(state.AutoSolveGuaranteed) .. " success=" .. tostring(succeeded))
		if succeeded then
			movePlayerToCorrectRoom(player, state, correctIndex, runToken, questionId)
			return
		end
		state.AutoSolveAt = math.min(state.EndsAt, Workspace:GetServerTimeNow() + state.AutoSolveDelay)
		sendActiveState(player, state, "AUTO MISSED · TRYING AGAIN")
		scheduleAutoAttempt(player, state)
	end)
end

local function setAutoEnabled(player, enabled)
	local state = getState(player)
	state.AutoEnabled = enabled == true
	if not state.AutoEnabled then
		state.AutoSolveAt = nil
		stopAutoMovement(player, state)
		if state.Active then
			sendActiveState(player, state, "AUTO OFF · CHOOSE A ROOM")
		else
			BrainQuizState:FireClient(player, { Phase = "AutoToggle", AutoEnabled = false, HallName = HALL_NAME })
		end
		firePopup(player, "QUIZ AUTO: OFF", "Choose a room manually")
	else
		if state.Active and state.Question then
			state.AutoSolveDelay, state.AutoSolveChance, state.AutoSolveGuaranteed, state.CurrentIQ = getAutoProfile(player)
			state.AutoSolveAt = math.min(state.EndsAt, Workspace:GetServerTimeNow() + state.AutoSolveDelay)
			sendActiveState(player, state, "AUTO ON · SEARCHING")
			scheduleAutoAttempt(player, state)
		else
			BrainQuizState:FireClient(player, { Phase = "AutoToggle", AutoEnabled = true, HallName = HALL_NAME })
		end
		firePopup(player, "QUIZ AUTO: ON", "Character will enter the correct room")
	end
	print("[BrainQuizHall] AutoToggle player=" .. player.Name .. " enabled=" .. tostring(state.AutoEnabled))
end

BrainQuizAutoToggle.OnServerEvent:Connect(function(player, enabled)
	if type(enabled) == "boolean" then
		setAutoEnabled(player, enabled)
	end
end)

local function selectDifficulty(player, difficultyName)
	local config = DIFFICULTIES[difficultyName]
	if not config then
		return
	end
	local now = os.clock()
	local lastTouch = tonumber(difficultyTouchAt[player.UserId]) or 0
	if now - lastTouch < 1.25 then
		return
	end
	difficultyTouchAt[player.UserId] = now
	local state = getState(player)
	if state.Active then
		firePopup(player, "QUIZ ACTIVE", "Difficulty changes next run")
		return
	end
	state.Difficulty = difficultyName
	BrainQuizState:FireClient(player, {
		Phase = "Difficulty",
		HallName = HALL_NAME,
		Difficulty = config.DisplayName,
		TimeLimit = config.TimeLimit,
		AutoEnabled = state.AutoEnabled,
	})
	firePopup(player, "DIFFICULTY: " .. config.DisplayName, tostring(config.TimeLimit) .. " seconds")
	print("[BrainQuizHall] Difficulty player=" .. player.Name .. " selected=" .. config.DisplayName)
end

local function startRun(player)
	if not DataManager.IsLoaded(player) then
		firePopup(player, "PLEASE WAIT", "Data is still loading")
		return
	end
	if not GameLogic.IsAlive(player) then
		return
	end
	local nowClock = os.clock()
	local lastTouch = tonumber(startTouchAt[player.UserId]) or 0
	if nowClock - lastTouch < START_DEBOUNCE_SECONDS then
		return
	end
	startTouchAt[player.UserId] = nowClock
	local state = getState(player)
	local now = Workspace:GetServerTimeNow()
	if state.Active then
		return
	end
	if now < state.CooldownUntil then
		firePopup(player, "QUIZ COOLDOWN", "Ready in " .. tostring(math.max(1, math.ceil(state.CooldownUntil - now))) .. "s")
		return
	end
	local difficulty = getDifficultyConfig(state.Difficulty)
	state.Token += 1
	state.Active = true
	state.Score = 0
	state.Attempts = 0
	state.WinsEarned = 0
	state.AutoSolvedCount = 0
	state.EndsAt = now + difficulty.TimeLimit
	state.LastAnswerAt = 0
	prepareQuestion(player, state)
	returnPlayerToChoice(player)
	local chancePercent = math.floor(state.AutoSolveChance * 100 + 0.5)
	local feedback
	if not state.AutoEnabled then
		feedback = "AUTO OFF · ENTER A ROOM"
	elseif state.AutoSolveGuaranteed then
		feedback = "AUTO 100% · MOVING IN " .. tostring(state.AutoSolveDelay) .. "s"
	else
		feedback = "AUTO " .. tostring(chancePercent) .. "% · MANUAL IS FASTER"
	end
	sendActiveState(player, state, feedback)
	scheduleAutoAttempt(player, state)
	firePopup(player, "BRAIN QUIZ · " .. difficulty.DisplayName, "Enter the room with the correct answer")
	print("[BrainQuizHall] Start player=" .. player.Name .. " difficulty=" .. difficulty.DisplayName .. " IQ=" .. tostring(state.CurrentIQ) .. " autoEnabled=" .. tostring(state.AutoEnabled))
	local token = state.Token
	task.spawn(function()
		while player.Parent and state.Active and state.Token == token do
			if Workspace:GetServerTimeNow() >= state.EndsAt then
				expireRun(player, state, "TIME UP")
				break
			end
			task.wait(0.2)
		end
	end)
end

answerQuestion = function(player, answerIndex, autoSolved, questionId)
	local state = getState(player)
	local now = Workspace:GetServerTimeNow()
	questionId = tonumber(questionId) or state.QuestionId
	if not state.Active or not state.Question or questionId ~= state.QuestionId then
		return
	end
	if state.ResolvedQuestionId == questionId then
		return
	end
	if now >= state.EndsAt then
		expireRun(player, state, "TIME UP")
		return
	end
	if now - state.LastAnswerAt < ANSWER_DEBOUNCE_SECONDS then
		return
	end
	state.LastAnswerAt = now
	state.ResolvedQuestionId = questionId
	stopAutoMovement(player, state)
	state.Attempts += 1
	if autoSolved == true then
		state.AutoSolvedCount += 1
	end
	local isCorrect = answerIndex == state.Question.CorrectIndex
	if isCorrect then
		state.Score += 1
		state.WinsEarned += WIN_PER_CORRECT
		GameLogic.AddWins(player, WIN_PER_CORRECT)
		UpdateStats:FireClient(player, { Wins = GameLogic.GetWins(player) })
		queueWinsSave(player)
	else
		state.EndsAt -= WRONG_ANSWER_PENALTY_SECONDS
	end
	print("[BrainQuizHall] Answer player=" .. player.Name .. " room=" .. tostring(answerIndex) .. " correct=" .. tostring(isCorrect) .. " auto=" .. tostring(autoSolved == true) .. " score=" .. tostring(state.Score) .. " winsEarned=" .. tostring(state.WinsEarned))
	if state.Score >= QUESTIONS_TO_FINISH then
		completeRun(player, state)
		return
	end
	if Workspace:GetServerTimeNow() >= state.EndsAt then
		expireRun(player, state, "WRONG ROOM · TIME UP")
		return
	end
	returnPlayerToChoice(player)
	prepareQuestion(player, state)
	local feedback = isCorrect and "+1 WIN · CORRECT ROOM" or ("WRONG ROOM · -" .. tostring(WRONG_ANSWER_PENALTY_SECONDS) .. "s")
	if autoSolved == true and isCorrect then
		feedback = "+1 WIN · AUTO ENTERED"
	end
	if not state.AutoEnabled then
		feedback ..= " · AUTO OFF"
	end
	sendActiveState(player, state, feedback)
	scheduleAutoAttempt(player, state)
end

local function createPart(parent, name, size, cframe, color, material, canCollide, canTouch, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.CanTouch = canTouch == true
	part.CanQuery = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addStaticText(part, face, text, font, minTextSize, maxTextSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StaticText"
	gui.Face = face
	gui.LightInfluence = 1
	gui.PixelsPerStud = 70
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.06)
	label.Size = UDim2.fromScale(0.92, 0.88)
	label.Font = font or BODY_FONT
	label.Text = text
	label.TextColor3 = COLORS.Text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = 1
	label.Parent = gui
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minTextSize or 16
	constraint.MaxTextSize = maxTextSize or 42
	constraint.Parent = label
end

local function addBoardBorder(parent, board, thickness)
	thickness = thickness or 0.7
	local size = board.Size
	local cf = board.CFrame
	for name, data in pairs({
		Top = { Vector3.new(size.X + thickness * 2, thickness, thickness), Vector3.new(0, size.Y * 0.5 + thickness * 0.5, -size.Z * 0.5 - 0.02) },
		Bottom = { Vector3.new(size.X + thickness * 2, thickness, thickness), Vector3.new(0, -size.Y * 0.5 - thickness * 0.5, -size.Z * 0.5 - 0.02) },
		Left = { Vector3.new(thickness, size.Y, thickness), Vector3.new(-size.X * 0.5 - thickness * 0.5, 0, -size.Z * 0.5 - 0.02) },
		Right = { Vector3.new(thickness, size.Y, thickness), Vector3.new(size.X * 0.5 + thickness * 0.5, 0, -size.Z * 0.5 - 0.02) },
	}) do
		createPart(parent, board.Name .. name .. "Border", data[1], cf * CFrame.new(data[2]), COLORS.BoardBorder, Enum.Material.SmoothPlastic, false, false)
	end
end

local function createAnswerRoom(hall, center, index, xOffset, accentColor)
	local room = Instance.new("Model")
	room.Name = "AnswerRoom_" .. tostring(index)
	room.Parent = hall
	local roomCenter = center + Vector3.new(xOffset, 0, -18)
	local width = 25
	local depth = 24
	local wallHeight = 16
	local wallThickness = 1.5
	local doorWidth = 10
	createPart(room, "Floor", Vector3.new(width, 1, depth), CFrame.new(roomCenter + Vector3.new(0, 0.5, 0)), Color3.fromRGB(217, 214, 206), Enum.Material.Concrete, true, false)
	createPart(room, "BackWall", Vector3.new(width, wallHeight, wallThickness), CFrame.new(roomCenter + Vector3.new(0, wallHeight * 0.5, -depth * 0.5)), COLORS.Wall, Enum.Material.SmoothPlastic, true, false)
	createPart(room, "LeftWall", Vector3.new(wallThickness, wallHeight, depth), CFrame.new(roomCenter + Vector3.new(-width * 0.5, wallHeight * 0.5, 0)), COLORS.Wall, Enum.Material.SmoothPlastic, true, false)
	createPart(room, "RightWall", Vector3.new(wallThickness, wallHeight, depth), CFrame.new(roomCenter + Vector3.new(width * 0.5, wallHeight * 0.5, 0)), COLORS.Wall, Enum.Material.SmoothPlastic, true, false)
	local frontSideWidth = (width - doorWidth) * 0.5
	createPart(room, "FrontLeft", Vector3.new(frontSideWidth, wallHeight, wallThickness), CFrame.new(roomCenter + Vector3.new(-(doorWidth * 0.5 + frontSideWidth * 0.5), wallHeight * 0.5, depth * 0.5)), COLORS.Wall, Enum.Material.SmoothPlastic, true, false)
	createPart(room, "FrontRight", Vector3.new(frontSideWidth, wallHeight, wallThickness), CFrame.new(roomCenter + Vector3.new(doorWidth * 0.5 + frontSideWidth * 0.5, wallHeight * 0.5, depth * 0.5)), COLORS.Wall, Enum.Material.SmoothPlastic, true, false)
	createPart(room, "DoorTop", Vector3.new(doorWidth, 4, wallThickness), CFrame.new(roomCenter + Vector3.new(0, wallHeight - 2, depth * 0.5)), accentColor, Enum.Material.SmoothPlastic, true, false)
	createPart(room, "Roof", Vector3.new(width + 1, 1, depth + 1), CFrame.new(roomCenter + Vector3.new(0, wallHeight + 0.5, 0)), COLORS.Roof, Enum.Material.SmoothPlastic, true, false)
	local answerBoard = createPart(room, "AnswerBoard_" .. tostring(index), Vector3.new(18, 5.5, 1), CFrame.new(roomCenter + Vector3.new(0, 11.5, depth * 0.5 + 0.8)) * CFrame.Angles(0, math.rad(180), 0), COLORS.Board, Enum.Material.SmoothPlastic, false, false)
	addBoardBorder(room, answerBoard, 0.65)
	local doorway = createPart(room, "RoomDoorway_" .. tostring(index), Vector3.new(5, 1, 5), CFrame.new(roomCenter + Vector3.new(0, 1, depth * 0.5 + 6)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, false, 1)
	local target = createPart(room, "RoomTarget_" .. tostring(index), Vector3.new(5, 1, 5), CFrame.new(roomCenter + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, false, 1)
	local trigger = createPart(room, "RoomTrigger_" .. tostring(index), Vector3.new(12, 8, 9), CFrame.new(roomCenter + Vector3.new(0, 4, -1)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, true, 1)
	roomDoorways[index] = doorway
	roomTargets[index] = target
	roomTriggers[index] = trigger
	trigger.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end
		local state = getState(player)
		local autoMoved = state.Active and state.AutoMoving and state.AutoMoveQuestionId == state.QuestionId and state.AutoMoveAnswerIndex == index
		answerQuestion(player, index, autoMoved, state.QuestionId)
	end)
end

local function installHall(map)
	if installedMap == map and map:FindFirstChild(HALL_NAME) then
		return
	end
	local oldHall = map:FindFirstChild(HALL_NAME)
	if oldHall then
		oldHall:Destroy()
	end
	table.clear(roomDoorways)
	table.clear(roomTargets)
	table.clear(roomTriggers)
	choicePoint = nil
	local center = Vector3.new(145, 0, -110)
	local hall = Instance.new("Model")
	hall.Name = HALL_NAME
	hall:SetAttribute("RoomAnswerMode", true)
	hall:SetAttribute("NoNeon", true)
	hall:SetAttribute("QuestionsToFinish", QUESTIONS_TO_FINISH)
	hall.Parent = map
	createPart(hall, "HallCourtyard", Vector3.new(104, 1, 92), CFrame.new(center + Vector3.new(0, 0.5, 5)), COLORS.Floor, Enum.Material.Concrete, true, false)
	createPart(hall, "HallPath", Vector3.new(22, 0.7, 56), CFrame.new(center + Vector3.new(-62, 0.35, 30)), COLORS.Path, Enum.Material.Concrete, true, false)
	local entranceHeader = createPart(hall, "EntranceHeader", Vector3.new(44, 8, 2), CFrame.new(center + Vector3.new(0, 11, 38)) * CFrame.Angles(0, math.rad(180), 0), COLORS.Board, Enum.Material.SmoothPlastic, false, false)
	addStaticText(entranceHeader, Enum.NormalId.Front, "BRAIN QUIZ HALL", TITLE_FONT, 24, 46)
	addBoardBorder(hall, entranceHeader, 0.7)
	createPart(hall, "EntrancePostLeft", Vector3.new(2, 16, 2), CFrame.new(center + Vector3.new(-21, 8, 38)), COLORS.Trim, Enum.Material.SmoothPlastic, true, false)
	createPart(hall, "EntrancePostRight", Vector3.new(2, 16, 2), CFrame.new(center + Vector3.new(21, 8, 38)), COLORS.Trim, Enum.Material.SmoothPlastic, true, false)
	local problemBoard = createPart(hall, "QuestionBoard", Vector3.new(84, 11, 1.2), CFrame.new(center + Vector3.new(0, 23, 1)) * CFrame.Angles(0, math.rad(180), 0), COLORS.Board, Enum.Material.SmoothPlastic, false, false)
	addBoardBorder(hall, problemBoard, 0.8)
	choicePoint = createPart(hall, "HallChoicePoint", Vector3.new(6, 1, 6), CFrame.new(center + Vector3.new(0, 1, 12)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, false, 1)
	local startTrigger = createPart(hall, "HallStartTrigger", Vector3.new(34, 9, 8), CFrame.new(center + Vector3.new(0, 4.5, 29)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, true, 1)
	startTrigger.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if player then
			startRun(player)
		end
	end)
	createAnswerRoom(hall, center, 1, -30, COLORS.RoomA)
	createAnswerRoom(hall, center, 2, 0, COLORS.RoomB)
	createAnswerRoom(hall, center, 3, 30, COLORS.RoomC)
	local deskOffsets = { -24, 0, 24 }
	for index, difficultyName in ipairs(DIFFICULTY_ORDER) do
		local config = DIFFICULTIES[difficultyName]
		local desk = createPart(hall, "DifficultyDesk_" .. difficultyName, Vector3.new(16, 4, 7), CFrame.new(center + Vector3.new(deskOffsets[index], 2, 49)), COLORS[difficultyName], Enum.Material.SmoothPlastic, true, false)
		local top = createPart(hall, "DifficultyTop_" .. difficultyName, Vector3.new(16, 0.8, 7), CFrame.new(center + Vector3.new(deskOffsets[index], 4.4, 49)), COLORS.Board, Enum.Material.SmoothPlastic, true, false)
		addStaticText(top, Enum.NormalId.Top, config.DisplayName .. "\n" .. tostring(config.TimeLimit) .. " SEC", BODY_FONT, 18, 34)
		local trigger = createPart(hall, "DifficultyTrigger_" .. difficultyName, Vector3.new(16, 6, 8), CFrame.new(center + Vector3.new(deskOffsets[index], 3, 49)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, true, 1)
		trigger.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			if player then
				selectDifficulty(player, difficultyName)
			end
		end)
	end
	installedMap = map
	map:SetAttribute("BrainQuizHallInstalled", true)
	print("[BrainQuizHall] Installed rooms=3 location=rightRear autoMovesIntoRoom=true winPerCorrect=1")
end

local function installForMap(map)
	if not map or map.Name ~= MAP_NAME then
		return
	end
	task.spawn(function()
		task.wait(0.6)
		if map.Parent == Workspace then
			installHall(map)
		end
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		installForMap(child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	installForMap(existingMap)
end

local function bindPlayer(player)
	getState(player)
	player.CharacterAdded:Connect(function()
		local state = states[player.UserId]
		if state and state.Active then
			state.Token += 1
			resetActiveState(state)
			BrainQuizState:FireClient(player, { Phase = "Cancelled", AutoEnabled = state.AutoEnabled, HallName = HALL_NAME })
		end
	end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player.UserId] = nil
	saveStates[player.UserId] = nil
	startTouchAt[player.UserId] = nil
	difficultyTouchAt[player.UserId] = nil
end)

print("[BrainQuizHall] Ready server=true remotes=true")
