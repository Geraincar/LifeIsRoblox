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


local ConnectObjects = {}


function ConnectObjects.Start(
	context,
	definition
)

	local mouse =
		Players.LocalPlayer:GetMouse()


	local first


	local connection =
		mouse.Button1Down:Connect(
			function()

				local object =
				ObjectResolver
				.FindLessonObjectFromTarget(
					mouse.Target
				)


				if not object then
					return
				end


				local id =
				object:GetAttribute(
					"LessonObjectId"
				)


				if not first then

					first =
					object


					context.Emit({

						Type =
						"ConnectionStarted",

						ObjectId =
						id,

					})


					return

				end


				if object == first then
					return
				end


				local firstId =
				first:GetAttribute(
					"LessonObjectId"
				)


				local p1 =
				ObjectResolver.GetPosition(
					first
				)


				local p2 =
				ObjectResolver.GetPosition(
					object
				)


				WorldLessonVisuals
				.DrawLine(
					p1,
					p2,
					nil,
					"Connection"
				)


				context.Emit({

					Type =
					"ConnectionCompleted",

					SourceId =
					firstId,

					TargetId =
					id,

				})


				first =
				nil

			end
		)


	return {

		Stop = function()

			connection:Disconnect()

		end,

	}

end


return ConnectObjects