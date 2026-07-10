-- ServerScriptService/GameServer.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

if ServerScriptService:GetAttribute("BrainRNG_ServerRunning") then
	warn("[GameServer] Duplicate GameServer blocked.")
	return
end

ServerScriptService:SetAttribute("BrainRNG_ServerRunning", true)

print("[GameServer] ACTIVE SCRIPT:", script:GetFullName())

local GameLogic = require(ServerScriptService:WaitForChild("GameLogic"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local ConceptGenerator = require(ServerScriptService:WaitForChild("ConceptGenerator"))

DataManager.BindGameLogic(GameLogic)

local ENABLE_ADMIN_TEST_TOOLS = true
local SERVER_MIN_ROLL_COOLDOWN = 0.65
local ADMIN_SAVE_COOLDOWN = 10
local DIRTY_SAVE_INTERVAL = 45
local DIRTY_SAVE_RETRY_DELAY = 15
local BIND_TO_CLOSE_MAX_WAIT_SECONDS = 25

local TEST_ADMIN_USER_NAMES = {
	"ming861212",
}

local TEST_ADMIN_USER_IDS = {}

for _, userName in ipairs(TEST_ADMIN_USER_NAMES) do
	local success, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(userName)
	end)

	if success and userId then
		TEST_ADMIN_USER_IDS[userId] = true
		print("[AdminTest] Added admin:", userName, userId)
	else
		warn("[AdminTest] Failed to resolve admin username:", userName, userId)
	end
end

local function isTestAdmin(player)
	return TEST_ADMIN_USER_IDS[player.UserId] == true
end

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name)
	local remote = remotesFolder:FindFirstChild(name)

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder

	return remote
end

local RollRequest = getOrCreateRemoteEvent("RollRequest")
local UpgradeRequest = getOrCreateRemoteEvent("UpgradeRequest")
local AutoRollUpgradeRequest = getOrCreateRemoteEvent("AutoRollUpgradeRequest")
local AdminTestRequest = getOrCreateRemoteEvent("AdminTestRequest")
local QuestClaimRequest = getOrCreateRemoteEvent("QuestClaimRequest")
local ChestOpenRequest = getOrCreateRemoteEvent("ChestOpenRequest")
local NextAreaRequest = getOrCreateRemoteEvent("NextAreaRequest")
local ReturnToLobbyRequest = getOrCreateRemoteEvent("ReturnToLobbyRequest")
local UpdateStats = getOrCreateRemoteEvent("UpdateStats")
local PopupEvent = getOrCreateRemoteEvent("PopupEvent")

local rollDebounce = {}
local winPadDebounce = {}
local gateTouchDebounce = {}
local lastRollAtByUserId = {}
local brainSurgeStateByUserId = {}
local playerLoadStarted = {}
local adminSaveStates = {}
local playerQuestStates = {}
local playerChestStates = {}
local dirtySaveStates = {}
local chestOpenDebounce = {}
local nextAreaRequestLastAtByUserId = {}
local returnToLobbyLastAtByUserId = {}
local worldChestPromptConnection = nil
local worldChestConnectedPrompt = nil

local BRAIN_SURGE_TARGET = 10
local BRAIN_SURGE_MULTIPLIER = 2
local NEXT_AREA_REQUIRED_IQ = 10000
local NEXT_AREA_REQUEST_COOLDOWN = 1.0
local RETURN_TO_LOBBY_COOLDOWN = 1.0

local function getBrainSurgeState(player)
	local userId = player.UserId
	local state = brainSurgeStateByUserId[userId]

	if not state then
		state = {
			Count = 0,
			Target = BRAIN_SURGE_TARGET,
			Multiplier = BRAIN_SURGE_MULTIPLIER,
		}

		brainSurgeStateByUserId[userId] = state
	end

	return state
end

local function getBrainSurgeRollInfo(player)
	local state = getBrainSurgeState(player)
	local target = tonumber(state.Target) or BRAIN_SURGE_TARGET
	local nextCount = (tonumber(state.Count) or 0) + 1
	local isActive = nextCount >= target

	return state, {
		NextCount = nextCount,
		Active = isActive,
		Target = target,
		Multiplier = tonumber(state.Multiplier) or BRAIN_SURGE_MULTIPLIER,
	}
end

local function commitBrainSurgeRoll(state, rollInfo)
	if type(state) ~= "table" or type(rollInfo) ~= "table" then
		return
	end

	if rollInfo.Active then
		state.Count = 0
	else
		state.Count = math.clamp(tonumber(rollInfo.NextCount) or 0, 0, tonumber(state.Target) or BRAIN_SURGE_TARGET)
	end
end

local function getBrainSurgeStats(player)
	local state = getBrainSurgeState(player)
	local count = math.max(0, tonumber(state.Count) or 0)
	local target = math.max(1, tonumber(state.Target) or BRAIN_SURGE_TARGET)

	return {
		Progress = math.clamp(count, 0, target),
		Target = target,
		Ready = count >= target - 1,
		Multiplier = tonumber(state.Multiplier) or BRAIN_SURGE_MULTIPLIER,
	}
end

local BASIC_CHEST_COST = 25
local BASIC_CHEST_REWARDS = {
	{ Weight = 50, Type = "IQ", Amount = 500, Text = "+500 IQ" },
	{ Weight = 30, Type = "KP", Amount = 100, Text = "+100 KP" },
	{ Weight = 15, Type = "IQ", Amount = 1500, Text = "+1,500 IQ" },
	{ Weight = 5, Type = "KP", Amount = 500, Text = "+500 KP" },
}

local QUEST_DEFINITIONS = {
	{
		Id = "Roll_50",
		Title = "Roll 50 Times",
		Description = "Roll 50 times.",
		Goal = 50,
		Reward = { Type = "KP", Amount = 100 },
		RewardText = "+100 KP",
	},
	{
		Id = "GainIQ_1000",
		Title = "Gain 1,000 IQ",
		Description = "Gain 1,000 IQ from rolls.",
		Goal = 1000,
		Reward = { Type = "IQ", Amount = 1000 },
		RewardText = "+1,000 IQ",
	},
	{
		Id = "Discover_3",
		Title = "Discover 3 Concepts",
		Description = "Discover 3 new Concepts.",
		Goal = 3,
		Reward = { Type = "KP", Amount = 250 },
		RewardText = "+250 KP",
	},
}

local QUEST_DEFINITION_BY_ID = {}

for _, questDefinition in ipairs(QUEST_DEFINITIONS) do
	QUEST_DEFINITION_BY_ID[questDefinition.Id] = questDefinition
end

local function formatNumber(value)
	value = tonumber(value) or 0

	if value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	end

	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	end

	if value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local function displayRarity(rarity)
	rarity = tostring(rarity or "COMMON")
	local label = rarity:gsub("_", " ")
	return label
end

local function getQuestState(player)
	local userId = player.UserId
	local state = playerQuestStates[userId]

	if not state then
		state = {
			Quests = {},
		}

		playerQuestStates[userId] = state
	end

	for _, questDefinition in ipairs(QUEST_DEFINITIONS) do
		if not state.Quests[questDefinition.Id] then
			state.Quests[questDefinition.Id] = {
				Progress = 0,
				Goal = questDefinition.Goal,
				Completed = false,
				Claimed = false,
			}
		end
	end

	return state
end

local function getQuestPayload(player)
	local state = getQuestState(player)
	local quests = {}

	for _, questDefinition in ipairs(QUEST_DEFINITIONS) do
		local questState = state.Quests[questDefinition.Id]
		local progress = math.min(tonumber(questState.Progress) or 0, questDefinition.Goal)

		table.insert(quests, {
			Id = questDefinition.Id,
			Title = questDefinition.Title,
			Description = questDefinition.Description,
			Progress = progress,
			Goal = questDefinition.Goal,
			Completed = questState.Completed == true,
			Claimed = questState.Claimed == true,
			RewardText = questDefinition.RewardText,
		})
	end

	return quests
end

