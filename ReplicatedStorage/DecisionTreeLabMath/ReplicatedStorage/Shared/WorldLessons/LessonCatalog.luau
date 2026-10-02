local lessonsFolder =
	script.Parent:WaitForChild("Lessons")


local LessonCatalog = {}


local lessons = {

	framework_test =
		require(
			lessonsFolder:WaitForChild(
				"FrameworkTest"
			)
		),

}


function LessonCatalog.Get(lessonId)

	return lessons[lessonId]

end


function LessonCatalog.Exists(lessonId)

	return lessons[lessonId] ~= nil

end


return LessonCatalog