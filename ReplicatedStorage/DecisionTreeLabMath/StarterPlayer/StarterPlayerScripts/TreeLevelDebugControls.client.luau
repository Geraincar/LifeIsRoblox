local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local UserInputService =
	game:GetService("UserInputService")

local RunService =
	game:GetService("RunService")

--------------------------------------------------
-- ONLY ROBLOX STUDIO
--------------------------------------------------

if not RunService:IsStudio() then
	return
end

--------------------------------------------------
-- REMOTE
--------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local debugProgressRemote =
	remotes:WaitForChild(
		"TreeLevelDebugChangeProgress"
	)

--------------------------------------------------
-- INFO
--------------------------------------------------

print("================================")
print("[TreeLevelDebug] DEBUG ENABLED")
print("[TreeLevelDebug] K = NEXT")
print("[TreeLevelDebug] L = PREVIOUS")
print("================================")

--------------------------------------------------
-- CONTROLS
--------------------------------------------------

UserInputService.InputBegan:Connect(
	function(input, gameProcessed)

		if gameProcessed then
			return
		end

		--------------------------------------------------
		-- K = +1
		--------------------------------------------------

		if input.KeyCode == Enum.KeyCode.K then

			debugProgressRemote:FireServer(1)

			--------------------------------------------------
			-- L = -1
			--------------------------------------------------

		elseif input.KeyCode == Enum.KeyCode.L then

			debugProgressRemote:FireServer(-1)

		end
	end
)