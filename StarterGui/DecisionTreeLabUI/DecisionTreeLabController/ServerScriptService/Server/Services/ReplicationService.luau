local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local TycoonService = require(
	script.Parent.TycoonService
)


local TycoonStateUpdate =
	ReplicatedStorage.Remotes.TycoonStateUpdate


local ReplicationService = {}

local started = false

-- Пока будем обновлять HUD 5 раз в секунду.
local UPDATE_INTERVAL = 0.2
local elapsed = 0


local function createSnapshot(state)

	-- Важно: клиенту отдаём только нужные данные,
	-- а не сам серверный state.

	local capabilities = {}

	for capabilityId, value in pairs(
		state.Capabilities
		) do

		capabilities[capabilityId] = value

	end
	


	return {

		Resources = {
			Honey = state.Resources.Honey,
		},

		Production = {
			HoneyRate =
				state.Production.HoneyRate,
		},

		Stats = {

			Efficiency =
				state.Stats.Efficiency,

			Workforce =
				state.Stats.Workforce,

			Supply =
				state.Stats.Supply,

			Processing =
				state.Stats.Processing,

			Consumption =
				state.Stats.Consumption,

			HealthRisk =
				state.Stats.HealthRisk,

		},

		Capabilities = capabilities,
		
		Population = {

			Total =
				state.Population.Summary.Total,

			Alive =
				state.Population.Summary.Alive,

			ByJob =
				state.Population.Summary.ByJob,

		},

	}

end


function ReplicationService.Send(player)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	local snapshot =
		createSnapshot(state)


	TycoonStateUpdate:FireClient(
		player,
		snapshot
	)

end


function ReplicationService.Start()

	if started then
		return
	end

	started = true


	RunService.Heartbeat:Connect(
		function(deltaTime)

			elapsed += deltaTime

			if elapsed < UPDATE_INTERVAL then
				return
			end

			elapsed = 0


			for _, player in Players:GetPlayers() do

				ReplicationService.Send(player)

			end

		end
	)

end


return ReplicationService