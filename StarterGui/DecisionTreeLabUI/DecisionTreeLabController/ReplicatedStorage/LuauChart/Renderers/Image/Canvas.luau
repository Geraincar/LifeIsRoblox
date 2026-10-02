--!strict
--!native
--!optimize 2
-- Canvas (Class): owns one EditableImage and keeps it the same pixel size as its ImageLabel. Renderers
-- either use the image's draw calls directly, or rasterize into Buffer() and then Flush().

-- ─── Services ────────────────────────────────────────────────────────────────

const AssetService = game:GetService("AssetService")

-- ─── Configuration ───────────────────────────────────────────────────────────

const MAX_SIZE = 1024 -- EditableImage limit per axis

-- ─── Types ───────────────────────────────────────────────────────────────────

type Fields = {
	Label: ImageLabel,
	Image: EditableImage?,
	Size: Vector2,
	_Scratch: buffer?,
}

local Canvas = {}
Canvas.__index = Canvas

export type Canvas = typeof(setmetatable({} :: Fields, Canvas))

-- ─── State ───────────────────────────────────────────────────────────────────

local Warned = false

-- ─── Construction ────────────────────────────────────────────────────────────

function Canvas.new(Label: ImageLabel): Canvas
	const self = setmetatable({} :: Fields, Canvas)

	self.Label = Label
	self.Image = nil
	self.Size = Vector2.zero
	self._Scratch = nil

	Label.ScaleType = Enum.ScaleType.Stretch

	return self
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- An EditableImage matching the label's current pixel size, cleared to transparent. Returns nil while the
-- label is not laid out yet, or when the image cannot be created.
function Canvas.Prepare(self: Canvas): EditableImage?
	const Absolute = self.Label.AbsoluteSize
	if Absolute.X < 1 or Absolute.Y < 1 then
		return nil
	end

	const Size = Vector2.new(
		math.clamp(math.round(Absolute.X), 1, MAX_SIZE),
		math.clamp(math.round(Absolute.Y), 1, MAX_SIZE)
	)

	const Existing = self.Image
	if Existing and self.Size == Size then
		self:Clear()
		return Existing
	end

	if Existing then
		Existing:Destroy()
		self.Image = nil
	end

	const Ok, Image = pcall(AssetService.CreateEditableImage, AssetService, { Size = Size })
	if not Ok or not Image then
		if not Warned then
			Warned = true
			warn(`LuauChart: could not create an EditableImage ({tostring(Image)}); use the "Viewport" renderer if the experience can't enable image APIs`)
		end
		return nil
	end

	self.Image = Image
	self.Size = Size
	self._Scratch = buffer.create(Size.X * Size.Y * 4) -- RGBA8, zero is fully transparent
	self.Label.ImageContent = Content.fromObject(Image)

	return Image
end

function Canvas.Clear(self: Canvas)
	const Image, Scratch = self.Image, self._Scratch
	if Image and Scratch then
		buffer.fill(Scratch, 0, 0)
		Image:WritePixelsBuffer(Vector2.zero, self.Size, Scratch)
	end
end

-- Scratch pixel buffer (RGBA8, row-major), zeroed by Prepare. Draw into it, then Flush.
function Canvas.Buffer(self: Canvas): buffer
	return self._Scratch :: buffer
end

function Canvas.Flush(self: Canvas)
	const Image, Scratch = self.Image, self._Scratch
	if Image and Scratch then
		Image:WritePixelsBuffer(Vector2.zero, self.Size, Scratch)
	end
end

function Canvas.Destroy(self: Canvas)
	const Image = self.Image
	if Image then
		Image:Destroy()
		self.Image = nil
	end
	self._Scratch = nil
end

return Canvas
