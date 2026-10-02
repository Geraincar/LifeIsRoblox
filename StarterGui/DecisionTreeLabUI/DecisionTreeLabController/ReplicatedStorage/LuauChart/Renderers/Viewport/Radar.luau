--!strict
--!native
--!optimize 2
-- Radar (Class): viewport radar renderer. Rings and spokes as thin parts, one viewport per series for its
-- fill (a triangle fan, blended through the viewport's transparency), outlines and markers as parts. Holders
-- stay in the tree, parts are pooled per holder and every line goes through Strokes.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const CreateTris = require(Internal.CreateTris)
const PieMath = require(Internal.PieMath)
const Stacking = require(Internal.Stacking)
const PartPool = require(Internal.PartPool)
const Strokes = require(script.Parent.Strokes)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const TAU = math.pi * 2

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	_Holders: { any },
	_HolderCount: number,
	_MarkerTemplate: Part,
	_Pool: typeof(PartPool.new()),
	_Colors: Strokes.Colors,
}

local RadarRenderer = {}
RadarRenderer.__index = RadarRenderer

export type RadarRenderer = typeof(setmetatable({} :: Fields, RadarRenderer))

-- ─── Internal ────────────────────────────────────────────────────────────────

-- World direction (Y up) for a screen angle
const function WorldDir(Angle: number): Vector3
	return Vector3.new(math.sin(Angle), math.cos(Angle), 0)
end

-- The points as a closed loop, for rings and outlines
const function Loop(Points: { Vector3 }): { Vector3 }
	const Closed = table.clone(Points)
	table.insert(Closed, Points[1])
	return Closed
end

-- ─── Construction ────────────────────────────────────────────────────────────

function RadarRenderer.new(Graph: any): RadarRenderer
	const self = setmetatable({} :: Fields, RadarRenderer)
	self.Graph = Graph
	self.WorldHeight = 100
	self.Thickness = 4 -- Z depth of the fill geometry
	self._Holders = {}
	self._HolderCount = 0
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

	return self
end

-- ─── Holders ─────────────────────────────────────────────────────────────────

-- The next viewport holder in tree order, with its part model. Holders keep their parent and their pooled
-- parts between updates, so a series draws with the same parts every frame
function RadarRenderer._GetHolder(self: RadarRenderer): (any, any)
	const Position = self._HolderCount + 1
	self._HolderCount = Position
	local Holder: any = self._Holders[Position]
	if not Holder then
		Holder = Assets.Slice:Clone()
		Holder.CurrentCamera = self.Graph._Camera
		Holder.Parent = self.Graph.UI.Plot
		self._Holders[Position] = Holder
	end
	Holder.Visible = true
	Holder.ImageColor3 = WHITE
	Holder.ImageTransparency = 0
	Holder.ZIndex = Assets.Slice.ZIndex
	return Holder, Holder:FindFirstChild("Model")
end

-- Starts an update: every holder becomes available again
function RadarRenderer._Reset(self: RadarRenderer)
	self._HolderCount = 0
end

-- Ends an update: holders that went unused are hidden in place
function RadarRenderer._Trim(self: RadarRenderer)
	for Position = self._HolderCount + 1, #self._Holders do
		self._Holders[Position].Visible = false
	end
end

