-- StarterPlayerScripts/EarlyGameTelemetry.client.lua
-- Studio-only, read-only telemetry for the first 10 minutes of Brain RNG.
-- This script never changes gameplay, UI, player movement, progression, or saved data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
if not remotes then
	warn("[EarlyGameQA] Remotes folder missing; telemetry disabled")
	return
end

local UpdateStats = remotes:WaitForChild("UpdateStats", 20)
local PopupEvent = remotes:WaitForChild("PopupEvent", 20)
local PlayerDataReady = remotes:WaitForChild("PlayerDataReady", 20)

if not UpdateStats or not PopupEvent or not PlayerDataReady then
	warn("[EarlyGameQA] Required remotes missing; telemetry disabled")
	return
end

local latestStats = {}
local sessionStartedAt = nil
local sessionStartSource = nil
local playerDataReadyReceived = false
local statsReceived = false
local rollCount = 0
local firstRollInputAt = nil
local firstRollSuccessAt = nil
local firstChestPanelAt = nil
local firstChestOpenAt = nil
local firstQuestPanelAt = nil
local firstQuestCompleteAt = nil
local firstQuestClaimAt = nil
local thresholdTimes = {}
local connectedObjects = setmetatable({}, { __mode = "k" })
local snapshotsScheduled = false

local IQ_THRESHOLDS = {
	{ Key = "IQ500", Value = 500 },
	{ Key = "IQ2000", Value = 2000 },
	{ Key = "IQ10000", Value = 10000 },
}

local function elapsed()
	if not sessionStartedAt then
		return 0
	end
	return math.max(0, os.clock() - sessionStartedAt)
end

local function secondsText(value)
	return string.format("%.2fs", tonumber(value) or 0)
end

local function getChestInfo()
	return type(latestStats.Chest) == "table" and latestStats.Chest or {}
end

local function countQuestStates(fieldName)
	local quests = type(latestStats.Quests) == "table" and latestStats.Quests or {}
	local count = 0
	for _, quest in ipairs(quests) do
		if type(quest) == "table" and quest[fieldName] == true then
			count += 1
		end
	end
	return count
end

local function snapshot(label)
	local chest = getChestInfo()
	print(
		"[EarlyGameQA] Snapshot=" .. tostring(label)
			.. " elapsed=" .. secondsText(elapsed())
			.. " IQ=" .. tostring(tonumber(latestStats.IQ) or 0)
			.. " Wins=" .. tostring(tonumber(latestStats.Wins) or 0)
			.. " CP=" .. tostring(tonumber(chest.Points) or 0)
			.. " TotalOpened=" .. tostring(tonumber(chest.TotalOpened) or 0)
			.. " RollCount=" .. tostring(rollCount)
			.. " QuestCompleted=" .. tostring(countQuestStates("Completed"))
			.. " QuestClaimed=" .. tostring(countQuestStates("Claimed"))
	)
end

local function printFinalSummary()
	print(
		"[EarlyGameQA] FinalSummary"
			.. " source=" .. tostring(sessionStartSource)
			.. " firstRollInput=" .. (firstRollInputAt and secondsText(firstRollInputAt) or "NONE")
			.. " firstRollSuccess=" .. (firstRollSuccessAt and secondsText(firstRollSuccessAt) or "NONE")
			.. " IQ500=" .. (thresholdTimes.IQ500 and secondsText(thresholdTimes.IQ500) or "NONE")
			.. " IQ2000=" .. (thresholdTimes.IQ2000 and secondsText(thresholdTimes.IQ2000) or "NONE")
			.. " IQ10000=" .. (thresholdTimes.IQ10000 and secondsText(thresholdTimes.IQ10000) or "NONE")
			.. " chestPanel=" .. (firstChestPanelAt and secondsText(firstChestPanelAt) or "NONE")
			.. " chestOpen=" .. (firstChestOpenAt and secondsText(firstChestOpenAt) or "NONE")
			.. " questPanel=" .. (firstQuestPanelAt and secondsText(firstQuestPanelAt) or "NONE")
			.. " questComplete=" .. (firstQuestCompleteAt and secondsText(firstQuestCompleteAt) or "NONE")
			.. " questClaim=" .. (firstQuestClaimAt and secondsText(firstQuestClaimAt) or "NONE")
			.. " rolls=" .. tostring(rollCount)
	)
end

local function scheduleSnapshots()
	if snapshotsScheduled then
		return
	end
	snapshotsScheduled = true

	task.delay(30, function()
		if player.Parent then
			snapshot("30s")
		end
	end)

	task.delay(180, function()
		if player.Parent then
			snapshot("3m")
		end
	end)

	task.delay(600, function()
		if player.Parent then
			snapshot("10m")
			printFinalSummary()
		end
	end)
end

local function startSession(source)
	if sessionStartedAt or not statsReceived then
		return
	end

	sessionStartedAt = os.clock()
	sessionStartSource = source

	local iq = tonumber(latestStats.IQ) or 0
	local wins = tonumber(latestStats.Wins) or 0
	local concepts = tonumber(latestStats.DiscoveredConcepts) or 0
	local freshProfile = iq <= 5 and wins <= 0 and concepts <= 1

	print(
		"[EarlyGameQA] Start"
			.. " player=" .. player.Name
			.. " source=" .. tostring(source)
			.. " IQ=" .. tostring(iq)
			.. " Wins=" .. tostring(wins)
			.. " FreshProfile=" .. tostring(freshProfile)
	)

	if not freshProfile then
		warn("[EarlyGameQA] Existing progress detected; this session is not valid fresh-account balance data")
	end

	scheduleSnapshots()
