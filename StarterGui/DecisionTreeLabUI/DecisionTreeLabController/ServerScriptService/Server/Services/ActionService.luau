local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local TycoonService = require(
	script.Parent.TycoonService
)

local ProductionService = require(
	script.Parent.ProductionService
)

local CapabilityService = require(
	script.Parent.CapabilityService
)


local EntityDefinitions = require(
	ReplicatedStorage.Shared.EntityDefinitions
)

local ActionDefinitions = require(
	ReplicatedStorage.Shared.ActionDefinitions
)


local ActionService = {}



local function createEntityState(definition)

	local state = {}

	for key, value in pairs(
		definition.InitialState
		) do

		state[key] = value

	end

	return state

end



local function toggleEfficiency(
	player,
	entityId,
	entityState,
	playerState
)

	entityState.Active =
		not entityState.Active


	if entityState.Active then

		playerState.Stats.Efficiency = 2

	else

		playerState.Stats.Efficiency = 1

	end


	ProductionService.Recalculate(player)


	print(
		"Entity:",
		entityId,
		"Active:",
		entityState.Active,
		"Efficiency:",
		playerState.Stats.Efficiency
	)

end



local function learnEfficiencyControl(
	player,
	entityId,
	entityState,
	playerState
)

	local granted =
		CapabilityService.Grant(
			player,
			"efficiency_control"
		)


	if granted then

		print(
			"Player learned efficiency control"
		)

	else

		print(
			"Player already has efficiency control"
		)

	end

end



local actionHandlers = {

	toggle_efficiency =
		toggleEfficiency,

	learn_efficiency_control =
		learnEfficiencyControl,

}



function ActionService.Execute(
	player,
	actionId,
	entityId
)

	local playerState =
		TycoonService.GetPlayerState(player)


	if not playerState then

		warn(
			"No tycoon state for:",
			player.Name
		)

		return

	end


	-- Does this Entity exist?

	local entityDefinition =
		EntityDefinitions.Get(entityId)


	if not entityDefinition then

		warn(
			"Unknown entity:",
			entityId
		)

		return

	end


	-- Does this Entity allow this Action?

	if not entityDefinition.Actions[actionId] then

		warn(
			"Action",
			actionId,
			"is not allowed for entity",
			entityId
		)

		return

	end


	-- Does this Action exist?

	local actionDefinition =
		ActionDefinitions.Get(actionId)


	if not actionDefinition then

		warn(
			"Unknown action definition:",
			actionId
		)

		return

	end


	-- Does the player have the required capabilities?

	local hasCapabilities =
		CapabilityService.HasAll(
			player,
			actionDefinition.RequiredCapabilities
		)


	if not hasCapabilities then

		warn(
			"Missing capability for action:",
			actionId
		)

		return

	end


	-- Create runtime state if needed.

	if not playerState.Entities[entityId] then

		playerState.Entities[entityId] =
			createEntityState(
				entityDefinition
			)

	end


	local entityState =
		playerState.Entities[entityId]


	-- Find actual server implementation.

	local handler =
		actionHandlers[actionId]


	if not handler then

		warn(
			"No handler for action:",
			actionId
		)

		return

	end


	handler(
		player,
		entityId,
		entityState,
		playerState
	)

end


return ActionService