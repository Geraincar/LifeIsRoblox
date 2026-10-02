--!nonstrict
-- PlotView2D: 2D-график из Frame'ов. Работает и в ScreenGui, и в SurfaceGui (табло).
-- Слои с пулами объектов: каждый кадр layer:begin() → dot/seg/curve/label → layer:finish().
-- Instance.new только при первом заполнении пула. Отрезки обрезаются аналитически
-- (ClipsDescendants не обрезает повёрнутые Frame).
--
--   local plot = PlotView2D.new(frame, { xMin=-1, xMax=1.5, yMin=0, yMax=2,
--       xTicks={...}, yTicks={...}, xLabel="m", yLabel="MSE", fallbackW=500, fallbackH=380 })
--   local L = plot:layer("records", 5); L:begin(); L:dot(0.2, 0.38, {color=...}); L:finish()

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local BedGeometry = require(Regression.Core.BedGeometry)

local PlotView2D = {}
PlotView2D.__index = PlotView2D

local Layer = {}
Layer.__index = Layer

local function defaultFormat(v: number): string
	local s = string.format("%g", v)
	s = (s:gsub("%.", ","))
	return (s:gsub("^%-", "\u{2212}"))
end

-- Шаг делений 1, 2, 5 × 10ⁿ, чтобы делений было около target
function PlotView2D.niceStep(span: number, target: number?): number
	local raw = span / (target or 5)
	local p = 10 ^ math.floor(math.log10(raw))
	for _, k in { 1, 2, 5, 10 } do
		if raw <= k * p + 1e-12 then
			return k * p
		end
	end
	return 10 * p
end

-- Деления от a до b с «красивым» шагом
function PlotView2D.ticks(a: number, b: number, target: number?): { number }
	local step = PlotView2D.niceStep(b - a, target)
	local out = {}
	local v = math.ceil(a / step - 1e-9) * step
	while v <= b + 1e-9 do
		table.insert(out, tonumber(string.format("%.6f", v)))
		v += step
	end
	return out
end

function PlotView2D.new(parent: GuiObject, opts)
	local self = setmetatable({}, PlotView2D)
	opts.padL = opts.padL or 64
	opts.padR = opts.padR or 16
	opts.padT = opts.padT or 40
	opts.padB = opts.padB or 64
	opts.fontSize = opts.fontSize or 22
	opts.formatX = opts.formatX or defaultFormat
	opts.formatY = opts.formatY or defaultFormat
	self.opts = opts
	self.root = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	self.area = Gui.frame({
		BackgroundColor3 = opts.bg or Theme.color.panel,
		Position = UDim2.fromOffset(opts.padL, opts.padT),
		Size = UDim2.new(1, -(opts.padL + opts.padR), 1, -(opts.padT + opts.padB)),
		Parent = self.root,
	})
	self.layers = {}
	self.onResize = nil :: (() -> ())?
	self.area:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:drawGrid()
		if self.onResize then
			self.onResize()
		end
	end)
	self:drawGrid()
	return self
end

function PlotView2D:size(): (number, number)
	local s = self.area.AbsoluteSize
	if s.X < 2 or s.Y < 2 then
		return self.opts.fallbackW or 400, self.opts.fallbackH or 300
	end
	return s.X, s.Y
end

function PlotView2D:toPx(x: number, y: number): (number, number)
	local o = self.opts
	local w, h = self:size()
	return (x - o.xMin) / (o.xMax - o.xMin) * w, (1 - (y - o.yMin) / (o.yMax - o.yMin)) * h
end

-- Пиксели области графика → координаты данных
function PlotView2D:fromPx(px: number, py: number): (number, number)
	local o = self.opts
	local w, h = self:size()
	return o.xMin + px / w * (o.xMax - o.xMin), o.yMin + (1 - py / h) * (o.yMax - o.yMin)
end

-- Экранная точка (InputObject.Position / AbsolutePosition) → пиксели области
function PlotView2D:screenToPx(sx: number, sy: number): (number, number)
	local a = self.area.AbsolutePosition
	return sx - a.X, sy - a.Y
end

-- Пикселей на единицу данных по осям
function PlotView2D:scale(): (number, number)
	local o = self.opts
	local w, h = self:size()
	return w / (o.xMax - o.xMin), h / (o.yMax - o.yMin)
end

-- Новый диапазон осей (деления — опционально); сетка перерисовывается сразу
function PlotView2D:setRange(xMin: number, xMax: number, yMin: number, yMax: number, xTicks: { number }?, yTicks: { number }?)
	local o = self.opts
	o.xMin, o.xMax, o.yMin, o.yMax = xMin, xMax, yMin, yMax
	if xTicks then o.xTicks = xTicks end
	if yTicks then o.yTicks = yTicks end
	self:drawGrid()
