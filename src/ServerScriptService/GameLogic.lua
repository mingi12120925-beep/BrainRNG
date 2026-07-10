-- ServerScriptService/GameLogic.lua

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ConceptGenerator = require(ServerScriptService:WaitForChild("ConceptGenerator"))

local GameLogic = {}
local sessionPersistence = nil

local BASE_WALK_SPEED = 16
local MAX_WALK_SPEED = 80
local MAX_LUCK_LEVEL = 50
local MAX_AUTO_ROLL_LEVEL = 5
local MAX_INDEX_IQ_MULTIPLIER = 2

local LUCK_UPGRADE_BASE_COST = 5
local AUTO_ROLL_COSTS = {
	[1] = 10,
	[2] = 25,
	[3] = 60,
	[4] = 150,
	[5] = 400,
}

local AUTO_ROLL_DELAYS = {
	[1] = 0.80,
	[2] = 0.60,
	[3] = 0.45,
	[4] = 0.30,
	[5] = 0.20,
}

local KNOWLEDGE_POINTS_REWARD = {
	COMMON = 1,
	UNCOMMON = 2,
	SMART = 3,
	SKILLED = 5,
	ADVANCED = 8,
	EXPERT = 12,
	GENIUS = 15,
	PRODIGY = 40,
	SUPER_GENIUS = 60,
	MASTERMIND = 90,
	LEGENDARY = 180,
	MYTHIC = 300,
	TRANSCENDENT = 900,
	IMPOSSIBLE = 2500,
	SECRET = 2000,
	REALITY_BREAKER = 10000,
}

local INDEX_MILESTONE_BONUSES = {
	{ Count = 0, Bonus = 1.00 },
	{ Count = 5, Bonus = 1.02 },
	{ Count = 10, Bonus = 1.05 },
	{ Count = 25, Bonus = 1.10 },
	{ Count = 50, Bonus = 1.15 },
	{ Count = 100, Bonus = 1.25 },
	{ Count = 250, Bonus = 1.40 },
	{ Count = 500, Bonus = 1.60 },
	{ Count = 1000, Bonus = 2.00 },
	{ Count = 2500, Bonus = 2.50 },
	{ Count = 5000, Bonus = 3.00 },
}

local INDEX_LEVEL_THRESHOLDS = {
	[1] = 0,
	[2] = 25,
	[3] = 75,
	[4] = 150,
	[5] = 300,
}

local RARITY_ORDER = {
	"COMMON",
	"UNCOMMON",
	"SMART",
	"SKILLED",
	"ADVANCED",
	"EXPERT",
	"GENIUS",
	"PRODIGY",
	"SUPER_GENIUS",
	"MASTERMIND",
	"LEGENDARY",
	"MYTHIC",
	"TRANSCENDENT",
	"IMPOSSIBLE",
	"SECRET",
	"REALITY_BREAKER",
}

local function clampNumber(value, minValue, maxValue)
	value = tonumber(value) or 0

	if value < minValue then
		return minValue
	end

	if value > maxValue then
		return maxValue
	end

	return value
end

local function createIntValue(parent, name, defaultValue)
	local value = parent:FindFirstChild(name)

	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Value = defaultValue or 0
		value.Parent = parent
	end

	return value
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function getLeaderstats(player)
	return getOrCreateFolder(player, "leaderstats")
end

local function getRunStats(player)
	return getOrCreateFolder(player, "RunStats")
end

local function getConceptIndex(player)
	return getOrCreateFolder(player, "ConceptIndex")
end

local function getRecentConceptsFolder(player)
	return getOrCreateFolder(player, "RecentConcepts")
end

local function getIQValue(player)
	return createIntValue(getRunStats(player), "IQ", 0)
end

local function getWinsValue(player)
	return createIntValue(getLeaderstats(player), "Wins", 0)
end

local function getLuckLevelValue(player)
	return createIntValue(getLeaderstats(player), "LuckLevel", 0)
end

