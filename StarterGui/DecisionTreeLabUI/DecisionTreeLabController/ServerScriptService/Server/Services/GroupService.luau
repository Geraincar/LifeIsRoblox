local TycoonService = require(
	script.Parent.TycoonService
)


local GroupService = {}



function GroupService.Create(
	player,
	groupId,
	scope,
	memberIds,
	metadata
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	local members = {}


	for _, memberId in ipairs(memberIds) do

		members[memberId] = true

	end


	local group = {

		Id = groupId,

		Scope = scope,

		Members = members,

		Metadata = metadata or {},

	}


	state.Groups[groupId] = group


	print(
		"Group created:",
		groupId,
		"Members:",
		#memberIds
	)


	return group

end



function GroupService.Get(
	player,
	groupId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	return state.Groups[groupId]

end



function GroupService.GetAll(player)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return nil
	end


	return state.Groups

end



function GroupService.Remove(
	player,
	groupId
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	state.Groups[groupId] = nil
	state.GroupPolicies[groupId] = nil

end



function GroupService.ClearScope(
	player,
	scope
)

	local state =
		TycoonService.GetPlayerState(player)

	if not state then
		return
	end


	for groupId, group in pairs(
		state.Groups
		) do

		if group.Scope == scope then

			state.Groups[groupId] = nil
			state.GroupPolicies[groupId] = nil

		end

	end

end



return GroupService