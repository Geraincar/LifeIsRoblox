--!strict
--!native
--!optimize 2
-- BaseGraph (Class): what every chart type shares. UI clone, camera, render scheduling, data animation and
-- cleanup. Chart classes derive from it, so its methods take any chart as self.

-- ─── Services ────────────────────────────────────────────────────────────────

const TweenService = game:GetService("TweenService")

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Animator = require(script.Parent.Animator)

-- ─── Configuration ───────────────────────────────────────────────────────────

const FEATURE_KEYS = { "Grid", "Cursor", "Selection", "References", "Labels", "Categories", "Hover" }

-- ─── Types ───────────────────────────────────────────────────────────────────

-- The fields every chart instance carries; chart classes list them again in their own field types
export type Fields = {
	UI: GuiObject,
	Data: { any },
	AutoViewportSize: boolean,
	EntryAnimation: TweenInfo?,
	Simplify: number,
	MotionSimplify: number,
	Type: string?,
	RendererType: string?,
	Renderer: any,
	_Camera: Camera,
	_HasData: boolean,
	_AnimationTarget: any,
	_Connections: { RBXScriptConnection },
	_DriverTweens: { [string]: Tween },
	_DriverConnections: { [string]: RBXScriptConnection },
	_RenderPending: boolean,
	_Destroyed: boolean,
}

local BaseGraph = {}
BaseGraph.__index = BaseGraph

-- ─── Construction ────────────────────────────────────────────────────────────

function BaseGraph.new(Template: GuiObject): any
	const self: any = setmetatable({}, BaseGraph)

	self.UI = Template:Clone()
	self.Data = {}
	self.AutoViewportSize = true -- re-render whenever the UI is resized
	self.EntryAnimation = nil :: TweenInfo? -- when set, the first data call animates in

	-- How far (pixels) a drawn line may sit from its samples: samples that only pad a straight stretch are
	-- not drawn. MotionSimplify applies while a driver tween runs, so animation frames draw fewer segments
	-- and the chart settles on the exact line when the tween ends.
	self.Simplify = 0.35
	self.MotionSimplify = 1

	self._HasData = false
	self._AnimationTarget = nil -- the data a running animation heads for; the auto fit reads it
	self._Connections = {}
	self._DriverTweens = {}
	self._DriverConnections = {}
	self._RenderPending = false
	self._Destroyed = false

	self:_CreateCamera()

	-- The live UI (not the template) leaving the tree is the signal to clean up
	const UI: GuiObject = self.UI
	table.insert(self._Connections, UI.AncestryChanged:Connect(function(_, Parent: Instance?)
		if Parent == nil then
			self:Destroy()
		end
	end))

	-- The projection depends on the aspect ratio
	table.insert(self._Connections, UI:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.AutoViewportSize then
			self:RequestRender()
		end
	end))

	return self
end

-- A near-orthographic camera views the chart's 3D assets
function BaseGraph._CreateCamera(self: any)
	const Camera = Instance.new("Camera")
	Camera.Name = "ChartCamera"
	Camera.FieldOfView = 1
	Camera.Parent = self.UI

	self._Camera = Camera
end

-- ─── Data ────────────────────────────────────────────────────────────────────
-- Series-based charts override these hooks

function BaseGraph._GetData(self: any): any
	return self.Data
end

function BaseGraph._ApplyData(self: any, Data: any, RecomputeBounds: boolean)
	self.Data = Data
	if RecomputeBounds and (self._UpdateProcessedBounds::any) then
		self:_UpdateProcessedBounds()
	end
end

function BaseGraph._BlendData(self: any, From: any, To: any, Alpha: number): any
	return Animator.BlendList(From, To, Alpha)
end

function BaseGraph._ZeroData(self: any, Data: any): any
	return Animator.ZeroList(Data)
end

-- Sets data, animating from the current data, or from a zero baseline on the first call with EntryAnimation
function BaseGraph._SetData(self: any, Target: any, Animate: TweenInfo?)
	const First = not self._HasData
	self._HasData = true

	const Info = Animate or (if First then self.EntryAnimation else nil)
	if Info then
		if First then
			self:_ApplyData(self:_ZeroData(Target), false)
		end
		self:AnimateTo(Target, Info)
	else
		self._AnimationTarget = nil
		self:_ApplyData(Target, true)
		self:_InternalUpdate()
	end
end

