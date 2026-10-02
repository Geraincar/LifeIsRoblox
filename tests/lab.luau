--!nonstrict
-- Лаборатория деревьев (DecisionTreeLab) на моке Roblox: сервер + клиент из team-patches, настоящие датасеты.
-- Запуск: python3 tests/bundle.py && luau tests/lab.luau
-- Проверяет: кнопки подвала (◀ ▶ по партиям, «Посмотреть на test-датасете», «Пройти окончательную проверку»),
-- партия = одна строка test-датасета, окончательная проверка — весь test-датасет уровня, прогресс без DataStore,
-- режимы «Лес голосует» (ForestExplain) и «Бустинг исправляет ошибки» (BoostExplain).

local R = require("./mock/Roblox")
local files = require("./_bundle_team")

local checks, fails = 0, 0
local function ok(name, cond, extra)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. name .. (if extra ~= nil then " — " .. tostring(extra) else ""))
	end
	return cond
end

-- только файлы лаборатории (остальные скрипты из team-patches требуют полной карты SkRob)
local labFiles = {}
for path, src in files do
	if path:find("DecisionTreeLab") then
		labFiles[path] = src
	end
end
R.mount(labFiles)
local G = R.game
local RS = G:GetService("ReplicatedStorage")
local rpc = R.newInstance("RemoteFunction")
rpc.Name = "DecisionTreeLabRPC"
rpc.Parent = RS

-- мир лаборатории: терминал с подсказкой и маяки классов
local lab = R.newInstance("Model")
lab.Name = "DecisionTreeLab_2026"
lab.Parent = G.Workspace
local terminal = R.newInstance("Part")
terminal.Name = "SorterTerminal"
terminal.Parent = lab
local prompt = R.newInstance("ProximityPrompt")
prompt.Name = "OpenDecisionTreeLab"
prompt.MaxActivationDistance = 10
prompt.Parent = terminal
for _, l in { "A", "B", "C", "D" } do
	local b = R.newInstance("Part")
	b.Name = "ClassBeacon_" .. l
	b.Parent = lab
end

-- StarterGui → PlayerGui: ScreenGui с локальными скриптами
local starterFolder = G:GetService("StarterGui").DecisionTreeLabUI
local gui = R.newInstance("ScreenGui")
gui.Name = "DecisionTreeLabUI"
gui.Parent = R.playerGui
for _, sc in starterFolder:GetChildren() do
	sc.Parent = gui
end

R.runScript(G:GetService("ServerScriptService").DecisionTreeLabService)
R.step(0.1)
R.runScript(gui.DecisionTreeLabController)
R.step(0.2)

-- вызов сервера в корутине: обучение леса/бустинга уступает управление (task.wait), время двигаем шагами
local function invoke(...)
	local args = table.pack(...)
	local done, okRes, res = false, nil, nil
	R.task.spawn(function()
		okRes, res = pcall(function()
			return rpc:InvokeServer(table.unpack(args, 1, args.n))
		end)
		done = true
	end)
	local guard = 0
	while not done and guard < 2000 do
		R.step(0.05)
		guard += 1
	end
	if not okRes then
		error(res, 0)
	end
	return res
end

local function text()
	return R.allText(gui)
end
local function status()
	return R.stripRich(gui:FindFirstChild("Status", true).Text)
end
local function batchText()
	return gui:FindFirstChild("BatchText", true).Text
end
local function metricsText()
	return gui:FindFirstChild("Metrics", true).Text
end

R.trigger(prompt)
local shade = gui:FindFirstChild("Shade")
ok("лаборатория открывается подсказкой", shade.Visible == true)

-- кнопки подвала
for _, t in { "◀ ПАРТИЯ", "ПАРТИЯ ▶", "ПОСМОТРЕТЬ НА TEST-ДАТАСЕТЕ", "ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ" } do
	ok("кнопка «" .. t .. "»", R.button(gui, t) ~= nil, text():sub(1, 400))
end
for _, t in { "ПРОВЕРИТЬ VALIDATION", "СОРТИРОВАТЬ ПАРТИЮ", "СЛЕДУЮЩАЯ →" } do
	ok("старой кнопки «" .. t .. "» нет", R.button(gui, t) == nil)
end

