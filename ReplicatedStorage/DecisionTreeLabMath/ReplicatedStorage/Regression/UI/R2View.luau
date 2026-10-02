--!nonstrict
-- R2View: «собери R² руками» — 2D.7 и проверка прогноза в лор-задаче.
--   Фаза res:  на графике квадраты остатков (yᵢ − ŷᵢ)²; тап по квадрату — он улетает в столбик SS_res (≤ 0,6 с);
--              после 2 ручных — кнопка «Собрать остальные».
--   Фаза mean: игрок тянет горизонтальную прямую (прилипание у ȳ) — появляются квадраты отклонений от среднего.
--   Фаза tot:  кнопка «Собрать в столбик» — квадраты улетают в SS_tot. Столбики в одном масштабе.
--   Фаза done: onDone(ssRes, ssTot).
-- opts: x, y, yhat, line = { m, c }?, xMin/xMax/xTicks, yMin/yMax/yTicks, xLabel, yLabel, unit, meanStart, snapTol,
--       markers (true — показывать прогноз точками-кольцами), onPhase(phase), onDone(ssRes, ssTot), store

local TweenService = game:GetService("TweenService")

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)
local Drag = require(Regression.UI.Drag)

local R2View = {}
R2View.__index = R2View

local MANUAL_BEFORE_AUTO = 2
local FLY_S = 0.5
local HIT_MIN = 32

function R2View.new(parent: GuiObject, opts)
	local self = setmetatable({}, R2View)
	self.opts = opts
	self.x, self.y, self.yhat = opts.x, opts.y, opts.yhat
	self.n = #opts.x
	local mean = 0
	for _, v in self.y do mean += v end
	self.mean = mean / self.n
	self.phase = "res"
	self.res, self.tot = {}, {}
	self.nRes, self.nTot, self.manual = 0, 0, 0
	self.meanY = opts.meanStart or (opts.yMin + (opts.yMax - opts.yMin) * 0.12)
	self.meanSet = false
	self.ssResFull, self.ssTotFull = 0, 0
	for i = 1, self.n do
		self.ssResFull += (self.y[i] - self.yhat[i]) ^ 2
		self.ssTotFull += (self.y[i] - self.mean) ^ 2
	end
	self.flying = 0
	self.conns = {}

	self.root = Gui.frame({ Name = "R2View", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	local top = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -62), Parent = self.root })
	local left = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(0.66, -6, 1, 0), Parent = top })
	local right = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromScale(0.66, 0), Size = UDim2.new(0.34, 0, 1, 0), Parent = top })
	self.plot = PlotView2D.new(left, {
		xMin = opts.xMin, xMax = opts.xMax, yMin = opts.yMin, yMax = opts.yMax, xTicks = opts.xTicks, yTicks = opts.yTicks,
		xLabel = opts.xLabel, yLabel = opts.yLabel, padL = 50, padR = 10, padT = 16, padB = 58, fontSize = 16, fallbackW = 420, fallbackH = 420,
		formatX = opts.formatX,
	})
	local colMax = math.max(self.ssTotFull, self.ssResFull) * 1.18
	local ticks = PlotView2D.ticks(0, colMax, 5)
	self.cols = PlotView2D.new(right, {
		xMin = 0, xMax = 3, yMin = 0, yMax = colMax, xTicks = {}, yTicks = ticks, yLabel = Strings.r2.colsLabel:format(opts.unit or ""),
		padL = 52, padR = 8, padT = 16, padB = 58, fontSize = 15, fallbackW = 200, fallbackH = 420,
	})
	self.plot.onResize = function() self:draw() end
	self.cols.onResize = function() self:draw() end

	-- кнопки-попадания по квадратам остатков
	self.hits = {}
	for i = 1, self.n do
		local b = Gui.make("TextButton", { Name = "Hit" .. i, Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 8, Parent = self.plot.area })
		b.Activated:Connect(function()
			if self.phase == "res" and not self.res[i] then
				self.manual += 1
				self:collect("res", i, 0)
			end
		end)
		self.hits[i] = b
	end

	local bar = Gui.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 56), Parent = self.root })
	Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = bar })
	self.restBtn = Gui.button({ Text = Strings.r2.collectRest, Size = UDim2.fromOffset(220, 50), Visible = false, LayoutOrder = 1, Parent = bar })
	self.restBtn.Activated:Connect(function()
		local k = 0
		for i = 1, self.n do
			if not self.res[i] then
				self:collect("res", i, k * 0.08)
				k += 1
			end
		end
		self.restBtn.Visible = false
	end)
	self.totBtn = Gui.button({ Text = Strings.r2.collectTot, Size = UDim2.fromOffset(220, 50), Visible = false, LayoutOrder = 2,
		BackgroundColor3 = Theme.color.mean, Parent = bar })
	self.totBtn.Activated:Connect(function()
		if self.phase ~= "tot" then
			return
		end
		for i = 1, self.n do
			self:collect("tot", i, (i - 1) * 0.08)
		end
		self.totBtn.Visible = false
	end)
	self.status = Gui.label({ Text = Strings.r2.tapSquares, TextSize = 17, TextColor3 = Theme.color.textDim, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = bar })

	-- прямая среднего: тянуть по вертикали
	self.drag = Drag.attach(self.plot.area, {
		began = function(p)
			if self.phase ~= "mean" then
				return false
			end
			self:_dragMean(p)
			return true
		end,
		moved = function(p)
			self:_dragMean(p)
		end,
		ended = function()
			self:_releaseMean()
		end,
	})
	self:draw()
	return self
