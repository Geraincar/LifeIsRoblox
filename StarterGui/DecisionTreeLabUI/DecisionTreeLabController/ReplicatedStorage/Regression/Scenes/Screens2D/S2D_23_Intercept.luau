--!nonstrict
-- 2D.2 Новый график: ищем свободный член. 2D.3 Минимум по свободному члену — это dL/dc = 0.
-- Одна «лаборатория» на обе сцены (графики остаются при переходе 2D.2 → 2D.3):
--   слева — 5 ульев (пчёлы → мёд), прямая постоянного наклона m = 0,47, точка пересечения с OY, остатки и их квадраты;
--   справа — записи (c, MSE), после пяти — парабола и минимум c* = 6,2.
-- Управление прямой: перетаскивание по графику, Shift/Ctrl (↑/↓), кнопки ▲ ▼ (удержание), R — записать.

local Regression = script.Parent.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)
local Drag = require(Regression.UI.Drag)

local S2, S3 = Strings.s2d["2D.2"], Strings.s2d["2D.3"]
local C_MIN, C_MAX = -2, 14
local C_SPEED = 4 -- кг/с при удержании
local C_GRID = 0.1
local MIN_DC = 1.0 -- записи должны различаться по c хотя бы на 1 кг
local SNAP_TOL = 0.3
local NEED = 5

local function kg(v: number, d: number?): string
	return Format.unit(v, d or 1, "кг")
end

-- ───── лаборатория ─────

local Lab = {}
Lab.__index = Lab

function Lab.new(sc)
	local self = setmetatable({}, Lab)
	local idm = sc.Datasets.intercept_demo
	local MathCore = sc.MathCore
	self.sc = sc
	self.MathCore = MathCore
	self.x, self.y = idm.bees_k, idm.honey_kg
	self.n = #self.x
	self.m = idm.fixed_slope
	self.c = 0
	self.records = {}
	self.held = 0
	self.moved = false
	local o = MathCore.ols1d(self.x, self.y)
	self.o = o
	self.cStar = o.yMean - self.m * o.xMean -- 6,2
	self.recordEnabled = false
	self.sumX, self.sumY = o.xMean * self.n, o.yMean * self.n

	local main = sc.shell.main
	local top = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -62), Parent = main })
	local left = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(0.58, -6, 1, 0), Parent = top })
	local right = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.42, 0, 1, 0), Parent = top })
	Gui.label({ Text = S2.plotTitle, Font = Theme.fontBold, TextSize = 20, Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -56, 0, 26), Parent = left })
	self.rightTitle = Gui.label({ Text = S3.plotTitle, Font = Theme.fontBold, TextSize = 20, Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -52, 0, 26), Visible = false, Parent = right })
	local li = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), Parent = left })
	local ri = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), Visible = false, Parent = right })
	self.rightHolder = ri
	self.plot = PlotView2D.new(li, {
		xMin = 0, xMax = 70, yMin = 0, yMax = 45, xTicks = { 0, 10, 20, 30, 40, 50, 60, 70 }, yTicks = { 0, 10, 20, 30, 40 },
		xLabel = S2.xLabel, yLabel = S2.yLabel, padL = 52, padR = 10, padT = 14, padB = 58, fontSize = 17, fallbackW = 380, fallbackH = 420,
	})
	self.mplot = PlotView2D.new(ri, {
		xMin = C_MIN, xMax = C_MAX, yMin = 0, yMax = 50, xTicks = { 0, 3, 6, 9, 12 }, yTicks = { 0, 10, 20, 30, 40, 50 },
		xLabel = S3.xLabel, yLabel = S3.yLabel, padL = 48, padR = 10, padT = 14, padB = 58, fontSize = 17, fallbackW = 260, fallbackH = 420,
	})
	self.plot.onResize = function() self:draw() end
	self.mplot.onResize = function() self:draw() end

	-- кнопки под графиками
	local bar = Gui.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56), Parent = main })
	Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = bar })
	for i, spec in { { "▲  c", 1 }, { "▼  c", -1 } } do
		local b = Gui.button({ Text = spec[1], Size = UDim2.fromOffset(96, 50), LayoutOrder = i, Parent = bar })
		Gui.stroke(Theme.color.c, 2).Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				self.held = spec[2]
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				self:release()
			end
		end)
	end
	self.recordBtn = Gui.button({ Text = S3.record, Size = UDim2.fromOffset(170, 50), LayoutOrder = 3, Visible = false,
		BackgroundColor3 = Theme.color.loss, TextColor3 = Theme.color.bg, Parent = bar })
	self.recordBtn.Activated:Connect(function()
		self:record()
	end)
	self.counter = Gui.label({ Text = "", TextSize = 18, TextColor3 = Theme.color.textDim, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 4, Parent = bar })

	-- перетаскивание прямой (по вертикали, без скачка)
	self.drag = Drag.attach(self.plot.area, {
		began = function(p)
			local _, py = self.plot:screenToPx(p.X, p.Y)
			local _, yd = self.plot:fromPx(0, py)
			self.dragStart = { y = yd, c = self.c }
			return true
		end,
		moved = function(p)
			if not self.dragStart then
				return
			end
			local _, py = self.plot:screenToPx(p.X, p.Y)
			local _, yd = self.plot:fromPx(0, py)
			self:setC(self.dragStart.c + (yd - self.dragStart.y))
		end,
		ended = function()
			self.dragStart = nil
			self:release()
		end,
	})
	self:sync()
	self:draw()
	return self