-- партии: весь test-датасет уровня (дерево — 64 партии), листание по кругу в обе стороны
ok("партия 1 из 64", batchText():find("Партия 1 из 64", 1, true) ~= nil, batchText():sub(1, 80))
R.click(R.button(gui, "◀ ПАРТИЯ"))
ok("◀ с первой партии — на последнюю (64 из 64)", batchText():find("Партия 64 из 64", 1, true) ~= nil, batchText():sub(1, 80))
R.click(R.button(gui, "ПАРТИЯ ▶"))
R.click(R.button(gui, "ПАРТИЯ ▶"))
ok("▶ ▶ — партия 2 из 64", batchText():find("Партия 2 из 64", 1, true) ~= nil, batchText():sub(1, 80))
for _ = 1, 25 do
	R.click(R.button(gui, "ПАРТИЯ ▶"))
end
ok("можно уйти дальше 20-й партии (27 из 64)", batchText():find("Партия 27 из 64", 1, true) ~= nil, batchText():sub(1, 80))

-- «Посмотреть на test-датасете»: прогноз для ОДНОЙ партии
R.click(R.button(gui, "ПОСМОТРЕТЬ НА TEST-ДАТАСЕТЕ"))
ok("посмотреть: ответ про одну партию (27 из 64)", status():find("27 из 64", 1, true) ~= nil and status():find("одна партия", 1, true) ~= nil, status())
ok("посмотреть: метрики окончательной проверки не появились", metricsText():find("Точность", 1, true) == nil)

-- «Пройти окончательную проверку»: весь test-датасет уровня
R.click(R.button(gui, "ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ"))
R.step(0.1)
ok("окончательная проверка: весь test-датасет уровня, 64 партии", metricsText():find("весь test-датасет уровня · 64 партий", 1, true) ~= nil, metricsText())
ok("окончательная проверка: в статусе 64 партии", status():find("64 партий", 1, true) ~= nil, status())
ok("нет упоминаний validation в интерфейсе", not text():lower():find("validation", 1, true), text():sub(1, 300))

-- полный проход по окончательным проверкам (test-датасет уровня): дерево из подсказки «Критерии сортировщиков»,
-- лес 11×5, бустинг 60×3 — каждый открывает следующий уровень
local guideTree = { root = 1, nodes = {
	["1"] = { kind = "split", feature = 1, op = ">", threshold = 38, yes = 2, no = 3 },
	["2"] = { kind = "leaf", class = 1 },
	["3"] = { kind = "split", feature = 2, op = "<", threshold = 60, yes = 4, no = 5 },
	["4"] = { kind = "leaf", class = 2 },
	["5"] = { kind = "split", feature = 3, op = "<", threshold = 4.2, yes = 6, no = 7 },
	["6"] = { kind = "leaf", class = 3 },
	["7"] = { kind = "leaf", class = 4 },
} }
local r1 = invoke("Evaluate", "Tree", { Graph = guideTree })
ok("дерево по подсказке проходит окончательную проверку на test (64 партии)", r1.Success and r1.Total == 64 and r1.Dataset == "test",
	("acc %.3f f1 %.3f"):format(r1.Metrics.Accuracy, r1.Metrics.MacroF1))
local r2 = invoke("Evaluate", "Forest", { Count = 11, Depth = 5 })
ok("лес 11×5 проходит окончательную проверку (360 партий)", r2.Success and r2.Total == 360,
	("acc %.3f f1 %.3f"):format(r2.Metrics.Accuracy, r2.Metrics.MacroF1))
local r3 = invoke("Evaluate", "Boost", { Rounds = 60, Depth = 3 })
ok("бустинг 60×3 проходит окончательную проверку (640 партий)", r3.Success and r3.Total == 640,
	("acc %.3f f1 %.3f"):format(r3.Metrics.Accuracy, r3.Metrics.MacroF1))
ok("все уровни лаборатории открыты в этой сессии", r3.Unlocked == 4, r3.Unlocked)