local function exportQuestState(player)
	local state = getQuestState(player)
	local exported = {
		Progress = {},
		Completed = {},
		Claimed = {},
	}

	for _, questDefinition in ipairs(QUEST_DEFINITIONS) do
		local questState = state.Quests[questDefinition.Id]
		exported.Progress[questDefinition.Id] = math.max(0, math.floor(tonumber(questState.Progress) or 0))
		exported.Completed[questDefinition.Id] = questState.Completed == true
		exported.Claimed[questDefinition.Id] = questState.Claimed == true
	end

	return exported
end

local function countDictionaryEntries(source)
	if type(source) ~= "table" then
		return 0
	end

	local count = 0
	for _ in pairs(source) do
		count += 1
	end

	return count
end

local function countTrueDictionaryEntries(source)
	if type(source) ~= "table" then
		return 0
	end

	local count = 0
	for _, value in pairs(source) do
		if value == true then
			count += 1
		end
	end

	return count
end

local function printSessionPersistenceAudit(player, label)
	local chestState = getChestState(player)
	local quests = exportQuestState(player)

	print("[PersistAudit] " .. tostring(label)
		.. " player=" .. player.Name
		.. " CP=" .. tostring(math.max(0, math.floor(tonumber(chestState.ChestPoints) or 0)))
		.. " TotalOpened=" .. tostring(math.max(0, math.floor(tonumber(chestState.TotalOpened) or 0)))
		.. " QuestProgressCount=" .. tostring(countDictionaryEntries(quests.Progress))
		.. " QuestCompletedCount=" .. tostring(countTrueDictionaryEntries(quests.Completed))
		.. " QuestClaimedCount=" .. tostring(countTrueDictionaryEntries(quests.Claimed)))
end

local function importQuestState(player, questsData)
	local userId = player.UserId
	local progressData = type(questsData) == "table" and type(questsData.Progress) == "table" and questsData.Progress or {}
	local completedData = type(questsData) == "table" and type(questsData.Completed) == "table" and questsData.Completed or {}
	local claimedData = type(questsData) == "table" and type(questsData.Claimed) == "table" and questsData.Claimed or {}
	local state = {
		Quests = {},
	}

	for _, questDefinition in ipairs(QUEST_DEFINITIONS) do
		local questId = questDefinition.Id
		local progress = math.clamp(math.floor(tonumber(progressData[questId]) or 0), 0, questDefinition.Goal)
		local claimed = claimedData[questId] == true
		local completed = completedData[questId] == true or claimed or progress >= questDefinition.Goal

		state.Quests[questId] = {
			Progress = progress,
			Goal = questDefinition.Goal,
			Completed = completed,
			Claimed = claimed,
		}
	end

	playerQuestStates[userId] = state
end

local function getChestState(player)
	local userId = player.UserId
	local state = playerChestStates[userId]

	if not state then
		state = {
			ChestPoints = 0,
			TotalOpened = 0,
		}

		playerChestStates[userId] = state
	end

	return state
end

local function importChestState(player, data)
	playerChestStates[player.UserId] = {
		ChestPoints = math.max(0, math.floor(tonumber(data and data.ChestPoints) or 0)),
		TotalOpened = math.max(0, math.floor(tonumber(data and data.ChestTotalOpened) or 0)),
	}
end

local function resetPersistentSessionState(player)
	playerChestStates[player.UserId] = {
		ChestPoints = 0,
		TotalOpened = 0,
	}

	importQuestState(player, {
		Progress = {},
		Completed = {},
		Claimed = {},
	})
end

local function addChestPoints(player, amount)
	local state = getChestState(player)
	state.ChestPoints = math.max(0, math.floor((tonumber(state.ChestPoints) or 0) + (tonumber(amount) or 0)))
	return state.ChestPoints
end

GameLogic.BindSessionPersistence({
	ExportPlayerData = function(player)
		local chestState = getChestState(player)

		return {
			ChestPoints = math.max(0, math.floor(tonumber(chestState.ChestPoints) or 0)),
			ChestTotalOpened = math.max(0, math.floor(tonumber(chestState.TotalOpened) or 0)),
			Quests = exportQuestState(player),
		}
	end,

	ImportPlayerData = function(player, data)
		importChestState(player, data)
		importQuestState(player, data and data.Quests)
		printSessionPersistenceAudit(player, "ImportSession")
	end,

	ResetPlayerData = function(player)
		resetPersistentSessionState(player)
	end,
})

local function getChestPayload(player)
	local state = getChestState(player)
	local points = math.max(0, math.floor(tonumber(state.ChestPoints) or 0))

	return {
		Points = points,
		BasicCost = BASIC_CHEST_COST,
		CanOpenBasic = points >= BASIC_CHEST_COST,
		TotalOpened = math.max(0, math.floor(tonumber(state.TotalOpened) or 0)),
	}
end

local function rollBasicChestReward()
	local totalWeight = 0
	for _, reward in ipairs(BASIC_CHEST_REWARDS) do
		totalWeight += math.max(0, tonumber(reward.Weight) or 0)
	end

	local roll = math.random() * totalWeight
	local runningWeight = 0

	for _, reward in ipairs(BASIC_CHEST_REWARDS) do
		runningWeight += math.max(0, tonumber(reward.Weight) or 0)
		if roll <= runningWeight then
			return reward
		end
	end

	return BASIC_CHEST_REWARDS[1]
end

local function applyChestReward(player, reward)
	if type(reward) ~= "table" then
		return false
	end

	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
	if amount <= 0 then
		return false
	end

	if reward.Type == "IQ" then
		GameLogic.AddIQ(player, amount)
		return true
	end

	if reward.Type == "KP" then
		GameLogic.AddKnowledgePoints(player, amount)
		return true
	end

	return false
end

local function advanceQuest(player, questId, amount)
	amount = math.max(0, tonumber(amount) or 0)

	if amount <= 0 then
		return false, false
	end

	local questDefinition = QUEST_DEFINITION_BY_ID[questId]
	if not questDefinition then
		return false, false
	end

	local state = getQuestState(player)
	local questState = state.Quests[questId]

	if not questState or questState.Claimed then
		return false, false
	end

	local wasCompleted = questState.Completed == true
	local previousProgress = tonumber(questState.Progress) or 0
	questState.Progress = math.min(questDefinition.Goal, (tonumber(questState.Progress) or 0) + amount)

	if questState.Progress >= questDefinition.Goal then
		questState.Completed = true
	end

	local completedNow = not wasCompleted and questState.Completed == true
	local changed = questState.Progress ~= previousProgress or completedNow

	return completedNow, changed
end

local function updateQuestProgressFromRoll(player, rollResult)
	local completedQuests = {}
	local progressChanged = false

	local completed, changed = advanceQuest(player, "Roll_50", 1)
	progressChanged = progressChanged or changed
	if completed then
		table.insert(completedQuests, QUEST_DEFINITION_BY_ID.Roll_50)
	end

	completed, changed = advanceQuest(player, "GainIQ_1000", tonumber(rollResult.GainedIQ) or 0)
	progressChanged = progressChanged or changed
	if completed then
		table.insert(completedQuests, QUEST_DEFINITION_BY_ID.GainIQ_1000)
	end

	if rollResult.IsNewConcept then
		completed, changed = advanceQuest(player, "Discover_3", 1)
		progressChanged = progressChanged or changed
		if completed then
			table.insert(completedQuests, QUEST_DEFINITION_BY_ID.Discover_3)
		end
	end

	return completedQuests, progressChanged
end

local function getEffectiveRollCooldown(player)
	local autoLevel = GameLogic.GetAutoRollLevel(player)

	if autoLevel <= 0 then
		return 0.75
	end

	local delay = GameLogic.GetAutoRollDelay(player)
	return math.max(tonumber(delay) or 0.75, SERVER_MIN_ROLL_COOLDOWN)
end

