--!strict
--!native
--!optimize 2
-- References (Class): reference lines (thresholds, targets) and highlighted bands on Cartesian charts.
-- Pure GUI, so it works with both renderers. Positions follow the visible bounds, so they pan and zoom with
-- the data.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const GuiUtil = require(script.Parent.Parent.Internal.GuiUtil)
const Types = require(script.Parent.Parent.Types)

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Graph: any,
	Style: Types.TextStyle,
	Lines: { Types.Reference },
	Bands: { Types.Band },
	LinesContainer: Frame,
	BandsContainer: Frame,
	_LineUI: { Frame },
	_BandUI: { Frame },
}

local References = {}
References.__index = References

export type References = typeof(setmetatable({} :: Fields, References))

-- ─── Internal ────────────────────────────────────────────────────────────────

const function Alpha(Value: number, Range: NumberRange): number
	const Span = Range.Max - Range.Min
	if Span == 0 then
		return 0
	end
	return (Value - Range.Min) / Span
end

-- ─── Construction ────────────────────────────────────────────────────────────

function References.new(Graph: any): References
	const self = setmetatable({} :: Fields, References)

	self.Graph = Graph
	self.Style = {}

	self.Lines = {} -- Types.Reference specs
	self.Bands = {} -- Types.Band specs

	self.LinesContainer = GuiUtil.Container(Graph.UI, "References", 2)
	self.BandsContainer = GuiUtil.Container(Graph.UI, "Bands", 0)

	self._LineUI = {}
	self._BandUI = {}

	return self
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Spec: { Axis = "X" | "Y", Value, Color?, Thickness?, Transparency?, Label? }
function References.AddLine(self: References, Spec: Types.Reference): Types.Reference
	table.insert(self.Lines, Spec)
	self:Update()
	return Spec
end

-- Spec: { Axis = "X" | "Y", Min, Max, Color?, Transparency? }
function References.AddBand(self: References, Spec: Types.Band): Types.Band
	table.insert(self.Bands, Spec)
	self:Update()
	return Spec
end

function References.Remove(self: References, Spec: any)
	const LineIndex = table.find(self.Lines, Spec)
	if LineIndex then
		table.remove(self.Lines, LineIndex)
	end
	const BandIndex = table.find(self.Bands, Spec)
	if BandIndex then
		table.remove(self.Bands, BandIndex)
	end
	self:Update()
end

function References.Clear(self: References)
	table.clear(self.Lines)
	table.clear(self.Bands)
	self:Update()
end

-- ─── Rendering ───────────────────────────────────────────────────────────────

function References._GetLineUI(self: References, Index: number): Frame
	const Existing = self._LineUI[Index]
	if Existing then
		return Existing
	end

	const Frame = Instance.new("Frame")
	Frame.Name = "Line"
	Frame.BorderSizePixel = 0
	-- Explicit ZIndex keeps it above the chart layers under global z-ordering
	Frame.ZIndex = self.LinesContainer.ZIndex + 1

	const Label = GuiUtil.TextLabel(self.Style)
	Label.Name = "Label"
	Label.ZIndex = self.LinesContainer.ZIndex + 2
	Label.Parent = Frame

	Frame.Parent = self.LinesContainer
	self._LineUI[Index] = Frame
	return Frame
end

function References._GetBandUI(self: References, Index: number): Frame
	const Existing = self._BandUI[Index]
	if Existing then
		return Existing
	end

	const Frame = Instance.new("Frame")
	Frame.Name = "Band"
	Frame.BorderSizePixel = 0
	Frame.ZIndex = self.BandsContainer.ZIndex + 1
	Frame.Parent = self.BandsContainer
	self._BandUI[Index] = Frame
	return Frame
end

function References.Update(self: References)
	const Visible: Types.Bounds = self.Graph:GetVisibleBounds()

	for Index, Spec in self.Lines do
		const Frame = self:_GetLineUI(Index)
		const Label = Frame:FindFirstChild("Label") :: TextLabel
		const Axis = Spec.Axis or "Y"
		const Along = Alpha(Spec.Value, if Axis == "X" then Visible.X else Visible.Y)
		const Thickness = Spec.Thickness or 1

		Frame.Visible = Along >= 0 and Along <= 1
		Frame.BackgroundColor3 = Spec.Color or Color3.new(1, 1, 1)
		Frame.BackgroundTransparency = Spec.Transparency or 0.3

		if Axis == "Y" then
			Frame.AnchorPoint = Vector2.new(0, 0.5)
			Frame.Position = UDim2.fromScale(0, 1 - Along)
			Frame.Size = UDim2.new(1, 0, 0, Thickness)
			Label.AnchorPoint = Vector2.new(1, 1)
			Label.Position = UDim2.new(1, -4, 0, -2)
		else
			Frame.AnchorPoint = Vector2.new(0.5, 0)
			Frame.Position = UDim2.fromScale(Along, 0)
			Frame.Size = UDim2.new(0, Thickness, 1, 0)
			Label.AnchorPoint = Vector2.new(0, 0)
			Label.Position = UDim2.new(1, 4, 0, 2)
		end

		GuiUtil.ApplyTextStyle(Label, self.Style)
		Label.Text = Spec.Label or ""
		Label.Visible = Spec.Label ~= nil
	end
	for Index = #self.Lines + 1, #self._LineUI do
		self._LineUI[Index].Visible = false
	end

	for Index, Spec in self.Bands do
		const Frame = self:_GetBandUI(Index)
		const Axis = Spec.Axis or "X"
		const Range = if Axis == "X" then Visible.X else Visible.Y
		const AlphaMin = math.clamp(Alpha(math.min(Spec.Min, Spec.Max), Range), 0, 1)
		const AlphaMax = math.clamp(Alpha(math.max(Spec.Min, Spec.Max), Range), 0, 1)

		Frame.Visible = AlphaMax > AlphaMin
		Frame.BackgroundColor3 = Spec.Color or Color3.new(1, 1, 1)
		Frame.BackgroundTransparency = Spec.Transparency or 0.85

		if Axis == "Y" then
			Frame.Position = UDim2.fromScale(0, 1 - AlphaMax)
			Frame.Size = UDim2.fromScale(1, AlphaMax - AlphaMin)
		else
			Frame.Position = UDim2.fromScale(AlphaMin, 0)
			Frame.Size = UDim2.fromScale(AlphaMax - AlphaMin, 1)
		end
	end
	for Index = #self.Bands + 1, #self._BandUI do
		self._BandUI[Index].Visible = false
	end
end

function References.Destroy(self: References)
	for _, Frame in self._LineUI do
		Frame:Destroy()
	end
	for _, Frame in self._BandUI do
		Frame:Destroy()
	end
	table.clear(self._LineUI)
	table.clear(self._BandUI)
end

return References
