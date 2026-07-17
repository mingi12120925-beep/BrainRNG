local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("StudySimulatorConfig"))
local remotes = ReplicatedStorage:WaitForChild("StudySimulatorRemotes")

local StateUpdated = remotes:WaitForChild("StateUpdated")
local DistractionSpawned = remotes:WaitForChild("DistractionSpawned")
local StudyClickRequest = remotes:WaitForChild("StudyClickRequest")
local UpgradeApplyRequest = remotes:WaitForChild("UpgradeApplyRequest")
local RespecRequest = remotes:WaitForChild("RespecRequest")
local PresentationEvent = remotes:WaitForChild("PresentationEvent")
local OpenPartnerPanel = remotes:WaitForChild("OpenPartnerPanel")

local latest = nil
local currentNonce = nil
local partnerPanelOpen = false
local previewPower = 0
local previewSpeed = 0
local previewSpecialization = ""
local legacySuppressionStarted = false
local graduationHighlight = nil

local COLORS = {
	Navy = Color3.fromRGB(37, 52, 68),
	Navy2 = Color3.fromRGB(49, 68, 88),
	Cream = Color3.fromRGB(248, 244, 229),
	Paper = Color3.fromRGB(255, 252, 241),
	Green = Color3.fromRGB(74, 127, 101),
	Blue = Color3.fromRGB(72, 111, 157),
	Gold = Color3.fromRGB(205, 157, 68),
	Red = Color3.fromRGB(170, 79, 70),
	Muted = Color3.fromRGB(111, 121, 132),
	Ink = Color3.fromRGB(39, 47, 57),
}

local function corner(parent, radius)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius or 10)
	value.Parent = parent
	return value
end

local function stroke(parent, color, thickness, transparency)
	local value = Instance.new("UIStroke")
	value.Color = color or COLORS.Navy
	value.Thickness = thickness or 1
	value.Transparency = transparency or 0
	value.Parent = parent
	return value
end

local function padding(parent, left, right, top, bottom)
	local value = Instance.new("UIPadding")
	value.PaddingLeft = UDim.new(0, left or 0)
	value.PaddingRight = UDim.new(0, right or 0)
	value.PaddingTop = UDim.new(0, top or 0)
	value.PaddingBottom = UDim.new(0, bottom or 0)
	value.Parent = parent
	return value
end

local function createLabel(parent, name, text, size, position, fontSize, color, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.fromOffset(0, 0)
	label.Text = text or ""
	label.TextColor3 = color or COLORS.Ink
	label.TextSize = fontSize or 18
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

local function createButton(parent, name, text, size, position, background)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position or UDim2.fromOffset(0, 0)
	button.BackgroundColor3 = background or COLORS.Navy
	button.AutoButtonColor = true
	button.Text = text
	button.TextColor3 = COLORS.Cream
	button.TextSize = 17
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	corner(button, 10)
	stroke(button, Color3.fromRGB(255, 255, 255), 1, 0.78)
	return button
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainStudyHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 900
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local topCard = Instance.new("Frame")
topCard.Name = "ProgressCard"
topCard.AnchorPoint = Vector2.new(0.5, 0)
topCard.Position = UDim2.new(0.5, 0, 0, 18)
topCard.Size = UDim2.new(0, 460, 0, 104)
topCard.BackgroundColor3 = COLORS.Paper
topCard.Parent = screenGui
corner(topCard, 14)
stroke(topCard, COLORS.Navy, 2, 0.1)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 94)
sizeConstraint.MaxSize = Vector2.new(520, 118)
sizeConstraint.Parent = topCard

local schoolLabel = createLabel(topCard, "School", "KINDERGARTEN", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), 16, COLORS.Green)
schoolLabel.TextXAlignment = Enum.TextXAlignment.Left
local iqLabel = createLabel(topCard, "IQ", "IQ 80.000000", UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 30), 25, COLORS.Ink)
iqLabel.TextXAlignment = Enum.TextXAlignment.Left
local goalLabel = createLabel(topCard, "Goal", "Elementary · 80.010000", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 60), 13, COLORS.Muted)
goalLabel.TextXAlignment = Enum.TextXAlignment.Left

