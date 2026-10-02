--!strict
--!native
--!optimize 2
-- Heatmap (Class): image heatmap renderer. One colored cell per entry into an EditableImage, with optional
-- value labels.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const HitTest = require(Root.Parent.Parent.Internal.HitTest)
const Types = require(Root.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	Layout: Types.Layout?,
	_Canvas: Canvas.Canvas,
}

local HeatmapRenderer = {}
HeatmapRenderer.__index = HeatmapRenderer

export type HeatmapRenderer = typeof(setmetatable({} :: Fields, HeatmapRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function HeatmapRenderer.new(Graph: any): HeatmapRenderer
	const self = setmetatable({} :: Fields, HeatmapRenderer)
	self.Graph = Graph
	self.Layout = nil
	self._Canvas = Canvas.new(Graph.UI.Cells)
	return self
end

-- Half a cell of room on every side
function HeatmapRenderer.AdjustBounds(self: HeatmapRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	return MinX - 0.5, MaxX + 0.5, MinY - 0.5, MaxY + 0.5
end

function HeatmapRenderer.HitTest(self: HeatmapRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function HeatmapRenderer.Destroy(self: HeatmapRenderer)
	self._Canvas:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function HeatmapRenderer.Update(self: HeatmapRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Image = self._Canvas:Prepare()
	if not Image then
		return
	end

	const Cells: { any } = Graph.Cells or {}
	if #Cells == 0 then
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end

	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const ToPixel = Draw.PixelProjector(Graph:GetVisibleBounds(), Size)
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size
	const PixelBuffer = self._Canvas:Buffer()
	const HalfGap = (Graph.Gap or 0) / 2 / Scale.X
	const Radius: number = Graph.CornerRadius or 0
	const Hover = Graph.Hover
	const ShowLabels = Labels and Labels.Enabled
	const Layout: Types.Layout = { Items = {} }
	const LabelItems: { Types.LabelItem } = {}

	for Position, Cell in Cells do
		const Column: number, Row: number = Cell.Column, Cell.Row
		const CornerA = ToPixel(Column - 0.5, Row - 0.5)
		const CornerB = ToPixel(Column + 0.5, Row + 0.5)
		const Left, Right = math.min(CornerA.X, CornerB.X) + HalfGap, math.max(CornerA.X, CornerB.X) - HalfGap
		const Top, Bottom = math.min(CornerA.Y, CornerB.Y) + HalfGap, math.max(CornerA.Y, CornerB.Y) - HalfGap
		if Right <= Left or Bottom <= Top then
			continue
		end

		local Color: Color3 = Graph:ColorFor(Cell.Value)
		if Hover then
			const Amount: number = Hover:GetAlpha(Position) * (Hover.Highlight or 0.3)
			if Amount > 0 then
				Color = Color:Lerp(WHITE, math.clamp(Amount, 0, 1))
			end
		end
		Draw.RoundedRect(PixelBuffer, Width, Height, Left, Top, Right, Bottom, Radius, Color)

		const Rect = { Left * Scale.X, Top * Scale.Y, Right * Scale.X, Bottom * Scale.Y }
		Layout.Items[Position] = { Entry = Cell, Series = 1, Rect = Rect }

		if ShowLabels then
			const Spec: Types.ResolvedLabel? = Labels:Resolve(Cell, { Column = Column, Row = Row, Value = Cell.Value, Rect = Rect, Color = Color })
			if Spec then
				local LabelPosition = Vector2.new((Rect[1] + Rect[3]) / 2, (Rect[2] + Rect[4]) / 2)
				if Spec.Position then LabelPosition = Spec.Position end
				if Spec.Nudge then LabelPosition += Spec.Nudge end
				table.insert(LabelItems, { Position = LabelPosition, Text = Spec.Text, Anchor = Spec.Anchor, Style = Spec.Style })
			end
		end
	end

	self._Canvas:Flush()
	self.Layout = Layout
	if Labels then
		Labels:Set(LabelItems)
	end
end

return HeatmapRenderer
