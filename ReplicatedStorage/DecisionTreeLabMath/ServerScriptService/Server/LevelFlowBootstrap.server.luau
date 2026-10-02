local service =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild(
				"LevelFlowService"
			)
	)


service.Start()
