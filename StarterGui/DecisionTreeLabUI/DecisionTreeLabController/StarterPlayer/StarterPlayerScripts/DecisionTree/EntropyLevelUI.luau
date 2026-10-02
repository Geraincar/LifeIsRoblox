local TweenService =
	game:GetService("TweenService")

local UI = {}
UI.__index = UI

--------------------------------------------------
-- COLORS
--------------------------------------------------

local WHITE =
	Color3.fromRGB(
		245,
		247,
		255
	)

local MUTED =
	Color3.fromRGB(
		170,
		180,
		200
	)

local GREEN =
	Color3.fromRGB(
		80,
		255,
		115
	)

local YELLOW =
	Color3.fromRGB(
		255,
		220,
		80
	)

local PANEL =
	Color3.fromRGB(
		18,
		22,
		31
	)

local PANEL2 =
	Color3.fromRGB(
		31,
		37,
		51
	)

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function corner(
	parent,
	radius
)

	local object =
		Instance.new("UICorner")

	object.CornerRadius =
		UDim.new(
			0,
			radius or 10
		)

	object.Parent =
		parent

	return object
end

local function stroke(
	parent,
	thickness,
	color,
	transparency
)

	local object =
		Instance.new("UIStroke")

	object.Thickness =
		thickness or 1

	object.Color =
		color or WHITE

	object.Transparency =
		transparency or 0

	object.Parent =
		parent

	return object
end

local function label(
	parent,
	name,
	text,
	position,
	size,
	textSize,
	bold
)

	local object =
		Instance.new("TextLabel")

	object.Name =
		name

	object.BackgroundTransparency =
		1

	object.Position =
		position

	object.Size =
		size

	object.Text =
		text or ""

	object.TextColor3 =
		WHITE

	object.Font =
		bold
		and Enum.Font.GothamBold
		or Enum.Font.Gotham

	object.TextSize =
		textSize or 18

	object.TextWrapped =
		true

	object.TextXAlignment =
		Enum.TextXAlignment.Center

	object.TextYAlignment =
		Enum.TextYAlignment.Center

	object.Parent =
		parent

	return object
end

local function button(
	parent,
	name,
	text,
	position,
	size,
	color
)

	local object =
		Instance.new("TextButton")

	object.Name =
		name

	object.Position =
		position

	object.Size =
		size

	object.BackgroundColor3 =
		color

	object.Text =
		text

	object.TextColor3 =
		WHITE

	object.Font =
		Enum.Font.GothamBold

	object.TextSize =
		17

	object.AutoButtonColor =
		true

	object.Parent =
		parent

	corner(
		object,
		9
	)

	return object
end

--------------------------------------------------
-- FIND LEFT NODE OBJECTS
--------------------------------------------------

local function findLeftObjects()

	local tree =
		workspace:FindFirstChild(
			"DecisionTree"
		)

	if not tree then

		warn(
			"[EntropyUI] DecisionTree not found"
		)

		return {}
	end

	local objects = {}

	for _, descendant
		in ipairs(
			tree:GetDescendants()
		)
	do

		if descendant:IsA(
			"BasePart"
			)
				and descendant:GetAttribute(
					"DT_IsDataObject"
				) == true
				and descendant:GetAttribute(
					"DT_SourceNode"
				) == "Left"
		then

			table.insert(
				objects,
				descendant
			)

		end
	end

	table.sort(
		objects,

		function(a, b)

			return
				tostring(
					a:GetAttribute(
						"DT_ObjectId"
					)
				)
				<
				tostring(
					b:GetAttribute(
						"DT_ObjectId"
					)
				)

		end
	)

	return objects
end

--------------------------------------------------
-- VIEWPORT OBJECT
--------------------------------------------------

local function cleanClone(clone)

	for _, descendant
		in ipairs(
			clone:GetDescendants()
		)
	do

		if descendant:IsA(
			"SelectionBox"
			)
				or descendant:IsA(
					"Highlight"
				)
				or descendant:IsA(
					"BillboardGui"
				)
				or descendant:IsA(
					"SurfaceGui"
				)
		then

			descendant:Destroy()

		end
	end