end

function Lab:bindKeys(sc)
	sc:keys("CUp", { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.Up }, function(down)
		if down then self.held = 1 elseif self.held == 1 then self:release() end
	end)
	sc:keys("CDown", { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.Down }, function(down)
		if down then self.held = -1 elseif self.held == -1 then self:release() end
	end)
	sc:keys("CRecord", { Enum.KeyCode.R }, function(down)
		if down then self:record() end
	end)
	self.sc = sc
end

function Lab:sync()
	local MathCore = self.MathCore
	self.mse = MathCore.mseLine(self.x, self.y, self.m, self.c)
	self.L = self.mse * self.n
	self.dldc = MathCore.dLdc(self.x, self.y, self.m, self.c)
end

function Lab:setC(c: number)
	c = math.clamp(c, C_MIN, C_MAX)
	if c == self.c then
		return
	end
	self.c = c
	self.moved = true
	self:sync()
	self.sc.store:set("c2d", c)
	self.sc:progress()
	self.dirty = true -- перерисовка — в update, не чаще 30 Гц
end

function Lab:release()
	self.held = 0
	local c = math.round(self.c / C_GRID) * C_GRID
	c = tonumber(string.format("%.4f", c)) :: number
	if self.parabola and math.abs(c - self.cStar) < SNAP_TOL then
		c = self.cStar
	end
	if c ~= self.c then
		self.c = c
		self:sync()
		self.sc.store:set("c2d", c)
		self:draw()
	end
end

function Lab:update(dt: number)
	if self.held ~= 0 then
		self:setC(self.c + self.held * C_SPEED * dt)
	end
	if self.dirty then
		self.dirty = false
		self:draw()
	end
end

function Lab:record()
	if not self.recordEnabled then
		return
	end
	local sc = self.sc
	if #self.records >= NEED then
		sc:toast(S3.recordFull, Theme.color.c)
		return
	end
	for _, r in self.records do
		if math.abs(r.c - self.c) < MIN_DC - 1e-9 then
			sc:toast(S3.recordTooClose:format(kg(r.c)), Theme.color.c)
			return
		end
	end
	local recs = table.clone(self.records)
	table.insert(recs, { c = self.c, mse = self.mse })
	self.records = recs
	sc.store:set("records2d", recs)
	sc.shell:flash(self.recordBtn)
	sc:toast(S3.recordAdded:format(kg(self.c), Format.num(self.mse, 2)), Theme.color.loss)
	sc:progress()
	if #recs == NEED - 1 then
		local below, above = 0, 0
		for _, r in recs do
			if r.c < self.cStar then below += 1 else above += 1 end
		end
		if below == 0 or above == 0 then
			sc:toast(S3.oneSide, Theme.color.c)
		end
	end
	if #recs == NEED then
		local t, v = {}, {}
		for i, r in recs do
			t[i], v[i] = r.c, r.mse
		end
		self.parabola = self.MathCore.fitParabola(t, v)
		self.recordBtn.Visible = false
		sc.shell:setText(S3.afterRecords:format(Format.num(self.parabola.tStar, 1)))
	end
	self:updateCounter()
	self:draw()
end

