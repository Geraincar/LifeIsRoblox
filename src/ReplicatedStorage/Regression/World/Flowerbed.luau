--!nonstrict
-- Flowerbed: клумба в мире (локально у игрока): грядка, оси, 5 цветков, прямая, нити, квадраты, пульт.
-- Система координат: origin — центр клумбы на уровне земли; локальная X — вдоль клумбы (ось x данных),
-- локальная −Z — поперёк от игрока (ось y данных), Y — вверх. 1 м = Config.STUDS_PER_M studs.
-- Всё создаётся один раз; при движении прямой меняются только CFrame/Size/Transparency.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local BedGeometry = require(Regression.Core.BedGeometry)
local Format = require(Regression.Core.Format)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)

local Flowerbed = {}
Flowerbed.__index = Flowerbed

local LINE_LIFT = 0.18
local THREAD_LIFT = 0.22
local SQUARE_LIFT = 0.04

function Flowerbed.new(args)
	local self = setmetatable({}, Flowerbed)
	local fb = args.data
	self.origin = args.origin :: CFrame
	self.W, self.H = fb.bed_length_m, fb.bed_width_m
	self.x, self.y, self.n = fb.x_m, fb.y_m, #fb.x_m
	self.pivotX = fb.pivot_x_m
	self.S = Config.STUDS_PER_M
	self.surface = 0.4
	self.model = Gui.make("Model", { Name = "RegressionFlowerbed" })
	self.flowers = {}
	self.threads, self.threadLabels, self.squares = {}, {}, {}
	self.cards = {}
	self.cardPinned, self.cardHover = {}, nil
	self:_buildBed()
	self:_buildFlowers()
	self:_buildLine()
	self:_buildResiduals()
	self:_buildPedestal()
	self.model.Parent = args.parent
	return self
end

-- ───── координаты ─────

function Flowerbed:localPos(x: number, y: number, lift: number?): Vector3
	return Vector3.new((x - self.W / 2) * self.S, self.surface + (lift or 0), -(y - self.H / 2) * self.S)
end

function Flowerbed:toWorld(x: number, y: number, lift: number?): Vector3
	return self.origin:PointToWorldSpace(self:localPos(x, y, lift))
end

function Flowerbed:cfAt(x: number, y: number, lift: number?): CFrame
	return self.origin * CFrame.new(self:localPos(x, y, lift))
end

-- Позиция игрока относительно клумбы → расстояние до её прямоугольника (studs)
function Flowerbed:distanceTo(worldPos: Vector3): number
	local p = self.origin:PointToObjectSpace(worldPos)
	return BedGeometry.distToRect(p.X, p.Z, self.W * self.S / 2, self.H * self.S / 2)
end

function Flowerbed:_attach(x: number, y: number, lift: number?): Attachment
	local a = Instance.new("Attachment")
	a.Parent = self.soil
	a.WorldPosition = self:toWorld(x, y, lift)
	return a
end

-- ───── построение ─────

