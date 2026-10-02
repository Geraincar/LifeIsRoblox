local WorldLessonHUD = {}


local ui = nil

local lessonName = ""

local currentHint = nil



--------------------------------------------------
-- INIT
--------------------------------------------------

function WorldLessonHUD.Initialize(
	uiReferences
)

	ui =
		uiReferences


	ui.Root.Visible =
		false


	ui.ChoicesFrame.Visible =
		false

end



--------------------------------------------------
-- VISIBILITY
--------------------------------------------------

function WorldLessonHUD.Show()

	if not ui then
		return
	end


	ui.Root.Visible =
		true

end

function WorldLessonHUD.GetReopenButton()

	return ui.ReopenButton

end

function WorldLessonHUD.Hide()

	if not ui then
		return
	end


	WorldLessonHUD.ClearChoices()


	ui.Root.Visible =
		false


	if ui.ReopenButton then

		ui.ReopenButton.Visible =
			false

	end

end



--------------------------------------------------
-- LESSON
--------------------------------------------------

function WorldLessonHUD.SetLesson(
	name
)

	lessonName =
		name or ""

end



--------------------------------------------------
-- STEP
--------------------------------------------------

function WorldLessonHUD.SetStep(
	index,
	total,
	instruction
)

	instruction =
		instruction or {}


	if lessonName ~= "" then

		ui.StepLabel.Text =
			lessonName
			.. "  •  Step "
			.. tostring(index)
			.. " / "
			.. tostring(total)

	else

		ui.StepLabel.Text =
			"Step "
			.. tostring(index)
			.. " / "
			.. tostring(total)

	end


	ui.TitleLabel.Text =
		instruction.Title
		or ""


	ui.InstructionLabel.Text =
		instruction.Text
		or ""


	currentHint =
		instruction.Hint


	ui.HintButton.Visible =
		currentHint ~= nil


	ui.StatusLabel.Text =
		""


	WorldLessonHUD.ClearChoices()

end



--------------------------------------------------
-- STATUS
--------------------------------------------------

function WorldLessonHUD.SetStatus(
	text
)

	ui.StatusLabel.Text =
		text or ""

end



--------------------------------------------------
-- HINT
--------------------------------------------------

function WorldLessonHUD.Show()

	if not ui then
		return
	end


	ui.Root.Visible =
		true


	if ui.ReopenButton then

		ui.ReopenButton.Visible =
			false

	end

end



--------------------------------------------------
-- CHOICES
--------------------------------------------------

function WorldLessonHUD.ClearChoices()

	if not ui then
		return
	end


	for _, child in ipairs(
		ui.ChoicesFrame:GetChildren()
		) do

		if child:IsA(
			"TextButton"
			) then

			child:Destroy()

		end

	end


	ui.ChoicesFrame.Visible =
		false

end



function WorldLessonHUD.ShowChoices(
	options,
	callback
)

	WorldLessonHUD.ClearChoices()


	ui.ChoicesFrame.Visible =
		true


	for _, option in ipairs(
		options
		) do

		local button =
			Instance.new(
				"TextButton"
			)


		button.Name =
			"Choice_"
			.. tostring(
				option.Id
			)


		button.Size =
			UDim2.new(
				1,
				0,
				0,
				36
			)


		button.BackgroundColor3 =
			Color3.fromRGB(
				48,
				50,
				60
			)


		button.BorderSizePixel =
			0


		button.Text =
			option.Label
			or tostring(
				option.Id
			)


		button.TextColor3 =
			Color3.fromRGB(
				245,
				245,
				245
			)


		button.TextSize =
			15


		button.Font =
			Enum.Font.GothamMedium


		button.Parent =
			ui.ChoicesFrame


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
			button


		button.MouseButton1Click
			:Connect(function()

				callback(
					option.Id
				)

			end)

	end

end



--------------------------------------------------
-- BUTTON REFERENCES
--------------------------------------------------

function WorldLessonHUD.GetHintButton()

	return ui.HintButton

end


function WorldLessonHUD.GetResetButton()

	return ui.ResetButton

end


function WorldLessonHUD.GetExitButton()

	return ui.ExitButton

end


function WorldLessonHUD.Minimize()

	if not ui then
		return
	end


	ui.Root.Visible =
		false


	if ui.ReopenButton then

		ui.ReopenButton.Visible =
			true

	end

end



function WorldLessonHUD.Restore()

	if not ui then
		return
	end


	ui.Root.Visible =
		true


	if ui.ReopenButton then

		ui.ReopenButton.Visible =
			false

	end

end

return WorldLessonHUD