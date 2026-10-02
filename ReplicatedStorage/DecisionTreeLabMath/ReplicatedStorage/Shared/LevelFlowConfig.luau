local Config = {}


Config.Order = {

	"regression",

	"decision_tree",

	"dbscan",

}


Config.Levels = {


	regression = {

		Name =
			"Регрессия",

		EntryPoint =
			"RegressionEntry",

	},


	decision_tree = {

		Name =
			"Решающее дерево",

		EntryPoint =
			"DecisionTreeEntry",

	},


	dbscan = {

		Name =
			"Кластеризация",

		EntryPoint =
			"DBSCANEntry",

	},

}


Config.ArrivalDistance =
	14


return Config
