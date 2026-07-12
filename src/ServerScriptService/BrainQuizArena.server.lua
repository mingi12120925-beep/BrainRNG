-- ServerScriptService/BrainQuizArena.server.lua
-- Brain Quiz Arena: auto-first quiz play with optional manual answers.
-- Every correct answer awards +1 Win. IQ 500+ guarantees auto solving;
-- lower IQ uses repeated probability checks and moves the character to the correct pad on success.

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
local UpdateStats = getOrCreateRemoteEvent("UpdateStats")
local PopupEvent = getOrCreateRemoteEvent("PopupEvent")

local ARENA_NAME = "BrainQuizArena"
local QUESTIONS_TO_FINISH = 5
local WIN_PER_CORRECT = 1
local WRONG_ANSWER_PENALTY_SECONDS = 5
local COMPLETION_COOLDOWN_SECONDS = 60
local ANSWER_DEBOUNCE_SECONDS = 0.65
local GUARANTEED_AUTO_IQ = 500
local LOW_IQ_MIN_CHANCE = 0.15
local LOW_IQ_MAX_CHANCE = 0.90
local LOW_IQ_RETRY_DELAY = 8
local AUTO_MOVE_TIMEOUT = 4

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
	Platform = Color3.fromRGB(225, 232, 242),
	PlatformTrim = Color3.fromRGB(75, 111, 170),
	Start = Color3.fromRGB(62, 202, 118),
	A = Color3.fromRGB(255, 100, 110),
	B = Color3.fromRGB(70, 165, 255),
	C = Color3.fromRGB(255, 205, 70),
	Easy = Color3.fromRGB(85, 220, 130),
	Normal = Color3.fromRGB(255, 205, 70),
	Hard = Color3.fromRGB(255, 95, 105),
	Board = Color3.fromRGB(31, 43, 65),
	BoardText = Color3.fromRGB(255, 255, 255),
	Post = Color3.fromRGB(92, 72, 52),
}

local random = Random.new()
local states = {}
local saveStates = {}
local answerPads = {}
local installedMap = nil
local difficultyTouchAt = {}
local answerQuestion
local scheduleAutoAttempt

local function firePopup(player, title, subtitle)
	PopupEvent:FireClient(player, tostring(title) .. "|" .. tostring(subtitle), "Info")
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function getState(player)
	local state = states[player.UserId]
	if not state then
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
			Token = 0,
			LastAnswerAt = 0,
			AutoSolveDelay = LOW_IQ_RETRY_DELAY,
			AutoSolveAt = nil,
			AutoSolveChance = LOW_IQ_MIN_CHANCE,
			AutoSolveGuaranteed = false,
			AutoSolveRequiredIQ = GUARANTEED_AUTO_IQ,
			CurrentIQ = 0,
			AutoMoving = false,
			AutoMoveQuestionId = 0,
			AutoMoveAnswerIndex = 0,
		}
		states[player.UserId] = state
	end
	return state
end

local function getDifficultyConfig(name)
	return DIFFICULTIES[name] or DIFFICULTIES.Normal
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
	state.LastAnswerAt = 0
	state.AutoSolveAt = nil
	state.AutoMoving = false
	state.AutoMoveQuestionId = 0
	state.AutoMoveAnswerIndex = 0
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

local function buildNumberChoices(correct, spread)
	local choices = { correct }
	local used = { [correct] = true }
	spread = math.max(3, math.floor(tonumber(spread) or 10))

	while #choices < 3 do
		local candidate = math.max(0, correct + random:NextInteger(-spread, spread))
		if not used[candidate] then
			used[candidate] = true
			table.insert(choices, candidate)
		end
	end

	shuffle(choices)
	local correctIndex = 1
	local display = {}
	for index, value in ipairs(choices) do
		display[index] = tostring(value)
		if value == correct then
			correctIndex = index
		end
	end
	return display, correctIndex
end

