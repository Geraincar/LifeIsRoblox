local UI = {}
UI.__index = UI

--------------------------------------------------
-- LABEL HELPER
--------------------------------------------------

local function createLabel(
	parent,
	name,
	position,
	size
)

	local label =
		Instance.new("TextLabel")

	label.Name =
		name

	label.AnchorPoint =
		Vector2.new(
			0.5,
			0
		)

	label.Position =
		position

	label.Size =
		size

	label.BackgroundColor3 =
		Color3.fromRGB(
			22,
			25,
			32
		)

	label.BackgroundTransparency =
		0.12

	label.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	label.Font =
		Enum.Font.GothamBold

	label.TextSize =
		18

	label.TextScaled =
		false

	label.TextWrapped =
		true

	label.Visible =
		false

	label.Parent =
		parent

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

	return label
end

--------------------------------------------------
-- CREATE
--------------------------------------------------

function UI.new(playerGui)

	local self =
		setmetatable(
			{},
			UI
		)

	local gui =
		Instance.new(
			"ScreenGui"
		)

	gui.Name =
		"DecisionTreeLevelUI"

	gui.ResetOnSpawn =
		false

	gui.DisplayOrder =
		60

	gui.Enabled =
		false

	gui.Parent =
		playerGui

	self.Gui =
		gui

	--------------------------------------------------
	-- CONDITION
	--------------------------------------------------

	self.Condition =
		createLabel(
			gui,
			"ConditionLabel",

			UDim2.new(
				0.5,
				0,
				0,
				47
			),

			UDim2.new(
				0,
				300,
				0,
				30
			)
		)

	--------------------------------------------------
	-- X / Y
	--------------------------------------------------

	self.Data =
		createLabel(
			gui,
			"DataLabel",

			UDim2.new(
				0.5,
				0,
				0,
				82
			),

			UDim2.new(
				0,
				220,
				0,
				30
			)
		)

	--------------------------------------------------
	-- CORRECT / INCORRECT
	--------------------------------------------------

	self.Feedback =
		createLabel(
			gui,
			"FeedbackLabel",

			UDim2.new(
				0.5,
				0,
				0,
				118
			),

			UDim2.new(
				0,
				230,
				0,
				42
			)
		)

	self.Feedback.TextSize =
		24

	self.FeedbackToken =
		0

	--------------------------------------------------
	-- RESTART BUTTON
	--------------------------------------------------

	self.RestartButton =
		Instance.new(
			"TextButton"
		)

	self.RestartButton.Name =
		"RestartButton"

	self.RestartButton.AnchorPoint =
		Vector2.new(
			1,
			0
		)

	self.RestartButton.Position =
		UDim2.new(
			1,
			-20,
			0,
			20
		)

	self.RestartButton.Size =
		UDim2.new(
			0,
			150,
			0,
			40
		)

	self.RestartButton.BackgroundColor3 =
		Color3.fromRGB(
			170,
			55,
			55
		)

	self.RestartButton.BackgroundTransparency =
		0.05

	self.RestartButton.Text =
		"RESTART"

	self.RestartButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	self.RestartButton.Font =
		Enum.Font.GothamBold

	self.RestartButton.TextSize =
		17

	self.RestartButton.AutoButtonColor =
		true

	self.RestartButton.Parent =
		gui

	local restartCorner =
		Instance.new(
			"UICorner"
		)

	restartCorner.CornerRadius =
		UDim.new(
			0,
			8
		)

	restartCorner.Parent =
		self.RestartButton

	return self
end

--------------------------------------------------
-- ENABLE
--------------------------------------------------

function UI:SetEnabled(value)

	self.Gui.Enabled =
		value

	if not value then

		self:ClearTransient()

	end
end

--------------------------------------------------
-- CONDITION
--------------------------------------------------

function UI:SetCondition(text)

	if not text then

		self.Condition.Visible =
			false

		return
	end

	self.Condition.Text =
		"УСЛОВИЕ: "
		.. text

	self.Condition.Visible =
		true
end

--------------------------------------------------
-- DATA
--------------------------------------------------

function UI:SetData(x, y)

	self.Data.Text =
		"x = "
		.. tostring(x)
		.. "     y = "
		.. tostring(y)

	self.Data.Visible =
		true
end

function UI:HideData()

	self.Data.Visible =
		false

end

--------------------------------------------------
-- FEEDBACK
--------------------------------------------------

function UI:ShowFeedback(correct)

	self.FeedbackToken += 1

	local token =
		self.FeedbackToken

	if correct then

		self.Feedback.Text =
			"CORRECT"

		self.Feedback.TextColor3 =
			Color3.fromRGB(
				70,
				255,
				110
			)

		self.Feedback.BackgroundColor3 =
			Color3.fromRGB(
				18,
				55,
				28
			)

	else

		self.Feedback.Text =
			"INCORRECT"

		self.Feedback.TextColor3 =
			Color3.fromRGB(
				255,
				85,
				85
			)

		self.Feedback.BackgroundColor3 =
			Color3.fromRGB(
				60,
				20,
				20
			)

	end

	self.Feedback.Visible =
		true

	task.delay(
		0.9,

		function()

			if token
				~=
				self.FeedbackToken
			then
				return
			end

			self.Feedback.Visible =
				false

		end
	)
end

--------------------------------------------------
-- CLEAR
--------------------------------------------------

function UI:ClearTransient()

	self.FeedbackToken += 1

	self.Condition.Visible =
		false

	self.Data.Visible =
		false

	self.Feedback.Visible =
		false

end

return UI