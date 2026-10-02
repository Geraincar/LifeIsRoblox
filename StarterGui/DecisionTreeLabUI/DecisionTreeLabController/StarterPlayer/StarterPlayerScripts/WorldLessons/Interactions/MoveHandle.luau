local Players =
	game:GetService("Players")

local UserInputService =
	game:GetService(
		"UserInputService"
	)


local ObjectResolver =
	require(
		script.Parent.Parent.ObjectResolver
	)


local MoveHandle = {}


local AXES = {

	X = Vector3.new(1, 0, 0),

	Y = Vector3.new(0, 1, 0),

	Z = Vector3.new(0, 0, 1),

}



function MoveHandle.Start(
	context,
	definition
)

	local player =
		Players.LocalPlayer


	local mouse =
		player:GetMouse()


	local handle =
		ObjectResolver.FindById(
			definition.TargetId
		)
	
	


	if not handle then

		warn(
			"MoveHandle target missing:",
			definition.TargetId
		)

		return nil

	end

	local initialPosition =
		ObjectResolver.GetPosition(
			handle
		)

	local dragging = false

	local startMouse

	local startPosition

	local currentOffset = 0


	local pixelsPerUnit =
		definition.PixelsPerUnit
		or 20


	local axis =
		AXES[
	definition.Axis
		or "Y"
	]


	local screenAxis =
		definition.ScreenAxis
		or "Y"


	local mouseDownConnection =
		mouse.Button1Down:Connect(
			function()

				local clicked =
				ObjectResolver
				.FindLessonObjectFromTarget(
					mouse.Target
				)


				if clicked ~= handle then
					return
				end


				dragging = true


				startMouse =
				Vector2.new(
					mouse.X,
					mouse.Y
				)


				startPosition =
				ObjectResolver
				.GetPosition(
					handle
				)

			end
		)


	local moveConnection =
		UserInputService
		.InputChanged
		:Connect(function(input)

			if not dragging then
				return
			end


			if input.UserInputType
				~= Enum.UserInputType.MouseMovement
			then

				return

			end


			local now =
			Vector2.new(
				mouse.X,
				mouse.Y
			)


			local delta =
			now - startMouse


			local pixels


			if screenAxis == "X" then

				pixels =
				delta.X

			else

				pixels =
				-delta.Y

			end


			currentOffset =
			pixels
			/ pixelsPerUnit


			if definition.MinOffset then

				currentOffset =
				math.max(
					currentOffset,
					definition.MinOffset
				)

			end


			if definition.MaxOffset then

				currentOffset =
				math.min(
					currentOffset,
					definition.MaxOffset
				)

			end


			local newPosition =
			startPosition
			+ axis
			* currentOffset


			ObjectResolver.SetPosition(
				handle,
				newPosition
			)


			context.Emit({

				Type =
				"HandleMoved",

				ObjectId =
				definition.TargetId,

				Offset =
				currentOffset,

			})

		end)


	local releaseConnection =
		UserInputService
		.InputEnded
		:Connect(function(input)

			if input.UserInputType
				~= Enum.UserInputType.MouseButton1
			then

				return

			end


			if dragging then

				dragging = false


				context.Emit({

					Type =
					"HandleReleased",

					ObjectId =
					definition.TargetId,

					Offset =
					currentOffset,

				})

			end

		end)


	return {

		Reset = function()

			dragging =
				false


			if initialPosition then

				ObjectResolver.SetPosition(
					handle,
					initialPosition
				)

			end

		end,


		Stop = function()

			mouseDownConnection
				:Disconnect()

			moveConnection
				:Disconnect()

			releaseConnection
				:Disconnect()

		end,

	}

end


return MoveHandle