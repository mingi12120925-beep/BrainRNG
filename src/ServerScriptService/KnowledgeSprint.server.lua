-- ServerScriptService/KnowledgeSprint.server.lua
-- Early-game movement activity: Start -> Quest -> Chest -> School -> Finish.
-- Uses only physical pads, fixed SurfaceGui signs, and the existing ScreenGui popup remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameLogic = require(ServerScriptService:WaitForChild("GameLogic"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PopupEvent = remotes:WaitForChild("PopupEvent")
local UpdateStats = remotes:WaitForChild("UpdateStats")

local COURSE_NAME = "KnowledgeSprint"
local TIME_LIMIT_SECONDS = 75
local COMPLETION_COOLDOWN_SECONDS = 45
local REWARD_WINS = 2
local TOUCH_DEBOUNCE_SECONDS = 1.25

local COLORS = {
	Start = Color3.fromRGB(70, 190, 255),
	Checkpoint = Color3.fromRGB(255, 210, 65),
	Finish = Color3.fromRGB(255, 170, 45),
	Board = Color3.fromRGB(35, 48, 68),
	Text = Color3.fromRGB(255, 255, 255),
}

local states = {}
local touchDebounces = {}
local installedMap = nil

local function getState(player)
	local state = states[player.UserId]
	if not state then
		state = {
			Active = false,
			NextCheckpoint = 1,
			StartedAt = 0,
			CooldownUntil = 0,
		}
		states[player.UserId] = state
	end
	return state
end

local function resetRun(state)
	state.Active = false
	state.NextCheckpoint = 1
	state.StartedAt = 0
end

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

local function canProcessTouch(part, player)
	local byPlayer = touchDebounces[part]
	if not byPlayer then
		byPlayer = {}
		touchDebounces[part] = byPlayer
	end

	local now = os.clock()
	local lastAt = tonumber(byPlayer[player.UserId]) or 0
	if now - lastAt < TOUCH_DEBOUNCE_SECONDS then
		return false
	end

	byPlayer[player.UserId] = now
	return true
end

local function horizontalWorldPosition(scale, localPosition)
	return Vector3.new(localPosition.X * scale, localPosition.Y, localPosition.Z * scale)
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

local function addSurfaceText(board, text)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "SurfaceGui"
		gui.Face = face
		gui.LightInfluence = 0.1
		gui.PixelsPerStud = 60
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = text
		label.TextColor3 = COLORS.Text
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0.45
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui
	end
end

local function createFixedSign(parent, name, position, text, accentColor)
	local post = createPart(
		parent,
		name .. "_Post",
		Vector3.new(1.2, 8, 1.2),
		position + Vector3.new(0, 4, 0),
		Color3.fromRGB(95, 75, 55),
		Enum.Material.Wood,
		false
	)
	post.CanQuery = false

	local board = createPart(
		parent,
		name .. "_Board",
		Vector3.new(20, 7, 1.1),
		position + Vector3.new(0, 10, 0),
		COLORS.Board,
		Enum.Material.SmoothPlastic,
		false
	)
	board.CanQuery = false

	local trim = createPart(
		parent,
		name .. "_Trim",
		Vector3.new(21, 8, 0.35),
		position + Vector3.new(0, 10, 0.72),
		accentColor,
		Enum.Material.Neon,
		false
	)
	trim.CanCollide = false
	trim.CanQuery = false

	addSurfaceText(board, text)
end

local function saveWins(player)
	task.spawn(function()
		local success, result = pcall(function()
			return DataManager.SaveProfile(player, false, {
				Reason = "KnowledgeSprintWin",
			})
		end)

		if success and result then
			print("[KnowledgeSprint] SaveOK player=" .. player.Name .. " wins=" .. tostring(GameLogic.GetWins(player)))
		else
			warn("[KnowledgeSprint] SaveFailed player=" .. player.Name .. " error=" .. tostring(result))
		end
	end)
end

local function validateActiveRun(player, state)
	if not state.Active then
		firePopup(player, "KNOWLEDGE SPRINT", "Step on the blue START pad first")
		return false
	end

	local elapsed = os.clock() - state.StartedAt
	if elapsed > TIME_LIMIT_SECONDS then
		resetRun(state)
		firePopup(player, "SPRINT EXPIRED", "Step on START to retry")
		print("[KnowledgeSprint] Expired player=" .. player.Name .. " elapsed=" .. string.format("%.2f", elapsed))
		return false
	end

	return true
end

local function connectStartPad(startPad)
	startPad.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player or not canProcessTouch(startPad, player) then
			return
		end

		if not DataManager.IsLoaded(player) then
			firePopup(player, "PLEASE WAIT", "Data is still loading")
			return
		end

		if not GameLogic.IsAlive(player) then
			return
		end

		local state = getState(player)
		local now = os.clock()
		if now < state.CooldownUntil then
			local remaining = math.max(1, math.ceil(state.CooldownUntil - now))
			firePopup(player, "SPRINT COOLDOWN", "Ready in " .. tostring(remaining) .. "s")
			return
		end

		state.Active = true
		state.NextCheckpoint = 1
		state.StartedAt = now
		firePopup(player, "KNOWLEDGE SPRINT", "QUEST → CHEST → SCHOOL → FINISH")
		print("[KnowledgeSprint] Start player=" .. player.Name)
	end)
end

local function connectCheckpoint(checkpointPart, checkpointIndex, checkpointName)
	checkpointPart.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player or not canProcessTouch(checkpointPart, player) then
			return
		end

		local state = getState(player)
		if not validateActiveRun(player, state) then
			return
		end

		if state.NextCheckpoint ~= checkpointIndex then
			firePopup(player, "WRONG CHECKPOINT", "Find checkpoint " .. tostring(state.NextCheckpoint) .. " first")
			return
		end

		state.NextCheckpoint += 1
		firePopup(player, "SPRINT " .. tostring(checkpointIndex) .. "/3", checkpointName .. " checkpoint cleared")
		print(
			"[KnowledgeSprint] Checkpoint player="
				.. player.Name
				.. " index="
				.. tostring(checkpointIndex)
				.. " elapsed="
				.. string.format("%.2f", os.clock() - state.StartedAt)
		)
	end)
