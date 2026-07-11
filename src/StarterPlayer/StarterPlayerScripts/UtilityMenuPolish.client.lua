-- StarterPlayer/StarterPlayerScripts/UtilityMenuPolish.client.lua
-- Keeps the existing right-side utility menu fully inside the screen.
-- No new UI is created; this script only adjusts existing elements.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI_NAME = "BrainRNG_UI"
local FIND_TIMEOUT_SECONDS = 30
local TARGET_MENU_HEIGHT = 240

local activeGui = nil
local activeGuiConnection = nil

local function polishBadge(button, badgeName)
	if not button or not button:IsA("GuiObject") then
		return false
	end

	local badge = button:FindFirstChild(badgeName)
	if not badge or not badge:IsA("GuiObject") then
		return false
	end

	-- Keep the badge inside the button boundary so it cannot be clipped by the
	-- right edge of the viewport on desktop or mobile.
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -4, 0, -4)
	badge.Size = UDim2.fromOffset(24, 24)

	if badge:IsA("TextLabel") or badge:IsA("TextButton") then
		badge.TextSize = 16
	end

	return true
end

local function applyPolish()
	local screenGui = activeGui
	if not screenGui or not screenGui.Parent then
		return
	end

	local utilityMenu = screenGui:FindFirstChild("UtilityMenuFrame")
	if utilityMenu and utilityMenu:IsA("GuiObject") then
		-- Five 42 px buttons at Y offsets 0, 48, 96, 144, 192 end at 234 px.
		-- Six extra pixels leave a small bottom pad without the long empty strip.
		utilityMenu.Size = UDim2.new(0, 140, 0, TARGET_MENU_HEIGHT)
		utilityMenu.ClipsDescendants = false
	end

	local questButton = utilityMenu and utilityMenu:FindFirstChild("QuestButton")
	local chestButton = utilityMenu and utilityMenu:FindFirstChild("ChestButton")

	local questReady = polishBadge(questButton, "QuestReadyBadge")
	local chestReady = polishBadge(chestButton, "ChestReadyBadge")

	if utilityMenu and questReady and chestReady and not utilityMenu:GetAttribute("UtilityMenuPolishLogged") then
		utilityMenu:SetAttribute("UtilityMenuPolishLogged", true)
		print("[UtilityMenuPolish] Applied safe badge positions and compact menu height")
	end
end

local function disconnectActiveGuiConnection()
	if activeGuiConnection then
		activeGuiConnection:Disconnect()
		activeGuiConnection = nil
	end
end

local function attach(screenGui)
	if not screenGui or not screenGui:IsA("ScreenGui") then
		return
	end

	if activeGui ~= screenGui then
		disconnectActiveGuiConnection()
		activeGui = screenGui
		activeGuiConnection = screenGui.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "UtilityMenuFrame"
				or descendant.Name == "QuestReadyBadge"
				or descendant.Name == "ChestReadyBadge"
			then
				task.defer(applyPolish)
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

playerGui.ChildAdded:Connect(function(child)
	if child.Name == UI_NAME and child:IsA("ScreenGui") then
		attach(child)
	end
end)

findUi()
