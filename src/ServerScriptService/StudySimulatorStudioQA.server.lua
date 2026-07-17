local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() then
	return
end

local Config = require(ReplicatedStorage:WaitForChild("StudySimulatorConfig"))
local StudyData = require(ServerScriptService:WaitForChild("StudySimulatorData"))
local remotes = ReplicatedStorage:WaitForChild("StudySimulatorRemotes")
local PresentationEvent = remotes:WaitForChild("PresentationEvent")

local ALLOWED_NAMES = {
	ming861212 = true,
}

local function notify(player, text)
	PresentationEvent:FireClient(player, "Info", { Text = text })
end

local function refresh(player)
	player:SetAttribute("StudyQARefresh", (tonumber(player:GetAttribute("StudyQARefresh")) or 0) + 1)
end

local function totalPoints(data)
	return math.max(0, math.floor(tonumber(data.PartnerPowerPoints) or 0))
		+ math.max(0, math.floor(tonumber(data.PartnerSpeedPoints) or 0))
		+ math.max(0, math.floor(tonumber(data.PartnerUnspentPoints) or 0))
end

local function handleCommand(player, message)
	if not ALLOWED_NAMES[player.Name] then
		return
	end

	message = string.lower(tostring(message or ""))
	if message == "/study_help" then
		notify(player, "/study_neargoal · /study_partner · /study_point · /study_save")
		return
	end

	local data = StudyData.Get(player)
	if not data then
		notify(player, "Study profile is not loaded yet.")
		return
	end

	if message == "/study_neargoal" then
		local school = Config.GetSchool(data.SchoolIndex)
		local previousGoal = data.SchoolIndex > 1 and Config.GetSchool(data.SchoolIndex - 1).GoalMicroIQ or 0
		local directMultiplier = Config.GetDirectRewardMultiplier({
			Specialization = data.PartnerSpecialization,
			PowerPoints = data.PartnerPowerPoints,
			SpeedPoints = data.PartnerSpeedPoints,
		})
		local nextReward = math.max(1, math.floor(school.DirectRewardMicroIQ * directMultiplier))
		data.MicroIQ = math.max(previousGoal, school.GoalMicroIQ - nextReward)
		StudyData.MarkDirty(player)
		StudyData.Save(player, true)
		refresh(player)
		notify(player, "Near goal set. Complete one normal study reward to trigger READY.")
		return
	end

	if message == "/study_partner" then
		data.DirectStudyRewards = math.max(data.DirectStudyRewards, Config.PARTNER_UNLOCK_REWARDS)
		data.PartnerUnlocked = true
		StudyData.MarkDirty(player)
		StudyData.Save(player, true)
		refresh(player)
		notify(player, "Study Partner unlocked for Studio QA.")
		return
	end

	if message == "/study_point" then
		local cap = Config.GetPointCap(data.SchoolIndex)
		if totalPoints(data) >= cap then
			notify(player, "Current school partner point cap reached.")
			return
		end
		data.PartnerUnlocked = true
		data.DirectStudyRewards = math.max(data.DirectStudyRewards, Config.PARTNER_UNLOCK_REWARDS)
		data.PartnerUnspentPoints += 1
		StudyData.MarkDirty(player)
		StudyData.Save(player, true)
		refresh(player)
		notify(player, "One partner upgrade point added.")
		return
	end

	if message == "/study_save" then
		local ok, err = StudyData.Save(player, true)
		notify(player, ok and "Study profile saved." or ("Save failed: " .. tostring(err)))
		return
	end
end

local function bindPlayer(player)
	player.Chatted:Connect(function(message)
		handleCommand(player, message)
	end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

print("[StudySimulatorQA] Studio commands ready. Use /study_help")
