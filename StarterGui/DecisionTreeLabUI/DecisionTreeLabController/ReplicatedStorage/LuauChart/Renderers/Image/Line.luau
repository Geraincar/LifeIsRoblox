--!strict
--!native
--!optimize 2
-- Line (Class): image line renderer, drawing into EditableImages. Series without a Color are drawn white
-- and tinted by the layer's UIGradient (see Graph.GradientMode); series with a Color go to gradient-free
-- layers so the color shows as is. Fills carry their own alpha, so overlapping series blend. Every sample is
-- drawn: an antialiased raster shows sub-pixel simplification as a wobble, so Graph.Simplify does not apply.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Internal = Root.Parent.Parent.Internal
const Sampling = require(Internal.Sampling)
const Stacking = require(Internal.Stacking)

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	RenderPoints: { Sampling.Point }?,
	RenderPointsBySeries: { { Sampling.Point } },
	_Canvases: { [string]: Canvas.Canvas },
}

local LineRenderer = {}
LineRenderer.__index = LineRenderer

export type LineRenderer = typeof(setmetatable({} :: Fields, LineRenderer))

-- ─── Internal ────────────────────────────────────────────────────────────────

const function ColoredLayer(UI: any, SourceName: string, Name: string): ImageLabel
	const Existing = UI:FindFirstChild(Name)
	if Existing then
		return Existing
	end
	const Layer = UI[SourceName]:Clone()
	Layer.Name = Name
	const Gradient = Layer:FindFirstChild("Gradient")
	if Gradient then
		Gradient:Destroy()
	end
	Layer.Parent = UI
	return Layer
end

-- ─── Construction ────────────────────────────────────────────────────────────

function LineRenderer.new(Graph: any): LineRenderer
	const self = setmetatable({} :: Fields, LineRenderer)
	self.Graph = Graph

	-- The points actually drawn (spline samples for curves, stacked tops on stacked charts), gaps included;
	-- read by the Cursor feature
	self.RenderPoints = nil
	self.RenderPointsBySeries = {}

	const UI = Graph.UI
	self._Canvases = {
		Nodes = Canvas.new(UI.Nodes),
		Fillers = Canvas.new(UI.Fillers),
		Envelopes = Canvas.new(UI.Envelopes),
		NodesColored = Canvas.new(ColoredLayer(UI, "Nodes", "NodesColored")),
		FillersColored = Canvas.new(ColoredLayer(UI, "Fillers", "FillersColored")),
	}

	-- Fills blend inside the image through their own alpha, so the fill layers themselves stay opaque
	UI.Fillers.ImageTransparency = 0
	UI.FillersColored.ImageTransparency = 0

	return self
end

