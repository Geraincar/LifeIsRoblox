local Config = {}

--------------------------------------------------
-- OBJECTS
--------------------------------------------------

Config.ObjectOrder = {
	"A1",
	"A2",

	"B1",
	"B2",
	"B3",

	"C1",
	"C2",
	"C3",

	"D1",
	"D2",
}

Config.Objects = {

	A1 = {
		X = 1,
		Y = 1,
		Class = "A",
	},

	A2 = {
		X = 2,
		Y = 2,
		Class = "A",
	},

	B1 = {
		X = 4,
		Y = 3,
		Class = "B",
	},

	B2 = {
		X = 1,
		Y = 7,
		Class = "B",
	},

	B3 = {
		X = 4,
		Y = 8,
		Class = "B",
	},

	C1 = {
		X = 6,
		Y = 1,
		Class = "C",
	},

	C2 = {
		X = 7,
		Y = 4,
		Class = "C",
	},

	C3 = {
		X = 7,
		Y = 9,
		Class = "C",
	},

	D1 = {
		X = 8,
		Y = 7,
		Class = "D",
	},

	D2 = {
		X = 9,
		Y = 8,
		Class = "D",
	},

}

--------------------------------------------------
-- COLORS
--
-- Только для автоматического распознавания
-- уже покрашенных физических объектов.
-- Мы их НЕ перекрашиваем.
--------------------------------------------------

Config.ClassColors = {

	A = Color3.fromRGB(
		232,
		126,
		130
	),

	B = Color3.fromRGB(
		143,
		119,
		218
	),

	C = Color3.fromRGB(
		73,
		184,
		145
	),

	D = Color3.fromRGB(
		255,
		179,
		32
	),

}

--------------------------------------------------
-- CONDITIONS
--------------------------------------------------

Config.Conditions = {

	Root = {
		Text = "x <= 5 ?",
	},

	Left = {
		Text = "y <= 2.5 ?",
	},

	Right = {
		Text = "x <= 7.5 ?",
	},

}

--------------------------------------------------
-- EXPECTED TARGET
--------------------------------------------------

function Config.GetExpectedTarget(
	objectId,
	sourceNode
)

	local object =
		Config.Objects[objectId]

	if not object then
		return nil
	end

	if sourceNode == "Root" then

		if object.X <= 5 then
			return "Left"
		else
			return "Right"
		end

	elseif sourceNode == "Left" then

		if object.Y <= 2.5 then
			return "ClassA"
		else
			return "ClassB"
		end

	elseif sourceNode == "Right" then

		if object.X <= 7.5 then
			return "ClassC"
		else
			return "ClassD"
		end

	end

	return nil
end

--------------------------------------------------
-- CONDITION TEXT
--------------------------------------------------

function Config.GetConditionText(sourceNode)

	local condition =
		Config.Conditions[sourceNode]

	if condition then
		return condition.Text
	end

	return nil
end

--------------------------------------------------
-- FINAL TARGET
--------------------------------------------------

function Config.GetFinalTarget(objectId)

	local middle =
		Config.GetExpectedTarget(
			objectId,
			"Root"
		)

	if not middle then
		return nil
	end

	return Config.GetExpectedTarget(
		objectId,
		middle
	)
end

return Config