--!strict
--!native
--!optimize 2
-- Format (Library): ready made text formatters for axis ticks, cursor readouts and labels. Each function
-- returns a formatter that takes a number or an entry table carrying a Value, so one formatter fits
-- Grid.Properties.X.Transform, Cursor.Format.Y and Labels.Format alike. An entry without a Value formats
-- to nil, which skips its label.

local Format = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Formatter = (Value: any, Info: any?) -> string?

-- ─── Internal ────────────────────────────────────────────────────────────────

const function NumberOf(Value: any): number?
	if typeof(Value) == "number" then
		return Value
	end
	if typeof(Value) == "table" then
		const Inner = Value.Value
		return if typeof(Inner) == "number" then Inner else nil
	end
	return nil
end

const function Fixed(Value: number, Decimals: number): string
	const Text = string.format(`%.{math.max(math.floor(Decimals), 0)}f`, Value)
	-- A rounded zero keeps no sign, so axes never show "-0"
	return if tonumber(Text) == 0 then (Text:gsub("^%-", "")) else Text
end

-- Trailing zeros after the point go, then a bare point
const function Trimmed(Text: string): string
	if not Text:find(".", 1, true) then
		return Text
	end
	return (Text:gsub("0+$", ""):gsub("%.$", ""))
end

const function Grouped(Digits: string, Separator: string): string
	const Length = #Digits
	const First = Length % 3
	const Parts = {}
	if First > 0 then
		table.insert(Parts, Digits:sub(1, First))
	end
	for Start = First + 1, Length, 3 do
		table.insert(Parts, Digits:sub(Start, Start + 2))
	end
	return table.concat(Parts, Separator)
end

const function WithGroups(Value: number, Decimals: number, Separator: string, Point: string): string
	const Text = Fixed(math.abs(Value), Decimals)
	const Whole, Fraction = Text:match("^(%d+)%.?(%d*)$")
	local Result = Grouped(Whole or Text, Separator)
	if Fraction and #Fraction > 0 then
		Result ..= Point .. Fraction
	end
	return if Value < 0 and tonumber(Text) ~= 0 then "-" .. Result else Result
end

const function Wrap(Body: (number, any?) -> string): Formatter
	return function(Value: any, Info: any?): string?
		const Number = NumberOf(Value)
		return if Number ~= nil then Body(Number, Info) else nil
	end
end

-- ─── Numbers ─────────────────────────────────────────────────────────────────

-- "1234.57" with a fixed number of decimals (default 0)
function Format.Number(Decimals: number?): Formatter
	const Places = Decimals or 0
	return Wrap(function(Value)
		return Fixed(Value, Places)
	end)
end

-- "%g" style: as many digits as needed, up to Significant (default 6)
function Format.Plain(Significant: number?): Formatter
	const Pattern = `%.{math.clamp(Significant or 6, 1, 17)}g`
	return Wrap(function(Value)
		return string.format(Pattern, Value)
	end)
end

-- "1,234,567.5" with digit groups; Separator and Point default to "," and "."
function Format.Thousands(Decimals: number?, Separator: string?, Point: string?): Formatter
	const Places = Decimals or 0
	const Group = Separator or ","
	const Dot = Point or "."
	return Wrap(function(Value)
		return WithGroups(Value, Places, Group, Dot)
	end)
end

-- "1.2K", "3.4M", "5B", "2T"; Decimals defaults to 1 and trailing zeros are dropped
function Format.Compact(Decimals: number?): Formatter
	const Places = Decimals or 1
	return Wrap(function(Value)
		const Magnitude = math.abs(Value)
		local Scaled, Suffix = Value, ""
		if Magnitude >= 1e12 then
			Scaled, Suffix = Value / 1e12, "T"
		elseif Magnitude >= 1e9 then
			Scaled, Suffix = Value / 1e9, "B"
		elseif Magnitude >= 1e6 then
			Scaled, Suffix = Value / 1e6, "M"
		elseif Magnitude >= 1e3 then
			Scaled, Suffix = Value / 1e3, "K"
		end
		return Trimmed(Fixed(Scaled, Places)) .. Suffix
	end)
