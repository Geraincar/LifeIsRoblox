--!strict
--!native
--!optimize 2
-- BarMath (Helper): bar geometry shared by both bar renderers. Slot sizing, grouped and stacked placement in
-- data space, colors with the hover highlight, value labels and per-slot geometry for category labels. Data
-- space is (Index, Value); renderers map it to the screen through Graph:_ToScreenAxes, which is what makes
-- horizontal charts work.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Types = require(script.Parent.Parent.Types)

local BarMath = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const HALF = Vector2.new(0.5, 0.5)
const MIN_RATIO = 0.25 -- the room category labels take never shrinks the bars below this share of a slot

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Item = {
	Key: string,
	Entry: any,
	Series: number,
	SeriesData: any,
	Index: number,
	X0: number, -- data-space extent along the index axis
	X1: number,
	Y0: number, -- data-space extent along the value axis, Y0 <= Y1
	Y1: number,
	Negative: boolean,
}

export type Totals = {
	Positive: { [number]: number },
	Negative: { [number]: number },
}

type Projector = (number, number) -> Vector2

-- ─── Internal ────────────────────────────────────────────────────────────────

-- Pixel rectangle of a data-space rectangle, through an orientation-aware projector
const function PixelRect(ToPixel: Projector, X0: number, Y0: number, X1: number, Y1: number): (number, number, number, number)
	const CornerA, CornerB = ToPixel(X0, Y0), ToPixel(X1, Y1)
	return math.min(CornerA.X, CornerB.X), math.min(CornerA.Y, CornerB.Y), math.max(CornerA.X, CornerB.X), math.max(CornerA.Y, CornerB.Y)
end

-- Growth is the unit pixel vector the bar grows along, so "End" of a negative bar on a horizontal chart is
-- its left end. Returns the label position and anchor.
const function Place(Placement: string, Center: Vector2, StartPoint: Vector2, EndPoint: Vector2, Growth: Vector2, Offset: number): (Vector2, Vector2)
	if Placement == "InsideEnd" then
		return EndPoint - Growth * Offset, HALF + Growth * 0.5
	elseif Placement == "Center" then
		return Center, HALF
	elseif Placement == "InsideStart" then
		return StartPoint + Growth * Offset, HALF - Growth * 0.5
	elseif Placement == "Start" then
		return StartPoint - Growth * Offset, HALF + Growth * 0.5
	end
	return EndPoint + Growth * Offset, HALF - Growth * 0.5
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Smallest gap between neighbouring bar slots across every series, in Index units
function BarMath.Slot(SeriesList: { any }): number
	const Indices: { number } = {}
	const Seen: { [number]: boolean } = {}
	for _, Series in SeriesList do
		for _, Bar in Series.Bars do
			const Index: number = Bar.Index
			if not Seen[Index] then
				Seen[Index] = true
				table.insert(Indices, Index)
			end
		end
	end
	table.sort(Indices)

	local Slot = math.huge
	for Position = 2, #Indices do
		const Gap = Indices[Position] - Indices[Position - 1]
		if Gap > 0 and Gap < Slot then
			Slot = Gap
		end
	end
	return if Slot == math.huge then 1 else Slot
end

