-- ServerScriptService/BrainQuizArena.server.lua
-- Early-game activity: answer five randomized questions by stepping on A/B/C pads.

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
local QUESTIONS_TO_WIN = 5
local TIME_LIMIT_SECONDS = 60
local WRONG_ANSWER_PENALTY_SECONDS = 5
local COMPLETION_COOLDOWN_SECONDS = 60
local NORMAL_REWARD_WINS = 2
local PERFECT_REWARD_WINS = 3
local ANSWER_DEBOUNCE_SECONDS = 0.65

local COLORS = {
	Platform = Color3.fromRGB(225, 232, 242),
	PlatformTrim = Color3.fromRGB(75, 111, 170),
	Start = Color3.fromRGB(62, 202, 118),
	A = Color3.fromRGB(255, 100, 110),
	B = Color3.fromRGB(70, 165, 255),
	C = Color3.fromRGB(255, 205, 70),
	Board = Color3.fromRGB(31, 43, 65),
	BoardText = Color3.fromRGB(255, 255, 255),
	Post = Color3.fromRGB(92, 72, 52),
}

local random = Random.new()
local states = {}
local installedMap = nil

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
			Score = 0,
			Attempts = 0,
			EndsAt = 0,
			CooldownUntil = 0,
			Question = nil,
			Token = 0,
			LastAnswerAt = 0,
		}
		states[player.UserId] = state
	end
	return state
end

local function resetActiveState(state)
	state.Active = false
	state.Score = 0
	state.Attempts = 0
	state.EndsAt = 0
	state.Question = nil
	state.LastAnswerAt = 0
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
		local candidate = correct + random:NextInteger(-spread, spread)
		candidate = math.max(0, candidate)
		if not used[candidate] then
			used[candidate] = true
			table.insert(choices, candidate)
		end
	end

	shuffle(choices)
	local correctIndex = 1
	for index, value in ipairs(choices) do
		if value == correct then
			correctIndex = index
			break
		end
	end

	local display = {}
	for index, value in ipairs(choices) do
		display[index] = tostring(value)
	end

	return display, correctIndex
end

local function buildQuestion()
	local questionType = random:NextInteger(1, 6)
	local promptText
	local correct
	local spread = 10

	if questionType == 1 then
		local a = random:NextInteger(6, 35)
		local b = random:NextInteger(4, 28)
		correct = a + b
		promptText = tostring(a) .. " + " .. tostring(b) .. " = ?"
		spread = 14
	elseif questionType == 2 then
		local a = random:NextInteger(20, 60)
		local b = random:NextInteger(4, a - 3)
		correct = a - b
		promptText = tostring(a) .. " - " .. tostring(b) .. " = ?"
		spread = 12
	elseif questionType == 3 then
		local a = random:NextInteger(2, 12)
		local b = random:NextInteger(2, 12)
		correct = a * b
		promptText = tostring(a) .. " × " .. tostring(b) .. " = ?"
		spread = 18
	elseif questionType == 4 then
		local start = random:NextInteger(2, 18)
		local step = random:NextInteger(2, 8)
		correct = start + (step * 3)
		promptText = "NEXT: " .. tostring(start) .. ", " .. tostring(start + step) .. ", " .. tostring(start + step * 2) .. ", ?"
		spread = 10
	elseif questionType == 5 then
		local start = random:NextInteger(1, 6)
		correct = start * 8
		promptText = "NEXT: " .. tostring(start) .. ", " .. tostring(start * 2) .. ", " .. tostring(start * 4) .. ", ?"
		spread = 18
	else
		local a = random:NextInteger(10, 70)
		local b = random:NextInteger(10, 70)
		while b == a do
			b = random:NextInteger(10, 70)
		end
		correct = math.max(a, b)
		promptText = "WHICH IS LARGER: " .. tostring(a) .. " OR " .. tostring(b) .. "?"
		spread = 15
	end

	local options, correctIndex = buildNumberChoices(correct, spread)
	return {
		Prompt = promptText,
		Options = options,
		CorrectIndex = correctIndex,
	}
end

local function firePopup(player, title, subtitle)
	PopupEvent:FireClient(player, tostring(title) .. "|" .. tostring(subtitle), "Info")
end

