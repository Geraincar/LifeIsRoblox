--!nonstrict

-- ============================================================
-- KMeansClient
--
-- 1. PLACE CENTROIDS
-- 2. MANUAL ASSIGNMENT
-- 3. UPDATE CENTROIDS TO MEAN
-- 4. REPEAT
-- 5. CONVERGENCE
-- 6. FORMAL VIEW
--
-- Всё происходит локально, как regression learning world.
-- ============================================================


local Players =
	game:GetService(
		"Players"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local RunService =
	game:GetService(
		"RunService"
	)


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


-- ============================================================
-- MODULES
-- ============================================================

local KMeans =
	ReplicatedStorage
	:WaitForChild(
		"KMeans"
	)

local Config =
	require(
		KMeans.Core.Config
	)

local MathCore =
	require(
		KMeans.Core.MathCore
	)

local Datasets =
	require(
		KMeans.Data.Datasets
	)


local dataset =
	Datasets.manual


-- ============================================================
-- TRY TO REUSE REGRESSION THEME
-- ============================================================

local COLORS = {

	bg =
		Color3.fromRGB(
			35,
			39,
			42
		),

	panel =
		Color3.fromRGB(
			45,
			49,
			53
		),

	boardFrame =
		Color3.fromRGB(
			65,
			54,
			38
		),

	text =
		Color3.fromRGB(
			245,
			241,
			224
		),

	textDim =
		Color3.fromRGB(
			180,
			180,
			175
		),

	accent =
		Color3.fromRGB(
			244,
			194,
			74
		),

	good =
		Color3.fromRGB(
			98,
			205,
			130
		),

	bad =
		Color3.fromRGB(
			236,
			90,
			80
		),

}


local FONT =
	Enum.Font.Gotham


local FONT_BOLD =
	Enum.Font.GothamBold


do

	local regression =
		ReplicatedStorage
		:FindFirstChild(
			"Regression"
		)


	if regression then

		local ui =
			regression
			:FindFirstChild(
				"UI"
			)


		local themeModule =
			ui
			and
			ui:FindFirstChild(
				"Theme"
			)


		if themeModule then

			local ok,
				theme =
					pcall(
						require,
						themeModule
					)


			if
				ok
				and
				theme
			then

				if theme.color then

					COLORS.bg =
						theme.color.bg
						or COLORS.bg

					COLORS.panel =
						theme.color.boardFrame
						or COLORS.panel

					COLORS.text =
						theme.color.text
						or COLORS.text

					COLORS.textDim =
						theme.color.textDim
						or COLORS.textDim

					COLORS.accent =
						theme.color.loss
						or COLORS.accent

					COLORS.good =
						theme.color.good
						or COLORS.good

					COLORS.boardFrame =
						theme.color.wood
						or
						theme.color.boardFrame
						or
						COLORS.boardFrame

				end


				FONT =
					theme.font
					or FONT


				FONT_BOLD =
					theme.fontBold
					or FONT_BOLD

			end

		end

	end

end


-- Cluster colors are intentionally clearer than generic UI colors.

local CENTER_COLORS = {

	Color3.fromRGB(
		239,
		92,
		73
	),

	Color3.fromRGB(
		72,
		151,
		220
	),

}


local POINT_IDLE_COLOR =
	Color3.fromRGB(
		242,
		242,
		238
	)


-- ============================================================
-- LEVEL REFERENCES
-- ============================================================

local level =
	workspace
	:WaitForChild(
		"KMeansLevel"
	)


local anchor =
	level
	:WaitForChild(
		"KMeansAnchor"
	)


local zone =
	level
	:WaitForChild(
		"KMeansZone"
	)


anchor.Transparency = 1
anchor.CanCollide = false
anchor.CanQuery = false


zone.Transparency = 1
zone.CanCollide = false
zone.CanQuery = false
zone.CanTouch = false


local marker =
	anchor
	:FindFirstChild(
		"BuilderMarker"
	)

if marker
	and marker:IsA("BillboardGui") then

	marker.Enabled =
		false

end


-- ============================================================
-- CLEAN LOCAL WORLD
-- ============================================================

local existing =
	workspace
	:FindFirstChild(
		"KMeansWorld"
	)


if existing then

	existing:Destroy()

end


local world =
	Instance.new(
		"Folder"
	)

world.Name =
	"KMeansWorld"

world.Parent =
	workspace


local temporary =
	Instance.new(
		"Folder"
	)

temporary.Name =
	"Temporary"

temporary.Parent =
	world


-- ============================================================
-- GENERIC INSTANCE HELPERS
-- ============================================================

local function makePart(args)

	local p =
		Instance.new(
			"Part"
		)


	p.Name =
		args.Name
		or
		"Part"


	p.Anchored =
		true


	p.CanCollide =
		args.CanCollide
		or false


	p.CanTouch =
		false


	p.CanQuery =
		args.CanQuery
		or false


	p.Material =
		args.Material
		or
		Enum.Material.SmoothPlastic


	p.Color =
		args.Color
		or
		Color3.new(
			1,
			1,
			1
		)


	p.Transparency =
		args.Transparency
		or 0


	p.Size =
		args.Size
		or
		Vector3.one


	p.CFrame =
		args.CFrame
		or
		CFrame.new()


	if args.Shape then

		p.Shape =
			args.Shape

	end


	p.Parent =
		args.Parent
		or
		world


	return p

end


local function corner(
	parent,
	radius
)

	local c =
		Instance.new(
			"UICorner"
		)

	c.CornerRadius =
		UDim.new(
			0,
			radius
			or 8
		)

	c.Parent =
		parent


	return c

end


local function stroke(
	parent,
	color,
	thickness,
	transparency
)

	local s =
		Instance.new(
			"UIStroke"
		)

	s.Color =
		color
		or
		COLORS.textDim


	s.Thickness =
		thickness
		or 1


	s.Transparency =
		transparency
		or 0


	s.Parent =
		parent


	return s

end


local function label(
	parent,
	args
)

	local t =
		Instance.new(
			"TextLabel"
		)


	t.BackgroundTransparency =
		args.BackgroundTransparency
		or 1


	t.BackgroundColor3 =
		args.BackgroundColor3
		or
		COLORS.bg


	t.Position =
		args.Position
		or
		UDim2.new()


	t.Size =
		args.Size
		or
		UDim2.fromScale(
			1,
			1
		)


	t.Text =
		args.Text
		or
		""


	t.TextColor3 =
		args.TextColor3
		or
		COLORS.text


	t.TextSize =
		args.TextSize
		or 20


	t.Font =
		args.Font
		or FONT


	t.TextWrapped =
		if args.TextWrapped == nil
		then true
		else args.TextWrapped


	t.TextXAlignment =
		args.TextXAlignment
		or
		Enum.TextXAlignment.Left


	t.TextYAlignment =
		args.TextYAlignment
		or
		Enum.TextYAlignment.Center


	t.RichText =
		args.RichText
		or false


	t.Visible =
		if args.Visible == nil
		then true
		else args.Visible


	t.Parent =
		parent


	return t

end


local function button(
	parent,
	args
)

	local b =
		Instance.new(
			"TextButton"
		)


	b.BackgroundColor3 =
		args.BackgroundColor3
		or
		COLORS.accent


	b.AutoButtonColor =
		true


	b.Position =
		args.Position
		or
		UDim2.new()


	b.Size =
		args.Size
		or
		UDim2.fromOffset(
			200,
			50
		)


	b.Text =
		args.Text
		or
		"Button"


	b.TextColor3 =
		args.TextColor3
		or
		COLORS.bg


	b.TextSize =
		args.TextSize
		or 20


	b.Font =
		args.Font
		or FONT_BOLD


	b.TextWrapped =
		true


	b.Visible =
		if args.Visible == nil
		then true
		else args.Visible


	b.Parent =
		parent


	corner(
		b,
		8
	)


	return b

end


local function billboard(
	part,
	text,
	color
)

	local gui =
		Instance.new(
			"BillboardGui"
		)


	gui.Name =
		"Label"


	gui.Adornee =
		part


	gui.Size =
		UDim2.fromOffset(
			120,
			40
		)


	gui.StudsOffsetWorldSpace =
		Vector3.new(
			0,
			1.5,
			0
		)


	gui.AlwaysOnTop =
		true


	gui.MaxDistance =
		60


	gui.Parent =
		part


	local t =
		label(
			gui,
			{
				Size =
					UDim2.fromScale(
						1,
						1
					),

				Text =
					text,

				TextColor3 =
					color,

				Font =
					FONT_BOLD,

				TextSize =
					24,

				TextXAlignment =
					Enum.TextXAlignment.Center,
			}
		)


	return
		gui,
		t

end


-- ============================================================
-- COORDINATES
-- ============================================================

local function dataToWorld(
	point,
	y
)

	return
		anchor.CFrame
		:PointToWorldSpace(
			Vector3.new(
				point.X
					*
					Config.SCALE,

				y
					or
					Config.POINT_Y,

				point.Y
					*
					Config.SCALE
			)
		)

end


local function worldToData(
	position
)

	local p =
		anchor.CFrame
		:PointToObjectSpace(
			position
		)


	return
		Vector2.new(
			p.X
				/
				Config.SCALE,

			p.Z
				/
				Config.SCALE
		)

end


local function localToWorld(
	x,
	y,
	z
)

	return
		anchor.CFrame
		:PointToWorldSpace(
			Vector3.new(
				x,
				y,
				z
			)
		)

end


-- ============================================================
-- BUILD FIELD
-- ============================================================

local field =
	makePart(
		{
			Name =
				"KMeansField",

			Size =
				Vector3.new(
					Config.FIELD_X,
					0.35,
					Config.FIELD_Z
				),

			CFrame =
				anchor.CFrame
				*
				CFrame.new(
					0,
					0.15,
					0
				),

			Color =
				Color3.fromRGB(
					42,
					47,
					50
				),

			Material =
				Enum.Material.Slate,

			CanCollide =
				true,
		}
	)


-- Grid

for x = -16, 16, 4 do

	makePart(
		{
			Name =
				"GridX",

			Size =
				Vector3.new(
					0.05,
					0.025,
					Config.FIELD_Z
						-
						1
				),

			CFrame =
				anchor.CFrame
				*
				CFrame.new(
					x,
					0.36,
					0
				),

			Color =
				Color3.fromRGB(
					78,
					83,
					86
				),

			Transparency =
				0.6,
		}
	)

end


for z = -12, 12, 4 do

	makePart(
		{
			Name =
				"GridZ",

			Size =
				Vector3.new(
					Config.FIELD_X
						-
						1,
					0.025,
					0.05
				),

			CFrame =
				anchor.CFrame
				*
				CFrame.new(
					0,
					0.36,
					z
				),

			Color =
				Color3.fromRGB(
					78,
					83,
					86
				),

			Transparency =
				0.6,
		}
	)

end


-- Main axes

makePart(
	{
		Name =
			"AxisX1",

		Size =
			Vector3.new(
				Config.FIELD_X
					-
					1,
				0.05,
				0.12
			),

		CFrame =
			anchor.CFrame
				*
				CFrame.new(
					0,
					0.4,
					0
				),

		Color =
			COLORS.textDim,
	}
)


makePart(
	{
		Name =
			"AxisX2",

		Size =
			Vector3.new(
				0.12,
				0.05,
				Config.FIELD_Z
					-
					1
			),

		CFrame =
			anchor.CFrame
				*
				CFrame.new(
					0,
					0.4,
					0
				),

		Color =
			COLORS.textDim,
	}
)


local axisX1 =
	makePart(
		{
			Name =
				"X1LabelAnchor",

			Size =
				Vector3.new(
					0.2,
					0.2,
					0.2
				),

			CFrame =
				anchor.CFrame
				*
				CFrame.new(
					Config.FIELD_X
						/
						2
						-
						1,
					0.5,
					-0.7
				),

			Transparency =
				1,
		}
	)


billboard(
	axisX1,
	"x₁",
	COLORS.text
)


local axisX2 =
	makePart(
		{
			Name =
				"X2LabelAnchor",

			Size =
				Vector3.new(
					0.2,
					0.2,
					0.2
				),

			CFrame =
				anchor.CFrame
				*
				CFrame.new(
					0.8,
					0.5,
					-Config.FIELD_Z
						/
						2
						+
						1
				),

			Transparency =
				1,
		}
	)


billboard(
	axisX2,
	"x₂",
	COLORS.text
)


-- ============================================================
-- POINTS
-- ============================================================

local points = {}


for i, dataPoint in ipairs(
	dataset.points
) do

	local point =
		makePart(
			{
				Name =
					"Observation_"
					..
					i,

				Shape =
					Enum.PartType.Ball,

				Size =
					Vector3.new(
						0.95,
						0.95,
						0.95
					),

				CFrame =
					CFrame.new(
						dataToWorld(
							dataPoint,
							Config.POINT_Y
						)
					),

				Color =
					POINT_IDLE_COLOR,

				Material =
					Enum.Material.SmoothPlastic,

				CanQuery =
					true,
			}
		)


	local prompt =
		Instance.new(
			"ProximityPrompt"
		)


	prompt.Name =
		"AssignPrompt"


	prompt.ActionText =
		"Назначить точку"


	prompt.ObjectText =
		("Наблюдение %d"):format(
			i
		)


	prompt.KeyboardKeyCode =
		Enum.KeyCode.F


	prompt.HoldDuration =
		0


	prompt.MaxActivationDistance =
		8


	prompt.RequiresLineOfSight =
		false


	prompt.Enabled =
		false


	prompt.Parent =
		point


	points[i] = {

		part =
			point,

		prompt =
			prompt,

		data =
			dataPoint,

	}

end


-- ============================================================
-- CENTROIDS
-- ============================================================

local centroids = {}
local centroidPrompts = {}
local centroidLabels = {}


for cluster = 1, 2 do

	local name =
		if cluster == 1
		then "A"
		else "B"


	local centroid =
		makePart(
			{
				Name =
					"Centroid"
					..
					name,

				Shape =
					Enum.PartType.Ball,

				Size =
					Vector3.new(
						1.55,
						1.55,
						1.55
					),

				Color =
					CENTER_COLORS[
						cluster
					],

				Material =
					Enum.Material.Neon,

				CanQuery =
					true,
			}
		)


	local prompt =
		Instance.new(
			"ProximityPrompt"
		)


	prompt.Name =
		"MoveCentroidPrompt"


	prompt.ActionText =
		"Взять центр "
		..
		name


	prompt.ObjectText =
		"Centroid "
		..
		name


	prompt.KeyboardKeyCode =
		Enum.KeyCode.F


	prompt.HoldDuration =
		0


	prompt.MaxActivationDistance =
		9


	prompt.RequiresLineOfSight =
		false


	prompt.Enabled =
		false


	prompt.Parent =
		centroid


	local bb,
		text =
			billboard(
				centroid,
				"× "
					..
					name,

				CENTER_COLORS[
					cluster
				]
			)


	centroids[cluster] =
		centroid


	centroidPrompts[cluster] =
		prompt


	centroidLabels[cluster] =
		bb

end


-- ============================================================
-- GHOST MEANS
-- ============================================================

local ghosts = {}


for cluster = 1, 2 do

	local ghost =
		makePart(
			{
				Name =
					"MeanTarget"
					..
					cluster,

				Shape =
					Enum.PartType.Cylinder,

				Size =
					Vector3.new(
						0.22,
						2.4,
						2.4
					),

				Color =
					CENTER_COLORS[
						cluster
					],

				Material =
					Enum.Material.Neon,

				Transparency =
					1,
			}
		)


	ghost.CFrame =
		ghost.CFrame
		*
		CFrame.Angles(
			0,
			0,
			math.rad(
				90
			)
		)


	local bb =
		billboard(
			ghost,
			"mean",
			CENTER_COLORS[
				cluster
			]
		)


	bb.Enabled =
		false


	ghosts[cluster] = {

		part =
			ghost,

		label =
			bb,

	}

end


-- ============================================================
-- SCOREBOARD
-- ============================================================

local boardCF =
	anchor.CFrame
	*
	CFrame.new(
		0,
		5.6,
		-Config.FIELD_Z
			/
			2
			-
			5.5
	)
	*
	CFrame.Angles(
		0,
		math.pi,
		0
	)


local boardFrame =
	makePart(
		{
			Name =
				"KMeansBoardFrame",

			Size =
				Vector3.new(
					19,
					11,
					0.45
				),

			CFrame =
				boardCF
				*
				CFrame.new(
					0,
					0,
					0.25
				),

			Color =
				COLORS.boardFrame,
		}
	)


local boardScreen =
	makePart(
		{
			Name =
				"KMeansBoard",

			Size =
				Vector3.new(
					18,
					10,
					0.4
				),

			CFrame =
				boardCF,

			Color =
				COLORS.bg,
		}
	)


local boardGui =
	Instance.new(
		"SurfaceGui"
	)


boardGui.Name =
	"KMeansBoardGui"


boardGui.Adornee =
	boardScreen


boardGui.Face =
	Enum.NormalId.Front


boardGui.SizingMode =
	Enum.SurfaceGuiSizingMode.PixelsPerStud


boardGui.PixelsPerStud =
	55


boardGui.LightInfluence =
	0


boardGui.ResetOnSpawn =
	false


boardGui.Parent =
	playerGui


local boardRoot =
	Instance.new(
		"Frame"
	)


boardRoot.Size =
	UDim2.fromScale(
		1,
		1
	)


boardRoot.BackgroundColor3 =
	COLORS.bg


boardRoot.BorderSizePixel =
	0


boardRoot.Parent =
	boardGui


local boardTitle =
	label(
		boardRoot,
		{
			Position =
				UDim2.fromOffset(
					30,
					20
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					55
				),

			Text =
				"K-MEANS · РУЧКАМИ",

			Font =
				FONT_BOLD,

			TextSize =
				34,
		}
	)


local boardStep =
	label(
		boardRoot,
		{
			Position =
				UDim2.fromOffset(
					30,
					85
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					50
				),

			Text =
				"Подойди к полю",

			TextColor3 =
				COLORS.accent,

			Font =
				FONT_BOLD,

			TextSize =
				27,
		}
	)


local boardMessage =
	label(
		boardRoot,
		{
			Position =
				UDim2.fromOffset(
					30,
					145
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					145
				),

			Text =
				"Здесь ты вручную выполнишь цикл K-means.",

			TextSize =
				24,

			TextYAlignment =
				Enum.TextYAlignment.Top,
		}
	)


local boardMetrics =
	label(
		boardRoot,
		{
			Position =
				UDim2.fromOffset(
					30,
					310
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					110
				),

			Text =
				"Iteration: 0\nAssigned: 0",

			Font =
				FONT_BOLD,

			TextSize =
				25,

			TextColor3 =
				COLORS.textDim,

			TextYAlignment =
				Enum.TextYAlignment.Top,
		}
	)


local boardMeans =
	label(
		boardRoot,
		{
			Position =
				UDim2.fromOffset(
					30,
					430
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					100
				),

			Text =
				"",

			TextSize =
				22,

			TextYAlignment =
				Enum.TextYAlignment.Top,
		}
	)


-- ============================================================
-- HUD
-- ============================================================

local hud =
	Instance.new(
		"ScreenGui"
	)


hud.Name =
	"KMeansHUD"


hud.ResetOnSpawn =
	false


hud.IgnoreGuiInset =
	false


hud.DisplayOrder =
	40


hud.Enabled =
	false


hud.Parent =
	playerGui


local hudRoot =
	Instance.new(
		"Frame"
	)


hudRoot.Name =
	"LessonCard"


hudRoot.Position =
	UDim2.fromOffset(
		24,
		90
	)


hudRoot.Size =
	UDim2.fromOffset(
		430,
		300
	)


hudRoot.BackgroundColor3 =
	COLORS.bg


hudRoot.BackgroundTransparency =
	0.05


hudRoot.BorderSizePixel =
	0


hudRoot.Parent =
	hud


corner(
	hudRoot,
	12
)


stroke(
	hudRoot,
	COLORS.textDim,
	1,
	0.55
)


local hudTitle =
	label(
		hudRoot,
		{
			Position =
				UDim2.fromOffset(
					20,
					14
				),

			Size =
				UDim2.new(
					1,
					-40,
					0,
					32
				),

			Text =
				"K-MEANS",

			TextSize =
				26,

			Font =
				FONT_BOLD,
		}
	)


local hudStep =
	label(
		hudRoot,
		{
			Position =
				UDim2.fromOffset(
					20,
					48
				),

			Size =
				UDim2.new(
					1,
					-40,
					0,
					30
				),

			Text =
				"Ручной алгоритм",

			TextSize =
				18,

			TextColor3 =
				COLORS.accent,

			Font =
				FONT_BOLD,
		}
	)


local hudTask =
	label(
		hudRoot,
		{
			Position =
				UDim2.fromOffset(
					20,
					84
				),

			Size =
				UDim2.new(
					1,
					-40,
					0,
					86
				),

			Text =
				"Подойди к площадке.",

			TextSize =
				20,

			TextYAlignment =
				Enum.TextYAlignment.Top,
		}
	)


local hudStatus =
	label(
		hudRoot,
		{
			Position =
				UDim2.fromOffset(
					20,
					172
				),

			Size =
				UDim2.new(
					1,
					-40,
					0,
					43
				),

			Text =
				"",

			TextSize =
				17,

			TextColor3 =
				COLORS.textDim,
		}
	)


local primaryButton =
	button(
		hudRoot,
		{
			Position =
				UDim2.fromOffset(
					20,
					224
				),

			Size =
				UDim2.fromOffset(
					280,
					54
				),

			Text =
				"Continue",

			Visible =
				false,
		}
	)


local resetButton =
	button(
		hudRoot,
		{
			Position =
				UDim2.fromOffset(
					312,
					224
				),

			Size =
				UDim2.fromOffset(
					98,
					54
				),

			Text =
				"Reset",

			BackgroundColor3 =
				COLORS.panel,

			TextColor3 =
				COLORS.text,

			TextSize =
				17,
		}
	)


-- ============================================================
-- ASSIGNMENT MODAL
-- ============================================================

local assignModal =
	Instance.new(
		"Frame"
	)


assignModal.Name =
	"AssignmentModal"


assignModal.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)


