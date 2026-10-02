
local Players =
	game:GetService("Players")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


-- ============================================================
-- HELPERS
-- ============================================================

local function startsWith(
	text,
	prefix
)

	return
		string.sub(
			text,
			1,
			#prefix
		)
		==
		prefix

end


local function findTextObject(
	parent,
	test
)

	for _, object in ipairs(
		parent:GetDescendants()
	) do

		if
			(
				object:IsA("TextLabel")
				or
				object:IsA("TextButton")
			)
			and
			test(object)
		then

			return object

		end

	end


	return nil

end


-- ============================================================
-- PATCH LESSON CARD
-- ============================================================

local function patchLessonCard(
	hud
)

	local card =
		hud:FindFirstChild(
			"LessonCard",
			true
		)


	if not card
		or not card:IsA("Frame")
	then

		warn(
			"[KMeansUI] LessonCard not found"
		)

		return

	end


	-- Было около 430x300.
	-- Делаем компактнее и ниже.

	card.Position =
		UDim2.fromOffset(
			20,
			190
		)


	card.Size =
		UDim2.fromOffset(
			380,
			225
		)


	-- --------------------------------------------------------
	-- Ищем элементы внутри карточки по расположению.
	-- Это устойчивее, чем искать исходный код.
	-- --------------------------------------------------------

	local labels = {}


	for _, object in ipairs(
		card:GetChildren()
	) do

		if object:IsA("TextLabel") then

			table.insert(
				labels,
				object
			)

		end

	end


	table.sort(
		labels,

		function(a, b)

			return
				a.Position.Y.Offset
				<
				b.Position.Y.Offset

		end
	)


	-- Обычно:
	-- 1 = K-MEANS
	-- 2 = step
	-- 3 = task
	-- 4 = status

	if labels[1] then

		labels[1].Position =
			UDim2.fromOffset(
				18,
				10
			)

		labels[1].Size =
			UDim2.new(
				1,
				-36,
				0,
				28
			)

		labels[1].TextSize =
			22

	end


	if labels[2] then

		labels[2].Position =
			UDim2.fromOffset(
				18,
				40
			)

		labels[2].Size =
			UDim2.new(
				1,
				-36,
				0,
				26
			)

		labels[2].TextSize =
			17

	end


	if labels[3] then

		labels[3].Position =
			UDim2.fromOffset(
				18,
				72
			)

		labels[3].Size =
			UDim2.new(
				1,
				-36,
				0,
				72
			)

		labels[3].TextSize =
			18

	end


	if labels[4] then

		labels[4].Position =
			UDim2.fromOffset(
				18,
				145
			)

		labels[4].Size =
			UDim2.new(
				1,
				-36,
				0,
				30
			)

		labels[4].TextSize =
			15

	end


	-- --------------------------------------------------------
	-- Кнопки
	-- --------------------------------------------------------

	local buttons = {}


	for _, object in ipairs(
		card:GetChildren()
	) do

		if object:IsA("TextButton") then

			table.insert(
				buttons,
				object
			)

		end

	end


	-- Большая action-кнопка

	for _, button in ipairs(
		buttons
	) do

		if
			string.lower(
				button.Text
			)
			==
			"reset"
		then

			button.Position =
				UDim2.fromOffset(
					274,
					178
				)

			button.Size =
				UDim2.fromOffset(
					88,
					38
				)

			button.TextSize =
				14

		else

			button.Position =
				UDim2.fromOffset(
					18,
					178
				)

			button.Size =
				UDim2.fromOffset(
					245,
					38
				)

			button.TextSize =
				15

		end

	end

end


-- ============================================================
-- PATCH ASSIGNMENT MODAL
-- ============================================================

