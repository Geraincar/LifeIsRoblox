--!strict
--!native
--!optimize 2
-- Grid (Class): axis lines and labels for Cartesian charts
-- Per-axis Properties: Visible; Mode "Nice" (round values, Amount is a target count) or "Even" (Amount
-- divisions between min and max); Amount; Step (explicit spacing in data units, overrides Mode); Ticks
-- (explicit values, overrides everything); Transform (value to label text); Lines and Labels switches.

-- ─── Configuration ───────────────────────────────────────────────────────────

const AXES = { "X", "Y" }
const MAX_TICKS = 200

-- ─── Types ───────────────────────────────────────────────────────────────────

export type AxisProperties = {
	Visible: boolean?,
	Amount: number?,
	Step: number?,
	Ticks: { number }?,
	Transform: ((Value: number) -> any)?,
	Mode: string?,
	Lines: boolean?,
	Labels: boolean?,
}

type Fields = {
	Graph: any,
	UI: Frame?,
	Visible: boolean,
	Properties: { X: AxisProperties, Y: AxisProperties },
	_Templates: { [string]: Frame },
	_LineTransparency: { [string]: number },
	_Pools: { [string]: { Frame } },
}

local Grid = {}
Grid.__index = Grid

export type Grid = typeof(setmetatable({} :: Fields, Grid))

-- ─── Internal ────────────────────────────────────────────────────────────────

const function NiceStep(Span: number, Target: number): number
	if Span <= 0 or Target < 1 then
		return Span
	end
	const Raw = Span / Target
	const Magnitude = 10 ^ math.floor(math.log10(Raw))
	const Normalized = Raw / Magnitude
	-- Rounding to the nearest nice multiplier keeps the tick count close to the target
	const Nice = if Normalized < 1.5 then 1
		elseif Normalized < 2.25 then 2
		elseif Normalized < 3.5 then 2.5
		elseif Normalized < 7.5 then 5
		else 10
	return Nice * Magnitude
end

-- Multiple * Step rounded to the precision the step implies, so labels never show float noise
const function Tick(Multiple: number, Step: number): number
	const Decimals = math.clamp(-math.floor(math.log10(Step)) + 1, 0, 10)
	const Value = tonumber(string.format(`%.{Decimals}f`, Multiple * Step)) or Multiple * Step
	-- Adding zero turns a negative zero into plain zero, so labels never read "-0"
	return Value + 0
end

-- ─── Construction ────────────────────────────────────────────────────────────

function Grid.new(Graph: any): Grid
	const self = setmetatable({} :: Fields, Grid)

	self.Graph = Graph
	self.UI = Graph.UI:FindFirstChild("Grid")
	self.Visible = false

	const function Plain(Value: number): any
		return tostring(Value)
	end
	self.Properties = {
		X = { Visible = true, Amount = 6, Transform = Plain, Mode = "Nice" },
		Y = { Visible = true, Amount = 6, Transform = Plain, Mode = "Nice" },
	}

	self._Templates = {}
	self._LineTransparency = {}
	self._Pools = {
		X = {},
		Y = {},
	}

	const UI = self.UI
	if UI then
		UI.Visible = false
		for _, Axis in AXES do
			const AxisUI = UI:FindFirstChild(Axis)
			const Layout = if AxisUI then AxisUI:FindFirstChild("[UI] Layout") else nil
			const Template = if Layout then Layout:FindFirstChild("Template") else nil
			if Layout and Template and Template:IsA("Frame") then
				self._Templates[Axis] = Template
				self._LineTransparency[Axis] = Template.BackgroundTransparency
				-- Ticks are positioned absolutely; the layout only held the template
				Layout.Parent = nil
			end
		end
	end

	return self
end

-- ─── Ticks ───────────────────────────────────────────────────────────────────

function Grid._EnsurePool(self: Grid, Axis: string, NeededCount: number): { Frame }
	const UI = self.UI :: Frame
	const AxisUI = UI:FindFirstChild(Axis)
	const Template = self._Templates[Axis]
	const Pool = self._Pools[Axis]

	if Template and AxisUI then
		for Index = #Pool + 1, NeededCount do
			const Item = Template:Clone()
			Item.Parent = AxisUI
			Pool[Index] = Item
		end
	end

	for Index = 1, #Pool do
		Pool[Index].Visible = Index <= NeededCount
	end

	return Pool