local function getStats(player)
	local discoveredByRarity = {}
	local recentConcepts = {}

	if type(GameLogic.GetDiscoveredConceptCountByRarity) == "function" then
		discoveredByRarity = GameLogic.GetDiscoveredConceptCountByRarity(player)
	end

	if type(GameLogic.GetRecentDiscoveredConcepts) == "function" then
		recentConcepts = GameLogic.GetRecentDiscoveredConcepts(player, 5)
	end

	local discoveredConcepts = 0
	if type(GameLogic.GetDiscoveredConceptCount) == "function" then
		discoveredConcepts = GameLogic.GetDiscoveredConceptCount(player)
	end

	local totalConcepts = 0
	if type(ConceptGenerator.GetTotalCount) == "function" then
		totalConcepts = ConceptGenerator.GetTotalCount()
	end

	local luckUpgradeCost = nil
	if type(GameLogic.GetLuckUpgradeCost) == "function" then
		luckUpgradeCost = GameLogic.GetLuckUpgradeCost(player)
	end

	local autoRollUpgradeCost = nil
	if type(GameLogic.GetAutoRollUpgradeCost) == "function" then
		autoRollUpgradeCost = GameLogic.GetAutoRollUpgradeCost(player)
	end

	local autoRollDelay = getEffectiveRollCooldown(player)
	local brainSurgeStats = getBrainSurgeStats(player)

	local indexMilestoneInfo = {
		CurrentMilestone = 0,
		CurrentBonus = 1,
		NextMilestone = 5,
		NextBonus = 1.02,
	}

	if type(GameLogic.GetIndexMilestoneBonus) == "function" then
		indexMilestoneInfo = GameLogic.GetIndexMilestoneBonus(player)
	end

	local rebirths = 0
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsValue = leaderstats:FindFirstChild("Rebirths")
		if rebirthsValue then
			rebirths = tonumber(rebirthsValue.Value) or 0
		end
	end

	return {
		IQ = GameLogic.GetIQ(player),
		Wins = GameLogic.GetWins(player),
		LuckLevel = GameLogic.GetLuckLevel(player),
		LuckUpgradeCost = luckUpgradeCost,
		Rebirths = rebirths,

		KnowledgePoints = type(GameLogic.GetKnowledgePoints) == "function" and GameLogic.GetKnowledgePoints(player) or 0,
		IndexLevel = type(GameLogic.GetIndexLevel) == "function" and GameLogic.GetIndexLevel(player) or 1,
		IndexIQMultiplier = type(GameLogic.GetIndexIQMultiplier) == "function" and GameLogic.GetIndexIQMultiplier(player) or 1,
		IndexMilestoneBonus = indexMilestoneInfo.CurrentBonus or 1,
		CurrentIndexMilestone = indexMilestoneInfo.CurrentMilestone or 0,
		NextIndexMilestone = indexMilestoneInfo.NextMilestone,
		NextIndexMilestoneBonus = indexMilestoneInfo.NextBonus,

		DiscoveredConcepts = discoveredConcepts,
		TotalConcepts = totalConcepts,
		DiscoveredByRarity = discoveredByRarity,
		RecentConcepts = recentConcepts,

		AutoRollLevel = type(GameLogic.GetAutoRollLevel) == "function" and GameLogic.GetAutoRollLevel(player) or 0,
		AutoRollUpgradeCost = autoRollUpgradeCost,
		AutoRollDelay = autoRollDelay,

		BrainSurgeProgress = brainSurgeStats.Progress,
		BrainSurgeTarget = brainSurgeStats.Target,
		BrainSurgeReady = brainSurgeStats.Ready,
		BrainSurgeMultiplier = brainSurgeStats.Multiplier,

		Quests = getQuestPayload(player),
		Chest = getChestPayload(player),
	}
end

local function updateAllStats(player)
	if not player or not player.Parent then
		return
	end

	UpdateStats:FireClient(player, getStats(player))
end

-- Next Area:
-- This helper provides the server-authoritative unlock check for Area 2.
-- Phase E movement must still pass this check before moving the character.
-- Client READY UI is display-only; final entry permission must trust this server check.
local function canEnterNextArea(player)
	if not player or not player.Parent then
		return false, "INVALID_PLAYER", 0, NEXT_AREA_REQUIRED_IQ
	end

	if not DataManager.IsLoaded(player) then
		return false, "DATA_NOT_LOADED", 0, NEXT_AREA_REQUIRED_IQ
	end

	local currentIQ = math.max(0, math.floor(tonumber(GameLogic.GetIQ(player)) or 0))
	if currentIQ < NEXT_AREA_REQUIRED_IQ then
		return false, "NOT_ENOUGH_IQ", currentIQ, NEXT_AREA_REQUIRED_IQ
	end

	return true, "OK", currentIQ, NEXT_AREA_REQUIRED_IQ
end

local function getArea2ArrivalCFrame()
	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	local arrivalPad = simpleMap and simpleMap:FindFirstChild("Area2ArrivalPad", true)

	if not arrivalPad or not arrivalPad:IsA("BasePart") then
		return nil
	end

	return arrivalPad.CFrame + Vector3.new(0, 5, 0)
end

local function getLobbyReturnCFrame()
	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	local returnPart = simpleMap and (simpleMap:FindFirstChild("PlayerSpawn", true) or simpleMap:FindFirstChild("SpawnLocation", true))

	if not returnPart or not returnPart:IsA("BasePart") then
		return nil
	end

	return returnPart.CFrame + Vector3.new(0, 5, 0)
end

local function handleNextAreaRequest(player)
	if not player or not player.Parent then
		return
	end

	local userId = player.UserId
	local nowTime = os.clock()
	local lastRequestAt = tonumber(nextAreaRequestLastAtByUserId[userId]) or 0

	if nowTime - lastRequestAt < NEXT_AREA_REQUEST_COOLDOWN then
		return
	end

	nextAreaRequestLastAtByUserId[userId] = nowTime

	local canEnter, reasonCode, currentIQ, requiredIQ = canEnterNextArea(player)
	if not canEnter and reasonCode == "DATA_NOT_LOADED" then
		PopupEvent:FireClient(player, "PLEASE WAIT|Data is still loading", "Info")
		return
	elseif not canEnter and reasonCode == "NOT_ENOUGH_IQ" then
		PopupEvent:FireClient(player, "AREA LOCKED|Need " .. formatNumber(requiredIQ or NEXT_AREA_REQUIRED_IQ) .. " IQ", "Info")
		return
	elseif not canEnter then
		PopupEvent:FireClient(player, "AREA UNAVAILABLE|Try again soon", "Info")
		return
	end

	local character = player.Character
	if not character then
		PopupEvent:FireClient(player, "AREA UNAVAILABLE|Character not ready", "Info")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		PopupEvent:FireClient(player, "AREA UNAVAILABLE|Character not ready", "Info")
		return
	end

	if humanoid.Health <= 0 then
		PopupEvent:FireClient(player, "AREA UNAVAILABLE|Try again after respawn", "Info")
		return
	end

	local targetCFrame = getArea2ArrivalCFrame()
	if not targetCFrame then
		warn("[NextArea] Area2ArrivalPad missing; movement skipped.")
		PopupEvent:FireClient(player, "AREA UNAVAILABLE|Try again soon", "Info")
		return
	end

	local moveOk, moveError = pcall(function()
		character:PivotTo(targetCFrame)
	end)

	if not moveOk then
		warn("[NextArea] Failed to move player:", player.Name, moveError)
		PopupEvent:FireClient(player, "AREA UNAVAILABLE|Try again soon", "Info")
		return
	end

	PopupEvent:FireClient(player, "AREA 2 PREVIEW|Full area coming soon", "Info")
end

