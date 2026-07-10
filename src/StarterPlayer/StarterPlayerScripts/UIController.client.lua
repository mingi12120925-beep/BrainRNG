-- StarterPlayer/StarterPlayerScripts/UIController.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROLL_TICK_SOUND_ID = "rbxassetid://12221967"
local ROLL_RESULT_SOUND_ID = "rbxassetid://6648577112"
local CHEST_CREAK_SOUND_IDS = {
	"rbxassetid://9120839174",
	"rbxassetid://9114145200",
	"rbxassetid://7274931838",
}
local CHEST_CREAK_SOUND_INDEX = 1
local CHEST_CREAK_VOLUME = 2.5
local LOCAL_ADMIN_USERNAME = "ming861212"
local DEBUG_UI = false
local DEBUG_TUTORIAL = false
local LoadingController = require(script.Parent:WaitForChild("LoadingController"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local PlayerDataReady = remotesFolder:WaitForChild("PlayerDataReady")

LoadingController.Start({
	Player = player,
	PlayerGui = playerGui,
	PlayerDataReady = PlayerDataReady,
	TweenService = TweenService,
})

local RollRequest = remotesFolder:WaitForChild("RollRequest")
local UpgradeRequest = remotesFolder:WaitForChild("UpgradeRequest")
local AutoRollUpgradeRequest = remotesFolder:WaitForChild("AutoRollUpgradeRequest")
local AdminTestRequest = remotesFolder:WaitForChild("AdminTestRequest")
local AdminTestCommandRequest = remotesFolder:WaitForChild("AdminTestCommandRequest")
local AdminTestCommandResult = remotesFolder:WaitForChild("AdminTestCommandResult")
local QuestClaimRequest = remotesFolder:WaitForChild("QuestClaimRequest")
local ChestOpenRequest = remotesFolder:WaitForChild("ChestOpenRequest")
local NextAreaRequest = remotesFolder:WaitForChild("NextAreaRequest")
local ReturnToLobbyRequest = remotesFolder:WaitForChild("ReturnToLobbyRequest")
local UpdateStats = remotesFolder:WaitForChild("UpdateStats")
local PopupEvent = remotesFolder:WaitForChild("PopupEvent")

local stats = {
	IQ = 0,
	Wins = 0,
	LuckLevel = 0,
	LuckUpgradeCost = 0,
	KnowledgePoints = 0,
	IndexLevel = 1,
	IndexIQMultiplier = 1,
	IndexMilestoneBonus = 1,
	CurrentIndexMilestone = 0,
	NextIndexMilestone = 5,
	NextIndexMilestoneBonus = 1.02,
	DiscoveredConcepts = 0,
	TotalConcepts = 0,
	DiscoveredByRarity = {},
	RecentConcepts = {},
	AutoRollLevel = 0,
	AutoRollUpgradeCost = 10,
	AutoRollDelay = nil,
	BrainSurgeProgress = 0,
	BrainSurgeTarget = 10,
	BrainSurgeReady = false,
	BrainSurgeMultiplier = 2,
	Quests = {},
	Chest = {
		Points = 0,
		BasicCost = 25,
		CanOpenBasic = false,
		TotalOpened = 0,
	},
	Rebirths = 0,
}

local pendingStats = nil
local rollRevealPending = false
local rouletteActive = false
local rollRequestPending = false
local rollRequestToken = 0
local activeRollRequestToken = nil
local autoRollActive = false
local autoRollDelayFallback = 0.8
local autoRollScheduleToken = 0
local AUTO_ROLL_BUSY_RETRY_DELAY = 0.2
local AUTO_ROLL_STUCK_TIMEOUT = 5.0
local AUTO_ROLL_DEBUG = false
local NEXT_AREA_REQUIRED_IQ = 10000
local FULL_ROULETTE_MIN_DISPLAY = 1.5
local FULL_ROULETTE_AFTER_RESULT_PAUSE = 0.5
local autoRollBusySince = nil
local autoRollLastBusyState = nil
local autoRollRecoveryCount = 0
local fullRollPresentationActive = false
local autoRollPresentationLockUntil = 0
local currentRollPresentationId = 0
local sessionBestRarityRank = 0
local questNpcPromptConnection = nil
local questNpcConnectedPrompt = nil

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

local RARITY_DETAILS = {
	COMMON = { Display = "COMMON", Rank = 1, EffectLevel = 1, Color = Color3.fromRGB(255, 255, 255) },
	UNCOMMON = { Display = "UNCOMMON", Rank = 2, EffectLevel = 1, Color = Color3.fromRGB(120, 235, 150) },
	SMART = { Display = "SMART", Rank = 3, EffectLevel = 1, Color = Color3.fromRGB(90, 220, 255) },
	SKILLED = { Display = "SKILLED", Rank = 4, EffectLevel = 1, Color = Color3.fromRGB(95, 170, 255) },
	ADVANCED = { Display = "ADVANCED", Rank = 5, EffectLevel = 1, Color = Color3.fromRGB(120, 135, 255) },
	EXPERT = { Display = "EXPERT", Rank = 6, EffectLevel = 2, Color = Color3.fromRGB(170, 120, 255) },
	GENIUS = { Display = "GENIUS", Rank = 7, EffectLevel = 2, Color = Color3.fromRGB(255, 230, 80) },
	PRODIGY = { Display = "PRODIGY", Rank = 8, EffectLevel = 3, Color = Color3.fromRGB(255, 185, 80) },
	SUPER_GENIUS = { Display = "SUPER GENIUS", Rank = 9, EffectLevel = 3, Color = Color3.fromRGB(255, 150, 55) },
	MASTERMIND = { Display = "MASTERMIND", Rank = 10, EffectLevel = 3, Color = Color3.fromRGB(255, 110, 80) },
	LEGENDARY = { Display = "LEGENDARY", Rank = 11, EffectLevel = 4, Color = Color3.fromRGB(255, 210, 70) },
	MYTHIC = { Display = "MYTHIC", Rank = 12, EffectLevel = 4, Color = Color3.fromRGB(220, 120, 255) },
	TRANSCENDENT = { Display = "TRANSCENDENT", Rank = 13, EffectLevel = 5, Color = Color3.fromRGB(95, 255, 235) },
	IMPOSSIBLE = { Display = "IMPOSSIBLE", Rank = 14, EffectLevel = 5, Color = Color3.fromRGB(255, 70, 95) },
	SECRET = { Display = "SECRET", Rank = 15, EffectLevel = 6, Color = Color3.fromRGB(255, 80, 180) },
	REALITY_BREAKER = { Display = "REALITY BREAKER", Rank = 16, EffectLevel = 6, Color = Color3.fromRGB(255, 255, 255) },
}

local RARITY_MATCH_ORDER = {
	"REALITY_BREAKER",
	"SECRET",
	"IMPOSSIBLE",
	"TRANSCENDENT",
	"MYTHIC",
	"LEGENDARY",
	"MASTERMIND",
	"SUPER_GENIUS",
	"PRODIGY",
	"GENIUS",
	"EXPERT",
	"ADVANCED",
	"SKILLED",
	"SMART",
	"UNCOMMON",
	"COMMON",
}

local screenGui = nil
local rollButton = nil
local brainSurgeLabel = nil
local rollButtonBrainSurgeStroke = nil
local autoButton = nil
local autoUpButton = nil
local luckButton = nil
local luckBar = nil
local indexButton = nil
local indexPanel = nil
local questButton = nil
local questReadyBadge = nil
local questPanel = nil
local questWorldStatusFrame = nil
local questWorldStatusTitle = nil
local questWorldStatusSubtitle = nil
local questWorldStatusStroke = nil
local questWorldReadyIcon = nil
local chestButton = nil
local chestReadyBadge = nil
local chestPanel = nil
local chestWorldStatusFrame = nil
local chestWorldStatusTitle = nil
local chestWorldStatusSubtitle = nil
local chestWorldStatusStroke = nil
local chestWorldReadyIcon = nil
local isChestWorldAnimating = false
local chestWorldAnimationWarned = false
local nextAreaWorldStatus = {}
local nextAreaPromptState = {}
local area2ReturnPromptState = {}
local rouletteFrame = nil
local rouletteTitle = nil
local rouletteSubtitle = nil
local popupContainer = nil
local questToastContainer = nil
local adminPanel = nil
local adminTestResultText = nil

local overheadGui = nil
local overheadIQLabel = nil
local overheadWinsLabel = nil

local tutorialFrame = nil
local tutorialTitleLabel = nil
local tutorialBodyLabel = nil
local tutorialNextButton = nil
local tutorialSkipButton = nil
local tutorialHighlight = nil

local tutorialActive = false
local tutorialCompletedThisSession = false
local tutorialSkippedThisSession = false
local tutorialStepIndex = 1
local tutorialRollObserved = false
local initialStatsReceived = false

local checkTutorialAutoProgress = function() end

local activePopups = {}
local activeQuestToasts = {}
local dangerousConfirm = {}

local fakeRouletteCandidates = {
	"Drowsy Math Memory|COMMON · +2 IQ",
	"Awake Coding Spark|UNCOMMON · +4 IQ",
	"Focused Science Thinking|SMART · +6 IQ",
	"Trained Logic Strategy|SKILLED · +10 IQ",
	"Advanced AI Pattern|ADVANCED · +20 IQ",
	"Expert Physics Proof|EXPERT · +42 IQ",
	"Top Rank Physics Formula|GENIUS · +18 IQ",
	"Prodigy Algorithm Engine|PRODIGY · +90 IQ",
	"Cosmic AI Paper|SUPER GENIUS · +55 IQ",
	"Mastermind Research Core|MASTERMIND · +150 IQ",
	"Legendary Astronomy Insight|LEGENDARY · +400 IQ",
	"Einstein Transcendent Mind|MYTHIC · +255 IQ",
	"Singularity Formula Breakthrough|TRANSCENDENT · +1800 IQ",
	"Impossible Dimension Split Proof|IMPOSSIBLE · +9000 IQ",
	"Forbidden Dimension Formula|SECRET · +1200 IQ",
	"Reality Breaker Origin Code|REALITY BREAKER · +50000 IQ",
}
local tutorialSteps = {
	{
		Title = "Start Rolling",
		Body = "Press ROLL to earn IQ and discover brain concepts.",
		Target = function()
			return rollButton
		end,
	},
	{
		Title = "IQ Gained",
		Body = "IQ makes you grow faster and helps you reach the next goal.",
		Target = function()
			return rollButton
		end,
	},
	{
		Title = "Concept Index",
		Body = "New Concepts are saved in your Index. More discoveries give growth bonuses.",
		Target = function()
			return indexButton
		end,
	},
	{
		Title = "Luck Upgrade",
		Body = "Use Wins to upgrade Luck. Higher Luck helps you find rarer Concepts.",
		Target = function()
			return luckButton
		end,
	},
	{
		Title = "AutoRoll",
		Body = "Unlock AutoRoll to keep rolling automatically.",
		Target = function()
			return autoButton
		end,
	},
	{
		Title = "Your Goal",
		Body = "Grow IQ, earn Wins, fill the Index, and hunt for rare Concepts.",
		Target = function()
			return nil
		end,
	},
}

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

local function createOptionalSound(name, soundId, volume)
	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume or 0.4
	sound.Parent = SoundService

	return sound
end

local tickSound = createOptionalSound("BrainRNG_RollTick", ROLL_TICK_SOUND_ID, 0.25)
local resultSound = createOptionalSound("BrainRNG_RollResult", ROLL_RESULT_SOUND_ID, 0.55)

local function safePlay(sound)
	if not sound then
		return
	end

	pcall(function()
		sound.TimePosition = 0
		sound:Play()
	end)
end

local function playChestCreakSound(parentForCleanup)
	local soundId = CHEST_CREAK_SOUND_IDS[CHEST_CREAK_SOUND_INDEX]
	if type(soundId) ~= "string" or soundId == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "ChestCreakSound"
	sound.SoundId = soundId
	sound.Volume = CHEST_CREAK_VOLUME
	sound.PlaybackSpeed = 0.85
	sound.Parent = SoundService

	print("[ChestSound] Try play", sound.SoundId, "volume", sound.Volume, "speed", sound.PlaybackSpeed)

	pcall(function()
		SoundService:PlayLocalSound(sound)
	end)

	task.delay(0.4, function()
		if sound then
			print("[ChestSound] After 0.4s", "IsLoaded", sound.IsLoaded, "TimeLength", sound.TimeLength, "Playing", sound.Playing)
		end
	end)

	Debris:AddItem(sound, 4)
end

local function safeStop(sound)
	if not sound then
		return
	end

	pcall(function()
		sound:Stop()
		sound.TimePosition = 0
	end)
end

local function clearOldUi()
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and (child.Name == "BrainRNG_UI" or child.Name == "GameUI" or child.Name == "MainUI") then
			child:Destroy()
		end
	end
end

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(255, 255, 255)
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function splitPopupText(text)
	text = tostring(text or "")

	local title, subtitle = text:match("^(.-)|(.*)$")
	if title and subtitle then
		return title, subtitle
	end

	local rarity, amount = text:match("^(.-)%s+(%+[%d%.KMB]+%s+IQ)$")
	if rarity and amount then
		return rarity, amount
	end

	return text, ""
end

local function displayRarity(rarity)
	local details = RARITY_DETAILS[tostring(rarity or "COMMON")]
	return details and details.Display or tostring(rarity or "COMMON"):gsub("_", " ")
end

local function getRarityFromText(text)
	local upperText = string.upper(tostring(text or ""))

	for _, rarity in ipairs(RARITY_MATCH_ORDER) do
		local details = RARITY_DETAILS[rarity]
		if details then
			if upperText:find(rarity, 1, true) or upperText:find(details.Display, 1, true) then
				return rarity
			end
		end
	end

	return nil
end

local function getRarityRank(rarity)
	local details = RARITY_DETAILS[tostring(rarity or "COMMON")]
	return details and details.Rank or 1
end

local function getRarityEffectLevel(rarity)
	local details = RARITY_DETAILS[tostring(rarity or "COMMON")]
	return details and details.EffectLevel or 1
end

local function isBasicRollRarity(rarity)
	return getRarityRank(rarity) <= getRarityRank("ADVANCED")
end

local function popupTextHasImportantMarker(text)
	local _, subtitle = splitPopupText(text)
	local upperText = string.upper(tostring(subtitle or ""))

	return upperText:find("NEW CONCEPT", 1, true) ~= nil
		or upperText:find("BRAIN SURGE", 1, true) ~= nil
		or upperText:find("INDEX X", 1, true) ~= nil
end

local function getRollPopupEffectLevel(text, popupType)
	if popupType ~= "Roll" then
		return 1, 0
	end

	local _, subtitle = splitPopupText(text)
	local rarity = getRarityFromText(subtitle) or "COMMON"
	local rank = getRarityRank(rarity)
	local effectLevel = getRarityEffectLevel(rarity)

	if popupTextHasImportantMarker(text) then
		effectLevel = math.min(effectLevel + 1, 6)
	end

	if rank > sessionBestRarityRank then
		effectLevel = math.min(effectLevel + 1, 6)
	end

	return effectLevel, rank
end

local function getRarityColor(text)
	text = tostring(text or "")

	local rarity = getRarityFromText(text)
	if rarity and RARITY_DETAILS[rarity] then
		return RARITY_DETAILS[rarity].Color
	end

	if text:find("WIN", 1, true) or text:find("SAVE", 1, true) then
		return Color3.fromRGB(255, 210, 80)
	end

	if text:find("QUEST", 1, true) then
		return Color3.fromRGB(120, 230, 170)
	end

	if text:find("LOCKED", 1, true) or text:find("FAILED", 1, true) then
		return Color3.fromRGB(255, 90, 90)
	end

	return Color3.fromRGB(255, 255, 255)
end

local function createText(parent, name, text, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size or 18
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function showPopup(text, popupType)
	local title, subtitle = splitPopupText(text)
	local effectLevel, rarityRank = getRollPopupEffectLevel(text, popupType)
	local isRareRollPopup = popupType == "Roll" and effectLevel >= 3
	local popupWidth = effectLevel >= 4 and 430 or 360
	local popupHeight = effectLevel >= 4 and 112 or 92
	local strokeThickness = effectLevel >= 5 and 4 or (effectLevel >= 3 and 3 or 2)
	local titleSize = popupType == "Roll" and (effectLevel >= 4 and 27 or 24) or 26
	local subtitleSize = effectLevel >= 4 and 22 or 21

	local frame = Instance.new("Frame")
	frame.Name = "Popup"
	frame:SetAttribute("PopupType", tostring(popupType or "Info"))
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.32, 0)
	frame.Size = UDim2.new(0, popupWidth, 0, popupHeight)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BackgroundTransparency = isRareRollPopup and 0.02 or 0.08
	frame.Parent = popupContainer

	createCorner(frame, 14)
	createStroke(frame, getRarityColor(subtitle ~= "" and subtitle or title), strokeThickness, effectLevel >= 3 and 0.05 or 0.15)

	local titleLabel = createText(frame, "Title", title, titleSize, getRarityColor(subtitle ~= "" and subtitle or title))
	titleLabel.Position = UDim2.new(0, 14, 0, 10)
	titleLabel.Size = UDim2.new(1, -28, 0, effectLevel >= 4 and 42 or 34)

	local subtitleLabel = createText(frame, "Subtitle", subtitle, subtitleSize, Color3.fromRGB(245, 245, 245))
	subtitleLabel.Position = UDim2.new(0, 14, 0, effectLevel >= 4 and 58 or 48)
	subtitleLabel.Size = UDim2.new(1, -28, 0, effectLevel >= 4 and 34 or 28)

	if popupType == "Roll" and rarityRank > sessionBestRarityRank then
		sessionBestRarityRank = rarityRank
	end

	table.insert(activePopups, frame)

	while #activePopups > 3 do
		local old = table.remove(activePopups, 1)
		if old then
			old:Destroy()
		end
	end

	for index, popup in ipairs(activePopups) do
		if popup and popup.Parent then
			TweenService:Create(popup, TweenInfo.new(0.18), {
				Position = UDim2.new(0.5, 0, 0.32 - ((#activePopups - index) * 0.105), 0),
			}):Play()
		end
	end

	frame.Position = UDim2.new(0.5, 0, 0.38, 0)
	TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.32, 0),
	}):Play()

	if effectLevel >= 5 then
		task.spawn(function()
			for index = 1, 4 do
				if not frame.Parent then
					return
				end

				local offset = index % 2 == 0 and -8 or 8
				TweenService:Create(frame, TweenInfo.new(0.035), {
					Position = UDim2.new(0.5, offset, 0.32, 0),
				}):Play()
				task.wait(0.035)
			end

			if frame.Parent then
				TweenService:Create(frame, TweenInfo.new(0.06), {
					Position = UDim2.new(0.5, 0, 0.32, 0),
				}):Play()
			end
		end)
	end

	task.delay(2.2, function()
		if not frame.Parent then
			return
		end

		for index, popup in ipairs(activePopups) do
			if popup == frame then
				table.remove(activePopups, index)
				break
			end
		end

		local tween = TweenService:Create(frame, TweenInfo.new(0.2), {
			BackgroundTransparency = 1,
		})

		for _, child in ipairs(frame:GetDescendants()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.2), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.2), {
					Transparency = 1,
				}):Play()
			end
		end

		tween:Play()
		tween.Completed:Wait()
		frame:Destroy()
	end)
