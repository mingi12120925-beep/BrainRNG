local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("StudySimulatorConfig"))
local StudyData = require(ServerScriptService:WaitForChild("StudySimulatorData"))
local remotes = ReplicatedStorage:WaitForChild("StudySimulatorRemotes")
local StateUpdated = remotes:WaitForChild("StateUpdated")

local StateRequest = remotes:FindFirstChild("StateRequest")
if not StateRequest then
	StateRequest = Instance.new("RemoteEvent")
	StateRequest.Name = "StateRequest"
	StateRequest.Parent = remotes
end

local lastRequestAt = {}

local function totalPartnerPoints(data)
	return math.max(0, math.floor(tonumber(data.PartnerPowerPoints) or 0))
		+ math.max(0, math.floor(tonumber(data.PartnerSpeedPoints) or 0))
		+ math.max(0, math.floor(tonumber(data.PartnerUnspentPoints) or 0))
end

local function buildPayload(data)
	local school = Config.GetSchool(data.SchoolIndex)
	local nextSchool = Config.SCHOOLS[data.SchoolIndex + 1]
	local previousGoal = data.SchoolIndex > 1 and Config.GetSchool(data.SchoolIndex - 1).GoalMicroIQ or 0
	local range = math.max(1, school.GoalMicroIQ - previousGoal)
	local totalPoints = totalPartnerPoints(data)
	local directMultiplier = Config.GetDirectRewardMultiplier({
		Specialization = data.PartnerSpecialization,
		PowerPoints = data.PartnerPowerPoints,
		SpeedPoints = data.PartnerSpeedPoints,
	})

	return {
		MicroIQ = data.MicroIQ,
		DisplayIQ = Config.MicroIQToDisplay(data.MicroIQ),
		SchoolIndex = data.SchoolIndex,
		SchoolName = school.DisplayName,
		GoalMicroIQ = school.GoalMicroIQ,
		GoalDisplayIQ = Config.MicroIQToDisplay(school.GoalMicroIQ),
		NextSchoolName = nextSchool and nextSchool.DisplayName or "Prestige",
		Progress = math.clamp((data.MicroIQ - previousGoal) / range, 0, 1),
		DirectActive = false,
		ClickProgress = 0,
		ClicksNeeded = Config.DIRECT_CLICKS_PER_REWARD,
		DirectRewardMicroIQ = math.max(1, math.floor(school.DirectRewardMicroIQ * directMultiplier)),
		BreakthroughChance = Config.BREAKTHROUGH_CHANCE,
		PartnerUnlocked = data.PartnerUnlocked,
		DirectStudyRewards = data.DirectStudyRewards,
		PartnerPowerPoints = data.PartnerPowerPoints,
		PartnerSpeedPoints = data.PartnerSpeedPoints,
		PartnerUnspentPoints = data.PartnerUnspentPoints,
		PartnerTotalPoints = totalPoints,
		PartnerPointCap = Config.GetPointCap(data.SchoolIndex),
		PartnerTrainingSeconds = data.PartnerTrainingSeconds,
		PartnerNextPointSeconds = Config.GetTrainingSecondsForNextPoint(totalPoints),
		PartnerRewardMicroIQ = math.max(1, math.floor(school.DirectRewardMicroIQ * Config.GetPowerMultiplier(data.PartnerPowerPoints))),
		PartnerInterval = Config.PARTNER_BASE_INTERVAL / Config.GetSpeedMultiplier(data.PartnerSpeedPoints),
		PartnerSpecialization = data.PartnerSpecialization,
		RespecAvailable = data.RespecSchoolIndex ~= data.SchoolIndex,
		Ready = data.MicroIQ >= school.GoalMicroIQ,
		NextSchoolImplemented = nextSchool and nextSchool.Implemented == true or false,
	}
end

StateRequest.OnServerEvent:Connect(function(player)
	local nowTime = os.clock()
	local previous = tonumber(lastRequestAt[player.UserId]) or 0
	if nowTime - previous < 0.5 then
		return
	end
	lastRequestAt[player.UserId] = nowTime

	local data = StudyData.Get(player)
	if data then
		StateUpdated:FireClient(player, buildPayload(data))
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastRequestAt[player.UserId] = nil
end)
