local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local Players =
	game:GetService("Players")


local resetRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"DecisionTreeFullReset"
		)


resetRemote.OnServerEvent:Connect(
	function(player)

		if not player
			or player.Parent ~= Players
		then
			return
		end


		--------------------------------
		-- RESET GLOBAL LEVEL FLOW STATE
		--------------------------------

		player:SetAttribute(
			"LevelFlowCompleted_decision_tree",
			nil
		)


		player:SetAttribute(
			"LevelFlowPendingNext",
			nil
		)


		player:SetAttribute(
			"LevelFlowTargetLevel",
			nil
		)


		player:SetAttribute(
			"ActiveLevel",
			"decision_tree"
		)


		print(
			"[TreeReset] LevelFlow state reset for",
			player.Name
		)

	end
)
