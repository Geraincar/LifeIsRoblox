--!strict
--!native
--!optimize 2
-- Candle (Class): viewport candlestick renderer. Bodies and wicks are cubes, overlay lines go through
-- Strokes, all inside one ViewportFrame.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const Mapper = require(Internal.Mapper)
const CandleMath = require(Internal.CandleMath)
const HitTest = require(Internal.HitTest)
const Sampling = require(Internal.Sampling)
const PartPool = require(Internal.PartPool)
const Strokes = require(script.Parent.Strokes)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	Layout: Types.Layout?,
	_Pool: typeof(PartPool.new()),
	_Colors: Strokes.Colors,
}

local CandleRenderer = {}
CandleRenderer.__index = CandleRenderer

export type CandleRenderer = typeof(setmetatable({} :: Fields, CandleRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function CandleRenderer.new(Graph: any): CandleRenderer
	const self = setmetatable({} :: Fields, CandleRenderer)
	self.Graph = Graph
	self.WorldHeight = 100
	self.Thickness = 5 -- Z depth of a body

	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover and Cursor features

	self._Pool = PartPool.new()
	self._Colors = Strokes.Colors()

	return self
end

function CandleRenderer.AdjustBounds(self: CandleRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	return CandleMath.AdjustBounds(self.Graph, MinX, MaxX, MinY, MaxY)
end

function CandleRenderer.HitTest(self: CandleRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function CandleRenderer.Destroy(self: CandleRenderer)
	self._Pool:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function CandleRenderer._SetupCamera(self: CandleRenderer)
	const Camera: Camera = self.Graph._Camera
	const Distance = (self.WorldHeight / 2) / math.tan(math.rad(Camera.FieldOfView / 2))
	Camera.CFrame = CFrame.new(0, 0, Distance)
	const Frame = self.Graph.UI.Candles
	if Frame.CurrentCamera ~= Camera then
		Frame.CurrentCamera = Camera
	end
end

function CandleRenderer.Update(self: CandleRenderer)
	const Graph = self.Graph
	const Pool = self._Pool
	const Colors = self._Colors

	Pool:Begin()

	const Items = CandleMath.Layout(Graph)
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	if #Items == 0 or AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		Pool:Finish()
		self.Layout = nil
		return
	end

	self:_SetupCamera()

	const Visible = Graph:GetVisibleBounds()
	const Projector = Mapper.GetWorldProjector(AbsoluteSize, Visible, self.WorldHeight)
	const ToPixel = Mapper.GetPixelProjector(AbsoluteSize, Visible)
	const WorldPerPixel = self.WorldHeight / AbsoluteSize.Y
	const Tolerance: number = Graph:GetSimplify()
	const Container = Graph.UI.Candles.Model
	const WickWorld = (Graph.WickThickness or 1) * WorldPerPixel
	const Layout: Types.Layout = { Items = {} }

	for _, Item in Items do
		const Color = CandleMath.Color(Graph, Item)
		const Left, Right = Projector.ToWorld(Item.X0, 0).X, Projector.ToWorld(Item.X1, 0).X
		const CenterX = (Left + Right) / 2
		const BodyTop, BodyBottom = Projector.ToWorld(Item.Index, Item.BodyHigh).Y, Projector.ToWorld(Item.Index, Item.BodyLow).Y
		const WickTop, WickBottom = Projector.ToWorld(Item.Index, Item.High).Y, Projector.ToWorld(Item.Index, Item.Low).Y

		const Wick: any = Pool:Get(Container, "Wicks", Assets.FillerCube)
		Strokes.SetColor(Colors, Wick, Color)
		Wick.Size = Vector3.new(WickWorld, math.max(WickTop - WickBottom, WickWorld), self.Thickness)
		Wick.Position = Vector3.new(CenterX, (WickTop + WickBottom) / 2, 0)

		-- A doji still shows as a one-pixel body
		const Body: any = Pool:Get(Container, "Bodies", Assets.FillerCube)
		Strokes.SetColor(Colors, Body, Color)
		Body.Size = Vector3.new(Right - Left, math.max(BodyTop - BodyBottom, WorldPerPixel), self.Thickness)
		Body.Position = Vector3.new(CenterX, (BodyTop + BodyBottom) / 2, 0)

		Layout.Items[Item.Key] = {
			Entry = Item.Entry,
			Series = 1,
			Rect = { ToPixel(Item.X0, 0).X, ToPixel(Item.Index, Item.High).Y, ToPixel(Item.X1, 0).X, ToPixel(Item.Index, Item.Low).Y },
		}
	end

	-- Overlays sit just in front of the candles
	const Lift = Vector3.new(0, 0, self.Thickness / 2 + 0.1)
	const Overlays: { any } = Graph.Overlays or {}
	for _, Overlay in Overlays do
		const Points: { Sampling.Point } = Overlay.Points or {}
		if #Points < 2 then
			continue
		end
		const Color: Color3 = Overlay.Color or WHITE
		const Thickness: number = (Overlay.Thickness or Graph.PixelScale or 1) * WorldPerPixel
		const Dash: { number }? = Overlay.Dash
		for _, Run in Sampling.Runs(Sampling.Resolve(Points, Overlay.Style or "Line", Graph.StepsPerSegment)) do
			if #Run < 2 then
				continue
			end
			const World: { Vector3 } = (table.create(#Run)::any)
			for Position, Point in Run do
				World[Position] = Projector.ToWorld(Point.Index, Point.Value or 0) + Lift
			end

			-- Samples the screen cannot tell apart are dropped before the parts are placed
			const Simplified = Strokes.Simplify(World, WorldPerPixel, Tolerance)
			if Dash then
				Strokes.Dashed(Pool, Colors, Container, Simplified, Thickness, Color, Dash, WorldPerPixel)
			else
				Strokes.Polyline(Pool, Colors, Container, Simplified, Thickness, Color, WorldPerPixel)
			end
		end
	end

	Pool:Finish()
	self.Layout = Layout
end

return CandleRenderer
