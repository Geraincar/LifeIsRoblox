--!nonstrict
-- RegressionClient: точка входа модуля «Регрессия» (3D experience → 2D experience → лор-задача).
-- Всё обучение — на клиенте: клумба, табло, экраны и пасека создаются локально, у каждого игрока свои.
-- Где строить (общая карта SkRob): Workspace/RegressionLevel/FlowerbedAnchor и …/LoreAnchor
--   (низ детали — земля; локальная +Z детали смотрит туда, откуда приходит игрок). Высота уточняется лучом вниз;
--   если земля ещё не подгрузилась (StreamingEnabled), остаётся низ якоря.
-- Клумба и пасека строятся сразу при входе в игру и видны всегда. Площадки в SkRob стримятся (StreamingEnabled),
--   поэтому их CFrame/Size берутся из атрибутов папки RegressionLevel (их ставит сервер, RegressionLevelServer) —
--   без ожидания; если атрибутов нет — из самих деталей, а если и их нет — из Core/LevelLayout.
-- Кнопки квестов модуля (подсказки F, HUD, пульт, экран 2D) работают, только когда уровень активен:
--   игрок внутри куба Workspace/RegressionLevel/RegressionZone и (если в месте есть LevelFlow) ActiveLevel = "regression".
-- Прогресс: вехи regression_3d / regression_2d / regression_lore → RemoteEvent ReplicatedStorage.Remotes.RegressionProgress.
-- В Studio: _G.RegressionDebug.goto("2D.4") — перейти к шагу (для проверки экранов без прохождения).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regression = ReplicatedStorage:WaitForChild("Regression")
local MathCore = require(Regression.MathCore)
local Datasets = require(Regression.Data.Datasets)
local Config = require(Regression.Core.Config)
local Layout = require(Regression.Core.LevelLayout)
local Store = require(Regression.Core.Store)
local LineModel = require(Regression.Core.LineModel)
local Hud = require(Regression.UI.Hud)
local Shell2D = require(Regression.UI.Shell2D)
local Strings = require(Regression.UI.Strings)
local Flowerbed = require(Regression.World.Flowerbed)
local Scoreboard = require(Regression.World.Scoreboard)
local NextBoard = require(Regression.World.NextBoard)
local LoreWorld = require(Regression.World.LoreWorld)
local LineControls = require(Regression.Input.LineControls)
local PlayerControls = require(Regression.Input.PlayerControls)
local Flow3D = require(Regression.Scenes.Flow3D)
local SceneMachine = require(Regression.Scenes.SceneMachine)
local Screens = Regression.Scenes.Screens2D

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fb = Datasets.flowerbed

-- ───── 1. Место в мире ─────

-- В SkRob включён StreamingEnabled: детали-якоря могут прийти на клиент позже скрипта — ждём их
local level = workspace:WaitForChild("RegressionLevel", 10)
local LEVEL_PARTS = { FlowerbedAnchor = true, LoreAnchor = true, RegressionZone = true }

-- Площадки и куб — служебные детали: в игре невидимы и не мешают (в том числе те, что придут стримингом позже)
local function hideLevelPart(d: Instance)
	if d:IsA("BasePart") and LEVEL_PARTS[d.Name] then
		d.Transparency = 1
		d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
	end
end
if level then
	for _, d in level:GetChildren() do
		hideLevelPart(d)
	end
	level.ChildAdded:Connect(hideLevelPart)
end

-- CFrame и размер площадки без ожидания стриминга: атрибуты папки → деталь → LevelLayout
local function levelPart(name: string): (CFrame, Vector3)
	if level then
		local cf, size = level:GetAttribute(name .. "_CFrame"), level:GetAttribute(name .. "_Size")
		if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			return cf, size
		end
		local part = level:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part.CFrame, part.Size
		end
	end
	local p = Layout.parts[name]
	return p.cframe, p.size
end
local worldFolder = Instance.new("Folder")
worldFolder.Name = "RegressionWorld"
worldFolder.Parent = workspace

