--!nonstrict
-- Scoreboard: табло у клумбы. Part-экран + SurfaceGui в PlayerGui (иначе кнопки на нём не нажимаются).
-- Слева — параметры (m, h и c, ŷ, MSE, λ), сообщение шага и кнопка записи; справа — график «MSE от наклона»:
-- живой маркер текущей прямой, записи, бледные записи другой высоты, парабола и флажок минимума.

local Regression = script.Parent.Parent
local Records = require(Regression.Core.Records)
local Format = require(Regression.Core.Format)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)

local Scoreboard = {}
Scoreboard.__index = Scoreboard

local PPS = 50 -- пикселей на stud
local W_STUDS, H_STUDS = 20, 11.25 -- 1000 × 562 px

-- args: parent, cframe (центр экрана, −Z смотрит на игрока), playerGui, onRecord
function Scoreboard.new(args)
	local self = setmetatable({}, Scoreboard)
	self.onRecord = args.onRecord
	self.model = Gui.make("Model", { Name = "RegressionScoreboard" })
	local cf = args.cframe :: CFrame
	self.screen = Gui.part({ Name = "Screen", Size = Vector3.new(W_STUDS, H_STUDS, 0.4), CFrame = cf, Color = Theme.color.bg, Parent = self.model })
	Gui.part({ Name = "Frame", Size = Vector3.new(W_STUDS + 0.8, H_STUDS + 0.8, 0.3), CFrame = cf * CFrame.new(0, 0, 0.3),
		Color = Theme.color.boardFrame, Parent = self.model })
	local bottomY = cf.Position.Y - H_STUDS / 2
	local groundY = args.groundY or (bottomY - 1.5)
	for _, dx in { -W_STUDS / 2 + 1.5, W_STUDS / 2 - 1.5 } do
		local legH = bottomY - groundY + 0.4
		Gui.part({ Name = "Leg", Size = Vector3.new(0.6, legH, 0.6), CFrame = cf * CFrame.new(dx, -H_STUDS / 2 - legH / 2 + 0.4, 0.45),
			Color = Theme.color.boardFrame, CanCollide = true, Parent = self.model })
	end
	self.model.Parent = args.parent

	self.gui = Gui.make("SurfaceGui", {
		Name = "RegressionScoreboardGui",
		Adornee = self.screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PPS,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = args.playerGui,
	})
	self:_buildLeft()
	self:_buildPlot()
	self:_buildIdle()
	return self
end

function Scoreboard:_buildLeft()
	local root = Gui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.bg, Parent = self.gui })
	self.root = root
	local function row(y: number, h: number, size: number, bold: boolean?)
		return Gui.label({ Position = UDim2.fromOffset(28, y), Size = UDim2.fromOffset(380, h), TextSize = size,
			Font = if bold then Theme.fontBold else Theme.font, Parent = root })
	end
	self.title = row(12, 44, 32, true)
	self.title.Text = Strings.boardTitle
	self.rowM = row(66, 42, 32, true)
	self.rowH = row(110, 42, 28)
	self.rowEq = row(152, 36, 26)
	self.rowMse = row(192, 48, 36, true)
	self.rowMseFormula = row(240, 32, 22)
	self.rowLambda = row(276, 34, 24)
	self.message = row(316, 118, 24)
	self.message.TextYAlignment = Enum.TextYAlignment.Top
	self.message.TextScaled = true -- длинные сообщения ужимаются, но не крупнее 24 px
	Gui.make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 16, Parent = self.message })
	self.message.TextColor3 = Theme.color.text

	self.recordBtn = Gui.button({
		Position = UDim2.fromOffset(28, 444), Size = UDim2.fromOffset(372, 58), TextSize = 28,
		BackgroundColor3 = Theme.color.loss, TextColor3 = Theme.color.bg, Text = Strings.recordBtn, Visible = false, Parent = root,
	})
	self.recordBtn.Activated:Connect(function()
		if self.onRecord then
			self.onRecord()
		end
	end)
	self.recordCounter = row(508, 40, 24)
	self.recordCounter.TextColor3 = Theme.color.textDim
end

function Scoreboard:_buildPlot()
	local holder = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(420, 14), Size = UDim2.fromOffset(566, 534), Parent = self.root })
	Gui.label({ Text = Strings.plotTitle, Position = UDim2.fromOffset(64, 0), Size = UDim2.fromOffset(480, 30), TextSize = 26,
		Font = Theme.fontBold, Parent = holder })
	local inner = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), Parent = holder })
	self.plot = PlotView2D.new(inner, {
		xMin = -1, xMax = 1.5, yMin = 0, yMax = 2,
		xTicks = { -1, -0.5, 0, 0.5, 1, 1.5 }, yTicks = { 0, 0.5, 1, 1.5, 2 },
		xLabel = Strings.plotX, yLabel = Strings.plotY,
		padL = 62, padR = 14, padT = 40, padB = 70, fontSize = 22,
		fallbackW = 566 - 62 - 14, fallbackH = 508 - 40 - 70,
	})
	self.plot.onResize = function()
		self.dirty = true
	end
