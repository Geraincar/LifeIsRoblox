local Players =
	game:GetService("Players")


local ObjectResolver =
	require(
		script.Parent.Parent.ObjectResolver
	)


local PlaceInZone = {}


function PlaceInZone.Start(
	context,
	definition
)

	local player =
		Players.LocalPlayer


	local mouse =
		player:GetMouse()


	local selectedObject =
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


				local role =
				lessonObject:GetAttribute(
					"LessonRole"
				)


				--------------------------------
				-- SELECT OBJECT
				--------------------------------

				if not selectedObject then

					if role
						~= definition.ObjectRole
					then

						return

					end


					selectedObject =
					lessonObject


					context.Emit({

						Type =
						"PlacementStarted",

						ObjectId =
						objectId,

					})


					return

				end


				--------------------------------
				-- SELECT ZONE
				--------------------------------

				if role
					~= definition.ZoneRole
				then

					return

				end


				local selectedId =
				selectedObject:GetAttribute(
					"LessonObjectId"
				)


				context.Emit({

					Type =
					"ObjectPlaced",

					ObjectId =
					selectedId,

					ZoneId =
					objectId,

				})


				selectedObject =
				nil

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



return PlaceInZone