-- Morphs the chart from its current data to Target. Axes and the auto fit settle on the final data
-- immediately: the target stays stored for the length of the tween, so a fit computed mid-animation (after
-- a zoom, say) still reads the data the chart is heading for rather than the blend of the moment.
function BaseGraph.AnimateTo(self: any, Target: any, TweenInfoObject: TweenInfo?)
	const From = self:_GetData()
	self._HasData = true
	self._AnimationTarget = Target
	self:_ApplyData(Target, true)

	self:_TweenDriver("Animation", 0, 1, TweenInfoObject or TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		function(Alpha: number)
			self:_ApplyData(self:_BlendData(From, Target, Alpha), false)
			self:RequestRender()
		end,
		function()
			self._AnimationTarget = nil
			self:_ApplyData(Target, false)
			self:RequestRender()
		end
	)
end

-- ─── Drivers ─────────────────────────────────────────────────────────────────
-- NumberValues under UI.Drivers, so TweenService can animate any chart quantity

function BaseGraph._GetDriver(self: any, Name: string): NumberValue
	const UI: GuiObject = self.UI
	local Folder = UI:FindFirstChild("Drivers")
	if not Folder then
		const Created = Instance.new("Configuration")
		Created.Name = "Drivers"
		Created.Parent = UI
		Folder = Created
	end
	const Holder = Folder :: Instance

	local Driver = Holder:FindFirstChild(Name)
	if not Driver then
		const Created = Instance.new("NumberValue")
		Created.Name = Name
		Created.Parent = Holder
		Driver = Created
	end
	return Driver :: NumberValue
end

-- Tweens the named driver from From to To, calling OnStep with every value, From included right away
function BaseGraph._TweenDriver(self: any, Name: string, From: number, To: number, Info: TweenInfo, OnStep: (number) -> (), OnDone: (() -> ())?)
	const Driver = self:_GetDriver(Name)

	const OldTween: Tween? = self._DriverTweens[Name]
	if OldTween then
		OldTween:Cancel()
	end
	const OldConnection: RBXScriptConnection? = self._DriverConnections[Name]
	if OldConnection then
		OldConnection:Disconnect()
	end

	Driver.Value = From
	OnStep(From)

	const Connection = Driver.Changed:Connect(OnStep)
	self._DriverConnections[Name] = Connection

	const Tween = TweenService:Create(Driver, Info, { Value = To })
	self._DriverTweens[Name] = Tween
	Tween.Completed:Connect(function(State: Enum.PlaybackState)
		if State ~= Enum.PlaybackState.Completed then
			return
		end
		Connection:Disconnect()
		if self._DriverConnections[Name] == Connection then
			self._DriverConnections[Name] = nil
		end
		if self._DriverTweens[Name] == Tween then
			self._DriverTweens[Name] = nil
		end
		if OnDone then
			OnDone()
		end
	end)
	Tween:Play()
end

-- Whether a driver tween is running, so a renderer can draw a cheaper frame while things move
function BaseGraph.IsAnimating(self: any): boolean
	return next(self._DriverTweens) ~= nil
end

-- The simplification tolerance in pixels for this frame (see Simplify and MotionSimplify)
function BaseGraph.GetSimplify(self: any): number
	return if self:IsAnimating() then self.MotionSimplify else self.Simplify
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function BaseGraph._InternalUpdate(self: any)
	if self._Destroyed then
		return
	end

	if self.Renderer and (self.Renderer.Update::any) then
		self.Renderer:Update()
	end

	for _, Key in FEATURE_KEYS do
		const Feature = self[Key]
		if Feature and Feature.Update then
			Feature:Update()
		end
	end
end

-- Any number of requests in one frame become a single update
function BaseGraph.RequestRender(self: any)
	if self._RenderPending or self._Destroyed then
		return
	end
	self._RenderPending = true

	task.defer(function()
		self._RenderPending = false
		self:_InternalUpdate()
	end)
end

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

function BaseGraph.Destroy(self: any)
	if self._Destroyed then
		return
	end
	self._Destroyed = true

	for _, Connection in self._Connections :: { RBXScriptConnection } do
		Connection:Disconnect()
	end
	table.clear(self._Connections)

	for _, Tween in self._DriverTweens :: { [string]: Tween } do
		Tween:Cancel()
	end
	table.clear(self._DriverTweens)
	self._AnimationTarget = nil
	for _, Connection in self._DriverConnections :: { [string]: RBXScriptConnection } do
		Connection:Disconnect()
	end
	table.clear(self._DriverConnections)

	if self.Renderer and (self.Renderer.Destroy::any) then
		self.Renderer:Destroy()
	end

	for _, Key in FEATURE_KEYS do
		const Feature = self[Key]
		if Feature and Feature.Destroy then
			Feature:Destroy()
		end
	end

	if self.UI then
		self.UI:Destroy()
	end

	table.clear(self.Data)
end

return BaseGraph
