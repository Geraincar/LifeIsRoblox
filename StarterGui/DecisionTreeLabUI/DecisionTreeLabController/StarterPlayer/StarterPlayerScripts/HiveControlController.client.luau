local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)


local player =
	Players.LocalPlayer


local gui =
	player
		:WaitForChild("PlayerGui")
		:WaitForChild(
			"HiveControlUI"
		)


local rpc =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"HiveControlRPC"
		)


local openRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"HiveControlOpen"
		)


local overlay =
	gui:WaitForChild(
		"Overlay"
	)


local window =
	overlay:WaitForChild(
		"Window"
	)


local openButton =
	gui:WaitForChild(
		"OpenButton"
	)


local closeButton =
	window:WaitForChild(
		"CloseButton"
	)


local statBar =
	window:WaitForChild(
		"StatBar"
	)


local bottleneck =
	window:WaitForChild(
		"BottleneckLabel"
	)


local jobsLabel =
	window:WaitForChild(
		"JobsLabel"
	)


local impactLabel =
	window:WaitForChild(
		"ImpactLabel"
	)


local cards =
	window:WaitForChild(
		"Cards"
	)


local applying =
	false



------------------------------------------------------------
-- FORMAT
------------------------------------------------------------

local function f2(
	value
)

	return string.format(
		"%.2f",
		value or 0
	)

end



------------------------------------------------------------
-- BOTTLENECK
------------------------------------------------------------

local function bottleneckText(
	state
)

	local stats =
		state.Stats


	local values = {

		{
			Name =
				"снабжение",

			Value =
				stats.EffectiveSupply,
		},

		{
			Name =
				"переработка",

			Value =
				stats.EffectiveProcessing,
		},

		{
			Name =
				"рабочая сила",

			Value =
				stats.Workforce,
		},

	}


	table.sort(
		values,
		function(a, b)

			return
				a.Value
				< b.Value

		end
	)


	return
		"Текущее узкое место: "
		..
		values[1].Name
		..
		"  ("
		..
		f2(
			values[1].Value
		)
		..
		")"

end



------------------------------------------------------------
-- METHOD CARD
------------------------------------------------------------

local function renderMethod(
	methodId,
	methodState,
	state
)

	local card =
		cards:WaitForChild(
			methodId
		)


	local status =
		card:WaitForChild(
			"Status"
		)


	local detail =
		card:WaitForChild(
			"Detail"
		)


	local button =
		card:WaitForChild(
			"ApplyButton"
		)


	if methodState.Applied then

		status.Text =
			"ПРИМЕНЕНО"


		status.TextColor3 =
			Color3.fromRGB(
				0,
				158,
				115
			)


		button.Visible =
			false


	elseif methodState.Unlocked then

		status.Text =
			"ГОТОВО К ПРИМЕНЕНИЮ"


		status.TextColor3 =
			Color3.fromRGB(
				230,
				159,
				0
			)


		button.Visible =
			true


	else

		status.Text =
			"ЗАБЛОКИРОВАНО"


		status.TextColor3 =
			Color3.fromRGB(
				160,
				160,
				170
			)


		button.Visible =
			false

	end


	if methodId
		== "regression"
	then

		if methodState.Applied then

			detail.Text =
				"Поля: A 20% • B 40% • C 10% • D 30%"

		elseif methodState.Unlocked then

			detail.Text =
				"Модель готова. Примените прогноз к маршрутам сборщиков."

		else

			detail.Text =
				"Сначала завершите уровень по регрессии."

		end


	elseif methodId
		== "tree"
	then

		if methodState.Applied then

			detail.Text =
				"Точность маршрутизации: "
				..
				tostring(
					math.floor(
						(state.RoutingAccuracy or 0)
						* 100
					)
				)
				..
				"%"

		elseif methodState.Unlocked then

			detail.Text =
				"Сортировщик готов к подключению к производству."

		else

			detail.Text =
				"Сначала завершите уровень с решающим деревом."

		end


	elseif methodId
		== "clustering"
	then

		if methodState.Applied then

			detail.Text =
				"Когорты назначены на подходящие виды работ."

		elseif methodState.Unlocked then

			detail.Text =
				"Когорты найдены. Примените распределение задач."

		else

			detail.Text =
				"Сначала завершите уровень по кластеризации."

		end

	end

end



