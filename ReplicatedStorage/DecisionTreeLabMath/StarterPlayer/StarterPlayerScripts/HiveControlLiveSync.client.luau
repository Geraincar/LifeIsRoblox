local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local rpc =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"HiveControlRPC"
		)



------------------------------------------------------------
-- UI
------------------------------------------------------------

local gui =
	playerGui:WaitForChild(
		"HiveControlUI"
	)


local overlay =
	gui:WaitForChild(
		"Overlay"
	)


local window =
	overlay:WaitForChild(
		"Window"
	)


local cards =
	window:WaitForChild(
		"Cards"
	)


local impact =
	window:WaitForChild(
		"ImpactLabel"
	)



------------------------------------------------------------
-- COLORS
------------------------------------------------------------

local GREEN =
	Color3.fromRGB(
		0,
		158,
		115
	)


local ORANGE =
	Color3.fromRGB(
		230,
		159,
		0
	)


local DIM =
	Color3.fromRGB(
		160,
		160,
		170
	)



------------------------------------------------------------
-- LEVEL FLOW VISIBILITY
------------------------------------------------------------

local function setFlowVisibility(
	hiveOpen
)

	local flow =
		playerGui:FindFirstChild(
			"LevelFlowUI"
		)


	if not flow then
		return
	end


	local status =
		flow:FindFirstChild(
			"Status"
		)


	local navigation =
		flow:FindFirstChild(
			"Navigation"
		)


	if hiveOpen then

		if status then
			status.Visible = false
		end


		if navigation then
			navigation.Visible = false
		end


	else

		if status then
			status.Visible = true
		end


		if navigation then

			local target =
				player:GetAttribute(
					"LevelFlowTargetLevel"
				)


			navigation.Visible =
				type(target) == "string"
				and target ~= ""

		end

	end

end



------------------------------------------------------------
-- CARD RENDER
------------------------------------------------------------

local function renderCard(
	methodId,
	methodState,
	state
)

	local card =
		cards:FindFirstChild(
			methodId
		)


	if not card then
		return
	end


	local status =
		card:FindFirstChild(
			"Status"
		)


	local detail =
		card:FindFirstChild(
			"Detail"
		)


	local button =
		card:FindFirstChild(
			"ApplyButton"
		)


	if not status
		or not detail
		or not button
	then

		return

	end



	------------------------------------------------
	-- APPLIED
	------------------------------------------------

	if methodState.Applied then

		status.Text =
			"ПРИМЕНЕНО"


		status.TextColor3 =
			GREEN


		button.Visible =
			false


		if methodId
			== "regression"
		then

			detail.Text =
				"Поля: A 20% • B 40% • C 10% • D 30%"


		elseif methodId
			== "tree"
		then

			local accuracy =
				state.RoutingAccuracy
				or 0


			detail.Text =
				"Точность маршрутизации: "
				..
				tostring(
					math.floor(
						accuracy
						* 100
						+ 0.5
					)
				)
				..
				"%"


		elseif methodId
			== "clustering"
		then

			detail.Text =
				"Когорты назначены на подходящие виды работ."

		end


		return

	end



	------------------------------------------------
	-- READY
	------------------------------------------------

	if methodState.Unlocked then

		status.Text =
			"ГОТОВО К ПРИМЕНЕНИЮ"


		status.TextColor3 =
			ORANGE


		button.Visible =
			true


		if methodId
			== "regression"
		then

			detail.Text =
				"Прогноз готов. Примените его к маршрутам сборщиков."


		elseif methodId
			== "tree"
		then

			detail.Text =
				"Сортировщик готов к подключению к производству."


		elseif methodId
			== "clustering"
		then

			detail.Text =
				"Когорты найдены. Примените распределение задач."

		end


		return

	end



	------------------------------------------------
	-- LOCKED
	------------------------------------------------

	status.Text =
		"ЗАБЛОКИРОВАНО"


	status.TextColor3 =
		DIM


	button.Visible =
		false


	if methodId
		== "regression"
	then

		detail.Text =
			"Сначала завершите уровень по регрессии."


	elseif methodId
		== "tree"
	then

		detail.Text =
			"Сначала завершите уровень с решающим деревом."


	elseif methodId
		== "clustering"
	then

		detail.Text =
			"Сначала завершите уровень по кластеризации."

	end

end



------------------------------------------------------------
-- REFRESH FROM SERVER
------------------------------------------------------------

local refreshing =
	false


local function refresh()

	if refreshing then
		return
	end


	if not overlay.Visible then
		return
	end


	refreshing =
		true


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
		and result.State
	then

		local state =
			result.State


		if state.Methods then

			renderCard(
				"regression",
				state.Methods.regression,
				state
			)


			renderCard(
				"tree",
				state.Methods.tree,
				state
			)


			renderCard(
				"clustering",
				state.Methods.clustering,
				state
			)

		end



		------------------------------------------------
		-- REMOVE STALE "ALREADY APPLIED" ERROR
		------------------------------------------------

		if string.find(
			string.lower(
				impact.Text or ""
			),
			"уже примен",
			1,
			true
		)
		then

			impact.Text =
				""

		end

	end


	refreshing =
		false

end



------------------------------------------------------------
-- HIVE WINDOW OPEN/CLOSE
------------------------------------------------------------

overlay:GetPropertyChangedSignal(
	"Visible"
)
:Connect(
	function()

		setFlowVisibility(
			overlay.Visible
		)


		if overlay.Visible then

			task.defer(
				refresh
			)

		end

	end
)



------------------------------------------------------------
-- ATTRIBUTE CHANGES
------------------------------------------------------------

local watchedAttributes = {

	"HiveMethodUnlocked_regression",

	"HiveMethodApplied_regression",

	"HiveMethodUnlocked_tree",

	"HiveMethodApplied_tree",

	"HiveMethodUnlocked_clustering",

	"HiveMethodApplied_clustering",

}


for _, attribute in ipairs(
	watchedAttributes
) do

	player:GetAttributeChangedSignal(
		attribute
	)
	:Connect(
		function()

			task.defer(
				refresh
			)

		end
	)

end



------------------------------------------------------------
-- PERIODIC SYNC
------------------------------------------------------------

task.spawn(
	function()

		while true do

			task.wait(
				0.4
			)


			if overlay.Visible then

				refresh()

			end

		end

	end
)



------------------------------------------------------------
-- INITIAL
------------------------------------------------------------

setFlowVisibility(
	overlay.Visible
)


print(
	"[HiveControlLiveSync] Ready"
)
