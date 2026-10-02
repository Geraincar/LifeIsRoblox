local Players =
	game:GetService("Players")


local ObjectResolver =
	require(
		script.Parent.Parent.ObjectResolver
	)


local WorldLessonVisuals =
	require(
		script.Parent.Parent.WorldLessonVisuals
	)


local MeasureDistance = {}



--------------------------------------------------
-- DISTANCE
--------------------------------------------------

local function calculateDistance(
	sourcePosition,
	targetPosition,
	axis
)

	if axis == "X" then

		return math.abs(
			targetPosition.X
			- sourcePosition.X
		)

	end


	if axis == "Y" then

		return math.abs(
			targetPosition.Y
			- sourcePosition.Y
		)

	end


	if axis == "Z" then

		return math.abs(
			targetPosition.Z
			- sourcePosition.Z
		)

	end


	-- Euclidean

	return (
		targetPosition
		- sourcePosition
	).Magnitude

end



--------------------------------------------------
-- START
--------------------------------------------------

function MeasureDistance.Start(
	context,
	definition
)

	local player =
		Players.LocalPlayer


	local mouse =
		player:GetMouse()


	local selectedSource =
		nil


	local connection



	connection =
		mouse.Button1Down:Connect(
			function()

				local target =
				mouse.Target


				if not target then
					return
				end


				local lessonObject =
				ObjectResolver
				.FindLessonObjectFromTarget(
					target
				)


				if not lessonObject then
					return
				end


				local objectId =
				lessonObject:GetAttribute(
					"LessonObjectId"
				)



				--------------------------------
				-- FIRST CLICK
				--------------------------------

				if not selectedSource then

					if definition.SourceId
						and objectId
						~= definition.SourceId
					then

						return

					end


					selectedSource =
					lessonObject



					--------------------------------
					-- VISUAL PREVIEW
					--------------------------------

					local targetObject =
					ObjectResolver.FindById(
						definition.TargetId
					)


					local sourcePosition =
					ObjectResolver.GetPosition(
						selectedSource
					)


					local targetPosition =
					ObjectResolver.GetPosition(
						targetObject
					)


					if sourcePosition
						and targetPosition
					then

						WorldLessonVisuals
						.ClearTransient()


						WorldLessonVisuals
						.Highlight(
							selectedSource,
							"MeasurementSource"
						)


						WorldLessonVisuals
						.Highlight(
							targetObject,
							"MeasurementTarget"
						)


						WorldLessonVisuals
						.DrawMeasurement(
							sourcePosition,
							targetPosition,
							definition.Axis,
							nil
						)

					end



					context.Emit({

						Type =
						"MeasurementStarted",

						ObjectId =
						objectId,

					})


					return

				end



				--------------------------------
				-- SECOND CLICK
				--------------------------------

				if definition.TargetId
					and objectId
					~= definition.TargetId
				then

					return

				end


				if lessonObject
					== selectedSource
				then

					return

				end



				local sourcePosition =
				ObjectResolver.GetPosition(
					selectedSource
				)


				local targetPosition =
				ObjectResolver.GetPosition(
					lessonObject
				)


				if not sourcePosition
					or not targetPosition
				then

					return

				end



				local distance =
				calculateDistance(
					sourcePosition,
					targetPosition,
					definition.Axis
					or "Euclidean"
				)



				--------------------------------
				-- FINAL VISUAL
				--------------------------------

				WorldLessonVisuals
				.ClearTransient()


				WorldLessonVisuals
				.Highlight(
					selectedSource,
					"MeasurementSource"
				)


				WorldLessonVisuals
				.Highlight(
					lessonObject,
					"MeasurementTarget"
				)


				WorldLessonVisuals
				.DrawMeasurement(
					sourcePosition,
					targetPosition,
					definition.Axis,
					distance
				)



				--------------------------------
				-- EVENT
				--------------------------------

				context.Emit({

					Type =
					"MeasurementCompleted",

					SourceId =
					selectedSource:GetAttribute(
						"LessonObjectId"
					),

					TargetId =
					objectId,

					Distance =
					distance,

				})

			end
		)



	--------------------------------
	-- HANDLER
	--------------------------------

	return {

		Reset = function()

			selectedSource =
				nil


			WorldLessonVisuals
				.ClearTransient()

		end,


		Stop = function()

			if connection then

				connection:Disconnect()

			end

		end,

	}

end



return MeasureDistance