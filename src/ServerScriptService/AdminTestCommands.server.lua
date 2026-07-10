-- ServerScriptService/AdminTestCommands.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameLogic = require(ServerScriptService:WaitForChild("GameLogic"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local connectedPlayers = {}

local ALLOWED_TEST_USER_NAMES = {
	"ming861212",
}

local ALLOWED_TEST_USER_IDS = {}

for _, userName in ipairs(ALLOWED_TEST_USER_NAMES) do
	local success, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(userName)
	end)

	if success and userId then
		ALLOWED_TEST_USER_IDS[userId] = true
	else
		warn("[TEST][WARN] Failed to resolve test user:", userName, userId)
	end
end

local function getOrCreateRemoteEvent(name)
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local remote = remotesFolder:FindFirstChild(name)

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end

	return remote
end

local AdminTestCommandRequest = getOrCreateRemoteEvent("AdminTestCommandRequest")
local AdminTestCommandResult = getOrCreateRemoteEvent("AdminTestCommandResult")

local currentOutputLines = nil

local function isAllowed(player)
	return RunService:IsStudio() or ALLOWED_TEST_USER_IDS[player.UserId] == true
end

local function appendOutput(line)
	print(line)

	if currentOutputLines then
		table.insert(currentOutputLines, line)
	end
end

local function pass(name, description)
	appendOutput("[TEST][PASS] " .. tostring(name) .. " - " .. tostring(description))
end

local function fail(name, reason)
	appendOutput("[TEST][FAIL] " .. tostring(name) .. " - " .. tostring(reason))
end

local function warnTest(name, description)
	appendOutput("[TEST][WARN] " .. tostring(name) .. " - " .. tostring(description))
end

local function countTrueValues(values)
	if type(values) ~= "table" then
		return 0
	end

	local count = 0
	for _, value in pairs(values) do
		if value == true then
			count += 1
		end
	end

	return count
end

local function countEntries(values)
	if type(values) ~= "table" then
		return 0
	end

	local count = 0
	for _ in pairs(values) do
		count += 1
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
		ChestPoints = math.max(0, math.floor(tonumber(data.ChestPoints) or 0)),
		ChestTotalOpened = math.max(0, math.floor(tonumber(data.ChestTotalOpened) or 0)),
		QuestProgressCount = countEntries(progress),
		QuestCompletedCount = countTrueValues(completed),
		QuestClaimedCount = countTrueValues(claimed),
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

local function appendAuditSummary(label, summary)
	appendOutput("[PersistAudit] " .. label .. " " .. formatSummary(summary))
end

local function collectQuestIds(quests)
	local ids = {}
	local seen = {}

	local function addFrom(source)
		if type(source) ~= "table" then
			return
		end

		for questId in pairs(source) do
			if type(questId) == "string" and not seen[questId] then
				seen[questId] = true
				table.insert(ids, questId)
			end
		end
	end

	if type(quests) == "table" then
		addFrom(quests.Progress)
		addFrom(quests.Completed)
		addFrom(quests.Claimed)
	end

	table.sort(ids)
	return ids
end

local function getSnapshot(player)
	local success, snapshot = pcall(function()
		return GameLogic.ExportPlayerData(player)
	end)

	if not success then
		fail("ExportPlayerData", tostring(snapshot))
		return nil
	end

	if type(snapshot) ~= "table" then
		fail("ExportPlayerData", "snapshot is not a table")
		return nil
	end

	return snapshot
end

local function testHelp()
	appendOutput("[TEST] Available commands:")
	appendOutput("[TEST] /test_help - Show this command list")
	appendOutput("[TEST] /test_chest_state - Print current exported Chest persistence fields")
	appendOutput("[TEST] /test_quest_state - Print current exported Quest persistence fields")
	appendOutput("[TEST] /test_persistence - Validate exported v3 persistence shape")
	appendOutput("[TEST] /test_persist_audit - Print profile/export/load/save persistence audit")
	appendOutput("[TEST] /test_force_save - Force DataManager.SaveProfile with audit output")
	appendOutput("[TEST] /test_all - Run all persistence tests")
	appendOutput("[TEST] Admin Panel commands: help, chest_state, quest_state, persistence, persist_audit, force_save, all")
end

local function testChestState(player)
	local snapshot = getSnapshot(player)
	if not snapshot then
		return
	end

	if type(snapshot.ChestPoints) == "number" then
		pass("ChestPoints", "number = " .. tostring(snapshot.ChestPoints))
	else
		fail("ChestPoints", "expected number, got " .. typeof(snapshot.ChestPoints))
	end

	if type(snapshot.ChestTotalOpened) == "number" then
		pass("ChestTotalOpened", "number = " .. tostring(snapshot.ChestTotalOpened))
	else
		fail("ChestTotalOpened", "expected number, got " .. typeof(snapshot.ChestTotalOpened))
	end
end

local function testQuestState(player)
	local snapshot = getSnapshot(player)
	if not snapshot then
		return
	end

	local quests = snapshot.Quests
	if type(quests) ~= "table" then
		fail("Quests", "expected table, got " .. typeof(quests))
		return
	end

	pass("Quests", "table exists")

	if type(quests.Progress) == "table" then
		pass("Quests.Progress", "table exists")
	else
		fail("Quests.Progress", "expected table, got " .. typeof(quests.Progress))
	end

	if type(quests.Completed) == "table" then
		pass("Quests.Completed", "table exists")
	else
		fail("Quests.Completed", "expected table, got " .. typeof(quests.Completed))
	end

	if type(quests.Claimed) == "table" then
		pass("Quests.Claimed", "table exists")
	else
		fail("Quests.Claimed", "expected table, got " .. typeof(quests.Claimed))
	end

	local questIds = collectQuestIds(quests)
	if #questIds > 0 then
		pass("Quest dictionary ids", table.concat(questIds, ", "))
	else
		warnTest("Quest dictionary ids", "no quest ids exported yet")
	end

	pass("Quest claimed count", tostring(countTrueValues(quests.Claimed)))
end

local function testPersistence(player)
	local snapshot = getSnapshot(player)
	if not snapshot then
		return
	end

	if tonumber(snapshot.Version) == 3 then
		pass("Export Version", "Version = 3")
	else
		fail("Export Version", "expected 3, got " .. tostring(snapshot.Version))
	end

	if snapshot.ChestPoints ~= nil then
		pass("Export ChestPoints", "exists")
	else
		fail("Export ChestPoints", "missing")
	end

	if snapshot.ChestTotalOpened ~= nil then
		pass("Export ChestTotalOpened", "exists")
	else
		fail("Export ChestTotalOpened", "missing")
	end

	if type(snapshot.Quests) == "table" then
		pass("Export Quests", "table exists")
	else
		fail("Export Quests", "missing or not table")
	end

	if type(snapshot.Quests) == "table" and type(snapshot.Quests.Progress) == "table" then
		pass("Export Quests.Progress", "table exists")
	else
		fail("Export Quests.Progress", "missing or not table")
	end

	if type(snapshot.Quests) == "table" and type(snapshot.Quests.Completed) == "table" then
		pass("Export Quests.Completed", "table exists")
	else
		fail("Export Quests.Completed", "missing or not table")
	end

	if type(snapshot.Quests) == "table" and type(snapshot.Quests.Claimed) == "table" then
		pass("Export Quests.Claimed", "table exists")
	else
		fail("Export Quests.Claimed", "missing or not table")
	end

	warnTest("Persistence runtime save", "still requires leave/rejoin verification.")
end

local function testPersistAudit(player)
	local snapshot = getSnapshot(player)
	local exportSummary = snapshot and summarizePersistenceData(snapshot) or nil
	local audit = DataManager.GetPersistenceAuditSnapshot(player)

	appendOutput("[PersistAudit] Loaded=" .. tostring(audit.Loaded) .. " LastSaveAt=" .. tostring(audit.LastSaveAt or "nil"))
	appendAuditSummary("ExportBeforeSave", exportSummary)
	appendAuditSummary("ProfileSnapshot", audit.Profile)

	if type(audit.LastLoad) == "table" then
		appendAuditSummary("LoadRaw", audit.LastLoad.Raw)
		appendAuditSummary("Normalize", audit.LastLoad.Normalized)
	else
		appendOutput("[PersistAudit] LoadRaw unavailable")
		appendOutput("[PersistAudit] Normalize unavailable")
	end

	if type(audit.LastSave) == "table" then
		appendOutput("[PersistAudit] LastSave Success=" .. tostring(audit.LastSave.Success)
			.. " Kind=" .. tostring(audit.LastSave.Kind or "nil")
			.. " Reason=" .. tostring(audit.LastSave.Reason or "nil")
			.. " Error=" .. tostring(audit.LastSave.Error or "nil")
			.. " At=" .. tostring(audit.LastSave.At or "nil"))
		appendAuditSummary("LastSave.ExportBeforeSave", audit.LastSave.ExportBeforeSave)
		appendAuditSummary("LastSave.Payload", audit.LastSave.Payload)
	else
		appendOutput("[PersistAudit] LastSave unavailable")
	end
end

local function testForceSave(player)
	local beforeSnapshot = getSnapshot(player)
	appendAuditSummary("ForceSave.BeforeExport", beforeSnapshot and summarizePersistenceData(beforeSnapshot) or nil)

	local success, saved = pcall(function()
		return DataManager.SaveProfile(player, false, {
			Reason = "AdminTestForceSave",
		})
	end)

	if success and saved then
		pass("Force Save", "DataManager.SaveProfile returned true")
	else
		fail("Force Save", "DataManager.SaveProfile failed: " .. tostring(saved))
	end

	local afterSnapshot = getSnapshot(player)
	appendAuditSummary("ForceSave.AfterExport", afterSnapshot and summarizePersistenceData(afterSnapshot) or nil)
	testPersistAudit(player)
end

local function testAll(player)
	testChestState(player)
	testQuestState(player)
	testPersistence(player)
end

local TEST_COMMANDS = {
	help = testHelp,
	chest_state = testChestState,
	quest_state = testQuestState,
	persistence = testPersistence,
	persist_audit = testPersistAudit,
	force_save = testForceSave,
	all = testAll,
}

local CHAT_COMMANDS = {
	["/test_help"] = "help",
	["/test_chest_state"] = "chest_state",
	["/test_quest_state"] = "quest_state",
	["/test_persistence"] = "persistence",
	["/test_persist_audit"] = "persist_audit",
	["/test_force_save"] = "force_save",
	["/test_all"] = "all",
}

local function runTestCommand(player, commandName)
	commandName = string.lower(tostring(commandName or ""))

	local handler = TEST_COMMANDS[commandName]
	local outputLines = {}
	local previousOutputLines = currentOutputLines
	currentOutputLines = outputLines

	if not handler then
		fail("Admin test command", "unknown command: " .. tostring(commandName))
		currentOutputLines = previousOutputLines
		return outputLines
	end

	appendOutput("[TEST] Running " .. commandName .. " for " .. player.Name .. " " .. tostring(player.UserId))

	local success, err = pcall(function()
		handler(player)
	end)

	if not success then
		fail("Admin test command", tostring(err))
	end

	currentOutputLines = previousOutputLines
	return outputLines
end

local function handleChat(player, message)
	if not isAllowed(player) then
		return
	end

	local chatCommand = string.lower(tostring(message or ""):match("^%S+") or "")
	local commandName = CHAT_COMMANDS[chatCommand]

	if commandName then
		runTestCommand(player, commandName)
	end
end

local function handleRemoteTestRequest(player, commandName)
	if not isAllowed(player) then
		warn("[TEST][WARN] Blocked non-admin test command request:", player.Name, player.UserId)
		return
	end

	commandName = string.lower(tostring(commandName or ""))

	if not TEST_COMMANDS[commandName] then
		warn("[TEST][WARN] Blocked unknown test command request:", player.Name, tostring(commandName))
		AdminTestCommandResult:FireClient(player, commandName, {
			"[TEST][FAIL] Admin test command - unknown command: " .. tostring(commandName),
		})
		return
	end

	local outputLines = runTestCommand(player, commandName)
	AdminTestCommandResult:FireClient(player, commandName, outputLines)
end

local function connectPlayer(player)
	if connectedPlayers[player] then
		return
	end

	connectedPlayers[player] = true

	player.Chatted:Connect(function(message)
		handleChat(player, message)
	end)
end

AdminTestCommandRequest.OnServerEvent:Connect(handleRemoteTestRequest)

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
	connectedPlayers[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	connectPlayer(player)
end

print("[TEST] Admin test chat commands ready. Use /test_help in Studio.")
print("[TEST] Admin test panel remotes ready: AdminTestCommandRequest/AdminTestCommandResult.")
