-- RegressionProgress: вехи модуля «Регрессия» от клиента → LearningService (как у других уроков SkRob).
-- Клиент присылает только id из списка ниже; прогресс прохождения внутри модуля живёт на клиенте (Store.serialize).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- В песочнице RegressionBeeHive сервисов SkRob нет — тогда вехи просто не сохраняются
local services = script.Parent:FindFirstChild("Services")
if not services or not services:FindFirstChild("LearningService") then
	return
end
local LearningService = require(services.LearningService)

local MILESTONES = {
	regression_3d = true, -- клумба: найден оптимальный наклон (3D.6)
	regression_2d = true, -- экраны 2D.1–2D.7 пройдены (R² открыт)
	regression_lore = true, -- лор-задача: прогноз мёда проверен через R²
}

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RegressionProgress")

remote.OnServerEvent:Connect(function(player, milestone)
	if type(milestone) ~= "string" or not MILESTONES[milestone] then
		return
	end
	if LearningService.IsCompleted(player, milestone) then
		return
	end
	LearningService.Complete(player, milestone)
end)
