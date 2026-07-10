local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local DataManager = {}

local DATASTORE_NAME = "BrainRNG_PlayerData_v1"
local DATA_VERSION = 3
local LOCK_TIMEOUT_SECONDS = 300
local SAVE_RETRY_COUNT = 3
local SAVE_RETRY_DELAY = 1.5

local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local sessionId = game.JobId

if sessionId == "" then
	sessionId = "Studio-" .. HttpService:GenerateGUID(false)
end

local loadedProfiles = {}
local loadErrors = {}
local persistenceAudits = {}
local gameLogic = nil

local function now()
	return os.time()
end

local function defaultData()
	return {
		Version = DATA_VERSION,
		IQ = 0,
		Wins = 0,
		LuckLevel = 0,
		KnowledgePoints = 0,
		Rebirths = 0,
		AutoRollLevel = 0,
		ChestPoints = 0,
		ChestTotalOpened = 0,
		Quests = {
			Progress = {},
			Completed = {},
			Claimed = {},
		},
		DiscoveredConceptIds = {},
		RecentConcepts = {},
		LastSavedAt = 0,
		SessionLock = nil,
	}
end

local function readNested(data, path)
	local current = data

	for _, key in ipairs(path) do
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
	end

	return current
end

local function readNumber(data, paths, defaultValue)
	if type(data) ~= "table" then
		return defaultValue or 0
	end

	for _, path in ipairs(paths) do
		local value

		if type(path) == "table" then
			value = readNested(data, path)
		else
			value = data[path]
		end

		value = tonumber(value)

		if value ~= nil then
			return value
		end
	end

	return defaultValue or 0
end

local function countTableEntries(value)
	if type(value) ~= "table" then
		return 0
	end

	local count = 0
	for _ in pairs(value) do
		count += 1
	end

	return count
end

local function countTrueEntries(value)
	if type(value) ~= "table" then
		return 0
	end

	local count = 0
	for _, entry in pairs(value) do
		if entry == true then
			count += 1
		end
	end

	return count
end

local function summarizePersistenceData(data)
	data = type(data) == "table" and data or {}

	local quests = type(data.Quests) == "table" and data.Quests or {}
	local progress = type(quests.Progress) == "table" and quests.Progress or {}
	local completed = type(quests.Completed) == "table" and quests.Completed or {}
	local claimed = type(quests.Claimed) == "table" and quests.Claimed or {}

	return {
		ChestPoints = math.max(0, math.floor(readNumber(data, { "ChestPoints", "CP", { "Chest", "CP" }, { "Chest", "ChestPoints" }, { "Chest", "Points" } }, 0))),
		ChestTotalOpened = math.max(0, math.floor(readNumber(data, { "ChestTotalOpened", { "Chest", "TotalOpened" }, { "Chest", "ChestTotalOpened" }, "TotalChestsOpened" }, 0))),
		QuestProgressCount = countTableEntries(progress),
		QuestCompletedCount = countTrueEntries(completed),
		QuestClaimedCount = countTrueEntries(claimed),
	}
end

local function formatSummary(summary)
	summary = type(summary) == "table" and summary or {}

	return "CP=" .. tostring(summary.ChestPoints or 0)
		.. " TotalOpened=" .. tostring(summary.ChestTotalOpened or 0)
		.. " QuestProgressCount=" .. tostring(summary.QuestProgressCount or 0)
		.. " QuestCompletedCount=" .. tostring(summary.QuestCompletedCount or 0)
		.. " QuestClaimedCount=" .. tostring(summary.QuestClaimedCount or 0)
end

local function cloneSummary(summary)
	if type(summary) ~= "table" then
		return nil
	end

	return {
		ChestPoints = summary.ChestPoints,
		ChestTotalOpened = summary.ChestTotalOpened,
		QuestProgressCount = summary.QuestProgressCount,
		QuestCompletedCount = summary.QuestCompletedCount,
		QuestClaimedCount = summary.QuestClaimedCount,
	}
end

