local Runner = require(script.Parent:WaitForChild("ImpurityLevelRunner"))

local function entropy(counts, total, classes)
	if total <= 0 then
		return 0
	end
	local value = 0
	for _, className in ipairs(classes) do
		local amount = counts[className] or 0
		if amount > 0 then
			local probability = amount / total
			value -= probability * (math.log(probability) / math.log(2))
		end
	end
	return value
end

Runner.new({
	Sublevel = 2,
	GuiName = "EntropyLevelGui",
	Title = "Энтропия",
	Symbol = "H",
	Formula = "H(S) = -Σ pₖ log₂(pₖ)",
	FormulaKind = "Entropy",
	Explanation = "Энтропия — мера неопределённости данных: чем сильнее смешаны классы, тем она выше.",
	Classes = { "A", "B" },
	MeasureClasses = { "A", "B", "C", "D" },
	Calculate = entropy,
	ShowIntro = false,
	Nodes = {
		{ Id = "Root", SourceNode = "Root", Title = "корневой узел", Layer = "Layer1", Prefix = "RootNode", FloorName = "RootNodeFloor", Task = false },
		{ Id = "Left", SourceNode = "Left", Title = "левый средний узел", Layer = "Layer2", Prefix = "LeftConditionNode", FloorName = "LeftConditionNodeFloor", Task = true },
		{ Id = "ClassA", SourceNode = "ClassA", Title = "конечный узел A", Layer = "Layer3", Prefix = "ClassA", FloorName = "ClassAFloor", Task = true },
		{ Id = "ClassB", SourceNode = "ClassB", Title = "конечный узел B", Layer = "Layer3", Prefix = "ClassB", FloorName = "ClassBFloor", Task = true },
		{ Id = "Right", SourceNode = "Right", Title = "правый средний узел", Layer = "Layer2", Prefix = "RightConditionNode", FloorName = "RightConditionNodeFloor", Task = false },
		{ Id = "ClassC", SourceNode = "ClassC", Title = "конечный узел C", Layer = "Layer3", Prefix = "ClassC", FloorName = "ClassCFloor", Task = false },
		{ Id = "ClassD", SourceNode = "ClassD", Title = "конечный узел D", Layer = "Layer3", Prefix = "ClassD", FloorName = "ClassDFloor", Task = false },
	},
})
