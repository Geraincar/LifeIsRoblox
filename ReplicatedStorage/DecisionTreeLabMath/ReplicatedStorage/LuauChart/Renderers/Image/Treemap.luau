--!strict
--!native
--!optimize 2
-- Treemap (Class): image treemap renderer. Squarified tiles into an EditableImage, group tiles shaded behind
-- their children, with tile labels.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Root = script.Parent
const Canvas = require(Root.Canvas)
const Draw = require(Root.Draw)
const Internal = Root.Parent.Parent.Internal
const TreemapMath = require(Internal.TreemapMath)
const HitTest = require(Internal.HitTest)
const Types = require(Root.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const BLACK = Color3.new(0, 0, 0)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	Layout: Types.Layout?,
	_Canvas: Canvas.Canvas,
}

local TreemapRenderer = {}
TreemapRenderer.__index = TreemapRenderer

export type TreemapRenderer = typeof(setmetatable({} :: Fields, TreemapRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function TreemapRenderer.new(Graph: any): TreemapRenderer
	const self = setmetatable({} :: Fields, TreemapRenderer)
	self.Graph = Graph
	self.Layout = nil
	self._Canvas = Canvas.new(Graph.UI.Tiles)
	return self
end

function TreemapRenderer.HitTest(self: TreemapRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function TreemapRenderer.Destroy(self: TreemapRenderer)
	self._Canvas:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function TreemapRenderer.Update(self: TreemapRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Image = self._Canvas:Prepare()
	if not Image then
		return
	end

	const Nodes: { any } = Graph.Nodes or {}
	const Size = Image.Size
	const Width, Height = Size.X, Size.Y
	const Scale: Vector2 = Graph.UI.AbsoluteSize / Size
	const ShowLabels = Labels and Labels.Enabled
	-- Gap, padding and the group header are UI pixels; the image may be smaller than the UI
	const Tiles = TreemapMath.Layout(Nodes, Width, Height, {
		Gap = (Graph.Gap or 0) / Scale.X,
		Padding = (Graph.Padding or 0) / Scale.X,
		Header = if ShowLabels then (Graph.HeaderHeight or 0) / Scale.Y else 0,
		Palette = Graph.Palette,
	})
	if #Tiles == 0 then
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end

	const PixelBuffer = self._Canvas:Buffer()
	const Radius: number = Graph.CornerRadius or 0
	const Hover = Graph.Hover
	const MinLabel: Vector2 = Graph.MinLabelSize or Vector2.new(48, 18)
	const Layout: Types.Layout = { Items = {} }
	const LabelItems: { Types.LabelItem } = {}

	local Total = 0
	for _, Node in Nodes do
		Total += TreemapMath.Weight(Node)
	end

	for _, Tile in Tiles do
		const Rect = Tile.Rect
		local Color = Tile.Color
		if Tile.Group then
			Color = Color:Lerp(BLACK, Graph.GroupShade or 0.55)
		elseif Hover then
			const Amount: number = Hover:GetAlpha(Tile.Key) * (Hover.Highlight or 0.3)
			if Amount > 0 then
				Color = Color:Lerp(WHITE, math.clamp(Amount, 0, 1))
			end
		end
		Draw.RoundedRect(PixelBuffer, Width, Height, Rect[1], Rect[2], Rect[3], Rect[4], Radius, Color)

		const UIRect = { Rect[1] * Scale.X, Rect[2] * Scale.Y, Rect[3] * Scale.X, Rect[4] * Scale.Y }
		-- Only leaves answer hovers, so a group never hides its children
		if not Tile.Group then
			Layout.Items[Tile.Key] = { Entry = Tile.Entry, Series = Tile.Depth, Rect = UIRect }
		end

		if ShowLabels then
			const TileWidth, TileHeight = UIRect[3] - UIRect[1], UIRect[4] - UIRect[2]
			const Header: number = Graph.HeaderHeight or 0
			const Fits = if Tile.Group then (Header > 0 and TileWidth >= MinLabel.X) else (TileWidth >= MinLabel.X and TileHeight >= MinLabel.Y)
			if Fits then
				const Spec: Types.ResolvedLabel? = Labels:Resolve(Tile.Entry, { Key = Tile.Key, Rect = UIRect, Depth = Tile.Depth, Group = Tile.Group, Fraction = if Total > 0 then TreemapMath.Weight(Tile.Entry) / Total else 0 })
				if Spec then
					-- Group names sit in the header strip above their children, leaf names in the middle
					const Padding: number = Graph.Padding or 0
					local LabelPosition = if Tile.Group
						then Vector2.new(UIRect[1] + Padding + 2, UIRect[2] + Padding + Header / 2)
						else Vector2.new((UIRect[1] + UIRect[3]) / 2, (UIRect[2] + UIRect[4]) / 2)
					local Anchor = if Tile.Group then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5)
					if Spec.Position then LabelPosition = Spec.Position end
					if Spec.Anchor then Anchor = Spec.Anchor end
					if Spec.Nudge then LabelPosition += Spec.Nudge end
					table.insert(LabelItems, { Position = LabelPosition, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
				end
			end
		end
	end

	self._Canvas:Flush()
	self.Layout = Layout
	if Labels then
		Labels:Set(LabelItems)
	end
end

return TreemapRenderer
