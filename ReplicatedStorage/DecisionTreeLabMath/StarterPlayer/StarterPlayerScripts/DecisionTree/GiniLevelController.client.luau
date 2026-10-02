local Runner = require(script.Parent:WaitForChild("ImpurityLevelRunner"))

local function gini(counts, total, classes)
	if total <= 0 then
		return 0
	end
	local sumOfSquares = 0
	for _, className in ipairs(classes) do
		local probability = (counts[className] or 0) / total
		sumOfSquares += probability * probability
	end
	return 1 - sumOfSquares
end

Runner.new({
	Sublevel = 3,
	GuiName = "GiniLevelGui",
	Title = "Индекс Джини",
	Symbol = "G",
	ResultColor = Color3.fromRGB(190, 145, 255),
	AccentColor = Color3.fromRGB(190, 145, 255),
	ResultOffset = Vector3.new(0, 7, 0),
	Formula = "G(S) = 1 - Σ pₖ²",
	FormulaKind = "Gini",
	Explanation = "Индекс Джини измеряет вероятность неправильной классификации случайно выбранного объекта.",
	Classes = { "C", "D" },
	MeasureClasses = { "A", "B", "C", "D" },
	Calculate = gini,
	ShowIntro = true,
	IntroTitle = "Следующий подуровень — Индекс Джини",
	IntroBody = "Теперь посчитайте индекс Джини для правого среднего узла и конечных узлов C и D. Здесь pₖ — доля объектов класса k в узле S.",
	Nodes = {
		{ Id = "Root", SourceNode = "Root", Title = "корневой узел", Layer = "Layer1", Prefix = "RootNode", FloorName = "RootNodeFloor", Task = false },
		{ Id = "Left", SourceNode = "Left", Title = "левый средний узел", Layer = "Layer2", Prefix = "LeftConditionNode", FloorName = "LeftConditionNodeFloor", Task = false },
		{ Id = "ClassA", SourceNode = "ClassA", Title = "конечный узел A", Layer = "Layer3", Prefix = "ClassA", FloorName = "ClassAFloor", Task = false },
		{ Id = "ClassB", SourceNode = "ClassB", Title = "конечный узел B", Layer = "Layer3", Prefix = "ClassB", FloorName = "ClassBFloor", Task = false },
		{ Id = "Right", SourceNode = "Right", Title = "правый средний узел", Layer = "Layer2", Prefix = "RightConditionNode", FloorName = "RightConditionNodeFloor", Task = true },
		{ Id = "ClassC", SourceNode = "ClassC", Title = "конечный узел C", Layer = "Layer3", Prefix = "ClassC", FloorName = "ClassCFloor", Task = true },
		{ Id = "ClassD", SourceNode = "ClassD", Title = "конечный узел D", Layer = "Layer3", Prefix = "ClassD", FloorName = "ClassDFloor", Task = true },
	},
})