function RadarRenderer.Destroy(self: RadarRenderer)
	self._Pool:Destroy()
	for _, Holder in self._Holders do
		Holder:Destroy()
	end
	table.clear(self._Holders)
	self._HolderCount = 0
	self._MarkerTemplate:Destroy()
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function RadarRenderer.Update(self: RadarRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Pool = self._Pool
	const Colors = self._Colors

	self:_Reset()
	Pool:Begin()

	const Axes: { string } = Graph.Axes or {}
	const SeriesList: { any } = Graph.Series or {}
	const Count = #Axes
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	if Count < 3 or AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		self:_Trim()
		Pool:Finish()
		if Labels then
			Labels:Clear()
		end
		return
	end

	const ShowLabels = Labels and Labels.Enabled
	const Reserve: number = if ShowLabels then (Labels.OutsideMargin or 64) else 0
	const RadiusPixels = (math.min(AbsoluteSize.X, AbsoluteSize.Y) / 2 - Reserve) * (1 - (Graph.Padding or 0))
	if RadiusPixels <= 0 then
		self:_Trim()
		Pool:Finish()
		return
	end

	-- The camera maps world units to exactly the pixel radius
	const RadiusWorld = self.WorldHeight / 2
	const PixelsPerWorld = RadiusPixels / RadiusWorld
	const Camera: Camera = Graph._Camera
	Camera.CFrame = CFrame.new(0, 0, ((AbsoluteSize.Y / 2) / PixelsPerWorld) / math.tan(math.rad(Camera.FieldOfView / 2)))
	const WorldPerPixel = 1 / PixelsPerWorld

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
	const Directions: { Vector3 } = (table.create(Count)::any)
	for Axis = 1, Count do
		Directions[Axis] = WorldDir(Start + (Axis - 1) * Step)
	end

	-- Rings and spokes in one faint holder
	const GridHolder, GridModel = self:_GetHolder()
	GridHolder.ImageTransparency = Graph.GridTransparency or 0.6
	const GridColor: Color3 = Graph.GridColor or WHITE
	const Rings: number = Graph.Rings or 4
	for Ring = 1, Rings do
		const RingRadius = RadiusWorld * Ring / Rings
		const RingPoints: { Vector3 } = (table.create(Count)::any)
		for Axis = 1, Count do
			RingPoints[Axis] = Directions[Axis] * RingRadius
		end
		Strokes.Polyline(Pool, Colors, GridModel, Loop(RingPoints), WorldPerPixel, GridColor, WorldPerPixel)
	end
	for Axis = 1, Count do
		Strokes.Polyline(Pool, Colors, GridModel, { Vector3.zero, Directions[Axis] * RadiusWorld }, WorldPerPixel, GridColor, WorldPerPixel)
	end

	for Rank, SeriesIndex in Stacking.Order(SeriesList) do
		const Series = SeriesList[SeriesIndex]
		const Color: Color3 = Series.Color or WHITE
		const Values: { number } = Series.Values
		const Depth = Rank * 0.2
		const Points: { Vector3 } = (table.create(Count)::any)
		for Axis = 1, Count do
			const Value = Values[Axis] or 0
			Points[Axis] = Directions[Axis] * (RadiusWorld * math.clamp(Value / Max, 0, 1)) + Vector3.new(0, 0, Depth)
		end

		const Fill = if Series.Fill ~= nil then Series.Fill else Graph.Fill
		if Fill then
			const FillHolder, FillModel = self:_GetHolder()
			FillHolder.ImageTransparency = Series.FillTransparency or Graph.FillTransparency or 0.7
			FillHolder.ZIndex = Assets.Slice.ZIndex + 1
			const Center = Vector3.new(0, 0, Depth)
			for Axis = 1, Count do
				const Next = if Axis == Count then 1 else Axis + 1
				const WedgeA: any = Pool:Get(FillModel, "Wedges", Assets.Filler)
				const WedgeB: any = Pool:Get(FillModel, "Wedges", Assets.Filler)
				Strokes.SetColor(Colors, WedgeA, Color)
				Strokes.SetColor(Colors, WedgeB, Color)
				CreateTris(WedgeA, WedgeB, Center, Points[Axis], Points[Next], self.Thickness)
			end
		end

		const LineHolder, LineModel = self:_GetHolder()
		LineHolder.ZIndex = Assets.Slice.ZIndex + 2
		const Thickness = (Series.Thickness or Graph.PixelScale or 2) * WorldPerPixel
		Strokes.Polyline(Pool, Colors, LineModel, Loop(Points), Thickness, Color, WorldPerPixel)

		const Markers = Series.Markers or Graph.Markers
		if Markers and (Markers.Size or 0) > 0 then
			for _, Point in Points do
				const Marker: any = Pool:Get(LineModel, "Markers", self._MarkerTemplate)
				Marker.Size = Vector3.one * Markers.Size * WorldPerPixel
				Strokes.SetColor(Colors, Marker, Markers.Color or Color)
				Marker.Position = Point + Vector3.new(0, 0, Thickness)
			end
		end
	end

	self:_Trim()
	Pool:Finish()

	if ShowLabels then
		const Center = AbsoluteSize / 2
		const Items: { Types.LabelItem } = {}
		for Axis = 1, Count do
			const Screen = PieMath.Dir(Start + (Axis - 1) * Step)
			const Spec: Types.ResolvedLabel? = Labels:Resolve({ Index = Axis, Label = Axes[Axis] }, { Index = Axis, Direction = Screen })
			if Spec then
				local Position = Center + Screen * (RadiusPixels + Spec.Offset)
				local Anchor = Vector2.new(0.5 - Screen.X * 0.5, 0.5 - Screen.Y * 0.5)
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
