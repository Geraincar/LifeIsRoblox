local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)



------------------------------------------------------------
-- REGRESSION THEME = SOURCE OF TRUTH
------------------------------------------------------------

local Theme


do

	local ok,
		result =
		pcall(
			function()

				return require(
					ReplicatedStorage
						:WaitForChild("Regression")
						:WaitForChild("UI")
						:WaitForChild("Theme")
				)

			end
		)


	if ok then

		Theme =
			result

	else

		warn(
			"[UnifiedUI] Regression Theme not found, using fallback"
		)


		Theme = {

			color = {

				bg =
					Color3.fromRGB(
						30,
						30,
						36
					),

				panel =
					Color3.fromRGB(
						42,
						42,
						51
					),

				panel2 =
					Color3.fromRGB(
						52,
						52,
						63
					),

				text =
					Color3.fromRGB(
						237,
						237,
						237
					),

				textDim =
					Color3.fromRGB(
						160,
						160,
						170
					),

				c =
					Color3.fromRGB(
						230,
						159,
						0
					),

				loss =
					Color3.fromRGB(
						86,
						180,
						233
					),

				good =
					Color3.fromRGB(
						0,
						158,
						115
					),

				residual =
					Color3.fromRGB(
						213,
						94,
						0
					),

				penalty =
					Color3.fromRGB(
						204,
						121,
						167
					),

			},

			font =
				Enum.Font.BuilderSans,

			fontBold =
				Enum.Font.BuilderSansBold,

		}

	end

end



local C =
	Theme.color


local FONT =
	Theme.font
	or Enum.Font.BuilderSans


local FONT_BOLD =
	Theme.fontBold
	or Enum.Font.BuilderSansBold



------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function corner(
	object,
	radius
)

	if not object
		or not object:IsA(
			"GuiObject"
		)
	then

		return

	end


	local value =
		object:FindFirstChildOfClass(
			"UICorner"
		)


	if not value then

		value =
			Instance.new(
				"UICorner"
			)

		value.Parent =
			object

	end


	value.CornerRadius =
		UDim.new(
			0,
			radius or 10
		)

end



local function stroke(
	object,
	color,
	transparency,
	thickness
)

	if not object
		or not object:IsA(
			"GuiObject"
		)
	then

		return

	end


	local value =
		object:FindFirstChildOfClass(
			"UIStroke"
		)


	if not value then

		value =
			Instance.new(
				"UIStroke"
			)

		value.Parent =
			object

	end


	value.Color =
		color
		or C.loss


	value.Transparency =
		transparency
		or 0.55


	value.Thickness =
		thickness
		or 1

end



local function isGray(
	color
)

	local maxValue =
		math.max(
			color.R,
			color.G,
			color.B
		)


	local minValue =
		math.min(
			color.R,
			color.G,
			color.B
		)


	return
		maxValue
		- minValue
		< 0.09

end



local function styleText(
	object
)

	if not (
		object:IsA("TextLabel")
		or object:IsA("TextButton")
	) then

		return

	end


	local bold =
		object.Font
			== Enum.Font.GothamBold
		or object.Font
			== Enum.Font.GothamMedium
		or object.Font
			== Enum.Font.SourceSansBold


	object.Font =
		bold
			and FONT_BOLD
			or FONT


	if isGray(
		object.TextColor3
	) then

		local brightness =
			(
				object.TextColor3.R
				+ object.TextColor3.G
				+ object.TextColor3.B
			)
			/ 3


		if brightness > 0.75 then

			object.TextColor3 =
				C.text

		else

			object.TextColor3 =
				C.textDim

		end

	end

end



local function styleButton(
	button,
	accent
)

	if not button
		or not button:IsA(
			"TextButton"
		)
	then

		return

	end


	button.BackgroundColor3 =
		C.panel2


	button.BackgroundTransparency =
		0.02


	button.TextColor3 =
		accent
		or C.text


	button.Font =
		FONT_BOLD


	button.BorderSizePixel =
		0


	corner(
		button,
		10
	)


	stroke(
		button,
		accent or C.loss,
		0.65,
		1
	)

end



