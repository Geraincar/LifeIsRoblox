local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local player = Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


local mainUI =
	playerGui:WaitForChild("MainUI")

local hud =
	mainUI:WaitForChild("HUD")


local honeyLabel =
	hud:WaitForChild("HoneyLabel")

local rateLabel =
	hud:WaitForChild("RateLabel")

local efficiencyLabel =
	hud:WaitForChild("EfficiencyLabel")


local tycoonStateUpdate =
	ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("TycoonStateUpdate")


local function formatNumber(value)

	return string.format("%.1f", value)

end


local function updateUI(snapshot)

	honeyLabel.Text =
		"Honey: "
		.. formatNumber(
			snapshot.Resources.Honey
		)


	rateLabel.Text =
		"Production: "
		.. formatNumber(
			snapshot.Production.HoneyRate
		)
		.. " / sec"


	efficiencyLabel.Text =
		"Efficiency: "
		.. string.format(
			"%.2f",
			snapshot.Stats.Efficiency
		)

end


tycoonStateUpdate.OnClientEvent:Connect(
	updateUI
)