local function groundAt(pos: Vector3, fallbackY: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { worldFolder }
	if level then
		table.insert(ignore, level)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else fallbackY
end

-- Якорь → CFrame на земле с поворотом только вокруг вертикали
local function findOrigin(name: string): CFrame
	local acf, asize = levelPart(name)
	local cf = acf * CFrame.new(0, -asize.Y / 2, 0)
	local _, yaw, _ = cf:ToOrientation()
	local p = cf.Position
	return CFrame.new(p.X, groundAt(p, p.Y), p.Z) * CFrame.Angles(0, yaw, 0)
end

local origin = findOrigin("FlowerbedAnchor")
local loreOrigin = findOrigin("LoreAnchor")

-- Куб уровня (его можно растянуть/повернуть в Studio)
local zoneCF, zoneSize = levelPart("RegressionZone")
local function insideCube(p: Vector3): boolean
	local l = zoneCF:PointToObjectSpace(p)
	return math.abs(l.X) <= zoneSize.X / 2 and math.abs(l.Y) <= zoneSize.Y / 2 and math.abs(l.Z) <= zoneSize.Z / 2
end

-- ───── 2. Состояние и модель ─────

local store = Store.new({
	scene = "",
	m = fb.start_line.m,
	h = fb.start_line.h,
	threads = table.create(#fb.x_m, false),
	records = {},
	parabola = nil,
	honey = 0,
	predictions = {},
	inZone = false,
	controlUnlocked = false,
	controlMode = false,
	recordEnabled = false,
	movedSlope = false,
	movedHeight = false,
	showMseFormula = false,
	opened2D = false,
	highlight = nil,
	notes = {},
	inQuestCube = false,
})
local lineModel = LineModel.new(MathCore, fb)

local progressRemote = nil
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	progressRemote = remotes and remotes:WaitForChild("RegressionProgress", 10)
end)
local function milestone(id: string)
	if progressRemote then
		progressRemote:FireServer(id)
	end
end

-- ───── 3. Мир и UI ─────

local D = fb.bed_width_m * Config.STUDS_PER_M
local hud = Hud.new(playerGui)
local shell = Shell2D.new(playerGui, store)
local bed = Flowerbed.new({ parent = worldFolder, origin = origin, data = fb })
local lore = LoreWorld.new({ parent = worldFolder, origin = loreOrigin, data = Datasets.lore })

local flow -- объявлены заранее: кнопки табло и промпты ссылаются на них
local machine
local board = Scoreboard.new({
	parent = worldFolder,
	cframe = origin * CFrame.new(0, 1.2 + 11.25 / 2, -(D / 2 + 4)) * CFrame.Angles(0, math.pi, 0),
	groundY = origin.Position.Y,
	playerGui = playerGui,
	onRecord = function()
		flow:record()
	end,
})
local nextBoard = NextBoard.new({
	parent = worldFolder,
	cframe = origin * CFrame.new(20, 1.2 + 7.875 / 2, -(D / 2 + 4)) * CFrame.Angles(0, math.pi, 0),
	groundY = origin.Position.Y,
	playerGui = playerGui,
	onContinue = function()
		flow:openScreen2D()
	end,
})

local prompts = { bed.controlPrompt }
for _, f in bed.flowers do
	table.insert(prompts, f.prompt)
end
local controls = LineControls.new({
	store = store,
	hud = hud,
	prompts = prompts,
	onRecord = function()
		flow:record()
	end,
})

-- ───── 3a. Уровень активен (куб + LevelFlow): иначе подсказки модуля недоступны ─────
-- Enabled подсказок ведут сцены, поэтому не трогаем его: вне куба MaxActivationDistance = 0 (исходное — в атрибуте).
local inCube = false
local function gatePrompt(p: ProximityPrompt)
	if inCube then
		return
	end
	if p:GetAttribute("RegDist") == nil then
		p:SetAttribute("RegDist", p.MaxActivationDistance)
		p.MaxActivationDistance = 0
	end
end
local function setCube(on: boolean)
	inCube = on
	for _, d in worldFolder:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			if on then
				local dist = d:GetAttribute("RegDist")
				if dist ~= nil then
					d.MaxActivationDistance = dist
					d:SetAttribute("RegDist", nil)
				end
			else
				gatePrompt(d)
			end
		end
	end
	store:set("inQuestCube", on)
end
worldFolder.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		gatePrompt(d) -- например, подсказка второго табло, которое поднимается позже
	end
end)

-- ───── 4. Сцены: 3D (Flow3D) → экраны 2D и лор (SceneMachine) ─────

local scenes = { require(Screens.S2D_1_DerivativeM) }
for _, sc in require(Screens.S2D_23_Intercept) do
	table.insert(scenes, sc)
end
for _, mod in { Screens.S2D_4_SmallSample, Screens.S2D_5_RidgeLasso, Screens.S2D_6_PenaltyCurves, Screens.S2D_7_R2 } do
	table.insert(scenes, require(mod))
