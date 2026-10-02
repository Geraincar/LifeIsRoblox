local ConditionRegistry = {}


local conditions = {}


--------------------------------------------------
-- SELECTION COUNT
--------------------------------------------------

conditions.SelectionCount =
	function(
		runtime,
		definition
	)

	local count = 0


	for _ in pairs(
		runtime.StepData.SelectedObjects
		) do

		count += 1

	end


	return count
		>= definition.Count

end



--------------------------------------------------
-- MEASUREMENT COUNT
--------------------------------------------------

conditions.MeasurementCount =
	function(
		runtime,
		definition
	)

	return #runtime.StepData.Measurements
		>= definition.Count

end



--------------------------------------------------
-- PLACEMENT COUNT
--------------------------------------------------

conditions.PlacementCount =
	function(
		runtime,
		definition
	)

	local count = 0


	for _ in pairs(
		runtime.StepData.Placements
		) do

		count += 1

	end


	return count
		>= definition.Count

end



--------------------------------------------------
-- EVENT COUNT
--------------------------------------------------

conditions.EventCount =
	function(
		runtime,
		definition
	)

	local count =
		runtime.StepData.EventCounts[
	definition.Event
	]
		or 0


	return count
		>= definition.Count

end



--------------------------------------------------
-- METRIC BELOW
--------------------------------------------------

conditions.MetricBelow =
	function(
		runtime,
		definition
	)

	local value =
		runtime.Metrics[
	definition.Metric
	]


	if value == nil then
		return false
	end


	return value
		< definition.Value

end



--------------------------------------------------
-- METRIC WITHIN
--------------------------------------------------

conditions.MetricWithin =
	function(
		runtime,
		definition
	)

	local value =
		runtime.Metrics[
	definition.Metric
	]


	if value == nil then
		return false
	end


	return value
		>= definition.Min
		and value
		<= definition.Max

end



--------------------------------------------------
-- ALL
--------------------------------------------------

conditions.All =
	function(
		runtime,
		definition,
		event
	)

	for _, child in ipairs(
		definition.Conditions
		) do

		if not ConditionRegistry.Check(
			runtime,
			child,
			event
			) then

			return false

		end

	end


	return true

end



function ConditionRegistry.Register(
	conditionType,
	callback
)

	conditions[conditionType] =
		callback

end



function ConditionRegistry.Check(
	runtime,
	definition,
	event
)

	if not definition then
		return false
	end


	local callback =
		conditions[
	definition.Type
	]


	if not callback then

		warn(
			"Unknown completion condition:",
			definition.Type
		)

		return false

	end


	return callback(
		runtime,
		definition,
		event
	)

end



return ConditionRegistry