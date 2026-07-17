local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("StudySimulatorRemotes")
local StateRequest = remotes:WaitForChild("StateRequest")
local StateUpdated = remotes:WaitForChild("StateUpdated")
local receivedInitialState = false

StateUpdated.OnClientEvent:Connect(function()
	receivedInitialState = true
end)

local function requestState()
	StateRequest:FireServer()
end

player:GetAttributeChangedSignal("StudyQARefresh"):Connect(requestState)

for attempt = 1, 8 do
	if receivedInitialState then
		break
	end
	requestState()
	task.wait(attempt <= 3 and 0.75 or 1.5)
end