local function styleChildrenText(
	root
)

	for _, object in ipairs(
		root:GetDescendants()
	) do

		styleText(
			object
		)

	end

end



------------------------------------------------------------
-- GLOBAL LEVEL FLOW
------------------------------------------------------------

local function styleLevelFlow(
	gui
)

	gui.DisplayOrder =
		500


	--------------------------------
	-- STATUS
	--------------------------------

	local status =
		gui:FindFirstChild(
			"Status"
		)


	if status
		and status:IsA("Frame")
	then

		status.AnchorPoint =
			Vector2.new(
				0.5,
				0
			)


		status.Position =
			UDim2.new(
				0.5,
				0,
				0,
				8
			)


		status.Size =
			UDim2.fromOffset(
				440,
				56
			)


		status.BackgroundColor3 =
			C.bg


		status.BackgroundTransparency =
			0.10


		status.BorderSizePixel =
			0


		corner(
			status,
			12
		)


		stroke(
			status,
			C.loss,
			0.62,
			1
		)


		local levelLabel =
			status:FindFirstChild(
				"LevelLabel"
			)


		if levelLabel then

			levelLabel.Position =
				UDim2.fromOffset(
					14,
					5
				)


			levelLabel.Size =
				UDim2.new(
					1,
					-190,
					0,
					23
				)


			levelLabel.TextXAlignment =
				Enum.TextXAlignment.Left


			levelLabel.TextSize =
				16


			levelLabel.Font =
				FONT_BOLD


			levelLabel.TextColor3 =
				C.text

		end


		local hint =
			status:FindFirstChild(
				"HintLabel"
			)


		if hint then

			hint.Position =
				UDim2.fromOffset(
					14,
					29
				)


			hint.Size =
				UDim2.new(
					1,
					-190,
					0,
					18
				)


			hint.TextXAlignment =
				Enum.TextXAlignment.Left


			hint.TextSize =
				12


			hint.Font =
				FONT


			hint.TextColor3 =
				C.textDim

		end


		local skip =
			status:FindFirstChild(
				"SkipButton"
			)


		if skip then

			skip.AnchorPoint =
				Vector2.new(
					1,
					0.5
				)


			skip.Position =
				UDim2.new(
					1,
					-10,
					0.5,
					0
				)


			skip.Size =
				UDim2.fromOffset(
					70,
					36
				)


			skip.Text =
				"SKIP"


			styleButton(
				skip,
				C.c
			)

		end


		local reset =
			status:FindFirstChild(
				"ResetButton"
			)


		if reset then

			reset.AnchorPoint =
				Vector2.new(
					1,
					0.5
				)


			reset.Position =
				UDim2.new(
					1,
					-88,
					0.5,
					0
				)


			reset.Size =
				UDim2.fromOffset(
					76,
					36
				)


			styleButton(
				reset,
				C.residual
			)

		end

	end


	--------------------------------
	-- WALK NAVIGATION
	--------------------------------

	local nav =
		gui:FindFirstChild(
			"Navigation"
		)


	if nav
		and nav:IsA("Frame")
	then

		nav.AnchorPoint =
			Vector2.new(
				0.5,
				0
			)


		nav.Position =
			UDim2.new(
				0.5,
				0,
				0,
				72
			)


		nav.Size =
			UDim2.fromOffset(
				390,
				58
			)


		nav.BackgroundColor3 =
			C.bg


		nav.BackgroundTransparency =
			0.08


		corner(
			nav,
			12
		)


		stroke(
			nav,
			C.c,
			0.55,
			1
		)


		local arrow =
			nav:FindFirstChild(
				"Arrow"
			)


		if arrow then

			arrow.TextColor3 =
				C.c


			arrow.Font =
				FONT_BOLD

		end


		local destination =
			nav:FindFirstChild(
				"DestinationLabel"
			)


		if destination then

			destination.TextColor3 =
				C.text


			destination.Font =
				FONT_BOLD

		end


		local distance =
			nav:FindFirstChild(
				"DistanceLabel"
			)


		if distance then

			distance.TextColor3 =
				C.textDim


			distance.Font =
				FONT

		end

	end


	--------------------------------
	-- COMPLETION MODAL
	--------------------------------

	local overlay =
		gui:FindFirstChild(
			"Overlay"
		)


	if overlay
		and overlay:IsA("Frame")
	then

		overlay.BackgroundTransparency =
			0.42


		local card =
			overlay:FindFirstChild(
				"Card"
			)


		if card
			and card:IsA("Frame")
		then

			card.BackgroundColor3 =
				C.bg


			card.BackgroundTransparency =
				0.02


			corner(
				card,
				16
			)


			stroke(
				card,
				C.loss,
				0.35,
				1.5
			)


			for _, child in ipairs(
				card:GetDescendants()
			) do

				styleText(
					child
				)

			end


			local continue =
				card:FindFirstChild(
					"ContinueButton"
				)


			if continue then

				continue.BackgroundColor3 =
					C.good


				continue.TextColor3 =
					C.bg


				continue.Font =
					FONT_BOLD


				corner(
					continue,
					10
				)

			end

		end

	end


	styleChildrenText(
		gui
	)

