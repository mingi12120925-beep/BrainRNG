local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("StudySimulatorRemotes")
local StateRequest = remotes:WaitForChild("StateRequest")

for attempt = 1, 8 do
	StateRequest:FireServer()
	task.wait(attempt <= 3 and 0.75 or 1.5)
end
