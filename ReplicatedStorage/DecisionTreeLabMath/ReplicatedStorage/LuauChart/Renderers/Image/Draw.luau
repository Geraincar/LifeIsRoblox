--!strict
--!native
--!optimize 2
-- Draw (Helper): drawing for EditableImages. Coordinates are pixels with Y pointing down. Thin wrappers
-- around the image's own draw calls (rectangles), which must stay inside the image, and software
-- rasterizers that write antialiased coverage into a Canvas buffer (strokes, rounded rects, pie sectors).

local Draw = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const Blend = Enum.ImageCombineType.BlendSourceOver
const TAU = math.pi * 2
const HALF_PI = math.pi / 2
const ALPHA_255 = 4278190080 -- alpha 255 in a little-endian RGBA8 u32
const STROKE_CHUNK = 8 -- long stroke segments are split so each bounding box stays small

-- ─── Types ───────────────────────────────────────────────────────────────────

export type SectorBorder = {
	Thickness: number,
	Color: Color3,
	Rim: boolean, -- border along the outer (and inner) arc
	Between: boolean, -- border along the two straight edges
}

-- Which corners of a rounded rectangle take the radius; nil means all four
export type Corners = {
	TopLeft: boolean?,
	TopRight: boolean?,
	BottomRight: boolean?,
	BottomLeft: boolean?,
}

-- ─── Internal ────────────────────────────────────────────────────────────────

const function Channels(Color: Color3): (number, number, number)
	return math.round(Color.R * 255), math.round(Color.G * 255), math.round(Color.B * 255)
end

-- Source-over composite of one pixel, straight alpha
const function Composite(Buf: buffer, Index: number, Red: number, Green: number, Blue: number, Coverage: number)
	const OldAlpha8 = buffer.readu8(Buf, Index + 3)
	if OldAlpha8 == 0 then
		buffer.writeu8(Buf, Index, Red)
		buffer.writeu8(Buf, Index + 1, Green)
		buffer.writeu8(Buf, Index + 2, Blue)
		buffer.writeu8(Buf, Index + 3, math.floor(Coverage * 255 + 0.5))
		return
	end

	const OldAlpha = OldAlpha8 / 255
	const OutAlpha = Coverage + OldAlpha * (1 - Coverage)
	const Weight = Coverage / OutAlpha
	buffer.writeu8(Buf, Index, math.floor(Red * Weight + buffer.readu8(Buf, Index) * (1 - Weight) + 0.5))
	buffer.writeu8(Buf, Index + 1, math.floor(Green * Weight + buffer.readu8(Buf, Index + 1) * (1 - Weight) + 0.5))
	buffer.writeu8(Buf, Index + 2, math.floor(Blue * Weight + buffer.readu8(Buf, Index + 2) * (1 - Weight) + 0.5))
	buffer.writeu8(Buf, Index + 3, math.floor(OutAlpha * 255 + 0.5))
end

