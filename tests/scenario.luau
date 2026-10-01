--!nonstrict
-- Сквозной сценарий игрока на моке Roblox: 3D experience → 2D experience → лор-задача.
-- Запуск: python3 tests/bundle.py && luau tests/scenario.luau
-- Проверяет контрольные числа раскадровок по тому, что реально написано в UI,
-- и то, что каждая строка формулы открывается только после действия.

local R = require("./mock/Roblox")
local files = require("./_bundle")
local Enum, Vector3, Vector2 = R.Enum, R.Vector3, R.Vector2

local checks, fails = 0, 0
local function ok(name, cond, extra)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. name .. (if extra ~= nil then " — " .. tostring(extra) else ""))
	end
	return cond
end
local function has(root, pattern, name)
	local list = R.findText(root, pattern, { plain = true })
	ok(name or ("есть текст «" .. pattern .. "»"), #list > 0, if #list == 0 then R.allText(root):sub(1, 900) else nil)
	return list[1]
end
local function hasNot(root, pattern, name)
	local list = R.findText(root, pattern, { plain = true })
	ok(name or ("нет текста «" .. pattern .. "»"), #list == 0)
end
local function parseNum(s)
	s = s:gsub("\u{2212}", "-"):gsub(",", ".")
	return tonumber(s:match("%-?%d+%.?%d*"))
end

R.mount(files)
local G = R.game
-- RemoteEvent прогресса, как в SkRob (ReplicatedStorage.Remotes.RegressionProgress)
local remotes = R.newInstance("Folder")
remotes.Name = "Remotes"
remotes.Parent = G:GetService("ReplicatedStorage")
local progress = R.newInstance("RemoteEvent")
progress.Name = "RegressionProgress"
progress.Parent = remotes

-- якоря уровня, как в SkRob (tools/level.py): повёрнуты к спауну, земля на y = −30,58
R.groundY = -30.5758
local level = R.newInstance("Folder")
level.Name = "RegressionLevel"
level.Parent = G.Workspace
for _, a in { { "FlowerbedAnchor", 62, -28, Vector3.new(20, 1, 12) }, { "LoreAnchor", 5, 62, Vector3.new(40, 1, 44) } } do
	local p = R.newInstance("Part")
	p.Name = a[1]
	p.Size = a[4]
	local pos = Vector3.new(a[2], -30.0758, a[3])
	p.CFrame = R.CFrame.lookAt(pos, pos + (pos - Vector3.new(3.1, -30.0758, 1.7)))
	p.Parent = level
end

local client = G:GetService("StarterPlayer").StarterPlayerScripts.RegressionClient
R.setCharacter(Vector3.new(0, 3, 200))
R.runScript(client)
R.step(0.5)

local gui = R.playerGui
local hud = gui:FindFirstChild("RegressionHud")
local board = gui:FindFirstChild("RegressionScoreboardGui")
local shellGui = gui:FindFirstChild("Regression2D")
ok("HUD создан", hud ~= nil)
ok("табло создано", board ~= nil)
ok("экран 2D создан", shellGui ~= nil)
ok("HUD скрыт вдали от клумбы", hud.Enabled == false)
local dbg = R.G.RegressionDebug
ok("отладочный API в Studio", dbg ~= nil)

local function hudText()
	return R.allText(hud)
end
local function boardM()
	local l = R.findText(board, "наклон", { plain = true })[1]
	return parseNum(R.stripRich(l.Text):match("наклон%s+(.+)$"))
end
local function boardMse()
	for _, l in R.findText(board, "MSE = ", { plain = true }) do
		local t = R.stripRich(l.Text)
		if not t:find("Σ") then
			return parseNum(t:match("MSE = (.+)$"))
		end
	end
	return nil
end

-- ═════════════ 3D experience ═════════════
local bed = G.Workspace.RegressionWorld.RegressionFlowerbed
local soilPos = bed.Soil.Position
ok("клумба на якоре уровня", math.abs(soilPos.X - 62) < 1e-3 and math.abs(soilPos.Z + 28) < 1e-3, soilPos)
ok("клумба стоит на земле", math.abs(soilPos.Y - (-30.5758 + 0.2)) < 1e-3, soilPos.Y)
ok("якоря скрыты в игре", level.FlowerbedAnchor.Transparency == 1 and level.LoreAnchor.Transparency == 1)
local pedestal = bed.Pedestal.Position
local toSpawn = (Vector3.new(3.1, 0, 1.7) - Vector3.new(62, 0, -28)).Unit
local toPed = (Vector3.new(pedestal.X, 0, pedestal.Z) - Vector3.new(62, 0, -28)).Unit
ok("пульт клумбы — со стороны спауна", toPed:Dot(toSpawn) > 0.99, toPed:Dot(toSpawn))
R.setCharacter(bed.Soil.Position + Vector3.new(0, 3, 8))
R.step(0.3)
ok("HUD виден у клумбы", hud.Enabled == true)
ok("3D.2 после входа в зону", hudText():find("3D.2", 1, true) ~= nil, hudText())
local mse0 = boardMse()
ok("старт MSE = 0,566", mse0 and math.abs(mse0 - 0.566) < 1e-9, mse0)

R.trigger(bed.Flower1.Head.ProximityPrompt)
R.trigger(bed.Flower2.Head.ProximityPrompt)
local rest = R.button(hud, "Протянуть остальные")
ok("кнопка «протянуть остальные»", rest ~= nil)
R.click(rest)
R.step(1.2)
ok("3D.3 квадраты", hudText():find("3D.3", 1, true) ~= nil, hudText())

R.click(R.button(hud, "Вырастут"))
R.trigger(bed.Pedestal.ProximityPrompt)
R.key(Enum.KeyCode.Q, 0.3)
R.key(Enum.KeyCode.LeftShift, 0.2)
R.key(Enum.KeyCode.LeftControl, 0.2)
R.step(0.1)
ok("3D.4 записи", hudText():find("3D.4", 1, true) ~= nil, hudText())

local function setSlope(target)
	for _ = 1, 4 do
		local m = boardM()
		local da = math.deg(math.atan(target) - math.atan(m))
		if math.abs(da) < 0.2 then break end
		R.key(if da > 0 then Enum.KeyCode.Q else Enum.KeyCode.E, math.abs(da) / 20)
	end
	return boardM()
end
for _, target in { -0.2, 0.0, 0.2, 0.5, 0.8 } do
	setSlope(target)
	R.key(Enum.KeyCode.R)
end
R.step(0.2)
ok("3D.5 парабола", hudText():find("3D.5", 1, true) ~= nil, hudText())
has(board, "m* = 0,33", "на табло минимум m* = 0,33")
setSlope(0.33)
R.step(0.2)
ok("m прилип к m*", math.abs(boardM() - 0.33) < 1e-9, boardM())
R.step(0.3)
ok("3D.6 второе табло", hudText():find("3D.6", 1, true) ~= nil, hudText())
R.step(2.5)
R.key(Enum.KeyCode.X)
local nb = G.Workspace.RegressionWorld.RegressionNextBoard
local fired = rawget(progress, "__fired") or {}
ok("веха regression_3d отправлена", #fired >= 1 and fired[1][1] == "regression_3d", #fired)

-- ═════════════ 2D experience ═════════════
R.trigger(nb.Screen.ProximityPrompt)
R.step(0.2)
ok("экран 2D открыт", shellGui.Enabled == true)
local M = dbg.machine
local function sc() return M.sc end
local function shellText() return R.allText(shellGui) end
local function nextBtn() return M.shell.nextBtn end
local function clickNext(name)
	R.step(0.1)
	ok(name .. ": «Дальше» активна", M.shell.nextEnabled == true, shellText():sub(1, 600))
	R.click(nextBtn())
	R.step(0.1)
end

-- 2D.1
ok("2D.1 открыт", M:sceneId() == "2D.1", M:sceneId())
has(shellGui, "MSE от наклона", "2D.1: график MSE от наклона")
hasNot(shellGui, "3,3", "2D.1: строка dL/dm = 0 закрыта до действия")
ok("2D.1: «Дальше» закрыта до действия", M.shell.nextEnabled == false)
R.click(R.button(shellGui, "Показать L = n·MSE"))
ok("2D.1: строка L(m) открыта действием", sc().f.LOSS:isUnlocked("Lm"))
has(shellGui, "1,58", "2D.1: L(m) = 10·m² − 6,6·m + 1,58 + …")
local bet = R.button(shellGui, "Ноль — касательная горизонтальна")
ok("2D.1: ставка показана", bet ~= nil)
R.click(bet)
R.key(Enum.KeyCode.Q, (0.33 + 0.5) / 0.3)
R.step(0.1)
ok("2D.1: бегунок прилип к m* = 0,33", math.abs(sc().s.mr - 0.33) < 1e-12, sc().s.mr)
ok("2D.1: dL/dm = 0 открыта", sc().f.DLDM:isUnlocked("zero"))
has(shellGui, "3,3", "2D.1: m = 3,3 / 10")
has(shellGui, "= 0,33", "2D.1: результат 0,33")
has(shellGui, "Верно!", "2D.1: ставка засчитана")
clickNext("2D.1")

-- 2D.2 → 2D.3
ok("2D.2 открыт", M:sceneId() == "2D.2", M:sceneId())
has(shellGui, "0,47", "2D.2: наклон 0,47")
R.key(Enum.KeyCode.LeftShift, 0.5)
R.step(0.1)
ok("2D.3 после первого сдвига", M:sceneId() == "2D.3", M:sceneId())
local lab = sc().shared.lab
-- прямую тянем мышью по графику: c меняется на Δy без скачка
local function setC(target)
	local d = target - lab.c
	if math.abs(d) > 1e-9 then
		local p = lab.plot
		local ax, ay = p:toPx(35, 20)
		local bx, by = p:toPx(35, 20 + d)
		local a0 = p.area.AbsolutePosition
		R.mouseDrag(p.area, a0 + Vector2.new(ax, ay), a0 + Vector2.new(bx, by), 6)
	end
	R.step(0.05)
	return lab.c
end
ok("2D.3: dL/dc закрыта до записей", not sc().f.DLDC:isUnlocked("deriv"))
local wantMse = { 42.66, 14.46, 4.26, 12.06, 37.86 }
for k, c in { 0, 3, 6, 9, 12 } do
	local got = setC(c)
	ok(("2D.3: c = %g"):format(c), math.abs(got - c) < 1e-6, got)
	R.key(Enum.KeyCode.R)
	local rec = lab.records[k]
	ok(("2D.3: MSE(c = %g) = %g"):format(c, wantMse[k]), rec and math.abs(rec.mse - wantMse[k]) < 1e-6, rec and rec.mse)
end
ok("2D.3: dL/dc открыта после 5 записей", sc().f.DLDC:isUnlocked("deriv"))
ok("2D.3: c* = 6,2", lab.parabola and math.abs(lab.parabola.tStar - 6.2) < 1e-9, lab.parabola and lab.parabola.tStar)
setC(6.2)
ok("2D.3: прямая в минимуме (прилипание)", lab.c == lab.cStar, lab.c)
ok("2D.3: строка dL/dc = 0 открыта", sc().f.DLDC:isUnlocked("zero"))
has(shellGui, "= 6,2\u{00A0}кг", "2D.3: c = ȳ − m·x̄ = 6,2 кг")
R.click(R.button(shellGui, "Нет"))
has(shellGui, "Верно!", "2D.3: ставка «Нет» засчитана")
clickNext("2D.3")

-- 2D.4
ok("2D.4 открыт", M:sceneId() == "2D.4", M:sceneId())
-- закрыть экран посреди обучения и вернуться через второе табло
R.click(R.button(shellGui, "Закрыть"))
ok("экран закрыт кнопкой", shellGui.Enabled == false)
ok("HUD показывает текущий шаг 2D.4", hudText():find("2D.4", 1, true) ~= nil, hudText())
R.trigger(nb.Screen.ProximityPrompt)
ok("второе табло возвращает к шагу 2D.4", shellGui.Enabled == true and M:sceneId() == "2D.4", M:sceneId())
local s4 = sc().s
local vp = s4.vp
local center = vp.frame.AbsolutePosition + vp.frame.AbsoluteSize / 2
R.mouseDrag(vp.frame, center, center + Vector2.new(-240, 10), 12)
ok("2D.4: облако повёрнуто ≥ 90°", vp.totalYaw >= 90, vp.totalYaw)
has(shellGui, "14,31", "2D.4: коэффициент пчёл 14,31")
has(shellGui, "9,16", "2D.4: коэффициент температуры −9,16")
has(shellGui, "0,981", "2D.4: R² на 5 = 0,981")
R.click(R.button(shellGui, "Проверить на остальных 10"))
R.click(R.button(shellGui, "Плохо — ошибки будут большими"))
R.step(0.1)
has(shellGui, "0,144", "2D.4: R² на остальных 10 = 0,144")
R.click(R.button(shellGui, "Обучить на 15 точках"))
R.step(0.1)
has(shellGui, "0,900", "2D.4: R² на 15 = 0,900")
local tapped = 0
for i, r in s4.rows do
	if r.sample == "rest" and tapped < 2 then
		local wp = Vector3.new((r.bees_k - 35) / 4, (r.honey_kg - 10) / 4, -(r.temperature_C - 21) / 2.5)
		local x, y, vis = vp:project(wp)
		if vis then
			R.mouseDrag(vp.frame, vp.frame.AbsolutePosition + Vector2.new(x, y))
			if s4.tapped[i] then tapped += 1 end
		end
	end
end
ok("2D.4: открыты 2 точки из остальных", s4.nTapped >= 2, s4.nTapped)
has(shellGui, "Ridge и Lasso", "2D.4: строка-итог про Ridge и Lasso")
clickNext("2D.4")

-- 2D.5
ok("2D.5 открыт", M:sceneId() == "2D.5", M:sceneId())
R.click(R.button(shellGui, "Станет ровно 0"))
local s5 = sc().s
s5.slider:set(1)
R.step(0.1)
has(shellGui, "(3,22; 1,46)", "2D.5: L2 при λ = 1 → (3,22; 1,46)")
has(shellGui, "(8,16; ", "2D.5: L1 при λ = 1 → (8,16; −3,01)")
ok("2D.5: при λ = 1 температура в L1 ещё не 0", not s5.l1Snap)
-- перетаскивание ползунка до λ = 1,5
local track = s5.slider.track
local from = track.AbsolutePosition + Vector2.new(track.AbsoluteSize.X * 1 / 20, 4)
R.mouseDrag(s5.slider.hit, from, track.AbsolutePosition + Vector2.new(track.AbsoluteSize.X * 1.5 / 20, 4), 6)
ok("2D.5: λ = 1,5 ползунком", math.abs(s5.lambda - 1.5) < 1e-9, s5.lambda)
ok("2D.5: L1 защёлкнулась в вершину ромба", s5.l1Snap)
has(shellGui, "(5,16; 0,00)", "2D.5: L1 при λ ≥ 1,49 → (5,16; 0)")
has(shellGui, "острые углы", "2D.5: пояснение про ромб")
has(shellGui, "Верно!", "2D.5: ставка «ровно 0» засчитана")
ok("2D.5: «Дальше» закрыта, пока L2 не доведена до 20", M.shell.nextEnabled == false)
s5.slider:set(20)
R.step(0.1)
has(shellGui, "(0,90; 0,81)", "2D.5: L2 при λ = 20 → (0,90; 0,81)")
has(shellGui, "нет углов", "2D.5: пояснение про круг")
has(shellGui, "0,144", "2D.5: бонус R² OLS 0,144")
has(shellGui, "0,877", "2D.5: бонус R² Ridge 0,877")
has(shellGui, "0,838", "2D.5: бонус R² Lasso 0,838")
clickNext("2D.5")

-- 2D.6
ok("2D.6 открыт", M:sceneId() == "2D.6", M:sceneId())
local s6 = sc().s
local function slide6(v)
	s6.slider:set(v)
	s6.slider.opts.onReleased(v)
	R.step(0.1)
end
slide6(1)
local p2 = s6.half.l2.plot
local px, py = p2:toPx(0.3, 1)
R.mouseDrag(p2.area, p2.area.AbsolutePosition + Vector2.new(px, py))
has(shellGui, "0,300", "2D.6: L2 при λ = 1 → m* = 0,30")
local p1 = s6.half.l1.plot
px, py = p1:toPx(0.28, 1)
R.mouseDrag(p1.area, p1.area.AbsolutePosition + Vector2.new(px, py))
has(shellGui, "0,280", "2D.6: L1 при λ = 1 → m* = 0,28")
slide6(3.3)
has(shellGui, "0,165", "2D.6: L1 при λ = 3,3 → 0,165")
slide6(10)
ok("2D.6: λ = 10 — минимум 0, но не «впервые»", not s6.task)
slide6(6.6)
ok("2D.6: найдено λ = 6,6", s6.task)
ok("2D.6: строка λ ≥ 6,6 ⇒ m* = 0 открыта", sc().f.MIN1:isUnlocked("kink"))
ok("2D.6: след прошлых λ", #s6.trails >= 3, #s6.trails)
clickNext("2D.6")

-- 2D.7
ok("2D.7 открыт", M:sceneId() == "2D.7", M:sceneId())
local v7 = sc().s.view
R.click(v7.hits[1])
R.click(v7.hits[2])
R.step(0.7)
local restBtn = R.button(shellGui, "Собрать остальные")
ok("2D.7: «Собрать остальные» после 2 ручных", restBtn ~= nil)
R.click(restBtn)
R.step(1.2)
ok("2D.7: фаза среднего", v7.phase == "mean", v7.phase)
has(shellGui, "21,1", "2D.7: SS_res = 21,1")
local pa = v7.plot
local ax, ay = pa:toPx(35, 8)
local bx, by = pa:toPx(35, 25.4)
R.mouseDrag(pa.area, pa.area.AbsolutePosition + Vector2.new(ax, ay), pa.area.AbsolutePosition + Vector2.new(bx, by), 10)
ok("2D.7: прямая прилипла к ȳ = 25", v7.meanSet and v7.meanY == 25, v7.meanY)
R.click(R.button(shellGui, "Собрать в столбик"))
R.step(1.5)
has(shellGui, "242,0", "2D.7: SS_tot = 242")
has(shellGui, "0,913", "2D.7: R² = 0,913")
clickNext("2D.7")
fired = rawget(progress, "__fired") or {}
ok("веха regression_2d отправлена", fired[#fired] and fired[#fired][1] == "regression_2d")

-- ═════════════ Лор-задача ═════════════
ok("L.0: экран закрыт, задание в мире", M:sceneId() == "L.0" and shellGui.Enabled == false, M:sceneId())
local loreModel = G.Workspace.RegressionWorld.RegressionLore
local npcPos = loreModel.Beekeeper.Body.Position
ok("пасечник на пасеке ближе к спауну, чем ульи", (npcPos - Vector3.new(3.1, npcPos.Y, 1.7)).Magnitude < (loreModel.Hive3.Box.Position - Vector3.new(3.1, npcPos.Y, 1.7)).Magnitude)
R.setCharacter(loreModel.Beekeeper.Body.Position + Vector3.new(0, 0, 4))
R.step(0.2)
ok("HUD виден у пасеки", hud.Enabled == true)
R.trigger(loreModel.Beekeeper.Body.ProximityPrompt)
R.step(0.2)
ok("L.1 открыт", M:sceneId() == "L.1" and shellGui.Enabled, M:sceneId())
has(shellGui, "0,99", "L.1: корреляция пчёл и температуры 0,99")
R.click(R.button(shellGui, "Ridge (L2)"))
ok("L.1: Ridge не блокирует, но не засчитан", M:sceneId() == "L.1")
has(shellGui, "у круга нет углов", "L.1: напоминание после Ridge")
R.click(R.button(shellGui, "Lasso (L1)"))
R.step(0.1)
ok("L.2 после выбора L1", M:sceneId() == "L.2", M:sceneId())
has(shellGui, "2,5", "L.2: λ = 2,5")
hasNot(shellGui, "14,36", "L.2: формула закрыта до «Обучить»")
R.click(R.button(shellGui, "Обучить"))
R.step(0.1)
has(shellGui, "14,36", "L.2: мёд = 14,36 …")
has(shellGui, "0,0072", "L.2: − 0,0072·расстояние")
has(shellGui, "0,577", "L.2: + 0,577·пчёлы")
has(shellGui, "5,12", "L.2: стандартизованный коэффициент расстояния −5,12")
has(shellGui, "3,21", "L.2: стандартизованный коэффициент пчёл 3,21")
has(shellGui, "0,72", "L.2: каждые 100 м — минус 0,72 кг")
clickNext("L.2")

ok("L.3: задание в мире", M:sceneId() == "L.3" and shellGui.Enabled == false, M:sceneId())
local hives = { loreModel.Hive1, loreModel.Hive2, loreModel.Hive3, loreModel.Hive4, loreModel.Hive5 }
local meadows = { loreModel.Meadow1, loreModel.Meadow2, loreModel.Meadow3, loreModel.Meadow4, loreModel.Meadow5 }
R.trigger(hives[1].Box.ProximityPrompt)
R.trigger(meadows[1].SignPost.ProximityPrompt)
local enter1 = R.button(hud, "Внести данные улья 1")
ok("L.3: «Внести данные улья 1»", enter1 ~= nil)
R.click(enter1)
local st = M.shared.lore
ok("L.3: прогноз улья 1 = 24,79", st.pred[1] and math.abs(st.pred[1] - 24.791927) < 1e-4, st.pred[1])
local helper = R.button(hud, "Пчела-помощник")
ok("L.3: пчела-помощник после первого улья", helper ~= nil)
R.click(helper)
ok("L.3: пчёлы посчитаны во всех ульях", st.bees[5] == 46.5)
local wantPred = { 24.791927, 32.999628, 36.680266, 34.866434, 37.195494 }
for i = 2, 5 do
	R.trigger(meadows[i].SignPost.ProximityPrompt)
	R.click(R.button(hud, ("Внести данные улья %d"):format(i)))
	ok(("L.3: прогноз улья %d"):format(i), st.pred[i] and math.abs(st.pred[i] - wantPred[i]) < 1e-4, st.pred[i])
end
R.step(0.2)
ok("L.4 сезон", M:sceneId() == "L.4", M:sceneId())
for i = 1, 5 do
	R.trigger(hives[i].Box.ProximityPrompt)
end
R.step(0.2)
ok("L.5 открыт", M:sceneId() == "L.5" and shellGui.Enabled, M:sceneId())
local v5 = sc().s.view
R.click(v5.hits[1])
R.click(v5.hits[2])
R.step(0.7)
R.click(R.button(shellGui, "Собрать остальные"))
R.step(1.2)
has(shellGui, "1,2", "L.5: SS_res ≈ 1,18")
local lp = v5.plot
ax, ay = lp:toPx(3, 18)
bx, by = lp:toPx(3, 33.4)
R.mouseDrag(lp.area, lp.area.AbsolutePosition + Vector2.new(ax, ay), lp.area.AbsolutePosition + Vector2.new(bx, by), 10)
ok("L.5: прямая на среднем 33,2", v5.meanSet, v5.meanY)
R.click(R.button(shellGui, "Собрать в столбик"))
R.step(1.5)
has(shellGui, "110,8", "L.5: SS_tot = 110,8")
has(shellGui, "0,989", "L.5: R² = 0,989")
ok("L.5: «Дальше» закрыта до «А если бы OLS?»", M.shell.nextEnabled == false)
R.click(R.button(shellGui, "А если бы OLS?"))
has(shellGui, "R² = \u{2212}0,78", "L.5: R² OLS = −0,78")
clickNext("L.5")
ok("модуль завершён", M.finished == true)
fired = rawget(progress, "__fired") or {}
ok("веха regression_lore отправлена", fired[#fired] and fired[#fired][1] == "regression_lore")
local honey = dbg.store:get("honey")
ok("мёд-бонусы начислены", honey >= 8, honey)

-- ═════════════ Блокнот ═════════════
local nb2 = M.shell.notebook
local kinds = {}
for _, e in nb2.entries do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
ok("блокнот: формулы перенесены", (kinds.formula or 0) >= 10, kinds.formula)
ok("блокнот: заметки", (kinds.note or 0) >= 4, kinds.note)

print(("Scenario: %d/%d"):format(checks - fails, checks))
if fails > 0 then
	error("есть упавшие проверки")
end
