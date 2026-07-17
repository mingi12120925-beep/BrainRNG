local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("StudySimulatorRemotes")
local StateUpdated = remotes:WaitForChild("StateUpdated")
local PresentationEvent = remotes:WaitForChild("PresentationEvent")

local latest = nil

local function setModelVisible(model, visible)
	if not model then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = visible and 0 or 1
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = visible
		end
	end
end

local function refresh(payload)
	if type(payload) ~= "table" then
		return
	end
	latest = payload
	local root = Workspace:FindFirstChild("StudySimulatorWorld")
	if not root then
		return
	end
	for index, roomName in ipairs({ "KindergartenRoom", "ElementaryRoom" }) do
		local room = root:FindFirstChild(roomName)
		local partner = room and room:FindFirstChild("StudyPartner", true)
		local partnerDesk = room and room:FindFirstChild("PartnerStudyDesk", true)
		local isCurrentRoom = index == math.min(tonumber(payload.SchoolIndex) or 1, 2)
		setModelVisible(partner, payload.PartnerUnlocked == true and isCurrentRoom)
		if partnerDesk then
			for _, descendant in ipairs(partnerDesk:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					descendant.Enabled = payload.PartnerUnlocked == true and isCurrentRoom
				end
			end
		end
	end
end

StateUpdated.OnClientEvent:Connect(refresh)
PresentationEvent.OnClientEvent:Connect(function(kind, payload)
	if kind == "DataReady" then
		refresh(payload)
	end
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "StudySimulatorWorld" and latest then
		task.defer(refresh, latest)
	end
end)