local function handleReturnToLobbyRequest(player)
	if not player or not player.Parent then
		return
	end

	local userId = player.UserId
	local nowTime = os.clock()
	local lastRequestAt = tonumber(returnToLobbyLastAtByUserId[userId]) or 0

	if nowTime - lastRequestAt < RETURN_TO_LOBBY_COOLDOWN then
		return
	end

	returnToLobbyLastAtByUserId[userId] = nowTime

	local character = player.Character
	if not character then
		PopupEvent:FireClient(player, "RETURN FAILED|Character not ready", "Info")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		PopupEvent:FireClient(player, "RETURN FAILED|Character not ready", "Info")
		return
	end

	if humanoid.Health <= 0 then
		PopupEvent:FireClient(player, "RETURN FAILED|Try again after respawn", "Info")
		return
	end

	local targetCFrame = getLobbyReturnCFrame()
	if not targetCFrame then
		warn("[ReturnToLobby] Lobby spawn not found; movement skipped.")
		PopupEvent:FireClient(player, "RETURN FAILED|Lobby spawn not found", "Info")
		return
	end

	local moveOk, moveError = pcall(function()
		character:PivotTo(targetCFrame)
	end)

	if not moveOk then
		warn("[ReturnToLobby] Failed to move player:", player.Name, moveError)
		PopupEvent:FireClient(player, "RETURN FAILED|Lobby spawn not found", "Info")
		return
	end

	PopupEvent:FireClient(player, "LOBBY|Returned to lobby", "Info")
end

local function getDirtySaveState(player)
	local userId = player.UserId
	local state = dirtySaveStates[userId]

	if not state then
		state = {
			IsDirty = false,
			DirtyReason = nil,
			DirtyReasons = {},
			DirtyRevision = 0,
			LastDirtyAt = 0,
			LastSaveAttemptAt = 0,
			SaveInProgress = false,
		}

		dirtySaveStates[userId] = state
	end

	return state
end

local function formatDirtyReasons(state)
	if type(state) ~= "table" or type(state.DirtyReasons) ~= "table" then
		return tostring(state and state.DirtyReason or "Unknown")
	end

	local reasons = {}
	for reason in pairs(state.DirtyReasons) do
		table.insert(reasons, reason)
	end

	table.sort(reasons)

	if #reasons == 0 then
		return tostring(state.DirtyReason or "Unknown")
	end

	return table.concat(reasons, ",")
end

local function clearPlayerDirty(player, source, savedRevision)
	local state = dirtySaveStates[player.UserId]
	if not state then
		return
	end

	if savedRevision ~= nil and state.DirtyRevision ~= savedRevision then
		state.IsDirty = true
		state.DirtyReason = formatDirtyReasons(state)
		print(
			"[DirtySave] KeepDirty userId="
				.. tostring(player.UserId)
				.. " savedRevision="
				.. tostring(savedRevision)
				.. " currentRevision="
				.. tostring(state.DirtyRevision)
				.. " source="
				.. tostring(source or "Unknown")
		)
		return
	end

	local wasDirty = state.IsDirty == true

	state.IsDirty = false
	state.DirtyReason = nil
	state.DirtyReasons = {}

	if source and wasDirty then
		print("[DirtySave] Clear userId=" .. tostring(player.UserId) .. " source=" .. tostring(source))
	end
end

local function markPlayerDirty(player, reason)
	if not player or not player.Parent then
		return
	end

	reason = tostring(reason or "Unknown")

	local state = getDirtySaveState(player)
	local shouldLog = not state.IsDirty or state.DirtyReasons[reason] ~= true

	state.IsDirty = true
	state.DirtyReasons[reason] = true
	state.DirtyReason = formatDirtyReasons(state)
	state.DirtyRevision += 1
	state.LastDirtyAt = os.clock()

	if shouldLog then
		print("[DirtySave] Mark userId=" .. tostring(player.UserId) .. " reason=" .. reason)
	end
end

local function waitForDirtySave(player, maxWaitSeconds)
	local state = dirtySaveStates[player.UserId]
	local deadline = os.clock() + (tonumber(maxWaitSeconds) or 0)

	while state and state.SaveInProgress and os.clock() < deadline do
		task.wait(0.1)
	end

	return not (state and state.SaveInProgress)
end

local function trySaveDirtyPlayer(player, source, force)
	if not player or not player.Parent then
		return false, "PLAYER_NOT_ACTIVE"
	end

	local state = dirtySaveStates[player.UserId]
	if not state or state.IsDirty ~= true then
		return true
	end

	if state.SaveInProgress then
		return false, "SAVE_IN_PROGRESS"
	end

	if not force and os.clock() - (tonumber(state.LastSaveAttemptAt) or 0) < DIRTY_SAVE_RETRY_DELAY then
		return false, "RETRY_DELAY"
	end

	if not DataManager.IsLoaded(player) then
		return false, "DATA_NOT_LOADED"
	end

	state.SaveInProgress = true
	state.LastSaveAttemptAt = os.clock()

	local reasons = formatDirtyReasons(state)
	local saveRevision = state.DirtyRevision
	print("[DirtySave] Begin userId=" .. tostring(player.UserId) .. " reasons=" .. reasons .. " source=" .. tostring(source or "DirtyLoop"))

	local success, savedOrError = pcall(function()
		return DataManager.SaveProfile(player, false, {
			Reason = "DirtySave_" .. tostring(source or "DirtyLoop"),
		})
	end)

	state.SaveInProgress = false

	if success and savedOrError then
		clearPlayerDirty(player, tostring(source or "DirtyLoop"), saveRevision)
		print("[DirtySave] OK userId=" .. tostring(player.UserId))
		return true
	end

	state.IsDirty = true
	state.DirtyReason = formatDirtyReasons(state)
	warn("[DirtySave] Failed userId=" .. tostring(player.UserId) .. " error=" .. tostring(savedOrError))

	return false, savedOrError
end

local function saveProfileWithDirtyGuard(player, source, options)
	if not player or not player.Parent then
		return false, "PLAYER_NOT_ACTIVE"
	end

	local state = getDirtySaveState(player)
	waitForDirtySave(player, 5)

	if state.SaveInProgress then
		markPlayerDirty(player, tostring(source or "SaveInProgress"))
		return false, "SAVE_IN_PROGRESS"
	end

	if not DataManager.IsLoaded(player) then
		return false, "DATA_NOT_LOADED"
	end

	state.SaveInProgress = true
	state.LastSaveAttemptAt = os.clock()
	local saveRevision = state.DirtyRevision

	local success, savedOrError = pcall(function()
		return DataManager.SaveProfile(player, false, options)
	end)

	state.SaveInProgress = false

	if success and savedOrError then
		clearPlayerDirty(player, source, saveRevision)
		return true
	end

	markPlayerDirty(player, tostring(source or "ImmediateSaveFailed"))
	return false, savedOrError
end

local function releaseProfileWithDirtyGuard(player, source)
	local userId = player.UserId
	local state = dirtySaveStates[userId]

	waitForDirtySave(player, 5)

	state = dirtySaveStates[userId]
	if state and state.SaveInProgress then
		warn("[DirtySave] Release blocked by active save userId=" .. tostring(userId) .. " source=" .. tostring(source))
		return false, "SAVE_IN_PROGRESS"
	end

	state = dirtySaveStates[userId]
	if state then
		state.SaveInProgress = true
		state.LastSaveAttemptAt = os.clock()
	end
	local releaseRevision = state and state.DirtyRevision or nil

	local success, result = pcall(function()
		return DataManager.ReleaseProfile(player)
	end)

	state = dirtySaveStates[userId]
	if state then
		state.SaveInProgress = false

		if success and result then
			clearPlayerDirty(player, tostring(source or "ReleaseProfile"), releaseRevision)
		else
			warn("[DirtySave] Release failed; dirty state cannot retry after player leaves userId=" .. tostring(userId) .. " source=" .. tostring(source))
		end
	end

	return success, result
end

local function safeSaveImportantEvent(player, reason)
	reason = tostring(reason or "Unknown")

	local saveSuccess, savedOrError = saveProfileWithDirtyGuard(player, "ImportantEvent_" .. reason)

	if saveSuccess then
		print("[SaveImportantEvent] OK reason=" .. reason .. " player=" .. tostring(player and player.Name))
	else
		warn("[SaveImportantEvent] Failed reason=" .. reason .. " player=" .. tostring(player and player.Name) .. " err=" .. tostring(savedOrError))
	end
end

local function getPlayerFromTouchedPart(hit)
	if not hit then
		return nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getSimpleMap()
	return Workspace:FindFirstChild("SimpleMap")