local progressBack = Instance.new("Frame")
progressBack.Name = "ProgressBack"
progressBack.Position = UDim2.new(0, 12, 1, -19)
progressBack.Size = UDim2.new(1, -24, 0, 9)
progressBack.BackgroundColor3 = Color3.fromRGB(215, 212, 201)
progressBack.Parent = topCard
corner(progressBack, 8)
local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = COLORS.Green
progressFill.Parent = progressBack
corner(progressFill, 8)

local studyCard = Instance.new("Frame")
studyCard.Name = "StudyCard"
studyCard.AnchorPoint = Vector2.new(0.5, 1)
studyCard.Position = UDim2.new(0.5, 0, 1, -24)
studyCard.Size = UDim2.new(0, 420, 0, 108)
studyCard.BackgroundColor3 = COLORS.Paper
studyCard.Parent = screenGui
corner(studyCard, 14)
stroke(studyCard, COLORS.Navy, 2, 0.1)

local studyTitle = createLabel(studyCard, "StudyTitle", "GO TO YOUR DESK", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 10), 20, COLORS.Navy)
local studyHint = createLabel(studyCard, "StudyHint", "Press E at the study desk to begin.", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 40), 14, COLORS.Muted)
local clickProgress = createLabel(studyCard, "ClickProgress", "FOCUS 0 / 3", UDim2.new(0.5, -16, 0, 28), UDim2.fromOffset(12, 70), 17, COLORS.Green, Enum.TextXAlignment.Left)
local partnerButton = createButton(studyCard, "PartnerButton", "PARTNER", UDim2.new(0, 132, 0, 38), UDim2.new(1, -144, 1, -48), COLORS.Blue)
partnerButton.Visible = false

local distractionButton = createButton(screenGui, "Distraction", "PHONE ALERT\nTap to silence it", UDim2.fromOffset(210, 86), UDim2.fromScale(0.5, 0.54), COLORS.Red)
distractionButton.AnchorPoint = Vector2.new(0.5, 0.5)
distractionButton.TextWrapped = true
distractionButton.TextSize = 18
distractionButton.Visible = false
distractionButton.ZIndex = 30

local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 136)
toast.Size = UDim2.new(0, 420, 0, 72)
toast.BackgroundColor3 = COLORS.Navy
toast.BackgroundTransparency = 0.03
toast.Visible = false
toast.ZIndex = 50
toast.Parent = screenGui
corner(toast, 12)
local toastTitle = createLabel(toast, "Title", "", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 7), 20, COLORS.Cream)
toastTitle.ZIndex = 51
local toastBody = createLabel(toast, "Body", "", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 37), 14, Color3.fromRGB(222, 226, 229))
toastBody.ZIndex = 51

local readyBanner = Instance.new("Frame")
readyBanner.Name = "ReadyBanner"
readyBanner.AnchorPoint = Vector2.new(0.5, 0.5)
readyBanner.Position = UDim2.fromScale(0.5, 0.5)
readyBanner.Size = UDim2.new(0, 460, 0, 136)
readyBanner.BackgroundColor3 = COLORS.Paper
readyBanner.Visible = false
readyBanner.ZIndex = 45
readyBanner.Parent = screenGui
corner(readyBanner, 16)
stroke(readyBanner, COLORS.Gold, 4, 0)
local readyTitle = createLabel(readyBanner, "ReadyTitle", "ELEMENTARY READY", UDim2.new(1, -30, 0, 48), UDim2.fromOffset(15, 16), 28, COLORS.Gold)
readyTitle.ZIndex = 46
local readyBody = createLabel(readyBanner, "ReadyBody", "Go through the graduation gate.", UDim2.new(1, -30, 0, 42), UDim2.fromOffset(15, 70), 17, COLORS.Ink)
readyBody.ZIndex = 46

