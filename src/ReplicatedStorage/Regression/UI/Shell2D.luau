--!nonstrict
-- Shell2D: оболочка экранов 2D experience и панелей лор-задачи (ScreenGui поверх мира).
--   ┌ шапка: шаг · заголовок ·········· [Формулы] [Блокнот] [?] [Закрыть] ┐
--   │ main (графики сцены)          │ side: полоса формул (≤ 3), текст, управление │
--   └ подвал: задание ······································· [Дальше →] ┘
-- На узком экране (< 820 px) side уезжает в выдвижную панель (кнопка «Формулы»).
-- Ставки, подсказки и всплывающие сообщения — внутри оболочки, поверх сцены.

local TweenService = game:GetService("TweenService")

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)
local FormulaView = require(Regression.UI.FormulaView)
local Notebook = require(Regression.UI.Notebook)

local Shell2D = {}
Shell2D.__index = Shell2D

local MAX_FORMULAS = 3
local COMPACT_W = 820

function Shell2D.new(playerGui: PlayerGui, store)
	local self = setmetatable({}, Shell2D)
	self.store = store
	self.formulas = {}
	self.onClose = nil :: (() -> ())?
	self.onNext = nil :: (() -> ())?
	self.onHint = nil :: (() -> ())?
	self.isOpen = false
	self.compact = false
	self.sideOpen = false

	self.gui = Gui.make("ScreenGui", {
		Name = "Regression2D", ResetOnSpawn = false, Enabled = false, DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
	})
	local dim = Gui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = self.gui })
	local panel = Gui.frame({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.94),
		BackgroundColor3 = Theme.color.bg, Parent = dim })
	Gui.corner(UDim.new(0, 14)).Parent = panel
	Gui.make("UISizeConstraint", { MaxSize = Vector2.new(1240, 720), Parent = panel })
	self.panel = panel

	self:_buildHeader()
	self:_buildBody()
	self:_buildFooter()
	self:_buildOverlays()
	self.notebook = Notebook.new(panel)

	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	self:_layout()
	return self
end

-- ───── каркас ─────

function Shell2D:_buildHeader()
	local p = self.panel
	self.stepLabel = Gui.label({ Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -440, 0, 20), TextSize = 16,
		TextColor3 = Theme.color.textDim, Parent = p })
	self.titleLabel = Gui.label({ Position = UDim2.fromOffset(18, 24), Size = UDim2.new(1, -440, 0, 30), TextSize = 26,
		Font = Theme.fontBold, TextScaled = true, Parent = p })
	Gui.make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 16, Parent = self.titleLabel })

	local bar = Gui.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(420, 46), Parent = p })
	Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = bar })
	local h = Strings.s2d
	self.sideBtn = Gui.button({ Text = h.formulasBtn, Size = UDim2.fromOffset(100, 44), LayoutOrder = 1, Visible = false, TextSize = 18, Parent = bar })
	self.sideBtn.Activated:Connect(function()
		self:setSideOpen(not self.sideOpen)
	end)
	self.notebookBtn = Gui.button({ Text = h.notebookBtn, Size = UDim2.fromOffset(100, 44), LayoutOrder = 2, TextSize = 18, Parent = bar })
	self.notebookBtn.Activated:Connect(function()
		self.notebook:toggle()
	end)
	self.hintBtn = Gui.button({ Text = "?", Size = UDim2.fromOffset(44, 44), LayoutOrder = 3, TextSize = 26, Parent = bar })
	self.hintBtn.Activated:Connect(function()
		if self.onHint then
			self.onHint()
		end
	end)
	self.closeBtn = Gui.button({ Text = h.close, Size = UDim2.fromOffset(110, 44), LayoutOrder = 4, TextSize = 18, Parent = bar })
	self.closeBtn.Activated:Connect(function()
		self:close()
		if self.onClose then
			self.onClose()
		end
	end)
end

function Shell2D:_buildBody()
	local p = self.panel
	self.body = Gui.frame({ Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 1, -128), Parent = p })
	self.main = Gui.frame({ Name = "Main", BackgroundTransparency = 1, ClipsDescendants = false, Parent = self.body })
	self.side = Gui.frame({ Name = "Side", BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0, ZIndex = 5, Parent = self.body })
	Gui.corner().Parent = self.side
	self.sideScroll = Gui.make("ScrollingFrame", {
		Name = "SideScroll", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, ZIndex = 5, Parent = self.side,
	})
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), Parent = self.sideScroll })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = self.sideScroll })
	self.formulaHolder = Gui.frame({ Name = "Formulas", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 5, Parent = self.sideScroll })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = self.formulaHolder })
	self.text = Gui.label({ Name = "Text", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 19,
		TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, ZIndex = 5, Parent = self.sideScroll })
	self.controls = Gui.frame({ Name = "Controls", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 5, Parent = self.sideScroll })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = self.controls })
end

