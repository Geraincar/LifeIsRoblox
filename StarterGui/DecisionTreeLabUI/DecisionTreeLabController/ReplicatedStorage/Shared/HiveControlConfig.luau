local Config = {}


Config.MethodOrder = {

	"regression",

	"tree",

	"clustering",

}


Config.Methods = {


	regression = {

		Name =
			"Регрессия",

		Subtitle =
			"Прогноз добычи с полей",

		Description =
			"Модель оценивает ожидаемую добычу нектара и помогает направлять сборщиков на более перспективные поля.",

		Effect =
			"Влияет на снабжение улья сырьём.",

		LevelId =
			"regression",

	},


	tree = {

		Name =
			"Решающее дерево",

		Subtitle =
			"Сортировка и маршрутизация сырья",

		Description =
			"Дерево автоматически определяет, как обработать каждую поступившую партию: хранить, сушить, фильтровать или отклонить.",

		Effect =
			"Влияет на скорость и качество переработки.",

		LevelId =
			"decision_tree",

	},


	clustering = {

		Name =
			"Кластеризация",

		Subtitle =
			"Когорты пчёл и распределение задач",

		Description =
			"Пчёлы группируются по здоровью, активности, потреблению и продуктивности. Каждая когорта получает подходящую работу.",

		Effect =
			"Влияет на рабочую силу, здоровье и потребление.",

		LevelId =
			"dbscan",

	},

}


Config.FieldPriorities = {

	A = 0.20,

	B = 0.40,

	C = 0.10,

	D = 0.30,

}


Config.RegressionSupplyFactor =
	1.35


Config.TreeProcessingFactor =
	2.20


return Config
