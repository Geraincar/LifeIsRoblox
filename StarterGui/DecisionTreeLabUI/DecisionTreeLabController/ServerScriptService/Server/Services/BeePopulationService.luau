local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local TycoonService = require(
	script.Parent.TycoonService
)

local PopulationService = require(
	script.Parent.PopulationService
)

local BeeJobDefinitions = require(
	ReplicatedStorage.Shared.BeeJobDefinitions
)


local BeePopulationService = {}



local function createBeeId(population)

	local id = string.format(
		"bee_%04d",
		population.NextBeeId
	)

	population.NextBeeId += 1

	return id

end



local function chooseInitialJob(random)

	local roll =
		random:NextNumber()


	if roll < 0.55 then

		return "Forage"

	elseif roll < 0.80 then

		return "HiveWork"

	else

		return "Rest"

	end

end



local function generateBee(
	population,
	random
)

	local beeId =
		createBeeId(population)


	local age =
		random:NextNumber(0, 1)

	local health =
		random:NextNumber(0.55, 1)

	local activity =
		random:NextNumber(0.2, 1)

	local consumption =
		random:NextNumber(0.6, 1.4)


	local productivity =
		activity
		* health
		* (1 - age * 0.4)


	return {

		Id = beeId,

		Age = age,

		Health = health,

		Activity = activity,

		Consumption = consumption,

		Productivity = productivity,

		CurrentJob =
			chooseInitialJob(random),

		Alive = true,

	}

end



function BeePopulationService.RecalculateSummary(
	player
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	local population =
		state.Population


	local summary = {

		Total = 0,

		Alive = 0,

		ByJob = {

			Unassigned = 0,

			Forage = 0,

			HiveWork = 0,

			Rest = 0,

			Quarantine = 0,

		},

	}


	for _, bee in pairs(
		population.Bees
		) do

		summary.Total += 1


		if bee.Alive then

			summary.Alive += 1


			if summary.ByJob[
				bee.CurrentJob
				] ~= nil then

				summary.ByJob[
				bee.CurrentJob
				] += 1

			end

		end

	end


	population.Summary = summary

end



function BeePopulationService.AddBee(
	player,
	random
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	local population =
		state.Population


	random =
		random or Random.new()


	local bee =
		generateBee(
			population,
			random
		)


	population.Bees[bee.Id] =
		bee


	BeePopulationService
		.RecalculateSummary(player)


	PopulationService
		.Recalculate(player)


	return bee

end



function BeePopulationService.Initialize(
	player,
	count
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	local population =
		state.Population


	-- Не создаём популяцию повторно.
	if next(population.Bees) ~= nil then
		return
	end


	-- Для тестов один и тот же игрок
	-- получает воспроизводимую популяцию.
	local random =
		Random.new(
			player.UserId + 1000
		)


	for _ = 1, count do

		local bee =
			generateBee(
				population,
				random
			)


		population.Bees[bee.Id] =
			bee

	end


	BeePopulationService
		.RecalculateSummary(player)


	PopulationService
		.Recalculate(player)


	print(
		"Bee population initialized:",
		player.Name,
		"Total:",
		population.Summary.Total
	)

end



function BeePopulationService.GetBee(
	player,
	beeId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	return state.Population.Bees[
	beeId
	]

end



function BeePopulationService.GetAll(
	player
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	return state.Population.Bees

end



function BeePopulationService.SetJob(
	player,
	beeId,
	jobId
)

	if not BeeJobDefinitions.Exists(
		jobId
		) then

		warn(
			"Unknown bee job:",
			jobId
		)

		return false

	end


	local bee =
		BeePopulationService.GetBee(
			player,
			beeId
		)


	if not bee then

		warn(
			"Unknown bee:",
			beeId
		)

		return false

	end


	if not bee.Alive then
		return false
	end


	bee.CurrentJob =
		jobId


	BeePopulationService
		.RecalculateSummary(player)


	PopulationService
		.Recalculate(player)


	return true

end



function BeePopulationService.GetSummary(
	player
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	return state.Population.Summary

end

function BeePopulationService.SetJobsBatch(
	player,
	assignments
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return 0
	end


	local changed = 0


	for beeId, jobId in pairs(
		assignments
		) do

		if BeeJobDefinitions.Exists(jobId) then

			local bee =
				state.Population.Bees[beeId]


			if bee and bee.Alive then

				if bee.CurrentJob ~= jobId then

					bee.CurrentJob = jobId

					changed += 1

				end

			end

		else

			warn(
				"Unknown bee job:",
				jobId
			)

		end

	end


	if changed > 0 then

		BeePopulationService
			.RecalculateSummary(player)

		PopulationService
			.Recalculate(player)

	end


	return changed

end


return BeePopulationService