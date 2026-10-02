--!strict
--!native
--!optimize 2
-- Cartesian (Class): what charts with X and Y axes share. Data bounds, view range (pan and zoom), layer
-- gradients and the axis features. Chart classes derive from it, so its methods take any chart as self.

-- ─── Services ────────────────────────────────────────────────────────────────

const TweenService = game:GetService("TweenService")

-- ─── Dependencies ────────────────────────────────────────────────────────────

const BaseGraph = require(script.Parent.BaseGraph)
const Types = require(script.Parent.Parent.Types)

const FeaturesFolder = script.Parent.Parent.Features
const Grid = require(FeaturesFolder.Grid)
const Cursor = require(FeaturesFolder.Cursor)
const Selection = require(FeaturesFolder.Selection)
const References = require(FeaturesFolder.References)
const Labels = require(FeaturesFolder.Labels)

-- ─── Configuration ───────────────────────────────────────────────────────────

const DRIVER_NAMES = { "ViewXMin", "ViewXMax", "ViewYMin", "ViewYMax" }

-- ─── Types ───────────────────────────────────────────────────────────────────

-- The fields every Cartesian chart carries on top of BaseGraph's; chart classes list them again
export type Fields = {
	ViewRange: Types.Bounds,
	ProcessedBounds: Types.Bounds,
	PixelScale: number,
	GradientMode: Types.GradientMode,
	AutoFitY: boolean,
	AutoFitPadding: number,
	Colors: { [string]: ColorSequence },
	Orientation: string?,
	Grid: Grid.Grid,
	Cursor: Cursor.Cursor,
	Selection: Selection.Selection,
	References: References.References,
	Labels: Labels.Labels,
	_ManualBounds: Types.Bounds?,
	_VisibleBoundsCache: Types.Bounds?,
	_ViewDrivers: { [string]: NumberValue },
}

local Cartesian = setmetatable({}, BaseGraph)
Cartesian.__index = Cartesian

-- ─── Internal ────────────────────────────────────────────────────────────────

const function DefaultRange(): Types.Bounds
	return {
		X = NumberRange.new(0, 1),
		Y = NumberRange.new(0, 1),
	}
end

const function SafeRange(Min: number, Max: number): NumberRange
	if Min > Max then
		return NumberRange.new(Max, Min)
	end
	return NumberRange.new(Min, Max)
end

const function NormalizeRange(ValueRange: NumberRange, BoundsRange: NumberRange): NumberRange
	const Span = BoundsRange.Max - BoundsRange.Min
	if Span == 0 then
		return NumberRange.new(0, 1)
	end

	const MinAlpha = math.clamp((ValueRange.Min - BoundsRange.Min) / Span, 0, 1)
	const MaxAlpha = math.clamp((ValueRange.Max - BoundsRange.Min) / Span, 0, 1)

	return SafeRange(MinAlpha, MaxAlpha)
end