end

local function isInSimpleMap(instance)
	local simpleMap = getSimpleMap()
	return simpleMap and instance and instance:IsDescendantOf(simpleMap)
end

local function buildSimpleMap()
	local simpleWorldBuilder = ServerScriptService:FindFirstChild("SimpleWorldBuilder")
	if not simpleWorldBuilder then
		warn("[GameServer] SimpleWorldBuilder not found.")
		return
	end

	local success, builder = pcall(require, simpleWorldBuilder)
	if not success then
		warn("[GameServer] Failed to require SimpleWorldBuilder:", builder)
		return
	end

	local buildSuccess, buildError = pcall(function()
		if type(builder.CreateMap) == "function" then
			builder.CreateMap()
		elseif type(builder.Build) == "function" then
			builder.Build()
		elseif type(builder.Init) == "function" then
			builder.Init()
		elseif type(builder.Start) == "function" then
			builder.Start()
		else
			warn("[GameServer] SimpleWorldBuilder has no CreateMap/Build/Init/Start function.")
		end
	end)

	if not buildSuccess then
		warn("[GameServer] SimpleWorldBuilder failed:", buildError)
	end
end

buildSimpleMap()

local function getServerRollCooldown(player)
	return getEffectiveRollCooldown(player)
end

local function canRollNow(player)
	local userId = player.UserId
	local nowTime = os.clock()
	local cooldown = getServerRollCooldown(player)
	local lastRollAt = lastRollAtByUserId[userId]

	if lastRollAt and nowTime - lastRollAt < cooldown then
		return false, math.max(0, cooldown - (nowTime - lastRollAt))
	end

	return true, 0
end

local function markRollTime(player)
	lastRollAtByUserId[player.UserId] = os.clock()
end

local NEW_CONCEPT_RARITIES = {
	EXPERT = true,
	GENIUS = true,
	PRODIGY = true,
	SUPER_GENIUS = true,
	MASTERMIND = true,
	LEGENDARY = true,
	MYTHIC = true,
	TRANSCENDENT = true,
	IMPOSSIBLE = true,
	SECRET = true,
	REALITY_BREAKER = true,
}

local function buildRollPopupText(result)
	local conceptName = tostring(result.ConceptName or "Unknown Concept")
	local rarity = tostring(result.Rarity or "COMMON")
	local gainedIQ = tonumber(result.GainedIQ) or 0
	local kpReward = tonumber(result.KnowledgePointsReward) or 0

	local subtitleParts = {}

	if result.IsNewConcept and NEW_CONCEPT_RARITIES[rarity] then
		table.insert(subtitleParts, "NEW CONCEPT")
	end

	if result.BrainSurgeActive then
		table.insert(subtitleParts, "BRAIN SURGE x" .. tostring(result.BrainSurgeMultiplier or BRAIN_SURGE_MULTIPLIER))
	end

	table.insert(subtitleParts, displayRarity(rarity))
	table.insert(subtitleParts, "+" .. formatNumber(gainedIQ) .. " IQ")

	if kpReward > 0 then
		table.insert(subtitleParts, "+" .. formatNumber(kpReward) .. " KP")
	end

	if result.IndexMilestoneReached then
		table.insert(subtitleParts, "Index x" .. string.format("%.2f", tonumber(result.IndexMilestoneBonus) or 1))
	end

	return conceptName .. "|" .. table.concat(subtitleParts, " · ")
end

local function isValidRollResult(result)
	if type(result) ~= "table" then
		return false
	end

	if result.ConceptName == nil then
		return false
	end

	if result.Rarity == nil then
		return false
	end

	if result.GainedIQ == nil then
		return false
	end

	return true
end

local function handleRoll(player)
	if not DataManager.IsLoaded(player) then
		PopupEvent:FireClient(player, "Loading|Data is not ready yet", "Info")
		return
	end

	if rollDebounce[player.UserId] then
		UpdateStats:FireClient(player, getStats(player))
		PopupEvent:FireClient(player, "Cooldown|0.20", "RollCooldown")
		return
	end

	if not GameLogic.IsAlive(player) then
		return
	end

	local canRoll, cooldownRemaining = canRollNow(player)
	if not canRoll then
		UpdateStats:FireClient(player, getStats(player))
		PopupEvent:FireClient(player, "Cooldown|" .. string.format("%.2f", cooldownRemaining or getServerRollCooldown(player)), "RollCooldown")
		return
	end

	rollDebounce[player.UserId] = true
	markRollTime(player)

	local brainSurgeState, brainSurgeRollInfo = getBrainSurgeRollInfo(player)
	local rollOptions = nil

	if brainSurgeRollInfo.Active then
		rollOptions = {
			BrainSurgeActive = true,
			LuckMultiplier = brainSurgeRollInfo.Multiplier,
		}
	end

	local success, result = pcall(function()
		return GameLogic.RollIQ(player, rollOptions)
	end)

	if not success then
		warn("[GameServer] Roll failed:", player.Name, result)
		PopupEvent:FireClient(player, "Roll Failed|Try again", "Info")
		rollDebounce[player.UserId] = nil
		return
	end

	if not isValidRollResult(result) then
		warn("[GameServer] Invalid RollIQ result:", player.Name, result)
		PopupEvent:FireClient(player, "Roll Failed|Invalid result", "Info")
		rollDebounce[player.UserId] = nil
		return
	end

	commitBrainSurgeRoll(brainSurgeState, brainSurgeRollInfo)

	local completedQuests, questProgressChanged = updateQuestProgressFromRoll(player, result)
	addChestPoints(player, result.IsNewConcept and 4 or 1)

	markPlayerDirty(player, "RollIQ")
	markPlayerDirty(player, "ChestPointsGain")

	if result.IsNewConcept then
		markPlayerDirty(player, "ConceptDiscovered")
	end

	if questProgressChanged then
		markPlayerDirty(player, "QuestProgress")
	end

	updateAllStats(player)
	PopupEvent:FireClient(player, buildRollPopupText(result), "Roll")

	for _, questDefinition in ipairs(completedQuests) do
		PopupEvent:FireClient(
			player,
			"QUEST COMPLETE!|" .. tostring(questDefinition.Title) .. "|Reward Ready: " .. tostring(questDefinition.RewardText),
			"Quest"
		)
	end

	rollDebounce[player.UserId] = nil
end

local function handleLuckUpgrade(player)
	if not DataManager.IsLoaded(player) then
		PopupEvent:FireClient(player, "Loading|Data is not ready yet", "Info")
		return
	end

	local success, reason, newLevel, nextCost = GameLogic.TryUpgradeLuck(player)

	updateAllStats(player)

	if success then
		saveProfileWithDirtyGuard(player, "LuckUpgrade")
		local costText = nextCost and (formatNumber(nextCost) .. " Wins") or "MAX"
		PopupEvent:FireClient(player, "LUCK UP|Lv " .. tostring(newLevel) .. " · Next " .. costText, "Info")
		return
	end

	if reason == "Max" then
		PopupEvent:FireClient(player, "LUCK MAX|Already max level", "Info")
	elseif reason == "NeedWins" then
		local cost = GameLogic.GetLuckUpgradeCost(player)
		PopupEvent:FireClient(player, "Need Wins|Luck cost " .. formatNumber(cost or 0) .. " Wins", "Info")
	else
		PopupEvent:FireClient(player, "LUCK UP FAILED|" .. tostring(reason or "Unknown"), "Info")
	end
end

