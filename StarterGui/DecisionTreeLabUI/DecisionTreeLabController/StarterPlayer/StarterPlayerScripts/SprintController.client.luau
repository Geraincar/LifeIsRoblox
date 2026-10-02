local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local WALK_SPEED = 16
local RUN_SPEED = 40

local humanoid = nil

local function setupCharacter(character)
	humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = WALK_SPEED
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift
		or input.KeyCode == Enum.KeyCode.RightShift then

		if humanoid then
			humanoid.WalkSpeed = RUN_SPEED
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift
		or input.KeyCode == Enum.KeyCode.RightShift then

		if humanoid then
			humanoid.WalkSpeed = WALK_SPEED
		end
	end
end)