-- StarterPlayer/StarterPlayerScripts/ResponsiveUILayout.client.lua
-- Responsive layout for the existing Brain RNG screen UI only.
-- Project rule: never add floating world UI, BillboardGui, overlays, or extra labels.
-- This script only repositions existing frames and scales their parent containers.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI_NAME = "BrainRNG_UI"
local FIND_TIMEOUT_SECONDS = 30
local SCALE_NAME = "ResponsiveUILayoutScale"

local activeGui = nil
local guiChildConnection = nil
local cameraViewportConnection = nil
local playerGuiConnection = nil
local lastMode = nil

local function getInsets()
	local ok, topLeft, bottomRight = pcall(function()
		return GuiService:GetGuiInset()
	end)

	if not ok then
		return Vector2.zero, Vector2.zero
	end

	return topLeft or Vector2.zero, bottomRight or Vector2.zero
end

local function resolveMode(viewport)
	-- A short but wide desktop window should not be treated like a phone in
	-- landscape. The old height-only rule made the right menu unreadably small
	-- around 991x378 even though there was plenty of horizontal room.
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

local MODE_CONFIG = {
	DESKTOP = {
		UtilityScale = 1,
		ButtonScale = 1,
		TopScale = 1,
		PanelScale = 1,
		TutorialScale = 1,
		RouletteScale = 1,
		AdminScale = 1,
		RightMargin = 20,
		UtilityYScale = 0.5,
		BottomMargin = 26,
		SideMargin = 20,
		TopMargin = 16,
	},
	COMPACT = {
		UtilityScale = 0.84,
		ButtonScale = 0.96,
		TopScale = 0.9,
		PanelScale = 0.96,
		TutorialScale = 0.92,
		RouletteScale = 0.88,
		AdminScale = 0.92,
		RightMargin = 10,
		UtilityYScale = 0.48,
		BottomMargin = 18,
		SideMargin = 10,
		TopMargin = 10,
	},
	NARROW = {
		UtilityScale = 0.72,
		ButtonScale = 0.9,
		TopScale = 0.82,
		PanelScale = 0.9,
		TutorialScale = 0.82,
		RouletteScale = 0.78,
		AdminScale = 0.82,
		RightMargin = 7,
		UtilityYScale = 0.45,
		BottomMargin = 14,
		SideMargin = 8,
		TopMargin = 8,
	},
	WIDE_SHORT = {
		UtilityScale = 0.82,
		ButtonScale = 0.9,
		TopScale = 0.86,
		PanelScale = 0.84,
		TutorialScale = 0.8,
		RouletteScale = 0.78,
		AdminScale = 0.8,
		RightMargin = 10,
		UtilityYScale = 0.47,
		BottomMargin = 12,
		SideMargin = 10,
		TopMargin = 8,
	},
	LANDSCAPE_COMPACT = {
		UtilityScale = 0.68,
		ButtonScale = 0.82,
		TopScale = 0.78,
		PanelScale = 0.8,
		TutorialScale = 0.74,
		RouletteScale = 0.72,
		AdminScale = 0.74,
		RightMargin = 7,
		UtilityYScale = 0.46,
		BottomMargin = 10,
		SideMargin = 8,
		TopMargin = 6,
	},
}

local function ensureScale(guiObject)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return nil
	end

	local scale = guiObject:FindFirstChild(SCALE_NAME)
	if scale and not scale:IsA("UIScale") then
		scale:Destroy()
		scale = nil
	end

	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Scale = 1
		scale.Parent = guiObject
	end

	return scale
end

local function setScale(guiObject, value)
	local scale = ensureScale(guiObject)
	if scale then
		scale.Scale = value
	end
end

