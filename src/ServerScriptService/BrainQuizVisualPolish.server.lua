-- ServerScriptService/BrainQuizVisualPolish.server.lua
-- Screenshot-driven cleanup for the Brain Quiz Arena.
-- Keeps character overhead IQ/WINS UI as an explicit exception.

local Workspace = game:GetService("Workspace")

local MUTED = {
	Platform = Color3.fromRGB(192, 201, 207),
	Trim = Color3.fromRGB(96, 110, 124),
	Start = Color3.fromRGB(78, 137, 96),
	A = Color3.fromRGB(164, 91, 97),
	B = Color3.fromRGB(73, 111, 148),
	C = Color3.fromRGB(173, 139, 73),
	Easy = Color3.fromRGB(81, 140, 98),
	Normal = Color3.fromRGB(171, 139, 73),
	Hard = Color3.fromRGB(157, 80, 86),
	Board = Color3.fromRGB(52, 58, 66),
	Text = Color3.fromRGB(242, 242, 242),
}

local lastArena = nil

local function removeSurfaceText(part)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
end

local function addFlatText(part, face, text)
	local surface = Instance.new("SurfaceGui")
	surface.Name = face.Name .. "Text"
	surface.Face = face
	surface.LightInfluence = 1
	surface.PixelsPerStud = 55
	surface.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = MUTED.Text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = 1
	label.Parent = surface
end

local function stylePad(part, color)
	if not part or not part:IsA("BasePart") then
		return
	end
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			descendant.Font = Enum.Font.GothamBold
			descendant.TextStrokeTransparency = 1
			descendant.TextColor3 = MUTED.Text
		elseif descendant:IsA("SurfaceGui") then
			descendant.LightInfluence = 1
		end
	end
end

local function polishArena(arena)
	if not arena or not arena:IsA("Model") then
		return
	end

	local platform = arena:FindFirstChild("ArenaPlatform")
	if platform and platform:IsA("BasePart") then
		platform.Material = Enum.Material.Concrete
		platform.Color = MUTED.Platform
	end

	local trim = arena:FindFirstChild("ArenaTrim")
	if trim and trim:IsA("BasePart") then
		trim.Material = Enum.Material.SmoothPlastic
		trim.Color = MUTED.Trim
	end

	stylePad(arena:FindFirstChild("QuizStartPad"), MUTED.Start)
	stylePad(arena:FindFirstChild("AnswerPad_A"), MUTED.A)
	stylePad(arena:FindFirstChild("AnswerPad_B"), MUTED.B)
	stylePad(arena:FindFirstChild("AnswerPad_C"), MUTED.C)
	stylePad(arena:FindFirstChild("DifficultyPad_Easy"), MUTED.Easy)
	stylePad(arena:FindFirstChild("DifficultyPad_Normal"), MUTED.Normal)
	stylePad(arena:FindFirstChild("DifficultyPad_Hard"), MUTED.Hard)

	local board = arena:FindFirstChild("QuizRulesBoard")
	if board and board:IsA("BasePart") then
		board.Material = Enum.Material.SmoothPlastic
		board.Color = MUTED.Board
		board.Size = Vector3.new(48, 9, 1.4)
		if platform and platform:IsA("BasePart") then
			board.Position = Vector3.new(
				platform.Position.X,
				platform.Position.Y + 7.3,
				platform.Position.Z + math.max(28, platform.Size.Z * 0.42)
			)
		end
		removeSurfaceText(board)
		addFlatText(board, Enum.NormalId.Front, "BRAIN QUIZ\n+1 WIN PER CORRECT\nQUIZ AUTO BUTTON ON SCREEN")
		addFlatText(board, Enum.NormalId.Back, "CHOOSE DIFFICULTY\nSTEP ON START")
	end

	arena:SetAttribute("VisualPolishV2", true)
	print("[BrainQuizVisualPolish] Applied mutedColors=true compactBoard=true overheadUIException=true")
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