-- Data-space rectangles for every bar. Returns the items, the per-slot stack totals, the mode in effect, the
-- slot size and the bar ratio in effect. SlotPixels, the length of one slot on screen, lets category labels
-- between the slots reserve their room: the bars shrink, staying centered on their slot, when BarRatio would
-- leave less than the labels need.
function BarMath.Layout(Graph: any, SlotPixels: number?): ({ Item }, Totals, string, number, number)
	const SeriesList: { any } = Graph.Series or {}
	const Count = #SeriesList
	const Mode: string = if Count > 1 then (Graph.Mode or "Grouped") else "Single"
	const Slot = BarMath.Slot(SeriesList)

	local Ratio: number = Graph.BarRatio or 0.8
	const Categories = Graph.Categories
	if SlotPixels and SlotPixels > 0 and Categories and (Categories.SlotReserve::any) then
		const Reserve: number = Categories:SlotReserve()
		if Reserve > 0 then
			Ratio = math.min(Ratio, math.max(1 - 2 * Reserve / SlotPixels, MIN_RATIO))
		end
	end
	const SlotWidth = Slot * Ratio

	const Items: { Item } = {}
	const Totals: Totals = { Positive = {}, Negative = {} }

	-- Grouped bars run in series order: left to right on vertical charts, top to bottom on horizontal ones.
	-- Higher slot values sit higher on screen, so the order is mirrored there.
	const Horizontal = Graph.Orientation == "Horizontal"

	for SeriesIndex, Series in SeriesList do
		for EntryIndex, Entry in Series.Bars do
			const Value: number? = Entry.Value
			if Value == nil then
				continue
			end
			const Index: number = Entry.Index

			local X0, X1
			if Mode == "Grouped" then
				const Sub = SlotWidth / Count
				const Inner = Sub * (1 - (Graph.GroupSpacing or 0.15))
				const Position = if Horizontal then Count - SeriesIndex + 1 else SeriesIndex
				const SubCenter = Index - SlotWidth / 2 + Sub * (Position - 0.5)
				X0, X1 = SubCenter - Inner / 2, SubCenter + Inner / 2
			else
				X0, X1 = Index - SlotWidth / 2, Index + SlotWidth / 2
			end

			-- A floating bar starts at its own Base; stacks ignore it
			local Base: number, Top: number = Entry.Base or 0, Value
			if Mode == "Stacked" then
				const Bucket = if Value >= 0 then Totals.Positive else Totals.Negative
				Base = Bucket[Index] or 0
				Top = Base + Value
				Bucket[Index] = Top
			end

			table.insert(Items, {
				Key = `{SeriesIndex}_{EntryIndex}`,
				Entry = Entry,
				Series = SeriesIndex,
				SeriesData = Series,
				Index = Index,
				X0 = X0,
				X1 = X1,
				Y0 = math.min(Base, Top),
				Y1 = math.max(Base, Top),
				Negative = Top < Base,
			})
		end
	end

	return Items, Totals, Mode, Slot, Ratio
end

-- Fill color for a bar with the hover highlight applied
function BarMath.Color(Graph: any, Item: Item): Color3
	const Entry = Item.Entry
	const Base: Color3 = Entry.Color or Item.SeriesData.Color or (if Item.Negative then Graph.NegativeColor else nil) or WHITE

	const Hover = Graph.Hover
	if Hover then
		const Amount: number = Hover:GetAlpha(Item.Key) * (Hover.Highlight or 0.3)
		if Amount > 0 then
			return Base:Lerp(WHITE, math.clamp(Amount, 0, 1))
		end
	end
	return Base
end