end

local function splitQuestPopupText(text)
	text = tostring(text or "")

	local firstSeparator = string.find(text, "|", 1, true)
	if not firstSeparator then
		return text, "", ""
	end

	local secondSeparator = string.find(text, "|", firstSeparator + 1, true)
	if not secondSeparator then
		return string.sub(text, 1, firstSeparator - 1), string.sub(text, firstSeparator + 1), ""
	end

	return string.sub(text, 1, firstSeparator - 1),
		string.sub(text, firstSeparator + 1, secondSeparator - 1),
		string.sub(text, secondSeparator + 1)
end

local function layoutQuestToasts()
	for index, toast in ipairs(activeQuestToasts) do
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.18), {
				Position = UDim2.new(1, -18, 0, 116 + ((index - 1) * 92)),
			}):Play()
		end
	end
end

local function showQuestToast(text)
	local title, body, reward = splitQuestPopupText(text)
	local parent = questToastContainer or screenGui
	local isChestToast = string.find(title, "CHEST", 1, true) ~= nil
	local accentColor = isChestToast and Color3.fromRGB(255, 205, 80) or Color3.fromRGB(120, 235, 165)
	local titleColor = isChestToast and Color3.fromRGB(255, 225, 115) or Color3.fromRGB(145, 255, 185)

	local frame = Instance.new("Frame")
	frame.Name = "QuestToast"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, 18, 0, 116)
	frame.Size = UDim2.new(0, 286, 0, reward ~= "" and 86 or 70)
	frame.BackgroundColor3 = Color3.fromRGB(18, 28, 24)
	frame.BackgroundTransparency = 0.08
	frame.ZIndex = 70
	frame.Parent = parent

	createCorner(frame, 12)
	createStroke(frame, accentColor, 2, 0.12)

	local titleLabel = createText(frame, "Title", title, 18, titleColor)
	titleLabel.Position = UDim2.new(0, 12, 0, 8)
	titleLabel.Size = UDim2.new(1, -24, 0, 22)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = frame.ZIndex + 1

	local bodyLabel = createText(frame, "Body", body, 15, Color3.fromRGB(245, 245, 245))
	bodyLabel.Position = UDim2.new(0, 12, 0, 32)
	bodyLabel.Size = UDim2.new(1, -24, 0, 20)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.ZIndex = frame.ZIndex + 1

	if reward ~= "" then
		local rewardLabel = createText(frame, "Reward", reward, 14, Color3.fromRGB(255, 230, 120))
		rewardLabel.Position = UDim2.new(0, 12, 0, 56)
		rewardLabel.Size = UDim2.new(1, -24, 0, 20)
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
		rewardLabel.ZIndex = frame.ZIndex + 1
	end

	table.insert(activeQuestToasts, frame)

	while #activeQuestToasts > 2 do
		local old = table.remove(activeQuestToasts, 1)
		if old then
			old:Destroy()
		end
	end

	layoutQuestToasts()

	TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -18, 0, 116 + ((#activeQuestToasts - 1) * 92)),
	}):Play()

	task.delay(2.2, function()
		if not frame.Parent then
			return
		end

		for index, toast in ipairs(activeQuestToasts) do
			if toast == frame then
				table.remove(activeQuestToasts, index)
				break
			end
		end

		for _, child in ipairs(frame:GetDescendants()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.18), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.18), {
					Transparency = 1,
				}):Play()
			end
		end

		local currentPosition = frame.Position
		local tween = TweenService:Create(frame, TweenInfo.new(0.18), {
			BackgroundTransparency = 1,
			Position = UDim2.new(
				currentPosition.X.Scale,
				currentPosition.X.Offset + 24,
				currentPosition.Y.Scale,
				currentPosition.Y.Offset
			),
		})
		tween:Play()
		tween.Completed:Wait()
		frame:Destroy()
		layoutQuestToasts()
	end)
end

