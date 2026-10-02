--!nonstrict
-- SceneMachine: сцены 2D experience (экраны 2D.1–2D.7) и лор-задачи (L.1–L.5).
-- Сцена — таблица:
--   id, panel (true — экран в оболочке Shell2D; false — задание в мире, оболочка закрыта, работает HUD),
--   enter(sc), exit(sc)?, update(sc, dt)? (≤ 30 Гц), canAdvance(sc) → boolean,
--   unlocks = { { formula = "DLDC", line = "zero", when = function(sc) … end } } — строка формулы открывается
--     ТОЛЬКО так: машина проверяет условия на каждом кадре и при изменениях Store,
--   hintTargets(sc) → { GuiObject | Instance }?, keepMain (не чистить графики при выходе: 2D.2 → 2D.3),
--   nextLabel (текст кнопки «Дальше»), autoAdvance (для сцен в мире — переход без кнопки).
-- Контекст сцены sc: store, shell, hud, machine, MathCore, Datasets, Format, Theme, Strings, Gui, T (токены формул),
--   f[id] — формулы сцены, s — локальное состояние, shared — общее для сцен,
--   sc:formula(spec), sc:conn(c), sc:keys(name, keys, fn), sc:progress(), sc:honey(n), sc:note(text).

local ContextActionService = game:GetService("ContextActionService")

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local Format = require(Regression.Core.Format)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)
local FormulaView = require(Regression.UI.FormulaView)
local PlayerControls = require(Regression.Input.PlayerControls)

local SceneMachine = {}
SceneMachine.__index = SceneMachine

local PRIORITY = Enum.ContextActionPriority.High.Value

-- ctx: store, shell, hud, MathCore, Datasets, scenes = { spec, … } (по порядку), onMilestone(id)?, onFinished()?
function SceneMachine.new(ctx)
	local self = setmetatable({}, SceneMachine)
	self.store = ctx.store
	self.shell = ctx.shell
	self.hud = ctx.hud
	self.MathCore = ctx.MathCore
	self.Datasets = ctx.Datasets
	self.onMilestone = ctx.onMilestone
	self.onSceneChanged = ctx.onSceneChanged
	self.order = {}
	self.byId = {}
	for i, spec in ctx.scenes do
		self.order[i] = spec.id
		self.byId[spec.id] = spec
	end
	self.index = 0
	self.shared = {}
	self.sc = nil
	self.lastProgress = os.clock()
	self.hintLevel = 0
	self.acc = 0

	self.shell.onNext = function()
		self:advance()
	end
	self.shell.onClose = function()
		PlayerControls.release("shell")
		self:_releaseKeys()
	end
	self.shell.onHint = function()
		self:requestHint()
	end
	self.store.Changed:Connect("*", function(_, key)
		if key ~= "highlight" then
			self:_checkUnlocks()
		end
	end)
	return self
end

function SceneMachine:current()
	return self.byId[self.order[self.index]]
end

function SceneMachine:sceneId(): string?
	return self.order[self.index]
end

function SceneMachine:has(id: string): boolean
	return self.byId[id] ~= nil
end

-- ───── контекст сцены ─────

local Ctx = {}
Ctx.__index = Ctx

function Ctx:formula(spec)
	local fv = self.shell:addFormula(spec, self.s)
	self.f[spec.id] = fv
	return fv
end

function Ctx:conn(c)
	table.insert(self.conns, c)
	return c
end

-- Клавиши сцены (ContextActionService, High + Sink): fn(down: boolean)
function Ctx:keys(name: string, keys: { Enum.KeyCode }, fn: (boolean) -> ())
	local action = "Reg2D_" .. name
	self.keyBinds[action] = { keys = keys, fn = fn }
	if self.machine.shell.isOpen or not self.spec.panel then
		self.machine:_bindKey(action, self.keyBinds[action])
	end
end

function Ctx:progress()
	self.machine:progress()
end

function Ctx:honey(n: number)
	local v = (self.store:get("honey") or 0) + n
	self.store:set("honey", v)
	if self.hud then
		self.hud:setHoney(v)
	end
end

function Ctx:note(text: string)
	self.shell.notebook:addNote(self.id, text)
	local notes = table.clone(self.store:get("notes") or {})
	table.insert(notes, text)
	self.store:set("notes", notes)
end

function Ctx:toast(text: string, color: Color3?)
	if self.spec.panel then
		self.shell:toast(text, color)
	elseif self.hud then
		self.hud:toast(text, color)
	end
end

function Ctx:refresh()
	for _, fv in self.f do
		fv:refresh(self.s)
	end
end

-- ───── переходы ─────

function SceneMachine:_makeCtx(spec)
	return setmetatable({
		id = spec.id, spec = spec, machine = self, store = self.store, shell = self.shell, hud = self.hud,
		MathCore = self.MathCore, Datasets = self.Datasets, Format = Format, Theme = Theme, Strings = Strings, Gui = Gui,
		T = FormulaView.T, Config = Config, f = {}, s = {}, shared = self.shared, conns = {}, keyBinds = {},
	}, Ctx)
end