function Lab:updateCounter()
	self.counter.Text = if self.recordEnabled then S3.counter:format(#self.records) else ""
end

function Lab:enableRecording()
	self.recordEnabled = true
	self.recordBtn.Visible = true
	self.rightHolder.Visible = true
	self.rightTitle.Visible = true
	self:updateCounter()
	self:draw()
end

function Lab:draw()
	local plot = self.plot
	local hl = self.sc.store:get("highlight")
	local m, c = self.m, self.c

	-- квадраты остатков: сторона |e| в пикселях оси y, вдоль x — в сторону от среднего x
	local sq = plot:layer("squares", 2)
	sq:begin()
	for i = 1, self.n do
		local x, y = self.x[i], self.y[i]
		local yhat = m * x + c
		local px, py = plot:toPx(x, y)
		local _, ph = plot:toPx(x, yhat)
		local side = math.abs(ph - py)
		local dir = if x < self.o.xMean then -1 else 1
		sq:rectPx(px, py, px + dir * side, ph, { color = Theme.color.residual, transparency = if hl == "residual" then 0.35 else 0.6 })
	end
	sq:finish()

	local ln = plot:layer("line", 3)
	ln:begin()
	ln:seg(0, c, 70, m * 70 + c, { color = Theme.color.line, thickness = if hl == "m" then 5 else 3 })
	for i = 1, self.n do
		local x, y = self.x[i], self.y[i]
		ln:seg(x, y, x, m * x + c, { color = Theme.color.residual, thickness = 3 })
	end
	ln:finish()

	local pts = plot:layer("points", 5)
	pts:begin()
	for i = 1, self.n do
		pts:dot(self.x[i], self.y[i], { color = Theme.color.text, size = 12, strokeColor = Theme.color.bg })
	end
	-- точка пересечения с осью OY — свободный член
	pts:dot(0, c, { color = Theme.color.c, size = if hl == "c" then 22 else 18, strokeColor = Theme.color.text })
	pts:label(0, c, "c = " .. Format.num(c, 1), { dx = 14, dy = -6, anchor = Vector2.new(0, 1), size = 18, color = Theme.color.c, font = Theme.fontBold })
	if self.mean then
		pts:seg(0, self.o.yMean, 70, self.o.yMean, { color = Theme.color.mean, thickness = 2, transparency = 0.3 })
	end
	pts:finish()

	-- справа: записи (c, MSE), живая точка, парабола и минимум
	local mp = self.mplot
	local par = mp:layer("parabola", 3)
	par:begin()
	local P = self.parabola
	if P then
		par:curve(function(cc)
			return P.a * cc * cc + P.b * cc + P.k
		end, C_MIN, C_MAX, 90, { color = Theme.color.loss, thickness = 3 })
		par:dashedV(P.tStar, 0, P.vStar, { color = Theme.color.flag, thickness = 2 })
		par:dot(P.tStar, P.vStar, { color = Theme.color.flag, size = 14 })
		par:label(P.tStar, P.vStar, "c* = " .. Format.num(P.tStar, 1), { dx = 8, dy = 22, anchor = Vector2.new(0, 0), size = 18, color = Theme.color.flag, font = Theme.fontBold })
	end
	par:finish()
	local rec = mp:layer("records", 5)
	rec:begin()
	for _, r in self.records do
		rec:dot(r.c, r.mse, { color = Theme.color.loss, size = 14, strokeColor = Theme.color.bg })
	end
	rec:dot(c, math.min(self.mse, 49.5), { color = Theme.color.c, size = 18, hollow = true })
	rec:finish()
end

function Lab:Destroy()
	self.drag.Destroy()
end

-- ───── формулы ─────

local function lineFormula(sc, lab)
	local T = sc.T
	return {
		id = "LINE", title = S2.lineTitle,
		lines = {
			{ id = "eq", open = true,
				general = { T.hat("y"), " = ", T.sym("m", "m"), "·x + ", T.sym("c", "c") },
				numbers = function() return { T.hat("y"), " = ", T.col(Format.coef(lab.m), "m"), "·x + ", T.col(Format.num(lab.c, 1), "c") } end },
		},
	}
end

-- ───── сцены ─────

local scene2 = { id = "2D.2", panel = true, keepMain = true, autoAdvance = true }

function scene2.enter(sc)
	local lab = Lab.new(sc)
	sc.shared.lab = lab
	lab:bindKeys(sc)
	sc:formula(lineFormula(sc, lab))
	sc.shell:setText(S2.intro)
end

function scene2.update(sc, dt)
	sc.shared.lab:update(dt)
end

function scene2.canAdvance(sc)
	local lab = sc.shared.lab
	return lab ~= nil and lab.moved and lab.held == 0
end

function scene2.hintTargets(sc)
	return { sc.shared.lab.plot.area }
end

local scene3 = { id = "2D.3", panel = true }

function scene3.enter(sc)
	local lab = sc.shared.lab
	if not lab then
		lab = Lab.new(sc)
		sc.shared.lab = lab
	end
	lab:bindKeys(sc)
	lab:enableRecording()
	local T = sc.T
	local m, c = T.sym("m", "m"), T.sym("c", "c")
	sc:formula(lineFormula(sc, lab))
	sc:formula({
		id = "MSEC", title = S3.mseTitle, toNotebook = true,
		lines = {
			{ id = "def", open = true,
				general = { "MSE(", c, ") = ", T.frac({ T.sum(), "(", T.sub("y", "i"), " − ", m, "·", T.sub("x", "i"), " − ", c, ")²" }, { "n" }) },
				numbers = function()
					return { "MSE = ", T.frac({ T.sum(), "(", T.sub("y", "i"), " − ", T.col(Format.coef(lab.m), "m"), "·", T.sub("x", "i"), " − ",
						T.col(Format.num(lab.c, 1), "c"), ")²" }, { tostring(lab.n) }) }
				end,
				result = function() return Format.num(lab.mse, 2) end },
		},
	})
	sc:formula({
		id = "DLDC", title = S3.derivTitle, toNotebook = true,
		lines = {
			{ id = "deriv", hint = S3.lockDeriv,
				general = { T.d("L", "c", "c"), " = −2·", T.sum(), "(", T.sub("y", "i"), " − ", m, "·", T.sub("x", "i"), " − ", c, ")" },
				numbers = function()
					return { T.d("L", "c", "c"), " = −2·(", Format.num(lab.sumY, 0), " − ", T.col(Format.coef(lab.m), "m"), "·", Format.num(lab.sumX, 0),
						" − ", tostring(lab.n), "·", T.col(Format.num(lab.c, 1), "c"), ")" }
				end,
				result = function() return Format.signed(lab.dldc, 1) end },
			{ id = "zero", hint = S3.lockZero,
				general = { T.d("L", "c", "c"), " = 0  ⇒  ", c, " = ", T.bar("y", "mean", "mean"), " − ", m, "·", T.bar("x", "mean", "mean") },
				numbers = function()
					return { T.d("L", "c", "c"), " = 0  ⇒  ", c, " = ", Format.num(lab.o.yMean, 0), " − ", T.col(Format.coef(lab.m), "m"), "·", Format.num(lab.o.xMean, 0) }
				end,
				result = function() return Format.unit(lab.cStar, 1, "кг") end },
		},
	})
	sc.shell:setText(S3.intro)
end

function scene3.update(sc, dt)
	sc.shared.lab:update(dt)
end

scene3.unlocks = {
	{ formula = "DLDC", line = "deriv", when = function(sc) return #sc.shared.lab.records >= NEED end },
	{
		formula = "DLDC", line = "zero",
		when = function(sc)
			local lab = sc.shared.lab
			return lab.parabola ~= nil and lab.c == lab.cStar
		end,
		onUnlock = function(sc)
			sc.shell:setText(S3.atMinimum)
			sc.shell:ask(S3.bet, function(k)
				sc.s.bet = k
				local correct = k == 2
				sc.shell:resolve(correct, S3.bet.reveal)
				if correct then
					sc:honey(1)
				end
				sc:note(S3.note)
				sc:progress()
			end)
		end,
	},
}

function scene3.canAdvance(sc)
	return sc.f.DLDC ~= nil and sc.f.DLDC:isUnlocked("zero") and sc.s.bet ~= nil
end

function scene3.exit(sc)
	if sc.shared.lab then
		sc.shared.lab:Destroy()
		sc.shared.lab = nil
	end
end

function scene3.hintTargets(sc)
	local lab = sc.shared.lab
	return { if #lab.records < NEED then lab.recordBtn else lab.plot.area }
end

function scene3.hintText(sc, level)
	local lab = sc.shared.lab
	if level == 3 and #lab.records >= NEED then
		return Strings.hints["2D.3"].final:format(Format.num(lab.cStar, 1))
	end
	return nil
end

return { scene2, scene3 }