end
for _, sc in require(Regression.Scenes.Lore.LoreScenes) do
	table.insert(scenes, sc)
end

machine = SceneMachine.new({
	store = store, shell = shell, hud = hud, MathCore = MathCore, Datasets = Datasets, scenes = scenes,
	onMilestone = milestone,
})
machine.shared.loreWorld = lore

local function open2D()
	if machine:sceneId() == nil then
		machine:start("2D.1")
	elseif not machine.finished then
		local id = machine:sceneId()
		if id and id:sub(1, 2) == "2D" then
			machine:open()
		else
			hud:toast(Strings.lore.goToNpc, nil)
		end
	end
end

flow = Flow3D.new({
	store = store, hud = hud, bed = bed, board = board, nextBoard = nextBoard,
	controls = controls, lineModel = lineModel, MathCore = MathCore, open2D = open2D, onMilestone = milestone,
})

-- пасечник: вернуться к экрану лор-задачи, если игрок закрыл его
lore.npcPrompt.Triggered:Connect(function()
	local spec = machine:current()
	if spec and spec.panel and not shell.isOpen and (machine:sceneId() or ""):sub(1, 1) == "L" then
		machine:open()
	end
end)

-- ───── 5. Цикл: клумба — каждый кадр при изменениях, табло и экраны — не чаще 30 Гц ─────

local dirtyWorld, dirtyBoard = true, true
store.Changed:Connect("*", function()
	dirtyWorld, dirtyBoard = true, true
end)
bed:bindCards(function()
	dirtyWorld = true
end)

setCube(false) -- до первой проверки положения игрока всё закрыто
flow:start()

local uiAcc = 0
RunService.RenderStepped:Connect(function(dt)
	controls:step(dt)

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		-- LevelFlow включает уровни по очереди: ActiveLevel = "regression" ставит сервер у входа в уровень.
		-- Без LevelFlow (песочница) атрибута нет — тогда уровень активен всегда.
		local activeLevel = player:GetAttribute("ActiveLevel")
		local cube = insideCube(root.Position) and (activeLevel == nil or activeLevel == "regression")
		if cube ~= inCube then
			setCube(cube)
			if not cube then
				-- вышли из куба или уровень сменился: закрыть экран 2D и режим управления прямой
				controls:exit()
				if shell.isOpen then
					shell:close()
					PlayerControls.release("shell")
				end
			end
		end
		store:set("inZone", cube and bed:distanceTo(root.Position) <= Config.ZONE_STUDS)
		-- HUD модуля — только внутри куба: рядом с клумбой/пасекой или во время заданий модуля
		local id = machine:sceneId()
		local loreWorldStep = id ~= nil and id:sub(1, 1) == "L" and not shell.isOpen
		hud:setVisible(cube and (controls.active or loreWorldStep or bed:distanceTo(root.Position) <= Config.HUD_RADIUS_BED
			or lore:distanceTo(root.Position) <= Config.HUD_RADIUS_LORE))
	end

	local now = os.clock()
	local snap = lineModel:compute(store:get("m"), store:get("h"))
	local vis = flow:visuals(now)
	if dirtyWorld or vis.animating or bed.cardHover ~= nil then
		dirtyWorld = false
		bed:render(snap, vis)
	end

	flow:tick(snap, now)
	machine:tick(dt)

	uiAcc += dt
	if (dirtyBoard or board.dirty) and uiAcc >= 1 / Config.UI_HZ then
		uiAcc = 0
		dirtyBoard, board.dirty = false, false
		board:render(snap, {
			records = store:get("records"),
			parabola = store:get("parabola"),
			recordEnabled = store:get("recordEnabled"),
			showMseFormula = store:get("showMseFormula"),
		})
	end
end)

-- ───── 6. Отладка в Studio ─────

if RunService:IsStudio() then
	_G.RegressionDebug = {
		store = store, flow = flow, machine = machine, shell = shell, lore = lore, bed = bed,
		inCube = function() return inCube end,
		-- перейти к шагу: "3D.4", "2D.5", "L.3" …
		goto = function(id: string)
			if id:sub(1, 2) == "3D" then
				local i = table.find({ "3D.1", "3D.2", "3D.3", "3D.4", "3D.5", "3D.6" }, id)
				if i then
					store:set("controlUnlocked", i >= 3)
					flow:goto(i)
				end
			else
				flow:goto(7)
				machine:goto(id)
			end
		end,
	}
end
