--!nonstrict
-- Viewport3D: интерактивная 3D-сцена в ViewportFrame (2D.4).
--   Орбитальная камера: перетаскивание (мышь / один палец) — поворот, колесо / щипок — зум, reset() — исходный вид.
--   Подписи и выделение — 2D-оверлей поверх кадра; позиции считаются проекцией (без Mouse.Target и
--   ViewportPointToRay — они работают в координатах экрана, а не фрейма).
--   Тап без перетаскивания → onTap(pos), pos — пиксели внутри фрейма.

local UserInputService = game:GetService("UserInputService")

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Drag = require(Regression.UI.Drag)

local Viewport3D = {}
Viewport3D.__index = Viewport3D

local TAP_PX = 8

function Viewport3D.new(parent: GuiObject, opts)
	local self = setmetatable({}, Viewport3D)
	opts = opts or {}
	self.center = opts.center or Vector3.zero
	self.home = { yaw = opts.yaw or math.rad(35), pitch = opts.pitch or math.rad(22), radius = opts.radius or 16 }
	self.yaw, self.pitch, self.radius = self.home.yaw, self.home.pitch, self.home.radius
	self.minR, self.maxR = opts.minRadius or 8, opts.maxRadius or 32
	self.totalYaw = 0 -- накопленный поворот, градусы (2D.4: «повернуть облако минимум на 90°»)
	self.onTap = nil :: ((Vector2) -> ())?
	self.onCamera = nil :: (() -> ())?

	self.frame = Gui.make("ViewportFrame", {
		Name = "Viewport3D", BackgroundColor3 = Theme.color.panel, BorderSizePixel = 0, Size = opts.size or UDim2.fromScale(1, 1),
		Position = opts.position or UDim2.new(), Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = parent,
	})
	Gui.corner().Parent = self.frame
	self.world = Gui.make("WorldModel", { Parent = self.frame })
	self.camera = Gui.make("Camera", { FieldOfView = 50, Parent = self.frame })
	self.frame.CurrentCamera = self.camera
	self.overlay = Gui.frame({ Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = self.frame })

	local start, last, moved
	self.drag = Drag.attach(self.frame, {
		began = function(p)
			start, last, moved = p, p, false
			return true
		end,
		moved = function(p)
			if not last then
				return
			end
			local d = p - last
			last = p
			if (p - start).Magnitude > TAP_PX then
				moved = true
			end
			local dyaw = -d.X * 0.008
			self.yaw += dyaw
			self.totalYaw += math.deg(math.abs(dyaw))
			self.pitch = math.clamp(self.pitch + d.Y * 0.006, math.rad(-10), math.rad(80))
			self:updateCamera()
		end,
		ended = function(p)
			if start and not moved and self.onTap then
				local a = self.frame.AbsolutePosition
				self.onTap(Vector2.new(start.X - a.X, start.Y - a.Y))
			end
			start, last = nil, nil
		end,
	})
	self.conns = {}
	table.insert(self.conns, self.frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:zoom(-input.Position.Z * 1.5)
		end
	end))
	table.insert(self.conns, UserInputService.TouchPinch:Connect(function(_, scale, _, state)
		if self.frame.Visible and state == Enum.UserInputState.Change and scale and scale > 0 then
			self:zoom((1 - scale) * 4)
		end
	end))
	self:updateCamera()
	return self
end

function Viewport3D:zoom(d: number)
	self.radius = math.clamp(self.radius + d, self.minR, self.maxR)
	self:updateCamera()
end

function Viewport3D:reset()
	self.yaw, self.pitch, self.radius = self.home.yaw, self.home.pitch, self.home.radius
	self:updateCamera()
end

function Viewport3D:updateCamera()
	local cp = math.cos(self.pitch)
	local offset = Vector3.new(math.sin(self.yaw) * cp, math.sin(self.pitch), math.cos(self.yaw) * cp) * self.radius
	self.camera.CFrame = CFrame.lookAt(self.center + offset, self.center)
	if self.onCamera then
		self.onCamera()
	end
end

-- Мировая точка → пиксели внутри фрейма; visible = false, если за камерой
function Viewport3D:project(worldPos: Vector3): (number, number, boolean)
	local cam = self.camera
	local p = cam.CFrame:PointToObjectSpace(worldPos) -- камера смотрит по −Z
	if p.Z >= -0.05 then
		return 0, 0, false
	end
	local size = self.frame.AbsoluteSize
	local w, h = if size.X > 1 then size.X else 600, if size.Y > 1 then size.Y else 420
	local tanY = math.tan(math.rad(cam.FieldOfView) / 2) -- FieldOfView — вертикальный угол
	local aspect = w / h
	local nx = (p.X / -p.Z) / (tanY * aspect)
	local ny = (p.Y / -p.Z) / tanY
	return (nx + 1) / 2 * w, (1 - ny) / 2 * h, true
end

-- Тонкая деталь в мире вьюпорта
function Viewport3D:part(props)
	local defaults = { Parent = self.world }
	for k, v in props or {} do
		defaults[k] = v
	end
	return Gui.part(defaults)
end

-- Отрезок-брусок между двумя точками (переиспользуемый: передай существующий part)
function Viewport3D:segment(part: BasePart?, a: Vector3, b: Vector3, thickness: number, color: Color3)
	local p = part or self:part({ Material = Enum.Material.SmoothPlastic })
	local len = (b - a).Magnitude
	if len < 1e-3 then
		p.Transparency = 1
		return p
	end
	p.Transparency = 0
	if math.abs((b - a).Unit.Y) > 0.99 then
		-- вертикаль: lookAt с осью вверх вырождается
		p.Size = Vector3.new(thickness, len, thickness)
		p.CFrame = CFrame.new((a + b) / 2)
	else
		p.Size = Vector3.new(thickness, thickness, len)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
	end
	p.Color = color
	return p
end

function Viewport3D:Destroy()
	self.drag.Destroy()
	for _, c in self.conns do
		c:Disconnect()
	end
	self.frame:Destroy()
end

return Viewport3D
