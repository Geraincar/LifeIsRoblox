"""Эталонная математика регрессионного модуля «Улей».

Соглашения (ДОЛЖНЫ совпадать с Luau-реализацией, иначе числа в UI разойдутся с эталоном):
  * Функция потерь — СУММА квадратов остатков (не среднее):  L = Σ(yᵢ − ŷᵢ)²
  * Ridge:  L = Σe² + λ·Σ b_j²      Lasso:  L = Σe² + λ·Σ|b_j|
  * Свободный член c не штрафуется.
  * Для Ridge/Lasso признаки стандартизуются: z = (x − mean)/sd, sd с ddof=0,
    mean/sd берутся ТОЛЬКО по обучающей выборке.
  * Табло в 3D показывает MSE = L/n; на 2D-экранах — L (минимум тот же).
  * Одномерные демонстрации (клумба, свободный член, кривые штрафа) — на исходных единицах,
    стандартизация нужна только при 2+ признаках.
  * R² = 1 − SS_res/SS_tot, SS_tot считается от среднего той выборки, на которой меряем.
Запуск: python reference_math.py  → печатает эталонные числа клумбы (3D).
"""
import numpy as np


def ols_1d(x, y):
    x, y = np.asarray(x, float), np.asarray(y, float)
    xm, ym = x.mean(), y.mean()
    sxx = ((x - xm) ** 2).sum()
    sxy = ((x - xm) * (y - ym)).sum()
    b1 = sxy / sxx
    return ym - b1 * xm, b1


def standardize(X, mean=None, sd=None):
    X = np.asarray(X, float)
    if mean is None:
        mean, sd = X.mean(0), X.std(0)
    return (X - mean) / sd, mean, sd


def ridge(Xs, y, lam):
    """Xs — уже стандартизованные признаки. Возвращает (b0, b)."""
    y = np.asarray(y, float)
    ym = y.mean()
    Xc = Xs - Xs.mean(0)
    p = Xc.shape[1]
    b = np.linalg.solve(Xc.T @ Xc + lam * np.eye(p), Xc.T @ (y - ym))
    return ym - Xs.mean(0) @ b, b


def lasso(Xs, y, lam, iters=5000, tol=1e-12):
    """Координатный спуск для Σe² + λΣ|b|. b_j = S(ρ_j, λ/2) / Σx_j²."""
    y = np.asarray(y, float)
    ym = y.mean()
    Xc = Xs - Xs.mean(0)
    yc = y - ym
    p = Xc.shape[1]
    b = np.zeros(p)
    z = (Xc ** 2).sum(0)
    for _ in range(iters):
        b_old = b.copy()
        for j in range(p):
            r = yc - Xc @ b + Xc[:, j] * b[j]
            rho = Xc[:, j] @ r
            b[j] = np.sign(rho) * max(abs(rho) - lam / 2, 0) / z[j]
        if np.max(np.abs(b - b_old)) < tol:
            break
    return ym - Xs.mean(0) @ b, b


def ols(Xs, y):
    return ridge(Xs, y, 0.0)


def predict(b0, b, Xs):
    return b0 + Xs @ b


def r2(y, yhat):
    y = np.asarray(y, float)
    return 1 - ((y - yhat) ** 2).sum() / ((y - y.mean()) ** 2).sum()


def mse_line(x, y, m, c):
    """MSE прямой y = m·x + c (табло в 3D показывает именно MSE = L/n)."""
    x, y = np.asarray(x, float), np.asarray(y, float)
    return float(((y - (m * x + c)) ** 2).mean())


def line_from_pivot(m, h, pivot_x):
    """Прямая, вращаемая вокруг точки (pivot_x, h): возвращает свободный член c."""
    return h - m * pivot_x


def fit_parabola(t, v):
    """МНК-парабола v ≈ a·t² + b·t + k по записанным точкам; возвращает a, b, k, вершину (t*, v*).
    Для MSE при фиксированной высоте точки лежат на параболе точно, поэтому подгонка точная."""
    t, v = np.asarray(t, float), np.asarray(v, float)
    A = np.column_stack([t ** 2, t, np.ones_like(t)])
    a, b, k = np.linalg.lstsq(A, v, rcond=None)[0]
    ts = -b / (2 * a)
    return a, b, k, ts, a * ts ** 2 + b * ts + k


def penalized_loss_1d(x, y, m, lam, kind):
    """Сумма квадратов остатков при оптимальном c (= ȳ − m·x̄) плюс штраф. kind: 'l2' | 'l1'."""
    x, y = np.asarray(x, float), np.asarray(y, float)
    c = y.mean() - m * x.mean()
    L = ((y - m * x - c) ** 2).sum()
    return L + lam * (m * m if kind == "l2" else abs(m))


