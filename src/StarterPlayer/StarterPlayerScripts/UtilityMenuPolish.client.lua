-- StarterPlayer/StarterPlayerScripts/UtilityMenuPolish.client.lua
-- Keeps the existing right-side utility menu readable on every screen size.
-- No new UI is created. Text-heavy controls stay at native UIScale 1.0 so
-- Roblox does not blur them at fractional scales.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI_NAME = "BrainRNG_UI"
local FIND_TIMEOUT_SECONDS = 30
local RESPONSIVE_SCALE_NAME = "ResponsiveUILayoutScale"

local BUTTON_NAMES = {
	"IndexButton",
	"QuestButton",
	"ChestButton",
	"LuckButton",
	"AutoUpButton",
}

local MODE_CONFIG = {
	DESKTOP = {
		MenuWidth = 140,
		ButtonGap = 6,
		ButtonTextSize = 13,
		BadgeSize = 24,
		LuckWidth = 160,
		LuckHeight = 34,
		LuckTextSize = 18,
		RightMargin = 20,
		TopMargin = 16,
		MenuGap = 8,
	},
	COMPACT = {
		MenuWidth = 128,
		ButtonGap = 5,
		ButtonTextSize = 13,
		BadgeSize = 22,
		LuckWidth = 128,
		LuckHeight = 32,
		LuckTextSize = 16,
		RightMargin = 10,
		TopMargin = 10,
		MenuGap = 7,
	},
	NARROW = {
		MenuWidth = 112,
		ButtonGap = 4,
		ButtonTextSize = 13,
		BadgeSize = 20,
		LuckWidth = 112,
		LuckHeight = 30,
		LuckTextSize = 14,
		RightMargin = 7,
		TopMargin = 8,
		MenuGap = 7,
	},
	WIDE_SHORT = {
		MenuWidth = 140,
		ButtonGap = 6,
		ButtonTextSize = 13,
		BadgeSize = 24,
		LuckWidth = 140,
		LuckHeight = 30,
		LuckTextSize = 16,
		RightMargin = 10,
		TopMargin = 8,
		MenuGap = 7,
	},
	LANDSCAPE_COMPACT = {
		MenuWidth = 110,
		ButtonGap = 3,
		ButtonTextSize = 12,
		BadgeSize = 18,
		LuckWidth = 110,
		LuckHeight = 28,
		LuckTextSize = 13,
		RightMargin = 7,
		TopMargin = 6,
		MenuGap = 6,
	},
}

local activeGui = nil
local activeGuiConnection = nil
local cameraViewportConnection = nil
local lastMode = nil

local function resolveMode(viewport)
	if viewport.Y <= 500 then
		if viewport.X >= 850 then
			return "WIDE_SHORT"
		end

		return "LANDSCAPE_COMPACT"
	end

	if viewport.X <= 430 then
		return "NARROW"
	end

	if viewport.X <= 700 or viewport.Y <= 720 then
		return "COMPACT"
	end

	return "DESKTOP"
end

local function getTopInset()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)

	if not ok or not topLeft then
		return 0
	end

	return topLeft.Y
end

local function restoreNativeScale(guiObject)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return
	end

	local responsiveScale = guiObject:FindFirstChild(RESPONSIVE_SCALE_NAME)
	if responsiveScale and responsiveScale:IsA("UIScale") then
		responsiveScale.Scale = 1
	end
end

local function polishBadge(button, badgeName, badgeSize)
	if not button or not button:IsA("GuiObject") then
		return false
	end

	local badge = button:FindFirstChild(badgeName)
	if not badge or not badge:IsA("GuiObject") then
		return false
	end

	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -3, 0, -3)
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)

	if badge:IsA("TextLabel") or badge:IsA("TextButton") then
		badge.TextScaled = false
		badge.TextSize = math.max(12, badgeSize - 8)
	end

	return true
end