function Flowerbed:_buildBed()
	local L, D = self.W * self.S, self.H * self.S
	local o = self.origin
	self.soil = Gui.part({
		Name = "Soil", Size = Vector3.new(L, 0.4, D), CFrame = o * CFrame.new(0, 0.2, 0),
		Color = Theme.color.soil, Material = Enum.Material.Ground, CanCollide = true, Parent = self.model,
	})
	for _, b in {
		{ Vector3.new(L + 1, 0.7, 0.5), Vector3.new(0, 0.35, D / 2 + 0.25) },
		{ Vector3.new(L + 1, 0.7, 0.5), Vector3.new(0, 0.35, -(D / 2 + 0.25)) },
		{ Vector3.new(0.5, 0.7, D), Vector3.new(L / 2 + 0.25, 0.35, 0) },
		{ Vector3.new(0.5, 0.7, D), Vector3.new(-(L / 2 + 0.25), 0.35, 0) },
	} do
		Gui.part({
			Name = "Border", Size = b[1], CFrame = o * CFrame.new(b[2]),
			Color = Theme.color.wood, Material = Enum.Material.Wood, CanCollide = true, Parent = self.model,
		})
	end

	-- Оси данных на земле: x вдоль ближнего края (y = 0), y вдоль левого края (x = 0)
	Gui.part({ Name = "AxisX", Size = Vector3.new(L, 0.04, 0.1), CFrame = self:cfAt(self.W / 2, 0, 0.02), Color = Theme.color.axis, Parent = self.model })
	Gui.part({ Name = "AxisY", Size = Vector3.new(0.1, 0.04, D), CFrame = self:cfAt(0, self.H / 2, 0.02), Color = Theme.color.axis, Parent = self.model })
	local function tick(x: number, y: number, text: string)
		Gui.billboard(self:_attach(x, y, 0.5), text, { Size = UDim2.fromOffset(60, 26), StudsOffsetWorldSpace = Vector3.zero, MaxDistance = 45 })
	end
	for i = 0, self.W do
		tick(i, -0.2, tostring(i))
	end
	for i = 1, self.H do
		tick(-0.2, i, tostring(i))
	end
	tick(self.W + 0.45, 0, "x, м")
	tick(0, self.H + 0.3, "y, м")

	-- Пунктир x = x̄ — ось вращения прямой (цвет «среднее»)
	local z = 0
	while z < self.H - 0.05 do
		Gui.part({ Name = "MeanDash", Size = Vector3.new(0.07, 0.03, 0.12 * self.S), CFrame = self:cfAt(self.pivotX, z + 0.06, 0.015), Color = Theme.color.mean, Parent = self.model })
		z += 0.25
	end
end

function Flowerbed:_buildFlowers()
	for i = 1, self.n do
		local x, y = self.x[i], self.y[i]
		local base = self:cfAt(x, y, 0)
		local flower = Gui.make("Model", { Name = "Flower" .. i })
		Gui.part({ Name = "Point", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.8, 0.8),
			CFrame = base * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(25, 25, 25), Parent = flower })
		Gui.part({ Name = "Stem", Size = Vector3.new(0.22, 2.2, 0.22), CFrame = base * CFrame.new(0, 1.1, 0), Color = Theme.color.stem, CanQuery = true, Parent = flower })
		Gui.part({ Name = "Leaf", Size = Vector3.new(0.7, 0.08, 0.32), CFrame = base * CFrame.new(0.32, 0.8, 0) * CFrame.Angles(0, 0, math.rad(25)), Color = Theme.color.stem, Parent = flower })
		local head = Gui.part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.62, 0.62, 0.62),
			CFrame = base * CFrame.new(0, 2.45, 0), Color = Theme.color.flowerCore, CanQuery = true, Parent = flower })
		local petal = Theme.color.petals[(i - 1) % #Theme.color.petals + 1]
		for k = 0, 5 do
			local a = k * math.pi / 3
			Gui.part({ Name = "Petal", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.3),
				CFrame = base * CFrame.new(math.cos(a) * 0.48, 2.45 + math.sin(a) * 0.48, -0.05), Color = petal, CanQuery = true, Parent = flower })
		end
		Gui.billboard(head, tostring(i), { Size = UDim2.fromOffset(30, 30), StudsOffsetWorldSpace = Vector3.new(0, 1.0, 0), MaxDistance = 50 })

		local prompt = Gui.make("ProximityPrompt", {
			ActionText = Strings.prompt.thread,
			ObjectText = Strings.prompt.flower:format(i),
			KeyboardKeyCode = Enum.KeyCode.F,
			HoldDuration = 0,
			MaxActivationDistance = 10,
			RequiresLineOfSight = false,
			Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
			Enabled = false,
			Parent = head,
		})
		flower.Parent = self.model
		self.flowers[i] = { model = flower, head = head, prompt = prompt }
		self:_buildCard(i, head)
	end
end

function Flowerbed:_buildCard(i: number, head: BasePart)
	local bb = Gui.make("BillboardGui", {
		Name = "Card", Adornee = head, Size = UDim2.fromOffset(270, 214), StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 80, Enabled = false, ResetOnSpawn = false,
	})
	local bg = Gui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.08, Parent = bb })
	Gui.corner().Parent = bg
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), Parent = bg })
	Gui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = bg })
	Gui.label({ Text = Strings.card.title:format(i), Font = Theme.fontBold, TextSize = 20, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, Parent = bg })
	local values = {}
	for order, key in { "x", "y", "yhat", "e", "e2", "share" } do
		local row = Gui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = bg })
		Gui.label({ Text = Strings.card[key], TextSize = 17, TextColor3 = Theme.color.textDim, Size = UDim2.fromScale(0.6, 1), Parent = row })
		values[key] = Gui.label({ TextSize = 18, Font = Theme.fontBold, TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(0.4, 1), Position = UDim2.fromScale(0.6, 0), Parent = row })
	end
	bb.Parent = head
	self.cards[i] = { gui = bb, values = values }