local function showChestOpenAnimation(titleText, rewardText)
	if not screenGui then
		return
	end

	local existing = screenGui:FindFirstChild("ChestOpenAnimation")
	if existing then
		existing:Destroy()
	end

	local frame = Instance.new("Frame")
	frame.Name = "ChestOpenAnimation"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0, 360, 0, 260)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 100
	frame.Parent = screenGui

	local frameScale = Instance.new("UIScale")
	frameScale.Scale = 0.84
	frameScale.Parent = frame

	local glow = Instance.new("Frame")
	glow.Name = "ChestGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0.45, 0)
	glow.Size = UDim2.new(0, 20, 0, 20)
	glow.BackgroundColor3 = Color3.fromRGB(255, 230, 90)
	glow.BackgroundTransparency = 0.25
	glow.Visible = false
	glow.ZIndex = 101
	glow.Parent = frame
	createCorner(glow, 999)

	local body = Instance.new("Frame")
	body.Name = "ChestBody"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.new(0.5, 0, 0.72, 0)
	body.Size = UDim2.new(0, 190, 0, 95)
	body.BackgroundColor3 = Color3.fromRGB(115, 68, 28)
	body.ZIndex = 103
	body.Parent = frame
	createCorner(body, 14)
	createStroke(body, Color3.fromRGB(255, 185, 70), 2, 0.16)

	local bodyBand = Instance.new("Frame")
	bodyBand.Name = "BodyBand"
	bodyBand.Position = UDim2.new(0, 0, 0.5, -6)
	bodyBand.Size = UDim2.new(1, 0, 0, 12)
	bodyBand.BackgroundColor3 = Color3.fromRGB(75, 43, 18)
	bodyBand.BackgroundTransparency = 0.15
	bodyBand.ZIndex = 104
	bodyBand.Parent = body

	local lock = Instance.new("Frame")
	lock.Name = "ChestLock"
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.new(0.5, 0, 0.38, 0)
	lock.Size = UDim2.new(0, 38, 0, 34)
	lock.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
	lock.ZIndex = 105
	lock.Parent = body
	createCorner(lock, 8)
	createStroke(lock, Color3.fromRGB(110, 75, 18), 1, 0.25)

	local lid = Instance.new("Frame")
	lid.Name = "ChestLid"
	lid.AnchorPoint = Vector2.new(0.5, 1)
	lid.Position = UDim2.new(0.5, 0, 0.38, 0)
	lid.Size = UDim2.new(0, 205, 0, 58)
	lid.BackgroundColor3 = Color3.fromRGB(135, 78, 32)
	lid.ZIndex = 104
	lid.Parent = frame
	createCorner(lid, 14)
	createStroke(lid, Color3.fromRGB(255, 200, 80), 2, 0.14)

	local lidBand = Instance.new("Frame")
	lidBand.Name = "LidGoldLine"
	lidBand.Position = UDim2.new(0, 10, 0.55, 0)
	lidBand.Size = UDim2.new(1, -20, 0, 8)
	lidBand.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
	lidBand.ZIndex = 105
	lidBand.Parent = lid
	createCorner(lidBand, 999)

	local reward = createText(frame, "RewardText", tostring(rewardText or titleText or "REWARD!"), 28, Color3.fromRGB(255, 235, 100))
	reward.AnchorPoint = Vector2.new(0.5, 0.5)
	reward.Position = UDim2.new(0.5, 0, 0.45, 0)
	reward.Size = UDim2.new(0, 320, 0, 50)
	reward.BackgroundTransparency = 1
	reward.TextStrokeTransparency = 0.25
	reward.TextTransparency = 1
	reward.ZIndex = 107

	TweenService:Create(frameScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.spawn(function()
		task.wait(0.12)

		if not frame.Parent then
			return
		end

		for _, offset in ipairs({ -8, 8, -5, 5, 0 }) do
			if not frame.Parent then
				return
			end

			TweenService:Create(body, TweenInfo.new(0.05), {
				Position = UDim2.new(0.5, offset, 0.72, 0),
			}):Play()

			TweenService:Create(lid, TweenInfo.new(0.05), {
				Position = UDim2.new(0.5, offset, 0.38, 0),
			}):Play()

			task.wait(0.05)
		end

		if not frame.Parent then
			return
		end

		playChestCreakSound(frame)

		if not frame.Parent then
			return
		end

		TweenService:Create(lid, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -10, 0.25, 0),
			Rotation = -12,
		}):Play()

		glow.Visible = true
		TweenService:Create(glow, TweenInfo.new(0.32), {
			Size = UDim2.new(0, 220, 0, 220),
			BackgroundTransparency = 0.88,
		}):Play()

		local particleChars = { "*", "+", "o", "$" }
		for index = 1, 12 do
			local particle = Instance.new("TextLabel")
			particle.Name = "ChestParticle"
			particle.AnchorPoint = Vector2.new(0.5, 0.5)
			particle.Position = UDim2.new(0.5, math.random(-12, 12), 0.48, math.random(-10, 10))
			particle.Size = UDim2.new(0, 36, 0, 36)
			particle.BackgroundTransparency = 1
			particle.Text = particleChars[((index - 1) % #particleChars) + 1]
			particle.Font = Enum.Font.GothamBlack
			particle.TextSize = math.random(18, 28)
			particle.TextColor3 = index % 3 == 0 and Color3.fromRGB(255, 255, 180) or Color3.fromRGB(255, 210, 65)
			particle.TextStrokeTransparency = 0.45
			particle.ZIndex = 106
			particle.Parent = frame

			local xOffset = math.random(-135, 135)
			local yOffset = math.random(-110, -35)
			TweenService:Create(particle, TweenInfo.new(math.random(50, 80) / 100), {
				Position = UDim2.new(0.5, xOffset, 0.45, yOffset),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Rotation = math.random(-45, 45),
			}):Play()

			task.delay(0.85, function()
				if particle.Parent then
					particle:Destroy()
				end
			end)
		end

		TweenService:Create(reward, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.18, 0),
			TextTransparency = 0,
		}):Play()
	end)

	task.delay(1.05, function()
		if not frame.Parent then
			return
		end

		for _, descendant in ipairs(frame:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, TweenInfo.new(0.15), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif descendant:IsA("Frame") then
				TweenService:Create(descendant, TweenInfo.new(0.15), {
					BackgroundTransparency = 1,
				}):Play()
			elseif descendant:IsA("UIStroke") then
				TweenService:Create(descendant, TweenInfo.new(0.15), {
					Transparency = 1,
				}):Play()
			end
		end

		local tween = TweenService:Create(frame, TweenInfo.new(0.15), {
			BackgroundTransparency = 1,
		})

		TweenService:Create(frameScale, TweenInfo.new(0.15), {
			Scale = 0.75,
		}):Play()

		tween:Play()
		tween.Completed:Wait()
		frame:Destroy()
	end)
end

local function clearRollPopups()
	for index = #activePopups, 1, -1 do
		local popup = activePopups[index]
		if not popup or not popup.Parent then
			table.remove(activePopups, index)
		elseif popup:GetAttribute("PopupType") == "Roll" then
			popup:Destroy()
			table.remove(activePopups, index)
		end
	end
end

local function updateOverheadStats()
	if not overheadIQLabel or not overheadWinsLabel then
		return
	end

	overheadIQLabel.Text = "IQ " .. formatNumber(stats.IQ)
	overheadWinsLabel.Text = "WINS " .. formatNumber(stats.Wins)
end

local function createOverheadStats(character)
	overheadGui = nil
	overheadIQLabel = nil
	overheadWinsLabel = nil

	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end

	local existing = head:FindFirstChild("BrainRNG_OverheadStats")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainRNG_OverheadStats"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 220, 0, 54)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 80
	gui.Parent = head

	local iqLabel = createText(gui, "IQ", "", 20, Color3.fromRGB(255, 235, 120))
	iqLabel.Position = UDim2.new(0, 0, 0, 0)
	iqLabel.Size = UDim2.new(1, 0, 0, 26)

	local winsLabel = createText(gui, "Wins", "", 18, Color3.fromRGB(255, 255, 255))
	winsLabel.Position = UDim2.new(0, 0, 0, 25)
	winsLabel.Size = UDim2.new(1, 0, 0, 24)

	overheadGui = gui
	overheadIQLabel = iqLabel
	overheadWinsLabel = winsLabel

	updateOverheadStats()
end

local function refreshIndexPanel()
	if not indexPanel then
		return
	end

	local content = indexPanel:FindFirstChild("Content")
	if not content then
		return
	end

	local totalLabel = content:FindFirstChild("Total")
	if totalLabel then
		totalLabel.Text = "Total: " .. formatNumber(stats.DiscoveredConcepts) .. " / " .. formatNumber(stats.TotalConcepts)
	end

	local kpLabel = content:FindFirstChild("KP")
	if kpLabel then
		kpLabel.Text = "KP: " .. formatNumber(stats.KnowledgePoints)
	end

	local levelLabel = content:FindFirstChild("Level")
	if levelLabel then
		levelLabel.Text = "Index Lv: " .. tostring(stats.IndexLevel)
	end

	local bonusLabel = content:FindFirstChild("Bonus")
	if bonusLabel then
		bonusLabel.Text = "KP IQ Bonus: x" .. string.format("%.2f", tonumber(stats.IndexIQMultiplier) or 1)
	end

	local milestoneBonusLabel = content:FindFirstChild("MilestoneBonus")
	if milestoneBonusLabel then
		milestoneBonusLabel.Text = "Index Milestone Bonus: x" .. string.format("%.2f", tonumber(stats.IndexMilestoneBonus) or 1)
	end

	local nextMilestoneLabel = content:FindFirstChild("NextMilestone")
	if nextMilestoneLabel then
		if stats.NextIndexMilestone then
			nextMilestoneLabel.Text = "Next Reward: " .. formatNumber(stats.NextIndexMilestone) .. " Concepts -> x" .. string.format("%.2f", tonumber(stats.NextIndexMilestoneBonus) or 1)
		else
			nextMilestoneLabel.Text = "Next Reward: MAX"
		end
	end

	local rarityLabel = content:FindFirstChild("Rarity")
	if rarityLabel then
		local counts = stats.DiscoveredByRarity or {}
		local lines = {}

		for _, rarity in ipairs(RARITY_ORDER) do
			table.insert(lines, displayRarity(rarity) .. " " .. tostring(counts[rarity] or 0))
		end

		rarityLabel.Text = table.concat(lines, "\n")
	end

	local recentLabel = content:FindFirstChild("Recent")
	if recentLabel then
		local lines = {}

		for _, item in ipairs(stats.RecentConcepts or {}) do
			table.insert(lines, tostring(item.Name or "Unknown") .. " [" .. displayRarity(item.Rarity or "COMMON") .. "]")
		end

		if #lines == 0 then
			table.insert(lines, "No discoveries yet")
		end

		recentLabel.Text = "Recent:\n" .. table.concat(lines, "\n")
	end
end

local UISections = {}

function UISections.getQuestSummary()
	local claimable = 0
	local claimed = 0
	local total = 0

	for _, quest in ipairs(stats.Quests or {}) do
		total += 1

		if quest.Claimed then
			claimed += 1
		elseif quest.Completed then
			claimable += 1
		end
	end

	return claimable, claimed, total
end

function UISections.hasClaimableQuest(quests)
	for _, quest in ipairs(quests or {}) do
		if quest.Completed == true and quest.Claimed ~= true then
			return true
		end
	end

	return false
end

function UISections.refreshQuestReadyIndicator()
	if questReadyBadge then
		questReadyBadge.Visible = UISections.hasClaimableQuest(stats.Quests)
	end
end

function UISections.resolveQuestWorldStatus()
	if questWorldStatusTitle and questWorldStatusTitle.Parent and questWorldStatusSubtitle and questWorldStatusSubtitle.Parent then
		return true
	end

	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	if not simpleMap then
		return false
	end

	local questBody = simpleMap:FindFirstChild("ProfessorBrain_Body")
	if not questBody then
		return false
	end

	local billboard = questBody:FindFirstChild("QuestStatusBillboard")
	if not billboard then
		return false
	end

	local frame = billboard:FindFirstChild("StatusFrame")
	if not frame then
		return false
	end

	questWorldStatusFrame = frame
	questWorldStatusTitle = frame:FindFirstChild("QuestStatusTitle")
	questWorldStatusSubtitle = frame:FindFirstChild("QuestStatusSubtitle")
	questWorldStatusStroke = frame:FindFirstChild("StatusStroke")
	questWorldReadyIcon = simpleMap:FindFirstChild("QuestReadyIcon")

	return questWorldStatusTitle ~= nil and questWorldStatusSubtitle ~= nil
end

function UISections.refreshQuestWorldStatus()
	if not UISections.resolveQuestWorldStatus() then
		return
	end

	local claimable, claimed, total = UISections.getQuestSummary()
	local title = "QUESTS"
	local subtitle = "Check Progress"
	local accentColor = Color3.fromRGB(120, 235, 165)
	local frameColor = Color3.fromRGB(18, 28, 24)
	local iconColor = Color3.fromRGB(110, 124, 138)
	local iconTransparency = 0.35
	local iconMaterial = Enum.Material.SmoothPlastic

	if claimable > 0 then
		title = "QUEST READY!"
		subtitle = "Claim Reward"
		accentColor = Color3.fromRGB(255, 220, 90)
		frameColor = Color3.fromRGB(42, 34, 18)
		iconColor = Color3.fromRGB(255, 220, 90)
		iconTransparency = 0
		iconMaterial = Enum.Material.Neon
	elseif total > 0 and claimed >= total then
		title = "QUESTS"
		subtitle = "All Claimed"
		accentColor = Color3.fromRGB(145, 160, 165)
		frameColor = Color3.fromRGB(30, 34, 38)
	elseif total > 0 then
		title = "QUESTS"
		subtitle = "Progressing..."
	end

	questWorldStatusTitle.Text = title
	questWorldStatusTitle.TextColor3 = accentColor
	questWorldStatusSubtitle.Text = subtitle
	questWorldStatusSubtitle.TextColor3 = Color3.fromRGB(245, 245, 245)

	if questWorldStatusFrame then
		questWorldStatusFrame.BackgroundColor3 = frameColor
	end

	if questWorldStatusStroke then
		questWorldStatusStroke.Color = accentColor
		questWorldStatusStroke.Thickness = claimable > 0 and 3 or 2
		questWorldStatusStroke.Transparency = claimable > 0 and 0.05 or 0.25
	end

	if questWorldReadyIcon then
		questWorldReadyIcon.Color = iconColor
		questWorldReadyIcon.Transparency = iconTransparency
		questWorldReadyIcon.Material = iconMaterial
	end
end

local setQuestPanelContentZIndex

function UISections.getQuestUiState(quest)
	if quest.Claimed then
		return "CLAIMED", "Claimed", Color3.fromRGB(145, 160, 165), Color3.fromRGB(48, 56, 60)
	end

	if quest.Completed then
		return "READY", "Ready", Color3.fromRGB(255, 220, 90), Color3.fromRGB(72, 58, 18)
	end

	return "IN_PROGRESS", "In Progress", Color3.fromRGB(125, 205, 255), Color3.fromRGB(34, 48, 62)
end

function UISections.createQuestClaimButton(parent, quest)
	local button = Instance.new("TextButton")
	button.Name = "Claim_" .. tostring(quest.Id or "Quest")
	button.Size = UDim2.new(0, 92, 0, 34)
	button.Position = UDim2.new(1, -102, 1, -42)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 14
	button.TextWrapped = true
	button.AutoButtonColor = false
	button.Parent = parent

	createCorner(button, 10)
	createStroke(button, Color3.fromRGB(255, 255, 255), 1, 0.5)

	if quest.Claimed then
		button.Text = "CLAIMED"
		button.Active = false
		button.Selectable = false
		button.BackgroundColor3 = Color3.fromRGB(55, 65, 70)
		button.TextColor3 = Color3.fromRGB(190, 205, 210)
		return button
	end

	if quest.Completed then
		button.Text = "CLAIM"
		button.Active = true
		button.Selectable = true
		button.BackgroundColor3 = Color3.fromRGB(255, 210, 80)
		button.TextColor3 = Color3.fromRGB(45, 30, 0)
		button.MouseButton1Click:Connect(function()
			QuestClaimRequest:FireServer(quest.Id)
		end)
		return button
	end

	button.Text = "PROGRESS"
	button.Active = false
	button.Selectable = false
	button.BackgroundColor3 = Color3.fromRGB(70, 55, 60)
	button.TextColor3 = Color3.fromRGB(230, 230, 230)
	return button
end

function UISections.refreshQuestPanel()
	if questButton then
		local claimable, claimed, total = UISections.getQuestSummary()

		if claimable > 0 then
			questButton.Text = "Quests\n" .. tostring(claimable) .. " Ready"
			questButton.BackgroundColor3 = Color3.fromRGB(68, 110, 78)
			questButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			questButton.Text = "Quests\n" .. tostring(claimed) .. "/" .. tostring(total)
			questButton.BackgroundColor3 = Color3.fromRGB(45, 75, 62)
			questButton.TextColor3 = Color3.fromRGB(235, 255, 240)
		end
	end

	UISections.refreshQuestReadyIndicator()

	if not questPanel then
		return
	end

	local list = questPanel:FindFirstChild("QuestList")
	if not list then
		return
	end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, quest in ipairs(stats.Quests or {}) do
		local stateKey, stateText, stateColor, stateBackgroundColor = UISections.getQuestUiState(quest)
		local card = Instance.new("Frame")
		card.Name = "QuestCard_" .. tostring(quest.Id or "Unknown")
		card.Size = UDim2.new(1, -10, 0, 128)
		card.BackgroundColor3 = quest.Claimed and Color3.fromRGB(24, 30, 34) or Color3.fromRGB(24, 28, 38)
		card.Parent = list

		createCorner(card, 12)
		createStroke(card, stateKey == "READY" and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(85, 95, 110), stateKey == "READY" and 2 or 1, 0.28)

		local title = createText(card, "Title", tostring(quest.Title or "Quest"), 17, Color3.fromRGB(255, 240, 150))
		title.Position = UDim2.new(0, 12, 0, 8)
		title.Size = UDim2.new(1, -120, 0, 24)
		title.TextXAlignment = Enum.TextXAlignment.Left

		local status = createText(card, "Status", stateText, 12, stateColor)
		status.Font = Enum.Font.GothamBlack
		status.Position = UDim2.new(1, -102, 0, 8)
		status.Size = UDim2.new(0, 92, 0, 24)
		status.BackgroundColor3 = stateBackgroundColor
		status.BackgroundTransparency = 0.05
		status.TextStrokeTransparency = 0.75
		createCorner(status, 8)
		createStroke(status, stateColor, 1, 0.35)

		local description = createText(card, "Description", tostring(quest.Description or ""), 13, Color3.fromRGB(210, 220, 230))
		description.Font = Enum.Font.GothamBold
		description.Position = UDim2.new(0, 12, 0, 34)
		description.Size = UDim2.new(1, -124, 0, 36)
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextYAlignment = Enum.TextYAlignment.Top

		local progress = math.min(tonumber(quest.Progress) or 0, tonumber(quest.Goal) or 0)
		local goal = tonumber(quest.Goal) or 0
		local progressLabel = createText(card, "Progress", "Progress: " .. formatNumber(progress) .. " / " .. formatNumber(goal), 14, Color3.fromRGB(160, 230, 255))
		progressLabel.Font = Enum.Font.GothamBold
		progressLabel.Position = UDim2.new(0, 12, 1, -52)
		progressLabel.Size = UDim2.new(1, -124, 0, 20)
		progressLabel.TextXAlignment = Enum.TextXAlignment.Left

		local progressBar = Instance.new("Frame")
		progressBar.Name = "ProgressBar"
		progressBar.Position = UDim2.new(0, 12, 1, -30)
		progressBar.Size = UDim2.new(1, -124, 0, 8)
		progressBar.BackgroundColor3 = Color3.fromRGB(36, 44, 54)
		progressBar.BorderSizePixel = 0
		progressBar.Parent = card
		createCorner(progressBar, 999)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(goal > 0 and math.clamp(progress / goal, 0, 1) or 0, 0, 1, 0)
		fill.BackgroundColor3 = stateKey == "CLAIMED" and Color3.fromRGB(115, 135, 145) or stateColor
		fill.BorderSizePixel = 0
		fill.Parent = progressBar
		createCorner(fill, 999)

		local reward = createText(card, "Reward", "Reward: " .. tostring(quest.RewardText or ""), 14, Color3.fromRGB(170, 255, 190))
		reward.Font = Enum.Font.GothamBold
		reward.Position = UDim2.new(0, 12, 1, -18)
		reward.Size = UDim2.new(1, -124, 0, 18)
		reward.TextXAlignment = Enum.TextXAlignment.Left

		UISections.createQuestClaimButton(card, quest)
	end

	if setQuestPanelContentZIndex then
		setQuestPanelContentZIndex()
	end
end

function UISections.getChestInfo()
	if type(stats.Chest) ~= "table" then
		return {
			Points = 0,
			BasicCost = 25,
			CanOpenBasic = false,
			TotalOpened = 0,
		}
	end

	return stats.Chest
end

function UISections.resolveChestWorldStatus()
	if chestWorldStatusTitle and chestWorldStatusTitle.Parent and chestWorldStatusSubtitle and chestWorldStatusSubtitle.Parent then
		return true
	end

	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	if not simpleMap then
		return false
	end

	local station = simpleMap:FindFirstChild("WorldChestStation")
	if not station then
		return false
	end

	local chestModel = station:FindFirstChild("WorldChestModel")
	if not chestModel then
		return false
	end

	local billboard = chestModel:FindFirstChild("ChestStatusBillboard")
	if not billboard then
		return false
	end

	local frame = billboard:FindFirstChild("StatusFrame")
	if not frame then
		return false
	end

	chestWorldStatusFrame = frame
	chestWorldStatusTitle = frame:FindFirstChild("ChestStatusTitle")
	chestWorldStatusSubtitle = frame:FindFirstChild("ChestStatusSubtitle")
	chestWorldStatusStroke = frame:FindFirstChild("StatusStroke")
	chestWorldReadyIcon = station:FindFirstChild("ChestReadyIcon")

	return chestWorldStatusTitle ~= nil and chestWorldStatusSubtitle ~= nil
end

function UISections.refreshChestWorldStatus()
	if not UISections.resolveChestWorldStatus() then
		return
	end

	local chest = UISections.getChestInfo()
	local points = tonumber(chest.Points) or 0
	local cost = tonumber(chest.BasicCost) or 25
	local canOpen = chest.CanOpenBasic == true or points >= cost

	local title = "NEED CP"
	local subtitle = "Earn Chest Points"
	local accentColor = Color3.fromRGB(190, 170, 130)
	local frameColor = Color3.fromRGB(32, 28, 22)
	local iconColor = Color3.fromRGB(110, 124, 138)
	local iconTransparency = 0.35
	local iconMaterial = Enum.Material.SmoothPlastic

	if canOpen then
		title = "CHEST READY!"
		subtitle = "Open Basic Chest"
		accentColor = Color3.fromRGB(255, 220, 90)
		frameColor = Color3.fromRGB(48, 34, 14)
		iconColor = Color3.fromRGB(255, 220, 90)
		iconTransparency = 0
		iconMaterial = Enum.Material.Neon
	elseif cost <= 0 then
		title = "CHESTS"
		subtitle = "Spend CP for Rewards"
		accentColor = Color3.fromRGB(255, 205, 80)
	end

	chestWorldStatusTitle.Text = title
	chestWorldStatusTitle.TextColor3 = accentColor
	chestWorldStatusSubtitle.Text = subtitle
	chestWorldStatusSubtitle.TextColor3 = Color3.fromRGB(245, 245, 245)

	if chestWorldStatusFrame then
		chestWorldStatusFrame.BackgroundColor3 = frameColor
	end

	if chestWorldStatusStroke then
		chestWorldStatusStroke.Color = accentColor
		chestWorldStatusStroke.Thickness = canOpen and 3 or 2
		chestWorldStatusStroke.Transparency = canOpen and 0.05 or 0.25
	end

	if chestWorldReadyIcon then
		chestWorldReadyIcon.Color = iconColor
		chestWorldReadyIcon.Transparency = iconTransparency
		chestWorldReadyIcon.Material = iconMaterial
	end
end

function UISections.refreshChestReadyIndicator()
	local chest = UISections.getChestInfo()
	local canOpen = chest.CanOpenBasic == true

	if chestReadyBadge then
		chestReadyBadge.Visible = canOpen
	end
end

function UISections.resolveNextAreaGateStatus()
	if nextAreaWorldStatus.Title and nextAreaWorldStatus.Title.Parent and nextAreaWorldStatus.Subtitle and nextAreaWorldStatus.Subtitle.Parent then
		return true
	end

	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	local gate = simpleMap and simpleMap:FindFirstChild("NextAreaGate")
	local billboard = gate and gate:FindFirstChild("NextAreaGateBillboard", true)
	local frame = billboard and billboard:FindFirstChild("NextAreaGateBillboardFrame")

	if not frame then
		return false
	end

	nextAreaWorldStatus.Frame = frame
	nextAreaWorldStatus.Title = frame:FindFirstChild("NextAreaGateTitle")
	nextAreaWorldStatus.Subtitle = frame:FindFirstChild("NextAreaGateSubtitle")
	nextAreaWorldStatus.Stroke = frame:FindFirstChildOfClass("UIStroke")
	nextAreaWorldStatus.Door = gate:FindFirstChild("NextAreaGate_Door")
	nextAreaWorldStatus.BottomGlow = gate:FindFirstChild("NextAreaGateFrame_BottomGlow")
	nextAreaWorldStatus.LockIcon = gate:FindFirstChild("NextAreaLockIcon")

	if not nextAreaWorldStatus.Title or not nextAreaWorldStatus.Subtitle then
		if not nextAreaWorldStatus.Warned then
			nextAreaWorldStatus.Warned = true
			warn("[NextAreaGate] Billboard labels missing; gate status update skipped.")
		end

		return false
	end

	return true
end

function UISections.refreshNextAreaGateStatus()
	if not UISections.resolveNextAreaGateStatus() then
		return
	end

	local ready = (tonumber(stats.IQ) or 0) >= NEXT_AREA_REQUIRED_IQ
	local title = ready and "AREA 2 READY" or "AREA 2 LOCKED"
	local subtitle = ready and "Unlock Coming Soon" or "Need 10,000 IQ"
	local accentColor = ready and Color3.fromRGB(105, 240, 210) or Color3.fromRGB(170, 180, 205)
	local frameColor = ready and Color3.fromRGB(16, 42, 38) or Color3.fromRGB(24, 26, 34)

	nextAreaWorldStatus.Title.Text = title
	nextAreaWorldStatus.Title.TextColor3 = accentColor
	nextAreaWorldStatus.Subtitle.Text = subtitle
	nextAreaWorldStatus.Subtitle.TextColor3 = Color3.fromRGB(245, 245, 245)

	if nextAreaWorldStatus.Frame then
		nextAreaWorldStatus.Frame.BackgroundColor3 = frameColor
	end

	if nextAreaWorldStatus.Stroke then
		nextAreaWorldStatus.Stroke.Color = accentColor
		nextAreaWorldStatus.Stroke.Thickness = ready and 3 or 2
		nextAreaWorldStatus.Stroke.Transparency = ready and 0.08 or 0.3
	end

	if nextAreaWorldStatus.Door then
		nextAreaWorldStatus.Door.Color = ready and Color3.fromRGB(150, 235, 255) or Color3.fromRGB(145, 160, 175)
		nextAreaWorldStatus.Door.Transparency = ready and 0.32 or 0.58
	end

	if nextAreaWorldStatus.BottomGlow then
		nextAreaWorldStatus.BottomGlow.Color = ready and Color3.fromRGB(100, 240, 210) or Color3.fromRGB(95, 110, 130)
		nextAreaWorldStatus.BottomGlow.Transparency = ready and 0.28 or 0.7
	end

	if nextAreaWorldStatus.LockIcon then
		nextAreaWorldStatus.LockIcon.Color = ready and Color3.fromRGB(115, 225, 245) or Color3.fromRGB(185, 160, 90)
		nextAreaWorldStatus.LockIcon.Transparency = ready and 0.16 or 0.08
		nextAreaWorldStatus.LockIcon.Material = Enum.Material.SmoothPlastic
	end
end

function UISections.connectNextAreaPrompt()
	task.spawn(function()
		local prompt = nil
		local deadline = os.clock() + 8

		while os.clock() < deadline and not prompt do
			local simpleMap = Workspace:FindFirstChild("SimpleMap")
			local gate = simpleMap and simpleMap:FindFirstChild("NextAreaGate")
			local door = gate and gate:FindFirstChild("NextAreaGate_Door")

			prompt = door and door:FindFirstChild("NextAreaPrompt")
			if not prompt and gate then
				prompt = gate:FindFirstChild("NextAreaPrompt", true)
			end

			if prompt and not prompt:IsA("ProximityPrompt") then
				prompt = nil
			end

			if not prompt then
				task.wait(0.2)
			end
		end

		if not prompt then
			if not nextAreaPromptState.Warned then
				nextAreaPromptState.Warned = true
				warn("[NextAreaPrompt] Missing after retry; request connection skipped.")
			end

			return
		end

		if nextAreaPromptState.Prompt == prompt and nextAreaPromptState.Connection then
			return
		end

		if nextAreaPromptState.Connection then
			nextAreaPromptState.Connection:Disconnect()
		end

		nextAreaPromptState.Prompt = prompt
		nextAreaPromptState.Connection = prompt.Triggered:Connect(function()
			NextAreaRequest:FireServer()
		end)

		if not nextAreaPromptState.ConnectedLogged then
			nextAreaPromptState.ConnectedLogged = true
			print("[NextAreaPrompt] Connected")
		end
	end)
end

function UISections.connectArea2ReturnPrompt()
	task.spawn(function()
		local prompt = nil
		local deadline = os.clock() + 8

		while os.clock() < deadline and not prompt do
			local simpleMap = Workspace:FindFirstChild("SimpleMap")
			local previewZone = simpleMap and simpleMap:FindFirstChild("Area2PreviewZone")
			local promptPart = previewZone and previewZone:FindFirstChild("Area2ReturnPromptPart")

			prompt = promptPart and promptPart:FindFirstChild("Area2ReturnPrompt")
			if not prompt and previewZone then
				prompt = previewZone:FindFirstChild("Area2ReturnPrompt", true)
			end

			if prompt and not prompt:IsA("ProximityPrompt") then
				prompt = nil
			end

			if not prompt then
				task.wait(0.2)
			end
		end

		if not prompt then
			if not area2ReturnPromptState.Warned then
				area2ReturnPromptState.Warned = true
				warn("[Area2ReturnPrompt] Missing after retry; request connection skipped.")
			end

			return
		end

		if area2ReturnPromptState.Prompt == prompt and area2ReturnPromptState.Connection then
			return
		end

		if area2ReturnPromptState.Connection then
			area2ReturnPromptState.Connection:Disconnect()
		end

		area2ReturnPromptState.Prompt = prompt
		area2ReturnPromptState.Connection = prompt.Triggered:Connect(function()
			ReturnToLobbyRequest:FireServer()
		end)

		if not area2ReturnPromptState.ConnectedLogged then
			area2ReturnPromptState.ConnectedLogged = true
			print("[Area2ReturnPrompt] Connected")
		end
	end)
end

function UISections.refreshChestPanel()
	local chest = UISections.getChestInfo()
	local points = tonumber(chest.Points) or 0
	local cost = tonumber(chest.BasicCost) or 25
	local totalOpened = tonumber(chest.TotalOpened) or 0
	local canOpen = chest.CanOpenBasic == true or points >= cost

	if chestButton then
		chestButton.Text = "Rewards\n" .. formatNumber(points) .. " CP"
		chestButton.BackgroundColor3 = canOpen and Color3.fromRGB(120, 88, 35) or Color3.fromRGB(70, 55, 42)
		chestButton.TextColor3 = Color3.fromRGB(255, 242, 190)
	end

	UISections.refreshChestReadyIndicator()
	UISections.refreshChestWorldStatus()

	if not chestPanel then
		return
	end

	local pointsLabel = chestPanel:FindFirstChild("ChestPoints")
	if pointsLabel then
		pointsLabel.Text = "Chest Points: " .. formatNumber(points) .. " / " .. formatNumber(cost)
	end

	local openedLabel = chestPanel:FindFirstChild("Opened")
	if openedLabel then
		openedLabel.Text = "Opened this session: " .. formatNumber(totalOpened)
	end

	local openButton = chestPanel:FindFirstChild("OpenBasic")
	if openButton then
		if canOpen then
			openButton.Text = "OPEN BASIC"
			openButton.BackgroundColor3 = Color3.fromRGB(255, 205, 75)
			openButton.TextColor3 = Color3.fromRGB(45, 30, 0)
			openButton.Active = true
			openButton.AutoButtonColor = true
		else
			openButton.Text = "NEED " .. formatNumber(cost) .. " CP"
			openButton.BackgroundColor3 = Color3.fromRGB(72, 62, 50)
			openButton.TextColor3 = Color3.fromRGB(225, 210, 180)
			openButton.Active = false
			openButton.AutoButtonColor = false
		end
	end
end

function UISections.playWorldChestOpenAnimation()
	if isChestWorldAnimating then
		return
	end

	local simpleMap = Workspace:FindFirstChild("SimpleMap")
	local station = simpleMap and simpleMap:FindFirstChild("WorldChestStation")
	local chest = station and station:FindFirstChild("WorldChestModel")

	if not chest or not chest:IsA("BasePart") then
		if not chestWorldAnimationWarned then
			chestWorldAnimationWarned = true
			warn("[ChestWorldAnimation] WorldChestModel missing; animation skipped.")
		end

		return
	end

	isChestWorldAnimating = true

	task.spawn(function()
		local lid = station:FindFirstChild("WorldChestLid")
		local band = station:FindFirstChild("WorldChestBand")
		local readyIcon = station:FindFirstChild("ChestReadyIcon")
		local chestCFrame = chest.CFrame
		local chestSize = chest.Size
		local lidCFrame = lid and lid:IsA("BasePart") and lid.CFrame or nil
		local bandCFrame = band and band:IsA("BasePart") and band.CFrame or nil
		local chestPopSize = Vector3.new(chestSize.X * 1.015, chestSize.Y * 1.015, chestSize.Z * 1.015)
		local chestReactInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local lidOpenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local settleInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		if not lidCFrame and not chestWorldAnimationWarned then
			chestWorldAnimationWarned = true
			warn("[ChestWorldAnimation] WorldChestLid missing; using body-only animation.")
		end

		local chestPopTween = TweenService:Create(chest, chestReactInfo, {
			CFrame = chestCFrame * CFrame.new(0, 0.08, 0),
			Size = chestPopSize,
		})
		chestPopTween:Play()

		if lid and lid:IsA("BasePart") and lidCFrame then
			TweenService:Create(lid, lidOpenInfo, {
				CFrame = lidCFrame * CFrame.new(0, 0.9, -0.35) * CFrame.Angles(math.rad(-18), 0, 0),
			}):Play()
		end

		if band and band:IsA("BasePart") and bandCFrame then
			TweenService:Create(band, chestReactInfo, {
				CFrame = bandCFrame * CFrame.new(0, 0.05, 0),
			}):Play()
		end

		if readyIcon and readyIcon:IsA("BasePart") then
			readyIcon.Material = Enum.Material.Neon
			readyIcon.Color = Color3.fromRGB(255, 245, 125)
			readyIcon.Transparency = 0
		end

		chestPopTween.Completed:Wait()

		if chest.Parent then
			TweenService:Create(chest, settleInfo, {
				CFrame = chestCFrame,
				Size = chestSize,
			}):Play()
		end

		if lid and lid.Parent and lidCFrame then
			TweenService:Create(lid, settleInfo, {
				CFrame = lidCFrame,
			}):Play()
		end

		if band and band.Parent and bandCFrame then
			TweenService:Create(band, settleInfo, {
				CFrame = bandCFrame,
			}):Play()
		end

		task.wait(0.24)
		UISections.refreshChestWorldStatus()
		isChestWorldAnimating = false
	end)
end

local function refreshBrainSurgeVisual()
	local progress = tonumber(stats.BrainSurgeProgress) or 0
	local target = math.max(1, tonumber(stats.BrainSurgeTarget) or 10)
	local ready = stats.BrainSurgeReady == true or progress >= target - 1

	if brainSurgeLabel then
		if ready then
			brainSurgeLabel.Text = "Brain Surge READY"
			brainSurgeLabel.TextColor3 = Color3.fromRGB(255, 245, 135)
			brainSurgeLabel.BackgroundTransparency = 0.02
		else
			brainSurgeLabel.Text = "Brain Surge: " .. tostring(math.clamp(progress, 0, target)) .. "/" .. tostring(target)
			brainSurgeLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
			brainSurgeLabel.BackgroundTransparency = 0.18
		end
	end

	if rollButtonBrainSurgeStroke then
		if ready then
			rollButtonBrainSurgeStroke.Color = Color3.fromRGB(255, 245, 120)
			rollButtonBrainSurgeStroke.Thickness = 3
			rollButtonBrainSurgeStroke.Transparency = 0.14
		else
			rollButtonBrainSurgeStroke.Color = Color3.fromRGB(255, 255, 255)
			rollButtonBrainSurgeStroke.Thickness = 2
			rollButtonBrainSurgeStroke.Transparency = 0.78
		end
	end

	if rollButton then
		rollButton.Text = "ROLL"
	end
end

local function updateAutoButtonVisual()
	local autoLevel = tonumber(stats.AutoRollLevel) or 0

	if autoLevel <= 0 then
		autoButton.Text = "AUTO\nLOCKED"
		autoButton.Font = Enum.Font.GothamBold
		autoButton.TextSize = 16
		autoButton.TextStrokeTransparency = 1
		autoButton.BackgroundColor3 = Color3.fromRGB(75, 55, 60)
		autoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		autoButton.Font = Enum.Font.GothamBlack
		autoButton.TextSize = 22
		autoButton.TextStrokeTransparency = 0.75

		if autoRollActive then
			autoButton.Text = "AUTO ON\nLv " .. tostring(autoLevel)
			autoButton.BackgroundColor3 = Color3.fromRGB(85, 220, 150)
			autoButton.TextColor3 = Color3.fromRGB(10, 35, 20)
		else
			autoButton.Text = "AUTO OFF\nLv " .. tostring(autoLevel)
			autoButton.BackgroundColor3 = Color3.fromRGB(120, 45, 55)
			autoButton.TextColor3 = Color3.fromRGB(0, 0, 0)
		end
	end

	if autoUpButton then
		local cost = stats.AutoRollUpgradeCost

		if cost == nil then
			autoUpButton.Text = "Auto\nMAX"
		else
			autoUpButton.Text = "Auto\n" .. formatNumber(cost) .. " Wins"
		end
	end
end

local function refreshStats()
	if luckBar then
		luckBar.Text = "Luck Lv. " .. tostring(stats.LuckLevel)
	end

	if indexButton then
		indexButton.Text = "Concepts\n" .. formatNumber(stats.DiscoveredConcepts) .. "/" .. formatNumber(stats.TotalConcepts)
	end

	if luckButton then
		local cost = stats.LuckUpgradeCost
		luckButton.Text = cost
			and ("Luck\n" .. formatNumber(cost) .. " Wins")
			or "Luck\nMAX"
	end

	refreshBrainSurgeVisual()
	updateAutoButtonVisual()
	updateOverheadStats()
	refreshIndexPanel()
	UISections.refreshQuestPanel()
	UISections.refreshQuestWorldStatus()
	UISections.refreshChestPanel()
	UISections.refreshNextAreaGateStatus()
end

local function applyStats(newStats)
	if type(newStats) ~= "table" then
		return
	end

	for key, value in pairs(newStats) do
		stats[key] = value
	end

	refreshStats()

	if initialStatsReceived then
		checkTutorialAutoProgress()
	end
end

local function hideRouletteFrame()
	if rouletteFrame then
		rouletteFrame.Visible = false
	end
end

local function finishRollState()
	rouletteActive = false
	rollRequestPending = false
	activeRollRequestToken = nil
end

local scheduleNextAutoRoll
local debugAutoRoll

local function requestRoll()
	if rollRequestPending or rouletteActive or rollRevealPending then
		return
	end

	rollRequestPending = true
	rollRevealPending = true
	rollRequestToken += 1
	local capturedToken = rollRequestToken
	activeRollRequestToken = capturedToken

	task.delay(5, function()
		if activeRollRequestToken == capturedToken and rollRequestPending then
			debugAutoRoll("request fail-safe fired token=" .. tostring(capturedToken))
			rollRequestPending = false
			activeRollRequestToken = nil
			rollRevealPending = false
			rouletteActive = false

			if pendingStats then
				applyStats(pendingStats)
				pendingStats = nil
			end

			hideRouletteFrame()
			autoRollBusySince = nil
			autoRollLastBusyState = nil

			if autoRollActive and scheduleNextAutoRoll then
				scheduleNextAutoRoll(AUTO_ROLL_BUSY_RETRY_DELAY)
			end
		end
	end)

	RollRequest:FireServer()
end

function debugAutoRoll(message)
	if AUTO_ROLL_DEBUG then
		print("[AutoRoll] " .. tostring(message))
	end
end

local function getAutoRollBusyState()
	return string.format(
		"request=%s roulette=%s reveal=%s",
		tostring(rollRequestPending),
		tostring(rouletteActive),
		tostring(rollRevealPending)
	)
end

local function resetAutoRollBusyTracking()
	autoRollBusySince = nil
	autoRollLastBusyState = nil
end

local function recoverAutoRollStuck(reason)
	if not autoRollActive then
		return
	end

	debugAutoRoll("stuck recovery reason=" .. tostring(reason))

	rollRequestPending = false
	activeRollRequestToken = nil
	rouletteActive = false
	rollRevealPending = false
	hideRouletteFrame()

	if pendingStats then
		applyStats(pendingStats)
		pendingStats = nil
	end

	resetAutoRollBusyTracking()
	autoRollRecoveryCount += 1

	scheduleNextAutoRoll(AUTO_ROLL_BUSY_RETRY_DELAY)
end

local function trackAutoRollBusyState()
	local busyState = getAutoRollBusyState()
	local nowTime = os.clock()

	if busyState ~= autoRollLastBusyState then
		autoRollLastBusyState = busyState
		autoRollBusySince = nowTime
		return busyState, 0
	end

	if not autoRollBusySince then
		autoRollBusySince = nowTime
	end

	return busyState, nowTime - autoRollBusySince
end

function scheduleNextAutoRoll(delayOverride)
	if not autoRollActive then
		autoRollScheduleToken += 1
		resetAutoRollBusyTracking()
		debugAutoRoll("stopped inactive")
		return
	end

	autoRollScheduleToken += 1
	local scheduleToken = autoRollScheduleToken
	local delayTime = tonumber(delayOverride) or tonumber(stats.AutoRollDelay) or autoRollDelayFallback

	debugAutoRoll("schedule " .. string.format("%.2f", delayTime))

	task.delay(delayTime, function()
		if scheduleToken ~= autoRollScheduleToken then
			return
		end

		if not autoRollActive then
			resetAutoRollBusyTracking()
			debugAutoRoll("stopped inactive")
			return
		end

		local nowTime = os.clock()
		if fullRollPresentationActive or nowTime < autoRollPresentationLockUntil then
			if fullRollPresentationActive and nowTime > autoRollPresentationLockUntil + AUTO_ROLL_STUCK_TIMEOUT then
				fullRollPresentationActive = false
				rouletteActive = false
				hideRouletteFrame()
				debugAutoRoll("presentation lock end")
			else
				local lockDelay = math.max(AUTO_ROLL_BUSY_RETRY_DELAY, autoRollPresentationLockUntil - nowTime)
				debugAutoRoll("schedule blocked by presentation lock")
				scheduleNextAutoRoll(lockDelay)
				return
			end
		end

		if rollRequestPending or rouletteActive or rollRevealPending then
			local busyState, busyDuration = trackAutoRollBusyState()

			debugAutoRoll("busy retry " .. busyState)

			if busyDuration >= AUTO_ROLL_STUCK_TIMEOUT then
				recoverAutoRollStuck(busyState .. " duration=" .. string.format("%.2f", busyDuration))
				return
			end

			scheduleNextAutoRoll(AUTO_ROLL_BUSY_RETRY_DELAY)
			return
		end

		resetAutoRollBusyTracking()
		debugAutoRoll("request next")
		requestRoll()
	end)
end

local function getRollRarity(serverText)
	local _, subtitle = splitPopupText(serverText)
	return getRarityFromText(subtitle) or "COMMON"
end

local function isImportantRollResult(serverText)
	return popupTextHasImportantMarker(serverText)
end

local function shouldUseQuickAutoRollResult(serverText)
	if not autoRollActive then
		return false
	end

	if isImportantRollResult(serverText) then
		return false
	end

	local rarity = getRollRarity(serverText)
	return isBasicRollRarity(rarity)
end

local function getFullRollPathReason(serverText)
	if not autoRollActive then
		return "manual"
	end

	local _, subtitle = splitPopupText(serverText)
	local text = string.upper(tostring(subtitle or ""))
	local rarity = getRollRarity(serverText)

	if text:find("NEW CONCEPT", 1, true) then
		return "new concept"
	end

	if text:find("BRAIN SURGE", 1, true) then
		return "brain surge"
	end

	if text:find("INDEX X", 1, true) then
		return "milestone"
	end

	if not isBasicRollRarity(rarity) then
		return "rare"
	end

	return "interval"
end

local function finalizeRollReveal(serverText)
	debugAutoRoll("finalize reveal")
	finishRollState()
	rollRequestPending = false
	activeRollRequestToken = nil
	rollRevealPending = false
	resetAutoRollBusyTracking()

	showPopup(serverText, "Roll")

	if pendingStats then
		applyStats(pendingStats)
		pendingStats = nil
	end

	scheduleNextAutoRoll()
end

local function startQuickAutoRollResult(serverText)
	debugAutoRoll("quick path")
	rollRequestPending = false
	rouletteActive = false
	hideRouletteFrame()
	clearRollPopups()
	finalizeRollReveal(serverText)
end

local function startRouletteResult(serverText)
	debugAutoRoll("full path reason=" .. getFullRollPathReason(serverText))
	currentRollPresentationId += 1
	local presentationId = currentRollPresentationId
	local presentationStartedAt = os.clock()

	fullRollPresentationActive = true
	autoRollPresentationLockUntil = math.max(autoRollPresentationLockUntil, presentationStartedAt + FULL_ROULETTE_MIN_DISPLAY)
	debugAutoRoll("presentation lock start")

	clearRollPopups()
	safeStop(tickSound)
	safeStop(resultSound)

	rouletteActive = true
	rollRequestPending = false

	local finalTitle, finalSubtitle = splitPopupText(serverText)

	rouletteFrame.Visible = true
	rouletteTitle.Text = "ROLLING"
	rouletteSubtitle.Text = ""

	local steps = 18

	for index = 1, steps do
		if presentationId ~= currentRollPresentationId then
			return
		end

		local candidate = fakeRouletteCandidates[((index - 1) % #fakeRouletteCandidates) + 1]
		local title, subtitle = splitPopupText(candidate)

		rouletteTitle.Text = title
		rouletteSubtitle.Text = subtitle
		rouletteSubtitle.TextColor3 = getRarityColor(subtitle)

		safePlay(tickSound)

		local waitTime = 0.025 + ((index / steps) ^ 2 * 0.09)
		task.wait(waitTime)
	end

	if presentationId ~= currentRollPresentationId then
		return
	end

	rouletteTitle.Text = finalTitle
	rouletteSubtitle.Text = finalSubtitle
	rouletteSubtitle.TextColor3 = getRarityColor(finalSubtitle)

	safeStop(resultSound)
	safePlay(resultSound)

	local remainingMinDisplay = FULL_ROULETTE_MIN_DISPLAY - (os.clock() - presentationStartedAt)
	task.wait(math.max(FULL_ROULETTE_AFTER_RESULT_PAUSE, remainingMinDisplay))

	if presentationId ~= currentRollPresentationId then
		return
	end

	hideRouletteFrame()
	fullRollPresentationActive = false
	autoRollPresentationLockUntil = math.max(autoRollPresentationLockUntil, os.clock() + FULL_ROULETTE_AFTER_RESULT_PAUSE)
	debugAutoRoll("presentation lock end")
	finalizeRollReveal(serverText)
end

local function closePanelsExcept(panelToKeep)
	for _, panel in ipairs({ indexPanel, questPanel, chestPanel, adminPanel }) do
		if panel and panel ~= panelToKeep then
			panel.Visible = false
		end
	end
end

local function setPanelContentZIndex(panel, zIndex)
	for _, descendant in ipairs(panel:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex
		end
	end
end

setQuestPanelContentZIndex = function(panelOverride)
	local targetPanel = panelOverride or questPanel

	if not targetPanel then
		return
	end

	targetPanel.ZIndex = 70

	for _, descendant in ipairs(targetPanel:GetDescendants()) do
		if descendant:IsA("ScrollingFrame") or descendant:IsA("Frame") then
			descendant.ZIndex = 71
		elseif descendant:IsA("TextButton") then
			descendant.ZIndex = string.sub(descendant.Name, 1, 6) == "Claim_" and 73 or 72
		elseif descendant:IsA("TextLabel") or descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			descendant.ZIndex = 72
		end
	end
end

local function toggleIndexPanel()
	indexPanel.Visible = not indexPanel.Visible

	if indexPanel.Visible then
		closePanelsExcept(indexPanel)
		refreshIndexPanel()
	end
end

local function toggleQuestPanel()
	questPanel.Visible = not questPanel.Visible

	if questPanel.Visible then
		closePanelsExcept(questPanel)
		UISections.refreshQuestPanel()
	end
end

local function openQuestPanel()
	if not questPanel or questPanel.Visible then
		return
	end

	questPanel.Visible = true
	closePanelsExcept(questPanel)
	UISections.refreshQuestPanel()
end

local function connectQuestNpcPrompt()
	task.spawn(function()
		local simpleMap = Workspace:WaitForChild("SimpleMap", 15)
		if not simpleMap then
			warn("[QuestPrompt] SimpleMap missing; Quest NPC prompt connection skipped.")
			return
		end

		local questBody = simpleMap:WaitForChild("ProfessorBrain_Body", 15)
		if not questBody then
			warn("[QuestPrompt] ProfessorBrain_Body missing; Quest NPC prompt connection skipped.")
			return
		end

		local prompt = questBody:WaitForChild("QuestOpenPrompt", 15)
		if not prompt or not prompt:IsA("ProximityPrompt") then
			warn("[QuestPrompt] QuestOpenPrompt missing; Quest NPC prompt connection skipped.")
			return
		end

		if questNpcConnectedPrompt == prompt and questNpcPromptConnection then
			return
		end

		if questNpcPromptConnection then
			questNpcPromptConnection:Disconnect()
			questNpcPromptConnection = nil
		end

		questNpcConnectedPrompt = prompt
		questNpcPromptConnection = prompt.Triggered:Connect(openQuestPanel)
		UISections.refreshQuestWorldStatus()
	end)
end

local function toggleChestPanel()
	chestPanel.Visible = not chestPanel.Visible

	if chestPanel.Visible then
		closePanelsExcept(chestPanel)
		UISections.refreshChestPanel()
	end
end

local function createButton(parent, name, text, size, color, textColor)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Text = text
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 22
	button.TextColor3 = textColor or Color3.fromRGB(20, 20, 20)
	button.TextStrokeTransparency = 0.75
	button.BackgroundColor3 = color
	button.AutoButtonColor = false
	button.Parent = parent

	createCorner(button, 14)
	createStroke(button, Color3.fromRGB(255, 255, 255), 2, 0.45)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08), {
			Size = UDim2.new(size.X.Scale, size.X.Offset * 0.94, size.Y.Scale, size.Y.Offset * 0.94),
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = size,
		}):Play()
	end)

	return button
end

local function clearTutorialHighlight()
	if tutorialHighlight and tutorialHighlight.Parent then
		tutorialHighlight:Destroy()
	end

	tutorialHighlight = nil
end

local function getTutorialHighlightColor(target)
	if not target then
		return Color3.fromRGB(255, 235, 95)
	end

	if target.Name == "RollButton" then
		return Color3.fromRGB(80, 120, 255)
	end

	if target.Name == "IndexButton" then
		return Color3.fromRGB(255, 220, 80)
	end

	if target.Name == "LuckButton" then
		return Color3.fromRGB(220, 90, 255)
	end

	if target.Name == "AutoButton" then
		local background = target.BackgroundColor3

		if background.G > background.R then
			return Color3.fromRGB(170, 90, 255)
		end

		return Color3.fromRGB(80, 230, 255)
	end

	return Color3.fromRGB(255, 235, 95)
end

local function updateTutorialHighlight(target)
	clearTutorialHighlight()

	if not target or not target.Parent then
		return
	end

	local existing = target:FindFirstChild("TutorialHighlightStroke")
	if existing and existing:IsA("UIStroke") then
		existing:Destroy()
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "TutorialHighlightStroke"
	stroke.Color = getTutorialHighlightColor(target)
	stroke.Thickness = 4
	stroke.Transparency = 0.05
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target

	tutorialHighlight = stroke
end

local function closeTutorial()
	tutorialActive = false
	clearTutorialHighlight()

	if tutorialFrame then
		tutorialFrame.Visible = false
	end
end

local function finishTutorial()
	tutorialCompletedThisSession = true
	if DEBUG_TUTORIAL then
		print("[Tutorial] Finished")
	end
	closeTutorial()
end

local function skipTutorial()
	tutorialSkippedThisSession = true
	if DEBUG_TUTORIAL then
		print("[Tutorial] Skipped")
	end
	closeTutorial()
end

local function renderTutorialStep()
	if not tutorialFrame then
		return
	end

	local step = tutorialSteps[tutorialStepIndex]
	if not step then
		finishTutorial()
		return
	end

	tutorialTitleLabel.Text = step.Title
	tutorialBodyLabel.Text = step.Body

	if tutorialStepIndex >= #tutorialSteps then
		tutorialNextButton.Text = "FINISH"
	else
		tutorialNextButton.Text = "NEXT"
	end

	tutorialFrame.Visible = true

	task.defer(function()
		if not tutorialActive then
			return
		end

		local target = nil
		if type(step.Target) == "function" then
			target = step.Target()
		end

		updateTutorialHighlight(target)
	end)
end

local function goTutorialNext()
	if not tutorialActive then
		return
	end

	if tutorialStepIndex >= #tutorialSteps then
		finishTutorial()
		return
	end

	tutorialStepIndex += 1
	renderTutorialStep()
end

local function isBeginnerStats()
	return (tonumber(stats.IQ) or 0) <= 5
		and (tonumber(stats.Wins) or 0) <= 0
		and (tonumber(stats.DiscoveredConcepts) or 0) <= 1
end

local function maybeStartTutorial()
	if tutorialCompletedThisSession or tutorialSkippedThisSession or tutorialActive then
		return
	end

	if not initialStatsReceived then
		return
	end

	if not tutorialFrame then
		if DEBUG_TUTORIAL then
			print("[Tutorial] Beginner check delayed: UI not ready")
		end
		return
	end

	local isBeginner = isBeginnerStats()
	if DEBUG_TUTORIAL then
		print(
			"[Tutorial] Beginner check:",
			isBeginner,
			"IQ=", tostring(stats.IQ),
			"Wins=", tostring(stats.Wins),
			"Concepts=", tostring(stats.DiscoveredConcepts)
		)
	end

	if not isBeginner then
		return
	end

	tutorialStepIndex = 1
	tutorialRollObserved = false
	tutorialActive = true

	if DEBUG_TUTORIAL then
		print("[Tutorial] Started")
	end

	renderTutorialStep()
end

checkTutorialAutoProgress = function()
	if not tutorialActive then
		return
	end

	if tutorialStepIndex == 1 and tutorialRollObserved then
		task.delay(0.25, function()
			if tutorialActive and tutorialStepIndex == 1 then
				goTutorialNext()
			end
		end)
	elseif tutorialStepIndex == 2 and (tonumber(stats.IQ) or 0) > 0 then
		task.delay(0.25, function()
			if tutorialActive and tutorialStepIndex == 2 then
				goTutorialNext()
			end
		end)
	end
end

local function createTutorialUI()
	local frame = Instance.new("Frame")
	frame.Name = "TutorialFrame"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 82)
	frame.Size = UDim2.new(0, 420, 0, 178)
	frame.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	frame.BackgroundTransparency = 0.04
	frame.Visible = false
	frame.ZIndex = 90
	frame.Parent = screenGui

	createCorner(frame, 18)
	createStroke(frame, Color3.fromRGB(255, 220, 90), 2, 0.08)

	local title = createText(frame, "TutorialTitle", "", 24, Color3.fromRGB(255, 230, 120))
	title.Position = UDim2.new(0, 18, 0, 14)
	title.Size = UDim2.new(1, -36, 0, 34)
	title.ZIndex = 91

	local body = createText(frame, "TutorialBody", "", 17, Color3.fromRGB(245, 245, 245))
	body.Font = Enum.Font.GothamBold
	body.TextStrokeTransparency = 0.75
	body.Position = UDim2.new(0, 18, 0, 52)
	body.Size = UDim2.new(1, -36, 0, 62)
	body.ZIndex = 91

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "ButtonRow"
	buttonRow.BackgroundTransparency = 1
	buttonRow.Position = UDim2.new(0, 18, 1, -52)
	buttonRow.Size = UDim2.new(1, -36, 0, 40)
	buttonRow.ZIndex = 91
	buttonRow.Parent = frame

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 10)
	rowLayout.Parent = buttonRow

	local skipButton = createButton(buttonRow, "TutorialSkip", "SKIP", UDim2.new(0, 92, 0, 38), Color3.fromRGB(70, 75, 88), Color3.fromRGB(255, 255, 255))
	skipButton.TextSize = 16
	skipButton.ZIndex = 92

	local nextButton = createButton(buttonRow, "TutorialNext", "NEXT", UDim2.new(0, 112, 0, 38), Color3.fromRGB(255, 205, 70), Color3.fromRGB(35, 24, 0))
	nextButton.TextSize = 17
	nextButton.ZIndex = 92

	skipButton.MouseButton1Click:Connect(skipTutorial)
	nextButton.MouseButton1Click:Connect(goTutorialNext)

	tutorialFrame = frame
	tutorialTitleLabel = title
	tutorialBodyLabel = body
	tutorialNextButton = nextButton
	tutorialSkipButton = skipButton

	if DEBUG_TUTORIAL then
		print("[Tutorial] UI created")
	end

	if initialStatsReceived then
		task.defer(maybeStartTutorial)
	end