local function sendActiveState(player, state, feedback)
	if not player.Parent or not state.Active or not state.Question then
		return
	end

	BrainQuizState:FireClient(player, {
		Phase = "Active",
		Prompt = state.Question.Prompt,
		Options = state.Question.Options,
		Score = state.Score,
		Goal = QUESTIONS_TO_WIN,
		Attempts = state.Attempts,
		EndsAt = state.EndsAt,
		WrongPenalty = WRONG_ANSWER_PENALTY_SECONDS,
		Feedback = feedback,
	})
end

local function saveWins(player)
	task.spawn(function()
		for attempt = 1, 2 do
			if not player.Parent or not DataManager.IsLoaded(player) then
				return
			end

			local ok, savedOrError = pcall(function()
				return DataManager.SaveProfile(player, false, {
					Reason = "BrainQuizWin",
				})
			end)

			if ok and savedOrError then
				print("[BrainQuizArena] SaveOK player=" .. player.Name .. " wins=" .. tostring(GameLogic.GetWins(player)))
				return
			end

			if attempt == 1 then
				task.wait(1)
			else
				warn("[BrainQuizArena] SaveFailed player=" .. player.Name .. " error=" .. tostring(savedOrError))
			end
		end
	end)
end

local function expireRun(player, state, reason)
	if not state.Active then
		return
	end

	local score = state.Score
	resetActiveState(state)
	BrainQuizState:FireClient(player, {
		Phase = "Expired",
		Score = score,
		Goal = QUESTIONS_TO_WIN,
		Message = reason or "TIME UP",
	})
	firePopup(player, "QUIZ FAILED", "Score " .. tostring(score) .. "/" .. tostring(QUESTIONS_TO_WIN) .. " · Step on START to retry")
	print("[BrainQuizArena] Expired player=" .. player.Name .. " score=" .. tostring(score))
end

local function completeRun(player, state)
	local attempts = state.Attempts
	local perfect = attempts == QUESTIONS_TO_WIN
	local rewardWins = perfect and PERFECT_REWARD_WINS or NORMAL_REWARD_WINS
	local elapsed = math.max(0, TIME_LIMIT_SECONDS - math.max(0, state.EndsAt - Workspace:GetServerTimeNow()))

	resetActiveState(state)
	state.CooldownUntil = Workspace:GetServerTimeNow() + COMPLETION_COOLDOWN_SECONDS
	GameLogic.AddWins(player, rewardWins)

	UpdateStats:FireClient(player, {
		Wins = GameLogic.GetWins(player),
	})
	BrainQuizState:FireClient(player, {
		Phase = "Complete",
		RewardWins = rewardWins,
		Perfect = perfect,
		Attempts = attempts,
		Elapsed = elapsed,
		CooldownUntil = state.CooldownUntil,
	})
	firePopup(
		player,
		perfect and "PERFECT QUIZ!" or "QUIZ COMPLETE!",
		"+" .. tostring(rewardWins) .. " Wins · " .. string.format("%.1fs", elapsed)
	)
	saveWins(player)

	print(
		"[BrainQuizArena] Complete player="
			.. player.Name
			.. " attempts="
			.. tostring(attempts)
			.. " rewardWins="
			.. tostring(rewardWins)
			.. " totalWins="
			.. tostring(GameLogic.GetWins(player))
	)
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
		firePopup(player, "QUIZ ACTIVE", "Answer the current question on A, B, or C")
		return
	end
	if now < state.CooldownUntil then
		local remaining = math.max(1, math.ceil(state.CooldownUntil - now))
		firePopup(player, "QUIZ COOLDOWN", "Ready in " .. tostring(remaining) .. "s")
		return
	end

	state.Token += 1
	state.Active = true
	state.Score = 0
	state.Attempts = 0
	state.EndsAt = now + TIME_LIMIT_SECONDS
	state.Question = buildQuestion()
	state.LastAnswerAt = 0
	local token = state.Token

	sendActiveState(player, state, "STEP ON A, B, OR C")
	firePopup(player, "BRAIN QUIZ START", "Get 5 correct answers before time runs out")
	print("[BrainQuizArena] Start player=" .. player.Name)

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

