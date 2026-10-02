local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local HOVER_SCALE = 1.05
local CLICK_SCALE = 0.95
local TWEEN_TIME = 0.15
local TWEEN_INFO = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Button paths relative to PlayerGui
local BUTTON_PATHS = {
	"MainUI.HUD.OpenDataButton",
	"MainUI.DataPanel.BottomBar.BackButton",
	"MainUI.DataPanel.BottomBar.PrimaryButton",
	"MainUI.DataPanel.TopBar.CloseButton",
}

local function setupButton(button)
	if not button or not button:IsA("GuiButton") then return end
	if button:GetAttribute("HoverAnimSetup") then return end
	button:SetAttribute("HoverAnimSetup", true)

	local originalSize = button.Size
	local isHovering = false

	local function scaleSize(scaleFactor)
		local newUDim2 = UDim2.new(
			originalSize.X.Scale * scaleFactor,
			originalSize.X.Offset * scaleFactor,
			originalSize.Y.Scale * scaleFactor,
			originalSize.Y.Offset * scaleFactor
		)
		TweenService:Create(button, TWEEN_INFO, {Size = newUDim2}):Play()
	end

	button.MouseEnter:Connect(function()
		isHovering = true
		scaleSize(HOVER_SCALE)
	end)

	button.MouseLeave:Connect(function()
		isHovering = false
		scaleSize(1)
	end)

	button.Activated:Connect(function()
		scaleSize(CLICK_SCALE)
		task.wait(0.08)
		if isHovering then
			scaleSize(HOVER_SCALE)
		else
			scaleSize(1)
		end
	end)
end

-- Wait for PlayerGui and buttons to exist
local playerGui = player:WaitForChild("PlayerGui")

for _, path in ipairs(BUTTON_PATHS) do
	local button = playerGui:FindFirstChild(path, true)
	if button then
		setupButton(button)
	else
		-- Try again when descendants are added
		local connection
		connection = playerGui.DescendantAdded:Connect(function(descendant)
			local fullPath = descendant:GetFullName()
			-- Check if this descendant matches our target path
			local expectedPath = "StarterGui." .. path
			local descPath = descendant:GetFullName()
			if string.find(descPath, path, 1, true) then
				setupButton(descendant)
			end
	end)
	end
end
