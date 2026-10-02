--!strict
-- Records: записи (m, MSE) на табло. Без Roblox API.
-- Правила из раскадровки 3D.4: 5 записей на одной высоте, наклоны различаются не меньше чем на 0,1.

export type Record = { m: number, mse: number, h: number }

local Records = {}

Records.NEED = 5
Records.MIN_DM = 0.1
Records.H_TOL = 1e-3 -- высота дискретна (шаг 0,05 м), так что допуск только на погрешность float
Records.MAX_TOTAL = 20

function Records.sameHeight(a: number, b: number): boolean
	return math.abs(a - b) < Records.H_TOL
end

function Records.atHeight(list: { Record }, h: number): { Record }
	local out = {}
	for _, r in list do
		if Records.sameHeight(r.h, h) then
			table.insert(out, r)
		end
	end
	return out
end

-- ok, reason ("full" | "too_close"), конфликтующая запись
function Records.validate(list: { Record }, m: number, h: number): (boolean, string?, Record?)
	local cur = Records.atHeight(list, h)
	if #cur >= Records.NEED then
		return false, "full", nil
	end
	for _, r in cur do
		if math.abs(r.m - m) < Records.MIN_DM - 1e-9 then
			return false, "too_close", r
		end
	end
	return true, nil, nil
end

-- Добавляет запись в новый список (старый не меняется — удобно для Store).
-- Если записей слишком много, выбрасывает самые старые записи других высот.
function Records.add(list: { Record }, rec: Record): { Record }
	local out = table.clone(list)
	table.insert(out, rec)
	local i = 1
	while #out > Records.MAX_TOTAL and i <= #out do
		if not Records.sameHeight(out[i].h, rec.h) then
			table.remove(out, i)
		else
			i += 1
		end
	end
	return out
end

-- Все записи по одну сторону от mOpt (подсказка «попробуй наклон в другую сторону»)
function Records.oneSide(list: { Record }, mOpt: number): boolean
	if #list == 0 then
		return false
	end
	local below, above = 0, 0
	for _, r in list do
		if r.m < mOpt then below += 1 else above += 1 end
	end
	return below == 0 or above == 0
end

-- Парабола по записям: MathCore передаётся снаружи, чтобы модуль оставался чистым
function Records.fit(MathCore: any, list: { Record })
	local t, v = {}, {}
	for i, r in list do
		t[i], v[i] = r.m, r.mse
	end
	return MathCore.fitParabola(t, v)
end

return Records
