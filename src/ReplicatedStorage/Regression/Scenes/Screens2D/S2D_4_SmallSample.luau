--!nonstrict
-- 2D.4 Мало данных — коэффициенты «пляшут» (интерактивный 3D).
-- 15 точек (пчёлы, температура → мёд), первые 5 — малая выборка (залитые шары), остальные 10 — кольца.
-- Действия: повернуть облако ≥ 90°, ставка → «Проверить на остальных 10», переключить «на 5 / на 15»,
-- тапнуть 2 точки из остальных (карточка: прогноз и ошибка). После всех действий — строка-итог про Ridge и Lasso.

local Regression = script.Parent.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Format = require(Regression.Core.Format)
local Strings = require(Regression.UI.Strings)
local Viewport3D = require(Regression.UI.Viewport3D)

local S = Strings.s2d["2D.4"]
local NEED_YAW = 90
local NEED_TAPS = 2
local PICK_PX = 18

-- данные → мир вьюпорта
local function toWorld(bees: number, temp: number, honey: number): Vector3
	return Vector3.new((bees - 35) / 4, (honey - 10) / 4, -(temp - 21) / 2.5)
end

local scene = { id = "2D.4", panel = true }

local function fitModel(MathCore, X, y)
	local Z, mu, sd = MathCore.standardize(X)
	local b0, b = MathCore.ols(Z, y)
	local a0, a = MathCore.toRawUnits(b0, b, mu, sd)
	return { b0 = b0, b = b, a0 = a0, a = a, mu = mu, sd = sd }
end

local function predict(model, bees: number, temp: number): number
	return model.a0 + model.a[1] * bees + model.a[2] * temp
end

