--!strict
--!native
--!optimize 2
-- Box (Class): image box plot renderer. Whiskers, caps, bodies, medians and outliers into an EditableImage.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Internal = Root.Parent.Parent.Internal
const BoxMath = require(Internal.BoxMath)
const BarMath = require(Internal.BarMath)
const HitTest = require(Internal.HitTest)
const Types = require(Root.Parent.Parent.Types)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	Layout: Types.Layout?,
	_Canvas: Canvas.Canvas,
}

local BoxRenderer = {}
BoxRenderer.__index = BoxRenderer

export type BoxRenderer = typeof(setmetatable({} :: Fields, BoxRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function BoxRenderer.new(Graph: any): BoxRenderer
	const self = setmetatable({} :: Fields, BoxRenderer)
	self.Graph = Graph
	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover, Cursor and Categories features
	self._Canvas = Canvas.new(Graph.UI.Boxes)
	return self
end

function BoxRenderer.AdjustBounds(self: BoxRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	return BoxMath.AdjustBounds(self.Graph, MinX, MaxX, MinY, MaxY)
end

function BoxRenderer.HitTest(self: BoxRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function BoxRenderer.Destroy(self: BoxRenderer)
	self._Canvas:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function BoxRenderer.Update(self: BoxRenderer)
	const Graph = self.Graph
	const Image = self._Canvas:Prepare()
	if not Image then
		return
	end

	const Items, Slot = BoxMath.Layout(Graph)
	if #Items == 0 then
		self.Layout = nil
		return
	end

	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const ToPixel = Draw.PixelProjector(Graph:GetVisibleBounds(), Size)
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size
	const function ToUI(Index: number, Value: number): Vector2
		return ToPixel(Index, Value) * Scale
	end

	const PixelBuffer = self._Canvas:Buffer()
	const Radius: number = Graph.CornerRadius or 0
	const WhiskerThickness: number = Graph.WhiskerThickness or 1
	const MedianThickness: number = Graph.MedianThickness or 2
	const OutlierSize: number = Graph.OutlierSize or 0
	const MedianColor: Color3 = Graph.MedianColor or Color3.new(1, 1, 1)
	const Layout: Types.Layout = { Items = {} }

	for _, Item in Items do
		const Entry = Item.Entry
		const Color = BoxMath.Color(Graph, Item)
		const Left: number, Right: number = ToPixel(Item.X0, 0).X, ToPixel(Item.X1, 0).X
		const CapLeft, CapRight = ToPixel(Item.CapX0, 0).X, ToPixel(Item.CapX1, 0).X
		const CenterX = (Left + Right) / 2
		const LowY, HighY = ToPixel(Item.Index, Entry.Low).Y, ToPixel(Item.Index, Entry.High).Y
		const Q1Y, Q3Y = ToPixel(Item.Index, Entry.Q1).Y, ToPixel(Item.Index, Entry.Q3).Y
		const MedianY = ToPixel(Item.Index, Entry.Median).Y

		Draw.Stroke(PixelBuffer, Width, Height, { Vector2.new(CenterX, HighY), Vector2.new(CenterX, Q3Y) }, WhiskerThickness, Color)
		Draw.Stroke(PixelBuffer, Width, Height, { Vector2.new(CenterX, Q1Y), Vector2.new(CenterX, LowY) }, WhiskerThickness, Color)
		Draw.Stroke(PixelBuffer, Width, Height, { Vector2.new(CapLeft, HighY), Vector2.new(CapRight, HighY) }, WhiskerThickness, Color)
		Draw.Stroke(PixelBuffer, Width, Height, { Vector2.new(CapLeft, LowY), Vector2.new(CapRight, LowY) }, WhiskerThickness, Color)
		Draw.RoundedRect(PixelBuffer, Width, Height, Left, Q3Y, Right, Q1Y, Radius, Color)
		Draw.Stroke(PixelBuffer, Width, Height, { Vector2.new(Left, MedianY), Vector2.new(Right, MedianY) }, MedianThickness, MedianColor)

		local Top: number, Bottom: number = HighY, LowY
		if OutlierSize > 0 then
			const Outliers: { number } = Entry.Outliers or {}
			for _, Value in Outliers do
				const Pixel = Vector2.new(CenterX, ToPixel(Item.Index, Value).Y)
				Draw.Stroke(PixelBuffer, Width, Height, { Pixel, Pixel }, OutlierSize, Color)
				Top, Bottom = math.min(Top, Pixel.Y), math.max(Bottom, Pixel.Y)
			end
		end

		Layout.Items[Item.Key] = {
			Entry = Entry,
			Series = 1,
			Rect = { Left * Scale.X, Top * Scale.Y, Right * Scale.X, Bottom::number * Scale.Y },
		}
	end

	self._Canvas:Flush()
	-- Box items carry the same X0, X1, Y0, Y1 and Index fields BarMath.Slots reads
	Layout.Slots, Layout.Zero = BarMath.Slots(Graph, Items :: any, Slot, ToUI)
	Layout.Orientation = "Vertical"
	self.Layout = Layout
end

return BoxRenderer
