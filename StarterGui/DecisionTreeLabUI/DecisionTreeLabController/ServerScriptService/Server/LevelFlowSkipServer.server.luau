local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local ServerScriptService =
	game:GetService("ServerScriptService")


local skipRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"LevelFlowSkip"
		)


local LevelFlowService =
	require(
		ServerScriptService
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild(
				"LevelFlowService"
			)
	)


local locked = {}


skipRemote.OnServerEvent:Connect(
	function(player)

		if locked[player] then
			return
		end


		locked[player] =
			true


		LevelFlowService
			.SkipLesson(
				player
			)


		task.delay(
			0.8,
			function()

				locked[player] =
					nil

			end
		)

	end
)
