local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

if ServerScriptService:GetAttribute("StudySimulatorRunning") then
	warn("[StudySimulator] Duplicate service blocked")
	return
end
ServerScriptService:SetAttribute("StudySimulatorRunning", true)

local Config = require(ReplicatedStorage:WaitForChild("StudySimulatorConfig"))
local StudyData = require(ServerScriptService:WaitForChild("StudySimulatorData"))

ReplicatedStorage:SetAttribute("BrainRNG_GameMode", "StudySimulator")

local remotes = ReplicatedStorage:FindFirstChild("StudySimulatorRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "StudySimulatorRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(name)
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		remote:Destroy()
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local StateUpdated = getRemote("StateUpdated")
local DistractionSpawned = getRemote("DistractionSpawned")
local StudyClickRequest = getRemote("StudyClickRequest")
local UpgradeApplyRequest = getRemote("UpgradeApplyRequest")
local RespecRequest = getRemote("RespecRequest")
local PresentationEvent = getRemote("PresentationEvent")
local OpenPartnerPanel = getRemote("OpenPartnerPanel")

local playerStates = {}
local world = {}
local AUTOSAVE_INTERVAL = 45
local WORLD_ORIGIN = Vector3.new(0, 300, -3200)

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createSurfaceText(part, face, text, textColor, backgroundColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 35
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = backgroundColor or Color3.fromRGB(247, 242, 224)
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(34, 48, 65)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

local function createPrompt(parent, name, actionText, objectText, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function createDesk(parent, prefix, position, color)
	local model = Instance.new("Model")
	model.Name = prefix
	model.Parent = parent

	createPart(model, "Top", Vector3.new(9, 0.8, 5), CFrame.new(position), color, Enum.Material.WoodPlanks)
	for _, offset in ipairs({ Vector3.new(-3.6, -2.2, -1.7), Vector3.new(3.6, -2.2, -1.7), Vector3.new(-3.6, -2.2, 1.7), Vector3.new(3.6, -2.2, 1.7) }) do
		createPart(model, "Leg", Vector3.new(0.55, 4.4, 0.55), CFrame.new(position + offset), Color3.fromRGB(84, 61, 45), Enum.Material.Wood)
	end
	createPart(model, "Book", Vector3.new(3.2, 0.35, 2.2), CFrame.new(position + Vector3.new(0, 0.65, 0)), Color3.fromRGB(83, 130, 170), Enum.Material.SmoothPlastic, false)
	return model
end

local function createPartnerDummy(parent, position, shirtColor)
	local model = Instance.new("Model")
	model.Name = "StudyPartner"
	model.Parent = parent

	local root = createPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(position), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
	root.Transparency = 1
	local torso = createPart(model, "Torso", Vector3.new(2.4, 2.6, 1.2), CFrame.new(position + Vector3.new(0, 1.8, 0)), shirtColor, Enum.Material.SmoothPlastic, false)
	local head = createPart(model, "Head", Vector3.new(2, 2, 2), CFrame.new(position + Vector3.new(0, 4.0, 0)), Color3.fromRGB(244, 206, 168), Enum.Material.SmoothPlastic, false)
	createPart(model, "Hair", Vector3.new(2.1, 0.55, 2.05), CFrame.new(position + Vector3.new(0, 4.85, -0.05)), Color3.fromRGB(72, 49, 39), Enum.Material.SmoothPlastic, false)
	createPart(model, "LeftArm", Vector3.new(0.75, 2.5, 0.75), CFrame.new(position + Vector3.new(-1.55, 1.7, 0)), Color3.fromRGB(244, 206, 168), Enum.Material.SmoothPlastic, false)
	createPart(model, "RightArm", Vector3.new(0.75, 2.5, 0.75), CFrame.new(position + Vector3.new(1.55, 1.7, 0)), Color3.fromRGB(244, 206, 168), Enum.Material.SmoothPlastic, false)
	createPart(model, "LeftLeg", Vector3.new(0.9, 2.7, 0.9), CFrame.new(position + Vector3.new(-0.65, -0.5, 0)), Color3.fromRGB(52, 67, 85), Enum.Material.SmoothPlastic, false)
	createPart(model, "RightLeg", Vector3.new(0.9, 2.7, 0.9), CFrame.new(position + Vector3.new(0.65, -0.5, 0)), Color3.fromRGB(52, 67, 85), Enum.Material.SmoothPlastic, false)

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	return model, torso, head
end

local function buildRoom(parent, roomId, center, title, accentColor)
	local room = Instance.new("Model")
	room.Name = roomId
	room.Parent = parent

	local cream = Color3.fromRGB(244, 238, 218)
	local warmWhite = Color3.fromRGB(250, 248, 239)
	local wood = Color3.fromRGB(133, 91, 59)
	local dark = Color3.fromRGB(43, 57, 73)

	createPart(room, "Floor", Vector3.new(110, 2, 86), CFrame.new(center), Color3.fromRGB(187, 154, 112), Enum.Material.WoodPlanks)
	createPart(room, "BackWall", Vector3.new(110, 28, 2), CFrame.new(center + Vector3.new(0, 15, -42)), cream, Enum.Material.Plaster)
	createPart(room, "FrontWallLeft", Vector3.new(43, 28, 2), CFrame.new(center + Vector3.new(-33.5, 15, 42)), cream, Enum.Material.Plaster)
	createPart(room, "FrontWallRight", Vector3.new(43, 28, 2), CFrame.new(center + Vector3.new(33.5, 15, 42)), cream, Enum.Material.Plaster)
	createPart(room, "LeftWall", Vector3.new(2, 28, 86), CFrame.new(center + Vector3.new(-55, 15, 0)), warmWhite, Enum.Material.Plaster)
	createPart(room, "RightWall", Vector3.new(2, 28, 86), CFrame.new(center + Vector3.new(55, 15, 0)), warmWhite, Enum.Material.Plaster)
	createPart(room, "Ceiling", Vector3.new(110, 1, 86), CFrame.new(center + Vector3.new(0, 29, 0)), Color3.fromRGB(234, 235, 230), Enum.Material.Plaster)

	local board = createPart(room, "SchoolBoard", Vector3.new(42, 13, 1), CFrame.new(center + Vector3.new(0, 16, -40.7)), Color3.fromRGB(47, 91, 72), Enum.Material.SmoothPlastic)
	createSurfaceText(board, Enum.NormalId.Front, title .. "\nFOCUS · LEARN · GROW", Color3.fromRGB(247, 242, 224), Color3.fromRGB(47, 91, 72))

	for x = -42, 42, 28 do
		local windowFrame = createPart(room, "WindowFrame", Vector3.new(18, 12, 0.6), CFrame.new(center + Vector3.new(x, 17, -41)), dark, Enum.Material.Wood)
		local window = createPart(room, "Window", Vector3.new(16.5, 10.5, 0.35), windowFrame.CFrame + Vector3.new(0, 0, 0.55), Color3.fromRGB(168, 215, 232), Enum.Material.Glass, false)
		window.Transparency = 0.25
	end

	createPart(room, "ReadingCarpet", Vector3.new(28, 0.25, 20), CFrame.new(center + Vector3.new(-34, 1.2, 19)), accentColor, Enum.Material.Fabric, false)
	createPart(room, "Bookshelf", Vector3.new(18, 13, 3), CFrame.new(center + Vector3.new(42, 7.5, -25)), wood, Enum.Material.WoodPlanks)
	for shelfIndex = 0, 3 do
		createPart(room, "Shelf", Vector3.new(17, 0.35, 3.3), CFrame.new(center + Vector3.new(42, 2.5 + shelfIndex * 3.2, -25)), Color3.fromRGB(92, 64, 44), Enum.Material.Wood)
	end
	for index = 1, 14 do
		local row = math.floor((index - 1) / 7)
		local column = (index - 1) % 7
		local colors = {
			Color3.fromRGB(202, 90, 82), Color3.fromRGB(86, 132, 174), Color3.fromRGB(214, 166, 74), Color3.fromRGB(89, 151, 112),
		}
		createPart(room, "BookProp", Vector3.new(1.4, 2.2, 1), CFrame.new(center + Vector3.new(36.5 + column * 1.65, 4.0 + row * 3.2, -23.1)), colors[((index - 1) % #colors) + 1], Enum.Material.SmoothPlastic, false)
	end

	local playerDesk = createDesk(room, "PlayerStudyDesk", center + Vector3.new(-12, 5, 3), Color3.fromRGB(169, 121, 79))
	local interact = createPart(playerDesk, "Interact", Vector3.new(9, 5, 5), CFrame.new(center + Vector3.new(-12, 7.3, 3)), accentColor, Enum.Material.SmoothPlastic, false)
	interact.Transparency = 1
	interact.CanQuery = true
	local studyPrompt = createPrompt(interact, "StudyPrompt", "Start / Stop Study", "Your Study Desk", 14)

	local partnerDesk = createDesk(room, "PartnerStudyDesk", center + Vector3.new(14, 5, 3), Color3.fromRGB(149, 109, 75))
	local partnerInteract = createPart(partnerDesk, "PartnerInteract", Vector3.new(9, 6, 5), CFrame.new(center + Vector3.new(14, 8, 3)), accentColor, Enum.Material.SmoothPlastic, false)
	partnerInteract.Transparency = 1
	partnerInteract.CanQuery = true
	local partnerPrompt = createPrompt(partnerInteract, "PartnerPrompt", "Partner Upgrades", "Study Partner", 14)
	local dummy = createPartnerDummy(room, center + Vector3.new(14, 4.4, -1), accentColor)

	local spawn = createPart(room, "PlayerSpawn", Vector3.new(8, 1, 8), CFrame.new(center + Vector3.new(0, 2, 30)), accentColor, Enum.Material.SmoothPlastic, false)
	spawn.Transparency = 1

	local gate = createPart(room, "GraduationGate", Vector3.new(20, 18, 2), CFrame.new(center + Vector3.new(0, 10, 41)), Color3.fromRGB(67, 82, 96), Enum.Material.Wood)
	local gatePanel = createPart(room, "GatePanel", Vector3.new(17, 13, 0.8), CFrame.new(center + Vector3.new(0, 10, 39.7)), accentColor, Enum.Material.SmoothPlastic)
	local gateLabel = createSurfaceText(gatePanel, Enum.NormalId.Front, "NEXT SCHOOL\nREACH THE IQ GOAL", Color3.fromRGB(248, 245, 232), accentColor)
	local gatePrompt = createPrompt(gatePanel, "GraduationPrompt", "Enter Next School", "Graduation Gate", 14)

	return {
		Model = room,
		Center = center,
		Spawn = spawn,
		StudyPart = interact,
		StudyPrompt = studyPrompt,
		PartnerPrompt = partnerPrompt,
		PartnerDummy = dummy,
		GatePart = gate,
		GatePanel = gatePanel,
		GateLabel = gateLabel,
		GatePrompt = gatePrompt,
	}
end

local function buildWorld()
	local existing = Workspace:FindFirstChild("StudySimulatorWorld")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "StudySimulatorWorld"
	root.Parent = Workspace

	local skyFloor = createPart(root, "WorldGround", Vector3.new(420, 12, 180), CFrame.new(WORLD_ORIGIN + Vector3.new(75, -7, 0)), Color3.fromRGB(102, 139, 89), Enum.Material.Grass)
	createPart(root, "EarthMass", Vector3.new(420, 70, 180), CFrame.new(skyFloor.Position - Vector3.new(0, 41, 0)), Color3.fromRGB(98, 69, 49), Enum.Material.Ground)

	local kindergarten = buildRoom(root, "KindergartenRoom", WORLD_ORIGIN, "BRAIN RNG SCHOOL", Color3.fromRGB(78, 132, 105))
	local elementary = buildRoom(root, "ElementaryRoom", WORLD_ORIGIN + Vector3.new(170, 0, 0), "ELEMENTARY ACADEMY", Color3.fromRGB(77, 112, 162))

	createPart(root, "Path", Vector3.new(60, 1, 18), CFrame.new(WORLD_ORIGIN + Vector3.new(85, 1, 0)), Color3.fromRGB(199, 190, 164), Enum.Material.Cobblestone)
	for x = -160, 310, 24 do
		local trunk = createPart(root, "TreeTrunk", Vector3.new(3, 12, 3), CFrame.new(WORLD_ORIGIN + Vector3.new(x, 6, -70)), Color3.fromRGB(101, 70, 45), Enum.Material.Wood)
		createPart(root, "TreeCrown", Vector3.new(13, 13, 13), trunk.CFrame + Vector3.new(0, 10, 0), Color3.fromRGB(88, 143, 83), Enum.Material.Grass, false).Shape = Enum.PartType.Ball
	end

	world.Root = root
	world.Rooms = {
		[1] = kindergarten,
		[2] = elementary,
	}

	return root
end

buildWorld()

local function getState(player)
	local state = playerStates[player.UserId]
	if not state then
		state = {
			DirectActive = false,
			ClickProgress = 0,
			PendingDistraction = false,
			DistractionNonce = 0,
			NextDistractionAt = 0,
			LastClickAt = 0,
			PartnerWorkSeconds = 0,
			LastTickAt = os.clock(),
			Ready = false,
		}
		playerStates[player.UserId] = state
	end
	return state
end

local function totalPartnerPoints(data)
	return math.max(0, math.floor(tonumber(data.PartnerPowerPoints) or 0))
		+ math.max(0, math.floor(tonumber(data.PartnerSpeedPoints) or 0))
		+ math.max(0, math.floor(tonumber(data.PartnerUnspentPoints) or 0))
end

local function currentRoom(player)
	local data = StudyData.Get(player)
	if not data then
		return world.Rooms[1]
	end
	return world.Rooms[math.min(data.SchoolIndex, 2)] or world.Rooms[1]
end

local function rootPart(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function isNearStudyDesk(player)
	local room = currentRoom(player)
	local root = rootPart(player)
	return room and root and (root.Position - room.StudyPart.Position).Magnitude <= Config.STUDY_DESK_MAX_DISTANCE
end

local function displayIQ(data)
	return Config.MicroIQToDisplay(data.MicroIQ)
end

local function buildPayload(player)
	local data = StudyData.Get(player)
	local state = getState(player)
	if not data then
		return nil
	end

	local school = Config.GetSchool(data.SchoolIndex)
	local nextSchool = Config.SCHOOLS[data.SchoolIndex + 1]
	local previousGoal = data.SchoolIndex > 1 and Config.GetSchool(data.SchoolIndex - 1).GoalMicroIQ or 0
	local range = math.max(1, school.GoalMicroIQ - previousGoal)
	local progress = math.clamp((data.MicroIQ - previousGoal) / range, 0, 1)
	local totalPoints = totalPartnerPoints(data)
	local pointCap = Config.GetPointCap(data.SchoolIndex)
	local nextPointSeconds = Config.GetTrainingSecondsForNextPoint(totalPoints)
	local currentDirectReward = math.max(1, math.floor(school.DirectRewardMicroIQ * Config.GetDirectRewardMultiplier({
		Specialization = data.PartnerSpecialization,
		PowerPoints = data.PartnerPowerPoints,
		SpeedPoints = data.PartnerSpeedPoints,
	})))
	local partnerReward = math.max(1, math.floor(school.DirectRewardMicroIQ * Config.GetPowerMultiplier(data.PartnerPowerPoints)))
	local partnerInterval = Config.PARTNER_BASE_INTERVAL / Config.GetSpeedMultiplier(data.PartnerSpeedPoints)

	return {
		MicroIQ = data.MicroIQ,
		DisplayIQ = displayIQ(data),
		SchoolIndex = data.SchoolIndex,
		SchoolName = school.DisplayName,
		GoalMicroIQ = school.GoalMicroIQ,
		GoalDisplayIQ = Config.MicroIQToDisplay(school.GoalMicroIQ),
		NextSchoolName = nextSchool and nextSchool.DisplayName or "Prestige",
		Progress = progress,
		DirectActive = state.DirectActive,
		ClickProgress = state.ClickProgress,
		ClicksNeeded = Config.DIRECT_CLICKS_PER_REWARD,
		DirectRewardMicroIQ = currentDirectReward,
		BreakthroughChance = Config.BREAKTHROUGH_CHANCE,
		PartnerUnlocked = data.PartnerUnlocked,
		DirectStudyRewards = data.DirectStudyRewards,
		PartnerPowerPoints = data.PartnerPowerPoints,
		PartnerSpeedPoints = data.PartnerSpeedPoints,
		PartnerUnspentPoints = data.PartnerUnspentPoints,
		PartnerTotalPoints = totalPoints,
		PartnerPointCap = pointCap,
		PartnerTrainingSeconds = data.PartnerTrainingSeconds,
		PartnerNextPointSeconds = nextPointSeconds,
		PartnerRewardMicroIQ = partnerReward,
		PartnerInterval = partnerInterval,
		PartnerSpecialization = data.PartnerSpecialization,
		RespecAvailable = data.RespecSchoolIndex ~= data.SchoolIndex,
		Ready = state.Ready,
		NextSchoolImplemented = nextSchool and nextSchool.Implemented == true or false,
	}
end

local function pushState(player)
	if not player.Parent then
		return
	end
	local payload = buildPayload(player)
	if payload then
		StateUpdated:FireClient(player, payload)
		player:SetAttribute("StudyMicroIQ", payload.MicroIQ)
		player:SetAttribute("StudyDisplayIQ", payload.DisplayIQ)
		player:SetAttribute("StudySchool", payload.SchoolName)
		player:SetAttribute("StudyReady", payload.Ready)
	end
end

local function setReadyIfNeeded(player)
	local data = StudyData.Get(player)
	if not data then
		return false
	end
	local state = getState(player)
	local school = Config.GetSchool(data.SchoolIndex)
	if data.MicroIQ < school.GoalMicroIQ then
		state.Ready = false
		return false
	end

	if not state.Ready then
		state.Ready = true
		state.DirectActive = false
		state.PendingDistraction = false
		state.ClickProgress = 0
		PresentationEvent:FireClient(player, "GraduationReady", {
			SchoolName = school.DisplayName,
			NextSchoolName = Config.SCHOOLS[data.SchoolIndex + 1] and Config.SCHOOLS[data.SchoolIndex + 1].DisplayName or "Prestige",
		})
		StudyData.Save(player, true)
	end
	return true
end

local function addMicroIQ(player, amount, source, breakthrough)
	local data = StudyData.Get(player)
	if not data then
		return 0
	end

	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return 0
	end

	data.MicroIQ += amount
	StudyData.MarkDirty(player)
	setReadyIfNeeded(player)
	PresentationEvent:FireClient(player, "Reward", {
		AmountMicroIQ = amount,
		Source = source,
		Breakthrough = breakthrough == true,
	})
	pushState(player)
	return amount
end

local function stopDirectStudy(player, reason)
	local state = getState(player)
	state.DirectActive = false
	state.PendingDistraction = false
	state.NextDistractionAt = 0
	pushState(player)
	if reason then
		PresentationEvent:FireClient(player, "StudyStopped", { Reason = reason })
	end
end

local function startDirectStudy(player)
	if not StudyData.IsLoaded(player) then
		return
	end
	local state = getState(player)
	if state.Ready then
		PresentationEvent:FireClient(player, "Info", { Text = "Your next school is ready." })
		return
	end
	if not isNearStudyDesk(player) then
		return
	end
	state.DirectActive = true
	state.PendingDistraction = false
	state.NextDistractionAt = os.clock() + 0.35
	pushState(player)
	PresentationEvent:FireClient(player, "StudyStarted", {})
end

local function toggleDirectStudy(player)
	local state = getState(player)
	if state.DirectActive then
		stopDirectStudy(player, "Paused")
	else
		startDirectStudy(player)
	end
end

local function directReward(player)
	local data = StudyData.Get(player)
	if not data then
		return
	end
	local school = Config.GetSchool(data.SchoolIndex)
	local baseReward = math.max(1, math.floor(school.DirectRewardMicroIQ * Config.GetDirectRewardMultiplier({
		Specialization = data.PartnerSpecialization,
		PowerPoints = data.PartnerPowerPoints,
		SpeedPoints = data.PartnerSpeedPoints,
	})))
	local breakthrough = math.random() < Config.BREAKTHROUGH_CHANCE
	local amount = breakthrough and (baseReward * Config.BREAKTHROUGH_MULTIPLIER) or baseReward

	data.DirectStudyRewards += 1
	local unlockedNow = false
	if not data.PartnerUnlocked and data.DirectStudyRewards >= Config.PARTNER_UNLOCK_REWARDS then
		data.PartnerUnlocked = true
		unlockedNow = true
	end

	StudyData.MarkDirty(player)
	addMicroIQ(player, amount, "Direct", breakthrough)

	if unlockedNow then
		PresentationEvent:FireClient(player, "PartnerUnlocked", {})
		StudyData.Save(player, true)
	end
end

local function spawnDistraction(player)
	local state = getState(player)
	local data = StudyData.Get(player)
	if not data or not state.DirectActive or state.PendingDistraction or state.Ready then
		return
	end
	if not isNearStudyDesk(player) then
		stopDirectStudy(player, "Move closer to your desk")
		return
	end

	state.DistractionNonce += 1
	state.PendingDistraction = true
	local distraction = Config.DISTRACTIONS[math.random(1, #Config.DISTRACTIONS)]
	DistractionSpawned:FireClient(player, {
		Nonce = state.DistractionNonce,
		Id = distraction.Id,
		Label = distraction.Label,
		Hint = distraction.Hint,
	})
end

StudyClickRequest.OnServerEvent:Connect(function(player, nonce)
	if not StudyData.IsLoaded(player) then
		return
	end
	local state = getState(player)
	local nowTime = os.clock()
	if not state.DirectActive or not state.PendingDistraction or state.Ready then
		return
	end
	if tonumber(nonce) ~= state.DistractionNonce then
		return
	end
	if nowTime - state.LastClickAt < Config.DIRECT_CLICK_MIN_INTERVAL then
		return
	end
	if not isNearStudyDesk(player) then
		stopDirectStudy(player, "Move closer to your desk")
		return
	end

	state.LastClickAt = nowTime
	state.PendingDistraction = false
	state.ClickProgress += 1
	local data = StudyData.Get(player)
	local delayMultiplier = Config.GetDistractionSpeedMultiplier({
		Specialization = data.PartnerSpecialization,
		PowerPoints = data.PartnerPowerPoints,
		SpeedPoints = data.PartnerSpeedPoints,
	})
	local baseDelay = Config.DISTRACTION_MIN_DELAY + (math.random() * (Config.DISTRACTION_MAX_DELAY - Config.DISTRACTION_MIN_DELAY))
	state.NextDistractionAt = nowTime + (baseDelay / delayMultiplier)

	if state.ClickProgress >= Config.DIRECT_CLICKS_PER_REWARD then
		state.ClickProgress = 0
		directReward(player)
	else
		pushState(player)
	end
end)

local function validateUpgradeAllocation(data, targetPower, targetSpeed, specialization)
	targetPower = math.max(0, math.floor(tonumber(targetPower) or 0))
	targetSpeed = math.max(0, math.floor(tonumber(targetSpeed) or 0))
	specialization = tostring(specialization or data.PartnerSpecialization or "")
	if specialization ~= "Power" and specialization ~= "Speed" then
		specialization = ""
	end

	local currentlyInvested = data.PartnerPowerPoints + data.PartnerSpeedPoints
	local targetInvested = targetPower + targetSpeed
	local available = currentlyInvested + data.PartnerUnspentPoints
	if targetInvested < currentlyInvested or targetInvested > available then
		return false, "INVALID_POINT_TOTAL"
	end

	if targetInvested <= 10 then
		if targetPower > 5 or targetSpeed > 5 then
			return false, "PRE_SPECIALIZATION_CAP"
		end
		if specialization ~= "" then
			return false, "SPECIALIZATION_TOO_EARLY"
		end
	else
		if specialization == "Power" then
			if targetPower > 15 or targetSpeed > 5 then
				return false, "POWER_SPECIALIZATION_CAP"
			end
		elseif specialization == "Speed" then
			if targetSpeed > 15 or targetPower > 5 then
				return false, "SPEED_SPECIALIZATION_CAP"
			end
		else
			return false, "SPECIALIZATION_REQUIRED"
		end
	end

	if targetInvested > Config.GetPointCap(data.SchoolIndex) then
		return false, "SCHOOL_POINT_CAP"
	end

	return true, targetPower, targetSpeed, specialization, available - targetInvested
end

UpgradeApplyRequest.OnServerEvent:Connect(function(player, request)
	local data = StudyData.Get(player)
	if not data or not data.PartnerUnlocked or type(request) ~= "table" then
		return
	end

	local valid, a, b, c, d = validateUpgradeAllocation(data, request.PowerPoints, request.SpeedPoints, request.Specialization)
	if not valid then
		PresentationEvent:FireClient(player, "Info", { Text = "Upgrade rejected: " .. tostring(a) })
		pushState(player)
		return
	end

	data.PartnerPowerPoints = a
	data.PartnerSpeedPoints = b
	data.PartnerSpecialization = c
	data.PartnerUnspentPoints = d
	StudyData.MarkDirty(player)
	StudyData.Save(player, true)
	PresentationEvent:FireClient(player, "UpgradeApplied", {})
	pushState(player)
end)

RespecRequest.OnServerEvent:Connect(function(player)
	local data = StudyData.Get(player)
	if not data or not data.PartnerUnlocked then
		return
	end
	if data.RespecSchoolIndex == data.SchoolIndex then
		PresentationEvent:FireClient(player, "Info", { Text = "Free respec already used in this school." })
		return
	end

	local invested = data.PartnerPowerPoints + data.PartnerSpeedPoints
	data.PartnerPowerPoints = 0
	data.PartnerSpeedPoints = 0
	data.PartnerUnspentPoints += invested
	data.PartnerSpecialization = ""
	data.RespecSchoolIndex = data.SchoolIndex
	StudyData.MarkDirty(player)
	StudyData.Save(player, true)
	PresentationEvent:FireClient(player, "RespecComplete", {})
	pushState(player)
end)

local function partnerTick(player, dt)
	local data = StudyData.Get(player)
	local state = getState(player)
	if not data or not data.PartnerUnlocked or state.Ready then
		return
	end

	state.PartnerWorkSeconds += dt
	local school = Config.GetSchool(data.SchoolIndex)
	local interval = Config.PARTNER_BASE_INTERVAL / Config.GetSpeedMultiplier(data.PartnerSpeedPoints)
	local reward = math.max(1, math.floor(school.DirectRewardMicroIQ * Config.GetPowerMultiplier(data.PartnerPowerPoints)))

	while state.PartnerWorkSeconds >= interval and not state.Ready do
		state.PartnerWorkSeconds -= interval
		addMicroIQ(player, reward, "Partner", false)
	end

	local totalPoints = totalPartnerPoints(data)
	local pointCap = Config.GetPointCap(data.SchoolIndex)
	if totalPoints < pointCap then
		data.PartnerTrainingSeconds += dt
		local requirement = Config.GetTrainingSecondsForNextPoint(totalPoints)
		while data.PartnerTrainingSeconds >= requirement and totalPoints < pointCap do
			data.PartnerTrainingSeconds -= requirement
			data.PartnerUnspentPoints += 1
			totalPoints += 1
			StudyData.MarkDirty(player)
			PresentationEvent:FireClient(player, "UpgradePointEarned", {})
			requirement = Config.GetTrainingSecondsForNextPoint(totalPoints)
			pushState(player)
		end
	end
end

local function teleportToCurrentRoom(player)
	local data = StudyData.Get(player)
	local room = currentRoom(player)
	local character = player.Character
	if not data or not room or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root then
		character:PivotTo(room.Spawn.CFrame + Vector3.new(0, 4, 0))
	end
	if humanoid then
		humanoid.WalkSpeed = Config.PLAYER_WALK_SPEED
	end
end

local function graduate(player)
	local data = StudyData.Get(player)
	local state = getState(player)
	if not data or not state.Ready then
		PresentationEvent:FireClient(player, "Info", { Text = "Reach the IQ goal first." })
		return
	end

	local nextSchool = Config.SCHOOLS[data.SchoolIndex + 1]
	if not nextSchool then
		PresentationEvent:FireClient(player, "Info", { Text = "Prestige is not part of this playable slice yet." })
		return
	end
	if not nextSchool.Implemented then
		PresentationEvent:FireClient(player, "Info", { Text = nextSchool.DisplayName .. " is coming in the next build." })
		return
	end

	local previousName = Config.GetSchool(data.SchoolIndex).DisplayName
	data.SchoolIndex += 1
	state.Ready = false
	state.DirectActive = false
	state.PendingDistraction = false
	state.ClickProgress = 0
	StudyData.MarkDirty(player)
	StudyData.Save(player, true)
	PresentationEvent:FireClient(player, "Graduation", {
		From = previousName,
		To = nextSchool.DisplayName,
	})
	task.delay(1.2, function()
		if player.Parent then
			teleportToCurrentRoom(player)
			pushState(player)
		end
	end)
end

for _, room in pairs(world.Rooms) do
	room.StudyPrompt.Triggered:Connect(function(player)
		if currentRoom(player) == room then
			toggleDirectStudy(player)
		end
	end)

	room.PartnerPrompt.Triggered:Connect(function(player)
		if currentRoom(player) == room then
			OpenPartnerPanel:FireClient(player, buildPayload(player))
		end
	end)

	room.GatePrompt.Triggered:Connect(function(player)
		if currentRoom(player) == room then
			graduate(player)
		end
	end)
end

local function onCharacterAdded(player, character)
	task.delay(0.75, function()
		if player.Parent and character.Parent and StudyData.IsLoaded(player) then
			teleportToCurrentRoom(player)
		end
	end)
end

local function onPlayerAdded(player)
	local success, dataOrError = StudyData.Load(player)
	if not success then
		warn("[StudySimulator] Load failed", player.Name, dataOrError)
		player:Kick("Your study profile is already open or could not be loaded. Please rejoin.")
		return
	end

	local data = dataOrError
	local state = getState(player)
	state.Ready = data.MicroIQ >= Config.GetSchool(data.SchoolIndex).GoalMicroIQ
	state.LastTickAt = os.clock()

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	pushState(player)
	PresentationEvent:FireClient(player, "DataReady", buildPayload(player))
	print("[StudySimulator] Loaded", player.Name, "school", data.SchoolIndex, "microIQ", data.MicroIQ)
end

local function onPlayerRemoving(player)
	stopDirectStudy(player)
	local success, err = StudyData.Release(player)
	if not success then
		warn("[StudySimulator] Release failed", player.Name, err)
	end
	playerStates[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	local step = accumulator
	accumulator = 0
	local nowTime = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		if StudyData.IsLoaded(player) then
			local state = getState(player)
			if state.DirectActive and not state.PendingDistraction and not state.Ready and nowTime >= state.NextDistractionAt then
				spawnDistraction(player)
			end
			partnerTick(player, step)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			if StudyData.IsLoaded(player) then
				local ok, err = StudyData.Save(player, false)
				if not ok and err ~= "SAVE_IN_PROGRESS" then
					warn("[StudySimulator] Autosave failed", player.Name, err)
				end
			end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			StudyData.Release(player)
			pending -= 1
		end)
	end

	local deadline = os.clock() + 20
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

print("[StudySimulator] Kindergarten and Elementary playable slice ready")
