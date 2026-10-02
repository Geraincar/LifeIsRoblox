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


local gui =
	playerGui:WaitForChild(
		"HiveControlUI"
	)


local overlay =
	gui:WaitForChild(
		"Overlay"
	)


local window =
	overlay:WaitForChild(
		"Window"
	)


local button =
	window:WaitForChild(
		"NextMethodButton"
	)


local continueRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"LevelFlowContinue"
		)



------------------------------------------------------------
-- NAMES
------------------------------------------------------------

local BUTTON_TEXT = {

	decision_tree =
		"ИЗУЧИТЬ РЕШАЮЩЕЕ ДЕРЕВО →",

	dbscan =
		"ИЗУЧИТЬ КЛАСТЕРИЗАЦИЮ →",

}



------------------------------------------------------------
-- UPDATE
------------------------------------------------------------

local function update()

	local nextLevel =
		player:GetAttribute(
			"LevelFlowPendingNext"
		)


	if type(nextLevel)
		== "string"
		and BUTTON_TEXT[
			nextLevel
		]
	then

		button.Text =
			BUTTON_TEXT[
				nextLevel
			]


		button.Visible =
			true


	else

		button.Visible =
			false

	end

end



------------------------------------------------------------
-- CLICK
------------------------------------------------------------

button.MouseButton1Click
	:Connect(
		function()

			if not button.Visible then
				return
			end


			button.Active =
				false


			continueRemote:FireServer()


			--------------------------------
			-- Close Hive Control.
			-- LevelFlow arrow appears again.
			--------------------------------

			overlay.Visible =
				false


			task.delay(
				0.7,
				function()

					button.Active =
						true

					update()

				end
			)

		end
	)



------------------------------------------------------------
-- ATTRIBUTE
------------------------------------------------------------

player:GetAttributeChangedSignal(
	"LevelFlowPendingNext"
)
:Connect(
	update
)


overlay:GetPropertyChangedSignal(
	"Visible"
)
:Connect(
	update
)


update()


print(
	"[HiveControl] Next method button ready"
)
