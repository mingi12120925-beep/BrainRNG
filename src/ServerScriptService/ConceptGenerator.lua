local ConceptGenerator = {}

local TARGET_TOTAL_COUNT = 9790
local MAX_LUCK_LEVEL = 50
local LUCK_SCALE = 0.18

local built = false
local allConcepts = {}
local conceptsByRarity = {}
local conceptById = {}

local rng = Random.new()

local RarityConfig = {
	COMMON = {
		MinIQ = 1,
		MaxIQ = 3,
		BaseWeight = 5000000000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1,
		RarityRankBoost = 0,
		MaxLuckMultiplier = 1,
		MaxAdjustedWeight = nil,
		TargetCount = 2500,
		SecretCheck = false,
	},
	UNCOMMON = {
		MinIQ = 3,
		MaxIQ = 5,
		BaseWeight = 2000000000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 0.9,
		RarityRankBoost = 0.15,
		MaxLuckMultiplier = 1.8,
		MaxAdjustedWeight = nil,
		TargetCount = 1200,
		SecretCheck = false,
	},
	SMART = {
		MinIQ = 4,
		MaxIQ = 8,
		BaseWeight = 666666667,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 0.95,
		RarityRankBoost = 0.35,
		MaxLuckMultiplier = 2.5,
		MaxAdjustedWeight = nil,
		TargetCount = 1500,
		SecretCheck = false,
	},
	SKILLED = {
		MinIQ = 7,
		MaxIQ = 12,
		BaseWeight = 200000000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1,
		RarityRankBoost = 0.7,
		MaxLuckMultiplier = 3.5,
		MaxAdjustedWeight = nil,
		TargetCount = 1100,
		SecretCheck = false,
	},
	ADVANCED = {
		MinIQ = 12,
		MaxIQ = 25,
		BaseWeight = 66666667,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.05,
		RarityRankBoost = 1.1,
		MaxLuckMultiplier = 5,
		MaxAdjustedWeight = nil,
		TargetCount = 900,
		SecretCheck = false,
	},
	EXPERT = {
		MinIQ = 25,
		MaxIQ = 50,
		BaseWeight = 20000000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.1,
		RarityRankBoost = 1.8,
		MaxLuckMultiplier = 7,
		MaxAdjustedWeight = nil,
		TargetCount = 700,
		SecretCheck = false,
	},
	GENIUS = {
		MinIQ = 10,
		MaxIQ = 20,
		BaseWeight = 5000000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.15,
		RarityRankBoost = 2.6,
		MaxLuckMultiplier = 9,
		MaxAdjustedWeight = nil,
		TargetCount = 700,
		SecretCheck = false,
	},
	PRODIGY = {
		MinIQ = 60,
		MaxIQ = 120,
		BaseWeight = 1000000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.2,
		RarityRankBoost = 3.5,
		MaxLuckMultiplier = 10,
		MaxAdjustedWeight = nil,
		TargetCount = 350,
		SecretCheck = false,
	},
	SUPER_GENIUS = {
		MinIQ = 35,
		MaxIQ = 75,
		BaseWeight = 400000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.25,
		RarityRankBoost = 4,
		MaxLuckMultiplier = 10,
		MaxAdjustedWeight = nil,
		TargetCount = 250,
		SecretCheck = false,
	},
	MASTERMIND = {
		MinIQ = 90,
		MaxIQ = 180,
		BaseWeight = 200000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.3,
		RarityRankBoost = 4.5,
		MaxLuckMultiplier = 12,
		MaxAdjustedWeight = nil,
		TargetCount = 250,
		SecretCheck = false,
	},
	LEGENDARY = {
		MinIQ = 250,
		MaxIQ = 500,
		BaseWeight = 40000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.35,
		RarityRankBoost = 5.5,
		MaxLuckMultiplier = 14,
		MaxAdjustedWeight = nil,
		TargetCount = 160,
		SecretCheck = false,
	},
	MYTHIC = {
		MinIQ = 150,
		MaxIQ = 300,
		BaseWeight = 10000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.4,
		RarityRankBoost = 6.5,
		MaxLuckMultiplier = 16,
		MaxAdjustedWeight = nil,
		TargetCount = 45,
		SecretCheck = false,
	},
	TRANSCENDENT = {
		MinIQ = 1000,
		MaxIQ = 2500,
		BaseWeight = 1000,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.5,
		RarityRankBoost = 8,
		MaxLuckMultiplier = 20,
		MaxAdjustedWeight = nil,
		TargetCount = 80,
		SecretCheck = false,
	},
	IMPOSSIBLE = {
		MinIQ = 5000,
		MaxIQ = 12000,
		BaseWeight = 100,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.6,
		RarityRankBoost = 10,
		MaxLuckMultiplier = 25,
		MaxAdjustedWeight = nil,
		TargetCount = 40,
		SecretCheck = false,
	},
	SECRET = {
		MinIQ = 800,
		MaxIQ = 2000,
		BaseWeight = 0,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.7,
		RarityRankBoost = 7,
		MaxLuckMultiplier = 8,
		MaxAdjustedWeight = nil,
		TargetCount = 5,
		SecretCheck = true,
		GateChanceBase = 0.000000001,
	},
	REALITY_BREAKER = {
		MinIQ = 25000,
		MaxIQ = 100000,
		BaseWeight = 0,
		RarityPower = 0,
		LuckGrowth = 0,
		LuckCurve = 1.8,
		RarityRankBoost = 4,
		MaxLuckMultiplier = 5,
		MaxAdjustedWeight = nil,
		TargetCount = 10,
		SecretCheck = true,
		GateChanceBase = 0.0000000001,
	},
}