end

local function connectFinishPad(finishPad)
	finishPad.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player or not canProcessTouch(finishPad, player) then
			return
		end

		if not DataManager.IsLoaded(player) then
			return
		end

		local state = getState(player)
		if not validateActiveRun(player, state) then
			return
		end

		if state.NextCheckpoint <= 3 then
			firePopup(player, "SPRINT INCOMPLETE", "Clear all 3 checkpoints first")
			return
		end

		local elapsed = os.clock() - state.StartedAt
		resetRun(state)
		state.CooldownUntil = os.clock() + COMPLETION_COOLDOWN_SECONDS

		GameLogic.AddWins(player, REWARD_WINS)
		UpdateStats:FireClient(player, {
			Wins = GameLogic.GetWins(player),
		})
		firePopup(player, "SPRINT COMPLETE", "+" .. tostring(REWARD_WINS) .. " Wins · " .. string.format("%.1fs", elapsed))
		saveWins(player)

		print(
			"[KnowledgeSprint] Complete player="
				.. player.Name
				.. " elapsed="
				.. string.format("%.2f", elapsed)
				.. " rewardWins="
				.. tostring(REWARD_WINS)
				.. " totalWins="
				.. tostring(GameLogic.GetWins(player))
		)
	end)
end

local function removeLegacyWinPad(map)
	for _, name in ipairs({ "WinPad_Plaza", "WinPad_Plaza_Sign" }) do
		local item = map:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
end

