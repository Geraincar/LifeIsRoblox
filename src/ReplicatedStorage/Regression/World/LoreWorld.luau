--!nonstrict
-- LoreWorld: пасека игрока для лор-задачи (локально у игрока).
--   Пасечник (NPC) с ProximityPrompt «Поговорить», табло «Пять соседних пасек»,
--   5 ульев игрока (ProximityPrompt «Посчитать пчёл» / «Собрать мёд», карточка над ульем),
--   у каждого улья — ближайшая поляна с табличкой расстояния и ProximityPrompt «Измерить расстояние».
-- Расстояния 200–2000 м пешком в Roblox не пройти: на табличке — сюжетная величина в метрах,
-- а путь в мире ей пропорционален (Config.LORE_STUDS_PER_M).
-- Система координат: origin — центр пасеки на земле; локальная +Z смотрит туда, откуда приходит игрок.

local Regression = script.Parent.Parent
local Config = require(Regression.Core.Config)
local Format = require(Regression.Core.Format)
local Theme = require(Regression.UI.Theme)
local Gui = require(Regression.UI.Gui)
local Strings = require(Regression.UI.Strings)

local LoreWorld = {}
LoreWorld.__index = LoreWorld

local S = Strings.lore
local HIVE_SPACING = 8
local HIVE_Z = 6
local MEADOW_ANGLES = { -18, 10, -8, 16, 0 } -- небольшой разброс направлений к полянам, градусы

local function prompt(parent: Instance, action: string, object: string, dist: number?): ProximityPrompt
	return Gui.make("ProximityPrompt", {
		ActionText = action, ObjectText = object, KeyboardKeyCode = Enum.KeyCode.F, HoldDuration = 0,
		MaxActivationDistance = dist or 10, RequiresLineOfSight = false, Enabled = false, Parent = parent,
	})
end

function LoreWorld.new(args)
	local self = setmetatable({}, LoreWorld)
	self.origin = args.origin :: CFrame
	self.data = args.data
	self.model = Gui.make("Model", { Name = "RegressionLore" })
	self.hives, self.meadows = {}, {}
	self:_buildNpc()
	self:_buildBoard()
	for i, h in self.data.player_hives do
		self:_buildHive(i, h)
	end
	self:_buildBeacon()
	self.model.Parent = args.parent
	return self
end

function LoreWorld:cf(x: number, y: number, z: number): CFrame
	return self.origin * CFrame.new(x, y, z)
end

-- Расстояние от точки до пасеки (центр), studs
function LoreWorld:distanceTo(p: Vector3): number
	local l = self.origin:PointToObjectSpace(p)
	return Vector3.new(l.X, 0, l.Z).Magnitude
end

function LoreWorld:_buildNpc()
	local npc = Gui.make("Model", { Name = "Beekeeper" })
	local base = self:cf(0, 0, 14) * CFrame.Angles(0, math.pi, 0)
	local body = Gui.part({ Name = "Body", Size = Vector3.new(2, 2.6, 1.2), CFrame = base * CFrame.new(0, 1.3 + 1.2, 0), Color = Color3.fromHex("#F2F2F2"),
		CanCollide = true, Parent = npc })
	Gui.part({ Name = "Legs", Size = Vector3.new(1.8, 1.2, 1), CFrame = base * CFrame.new(0, 0.6, 0), Color = Color3.fromHex("#3B4A6B"), Parent = npc })
	local head = Gui.part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = base * CFrame.new(0, 4.4, 0),
		Color = Color3.fromHex("#E0B38C"), Parent = npc })
	Gui.part({ Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2.6, 2.6), CFrame = base * CFrame.new(0, 5.0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#E8DCA0"), Parent = npc })
	Gui.part({ Name = "Veil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.0, 1.7, 1.7), CFrame = base * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#2B2B2B"), Transparency = 0.55, Parent = npc })
	Gui.billboard(head, S.npcName, { Size = UDim2.fromOffset(160, 30), StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0) })
	npc.PrimaryPart = body
	npc.Parent = self.model
	self.npc = npc
	self.npcPrompt = prompt(body, S.promptTalk, S.npcName, 12)