assignModal.Position =
	UDim2.fromScale(
		0.5,
		0.55
	)


assignModal.Size =
	UDim2.fromOffset(
		590,
		390
	)


assignModal.BackgroundColor3 =
	COLORS.bg


assignModal.BorderSizePixel =
	0


assignModal.Visible =
	false


assignModal.Parent =
	hud


corner(
	assignModal,
	14
)


stroke(
	assignModal,
	COLORS.accent,
	2,
	0.15
)


local assignTitle =
	label(
		assignModal,
		{
			Position =
				UDim2.fromOffset(
					26,
					20
				),

			Size =
				UDim2.new(
					1,
					-52,
					0,
					42
				),

			Text =
				"К какому центру ближе точка?",

			TextSize =
				28,

			Font =
				FONT_BOLD,
		}
	)


local assignCoords =
	label(
		assignModal,
		{
			Position =
				UDim2.fromOffset(
					26,
					72
				),

			Size =
				UDim2.new(
					1,
					-52,
					0,
					46
				),

			Text =
				"x = (?, ?)",

			TextSize =
				21,

			TextColor3 =
				COLORS.textDim,
		}
	)


local assignDistances =
	label(
		assignModal,
		{
			Position =
				UDim2.fromOffset(
					26,
					125
				),

			Size =
				UDim2.new(
					1,
					-52,
					0,
					100
				),

			Text =
				"",

			TextSize =
				23,

			Font =
				FONT_BOLD,

			TextYAlignment =
				Enum.TextYAlignment.Top,
		}
	)