end

local function createIndexPanel()
	local panel = Instance.new("Frame")
	panel.Name = "IndexPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, 0)
	panel.Size = UDim2.new(0, 330, 0, 430)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.Visible = false
	panel.ZIndex = 70
	panel.Parent = screenGui

	createCorner(panel, 16)
	createStroke(panel, Color3.fromRGB(90, 190, 255), 2, 0.2)

	local close = createButton(panel, "Close", "X", UDim2.new(0, 38, 0, 34), Color3.fromRGB(180, 55, 65), Color3.fromRGB(255, 255, 255))
	close.Position = UDim2.new(1, -46, 0, 8)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local title = createText(panel, "Title", "Concept Index", 24, Color3.fromRGB(120, 220, 255))
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -70, 0, 34)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.new(0, 16, 0, 55)
	content.Size = UDim2.new(1, -32, 1, -70)
	content.ScrollBarThickness = 7
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Parent = panel

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingRight = UDim.new(0, 8)
	contentPadding.PaddingBottom = UDim.new(0, 12)
	contentPadding.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 7)
	layout.Parent = content

	local function configureIndexLabel(label)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		return label
	end

	local total = configureIndexLabel(createText(content, "Total", "", 16, Color3.fromRGB(255, 255, 255)))
	total.Size = UDim2.new(1, -8, 0, 24)

	local kp = configureIndexLabel(createText(content, "KP", "", 15, Color3.fromRGB(255, 230, 120)))
	kp.Size = UDim2.new(1, -8, 0, 22)

	local level = configureIndexLabel(createText(content, "Level", "", 15, Color3.fromRGB(160, 255, 190)))
	level.Size = UDim2.new(1, -8, 0, 22)

	local bonus = configureIndexLabel(createText(content, "Bonus", "", 15, Color3.fromRGB(180, 220, 255)))
	bonus.Size = UDim2.new(1, -8, 0, 22)

	local milestoneBonus = configureIndexLabel(createText(content, "MilestoneBonus", "", 15, Color3.fromRGB(255, 220, 120)))
	milestoneBonus.Size = UDim2.new(1, -8, 0, 22)

	local nextMilestone = configureIndexLabel(createText(content, "NextMilestone", "", 14, Color3.fromRGB(205, 235, 255)))
	nextMilestone.Size = UDim2.new(1, -8, 0, 36)

	local rarity = configureIndexLabel(createText(content, "Rarity", "", 14, Color3.fromRGB(235, 235, 235)))
	rarity.Size = UDim2.new(1, -8, 0, 280)

	local recent = configureIndexLabel(createText(content, "Recent", "", 14, Color3.fromRGB(230, 230, 230)))
	recent.Size = UDim2.new(1, -8, 0, 170)

	setPanelContentZIndex(panel, 71)
	return panel
