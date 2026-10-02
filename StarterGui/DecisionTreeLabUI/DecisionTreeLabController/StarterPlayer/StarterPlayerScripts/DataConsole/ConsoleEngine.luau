local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local SceneDefinitions =
	require(
		ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("DataConsole")
		:WaitForChild("SceneDefinitions")
	)


local ViewRegistry =
	require(
		script.Parent
		:WaitForChild("Views")
		:WaitForChild("ViewRegistry")
	)

local ConsoleEngine = {}

ConsoleEngine.OnAction = nil
local ui = nil

local currentSceneId = nil

local history = {}


--------------------------------------------------
-- RENDER HELPERS
--------------------------------------------------

local function renderContext(scene)

	local context =
		scene.Context or {}


	ui.StepLabel.Text =
		context.Step or ""


	ui.HeadingLabel.Text =
		context.Heading or ""


	ui.BodyLabel.Text =
		context.Body or ""


	ui.HintLabel.Text =
		context.Hint or ""

end



local function renderMainView(scene)

	local view =
		scene.MainView


	if not view then
		return
	end


	ViewRegistry.Render(
		view.Type,
		ui,
		view
	)

end



local function renderMetrics(scene)

	local metrics =
		scene.Metrics or {}


	ui.MetricsTitle.Text =
		metrics.Title or ""


	ui.MetricsText.Text =
		metrics.Text or ""

end



--------------------------------------------------
-- SCENE
--------------------------------------------------

function ConsoleEngine.GoTo(
	sceneId,
	addToHistory
)

	local scene =
		SceneDefinitions.Get(sceneId)


	if not scene then

		warn(
			"Unknown Data Console scene:",
			sceneId
		)

		return

	end


	if addToHistory == nil then
		addToHistory = true
	end


	if (
		addToHistory
			and currentSceneId
		) then

		table.insert(
			history,
			currentSceneId
		)

	end


	currentSceneId =
		sceneId


	ui.TitleLabel.Text =
		scene.Title or "Data Console"


	ui.ModeLabel.Text =
		scene.Mode or ""


	renderContext(scene)

	renderMainView(scene)

	renderMetrics(scene)


	--------------------------------
	-- BACK
	--------------------------------

	ui.BackButton.Visible =
		scene.AllowBack == true
		and #history > 0


	--------------------------------
	-- PRIMARY ACTION
	--------------------------------

	local primary =
		scene.PrimaryAction


	if primary then

		ui.PrimaryButton.Visible = true

		ui.PrimaryButton.Text =
			primary.Label
			or "Continue"

	else

		ui.PrimaryButton.Visible = false

	end


	ui.StatusLabel.Text =
		scene.Id

end



--------------------------------------------------
-- NAVIGATION
--------------------------------------------------

function ConsoleEngine.Next()

	if not currentSceneId then
		return
	end


	local scene =
		SceneDefinitions.Get(
			currentSceneId
		)


	if not scene then
		return
	end


	local primary =
		scene.PrimaryAction


	if not primary then
		return
	end


	--------------------------------
	-- LOCAL NAVIGATION
	--------------------------------

	if primary.NextScene then

		ConsoleEngine.GoTo(
			primary.NextScene
		)

		return

	end


	--------------------------------
	-- GAME ACTION
	--------------------------------

	if primary.Action then

		if ConsoleEngine.OnAction then

			ConsoleEngine.OnAction(
				primary.Action,
				scene
			)

		else

			warn(
				"No ConsoleEngine.OnAction handler"
			)

		end


		return

	end

end



function ConsoleEngine.Back()

	local previousScene =
		table.remove(history)


	if not previousScene then
		return
	end


	ConsoleEngine.GoTo(
		previousScene,
		false
	)

end



--------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------

function ConsoleEngine.Open(
	sceneId
)
	history = {}

	ui.Root.Visible = true


	ConsoleEngine.GoTo(
		sceneId,
		false
	)

end



function ConsoleEngine.Close()

	ui.Root.Visible = false

end



function ConsoleEngine.GetCurrentSceneId()

	return currentSceneId

end



--------------------------------------------------
-- INIT
--------------------------------------------------

function ConsoleEngine.Initialize(
	uiReferences
)

	ui =
		uiReferences


	ui.PrimaryButton.MouseButton1Click
		:Connect(function()

			ConsoleEngine.Next()

		end)


	ui.BackButton.MouseButton1Click
		:Connect(function()

			ConsoleEngine.Back()

		end)


	ui.CloseButton.MouseButton1Click
		:Connect(function()

			ConsoleEngine.Close()

		end)

end



return ConsoleEngine