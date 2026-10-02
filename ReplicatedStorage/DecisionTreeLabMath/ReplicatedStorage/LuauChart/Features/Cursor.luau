--!strict
--!native
--!optimize 2
-- Cursor (Class)

-- ─── Services ────────────────────────────────────────────────────────────────

const TweenService = game:GetService("TweenService")
const GuiService = game:GetService("GuiService")

-- ─── Dependencies ────────────────────────────────────────────────────────────

const GuiUtil = require(script.Parent.Parent.Internal.GuiUtil)
const Types = require(script.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const GuiInset = GuiService:GetGuiInset()

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Formatter = (Value: any, Info: Types.CursorInfo) -> any

type Fields = {
	Graph: any,
	UI: any, -- the Cursor frame, with Vertical, Horizontal and Point children
	Enabled: boolean,
	Mode: string,
	Interpolate: boolean,
	Follow: string,
	Series: number,
	TweenInfo: TweenInfo?,
	Show: { Vertical: boolean, Horizontal: boolean, Point: boolean, Tooltip: boolean },
	Format: { X: Formatter, Y: Formatter },
	OnChanged: ((Info: Types.CursorInfo?) -> ())?,
	OnClick: ((Info: Types.CursorInfo) -> ())?,
	Info: Types.CursorInfo?,
	_Hovering: boolean,
	_LastLocal: Vector2?,
	_LastPoint: any,
	_PointTransparency: number?,
	_Connections: { RBXScriptConnection },
}

local Cursor = {}
Cursor.__index = Cursor

export type Cursor = typeof(setmetatable({} :: Fields, Cursor))

-- ─── Construction ────────────────────────────────────────────────────────────

function Cursor.new(Graph: any): Cursor
	const self = setmetatable({} :: Fields, Cursor)

	self.Graph = Graph
	self.UI = Graph.UI:FindFirstChild("Cursor")
	self.Enabled = false

	self.Mode = "SnapX" -- "SnapX" | "Nearest2D"
	self.Interpolate = true -- SnapX only: interpolate along the line instead of snapping to the nearest entry
	self.Follow = "Line" -- "Line" | "Mouse": whether the vertical guide sits on the line or under the mouse
	self.Series = 1 -- which series the cursor tracks on multi-series charts
	self.TweenInfo = nil -- optional TweenInfo to smooth cursor movement

	self.Show = {
		Vertical = true,
		Horizontal = false,
		Point = true,
		Tooltip = true,
	}

	self.Format = {
		X = function(Value: any)
			return tostring(Value)
		end,
		Y = function(Value: any)
			return tostring(Value)
		end,
	}

	-- Info is a Types.CursorInfo
	self.OnChanged = nil -- function(Info?) when the nearest data point changes; nil when the pointer leaves
	self.OnClick = nil -- function(Info) on a click or tap over the chart
	self.Info = nil

	self._Hovering = false
	self._LastLocal = nil
	self._LastPoint = nil
	self._Connections = {}

	const UI = self.UI
	if UI then
		UI.Visible = false
		self._PointTransparency = UI.Point.BackgroundTransparency
		self:_BindInput()
	end

	return self
end

-- ─── Visibility ──────────────────────────────────────────────────────────────

function Cursor._RefreshVisibility(self: Cursor)
	const UI = self.UI
	if not UI then
		return
	end

	const Active = self.Enabled and self._Hovering
	UI.Visible = Active
	if not Active then
		self:_SetInfo(nil)
	end

	const Show = self.Show
	UI.Vertical.Visible = Show.Vertical
	UI.Horizontal.Visible = Show.Horizontal

	-- The tooltip hangs off the point frame, so the frame stays (invisible) when only the tooltip is wanted
	const Point = UI.Point
	Point.Visible = Show.Point or Show.Tooltip
	Point.BackgroundTransparency = if Show.Point then (self._PointTransparency or 0) else 1
	const PointStroke = Point:FindFirstChildOfClass("UIStroke")
	if PointStroke then
		PointStroke.Enabled = Show.Point
	end
	Point.DataViewer.Visible = Show.Tooltip
end

function Cursor.SetEnabled(self: Cursor, State: boolean)
	self.Enabled = State
	self:_RefreshVisibility()
end

-- OnChanged fires when the nearest data point changes; interpolated values update silently
function Cursor._SetInfo(self: Cursor, Info: Types.CursorInfo?)
	const Point = if Info then Info.Point else nil
	self.Info = Info
	if Point == self._LastPoint then
		return
	end
	self._LastPoint = Point
	const OnChanged = self.OnChanged
	if OnChanged then
		OnChanged(Info)
	end
end

-- ─── Input ───────────────────────────────────────────────────────────────────

function Cursor._BindInput(self: Cursor)
	const Target: GuiObject = self.Graph.UI

	table.insert(self._Connections, Target.MouseEnter:Connect(function()
		self._Hovering = true
		self:_RefreshVisibility()
	end))

	table.insert(self._Connections, Target.MouseLeave:Connect(function()
		self._Hovering = false
		self:_RefreshVisibility()
	end))

	table.insert(self._Connections, Target.MouseMoved:Connect(function(X: number, Y: number)
		if not self.Enabled then
			return
		end
		self:SetPosition(Vector2.new(X, Y) - (Target.AbsolutePosition + GuiInset))
	end))

	-- A finger acts as the hover while it is down
	const function TouchLocal(Input: InputObject): Vector2
		return Vector2.new(Input.Position.X, Input.Position.Y) - Target.AbsolutePosition
	end

	table.insert(self._Connections, Target.InputBegan:Connect(function(Input: InputObject)
		if Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		self._Hovering = true
		self:_RefreshVisibility()
		if self.Enabled then
			self:SetPosition(TouchLocal(Input))
		end
	end))

	table.insert(self._Connections, Target.InputChanged:Connect(function(Input: InputObject)
		if Input.UserInputType ~= Enum.UserInputType.Touch or not self.Enabled then
			return
		end
		self:SetPosition(TouchLocal(Input))
	end))

	table.insert(self._Connections, Target.InputEnded:Connect(function(Input: InputObject)
		if Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		self._Hovering = false
		self:_RefreshVisibility()
	end))

	-- The click resolves the release position itself, so the order of InputEnded handlers does not matter
	for _, Connection in GuiUtil.ClickDetector(Target, function(Local: Vector2)
		const OnClick = self.OnClick
		if not self.Enabled or not OnClick then
			return
		end
		const Info = self:_Resolve(Local)
		if Info then
			OnClick(Info)
		end
	end) do
		table.insert(self._Connections, Connection)
	end
end

-- ─── Resolution ──────────────────────────────────────────────────────────────

-- Raw data of the tracked series, gaps included. Line series keep it in Points, bar series in Bars.
function Cursor._GetSeriesPoints(self: Cursor): { any }
	const SeriesList = self.Graph.Series
	if SeriesList then
		const Series = SeriesList[self.Series or 1]
		return if Series then (Series.Points or Series.Bars or {}) else {}
	end
	return self.Graph.Data or {}
end

-- Points as drawn (spline samples for curves), falling back to raw data
function Cursor._GetRenderPoints(self: Cursor): { any }
	const Renderer = self.Graph.Renderer
	if Renderer then
		const BySeries = Renderer.RenderPointsBySeries
		if BySeries and BySeries[self.Series or 1] then
			return BySeries[self.Series or 1]
		end
		if Renderer.RenderPoints then
			return Renderer.RenderPoints
		end
	end
	return self:_GetSeriesPoints()
end

function Cursor._FindSegmentByIndex(self: Cursor, Points: { any }, TargetIndex: number): (any, any)
	const Count = #Points

	if TargetIndex <= Points[1].Index then
		return Points[1], Points[2]
	end
	if TargetIndex >= Points[Count].Index then
		return Points[Count - 1], Points[Count]
	end

	local Low, High = 1, Count - 1
	while Low <= High do
		const Mid = math.floor((Low + High) * 0.5)
		const Before, After = Points[Mid], Points[Mid + 1]

		if TargetIndex < Before.Index then
			High = Mid - 1
		elseif TargetIndex > After.Index then
			Low = Mid + 1
		else
			return Before, After
		end
	end

	return Points[Count - 1], Points[Count]
end

function Cursor._InterpolateValue(self: Cursor, Before: any, After: any, TargetIndex: number): number
	const Span: number = After.Index - Before.Index
	if Span == 0 then
		return Before.Value
	end
	return math.lerp(Before.Value, After.Value, (TargetIndex - Before.Index) / Span)
end

-- Nearest real (non-gap) point by Index, with its position in the list
function Cursor._FindNearestByIndex(self: Cursor, Points: { any }, TargetIndex: number): (any, number?)
	local Best, BestIndex = nil, nil
	local BestDistance = math.huge

	for Position, Point in Points do
		if Point.Value ~= nil then
			const Distance = math.abs(TargetIndex - Point.Index)
			if Distance < BestDistance then
				BestDistance = Distance
				Best, BestIndex = Point, Position
			end
		end
	end

	return Best, BestIndex
end

function Cursor._FindNearestPoint2D(self: Cursor, Points: { any }, MousePosition: Vector2): any
	local BestPoint = nil
	local BestDistance2 = math.huge

	for _, Point in Points do
		if Point.Value ~= nil then
			const Local = self:_DataToLocal(Point.Index, Point.Value)
			const DeltaX, DeltaY = Local.X - MousePosition.X, Local.Y - MousePosition.Y
			const Distance2 = DeltaX * DeltaX + DeltaY * DeltaY

			if Distance2 < BestDistance2 then
				BestDistance2 = Distance2
				BestPoint = Point
			end
		end
	end

	return BestPoint
end

function Cursor._DataToLocal(self: Cursor, Index: number, Value: number): Vector2
	const Size: Vector2 = self.Graph.UI.AbsoluteSize
	const Visible: Types.Bounds = self.Graph:GetVisibleBounds()

	-- Horizontal charts put the Index on screen Y and the Value on screen X
	const ScreenX: number, ScreenY: number = self.Graph:_ToScreenAxes(Index, Value)

	const XSpan = Visible.X.Max == Visible.X.Min and 1 or Visible.X.Max - Visible.X.Min
	const YSpan = Visible.Y.Max == Visible.Y.Min and 1 or Visible.Y.Max - Visible.Y.Min

	const XAlpha = math.clamp((ScreenX - Visible.X.Min) / XSpan, 0, 1)
	const YAlpha = math.clamp((ScreenY - Visible.Y.Min) / YSpan, 0, 1)

	return Vector2.new(XAlpha * Size.X, (1 - YAlpha) * Size.Y)
end

-- Bar charts report the bar under the pointer (or the nearest one), so multi-series and stacked charts
-- follow the hovered bar instead of the first series. The point sits at the bar's far end.
function Cursor._ResolveBar(self: Cursor, Position: Vector2, Renderer): Types.CursorInfo?
	const Layout: Types.Layout = Renderer.Layout
	local Key = Renderer.HitTest and Renderer:HitTest(Position)
	local Item: Types.LayoutItem? = if Key ~= nil then Layout.Items[Key] else nil -- The other way throws a warn

	const Horizontal = self.Graph.Orientation == "Horizontal"
	if not Item then
		-- Not over a bar: stay in the slot under the pointer, then take that slot's nearest bar along the value axis
		const Along = if Horizontal then Position.Y else Position.X
		local SlotIndex: number? = nil
		local BestBand = math.huge
		const Slots = Layout.Slots
		if Slots then
			for Index, Slot in Slots do
				const Distance = math.abs((Slot.Band[1] + Slot.Band[2]) / 2 - Along)
				if Distance < BestBand then
					BestBand, SlotIndex = Distance, Index
				end
			end
		end

		local BestDistance = math.huge
		for ItemKey, Candidate in Layout.Items do
			const Rect = Candidate.Rect
			if Rect and (SlotIndex == nil or Candidate.Entry.Index == SlotIndex) then
				const Distance = if Horizontal
					then math.max(Rect[1] - Position.X, 0, Position.X - Rect[3])
					else math.max(Rect[2] - Position.Y, 0, Position.Y - Rect[4])
				if Distance < BestDistance then
					BestDistance = Distance
					Item, Key = Candidate, ItemKey
				end
			end
		end
	end
	if not Item or not Item.Rect then
		return nil
	end

	const Entry = Item.Entry
	const Rect = Item.Rect
	const Negative = (Entry.Value or 0) < (Entry.Base or 0)
	const Local = if Horizontal
		then Vector2.new(if Negative then Rect[1] else Rect[3], (Rect[2] + Rect[4]) / 2)
		else Vector2.new((Rect[1] + Rect[3]) / 2, if Negative then Rect[4] else Rect[2])

	const SeriesIndex = Item.Series or 1
	const SeriesList = self.Graph.Series
	const Series = SeriesList and SeriesList[SeriesIndex]
	const PointIndex = if Series then table.find(Series.Bars, Entry) else nil

	return {
		Series = SeriesIndex,
		Index = Entry.Index,
		Value = Entry.Value,
		Point = Entry,
		PointIndex = PointIndex,
		Position = Position,
		Key = Key,
		Local = Local,
	}
end

-- Column charts (candles, boxes) snap the index to the nearest column while the value follows the pointer
function Cursor._ResolveColumn(self: Cursor, Position: Vector2, Renderer: any): Types.CursorInfo?
	const Layout: Types.Layout = Renderer.Layout
	local Best: Types.LayoutItem? = nil
	local BestKey: any = nil
	local BestDistance = math.huge
	for Key, Item in Layout.Items do
		const Rect = Item.Rect
		if Rect then
			const Distance = math.abs((Rect[1] + Rect[3]) / 2 - Position.X)
			if Distance < BestDistance then
				Best, BestKey, BestDistance = Item, Key, Distance
			end
		end
	end
	if not Best or not Best.Rect then
		return nil
	end

	const Entry = Best.Entry
	const Rect = Best.Rect
	const Size: Vector2 = self.Graph.UI.AbsoluteSize
	const Visible: Types.Bounds = self.Graph:GetVisibleBounds()
	const YAlpha = if Size.Y > 0 then 1 - math.clamp(Position.Y / Size.Y, 0, 1) else 0
	const Data: { any } = self.Graph.Data or {}

	return {
		Series = 1,
		Index = Entry.Index,
		Value = if Entry.Close ~= nil then Entry.Close else Entry.Median,
		Price = math.lerp(Visible.Y.Min, Visible.Y.Max, YAlpha),
		Point = Entry,
		PointIndex = table.find(Data, Entry),
		Position = Position,
		Key = BestKey,
		Local = Vector2.new((Rect[1] + Rect[3]) / 2, Position.Y),
	}
end

-- Render points of stacked charts carry the raw value in Raw; plain charts have only Value
const function RawOf(Point: any): number?
	return if Point.Raw ~= nil then Point.Raw else Point.Value
end

-- What the cursor should show for a local pixel position, without touching the UI
function Cursor._Resolve(self: Cursor, Position: Vector2): Types.CursorInfo?
	const Renderer = self.Graph.Renderer
	const HasLayout = Renderer ~= nil and Renderer.Layout ~= nil and Renderer.Layout.Items ~= nil
	if self.Graph.Type == "Bar" and HasLayout then
		return self:_ResolveBar(Position, Renderer)
	elseif self.Graph.Type == "Candle" or self.Graph.Type == "Box" then
		return if HasLayout then self:_ResolveColumn(Position, Renderer) else nil
	end

	const Raw = self:_GetSeriesPoints()
	const Points = self:_GetRenderPoints()

	-- Height is where the cursor sits (the stacked top on stacked charts), Value the data value
	local Index: number? = nil
	local Height: number? = nil
	local Value: number? = nil

	if self.Mode == "Nearest2D" then
		const Nearest = self:_FindNearestPoint2D(Points, Position)
		if not Nearest then
			return nil
		end
		Index, Height, Value = Nearest.Index, Nearest.Value, RawOf(Nearest)
	else
		-- SnapX: the Index under the pointer along the index axis (screen X, or screen Y on horizontal charts)
		const Size: Vector2 = self.Graph.UI.AbsoluteSize
		const Visible: Types.Bounds = self.Graph:GetVisibleBounds()
		local TargetIndex: number
		if self.Graph.Orientation == "Horizontal" then
			const YAlpha = if Size.Y > 0 then math.clamp(Position.Y / Size.Y, 0, 1) else 0
			TargetIndex = math.lerp(Visible.Y.Max, Visible.Y.Min, YAlpha) -- the top of the chart is the max
		else
			const XAlpha = if Size.X > 0 then math.clamp(Position.X / Size.X, 0, 1) else 0
			TargetIndex = math.lerp(Visible.X.Min, Visible.X.Max, XAlpha)
		end

		if self.Interpolate and #Points >= 2 then
			const Before, After = self:_FindSegmentByIndex(Points, TargetIndex)
			if Before.Value ~= nil and After.Value ~= nil then
				Index, Height = TargetIndex, self:_InterpolateValue(Before, After, TargetIndex)
				const BeforeRaw: number?, AfterRaw: number? = Before.Raw, After.Raw
				if BeforeRaw ~= nil and AfterRaw ~= nil then
					const Span: number = After.Index - Before.Index
					Value = if Span == 0 then BeforeRaw else math.lerp(BeforeRaw, AfterRaw, (TargetIndex - Before.Index) / Span)
				else
					Value = Height
				end
			end
		end

		if Index == nil then
			-- Snap to the nearest real point, which is also what happens inside a gap
			const Best = self:_FindNearestByIndex(Raw, TargetIndex)
			if not Best then
				return nil
			end
			Index, Height, Value = Best.Index, Best.Value, Best.Value
			-- On stacked charts the snapped point sits on the stacked top
			const Rendered = self:_FindNearestByIndex(Points, Best.Index)
			if Rendered and Rendered.Raw ~= nil then
				Height = Rendered.Value
			end
		end
	end

	const ResolvedIndex = Index :: number
	const Nearest, NearestIndex = self:_FindNearestByIndex(Raw, ResolvedIndex)
	if not Nearest then
		return nil
	end

	-- Render points of stacked charts carry Raw, so the height is a stacked top
	const IsStacked = Points[1] ~= nil and Points[1].Raw ~= nil

	return {
		Series = self.Series or 1,
		Index = ResolvedIndex,
		Value = Value :: number,
		Stacked = if IsStacked then Height else nil,
		Point = Nearest,
		PointIndex = NearestIndex,
		Position = Position,
	}
end

-- ─── Placement ───────────────────────────────────────────────────────────────

function Cursor._ApplyPositions(self: Cursor, VerticalX: number, LocalY: number)
	const UI = self.UI
	const Targets: { [GuiObject]: UDim2 } = {
		[UI.Vertical] = UDim2.fromOffset(VerticalX, 0),
		[UI.Horizontal] = UDim2.fromOffset(0, LocalY),
		[UI.Point] = UDim2.fromOffset(VerticalX, LocalY),
	}

	const Info = self.TweenInfo
	for Object, Position in Targets do
		if Info then
			TweenService:Create(Object, Info, { Position = Position }):Play()
		else
			Object.Position = Position
		end
	end
end

-- Position is in pixels, local to the chart UI
function Cursor.SetPosition(self: Cursor, Position: Vector2)
	const UI = self.UI
	if not UI then
		return
	end
	self._LastLocal = Position

	const Info = self:_Resolve(Position)
	if not Info then
		self:_SetInfo(nil)
		return
	end

	const Local = Info.Local or self:_DataToLocal(Info.Index, Info.Stacked or Info.Value)

	-- Format callbacks get the full info so they can show series names and keys too
	const DataViewer = UI.Point.DataViewer
	DataViewer.Index.Text = tostring(self.Format.X(Info.Index, Info))
	DataViewer.Value.Text = tostring(self.Format.Y(Info.Value, Info))

	self:_ApplyPositions(self.Follow == "Mouse" and Position.X or Local.X, Local.Y)
	self:_SetInfo(Info)
end

-- Re-applies the last position after the view or data changes
function Cursor.Update(self: Cursor)
	const Last = self._LastLocal
	if self.Enabled and self._Hovering and Last then
		self:SetPosition(Last)
	end
end

function Cursor.Destroy(self: Cursor)
	for _, Connection in self._Connections do
		Connection:Disconnect()
	end
	table.clear(self._Connections)
end

return Cursor