end

function UISections.createQuestPanel()
	local panel = Instance.new("Frame")
	panel.Name = "QuestPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, 0)
	panel.Size = UDim2.new(0, 330, 0, 430)
	panel.BackgroundColor3 = Color3.fromRGB(16, 22, 24)
	panel.Visible = false
	panel.ZIndex = 70
	panel.Parent = screenGui

	createCorner(panel, 16)
	createStroke(panel, Color3.fromRGB(120, 230, 170), 2, 0.2)

	local close = createButton(panel, "Close", "X", UDim2.new(0, 38, 0, 34), Color3.fromRGB(180, 55, 65), Color3.fromRGB(255, 255, 255))
	close.Position = UDim2.new(1, -46, 0, 8)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local title = createText(panel, "Title", "Quests", 24, Color3.fromRGB(140, 255, 190))
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -70, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local list = Instance.new("ScrollingFrame")
	list.Name = "QuestList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 16, 0, 56)
	list.Size = UDim2.new(1, -32, 1, -72)
	list.ScrollBarThickness = 7
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list

	setQuestPanelContentZIndex(panel)
	return panel
end

function UISections.createChestPanel()
	local panel = Instance.new("Frame")
	panel.Name = "ChestPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, 0)
	panel.Size = UDim2.new(0, 330, 0, 430)
	panel.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
	panel.Visible = false
	panel.ZIndex = 70
	panel.Parent = screenGui

	createCorner(panel, 16)
	createStroke(panel, Color3.fromRGB(245, 190, 80), 2, 0.18)

	local close = createButton(panel, "Close", "X", UDim2.new(0, 38, 0, 34), Color3.fromRGB(180, 55, 65), Color3.fromRGB(255, 255, 255))
	close.Position = UDim2.new(1, -46, 0, 8)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local title = createText(panel, "Title", "Chests", 24, Color3.fromRGB(255, 220, 115))
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -70, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local points = createText(panel, "ChestPoints", "Chest Points: 0 / 25", 17, Color3.fromRGB(255, 245, 210))
	points.Font = Enum.Font.GothamBold
	points.Position = UDim2.new(0, 16, 0, 52)
	points.Size = UDim2.new(1, -32, 0, 26)
	points.TextXAlignment = Enum.TextXAlignment.Left

	local opened = createText(panel, "Opened", "Opened this session: 0", 14, Color3.fromRGB(210, 200, 180))
	opened.Font = Enum.Font.GothamBold
	opened.Position = UDim2.new(0, 16, 0, 80)
	opened.Size = UDim2.new(1, -32, 0, 22)
	opened.TextXAlignment = Enum.TextXAlignment.Left

	local card = Instance.new("Frame")
	card.Name = "BasicChestCard"
	card.Position = UDim2.new(0, 16, 0, 116)
	card.Size = UDim2.new(1, -32, 0, 250)
	card.BackgroundColor3 = Color3.fromRGB(34, 28, 22)
	card.Parent = panel

	createCorner(card, 14)
	createStroke(card, Color3.fromRGB(255, 200, 90), 1, 0.28)

	local cardTitle = createText(card, "CardTitle", "Basic Chest", 22, Color3.fromRGB(255, 218, 95))
	cardTitle.Position = UDim2.new(0, 14, 0, 12)
	cardTitle.Size = UDim2.new(1, -28, 0, 30)
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left

	local rewards = createText(
		card,
		"Rewards",
		"Cost: 25 Chest Points\n\n50%  +500 IQ\n30%  +100 KP\n15%  +1,500 IQ\n5%   +500 KP",
		15,
		Color3.fromRGB(245, 238, 220)
	)
	rewards.Font = Enum.Font.GothamBold
	rewards.Position = UDim2.new(0, 14, 0, 50)
	rewards.Size = UDim2.new(1, -28, 0, 130)
	rewards.TextXAlignment = Enum.TextXAlignment.Left
	rewards.TextYAlignment = Enum.TextYAlignment.Top

	local openButton = createButton(card, "OpenBasic", "NEED 25 CP", UDim2.new(1, -28, 0, 44), Color3.fromRGB(72, 62, 50), Color3.fromRGB(225, 210, 180))
	openButton.Position = UDim2.new(0, 14, 1, -58)
	openButton.MouseButton1Click:Connect(function()
		if openButton.Active == false then
			return
		end

		ChestOpenRequest:FireServer("Basic")
	end)

	setPanelContentZIndex(panel, 71)
	return panel