-- ── A · «Лес голосует» и B · «Бустинг исправляет ошибки» (ответы сервера) ──
local fx = invoke("ForestExplain", "Forest", { Count = 7, Depth = 4, RandomFeatures = true }, 5)
ok("ForestExplain: 7 деревьев с корзинами и голосами", #fx.Trees == 7 and fx.Index == 5 and fx.Total == 360)
local voteSum, bagOk = 0, true
for c = 1, 4 do voteSum += fx.Votes[c] end
for _, t in fx.Trees do
	local n = 0
	for c = 1, 4 do n += t.Classes[c] end
	bagOk = bagOk and t.Size == 1080 and n == 1080 and t.Unique < 1080 and t.Unique > 500 and table.find({ "A", "B", "C", "D" }, t.Vote) ~= nil
end
ok("ForestExplain: голосов столько же, сколько деревьев", voteSum == 7, voteSum)
ok("ForestExplain: корзины по 1080 партий с повторами (бэггинг)", bagOk)
ok("ForestExplain: точность по числу деревьев для k=1..7", #fx.AccByCount == 7 and fx.Agreement > 0 and fx.Agreement < 1)
ok("ForestExplain: лес из 7 точнее среднего дерева", fx.AccByCount[7] > fx.Single, ("%.3f vs %.3f"):format(fx.AccByCount[7], fx.Single))
local fxSame = invoke("ForestExplain", "Forest", { Count = 7, Depth = 4, RandomFeatures = false }, 5)
ok("без случайных признаков деревья согласнее", fxSame.Agreement > fx.Agreement, ("%.3f vs %.3f"):format(fxSame.Agreement, fx.Agreement))

local bx0 = invoke("BoostExplain", "Boost", { Rounds = 0, Depth = 2, Rate = 0.2 }, 3)
ok("BoostExplain: раунд 0 без деревьев", bx0.Round == 0 and #bx0.History == 1 and bx0.LastStage == nil)
local bx = invoke("BoostExplain", "Boost", { Rounds = 30, Depth = 2, Rate = 0.2 }, 3)
local pSum = 0
for c = 1, 4 do pSum += bx.Probs[c] end
ok("BoostExplain: вероятности классов в сумме 1", math.abs(pSum - 1) < 1e-6, pSum)
ok("BoostExplain: история 31 точка, train/test по раундам", #bx.History == 31 and #bx.TrainAcc == 31 and #bx.TestAcc == 31)
ok("BoostExplain: ошибок на обучении меньше, чем в раунде 0", bx.Wrong < bx0.Wrong, bx.Wrong .. " vs " .. bx0.Wrong)
ok("BoostExplain: 5 самых трудных партий и вопросы деревьев раунда", #bx.Hard == 5 and #bx.LastStage == 4 and bx.Hard[1].P <= bx.Hard[5].P)
ok("BoostExplain: лучший раунд на test в пределах 0..30", bx.BestTestRound >= 0 and bx.BestTestRound <= 30)
local badRate = pcall(invoke, "BoostExplain", "Boost", { Rounds = 5, Depth = 2, Rate = 0.3 }, 3)
ok("шаг обучения не из списка отклоняется", badRate == false)
local zeroEval = pcall(invoke, "Evaluate", "Boost", { Rounds = 0, Depth = 2, Rate = 0.2 })
ok("окончательная проверка бустинга с 0 раундов отклоняется", zeroEval == false)
local r4 = invoke("Evaluate", "Boost", { Rounds = 60, Depth = 3, Rate = 0.5 })
ok("бустинг 60×3 с шагом 0,5 проходит", r4.Success, ("acc %.3f f1 %.3f"):format(r4.Metrics.Accuracy, r4.Metrics.MacroF1))

-- ── интерфейс A и B: перезапуск клиента (сервер уже открыл все уровни) ──
local function fire(btn)
	assert(btn, "кнопка не найдена")
	local done = false
	R.task.spawn(function()
		rawget(btn, "__signals").MouseButton1Click:Fire()
		done = true
	end)
	local guard = 0
	while not done and guard < 4000 do
		R.step(0.05)
		guard += 1
	end
	R.step(0.05)
end
for _, name in { "Shade", "OpenLab" } do
	local x = gui:FindFirstChild(name)
	if x then x:Destroy() end
end
R.runScript(gui.DecisionTreeLabController)
R.step(0.2)
shade = gui:FindFirstChild("Shade")
shade.Visible = true

fire(R.button(gui, "2 · СЛУЧАЙНЫЙ ЛЕС"))
for _, t in { "СОБРАТЬ ЛЕС И ПОКАЗАТЬ ГОЛОСА", "ВКЛ", "ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ" } do
	ok("лес: кнопка «" .. t .. "»", R.button(gui, t) ~= nil)
end
fire(R.button(gui, "СОБРАТЬ ЛЕС И ПОКАЗАТЬ ГОЛОСА"))
local trees = gui:FindFirstChild("Trees", true)
local cards = 0
if trees then
	for _, c in trees:GetChildren() do
		if c.Name:match("^Tree%d+$") then cards += 1 end
	end
end
ok("лес: 5 карточек деревьев", cards == 5, cards)
ok("лес: карточка показывает корзину и первый вопрос", text():find("Корзина: 1080 партий, разных", 1, true) ~= nil and text():find("1-й вопрос:", 1, true) ~= nil)
ok("лес: итог голосования по партии", text():find("лес:", 1, true) ~= nil and text():find("истинный класс:", 1, true) ~= nil)
local chart = gui:FindFirstChild("AccuracyByCount", true)
ok("лес: столбцы точности по числу деревьев", chart ~= nil and chart:FindFirstChild("Count5", true) ~= nil)

fire(R.button(gui, "ПАРТИЯ ▶"))
ok("лес: ▶ пересчитывает голоса для партии 2", text():find("%(2 из 360%)") ~= nil, text():match("Партия[^|]*голоса[^|]*"))
fire(R.button(gui, "ВКЛ"))
ok("лес: переключатель случайных признаков", R.button(gui, "ВЫКЛ") ~= nil and gui:FindFirstChild("Trees", true) == nil)
fire(R.button(gui, "ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ"))
ok("лес: окончательная проверка по 360 партиям", metricsText():find("360 партий", 1, true) ~= nil, metricsText())


fire(R.button(gui, "3 · ГРАДИЕНТНЫЙ БУСТИНГ"))
ok("бустинг: раунд 0 из 60", text():find("Раунд 0 из 60", 1, true) ~= nil)
fire(R.button(gui, "ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ"))
ok("бустинг: проверка с 0 раундов просит обучить раунд", status():find("хотя бы один раунд", 1, true) ~= nil, status())
fire(R.button(gui, "+1 РАУНД"))
ok("бустинг: +1 раунд", text():find("Раунд 1 из 60", 1, true) ~= nil and gui:FindFirstChild("Probabilities", true) ~= nil)
fire(R.button(gui, "+10"))
ok("бустинг: +10 → раунд 11", text():find("Раунд 11 из 60", 1, true) ~= nil)
ok("бустинг: вопросы деревьев раунда и трудные партии", text():find("Деревья раунда 11", 1, true) ~= nil and text():find("Самые трудные партии", 1, true) ~= nil)
local overfit = gui:FindFirstChild("Overfit", true)
ok("бустинг: точки train и test по 12 раундам", overfit ~= nil and overfit:FindFirstChild("Dot2_11", true) ~= nil and overfit:FindFirstChild("Dot2_12", true) == nil)
for _ = 1, 5 do fire(R.button(gui, "+10")) end
ok("бустинг: не больше 60 раундов", text():find("Раунд 60 из 60", 1, true) ~= nil)
fire(R.button(gui, "ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ"))
ok("бустинг: окончательная проверка по 640 партиям", metricsText():find("640 партий", 1, true) ~= nil, metricsText())
fire(R.button(gui, "СНАЧАЛА"))
ok("бустинг: сначала → раунд 0", text():find("Раунд 0 из 60", 1, true) ~= nil)

local b = invoke("GetBatch", "Forest", nil, 360)
ok("у леса 360 партий в test-датасете, последняя доступна", b.Total == 360 and b.Index == 360)

-- прогресс не сохраняется: сервер без DataStore, новый заход начинается с уровня 1
local state = invoke("GetState")
ok("прогресс помечен как несохраняемый", state.Persistent == false)
G:GetService("Players").PlayerRemoving:Fire(R.player)
state = invoke("GetState")
ok("после перезахода снова уровень 1", state.Unlocked == 1, state.Unlocked)
ok("в сервере лаборатории нет DataStore", not labFiles["ServerScriptService/DecisionTreeLabService.server.luau"]:find("DataStore"))

-- после перезахода лес снова закрыт
R.click(R.button(gui, "🔒 2 · СЛУЧАЙНЫЙ ЛЕС") or R.button(gui, "2 · СЛУЧАЙНЫЙ ЛЕС"))
local okF = pcall(invoke, "GetBatch", "Forest", nil, 1)
ok("после перезахода лес закрыт на сервере", okF == false)

print(("Lab: %d/%d"):format(checks - fails, checks))
if fails > 0 then
	error("есть упавшие проверки")
end