local assignFeedback =
	label(
		assignModal,
		{
			Position =
				UDim2.fromOffset(
					26,
					225
				),

			Size =
				UDim2.new(
					1,
					-52,
					0,
					40
				),

			Text =
				"Сравни два квадрата расстояния.",

			TextSize =
				18,

			TextColor3 =
				COLORS.textDim,
		}
	)


local chooseA =
	button(
		assignModal,
		{
			Position =
				UDim2.fromOffset(
					26,
					290
				),

			Size =
				UDim2.fromOffset(
					250,
					65
				),

			Text =
				"RED · A",

			BackgroundColor3 =
				CENTER_COLORS[1],

			TextColor3 =
				Color3.new(
					1,
					1,
					1
				),

			TextSize =
				23,
		}
	)


local chooseB =
	button(
		assignModal,
		{
			Position =
				UDim2.fromOffset(
					314,
					290
				),

			Size =
				UDim2.fromOffset(
					250,
					65
				),

			Text =
				"BLUE · B",

			BackgroundColor3 =
				CENTER_COLORS[2],

			TextColor3 =
				Color3.new(
					1,
					1,
					1
				),

			TextSize =
				23,
		}
	)


-- ============================================================
-- FORMAL PANEL
-- ============================================================

local formal =
	Instance.new(
		"Frame"
	)


