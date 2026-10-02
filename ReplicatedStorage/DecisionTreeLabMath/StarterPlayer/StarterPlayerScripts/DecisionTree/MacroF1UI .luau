local UI = {}
UI.__index = UI

local DARK = Color3.fromRGB(18, 25, 40)
local PANEL = Color3.fromRGB(24, 34, 55)
local WHITE = Color3.fromRGB(245, 248, 255)
local MUTED = Color3.fromRGB(191, 204, 228)
local ACCENT = Color3.fromRGB(255, 210, 72)
local CLASS_COLORS = {
	A = Color3.fromRGB(232, 151, 157),
	B = Color3.fromRGB(158, 143, 220),
	C = Color3.fromRGB(84, 190, 157),
	D = Color3.fromRGB(255, 184, 42),
}

local function round(gui, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function stroke(gui, color, thickness)
	local line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness or 1
	line.Transparency = 0.2
	line.Parent = gui
end

local function label(parent, name, size, position, text, textSize, color, font)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.Text = text or ""
	item.TextColor3 = color or WHITE
	item.TextSize = textSize or 20
	item.Font = font or Enum.Font.Gotham
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.Parent = parent
	return item
end

local function formatNumber(value)
	return string.format("%.2f", value)
end

function UI.new(playerGui)
	local self = setmetatable({}, UI)
	self.MacroValues = {}
	self.MacroButtons = {}

	local old = playerGui:FindFirstChild("MacroF1LevelGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MacroF1LevelGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = playerGui
	self.Gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "TaskPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -18)
	panel.Size = UDim2.new(0.9, 0, 0, 270)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.14
	panel.Parent = gui
	round(panel, 18)
	stroke(panel, ACCENT, 2)
	self.Panel = panel

	local title = label(panel, "Title", UDim2.new(1, -36, 0, 38), UDim2.fromOffset(18, 8), "F1 и Macro-F1", 27, ACCENT, Enum.Font.GothamMedium)
	self.Title = title

	local prompt = label(panel, "Prompt", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 45), "", 19, WHITE, Enum.Font.GothamMedium)
	self.Prompt = prompt

	local legend = label(
		panel,
		"Legend",
		UDim2.new(1, -36, 0, 34),
		UDim2.fromOffset(18, 86),
		"TP — истинно положительный   •   TN — истинно отрицательный   •   FP — ложноположительный   •   FN — ложноотрицательный",
		15,
		MUTED,
		Enum.Font.Gotham
	)
	legend.TextXAlignment = Enum.TextXAlignment.Center
	self.Legend = legend

	local counts = label(panel, "Counts", UDim2.new(0.31, -18, 0, 125), UDim2.fromOffset(18, 127), "TP = 0\nFP = 0\nFN = 0", 22, WHITE, Enum.Font.GothamMedium)
	counts.TextYAlignment = Enum.TextYAlignment.Top
	self.Counts = counts

	local macroButtons = Instance.new("Frame")
	macroButtons.Name = "MacroButtons"
	macroButtons.Size = UDim2.new(0.31, -18, 0, 125)
	macroButtons.Position = UDim2.fromOffset(18, 124)
	macroButtons.BackgroundTransparency = 1
	macroButtons.Visible = false
	macroButtons.Parent = panel
	self.MacroButtonsFrame = macroButtons

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 4)
	list.Parent = macroButtons

	for _, className in ipairs({ "A", "B", "C", "D" }) do
		local button = Instance.new("TextButton")
		button.Name = "F1" .. className .. "Button"
		button.Size = UDim2.new(1, 0, 0, 26)
		button.BackgroundColor3 = Color3.fromRGB(31, 43, 66)
		button.BackgroundTransparency = 0.18
		button.Text = "F1 " .. className
		button.TextColor3 = CLASS_COLORS[className]
		button.TextSize = 18
		button.Font = Enum.Font.GothamMedium
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.AutoButtonColor = true
		button.Parent = macroButtons
		round(button, 7)

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.Parent = button

		button.Activated:Connect(function()
			if self.OnMacroClassClicked then
				self.OnMacroClassClicked(className)
			end
		end)
		self.MacroButtons[className] = button
	end

	local formulas = label(panel, "Formulas", UDim2.new(0.69, -30, 0, 128), UDim2.new(0.31, 8, 0, 123), "", 19, WHITE, Enum.Font.GothamMedium)
	formulas.RichText = true
	formulas.TextYAlignment = Enum.TextYAlignment.Top
	self.Formulas = formulas

	local introShade = Instance.new("Frame")
	introShade.Name = "IntroShade"
	introShade.Size = UDim2.fromScale(1, 1)
	introShade.BackgroundColor3 = Color3.new(0, 0, 0)
	introShade.BackgroundTransparency = 0.28
	introShade.Visible = false
	introShade.Parent = gui
	self.IntroShade = introShade

	local intro = Instance.new("Frame")
	intro.Name = "Intro"
	intro.AnchorPoint = Vector2.new(0.5, 0.5)
	intro.Position = UDim2.fromScale(0.5, 0.48)
	intro.Size = UDim2.new(0, 680, 0, 350)
	intro.BackgroundColor3 = DARK
	intro.BackgroundTransparency = 0.04
	intro.Parent = introShade
	round(intro, 22)
	stroke(intro, ACCENT, 3)

	local introTitle = label(intro, "Title", UDim2.new(1, -60, 0, 55), UDim2.fromOffset(30, 24), "Проверяем дерево на новой партии мёда", 30, ACCENT, Enum.Font.GothamMedium)
	introTitle.TextXAlignment = Enum.TextXAlignment.Center
	self.IntroTitle = introTitle

	local introBody = label(intro, "Body", UDim2.new(1, -76, 0, 170), UDim2.fromOffset(38, 88), "Мы с тобой построили дерево на одной выборке. Теперь возьмём другую партию мёда и посмотрим, насколько хорошо наш сортировщик работает.\n\nНаведи курсор на объект, чтобы увидеть его данные.", 22, WHITE, Enum.Font.GothamMedium)
	introBody.TextXAlignment = Enum.TextXAlignment.Center
	self.IntroBody = introBody

	local start = Instance.new("TextButton")
	start.Name = "StartButton"
	start.AnchorPoint = Vector2.new(0.5, 1)
	start.Position = UDim2.new(0.5, 0, 1, -27)
	start.Size = UDim2.fromOffset(230, 58)
	start.BackgroundColor3 = ACCENT
	start.Text = "НАЧАТЬ"
	start.TextColor3 = DARK
	start.TextSize = 24
	start.Font = Enum.Font.GothamMedium
	start.Parent = intro
	round(start, 13)
	self.StartButton = start

	local hover = Instance.new("Frame")
	hover.Name = "ObjectData"
	hover.Size = UDim2.fromOffset(250, 158)
	hover.BackgroundColor3 = DARK
	hover.BackgroundTransparency = 0.08
	hover.Visible = false
	hover.ZIndex = 60
	hover.Parent = gui
	round(hover, 12)
	stroke(hover, Color3.fromRGB(125, 170, 255), 2)
	self.Hover = hover

	local hoverText = label(hover, "Text", UDim2.new(1, -24, 1, -20), UDim2.fromOffset(12, 10), "", 17, WHITE, Enum.Font.GothamMedium)
	hoverText.ZIndex = 61
	hoverText.TextYAlignment = Enum.TextYAlignment.Top
	self.HoverText = hoverText

	start.Activated:Connect(function()
		if self.OnStart then
			self.OnStart()
		end
	end)

	return self