local function getKnowledgePointsValue(player)
	return createIntValue(getLeaderstats(player), "KnowledgePoints", 0)
end

local function getRebirthsValue(player)
	return createIntValue(getLeaderstats(player), "Rebirths", 0)
end

local function getRollMultiplierValue(player)
	return createIntValue(getLeaderstats(player), "RollMultiplier", 1)
end

local function getAutoRollLevelValue(player)
	return createIntValue(getLeaderstats(player), "AutoRollLevel", 0)
end

local function clearChildren(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

function GameLogic.BindSessionPersistence(accessors)
	if type(accessors) ~= "table" then
		sessionPersistence = nil
		return
	end

	sessionPersistence = accessors
end

local function getIndexLevelFromKP(kp)
	kp = math.max(0, math.floor(tonumber(kp) or 0))

	if kp < 25 then
		return 1
	end

	if kp < 75 then
		return 2
	end

	if kp < 150 then
		return 3
	end

	if kp < 300 then
		return 4
	end

	return 5 + math.floor((kp - 300) / 250)
end

local function getMinimumKPForIndexLevel(level)
	level = math.max(1, math.floor(tonumber(level) or 1))

	if INDEX_LEVEL_THRESHOLDS[level] then
		return INDEX_LEVEL_THRESHOLDS[level]
	end

	return 300 + ((level - 5) * 250)
end

local function createRecentItem(conceptId, name, rarity, discoveredAt)
	return {
		ConceptId = tostring(conceptId or ""),
		Name = tostring(name or "Unknown Concept"),
		Rarity = tostring(rarity or "COMMON"),
		DiscoveredAt = tonumber(discoveredAt) or DateTime.now().UnixTimestampMillis,
	}
end

local function addRecentConcept(player, concept)
	if type(concept) ~= "table" then
		return
	end

	local folder = getRecentConceptsFolder(player)
	local recentItem = Instance.new("StringValue")
	recentItem.Name = tostring(DateTime.now().UnixTimestampMillis)
	recentItem.Value = tostring(concept.Name or "Unknown Concept")
	recentItem:SetAttribute("ConceptId", tostring(concept.Id or ""))
	recentItem:SetAttribute("Rarity", tostring(concept.Rarity or "COMMON"))
	recentItem:SetAttribute("DiscoveredAt", DateTime.now().UnixTimestampMillis)
	recentItem.Parent = folder

	local items = folder:GetChildren()
	table.sort(items, function(a, b)
		return (tonumber(a:GetAttribute("DiscoveredAt")) or 0) > (tonumber(b:GetAttribute("DiscoveredAt")) or 0)
	end)

	for index = 26, #items do
		items[index]:Destroy()
	end
end

local function markConceptDiscovered(player, concept)
	if type(concept) ~= "table" or not concept.Id then
		return false
	end

	local conceptIndex = getConceptIndex(player)
	local conceptId = tostring(concept.Id)
	local existing = conceptIndex:FindFirstChild(conceptId)

	if existing then
		return false
	end

	local marker = Instance.new("BoolValue")
	marker.Name = conceptId
	marker.Value = true
	marker:SetAttribute("Name", tostring(concept.Name or "Unknown Concept"))
	marker:SetAttribute("Rarity", tostring(concept.Rarity or "COMMON"))
	marker:SetAttribute("DiscoveredAt", DateTime.now().UnixTimestampMillis)
	marker.Parent = conceptIndex

	addRecentConcept(player, concept)

	return true
end

function GameLogic.SetupPlayer(player)
	local leaderstats = getLeaderstats(player)
	local runStats = getRunStats(player)

	createIntValue(runStats, "IQ", 0)

	createIntValue(leaderstats, "Wins", 0)
	createIntValue(leaderstats, "LuckLevel", 0)
	createIntValue(leaderstats, "KnowledgePoints", 0)
	createIntValue(leaderstats, "Rebirths", 0)
	createIntValue(leaderstats, "RollMultiplier", 1)
	createIntValue(leaderstats, "AutoRollLevel", 0)

	getConceptIndex(player)
	getRecentConceptsFolder(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			GameLogic.ApplySpeed(player)
		end)
	end)

	if player.Character then
		task.defer(function()
			GameLogic.ApplySpeed(player)
		end)
	end