local partnerPanel = Instance.new("Frame")
partnerPanel.Name = "PartnerPanel"
partnerPanel.AnchorPoint = Vector2.new(0.5, 0.5)
partnerPanel.Position = UDim2.fromScale(0.5, 0.5)
partnerPanel.Size = UDim2.new(0, 480, 0, 500)
partnerPanel.BackgroundColor3 = COLORS.Paper
partnerPanel.Visible = false
partnerPanel.ZIndex = 60
partnerPanel.Parent = screenGui
corner(partnerPanel, 16)
stroke(partnerPanel, COLORS.Navy, 2, 0.05)
padding(partnerPanel, 18, 18, 14, 14)

local panelTitle = createLabel(partnerPanel, "Title", "STUDY PARTNER", UDim2.new(1, -50, 0, 34), UDim2.fromOffset(0, 0), 24, COLORS.Navy, Enum.TextXAlignment.Left)
panelTitle.ZIndex = 61
local closeButton = createButton(partnerPanel, "Close", "×", UDim2.fromOffset(40, 36), UDim2.new(1, -40, 0, 0), COLORS.Red)
closeButton.TextSize = 24
closeButton.ZIndex = 62

local partnerSummary = createLabel(partnerPanel, "Summary", "Locked", UDim2.new(1, 0, 0, 72), UDim2.fromOffset(0, 44), 15, COLORS.Muted, Enum.TextXAlignment.Left)
partnerSummary.TextYAlignment = Enum.TextYAlignment.Top
partnerSummary.ZIndex = 61

local powerRow = Instance.new("Frame")
powerRow.Name = "PowerRow"
powerRow.Position = UDim2.fromOffset(0, 126)
powerRow.Size = UDim2.new(1, 0, 0, 68)
powerRow.BackgroundColor3 = Color3.fromRGB(239, 234, 218)
powerRow.ZIndex = 61
powerRow.Parent = partnerPanel
corner(powerRow, 10)
local powerLabel = createLabel(powerRow, "Label", "STUDY POWER", UDim2.new(0.62, 0, 1, 0), UDim2.fromOffset(14, 0), 17, COLORS.Ink, Enum.TextXAlignment.Left)
powerLabel.ZIndex = 62
local powerValue = createLabel(powerRow, "Value", "0", UDim2.fromOffset(54, 48), UDim2.new(1, -126, 0.5, -24), 22, COLORS.Navy)
powerValue.ZIndex = 62
local powerPlus = createButton(powerRow, "Plus", "+", UDim2.fromOffset(50, 48), UDim2.new(1, -60, 0.5, -24), COLORS.Green)
powerPlus.ZIndex = 62

local speedRow = powerRow:Clone()
speedRow.Name = "SpeedRow"
speedRow.Position = UDim2.fromOffset(0, 204)
speedRow.Parent = partnerPanel
speedRow.Label.Text = "STUDY SPEED"
local speedValue = speedRow.Value
local speedPlus = speedRow.Plus

local specializeLabel = createLabel(partnerPanel, "SpecializeLabel", "SPECIALIZATION UNLOCKS AT POINT 11", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 284), 13, COLORS.Muted)
specializeLabel.ZIndex = 61
local powerSpecialize = createButton(partnerPanel, "PowerSpecialize", "POWER PATH", UDim2.new(0.48, 0, 0, 42), UDim2.fromOffset(0, 314), COLORS.Green)
powerSpecialize.Visible = false
powerSpecialize.ZIndex = 62
local speedSpecialize = createButton(partnerPanel, "SpeedSpecialize", "SPEED PATH", UDim2.new(0.48, 0, 0, 42), UDim2.new(0.52, 0, 0, 314), COLORS.Blue)
speedSpecialize.Visible = false
speedSpecialize.ZIndex = 62