end

function UI:SetEnabled(enabled)
	self.Gui.Enabled = enabled
	if not enabled then
		self.IntroShade.Visible = false
		self.Hover.Visible = false
	end
end

function UI:ShowIntro(callback)
	self.IntroTitle.Text = "Проверяем дерево на новой партии мёда"
	self.IntroBody.Text = "Мы с тобой построили дерево на одной выборке. Теперь возьмём другую партию мёда и посмотрим, насколько хорошо наш сортировщик работает.\n\nНаведи курсор на объект, чтобы увидеть его данные."
	self.StartButton.Text = "НАЧАТЬ"
	self.OnStart = function()
		self.IntroShade.Visible = false
		callback()
	end
	self.Panel.Visible = false
	self.IntroShade.Visible = true
end

function UI:ShowCompletionSequence(onFinished)
	self.Panel.Visible = false
	self.Hover.Visible = false
	self.Counts.Visible = false
	self.MacroButtonsFrame.Visible = false
	self.Formulas.Text = ""
	self.OnMacroClassClicked = nil
	self.IntroShade.Visible = true
	self.IntroTitle.Text = "ЧТО ТАКОЕ MACRO-F1?"
	self.IntroBody.Text = "Macro-F1 — способ оценки ошибки решающего дерева, которое мы собрали."
	self.StartButton.Text = "ДАЛЕЕ"

	local stage = 1
	self.OnStart = function()
		if stage == 1 then
			stage = 2
			self.IntroTitle.Text = "УРОВЕНЬ ЗАВЕРШЁН"
			self.IntroBody.Text = "ПОЗДРАВЛЯЮ! ТЕПЕРЬ ТЫ ЗНАЕШЬ, КАК РАБОТАЕТ РЕШАЮЩЕЕ ДЕРЕВО!"
			self.StartButton.Text = "ЗАВЕРШИТЬ"
			return
		end

		self.IntroShade.Visible = false
		self.OnStart = nil
		onFinished()
	end
end

function UI:ShowClassATask()
	self.Panel.Visible = true
	self.IntroShade.Visible = false
	self.Counts.Visible = true
	self.MacroButtonsFrame.Visible = false
	self.OnMacroClassClicked = nil
	self.Title.Text = "F1 для класса A"
	self.Prompt.Text = "Сначала найдите истинно положительные объекты класса A."
	self:SetCounts(0, 0, 0)
