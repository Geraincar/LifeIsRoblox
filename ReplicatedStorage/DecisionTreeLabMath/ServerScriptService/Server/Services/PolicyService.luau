local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local TycoonService = require(
	script.Parent.TycoonService
)

local GroupService = require(
	script.Parent.GroupService
)

local BeePopulationService = require(
	script.Parent.BeePopulationService
)


local PolicyDefinitions = require(
	ReplicatedStorage.Shared.PolicyDefinitions
)


local PolicyService = {}



function PolicyService.ApplyToGroup(
	player,
	groupId,
	policyId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return false
	end


	local group =
		GroupService.Get(
			player,
			groupId
		)


	if not group then

		warn(
			"Unknown group:",
			groupId
		)

		return false

	end


	local policy =
		PolicyDefinitions.Get(
			policyId
		)


	if not policy then

		warn(
			"Unknown policy:",
			policyId
		)

		return false

	end


	if policy.TargetScope
		~= group.Scope then

		warn(
			"Policy",
			policyId,
			"cannot be applied to scope",
			group.Scope
		)

		return false

	end


	-- Пока реализуем policies
	-- только для bee groups.

	if group.Scope == "Bees" then

		local assignments = {}


		for beeId in pairs(
			group.Members
			) do

			assignments[beeId] =
				policy.Job

		end


		local changed =
			BeePopulationService.SetJobsBatch(
				player,
				assignments
			)


		state.GroupPolicies[groupId] =
			policyId


		print(
			"Policy applied:",
			policyId,
			"to",
			groupId,
			"| Bees changed:",
			changed
		)


		return true

	end


	warn(
		"No policy handler for scope:",
		group.Scope
	)


	return false

end



function PolicyService.GetPolicyForGroup(
	player,
	groupId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	return state.GroupPolicies[groupId]

end



return PolicyService