local function answerQuestion(player, answerIndex)
	local state = getState(player)
	local now = Workspace:GetServerTimeNow()

	if not state.Active or not state.Question then
		firePopup(player, "BRAIN QUIZ", "Step on the green START pad first")
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
	state.Attempts += 1

	local isCorrect = answerIndex == state.Question.CorrectIndex
	if isCorrect then
		state.Score += 1
	else
		state.EndsAt -= WRONG_ANSWER_PENALTY_SECONDS
	end

	if state.Score >= QUESTIONS_TO_WIN then
		completeRun(player, state)
		return
	end
	if Workspace:GetServerTimeNow() >= state.EndsAt then
		expireRun(player, state, "WRONG ANSWER · TIME UP")
		return
	end

	state.Question = buildQuestion()
	sendActiveState(
		player,
		state,
		isCorrect and "CORRECT!" or ("WRONG · -" .. tostring(WRONG_ANSWER_PENALTY_SECONDS) .. "s")
	)

	print(
		"[BrainQuizArena] Answer player="
			.. player.Name
			.. " correct="
			.. tostring(isCorrect)
			.. " score="
			.. tostring(state.Score)
			.. " attempts="
			.. tostring(state.Attempts)
	)
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
	gui.PixelsPerStud = 55
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor or COLORS.BoardText
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.45
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
	local scale = tonumber(map:GetAttribute("WorldScale")) or 2.5
	local center = Vector3.new(48 * scale, 0, -38 * scale)

	local arena = Instance.new("Model")
	arena.Name = ARENA_NAME
	arena:SetAttribute("QuestionsToWin", QUESTIONS_TO_WIN)
	arena:SetAttribute("TimeLimitSeconds", TIME_LIMIT_SECONDS)
	arena:SetAttribute("NormalRewardWins", NORMAL_REWARD_WINS)
	arena:SetAttribute("PerfectRewardWins", PERFECT_REWARD_WINS)
	arena.Parent = map

	local platform = createPart(
		arena,
		"ArenaPlatform",
		Vector3.new(36 * scale, 1, 28 * scale),
		center + Vector3.new(0, 0.5, 0),
		COLORS.Platform,
		Enum.Material.Concrete,
		false
	)
	platform.CanTouch = false

	local trim = createPart(
		arena,
		"ArenaTrim",
		Vector3.new(37 * scale, 0.3, 29 * scale),
		center + Vector3.new(0, 1.05, 0),
		COLORS.PlatformTrim,
		Enum.Material.Neon,
		false
	)
	trim.CanCollide = false
	trim.CanTouch = false

	local padSize = Vector3.new(7 * scale, 0.8, 7 * scale)
	local padY = 1.55
	local answerZ = center.Z
	local answerOffsets = { -10 * scale, 0, 10 * scale }
	local answerColors = { COLORS.A, COLORS.B, COLORS.C }
	local answerNames = { "A", "B", "C" }

	for index = 1, 3 do
		local pad = createPart(
			arena,
			"AnswerPad_" .. answerNames[index],
			padSize,
			Vector3.new(center.X + answerOffsets[index], padY, answerZ),
			answerColors[index],
			Enum.Material.Neon,
			true
		)
		addTopLabel(pad, answerNames[index])
		pad.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			if player then
				answerQuestion(player, index)
			end
		end)
	end

	local startPad = createPart(
		arena,
		"QuizStartPad",
		Vector3.new(12 * scale, 0.8, 5.5 * scale),
		Vector3.new(center.X, padY, center.Z - 10 * scale),
		COLORS.Start,
		Enum.Material.Neon,
		true
	)
	addTopLabel(startPad, "START\n2-3 WINS")
	startPad.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if player then
			startRun(player)
		end
	end)

	local boardPosition = Vector3.new(center.X, 10.5, center.Z + 11 * scale)
	local board = createPart(
		arena,
		"QuizRulesBoard",
		Vector3.new(31 * scale, 12, 1.4),
		boardPosition,
		COLORS.Board,
		Enum.Material.SmoothPlastic,
		false
	)
	board.CanCollide = false
	board.CanQuery = false
	addText(board, Enum.NormalId.Front, "BRAIN QUIZ ARENA\n5 CORRECT = +2 WINS\nPERFECT = +3 WINS", COLORS.BoardText)
	addText(board, Enum.NormalId.Back, "BRAIN QUIZ ARENA\nSTEP ON START\nANSWER ON A / B / C", COLORS.BoardText)

	for _, xOffset in ipairs({ -14 * scale, 14 * scale }) do
		local post = createPart(
			arena,
			"BoardPost_" .. tostring(xOffset),
			Vector3.new(1.2, 18, 1.2),
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
		"[BrainQuizArena] Installed questions="
			.. tostring(QUESTIONS_TO_WIN)
			.. " timeLimit="
			.. tostring(TIME_LIMIT_SECONDS)
			.. " rewards="
			.. tostring(NORMAL_REWARD_WINS)
			.. "/"
			.. tostring(PERFECT_REWARD_WINS)
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
end)
