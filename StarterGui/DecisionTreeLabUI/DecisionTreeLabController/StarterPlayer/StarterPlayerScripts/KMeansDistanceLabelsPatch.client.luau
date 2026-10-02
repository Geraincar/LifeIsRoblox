
local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


-- ============================================================
-- CONFIG
-- ============================================================

local SCALE = 1.55

pcall(function()

	local KMeans =
		ReplicatedStorage:WaitForChild("KMeans")

	local Config =
		require(
			KMeans.Core.Config
		)

	if type(Config) == "table" then
		SCALE = Config.SCALE or SCALE
	end

end)


local RED_COLOR =
	Color3.fromRGB(
		239,
		92,
		73
	)

local BLUE_COLOR =
	Color3.fromRGB(
		72,
		151,
		220
	)


-- ============================================================
-- HELPERS
-- ============================================================

local function ensureBillboard(
	part,
	name,
	color,
	offsetY
)

	local gui =
		part:FindFirstChild(name)

	if not gui then

		gui =
			Instance.new("BillboardGui")

		gui.Name =
			name

		gui.Size =
			UDim2.fromOffset(
				170,
				42
			)

		gui.StudsOffsetWorldSpace =
			Vector3.new(
				0,
				offsetY or 2.3,
				0
			)

		gui.AlwaysOnTop =
			true

		gui.MaxDistance =
			70

		gui.LightInfluence =
			0

		gui.Parent =
			part


		local label =
			Instance.new("TextLabel")

		label.Name =
			"Text"

		label.Size =
			UDim2.fromScale(
				1,
				1
			)

		label.BackgroundTransparency =
			0.25

		label.BackgroundColor3 =
			Color3.fromRGB(
				18,
				20,
				24
			)

		label.TextColor3 =
			color

		label.TextScaled =
			true

		label.Font =
			Enum.Font.GothamBold

		label.Text =
			""

		label.Parent =
			gui


		local corner =
			Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label


		local stroke =
			Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 1.5
		stroke.Transparency = 0.15
		stroke.Parent = label

	end


	return gui

end


local function setBillboardText(
	part,
	guiName,
	text,
	visible
)

	local gui =
		part:FindFirstChild(
			guiName
		)

	if not gui then
		return
	end


	gui.Enabled =
		visible


	local label =
		gui:FindFirstChild("Text")

	if label then
		label.Text = text or ""
	end

end


local function getCentroids()

	local world =
		Workspace:FindFirstChild(
			"KMeansWorld"
		)

	if not world then
		return nil, nil, nil
	end


	local centroidA =
		world:FindFirstChild(
			"CentroidA"
		)

	local centroidB =
		world:FindFirstChild(
			"CentroidB"
		)

	local temporary =
		world:FindFirstChild(
			"Temporary"
		)

	return centroidA, centroidB, temporary

end


local function getAssignmentModal()

	local hud =
		playerGui:FindFirstChild(
			"KMeansHUD"
		)

	if not hud then
		return nil
	end


	return hud:FindFirstChild(
		"AssignmentModal",
		true
	)

end


local function distanceSquaredFromLine(
	line
)

	-- line.Size.Z = world distance
	local worldDistance =
		line.Size.Z

	local dataDistance =
		worldDistance / SCALE

	return
		dataDistance * dataDistance

end


local function endpointInfo(line)

	local length =
		line.Size.Z

	local half =
		length / 2

	local center =
		line.Position

	local dir =
		line.CFrame.LookVector

	local p1 =
		center + dir * half

	local p2 =
		center - dir * half

	return p1, p2

end


local function closerCentroidForLine(
	line,
	centroidA,
	centroidB
)

	if not centroidA or not centroidB then
		return nil
	end


	local p1, p2 =
		endpointInfo(line)


	local aDist =
		math.min(
			(p1 - centroidA.Position).Magnitude,
			(p2 - centroidA.Position).Magnitude
		)

	local bDist =
		math.min(
			(p1 - centroidB.Position).Magnitude,
			(p2 - centroidB.Position).Magnitude
		)


	if aDist <= bDist then
		return "A"
	else
		return "B"
	end

end


-- ============================================================
-- MAIN
-- ============================================================

local accumulator = 0

RunService.RenderStepped:Connect(function(dt)

	accumulator += dt

	if accumulator < 0.08 then
		return
	end

	accumulator = 0


	local centroidA,
		centroidB,
		temporary =
			getCentroids()


	if not centroidA or not centroidB then
		return
	end


	ensureBillboard(
		centroidA,
		"DistanceInfoA",
		RED_COLOR,
		3.0
	)

	ensureBillboard(
		centroidB,
		"DistanceInfoB",
		BLUE_COLOR,
		3.0
	)


	local modal =
		getAssignmentModal()


	local modalVisible =
		modal
		and modal.Visible


	if not modalVisible or not temporary then

		setBillboardText(
			centroidA,
			"DistanceInfoA",
			"",
			false
		)

		setBillboardText(
			centroidB,
			"DistanceInfoB",
			"",
			false
		)

		return

	end


	local foundA = nil
	local foundB = nil


	for _, child in ipairs(
		temporary:GetChildren()
	) do

		if
			child:IsA("BasePart")
			and child.Name == "DistanceLine"
		then

			local cluster =
				closerCentroidForLine(
					child,
					centroidA,
					centroidB
				)

			local d2 =
				distanceSquaredFromLine(
					child
				)

			if cluster == "A" then

				foundA =
					("d²(A)=%.2f"):format(
						d2
					)

			elseif cluster == "B" then

				foundB =
					("d²(B)=%.2f"):format(
						d2
					)

			end

		end

	end


	setBillboardText(
		centroidA,
		"DistanceInfoA",
		foundA or "",
		foundA ~= nil
	)

	setBillboardText(
		centroidB,
		"DistanceInfoB",
		foundB or "",
		foundB ~= nil
	)

end)

print("[KMeansDistanceLabelsPatch] loaded")

