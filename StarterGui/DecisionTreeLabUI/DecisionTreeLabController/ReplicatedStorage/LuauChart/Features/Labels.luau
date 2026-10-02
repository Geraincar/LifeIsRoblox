--!strict
--!native
--!optimize 2
-- Labels (Class): text labels placed by a renderer. Value labels on bars, percentages on pie slices, donut
-- center text, and leader lines for pie labels placed outside the pie.
--
-- Every label resolves through three layers, each overriding the one below: chart-wide defaults on this
-- object; per-series overrides (Series.Labels = { Placement, Color, Enabled = false, ... }); the Format
-- callback, which returns nil (no label), a string (the text), or a Types.LabelSpec table that can override
-- anything for that one label, including an explicit Position and Anchor.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const GuiUtil = require(script.Parent.Parent.Internal.GuiUtil)
const Types = require(script.Parent.Parent.Types)

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Formatter = (Entry: any, Info: any) -> any

type Fields = {
	Graph: any,
	Enabled: boolean,
	Format: Formatter?,
	DefaultFormat: Formatter?,
	Placement: string?,
	Offset: number,
	Segments: boolean,
	Totals: boolean,
	Style: Types.TextStyle,
	Distance: number?,
	LeaderLength: number,
	LeaderRun: number,
	LeaderThickness: number,
	LeaderColor: Color3?,
	OutsideMargin: number,
	Container: Frame,
	LeadersContainer: Frame,
	_Pool: { TextLabel },
	_LeaderPool: { Frame },
}

local Labels = {}
Labels.__index = Labels

export type Labels = typeof(setmetatable({} :: Fields, Labels))

-- ─── Internal ────────────────────────────────────────────────────────────────

const function MergeStyle(Base: { [string]: any }, ...: any): { [string]: any }
	const Merged = table.clone(Base)
	for _, Extra in { ... } do
		if Extra then
			for Key, Value in Extra do
				Merged[Key] = Value
			end
		end
	end
	return Merged
end

-- ─── Construction ────────────────────────────────────────────────────────────

function Labels.new(Graph: any, ContainerName: string?): Labels
	const self = setmetatable({} :: Fields, Labels)

	self.Graph = Graph
	self.Enabled = false

	self.Format = nil -- (Entry, Info) -> nil | string | LabelSpec
	self.DefaultFormat = nil -- installed by the chart type; used when Format is nil or returns a spec without Text

	-- Bars: "End" | "InsideEnd" | "Center" | "InsideStart" | "Start" (nil: "End", or "InsideEnd" for stacked
	-- segments). Pies: "Inside" | "Outside" (nil: "Inside").
	self.Placement = nil
	self.Offset = 6 -- gap between the anchor point and the text, in pixels
	self.Segments = true -- stacked bars: label each segment
	self.Totals = false -- stacked bars: label each stack total past its end
	self.Style = {}

	-- Pie, inside placement: where labels sit along the bisector, 0 at the inner edge (or center), 1 at the
	-- rim. nil is automatic: the middle of the ring on donuts, 60% of the radius on full pies.
	self.Distance = nil
	-- Pie, outside placement
	self.LeaderLength = 14 -- radial part of the leader line, in pixels
	self.LeaderRun = 12 -- horizontal part of the leader line, in pixels
	self.LeaderThickness = 1
	self.LeaderColor = nil -- defaults to the slice color
	self.OutsideMargin = 64 -- room kept around the pie for leaders and labels, in pixels

	const Name = ContainerName or "Labels"
	self.Container = GuiUtil.Container(Graph.UI, Name, 6)
	self.LeadersContainer = GuiUtil.Container(Graph.UI, Name .. "Leaders", 5)
	self._Pool = {}
	self._LeaderPool = {}

	return self
end

-- ─── Resolution ──────────────────────────────────────────────────────────────

