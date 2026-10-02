--!strict
--!native
--!optimize 2
-- Categories (Class): category labels for bar charts, the name of each slot. The text comes from the
-- entries' Label field by default, through the same layers as value labels: chart defaults here, and a
-- Format callback that returns nil, a string, or a Types.LabelSpec for one slot.
--
-- Placement: "Axis" (chart edge on the slot axis: left on horizontal charts, bottom on vertical ones),
-- "Above" and "Below" (just outside the slot's bars), "Before" and "After" (before the bars' start, past
-- their end). Align applies to Above and Below on horizontal charts and Before and After on vertical ones:
-- "Start" | "Center" | "End" | "Zero" (over the zero line). Above and Below on horizontal charts sit between
-- the slots, so the bar layout keeps room for them (SlotReserve) and shrinks the bars when BarRatio would not.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Labels = require(script.Parent.Labels)
const Types = require(script.Parent.Parent.Types)

-- ─── Configuration ───────────────────────────────────────────────────────────

-- Labels are clones of the GuiUtil template, so its text size is a label's height
const LabelTemplate = script.Parent.Parent.Internal.GuiUtil:FindFirstChild("Label")
const TEMPLATE_TEXT_SIZE: number = (LabelTemplate and LabelTemplate:IsA("TextLabel")) and LabelTemplate.TextSize or 14
const RESERVE_MARGIN = 0 -- pixels kept between a slot-axis label and the neighbouring slot

-- ─── Types ───────────────────────────────────────────────────────────────────

export type SlotData = { Index: number, Label: string, Entries: { any } }

type Fields = {
	Graph: any,
	Enabled: boolean,
	Placement: string,
	Align: string,
	Offset: number,
	Style: Types.TextStyle,
	Format: ((Slot: SlotData, Info: any) -> any)?,
	DefaultFormat: ((Slot: SlotData, Info: any) -> any)?,
	_Layer: Labels.Labels,
}

local Categories = {}
Categories.__index = Categories

export type Categories = typeof(setmetatable({} :: Fields, Categories))

-- ─── Internal ────────────────────────────────────────────────────────────────

const function FirstLabel(Entries: { any }): string?
	for _, Entry in Entries do
		if Entry.Label ~= nil then
			return tostring(Entry.Label)
		end
	end
	return nil
end

-- ─── Construction ────────────────────────────────────────────────────────────

function Categories.new(Graph: any): Categories
	const self = setmetatable({} :: Fields, Categories)

	self.Graph = Graph
	self.Enabled = false
	self.Placement = "Axis"
	self.Align = "Start"
	self.Offset = 4 -- gap from the anchor point, in pixels
	self.Style = {}

	self.Format = nil -- (Slot, Info) -> nil | string | LabelSpec; Slot = { Index, Label, Entries }
	self.DefaultFormat = function(Slot: SlotData)
		return Slot.Label
	end

	self._Layer = Labels.new(Graph, "Categories")

	return self
end

-- ─── Placement ───────────────────────────────────────────────────────────────

