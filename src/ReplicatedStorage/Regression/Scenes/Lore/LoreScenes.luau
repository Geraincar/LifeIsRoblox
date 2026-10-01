--!nonstrict
-- Лор-задача: прогноз мёда для своей пасеки по данным пяти других пасек (lore-task.md).
--   L.0 (мир)    дойти до пасечника — «Поговорить»
--   L.1 (экран)  таблица пасек + подсказка; выбор метода OLS / Ridge / Lasso (ошибка не блокирует — напоминание и повтор)
--   L.2 (экран)  λ = 2,5 с пояснением; «Обучить» → коэффициенты и формула в исходных единицах
--   L.3 (мир)    у каждого улья: «Посчитать пчёл», дойти до поляны — «Измерить расстояние», «Внести» → прогноз;
--                после первого улья — пчела-помощник считает пчёл в остальных (до полян игрок ходит сам)
--   L.4 (мир)    «Собрать мёд» у каждого улья → реальный мёд рядом с прогнозом
--   L.5 (экран)  R² как в 2D.7 (игрок сам собирает SS_res и SS_tot) → «А если бы OLS?» → награда и выход
-- Мир пасеки (LoreWorld) кладёт в machine.shared.loreWorld точка входа RegressionClient.

local Regression = script.Parent.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)
local R2View = require(Regression.UI.R2View)
local S2D7 = require(Regression.Scenes.Screens2D.S2D_7_R2)

local S = Strings.lore
local MANUAL_HIVES = 1 -- после стольких ульев, внесённых вручную, появляется пчела-помощник

-- ───── модель (числа — только из MathCore) ─────

local function model(sc)
	local shared = sc.shared
	if shared.loreModel then
		return shared.loreModel
	end
	local L, MathCore = sc.Datasets.lore, sc.MathCore
	local X, y = {}, {}
	for i, a in L.train_apiaries do
		local row = {}
		for j, f in L.features do row[j] = a[f] end
		X[i], y[i] = row, a.honey_kg
	end
	local Z, mu, sd = MathCore.standardize(X)
	local b0, b = MathCore.lasso(Z, y, L.lambda_given)
	local a0, a = MathCore.toRawUnits(b0, b, mu, sd)
	local o0, ob = MathCore.ols(Z, y)
	local oa0, oa = MathCore.toRawUnits(o0, ob, mu, sd)
	local bees, temp = MathCore.column(X, 2), MathCore.column(X, 3)
	local m = {
		X = X, y = y, mu = mu, sd = sd, b0 = b0, b = b, a0 = a0, a = a, lambda = L.lambda_given,
		ols = { b0 = o0, b = ob, a0 = oa0, a = oa }, corr = MathCore.corr(bees, temp),
	}
	-- прогноз по исходным единицам признаков (расстояние, пчёлы, температура)
	function m.predict(row: { number }, which: string?): number
		local w = if which == "ols" then m.ols else m
		local s = w.a0
		for j = 1, 3 do s += w.a[j] * row[j] end
		return s
	end
	shared.loreModel = m
	shared.lore = shared.lore or { bees = {}, dist = {}, entered = {}, pred = {}, real = {}, manual = 0, helper = false }
	return m
end

local function hiveRow(sc, i: number): { number }
	local h = sc.Datasets.lore.player_hives[i]
	return { h.distance_to_meadow_m, h.bees_k, h.temperature_C }
end

local function kg(v: number): string
	return Format.unit(v, 2, "кг")
end

local function cardText(sc, i: number): string
	local st = sc.shared.lore
	local lines = { S.cardTitle:format(i) }
	table.insert(lines, S.cardBees:format(if st.bees[i] then Format.num(st.bees[i], 1) else "?"))
	table.insert(lines, S.cardDist:format(if st.dist[i] then Format.num(st.dist[i], 0) else "?"))
	if st.pred[i] then
		table.insert(lines, Theme.tok("loss", S.cardPred:format(kg(st.pred[i]))))
	end
	if st.real[i] then
		table.insert(lines, S.cardReal:format(kg(st.real[i]), Format.signed(st.real[i] - st.pred[i], 2)))
	end
	return table.concat(lines, "\n")
