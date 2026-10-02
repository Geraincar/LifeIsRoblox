--!nonstrict
-- Лаборатория деревьев (DecisionTreeLab) на моке Roblox: сервер + клиент из team-patches, настоящие датасеты.
-- Запуск: python3 tests/bundle.py && luau tests/lab.luau
-- Проверяет: кнопки подвала (◀ ▶ по партиям, «Посмотреть на test-датасете», «Пройти окончательную проверку»),
-- партия = одна строка test-датасета, окончательная проверка — весь test-датасет уровня, прогресс без DataStore.

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
