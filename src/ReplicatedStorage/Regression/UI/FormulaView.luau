--!nonstrict
-- FormulaView: формула как данные (ui-system.md §2).
--   Три слоя: общий вид · с числами (по умолчанию) · результат (всегда справа). Тап по формуле — смена слоя.
--   Строки раскрываются по одной: закрытая строка — «🔒 подсказка», открытие ≤ 0,4 с.
--   Токен с bind ↔ объект: наведение/тап ставит store.highlight = bind; подсвеченный токен получает фон цвета объекта.
--   Обновление чисел не пересоздаёт Instance, если структура формулы не изменилась.
--
--   local T = FormulaView.T
--   local fv = FormulaView.new(parent, {
--       id = "DLDC", title = "Производная по c", toNotebook = true,
--       lines = {
--           { id = "deriv", general = { T.d("L", "c"), " = −2·", T.sum(), "(", T.sub("y", "i"), " − ", T.sym("m", "m"), "·", T.sub("x", "i"), " − ", T.sym("c", "c"), ")" },
--             numbers = function(s) return { ... } end, result = function(s) return Format.num(s.dldc, 2) end,
--             hint = "сделай 5 записей" },
--       } }, { store = store })
--   fv:unlock("deriv"); fv:refresh(state); fv:snapshot() → { title, lines = { "строка", ... } }

local TweenService = game:GetService("TweenService")

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)

local FormulaView = {}
FormulaView.__index = FormulaView

-- ───── токены ─────

local T = {}
FormulaView.T = T

-- Символ объекта: цвет из Theme.color[color], bind — id объекта на графике
function T.sym(text: string, color: string?, bind: string?)
	return { k = "sym", text = text, color = color, bind = bind or color }
end
-- Число или текст цветом объекта, без привязки
function T.col(text: string, color: string)
	return { k = "sym", text = text, color = color }
end
-- Черта над буквой (x̄, ȳ) — Frame над токеном
function T.bar(text: string, color: string?, bind: string?)
	return { k = "bar", text = text, color = color, bind = bind }
end
-- «Шляпка» (ŷ) — маленький символ над токеном
function T.hat(text: string, color: string?, bind: string?)
	return { k = "hat", text = text, color = color, bind = bind }
end
function T.sub(base: any, sub: string, color: string?, bind: string?)
	return { k = "sub", base = base, small = sub, color = color, bind = bind }
end
function T.sup(base: any, sup: string, color: string?, bind: string?)
	return { k = "sup", base = base, small = sup, color = color, bind = bind }
end
function T.frac(num: { any }, den: { any })
	return { k = "frac", num = num, den = den }
end
-- Σ, крупнее текста
function T.sum()
	return { k = "big", text = "Σ" }
end
-- dL/dm как дробь
function T.d(f: string, v: string, color: string?)
	return T.frac({ "d" .. f }, { { k = "sym", text = "d" .. v, color = color } })
end
function T.res(text: string, color: string?)
	return { k = "res", text = text, color = color }
end

local function colorOf(name: string?): Color3
	if not name then
		return Theme.color.text
	end
	if name == "m" then
		return Theme.color.mText -- на тёмном фоне — светлый тон синего
	end
	return Theme.color[name] or Theme.color.text
end

-- ───── построение ─────

local function signature(tokens): string
	local parts = {}
	for _, t in tokens do
		if type(t) == "string" then
			table.insert(parts, "s")
		elseif t.k == "frac" then
			table.insert(parts, "f(" .. signature(t.num) .. "/" .. signature(t.den) .. ")")
		elseif t.k == "sub" or t.k == "sup" then
			table.insert(parts, t.k .. "(" .. signature({ t.base }) .. ")" .. (t.bind or ""))
		else
			table.insert(parts, t.k .. (t.bind or "") .. (t.color or ""))
		end
	end
	return table.concat(parts, ",")
end

function FormulaView.new(parent: GuiObject, spec, ctx)
	local self = setmetatable({}, FormulaView)
	ctx = ctx or {}
	self.spec = spec
	self.id = spec.id
	self.store = ctx.store
	self.size = ctx.textSize or 22
	self.layer = "numbers"
	self.unlocked = {}
	self.rows = {}
	self.bound = {} -- bind → { GuiObject }
	self.conns = {}
	self.state = ctx.state or {}

	self.root = Gui.frame({ Name = "Formula_" .. spec.id, BackgroundColor3 = Theme.color.panel, BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = ctx.layoutOrder or 0, Parent = parent })
	Gui.corner().Parent = self.root
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8), Parent = self.root })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = self.root })

	local head = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = self.root })
	self.title = Gui.label({ Size = UDim2.new(1, -90, 1, 0), TextSize = 16, TextColor3 = Theme.color.textDim, Text = spec.title or "",
		Parent = head })
	-- переключатель слоёв: «Σ» — общий вид, «12» — с числами
	self.layerBtns = {}
	for i, l in { { "general", "Σ" }, { "numbers", "12" } } do
		local b = Gui.button({ Text = l[2], TextSize = 15, Size = UDim2.fromOffset(40, 22), AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(2 - i) * 44, 0, 0), Parent = head })
		b.Activated:Connect(function()
			self:setLayer(l[1])
		end)
		self.layerBtns[l[1]] = b
	end
	self:_paintLayerBtns()

	for i, line in spec.lines do
		self:_buildRow(line, i)
		if line.open then
			self.unlocked[line.id] = true
		end
	end
	if self.store then
		table.insert(self.conns, self.store.Changed:Connect("highlight", function(v)
			self:_paintHighlight(v)
		end))
	end
	self:refresh(self.state)
	return self