local rarityOrder = {
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

-- Stable ID note:
-- Add new words only at the end of each list. Inserting in the middle can shift generated IDs.
local commonPrefixes = {
	"Drowsy",
	"Slow",
	"Basic",
	"Plain",
	"Tiny",
	"Quiet",
	"Beginner",
	"Old",
	"Faint",
	"Core",
}

local uncommonPrefixes = {
	"Awake",
	"Fresh",
	"Steady",
	"Curious",
	"Bright",
	"Neat",
	"Active",
	"Ready",
	"Rising",
	"Warmup",
}

local smartPrefixes = {
	"Focused",
	"Quick",
	"Clear",
	"Clever",
	"Logical",
	"Calm",
	"Precise",
	"Applied",
	"Calculated",
	"Sharp",
}

local skilledPrefixes = {
	"Trained",
	"Accurate",
	"Balanced",
	"Efficient",
	"Polished",
	"Sharp Minded",
	"Methodical",
	"Reliable",
	"Strategic",
	"Technical",
}

local advancedPrefixes = {
	"Advanced",
	"High Grade",
	"Rapid",
	"Deep",
	"Brilliant",
	"Refined",
	"Elite",
	"Complex",
	"Prime",
	"Accelerated",
}

local expertPrefixes = {
	"Expert",
	"Professor",
	"Champion",
	"Precision",
	"Breakthrough",
	"Quantum",
	"Senior",
	"Architect",
	"Tactical",
	"Peak",
}

local geniusPrefixes = {
	"Hyper Focused",
	"Top Rank",
	"Genius",
	"Perfect",
	"Dominant",
	"Ultra Precise",
	"Harvard Level",
	"Olympiad",
	"Master",
	"Golden",
}

local prodigyPrefixes = {
	"Prodigy",
	"Miracle",
	"Supreme",
	"Prodigious",
	"Lightning",
	"Impossible Fast",
	"Starborn",
	"Grandmaster",
	"Nova",
	"Hyper Logic",
}

local superPrefixes = {
	"Cosmic",
	"Transcendent",
	"Dimensional",
	"Legendary",
	"Ultra Fast",
	"Infinite",
	"Mythic",
	"Extreme",
	"Grand Genius",
	"Alpha",
}

local mastermindPrefixes = {
	"Mastermind",
	"Omni Focused",
	"Ultra Elite",
	"Supreme Genius",
	"Paradox",
	"Prime Architect",
	"Mindstorm",
	"Celestial",
	"Apex",
	"Absolute Logic",
}

local legendaryPrefixes = {
	"Legendary",
	"Immortal",
	"Stellar",
	"World Class",
	"Ancient",
	"Eternal",
	"Radiant",
	"Oracle",
	"Mirage",
	"Infinity Class",
}

local mythicPrefixes = {
	"Einstein",
	"Newton",
	"Tesla",
	"Da Vinci",
	"Hawking",
	"Divine",
	"Black Hole",
	"Timebreaking",
	"Cosmic Core",
	"Absolute Mind",
}

local transcendentPrefixes = {
	"Transcendent",
	"Beyond Time",
	"Hyperdimensional",
	"Singularity",
	"Reality Shifted",
	"Omega",
	"Limitless",
	"Event Horizon",
	"Celestial Core",
	"Ascended",
}

local impossiblePrefixes = {
	"Impossible",
	"Unthinkable",
	"Paradoxical",
	"Zero Point",
	"Infinity Edge",
	"Dimension Split",
	"Causality Broken",
	"Beyond Logic",
	"Unknown Law",
	"Absolute Void",
}

local secretPrefixes = {
	"Forbidden",
	"Hidden",
	"Admin",
	"Void",
	"Beyond Dimension",
}

local realityBreakerPrefixes = {
	"Reality Breaker",
	"Universe Error",
	"Existence Override",
	"Final Boundary",
	"Origin Code",
}

local fields = {
	"Math",
	"Science",
	"Physics",
	"Chemistry",
	"Biology",
	"Coding",
	"AI",
	"Algorithm",
	"Robotics",
	"Astronomy",
	"Logic",
	"Language",
	"Memory",
	"Strategy",
	"Puzzle",
	"Formula",
	"Paper",
	"Experiment",
	"Brain",
	"Intelligence",
	"Quiz",
	"Research",
	"Calculation",
	"Reasoning",
	"Analysis",
}

local results = {
	"Memory",
	"Thinking",
	"Formula",
	"Strategy",
	"Circuit",
	"Paper",
	"Note",
	"Pattern",
	"Answer",
	"Proof",
	"Experiment",
	"Routine",
	"Secret",
	"Engine",
	"Map",
	"Spark",
	"Core",
	"Module",
	"Operation",
	"Discovery",
	"Sense",
	"Breakthrough",
	"Training",
	"Record",
	"Insight",
}

local categories = {
	"Memory",
	"Logic",
	"Science",
	"Math",
	"AI",
	"Puzzle",
	"Research",
}

local function getPrefixList(rarity)
	if rarity == "COMMON" then
		return commonPrefixes
	elseif rarity == "UNCOMMON" then
		return uncommonPrefixes
	elseif rarity == "SMART" then
		return smartPrefixes
	elseif rarity == "SKILLED" then
		return skilledPrefixes
	elseif rarity == "ADVANCED" then
		return advancedPrefixes
	elseif rarity == "EXPERT" then
		return expertPrefixes
	elseif rarity == "GENIUS" then
		return geniusPrefixes
	elseif rarity == "PRODIGY" then
		return prodigyPrefixes
	elseif rarity == "SUPER_GENIUS" then
		return superPrefixes
	elseif rarity == "MASTERMIND" then
		return mastermindPrefixes
	elseif rarity == "LEGENDARY" then
		return legendaryPrefixes
	elseif rarity == "MYTHIC" then
		return mythicPrefixes
	elseif rarity == "TRANSCENDENT" then
		return transcendentPrefixes
	elseif rarity == "IMPOSSIBLE" then
		return impossiblePrefixes
	elseif rarity == "SECRET" then
		return secretPrefixes
	elseif rarity == "REALITY_BREAKER" then
		return realityBreakerPrefixes
	end

	return commonPrefixes
end

local function normalizeRarityForId(rarity)
	return tostring(rarity):gsub("%s+", "_")
end

local function registerConcept(concept)
	if conceptById[concept.Id] then
		warn("[ConceptGenerator] Duplicate ConceptId:", concept.Id)
	end

	conceptById[concept.Id] = concept
	table.insert(allConcepts, concept)

	conceptsByRarity[concept.Rarity] = conceptsByRarity[concept.Rarity] or {}
	table.insert(conceptsByRarity[concept.Rarity], concept)

	return concept
end

local function makeConcept(rarity, index, prefix, field, result)
	local config = RarityConfig[rarity]
	local id = string.format("%s:%04d:%03d:%03d:%03d", normalizeRarityForId(rarity), index, prefix.Index, field.Index, result.Index)
	local name = prefix.Value .. " " .. field.Value .. " " .. result.Value
	local category = categories[((index - 1) % #categories) + 1]

	return {
		Id = id,
		Name = name,
		Rarity = rarity,
		MinIQ = config.MinIQ,
		MaxIQ = config.MaxIQ,
		BaseWeight = config.BaseWeight,
		RarityPower = config.RarityPower,
		Category = category,
		IsLimited = false,
		IsSecret = config.SecretCheck == true,
	}
end

local function buildRarityPool(rarity)
	local config = RarityConfig[rarity]
	local prefixes = getPrefixList(rarity)
	local targetCount = config.TargetCount
	local created = 0

	for pIndex, prefix in ipairs(prefixes) do
		for fIndex, field in ipairs(fields) do
			for rIndex, result in ipairs(results) do
				created += 1

				registerConcept(makeConcept(
					rarity,
					created,
					{ Index = pIndex, Value = prefix },
					{ Index = fIndex, Value = field },
					{ Index = rIndex, Value = result }
					))

				if created >= targetCount then
					return
				end
			end
		end
	end

	while created < targetCount do
		created += 1

		local pIndex = ((created - 1) % #prefixes) + 1
		local fIndex = ((math.floor((created - 1) / #prefixes)) % #fields) + 1
		local rIndex = ((math.floor((created - 1) / (#prefixes * #fields))) % #results) + 1

		registerConcept(makeConcept(
			rarity,
			created,
			{ Index = pIndex, Value = prefixes[pIndex] },
			{ Index = fIndex, Value = fields[fIndex] },
			{ Index = rIndex, Value = results[rIndex] .. tostring(created) }
			))
	end
end

local function buildPools()
	if built then
		return
	end

	built = true
	allConcepts = {}
	conceptsByRarity = {}
	conceptById = {}

	for _, rarity in ipairs(rarityOrder) do
		buildRarityPool(rarity)
	end

	print("[ConceptGenerator] Built concept pool:", #allConcepts)
end

local function getAdjustedWeight(rarity, luckLevel)
	local config = RarityConfig[rarity]
	if not config or config.SecretCheck then
		return 0
	end

	luckLevel = math.clamp(tonumber(luckLevel) or 0, 0, MAX_LUCK_LEVEL)

	local curve = config.LuckCurve or 1
	local effectiveLuck = 0

	if luckLevel > 0 then
		effectiveLuck = math.log(1 + (luckLevel * LUCK_SCALE)) / math.log(1 + (MAX_LUCK_LEVEL * LUCK_SCALE))
	end

	local boost = config.RarityRankBoost or 0
	local maxMultiplier = config.MaxLuckMultiplier or math.huge
	local multiplier = math.min(1 + ((effectiveLuck ^ curve) * boost), maxMultiplier)
	local adjustedWeight = config.BaseWeight * multiplier

	if config.MaxAdjustedWeight then
		adjustedWeight = math.min(adjustedWeight, config.MaxAdjustedWeight)
	end

	return adjustedWeight
end

local gateRarityOrder = {
	"REALITY_BREAKER",
	"SECRET",
}

local function getGateChance(rarity, luckLevel)
	local config = RarityConfig[rarity]
	if not config or not config.SecretCheck then
		return 0
	end

	luckLevel = math.clamp(tonumber(luckLevel) or 0, 0, MAX_LUCK_LEVEL)

	local effectiveLuck = 0
	if luckLevel > 0 then
		effectiveLuck = math.log(1 + (luckLevel * LUCK_SCALE)) / math.log(1 + (MAX_LUCK_LEVEL * LUCK_SCALE))
	end

	local curve = config.LuckCurve or 1
	local boost = config.RarityRankBoost or 0
	local maxMultiplier = config.MaxLuckMultiplier or 1
	local multiplier = math.min(1 + ((effectiveLuck ^ curve) * boost), maxMultiplier)

	return (config.GateChanceBase or 0) * multiplier
end

local function rollGateRarity(luckLevel)
	for _, rarity in ipairs(gateRarityOrder) do
		local chance = getGateChance(rarity, luckLevel)
		if chance > 0 and rng:NextNumber() < chance then
			return rarity
		end
	end

	return nil
end

local function chooseRarity(luckLevel)
	local gateRarity = rollGateRarity(luckLevel)
	if gateRarity then
		return gateRarity
	end

	local totalWeight = 0
	local weightedRarities = {}

	for _, rarity in ipairs(rarityOrder) do
		local weight = getAdjustedWeight(rarity, luckLevel)
		if weight > 0 then
			totalWeight += weight
			table.insert(weightedRarities, {
				Rarity = rarity,
				Weight = weight,
			})
		end
	end

	local roll = rng:NextNumber(0, totalWeight)
	local running = 0

	for _, item in ipairs(weightedRarities) do
		running += item.Weight
		if roll <= running then
			return item.Rarity
		end
	end

	return "COMMON"
end

local function chooseConceptFromRarity(rarity)
	buildPools()

	local pool = conceptsByRarity[rarity]
	if not pool or #pool == 0 then
		pool = conceptsByRarity.COMMON
	end

	return pool[rng:NextInteger(1, #pool)]
end

function ConceptGenerator.GetTotalCount()
	buildPools()
	return #allConcepts
end

function ConceptGenerator.GetTotalCountByRarity(rarity)
	buildPools()

	local pool = conceptsByRarity[rarity]
	return pool and #pool or 0
end

function ConceptGenerator.GetConceptById(conceptId)
	buildPools()
	return conceptById[tostring(conceptId)]
end

function ConceptGenerator.RollConcept(luckLevel)
	buildPools()

	local rarity = chooseRarity(luckLevel)
	local concept = chooseConceptFromRarity(rarity)
	local baseIQ = rng:NextInteger(concept.MinIQ, concept.MaxIQ)

	return {
		Concept = concept,
		BaseIQ = baseIQ,
		Rarity = rarity,
	}
end

ConceptGenerator.Roll = ConceptGenerator.RollConcept
ConceptGenerator.RarityConfig = RarityConfig
ConceptGenerator.RarityOrder = rarityOrder

return ConceptGenerator
