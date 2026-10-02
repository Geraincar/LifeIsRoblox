local Config = {}

Config.Data = {
	{ Id = "A1", X = 2.0, Y = 1.0, TrueClass = "A", PredictedClass = "A" },
	{ Id = "A2", X = 4.2, Y = 2.1, TrueClass = "A", PredictedClass = "A" },
	{ Id = "B1", X = 3.1, Y = 1.7, TrueClass = "B", PredictedClass = "A" },
	{ Id = "B2", X = 1.8, Y = 3.4, TrueClass = "B", PredictedClass = "B" },
	{ Id = "B3", X = 4.5, Y = 4.0, TrueClass = "B", PredictedClass = "B" },
	{ Id = "B4", X = 2.7, Y = 5.1, TrueClass = "B", PredictedClass = "B" },
	{ Id = "A3", X = 3.6, Y = 3.2, TrueClass = "A", PredictedClass = "B" },
	{ Id = "D1", X = 6.0, Y = 1.2, TrueClass = "D", PredictedClass = "D" },
	{ Id = "D2", X = 6.8, Y = 2.8, TrueClass = "D", PredictedClass = "D" },
	{ Id = "D3", X = 7.3, Y = 4.7, TrueClass = "D", PredictedClass = "D" },
	{ Id = "C1", X = 8.1, Y = 1.4, TrueClass = "C", PredictedClass = "C" },
	{ Id = "C2", X = 8.8, Y = 2.2, TrueClass = "C", PredictedClass = "C" },
	{ Id = "C3", X = 9.2, Y = 3.8, TrueClass = "C", PredictedClass = "C" },
	{ Id = "C4", X = 8.4, Y = 5.0, TrueClass = "C", PredictedClass = "C" },
	{ Id = "D4", X = 8.0, Y = 3.0, TrueClass = "D", PredictedClass = "C" },
}

Config.Classes = { "A", "B", "C", "D" }

Config.ClassColors = {
	A = Color3.fromRGB(232, 151, 157),
	B = Color3.fromRGB(158, 143, 220),
	C = Color3.fromRGB(84, 190, 157),
	D = Color3.fromRGB(255, 184, 42),
}

Config.ById = {}
for _, row in ipairs(Config.Data) do
	assert(Config.ById[row.Id] == nil, "Duplicate Macro-F1 object: " .. row.Id)
	Config.ById[row.Id] = row
end

function Config.Predict(x, y)
	if x <= 5 then
		return y <= 2.5 and "A" or "B"
	end
	return x <= 7.5 and "D" or "C"
end

function Config.GetNodes(row)
	local branch = row.X <= 5 and "Left" or "Right"
	return { "Root", branch, "Class" .. row.PredictedClass }
end

function Config.GetConfusion(className)
	local result = { TP = 0, FP = 0, FN = 0, TN = 0 }
	for _, row in ipairs(Config.Data) do
		local actual = row.TrueClass == className
		local predicted = row.PredictedClass == className
		if actual and predicted then
			result.TP += 1
		elseif not actual and predicted then
			result.FP += 1
		elseif actual and not predicted then
			result.FN += 1
		else
			result.TN += 1
		end
	end
	return result
end

local function safeDivide(numerator, denominator)
	return denominator == 0 and 0 or numerator / denominator
end

function Config.GetMetrics(className)
	local confusion = Config.GetConfusion(className)
	local precision = safeDivide(confusion.TP, confusion.TP + confusion.FP)
	local recall = safeDivide(confusion.TP, confusion.TP + confusion.FN)
	local f1 = safeDivide(2 * precision * recall, precision + recall)
	return {
		Class = className,
		TP = confusion.TP,
		FP = confusion.FP,
		FN = confusion.FN,
		Precision = precision,
		Recall = recall,
		F1 = f1,
	}
end

function Config.GetAllMetrics()
	local result = {}
	local total = 0
	for _, className in ipairs(Config.Classes) do
		local metrics = Config.GetMetrics(className)
		result[className] = metrics
		total += metrics.F1
	end
	return result, total / #Config.Classes
end

assert(#Config.Data == 15, "Macro-F1 dataset must contain 15 objects")
for _, row in ipairs(Config.Data) do
	assert(Config.Predict(row.X, row.Y) == row.PredictedClass, "Wrong prediction for " .. row.Id)
end

local verifiedMetrics, verifiedMacro = Config.GetAllMetrics()
assert(verifiedMetrics.A.TP == 2 and verifiedMetrics.A.FP == 1 and verifiedMetrics.A.FN == 1)
assert(verifiedMetrics.B.TP == 3 and verifiedMetrics.B.FP == 1 and verifiedMetrics.B.FN == 1)
assert(verifiedMetrics.C.TP == 4 and verifiedMetrics.C.FP == 1 and verifiedMetrics.C.FN == 0)
assert(verifiedMetrics.D.TP == 3 and verifiedMetrics.D.FP == 0 and verifiedMetrics.D.FN == 1)
assert(math.abs(verifiedMacro - 0.7906746031746031) < 0.000001)

return Config
