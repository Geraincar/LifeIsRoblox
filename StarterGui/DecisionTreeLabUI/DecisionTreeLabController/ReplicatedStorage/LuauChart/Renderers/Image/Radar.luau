--!strict
--!native
--!optimize 2
-- Radar (Class): image radar renderer. Rings and spokes, then one filled and outlined polygon per series
-- into an EditableImage, with axis labels around the rim.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Stacking = require(Root.Parent.Parent.Internal.Stacking)
const Types = require(Root.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const TAU = math.pi * 2

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	_Canvas: Canvas.Canvas,
}

local RadarRenderer = {}
RadarRenderer.__index = RadarRenderer

export type RadarRenderer = typeof(setmetatable({} :: Fields, RadarRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function RadarRenderer.new(Graph: any): RadarRenderer
	const self = setmetatable({} :: Fields, RadarRenderer)
	self.Graph = Graph
	self._Canvas = Canvas.new(Graph.UI.Plot)
	return self
end

function RadarRenderer.Destroy(self: RadarRenderer)
	self._Canvas:Destroy()
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function RadarRenderer.Update(self: RadarRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Image = self._Canvas:Prepare()
	if not Image then
		return
	end

	const Axes: { string } = Graph.Axes or {}
	const SeriesList: { any } = Graph.Series or {}
	const Count = #Axes
	if Count < 3 then
		if Labels then
			Labels:Clear()
		end
		return
	end

	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const Center = Size / 2
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size
	const ShowLabels = Labels and Labels.Enabled
	const Reserve: number = if ShowLabels then (Labels.OutsideMargin or 64) else 0
	const Radius = (math.min(Width, Height) / 2 - Reserve) * (1 - (Graph.Padding or 0))
	if Radius <= 0 then
		return
	end

	local Max: number = Graph.Max or 0
	if not Graph.Max then
		for _, Series in SeriesList do
			const Values: { number } = Series.Values
			for _, Value in Values do
				Max = math.max(Max, Value)
			end
		end
	end
	if Max <= 0 then
		Max = 1
	end

	const Start = math.rad(Graph.StartAngle or 0)
	const Step = TAU / Count
	const Directions: { Vector2 } = (table.create(Count)::any)
	for Axis = 1, Count do
		Directions[Axis] = Draw.Dir(Start + (Axis - 1) * Step)
	end

	const PixelBuffer = self._Canvas:Buffer()

	-- Rings and spokes
	const GridColor: Color3 = Graph.GridColor or WHITE
	const GridTransparency: number = Graph.GridTransparency or 0
	const Rings: number = Graph.Rings or 4
	for Ring = 1, Rings do
		const RingRadius = Radius * Ring / Rings
		const Points: { Vector2 } = (table.create(Count + 1)::any)
		for Axis = 1, Count do
			Points[Axis] = Center + Directions[Axis] * RingRadius
		end
		Points[Count + 1] = Points[1]
		Draw.Stroke(PixelBuffer, Width, Height, Points, 1, GridColor, GridTransparency)
	end
	for Axis = 1, Count do
		Draw.Stroke(PixelBuffer, Width, Height, { Center, Center + Directions[Axis] * Radius }, 1, GridColor, GridTransparency)
	end

	for _, SeriesIndex in Stacking.Order(SeriesList) do
		const Series = SeriesList[SeriesIndex]
		const Color: Color3 = Series.Color or WHITE
		const Values: { number } = Series.Values
		const Points: { Vector2 } = (table.create(Count)::any)
		for Axis = 1, Count do
			const Value = Values[Axis] or 0
			Points[Axis] = Center + Directions[Axis] * (Radius * math.clamp(Value / Max, 0, 1))
		end

		const Fill = if Series.Fill ~= nil then Series.Fill else Graph.Fill
		if Fill then
			Draw.Polygon(PixelBuffer, Width, Height, Points, Color, Series.FillTransparency or Graph.FillTransparency or 0.7)
		end

		const Outline = table.clone(Points)
		table.insert(Outline, Points[1])
		Draw.Stroke(PixelBuffer, Width, Height, Outline, Series.Thickness or Graph.PixelScale or 2, Color)

		const Markers = Series.Markers or Graph.Markers
		if Markers and (Markers.Size or 0) > 0 then
			for _, Point in Points do
				Draw.Stroke(PixelBuffer, Width, Height, { Point, Point }, Markers.Size, Markers.Color or Color)
			end
		end
	end

	self._Canvas:Flush()

	if ShowLabels then
		const Items: { Types.LabelItem } = {}
		for Axis = 1, Count do
			const Direction = Directions[Axis]
			const Spec: Types.ResolvedLabel? = Labels:Resolve({ Index = Axis, Label = Axes[Axis] }, { Index = Axis, Direction = Direction })
			if Spec then
				local Position = (Center + Direction * (Radius + Spec.Offset)) * Scale
				local Anchor = Vector2.new(0.5 - Direction.X * 0.5, 0.5 - Direction.Y * 0.5)
				if Spec.Position then Position = Spec.Position end
				if Spec.Anchor then Anchor = Spec.Anchor end
				if Spec.Nudge then Position += Spec.Nudge end
				table.insert(Items, { Position = Position, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
			end
		end
		Labels:Set(Items)
	elseif Labels then
		Labels:Clear()
	end
end

return RadarRenderer
