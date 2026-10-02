--!strict
--!native
--!optimize 2
-- Statistics (Helper): turns raw samples into chart entries. Histogram bins, a linear regression line and
-- box plot summaries.

local Statistics = {}

-- ─── Internal ────────────────────────────────────────────────────────────────

-- Linear interpolation between order statistics, the common quantile definition
const function Quantile(Sorted: { number }, Fraction: number): number
	const Count = #Sorted
	if Count == 0 then
		return 0
	end
	const Position = 1 + (Count - 1) * Fraction
	const Lower = math.floor(Position)
	const Upper = math.min(Lower + 1, Count)
	return math.lerp(Sorted[Lower], Sorted[Upper], Position - Lower)
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Bar entries counting the values per bin; Index is the bin center, Label the bin range
function Statistics.Histogram(Values: { number }, Bins: number, Min: number?, Max: number?)
	local Low, High = Min or math.huge, Max or -math.huge
	if Min == nil or Max == nil then
		for _, Value in Values do
			if Min == nil and Value < Low then Low = Value end
			if Max == nil and Value > High then High = Value end
		end
	end
	if #Values == 0 or High <= Low then
		return {}
	end

	const Count = math.max(math.floor(Bins), 1)
	const Width = (High - Low) / Count
	const Counts = table.create(Count, 0)
	for _, Value in Values do
		if Value >= Low and Value <= High then
			-- The top edge belongs to the last bin
			const Bin = math.min(math.floor((Value - Low) / Width) + 1, Count)
			Counts[Bin] += 1
		end
	end

	const Entries = table.create(Count)
	for Bin = 1, Count do
		const Start = Low + (Bin - 1) * Width
		Entries[Bin] = {
			Index = Start + Width / 2,
			Value = Counts[Bin],
			Label = string.format("%g to %g", Start, Start + Width),
			Metadata = { Start = Start, Finish = Start + Width },
		}
	end
	return Entries
end

-- Least squares line through the points that have a Value: two end points plus the slope and intercept
function Statistics.Regression(Points): ({ { Index: number, Value: number } }, number, number)
	local Count, SumX, SumY, SumXY, SumXX = 0, 0, 0, 0, 0
	local MinX, MaxX = math.huge, -math.huge
	for _, Point in Points do
		const Value = Point.Value
		if Value ~= nil then
			Count += 1
			SumX += Point.Index
			SumY += Value
			SumXY += Point.Index * Value
			SumXX += Point.Index * Point.Index
			if Point.Index < MinX then MinX = Point.Index end
			if Point.Index > MaxX then MaxX = Point.Index end
		end
	end
	if Count < 2 then
		return {}, 0, 0
	end
	const Denominator = Count * SumXX - SumX * SumX
	const Slope = if Denominator == 0 then 0 else (Count * SumXY - SumX * SumY) / Denominator
	const Intercept = (SumY - Slope * SumX) / Count
	return {
		{ Index = MinX, Value = Intercept + Slope * MinX },
		{ Index = MaxX, Value = Intercept + Slope * MaxX },
	}, Slope, Intercept
end

-- Five number summary with Tukey fences: whiskers reach the last values within 1.5 IQR, the rest are outliers
function Statistics.Box(Values: { number }, Index: number?, Label: string?)
	const Sorted = table.clone(Values)
	table.sort(Sorted)
	const Q1, Median, Q3 = Quantile(Sorted, 0.25), Quantile(Sorted, 0.5), Quantile(Sorted, 0.75)
	const Fence = (Q3 - Q1) * 1.5
	local Low, High = math.huge, -math.huge
	const Outliers = {}
	for _, Value in Sorted do
		if Value < Q1 - Fence or Value > Q3 + Fence then
			table.insert(Outliers, Value)
		else
			if Value < Low then Low = Value end
			if Value > High then High = Value end
		end
	end
	if Low == math.huge then
		Low, High = Q1, Q3
	end
	return { Index = Index or 1, Label = Label, Low = Low, Q1 = Q1, Median = Median, Q3 = Q3, High = High, Outliers = Outliers }
end

return Statistics