end

-- Равный масштаб осей (круг остаётся кругом): ось y подстраивается под пропорции области вокруг центра
function PlotView2D:_applyEqualAspect()
	local o = self.opts
	if not o.equalAspect then
		return
	end
	local w, h = self:size()
	local cy = o.equalCenterY or (o.yMin + o.yMax) / 2
	o.equalCenterY = cy
	local half = (o.xMax - o.xMin) * h / w / 2
	o.yMin, o.yMax = cy - half, cy + half
end

function PlotView2D:inRange(x: number, y: number): boolean
	local o = self.opts
	return x >= o.xMin and x <= o.xMax and y >= o.yMin and y <= o.yMax
end

function PlotView2D:layer(name: string, z: number?)
	local L = self.layers[name]
	if L then
		return L
	end
	L = setmetatable({
		plot = self,
		holder = Gui.frame({
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z or 2,
			Parent = self.area,
		}),
		dots = {}, segs = {}, labels = {}, rects = {},
		nd = 0, ns = 0, nl = 0, nr = 0,
	}, Layer)
	self.layers[name] = L
	return L
end

function PlotView2D:drawGrid()
	self:_applyEqualAspect()
	local o = self.opts
	local L = self:layer("grid", 1)
	local w, h = self:size()
	L:begin()
	for _, xt in o.xTicks do
		if xt < o.xMin or xt > o.xMax then
			continue
		end
		L:seg(xt, o.yMin, xt, o.yMax, { color = if xt == 0 then Theme.color.axis else Theme.color.grid, thickness = if xt == 0 then 2 else 1 })
		local px = self:toPx(xt, o.yMin)
		L:labelPx(px, h + 6, o.formatX(xt), { anchor = Vector2.new(0.5, 0), size = o.fontSize, color = Theme.color.textDim })
	end
	for _, yt in o.yTicks do
		if yt < o.yMin or yt > o.yMax then
			continue
		end
		L:seg(o.xMin, yt, o.xMax, yt, { color = if yt == 0 then Theme.color.axis else Theme.color.grid, thickness = if yt == 0 then 2 else 1 })
		local _, py = self:toPx(o.xMin, yt)
		L:labelPx(-8, py, o.formatY(yt), { anchor = Vector2.new(1, 0.5), size = o.fontSize, color = Theme.color.textDim })
	end
	if o.xLabel then
		L:labelPx(w / 2, h + o.fontSize + 14, o.xLabel, { anchor = Vector2.new(0.5, 0), size = o.fontSize, color = Theme.color.text })
	end
	if o.yLabel then
		L:labelPx(0, -8, o.yLabel, { anchor = Vector2.new(0, 1), size = o.fontSize, color = Theme.color.text })
	end
	L:finish()
end

-- ───── Layer ─────

function Layer:begin()
	self.nd, self.ns, self.nl, self.nr = 0, 0, 0, 0
end

function Layer:finish()
	for i = self.nd + 1, #self.dots do self.dots[i].Visible = false end
	for i = self.ns + 1, #self.segs do self.segs[i].Visible = false end
	for i = self.nl + 1, #self.labels do self.labels[i].Visible = false end
	for i = self.nr + 1, #self.rects do self.rects[i].Visible = false end
end

function Layer:setVisible(on: boolean)
	self.holder.Visible = on
end

-- Прямоугольник в пикселях области (оси экрана), обрезанный по области графика.
-- style: color, transparency, strokeColor, strokeTransparency
function Layer:rectPx(x0: number, y0: number, x1: number, y1: number, style)
	style = style or {}
	local w, h = self.plot:size()
	local ax, bx = math.max(math.min(x0, x1), 0), math.min(math.max(x0, x1), w)
	local ay, by = math.max(math.min(y0, y1), 0), math.min(math.max(y0, y1), h)
	if bx - ax < 0.5 or by - ay < 0.5 then
		return nil
	end
	self.nr += 1
	local f = self.rects[self.nr]
	if not f then
		f = Gui.frame({ ZIndex = 1, Parent = self.holder })
		Gui.stroke(Theme.color.text, 1).Parent = f
		self.rects[self.nr] = f
	end
	f.Visible = true
	f.Position = UDim2.fromOffset(ax, ay)
	f.Size = UDim2.fromOffset(bx - ax, by - ay)
	f.BackgroundColor3 = style.color or Theme.color.residual
	f.BackgroundTransparency = style.transparency or 0.6
	local st = f:FindFirstChildOfClass("UIStroke")
	st.Enabled = style.strokeColor ~= nil
	st.Color = style.strokeColor or Theme.color.text
	st.Transparency = style.strokeTransparency or 0
	return f
end