local function makeQuestion(promptText, correct, spread)
	local options, correctIndex = buildNumberChoices(correct, spread)
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
		return makeQuestion("WHICH IS LARGER: " .. tostring(a) .. " OR " .. tostring(b) .. "?", math.max(a, b), 12)
	else
		local start = random:NextInteger(1, 12)
		local step = random:NextInteger(1, 5)
		local correct = start + step * 3
		return makeQuestion(
			"NEXT: " .. tostring(start) .. ", " .. tostring(start + step) .. ", " .. tostring(start + step * 2) .. ", ?",
			correct,
			8
		)
	end
end

local function buildNormalQuestion()
	local questionType = random:NextInteger(1, 6)
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
		local correct = start + step * 3
		return makeQuestion(
			"NEXT: " .. tostring(start) .. ", " .. tostring(start + step) .. ", " .. tostring(start + step * 2) .. ", ?",
			correct,
			10
		)
	elseif questionType == 5 then
		local start = random:NextInteger(1, 6)
		return makeQuestion(
			"NEXT: " .. tostring(start) .. ", " .. tostring(start * 2) .. ", " .. tostring(start * 4) .. ", ?",
			start * 8,
			18
		)
	else
		local a = random:NextInteger(10, 70)
		local b = random:NextInteger(10, 70)
		while b == a do
			b = random:NextInteger(10, 70)
		end
		return makeQuestion("WHICH IS LARGER: " .. tostring(a) .. " OR " .. tostring(b) .. "?", math.max(a, b), 15)
	end
end

local function buildHardQuestion()
	local questionType = random:NextInteger(1, 6)
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
		local dividend = divisor * quotient
		return makeQuestion(tostring(dividend) .. " ÷ " .. tostring(divisor) .. " = ?", quotient, 8)
	elseif questionType == 5 then
		local a = random:NextInteger(4, 12)
		local b = random:NextInteger(4, 12)
		local c = random:NextInteger(5, 30)
		return makeQuestion(tostring(a) .. " × " .. tostring(b) .. " + " .. tostring(c) .. " = ?", a * b + c, 28)
	else
		local start = random:NextInteger(10, 35)
		local step = random:NextInteger(9, 18)
		local correct = start + step * 3
		return makeQuestion(
			"NEXT: " .. tostring(start) .. ", " .. tostring(start + step) .. ", " .. tostring(start + step * 2) .. ", ?",
			correct,
			20
		)
	end
end

local function buildQuestion(difficultyName)
	if difficultyName == "Easy" then
		return buildEasyQuestion()
	end
	if difficultyName == "Hard" then
		return buildHardQuestion()
	end
	return buildNormalQuestion()
end

local function prepareQuestion(player, state)
	state.Question = buildQuestion(state.Difficulty)
	state.QuestionId += 1
	state.AutoMoving = false
	state.AutoMoveQuestionId = 0
	state.AutoMoveAnswerIndex = 0
	state.AutoSolveDelay, state.AutoSolveChance, state.AutoSolveGuaranteed, state.CurrentIQ = getAutoProfile(player)
	state.AutoSolveAt = math.min(state.EndsAt, Workspace:GetServerTimeNow() + state.AutoSolveDelay)
end