function scene.enter(sc)
	local s, MathCore = sc.s, sc.MathCore
	local rows = sc.Datasets.small_sample.rows
	s.rows = rows
	local X5, y5, Xall, yall, yrest = {}, {}, {}, {}, {}
	for _, r in rows do
		table.insert(Xall, { r.bees_k, r.temperature_C })
		table.insert(yall, r.honey_kg)
		if r.sample == "first5" then
			table.insert(X5, { r.bees_k, r.temperature_C })
			table.insert(y5, r.honey_kg)
		else
			table.insert(yrest, r.honey_kg)
		end
	end
	s.m5 = fitModel(MathCore, X5, y5)
	s.m15 = fitModel(MathCore, Xall, yall)
	local function preds(model, filter)
		local out = {}
		for _, r in rows do
			if filter == nil or r.sample == filter then
				table.insert(out, predict(model, r.bees_k, r.temperature_C))
			end
		end
		return out
	end
	s.r2first5 = MathCore.r2(y5, preds(s.m5, "first5"))
	s.r2rest = MathCore.r2(yrest, preds(s.m5, "rest"))
	s.r2all = MathCore.r2(yall, preds(s.m15, nil))
	s.corr = nil
	s.on = 5
	s.checked, s.toggled15, s.tapped, s.nTapped = false, false, {}, 0
	s.model = s.m5

	-- ── вьюпорт ──
	local vp = Viewport3D.new(sc.shell.main, { center = Vector3.new(0, 3, 0), radius = 17, yaw = math.rad(30), pitch = math.rad(20) })
	s.vp = vp
	sc:conn({ Disconnect = function() vp:Destroy() end })
	-- оси
	local o = toWorld(15, 12, 10)
	s.axisEnds = {
		{ toWorld(58, 12, 10), S.axisBees },
		{ toWorld(15, 32, 10), S.axisTemp },
		{ toWorld(15, 12, 37), S.axisHoney },
	}
	for _, e in s.axisEnds do
		vp:segment(nil, o, e[1], 0.08, Theme.color.axis)
	end
	-- точки
	s.balls, s.resid = {}, {}
	for i, r in rows do
		local first = r.sample == "first5"
		local p = toWorld(r.bees_k, r.temperature_C, r.honey_kg)
		s.balls[i] = vp:part({ Name = "Point" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * (if first then 0.6 else 0.22),
			CFrame = CFrame.new(p), Color = if first then Theme.color.loss else Theme.color.text, Material = Enum.Material.SmoothPlastic })
		s.resid[i] = vp:part({ Name = "Resid" .. i, Color = Theme.color.residual, Transparency = 1 })
	end
	-- плоскость модели — сетка из линий (линейная функция на прямоугольнике — параллелограмм, одним Part не нарисовать)
	s.net = {}
	for k = 1, 12 do
		s.net[k] = vp:part({ Name = "Net" .. k, Color = Theme.color.m, Transparency = 0.25 })
	end
	-- оверлей: подписи осей, кольца остальных точек, карточка
	s.axisLabels = {}
	for i, e in s.axisEnds do
		s.axisLabels[i] = Gui.label({ Text = e[2], TextSize = 16, TextColor3 = Theme.color.textDim, AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0), TextWrapped = false, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = vp.overlay })
	end
	s.rings = {}
	for i, r in rows do
		if r.sample == "rest" then
			local ring = Gui.frame({ Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 6, Parent = vp.overlay })
			Gui.corner(UDim.new(0.5, 0)).Parent = ring
			Gui.stroke(Theme.color.loss, 2).Parent = ring
			s.rings[i] = ring
		end
	end
	s.card = Gui.label({ Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.color.bg,
		BackgroundTransparency = 0.05, TextSize = 16, Visible = false, ZIndex = 8, Parent = vp.overlay })
	Gui.corner().Parent = s.card
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = s.card })
	s.legend = Gui.label({ Text = S.legend, TextSize = 15, TextColor3 = Theme.color.textDim, Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 20), ZIndex = 6, Parent = vp.overlay })
	s.rotLabel = Gui.label({ Text = "", TextSize = 15, TextColor3 = Theme.color.textDim, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -6), Size = UDim2.new(1, -20, 0, 20), ZIndex = 6, Parent = vp.overlay })

	vp.onCamera = function()
		scene.overlay(sc)
		sc:progress()
	end
	vp.onTap = function(pos)
		scene.tap(sc, pos)
	end

	-- ── управление ──
	s.toggleBtn = sc.shell:button(S.train15, { order = 1, onClick = function() scene.toggle(sc) end })
	Gui.stroke(Theme.color.m, 2).Parent = s.toggleBtn
	s.checkBtn = sc.shell:button(S.check, { order = 2, color = Theme.color.loss, textColor = Theme.color.bg, onClick = function()
		scene.check(sc)
	end })
	sc.shell:button(S.resetView, { order = 3, onClick = function() vp:reset() end })

	-- ── формулы ──
	local T = sc.T
	sc:formula({
		id = "PLANE", title = S.planeTitle, toNotebook = true,
		lines = {
			{ id = "eq", open = true,
				general = { T.hat("y"), " = ", T.sub("b", "0"), " + ", T.sub("b", "1", "m"), "·", T.sub("z", "пчёлы"), " + ",
					T.sub("b", "2", "m_temp"), "·", T.sub("z", "темп") },
				numbers = function(st)
					local b = st.model.b
					return { T.hat("y"), " = ", Format.num(st.model.b0, 2), " + ", T.col(Format.num(b[1], 2), "m"), "·", T.sub("z", "1"),
						" " .. (if b[2] < 0 then Format.MINUS else "+") .. " ", T.col(Format.num(math.abs(b[2]), 2), "m_temp"), "·", T.sub("z", "2") }
				end },
		},
	})
	sc:formula({
		id = "R2", title = S.r2Title, toNotebook = true,
		lines = {
			{ id = "first5", open = true, general = { S.r2first5 }, result = function(st) return Format.num(st.r2first5, 3) end },
			{ id = "rest", hint = S.lockRest, general = { S.r2rest }, result = function(st) return Format.num(st.r2rest, 3) end },
			{ id = "all", hint = S.lockAll, general = { S.r2all }, result = function(st) return Format.num(st.r2all, 3) end },
		},
	})
	sc.shell:setText(S.intro:format(Format.num(s.m5.b[2], 2)))
	scene.applyModel(sc)
	scene.overlay(sc)
end

function scene.applyModel(sc)
	local s = sc.s
	local model = s.model
	local vp = s.vp
	local k = 0
	for _, bees in { 15, 25, 35, 45, 55 } do
		k += 1
		vp:segment(s.net[k], toWorld(bees, 12, predict(model, bees, 12)), toWorld(bees, 31, predict(model, bees, 31)), 0.06, Theme.color.m)
	end
	for _, temp in { 12, 16.75, 21.5, 26.25, 31 } do
		k += 1
		vp:segment(s.net[k], toWorld(15, temp, predict(model, 15, temp)), toWorld(55, temp, predict(model, 55, temp)), 0.06, Theme.color.m)
	end
	for j = k + 1, #s.net do
		s.net[j].Transparency = 1
	end
	for i, r in s.rows do
		local show = s.checked and (r.sample == "rest" or s.on == 15)
		local part = s.resid[i]
		if show then
			local yhat = predict(model, r.bees_k, r.temperature_C)
			vp:segment(part, toWorld(r.bees_k, r.temperature_C, r.honey_kg), toWorld(r.bees_k, r.temperature_C, yhat), 0.07, Theme.color.residual)
		else
			part.Transparency = 1
		end
	end
	scene.overlay(sc)
end