end

function LoreWorld:_buildBoard()
	local cf = self:cf(8, 3.6, 14) * CFrame.Angles(0, 0, 0)
	local screen = Gui.part({ Name = "DataBoard", Size = Vector3.new(9, 5.2, 0.3), CFrame = cf, Color = Theme.color.bg, Parent = self.model })
	Gui.part({ Name = "Leg", Size = Vector3.new(0.4, 1.4, 0.4), CFrame = self:cf(8, 0.7, 14.05), Color = Theme.color.boardFrame, Parent = self.model })
	local sg = Gui.make("SurfaceGui", { Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
		LightInfluence = 0, Parent = screen })
	local root = Gui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.bg, Parent = sg })
	Gui.label({ Text = S.boardTitle, Font = Theme.fontBold, TextSize = 30, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 40), Parent = root })
	local lines = { S.tableHeader }
	for _, a in self.data.train_apiaries do
		table.insert(lines, S.tableRow:format(a.apiary, Format.num(a.distance_to_meadow_m, 0), Format.num(a.bees_k, 1), Format.num(a.temperature_C, 1),
			Format.num(a.honey_kg, 1)))
	end
	Gui.label({ Text = table.concat(lines, "\n"), Font = Enum.Font.RobotoMono, TextSize = 22, Position = UDim2.fromOffset(16, 54),
		Size = UDim2.new(1, -32, 1, -64), TextYAlignment = Enum.TextYAlignment.Top, RichText = false, Parent = root })
	self.board = screen
end

