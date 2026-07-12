-- ServerScriptService/BrainQuizHallSpacing.server.lua
-- Keeps difficulty selection outside the entrance so choosing a level does not also start the quiz.

local Workspace = game:GetService("Workspace")

local adjustedHall = nil

local function adjustHall(hall)
	if not hall or not hall:IsA("Model") or hall == adjustedHall then
		return
	end

	local courtyard = hall:FindFirstChild("HallCourtyard")
	local trim = hall:FindFirstChild("HallTrim")
	if courtyard and courtyard:IsA("BasePart") then
		courtyard.Size = Vector3.new(courtyard.Size.X, courtyard.Size.Y, 96)
		courtyard.Position += Vector3.new(0, 0, 10)
	end
	if trim and trim:IsA("BasePart") then
		trim.Size = Vector3.new(trim.Size.X, trim.Size.Y, 98)
		trim.Position += Vector3.new(0, 0, 10)
	end

	for _, descendant in ipairs(hall:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if string.find(descendant.Name, "DifficultyDesk_", 1, true)
				or string.find(descendant.Name, "DifficultyTop_", 1, true)
				or string.find(descendant.Name, "DifficultyTrigger_", 1, true) then
				descendant.Position += Vector3.new(0, 0, 21)
			end
		end
	end

	hall:SetAttribute("DifficultyStartSeparated", true)
	adjustedHall = hall
	print("[BrainQuizHallSpacing] Applied difficultyOffsetZ=21 courtyardDepth=96 startOverlap=false")
end

local function findHall()
	local map = Workspace:FindFirstChild("SimpleMap")
	local hall = map and map:FindFirstChild("BrainQuizHall")
	if hall and hall:IsA("Model") then
		return hall
	end
	return nil
end

task.spawn(function()
	while true do
		local hall = findHall()
		if hall and hall ~= adjustedHall then
			task.wait(0.2)
			adjustHall(hall)
		elseif adjustedHall and not adjustedHall.Parent then
			adjustedHall = nil
		end
		task.wait(0.5)
	end
end)
