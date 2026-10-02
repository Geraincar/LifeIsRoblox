local PlaceholderView = {}


function PlaceholderView.Render(
	ui,
	viewDefinition
)

	ui.PlaceholderLabel.Visible =
		true


	ui.PlaceholderLabel.Text =
		viewDefinition.Text
		or ""

end



function PlaceholderView.Hide(
	ui
)

	ui.PlaceholderLabel.Visible =
		false

end



return PlaceholderView