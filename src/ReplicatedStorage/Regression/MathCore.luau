--!nonstrict
-- MathCore: чистая математика регрессионного модуля «Улей». Без Roblox API —
-- запускается и в Studio, и в standalone luau (для автотестов).
-- Соглашения совпадают с scripts/reference_math.py:
--   L = Σe² (сумма, не среднее); Ridge: + λΣb²; Lasso: + λΣ|b|; b₀ не штрафуется;
--   стандартизация sd с делением на n, mean/sd только по train.

export type Vector = { number }
export type Matrix = { Vector } -- Matrix[i] — строка i (наблюдение)

local MathCore = {}

function MathCore.mean(v: Vector): number
	local s = 0
	for _, x in v do s += x end
	return s / #v
end

function MathCore.column(X: Matrix, j: number): Vector
	local c = table.create(#X)
	for i, row in X do c[i] = row[j] end
	return c
end

-- Одномерная МНК: возвращает b0, b1 и промежуточные суммы для формул UI
function MathCore.ols1d(x: Vector, y: Vector)
	local n = #x
	local xm, ym = MathCore.mean(x), MathCore.mean(y)
	local sxx, sxy, syy = 0, 0, 0
	for i = 1, n do
		local dx, dy = x[i] - xm, y[i] - ym
		sxx += dx * dx; sxy += dx * dy; syy += dy * dy
	end
	local b1 = sxy / sxx
	return {
		b0 = ym - b1 * xm, b1 = b1, n = n, xMean = xm, yMean = ym,
		sxx = sxx, sxy = sxy, syy = syy,
	}
end

-- Сумма квадратов остатков для прямой
function MathCore.sse1d(x: Vector, y: Vector, b0: number, b1: number): number
	local s = 0
	for i = 1, #x do
		local e = y[i] - (b0 + b1 * x[i])
		s += e * e
	end
	return s
end

-- MSE прямой y = m·x + c (табло в 3D показывает MSE = L/n)
function MathCore.mseLine(x: Vector, y: Vector, m: number, c: number): number
	return MathCore.sse1d(x, y, c, m) / #x
end

-- Прямая вращается вокруг точки (pivotX, h): свободный член
function MathCore.lineFromPivot(m: number, h: number, pivotX: number): number
	return h - m * pivotX
end

-- МНК-парабола v ≈ a·t² + b·t + k по записанным точкам (≥ 3 разных t).
-- Возвращает a, b, k и вершину (tStar, vStar). Для MSE при фиксированной высоте подгонка точная.
function MathCore.fitParabola(t: Vector, v: Vector)
	local S = table.create(5, 0) -- Σt^0..Σt^4
	local T = table.create(3, 0) -- Σv·t^0..Σv·t^2
	for i = 1, #t do
		local p = 1
		for k = 1, 5 do
			S[k] += p
			if k <= 3 then T[k] += v[i] * p end
			p *= t[i]
		end
	end
	-- нормальные уравнения для (k, b, a)
	local A = {
		{ S[1], S[2], S[3] },
		{ S[2], S[3], S[4] },
		{ S[3], S[4], S[5] },
	}
	local sol = MathCore._solve(A, { T[1], T[2], T[3] })
	local k, b, a = sol[1], sol[2], sol[3]
	local ts = -b / (2 * a)
	return { a = a, b = b, k = k, tStar = ts, vStar = a * ts * ts + b * ts + k }
end

-- Сумма квадратов остатков при оптимальном c (= ȳ − m·x̄) плюс штраф; kind = "l2" | "l1"
function MathCore.penalizedLoss1d(x: Vector, y: Vector, m: number, lambda: number, kind: string): number
	local c = MathCore.mean(y) - m * MathCore.mean(x)
	return MathCore.sse1d(x, y, c, m) + lambda * (if kind == "l2" then m * m else math.abs(m))
end

function MathCore.standardize(X: Matrix, means: Vector?, sds: Vector?): (Matrix, Vector, Vector)
	local p = #X[1]
	local m: Vector, s: Vector
	if means and sds then
		m, s = means, sds
	else
		m, s = table.create(p), table.create(p)
		for j = 1, p do
			local col = MathCore.column(X, j)
			local mu = MathCore.mean(col)
			local v = 0
			for _, x in col do v += (x - mu) ^ 2 end
			m[j], s[j] = mu, math.sqrt(v / #col)
		end
	end
	local Z: Matrix = table.create(#X)
	for i, row in X do
		local r = table.create(p)
		for j = 1, p do r[j] = (row[j] - m[j]) / s[j] end
		Z[i] = r
	end
	return Z, m, s
end

local function centered(X: Matrix, y: Vector): (Matrix, Vector, Vector, number)
	local n, p = #X, #X[1]
	local xm = table.create(p, 0)
	for _, row in X do for j = 1, p do xm[j] += row[j] / n end end
	local ym = MathCore.mean(y)
	local Xc: Matrix, yc: Vector = table.create(n), table.create(n)
	for i, row in X do
		local r = table.create(p)
		for j = 1, p do r[j] = row[j] - xm[j] end
		Xc[i], yc[i] = r, y[i] - ym
	end
	return Xc, yc, xm, ym
end

-- Решение A·b = c методом Гаусса с выбором ведущего элемента
local function solve(A: Matrix, c: Vector): Vector
	local p = #c
	local M: Matrix = table.create(p)
	for i = 1, p do
		local r = table.clone(A[i]); r[p + 1] = c[i]; M[i] = r
	end
	for k = 1, p do
		local piv = k
		for i = k + 1, p do if math.abs(M[i][k]) > math.abs(M[piv][k]) then piv = i end end
		M[k], M[piv] = M[piv], M[k]
		for i = k + 1, p do
			local f = M[i][k] / M[k][k]
			for j = k, p + 1 do M[i][j] -= f * M[k][j] end
		end
	end
	local b = table.create(p, 0)
	for i = p, 1, -1 do
		local s = M[i][p + 1]
		for j = i + 1, p do s -= M[i][j] * b[j] end
		b[i] = s / M[i][i]
	end
	return b
end

MathCore._solve = solve

local function intercept(xm: Vector, ym: number, b: Vector): number
	local s = ym
	for j = 1, #b do s -= xm[j] * b[j] end
	return s
end

-- Ridge (λ = 0 → обычная МНК). Xs — уже стандартизованные признаки.
function MathCore.ridge(Xs: Matrix, y: Vector, lambda: number): (number, Vector)
	local Xc, yc, xm, ym = centered(Xs, y)
	local p = #Xc[1]
	local A: Matrix, c: Vector = table.create(p), table.create(p, 0)
	for a = 1, p do
		A[a] = table.create(p, 0)
		for b = 1, p do
			local s = 0
			for i = 1, #Xc do s += Xc[i][a] * Xc[i][b] end
			A[a][b] = s + (if a == b then lambda else 0)
		end
		for i = 1, #Xc do c[a] += Xc[i][a] * yc[i] end
	end
	local b = solve(A, c)
	return intercept(xm, ym, b), b
end

function MathCore.ols(Xs: Matrix, y: Vector): (number, Vector)
	return MathCore.ridge(Xs, y, 0)
end

-- Lasso координатным спуском: b_j = S(ρ_j, λ/2) / Σx_j²
function MathCore.lasso(Xs: Matrix, y: Vector, lambda: number, maxIter: number?, tol: number?): (number, Vector)
	local Xc, yc, xm, ym = centered(Xs, y)
	local n, p = #Xc, #Xc[1]
	local b = table.create(p, 0)
	local z = table.create(p, 0)
	for j = 1, p do for i = 1, n do z[j] += Xc[i][j] ^ 2 end end
	local r = table.clone(yc) -- остатки при b = 0
	for _ = 1, maxIter or 5000 do
		local maxDelta = 0
		for j = 1, p do
			local rho = 0
			for i = 1, n do rho += Xc[i][j] * (r[i] + Xc[i][j] * b[j]) end
			local mag = math.max(math.abs(rho) - lambda / 2, 0)
			local nb = (if rho >= 0 then mag else -mag) / z[j]
			local d = nb - b[j]
			if d ~= 0 then
				for i = 1, n do r[i] -= Xc[i][j] * d end
				b[j] = nb
				maxDelta = math.max(maxDelta, math.abs(d))
			end
		end
		if maxDelta < (tol or 1e-12) then break end
	end
	return intercept(xm, ym, b), b
end

function MathCore.predict(b0: number, b: Vector, Xs: Matrix): Vector
	local out = table.create(#Xs)
	for i, row in Xs do
		local s = b0
		for j = 1, #b do s += row[j] * b[j] end
		out[i] = s
	end
	return out
end

-- R² = 1 − SS_res/SS_tot; возвращает и обе суммы для визуализации
function MathCore.r2(y: Vector, yhat: Vector): (number, number, number)
	local ym = MathCore.mean(y)
	local res, tot = 0, 0
	for i = 1, #y do
		res += (y[i] - yhat[i]) ^ 2
		tot += (y[i] - ym) ^ 2
	end
	return 1 - res / tot, res, tot
end

-- ───── 2D experience и лор ─────

-- Корреляция Пирсона
function MathCore.corr(a: Vector, b: Vector): number
	local ma, mb = MathCore.mean(a), MathCore.mean(b)
	local sab, saa, sbb = 0, 0, 0
	for i = 1, #a do
		local da, db = a[i] - ma, b[i] - mb
		sab += da * db; saa += da * da; sbb += db * db
	end
	return sab / math.sqrt(saa * sbb)
end

-- L(m) = a·m² + b·m + k для прямой, вращаемой вокруг (pivotX, h) (2D.1). При pivotX = x̄:
-- a = Σ(Δx)², b = −2·ΣΔxΔy, k = Σ(Δy)² + n·(ȳ − h)².
function MathCore.slopeLoss(x: Vector, y: Vector, h: number, pivotX: number): (number, number, number)
	local a, b, k = 0, 0, 0
	for i = 1, #x do
		local u, w = x[i] - pivotX, y[i] - h
		a += u * u; b -= 2 * u * w; k += w * w
	end
	return a, b, k
end

-- dL/dc = −2·Σ(yᵢ − m·xᵢ − c) (2D.3)
function MathCore.dLdc(x: Vector, y: Vector, m: number, c: number): number
	local s = 0
	for i = 1, #x do s += y[i] - m * x[i] - c end
	return -2 * s
end

-- Минимум L(m) + штраф при оптимальном c (2D.6): L2 → Sxy/(Sxx + λ); L1 → S(2·Sxy, λ)/(2·Sxx)
function MathCore.penalizedMin1d(x: Vector, y: Vector, lambda: number, kind: string): number
	local o = MathCore.ols1d(x, y)
	if kind == "l2" then
		return o.sxy / (o.sxx + lambda)
	end
	local mag = math.max(math.abs(2 * o.sxy) - lambda, 0)
	return (if o.sxy >= 0 then mag else -mag) / (2 * o.sxx)
end

-- Коэффициенты стандартизованной модели → исходные единицы: ŷ = a0 + Σ a_j·x_j
function MathCore.toRawUnits(b0: number, b: Vector, means: Vector, sds: Vector): (number, Vector)
	local a = table.create(#b)
	local a0 = b0
	for j = 1, #b do
		a[j] = b[j] / sds[j]
		a0 -= a[j] * means[j]
	end
	return a0, a
end

-- G = XcᵀXc (2 признака): SSE(b) = SSE(b̂) + (b − b̂)ᵀ·G·(b − b̂) — эллипсы уровня в 2D.5
function MathCore.gram(Xs: Matrix): Matrix
	local Xc = centered(Xs, table.create(#Xs, 0))
	local p = #Xc[1]
	local G = table.create(p)
	for a = 1, p do
		G[a] = table.create(p, 0)
		for b = 1, p do
			for i = 1, #Xc do G[a][b] += Xc[i][a] * Xc[i][b] end
		end
	end
	return G
end

-- Сумма квадратов остатков при коэффициентах b и оптимальном свободном члене
function MathCore.sseCoef(Xs: Matrix, y: Vector, b: Vector): number
	local _, _, xm, ym = centered(Xs, y)
	local b0 = intercept(xm, ym, b)
	local s = 0
	for i, row in Xs do
		local e = y[i] - b0
		for j = 1, #b do e -= row[j] * b[j] end
		s += e * e
	end
	return s
end

-- Собственные числа и векторы симметричной 2×2 (по возрастанию): w1, w2, v1, v2
local function eig2(G: Matrix): (number, number, Vector, Vector)
	local a, b, d = G[1][1], G[1][2], G[2][2]
	local tr, det = a + d, a * d - b * b
	local disc = math.sqrt(math.max(tr * tr / 4 - det, 0))
	local w1, w2 = tr / 2 - disc, tr / 2 + disc
	local v1: Vector
	if math.abs(b) > 1e-12 then
		v1 = { w1 - d, b }
	else
		v1 = if a <= d then { 1, 0 } else { 0, 1 }
	end
	local len = math.sqrt(v1[1] ^ 2 + v1[2] ^ 2)
	v1 = { v1[1] / len, v1[2] / len }
	return w1, w2, v1, { -v1[2], v1[1] }
end
MathCore._eig2 = eig2

-- Точка эллипса (b − c)ᵀG(b − c) = level, параметр t ∈ [0; 2π)
function MathCore.ellipsePoint(G: Matrix, center: Vector, level: number, t: number): Vector
	local w1, w2, v1, v2 = eig2(G)
	local p, q = math.sqrt(level / w1) * math.cos(t), math.sqrt(level / w2) * math.sin(t)
	return { center[1] + v1[1] * p + v2[1] * q, center[2] + v1[2] * p + v2[2] * q }
end

-- Путь коэффициентов на сетке λ (считать один раз при входе в сцену): { lambdas, b0s, coefs }
function MathCore.path(kind: string, Xs: Matrix, y: Vector, lambdaMax: number, steps: number)
	local lambdas, b0s, coefs = table.create(steps + 1), table.create(steps + 1), table.create(steps + 1)
	for i = 0, steps do
		local lam = lambdaMax * i / steps
		local b0, b
		if kind == "l2" then
			b0, b = MathCore.ridge(Xs, y, lam)
		else
			b0, b = MathCore.lasso(Xs, y, lam)
		end
		lambdas[i + 1], b0s[i + 1], coefs[i + 1] = lam, b0, b
	end
	return { lambdas = lambdas, b0s = b0s, coefs = coefs, lambdaMax = lambdaMax, steps = steps }
end

-- Коэффициенты на пути при произвольном λ (линейная интерполяция между узлами сетки;
-- точные нули Lasso сохраняются, если оба соседних узла — нули)
function MathCore.pathAt(path, lambda: number): (number, Vector)
	local f = math.clamp(lambda / path.lambdaMax, 0, 1) * path.steps
	local i = math.floor(f)
	if i >= path.steps then
		return path.b0s[path.steps + 1], table.clone(path.coefs[path.steps + 1])
	end
	local t = f - i
	local a, b = path.coefs[i + 1], path.coefs[i + 2]
	local out = table.create(#a)
	for j = 1, #a do
		out[j] = if a[j] == b[j] then a[j] else a[j] + (b[j] - a[j]) * t
	end
	return path.b0s[i + 1] + (path.b0s[i + 2] - path.b0s[i + 1]) * t, out
end

return MathCore
