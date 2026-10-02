local ObjectResolver =
	require(
		script.Parent.ObjectResolver
	)


local EffectRegistry = {}


local effects = {}


--------------------------------------------------
-- HIGHLIGHT
--------------------------------------------------

effects.HighlightObject =
	function(
		context,
		definition
	)

	local object =
		ObjectResolver.FindById(
			definition.TargetId
		)


	if not object then
		return
	end


	local old =
		object:FindFirstChild(
			"LessonHighlight"
		)


	if old then
		old:Destroy()
	end


	local highlight =
		Instance.new("Highlight")


	highlight.Name =
		"LessonHighlight"


	highlight.Parent =
		object

end



--------------------------------------------------
-- CLEAR HIGHLIGHT
--------------------------------------------------

effects.ClearHighlight =
	function(
		context,
		definition
	)

	local object =
		ObjectResolver.FindById(
			definition.TargetId
		)


	if not object then
		return
	end


	local highlight =
		object:FindFirstChild(
			"LessonHighlight"
		)


	if highlight then

		highlight:Destroy()

	end

end



--------------------------------------------------
-- SET VISIBILITY
--------------------------------------------------

effects.SetVisible =
	function(
		context,
		definition
	)

	local object =
		ObjectResolver.FindById(
			definition.TargetId
		)


	if not object then
		return
	end


	if object:IsA(
		"BasePart"
		) then

		object.Transparency =
			definition.Visible
			and 0
			or 1

	end

end



--------------------------------------------------
-- SET METRIC
--------------------------------------------------

effects.SetMetric =
	function(
		context,
		definition
	)

	context.SetMetric(
		definition.Metric,
		definition.Value
	)

end



function EffectRegistry.Register(
	effectType,
	callback
)

	effects[effectType] =
		callback

end



function EffectRegistry.Apply(
	context,
	definition
)

	local callback =
		effects[
	definition.Type
	]


	if not callback then

		warn(
			"Unknown world lesson effect:",
			definition.Type
		)

		return

	end


	callback(
		context,
		definition
	)

end



function EffectRegistry.ApplyAll(
	context,
	definitions
)

	if not definitions then
		return
	end


	for _, definition in ipairs(
		definitions
		) do

		EffectRegistry.Apply(
			context,
			definition
		)

	end

end



return EffectRegistry