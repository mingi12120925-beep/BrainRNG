-- ServerScriptService/PlayerProgressionInvariant.server.lua
-- Brain RNG rule: progression values such as IQ must never resize the avatar or
-- change normal player movement. This server-authoritative guard keeps movement
-- fixed and restores the avatar's original Roblox appearance scale if another
-- script attempts to mutate it after spawning.

local Players = game:GetService("Players")

local FIXED_WALK_SPEED = 30
local FIXED_JUMP_POWER = 50
local FIXED_JUMP_HEIGHT = 7.2
local APPEARANCE_WAIT_SECONDS = 8

local SCALE_VALUE_NAMES = {
	BodyDepthScale = true,
	BodyHeightScale = true,
	BodyTypeScale = true,
	BodyWidthScale = true,
	HeadScale = true,
	ProportionScale = true,
}

local characterStates = setmetatable({}, { __mode = "k" })

local function enforceMovement(humanoid, state)
	if state.applyingMovement or not humanoid.Parent then
		return
	end

	state.applyingMovement = true
	if humanoid.WalkSpeed ~= FIXED_WALK_SPEED then
		humanoid.WalkSpeed = FIXED_WALK_SPEED
	end
	if humanoid.JumpPower ~= FIXED_JUMP_POWER then
		humanoid.JumpPower = FIXED_JUMP_POWER
	end
	if humanoid.JumpHeight ~= FIXED_JUMP_HEIGHT then
		humanoid.JumpHeight = FIXED_JUMP_HEIGHT
	end
	state.applyingMovement = false
end

local function connectMovementGuard(humanoid, state)
	for _, propertyName in ipairs({ "WalkSpeed", "JumpPower", "JumpHeight" }) do
		humanoid:GetPropertyChangedSignal(propertyName):Connect(function()
			task.defer(function()
				enforceMovement(humanoid, state)
			end)
		end)
	end
	enforceMovement(humanoid, state)
end

local function connectScaleValue(scaleValue, state)
	if state.scaleConnections[scaleValue] or not scaleValue:IsA("NumberValue") then
		return
	end

	local baseline = state.scaleBaselines[scaleValue.Name]
	if baseline == nil then
		baseline = scaleValue.Value
		state.scaleBaselines[scaleValue.Name] = baseline
	end

	state.scaleConnections[scaleValue] = scaleValue:GetPropertyChangedSignal("Value"):Connect(function()
		if state.applyingScale or not scaleValue.Parent then
			return
		end
		task.defer(function()
			if not scaleValue.Parent then
				return
			end
			local expected = state.scaleBaselines[scaleValue.Name]
			if expected ~= nil and math.abs(scaleValue.Value - expected) > 0.0001 then
				state.applyingScale = true
				scaleValue.Value = expected
				state.applyingScale = false
			end
		end)
	end)

	if math.abs(scaleValue.Value - baseline) > 0.0001 then
		state.applyingScale = true
		scaleValue.Value = baseline
		state.applyingScale = false
	end
end

local function captureAndGuardScales(humanoid, state)
	if state.scaleReady or not humanoid.Parent then
		return
	end

	state.scaleReady = true
	for _, child in ipairs(humanoid:GetChildren()) do
		if SCALE_VALUE_NAMES[child.Name] and child:IsA("NumberValue") then
			state.scaleBaselines[child.Name] = child.Value
		end
	end

	for _, child in ipairs(humanoid:GetChildren()) do
		if SCALE_VALUE_NAMES[child.Name] and child:IsA("NumberValue") then
			connectScaleValue(child, state)
		end
	end

	humanoid.ChildAdded:Connect(function(child)
		if SCALE_VALUE_NAMES[child.Name] and child:IsA("NumberValue") then
			task.defer(function()
				connectScaleValue(child, state)
			end)
		end
	end)
end

local function guardCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or characterStates[character] then
		return
	end

	local state = {
		applyingMovement = false,
		applyingScale = false,
		scaleReady = false,
		scaleBaselines = {},
		scaleConnections = setmetatable({}, { __mode = "k" }),
	}
	characterStates[character] = state

	connectMovementGuard(humanoid, state)

	task.spawn(function()
		local deadline = os.clock() + APPEARANCE_WAIT_SECONDS
		while character.Parent and not player:HasAppearanceLoaded() and os.clock() < deadline do
			task.wait(0.1)
		end
		captureAndGuardScales(humanoid, state)
	end)

	player:SetAttribute("ProgressionMovementLocked", true)
	player:SetAttribute("ProgressionAvatarScaleLocked", true)
	print(
		"[PlayerProgressionInvariant] Installed player="
			.. player.Name
			.. " walkSpeed="
			.. tostring(FIXED_WALK_SPEED)
			.. " statDrivenTransform=disabled"
	)
end

local function connectPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(guardCharacter, player, character)
	end)

	if player.Character then
		task.spawn(guardCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(connectPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	connectPlayer(player)
end

print("[PlayerProgressionInvariant] Ready")
