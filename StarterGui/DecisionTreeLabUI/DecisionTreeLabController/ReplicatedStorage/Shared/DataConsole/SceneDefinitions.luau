local SceneDefinitions = {}


SceneDefinitions.Scenes = {

	console_intro = {

		Id = "console_intro",

		Title = "Data Console",
		Mode = "LEARNING",

		Context = {
			Step = "1 / 3",

			Heading = "Welcome to the data console",

			Body =
				"Here you can inspect data collected by the hive. "
				.. "Each point represents one observation.",

			Hint =
				"Start by selecting an observation.",
		},

		MainView = {
			Type = "Placeholder",

			Text =
				"DATA VISUALIZATION\n\n"
				.. "Scatter plot will live here.",
		},

		Metrics = {
			Title = "DATA",
			Text =
				"Observations: 7\n"
				.. "Features: 2",
		},

		PrimaryAction = {
			Label = "Continue",
			NextScene = "console_select_point",
		},

		AllowBack = false,
	},


	console_select_point = {

		Id = "console_select_point",

		Title = "Data Console",
		Mode = "LEARNING",

		Context = {
			Step = "2 / 3",

			Heading = "An observation",

			Body =
				"A point contains information about something "
				.. "that happened in the hive.",

			Hint =
				"For now, imagine you selected one point.",
		},

		MainView = {
			Type = "Placeholder",

			Text =
				"SELECTED OBSERVATION\n\n"
				.. "Bees: 120\n"
				.. "Nectar: 14.6 kg",
		},

		Metrics = {
			Title = "OBSERVATION",
			Text =
				"Field: B\n"
				.. "Bees: 120\n"
				.. "Nectar: 14.6",
		},

		PrimaryAction = {
			Label = "Continue",
			NextScene = "console_ready",
		},

		AllowBack = true,
	},


	console_ready = {

		Id = "console_ready",

		Title = "Data Console",
		Mode = "LEARNING",

		Context = {

			Step = "3 / 3",

			Heading =
				"Look for a relationship",

			Body =
				"Now that you can read observations, "
				.. "you are ready to use analytical "
				.. "tools on hive data.",

			Hint =
				"Finish the introduction "
				.. "to unlock the console.",

		},

		MainView = {

			Type = "Placeholder",

			Text =
				"DATA CONSOLE\n\n"
				.. "Ready",

		},

		Metrics = {

			Title = "READY",

			Text =
				"Introduction complete",

		},

		PrimaryAction = {

			Label =
				"Finish introduction",

			Action =
				"complete_console_intro",

		},

		AllowBack = true,

	},
	console_home = {

		Id = "console_home",

		Title = "Data Console",
		Mode = "HIVE ANALYTICS",
		PrimaryAction = {

			Label =
				"Open regression",

			NextScene =
				"reg_act1_observations",

		},

		Context = {

			Step = "",

			Heading =
				"Hive analytics",

			Body =
				"Choose an analytical tool "
				.. "to work with hive data.",

			Hint =
				"Regression will appear here next.",

		},

		MainView = {

			Type = "Placeholder",

			Text =
				"ANALYTICS\n\n"
				.. "[ Regression ]\n\n"
				.. "[ Locked ]\n"
				.. "[ Locked ]",

		},

		Metrics = {

			Title = "HIVE",

			Text =
				"Data Console online",

		},

		AllowBack = false,

	},
	
	reg_act1_observations = {

		Id = "reg_act1_observations",

		Title = "Regression",

		Mode = "LEARNING",

		Context = {

			Step = "Act 1",

			Heading =
				"What do these observations tell us?",

			Body =
				"The hive recorded seven historical observations. "
				.. "Each point shows how many bees worked "
				.. "and how much nectar was collected.",

			Hint =
				"First, just look at the cloud of points. "
				.. "Do you notice a relationship?",

		},


		MainView = {

			Type =
				"ScatterPlot",

			Dataset =
				"act1",

		},


		Metrics = {

			Title =
				"DATASET",

			Text =
				"Observations: 7\n"
				.. "X: Bees ×100\n"
				.. "Y: Nectar, kg",

		},


		PrimaryAction = {

			Label =
				"I see it",

			NextScene =
				nil,

		},


		AllowBack = true,

	},

}


function SceneDefinitions.Get(sceneId)

	return SceneDefinitions.Scenes[sceneId]

end


return SceneDefinitions