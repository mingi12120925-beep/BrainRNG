-- ServerScriptService/ProfileReleaseGuard.server.lua
-- Temporary shutdown-save guard.
-- Serializes DataManager.ReleaseProfile calls so PlayerRemoving and BindToClose
-- cannot save/release the same profile at the same time. It also keeps the
-- server alive until tracked profile releases have actually completed.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local WAIT_TIMEOUT_SECONDS = 25
local RECENT_SUCCESS_WINDOW_SECONDS = 8
local CLEANUP_DELAY_SECONDS = 30
local SHUTDOWN_START_GRACE_SECONDS = 0.15
local SHUTDOWN_RETRY_SECONDS = 1

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
			LastShutdownRequestAt = 0,
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

local function trackPlayer(player)
	-- Create the state before shutdown begins so BindToClose can still track a
	-- player after Players:GetPlayers() has already become empty.
	getReleaseState(player)
end

Players.PlayerAdded:Connect(function(player)
	local oldState = releaseStateByUserId[player.UserId]
	if oldState and oldState.Player ~= player then
		releaseStateByUserId[player.UserId] = nil
	end

	trackPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	trackPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	local state = getReleaseState(player)

	task.delay(CLEANUP_DELAY_SECONDS, function()
		local currentState = releaseStateByUserId[userId]
		if currentState == state and currentState and not currentState.InProgress then
			if not DataManager.IsLoaded(player) then
				releaseStateByUserId[userId] = nil
			end
		end
	end)
end)

local function countPendingReleases()
	local pending = 0

	for _, state in pairs(releaseStateByUserId) do
		local player = state.Player
		if state.InProgress then
			pending += 1
		elseif player and DataManager.IsLoaded(player) then
			pending += 1
		end
	end

	return pending
end

local function requestPendingShutdownReleases()
	local nowTime = os.clock()

	for _, state in pairs(releaseStateByUserId) do
		local player = state.Player
		local lastRequestAt = tonumber(state.LastShutdownRequestAt) or 0

		if player
			and DataManager.IsLoaded(player)
			and not state.InProgress
			and nowTime - lastRequestAt >= SHUTDOWN_RETRY_SECONDS
		then
			state.LastShutdownRequestAt = nowTime

			task.spawn(function()
				print("[ProfileReleaseGuard] Shutdown release requested player=" .. player.Name)
				local success, result = pcall(DataManager.ReleaseProfile, player)
				if not success then
					warn(
						"[ProfileReleaseGuard] Shutdown release error player="
							.. player.Name
							.. " error="
							.. tostring(result)
					)
				elseif not result then
					warn("[ProfileReleaseGuard] Shutdown release returned false player=" .. player.Name)
				end
			end)
		end
	end
end

game:BindToClose(function()
	local deadline = os.clock() + WAIT_TIMEOUT_SECONDS
	local lastPending = nil

	-- Give PlayerRemoving and GameServer's BindToClose callback a brief chance
	-- to start their normal release path before this guard requests one itself.
	task.wait(SHUTDOWN_START_GRACE_SECONDS)

	while os.clock() < deadline do
		requestPendingShutdownReleases()

		local pending = countPendingReleases()
		if pending == 0 then
			print("[ProfileReleaseGuard] Shutdown releases complete")
			return
		end

		if pending ~= lastPending then
			print("[ProfileReleaseGuard] Waiting for shutdown releases pending=" .. tostring(pending))
			lastPending = pending
		end

		task.wait(0.05)
	end

	warn(
		"[ProfileReleaseGuard] Shutdown wait timed out pending="
			.. tostring(countPendingReleases())
	)
end)

print("[ProfileReleaseGuard] Installed")
