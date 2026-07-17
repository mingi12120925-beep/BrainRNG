local Config = {}

Config.DATA_VERSION = 1
Config.DATASTORE_NAME = "BrainRNG_StudySimulator_v1"

Config.BASE_DISPLAY_IQ = 80
Config.MICRO_IQ_PER_DISPLAY_IQ = 1000000
Config.BREAKTHROUGH_CHANCE = 0.05
Config.BREAKTHROUGH_MULTIPLIER = 3
Config.DIRECT_CLICKS_PER_REWARD = 3
Config.PARTNER_UNLOCK_REWARDS = 10
Config.PARTNER_BASE_INTERVAL = 18
Config.PARTNER_POWER_PER_POINT = 0.10
Config.PARTNER_SPEED_PER_POINT = 0.10
Config.SPECIALIZATION_DIRECT_BONUS_PER_POINT = 0.02
Config.DISTRACTION_MIN_DELAY = 2
Config.DISTRACTION_MAX_DELAY = 4
Config.DIRECT_CLICK_MIN_INTERVAL = 0.12
Config.STUDY_DESK_MAX_DISTANCE = 18
Config.PLAYER_WALK_SPEED = 24

Config.SCHOOLS = {
	{
		Id = "Kindergarten",
		DisplayName = "Kindergarten",
		GoalMicroIQ = 10000,
		DirectRewardMicroIQ = 20,
		PartnerPointCap = 4,
		RollInterval = 1.0,
		Implemented = true,
	},
	{
		Id = "Elementary",
		DisplayName = "Elementary",
		GoalMicroIQ = 60000,
		DirectRewardMicroIQ = 60,
		PartnerPointCap = 8,
		RollInterval = 0.9,
		Implemented = true,
	},
	{
		Id = "MiddleSchool",
		DisplayName = "Middle School",
		GoalMicroIQ = 500000,
		DirectRewardMicroIQ = 250,
		PartnerPointCap = 12,
		RollInterval = 0.8,
		Implemented = false,
	},
	{
		Id = "HighSchool",
		DisplayName = "High School",
		GoalMicroIQ = 2000000,
		DirectRewardMicroIQ = 1000,
		PartnerPointCap = 15,
		RollInterval = 0.7,
		Implemented = false,
	},
	{
		Id = "University",
		DisplayName = "University",
		GoalMicroIQ = 10000000,
		DirectRewardMicroIQ = 5000,
		PartnerPointCap = 17,
		RollInterval = 0.6,
		Implemented = false,
	},
	{
		Id = "ResearchLab",
		DisplayName = "Research Lab",
		GoalMicroIQ = 40000000,
		DirectRewardMicroIQ = 25000,
		PartnerPointCap = 19,
		RollInterval = 0.5,
		Implemented = false,
	},
	{
		Id = "AILab",
		DisplayName = "AI Lab",
		GoalMicroIQ = 170000000,
		DirectRewardMicroIQ = 100000,
		PartnerPointCap = 20,
		RollInterval = 0.4,
		Implemented = false,
	},
}

Config.DISTRACTIONS = {
	{ Id = "Phone", Label = "PHONE ALERT", Hint = "Tap to silence it" },
	{ Id = "Drowsy", Label = "STAY AWAKE", Hint = "Tap to refocus" },
	{ Id = "Books", Label = "MESSY BOOKS", Hint = "Tap to organize" },
}

function Config.GetSchool(index)
	index = math.clamp(math.floor(tonumber(index) or 1), 1, #Config.SCHOOLS)
	return Config.SCHOOLS[index]
end

function Config.GetPointCap(index)
	return Config.GetSchool(index).PartnerPointCap
end

function Config.GetTrainingSecondsForNextPoint(totalPoints)
	totalPoints = math.max(0, math.floor(tonumber(totalPoints) or 0))
	return 300 + (totalPoints * 60)
end

function Config.GetPowerMultiplier(powerPoints)
	powerPoints = math.max(0, math.floor(tonumber(powerPoints) or 0))
	return 1 + (powerPoints * Config.PARTNER_POWER_PER_POINT)
end

function Config.GetSpeedMultiplier(speedPoints)
	speedPoints = math.max(0, math.floor(tonumber(speedPoints) or 0))
	return 1 + (speedPoints * Config.PARTNER_SPEED_PER_POINT)
end

function Config.GetSpecializationPoints(data)
	if type(data) ~= "table" then
		return 0
	end

	if data.Specialization == "Power" then
		return math.max(0, (tonumber(data.PowerPoints) or 0) - 5)
	elseif data.Specialization == "Speed" then
		return math.max(0, (tonumber(data.SpeedPoints) or 0) - 5)
	end

	return 0
end

function Config.GetDirectRewardMultiplier(data)
	if type(data) == "table" and data.Specialization == "Power" then
		return 1 + (Config.GetSpecializationPoints(data) * Config.SPECIALIZATION_DIRECT_BONUS_PER_POINT)
	end
	return 1
end

function Config.GetDistractionSpeedMultiplier(data)
	if type(data) == "table" and data.Specialization == "Speed" then
		return 1 + (Config.GetSpecializationPoints(data) * Config.SPECIALIZATION_DIRECT_BONUS_PER_POINT)
	end
	return 1
end

function Config.MicroIQToDisplay(microIQ)
	return Config.BASE_DISPLAY_IQ + ((tonumber(microIQ) or 0) / Config.MICRO_IQ_PER_DISPLAY_IQ)
end

return Config
