local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--------------------------------------------------
-- PLAYER
--------------------------------------------------

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config =
	require(
		ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("DecisionTreeConfig")
	)

--------------------------------------------------
-- MODULES
--------------------------------------------------

local UI =
	require(
		script.Parent
		:WaitForChild("DecisionTreeUI")
	)

local Visuals =
	require(
		script.Parent
		:WaitForChild("DecisionTreeVisuals")
	)

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage
	:WaitForChild("Remotes")

local rpc =
	remotes
	:WaitForChild("DecisionTreeLevelRPC")

local completeRemote =
	remotes
	:WaitForChild("TreeSublevelCompleted")

local navigateRemote =
	remotes
	:WaitForChild("TreeLevelNavigate")

--------------------------------------------------
-- TREE
--------------------------------------------------

local tree =
	workspace
	:WaitForChild("DecisionTree")

--------------------------------------------------
-- WAIT FOR SERVER SETUP
--------------------------------------------------

while tree:GetAttribute("DT_SetupReady") ~= true do

	tree:GetAttributeChangedSignal(
		"DT_SetupReady"
	):Wait()

end

--------------------------------------------------
-- UI / VISUALS
--------------------------------------------------

local ui =
	UI.new(
		playerGui
	)

local visuals =
	Visuals.new(
		player,
		tree,
		Config
	)

--------------------------------------------------
-- COMPLETION SCREEN
--------------------------------------------------

local completionGui =
	Instance.new("ScreenGui")

completionGui.Name =
	"DecisionTreeCompletionGui"

completionGui.ResetOnSpawn =
	false

completionGui.IgnoreGuiInset =
	true

completionGui.DisplayOrder =
	150

completionGui.Parent =
	playerGui

local completionShade =
	Instance.new("Frame")

completionShade.Name =
	"Shade"

completionShade.Size =
	UDim2.fromScale(1, 1)

completionShade.BackgroundColor3 =
	Color3.fromRGB(0, 0, 0)

completionShade.BackgroundTransparency =
	0.25

completionShade.Visible =
	false

completionShade.Active =
	true

completionShade.Parent =
	completionGui

local completionPanel =
	Instance.new("Frame")

completionPanel.AnchorPoint =
	Vector2.new(0.5, 0.5)

completionPanel.Position =
	UDim2.fromScale(0.5, 0.5)

completionPanel.Size =
	UDim2.new(
		0,
		860,
		0,
		330
	)

completionPanel.BackgroundColor3 =
	Color3.fromRGB(
		20,
		24,
		34
	)

completionPanel.Parent =
	completionShade

local panelCorner =
	Instance.new("UICorner")

panelCorner.CornerRadius =
	UDim.new(0, 16)

panelCorner.Parent =
	completionPanel

local panelStroke =
	Instance.new("UIStroke")

panelStroke.Thickness =
	2

panelStroke.Color =
	Color3.fromRGB(
		77,
		128,
		219
	)

panelStroke.Parent =
	completionPanel

local title =
	Instance.new("TextLabel")

title.BackgroundTransparency =
	1

title.Position =
	UDim2.new(
		0,
		35,
		0,
		24
	)

title.Size =
	UDim2.new(
		1,
		-70,
		0,
		50
	)

title.Text =
	"Поздравляем!"

title.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

title.Font =
	Enum.Font.GothamBold

title.TextSize =
	32

title.Parent =
	completionPanel

local text =
	Instance.new("TextLabel")

text.BackgroundTransparency =
	1

text.Position =
	UDim2.new(
		0,
		45,
		0,
		86
	)

text.Size =
	UDim2.new(
		1,
		-90,
		0,
		150
	)

text.Text =
	"Теперь ты знаешь, как классифицирует объекты решающее дерево!\n\nДерево выбирает условия для узлов так, чтобы минимизировать Энтропию. Посмотрим, как это работает!"