-- Position and text anchor for a slot. Rect is the union of the slot's bars, Band the slot's extent on the
-- slot axis, Zero the pixel coordinate of value zero along the bars.
function Categories._Place(self: Categories, Placement: string, Offset: number, Slot: Types.Slot, Horizontal: boolean, Size: Vector2, Zero: number): (Vector2, Vector2)
	const Rect = Slot.Rect
	const Band = Slot.Band
	const BandCenter = (Band[1] + Band[2]) / 2
	const Align = self.Align or "Start"

	-- Coordinate along the bars plus the matching anchor
	const function Along(StartCoord: number, EndCoord: number, StartAnchor: number, EndAnchor: number): (number, number)
		if Align == "Center" then
			return (StartCoord + EndCoord) / 2, 0.5
		elseif Align == "End" then
			return EndCoord, EndAnchor
		elseif Align == "Zero" then
			return Zero, 0.5
		end
		return StartCoord, StartAnchor
	end

	if Horizontal then
		if Placement == "Above" then
			const AlongX, AnchorX = Along(Rect[1], Rect[3], 0, 1)
			return Vector2.new(AlongX, Rect[2] - Offset), Vector2.new(AnchorX, 1)
		elseif Placement == "Below" then
			const AlongX, AnchorX = Along(Rect[1], Rect[3], 0, 1)
			return Vector2.new(AlongX, Rect[4] + Offset), Vector2.new(AnchorX, 0)
		elseif Placement == "Before" then
			return Vector2.new(Rect[1] - Offset, BandCenter), Vector2.new(1, 0.5)
		elseif Placement == "After" then
			return Vector2.new(Rect[3] + Offset, BandCenter), Vector2.new(0, 0.5)
		end
		return Vector2.new(-Offset, BandCenter), Vector2.new(1, 0.5)
	end

	if Placement == "Above" then
		return Vector2.new(BandCenter, Rect[2] - Offset), Vector2.new(0.5, 1)
	elseif Placement == "Below" then
		return Vector2.new(BandCenter, Rect[4] + Offset), Vector2.new(0.5, 0)
	elseif Placement == "Before" then
		-- Vertical bars start at the bottom
		const AlongY, AnchorY = Along(Rect[4], Rect[2], 1, 0)
		return Vector2.new(Band[1] - Offset, AlongY), Vector2.new(1, AnchorY)
	elseif Placement == "After" then
		const AlongY, AnchorY = Along(Rect[4], Rect[2], 1, 0)
		return Vector2.new(Band[2] + Offset, AlongY), Vector2.new(0, AnchorY)
	end
	return Vector2.new(BandCenter, Size.Y + Offset), Vector2.new(0.5, 0)
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Pixels the labels need inside every slot along the slot axis. Above and Below on horizontal charts sit
-- between the slots, so the bar layout keeps that room; every other placement sits beside the bars or on the
-- axis and needs none.
function Categories.SlotReserve(self: Categories): number
	if not self.Enabled then
		return 0
	end
	const Placement = self.Placement or "Axis"
	if self.Graph.Orientation == "Horizontal" and (Placement == "Above" or Placement == "Below") then
		return (self.Style.TextSize or TEMPLATE_TEXT_SIZE) + (self.Offset or 4) + RESERVE_MARGIN
	end
	return 0
end

function Categories.Update(self: Categories)
	const Layer = self._Layer
	const Renderer = self.Graph.Renderer
	const Layout: Types.Layout? = Renderer and Renderer.Layout
	const Slots = if Layout then Layout.Slots else nil
	if not self.Enabled or not Layout or not Slots then
		Layer:Clear()
		return
	end

	const Horizontal = self.Graph.Orientation == "Horizontal"
	const Size: Vector2 = self.Graph.UI.AbsoluteSize
	const Zero = Layout.Zero or 0
	const Items: { Types.LabelItem } = {}

	for Index, Slot in Slots do
		const SlotData: SlotData = { Index = Index, Label = FirstLabel(Slot.Entries) or tostring(Index), Entries = Slot.Entries }
		const Info = { Index = Index, Rect = Slot.Rect, Band = Slot.Band, Zero = Zero, Orientation = if Horizontal then "Horizontal" else "Vertical" }

		const Spec = Labels.ResolveWith(self, SlotData, Info, nil)
		if Spec then
			local Position, Anchor = self:_Place(Spec.Placement or "Axis", Spec.Offset, Slot, Horizontal, Size, Zero)
			if Spec.Position then Position = Spec.Position end
			if Spec.Anchor then Anchor = Spec.Anchor end
			if Spec.Nudge then Position += Spec.Nudge end
			table.insert(Items, { Position = Position, Text = Spec.Text, Anchor = Anchor, Style = Spec.Style })
		end
	end

	Layer:Set(Items)
end

function Categories.Destroy(self: Categories)
	self._Layer:Destroy()
end

return Categories
