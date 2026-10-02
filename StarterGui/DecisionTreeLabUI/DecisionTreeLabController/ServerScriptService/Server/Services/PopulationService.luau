local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local TycoonService = require(
	script.Parent.TycoonService
)

local ProductionService = require(
	script.Parent.ProductionService
)

local PopulationModel = require(
	ReplicatedStorage.Shared.PopulationModel
)


local PopulationService = {}



function PopulationService.Recalculate(player)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	local result =
		PopulationModel.Compute(
			state.Population
		)


	state.Stats.Workforce =
		result.Workforce

	state.Stats.Supply =
		result.Supply

	state.Stats.Processing =
		result.Processing

	state.Stats.Consumption =
		result.Consumption

	state.Stats.HealthRisk =
		result.HealthRisk


	ProductionService.Recalculate(player)


	print(
		"Population recalculated",
		"| Workforce:", math.round(result.Workforce * 100) / 100,
		"| Supply:", math.round(result.Supply * 100) / 100,
		"| Processing:", math.round(result.Processing * 100) / 100,
		"| Consumption:", math.round(result.Consumption * 100) / 100,
		"| HealthRisk:", math.round(result.HealthRisk * 100) / 100
	)

end



return PopulationService