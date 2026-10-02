local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")


local ObjectResolver =
	require(
		script.Parent.Parent.ObjectResolver
	)


local DragObject = {}

local initialPositions = {}


local function getMousePlanePosition(
	mouse,
	height
)

	local camera =
		workspace.CurrentCamera


	local ray =
		camera:ViewportPointToRay(
			mouse.X,
			mouse.Y
		)


	if math.abs(
		ray.Direction.Y
		) < 0.001 then

		return nil

	end


	local t =
		(
			height
			- ray.Origin.Y
		)
		/ ray.Direction.Y


	if t < 0 then
		return nil
	end


	return ray.Origin
		+ ray.Direction
		* t

end



function DragObject.Start(
	context,
	definition
)

	local mouse =
		Players.LocalPlayer:GetMouse()


	local draggingObject

	local dragHeight


	local mouseDown =
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


				local role =
				object:GetAttribute(
					"LessonRole"
				)


				if definition.TargetId
					and id
					~= definition.TargetId
				then

					return

				end


				if definition.Role
					and role
					~= definition.Role
				then

					return

				end


				draggingObject = object
				
				local id =
				object:GetAttribute(
					"LessonObjectId"
				)


				if (
					id
					and not initialPositions[id]
					) then

					initialPositions[id] =
					ObjectResolver.GetPosition(
						object
					)

				end


				dragHeight =
				ObjectResolver
				.GetPosition(
					object
				).Y


				context.Emit({

					Type =
					"DragStarted",

					ObjectId =
					id,

				})

			end
		)


	local heartbeat =
		RunService.RenderStepped
		:Connect(function()

			if not draggingObject then
				return
			end


			local position =
			getMousePlanePosition(
				mouse,
				dragHeight
			)


			if not position then
				return
			end


			ObjectResolver.SetPosition(
				draggingObject,
				position
			)


			context.Emit({

				Type =
				"ObjectDragged",

				ObjectId =
				draggingObject:GetAttribute(
					"LessonObjectId"
				),

				Position =
				position,

			})

		end)


	local mouseUp =
		mouse.Button1Up:Connect(
			function()

				if not draggingObject then
					return
				end


				context.Emit({

					Type =
					"DragCompleted",

					ObjectId =
					draggingObject:GetAttribute(
						"LessonObjectId"
					),

					Position =
					ObjectResolver.GetPosition(
						draggingObject
					),

				})


				draggingObject =
				nil

			end
		)


	return {

		Reset = function()

			draggingObject =
				nil


			for id, position in pairs(
				initialPositions
				) do

				local object =
					ObjectResolver.FindById(
						id
					)


				if object then

					ObjectResolver.SetPosition(
						object,
						position
					)

				end

			end

		end,


		Stop = function()

			mouseDown:Disconnect()
			mouseUp:Disconnect()
			heartbeat:Disconnect()

		end,

	}

end


return DragObject