local function normalizeDiscoveredConceptIds(data)
	local result = {}
	local seen = {}

	local function addConceptId(value)
		if type(value) ~= "string" then
			return
		end

		if value == "" then
			return
		end

		if seen[value] then
			return
		end

		seen[value] = true
		table.insert(result, value)
	end

	if type(data.DiscoveredConceptIds) == "table" then
		for _, conceptId in ipairs(data.DiscoveredConceptIds) do
			addConceptId(conceptId)
		end

		for conceptId, discovered in pairs(data.DiscoveredConceptIds) do
			if discovered == true then
				addConceptId(conceptId)
			end
		end
	end

	if type(data.ConceptIndex) == "table" then
		for _, conceptId in ipairs(data.ConceptIndex) do
			addConceptId(conceptId)
		end

		for conceptId, discovered in pairs(data.ConceptIndex) do
			if discovered == true or type(discovered) == "table" then
				addConceptId(conceptId)
			end
		end
	end

	if type(data.Index) == "table" then
		for _, conceptId in ipairs(data.Index) do
			addConceptId(conceptId)
		end

		for conceptId, discovered in pairs(data.Index) do
			if discovered == true or type(discovered) == "table" then
				addConceptId(conceptId)
			end
		end
	end

	table.sort(result)

	return result
end

local function normalizeRecentConcepts(source)
	local result = {}

	if type(source) ~= "table" then
		return result
	end

	for _, item in ipairs(source) do
		if #result >= 25 then
			break
		end

		if type(item) == "table" then
			table.insert(result, {
				ConceptId = tostring(item.ConceptId or ""),
				Name = tostring(item.Name or "Unknown Concept"),
				Rarity = tostring(item.Rarity or "COMMON"),
				DiscoveredAt = tonumber(item.DiscoveredAt) or 0,
			})
		end
	end

	return result
end

local function normalizeQuestDictionary(source, valueType)
	local result = {}

	if type(source) ~= "table" then
		return result
	end

	for questId, value in pairs(source) do
		if type(questId) == "string" and questId ~= "" then
			if valueType == "number" then
				result[questId] = math.max(0, math.floor(tonumber(value) or 0))
			elseif valueType == "boolean" then
				result[questId] = value == true
			end
		end
	end

	return result
end

local LEGACY_QUEST_FIELDS = {
	Progress = { "Progress", "progress" },
	Completed = { "Completed", "completed" },
	Claimed = { "Claimed", "claimed" },
	Id = { "Id", "id", "QuestId", "questId" },
}

local function readLegacyQuestField(entry, fieldName)
	if type(entry) ~= "table" then
		return nil
	end

	for _, key in ipairs(LEGACY_QUEST_FIELDS[fieldName] or {}) do
		if entry[key] ~= nil then
			return entry[key]
		end
	end

	return nil
end

local function normalizeLegacyQuestEntry(result, questId, entry)
	if type(questId) ~= "string" or questId == "" or type(entry) ~= "table" then
		return
	end

	local progress = readLegacyQuestField(entry, "Progress")
	if result.Progress[questId] == nil and progress ~= nil then
		result.Progress[questId] = math.max(0, math.floor(tonumber(progress) or 0))
	end

	local completed = readLegacyQuestField(entry, "Completed")
	if result.Completed[questId] == nil and completed ~= nil then
		result.Completed[questId] = completed == true
	end

	local claimed = readLegacyQuestField(entry, "Claimed")
	if result.Claimed[questId] == nil and claimed ~= nil then
		result.Claimed[questId] = claimed == true
	end
end

local function normalizeQuests(source)
	source = type(source) == "table" and source or {}

	local result = {
		Progress = normalizeQuestDictionary(source.Progress, "number"),
		Completed = normalizeQuestDictionary(source.Completed, "boolean"),
		Claimed = normalizeQuestDictionary(source.Claimed, "boolean"),
	}

	for key, value in pairs(source) do
		if key ~= "Progress" and key ~= "Completed" and key ~= "Claimed" then
			if type(key) == "string" then
				normalizeLegacyQuestEntry(result, key, value)
			elseif type(value) == "table" then
				local questId = readLegacyQuestField(value, "Id")
				normalizeLegacyQuestEntry(result, tostring(questId or ""), value)
			end
		end
	end

	return result
end

local function hasLegacyQuestEntryProgress(entry)
	if type(entry) ~= "table" then
		return false
	end

	if (tonumber(readLegacyQuestField(entry, "Progress")) or 0) > 0 then
		return true
	end

	if readLegacyQuestField(entry, "Completed") == true then
		return true
	end

	if readLegacyQuestField(entry, "Claimed") == true then
		return true
	end

	return false
