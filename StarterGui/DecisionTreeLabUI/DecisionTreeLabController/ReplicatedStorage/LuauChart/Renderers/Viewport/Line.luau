--!strict
--!native
--!optimize 2
-- Line (Class): viewport line renderer, drawing parts inside ViewportFrames. Every filled series gets a
-- viewport of its own with the series' fill transparency, so overlapping fills blend. Samples the screen
-- cannot tell apart are dropped before any part is placed, and the line itself goes through Strokes.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const Mapper = require(Internal.Mapper)
const Sampling = require(Internal.Sampling)
const Stacking = require(Internal.Stacking)
const PartPool = require(Internal.PartPool)
const Strokes = require(script.Parent.Strokes)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const DEPTH_STEP = 0.05 -- world units between series, so draw order holds inside a shared viewport

-- ─── Types ───────────────────────────────────────────────────────────────────

type RunStyle = {
	Color: Color3,
	Thickness: number,
	Fill: boolean,
	Dash: { number }?,
	Depth: number,
	Stroke: boolean,
	Range: boolean,
}

type FillLayer = { Frame: any, Tinted: boolean }

type Fields = {
	Graph: any,
	WorldHeight: number,
	RenderPoints: { Sampling.Point }?,
	RenderPointsBySeries: { { Sampling.Point } },
	_Pool: typeof(PartPool.new()),
	_Colors: Strokes.Colors,
	_MarkerTemplate: Part,
	_Layers: { [string]: any },
	_FillTemplates: { Tinted: any, Colored: any },
	_FillLayers: { [number]: FillLayer },
	_FillOrder: string,
}

local LineRenderer = {}
LineRenderer.__index = LineRenderer

export type LineRenderer = typeof(setmetatable({} :: Fields, LineRenderer))

-- ─── Internal ────────────────────────────────────────────────────────────────

-- Series that bring their own color draw on gradient-free copies of the gradient layers
const function ColoredLayer(UI: any, SourceName: string, Name: string): any
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
	Layer.Model:ClearAllChildren()
	Layer.Parent = UI
	return Layer
end

-- ─── Construction ────────────────────────────────────────────────────────────

function LineRenderer.new(Graph: any): LineRenderer
	const self = setmetatable({} :: Fields, LineRenderer)
	self.Graph = Graph
	self.WorldHeight = 100

	-- The points actually drawn (spline samples for curves, stacked tops on stacked charts), gaps included;
	-- read by the Cursor feature
	self.RenderPoints = nil
	self.RenderPointsBySeries = {}

	self._Pool = PartPool.new()
	self._Colors = Strokes.Colors()

	const Marker = Instance.new("Part")
	Marker.Shape = Enum.PartType.Ball
	Marker.Material = Enum.Material.SmoothPlastic
	Marker.Anchored = true
	Marker.CanCollide = false
	Marker.CanQuery = false
	Marker.CastShadow = false
	Marker.Size = Vector3.one
	self._MarkerTemplate = Marker

	const UI = Graph.UI
	self._Layers = {
		Nodes = UI.Nodes,
		Envelopes = UI.Envelopes,
		NodesColored = ColoredLayer(UI, "Nodes", "NodesColored"),
	}

	-- The fill layers only serve as templates for one viewport per filled series
	self._FillTemplates = {
		Tinted = UI.Fillers,
		Colored = ColoredLayer(UI, "Fillers", "FillersColored"),
	}
	self._FillTemplates.Tinted.Visible = false
	self._FillTemplates.Colored.Visible = false
	self._FillLayers = {} -- [SeriesIndex] = { Frame, Tinted }
	self._FillOrder = ""

	return self
end

-- ─── Pooling ─────────────────────────────────────────────────────────────────

function LineRenderer._Get(self: LineRenderer, Type: string, Template: Instance, Parent: Instance): any
	return self._Pool:Get(Parent, Type, Template)
end

function LineRenderer.Destroy(self: LineRenderer)
	self._Pool:Destroy()
	for _, Entry in self._FillLayers do
		self.Graph.Colors[Entry.Frame.Name] = nil
		Entry.Frame:Destroy()
	end
	table.clear(self._FillLayers)
	self._MarkerTemplate:Destroy()
	self.RenderPoints = nil
	self.RenderPointsBySeries = {}