------------------------------------------------------------
-- RENDER
------------------------------------------------------------

local function render(
	state,
	impact
)

	if not state
		or not state.Available
	then

		return

	end


	statBar.HoneyValue.Text =
		string.format(
			"%.1f",
			state.Honey
			or 0
		)


	statBar.RateValue.Text =
		f2(
			state.HoneyRate
		)
		..
		" / сек"


	statBar.SupplyValue.Text =
		f2(
			state.Stats
				.EffectiveSupply
		)


	statBar.ProcessingValue.Text =
		f2(
			state.Stats
				.EffectiveProcessing
		)


	statBar.WorkforceValue.Text =
		f2(
			state.Stats
				.Workforce
		)


	bottleneck.Text =
		bottleneckText(
			state
		)


	jobsLabel.Text =
		string.format(
			"Пчёлы: сборщики — %d • улей — %d • отдых — %d • карантин — %d",
			state.Jobs.Forage,
			state.Jobs.HiveWork,
			state.Jobs.Rest,
			state.Jobs.Quarantine
		)


	renderMethod(
		"regression",
		state.Methods.regression,
		state
	)


	renderMethod(
		"tree",
		state.Methods.tree,
		state
	)


	renderMethod(
		"clustering",
		state.Methods.clustering,
		state
	)


	if impact then

		local before =
			impact.Before


		local after =
			impact.After


		impactLabel.Text =
			impact.Text
			..
			"   Производство: "
			..
			f2(
				before.HoneyRate
			)
			..
			" → "
			..
			f2(
				after.HoneyRate
			)
			..
			" / сек"

	else

		impactLabel.Text =
			""

	end

end



------------------------------------------------------------
-- GET STATE
------------------------------------------------------------

local function refresh()

	local ok,
		result =
		pcall(
			function()

				return rpc:InvokeServer(
					"GetState"
				)

			end
		)


	if ok
		and result
		and result.Ok
	then

		render(
			result.State
		)

	end

end



------------------------------------------------------------
-- OPEN
------------------------------------------------------------

local function open()

	overlay.Visible =
		true


	refresh()

end



local function close()

	overlay.Visible =
		false

end



openButton.MouseButton1Click
	:Connect(
		open
	)


closeButton.MouseButton1Click
	:Connect(
		close
	)



------------------------------------------------------------
-- APPLY
------------------------------------------------------------

local function apply(
	methodId
)

	if applying then
		return
	end


	applying =
		true


	local card =
		cards:WaitForChild(
			methodId
		)


	local button =
		card:WaitForChild(
			"ApplyButton"
		)


	local oldText =
		button.Text


	button.Text =
		"ПРИМЕНЯЕМ..."


	button.Active =
		false


	local ok,
		result =
		pcall(
			function()

				return rpc:InvokeServer(
					"Apply",
					methodId
				)

			end
		)


	if ok
		and result
		and result.Ok
	then

		render(
			result.State,
			result.Impact
		)

	else

		impactLabel.Text =
			"Ошибка: "
			..
			tostring(
				result
				and result.Error
				or "неизвестная ошибка"
			)


		impactLabel.TextColor3 =
			Color3.fromRGB(
				213,
				94,
				0
			)

	end


	button.Text =
		oldText


	button.Active =
		true


	applying =
		false

end



cards.regression.ApplyButton
	.MouseButton1Click
	:Connect(
		function()

			apply(
				"regression"
			)

		end
	)


cards.tree.ApplyButton
	.MouseButton1Click
	:Connect(
		function()

			apply(
				"tree"
			)

		end
	)


cards.clustering.ApplyButton
	.MouseButton1Click
	:Connect(
		function()

			apply(
				"clustering"
			)

		end
	)



------------------------------------------------------------
-- AUTO OPEN AFTER LESSON
------------------------------------------------------------

openRemote.OnClientEvent:Connect(
	function(methodId)

		overlay.Visible =
			true


		refresh()


		impactLabel.Text =
			"Метод изучен. Теперь примените его к работе улья."

	end
)



------------------------------------------------------------
-- LIVE UPDATE WHILE OPEN
------------------------------------------------------------

task.spawn(
	function()

		while true do

			task.wait(
				1
			)


			if overlay.Visible
				and not applying
			then

				refresh()

			end

		end

	end
)



overlay.Visible =
	false


print(
	"[HiveControl] Client ready"
)
