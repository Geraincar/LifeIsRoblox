--!nonstrict
-- Flow3D: машина сцен 3D experience (3D.1 → 3D.6 → «2D»: дальше ведёт SceneMachine экранов 2D и лора).
-- Каждая сцена: enter(flow), exit(flow)?, update(flow, snap)?, canAdvance(flow, snap), hintTargets(flow).
-- Переход только по действию игрока; анимации ≤ 3 с; подсказки — 3 уровня («?» или 45 с без прогресса).

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local Records = require(Regression.Core.Records)
local Format = require(Regression.Core.Format)
local Theme = require(Regression.UI.Theme)
local Strings = require(Regression.UI.Strings)

local Flow3D = {}
Flow3D.__index = Flow3D

local ORDER = { "3D.1", "3D.2", "3D.3", "3D.4", "3D.5", "3D.6", "2D" }

local function allTrue(t: { boolean }, n: number): boolean
	for i = 1, n do
		if not t[i] then
			return false
		end
	end
	return true
end

-- ctx: store, hud, bed, board, nextBoard, controls, lineModel, MathCore, open2D (открыть экран 2D), onMilestone?
function Flow3D.new(ctx)
	local self = setmetatable({}, Flow3D)
	for k, v in ctx do
		self[k] = v
	end
	self.n = self.lineModel.n
	self.index = 0
	self.threadStart = {} -- i → os.clock() начала анимации нити
	self.squareStart = {}
	self.manualThreads = 0
	self.lastProgress = os.clock()
	self.hintLevel = 0
	self.highlights = {}
	self.watchers = {}
	self.scenes = self:_buildScenes()

	for i, f in self.bed.flowers do
		f.prompt.Triggered:Connect(function()
			self:_onFlowerPrompt(i)
		end)
	end
	self.bed.controlPrompt.Triggered:Connect(function()
		self.controls:enter()
	end)
	self.hud.onHintRequest = function()
		self:requestHint()
	end
	return self
end

function Flow3D:start()
	self:goto(1)
end

function Flow3D:sceneId(): string
	return ORDER[self.index]
end

function Flow3D:progress()
	self.lastProgress = os.clock()
end

function Flow3D:goto(i: number)
	local cur = self.scenes[ORDER[self.index]]
	if cur and cur.exit then
		cur.exit(self)
	end
	self.index = i
	local id = ORDER[i]
	self.store:set("scene", id)
	self.hud:setStep(id)
	self:clearHint()
	self:progress()
	self.scenes[id].enter(self)
end

function Flow3D:addHoney(n: number)
	local v = (self.store:get("honey") or 0) + n
	self.store:set("honey", v)
	self.hud:setHoney(v)
end

function Flow3D:setPrediction(key: string, value: number)
	local p = table.clone(self.store:get("predictions") or {})
	p[key] = value
	self.store:set("predictions", p)
end

-- ───── анимации нитей и квадратов ─────

function Flow3D:visuals(now: number)
	local tg, sg = {}, {}
	local animating = false
	for i = 1, self.n do
		local ts, ss = self.threadStart[i], self.squareStart[i]
		tg[i] = if ts then math.clamp((now - ts) / Config.THREAD_GROW_S, 0, 1) else 0
		sg[i] = if ss then math.clamp((now - ss) / Config.SQUARE_GROW_S, 0, 1) else 0
		if (ts and tg[i] < 1) or (ss and sg[i] < 1) then
			animating = true
		end
	end
	return { threadGrow = tg, squareGrow = sg, animating = animating }
end

function Flow3D:drawThread(i: number, delay: number?)
	local threads = table.clone(self.store:get("threads"))
	if threads[i] then
		return
	end
	threads[i] = true
	self.store:set("threads", threads)
	self.threadStart[i] = os.clock() + (delay or 0)
	self.bed.flowers[i].prompt.ActionText = Strings.prompt.card
	self:progress()
end

