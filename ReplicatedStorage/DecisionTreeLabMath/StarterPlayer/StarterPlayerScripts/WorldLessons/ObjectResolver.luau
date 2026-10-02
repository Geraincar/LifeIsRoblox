local Workspace =
	game:GetService("Workspace")


local ObjectResolver = {}

function ObjectResolver.SetPosition(
	instance,
	position
)

	if not instance then
		return
	end


	if instance:IsA(
		"BasePart"
		) then

		instance.Position =
			position

		return

	end


	if instance:IsA(
		"Model"
		) then

		local pivot =
			instance:GetPivot()


		local rotation =
			pivot
		- pivot.Position


		instance:PivotTo(
			CFrame.new(position)
				* rotation
		)

	end

end

function ObjectResolver.FindById(
	objectId
)

	for _, instance in ipairs(
		Workspace:GetDescendants()
		) do

		if instance:GetAttribute(
			"LessonObjectId"
			) == objectId then

			return instance

		end

	end


	return nil

end



function ObjectResolver.FindByRole(
	role
)

	local results = {}


	for _, instance in ipairs(
		Workspace:GetDescendants()
		) do

		if instance:GetAttribute(
			"LessonRole"
			) == role then

			table.insert(
				results,
				instance
			)

		end

	end


	return results

end



function ObjectResolver.FindLessonObjectFromTarget(
	target
)

	local current =
		target


	while current
		and current ~= Workspace
	do

		if current:GetAttribute(
			"LessonObjectId"
			) then

			return current

		end


		current =
			current.Parent

	end


	return nil

end



function ObjectResolver.GetPosition(
	instance
)

	if not instance then
		return nil
	end


	if instance:IsA(
		"BasePart"
		) then

		return instance.Position

	end


	if instance:IsA(
		"Attachment"
		) then

		return instance.WorldPosition

	end


	if instance:IsA(
		"Model"
		) then

		return instance:GetPivot().Position

	end


	return nil

end



return ObjectResolver