--!strict
--!native
--!optimize 2
-- Box (Class): viewport box plot renderer. Cubes for whiskers, caps, bodies and medians, balls for outliers.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Internal = script.Parent.Parent.Parent.Internal
const Mapper = require(Internal.Mapper)
const BoxMath = require(Internal.BoxMath)
const BarMath = require(Internal.BarMath)
const HitTest = require(Internal.HitTest)
const PartPool = require(Internal.PartPool)
const Types = require(script.Parent.Parent.Parent.Types)
const Assets = script.Parent.Assets

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	WorldHeight: number,
	Thickness: number,
	Layout: Types.Layout?,
	_Pool: typeof(PartPool.new()),
	_MarkerTemplate: Part,
}

local BoxRenderer = {}
BoxRenderer.__index = BoxRenderer

export type BoxRenderer = typeof(setmetatable({} :: Fields, BoxRenderer))

-- ─── Construction ────────────────────────────────────────────────────────────

function BoxRenderer.new(Graph: any): BoxRenderer
	const self = setmetatable({} :: Fields, BoxRenderer)
	self.Graph = Graph
	self.WorldHeight = 100
	self.Thickness = 5 -- Z depth of a body
	self.Layout = nil
	self._Pool = PartPool.new()

	const Marker = Instance.new("Part")
	Marker.Shape = Enum.PartType.Ball
	Marker.Material = Enum.Material.SmoothPlastic
	Marker.Anchored = true
	Marker.CanCollide = false
	Marker.CanQuery = false
	Marker.CastShadow = false
	Marker.Size = Vector3.one
	self._MarkerTemplate = Marker

	return self
end

function BoxRenderer.AdjustBounds(self: BoxRenderer, MinX: number, MaxX: number, MinY: number, MaxY: number): (number, number, number, number)
	return BoxMath.AdjustBounds(self.Graph, MinX, MaxX, MinY, MaxY)
end

function BoxRenderer.HitTest(self: BoxRenderer, Local: Vector2): any
	return HitTest.Rects(self.Layout, Local)
end

function BoxRenderer.Destroy(self: BoxRenderer)
	self._Pool:Destroy()
	self._MarkerTemplate:Destroy()
	self.Layout = nil
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function BoxRenderer._SetupCamera(self: BoxRenderer)
	const Camera: Camera = self.Graph._Camera
	Camera.CFrame = CFrame.new(0, 0, (self.WorldHeight / 2) / math.tan(math.rad(Camera.FieldOfView / 2)))
	const Frame = self.Graph.UI.Boxes
	if Frame.CurrentCamera ~= Camera then
		Frame.CurrentCamera = Camera
	end
end

function BoxRenderer._Cube(self: BoxRenderer, Container: Instance, Type: string, From: Vector3, To: Vector3, Thickness: number, Color: Color3)
	const Cube: any = self._Pool:Get(Container, Type, Assets.FillerCube)
	Cube.Color = Color
	Cube.Size = Vector3.new(math.max(math.abs(To.X - From.X), Thickness), math.max(math.abs(To.Y - From.Y), Thickness), self.Thickness)
	Cube.Position = (From + To) / 2
end

function BoxRenderer.Update(self: BoxRenderer)
	const Graph = self.Graph
	const Pool = self._Pool
	Pool:Begin()

	const Items, Slot = BoxMath.Layout(Graph)
	const AbsoluteSize: Vector2 = Graph.UI.AbsoluteSize
	if #Items == 0 or AbsoluteSize.X <= 0 or AbsoluteSize.Y <= 0 then
		Pool:Finish()
		self.Layout = nil
		return
	end

	self:_SetupCamera()
	const Visible = Graph:GetVisibleBounds()
	const Projector = Mapper.GetWorldProjector(AbsoluteSize, Visible, self.WorldHeight)
	const ToPixel = Mapper.GetPixelProjector(AbsoluteSize, Visible)
	const WorldPerPixel = self.WorldHeight / AbsoluteSize.Y
	const Container = Graph.UI.Boxes.Model
	const Whisker = (Graph.WhiskerThickness or 1) * WorldPerPixel
	const Median = (Graph.MedianThickness or 2) * WorldPerPixel
	const OutlierSize = (Graph.OutlierSize or 0) * WorldPerPixel
	const MedianColor: Color3 = Graph.MedianColor or Color3.new(1, 1, 1)
	const Layout: Types.Layout = { Items = {} }

	for _, Item in Items do
		const Entry = Item.Entry
		const Color = BoxMath.Color(Graph, Item)
		const Left, Right = Projector.ToWorld(Item.X0, 0).X, Projector.ToWorld(Item.X1, 0).X
		const CapLeft, CapRight = Projector.ToWorld(Item.CapX0, 0).X, Projector.ToWorld(Item.CapX1, 0).X
		const CenterX = (Left + Right) / 2
		const LowY, HighY = Projector.ToWorld(Item.Index, Entry.Low).Y, Projector.ToWorld(Item.Index, Entry.High).Y
		const Q1Y, Q3Y = Projector.ToWorld(Item.Index, Entry.Q1).Y, Projector.ToWorld(Item.Index, Entry.Q3).Y
		const MedianY = Projector.ToWorld(Item.Index, Entry.Median).Y

		self:_Cube(Container, "Whiskers", Vector3.new(CenterX, Q3Y, 0), Vector3.new(CenterX, HighY, 0), Whisker, Color)
		self:_Cube(Container, "Whiskers", Vector3.new(CenterX, LowY, 0), Vector3.new(CenterX, Q1Y, 0), Whisker, Color)
		self:_Cube(Container, "Caps", Vector3.new(CapLeft, HighY, 0), Vector3.new(CapRight, HighY, 0), Whisker, Color)
		self:_Cube(Container, "Caps", Vector3.new(CapLeft, LowY, 0), Vector3.new(CapRight, LowY, 0), Whisker, Color)
		self:_Cube(Container, "Bodies", Vector3.new(Left, Q1Y, 0), Vector3.new(Right, Q3Y, 0), Whisker, Color)
		-- The median sits just in front of the body
		self:_Cube(Container, "Medians", Vector3.new(Left, MedianY, 0.1), Vector3.new(Right, MedianY, 0.1), Median, MedianColor)

		local Top, Bottom = ToPixel(Item.Index, Entry.High).Y, ToPixel(Item.Index, Entry.Low).Y
		if OutlierSize > 0 then
			const Outliers: { number } = Entry.Outliers or {}
			for _, Value in Outliers do
				const Marker: any = Pool:Get(Container, "Outliers", self._MarkerTemplate)
				Marker.Size = Vector3.one * OutlierSize
				Marker.Color = Color
				Marker.Position = Vector3.new(CenterX, Projector.ToWorld(Item.Index, Value).Y, 0)
				const PixelY = ToPixel(Item.Index, Value).Y
				Top, Bottom = math.min(Top, PixelY), math.max(Bottom, PixelY)
			end
		end

		Layout.Items[Item.Key] = {
			Entry = Entry,
			Series = 1,
			Rect = { ToPixel(Item.X0, 0).X, Top, ToPixel(Item.X1, 0).X, Bottom },
		}
	end

	Pool:Finish()
	-- Box items carry the same X0, X1, Y0, Y1 and Index fields BarMath.Slots reads
	Layout.Slots, Layout.Zero = BarMath.Slots(Graph, Items :: any, Slot, ToPixel)
	Layout.Orientation = "Vertical"
	self.Layout = Layout
end

return BoxRenderer