end



------------------------------------------------------------
-- TREE: SUBLEVEL CHIP
------------------------------------------------------------

local function styleTreeLevelUI(
	gui
)

	gui.DisplayOrder =
		100


	local function chip(
		object
	)

		if not object
			or not object:IsA(
				"TextLabel"
			)
		then

			return

		end


		object.AnchorPoint =
			Vector2.new(
				0.5,
				0
			)


		object.Position =
			UDim2.new(
				0.5,
				0,
				0,
				72
			)


		object.Size =
			UDim2.fromOffset(
				380,
				38
			)


		object.BackgroundColor3 =
			C.bg


		object.BackgroundTransparency =
			0.08


		object.TextColor3 =
			C.c


		object.Font =
			FONT_BOLD


		object.TextSize =
			18


		corner(
			object,
			10
		)


		stroke(
			object,
			C.c,
			0.55,
			1
		)

	end


	chip(
		gui:FindFirstChild(
			"SublevelLabel"
		)
	)


	chip(
		gui:FindFirstChild(
			"LevelCompleteLabel"
		)
	)

end



------------------------------------------------------------
-- TREE: PREVIOUS / NEXT
------------------------------------------------------------

local function styleTreeNavigation(
	gui
)

	gui.DisplayOrder =
		180


	local previous =
		gui:FindFirstChild(
			"PreviousSublevelButton"
		)


	local nextButton =
		gui:FindFirstChild(
			"NextSublevelButton"
		)


	if previous then

		previous.Position =
			UDim2.fromOffset(
				18,
				82
			)


		previous.Size =
			UDim2.fromOffset(
				255,
				42
			)


		previous.TextSize =
			14


		styleButton(
			previous,
			C.loss
		)

	end


	if nextButton then

		nextButton.Position =
			UDim2.fromOffset(
				18,
				132
			)


		nextButton.Size =
			UDim2.fromOffset(
				255,
				42
			)


		nextButton.TextSize =
			14


		styleButton(
			nextButton,
			C.good
		)

	end

end



------------------------------------------------------------
-- TREE: SORTING UI
------------------------------------------------------------

local function styleDecisionTree(
	gui
)

	gui.DisplayOrder =
		90


	local condition =
		gui:FindFirstChild(
			"ConditionLabel"
		)


	local data =
		gui:FindFirstChild(
			"DataLabel"
		)


	local feedback =
		gui:FindFirstChild(
			"FeedbackLabel"
		)


	local items = {

		{
			condition,
			112,
			330,
			38
		},

		{
			data,
			158,
			260,
			36
		},

		{
			feedback,
			202,
			260,
			42
		},

	}


	for _, info in ipairs(
		items
	) do

		local object =
			info[1]


		if object then

			object.AnchorPoint =
				Vector2.new(
					0.5,
					0
				)


			object.Position =
				UDim2.new(
					0.5,
					0,
					0,
					info[2]
				)


			object.Size =
				UDim2.fromOffset(
					info[3],
					info[4]
				)


			object.BackgroundColor3 =
				C.bg


			object.BackgroundTransparency =
				0.08


			object.Font =
				FONT_BOLD


			object.TextColor3 =
				C.text


			corner(
				object,
				10
			)


			stroke(
				object,
				C.loss,
				0.68,
				1
			)

		end

	end


	local restart =
		gui:FindFirstChild(
			"RestartButton"
		)


	if restart then

		--------------------------------
		-- Hide local duplicate if our
		-- global RESET already exists.
		--------------------------------

		local levelFlow =
			playerGui:FindFirstChild(
				"LevelFlowUI"
			)


		local globalReset =
			levelFlow
			and levelFlow:FindFirstChild(
				"ResetButton",
				true
			)


		if globalReset then

			restart.Visible =
				false

		else

			restart.Position =
				UDim2.new(
					1,
					-18,
					0,
					82
				)


			restart.Size =
				UDim2.fromOffset(
					130,
					40
				)


			styleButton(
				restart,
				C.residual
			)

		end

	end