end

function UI:SetPhase(phase, current, goal)
	local text = {
		TP = "TP: нажимайте объекты, где истинный класс A и дерево предсказало A",
		FP = "FP: нажимайте объекты, где дерево предсказало A, но истинный класс другой",
		FN = "FN: нажимайте объекты класса A, которые дерево отправило в другой класс",
	}
	self.Prompt.Text = string.format("%s  (%d/%d)", text[phase] or phase, current or 0, goal or 0)
end

function UI:SetCounts(tp, fp, fn)
	self.Counts.Visible = true
	self.MacroButtonsFrame.Visible = false
	self.Counts.Text = string.format("TP = %d\nFP = %d\nFN = %d", tp, fp, fn)
	self.Formulas.Text = string.format(
		"Precision_A = TP / (TP + FP) = %d / (%d + %d)\nRecall_A = TP / (TP + FN) = %d / (%d + %d)\nF1_A = 2 · Precision · Recall / (Precision + Recall)",
		tp, tp, fp, tp, tp, fn
	)
end

function UI:ShowClassAMetrics(metrics)
	self.Counts.Visible = true
	self.MacroButtonsFrame.Visible = false
	self.Title.Text = "F1 для класса A — готово"
	self.Prompt.Text = "Теперь соберите Macro-F1: нажмите по одному результату F1 каждого класса над коробками."
	self.Counts.Text = string.format("TP = %d\nFP = %d\nFN = %d", metrics.TP, metrics.FP, metrics.FN)
	self.Formulas.Text = string.format(
		"Precision_A = %d / (%d + %d) = %s\nRecall_A = %d / (%d + %d) = %s\nF1 A = %s",
		metrics.TP, metrics.TP, metrics.FP, formatNumber(metrics.Precision),
		metrics.TP, metrics.TP, metrics.FN, formatNumber(metrics.Recall), formatNumber(metrics.F1)
	)
end

function UI:ShowMacro(metrics, onClassClicked)
	self.MacroValues = {}
	self.OnMacroClassClicked = onClassClicked
	self.Title.Text = "Macro-F1"
	self.Prompt.Text = "Нажимайте F1 A, F1 B, F1 C и F1 D здесь или на табличках над коробками."
	self.Counts.Visible = false
	self.MacroButtonsFrame.Visible = true
	for _, className in ipairs({ "A", "B", "C", "D" }) do
		local button = self.MacroButtons[className]
		button.Text = string.format("F1 %s = %s", className, formatNumber(metrics[className].F1))
		button.BackgroundColor3 = Color3.fromRGB(31, 43, 66)
		button.BackgroundTransparency = 0.18
		button.TextColor3 = CLASS_COLORS[className]
		button.Active = onClassClicked ~= nil
		button.AutoButtonColor = onClassClicked ~= nil
	end
	self:_refreshMacroFormula()
end

function UI:_refreshMacroFormula()
	local slots = {}
	for _, className in ipairs({ "A", "B", "C", "D" }) do
		local value = self.MacroValues[className]
		table.insert(slots, value and formatNumber(value) or ("F1 " .. className))
	end
	self.Formulas.Text = "Macro-F1 = (" .. table.concat(slots, " + ") .. ") / 4"
end

function UI:AddMacroValue(className, value)
	self.MacroValues[className] = value
	local button = self.MacroButtons[className]
	if button then
		button.BackgroundColor3 = CLASS_COLORS[className]
		button.BackgroundTransparency = 0.05
		button.TextColor3 = DARK
		button.Active = false
		button.AutoButtonColor = false
	end
	self:_refreshMacroFormula()
end

function UI:ShowMacroResult(value)
	self.Prompt.Text = "Готово! Качество сортировщика на новой партии мёда рассчитано."
	self.Formulas.Text ..= string.format("\n\nMacro-F1 = %s", formatNumber(value))
end

function UI:ShowCompleted(metrics, macro)
	self.Panel.Visible = true
	self.IntroShade.Visible = false
	self:ShowMacro(metrics, nil)
	for _, className in ipairs({ "A", "B", "C", "D" }) do
		self:AddMacroValue(className, metrics[className].F1)
	end
	self:ShowMacroResult(macro)
end

function UI:SetHover(row, mouseX, mouseY)
	if not row then
		self.Hover.Visible = false
		return
	end
	self.HoverText.Text = string.format(
		"Объект %s\nx = %.1f\ny = %.1f\nИстинный класс: %s\nПредсказание дерева: %s",
		row.Id, row.X, row.Y, row.TrueClass, row.PredictedClass
	)
	self.HoverText.RichText = true
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local x = math.clamp((mouseX or 0) + 18, 8, viewport.X - 258)
	local y = math.clamp((mouseY or 0) + 18, 8, viewport.Y - 166)
	self.Hover.Position = UDim2.fromOffset(x, y)
	self.Hover.Visible = true
end

return UI
