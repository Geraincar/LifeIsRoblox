local UI = {}
UI.__index = UI

local WHITE = Color3.fromRGB(245, 247, 255)
local MUTED = Color3.fromRGB(183, 194, 215)
local YELLOW = Color3.fromRGB(255, 225, 70)
local GREEN = Color3.fromRGB(85, 235, 130)
local DARK = Color3.fromRGB(18, 23, 34)
local DARK2 = Color3.fromRGB(31, 39, 55)

local function corner(parent, radius)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius or 10)
	value.Parent = parent
	return value
end

local function stroke(parent, color, transparency)
	local value = Instance.new("UIStroke")
	value.Thickness = 2
	value.Color = color or YELLOW
	value.Transparency = transparency or 0.15
	value.Parent = parent
	return value
end

local function label(parent, name, text, position, size, textSize, bold)
	local value = Instance.new("TextLabel")
	value.Name = name
	value.BackgroundTransparency = 1
	value.Position = position
	value.Size = size
	value.Text = text or ""
	value.TextColor3 = WHITE
	value.TextSize = textSize or 18
	value.TextWrapped = true
	value.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	value.Parent = parent
	return value
end

function UI.new(playerGui, options)
	local self = setmetatable({}, UI)
	options = options or {}
	self.Options = options
	self.Classes = options.Classes or { "A", "B" }
	self.FormulaKind = options.FormulaKind or "Entropy"
	self.ClassValues = {}
	self.TotalValue = nil
	self.HighlightedStage = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = options.GuiName or "ImpurityLevelGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 90
	gui.Enabled = false
	gui.Parent = playerGui
	self.Gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "BottomPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -18)
	panel.Size = UDim2.new(0.82, 0, 0, 265)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.22
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 16)
	stroke(panel, options.AccentColor or YELLOW, 0.12)
	self.Panel = panel

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(720, 265)
	constraint.MaxSize = Vector2.new(1180, 265)
	constraint.Parent = panel

	local title = label(
		panel,
		"Title",
		options.Title or "",
		UDim2.new(0, 24, 0, 10),
		UDim2.new(1, -48, 0, 34),
		25,
		true
	)
	title.TextColor3 = options.AccentColor or YELLOW
	title.TextXAlignment = Enum.TextXAlignment.Left
	self.Title = title

	local formula = label(
		panel,
		"Formula",
		"",
		UDim2.new(0, 24, 0, 48),
		UDim2.new(0.62, -30, 0, 55),
		21,
		true
	)
	formula.BackgroundColor3 = DARK2
	formula.BackgroundTransparency = 0.18
	formula.TextColor3 = WHITE
	formula.TextXAlignment = Enum.TextXAlignment.Center
	formula.RichText = true
	formula.TextScaled = true
	corner(formula, 10)
	self.Formula = formula

	local result = label(
		panel,
		"Result",
		"",
		UDim2.new(0.62, 8, 0, 48),
		UDim2.new(0.14, -8, 0, 55),
		28,
		true
	)
	result.TextColor3 = GREEN
	self.Result = result

	local explanation = label(
		panel,
		"Explanation",
		options.Explanation or "",
		UDim2.new(0.76, 12, 0, 48),
		UDim2.new(0.24, -36, 0, 72),
		15,
		false
	)
	explanation.TextColor3 = MUTED
	explanation.TextXAlignment = Enum.TextXAlignment.Left
	self.Explanation = explanation

	local prompt = label(
		panel,
		"Prompt",
		"",
		UDim2.new(0, 24, 0, 125),
		UDim2.new(1, -48, 0, 50),
		21,
		true
	)
	prompt.TextXAlignment = Enum.TextXAlignment.Left
	self.Prompt = prompt

	local counter = label(
		panel,
		"Counter",
		"0",
		UDim2.new(0, 24, 0, 184),
		UDim2.new(0, 245, 0, 58),
		34,
		true
	)
	counter.BackgroundColor3 = DARK2
	counter.BackgroundTransparency = 0.16
	corner(counter, 10)
	self.Counter = counter

	local hint = label(
		panel,
		"Hint",
		"Нажимайте на объекты внутри жёлтой коробки.",
		UDim2.new(0, 292, 0, 184),
		UDim2.new(1, -316, 0, 58),
		17,
		false
	)
	hint.TextColor3 = MUTED
	hint.TextXAlignment = Enum.TextXAlignment.Left

	local shade = Instance.new("Frame")
	shade.Name = "IntroShade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.28
	shade.Visible = false
	shade.Active = true
	shade.Parent = gui
	self.IntroShade = shade

	local intro = Instance.new("Frame")
	intro.Name = "IntroPanel"
	intro.AnchorPoint = Vector2.new(0.5, 0.5)
	intro.Position = UDim2.fromScale(0.5, 0.5)
	intro.Size = UDim2.fromOffset(820, 420)
	intro.BackgroundColor3 = DARK
	intro.BackgroundTransparency = 0.06
	intro.Parent = shade
	corner(intro, 18)
	stroke(intro, options.AccentColor or YELLOW, 0.08)

	self.IntroTitle = label(intro, "Title", "", UDim2.new(0, 35, 0, 30), UDim2.new(1, -70, 0, 55), 31, true)
	self.IntroTitle.TextColor3 = options.AccentColor or YELLOW
	self.IntroBody = label(intro, "Body", "", UDim2.new(0, 50, 0, 100), UDim2.new(1, -100, 0, 120), 21, false)
	self.IntroFormula = label(intro, "Formula", "", UDim2.new(0, 80, 0, 225), UDim2.new(1, -160, 0, 65), 34, true)
	self.IntroFormula.BackgroundColor3 = DARK2
	self.IntroFormula.BackgroundTransparency = 0.15
	corner(self.IntroFormula, 12)

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.AnchorPoint = Vector2.new(0.5, 0)
	startButton.Position = UDim2.new(0.5, 0, 0, 325)
	startButton.Size = UDim2.fromOffset(280, 58)
	startButton.BackgroundColor3 = Color3.fromRGB(52, 151, 92)
	startButton.Text = "НАЧАТЬ"
	startButton.TextColor3 = WHITE
	startButton.TextSize = 20
	startButton.Font = Enum.Font.GothamBold
	startButton.Parent = intro
	corner(startButton, 11)
	self.StartButton = startButton

	startButton.Activated:Connect(function()
		if self.OnStart then
			local callback = self.OnStart
			self.OnStart = nil
			self:HideIntro()
			callback()
		end
	end)

	self:ResetFormula()

	return self
