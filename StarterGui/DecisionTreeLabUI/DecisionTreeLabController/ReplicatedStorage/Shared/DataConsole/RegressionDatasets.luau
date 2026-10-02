local RegressionDatasets = {}


RegressionDatasets.act1 = {

	Id = "act1",

	XFeature = "bees_x100",
	YFeature = "nectar_kg",

	XLabel = "Bees ×100",
	YLabel = "Nectar, kg",

	Observations = {

		{
			Id = "meadow_1",
			Meadow = 1,
			X = 10,
			Y = 11.5,
		},

		{
			Id = "meadow_2",
			Meadow = 2,
			X = 15,
			Y = 12.0,
		},

		{
			Id = "meadow_3",
			Meadow = 3,
			X = 20,
			Y = 18.5,
		},

		{
			Id = "meadow_4",
			Meadow = 4,
			X = 25,
			Y = 21.0,
		},

		{
			Id = "meadow_5",
			Meadow = 5,
			X = 30,
			Y = 28.0,
		},

		{
			Id = "meadow_6",
			Meadow = 6,
			X = 35,
			Y = 29.5,
		},

		{
			Id = "meadow_7",
			Meadow = 7,
			X = 40,
			Y = 33.5,
		},

	},

}


function RegressionDatasets.Get(datasetId)

	return RegressionDatasets[datasetId]

end


return RegressionDatasets