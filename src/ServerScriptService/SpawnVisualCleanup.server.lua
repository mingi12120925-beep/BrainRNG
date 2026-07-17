-- ServerScriptService/SpawnVisualCleanup.server.lua
-- Temporary cleanup: remove only the visible spawn platform pieces.
-- Keep PlayerSpawn and SpawnLocation so spawning and respawning remain reliable.

local Workspace = game:GetService("Workspace")

local MAP_NAME = "SimpleMap"
local WAIT_SECONDS = 30
local VISUAL_PART_NAMES = {
	"P0_SpawnPlatform",
	"P0_SpawnPlatformInset",
}

local map = Workspace:WaitForChild(MAP_NAME, WAIT_SECONDS)
if not map then
	warn("[SpawnVisualCleanup] SimpleMap missing; cleanup skipped.")
	return
end

local removed = 0
for _, partName in ipairs(VISUAL_PART_NAMES) do
	local item = map:FindFirstChild(partName, true)
	if item then
		item:Destroy()
		removed += 1
	end
end

local playerSpawn = map:FindFirstChild("PlayerSpawn", true)
local spawnLocation = map:FindFirstChild("SpawnLocation", true)

if not playerSpawn or not playerSpawn:IsA("BasePart") then
	warn("[SpawnVisualCleanup] PlayerSpawn missing after cleanup.")
end

if not spawnLocation or not spawnLocation:IsA("SpawnLocation") then
	warn("[SpawnVisualCleanup] SpawnLocation missing after cleanup.")
end

print("[SpawnVisualCleanup] Removed visible spawn structure parts=" .. tostring(removed))
