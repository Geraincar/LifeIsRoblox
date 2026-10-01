--!nonstrict
-- LineControls: режим управления прямой.
--   Q/E — наклон (угол ±20°/с, m = tan угла), Shift/Ctrl — высота h (0,5 м/с, при отпускании — на сетку 0,05 м),
--   R — записать, X — выйти. Геймпад: R1/L1 — наклон, R2/L2 — высота, X — запись, B — выход.
--   Телефон и мышь: кнопки пульта в Hud (удержание = непрерывное изменение).
-- ContextActionService с приоритетом High и Sink: клавиши не уходят персонажу и shift-lock.
-- На время режима: движение персонажа выключено, shift-lock запрещён, ProximityPrompt'ы клумбы выключены.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)

local LineControls = {}
LineControls.__index = LineControls

local PRIORITY = Enum.ContextActionPriority.High.Value
local ANGLE_MIN = math.atan(Config.SLOPE_MIN)
local ANGLE_MAX = math.atan(Config.SLOPE_MAX)

-- args: store, hud, prompts (список ProximityPrompt, которые глушить), onRecord, onExit
function LineControls.new(args)
	local self = setmetatable({}, LineControls)
	self.store = args.store
	self.hud = args.hud
	self.prompts = args.prompts or {}
	self.onRecord = args.onRecord
	self.held = { slopeUp = false, slopeDown = false, up = false, down = false }
	self.active = false
	self.savedPrompts = {}

	for name in self.held do
		self.hud.padHandlers[name] = function(down: boolean)
			self.held[name] = down
		end
	end
	self.hud.padHandlers.record = function()
		self:record()
	end
	self.hud.padHandlers.exit = function()
		self:exit()
	end

	local player = Players.LocalPlayer
	task.spawn(function()
		local ok, pm = pcall(function()
			local pm: any = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
			return (require :: any)(pm)
		end)
		if ok and pm then
			self.controls = pm:GetControls()
		end
	end)
	player.CharacterAdded:Connect(function()
		if self.active then
			self:exit()
		end
	end)
	return self
end

function LineControls:record()
	if self.active and self.store:get("recordEnabled") and self.onRecord then
		self.onRecord()
	end
end

function LineControls:enter()
	if self.active or not self.store:get("controlUnlocked") then
		return
	end
	self.active = true
	self.store:set("controlMode", true)

	local function holdAction(name: string)
		return function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				self.held[name] = true
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				self.held[name] = false
			end
			return Enum.ContextActionResult.Sink
		end
	end
	ContextActionService:BindActionAtPriority("RegSlopeUp", holdAction("slopeUp"), false, PRIORITY, Enum.KeyCode.Q, Enum.KeyCode.ButtonR1)
	ContextActionService:BindActionAtPriority("RegSlopeDown", holdAction("slopeDown"), false, PRIORITY, Enum.KeyCode.E, Enum.KeyCode.ButtonL1)
	ContextActionService:BindActionAtPriority("RegUp", holdAction("up"), false, PRIORITY, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonR2)
	ContextActionService:BindActionAtPriority("RegDown", holdAction("down"), false, PRIORITY, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonL2)
	ContextActionService:BindActionAtPriority("RegRecord", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:record()
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:BindActionAtPriority("RegExit", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.defer(function()
				self:exit()
			end)
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.X, Enum.KeyCode.ButtonB)

	local player = Players.LocalPlayer
	self.savedMouseLock = player.DevEnableMouseLock
	pcall(function()
		player.DevEnableMouseLock = false
	end)
	if self.controls then
		self.controls:Disable()
	end
	self.savedPrompts = {}
	for _, p in self.prompts do
		self.savedPrompts[p] = p.Enabled
		p.Enabled = false
	end
	self.hud:showPad(true, UserInputService.KeyboardEnabled, self.store:get("recordEnabled") == true)
end

function LineControls:exit()
	if not self.active then
		return
	end
	self.active = false
	for _, name in { "RegSlopeUp", "RegSlopeDown", "RegUp", "RegDown", "RegRecord", "RegExit" } do
		ContextActionService:UnbindAction(name)
	end
	for k in self.held do
		self.held[k] = false
	end
	pcall(function()
		Players.LocalPlayer.DevEnableMouseLock = self.savedMouseLock
	end)
	if self.controls then
		self.controls:Enable()
	end
	for p, was in self.savedPrompts do
		p.Enabled = was
	end
	self.savedPrompts = {}
	self:_snapHeight()
	self.hud:showPad(false, false, false)
	self.store:set("controlMode", false)
end

-- Подсказку можно включить/выключить снаружи, пока режим активен (например, сцена включила новые промпты)
function LineControls:setPromptWanted(p: ProximityPrompt, enabled: boolean)
	if self.active and self.savedPrompts[p] ~= nil then
		self.savedPrompts[p] = enabled
	else
		p.Enabled = enabled
	end
end

function LineControls:_snapHeight()
	local h = self.store:get("h")
	local snapped = math.clamp(math.round(h / Config.H_STEP) * Config.H_STEP, Config.H_MIN, Config.H_MAX)
	if math.abs(snapped - h) > 1e-9 then
		self.store:set("h", snapped)
	end
end

-- Вызывать каждый кадр
function LineControls:step(dt: number)
	if not self.active then
		return
	end
	local st = self.store
	local held = self.held
	self.hud:showPad(true, UserInputService.KeyboardEnabled, st:get("recordEnabled") == true)

	local dirA = (if held.slopeUp then 1 else 0) - (if held.slopeDown then 1 else 0)
	if dirA ~= 0 then
		local a = math.clamp(math.atan(st:get("m")) + dirA * math.rad(Config.ANGLE_SPEED_DEG) * dt, ANGLE_MIN, ANGLE_MAX)
		st:set("m", math.tan(a))
		st:set("movedSlope", true)
		self.slopeWasHeld = true
	elseif self.slopeWasHeld then
		self.slopeWasHeld = false
		-- прилипание к цели (3D.5), только когда клавиша отпущена
		local snap = st:get("mSnap")
		if snap and math.abs(st:get("m") - snap.target) < snap.tol then
			st:set("m", snap.target)
		end
	end

	local dirH = (if held.up then 1 else 0) - (if held.down then 1 else 0)
	if dirH ~= 0 then
		st:set("h", math.clamp(st:get("h") + dirH * Config.H_SPEED * dt, Config.H_MIN, Config.H_MAX))
		st:set("movedHeight", true)
		self.heightWasHeld = true
	elseif self.heightWasHeld then
		self.heightWasHeld = false
		self:_snapHeight()
	end
end

return LineControls