end

local function makeObjectPreview(
	parent,
	part,
	position,
	size
)

	local viewport =
		Instance.new(
			"ViewportFrame"
		)

	viewport.BackgroundTransparency =
		1

	viewport.Position =
		position

	viewport.Size =
		size

	viewport.Ambient =
		Color3.fromRGB(
			190,
			190,
			190
		)

	viewport.LightColor =
		Color3.fromRGB(
			255,
			255,
			255
		)

	viewport.LightDirection =
		Vector3.new(
			-1,
			-1,
			-1
		)

	viewport.Parent =
		parent

	local world =
		Instance.new(
			"WorldModel"
		)

	world.Parent =
		viewport

	local clone =
		part:Clone()

	cleanClone(
		clone
	)

	clone.Anchored =
		true

	clone.CanCollide =
		false

	clone.CanQuery =
		false

	clone.CanTouch =
		false

	clone.CFrame =
		CFrame.new(
			0,
			0,
			0
		)

	clone.Parent =
		world

	local camera =
		Instance.new(
			"Camera"
		)

	camera.FieldOfView =
		35

	camera.Parent =
		viewport

	viewport.CurrentCamera =
		camera

	local radius =
		math.max(
			clone.Size.X,
			clone.Size.Y,
			clone.Size.Z,
			1
		)

	camera.CFrame =
		CFrame.lookAt(

			Vector3.new(
				radius * 2.4,
				radius * 1.5,
				radius * 3.2
			),

			Vector3.new(
				0,
				0,
				0
			)
		)

	return viewport
end

--------------------------------------------------
-- OBJECT ROW
--------------------------------------------------

local function makeObjectRow(
	parent,
	name,
	objects,
	y
)

	local frame =
		Instance.new("Frame")

	frame.Name =
		name

	frame.BackgroundTransparency =
		1

	frame.Position =
		UDim2.new(
			0,
			2,
			0,
			y
		)

	frame.Size =
		UDim2.new(
			1,
			-4,
			0,
			43
		)

	frame.Parent =
		parent

	local count =
		#objects

	if count == 0 then
		return frame
	end

	local width =
		1 / count

	for index, part
		in ipairs(
			objects
		)
	do

		makeObjectPreview(

			frame,

			part,

			UDim2.new(
				(index - 1)
					* width,
				0,
				0,
				0
			),

			UDim2.new(
				width,
				0,
				1,
				0
			)

		)

	end

	return frame
end

--------------------------------------------------
-- FRACTION
--------------------------------------------------

local function makeFraction(
	parent,
	name,
	position
)

	local frame =
		Instance.new("Frame")

	frame.Name =
		name

	frame.BackgroundTransparency =
		1

	frame.Position =
		position

	frame.Size =
		UDim2.new(
			0,
			150,
			0,
			108
		)

	frame.Parent =
		parent

	local numeratorContainer =
		Instance.new("Frame")

	numeratorContainer.Name =
		"NumeratorContainer"

	numeratorContainer.BackgroundTransparency =
		1

	numeratorContainer.Position =
		UDim2.new(
			0,
			0,
			0,
			0
		)

	numeratorContainer.Size =
		UDim2.new(
			1,
			0,
			0,
			45
		)

	numeratorContainer.Parent =
		frame

	local line =
		Instance.new("Frame")

	line.Name =
		"FractionLine"

	line.BorderSizePixel =
		0

	line.BackgroundColor3 =
		WHITE

	line.Position =
		UDim2.new(
			0,
			5,
			0,
			51
		)

	line.Size =
		UDim2.new(
			1,
			-10,
			0,
			2
		)

	line.Parent =
		frame

	local denominatorContainer =
		Instance.new("Frame")

	denominatorContainer.Name =
		"DenominatorContainer"

	denominatorContainer.BackgroundTransparency =
		1

	denominatorContainer.Position =
		UDim2.new(
			0,
			0,
			0,
			59
		)

	denominatorContainer.Size =
		UDim2.new(
			1,
			0,
			0,
			45
		)

	denominatorContainer.Parent =
		frame

	local numeratorValue =
		label(
			numeratorContainer,
			"NumeratorValue",
			"",
			UDim2.fromScale(
				0,
				0
			),
			UDim2.fromScale(
				1,
				1
			),
			30,
			true
		)

	numeratorValue.TextColor3 =
		GREEN

	numeratorValue.Visible =
		false

	local denominatorValue =
		label(
			denominatorContainer,
			"DenominatorValue",
			"",
			UDim2.fromScale(
				0,
				0
			),
			UDim2.fromScale(
				1,
				1
			),
			29,
			true
		)

	denominatorValue.TextColor3 =
		GREEN

	denominatorValue.Visible =
		false

	local highlight =
		stroke(
			frame,
			2,
			YELLOW,
			1
		)

	return {

		Frame =
			frame,

		NumeratorContainer =
			numeratorContainer,

		DenominatorContainer =
			denominatorContainer,

		NumeratorValue =
			numeratorValue,

		DenominatorValue =
			denominatorValue,

		Highlight =
			highlight,

		NumeratorRow =
			nil,

		DenominatorRow =
			nil,
	}
