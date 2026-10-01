--!nonstrict
-- 2D.5 L2 и L1: ограничение коэффициентов.
-- Слева L2 (Ridge, круг), справа L1 (Lasso, ромб). Плоскость коэффициентов (m_пчёлы, m_темп) малой выборки
-- (признаки стандартизованы по первым 5 точкам), эллипсы уровня Σe², точка OLS, область ограничения
-- размера t = ‖m(λ)‖ — решение всегда на границе, в точке касания самого низкого эллипса.
-- Общий ползунок λ ∈ [0; 20]. Пояснения открываются действием: L1 впервые «защёлкнулась» в вершину ромба;
-- L2 доведена до λ = 20 и всё ещё не ноль. Пути коэффициентов считаются один раз при входе (сетка 401 значение).

local Regression = script.Parent.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)
local Slider = require(Regression.UI.Slider)

local S = Strings.s2d["2D.5"]
local LAMBDA_MAX = 20
local GRID = 400
local LEVELS = { 4, 20, 60, 140 } -- фоновые эллипсы: SSE − SSE(OLS)

local scene = { id = "2D.5", panel = true }

function scene.enter(sc)
	local s, MathCore = sc.s, sc.MathCore
	sc.shell:setMainShare(0.68)
	local rows = sc.Datasets.small_sample.rows
	local X5, y5, Xr, yr = {}, {}, {}, {}
	for _, r in rows do
		if r.sample == "first5" then
			table.insert(X5, { r.bees_k, r.temperature_C }); table.insert(y5, r.honey_kg)
		else
			table.insert(Xr, { r.bees_k, r.temperature_C }); table.insert(yr, r.honey_kg)
		end
	end
	local Z5, mu, sd = MathCore.standardize(X5)
	local Zr = MathCore.standardize(Xr, mu, sd)
	s.Z5, s.y5, s.Zr, s.yr = Z5, y5, Zr, yr
	s.G = MathCore.gram(Z5)
	local b0, bOls = MathCore.ols(Z5, y5)
	s.bOls, s.b0 = bOls, b0
	s.sseOls = MathCore.sseCoef(Z5, y5, bOls)
	s.paths = { l2 = MathCore.path("l2", Z5, y5, LAMBDA_MAX, GRID), l1 = MathCore.path("l1", Z5, y5, LAMBDA_MAX, GRID) }
	local function r2rest(kind, lam)
		local c0, c = MathCore.pathAt(s.paths[kind], lam)
		return (MathCore.r2(yr, MathCore.predict(c0, c, Zr)))
	end
	s.r2rest = r2rest
	s.r2Ols = (MathCore.r2(yr, MathCore.predict(b0, bOls, Zr)))
	s.bonus = { ridge1 = r2rest("l2", 1), lasso15 = r2rest("l1", 1.5) }
	s.lambda = 0
	s.l1Snap, s.l2Max = false, false

	-- ── две половины ──
	local main = sc.shell.main
	local top = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -66), Parent = main })
	s.half = {}
	for i, kind in { "l2", "l1" } do
		local col = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromScale((i - 1) * 0.5, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = top })
		Gui.label({ Text = S.title[kind], Font = Theme.fontBold, TextSize = 20, TextColor3 = Theme.color.penalty, Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Center, Parent = col })
		local inner = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -96), Parent = col })
		local caption = Gui.label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 68),
			TextSize = 16, TextYAlignment = Enum.TextYAlignment.Top, Text = S.waiting[kind], TextColor3 = Theme.color.textDim, Parent = col })
		local plot = PlotView2D.new(inner, {
			xMin = -6, xMax = 18, yMin = -12, yMax = 12, equalAspect = true, equalCenterY = -1,
			xTicks = { -5, 0, 5, 10, 15 }, yTicks = { -20, -15, -10, -5, 0, 5, 10, 15, 20 },
			xLabel = S.xLabel, yLabel = S.yLabel, padL = 40, padR = 8, padT = 18, padB = 52, fontSize = 15, fallbackW = 300, fallbackH = 300,
		})
		s.half[kind] = { plot = plot, caption = caption }
		plot.onResize = function()
			scene.drawStatic(sc, kind)
			scene.draw(sc)
		end
	end

	-- ── ползунок λ под графиками ──
	local sliderHolder = Gui.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 60), Parent = main })
	s.slider = Slider.new(sliderHolder, {
		min = 0, max = LAMBDA_MAX, step = 0.05, buttonStep = 0.5, value = 0, label = "λ", color = Theme.color.penalty,
		format = function(v) return Format.num(v, 2) end,
		onChanged = function(v)
			s.lambda = v
			sc.store:set("lambda2d", v)
			sc:progress()
			s.dirty = true -- перерисовка — в update, не чаще 30 Гц
		end,
	})
	sc:conn({ Disconnect = function() s.slider:Destroy() end })
	sc:keys("LambdaUp", { Enum.KeyCode.E, Enum.KeyCode.Right }, function(down)
		s.keyDir = if down then 1 else 0
	end)
	sc:keys("LambdaDown", { Enum.KeyCode.Q, Enum.KeyCode.Left }, function(down)
		s.keyDir = if down then -1 else 0
	end)

	-- ── формулы ──
	local T = sc.T
	local m1, m2, lam = T.sub("m", "1", "m", "m"), T.sub("m", "2", "m_temp", "m_temp"), T.sym("λ", "penalty")
	local function sse(st, kind)
		local _, b = MathCore.pathAt(st.paths[kind], st.lambda)
		return MathCore.sseCoef(st.Z5, st.y5, b), b
	end
	sc:formula({
		id = "RIDGE", title = S.ridgeTitle, toNotebook = true,
		lines = { { id = "def", open = true,
			general = { T.sub("L", "ridge"), " = ", T.sum(), "e² + ", lam, "·(", m1, "² + ", m2, "²)" },
			numbers = function(st)
				local e2, b = sse(st, "l2")
				return { T.sub("L", "ridge"), " = ", T.col(Format.num(e2, 2), "residual"), " + ", T.col(Format.num(st.lambda, 2), "penalty"), "·(",
					T.col(Format.num(b[1], 2), "m"), "² + ", T.col(Format.num(b[2], 2), "m_temp"), "²)" }
			end,
			result = function(st)
				local e2, b = sse(st, "l2")
				return Format.num(e2 + st.lambda * (b[1] ^ 2 + b[2] ^ 2), 2)
			end } },
	})
	sc:formula({
		id = "LASSO", title = S.lassoTitle, toNotebook = true,
		lines = { { id = "def", open = true,
			general = { T.sub("L", "lasso"), " = ", T.sum(), "e² + ", lam, "·(|", m1, "| + |", m2, "|)" },
			numbers = function(st)
				local e2, b = sse(st, "l1")
				return { T.sub("L", "lasso"), " = ", T.col(Format.num(e2, 2), "residual"), " + ", T.col(Format.num(st.lambda, 2), "penalty"), "·(|",
					T.col(Format.num(b[1], 2), "m"), "| + |", T.col(Format.num(b[2], 2), "m_temp"), "|)" }
			end,
			result = function(st)
				local e2, b = sse(st, "l1")
				return Format.num(e2 + st.lambda * (math.abs(b[1]) + math.abs(b[2])), 2)
			end } },
	})
	sc:formula({
		id = "R2REST", title = S.r2Title, toNotebook = true,
		lines = {
			{ id = "now", open = true,
				general = { S.r2now },
				numbers = function(st)
					return { S.r2nowRidge, T.col(Format.num(st.r2rest("l2", st.lambda), 3), "penalty"), " · ", S.r2nowLasso,
						T.col(Format.num(st.r2rest("l1", st.lambda), 3), "penalty") }
				end },
			{ id = "bonus", hint = S.lockBonus,
				general = { S.bonus:format(Format.num(s.r2Ols, 3), Format.num(s.bonus.ridge1, 3), Format.num(s.bonus.lasso15, 3)) } },
		},
	})
	sc.shell:setText(S.intro)
	sc.shell:ask(S.bet, function(k)
		s.bet = k
		sc:progress()
	end)
	for _, kind in { "l2", "l1" } do
		scene.drawStatic(sc, kind)
	end
	scene.draw(sc)
