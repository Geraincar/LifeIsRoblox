--!strict
--!native
--!optimize 2
-- GuiUtil (Helper): overlays that features create at runtime, plus click detection.

local GuiUtil = {}

-- ─── Types ───────────────────────────────────────────────────────────────────

export type TextStyle = {
	TextSize: number?,
	TextColor3: Color3?,
	FontFace: Font?,
	StrokeTransparency: number?,
}

-- ─── Internal ────────────────────────────────────────────────────────────────

const function IsPointer(Input: InputObject): boolean
	return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Full-size transparent frame under Parent, created once and reused by name
function GuiUtil.Container(Parent: GuiObject, Name: string, ZIndex: number): Frame
	const Existing = Parent:FindFirstChild(Name)
	if Existing and Existing:IsA("Frame") then
		return Existing
	end

	const Frame = Instance.new("Frame")
	Frame.Name = Name
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.Size = UDim2.fromScale(1, 1)
	Frame.ZIndex = ZIndex
	Frame.Parent = Parent
	return Frame
end

function GuiUtil.ApplyTextStyle(Label: TextLabel, Style: TextStyle?)
	if not Style then
		return
	end
	Label.TextSize = Style.TextSize or Label.TextSize
	Label.TextColor3 = Style.TextColor3 or Label.TextColor3
	Label.FontFace = Style.FontFace or Label.FontFace
	Label.TextStrokeTransparency = Style.StrokeTransparency or Label.TextStrokeTransparency
end

function GuiUtil.TextLabel(Style: TextStyle?): TextLabel
	const Label = script.Label:Clone()
	GuiUtil.ApplyTextStyle(Label, Style)
	return Label
end

-- Calls Callback(LocalPosition) on a click or tap that moved less than MaxMove pixels, so drags are left
-- alone. Returns the connections so the caller can disconnect them.
function GuiUtil.ClickDetector(Gui: GuiObject, Callback: (Vector2) -> (), MaxMove: number?): { RBXScriptConnection }
	local PressPosition: Vector2? = nil
	const Connections = {}

	table.insert(Connections, Gui.InputBegan:Connect(function(Input: InputObject)
		if IsPointer(Input) then
			PressPosition = Vector2.new(Input.Position.X, Input.Position.Y)
		end
	end))

	table.insert(Connections, Gui.InputEnded:Connect(function(Input: InputObject)
		if not PressPosition or not IsPointer(Input) then
			return
		end
		const Origin = PressPosition
		PressPosition = nil

		const Release = Vector2.new(Input.Position.X, Input.Position.Y)
		if (Release - Origin).Magnitude <= (MaxMove or 6) then
			Callback(Release - Gui.AbsolutePosition)
		end
	end))

	table.insert(Connections, Gui.MouseLeave:Connect(function()
		PressPosition = nil
	end))

	return Connections
end

return GuiUtil