end

--------------------------------------------------
-- TERM
--------------------------------------------------

local function makeTerm(
	parent,
	name,
	x
)

	local frame =
		Instance.new("Frame")

	frame.Name =
		name

	frame.BackgroundTransparency =
		1

	frame.Position =
		UDim2.new(
			0,
			x,
			0,
			53
		)

	frame.Size =
		UDim2.new(
			0,
			455,
			0,
			125
		)

	frame.Parent =
		parent

	label(
		frame,
		"Minus",
		"−",
		UDim2.new(
			0,
			0,
			0,
			34
		),
		UDim2.new(
			0,
			30,
			0,
			48
		),
		32,
		true
	)

	local outside =
		makeFraction(
			frame,
			"OutsideFraction",
			UDim2.new(
				0,
				30,
				0,
				0
			)
		)

	label(
		frame,
		"Log",
		"× log₂",
		UDim2.new(
			0,
			186,
			0,
			35
		),
		UDim2.new(
			0,
			83,
			0,
			45
		),
		23,
		true
	)

	label(
		frame,
		"Open",
		"(",
		UDim2.new(
			0,
			262,
			0,
			33
		),
		UDim2.new(
			0,
			18,
			0,
			48
		),
		30,
		false
	)

	local inside =
		makeFraction(
			frame,
			"InsideFraction",
			UDim2.new(
				0,
				277,
				0,
				0
			)
		)

	label(
		frame,
		"Close",
		")",
		UDim2.new(
			0,
			428,
			0,
			33
		),
		UDim2.new(
			0,
			18,
			0,
			48
		),
		30,
		false
	)

	return {

		Frame =
			frame,

		Outside =
			outside,

		Inside =
			inside,
	}
end

--------------------------------------------------
-- NEW UI
--------------------------------------------------

