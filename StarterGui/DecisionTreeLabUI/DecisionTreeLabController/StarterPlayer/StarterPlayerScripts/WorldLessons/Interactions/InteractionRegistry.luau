local SelectObject =
	require(
		script.Parent.SelectObject
	)


local MeasureDistance =
	require(
		script.Parent.MeasureDistance
	)


local PlaceInZone =
	require(
		script.Parent.PlaceInZone
	)

local PressButton =
	require(
		script.Parent.PressButton
	)

local ChooseOption =
	require(
		script.Parent.ChooseOption
	)

local MoveHandle =
	require(
		script.Parent.MoveHandle
	)

local DragObject =
	require(
		script.Parent.DragObject
	)

local ConnectObjects =
	require(
		script.Parent.ConnectObjects
	)

local InteractionRegistry = {}


local interactions = {

	SelectObject =
		SelectObject,

	MeasureDistance =
		MeasureDistance,

	PlaceInZone =
		PlaceInZone,

	PressButton =
		PressButton,

	ChooseOption =
		ChooseOption,

	MoveHandle =
		MoveHandle,

	DragObject =
		DragObject,

	ConnectObjects =
		ConnectObjects,

}


function InteractionRegistry.Register(
	interactionType,
	module
)

	interactions[interactionType] =
		module

end



function InteractionRegistry.Start(
	definition,
	context
)

	if not definition then
		return nil
	end


	local interaction =
		interactions[
	definition.Type
	]


	if not interaction then

		warn(
			"Unknown world interaction:",
			definition.Type
		)

		return nil

	end


	return interaction.Start(
		context,
		definition
	)

end



return InteractionRegistry