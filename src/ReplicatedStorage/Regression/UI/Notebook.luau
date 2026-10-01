--!nonstrict
-- Notebook: «Блокнот пасечника» — формулы прошлых сцен (статичные, последние значения) и заметки,
-- сгруппированные по сценам. Прокручиваемый список поверх экрана 2D.
--   nb:addFormula(sceneId, snapshot) · nb:addNote(sceneId, text) · nb:setVisible(on) · nb.entries (для Store.serialize)

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)
local FormulaView = require(Regression.UI.FormulaView)

local Notebook = {}
Notebook.__index = Notebook

function Notebook.new(parent: GuiObject)
	local self = setmetatable({}, Notebook)
	self.entries = {}
	self.groups = {}
	self.frame = Gui.frame({ Name = "Notebook", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 60),
		Size = UDim2.new(0.5, 0, 1, -130), BackgroundColor3 = Theme.color.bg, Visible = false, ZIndex = 40, Parent = parent })
	Gui.corner().Parent = self.frame
	Gui.stroke(Theme.color.c, 2).Parent = self.frame
	Gui.make("UISizeConstraint", { MinSize = Vector2.new(300, 200), Parent = self.frame })
	Gui.label({ Text = Strings.s2d.notebookTitle, Font = Theme.fontBold, TextSize = 22, Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -80, 0, 30), ZIndex = 41, Parent = self.frame })
	local close = Gui.button({ Text = "✕", Size = UDim2.fromOffset(44, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6),
		ZIndex = 41, Parent = self.frame })
	close.Activated:Connect(function()
		self:setVisible(false)
	end)
	self.list = Gui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 1, -56), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 41, Parent = self.frame,
	})
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = self.list })
	self.empty = Gui.label({ Text = Strings.s2d.notebookEmpty, TextColor3 = Theme.color.textDim, Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 41, Parent = self.list })
	return self
end

function Notebook:_group(sceneId: string)
	local g = self.groups[sceneId]
	if g then
		return g
	end
	local order = 0
	for _ in self.groups do
		order += 1
	end
	g = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order + 1, ZIndex = 41, Parent = self.list })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = g })
	local step = Strings.step[sceneId]
	Gui.label({ Text = ("%s · %s"):format(sceneId, if step then step.title else ""), Font = Theme.fontBold, TextSize = 18,
		TextColor3 = Theme.color.c, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, ZIndex = 41, Parent = g })
	self.groups[sceneId] = g
	self.empty.Visible = false
	return g
end

-- snapshot — результат FormulaView:snapshot()
function Notebook:addFormula(sceneId: string, snap)
	if not snap or #snap.lines == 0 then
		return
	end
	table.insert(self.entries, { scene = sceneId, kind = "formula", title = snap.title, lines = snap.lines })
	local g = self:_group(sceneId)
	local lines = {}
	for i, tokens in snap.lines do
		lines[i] = { id = "l" .. i, general = tokens, open = true }
	end
	local fv = FormulaView.new(g, { id = snap.id .. "_nb", title = snap.title, lines = lines }, { textSize = 18, layoutOrder = #self.entries })
	fv.root.BackgroundColor3 = Theme.color.panel
end

function Notebook:addNote(sceneId: string, text: string)
	for _, e in self.entries do
		if e.kind == "note" and e.text == text then
			return
		end
	end
	table.insert(self.entries, { scene = sceneId, kind = "note", text = text })
	local g = self:_group(sceneId)
	Gui.label({ Text = "✎ " .. text, TextSize = 18, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #self.entries, ZIndex = 41, Parent = g })
end

function Notebook:setVisible(on: boolean)
	self.frame.Visible = on
end

function Notebook:toggle()
	self:setVisible(not self.frame.Visible)
end

return Notebook
