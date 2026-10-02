local WorldLessonHUD =
	require(
		script.Parent.Parent.WorldLessonHUD
	)


local ChooseOption = {}


function ChooseOption.Start(
	context,
	definition
)

	local active = true


	WorldLessonHUD.ShowChoices(

		definition.Options,

		function(optionId)

			if not active then
				return
			end


			context.Emit({

				Type =
					"ChoiceSelected",

				OptionId =
					optionId,

			})

		end

	)


	return {

		Stop = function()

			active = false

			WorldLessonHUD
				.ClearChoices()

		end,

	}

end


return ChooseOption