end

local AdminUI = {}

function AdminUI.sendAction(action, amount)
	AdminTestRequest:FireServer(action, amount)
end

function AdminUI.sendTestCommand(commandName)
	if adminTestResultText then
		adminTestResultText.Text = "Running " .. tostring(commandName) .. "..."
	end

	AdminTestCommandRequest:FireServer(commandName)
end

function AdminUI.createButton(parent, text, action, amount, dangerous)
	local color = dangerous and Color3.fromRGB(150, 45, 55) or Color3.fromRGB(42, 48, 62)
	local button = createButton(parent, action, text, UDim2.new(1, -12, 0, 52), color, Color3.fromRGB(255, 255, 255))
	button.TextSize = 18
	button.TextWrapped = true

	button.MouseButton1Click:Connect(function()
		if dangerous then
			local now = os.clock()

			if not dangerousConfirm[action] or now - dangerousConfirm[action] > 4 then
				dangerousConfirm[action] = now
				showPopup("ADMIN WARNING|Click again to confirm", "Info")
				return
			end

			dangerousConfirm[action] = nil
		end

		AdminUI.sendAction(action, amount)
	end)

	return button
end

function AdminUI.createTestCommandButton(parent, text, commandName)
	local button = createButton(parent, "TestCommand_" .. commandName, text, UDim2.new(1, -12, 0, 46), Color3.fromRGB(34, 72, 92), Color3.fromRGB(225, 245, 255))
	button.TextSize = 16
	button.TextWrapped = true

	button.MouseButton1Click:Connect(function()
		AdminUI.sendTestCommand(commandName)
	end)

	return button
