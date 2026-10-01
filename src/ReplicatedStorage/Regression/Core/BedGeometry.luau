--!strict
-- BedGeometry: геометрия клумбы в координатах данных (метры). Без Roblox API.
-- Клумба — прямоугольник [0; W] × [0; H], ось x вдоль, ось y поперёк.

local BedGeometry = {}

-- Отрезок прямой y = m·x + c внутри прямоугольника. Возвращает x0, y0, x1, y1 или nil.
function BedGeometry.clipLine(m: number, c: number, W: number, H: number): (number?, number?, number?, number?)
	local x0, x1 = 0, W
	if math.abs(m) < 1e-12 then
		if c < 0 or c > H then
			return nil, nil, nil, nil
		end
	else
		local xa, xb = (0 - c) / m, (H - c) / m
		if xa > xb then
			xa, xb = xb, xa
		end
		x0 = math.max(x0, xa)
		x1 = math.min(x1, xb)
		if x0 >= x1 then
			return nil, nil, nil, nil
		end
	end
	return x0, m * x0 + c, x1, m * x1 + c
end

-- Нить от цветка (x, y) к прямой параллельно оси y. grow ∈ [0; 1] — доля «протянутости».
function BedGeometry.thread(x: number, y: number, yhat: number, grow: number): (number, number, number, number)
	return x, y, x, y + (yhat - y) * grow
end

-- Квадрат ошибки: одна сторона — нить, другая — вдоль x в сторону от центра клумбы.
-- Возвращает центр (cx, cy) и сторону (м).
function BedGeometry.square(x: number, y: number, yhat: number, pivotX: number, grow: number): (number, number, number)
	local side = math.abs(y - yhat) * grow
	local dir = if x < pivotX then -1 else 1
	local yEnd = y + (yhat - y) * grow
	return x + dir * side / 2, (y + yEnd) / 2, side
end

-- Расстояние от точки (px, pz) до прямоугольника с полуразмерами (hx, hz) с центром в нуле
function BedGeometry.distToRect(px: number, pz: number, hx: number, hz: number): number
	local dx = math.max(math.abs(px) - hx, 0)
	local dz = math.max(math.abs(pz) - hz, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Отрезок в прямоугольнике [xMin; xMax] × [yMin; yMax] (Лян — Барски). Для графиков на табло.
function BedGeometry.clipSegment(
	x0: number, y0: number, x1: number, y1: number,
	xMin: number, xMax: number, yMin: number, yMax: number
): (number?, number?, number?, number?)
	local dx, dy = x1 - x0, y1 - y0
	local t0, t1 = 0, 1
	local p = { -dx, dx, -dy, dy }
	local q = { x0 - xMin, xMax - x0, y0 - yMin, yMax - y0 }
	for i = 1, 4 do
		if p[i] == 0 then
			if q[i] < 0 then
				return nil, nil, nil, nil
			end
		else
			local t = q[i] / p[i]
			if p[i] < 0 then
				if t > t1 then return nil, nil, nil, nil end
				if t > t0 then t0 = t end
			else
				if t < t0 then return nil, nil, nil, nil end
				if t < t1 then t1 = t end
			end
		end
	end
	return x0 + t0 * dx, y0 + t0 * dy, x0 + t1 * dx, y0 + t1 * dy
end

return BedGeometry