end

-- One viewport per filled series, cloned from the tinted or the colored fill template
function LineRenderer._FillLayer(self: LineRenderer, SeriesIndex: number, Tinted: boolean): any
	const Graph = self.Graph
	local Entry: FillLayer? = self._FillLayers[SeriesIndex]
	if Entry and Entry.Tinted ~= Tinted then
		Graph.Colors[Entry.Frame.Name] = nil
		self._Pool:Forget(Entry.Frame.Model)
		Entry.Frame:Destroy()
		Entry = nil
	end
	if not Entry then
		const Source = if Tinted then self._FillTemplates.Tinted else self._FillTemplates.Colored
		const Frame = Source:Clone()
		Frame.Name = `Fill{SeriesIndex}`
		Frame.Visible = true
		Frame.CurrentCamera = Graph._Camera
		Frame.Model:ClearAllChildren()
		Frame.Parent = Graph.UI
		-- Registered so GradientMode keeps updating this copy of the gradient
		if Tinted and Graph.Colors.Fillers then
			Graph.Colors[Frame.Name] = Graph.Colors.Fillers
		end
		const Created: FillLayer = { Frame = Frame, Tinted = Tinted }
		self._FillLayers[SeriesIndex] = Created
		self._FillOrder = ""
		Entry = Created
	end
	return (Entry :: FillLayer).Frame
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function LineRenderer._SetupCamera(self: LineRenderer)
	const Camera: Camera = self.Graph._Camera

	-- The distance that fits WorldHeight into the camera's tiny field of view
	const Distance = (self.WorldHeight / 2) / math.tan(math.rad(Camera.FieldOfView / 2))
	Camera.CFrame = CFrame.new(0, 0, Distance)

	for _, Layer in self._Layers do
		if Layer.CurrentCamera ~= Camera then
			Layer.CurrentCamera = Camera
		end
	end
end

-- A right-triangle wedge between a segment and the horizontal through its lower end. Flipped, the sloped
-- face is on the bottom and the horizontal runs through the upper end, which is the shape above a base
-- segment.
function LineRenderer._DrawWedge(self: LineRenderer, Parent: Instance, Start: Vector3, Finish: Vector3, Width: number, Color: Color3, Thickness: number, Depth: number, Flip: boolean)
	const Height = math.abs(Finish.Y - Start.Y)
	if Height < 1e-4 then
		return
	end
	const Wedge = self:_Get("Wedges", Assets.Filler, Parent)
	Strokes.SetColor(self._Colors, Wedge, Color)
	Wedge.Size = Vector3.new(Thickness, Width, Height)

	-- The orientation (YXZ order) picks which way the wedge slopes; a flipped wedge is the mirror of a
	-- segment sloping the other way
	const Rising = Finish.Y > Start.Y
	const Yaw = if Rising ~= Flip then -90 else 90
	local Frame = CFrame.new((Start.X + Finish.X) / 2, (Start.Y + Finish.Y) / 2, Depth)
	if Flip then
		Frame = Frame * CFrame.Angles(math.pi, 0, 0)
	end
	Wedge.CFrame = Frame * CFrame.fromOrientation(math.rad(90), math.rad(Yaw), 0)
end

