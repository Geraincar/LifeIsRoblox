local PolicyDefinitions = {}


local definitions = {

	forage = {

		DisplayName = "Send to forage",

		TargetScope = "Bees",

		Job = "Forage",

	},


	hive_work = {

		DisplayName = "Hive work",

		TargetScope = "Bees",

		Job = "HiveWork",

	},


	rest = {

		DisplayName = "Rest",

		TargetScope = "Bees",

		Job = "Rest",

	},


	quarantine = {

		DisplayName = "Quarantine",

		TargetScope = "Bees",

		Job = "Quarantine",

	},

}



function PolicyDefinitions.Get(
	policyId
)

	return definitions[policyId]

end



function PolicyDefinitions.Exists(
	policyId
)

	return definitions[policyId] ~= nil

end



return PolicyDefinitions