end

function GameLogic.GetIQ(player)
	return getIQValue(player).Value
end

function GameLogic.SetIQ(player, value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	getIQValue(player).Value = value
	GameLogic.ApplySpeed(player)
	return value
end

function GameLogic.AddIQ(player, amount)
	return GameLogic.SetIQ(player, GameLogic.GetIQ(player) + (tonumber(amount) or 0))
end

function GameLogic.GetWins(player)
	return getWinsValue(player).Value
end

function GameLogic.SetWins(player, value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	getWinsValue(player).Value = value
	return value
end

function GameLogic.AddWins(player, amount)
	return GameLogic.SetWins(player, GameLogic.GetWins(player) + (tonumber(amount) or 0))
end

function GameLogic.GetLuckLevel(player)
	return getLuckLevelValue(player).Value
end

function GameLogic.SetLuckLevel(player, value)
	value = clampNumber(math.floor(tonumber(value) or 0), 0, MAX_LUCK_LEVEL)
	getLuckLevelValue(player).Value = value
	return value
end

function GameLogic.GetKnowledgePoints(player)
	return getKnowledgePointsValue(player).Value
end

function GameLogic.SetKnowledgePoints(player, value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	getKnowledgePointsValue(player).Value = value
	return value
end

function GameLogic.AddKnowledgePoints(player, amount)
	return GameLogic.SetKnowledgePoints(player, GameLogic.GetKnowledgePoints(player) + (tonumber(amount) or 0))
end

function GameLogic.ApplyQuestReward(player, reward)
	if type(reward) ~= "table" then
		return false, "InvalidReward"
	end

	local rewardType = tostring(reward.Type or "")
	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))

	if amount <= 0 then
		return false, "InvalidAmount"
	end

	if rewardType == "IQ" then
		GameLogic.AddIQ(player, amount)
		return true, "IQ", amount
	end

	if rewardType == "KP" or rewardType == "KnowledgePoints" then
		GameLogic.AddKnowledgePoints(player, amount)
		return true, "KP", amount
	end

	return false, "UnsupportedReward"
end

function GameLogic.GetRebirths(player)
	return getRebirthsValue(player).Value
end

function GameLogic.SetRebirths(player, value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	getRebirthsValue(player).Value = value
	return value
end

function GameLogic.GetRollMultiplier(player)
	return getRollMultiplierValue(player).Value
end

function GameLogic.GetAutoRollLevel(player)
	return getAutoRollLevelValue(player).Value
end

function GameLogic.SetAutoRollLevel(player, value)
	value = clampNumber(math.floor(tonumber(value) or 0), 0, MAX_AUTO_ROLL_LEVEL)
	getAutoRollLevelValue(player).Value = value
	return value
end

function GameLogic.GetAutoRollUpgradeCost(player)
	local level = GameLogic.GetAutoRollLevel(player)

	if level >= MAX_AUTO_ROLL_LEVEL then
		return nil
	end

	return AUTO_ROLL_COSTS[level + 1]
end

function GameLogic.GetAutoRollDelay(player)
	local level = GameLogic.GetAutoRollLevel(player)

	if level <= 0 then
		return nil
	end

	return AUTO_ROLL_DELAYS[level] or AUTO_ROLL_DELAYS[MAX_AUTO_ROLL_LEVEL]
end

function GameLogic.TryUpgradeAutoRoll(player)
	local currentLevel = GameLogic.GetAutoRollLevel(player)

	if currentLevel >= MAX_AUTO_ROLL_LEVEL then
		return false, "Max", currentLevel, nil, GameLogic.GetAutoRollDelay(player)
	end

	local cost = GameLogic.GetAutoRollUpgradeCost(player)
	local wins = GameLogic.GetWins(player)

	if wins < cost then
		return false, "NeedWins", currentLevel, cost, GameLogic.GetAutoRollDelay(player)
	end

	GameLogic.SetWins(player, wins - cost)
	local newLevel = GameLogic.SetAutoRollLevel(player, currentLevel + 1)

	return true, "Upgraded", newLevel, GameLogic.GetAutoRollUpgradeCost(player), GameLogic.GetAutoRollDelay(player)
end

function GameLogic.GetLuckUpgradeCost(player)
	local level = GameLogic.GetLuckLevel(player)

	if level >= MAX_LUCK_LEVEL then
		return nil
	end

	return math.floor(LUCK_UPGRADE_BASE_COST * ((level + 1) ^ 1.45))
end

function GameLogic.TryUpgradeLuck(player)
	local level = GameLogic.GetLuckLevel(player)

	if level >= MAX_LUCK_LEVEL then
		return false, "Max", level, nil
	end

	local cost = GameLogic.GetLuckUpgradeCost(player)

	if GameLogic.GetWins(player) < cost then
		return false, "NeedWins", level, cost
	end

	GameLogic.SetWins(player, GameLogic.GetWins(player) - cost)
	local newLevel = GameLogic.SetLuckLevel(player, level + 1)

	return true, "Upgraded", newLevel, GameLogic.GetLuckUpgradeCost(player)
end

function GameLogic.GetIndexLevel(player)
	return getIndexLevelFromKP(GameLogic.GetKnowledgePoints(player))
end

function GameLogic.GetIndexIQMultiplier(player)
	local level = GameLogic.GetIndexLevel(player)
	local multiplier = 1 + ((level - 1) * 0.05)

	if multiplier > MAX_INDEX_IQ_MULTIPLIER then
		multiplier = MAX_INDEX_IQ_MULTIPLIER
	end

	return multiplier
end

function GameLogic.CalculateIndexMilestoneBonus(discoveredCount)
	discoveredCount = math.max(0, math.floor(tonumber(discoveredCount) or 0))

	local currentMilestone = INDEX_MILESTONE_BONUSES[1]
	local nextMilestone = nil

	for _, milestone in ipairs(INDEX_MILESTONE_BONUSES) do
		if discoveredCount >= milestone.Count then
			currentMilestone = milestone
		elseif not nextMilestone then
			nextMilestone = milestone
			break
		end
	end

	return {
		DiscoveredCount = discoveredCount,
		CurrentMilestone = currentMilestone.Count,
		CurrentBonus = currentMilestone.Bonus,
		NextMilestone = nextMilestone and nextMilestone.Count or nil,
		NextBonus = nextMilestone and nextMilestone.Bonus or nil,
	}
end

function GameLogic.GetIndexMilestoneBonus(player)
	return GameLogic.CalculateIndexMilestoneBonus(GameLogic.GetDiscoveredConceptCount(player))
end

function GameLogic.CalculateWalkSpeed(iq)
	iq = math.max(0, tonumber(iq) or 0)
	return math.clamp(BASE_WALK_SPEED + (math.sqrt(iq) * 0.35), BASE_WALK_SPEED, MAX_WALK_SPEED)
end

function GameLogic.ApplySpeed(player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = GameLogic.CalculateWalkSpeed(GameLogic.GetIQ(player))
end

function GameLogic.IsAlive(player)
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	return humanoid.Health > 0
end

function GameLogic.TeleportToSpawn(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	local spawnPart = simpleMap and simpleMap:FindFirstChild("SpawnLocation", true)

	if not spawnPart then
		spawnPart = Workspace:FindFirstChild("SpawnLocation")
	end

	local position = Vector3.new(0, 5, 0)

	if spawnPart and spawnPart:IsA("BasePart") then
		position = spawnPart.Position + Vector3.new(0, 5, 0)
	end

	root.CFrame = CFrame.new(position)
end

function GameLogic.TryClaimWinPad(player, winPad)
	if not winPad or not winPad:IsA("BasePart") then
		return false, "InvalidWinPad", 0
	end

	local requiredIQ = tonumber(winPad:GetAttribute("RequiredIQ")) or 0
	local rewardWins = tonumber(winPad:GetAttribute("RewardWins")) or 1
	local currentIQ = GameLogic.GetIQ(player)

	if currentIQ < requiredIQ then
		return false, "Need " .. tostring(requiredIQ) .. " IQ", 0
	end

	GameLogic.AddWins(player, rewardWins)

	return true, "Claimed", rewardWins
end

function GameLogic.RollIQ(player, rollOptions)
	rollOptions = type(rollOptions) == "table" and rollOptions or {}

	local luckLevel = GameLogic.GetLuckLevel(player)
	local effectiveLuckLevel = luckLevel
	local brainSurgeActive = rollOptions.BrainSurgeActive == true
	local brainSurgeMultiplier = tonumber(rollOptions.LuckMultiplier) or 1

	if brainSurgeActive then
		effectiveLuckLevel = math.min(luckLevel * brainSurgeMultiplier, MAX_LUCK_LEVEL)
	end

	local rollResult = ConceptGenerator.RollConcept(effectiveLuckLevel)
	local concept = rollResult.Concept
	local baseIQ = tonumber(rollResult.BaseIQ) or 1

	if type(concept) ~= "table" then
		error("ConceptGenerator.RollConcept returned invalid concept")
	end

	local previousIndexLevel = GameLogic.GetIndexLevel(player)
	local previousDiscoveredCount = GameLogic.GetDiscoveredConceptCount(player)
	local previousMilestoneInfo = GameLogic.CalculateIndexMilestoneBonus(previousDiscoveredCount)
	local isNewConcept = markConceptDiscovered(player, concept)
	local kpReward = 0

	if isNewConcept then
		kpReward = KNOWLEDGE_POINTS_REWARD[tostring(concept.Rarity or "COMMON")] or 0
		if kpReward > 0 then
			GameLogic.AddKnowledgePoints(player, kpReward)
		end
	end

	local indexMultiplier = GameLogic.GetIndexIQMultiplier(player)
	local milestoneInfo = GameLogic.GetIndexMilestoneBonus(player)
	local milestoneMultiplier = tonumber(milestoneInfo.CurrentBonus) or 1
	local gainedIQ = math.max(1, math.floor(baseIQ * indexMultiplier * milestoneMultiplier))
	local newIQ = GameLogic.AddIQ(player, gainedIQ)
	local milestoneReached = milestoneInfo.CurrentMilestone > previousMilestoneInfo.CurrentMilestone

	return {
		NewIQ = newIQ,
		GainedIQ = gainedIQ,
		BaseIQ = baseIQ,
		ConceptName = tostring(concept.Name or "Unknown Concept"),
		Rarity = tostring(concept.Rarity or "COMMON"),
		ConceptId = tostring(concept.Id or ""),
		IsNewConcept = isNewConcept,
		LuckLevel = luckLevel,
		EffectiveLuckLevel = effectiveLuckLevel,
		BrainSurgeActive = brainSurgeActive,
		BrainSurgeMultiplier = brainSurgeMultiplier,
		KnowledgePointsReward = kpReward,
		KnowledgePoints = GameLogic.GetKnowledgePoints(player),
		IndexLevel = GameLogic.GetIndexLevel(player),
		IndexIQMultiplier = GameLogic.GetIndexIQMultiplier(player),
		PreviousIndexLevel = previousIndexLevel,
		IndexMilestoneBonus = milestoneInfo.CurrentBonus,
		CurrentIndexMilestone = milestoneInfo.CurrentMilestone,
		NextIndexMilestone = milestoneInfo.NextMilestone,
		NextIndexMilestoneBonus = milestoneInfo.NextBonus,
		IndexMilestoneReached = milestoneReached,
	}
end

function GameLogic.GetDiscoveredConceptCount(player)
	return #getConceptIndex(player):GetChildren()
end

function GameLogic.GetDiscoveredConceptCountByRarity(player)
	local counts = {}

	for _, rarity in ipairs(RARITY_ORDER) do
		counts[rarity] = 0
	end

	for _, marker in ipairs(getConceptIndex(player):GetChildren()) do
		local rarity = marker:GetAttribute("Rarity") or "COMMON"
		counts[rarity] = (counts[rarity] or 0) + 1
	end

	return counts
end

function GameLogic.GetRecentDiscoveredConcepts(player, limit)
	limit = tonumber(limit) or 5

	local items = getRecentConceptsFolder(player):GetChildren()
	table.sort(items, function(a, b)
		return (tonumber(a:GetAttribute("DiscoveredAt")) or 0) > (tonumber(b:GetAttribute("DiscoveredAt")) or 0)
	end)

	local result = {}

	for index = 1, math.min(limit, #items) do
		local item = items[index]
		table.insert(result, {
			ConceptId = tostring(item:GetAttribute("ConceptId") or ""),
			Name = tostring(item.Value or item.Name),
			Rarity = tostring(item:GetAttribute("Rarity") or "COMMON"),
			DiscoveredAt = tonumber(item:GetAttribute("DiscoveredAt")) or 0,
		})
	end

	return result
end

function GameLogic.ClearRecentConcepts(player)
	clearChildren(getRecentConceptsFolder(player))
end

function GameLogic.AdminDiscoverRandomConcepts(player, amount)
	amount = math.clamp(math.floor(tonumber(amount) or 10), 1, 50)

	local discovered = 0

	for _ = 1, amount do
		local rollResult = ConceptGenerator.RollConcept(GameLogic.GetLuckLevel(player))
		local concept = rollResult and rollResult.Concept

		if concept and markConceptDiscovered(player, concept) then
			discovered += 1
		end
	end

	return discovered
end

function GameLogic.AdminAddIQ(player, amount)
	return GameLogic.AddIQ(player, amount)
end

function GameLogic.AdminSetIQ(player, value)
	return GameLogic.SetIQ(player, value)
end

function GameLogic.AdminAddWins(player, amount)
	return GameLogic.AddWins(player, amount)
end

function GameLogic.AdminSetWins(player, value)
	return GameLogic.SetWins(player, value)
end

function GameLogic.AdminAddKnowledgePoints(player, amount)
	return GameLogic.AddKnowledgePoints(player, amount)
end

function GameLogic.AdminSetKnowledgePoints(player, value)
	return GameLogic.SetKnowledgePoints(player, value)
end

function GameLogic.AdminAddLuckLevel(player, amount)
	return GameLogic.SetLuckLevel(player, GameLogic.GetLuckLevel(player) + (tonumber(amount) or 0))
end

function GameLogic.AdminSetLuckLevel(player, value)
	return GameLogic.SetLuckLevel(player, value)
end

function GameLogic.AdminAddAutoRollLevel(player, amount)
	return GameLogic.SetAutoRollLevel(player, GameLogic.GetAutoRollLevel(player) + (tonumber(amount) or 0))
end

function GameLogic.AdminSetAutoRollLevel(player, value)
	return GameLogic.SetAutoRollLevel(player, value)
end

function GameLogic.AdminAddIndexLevel(player, amount)
	local targetLevel = GameLogic.GetIndexLevel(player) + (tonumber(amount) or 0)
	targetLevel = math.max(1, math.floor(targetLevel))
	return GameLogic.SetKnowledgePoints(player, getMinimumKPForIndexLevel(targetLevel))
end

function GameLogic.AdminSetIndexLevel(player, level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	return GameLogic.SetKnowledgePoints(player, getMinimumKPForIndexLevel(level))
end

function GameLogic.ResetTestData(player)
	GameLogic.SetIQ(player, 0)
	GameLogic.SetWins(player, 0)
	GameLogic.SetLuckLevel(player, 0)
	GameLogic.SetKnowledgePoints(player, 0)
	GameLogic.SetRebirths(player, 0)
	GameLogic.SetAutoRollLevel(player, 0)

	clearChildren(getConceptIndex(player))
	clearChildren(getRecentConceptsFolder(player))

	if sessionPersistence and type(sessionPersistence.ResetPlayerData) == "function" then
		sessionPersistence.ResetPlayerData(player)
	end

	GameLogic.ApplySpeed(player)
end

function GameLogic.ExportPlayerData(player)
	local discoveredIds = {}

	for _, marker in ipairs(getConceptIndex(player):GetChildren()) do
		table.insert(discoveredIds, marker.Name)
	end

	table.sort(discoveredIds)

	local exported = {
		Version = 3,
		IQ = GameLogic.GetIQ(player),
		Wins = GameLogic.GetWins(player),
		LuckLevel = GameLogic.GetLuckLevel(player),
		KnowledgePoints = GameLogic.GetKnowledgePoints(player),
		Rebirths = GameLogic.GetRebirths(player),
		AutoRollLevel = GameLogic.GetAutoRollLevel(player),
		DiscoveredConceptIds = discoveredIds,
		RecentConcepts = GameLogic.GetRecentDiscoveredConcepts(player, 25),
	}

	if sessionPersistence and type(sessionPersistence.ExportPlayerData) == "function" then
		local sessionData = sessionPersistence.ExportPlayerData(player)

		if type(sessionData) == "table" then
			exported.ChestPoints = sessionData.ChestPoints
			exported.ChestTotalOpened = sessionData.ChestTotalOpened
			exported.Quests = sessionData.Quests
		end
	end

	return exported
end

function GameLogic.ImportPlayerData(player, data)
	if type(data) ~= "table" then
		return
	end

	GameLogic.SetIQ(player, data.IQ or 0)
	GameLogic.SetWins(player, data.Wins or 0)
	GameLogic.SetLuckLevel(player, data.LuckLevel or 0)
	GameLogic.SetKnowledgePoints(player, data.KnowledgePoints or 0)
	GameLogic.SetRebirths(player, data.Rebirths or 0)
	GameLogic.SetAutoRollLevel(player, data.AutoRollLevel or 0)

	local conceptIndex = getConceptIndex(player)
	clearChildren(conceptIndex)

	if type(data.DiscoveredConceptIds) == "table" then
		for _, conceptId in ipairs(data.DiscoveredConceptIds) do
			local marker = Instance.new("BoolValue")
			marker.Name = tostring(conceptId)
			marker.Value = true

			local concept = nil
			if type(ConceptGenerator.GetConceptById) == "function" then
				concept = ConceptGenerator.GetConceptById(conceptId)
			end

			if concept then
				marker:SetAttribute("Name", tostring(concept.Name or "Unknown Concept"))
				marker:SetAttribute("Rarity", tostring(concept.Rarity or "COMMON"))
			end

			marker.Parent = conceptIndex
		end
	end

	local recentFolder = getRecentConceptsFolder(player)
	clearChildren(recentFolder)

	if type(data.RecentConcepts) == "table" then
		for _, item in ipairs(data.RecentConcepts) do
			local recent = createRecentItem(item.ConceptId, item.Name, item.Rarity, item.DiscoveredAt)
			local value = Instance.new("StringValue")
			value.Name = tostring(recent.DiscoveredAt)
			value.Value = recent.Name
			value:SetAttribute("ConceptId", recent.ConceptId)
			value:SetAttribute("Rarity", recent.Rarity)
			value:SetAttribute("DiscoveredAt", recent.DiscoveredAt)
			value.Parent = recentFolder
		end
	end

	if sessionPersistence and type(sessionPersistence.ImportPlayerData) == "function" then
		sessionPersistence.ImportPlayerData(player, data)
	end

	GameLogic.ApplySpeed(player)
end

return GameLogic