const function EvaluateSequence(Keypoints: { ColorSequenceKeypoint }, Time: number): Color3
	if Time <= Keypoints[1].Time then
		return Keypoints[1].Value
	end
	const Last = Keypoints[#Keypoints]
	if Time >= Last.Time then
		return Last.Value
	end
	for Index = 1, #Keypoints - 1 do
		const Before, After = Keypoints[Index], Keypoints[Index + 1]
		if Time >= Before.Time and Time <= After.Time then
			const Alpha = if After.Time == Before.Time then 0 else (Time - Before.Time) / (After.Time - Before.Time)
			return Before.Value:Lerp(After.Value, Alpha)
		end
	end
	return Last.Value
end

-- One-pixel-wide vertical strip, clipped to the image. One native draw call per column beats writing the
-- column's pixels from Luau, which costs more the taller the fill gets.
const function Strip(Image: EditableImage, Column: number, Top: number, Bottom: number, Color: Color3, Transparency: number)
	const Height = Image.Size.Y
	const First = math.max(math.floor(Top), 0)
	const Last = math.min(math.ceil(Bottom), Height)
	if Last > First then
		Image:DrawRectangle(Vector2.new(Column, First), Vector2.new(1, Last - First), Color, Transparency, Blend)
	end
end

const function Wrap(Angle: number): number
	return Angle % TAU
end

-- Color of a ColorSequence at Time, also the heatmap color scale
function Draw.Evaluate(Sequence: ColorSequence, Time: number): Color3
	const Keypoints = Sequence.Keypoints
	if Time <= Keypoints[1].Time then
		return Keypoints[1].Value
	end
	const Last = Keypoints[#Keypoints]
	if Time >= Last.Time then
		return Last.Value
	end
	for Index = 1, #Keypoints - 1 do
		const Before, After = Keypoints[Index], Keypoints[Index + 1]
		if Time >= Before.Time and Time <= After.Time then
			const Alpha = if After.Time == Before.Time then 0 else (Time - Before.Time) / (After.Time - Before.Time)
			return Before.Value:Lerp(After.Value, Alpha)
		end
	end
	return Last.Value
end

-- ─── Projection ──────────────────────────────────────────────────────────────

-- Maps data space (Index, Value) to pixels for the visible bounds and image size. Returns the projector and
-- the pixels per data unit.
function Draw.PixelProjector(Visible: { X: NumberRange, Y: NumberRange }, Size: Vector2): ((number, number) -> Vector2, Vector2)
	const XSpan = if Visible.X.Max == Visible.X.Min then 1 else Visible.X.Max - Visible.X.Min
	const YSpan = if Visible.Y.Max == Visible.Y.Min then 1 else Visible.Y.Max - Visible.Y.Min

	const XMultiplier = Size.X / XSpan
	const YMultiplier = Size.Y / YSpan
	const XMin, YMin, Height = Visible.X.Min, Visible.Y.Min, Size.Y

	const function ToPixel(Index: number, Value: number): Vector2
		return Vector2.new((Index - XMin) * XMultiplier, Height - (Value - YMin) * YMultiplier)
	end

	return ToPixel, Vector2.new(XMultiplier, YMultiplier)
end

-- Pie angles: 0 points up, increasing clockwise on screen
function Draw.Dir(Angle: number): Vector2
	return Vector2.new(math.sin(Angle), -math.cos(Angle))
end

-- ─── Columns ─────────────────────────────────────────────────────────────────

-- Samples a polyline (sorted by X) once per pixel column. Returns ColumnY[Column + 1] (nil where the line
-- has no data) and, when Extras is given, the same interpolation of Extras[Index] per column.
function Draw.ColumnProfile(Points: { Vector2 }, Width: number, Extras: { number }?): ({number}, {number}?)
	const ColumnY = table.create(Width)
	const ColumnExtra = if Extras then table.create(Width) else nil

	const Count = #Points
	if Count < 2 then
		return ColumnY, ColumnExtra
	end

	local Segment = 1
	const FirstColumn = math.max(math.ceil(Points[1].X - 0.5), 0)
	const LastColumn = math.min(math.floor(Points[Count].X - 0.5), Width - 1)

	for Column = FirstColumn, LastColumn do
		const PixelX = Column + 0.5
		while Segment < Count - 1 and Points[Segment + 1].X < PixelX do
			Segment += 1
		end

		const Start, Finish = Points[Segment], Points[Segment + 1]
		const Span = Finish.X - Start.X
		const Alpha = if Span > 0 then math.clamp((PixelX - Start.X) / Span, 0, 1) else 0

		ColumnY[Column + 1] = Start.Y + (Finish.Y - Start.Y) * Alpha
		if ColumnExtra and Extras then
			const ExtraStart, ExtraFinish = Extras[Segment], Extras[Segment + 1]
			ColumnExtra[Column + 1] = ExtraStart + (ExtraFinish - ExtraStart) * Alpha
		end
	end

	return ColumnY, ColumnExtra
end

-- Fills each column between its Y and the floor: a constant pixel row, or a per-column profile (the top of
-- the series below on stacked charts). Columns with no floor or no line are skipped.
function Draw.FillColumns(Image: EditableImage, ColumnY: { number }, Width: number, Floor: number | { number }, Color: Color3, Transparency: number?)
	const Profile = if typeof(Floor) == "table" then Floor else nil
	const Constant = if typeof(Floor) == "number" then Floor else 0
	for Column = 0, Width - 1 do
		const Y = ColumnY[Column + 1]
		const FloorY = if Profile then Profile[Column + 1] else Constant
		if Y and FloorY and Y ~= FloorY then
			Strip(Image, Column, math.min(Y, FloorY), math.max(Y, FloorY), Color, Transparency or 0)
		end
	end
end

-- A band of half-height ColumnExtra around each column's Y
function Draw.BandColumns(Image: EditableImage, ColumnY: { number }, ColumnExtra: { number }, Width: number, Color: Color3, Transparency: number?)
	for Column = 0, Width - 1 do
		const Y, Extra = ColumnY[Column + 1], ColumnExtra[Column + 1]
		if Y and Extra and Extra > 0 then
			Strip(Image, Column, Y - Extra, Y + Extra, Color, Transparency or 0)
		end
	end
end

-- Axis-aligned rectangle given by two corners, clipped to the image
function Draw.Rect(Image: EditableImage, X0: number, Y0: number, X1: number, Y1: number, Color: Color3, Transparency: number?)
	const Size = Image.Size
	const Left = math.clamp(math.round(math.min(X0, X1)), 0, Size.X)
	const Right = math.clamp(math.round(math.max(X0, X1)), 0, Size.X)
	const Top = math.clamp(math.round(math.min(Y0, Y1)), 0, Size.Y)
	const Bottom = math.clamp(math.round(math.max(Y0, Y1)), 0, Size.Y)
	if Right > Left and Bottom > Top then
		Image:DrawRectangle(Vector2.new(Left, Top), Vector2.new(Right - Left, Bottom - Top), Color, Transparency or 0, Blend)
	end
end

-- ─── Strokes ─────────────────────────────────────────────────────────────────

-- Antialiased polyline with round caps and joins. Coverage inside one stroke combines with max, so
-- overlapping pieces of the same stroke never double up, then the stroke composites over the buffer. Only
-- pixels near each segment are visited. A single point ({P, P}) draws a dot. Transparency fades the whole
-- stroke.
function Draw.Stroke(Buf: buffer, Width: number, Height: number, Points: { Vector2 }, Thickness: number, Color: Color3, Transparency: number?)
	const Alpha = 1 - (Transparency or 0)
	if Alpha <= 0 then
		return
	end
	const Red, Green, Blue = Channels(Color)
	const HalfThickness = Thickness / 2
	const Pad = HalfThickness + 1

	const Touched = {}

	for Index = 1, #Points - 1 do
		const From, To = Points[Index], Points[Index + 1]
		const SegmentDX, SegmentDY = To.X - From.X, To.Y - From.Y
		const SegmentLength = math.sqrt(SegmentDX * SegmentDX + SegmentDY * SegmentDY)
		const Chunks = math.max(math.ceil(SegmentLength / STROKE_CHUNK), 1)

		for Chunk = 0, Chunks - 1 do
			const ChunkStart, ChunkEnd = Chunk / Chunks, (Chunk + 1) / Chunks
			const StartX, StartY = From.X + SegmentDX * ChunkStart, From.Y + SegmentDY * ChunkStart
			const EndX, EndY = From.X + SegmentDX * ChunkEnd, From.Y + SegmentDY * ChunkEnd
			const DeltaX, DeltaY = EndX - StartX, EndY - StartY
			const Length2 = DeltaX * DeltaX + DeltaY * DeltaY

			const MinColumn = math.max(math.floor(math.min(StartX, EndX) - Pad), 0)
			const MaxColumn = math.min(math.ceil(math.max(StartX, EndX) + Pad), Width - 1)
			const MinRow = math.max(math.floor(math.min(StartY, EndY) - Pad), 0)
			const MaxRow = math.min(math.ceil(math.max(StartY, EndY) + Pad), Height - 1)

			for Row = MinRow, MaxRow do
				const PixelY = Row + 0.5
				const RowOffset = Row * Width
				for Column = MinColumn, MaxColumn do
					const PixelX = Column + 0.5

					-- Distance from the pixel center to the segment
					local Along = 0
					if Length2 > 0 then
						Along = ((PixelX - StartX) * DeltaX + (PixelY - StartY) * DeltaY) / Length2
						if Along < 0 then Along = 0 elseif Along > 1 then Along = 1 end
					end
					const OffsetX, OffsetY = PixelX - (StartX + DeltaX * Along), PixelY - (StartY + DeltaY * Along)
					const Coverage = HalfThickness - math.sqrt(OffsetX * OffsetX + OffsetY * OffsetY) + 0.5

					if Coverage > 0 then
						const Index2 = (RowOffset + Column) * 4
						const Old = Touched[Index2]
						const Clamped = if Coverage > 1 then 1 else Coverage
						if not Old or Clamped > Old then
							Touched[Index2] = Clamped
						end
					end
				end
			end
		end
	end

	for Index, Coverage in Touched do
		Composite(Buf, Index, Red, Green, Blue, Coverage * Alpha)
	end
end

-- ─── Polygons ────────────────────────────────────────────────────────────────

-- Antialiased filled polygon (any simple polygon, even-odd). Coverage comes from four sub-rows per pixel
-- row with fractional span ends, then composites once per pixel with the given transparency. Pixels the
-- polygon fully covers that nothing has touched yet take a single 32-bit store.
function Draw.Polygon(Buf: buffer, Width: number, Height: number, Points: { Vector2 }, Color: Color3, Transparency: number?)
	const Count = #Points
	if Count < 3 then
		return
	end
	const Alpha = 1 - (Transparency or 0)
	if Alpha <= 0 then
		return
	end
	const Red, Green, Blue = Channels(Color)
	const FullU32 = Red + Green * 256 + Blue * 65536 + math.floor(Alpha * 255 + 0.5) * 16777216

	local MinX, MaxX, MinY, MaxY = math.huge, -math.huge, math.huge, -math.huge
	for _, Point in Points do
		if Point.X < MinX then MinX = Point.X end
		if Point.X > MaxX then MaxX = Point.X end
		if Point.Y < MinY then MinY = Point.Y end
		if Point.Y > MaxY then MaxY = Point.Y end
	end
	const MinColumn = math.max(math.floor(MinX), 0)
	const MaxColumn = math.min(math.ceil(MaxX), Width - 1)
	const MinRow = math.max(math.floor(MinY), 0)
	const MaxRow = math.min(math.ceil(MaxY), Height - 1)
	if MaxColumn < MinColumn or MaxRow < MinRow then
		return
	end

	const Coverage = table.create(MaxColumn - MinColumn + 1, 0)
	const Crossings = {}

	for Row = MinRow, MaxRow do
		local RowFirst, RowLast = math.huge, -math.huge

		for Sub = 0, 3 do
			const SampleY = Row + (Sub + 0.5) / 4
			local CrossingCount = 0
			for Index = 1, Count do
				const From = Points[Index]
				const To = Points[if Index == Count then 1 else Index + 1]
				-- Half-open rule: an edge covers its lower end and not its upper end
				if (From.Y <= SampleY) ~= (To.Y <= SampleY) then
					CrossingCount += 1
					Crossings[CrossingCount] = From.X + (SampleY - From.Y) / (To.Y - From.Y) * (To.X - From.X)
				end
			end
			for Index = CrossingCount + 1, #Crossings do
				Crossings[Index] = nil
			end
			table.sort(Crossings)

			for Index = 1, CrossingCount - 1, 2 do
				const SpanStart = math.max(Crossings[Index], MinColumn)
				const SpanEnd = math.min(Crossings[Index + 1], MaxColumn + 1)
				if SpanEnd > SpanStart then
					const StartColumn = math.floor(SpanStart)
					const EndColumn = math.ceil(SpanEnd) - 1
					if StartColumn < RowFirst then RowFirst = StartColumn end
					if EndColumn > RowLast then RowLast = EndColumn end
					if StartColumn == EndColumn then
						Coverage[StartColumn - MinColumn + 1] += (SpanEnd - SpanStart) * 0.25
					else
						-- Only the two end columns are partial
						Coverage[StartColumn - MinColumn + 1] += (StartColumn + 1 - SpanStart) * 0.25
						for Column = StartColumn + 1, EndColumn - 1 do
							Coverage[Column - MinColumn + 1] += 0.25
						end
						Coverage[EndColumn - MinColumn + 1] += (SpanEnd - EndColumn) * 0.25
					end
				end
			end
		end

		if RowLast >= RowFirst then
			const RowOffset = Row * Width
			for Column = RowFirst, RowLast do
				const Slot = Column - MinColumn + 1
				const Amount = Coverage[Slot]
				if Amount > 0 then
					Coverage[Slot] = 0
					const Index = (RowOffset + Column) * 4
					if Amount >= 0.999 and buffer.readu8(Buf, Index + 3) == 0 then
						buffer.writeu32(Buf, Index, FullU32)
					else
						Composite(Buf, Index, Red, Green, Blue, (if Amount > 1 then 1 else Amount) * Alpha)
					end
				end
			end
		end
	end
end

-- ─── Rounded rectangles ──────────────────────────────────────────────────────

-- Antialiased rounded rectangle from two corners, optionally tinted top-to-bottom by a ColorSequence.
-- Corners picks which corners take the radius; the others stay square.
-- Speed: per row, the pixels that sit at least half a pixel inside the shape (so their coverage is 1) are
-- written as a run of 32-bit stores; only the pixels near the outline pay for the distance math.
function Draw.RoundedRect(Buf: buffer, Width: number, Height: number, X0: number, Y0: number, X1: number, Y1: number, Radius: number, Color: Color3, Gradient: ColorSequence?, Corners: Corners?)
	const Left, Right = math.min(X0, X1), math.max(X0, X1)
	const Top, Bottom = math.min(Y0, Y1), math.max(Y0, Y1)
	if Right - Left < 0.01 or Bottom - Top < 0.01 then
		return
	end

	const HalfWidth, HalfHeight = (Right - Left) / 2, (Bottom - Top) / 2
	const CenterX, CenterY = (Left + Right) / 2, (Top + Bottom) / 2
	const CornerRadius = math.clamp(Radius or 0, 0, math.min(HalfWidth, HalfHeight))
	const TopLeft = if Corners then (Corners.TopLeft == true) else true
	const TopRight = if Corners then (Corners.TopRight == true) else true
	const BottomRight = if Corners then (Corners.BottomRight == true) else true
	const BottomLeft = if Corners then (Corners.BottomLeft == true) else true

	const MinColumn = math.max(math.floor(Left - 1), 0)
	const MaxColumn = math.min(math.ceil(Right + 1), Width - 1)
	const MinRow = math.max(math.floor(Top - 1), 0)
	const MaxRow = math.min(math.ceil(Bottom + 1), Height - 1)

	const FillRed, FillGreen, FillBlue = Channels(Color)
	const Keypoints = if Gradient then Gradient.Keypoints else nil
	-- Corner circles shrunk by half a pixel bound the fully covered pixels on corner rows
	const SafeRadius = CornerRadius - 0.5
	const SafeRadius2 = SafeRadius * SafeRadius

	for Row = MinRow, MaxRow do
		const PixelY = Row + 0.5
		const Below = PixelY > CenterY
		const RowOffset = Row * Width

		local Red, Green, Blue = FillRed, FillGreen, FillBlue
		if Keypoints then
			Red, Green, Blue = Channels(EvaluateSequence(Keypoints, math.clamp((PixelY - Top) / (Bottom - Top), 0, 1)))
		end
		const FillU32 = Red + Green * 256 + Blue * 65536 + ALPHA_255

		-- The run of columns whose pixel centers are at least half a pixel inside the shape on this row
		local RunFirst, RunLast = 1, 0
		const OffsetY = math.abs(PixelY - CenterY)
		if OffsetY <= HalfHeight - 0.5 then
			local SafeLeft, SafeRight = Left + 0.5, Right - 0.5
			const Reach = OffsetY - (HalfHeight - CornerRadius)
			if Reach > 0 and CornerRadius > 0 then
				const Inset = if SafeRadius > 0 and Reach <= SafeRadius
					then CornerRadius - math.sqrt(SafeRadius2 - Reach * Reach)
					else HalfWidth
				if (if Below then BottomLeft else TopLeft) then SafeLeft = math.max(SafeLeft, Left + Inset) end
				if (if Below then BottomRight else TopRight) then SafeRight = math.min(SafeRight, Right - Inset) end
			end
			RunFirst = math.max(math.ceil(SafeLeft - 0.5), MinColumn)
			RunLast = math.min(math.floor(SafeRight - 0.5), MaxColumn)
		end

		local Column = MinColumn
		while Column <= MaxColumn do
			if Column == RunFirst and RunLast >= RunFirst then
				local Index = (RowOffset + Column) * 4
				for _ = RunFirst, RunLast do
					buffer.writeu32(Buf, Index, FillU32)
					Index += 4
				end
				Column = RunLast + 1
				continue
			end

			const PixelX = Column + 0.5

			-- The radius of the corner this pixel's quadrant belongs to
			const Rounded = if PixelX > CenterX
				then (if Below then BottomRight else TopRight)
				else (if Below then BottomLeft else TopLeft)
			const Rad = if Rounded then CornerRadius else 0
			const BoxX = math.abs(PixelX - CenterX) - (HalfWidth - Rad)
			const BoxY = math.abs(PixelY - CenterY) - (HalfHeight - Rad)

			-- Signed distance to a rounded box
			const OutsideX, OutsideY = math.max(BoxX, 0), math.max(BoxY, 0)
			const Distance = math.sqrt(OutsideX * OutsideX + OutsideY * OutsideY) + math.min(math.max(BoxX, BoxY), 0) - Rad
			const Coverage = 0.5 - Distance

			if Coverage > 0 then
				Composite(Buf, (RowOffset + Column) * 4, Red, Green, Blue, if Coverage > 1 then 1 else Coverage)
			end
			Column += 1
		end
	end
end

-- ─── Sectors ─────────────────────────────────────────────────────────────────

-- Antialiased ring sector (pie slice) with optional inset borders. Slices composite additively: two slices
-- sharing an edge each cover part of the edge pixels and the parts add up to a solid pixel, so no seam
-- shows between them.
-- Speed: per row, the pixels that are provably plain fill (a full pixel away from every rim, edge ray and
-- border zone) are written as runs with one 32-bit store each. Only the band of pixels near the edges pays
-- for the coverage math, which uses cross and dot products against the edge rays instead of trig.
function Draw.Sector(Buf: buffer, Width: number, Height: number, Center: Vector2, StartAngle: number, Sweep: number, Inner: number, Outer: number, Color: Color3, Border: SectorBorder?)
	if Sweep <= 0 or Outer <= 0 then
		return
	end

	const CenterX, CenterY = Center.X, Center.Y
	const FullCircle = Sweep >= TAU - 1e-6
	const Reflex = Sweep > math.pi

	const FillRed, FillGreen, FillBlue = Channels(Color)
	const BorderThickness = if Border then Border.Thickness else 0
	const Rim = Border ~= nil and Border.Rim and BorderThickness > 0
	const Between = Border ~= nil and Border.Between and BorderThickness > 0 and not FullCircle
	local BorderRed, BorderGreen, BorderBlue = 0, 0, 0
	if Border then
		BorderRed, BorderGreen, BorderBlue = Channels(Border.Color)
	end
	const FillU32 = FillRed + FillGreen * 256 + FillBlue * 65536 + ALPHA_255
	const BorderU32 = BorderRed + BorderGreen * 256 + BorderBlue * 65536 + ALPHA_255

	-- Edge rays as unit vectors; angle 0 points up, clockwise on screen
	const StartDirX, StartDirY = math.sin(StartAngle), -math.cos(StartAngle)
	const EndDirX, EndDirY = math.sin(StartAngle + Sweep), -math.cos(StartAngle + Sweep)

	-- Bounding box: edge endpoints, plus any axis extreme that falls inside the sweep
	local MinX, MinY, MaxX, MaxY = math.huge, math.huge, -math.huge, -math.huge
	const function Include(X: number, Y: number)
		if X < MinX then MinX = X end
		if X > MaxX then MaxX = X end
		if Y < MinY then MinY = Y end
		if Y > MaxY then MaxY = Y end
	end

	if FullCircle then
		Include(CenterX - Outer, CenterY - Outer)
		Include(CenterX + Outer, CenterY + Outer)
	else
		for _, Angle in { StartAngle, StartAngle + Sweep } do
			const Direction = Draw.Dir(Angle)
			Include(CenterX + Direction.X * Outer, CenterY + Direction.Y * Outer)
			Include(CenterX + Direction.X * Inner, CenterY + Direction.Y * Inner)
		end
		for Quarter = 0, 3 do
			const Angle = Quarter * HALF_PI
			if Wrap(Angle - StartAngle) <= Sweep then
				const Direction = Draw.Dir(Angle)
				Include(CenterX + Direction.X * Outer, CenterY + Direction.Y * Outer)
			end
		end
	end

	const MinColumn = math.max(math.floor(MinX - 1), 0)
	const MaxColumn = math.min(math.ceil(MaxX + 1), Width - 1)
	const MinRow = math.max(math.floor(MinY - 1), 0)
	const MaxRow = math.min(math.ceil(MaxY + 1), Height - 1)

	const OuterLimit2 = (Outer + 1) * (Outer + 1)
	const InnerLimit = math.max(Inner - 1, 0)
	const InnerLimit2 = InnerLimit * InnerLimit

	-- Between these radii the radial coverage is a full pixel, so no square root is needed
	const OuterSafe2 = (Outer - 0.5) * (Outer - 0.5)
	const InnerSafe2 = if Inner > 0 then (Inner + 0.5) * (Inner + 0.5) else 0

	-- Rim border zones compared on squared radii
	const RimOuter2 = if Outer > BorderThickness then (Outer - BorderThickness) * (Outer - BorderThickness) else -1
	const RimInner2 = (Inner + BorderThickness) * (Inner + BorderThickness)

	-- Interior runs: pixels at least Margin from every edge ray and border zone, within the safe radii
	const Margin = math.max(1, BorderThickness)
	const RunOuter2 = if Rim and RimOuter2 < OuterSafe2 then RimOuter2 else OuterSafe2
	local RunInner2 = math.max(InnerSafe2, Margin * Margin)
	if Rim and Inner > 0 and RimInner2 > RunInner2 then
		RunInner2 = RimInner2
	end
	const HasRuns = RunOuter2 > RunInner2

	const RunLow, RunHigh = table.create(4), table.create(4)
	local RunCount = 0

	-- Appends the pixel columns whose centers lie in [Low, High] ∩ [RingLow, RingHigh], relative to the center
	const function Clip(Low: number, High: number, RingLow: number, RingHigh: number)
		const ClampedLow = if RingLow > Low then RingLow else Low
		const ClampedHigh = if RingHigh < High then RingHigh else High
		local FirstColumn = math.ceil(ClampedLow + CenterX - 0.5)
		local LastColumn = math.floor(ClampedHigh + CenterX - 0.5)
		if FirstColumn < MinColumn then FirstColumn = MinColumn end
		if LastColumn > MaxColumn then LastColumn = MaxColumn end
		if LastColumn >= FirstColumn then
			RunCount += 1
			RunLow[RunCount] = FirstColumn
			RunHigh[RunCount] = LastColumn
		end
	end

	const function AddRuns(Low: number, High: number, RingLow1: number, RingHigh1: number, RingLow2: number?, RingHigh2: number?)
		if High < Low then
			return
		end
		Clip(Low, High, RingLow1, RingHigh1)
		if RingLow2 and RingHigh2 then
			Clip(Low, High, RingLow2, RingHigh2)
		end
	end

	for Row = MinRow, MaxRow do
		const PixelY = Row + 0.5 - CenterY
		const PixelY2 = PixelY * PixelY
		const RowOffset = Row * Width

		-- This row's interior runs
		RunCount = 0
		if HasRuns and PixelY2 < RunOuter2 then
			const OuterHalfWidth = math.sqrt(RunOuter2 - PixelY2)
			local RingLow1, RingHigh1, RingLow2, RingHigh2 = -OuterHalfWidth, OuterHalfWidth, nil, nil
			if PixelY2 < RunInner2 then
				const InnerHalfWidth = math.sqrt(RunInner2 - PixelY2)
				RingLow1, RingHigh1, RingLow2, RingHigh2 = -OuterHalfWidth, -InnerHalfWidth, InnerHalfWidth, OuterHalfWidth
			end

			if FullCircle then
				AddRuns(-math.huge, math.huge, RingLow1, RingHigh1, RingLow2, RingHigh2)
			else
				-- PixelX ranges at least Margin clockwise of the start ray and at least Margin counter-clockwise
				-- of the end ray; each is a half-line, everything, or nothing
				local StartLow, StartHigh, StartOk = -math.huge, math.huge, true
				if StartDirY > 1e-9 then
					StartHigh = (StartDirX * PixelY - Margin) / StartDirY
				elseif StartDirY < -1e-9 then
					StartLow = (StartDirX * PixelY - Margin) / StartDirY
				else
					StartOk = StartDirX * PixelY >= Margin
				end
				local EndLow, EndHigh, EndOk = -math.huge, math.huge, true
				if EndDirY > 1e-9 then
					EndLow = (Margin + PixelY * EndDirX) / EndDirY
				elseif EndDirY < -1e-9 then
					EndHigh = (Margin + PixelY * EndDirX) / EndDirY
				else
					EndOk = -PixelY * EndDirX >= Margin
				end

				if Reflex then
					-- Inside a reflex sector is the union of the two half-planes
					if StartOk and EndOk then
						if StartHigh >= EndLow and EndHigh >= StartLow then
							AddRuns(math.min(StartLow, EndLow), math.max(StartHigh, EndHigh), RingLow1, RingHigh1, RingLow2, RingHigh2)
						else
							AddRuns(StartLow, StartHigh, RingLow1, RingHigh1, RingLow2, RingHigh2)
							AddRuns(EndLow, EndHigh, RingLow1, RingHigh1, RingLow2, RingHigh2)
						end
					elseif StartOk then
						AddRuns(StartLow, StartHigh, RingLow1, RingHigh1, RingLow2, RingHigh2)
					elseif EndOk then
						AddRuns(EndLow, EndHigh, RingLow1, RingHigh1, RingLow2, RingHigh2)
					end
				elseif StartOk and EndOk then
					AddRuns(math.max(StartLow, EndLow), math.min(StartHigh, EndHigh), RingLow1, RingHigh1, RingLow2, RingHigh2)
				end
			end

			-- Column order; at most four runs, from the disjoint union case
			for Index = 2, RunCount do
				const Low, High = RunLow[Index], RunHigh[Index]
				local Slot = Index - 1
				while Slot >= 1 and RunLow[Slot] > Low do
					RunLow[Slot + 1], RunHigh[Slot + 1] = RunLow[Slot], RunHigh[Slot]
					Slot -= 1
				end
				RunLow[Slot + 1], RunHigh[Slot + 1] = Low, High
			end
		end

		-- Walk the row: interior runs are plain stores, everything else gets the coverage math
		local Run = 1
		local Column = MinColumn
		while Column <= MaxColumn do
			if Run <= RunCount and Column == RunLow[Run] then
				const LastColumn = RunHigh[Run]
				local Index = (RowOffset + Column) * 4
				for _ = Column, LastColumn do
					const OldAlpha = buffer.readu8(Buf, Index + 3)
					if OldAlpha == 0 then
						buffer.writeu32(Buf, Index, FillU32)
					else
						const Sum = OldAlpha + 255
						buffer.writeu8(Buf, Index, math.floor((buffer.readu8(Buf, Index) * OldAlpha + FillRed * 255) / Sum + 0.5))
						buffer.writeu8(Buf, Index + 1, math.floor((buffer.readu8(Buf, Index + 1) * OldAlpha + FillGreen * 255) / Sum + 0.5))
						buffer.writeu8(Buf, Index + 2, math.floor((buffer.readu8(Buf, Index + 2) * OldAlpha + FillBlue * 255) / Sum + 0.5))
						buffer.writeu8(Buf, Index + 3, 255)
					end
					Index += 4
				end
				Column = LastColumn + 1
				Run += 1
				continue
			end

			const PixelX = Column + 0.5 - CenterX
			const Radius2 = PixelX * PixelX + PixelY2
			if Radius2 <= OuterLimit2 and Radius2 >= InnerLimit2 then
				local Radius = -1 -- computed only when needed

				-- Radial coverage
				local Coverage = 1
				if Radius2 > OuterSafe2 or Radius2 < InnerSafe2 then
					Radius = math.sqrt(Radius2)
					Coverage = Outer - Radius + 0.5
					if Inner > 0 then
						const InnerCoverage = Radius - Inner + 0.5
						if InnerCoverage < Coverage then Coverage = InnerCoverage end
					end
				end

				-- Angular coverage. StartDistance and EndDistance are the distances to the edge rays: the
				-- perpendicular distance in front of a ray, the distance to the center behind it.
				local StartDistance, EndDistance = math.huge, math.huge
				if Coverage > 0 and not FullCircle then
					const CrossStart = StartDirX * PixelY - StartDirY * PixelX -- positive: clockwise of the start ray
					const CrossEnd = PixelX * EndDirY - PixelY * EndDirX -- positive: counter-clockwise of the end ray
					if StartDirX * PixelX + StartDirY * PixelY >= 0 then
						StartDistance = if CrossStart < 0 then -CrossStart else CrossStart
					else
						if Radius < 0 then Radius = math.sqrt(Radius2) end
						StartDistance = Radius
					end
					if EndDirX * PixelX + EndDirY * PixelY >= 0 then
						EndDistance = if CrossEnd < 0 then -CrossEnd else CrossEnd
					else
						if Radius < 0 then Radius = math.sqrt(Radius2) end
						EndDistance = Radius
					end

					const Nearest = if StartDistance < EndDistance then StartDistance else EndDistance
					const Inside = if Reflex then (CrossStart >= 0 or CrossEnd >= 0) else (CrossStart >= 0 and CrossEnd >= 0)
					if Inside then
						const Edge = Nearest + 0.5
						if Edge < Coverage then Coverage = Edge end
					else
						-- Outside the sweep only the sliver within half a pixel of an edge ray is covered, and
						-- that sliver belongs to the side border if there is one
						const Edge = 0.5 - Nearest
						if Edge < Coverage then Coverage = Edge end
						StartDistance = 0
					end
				end

				if Coverage > 0 then
					if Coverage > 1 then Coverage = 1 end

					local IsBorder = false
					if Rim and (Radius2 > RimOuter2 or (Inner > 0 and Radius2 < RimInner2)) then
						IsBorder = true
					elseif Between and (StartDistance < BorderThickness or EndDistance < BorderThickness) then
						IsBorder = true
					end

					-- Additive composite
					const Index = (RowOffset + Column) * 4
					const OldAlpha = buffer.readu8(Buf, Index + 3)
					if OldAlpha == 0 then
						if Coverage >= 1 then
							buffer.writeu32(Buf, Index, if IsBorder then BorderU32 else FillU32)
						else
							buffer.writeu8(Buf, Index, if IsBorder then BorderRed else FillRed)
							buffer.writeu8(Buf, Index + 1, if IsBorder then BorderGreen else FillGreen)
							buffer.writeu8(Buf, Index + 2, if IsBorder then BorderBlue else FillBlue)
							buffer.writeu8(Buf, Index + 3, math.floor(Coverage * 255 + 0.5))
						end
					else
						const NewAlpha = math.floor(Coverage * 255 + 0.5)
						if NewAlpha > 0 then
							const Red = if IsBorder then BorderRed else FillRed
							const Green = if IsBorder then BorderGreen else FillGreen
							const Blue = if IsBorder then BorderBlue else FillBlue
							const Sum = OldAlpha + NewAlpha
							buffer.writeu8(Buf, Index, math.floor((buffer.readu8(Buf, Index) * OldAlpha + Red * NewAlpha) / Sum + 0.5))
							buffer.writeu8(Buf, Index + 1, math.floor((buffer.readu8(Buf, Index + 1) * OldAlpha + Green * NewAlpha) / Sum + 0.5))
							buffer.writeu8(Buf, Index + 2, math.floor((buffer.readu8(Buf, Index + 2) * OldAlpha + Blue * NewAlpha) / Sum + 0.5))
							buffer.writeu8(Buf, Index + 3, math.min(Sum, 255))
						end
					end
				end
			end
			Column += 1
		end
	end
end

return Draw