function Flow3D:_onFlowerPrompt(i: number)
	if self:sceneId() == "3D.2" and not self.store:get("threads")[i] then
		self.manualThreads += 1
		self:drawThread(i)
		if self.manualThreads == 1 then
			self.board:setMessage(Strings.msg.firstThread, Theme.color.residual)
		end
		local threads = self.store:get("threads")
		if self.manualThreads >= Config.MANUAL_THREADS_BEFORE_AUTO and not allTrue(threads, self.n) then
			self.hud:setAction("primary", Strings.hud.restThreads, function()
				local k = 0
				for j = 1, self.n do
					if not self.store:get("threads")[j] then
						self:drawThread(j, k * 0.12)
						k += 1
					end
				end
				self.hud:setAction("primary", nil)
			end)
		end
	elseif self.store:get("threads")[i] then
		self.bed:toggleCard(i)
		self.store:set("cardsTick", os.clock()) -- перерисовать клумбу
	end
end

-- ───── запись точки на табло (R, кнопка табло, кнопка пульта) ─────

function Flow3D:record()
	local st = self.store
	if not st:get("recordEnabled") then
		return
	end
	local snap = self.lineModel:compute(st:get("m"), st:get("h"))
	local records = st:get("records")
	local ok, reason, other = Records.validate(records, snap.m, snap.h)
	if not ok then
		if reason == "too_close" and other then
			self.hud:toast(Strings.msg.recordTooClose:format(Format.coef(other.m)), Theme.color.c)
		else
			self.hud:toast(Strings.msg.recordFull, Theme.color.c)
		end
		return
	end
	records = Records.add(records, { m = snap.m, mse = snap.mse, h = snap.h })
	st:set("records", records)
	self.hud:toast(Strings.msg.recordAdded:format(Format.coef(snap.m), Format.mse(snap.mse)), Theme.color.loss)
	self.hud:flash(self.board.recordBtn)
	self:progress()

	local cur = Records.atHeight(records, snap.h)
	if #cur == Config.ONE_SIDE_CHECK_AFTER then
		if Records.oneSide(cur, self.lineModel.mOpt) then
			self.board:setMessage(Strings.msg.oneSide, Theme.color.c)
			self.hud:toast(Strings.msg.oneSide, Theme.color.c)
		elseif (st:get("predictions") or {}).minimum == nil then
			self.hud:ask(Strings.predictions.minimum, function(k)
				self:setPrediction("minimum", k)
				self:progress()
			end)
		end
	end
end

-- ───── подсказки ─────

function Flow3D:clearHighlights()
	for _, h in self.highlights do
		h:Destroy()
	end
	self.highlights = {}
end

function Flow3D:highlight(targets: { Instance })
	self:clearHighlights()
	for _, t in targets do
		local h = Instance.new("Highlight")
		h.FillColor = Theme.color.loss
		h.FillTransparency = 0.75
		h.OutlineColor = Theme.color.loss
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Adornee = t
		h.Parent = t
		table.insert(self.highlights, h)
	end
end

function Flow3D:clearHint()
	self.hintLevel = 0
	self.hud:hideHint()
	self:clearHighlights()
end

function Flow3D:showHint(level: number)
	local id = self:sceneId()
	local texts = Strings.hints[id]
	local scene = self.scenes[id]
	if not texts or not scene then
		return
	end
	self.hintLevel = level
	local text = texts[level]
	if scene.hintText then
		text = scene.hintText(self, level) or text
	end
	self.hud:showHint(level, text)
	if scene.hintTargets then
		self:highlight(scene.hintTargets(self))
	end
	local shownLevel = level
	task.delay(15, function()
		if self.hintLevel == shownLevel and self:sceneId() == id then
			self.hud:hideHint()
			self:clearHighlights()
		end
	end)
end

function Flow3D:requestHint()
	self:showHint(math.min(self.hintLevel + 1, 3))
	self:progress()
end

-- ───── кадр ─────

function Flow3D:tick(snap, now: number)
	local st = self.store
	local id = self:sceneId()
	local scene = self.scenes[id]
	if scene.update then
		scene.update(self, snap)
	end
	for _, w in table.clone(self.watchers) do
		w(self, snap)
	end

	-- кнопка «Управлять прямой» для телефона и мыши
	local wantControlBtn = st:get("controlUnlocked") == true and st:get("inZone") == true and not st:get("controlMode")
	if wantControlBtn ~= self.controlBtnShown then
		self.controlBtnShown = wantControlBtn
		if wantControlBtn then
			self.hud:setAction("control", Strings.hud.control, function()
				self.controls:enter()
			end)
		else
			self.hud:setAction("control", nil)
		end
	end

	if scene.canAdvance and scene.canAdvance(self, snap) and self.index < #ORDER then
		self:goto(self.index + 1)
		return
	end

	-- 45 с без прогресса → следующий уровень подсказки (автоматически не дальше 2-го)
	if now - self.lastProgress > Config.HINT_IDLE_S and self.hintLevel < 2 then
		self:showHint(self.hintLevel + 1)
		self:progress()
	end
