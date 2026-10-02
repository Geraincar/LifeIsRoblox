--!strict
--!native
--!optimize 2
-- Pie (Class): viewport pie renderer, drawing parts inside ViewportFrames. Border.Mode: "Between" (radial
-- lines between slices), "Rim" (outer and inner arcs) or "All" (default). Holders stay in the tree and their
-- parts are pooled, so an animated pie moves parts instead of recreating them every frame.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const CreateTris = require(Internal.CreateTris)
const PieMath = require(Internal.PieMath)
const HitTest = require(Internal.HitTest)
const PartPool = require(Internal.PartPool)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Configuration ───────────────────────────────────────────────────────────

const WHITE = Color3.new(1, 1, 1)
const TAU = math.pi * 2

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	Segments: number,
	DefaultOffset: number,
	Padding: number,
	Layout: Types.Layout?,
	_Holders: { any },
	_HolderCount: number,
	_Pool: typeof(PartPool.new()),
}

local PieRenderer = {}
PieRenderer.__index = PieRenderer

export type PieRenderer = typeof(setmetatable({} :: Fields, PieRenderer))

-- ─── Internal ────────────────────────────────────────────────────────────────

-- World direction (Y up) for a screen angle
const function WorldDir(Angle: number): Vector3
	return Vector3.new(math.sin(Angle), math.cos(Angle), 0)
end

-- ─── Construction ────────────────────────────────────────────────────────────

function PieRenderer.new(Graph: any): PieRenderer
	const self = setmetatable({} :: Fields, PieRenderer)
	self.Graph = Graph

	self.WorldHeight = 100
	self.Thickness = 10 -- Z depth of the slice geometry
	self.Segments = 80 -- segments per full circle; higher is smoother
	self.DefaultOffset = 0 -- explode distance in pixels for slices that set no Offset
	self.Padding = 0.04 -- fraction of the radius kept clear around the pie

	self.Layout = nil -- pixel-space geometry of the last render, read by the Hover feature

	self._Holders = {}
	self._HolderCount = 0
	self._Pool = PartPool.new()
	return self
end

function PieRenderer.HitTest(self: PieRenderer, Local: Vector2): any
	return HitTest.Pie(self.Layout, Local)
end

-- ─── Pooling ─────────────────────────────────────────────────────────────────

-- The next viewport holder in tree order, with its part model. Holders keep their parent and their pooled
-- parts between updates, so a slice draws with the same parts every frame
function PieRenderer._GetSliceHolder(self: PieRenderer): (any, any)
	const Position = self._HolderCount + 1
	self._HolderCount = Position
	local Holder: any = self._Holders[Position]
	if not Holder then
		Holder = Assets.Slice:Clone()
		Holder.CurrentCamera = self.Graph._Camera
		Holder.Parent = self.Graph.UI.Slices
		self._Holders[Position] = Holder
	end
	Holder.Visible = true
	Holder.ZIndex = Assets.Slice.ZIndex -- a holder may have been raised for borders or leaders last time

	return Holder, Holder:FindFirstChild("Model")
end

-- Starts an update: every holder becomes available again
function PieRenderer._Reset(self: PieRenderer)
	self._HolderCount = 0
end

-- Ends an update: holders that went unused are hidden in place
function PieRenderer._Trim(self: PieRenderer)
	for Position = self._HolderCount + 1, #self._Holders do
		self._Holders[Position].Visible = false
	end
end

function PieRenderer.Destroy(self: PieRenderer)
	self._Pool:Destroy()
	for _, Holder in self._Holders do
		Holder:Destroy()
	end
	table.clear(self._Holders)
	self._HolderCount = 0
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function PieRenderer._DrawLine(self: PieRenderer, Parent: Instance, From: Vector3, To: Vector3, Thickness: number)
	const Distance = (To - From).Magnitude
	if Distance < 0.001 then
		return
	end

	const Line: any = self._Pool:Get(Parent, "Borders", Assets.FillerCube)
	Line.Size = Vector3.new(Thickness, Thickness, Distance)
	Line.CFrame = CFrame.lookAt(From, To) * CFrame.new(0, 0, -Distance / 2)
end

-- Frames EffectiveRadius world units across the half height of the viewport
function PieRenderer._SetupCamera(self: PieRenderer, EffectiveRadius: number)
	const Camera: Camera = self.Graph._Camera
	const Distance = EffectiveRadius / math.tan(math.rad(Camera.FieldOfView / 2))
	Camera.CFrame = CFrame.new(0, 0, Distance)
end