end

function FormulaView:_paintLayerBtns()
	for name, b in self.layerBtns do
		b.BackgroundColor3 = if name == self.layer then Theme.color.loss else Theme.color.panel2
		b.TextColor3 = if name == self.layer then Theme.color.bg else Theme.color.text
	end
end

function FormulaView:setLayer(layer: string)
	self.layer = layer
	self:_paintLayerBtns()
	for _, row in self.rows do
		row.sig = nil -- перестроить
	end
	self:refresh(self.state)
end

function FormulaView:_buildRow(line, order: number)
	local row = Gui.frame({ Name = "Line_" .. line.id, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = self.root })
	-- тап по строке — смена слоя (кнопка поверх, под токенами)
	local tap = Gui.make("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
		ZIndex = 1, Parent = row })
	tap.Activated:Connect(function()
		self:setLayer(if self.layer == "numbers" then "general" else "numbers")
	end)
	local content = Gui.frame({ Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 2, Parent = row })
	Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = content })
	local scale = Gui.make("UIScale", { Scale = 1, Parent = content })
	local lock = Gui.label({ Name = "Locked", Size = UDim2.new(1, 0, 0, self.size + 6), TextSize = self.size - 4,
		TextColor3 = Theme.color.textDim, Visible = false, ZIndex = 2, Parent = row })
	local r = { line = line, frame = row, content = content, scale = scale, lock = lock, leaves = {}, sig = nil }
	-- длинная строка ужимается под ширину панели
	local function fit()
		local avail = row.AbsoluteSize.X
		local w = content.AbsoluteSize.X / math.max(scale.Scale, 0.01)
		scale.Scale = if w > 1 and avail > 1 then math.clamp(avail / w, 0.55, 1) else 1
	end
	table.insert(self.conns, content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	table.insert(self.conns, row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	self.rows[line.id] = r
	self.rows[order] = r
end

-- Лист: TextLabel / TextButton (если есть bind)
function FormulaView:_leaf(parent: Instance, text: string, opts): TextLabel
	opts = opts or {}
	local size = opts.size or self.size
	local cls = if opts.bind then "TextButton" else "TextLabel"
	local l = Gui.make(cls, {
		BackgroundTransparency = 1, BackgroundColor3 = colorOf(opts.color), BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, opts.height or (size + 8)), AutomaticSize = Enum.AutomaticSize.X,
		Font = opts.font or Theme.fontMedium, TextSize = size, TextColor3 = colorOf(opts.color), Text = text,
		RichText = false, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = opts.order or 0, ZIndex = 3, Parent = parent,
	})
	if cls == "TextButton" then
		(l :: any).AutoButtonColor = false
		Gui.corner(UDim.new(0, 4)).Parent = l
		local bind = opts.bind
		self.bound[bind] = self.bound[bind] or {}
		table.insert(self.bound[bind], l)
		l.MouseEnter:Connect(function()
			if self.store then self.store:set("highlight", bind) end
		end)
		l.MouseLeave:Connect(function()
			if self.store and self.store:get("highlight") == bind then self.store:set("highlight", nil) end
		end)
		;(l :: any).Activated:Connect(function()
			if self.store then
				self.store:set("highlight", if self.store:get("highlight") == bind then nil else bind)
			end
		end)
	end
	return l
end

function FormulaView:_build(parent: Instance, tokens, leaves, order0: number?)
	local order = order0 or 0
	for _, t in tokens do
		order += 1
		if type(t) == "string" then
			table.insert(leaves, self:_leaf(parent, t, { order = order }))
		elseif t.k == "sym" or t.k == "res" or t.k == "big" then
			table.insert(leaves, self:_leaf(parent, t.text, {
				order = order, color = t.color, bind = t.bind,
				font = if t.k == "res" then Theme.fontBold else nil,
				size = if t.k == "big" then math.floor(self.size * 1.3) else nil, height = self.size + 8,
			}))
		elseif t.k == "bar" or t.k == "hat" then
			local l = self:_leaf(parent, t.text, { order = order, color = t.color, bind = t.bind })
			table.insert(leaves, l)
			if t.k == "bar" then
				Gui.frame({ Name = "Bar", BackgroundColor3 = colorOf(t.color), AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(0.75, 0, 0, 2), ZIndex = 4, Parent = l })
			else
				Gui.label({ Name = "Hat", Text = "ˆ", TextSize = math.floor(self.size * 0.8), TextColor3 = colorOf(t.color),
					AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -math.floor(self.size * 0.35)),
					Size = UDim2.fromOffset(10, self.size), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = l })
			end
		elseif t.k == "sub" or t.k == "sup" then
			local box = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(0, self.size + 8), AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = order, ZIndex = 3, Parent = parent })
			Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
			local base = t.base
			if type(base) == "string" then
				base = { k = "sym", text = base, color = t.color, bind = t.bind }
			end
			self:_build(box, { base }, leaves, 0)
			local smallSize = math.floor(self.size * 0.65)
			local holder = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(0, self.size + 8), AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 10, ZIndex = 3, Parent = box })
			local sl = self:_leaf(holder, t.small, { size = smallSize, color = t.color, height = smallSize + 2 })
			sl.Position = UDim2.fromOffset(0, if t.k == "sub" then math.floor(self.size * 0.5) else 0)
			table.insert(leaves, sl)
		elseif t.k == "frac" then
			local box = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = order, ZIndex = 3, Parent = parent })
			Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
			for i, part in { t.num, t.den } do
				local rowf = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
					LayoutOrder = i * 2 - 1, ZIndex = 3, Parent = box })
				Gui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder, Parent = rowf })
				self:_build(rowf, part, leaves, 0)
				if i == 1 then
					Gui.frame({ Name = "FracBar", BackgroundColor3 = Theme.color.text, Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 2, ZIndex = 3, Parent = box })
				end
			end
		end
	end
