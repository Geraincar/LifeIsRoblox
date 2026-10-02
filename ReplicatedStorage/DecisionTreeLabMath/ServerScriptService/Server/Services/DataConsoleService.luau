local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local LearningService =
	require(
		script.Parent.LearningService
	)

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local requestRemote =
	remotes:WaitForChild("DataConsoleRequest")

local openRemote =
	remotes:WaitForChild("DataConsoleOpen")

local actionRemote =
	remotes:WaitForChild("DataConsoleAction")

local DataConsoleService = {}


--------------------------------------------------
-- ENTRY POINT
--------------------------------------------------

function DataConsoleService.GetEntryScene(
	player
)

	if not LearningService.IsCompleted(
		player,
		"console_intro"
		) then

		return "console_intro"

	end


	return "console_home"

end



function DataConsoleService.Open(
	player
)

	local sceneId =
		DataConsoleService.GetEntryScene(
			player
		)


	openRemote:FireClient(
		player,
		sceneId
	)

end



--------------------------------------------------
-- ACTIONS FROM SCENES
--------------------------------------------------

function DataConsoleService.HandleAction(
	player,
	actionId
)

	print(
		"Data Console action:",
		player.Name,
		actionId
	)


	if actionId
		== "complete_console_intro"
	then

		LearningService.Complete(
			player,
			"console_intro"
		)


		openRemote:FireClient(
			player,
			"console_home"
		)


		return

	end


	warn(
		"Unknown Data Console action:",
		actionId
	)

end



--------------------------------------------------
-- WORLD HIVE PROMPT
--------------------------------------------------

local function bindHivePrompt()

	-- Ожидаем модель:
	--
	-- Workspace
	-- └── Hive
	--     └── DataConsolePrompt

	local hive =
		Workspace:FindFirstChild(
			"Hive"
		)


	if not hive then

		warn(
			"DataConsoleService: "
				.. "Workspace.Hive not found"
		)

		return

	end


	local prompt =
		hive:FindFirstChild(
			"DataConsolePrompt",
			true
		)


	if not prompt then

		warn(
			"DataConsoleService: "
				.. "DataConsolePrompt not found in Hive"
		)

		return

	end


	if not prompt:IsA(
		"ProximityPrompt"
		) then

		warn(
			"DataConsolePrompt is not "
				.. "a ProximityPrompt"
		)

		return

	end


	prompt.Triggered:Connect(
		function(player)

			DataConsoleService.Open(
				player
			)

		end
	)

end



--------------------------------------------------
-- START
--------------------------------------------------

function DataConsoleService.Start()

	requestRemote.OnServerEvent:Connect(
		function(player)

			DataConsoleService.Open(
				player
			)

		end
	)


	actionRemote.OnServerEvent:Connect(
		function(
			player,
			actionId
		)

			if type(actionId)
				~= "string"
			then
				return
			end


			DataConsoleService.HandleAction(
				player,
				actionId
			)

		end
	)


	bindHivePrompt()


	print(
		"DataConsoleService started"
	)

end



return DataConsoleService