--!nonstrict
-- PlayerControls: выключить движение персонажа на время экрана 2D или панели (счётчик запросов).
-- Камеру не трогает. Работает через PlayerModule:GetControls(); если модуля нет — тихо ничего не делает.

local Players = game:GetService("Players")

local PlayerControls = {}

local holds = {}
local controls = nil

local function get()
	if controls then
		return controls
	end
	local ok, c = pcall(function()
		local pm: any = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return (require :: any)(pm):GetControls()
	end)
	if ok then
		controls = c
	end
	return controls
end

local function apply()
	local c = get()
	if not c then
		return
	end
	if next(holds) then
		c:Disable()
	else
		c:Enable()
	end
end

function PlayerControls.hold(key: string)
	holds[key] = true
	task.spawn(apply)
end

function PlayerControls.release(key: string)
	holds[key] = nil
	task.spawn(apply)
end

return PlayerControls
