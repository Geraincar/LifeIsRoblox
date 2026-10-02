local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--------------------------------------------------
-- UI
--------------------------------------------------

local mainUI =
	playerGui:WaitForChild(
		"MainUI"
	)


local lessonPanel =
	mainUI:WaitForChild(
		"WorldLessonPanel"
	)


local bottomRow =
	lessonPanel:WaitForChild(
		"BottomRow"
	)

local reopenButton =
	mainUI:WaitForChild(
		"WorldLessonReopenButton"
	)

--------------------------------------------------
-- MODULES
--------------------------------------------------

local LessonCatalog =
	require(
		ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("WorldLessons")
		:WaitForChild("LessonCatalog")
	)


local WorldLessonEngine =
	require(
		script.Parent:WaitForChild(
			"WorldLessonEngine"
		)
	)


local WorldLessonHUD =
	require(
		script.Parent:WaitForChild(
			"WorldLessonHUD"
		)
	)


local WorldLessonVisuals =
	require(
		script.Parent:WaitForChild(
			"WorldLessonVisuals"
		)
	)



--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local startRemote =
	remotes:WaitForChild(
		"WorldLessonStart"
	)


local completeRemote =
	remotes:WaitForChild(
		"WorldLessonComplete"
	)



--------------------------------------------------
-- HUD INIT
--------------------------------------------------

WorldLessonHUD.Initialize({

	Root =
		lessonPanel,

	StepLabel =
		lessonPanel:WaitForChild(
			"StepLabel"
		),

	TitleLabel =
		lessonPanel:WaitForChild(
			"TitleLabel"
		),

	InstructionLabel =
		lessonPanel:WaitForChild(
			"InstructionLabel"
		),

	StatusLabel =
		lessonPanel:WaitForChild(
			"StatusLabel"
		),

	ChoicesFrame =
		lessonPanel:WaitForChild(
			"ChoicesFrame"
		),

	HintButton =
		bottomRow:WaitForChild(
			"HintButton"
		),

	ResetButton =
		bottomRow:WaitForChild(
			"ResetButton"
		),

	ExitButton =
		bottomRow:WaitForChild(
			"ExitButton"
		),

	ReopenButton =
		reopenButton,

})



--------------------------------------------------
-- ENGINE CALLBACKS
--------------------------------------------------

WorldLessonEngine.Initialize({

	--------------------------------
	-- LESSON START
	--------------------------------

	OnLessonStarted =
		function(lesson)

			WorldLessonVisuals
			.ClearTransient()


			WorldLessonHUD
			.SetLesson(
				lesson.DisplayName
				or lesson.Id
			)


			WorldLessonHUD
			.Show()


			print(
				"World lesson started:",
				lesson.Id
			)

		end,


	--------------------------------
	-- STEP
	--------------------------------

	OnStepChanged =
		function(
			step,
			index,
			total
		)

		WorldLessonHUD
			.SetStep(
				index,
				total,
				step.Instruction
			)


		print(
			"STEP",
			index,
			"/",
			total,
			step.Instruction.Title
		)

	end,


	--------------------------------
	-- RESET
	--------------------------------

	OnStepReset =
		function()

			WorldLessonVisuals
			.ClearTransient()


			WorldLessonHUD
			.SetStatus(
				"Step reset."
			)

		end,


	--------------------------------
	-- EVENTS
	--------------------------------

	OnEvent =
		function(event)

			print(
				"Lesson event:",
				event.Type
			)


			if event.Type
				== "ObjectSelected"
			then

				WorldLessonHUD
				.SetStatus(
					"Object selected."
				)

			end


			if event.Type
				== "MeasurementStarted"
			then

				WorldLessonHUD
				.SetStatus(
					"Now select the second object."
				)

			end


			if event.Type
				== "MeasurementCompleted"
			then

				WorldLessonHUD
				.SetStatus(
					string.format(
						"Measured distance: %.2f",
						event.Distance
					)
				)

			end


			if event.Type
				== "ChoiceSelected"
			then

				WorldLessonHUD
				.SetStatus(
					"Selected: "
					.. tostring(
						event.OptionId
					)
				)

			end


			if event.Type
				== "HandleMoved"
			then

				WorldLessonHUD
				.SetStatus(
					string.format(
						"Value: %.2f",
						event.Offset
					)
				)

			end


			if event.Type
				== "DragStarted"
			then

				WorldLessonHUD
				.SetStatus(
					"Drag the object."
				)

			end


			if event.Type
				== "DragCompleted"
			then

				WorldLessonHUD
				.SetStatus(
					"Object placed."
				)

			end


			if event.Type
				== "ConnectionStarted"
			then

				WorldLessonHUD
				.SetStatus(
					"Select the second object."
				)

			end


			if event.Type
				== "ConnectionCompleted"
			then

				WorldLessonHUD
				.SetStatus(
					"Objects connected."
				)

			end

		end,


	--------------------------------
	-- COMPLETE
	--------------------------------

	OnLessonCompleted =
		function(lessonId)

			WorldLessonHUD
			.SetStatus(
				"Lesson complete."
			)


			completeRemote:FireServer(
				lessonId
			)


			task.delay(
				0.35,
				function()

					WorldLessonVisuals
					.ClearTransient()


					WorldLessonHUD
					.Hide()

				end
			)

		end,


	--------------------------------
	-- CANCEL
	--------------------------------

	OnLessonCancelled =
		function()

			WorldLessonVisuals
			.ClearTransient()


			WorldLessonHUD
			.Hide()

		end,

})



--------------------------------------------------
-- HUD BUTTONS
--------------------------------------------------

WorldLessonHUD
	.GetHintButton()
	.MouseButton1Click
	:Connect(function()

		WorldLessonHUD
		.ShowHint()

	end)



WorldLessonHUD
	.GetResetButton()
	.MouseButton1Click
	:Connect(function()

		WorldLessonEngine
		.ResetStep()

	end)



WorldLessonHUD
	.GetExitButton()
	.MouseButton1Click
	:Connect(function()

		WorldLessonEngine
		.CancelLesson()

	end)



--------------------------------------------------
-- START LESSON FROM SERVER
--------------------------------------------------

startRemote.OnClientEvent:Connect(
	function(lessonId)

		local lesson =
			LessonCatalog.Get(
				lessonId
			)


		if not lesson then

			warn(
				"Unknown world lesson:",
				lessonId
			)

			return

		end


		WorldLessonEngine
			.StartLesson(
				lesson
			)

	end
)