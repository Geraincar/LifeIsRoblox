local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- =========================================================
-- REFERENCES
-- =========================================================

local beeTemplate =
	ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Bees")
	:WaitForChild("AmbientBee")

local hive =
	workspace:WaitForChild("Hive")

local hiveCenter =
	hive:WaitForChild("BeeCenter")


-- =========================================================
-- NORMAL SWARM SETTINGS
-- =========================================================

local BEE_COUNT = 600


-- Размер обычного роя

local MIN_RADIUS = 18
local MAX_RADIUS = 20

-- Чем больше, тем больше пчёл около улья
local ORBIT_DENSITY_POWER = 2.2


-- Верхняя и нижняя границы обычного роя
-- относительно BeeCenter

local MIN_Y = -12
local MAX_Y = 20

-- Чем больше, тем меньше пчёл долетает
-- до верхней/нижней границы
local VERTICAL_DENSITY_POWER = 2.2


-- Скорость обычного полёта

local MIN_SPEED = 0.35
local MAX_SPEED = 0.9

local MIN_ELEVATION_SPEED = 0.15
local MAX_ELEVATION_SPEED = 0.45


-- Неровность обычной траектории

local PATH_DISTORTION = 1.5


-- Плавный noise

local NOISE_XZ_AMOUNT = 1.2
local NOISE_Y_AMOUNT = 0.5

local NOISE_XZ_SPEED = 0.4
local NOISE_Y_SPEED = 0.55


-- =========================================================
-- 67 EASTER EGG SETTINGS
-- =========================================================

-- Сколько секунд обычного полёта между пасхалками
local FORMATION_INTERVAL = 10


-- Сколько секунд рой собирается в 67
local FORMATION_ENTER_TIME = 2.5


-- Сколько секунд рой летает по траектории 67
local FORMATION_DRAW_TIME = 6.7


-- Сколько секунд разлетается обратно
local FORMATION_EXIT_TIME = 2.5


-- Скорость пчёл вдоль линии цифр
-- studs / second

local FORMATION_SPEED = 7


-- Толщина движущегося потока

local FORMATION_THICKNESS = 0.9


-- Глубина потока
-- Чтобы пчёлы не были идеально плоскими

local FORMATION_DEPTH = 0.7


-- Смещение всей надписи относительно BeeCenter

local FORMATION_OFFSET =
	Vector3.new(
		0,      -- вправо / влево
		30,     -- вверх
		0       -- вперёд / назад
	)


-- =========================================================
-- SHAPE OF NUMBER 6
-- =========================================================

-- Это точки, между которыми пчёлы летают.
--
-- X = горизонталь
-- Y = вертикаль
-- Z = 0, потому что цифра лежит в одной плоскости.

local PATH_6_POINTS = {

	Vector3.new(-2, 8, 0),

	Vector3.new(-6, 8, 0),

	Vector3.new(-9, 7, 0),

	Vector3.new(-10, 4, 0),

	Vector3.new(-10, 0, 0),

	Vector3.new(-9, -4, 0),

	Vector3.new(-6, -6, 0),

	Vector3.new(-2, -6, 0),

	Vector3.new(0, -4, 0),

	Vector3.new(0, 0, 0),

	Vector3.new(-2, 3, 0),

	Vector3.new(-5, 4, 0),

	Vector3.new(-10, 4, 0),
}


-- =========================================================
-- SHAPE OF NUMBER 7
-- =========================================================

local PATH_7_POINTS = {

	Vector3.new(3, 8, 0),

	Vector3.new(12, 8, 0),

	Vector3.new(10, 5, 0),

	Vector3.new(8, 2, 0),

	Vector3.new(6, -1, 0),

	Vector3.new(4, -4, 0),

	Vector3.new(3, -6, 0),
}


-- =========================================================
-- STORAGE
-- =========================================================

local bees = {}


local formationActive = false

local formationStartTime = 0

local formationTimer = 0


-- =========================================================
-- HELPERS
-- =========================================================

local function randomRange(minValue, maxValue)

	return
		minValue
		+
		math.random()
		*
		(maxValue - minValue)

