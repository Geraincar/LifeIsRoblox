local EntityDefinitions = {}


local definitions = {

	["42"] = {

		Type = "TestProductionControl",

		InitialState = {
			Active = false,
		},

		Actions = {
			toggle_efficiency = true,
		},

	},


	["43"] = {

		Type = "TestLearningTerminal",

		InitialState = {},

		Actions = {
			learn_efficiency_control = true,
		},

	},

}


function EntityDefinitions.Get(entityId)

	return definitions[tostring(entityId)]

end


return EntityDefinitions