function UI.new(playerGui)

	local self =
		setmetatable(
			{},
			UI
		)

	--------------------------------------------------
	-- SCREEN
	--------------------------------------------------

	local gui =
		Instance.new(
			"ScreenGui"
		)

	gui.Name =
		"EntropyLevelGui"

	gui.ResetOnSpawn =
		false

	gui.IgnoreGuiInset =
		true

	gui.DisplayOrder =
		90

	gui.Enabled =
		false

	gui.Parent =
		playerGui

	self.Gui =
		gui

	--------------------------------------------------
	-- MAIN PANEL
	--------------------------------------------------

	local main =
		Instance.new("Frame")

	main.Name =
		"MainPanel"

	main.AnchorPoint =
		Vector2.new(
			0.5,
			0
		)

	main.Position =
		UDim2.new(
			0.5,
			0,
			0,
			32
		)

	main.Size =
		UDim2.new(
			0,
			1180,
			0,
			500
		)

	main.BackgroundColor3 =
		PANEL

	main.BackgroundTransparency =
		0.03

	main.Visible =
		false

	main.Parent =
		gui

	corner(
		main,
		15
	)

	stroke(
		main,
		2,
		Color3.fromRGB(
			72,
			120,
			210
		),
		0.15
	)

	self.Panel =
		main

	--------------------------------------------------
	-- TITLE
	--------------------------------------------------

	local title =
		label(
			main,
			"Title",
			"Энтропия для второго узла",
			UDim2.new(
				0,
				25,
				0,
				12
			),
			UDim2.new(
				1,
				-50,
				0,
				38
			),
			26,
			true
		)

	title.TextColor3 =
		YELLOW

	--------------------------------------------------
	-- FORMULA BOX
	--------------------------------------------------

	local formula =
		Instance.new("Frame")

	formula.Name =
		"Formula"

	formula.Position =
		UDim2.new(
			0,
			25,
			0,
			60
		)

	formula.Size =
		UDim2.new(
			1,
			-50,
			0,
			205
		)

	formula.BackgroundColor3 =
		PANEL2

	formula.Parent =
		main

	corner(
		formula,
		12
	)

	self.Formula =
		formula

	label(
		formula,
		"H",
		"H =",
		UDim2.new(
			0,
			18,
			0,
			86
		),
		UDim2.new(
			0,
			65,
			0,
			45
		),
		31,
		true
	)

	--------------------------------------------------
	-- EXPLICIT SUM:
	--
	-- -(A/N)log2(A/N) -(B/N)log2(B/N)
	--------------------------------------------------

	self.TermA =
		makeTerm(
			formula,
			"ClassATerm",
			72
		)

	self.TermB =
		makeTerm(
			formula,
			"ClassBTerm",
			525
		)

	local result =
		label(
			formula,
			"Result",
			"",
			UDim2.new(
				1,
				-130,
				0,
				84
			),
			UDim2.new(
				0,
				115,
				0,
				48
			),
			30,
			true
		)

	result.TextColor3 =
		GREEN

	self.Result =
		result

	--------------------------------------------------
	-- PROMPT
	--------------------------------------------------

	local prompt =
		label(
			main,
			"Prompt",
			"",
			UDim2.new(
				0,
				30,
				0,
				285
			),
			UDim2.new(
				1,
				-60,
				0,
				50
			),
			23,
			true
		)

	prompt.TextXAlignment =
		Enum.TextXAlignment.Left

	self.Prompt =
		prompt

	--------------------------------------------------
	-- COUNTER BOX
	--------------------------------------------------

	local counterBox =
		Instance.new("Frame")

	counterBox.Name =
		"CounterBox"

	counterBox.Position =
		UDim2.new(
			0,
			30,
			0,
			350
		)

	counterBox.Size =
		UDim2.new(
			0,
			270,
			0,
			105
		)

	counterBox.BackgroundColor3 =
		PANEL2

	counterBox.Parent =
		main

	corner(
		counterBox,
		11
	)

	label(
		counterBox,
		"CounterTitle",
		"СЧЁТЧИК",
		UDim2.new(
			0,
			10,
			0,
			8
		),
		UDim2.new(
			1,
			-20,
			0,
			24
		),
		15,
		true
	)

	local counterValue =
		label(
			counterBox,
			"CounterValue",
			"0",
			UDim2.new(
				0,
				10,
				0,
				31
			),
			UDim2.new(
				1,
				-20,
				0,
				61
			),
			39,
			true
		)

	self.CounterValue =
		counterValue

	--------------------------------------------------
	-- RESET
	--------------------------------------------------

	self.ResetButton =
		button(
			main,
			"ResetButton",
			"СБРОСИТЬ СЧЁТЧИК",
			UDim2.new(
				0,
				325,
				0,
				380
			),
			UDim2.new(
				0,
				240,
				0,
				48
			),
			Color3.fromRGB(
				160,
				64,
				70
			)
		)

	--------------------------------------------------
	-- HELP
	--------------------------------------------------

	local help =
		label(
			main,
			"Help",
			"Нажимайте на объекты внутри подсвеченной коробки.",
			UDim2.new(
				0,
				600,
				0,
				355
			),
			UDim2.new(
				0,
				530,
				0,
				90
			),
			17,
			false
		)

	help.TextColor3 =
		MUTED

	--------------------------------------------------
	-- UNUSED INTRO COMPATIBILITY
	--
	-- Intro is now shown by DecisionTreeController.
	--------------------------------------------------

	self.IntroShade =
		Instance.new("Frame")

	self.IntroShade.Name =
		"UnusedIntroShade"

	self.IntroShade.Size =
		UDim2.fromScale(
			1,
			1
		)

	self.IntroShade.BackgroundTransparency =
		1

	self.IntroShade.Visible =
		false

	self.IntroShade.Parent =
		gui

	self.NextButton =
		Instance.new("TextButton")

	self.NextButton.Name =
		"UnusedNextButton"

	self.NextButton.Visible =
		false

	self.NextButton.Parent =
		self.IntroShade

	--------------------------------------------------
	-- FADE
	--------------------------------------------------

	local fade =
		Instance.new("Frame")

	fade.Name =
		"Fade"

	fade.Size =
		UDim2.fromScale(
			1,
			1
		)

	fade.BackgroundColor3 =
		Color3.fromRGB(
			0,
			0,
			0
		)

	fade.BackgroundTransparency =
		1

	fade.Visible =
		false

	fade.ZIndex =
		200

	fade.Parent =
		gui

	self.Fade =
		fade

	--------------------------------------------------
	-- OBJECTS IN FORMULA
	--------------------------------------------------

	self:SetNodeObjects(
		findLeftObjects()
	)

	self:ResetFormulaVisuals()

	print(
		"[EntropyUI] Formula UI created"
	)

	return self
