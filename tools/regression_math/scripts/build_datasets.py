"""Собирает и проверяет кураторские датасеты нового ТЗ, пишет assets/datasets.json.

Наборы:
  flowerbed       — 3D-клумба: 5 цветков, координаты в метрах (x вдоль клумбы, y поперёк).
                    Квесты 3D.1–3D.6 и 2D.1, 2D.6.
  intercept_demo  — 5 точек «пчёлы (тыс.) → мёд (кг)», поиск свободного члена (2D.2–2D.3) и R² (2D.7).
  small_sample    — 15 точек «пчёлы, температура → мёд»; первые 5 — малая выборка (2D.4–2D.5).
  lore            — 5 чужих пасек (обучение) + 5 ульев игрока (проверка): расстояние до ближайшей
                    поляны, пчёлы, температура → мёд. Задача после обучения.
Все педагогические критерии проверяются assert'ами; если генератор поменять — скрипт упадёт,
а не выдаст «тихо сломанный» урок.
"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference_math import standardize, ridge, lasso, ols, predict, r2, ols_1d

r05 = lambda a: np.round(np.asarray(a) * 2) / 2


def flowerbed():
    x = [0.5, 1.5, 2.5, 3.5, 4.5]
    y = [1.1, 0.8, 1.3, 2.3, 2.0]
    c, m = ols_1d(x, y)
    assert abs(m - 0.33) < 1e-9 and abs(c - 0.675) < 1e-9
    return {"x_m": x, "y_m": y, "bed_length_m": 5.0, "bed_width_m": 3.0, "pivot_x_m": 2.5,
            "start_line": {"m": 0.0, "h": 1.0}}


def intercept_demo():
    x = [20, 30, 40, 50, 60]
    y = [17, 17, 26, 32, 33]
    c, m = ols_1d(x, y)
    assert abs(m - 0.47) < 1e-9 and abs(c - 6.2) < 1e-9
    return {"bees_k": x, "honey_kg": y, "fixed_slope": 0.47}


def small_sample(seed=12):
    rng = np.random.default_rng(seed)
    n = 15
    t = r05(rng.uniform(14, 30, n))
    bees = r05(np.clip(2.2 * t - 12 + rng.normal(0, 3, n), 15, 65))
    h = r05(0.5 * bees + 5 + rng.normal(0, 2.5, n))
    X = np.column_stack([bees, t])
    tr, te = np.arange(5), np.arange(5, 15)
    Xs, mu, sd = standardize(X[tr]); Xt, _, _ = standardize(X[te], mu, sd)
    b0, b = ols(Xs, h[tr])
    assert r2(h[te], predict(b0, b, Xt)) < 0.2 and b[1] < -1
    Xa, _, _ = standardize(X); a0, ab = ols(Xa, h)
    assert r2(h, predict(a0, ab, Xa)) > 0.8
    rows = [{"point": i + 1, "sample": "first5" if i < 5 else "rest",
             "bees_k": float(bees[i]), "temperature_C": float(t[i]), "honey_kg": float(h[i])} for i in range(n)]
    return {"seed": seed, "rows": rows}


def lore(seed=9):
    rng = np.random.default_rng(seed)

    def gen(n):
        t = r05(rng.uniform(15, 30, n))
        bees = r05(np.clip(2.2 * t - 12 + rng.normal(0, 2.5, n), 15, 65))
        d = np.round(rng.uniform(200, 2000, n) / 10) * 10
        h = r05(0.55 * bees - 0.008 * d + 0.15 * t + 12 + rng.normal(0, 1.5, n))
        return np.column_stack([d, bees, t]), h

    X, h = gen(5); Xt, ht = gen(5)
    assert np.corrcoef(X[:, 1], X[:, 2])[0, 1] > 0.85
    Xs, mu, sd = standardize(X); Xts, _, _ = standardize(Xt, mu, sd)
    lam = 2.5
    b0, b = lasso(Xs, h, lam)
    assert abs(b[2]) < 1e-9 and b[1] > 0 and b[0] < 0, b
    pred = predict(b0, b, Xts)
    assert r2(ht, pred) > 0.85
    o0, ob = ols(Xs, h)
    assert r2(ht, predict(o0, ob, Xts)) < 0.5
    feats = ["distance_to_meadow_m", "bees_k", "temperature_C"]
    mk = lambda A, y, tag: [{tag: i + 1, **{f: float(A[i, j]) for j, f in enumerate(feats)},
                             "honey_kg": float(y[i])} for i in range(len(y))]
    lo, hi = float(np.floor(min(pred) / 5) * 5), float(np.ceil(max(pred) / 5) * 5)
    return {"seed": seed, "features": feats, "lambda_given": lam,
            "plausible_range_kg": [lo, hi],
            "train_apiaries": mk(X, h, "apiary"), "player_hives": mk(Xt, ht, "hive")}


if __name__ == "__main__":
    out = {"flowerbed": flowerbed(), "intercept_demo": intercept_demo(),
           "small_sample": small_sample(), "lore": lore()}
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    json.dump(out, open(os.path.join(root, "assets", "datasets.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("ok; lore range", out["lore"]["plausible_range_kg"])
