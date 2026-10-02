local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)


local Players =
	game:GetService("Players")


local Config =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild(
				"HiveControlConfig"
			)
	)


local remotes =
	ReplicatedStorage
		:WaitForChild("Remotes")


local rpc =
	remotes:WaitForChild(
		"HiveControlRPC"
	)


local TycoonService =
	require(
		script.Parent
			:WaitForChild(
				"TycoonService"
			)
	)


local ProductionService =
	require(
		script.Parent
			:WaitForChild(
				"ProductionService"
			)
	)


local BeePopulationService =
	require(
		script.Parent
			:WaitForChild(
				"BeePopulationService"
			)
	)


local PopulationService =
	require(
		script.Parent
			:WaitForChild(
				"PopulationService"
			)
	)


local HiveControlService = {}


local started =
	false


local lastImpacts = {}



------------------------------------------------------------
-- STATE
------------------------------------------------------------

local function getState(
	player
)

	local candidates = {

		"GetState",

		"GetPlayerState",

		"GetTycoon",

		"Get",

	}


	for _, name in ipairs(
		candidates
	) do

		local fn =
			TycoonService[name]


		if type(fn)
			== "function"
		then

			local ok,
				result =
				pcall(
					fn,
					player
				)


			if ok
				and type(result)
					== "table"
			then

				return result

			end

		end

	end


	return nil

end



------------------------------------------------------------
-- RECALCULATE
------------------------------------------------------------

local function recalculateProduction(
	player
)

	local candidates = {

		"Recalculate",

		"RecalculateProduction",

		"UpdatePlayer",

		"Update",

	}


	for _, name in ipairs(
		candidates
	) do

		local fn =
			ProductionService[name]


		if type(fn)
			== "function"
		then

			local ok =
				pcall(
					fn,
					player
				)


			if ok then
				return
			end

		end

	end

end



local function recalculatePopulation(
	player
)

	local candidates = {

		"Recalculate",

		"RecalculatePlayer",

		"Update",

	}


	for _, name in ipairs(
		candidates
	) do

		local fn =
			PopulationService[name]


		if type(fn)
			== "function"
		then

			local ok =
				pcall(
					fn,
					player
				)


			if ok then
				return
			end

		end

	end

end



------------------------------------------------------------
-- METHOD STATE
------------------------------------------------------------

local function methodState(
	player,
	methodId
)

	return {

		Unlocked =
			player:GetAttribute(
				"HiveMethodUnlocked_"
					.. methodId
			)
			== true,

		Applied =
			player:GetAttribute(
				"HiveMethodApplied_"
					.. methodId
			)
			== true,

		Pending =
			player:GetAttribute(
				"HiveMethodPending_"
					.. methodId
			)
			== true,

	}

end



------------------------------------------------------------
-- SNAPSHOT
------------------------------------------------------------

local function snapshot(
	player
)

	local state =
		getState(
			player
		)


	if not state then

		return {

			Available =
				false,

		}

	end


	state.Optimization =
		state.Optimization
		or {}


	local stats =
		state.Stats
		or {}


	local production =
		state.Production
		or {}


	local population =
		state.Population
		or {}


	local summary =
		population.Summary
		or {}


	local jobs =
		summary.ByJob
		or {}


	local supplyFactor =
		state.Optimization.SupplyFactor
		or 1


	local processingFactor =
		state.Optimization.ProcessingFactor
		or 1


	local effectiveSupply =
		math.clamp(
			(stats.Supply or 0)
				* supplyFactor,
			0,
			1
		)


	local effectiveProcessing =
		math.clamp(
			(stats.Processing or 0)
				* processingFactor,
			0,
			1
		)


	return {

		Available =
			true,


		Honey =
			state.Resources
			and state.Resources.Honey
			or 0,


		HoneyRate =
			production.HoneyRate
			or 0,


		Efficiency =
			stats.Efficiency
			or 1,


		Stats = {

			Workforce =
				stats.Workforce
				or 0,

			Supply =
				stats.Supply
				or 0,

			Processing =
				stats.Processing
				or 0,

			EffectiveSupply =
				effectiveSupply,

			EffectiveProcessing =
				effectiveProcessing,

			Consumption =
				stats.Consumption
				or 1,

			HealthRisk =
				stats.HealthRisk
				or 0,

		},


		Jobs = {

			Forage =
				jobs.Forage
				or 0,

			HiveWork =
				jobs.HiveWork
				or 0,

			Rest =
				jobs.Rest
				or 0,

			Quarantine =
				jobs.Quarantine
				or 0,

			Unassigned =
				jobs.Unassigned
				or 0,

		},


		Methods = {

			regression =
				methodState(
					player,
					"regression"
				),

			tree =
				methodState(
					player,
					"tree"
				),

			clustering =
				methodState(
					player,
					"clustering"
				),

		},


		FieldPriorities =
			state.Optimization
				.FieldPriorities,


		RoutingAccuracy =
			state.Optimization
				.RoutingAccuracy,


		LastImpacts =
			lastImpacts[player],

	}

end