local function installCourse(map)
	if installedMap == map or not map or map.Parent ~= Workspace then
		return
	end

	if Workspace:FindFirstChild("SimpleMap") ~= map then
		return
	end

	if map:FindFirstChild(COURSE_NAME) then
		installedMap = map
		return
	end

	removeLegacyWinPad(map)

	local scale = tonumber(map:GetAttribute("WorldScale")) or 2.5
	local model = Instance.new("Model")
	model.Name = COURSE_NAME
	model:SetAttribute("TimeLimitSeconds", TIME_LIMIT_SECONDS)
	model:SetAttribute("CooldownSeconds", COMPLETION_COOLDOWN_SECONDS)
	model:SetAttribute("RewardWins", REWARD_WINS)
	model.Parent = map

	local padSize = Vector3.new(12 * scale, 0.8, 12 * scale)
	local y = 1.45

	local startPosition = horizontalWorldPosition(scale, Vector3.new(-22, y, 34))
	local questPosition = horizontalWorldPosition(scale, Vector3.new(-64, y, 0))
	local chestPosition = horizontalWorldPosition(scale, Vector3.new(64, y, 0))
	local schoolPosition = horizontalWorldPosition(scale, Vector3.new(0, y, 58))
	local finishPosition = horizontalWorldPosition(scale, Vector3.new(22, y, 34))

	local startPad = createPart(model, "SprintStartPad", padSize, startPosition, COLORS.Start, Enum.Material.Neon, true)
	local checkpointQuest = createPart(model, "SprintCheckpoint1_Quest", padSize, questPosition, COLORS.Checkpoint, Enum.Material.Neon, true)
	local checkpointChest = createPart(model, "SprintCheckpoint2_Chest", padSize, chestPosition, COLORS.Checkpoint, Enum.Material.Neon, true)
	local checkpointSchool = createPart(model, "SprintCheckpoint3_School", padSize, schoolPosition, COLORS.Checkpoint, Enum.Material.Neon, true)
	local finishPad = createPart(model, "SprintFinishPad", padSize, finishPosition, COLORS.Finish, Enum.Material.Neon, true)

	createFixedSign(model, "SprintStartSign", startPosition + Vector3.new(0, 0, -10 * scale), "KNOWLEDGE SPRINT\nSTART", COLORS.Start)
	createFixedSign(model, "SprintQuestSign", questPosition + Vector3.new(0, 0, -9 * scale), "1 · QUEST", COLORS.Checkpoint)
	createFixedSign(model, "SprintChestSign", chestPosition + Vector3.new(0, 0, -9 * scale), "2 · CHEST", COLORS.Checkpoint)
	createFixedSign(model, "SprintSchoolSign", schoolPosition + Vector3.new(0, 0, -9 * scale), "3 · SCHOOL", COLORS.Checkpoint)
	createFixedSign(model, "SprintFinishSign", finishPosition + Vector3.new(0, 0, -10 * scale), "FINISH\n+2 WINS", COLORS.Finish)

	connectStartPad(startPad)
	connectCheckpoint(checkpointQuest, 1, "Quest")
	connectCheckpoint(checkpointChest, 2, "Chest")
	connectCheckpoint(checkpointSchool, 3, "School")
	connectFinishPad(finishPad)

	installedMap = map
	map:SetAttribute("KnowledgeSprintInstalled", true)
	print(
		"[KnowledgeSprint] Installed timeLimit="
			.. tostring(TIME_LIMIT_SECONDS)
			.. " cooldown="
			.. tostring(COMPLETION_COOLDOWN_SECONDS)
			.. " rewardWins="
			.. tostring(REWARD_WINS)
	)
end

local function scheduleInstall(map)
	if not map or map.Name ~= "SimpleMap" then
		return
	end

	task.spawn(function()
		task.wait(0.75)
		installCourse(map)
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

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local state = states[player.UserId]
		if state then
			resetRun(state)
		end
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		local state = states[player.UserId]
		if state then
			resetRun(state)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	states[player.UserId] = nil
end)
