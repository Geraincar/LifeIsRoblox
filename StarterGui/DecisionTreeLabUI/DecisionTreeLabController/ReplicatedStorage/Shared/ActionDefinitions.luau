local ActionDefinitions = {}

local definitions = {

	toggle_efficiency = {

		RequiredCapabilities = {
			"efficiency_control",
		},

	},

	learn_efficiency_control = {

		RequiredCapabilities = {},

	},

}


function ActionDefinitions.Get(actionId)

	return definitions[actionId]

end


return ActionDefinitions