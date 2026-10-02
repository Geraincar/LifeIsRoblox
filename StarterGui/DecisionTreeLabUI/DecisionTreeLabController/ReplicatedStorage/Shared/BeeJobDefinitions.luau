local BeeJobDefinitions = {}


local definitions = {

	Unassigned = {
		DisplayName = "Unassigned",
	},

	Forage = {
		DisplayName = "Forage",
	},

	HiveWork = {
		DisplayName = "Hive Work",
	},

	Rest = {
		DisplayName = "Rest",
	},

	Quarantine = {
		DisplayName = "Quarantine",
	},

}


function BeeJobDefinitions.Get(jobId)
	return definitions[jobId]
end


function BeeJobDefinitions.Exists(jobId)
	return definitions[jobId] ~= nil
end


function BeeJobDefinitions.GetAll()
	return definitions
end


return BeeJobDefinitions