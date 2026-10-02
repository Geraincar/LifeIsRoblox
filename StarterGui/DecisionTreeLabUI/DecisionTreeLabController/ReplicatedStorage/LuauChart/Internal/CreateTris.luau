--!strict
--!native
--!optimize 2
-- CreateTris (Helper): shapes two wedge parts into the triangle A, B, C for the viewport renderers.

const MIN_LENGTH2 = 0.0001

return function(WedgeA: WedgePart, WedgeB: WedgePart, A: Vector3, B: Vector3, C: Vector3, Thickness: number)
	local EdgeAB, EdgeAC, EdgeBC = B - A, C - A, C - B
	const SquaredAB, SquaredAC, SquaredBC = EdgeAB:Dot(EdgeAB), EdgeAC:Dot(EdgeAC), EdgeBC:Dot(EdgeBC)

	-- Degenerate triangles would produce NaN frames
	if SquaredAB < MIN_LENGTH2 or SquaredAC < MIN_LENGTH2 or SquaredBC < MIN_LENGTH2 then
		WedgeA.Size = Vector3.zero
		WedgeB.Size = Vector3.zero
		return
	end

	-- Rotate the corners so the longest edge is BC, which the two wedges share
	if SquaredAB > SquaredAC and SquaredAB > SquaredBC then
		A, B, C = C, A, B
		EdgeAB, EdgeAC, EdgeBC = B - A, C - A, C - B
	elseif not (SquaredAC > SquaredBC and SquaredAC > SquaredAB) then
		A, B, C = B, C, A
		EdgeAB, EdgeAC, EdgeBC = B - A, C - A, C - B
	end

	const Normal = EdgeAC:Cross(EdgeAB)
	const Right = if Normal.Magnitude > MIN_LENGTH2 then Normal.Unit else Vector3.new(0, 0, 1)

	const UpCross = EdgeBC:Cross(Right)
	if UpCross.Magnitude < MIN_LENGTH2 then
		WedgeA.Size = Vector3.zero
		WedgeB.Size = Vector3.zero
		return
	end
	const Up = UpCross.Unit
	const Back = EdgeBC.Unit

	const Height = math.abs(EdgeAB:Dot(Up))
	const DepthAB = math.abs(EdgeAB:Dot(Back))
	const DepthAC = math.abs(EdgeAC:Dot(Back))

	WedgeA.CFrame = CFrame.fromMatrix((A + B) / 2, Right, Up, Back)
	WedgeA.Size = Vector3.new(Thickness, Height, DepthAB)

	WedgeB.CFrame = CFrame.fromMatrix((A + C) / 2, -Right, Up, -Back)
	WedgeB.Size = Vector3.new(Thickness, Height, DepthAC)
end
