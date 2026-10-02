--!nonstrict
-- 2D.7 R². График из 2D.2 с оптимальной прямой (m = 0,47, c = 6,2).
-- Действие 1: собрать квадраты остатков в столбик — SS_res = Σ(yᵢ − ŷᵢ)² = 21,1.
-- Действие 2: поставить горизонтальную прямую на среднее (прилипание у ȳ = 25) и собрать квадраты — SS_tot = 242.
-- Открытие: R² = 1 − SS_res / SS_tot = 0,913, столбики в одном масштабе. Дальше — лор-задача.

local Regression = script.Parent.Parent.Parent
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local R2View = require(Regression.UI.R2View)

local S = Strings.s2d["2D.7"]

local scene = { id = "2D.7", panel = true, milestone = "regression_2d" }
scene.nextLabel = S.next

-- Общие формулы R² (используются и в лор-задаче)
function scene.formulas(sc, view)
	local T = sc.T
	local yi, yh, yb = T.sub("y", "i"), T.sub(T.hat("y"), "i"), T.bar("y", "mean", "mean")
	sc:formula({
		id = "SSRES", title = Strings.r2.ssResTitle, toNotebook = true,
		lines = { { id = "eq", hint = Strings.r2.lockRes,
			general = { T.sym("SS", "residual", "residual"), T.sub("", "res"), " = ", T.sum(), "(", yi, " − ", yh, ")²" },
			result = function() return Format.num(view:ssRes(), 1) end } },
	})
	sc:formula({
		id = "SSTOT", title = Strings.r2.ssTotTitle, toNotebook = true,
		lines = { { id = "eq", hint = Strings.r2.lockTot,
			general = { T.sym("SS", "mean", "mean"), T.sub("", "tot"), " = ", T.sum(), "(", yi, " − ", yb, ")²" },
			result = function() return Format.num(view:ssTot(), 1) end } },
	})
	sc:formula({
		id = "R2", title = Strings.r2.r2Title, toNotebook = true,
		lines = { { id = "eq", hint = Strings.r2.lockR2,
			general = { "R² = 1 − ", T.frac({ T.col("SS", "residual"), T.sub("", "res") }, { T.col("SS", "mean"), T.sub("", "tot") }) },
			numbers = function()
				return { "R² = 1 − ", T.frac({ T.col(Format.num(view:ssRes(), 1), "residual") }, { T.col(Format.num(view:ssTot(), 1), "mean") }) }
			end,
			result = function() return Format.num(1 - view:ssRes() / view:ssTot(), 3) end } },
	})
end

scene.r2Unlocks = {
	{ formula = "SSRES", line = "eq", when = function(sc) return sc.s.view.nRes == sc.s.view.n end },
	{ formula = "SSTOT", line = "eq", when = function(sc) return sc.s.view.nTot == sc.s.view.n end },
	{ formula = "R2", line = "eq", when = function(sc) return sc.s.view.phase == "done" end },
}
scene.unlocks = {
	scene.r2Unlocks[1], scene.r2Unlocks[2],
	{ formula = "R2", line = "eq", when = scene.r2Unlocks[3].when, onUnlock = function(sc)
		sc.shell:setText(S.done)
		sc:note(S.meaning)
	end },
}

function scene.enter(sc)
	local s = sc.s
	local idm = sc.Datasets.intercept_demo
	local o = sc.MathCore.ols1d(idm.bees_k, idm.honey_kg)
	local yhat = {}
	for i, x in idm.bees_k do
		yhat[i] = o.b1 * x + o.b0
	end
	s.view = R2View.new(sc.shell.main, {
		x = idm.bees_k, y = idm.honey_kg, yhat = yhat, line = { m = o.b1, c = o.b0 },
		xMin = 0, xMax = 70, xTicks = { 0, 10, 20, 30, 40, 50, 60, 70 }, yMin = 0, yMax = 45, yTicks = { 0, 10, 20, 30, 40 },
		xLabel = Strings.s2d["2D.2"].xLabel, yLabel = Strings.s2d["2D.2"].yLabel, unit = "кг²", meanStart = 8, snapTol = 1.5,
		store = sc.store,
		onPhase = function(phase)
			sc.shell:setText(S.phase[phase] or "")
			sc:progress()
		end,
		onChanged = function()
			sc:progress()
		end,
	})
	sc:conn({ Disconnect = function() s.view:Destroy() end })
	sc:keys("MeanUp", { Enum.KeyCode.LeftShift, Enum.KeyCode.Up }, function(down) s.meanDir = if down then 1 else 0 end)
	sc:keys("MeanDown", { Enum.KeyCode.LeftControl, Enum.KeyCode.Down }, function(down)
		s.meanDir = if down then -1 else 0
		if not down then s.view:_releaseMean() end
	end)
	scene.formulas(sc, s.view)
	sc.shell:setText(S.phase.res)
end

function scene.update(sc, dt)
	local s = sc.s
	if s.meanDir and s.meanDir ~= 0 then
		s.view:nudgeMean(s.meanDir * 8 * dt)
	elseif s.view.phase == "mean" and s.meanDir == 0 then
		s.meanDir = nil
		s.view:_releaseMean()
	end
end

function scene.canAdvance(sc)
	return sc.f.R2 ~= nil and sc.f.R2:isUnlocked("eq")
end

function scene.hintTargets(sc)
	local v = sc.s.view
	if v.phase == "res" then
		return { v.plot.area }
	elseif v.phase == "tot" then
		return { v.totBtn }
	end
	return { v.plot.area }
end

function scene.hintText(sc, level)
	local v = sc.s.view
	return Strings.hints["2D.7"][v.phase] and Strings.hints["2D.7"][v.phase][level] or nil
end

return scene
