--!nonstrict
-- 2D.6 Сумма ошибки от наклона при разных λ (данные клумбы, один признак — без стандартизации).
-- Два графика: L2 — L(m) + λ·m², L1 — L(m) + λ·|m|; L(m) — сумма квадратов при оптимальном c.
-- Ползунок λ ∈ [0; 10]; при отпускании текущая кривая остаётся бледным следом.
-- Игрок отмечает «где минимум» тапом по графику → игра показывает точный минимум.
-- Задание: найти λ, при котором минимум L1 впервые становится нулём (λ = 2·ΣΔxΔy = 6,6) — «излом в нуле».

local Regression = script.Parent.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)
local Slider = require(Regression.UI.Slider)
local Drag = require(Regression.UI.Drag)

local S = Strings.s2d["2D.6"]
local M_MIN, M_MAX = -0.2, 0.6
local LAMBDA_MAX = 10
local MAX_TRAILS = 4
local FIRST_ZERO_TOL = 0.3 -- λ из [6,6; 6,9] — «впервые ноль»
local GUESS_GOOD = 0.03

local scene = { id = "2D.6", panel = true }

function scene.enter(sc)
	local s, MathCore = sc.s, sc.MathCore
	sc.shell:setMainShare(0.66)
	local fb = sc.Datasets.flowerbed
	s.x, s.y = fb.x_m, fb.y_m
	s.o = MathCore.ols1d(s.x, s.y)
	s.lambda = 0
	s.trails = {}
	s.guess = {}
	s.exactShown = {}
	s.task = false
	s.zeroLambda = 2 * s.o.sxy -- 6,6

	local main = sc.shell.main
	local top = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -66), Parent = main })
	s.half = {}
	for i, kind in { "l2", "l1" } do
		local col = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromScale((i - 1) * 0.5, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = top })
		Gui.label({ Text = S.title[kind], Font = Theme.fontBold, TextSize = 19, Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, Parent = col })
		local inner = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), Parent = col })
		local plot = PlotView2D.new(inner, {
			xMin = M_MIN, xMax = M_MAX, yMin = 0, yMax = 4, xTicks = { -0.2, 0, 0.2, 0.4, 0.6 }, yTicks = { 0, 1, 2, 3, 4 },
			xLabel = Strings.plotX, yLabel = S.yLabel, padL = 40, padR = 8, padT = 14, padB = 56, fontSize = 15, fallbackW = 300, fallbackH = 380,
		})
		local h = { plot = plot, kind = kind }
		s.half[kind] = h
		plot.onResize = function()
			scene.draw(sc)
		end
		-- тап по графику — «здесь минимум»
		h.drag = Drag.attach(plot.area, {
			began = function(p)
				local px = plot:screenToPx(p.X, p.Y)
				local m = plot:fromPx(px, 0)
				scene.mark(sc, kind, m)
				return false
			end,
		})
		sc:conn({ Disconnect = h.drag.Destroy })
	end

	local sliderHolder = Gui.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 60), Parent = main })
	s.slider = Slider.new(sliderHolder, {
		min = 0, max = LAMBDA_MAX, step = 0.1, buttonStep = 0.1, value = 0, label = "λ", color = Theme.color.penalty, format = Format.lambda,
		onChanged = function(v)
			s.lambda = v
			s.exactShown = {}
			sc.store:set("lambda2d", v)
			sc:progress()
			s.dirty = true -- перерисовка — в update, не чаще 30 Гц
		end,
		onReleased = function(v)
			scene.released(sc, v)
		end,
	})
	sc:conn({ Disconnect = function() s.slider:Destroy() end })

	local T = sc.T
	local m, lam = T.sym("m", "m"), T.sym("λ", "penalty")
	sc:formula({
		id = "CURVES", title = S.curvesTitle,
		lines = {
			{ id = "l2", open = true, general = { T.sym("L", "loss"), "(", m, ") + ", lam, "·", m, "²" },
				numbers = function(st) return { Format.num(st.o.sxx, 0), "·", m, "² − ", Format.num(2 * st.o.sxy, 1), "·", m, " + ", Format.num(st.o.syy, 2),
					" + ", T.col(Format.lambda(st.lambda), "penalty"), "·", m, "²" } end },
			{ id = "l1", open = true, general = { T.sym("L", "loss"), "(", m, ") + ", lam, "·|", m, "|" },
				numbers = function(st) return { Format.num(st.o.sxx, 0), "·", m, "² − ", Format.num(2 * st.o.sxy, 1), "·", m, " + ", Format.num(st.o.syy, 2),
					" + ", T.col(Format.lambda(st.lambda), "penalty"), "·|", m, "|" } end },
		},
	})
	sc:formula({
		id = "MIN2", title = S.min2Title, toNotebook = true,
		lines = { { id = "eq", hint = S.lockMin,
			general = { m, "* = ", T.frac({ T.sum(), "ΔxΔy" }, { T.sum(), "(Δx)² + ", lam }) },
			numbers = function(st) return { m, "* = ", T.frac({ Format.num(st.o.sxy, 1) }, { Format.num(st.o.sxx, 0), " + ", T.col(Format.lambda(st.lambda), "penalty") }) } end,
			result = function(st) return Format.num(sc.MathCore.penalizedMin1d(st.x, st.y, st.lambda, "l2"), 3) end } },
	})
	sc:formula({
		id = "MIN1", title = S.min1Title, toNotebook = true,
		lines = {
			{ id = "eq", hint = S.lockMin,
				general = { m, "* = ", T.frac({ "2·", T.sum(), "ΔxΔy − ", lam }, { "2·", T.sum(), "(Δx)²" }) },
				numbers = function(st) return { m, "* = ", T.frac({ Format.num(2 * st.o.sxy, 1), " − ", T.col(Format.lambda(st.lambda), "penalty") }, { Format.num(2 * st.o.sxx, 0) }) } end,
				result = function(st) return Format.num(sc.MathCore.penalizedMin1d(st.x, st.y, st.lambda, "l1"), 3) end },
			{ id = "kink", hint = S.lockKink,
				general = { lam, " ≥ 2·", T.sum(), "ΔxΔy  ⇒  ", m, "* = 0" },
				numbers = function(st) return { lam, " ≥ ", Format.num(st.zeroLambda, 1), "  ⇒  ", m, "* = 0" } end },
		},
	})
	sc.shell:setText(S.intro)
	sc.shell:setTask(S.task)
	scene.draw(sc)