text.TextColor3 =
	Color3.fromRGB(
		240,
		243,
		250
	)

text.Font =
	Enum.Font.Gotham

text.TextSize =
	23

text.TextWrapped =
	true

text.TextXAlignment =
	Enum.TextXAlignment.Center

text.TextYAlignment =
	Enum.TextYAlignment.Center

text.Parent =
	completionPanel

local nextButton =
	Instance.new("TextButton")

nextButton.AnchorPoint =
	Vector2.new(0.5, 1)

nextButton.Position =
	UDim2.new(
		0.5,
		0,
		1,
		-28
	)

nextButton.Size =
	UDim2.new(
		0,
		190,
		0,
		48
	)

nextButton.BackgroundColor3 =
	Color3.fromRGB(
		58,
		123,
		231
	)

nextButton.Text =
	"ДАЛЕЕ"

nextButton.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

nextButton.Font =
	Enum.Font.GothamBold

nextButton.TextSize =
	19

nextButton.Parent =
	completionPanel

local nextCorner =
	Instance.new("UICorner")

nextCorner.CornerRadius =
	UDim.new(0, 10)

nextCorner.Parent =
	nextButton

--------------------------------------------------
-- STATE
--------------------------------------------------

local state = nil
local held = nil
local busy = false

local activationVersion = 0

local completionSent = false
local transitionBusy = false

local lastReplayRestartToken = 0

--------------------------------------------------
-- LEVEL STATE
--------------------------------------------------

local function isInsideZone()

	return
		player:GetAttribute(
			"TreeLevelInside"
		) == true

end

local function isActive()

	return
		isInsideZone()

		and

		player:GetAttribute(
			"TreeLevelActiveSublevel"
		) == 1

end

--------------------------------------------------
-- RPC
--------------------------------------------------

local function callRPC(
	action,
	payload
)

	local success, result =
		pcall(function()

			return
			rpc:InvokeServer(
				action,
				payload
			)

		end)

	if not success then

		warn(
			"[DecisionTree] RPC error:",
			result
		)

		return nil

	end

	return result
end

--------------------------------------------------
-- HELD OBJECT
--------------------------------------------------

local function clearHeld()

	held = nil

	visuals:DestroyHeldVisual()

	ui:HideData()

end

--------------------------------------------------
-- COMPLETION PANEL
--------------------------------------------------

local function hideCompletionPanel()

	completionShade.Visible =
		false

end

local function showCompletionPanel()

	if not isActive() then
		return
	end

	completionShade.Visible =
		true

end

--------------------------------------------------
-- COMPLETE SUBLEVEL
--------------------------------------------------

local function sendNormalCompletion()

	if completionSent then
		return
	end

	completionSent = true

	completeRemote:FireServer(
		1
	)

	--------------------------------------------------
	-- Safety:
	-- if server rejected completion, show panel again.
	--------------------------------------------------

	task.delay(
		1,

		function()

			if isActive()
				and state
				and state.Completed
			then

				completionSent =
					false

				showCompletionPanel()

			end

		end
	)
end

--------------------------------------------------
-- APPLY STATE
--------------------------------------------------

local function applyState(newState)

	if newState then
		state = newState
	end

	local active =
		isActive()

	local showTree =
		active

	if state
		and state.Completed
		and isInsideZone()
	then

		showTree =
			true

	end

	visuals:SetState(
		state,
		showTree,
		active
	)

	if active
		and state
		and state.Completed
	then

		showCompletionPanel()

	end
end

--------------------------------------------------
-- NEXT AFTER DECISION TREE
--------------------------------------------------