end

--------------------------------------------------
-- SET OBJECT PREVIEWS
--------------------------------------------------

function UI:SetNodeObjects(
	leftObjects
)

	local classA = {}
	local classB = {}

	for _, part
		in ipairs(
			leftObjects
		)
	do

		local className =
			part:GetAttribute(
				"DT_Class"
			)

		if className == "A" then

			table.insert(
				classA,
				part
			)

		elseif className == "B" then

			table.insert(
				classB,
				part
			)

		end
	end

	local function populateFraction(
		fraction,
		numeratorObjects
	)

		if fraction.NumeratorRow then

			fraction.NumeratorRow:Destroy()

		end

		if fraction.DenominatorRow then

			fraction.DenominatorRow:Destroy()

		end

		fraction.NumeratorRow =
			makeObjectRow(
				fraction.NumeratorContainer,
				"Objects",
				numeratorObjects,
				0
			)

		fraction.DenominatorRow =
			makeObjectRow(
				fraction.DenominatorContainer,
				"Objects",
				leftObjects,
				0
			)

	end

	populateFraction(
		self.TermA.Outside,
		classA
	)

	populateFraction(
		self.TermA.Inside,
		classA
	)

	populateFraction(
		self.TermB.Outside,
		classB
	)

	populateFraction(
		self.TermB.Inside,
		classB
	)

	print(
		"[EntropyUI] Formula objects:",
		"A =",
		#classA,
		"B =",
		#classB,
		"TOTAL =",
		#leftObjects
	)
end

--------------------------------------------------
-- ENABLE
--------------------------------------------------

function UI:SetEnabled(enabled)

	self.Gui.Enabled =
		enabled == true

	if not enabled then

		self.Panel.Visible =
			false

		self.IntroShade.Visible =
			false

		self.Fade.Visible =
			false

		self.Fade.BackgroundTransparency =
			1

	end
end

--------------------------------------------------
-- COMPATIBILITY
--------------------------------------------------

function UI:ShowIntro()

	self.Panel.Visible =
		false

end

function UI:HideIntro()

	self.IntroShade.Visible =
		false

	self.Panel.Visible =
		true

	print(
		"[EntropyUI] FORMULA PANEL VISIBLE"
	)
end

--------------------------------------------------
-- PROMPT
--------------------------------------------------

function UI:SetPrompt(text)

	self.Prompt.Text =
		text or ""

end

--------------------------------------------------
-- COUNTER
--------------------------------------------------

function UI:SetCounter(
	value,
	goal,
	success
)

	if goal then

		self.CounterValue.Text =
			tostring(value)
			.. " / "
			.. tostring(goal)

	else

		self.CounterValue.Text =
			tostring(value)

	end

	if success then

		self.CounterValue.TextColor3 =
			GREEN

	else

		self.CounterValue.TextColor3 =
			WHITE

	end