function PieRenderer.Update(self: PieRenderer)
	const Graph = self.Graph
	const Labels = Graph.Labels
	const Pool = self._Pool

	self:_Reset()
	Pool:Begin()

	const function Clear()
		self:_Trim()
		Pool:Finish()
		self.Layout = nil
		if Labels then
			Labels:Clear()
		end
	end

	const Slices = PieMath.Slices(Graph)
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	if #Slices == 0 or AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		Clear()
		return
	end

	local MaxOffsetPixels = 0
	for _, Slice in Slices do
		MaxOffsetPixels = math.max(MaxOffsetPixels, Slice.Offset)
	end

	const ShowLabels = Labels and Labels.Enabled
	const Outside = ShowLabels and Labels.Placement == "Outside"
	const Reserve: number = if Outside then (Labels.OutsideMargin or 64) else 0

	-- The camera maps world units to exactly the pixel radius of the pie
	const OuterRadius = self.WorldHeight / 2
	const OuterPixels = (math.min(AbsoluteSize.X, AbsoluteSize.Y) / 2 - MaxOffsetPixels - Reserve) * (1 - self.Padding)
	if OuterPixels <= 0 then
		Clear()
		return
	end
	const PixelsPerWorld = OuterPixels / OuterRadius
	self:_SetupCamera((AbsoluteSize.Y / 2) / PixelsPerWorld)

	const InnerRadius = OuterRadius * (Graph.Cutout or 0)
	const SegmentAngle = TAU / self.Segments

	const CenterPixels = AbsoluteSize / 2
	const LayoutOuter = OuterPixels
	const LayoutInner = InnerRadius * PixelsPerWorld
	const Layout: Types.Layout = {
		Center = CenterPixels,
		Outer = LayoutOuter,
		Inner = LayoutInner,
		Items = {},
	}
	const LabelItems: { Types.LabelItem } = {}
	const Leaders: { Types.LeaderSpec } = {}

	for _, Slice in Slices do
		const SliceData = Slice.Data
		const StartAngle = Slice.Start
		const Sweep = Slice.Sweep
		const EndAngle = StartAngle + Sweep
		const SliceSegments = math.max(math.ceil(Sweep / SegmentAngle), 1)

		const Border = SliceData.Border or {}
		const Mode: string = Border.Mode or "All"
		const HasBorder = (Border.Thickness or 0) > 0
		const BorderWorld: number = if HasBorder then Border.Thickness / PixelsPerWorld else 0

		-- The whole slice moves along its bisector when exploded
		const Bisector = Slice.Bisector
		const OffsetVector = WorldDir(Bisector) * (Slice.Offset / PixelsPerWorld)

		-- Rose charts carry the value in the radius, scaled over the ring so the cutout stays put
		const SliceOuterWorld = InnerRadius + (OuterRadius - InnerRadius) * Slice.Scale
		const SliceInnerWorld = InnerRadius
		const SliceOuterPixels = LayoutInner + (LayoutOuter - LayoutInner) * Slice.Scale
		const SliceInnerPixels = LayoutInner

		const SliceHolder, SliceModel = self:_GetSliceHolder()
		SliceHolder.ImageColor3 = SliceData.Color or WHITE

		local BorderModel: any = nil
		if HasBorder then
			const BorderHolder, Model = self:_GetSliceHolder()
			BorderModel = Model
			BorderHolder.ImageColor3 = Border.Color or WHITE
			BorderHolder.ZIndex = SliceHolder.ZIndex + 1

			if Mode == "Between" or Mode == "All" then
				-- Side borders shift inside the slice: clockwise at the start edge, counter-clockwise at the end
				const function DrawSide(Angle: number, IsStart: boolean)
					const Direction = WorldDir(Angle)
					const SideSign = if IsStart then 1 else -1
					const Shift = Vector3.new(math.cos(Angle), -math.sin(Angle), 0) * SideSign * (BorderWorld / 2)
					const InnerPoint = OffsetVector + Direction * SliceInnerWorld + Shift
					const OuterPoint = OffsetVector + Direction * SliceOuterWorld + Shift
					self:_DrawLine(BorderModel, InnerPoint, OuterPoint, BorderWorld)
				end

				DrawSide(StartAngle, true)
				DrawSide(EndAngle, false)
			end
		end

		for Segment = 1, SliceSegments do
			const AngleA = StartAngle + Sweep * (Segment - 1) / SliceSegments
			const AngleB = StartAngle + Sweep * Segment / SliceSegments

			const DirectionA = WorldDir(AngleA)
			const DirectionB = WorldDir(AngleB)

			const OuterA = OffsetVector + DirectionA * SliceOuterWorld
			const OuterB = OffsetVector + DirectionB * SliceOuterWorld
			const InnerA = OffsetVector + DirectionA * SliceInnerWorld
			const InnerB = OffsetVector + DirectionB * SliceInnerWorld

			const WedgeA: any = Pool:Get(SliceModel, "Wedges", Assets.Filler)
			const WedgeB: any = Pool:Get(SliceModel, "Wedges", Assets.Filler)
			CreateTris(WedgeA, WedgeB, InnerA, OuterA, OuterB, self.Thickness)

			if SliceInnerWorld > 0.001 then
				const WedgeC: any = Pool:Get(SliceModel, "Wedges", Assets.Filler)
				const WedgeD: any = Pool:Get(SliceModel, "Wedges", Assets.Filler)
				CreateTris(WedgeC, WedgeD, InnerA, InnerB, OuterB, self.Thickness)
			end

			-- Rim borders shift inward so they stay inside the slice
			if HasBorder and (Mode == "Rim" or Mode == "All") then
				const Inward = (DirectionA + DirectionB).Unit * (BorderWorld / 2)

				self:_DrawLine(BorderModel, OuterA - Inward, OuterB - Inward, BorderWorld)

				if SliceInnerWorld > 0.001 then
					self:_DrawLine(BorderModel, InnerA + Inward, InnerB + Inward, BorderWorld)
				end
			end
		end

		-- Layout and labels, in pixels
		const BisectorDir = PieMath.Dir(Bisector)
		const OffsetPixels = BisectorDir * Slice.Offset
		const SliceCenter = CenterPixels + OffsetPixels
		Layout.Items[Slice.Index] = { Entry = SliceData, Start = StartAngle, Sweep = Sweep, Offset = OffsetPixels, Outer = SliceOuterPixels }

		if ShowLabels then
			const Spec: Types.ResolvedLabel? = Labels:Resolve(SliceData, Slice)
			if Spec then
				local Position: Vector2
				local Anchor: Vector2? = nil
				if (Spec.Placement or "Inside") == "Outside" then
					-- Past the rim, on a leader line that bends horizontally toward the label
					const Side = if BisectorDir.X >= 0 then 1 else -1
					const Rim = SliceCenter + BisectorDir * (SliceOuterPixels + 2)
					const Elbow = SliceCenter + BisectorDir * (SliceOuterPixels + (Labels.LeaderLength or 14))
					const Tip = Elbow + Vector2.new(Side * (Labels.LeaderRun or 12), 0)
					table.insert(Leaders, { Points = { Rim, Elbow, Tip }, Color = Labels.LeaderColor or SliceData.Color or WHITE })
					Position = Tip + Vector2.new(Side * Spec.Offset, 0)
					Anchor = Vector2.new(if Side > 0 then 0 else 1, 0.5)
				else
					-- Automatic placement: the middle of the ring on donuts, 60% of the radius on full pies
					const Distance: number = Labels.Distance or (if LayoutInner > 0.5 then 0.5 else 0.6)
					const Radius = SliceInnerPixels + (SliceOuterPixels - SliceInnerPixels) * Distance
					Position = SliceCenter + BisectorDir * Radius
				end
				if Spec.Position then Position = Spec.Position end
				if Spec.Anchor then Anchor = Spec.Anchor end
				if Spec.Nudge then Position += Spec.Nudge end
				table.insert(LabelItems, { Position = Position, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
			end
		end
	end

	if Graph.CenterText then
		table.insert(LabelItems, { Position = CenterPixels, Text = tostring(Graph.CenterText) })
	end

	-- Leader lines are thin parts in their own viewport, so both of their segments get the same weight;
	-- rotated GUI frames would render the angled segment heavier than the horizontal one
	if #Leaders > 0 then
		const LeaderThickness = (Labels.LeaderThickness or 1) / PixelsPerWorld
		const function PixelToWorld(Pixel: Vector2): Vector3
			return Vector3.new((Pixel.X - CenterPixels.X) / PixelsPerWorld, -(Pixel.Y - CenterPixels.Y) / PixelsPerWorld, self.Thickness)
		end

		for _, Leader in Leaders do
			const Holder, Model = self:_GetSliceHolder()
			Holder.ImageColor3 = Leader.Color or WHITE
			Holder.ZIndex = Assets.Slice.ZIndex + 2
			for Index = 1, #Leader.Points - 1 do
				self:_DrawLine(Model, PixelToWorld(Leader.Points[Index]), PixelToWorld(Leader.Points[Index + 1]), LeaderThickness)
			end
		end
	end

	self:_Trim()
	Pool:Finish()
	self.Layout = Layout
	if Labels then
		Labels:Set(LabelItems)
		Labels:SetLeaders({})
	end
end

return PieRenderer