nextButton.Activated:Connect(
	function()

		if transitionBusy then
			return
		end

		if not isActive() then
			return
		end

		if not state
			or state.Completed ~= true
		then

			return
		end

		transitionBusy =
			true

		hideCompletionPanel()

		--------------------------------------------------
		-- Are we replaying sublevel 1?
		--------------------------------------------------

		local replayReturn =
			tonumber(
				player:GetAttribute(
					"TreeLevelReplayReturn"
				)
			) or 0

		if replayReturn > 1 then

			local success, result =
				pcall(function()

					return
					navigateRemote:InvokeServer(
						"ResumeReplay"
					)

				end)

			if not success
				or not result
				or result.Ok ~= true
			then

				warn(
					"[DecisionTree] Could not return from replay"
				)

				showCompletionPanel()

			end

		else

			sendNormalCompletion()

		end

		transitionBusy =
			false

	end
)

--------------------------------------------------
-- ACTIVATE / DEACTIVATE
--------------------------------------------------

local function refreshActivation()

	activationVersion =
		activationVersion + 1

	local version =
		activationVersion

	--------------------------------------------------
	-- NOT SUBLEVEL 1
	--------------------------------------------------

	if not isActive() then

		clearHeld()

		hideCompletionPanel()

		--------------------------------------------------
		-- IMPORTANT:
		-- after tree is complete, keep all physical
		-- copies visible while player is still
		-- inside the general TreeLevel zone.
		--------------------------------------------------

		local keepTreeVisible =
			isInsideZone()
			and state
			and state.Completed == true

		visuals:SetState(
			state,
			keepTreeVisible == true,
			false
		)

		ui:SetEnabled(
			false
		)

		ui:ClearTransient()

		completionSent =
			false

		return
	end

	--------------------------------------------------
	-- SUBLEVEL 1 ACTIVE
	--------------------------------------------------

	hideCompletionPanel()

	ui:SetEnabled(
		true
	)

	task.spawn(
		function()

			--------------------------------------------------
			-- PREVIOUS SUBLEVEL:
			-- when coming back from Entropy,
			-- start Decision Tree from zero.
			--------------------------------------------------

			local replayToken =
				tonumber(
					player:GetAttribute(
						"TreeLevelReplayToken"
					)
				) or 0

			local replayRestartTarget =
				tonumber(
					player:GetAttribute(
						"TreeLevelReplayRestartTarget"
					)
				) or 0

			local action =
				"Begin"

			if replayRestartTarget == 1
				and replayToken > 0
				and replayToken ~= lastReplayRestartToken
			then

				lastReplayRestartToken =
					replayToken

				action =
					"Restart"

			end

			local result =
				callRPC(
					action,
					{}
				)

			if version ~= activationVersion then
				return
			end

			if not isActive() then
				return
			end

			if not result
				or result.Ok ~= true
			then

				warn(
					"[DecisionTree] Could not begin sublevel:",
					action
				)

				return
			end

			held = nil

			visuals:DestroyHeldVisual()

			completionSent =
				false

			applyState(
				result.State
			)

		end
	)
end

--------------------------------------------------
-- RESTART BUTTON
--------------------------------------------------

ui.RestartButton.Activated:Connect(
	function()

		if busy then
			return
		end

		if not isActive() then
			return
		end

		busy = true

		hideCompletionPanel()

		clearHeld()

		local result =
			callRPC(
				"Restart",
				{}
			)

		busy = false

		if not result
			or result.Ok ~= true
		then

			warn(
				"[DecisionTree] Restart failed"
			)

			return
		end

		completionSent =
			false

		applyState(
			result.State
		)

		print(
			"[DecisionTree] Sublevel restarted"
		)

	end
)

--------------------------------------------------
-- PICK
--------------------------------------------------