end


local function smoothstep(alpha)

	alpha =
		math.clamp(
			alpha,
			0,
			1
		)

	return
		alpha
		* alpha
		* (3 - 2 * alpha)

end


-- Даёт распределение около 0.
--
-- Большинство пчёл находится около
-- центральной линии потока,
-- а не равномерно по всей толщине.

local function centeredRandom()

	return
		math.random()
		+
		math.random()
	-
		1

end


-- =========================================================
-- FIND BEE PARTS
-- =========================================================

local function getBeeParts(object)

	local parts = {}


	if object:IsA("BasePart") then

		table.insert(
			parts,
			object
		)

	end


	for _, descendant in ipairs(object:GetDescendants()) do

		if descendant:IsA("BasePart") then

			table.insert(
				parts,
				descendant
			)

		end

	end


	return parts

end


-- =========================================================
-- BUILD PATH DATA
-- =========================================================

local function buildPath(points)

	local path = {

		points = points,

		segments = {},

		totalLength = 0,
	}


	for i = 1, #points - 1 do

		local pointA =
			points[i]

		local pointB =
			points[i + 1]


		local length =
			(pointB - pointA).Magnitude


		table.insert(
			path.segments,
			{
				a = pointA,

				b = pointB,

				length = length,

				startDistance =
					path.totalLength,
			}
		)


		path.totalLength +=
			length

	end


	return path

end


local path6 =
	buildPath(
		PATH_6_POINTS
	)


local path7 =
	buildPath(
		PATH_7_POINTS
	)


-- =========================================================
-- SAMPLE POINT ON PATH
-- =========================================================

local function samplePath(path, distance)

	distance =
		math.clamp(
			distance,
			0,
			path.totalLength
		)


	for _, segment in ipairs(path.segments) do

		local segmentEnd =
			segment.startDistance
			+
			segment.length


		if distance <= segmentEnd then

			local localDistance =
				distance
			-
				segment.startDistance


			local alpha =
				0


			if segment.length > 0 then

				alpha =
					localDistance
					/
					segment.length

			end


			local position =
				segment.a:Lerp(
					segment.b,
					alpha
				)


			local direction =
				segment.b
			-
				segment.a


			if direction.Magnitude > 0 then

				direction =
					direction.Unit

			else

				direction =
					Vector3.new(
						1,
						0,
						0
					)

			end


			return
				position,
				direction

		end

	end


	-- fallback

	local lastSegment =
		path.segments[
	#path.segments
	]


	return
		lastSegment.b,
		(lastSegment.b - lastSegment.a).Unit

end


-- =========================================================
-- NORMAL SWARM POSITION
-- =========================================================

