--!strict
--!native
--!optimize 2
-- Animator (Helper): blends datasets for animated transitions. Numeric fields interpolate, everything else
-- comes from the target, and gaps (nil values) stay gaps.

local Animator = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const BLEND_KEYS = { "Value", "Index", "Envelope", "Offset", "Open", "High", "Low", "Close", "Volume", "Q1", "Median", "Q3", "Size", "Base" }

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Entry = { [string]: any }

-- ─── API ─────────────────────────────────────────────────────────────────────

function Animator.BlendEntry(From: Entry?, To: Entry, Alpha: number): Entry
	const Output = table.clone(To)
	if From then
		for _, Key in BLEND_KEYS do
			const FromValue, ToValue = From[Key], To[Key]
			if typeof(FromValue) == "number" and typeof(ToValue) == "number" then
				Output[Key] = FromValue + (ToValue - FromValue) * Alpha
			end
		end
	end
	return Output
end

function Animator.BlendList(From: { Entry }?, To: { Entry }, Alpha: number): { Entry }
	const Output: {Entry} = (table.create(#To)::any)
	for Index, Entry in To do
		Output[Index] = Animator.BlendEntry(if From then From[Index] else nil, Entry, Alpha)
	end
	return Output
end

-- ListKey names the entry list inside a series ("Points" for lines, "Bars" for bars)
function Animator.BlendSeries(From: { Entry }?, To: { Entry }, Alpha: number, ListKey: string?): { Entry }
	const Key = ListKey or "Points"
	const Output: {Entry} = (table.create(#To)::any)
	for Index, Series in To do
		const Copy = table.clone(Series)
		const Source = if From then From[Index] else nil
		Copy[Key] = Animator.BlendList(if Source then Source[Key] else nil, Series[Key], Alpha)
		Output[Index] = Copy
	end
	return Output
end

-- Baseline for entry animations: the same shape as the data with every Value at zero
function Animator.ZeroList(List: { Entry }): { Entry }
	const Output: {Entry} = (table.create(#List)::any)
	for Index, Entry in List do
		const Copy = table.clone(Entry)
		if Copy.Value ~= nil then
			Copy.Value = 0
		end
		if Copy.Envelope then
			Copy.Envelope = 0
		end
		Output[Index] = Copy
	end
	return Output
end

function Animator.ZeroSeries(SeriesList: { Entry }, ListKey: string?): { Entry }
	const Key = ListKey or "Points"
	const Output: {Entry} = (table.create(#SeriesList)::any)
	for Index, Series in SeriesList do
		const Copy = table.clone(Series)
		Copy[Key] = Animator.ZeroList(Series[Key])
		Output[Index] = Copy
	end
	return Output
end

return Animator
