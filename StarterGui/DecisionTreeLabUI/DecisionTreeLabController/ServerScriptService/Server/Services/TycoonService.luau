local TycoonService = {}

local playerStates = {}


function TycoonService.CreatePlayerState(player)

	if playerStates[player] then
		return playerStates[player]
	end

	local state = {

		Resources = {
			Honey = 0,
		},

		Stats = {

			Efficiency = 1,

			Workforce = 0,
			Supply = 0,
			Processing = 0,

			Consumption = 1,
			HealthRisk = 0,

		},

		Production = {
			BaseHoneyRate = 1,
			HoneyRate = 0,
		},

		Population = {

			NextBeeId = 1,

			Bees = {},

			Summary = {
				Total = 0,
				Alive = 0,

				ByJob = {
					Unassigned = 0,
					Forage = 0,
					HiveWork = 0,
					Rest = 0,
					Quarantine = 0,
				},
			},

		},

		Entities = {},

		Capabilities = {},

		Unlocks = {},

		Groups = {},

		GroupPolicies = {},
		
		Learning = {

			CompletedLessons = {},

		},
	}

	playerStates[player] = state

	return state
end


function TycoonService.GetPlayerState(player)
	return playerStates[player]
end


function TycoonService.RemovePlayerState(player)
	playerStates[player] = nil
end


return TycoonService