local trainingLabel = createLabel(partnerPanel, "Training", "NEXT POINT 05:00", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 370), 15, COLORS.Muted)
trainingLabel.ZIndex = 61
local applyButton = createButton(partnerPanel, "Apply", "APPLY UPGRADES", UDim2.new(0.62, 0, 0, 48), UDim2.fromOffset(0, 430), COLORS.Navy)
applyButton.ZIndex = 62
local respecButton = createButton(partnerPanel, "Respec", "FREE RESPEC", UDim2.new(0.34, 0, 0, 48), UDim2.new(0.66, 0, 0, 430), COLORS.Gold)
respecButton.ZIndex = 62

local function formatDisplayIQ(value)
	return string.format("%.6f", tonumber(value) or Config.BASE_DISPLAY_IQ)
end

local function formatMicroReward(value)
	return "+" .. string.format("%.6f", (tonumber(value) or 0) / Config.MICRO_IQ_PER_DISPLAY_IQ) .. " IQ"
end

local function showToast(title, body, duration, background)
	toast.BackgroundColor3 = background or COLORS.Navy
	toastTitle.Text = title or ""
	toastBody.Text = body or ""
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 0, 120)
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.18), {
		Position = UDim2.new(0.5, 0, 0, 136),
		BackgroundTransparency = 0.03,
	}):Play()

	local token = os.clock()
	toast:SetAttribute("Token", token)
	task.delay(duration or 2.2, function()
		if toast:GetAttribute("Token") == token then
			local tween = TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			if toast:GetAttribute("Token") == token then
				toast.Visible = false
			end
		end
	end)
end

local function suppressLegacyGui()
	if legacySuppressionStarted then
		return
	end
	legacySuppressionStarted = true

	local function suppress(child)
		if child:IsA("ScreenGui") and child ~= screenGui then
			child.Enabled = false
		end
	end

	for _, child in ipairs(playerGui:GetChildren()) do
		suppress(child)
	end
	playerGui.ChildAdded:Connect(function(child)
		task.defer(suppress, child)
	end)
end

local function clearGraduationHighlight()
	if graduationHighlight then
		graduationHighlight:Destroy()
		graduationHighlight = nil
	end
end

local function highlightGate()
	clearGraduationHighlight()
	local worldRoot = Workspace:FindFirstChild("StudySimulatorWorld")
	if not worldRoot or not latest then
		return
	end
	local roomName = latest.SchoolIndex == 1 and "KindergartenRoom" or "ElementaryRoom"
	local room = worldRoot:FindFirstChild(roomName)
	local gate = room and room:FindFirstChild("GraduationGate", true)
	if not gate then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "GraduationReadyHighlight"
	highlight.FillColor = COLORS.Gold
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = COLORS.Gold
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = gate
	highlight.Parent = gate
	graduationHighlight = highlight
end

local function pointMaximums()
	if previewSpecialization == "Power" then
		return 15, 5
	elseif previewSpecialization == "Speed" then
		return 5, 15
	end
	return 5, 5
end