-- The area between a top segment and a base segment as three axis-aligned parts: a wedge under the top, a
-- cube through the middle and a wedge above the base. Axis-aligned parts tile without seams, which
-- rotated triangles do not.
function LineRenderer._DrawBand(self: LineRenderer, Parent: Instance, TopStart: Vector3, TopFinish: Vector3, BaseStart: Vector3, BaseFinish: Vector3, Color: Color3, Thickness: number, Depth: number)
	const Width = math.abs(TopFinish.X - TopStart.X)
	const TopLow = math.min(TopStart.Y, TopFinish.Y)
	const BaseHigh = math.max(BaseStart.Y, BaseFinish.Y)
	if Width < 1e-4 or math.max(TopStart.Y, TopFinish.Y) <= math.min(BaseStart.Y, BaseFinish.Y) then
		return
	end

	self:_DrawWedge(Parent, TopStart, TopFinish, Width, Color, Thickness, Depth, false)
	self:_DrawWedge(Parent, BaseStart, BaseFinish, Width, Color, Thickness, Depth, true)

	const CubeHeight = TopLow - BaseHigh
	if CubeHeight > 0 then
		const Cube = self:_Get("Cubes", Assets.FillerCube, Parent)
		Strokes.SetColor(self._Colors, Cube, Color)
		Cube.Size = Vector3.new(Width, CubeHeight, Thickness)
		Cube.Position = Vector3.new((TopStart.X + TopFinish.X) / 2, BaseHigh + CubeHeight / 2, Depth)
	end
end

-- One unbroken run of points of a series. Below is the world polyline the fill drops to on stacked charts,
-- sampled on the same grid as Run; without it the fill drops to the chart floor. Tolerance is the pixel
-- distance the drawn polylines may sit from the samples.
function LineRenderer._DrawRun(self: LineRenderer, Run: { Sampling.Point }, Style: RunStyle, Projector: any, WorldPerPixel: number, Tolerance: number, FloorY: number, Models: { [string]: any }, Below: { Vector3 }?)
	const Color, Thickness, Depth = Style.Color, Style.Thickness, Style.Depth
	const Lift = Vector3.new(0, 0, Depth)
	const Count = #Run

	-- World positions and envelope half-heights on the run's sample grid
	local World: { Vector3 } = (table.create(Count)::any)
	local Envelopes: { number } = (table.create(Count)::any)
	local HasEnvelope = false
	for Index, Point in Run do
		World[Index] = Projector.ToWorld(Point.Index, Point.Value or 0) + Lift
		const Envelope = (Point.Envelope or 0) * Projector.UnitScale.Y
		Envelopes[Index] = Envelope
		if Envelope ~= 0 then
			HasEnvelope = true
		end
	end
	local Floor: { Vector3 }? = nil
	if Below and #Below == Count then
		Floor = Below
	end

	-- Samples that only pad a straight stretch are dropped. A sample stays when the line, the envelope edge or
	-- the stacked floor bends there, so all three polylines keep the same grid.
	const Keep: { boolean } = table.create(Count, false)
	local Kept = 0
	const function Mark(Indices: { number })
		for _, Index in Indices do
			if not Keep[Index] then
				Keep[Index] = true
				Kept += 1
			end
		end
	end
	Mark(Strokes.SimplifyIndices(World, WorldPerPixel, Tolerance))
	if HasEnvelope then
		const Upper: { Vector3 } = (table.create(Count)::any)
		for Index, Position in World do
			Upper[Index] = Position + Vector3.new(0, Envelopes[Index], 0)
		end
		Mark(Strokes.SimplifyIndices(Upper, WorldPerPixel, Tolerance))
	end
	if Floor then
		Mark(Strokes.SimplifyIndices(Floor, WorldPerPixel, Tolerance))
	end
	if Kept < Count then
		const KeptWorld: { Vector3 } = (table.create(Kept)::any)
		const KeptEnvelopes: { number } = (table.create(Kept)::any)
		const KeptFloor: { Vector3 }? = if Floor then (table.create(Kept)::any) else nil
		local Position = 0
		for Index = 1, Count do
			if Keep[Index] then
				Position += 1
				KeptWorld[Position] = World[Index]
				KeptEnvelopes[Position] = Envelopes[Index]
				if KeptFloor and Floor then
					KeptFloor[Position] = Floor[Index]
				end
			end
		end
		World, Envelopes, Floor = KeptWorld, KeptEnvelopes, KeptFloor
	end

	if Style.Stroke then
		const Dash = Style.Dash
		if Dash then
			Strokes.Dashed(self._Pool, self._Colors, Models.Nodes, World, Thickness, Color, Dash, WorldPerPixel)
		else
			Strokes.Polyline(self._Pool, self._Colors, Models.Nodes, World, Thickness, Color, WorldPerPixel)
		end
	end

	for Index = 1, #World - 1 do
		const Start, Finish = World[Index], World[Index + 1]

		if Style.Fill and Models.Fillers and not Style.Range then
			local BaseStart, BaseFinish
			if Floor then
				BaseStart, BaseFinish = Floor[Index], Floor[Index + 1]
			else
				BaseStart, BaseFinish = Vector3.new(Start.X, FloorY, Depth), Vector3.new(Finish.X, FloorY, Depth)
			end
			self:_DrawBand(Models.Fillers, Start, Finish, BaseStart, BaseFinish, Color, Thickness, Depth)
		end

		-- Envelope: a skinned mesh band around the line
		const HalfStart, HalfEnd = Envelopes[Index], Envelopes[Index + 1]
		if HalfStart ~= 0 or HalfEnd ~= 0 then
			const Band = self:_Get("Envelopes", Assets.Cube, Models.Envelopes)
			Strokes.SetColor(self._Colors, Band, Color)

			Band.TopLeft.WorldPosition = Start + Vector3.new(0, HalfStart, 0)
			Band.BottomLeft.WorldPosition = Start - Vector3.new(0, HalfStart, 0)
			Band.TopRight.WorldPosition = Finish + Vector3.new(0, HalfEnd, 0)
			Band.BottomRight.WorldPosition = Finish - Vector3.new(0, HalfEnd, 0)
		end
	end
