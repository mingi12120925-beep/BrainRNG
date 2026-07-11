-- StarterPlayer/StarterPlayerScripts/RollWorldFeedback.client.lua
-- Temporary client-only first-impression and success feedback for the central Roll area.
-- This script does not change Roll rewards, cooldowns, saving, or server authority.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local MAP_WAIT_SECONDS = 30
local ROLL_BUTTON_NAME = "RollButton"
local RESULT_HOLD_SECONDS = 0.75

local RARITY_EFFECTS = {
	{ Match = "REALITY BREAKER", Name = "REALITY BREAKER", Color = Color3.fromRGB(255, 255, 255), Emit = 90 },
	{ Match = "TRANSCENDENT", Name = "TRANSCENDENT", Color = Color3.fromRGB(95, 255, 235), Emit = 75 },
	{ Match = "IMPOSSIBLE", Name = "IMPOSSIBLE", Color = Color3.fromRGB(255, 70, 95), Emit = 75 },
	{ Match = "SECRET", Name = "SECRET", Color = Color3.fromRGB(255, 80, 180), Emit = 70 },
	{ Match = "MYTHIC", Name = "MYTHIC", Color = Color3.fromRGB(220, 120, 255), Emit = 60 },
	{ Match = "LEGENDARY", Name = "LEGENDARY", Color = Color3.fromRGB(255, 210, 70), Emit = 55 },
	{ Match = "MASTERMIND", Name = "MASTERMIND", Color = Color3.fromRGB(255, 110, 80), Emit = 48 },
	{ Match = "SUPER GENIUS", Name = "SUPER GENIUS", Color = Color3.fromRGB(255, 150, 55), Emit = 42 },
	{ Match = "PRODIGY", Name = "PRODIGY", Color = Color3.fromRGB(255, 185, 80), Emit = 38 },
	{ Match = "GENIUS", Name = "GENIUS", Color = Color3.fromRGB(255, 230, 80), Emit = 34 },
	{ Match = "EXPERT", Name = "EXPERT", Color = Color3.fromRGB(170, 120, 255), Emit = 30 },
	{ Match = "ADVANCED", Name = "ADVANCED", Color = Color3.fromRGB(120, 135, 255), Emit = 26 },
	{ Match = "SKILLED", Name = "SKILLED", Color = Color3.fromRGB(95, 170, 255), Emit = 23 },
	{ Match = "SMART", Name = "SMART", Color = Color3.fromRGB(90, 220, 255), Emit = 20 },
	{ Match = "UNCOMMON", Name = "UNCOMMON", Color = Color3.fromRGB(120, 235, 150), Emit = 17 },
	{ Match = "COMMON", Name = "COMMON", Color = Color3.fromRGB(255, 255, 255), Emit = 12 },
}

local DEFAULT_COLOR = Color3.fromRGB(112, 255, 92)
local resultToken = 0
local resultActiveUntil = 0
local firstRollCompleted = false