# ───── 2D experience и лор (добавлено для экранов 2D.1–2D.7 и лор-задачи) ─────

def slope_loss_coefs(x, y, h, pivot_x):
    """L(m) = a·m² + b·m + k для прямой, вращаемой вокруг (pivot_x, h). При pivot_x = x̄:
    a = Σ(Δx)², b = −2·ΣΔxΔy, k = Σ(Δy)² + n·(ȳ − h)²."""
    x, y = np.asarray(x, float), np.asarray(y, float)
    u = x - pivot_x          # y − ŷ = (y − h) − m·u
    w = y - h
    return float((u * u).sum()), float(-2 * (u * w).sum()), float((w * w).sum())


def dl_dc(x, y, m, c):
    """Производная суммы квадратов по свободному члену: dL/dc = −2·Σ(yᵢ − m·xᵢ − c)."""
    x, y = np.asarray(x, float), np.asarray(y, float)
    return float(-2 * (y - m * x - c).sum())


def penalized_min_1d(x, y, lam, kind):
    """Минимум L(m) + штраф при оптимальном c: L2 → Sxy/(Sxx+λ); L1 → S(2Sxy, λ)/(2Sxx)."""
    x, y = np.asarray(x, float), np.asarray(y, float)
    dx, dy = x - x.mean(), y - y.mean()
    sxx, sxy = (dx * dx).sum(), (dx * dy).sum()
    if kind == "l2":
        return float(sxy / (sxx + lam))
    return float(np.sign(sxy) * max(abs(2 * sxy) - lam, 0) / (2 * sxx))


def to_raw_units(b0, b, mean, sd):
    """Коэффициенты стандартизованной модели → исходные единицы: ŷ = a0 + Σ a_j·x_j."""
    a = np.asarray(b, float) / np.asarray(sd, float)
    return float(b0 - (a * np.asarray(mean, float)).sum()), a


def gram(Xs):
    """XcᵀXc по центрированным признакам: SSE(b) = SSE(b̂) + (b − b̂)ᵀ·G·(b − b̂)."""
    Xc = Xs - Xs.mean(0)
    return Xc.T @ Xc


def sse_coef(Xs, y, b):
    """Сумма квадратов остатков при коэффициентах b и оптимальном свободном члене."""
    y = np.asarray(y, float)
    b0 = y.mean() - Xs.mean(0) @ b
    return float(((y - b0 - Xs @ b) ** 2).sum())


def ellipse_point(G, center, level, t):
    """Точка эллипса (b − b̂)ᵀG(b − b̂) = level, параметр t ∈ [0; 2π)."""
    w, V = np.linalg.eigh(G)
    v = np.array([np.sqrt(level / w[0]) * np.cos(t), np.sqrt(level / w[1]) * np.sin(t)])
    return np.asarray(center, float) + V @ v


def corr(a, b):
    """Корреляция Пирсона (подсказка лор-задачи: температура почти повторяет число пчёл)."""
    return float(np.corrcoef(np.asarray(a, float), np.asarray(b, float))[0, 1])


def lasso_zero_lambda(Xs, y, j, lam_max=50.0, step=1e-4):
    """Наименьшее λ (с шагом step), при котором Lasso обнуляет коэффициент j."""
    lam = 0.0
    while lam <= lam_max:
        if lasso(Xs, y, lam)[1][j] == 0:
            return lam
        lam += step
    return None


FLOWER_X = [0.5, 1.5, 2.5, 3.5, 4.5]  # м, вдоль клумбы
FLOWER_Y = [1.1, 0.8, 1.3, 2.3, 2.0]  # м, поперёк клумбы

if __name__ == "__main__":
    x, y = np.array(FLOWER_X), np.array(FLOWER_Y)
    n = len(x); xm, ym = x.mean(), y.mean()
    dx, dy = x - xm, y - ym
    sxx, sxy, syy = (dx**2).sum(), (dx*dy).sum(), (dy**2).sum()
    c, m = ols_1d(x, y)
    print(f"Клумба: x̄={xm} ȳ={ym} Sxx={sxx:.4f} Sxy={sxy:.4f} Syy={syy:.4f}")
    print(f"OLS: m={m:.4f} c={c:.4f} L={((y-m*x-c)**2).sum():.4f} MSE={mse_line(x,y,m,c):.4f}")
    print(f"MSE(m | высота h, вращение вокруг x={xm}) = {sxx/n:.4f}·m² − {2*sxy/n:.4f}·m + {syy/n:.4f} + (ȳ − h)²")
    print(f"Ridge: m = {sxy:.4f}/({sxx:.4f}+λ);  Lasso: m = ({2*sxy:.4f} − λ)/{2*sxx:.4f}, ноль при λ ≥ {2*sxy:.4f}")
