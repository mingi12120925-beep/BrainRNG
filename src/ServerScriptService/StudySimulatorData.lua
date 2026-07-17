local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("StudySimulatorConfig"))

local StudySimulatorData = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local profiles = {}
local sessionId = game.JobId

if sessionId == "" then
	sessionId = "Studio-" .. HttpService:GenerateGUID(false)
end

local LOCK_TIMEOUT_SECONDS = 300
local RETRY_COUNT = 3
local RETRY_DELAY = 1.5

local function now()
	return os.time()
end

local function defaultData()
	return {
		Version = Config.DATA_VERSION,
		MicroIQ = 0,
		SchoolIndex = 1,
		DirectStudyRewards = 0,
		PartnerUnlocked = false,
		PartnerPowerPoints = 0,
		PartnerSpeedPoints = 0,
		PartnerUnspentPoints = 0,
		PartnerTrainingSeconds = 0,
		PartnerSpecialization = "",
		RespecSchoolIndex = 0,
		LastSeenTime = 0,
		SessionLock = nil,
	}
end

local function normalize(data)
	local result = defaultData()
	data = type(data) == "table" and data or {}

	result.Version = Config.DATA_VERSION
	result.MicroIQ = math.max(0, math.floor(tonumber(data.MicroIQ) or 0))
	result.SchoolIndex = math.clamp(math.floor(tonumber(data.SchoolIndex) or 1), 1, #Config.SCHOOLS)
	result.DirectStudyRewards = math.max(0, math.floor(tonumber(data.DirectStudyRewards) or 0))
	result.PartnerUnlocked = data.PartnerUnlocked == true or result.DirectStudyRewards >= Config.PARTNER_UNLOCK_REWARDS
	result.PartnerPowerPoints = math.clamp(math.floor(tonumber(data.PartnerPowerPoints) or 0), 0, 15)
	result.PartnerSpeedPoints = math.clamp(math.floor(tonumber(data.PartnerSpeedPoints) or 0), 0, 15)
	result.PartnerUnspentPoints = math.max(0, math.floor(tonumber(data.PartnerUnspentPoints) or 0))
	result.PartnerTrainingSeconds = math.max(0, tonumber(data.PartnerTrainingSeconds) or 0)

	local specialization = tostring(data.PartnerSpecialization or "")
	if specialization ~= "Power" and specialization ~= "Speed" then
		specialization = ""
	end
	result.PartnerSpecialization = specialization
	result.RespecSchoolIndex = math.max(0, math.floor(tonumber(data.RespecSchoolIndex) or 0))
	result.LastSeenTime = math.max(0, math.floor(tonumber(data.LastSeenTime) or 0))

	local pointCap = Config.GetPointCap(result.SchoolIndex)
	local totalPoints = result.PartnerPowerPoints + result.PartnerSpeedPoints + result.PartnerUnspentPoints
	if totalPoints > pointCap then
		local overflow = totalPoints - pointCap
		local removeFromUnspent = math.min(result.PartnerUnspentPoints, overflow)
		result.PartnerUnspentPoints -= removeFromUnspent
		overflow -= removeFromUnspent

		if overflow > 0 then
			local removeFromSpeed = math.min(result.PartnerSpeedPoints, overflow)
			result.PartnerSpeedPoints -= removeFromSpeed
			overflow -= removeFromSpeed
		end

		if overflow > 0 then
			result.PartnerPowerPoints = math.max(0, result.PartnerPowerPoints - overflow)
		end
	end

	if type(data.SessionLock) == "table" then
		result.SessionLock = {
			SessionId = tostring(data.SessionLock.SessionId or ""),
			JobId = tostring(data.SessionLock.JobId or ""),
			LockedAt = math.max(0, math.floor(tonumber(data.SessionLock.LockedAt) or 0)),
			LockExpiresAt = math.max(0, math.floor(tonumber(data.SessionLock.LockExpiresAt) or 0)),
		}
	end

	return result
end

local function cloneData(data)
	local cloned = normalize(data)
	if data and type(data.SessionLock) == "table" then
		cloned.SessionLock = {
			SessionId = tostring(data.SessionLock.SessionId or ""),
			JobId = tostring(data.SessionLock.JobId or ""),
			LockedAt = tonumber(data.SessionLock.LockedAt) or 0,
			LockExpiresAt = tonumber(data.SessionLock.LockExpiresAt) or 0,
		}
	end
	return cloned
end

local function isLockExpired(lock)
	return type(lock) ~= "table" or (tonumber(lock.LockExpiresAt) or 0) <= now()
end

local function ownsLock(data)
	return type(data) == "table"
		and type(data.SessionLock) == "table"
		and tostring(data.SessionLock.SessionId or "") == sessionId
		and not isLockExpired(data.SessionLock)
end

local function lockedByOther(data)
	return type(data) == "table"
		and type(data.SessionLock) == "table"
		and not isLockExpired(data.SessionLock)
		and tostring(data.SessionLock.SessionId or "") ~= sessionId
end

local function applyLock(data)
	data.SessionLock = {
		SessionId = sessionId,
		JobId = game.JobId,
		LockedAt = now(),
		LockExpiresAt = now() + LOCK_TIMEOUT_SECONDS,
	}
end

local function updateWithRetry(key, transform)
	local lastError = nil

	for attempt = 1, RETRY_COUNT do
		local success, result = pcall(function()
			return store:UpdateAsync(key, transform)
		end)

		if success then
			return true, result
		end

		lastError = result
		warn("[StudyData] UpdateAsync failed", key, "attempt", attempt, result)
		task.wait(RETRY_DELAY)
	end

	return false, lastError
end

local function keyFor(player)
	return "StudyPlayer_" .. tostring(player.UserId)
end

function StudySimulatorData.Load(player)
	local userId = player.UserId
	local loaded = nil
	local blocked = false

	local success, result = updateWithRetry(keyFor(player), function(oldData)
		if lockedByOther(oldData) then
			blocked = true
			return oldData
		end

		local data = normalize(oldData)
		applyLock(data)
		loaded = cloneData(data)
		return data
	end)

	if not success then
		return false, tostring(result)
	end

	if blocked or not loaded then
		return false, "PROFILE_LOCKED"
	end

	profiles[userId] = {
		Loaded = true,
		Data = loaded,
		Dirty = false,
		Saving = false,
	}

	return true, loaded
end

function StudySimulatorData.IsLoaded(player)
	local profile = profiles[player.UserId]
	return profile ~= nil and profile.Loaded == true
end

function StudySimulatorData.Get(player)
	local profile = profiles[player.UserId]
	return profile and profile.Data or nil
end

function StudySimulatorData.MarkDirty(player)
	local profile = profiles[player.UserId]
	if profile then
		profile.Dirty = true
	end
end

function StudySimulatorData.IsDirty(player)
	local profile = profiles[player.UserId]
	return profile ~= nil and profile.Dirty == true
end

function StudySimulatorData.Save(player, force)
	local profile = profiles[player.UserId]
	if not profile or not profile.Loaded then
		return false, "NOT_LOADED"
	end

	if profile.Saving then
		return false, "SAVE_IN_PROGRESS"
	end

	if not force and not profile.Dirty then
		return true
	end

	profile.Saving = true
	local snapshot = cloneData(profile.Data)
	snapshot.LastSeenTime = now()
	applyLock(snapshot)
	local lockLost = false

	local success, result = updateWithRetry(keyFor(player), function(oldData)
		if oldData ~= nil and not ownsLock(oldData) and not isLockExpired(oldData.SessionLock) then
			lockLost = true
			return oldData
		end

		local saved = cloneData(snapshot)
		applyLock(saved)
		return saved
	end)

	profile.Saving = false

	if not success then
		return false, tostring(result)
	end

	if lockLost then
		return false, "LOCK_LOST"
	end

	profile.Data.LastSeenTime = snapshot.LastSeenTime
	profile.Data.SessionLock = snapshot.SessionLock
	profile.Dirty = false
	return true
end

function StudySimulatorData.Release(player)
	local profile = profiles[player.UserId]
	if not profile then
		return true
	end

	StudySimulatorData.Save(player, true)
	local snapshot = cloneData(profile.Data)
	snapshot.LastSeenTime = now()
	snapshot.SessionLock = nil

	local success, result = updateWithRetry(keyFor(player), function(oldData)
		if oldData ~= nil and not ownsLock(oldData) and not isLockExpired(oldData.SessionLock) then
			return oldData
		end
		return cloneData(snapshot)
	end)

	profiles[player.UserId] = nil
	return success, result
end

function StudySimulatorData.Reset(player)
	local profile = profiles[player.UserId]
	if not profile then
		return false, "NOT_LOADED"
	end

	local reset = defaultData()
	applyLock(reset)
	profile.Data = reset
	profile.Dirty = true
	return true, reset
end

function StudySimulatorData.GetSnapshot(player)
	local data = StudySimulatorData.Get(player)
	return data and cloneData(data) or nil
end

return StudySimulatorData