end

function Flowerbed:_buildLine()
	self.line = Gui.part({ Name = "Line", Size = Vector3.new(0.25, 0.25, 1), Color = Theme.color.line, Material = Enum.Material.Neon, Parent = self.model })
	-- Ось вращения (x̄; h): оранжевый — «высота прямой»
	self.pivot = Gui.part({ Name = "Pivot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = Theme.color.c, Parent = self.model })
	-- Метка высоты на оси y
	self.hTick = Gui.part({ Name = "HeightTick", Size = Vector3.new(0.6, 0.08, 0.18), Color = Theme.color.c, Parent = self.model })
end

function Flowerbed:_buildResiduals()
	for i = 1, self.n do
		local t = Gui.part({ Name = "Thread" .. i, Size = Vector3.new(0.15, 0.15, 1), Color = Theme.color.residual, Transparency = 1, Parent = self.model })
		local bb, lbl = Gui.billboard(t, "", { Size = UDim2.fromOffset(150, 30), StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0), Enabled = false })
		lbl.TextColor3 = Theme.color.residual
		self.threads[i] = t
		self.threadLabels[i] = { gui = bb, label = lbl }
		self.squares[i] = Gui.part({ Name = "Square" .. i, Size = Vector3.new(1, 0.05, 1), Color = Theme.color.residual, Transparency = 1, Parent = self.model })
	end
end

function Flowerbed:_buildPedestal()
	local D = self.H * self.S
	local o = self.origin
	local post = Gui.part({ Name = "Pedestal", Size = Vector3.new(1.6, 2.6, 1.0), CFrame = o * CFrame.new(0, 1.3, D / 2 + 3.5),
		Color = Theme.color.wood, Material = Enum.Material.Wood, CanCollide = true, Parent = self.model })
	local top = Gui.part({ Name = "PedestalTop", Size = Vector3.new(2.6, 0.2, 1.7),
		CFrame = o * CFrame.new(0, 2.7, D / 2 + 3.5) * CFrame.Angles(math.rad(25), 0, 0), Color = Theme.color.bg, Parent = self.model })
	local sg = Gui.make("SurfaceGui", { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, LightInfluence = 0 })
	Gui.label({ Size = UDim2.fromScale(1, 1), Text = Strings.prompt.pedestal .. "\nQ/E · Shift/Ctrl", TextSize = 26, Font = Theme.fontBold,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = sg })
	sg.Parent = top
	self.pedestal = post
	self.controlPrompt = Gui.make("ProximityPrompt", {
		ActionText = Strings.prompt.control,
		ObjectText = Strings.prompt.pedestal,
		KeyboardKeyCode = Enum.KeyCode.F,
		HoldDuration = 0,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
		Enabled = false,
		Parent = post,
	})
end

-- ───── отрисовка ─────

-- snap: снимок LineModel; vis.threadGrow[i], vis.squareGrow[i] ∈ [0; 1]
function Flowerbed:render(snap, vis)
	local S = self.S
	local rot = self.origin.Rotation

	local x0, y0, x1, y1 = BedGeometry.clipLine(snap.m, snap.c, self.W, self.H)
	if x0 then
		local p0, p1 = self:toWorld(x0, y0, LINE_LIFT), self:toWorld(x1, y1, LINE_LIFT)
		self.line.Size = Vector3.new(0.25, 0.25, (p1 - p0).Magnitude)
		self.line.CFrame = CFrame.lookAt((p0 + p1) / 2, p1, self.origin.UpVector)
		self.line.Transparency = 0
	else
		self.line.Transparency = 1
	end
	self.pivot.CFrame = self:cfAt(self.pivotX, snap.h, LINE_LIFT)
	self.hTick.CFrame = self:cfAt(-0.1, snap.h, 0.05)

	for i = 1, self.n do
		local x, y, yhat = self.x[i], self.y[i], snap.yhat[i]
		local g = vis.threadGrow[i] or 0
		local t, tl = self.threads[i], self.threadLabels[i]
		if g > 0 then
			local _, ty0, _, ty1 = BedGeometry.thread(x, y, yhat, g)
			local len = math.abs(ty1 - ty0) * S
			if len < 0.03 then
				t.Transparency = 1
			else
				t.Transparency = 0
				t.Size = Vector3.new(0.15, 0.15, len)
				t.CFrame = CFrame.new(self:toWorld(x, (ty0 + ty1) / 2, THREAD_LIFT)) * rot
			end
			local e = snap.e[i]
			tl.gui.Enabled = g >= 1 and math.abs(e) >= 0.005
			tl.label.Text = "e = " .. Format.signed(e) .. Format.NBSP .. "м"
		else
			t.Transparency = 1
			tl.gui.Enabled = false
		end

		local sg = vis.squareGrow[i] or 0
		local sq = self.squares[i]
		if sg > 0 then
			local cx, cy, side = BedGeometry.square(x, y, yhat, self.pivotX, sg)
			if side * S < 0.03 then
				sq.Transparency = 1
			else
				sq.Transparency = 0.5
				sq.Size = Vector3.new(side * S, 0.05, side * S)
				sq.CFrame = CFrame.new(self:toWorld(cx, cy, SQUARE_LIFT)) * rot
			end
		else
			sq.Transparency = 1
		end
	end
	self:_renderCards(snap, vis)
end

function Flowerbed:_renderCards(snap, vis)
	local now = os.clock()
	for i, card in self.cards do
		local hovered = self.cardHover ~= nil and self.cardHover.i == i and now - self.cardHover.t >= 0.15
		local show = self.cardPinned[i] == true or hovered
		card.gui.Enabled = show
		if show then
			local v = card.values
			local hasThread = (vis.threadGrow[i] or 0) >= 1
			v.x.Text = Format.len(self.x[i])
			v.y.Text = Format.len(self.y[i])
			v.yhat.Text = Format.len(snap.yhat[i])
			if hasThread then
				v.e.Text = Format.signed(snap.e[i]) .. Format.NBSP .. "м"
				v.e2.Text = Format.area(snap.sq[i])
				v.share.Text = if snap.L > 1e-12 then Format.percent(snap.sq[i] / snap.L) else "—"
			else
				v.e.Text, v.e2.Text, v.share.Text = "?", "?", "?"
			end
		end
	end
end

-- ───── карточки: наведение (ПК, 150 мс) и тап/клик (все устройства) ─────

function Flowerbed:toggleCard(i: number)
	self.cardPinned[i] = not self.cardPinned[i]
end

function Flowerbed:bindCards(onChanged: () -> ())
	local camera = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local models = {}
	for _, f in self.flowers do
		table.insert(models, f.model)
	end
	params.FilterDescendantsInstances = models

	local function pick(ray: Ray): number?
		local r = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		if not r then
			return nil
		end
		for i, f in self.flowers do
			if r.Instance:IsDescendantOf(f.model) then
				return i
			end
		end
		return nil
	end

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local i = pick(camera:ScreenPointToRay(input.Position.X, input.Position.Y))
		if i then
			self:toggleCard(i)
			onChanged()
		end
	end)
	UserInputService.TouchTap:Connect(function(positions, gp)
		if gp or #positions == 0 then
			return
		end
		local p = positions[1]
		local i = pick(camera:ScreenPointToRay(p.X, p.Y))
		if i then
			self:toggleCard(i)
			onChanged()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 or not UserInputService.MouseEnabled then
			return
		end
		acc = 0
		local m = UserInputService:GetMouseLocation()
		local i = pick(camera:ViewportPointToRay(m.X, m.Y))
		local cur = self.cardHover
		if i == nil then
			if cur then
				self.cardHover = nil
				onChanged()
			end
		elseif cur == nil or cur.i ~= i then
			self.cardHover = { i = i, t = os.clock() }
		elseif os.clock() - cur.t >= 0.15 and not cur.shown then
			cur.shown = true
			onChanged()
		end
	end)
end

return Flowerbed
