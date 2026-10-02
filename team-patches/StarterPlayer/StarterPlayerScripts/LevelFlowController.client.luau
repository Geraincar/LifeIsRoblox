local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)


local RunService =
	game:GetService(
		"RunService"
	)


local Workspace =
	game:GetService(
		"Workspace"
	)


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local playerScripts =
	player:WaitForChild(
		"PlayerScripts"
	)


local Config =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild(
				"LevelFlowConfig"
			)
	)


local remotes =
	ReplicatedStorage
		:WaitForChild("Remotes")


local showRemote =
	remotes:WaitForChild(
		"LevelFlowShow"
	)


local continueRemote =
	remotes:WaitForChild(
		"LevelFlowContinue"
	)


--------------------------------------------------
-- UI
--------------------------------------------------

local gui =
	playerGui:WaitForChild(
		"LevelFlowUI"
	)


local status =
	gui:WaitForChild(
		"Status"
	)


local levelLabel =
	status:WaitForChild(
		"LevelLabel"
	)


local hintLabel =
	status:WaitForChild(
		"HintLabel"
	)


local navigation =
	gui:WaitForChild(
		"Navigation"
	)


local arrow =
	navigation:WaitForChild(
		"Arrow"
	)


local destinationLabel =
	navigation:WaitForChild(
		"DestinationLabel"
	)


local distanceLabel =
	navigation:WaitForChild(
		"DistanceLabel"
	)


local overlay =
	gui:WaitForChild(
		"Overlay"
	)


local card =
	overlay:WaitForChild(
		"Card"
	)


local completedLabel =
	card:WaitForChild(
		"CompletedLabel"
	)


local nextLabel =
	card:WaitForChild(
		"NextLabel"
	)


local continueButton =
	card:WaitForChild(
		"ContinueButton"
	)


local skipButton =
	status:FindFirstChild(
		"SkipButton"
	)



--------------------------------------------------
-- MAP
--------------------------------------------------

local levelIndex = {

	regression = 1,

	decision_tree = 2,

	dbscan = 3,

}


local levelNames = {

	regression =
		"РЕГРЕССИЯ",

	decision_tree =
		"РЕШАЮЩЕЕ ДЕРЕВО",

	dbscan =
		"КЛАСТЕРИЗАЦИЯ",

}


local SCRIPT_LEVELS = {

	RegressionClient =
		"regression",

	TreeLevelClient =
		"decision_tree",

	TreeLevelNavigationController =
		"decision_tree",

	DBSCAN_RadarClient =
		"dbscan",

}


local ALWAYS_DISABLED = {

	TreeLevelDebugControls =
		true,

	WorldLessonController =
		true,

	DataConsoleController =
		true,

}



--------------------------------------------------
-- SCRIPT GATING
--------------------------------------------------

local function applyScriptState(
	object,
	activeLevel
)

	if not object:IsA(
		"LocalScript"
	) then

		return

	end


	if ALWAYS_DISABLED[
		object.Name
	] then

		object.Enabled =
			false

		return

	end


	local required =
		SCRIPT_LEVELS[
			object.Name
		]


	if required then

		object.Enabled =
			activeLevel
				== required

	end

end



local function updateScripts(
	activeLevel
)

	for _, object in ipairs(
		playerScripts:GetDescendants()
	) do

		applyScriptState(
			object,
			activeLevel
		)

	end

end



--------------------------------------------------
-- STATUS
--------------------------------------------------

local function updateStatus()

	local active =
		player:GetAttribute(
			"ActiveLevel"
		)


	local target =
		player:GetAttribute(
			"LevelFlowTargetLevel"
		)


	if type(active) == "string"
		and Config.Levels[active]
	then

		local index =
			levelIndex[
				active
			]
			or 1


		levelLabel.Text =
			tostring(index)
			.. " / 3  •  "
			.. (
				levelNames[
					active
				]
				or string.upper(
					active
				)
			)


		if active
			== "regression"
		then

			hintLabel.Text =
				"Завершите модуль по регрессии"


		elseif active
			== "decision_tree"
		then

			hintLabel.Text =
				"Завершите все 4 подуровня дерева"


		elseif active
			== "dbscan"
		then

			hintLabel.Text =
				"Завершите модуль кластеризации"

		end


		if skipButton then

			skipButton.Visible =
				true

		end


	else

		levelLabel.Text =
			"ИДИТЕ К СЛЕДУЮЩЕМУ УРОВНЮ"


		hintLabel.Text =
			"Следуйте по стрелке"


		if skipButton then

			skipButton.Visible =
				false

		end

	end


	updateScripts(
		active or ""
	)


	navigation.Visible =
		type(target) == "string"
		and Config.Levels[
			target
		] ~= nil

end



--------------------------------------------------
-- FIND TARGET ENTRY
--------------------------------------------------

local function getTargetEntry()

	local target =
		player:GetAttribute(
			"LevelFlowTargetLevel"
		)


	if type(target)
		~= "string"
	then

		return nil, nil
	end


	local level =
		Config.Levels[
			target
		]


	if not level then

		return nil, nil

	end


	local entries =
		Workspace:FindFirstChild(
			"LevelFlowEntries"
		)


	if not entries then

		return nil, nil

	end


	return

		entries:FindFirstChild(
			level.EntryPoint
		),

		target

