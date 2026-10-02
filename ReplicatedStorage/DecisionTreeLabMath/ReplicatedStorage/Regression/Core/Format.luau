--!strict
-- Format: числа для UI. Десятичная запятая, неразрывный пробел перед единицей,
-- типографский минус, явный знак у ошибок. Без Roblox API (тестируется standalone).

local Format = {}

Format.NBSP = "\u{00A0}"
Format.MINUS = "\u{2212}"

function Format.num(x: number, digits: number?): string
	local d = digits or 2
	local s = string.format("%." .. d .. "f", x)
	if tonumber(s) == 0 then
		s = string.format("%." .. d .. "f", 0) -- без «−0,00»
	end
	s = (s:gsub("%.", ","))
	s = (s:gsub("^%-", Format.MINUS))
	return s
end

-- Со знаком: +0,26 / −0,37 / 0,00
function Format.signed(x: number, digits: number?): string
	local s = Format.num(x, digits)
	local d = digits or 2
	local r = tonumber(string.format("%." .. d .. "f", x)) or 0
	if r > 0 then
		return "+" .. s
	end
	return s
end

function Format.unit(x: number, digits: number?, unit: string): string
	return Format.num(x, digits) .. Format.NBSP .. unit
end

-- Коэффициенты (наклон m): 2 знака на табло, сравнение точности — в логике
function Format.coef(x: number): string
	return Format.num(x, 2)
end

function Format.len(x: number): string
	return Format.unit(x, 2, "м")
end

function Format.area(x: number): string
	return Format.unit(x, 2, "м²")
end

function Format.mse(x: number): string
	return Format.unit(x, 3, "м²")
end

function Format.lambda(x: number): string
	if x == 0 then
		return "0"
	end
	return Format.num(x, 1)
end

function Format.percent(share: number): string
	return Format.unit(share * 100, 1, "%")
end

return Format
