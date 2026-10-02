local DBSCAN_Config = {
	MIN_PTS = 3,
	DEFAULT_EPSILON = 12,
	EPSILON_MIN = 5,
	EPSILON_MAX = 30,
	BEE_COUNT = 16,

	CLUSTER_COLORS = {
		Color3.fromRGB(255, 80, 80),   -- red
		Color3.fromRGB(80, 140, 255),  -- blue
		Color3.fromRGB(80, 200, 100),  -- green
		Color3.fromRGB(255, 180, 60),  -- orange
		Color3.fromRGB(200, 100, 255), -- purple
	},

	BEE_TYPES = {
		[1] = { name = "Выносливые", color = Color3.fromRGB(220, 60, 60), icon = "💪" },
		[2] = { name = "Быстрые",    color = Color3.fromRGB(60, 120, 220), icon = "⚡" },
		[3] = { name = "Сильные",    color = Color3.fromRGB(60, 180, 80),  icon = "🔋" },
		[4] = { name = "Аномалия A", color = Color3.fromRGB(255, 200, 0),  icon = "?" },
		[5] = { name = "Аномалия B", color = Color3.fromRGB(180, 80, 220), icon = "?" },
		[6] = { name = "Аномалия C", color = Color3.fromRGB(255, 140, 40), icon = "?" },
		[7] = { name = "Аномалия D", color = Color3.fromRGB(220, 220, 220),icon = "?" },
	},

	-- Hive position for noise bees to fly to
	HIVE_POSITION = Vector3.new(75, -27, -170),
}

return DBSCAN_Config