end

-- ───── L.0 к пасечнику ─────

local L0 = { id = "L.0", panel = false }

function L0.enter(sc)
	local lw = sc.shared.loreWorld
	model(sc)
	sc.s.talked = false
	lw.npcPrompt.Enabled = true
	lw:setBeacon(lw.npc.PrimaryPart)
	sc:conn(lw.npcPrompt.Triggered:Connect(function()
		sc.s.talked = true
		sc:progress()
	end))
	sc:toast(S.goToNpc, Theme.color.c)
end

function L0.exit(sc)
	sc.shared.loreWorld:setBeacon(nil)
end

function L0.canAdvance(sc)
	return sc.s.talked
end

function L0.hintTargets(sc)
	return { sc.shared.loreWorld.npc }
end

-- ───── L.1 выбор метода ─────

local L1 = { id = "L.1", panel = true, autoAdvance = true }

function L1.enter(sc)
	local m = model(sc)
	local L = sc.Datasets.lore
	local main = sc.shell.main
	-- таблица пяти пасек
	local tbl = Gui.frame({ BackgroundColor3 = Theme.color.panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = main })
	Gui.corner().Parent = tbl
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = tbl })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = tbl })
	local function row(cells, order, header)
		local r = Gui.frame({ BackgroundTransparency = if header then 1 else 0.9, BackgroundColor3 = Theme.color.panel2, Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = order, Parent = tbl })
		for k, text in cells do
			Gui.label({ Text = text, TextSize = if header then 16 else 19, Font = if header then Theme.font else Theme.fontMedium,
				TextColor3 = if header then Theme.color.textDim else (if k == 4 then Theme.color.m_temp else Theme.color.text),
				TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale((k - 1) / 5, 0), Size = UDim2.fromScale(1 / 5, 1), Parent = r })
		end
	end
	row(S.columns, 0, true)
	for i, a in L.train_apiaries do
		row({ tostring(a.apiary), Format.num(a.distance_to_meadow_m, 0), Format.num(a.bees_k, 1), Format.num(a.temperature_C, 1), Format.num(a.honey_kg, 1) }, i)
	end
	Gui.label({ Text = S.corrNote:format(Format.num(m.corr, 2)), TextSize = 18, TextColor3 = Theme.color.m_temp, Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 10, Parent = tbl })

	sc.shell:setText(S.npcSays)
	for k, opt in S.methods do
		sc.shell:button(opt.label, { order = k, onClick = function()
			if sc.s.chosen then
				return
			end
			sc:progress()
			if opt.id == "l1" then
				sc.s.chosen = true
				sc.shell:toast(S.methodOk, Theme.color.good)
				sc:honey(1)
			else
				sc.s.wrong = (sc.s.wrong or 0) + 1
				sc.shell:setText(S.npcSays .. "\n\n" .. Theme.tok("c", opt.reply))
			end
		end })
	end
end

function L1.canAdvance(sc)
	return sc.s.chosen == true
end

-- ───── L.2 модель ─────

local L2 = { id = "L.2", panel = true }
L2.nextLabel = S.toWorld

