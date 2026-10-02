local Players = game:GetService("Players")

local player = Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local mainUI =
	playerGui:WaitForChild("MainUI")

local hud =
	mainUI:WaitForChild("HUD")

local dataPanel =
	mainUI:WaitForChild("DataPanel")

local openButton =
	hud:WaitForChild("OpenDataButton")

local header =
	dataPanel:WaitForChild("Header")

local closeButton =
	header:WaitForChild("CloseButton")


dataPanel.Visible = false


local function openPanel()

	dataPanel.Visible = true

end


local function closePanel()

	dataPanel.Visible = false

end


openButton.MouseButton1Click:Connect(openPanel)

closeButton.MouseButton1Click:Connect(closePanel)