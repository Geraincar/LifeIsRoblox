local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local LuauChart =
	require(
		ReplicatedStorage:WaitForChild(
			"LuauChart"
		)
	)


local RegressionDatasets =
	require(
		ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("DataConsole")
		:WaitForChild("RegressionDatasets")
	)


local ScatterPlotView = {}


local activeChart = nil


--------------------------------------------------
-- CLEANUP
--------------------------------------------------

local function destroyCurrentChart()

	if not activeChart then
		return
	end


	if activeChart.UI then

		activeChart.UI:Destroy()

	end


	activeChart = nil

end



--------------------------------------------------
-- SERIES
--------------------------------------------------

local function buildPointSeries(
	observations
)

	local series = {}


	-- Один observation = одна series.
	--
	-- Зачем:
	-- LuauChart Line обычно соединяет точки.
	-- У серии из одной точки соединять нечего,
	-- поэтому получаем настоящий scatter plot.

	for index, observation
		in ipairs(observations)
	do

		table.insert(
			series,
			{
				Name =
					"Observation "
					.. tostring(index),

				Thickness = 2,

				Markers = {
					Size = 8,
				},

				Points = {
					{
						Index =
							observation.X,

						Value =
							observation.Y,
					},
				},
			}
		)

	end


	return series

end



--------------------------------------------------
-- RENDER
--------------------------------------------------

function ScatterPlotView.Render(
	ui,
	viewDefinition
)

	destroyCurrentChart()


	local dataset =
		RegressionDatasets.Get(
			viewDefinition.Dataset
		)


	if not dataset then

		warn(
			"Unknown regression dataset:",
			viewDefinition.Dataset
		)

		return

	end


	local host =
		ui.ViewHost


	--------------------------------
	-- CREATE CHART
	--------------------------------

	local chart =
		LuauChart.Line.new({

			Renderer = "Viewport",

		})


	activeChart =
		chart


	chart.UI.Parent =
		host


	chart.UI.Size =
		UDim2.fromScale(
			1,
			1
		)


	chart.UI.Position =
		UDim2.fromScale(
			0,
			0
		)


	--------------------------------
	-- CHART SETTINGS
	--------------------------------

	chart.Grid:SetVisible(
		true
	)


	chart.Cursor:SetEnabled(
		true
	)


	chart.AutoFitY =
		false


	chart:SetBounds({

		X =
			NumberRange.new(
				5,
				45
			),

		Y =
			NumberRange.new(
				5,
				38
			),

	})


	--------------------------------
	-- DATA
	--------------------------------

	chart:SetSeries(
		buildPointSeries(
			dataset.Observations
		)
	)


	print(
		"ScatterPlot rendered:",
		dataset.Id,
		"Points:",
		#dataset.Observations
	)

end



--------------------------------------------------
-- HIDE
--------------------------------------------------

function ScatterPlotView.Hide(
	ui
)

	destroyCurrentChart()

end



return ScatterPlotView