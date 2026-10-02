--!strict
--!native
--!optimize 2
-- Pie (Class): image pie renderer, drawing into an EditableImage. Border.Mode: "Between" (radial lines
-- between slices), "Rim" (outer and inner arcs) or "All" (default).

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Internal = Root.Parent.Parent.Internal
const PieMath = require(Internal.PieMath)
const HitTest = require(Internal.HitTest)
const Types = require(Root.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	DefaultOffset: number,
	Padding: number,
	Layout: Types.Layout?,
	_Canvas: Canvas.Canvas,
}

local PieRenderer = {}
PieRenderer.__index = PieRenderer

export type PieRenderer = typeof(setmetatable({} :: Fields, PieRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function PieRenderer.new(Graph: any): PieRenderer
	const self = setmetatable({} :: Fields, PieRenderer)
	self.Graph = Graph

	self.DefaultOffset = 0 -- explode distance in pixels for slices that set no Offset
	self.Padding = 0.04 -- fraction of the radius kept clear around the pie

	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover feature

	self._Canvas = Canvas.new(Graph.UI.Slices)

	return self
end

function PieRenderer.HitTest(self: PieRenderer, Local: Vector2): any
	return HitTest.Pie(self.Layout, Local)
end

function PieRenderer.Destroy(self: PieRenderer)
	self._Canvas:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function PieRenderer.Update(self: PieRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels

	const Image = self._Canvas:Prepare()
	if not Image then
		return
	end

	const Slices = PieMath.Slices(Graph)
	if #Slices == 0 then
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end

	local MaxOffset = 0
	for _, Slice in Slices do
		MaxOffset = math.max(MaxOffset, Slice.Offset)
	end

	const ShowLabels = Labels and Labels.Enabled
	const Outside = ShowLabels and Labels.Placement == "Outside"
	const Reserve: number = if Outside then (Labels.OutsideMargin or 64) else 0

	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const Center = Size / 2
	const Outer = (math.min(Width, Height) / 2 - MaxOffset - Reserve) * (1 - self.Padding)
	if Outer <= 0 then
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end
	const Inner = Outer * (Graph.Cutout or 0)

	-- The image is capped below the UI's pixel size and stretched: hover and label geometry is in UI pixels
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size

	const PixelBuffer = self._Canvas:Buffer()
	const Layout: Types.Layout = { Center = Center * Scale, Outer = Outer * Scale.X, Inner = Inner * Scale.X, Items = {} }
	const LabelItems: { Types.LabelItem } = {}
	const Leaders: { Types.LeaderSpec } = {}

	for _, Slice in Slices do
		const SliceData = Slice.Data

		-- The slice moves along its bisector when exploded
		const BisectorDir = Draw.Dir(Slice.Bisector)
		const OffsetVector = BisectorDir * Slice.Offset
		const SliceCenter = Center + OffsetVector

		-- Rose charts carry the value in the radius, scaled over the ring so the cutout stays put
		const SliceOuter = Inner + (Outer - Inner) * Slice.Scale
		const SliceInner = Inner

		const Border = SliceData.Border
		local BorderSpec: Draw.SectorBorder? = nil
		if Border and (Border.Thickness or 0) > 0 then
			const Mode = Border.Mode or "All"
			BorderSpec = {
				Thickness = Border.Thickness,
				Color = Border.Color or WHITE,
				Rim = Mode == "Rim" or Mode == "All",
				Between = Mode == "Between" or Mode == "All",
			}
		end

		Draw.Sector(PixelBuffer, Width, Height, SliceCenter, Slice.Start, Slice.Sweep, SliceInner, SliceOuter, SliceData.Color or WHITE, BorderSpec)

		Layout.Items[Slice.Index] = { Entry = SliceData, Start = Slice.Start, Sweep = Slice.Sweep, Offset = OffsetVector * Scale, Outer = SliceOuter * Scale.X }

		if ShowLabels then
			const Spec: Types.ResolvedLabel? = Labels:Resolve(SliceData, Slice)
			if Spec then
				local Position: Vector2
				local Anchor: Vector2? = nil
				if (Spec.Placement or "Inside") == "Outside" then
					-- Past the rim, on a leader line that bends horizontally toward the label
					const Side = if BisectorDir.X >= 0 then 1 else -1
					const Rim = SliceCenter + BisectorDir * (SliceOuter + 2)
					const Elbow = SliceCenter + BisectorDir * (SliceOuter + (Labels.LeaderLength or 14))
					const Tip = Elbow + Vector2.new(Side * (Labels.LeaderRun or 12), 0)
					table.insert(Leaders, { Points = { Rim, Elbow, Tip }, Color = Labels.LeaderColor or SliceData.Color or WHITE })
					Position = Tip * Scale + Vector2.new(Side * Spec.Offset, 0)
					Anchor = Vector2.new(if Side > 0 then 0 else 1, 0.5)
				else
					-- Automatic placement: the middle of the ring on donuts, 60% of the radius on full pies
					const Distance: number = Labels.Distance or (if Inner > 0.5 then 0.5 else 0.6)
					const Radius = SliceInner + (SliceOuter - SliceInner) * Distance
					Position = (SliceCenter + BisectorDir * Radius) * Scale
				end
				if Spec.Position then Position = Spec.Position end
				if Spec.Anchor then Anchor = Spec.Anchor end
				if Spec.Nudge then Position += Spec.Nudge end
				table.insert(LabelItems, { Position = Position, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
			end
		end
	end

	if Graph.CenterText then
		table.insert(LabelItems, { Position = Center * Scale, Text = tostring(Graph.CenterText) })
	end

	-- Leader lines go into the same image as the slices, so both of their segments get the same antialiased
	-- weight; rotated GUI frames would render the angled segment heavier than the horizontal one
	const LeaderThickness: number = if Labels then (Labels.LeaderThickness or 1) else 1
	for _, Leader in Leaders do
		Draw.Stroke(PixelBuffer, Width, Height, Leader.Points, LeaderThickness, Leader.Color or WHITE)
	end

	self._Canvas:Flush()
	self.Layout = Layout
	if Labels then
		Labels:Set(LabelItems)
		Labels:SetLeaders({})
	end
end

return PieRenderer
