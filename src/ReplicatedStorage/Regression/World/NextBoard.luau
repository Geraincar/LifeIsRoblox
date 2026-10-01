--!nonstrict
-- NextBoard: второе табло (3D.6). Скрыто до вызова rise(): поднимается из-под земли за ≤ 2 с,
-- на экране — превью параболы игрока; ProximityPrompt «Продолжить обучение» открывает 2D experience.

local TweenService = game:GetService("TweenService")

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)
local PlotView2D = require(Regression.UI.PlotView2D)

local NextBoard = {}
NextBoard.__index = NextBoard

local W_STUDS, H_STUDS = 14, 7.875 -- 700 × 394 px при 50 px/stud

-- args: parent, cframe (итоговый центр экрана), groundY, playerGui, onContinue
function NextBoard.new(args)
	local self = setmetatable({}, NextBoard)
	self.parent = args.parent
	self.finalCF = args.cframe :: CFrame
	self.model = Gui.make("Model", { Name = "RegressionNextBoard" })
	local cf = self.finalCF
	self.screen = Gui.part({ Name = "Screen", Size = Vector3.new(W_STUDS, H_STUDS, 0.4), CFrame = cf, Color = Theme.color.bg, Parent = self.model })
	Gui.part({ Name = "Frame", Size = Vector3.new(W_STUDS + 0.8, H_STUDS + 0.8, 0.3), CFrame = cf * CFrame.new(0, 0, 0.3),
		Color = Theme.color.boardFrame, Parent = self.model })
	local legH = (cf.Position.Y - H_STUDS / 2) - args.groundY + 0.4
	Gui.part({ Name = "Leg", Size = Vector3.new(0.8, legH, 0.8), CFrame = cf * CFrame.new(0, -H_STUDS / 2 - legH / 2 + 0.4, 0.45),
		Color = Theme.color.boardFrame, CanCollide = true, Parent = self.model })
	self.model.PrimaryPart = self.screen
	self.depth = H_STUDS + legH + 1 -- на сколько опустить под землю

	self.prompt = Gui.make("ProximityPrompt", {
		ActionText = Strings.prompt.continue,
		ObjectText = Strings.prompt.board2,
		KeyboardKeyCode = Enum.KeyCode.F,
		HoldDuration = 0,
		MaxActivationDistance = 16,
		RequiresLineOfSight = false,
		Enabled = false,
		Parent = self.screen,
	})
	self.prompt.Triggered:Connect(function()
		if args.onContinue then
			args.onContinue()
		end
	end)

	self.gui = Gui.make("SurfaceGui", {
		Name = "RegressionNextBoardGui", Adornee = self.screen, Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, LightInfluence = 0,
		ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false, Parent = args.playerGui,
	})
	local root = Gui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.bg, Parent = self.gui })
	Gui.label({ Position = UDim2.fromOffset(24, 12), Size = UDim2.fromOffset(660, 44), Text = Strings.screen2d.boardTitle,
		TextSize = 36, Font = Theme.fontBold, Parent = root })
	Gui.label({ Position = UDim2.fromOffset(24, 56), Size = UDim2.fromOffset(300, 300), Text = Strings.screen2d.boardBody .. "\n\n<b>dL/dm = 0</b>",
		TextSize = 26, TextYAlignment = Enum.TextYAlignment.Top, Parent = root })
	local holder = Gui.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(330, 60), Size = UDim2.fromOffset(360, 320), Parent = root })
	self.plot = PlotView2D.new(holder, {
		xMin = -1, xMax = 1.5, yMin = 0, yMax = 2,
		xTicks = { -1, 0, 1 }, yTicks = { 0, 1, 2 },
		padL = 40, padR = 8, padT = 12, padB = 36, fontSize = 18,
		fallbackW = 312, fallbackH = 272,
	})
	return self
end

function NextBoard:setParabola(P, records)
	local L = self.plot:layer("parabola", 3)
	L:begin()
	if P then
		L:curve(function(m)
			return P.a * m * m + P.b * m + P.k
		end, -1, 1.5, 80, { color = Theme.color.loss, thickness = 3 })
		L:dashedV(P.tStar, 0, P.vStar, { color = Theme.color.flag, thickness = 2 })
		for _, r in records or {} do
			L:dot(r.m, r.mse, { color = Theme.color.loss, size = 12 })
		end
		L:dot(P.tStar, P.vStar, { color = Theme.color.flag, size = 14 })
	end
	L:finish()
end

function NextBoard:rise(onDone: (() -> ())?)
	local target = self.finalCF
	self.model:PivotTo(target * CFrame.new(0, -self.depth, 0))
	self.model.Parent = self.parent
	self.gui.Enabled = true
	local v = Instance.new("CFrameValue")
	v.Value = target * CFrame.new(0, -self.depth, 0)
	v.Changed:Connect(function(cf)
		self.model:PivotTo(cf)
	end)
	local tw = TweenService:Create(v, TweenInfo.new(Config.BOARD2_RISE_S, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
	tw.Completed:Connect(function()
		v:Destroy()
		self.prompt.Enabled = true
		if onDone then
			onDone()
		end
	end)
	tw:Play()
end

return NextBoard
