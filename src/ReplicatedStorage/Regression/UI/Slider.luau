--!nonstrict
-- Slider: горизонтальный ползунок (мышь, палец, кнопки −/+ для точного шага; зона касания ≥ 44 px).
--   local s = Slider.new(parent, { min = 0, max = 20, step = 0.1, value = 0, label = "λ", color = Theme.color.penalty,
--       format = Format.lambda, onChanged = fn(v), onReleased = fn(v) })
--   s:set(v, silent?), s.value, s.frame, s:Destroy()

local Regression = script.Parent.Parent
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Drag = require(Regression.UI.Drag)

local Slider = {}
Slider.__index = Slider

function Slider.new(parent: GuiObject, opts)
	local self = setmetatable({}, Slider)
	self.opts = opts
	self.value = opts.value or opts.min
	local color = opts.color or Theme.color.loss
	self.frame = Gui.frame({ Name = opts.name or "Slider", BackgroundTransparency = 1, Size = opts.size or UDim2.new(1, 0, 0, 56),
		LayoutOrder = opts.layoutOrder or 0, Parent = parent })
	self.caption = Gui.label({ Size = UDim2.new(0, 110, 1, 0), TextSize = 20, Font = Theme.fontBold, Parent = self.frame })
	local minus = Gui.button({ Text = "−", TextSize = 24, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 112, 0.5, -22), Parent = self.frame })
	local plus = Gui.button({ Text = "+", TextSize = 24, Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0.5, -22), Parent = self.frame })
	self.track = Gui.frame({ BackgroundColor3 = Theme.color.panel2, Position = UDim2.new(0, 170, 0.5, -4), Size = UDim2.new(1, -230, 0, 8),
		Parent = self.frame })
	Gui.corner(UDim.new(0, 4)).Parent = self.track
	self.fill = Gui.frame({ BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = self.track })
	Gui.corner(UDim.new(0, 4)).Parent = self.fill
	self.knob = Gui.frame({ AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromScale(0, 0.5), ZIndex = 3, Parent = self.track })
	Gui.corner(UDim.new(0.5, 0)).Parent = self.knob
	Gui.stroke(Theme.color.text, 2).Parent = self.knob
	-- невидимая широкая зона касания поверх дорожки
	self.hit = Gui.make("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.new(1, 24, 0, 48),
		Position = UDim2.new(0, -12, 0.5, -24), ZIndex = 4, Parent = self.track })

	local function fromScreen(p: Vector2)
		local a, s = self.track.AbsolutePosition, self.track.AbsoluteSize
		local t = if s.X > 0 then math.clamp((p.X - a.X) / s.X, 0, 1) else 0
		self:set(opts.min + t * (opts.max - opts.min))
	end
	self.drag = Drag.attach(self.hit, {
		began = function(p)
			fromScreen(p)
		end,
		moved = fromScreen,
		ended = function()
			if opts.onReleased then
				opts.onReleased(self.value)
			end
		end,
	})
	local stepBtn = opts.buttonStep or opts.step or (opts.max - opts.min) / 100
	minus.Activated:Connect(function()
		self:set(self.value - stepBtn)
		if opts.onReleased then
			opts.onReleased(self.value)
		end
	end)
	plus.Activated:Connect(function()
		self:set(self.value + stepBtn)
		if opts.onReleased then
			opts.onReleased(self.value)
		end
	end)
	self:set(self.value, true)
	return self
end

function Slider:set(v: number, silent: boolean?)
	local o = self.opts
	v = math.clamp(v, o.min, o.max)
	if o.step then
		v = math.clamp(math.round(v / o.step) * o.step, o.min, o.max)
		-- убрать хвосты float (6,6000000000000005 → 6,6)
		v = tonumber(string.format("%.6f", v)) :: number
	end
	local changed = v ~= self.value
	self.value = v
	local t = (v - o.min) / (o.max - o.min)
	self.knob.Position = UDim2.fromScale(t, 0.5)
	self.fill.Size = UDim2.fromScale(t, 1)
	self.caption.Text = ("%s = %s"):format(o.label or "", if o.format then o.format(v) else tostring(v))
	if changed and not silent and o.onChanged then
		o.onChanged(v)
	end
end

function Slider:Destroy()
	self.drag.Destroy()
	self.frame:Destroy()
end

return Slider
