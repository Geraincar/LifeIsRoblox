--!nonstrict
-- Hud: экранный слой 3D experience (ScreenGui):
--   баннер шага · мёд · «?» и панель подсказки · всплывающие сообщения · ставки ·
--   кнопки действий (с телефона всё доступно тапом) · пульт управления прямой (удержание = непрерывно).

local TweenService = game:GetService("TweenService")

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)

local Hud = {}
Hud.__index = Hud

function Hud.new(playerGui: PlayerGui)
	local self = setmetatable({}, Hud)
	self.gui = Gui.make("ScreenGui", {
		Name = "RegressionHud", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
	})
	self.actions = {}
	self.pad = {}
	self.padHandlers = {} -- name → function(down: boolean)
	self.onHintRequest = nil :: (() -> ())?
	self:_buildBanner()
	self:_buildTopRight()
	self:_buildToast()
	self:_buildPrediction()
	self:_buildActions()
	self:_buildPad()
	return self
end

-- ───── баннер шага ─────

function Hud:_buildBanner()
	-- слева сверху: справа сверху в SkRob живёт HUD тайкуна (MainUI.HUD)
	local b = Gui.frame({ AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(0.5, 0, 0, 70),
		BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.15, Parent = self.gui })
	Gui.corner().Parent = b
	Gui.make("UISizeConstraint", { MaxSize = Vector2.new(600, 70), MinSize = Vector2.new(300, 70), Parent = b })
	self.bannerStep = Gui.label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 22), TextSize = Theme.size.hudSmall,
		TextColor3 = Theme.color.textDim, Parent = b })
	self.bannerTask = Gui.label({ Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 38), TextSize = Theme.size.hudText,
		Font = Theme.fontBold, TextScaled = true, Parent = b })
	Gui.make("UITextSizeConstraint", { MaxTextSize = Theme.size.hudText, Parent = self.bannerTask })
end

-- HUD модуля виден только рядом с клумбой / пасекой или во время заданий модуля
function Hud:setVisible(on: boolean)
	if self.gui.Enabled ~= on then
		self.gui.Enabled = on
	end
end

function Hud:setStep(id: string)
	local s = Strings.step[id]
	if not s then
		return
	end
	self.bannerStep.Text = Strings.hud.stepLabel:format(id, s.title)
	self.bannerTask.Text = s.task
end

-- ───── мёд и подсказки ─────

function Hud:_buildTopRight()
	self.hintBtn = Gui.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 56), Size = UDim2.fromOffset(52, 52),
		Text = Strings.hud.hintBtn, TextSize = 30, BackgroundColor3 = Theme.color.panel2, Parent = self.gui })
	self.hintBtn.Activated:Connect(function()
		if self.onHintRequest then
			self.onHintRequest()
		end
	end)
	self.honey = Gui.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -74, 0, 56), Size = UDim2.fromOffset(120, 52),
		BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.15, Font = Theme.fontBold, TextColor3 = Theme.color.c,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = self.gui })
	Gui.corner().Parent = self.honey
	self:setHoney(0)

	self.hint = Gui.frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 116), Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.1, Visible = false, Parent = self.gui })
	Gui.corner().Parent = self.hint
	Gui.stroke(Theme.color.loss, 2).Parent = self.hint
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = self.hint })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = self.hint })
	self.hintTitle = Gui.label({ Size = UDim2.new(1, 0, 0, 22), TextSize = Theme.size.hudSmall, TextColor3 = Theme.color.loss, LayoutOrder = 1, Parent = self.hint })
	self.hintText = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = self.hint })
end

function Hud:setHoney(n: number)
	self.honey.Text = Strings.hud.honey:format(n)
end

function Hud:showHint(level: number, text: string)
	self.hintTitle.Text = Strings.hud.hintTitle:format(level)
	self.hintText.Text = text
	self.hint.Visible = true
end

function Hud:hideHint()
	self.hint.Visible = false
end

-- ───── всплывающие сообщения ─────

function Hud:_buildToast()
	self.toastLabel = Gui.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.1, Font = Theme.fontBold,
		TextWrapped = false, Visible = false, Parent = self.gui })
	Gui.corner().Parent = self.toastLabel
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = self.toastLabel })
	self.toastId = 0
end

function Hud:toast(text: string, color: Color3?)
	self.toastId += 1
	local id = self.toastId
	local l = self.toastLabel
	l.Text = text
	l.TextColor3 = color or Theme.color.text
	l.Visible = true
	task.delay(Config.TOAST_S, function()
		if self.toastId == id then
			l.Visible = false
		end
	end)
end

-- ───── ставки ─────

function Hud:_buildPrediction()
	local p = Gui.frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.08, Visible = false, Parent = self.gui })
	Gui.corner().Parent = p
	Gui.stroke(Theme.color.c, 2).Parent = p
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = p })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = p })
	Gui.label({ Text = Strings.hud.predictionTitle, TextColor3 = Theme.color.c, TextSize = Theme.size.hudSmall, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = p })
	self.predQuestion = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.fontBold, LayoutOrder = 2, Parent = p })
	self.predButtons = {}
	for i = 1, 4 do
		local b = Gui.button({ Size = UDim2.new(1, 0, 0, Theme.size.touch), LayoutOrder = 2 + i, Visible = false, Parent = p })
		b.Activated:Connect(function()
			if self.predPick then
				local fn = self.predPick
				self.predPick = nil
				self.predChosen = i
				for k, other in self.predButtons do
					other.BackgroundColor3 = if k == i then Theme.color.c else Theme.color.panel2
					other.AutoButtonColor = false
				end
				fn(i)
			end
		end)
		self.predButtons[i] = b
	end
	self.predResult = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10, Visible = false, Parent = p })
	self.pred = p
