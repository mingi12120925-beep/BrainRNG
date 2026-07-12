-- ServerScriptService/PlayerProgressionInvariant.server.lua
-- Global movement is fixed; IQ never changes speed or avatar scale.

local Players = game:GetService("Players")

local FIXED_WALK_SPEED = 40
local FIXED_JUMP_POWER = 50
local FIXED_JUMP_HEIGHT = 7.2
local SCALE_NAMES = {
	BodyDepthScale = true,
	BodyHeightScale = true,
	BodyTypeScale = true,
	BodyWidthScale = true,
	HeadScale = true,
	ProportionScale = true,
}

local guardedCharacters = setmetatable({}, { __mode = "k" })

local function guardCharacter(player, character)
	if guardedCharacters[character] then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	guardedCharacters[character] = true

	local applyingMovement = false
	local function enforceMovement()
		if applyingMovement or not humanoid.Parent then
			return
		end
		applyingMovement = true
		humanoid.WalkSpeed = FIXED_WALK_SPEED
		humanoid.JumpPower = FIXED_JUMP_POWER
		humanoid.JumpHeight = FIXED_JUMP_HEIGHT
		applyingMovement = false
	end

	for _, propertyName in ipairs({ "WalkSpeed", "JumpPower", "JumpHeight" }) do
		humanoid:GetPropertyChangedSignal(propertyName):Connect(function()
			task.defer(enforceMovement)
		end)
	end
	enforceMovement()

	local baselines = {}
	local applyingScale = false
	local function guardScale(valueObject)
		if not valueObject:IsA("NumberValue") or not SCALE_NAMES[valueObject.Name] then
			return
		end
		if baselines[valueObject.Name] == nil then
			baselines[valueObject.Name] = valueObject.Value
		end
		valueObject:GetPropertyChangedSignal("Value"):Connect(function()
			if applyingScale or not valueObject.Parent then
				return
			end
			local expected = baselines[valueObject.Name]
			if expected ~= nil and math.abs(valueObject.Value - expected) > 0.0001 then
				applyingScale = true
				valueObject.Value = expected
				applyingScale = false
			end
		end)
	end

	task.spawn(function()
		local deadline = os.clock() + 8
		while character.Parent and not player:HasAppearanceLoaded() and os.clock() < deadline do
			task.wait(0.1)
		end
		for _, child in ipairs(humanoid:GetChildren()) do
			guardScale(child)
		end
		humanoid.ChildAdded:Connect(guardScale)
	end)

	player:SetAttribute("ProgressionMovementLocked", true)
	player:SetAttribute("ProgressionAvatarScaleLocked", true)
	print("[PlayerProgressionInvariant] Installed player=" .. player.Name .. " walkSpeed=40 statDrivenTransform=disabled")
end

local function bindPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(guardCharacter, player, character)
	end)
	if player.Character then
		task.spawn(guardCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

print("[PlayerProgressionInvariant] Ready fixedWalkSpeed=40")