local function calculateNormalPosition(
	beeData,
	timeValue
)

	local radius =
		beeData.radius


	-- -----------------------------------------------------
	-- движение вокруг улья
	-- -----------------------------------------------------

	local angle =
		timeValue
		* beeData.speed
		+
		beeData.phase


	-- -----------------------------------------------------
	-- доступный вертикальный диапазон
	-- -----------------------------------------------------

	local safeMinY =
		MIN_Y
		+
		NOISE_Y_AMOUNT


	local safeMaxY =
		MAX_Y
	-
		NOISE_Y_AMOUNT


	local minRatio =
		math.clamp(
			safeMinY / radius,
			-1,
			1
		)


	local maxRatio =
		math.clamp(
			safeMaxY / radius,
			-1,
			1
		)


	local minElevation =
		math.asin(
			minRatio
		)


	local maxElevation =
		math.asin(
			maxRatio
		)


	if minElevation > maxElevation then

		local temporary =
			minElevation

		minElevation =
			maxElevation

		maxElevation =
			temporary

	end


	-- Большинство пчёл остаётся ближе
	-- к центральной части роя

	minElevation *=
		beeData.verticalReach


	maxElevation *=
		beeData.verticalReach


	-- -----------------------------------------------------
	-- движение вверх / вниз
	-- -----------------------------------------------------

	local elevationCenter =
		(minElevation + maxElevation)
		/
		2


	local elevationAmplitude =
		(maxElevation - minElevation)
		/
		2


	local elevation =
		elevationCenter

		+

		math.sin(
			timeValue
			* beeData.elevationSpeed
			+
			beeData.elevationPhase
		)

		*
		elevationAmplitude


	-- -----------------------------------------------------
	-- spherical coordinates
	-- -----------------------------------------------------

	local horizontalRadius =
		math.cos(
			elevation
		)
		*
		radius


	local x =
		math.cos(
			angle
		)
		*
		horizontalRadius


	local z =
		math.sin(
			angle
		)
		*
		horizontalRadius


	local y =
		math.sin(
			elevation
		)
		*
		radius


	-- -----------------------------------------------------
	-- искажение идеальной траектории
	-- -----------------------------------------------------

	x +=
		math.sin(
			angle * 2.3
			+
			beeData.pathOffset
		)
		*
		PATH_DISTORTION


	z +=
		math.cos(
			angle * 1.7
			+
			beeData.pathOffset
		)
		*
		PATH_DISTORTION


	-- -----------------------------------------------------
	-- smooth noise
	-- -----------------------------------------------------

	local noiseX =
		math.noise(
			timeValue
			*
			NOISE_XZ_SPEED,

			beeData.noiseOffset
		)
		*
		NOISE_XZ_AMOUNT


	local noiseY =
		math.noise(
			timeValue
			*
			NOISE_Y_SPEED,

			beeData.noiseOffset
			+
			100
		)
		*
		NOISE_Y_AMOUNT


	local noiseZ =
		math.noise(
			timeValue
			*
			NOISE_XZ_SPEED,

			beeData.noiseOffset
			+
			200
		)
		*
		NOISE_XZ_AMOUNT


	x += noiseX
	y += noiseY
	z += noiseZ


	y =
		math.clamp(
			y,
			MIN_Y,
			MAX_Y
		)


	return
		hiveCenter.CFrame
		:PointToWorldSpace(
			Vector3.new(
				x,
				y,
				z
			)
		)

end


-- =========================================================
-- FORMATION POSITION
-- =========================================================

local function calculateFormationPosition(
	beeData,
	formationElapsed
)

	local path =
		beeData.formationPath


	local pathLength =
		path.totalLength


	-- -----------------------------------------------------
	-- движение вперёд-назад по траектории
	--
	-- Благодаря этому в конце линии пчела
	-- не телепортируется обратно в начало.
	-- -----------------------------------------------------

	local travelledDistance =
		beeData.formationStartDistance

		+

		formationElapsed
		*
		FORMATION_SPEED


	local fullCycle =
		pathLength
		*
		2


	local cycleDistance =
		travelledDistance
		%
		fullCycle


	local actualDistance

	local movementDirection


	if cycleDistance <= pathLength then

		actualDistance =
			cycleDistance

		movementDirection =
			1

	else

		actualDistance =
			fullCycle
		-
			cycleDistance

		movementDirection =
			-1

	end


	-- -----------------------------------------------------
	-- основная точка линии
	-- -----------------------------------------------------

	local point,
		pathDirection =
		samplePath(
			path,
			actualDistance
		)


	pathDirection *=
		movementDirection


	-- -----------------------------------------------------
	-- нормаль к линии
	--
	-- Нужна для толщины потока.
	-- -----------------------------------------------------

	local sideDirection =
		Vector3.new(
			-pathDirection.Y,
			pathDirection.X,
			0
		)


	if sideDirection.Magnitude > 0.001 then

		sideDirection =
			sideDirection.Unit

	else

		sideDirection =
			Vector3.new(
				1,
				0,
				0
			)

	end


	-- -----------------------------------------------------
	-- небольшое живое движение внутри потока
	-- -----------------------------------------------------

	local wobble =
		math.sin(
			formationElapsed * 4
			+
			beeData.phase
		)
		*
		0.15


	local localPosition =
		point

		+

		FORMATION_OFFSET

		+

		sideDirection
		*
		(
			beeData.formationSideOffset
			+
			wobble
		)

		+

		Vector3.new(
			0,
			0,
			beeData.formationDepthOffset
		)


	local worldPosition =
		hiveCenter.CFrame
		:PointToWorldSpace(
			localPosition
		)


	-- Направление движения тоже переводим
	-- из пространства BeeCenter в мир

	local worldDirection =
		hiveCenter.CFrame
		:VectorToWorldSpace(
			pathDirection
		)


	return
		worldPosition,
		worldDirection

