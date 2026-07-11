-- ServerScriptService/SpawnSafety.server.lua
-- Temporary server-side spawn correction.
-- Roblox can create a character before the generated map's SpawnLocation exists,
-- which may leave the character inside the central plaza structure. This script
-- assigns the generated SpawnLocation and safely repositions every new character.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local MAP_WAIT_SECONDS = 30
local CHARACTER_WAIT_SECONDS = 10
local INITIAL_SETTLE_SECONDS = 0.08
local SAFE_CLEARANCE_STUDS = 5
local VERIFY_DELAY_SECONDS = 0.35
local MAX_VERIFY_DISTANCE = 18

local characterVersionByUserId = {}

local function findDescendantWithTimeout(root, name, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds

	repeat
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end

		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local function resolveSpawnParts()
	local map = Workspace:FindFirstChild(MAP_NAME)
	if not map then
		map = Workspace:WaitForChild(MAP_NAME, MAP_WAIT_SECONDS)
	end

	if not map then
		return nil, nil, "SimpleMap missing"
	end

	local spawnLocation = findDescendantWithTimeout(map, "SpawnLocation", MAP_WAIT_SECONDS)
	if spawnLocation and not spawnLocation:IsA("SpawnLocation") then
		spawnLocation = nil
	end

	local anchor = map:FindFirstChild("PlayerSpawn", true)
	if not anchor or not anchor:IsA("BasePart") then
		anchor = spawnLocation
	end

	if not anchor or not anchor:IsA("BasePart") then
		anchor = map:FindFirstChild("P0_SpawnPlatform", true)
	end

	if not anchor or not anchor:IsA("BasePart") then
		return spawnLocation, nil, "safe spawn anchor missing"
	end

	return spawnLocation, anchor, nil
end

local function getSafeSpawnCFrame(anchor)
	local clearance = (anchor.Size.Y * 0.5) + SAFE_CLEARANCE_STUDS
	local position = anchor.Position + Vector3.new(0, clearance, 0)

	-- The lobby's forward direction is +Z, toward the Roll plaza and school gate.
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

local function clearVelocity(root)
	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function moveCharacterToSafeSpawn(player, character, root, anchor, version)
	if characterVersionByUserId[player.UserId] ~= version then
		return false
	end

	if player.Character ~= character or not character.Parent or not root.Parent then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local targetCFrame = getSafeSpawnCFrame(anchor)
	local success, moveError = pcall(function()
		clearVelocity(root)
		character:PivotTo(targetCFrame)
		clearVelocity(root)
	end)

	if not success then
		warn("[SpawnSafety] Failed player=" .. player.Name .. " error=" .. tostring(moveError))
		return false
	end

	return true, targetCFrame
end

local function handleCharacter(player, character)
	local userId = player.UserId
	local version = (characterVersionByUserId[userId] or 0) + 1
	characterVersionByUserId[userId] = version

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", CHARACTER_WAIT_SECONDS)
		local root = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS)

		if not humanoid or not root or not root:IsA("BasePart") then
			warn("[SpawnSafety] Character parts missing player=" .. player.Name)
			return
		end

		local spawnLocation, anchor, resolveError = resolveSpawnParts()
		if not anchor then
			warn("[SpawnSafety] " .. tostring(resolveError) .. " player=" .. player.Name)
			return
		end

		if spawnLocation then
			spawnLocation.Enabled = true
			player.RespawnLocation = spawnLocation
		end

		task.wait(INITIAL_SETTLE_SECONDS)

		local moved, targetCFrame = moveCharacterToSafeSpawn(player, character, root, anchor, version)
		if not moved then
			return
		end

		-- One delayed verification covers late physics resolution without repeatedly
		-- fighting normal player movement.
		task.delay(VERIFY_DELAY_SECONDS, function()
			if characterVersionByUserId[userId] ~= version then
				return
			end

			if player.Character ~= character or not root.Parent then
				return
			end

			local distance = (root.Position - targetCFrame.Position).Magnitude
			if distance > MAX_VERIFY_DISTANCE or root.Position.Y < targetCFrame.Position.Y - 8 then
				moveCharacterToSafeSpawn(player, character, root, anchor, version)
			end
		end)

		print(
			"[SpawnSafety] Positioned player="
				.. player.Name
				.. " anchor="
				.. anchor:GetFullName()
		)
	end)
end

local function handlePlayer(player)
	player.CharacterAdded:Connect(function(character)
		handleCharacter(player, character)
	end)

	if player.Character then
		handleCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(handlePlayer)

for _, player in ipairs(Players:GetPlayers()) do
	handlePlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	characterVersionByUserId[player.UserId] = nil
end)

print("[SpawnSafety] Ready")
