local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local LessonCatalog =
	require(
		ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("WorldLessons")
		:WaitForChild("LessonCatalog")
	)


local LearningService =
	require(
		script.Parent.LearningService
	)


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


local dataConsoleOpen =
	remotes:WaitForChild(
		"DataConsoleOpen"
	)


local WorldLessonService = {}


function WorldLessonService.StartLesson(
	player,
	lessonId
)

	if not LessonCatalog.Exists(
		lessonId
		) then

		warn(
			"Unknown lesson:",
			lessonId
		)

		return false

	end


	startRemote:FireClient(
		player,
		lessonId
	)


	return true

end



function WorldLessonService.Start()

	completeRemote.OnServerEvent:Connect(
		function(
			player,
			lessonId
		)

			if type(lessonId)
				~= "string"
			then
				return
			end


			local lesson =
				LessonCatalog.Get(
					lessonId
				)


			if not lesson then
				return
			end


			LearningService.Complete(
				player,
				lessonId
			)


			print(
				"Server completed world lesson:",
				player.Name,
				lessonId
			)


			--------------------------------
			-- PART 1 → PART 2
			--------------------------------

			if lesson.NextConsoleScene then

				dataConsoleOpen:FireClient(
					player,
					lesson.NextConsoleScene
				)

			end

		end
	)


	print(
		"WorldLessonService started"
	)

end



return WorldLessonService