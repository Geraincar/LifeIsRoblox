local TycoonService = require(
	script.Parent.TycoonService
)


local CapabilityService = {}


function CapabilityService.Has(player, capabilityId)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return false
	end

	return state.Capabilities[capabilityId] == true

end


function CapabilityService.HasAll(
	player,
	requiredCapabilities
)

	for _, capabilityId in ipairs(
		requiredCapabilities
		) do

		if not CapabilityService.Has(
			player,
			capabilityId
			) then

			return false

		end

	end

	return true

end


function CapabilityService.Grant(
	player,
	capabilityId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return false
	end


	if state.Capabilities[capabilityId] then
		return false
	end


	state.Capabilities[capabilityId] = true


	print(
		"Capability granted:",
		player.Name,
		capabilityId
	)


	return true

end


function CapabilityService.Revoke(
	player,
	capabilityId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end

	state.Capabilities[capabilityId] = nil

end


return CapabilityService