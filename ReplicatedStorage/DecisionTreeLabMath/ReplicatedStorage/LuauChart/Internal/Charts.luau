--!strict
--!native
--!optimize 2
-- Charts (Library): the Line, Bar, Pie, Candle, Box, Heatmap, Treemap and Radar chart classes, built over a
-- set of renderer backends by Charts.Build. Every chart picks a backend when it is created ("Image":
-- EditableImage pixels, "Viewport": parts in ViewportFrames) and the public API is the same for both.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const BaseGraph = require(script.Parent.BaseGraph)
const Cartesian = require(script.Parent.Cartesian)
const Animator = require(script.Parent.Animator)
const Stacking = require(script.Parent.Stacking)
const Sampling = require(script.Parent.Sampling)
const Indicators = require(script.Parent.Indicators)
const Statistics = require(script.Parent.Statistics)
const Link = require(script.Parent.Link)
const Types = require(script.Parent.Parent.Types)
const Format = require(script.Parent.Parent.Format)

const FeaturesFolder = script.Parent.Parent.Features
const Grid = require(FeaturesFolder.Grid)
const Cursor = require(FeaturesFolder.Cursor)
const Selection = require(FeaturesFolder.Selection)
const References = require(FeaturesFolder.References)
const Labels = require(FeaturesFolder.Labels)
const Categories = require(FeaturesFolder.Categories)
const Hover = require(FeaturesFolder.Hover)

local Charts = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Backend = {
	Assets: Folder, -- one UI template per chart type for this renderer
	Line: any,
	Bar: any,
	Pie: any,
	Candle: any,
	Box: any,
	Heatmap: any,
	Treemap: any,
	Radar: any,
}

export type Options = {
	Renderer: string?, -- backend name, defaults to Library.DefaultRenderer
	Preset: GuiObject?, -- custom UI template instead of the backend's asset
}

-- Fields every chart carries (see BaseGraph), then the Cartesian ones (see Cartesian), then its own. Field
-- types are listed flat per class because the type checker needs one plain table type behind a metatable.

export type LineFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	ViewRange: Types.Bounds,
	ProcessedBounds: Types.Bounds,
	PixelScale: number,
	GradientMode: Types.GradientMode,
	AutoFitY: boolean,
	AutoFitPadding: number,
	Colors: { [string]: ColorSequence },
	Grid: Grid.Grid,
	Cursor: Cursor.Cursor,
	Selection: Selection.Selection,
	References: References.References,
	Labels: Labels.Labels,
	Series: { Types.LineSeries },
	Style: Types.LineStyle,
	StepsPerSegment: number,
	Fill: boolean,
	FillTransparency: number,
	Dash: { number }?,
	Markers: Types.Markers?,
	Stacking: Types.LineStacking,
	MaxPoints: number?,
}

export type BarFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	ViewRange: Types.Bounds,
	ProcessedBounds: Types.Bounds,
	PixelScale: number,
	GradientMode: Types.GradientMode,
	AutoFitY: boolean,
	AutoFitPadding: number,
	Colors: { [string]: ColorSequence },
	Grid: Grid.Grid,
	Cursor: Cursor.Cursor,
	Selection: Selection.Selection,
	References: References.References,
	Labels: Labels.Labels,
	Series: { Types.BarSeries },
	Orientation: Types.BarOrientation,
	Mode: Types.BarMode,
	GroupSpacing: number,
	BarRatio: number,
	ZeroFloor: boolean,
	CornerRadius: number,
	NegativeColor: Color3?,
	Headroom: number,
	MaxBars: number?,
	Categories: Categories.Categories,
	Hover: Hover.Hover,
}

export type PieFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	Cutout: number,
	StartAngle: number,
	Clockwise: boolean,
	Rose: boolean,
	Reveal: number,
	CenterText: string?,
	Labels: Labels.Labels,
	Hover: Hover.Hover,
}

export type CandleFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	ViewRange: Types.Bounds,
	ProcessedBounds: Types.Bounds,
	PixelScale: number,
	GradientMode: Types.GradientMode,
	AutoFitY: boolean,
	AutoFitPadding: number,
	Colors: { [string]: ColorSequence },
	Grid: Grid.Grid,
	Cursor: Cursor.Cursor,
	Selection: Selection.Selection,
	References: References.References,
	Labels: Labels.Labels,
	Candles: { Types.Candle },
	Overlays: { Types.LineSeries },
	BodyRatio: number,
	WickThickness: number,
	CornerRadius: number,
	UpColor: Color3,
	DownColor: Color3,
	Headroom: number,
	MaxCandles: number?,
	Hover: Hover.Hover,
}

export type BoxFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	ViewRange: Types.Bounds,
	ProcessedBounds: Types.Bounds,
	PixelScale: number,
	GradientMode: Types.GradientMode,
	AutoFitY: boolean,
	AutoFitPadding: number,
	Colors: { [string]: ColorSequence },
	Grid: Grid.Grid,
	Cursor: Cursor.Cursor,
	Selection: Selection.Selection,
	References: References.References,
	Labels: Labels.Labels,
	Boxes: { Types.BoxEntry },
	BodyRatio: number,
	CapRatio: number,
	WhiskerThickness: number,
	MedianThickness: number,
	OutlierSize: number,
	CornerRadius: number,
	Color: Color3,
	MedianColor: Color3,
	Headroom: number,
	Categories: Categories.Categories,
	Hover: Hover.Hover,
}