local function applyLayout()
	local screenGui = activeGui
	local camera = Workspace.CurrentCamera
	if not screenGui or not screenGui.Parent or not camera then
		return
	end

	local viewport = camera.ViewportSize
	local mode = resolveMode(viewport)
	local config = MODE_CONFIG[mode]
	local topLeftInset, bottomRightInset = getInsets()

	local utilityMenu = screenGui:FindFirstChild("UtilityMenuFrame")
	if utilityMenu and utilityMenu:IsA("GuiObject") then
		setScale(utilityMenu, config.UtilityScale)
		utilityMenu.AnchorPoint = Vector2.new(1, 0.5)
		utilityMenu.Position = UDim2.new(1, -config.RightMargin, config.UtilityYScale, 0)
	end

	local buttonFrame = screenGui:FindFirstChild("ButtonFrame")
	if buttonFrame and buttonFrame:IsA("GuiObject") then
		setScale(buttonFrame, config.ButtonScale)
		buttonFrame.AnchorPoint = Vector2.new(0.5, 1)
		buttonFrame.Position = UDim2.new(0.5, 0, 1, -(config.BottomMargin + bottomRightInset.Y))
	end

	local luckBar = screenGui:FindFirstChild("LuckBar")
	if luckBar and luckBar:IsA("GuiObject") then
		setScale(luckBar, config.TopScale)
		luckBar.AnchorPoint = Vector2.new(1, 0)
		luckBar.Position = UDim2.new(1, -config.RightMargin, 0, topLeftInset.Y + config.TopMargin)
	end

	for _, panelName in ipairs({ "IndexPanel", "QuestPanel", "ChestPanel" }) do
		local panel = screenGui:FindFirstChild(panelName)
		if panel and panel:IsA("GuiObject") then
			setScale(panel, config.PanelScale)
			panel.AnchorPoint = Vector2.new(0, 0.5)
			panel.Position = UDim2.new(0, config.SideMargin, 0.5, 0)
		end
	end

	local tutorialFrame = screenGui:FindFirstChild("TutorialFrame")
	if tutorialFrame and tutorialFrame:IsA("GuiObject") then
		setScale(tutorialFrame, config.TutorialScale)
		tutorialFrame.AnchorPoint = Vector2.new(0.5, 0)
		tutorialFrame.Position = UDim2.new(0.5, 0, 0, topLeftInset.Y + math.max(48, config.TopMargin + 36))
	end

	local rouletteFrame = screenGui:FindFirstChild("RouletteFrame")
	if rouletteFrame and rouletteFrame:IsA("GuiObject") then
		setScale(rouletteFrame, config.RouletteScale)
		rouletteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		rouletteFrame.Position = UDim2.new(0.5, 0, 0.42, 0)
	end

	local adminPanel = screenGui:FindFirstChild("AdminTestPanel")
	if adminPanel and adminPanel:IsA("GuiObject") then
		setScale(adminPanel, config.AdminScale)
		adminPanel.AnchorPoint = Vector2.new(0, 0.5)
		adminPanel.Position = UDim2.new(0, config.SideMargin, 0.5, 0)
	end

	if mode ~= lastMode then
		lastMode = mode
		print(
			"[ResponsiveUILayout] Mode="
				.. mode
				.. " viewport="
				.. tostring(math.floor(viewport.X))
				.. "x"
				.. tostring(math.floor(viewport.Y))
		)
	end
end

local function disconnectGuiConnection()
	if guiChildConnection then
		guiChildConnection:Disconnect()
		guiChildConnection = nil
	end
end

local function attachToGui(screenGui)
	if not screenGui or not screenGui:IsA("ScreenGui") then
		return
	end

	if activeGui == screenGui then
		applyLayout()
		return
	end

	disconnectGuiConnection()
	activeGui = screenGui
	lastMode = nil

	guiChildConnection = screenGui.ChildAdded:Connect(function()
		task.defer(applyLayout)
	end)

	-- UIController builds children over several frames. Re-apply a few times so
	-- every existing frame receives its layout without polling forever.
	for _, delaySeconds in ipairs({ 0, 0.1, 0.35, 0.8 }) do
		task.delay(delaySeconds, applyLayout)
	end
end

local function findAndAttachGui()
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS

	repeat
		local screenGui = playerGui:FindFirstChild(UI_NAME)
		if screenGui and screenGui:IsA("ScreenGui") then
			attachToGui(screenGui)
			return true
		end

		task.wait(0.1)
	until os.clock() >= deadline

	warn("[ResponsiveUILayout] BrainRNG_UI missing; responsive layout disabled.")
	return false
end

local function connectCamera()
	if cameraViewportConnection then
		cameraViewportConnection:Disconnect()
		cameraViewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	end

	applyLayout()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
connectCamera()

playerGuiConnection = playerGui.ChildAdded:Connect(function(child)
	if child.Name == UI_NAME and child:IsA("ScreenGui") then
		attachToGui(child)
	end
end)

findAndAttachGui()
