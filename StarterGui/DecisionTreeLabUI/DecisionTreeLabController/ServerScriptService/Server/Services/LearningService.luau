local TycoonService =
	require(
		script.Parent.TycoonService
	)


local LearningService = {}


function LearningService.IsCompleted(
	player,
	lessonId
)

	local state =
		TycoonService.GetPlayerState(player)


	if not state then
		return false
	end


	local learning =
		state.Learning


	if not learning then
		return false
	end


	return learning.CompletedLessons[lessonId]
		== true

end



function LearningService.Complete(
	player,
	lessonId
)

	local state =
		TycoonService.GetPlayerState(player)


	if not state then
		return false
	end


	state.Learning =
		state.Learning or {
			CompletedLessons = {},
		}


	state.Learning.CompletedLessons[lessonId] =
		true


	print(
		"Lesson completed:",
		player.Name,
		lessonId
	)


	return true

end



return LearningService