--!strict
--!native
--!optimize 2
-- HitTest (Helper): pointer tests against the pixel-space layouts that renderers publish in Renderer.Layout.

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Types = require(script.Parent.Parent.Types)

local HitTest = {}

-- ─── Configuration ───────────────────────────────────────────────────────────

const TAU = math.pi * 2

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Layout: { Center: Vector2, Outer, Inner, Items = { [Key] = { Start, Sweep, Offset: Vector2, Outer? } } }
function HitTest.Pie(Layout: Types.Layout?, Local: Vector2): any
	if not Layout or not Layout.Items then
		return nil
	end
	const Center = Layout.Center or Vector2.zero
	const Inner = Layout.Inner or 0
	for Key, Item in Layout.Items do
		const Relative = Local - (Center + (Item.Offset or Vector2.zero))
		const Distance = Relative.Magnitude
		if Distance <= (Item.Outer or Layout.Outer or 0) and Distance >= Inner then
			const Angle = math.atan2(Relative.X, -Relative.Y)
			if (Angle - (Item.Start or 0)) % TAU <= (Item.Sweep or 0) then
				return Key
			end
		end
	end
	return nil
end

-- Layout: { Items = { [Key] = { Rect = { Left, Top, Right, Bottom } } } }
function HitTest.Rects(Layout: Types.Layout?, Local: Vector2): any
	if not Layout or not Layout.Items then
		return nil
	end
	for Key, Item in Layout.Items do
		const Rect = Item.Rect
		if Rect and Local.X >= Rect[1] and Local.X <= Rect[3] and Local.Y >= Rect[2] and Local.Y <= Rect[4] then
			return Key
		end
	end
	return nil
end

return HitTest
