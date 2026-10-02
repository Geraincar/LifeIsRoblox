
local Datasets = {}


-- Координаты — это именно учебные x1/x2.
-- В мире они потом умножаются на Config.SCALE.

Datasets.manual = {

	name =
		"Two visible groups",

	points = {

		-- LEFT CLOUD

		Vector2.new(-7.8,  4.5),
		Vector2.new(-6.5,  2.5),
		Vector2.new(-8.2,  0.2),
		Vector2.new(-5.8, -1.2),
		Vector2.new(-7.4, -3.8),
		Vector2.new(-4.6,  4.0),
		Vector2.new(-4.1,  1.3),
		Vector2.new(-5.1, -3.5),
		Vector2.new(-8.8, -2.1),

		-- RIGHT CLOUD

		Vector2.new(4.0,  4.8),
		Vector2.new(6.3,  3.9),
		Vector2.new(8.0,  4.9),
		Vector2.new(4.8,  1.4),
		Vector2.new(7.2,  0.9),
		Vector2.new(8.7,  2.1),
		Vector2.new(4.1, -2.7),
		Vector2.new(6.5, -3.8),
		Vector2.new(8.6, -1.9),

	}

}


return Datasets

