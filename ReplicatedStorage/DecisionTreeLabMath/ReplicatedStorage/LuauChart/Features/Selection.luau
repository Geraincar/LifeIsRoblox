--!strict
--!native
--!optimize 2
-- Selection (Class): pointer navigation for Cartesian charts. A left drag zooms into the dragged rectangle
-- (Mode "Zoom") or pans (Mode "Pan"), a middle button drag always pans, the mouse wheel zooms around the
-- pointer (X by default, Y with Shift, both with Ctrl) and a right click resets the view.

-- ─── Services ────────────────────────────────────────────────────────────────

const UserInputService = game:GetService("UserInputService")

-- ─── Configuration ───────────────────────────────────────────────────────────

const MIN_DRAG_PIXELS = 6
const MIN_SPAN = 0.002 -- smallest normalized view span the wheel can zoom to

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Mode = "Zoom" | "Pan"

type Fields = {
	Graph: any,
	UI: Frame?,
	Enabled: boolean,
	Mode: Mode,
	ResetOnRightClick: boolean,
	Wheel: boolean,
	WheelStep: number,
	Pan: boolean,
	TweenInfo: TweenInfo,
	_Dragging: boolean,
	_Panning: boolean,
	_StartLocal: Vector2,
	_LastLocal: Vector2,
	_PanStart: { X: NumberRange, Y: NumberRange }?,
	_Connections: { RBXScriptConnection },
}

local Selection = {}
Selection.__index = Selection

export type Selection = typeof(setmetatable({} :: Fields, Selection))

-- ─── Internal ────────────────────────────────────────────────────────────────

const function IsPointer(Input: InputObject): boolean
	return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

const function IsMiddle(Input: InputObject): boolean
	return Input.UserInputType == Enum.UserInputType.MouseButton3
end

-- A normalized range moved by Shift, kept inside 0..1 with its span intact
const function Shifted(Range: NumberRange, Shift: number): NumberRange
	const Span = Range.Max - Range.Min
	local Min = Range.Min + Shift
	if Min < 0 then
		Min = 0
	elseif Min + Span > 1 then
		Min = 1 - Span
	end
	return NumberRange.new(Min, Min + Span)
end

-- A normalized range scaled by Factor around the point at Alpha through it, kept inside 0..1
const function Scaled(Range: NumberRange, Factor: number, Alpha: number): NumberRange
	const OldSpan = Range.Max - Range.Min
	const Span = math.clamp(OldSpan * Factor, MIN_SPAN, 1)
	const Anchor = Range.Min + OldSpan * Alpha
	local Min = Anchor - Span * Alpha
	if Min < 0 then
		Min = 0
	elseif Min + Span > 1 then
		Min = 1 - Span
	end
	return NumberRange.new(Min, Min + Span)
end

-- ─── Construction ────────────────────────────────────────────────────────────

function Selection.new(Graph: any): Selection
	const self = setmetatable({} :: Fields, Selection)

	self.Graph = Graph
	self.UI = Graph.UI:FindFirstChild("Selection")
	self.Enabled = true
	self.Mode = "Zoom" -- what a left drag or a touch drag does
	self.ResetOnRightClick = true
	self.Wheel = true -- the mouse wheel zooms around the pointer
	self.WheelStep = 0.15 -- fraction of the visible span one wheel notch removes or adds
	self.Pan = true -- a middle button drag pans
	self.TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	self._Dragging = false
	self._Panning = false
	self._StartLocal = Vector2.zero
	self._LastLocal = Vector2.zero
	self._PanStart = nil
	self._Connections = {}

	if self.UI then
		self.UI.Visible = false
		self:_Bind()
	end

	return self
end

-- ─── API ─────────────────────────────────────────────────────────────────────

function Selection.SetEnabled(self: Selection, State: boolean)
	self.Enabled = State
	if not State then
		self:_Cancel()
	end
end

-- Zooms the view by Factor (below 1 zooms in) around a chart-relative point given in 0..1 fractions
function Selection.ZoomAt(self: Selection, Factor: number, AlphaX: number, AlphaY: number, ZoomX: boolean, ZoomY: boolean)
	const View = self.Graph.ViewRange
	self.Graph:SetViewRange({
		X = ZoomX and Scaled(View.X, Factor, math.clamp(AlphaX, 0, 1)) or View.X,
		-- Screen Y runs down, the view range runs up
		Y = ZoomY and Scaled(View.Y, Factor, 1 - math.clamp(AlphaY, 0, 1)) or View.Y,
	})
end

-- Pans the view by a pixel delta, as if the chart were dragged by that much
function Selection.PanBy(self: Selection, Delta: Vector2, From: { X: NumberRange, Y: NumberRange }?)
	const Size: Vector2 = self.Graph.UI.AbsoluteSize
	if Size.X <= 0 or Size.Y <= 0 then
		return
	end
	const View = From or self.Graph.ViewRange
	const SpanX = View.X.Max - View.X.Min
	const SpanY = View.Y.Max - View.Y.Min
	self.Graph:SetViewRange({
		X = Shifted(View.X, -Delta.X / Size.X * SpanX),
		Y = Shifted(View.Y, Delta.Y / Size.Y * SpanY),
	})
end

function Selection.Destroy(self: Selection)
	for _, Connection in self._Connections do
		Connection:Disconnect()
	end
	table.clear(self._Connections)
end

-- ─── Drag ────────────────────────────────────────────────────────────────────