------------------------------------------------------------
-- REGRESSION
------------------------------------------------------------

local function applyRegression(
	player,
	state
)

	state.Optimization =
		state.Optimization
		or {}


	state.Optimization.SupplyFactor =
		Config.RegressionSupplyFactor


	state.Optimization.FieldPriorities = {

		A =
			Config.FieldPriorities.A,

		B =
			Config.FieldPriorities.B,

		C =
			Config.FieldPriorities.C,

		D =
			Config.FieldPriorities.D,

	}


	return {

		Text =
			"Приоритеты полей обновлены: A 20%, B 40%, C 10%, D 30%.",

	}

end



------------------------------------------------------------
-- DECISION TREE
------------------------------------------------------------

local function applyTree(
	player,
	state
)

	state.Optimization =
		state.Optimization
		or {}


	state.Optimization.ProcessingFactor =
		Config.TreeProcessingFactor


	state.Optimization.RoutingAccuracy =
		0.86


	return {

		Text =
			"Автоматическая сортировка партий включена. Ожидаемая точность маршрутизации: 86%.",

	}

end



------------------------------------------------------------
-- CLUSTERING
------------------------------------------------------------

local function feature(
	bee
)

	return {

		bee.Health
			or 0.5,

		bee.Activity
			or 0.5,

		bee.Consumption
			or 0.5,

		bee.Productivity
			or 0.5,

	}

end



local function distance(
	a,
	b
)

	local sum = 0


	for i = 1, 4 do

		local delta =
			a[i]
			- b[i]


		sum +=
			delta
			* delta

	end


	return math.sqrt(
		sum
	)

end



local function copyVector(
	v
)

	return {

		v[1],

		v[2],

		v[3],

		v[4],

	}

end



