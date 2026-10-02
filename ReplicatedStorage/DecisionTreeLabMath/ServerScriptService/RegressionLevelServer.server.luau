-- RegressionLevelServer: копирует CFrame и Size площадок уровня «Регрессия» в атрибуты папки
-- Workspace/RegressionLevel. В SkRob включён StreamingEnabled: сами детали приходят клиенту не сразу,
-- а атрибуты папки — сразу, поэтому клумба и пасека строятся на своих местах в первый же кадр.
-- Двигать площадки и куб можно прямо в Studio — атрибуты обновятся при запуске.
local level = workspace:WaitForChild("RegressionLevel")

local function publish(part: Instance)
	if part:IsA("BasePart") then
		level:SetAttribute(part.Name .. "_CFrame", part.CFrame)
		level:SetAttribute(part.Name .. "_Size", part.Size)
	end
end

for _, child in level:GetChildren() do
	publish(child)
	if child:IsA("BasePart") then
		child:GetPropertyChangedSignal("CFrame"):Connect(function() publish(child) end)
		child:GetPropertyChangedSignal("Size"):Connect(function() publish(child) end)
	end
end
level.ChildAdded:Connect(publish)