function L2.enter(sc)
	local m = model(sc)
	local s = sc.s
	s.trained = false
	local main = sc.shell.main
	Gui.label({ Text = S.coefsTitle, Font = Theme.fontBold, TextSize = 20, Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -56, 0, 26), Parent = main })
	local inner = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), Parent = main })
	s.plot = PlotView2D.new(inner, {
		xMin = 0, xMax = 4, yMin = -16, yMax = 18, xTicks = {}, yTicks = { -15, -10, -5, 0, 5, 10, 15 },
		yLabel = S.coefsAxis, padL = 52, padR = 10, padT = 14, padB = 56, fontSize = 15, fallbackW = 420, fallbackH = 400,
	})
	s.plot.onResize = function() L2.draw(sc) end
	s.trainBtn = sc.shell:button(S.train, { order = 1, color = Theme.color.loss, textColor = Theme.color.bg, onClick = function()
		if s.trained then
			return
		end
		s.trained = true
		s.trainBtn.Visible = false
		sc.store:set("loreTrained", true)
		sc.shell:setText(S.lambdaWhy:format(Format.lambda(m.lambda)) .. "\n\n" .. S.interpret:format(Format.num(-m.a[1] * 100, 2), Format.num(m.a[2], 2)))
		sc:progress()
		L2.draw(sc)
	end })
	local T = sc.T
	sc:formula({
		id = "LORE_LAMBDA", title = S.lambdaTitle,
		lines = { { id = "eq", open = true, general = { T.sym("λ", "penalty"), " = ", T.col(Format.lambda(m.lambda), "penalty") } } },
	})
	sc:formula({
		id = "LORE_MODEL", title = S.modelTitle, toNotebook = true,
		lines = {
			{ id = "std", hint = S.lockTrain,
				general = { T.hat("y"), " = ", T.sub("b", "0"), " + ", T.sub("b", "р", "m_dist"), "·", T.sub("z", "расст"), " + ", T.sub("b", "п", "m"), "·", T.sub("z", "пчёлы"),
					" + ", T.sub("b", "т", "m_temp"), "·", T.sub("z", "темп") },
				numbers = function()
					return { T.hat("y"), " = ", Format.num(m.b0, 1), " ", Format.MINUS, " ", T.col(Format.num(-m.b[1], 2), "m_dist"), "·", T.sub("z", "р"),
						" + ", T.col(Format.num(m.b[2], 2), "m"), "·", T.sub("z", "п"), " + ", T.col(Format.num(m.b[3], 0), "m_temp"), "·", T.sub("z", "т") }
				end },
			{ id = "raw", hint = S.lockTrain,
				general = { S.honeyWord, " = ", T.sub("a", "0"), " + ", T.sub("a", "р", "m_dist"), "·", S.distWord, " + ", T.sub("a", "п", "m"), "·", S.beesWord },
				numbers = function()
					return { S.honeyWord, " = ", Format.num(m.a0, 2), " ", Format.MINUS, " ", T.col(Format.num(-m.a[1], 4), "m_dist"), "·", S.distWord, " + ",
						T.col(Format.num(m.a[2], 3), "m"), "·", S.beesWord }
				end },
		},
	})
	sc.shell:setText(S.lambdaGiven:format(Format.lambda(m.lambda)))
	L2.draw(sc)
end

function L2.draw(sc)
	local s, m = sc.s, model(sc)
	local L = s.plot:layer("bars", 3)
	L:begin()
	if s.trained then
		local colors = { Theme.color.m_dist, Theme.color.m, Theme.color.m_temp }
		for j = 1, 3 do
			local v = m.b[j]
			L:rect(j - 0.3, 0, j + 0.3, v, { color = colors[j], transparency = 0.1 })
			L:label(j, v, Format.num(v, 2), { anchor = Vector2.new(0.5, if v >= 0 then 1 else 0), dy = if v >= 0 then -2 else 2, size = 18, font = Theme.fontBold })
			local px = s.plot:toPx(j, 0)
			local _, ph = s.plot:size()
			L:labelPx(px, ph + 6, S.featureNames[j], { anchor = Vector2.new(0.5, 0), size = 15, color = colors[j] })
		end
		L:label(3, 0, S.tempOff, { anchor = Vector2.new(0.5, 1), dy = -26, size = 15, color = Theme.color.m_temp })
	end
	L:finish()
end

L2.unlocks = {
	{ formula = "LORE_MODEL", line = "std", when = function(sc) return sc.s.trained end },
	{ formula = "LORE_MODEL", line = "raw", when = function(sc) return sc.s.trained end },
}

function L2.canAdvance(sc)
	return sc.s.trained == true
end

-- ───── L.3 сбор данных ─────

local L3 = { id = "L.3", panel = false }