end

local function ellipse(sc, center, level)
	local pts = {}
	for k = 0, 72 do
		local p = sc.MathCore.ellipsePoint(sc.s.G, center, level, k / 72 * 2 * math.pi)
		pts[k + 1] = { p[1], p[2] }
	end
	return pts
end

function scene.drawStatic(sc, kind)
	local s = sc.s
	local plot = s.half[kind].plot
	local L = plot:layer("static", 2)
	L:begin()
	for _, lv in LEVELS do
		L:polyline(ellipse(sc, s.bOls, lv), { color = Theme.color.loss, thickness = 1, transparency = 0.6 })
	end
	L:dot(s.bOls[1], s.bOls[2], { color = Theme.color.loss, size = 14, hollow = true })
	L:label(s.bOls[1], s.bOls[2], "OLS", { dx = 8, dy = -6, anchor = Vector2.new(0, 1), size = 15, color = Theme.color.loss })
	L:finish()
end

function scene.draw(sc)
	local s = sc.s
	local MathCore = sc.MathCore
	for _, kind in { "l2", "l1" } do
		local h = s.half[kind]
		local _, b = MathCore.pathAt(s.paths[kind], s.lambda)
		h.b = b
		local plot = h.plot
		local L = plot:layer("dynamic", 3)
		L:begin()
		-- область ограничения
		if kind == "l2" then
			local r = math.sqrt(b[1] ^ 2 + b[2] ^ 2)
			local pts = {}
			for k = 0, 72 do
				local a = k / 72 * 2 * math.pi
				pts[k + 1] = { r * math.cos(a), r * math.sin(a) }
			end
			L:polyline(pts, { color = Theme.color.penalty, thickness = 3 })
		else
			local t = math.abs(b[1]) + math.abs(b[2])
			L:polyline({ { t, 0 }, { 0, t }, { -t, 0 }, { 0, -t } }, { color = Theme.color.penalty, thickness = 3 }, true)
			if s.l1Snap and b[2] == 0 then
				L:dot(t, 0, { color = Theme.color.c, size = 22, hollow = true })
			end
		end
		-- самый низкий эллипс, касающийся области
		local lvl = MathCore.sseCoef(s.Z5, s.y5, b) - s.sseOls
		if lvl > 1e-6 then
			L:polyline(ellipse(sc, s.bOls, lvl), { color = Theme.color.loss, thickness = 3 })
		end
		L:dot(b[1], b[2], { color = Theme.color.penalty, size = 16, strokeColor = Theme.color.text })
		L:label(b[1], b[2], ("(%s; %s)"):format(Format.num(b[1], 2), Format.num(b[2], 2)), {
			dx = 10, dy = 6, anchor = Vector2.new(0, 0), size = 16, color = Theme.color.text, font = Theme.fontBold })
		L:finish()
	end
	-- события-действия
	local b1 = s.half.l1.b
	if not s.l1Snap and b1 and b1[2] == 0 and s.lambda > 0 then
		s.l1Snap = true
		s.half.l1.caption.Text = S.captionL1
		s.half.l1.caption.TextColor3 = Theme.color.text
		sc:toast(S.snapToast, Theme.color.penalty)
		if s.bet then
			local correct = s.bet == 2
			sc.shell:resolve(correct, S.bet.reveal)
			if correct then
				sc:honey(1)
			end
		end
		sc:progress()
	end
	if not s.l2Max and s.lambda >= LAMBDA_MAX - 1e-9 then
		s.l2Max = true
		local b2 = s.half.l2.b
		s.half.l2.caption.Text = S.captionL2:format(Format.num(b2[1], 2), Format.num(b2[2], 2))
		s.half.l2.caption.TextColor3 = Theme.color.text
		sc:progress()
	end
end

function scene.update(sc, dt)
	local s = sc.s
	if s.keyDir and s.keyDir ~= 0 then
		s.slider:set(s.slider.value + s.keyDir * 4 * dt)
	end
	if s.dirty then
		s.dirty = false
		scene.draw(sc)
	end
end

scene.unlocks = {
	{ formula = "R2REST", line = "bonus", when = function(sc) return sc.s.l1Snap and sc.s.l2Max end },
}

function scene.canAdvance(sc)
	return sc.s.l1Snap and sc.s.l2Max
end

function scene.hintTargets(sc)
	return { sc.s.slider.frame }
end

return scene
