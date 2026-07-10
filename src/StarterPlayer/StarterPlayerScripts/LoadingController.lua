local LoadingController = {}

local MIN_LOADING_TIME = 1.2
local MAX_LOADING_TIME = 12
local FADE_OUT_TIME = 0.35

local activeState = nil

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
	return corner
end

local function addTextConstraint(parent, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
	return constraint
end

local function tweenProgress(state, targetScale, duration)
	if not state.ProgressFill or state.Finished then
		return
	end

	targetScale = math.clamp(tonumber(targetScale) or 0, 0.06, 1)
	state.TweenService:Create(
		state.ProgressFill,
		TweenInfo.new(duration or 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(targetScale, 1) }
	):Play()
end

local function createLoadingScreen(state)
	local existing = state.PlayerGui:FindFirstChild("BrainRNG_LoadingGui")
	if existing then
		existing:Destroy()
	end

	state.Gui = Instance.new("ScreenGui")
	state.Gui.Name = "BrainRNG_LoadingGui"
	state.Gui.IgnoreGuiInset = true
	state.Gui.ResetOnSpawn = false
	state.Gui.DisplayOrder = 10000
	state.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	state.Gui.Enabled = true
	state.Gui.Parent = state.PlayerGui

	local background = Instance.new("Frame")
	background.Name = "LoadingBackground"
	background.Size = UDim2.fromScale(1, 1)
	background.Position = UDim2.fromScale(0, 0)
	background.BackgroundColor3 = Color3.fromRGB(12, 17, 30)
	background.BorderSizePixel = 0
	background.ZIndex = 100
	background.Parent = state.Gui

	state.GlowLeft = Instance.new("Frame")
	state.GlowLeft.Name = "GlowLeft"
	state.GlowLeft.AnchorPoint = Vector2.new(0.5, 0.5)
	state.GlowLeft.Position = UDim2.fromScale(0.22, 0.38)
	state.GlowLeft.Size = UDim2.fromOffset(420, 420)
	state.GlowLeft.BackgroundColor3 = Color3.fromRGB(64, 120, 255)
	state.GlowLeft.BackgroundTransparency = 0.82
	state.GlowLeft.BorderSizePixel = 0
	state.GlowLeft.ZIndex = 101
	state.GlowLeft.Parent = background
	addCorner(state.GlowLeft, UDim.new(1, 0))

	state.GlowRight = Instance.new("Frame")
	state.GlowRight.Name = "GlowRight"
	state.GlowRight.AnchorPoint = Vector2.new(0.5, 0.5)
	state.GlowRight.Position = UDim2.fromScale(0.68, 0.52)
	state.GlowRight.Size = UDim2.fromOffset(360, 360)
	state.GlowRight.BackgroundColor3 = Color3.fromRGB(137, 84, 255)
	state.GlowRight.BackgroundTransparency = 0.86
	state.GlowRight.BorderSizePixel = 0
	state.GlowRight.ZIndex = 101
	state.GlowRight.Parent = background
	addCorner(state.GlowRight, UDim.new(1, 0))

	state.Title = Instance.new("TextLabel")
	state.Title.Name = "GameTitle"
	state.Title.AnchorPoint = Vector2.new(0.5, 0.5)
	state.Title.Position = UDim2.fromScale(0.5, 0.39)
	state.Title.Size = UDim2.fromScale(0.75, 0.13)
	state.Title.BackgroundTransparency = 1
	state.Title.Text = "BRAIN RNG"
	state.Title.Font = Enum.Font.GothamBlack
	state.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
	state.Title.TextScaled = true
	state.Title.TextStrokeColor3 = Color3.fromRGB(50, 85, 180)
	state.Title.TextStrokeTransparency = 0.35
	state.Title.ZIndex = 103
	state.Title.Parent = background
	addTextConstraint(state.Title, 34, 72)

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.49)
	subtitle.Size = UDim2.fromScale(0.8, 0.05)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "ROLL. LEARN. EVOLVE."
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextColor3 = Color3.fromRGB(162, 191, 255)
	subtitle.TextScaled = true
	subtitle.ZIndex = 103
	subtitle.Parent = background
	addTextConstraint(subtitle, 14, 24)

	local progressBackground = Instance.new("Frame")
	progressBackground.Name = "ProgressBarBackground"
	progressBackground.AnchorPoint = Vector2.new(0.5, 0.5)
	progressBackground.Position = UDim2.fromScale(0.5, 0.66)
	progressBackground.Size = UDim2.fromScale(0.42, 0.018)
	progressBackground.BackgroundColor3 = Color3.fromRGB(39, 47, 68)
	progressBackground.BorderSizePixel = 0
	progressBackground.ZIndex = 103
	progressBackground.Parent = background
	addCorner(progressBackground, UDim.new(1, 0))

	local progressSizeConstraint = Instance.new("UISizeConstraint")
	progressSizeConstraint.MinSize = Vector2.new(230, 10)
	progressSizeConstraint.MaxSize = Vector2.new(520, 20)
	progressSizeConstraint.Parent = progressBackground

	state.ProgressFill = Instance.new("Frame")
	state.ProgressFill.Name = "ProgressFill"
	state.ProgressFill.Size = UDim2.fromScale(0.06, 1)
	state.ProgressFill.BackgroundColor3 = Color3.fromRGB(90, 155, 255)
	state.ProgressFill.BorderSizePixel = 0
	state.ProgressFill.ZIndex = 104
	state.ProgressFill.Parent = progressBackground
	addCorner(state.ProgressFill, UDim.new(1, 0))

	state.StatusLabel = Instance.new("TextLabel")
	state.StatusLabel.Name = "LoadingStatus"
	state.StatusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	state.StatusLabel.Position = UDim2.fromScale(0.5, 0.71)
	state.StatusLabel.Size = UDim2.fromScale(0.65, 0.045)
	state.StatusLabel.BackgroundTransparency = 1
	state.StatusLabel.Text = "Loading player data..."
	state.StatusLabel.Font = Enum.Font.GothamMedium
	state.StatusLabel.TextColor3 = Color3.fromRGB(205, 216, 240)
	state.StatusLabel.TextScaled = true
	state.StatusLabel.ZIndex = 103
	state.StatusLabel.Parent = background
	addTextConstraint(state.StatusLabel, 14, 22)

	print("[Loading] Screen shown")

	state.TweenService:Create(
		state.Title,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0.5, 0, 0.39, 5) }
	):Play()

	state.TweenService:Create(
		state.GlowLeft,
		TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.9 }
	):Play()

	state.TweenService:Create(
		state.GlowRight,
		TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.78 }
	):Play()
