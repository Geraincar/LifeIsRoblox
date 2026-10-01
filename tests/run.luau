-- Standalone-прогон автотестов без Roblox: luau tests/run.luau
-- Модули без Roblox API подключаются по путям файлов; в Studio тот же набор гоняет Script RegressionTests.
local R = "../src/ReplicatedStorage/Regression/"
local MathCore = require(R .. "MathCore")
local Datasets = require(R .. "Data/Datasets")
local Expected = require(R .. "Data/ExpectedValues")

local suites = {
	{ "MathCore", function()
		return require(R .. "Tests/MathCoreSpec")(MathCore, Datasets, Expected)
	end },
	{ "Logic3D", function()
		return require(R .. "Tests/LogicSpec")({
			MathCore = MathCore, Datasets = Datasets,
			Format = require(R .. "Core/Format"), BedGeometry = require(R .. "Core/BedGeometry"),
			Records = require(R .. "Core/Records"), LineModel = require(R .. "Core/LineModel"),
			Store = require(R .. "Core/Store"),
		})
	end },
}

local total, failed = 0, 0
for _, s in suites do
	local c, f = s[2]()
	print(("%s: %d/%d"):format(s[1], c - f, c))
	total += c
	failed += f
end
print(("Regression ИТОГО: %d/%d"):format(total - failed, total))
if failed > 0 then
	error("есть упавшие проверки")
end