end

local function hasQuestProgress(quests)
	if type(quests) ~= "table" then
		return false
	end

	if type(quests.Progress) == "table" then
		for _, value in pairs(quests.Progress) do
			if (tonumber(value) or 0) > 0 then
				return true
			end
		end
	end

	if type(quests.Completed) == "table" then
		for _, value in pairs(quests.Completed) do
			if value == true then
				return true
			end
		end
	end

	if type(quests.Claimed) == "table" then
		for _, value in pairs(quests.Claimed) do
			if value == true then
				return true
			end
		end
	end

	for key, value in pairs(quests) do
		if key ~= "Progress" and key ~= "Completed" and key ~= "Claimed" then
			if hasLegacyQuestEntryProgress(value) then
				return true
			end
		end
	end

	return false
end

local function hasProgress(data)
	if type(data) ~= "table" then
		return false
	end

	if readNumber(data, { "IQ", { "RunStats", "IQ" }, { "Stats", "IQ" } }, 0) > 0 then
		return true
	end

	if readNumber(data, { "Wins", { "leaderstats", "Wins" }, { "Leaderstats", "Wins" } }, 0) > 0 then
		return true
	end

	if readNumber(data, { "LuckLevel", "Luck" }, 0) > 0 then
		return true
	end

	if readNumber(data, { "KnowledgePoints", "KP", "IndexKP" }, 0) > 0 then
		return true
	end

	if readNumber(data, { "Rebirths" }, 0) > 0 then
		return true
	end

	if readNumber(data, { "AutoRollLevel" }, 0) > 0 then
		return true
	end

	if readNumber(data, { "ChestPoints", "CP", { "Chest", "CP" }, { "Chest", "ChestPoints" }, { "Chest", "Points" } }, 0) > 0 then
		return true
	end

	if readNumber(data, { "ChestTotalOpened", { "Chest", "TotalOpened" }, { "Chest", "ChestTotalOpened" }, "TotalChestsOpened" }, 0) > 0 then
		return true
	end

	if hasQuestProgress(data.Quests) then
		return true
	end

	if type(data.DiscoveredConceptIds) == "table" and countTableEntries(data.DiscoveredConceptIds) > 0 then
		return true
	end

	if type(data.ConceptIndex) == "table" and countTableEntries(data.ConceptIndex) > 0 then
		return true
	end

	if type(data.Index) == "table" and countTableEntries(data.Index) > 0 then
		return true
	end

	if (tonumber(data.DiscoveredConcepts) or 0) > 0 then
		return true
	end

	return false
end

