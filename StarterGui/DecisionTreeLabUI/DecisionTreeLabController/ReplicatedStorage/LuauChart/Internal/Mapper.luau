--!strict
--!native
--!optimize 2
-- Mapper (Helper): projects data space (Index, Value) into the chart camera's world or into chart pixels.

local Mapper = {}

-- ─── Internal ────────────────────────────────────────────────────────────────

-- A zero span would divide by zero, so it maps like a span of one
const function SpanOf(Range: NumberRange): number
	const Span = Range.Max - Range.Min
	return if Span == 0 then 1 else Span
end

-- ─── API ─────────────────────────────────────────────────────────────────────

function Mapper.GetWorldProjector(AbsoluteSize: Vector2, VisibleBounds: any, WorldHeight: number)
	const Aspect = if AbsoluteSize.Y > 0 then AbsoluteSize.X / AbsoluteSize.Y else 1
	const WorldWidth = WorldHeight * Aspect
	const XMultiplier = WorldWidth / SpanOf(VisibleBounds.X)
	const YMultiplier = WorldHeight / SpanOf(VisibleBounds.Y)

	return {
		-- The world is centered on the origin
		ToWorld = function(Index: number, Value: number): Vector3
			return Vector3.new(
				(Index - VisibleBounds.X.Min) * XMultiplier - WorldWidth / 2,
				(Value - VisibleBounds.Y.Min) * YMultiplier - WorldHeight / 2,
				0
			)
		end,
		UnitScale = Vector3.new(XMultiplier, YMultiplier, 1),
		WorldSize = Vector2.new(WorldWidth, WorldHeight),
	}
end

-- Pixels local to the chart, Y down
function Mapper.GetPixelProjector(AbsoluteSize: Vector2, VisibleBounds: any): (number, number) -> Vector2
	const XMultiplier = AbsoluteSize.X / SpanOf(VisibleBounds.X)
	const YMultiplier = AbsoluteSize.Y / SpanOf(VisibleBounds.Y)
	const XMin, YMin, Height = VisibleBounds.X.Min, VisibleBounds.Y.Min, AbsoluteSize.Y

	return function(Index: number, Value: number): Vector2
		return Vector2.new((Index - XMin) * XMultiplier, Height - (Value - YMin) * YMultiplier)
	end
end

return Mapper
