local Workspace =
	game:GetService("Workspace")


local WorldLessonVisuals = {}


--------------------------------------------------
-- STATE
--------------------------------------------------

local root = nil
local transientFolder = nil



--------------------------------------------------
-- ROOT
--------------------------------------------------

local function getRoot()

	if root
		and root.Parent
	then
		return root
	end


	root =
		Instance.new("Folder")


	root.Name =
		"WorldLessonVisuals"


	root.Parent =
		Workspace



	transientFolder =
		Instance.new("Folder")


	transientFolder.Name =
		"Transient"


	transientFolder.Parent =
		root


	return root

end



local function getTransientFolder()

	getRoot()


	if not transientFolder
		or not transientFolder.Parent
	then

		transientFolder =
			Instance.new("Folder")


		transientFolder.Name =
			"Transient"


		transientFolder.Parent =
			root

	end


	return transientFolder

end



--------------------------------------------------
-- CLEAR TEMPORARY VISUALS
--------------------------------------------------

function WorldLessonVisuals.ClearTransient()

	local folder =
		getTransientFolder()


	folder:ClearAllChildren()

end



--------------------------------------------------
-- HIGHLIGHT
--------------------------------------------------

function WorldLessonVisuals.Highlight(
	object,
	name
)

	if not object then
		return nil
	end


	local adornee =
		object


	-- Attachments themselves cannot be highlighted.
	if object:IsA("Attachment") then

		adornee =
			object.Parent

	end


	if not adornee then
		return nil
	end


	local highlight =
		Instance.new("Highlight")


	highlight.Name =
		name
		or "LessonHighlight"


	highlight.Adornee =
		adornee


	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop


	highlight.FillTransparency =
		0.65


	highlight.OutlineTransparency =
		0


	highlight.Parent =
		getTransientFolder()


	return highlight

end



--------------------------------------------------
-- DRAW LINE BETWEEN TWO WORLD POSITIONS
--------------------------------------------------

function WorldLessonVisuals.DrawLine(
	pointA,
	pointB,
	labelText,
	name
)

	if not pointA
		or not pointB
	then
		return nil
	end


	local delta =
		pointB - pointA


	local length =
		delta.Magnitude


	if length <= 0.001 then
		return nil
	end



	--------------------------------
	-- LINE
	--------------------------------

	local line =
		Instance.new("Part")


	line.Name =
		name
		or "LessonLine"


	line.Anchored =
		true


	line.CanCollide =
		false


	line.CanTouch =
		false


	line.CanQuery =
		false


	line.CastShadow =
		false


	line.Material =
		Enum.Material.Neon


	line.Size =
		Vector3.new(
			0.12,
			0.12,
			length
		)


	line.CFrame =
		CFrame.lookAt(
			(pointA + pointB) / 2,
			pointB
		)


	line.Parent =
		getTransientFolder()



	--------------------------------
	-- OPTIONAL LABEL
	--------------------------------

	if labelText ~= nil then

		local billboard =
			Instance.new(
				"BillboardGui"
			)


		billboard.Name =
			"MeasurementLabel"


		billboard.Size =
			UDim2.fromOffset(
				120,
				40
			)


		billboard.AlwaysOnTop =
			true


		billboard.StudsOffset =
			Vector3.new(
				0,
				0.7,
				0
			)


		billboard.Adornee =
			line


		billboard.Parent =
			line



		local label =
			Instance.new(
				"TextLabel"
			)


		label.Name =
			"Value"


		label.Size =
			UDim2.fromScale(
				1,
				1
			)


		label.BackgroundColor3 =
			Color3.fromRGB(
				25,
				26,
				32
			)


		label.BackgroundTransparency =
			0.15


		label.BorderSizePixel =
			0


		label.Text =
			tostring(
				labelText
			)


		label.TextColor3 =
			Color3.fromRGB(
				255,
				255,
				255
			)


		label.TextSize =
			18


		label.Font =
			Enum.Font.GothamBold


		label.Parent =
			billboard



		local corner =
			Instance.new(
				"UICorner"
			)


		corner.CornerRadius =
			UDim.new(
				0,
				8
			)


		corner.Parent =
			label

	end


	return line

