--!strict
--!native
--!optimize 2
-- Types (Library): data and option shapes shared by every chart.

-- ─── Types ───────────────────────────────────────────────────────────────────

export type ChartType = "Line" | "Bar" | "Pie" | "Candle" | "Box" | "Radar" | "Heatmap" | "Treemap"
export type LineStyle = "Line" | "Curve" | "Step"
export type GradientMode = "View" | "Absolute" | "Relative"
export type BarMode = "Grouped" | "Stacked"
export type LineStacking = "None" | "Stacked" | "Stream"
export type BarOrientation = "Vertical" | "Horizontal"

export type Range = {
	X: NumberRange,
	Y: NumberRange,
}

export type Border = {
	Thickness: number?, -- pixels
	Color: Color3?,
	Mode: ("Between" | "Rim" | "All")?, -- pie only
}

type BaseEntry = {
	Label: string?,
	Metadata: { [any]: any }?,
}

export type LinePoint = BaseEntry & {
	Index: number,
	Value: number?, -- nil is a gap: the line breaks here
	Envelope: number?, -- half-height of the band around the line, in Value units
	Low: number?, -- range series: the band's lower edge
	High: number?, -- range series: the band's upper edge
	Size: number?, -- marker diameter for this point, for bubble charts
	Color: Color3?, -- marker color for this point
}

export type Markers = {
	Size: number, -- diameter in pixels
	Color: Color3?, -- defaults to the series color
	Spacing: number?, -- pixels: a marker within this distance of one already drawn is skipped
	Limit: number?, -- at most this many markers, spread evenly along the series
}

export type LineSeries = {
	Name: string?,
	Points: { LinePoint },
	Color: Color3?, -- nil: drawn white and tinted by the layer gradient (see Graph.GradientMode)
	Style: LineStyle?, -- overrides Graph.Style
	Thickness: number?, -- pixels, overrides Graph.PixelScale
	Fill: boolean?, -- overrides Graph.Fill
	Dash: { number }?, -- on/off pixel lengths such as {6, 4}, overrides Graph.Dash
	Markers: Markers?, -- overrides Graph.Markers
	FillTransparency: number?, -- overrides Graph.FillTransparency; overlapping fills blend
	ZIndex: number?, -- draw order among the series, higher draws on top; defaults to the series position
	Stroke: boolean?, -- false draws no line, only markers and fill (scatter charts)
	Range: boolean?, -- the points carry Low and High and the fill runs between them (range bands)
}

export type BarEntry = BaseEntry & {
	Index: number,
	Value: number?, -- nil: no bar in this slot
	Base: number?, -- the bar starts here instead of zero (floating bars, waterfalls, timelines)
	Color: Color3?, -- defaults to the series color, then Graph.NegativeColor below zero, then white
	Gradient: ColorSequence?, -- top-to-bottom tint, Image renderer only
	Border: Border?,
	Spacing: number?, -- reserved
}

export type TextStyle = {
	TextSize: number?,
	TextColor3: Color3?,
	FontFace: Font?,
	StrokeTransparency: number?,
}

-- What a Labels or Categories Format callback may return instead of plain text: nil skips the label,
-- a string is the text, a table overrides anything for that one label
export type LabelSpec = {
	Text: string?,
	Placement: string?, -- bars: End, InsideEnd, Center, InsideStart, Start; pies: Inside, Outside
	Offset: number?, -- gap from the anchor point, in pixels
	Nudge: Vector2?, -- added to the final position, in pixels
	Color: Color3?, -- shorthand for Style.TextColor3
	Style: TextStyle?,
	Position: Vector2?, -- explicit position in chart pixels, skips placement
	Anchor: Vector2?, -- text anchor used with Position
}

-- Per-series label overrides (BarSeries.Labels)
export type LabelOverrides = {
	Enabled: boolean?,
	Placement: string?,
	Offset: number?,
	Nudge: Vector2?,
	Color: Color3?,
	Style: TextStyle?,
}

export type BarSeries = {
	Name: string?,
	Color: Color3?,
	Bars: { BarEntry },
	Labels: LabelOverrides?,
}