end



------------------------------------------------------------
-- TREE: ENTROPY / GINI
------------------------------------------------------------

local function styleImpurity(
	gui
)

	gui.DisplayOrder =
		80


	local panel =
		gui:FindFirstChild(
			"BottomPanel",
			true
		)


	if not panel
		or not panel:IsA("Frame")
	then

		return

	end


	panel.BackgroundColor3 =
		C.bg


	panel.BackgroundTransparency =
		0.13


	corner(
		panel,
		16
	)


	local title =
		panel:FindFirstChild(
			"Title"
		)


	local accent =
		C.c


	if title
		and title:IsA(
			"TextLabel"
		)
	then

		if not isGray(
			title.TextColor3
		) then

			accent =
				title.TextColor3

		else

			title.TextColor3 =
				accent

		end


		title.Font =
			FONT_BOLD

	end


	stroke(
		panel,
		accent,
		0.42,
		1.5
	)


	local formula =
		panel:FindFirstChild(
			"Formula"
		)


	if formula
		and formula:IsA(
			"TextLabel"
		)
	then

		formula.BackgroundColor3 =
			C.panel2


		formula.BackgroundTransparency =
			0.08


		formula.Font =
			FONT_BOLD


		corner(
			formula,
			10
		)

	end


	local counter =
		panel:FindFirstChild(
			"Counter"
		)


	if counter
		and counter:IsA(
			"TextLabel"
		)
	then

		counter.BackgroundColor3 =
			C.panel2


		counter.BackgroundTransparency =
			0.06


		counter.Font =
			FONT_BOLD


		corner(
			counter,
			10
		)

	end


	local intro =
		gui:FindFirstChild(
			"IntroPanel",
			true
		)


	if intro
		and intro:IsA(
			"Frame"
		)
	then

		intro.BackgroundColor3 =
			C.bg


		intro.BackgroundTransparency =
			0.03


		corner(
			intro,
			16
		)


		stroke(
			intro,
			accent,
			0.38,
			1.5
		)


		local start =
			intro:FindFirstChild(
				"StartButton",
				true
			)


		if start then

			start.BackgroundColor3 =
				C.good


			start.TextColor3 =
				C.bg


			start.Font =
				FONT_BOLD


			corner(
				start,
				10
			)

		end

	end


	styleChildrenText(
		gui
	)

end



------------------------------------------------------------
-- TREE: MACRO F1
------------------------------------------------------------

local function styleMacroF1(
	gui
)

	gui.DisplayOrder =
		80


	local panel =
		gui:FindFirstChild(
			"TaskPanel",
			true
		)


	if panel
		and panel:IsA("Frame")
	then

		panel.BackgroundColor3 =
			C.bg


		panel.BackgroundTransparency =
			0.10


		corner(
			panel,
			16
		)


		stroke(
			panel,
			C.c,
			0.42,
			1.5
		)

	end


	local intro =
		gui:FindFirstChild(
			"Intro",
			true
		)


	if intro
		and intro:IsA("Frame")
	then

		intro.BackgroundColor3 =
			C.bg


		intro.BackgroundTransparency =
			0.03


		corner(
			intro,
			18
		)


		stroke(
			intro,
			C.c,
			0.35,
			1.5
		)

	end


	local hover =
		gui:FindFirstChild(
			"ObjectData",
			true
		)


	if hover
		and hover:IsA("Frame")
	then

		hover.BackgroundColor3 =
			C.bg


		hover.BackgroundTransparency =
			0.06


		corner(
			hover,
			10
		)


		stroke(
			hover,
			C.loss,
			0.45,
			1
		)

	end


	styleChildrenText(
		gui
	)