end

function R2View:_dragMean(p: Vector2)
	local _, py = self.plot:screenToPx(p.X, p.Y)
	local _, y = self.plot:fromPx(0, py)
	self.meanY = math.clamp(y, self.opts.yMin, self.opts.yMax)
	if self.opts.onChanged then
		self.opts.onChanged()
	end
	self:draw()
end

-- Сдвиг прямой среднего кнопками/клавишами (для телефона и клавиатуры)
function R2View:nudgeMean(dy: number)
	if self.phase ~= "mean" then
		return
	end
	self.meanY = math.clamp(self.meanY + dy, self.opts.yMin, self.opts.yMax)
	self:draw()
end

function R2View:_releaseMean()
	if self.phase ~= "mean" then
		return
	end
	local tol = self.opts.snapTol or 1.5
	if math.abs(self.meanY - self.mean) < tol then
		self.meanY = self.mean
		self.meanSet = true
		self:setPhase("tot")
	end
	self:draw()
end

function R2View:setPhase(phase: string)
	self.phase = phase
	self.status.Text = Strings.r2.status[phase] or ""
	self.totBtn.Visible = phase == "tot"
	if self.opts.onPhase then
		self.opts.onPhase(phase)
	end
end

-- Полёт квадрата в столбик (≤ 0,6 с), потом — столбик растёт
function R2View:collect(kind: string, i: number, delay: number)
	local set = if kind == "res" then self.res else self.tot
	if set[i] then
		return
	end
	set[i] = "flying"
	self.flying += 1
	task.delay(delay, function()
		local r = self:_squareRect(kind, i)
		local tx, ty = self:_columnTop(kind)
		local fly = nil
		if r then
			local origin = self.root.AbsolutePosition
			fly = Gui.frame({ BackgroundColor3 = if kind == "res" then Theme.color.residual else Theme.color.mean, BackgroundTransparency = 0.3,
				Position = UDim2.fromOffset(r.x - origin.X, r.y - origin.Y), Size = UDim2.fromOffset(r.w, r.h), ZIndex = 20, Parent = self.root })
			local tw = TweenService:Create(fly, TweenInfo.new(FLY_S, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(tx - origin.X - 10, ty - origin.Y - 10), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0.6 })
			tw:Play()
		end
		task.delay(FLY_S, function()
			if fly then
				fly:Destroy()
			end
			set[i] = true
			self.flying -= 1
			if kind == "res" then
				self.nRes += 1
				if self.manual >= MANUAL_BEFORE_AUTO and self.nRes < self.n then
					self.restBtn.Visible = true
				end
				if self.nRes == self.n then
					self.restBtn.Visible = false
					self:setPhase("mean")
				end
			else
				self.nTot += 1
				if self.nTot == self.n then
					self:setPhase("done")
					if self.opts.onDone then
						self.opts.onDone(self:ssRes(), self:ssTot())
					end
				end
			end
			if self.opts.onChanged then
				self.opts.onChanged()
			end
			self:draw()
		end)
	end)
end

function R2View:ssRes(): number
	local s = 0
	for i = 1, self.n do
		if self.res[i] == true then s += (self.y[i] - self.yhat[i]) ^ 2 end
	end
	return s
end

function R2View:ssTot(): number
	local s = 0
	for i = 1, self.n do
		if self.tot[i] == true then s += (self.y[i] - self.mean) ^ 2 end
	end
	return s
end

-- Абсолютный прямоугольник квадрата на экране
function R2View:_squareRect(kind: string, i: number)
	local plot = self.plot
	local x, y = self.x[i], self.y[i]
	local base = if kind == "res" then self.yhat[i] else self.meanY
	local px, py = plot:toPx(x, y)
	local _, pb = plot:toPx(x, base)
	local side = math.abs(pb - py)
	local xm = 0
	for _, v in self.x do xm += v end
	xm /= self.n
	local dir = if x < xm then -1 else 1
	local x0, x1 = math.min(px, px + dir * side), math.max(px, px + dir * side)
	local y0, y1 = math.min(py, pb), math.max(py, pb)
	local a = plot.area.AbsolutePosition
	return { x = a.X + x0, y = a.Y + y0, w = x1 - x0, h = y1 - y0, lx0 = x0, ly0 = y0, lx1 = x1, ly1 = y1 }