-- Прямоугольник в координатах данных
function Layer:rect(x0: number, y0: number, x1: number, y1: number, style)
	local ax, ay = self.plot:toPx(x0, y0)
	local bx, by = self.plot:toPx(x1, y1)
	return self:rectPx(ax, ay, bx, by, style)
end

-- Ломаная по точкам данных { {x, y}, ... }; closed — замкнуть
function Layer:polyline(points: { { number } }, style, closed: boolean?)
	local n = #points
	for i = 1, n - 1 do
		self:seg(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], style)
	end
	if closed and n > 2 then
		self:seg(points[n][1], points[n][2], points[1][1], points[1][2], style)
	end
end

-- style: color, size (px), hollow, transparency, strokeColor
function Layer:dot(x: number, y: number, style)
	style = style or {}
	if not self.plot:inRange(x, y) then
		return
	end
	local px, py = self.plot:toPx(x, y)
	self.nd += 1
	local f = self.dots[self.nd]
	if not f then
		f = Gui.frame({ AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = self.holder })
		Gui.corner(UDim.new(0.5, 0)).Parent = f
		Gui.stroke(Theme.color.text, 3).Parent = f
		self.dots[self.nd] = f
	end
	local size = style.size or 12
	local tr = style.transparency or 0
	local color = style.color or Theme.color.text
	f.Visible = true
	f.Size = UDim2.fromOffset(size, size)
	f.Position = UDim2.fromOffset(px, py)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = if style.hollow then 1 else tr
	local st = f:FindFirstChildOfClass("UIStroke")
	st.Enabled = style.hollow == true or style.strokeColor ~= nil
	st.Color = style.strokeColor or color
	st.Transparency = tr
	return f
end

-- Отрезок в пикселях области графика
function Layer:segPx(ax: number, ay: number, bx: number, by: number, style)
	style = style or {}
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 0.5 then
		return
	end
	self.ns += 1
	local f = self.segs[self.ns]
	if not f then
		f = Gui.frame({ AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = self.holder })
		self.segs[self.ns] = f
	end
	f.Visible = true
	f.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
	f.Size = UDim2.fromOffset(len + 1, style.thickness or 3)
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.BackgroundColor3 = style.color or Theme.color.text
	f.BackgroundTransparency = style.transparency or 0
end

-- Отрезок в координатах данных, обрезанный по области графика
function Layer:seg(x0: number, y0: number, x1: number, y1: number, style)
	local o = self.plot.opts
	local a, b, c, d = BedGeometry.clipSegment(x0, y0, x1, y1, o.xMin, o.xMax, o.yMin, o.yMax)
	if not a then
		return
	end
	local ax, ay = self.plot:toPx(a, b)
	local bx, by = self.plot:toPx(c, d)
	self:segPx(ax, ay, bx, by, style)
end

-- Кривая y = fn(x) ломаной из steps отрезков
function Layer:curve(fn: (number) -> number, xFrom: number, xTo: number, steps: number, style)
	local px, py = xFrom, fn(xFrom)
	for i = 1, steps do
		local x = xFrom + (xTo - xFrom) * i / steps
		local y = fn(x)
		self:seg(px, py, x, y, style)
		px, py = x, y
	end
end

-- Пунктирная вертикаль x = const от y0 до y1
function Layer:dashedV(x: number, y0: number, y1: number, style)
	local o = self.plot.opts
	if x < o.xMin or x > o.xMax then
		return
	end
	local _, pa = self.plot:toPx(x, math.clamp(y0, o.yMin, o.yMax))
	local px, pb = self.plot:toPx(x, math.clamp(y1, o.yMin, o.yMax))
	local top, bottom = math.min(pa, pb), math.max(pa, pb)
	local dash, gap = 8, 6
	local y = top
	while y < bottom do
		self:segPx(px, y, px, math.min(y + dash, bottom), style)
		y += dash + gap
	end
end

-- Подпись в пикселях; style: anchor, size, color, font, transparency
function Layer:labelPx(px: number, py: number, text: string, style)
	style = style or {}
	self.nl += 1
	local l = self.labels[self.nl]
	if not l then
		l = Gui.label({
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			TextWrapped = false,
			ZIndex = 4,
			Parent = self.holder,
		})
		self.labels[self.nl] = l
	end
	l.Visible = true
	l.AnchorPoint = style.anchor or Vector2.new(0, 1)
	l.Position = UDim2.fromOffset(px, py)
	l.TextSize = style.size or self.plot.opts.fontSize
	l.TextColor3 = style.color or Theme.color.text
	l.Font = style.font or Theme.font
	l.TextTransparency = style.transparency or 0
	l.Text = text
end

function Layer:label(x: number, y: number, text: string, style)
	style = style or {}
	local px, py = self.plot:toPx(x, y)
	self:labelPx(px + (style.dx or 0), py + (style.dy or 0), text, style)
end

return PlotView2D
