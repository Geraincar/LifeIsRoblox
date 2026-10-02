local FrameworkTest = {}


--------------------------------------------------
-- BASIC INFO
--------------------------------------------------

FrameworkTest.Id =
	"framework_test"


FrameworkTest.DisplayName =
	"World Lesson Test"


--------------------------------------------------
-- STEP ORDER
--------------------------------------------------

FrameworkTest.StepOrder = {

	"select_object",

	"measure_distance",

}


--------------------------------------------------
-- STEPS
--------------------------------------------------

FrameworkTest.Steps = {


	--------------------------------------------------
	-- STEP 1
	-- SELECT OBJECT
	--------------------------------------------------

	select_object = {

		Instruction = {

			Title =
				"Select the object",

			Text =
				"Click object A in the world.",

			Hint =
				"Look for the highlighted object.",

		},


		Interaction = {

			Type =
				"SelectObject",

			TargetId =
				"test_a",

		},


		Completion = {

			Type =
				"SelectionCount",

			Count =
				1,

		},


		EffectsOnStart = {

			{

				Type =
					"HighlightObject",

				ObjectId =
					"test_a",

			},

		},


		EffectsOnComplete = {

			{

				Type =
					"ClearHighlight",

				ObjectId =
					"test_a",

			},

		},

	},



	--------------------------------------------------
	-- STEP 2
	-- MEASURE DISTANCE
	--------------------------------------------------

	measure_distance = {

		Instruction = {

			Title =
				"Measure distance",

			Text =
				"Click object A, then click object B.",

			Hint =
				"Start with object A. The line will show what is being measured.",

		},


		Interaction = {

			Type =
				"MeasureDistance",

			SourceId =
				"test_a",

			TargetId =
				"test_b",

			Axis =
				"Euclidean",

		},


		Completion = {

			Type =
				"MeasurementCount",

			Count =
				1,

		},


		EffectsOnStart = {

			{

				Type =
					"HighlightObject",

				ObjectId =
					"test_a",

			},

			{

				Type =
					"HighlightObject",

				ObjectId =
					"test_b",

			},

		},


		EffectsOnComplete = {

			{

				Type =
					"ClearHighlight",

				ObjectId =
					"test_a",

			},

			{

				Type =
					"ClearHighlight",

				ObjectId =
					"test_b",

			},

		},

	},

}


--------------------------------------------------
-- AFTER LESSON
--------------------------------------------------

FrameworkTest.NextConsoleScene =
	"console_home"



return FrameworkTest