formal.Name =
	"FormalPanel"


formal.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)


formal.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)


formal.Size =
	UDim2.new(
		0.72,
		0,
		0.72,
		0
	)


formal.BackgroundColor3 =
	COLORS.bg


formal.BorderSizePixel =
	0


formal.Visible =
	false


formal.Parent =
	hud


corner(
	formal,
	14
)


stroke(
	formal,
	COLORS.accent,
	2,
	0.2
)


local formalHeader =
	label(
		formal,
		{
			Position =
				UDim2.fromOffset(
					30,
					22
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					48
				),

			Text =
				"K-MEANS · ФОРМАЛЬНО",

			TextSize =
				31,

			Font =
				FONT_BOLD,
		}
	)


local formalPageTitle =
	label(
		formal,
		{
			Position =
				UDim2.fromOffset(
					30,
					82
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					45
				),

			Text =
				"",

			TextSize =
				25,

			Font =
				FONT_BOLD,

			TextColor3 =
				COLORS.accent,
		}
	)


local formalFormula =
	label(
		formal,
		{
			Position =
				UDim2.fromOffset(
					30,
					140
				),

			Size =
				UDim2.new(
					1,
					-60,
					0,
					90
				),

			Text =
				"",

			TextSize =
				31,

			Font =
				FONT_BOLD,

			TextXAlignment =
				Enum.TextXAlignment.Center,
		}
	)


local formalBody =
	label(
		formal,
		{
			Position =
				UDim2.fromOffset(
					45,
					240
				),

			Size =
				UDim2.new(
					1,
					-90,
					0,
					130
				),

			Text =
				"",

			TextSize =
				21,

			TextYAlignment =
				Enum.TextYAlignment.Top,
		}
	)