end

--------------------------------------------------
-- RESET FRACTION
--------------------------------------------------

local function resetFraction(
	fraction
)

	if fraction.NumeratorRow then

		fraction.NumeratorRow.Visible =
			true

	end

	if fraction.DenominatorRow then

		fraction.DenominatorRow.Visible =
			true

	end

	fraction.NumeratorValue.Visible =
		false

	fraction.DenominatorValue.Visible =
		false

	fraction.NumeratorValue.Text =
		""

	fraction.DenominatorValue.Text =
		""

	fraction.Highlight.Transparency =
		1
end

--------------------------------------------------
-- RESET FORMULA
--------------------------------------------------

function UI:ResetFormulaVisuals()

	resetFraction(
		self.TermA.Outside
	)

	resetFraction(
		self.TermA.Inside
	)

	resetFraction(
		self.TermB.Outside
	)

	resetFraction(
		self.TermB.Inside
	)

	self.Result.Text =
		""

end

--------------------------------------------------
-- HIGHLIGHT CURRENT PART
--------------------------------------------------

function UI:HighlightStage(stage)

	for _, fraction
		in ipairs({

			self.TermA.Outside,
			self.TermA.Inside,
			self.TermB.Outside,
			self.TermB.Inside,

		})
	do

		fraction.Highlight.Transparency =
			1

	end

	if stage == "A" then

		self.TermA.Outside.Highlight.Transparency =
			0

		self.TermA.Inside.Highlight.Transparency =
			0

	elseif stage == "B" then

		self.TermB.Outside.Highlight.Transparency =
			0

		self.TermB.Inside.Highlight.Transparency =
			0

	elseif stage == "TOTAL" then

		self.TermA.Outside.Highlight.Transparency =
			0

		self.TermA.Inside.Highlight.Transparency =
			0

		self.TermB.Outside.Highlight.Transparency =
			0

		self.TermB.Inside.Highlight.Transparency =
			0

	end
end

--------------------------------------------------
-- NUMERATOR
--------------------------------------------------

local function setNumerator(
	term,
	value
)

	for _, fraction
		in ipairs({

			term.Outside,
			term.Inside,

		})
	do

		if fraction.NumeratorRow then

			fraction.NumeratorRow.Visible =
				false

		end

		fraction.NumeratorValue.Text =
			tostring(value)

		fraction.NumeratorValue.Visible =
			true

	end
end

function UI:SetAValue(value)

	setNumerator(
		self.TermA,
		value
	)

end

function UI:SetBValue(value)

	setNumerator(
		self.TermB,
		value
	)

end

--------------------------------------------------
-- DENOMINATOR
--------------------------------------------------

local function setDenominator(
	term,
	value
)

	for _, fraction
		in ipairs({

			term.Outside,
			term.Inside,

		})
	do

		if fraction.DenominatorRow then

			fraction.DenominatorRow.Visible =
				false

		end

		fraction.DenominatorValue.Text =
			tostring(value)

		fraction.DenominatorValue.Visible =
			true

	end
end

function UI:SetTotalValue(value)

	setDenominator(
		self.TermA,
		value
	)

	setDenominator(
		self.TermB,
		value
	)

end

--------------------------------------------------
-- RESULT
--------------------------------------------------

function UI:SetEntropyResult(text)

	--------------------------------------------------
	-- Controller currently sends the whole equation.
	-- On-screen formula is already visible,
	-- so only put final equality on the right.
	--------------------------------------------------

	self.Result.Text =
		"= 1"

	self.Result.TextColor3 =
		GREEN

end

--------------------------------------------------
-- FADE
--------------------------------------------------

function UI:PlayFade(duration)

	duration =
		duration or 0.8

	self.Fade.Visible =
		true

	self.Fade.BackgroundTransparency =
		1

	local tween =
		TweenService:Create(

			self.Fade,

			TweenInfo.new(
				duration,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				BackgroundTransparency =
				0
			}
		)

	tween:Play()

	tween.Completed:Wait()
end

return UI