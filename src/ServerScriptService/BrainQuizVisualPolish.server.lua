-- ServerScriptService/BrainQuizVisualPolish.server.lua
-- High-contrast, non-neon world text for the Brain Quiz Arena.
-- Character overhead IQ/WINS UI remains an explicit exception.

local Workspace = game:GetService("Workspace")

local COLORS = {
	Platform = Color3.fromRGB(201, 207, 211),
	Trim = Color3.fromRGB(91, 101, 112),
	Start = Color3.fromRGB(91, 139, 104),
	A = Color3.fromRGB(166, 104, 109),
	B = Color3.fromRGB(88, 122, 153),
	C = Color3.fromRGB(172, 143, 86),
	Easy = Color3.fromRGB(96, 142, 107),
	Normal = Color3.fromRGB(169, 140, 83),
	Hard = Color3.fromRGB(157, 91, 96),
	Board = Color3.fromRGB(244, 241, 232),
	Plate = Color3.fromRGB(250, 248, 241),
	Text = Color3.fromRGB(24, 30, 37),
	Border = Color3.fromRGB(45, 52, 60),
}

local lastArena = nil

local function removeSurfaceText(part)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
end

local function addReadableText(part, face, text, usePlate)
	local surface = Instance.new("SurfaceGui")
	surface.Name = face.Name .. "ReadableText"
	surface.Face = face
	surface.LightInfluence = 1
	surface.PixelsPerStud = 70
	surface.AlwaysOnTop = false
	surface.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "ReadableLabel"
	label.Position = usePlate and UDim2.fromScale(0.08, 0.14) or UDim2.fromScale(0.04, 0.08)
	label.Size = usePlate and UDim2.fromScale(0.84, 0.72) or UDim2.fromScale(0.92, 0.84)
	label.BackgroundColor3 = COLORS.Plate
	label.BackgroundTransparency = usePlate and 0 or 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = COLORS.Text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = 1
	label.Parent = surface

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 18
	textConstraint.MaxTextSize = 42
	textConstraint.Parent = label

	if usePlate then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = COLORS.Border
		stroke.Transparency = 0
		stroke.Parent = label
	end
end

local function stylePad(part, color, labelText)
	if not part or not part:IsA("BasePart") then
		return
	end
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	removeSurfaceText(part)
	addReadableText(part, Enum.NormalId.Top, labelText, true)
end

local function polishArena(arena)
	if not arena or not arena:IsA("Model") then
		return
	end

	local platform = arena:FindFirstChild("ArenaPlatform")
	if platform and platform:IsA("BasePart") then
		platform.Material = Enum.Material.Concrete
		platform.Color = COLORS.Platform
	end

	local trim = arena:FindFirstChild("ArenaTrim")
	if trim and trim:IsA("BasePart") then
		trim.Material = Enum.Material.SmoothPlastic
		trim.Color = COLORS.Trim
	end

	stylePad(arena:FindFirstChild("QuizStartPad"), COLORS.Start, "START")
	stylePad(arena:FindFirstChild("AnswerPad_A"), COLORS.A, "A")
	stylePad(arena:FindFirstChild("AnswerPad_B"), COLORS.B, "B")
	stylePad(arena:FindFirstChild("AnswerPad_C"), COLORS.C, "C")
	stylePad(arena:FindFirstChild("DifficultyPad_Easy"), COLORS.Easy, "EASY\n75 SEC")
	stylePad(arena:FindFirstChild("DifficultyPad_Normal"), COLORS.Normal, "NORMAL\n60 SEC")
	stylePad(arena:FindFirstChild("DifficultyPad_Hard"), COLORS.Hard, "HARD\n45 SEC")

	local board = arena:FindFirstChild("QuizRulesBoard")
	if board and board:IsA("BasePart") then
		board.Material = Enum.Material.SmoothPlastic
		board.Color = COLORS.Board
		board.Size = Vector3.new(44, 7.5, 1.4)
		if platform and platform:IsA("BasePart") then
			board.Position = Vector3.new(
				platform.Position.X,
				platform.Position.Y + 6.4,
				platform.Position.Z + math.max(28, platform.Size.Z * 0.42)
			)
		end
		removeSurfaceText(board)
		addReadableText(board, Enum.NormalId.Front, "BRAIN QUIZ\n1 CORRECT = 1 WIN", false)
		addReadableText(board, Enum.NormalId.Back, "CHOOSE LEVEL\nSTEP ON START", false)
	end

	arena:SetAttribute("VisualPolishV3", true)
	print("[BrainQuizVisualPolish] Applied highContrast=true labelPlates=true compactBoard=true overheadUIException=true")
end

local function findArena()
	local map = Workspace:FindFirstChild("SimpleMap")
	local arena = map and map:FindFirstChild("BrainQuizArena")
	if arena and arena:IsA("Model") then
		return arena
	end
	return nil
end

task.spawn(function()
	while true do
		local arena = findArena()
		if arena and arena ~= lastArena then
			lastArena = arena
			task.wait(0.25)
			polishArena(arena)
		elseif lastArena and not lastArena.Parent then
			lastArena = nil
		end
		task.wait(0.5)
	end
end)