export type HeatmapFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	ViewRange: Types.Bounds,
	ProcessedBounds: Types.Bounds,
	PixelScale: number,
	GradientMode: Types.GradientMode,
	AutoFitY: boolean,
	AutoFitPadding: number,
	Colors: { [string]: ColorSequence },
	Grid: Grid.Grid,
	Cursor: Cursor.Cursor,
	Selection: Selection.Selection,
	References: References.References,
	Labels: Labels.Labels,
	Cells: { Types.HeatCell },
	ColorScale: ColorSequence,
	Range: NumberRange?,
	Gap: number,
	CornerRadius: number,
	ColumnLabels: { string }?,
	RowLabels: { string }?,
	Hover: Hover.Hover,
	_DataRange: NumberRange?,
}

export type TreemapFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	Nodes: { Types.TreeNode },
	Gap: number,
	Padding: number,
	HeaderHeight: number,
	CornerRadius: number,
	GroupShade: number,
	Palette: { Color3 },
	MinLabelSize: Vector2,
	Labels: Labels.Labels,
	Hover: Hover.Hover,
}

export type RadarFields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Type: string,
	RendererType: string,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	Axes: { string },
	Series: { Types.RadarSeries },
	Max: number?,
	Rings: number,
	StartAngle: number,
	Padding: number,
	GridColor: Color3,
	GridTransparency: number,
	Fill: boolean,
	FillTransparency: number,
	PixelScale: number,
	Markers: Types.Markers?,
	Labels: Labels.Labels,
}

-- ─── Classes ─────────────────────────────────────────────────────────────────

local Line = setmetatable({}, Cartesian)
Line.__index = Line
export type Line = typeof(setmetatable({} :: LineFields, Line))

local Bar = setmetatable({}, Cartesian)
Bar.__index = Bar
export type Bar = typeof(setmetatable({} :: BarFields, Bar))

-- Inherits BaseGraph only: no grid, cursor or selection
local Pie = setmetatable({}, BaseGraph)
Pie.__index = Pie
export type Pie = typeof(setmetatable({} :: PieFields, Pie))

local Candle = setmetatable({}, Cartesian)
Candle.__index = Candle
export type Candle = typeof(setmetatable({} :: CandleFields, Candle))

local Box = setmetatable({}, Cartesian)
Box.__index = Box
export type Box = typeof(setmetatable({} :: BoxFields, Box))

local Heatmap = setmetatable({}, Cartesian)
Heatmap.__index = Heatmap
export type Heatmap = typeof(setmetatable({} :: HeatmapFields, Heatmap))

-- Inherits BaseGraph only: no axes
local Treemap = setmetatable({}, BaseGraph)
Treemap.__index = Treemap
export type Treemap = typeof(setmetatable({} :: TreemapFields, Treemap))

-- Inherits BaseGraph only: polar, no axes features
local Radar = setmetatable({}, BaseGraph)
Radar.__index = Radar
export type Radar = typeof(setmetatable({} :: RadarFields, Radar))

export type Library = {
	DefaultRenderer: string, -- the renderer charts use unless their Options say otherwise
	Renderers: { string },
	Line: typeof(Line),
	Bar: typeof(Bar),
	Pie: typeof(Pie),
	Candle: typeof(Candle),
	Box: typeof(Box),
	Heatmap: typeof(Heatmap),
	Treemap: typeof(Treemap),
	Radar: typeof(Radar),
	Format: typeof(Format),
	Indicators: typeof(Indicators),
	Statistics: typeof(Statistics),
	Link: typeof(Link),
}

-- ─── State ───────────────────────────────────────────────────────────────────

local Backends: { [string]: Backend } = {}
local Library: Library

-- ─── Internal ────────────────────────────────────────────────────────────────

-- Entries must be sorted by Index. A nil Value is a gap (the line breaks, the bar slot stays empty).
const function AssertSorted(Entries: any, Method: string)
	assert(typeof(Entries) == "table", `{Method}: expected a table of entries`)

	local Last = -math.huge
	for Position, Entry in Entries :: { any } do
		assert(typeof(Entry) == "table" and typeof(Entry.Index) == "number", `{Method}: entry #{Position} needs a numeric Index`)
		assert(Entry.Value == nil or typeof(Entry.Value) == "number", `{Method}: entry #{Position} needs a numeric Value (or nil for a gap)`)
		assert(Entry.Index > Last, `{Method}: entries must be sorted by Index ascending (entry #{Position})`)
		Last = Entry.Index
	end
end

-- Accepts a list of series or a plain list of entries and always returns a list of series.
-- ListKey is the entry list field of a series ("Points" for lines, "Bars" for bars).
const function NormalizeSeries(Input: any, Method: string, ListKey: string): { any }
	assert(typeof(Input) == "table", `{Method}: expected a table`)
	if Input[1] and typeof(Input[1]) == "table" and Input[1][ListKey] then
		for Position, Series in Input :: { any } do
			AssertSorted(Series[ListKey], `{Method} (series #{Position})`)
		end
		return Input
	end
	AssertSorted(Input, Method)
	return { { [ListKey] = Input } }
end

-- Keeps at most Max entries in place, dropping the oldest
const function TrimFront(List: { any }, Max: number?)
	if not Max then
		return
	end
	const Count = #List
	const Excess = Count - Max
	if Excess <= 0 then
		return
	end
	table.move(List, Excess + 1, Count, 1)
	for Position = Count - Excess + 1, Count do
		List[Position] = nil
	end
end