function Shell2D:_buildFooter()
	local p = self.panel
	self.taskLabel = Gui.label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -10), Size = UDim2.new(1, -250, 0, 48),
		TextSize = 20, TextColor3 = Theme.color.text, TextScaled = true, Parent = p })
	Gui.make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 14, Parent = self.taskLabel })
	self.nextBtn = Gui.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(210, 50),
		Text = Strings.s2d.next, TextSize = 22, Parent = p })
	self.nextBtn.Activated:Connect(function()
		if self.nextEnabled and self.onNext then
			self.onNext()
		end
	end)
	self:setNext(false)
end

function Shell2D:_buildOverlays()
	local p = self.panel
	-- всплывающее сообщение
	self.toastLabel = Gui.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Theme.color.panel2, BackgroundTransparency = 0.05, Font = Theme.fontBold,
		TextWrapped = false, Visible = false, ZIndex = 30, Parent = p })
	Gui.corner().Parent = self.toastLabel
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = self.toastLabel })
	self.toastId = 0

	-- ставка
	local pr = Gui.frame({ Name = "Prediction", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.02, Visible = false, ZIndex = 35, Parent = p })
	Gui.corner().Parent = pr
	Gui.stroke(Theme.color.c, 2).Parent = pr
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = pr })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = pr })
	Gui.label({ Text = Strings.hud.predictionTitle, TextColor3 = Theme.color.c, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, ZIndex = 36, Parent = pr })
	self.predQuestion = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.fontBold, LayoutOrder = 2, ZIndex = 36, Parent = pr })
	self.predButtons = {}
	for i = 1, 4 do
		local b = Gui.button({ Size = UDim2.new(1, 0, 0, Theme.size.touch), LayoutOrder = 2 + i, Visible = false, ZIndex = 36, TextWrapped = true, Parent = pr })
		b.Activated:Connect(function()
			if self.predPick then
				local fn = self.predPick
				self.predPick = nil
				for k, other in self.predButtons do
					other.BackgroundColor3 = if k == i then Theme.color.c else Theme.color.panel2
					other.AutoButtonColor = false
				end
				-- после выбора панель уходит в сторону, чтобы не закрывать эксперимент
				self.pred.AnchorPoint = Vector2.new(1, 1)
				self.pred.Position = UDim2.new(1, -12, 1, -70)
				for _, other in self.predButtons do
					other.Visible = false
				end
				self.predChosen.Text = Strings.s2d.yourBet:format(self.predSpec.options[i])
				self.predChosen.Visible = true
				fn(i)
			end
		end)
		self.predButtons[i] = b
	end
	self.predChosen = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = Theme.color.c,
		LayoutOrder = 9, Visible = false, ZIndex = 36, Parent = pr })
	self.predResult = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10, Visible = false, ZIndex = 36, Parent = pr })
	self.pred = pr

	-- подсказка
	local hint = Gui.frame({ Name = "Hint", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 60), Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.02, Visible = false, ZIndex = 32, Parent = p })
	Gui.corner().Parent = hint
	Gui.stroke(Theme.color.loss, 2).Parent = hint
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = hint })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = hint })
	self.hintTitle = Gui.label({ Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextColor3 = Theme.color.loss, LayoutOrder = 1, ZIndex = 33, Parent = hint })
	self.hintText = Gui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 33, Parent = hint })
	self.hint = hint
	self.pulses = {}
end

-- ───── раскладка ─────

function Shell2D:_layout()
	local w = self.panel.AbsoluteSize.X
	local compact = w > 0 and w < COMPACT_W
	self.compact = compact
	self.sideBtn.Visible = compact
	if compact then
		self.main.Position = UDim2.fromScale(0, 0)
		self.main.Size = UDim2.fromScale(1, 1)
		self.side.AnchorPoint = Vector2.new(1, 0)
		self.side.Position = UDim2.fromScale(1, 0)
		self.side.Size = UDim2.fromScale(0.86, 1)
		self.side.Visible = self.sideOpen
		self.side.BackgroundTransparency = 0.03
	else
		self.main.Position = UDim2.fromScale(0, 0)
		self.main.Size = UDim2.new(self.mainShare or 0.6, -8, 1, 0)
		self.side.AnchorPoint = Vector2.new(0, 0)
		self.side.Position = UDim2.fromScale(self.mainShare or 0.6, 0)
		self.side.Size = UDim2.fromScale(1 - (self.mainShare or 0.6), 1)
		self.side.Visible = true
		self.side.BackgroundTransparency = 1
	end
end

-- Доля ширины под графики (сцене с двумя графиками нужно больше места)
function Shell2D:setMainShare(share: number)
	self.mainShare = share
	self:_layout()
end

function Shell2D:setSideOpen(on: boolean)
	self.sideOpen = on
	self:_layout()
end

-- ───── API сцен ─────

function Shell2D:open()
	self.gui.Enabled = true
	self.isOpen = true
end

function Shell2D:close()
	self.gui.Enabled = false
	self.isOpen = false
	self.notebook:setVisible(false)
end

function Shell2D:setHeader(id: string, title: string)
	self.stepLabel.Text = Strings.s2d.stepLabel:format(id)
	self.titleLabel.Text = title
end

function Shell2D:setTask(text: string)
	self.taskLabel.Text = text
end

function Shell2D:setText(text: string)
	self.text.Text = text
end

