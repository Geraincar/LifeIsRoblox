local PlaceholderView =
	require(
		script.Parent.PlaceholderView
	)


local ScatterPlotView =
	require(
		script.Parent.ScatterPlotView
	)


local ViewRegistry = {}


local views = {

	Placeholder =
		PlaceholderView,

	ScatterPlot =
		ScatterPlotView,

}


function ViewRegistry.Render(
	viewType,
	ui,
	viewDefinition
)

	--------------------------------
	-- HIDE CURRENT VIEWS
	--------------------------------

	for _, view in pairs(views) do

		if view.Hide then

			view.Hide(ui)

		end

	end


	--------------------------------
	-- RENDER REQUESTED VIEW
	--------------------------------

	local view =
		views[viewType]


	if not view then

		warn(
			"Unknown Data Console view:",
			viewType
		)

		return

	end


	view.Render(
		ui,
		viewDefinition
	)

end



return ViewRegistry