local formalCode =
	label(
		formal,
		{
			Position =
				UDim2.fromOffset(
					45,
					375
				),

			Size =
				UDim2.new(
					1,
					-90,
					0,
					180
				),

			Text =
				"",

			TextSize =
				18,

			Font =
				Enum.Font.Code,

			TextYAlignment =
				Enum.TextYAlignment.Top,

			TextColor3 =
				Color3.fromRGB(
					220,
					225,
					215
				),

			BackgroundTransparency =
				0,

			BackgroundColor3 =
				Color3.fromRGB(
					24,
					27,
					29
				),
		}
	)


corner(
	formalCode,
	8
)


local formalNext =
	button(
		formal,
		{
			AnchorPoint =
				Vector2.new(
					1,
					1
				),

			Position =
				UDim2.new(
					1,
					-30,
					1,
					-25
				),

			Size =
				UDim2.fromOffset(
					190,
					52
				),

			Text =
				"Дальше",
		}
	)


local formalClose =
	button(
		formal,
		{
			AnchorPoint =
				Vector2.new(
					0,
					1
				),

			Position =
				UDim2.new(
					0,
					30,
					1,
					-25
				),

			Size =
				UDim2.fromOffset(
					120,
					52
				),

			Text =
				"Закрыть",

			BackgroundColor3 =
				COLORS.panel,

			TextColor3 =
				COLORS.text,
		}
	)


-- ============================================================
-- STATE
-- ============================================================

local started = false

local phase =
	"WAIT"


local labels =
	table.create(
		#dataset.points
	)


local placed = {
	false,
	false,
}


local updateDone = {
	false,
	false,
}


local targetMeans = nil
local meanCounts = nil

local iteration = 0
local manualCount = 0

local carrying = nil
local selectedPoint = nil

local busy = false

local primaryAction = nil

local inertiaHistory = {}

local currentCorrectCluster = nil


-- forward declarations

local resetLesson
local beginUpdate
local autoAssignRemaining
local reassignAll
local openFormal


-- ============================================================
-- BASIC STATE HELPERS
-- ============================================================

local function currentCenters()

	return {

		worldToData(
			centroids[1].Position
		),

		worldToData(
			centroids[2].Position
		),

	}

end


local function countAssigned()

	local n = 0


	for i = 1, #labels do

		if labels[i] then
			n += 1
		end

	end


	return n

end


local function setPointCluster(
	index,
	cluster
)

	labels[index] =
		cluster


	if cluster then

		points[index].part.Color =
			CENTER_COLORS[
				cluster
			]

	else

		points[index].part.Color =
			POINT_IDLE_COLOR

	end

end


local function clearTemporary()

	for _, child in ipairs(
		temporary:GetChildren()
	) do

		child:Destroy()

	end

end


local function showStatus(
	text,
	color
)

	hudStatus.Text =
		text
		or ""


	hudStatus.TextColor3 =
		color
		or
		COLORS.textDim

end


local function setPrimary(
	text,
	callback
)

	primaryAction =
		callback


	if text then

		primaryButton.Text =
			text


		primaryButton.Visible =
			true

	else

		primaryButton.Visible =
			false

	end

end


local function formatInertiaHistory()

	if #inertiaHistory == 0 then
		return "—"
	end


	local start =
		math.max(
			1,
			#inertiaHistory
				-
				3
		)


	local values = {}


	for i = start, #inertiaHistory do

		table.insert(
			values,
			("%.1f"):format(
				inertiaHistory[i]
			)
		)

	end


	return
		table.concat(
			values,
			" → "
		)

end


local function currentInertia()

	return
		MathCore.inertia(
			dataset.points,
			labels,
			currentCenters()
		)

end


local function refreshBoard()

	local assigned =
		countAssigned()


	boardMetrics.Text =
		(
			"Iteration: %d\nAssigned: %d / %d\nInertia: %s"
		):format(
			iteration,
			assigned,
			#dataset.points,

			if assigned > 0
			then
				("%.2f"):format(
					currentInertia()
				)
			else
				"—"
		)


	if
		targetMeans
		and
		meanCounts
	then

		boardMeans.Text =
			(
				"μA = (%.2f, %.2f), n=%d\nμB = (%.2f, %.2f), n=%d"
			):format(
				targetMeans[1].X,
				targetMeans[1].Y,
				meanCounts[1],

				targetMeans[2].X,
				targetMeans[2].Y,
				meanCounts[2]
			)

	else

		boardMeans.Text =
			"Inertia history: "
			..
			formatInertiaHistory()

	end

end


local function setAllPointPrompts(
	enabled
)

	for i, entry in ipairs(
		points
	) do

		entry.prompt.Enabled =
			enabled
			and
			labels[i] == nil

	end

end


local function setCentroidPrompts(
	a,
	b
)

	centroidPrompts[1].Enabled =
		a


	centroidPrompts[2].Enabled =
		b

end


-- ============================================================
-- PHASE UI
-- ============================================================