local function handleAutoRollUpgrade(player)
	if not DataManager.IsLoaded(player) then
		PopupEvent:FireClient(player, "Loading|Data is not ready yet", "Info")
		return
	end

	local success, reason, newLevel, nextCost, delay = GameLogic.TryUpgradeAutoRoll(player)

	updateAllStats(player)

	if success then
		saveProfileWithDirtyGuard(player, "AutoRollUpgrade")

		local nextText = nextCost and (" · Next " .. formatNumber(nextCost) .. " Wins") or ""
		PopupEvent:FireClient(
			player,
			"AUTO UPGRADE|Lv " .. tostring(newLevel) .. " · Delay " .. string.format("%.2fs", tonumber(delay) or 0) .. nextText,
			"Info"
		)

		return
	end

	if reason == "Max" then
		local level = GameLogic.GetAutoRollLevel(player)
		local currentDelay = GameLogic.GetAutoRollDelay(player)
		PopupEvent:FireClient(player, "AUTO MAX|Lv " .. tostring(level) .. " · Delay " .. string.format("%.2fs", currentDelay), "Info")
	elseif reason == "NeedWins" then
		local cost = GameLogic.GetAutoRollUpgradeCost(player)
		local level = GameLogic.GetAutoRollLevel(player)
		PopupEvent:FireClient(player, "Need Wins|Auto Lv " .. tostring(level + 1) .. " Cost " .. formatNumber(cost or 0) .. " Wins", "Info")
	else
		PopupEvent:FireClient(player, "AUTO FAILED|" .. tostring(reason or "Unknown"), "Info")
	end
end

local function handleQuestClaim(player, questId)
	if not DataManager.IsLoaded(player) then
		PopupEvent:FireClient(player, "Loading|Data is not ready yet", "Info")
		return
	end

	questId = tostring(questId or "")

	local questDefinition = QUEST_DEFINITION_BY_ID[questId]
	if not questDefinition then
		warn("[Quest] Unknown quest claim:", player.Name, player.UserId, questId)
		PopupEvent:FireClient(player, "QUEST|Unknown quest", "Info")
		return
	end

	local state = getQuestState(player)
	local questState = state.Quests[questId]

	if not questState then
		PopupEvent:FireClient(player, "QUEST|Quest not ready", "Info")
		return
	end

	if questState.Claimed then
		PopupEvent:FireClient(player, "QUEST|Already claimed", "Info")
		return
	end

	if not questState.Completed or (tonumber(questState.Progress) or 0) < questDefinition.Goal then
		PopupEvent:FireClient(player, "QUEST|Not complete yet", "Info")
		return
	end

	local rewardSuccess, rewardType = GameLogic.ApplyQuestReward(player, questDefinition.Reward)
	if not rewardSuccess then
		warn("[Quest] Reward failed:", player.Name, player.UserId, questId, rewardType)
		PopupEvent:FireClient(player, "QUEST FAILED|Reward error", "Info")
		return
	end

	questState.Claimed = true
	addChestPoints(player, 10)
	updateAllStats(player)
	PopupEvent:FireClient(player, "QUEST CLAIMED!|" .. questDefinition.RewardText .. "|+10 Chest Points", "Quest")
	safeSaveImportantEvent(player, "QuestClaim")
end

local function handleChestOpen(player, chestId)
	if not DataManager.IsLoaded(player) then
		PopupEvent:FireClient(player, "Loading|Data is not ready yet", "Info")
		return
	end

	chestId = tostring(chestId or "")
	if chestId ~= "Basic" then
		warn("[Chest] Unknown chest request:", player.Name, player.UserId, chestId)
		PopupEvent:FireClient(player, "CHEST|Unknown chest", "Chest")
		return
	end

	local userId = player.UserId
	if chestOpenDebounce[userId] then
		return
	end

	chestOpenDebounce[userId] = true

	local state = getChestState(player)
	local points = math.max(0, math.floor(tonumber(state.ChestPoints) or 0))

	if points < BASIC_CHEST_COST then
		updateAllStats(player)
		PopupEvent:FireClient(player, "CHEST LOCKED|Need " .. tostring(BASIC_CHEST_COST) .. " Chest Points", "Chest")
		chestOpenDebounce[userId] = nil
		return
	end

	state.ChestPoints = points - BASIC_CHEST_COST

	local reward = rollBasicChestReward()
	if not applyChestReward(player, reward) then
		state.ChestPoints = points
		updateAllStats(player)
		PopupEvent:FireClient(player, "CHEST FAILED|Reward error", "Chest")
		chestOpenDebounce[userId] = nil
		return
	end

	state.TotalOpened = math.max(0, math.floor(tonumber(state.TotalOpened) or 0)) + 1

	updateAllStats(player)
	PopupEvent:FireClient(player, "CHEST OPENED!|" .. tostring(reward.Text or "Reward"), "Chest")
	chestOpenDebounce[userId] = nil
	safeSaveImportantEvent(player, "ChestOpen")
end

local function connectWorldChestPrompt()
	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	if not simpleMap then
		warn("[WorldChest] SimpleMap missing; prompt connection skipped.")
		return
	end

	local station = simpleMap:FindFirstChild("WorldChestStation")
	if not station then
		warn("[WorldChest] WorldChestStation missing; prompt connection skipped.")
		return
	end

	local promptPart = station:FindFirstChild("ChestPromptPart", true)
	if not promptPart then
		warn("[WorldChest] ChestPromptPart missing; prompt connection skipped.")
		return
	end

	local prompt = promptPart:FindFirstChild("ChestOpenPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[WorldChest] ChestOpenPrompt missing; prompt connection skipped.")
		return
	end

	if worldChestConnectedPrompt == prompt and worldChestPromptConnection then
		return
	end

	if worldChestPromptConnection then
		worldChestPromptConnection:Disconnect()
		worldChestPromptConnection = nil
	end

	worldChestConnectedPrompt = prompt
	worldChestPromptConnection = prompt.Triggered:Connect(function(player)
		handleChestOpen(player, "Basic")
	end)
end

local function getAdminSaveState(player)
	local userId = player.UserId
	local state = adminSaveStates[userId]

	if not state then
		state = {
			dirty = false,
			saving = false,
			workerRunning = false,
			allowEmptyOverwrite = false,
			reason = nil,
			lastSaveAt = 0,
		}

		adminSaveStates[userId] = state
	end

	return state
end

local function applyResetSaveOptionToState(state, options)
	if type(options) ~= "table" then
		return
	end

	if options.AllowEmptyOverwrite == true then
		state.allowEmptyOverwrite = true
		state.reason = tostring(options.Reason or "AdminResetTestData")
	end
end

local function performQueuedAdminSave(player, source)
	if not player or not player.Parent then
		return false
	end

	if not DataManager.IsLoaded(player) then
		warn("[AdminTest] Save skipped because data is not loaded:", player.Name, player.UserId)
		return false
	end

	local state = getAdminSaveState(player)

	if state.saving then
		return false
	end

	state.saving = true

	local allowEmptyOverwrite = state.allowEmptyOverwrite == true
	local reason = state.reason

	state.dirty = false
	state.allowEmptyOverwrite = false
	state.reason = nil

	local options = nil

	if allowEmptyOverwrite then
		options = {
			AllowEmptyOverwrite = true,
			Reason = reason or "AdminResetTestData",
		}
	end

	local saved, saveError = saveProfileWithDirtyGuard(player, "AdminSave_" .. tostring(source), options)

	state.saving = false
	state.lastSaveAt = os.clock()

	if saved then
		PopupEvent:FireClient(player, "ADMIN SAVE OK|Changes saved", "Info")
		return true
	end

	if allowEmptyOverwrite then
		state.allowEmptyOverwrite = true
		state.reason = reason or "AdminResetTestData"
	end

	state.dirty = true

	warn("[AdminTest] Queued save failed:", source, player.Name, player.UserId, saved, saveError)
	PopupEvent:FireClient(player, "ADMIN SAVE FAILED|Check Output", "Info")

	return false
end

local function startAdminSaveWorker(player)
	local state = getAdminSaveState(player)

	if state.workerRunning then
		return
	end

	state.workerRunning = true

	task.spawn(function()
		while player.Parent and DataManager.IsLoaded(player) do
			task.wait(ADMIN_SAVE_COOLDOWN)

			if not state.dirty then
				break
			end

			if not state.saving then
				performQueuedAdminSave(player, "QueuedAdminSave")
			end

			if not state.dirty then
				break
			end
		end

		state.workerRunning = false

		if state.dirty and player.Parent and DataManager.IsLoaded(player) then
			startAdminSaveWorker(player)
		end
	end)