local function pickObject(part)

	if busy then
		return
	end

	if completionShade.Visible then
		return
	end

	if not visuals:IsAvailablePart(
		part
		)
	then

		return
	end

	busy = true

	local objectId =
		part:GetAttribute(
			"DT_ObjectId"
		)

	local sourceNode =
		part:GetAttribute(
			"DT_SourceNode"
		)

	local result =
		callRPC(
			"Pick",

			{
				ObjectId =
				objectId,

				SourceNode =
				sourceNode,
			}
		)

	busy = false

	if not result
		or result.Ok ~= true
	then

		return
	end

	applyState(
		result.State
	)

	held =
		result.Held

	if not held then
		return
	end

	visuals:CreateHeldVisual(
		held.SourceNode,
		held.ObjectId
	)

	ui:SetData(
		held.X,
		held.Y
	)

	ui:SetCondition(
		held.ConditionText
	)
end

--------------------------------------------------
-- PLACE
--------------------------------------------------

local function placeObject(targetNode)

	if busy
		or not held
	then

		return
	end

	if completionShade.Visible then
		return
	end

	busy = true

	local result =
		callRPC(
			"Place",

			{
				TargetNode =
				targetNode,
			}
		)

	busy = false

	if not result
		or result.Ok ~= true
	then

		return
	end

	--------------------------------------------------
	-- WRONG
	--------------------------------------------------

	if result.Correct == false then

		ui:ShowFeedback(
			false
		)

		if result.Held then
			held = result.Held
		end

		return
	end

	--------------------------------------------------
	-- CORRECT
	--------------------------------------------------

	if result.Correct == true then

		ui:ShowFeedback(
			true
		)

		held = nil

		visuals:DestroyHeldVisual()

		--------------------------------------------------
		-- If this was the last object,
		-- applyState() shows completion panel.
		-- WE DO NOT send completion here anymore.
		--------------------------------------------------

		applyState(
			result.State
		)

	end
end

--------------------------------------------------
-- CLICK
--------------------------------------------------

mouse.Button1Down:Connect(
	function()

		if completionShade.Visible then
			return
		end

		if not isActive()
			or not state
		then

			return
		end

		local target =
			mouse.Target

		local dataPart =
			visuals:GetDataPart(
				target
			)

		if dataPart
			and visuals:IsAvailablePart(
				dataPart
			)
		then

			pickObject(
				dataPart
			)

			return
		end

		if not held then
			return
		end

		local node =
			visuals:GetNodeFromTarget(
				target
			)

		if not node then

			node =
				visuals
				:RaycastNodeIgnoringObjects(
					mouse
				)

		end

		if node then

			placeObject(
				node
			)

		end
	end
)

--------------------------------------------------
-- HOVER
--------------------------------------------------

RunService.RenderStepped:Connect(
	function()

		if completionShade.Visible then
			return
		end

		if not isActive()
			or not state
		then

			return
		end

		if held then

			ui:SetData(
				held.X,
				held.Y
			)

			ui:SetCondition(
				held.ConditionText
			)

			return
		end

		local target =
			mouse.Target

		local part =
			visuals:GetDataPart(
				target
			)

		if part
			and visuals:IsAvailablePart(
				part
			)
		then

			ui:SetData(
				part:GetAttribute(
					"DT_X"
				),

				part:GetAttribute(
					"DT_Y"
				)
			)

			ui:SetCondition(
				Config.GetConditionText(
					part:GetAttribute(
						"DT_SourceNode"
					)
				)
			)

			return
		end

		ui:HideData()

		if state.RootComplete ~= true then

			ui:SetCondition(
				Config.GetConditionText(
					"Root"
				)
			)

		else

			ui:SetCondition(
				nil
			)

		end
	end
)

--------------------------------------------------
-- CHARACTER RESET
--------------------------------------------------

player.CharacterAdded:Connect(
	function()

		clearHeld()

	end
)

--------------------------------------------------
-- ATTRIBUTE WATCHERS
--------------------------------------------------

player:GetAttributeChangedSignal(
	"TreeLevelInside"
):Connect(
	refreshActivation
)

player:GetAttributeChangedSignal(
	"TreeLevelActiveSublevel"
):Connect(
	refreshActivation
)

--------------------------------------------------
-- START
--------------------------------------------------

refreshActivation()