end

function R2View:_columnTop(kind: string): (number, number)
	local cx = if kind == "res" then 1 else 2
	local h = if kind == "res" then self:ssRes() else self:ssTot()
	local px, py = self.cols:toPx(cx, h)
	local a = self.cols.area.AbsolutePosition
	return a.X + px, a.Y + py
end

function R2View:draw()
	local plot = self.plot
	local o = self.opts
	local hl = o.store and o.store:get("highlight")

	local sq = plot:layer("squares", 2)
	sq:begin()
	for i = 1, self.n do
		local hit = self.hits[i]
		if not self.res[i] then
			local r = self:_squareRect("res", i)
			sq:rectPx(r.lx0, r.ly0, r.lx1, r.ly1, { color = Theme.color.residual, transparency = if hl == "residual" then 0.3 else 0.5, strokeColor = Theme.color.residual })
			local w, h = math.max(r.lx1 - r.lx0, HIT_MIN), math.max(r.ly1 - r.ly0, HIT_MIN)
			hit.Visible = self.phase == "res"
			hit.Position = UDim2.fromOffset((r.lx0 + r.lx1) / 2 - w / 2, (r.ly0 + r.ly1) / 2 - h / 2)
			hit.Size = UDim2.fromOffset(w, h)
		else
			hit.Visible = false
		end
		if self.meanSet and not self.tot[i] then
			local r = self:_squareRect("tot", i)
			sq:rectPx(r.lx0, r.ly0, r.lx1, r.ly1, { color = Theme.color.mean, transparency = if hl == "mean" then 0.3 else 0.55, strokeColor = Theme.color.mean })
		end
	end
	sq:finish()

	local ln = plot:layer("model", 3)
	ln:begin()
	if o.line then
		ln:seg(o.xMin, o.line.m * o.xMin + o.line.c, o.xMax, o.line.m * o.xMax + o.line.c, { color = Theme.color.line, thickness = 3 })
	end
	for i = 1, self.n do
		ln:seg(self.x[i], self.y[i], self.x[i], self.yhat[i], { color = Theme.color.residual, thickness = 2 })
	end
	if self.phase ~= "res" then
		ln:seg(o.xMin, self.meanY, o.xMax, self.meanY, { color = Theme.color.mean, thickness = if self.meanSet then 3 else 4 })
		ln:label(o.xMax, self.meanY, if self.meanSet then "ȳ = " .. Format.num(self.mean, 1) else Strings.r2.dragMean,
			{ dx = -6, dy = -4, anchor = Vector2.new(1, 1), size = 16, color = Theme.color.text, font = Theme.fontBold })
		if self.meanSet then
			for i = 1, self.n do
				ln:seg(self.x[i] + (o.xMax - o.xMin) * 0.006, self.y[i], self.x[i] + (o.xMax - o.xMin) * 0.006, self.mean, { color = Theme.color.mean, thickness = 2 })
			end
		end
	end
	ln:finish()

	local pts = plot:layer("points", 5)
	pts:begin()
	for i = 1, self.n do
		if o.markers then
			pts:dot(self.x[i], self.yhat[i], { color = Theme.color.m, size = 14, hollow = true })
		end
		pts:dot(self.x[i], self.y[i], { color = Theme.color.text, size = 12, strokeColor = Theme.color.bg })
	end
	pts:finish()

	-- столбики: стопки квадратов, общий масштаб
	local cols = self.cols
	local L = cols:layer("columns", 3)
	L:begin()
	for k, kind in { "res", "tot" } do
		local acc = 0
		local set = if kind == "res" then self.res else self.tot
		for i = 1, self.n do
			if set[i] == true then
				local v = if kind == "res" then (self.y[i] - self.yhat[i]) ^ 2 else (self.y[i] - self.mean) ^ 2
				L:rect(k - 0.35, acc, k + 0.35, acc + v, { color = if kind == "res" then Theme.color.residual else Theme.color.mean, transparency = 0.15,
					strokeColor = Theme.color.bg, strokeTransparency = 0 })
				acc += v
			end
		end
		local name = if kind == "res" then "SS_res" else "SS_tot"
		local px, _ = cols:toPx(k, 0)
		local _, ph = cols:size()
		L:labelPx(px, ph + 6, name, { anchor = Vector2.new(0.5, 0), size = 16, color = if kind == "res" then Theme.color.residual else Theme.color.mean, font = Theme.fontBold })
		if acc > 0 then
			L:label(k, acc, Format.num(acc, 1), { anchor = Vector2.new(0.5, 1), dy = -2, size = 16, color = Theme.color.text, font = Theme.fontBold })
		end
	end
	L:finish()
end

function R2View:Destroy()
	self.drag.Destroy()
	self.root:Destroy()
end

return R2View
