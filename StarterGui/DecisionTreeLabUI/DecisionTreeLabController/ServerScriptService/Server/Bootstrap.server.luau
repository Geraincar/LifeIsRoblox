local Players = game:GetService("Players")

local ReplicationService = require(
	script.Parent.Services.ReplicationService
)

local TycoonService = require(
	script.Parent.Services.TycoonService
)

local ProductionService = require(
	script.Parent.Services.ProductionService
)

local BeePopulationService = require(
	script.Parent.Services.BeePopulationService
)

local GroupService = require(
	script.Parent.Services.GroupService
)

local PolicyService = require(
	script.Parent.Services.PolicyService
)

local DataConsoleService =
	require(
		script.Parent.Services.DataConsoleService
	)

local WorldLessonService =
	require(
		script.Parent.Services.WorldLessonService
	)


local function onPlayerAdded(player)

	local state =
		TycoonService.CreatePlayerState(player)

	-- framework_test auto-start removed by LevelFlow installer
	BeePopulationService.Initialize(
		player,
		50
	)
	
		-- test_cluster_1 debug block removed by LevelFlow installer

	-- После того как популяция и производство уже рассчитаны,
	-- отправляем первое актуальное состояние клиенту.
	ReplicationService.Send(player)


		-- verbose bee debug print removed by LevelFlow installer

	print(
		"Created tycoon for:",
		player.Name
	)

	print(
		"Starting honey:",
		state.Resources.Honey
	)

end


local function onPlayerRemoving(player)

	TycoonService.RemovePlayerState(player)

	print(
		"Removed tycoon for:",
		player.Name
	)

end


Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(onPlayerRemoving)


for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end


ProductionService.Start()
ReplicationService.Start()
DataConsoleService.Start()
WorldLessonService.Start()


