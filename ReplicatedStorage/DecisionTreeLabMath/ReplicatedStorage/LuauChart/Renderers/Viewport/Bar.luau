--!strict
--!native
--!optimize 2
-- Bar (Class): viewport bar renderer, drawing parts inside ViewportFrames. CornerRadius and per-bar
-- Gradient need the Image renderer; parts can do neither.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const Mapper = require(Internal.Mapper)
const BarMath = require(Internal.BarMath)
const HitTest = require(Internal.HitTest)
const PartPool = require(Internal.PartPool)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	RenderPoints: { any }?,
	Layout: Types.Layout?,
	_Pool: typeof(PartPool.new()),
}

local BarRenderer = {}
BarRenderer.__index = BarRenderer

export type BarRenderer = typeof(setmetatable({} :: Fields, BarRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function BarRenderer.new(Graph: any): BarRenderer
	const self = setmetatable({} :: Fields, BarRenderer)
	self.Graph = Graph
	self.WorldHeight = 100
	self.Thickness = 5 -- Z depth of a bar

	self.RenderPoints = nil -- what the Cursor feature snaps to
	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover feature

	self._Pool = PartPool.new()

	return self
end

-- ─── Bounds ──────────────────────────────────────────────────────────────────

-- Called by Cartesian in data axes, before any orientation swap: pads the index axis so the outer bars
-- keep their full width, keeps the zero floor in view, and leaves headroom for labels
function BarRenderer.AdjustBounds(self: BarRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	const Half = BarMath.Slot(self.Graph.Series or {}) * 0.5
	const ZeroFloor = self.Graph.ZeroFloor ~= false
	const FloorMin = if ZeroFloor then math.min(MinY, 0) else MinY
	const FloorMax = if ZeroFloor then math.max(MaxY, 0) else MaxY

	const Headroom = (self.Graph.Headroom or 0.08) * (FloorMax - FloorMin)
	return MinX - Half, MaxX + Half,
		if FloorMin < 0 or not ZeroFloor then FloorMin - Headroom else FloorMin,
		if FloorMax > 0 or not ZeroFloor then FloorMax + Headroom else FloorMax
end

function BarRenderer.HitTest(self: BarRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function BarRenderer.Destroy(self: BarRenderer)
	self._Pool:Destroy()
	self.RenderPoints = nil
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function BarRenderer._SetupCamera(self: BarRenderer)
	const UI = self.Graph.UI
	const Camera: Camera = self.Graph._Camera

	const Distance = (self.WorldHeight / 2) / math.tan(math.rad(Camera.FieldOfView / 2))
	Camera.CFrame = CFrame.new(0, 0, Distance)

	if UI.Bars.CurrentCamera ~= Camera then
		UI.Bars.CurrentCamera = Camera
	end
end

function BarRenderer._DrawLine(self: BarRenderer, Parent: Instance, From: Vector3, To: Vector3, Thickness: number, Color: Color3)
	const Distance = (To - From).Magnitude
	if Distance < 0.001 then
		return
	end

	const Line: any = self._Pool:Get(Parent, "Borders", Assets.FillerCube)
	Line.Size = Vector3.new(Thickness, Thickness, Distance)
	Line.CFrame = CFrame.lookAt(From, To) * CFrame.new(0, 0, -Distance / 2)
	Line.Color = Color
end

function BarRenderer.Update(self: BarRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Pool = self._Pool

	Pool:Begin()

	const function Clear()
		Pool:Finish()
		self.RenderPoints = nil
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
	end

	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	if AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		Clear()
		return
	end

	const Visible = Graph:GetVisibleBounds()
	const BaseWorld = Mapper.GetWorldProjector(AbsoluteSize, Visible, self.WorldHeight)
	const BasePixel = Mapper.GetPixelProjector(AbsoluteSize, Visible)

	-- Data (Index, Value) to world and pixels, honoring the chart's orientation
	const function ToWorld(Index: number, Value: number): Vector3
		return BaseWorld.ToWorld(Graph:_ToScreenAxes(Index, Value))
	end
	const function ToPixel(Index: number, Value: number): Vector2
		return BasePixel(Graph:_ToScreenAxes(Index, Value))
	end

	-- One slot on screen, so category labels between the slots can reserve their room
	const Horizontal = Graph.Orientation == "Horizontal"
	const SlotUnits = BarMath.Slot(Graph.Series or {})
	const SlotPixels = if Horizontal
		then math.abs(ToPixel(SlotUnits, 0).Y - ToPixel(0, 0).Y)
		else math.abs(ToPixel(SlotUnits, 0).X - ToPixel(0, 0).X)

	const Items, Totals, Mode, Slot, Ratio = BarMath.Layout(Graph, SlotPixels)
	if #Items == 0 then
		Clear()
		return
	end

	self.RenderPoints = Graph.Data
	self:_SetupCamera()

	const Container = Graph.UI.Bars.Model
	const WorldPerPixel = self.WorldHeight / AbsoluteSize.Y
	const FrontZ = self.Thickness / 2 -- borders sit on the face nearest the camera

	const Layout: Types.Layout = { Items = {} }

	for _, Item in Items do
		const Entry = Item.Entry
		const Color = BarMath.Color(Graph, Item)

		-- Either corner may end up left or right, top or bottom
		const CornerA = ToWorld(Item.X0, Item.Y0)
		const CornerB = ToWorld(Item.X1, Item.Y1)
		const Left, Right = math.min(CornerA.X, CornerB.X), math.max(CornerA.X, CornerB.X)
		const Bottom, Top = math.min(CornerA.Y, CornerB.Y), math.max(CornerA.Y, CornerB.Y)

		const Bar: any = Pool:Get(Container, "Bars", Assets.FillerCube)
		Bar.Size = Vector3.new(Right - Left, Top - Bottom, self.Thickness)
		Bar.Position = Vector3.new((Left + Right) / 2, (Top + Bottom) / 2, 0)
		Bar.Color = Color

		-- The border is four cubes on the front face, shifted inside the bar so it does not grow the bar
		const Border = Entry.Border
		if Border and Border.Thickness and Border.Thickness > 0 then
			const BorderWorld: number = Border.Thickness * WorldPerPixel
			const BorderColor: Color3 = Border.Color or Color3.new(0, 0, 0)
			const HalfBorder = BorderWorld / 2

			const InnerLeft, InnerRight = Left + HalfBorder, Right - HalfBorder
			const InnerTop, InnerBottom = Top - HalfBorder, Bottom + HalfBorder
			const Depth = FrontZ + HalfBorder

			self:_DrawLine(Container, Vector3.new(Left, InnerTop, Depth), Vector3.new(Right, InnerTop, Depth), BorderWorld, BorderColor)
			self:_DrawLine(Container, Vector3.new(Left, InnerBottom, Depth), Vector3.new(Right, InnerBottom, Depth), BorderWorld, BorderColor)
			self:_DrawLine(Container, Vector3.new(InnerLeft, Top, Depth), Vector3.new(InnerLeft, Bottom, Depth), BorderWorld, BorderColor)
			self:_DrawLine(Container, Vector3.new(InnerRight, Top, Depth), Vector3.new(InnerRight, Bottom, Depth), BorderWorld, BorderColor)
		end

		const PixelA = ToPixel(Item.X0, Item.Y0)
		const PixelB = ToPixel(Item.X1, Item.Y1)
		Layout.Items[Item.Key] = {
			Entry = Entry,
			Series = Item.Series,
			Rect = { math.min(PixelA.X, PixelB.X), math.min(PixelA.Y, PixelB.Y), math.max(PixelA.X, PixelB.X), math.max(PixelA.Y, PixelB.Y) },
		}
	end

	Pool:Finish()
	Layout.Slots, Layout.Zero = BarMath.Slots(Graph, Items, Slot, ToPixel)
	Layout.Orientation = Graph.Orientation or "Vertical"
	self.Layout = Layout
	if Labels then
		Labels:Set(BarMath.Labels(Graph, Items, Totals, Mode, Slot, ToPixel, Ratio))
	end
end

return BarRenderer