end

-- Тексты листьев в том же порядке, что _build (для обновления на месте)
local function leafTexts(tokens, out)
	for _, t in tokens do
		if type(t) == "string" then
			table.insert(out, t)
		elseif t.k == "frac" then
			leafTexts(t.num, out)
			leafTexts(t.den, out)
		elseif t.k == "sub" or t.k == "sup" then
			local base = if type(t.base) == "string" then t.base else t.base.text
			table.insert(out, base)
			table.insert(out, t.small)
		else
			table.insert(out, t.text)
		end
	end
	return out
end

function FormulaView:_tokensFor(line, s)
	local tokens
	if self.layer == "general" or not line.numbers then
		tokens = if type(line.general) == "function" then line.general(s) else line.general
	else
		tokens = line.numbers(s)
	end
	tokens = table.clone(tokens or {})
	local res = line.result and line.result(s)
	if res then
		table.insert(tokens, T.res(" = " .. res, line.resultColor))
	end
	return tokens
end

-- Перерисовать числа (не чаще 30 Гц — троттлит вызывающий)
function FormulaView:refresh(s)
	self.state = s or self.state
	for i = 1, #self.spec.lines do
		local r = self.rows[i]
		local line = r.line
		local open = self.unlocked[line.id] == true
		r.content.Visible = open
		r.lock.Visible = not open
		if not open then
			r.lock.Text = "🔒 " .. (line.hint or "…")
			continue
		end
		local ok, tokens = pcall(self._tokensFor, self, line, self.state)
		if not ok then
			warn("FormulaView " .. self.id .. "." .. line.id .. ": " .. tostring(tokens))
			continue
		end
		local sig = signature(tokens)
		if sig == r.sig then
			local texts = leafTexts(tokens, {})
			for k, l in r.leaves do
				if texts[k] and l.Text ~= texts[k] then
					l.Text = texts[k]
				end
			end
		else
			for _, c in r.content:GetChildren() do
				if not c:IsA("UIListLayout") and not c:IsA("UIScale") then
					c:Destroy()
				end
			end
			for b, list in self.bound do
				for k = #list, 1, -1 do
					if list[k]:IsDescendantOf(r.content) or list[k].Parent == nil then
						table.remove(list, k)
					end
				end
			end
			r.leaves = {}
			self:_build(r.content, tokens, r.leaves)
			r.sig = sig
			self:_paintHighlight(self.store and self.store:get("highlight"))
		end
	end
end

function FormulaView:isUnlocked(lineId: string): boolean
	return self.unlocked[lineId] == true
end

-- Открыть строку (≤ 0,4 с: вспышка фона)
function FormulaView:unlock(lineId: string)
	if self.unlocked[lineId] then
		return false
	end
	self.unlocked[lineId] = true
	self:refresh(self.state)
	local r = self.rows[lineId]
	if r then
		r.frame.BackgroundColor3 = Theme.color.loss
		r.frame.BackgroundTransparency = 0.6
		TweenService:Create(r.frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end
	return true
end

function FormulaView:_paintHighlight(bind: string?)
	for b, list in self.bound do
		for _, l in list do
			l.BackgroundTransparency = if b == bind then 0.75 else 1
		end
	end
end

-- Для блокнота: открытые строки в виде с числами (токены, статичные — последние значения)
function FormulaView:snapshot()
	local lines = {}
	for i = 1, #self.spec.lines do
		local line = self.spec.lines[i]
		if self.unlocked[line.id] then
			local saved = self.layer
			self.layer = "numbers"
			local ok, tokens = pcall(self._tokensFor, self, line, self.state)
			self.layer = saved
			if ok then
				table.insert(lines, tokens)
			end
		end
	end
	return { id = self.id, title = self.spec.title or self.id, lines = lines }
end

function FormulaView:Destroy()
	for _, c in self.conns do
		c:Disconnect()
	end
	self.conns = {}
	self.root:Destroy()
end

return FormulaView