local function isEmptyProgress(data)
	if type(data) ~= "table" then
		return true
	end

	return (tonumber(data.IQ) or 0) <= 0
		and (tonumber(data.Wins) or 0) <= 0
		and (tonumber(data.LuckLevel) or 0) <= 0
		and (tonumber(data.KnowledgePoints) or 0) <= 0
		and (tonumber(data.Rebirths) or 0) <= 0
		and (tonumber(data.AutoRollLevel) or 0) <= 0
		and (tonumber(data.ChestPoints) or 0) <= 0
		and (tonumber(data.ChestTotalOpened) or 0) <= 0
		and not hasQuestProgress(data.Quests)
		and (type(data.DiscoveredConceptIds) ~= "table" or #data.DiscoveredConceptIds <= 0)
end

local function normalizeData(data)
	local normalized = defaultData()

	if type(data) ~= "table" then
		return normalized
	end

	normalized.Version = DATA_VERSION
	normalized.IQ = math.max(math.floor(readNumber(data, { "IQ", { "RunStats", "IQ" }, { "Stats", "IQ" } }, 0)), 0)
	normalized.Wins = math.max(math.floor(readNumber(data, { "Wins", { "leaderstats", "Wins" }, { "Leaderstats", "Wins" } }, 0)), 0)
	normalized.LuckLevel = math.max(math.floor(readNumber(data, { "LuckLevel", "Luck" }, 0)), 0)
	normalized.KnowledgePoints = math.max(math.floor(readNumber(data, { "KnowledgePoints", "KP", "IndexKP" }, 0)), 0)
	normalized.Rebirths = math.max(math.floor(readNumber(data, { "Rebirths" }, 0)), 0)
	normalized.AutoRollLevel = math.clamp(math.floor(readNumber(data, { "AutoRollLevel" }, 0)), 0, 5)
	normalized.ChestPoints = math.max(math.floor(readNumber(data, { "ChestPoints", "CP", { "Chest", "CP" }, { "Chest", "ChestPoints" }, { "Chest", "Points" } }, 0)), 0)
	normalized.ChestTotalOpened = math.max(math.floor(readNumber(data, { "ChestTotalOpened", { "Chest", "TotalOpened" }, { "Chest", "ChestTotalOpened" }, "TotalChestsOpened" }, 0)), 0)
	normalized.Quests = normalizeQuests(data.Quests)
	normalized.DiscoveredConceptIds = normalizeDiscoveredConceptIds(data)
	normalized.RecentConcepts = normalizeRecentConcepts(data.RecentConcepts)
	normalized.LastSavedAt = tonumber(data.LastSavedAt) or 0

	if type(data.SessionLock) == "table" then
		normalized.SessionLock = {
			SessionId = tostring(data.SessionLock.SessionId or ""),
			JobId = tostring(data.SessionLock.JobId or ""),
			LockedAt = tonumber(data.SessionLock.LockedAt) or 0,
			LockExpiresAt = tonumber(data.SessionLock.LockExpiresAt) or 0,
		}
	end

	return normalized
end

local function buildSaveSnapshot(player)
	local exportedData = normalizeData(gameLogic.ExportPlayerData(player))
	local summary = summarizePersistenceData(exportedData)

	return exportedData, summary
end

local function getKey(player)
	return "Player_" .. tostring(player.UserId)
end

local function isLockExpired(lock)
	if type(lock) ~= "table" then
		return true
	end

	local expiresAt = tonumber(lock.LockExpiresAt) or 0
	return expiresAt <= now()
end

local function isLockOwnedByCurrentSession(data)
	if type(data) ~= "table" then
		return false
	end

	local lock = data.SessionLock
	return type(lock) == "table"
		and tostring(lock.SessionId or "") == sessionId
		and not isLockExpired(lock)
end

local function isLockedByOtherSession(data)
	if type(data) ~= "table" then
		return false
	end

	local lock = data.SessionLock
	if type(lock) ~= "table" then
		return false
	end

	if isLockExpired(lock) then
		return false
	end

	return tostring(lock.SessionId or "") ~= sessionId
end

local function applyLock(data)
	data.SessionLock = {
		SessionId = sessionId,
		JobId = game.JobId,
		LockedAt = now(),
		LockExpiresAt = now() + LOCK_TIMEOUT_SECONDS,
	}
end

local function clearLock(data)
	data.SessionLock = nil
end

local function retryUpdateAsync(key, transform)
	local lastError = nil

	for attempt = 1, SAVE_RETRY_COUNT do
		local success, result = pcall(function()
			return dataStore:UpdateAsync(key, transform)
		end)

		if success then
			return true, result
		end

		lastError = result
		warn("[DataManager] UpdateAsync failed attempt", attempt, key, result)
		task.wait(SAVE_RETRY_DELAY)
	end

	return false, lastError
end

function DataManager.BindGameLogic(module)
	gameLogic = module
end

function DataManager.IsLoaded(player)
	local profile = loadedProfiles[player.UserId]
	return profile ~= nil and profile.Loaded == true
end

function DataManager.GetLoadError(player)
	return loadErrors[player.UserId]
end

function DataManager.LoadProfile(player)
	if not gameLogic then
		error("[DataManager] GameLogic is not bound. Call DataManager.BindGameLogic(GameLogic) first.")
	end

	local userId = player.UserId
	local key = getKey(player)
	local loadedData = nil
	local blockedByOtherLock = false
	local migrationBlocked = false
	local invalidOldData = false
	local rawLoadSummary = nil
	local normalizedLoadSummary = nil

	loadErrors[userId] = nil

	local success, result = retryUpdateAsync(key, function(oldData)
		if isLockedByOtherSession(oldData) then
			blockedByOtherLock = true
			return oldData
		end

		if oldData == nil then
			local data = defaultData()
			normalizedLoadSummary = summarizePersistenceData(data)
			applyLock(data)
			loadedData = data
			return data
		end

		if type(oldData) ~= "table" then
			invalidOldData = true
			return oldData
		end

		rawLoadSummary = summarizePersistenceData(oldData)
		local data = normalizeData(oldData)
		normalizedLoadSummary = summarizePersistenceData(data)

		if hasProgress(oldData) and isEmptyProgress(data) then
			migrationBlocked = true
			warn("[DataManager][BLOCKED] Refusing to normalize unknown progress data into empty data:", player.Name, key)
			return oldData
		end

		applyLock(data)
		loadedData = data
		return data
	end)

	if not success then
		loadErrors[userId] = "Data failed to load. Please rejoin."
		warn("[DataManager] LoadProfile failed:", player.Name, result)
		return false
	end

	if blockedByOtherLock then
		loadErrors[userId] = "Your data is open in another server. Please wait and rejoin."
		warn("[DataManager] Load blocked by another live session:", player.Name)
		return false
	end

	if invalidOldData then
		loadErrors[userId] = "Data format is invalid. Please contact support."
		warn("[DataManager] Invalid oldData format:", player.Name)
		return false
	end

	if migrationBlocked then
		loadErrors[userId] = "Data migration was blocked to protect your progress. Please contact support."
		return false
	end

	if not loadedData then
		loadErrors[userId] = "Data failed to load. Please rejoin."
		return false
	end

	loadedProfiles[userId] = {
		Loaded = true,
		Data = loadedData,
		LastSaveAt = now(),
	}

	persistenceAudits[userId] = persistenceAudits[userId] or {}
	persistenceAudits[userId].LastLoad = {
		At = now(),
		Raw = cloneSummary(rawLoadSummary),
		Normalized = cloneSummary(normalizedLoadSummary),
	}

	print("[PersistAudit] LoadRaw player=" .. player.Name .. " " .. formatSummary(rawLoadSummary))
	print("[PersistAudit] Normalize player=" .. player.Name .. " " .. formatSummary(normalizedLoadSummary))

	gameLogic.ImportPlayerData(player, loadedData)

	return true
end

function DataManager.SaveProfile(player, releaseLock, options)
	if not gameLogic then
		error("[DataManager] GameLogic is not bound. Call DataManager.BindGameLogic(GameLogic) first.")
	end

	options = options or {}

	local userId = player.UserId
	local profile = loadedProfiles[userId]

	if not profile or profile.Loaded ~= true then
		warn("[DataManager] SaveProfile skipped because profile is not loaded:", player.Name)
		return false
	end

	local key = getKey(player)
	local blockedByOtherLock = false
	local recoveredMissingLock = false
	local blockedEmptyOverwrite = false
	local allowEmptyOverwrite = options.AllowEmptyOverwrite == true
	local saveReason = tostring(options.Reason or "Unspecified")
	local exportedDataForAudit = nil
	local exportedSummary = nil
	local saveKind = "Normal"

	local success, result = retryUpdateAsync(key, function(oldData)
		if isLockedByOtherSession(oldData) then
			blockedByOtherLock = true
			return oldData
		end

		if not isLockOwnedByCurrentSession(oldData) then
			recoveredMissingLock = true
			saveKind = "Recovery"
			warn("[DataManager] Missing or expired lock. Recovering save for:", player.Name)
		end

		if recoveredMissingLock then
			print("[PersistAudit] RecoveryBeforeExport player=" .. player.Name .. " reason=" .. saveReason)
		end

		local exportedData, snapshotSummary = buildSaveSnapshot(player)
		exportedDataForAudit = exportedData
		exportedSummary = snapshotSummary

		if recoveredMissingLock then
			print("[PersistAudit] RecoveryAfterExport player=" .. player.Name .. " " .. formatSummary(exportedSummary))
		end

		if hasProgress(oldData) and isEmptyProgress(exportedData) and not allowEmptyOverwrite then
			blockedEmptyOverwrite = true
			warn("[DataManager][BLOCKED] Refusing to overwrite progress with empty data:", player.Name, key, saveReason)
			return oldData
		end

		exportedData.Version = DATA_VERSION
		exportedData.LastSavedAt = now()

		if releaseLock then
			clearLock(exportedData)
		else
			applyLock(exportedData)
		end

		if recoveredMissingLock then
			print("[PersistAudit] RecoverySavePayload player=" .. player.Name .. " " .. formatSummary(summarizePersistenceData(exportedData)))
		end

		return exportedData
	end)

	if not success then
		persistenceAudits[userId] = persistenceAudits[userId] or {}
		persistenceAudits[userId].LastSave = {
			At = now(),
			Reason = saveReason,
			Kind = saveKind,
			Success = false,
			Error = tostring(result),
			ExportBeforeSave = cloneSummary(exportedSummary),
			Payload = cloneSummary(exportedSummary),
		}
		warn("[PersistAudit] " .. (saveKind == "Recovery" and "RecoverySaveFail" or "SaveFail") .. " player=" .. player.Name .. " reason=" .. saveReason .. " err=" .. tostring(result))
		warn("[DataManager] SaveProfile failed:", player.Name, result)
		return false
	end

	if blockedByOtherLock then
		persistenceAudits[userId] = persistenceAudits[userId] or {}
		persistenceAudits[userId].LastSave = {
			At = now(),
			Reason = saveReason,
			Kind = saveKind,
			Success = false,
			Error = "LOCKED_BY_OTHER_SESSION",
			ExportBeforeSave = cloneSummary(exportedSummary),
			Payload = cloneSummary(exportedSummary),
		}
		warn("[PersistAudit] " .. (saveKind == "Recovery" and "RecoverySaveFail" or "SaveFail") .. " player=" .. player.Name .. " reason=" .. saveReason .. " err=LOCKED_BY_OTHER_SESSION")
		warn("[DataManager] Save blocked because another live session owns the lock:", player.Name)
		return false
	end

	if blockedEmptyOverwrite then
		persistenceAudits[userId] = persistenceAudits[userId] or {}
		persistenceAudits[userId].LastSave = {
			At = now(),
			Reason = saveReason,
			Kind = saveKind,
			Success = false,
			Error = "EMPTY_OVERWRITE_BLOCKED",
			ExportBeforeSave = cloneSummary(exportedSummary),
			Payload = cloneSummary(exportedSummary),
		}
		warn("[PersistAudit] " .. (saveKind == "Recovery" and "RecoverySaveFail" or "SaveFail") .. " player=" .. player.Name .. " reason=" .. saveReason .. " err=EMPTY_OVERWRITE_BLOCKED")
		warn("[DataManager] Save blocked to protect existing progress:", player.Name, saveReason)
		return false
	end

	if recoveredMissingLock then
		print("[PersistAudit] RecoverySaveOK player=" .. player.Name .. " reason=" .. saveReason .. " " .. formatSummary(exportedSummary))
		warn("[DataManager] Save recovered from missing or expired lock:", player.Name)
	end

	if exportedDataForAudit then
		profile.Data = exportedDataForAudit
	end

	profile.LastSaveAt = now()
	persistenceAudits[userId] = persistenceAudits[userId] or {}
	persistenceAudits[userId].LastSave = {
		At = profile.LastSaveAt,
		Reason = saveReason,
		Kind = saveKind,
		Success = true,
		ExportBeforeSave = cloneSummary(exportedSummary),
		Payload = cloneSummary(exportedSummary),
	}

	print("[PersistAudit] SaveOK player=" .. player.Name .. " reason=" .. saveReason .. " " .. formatSummary(exportedSummary))

	return true
end

function DataManager.GetPersistenceAuditSnapshot(player)
	local profile = loadedProfiles[player.UserId]
	local audit = persistenceAudits[player.UserId] or {}
	local profileSummary = nil

	if profile and profile.Loaded == true then
		profileSummary = summarizePersistenceData(profile.Data)
	end

	return {
		Loaded = profile ~= nil and profile.Loaded == true,
		LastSaveAt = profile and profile.LastSaveAt or nil,
		Profile = cloneSummary(profileSummary),
		LastLoad = audit.LastLoad,
		LastSave = audit.LastSave,
	}
end

function DataManager.ReleaseProfile(player)
	local userId = player.UserId
	local profile = loadedProfiles[userId]

	if not profile or profile.Loaded ~= true then
		loadedProfiles[userId] = nil
		persistenceAudits[userId] = nil
		return true
	end

	local saved = DataManager.SaveProfile(player, true)
	if not saved then
		warn("[DataManager][CRITICAL] ReleaseProfile failed:", player.Name)
		return false
	end

	loadedProfiles[userId] = nil
	persistenceAudits[userId] = nil
	return true
end

return DataManager
