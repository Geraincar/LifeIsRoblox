--!strict
--!native
--!optimize 2
-- CandleMath (Helper): candle geometry shared by both candle renderers. Slot sizing, data-space extents
-- for bodies and wicks, colors with the hover highlight, and the bounds padding.

local CandleMath = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Item = {
	Key: number,
	Entry: any,
	Index: number,
	X0: number, -- data-space extent of the body along the index axis
	X1: number,
	BodyLow: number,
	BodyHigh: number,
	Low: number,
	High: number,
	Up: boolean,
}

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Smallest gap between neighbouring candles, in Index units
function CandleMath.Slot(Candles: { any }): number
	local Slot = math.huge
	for Position = 2, #Candles do
		const Gap: number = Candles[Position].Index - Candles[Position - 1].Index
		if Gap > 0 and Gap < Slot then
			Slot = Gap
		end
	end
	return if Slot == math.huge then 1 else Slot
end

function CandleMath.Layout(Graph: any): ({ Item }, number)
	const Candles: { any } = Graph.Candles or {}
	const Slot = CandleMath.Slot(Candles)
	const HalfBody = Slot * (Graph.BodyRatio or 0.6) / 2

	const Items: { Item } = (table.create(#Candles)::any)
	for Position, Entry in Candles do
		const Index: number = Entry.Index
		const Open: number, Close: number = Entry.Open, Entry.Close
		Items[Position] = {
			Key = Position,
			Entry = Entry,
			Index = Index,
			X0 = Index - HalfBody,
			X1 = Index + HalfBody,
			BodyLow = math.min(Open, Close),
			BodyHigh = math.max(Open, Close),
			Low = Entry.Low,
			High = Entry.High,
			Up = Close >= Open,
		}
	end
	return Items, Slot
end

-- Fill color for a candle with the hover highlight applied
function CandleMath.Color(Graph: any, Item: Item): Color3
	const Entry = Item.Entry
	const Base: Color3 = Entry.Color or (if Item.Up then Graph.UpColor else Graph.DownColor) or WHITE

	const Hover = Graph.Hover
	if Hover then
		const Amount: number = Hover:GetAlpha(Item.Key) * (Hover.Highlight or 0.3)
		if Amount > 0 then
			return Base:Lerp(WHITE, math.clamp(Amount, 0, 1))
		end
	end
	return Base
end

-- Called by Cartesian in data axes: pads the index axis by half a slot so the outer candles keep their
-- width, and the price axis by the headroom
function CandleMath.AdjustBounds(Graph: any, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	const Half = CandleMath.Slot(Graph.Candles or {}) * 0.5
	const Headroom = (Graph.Headroom or 0.05) * (MaxY - MinY)
	return MinX - Half, MaxX + Half, MinY - Headroom, MaxY + Headroom
end

return CandleMath
