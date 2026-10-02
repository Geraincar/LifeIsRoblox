--!strict
--!native
--!optimize 2
-- TreemapMath (Helper): squarified treemap layout. Children are laid in rows along the shorter side of the
-- remaining space so tiles stay close to square; nested children recurse inside their parent's tile.

local TreemapMath = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Settings = {
	Gap: number?, -- pixels between tiles
	Padding: number?, -- pixels inside a group tile around its children
	Header: number?, -- extra pixels above a group's children for its name
	Palette: { Color3 }?,
}

export type Tile = {
	Key: string, -- "3" for a top level node, "3/2" for its second child
	Entry: any,
	Rect: { number }, -- Left, Top, Right, Bottom
	Depth: number,
	Color: Color3,
	Group: boolean, -- the tile behind a set of children
}

type Box = { X: number, Y: number, Width: number, Height: number }
type RowItem = { Node: any, Position: number, Share: number }
type Placed = { Item: RowItem, X: number, Y: number, Width: number, Height: number }

-- ─── Internal ────────────────────────────────────────────────────────────────

-- A node weighs its Value, or the sum of its children when it has none of its own
const function Weight(Node: any): number
	if typeof(Node.Value) == "number" then
		return math.max(Node.Value, 0)
	end
	local Sum = 0
	for _, Child in (Node.Children or {}) :: { any } do
		Sum += Weight(Child)
	end
	return Sum
end

-- The worst aspect ratio a row would have on a side of the given length
const function Worst(Row: { RowItem }, RowSum: number, Side: number, Area: number): number
	if RowSum <= 0 or Side <= 0 then
		return math.huge
	end
	local Result = 0
	const Scale = Area / RowSum
	for _, Node in Row do
		const Length = Node.Share * Scale / Side
		const Ratio = math.max(Side / Length, Length / Side)
		if Ratio > Result then
			Result = Ratio
		end
	end
	return Result
end

const function Squarify(Nodes: { any }, Rect: Box, Output: { Tile }, Depth: number, ParentColor: Color3?, Settings: Settings, Path: string)
	local Total = 0
	for _, Node in Nodes do
		Total += Weight(Node)
	end
	if Total <= 0 then
		return
	end

	-- Largest first keeps rows compact
	const Sorted: { RowItem } = {}
	for Position, Node in Nodes do
		const Share = Weight(Node)
		if Share > 0 then
			table.insert(Sorted, { Node = Node, Position = Position, Share = Share })
		end
	end
	table.sort(Sorted, function(Left: RowItem, Right: RowItem)
		return Left.Share > Right.Share
	end)

	local X, Y, Width, Height = Rect.X, Rect.Y, Rect.Width, Rect.Height
	const Area = Width * Height
	const Placed: { Placed } = {}

	local Row: { RowItem } = {}
	local RowSum = 0

	const function PlaceRow()
		if #Row == 0 then
			return
		end
		const Along = math.min(Width, Height) -- the row runs along the shorter side
		const Thickness = (RowSum / Total) * Area / Along
		local Offset = 0
		for _, Item in Row do
			const Length = Along * (Item.Share / RowSum)
			if Width >= Height then
				table.insert(Placed, { Item = Item, X = X, Y = Y + Offset, Width = Thickness, Height = Length })
			else
				table.insert(Placed, { Item = Item, X = X + Offset, Y = Y, Width = Length, Height = Thickness })
			end
			Offset += Length
		end
		if Width >= Height then
			X += Thickness
			Width -= Thickness
		else
			Y += Thickness
			Height -= Thickness
		end
		Row = {}
		RowSum = 0
	end

	for _, Item in Sorted do
		const Side = math.min(Width, Height)
		const Remaining = Width * Height
		if #Row > 0 and Worst(Row, RowSum + Item.Share, Side, Remaining) > Worst(Row, RowSum, Side, Remaining) then
			PlaceRow()
		end
		table.insert(Row, Item)
		RowSum += Item.Share
	end
	PlaceRow()

	const Gap = Settings.Gap or 0
	for _, Tile in Placed do
		const Node = Tile.Item.Node
		const Position = Tile.Item.Position
		const Key = if Path == "" then tostring(Position) else Path .. "/" .. Position
		const Palette = Settings.Palette
		local Color: Color3? = Node.Color or ParentColor
		if Color == nil then
			Color = if Palette and #Palette > 0 then Palette[(Position - 1) % #Palette + 1] else WHITE
		end
		const TileColor = Color :: Color3
		-- Half the gap on each side keeps the outer edge flush with the chart
		const Left, Top = Tile.X + Gap / 2, Tile.Y + Gap / 2
		const Right, Bottom = Tile.X + Tile.Width - Gap / 2, Tile.Y + Tile.Height - Gap / 2
		if Right <= Left or Bottom <= Top then
			continue
		end

		const Children: { any }? = Node.Children
		if Children and #Children > 0 then
			-- The header is extra room above the children for the group's name
			const Pad = Settings.Padding or 0
			const Header = Settings.Header or 0
			const Inner = { X = Left + Pad, Y = Top + Pad + Header, Width = Right - Left - Pad * 2, Height = Bottom - Top - Pad * 2 - Header }
			table.insert(Output, { Key = Key, Entry = Node, Rect = { Left, Top, Right, Bottom }, Depth = Depth, Color = TileColor, Group = true })
			if Inner.Width > 0 and Inner.Height > 0 then
				-- Nested tiles lighten a little per level so groups read as groups
				Squarify(Children, Inner, Output, Depth + 1, TileColor:Lerp(WHITE, 0.18), Settings, Key)
			end
		else
			table.insert(Output, { Key = Key, Entry = Node, Rect = { Left, Top, Right, Bottom }, Depth = Depth, Color = TileColor, Group = false })
		end
	end
end

-- ─── API ─────────────────────────────────────────────────────────────────────

TreemapMath.Weight = Weight

-- Tiles for a node list inside a pixel rectangle: { Key, Entry, Rect = { Left, Top, Right, Bottom }, Depth,
-- Color, Group }. Groups are the parent tiles behind their children. Settings: { Gap, Padding, Header, Palette }.
function TreemapMath.Layout(Nodes: { any }, Width: number, Height: number, Settings: Settings?): { Tile }
	const Output: { Tile } = {}
	Squarify(Nodes, { X = 0, Y = 0, Width = Width, Height = Height }, Output, 0, nil, Settings or {}, "")
	return Output
end

return TreemapMath