function Selection._Cancel(self: Selection)
	self._Dragging = false
	self._Panning = false
	self._PanStart = nil
	if self.UI then
		self.UI.Visible = false
	end
end

function Selection._IsInside(self: Selection, Position: Vector3): boolean
	const AbsolutePosition: Vector2 = self.Graph.UI.AbsolutePosition
	const AbsoluteSize: Vector2 = self.Graph.UI.AbsoluteSize

	return Position.X >= AbsolutePosition.X and Position.X <= AbsolutePosition.X + AbsoluteSize.X
		and Position.Y >= AbsolutePosition.Y and Position.Y <= AbsolutePosition.Y + AbsoluteSize.Y
end

function Selection._GetLocalFromInput(self: Selection, Input: InputObject): Vector2
	const AbsolutePosition: Vector2 = self.Graph.UI.AbsolutePosition
	const AbsoluteSize: Vector2 = self.Graph.UI.AbsoluteSize
	const Position = Input.Position

	return Vector2.new(
		math.clamp(Position.X - AbsolutePosition.X, 0, AbsoluteSize.X),
		math.clamp(Position.Y - AbsolutePosition.Y, 0, AbsoluteSize.Y)
	)
end

function Selection._LocalToData(self: Selection, Local: Vector2): (number, number)
	const AbsoluteSize: Vector2 = self.Graph.UI.AbsoluteSize
	const Visible = self.Graph:GetVisibleBounds()

	const XAlpha = AbsoluteSize.X > 0 and Local.X / AbsoluteSize.X or 0
	const YAlpha = AbsoluteSize.Y > 0 and Local.Y / AbsoluteSize.Y or 0

	return math.lerp(Visible.X.Min, Visible.X.Max, XAlpha), math.lerp(Visible.Y.Max, Visible.Y.Min, YAlpha)
end

function Selection._UpdateRect(self: Selection)
	const UI = self.UI
	if not UI then
		return
	end
	const Start, Last = self._StartLocal, self._LastLocal
	const Min = Vector2.new(math.min(Start.X, Last.X), math.min(Start.Y, Last.Y))
	const Max = Vector2.new(math.max(Start.X, Last.X), math.max(Start.Y, Last.Y))

	UI.Position = UDim2.fromOffset(Min.X, Min.Y)
	UI.Size = UDim2.fromOffset(Max.X - Min.X, Max.Y - Min.Y)
end

function Selection._Finish(self: Selection)
	const UI = self.UI
	const Size = UI and UI.AbsoluteSize or Vector2.zero
	if Size.X < MIN_DRAG_PIXELS or Size.Y < MIN_DRAG_PIXELS then
		self:_Cancel()
		return
	end

	const StartX, StartY = self:_LocalToData(self._StartLocal)
	const EndX, EndY = self:_LocalToData(self._LastLocal)

	self:_Cancel()

	self.Graph:SetViewFromBounds({
		X = NumberRange.new(math.min(StartX, EndX), math.max(StartX, EndX)),
		Y = NumberRange.new(math.min(StartY, EndY), math.max(StartY, EndY)),
	}, self.TweenInfo)
end

function Selection._BeginPan(self: Selection, Input: InputObject)
	self._Panning = true
	self._StartLocal = self:_GetLocalFromInput(Input)
	self._LastLocal = self._StartLocal
	const View = self.Graph.ViewRange
	self._PanStart = { X = View.X, Y = View.Y }
end

function Selection._Bind(self: Selection)
	table.insert(self._Connections, UserInputService.InputBegan:Connect(function(Input: InputObject)
		if not self.Enabled or self._Dragging or self._Panning then
			return
		end

		if Input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.ResetOnRightClick and self:_IsInside(Input.Position) then
				self.Graph:ResetView(self.TweenInfo)
			end
			return
		end

		if not self:_IsInside(Input.Position) then
			return
		end

		if IsMiddle(Input) and self.Pan then
			self:_BeginPan(Input)
			return
		end
		if not IsPointer(Input) then
			return
		end
		if self.Mode == "Pan" then
			self:_BeginPan(Input)
			return
		end

		self._Dragging = true
		self._StartLocal = self:_GetLocalFromInput(Input)
		self._LastLocal = self._StartLocal

		if self.UI then
			self.UI.Visible = true
		end
		self:_UpdateRect()
	end))

	table.insert(self._Connections, UserInputService.InputChanged:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.MouseWheel then
			if self.Enabled and self.Wheel and not self._Dragging and not self._Panning and self:_IsInside(Input.Position) then
				const Local = self:_GetLocalFromInput(Input)
				const Size: Vector2 = self.Graph.UI.AbsoluteSize
				const Factor = 1 - math.sign(Input.Position.Z) * self.WheelStep
				const Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				const Control = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				self:ZoomAt(Factor, Local.X / math.max(Size.X, 1), Local.Y / math.max(Size.Y, 1), not Shift or Control, Shift or Control)
			end
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self._Panning then
			self._LastLocal = self:_GetLocalFromInput(Input)
			self:PanBy(self._LastLocal - self._StartLocal, self._PanStart)
		elseif self._Dragging then
			self._LastLocal = self:_GetLocalFromInput(Input)
			self:_UpdateRect()
		end
	end))

	table.insert(self._Connections, UserInputService.InputEnded:Connect(function(Input: InputObject)
		if self._Panning and (IsMiddle(Input) or IsPointer(Input)) then
			self:_Cancel()
		elseif self._Dragging and IsPointer(Input) then
			self:_Finish()
		end
	end))
end

return Selection
