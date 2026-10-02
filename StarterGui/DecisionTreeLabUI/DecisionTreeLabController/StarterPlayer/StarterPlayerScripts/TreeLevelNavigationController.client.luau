local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_SUBLEVEL = 4
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local navigateRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("TreeLevelNavigate")

local gui = Instance.new("ScreenGui")
gui.Name = "TreeLevelNavigationUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 200
gui.Parent = playerGui

local function makeButton(name, text, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.fromOffset(285, 46)
	button.BackgroundColor3 = Color3.fromRGB(32, 39, 54)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.Visible = false
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(89, 120, 181)
	stroke.Parent = button
	return button
end

local previousButton = makeButton(
	"PreviousSublevelButton",
	"← ПРЕДЫДУЩИЙ ПОДУРОВЕНЬ",
	UDim2.fromOffset(18, 18)
)

local nextButton = makeButton(
	"NextSublevelButton",
	"СЛЕДУЮЩИЙ ПОДУРОВЕНЬ →",
	UDim2.fromOffset(18, 74)
)

local busy = false

local function setAvailable(button, available)
	button.Active = available
	button.AutoButtonColor = available
	button.BackgroundTransparency = available and 0 or 0.35
	button.TextTransparency = available and 0 or 0.4
end

local function getState()
	return player:GetAttribute("TreeLevelInside") == true,
		tonumber(player:GetAttribute("TreeLevelActiveSublevel")) or 0,
		tonumber(player:GetAttribute("TreeLevelProgress")) or 0
end

local function refresh()
	local inside, active, progress = getState()
	previousButton.Visible = inside

	if not inside then
		nextButton.Visible = false
		return
	end

	local canGoPrevious = active > 1
	setAvailable(previousButton, canGoPrevious)
	previousButton.Text = canGoPrevious
		and "← ПРЕДЫДУЩИЙ ПОДУРОВЕНЬ"
		or "← ПРЕДЫДУЩЕГО НЕТ"

	-- Следующий уровень доступен только тогда, когда
	-- текущий уже входит в сохранённый прогресс игрока.
	local canGoNext = active >= 1
		and active <= progress
		and active < MAX_SUBLEVEL

	nextButton.Visible = canGoNext
	setAvailable(nextButton, canGoNext)
	nextButton.Text = "СЛЕДУЮЩИЙ ПОДУРОВЕНЬ →"
end

local function navigate(action, waitingText)
	if busy then
		return
	end
	busy = true
	local button = action == "Previous" and previousButton or nextButton
	local oldText = button.Text
	button.Text = waitingText

	local success, result = pcall(function()
		return navigateRemote:InvokeServer(action)
	end)

	busy = false
	button.Text = oldText
	if not success or not result or result.Ok ~= true then
		warn("[TreeLevelNavigation] " .. action .. " failed", result and result.Error)
	end
	refresh()
end

previousButton.Activated:Connect(function()
	local inside, active = getState()
	if inside and active > 1 then
		navigate("Previous", "ВОЗВРАЩАЕМСЯ...")
	end
end)

nextButton.Activated:Connect(function()
	local inside, active, progress = getState()
	if inside and active >= 1 and active <= progress and active < MAX_SUBLEVEL then
		navigate("Next", "ПЕРЕХОДИМ...")
	end
end)

player:GetAttributeChangedSignal("TreeLevelInside"):Connect(refresh)
player:GetAttributeChangedSignal("TreeLevelActiveSublevel"):Connect(refresh)
player:GetAttributeChangedSignal("TreeLevelProgress"):Connect(refresh)

refresh()
