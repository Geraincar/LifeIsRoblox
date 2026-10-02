local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("DBSCAN_Config"))
local Remotes = ReplicatedStorage:WaitForChild("DBSCAN_Remotes")

local beesFolder = Workspace:WaitForChild("DBSCANLevel"):WaitForChild("Bees")

-- ========== State ==========
local currentEpsilon = Config.DEFAULT_EPSILON
local currentAnalysis = nil
local epsilonCircle = nil
local highlightObjects = {}
local beamObjects = {}
local beeHighlights = {}
local clusterCards = {}
local classifiedCount = 0
local uiVisible = false

-- ========== UI Creation ==========

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DBSCAN_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ===== TOGGLE BUTTON (always visible) =====
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 140, 0, 40)
toggleBtn.Position = UDim2.new(1, -150, 1, -50)
toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 80, 140)
toggleBtn.Text = "🐝 Кластеры"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextScaled = true
toggleBtn.Parent = screenGui
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 10)
tc.Parent = toggleBtn
local ts = Instance.new("UIStroke")
ts.Color = Color3.fromRGB(80, 160, 255)
ts.Thickness = 2
ts.Transparency = 0.3
ts.Parent = toggleBtn

-- Helper function to create UI elements
local function makeFrame(parent, props)
	local f = Instance.new("Frame")
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function makeLabel(parent, props)
	local l = Instance.new("TextLabel")
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function makeButton(parent, props)
	local b = Instance.new("TextButton")
	for k, v in pairs(props) do
		b[k] = v
	end
	b.Parent = parent
	return b
end

local function addCorner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = obj
end

local function addStroke(obj, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0, 0, 0)
	s.Thickness = thickness or 1
	s.Transparency = 0.5
	s.Parent = obj
end

-- ===== TOP HUD: Epsilon & MinPts =====
local hudFrame = makeFrame(screenGui, {
	Size = UDim2.new(0, 400, 0, 80),
	Position = UDim2.new(0.5, -200, 0, 10),
	BackgroundColor3 = Color3.fromRGB(20, 25, 35),
	BackgroundTransparency = 0.1,
})
addCorner(hudFrame, 12)
addStroke(hudFrame, Color3.fromRGB(80, 160, 255), 2)

