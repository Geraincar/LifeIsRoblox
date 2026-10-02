--!strict
--!native
--!optimize 2
-- Heatmap (Class): viewport heatmap renderer. One colored cube per cell, with optional value labels.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const Mapper = require(Internal.Mapper)
const HitTest = require(Internal.HitTest)
const PartPool = require(Internal.PartPool)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	Layout: Types.Layout?,
	_Pool: typeof(PartPool.new()),
}

local HeatmapRenderer = {}
HeatmapRenderer.__index = HeatmapRenderer

export type HeatmapRenderer = typeof(setmetatable({} :: Fields, HeatmapRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function HeatmapRenderer.new(Graph: any): HeatmapRenderer
	const self = setmetatable({} :: Fields, HeatmapRenderer)
	self.Graph = Graph
	self.WorldHeight = 100
	self.Thickness = 5
	self.Layout = nil
	self._Pool = PartPool.new()
	return self
end

function HeatmapRenderer.AdjustBounds(self: HeatmapRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	return MinX - 0.5, MaxX + 0.5, MinY - 0.5, MaxY + 0.5
end

function HeatmapRenderer.HitTest(self: HeatmapRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function HeatmapRenderer.Destroy(self: HeatmapRenderer)
	self._Pool:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function HeatmapRenderer._SetupCamera(self: HeatmapRenderer)
	const Camera: Camera = self.Graph._Camera
	Camera.CFrame = CFrame.new(0, 0, (self.WorldHeight / 2) / math.tan(math.rad(Camera.FieldOfView / 2)))
	const Frame = self.Graph.UI.Cells
	if Frame.CurrentCamera ~= Camera then
		Frame.CurrentCamera = Camera
	end
end

function HeatmapRenderer.Update(self: HeatmapRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Pool = self._Pool
	Pool:Begin()

	const Cells: { any } = Graph.Cells or {}
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	if #Cells == 0 or AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		Pool:Finish()
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end

	self:_SetupCamera()
	const Visible = Graph:GetVisibleBounds()
	const Projector = Mapper.GetWorldProjector(AbsoluteSize, Visible, self.WorldHeight)
	const ToPixel = Mapper.GetPixelProjector(AbsoluteSize, Visible)
	const WorldPerPixel = self.WorldHeight / AbsoluteSize.Y
	const HalfGap = (Graph.Gap or 0) / 2 * WorldPerPixel
	const Container = Graph.UI.Cells.Model
	const Hover = Graph.Hover
	const ShowLabels = Labels and Labels.Enabled
	const Layout: Types.Layout = { Items = {} }
	const LabelItems: { Types.LabelItem } = {}

	for Position, Cell in Cells do
		const Column: number, Row: number = Cell.Column, Cell.Row
		const CornerA = Projector.ToWorld(Column - 0.5, Row - 0.5)
		const CornerB = Projector.ToWorld(Column + 0.5, Row + 0.5)
		const CellWidth = math.abs(CornerB.X - CornerA.X) - HalfGap * 2
		const CellHeight = math.abs(CornerB.Y - CornerA.Y) - HalfGap * 2
		if CellWidth <= 0 or CellHeight <= 0 then
			continue
		end

		local Color: Color3 = Graph:ColorFor(Cell.Value)
		if Hover then
			const Amount: number = Hover:GetAlpha(Position) * (Hover.Highlight or 0.3)
			if Amount > 0 then
				Color = Color:Lerp(WHITE, math.clamp(Amount, 0, 1))
			end
		end
		const Cube: any = Pool:Get(Container, "Cells", Assets.FillerCube)
		Cube.Color = Color
		Cube.Size = Vector3.new(CellWidth, CellHeight, self.Thickness)
		Cube.Position = Vector3.new((CornerA.X + CornerB.X) / 2, (CornerA.Y + CornerB.Y) / 2, 0)

		const PixelA, PixelB = ToPixel(Column - 0.5, Row - 0.5), ToPixel(Column + 0.5, Row + 0.5)
		const Rect = { math.min(PixelA.X, PixelB.X), math.min(PixelA.Y, PixelB.Y), math.max(PixelA.X, PixelB.X), math.max(PixelA.Y, PixelB.Y) }
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

	Pool:Finish()
	self.Layout = Layout
	if Labels then
		Labels:Set(LabelItems)
	end
end

return HeatmapRenderer