end

function AdminUI.createSection(parent, titleText)
	local title = createText(parent, "Section_" .. titleText, titleText, 18, Color3.fromRGB(255, 220, 120))
	title.Size = UDim2.new(1, -12, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextStrokeTransparency = 0.65
	return title
end

function AdminUI.createPanel()
	if player.Name ~= LOCAL_ADMIN_USERNAME then
		return nil
	end

	local panel = Instance.new("Frame")
	panel.Name = "AdminTestPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, 0)
	panel.Size = UDim2.new(0, 420, 0, 560)
	panel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	panel.Visible = false
	panel.ZIndex = 70
	panel.Parent = screenGui

	createCorner(panel, 16)
	createStroke(panel, Color3.fromRGB(255, 210, 90), 2, 0.15)

	local title = createText(panel, "Title", "Admin Test Tools", 23, Color3.fromRGB(255, 220, 120))
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -32, 0, 34)

	local hint = createText(panel, "Hint", "F2 toggle · server validates UserId", 13, Color3.fromRGB(190, 200, 210))
	hint.Font = Enum.Font.GothamBold
	hint.Position = UDim2.new(0, 16, 0, 42)
	hint.Size = UDim2.new(1, -32, 0, 22)
	hint.TextStrokeTransparency = 1

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "AdminScroll"
	scroll.Position = UDim2.new(0, 14, 0, 72)
	scroll.Size = UDim2.new(1, -28, 1, -88)
	scroll.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	scroll.BackgroundTransparency = 0.15
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel

	createCorner(scroll, 12)
	createStroke(scroll, Color3.fromRGB(80, 86, 105), 1, 0.45)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	AdminUI.createSection(scroll, "IQ TEST")
	AdminUI.createButton(scroll, "+1K IQ", "AddIQ", 1000, false)
	AdminUI.createButton(scroll, "+100K IQ", "AddIQ", 100000, false)
	AdminUI.createButton(scroll, "+10M IQ", "AddIQ", 10000000, false)
	AdminUI.createButton(scroll, "IQ 0 [!]", "SetIQ", 0, true)

	AdminUI.createSection(scroll, "WINS TEST")
	AdminUI.createButton(scroll, "+10 Wins", "AddWins", 10, false)
	AdminUI.createButton(scroll, "+100 Wins", "AddWins", 100, false)
	AdminUI.createButton(scroll, "Wins 0 [!]", "SetWins", 0, true)

	AdminUI.createSection(scroll, "GROWTH / UPGRADE TEST")
	AdminUI.createButton(scroll, "+100 KP", "AddKP", 100, false)
	AdminUI.createButton(scroll, "KP 0 [!]", "SetKP", 0, true)
	AdminUI.createButton(scroll, "Luck +1", "AddLuck", 1, false)
	AdminUI.createButton(scroll, "Luck 0 [!]", "SetLuck", 0, true)
	AdminUI.createButton(scroll, "AutoRoll +1", "AddAutoRoll", 1, false)
	AdminUI.createButton(scroll, "AutoRoll 0 [!]", "SetAutoRoll", 0, true)
	AdminUI.createButton(scroll, "Index Level +1", "AddIndexLevel", 1, false)
	AdminUI.createButton(scroll, "Index Level 1 [!]", "SetIndexLevel", 1, true)

	AdminUI.createSection(scroll, "INDEX TEST")
	AdminUI.createButton(scroll, "Discover 10 Concepts", "DiscoverRandomConcepts", 10, false)
	AdminUI.createButton(scroll, "Clear Recent Concepts [!]", "ClearRecentConcepts", 0, true)

	AdminUI.createSection(scroll, "READ-ONLY TESTS")
	AdminUI.createTestCommandButton(scroll, "Test Help", "help")
	AdminUI.createTestCommandButton(scroll, "Chest State Test", "chest_state")
	AdminUI.createTestCommandButton(scroll, "Quest State Test", "quest_state")
	AdminUI.createTestCommandButton(scroll, "Persistence Test", "persistence")
	AdminUI.createTestCommandButton(scroll, "Run All Tests", "all")

	adminTestResultText = createText(scroll, "AdminTestResultText", "Read-only test results will appear here.", 13, Color3.fromRGB(220, 235, 245))
	adminTestResultText.Size = UDim2.new(1, -12, 0, 220)
	adminTestResultText.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
	adminTestResultText.BackgroundTransparency = 0.05
	adminTestResultText.Font = Enum.Font.Code
	adminTestResultText.TextXAlignment = Enum.TextXAlignment.Left
	adminTestResultText.TextYAlignment = Enum.TextYAlignment.Top
	adminTestResultText.TextStrokeTransparency = 1
	createCorner(adminTestResultText, 8)
	createStroke(adminTestResultText, Color3.fromRGB(80, 130, 160), 1, 0.35)

	AdminUI.createSection(scroll, "SAVE / DIAGNOSTIC")
	AdminUI.createButton(scroll, "Force Save", "ForceSave", 0, false)
	AdminUI.createButton(scroll, "Print Snapshot", "PrintDataSnapshot", 0, false)

	AdminUI.createSection(scroll, "DANGER")
	AdminUI.createButton(scroll, "RESET DATA [!!]", "ResetTestData", 0, true)

	setPanelContentZIndex(panel, 71)
	return panel
end