end



------------------------------------------------------------
-- TREE COMPLETION POPUP
------------------------------------------------------------

local function styleTreeCompletion(
	gui
)

	for _, object in ipairs(
		gui:GetDescendants()
	) do

		if object:IsA(
			"Frame"
		) then

			if object.BackgroundTransparency
				< 0.95
			then

				object.BackgroundColor3 =
					C.bg


				corner(
					object,
					14
				)

			end


		elseif object:IsA(
			"TextButton"
		) then

			styleButton(
				object,
				C.good
			)


		else

			styleText(
				object
			)

		end

	end

end



------------------------------------------------------------
-- DBSCAN
------------------------------------------------------------

local function styleDBSCAN(
	gui
)

	gui.DisplayOrder =
		70


	local frames = {}


	for _, child in ipairs(
		gui:GetChildren()
	) do

		if child:IsA(
			"Frame"
		) then

			table.insert(
				frames,
				child
			)

		end

	end


	--------------------------------
	-- TOP-LEVEL PANELS
	--------------------------------

	for _, frame in ipairs(
		frames
	) do

		local sx =
			frame.Size.X.Offset


		local sy =
			frame.Size.Y.Offset


		--------------------------------
		-- epsilon HUD: originally
		-- 400 x 80 at top center
		--------------------------------

		if sx == 400
			and sy == 80
		then

			frame.Position =
				UDim2.new(
					0.5,
					-200,
					0,
					74
				)


			frame.BackgroundColor3 =
				C.bg


			frame.BackgroundTransparency =
				0.08


			corner(
				frame,
				12
			)


			stroke(
				frame,
				C.loss,
				0.42,
				1.5
			)


		--------------------------------
		-- instructions
		--------------------------------

		elseif sx == 280
			and sy == 250
		then

			frame.Position =
				UDim2.new(
					0,
					12,
					0,
					168
				)


			frame.BackgroundColor3 =
				C.bg


			frame.BackgroundTransparency =
				0.08


			corner(
				frame,
				12
			)


			stroke(
				frame,
				C.good,
				0.48,
				1.25
			)


		--------------------------------
		-- cluster cards panel
		--------------------------------

		elseif sx == 280
			and sy == 300
		then

			frame.Position =
				UDim2.new(
					1,
					-292,
					0,
					168
				)


			frame.BackgroundColor3 =
				C.bg


			frame.BackgroundTransparency =
				0.08


			corner(
				frame,
				12
			)


			stroke(
				frame,
				C.penalty,
				0.48,
				1.25
			)


		--------------------------------
		-- other substantial panels
		--------------------------------

		elseif sx >= 300
			and (
				sy >= 100
				or sy == 0
			)
		then

			frame.BackgroundColor3 =
				C.bg


			frame.BackgroundTransparency =
				math.min(
					frame.BackgroundTransparency,
					0.08
				)


			corner(
				frame,
				14
			)

		end

	end


	--------------------------------
	-- TEXT / BUTTONS / INNER PANELS
	--------------------------------

	for _, object in ipairs(
		gui:GetDescendants()
	) do

		if object:IsA(
			"TextLabel"
		) then

			styleText(
				object
			)


		elseif object:IsA(
			"TextButton"
		) then

			local text =
				string.upper(
					object.Text or ""
				)


			if string.find(
				text,
				"RESET",
				1,
				true
			)
				or string.find(
					text,
					"СБРОС",
					1,
					true
				)
			then

				styleButton(
					object,
					C.residual
				)


			elseif string.find(
				text,
				"CHECK",
				1,
				true
			)
				or string.find(
					text,
					"ПРОВЕР",
					1,
					true
				)
			then

				object.BackgroundColor3 =
					C.good


				object.TextColor3 =
					C.bg


				object.Font =
					FONT_BOLD


				corner(
					object,
					10
				)


			else

				styleButton(
					object,
					C.loss
				)

			end


		elseif object:IsA(
			"Frame"
		) then

			--------------------------------
			-- don't destroy slider / tiny
			-- visualization frames
			--------------------------------

			if object.Size.Y.Offset >= 28
				and object.BackgroundTransparency
					< 0.95
				and object.Parent
					~= gui
			then

				if isGray(
					object.BackgroundColor3
				)
				then

					object.BackgroundColor3 =
						C.panel2

				end


				corner(
					object,
					8
				)

			end

		end

	end