end

function scene.lossAt(sc, kind: string, m: number, lam: number): number
	return sc.MathCore.penalizedLoss1d(sc.s.x, sc.s.y, m, lam, kind)
end

function scene.mark(sc, kind: string, m: number)
	local s = sc.s
	s.guess[kind] = math.clamp(m, M_MIN, M_MAX)
	s.exactShown[kind] = true
	s.anyGuess = true
	s.guessed = s.guessed or {}
	s.guessed[kind] = true
	local exact = sc.MathCore.penalizedMin1d(s.x, s.y, s.lambda, kind)
	local d = math.abs(s.guess[kind] - exact)
	if d < GUESS_GOOD then
		sc:toast(S.guessGood:format(Format.num(exact, 3)), Theme.color.good)
		s.goodGuess = s.goodGuess or {}
		if not s.goodGuess[kind] then
			s.goodGuess[kind] = true
			sc:honey(1)
		end
	else
		sc:toast(S.guessOff:format(Format.num(exact, 3), Format.num(d, 2)), Theme.color.c)
	end
	sc.store:set("guess2d", os.clock())
	sc:progress()
	scene.draw(sc)
end

function scene.released(sc, v: number)
	local s = sc.s
	-- след: прошлые λ остаются бледными кривыми
	local last = s.trails[#s.trails]
	if last == nil or math.abs(last - v) >= 0.5 then
		table.insert(s.trails, v)
		if #s.trails > MAX_TRAILS then
			table.remove(s.trails, 1)
		end
	end
	local m1 = sc.MathCore.penalizedMin1d(s.x, s.y, v, "l1")
	if not s.task and m1 == 0 and v - s.zeroLambda < FIRST_ZERO_TOL - 1e-9 then
		s.task = true
		sc.store:set("task2d6", true)
		sc.shell:setText(S.kink:format(Format.num(s.zeroLambda, 1)))
		sc:toast(S.taskDone, Theme.color.good)
		sc:note(S.note)
		sc:honey(1)
	elseif not s.task and m1 == 0 then
		sc:toast(S.tooFar, Theme.color.c)
	end
	sc:progress()
	scene.draw(sc)
end

function scene.draw(sc)
	local s = sc.s
	for _, kind in { "l2", "l1" } do
		local h = s.half[kind]
		local plot = h.plot
		local tr = plot:layer("trails", 2)
		tr:begin()
		for _, lam in s.trails do
			if math.abs(lam - s.lambda) > 1e-9 then
				tr:curve(function(m) return scene.lossAt(sc, kind, m, lam) end, M_MIN, M_MAX, 60, { color = Theme.color.penalty, thickness = 2, transparency = 0.65 })
				local mm = sc.MathCore.penalizedMin1d(s.x, s.y, lam, kind)
				tr:label(M_MAX, scene.lossAt(sc, kind, M_MAX, lam), "λ=" .. Format.lambda(lam), { dx = -4, anchor = Vector2.new(1, 1), size = 13, color = Theme.color.textDim })
				tr:dot(mm, scene.lossAt(sc, kind, mm, lam), { color = Theme.color.penalty, size = 8, transparency = 0.5 })
			end
		end
		tr:finish()

		local cur = plot:layer("current", 3)
		cur:begin()
		-- без штрафа — тонкая базовая кривая L(m)
		cur:curve(function(m) return scene.lossAt(sc, kind, m, 0) end, M_MIN, M_MAX, 60, { color = Theme.color.loss, thickness = 1, transparency = 0.5 })
		cur:curve(function(m) return scene.lossAt(sc, kind, m, s.lambda) end, M_MIN, M_MAX, 100, { color = Theme.color.penalty, thickness = 3 })
		cur:finish()

		local mk = plot:layer("marks", 5)
		mk:begin()
		local g = s.guess[kind]
		if g then
			mk:dashedV(g, 0, 4, { color = Theme.color.c, thickness = 2 })
			mk:label(g, 3.9, S.yourGuess, { dx = 4, anchor = Vector2.new(0, 0), size = 14, color = Theme.color.c })
		end
		if s.exactShown[kind] then
			local mm = sc.MathCore.penalizedMin1d(s.x, s.y, s.lambda, kind)
			local v = scene.lossAt(sc, kind, mm, s.lambda)
			mk:dot(mm, v, { color = Theme.color.flag, size = 14 })
			mk:label(mm, v, "m* = " .. Format.num(mm, 3), { dx = 6, dy = 20, anchor = Vector2.new(0, 0), size = 16, color = Theme.color.flag, font = Theme.fontBold })
		end
		mk:finish()
	end
end

scene.unlocks = {
	{ formula = "MIN2", line = "eq", when = function(sc) return sc.s.guessed ~= nil and sc.s.guessed.l2 == true end },
	{ formula = "MIN1", line = "eq", when = function(sc) return sc.s.guessed ~= nil and sc.s.guessed.l1 == true end },
	{ formula = "MIN1", line = "kink", when = function(sc) return sc.s.task end },
}

function scene.update(sc)
	local s = sc.s
	if s.dirty then
		s.dirty = false
		scene.draw(sc)
	end
end

function scene.canAdvance(sc)
	return sc.s.task and sc.s.anyGuess == true
end

function scene.hintTargets(sc)
	local s = sc.s
	if not s.anyGuess then
		return { s.half.l1.plot.area }
	end
	return { s.slider.frame }
end

return scene