function scene.overlay(sc)
	local s = sc.s
	local vp = s.vp
	for i, e in s.axisEnds do
		local x, y, vis = vp:project(e[1])
		s.axisLabels[i].Visible = vis
		s.axisLabels[i].Position = UDim2.fromOffset(x, y)
	end
	for i, ring in s.rings do
		local r = s.rows[i]
		local x, y, vis = vp:project(toWorld(r.bees_k, r.temperature_C, r.honey_kg))
		ring.Visible = vis
		ring.Position = UDim2.fromOffset(x, y)
		local st = ring:FindFirstChildOfClass("UIStroke")
		st.Color = if s.selected == i then Theme.color.c else Theme.color.loss
	end
	if s.selected then
		local r = s.rows[s.selected]
		local x, y, vis = vp:project(toWorld(r.bees_k, r.temperature_C, r.honey_kg))
		s.card.Visible = vis
		s.card.Position = UDim2.fromOffset(x + 14, y - 10)
	else
		s.card.Visible = false
	end
	s.rotLabel.Text = if vp.totalYaw < NEED_YAW then S.rotate:format(math.floor(vp.totalYaw)) else S.rotated
	s.rotated = vp.totalYaw >= NEED_YAW
end

function scene.tap(sc, pos: Vector2)
	local s = sc.s
	local best, bestD = nil, PICK_PX
	for i, r in s.rows do
		local x, y, vis = s.vp:project(toWorld(r.bees_k, r.temperature_C, r.honey_kg))
		if vis then
			local d = (Vector2.new(x, y) - pos).Magnitude
			if d < bestD then
				best, bestD = i, d
			end
		end
	end
	if best == nil or best == s.selected then
		s.selected = nil
		scene.overlay(sc)
		return
	end
	s.selected = best
	local r = s.rows[best]
	local yhat = predict(s.model, r.bees_k, r.temperature_C)
	s.card.Text = S.card:format(best, Format.num(r.bees_k, 1), Format.num(r.temperature_C, 1), Format.unit(r.honey_kg, 1, "кг"),
		Format.unit(yhat, 1, "кг"), Format.signed(r.honey_kg - yhat, 1), if r.sample == "first5" then S.cardFirst5 else S.cardRest)
	if r.sample == "rest" and not s.tapped[best] then
		s.tapped[best] = true
		s.nTapped += 1
	end
	sc:progress()
	scene.overlay(sc)
	scene.checkFinal(sc)
end

function scene.check(sc)
	local s = sc.s
	if s.checked or s.asking then
		return
	end
	s.asking = true
	sc.shell:ask(S.bet, function(k)
		s.checked = true
		s.checkBtn.Visible = false
		scene.applyModel(sc)
		local correct = k == 2
		sc.shell:resolve(correct, S.bet.reveal:format(Format.num(s.r2rest, 2)))
		if correct then
			sc:honey(1)
		end
		sc:progress()
		scene.checkFinal(sc)
	end)
end

function scene.toggle(sc)
	local s = sc.s
	s.on = if s.on == 5 then 15 else 5
	s.model = if s.on == 5 then s.m5 else s.m15
	s.toggleBtn.Text = if s.on == 5 then S.train15 else S.train5
	if s.on == 15 and not s.toggled15 then
		s.toggled15 = true
		sc.shell:toast(S.after15, Theme.color.good)
	end
	if s.selected then
		scene.tap(sc, Vector2.new(-1000, -1000)) -- закрыть карточку (прогноз изменился)
	end
	scene.applyModel(sc)
	sc:progress()
	scene.checkFinal(sc)
end

function scene.checkFinal(sc)
	local s = sc.s
	if s.final then
		return
	end
	if s.rotated and s.checked and s.toggled15 and s.nTapped >= NEED_TAPS then
		s.final = true
		sc.shell:setText(S.final)
		sc:note(S.final)
	end
end

function scene.update(sc)
	local s = sc.s
	if not s.final and s.rotated then
		scene.checkFinal(sc)
	end
end

-- Строки R² открываются действиями: проверка на остальных 10 и переключение на 15 точек
scene.unlocks = {
	{ formula = "R2", line = "rest", when = function(sc) return sc.s.checked end },
	{ formula = "R2", line = "all", when = function(sc) return sc.s.toggled15 end },
}

function scene.canAdvance(sc)
	return sc.s.final == true
end

function scene.hintTargets(sc)
	local s = sc.s
	if not s.rotated then
		return { s.vp.frame }
	elseif not s.checked then
		return { s.checkBtn }
	elseif not s.toggled15 then
		return { s.toggleBtn }
	end
	return { s.vp.frame }
end

function scene.hintText(sc, level)
	local s = sc.s
	local key = if not s.rotated then "rotate" elseif not s.checked then "check" elseif not s.toggled15 then "toggle" else "tap"
	return Strings.hints["2D.4"][key][level]
end

return scene