local function findDescendantWithTimeout(root, name, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds

	repeat
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local map = Workspace:WaitForChild(MAP_NAME, MAP_WAIT_SECONDS)
if not map then
	warn("[RollWorldFeedback] SimpleMap missing; feedback disabled.")
	return
end

local rollButton = findDescendantWithTimeout(map, ROLL_BUTTON_NAME, MAP_WAIT_SECONDS)
if not rollButton or not rollButton:IsA("BasePart") then
	warn("[RollWorldFeedback] RollButton missing; feedback disabled.")
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", MAP_WAIT_SECONDS)
local popupEvent = remotes and remotes:WaitForChild("PopupEvent", MAP_WAIT_SECONDS)
if not popupEvent or not popupEvent:IsA("RemoteEvent") then
	warn("[RollWorldFeedback] PopupEvent missing; feedback disabled.")
	return
end

local oldFolder = map:FindFirstChild("ClientRollWorldFeedback")
if oldFolder then
	oldFolder:Destroy()
end

local feedbackFolder = Instance.new("Folder")
feedbackFolder.Name = "ClientRollWorldFeedback"
feedbackFolder.Parent = map

local highlight = Instance.new("Highlight")
highlight.Name = "RollButtonHighlight"
highlight.Adornee = rollButton
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillColor = DEFAULT_COLOR
highlight.FillTransparency = 0.78
highlight.OutlineColor = Color3.fromRGB(235, 255, 220)
highlight.OutlineTransparency = 0.18
highlight.Parent = feedbackFolder

local light = Instance.new("PointLight")
light.Name = "RollButtonGlow"
light.Color = DEFAULT_COLOR
light.Brightness = 1.15
light.Range = math.max(28, rollButton.Size.Magnitude * 1.2)
light.Shadows = false
light.Parent = rollButton

local attachment = Instance.new("Attachment")
attachment.Name = "RollFeedbackAttachment"
attachment.Position = Vector3.new(0, rollButton.Size.Y * 0.2, 0)
attachment.Parent = rollButton

local particles = Instance.new("ParticleEmitter")
particles.Name = "RollResultParticles"
particles.Enabled = false
particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
particles.Color = ColorSequence.new(DEFAULT_COLOR)
particles.LightEmission = 0.9
particles.LightInfluence = 0
particles.Lifetime = NumberRange.new(0.45, 0.85)
particles.Rate = 0
particles.Rotation = NumberRange.new(0, 360)
particles.RotSpeed = NumberRange.new(-140, 140)
particles.Speed = NumberRange.new(7, 14)
particles.SpreadAngle = Vector2.new(180, 180)
particles.Drag = 4
particles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55),
	NumberSequenceKeypoint.new(0.35, 0.9),
	NumberSequenceKeypoint.new(1, 0),
})
particles.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.05),
	NumberSequenceKeypoint.new(0.75, 0.15),
	NumberSequenceKeypoint.new(1, 1),
})
particles.Parent = attachment

local billboard = Instance.new("BillboardGui")
billboard.Name = "RollStartHereGui"
billboard.Adornee = rollButton
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.MaxDistance = 420
billboard.Size = UDim2.fromOffset(300, 92)
billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(16, rollButton.Size.Y * 0.85), 0)
billboard.Parent = feedbackFolder

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.fromScale(1, 1)
card.BackgroundColor3 = Color3.fromRGB(16, 24, 24)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = billboard

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = card

local stroke = Instance.new("UIStroke")
stroke.Name = "AccentStroke"
stroke.Color = DEFAULT_COLOR
stroke.Thickness = 3
stroke.Transparency = 0.05
stroke.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 10, 0, 7)
title.Size = UDim2.new(1, -20, 0, 43)
title.Font = Enum.Font.GothamBlack
title.Text = "START HERE"
title.TextColor3 = Color3.fromRGB(235, 255, 225)
title.TextScaled = true
title.TextStrokeTransparency = 0.68
title.Parent = card

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = 18
titleConstraint.MaxTextSize = 31
titleConstraint.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 10, 0, 49)
subtitle.Size = UDim2.new(1, -20, 0, 31)
subtitle.Font = Enum.Font.GothamBold
subtitle.Text = "TAP ROLL  •  R KEY"
subtitle.TextColor3 = Color3.fromRGB(205, 235, 215)
subtitle.TextScaled = true
subtitle.TextStrokeTransparency = 0.78
subtitle.Parent = card

local subtitleConstraint = Instance.new("UITextSizeConstraint")
subtitleConstraint.MinTextSize = 12
subtitleConstraint.MaxTextSize = 19
subtitleConstraint.Parent = subtitle

local function resolveEffect(text)
	local upperText = string.upper(tostring(text or ""))
	for _, effect in ipairs(RARITY_EFFECTS) do
		if string.find(upperText, effect.Match, 1, true) then
			return effect
		end
	end
	return {
		Name = "ROLL COMPLETE",
		Color = DEFAULT_COLOR,
		Emit = 16,
	}
end