end

local function queueAdminSave(player, options)
	local state = getAdminSaveState(player)

	state.dirty = true
	applyResetSaveOptionToState(state, options)

	startAdminSaveWorker(player)

	PopupEvent:FireClient(player, "ADMIN|Applied · Save queued", "Info")
end

local function tryForceAdminSave(player)
	local state = getAdminSaveState(player)

	if state.saving or state.dirty or state.workerRunning then
		PopupEvent:FireClient(player, "SAVE BUSY|Save already queued", "Info")
		return
	end

	state.saving = true

	local saved, saveError = saveProfileWithDirtyGuard(player, "AdminForceSave")

	state.saving = false
	state.lastSaveAt = os.clock()

	if saved then
		PopupEvent:FireClient(player, "FORCE SAVE OK|Profile saved", "Info")
	else
		warn("[AdminTest] Force Save failed:", player.Name, player.UserId, saved, saveError)
		PopupEvent:FireClient(player, "FORCE SAVE FAILED|Check Output", "Info")
	end
end

local function flushQueuedAdminSaveBeforeRelease(player)
	local state = adminSaveStates[player.UserId]

	if not state then
		return
	end

	if state.dirty and not state.saving and DataManager.IsLoaded(player) then
		performQueuedAdminSave(player, "PlayerRemovingFlush")
	end
end

local function sanitizeAdminAmount(amount)
	amount = tonumber(amount)

	if not amount then
		return nil
	end

	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil
	end

	return math.floor(amount)
end

local ADMIN_SAVE_ACTIONS = {
	AddIQ = true,
	SetIQ = true,
	AddWins = true,
	SetWins = true,
	AddKP = true,
	SetKP = true,
	AddLuck = true,
	SetLuck = true,
	AddAutoRoll = true,
	SetAutoRoll = true,
	AddIndexLevel = true,
	SetIndexLevel = true,
	DiscoverRandomConcepts = true,
	ClearRecentConcepts = true,
}

local ADMIN_NO_SAVE_ACTIONS = {
	PrintDataSnapshot = true,
}

local ADMIN_FORCE_SAVE_ACTIONS = {
	ForceSave = true,
}

local ADMIN_RESET_ACTIONS = {
	ResetTestData = true,
}

local function printDataSnapshot(player)
	local totalConcepts = 0
	if type(ConceptGenerator.GetTotalCount) == "function" then
		totalConcepts = ConceptGenerator.GetTotalCount()
	end

	print("[AdminTest] Data Snapshot")
	print("UserId:", player.UserId)
	print("Name:", player.Name)
	print("IQ:", GameLogic.GetIQ(player))
	print("Wins:", GameLogic.GetWins(player))
	print("LuckLevel:", GameLogic.GetLuckLevel(player))
	print("KnowledgePoints:", GameLogic.GetKnowledgePoints(player))
	print("IndexLevel:", GameLogic.GetIndexLevel(player))
	print("IndexIQMultiplier:", GameLogic.GetIndexIQMultiplier(player))
	print("AutoRollLevel:", GameLogic.GetAutoRollLevel(player))
	print("Rebirths:", GameLogic.GetRebirths(player))
	print("DiscoveredConcepts:", GameLogic.GetDiscoveredConceptCount(player))
	print("TotalConcepts:", totalConcepts)
	print("DataManager.IsLoaded:", DataManager.IsLoaded(player))
end

local function handleAdminTestRequest(player, action, amount)
	if not ENABLE_ADMIN_TEST_TOOLS then
		warn("[AdminTest] Admin tools disabled.")
		return
	end

	if not isTestAdmin(player) then
		warn("[AdminTest] Blocked non-admin request:", player.Name, player.UserId)
		return
	end

	if not DataManager.IsLoaded(player) then
		PopupEvent:FireClient(player, "ADMIN|Data not loaded", "Info")
		return
	end

	action = tostring(action or "")

	if not ADMIN_SAVE_ACTIONS[action] and not ADMIN_NO_SAVE_ACTIONS[action] and not ADMIN_FORCE_SAVE_ACTIONS[action] and not ADMIN_RESET_ACTIONS[action] then
		warn("[AdminTest] Blocked unknown action:", action, player.Name, player.UserId)
		PopupEvent:FireClient(player, "ADMIN|Unknown action", "Info")
		return
	end

	if ADMIN_RESET_ACTIONS[action] then
		GameLogic.ResetTestData(player)
		updateAllStats(player)

		queueAdminSave(player, {
			AllowEmptyOverwrite = true,
			Reason = "AdminResetTestData",
		})

		return
	end

	if ADMIN_FORCE_SAVE_ACTIONS[action] then
		tryForceAdminSave(player)
		return
	end

	if ADMIN_NO_SAVE_ACTIONS[action] then
		printDataSnapshot(player)
		PopupEvent:FireClient(player, "ADMIN SNAPSHOT|Printed to Output", "Info")
		return
	end

	local value = sanitizeAdminAmount(amount)
	if not value then
		PopupEvent:FireClient(player, "ADMIN|Invalid amount", "Info")
		return
	end

	if action == "AddIQ" then
		GameLogic.AdminAddIQ(player, value)
	elseif action == "SetIQ" then
		GameLogic.AdminSetIQ(player, value)
	elseif action == "AddWins" then
		GameLogic.AdminAddWins(player, value)
	elseif action == "SetWins" then
		GameLogic.AdminSetWins(player, value)
	elseif action == "AddKP" then
		GameLogic.AdminAddKnowledgePoints(player, value)
	elseif action == "SetKP" then
		GameLogic.AdminSetKnowledgePoints(player, value)
	elseif action == "AddLuck" then
		GameLogic.AdminAddLuckLevel(player, value)
	elseif action == "SetLuck" then
		GameLogic.AdminSetLuckLevel(player, value)
	elseif action == "AddAutoRoll" then
		GameLogic.AdminAddAutoRollLevel(player, value)
	elseif action == "SetAutoRoll" then
		GameLogic.AdminSetAutoRollLevel(player, value)
	elseif action == "AddIndexLevel" then
		GameLogic.AdminAddIndexLevel(player, value)
	elseif action == "SetIndexLevel" then
		GameLogic.AdminSetIndexLevel(player, value)
	elseif action == "DiscoverRandomConcepts" then
		GameLogic.AdminDiscoverRandomConcepts(player, value)
	elseif action == "ClearRecentConcepts" then
		GameLogic.ClearRecentConcepts(player)
	end

	updateAllStats(player)
	queueAdminSave(player)
end

local connectedWinPads = {}
local connectedGates = {}

local function connectWinPad(winPad)
	if connectedWinPads[winPad] then
		return
	end

	if not winPad:IsA("BasePart") then
		return
	end

	if not isInSimpleMap(winPad) then
		return
	end

	connectedWinPads[winPad] = true

	winPad.Touched:Connect(function(hit)
		local player = getPlayerFromTouchedPart(hit)
		if not player then
			return
		end

		if not DataManager.IsLoaded(player) then
			return
		end

		if not GameLogic.IsAlive(player) then
			return
		end

		local userId = player.UserId
		if winPadDebounce[userId] then
			return
		end

		winPadDebounce[userId] = true

		local callOk, claimed, status, rewardWins = pcall(function()
			return GameLogic.TryClaimWinPad(player, winPad)
		end)

		if not callOk then
			warn("[GameServer] WinPad claim failed:", player.Name, claimed)
			PopupEvent:FireClient(player, "WIN FAILED|Try again", "Info")
			task.delay(1, function()
				winPadDebounce[userId] = nil
			end)
			return
		end

		if claimed then
			local reward = tonumber(rewardWins) or 0

			updateAllStats(player)
			saveProfileWithDirtyGuard(player, "WinPad")
			PopupEvent:FireClient(player, "WIN|+" .. formatNumber(reward) .. " Wins", "Win")
		elseif status then
			PopupEvent:FireClient(player, "WIN LOCKED|" .. tostring(status), "Info")
		end

		task.delay(1, function()
			winPadDebounce[userId] = nil
		end)
	end)