local function patchAssignmentModal(
	hud
)

	local modal =
		hud:FindFirstChild(
			"AssignmentModal",
			true
		)


	if not modal
		or not modal:IsA("Frame")
	then

		warn(
			"[KMeansUI] AssignmentModal not found"
		)

		return

	end


	-- ========================================================
	-- Главное:
	-- панель теперь внизу, а центр мира остаётся открытым.
	-- ========================================================

	modal.AnchorPoint =
		Vector2.new(
			0.5,
			1
		)


	modal.Position =
		UDim2.new(
			0.5,
			0,
			1,
			-24
		)


	modal.Size =
		UDim2.fromOffset(
			650,
			215
		)


	-- ========================================================
	-- TITLE
	-- ========================================================

	local title =
		findTextObject(
			modal,

			function(object)

				return
					object:IsA("TextLabel")
					and
					(
						startsWith(
							object.Text,
							"К какому"
						)
						or
						startsWith(
							object.Text,
							"Наблюдение"
						)
					)

			end
		)


	if title then

		title.Position =
			UDim2.fromOffset(
				22,
				10
			)

		title.Size =
			UDim2.new(
				1,
				-44,
				0,
				32
			)

		title.TextSize =
			22

	end


	-- ========================================================
	-- COORDINATES
	-- ========================================================

	local coords =
		findTextObject(
			modal,

			function(object)

				return
					object:IsA("TextLabel")
					and
					startsWith(
						object.Text,
						"x ="
					)

			end
		)


	if coords then

		coords.Position =
			UDim2.fromOffset(
				22,
				46
			)

		coords.Size =
			UDim2.fromOffset(
				180,
				28
			)

		coords.TextSize =
			17

	end


	-- ========================================================
	-- DISTANCES
	-- ========================================================

	local distances =
		findTextObject(
			modal,

			function(object)

				return
					object:IsA("TextLabel")
					and
					string.find(
						object.Text,
						"d²(A)",
						1,
						true
					)
					~= nil

			end
		)


	if distances then

		distances.Position =
			UDim2.fromOffset(
				205,
				45
			)

		distances.Size =
			UDim2.new(
				1,
				-225,
				0,
				31
			)

		distances.TextSize =
			19


		-- KMeansClient записывает значения
		-- двумя строками.
		-- Перестраиваем их в одну строку
		-- каждый раз после изменения текста.

		local changing =
			false


		local function flattenDistances()

			if changing then
				return
			end


			if
				string.find(
					distances.Text,
					"\n",
					1,
					true
				)
			then

				changing =
					true


				distances.Text =
					string.gsub(
						distances.Text,
						"\n",
						"        "
					)


				changing =
					false

			end

		end


		flattenDistances()


		distances
			:GetPropertyChangedSignal(
				"Text"
			)
			:Connect(
				flattenDistances
			)

	end


	-- ========================================================
	-- FEEDBACK
	-- ========================================================

	local feedback =
		findTextObject(
			modal,

			function(object)

				if
					not object:IsA(
						"TextLabel"
					)
				then

					return false

				end


				return
					startsWith(
						object.Text,
						"Сравни"
					)
					or
					startsWith(
						object.Text,
						"Выбери"
					)
					or
					startsWith(
						object.Text,
						"Не тот"
					)

			end
		)


	if feedback then

		feedback.Position =
			UDim2.fromOffset(
				22,
				79
			)

		feedback.Size =
			UDim2.new(
				1,
				-44,
				0,
				28
			)

		feedback.TextSize =
			15

	end


	-- ========================================================
	-- RED BUTTON
	-- ========================================================

	local red =
		findTextObject(
			modal,

			function(object)

				return
					object:IsA("TextButton")
					and
					string.find(
						string.upper(
							object.Text
						),
						"RED",
						1,
						true
					)
					~= nil

			end
		)


	if red then

		red.Position =
			UDim2.fromOffset(
				22,
				126
			)

		red.Size =
			UDim2.new(
				0.5,
				-33,
				0,
				62
			)

		red.TextSize =
			20

	end


	-- ========================================================
	-- BLUE BUTTON
	-- ========================================================

	local blue =
		findTextObject(
			modal,

			function(object)

				return
					object:IsA("TextButton")
					and
					string.find(
						string.upper(
							object.Text
						),
						"BLUE",
						1,
						true
					)
					~= nil

			end
		)


	if blue then

		blue.Position =
			UDim2.new(
				0.5,
				11,
				0,
				126
			)

		blue.Size =
			UDim2.new(
				0.5,
				-33,
				0,
				62
			)

		blue.TextSize =
			20

	end

end


-- ============================================================
-- APPLY
-- ============================================================

local patchedHuds = {}


local function patchHud(
	hud
)

	if
		not hud
		or
		patchedHuds[hud]
	then

		return

	end


	patchedHuds[hud] =
		true


	-- Иногда основной client ещё добавляет детей
	-- в этом же кадре.

	task.wait()


	patchLessonCard(
		hud
	)


	patchAssignmentModal(
		hud
	)


	print(
		"[KMeansUI] Compact UI applied"
	)

end


-- HUD уже существует

local current =
	playerGui
	:FindFirstChild(
		"KMeansHUD"
	)


if current then

	task.defer(
		patchHud,
		current
	)

end


-- HUD может быть создан позже,
-- когда LevelFlow включит KMeansClient.

playerGui.ChildAdded:Connect(
	function(child)

		if
			child.Name
			==
			"KMeansHUD"
		then

			task.delay(
				0.05,
				patchHud,
				child
			)

		end

	end
)