local function applyPolish()
	local screenGui = activeGui
	local camera = Workspace.CurrentCamera
	if not screenGui or not screenGui.Parent or not camera then
		return
	end

	local viewport = camera.ViewportSize
	local mode = resolveMode(viewport)
	local config = MODE_CONFIG[mode]
	local topInset = getTopInset()

	local luckBar = screenGui:FindFirstChild("LuckBar")
	if luckBar and luckBar:IsA("GuiObject") then
		restoreNativeScale(luckBar)
		luckBar.AnchorPoint = Vector2.new(1, 0)
		luckBar.Position = UDim2.new(1, -config.RightMargin, 0, topInset + config.TopMargin)
		luckBar.Size = UDim2.fromOffset(config.LuckWidth, config.LuckHeight)

		if luckBar:IsA("TextLabel") or luckBar:IsA("TextButton") then
			luckBar.TextScaled = false
			luckBar.TextSize = config.LuckTextSize
		end
	end

	local utilityMenu = screenGui:FindFirstChild("UtilityMenuFrame")
	local allButtonsReady = utilityMenu ~= nil
	if utilityMenu and utilityMenu:IsA("GuiObject") then
		restoreNativeScale(utilityMenu)

		local buttonHeight = 42
		local menuHeight = (#BUTTON_NAMES * buttonHeight) + ((#BUTTON_NAMES - 1) * config.ButtonGap) + 4
		local menuTop = topInset + config.TopMargin + config.LuckHeight + config.MenuGap

		utilityMenu.AnchorPoint = Vector2.new(1, 0)
		utilityMenu.Position = UDim2.new(1, -config.RightMargin, 0, menuTop)
		utilityMenu.Size = UDim2.fromOffset(config.MenuWidth, menuHeight)
		utilityMenu.ClipsDescendants = false

		for index, buttonName in ipairs(BUTTON_NAMES) do
			local button = utilityMenu:FindFirstChild(buttonName)
			if button and button:IsA("GuiButton") then
				button.AnchorPoint = Vector2.zero
				button.Position = UDim2.fromOffset(0, (index - 1) * (buttonHeight + config.ButtonGap))
				button.Size = UDim2.new(1, 0, 0, buttonHeight)
				button.TextScaled = false
				button.TextSize = config.ButtonTextSize
				button.TextWrapped = true
			else
				allButtonsReady = false
			end
		end

		local questButton = utilityMenu:FindFirstChild("QuestButton")
		local chestButton = utilityMenu:FindFirstChild("ChestButton")
		local questReady = polishBadge(questButton, "QuestReadyBadge", config.BadgeSize)
		local chestReady = polishBadge(chestButton, "ChestReadyBadge", config.BadgeSize)
		allButtonsReady = allButtonsReady and questReady and chestReady
	end

	if mode ~= lastMode and allButtonsReady and luckBar then
		lastMode = mode
		print(
			"[UtilityMenuPolish] Mode="
				.. mode
				.. " native-scale menu="
				.. tostring(config.MenuWidth)
				.. "px viewport="
				.. tostring(math.floor(viewport.X))
				.. "x"
				.. tostring(math.floor(viewport.Y))
		)
	end
end

local function schedulePolish()
	-- ResponsiveUILayout may apply fractional scales first. Re-apply after it so
	-- text-heavy menu controls always finish at native scale with integer sizes.
	task.defer(applyPolish)
	task.delay(0.06, applyPolish)
end

local function disconnectActiveGuiConnection()
	if activeGuiConnection then
		activeGuiConnection:Disconnect()
		activeGuiConnection = nil
	end
end

local function connectCamera()
	if cameraViewportConnection then
		cameraViewportConnection:Disconnect()
		cameraViewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(schedulePolish)
	end

	schedulePolish()
end

local function attach(screenGui)
	if not screenGui or not screenGui:IsA("ScreenGui") then
		return
	end

	if activeGui ~= screenGui then
		disconnectActiveGuiConnection()
		activeGui = screenGui
		lastMode = nil
		activeGuiConnection = screenGui.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "UtilityMenuFrame"
				or descendant.Name == "LuckBar"
				or descendant.Name == "QuestReadyBadge"
				or descendant.Name == "ChestReadyBadge"
			then
				schedulePolish()
			end
		end)
	end

	for _, delaySeconds in ipairs({ 0, 0.1, 0.35, 0.8 }) do
		task.delay(delaySeconds, applyPolish)
	end
end

local function findUi()
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS

	repeat
		local screenGui = playerGui:FindFirstChild(UI_NAME)
		if screenGui and screenGui:IsA("ScreenGui") then
			attach(screenGui)
			return
		end

		task.wait(0.1)
	until os.clock() >= deadline

	warn("[UtilityMenuPolish] BrainRNG_UI missing; polish disabled.")
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
connectCamera()

playerGui.ChildAdded:Connect(function(child)
	if child.Name == UI_NAME and child:IsA("ScreenGui") then
		attach(child)
	end
end)

findUi()
