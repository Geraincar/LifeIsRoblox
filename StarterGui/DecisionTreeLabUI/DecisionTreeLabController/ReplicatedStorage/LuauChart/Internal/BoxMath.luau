--!strict
--!native
--!optimize 2
-- BoxMath (Helper): box plot geometry shared by both box renderers. Slot sizing, data-space extents, colors
-- with the hover highlight, and the bounds padding.

local BoxMath = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Item = {
	Key: number,
	Entry: any,
	Index: number,
	X0: number, -- data-space extent of the body along the index axis
	X1: number,
	Y0: number, -- whisker span along the value axis, Y0 <= Y1
	Y1: number,
	CapX0: number,
	CapX1: number,
}

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Smallest gap between neighbouring boxes, in Index units
function BoxMath.Slot(Boxes: { any }): number
	local Slot = math.huge
	for Position = 2, #Boxes do
		const Gap: number = Boxes[Position].Index - Boxes[Position - 1].Index
		if Gap > 0 and Gap < Slot then
			Slot = Gap
		end
	end
	return if Slot == math.huge then 1 else Slot
end

-- Items carry the box body in X0..X1 and the whisker span in Y0..Y1, which is what BarMath.Slots reads
function BoxMath.Layout(Graph: any): ({ Item }, number)
	const Boxes: { any } = Graph.Boxes or {}
	const Slot = BoxMath.Slot(Boxes)
	const HalfBody = Slot * (Graph.BodyRatio or 0.5) / 2
	const HalfCap = HalfBody * (Graph.CapRatio or 0.5)

	const Items: { Item } = (table.create(#Boxes)::any)
	for Position, Entry in Boxes do
		const Index: number = Entry.Index
		Items[Position] = {
			Key = Position,
			Entry = Entry,
			Index = Index,
			X0 = Index - HalfBody,
			X1 = Index + HalfBody,
			Y0 = Entry.Low,
			Y1 = Entry.High,
			CapX0 = Index - HalfCap,
			CapX1 = Index + HalfCap,
		}
	end
	return Items, Slot
end

function BoxMath.Color(Graph: any, Item: Item): Color3
	const Base: Color3 = Item.Entry.Color or Graph.Color or WHITE
	const Hover = Graph.Hover
	if Hover then
		const Amount: number = Hover:GetAlpha(Item.Key) * (Hover.Highlight or 0.3)
		if Amount > 0 then
			return Base:Lerp(WHITE, math.clamp(Amount, 0, 1))
		end
	end
	return Base
end

-- Called by Cartesian in data axes: half a slot on the index axis, headroom on the value axis
function BoxMath.AdjustBounds(Graph: any, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	const Half = BoxMath.Slot(Graph.Boxes or {}) * 0.5
	const Headroom = (Graph.Headroom or 0.08) * (MaxY - MinY)
	return MinX - Half, MaxX + Half, MinY - Headroom, MaxY + Headroom
end

return BoxMath