local function setPhase(
	newPhase
)

	phase =
		newPhase


	setPrimary(
		nil,
		nil
	)


	setAllPointPrompts(
		false
	)


	setCentroidPrompts(
		false,
		false
	)


	if phase == "WAIT" then

		hudStep.Text =
			"Ручной алгоритм"


		hudTask.Text =
			"Подойди к площадке K-means."


		boardStep.Text =
			"K-means"


		boardMessage.Text =
			"Подойди к полю, чтобы начать."


	elseif phase == "PLACE" then

		hudStep.Text =
			"1 / 4 · Инициализация"


		hudTask.Text =
			"Поставь два начальных центра. Подойди к centroid и нажми F. Пока несёшь его — ходи по полю. Ещё раз F — поставить."


		boardStep.Text =
			"1. INITIALIZE CENTROIDS"


		boardMessage.Text =
			"K-means начинается с начальных центров. Поставь A и B вручную."


		setCentroidPrompts(
			true,
			true
		)


	elseif phase == "ASSIGN_MANUAL" then

		hudStep.Text =
			"2 / 4 · Assignment"


		hudTask.Text =
			("Назначь %d точек вручную. F у точки → сравни d² до A и B → выбери ближайший центр.")
			:format(
				Config.MANUAL_POINTS
			)


		boardStep.Text =
			"2. ASSIGN POINTS"


		boardMessage.Text =
			"Для каждой точки выбираем ближайший centroid: минимальное квадратное расстояние."


		setAllPointPrompts(
			true
		)


	elseif phase == "MANUAL_READY" then

		hudStep.Text =
			"2 / 4 · Assignment"


		hudTask.Text =
			"Правило уже выполнено вручную несколько раз. Теперь можно применить его ко всем оставшимся наблюдениям."


		boardStep.Text =
			"2. ASSIGN POINTS"


		boardMessage.Text =
			"Ты понял правило nearest centroid. Остальные назначения можно автоматизировать."


		setPrimary(
			"Назначить остальные",
			function()

				autoAssignRemaining()

			end
		)


	elseif phase == "UPDATE" then

		hudStep.Text =
			"3 / 4 · Update centroid"


		hudTask.Text =
			"Теперь перенеси каждый centroid в среднее положение точек своего кластера. Полупрозрачный круг показывает рассчитанный mean."


		boardStep.Text =
			"3. UPDATE CENTROIDS"


		boardMessage.Text =
			"Новый centroid = среднее координат всех точек своего кластера."


		setCentroidPrompts(
			not updateDone[1],
			not updateDone[2]
		)


	elseif phase == "REASSIGN" then

		hudStep.Text =
			"4 / 4 · Repeat"


		hudTask.Text =
			"Центры изменились. Значит ближайший центр для некоторых точек тоже мог измениться."


		boardStep.Text =
			"4. REPEAT"


		boardMessage.Text =
			"Снова выполним assignment. Если точки перестанут менять кластер — алгоритм сошёлся."


		setPrimary(
			"Назначить точки снова",
			function()

				reassignAll()

			end
		)


	elseif phase == "CONVERGED" then

		hudStep.Text =
			"CONVERGED"


		hudTask.Text =
			"0 точек изменили кластер. Следующий assignment даст тот же результат: K-means сошёлся."


		boardStep.Text =
			"CONVERGED"


		boardStep.TextColor3 =
			COLORS.good


		boardMessage.Text =
			"Centroids больше не требуют изменения. Ручной цикл K-means завершён."


		setPrimary(
			"Открыть формальную часть",
			function()

				openFormal()

			end
		)


	elseif phase == "EMPTY" then

		hudStep.Text =
			"EMPTY CLUSTER"


		hudTask.Text =
			"Один из центров не получил ни одной точки. Для учебного примера начнём с других начальных центров."


		boardStep.Text =
			"EMPTY CLUSTER"


		boardMessage.Text =
			"Один кластер пуст. Такое может случиться при плохой инициализации."


		setPrimary(
			"Начать заново",
			function()

				resetLesson()

			end
		)

	end


	refreshBoard()

end


-- ============================================================
-- DISTANCE LINES
-- ============================================================

local function lineBetween(
	a,
	b,
	color
)

	local midpoint =
		(a + b)
		/
		2


	local length =
		(b - a).Magnitude


	local line =
		makePart(
			{
				Name =
					"DistanceLine",

				Size =
					Vector3.new(
						0.11,
						0.11,
						length
					),

				CFrame =
					CFrame.lookAt(
						midpoint,
						b
					),

				Color =
					color,

				Material =
					Enum.Material.Neon,

				Parent =
					temporary,
			}
		)


	return line

end


-- ============================================================
-- ASSIGNMENT MODAL
-- ============================================================

local function closeAssignment()

	assignModal.Visible =
		false


	selectedPoint =
		nil


	currentCorrectCluster =
		nil


	clearTemporary()

end


local function openAssignment(
	index
)

	if phase ~= "ASSIGN_MANUAL" then
		return
	end


	if labels[index] then
		return
	end


	selectedPoint =
		index


	local pointData =
		dataset.points[index]


	local centers =
		currentCenters()


	local dA =
		MathCore.dist2(
			pointData,
			centers[1]
		)


	local dB =
		MathCore.dist2(
			pointData,
			centers[2]
		)


	currentCorrectCluster =
		if dA <= dB
		then 1
		else 2


	assignTitle.Text =
		("Наблюдение %d: какой centroid ближе?")
		:format(
			index
		)


	assignCoords.Text =
		(
			"x = (%.1f, %.1f)"
		):format(
			pointData.X,
			pointData.Y
		)


	assignDistances.Text =
		(
			"d²(A) = %.2f\n"
			..
			"d²(B) = %.2f"
		):format(
			dA,
			dB
		)


	assignFeedback.Text =
		"Выбери центр с меньшим d²."


	assignFeedback.TextColor3 =
		COLORS.textDim


	clearTemporary()


	local pointPosition =
		points[index].part.Position
		+
		Vector3.new(
			0,
			0.4,
			0
		)


	for cluster = 1, 2 do

		lineBetween(
			pointPosition,
			centroids[cluster].Position,
			CENTER_COLORS[
				cluster
			]
		)

	end


	assignModal.Visible =
		true

end


local function chooseCluster(
	cluster
)

	if
		not selectedPoint
		or
		not currentCorrectCluster
	then

		return

	end


	if cluster ~= currentCorrectCluster then

		assignFeedback.Text =
			"Не тот центр: сравни значения d² ещё раз."


		assignFeedback.TextColor3 =
			COLORS.bad


		return

	end


	local index =
		selectedPoint


	setPointCluster(
		index,
		cluster
	)


	points[index].prompt.Enabled =
		false


	manualCount +=
		1


	closeAssignment()


	showStatus(
		(
			"Верно. Вручную назначено: %d / %d"
		):format(
			manualCount,
			Config.MANUAL_POINTS
		),

		COLORS.good
	)


	refreshBoard()


	if
		manualCount
		>=
		Config.MANUAL_POINTS
	then

		setPhase(
			"MANUAL_READY"
		)

	else

		setAllPointPrompts(
			true
		)

	end

end


chooseA.Activated:Connect(
	function()

		chooseCluster(
			1
		)

	end
)


chooseB.Activated:Connect(
	function()

		chooseCluster(
			2
		)

	end
)


for i, entry in ipairs(
	points
) do

	entry.prompt.Triggered:Connect(
		function()

			openAssignment(
				i
			)

		end
	)

end


-- ============================================================
-- BEGIN CENTROID UPDATE
-- ============================================================

beginUpdate =
	function()

		local centers =
			currentCenters()


		local means,
			counts =
				MathCore.means(
					dataset.points,
					labels,
					2,
					centers
				)


		if
			counts[1] == 0
			or
			counts[2] == 0
		then

			targetMeans =
				nil


			meanCounts =
				counts


			setPhase(
				"EMPTY"
			)


			return

		end


		targetMeans =
			means


		meanCounts =
			counts


		updateDone = {
			false,
			false,
		}


		for cluster = 1, 2 do

			local pos =
				dataToWorld(
					targetMeans[
						cluster
					],

					0.52
				)


			ghosts[cluster].part.CFrame =
				CFrame.new(
					pos
				)
				*
				CFrame.Angles(
					0,
					0,
					math.rad(
						90
					)
				)


			ghosts[cluster].part.Transparency =
				0.42


			ghosts[cluster].label.Enabled =
				true

		end


		setPhase(
			"UPDATE"
		)


		showStatus(
			"Подойди к centroid A или B, F — взять. Поставь его на соответствующий mean.",
			COLORS.accent
		)

	end