function SceneMachine:_bindKey(action: string, b)
	ContextActionService:BindActionAtPriority(action, function(_, state)
		if state == Enum.UserInputState.Begin then
			b.fn(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			b.fn(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, table.unpack(b.keys))
end

function SceneMachine:_bindKeys()
	if self.sc then
		for action, b in self.sc.keyBinds do
			self:_bindKey(action, b)
		end
	end
end

function SceneMachine:_releaseKeys()
	if self.sc then
		for action, b in self.sc.keyBinds do
			ContextActionService:UnbindAction(action)
			b.fn(false)
		end
	end
end

function SceneMachine:_exitCurrent()
	local spec, sc = self:current(), self.sc
	if not spec or not sc then
		return
	end
	if spec.exit then
		spec.exit(sc)
	end
	self:_releaseKeys()
	for _, c in sc.conns do
		if typeof(c) == "RBXScriptConnection" or type(c) == "table" then
			c:Disconnect()
		end
	end
	self.shell:clearScene(spec.id, spec.keepMain)
	if self.hud then
		self.hud:setAction("primary", nil)
	end
	self.sc = nil
end

function SceneMachine:goto(id: string)
	local i = table.find(self.order, id)
	assert(i, "SceneMachine: нет сцены " .. tostring(id))
	self:_exitCurrent()
	self.index = i
	local spec = self.byId[id]
	local sc = self:_makeCtx(spec)
	sc.keepFrom = self.shared.keep -- графики, оставленные предыдущей сценой (keepMain)
	self.sc = sc
	self.store:set("scene2d", id)
	self.hintLevel = 0
	self:progress()
	local step = Strings.step[id]
	if self.hud then
		self.hud:setStep(id)
	end
	if spec.panel then
		self.shell:setHeader(id, if step then step.title else id)
		self.shell:setTask(if step then step.task else "")
		self.shell:setNext(false, spec.nextLabel)
		if not self.shell.isOpen then
			self:open()
		end
	else
		if self.shell.isOpen then
			self.shell:close()
			PlayerControls.release("shell")
		end
	end
	spec.enter(sc)
	self:_bindKeys()
	self:_checkUnlocks()
	if self.onSceneChanged then
		self.onSceneChanged(id)
	end
end

function SceneMachine:advance()
	local spec, sc = self:current(), self.sc
	if not spec or not sc or not spec.canAdvance(sc) then
		return
	end
	if spec.milestone and self.onMilestone then
		self.onMilestone(spec.milestone)
	end
	if self.index >= #self.order then
		self:_exitCurrent()
		self.shell:close()
		PlayerControls.release("shell")
		self.finished = true
		if self.onFinished then
			self.onFinished()
		end
		return
	end
	self:goto(self.order[self.index + 1])
end

-- Открыть оболочку (второе табло, NPC); сцена в мире — просто напоминание в HUD
function SceneMachine:open()
	local spec = self:current()
	if spec and not spec.panel then
		return
	end
	self.shell:open()
	PlayerControls.hold("shell")
	self:_bindKeys()
	self:progress()
end

function SceneMachine:start(id: string?)
	self:goto(id or self.order[1])
end

-- ───── открытие строк формул ─────

function SceneMachine:_checkUnlocks()
	local spec, sc = self:current(), self.sc
	if not spec or not sc or not spec.unlocks then
		return
	end
	for _, u in spec.unlocks do
		local fv = sc.f[u.formula]
		if fv and not fv:isUnlocked(u.line) then
			local ok, res = pcall(u.when, sc)
			if ok and res then
				fv:unlock(u.line)
				self:progress()
				if u.onUnlock then
					u.onUnlock(sc)
				end
			elseif not ok then
				warn("unlock " .. u.formula .. "." .. u.line .. ": " .. tostring(res))
			end
		end
	end
end

-- ───── подсказки ─────

function SceneMachine:progress()
	self.lastProgress = os.clock()
end

function SceneMachine:showHint(level: number)
	local spec, sc = self:current(), self.sc
	if not spec or not sc then
		return
	end
	local texts = Strings.hints[spec.id]
	if not texts then
		return
	end
	self.hintLevel = level
	local text = texts[level]
	if spec.hintText then
		text = spec.hintText(sc, level) or text
	end
	local targets = if spec.hintTargets then spec.hintTargets(sc) else {}
	if spec.panel then
		local guiTargets = {}
		for _, t in targets do
			if t:IsA("GuiObject") then
				table.insert(guiTargets, t)
			end
		end
		self.shell:showHint(level, text, guiTargets)
	elseif self.hud then
		self.hud:showHint(level, text)
	end
	local id, shown = spec.id, level
	task.delay(15, function()
		if self.hintLevel == shown and self:sceneId() == id then
			self.shell:hideHint()
			if self.hud then
				self.hud:hideHint()
			end
		end
	end)
end

function SceneMachine:requestHint()
	self:showHint(math.min(self.hintLevel + 1, 3))
	self:progress()
end

-- ───── кадр ─────

function SceneMachine:tick(dt: number)
	local spec, sc = self:current(), self.sc
	if not spec or not sc or self.finished then
		return
	end
	local active = spec.panel and self.shell.isOpen or not spec.panel
	if not active then
		return
	end
	self.acc += dt
	if self.acc >= 1 / Config.UI_HZ then
		local step = self.acc
		self.acc = 0
		if spec.update then
			spec.update(sc, step)
		end
		sc:refresh()
		self:_checkUnlocks()
	end
	local can = spec.canAdvance(sc)
	if can and spec.autoAdvance then
		self:advance()
		return
	end
	if spec.panel then
		if can ~= self.shell.nextEnabled then
			self.shell:setNext(can, spec.nextLabel)
			if can then
				self.shell:flash(self.shell.nextBtn)
			end
		end
	elseif can and spec.autoAdvance ~= false then
		self:advance()
		return
	end
	if os.clock() - self.lastProgress > Config.HINT_IDLE_S and self.hintLevel < 2 then
		self:showHint(self.hintLevel + 1)
		self:progress()
	end
end

return SceneMachine