end

local function startStatusLoop(state)
	task.spawn(function()
		local statuses = {
			"Loading player data...",
			"Preparing concepts...",
			"Building your school...",
			"Almost ready...",
		}
		local index = 1

		while state.Gui and state.Gui.Parent and not state.ReadyReceived do
			if state.StatusLabel then
				state.StatusLabel.Text = statuses[index]
			end
			index = (index % #statuses) + 1
			task.wait(0.8)
		end
	end)
end

local function startProgressLoop(state)
	task.spawn(function()
		local stages = {
			{ Delay = 0, Progress = 0.06 },
			{ Delay = 0.5, Progress = 0.22 },
			{ Delay = 1.5, Progress = 0.48 },
			{ Delay = 3, Progress = 0.72 },
			{ Delay = MAX_LOADING_TIME, Progress = 0.88 },
		}
		local lastDelay = 0

		for _, stage in ipairs(stages) do
			if state.ReadyReceived or state.Finished then
				return
			end

			local waitTime = math.max(0, stage.Delay - lastDelay)
			lastDelay = stage.Delay
			if waitTime > 0 then
				task.wait(waitTime)
			end

			if state.ReadyReceived or state.Finished then
				return
			end

			tweenProgress(state, stage.Progress, 0.45)

			if stage.Delay == MAX_LOADING_TIME and state.StatusLabel then
				state.StatusLabel.Text = "Still loading..."
				task.wait(0.8)
				if not state.ReadyReceived and state.StatusLabel then
					state.StatusLabel.Text = "Please wait a moment."
				end
			end
		end

		task.wait(3)
		if not state.ReadyReceived and state.StatusLabel then
			state.StatusLabel.Text = "Loading is taking longer than expected."
		end
	end)
end

local function fadeOut(state)
	if state.Finished then
		return
	end

	state.Finished = true
	if not state.Gui or not state.Gui.Parent then
		return
	end

	local background = state.Gui:FindFirstChild("LoadingBackground")
	if background then
		for _, descendant in ipairs(background:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				state.TweenService:Create(descendant, TweenInfo.new(FADE_OUT_TIME), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
					BackgroundTransparency = 1,
				}):Play()
			elseif descendant:IsA("Frame") then
				state.TweenService:Create(descendant, TweenInfo.new(FADE_OUT_TIME), {
					BackgroundTransparency = 1,
				}):Play()
			elseif descendant:IsA("UIStroke") then
				state.TweenService:Create(descendant, TweenInfo.new(FADE_OUT_TIME), {
					Transparency = 1,
				}):Play()
			end
		end

		state.TweenService:Create(background, TweenInfo.new(FADE_OUT_TIME), {
			BackgroundTransparency = 1,
		}):Play()
	end

	task.wait(FADE_OUT_TIME)

	if state.Gui then
		state.Gui:Destroy()
		state.Gui = nil
	end

	print("[Loading] Fade out complete")
end

local function complete(state)
	if state.ReadyReceived then
		return
	end

	state.ReadyReceived = true
	print("[Loading] PlayerDataReady received")

	if state.StatusLabel then
		state.StatusLabel.Text = "Ready!"
	end
	tweenProgress(state, 1, 0.18)

	local elapsed = os.clock() - state.StartedAt
	if elapsed < MIN_LOADING_TIME then
		task.wait(MIN_LOADING_TIME - elapsed)
	end

	task.wait(0.15)
	fadeOut(state)
end

function LoadingController.Start(config)
	config = config or {}

	if activeState and activeState.Connection then
		activeState.Connection:Disconnect()
	end

	local state = {
		StartedAt = os.clock(),
		ReadyReceived = false,
		Finished = false,
		Gui = nil,
		ProgressFill = nil,
		StatusLabel = nil,
		Title = nil,
		GlowLeft = nil,
		GlowRight = nil,
		Player = config.Player,
		PlayerGui = config.PlayerGui,
		PlayerDataReady = config.PlayerDataReady,
		TweenService = config.TweenService,
		Connection = nil,
	}
	activeState = state

	if not state.Player or not state.PlayerGui or not state.PlayerDataReady or not state.TweenService then
		warn("[Loading] Missing LoadingController config")
		return
	end

	createLoadingScreen(state)
	startStatusLoop(state)
	startProgressLoop(state)

	state.Connection = state.PlayerDataReady.OnClientEvent:Connect(function()
		task.spawn(function()
			complete(state)
		end)
	end)

	if state.Player:GetAttribute("DataReady") == true then
		task.spawn(function()
			complete(state)
		end)
	end
end

return LoadingController
