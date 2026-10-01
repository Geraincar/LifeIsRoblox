-- Автотест MathCore против эталона scripts/export_expected.py (110 проверок).
-- Модуль возвращает функцию: run(MathCore, Datasets, ExpectedValues) → checks, fails.
-- Standalone: luau tests/run.luau · Studio: Script RegressionTests в ServerScriptService.
return function(MathCore, D, E)

	local fails, checks = 0, 0
	local function near(name: string, got: number, want: number, tol: number?)
		checks += 1
		if math.abs(got - want) > (tol or 1e-5) then
			fails += 1
			print(("FAIL %s: got %.6f want %.6f"):format(name, got, want))
		end
	end
	local function col(v)
		local X = {}
		for i, a in v do X[i] = { a } end
		return X
	end

	-- 3D-клумба
	local fb, Efb = D.flowerbed, E.flowerbed
	local x, y = fb.x_m, fb.y_m
	local o = MathCore.ols1d(x, y)
	near("fb m", o.b1, Efb.ols.m); near("fb c", o.b0, Efb.ols.c); near("fb L", MathCore.sse1d(x, y, o.b0, o.b1), Efb.ols.L)
	near("fb mse", MathCore.mseLine(x, y, o.b1, o.b0), Efb.ols.mse)
	for _, ex in Efb.mse_examples do
		local c = MathCore.lineFromPivot(ex.m, ex.h, fb.pivot_x_m)
		near(("fb mse m=%g h=%g"):format(ex.m, ex.h), MathCore.mseLine(x, y, ex.m, c), ex.mse)
	end
	local rec = Efb.recording_example
	local vs = {}
	for i, mm in rec.m do vs[i] = MathCore.mseLine(x, y, mm, MathCore.lineFromPivot(mm, rec.h, fb.pivot_x_m)); near("fb rec " .. i, vs[i], rec.mse[i]) end
	local P = MathCore.fitParabola(rec.m, vs)
	near("fb parabola a", P.a, rec.parabola.a); near("fb parabola m*", P.tStar, rec.parabola.m_star); near("fb parabola mse*", P.vStar, rec.parabola.mse_star)
	for i, e in Efb.residuals_at_ols do near("fb resid " .. i, y[i] - (o.b1 * x[i] + o.b0), e) end
	for lam, want in Efb.ridge_m do local _, b = MathCore.ridge(col(x), y, tonumber(lam)); near("fb ridge " .. lam, b[1], want) end
	for lam, want in Efb.lasso_m do local _, b = MathCore.lasso(col(x), y, tonumber(lam)); near("fb lasso " .. lam, b[1], want) end
	for key, want in Efb.penalized_loss do
		local kind, lam, mm = key:match("^(l%d)_([%d%.]+)_([%d%.%-]+)$")
		near("fb pen " .. key, MathCore.penalizedLoss1d(x, y, tonumber(mm), tonumber(lam), kind), want)
	end

	-- Свободный член и R²
	local idm, Eid = D.intercept_demo, E.intercept_demo
	local o2 = MathCore.ols1d(idm.bees_k, idm.honey_kg)
	near("id m", o2.b1, Eid.ols.m); near("id c", o2.b0, Eid.ols.c)
	local v2 = {}
	for i, cc in Eid.recording_example.c do v2[i] = MathCore.mseLine(idm.bees_k, idm.honey_kg, idm.fixed_slope, cc); near("id rec " .. i, v2[i], Eid.recording_example.mse[i]) end
	local P2 = MathCore.fitParabola(Eid.recording_example.c, v2)
	near("id c*", P2.tStar, Eid.recording_example.c_star); near("id mse*", P2.vStar, Eid.recording_example.mse_star)
	local yhat = {}
	for i, xi in idm.bees_k do yhat[i] = o2.b0 + o2.b1 * xi end
	local r, res, tot = MathCore.r2(idm.honey_kg, yhat)
	near("id r2", r, Eid.r2.r2); near("id ss_res", res, Eid.r2.ss_res); near("id ss_tot", tot, Eid.r2.ss_tot)

	-- Малая выборка
	local Es = E.small_sample
	local Xtr, ytr, Xte, yte, Xall, yall = {}, {}, {}, {}, {}, {}
	for _, row0 in D.small_sample.rows do
		local row = { row0.bees_k, row0.temperature_C }
		table.insert(Xall, row); table.insert(yall, row0.honey_kg)
		if row0.sample == "first5" then table.insert(Xtr, row); table.insert(ytr, row0.honey_kg)
		else table.insert(Xte, row); table.insert(yte, row0.honey_kg) end
	end
	local Ztr, mu, sd = MathCore.standardize(Xtr)
	local Zte = MathCore.standardize(Xte, mu, sd)
	local function chk(name, fn, lam, ex)
		local b0, b = fn(Ztr, ytr, lam)
		near(name .. " b0", b0, ex.b0)
		for j = 1, #b do near(name .. " coef" .. j, b[j], ex.coefs[j]) end
		near(name .. " r2 first5", (MathCore.r2(ytr, MathCore.predict(b0, b, Ztr))), ex.r2_first5)
		near(name .. " r2 rest", (MathCore.r2(yte, MathCore.predict(b0, b, Zte))), ex.r2_rest)
	end
	chk("ss ols", MathCore.ridge, 0, Es.ols_first5)
	for lam, ex in Es.ridge do chk("ss ridge " .. lam, MathCore.ridge, tonumber(lam), ex) end
	for lam, ex in Es.lasso do chk("ss lasso " .. lam, MathCore.lasso, tonumber(lam), ex) end
	local Za = MathCore.standardize(Xall); local a0, ab = MathCore.ols(Za, yall)
	near("ss ols all15", (MathCore.r2(yall, MathCore.predict(a0, ab, Za))), Es.ols_all15_r2)

	-- 2D experience и лор: новые функции ядра
	for hk, ex in Efb.slope_loss do
		local a, b, k = MathCore.slopeLoss(x, y, tonumber(hk), fb.pivot_x_m)
		near("slopeLoss a h=" .. hk, a, ex.a); near("slopeLoss b h=" .. hk, b, ex.b); near("slopeLoss k h=" .. hk, k, ex.k)
	end
	for kind, t in Efb.penalized_min do
		for lam, ex in t do
			near(("penalizedMin1d %s λ=%s"):format(kind, lam), MathCore.penalizedMin1d(x, y, tonumber(lam), kind), ex)
		end
	end
	local idm2, Eid2 = D.intercept_demo, E.intercept_demo
	for cc, ex in Eid2.dldc do
		near("dLdc c=" .. cc, MathCore.dLdc(idm2.bees_k, idm2.honey_kg, idm2.fixed_slope, tonumber(cc)), ex)
	end
	do
		local rows = D.small_sample.rows
		local X5, y5 = {}, {}
		for _, r in rows do
			if r.sample == "first5" then
				table.insert(X5, { r.bees_k, r.temperature_C }); table.insert(y5, r.honey_kg)
			end
		end
		local Z5, mu5, sd5 = MathCore.standardize(X5)
		local G = MathCore.gram(Z5)
		for a = 1, 2 do for b = 1, 2 do near(("gram %d%d"):format(a, b), G[a][b], Es.gram[a][b]) end end
		local _, bo = MathCore.ols(Z5, y5)
		near("sse ols", MathCore.sseCoef(Z5, y5, bo), Es.sse_ols)
		local ec = Es.ellipse_check
		local pt = MathCore.ellipsePoint(G, bo, ec.level, ec.t)
		-- знак собственных векторов произволен (numpy и Luau могут дать разные точки), проверяем само свойство:
		-- точка лежит на эллипсе уровня — SSE = SSE(b̂) + level
		near("ellipse sse", MathCore.sseCoef(Z5, y5, pt), ec.sse, 1e-4)
		for _, t in { 0, 1.3, 2.9, 4.4 } do
			near("ellipse sse t=" .. t, MathCore.sseCoef(Z5, y5, MathCore.ellipsePoint(G, bo, ec.level, t)), ec.sse, 1e-4)
		end
		local a0, araw = MathCore.toRawUnits(Es.ols_first5.b0, bo, mu5, sd5)
		near("raw a0 ss", a0, Es.ols_first5.raw.a0); near("raw a1 ss", araw[1], Es.ols_first5.raw.a[1]); near("raw a2 ss", araw[2], Es.ols_first5.raw.a[2])
		local path = MathCore.path("l1", Z5, y5, 20, 400)
		local _, bz = MathCore.pathAt(path, 1.5)
		near("lasso path λ=1.5 bees", bz[1], Es.lasso["1.5"].coefs[1], 1e-4)
		checks += 1
		if bz[2] ~= 0 then fails += 1; print("FAIL lasso path λ=1.5: температура не ровно 0") end
		local _, bnz = MathCore.pathAt(path, Es.lasso_zero_lambda - 0.01)
		checks += 1
		if bnz[2] == 0 then fails += 1; print("FAIL lasso path: температура обнулилась раньше λ*") end
		local rpath = MathCore.path("l2", Z5, y5, 20, 400)
		local _, br = MathCore.pathAt(rpath, 1)
		near("ridge path λ=1", br[1], Es.ridge["1"].coefs[1], 1e-6); near("ridge path λ=1 t", br[2], Es.ridge["1"].coefs[2], 1e-6)
	end

	-- Лор
	local L, El = D.lore, E.lore
	local function mat(rows)
		local X, yy = {}, {}
		for i, r in rows do
			local row = {}
			for j, f in L.features do row[j] = r[f] end
			X[i] = row; yy[i] = r.honey_kg
		end
		return X, yy
	end
	local Xl, hl = mat(L.train_apiaries); local Xp, hp = mat(L.player_hives)
	local Zl, ml, sl = MathCore.standardize(Xl); local Zp = MathCore.standardize(Xp, ml, sl)
	local lb0, lb = MathCore.lasso(Zl, hl, L.lambda_given)
	near("lore b0", lb0, El.lasso.b0)
	for j = 1, 3 do near("lore coef" .. j, lb[j], El.lasso.coefs[j]) end
	local pr = MathCore.predict(lb0, lb, Zp)
	for i = 1, #pr do near("lore pred" .. i, pr[i], El.lasso.predictions[i]) end
	near("lore r2", (MathCore.r2(hp, pr)), El.lasso.r2_player)
	local ob0, ob = MathCore.ols(Zl, hl)
	near("lore ols r2", (MathCore.r2(hp, MathCore.predict(ob0, ob, Zp))), El.ols.r2_player)
	near("lore corr bees-temp", MathCore.corr(MathCore.column(Xl, 2), MathCore.column(Xl, 3)), El.corr_bees_temp)
	near("ss corr first5", MathCore.corr(MathCore.column(Xtr, 1), MathCore.column(Xtr, 2)), Es.corr_first5)
	local ra0, ra = MathCore.toRawUnits(lb0, lb, ml, sl)
	near("lore raw intercept", ra0, El.lasso.raw_intercept)
	for j = 1, 3 do near("lore raw coef" .. j, ra[j], El.lasso.coefs_raw_units[j]) end
	local opr = MathCore.predict(ob0, ob, Zp)
	for i = 1, #opr do near("lore ols pred" .. i, opr[i], El.ols.predictions[i]) end

	print(("MathCore: %d/%d проверок пройдено"):format(checks - fails, checks))
	return checks, fails
end
