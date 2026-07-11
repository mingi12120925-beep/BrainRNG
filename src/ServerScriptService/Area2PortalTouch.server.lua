-- ServerScriptService/Area2PortalTouch.server.lua
-- Temporary server-side touch portal patch.
-- Remove this file after the behavior is integrated into GameServer/SimpleWorldBuilder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameLogic = require(ServerScriptService:WaitForChild("GameLogic"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local MAP_NAME = "SimpleMap"
local REQUIRED_IQ = 10000
local PORTAL_LOCK_SECONDS = 1.5
local MAP_WAIT_SECONDS = 30

local lockedUntilByUserId = {}

local function showPopup(player, message)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local popupEvent = remotes and remotes:FindFirstChild("PopupEvent")

	if popupEvent and popupEvent:IsA("RemoteEvent") then
		popupEvent:FireClient(player, message, "Info")
	end
end

local function findDescendant(root, name)
	local deadline = os.clock() + MAP_WAIT_SECONDS

	repeat
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local function getCharacterFromHit(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not player or not player.Parent then
		return nil
	end

	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	if not root or not root:IsA("BasePart") then
		return nil
	end

	return player, character, root
end

local function tryLock(player)
	local nowTime = os.clock()
	local userId = player.UserId
	local lockedUntil = lockedUntilByUserId[userId] or 0

	if nowTime < lockedUntil then
		return false
	end

	lockedUntilByUserId[userId] = nowTime + PORTAL_LOCK_SECONDS
	return true
end

local function moveCharacter(character, root, targetCFrame)
	local success, moveError = pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(targetCFrame)

		task.defer(function()
			if root and root.Parent then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end)
	end)

	return success, moveError
end

local function makeTrigger(parent, name, triggerCFrame, triggerSize)
	local old = parent:FindFirstChild(name)
	if old and not old:IsA("BasePart") then
		old:Destroy()
		old = nil
	end

	local trigger = old or Instance.new("Part")
	trigger.Name = name
	trigger.Anchored = true
	trigger.CFrame = triggerCFrame
	trigger.Size = triggerSize
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger.CanQuery = false
	trigger.CastShadow = false
	trigger.Massless = true
	trigger.Parent = parent
	return trigger
end

local map = Workspace:WaitForChild(MAP_NAME, MAP_WAIT_SECONDS)
if not map then
	warn("[Area2PortalTouch] SimpleMap missing; touch portals not connected.")
	return
end

local entranceDoor = findDescendant(map, "NextAreaGate_Door")
local arrivalPad = findDescendant(map, "Area2ArrivalPad")
local returnPart = findDescendant(map, "Area2ReturnPromptPart") or findDescendant(map, "Area2ReturnPad")
local lobbySpawn = findDescendant(map, "PlayerSpawn") or findDescendant(map, "SpawnLocation")

if not entranceDoor or not entranceDoor:IsA("BasePart") then
	warn("[Area2PortalTouch] NextAreaGate_Door missing.")
	return
end

if not arrivalPad or not arrivalPad:IsA("BasePart") then
	warn("[Area2PortalTouch] Area2ArrivalPad missing.")
	return
end

if not returnPart or not returnPart:IsA("BasePart") then
	warn("[Area2PortalTouch] Area2 return part missing.")
	return
end

if not lobbySpawn or not lobbySpawn:IsA("BasePart") then
	warn("[Area2PortalTouch] PlayerSpawn/SpawnLocation missing.")
	return
end

local nextAreaPrompt = map:FindFirstChild("NextAreaPrompt", true)
if nextAreaPrompt and nextAreaPrompt:IsA("ProximityPrompt") then
	nextAreaPrompt.Enabled = false
end

local returnPrompt = map:FindFirstChild("Area2ReturnPrompt", true)
if returnPrompt and returnPrompt:IsA("ProximityPrompt") then
	returnPrompt.Enabled = false
end

local entranceTrigger = makeTrigger(
	entranceDoor.Parent,
	"Area2EntranceTrigger",
	entranceDoor.CFrame,
	Vector3.new(
		math.max(entranceDoor.Size.X + 4, 12),
		math.max(entranceDoor.Size.Y + 2, 16),
		math.max(entranceDoor.Size.Z + 6, 8)
	)
)

local returnTrigger = makeTrigger(
	returnPart.Parent,
	"Area2ReturnTrigger",
	returnPart.CFrame + Vector3.new(0, 3, 0),
	Vector3.new(
		math.max(returnPart.Size.X + 4, 16),
		8,
		math.max(returnPart.Size.Z + 4, 16)
	)
)

entranceTrigger.Touched:Connect(function(hit)
	local player, character, root = getCharacterFromHit(hit)
	if not player or not tryLock(player) then
		return
	end

	if not DataManager.IsLoaded(player) then
		showPopup(player, "PLEASE WAIT|Data is still loading")
		return
	end

	local currentIQ = math.max(0, math.floor(tonumber(GameLogic.GetIQ(player)) or 0))
	if currentIQ < REQUIRED_IQ then
		showPopup(player, "AREA LOCKED|Need 10.0K IQ")
		return
	end

	local moved, moveError = moveCharacter(character, root, arrivalPad.CFrame + Vector3.new(0, 5, 0))
	if not moved then
		warn("[Area2Portal] Enter failed player=" .. player.Name .. " error=" .. tostring(moveError))
		showPopup(player, "AREA UNAVAILABLE|Try again soon")
		return
	end

	print("[Area2Portal] Enter player=" .. player.Name)
	showPopup(player, "AREA 2 PREVIEW|Full area coming soon")
end)

returnTrigger.Touched:Connect(function(hit)
	local player, character, root = getCharacterFromHit(hit)
	if not player or not tryLock(player) then
		return
	end

	local moved, moveError = moveCharacter(character, root, lobbySpawn.CFrame + Vector3.new(0, 5, 0))
	if not moved then
		warn("[Area2Portal] Return failed player=" .. player.Name .. " error=" .. tostring(moveError))
		showPopup(player, "RETURN FAILED|Lobby spawn not found")
		return
	end

	print("[Area2Portal] Return player=" .. player.Name)
	showPopup(player, "LOBBY|Returned to lobby")
end)

Players.PlayerRemoving:Connect(function(player)
	lockedUntilByUserId[player.UserId] = nil
end)

print("[Area2PortalTouch] Connected entrance=" .. entranceTrigger:GetFullName() .. " return=" .. returnTrigger:GetFullName())