local function buildUI()
	clearOldUi()

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BrainRNG_UI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	luckBar = createText(screenGui, "LuckBar", "Luck Lv. 0", 18, Color3.fromRGB(160, 255, 190))
	luckBar.AnchorPoint = Vector2.new(1, 0)
	luckBar.Position = UDim2.new(1, -14, 0, 16)
	luckBar.Size = UDim2.new(0, 160, 0, 34)
	luckBar.BackgroundColor3 = Color3.fromRGB(16, 22, 22)
	luckBar.BackgroundTransparency = 0.15
	createCorner(luckBar, 10)
	createStroke(luckBar, Color3.fromRGB(80, 220, 150), 2, 0.25)

	for _, staleName in ipairs({ "UtilityMenuFrame", "IndexButton", "QuestButton", "ChestButton", "LuckButton", "AutoUpButton" }) do
		local stale = screenGui:FindFirstChild(staleName)
		if stale then
			stale:Destroy()
		end
	end

	local utilityMenuFrame = Instance.new("Frame")
	utilityMenuFrame.Name = "UtilityMenuFrame"
	utilityMenuFrame.AnchorPoint = Vector2.new(1, 0.5)
	utilityMenuFrame.Position = UDim2.new(1, -20, 0.5, 0)
	utilityMenuFrame.Size = UDim2.new(0, 140, 0, 260)
	utilityMenuFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	utilityMenuFrame.BackgroundTransparency = 0.25
	utilityMenuFrame.ClipsDescendants = false
	utilityMenuFrame.ZIndex = 30
	utilityMenuFrame.Visible = true
	utilityMenuFrame.Parent = screenGui

	indexButton = createButton(utilityMenuFrame, "IndexButton", "Concepts\n0/0", UDim2.new(1, 0, 0, 42), Color3.fromRGB(40, 70, 105), Color3.fromRGB(255, 255, 255))
	indexButton.LayoutOrder = 1
	indexButton.AnchorPoint = Vector2.new(0, 0)
	indexButton.Position = UDim2.new(0, 0, 0, 0)
	indexButton.Visible = true
	indexButton.TextSize = 13
	indexButton.ZIndex = 31
	indexButton.MouseButton1Click:Connect(toggleIndexPanel)

	questButton = createButton(utilityMenuFrame, "QuestButton", "Quests\n0/3", UDim2.new(1, 0, 0, 42), Color3.fromRGB(45, 75, 62), Color3.fromRGB(235, 255, 240))
	questButton.LayoutOrder = 2
	questButton.AnchorPoint = Vector2.new(0, 0)
	questButton.Position = UDim2.new(0, 0, 0, 48)
	questButton.Visible = true
	questButton.ZIndex = 31
	questButton.TextSize = 13
	questButton.MouseButton1Click:Connect(toggleQuestPanel)

	questReadyBadge = createText(questButton, "QuestReadyBadge", "!", 18, Color3.fromRGB(255, 255, 255))
	questReadyBadge.AnchorPoint = Vector2.new(1, 0)
	questReadyBadge.Position = UDim2.new(1, 8, 0, -8)
	questReadyBadge.Size = UDim2.new(0, 28, 0, 28)
	questReadyBadge.BackgroundColor3 = Color3.fromRGB(225, 45, 55)
	questReadyBadge.BackgroundTransparency = 0
	questReadyBadge.TextStrokeTransparency = 0.35
	questReadyBadge.Visible = false
	questReadyBadge.ZIndex = 32
	createCorner(questReadyBadge, 999)
	createStroke(questReadyBadge, Color3.fromRGB(255, 235, 110), 2, 0.05)

	chestButton = createButton(utilityMenuFrame, "ChestButton", "Rewards\n0 CP", UDim2.new(1, 0, 0, 42), Color3.fromRGB(70, 55, 42), Color3.fromRGB(255, 242, 190))
	chestButton.LayoutOrder = 3
	chestButton.AnchorPoint = Vector2.new(0, 0)
	chestButton.Position = UDim2.new(0, 0, 0, 96)
	chestButton.Visible = true
	chestButton.ZIndex = 31
	chestButton.TextSize = 13
	chestButton.MouseButton1Click:Connect(toggleChestPanel)

	chestReadyBadge = createText(chestButton, "ChestReadyBadge", "!", 18, Color3.fromRGB(255, 255, 255))
	chestReadyBadge.AnchorPoint = Vector2.new(1, 0)
	chestReadyBadge.Position = UDim2.new(1, 8, 0, -8)
	chestReadyBadge.Size = UDim2.new(0, 28, 0, 28)
	chestReadyBadge.BackgroundColor3 = Color3.fromRGB(245, 165, 35)
	chestReadyBadge.BackgroundTransparency = 0
	chestReadyBadge.TextStrokeTransparency = 0.35
	chestReadyBadge.Visible = false
	chestReadyBadge.ZIndex = 32
	createCorner(chestReadyBadge, 999)
	createStroke(chestReadyBadge, Color3.fromRGB(255, 245, 160), 2, 0.05)

	luckButton = createButton(utilityMenuFrame, "LuckButton", "Luck\n0 Wins", UDim2.new(1, 0, 0, 42), Color3.fromRGB(95, 230, 165), Color3.fromRGB(10, 35, 20))
	luckButton.LayoutOrder = 4
	luckButton.AnchorPoint = Vector2.new(0, 0)
	luckButton.Position = UDim2.new(0, 0, 0, 144)
	luckButton.Visible = true
	luckButton.TextSize = 13
	luckButton.ZIndex = 31
	luckButton.MouseButton1Click:Connect(function()
		UpgradeRequest:FireServer()
	end)

	autoUpButton = createButton(utilityMenuFrame, "AutoUpButton", "Auto\n10 Wins", UDim2.new(1, 0, 0, 42), Color3.fromRGB(80, 170, 220), Color3.fromRGB(15, 30, 40))
	autoUpButton.LayoutOrder = 5
	autoUpButton.AnchorPoint = Vector2.new(0, 0)
	autoUpButton.Position = UDim2.new(0, 0, 0, 192)
	autoUpButton.Visible = true
	autoUpButton.TextSize = 13
	autoUpButton.ZIndex = 31
	autoUpButton.MouseButton1Click:Connect(function()
		AutoRollUpgradeRequest:FireServer()
	end)

	local buttonFrame = Instance.new("Frame")
	buttonFrame.Name = "ButtonFrame"
	buttonFrame.AnchorPoint = Vector2.new(0.5, 1)
	buttonFrame.Position = UDim2.new(0.5, 0, 1, -26)
	buttonFrame.Size = UDim2.new(0, 330, 0, 96)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = screenGui

	rollButton = createButton(buttonFrame, "RollButton", "ROLL", UDim2.new(0, 165, 0, 76), Color3.fromRGB(255, 190, 45), Color3.fromRGB(35, 22, 0))
	rollButton.AnchorPoint = Vector2.new(0, 0)
	rollButton.Position = UDim2.new(0, 0, 0, 10)
	rollButton.TextSize = 28
	rollButtonBrainSurgeStroke = createStroke(rollButton, Color3.fromRGB(255, 255, 255), 2, 0.78)
	rollButtonBrainSurgeStroke.Name = "BrainSurgeGlow"

	brainSurgeLabel = createText(buttonFrame, "BrainSurgeLabel", "Brain Surge: 0/10", 12, Color3.fromRGB(210, 235, 255))
	brainSurgeLabel.AnchorPoint = Vector2.new(0, 0)
	brainSurgeLabel.Position = UDim2.new(0, 0, 0, -14)
	brainSurgeLabel.Size = UDim2.new(0, 165, 0, 22)
	brainSurgeLabel.BackgroundColor3 = Color3.fromRGB(18, 24, 32)
	brainSurgeLabel.BackgroundTransparency = 0.18
	brainSurgeLabel.TextStrokeTransparency = 0.75
	brainSurgeLabel.ZIndex = 29
	createCorner(brainSurgeLabel, 8)
	createStroke(brainSurgeLabel, Color3.fromRGB(120, 210, 255), 1, 0.35)

	autoButton = createButton(buttonFrame, "AutoButton", "AUTO\nLOCKED", UDim2.new(0, 130, 0, 62), Color3.fromRGB(75, 55, 60), Color3.fromRGB(255, 255, 255))
	autoButton.AnchorPoint = Vector2.new(0, 0)
	autoButton.Position = UDim2.new(0, 185, 0, 17)

	rollButton.Parent = buttonFrame
	brainSurgeLabel.Parent = buttonFrame
	autoButton.Parent = buttonFrame
	indexButton.Parent = utilityMenuFrame
	questButton.Parent = utilityMenuFrame
	chestButton.Parent = utilityMenuFrame
	luckButton.Parent = utilityMenuFrame
	autoUpButton.Parent = utilityMenuFrame

	rollButton.LayoutOrder = 1
	autoButton.LayoutOrder = 2
	rollButton.Visible = true
	autoButton.Visible = true

	rollButton.MouseButton1Click:Connect(requestRoll)

	autoButton.MouseButton1Click:Connect(function()
		local level = tonumber(stats.AutoRollLevel) or 0

		if level <= 0 then
			AutoRollUpgradeRequest:FireServer()
			return
		end

		autoRollActive = not autoRollActive
		updateAutoButtonVisual()

		if autoRollActive then
			scheduleNextAutoRoll()
		end
	end)

	rouletteFrame = Instance.new("Frame")
	rouletteFrame.Name = "RouletteFrame"
	rouletteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rouletteFrame.Position = UDim2.new(0.5, 0, 0.42, 0)
	rouletteFrame.Size = UDim2.new(0, 460, 0, 135)
	rouletteFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
	rouletteFrame.Visible = false
	rouletteFrame.Parent = screenGui

	createCorner(rouletteFrame, 18)
	createStroke(rouletteFrame, Color3.fromRGB(255, 220, 90), 3, 0.1)

	rouletteTitle = createText(rouletteFrame, "Title", "", 28, Color3.fromRGB(255, 255, 255))
	rouletteTitle.Position = UDim2.new(0, 18, 0, 20)
	rouletteTitle.Size = UDim2.new(1, -36, 0, 45)

	rouletteSubtitle = createText(rouletteFrame, "Subtitle", "", 24, Color3.fromRGB(255, 230, 120))
	rouletteSubtitle.Position = UDim2.new(0, 18, 0, 72)
	rouletteSubtitle.Size = UDim2.new(1, -36, 0, 38)

	popupContainer = Instance.new("Frame")
	popupContainer.Name = "PopupContainer"
	popupContainer.BackgroundTransparency = 1
	popupContainer.Size = UDim2.new(1, 0, 1, 0)
	popupContainer.Parent = screenGui

	questToastContainer = Instance.new("Frame")
	questToastContainer.Name = "QuestToastContainer"
	questToastContainer.BackgroundTransparency = 1
	questToastContainer.Size = UDim2.new(1, 0, 1, 0)
	questToastContainer.Parent = screenGui

	indexPanel = createIndexPanel()
	questPanel = UISections.createQuestPanel()
	chestPanel = UISections.createChestPanel()
	adminPanel = AdminUI.createPanel()
	createTutorialUI()
	connectQuestNpcPrompt()
	UISections.connectNextAreaPrompt()
	UISections.connectArea2ReturnPrompt()

	local function forceUtilityButtonLayout(button, layoutOrder, yOffset)
		button.Parent = utilityMenuFrame
		button.AnchorPoint = Vector2.new(0, 0)
		button.Position = UDim2.new(0, 0, 0, yOffset)
		button.Size = UDim2.new(1, 0, 0, 42)
		button.LayoutOrder = layoutOrder
		button.Visible = true
		button.ZIndex = 31
	end

	forceUtilityButtonLayout(indexButton, 1, 0)
	forceUtilityButtonLayout(questButton, 2, 48)
	forceUtilityButtonLayout(chestButton, 3, 96)
	forceUtilityButtonLayout(luckButton, 4, 144)
	forceUtilityButtonLayout(autoUpButton, 5, 192)

	chestReadyBadge.Parent = chestButton
	chestReadyBadge.ZIndex = 32

	if DEBUG_UI then
		print("[UI CHECK] ButtonFrame children:")
		for _, child in ipairs(buttonFrame:GetChildren()) do
			print(child.Name)
		end

		print("[UI CHECK] UtilityMenuFrame children:")
		for _, child in ipairs(utilityMenuFrame:GetChildren()) do
			print(child.Name, child.Position, child.Size, child.ZIndex)
		end

		print("[UI CHECK] screenGui direct ChestButton:", screenGui:FindFirstChild("ChestButton"))
	end

	refreshStats()

	task.delay(0.25, function()
		maybeStartTutorial()
	end)
end

UpdateStats.OnClientEvent:Connect(function(newStats)
	if type(newStats) ~= "table" then
		return
	end

	if rollRevealPending or rouletteActive then
		pendingStats = newStats
		return
	end

	applyStats(newStats)

	if not initialStatsReceived then
		initialStatsReceived = true
		if DEBUG_TUTORIAL then
			print("[Tutorial] Stats received")
		end
	end

	maybeStartTutorial()
end)

PopupEvent.OnClientEvent:Connect(function(text, popupType)
	popupType = tostring(popupType or "Info")

	if popupType == "Roll" then
		debugAutoRoll("roll result received")
		rollRequestPending = false
		activeRollRequestToken = nil
		tutorialRollObserved = true
		checkTutorialAutoProgress()

		local rollText = tostring(text or "")
		if shouldUseQuickAutoRollResult(rollText) then
			startQuickAutoRollResult(rollText)
		else
			startRouletteResult(rollText)
		end

		return
	end

	if popupType == "RollCooldown" then
		local _, subtitle = splitPopupText(tostring(text or ""))
		local cooldownDelay = tonumber(subtitle) or tonumber(stats.AutoRollDelay) or autoRollDelayFallback

		debugAutoRoll("server cooldown " .. string.format("%.2f", cooldownDelay))

		rollRequestPending = false
		activeRollRequestToken = nil
		rollRevealPending = false
		rouletteActive = false
		hideRouletteFrame()
		resetAutoRollBusyTracking()

		if pendingStats then
			applyStats(pendingStats)
			pendingStats = nil
		end

		if autoRollActive then
			scheduleNextAutoRoll(math.max(cooldownDelay, AUTO_ROLL_BUSY_RETRY_DELAY))
		end

		return
	end

	if popupType == "Quest" or popupType == "Chest" then
		if popupType == "Chest" then
			local title, body, reward = splitQuestPopupText(tostring(text or ""))
			if string.find(title, "CHEST OPENED", 1, true) then
				UISections.playWorldChestOpenAnimation()
				showChestOpenAnimation(title, reward ~= "" and reward or body)
			end
		end

		showQuestToast(tostring(text or ""))
		return
	end

	showPopup(tostring(text or ""), popupType)
end)

AdminTestCommandResult.OnClientEvent:Connect(function(commandName, lines)
	local outputLines = {}

	if type(lines) == "table" then
		for _, line in ipairs(lines) do
			table.insert(outputLines, tostring(line))
		end
	else
		table.insert(outputLines, tostring(lines or "No result lines received."))
	end

	local text = "Command: " .. tostring(commandName or "") .. "\n" .. table.concat(outputLines, "\n")

	if adminTestResultText then
		adminTestResultText.Text = text
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		requestRoll()
	elseif input.KeyCode == Enum.KeyCode.F2 then
		if adminPanel then
			adminPanel.Visible = not adminPanel.Visible
			if adminPanel.Visible then
				closePanelsExcept(adminPanel)
			end
		end

		if tutorialActive then
			task.defer(renderTutorialStep)
		end
	end
end)

player.CharacterAdded:Connect(function(character)
	task.defer(function()
		createOverheadStats(character)
	end)
end)

if player.Character then
	task.defer(function()
		createOverheadStats(player.Character)
	end)
end

buildUI()