function LineRenderer.Destroy(self: LineRenderer)
	for _, Layer in self._Canvases do
		Layer:Destroy()
	end
	self.RenderPoints = nil
	self.RenderPointsBySeries = {}
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function LineRenderer.Update(self: LineRenderer)
	const Graph = self.Graph

	-- Prepare clears every layer, so stale drawings never survive an update
	const Images: { [string]: EditableImage } = {}
	for Name, Layer in self._Canvases do
		const Image = Layer:Prepare()
		if not Image then
			return -- not laid out yet (BaseGraph re-renders on resize), or images unavailable
		end
		Images[Name] = Image
	end

	self.RenderPoints = nil
	self.RenderPointsBySeries = {}

	const SeriesList: { any } = Graph.Series or {}
	if #SeriesList == 0 then
		return
	end

	const Size = Images.Nodes.Size
	const Width, Height = Size.X, Size.Y
	const ToPixel, UnitScale = Draw.PixelProjector(Graph:GetVisibleBounds(), Size)
	const Canvases = self._Canvases

	-- Stacked charts draw every series from the shared grid with the chart's Style, so shared edges line up
	const Mode: string = Graph.Stacking or "None"
	const Stacked = if Mode ~= "None" then Stacking.Resolve(SeriesList, Mode) else nil
	const RenderBySeries: { { Sampling.Point } } = {}
	for SeriesIndex, Series in SeriesList do
		const Points: { Sampling.Point } = if Stacked then Stacked.Tops[SeriesIndex] else Series.Points
		const Style = if Stacked then Graph.Style else (Series.Style or Graph.Style)
		RenderBySeries[SeriesIndex] = if #Points > 0 then Sampling.Resolve(Points, Style, Graph.StepsPerSegment) else {}
	end
	const BaseRender = if Stacked then Sampling.Resolve(Stacked.Base, Graph.Style, Graph.StepsPerSegment) else nil
	self.RenderPointsBySeries = RenderBySeries
	self.RenderPoints = RenderBySeries[1]

	-- Per-column pixel Y of a render polyline, the floor a stacked fill drops to
	const function ProfileOf(RenderPoints: { Sampling.Point }): { number }
		const Pixels: { Vector2 } = {}
		for _, Point in RenderPoints do
			const Value = Point.Value
			if Value ~= nil then
				table.insert(Pixels, ToPixel(Point.Index, Value))
			end
		end
		return (Draw.ColumnProfile(Pixels, Width))
	end

	for _, SeriesIndex in Stacking.Order(SeriesList) do
		const Series = SeriesList[SeriesIndex]
		const RenderPoints = RenderBySeries[SeriesIndex]
		if #RenderPoints == 0 then
			continue
		end

		const Colored = Series.Color ~= nil
		const Color: Color3 = Series.Color or WHITE
		const Thickness: number = Series.Thickness or Graph.PixelScale or 1
		const Fill: boolean = if Series.Fill ~= nil then Series.Fill else Graph.Fill
		const FillTransparency: number = Series.FillTransparency or Graph.FillTransparency or 0.5
		const Dash: { number }? = Series.Dash or Graph.Dash
		const Markers = Series.Markers or Graph.Markers
		const Stroke = Series.Stroke ~= false
		const Range = Series.Range == true

		const NodesCanvas = if Colored then Canvases.NodesColored else Canvases.Nodes
		const FillImage = if Colored then Images.FillersColored else Images.Fillers
		const NodeBuffer = NodesCanvas:Buffer()

		-- The fill runs down to the chart floor, or to the top of the series below on stacked charts
		local Floor: number | { number } = Height
		if Fill and Stacked then
			Floor = ProfileOf(if SeriesIndex == 1 then BaseRender :: { Sampling.Point } else RenderBySeries[SeriesIndex - 1])
		end

		-- Each run between gaps is its own polyline
		for _, Run in Sampling.Runs(RenderPoints) do
			if #Run < 2 then
				continue
			end

			const Pixels: { Vector2 } = (table.create(#Run)::any)
			const Envelopes: { number } = (table.create(#Run)::any)
			local HasEnvelope = false
			for Index, Point in Run do
				Pixels[Index] = ToPixel(Point.Index, Point.Value or 0)
				const Envelope = Point.Envelope or 0
				Envelopes[Index] = Envelope * UnitScale.Y
				if Envelope ~= 0 then
					HasEnvelope = true
				end
			end

			-- The fill and the envelope band are drawn per pixel column with rectangles
			if Fill or HasEnvelope then
				const ColumnY, ColumnExtra = Draw.ColumnProfile(Pixels, Width, if HasEnvelope then Envelopes else nil)
				if Fill and not Range then
					Draw.FillColumns(FillImage, ColumnY, Width, Floor, Color, FillTransparency)
				end
				if HasEnvelope and ColumnExtra then
					Draw.BandColumns(Images.Envelopes, ColumnY, ColumnExtra, Width, Color)
				end
			end

			-- The line itself is rasterized with antialiasing; a dash pattern splits it into pieces first
			if Stroke and Dash then
				for _, Piece in Sampling.Dash(Pixels, Dash, 1) do
					Draw.Stroke(NodeBuffer, Width, Height, Piece, Thickness, Color)
				end
			elseif Stroke then
				Draw.Stroke(NodeBuffer, Width, Height, Pixels, Thickness, Color)
			end
		end

		-- A range series fills between its Low and High edges instead of down to the floor, whether or not
		-- it also asks for a fill
		if Range then
			const EdgeStyle = if Stacked then Graph.Style else (Series.Style or Graph.Style)
			const LowProfile = ProfileOf(Sampling.Resolve(Sampling.Edge(Series.Points, "Low"), EdgeStyle, Graph.StepsPerSegment))
			for _, Run in Sampling.Runs(Sampling.Resolve(Sampling.Edge(Series.Points, "High"), EdgeStyle, Graph.StepsPerSegment)) do
				if #Run >= 2 then
					const Pixels: { Vector2 } = (table.create(#Run)::any)
					for Position, Point in Run do
						Pixels[Position] = ToPixel(Point.Index, Point.Value or 0)
					end
					Draw.FillColumns(FillImage, (Draw.ColumnProfile(Pixels, Width)), Width, LowProfile, Color, FillTransparency)
				end
			end
		end

		-- Markers sit at the raw data points (on the stacked top on stacked charts); a zero-length stroke is
		-- a dot, and gaps have none
		if Markers then
			const MarkerColor: Color3 = Markers.Color or Color
			const ColoredBuffer = Canvases.NodesColored:Buffer()
			const Heights: { [number]: number } = {}
			if Stacked then
				for _, Point in Stacked.Tops[SeriesIndex] do
					Heights[Point.Index] = Point.Value or 0
				end
			end
			-- Dense series thin their markers by pixel spacing and count before drawing
			const MarkerPoints = Sampling.Thin(Series.Points, function(Index: number, Value: number)
				return ToPixel(Index, Heights[Index] or Value)
			end, Markers.Spacing, Markers.Limit)
			for _, Point in MarkerPoints do
				-- Bubble charts size and color each marker on its own
				const Diameter: number = Point.Size or Markers.Size or 0
				const Value = Point.Value
				if Value ~= nil and Diameter > 0 then
					const Pixel = ToPixel(Point.Index, Heights[Point.Index] or Value)
					const Target = if Colored or Markers.Color or Point.Color then ColoredBuffer else NodeBuffer
					Draw.Stroke(Target, Width, Height, { Pixel, Pixel }, Diameter, Point.Color or MarkerColor)
				end
			end
		end
	end

	Canvases.Nodes:Flush()
	Canvases.NodesColored:Flush()
end

return LineRenderer
