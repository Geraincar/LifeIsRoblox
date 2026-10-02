local Players =
	game:GetService("Players")

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

--------------------------------------------------
-- SUBLEVEL NAMES
--------------------------------------------------

local SUBLEVEL_NAMES = {

	[1] = "Решающее дерево",

	[2] = "Энтропия",

	[3] = "Индекс Джини",

	[4] = "F1 и Макро-F1",

}

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

local screenGui =
	Instance.new("ScreenGui")

screenGui.Name =
	"TreeLevelUI"

screenGui.ResetOnSpawn =
	false

screenGui.DisplayOrder =
	50

screenGui.Parent =
	playerGui

--------------------------------------------------
-- SUBLEVEL LABEL
--------------------------------------------------

local sublevelLabel =
	Instance.new("TextLabel")

sublevelLabel.Name =
	"SublevelLabel"

sublevelLabel.AnchorPoint =
	Vector2.new(0.5, 0)

sublevelLabel.Position =
	UDim2.new(
		0.5, 0,
		0, 6
	)

sublevelLabel.Size =
	UDim2.new(
		0, 380,
		0, 36
	)

sublevelLabel.BackgroundColor3 =
	Color3.fromRGB(
		25,
		25,
		35
	)

sublevelLabel.BackgroundTransparency =
	0.15

sublevelLabel.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

sublevelLabel.Font =
	Enum.Font.GothamBold

sublevelLabel.TextScaled = false
sublevelLabel.TextSize = 20
sublevelLabel.TextWrapped =
	true

sublevelLabel.TextStrokeTransparency =
	0.7

sublevelLabel.Visible =
	false

sublevelLabel.Parent =
	screenGui

local sublevelCorner =
	Instance.new("UICorner")

sublevelCorner.CornerRadius =
	UDim.new(0, 10)

sublevelCorner.Parent =
	sublevelLabel

--------------------------------------------------
-- LEVEL COMPLETE LABEL
--------------------------------------------------

local completeLabel =
	Instance.new("TextLabel")

completeLabel.Name =
	"LevelCompleteLabel"

completeLabel.AnchorPoint =
	Vector2.new(0.5, 0)

completeLabel.Position =
	UDim2.new(
		0.5, 0,
		0, 25
	)

completeLabel.Size =
	UDim2.new(
		0, 520,
		0, 54
	)

completeLabel.BackgroundColor3 =
	Color3.fromRGB(
		20,
		45,
		25
	)

completeLabel.BackgroundTransparency =
	0.15

completeLabel.Text =
	"УРОВЕНЬ ПРОЙДЕН"

completeLabel.TextColor3 =
	Color3.fromRGB(
		70,
		255,
		110
	)

completeLabel.Font =
	Enum.Font.GothamBold

completeLabel.TextScaled =
	true

completeLabel.TextStrokeTransparency =
	0.7

completeLabel.Visible =
	false

completeLabel.Parent =
	screenGui

local completeCorner =
	Instance.new("UICorner")

completeCorner.CornerRadius =
	UDim.new(0, 10)

completeCorner.Parent =
	completeLabel

--------------------------------------------------
-- CURRENT SUBLEVEL
--------------------------------------------------

local currentSublevel = 0

--------------------------------------------------
-- CANCEL SUBLEVEL
--------------------------------------------------

local function cancelCurrentSublevel()

	if currentSublevel > 0 then

		print(
			"[TreeLevel] Stop:",
			SUBLEVEL_NAMES[currentSublevel]
		)

	end

	currentSublevel = 0
end

--------------------------------------------------
-- START SUBLEVEL
--------------------------------------------------

local function startSublevel(index)

	currentSublevel = index

	print(
		"[TreeLevel] START:",
		index,
		SUBLEVEL_NAMES[index]
	)

	--------------------------------------------------
	-- Здесь позже подключим настоящую
	-- механику каждого подуровня.
	--------------------------------------------------

	if index == 1 then

		-- Решающее дерево

	elseif index == 2 then

		-- Энтропия

	elseif index == 3 then

		-- Индекс Джини

	elseif index == 4 then

		-- F1 и Макро-F1

	end
end

--------------------------------------------------
-- UPDATE STATE
--------------------------------------------------

local function updateState()

	local isInside =
		player:GetAttribute(
			"TreeLevelInside"
		) == true

	local completed =
		player:GetAttribute(
			"TreeLevelProgress"
		) or 0

	local active =
		player:GetAttribute(
			"TreeLevelActiveSublevel"
		) or 0

	--------------------------------------------------
	-- OUTSIDE ZONE
	--------------------------------------------------

	if not isInside then

		sublevelLabel.Visible =
			false

		completeLabel.Visible =
			false

		cancelCurrentSublevel()

		return
	end

	--------------------------------------------------
	-- LEVEL COMPLETED
	--------------------------------------------------

	if completed >= 4 then

		cancelCurrentSublevel()

		sublevelLabel.Visible =
			false

		completeLabel.Text =
			"УРОВЕНЬ ПРОЙДЕН"

		completeLabel.Visible =
			true

		return
	end

	--------------------------------------------------
	-- LEVEL IN PROGRESS
	--------------------------------------------------

	completeLabel.Visible =
		false

	if active > 0 then

		sublevelLabel.Text =
			SUBLEVEL_NAMES[active]
			or ("Подуровень " .. active)

		sublevelLabel.Visible =
			true

	else

		sublevelLabel.Visible =
			false

	end

	--------------------------------------------------
	-- START NEW SUBLEVEL
	--------------------------------------------------

	if active > 0
		and active ~= currentSublevel then

		cancelCurrentSublevel()

		startSublevel(active)

	end
end

--------------------------------------------------
-- ATTRIBUTE WATCHERS
--------------------------------------------------

player:GetAttributeChangedSignal(
	"TreeLevelInside"
):Connect(updateState)

player:GetAttributeChangedSignal(
	"TreeLevelProgress"
):Connect(updateState)

player:GetAttributeChangedSignal(
	"TreeLevelActiveSublevel"
):Connect(updateState)

task.defer(updateState)