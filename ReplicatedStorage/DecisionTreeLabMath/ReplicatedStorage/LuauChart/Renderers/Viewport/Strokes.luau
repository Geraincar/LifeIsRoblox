--!strict
--!native
--!optimize 2
-- Strokes (Helper): pooled polylines for the viewport renderers. Samples that only pad a straight stretch
-- are dropped (Graph.Simplify pixels, coarser while the chart animates), a ball cap sits only where a joint
-- bends enough to show a notch, dashes get no caps at all, and a color is written only when it changes, so
-- an animated line touches as few part properties per frame as it can.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const Sampling = require(Internal.Sampling)
const PartPool = require(Internal.PartPool)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const SIMPLIFY_PIXELS = 0.35 -- default distance a drawn polyline may sit from its samples on screen
const CAP_PIXELS = 0.5 -- a joint whose notch would be smaller than this gets no cap

-- The Node asset is a cylinder with a ball cap inside it; the pool hands them out separately
const LineTemplate = Assets.Node:Clone()
const CapTemplate = LineTemplate:FindFirstChild("Cap") :: Part
CapTemplate.Parent = nil

local Strokes = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Pool = PartPool.PartPool
export type Colors = { [Instance]: Color3 }

-- ─── Internal ────────────────────────────────────────────────────────────────

-- Two cylinders meeting at a joint leave a notch on the outer side of the bend; when it would be smaller
-- than the limit, no cap is needed
const function NeedsCap(Before: Vector3, Joint: Vector3, After: Vector3, HalfThickness: number, Limit: number): boolean
	const In, Out = Joint - Before, After - Joint
	const InLength, OutLength = In.Magnitude, Out.Magnitude
	if InLength < 1e-6 or OutLength < 1e-6 then
		return true
	end
	const Cosine = math.clamp(In:Dot(Out) / (InLength * OutLength), -1, 1)
	if Cosine <= 0 then
		return true
	end
	-- Notch depth is half the thickness times the tangent of half the turn
	return HalfThickness * math.sqrt((1 - Cosine) / (1 + Cosine)) >= Limit
end

const function Cap(Pool: Pool, Colors: Colors, Parent: Instance, Position: Vector3, Thickness: number, Color: Color3)
	const Ball: any = Pool:Get(Parent, "Caps", CapTemplate)
	Strokes.SetColor(Colors, Ball, Color)
	Ball.Size = Vector3.new(Thickness, Thickness, Thickness)
	Ball.CFrame = CFrame.new(Position)
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- A color cache for one renderer: weak keys, so destroyed parts fall out of it
function Strokes.Colors(): Colors
	return setmetatable({}, { __mode = "k" }) :: any
end

-- Writes a color only when the part does not already show it
function Strokes.SetColor(Colors: Colors, Part: any, Color: Color3)
	if Colors[Part] ~= Color then
		Colors[Part] = Color
		Part.Color = Color
	end
end

-- The indices of the points a polyline needs to stay within Pixels (default SIMPLIFY_PIXELS) of its samples
function Strokes.SimplifyIndices(Points: { Vector3 }, WorldPerPixel: number, Pixels: number?): { number }
	return Sampling.SimplifyIndices(Points, (Pixels or SIMPLIFY_PIXELS) * WorldPerPixel)
end

-- One polyline of world points (two or more) as cylinders under Parent. Thickness is in world units. With
-- Caps (the default) the ends and every joint that bends enough get a ball; without, the ends stay flat.
function Strokes.Polyline(Pool: Pool, Colors: Colors, Parent: Instance, Points: { Vector3 }, Thickness: number, Color: Color3, WorldPerPixel: number, Caps: boolean?)
	const Count = #Points
	if Count < 2 then
		return
	end
	const Capped = Caps ~= false
	const HalfThickness = Thickness / 2
	const Limit = CAP_PIXELS * WorldPerPixel

	if Capped then
		Cap(Pool, Colors, Parent, Points[1], Thickness, Color)
	end
	for Index = 1, Count - 1 do
		const Start, Finish = Points[Index], Points[Index + 1]
		const Line: any = Pool:Get(Parent, "Lines", LineTemplate)
		Strokes.SetColor(Colors, Line, Color)
		Line.Size = Vector3.new((Finish - Start).Magnitude, Thickness, Thickness)
		Line.CFrame = CFrame.new((Start + Finish) / 2) * CFrame.Angles(0, 0, math.atan2(Finish.Y - Start.Y, Finish.X - Start.X))
		if Capped and (Index == Count - 1 or NeedsCap(Start, Finish, Points[Index + 2], HalfThickness, Limit)) then
			Cap(Pool, Colors, Parent, Finish, Thickness, Color)
		end
	end
end

-- The same polyline broken into dashes; pattern lengths are pixels. Dashes are flat-ended single cylinders,
-- so a dashed line costs one part per dash instead of three.
function Strokes.Dashed(Pool: Pool, Colors: Colors, Parent: Instance, Points: { Vector3 }, Thickness: number, Color: Color3, Dash: { number }, WorldPerPixel: number)
	for _, Piece in Sampling.Dash(Points :: any, Dash, 1 / WorldPerPixel) do
		Strokes.Polyline(Pool, Colors, Parent, Piece :: any, Thickness, Color, WorldPerPixel, false)
	end
end

-- Points simplified to what the screen can tell apart, for renderers that draw their own segments
function Strokes.Simplify(Points: { Vector3 }, WorldPerPixel: number, Pixels: number?): { Vector3 }
	return Sampling.Simplify(Points, (Pixels or SIMPLIFY_PIXELS) * WorldPerPixel) :: any
end

return Strokes
