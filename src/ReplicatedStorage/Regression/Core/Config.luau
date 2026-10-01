--!strict
-- Config: все числовые константы 3D experience в одном месте.

return {
	STUDS_PER_M = 4, -- 1 м данных = 4 studs: клумба 5 × 3 м = 20 × 12 studs

	-- Прямая
	SLOPE_MIN = -1,
	SLOPE_MAX = 1.5,
	H_MIN = 0,
	H_MAX = 3,
	H_STEP = 0.05, -- высота «защёлкивается» на сетку 0,05 м при отпускании Shift/Ctrl
	ANGLE_SPEED_DEG = 20, -- Q/E: град/с
	H_SPEED = 0.5, -- Shift/Ctrl: м/с

	-- Шаги
	ZONE_STUDS = 10, -- табло оживает, когда игрок ближе 10 studs к клумбе
	MANUAL_THREADS_BEFORE_AUTO = 2, -- после 2 ручных нитей — кнопка «протянуть остальные»
	SNAP_TOL = 0.03, -- 3D.5: прилипание к m*
	BEST_H = 1.5, -- 3D.5 бонус: высота лучшей прямой (= ȳ)
	ONE_SIDE_CHECK_AFTER = 4, -- после 4-й записи проверка «все по одну сторону»

	-- Анимации (все ≤ 3 с, переходы ≤ 0,6 с)
	THREAD_GROW_S = 0.5,
	SQUARE_GROW_S = 0.6,
	BOARD2_RISE_S = 1.8,

	-- Лор-задача: путь в мире пропорционален сюжетному расстоянию до поляны
	LORE_STUDS_PER_M = 0.012, -- 550 м ≈ 11 studs, 1630 м ≈ 24 studs (плюс 4 studs от улья)

	-- Встраивание в общий мир: HUD модуля виден только рядом с клумбой или пасекой
	HUD_RADIUS_BED = 60,
	HUD_RADIUS_LORE = 45,

	-- Подсказки и UI
	HINT_IDLE_S = 45,
	UI_HZ = 30,
	TOAST_S = 3,
}
