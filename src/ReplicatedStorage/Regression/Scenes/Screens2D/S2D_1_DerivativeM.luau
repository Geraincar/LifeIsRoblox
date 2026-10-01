--!nonstrict
-- 2D.1 Минимум параболы — это dL/dm = 0.
-- Парабола игрока из 3D (записи, вершина m*). Действия: «Показать L = n·MSE» (график переходит к сумме L),
-- бегунок с касательной по параболе (перетаскивание, Q/E, кнопки), ставка про наклон касательной в минимуме.
-- Открытие: dL/dm — после первого сдвига бегунка; dL/dm = 0 ⇒ m = ΣΔxΔy / Σ(Δx)² — когда |dL/dm| < 0,3.

local Regression = script.Parent.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)
local Drag = require(Regression.UI.Drag)
local Records = require(Regression.Core.Records)

local S = Strings.s2d["2D.1"]
local M_MIN, M_MAX = -1, 1.5
local RUNNER_SPEED = 0.3 -- м/м в секунду при удержании
local SNAP_TOL = 0.03
local ZERO_TOL = 0.3 -- |dL/dm| < 0,3 — касательная «горизонтальна»

-- Парабола из 3D; если игрок пришёл сюда в обход (отладка) — эталонные записи при h = 1,0
local function parabolaFrom(sc)
	local P = sc.store:get("parabola")
	if P then
		return P
	end
	local fb = sc.Datasets.flowerbed
	local MathCore = sc.MathCore
	local recs = {}
	for _, m in { -0.2, 0.0, 0.2, 0.5, 0.8 } do
		local c = MathCore.lineFromPivot(m, 1.0, fb.pivot_x_m)
		table.insert(recs, { m = m, mse = MathCore.mseLine(fb.x_m, fb.y_m, m, c), h = 1.0 })
	end
	P = Records.fit(MathCore, recs)
	P.h, P.records = 1.0, recs
	return P
end

local scene = { id = "2D.1", panel = true }

