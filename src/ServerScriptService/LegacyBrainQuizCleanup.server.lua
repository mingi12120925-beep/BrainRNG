-- ServerScriptService/LegacyBrainQuizCleanup.server.lua
-- Removes every remaining pre-Hall Brain Quiz object without touching BrainQuizHall.

local Workspace = game:GetService("Workspace")

local LEGACY_EXACT_NAMES = {
	BrainQuizArena = true,
	KnowledgeSprint = true,
	WinPad_Plaza = true,
	WinPad_Plaza_Sign = true,
	AnswerPad_A = true,
	AnswerPad_B = true,
	AnswerPad_C = true,
	QuizStartPad = true,
	DifficultyPad_Easy = true,
	DifficultyPad_Normal = true,
	DifficultyPad_Hard = true,
	QuizRulesBoard = true,
	ArenaPlatform = true,
	ArenaTrim = true,
}

local removedCount = 0

local function isInsideCurrentHall(instance)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == "BrainQuizHall" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isLegacy(instance)
	if not instance or not instance.Parent then
		return false
	end
	if isInsideCurrentHall(instance) then
		return false
	end
	if LEGACY_EXACT_NAMES[instance.Name] then
		return true
	end
	if instance:IsA("Model") and instance:GetAttribute("BrainQuizArenaInstalled") == true then
		return true
	end
	return false
end

local function removeLegacy(instance)
	if not isLegacy(instance) then
		return false
	end
	removedCount += 1
	print("[LegacyBrainQuizCleanup] Removed " .. instance:GetFullName())
	instance:Destroy()
	return true
end

local function cleanContainer(container)
	if not container or not container.Parent then
		return
	end

	local descendants = container:GetDescendants()
	for index = #descendants, 1, -1 do
		local instance = descendants[index]
		if instance.Parent then
			removeLegacy(instance)
		end
	end

	if container.Name == "SimpleMap" then
		container:SetAttribute("BrainQuizArenaInstalled", nil)
	end
end

local function cleanWorld()
	local map = Workspace:FindFirstChild("SimpleMap")
	if map then
		cleanContainer(map)
	else
		cleanContainer(Workspace)
	end
end

Workspace.DescendantAdded:Connect(function(instance)
	task.defer(function()
		if instance.Parent then
			removeLegacy(instance)
		end
	end)
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "SimpleMap" then
		task.delay(0.2, function()
			if child.Parent then
				cleanContainer(child)
			end
		end)
	end
end)

task.spawn(function()
	for _ = 1, 12 do
		cleanWorld()
		task.wait(0.5)
	end
	print("[LegacyBrainQuizCleanup] Ready removed=" .. tostring(removedCount) .. " hallProtected=true")
end)
