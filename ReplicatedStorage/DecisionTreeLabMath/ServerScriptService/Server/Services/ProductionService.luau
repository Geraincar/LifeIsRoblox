local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local TycoonService = require(
	script.Parent.TycoonService
)

local ProductionModel = require(
	ReplicatedStorage.Shared.ProductionModel
)


local ProductionService = {}

local started = false
local debugTimer = 0


function ProductionService.Recalculate(player)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	local snapshot =
		ProductionModel.Compute(state)


	state.Production.HoneyRate =
		snapshot.HoneyRate


	print(
		"Production recalculated:",
		player.Name,
		"HoneyRate:",
		state.Production.HoneyRate
	)

end


function ProductionService.Start()

	if started then
		return
	end

	started = true


	RunService.Heartbeat:Connect(function(deltaTime)

		debugTimer += deltaTime


		for _, player in Players:GetPlayers() do

			local state =
				TycoonService.GetPlayerState(player)

			if state then

				local rate =
					state.Production.HoneyRate

				state.Resources.Honey +=
					rate * deltaTime

			end

		end


		-- Временно, чтобы видеть работу системы.
		if debugTimer >= 1 then

			debugTimer = 0

			for _, player in Players:GetPlayers() do

				local state =
					TycoonService.GetPlayerState(player)

				if state then

					print(
						"Honey:",
						math.floor(state.Resources.Honey * 10) / 10,
						"| Rate:",
						state.Production.HoneyRate
					)

				end

			end

		end

	end)

end


return ProductionService