function scene.enter(sc)
	local s, T, MathCore = sc.s, sc.T, sc.MathCore
	local fb = sc.Datasets.flowerbed
	local x, y = fb.x_m, fb.y_m
	local P = parabolaFrom(sc)
	local o = MathCore.ols1d(x, y)
	s.P, s.o, s.n = P, o, #x
	s.h = P.h
	s.a, s.b, s.k = MathCore.slopeLoss(x, y, s.h, fb.pivot_x_m)
	s.mStar = o.sxy / o.sxx -- 0,33
	s.mode = "mse"
	s.mr = -0.5
	s.moved = false
	s.held = 0

	local function L(m)
		return s.a * m * m + s.b * m + s.k
	end
	local function dL(m)
		return 2 * s.a * m + s.b
	end
	s.L, s.dL = L, dL
	local function sync()
		s.c = MathCore.lineFromPivot(s.mr, s.h, fb.pivot_x_m)
		s.Lv = L(s.mr)
		s.mse = s.Lv / s.n
		s.deriv = dL(s.mr)
	end
	s.sync = sync
	sync()

	-- ── график ──
	local holder = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64), Parent = sc.shell.main })
	s.title = Gui.label({ Text = S.plotTitleMse, Font = Theme.fontBold, TextSize = 22, Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -64, 0, 28), Parent = holder })
	local inner = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), Parent = holder })
	s.plot = PlotView2D.new(inner, {
		xMin = M_MIN, xMax = M_MAX, yMin = 0, yMax = 2,
		xTicks = { -1, -0.5, 0, 0.5, 1, 1.5 }, yTicks = { 0, 0.5, 1, 1.5, 2 },
		xLabel = Strings.plotX, yLabel = Strings.plotY, padL = 60, padR = 14, padT = 16, padB = 60, fontSize = 18,
		fallbackW = 560, fallbackH = 420,
	})
	s.plot.onResize = function()
		scene.draw(sc)
	end

	-- ── кнопки под графиком: ◀ ▶ (удержание), «Показать L» ──
	local bar = Gui.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56), Parent = sc.shell.main })
	Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = bar })
	s.showL = Gui.button({ Text = S.showL, Size = UDim2.fromOffset(250, 50), BackgroundColor3 = Theme.color.loss, TextColor3 = Theme.color.bg,
		LayoutOrder = 1, Parent = bar })
	s.showL.Activated:Connect(function()
		scene.switchToL(sc)
	end)
	s.runnerBtns = {}
	for i, spec in { { "◀  m", -1 }, { "m  ▶", 1 } } do
		local b = Gui.button({ Text = spec[1], Size = UDim2.fromOffset(110, 50), LayoutOrder = 1 + i, Visible = false, Parent = bar })
		Gui.stroke(Theme.color.m, 2).Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				s.held = spec[2]
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				scene.release(sc)
			end
		end)
		s.runnerBtns[i] = b
	end
	s.flagNote = Gui.label({ Text = "", TextSize = 18, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Theme.color.good, LayoutOrder = 9, Parent = bar })

	sc:keys("RunnerUp", { Enum.KeyCode.Q, Enum.KeyCode.Right }, function(down)
		if down then s.held = 1 elseif s.held == 1 then scene.release(sc) end
	end)
	sc:keys("RunnerDown", { Enum.KeyCode.E, Enum.KeyCode.Left }, function(down)
		if down then s.held = -1 elseif s.held == -1 then scene.release(sc) end
	end)

	-- бегунок: перетаскивание по области графика (только по оси m)
	s.drag = Drag.attach(s.plot.area, {
		began = function(p)
			if s.mode ~= "L" then
				return false
			end
			scene.dragTo(sc, p)
			return true
		end,
		moved = function(p)
			scene.dragTo(sc, p)
		end,
		ended = function()
			scene.release(sc)
		end,
	})
	sc:conn({ Disconnect = s.drag.Destroy })

	-- ── формулы ──
	local m, c, nTok = T.sym("m", "m"), T.sym("c", "c"), "n"
	sc:formula({
		id = "LOSS", title = S.lossTitle, toNotebook = true,
		lines = {
			{ id = "def", open = true,
				general = { T.sym("L", "loss"), "(", m, ", ", c, ") = ", T.sum(), "(", T.sub("y", "i"), " − (", m, "·", T.sub("x", "i"), " + ", c, "))", T.sup("", "2") },
				numbers = function(st)
					return { T.sym("L", "loss"), " = ", T.sum(), "(", T.sub("y", "i"), " − (", T.col(Format.coef(st.mr), "m"), "·", T.sub("x", "i"),
						" + ", T.col(Format.num(st.c, 2), "c"), "))", T.sup("", "2") }
				end,
				result = function(st) return Format.area(st.Lv) end },
			{ id = "mse", open = true,
				general = { "MSE = ", T.sym("L", "loss"), " / ", nTok },
				numbers = function(st) return { "MSE = ", T.col(Format.num(st.Lv, 3), "loss"), " / ", tostring(st.n) } end,
				result = function(st) return Format.mse(st.mse) end },
			{ id = "Lm", hint = S.lockLm,
				general = { T.sym("L", "loss"), "(", m, ") = ", T.sum(), "(Δx)²·", m, "² − 2·", T.sum(), "ΔxΔy·", m, " + ", T.sum(), "(Δy)² + n·(",
					T.bar("y", "mean", "mean"), " − ", T.sym("h", "c"), ")²" },
				numbers = function(st)
					return { T.sym("L", "loss"), "(", m, ") = ", Format.num(st.a, 0), "·", m, "² ", Format.MINUS, " ", Format.num(-st.b, 1), "·", m, " + ",
						Format.num(st.o.syy, 2), " + ", tostring(st.n), "·(", Format.num(st.o.yMean, 1), " − ", T.col(Format.num(st.h, 2), "c"), ")²" }
				end,
				result = function(st) return Format.area(st.Lv) end },
		},
	})
	sc:formula({
		id = "DLDM", title = S.derivTitle, toNotebook = true,
		lines = {
			{ id = "deriv", hint = S.lockDeriv,
				general = { T.d("L", "m", "m"), " = 2·", T.sum(), "(Δx)²·", m, " − 2·", T.sum(), "ΔxΔy" },
				numbers = function(st)
					return { T.d("L", "m", "m"), " = ", Format.num(2 * st.a, 0), "·", T.col(Format.coef(st.mr), "m"), " ", Format.MINUS, " ", Format.num(-st.b, 1) }
				end,
				result = function(st) return Format.signed(st.deriv, 2) end },
			{ id = "zero", hint = S.lockZero,
				general = { T.d("L", "m", "m"), " = 0  ⇒  ", m, " = ", T.frac({ T.sum(), "ΔxΔy" }, { T.sum(), "(Δx)²" }) },
				numbers = function(st)
					return { T.d("L", "m", "m"), " = 0  ⇒  ", m, " = ", T.frac({ Format.num(st.o.sxy, 1) }, { Format.num(st.o.sxx, 0) }) }
				end,
				result = function(st) return Format.coef(st.mStar) end },
		},
	})
	sc.shell:setText(S.intro)
	scene.draw(sc)
end

function scene.switchToL(sc)
	local s = sc.s
	if s.mode == "L" then
		return
	end
	s.mode = "L"
	s.showL.Visible = false
	for _, b in s.runnerBtns do
		b.Visible = true
	end
	s.title.Text = S.plotTitleL
	s.plot:setRange(M_MIN, M_MAX, 0, 10, nil, { 0, 2, 4, 6, 8, 10 })
	s.plot.opts.yLabel = S.plotYL
	s.plot:drawGrid()
	sc.shell:setText(S.afterL)
	sc:progress()
	sc.shell:ask(S.bet, function(k)
		s.bet = k
		sc:progress()
	end)
	scene.draw(sc)