function Shell2D:setNext(enabled: boolean, label: string?)
	self.nextEnabled = enabled
	self.nextBtn.Text = label or Strings.s2d.next
	self.nextBtn.BackgroundColor3 = if enabled then Theme.color.good else Theme.color.panel2
	self.nextBtn.TextColor3 = if enabled then Theme.color.bg else Theme.color.textDim
	self.nextBtn.AutoButtonColor = enabled
end

-- Новая формула в полосе (не больше 3 на экране)
function Shell2D:addFormula(spec, state)
	assert(#self.formulas < MAX_FORMULAS, "Shell2D: больше 3 формул на экране — перенеси старые в блокнот")
	local fv = FormulaView.new(self.formulaHolder, spec, { store = self.store, layoutOrder = #self.formulas + 1, state = state })
	table.insert(self.formulas, fv)
	return fv
end

-- Кнопка в колонке управления
function Shell2D:button(text: string, opts)
	opts = opts or {}
	local b = Gui.button({ Text = text, Size = opts.size or UDim2.new(1, 0, 0, 48), LayoutOrder = opts.order or 10, TextSize = opts.textSize or 20,
		BackgroundColor3 = opts.color or Theme.color.panel2, TextColor3 = opts.textColor or Theme.color.text, ZIndex = 6,
		Visible = opts.visible ~= false, Parent = opts.parent or self.controls })
	if opts.onClick then
		b.Activated:Connect(opts.onClick)
	end
	return b
end

-- Ряд кнопок в колонке управления
function Shell2D:row(order: number?, height: number?)
	local f = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 48), LayoutOrder = order or 10, ZIndex = 6, Parent = self.controls })
	Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = f })
	return f
end

-- Убрать всё сценовое; формулы с toNotebook уходят в блокнот
function Shell2D:clearScene(sceneId: string?, keepMain: boolean?)
	for _, fv in self.formulas do
		if sceneId and fv.spec.toNotebook then
			self.notebook:addFormula(sceneId, fv:snapshot())
		end
		fv:Destroy()
	end
	self.formulas = {}
	if not keepMain then
		for _, c in self.main:GetChildren() do
			c:Destroy()
		end
	end
	for _, c in self.controls:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	self.text.Text = ""
	self:closePrediction()
	self:hideHint()
	self:setNext(false)
	self:setMainShare(0.6)
end

function Shell2D:toast(text: string, color: Color3?)
	self.toastId += 1
	local id = self.toastId
	self.toastLabel.Text = text
	self.toastLabel.TextColor3 = color or Theme.color.text
	self.toastLabel.Visible = true
	task.delay(Config.TOAST_S, function()
		if self.toastId == id then
			self.toastLabel.Visible = false
		end
	end)
end

-- Ставка: 2–4 варианта; onPick(i) один раз. Ответ — resolve() после действия игрока.
function Shell2D:ask(spec, onPick: (number) -> ())
	self.predSpec = spec
	self.predQuestion.Text = spec.question
	for i, b in self.predButtons do
		local opt = spec.options[i]
		b.Visible = opt ~= nil
		b.Text = opt or ""
		b.BackgroundColor3 = Theme.color.panel2
		b.AutoButtonColor = true
	end
	self.pred.AnchorPoint = Vector2.new(0.5, 0.5)
	self.pred.Position = UDim2.fromScale(0.5, 0.5)
	self.predResult.Visible = false
	self.predChosen.Visible = false
	self.predPick = onPick
	self.pred.Visible = true
end

function Shell2D:resolve(correct: boolean, explanation: string)
	self.predResult.Text = (if correct then Theme.tok("good", Strings.hud.predictionOk) else Strings.hud.predictionWrong) .. "\n" .. explanation
	self.predResult.Visible = true
	self.pred.Visible = true
	self.predPick = nil
	local token = {}
	self.predToken = token
	task.delay(8, function()
		if self.predToken == token then
			self.pred.Visible = false
		end
	end)
end

function Shell2D:closePrediction()
	self.pred.Visible = false
	self.predPick = nil
	self.predToken = nil
end

function Shell2D:showHint(level: number, text: string, targets: { GuiObject }?)
	self.hintTitle.Text = Strings.hud.hintTitle:format(level)
	self.hintText.Text = text
	self.hint.Visible = true
	self:_clearPulses()
	for _, t in targets or {} do
		local st = Gui.stroke(Theme.color.loss, 4)
		st.Name = "HintPulse"
		st.Parent = t
		table.insert(self.pulses, st)
		TweenService:Create(st, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.8 }):Play()
	end
end

function Shell2D:_clearPulses()
	for _, p in self.pulses do
		p:Destroy()
	end
	self.pulses = {}
end

function Shell2D:hideHint()
	self.hint.Visible = false
	self:_clearPulses()
end

-- Подтверждение действия (≤ 0,6 с)
function Shell2D:flash(gui: GuiObject)
	local old = gui.BackgroundColor3
	gui.BackgroundColor3 = Theme.color.good
	TweenService:Create(gui, TweenInfo.new(0.5), { BackgroundColor3 = old }):Play()
end

return Shell2D