local function refreshPartnerPanel()
	if not latest then
		return
	end
	previewPower = math.max(previewPower, latest.PartnerPowerPoints or 0)
	previewSpeed = math.max(previewSpeed, latest.PartnerSpeedPoints or 0)
	if previewSpecialization == "" then
		previewSpecialization = latest.PartnerSpecialization or ""
	end

	local spentPreview = previewPower + previewSpeed
	local invested = (latest.PartnerPowerPoints or 0) + (latest.PartnerSpeedPoints or 0)
	local usedUnspent = spentPreview - invested
	local remaining = math.max(0, (latest.PartnerUnspentPoints or 0) - usedUnspent)
	local powerMax, speedMax = pointMaximums()
	local powerMultiplier = 1 + previewPower * Config.PARTNER_POWER_PER_POINT
	local speedMultiplier = 1 + previewSpeed * Config.PARTNER_SPEED_PER_POINT
	local reward = math.max(1, math.floor((latest.DirectRewardMicroIQ or 1) * powerMultiplier))
	local interval = Config.PARTNER_BASE_INTERVAL / speedMultiplier

	powerValue.Text = tostring(previewPower) .. "/" .. tostring(powerMax)
	speedValue.Text = tostring(previewSpeed) .. "/" .. tostring(speedMax)
	powerPlus.Text = remaining > 0 and "+" or "—"
	speedPlus.Text = remaining > 0 and "+" or "—"

	if latest.PartnerUnlocked then
		partnerSummary.Text = string.format(
			"%s every %.1fs\nUnspent points: %d · School cap: %d/%d",
			formatMicroReward(reward),
			interval,
			remaining,
			latest.PartnerTotalPoints or 0,
			latest.PartnerPointCap or 0
		)
	else
		partnerSummary.Text = string.format(
			"Complete %d direct study rewards to unlock.\nProgress: %d / %d",
			Config.PARTNER_UNLOCK_REWARDS,
			latest.DirectStudyRewards or 0,
			Config.PARTNER_UNLOCK_REWARDS
		)
	end

	local totalPreview = previewPower + previewSpeed
	local specializationNeeded = totalPreview > 10 and previewSpecialization == ""
	powerSpecialize.Visible = specializationNeeded
	speedSpecialize.Visible = specializationNeeded
	if previewSpecialization ~= "" then
		specializeLabel.Text = string.upper(previewSpecialization) .. " SPECIALIZATION"
	elseif specializationNeeded then
		specializeLabel.Text = "CHOOSE A SPECIALIZATION"
	else
		specializeLabel.Text = "SPECIALIZATION UNLOCKS AT POINT 11"
	end

	local requirement = latest.PartnerNextPointSeconds or 300
	local elapsed = latest.PartnerTrainingSeconds or 0
	local remainingSeconds = math.max(0, requirement - elapsed)
	trainingLabel.Text = string.format("NEXT POINT %02d:%02d", math.floor(remainingSeconds / 60), math.floor(remainingSeconds % 60))
	applyButton.Text = specializationNeeded and "CHOOSE A PATH" or "APPLY UPGRADES"
	applyButton.Active = latest.PartnerUnlocked == true
	applyButton.AutoButtonColor = latest.PartnerUnlocked == true
	applyButton.BackgroundColor3 = latest.PartnerUnlocked and COLORS.Navy or COLORS.Muted
	respecButton.Visible = latest.PartnerUnlocked == true
	respecButton.Text = latest.RespecAvailable and "FREE RESPEC" or "RESPEC USED"
	respecButton.BackgroundColor3 = latest.RespecAvailable and COLORS.Gold or COLORS.Muted
end

local function openPanel(payload)
	if payload then
		latest = payload
	end
	if not latest then
		return
	end
	partnerPanelOpen = true
	partnerPanel.Visible = true
	previewPower = latest.PartnerPowerPoints or 0
	previewSpeed = latest.PartnerSpeedPoints or 0
	previewSpecialization = latest.PartnerSpecialization or ""
	refreshPartnerPanel()
end

local function closePanel()
	partnerPanelOpen = false
	partnerPanel.Visible = false
end