local function extractRewardText(text)
	local upperText = string.upper(tostring(text or ""))
	local reward = string.match(upperText, "%+[%d%.,]+%s*[KMBTQ]*%s*IQ")
	return reward or "IQ GAINED"
end

local function tween(instance, duration, properties, easingStyle, easingDirection)
	local info = TweenInfo.new(
		duration,
		easingStyle or Enum.EasingStyle.Quad,
		easingDirection or Enum.EasingDirection.Out
	)
	local item = TweenService:Create(instance, info, properties)
	item:Play()
	return item
end

local function restoreIdleVisual(token)
	if token ~= resultToken then
		return
	end

	local idleTitle = firstRollCompleted and "ROLL AGAIN" or "START HERE"
	local idleSubtitle = firstRollCompleted and "BUILD YOUR IQ" or "TAP ROLL  •  R KEY"

	tween(highlight, 0.32, {
		FillColor = DEFAULT_COLOR,
		FillTransparency = 0.78,
		OutlineColor = Color3.fromRGB(235, 255, 220),
		OutlineTransparency = 0.18,
	})
	tween(light, 0.32, {
		Color = DEFAULT_COLOR,
		Brightness = 1.15,
		Range = math.max(28, rollButton.Size.Magnitude * 1.2),
	})
	tween(stroke, 0.32, {
		Color = DEFAULT_COLOR,
		Thickness = 3,
	})
	title.Text = idleTitle
	title.TextColor3 = Color3.fromRGB(235, 255, 225)
	subtitle.Text = idleSubtitle
	subtitle.TextColor3 = Color3.fromRGB(205, 235, 215)
end

local function playRollResult(text)
	resultToken += 1
	local token = resultToken
	local effect = resolveEffect(text)
	local rewardText = extractRewardText(text)

	firstRollCompleted = true
	resultActiveUntil = os.clock() + RESULT_HOLD_SECONDS + 0.45

	particles.Color = ColorSequence.new(effect.Color)
	particles:Emit(effect.Emit)

	title.Text = effect.Name
	title.TextColor3 = effect.Color
	subtitle.Text = rewardText
	subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)

	highlight.FillColor = effect.Color
	highlight.OutlineColor = effect.Color
	light.Color = effect.Color
	stroke.Color = effect.Color

	tween(highlight, 0.1, {
		FillTransparency = 0.28,
		OutlineTransparency = 0,
	}, Enum.EasingStyle.Back)
	tween(light, 0.1, {
		Brightness = 4.5,
		Range = math.max(42, rollButton.Size.Magnitude * 1.8),
	}, Enum.EasingStyle.Back)
	tween(stroke, 0.1, {
		Thickness = 6,
		Transparency = 0,
	}, Enum.EasingStyle.Back)
	tween(card, 0.1, {
		BackgroundTransparency = 0,
	}, Enum.EasingStyle.Back)

	task.delay(RESULT_HOLD_SECONDS, function()
		if token ~= resultToken then
			return
		end

		tween(card, 0.28, { BackgroundTransparency = 0.08 })
		restoreIdleVisual(token)
	end)
end

-- A restrained idle pulse keeps the central interaction readable without
-- modifying gameplay or creating a constant high-intensity effect.
task.spawn(function()
	local bright = false
	while rollButton.Parent and feedbackFolder.Parent do
		if os.clock() >= resultActiveUntil then
			bright = not bright
			local duration = bright and 0.85 or 1.05
			tween(light, duration, {
				Brightness = bright and 1.65 or 0.9,
			})
			tween(highlight, duration, {
				FillTransparency = bright and 0.7 or 0.84,
				OutlineTransparency = bright and 0.08 or 0.28,
			})
		end
		task.wait(0.9)
	end
end)

popupEvent.OnClientEvent:Connect(function(text, popupType)
	if tostring(popupType or "") == "Roll" then
		playRollResult(text)
	end
end)

print("[RollWorldFeedback] Connected button=" .. rollButton:GetFullName())