end



------------------------------------------------------------
-- LEGACY TYCOON HUD
------------------------------------------------------------

local function styleMainUI(
	gui
)

	local hud =
		gui:FindFirstChild(
			"HUD"
		)


	if not hud
		or not hud:IsA(
			"GuiObject"
		)
	then

		return

	end


	hud.BackgroundColor3 =
		C.bg


	hud.BackgroundTransparency =
		0.12


	corner(
		hud,
		10
	)


	stroke(
		hud,
		C.panel2,
		0.72,
		1
	)


	styleChildrenText(
		hud
	)

end



------------------------------------------------------------
-- DISPATCH
------------------------------------------------------------

local function apply(
	gui
)

	if not gui
		or not gui.Parent
	then

		return

	end


	local name =
		gui.Name


	if name ==
		"LevelFlowUI"
	then

		styleLevelFlow(
			gui
		)


	elseif name ==
		"TreeLevelUI"
	then

		styleTreeLevelUI(
			gui
		)


	elseif name ==
		"TreeLevelNavigationUI"
	then

		styleTreeNavigation(
			gui
		)


	elseif name ==
		"DecisionTreeLevelUI"
	then

		styleDecisionTree(
			gui
		)


	elseif name ==
			"EntropyLevelGui"
		or name ==
			"GiniLevelGui"
	then

		styleImpurity(
			gui
		)


	elseif name ==
		"MacroF1LevelGui"
	then

		styleMacroF1(
			gui
		)


	elseif name ==
		"DecisionTreeCompletionGui"
	then

		styleTreeCompletion(
			gui
		)


	elseif name ==
		"DBSCAN_UI"
	then

		styleDBSCAN(
			gui
		)


	elseif name ==
		"MainUI"
	then

		styleMainUI(
			gui
		)

	end

end



------------------------------------------------------------
-- EXISTING UI
------------------------------------------------------------

local function applyAll()

	for _, object in ipairs(
		playerGui:GetChildren()
	) do

		if object:IsA(
			"ScreenGui"
		) then

			apply(
				object
			)

		end

	end

end



------------------------------------------------------------
-- UI CREATED LATER
------------------------------------------------------------

playerGui.ChildAdded:Connect(
	function(object)

		if not object:IsA(
			"ScreenGui"
		) then

			return

		end


		task.defer(
			function()

				task.wait(
					0.05
				)


				apply(
					object
				)

			end
		)


		task.delay(
			0.5,
			function()

				if object.Parent then

					apply(
						object
					)

				end

			end
		)

	end
)



------------------------------------------------------------
-- SOME UIs BUILD THEIR CHILDREN AFTER SCREEN GUI CREATION
------------------------------------------------------------

playerGui.DescendantAdded:Connect(
	function(object)

		local root =
			object:FindFirstAncestorWhichIsA(
				"ScreenGui"
			)


		if not root then
			return
		end


		local name =
			root.Name


		if name == "DBSCAN_UI"
			or name == "DecisionTreeLevelUI"
			or name == "EntropyLevelGui"
			or name == "GiniLevelGui"
			or name == "MacroF1LevelGui"
		then

			task.delay(
				0.05,
				function()

					if root.Parent then

						apply(
							root
						)

					end

				end
			)

		end

	end
)



------------------------------------------------------------
-- INITIAL
------------------------------------------------------------

task.wait(
	0.2
)


applyAll()


print(
	"[UnifiedUI] Regression-style skin active"
)
