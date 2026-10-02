local InteractionRegistry =
	require(
		script.Parent
		:WaitForChild("Interactions")
		:WaitForChild(
			"InteractionRegistry"
		)
	)


local ConditionRegistry =
	require(
		script.Parent
		:WaitForChild(
			"ConditionRegistry"
		)
	)


local EffectRegistry =
	require(
		script.Parent
		:WaitForChild(
			"EffectRegistry"
		)
	)


local WorldLessonEngine = {}


local callbacks = {}


local activeInteraction =
	nil


local runtime =
	nil


--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function stopInteraction()

	if activeInteraction
		and activeInteraction.Stop
	then

		activeInteraction.Stop()

	end


	activeInteraction =
		nil

end



local function createStepData()

	return {

		EventCounts = {},

		SelectedObjects = {},

		Measurements = {},

		Placements = {},

	}

end



local function getCurrentStep()

	if not runtime then
		return nil
	end


	return runtime.Lesson.Steps[
	runtime.CurrentStepId
	]

end



local function getStepIndex(
	stepId
)

	for index, id in ipairs(
		runtime.Lesson.StepOrder
		) do

		if id == stepId then
			return index
		end

	end


	return nil

end



--------------------------------------------------
-- METRICS
--------------------------------------------------

function WorldLessonEngine.SetMetric(
	name,
	value
)

	if not runtime then
		return
	end


	runtime.Metrics[name] =
		value


	WorldLessonEngine.CheckCompletion()

end



--------------------------------------------------
-- EVENTS FROM INTERACTIONS
--------------------------------------------------

function WorldLessonEngine.Emit(
	event
)

	if not runtime then
		return
	end


	local stepData =
		runtime.StepData


	stepData.EventCounts[
	event.Type
	] =
		(
			stepData.EventCounts[
			event.Type
			]
			or 0
		)
		+ 1


	if event.Type
		== "ObjectSelected"
	then

		stepData.SelectedObjects[
		event.ObjectId
		] = true

	end


	if event.Type
		== "MeasurementCompleted"
	then

		table.insert(
			stepData.Measurements,
			event
		)

	end


	if event.Type
		== "ObjectPlaced"
	then

		stepData.Placements[
		event.ObjectId
		] =
			event.ZoneId

	end


	if callbacks.OnEvent then

		callbacks.OnEvent(
			event,
			runtime
		)

	end


	WorldLessonEngine.CheckCompletion(
		event
	)

end



--------------------------------------------------
-- STEP
--------------------------------------------------

function WorldLessonEngine.StartStep(
	stepId
)

	stopInteraction()


	local step =
		runtime.Lesson.Steps[
	stepId
	]


	if not step then

		warn(
			"Unknown lesson step:",
			stepId
		)

		return

	end


	runtime.CurrentStepId =
		stepId


	runtime.StepData =
		createStepData()


	local effectContext = {

		SetMetric =
			WorldLessonEngine.SetMetric,

	}


	EffectRegistry.ApplyAll(
		effectContext,
		step.EffectsOnStart
	)


	if callbacks.OnStepChanged then

		callbacks.OnStepChanged(

			step,

			getStepIndex(
				stepId
			),

			#runtime.Lesson.StepOrder

		)

	end


	local interactionContext = {

		Emit =
			WorldLessonEngine.Emit,

		SetMetric =
			WorldLessonEngine.SetMetric,

	}


	activeInteraction =
		InteractionRegistry.Start(
			step.Interaction,
			interactionContext
		)

end



function WorldLessonEngine.CheckCompletion(
	event
)

	if not runtime then
		return
	end


	if runtime.CompletingStep then
		return
	end


	local step =
		getCurrentStep()


	if not step then
		return
	end


	if ConditionRegistry.Check(
		runtime,
		step.Completion,
		event
		) then

		WorldLessonEngine.CompleteStep()

	end

end



function WorldLessonEngine.CompleteStep()

	if runtime.CompletingStep then
		return
	end


	runtime.CompletingStep =
		true


	stopInteraction()


	local step =
		getCurrentStep()


	local effectContext = {

		SetMetric =
			WorldLessonEngine.SetMetric,

	}


	EffectRegistry.ApplyAll(
		effectContext,
		step.EffectsOnComplete
	)


	runtime.CompletedSteps[
	runtime.CurrentStepId
	] = true


	local currentIndex =
		getStepIndex(
			runtime.CurrentStepId
		)


	local nextStepId =
		step.NextStep


	if not nextStepId
		and currentIndex
	then

		nextStepId =
			runtime.Lesson.StepOrder[
		currentIndex + 1
		]

	end


	runtime.CompletingStep =
		false


	if nextStepId then

		WorldLessonEngine.StartStep(
			nextStepId
		)

	else

		WorldLessonEngine.CompleteLesson()

	end

end

function WorldLessonEngine.ResetStep()

	if not runtime then
		return
	end


	if not runtime.CurrentStepId then
		return
	end


	local stepId =
		runtime.CurrentStepId


	--------------------------------
	-- LET INTERACTION RESTORE OBJECTS
	--------------------------------

	if activeInteraction
		and activeInteraction.Reset
	then

		activeInteraction.Reset()

	end


	if callbacks.OnStepReset then

		callbacks.OnStepReset(
			stepId
		)

	end


	--------------------------------
	-- RESTART SAME STEP
	--------------------------------

	WorldLessonEngine.StartStep(
		stepId
	)

end


--------------------------------------------------
-- LESSON
--------------------------------------------------

function WorldLessonEngine.StartLesson(
	lessonDefinition
)

	WorldLessonEngine.CancelLesson()


	runtime = {

		Lesson =
			lessonDefinition,

		CurrentStepId =
			nil,

		CompletedSteps =
			{},

		Metrics =
			{},

		StepData =
			createStepData(),

		CompletingStep =
			false,

	}


	if callbacks.OnLessonStarted then

		callbacks.OnLessonStarted(
			lessonDefinition
		)

	end


	local firstStep =
		lessonDefinition.StepOrder[1]


	WorldLessonEngine.StartStep(
		firstStep
	)

end



function WorldLessonEngine.CompleteLesson()

	stopInteraction()


	local lessonId =
		runtime.Lesson.Id


	if callbacks.OnLessonCompleted then

		callbacks.OnLessonCompleted(
			lessonId
		)

	end


	runtime =
		nil

end


function WorldLessonEngine.CancelLesson()

	stopInteraction()


	if runtime
		and callbacks.OnLessonCancelled
	then

		callbacks.OnLessonCancelled(
			runtime.Lesson.Id
		)

	end


	runtime =
		nil

end



function WorldLessonEngine.GetRuntime()

	return runtime

end



function WorldLessonEngine.Initialize(
	newCallbacks
)

	callbacks =
		newCallbacks or {}

end



return WorldLessonEngine