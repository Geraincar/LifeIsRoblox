local Players =
	game:GetService("Players")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)



--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function containsText(
	root,
	search
)

	search =
		string.lower(
			search
		)


	for _, object in ipairs(
		root:GetDescendants()
	) do

		if object:IsA("TextLabel")
			or object:IsA("TextButton")
		then

			local text =
				string.lower(
					object.Text or ""
				)


			if string.find(
				text,
				search,
				1,
				true
			)
			then

				return true

			end

		end

	end


	return false

end



local function findAncestorFrame(
	object,
	maxDepth
)

	local current =
		object


	for _ = 1, maxDepth or 6 do

		if not current then
			return nil
		end


		if current:IsA("Frame") then
			return current
		end


		current =
			current.Parent

	end


	return nil

end



local function findTextObject(
	root,
	search
)

	search =
		string.lower(
			search
		)


	for _, object in ipairs(
		root:GetDescendants()
	) do

		if object:IsA("TextLabel")
			or object:IsA("TextButton")
		then

			local text =
				string.lower(
					object.Text or ""
				)


			if string.find(
				text,
				search,
				1,
				true
			)
			then

				return object

			end

		end

	end


	return nil

end



--------------------------------------------------
-- FIND REGRESSION GUI
--------------------------------------------------

local function findRegressionGui()

	for _, gui in ipairs(
		playerGui:GetChildren()
	) do

		if gui:IsA("ScreenGui")
			and (
				containsText(
					gui,
					"где будет минимум mse"
				)
				or
				containsText(
					gui,
					"наклон +"
				)
			)
		then

			return gui

		end

	end


	return nil

end



--------------------------------------------------
-- FIND BET PANEL
--------------------------------------------------

local function findBetPanel(
	gui
)

	local question =
		findTextObject(
			gui,
			"где будет минимум mse"
		)


	if not question then
		return nil
	end


	local current =
		question.Parent


	--------------------------------
	-- Walk upwards until we find
	-- a substantial panel containing
	-- both the question and "Ставка".
	--------------------------------

	for _ = 1, 7 do

		if not current then
			break
		end


		if current:IsA("Frame")
			and containsText(
				current,
				"ставка"
			)
			and containsText(
				current,
				"где будет минимум mse"
			)
		then

			return current

		end


		current =
			current.Parent

	end


	return nil

end



--------------------------------------------------
-- FIND CONTROL BLOCK
--------------------------------------------------

local function findControlPanel(
	gui
)

	local slopeButton =
		findTextObject(
			gui,
			"наклон +"
		)


	if not slopeButton then
		return nil
	end


	local current =
		slopeButton.Parent


	for _ = 1, 7 do

		if not current then
			break
		end


		if current:IsA("Frame")
			and containsText(
				current,
				"наклон +"
			)
			and containsText(
				current,
				"ниже"
			)
		then

			return current

		end


		current =
			current.Parent

	end


	return nil

end



--------------------------------------------------
-- APPLY
--------------------------------------------------

local function apply()

	if player:GetAttribute(
		"ActiveLevel"
	) ~= "regression"
	then

		return

	end


	local gui =
		findRegressionGui()


	if not gui then

		warn(
			"[RegressionRightLayout] GUI not found"
		)

		return

	end


	local betPanel =
		findBetPanel(
			gui
		)


	local controls =
		findControlPanel(
			gui
		)


	if not betPanel then

		warn(
			"[RegressionRightLayout] Bet panel not found"
		)

	end


	if not controls then

		warn(
			"[RegressionRightLayout] Controls not found"
		)

	end



	------------------------------------------------
	-- BET PANEL
	------------------------------------------------

	if betPanel then

		betPanel.AnchorPoint =
			Vector2.new(
				1,
				0
			)


		betPanel.Position =
			UDim2.new(
				1,
				-18,
				0,
				190
			)


		--------------------------------
		-- Slightly narrower and shorter
		-- so it doesn't eat the controls.
		--------------------------------

		betPanel.Size =
			UDim2.fromOffset(
				455,
				315
			)

	end



	------------------------------------------------
	-- CONTROLS
	------------------------------------------------

	if controls then

		controls.AnchorPoint =
			Vector2.new(
				1,
				0
			)


		controls.Position =
			UDim2.new(
				1,
				-18,
				0,
				525
			)


		controls.Size =
			UDim2.fromOffset(
				390,
				300
			)

	end


	print(
		"[RegressionRightLayout] Applied"
	)

end



--------------------------------------------------
-- LEVEL CHANGE
--------------------------------------------------

player:GetAttributeChangedSignal(
	"ActiveLevel"
)
:Connect(
	function()

		task.delay(
			0.2,
			apply
		)

		task.delay(
			0.8,
			apply
		)

	end
)



--------------------------------------------------
-- GUI CREATED / REBUILT
--------------------------------------------------

playerGui.DescendantAdded:Connect(
	function(object)

		if object:IsA("TextLabel")
			or object:IsA("TextButton")
		then

			local text =
				string.lower(
					object.Text or ""
				)


			if string.find(
				text,
				"где будет минимум mse",
				1,
				true
			)
				or string.find(
					text,
					"наклон +",
					1,
					true
				)
			then

				task.delay(
					0.1,
					apply
				)


				task.delay(
					0.6,
					apply
				)

			end

		end

	end
)



--------------------------------------------------
-- START
--------------------------------------------------

task.delay(
	0.4,
	apply
)


task.delay(
	1.2,
	apply
)


print(
	"[RegressionRightLayout] Controller ready"
)