end


-- =========================================================
-- CREATE BEES
-- =========================================================

-- Сколько относительной длины занимает 6,
-- столько примерно пчёл ей и отдаём.

local combinedPathLength =
	path6.totalLength
	+
	path7.totalLength


local path6Probability =
	path6.totalLength
	/
	combinedPathLength


for i = 1, BEE_COUNT do

	local bee =
		beeTemplate:Clone()


	bee.Name =
		"AmbientBee_"
		..
		i


	bee.Parent =
		workspace


	-- -----------------------------------------------------
	-- physical parts
	-- -----------------------------------------------------

	local parts =
		getBeeParts(
			bee
		)


	if #parts == 0 then

		warn(
			"Bee "
				..
				bee.Name
				..
				" contains no BasePart / MeshPart"
		)


		bee:Destroy()

		continue

	end


	local rootPart =
		parts[1]


	for _, part in ipairs(parts) do

		part.Anchored =
			true

		part.CanCollide =
			false

		part.CanTouch =
			false

		part.CanQuery =
			false

		part.Massless =
			true

	end


	-- -----------------------------------------------------
	-- remember relative part positions
	-- -----------------------------------------------------

	local partOffsets = {}


	for _, part in ipairs(parts) do

		partOffsets[part] =
			rootPart.CFrame
			:ToObjectSpace(
				part.CFrame
			)

	end


	-- -----------------------------------------------------
	-- radius distribution
	-- -----------------------------------------------------

	local radiusFactor =
		math.random()
		^
		ORBIT_DENSITY_POWER


	local radius =
		MIN_RADIUS

		+

		(MAX_RADIUS - MIN_RADIUS)
		*
		radiusFactor


	-- -----------------------------------------------------
	-- vertical distribution
	-- -----------------------------------------------------

	local verticalReach =
		math.random()
		^
		VERTICAL_DENSITY_POWER


	-- -----------------------------------------------------
	-- choose 6 or 7
	-- -----------------------------------------------------

	local formationPath


	if math.random() < path6Probability then

		formationPath =
			path6

	else

		formationPath =
			path7

	end


	-- -----------------------------------------------------
	-- create data
	-- -----------------------------------------------------

	local beeData = {

		rootPart =
			rootPart,

		parts =
			parts,

		partOffsets =
			partOffsets,


		-- normal swarm

		radius =
			radius,

		verticalReach =
			verticalReach,

		speed =
			randomRange(
				MIN_SPEED,
				MAX_SPEED
			),

		elevationSpeed =
			randomRange(
				MIN_ELEVATION_SPEED,
				MAX_ELEVATION_SPEED
			),

		phase =
			math.random()
			*
			math.pi
			*
			2,

		elevationPhase =
			math.random()
			*
			math.pi
			*
			2,

		pathOffset =
			math.random()
			*
			math.pi
			*
			2,

		noiseOffset =
			math.random()
			*
			1000,


		-- 67 formation

		formationPath =
			formationPath,

		formationStartDistance =
			math.random()
			*
			formationPath.totalLength,

		formationSideOffset =
			centeredRandom()
			*
			FORMATION_THICKNESS,

		formationDepthOffset =
			centeredRandom()
			*
			FORMATION_DEPTH,
	}


	table.insert(
		bees,
		beeData
	)

end


-- =========================================================
-- START FORMATION
-- =========================================================

local function startFormation(currentTime)

	formationActive =
		true


	formationStartTime =
		currentTime


	print(
		"Starting 67 swarm easter egg"
	)

end