local function runClustering(
	player
)

	local all =
		BeePopulationService
			.GetAll
		and BeePopulationService
			.GetAll(
				player
			)


	if type(all)
		~= "table"
	then

		return nil,
			"Не удалось получить популяцию пчёл."

	end


	local bees = {}


	for beeId, bee in pairs(
		all
	) do

		if bee.Alive
			~= false
		then

			table.insert(
				bees,
				{

					Id =
						beeId,

					Bee =
						bee,

					X =
						feature(
							bee
						),

				}
			)

		end

	end


	if #bees < 3 then

		return nil,
			"Недостаточно пчёл для кластеризации."

	end


	--------------------------------
	-- deterministic initialization
	--------------------------------

	table.sort(
		bees,
		function(a, b)

			local sa =
				a.X[2]
				+ a.X[4]


			local sb =
				b.X[2]
				+ b.X[4]


			return sa < sb

		end
	)


	local centroids = {

		copyVector(
			bees[1].X
		),

		copyVector(
			bees[
				math.floor(
					#bees / 2
				)
			].X
		),

		copyVector(
			bees[#bees].X
		),

	}


	local assignments = {}


	--------------------------------
	-- K-MEANS
	--------------------------------

	for _ = 1, 8 do

		--------------------------------
		-- assign
		--------------------------------

		for i, item in ipairs(
			bees
		) do

			local bestCluster =
				1


			local bestDistance =
				math.huge


			for cluster = 1, 3 do

				local d =
					distance(
						item.X,
						centroids[
							cluster
						]
					)


				if d < bestDistance then

					bestDistance =
						d


					bestCluster =
						cluster

				end

			end


			assignments[i] =
				bestCluster

		end


		--------------------------------
		-- recompute
		--------------------------------

		local sums = {

			{0, 0, 0, 0},

			{0, 0, 0, 0},

			{0, 0, 0, 0},

		}


		local counts = {

			0,

			0,

			0,

		}


		for i, item in ipairs(
			bees
		) do

			local cluster =
				assignments[i]


			counts[cluster] +=
				1


			for featureIndex = 1, 4 do

				sums[cluster][featureIndex] +=
					item.X[
						featureIndex
					]

			end

		end


		for cluster = 1, 3 do

			if counts[cluster] > 0 then

				for featureIndex = 1, 4 do

					centroids[cluster][featureIndex] =
						sums[cluster][featureIndex]
						/ counts[cluster]

				end

			end

		end

	end



	------------------------------------------------
	-- INTERPRET CLUSTERS
	------------------------------------------------

	local forageCluster =
		1


	local forageScore =
		-math.huge


	for cluster = 1, 3 do

		local score =
			centroids[cluster][2]
			+
			centroids[cluster][4]


		if score > forageScore then

			forageScore =
				score


			forageCluster =
				cluster

		end

	end


	local hiveCluster =
		nil


	local hiveScore =
		-math.huge


	for cluster = 1, 3 do

		if cluster
			~= forageCluster
		then

			local score =
				centroids[cluster][1]
				+
				centroids[cluster][4]


			if score > hiveScore then

				hiveScore =
					score


				hiveCluster =
					cluster

			end

		end

	end


	local restCluster


	for cluster = 1, 3 do

		if cluster
			~= forageCluster
			and cluster
				~= hiveCluster
		then

			restCluster =
				cluster

			break

		end

	end


	local jobs = {

		[forageCluster] =
			"Forage",

		[hiveCluster] =
			"HiveWork",

		[restCluster] =
			"Rest",

	}


	local counts = {

		Forage =
			0,

		HiveWork =
			0,

		Rest =
			0,

	}



	------------------------------------------------
	-- APPLY REAL JOBS
	------------------------------------------------

	for i, item in ipairs(
		bees
	) do

		local job =
			jobs[
				assignments[i]
			]


		if job then

			if BeePopulationService.SetJob then

				pcall(
					BeePopulationService.SetJob,
					player,
					item.Id,
					job
				)

			end


			counts[job] +=
				1

		end

	end


	recalculatePopulation(
		player
	)


	return counts,
		nil

end



local function applyClustering(
	player,
	state
)

	local counts,
		err =
		runClustering(
			player
		)


	if not counts then

		return nil,
			err

	end


	state.Optimization =
		state.Optimization
		or {}


	state.Optimization.ClusterAssignments =
		counts


	return {

		Text =
			string.format(
				"Когорты назначены: сборщики — %d, работа в улье — %d, отдых — %d.",
				counts.Forage,
				counts.HiveWork,
				counts.Rest
			),

		Counts =
			counts,

	}

end



------------------------------------------------------------
-- APPLY
------------------------------------------------------------

local METHOD_TO_LEVEL = {

	regression =
		"regression",

	tree =
		"decision_tree",

	clustering =
		"dbscan",

}



local function applyMethod(
	player,
	methodId
)

	if not Config.Methods[
		methodId
	] then

		return {

			Ok =
				false,

			Error =
				"Неизвестный метод.",

		}

	end


	if player:GetAttribute(
		"HiveMethodUnlocked_"
			.. methodId
	) ~= true
	then

		return {

			Ok =
				false,

			Error =
				"Этот метод ещё не изучен.",

		}

	end


	if player:GetAttribute(
		"HiveMethodApplied_"
			.. methodId
	) == true
	then

		return {

			Ok =
				false,

			Error =
				"Метод уже применён.",

		}

	end


	local state =
		getState(
			player
		)


	if not state then

		return {

			Ok =
				false,

			Error =
				"Состояние улья не найдено.",

		}

	end


	local before =
		snapshot(
			player
		)


	local detail
	local err


	if methodId
		== "regression"
	then

		detail =
			applyRegression(
				player,
				state
			)


	elseif methodId
		== "tree"
	then

		detail =
			applyTree(
				player,
				state
			)


	elseif methodId
		== "clustering"
	then

		detail,
			err =
			applyClustering(
				player,
				state
			)

	end


	if not detail then

		return {

			Ok =
				false,

			Error =
				err
				or "Не удалось применить метод.",

		}

	end


	player:SetAttribute(
		"HiveMethodApplied_"
			.. methodId,
		true
	)


	player:SetAttribute(
		"HiveMethodPending_"
			.. methodId,
		false
	)


	if player:GetAttribute(
		"HiveAwaitingApplication"
	) == methodId
	then

		player:SetAttribute(
			"HiveAwaitingApplication",
			nil
		)

	end


	recalculateProduction(
		player
	)


	task.wait(
		0.05
	)


	local after =
		snapshot(
			player
		)


	lastImpacts[player] =
		lastImpacts[player]
		or {}


	lastImpacts[player][methodId] = {

		Before =
			before,

		After =
			after,

		Text =
			detail.Text,

	}


	print(
		"[HiveControl] APPLIED:",
		player.Name,
		methodId
	)


	------------------------------------------------
	-- Give the player a moment to see the impact,
	-- then unlock the next learning level.
	------------------------------------------------

	local levelId =
		METHOD_TO_LEVEL[
			methodId
		]


	task.delay(
		2.2,
		function()

			if not player.Parent then
				return
			end


			local LevelFlowService =
				require(
					script.Parent
						:WaitForChild(
							"LevelFlowService"
						)
				)


			LevelFlowService
				.CompleteLevel(
					player,
					levelId
				)

		end
	)


	return {

		Ok =
			true,

		State =
			after,

		Impact = {

			Before =
				before,

			After =
				after,

			Text =
				detail.Text,

		},

	}

end



------------------------------------------------------------
-- RPC
------------------------------------------------------------

local function onRPC(
	player,
	action,
	payload
)

	if action
		== "GetState"
	then

		return {

			Ok =
				true,

			State =
				snapshot(
					player
				),

		}

	end


	if action
		== "Apply"
	then

		return applyMethod(
			player,
			payload
		)

	end


	return {

		Ok =
			false,

		Error =
			"Неизвестная команда.",

	}

end



------------------------------------------------------------
-- START
------------------------------------------------------------

function HiveControlService.Start()

	if started then
		return
	end


	started =
		true


	rpc.OnServerInvoke =
		onRPC


	Players.PlayerRemoving:Connect(
		function(player)

			lastImpacts[player] =
				nil

		end
	)


	print(
		"[HiveControl] Service started"
	)

end



return HiveControlService
