--!strict
--!native
--!optimize 2
-- Hover (Class): pointer hover and click for charts with discrete items (pie slices, bars). The renderer
-- publishes its pixel-space geometry in Renderer.Layout and answers Renderer:HitTest(Local) with an item
-- key; this feature eases a 0..1 value per item that renderers read back (GetAlpha, GetOffset) to
-- highlight it.

-- ─── Services ────────────────────────────────────────────────────────────────

const TweenService = game:GetService("TweenService")
const GuiService = game:GetService("GuiService")

-- ─── Dependencies ────────────────────────────────────────────────────────────

const GuiUtil = require(script.Parent.Parent.Internal.GuiUtil)

-- ─── Configuration ───────────────────────────────────────────────────────────

const GuiInset = GuiService:GetGuiInset()

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	Enabled: boolean,
	Offset: number,
	Highlight: number,
	TweenInfo: TweenInfo,
	OnChanged: ((Key: any, Entry: any) -> ())?,
	OnClick: ((Key: any, Entry: any) -> ())?,
	Key: any,
	Index: any,
	_Drivers: { [any]: NumberValue },
	_Connections: { RBXScriptConnection },
}

local Hover = {} 
Hover.__index = Hover

export type Hover = typeof(setmetatable({} :: Fields, Hover))

-- ─── Construction ────────────────────────────────────────────────────────────

function Hover.new(Graph: any): Hover
	const self = setmetatable({} :: Fields, Hover)

	self.Graph = Graph
	self.Enabled = true
	self.Offset = 12 -- pie: pixels the hovered slice moves outward
	self.Highlight = 0.3 -- bar: how much the hovered bar lightens toward white, 0..1
	self.TweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	self.OnChanged = nil -- function(Key, Entry) when the hovered item changes; Key nil when nothing is hovered
	self.OnClick = nil -- function(Key, Entry) on a click or tap over an item

	self.Key = nil -- hovered item: the slice index for pies, "<series>_<bar>" for bars
	self.Index = nil -- same as Key, kept for pie code that reads Hover.Index

	self._Drivers = {} -- [Key] = NumberValue, 0..1
	self._Connections = {}

	self:_BindInput()

	return self
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- 0..1 highlight amount for an item, 0 while disabled
function Hover.GetAlpha(self: Hover, Key: any): number
	if not self.Enabled then
		return 0
	end
	const Driver = self._Drivers[Key]
	return if Driver then Driver.Value else 0
end

-- Extra explode distance for a pie slice, in pixels
function Hover.GetOffset(self: Hover, Key: any): number
	return self:GetAlpha(Key) * self.Offset
end

function Hover.SetKey(self: Hover, Key: any)
	if Key == self.Key then
		return
	end

	const Previous = self.Key
	self.Key = Key
	self.Index = Key

	if Previous ~= nil then
		TweenService:Create(self:_GetDriver(Previous), self.TweenInfo, { Value = 0 }):Play()
	end
	if Key ~= nil then
		TweenService:Create(self:_GetDriver(Key), self.TweenInfo, { Value = 1 }):Play()
	end

	const OnChanged = self.OnChanged
	if OnChanged then
		OnChanged(Key, if Key ~= nil then self:_EntryFor(Key) else nil)
	end
end

-- Kept for callers that used the pie-only API
function Hover.SetIndex(self: Hover, Index: any)
	self:SetKey(Index)
end

function Hover.Destroy(self: Hover)
	for _, Connection in self._Connections do
		Connection:Disconnect()
	end
	table.clear(self._Connections)
end

-- ─── Internal ────────────────────────────────────────────────────────────────

function Hover._EntryFor(self: Hover, Key: any): any
	const Renderer = self.Graph.Renderer
	const Layout = Renderer and Renderer.Layout
	const Item = Layout and Layout.Items and Layout.Items[Key]
	if Item and Item.Entry then
		return Item.Entry
	end
	return if typeof(Key) == "number" then self.Graph.Data[Key] else nil
end


function Hover._HitTest(self: Hover, Local: Vector2): any
	const Renderer = self.Graph.Renderer
	if Renderer and (Renderer.HitTest::any) then
		return Renderer:HitTest(Local)
	end
	return nil
end

function Hover._GetDriver(self: Hover, Key: any): NumberValue
	local Driver = self._Drivers[Key]
	if not Driver then
		const Created: NumberValue = self.Graph:_GetDriver(`Hover_{tostring(Key)}`)
		Created.Value = 0
		table.insert(self._Connections, Created.Changed:Connect(function()
			self.Graph:RequestRender()
		end))
		self._Drivers[Key] = Created
		Driver = Created
	end
	return Driver
end

function Hover._BindInput(self: Hover)
	const Target: GuiObject = self.Graph.UI

	const function Handle(Local: Vector2)
		if not self.Enabled then
			self:SetKey(nil)
			return
		end
		self:SetKey(self:_HitTest(Local))
	end

	table.insert(self._Connections, Target.MouseMoved:Connect(function(X: number, Y: number)
		Handle(Vector2.new(X, Y) - (Target.AbsolutePosition + GuiInset))
	end))
	table.insert(self._Connections, Target.MouseLeave:Connect(function()
		self:SetKey(nil)
	end))

	const function TouchLocal(Input: InputObject): Vector2
		return Vector2.new(Input.Position.X, Input.Position.Y) - Target.AbsolutePosition
	end
	table.insert(self._Connections, Target.InputBegan:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch then
			Handle(TouchLocal(Input))
		end
	end))
	table.insert(self._Connections, Target.InputChanged:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch then
			Handle(TouchLocal(Input))
		end
	end))
	table.insert(self._Connections, Target.InputEnded:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch then
			self:SetKey(nil)
		end
	end))

	-- The click hit-tests the release position itself, so the order of InputEnded handlers does not matter
	for _, Connection in GuiUtil.ClickDetector(Target, function(Local: Vector2)
		const OnClick = self.OnClick
		if not self.Enabled or not OnClick then
			return
		end
		const Key = self:_HitTest(Local)
		if Key ~= nil then
			OnClick(Key, self:_EntryFor(Key))
		end
	end) do
		table.insert(self._Connections, Connection)
	end
end

return Hover