-- Value labels: one per bar (or per stacked segment), plus stack totals when Labels.Totals is on.
-- ToPixel maps data space (Index, Value) to chart pixels and must already honor the orientation. Ratio is the
-- bar ratio Layout settled on.
function BarMath.Labels(Graph: any, Items: { Item }, Totals: Totals, Mode: string, Slot: number, ToPixel: Projector, Ratio: number?): { Types.LabelItem }
	const Labels = Graph.Labels
	if not (Labels and Labels.Enabled) then
		return {}
	end

	const Horizontal = Graph.Orientation == "Horizontal"
	const Orientation = if Horizontal then "Horizontal" else "Vertical"
	const Stacked = Mode == "Stacked"
	const Output: { Types.LabelItem } = {}

	const function Emit(Entry: any, Info: { [string]: any }, Overrides: any, DefaultPlacement: string, Left: number, Top: number, Right: number, Bottom: number, Negative: boolean)
		const Direction = if Negative then -1 else 1
		const Growth = if Horizontal then Vector2.new(Direction, 0) else Vector2.new(0, -Direction)
		Info.Rect = { Left, Top, Right, Bottom }
		Info.Direction = Growth
		Info.Orientation = Orientation

		const Spec: Types.ResolvedLabel? = Labels:Resolve(Entry, Info, Overrides)
		if not Spec then
			return
		end

		const Center = Vector2.new((Left + Right) / 2, (Top + Bottom) / 2)
		const HalfLength = if Horizontal then (Right - Left) / 2 else (Bottom - Top) / 2
		const EndPoint = Center + Growth * HalfLength
		const StartPoint = Center - Growth * HalfLength

		local Position, Anchor = Place(Spec.Placement or DefaultPlacement, Center, StartPoint, EndPoint, Growth, Spec.Offset)
		if Spec.Position then Position = Spec.Position end
		if Spec.Anchor then Anchor = Spec.Anchor end
		if Spec.Nudge then Position += Spec.Nudge end

		table.insert(Output, { Position = Position, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
	end

	if not Stacked or Labels.Segments ~= false then
		for _, Item in Items do
			const Left, Top, Right, Bottom = PixelRect(ToPixel, Item.X0, Item.Y0, Item.X1, Item.Y1)
			Emit(Item.Entry, {
				Index = Item.Index,
				Value = Item.Entry.Value,
				Series = Item.Series,
				SeriesData = Item.SeriesData,
				Negative = Item.Negative,
				Stacked = Stacked,
			}, Item.SeriesData.Labels, if Stacked then "InsideEnd" else "End", Left, Top, Right, Bottom, Item.Negative)
		end
	end

	if Stacked and Labels.Totals then
		const HalfSlot = Slot * (Ratio or Graph.BarRatio or 0.8) / 2
		for _, Bucket in { Totals.Positive, Totals.Negative } do
			for Index, Total in Bucket do
				if Total ~= 0 then
					const Left, Top, Right, Bottom = PixelRect(ToPixel, Index - HalfSlot, 0, Index + HalfSlot, Total)
					Emit({ Index = Index, Value = Total }, {
						Index = Index,
						Value = Total,
						Total = Total,
						Negative = Total < 0,
						Stacked = true,
						IsTotal = true,
					}, nil, "End", Left, Top, Right, Bottom, Total < 0)
				end
			end
		end
	end

	return Output
end

-- Per-slot pixel geometry for category labels: Rect is the union of the slot's bars, Band the slot's extent
-- on the slot axis. Also returns the pixel coordinate of value zero along the bars.
function BarMath.Slots(Graph: any, Items: { Item }, Slot: number, ToPixel: Projector): ({ [number]: Types.Slot }, number)
	const Horizontal = Graph.Orientation == "Horizontal"
	const HalfSlot = Slot / 2
	const Slots: { [number]: Types.Slot } = {}

	for _, Item in Items do
		const Left, Top, Right, Bottom = PixelRect(ToPixel, Item.X0, Item.Y0, Item.X1, Item.Y1)
		local SlotEntry = Slots[Item.Index]
		if not SlotEntry then
			const BandA, BandB = ToPixel(Item.Index - HalfSlot, 0), ToPixel(Item.Index + HalfSlot, 0)
			const Band = if Horizontal
				then { math.min(BandA.Y, BandB.Y), math.max(BandA.Y, BandB.Y) }
				else { math.min(BandA.X, BandB.X), math.max(BandA.X, BandB.X) }
			SlotEntry = { Index = Item.Index, Rect = { Left, Top, Right, Bottom }, Band = Band, Entries = {} }
			Slots[Item.Index] = SlotEntry
		else
			const Rect = SlotEntry.Rect
			Rect[1], Rect[2] = math.min(Rect[1], Left), math.min(Rect[2], Top)
			Rect[3], Rect[4] = math.max(Rect[3], Right), math.max(Rect[4], Bottom)
		end
		table.insert(SlotEntry.Entries, Item.Entry)
	end

	const ZeroPixel = ToPixel(0, 0)
	return Slots, if Horizontal then ZeroPixel.X else ZeroPixel.Y
end

return BarMath