local function updateState(payload)
	if type(payload) ~= "table" then
		return
	end
	latest = payload
	suppressLegacyGui()

	schoolLabel.Text = string.upper(payload.SchoolName or "SCHOOL")
	iqLabel.Text = "IQ " .. formatDisplayIQ(payload.DisplayIQ)
	goalLabel.Text = tostring(payload.NextSchoolName or "Next School") .. " · " .. formatDisplayIQ(payload.GoalDisplayIQ)
	TweenService:Create(progressFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(math.clamp(tonumber(payload.Progress) or 0, 0, 1), 1),
	}):Play()

	if payload.Ready then
		studyTitle.Text = "GRADUATION READY"
		studyHint.Text = "Study and partner production are paused."
		studyTitle.TextColor3 = COLORS.Gold
	elseif payload.DirectActive then
		studyTitle.Text = "FOCUS MODE ACTIVE"
		studyHint.Text = "Handle each distraction. Three taps earn IQ."
		studyTitle.TextColor3 = COLORS.Green
	else
		studyTitle.Text = "GO TO YOUR DESK"
		studyHint.Text = "Press E at the study desk to begin."
		studyTitle.TextColor3 = COLORS.Navy
	end
	clickProgress.Text = string.format("FOCUS %d / %d", payload.ClickProgress or 0, payload.ClicksNeeded or 3)
	partnerButton.Visible = payload.PartnerUnlocked == true

	readyBanner.Visible = payload.Ready == true
	if payload.Ready then
		readyTitle.Text = string.upper(tostring(payload.NextSchoolName or "NEXT SCHOOL")) .. " READY"
		readyBody.Text = "Go through the graduation gate when you are ready."
		highlightGate()
	else
		clearGraduationHighlight()
	end

	if partnerPanelOpen then
		refreshPartnerPanel()
	end
end

StateUpdated.OnClientEvent:Connect(updateState)
OpenPartnerPanel.OnClientEvent:Connect(openPanel)

DistractionSpawned.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	currentNonce = payload.Nonce
	distractionButton.Text = tostring(payload.Label or "DISTRACTION") .. "\n" .. tostring(payload.Hint or "Tap")
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local xMin, xMax = 0.18, 0.82
	local yMin, yMax = 0.28, 0.70
	if viewport.X < 700 then
		xMin, xMax = 0.25, 0.75
		yMin, yMax = 0.30, 0.66
	end
	distractionButton.Position = UDim2.fromScale(xMin + math.random() * (xMax - xMin), yMin + math.random() * (yMax - yMin))
	distractionButton.Size = UDim2.fromOffset(185, 82)
	distractionButton.Visible = true
	distractionButton.BackgroundTransparency = 0.06
	distractionButton.Rotation = math.random(-4, 4)
	TweenService:Create(distractionButton, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(215, 90),
		BackgroundTransparency = 0,
	}):Play()
end)

distractionButton.Activated:Connect(function()
	if currentNonce == nil then
		return
	end
	local nonce = currentNonce
	currentNonce = nil
	distractionButton.Visible = false
	StudyClickRequest:FireServer(nonce)
end)

partnerButton.Activated:Connect(function()
	openPanel(latest)
end)
closeButton.Activated:Connect(closePanel)

local function canSpendPreview()
	if not latest then
		return false
	end
	local invested = (latest.PartnerPowerPoints or 0) + (latest.PartnerSpeedPoints or 0)
	local previewInvested = previewPower + previewSpeed
	return previewInvested - invested < (latest.PartnerUnspentPoints or 0)
end

powerPlus.Activated:Connect(function()
	local powerMax = pointMaximums()
	if canSpendPreview() and previewPower < powerMax then
		previewPower += 1
		refreshPartnerPanel()
	end
end)

speedPlus.Activated:Connect(function()
	local _, speedMax = pointMaximums()
	if canSpendPreview() and previewSpeed < speedMax then
		previewSpeed += 1
		refreshPartnerPanel()
	end
end)

powerSpecialize.Activated:Connect(function()
	previewSpecialization = "Power"
	if previewSpeed > 5 then
		previewSpeed = 5
	end
	refreshPartnerPanel()
end)

speedSpecialize.Activated:Connect(function()
	previewSpecialization = "Speed"
	if previewPower > 5 then
		previewPower = 5
	end
	refreshPartnerPanel()
end)

applyButton.Activated:Connect(function()
	if not latest or not latest.PartnerUnlocked then
		return
	end
	UpgradeApplyRequest:FireServer({
		PowerPoints = previewPower,
		SpeedPoints = previewSpeed,
		Specialization = previewSpecialization,
	})
end)

respecButton.Activated:Connect(function()
	if latest and latest.RespecAvailable then
		RespecRequest:FireServer()
	end
end)