end

function LineRenderer.Update(self: LineRenderer)
	const Graph = self.Graph
	const Pool = self._Pool

	Pool:Begin()
	self.RenderPoints = nil
	self.RenderPointsBySeries = {}

	const SeriesList: { any } = Graph.Series or {}
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	-- Not laid out yet: BaseGraph re-renders on resize
	if #SeriesList == 0 or AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		Pool:Finish()
		for _, Entry in self._FillLayers do
			Entry.Frame.Visible = false
		end
		return
	end

	self:_SetupCamera()

	const Visible = Graph:GetVisibleBounds()
	const Projector = Mapper.GetWorldProjector(AbsoluteSize, Visible, self.WorldHeight)
	const WorldPerPixel = self.WorldHeight / AbsoluteSize.Y
	const Tolerance: number = Graph:GetSimplify()
	const FloorY = -self.WorldHeight / 2
	const Layers = self._Layers

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

	const Order = Stacking.Order(SeriesList)
	const Used: { [number]: boolean } = {}

	for Rank, SeriesIndex in Order do
		const Series = SeriesList[SeriesIndex]
		const RenderPoints = RenderBySeries[SeriesIndex]
		if #RenderPoints == 0 then
			continue
		end

		const Colored = Series.Color ~= nil
		const Style: RunStyle = {
			Color = Series.Color or WHITE,
			Thickness = (Series.Thickness or Graph.PixelScale or 1) * WorldPerPixel,
			Fill = if Series.Fill ~= nil then Series.Fill else Graph.Fill,
			Dash = Series.Dash or Graph.Dash,
			Depth = Rank * DEPTH_STEP,
			Stroke = Series.Stroke ~= false,
			Range = Series.Range == true,
		}

		-- Range bands draw into the fill layer too
		local FillModel: any = nil
		if Style.Fill or Style.Range then
			const Frame = self:_FillLayer(SeriesIndex, not Colored)
			Frame.ImageTransparency = Series.FillTransparency or Graph.FillTransparency or 0.5
			Frame.Visible = true
			Used[SeriesIndex] = true
			FillModel = Frame.Model
		end
		const Models: { [string]: any } = {
			Nodes = (if Colored then Layers.NodesColored else Layers.Nodes).Model,
			Fillers = FillModel,
			Envelopes = Layers.Envelopes.Model,
		}

		-- On stacked charts the fill drops to the top of the series below, in world space
		local Below: { Vector3 }? = nil
		if Stacked and Style.Fill then
			const BelowPoints: { Sampling.Point } = if SeriesIndex == 1 then BaseRender :: { Sampling.Point } else RenderBySeries[SeriesIndex - 1]
			const Positions: { Vector3 } = (table.create(#BelowPoints)::any)
			for Position, Point in BelowPoints do
				Positions[Position] = Projector.ToWorld(Point.Index, Point.Value or 0) + Vector3.new(0, 0, Style.Depth)
			end
			Below = Positions
		end

		-- Each run between gaps is its own polyline
		for _, Run in Sampling.Runs(RenderPoints) do
			if #Run >= 2 then
				self:_DrawRun(Run, Style, Projector, WorldPerPixel, Tolerance, FloorY, Models, Below)
			end
		end

		-- A range series fills between its Low and High edges instead of down to the floor
		if Style.Range and FillModel then
			const EdgeStyle = if Stacked then Graph.Style else (Series.Style or Graph.Style)
			const HighRender = Sampling.Resolve(Sampling.Edge(Series.Points, "High"), EdgeStyle, Graph.StepsPerSegment)
			const LowRender = Sampling.Resolve(Sampling.Edge(Series.Points, "Low"), EdgeStyle, Graph.StepsPerSegment)
			const Lift = Vector3.new(0, 0, Style.Depth)
			if #HighRender == #LowRender then
				for Position = 1, #HighRender - 1 do
					const HighA, HighB = HighRender[Position], HighRender[Position + 1]
					const LowA, LowB = LowRender[Position], LowRender[Position + 1]
					const HighAValue, HighBValue, LowAValue, LowBValue = HighA.Value, HighB.Value, LowA.Value, LowB.Value
					if HighAValue and HighBValue and LowAValue and LowBValue then
						self:_DrawBand(FillModel,
							Projector.ToWorld(HighA.Index, HighAValue) + Lift, Projector.ToWorld(HighB.Index, HighBValue) + Lift,
							Projector.ToWorld(LowA.Index, LowAValue) + Lift, Projector.ToWorld(LowB.Index, LowBValue) + Lift,
							Style.Color, Style.Thickness, Style.Depth)
					end
				end
			end
		end

		-- Markers sit at the raw data points (on the stacked top on stacked charts); gaps have none
		const Markers = Series.Markers or Graph.Markers
		if Markers then
			const MarkerColor: Color3 = Markers.Color or Style.Color
			const Heights: { [number]: number } = {}
			if Stacked then
				for _, Point in Stacked.Tops[SeriesIndex] do
					Heights[Point.Index] = Point.Value or 0
				end
			end
			-- Dense series thin their markers by pixel spacing and count before drawing
			const MarkerPoints = Sampling.Thin(Series.Points, function(Index: number, Value: number)
				const World: Vector3 = Projector.ToWorld(Index, Heights[Index] or Value)
				return Vector2.new(World.X / WorldPerPixel, World.Y / WorldPerPixel)
			end, Markers.Spacing, Markers.Limit)
			for _, Point in MarkerPoints do
				-- Bubble charts size and color each marker on its own
				const Diameter: number = Point.Size or Markers.Size or 0
				const Value = Point.Value
				if Value ~= nil and Diameter > 0 then
					const Model = (if Colored or Markers.Color or Point.Color then Layers.NodesColored else Layers.Nodes).Model
					const Marker = self:_Get("Markers", self._MarkerTemplate, Model)
					Marker.Size = Vector3.one * Diameter * WorldPerPixel
					Strokes.SetColor(self._Colors, Marker, Point.Color or MarkerColor)
					Marker.Position = Projector.ToWorld(Point.Index, Heights[Point.Index] or Value) + Vector3.new(0, 0, Style.Depth + Style.Thickness)
				end
			end
		end
	end

	Pool:Finish()
	for SeriesIndex, Entry in self._FillLayers do
		if not Used[SeriesIndex] then
			Entry.Frame.Visible = false
		end
	end

	-- Fill viewports share a ZIndex, so their order in the tree is the draw order
	const OrderKey = table.concat(Order, ",")
	if OrderKey ~= self._FillOrder then
		self._FillOrder = OrderKey
		for _, SeriesIndex in Order do
			const Entry = self._FillLayers[SeriesIndex]
			if Entry then
				Entry.Frame.Parent = nil
				Entry.Frame.Parent = Graph.UI
			end
		end
	end
end

return LineRenderer