-- Resolves one label through the three layers for any settings object shaped like this feature
-- (Categories reuses it). Returns nil for no label, otherwise
-- { Text, Placement?, Offset, Nudge?, Style, Position?, Anchor? }.
function Labels.ResolveWith(Settings, Entry: any, Info: any, Overrides: any): Types.ResolvedLabel?
	if not Settings.Enabled or (Overrides and Overrides.Enabled == false) then
		return nil
	end

	const Formatter: Formatter? = Settings.Format or Settings.DefaultFormat
	if not Formatter then
		return nil
	end

	const Result = Formatter(Entry, Info)
	if Result == nil then
		return nil
	end
	const Spec: { [string]: any } = typeof(Result) == "table" and Result or { Text = Result }

	local Text = Spec.Text
	if Text == nil and Settings.DefaultFormat then
		const Fallback = Settings.DefaultFormat(Entry, Info)
		Text = if typeof(Fallback) == "table" then Fallback.Text else Fallback
	end
	if Text == nil then
		return nil
	end

	const function Pick(Key: string): any
		local Value = Spec[Key]
		if Value == nil and Overrides then
			Value = Overrides[Key]
		end
		if Value == nil then
			Value = Settings[Key]
		end
		return Value
	end

	const Style = MergeStyle(Settings.Style or {}, Overrides and Overrides.Style, Spec.Style)
	const Color = Spec.Color or (Overrides and Overrides.Color)
	if Color then
		Style.TextColor3 = Color
	end

	return {
		Text = tostring(Text),
		Placement = Pick("Placement"),
		Offset = Pick("Offset") or 6,
		Nudge = Spec.Nudge or (Overrides and Overrides.Nudge),
		Style = Style,
		Position = Spec.Position,
		Anchor = Spec.Anchor,
	}
end

function Labels.Resolve(self: Labels, Entry: any, Info: any, Overrides: any): Types.ResolvedLabel?
	return Labels.ResolveWith(self, Entry, Info, Overrides)
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Items: { { Position: Vector2 (pixels, local to the chart), Text: string, Anchor: Vector2?, Style: TextStyle? } }
function Labels.Set(self: Labels, Items: { Types.LabelItem })
	for Index, Item in Items do
		local Label = self._Pool[Index]
		if not Label then
			const Created = GuiUtil.TextLabel(self.Style)
			-- Explicit ZIndex keeps it above the chart layers under global z-ordering
			Created.ZIndex = self.Container.ZIndex + 1
			Created.Parent = self.Container
			self._Pool[Index] = Created
			Label = Created
		end
		GuiUtil.ApplyTextStyle(Label, Item.Style or self.Style)
		Label.Text = Item.Text
		Label.AnchorPoint = Item.Anchor or Vector2.new(0.5, 0.5)
		Label.Position = UDim2.fromOffset(Item.Position.X, Item.Position.Y)
		Label.Visible = true
	end
	for Index = #Items + 1, #self._Pool do
		self._Pool[Index].Visible = false
	end
end

-- Leaders: { { Points: { Vector2, ... }, Color: Color3? } }; each consecutive pair of points is one segment.
-- Frame-based, for custom renderers. The built-in pie renderers draw leaders through their own pipeline,
-- because a rotated frame renders visibly heavier than an axis-aligned one.
function Labels.SetLeaders(self: Labels, Leaders: { Types.LeaderSpec })
	local Used = 0
	for _, Leader in Leaders do
		const Points = Leader.Points
		for Index = 1, #Points - 1 do
			Used += 1
			local Segment = self._LeaderPool[Used]
			if not Segment then
				const Created = Instance.new("Frame")
				Created.Name = "Leader"
				Created.BorderSizePixel = 0
				Created.AnchorPoint = Vector2.new(0.5, 0.5)
				Created.ZIndex = self.LeadersContainer.ZIndex + 1
				Created.Parent = self.LeadersContainer
				self._LeaderPool[Used] = Created
				Segment = Created
			end

			const Start, Finish = Points[Index], Points[Index + 1]
			const Delta = Finish - Start
			const Middle = (Start + Finish) / 2
			Segment.Position = UDim2.fromOffset(Middle.X, Middle.Y)
			Segment.Size = UDim2.fromOffset(Delta.Magnitude, self.LeaderThickness or 1)
			Segment.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
			Segment.BackgroundColor3 = Leader.Color or self.LeaderColor or Color3.new(1, 1, 1)
			Segment.Visible = true
		end
	end
	for Index = Used + 1, #self._LeaderPool do
		self._LeaderPool[Index].Visible = false
	end
end

function Labels.Clear(self: Labels)
	self:Set({})
	self:SetLeaders({})
end

function Labels.Destroy(self: Labels)
	for _, Label in self._Pool do
		Label:Destroy()
	end
	for _, Segment in self._LeaderPool do
		Segment:Destroy()
	end
	table.clear(self._Pool)
	table.clear(self._LeaderPool)
end

return Labels
