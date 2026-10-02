--!strict
--!native
--!optimize 2
-- Sampling (Helper): turns raw points into the points a renderer draws (curves, steps), splits polylines into
-- dash pieces, thins markers, simplifies polylines, and keeps gaps: a point whose Value is nil breaks the line.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Types = require(script.Parent.Parent.Types)

local Sampling = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Point = Types.RenderPoint

-- ─── Internal ────────────────────────────────────────────────────────────────

const function IsGap(Point: Point): boolean
	return Point.Value == nil
end

-- Runs never hold gaps, so a missing Value only means an edge point outside the data
const function ValueOf(Point: Point): number
	return Point.Value or 0
end

const function CatmullRom(Before: number, Start: number, Finish: number, After: number, Time: number): number
	const Time2, Time3 = Time * Time, Time * Time * Time
	return 0.5 * (
		(2 * Start) +
			(-Before + Finish) * Time +
			(2 * Before - 5 * Start + 4 * Finish - After) * Time2 +
			(-Before + 3 * Start - 3 * Finish + After) * Time3
	)
end

const function PointAt(Points: { Point }, Index: number): Point
	return Points[math.clamp(Index, 1, #Points)]
end

const function Curve(Points: { Point }, Steps: number): { Point }
	local Sampled: { Point } = {}
	for Index = 1, #Points - 1 do
		const Before = PointAt(Points, Index - 1)
		const Start, Finish = Points[Index], Points[Index + 1]
		const After = PointAt(Points, Index + 2)
		const StartValue, FinishValue = ValueOf(Start), ValueOf(Finish)
		const StartRaw, FinishRaw = Start.Raw, Finish.Raw

		for Step = 0, Steps - 1 do
			const Time = Step / Steps
			-- Samples are clamped to the segment so the curve never overshoots its control points
			const SampleIndex = math.clamp(
				CatmullRom(Before.Index, Start.Index, Finish.Index, After.Index, Time),
				math.min(Start.Index, Finish.Index), math.max(Start.Index, Finish.Index)
			)
			const SampleValue = math.clamp(
				CatmullRom(ValueOf(Before), StartValue, FinishValue, ValueOf(After), Time),
				math.min(StartValue, FinishValue), math.max(StartValue, FinishValue)
			)
			table.insert(Sampled::any, { -- ::any cuz warns
				Index = SampleIndex,
				Value = SampleValue,
				Envelope = math.lerp(Start.Envelope or 0, Finish.Envelope or 0, Time),
				Raw = if StartRaw ~= nil and FinishRaw ~= nil then math.lerp(StartRaw, FinishRaw, Time) else nil,
			})
		end
	end
	table.insert(Sampled, Points[#Points])
	return Sampled
end

-- Staircase: every value holds until the next point's Index
const function Step(Points: { Point }): { Point }
	local Output: { Point } = {}
	for Index = 1, #Points - 1 do
		const Current, Next = Points[Index], Points[Index + 1]
		table.insert(Output, Current)
		table.insert(Output::any, { Index = Next.Index, Value = Current.Value, Envelope = Current.Envelope, Raw = Current.Raw })
	end
	table.insert(Output, Points[#Points])
	return Output
end

const function ResolveRun(Points: { Point }, Style: string?, Steps: number?): { Point }
	if #Points < 2 then
		return Points
	end
	if Style == "Curve" then
		return Curve(Points, math.max(Steps or 8, 1))
	elseif Style == "Step" then
		return Step(Points)
	end
	return Points
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- The points of one edge of a range series (Key "Low" or "High") as plain points; missing edges are gaps
function Sampling.Edge(Points: { Point }, Key: string): { Point }
	const Output = table.create(#Points)
	for Position, Point in Points do
		Output[Position] = { Index = Point.Index, Value = Point[Key] }
	end
	return Output::any
end

-- Runs of consecutive real points; gaps separate runs and are dropped
function Sampling.Runs(Points: { Point }): { { Point } }
	local Runs: { { Point } } = {}
	local Run: { Point } = {}
	for _, Point in Points do
		if IsGap(Point) then
			if #Run > 0 then
				table.insert(Runs, Run)
				Run = {}
			end
		else
			table.insert(Run, Point)
		end
	end
	if #Run > 0 then
		table.insert(Runs, Run)
	end
	return Runs
end

-- Every run resolved with the style; gap points stay in place so the result is still sorted by Index
function Sampling.Resolve(Points: { Point }, Style: string?, Steps: number?): { Point }
	local Output: { Point } = {}
	local Run: { Point } = {}

	const function Flush()
		if #Run > 0 then
			for _, Point in ResolveRun(Run, Style, Steps) do
				table.insert(Output, Point)
			end
			Run = {}
		end
	end

	for _, Point in Points do
		if IsGap(Point) then
			Flush()
			table.insert(Output, Point)
		else
			table.insert(Run, Point)
		end
	end
	Flush()

	return Output
end

-- The "on" pieces of a dash pattern along a polyline, as { {Start, Finish}, ... } in the points' space.
-- Points are Vector2 pixels or Vector3 world positions. Pattern lengths are pixels; Scale is how many
-- pixels one unit of the points is (1 for pixel-space points).
function Sampling.Dash(Points: { any }, Pattern: { number }, Scale: number?): { { any } }
	local Pieces: { { any } } = {}
	const PixelsPerUnit = Scale or 1

	local Lengths: { number } = {}
	local Total = 0
	for _, Length in Pattern do
		const Clean = math.max(Length, 0)
		table.insert(Lengths, Clean)
		Total += Clean
	end
	-- Odd patterns repeat, like SVG
	if #Lengths % 2 == 1 then
		for Index = 1, #Lengths do
			table.insert(Lengths, Lengths[Index])
		end
		Total *= 2
	end
	if #Lengths == 0 or Total <= 0 then
		for Index = 1, #Points - 1 do
			table.insert(Pieces, { Points[Index], Points[Index + 1] })
		end
		return Pieces
	end

	const Count = #Lengths
	local PatternIndex = 1
	local Remaining = Lengths[1] / PixelsPerUnit

	for Index = 1, #Points - 1 do
		const Start: any, Finish: any = Points[Index], Points[Index + 1]
		const Delta = Finish - Start
		const Length: number = Delta.Magnitude
		local Position = 0
		local Guard = 0
		while Position < Length and Guard < 10000 do
			Guard += 1
			const Run = math.min(Remaining, Length - Position)
			if PatternIndex % 2 == 1 and Run > 0 then
				table.insert(Pieces, { Start + Delta * (Position / Length), Start + Delta * ((Position + Run) / Length) })
			end
			Position += Run
			Remaining -= Run
			if Remaining <= 1e-6 then
				PatternIndex = PatternIndex % Count + 1
				Remaining = Lengths[PatternIndex] / PixelsPerUnit
			end
		end
	end

	return Pieces
end

-- Marker thinning for dense series: with Spacing, one point per Spacing pixel cell survives (the first),
-- then Limit keeps at most that many points spread evenly. Gaps are dropped. Either rule may be nil.
function Sampling.Thin(Points: { Point }, ToPixel: (Index: number, Value: number) -> Vector2, Spacing: number?, Limit: number?): { Point }
	local Output = Points
	if Spacing and Spacing > 0 then
		const Seen: { [number]: boolean } = {}
		const Kept: { Point } = {}
		for _, Point in Points do
			const Value = Point.Value
			if Value ~= nil then
				const Pixel = ToPixel(Point.Index, Value)
				-- One integer per cell, with room for negative and off-image coordinates
				const Key = (math.floor(Pixel.X / Spacing) + 65536) * 131072 + (math.floor(Pixel.Y / Spacing) + 65536)
				if not Seen[Key] then
					Seen[Key] = true
					table.insert(Kept, Point)
				end
			end
		end
		Output = Kept
	end
	if Limit and Limit > 0 and #Output > Limit then
		const Stride = #Output / Limit
		const Kept = table.create(Limit)
		for Position = 1, Limit do
			Kept[Position] = Output[math.floor((Position - 1) * Stride) + 1]
		end
		Output = Kept
	end
	return Output
end

-- Polyline simplification (Ramer-Douglas-Peucker): the indices of the points that keep the polyline within
-- Tolerance of the original, in order; the first and last point always stay. Points are Vector2 or Vector3.
function Sampling.SimplifyIndices(Points: { any }, Tolerance: number): { number }
	const Count = #Points
	const Indices: { number } = {}
	if Count <= 2 or Tolerance <= 0 then
		for Index = 1, Count do
			Indices[Index] = Index
		end
		return Indices
	end

	const Keep: { boolean } = table.create(Count, false)
	Keep[1], Keep[Count] = true, true
	const Tolerance2 = Tolerance * Tolerance
	const Stack: { number } = { 1, Count }

	while #Stack > 0 do
		const Last = table.remove(Stack) :: number
		const First = table.remove(Stack) :: number
		const Start: any, Finish: any = Points[First], Points[Last]
		const Direction = Finish - Start
		const Length2: number = Direction:Dot(Direction)

		-- The point farthest from the chord splits the span when it sits outside the tolerance
		local Farthest, Farthest2 = 0, Tolerance2
		for Index = First + 1, Last - 1 do
			const Offset = Points[Index] - Start
			local Distance2: number
			if Length2 > 0 then
				const Along = math.clamp(Offset:Dot(Direction) / Length2, 0, 1)
				const Perpendicular = Offset - Direction * Along
				Distance2 = Perpendicular:Dot(Perpendicular)
			else
				Distance2 = Offset:Dot(Offset)
			end
			if Distance2 > Farthest2 then
				Farthest, Farthest2 = Index, Distance2
			end
		end

		if Farthest > 0 then
			Keep[Farthest] = true
			table.insert(Stack, First)
			table.insert(Stack, Farthest)
			table.insert(Stack, Farthest)
			table.insert(Stack, Last)
		end
	end

	for Index = 1, Count do
		if Keep[Index] then
			table.insert(Indices, Index)
		end
	end
	return Indices
end

-- The simplified polyline itself
function Sampling.Simplify(Points: { any }, Tolerance: number): { any }
	const Indices = Sampling.SimplifyIndices(Points, Tolerance)
	const Output = table.create(#Indices)
	for Position, Index in Indices do
		Output[Position] = Points[Index]
	end
	return Output
end

return Sampling