end

-- Показать ставку; onPick(i) вызывается один раз
function Hud:ask(spec, onPick: (number) -> ())
	self.predQuestion.Text = spec.question
	for i, b in self.predButtons do
		local opt = spec.options[i]
		b.Visible = opt ~= nil
		b.Text = opt or ""
		b.BackgroundColor3 = Theme.color.panel2
		b.AutoButtonColor = true
	end
	self.predResult.Visible = false
	self.predPick = onPick
	self.pred.Visible = true
end

-- Ответ после действия игрока; панель закрывается сама
function Hud:resolve(correct: boolean, explanation: string)
	self.predResult.Text = (if correct then Theme.tok("good", Strings.hud.predictionOk) else Strings.hud.predictionWrong) .. "\n" .. explanation
	self.predResult.Visible = true
	self.pred.Visible = true
	self.predPick = nil
	task.delay(6, function()
		self.pred.Visible = false
	end)
end

function Hud:closePrediction()
	self.pred.Visible = false
	self.predPick = nil
end

-- ───── кнопки действий ─────

function Hud:_buildActions()
	local col = Gui.frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = self.gui })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = col })
	for order, slot in { "primary", "control" } do
		local b = Gui.button({ Size = UDim2.fromOffset(300, 54), LayoutOrder = order, Visible = false, TextSize = 22,
			BackgroundColor3 = if slot == "primary" then Theme.color.loss else Theme.color.panel2,
			TextColor3 = if slot == "primary" then Theme.color.bg else Theme.color.text, Parent = col })
		b.Activated:Connect(function()
			local a = self.actions[slot]
			if a and a.callback then
				a.callback()
			end
		end)
		self.actions[slot] = { button = b, callback = nil }
	end
	self.actionColumn = col
end

-- slot: "primary" | "control"; text = nil прячет кнопку
function Hud:setAction(slot: string, text: string?, callback: (() -> ())?)
	local a = self.actions[slot]
	a.callback = callback
	a.button.Visible = text ~= nil
	if text then
		a.button.Text = text
	end
end

-- ───── пульт управления прямой ─────

function Hud:_buildPad()
	local h = Strings.hud
	local pad = Gui.frame({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(2 * 128 + 8, 3 * 62 + 16),
		BackgroundTransparency = 1, Visible = false, Parent = self.gui })
	Gui.make("UIGridLayout", { CellSize = UDim2.fromOffset(128, 62), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pad })
	local spec = {
		{ "slopeUp", h.slopeUp, h.keyQ, Theme.color.m, true },
		{ "up", h.up, h.keyShift, Theme.color.c, true },
		{ "slopeDown", h.slopeDown, h.keyE, Theme.color.m, true },
		{ "down", h.down, h.keyCtrl, Theme.color.c, true },
		{ "record", h.record, h.keyR, Theme.color.loss, false },
		{ "exit", h.exit, h.keyX, Theme.color.panel2, false },
	}
	for order, s in spec do
		local name, text, key, color, hold = s[1], s[2], s[3], s[4], s[5]
		local b = Gui.button({ LayoutOrder = order, BackgroundColor3 = Theme.color.panel2, TextSize = 20,
			Text = ("%s\n<font size=\"14\" color=\"%s\">%s</font>"):format(text, Theme.hex.textDim, key), Parent = pad })
		Gui.stroke(color, 2).Parent = b
		if hold then
			local function set(down: boolean)
				local fn = self.padHandlers[name]
				if fn then
					fn(down)
				end
			end
			b.InputBegan:Connect(function(input)
				local t = input.UserInputType
				if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
					set(true)
				end
			end)
			b.InputEnded:Connect(function(input)
				local t = input.UserInputType
				if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
					set(false)
				end
			end)
			b.MouseLeave:Connect(function()
				set(false)
			end)
		else
			b.Activated:Connect(function()
				local fn = self.padHandlers[name]
				if fn then
					fn(true)
				end
			end)
		end
		self.pad[name] = b
	end
	self.padFrame = pad

	self.keysBar = Gui.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -90), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.15, TextWrapped = false,
		Text = h.keysBar, TextSize = 18, Visible = false, Parent = self.gui })
	Gui.corner().Parent = self.keysBar
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = self.keysBar })
end

function Hud:showPad(on: boolean, keyboard: boolean, recordEnabled: boolean)
	self.padFrame.Visible = on
	self.keysBar.Visible = on and keyboard
	self.pad.record.Visible = recordEnabled
end

-- Короткая вспышка кнопки (подтверждение действия ≤ 0,6 с)
function Hud:flash(gui: GuiObject)
	local old = gui.BackgroundColor3
	gui.BackgroundColor3 = Theme.color.good
	TweenService:Create(gui, TweenInfo.new(0.5), { BackgroundColor3 = old }):Play()
end

return Hud
