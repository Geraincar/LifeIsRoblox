--!strict
--!native
--!optimize 2
-- Indicators (Helper): moving averages over candle lists, as line series points for Candle.Overlays.
-- The first Period - 1 entries have no value, so they draw as a gap.

local Indicators = {}

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Simple moving average of Key (Close by default)
function Indicators.SMA(Candles, Period: number, Key: string?)
	const Field = Key or "Close"
	const Points = table.create(#Candles)
	local Sum = 0
	for Position, Entry in Candles do
		Sum += Entry[Field]
		if Position > Period then
			Sum -= Candles[Position - Period][Field]
		end
		Points[Position] = { Index = Entry.Index, Value = if Position >= Period then Sum / Period else nil }
	end
	return Points
end

-- Exponential moving average of Key, seeded with the simple average of the first Period entries
function Indicators.EMA(Candles, Period: number, Key: string?)
	const Field = Key or "Close"
	const Weight = 2 / (Period + 1)
	const Points = table.create(#Candles)
	local Average = 0
	local Sum = 0
	for Position, Entry in Candles do
		const Value: number = Entry[Field]
		if Position < Period then
			Sum += Value
			Points[Position] = { Index = Entry.Index }
		else
			Average = Position == Period and (Sum + Value) / Period or (Value - Average) * Weight + Average
			Points[Position] = { Index = Entry.Index, Value = Average }
		end
	end
	return Points
end

return Indicators