end

local function connectIQGate(gate)
	if connectedGates[gate] then
		return
	end

	if not gate:IsA("BasePart") then
		return
	end

	if not isInSimpleMap(gate) then
		return
	end

	connectedGates[gate] = true

	gate.Touched:Connect(function(hit)
		local player = getPlayerFromTouchedPart(hit)
		if not player then
			return
		end

		if not DataManager.IsLoaded(player) then
			return
		end

		local userId = player.UserId
		local gateDebounce = gateTouchDebounce[gate]
		if not gateDebounce then
			gateDebounce = {}
			gateTouchDebounce[gate] = gateDebounce
		end

		if gateDebounce[userId] then
			return
		end

		gateDebounce[userId] = true

		local requiredIQ = tonumber(gate:GetAttribute("RequiredIQ")) or 0
		local currentIQ = GameLogic.GetIQ(player)

		if currentIQ >= requiredIQ then
			PopupEvent:FireClient(player, "ACCESS GRANTED|Need " .. formatNumber(requiredIQ) .. " IQ", "Info")
		else
			PopupEvent:FireClient(player, "LOCKED|Need " .. formatNumber(requiredIQ) .. " IQ", "Info")
		end

		task.delay(1, function()
			local currentGateDebounce = gateTouchDebounce[gate]
			if currentGateDebounce then
				currentGateDebounce[userId] = nil

				if next(currentGateDebounce) == nil then
					gateTouchDebounce[gate] = nil
				end
			end
		end)
	end)
end

local function connectTaggedParts()
	for _, instance in ipairs(CollectionService:GetTagged("WinPad")) do
		connectWinPad(instance)
	end

	for _, instance in ipairs(CollectionService:GetTagged("IQGate")) do
		connectIQGate(instance)
	end
end

connectTaggedParts()

CollectionService:GetInstanceAddedSignal("WinPad"):Connect(function(instance)
	task.defer(function()
		connectWinPad(instance)
	end)
end)

CollectionService:GetInstanceAddedSignal("IQGate"):Connect(function(instance)
	task.defer(function()
		connectIQGate(instance)
	end)
end)

RollRequest.OnServerEvent:Connect(handleRoll)
UpgradeRequest.OnServerEvent:Connect(handleLuckUpgrade)
AutoRollUpgradeRequest.OnServerEvent:Connect(handleAutoRollUpgrade)
AdminTestRequest.OnServerEvent:Connect(handleAdminTestRequest)
QuestClaimRequest.OnServerEvent:Connect(handleQuestClaim)
ChestOpenRequest.OnServerEvent:Connect(handleChestOpen)
NextAreaRequest.OnServerEvent:Connect(handleNextAreaRequest)
ReturnToLobbyRequest.OnServerEvent:Connect(handleReturnToLobbyRequest)

task.defer(connectWorldChestPrompt)

local function handlePlayerAdded(player)
	if playerLoadStarted[player.UserId] then
		return
	end

	playerLoadStarted[player.UserId] = true

	print("[GameServer] Player profile loading:", player.Name, player.UserId)

	GameLogic.SetupPlayer(player)

	local loaded = DataManager.LoadProfile(player)
	if not loaded then
		local loadError = DataManager.GetLoadError(player) or "Data failed to load."
		warn("[GameServer] Player profile load failed:", player.Name, player.UserId, loadError)
		player:Kick(loadError)
		return
	end

	print("[GameServer] Player profile loaded:", player.Name, player.UserId)

	updateAllStats(player)
end

Players.PlayerAdded:Connect(handlePlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		handlePlayerAdded(player)
	end)
end

local function clearPlayerRuntimeState(player)
	local userId = player.UserId

	playerLoadStarted[userId] = nil
	rollDebounce[userId] = nil
	winPadDebounce[userId] = nil
	lastRollAtByUserId[userId] = nil
	brainSurgeStateByUserId[userId] = nil
	adminSaveStates[userId] = nil
	chestOpenDebounce[userId] = nil
	nextAreaRequestLastAtByUserId[userId] = nil
	returnToLobbyLastAtByUserId[userId] = nil

	for gate, debounces in pairs(gateTouchDebounce) do
		if type(debounces) == "table" then
			debounces[userId] = nil

			if next(debounces) == nil then
				gateTouchDebounce[gate] = nil
			end
		end
	end

	playerQuestStates[userId] = nil
	playerChestStates[userId] = nil
	dirtySaveStates[userId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	flushQueuedAdminSaveBeforeRelease(player)

	local success, result = releaseProfileWithDirtyGuard(player, "PlayerRemoving")

	if not success and result == "SAVE_IN_PROGRESS" then
		waitForDirtySave(player, 10)
		success, result = releaseProfileWithDirtyGuard(player, "PlayerRemovingRetryAfterSave")
	end

	if not success and result == "SAVE_IN_PROGRESS" then
		warn("[GameServer] ReleaseProfile deferred until active save finishes:", player.Name)
		task.spawn(function()
			waitForDirtySave(player, 15)

			local deferredSuccess, deferredResult = releaseProfileWithDirtyGuard(player, "PlayerRemovingDeferredRelease")
			if not deferredSuccess then
				warn("[GameServer][CRITICAL] Deferred ReleaseProfile error:", player.Name, deferredResult)
			elseif not deferredResult then
				warn("[GameServer][CRITICAL] Deferred ReleaseProfile returned false:", player.Name)
			end

			clearPlayerRuntimeState(player)
		end)
		return
	end

	if not success then
		warn("[GameServer] ReleaseProfile error:", player.Name, result)
	elseif not result then
		warn("[GameServer] ReleaseProfile returned false:", player.Name)
	end

	clearPlayerRuntimeState(player)
end)

task.spawn(function()
	while true do
		task.wait(DIRTY_SAVE_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			local state = dirtySaveStates[player.UserId]
			if state and state.IsDirty == true then
				trySaveDirtyPlayer(player, "Interval", false)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(120)

		for _, player in ipairs(Players:GetPlayers()) do
			local dirtyState = dirtySaveStates[player.UserId]
			local dirtySaveOwnsPlayer = dirtyState and (dirtyState.IsDirty == true or dirtyState.SaveInProgress == true)

			if DataManager.IsLoaded(player) and not dirtySaveOwnsPlayer then
				local success, result = pcall(function()
					return DataManager.SaveProfile(player, false)
				end)

				if not success then
					warn("[GameServer] Auto-save error:", player.Name, result)
				elseif not result then
					warn("[GameServer] Auto-save blocked or failed:", player.Name)
				end
			end
		end
	end
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	local startedAt = os.clock()
	local successCount = 0
	local failureCount = 0

	for _, player in ipairs(players) do
		if DataManager.IsLoaded(player) then
			flushQueuedAdminSaveBeforeRelease(player)

			local success, result = releaseProfileWithDirtyGuard(player, "BindToClose")

			if not success then
				failureCount += 1
				warn("[GameServer] BindToClose ReleaseProfile error:", player.Name, result)
			elseif not result then
				failureCount += 1
				warn("[GameServer] BindToClose ReleaseProfile failed, retrying:", player.Name)

				if os.clock() - startedAt < BIND_TO_CLOSE_MAX_WAIT_SECONDS then
					task.wait(0.5)

					local retrySuccess, retryResult = releaseProfileWithDirtyGuard(player, "BindToCloseRetry")

					if retrySuccess and retryResult then
						successCount += 1
					else
						warn("[GameServer][CRITICAL] BindToClose ReleaseProfile retry failed:", player.Name, retryResult)
					end
				end
			else
				successCount += 1
			end

			dirtySaveStates[player.UserId] = nil

			if os.clock() - startedAt >= BIND_TO_CLOSE_MAX_WAIT_SECONDS then
				warn("[DirtySave] BindToClose max wait reached after player=" .. player.Name)
				break
			end
		end
	end

	print("[DirtySave] BindToClose summary success=" .. tostring(successCount) .. " failed=" .. tostring(failureCount))
	task.wait(1)
end)