-- =========================================================
-- MAIN LOOP
-- =========================================================

local elapsedTime = 0


RunService.RenderStepped:Connect(function(dt)

	elapsedTime += dt


	-- =====================================================
	-- FORMATION TIMER
	-- =====================================================

	if not formationActive then

		formationTimer += dt


		if formationTimer >= FORMATION_INTERVAL then

			formationTimer = 0

			startFormation(
				elapsedTime
			)

		end

	end


	-- =====================================================
	-- FORMATION ALPHA
	-- =====================================================

	local formationAlpha = 0

	local formationElapsed = 0


	if formationActive then

		formationElapsed =
			elapsedTime
		-
			formationStartTime


		local enterEnd =
			FORMATION_ENTER_TIME


		local drawEnd =
			enterEnd
			+
			FORMATION_DRAW_TIME


		local exitEnd =
			drawEnd
			+
			FORMATION_EXIT_TIME


		-- -------------------------------------------------
		-- gather into 67
		-- -------------------------------------------------

		if formationElapsed < enterEnd then

			formationAlpha =
				smoothstep(
					formationElapsed
					/
					FORMATION_ENTER_TIME
				)


			-- -------------------------------------------------
			-- fully in 67
			-- -------------------------------------------------

		elseif formationElapsed < drawEnd then

			formationAlpha =
				1


			-- -------------------------------------------------
			-- fly back into normal swarm
			-- -------------------------------------------------

		elseif formationElapsed < exitEnd then

			local alpha =
				(
					formationElapsed
					-
					drawEnd
				)
				/
				FORMATION_EXIT_TIME


			formationAlpha =
				1
			-
				smoothstep(alpha)


			-- -------------------------------------------------
			-- finished
			-- -------------------------------------------------

		else

			formationActive =
				false


			formationAlpha =
				0


			formationTimer =
				0


			print(
				"67 swarm easter egg finished"
			)

		end

	end


	-- =====================================================
	-- MOVE ALL BEES
	-- =====================================================

	for _, beeData in ipairs(bees) do

		local rootPart =
			beeData.rootPart


		if
			not rootPart
			or
			not rootPart.Parent
		then

			continue

		end


		-- -------------------------------------------------
		-- normal position
		-- -------------------------------------------------

		local normalPosition =
			calculateNormalPosition(
				beeData,
				elapsedTime
			)


		local normalNextPosition =
			calculateNormalPosition(
				beeData,
				elapsedTime + 0.04
			)


		local normalDirection =
			normalNextPosition
		-
			normalPosition


		if normalDirection.Magnitude > 0.001 then

			normalDirection =
				normalDirection.Unit

		else

			normalDirection =
				Vector3.new(
					0,
					0,
					-1
				)

		end


		-- -------------------------------------------------
		-- default = normal swarm
		-- -------------------------------------------------

		local finalPosition =
			normalPosition


		local finalDirection =
			normalDirection


		-- -------------------------------------------------
		-- blend into 67 path
		-- -------------------------------------------------

		if
			formationActive
			and
			formationAlpha > 0
		then

			local formationPosition,
			formationDirection =
				calculateFormationPosition(
					beeData,
					formationElapsed
				)


			finalPosition =
				normalPosition
				:Lerp(
					formationPosition,
					formationAlpha
				)


			finalDirection =
				normalDirection
				:Lerp(
					formationDirection,
					formationAlpha
				)


			if finalDirection.Magnitude > 0.001 then

				finalDirection =
					finalDirection.Unit

			else

				finalDirection =
					normalDirection

			end

		end


		-- =================================================
		-- ROTATION
		-- =================================================

		local rootCFrame =
			CFrame.lookAt(
				finalPosition,
				finalPosition
				+
				finalDirection
			)


		-- =================================================
		-- MOVE ALL PARTS OF BEE
		-- =================================================

		for _, part in ipairs(beeData.parts) do

			if
				part
				and
				part.Parent
			then

				local offset =
					beeData.partOffsets[
				part
				]


				part.CFrame =
					rootCFrame
					*
					offset

			end

		end

	end

end)