local function sendActiveState(player, state, feedback)
	if not player.Parent or not state.Active or not state.Question then
		return
	end
	local difficulty = getDifficultyConfig(state.Difficulty)
	BrainQuizState:FireClient(player, {
		Phase = "Active",
		Difficulty = difficulty.DisplayName,
		Prompt = state.Question.Prompt,
		Options = state.Question.Options,
		Score = state.Score,
		Goal = QUESTIONS_TO_FINISH,
		Attempts = state.Attempts,
		WinsEarned = state.WinsEarned,
		EndsAt = state.EndsAt,
		WrongPenalty = WRONG_ANSWER_PENALTY_SECONDS,
		Feedback = feedback,
		AutoSolveDelay = state.AutoSolveDelay,
		AutoSolveAt = state.AutoSolveAt,
		AutoSolveChance = state.AutoSolveChance,
		AutoSolveGuaranteed = state.AutoSolveGuaranteed,
		AutoSolveRequiredIQ = GUARANTEED_AUTO_IQ,
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
				if not player.Parent or not DataManager.IsLoaded(player) then
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
				print("[BrainQuizArena] SaveOK player=" .. player.Name .. " wins=" .. tostring(GameLogic.GetWins(player)))
			else
				warn("[BrainQuizArena] SaveFailed player=" .. player.Name .. " error=" .. tostring(lastError))
			end
		end
		saveState.Running = false
	end)
end

local function expireRun(player, state, reason)
	if not state.Active then
		return
	end
	local score = state.Score
	local winsEarned = state.WinsEarned
	local difficulty = getDifficultyConfig(state.Difficulty).DisplayName
	state.Token += 1
	resetActiveState(state)
	BrainQuizState:FireClient(player, {
		Phase = "Expired",
		Difficulty = difficulty,
		Score = score,
		Goal = QUESTIONS_TO_FINISH,
		WinsEarned = winsEarned,
		Message = reason or "TIME UP",
	})
	firePopup(
		player,
		"QUIZ ENDED",
		"Score " .. tostring(score) .. "/" .. tostring(QUESTIONS_TO_FINISH) .. " · +" .. tostring(winsEarned) .. " Wins kept"
	)
	print(
		"[BrainQuizArena] Expired player=" .. player.Name
			.. " difficulty=" .. difficulty
			.. " score=" .. tostring(score)
			.. " winsEarned=" .. tostring(winsEarned)
	)
end

local function completeRun(player, state)
	local attempts = state.Attempts
	local autoSolvedCount = state.AutoSolvedCount
	local winsEarned = state.WinsEarned
	local difficulty = getDifficultyConfig(state.Difficulty).DisplayName
	local timeLimit = getDifficultyConfig(state.Difficulty).TimeLimit
	local elapsed = math.max(0, timeLimit - math.max(0, state.EndsAt - Workspace:GetServerTimeNow()))

	state.Token += 1
	resetActiveState(state)
	state.CooldownUntil = Workspace:GetServerTimeNow() + COMPLETION_COOLDOWN_SECONDS
	BrainQuizState:FireClient(player, {
		Phase = "Complete",
		Difficulty = difficulty,
		WinsEarned = winsEarned,
		Attempts = attempts,
		AutoSolvedCount = autoSolvedCount,
		Elapsed = elapsed,
		CooldownUntil = state.CooldownUntil,
	})
	firePopup(player, "QUIZ COMPLETE!", "+" .. tostring(winsEarned) .. " Wins · " .. string.format("%.1fs", elapsed))
	queueWinsSave(player)
	print(
		"[BrainQuizArena] Complete player=" .. player.Name
			.. " difficulty=" .. difficulty
			.. " attempts=" .. tostring(attempts)
			.. " autoSolved=" .. tostring(autoSolvedCount)
			.. " winsEarned=" .. tostring(winsEarned)
			.. " totalWins=" .. tostring(GameLogic.GetWins(player))
	)
end

local function horizontalDistance(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function movePlayerToCorrectPad(player, state, correctIndex, runToken, questionId)
	local pad = answerPads[correctIndex]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not pad or not pad.Parent or not humanoid or not root or humanoid.Health <= 0 then
		warn("[BrainQuizArena] AutoMoveFailed player=" .. player.Name .. " reason=missing_character_or_pad")
		return
	end

	state.AutoMoving = true
	state.AutoMoveQuestionId = questionId
	state.AutoMoveAnswerIndex = correctIndex
	state.AutoSolveAt = nil
	sendActiveState(player, state, "AUTO FOUND ANSWER · MOVING")

	local targetPosition = Vector3.new(
		pad.Position.X,
		pad.Position.Y + pad.Size.Y * 0.5 + 2.8,
		pad.Position.Z
	)
	humanoid:MoveTo(targetPosition)

	task.spawn(function()
		local deadline = os.clock() + AUTO_MOVE_TIMEOUT
		while os.clock() < deadline do
			if not player.Parent or not state.Active or state.Token ~= runToken or state.QuestionId ~= questionId then
				return
			end
			character = player.Character
			root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			if horizontalDistance(root.Position, pad.Position) <= math.max(4, pad.Size.X * 0.3) then
				break
			end
			task.wait(0.1)
		end

		if not player.Parent or not state.Active or state.Token ~= runToken or state.QuestionId ~= questionId then
			return
		end

		character = player.Character
		root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root then
			return
		end
		if horizontalDistance(root.Position, pad.Position) > math.max(5, pad.Size.X * 0.35) then
			character:PivotTo(CFrame.new(targetPosition))
		end

		task.wait(0.15)
		if state.Active and state.Token == runToken and state.QuestionId == questionId then
			answerQuestion(player, correctIndex, true)
		end
	end)
end

scheduleAutoAttempt = function(player, state)
	if not state.Active or not state.Question or not state.AutoSolveAt then
		return
	end
	local runToken = state.Token
	local questionId = state.QuestionId
	local correctIndex = state.Question.CorrectIndex
	local delaySeconds = math.max(0, state.AutoSolveAt - Workspace:GetServerTimeNow())

	task.delay(delaySeconds, function()
		if not player.Parent or not state.Active or state.AutoMoving then
			return
		end
		if state.Token ~= runToken or state.QuestionId ~= questionId then
			return
		end
		if Workspace:GetServerTimeNow() >= state.EndsAt then
			return
		end

		local succeeded = state.AutoSolveGuaranteed or random:NextNumber() <= state.AutoSolveChance
		print(
			"[BrainQuizArena] AutoAttempt player=" .. player.Name
				.. " IQ=" .. tostring(state.CurrentIQ)
				.. " chance=" .. string.format("%.2f", state.AutoSolveChance)
				.. " guaranteed=" .. tostring(state.AutoSolveGuaranteed)
				.. " success=" .. tostring(succeeded)
		)

		if succeeded then
			movePlayerToCorrectPad(player, state, correctIndex, runToken, questionId)
			return
		end

		state.AutoSolveAt = math.min(state.EndsAt, Workspace:GetServerTimeNow() + state.AutoSolveDelay)
		sendActiveState(player, state, "AUTO MISSED · RETRYING")
		scheduleAutoAttempt(player, state)
	end)
end

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
		firePopup(player, "QUIZ ACTIVE", "Difficulty can be changed before the next run")
		return
	end
	state.Difficulty = difficultyName
	BrainQuizState:FireClient(player, {
		Phase = "Difficulty",
		Difficulty = config.DisplayName,
		TimeLimit = config.TimeLimit,
	})
	firePopup(player, "DIFFICULTY: " .. config.DisplayName, tostring(config.TimeLimit) .. " seconds")
	print("[BrainQuizArena] Difficulty player=" .. player.Name .. " selected=" .. config.DisplayName)
end

local function startRun(player)
	if not DataManager.IsLoaded(player) then
		firePopup(player, "PLEASE WAIT", "Data is still loading")
		return
	end
	if not GameLogic.IsAlive(player) then
		return
	end

	local state = getState(player)
	local now = Workspace:GetServerTimeNow()
	if state.Active then
		firePopup(player, "QUIZ ACTIVE", "Auto is running; move manually to answer faster")
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

	local chancePercent = math.floor(state.AutoSolveChance * 100 + 0.5)
	local feedback = state.AutoSolveGuaranteed
		and ("AUTO 100% · MOVES IN " .. tostring(state.AutoSolveDelay) .. "s")
		or ("AUTO " .. tostring(chancePercent) .. "% · MANUAL IS FASTER")
	sendActiveState(player, state, feedback)
	scheduleAutoAttempt(player, state)
	firePopup(player, "BRAIN QUIZ · " .. difficulty.DisplayName, "Auto is active · manual movement is optional")
	print(
		"[BrainQuizArena] Start player=" .. player.Name
			.. " difficulty=" .. difficulty.DisplayName
			.. " IQ=" .. tostring(state.CurrentIQ)
			.. " autoChance=" .. string.format("%.2f", state.AutoSolveChance)
			.. " guaranteed=" .. tostring(state.AutoSolveGuaranteed)
			.. " autoDelay=" .. tostring(state.AutoSolveDelay)
	)

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

answerQuestion = function(player, answerIndex, autoSolved)
	local state = getState(player)
	local now = Workspace:GetServerTimeNow()
	if not state.Active or not state.Question then
		if autoSolved ~= true then
			firePopup(player, "BRAIN QUIZ", "Step on the green START pad first")
		end
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
	state.AutoMoving = false
	state.AutoMoveQuestionId = 0
	state.AutoMoveAnswerIndex = 0
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

	print(
		"[BrainQuizArena] Answer player=" .. player.Name
			.. " difficulty=" .. getDifficultyConfig(state.Difficulty).DisplayName
			.. " correct=" .. tostring(isCorrect)
			.. " auto=" .. tostring(autoSolved == true)
			.. " score=" .. tostring(state.Score)
			.. " winsEarned=" .. tostring(state.WinsEarned)
			.. " totalWins=" .. tostring(GameLogic.GetWins(player))
	)

	if state.Score >= QUESTIONS_TO_FINISH then
		completeRun(player, state)
		return
	end
	if Workspace:GetServerTimeNow() >= state.EndsAt then
		expireRun(player, state, "WRONG ANSWER · TIME UP")
		return
	end

	prepareQuestion(player, state)
	local feedback
	if autoSolved == true then
		feedback = "+1 WIN · AUTO MOVED"
	else
		feedback = isCorrect and "+1 WIN · MANUAL" or ("WRONG · -" .. tostring(WRONG_ANSWER_PENALTY_SECONDS) .. "s")
	end
	sendActiveState(player, state, feedback)
	scheduleAutoAttempt(player, state)
end

local function createPart(parent, name, size, position, color, material, canTouch)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.Position = position
	item.Anchored = true
	item.CanCollide = true
	item.CanTouch = canTouch == true
	item.CanQuery = true
	item.Material = material or Enum.Material.SmoothPlastic
	item.Color = color
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function addText(part, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = face.Name .. "Text"
	gui.Face = face
	gui.LightInfluence = 0.05
	gui.PixelsPerStud = 75
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor or COLORS.BoardText
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
end

local function addTopLabel(part, text)
	addText(part, Enum.NormalId.Top, text, Color3.fromRGB(255, 255, 255))
end

local function removeLegacyActivities(map)
	for _, name in ipairs({ "KnowledgeSprint", "BrainQuizArena", "WinPad_Plaza", "WinPad_Plaza_Sign" }) do
		local item = map:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
end

local function installArena(map)
	if installedMap == map or not map or map.Parent ~= Workspace then
		return
	end
	if Workspace:FindFirstChild("SimpleMap") ~= map then
		return
	end

	removeLegacyActivities(map)
	table.clear(answerPads)
	local scale = tonumber(map:GetAttribute("WorldScale")) or 2.5
	local center = Vector3.new(48 * scale, 0, -34 * scale)

	local arena = Instance.new("Model")
	arena.Name = ARENA_NAME
	arena:SetAttribute("QuestionsToFinish", QUESTIONS_TO_FINISH)
	arena:SetAttribute("WinPerCorrect", WIN_PER_CORRECT)
	arena:SetAttribute("DefaultDifficulty", "Normal")
	arena:SetAttribute("AutoGuaranteedIQ", GUARANTEED_AUTO_IQ)
	arena:SetAttribute("LowIQMinChance", LOW_IQ_MIN_CHANCE)
	arena:SetAttribute("LowIQMaxChance", LOW_IQ_MAX_CHANCE)
	arena.Parent = map

	local platform = createPart(
		arena,
		"ArenaPlatform",
		Vector3.new(38 * scale, 1, 38 * scale),
		center + Vector3.new(0, 0.5, 0),
		COLORS.Platform,
		Enum.Material.Concrete,
		false
	)
	platform.CanTouch = false

	local trim = createPart(
		arena,
		"ArenaTrim",
		Vector3.new(39 * scale, 0.3, 39 * scale),
		center + Vector3.new(0, 1.05, 0),
		COLORS.PlatformTrim,
		Enum.Material.Neon,
		false
	)
	trim.CanCollide = false
	trim.CanTouch = false

	local padSize = Vector3.new(7 * scale, 0.8, 7 * scale)
	local padY = 1.55
	local answerOffsets = { -10 * scale, 0, 10 * scale }
	local answerColors = { COLORS.A, COLORS.B, COLORS.C }
	local answerNames = { "A", "B", "C" }

	for index = 1, 3 do
		local pad = createPart(
			arena,
			"AnswerPad_" .. answerNames[index],
			padSize,
			Vector3.new(center.X + answerOffsets[index], padY, center.Z + 3 * scale),
			answerColors[index],
			Enum.Material.Neon,
			true
		)
		answerPads[index] = pad
		addTopLabel(pad, answerNames[index])
		pad.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			if player then
				local state = getState(player)
				local autoMoved = state.Active
					and state.AutoMoving
					and state.AutoMoveQuestionId == state.QuestionId
					and state.AutoMoveAnswerIndex == index
				answerQuestion(player, index, autoMoved)
			end
		end)
	end

	local startPad = createPart(
		arena,
		"QuizStartPad",
		Vector3.new(12 * scale, 0.8, 5 * scale),
		Vector3.new(center.X, padY, center.Z - 5 * scale),
		COLORS.Start,
		Enum.Material.Neon,
		true
	)
	addTopLabel(startPad, "START\nAUTO ON")
	startPad.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if player then
			startRun(player)
		end
	end)

	local difficultyXOffsets = { -10 * scale, 0, 10 * scale }
	for index, difficultyName in ipairs(DIFFICULTY_ORDER) do
		local config = DIFFICULTIES[difficultyName]
		local pad = createPart(
			arena,
			"DifficultyPad_" .. difficultyName,
			Vector3.new(6 * scale, 0.65, 4.5 * scale),
			Vector3.new(center.X + difficultyXOffsets[index], 1.48, center.Z - 13 * scale),
			COLORS[difficultyName],
			Enum.Material.Neon,
			true
		)
		addTopLabel(pad, config.DisplayName .. "\n" .. tostring(config.TimeLimit) .. "s")
		pad.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			if player then
				selectDifficulty(player, difficultyName)
			end
		end)
	end

	local boardPosition = Vector3.new(center.X, 11.5, center.Z + 16 * scale)
	local board = createPart(
		arena,
		"QuizRulesBoard",
		Vector3.new(31 * scale, 14, 1.4),
		boardPosition,
		COLORS.Board,
		Enum.Material.SmoothPlastic,
		false
	)
	board.CanCollide = false
	board.CanQuery = false
	addText(
		board,
		Enum.NormalId.Front,
		"BRAIN QUIZ ARENA\nAUTO IS DEFAULT\nIQ 500+ = 100%\nLOW IQ = CHANCE\nEVERY CORRECT = +1 WIN",
		COLORS.BoardText
	)
	addText(
		board,
		Enum.NormalId.Back,
		"CHOOSE DIFFICULTY\nSTEP ON START\nAUTO MOVES TO ANSWER\nMANUAL PLAY IS OPTIONAL",
		COLORS.BoardText
	)

	for _, xOffset in ipairs({ -14 * scale, 14 * scale }) do
		local post = createPart(
			arena,
			"BoardPost_" .. tostring(xOffset),
			Vector3.new(1.2, 20, 1.2),
			Vector3.new(center.X + xOffset, 5, boardPosition.Z),
			COLORS.Post,
			Enum.Material.Wood,
			false
		)
		post.CanCollide = false
		post.CanQuery = false
	end

	installedMap = map
	map:SetAttribute("BrainQuizArenaInstalled", true)
	print(
		"[BrainQuizArena] Installed goal=5 winPerCorrect=1 autoDefault=true guaranteedIQ=500"
			.. " lowChance=15-90 movement=HumanoidMoveTo difficulties=Easy75/Normal60/Hard45"
	)
end

local function scheduleInstall(map)
	if not map or map.Name ~= "SimpleMap" then
		return
	end
	task.spawn(function()
		task.wait(0.9)
		installArena(map)
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "SimpleMap" then
		scheduleInstall(child)
	end
end)

local existingMap = Workspace:FindFirstChild("SimpleMap")
if existingMap then
	scheduleInstall(existingMap)
end

local function bindPlayer(player)
	player.CharacterAdded:Connect(function()
		local state = states[player.UserId]
		if state and state.Active then
			state.Token += 1
			resetActiveState(state)
			BrainQuizState:FireClient(player, { Phase = "Cancelled" })
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
	difficultyTouchAt[player.UserId] = nil
end)