end

function scene.dragTo(sc, p: Vector2)
	local s = sc.s
	local px = s.plot:screenToPx(p.X, p.Y)
	local m = s.plot:fromPx(px, 0)
	scene.setRunner(sc, m)
end

function scene.setRunner(sc, m: number)
	local s = sc.s
	m = math.clamp(m, M_MIN, M_MAX)
	if m ~= s.mr then
		s.mr = m
		s.moved = true
		s.sync()
		sc.store:set("runner2d", m) -- для проверки условий открытия
		sc:progress()
		s.dirty = true -- перерисовка — в update, не чаще 30 Гц
	end
end

-- отпускание: прилипание к минимуму
function scene.release(sc)
	local s = sc.s
	s.held = 0
	if math.abs(s.mr - s.mStar) < SNAP_TOL then
		s.mr = s.mStar
		s.sync()
		sc.store:set("runner2d", s.mr)
		scene.draw(sc)
	end
end

function scene.update(sc, dt)
	local s = sc.s
	if s.held ~= 0 and s.mode == "L" then
		scene.setRunner(sc, s.mr + s.held * RUNNER_SPEED * dt)
	end
	if s.dirty then
		s.dirty = false
		scene.draw(sc)
	end
end

function scene.draw(sc)
	local s = sc.s
	local P = s.P
	local scaleY = if s.mode == "L" then s.n else 1
	local hl = sc.store:get("highlight")

	local curve = s.plot:layer("curve", 3)
	curve:begin()
	curve:curve(function(m)
		return (P.a * m * m + P.b * m + P.k) * scaleY
	end, M_MIN, M_MAX, 100, { color = Theme.color.loss, thickness = if hl == "loss" then 5 else 3 })
	curve:finish()

	local pts = s.plot:layer("points", 5)
	pts:begin()
	for _, r in P.records or {} do
		pts:dot(r.m, r.mse * scaleY, { color = Theme.color.loss, size = 14, strokeColor = Theme.color.bg })
	end
	pts:finish()

	local flag = s.plot:layer("flag", 4)
	flag:begin()
	local vStar = P.vStar * scaleY
	flag:dashedV(P.tStar, 0, vStar, { color = Theme.color.flag, thickness = 2 })
	flag:dot(P.tStar, vStar, { color = Theme.color.flag, size = 14 })
	flag:label(P.tStar, vStar, S.flag:format(Format.coef(P.tStar)), { dx = 10, dy = 26, anchor = Vector2.new(0, 0), size = 18, color = Theme.color.flag })
	flag:finish()

	local run = s.plot:layer("runner", 6)
	run:begin()
	if s.mode == "L" then
		local m0, L0, d = s.mr, s.Lv, s.deriv
		local w = 0.35
		local horizontal = math.abs(d) < ZERO_TOL
		run:seg(m0 - w, L0 - d * w, m0 + w, L0 + d * w, { color = if horizontal then Theme.color.good else Theme.color.m, thickness = 4 })
		run:dot(m0, L0, { color = Theme.color.m, size = 22, strokeColor = Theme.color.text })
		run:label(m0, L0, ("m = %s"):format(Format.coef(m0)), { dx = -10, dy = -14, anchor = Vector2.new(1, 1), size = 18, color = Theme.color.mText })
	end
	run:finish()
end

scene.unlocks = {
	{ formula = "LOSS", line = "Lm", when = function(sc) return sc.s.mode == "L" end },
	{ formula = "DLDM", line = "deriv", when = function(sc) return sc.s.moved end },
	{
		formula = "DLDM", line = "zero",
		when = function(sc)
			local s = sc.s
			return s.moved and s.held == 0 and math.abs(s.deriv) < ZERO_TOL
		end,
		onUnlock = function(sc)
			local s = sc.s
			s.flagNote.Text = S.flagMatch:format(Format.coef(s.P.tStar))
			sc.shell:setText(S.done)
			if s.bet then
				local correct = s.bet == 2
				sc.shell:resolve(correct, S.bet.reveal)
				if correct then
					sc:honey(1)
				end
			end
		end,
	},
}

function scene.canAdvance(sc)
	return sc.f.DLDM ~= nil and sc.f.DLDM:isUnlocked("zero")
end

function scene.hintTargets(sc)
	return { if sc.s.mode == "L" then sc.s.plot.area else sc.s.showL }
end

function scene.hintText(sc, level)
	if level == 3 then
		return Strings.hints["2D.1"][3]:format(Format.coef(sc.s.mStar))
	end
	return nil
end

return scene
