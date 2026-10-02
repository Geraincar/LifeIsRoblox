--!strict
--!native
--!optimize 2
-- Treemap (Class): viewport treemap renderer. One cube per tile, group tiles shaded behind their children,
-- with tile labels.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const TreemapMath = require(Internal.TreemapMath)
const HitTest = require(Internal.HitTest)
const PartPool = require(Internal.PartPool)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const BLACK = Color3.new(0, 0, 0)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	Layout: Types.Layout?,
	_Pool: typeof(PartPool.new()),
}

local TreemapRenderer = {}
TreemapRenderer.__index = TreemapRenderer

export type TreemapRenderer = typeof(setmetatable({} :: Fields, TreemapRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function TreemapRenderer.new(Graph: any): TreemapRenderer
	const self = setmetatable({} :: Fields, TreemapRenderer)
	self.Graph = Graph
	self.WorldHeight = 100
	self.Thickness = 5
	self.Layout = nil
	self._Pool = PartPool.new()
	return self
end

function TreemapRenderer.HitTest(self: TreemapRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function TreemapRenderer.Destroy(self: TreemapRenderer)
	self._Pool:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function TreemapRenderer._SetupCamera(self: TreemapRenderer)
	const Camera: Camera = self.Graph._Camera
	Camera.CFrame = CFrame.new(0, 0, (self.WorldHeight / 2) / math.tan(math.rad(Camera.FieldOfView / 2)))
	const Frame = self.Graph.UI.Tiles
	if Frame.CurrentCamera ~= Camera then
		Frame.CurrentCamera = Camera
	end
end

function TreemapRenderer.Update(self: TreemapRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Pool = self._Pool
	Pool:Begin()

	const Nodes: { any } = Graph.Nodes or {}
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	const ShowLabels = Labels and Labels.Enabled
	const Tiles: { TreemapMath.Tile } = if AbsoluteSize.X > 0 and AbsoluteSize.Y > 0
		then TreemapMath.Layout(Nodes, AbsoluteSize.X, AbsoluteSize.Y, { Gap = Graph.Gap, Padding = Graph.Padding, Header = if ShowLabels then Graph.HeaderHeight else 0, Palette = Graph.Palette })
		else {}
	if #Tiles == 0 then
		Pool:Finish()
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
		return
	end

	self:_SetupCamera()
	const WorldPerPixel = self.WorldHeight / AbsoluteSize.Y
	const HalfWidth, HalfHeight = AbsoluteSize.X / 2, AbsoluteSize.Y / 2
	const Container = Graph.UI.Tiles.Model
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

		-- Pixels to world: the origin sits in the middle, Y flips
		const Cube: any = Pool:Get(Container, "Tiles", Assets.FillerCube)
		Cube.Color = Color
		Cube.Size = Vector3.new((Rect[3] - Rect[1]) * WorldPerPixel, (Rect[4] - Rect[2]) * WorldPerPixel, self.Thickness)
		Cube.Position = Vector3.new(((Rect[1] + Rect[3]) / 2 - HalfWidth) * WorldPerPixel, (HalfHeight - (Rect[2] + Rect[4]) / 2) * WorldPerPixel, -Tile.Depth * 0.1 + (if Tile.Group then -0.5 else 0))

		if not Tile.Group then
			Layout.Items[Tile.Key] = { Entry = Tile.Entry, Series = Tile.Depth, Rect = Rect }
		end

		if ShowLabels then
			const TileWidth, TileHeight = Rect[3] - Rect[1], Rect[4] - Rect[2]
			const Header: number = Graph.HeaderHeight or 0
			const Fits = if Tile.Group then (Header > 0 and TileWidth >= MinLabel.X) else (TileWidth >= MinLabel.X and TileHeight >= MinLabel.Y)
			if Fits then
				const Spec: Types.ResolvedLabel? = Labels:Resolve(Tile.Entry, { Key = Tile.Key, Rect = Rect, Depth = Tile.Depth, Group = Tile.Group, Fraction = if Total > 0 then TreemapMath.Weight(Tile.Entry) / Total else 0 })
				if Spec then
					-- Group names sit in the header strip above their children, leaf names in the middle
					const Padding: number = Graph.Padding or 0
					local LabelPosition = if Tile.Group then Vector2.new(Rect[1] + Padding + 2, Rect[2] + Padding + Header / 2) else Vector2.new((Rect[1] + Rect[3]) / 2, (Rect[2] + Rect[4]) / 2)
					local Anchor = if Tile.Group then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5)
					if Spec.Position then LabelPosition = Spec.Position end
					if Spec.Anchor then Anchor = Spec.Anchor end
					if Spec.Nudge then LabelPosition += Spec.Nudge end
					table.insert(LabelItems, { Position = LabelPosition, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
				end
			end
		end
	end

	Pool:Finish()
	self.Layout = Layout
	if Labels then
		Labels:Set(LabelItems)
	end
end

return TreemapRenderer