end



--------------------------------------------------
-- WORLD DESTINATION MARKER
--------------------------------------------------

local marker =
	Instance.new("BillboardGui")


marker.Name =
	"LevelDestinationMarker"


marker.Size =
	UDim2.fromOffset(
		220,
		55
	)


marker.StudsOffset =
	Vector3.new(
		0,
		5,
		0
	)


marker.AlwaysOnTop =
	true


marker.Enabled =
	false


marker.Parent =
	gui


local markerLabel =
	Instance.new("TextLabel")


markerLabel.Size =
	UDim2.fromScale(
		1,
		1
	)


markerLabel.BackgroundColor3 =
	Color3.fromRGB(
		24,
		27,
		33
	)


markerLabel.BackgroundTransparency =
	0.1


markerLabel.BorderSizePixel =
	0


markerLabel.TextColor3 =
	Color3.fromRGB(
		235,
		190,
		66
	)


markerLabel.TextSize =
	18


markerLabel.Font =
	Enum.Font.GothamBold


markerLabel.Parent =
	marker


local markerCorner =
	Instance.new("UICorner")


markerCorner.CornerRadius =
	UDim.new(
		0,
		10
	)


markerCorner.Parent =
	markerLabel



--------------------------------------------------
-- ARROW UPDATE
--------------------------------------------------

RunService.RenderStepped
	:Connect(
		function()

			local entry,
				target =
				getTargetEntry()


			if not entry
				or not entry:IsA(
					"BasePart"
				)
			then

				navigation.Visible =
					false

				marker.Enabled =
					false

				return

			end


			navigation.Visible =
				true


			marker.Adornee =
				entry


			marker.Enabled =
				true


			local displayName =
				Config.Levels[
					target
				].Name
				or target


			markerLabel.Text =
				string.upper(
					displayName
				)


			destinationLabel.Text =
				"К УРОВНЮ: "
				.. string.upper(
					displayName
				)



			--------------------------------
			-- DISTANCE
			--------------------------------

			local character =
				player.Character


			local root =
				character
				and character
					:FindFirstChild(
						"HumanoidRootPart"
					)


			if root then

				local distance =
					(
						entry.Position
						- root.Position
					).Magnitude


				distanceLabel.Text =
					tostring(
						math.floor(
							distance
							+ 0.5
						)
					)
					.. " м до цели"

			else

				distanceLabel.Text =
					"Find the marked area"

			end



			--------------------------------
			-- DIRECTION RELATIVE TO CAMERA
			--------------------------------

			local camera =
				Workspace.CurrentCamera


			if not camera then
				return
			end


			local localPosition =
				camera.CFrame
					:PointToObjectSpace(
						entry.Position
					)


			local angle =
				math.atan2(
					localPosition.X,
					-localPosition.Z
				)


			arrow.Rotation =
				math.deg(
					angle
				)

		end
	)



--------------------------------------------------
-- NEW SCRIPTS
--------------------------------------------------

playerScripts.DescendantAdded
	:Connect(
		function(object)

			task.defer(
				function()

					if not object.Parent then
						return
					end


					applyScriptState(

						object,

						player:GetAttribute(
							"ActiveLevel"
						)
							or ""

					)

				end
			)

		end
	)



--------------------------------------------------
-- ACTIVE/TARGET CHANGES
--------------------------------------------------

player:GetAttributeChangedSignal(
	"ActiveLevel"
)
:Connect(
	updateStatus
)


player:GetAttributeChangedSignal(
	"LevelFlowTargetLevel"
)
:Connect(
	updateStatus
)



--------------------------------------------------
-- COMPLETE UI
--------------------------------------------------

showRemote.OnClientEvent
	:Connect(
		function(data)

			completedLabel.Text =
				tostring(
					data.CompletedName
						or "Level"
				)
				.. " completed"


			if data.Skipped then

				completedLabel.Text =
					tostring(
						data.CompletedName
							or "Level"
					)
					.. " skipped"

			end


			if data.IsFinal then

				nextLabel.Text =
					"Все учебные модули завершены"

				continueButton.Text =
					"DONE"

			else

				nextLabel.Text =
					"Next: "
					.. tostring(
						data.NextName
							or data.NextId
					)

				continueButton.Text =
					"ПОКАЗАТЬ ПУТЬ →"

			end


			overlay:SetAttribute(
				"IsFinal",
				data.IsFinal
			)


			overlay.Visible =
				true

		end
	)



--------------------------------------------------
-- CONTINUE
--------------------------------------------------

continueButton.MouseButton1Click
	:Connect(
		function()

			if overlay:GetAttribute(
				"IsFinal"
			) == true
			then

				overlay.Visible =
					false

				return

			end


			continueRemote:FireServer()


			overlay.Visible =
				false

		end
	)



--------------------------------------------------
-- START
--------------------------------------------------

overlay.Visible =
	false


updateStatus()
