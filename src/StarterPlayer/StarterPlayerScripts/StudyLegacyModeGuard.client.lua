local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local deadline = os.clock() + 15
while ReplicatedStorage:GetAttribute("BrainRNG_GameMode") ~= "StudySimulator" and os.clock() < deadline do
	task.wait(0.1)
end

if ReplicatedStorage:GetAttribute("BrainRNG_GameMode") ~= "StudySimulator" then
	return
end

local guarded = setmetatable({}, { __mode = "k" })

local function guard(gui)
	if not gui:IsA("ScreenGui") or gui.Name == "BrainStudyHUD" or guarded[gui] then
		return
	end
	guarded[gui] = true

	local applying = false
	local function disable()
		if applying or not gui.Parent then
			return
		end
		if gui.Enabled then
			applying = true
			gui.Enabled = false
			applying = false
		end
	end

	disable()
	gui:GetPropertyChangedSignal("Enabled"):Connect(disable)
end

for _, child in ipairs(playerGui:GetChildren()) do
	guard(child)
end
playerGui.ChildAdded:Connect(function(child)
	task.defer(guard, child)
end)
