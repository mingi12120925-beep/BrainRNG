-- StarterPlayer/StarterPlayerScripts/RollWorldFeedback.client.lua
-- Temporary client-only Roll feedback.
-- Project rule: never create floating BillboardGui/world UI that can block the player's view.
-- This script only uses light, highlight, and short particle bursts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local MAP_WAIT_SECONDS = 30
local ROLL_BUTTON_NAME = "RollButton"
local RESULT_HOLD_SECONDS = 0.55

local DEFAULT_COLOR = Color3.fromRGB(112, 255, 92)
local IDLE_OUTLINE_COLOR = Color3.fromRGB(235, 255, 220)

local RARITY_EFFECTS = {
	{ Match = "REALITY BREAKER", Color = Color3.fromRGB(255, 255, 255), Emit = 45 },
	{ Match = "TRANSCENDENT", Color = Color3.fromRGB(95, 255, 235), Emit = 38 },
	{ Match = "IMPOSSIBLE", Color = Color3.fromRGB(255, 70, 95), Emit = 38 },
	{ Match = "SECRET", Color = Color3.fromRGB(255, 80, 180), Emit = 36 },
	{ Match = "MYTHIC", Color = Color3.fromRGB(220, 120, 255), Emit = 32 },
	{ Match = "LEGENDARY", Color = Color3.fromRGB(255, 210, 70), Emit = 30 },
	{ Match = "MASTERMIND", Color = Color3.fromRGB(255, 110, 80), Emit = 27 },
	{ Match = "SUPER GENIUS", Color = Color3.fromRGB(255, 150, 55), Emit = 24 },
	{ Match = "PRODIGY", Color = Color3.fromRGB(255, 185, 80), Emit = 22 },
	{ Match = "GENIUS", Color = Color3.fromRGB(255, 230, 80), Emit = 20 },
	{ Match = "EXPERT", Color = Color3.fromRGB(170, 120, 255), Emit = 18 },
	{ Match = "ADVANCED", Color = Color3.fromRGB(120, 135, 255), Emit = 16 },
	{ Match = "SKILLED", Color = Color3.fromRGB(95, 170, 255), Emit = 14 },
	{ Match = "SMART", Color = Color3.fromRGB(90, 220, 255), Emit = 12 },
	{ Match = "UNCOMMON", Color = Color3.fromRGB(120, 235, 150), Emit = 10 },
	{ Match = "COMMON", Color = Color3.fromRGB(255, 255, 255), Emit = 7 },
}

local resultToken = 0
local resultActiveUntil = 0

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

local function tween(instance, duration, properties, easingStyle, easingDirection)
	if not instance or not instance.Parent then
		return nil
	end

	local item = TweenService:Create(
		instance,
		TweenInfo.new(
			duration,
			easingStyle or Enum.EasingStyle.Quad,
			easingDirection or Enum.EasingDirection.Out
		),
		properties
	)
	item:Play()
	return item
end

local function resolveEffect(text)
	local upperText = string.upper(tostring(text or ""))

	for _, effect in ipairs(RARITY_EFFECTS) do
		if string.find(upperText, effect.Match, 1, true) then
			return effect
		end
	end

	return {
		Color = DEFAULT_COLOR,
		Emit = 9,
	}
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

-- Clear every visual instance from an earlier script version, including the
-- removed floating BillboardGui version and objects parented to RollButton.
local oldFolder = map:FindFirstChild("ClientRollWorldFeedback")
if oldFolder then
	oldFolder:Destroy()
end

for _, oldName in ipairs({ "RollButtonGlow", "RollFeedbackAttachment" }) do
	local oldInstance = rollButton:FindFirstChild(oldName)
	if oldInstance then
		oldInstance:Destroy()
	end
end

local feedbackFolder = Instance.new("Folder")
feedbackFolder.Name = "ClientRollWorldFeedback"
feedbackFolder.Parent = map

local highlight = Instance.new("Highlight")
highlight.Name = "RollButtonHighlight"
highlight.Adornee = rollButton
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillColor = DEFAULT_COLOR
highlight.FillTransparency = 0.82
highlight.OutlineColor = IDLE_OUTLINE_COLOR
highlight.OutlineTransparency = 0.22
highlight.Parent = feedbackFolder

local light = Instance.new("PointLight")
light.Name = "RollButtonGlow"
light.Color = DEFAULT_COLOR
light.Brightness = 0.9
light.Range = math.max(26, rollButton.Size.Magnitude * 1.1)
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
particles.LightEmission = 0.75
particles.LightInfluence = 0
particles.Lifetime = NumberRange.new(0.35, 0.65)
particles.Rate = 0
particles.Rotation = NumberRange.new(0, 360)
particles.RotSpeed = NumberRange.new(-100, 100)
particles.Speed = NumberRange.new(5, 10)
particles.SpreadAngle = Vector2.new(150, 150)
particles.Drag = 5
particles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.38),
	NumberSequenceKeypoint.new(0.35, 0.62),
	NumberSequenceKeypoint.new(1, 0),
})
particles.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.12),
	NumberSequenceKeypoint.new(0.7, 0.25),
	NumberSequenceKeypoint.new(1, 1),
})
particles.Parent = attachment

local function restoreIdleVisual(token)
	if token ~= resultToken then
		return
	end

	tween(highlight, 0.3, {
		FillColor = DEFAULT_COLOR,
		FillTransparency = 0.82,
		OutlineColor = IDLE_OUTLINE_COLOR,
		OutlineTransparency = 0.22,
	})
	tween(light, 0.3, {
		Color = DEFAULT_COLOR,
		Brightness = 0.9,
		Range = math.max(26, rollButton.Size.Magnitude * 1.1),
	})
end

local function playRollResult(text)
	resultToken += 1
	local token = resultToken
	local effect = resolveEffect(text)

	resultActiveUntil = os.clock() + RESULT_HOLD_SECONDS + 0.35
	particles.Color = ColorSequence.new(effect.Color)
	particles:Emit(effect.Emit)

	highlight.FillColor = effect.Color
	highlight.OutlineColor = effect.Color
	light.Color = effect.Color

	tween(highlight, 0.1, {
		FillTransparency = 0.38,
		OutlineTransparency = 0.02,
	}, Enum.EasingStyle.Back)
	tween(light, 0.1, {
		Brightness = 3.1,
		Range = math.max(38, rollButton.Size.Magnitude * 1.55),
	}, Enum.EasingStyle.Back)

	task.delay(RESULT_HOLD_SECONDS, function()
		restoreIdleVisual(token)
	end)
end

-- Subtle idle pulse only. No BillboardGui, floating text, screen overlay,
-- camera movement, or other view-blocking feedback is created here.
task.spawn(function()
	local bright = false

	while rollButton.Parent and feedbackFolder.Parent do
		if os.clock() >= resultActiveUntil then
			bright = not bright
			local duration = bright and 0.9 or 1.1

			tween(light, duration, {
				Brightness = bright and 1.2 or 0.72,
			})
			tween(highlight, duration, {
				FillTransparency = bright and 0.76 or 0.88,
				OutlineTransparency = bright and 0.14 or 0.3,
			})
		end

		task.wait(0.95)
	end
end)

popupEvent.OnClientEvent:Connect(function(text, popupType)
	if tostring(popupType or "") == "Roll" then
		playRollResult(text)
	end
end)

print("[RollWorldFeedback] Connected without floating UI button=" .. rollButton:GetFullName())