local epsLabel = makeLabel(hudFrame, {
	Size = UDim2.new(0, 120, 0, 30),
	Position = UDim2.new(0, 15, 0, 10),
	BackgroundTransparency = 1,
	Text = "Epsilon: " .. currentEpsilon,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local epsSlider = Instance.new("Frame")
epsSlider.Size = UDim2.new(0, 250, 0, 8)
epsSlider.Position = UDim2.new(0, 15, 0, 45)
epsSlider.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
epsSlider.Parent = hudFrame
addCorner(epsSlider, 4)

local epsFill = makeFrame(epsSlider, {
	Size = UDim2.new((currentEpsilon - Config.EPSILON_MIN) / (Config.EPSILON_MAX - Config.EPSILON_MIN), 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(80, 160, 255),
})
addCorner(epsFill, 4)

local epsKnob = makeFrame(epsSlider, {
	Size = UDim2.new(0, 16, 0, 16),
	Position = UDim2.new(epsFill.Size.X.Scale, -8, 0.5, -8),
	BackgroundColor3 = Color3.fromRGB(120, 180, 255),
})
addCorner(epsKnob, 8)

-- MinPts display
local minPtsLabel = makeLabel(hudFrame, {
	Size = UDim2.new(0, 100, 0, 30),
	Position = UDim2.new(0, 290, 0, 10),
	BackgroundTransparency = 1,
	Text = "MinPts: " .. Config.MIN_PTS,
	TextColor3 = Color3.fromRGB(255, 200, 100),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local progressLabel = makeLabel(hudFrame, {
	Size = UDim2.new(0, 100, 0, 25),
	Position = UDim2.new(0, 290, 0, 48),
	BackgroundTransparency = 1,
	Text = "0/16",
	TextColor3 = Color3.fromRGB(180, 255, 180),
	Font = Enum.Font.Gotham,
	TextScaled = true,
})

-- Epsilon slider drag logic
local dragging = false
epsSlider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
	end
end)
epsSlider.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
RunService.RenderStepped:Connect(function()
	if dragging then
		local mousePos = player:GetMouse().X
		local sliderPos = epsSlider.AbsolutePosition.X
		local sliderWidth = epsSlider.AbsoluteSize.X
		local pct = math.clamp((mousePos - sliderPos) / sliderWidth, 0, 1)
		currentEpsilon = math.floor(Config.EPSILON_MIN + pct * (Config.EPSILON_MAX - Config.EPSILON_MIN) + 0.5)
		epsFill.Size = UDim2.new(pct, 0, 1, 0)
		epsKnob.Position = UDim2.new(pct, -8, 0.5, -8)
		epsLabel.Text = "Epsilon: " .. currentEpsilon
		-- Update epsilon circle if visible
		if epsilonCircle then
			epsilonCircle.Size = Vector3.new(currentEpsilon * 2, 0.5, currentEpsilon * 2)
		end
	end
end)

-- ===== LEFT: Instructions Panel =====
local instrFrame = makeFrame(screenGui, {
	Size = UDim2.new(0, 280, 0, 250),
	Position = UDim2.new(0, 10, 0, 100),
	BackgroundColor3 = Color3.fromRGB(20, 25, 35),
	BackgroundTransparency = 0.1,
})
addCorner(instrFrame, 12)
addStroke(instrFrame, Color3.fromRGB(100, 200, 100), 2)

local instrTitle = makeLabel(instrFrame, {
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.new(0, 10, 0, 5),
	BackgroundTransparency = 1,
	Text = "Инструкция",
	TextColor3 = Color3.fromRGB(100, 255, 100),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local instrText = makeLabel(instrFrame, {
	Size = UDim2.new(1, -20, 0, 210),
	Position = UDim2.new(0, 10, 0, 35),
	BackgroundTransparency = 1,
	Text = "1. Нажмите на пчелу для анализа.\n2. Проверьте её соседей в радиусе Epsilon.\n3. Если похожих соседей >= MinPts (3) — это Core!\n4. Нажмите «Создать кластер» для Core-пчелы.\n5. Кластер автоматически расширится.\n6. Оставшиеся пчёлы без кластера — Шум.\n7. Нажмите на шумовую пчелу, чтобы отправить в улей.\n8. Нажмите «Проверить» когда закончите.",
	TextColor3 = Color3.fromRGB(220, 220, 220),
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
instrText.TextSize = 13

-- ===== RIGHT: Clusters Panel =====
local clustersFrame = makeFrame(screenGui, {
	Size = UDim2.new(0, 280, 0, 300),
	Position = UDim2.new(1, -290, 0, 100),
	BackgroundColor3 = Color3.fromRGB(20, 25, 35),
	BackgroundTransparency = 0.1,
})
addCorner(clustersFrame, 12)
addStroke(clustersFrame, Color3.fromRGB(200, 150, 255), 2)

local clustersTitle = makeLabel(clustersFrame, {
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.new(0, 10, 0, 5),
	BackgroundTransparency = 1,
	Text = "Кластеры",
	TextColor3 = Color3.fromRGB(200, 150, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local clustersScroll = Instance.new("ScrollingFrame")
clustersScroll.Size = UDim2.new(1, -20, 0, 255)
clustersScroll.Position = UDim2.new(0, 10, 0, 35)
clustersScroll.BackgroundTransparency = 1
clustersScroll.ScrollBarThickness = 4
clustersScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
clustersScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
clustersScroll.Parent = clustersFrame

local clustersList = Instance.new("UIListLayout")
clustersList.Padding = UDim.new(0, 6)
clustersList.Parent = clustersScroll

-- ===== BOTTOM: Action Buttons =====
local checkBtn = makeButton(screenGui, {
	Size = UDim2.new(0, 200, 0, 45),
	Position = UDim2.new(0.5, -100, 1, -60),
	BackgroundColor3 = Color3.fromRGB(40, 150, 80),
	Text = "Проверить завершение",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})
addCorner(checkBtn, 10)

local resetBtn = makeButton(screenGui, {
	Size = UDim2.new(0, 120, 0, 35),
	Position = UDim2.new(0, 10, 1, -50),
	BackgroundColor3 = Color3.fromRGB(80, 60, 60),
	Text = "Сброс",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.Gotham,
	TextScaled = true,
})
addCorner(resetBtn, 8)

-- ===== Toggleable UI elements: hide by default =====
local toggleableElements = { hudFrame, instrFrame, clustersFrame, checkBtn, resetBtn }
for _, el in ipairs(toggleableElements) do
	el.Visible = false
end

-- ===== Analysis Result Panel =====
local analysisPanel = makeFrame(screenGui, {
	Size = UDim2.new(0, 350, 0, 0),
	Position = UDim2.new(0.5, -175, 1, 10),
	BackgroundColor3 = Color3.fromRGB(20, 25, 35),
	BackgroundTransparency = 0.05,
	Visible = false,
})
addCorner(analysisPanel, 12)
addStroke(analysisPanel, Color3.fromRGB(255, 200, 100), 2)

local analysisTitle = makeLabel(analysisPanel, {
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.new(0, 10, 0, 5),
	BackgroundTransparency = 1,
	Text = "Анализ пчелы",
	TextColor3 = Color3.fromRGB(255, 200, 100),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local analysisInfo = makeLabel(analysisPanel, {
	Size = UDim2.new(1, -20, 0, 80),
	Position = UDim2.new(0, 10, 0, 35),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(220, 220, 220),
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
analysisInfo.TextSize = 13

local createClusterBtn = makeButton(analysisPanel, {
	Size = UDim2.new(1, -20, 0, 35),
	Position = UDim2.new(0, 10, 0, 120),
	BackgroundColor3 = Color3.fromRGB(40, 120, 200),
	Text = "Создать кластер",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Visible = false,
})
addCorner(createClusterBtn, 8)

local sendNoiseBtn = makeButton(analysisPanel, {
	Size = UDim2.new(1, -20, 0, 35),
	Position = UDim2.new(0, 10, 0, 120),
	BackgroundColor3 = Color3.fromRGB(180, 60, 60),
	Text = "Отправить в улей (Шум)",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Visible = false,
})
addCorner(sendNoiseBtn, 8)

-- ===== Educational Panel =====
local eduPanel = makeFrame(screenGui, {
	Size = UDim2.new(0, 450, 0, 0),
	Position = UDim2.new(0.5, -225, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(15, 20, 30),
	BackgroundTransparency = 0.03,
	Visible = false,
})
addCorner(eduPanel, 14)
addStroke(eduPanel, Color3.fromRGB(100, 180, 255), 3)

local eduTitle = makeLabel(eduPanel, {
	Size = UDim2.new(1, -50, 0, 35),
	Position = UDim2.new(0, 15, 0, 10),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(100, 180, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local eduCloseBtn = makeButton(eduPanel, {
	Size = UDim2.new(0, 30, 0, 30),
	Position = UDim2.new(1, -40, 0, 10),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60),
	Text = "X",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})
addCorner(eduCloseBtn, 6)

local eduText = makeLabel(eduPanel, {
	Size = UDim2.new(1, -30, 0, 200),
	Position = UDim2.new(0, 15, 0, 45),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(200, 200, 200),
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
eduText.TextSize = 14

local eduContinueBtn = makeButton(eduPanel, {
	Size = UDim2.new(0, 150, 0, 35),
	Position = UDim2.new(0.5, -75, 1, -45),
	BackgroundColor3 = Color3.fromRGB(50, 100, 180),
	Text = "Понятно",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})
addCorner(eduContinueBtn, 8)

-- Educational content
local eduContent = {
	intro = {
		title = "DBSCAN — Кластеризация по плотности",
		text = "DBSCAN — это алгоритм, который находит плотные группы объектов.\n\nДва ключевых параметра:\n• Epsilon (ε) — радиус поиска соседей вокруг каждой точки.\n• MinPts — минимальное число точек внутри ε, чтобы образовать плотную группу.\n\nВ нашем случае: ε = радиус радара, MinPts = 3.\n\nКоличество кластеров заранее НЕИЗВЕСТНО — вы должны найти их сами!",
		height = 280,
	},
	core = {
		title = "Core / Ядро",
		text = "Точка считается Ядром (Core), если внутри радиуса ε находится не менее MinPts похожих соседей.\n\nCore-пчела становится центром нового кластера. Кластер начинает расти от неё.\n\nВ нашем случае: если внутри круга радара есть 3+ пчёл того же таланта — это Core!",
		height = 200,
	},
	border = {
		title = "Border / Граница",
		text = "Точка считается Границей (Border), если она находится внутри ε-радиуса Core-точки, но сама не имеет достаточно соседей (меньше MinPts), чтобы стать Core.\n\nBorder-пчёлы присоединяются к кластеру, но НЕ расширяют его дальше.",
		height = 180,
	},
	noise = {
		title = "Noise / Шум / Выброс",
		text = "Точка считается Шумом (Noise), если она:\n• не является Core\n• не является Border (не входит в ε-радиус любого Core)\n• не принадлежит ни одному кластеру\n\nТакие пчёлы — аномалии. Их нужно отправить обратно в улей.",
		height = 180,
	},
	final = {
		title = "DBSCAN — Итоги и пример кода",
		text = "Вы прошли кластеризацию DBSCAN!\n\nКлючевые выводы:\n• Кластеры — это плотные группы, а не ближайшие к центру.\n• Количество кластеров определяется автоматически.\n• Шум (выбросы) определяется естественно.\n\nПример на Python:\nfrom sklearn.cluster import DBSCAN\nimport numpy as np\n\nX = np.array([[x1,y1], [x2,y2], ...])\ndb = DBSCAN(eps=12, min_samples=3)\nlabels = db.fit_predict(X)\n# labels: 0,0,0,0, 1,1,1,1, 2,2,2, -1,-1,-1,-1\n# (номера кластеров, -1 = шум)",
		height = 320,
	},
}

local function showEduPanel(panelId)
	local content = eduContent[panelId]
	if not content then return end
	eduTitle.Text = content.title
	eduText.Text = content.text
	eduPanel.Size = UDim2.new(0, 450, 0, content.height)
	eduPanel.Position = UDim2.new(0.5, -225, 0.5, -content.height / 2)
	eduPanel.Visible = true
end

eduCloseBtn.MouseButton1Click:Connect(function()
	eduPanel.Visible = false
end)
eduContinueBtn.MouseButton1Click:Connect(function()
	eduPanel.Visible = false
end)

-- ===== Final Result Panel =====
local resultPanel = makeFrame(screenGui, {
	Size = UDim2.new(0, 400, 0, 250),
	Position = UDim2.new(0.5, -200, 0.5, -125),
	BackgroundColor3 = Color3.fromRGB(15, 20, 30),
	BackgroundTransparency = 0.03,
	Visible = false,
})
addCorner(resultPanel, 14)
addStroke(resultPanel, Color3.fromRGB(100, 255, 100), 3)

local resultTitle = makeLabel(resultPanel, {
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.new(0, 0, 0, 15),
	BackgroundTransparency = 1,
	Text = "Уровень пройден!",
	TextColor3 = Color3.fromRGB(100, 255, 100),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local resultText = makeLabel(resultPanel, {
	Size = UDim2.new(1, -40, 0, 130),
	Position = UDim2.new(0, 20, 0, 60),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(220, 220, 220),
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
resultText.TextSize = 16

local resultCloseBtn = makeButton(resultPanel, {
	Size = UDim2.new(0, 150, 0, 40),
	Position = UDim2.new(0.5, -75, 1, -50),
	BackgroundColor3 = Color3.fromRGB(50, 100, 180),
	Text = "Закрыть",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})
addCorner(resultCloseBtn, 8)

resultCloseBtn.MouseButton1Click:Connect(function()
	resultPanel.Visible = false
end)

-- ===== Cluster Naming Dialog =====
local nameDialog = makeFrame(screenGui, {
	Size = UDim2.new(0, 300, 0, 130),
	Position = UDim2.new(0.5, -150, 0.5, -65),
	BackgroundColor3 = Color3.fromRGB(20, 25, 35),
	BackgroundTransparency = 0.05,
	Visible = false,
})
addCorner(nameDialog, 12)
addStroke(nameDialog, Color3.fromRGB(200, 150, 255), 2)

local nameInputLabel = makeLabel(nameDialog, {
	Size = UDim2.new(1, -20, 0, 25),
	Position = UDim2.new(0, 10, 0, 10),
	BackgroundTransparency = 1,
	Text = "Название для кластера:",
	TextColor3 = Color3.fromRGB(200, 150, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})

local nameInput = Instance.new("TextBox")
nameInput.Size = UDim2.new(1, -20, 0, 35)
nameInput.Position = UDim2.new(0, 10, 0, 40)
nameInput.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
nameInput.Font = Enum.Font.Gotham
nameInput.TextSize = 16
nameInput.PlaceholderText = "Например: Няньки"
nameInput.Parent = nameDialog
addCorner(nameInput, 8)

local nameSubmitBtn = makeButton(nameDialog, {
	Size = UDim2.new(0, 120, 0, 30),
	Position = UDim2.new(0.5, -60, 1, -40),
	BackgroundColor3 = Color3.fromRGB(50, 120, 200),
	Text = "OK",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
})
addCorner(nameSubmitBtn, 8)

local namingClusterId = nil
nameSubmitBtn.MouseButton1Click:Connect(function()
	if namingClusterId and #nameInput.Text > 0 then
		Remotes.NameCluster:FireServer(namingClusterId, nameInput.Text)
	end
	nameDialog.Visible = false
	nameInput.Text = ""
end)

-- ========== Visualization Functions ==========

local function clearHighlights()
	for _, hl in pairs(highlightObjects) do
		hl:Destroy()
	end
	highlightObjects = {}
	for _, beam in pairs(beamObjects) do
		beam:Destroy()
	end
	beamObjects = {}
end

local function clearEpsilonCircle()
	if epsilonCircle then
		epsilonCircle:Destroy()
		epsilonCircle = nil
	end
end

local function createEpsilonCircle(position, radius)
	clearEpsilonCircle()
	local circle = Instance.new("Part")
	circle.Name = "EpsilonCircle"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.3, radius * 2, radius * 2)
	circle.Position = position
	circle.Orientation = Vector3.new(0, 0, 90)
	circle.Anchored = true
	circle.CanCollide = false
	circle.Material = Enum.Material.ForceField
	circle.Color = Color3.fromRGB(100, 180, 255)
	circle.Transparency = 0.7
	circle.Parent = Workspace
	epsilonCircle = circle
end

local function highlightBee(bee, color, fillTransparency)
	local hl = Instance.new("Highlight")
	hl.Adornee = bee
	hl.FillColor = color
	hl.OutlineColor = color
	hl.FillTransparency = fillTransparency or 0.7
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = bee
	table.insert(highlightObjects, hl)
end

local function createBeam(fromBee, toBee, color)
	local a0 = Instance.new("Attachment")
	a0.Parent = fromBee
	local a1 = Instance.new("Attachment")
	a1.Parent = toBee
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.3)
	beam.Parent = fromBee
	table.insert(beamObjects, beam)
	table.insert(beamObjects, a0)
	table.insert(beamObjects, a1)
end

-- Apply persistent cluster color to a bee
local function applyClusterVisual(bee, clusterColor, isCore)
	-- Remove old highlight
	local oldHl = bee:FindFirstChild("ClusterHighlight")
	if oldHl then oldHl:Destroy() end
	
	local hl = Instance.new("Highlight")
	hl.Name = "ClusterHighlight"
	hl.Adornee = bee
	hl.FillColor = clusterColor
	hl.OutlineColor = clusterColor
	hl.FillTransparency = isCore and 0.3 or 0.6
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = bee
	
	-- Add Core/Border marker
	local oldMarker = bee:FindFirstChild("StateMarker")
	if oldMarker then oldMarker:Destroy() end
	
	local marker = Instance.new("Part")
	marker.Name = "StateMarker"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(0.6, 0.6, 0.6)
	marker.Position = bee.Position + Vector3.new(0, 2.2, 0)
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = isCore and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(200, 200, 200)
	marker.Transparency = isCore and 0 or 0.3
	marker.Parent = bee
	
	-- BillboardGui for state label
	local bb = Instance.new("BillboardGui")
	bb.Name = "StateLabel"
	bb.Size = UDim2.new(0, 60, 0, 20)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = bee
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = isCore and "CORE" or "BORDER"
	lbl.TextColor3 = isCore and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(200, 200, 200)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = bb
end

local function applyNoiseVisual(bee)
	local oldHl = bee:FindFirstChild("ClusterHighlight")
	if oldHl then oldHl:Destroy() end
	local oldMarker = bee:FindFirstChild("StateMarker")
	if oldMarker then oldMarker:Destroy() end
	local oldLabel = bee:FindFirstChild("StateLabel")
	if oldLabel then oldLabel:Destroy() end
	
	local hl = Instance.new("Highlight")
	hl.Name = "ClusterHighlight"
	hl.Adornee = bee
	hl.FillColor = Color3.fromRGB(255, 50, 50)
	hl.OutlineColor = Color3.fromRGB(255, 50, 50)
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = bee
	
	local bb = Instance.new("BillboardGui")
	bb.Name = "StateLabel"
	bb.Size = UDim2.new(0, 60, 0, 20)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = bee
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "ШУМ"
	lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = bb
end

local function removeBeeVisuals(bee)
	local hl = bee:FindFirstChild("ClusterHighlight")
	if hl then hl:Destroy() end
	local marker = bee:FindFirstChild("StateMarker")
	if marker then marker:Destroy() end
	local label = bee:FindFirstChild("StateLabel")
	if label then label:Destroy() end
end

-- ========== Cluster Card Creation ==========
local function createClusterCard(clusterInfo)
	local card = makeFrame(clustersScroll, {
		Size = UDim2.new(1, -4, 0, 90),
		BackgroundColor3 = Color3.fromRGB(30, 35, 45),
	})
	addCorner(card, 8)
	
	local colorDot = makeFrame(card, {
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = clusterInfo.color,
	})
	addCorner(colorDot, 10)
	
	local nameLbl = makeLabel(card, {
		Size = UDim2.new(1, -80, 0, 20),
		Position = UDim2.new(0, 35, 0, 5),
		BackgroundTransparency = 1,
		Text = clusterInfo.name,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	
	local nameBtn = makeButton(card, {
		Size = UDim2.new(0, 35, 0, 20),
		Position = UDim2.new(1, -43, 0, 5),
		BackgroundColor3 = Color3.fromRGB(50, 80, 120),
		Text = "✏",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.Gotham,
		TextScaled = true,
	})
	addCorner(nameBtn, 4)
	nameBtn.MouseButton1Click:Connect(function()
		namingClusterId = clusterInfo.id
		nameDialog.Visible = true
		nameInput.Text = clusterInfo.name ~= ("Кластер " .. clusterInfo.id) and clusterInfo.name or ""
	end)
	
	local statsLbl = makeLabel(card, {
		Size = UDim2.new(1, -16, 0, 45),
		Position = UDim2.new(0, 8, 0, 30),
		BackgroundTransparency = 1,
		Text = "Core: " .. #clusterInfo.coreBeeIds .. " | Border: " .. #clusterInfo.borderBeeIds,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	statsLbl.TextSize = 12
	
	clusterCards[clusterInfo.id] = { card = card, nameLbl = nameLbl, statsLbl = statsLbl }
	
	-- Auto-resize scrolling canvas
	clustersScroll.CanvasSize = UDim2.new(0, 0, 0, clustersScroll.UIListLayout.AbsoluteContentSize.Y)
end

-- ========== Update Progress ==========
local function updateProgress()
	local count = 0
	for _, bee in beesFolder:GetChildren() do
		if bee:IsA("BasePart") and bee:GetAttribute("BeeId") then
			local state = bee:GetAttribute("BeeState")
			if state == "Core" or state == "Border" or state == "Sent" then
				count += 1
			end
		end
	end
	classifiedCount = count
	progressLabel.Text = count .. "/16"
end

-- ========== Bee Click Handling ==========
local function getBeeById(id)
	for _, bee in beesFolder:GetChildren() do
		if bee:IsA("BasePart") and bee:GetAttribute("BeeId") == id then
			return bee
		end
	end
	return nil
end

for _, bee in beesFolder:GetChildren() do
	if bee:IsA("BasePart") and bee:FindFirstChild("BeeClick") then
		local cd = bee.BeeClick
		cd.MouseClick:Connect(function(clicker)
			if clicker ~= player then return end
			local beeId = bee:GetAttribute("BeeId")
			if bee:GetAttribute("BeeState") == "Sent" then return end
			Remotes.AnalyzeBee:FireServer(beeId, nil, currentEpsilon)
		end)
	end
end

-- Handle bees added later (e.g. after reset)
beesFolder.ChildAdded:Connect(function(bee)
	if bee:IsA("BasePart") and bee:FindFirstChild("BeeClick") then
		bee.BeeClick.MouseClick:Connect(function(clicker)
			if clicker ~= player then return end
			local beeId = bee:GetAttribute("BeeId")
			if bee:GetAttribute("BeeState") == "Sent" then return end
			Remotes.AnalyzeBee:FireServer(beeId, nil, currentEpsilon)
		end)
	end
end)

-- ========== Server Event Handlers ==========

-- Analysis Result
Remotes.BeeAnalysisResult.OnClientEvent:Connect(function(data)
	clearHighlights()
	clearEpsilonCircle()
	currentAnalysis = data
	
	local bee = getBeeById(data.beeId)
	if not bee then return end
	
	-- Create epsilon circle around the bee
	createEpsilonCircle(Vector3.new(data.beePosition[1], data.beePosition[2], data.beePosition[3]), data.epsilon)
	
	-- Highlight the selected bee
	highlightBee(bee, Color3.fromRGB(255, 255, 255), 0.5)
	
	-- Highlight neighbors
	local similarCount = 0
	for _, nInfo in ipairs(data.neighbors) do
		local nBee = getBeeById(nInfo.id)
		if nBee then
			if nInfo.isSimilar then
				highlightBee(nBee, Color3.fromRGB(50, 255, 50), 0.6)
				similarCount += 1
			else
				highlightBee(nBee, Color3.fromRGB(255, 50, 50), 0.6)
			end
		end
	end
	
	-- Update analysis panel
	local stateText = ""
	if data.currentState == "Core" then
		stateText = "\nСтатус: CORE (Ядро)\nКластер #" .. data.clusterId
	elseif data.currentState == "Border" then
		stateText = "\nСтатус: BORDER (Граница)\nКластер #" .. data.clusterId
	elseif data.currentState == "Noise" then
		stateText = "\nСтатус: ШУМ"
	else
		stateText = "\nСтатус: Не определена"
	end
	
	analysisInfo.Text = string.format(
		"Тип: %s\nСоседей в радиусе: %d\nПохожих соседей: %d\nMinPts: %d\nЯдро? %s%s",
		data.typeName,
		data.totalNeighbors,
		data.similarNeighbors,
		Config.MIN_PTS,
		data.isCore and "ДА" or "НЕТ",
		stateText
	)
	
	-- Show appropriate buttons
	if data.currentState == "Unassigned" or data.currentState == "Noise" then
		if data.isCore then
			createClusterBtn.Visible = true
			sendNoiseBtn.Visible = false
			analysisPanel.Size = UDim2.new(0, 350, 0, 170)
		else
			createClusterBtn.Visible = false
			sendNoiseBtn.Visible = true
			analysisPanel.Size = UDim2.new(0, 350, 0, 170)
		end
	elseif data.currentState == "Noise" then
		createClusterBtn.Visible = false
		sendNoiseBtn.Visible = true
		analysisPanel.Size = UDim2.new(0, 350, 0, 170)
	else
		createClusterBtn.Visible = false
		sendNoiseBtn.Visible = false
		analysisPanel.Size = UDim2.new(0, 350, 0, 125)
	end
	
	analysisPanel.Position = UDim2.new(0.5, -175, 1, -analysisPanel.Size.Y.Offset - 20)
	analysisPanel.Visible = true
end)

-- Create Cluster button handler
createClusterBtn.MouseButton1Click:Connect(function()
	if currentAnalysis then
		Remotes.AnalyzeBee:FireServer(currentAnalysis.beeId, "confirm", currentEpsilon)
		createClusterBtn.Visible = false
	end
end)

-- Send Noise button handler
sendNoiseBtn.MouseButton1Click:Connect(function()
	if currentAnalysis then
		Remotes.SendNoiseBee:FireServer(currentAnalysis.beeId)
		sendNoiseBtn.Visible = false
		analysisPanel.Visible = false
		clearHighlights()
		clearEpsilonCircle()
	end
end)

-- Cluster Created
Remotes.ClusterCreated.OnClientEvent:Connect(function(clusterInfo)
	-- Create cluster card
	createClusterCard(clusterInfo)
	
	-- Apply visual to all bees in cluster
	local color = clusterInfo.color
	for _, beeId in ipairs(clusterInfo.coreBeeIds) do
		local bee = getBeeById(beeId)
		if bee then
			applyClusterVisual(bee, color, true)
		end
	end
	for _, beeId in ipairs(clusterInfo.borderBeeIds) do
		local bee = getBeeById(beeId)
		if bee then
			applyClusterVisual(bee, color, false)
		end
	end
	
	-- Draw beams between core bees
	for i = 1, #clusterInfo.coreBeeIds - 1 do
		local bee1 = getBeeById(clusterInfo.coreBeeIds[i])
		local bee2 = getBeeById(clusterInfo.coreBeeIds[i + 1])
		if bee1 and bee2 then
			createBeam(bee1, bee2, color)
		end
	end
	
	updateProgress()
	analysisPanel.Visible = false
	clearHighlights()
	clearEpsilonCircle()
end)

-- Bee State Update
Remotes.BeeStateUpdate.OnClientEvent:Connect(function(beeId, state, clusterId)
	local bee = getBeeById(beeId)
	if bee then
		bee:SetAttribute("BeeState", state)
		bee:SetAttribute("ClusterId", clusterId)
		if state == "Noise" then
			applyNoiseVisual(bee)
		elseif state == "Sent" then
			removeBeeVisuals(bee)
		end
		updateProgress()
	end
end)

-- Noise Sent
Remotes.NoiseSent.OnClientEvent:Connect(function(beeId)
	local bee = getBeeById(beeId)
	if bee then
		removeBeeVisuals(bee)
	end
	updateProgress()
end)

-- Cluster Named
Remotes.ClusterNamed.OnClientEvent:Connect(function(clusterId, name)
	local card = clusterCards[clusterId]
	if card then
		card.nameLbl.Text = name
	end
end)

-- Show Educational Panel
Remotes.ShowEduPanel.OnClientEvent:Connect(function(panelId)
	showEduPanel(panelId)
end)

-- Check Complete button
checkBtn.MouseButton1Click:Connect(function()
	Remotes.CheckComplete:FireServer()
end)

-- Level Complete
Remotes.LevelComplete.OnClientEvent:Connect(function(data)
	if data.complete then
		resultTitle.Text = "Уровень пройден! 🐝"
		resultTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
		resultText.Text = string.format(
			"Найдено кластеров: %d\nCore-пчёл: %d\nBorder-пчёл: %d\nШумовых пчёл отправлено: %d",
			data.clustersFound, data.coreCount, data.borderCount, data.noiseSent
		)
		resultPanel.Visible = true
		-- Show final educational panel
		showEduPanel("final")
	else
		resultTitle.Text = "Ещё не всё..."
		resultTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
		local msg = ""
		if data.unassigned > 0 then
			msg = msg .. "Не определено пчёл: " .. data.unassigned .. "\n"
		end
		if data.noiseNotSent > 0 then
			msg = msg .. "Шумовых пчёл не отправлено: " .. data.noiseNotSent .. "\n"
		end
		msg = msg .. "\nПродолжайте исследование!"
		resultText.Text = msg
		resultPanel.Visible = true
	end
end)

-- Reset button
resetBtn.MouseButton1Click:Connect(function()
	Remotes.ResetLevel:FireServer()
end)

-- Level Reset
Remotes.LevelReset.OnClientEvent:Connect(function()
	-- Clear all visuals
	clearHighlights()
	clearEpsilonCircle()
	for _, bee in beesFolder:GetChildren() do
		if bee:IsA("BasePart") then
			removeBeeVisuals(bee)
		end
	end
	-- Clear cluster cards
	for id, card in pairs(clusterCards) do
		card.card:Destroy()
	end
	clusterCards = {}
	classifiedCount = 0
	progressLabel.Text = "0/16"
	analysisPanel.Visible = false
	resultPanel.Visible = false
	eduPanel.Visible = false
end)

-- ===== Toggle Button Handler (at end so all vars are in scope) =====
toggleBtn.MouseButton1Click:Connect(function()
	uiVisible = not uiVisible
	for _, el in ipairs(toggleableElements) do
		el.Visible = uiVisible
	end
	toggleBtn.Text = uiVisible and "🐝 Скрыть" or "🐝 Кластеры"
	toggleBtn.BackgroundColor3 = uiVisible and Color3.fromRGB(140, 60, 60) or Color3.fromRGB(35, 80, 140)
	-- If hiding, also clear analysis visuals
	if not uiVisible then
		clearHighlights()
		clearEpsilonCircle()
		analysisPanel.Visible = false
	end
end)

-- Initialize
updateProgress()
print("[DBSCAN_RadarClient] Client initialized")