end

function Scoreboard:_buildIdle()
	self.idle = Gui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.bg, ZIndex = 50, Parent = self.gui })
	Gui.label({ Size = UDim2.fromScale(1, 1), Text = Strings.boardIdle, TextSize = 44, Font = Theme.fontBold, ZIndex = 51,
		TextColor3 = Theme.color.textDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = self.idle })
end

function Scoreboard:setActive(on: boolean)
	self.idle.Visible = not on
end

function Scoreboard:setMessage(text: string, color: Color3?)
	self.message.Text = text
	self.message.TextColor3 = color or Theme.color.text
end

-- snap: LineModel-снимок; st: { records, parabola, recordEnabled, showMseFormula, bestLine }
function Scoreboard:render(snap, st)
	local tok = Theme.tok
	self.rowM.Text = ("%s  <font size=\"24\">%s</font>   %s"):format(tok("mText", "m"), Strings.slopeName, Format.coef(snap.m))
	self.rowH.Text = ("%s  <font size=\"22\">%s</font>  %s     %s = %s"):format(
		tok("c", "h"), Strings.heightName, Format.len(snap.h), tok("c", "c"), Format.len(snap.c))
	self.rowEq.Text = ("ŷ = %s·x + %s"):format(tok("mText", Format.coef(snap.m)), tok("c", Format.num(snap.c, 2)))
	self.rowMse.Text = ("%s = %s"):format(tok("residual", "MSE"), Format.mse(snap.mse))
	if st.showMseFormula then
		self.rowMseFormula.Text = ("MSE = Σe² / %d = %s / %d"):format(snap.n, Format.num(snap.L, 3), snap.n)
	else
		self.rowMseFormula.Text = ""
	end
	self.rowLambda.Text = ("%s = %s   <font color=\"%s\">%s</font>"):format(tok("penalty", "λ"), Format.lambda(0), Theme.hex.textDim, Strings.lambdaNote)

	local cur = Records.atHeight(st.records, snap.h)
	self.recordBtn.Visible = st.recordEnabled == true
	if st.recordEnabled or #st.records > 0 then
		self.recordCounter.Text = if st.parabola then Strings.recordsDone
			else Strings.recordCounter:format(Format.len(snap.h), #cur)
	else
		self.recordCounter.Text = ""
	end

	self:_renderPlot(snap, st, cur)
end

function Scoreboard:_renderPlot(snap, st, cur)
	local plot = self.plot
	local anyStale = #cur < #st.records

	local stale = plot:layer("stale", 3)
	stale:begin()
	for _, r in st.records do
		if not Records.sameHeight(r.h, snap.h) then
			stale:dot(r.m, r.mse, { color = Theme.color.textDim, size = 14, transparency = 0.6 })
		end
	end
	stale:finish()

	local P = st.parabola
	local par = plot:layer("parabola", 4)
	par:begin()
	if P then
		local sameH = Records.sameHeight(P.h, snap.h)
		local tr = if sameH then 0 else 0.6
		par:curve(function(m)
			return P.a * m * m + P.b * m + P.k
		end, -1, 1.5, 100, { color = Theme.color.loss, thickness = 3, transparency = tr })
		par:dashedV(P.tStar, 0, P.vStar, { color = Theme.color.flag, thickness = 2, transparency = tr })
		par:dot(P.tStar, P.vStar, { color = Theme.color.flag, size = 18, transparency = tr })
		par:label(P.tStar, P.vStar, ("m* = %s"):format(Format.coef(P.tStar)), {
			dx = 12, dy = -10, anchor = Vector2.new(0, 1), size = 24, font = Theme.fontBold, color = Theme.color.flag, transparency = tr,
		})
		if not sameH then
			par:labelPx(8, 8, Strings.parabolaOtherH:format(Format.len(P.h)), { anchor = Vector2.new(0, 0), size = 18, color = Theme.color.textDim })
		end
	end
	if anyStale then
		par:labelPx(8, if P then 32 else 8, Strings.staleNote, { anchor = Vector2.new(0, 0), size = 18, color = Theme.color.textDim })
	end
	par:finish()

	local recs = plot:layer("records", 5)
	recs:begin()
	for _, r in cur do
		recs:dot(r.m, r.mse, { color = Theme.color.loss, size = 16, strokeColor = Theme.color.bg })
	end
	recs:finish()

	-- текущее положение прямой — с шага записей (до него график пуст: точки «заносятся с п. 4»)
	local live = plot:layer("live", 6)
	live:begin()
	if st.recordEnabled or P or #st.records > 0 then
		live:dot(snap.m, snap.mse, { color = Theme.color.line, size = 20, hollow = true })
	end
	live:finish()
end

return Scoreboard
