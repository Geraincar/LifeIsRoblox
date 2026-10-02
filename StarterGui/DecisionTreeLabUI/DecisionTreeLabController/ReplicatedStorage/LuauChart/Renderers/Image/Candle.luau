--!strict
--!native
--!optimize 2
-- Candle (Class): image candlestick renderer, drawing bodies, wicks and overlay lines into an EditableImage.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Internal = Root.Parent.Parent.Internal
const CandleMath = require(Internal.CandleMath)
const HitTest = require(Internal.HitTest)
const Sampling = require(Internal.Sampling)
const Types = require(Root.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	Layout: Types.Layout?,
	_Canvas: Canvas.Canvas,
}

local CandleRenderer = {}
CandleRenderer.__index = CandleRenderer

export type CandleRenderer = typeof(setmetatable({} :: Fields, CandleRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function CandleRenderer.new(Graph: any): CandleRenderer
	const self = setmetatable({} :: Fields, CandleRenderer)
	self.Graph = Graph

	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover and Cursor features

	self._Canvas = Canvas.new(Graph.UI.Candles)

	return self
end

function CandleRenderer.AdjustBounds(self: CandleRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	return CandleMath.AdjustBounds(self.Graph, MinX, MaxX, MinY, MaxY)
end

function CandleRenderer.HitTest(self: CandleRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function CandleRenderer.Destroy(self: CandleRenderer)
	self._Canvas:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function CandleRenderer.Update(self: CandleRenderer)
	const Graph = self.Graph

	const Image = self._Canvas:Prepare()
	if not Image then
		return -- not laid out yet (BaseGraph re-renders on resize), or images unavailable
	end

	const Items = CandleMath.Layout(Graph)
	if #Items == 0 then
		self.Layout = nil
		return
	end

	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const ToPixel = Draw.PixelProjector(Graph:GetVisibleBounds(), Size)

	-- The image is capped below the UI's pixel size and stretched, so hit geometry is published in UI pixels
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size

	const PixelBuffer = self._Canvas:Buffer()
	const Radius: number = Graph.CornerRadius or 0
	const WickThickness: number = Graph.WickThickness or 1
	const Layout: Types.Layout = { Items = {} }

	for _, Item in Items do
		const Color = CandleMath.Color(Graph, Item)
		const Left, Right = ToPixel(Item.X0, 0).X, ToPixel(Item.X1, 0).X
		const CenterX = (Left + Right) / 2
		const WickTop, WickBottom = ToPixel(Item.Index, Item.High).Y, ToPixel(Item.Index, Item.Low).Y
		Draw.Stroke(PixelBuffer, Width, Height, { Vector2.new(CenterX, WickTop), Vector2.new(CenterX, WickBottom) }, WickThickness, Color)

		-- A doji still shows as a one-pixel body
		local Top, Bottom = ToPixel(Item.Index, Item.BodyHigh).Y, ToPixel(Item.Index, Item.BodyLow).Y
		if Bottom - Top < 1 then
			const Middle = (Top + Bottom) / 2
			Top, Bottom = Middle - 0.5, Middle + 0.5
		end
		Draw.RoundedRect(PixelBuffer, Width, Height, Left, Top, Right, Bottom, Radius, Color)

		Layout.Items[Item.Key] = {
			Entry = Item.Entry,
			Series = 1,
			Rect = { Left * Scale.X, WickTop * Scale.Y, Right * Scale.X, WickBottom * Scale.Y },
		}
	end

	-- Overlays are plain polylines over the candles
	const Overlays: { any } = Graph.Overlays or {}
	for _, Overlay in Overlays do
		const Points: { Sampling.Point } = Overlay.Points or {}
		if #Points < 2 then
			continue
		end
		const Color: Color3 = Overlay.Color or WHITE
		const Thickness: number = Overlay.Thickness or Graph.PixelScale or 1
		const Dash: { number }? = Overlay.Dash
		for _, Run in Sampling.Runs(Sampling.Resolve(Points, Overlay.Style or "Line", Graph.StepsPerSegment)) do
			if #Run < 2 then
				continue
			end
			const Pixels: { Vector2 } = table.create(#Run)
			for Position, Point in Run do
				Pixels[Position] = ToPixel(Point.Index, Point.Value or 0)
			end
			if Dash then
				for _, Piece in Sampling.Dash(Pixels, Dash, 1) do
					Draw.Stroke(PixelBuffer, Width, Height, Piece, Thickness, Color)
				end
			else
				Draw.Stroke(PixelBuffer, Width, Height, Pixels, Thickness, Color)
			end
		end
	end

	self._Canvas:Flush()
	self.Layout = Layout
end

return CandleRenderer