function LoreWorld:_buildHive(i: number, h)
	local x = -2 * HIVE_SPACING + (i - 1) * HIVE_SPACING
	local hive = Gui.make("Model", { Name = "Hive" .. i })
	local base = self:cf(x, 0, HIVE_Z)
	Gui.part({ Name = "Stand", Size = Vector3.new(2.8, 0.6, 2.8), CFrame = base * CFrame.new(0, 0.3, 0), Color = Theme.color.wood, Material = Enum.Material.Wood, CanCollide = true, Parent = hive })
	local box = Gui.part({ Name = "Box", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = base * CFrame.new(0, 1.8, 0), Color = Color3.fromHex("#E8B84A"), Material = Enum.Material.Wood,
		CanCollide = true, CanQuery = true, Parent = hive })
	for k = 1, 2 do
		Gui.part({ Name = "Stripe", Size = Vector3.new(2.45, 0.12, 2.45), CFrame = base * CFrame.new(0, 1.2 + k * 0.8 - 0.4, 0), Color = Color3.fromHex("#B8862B"), Parent = hive })
	end
	Gui.part({ Name = "Roof", Size = Vector3.new(3, 0.35, 3), CFrame = base * CFrame.new(0, 3.2, 0), Color = Color3.fromHex("#7A4E2D"), Parent = hive })
	Gui.part({ Name = "Entrance", Size = Vector3.new(0.9, 0.2, 0.05), CFrame = base * CFrame.new(0, 0.9, 1.22), Color = Color3.fromHex("#2B1A0E"), Parent = hive })
	Gui.billboard(box, S.hiveName:format(i), { Size = UDim2.fromOffset(120, 28), StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0) })
	-- карточка улья: данные, прогноз, реальный мёд
	local card = Gui.make("BillboardGui", { Name = "Card", Adornee = box, Size = UDim2.fromOffset(230, 0), StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 70, Enabled = false, ResetOnSpawn = false, Parent = box })
	local cardLabel = Gui.label({ Size = UDim2.fromOffset(230, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.color.bg, BackgroundTransparency = 0.1,
		TextSize = 18, Parent = card })
	Gui.corner().Parent = cardLabel
	Gui.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = cardLabel })
	card.Size = UDim2.fromOffset(230, 130)
	hive.PrimaryPart = box
	hive.Parent = self.model
	local hp = prompt(box, S.promptCount, S.hiveName:format(i), 9)

	-- поляна: путь в мире пропорционален сюжетному расстоянию
	local d = h.distance_to_meadow_m * Config.LORE_STUDS_PER_M + 4
	local a = math.rad(MEADOW_ANGLES[i] or 0)
	local mx, mz = x + math.sin(a) * d, HIVE_Z - math.cos(a) * d
	local meadow = Gui.make("Model", { Name = "Meadow" .. i })
	local mcf = self:cf(mx, 0, mz)
	Gui.part({ Name = "Grass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6, 6), CFrame = mcf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#6BBF59"), Material = Enum.Material.Grass, Parent = meadow })
	for k = 1, 7 do
		local ang = k * 2.4
		local r = 0.8 + (k % 3) * 0.75
		Gui.part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45),
			CFrame = mcf * CFrame.new(math.cos(ang) * r, 0.6, math.sin(ang) * r), Color = Theme.color.petals[(k - 1) % #Theme.color.petals + 1], Parent = meadow })
	end
	local post = Gui.part({ Name = "SignPost", Size = Vector3.new(0.3, 2.2, 0.3), CFrame = mcf * CFrame.new(2.6, 1.1, 0), Color = Theme.color.wood, Parent = meadow })
	local sign = Gui.part({ Name = "Sign", Size = Vector3.new(3.2, 1.3, 0.15), CFrame = mcf * CFrame.new(2.6, 2.5, 0) * CFrame.Angles(0, math.pi, 0), Color = Theme.color.wood, Parent = meadow })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Gui.make("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, LightInfluence = 0, Parent = sign })
		Gui.label({ Size = UDim2.fromScale(1, 1), Text = S.signText:format(i, Format.num(h.distance_to_meadow_m, 0)), Font = Theme.fontBold, TextSize = 24,
			TextColor3 = Color3.fromHex("#2B1A0E"), TextXAlignment = Enum.TextXAlignment.Center, Parent = sg })
	end
	-- тропинка от улья к поляне
	local from, to = self:cf(x, 0, HIVE_Z).Position, mcf.Position
	local steps = math.max(2, math.floor((to - from).Magnitude / 2.2))
	for k = 1, steps - 1 do
		local p = from:Lerp(to, k / steps)
		Gui.part({ Name = "Path", Size = Vector3.new(0.9, 0.05, 0.9), CFrame = CFrame.new(p + Vector3.new(0, 0.03, 0)) * self.origin.Rotation,
			Color = Color3.fromHex("#C9B48A"), Parent = meadow })
	end
	meadow.Parent = self.model
	local mp = prompt(post, S.promptMeasure, S.meadowName:format(i), 8)
	self.hives[i] = { model = hive, box = box, prompt = hp, card = card, cardLabel = cardLabel }
	self.meadows[i] = { model = meadow, prompt = mp, post = post, sign = sign }
end

function LoreWorld:_buildBeacon()
	self.beacon = Gui.part({ Name = "Beacon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 1.2, 1.2), Color = Theme.color.c,
		Material = Enum.Material.Neon, Transparency = 1, Parent = self.model })
end

-- Луч-ориентир над целью (nil — спрятать)
function LoreWorld:setBeacon(target: BasePart?)
	if target then
		self.beacon.CFrame = CFrame.new(target.Position + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
		self.beacon.Transparency = 0.45
	else
		self.beacon.Transparency = 1
	end
end

function LoreWorld:setCard(i: number, text: string?)
	local h = self.hives[i]
	h.card.Enabled = text ~= nil
	if text then
		h.cardLabel.Text = text
	end
end

-- Все ProximityPrompt пасеки (для отключения на время режима управления прямой)
function LoreWorld:prompts(): { ProximityPrompt }
	local out = { self.npcPrompt }
	for i = 1, #self.hives do
		table.insert(out, self.hives[i].prompt)
		table.insert(out, self.meadows[i].prompt)
	end
	return out
end

return LoreWorld