end

local function highlighted(text, enabled)
	if enabled then
		return '<font color="#FFE146">' .. text .. "</font>"
	end
	return text
end

function UI:_updateFormula()
	local firstClass = self.Classes[1]
	local secondClass = self.Classes[2]
	local firstValue = self.ClassValues[firstClass]
	local secondValue = self.ClassValues[secondClass]
	local total = self.TotalValue

	local firstNumerator = firstValue == nil and firstClass or tostring(firstValue)
	local secondNumerator = secondValue == nil and secondClass or tostring(secondValue)
	local denominator = total == nil and "N" or tostring(total)

	local firstFraction = "(" .. firstNumerator .. "/" .. denominator .. ")"
	local secondFraction = "(" .. secondNumerator .. "/" .. denominator .. ")"

	firstFraction = highlighted(firstFraction, self.HighlightedStage == firstClass)
	secondFraction = highlighted(secondFraction, self.HighlightedStage == secondClass)

	local text
	if self.FormulaKind == "Gini" then
		text = "G(S) = 1 − " .. firstFraction .. "² − " .. secondFraction .. "²"
	else
		text = "H(S) = −" .. firstFraction .. " log₂" .. firstFraction
			.. " − " .. secondFraction .. " log₂" .. secondFraction
	end

	if self.HighlightedStage == "TOTAL" then
		text = highlighted(text, true)
	end
	self.Formula.Text = text
end

function UI:ResetFormula()
	self.ClassValues = {}
	self.TotalValue = nil
	self.HighlightedStage = nil
	self:_updateFormula()
end

function UI:HighlightStage(stage)
	self.HighlightedStage = stage
	self:_updateFormula()
end

function UI:SetClassValue(className, value)
	self.ClassValues[className] = value
	self:_updateFormula()
end

function UI:SetTotalValue(value)
	self.TotalValue = value
	self:_updateFormula()
end

function UI:SetEnabled(enabled)
	self.Gui.Enabled = enabled == true
	if not enabled then
		self.Panel.Visible = false
		self.IntroShade.Visible = false
		self.OnStart = nil
	end
end

function UI:ShowTask()
	self.IntroShade.Visible = false
	self.Panel.Visible = true
end

function UI:ShowIntro(title, body, formula, onStart)
	self.Panel.Visible = false
	self.IntroTitle.Text = title or ""
	self.IntroBody.Text = body or ""
	self.IntroFormula.Text = formula or ""
	self.OnStart = onStart
	self.IntroShade.Visible = true
end

function UI:HideIntro()
	self.IntroShade.Visible = false
end

function UI:SetTitle(text)
	self.Title.Text = text or ""
end

function UI:SetPrompt(text)
	self.Prompt.Text = text or ""
end

function UI:SetCounter(value, goal, success)
	if goal ~= nil then
		self.Counter.Text = tostring(value) .. " / " .. tostring(goal)
	else
		self.Counter.Text = tostring(value)
	end
	self.Counter.TextColor3 = success and GREEN or WHITE
end

function UI:SetResult(symbol, value)
	if value == nil then
		self.Result.Text = ""
	else
		self.Result.Text = string.format("%s = %.2f", symbol, value)
	end
end

return UI
