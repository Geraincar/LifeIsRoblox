local Players =
	game:GetService("Players")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local mainUI =
	playerGui:WaitForChild(
		"MainUI"
	)


local root =
	mainUI:WaitForChild(
		"DataPanel"
	)


local topBar =
	root:WaitForChild(
		"TopBar"
	)


local body =
	root:WaitForChild(
		"Body"
	)


local contextPanel =
	body:WaitForChild(
		"ContextPanel"
	)


local mainView =
	body:WaitForChild(
		"MainView"
	)


local sidePanel =
	body:WaitForChild(
		"SidePanel"
	)


local bottomBar =
	root:WaitForChild(
		"BottomBar"
	)


local ConsoleEngine =
	require(
		script.Parent:WaitForChild(
			"ConsoleEngine"
		)
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local requestRemote =
	remotes:WaitForChild(
		"DataConsoleRequest"
	)


local openRemote =
	remotes:WaitForChild(
		"DataConsoleOpen"
	)


local actionRemote =
	remotes:WaitForChild(
		"DataConsoleAction"
	)

local hud =
	mainUI:WaitForChild(
		"HUD"
	)


local openDataButton =
	hud:WaitForChild(
		"OpenDataButton"
	)

ConsoleEngine.Initialize({

	Root = root,


	TitleLabel =
		topBar:WaitForChild(
			"TitleLabel"
		),

	ModeLabel =
		topBar:WaitForChild(
			"ModeLabel"
		),

	CloseButton =
		topBar:WaitForChild(
			"CloseButton"
		),


	StepLabel =
		contextPanel:WaitForChild(
			"StepLabel"
		),

	HeadingLabel =
		contextPanel:WaitForChild(
			"HeadingLabel"
		),

	BodyLabel =
		contextPanel:WaitForChild(
			"BodyLabel"
		),

	HintLabel =
		contextPanel:WaitForChild(
			"HintLabel"
		),
	

	ViewHost =
		mainView:WaitForChild(
			"ViewHost"
		),

	PlaceholderLabel =
		mainView
		:WaitForChild("ViewHost")
		:WaitForChild("PlaceholderLabel"),


	MetricsTitle =
		sidePanel:WaitForChild(
			"MetricsTitle"
		),

	MetricsText =
		sidePanel:WaitForChild(
			"MetricsText"
		),


	BackButton =
		bottomBar:WaitForChild(
			"BackButton"
		),

	StatusLabel =
		bottomBar:WaitForChild(
			"StatusLabel"
		),

	PrimaryButton =
		bottomBar:WaitForChild(
			"PrimaryButton"
		),

})

ConsoleEngine.OnAction =
	function(actionId)

		actionRemote:FireServer(
			actionId
		)

	end

openRemote.OnClientEvent:Connect(
	function(sceneId)

		ConsoleEngine.Open(
			sceneId
		)

	end
)

openDataButton.MouseButton1Click
	:Connect(function()

		requestRemote:FireServer()

	end)

