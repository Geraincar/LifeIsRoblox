--!nonstrict
-- Drag: перетаскивание мышью и пальцем по GuiObject.
--   local d = Drag.attach(frame, { began = fn(pos) -> boolean?, moved = fn(pos), ended = fn(pos) })
--   pos — Vector2 в экранных координатах GUI (та же система, что AbsolutePosition).
--   began может вернуть false — тогда это касание не перехватывается. d:Destroy() отключает всё.

local UserInputService = game:GetService("UserInputService")

local Drag = {}

local function isPress(t: Enum.UserInputType): boolean
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

function Drag.attach(gui: GuiObject, h)
	local active: InputObject? = nil
	local conns = {}
	local function pos(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	table.insert(conns, gui.InputBegan:Connect(function(input)
		if active or not isPress(input.UserInputType) then
			return
		end
		if h.began and h.began(pos(input)) == false then
			return
		end
		active = input
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if not active then
			return
		end
		local t = input.UserInputType
		local same = (t == Enum.UserInputType.MouseMovement and active.UserInputType == Enum.UserInputType.MouseButton1)
			or (t == Enum.UserInputType.Touch and input == active)
		if same and h.moved then
			h.moved(pos(input))
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if active and (input == active or (isPress(input.UserInputType) and input.UserInputType == active.UserInputType)) then
			active = nil
			if h.ended then
				h.ended(pos(input))
			end
		end
	end))
	return {
		Destroy = function()
			for _, c in conns do
				c:Disconnect()
			end
			table.clear(conns)
			active = nil
		end,
		isActive = function()
			return active ~= nil
		end,
	}
end

return Drag