-- ============================================================
-- AUTO ASSIGN REMAINING
-- ============================================================

autoAssignRemaining =
	function()

		if busy then
			return
		end


		busy =
			true


		setPrimary(
			nil,
			nil
		)


		setAllPointPrompts(
			false
		)


		local centers =
			currentCenters()


		local newLabels,
			inertia =
				MathCore.assign(
					dataset.points,
					centers
				)


		local remaining = {}


		for i = 1, #dataset.points do

			if not labels[i] then

				table.insert(
					remaining,
					i
				)

			end

		end


		for order,
			index in ipairs(
				remaining
			)
		do

			task.delay(
				(order - 1)
					*
					Config.AUTO_ASSIGN_DELAY,

				function()

					setPointCluster(
						index,
						newLabels[
							index
						]
					)


					refreshBoard()

				end
			)

		end


		local totalTime =
			#remaining
			*
			Config.AUTO_ASSIGN_DELAY
			+
			0.15


		task.delay(
			totalTime,

			function()

				labels =
					newLabels


				table.insert(
					inertiaHistory,
					inertia
				)


				busy =
					false


				refreshBoard()


				showStatus(
					(
						"Все точки назначены. Inertia = %.2f"
					):format(
						inertia
					),

					COLORS.good
				)


				beginUpdate()

			end
		)

	end


-- ============================================================
-- REASSIGN ALL
-- ============================================================

reassignAll =
	function()

		if busy then
			return
		end


		busy =
			true


		setPrimary(
			nil,
			nil
		)


		local centers =
			currentCenters()


		local newLabels,
			inertia =
				MathCore.assign(
					dataset.points,
					centers
				)


		local changed =
			MathCore.changedCount(
				labels,
				newLabels
			)


		for i = 1, #dataset.points do

			task.delay(
				(i - 1)
					*
					0.035,

				function()

					setPointCluster(
						i,
						newLabels[
							i
						]
					)

				end
			)

		end


		task.delay(
			#dataset.points
				*
				0.035
				+
				0.1,

			function()

				labels =
					newLabels


				table.insert(
					inertiaHistory,
					inertia
				)


				busy =
					false


				refreshBoard()


				if changed == 0 then

					showStatus(
						"0 points changed cluster.",
						COLORS.good
					)


					setPhase(
						"CONVERGED"
					)

				else

					showStatus(
						(
							"%d точек сменили кластер. Теперь снова обновим centroids."
						):format(
							changed
						),

						COLORS.accent
					)


					task.delay(
						0.5,

						function()

							beginUpdate()

						end
					)

				end

			end
		)

	end


-- ============================================================
-- CENTROID INTERACTION
-- ============================================================

local function finishCentroidDrop(
	cluster
)

	local prompt =
		centroidPrompts[
			cluster
		]


	local name =
		if cluster == 1
		then "A"
		else "B"


	if phase == "PLACE" then

		placed[cluster] =
			true


		prompt.ActionText =
			"Переместить центр "
			..
			name


		if
			placed[1]
			and
			placed[2]
		then

			local centers =
				currentCenters()


			local distance =
				(
					centers[1]
					-
					centers[2]
				).Magnitude


			if
				distance
				<
				Config.MIN_INITIAL_CENTROID_DISTANCE
			then

				placed[cluster] =
					false


				showStatus(
					"Centroids слишком близко друг к другу. Разнеси их.",
					COLORS.bad
				)


				return

			end


			showStatus(
				"Начальные centroids готовы.",
				COLORS.good
			)


			task.delay(
				0.25,

				function()

					setPhase(
						"ASSIGN_MANUAL"
					)

				end
			)

		end


	elseif phase == "UPDATE" then

		if
			not targetMeans
			or
			updateDone[cluster]
		then

			return

		end


		local target =
			dataToWorld(
				targetMeans[
					cluster
				],

				Config.CENTROID_Y
			)


		local distance =
			(
				centroids[cluster].Position
				-
				target
			).Magnitude


		if
			distance
			<=
			Config.UPDATE_TOLERANCE
		then

			centroids[cluster].CFrame =
				CFrame.new(
					target
				)


			updateDone[cluster] =
				true


			ghosts[cluster].part.Transparency =
				1


			ghosts[cluster].label.Enabled =
				false


			prompt.Enabled =
				false


			showStatus(
				"Centroid "
				..
				name
				..
				" установлен в mean.",

				COLORS.good
			)


			if
				updateDone[1]
				and
				updateDone[2]
			then

				iteration +=
					1


				targetMeans =
					nil


				meanCounts =
					nil


				refreshBoard()


				task.delay(
					0.3,

					function()

						setPhase(
							"REASSIGN"
						)

					end
				)

			end

		else

			showStatus(
				(
					"Пока не mean. Осталось примерно %.1f studs."
				):format(
					distance
				),

				COLORS.bad
			)

		end

	end

end


for cluster = 1, 2 do

	centroidPrompts[
		cluster
	].Triggered:Connect(
		function()

			if
				phase ~= "PLACE"
				and
				phase ~= "UPDATE"
			then

				return

			end


			local name =
				if cluster == 1
				then "A"
				else "B"


			if
				carrying
				and
				carrying ~= cluster
			then

				showStatus(
					"Сначала поставь centroid, который уже несёшь.",
					COLORS.bad
				)


				return

			end


			if carrying == cluster then

				carrying =
					nil


				centroidPrompts[
					cluster
				].ActionText =
					"Взять центр "
					..
					name


				finishCentroidDrop(
					cluster
				)


			else

				carrying =
					cluster


				if phase == "PLACE" then

					placed[cluster] =
						false

				end


				centroidPrompts[
					cluster
				].ActionText =
					"Поставить центр "
					..
					name


				showStatus(
					"Иди по полю вместе с centroid. F ещё раз — поставить.",
					CENTER_COLORS[
						cluster
					]
				)

			end

		end
	)

end


-- ============================================================
-- FORMAL LESSON
-- ============================================================

local formalPage = 1


local formalPages = {

	{

		title =
			"1. Assignment step",

		formula =
			"cᵢ = argminₖ ‖xᵢ − μₖ‖²",

		body =
			"Для каждой точки рассматриваем расстояние до каждого centroid и выбираем ближайший. Именно это ты делал вручную, сравнивая d²(A) и d²(B).",

		code =
			"",

	},

	{

		title =
			"2. Update step",

		formula =
			"μₖ = (1 / |Cₖ|) Σᵢ∈Cₖ xᵢ",

		body =
			"После assignment центр каждого кластера переносится в среднее положение его точек. Полупрозрачные цели на поле были именно этими средними.",

		code =
			"",

	},

	{

		title =
			"3. Objective + real Python",

		formula =
			"J = Σᵢ ‖xᵢ − μcᵢ‖²",

		body =
			"K-means повторяет Assignment → Update, пока результат перестаёт меняться. J обычно называют inertia: суммой квадратов расстояний точек до своих центров.",

		code =
			"from sklearn.cluster import KMeans\n\n"
			..
			"model = KMeans(\n"
			..
			"    n_clusters=2,\n"
			..
			"    random_state=42\n"
			..
			")\n\n"
			..
			"labels = model.fit_predict(X)\n"
			..
			"print(model.cluster_centers_)\n"
			..
			"print(model.inertia_)",

	},

}


