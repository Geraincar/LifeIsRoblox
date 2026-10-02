local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local player = Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


local mainUI =
	playerGui:WaitForChild("MainUI")

local dataPanel =
	mainUI:WaitForChild("DataPanel")

local chartContainer =
	dataPanel:WaitForChild("ChartContainer")


local LuauChart =
	require(
		ReplicatedStorage:WaitForChild("LuauChart")
	)


local tycoonStateUpdate =
	ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("TycoonStateUpdate")



local chart =
	LuauChart.Line.new({

		Renderer = "Viewport"

	})


chart.UI.Parent =
	chartContainer


chart.UI.Size =
	UDim2.fromScale(1, 1)


chart.UI.Position =
	UDim2.fromScale(0, 0)

chart.AutoFitY = false


chart.Grid:SetVisible(true)

chart.Cursor:SetEnabled(true)


chart.MaxPoints = 60


chart:SetSeries({
	{
		Name = "Honey rate",

		Color = Color3.fromRGB(30, 90, 220),
		Thickness = 4,

		Markers = {
			Size = 8,
			Color = Color3.fromRGB(30, 90, 220),
		},

		Points = {
			{
				Index = 0,
				Value = 1,
			},
		},
	},
})



local startTime =
	os.clock()

local lastPointTime = 0

local SAMPLE_INTERVAL = 1
local maxObservedRate = 1
local latestElapsed = 0

local function updateChartBounds(elapsed, rate)

	if rate > maxObservedRate then
		maxObservedRate = rate
	end

	-- 20% свободного пространства сверху
	local dynamicYMax =
		math.max(1, maxObservedRate * 1.2)

	-- X тоже постепенно расширяется
	local dynamicXMax =
		math.max(10, elapsed)

	chart:SetBounds({
		X = NumberRange.new(0, dynamicXMax),
		Y = NumberRange.new(0, dynamicYMax),
	})

end


local function onTycoonUpdate(snapshot)

	local now = os.clock()

	if now - lastPointTime < SAMPLE_INTERVAL then
		return
	end

	lastPointTime = now


	local elapsed =
		now - startTime

	local honeyRate =
		snapshot.Production.HoneyRate


	chart:AddPoint({
		Index = elapsed,
		Value = honeyRate,
	})


	updateChartBounds(
		elapsed,
		honeyRate
	)

end



tycoonStateUpdate.OnClientEvent:Connect(
	onTycoonUpdate
)