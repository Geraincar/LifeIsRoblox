local Players =
	game:GetService("Players")


local ObjectResolver =
	require(
		script.Parent.Parent.ObjectResolver
	)


local PressButton = {}


function PressButton.Start(
	context,
	definition
)

	local mouse =
		Players.LocalPlayer:GetMouse()


	local connection


	connection =
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


				if definition.TargetId
					and id
					~= definition.TargetId
				then

					return

				end


				context.Emit({

					Type =
					"ButtonPressed",

					ObjectId =
					id,

				})

			end
		)


	return {

		Stop = function()

			if connection then
				connection:Disconnect()
			end

		end,

	}

end


return PressButton