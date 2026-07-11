-- ServerScriptService/ProfileReleaseGuard.server.lua
-- Temporary shutdown-save guard.
-- Serializes DataManager.ReleaseProfile calls so PlayerRemoving and BindToClose
-- cannot release/save the same profile at the same time.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local WAIT_TIMEOUT_SECONDS = 25
local RECENT_SUCCESS_WINDOW_SECONDS = 8
local CLEANUP_DELAY_SECONDS = 30

if DataManager.__ProfileReleaseGuardInstalled == true then
	warn("[ProfileReleaseGuard] Duplicate guard script blocked.")
	return
end

local originalReleaseProfile = DataManager.ReleaseProfile
if type(originalReleaseProfile) ~= "function" then
	warn("[ProfileReleaseGuard] DataManager.ReleaseProfile is missing; guard not installed.")
	return
end

DataManager.__ProfileReleaseGuardInstalled = true

local releaseStateByUserId = {}

local function getReleaseState(player)
	local userId = player.UserId
	local state = releaseStateByUserId[userId]

	if not state or state.Player ~= player then
		state = {
			Player = player,
			InProgress = false,
			LastSucceeded = false,
			LastFinishedAt = 0,
			AttemptCount = 0,
		}
		releaseStateByUserId[userId] = state
	end

	return state
end

local function waitForActiveRelease(player, state)
	local deadline = os.clock() + WAIT_TIMEOUT_SECONDS

	while state.InProgress and os.clock() < deadline do
		task.wait(0.05)
	end

	if state.InProgress then
		warn("[ProfileReleaseGuard] Timed out waiting for active release player=" .. player.Name)
		return false
	end

	return true
end

DataManager.ReleaseProfile = function(player)
	if not player then
		warn("[ProfileReleaseGuard] ReleaseProfile called without player.")
		return false
	end

	local state = getReleaseState(player)

	-- Re-check in a loop because more than one shutdown callback may be waiting.
	while state.InProgress do
		if not waitForActiveRelease(player, state) then
			return false
		end
	end

	local secondsSinceLastSuccess = os.clock() - (tonumber(state.LastFinishedAt) or 0)
	if state.LastSucceeded and secondsSinceLastSuccess <= RECENT_SUCCESS_WINDOW_SECONDS then
		print("[ProfileReleaseGuard] Duplicate release skipped player=" .. player.Name)
		return true
	end

	state.InProgress = true
	state.AttemptCount += 1

	local callSucceeded, releaseResult = pcall(originalReleaseProfile, player)

	state.InProgress = false
	state.LastFinishedAt = os.clock()
	state.LastSucceeded = callSucceeded and releaseResult == true

	if not callSucceeded then
		warn(
			"[ProfileReleaseGuard] ReleaseProfile error player="
				.. player.Name
				.. " error="
				.. tostring(releaseResult)
		)
		error(releaseResult, 0)
	end

	if not releaseResult then
		warn("[ProfileReleaseGuard] ReleaseProfile returned false player=" .. player.Name)
	end

	return releaseResult
end

Players.PlayerAdded:Connect(function(player)
	-- A rejoin is a new profile session even when the UserId is the same.
	local oldState = releaseStateByUserId[player.UserId]
	if oldState and oldState.Player ~= player then
		releaseStateByUserId[player.UserId] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	local state = releaseStateByUserId[userId]

	task.delay(CLEANUP_DELAY_SECONDS, function()
		local currentState = releaseStateByUserId[userId]
		if currentState == state and currentState and not currentState.InProgress then
			releaseStateByUserId[userId] = nil
		end
	end)
end)

print("[ProfileReleaseGuard] Installed")