end

local function checkIQThresholds()
	if not sessionStartedAt then
		return
	end

	local iq = tonumber(latestStats.IQ) or 0
	for _, threshold in ipairs(IQ_THRESHOLDS) do
		if not thresholdTimes[threshold.Key] and iq >= threshold.Value then
			thresholdTimes[threshold.Key] = elapsed()
			print(
				"[EarlyGameQA] Milestone=" .. threshold.Key
					.. " elapsed=" .. secondsText(thresholdTimes[threshold.Key])
					.. " IQ=" .. tostring(iq)
					.. " rolls=" .. tostring(rollCount)
			)
		end
	end
end

local function mergeStats(newStats)
	if type(newStats) ~= "table" then
		return
	end
	for key, value in pairs(newStats) do
		latestStats[key] = value
	end
end

local function connectPanel(panel, kind)
	if connectedObjects[panel] or not panel:IsA("GuiObject") then
		return
	end
	connectedObjects[panel] = true

	local function observe()
		if not sessionStartedAt or not panel.Visible then
			return
		end

		if kind == "Quest" and not firstQuestPanelAt then
			firstQuestPanelAt = elapsed()
			print("[EarlyGameQA] Milestone=QuestPanelOpened elapsed=" .. secondsText(firstQuestPanelAt))
		elseif kind == "Chest" and not firstChestPanelAt then
			firstChestPanelAt = elapsed()
			print("[EarlyGameQA] Milestone=ChestPanelOpened elapsed=" .. secondsText(firstChestPanelAt))
		end
	end

	panel:GetPropertyChangedSignal("Visible"):Connect(observe)
	observe()
end

local function connectRollButton(button)
	if connectedObjects[button] or not button:IsA("GuiButton") then
		return
	end
	connectedObjects[button] = true

	button.Activated:Connect(function()
		if not sessionStartedAt or firstRollInputAt then
			return
		end
		firstRollInputAt = elapsed()
		print("[EarlyGameQA] Milestone=FirstRollInput elapsed=" .. secondsText(firstRollInputAt))
	end)
end

local function inspectGuiObject(instance)
	if instance.Name == "QuestPanel" and instance:IsA("GuiObject") then
		connectPanel(instance, "Quest")
	elseif instance.Name == "ChestPanel" and instance:IsA("GuiObject") then
		connectPanel(instance, "Chest")
	elseif instance.Name == "RollButton" and instance:IsA("GuiButton") then
		connectRollButton(instance)
	end
end

local function watchPlayerGui()
	local playerGui = player:WaitForChild("PlayerGui", 20)
	if not playerGui then
		warn("[EarlyGameQA] PlayerGui missing; UI discovery timing disabled")
		return
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		inspectGuiObject(descendant)
	end
	playerGui.DescendantAdded:Connect(inspectGuiObject)
end

UpdateStats.OnClientEvent:Connect(function(newStats)
	mergeStats(newStats)
	statsReceived = true
	if not sessionStartedAt then
		startSession(playerDataReadyReceived and "PlayerDataReady+UpdateStats" or "UpdateStats")
	end
	checkIQThresholds()
end)

PlayerDataReady.OnClientEvent:Connect(function()
	playerDataReadyReceived = true
	if statsReceived and not sessionStartedAt then
		startSession("UpdateStats+PlayerDataReady")
	end
end)

PopupEvent.OnClientEvent:Connect(function(text, popupType)
	if not sessionStartedAt and statsReceived then
		startSession("UpdateStats+PopupEvent")
	end

	popupType = tostring(popupType or "Info")
	local popupText = string.upper(tostring(text or ""))

	if popupType == "Roll" then
		rollCount += 1
		if not firstRollSuccessAt then
			firstRollSuccessAt = elapsed()
			print("[EarlyGameQA] Milestone=FirstRollSuccess elapsed=" .. secondsText(firstRollSuccessAt))
		end
	elseif popupType == "Chest" and string.find(popupText, "CHEST OPENED", 1, true) then
		if not firstChestOpenAt then
			firstChestOpenAt = elapsed()
			print("[EarlyGameQA] Milestone=FirstChestOpen elapsed=" .. secondsText(firstChestOpenAt))
		end
	elseif popupType == "Quest" then
		if string.find(popupText, "QUEST COMPLETE", 1, true) and not firstQuestCompleteAt then
			firstQuestCompleteAt = elapsed()
			print("[EarlyGameQA] Milestone=FirstQuestComplete elapsed=" .. secondsText(firstQuestCompleteAt))
		end
		if string.find(popupText, "QUEST CLAIMED", 1, true) and not firstQuestClaimAt then
			firstQuestClaimAt = elapsed()
			print("[EarlyGameQA] Milestone=FirstQuestClaim elapsed=" .. secondsText(firstQuestClaimAt))
		end
	end
end)

task.spawn(watchPlayerGui)
print("[EarlyGameQA] Ready studioOnly=true readOnly=true duration=600s")
