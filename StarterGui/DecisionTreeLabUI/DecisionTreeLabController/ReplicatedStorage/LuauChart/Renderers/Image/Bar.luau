--!strict
--!native
--!optimize 2
-- Bar (Class): image bar renderer, drawing into an EditableImage.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Internal = Root.Parent.Parent.Internal
const BarMath = require(Internal.BarMath)
const HitTest = require(Internal.HitTest)
const Types = require(Root.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const TOP: Draw.Corners = { TopLeft = true, TopRight = true }
const BOTTOM: Draw.Corners = { BottomLeft = true, BottomRight = true }
const LEFT: Draw.Corners = { TopLeft = true, BottomLeft = true }
const RIGHT: Draw.Corners = { TopRight = true, BottomRight = true }
const NONE: Draw.Corners = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	RenderPoints: { any }?,
	Layout: Types.Layout?,
	_Canvas: Canvas.Canvas,
}

local BarRenderer = {}
BarRenderer.__index = BarRenderer

export type BarRenderer = typeof(setmetatable({} :: Fields, BarRenderer))

-- ─── Internal ──────────────────────────────────────────────────────────────

-- Only the growing end of a bar is rounded, and on stacked charts only the outermost segment's
const function TipCorners(Item: BarMath.Item, Totals: BarMath.Totals, Mode: string, Horizontal: boolean): Draw.Corners
	if Mode == "Stacked" then
		const Total = if Item.Negative then Totals.Negative[Item.Index] else Totals.Positive[Item.Index]
		const Far = if Item.Negative then Item.Y0 else Item.Y1
		if Total == nil or math.abs(Far - Total) > 1e-9 then
			return NONE
		end
	end
	if Horizontal then
		return if Item.Negative then LEFT else RIGHT
	end
	return if Item.Negative then BOTTOM else TOP
end

-- ─── Construction ────────────────────────────────────────────────────────────

function BarRenderer.new(Graph: any): BarRenderer
	const self = setmetatable({} :: Fields, BarRenderer)
	self.Graph = Graph

	self.RenderPoints = nil -- what the Cursor feature snaps to
	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover feature

	self._Canvas = Canvas.new(Graph.UI.Bars)

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
	self._Canvas:Destroy()
	self.RenderPoints = nil
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function BarRenderer.Update(self: BarRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels

	const Image = self._Canvas:Prepare()
	if not Image then
		return -- not laid out yet (BaseGraph re-renders on resize), or images unavailable
	end

	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const BasePixel = Draw.PixelProjector(Graph:GetVisibleBounds(), Size)

	-- Data (Index, Value) to image pixels, honoring the chart's orientation
	const function ToPixel(Index: number, Value: number): Vector2
		return BasePixel(Graph:_ToScreenAxes(Index, Value))
	end

	-- The image is capped below the UI's pixel size and stretched, so geometry other features read
	-- (labels, hit tests, categories) is published in UI pixels
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size
	const function ToUI(Index: number, Value: number): Vector2
		return ToPixel(Index, Value) * Scale
	end

	-- One slot on screen, so category labels between the slots can reserve their room
	const Horizontal = Graph.Orientation == "Horizontal"
	const SlotUnits = BarMath.Slot(Graph.Series or {})
	const SlotPixels = if Horizontal
		then math.abs(ToUI(SlotUnits, 0).Y - ToUI(0, 0).Y)
		else math.abs(ToUI(SlotUnits, 0).X - ToUI(0, 0).X)

	const Items, Totals, Mode, Slot, Ratio = BarMath.Layout(Graph, SlotPixels)
	if #Items == 0 then
		self.RenderPoints = nil
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end
	self.RenderPoints = Graph.Data

	const PixelBuffer = self._Canvas:Buffer()
	const Radius: number = Graph.CornerRadius or 0

	const Layout: Types.Layout = { Items = {} }

	for _, Item in Items do
		const Entry = Item.Entry
		const Color = BarMath.Color(Graph, Item)
		const Corners = TipCorners(Item, Totals, Mode, Horizontal)

		-- Either corner may end up left or right, top or bottom
		const CornerA = ToPixel(Item.X0, Item.Y0)
		const CornerB = ToPixel(Item.X1, Item.Y1)
		const Left, Right = math.min(CornerA.X, CornerB.X), math.max(CornerA.X, CornerB.X)
		const Top, Bottom = math.min(CornerA.Y, CornerB.Y), math.max(CornerA.Y, CornerB.Y)

		const Border = Entry.Border
		const BorderThickness = math.min(if Border then (Border.Thickness or 0) else 0, (Right - Left) / 2, (Bottom - Top) / 2)

		if BorderThickness > 0 then
			-- The border is the full rounded rect with the fill inset inside it
			Draw.RoundedRect(PixelBuffer, Width, Height, Left, Top, Right, Bottom, Radius, Border.Color or Color3.new(0, 0, 0), nil, Corners)
			Draw.RoundedRect(PixelBuffer, Width, Height, Left + BorderThickness, Top + BorderThickness, Right - BorderThickness, Bottom - BorderThickness, math.max(Radius - BorderThickness, 0), Color, Entry.Gradient, Corners)
		else
			Draw.RoundedRect(PixelBuffer, Width, Height, Left, Top, Right, Bottom, Radius, Color, Entry.Gradient, Corners)
		end

		Layout.Items[Item.Key] = { Entry = Entry, Series = Item.Series, Rect = { Left * Scale.X, Top * Scale.Y, Right * Scale.X, Bottom * Scale.Y } }
	end

	self._Canvas:Flush()
	Layout.Slots, Layout.Zero = BarMath.Slots(Graph, Items, Slot, ToUI)
	Layout.Orientation = Graph.Orientation or "Vertical"
	self.Layout = Layout
	if Labels then
		Labels:Set(BarMath.Labels(Graph, Items, Totals, Mode, Slot, ToUI, Ratio))
	end
end

return BarRenderer