function L3.enter(sc)
	local lw = sc.shared.loreWorld
	local m = model(sc)
	local st = sc.shared.lore
	local n = #sc.Datasets.lore.player_hives
	for i = 1, n do
		local h = lw.hives[i]
		h.prompt.ActionText = S.promptCount
		h.prompt.Enabled = st.bees[i] == nil
		lw.meadows[i].prompt.Enabled = st.dist[i] == nil
		lw:setCard(i, cardText(sc, i))
		sc:conn(h.prompt.Triggered:Connect(function()
			if st.bees[i] == nil then
				st.bees[i] = sc.Datasets.lore.player_hives[i].bees_k
				h.prompt.Enabled = false
				sc:toast(S.beesCounted:format(i, Format.num(st.bees[i], 1)), Theme.color.m)
				L3.changed(sc, i)
			end
		end))
		sc:conn(lw.meadows[i].prompt.Triggered:Connect(function()
			if st.dist[i] == nil then
				st.dist[i] = sc.Datasets.lore.player_hives[i].distance_to_meadow_m
				lw.meadows[i].prompt.Enabled = false
				sc:toast(S.distMeasured:format(i, Format.num(st.dist[i], 0)), Theme.color.m_dist)
				L3.changed(sc, i)
			end
		end))
	end
	sc.s.model = m
	L3.refreshAction(sc)
end

function L3.changed(sc, i: number)
	sc.shared.loreWorld:setCard(i, cardText(sc, i))
	sc.store:set("loreTick", os.clock())
	sc:progress()
	L3.refreshAction(sc)
end

-- Кнопка HUD: «Внести данные улья N» (как только для улья известны оба признака) или пчела-помощник
function L3.refreshAction(sc)
	local st = sc.shared.lore
	local n = #sc.Datasets.lore.player_hives
	for i = 1, n do
		if st.bees[i] and st.dist[i] and not st.entered[i] then
			sc.hud:setAction("primary", S.enter:format(i), function()
				L3.enter_(sc, i)
			end)
			return
		end
	end
	if st.manual >= MANUAL_HIVES and not st.helper then
		local missing = false
		for i = 1, n do
			if st.bees[i] == nil then missing = true end
		end
		if missing then
			sc.hud:setAction("primary", S.helper, function()
				st.helper = true
				local lw = sc.shared.loreWorld
				for k = 1, n do
					if st.bees[k] == nil then
						st.bees[k] = sc.Datasets.lore.player_hives[k].bees_k
						lw.hives[k].prompt.Enabled = false
						lw:setCard(k, cardText(sc, k))
					end
				end
				sc:toast(S.helperDone, Theme.color.c)
				sc.store:set("loreTick", os.clock())
				L3.refreshAction(sc)
			end)
			return
		end
	end
	sc.hud:setAction("primary", nil)
end

function L3.enter_(sc, i: number)
	local st = sc.shared.lore
	if st.entered[i] then
		return
	end
	st.entered[i] = true
	st.manual += 1
	local row = hiveRow(sc, i)
	row[1], row[2] = st.dist[i], st.bees[i]
	st.pred[i] = sc.s.model.predict(row)
	sc:toast(S.predicted:format(i, kg(st.pred[i])), Theme.color.loss)
	L3.changed(sc, i)
end

function L3.exit(sc)
	sc.hud:setAction("primary", nil)
end

function L3.canAdvance(sc)
	local st = sc.shared.lore
	for i = 1, #sc.Datasets.lore.player_hives do
		if not st.entered[i] then
			return false
		end
	end
	return true
end

function L3.hintTargets(sc)
	local st, lw = sc.shared.lore, sc.shared.loreWorld
	for i = 1, #lw.hives do
		if st.bees[i] == nil then
			return { lw.hives[i].model }
		elseif st.dist[i] == nil then
			return { lw.meadows[i].model }
		end
	end
	return {}
end

-- ───── L.4 сбор мёда ─────

local L4 = { id = "L.4", panel = false }

