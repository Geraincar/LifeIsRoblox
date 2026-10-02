--!strict
--!native
--!optimize 2
-- Stacking (Helper): series arrangement for line charts. Draw order from ZIndex, and stacked tops for
-- area charts: every series is resampled on the union of all indices, gaps count as zero, and the base of
-- the first series is zero for "Stacked" or minus half the total for "Stream", which centers the silhouette.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Types = require(script.Parent.Parent.Types)

local Stacking = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

type Point = Types.RenderPoint
type Series = { [string]: any }

export type Result = {
	Tops: { { Point } },
	Base: { Point },
}

-- ─── Internal ────────────────────────────────────────────────────────────────

-- Linear interpolation of a point field at Index; gaps and indices outside the series count as zero
const function FieldAt(Points: { Point }, Index: number, Key: string): number
	const Count = #Points
	if Count == 0 or Index < Points[1].Index or Index > Points[Count].Index then
		return 0
	end

	local Low, High = 1, Count
	while Low < High do
		const Mid = (Low + High + 1) // 2
		if Points[Mid].Index <= Index then
			Low = Mid
		else
			High = Mid - 1
		end
	end

	const Before = Points[Low]
	if Before.Index == Index or Low == Count then
		return Before[Key] or 0
	end
	const After = Points[Low + 1]
	const BeforeValue, AfterValue = Before[Key], After[Key]
	if BeforeValue == nil or AfterValue == nil then
		return 0
	end
	return math.lerp(BeforeValue, AfterValue, (Index - Before.Index) / (After.Index - Before.Index))
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Series indices in drawing order: ascending ZIndex, series order breaking ties
function Stacking.Order(SeriesList: { Series }): { number }
	const Order = (table.create(#SeriesList)::any)
	for Index = 1, #SeriesList do
		Order[Index] = Index
	end
	table.sort(Order, function(Left: number, Right: number)
		const LeftZ: number = SeriesList[Left].ZIndex or Left
		const RightZ: number = SeriesList[Right].ZIndex or Right
		if LeftZ == RightZ then
			return Left < Right
		end
		return LeftZ < RightZ
	end)
	return Order
end

-- Tops[SeriesIndex] is the series' upper edge on the shared grid ({ Index, Value, Raw, Envelope }), Base the
-- lower edge of the first series; each further series sits on the top of the one before it
function Stacking.Resolve(SeriesList: { Series }, Mode: string): Result
	const Grid: { number } = {}
	const Seen: { [number]: boolean } = {}
	for _, Series in SeriesList do
		const Points: { Point } = Series.Points
		for _, Point in Points do
			if not Seen[Point.Index] then
				Seen[Point.Index] = true
				table.insert(Grid, Point.Index)
			end
		end
	end
	table.sort(Grid)

	const Count = #SeriesList
	const Raw: { { number } } = (table.create(Count)::any)
	for SeriesIndex, Series in SeriesList do
		const Points: { Point } = Series.Points
		const Values = (table.create(#Grid)::any)
		for Position, Index in Grid do
			Values[Position] = FieldAt(Points, Index, "Value")
		end
		Raw[SeriesIndex] = Values
	end

	const Base: { Point } = (table.create(#Grid)::any)
	for Position, Index in Grid do
		local Total = 0
		for SeriesIndex = 1, Count do
			Total += Raw[SeriesIndex][Position]
		end
		Base[Position] = { Index = Index, Value = if Mode == "Stream" then -Total / 2 else 0 }
	end

	const Tops: { { Point } } = (table.create(Count)::any)
	local Below = Base
	for SeriesIndex, Series in SeriesList do
		const Points: { Point } = Series.Points
		const Top: { Point } = (table.create(#Grid)::any)
		for Position, Index in Grid do
			const Value = Raw[SeriesIndex][Position]
			const Envelope = FieldAt(Points, Index, "Envelope")
			Top[Position] = {
				Index = Index,
				Value = (Below[Position].Value or 0) + Value,
				Raw = Value,
				Envelope = if Envelope ~= 0 then Envelope else nil,
			}
		end
		Tops[SeriesIndex] = Top
		Below = Top
	end

	return { Tops = Tops, Base = Base }
end

return Stacking
