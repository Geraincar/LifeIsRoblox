--!nonstrict
-- Gui: короткие фабрики Instance для UI и мира. Parent всегда ставится последним.

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)

local Gui = {}

function Gui.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function merge(defaults: { [string]: any }, props: { [string]: any }?): { [string]: any }
	local t = table.clone(defaults)
	if props then
		for k, v in props do
			t[k] = v
		end
	end
	return t
end

function Gui.corner(radius: UDim?): UICorner
	return Gui.make("UICorner", { CornerRadius = radius or UDim.new(0, 10) })
end

function Gui.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return Gui.make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Gui.label(props: { [string]: any }?): TextLabel
	return Gui.make("TextLabel", merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.font,
		TextColor3 = Theme.color.text,
		TextSize = Theme.size.hudText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
		TextWrapped = true,
		Text = "",
	}, props))
end

function Gui.button(props: { [string]: any }?): TextButton
	local b = Gui.make("TextButton", merge({
		BackgroundColor3 = Theme.color.panel2,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Theme.fontBold,
		TextColor3 = Theme.color.text,
		TextSize = Theme.size.hudText,
		RichText = true,
		Text = "",
	}, props))
	Gui.corner().Parent = b
	return b
end

function Gui.frame(props: { [string]: any }?): Frame
	return Gui.make("Frame", merge({
		BackgroundColor3 = Theme.color.panel,
		BorderSizePixel = 0,
	}, props))
end

-- Part для мира: закреплён, не мешает персонажу и лучам, без теней
function Gui.part(props: { [string]: any }?): Part
	return Gui.make("Part", merge({
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, props))
end

-- Надпись над объектом в мире (размер в пикселях — читается с любого расстояния)
function Gui.billboard(adornee: Instance, text: string, props: { [string]: any }?): (BillboardGui, TextLabel)
	local bb = Gui.make("BillboardGui", merge({
		Adornee = adornee,
		Size = UDim2.fromOffset(150, 34),
		StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0),
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 60,
		ResetOnSpawn = false,
	}, props))
	local lbl = Gui.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextSize = 22,
		Font = Theme.fontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Parent = bb,
	})
	bb.Parent = adornee
	return bb, lbl
end

return Gui