export type Candle = BaseEntry & {
	Index: number, -- time
	Open: number,
	High: number,
	Low: number,
	Close: number,
	Volume: number?,
	Color: Color3?, -- overrides the chart's up and down colors
}

export type BoxEntry = BaseEntry & {
	Index: number,
	Low: number, -- whisker ends
	Q1: number, -- box edges
	Median: number,
	Q3: number,
	High: number,
	Outliers: { number }?,
	Color: Color3?,
}

export type RadarSeries = {
	Name: string?,
	Values: { number }, -- one per axis
	Color: Color3?,
	Fill: boolean?,
	FillTransparency: number?,
	Thickness: number?,
	Markers: Markers?,
}

export type HeatCell = BaseEntry & {
	Column: number,
	Row: number,
	Value: number,
}

export type TreeNode = BaseEntry & {
	Value: number,
	Color: Color3?,
	Children: { TreeNode }?,
}

export type PieSlice = BaseEntry & {
	Value: number,
	Color: Color3?,
	Offset: number?, -- explode distance from the center, in pixels
	Border: Border?,
}

export type Reference = {
	Axis: "X" | "Y",
	Value: number,
	Color: Color3?,
	Thickness: number?, -- pixels
	Transparency: number?,
	Label: string?,
}

export type Band = {
	Axis: "X" | "Y",
	Min: number,
	Max: number,
	Color: Color3?,
	Transparency: number?,
}

-- ─── Internal shapes ─────────────────────────────────────────────────────────
-- Shared by renderers and features. A chart instance is typed by its class; code that takes any chart
-- (features, renderers, helpers) takes Graph.

export type Graph = any

export type Bounds = {
	X: NumberRange,
	Y: NumberRange,
}

-- A point as drawn: spline samples and stacked tops carry Raw (the data value) next to Value (the height)
export type RenderPoint = {
	Index: number,
	Value: number?,
	Envelope: number?,
	Raw: number?,
	[string]: any,
}

-- A placed label, in pixels local to the chart
export type LabelItem = {
	Position: Vector2,
	Text: string,
	Anchor: Vector2?,
	Style: TextStyle?,
}

export type LeaderSpec = {
	Points: { Vector2 },
	Color: Color3?,
}

-- What Labels.Resolve returns: the spec after the three layers merged
export type ResolvedLabel = {
	Text: string,
	Placement: string?,
	Offset: number,
	Nudge: Vector2?,
	Style: TextStyle,
	Position: Vector2?,
	Anchor: Vector2?,
}

export type Rect = { number } -- Left, Top, Right, Bottom in chart pixels

-- One hoverable item of a renderer layout
export type LayoutItem = {
	Entry: any,
	Series: number?,
	Rect: Rect?,
	Start: number?,
	Sweep: number?,
	Offset: Vector2?,
	Outer: number?,
}

-- One bar slot: the union of its bars and its extent along the slot axis
export type Slot = {
	Index: number,
	Rect: Rect,
	Band: { number },
	Entries: { any },
}

-- Pixel-space geometry a renderer publishes after each update
export type Layout = {
	Items: { [any]: LayoutItem },
	Slots: { [number]: Slot }?,
	Zero: number?,
	Orientation: string?,
	Center: Vector2?,
	Outer: number?,
	Inner: number?,
}

-- What the Cursor reports through OnChanged and OnClick
export type CursorInfo = {
	Series: number,
	Index: number, -- interpolated when Cursor.Interpolate is on
	Value: number, -- the data value; on stacked charts the raw value, not the stacked height
	Stacked: number?, -- the stacked height the cursor sits at, on stacked charts
	Price: number?, -- candle charts: the price under the pointer
	Point: any, -- nearest real data entry (a LinePoint, BarEntry, Candle or BoxEntry)
	PointIndex: number?, -- its position in the series list
	Position: Vector2, -- pixels, local to the chart
	Key: any?, -- bar and column charts: the layout key of the item under the cursor
	Local: Vector2?, -- bar and column charts: where the cursor point sits, in chart pixels
}

return {}