local function renderFormalPage()

	local page =
		formalPages[
			formalPage
		]


	formalPageTitle.Text =
		page.title


	formalFormula.Text =
		page.formula


	formalBody.Text =
		page.body


	formalCode.Text =
		page.code


	formalCode.Visible =
		page.code ~= ""


	formalNext.Text =
		if
			formalPage
			==
			#formalPages
		then
			"Готово"
		else
			"Дальше"

end


openFormal =
	function()

	formalPage =
		1


	renderFormalPage()


	formal.Visible =
		true


	assignModal.Visible =
		false


	showStatus(
		"Теперь те же действия записаны математически.",
		COLORS.accent
	)

end


formalNext.Activated:Connect(
	function()

		if
			formalPage
			<
			#formalPages
		then

			formalPage +=
				1


			renderFormalPage()

		else

			formal.Visible =
				false

		end

	end
)


formalClose.Activated:Connect(
	function()

		formal.Visible =
			false

	end
)


-- ============================================================
-- RESET
-- ============================================================

resetLesson =
	function()

	busy =
		false


	carrying =
		nil


	selectedPoint =
		nil


	currentCorrectCluster =
		nil


	assignModal.Visible =
		false


	formal.Visible =
		false


	clearTemporary()


	labels =
		table.create(
			#dataset.points
		)


	placed = {
		false,
		false,
	}


	updateDone = {
		false,
		false,
	}


	targetMeans =
		nil


	meanCounts =
		nil


	iteration =
		0


	manualCount =
		0


	inertiaHistory =
		{}


	boardStep.TextColor3 =
		COLORS.accent


	for i = 1, #points do

		setPointCluster(
			i,
			nil
		)


		points[i].prompt.Enabled =
			false

	end


	for cluster = 1, 2 do

		ghosts[cluster].part.Transparency =
			1


		ghosts[cluster].label.Enabled =
			false


		centroidPrompts[cluster].ActionText =
			"Взять центр "
			..
			(
				if cluster == 1
				then "A"
				else "B"
			)

	end


	local startA =
		localToWorld(
			-4.5,
			Config.CENTROID_Y,
			Config.FIELD_Z
				/
				2
				-
				2
		)


	local startB =
		localToWorld(
			4.5,
			Config.CENTROID_Y,
			Config.FIELD_Z
				/
				2
				-
				2
		)


	centroids[1].CFrame =
		CFrame.new(
			startA
		)


	centroids[2].CFrame =
		CFrame.new(
			startB
		)


	if started then

		setPhase(
			"PLACE"
		)


		showStatus(
			"F — взять centroid, ещё раз F — поставить.",
			COLORS.textDim
		)

	else

		setPhase(
			"WAIT"
		)

	end


	refreshBoard()

end


resetButton.Activated:Connect(
	function()

		resetLesson()

	end
)


primaryButton.Activated:Connect(
	function()

		if
			primaryAction
			and
			not busy
		then

			primaryAction()

		end

	end
)


-- ============================================================
-- ZONE
-- ============================================================

local function insideZone(
	worldPosition
)

	local localPosition =
		zone.CFrame
		:PointToObjectSpace(
			worldPosition
		)


	return
		math.abs(
			localPosition.X
		)
			<=
			zone.Size.X / 2

		and

		math.abs(
			localPosition.Y
		)
			<=
			zone.Size.Y / 2

		and

		math.abs(
			localPosition.Z
		)
			<=
			zone.Size.Z / 2

end


-- ============================================================
-- MAIN LOOP
-- ============================================================

local zoneAccumulator = 0
local wasInside = false


RunService.RenderStepped:Connect(
	function(dt)

		-- ----------------------------------------------------
		-- CENTROID FOLLOWS PLAYER WHILE BEING CARRIED
		-- ----------------------------------------------------

		if carrying then

			local character =
				player.Character


			local root =
				character
				and
				character:FindFirstChild(
					"HumanoidRootPart"
				)


			if root then

				local localPlayerPosition =
					anchor.CFrame
					:PointToObjectSpace(
						root.Position
					)


				local x =
					math.clamp(
						localPlayerPosition.X,

						-Config.FIELD_X
							/
							2
							+
							1,

						Config.FIELD_X
							/
							2
							-
							1
					)


				local z =
					math.clamp(
						localPlayerPosition.Z,

						-Config.FIELD_Z
							/
							2
							+
							1,

						Config.FIELD_Z
							/
							2
							-
							1
					)


				local worldPosition =
					localToWorld(
						x,
						Config.CENTROID_Y,
						z
					)


				centroids[
					carrying
				].CFrame =
					CFrame.new(
						worldPosition
					)

			end

		end


		-- ----------------------------------------------------
		-- CHECK LEVEL ZONE
		-- ----------------------------------------------------

		zoneAccumulator +=
			dt


		if zoneAccumulator >= 0.08 then

			zoneAccumulator =
				0


			local character =
				player.Character


			local root =
				character
				and
				character:FindFirstChild(
					"HumanoidRootPart"
				)


			if root then

				local inside =
					insideZone(
						root.Position
					)


				hud.Enabled =
					inside


				if
					inside
					and
					not wasInside
				then

					if not started then

						started =
							true


						resetLesson()

					end

				end


				if
					not inside
					and
					wasInside
				then

					closeAssignment()


					formal.Visible =
						false


					if carrying then

						local cluster =
							carrying


						carrying =
							nil


						centroidPrompts[
							cluster
						].ActionText =
							"Взять центр "
							..
							(
								if cluster == 1
									then "A"
									else "B"
							)

					end

				end


				wasInside =
					inside

			end

		end

	end
)


-- ============================================================
-- INITIAL
-- ============================================================

resetLesson()


-- ============================================================
-- STUDIO DEBUG
-- ============================================================

if RunService:IsStudio() then

	_G.KMeansDebug = {

		reset =
			function()

				started =
					true

				resetLesson()

			end,


		formal =
			function()

				hud.Enabled =
					true

				openFormal()

			end,


		state =
			function()

				return {

					phase =
						phase,

					iteration =
						iteration,

					manualCount =
						manualCount,

					assigned =
						countAssigned(),

					centers =
						currentCenters(),

					inertia =
						currentInertia(),

				}

			end,

	}

end


print(
	"[KMeansClient] loaded"
)

