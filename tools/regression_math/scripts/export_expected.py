"""Пишет assets/expected_values.json — эталон для автотестов Luau-ядра (MathCore) и контрольных чисел UI.
Запускать после build_datasets.py. Допуск в тестах 1e-5.
"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference_math import (standardize, ridge, lasso, ols, predict, r2, ols_1d,
                            mse_line, line_from_pivot, fit_parabola, penalized_loss_1d,
                            slope_loss_coefs, dl_dc, penalized_min_1d, to_raw_units, gram,
                            sse_coef, ellipse_point, lasso_zero_lambda, corr)

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = json.load(open(os.path.join(root, "assets", "datasets.json"), encoding="utf-8"))
R = lambda v: round(float(v), 6)
F = lambda v: [R(a) for a in np.atleast_1d(v)]
out = {}

# 3D-клумба
fb = D["flowerbed"]; x, y = np.array(fb["x_m"]), np.array(fb["y_m"]); px = fb["pivot_x_m"]
c, m = ols_1d(x, y)
rec_m = [-0.2, 0.0, 0.2, 0.5, 0.8]           # пример пяти записей при высоте h = 1.0
rec_h = 1.0
rec_v = [mse_line(x, y, mm, line_from_pivot(mm, rec_h, px)) for mm in rec_m]
a, b, k, ts, vs = fit_parabola(rec_m, rec_v)
out["flowerbed"] = {
    "ols": {"m": R(m), "c": R(c), "L": R(((y - m * x - c) ** 2).sum()), "mse": R(mse_line(x, y, m, c))},
    "mse_examples": [{"m": mm, "h": hh, "mse": R(mse_line(x, y, mm, line_from_pivot(mm, hh, px)))}
                     for mm, hh in [(0.0, 1.0), (0.33, 1.5), (0.5, 1.2), (-0.3, 2.0), (1.0, 1.5)]],
    "recording_example": {"h": rec_h, "m": rec_m, "mse": F(rec_v),
                          "parabola": {"a": R(a), "b": R(b), "k": R(k), "m_star": R(ts), "mse_star": R(vs)}},
    "residuals_at_ols": F(y - (m * x + c)),
    "ridge_m": {str(l): R(ridge(x[:, None], y, l)[1][0]) for l in [0, 1, 5, 10, 50]},
    "lasso_m": {str(l): R(lasso(x[:, None], y, l)[1][0]) for l in [0, 1, 3.3, 6, 6.6, 10]},
    "penalized_loss": {f"{kind}_{l}_{mm}": R(penalized_loss_1d(x, y, mm, l, kind))
                       for kind in ["l2", "l1"] for l in [0, 2, 6] for mm in [0.0, 0.2, 0.33]},
}
# Свободный член и R²
idm = D["intercept_demo"]; x2, y2 = np.array(idm["bees_k"], float), np.array(idm["honey_kg"], float)
c2, m2 = ols_1d(x2, y2)
rec_c = [0.0, 3.0, 6.0, 9.0, 12.0]
rec_v2 = [mse_line(x2, y2, idm["fixed_slope"], cc) for cc in rec_c]
a2, b2, k2, cs, vs2 = fit_parabola(rec_c, rec_v2)
r2v = r2(y2, m2 * x2 + c2)
out["intercept_demo"] = {
    "ols": {"m": R(m2), "c": R(c2)},
    "recording_example": {"c": rec_c, "mse": F(rec_v2), "c_star": R(cs), "mse_star": R(vs2)},
    "r2": {"ss_res": R(((y2 - m2 * x2 - c2) ** 2).sum()), "ss_tot": R(((y2 - y2.mean()) ** 2).sum()),
           "mean": R(y2.mean()), "r2": R(r2v)},
}
# Малая выборка 15 точек
rows = D["small_sample"]["rows"]
X = np.array([[r["bees_k"], r["temperature_C"]] for r in rows]); h = np.array([r["honey_kg"] for r in rows])
tr = np.array([r["sample"] == "first5" for r in rows])
Xs, mu, sd = standardize(X[tr]); Xt, _, _ = standardize(X[~tr], mu, sd)
def pk(fn, lam):
    b0, b = fn(Xs, h[tr], lam)
    return {"b0": R(b0), "coefs": F(b), "r2_first5": R(r2(h[tr], predict(b0, b, Xs))),
            "r2_rest": R(r2(h[~tr], predict(b0, b, Xt)))}
Xa, _, _ = standardize(X); a0, ab = ols(Xa, h)
out["small_sample"] = {"mean_first5": F(mu), "sd_first5": F(sd),
                       "corr_first5": R(np.corrcoef(X[tr].T)[0, 1]),
                       "ols_first5": pk(ridge, 0.0), "ols_all15_r2": R(r2(h, predict(a0, ab, Xa))),
                       "ridge": {str(l): pk(ridge, l) for l in [1, 3, 10]},
                       "lasso": {str(l): pk(lasso, l) for l in [1.5, 5, 15]}}
# Лор
L = D["lore"]; f = L["features"]
Xl = np.array([[r[k] for k in f] for r in L["train_apiaries"]]); hl = np.array([r["honey_kg"] for r in L["train_apiaries"]])
Xp = np.array([[r[k] for k in f] for r in L["player_hives"]]); hp = np.array([r["honey_kg"] for r in L["player_hives"]])
Xls, mul, sdl = standardize(Xl); Xps, _, _ = standardize(Xp, mul, sdl)
b0, b = lasso(Xls, hl, L["lambda_given"]); o0, ob = ols(Xls, hl)
pred = predict(b0, b, Xps)
out["lore"] = {"mean_train": F(mul), "sd_train": F(sdl),
               "lasso": {"lambda": L["lambda_given"], "b0": R(b0), "coefs": F(b),
                         "coefs_raw_units": F(b / sdl), "predictions": F(pred), "r2_player": R(r2(hp, pred))},
               "ols": {"b0": R(o0), "coefs": F(ob), "r2_player": R(r2(hp, predict(o0, ob, Xps)))}}
# 2D experience и лор: дополнительные эталоны
sl = {str(hh): dict(zip("abk", map(R, slope_loss_coefs(x, y, hh, px)))) for hh in [1.0, 1.5]}
out["flowerbed"]["slope_loss"] = sl
out["flowerbed"]["penalized_min"] = {kind: {str(l): R(penalized_min_1d(x, y, l, kind)) for l in [0, 1, 3.3, 5, 6.6, 10]}
                                     for kind in ["l2", "l1"]}
out["intercept_demo"]["dldc"] = {str(cc): R(dl_dc(x2, y2, idm["fixed_slope"], cc)) for cc in [0.0, 6.2, 9.0]}
G = gram(Xs); b_ols = ridge(Xs, h[tr], 0.0)[1]
sse_ols = sse_coef(Xs, h[tr], b_ols)
pt = ellipse_point(G, b_ols, 50.0, 0.7)
out["small_sample"]["gram"] = [F(G[0]), F(G[1])]
out["small_sample"]["sse_ols"] = R(sse_ols)
out["small_sample"]["ellipse_check"] = {"level": 50.0, "t": 0.7, "point": F(pt), "sse": R(sse_coef(Xs, h[tr], pt))}
out["small_sample"]["lasso_zero_lambda"] = R(lasso_zero_lambda(Xs, h[tr], 1, lam_max=5.0, step=1e-3))
rb0, ra = to_raw_units(b0, b, mul, sdl)
out["lore"]["lasso"]["raw_intercept"] = R(rb0)
out["lore"]["corr_bees_temp"] = R(corr(Xl[:, 1], Xl[:, 2]))
ob0r, obr = to_raw_units(o0, ob, mul, sdl)
out["lore"]["ols"]["predictions"] = F(predict(o0, ob, Xps))
out["lore"]["ols"]["coefs_raw_units"] = F(obr)
xs1 = X[tr]; a0s, a_s = to_raw_units(*ridge(Xs, h[tr], 0.0), mu, sd)
out["small_sample"]["ols_first5"]["raw"] = {"a0": R(a0s), "a": F(a_s)}

json.dump(out, open(os.path.join(root, "assets", "expected_values.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print(json.dumps({k: out[k] for k in ["intercept_demo"]}, ensure_ascii=False))
print(json.dumps(out["flowerbed"]["recording_example"], ensure_ascii=False))
print(json.dumps(out["small_sample"]["ols_first5"], ensure_ascii=False), out["small_sample"]["ols_all15_r2"], out["small_sample"]["corr_first5"])
print(json.dumps(out["small_sample"]["ridge"]["1"]), json.dumps(out["small_sample"]["lasso"]["1.5"]))
print(json.dumps(out["lore"], ensure_ascii=False))