end

function Flow3D:watch(fn)
	table.insert(self.watchers, fn)
	return function()
		local i = table.find(self.watchers, fn)
		if i then
			table.remove(self.watchers, i)
		end
	end
end

-- ───── сцены ─────

function Flow3D:_buildScenes()
	local scenes = {}

	scenes["3D.1"] = {
		enter = function(f)
			f.board:setActive(false)
			f.board:setMessage(Strings.msg.idle)
		end,
		canAdvance = function(f)
			return f.store:get("inZone") == true
		end,
		exit = function(f)
			f.board:setActive(true)
		end,
		hintTargets = function(f)
			return { f.bed.soil }
		end,
	}

	scenes["3D.2"] = {
		enter = function(f)
			for _, fl in f.bed.flowers do
				f.controls:setPromptWanted(fl.prompt, true)
			end
		end,
		canAdvance = function(f)
			if not allTrue(f.store:get("threads"), f.n) then
				return false
			end
			local v = f:visuals(os.clock())
			for i = 1, f.n do
				if v.threadGrow[i] < 1 then
					return false
				end
			end
			return true
		end,
		exit = function(f)
			f.hud:setAction("primary", nil)
			f.board:setMessage(Strings.msg.threadsDone)
		end,
		hintTargets = function(f)
			local t = {}
			for i, fl in f.bed.flowers do
				if not f.store:get("threads")[i] then
					table.insert(t, fl.model)
				end
			end
			return t
		end,
	}

	scenes["3D.3"] = {
		enter = function(f)
			for i = 1, f.n do
				f.squareStart[i] = os.clock() + (i - 1) * 0.08
			end
			f.store:set("showMseFormula", true)
			f.board:setMessage(Strings.msg.squares, Theme.color.residual)
			f.hud:ask(Strings.predictions.squaresUp, function(k)
				f:setPrediction("squaresUp", k)
				f.store:set("controlUnlocked", true)
				f.controls:setPromptWanted(f.bed.controlPrompt, true)
				f.board:setMessage(Strings.msg.squares .. "\n" .. Strings.msg.controlHint, Theme.color.residual)
				f:progress()
				-- ответ на ставку — после действия: прямая выше всех цветков и поднята ещё на 0,1 м
				-- (тогда все e < 0 и каждый квадрат растёт с высотой — ответ «вырастут» верен строго)
				local crossH = nil
				local stop
				stop = f:watch(function(ff, snap)
					for i = 1, ff.n do
						if snap.e[i] >= 0 then
							crossH = nil
							return
						end
					end
					if crossH == nil then
						crossH = snap.h
						ff.hud:toast(Strings.msg.aboveAll, Theme.color.residual)
						return
					end
					if snap.h >= crossH + 0.1 - 1e-9 then
						stop()
						local correct = k == 1
						ff.hud:resolve(correct, Strings.predictions.squaresUp.reveal)
						if correct then
							ff:addHoney(1)
						end
					end
				end)
			end)
		end,
		update = function(f)
			if f.store:get("movedSlope") and not f.sawSlope then
				f.sawSlope = true
				f:progress()
			end
			if f.store:get("movedHeight") and not f.sawHeight then
				f.sawHeight = true
				f:progress()
			end
		end,
		canAdvance = function(f)
			local st = f.store
			return st:get("controlUnlocked") and st:get("movedSlope") and st:get("movedHeight")
		end,
		hintText = function(f, level)
			if not f.store:get("controlUnlocked") then
				return Strings.hints.betFirst
			end
			return nil
		end,
		hintTargets = function(f)
			return { if f.store:get("controlMode") then f.bed.line else f.bed.pedestal }
		end,
	}

	scenes["3D.4"] = {
		enter = function(f)
			f.store:set("recordEnabled", true)
			f.board:setMessage(Strings.msg.recordHint)
			f.lastRecordH = f.store:get("h")
		end,
		update = function(f, snap)
			-- высота сменилась при наличии записей — прежние бледнеют
			if not Records.sameHeight(snap.h, f.lastRecordH) then
				f.lastRecordH = snap.h
				local recs = f.store:get("records")
				if #recs > #Records.atHeight(recs, snap.h) then
					f.board:setMessage(Strings.msg.heightChanged, Theme.color.c)
				end
			end
		end,
		canAdvance = function(f, snap)
			return #Records.atHeight(f.store:get("records"), snap.h) >= Records.NEED
		end,
		exit = function(f)
			f.store:set("recordEnabled", false)
		end,
		hintTargets = function(f)
			return { f.bed.line, f.board.screen }
		end,
	}

	scenes["3D.5"] = {
		enter = function(f)
			local h = f.store:get("h")
			local cur = Records.atHeight(f.store:get("records"), h)
			local P = Records.fit(f.MathCore, cur)
			P.h = h
			P.records = cur
			f.store:set("parabola", P)
			f.store:set("mSnap", { target = P.tStar, tol = Config.SNAP_TOL })
			f.board:setMessage(Strings.msg.parabola:format(Format.coef(P.tStar), Format.num(math.deg(math.atan(P.tStar)), 1), Format.mse(P.vStar)), Theme.color.loss)
			local pick = (f.store:get("predictions") or {}).minimum
			if pick then
				local region = if P.tStar < 0 then 1 elseif P.tStar <= 0.5 then 2 else 3
				f.hud:resolve(pick == region, Strings.predictions.minimum.reveal:format(Format.coef(P.tStar)))
				if pick == region then
					f:addHoney(1)
				end
			else
				f.hud:closePrediction()
			end
		end,
		canAdvance = function(f, snap)
			local P = f.store:get("parabola")
			return P ~= nil and math.abs(snap.m - P.tStar) < 1e-9
		end,
		hintText = function(f, level)
			if level == 2 then
				local P = f.store:get("parabola")
				return Strings.hints["3D.5"][2]:format(Format.coef(P.tStar), Format.coef(f.store:get("m")))
			end
			return nil
		end,
		hintTargets = function(f)
			return { f.bed.line }
		end,
	}

	scenes["3D.6"] = {
		enter = function(f)
			if f.onMilestone then
				f.onMilestone("regression_3d") -- оптимальный наклон найден: 3D experience пройдено
			end
			local P = f.store:get("parabola")
			f.board:setMessage(Strings.msg.optimumFound .. "\n" .. Strings.msg.bestLineTip, Theme.color.good)
			f.hud:toast(Strings.msg.optimumFound, Theme.color.good)
			f.nextBoard:setParabola(P, P.records)
			f.nextBoard:rise(function()
				f.hud:toast(Strings.msg.nextBoard)
			end)
			-- бонус: лучшая прямая (m = m*, h = ȳ = 1,5 м) — в любой момент после 3D.5
			local stop
			stop = f:watch(function(ff, snap)
				if math.abs(snap.m - P.tStar) < 1e-9 and math.abs(snap.h - Config.BEST_H) < 1e-3 then
					stop()
					ff:addHoney(1)
					ff.board:setMessage(Strings.msg.bestLine:format(Format.mse(snap.mse)), Theme.color.good)
					ff.hud:toast(Strings.msg.bestLine:format(Format.mse(snap.mse)), Theme.color.good)
				end
			end)
		end,
		canAdvance = function(f)
			return f.store:get("opened2D") == true
		end,
		hintTargets = function(f)
			return { f.nextBoard.screen }
		end,
	}

	-- 3D пройдено: дальше экраны 2D (второе табло) и лор-задача — их ведёт SceneMachine
	scenes["2D"] = {
		enter = function(f) end,
		canAdvance = function()
			return false
		end,
	}

	return scenes
end

-- Вызывается вторым табло
function Flow3D:openScreen2D()
	self.controls:exit()
	self.store:set("opened2D", true)
	self:progress()
	if self.open2D then
		self.open2D()
	end
end

return Flow3D
