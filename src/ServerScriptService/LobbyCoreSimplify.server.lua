-- ServerScriptService/LobbyCoreSimplify.server.lua
-- Keeps the first lobby focused on School, Quest, Chest, and Brain Quiz Hall.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local RETRY_COUNT = 20
local RETRY_DELAY = 0.25

local REMOVE_ROOT_NAMES = {
	SimulatorStructureUpgrade = true,
	WinPad_Plaza = true,
	WinPad_Plaza_Sign = true,
	TrainingDummy = true,
	RankingWall = true,
}

local REMOVE_LOBBY_FOLDERS = {
	ResearchArea = true,
	RankingArea = true,
	ShopArea = true,
	AttendanceArea = true,
}

local DECORATION_REMOVE_TOKENS = {
	"_Lamp_",
	"_Rock_",
	"_Flower",
	"_Fence",
}

local function containsToken(name, tokens)
	for _, token in ipairs(tokens) do
		if string.find(name, token, 1, true) then
			return true
		end
	end
	return false
end

local function destroyChildren(container)
	if not container then
		return 0
	end
	local count = 0
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
		count += 1
	end
	return count
end

local function simplifyMap(map)
	if not map or not map.Parent then
		return 0
	end
	local removed = 0

	for _, child in ipairs(map:GetChildren()) do
		if REMOVE_ROOT_NAMES[child.Name] then
			child:Destroy()
			removed += 1
		end
	end

	local world = map:FindFirstChild("World")
	local lobby = world and world:FindFirstChild("Lobby_Prestige0_School")
	if lobby then
		for folderName in pairs(REMOVE_LOBBY_FOLDERS) do
			local folder = lobby:FindFirstChild(folderName)
			removed += destroyChildren(folder)
		end

		local rollArea = lobby:FindFirstChild("RollArea")
		removed += destroyChildren(rollArea)

		local decorations = lobby:FindFirstChild("Decorations")
		if decorations then
			for _, descendant in ipairs(decorations:GetDescendants()) do
				if descendant.Parent and containsToken(descendant.Name, DECORATION_REMOVE_TOKENS) then
					descendant:Destroy()
					removed += 1
				end
			end
		end
	end

	local rollButton = map:FindFirstChild("RollButton", true)
	if rollButton and rollButton:IsA("BasePart") then
		rollButton.Transparency = 1
		rollButton.CanCollide = false
		rollButton.CanTouch = false
		rollButton.CanQuery = false
		rollButton.CastShadow = false
		rollButton:SetAttribute("VisualOnly", true)
	end

	map:SetAttribute("LobbyCoreSimplified", true)
	map:SetAttribute("LobbyCoreFocus", "SchoolQuestChestQuiz")
	return removed
end

local function attach(map)
	task.spawn(function()
		local totalRemoved = 0
		for _ = 1, RETRY_COUNT do
			if not map.Parent then
				return
			end
			totalRemoved += simplifyMap(map)
			task.wait(RETRY_DELAY)
		end
		print("[LobbyCoreSimplify] Ready focus=SchoolQuestChestQuiz removed=" .. tostring(totalRemoved))
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == MAP_NAME then
		attach(child)
	end
end)

local existingMap = Workspace:FindFirstChild(MAP_NAME)
if existingMap then
	attach(existingMap)
end
