local service =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild(
				"HiveControlService"
			)
	)


service.Start()
