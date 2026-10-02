--!strict
--!native
--!optimize 2
-- PieMath (Helper): slice geometry shared by both pie renderers. Screen angles honor StartAngle, Clockwise,
-- Reveal (entry animation) and hover offsets. Angle 0 points up and angles increase clockwise on screen.

local PieMath = {}

-- ─── Just that ngl ───────────────────────────────────────────────────────────

const TAU = math.pi * 2

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Slice = {
	Data: any,
	Index: number,
	Start: number, -- screen-space start angle, radians
	Sweep: number, -- radians
	Bisector: number,
	Fraction: number, -- share of the total for the full slice, not the revealed part
	Value: number,
	Total: number,
	Offset: number, -- explode distance in pixels, hover included
	Scale: number, -- radius share, 1 on pies; on rose charts the value over the largest value
}

-- ─── API ─────────────────────────────────────────────────────────────────────

function PieMath.Slices(Graph: any): ({ Slice }, number)
	const Data: { any } = Graph.Data
	local Total = 0
	local Largest = 0
	for _, Slice in Data do
		const Value: number = Slice.Value
		Total += math.max(Value, 0)
		Largest = math.max(Largest, Value)
	end
	if Total <= 0 then
		return {}, 0
	end

	-- Rose charts give every slice the same angle and carry the value in the radius
	const Rose = Graph.Rose == true

	const StartRadians = math.rad(Graph.StartAngle or 0)
	const Clockwise = Graph.Clockwise ~= false
	const Reveal = math.clamp(Graph.Reveal or 1, 0, 1)
	const DefaultOffset: number = (Graph.Renderer and Graph.Renderer.DefaultOffset) or 0
	const Hover = Graph.Hover

	local Output: { Slice } = {}
	local Current = 0
	for Index, Slice in Data do
		const Value: number = Slice.Value
		const Fraction = math.max(Value, 0) / Total
		const FullSweep = if Rose then TAU / #Data else Fraction * TAU
		const Sweep = math.min(FullSweep, Reveal * TAU - Current)
		if Sweep <= 1e-6 then
			break
		end

		const ScreenStart = if Clockwise then StartRadians + Current else StartRadians - Current - Sweep
		const Offset: number = (Slice.Offset or DefaultOffset) + (if Hover then Hover:GetOffset(Index) else 0)

		table.insert(Output, {
			Data = Slice,
			Index = Index,
			Start = ScreenStart % TAU,
			Sweep = Sweep,
			Bisector = ScreenStart + Sweep / 2,
			Fraction = Fraction,
			Value = Value,
			Total = Total,
			Offset = Offset,
			Scale = if Rose then math.max(Value, 0) / Largest else 1,
		})

		Current += FullSweep
	end

	return Output, Total
end

-- Unit direction on screen (Y down) for a screen angle
function PieMath.Dir(Angle: number): Vector2
	return Vector2.new(math.sin(Angle), -math.cos(Angle))
end

return PieMath