-- Appends an entry to a series list (Index must increase) and trims to Max
const function Append(SeriesList: { any }, ListKey: string, SeriesIndex: number, Entry: any, Max: number?, Method: string)
	local Series = SeriesList[SeriesIndex]
	if not Series then
		Series = { [ListKey] = {} }
		SeriesList[SeriesIndex] = Series
	end

	const List: { any } = Series[ListKey]
	const Last = List[#List]
	assert(typeof(Entry.Index) == "number", `{Method}: entry needs a numeric Index`)
	assert(Entry.Value == nil or typeof(Entry.Value) == "number", `{Method}: entry needs a numeric Value (or nil for a gap)`)
	assert(not Last or Entry.Index > Last.Index, `{Method}: Index must be greater than the last entry's`)

	table.insert(List, Entry)
	TrimFront(List, Max)
end

-- A bare GuiObject is accepted as a preset for backwards compatibility
const function Resolve(Options: any, ChartType: string): (Backend, string, GuiObject)
	const Opts: Options = if typeof(Options) == "Instance" then { Preset = Options :: any } else (Options or {})
	const Name = Opts.Renderer or Library.DefaultRenderer
	const Backend = Backends[Name]
	assert(Backend, `LuauChart: unknown renderer "{tostring(Name)}" (available: {table.concat(Library.Renderers, ", ")})`)
	return Backend, Name, Opts.Preset or ((Backend.Assets :: any)[ChartType] :: GuiObject)
end

-- ─── Line ────────────────────────────────────────────────────────────────────

function Line.new(Options: Options?): Line
	const Backend, RendererName, Preset = Resolve(Options, "Line")
	const self: Line = setmetatable(Cartesian.new(Preset), Line)
	self.Type = "Line"
	self.RendererType = RendererName

	self.Series = {}

	-- Defaults for series that don't set their own
	self.Style = "Line"
	self.StepsPerSegment = 8 -- Curve only: spline samples per segment
	self.Fill = false
	self.FillTransparency = 0.5 -- overlapping fills blend through it
	self.Dash = nil
	self.Markers = nil

	-- "Stacked": each series sits on the one before it. "Stream": stacked and centered, the stream graph
	-- silhouette. Both resample every series on the shared index grid, count gaps as zero, and draw every
	-- series with the chart's Style so the shared edges line up.
	self.Stacking = "None"

	self.MaxPoints = nil -- AddPoint drops the oldest points beyond this

	self.Renderer = Backend.Line.new(self)

	return self
end

function Line._GetData(self: Line): any
	return self.Series
end

function Line._ApplyData(self: Line, SeriesList: { any }, RecomputeBounds: boolean)
	self.Series = SeriesList
	self.Data = if SeriesList[1] then SeriesList[1].Points else {}
	if RecomputeBounds then
		self:_UpdateProcessedBounds()
	end
end

function Line._BlendData(self: Line, From: any, To: any, Alpha: number): any
	return Animator.BlendSeries(From, To, Alpha, "Points")
end

function Line._ZeroData(self: Line, SeriesList: any): any
	return Animator.ZeroSeries(SeriesList, "Points")
end

-- Stacked charts are bounded by their stacked tops and base, not the raw values
function Line._GetBoundsLists(self: Line, Source: any?): { { any } }
	const SeriesList: { any } = Source or self.Series
	if self.Stacking ~= "None" and #SeriesList > 0 then
		const Result = Stacking.Resolve(SeriesList, self.Stacking)
		const Lists: { { any } } = table.clone(Result.Tops)
		table.insert(Lists, Result.Base)
		return Lists
	end

	const Lists: { { any } } = {}
	for _, Series in SeriesList do
		table.insert(Lists, Series.Points)
		-- Range bands bound the axis by their edges
		if Series.Range then
			table.insert(Lists, Sampling.Edge(Series.Points :: any, "Low"))
			table.insert(Lists, Sampling.Edge(Series.Points :: any, "High"))
		end
	end
	return Lists
end

-- Points: a list of points, or a list of series ({ Points = ..., Color = ... })
function Line.SetPoints(self: Line, Points: any, Animate: TweenInfo?)
	self:_SetData(NormalizeSeries(Points, "Line:SetPoints", "Points"), Animate)
end

function Line.SetSeries(self: Line, SeriesList: any, Animate: TweenInfo?)
	self:_SetData(NormalizeSeries(SeriesList, "Line:SetSeries", "Points"), Animate)
end

function Line.AnimateTo(self: Line, Target: any, TweenInfoObject: TweenInfo?)
	BaseGraph.AnimateTo(self, NormalizeSeries(Target, "Line:AnimateTo", "Points"), TweenInfoObject)
end

-- Live data: appends one point and drops the oldest beyond MaxPoints
function Line.AddPoint(self: Line, Point: Types.LinePoint, SeriesIndex: number?)
	Append(self.Series, "Points", SeriesIndex or 1, Point, self.MaxPoints, "Line:AddPoint")

	self._HasData = true
	self.Data = self.Series[1].Points
	self:_UpdateProcessedBounds()
	self:RequestRender()
end

-- ─── Bar ─────────────────────────────────────────────────────────────────────

function Bar.new(Options: Options?): Bar
	const Backend, RendererName, Preset = Resolve(Options, "Bar")
	const self: Bar = setmetatable(Cartesian.new(Preset), Bar)
	self.Type = "Bar"
	self.RendererType = RendererName

	self.Series = {}
	self.Orientation = "Vertical" -- Horizontal: bars grow sideways, slots run down screen Y
	self.Mode = "Grouped" -- how several series share a slot
	self.GroupSpacing = 0.15 -- Grouped: gap between the bars of a group, as a fraction of one bar's width

	self.BarRatio = 0.8 -- fraction of the slot that a bar (or group) fills
	self.ZeroFloor = true -- keeps zero in view; off for floating bars such as timelines
	self.CornerRadius = 0 -- pixels, Image renderer only
	self.NegativeColor = nil -- bars below zero whose bar and series set no Color
	self.Headroom = 0.08 -- fraction of the value range kept free past the tallest bars
	self.MaxBars = nil -- AddBar drops the oldest bars beyond this

	-- Labels.Format(Entry, Info) -> nil | text | LabelSpec. Info: { Index, Value, Series, SeriesData, Negative,
	-- Stacked, Rect, Direction, Orientation }, or { Index, Value, Total, IsTotal = true, ... } for a stack total
	self.Labels.DefaultFormat = function(Entry: any)
		return tostring(math.round(Entry.Value))
	end
	self.Categories = Categories.new(self) -- slot names from the entries' Label field
	self.Hover = Hover.new(self) -- hovered bars lighten; OnChanged and OnClick report them

	self.Renderer = Backend.Bar.new(self)

	-- Bars are discrete, so the cursor snaps to entries and drag-to-zoom stays off unless asked for.
	-- Hovered bars highlight themselves, so no guide line unless Cursor.Show says so (Show.Horizontal on
	-- vertical bars or Show.Vertical on horizontal bars marks the value on the axis).
	self.Cursor.Interpolate = false
	self.Cursor.Show.Vertical = false
	self.Selection:SetEnabled(false)

	return self
end

function Bar._GetData(self: Bar): any
	return self.Series
end

function Bar._ApplyData(self: Bar, SeriesList: { any }, RecomputeBounds: boolean)
	self.Series = SeriesList
	self.Data = if SeriesList[1] then SeriesList[1].Bars else {}
	if RecomputeBounds then
		self:_UpdateProcessedBounds()
	end
end

function Bar._BlendData(self: Bar, From: any, To: any, Alpha: number): any
	return Animator.BlendSeries(From, To, Alpha, "Bars")
end

function Bar._ZeroData(self: Bar, SeriesList: any): any
	return Animator.ZeroSeries(SeriesList, "Bars")
end

-- Stacked bars need the per-slot totals in the bounds, not the individual values
function Bar._GetBoundsLists(self: Bar, Source: any?): { { any } }
	const SeriesList: { any } = Source or self.Series
	if self.Mode == "Stacked" and #SeriesList > 1 then
		const Positive: { [number]: number }, Negative: { [number]: number } = {}, {}
		const Order: { number } = {}
		for _, Series in SeriesList do
			for _, Entry in Series.Bars do
				const Value = Entry.Value
				if Value ~= nil then
					const Bucket = if Value >= 0 then Positive else Negative
					if not Positive[Entry.Index] and not Negative[Entry.Index] then
						table.insert(Order, Entry.Index)
					end
					Bucket[Entry.Index] = (Bucket[Entry.Index] or 0) + Value
				end
			end
		end

		const List: { any } = {}
		for _, Index in Order do
			table.insert(List, { Index = Index, Value = Positive[Index] or 0 })
			table.insert(List, { Index = Index, Value = Negative[Index] or 0 })
		end
		return { List }
	end

	const Lists: { { any } } = {}
	for _, Series in SeriesList do
		table.insert(Lists, Series.Bars)
		-- Floating bars start at their Base, which bounds the value axis too
		const Bases: { any } = {}
		for _, Entry in Series.Bars do
			if Entry.Base ~= nil then
				table.insert(Bases, { Index = Entry.Index, Value = Entry.Base })
			end
		end
		if #Bases > 0 then
			table.insert(Lists, Bases)
		end
	end
	return Lists
end

-- Bars: a list of bars, or a list of series ({ Bars = ..., Color = ..., Name = ... })
function Bar.SetBars(self: Bar, Bars: any, Animate: TweenInfo?)
	self:_SetData(NormalizeSeries(Bars, "Bar:SetBars", "Bars"), Animate)
end

function Bar.SetSeries(self: Bar, SeriesList: any, Animate: TweenInfo?)
	self:_SetData(NormalizeSeries(SeriesList, "Bar:SetSeries", "Bars"), Animate)
end

function Bar.AnimateTo(self: Bar, Target: any, TweenInfoObject: TweenInfo?)
	BaseGraph.AnimateTo(self, NormalizeSeries(Target, "Bar:AnimateTo", "Bars"), TweenInfoObject)
end

function Bar.AddBar(self: Bar, Entry: Types.BarEntry, SeriesIndex: number?)
	Append(self.Series, "Bars", SeriesIndex or 1, Entry, self.MaxBars, "Bar:AddBar")

	self._HasData = true
	self.Data = self.Series[1].Bars
	self:_UpdateProcessedBounds()
	self:RequestRender()
end

-- ─── Pie ─────────────────────────────────────────────────────────────────────

function Pie.new(Options: Options?): Pie
	const Backend, RendererName, Preset = Resolve(Options, "Pie")
	const self: Pie = setmetatable(BaseGraph.new(Preset), Pie) :: any
	self.Type = "Pie"
	self.RendererType = RendererName

	self.Cutout = 0 -- 0..1 inner radius ratio
	self.StartAngle = 0 -- degrees, 0 is straight up
	self.Clockwise = true
	self.Rose = false -- equal angles with the value in the radius, the Nightingale rose
	self.Reveal = 1 -- 0..1 fraction of the pie that is drawn, used by the entry animation
	self.CenterText = nil

	self.Labels = Labels.new(self)
	-- Labels.Format(Slice, Info) -> nil | text | LabelSpec. Info: { Index, Value, Fraction, Total, Data }
	self.Labels.DefaultFormat = function(_, Info: any)
		return string.format("%d%%", math.round(Info.Fraction * 100))
	end
	self.Hover = Hover.new(self) -- hovered slices ease outward; OnChanged and OnClick report them

	self.Renderer = Backend.Pie.new(self)

	return self
end

function Pie.SetSlices(self: Pie, Slices: { Types.PieSlice }, Animate: TweenInfo?)
	assert(typeof(Slices) == "table", "Pie:SetSlices: expected a table of slices")

	const First = not self._HasData
	const Entry = self.EntryAnimation
	if First and Entry and not Animate then
		-- The entry animation sweeps the pie in instead of growing values
		self._HasData = true
		self:_ApplyData(Slices, true)
		self:_TweenDriver("Reveal", 0, 1, Entry, function(Value: number)
			self.Reveal = Value
			self:RequestRender()
		end)
	else
		self:_SetData(Slices, Animate)
	end
end

-- ─── Candle ──────────────────────────────────────────────────────────────────

const function AssertCandles(Candles: any, Method: string)
	assert(typeof(Candles) == "table", `{Method}: expected a table of candles`)
	local Last = -math.huge
	for Position, Entry in Candles :: { any } do
		assert(typeof(Entry) == "table" and typeof(Entry.Index) == "number", `{Method}: candle #{Position} needs a numeric Index`)
		for _, Key in { "Open", "High", "Low", "Close" } do
			assert(typeof(Entry[Key]) == "number", `{Method}: candle #{Position} needs a numeric {Key}`)
		end
		assert(Entry.Index > Last, `{Method}: candles must be sorted by Index ascending (candle #{Position})`)
		Last = Entry.Index
	end
end

function Candle.new(Options: Options?): Candle
	const Backend, RendererName, Preset = Resolve(Options, "Candle")
	const self: Candle = setmetatable(Cartesian.new(Preset), Candle)
	self.Type = "Candle"
	self.RendererType = RendererName

	self.Candles = {}
	self.Overlays = {} -- lines drawn over the candles, such as moving averages

	self.BodyRatio = 0.6 -- fraction of the slot a body fills
	self.WickThickness = 1 -- pixels
	self.CornerRadius = 0 -- pixels, Image renderer only
	self.UpColor = Color3.fromRGB(38, 166, 91)
	self.DownColor = Color3.fromRGB(239, 83, 80)
	self.Headroom = 0.05 -- fraction of the price range kept free above and below
	self.MaxCandles = nil -- PushCandle drops the oldest candles beyond this
	self.AutoFitY = true -- the price axis follows the candles in view

	self.Hover = Hover.new(self) -- hovered candles lighten; OnChanged and OnClick report them
	self.Renderer = Backend.Candle.new(self)

	-- A trading crosshair: the time snaps to a candle, the price follows the pointer
	self.Cursor.Interpolate = false
	self.Cursor.Show.Horizontal = true

	return self
end

function Candle._GetData(self: Candle): any
	return self.Candles
end

function Candle._ApplyData(self: Candle, Candles: { any }, RecomputeBounds: boolean)
	self.Candles = Candles
	self.Data = Candles
	if RecomputeBounds then
		self:_UpdateProcessedBounds()
	end
end

function Candle._BlendData(self: Candle, From: any, To: any, Alpha: number): any
	return Animator.BlendList(From, To, Alpha)
end

-- The entry animation grows each candle out of a flat line at its close
function Candle._ZeroData(self: Candle, Candles: { any }): any
	const Output = table.create(#Candles)
	for Position, Entry in Candles do
		const Copy = table.clone(Entry)
		Copy.Open, Copy.High, Copy.Low = Entry.Close, Entry.Close, Entry.Close
		if Copy.Volume then
			Copy.Volume = 0
		end
		Output[Position] = Copy
	end
	return Output
end

-- Lows, highs and overlay points all bound the price axis
function Candle._GetBoundsLists(self: Candle, Source: any?): { { any } }
	const Candles: { any } = Source or self.Candles
	const Lows: { any }, Highs: { any } = table.create(#Candles), table.create(#Candles)
	for Position, Entry in Candles do
		Lows[Position] = { Index = Entry.Index, Value = Entry.Low }
		Highs[Position] = { Index = Entry.Index, Value = Entry.High }
	end
	const Lists: { { any } } = { Lows, Highs }
	for _, Overlay in self.Overlays do
		table.insert(Lists, Overlay.Points)
	end
	return Lists
end

function Candle.SetCandles(self: Candle, Candles: { Types.Candle }, Animate: TweenInfo?)
	AssertCandles(Candles, "Candle:SetCandles")
	self:_SetData(Candles, Animate)
end

function Candle.AnimateTo(self: Candle, Target: { Types.Candle }, TweenInfoObject: TweenInfo?)
	AssertCandles(Target, "Candle:AnimateTo")
	BaseGraph.AnimateTo(self, Target, TweenInfoObject)
end

-- Overlays: LineSeries drawn over the candles (Points, Color, Thickness, Style, Dash); Fill is ignored
function Candle.SetOverlays(self: Candle, Overlays: { Types.LineSeries }?)
	self.Overlays = Overlays or {}
	self:_UpdateProcessedBounds()
	self:RequestRender()
end

-- Live data: a candle with the Index of the last one replaces it (the open interval ticking), a newer
-- one is appended and the oldest dropped beyond MaxCandles
function Candle.PushCandle(self: Candle, Entry: Types.Candle)
	AssertCandles({ Entry }, "Candle:PushCandle")
	const Candles = self.Candles
	const Last = Candles[#Candles]
	if Last and Entry.Index == Last.Index then
		Candles[#Candles] = Entry
	else
		assert(not Last or Entry.Index > Last.Index, "Candle:PushCandle: Index must not go backwards")
		table.insert(Candles, Entry)
		TrimFront(Candles, self.MaxCandles)
	end

	self._HasData = true
	self.Data = Candles
	self:_UpdateProcessedBounds()
	self:RequestRender()
end

-- ─── Box ─────────────────────────────────────────────────────────────────────

const function AssertBoxes(Boxes: any, Method: string)
	assert(typeof(Boxes) == "table", `{Method}: expected a table of boxes`)
	local Last = -math.huge
	for Position, Entry in Boxes :: { any } do
		assert(typeof(Entry) == "table" and typeof(Entry.Index) == "number", `{Method}: box #{Position} needs a numeric Index`)
		for _, Key in { "Low", "Q1", "Median", "Q3", "High" } do
			assert(typeof(Entry[Key]) == "number", `{Method}: box #{Position} needs a numeric {Key}`)
		end
		assert(Entry.Index > Last, `{Method}: boxes must be sorted by Index ascending (box #{Position})`)
		Last = Entry.Index
	end
end

function Box.new(Options: Options?): Box
	const Backend, RendererName, Preset = Resolve(Options, "Box")
	const self: Box = setmetatable(Cartesian.new(Preset), Box)
	self.Type = "Box"
	self.RendererType = RendererName

	self.Boxes = {}
	self.BodyRatio = 0.5 -- fraction of the slot a box fills
	self.CapRatio = 0.5 -- whisker cap width as a fraction of the box width
	self.WhiskerThickness = 1 -- pixels
	self.MedianThickness = 2 -- pixels
	self.OutlierSize = 5 -- marker diameter in pixels, 0 hides outliers
	self.CornerRadius = 0 -- pixels, Image renderer only
	self.Color = Color3.fromRGB(59, 130, 246)
	self.MedianColor = Color3.new(1, 1, 1)
	self.Headroom = 0.08

	self.Categories = Categories.new(self) -- slot names from the entries' Label field
	self.Hover = Hover.new(self)
	self.Renderer = Backend.Box.new(self)

	self.Cursor.Interpolate = false
	self.Cursor.Show.Horizontal = true
	self.Selection:SetEnabled(false)

	return self
end

function Box._GetData(self: Box): any
	return self.Boxes
end

function Box._ApplyData(self: Box, Boxes: { any }, RecomputeBounds: boolean)
	self.Boxes = Boxes
	self.Data = Boxes
	if RecomputeBounds then
		self:_UpdateProcessedBounds()
	end
end

function Box._BlendData(self: Box, From: any, To: any, Alpha: number): any
	return Animator.BlendList(From, To, Alpha)
end

-- The entry animation grows each box out of its median
function Box._ZeroData(self: Box, Boxes: { any }): any
	const Output = table.create(#Boxes)
	for Position, Entry in Boxes do
		const Copy = table.clone(Entry)
		Copy.Low, Copy.Q1, Copy.Q3, Copy.High = Entry.Median, Entry.Median, Entry.Median, Entry.Median
		Copy.Outliers = {}
		Output[Position] = Copy
	end
	return Output
end

function Box._GetBoundsLists(self: Box, Source: any?): { { any } }
	const Boxes: { any } = Source or self.Boxes
	const Lows: { any }, Highs: { any }, Outliers: { any } = {}, {}, {}
	for _, Entry in Boxes do
		table.insert(Lows, { Index = Entry.Index, Value = Entry.Low })
		table.insert(Highs, { Index = Entry.Index, Value = Entry.High })
		const Values: { number } = Entry.Outliers or {}
		for _, Value in Values do
			table.insert(Outliers, { Index = Entry.Index, Value = Value })
		end
	end
	return { Lows, Highs, Outliers }
end

function Box.SetBoxes(self: Box, Boxes: { Types.BoxEntry }, Animate: TweenInfo?)
	AssertBoxes(Boxes, "Box:SetBoxes")
	self:_SetData(Boxes, Animate)
end

function Box.AnimateTo(self: Box, Target: { Types.BoxEntry }, TweenInfoObject: TweenInfo?)
	AssertBoxes(Target, "Box:AnimateTo")
	BaseGraph.AnimateTo(self, Target, TweenInfoObject)
end

-- ─── Heatmap ─────────────────────────────────────────────────────────────────

function Heatmap.new(Options: Options?): Heatmap
	const Backend, RendererName, Preset = Resolve(Options, "Heatmap")
	const self: Heatmap = setmetatable(Cartesian.new(Preset), Heatmap)
	self.Type = "Heatmap"
	self.RendererType = RendererName

	self.Cells = {}
	self.ColorScale = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(37, 99, 235)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 204, 21)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 38, 38)),
	})
	self.Range = nil -- values mapped onto the scale; nil fits the data
	self.Gap = 2 -- pixels between cells
	self.CornerRadius = 0 -- pixels, Image renderer only
	self.ColumnLabels = nil -- axis names per column and row; numbers otherwise
	self.RowLabels = nil

	-- Labels.Format(Cell, Info) -> nil | text | LabelSpec. Info: { Column, Row, Value, Rect, Color }
	self.Labels.DefaultFormat = function(Entry: any)
		return string.format("%g", Entry.Value)
	end
	self.Hover = Hover.new(self)
	self.Renderer = Backend.Heatmap.new(self)

	-- Cells are read by hovering; the cursor and drag zoom would get in the way
	self.Cursor:SetEnabled(false)
	self.Selection:SetEnabled(false)
	self:_ConfigureAxes()

	return self
end

-- One tick per column and row, named from the label lists
function Heatmap._ConfigureAxes(self: Heatmap)
	const Grid = self.Grid
	for _, Axis in { "X", "Y" } do
		const Properties: Grid.AxisProperties = (Grid.Properties :: any)[Axis]
		const Names = if Axis == "X" then self.ColumnLabels else self.RowLabels
		Properties.Step = 1
		Properties.Lines = false
		Properties.Transform = function(Value: number)
			const Name = if Names then Names[math.round(Value)] else nil
			return if Name ~= nil then tostring(Name) else tostring(math.round(Value))
		end
	end
	Grid:SetVisible(true)
end

function Heatmap.SetLabels(self: Heatmap, Columns: { string }?, Rows: { string }?)
	self.ColumnLabels = Columns
	self.RowLabels = Rows
	self:_ConfigureAxes()
	self:RequestRender()
end

-- The color a value maps to on the scale
function Heatmap.ColorFor(self: Heatmap, Value: number): Color3
	const Range = self.Range or self._DataRange or NumberRange.new(0, 1)
	const Span = Range.Max - Range.Min
	const Time = if Span > 0 then math.clamp((Value - Range.Min) / Span, 0, 1) else 0
	const Keypoints = self.ColorScale.Keypoints
	if Time <= Keypoints[1].Time then
		return Keypoints[1].Value
	end
	for Index = 1, #Keypoints - 1 do
		const Before, After = Keypoints[Index], Keypoints[Index + 1]
		if Time >= Before.Time and Time <= After.Time then
			const Alpha = if After.Time == Before.Time then 0 else (Time - Before.Time) / (After.Time - Before.Time)
			return Before.Value:Lerp(After.Value, Alpha)
		end
	end
	return Keypoints[#Keypoints].Value
end

function Heatmap._GetData(self: Heatmap): any
	return self.Cells
end

function Heatmap._ApplyData(self: Heatmap, Cells: { any }, RecomputeBounds: boolean)
	self.Cells = Cells
	self.Data = Cells
	local Min, Max = math.huge, -math.huge
	for _, Cell in Cells do
		if Cell.Value < Min then Min = Cell.Value end
		if Cell.Value > Max then Max = Cell.Value end
	end
	self._DataRange = if Min <= Max then NumberRange.new(Min, Max) else nil
	if RecomputeBounds then
		self:_UpdateProcessedBounds()
	end
end

function Heatmap._BlendData(self: Heatmap, From: any, To: any, Alpha: number): any
	return Animator.BlendList(From, To, Alpha)
end

-- The entry animation warms every cell up from the cold end of the scale
function Heatmap._ZeroData(self: Heatmap, Cells: { any }): any
	local Min = math.huge
	for _, Cell in Cells do
		if Cell.Value < Min then Min = Cell.Value end
	end
	const Range = self.Range
	const Output = table.create(#Cells)
	for Position, Cell in Cells do
		const Copy = table.clone(Cell)
		Copy.Value = if Range then Range.Min else Min
		Output[Position] = Copy
	end
	return Output
end

-- Columns bound X, rows bound Y
function Heatmap._GetBoundsLists(self: Heatmap, Source: any?): { { any } }
	const Cells: { any } = Source or self.Cells
	const List: { any } = table.create(#Cells)
	for Position, Cell in Cells do
		List[Position] = { Index = Cell.Column, Value = Cell.Row }
	end
	return { List }
end

function Heatmap.SetCells(self: Heatmap, Cells: { Types.HeatCell }, Animate: TweenInfo?)
	assert(typeof(Cells) == "table", "Heatmap:SetCells: expected a table of cells")
	for Position, Cell in Cells do
		assert(typeof(Cell.Column) == "number" and typeof(Cell.Row) == "number" and typeof(Cell.Value) == "number", `Heatmap:SetCells: cell #{Position} needs numeric Column, Row and Value`)
	end
	self:_SetData(Cells, Animate)
end

-- ─── Treemap ─────────────────────────────────────────────────────────────────

-- Values blend down the whole tree
const function BlendNodes(From: { any }?, To: { any }, Alpha: number): { any }
	const Output = table.create(#To)
	for Position, Node in To do
		const Source = if From then From[Position] else nil
		const Copy = table.clone(Node)
		if Source and typeof(Source.Value) == "number" and typeof(Node.Value) == "number" then
			Copy.Value = Source.Value + (Node.Value - Source.Value) * Alpha
		end
		if Node.Children then
			Copy.Children = BlendNodes(if Source then Source.Children else nil, Node.Children, Alpha)
		end
		Output[Position] = Copy
	end
	return Output
end

-- The entry animation starts from equal leaves; groups weigh their leaves
const function FlattenNodes(Nodes: { any }): { any }
	const Output = table.create(#Nodes)
	for Position, Node in Nodes do
		const Copy: any = table.clone(Node)
		if Node.Children then
			Copy.Value = nil
			Copy.Children = FlattenNodes(Node.Children)
		else
			Copy.Value = 1
		end
		Output[Position] = Copy
	end
	return Output
end

function Treemap.new(Options: Options?): Treemap
	const Backend, RendererName, Preset = Resolve(Options, "Treemap")
	const self: Treemap = setmetatable(BaseGraph.new(Preset), Treemap)
	self.Type = "Treemap"
	self.RendererType = RendererName

	self.Nodes = {}
	self.Gap = 2 -- pixels between tiles
	self.Padding = 4 -- pixels inside a group tile around its children
	self.HeaderHeight = 18 -- pixels above a group's children for its name while labels are on
	self.CornerRadius = 2 -- pixels, Image renderer only
	self.GroupShade = 0.55 -- how much darker group tiles are behind their children
	self.Palette = {
		Color3.fromRGB(59, 130, 246), Color3.fromRGB(16, 185, 129), Color3.fromRGB(245, 158, 11), Color3.fromRGB(236, 72, 153),
		Color3.fromRGB(139, 92, 246), Color3.fromRGB(20, 184, 166), Color3.fromRGB(249, 115, 22), Color3.fromRGB(100, 116, 139),
	}
	self.MinLabelSize = Vector2.new(48, 18) -- tiles smaller than this get no label

	self.Labels = Labels.new(self)
	self.Labels.Enabled = true
	-- Labels.Format(Node, Info) -> nil | text | LabelSpec. Info: { Key, Rect, Depth, Group, Fraction }
	self.Labels.DefaultFormat = function(Entry: any)
		return Entry.Label
	end
	self.Hover = Hover.new(self) -- hovered tiles lighten; OnChanged and OnClick report them
	self.Renderer = Backend.Treemap.new(self)

	return self
end

function Treemap._GetData(self: Treemap): any
	return self.Nodes
end

function Treemap._ApplyData(self: Treemap, Nodes: { any })
	self.Nodes = Nodes
	self.Data = Nodes
end

function Treemap._BlendData(self: Treemap, From: any, To: any, Alpha: number): any
	return BlendNodes(From, To, Alpha)
end

function Treemap._ZeroData(self: Treemap, Nodes: { any }): any
	return FlattenNodes(Nodes)
end

function Treemap.SetNodes(self: Treemap, Nodes: { Types.TreeNode }, Animate: TweenInfo?)
	assert(typeof(Nodes) == "table", "Treemap:SetNodes: expected a table of nodes")
	self:_SetData(Nodes, Animate)
end

-- ─── Radar ───────────────────────────────────────────────────────────────────

const function BlendRadar(From: { any }?, To: { any }, Alpha: number): { any }
	const Output = table.create(#To)
	for Position, Series in To do
		const Source = if From then From[Position] else nil
		const Copy = table.clone(Series)
		const Values: { number } = table.clone(Series.Values)
		if Source and Source.Values then
			for Axis, Value in Values do
				const Start = Source.Values[Axis]
				if typeof(Start) == "number" then
					Values[Axis] = Start + (Value - Start) * Alpha
				end
			end
		end
		Copy.Values = Values
		Output[Position] = Copy
	end
	return Output
end

function Radar.new(Options: Options?): Radar
	const Backend, RendererName, Preset = Resolve(Options, "Radar")
	const self: Radar = setmetatable(BaseGraph.new(Preset), Radar)
	self.Type = "Radar"
	self.RendererType = RendererName

	self.Axes = {}
	self.Series = {}
	self.Max = nil -- axis maximum; nil fits the data
	self.Rings = 4
	self.StartAngle = 0 -- degrees for the first axis, 0 is straight up
	self.Padding = 0.06 -- fraction of the radius kept clear
	self.GridColor = Color3.fromRGB(148, 148, 158)
	self.GridTransparency = 0.6
	self.Fill = true
	self.FillTransparency = 0.7
	self.PixelScale = 2 -- outline thickness in pixels
	self.Markers = nil

	self.Labels = Labels.new(self)
	self.Labels.Enabled = true
	self.Labels.Offset = 10
	-- Labels.Format(Axis, Info) -> nil | text | LabelSpec. Axis: { Index, Label }
	self.Labels.DefaultFormat = function(Entry: any)
		return Entry.Label
	end
	self.Renderer = Backend.Radar.new(self)

	return self
end

function Radar._GetData(self: Radar): any
	return self.Series
end

function Radar._ApplyData(self: Radar, SeriesList: { any })
	self.Series = SeriesList
	self.Data = SeriesList
end

function Radar._BlendData(self: Radar, From: any, To: any, Alpha: number): any
	return BlendRadar(From, To, Alpha)
end

function Radar._ZeroData(self: Radar, SeriesList: { any }): any
	const Output = table.create(#SeriesList)
	for Position, Series in SeriesList do
		const Copy = table.clone(Series)
		Copy.Values = table.create(#Series.Values, 0)
		Output[Position] = Copy
	end
	return Output
end

function Radar.SetAxes(self: Radar, Axes: { string })
	self.Axes = Axes
	self:RequestRender()
end

function Radar.SetSeries(self: Radar, SeriesList: { Types.RadarSeries }, Animate: TweenInfo?)
	assert(typeof(SeriesList) == "table", "Radar:SetSeries: expected a table of series")
	for Position, Series in SeriesList do
		assert(typeof(Series.Values) == "table", `Radar:SetSeries: series #{Position} needs a Values list`)
	end
	self:_SetData(SeriesList, Animate)
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- BackendMap: { [Name] = Backend }. DefaultName is the renderer charts use unless their Options say
-- otherwise; it can be changed later through Library.DefaultRenderer. Build runs once, from the package.
function Charts.Build(BackendMap: { [string]: Backend }, DefaultName: string): Library
	Backends = BackendMap

	const Renderers: { string } = {}
	for Name in BackendMap do
		table.insert(Renderers, Name)
	end
	table.sort(Renderers)

	Library = {
		DefaultRenderer = DefaultName,
		Renderers = Renderers,
		Line = Line,
		Bar = Bar,
		Pie = Pie,
		Candle = Candle,
		Box = Box,
		Heatmap = Heatmap,
		Treemap = Treemap,
		Radar = Radar,
		Format = Format,
		Indicators = Indicators,
		Statistics = Statistics,
		Link = Link,
	}
	return Library
end

return Charts