end



--------------------------------------------------
-- DRAW MEASUREMENT
--------------------------------------------------

function WorldLessonVisuals.DrawMeasurement(
	sourcePosition,
	targetPosition,
	axis,
	distance
)

	if not sourcePosition
		or not targetPosition
	then
		return nil
	end


	local endPosition


	--------------------------------
	-- AXIS-SPECIFIC MEASUREMENT
	--------------------------------

	if axis == "X" then

		endPosition =
			Vector3.new(
				targetPosition.X,
				sourcePosition.Y,
				sourcePosition.Z
			)


	elseif axis == "Y" then

		endPosition =
			Vector3.new(
				sourcePosition.X,
				targetPosition.Y,
				sourcePosition.Z
			)


	elseif axis == "Z" then

		endPosition =
			Vector3.new(
				sourcePosition.X,
				sourcePosition.Y,
				targetPosition.Z
			)


	else

		-- Euclidean
		endPosition =
			targetPosition

	end



	--------------------------------
	-- LABEL
	--------------------------------

	local text


	if distance ~= nil then

		text =
			string.format(
				"%.2f",
				distance
			)

	else

		text =
			"?"

	end



	return WorldLessonVisuals.DrawLine(
		sourcePosition,
		endPosition,
		text,
		"Measurement"
	)

end



--------------------------------------------------
-- TARGET MARKER
--------------------------------------------------

function WorldLessonVisuals.ShowTargetMarker(
	position,
	name
)

	if not position then
		return nil
	end


	local marker =
		Instance.new("Part")


	marker.Name =
		name
		or "TargetMarker"


	marker.Shape =
		Enum.PartType.Ball


	marker.Size =
		Vector3.new(
			0.6,
			0.6,
			0.6
		)


	marker.Position =
		position


	marker.Anchored =
		true


	marker.CanCollide =
		false


	marker.CanTouch =
		false


	marker.CanQuery =
		false


	marker.CastShadow =
		false


	marker.Material =
		Enum.Material.Neon


	marker.Parent =
		getTransientFolder()


	return marker

end



--------------------------------------------------
-- VALUE LABEL ON OBJECT
--------------------------------------------------

function WorldLessonVisuals.ShowValueLabel(
	object,
	text
)

	if not object then
		return nil
	end


	local adornee =
		object


	if object:IsA("Model") then

		adornee =
			object.PrimaryPart
			or object:FindFirstChildWhichIsA(
				"BasePart",
				true
			)

	end


	if object:IsA("Attachment") then

		adornee =
			object.Parent

	end


	if not adornee
		or not adornee:IsA("BasePart")
	then
		return nil
	end



	local billboard =
		Instance.new("BillboardGui")


	billboard.Name =
		"LessonValueLabel"


	billboard.Size =
		UDim2.fromOffset(
			140,
			40
		)


	billboard.StudsOffset =
		Vector3.new(
			0,
			1.5,
			0
		)


	billboard.AlwaysOnTop =
		true


	billboard.Adornee =
		adornee


	billboard.Parent =
		getTransientFolder()



	local label =
		Instance.new("TextLabel")


	label.Size =
		UDim2.fromScale(
			1,
			1
		)


	label.BackgroundColor3 =
		Color3.fromRGB(
			25,
			26,
			32
		)


	label.BackgroundTransparency =
		0.15


	label.BorderSizePixel =
		0


	label.Text =
		tostring(text)


	label.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	label.TextSize =
		16


	label.Font =
		Enum.Font.GothamBold


	label.Parent =
		billboard



	local corner =
		Instance.new("UICorner")


	corner.CornerRadius =
		UDim.new(
			0,
			8
		)


	corner.Parent =
		label


	return billboard

end



return WorldLessonVisuals