const function EvaluateSequence(Sequence: ColorSequence, Time: number): Color3
	const Keypoints = Sequence.Keypoints
	if Time <= Keypoints[1].Time then
		return Keypoints[1].Value
	end
	if Time >= Keypoints[#Keypoints].Time then
		return Keypoints[#Keypoints].Value
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

-- Base restricted to the time window, stretched back to 0..1 and clamped outside the window
const function SliceSequence(Base: ColorSequence, WindowStart: number, WindowEnd: number): ColorSequence
	const Span = WindowEnd - WindowStart
	if Span <= 1e-6 then
		return ColorSequence.new(EvaluateSequence(Base, WindowStart))
	end

	const Keypoints = { ColorSequenceKeypoint.new(0, EvaluateSequence(Base, WindowStart)) }
	for _, Keypoint in Base.Keypoints do
		const Time = (Keypoint.Time - WindowStart) / Span
		if Time > 1e-4 and Time < 1 - 1e-4 then
			table.insert(Keypoints, ColorSequenceKeypoint.new(Time, Keypoint.Value))
		end
	end
	table.insert(Keypoints, ColorSequenceKeypoint.new(1, EvaluateSequence(Base, WindowEnd)))
	return ColorSequence.new(Keypoints)
end

-- ─── Construction ────────────────────────────────────────────────────────────

function Cartesian.new(Template: GuiObject): any
	const self: any = setmetatable(BaseGraph.new(Template), Cartesian)

	-- ProcessedBounds is in data units; ViewRange is normalized 0..1 across it
	self.ViewRange = DefaultRange()
	self.ProcessedBounds = DefaultRange()

	self.PixelScale = 1 -- line thickness in pixels

	-- "View": the layer gradient spans the visible window. "Absolute": it spans the full data range, so
	-- zooming shows a slice of it. "Relative": it spans the min and max of the visible data points.
	self.GradientMode = "View"

	-- Fits the Y axis to the entries inside the visible X window, the way trading views rescale on zoom;
	-- vertical charts only
	self.AutoFitY = false
	self.AutoFitPadding = 0.05 -- fraction of the fitted span kept free above and below

	self.Colors = {} -- layer name to base ColorSequence, captured from the asset's UIGradients
	const UI: GuiObject = self.UI
	for _, Child in UI:GetChildren() do
		const Gradient = Child:FindFirstChild("Gradient")
		if Gradient and Gradient:IsA("UIGradient") then
			self.Colors[Child.Name] = Gradient.Color
		end
	end

	self._ManualBounds = nil
	self._VisibleBoundsCache = nil

	self:_CreateViewDrivers()

	self.Grid = Grid.new(self)
	self.Cursor = Cursor.new(self)
	self.Selection = Selection.new(self)
	self.References = References.new(self)
	self.Labels = Labels.new(self)

	return self
end

-- ─── Bounds ──────────────────────────────────────────────────────────────────

-- Locks the data bounds instead of deriving them from the data; nil returns to automatic bounds
function Cartesian.SetBounds(self: any, Bounds: Types.Bounds?)
	self._ManualBounds = Bounds
	self:_UpdateProcessedBounds()
	self:RequestRender()
end

-- Entry lists that contribute to the bounds, from Source (a dataset such as an animation target) or the
-- live data; series charts override this
function Cartesian._GetBoundsLists(self: any, Source: any?): { { any } }
	return { Source or self.Data }
end

-- The data min and max that the full, un-zoomed view maps to
function Cartesian._UpdateProcessedBounds(self: any)
	self._VisibleBoundsCache = nil

	const Manual: Types.Bounds? = self._ManualBounds
	if Manual then
		self.ProcessedBounds = {
			X = SafeRange(Manual.X.Min, Manual.X.Max),
			Y = SafeRange(Manual.Y.Min, Manual.Y.Max),
		}
		return
	end

	local MinX, MaxX = math.huge, -math.huge
	local MinY, MaxY = math.huge, -math.huge
	local HasValues = false

	for _, List in self:_GetBoundsLists() :: { { any } } do
		for _, Entry in List do
			const Index: number = Entry.Index
			if Index < MinX then MinX = Index end
			if Index > MaxX then MaxX = Index end
			const Value: number? = Entry.Value
			if Value ~= nil then
				HasValues = true
				if Value < MinY then MinY = Value end
				if Value > MaxY then MaxY = Value end
			end
		end
	end
	if not HasValues then
		return
	end

	-- Bars need room for their width and a zero floor
	const Renderer = self.Renderer
	if Renderer and (Renderer.AdjustBounds::any) then
		MinX, MaxX, MinY, MaxY = Renderer:AdjustBounds(MinX, MaxX, MinY, MaxY)
	end

	-- A zero-width span would put every point in the same place
	if MinX == MaxX then MaxX += 1 end
	if MinY == MaxY then MaxY += 1 end

	-- Horizontal charts put the Index axis on screen Y and the Value axis on screen X
	if self.Orientation == "Horizontal" then
		MinX, MaxX, MinY, MaxY = MinY, MaxY, MinX, MaxX
	end

	self.ProcessedBounds = {
		X = NumberRange.new(MinX, MaxX),
		Y = NumberRange.new(MinY, MaxY),
	}
end

-- Data (Index, Value) to the pair that lives on screen axes X and Y, honoring Orientation
function Cartesian._ToScreenAxes(self: any, Index: number, Value: number): (number, number)
	if self.Orientation == "Horizontal" then
		return Value, Index
	end
	return Index, Value
end

-- Data-space coordinates of what is currently visible in the UI
function Cartesian.GetVisibleBounds(self: any): Types.Bounds
	const Cached: Types.Bounds? = self._VisibleBoundsCache
	if Cached then
		return Cached
	end

	const Processed: Types.Bounds = self.ProcessedBounds
	const View: Types.Bounds = self.ViewRange

	const function Slice(Bounds: NumberRange, Range: NumberRange): NumberRange
		const Min = math.lerp(Bounds.Min, Bounds.Max, Range.Min)
		const Max = math.lerp(Bounds.Min, Bounds.Max, Range.Max)
		return SafeRange(Min, Max)
	end

	const XVisible = Slice(Processed.X, View.X)
	local YVisible = Slice(Processed.Y, View.Y)
	if self.AutoFitY then
		const DataMin: number?, DataMax: number? = self:_DataRangeWithin(XVisible.Min, XVisible.Max)
		if DataMin and DataMax then
			const Span = if DataMax > DataMin then DataMax - DataMin else math.max(math.abs(DataMax), 1)
			const Pad = Span * (self.AutoFitPadding or 0)
			YVisible = SafeRange(DataMin - Pad, DataMax + Pad)
		end
	end

	const Visible: Types.Bounds = { X = XVisible, Y = YVisible }
	self._VisibleBoundsCache = Visible
	return Visible
end

-- Min and max Value of the data points inside the visible X window
function Cartesian._VisibleDataRange(self: any): (number?, number?)
	const Visible: Types.Bounds = self:GetVisibleBounds()
	return self:_DataRangeWithin(Visible.X.Min, Visible.X.Max)
end

function Cartesian._DataRangeWithin(self: any, XMin: number, XMax: number): (number?, number?)
	local Min, Max = math.huge, -math.huge
	-- While an animation runs the fit follows its target, so the axis settles before the data arrives
	for _, List in self:_GetBoundsLists(self._AnimationTarget) :: { { any } } do
		for _, Entry in List do
			const Value: number? = Entry.Value
			const Index: number = Entry.Index
			if Value ~= nil and Index >= XMin and Index <= XMax then
				if Value < Min then Min = Value end
				if Value > Max then Max = Value end
			end
		end
	end
	if Min == math.huge then
		return nil, nil
	end
	return Min, Max
end

-- ─── Gradients ───────────────────────────────────────────────────────────────

-- Applies GradientMode to every layer that has a UIGradient; gradients run top to bottom
function Cartesian._UpdateGradients(self: any)
	const Colors: { [string]: ColorSequence } = self.Colors
	if next(Colors) == nil then
		return
	end

	const Mode = self.GradientMode or "View"
	const Visible: Types.Bounds = self:GetVisibleBounds()
	const VisibleMin, VisibleMax = Visible.Y.Min, Visible.Y.Max

	local WindowStart, WindowEnd = 0, 1
	if Mode == "Absolute" then
		const Processed: NumberRange = self.ProcessedBounds.Y
		const ProcessedSpan = Processed.Max - Processed.Min
		if ProcessedSpan > 0 then
			WindowStart = (Processed.Max - VisibleMax) / ProcessedSpan
			WindowEnd = (Processed.Max - VisibleMin) / ProcessedSpan
		end
	elseif Mode == "Relative" then
		const DataMin: number?, DataMax: number? = self:_VisibleDataRange()
		if DataMin and DataMax and DataMax > DataMin then
			WindowStart = (DataMax - VisibleMax) / (DataMax - DataMin)
			WindowEnd = (DataMax - VisibleMin) / (DataMax - DataMin)
		end
	end

	const Stretch = math.abs(WindowStart) > 1e-6 or math.abs(WindowEnd - 1) > 1e-6
	const UI: GuiObject = self.UI
	for Name, Base in Colors do
		const Layer = UI:FindFirstChild(Name)
		const Gradient = if Layer then Layer:FindFirstChild("Gradient") else nil
		if Gradient and Gradient:IsA("UIGradient") then
			Gradient.Color = if Stretch then SliceSequence(Base, WindowStart, WindowEnd) else Base
		end
	end
end

function Cartesian._InternalUpdate(self: any)
	if self._Destroyed then
		return
	end
	self:_UpdateGradients()
	BaseGraph._InternalUpdate(self)
end

-- ─── View ────────────────────────────────────────────────────────────────────
-- Pan and zoom through NumberValue drivers, so the view can be tweened with TweenService

function Cartesian._CreateViewDrivers(self: any)
	const Drivers: { [string]: NumberValue } = {}

	const function Apply()
		self.ViewRange = {
			X = SafeRange(math.clamp(Drivers.ViewXMin.Value, 0, 1), math.clamp(Drivers.ViewXMax.Value, 0, 1)),
			Y = SafeRange(math.clamp(Drivers.ViewYMin.Value, 0, 1), math.clamp(Drivers.ViewYMax.Value, 0, 1)),
		}
		self._VisibleBoundsCache = nil
		self:RequestRender()
	end

	for _, Name in DRIVER_NAMES do
		const Driver: NumberValue = self:_GetDriver(Name)
		Driver.Value = if string.find(Name, "Max") then 1 else 0

		table.insert(self._Connections, Driver.Changed:Connect(Apply))
		Drivers[Name] = Driver
	end

	self._ViewDrivers = Drivers
end

-- ViewRange is normalized: 0..1 across ProcessedBounds on each axis
function Cartesian.SetViewRange(self: any, ViewRange: Types.Bounds, TweenInfoObject: TweenInfo?)
	const Targets: { [string]: number } = {
		ViewXMin = math.clamp(ViewRange.X.Min, 0, 1),
		ViewXMax = math.clamp(ViewRange.X.Max, 0, 1),
		ViewYMin = math.clamp(ViewRange.Y.Min, 0, 1),
		ViewYMax = math.clamp(ViewRange.Y.Max, 0, 1),
	}

	const Drivers: { [string]: NumberValue } = self._ViewDrivers
	for Name, Value in Targets do
		const Driver = Drivers[Name]
		if TweenInfoObject then
			TweenService:Create(Driver, TweenInfoObject, { Value = Value }):Play()
		else
			Driver.Value = Value
		end
	end

	-- Driver signals are deferred, so an immediate change lands in ViewRange right away; several wheel
	-- notches in one frame then build on each other instead of on a stale range
	if not TweenInfoObject then
		self.ViewRange = {
			X = SafeRange(Targets.ViewXMin, Targets.ViewXMax),
			Y = SafeRange(Targets.ViewYMin, Targets.ViewYMax),
		}
		self._VisibleBoundsCache = nil
	end
end

-- Same as SetViewRange with data-space bounds
function Cartesian.SetViewFromBounds(self: any, VisibleBounds: Types.Bounds, TweenInfoObject: TweenInfo?)
	const Processed: Types.Bounds = self.ProcessedBounds

	self:SetViewRange({
		X = NormalizeRange(VisibleBounds.X, Processed.X),
		Y = NormalizeRange(VisibleBounds.Y, Processed.Y),
	}, TweenInfoObject)
end

function Cartesian.ResetView(self: any, TweenInfoObject: TweenInfo?)
	self:SetViewRange(DefaultRange(), TweenInfoObject)
end

return Cartesian
