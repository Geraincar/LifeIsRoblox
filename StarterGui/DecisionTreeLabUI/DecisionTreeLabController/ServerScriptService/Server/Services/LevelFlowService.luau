local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)


local Workspace =
	game:GetService(
		"Workspace"
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


local continueRemote =
	remotes:WaitForChild(
		"LevelFlowContinue"
	)


local hiveOpenRemote =
	remotes:WaitForChild(
		"HiveControlOpen"
	)


local Service = {}


local started =
	false



------------------------------------------------------------
-- LEVEL -> METHOD
------------------------------------------------------------

local LEVEL_TO_METHOD = {

	regression =
		"regression",

	decision_tree =
		"tree",

	dbscan =
		"clustering",

}



------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function getIndex(
	levelId
)

	for index, id in ipairs(
		Config.Order
	) do

		if id == levelId then
			return index
		end

	end


	return nil

end



local function getNextLevel(
	levelId
)

	local index =
		getIndex(
			levelId
		)


	if not index then
		return nil
	end


	return
		Config.Order[
			index + 1
		]

end



local function getName(
	levelId
)

	local level =
		Config.Levels[
			levelId
		]


	return
		level
		and level.Name
		or levelId

end



local function isActive(
	player,
	levelId
)

	return
		player:GetAttribute(
			"ActiveLevel"
		)
		== levelId

end



------------------------------------------------------------
-- ENTRY
------------------------------------------------------------

local function getEntry(
	levelId
)

	local level =
		Config.Levels[
			levelId
		]


	if not level then
		return nil
	end


	local entries =
		Workspace:FindFirstChild(
			"LevelFlowEntries"
		)


	if not entries then
		return nil
	end


	local entry =
		entries:FindFirstChild(
			level.EntryPoint
		)


	if entry
		and entry:IsA(
			"BasePart"
		)
	then

		return entry

	end


	return nil

end



------------------------------------------------------------
-- LESSON FINISHED
--
-- IMPORTANT:
-- This DOES NOT require hive application.
------------------------------------------------------------

local function finishLesson(
	player,
	levelId,
	skipped
)

	if not player
		or player.Parent ~= Players
	then

		return false

	end


	if not isActive(
		player,
		levelId
	) then

		return false

	end


	local completeAttribute =
		"LevelFlowCompleted_"
		.. levelId


	--------------------------------
	-- ALREADY COUNTED
	--------------------------------

	if player:GetAttribute(
		completeAttribute
	) == true
	then

		return false

	end


	local methodId =
		LEVEL_TO_METHOD[
			levelId
		]


	if not methodId then

		warn(
			"[LevelFlow] Нет метода для:",
			levelId
		)

		return false

	end



	--------------------------------
	-- LEARNING COMPLETE
	--------------------------------

	player:SetAttribute(
		completeAttribute,
		true
	)


	player:SetAttribute(
		"HiveMethodUnlocked_"
			.. methodId,
		true
	)



	--------------------------------
	-- APPLICATION REMAINS OPTIONAL
	--------------------------------

	if player:GetAttribute(
		"HiveMethodApplied_"
			.. methodId
	) ~= true
	then

		player:SetAttribute(
			"HiveMethodPending_"
				.. methodId,
			true
		)

	else

		player:SetAttribute(
			"HiveMethodPending_"
				.. methodId,
			false
		)

	end



	--------------------------------
	-- NEXT LESSON IS IMMEDIATELY
	-- AVAILABLE
	--------------------------------

	local nextLevel =
		getNextLevel(
			levelId
		)


	player:SetAttribute(
		"LevelFlowPendingNext",
		nextLevel
	)



	--------------------------------
	-- LAST LEARNED METHOD
	--------------------------------

	player:SetAttribute(
		"HiveLastLearnedMethod",
		methodId
	)



	if skipped then

		print(
			"[LevelFlow] УРОК ПРОПУЩЕН:",
			player.Name,
			levelId
		)

	else

		print(
			"[LevelFlow] УРОК ЗАВЕРШЁН:",
			player.Name,
			levelId
		)

	end


	print(
		"[HiveControl] Метод открыт:",
		methodId
	)


	if nextLevel then

		print(
			"[LevelFlow] Следующий метод доступен:",
			getName(
				nextLevel
			)
		)

	else

		print(
			"[LevelFlow] Все методы изучены"
		)

	end



	--------------------------------
	-- OPEN HIVE CONTROL
	--------------------------------

	hiveOpenRemote:FireClient(
		player,
		methodId
	)


	return true

end



------------------------------------------------------------
-- PUBLIC COMPLETION
--
-- Kept for compatibility with existing scripts.
------------------------------------------------------------

function Service.CompleteLevel(
	player,
	levelId
)

	return finishLesson(
		player,
		levelId,
		false
	)

end



------------------------------------------------------------
-- SKIP
------------------------------------------------------------

function Service.SkipLesson(
	player
)

	local levelId =
		player:GetAttribute(
			"ActiveLevel"
		)


	if type(levelId)
		~= "string"
	then

		return false

	end


	return finishLesson(
		player,
		levelId,
		true
	)

end



------------------------------------------------------------
-- ACTIVATE LEVEL
------------------------------------------------------------

local function activateLevel(
	player,
	levelId
)

	if not Config.Levels[
		levelId
	] then

		return

	end


	player:SetAttribute(
		"LevelFlowTargetLevel",
		nil
	)


	player:SetAttribute(
		"ActiveLevel",
		levelId
	)


	print(
		"[LevelFlow] ARRIVED:",
		player.Name,
		levelId
	)



	--------------------------------
	-- SAVED TREE PROGRESS MAY
	-- ALREADY BE COMPLETE
	--------------------------------

	if levelId
		== "decision_tree"
	then

		task.delay(
			0.25,
			function()

				if not player.Parent then
					return
				end


				local progress =
					tonumber(
						player:GetAttribute(
							"TreeLevelProgress"
						)
					)
					or 0


				if progress >= 4 then

					finishLesson(
						player,
						"decision_tree",
						false
					)

				end

			end
		)

	end

end



------------------------------------------------------------
-- NAVIGATE
------------------------------------------------------------

local function navigateTo(
	player,
	levelId
)

	if not Config.Levels[
		levelId
	] then

		return

	end


	player:SetAttribute(
		"ActiveLevel",
		""
	)


	player:SetAttribute(
		"LevelFlowTargetLevel",
		levelId
	)


	print(
		"[LevelFlow] ИДТИ К:",
		player.Name,
		levelId
	)

end



------------------------------------------------------------
-- ARRIVAL WATCH
------------------------------------------------------------

local function startArrivalWatch(
	player
)

	task.spawn(
		function()

			while player.Parent do

				task.wait(
					0.2
				)


				local target =
					player:GetAttribute(
						"LevelFlowTargetLevel"
					)


				if type(target)
					~= "string"
					or target == ""
				then

					continue

				end


				local entry =
					getEntry(
						target
					)


				local character =
					player.Character


				local root =
					character
					and character
						:FindFirstChild(
							"HumanoidRootPart"
						)


				if not entry
					or not root
				then

					continue

				end


				local distance =
					(
						root.Position
						- entry.Position
					).Magnitude


				if distance
					<= (
						Config.ArrivalDistance
						or 14
					)
				then

					activateLevel(
						player,
						target
					)

				end

			end

		end
	)

end



------------------------------------------------------------
-- REGRESSION
------------------------------------------------------------

local function bindRegression()

	local regressionRemote =
		remotes:FindFirstChild(
			"RegressionProgress"
		)


	if not regressionRemote then

		regressionRemote =
			ReplicatedStorage
				:FindFirstChild(
					"RegressionProgress",
					true
				)

	end


	if not regressionRemote
		or not regressionRemote:IsA(
			"RemoteEvent"
		)
	then

		warn(
			"[LevelFlow] RegressionProgress не найден"
		)

		return

	end


	regressionRemote.OnServerEvent:Connect(
		function(
			player,
			milestone
		)

			if milestone
				== "regression_lore"
				and isActive(
					player,
					"regression"
				)
			then

				finishLesson(
					player,
					"regression",
					false
				)

			end

		end
	)

end



------------------------------------------------------------
-- DECISION TREE
------------------------------------------------------------

local function checkTree(
	player
)

	if not isActive(
		player,
		"decision_tree"
	) then

		return

	end


	local progress =
		tonumber(
			player:GetAttribute(
				"TreeLevelProgress"
			)
		)
		or 0


	if progress >= 4 then

		finishLesson(
			player,
			"decision_tree",
			false
		)

	end

end



local function watchTree(
	player
)

	player:GetAttributeChangedSignal(
		"TreeLevelProgress"
	)
	:Connect(
		function()

			checkTree(
				player
			)

		end
	)

end



------------------------------------------------------------
-- DBSCAN / CLUSTERING
------------------------------------------------------------

local function dbscanIsComplete()

	local level =
		Workspace:FindFirstChild(
			"DBSCANLevel"
		)


	if not level then
		return false
	end


	local bees =
		level:FindFirstChild(
			"Bees"
		)


	if not bees then
		return false
	end


	local count = 0


	for _, bee in ipairs(
		bees:GetChildren()
	) do

		if bee:IsA(
			"BasePart"
		)
			and bee:GetAttribute(
				"BeeId"
			) ~= nil
		then

			count += 1


			local beeState =
				bee:GetAttribute(
					"BeeState"
				)
				or "Unassigned"


			if beeState
				== "Unassigned"
				or beeState
					== "Noise"
			then

				return false

			end

		end

	end


	return count > 0

end



local function bindDBSCAN()

	local folder =
		ReplicatedStorage
			:FindFirstChild(
				"DBSCAN_Remotes"
			)


	if not folder then
		return
	end


	local checkRemote =
		folder:FindFirstChild(
			"CheckComplete"
		)


	if not checkRemote
		or not checkRemote:IsA(
			"RemoteEvent"
		)
	then

		return

	end


	checkRemote.OnServerEvent:Connect(
		function(player)

			if not isActive(
				player,
				"dbscan"
			) then

				return

			end


			task.delay(
				0.15,
				function()

					if dbscanIsComplete() then

						finishLesson(
							player,
							"dbscan",
							false
						)

					end

				end
			)

		end
	)

end



------------------------------------------------------------
-- CONTINUE TO NEXT METHOD
------------------------------------------------------------

continueRemote.OnServerEvent:Connect(
	function(player)

		local nextLevel =
			player:GetAttribute(
				"LevelFlowPendingNext"
			)


		if type(nextLevel)
			~= "string"
		then

			return

		end


		if not Config.Levels[
			nextLevel
		] then

			return

		end


		player:SetAttribute(
			"LevelFlowPendingNext",
			nil
		)


		navigateTo(
			player,
			nextLevel
		)

	end
)



------------------------------------------------------------
-- PLAYER
------------------------------------------------------------

local function setupPlayer(
	player
)

	player:SetAttribute(
		"ActiveLevel",
		""
	)


	player:SetAttribute(
		"LevelFlowPendingNext",
		nil
	)


	player:SetAttribute(
		"LevelFlowTargetLevel",
		"regression"
	)


	watchTree(
		player
	)


	startArrivalWatch(
		player
	)


	print(
		"[LevelFlow] START -> Регрессия"
	)

end



------------------------------------------------------------
-- START
------------------------------------------------------------

function Service.Start()

	if started then
		return
	end


	started =
		true


	bindRegression()
	bindDBSCAN()


	Players.PlayerAdded:Connect(
		setupPlayer
	)


	for _, player in ipairs(
		Players:GetPlayers()
	) do

		setupPlayer(
			player
		)

	end


	print(
		"[LevelFlow] V5 started — обучение и применение разделены"
	)

end



return Service