PresentationEvent.OnClientEvent:Connect(function(kind, payload)
	payload = type(payload) == "table" and payload or {}
	if kind == "DataReady" then
		updateState(payload)
	elseif kind == "Reward" then
		local source = tostring(payload.Source or "Study")
		if payload.Breakthrough then
			showToast("BREAKTHROUGH!", formatMicroReward(payload.AmountMicroIQ) .. " · 3× study reward", 2.4, COLORS.Gold)
		else
			showToast(source == "Partner" and "PARTNER STUDY" or "FOCUS COMPLETE", formatMicroReward(payload.AmountMicroIQ), 1.1, source == "Partner" and COLORS.Blue or COLORS.Green)
		end
	elseif kind == "PartnerUnlocked" then
		showToast("STUDY PARTNER JOINED", "Your partner now studies automatically while you are online.", 3.2, COLORS.Blue)
	elseif kind == "UpgradePointEarned" then
		showToast("PARTNER UPGRADE READY", "Open the partner panel to spend the new point.", 2.4, COLORS.Blue)
	elseif kind == "UpgradeApplied" then
		showToast("UPGRADES APPLIED", "Your partner's work pattern has changed.", 1.8, COLORS.Green)
	elseif kind == "RespecComplete" then
		showToast("POINTS RETURNED", "Choose a new Power and Speed setup.", 2.0, COLORS.Gold)
	elseif kind == "StudyStarted" then
		showToast("FOCUS MODE", "Handle three distractions to earn IQ.", 1.6, COLORS.Green)
	elseif kind == "StudyStopped" then
		currentNonce = nil
		distractionButton.Visible = false
	elseif kind == "GraduationReady" then
		showToast("SCHOOL GOAL COMPLETE", "Your graduation gate is ready.", 3.2, COLORS.Gold)
	elseif kind == "Graduation" then
		currentNonce = nil
		distractionButton.Visible = false
		readyBanner.Visible = false
		local fade = Instance.new("Frame")
		fade.Name = "GraduationFade"
		fade.Size = UDim2.fromScale(1, 1)
		fade.BackgroundColor3 = Color3.fromRGB(247, 244, 232)
		fade.BackgroundTransparency = 1
		fade.ZIndex = 100
		fade.Parent = screenGui
		local title = createLabel(fade, "GraduationTitle", string.upper(tostring(payload.To or "NEXT SCHOOL")) .. " UNLOCKED", UDim2.new(1, -40, 0, 70), UDim2.new(0, 20, 0.5, -48), 34, COLORS.Navy)
		title.ZIndex = 101
		local sub = createLabel(fade, "GraduationSub", "YOUR IQ WAS KEPT", UDim2.new(1, -40, 0, 34), UDim2.new(0, 20, 0.5, 24), 18, COLORS.Green)
		sub.ZIndex = 101
		TweenService:Create(fade, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
		task.delay(3.5, function()
			local tween = TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			fade:Destroy()
		end)
	elseif kind == "Info" then
		showToast("NOTICE", tostring(payload.Text or ""), 2.2, COLORS.Navy)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P and latest and latest.PartnerUnlocked then
		if partnerPanelOpen then
			closePanel()
		else
			openPanel(latest)
		end
	end
end)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local viewport = camera.ViewportSize
		if viewport.X < 700 then
			topCard.Size = UDim2.new(1, -28, 0, 98)
			studyCard.Size = UDim2.new(1, -28, 0, 104)
			partnerPanel.Size = UDim2.new(1, -24, 0, 500)
		else
			topCard.Size = UDim2.new(0, 460, 0, 104)
			studyCard.Size = UDim2.new(0, 420, 0, 108)
			partnerPanel.Size = UDim2.new(0, 480, 0, 500)
		end
	end)
end

showToast("LOADING STUDY PROFILE", "Preparing your classroom…", 2.0, COLORS.Navy)
