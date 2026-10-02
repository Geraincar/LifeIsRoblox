local ProximityPromptService =
	game:GetService("ProximityPromptService")


local ActionService = require(
	script.Parent.Services.ActionService
)


local function onPromptTriggered(prompt, player)

	local entityInstance = prompt.Parent

	if not entityInstance then
		return
	end


	local entityId =
		entityInstance:GetAttribute("EntityId")

	local actionId =
		entityInstance:GetAttribute("ActionId")


	if not entityId then
		warn("Entity has no EntityId:", entityInstance.Name)
		return
	end


	if not actionId then
		warn("Entity has no ActionId:", entityInstance.Name)
		return
	end


	ActionService.Execute(
		player,
		actionId,
		entityId
	)

end


ProximityPromptService.PromptTriggered:Connect(
	onPromptTriggered
)