function L4.enter(sc)
	local lw = sc.shared.loreWorld
	local st = sc.shared.lore
	sc:toast(S.season, Theme.color.c)
	for i, h in lw.hives do
		h.prompt.ActionText = S.promptHarvest
		h.prompt.Enabled = st.real[i] == nil
		sc:conn(h.prompt.Triggered:Connect(function()
			if st.real[i] == nil then
				st.real[i] = sc.Datasets.lore.player_hives[i].honey_kg
				h.prompt.Enabled = false
				lw:setCard(i, cardText(sc, i))
				sc:toast(S.harvested:format(i, kg(st.real[i]), kg(st.pred[i])), Theme.color.c)
				sc.store:set("loreTick", os.clock())
				sc:progress()
			end
		end))
	end
end

function L4.canAdvance(sc)
	local st = sc.shared.lore
	for i = 1, #sc.Datasets.lore.player_hives do
		if st.real[i] == nil then
			return false
		end
	end
	return true
end

function L4.hintTargets(sc)
	local st, lw = sc.shared.lore, sc.shared.loreWorld
	for i, h in lw.hives do
		if st.real[i] == nil then
			return { h.model }
		end
	end
	return {}
end

-- ───── L.5 проверка R² ─────

local L5 = { id = "L.5", panel = true, milestone = "regression_lore" }
L5.nextLabel = S.finish

function L5.enter(sc)
	local s, st, m = sc.s, sc.shared.lore, model(sc)
	local n = #sc.Datasets.lore.player_hives
	local xs, real, pred = {}, {}, {}
	for i = 1, n do
		xs[i], real[i], pred[i] = i, st.real[i], st.pred[i]
	end
	s.view = R2View.new(sc.shell.main, {
		x = xs, y = real, yhat = pred, markers = true,
		xMin = 0.5, xMax = n + 0.5, xTicks = xs, yMin = 15, yMax = 45, yTicks = { 15, 20, 25, 30, 35, 40, 45 },
		xLabel = S.hiveAxis, yLabel = Strings.s2d["2D.2"].yLabel, unit = "кг²", meanStart = 18, snapTol = 1.0, store = sc.store,
		onPhase = function(phase)
			sc.shell:setText(Strings.s2d["2D.7"].phase[phase] or "")
			sc:progress()
		end,
		onChanged = function() sc:progress() end,
	})
	sc:conn({ Disconnect = function() s.view:Destroy() end })
	S2D7.formulas(sc, s.view)
	s.olsBtn = sc.shell:button(S.whatIfOls, { order = 1, visible = false, onClick = function()
		if s.olsShown then
			return
		end
		s.olsShown = true
		s.olsBtn.Visible = false
		local olsPred = {}
		for i = 1, n do
			olsPred[i] = m.predict(hiveRow(sc, i), "ols")
		end
		local r2ols = sc.MathCore.r2(real, olsPred)
		local preds = {}
		for i = 1, n do
			table.insert(preds, Format.num(olsPred[i], 1))
		end
		sc.shell:setText(S.olsResult:format(table.concat(preds, "; "), Format.num(r2ols, 2), Format.num(m.ols.b[2], 2), Format.num(m.ols.b[3], 2)))
		sc:note(S.olsNote)
		sc:progress()
	end })
	sc.shell:setText(Strings.s2d["2D.7"].phase.res)
end

L5.unlocks = {
	S2D7.r2Unlocks[1], S2D7.r2Unlocks[2],
	{ formula = "R2", line = "eq", when = S2D7.r2Unlocks[3].when, onUnlock = function(sc)
		sc.s.olsBtn.Visible = true
		sc.shell:setText(S.r2Done)
	end },
}

function L5.canAdvance(sc)
	return sc.s.olsShown == true
end

function L5.exit(sc)
	sc:honey(3)
	if sc.hud then
		sc.hud:toast(S.moduleDone, Theme.color.good)
	end
end

function L5.hintTargets(sc)
	local v = sc.s.view
	if v.phase == "done" then
		return { sc.s.olsBtn }
	end
	return { v.plot.area }
end

function L5.hintText(sc, level)
	local v = sc.s.view
	return Strings.hints["2D.7"][v.phase] and Strings.hints["2D.7"][v.phase][level] or nil
end

return { L0, L1, L2, L3, L4, L5 }
