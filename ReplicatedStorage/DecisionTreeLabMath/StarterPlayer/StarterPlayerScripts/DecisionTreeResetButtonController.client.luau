local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--------------------------------------------------
-- UI
--------------------------------------------------

local levelFlowUI =
	playerGui:WaitForChild(
		"LevelFlowUI"
	)


local status =
	levelFlowUI:WaitForChild(
		"Status"
	)


local resetButton =
	status:WaitForChild(
		"ResetButton"
	)


--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local navigate =
	remotes:WaitForChild(
		"TreeLevelNavigate"
	)


local debugProgress =
	remotes:WaitForChild(
		"TreeLevelDebugChangeProgress"
	)


local fullResetRemote =
	remotes:WaitForChild(
		"DecisionTreeFullReset"
	)


local decisionTreeRPC =
	remotes:FindFirstChild(
		"DecisionTreeLevelRPC"
	)


if not decisionTreeRPC then

	decisionTreeRPC =
		ReplicatedStorage:FindFirstChild(
			"DecisionTreeLevelRPC",
			true
		)

end


--------------------------------------------------
-- VISIBILITY
--------------------------------------------------

local function updateVisibility()

	resetButton.Visible =
		player:GetAttribute(
			"ActiveLevel"
		)
		== "decision_tree"

end


player:GetAttributeChangedSignal(
	"ActiveLevel"
)
:Connect(
	updateVisibility
)


updateVisibility()


--------------------------------------------------
-- RESET
--------------------------------------------------

local resetting =
	false


local function resetDecisionTree()

	if resetting then
		return
	end


	resetting =
		true


	resetButton.Active =
		false


	resetButton.Text =
		"..."


	print(
		"[TreeReset] START"
	)


	------------------------------------------------
	-- 1. RETURN THROUGH THE REAL SUBLEVEL
	-- NAVIGATION SYSTEM TO SUBLEVEL 1
	------------------------------------------------

	for _ = 1, 6 do

		local activeSublevel =
			tonumber(
				player:GetAttribute(
					"TreeLevelActiveSublevel"
				)
			)
			or 1


		if activeSublevel <= 1 then
			break
		end


		local ok,
			result =
			pcall(
				function()

					return navigate:InvokeServer(
						"Previous"
					)

				end
			)


		if not ok then

			warn(
				"[TreeReset] Previous error:",
				result
			)

			break

		end


		if result
			and result.Ok == false
		then

			warn(
				"[TreeReset] Previous rejected:",
				result.Error
			)

			break

		end


		task.wait(
			0.25
		)

	end


	------------------------------------------------
	-- 2. FORCE THE SORTING GAME ITSELF TO RESTART
	------------------------------------------------

	task.wait(
		0.25
	)


	if decisionTreeRPC
		and decisionTreeRPC:IsA(
			"RemoteFunction"
		)
	then

		local ok,
			result =
			pcall(
				function()

					return decisionTreeRPC:InvokeServer(
						"Restart"
					)

				end
			)


		if not ok then

			warn(
				"[TreeReset] Restart RPC error:",
				result
			)

		else

			print(
				"[TreeReset] Sorting restarted"
			)

		end

	end


	------------------------------------------------
	-- 3. RESET THE AUTHORITATIVE TREE PROGRESS
	------------------------------------------------

	for _ = 1, 6 do

		debugProgress:FireServer(
			-1
		)

		task.wait(
			0.12
		)

	end


	------------------------------------------------
	-- 4. RESET GLOBAL LEVELFLOW STATE
	------------------------------------------------

	fullResetRemote:FireServer()


	task.wait(
		0.7
	)


	------------------------------------------------
	-- DONE
	------------------------------------------------

	print(
		"[TreeReset] COMPLETE"
	)


	print(
		"[TreeReset] Progress:",
		player:GetAttribute(
			"TreeLevelProgress"
		)
	)


	print(
		"[TreeReset] Sublevel:",
		player:GetAttribute(
			"TreeLevelActiveSublevel"
		)
	)


	resetButton.Text =
		"RESET"


	resetButton.Active =
		true


	resetting =
		false

end


--------------------------------------------------
-- BUTTON
--------------------------------------------------

resetButton.MouseButton1Click
	:Connect(
		resetDecisionTree
	)
