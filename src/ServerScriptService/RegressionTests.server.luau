-- RegressionTests: прогон автотестов ядра и логики 3D при запуске в Studio (в опубликованной игре не выполняется).
-- Ожидаемый вывод в Output: «MathCore: 160/160», «Logic3D: 62/62», «Regression ИТОГО: 222/222».
-- Сквозной сценарий игрока (3D → 2D → лор) гоняется вне Studio: luau tests/scenario.luau (README).
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Regression = ReplicatedStorage:WaitForChild("Regression")
local MathCore = require(Regression.MathCore)
local Datasets = require(Regression.Data.Datasets)
local Expected = require(Regression.Data.ExpectedValues)

local c1, f1 = require(Regression.Tests.MathCoreSpec)(MathCore, Datasets, Expected)
local c2, f2 = require(Regression.Tests.LogicSpec)({
	MathCore = MathCore,
	Datasets = Datasets,
	Format = require(Regression.Core.Format),
	BedGeometry = require(Regression.Core.BedGeometry),
	Records = require(Regression.Core.Records),
	LineModel = require(Regression.Core.LineModel),
	Store = require(Regression.Core.Store),
})
local total, failed = c1 + c2, f1 + f2
if failed > 0 then
	warn(("Regression ИТОГО: %d/%d — есть упавшие проверки, смотри FAIL выше"):format(total - failed, total))
else
	print(("Regression ИТОГО: %d/%d"):format(total, total))
end