end

function Grid._ComputeTicks(self: Grid, AxisProperties: AxisProperties, Min: number, Max: number): { number }
	const Explicit = AxisProperties.Ticks
	if Explicit then
		const Ticks: { number } = {}
		for _, Value in Explicit do
			if Value >= Min and Value <= Max then
				table.insert(Ticks, Value)
			end
		end
		return Ticks
	end

	const Amount = AxisProperties.Amount or 6
	assert(typeof(Amount) == "number" and Amount >= 0, "Grid: Amount must be a number >= 0")

	if (AxisProperties.Mode or "Nice") == "Even" and not AxisProperties.Step then
		const Ticks: {number} = (table.create(Amount + 2)::{number}) -- Remove the :: and see why it's there
		for Division = 0, Amount + 1 do
			Ticks[Division + 1] = Min + (Max - Min) * (Division / (Amount + 1))
		end
		return Ticks
	end

	const Step = AxisProperties.Step or NiceStep(Max - Min, Amount + 1)
	if Step <= 0 then
		return { Min, Max }
	end

	const FirstMultiple = math.ceil(Min / Step - 1e-9)
	const LastMultiple = math.floor(Max / Step + 1e-9)
	const Ticks: { number } = {}
	for Multiple = FirstMultiple, math.min(LastMultiple, FirstMultiple + MAX_TICKS) do
		table.insert(Ticks, Tick(Multiple, Step))
	end
	return Ticks
end

-- ─── API ─────────────────────────────────────────────────────────────────────

function Grid.SetVisible(self: Grid, IsVisible: boolean)
	self.Visible = IsVisible
	const UI = self.UI
	if UI then
		UI.Visible = IsVisible
	end
	if IsVisible then
		self:Update()
	end
end

function Grid.Update(self: Grid)
	const UI = self.UI
	if not self.Visible or not UI then
		return
	end

	const Visible = self.Graph:GetVisibleBounds()

	for _, Axis in AXES do
		const AxisProperties = (self.Properties :: any)[Axis] :: AxisProperties?
		const AxisUI = UI:FindFirstChild(Axis)
		if not AxisUI or not AxisUI:IsA("GuiObject") then
			continue
		end

		if not AxisProperties or AxisProperties.Visible == false then
			AxisUI.Visible = false
			continue
		end
		AxisUI.Visible = true

		const Transform: (number) -> any = AxisProperties.Transform or tostring
		const AxisRange: NumberRange = Visible[Axis]
		const AxisMin, AxisMax = AxisRange.Min, AxisRange.Max
		const Span = if AxisMax == AxisMin then 1 else AxisMax - AxisMin

		const Ticks = self:_ComputeTicks(AxisProperties, AxisMin, AxisMax)
		const Pool = self:_EnsurePool(Axis, #Ticks)

		for Index, Value in Ticks do
			const Item = Pool[Index]
			if not Item then
				break
			end
			const Alpha = (Value - AxisMin) / Span

			if Axis == "X" then
				Item.AnchorPoint = Vector2.new(0.5, 0)
				Item.Position = UDim2.fromScale(Alpha, 0)
			else
				Item.AnchorPoint = Vector2.new(0, 0.5)
				Item.Position = UDim2.fromScale(0, 1 - Alpha)
			end

			Item.Name = tostring(Index)
			Item.BackgroundTransparency = if AxisProperties.Lines == false then 1 else (self._LineTransparency[Axis] or 0)
			const Display = Item:FindFirstChild("Display")
			if Display and Display:IsA("TextLabel") then
				Display.Visible = AxisProperties.Labels ~= false
				Display.Text = tostring(Transform(Value))
			end
		end
	end
end

function Grid.Destroy(self: Grid)
	for _, Pool in self._Pools do
		for _, Item in Pool do
			Item:Destroy()
		end
		table.clear(Pool)
	end
	for _, Template in self._Templates do
		const Holder = Template.Parent
		if Holder then
			Holder:Destroy()
		end
	end
	table.clear(self._Templates)
end

return Grid