end

-- "25%"; OfOne (default true) treats the value as a fraction of one and scales it by 100
function Format.Percent(Decimals: number?, OfOne: boolean?): Formatter
	const Places = Decimals or 0
	const Scale = if OfOne == false then 1 else 100
	return Wrap(function(Value)
		return Fixed(Value * Scale, Places) .. "%"
	end)
end

-- "$1,234.50", "-$5.00"; Decimals defaults to 2
function Format.Currency(Symbol: string, Decimals: number?, Separator: string?, Point: string?): Formatter
	const Places = Decimals or 2
	const Group = Separator or ","
	const Dot = Point or "."
	return Wrap(function(Value)
		const Text = WithGroups(math.abs(Value), Places, Group, Dot)
		return if Value < 0 and tonumber(Fixed(Value, Places)) ~= 0 then "-" .. Symbol .. Text else Symbol .. Text
	end)
end

-- "+12", "-7", "0": the sign always shows, for deltas and waterfalls
function Format.Signed(Decimals: number?): Formatter
	const Places = Decimals or 0
	return Wrap(function(Value)
		const Text = Fixed(Value, Places)
		return if Value > 0 and tonumber(Text) ~= 0 then "+" .. Text else Text
	end)
end

-- ─── Time ────────────────────────────────────────────────────────────────────

-- Seconds since midnight as "09:30" or "09:30:15"; values past a day wrap
function Format.Clock(WithSeconds: boolean?): Formatter
	return Wrap(function(Value)
		const Total = math.floor(Value) % 86400
		const Hours, Minutes, Seconds = Total // 3600, (Total % 3600) // 60, Total % 60
		return if WithSeconds
			then string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
			else string.format("%02d:%02d", Hours, Minutes)
	end)
end

-- Seconds as "3d 04h", "2h 05m", "5m 03s" or "45s"
function Format.Duration(): Formatter
	return Wrap(function(Value)
		const Total = math.floor(math.abs(Value))
		const Sign = if Value < 0 then "-" else ""
		if Total >= 86400 then
			return string.format("%s%dd %02dh", Sign, Total // 86400, (Total % 86400) // 3600)
		elseif Total >= 3600 then
			return string.format("%s%dh %02dm", Sign, Total // 3600, (Total % 3600) // 60)
		elseif Total >= 60 then
			return string.format("%s%dm %02ds", Sign, Total // 60, Total % 60)
		end
		return `{Sign}{Total}s`
	end)
end

-- Unix time through os.date; Pattern defaults to "!%Y-%m-%d" (UTC), see os.date for the codes
function Format.Date(Pattern: string?): Formatter
	const DatePattern = Pattern or "!%Y-%m-%d"
	return Wrap(function(Value)
		return os.date(DatePattern, math.floor(Value))
	end)
end

-- ─── Composition ─────────────────────────────────────────────────────────────

-- Text in front of another formatter's output (Plain when none is given)
function Format.Prefix(Text: string, Inner: Formatter?): Formatter
	const Body = Inner or Format.Plain()
	return function(Value: any, Info: any?): string?
		const Result = Body(Value, Info)
		return if Result ~= nil then Text .. Result else nil
	end
end

-- Text after another formatter's output, for units such as " ms"
function Format.Suffix(Text: string, Inner: Formatter?): Formatter
	const Body = Inner or Format.Plain()
	return function(Value: any, Info: any?): string?
		const Result = Body(Value, Info)
		return if Result ~= nil then Result .. Text else nil
	end
end

-- Whole values become the name at that position in Names, for month or category ticks; others show the
-- Fallback formatter (nothing when none is given)
function Format.Names(Names: { string }, Fallback: Formatter?): Formatter
	return function(Value: any, Info: any?): string?
		const Number = NumberOf(Value)
		if Number == nil then
			return nil
		end
		const Rounded = math.round(Number)
		if math.abs(Number - Rounded) < 1e-6 then
			const Name = Names[Rounded]
			if Name ~= nil then
				return Name
			end
		end
		return if Fallback then Fallback(Value, Info) else nil
	end
end

return Format
