local Players =
	game:GetService("Players")


local ObjectResolver =
	require(
		script.Parent.Parent.ObjectResolver
	)


local SelectObject = {}


function SelectObject.Start(
	context,
	definition
)

	local player =
		Players.LocalPlayer


	local mouse =
		player:GetMouse()


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
				-- TARGET ID FILTER
				--------------------------------

				if definition.TargetId then

					if objectId
						~= definition.TargetId
					then

						return

					end

				end


				--------------------------------
				-- ROLE FILTER
				--------------------------------

				if definition.Role then

					local role =
					lessonObject:GetAttribute(
						"LessonRole"
					)


					if role
						~= definition.Role
					then

						return

					end

				end


				context.Emit({

					Type =
					"ObjectSelected",

					ObjectId =
					objectId,

					Instance =
					lessonObject,

				})

			end
		)


	return {

		Stop = function()

			if connection then

				connection:Disconnect()

				connection = nil

			end

		end,

	}

end



return SelectObject