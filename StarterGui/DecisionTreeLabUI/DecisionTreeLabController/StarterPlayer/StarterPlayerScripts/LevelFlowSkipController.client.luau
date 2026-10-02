local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


local gui =
	player
		:WaitForChild("PlayerGui")
		:WaitForChild(
			"LevelFlowUI"
		)


local status =
	gui:WaitForChild(
		"Status"
	)


local skipButton =
	status:WaitForChild(
		"SkipButton"
	)


local skipRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"LevelFlowSkip"
		)


local locked =
	false



skipButton.MouseButton1Click
	:Connect(
		function()

			if locked then
				return
			end


			locked =
				true


			skipButton.Text =
				"..."


			skipRemote:FireServer()


			task.delay(
				1,
				function()

					locked =
						false


					if skipButton.Parent then

						skipButton.Text =
							"SKIP"

					end

				end
			)

		end
	)
