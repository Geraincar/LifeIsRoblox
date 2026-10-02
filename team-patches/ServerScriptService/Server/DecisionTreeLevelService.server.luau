warn("========== DECISION TREE SERVICE STARTED ==========")
local Players =
	game:GetService("Players")

local DataStoreService =
	game:GetService("DataStoreService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

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
-- REMOTE
--------------------------------------------------

local remotes =
	ReplicatedStorage
	:WaitForChild("Remotes")

local rpc =
	remotes
	:WaitForChild(
		"DecisionTreeLevelRPC"
	)

--------------------------------------------------
-- TREE
--------------------------------------------------

local tree =
	workspace
	:WaitForChild("DecisionTree")

local layer1 =
	tree:WaitForChild("Layer1")

local layer2 =
	tree:WaitForChild("Layer2")

local layer3 =
	tree:WaitForChild("Layer3")

--------------------------------------------------
-- FLOORS
--------------------------------------------------

local floors = {

	Root =
		layer1
		:WaitForChild(
			"RootNodeFloor"
		),

	Left =
		layer2
		:WaitForChild(
			"LeftConditionNodeFloor"
		),

	Right =
		layer2
		:WaitForChild(
			"RightConditionNodeFloor"
		),

	ClassA =
		layer3
		:WaitForChild(
			"ClassAFloor"
		),

	ClassB =
		layer3
		:WaitForChild(
			"ClassBFloor"
		),

	ClassC =
		layer3
		:WaitForChild(
			"ClassCFloor"
		),

	ClassD =
		layer3
		:WaitForChild(
			"ClassDFloor"
		),
}

--------------------------------------------------
-- NODE GEOMETRY
--------------------------------------------------

local NODE_GEOMETRY = {

	Root = {
		Layer = layer1,
		Prefix = "RootNode",
	},

	Left = {
		Layer = layer2,
		Prefix = "LeftConditionNode",
	},

	Right = {
		Layer = layer2,
		Prefix = "RightConditionNode",
	},

	ClassA = {
		Layer = layer3,
		Prefix = "ClassA",
	},

	ClassB = {
		Layer = layer3,
		Prefix = "ClassB",
	},

	ClassC = {
		Layer = layer3,
		Prefix = "ClassC",
	},

	ClassD = {
		Layer = layer3,
		Prefix = "ClassD",
	},
}

--------------------------------------------------
-- DATASTORE
--------------------------------------------------

local progressStore =
	DataStoreService:GetDataStore(
		"DecisionTreeSublevel_v1"
	)

--------------------------------------------------
-- RUNTIME
--------------------------------------------------

local states = {}
local heldObjects = {}

local dirty = {}
local saveScheduled = {}

local partByNode = {

	Root = {},
	Left = {},
	Right = {},

	ClassA = {},
	ClassB = {},
	ClassC = {},
	ClassD = {},
}

--------------------------------------------------
-- UTILS
--------------------------------------------------

local function playerKey(player)

	return
		"player_"
		.. tostring(player.UserId)

end

local function horizontalDistance(
	a,
	b
)

	local dx =
		a.X - b.X

	local dz =
		a.Z - b.Z

	return
		dx * dx
		+ dz * dz

end

--------------------------------------------------
-- FIND CLASS FROM EXISTING COLOR
--------------------------------------------------

local function colorDistance(
	a,
	b
)

	local dr =
		a.R - b.R

	local dg =
		a.G - b.G

	local db =
		a.B - b.B

	return
		dr * dr
		+ dg * dg
		+ db * db

end

local function getClassFromColor(part)

	local bestClass = nil
	local bestDistance = math.huge

	for className, color
		in pairs(
			Config.ClassColors
		)
	do

		local distance =
			colorDistance(
				part.Color,
				color
			)

		if distance < bestDistance then

			bestDistance =
				distance

			bestClass =
				className

		end
	end

	return bestClass
end

--------------------------------------------------
-- OBJECT SIZE ORDER
--
-- Builder generated:
--
-- #1 = scale 0.82
-- #2 = scale 1.00
-- #3 = scale 0.72
--
-- Ascending size therefore:
-- 3, 1, 2
--------------------------------------------------

local SIZE_ORDER = {

	A = {
		"A1",
		"A2",
	},

	B = {
		"B3",
		"B1",
		"B2",
	},

	C = {
		"C3",
		"C1",
		"C2",
	},

	D = {
		"D1",
		"D2",
	},
}

local EXPECTED_COUNTS = {

	Root = {
		A = 2,
		B = 3,
		C = 3,
		D = 2,
	},

	Left = {
		A = 2,
		B = 3,
	},

	Right = {
		C = 3,
		D = 2,
	},

	ClassA = {
		A = 2,
	},

	ClassB = {
		B = 3,
	},

	ClassC = {
		C = 3,
	},

	ClassD = {
		D = 2,
	},
}

--------------------------------------------------
-- BLACK OUTLINE
--------------------------------------------------

local function setupHighlight(part)

	local outline =
		part:FindFirstChild(
			"DT_BlackOutline"
		)

	if not outline then

		outline =
			Instance.new(
				"SelectionBox"
			)

		outline.Name =
			"DT_BlackOutline"

		outline.Parent =
			part
	end

	outline.Adornee =
		part

	outline.Color3 =
		Color3.fromRGB(
			0,
			0,
			0
		)

	outline.LineThickness =
		0.05

	outline.SurfaceTransparency =
		1

	outline.Transparency =
		0

	outline.Visible =
		false
end

local function normalizeFinalClassFloors()

	local gray =
		Color3.fromRGB(
			224,
			229,
			238
		)

	local black =
		Color3.fromRGB(
			28,
			33,
			42
		)

	for _, nodeName
		in ipairs({
			"ClassA",
			"ClassB",
			"ClassC",
			"ClassD",
		})
	do

		local floor =
			floors[nodeName]

		if floor then

			--------------------------------------------------
			-- Make final box floor gray
			--------------------------------------------------

			floor.Color =
				gray

			--------------------------------------------------
			-- Make title text black
			--------------------------------------------------

			local gui =
				floor:FindFirstChild(
					"TopLabel"
				)

			local label =
				gui
				and gui:FindFirstChild(
					"Text"
				)

			if label
				and label:IsA("TextLabel")
			then

				label.TextColor3 =
					black

				label.TextStrokeTransparency =
					1
			end
		end
	end
end

--------------------------------------------------
-- TAG ONE OBJECT
--------------------------------------------------

local function tagObject(
	part,
	objectId,
	node
)

	local data =
		Config.Objects[objectId]

	if not data then

		error(
			"[DecisionTree] Unknown object "
				.. tostring(objectId)
		)

	end

	part:SetAttribute(
		"DT_IsDataObject",
		true
	)

	part:SetAttribute(
		"DT_ObjectId",
		objectId
	)

	part:SetAttribute(
		"DT_SourceNode",
		node
	)

	part:SetAttribute(
		"DT_X",
		data.X
	)

	part:SetAttribute(
		"DT_Y",
		data.Y
	)

	part:SetAttribute(
		"DT_Class",
		data.Class
	)

	part.CanCollide =
		false

	part.CanTouch =
		false

	part.CanQuery =
		true

	part.CastShadow =
		false

	-- Base transparency stays zero.
	-- Each player hides/shows locally.
	part.Transparency =
		0

	setupHighlight(part)

	partByNode[node][objectId] =
		part

end

--------------------------------------------------
-- ASSIGN IDS INSIDE ONE NODE
--------------------------------------------------

local function assignNodeObjects(
	node,
	parts
)

	local byClass = {
		A = {},
		B = {},
		C = {},
		D = {},
	}

	for _, part
		in ipairs(parts)
	do

		local className =
			getClassFromColor(
				part
			)

		table.insert(
			byClass[className],
			part
		)

	end

	local expected =
		EXPECTED_COUNTS[node]

	for className, objects
		in pairs(byClass)
	do

		local expectedCount =
			expected[className]
			or 0

		if #objects ~= expectedCount then

			error(
				"[DecisionTree] "
					.. node
					.. " class "
					.. className
					.. ": expected "
					.. tostring(expectedCount)
					.. " objects, found "
					.. tostring(#objects)
			)

		end

		if expectedCount > 0 then

			table.sort(
				objects,

				function(a, b)

					return
						a.Size.Magnitude
						<
						b.Size.Magnitude

				end
			)

			local idOrder =
				SIZE_ORDER[className]

			for index, part
				in ipairs(objects)
			do

				local objectId =
					idOrder[index]

				tagObject(
					part,
					objectId,
					node
				)

			end
		end
	end
end

--------------------------------------------------
-- GET DATAOBJECTS
--------------------------------------------------

local function getDataObjects(layer)

	local result = {}

	for _, descendant
		in ipairs(
			layer:GetDescendants()
		)
	do

		if descendant:IsA("BasePart")
			and descendant.Name == "DataObject"
		then

			table.insert(
				result,
				descendant
			)

		end
	end

	return result
end

--------------------------------------------------
-- TAG BOX GEOMETRY
--------------------------------------------------

local function tagNodeGeometry()

	for node, info
		in pairs(NODE_GEOMETRY)
	do

		for _, descendant
			in ipairs(
				info.Layer:GetDescendants()
			)
		do

			if descendant:IsA("BasePart") then

				if string.sub(
					descendant.Name,
					1,
					#info.Prefix
					) == info.Prefix
				then

					descendant:SetAttribute(
						"DT_NodeId",
						node
					)

				end
			end
		end
	end
end

--------------------------------------------------
-- FIX RIGHT BRANCH LABELS
--
-- Current physical model was built with
-- YES -> D and NO -> C.
--
-- With C3 x=7 the correct rule is:
-- YES -> C
-- NO  -> D
--------------------------------------------------

local function setBeltText(
	beltName,
	text,
	color
)

	local belt =
		layer3:FindFirstChild(
			beltName
		)

	if not belt then
		return
	end

	local gui =
		belt:FindFirstChild(
			"TopLabel"
		)

	local label =
		gui
		and gui:FindFirstChild(
			"Text"
		)

	if label
		and label:IsA("TextLabel")
	then

		label.Text =
			text

		label.TextColor3 =
			color

	end
end

local function fixRightBranchLabels()

	setBeltText(
		"RightYesToDBelt",
		"NO",
		Color3.fromRGB(
			235,
			70,
			70
		)
	)

	setBeltText(
		"RightNoToCBelt",
		"YES",
		Color3.fromRGB(
			47,
			214,
			102
		)
	)

end

--------------------------------------------------
-- PHYSICAL TREE SETUP
--------------------------------------------------

local function setupPhysicalTree()

	tagNodeGeometry()

	--------------------------------------------------
	-- ROOT
	--------------------------------------------------

	local rootObjects =
		getDataObjects(
			layer1
		)

	if #rootObjects ~= 10 then

		error(
			"[DecisionTree] Layer1 must have 10 DataObjects, found "
				.. tostring(#rootObjects)
		)

	end

	assignNodeObjects(
		"Root",
		rootObjects
	)

	--------------------------------------------------
	-- LEFT / RIGHT
	--------------------------------------------------

	local layer2Objects =
		getDataObjects(
			layer2
		)

	if #layer2Objects ~= 10 then

		error(
			"[DecisionTree] Layer2 must have 10 DataObjects, found "
				.. tostring(#layer2Objects)
		)

	end

	local leftObjects = {}
	local rightObjects = {}

	for _, part
		in ipairs(layer2Objects)
	do

		local leftDistance =
			horizontalDistance(
				part.Position,
				floors.Left.Position
			)

		local rightDistance =
			horizontalDistance(
				part.Position,
				floors.Right.Position
			)

		if leftDistance
			<
			rightDistance
		then

			table.insert(
				leftObjects,
				part
			)

		else

			table.insert(
				rightObjects,
				part
			)

		end
	end

	assignNodeObjects(
		"Left",
		leftObjects
	)

	assignNodeObjects(
		"Right",
		rightObjects
	)

	--------------------------------------------------
	-- FINAL CLASSES
	--------------------------------------------------

	local layer3Objects =
		getDataObjects(
			layer3
		)

	if #layer3Objects ~= 10 then

		error(
			"[DecisionTree] Layer3 must have 10 DataObjects, found "
				.. tostring(#layer3Objects)
		)

	end

	local finalGroups = {

		ClassA = {},
		ClassB = {},
		ClassC = {},
		ClassD = {},
	}

	for _, part
		in ipairs(layer3Objects)
	do

		local nearestNode =
			nil

		local nearestDistance =
			math.huge

		for _, node
			in ipairs({
				"ClassA",
				"ClassB",
				"ClassC",
				"ClassD",
			})
		do

			local distance =
				horizontalDistance(
					part.Position,
					floors[node].Position
				)

			if distance
				<
				nearestDistance
			then

				nearestDistance =
					distance

				nearestNode =
					node

			end
		end

		table.insert(
			finalGroups[nearestNode],
			part
		)

	end

	for node, parts
		in pairs(finalGroups)
	do

		assignNodeObjects(
			node,
			parts
		)

	end

	normalizeFinalClassFloors()
	fixRightBranchLabels()

	tree:SetAttribute(
		"DT_SetupReady",
		true
	)

	print(
		"[DecisionTree] Physical setup complete. 30 objects tagged."
	)

end

warn("[DecisionTree] Starting physical setup...")

local setupSuccess, setupError = xpcall(
	setupPhysicalTree,
	debug.traceback
)

if setupSuccess then
	warn("[DecisionTree] PHYSICAL SETUP SUCCESS")
else
	warn("[DecisionTree] PHYSICAL SETUP FAILED")
	warn(setupError)
	error(setupError)
end
--------------------------------------------------
-- STATE
--------------------------------------------------

local function newState()

	return {

		RootDone = {},
		FinalDone = {},
	}

end

local function resetDecisionTree(player)

	local state =
		newState()

	states[player] =
		state

	heldObjects[player] =
		nil

	dirty[player] =
		nil

	player:SetAttribute(
		"DecisionTreeCompleted",
		false
	)

	print(
		"[DecisionTree]",
		player.Name,
		"progress reset"
	)

	return state
end

local function sanitizeState(raw)

	local state =
		newState()

	if type(raw) ~= "table" then
		return state
	end

	if type(raw.RootDone)
		== "table"
	then

		for _, objectId
			in ipairs(
				Config.ObjectOrder
			)
		do

			if raw.RootDone[objectId]
				== true
			then

				state.RootDone[objectId] =
					true

			end
		end
	end

	if type(raw.FinalDone)
		== "table"
	then

		for _, objectId
			in ipairs(
				Config.ObjectOrder
			)
		do

			if raw.FinalDone[objectId]
				== true
			then

				state.FinalDone[objectId] =
					true

			end
		end
	end

	return state
end

--------------------------------------------------
-- COMPLETION
--------------------------------------------------

local function rootComplete(state)

	for _, objectId
		in ipairs(
			Config.ObjectOrder
		)
	do

		if state.RootDone[objectId]
			~= true
		then

			return false

		end
	end

	return true
end

local function finalComplete(state)

	for _, objectId
		in ipairs(
			Config.ObjectOrder
		)
	do

		if state.FinalDone[objectId]
			~= true
		then

			return false

		end
	end

	return true
end

--------------------------------------------------
-- PUBLIC STATE
--------------------------------------------------

local function copyTrueMap(source)

	local result = {}

	for key, value
		in pairs(source)
	do

		if value == true then
			result[key] = true
		end
	end

	return result
end

local function publicState(state)

	return {

		RootDone =
			copyTrueMap(
				state.RootDone
			),

		FinalDone =
			copyTrueMap(
				state.FinalDone
			),

		RootComplete =
			rootComplete(state),

		Completed =
			finalComplete(state),
	}

end

--------------------------------------------------
-- LOAD
--------------------------------------------------

local function loadPlayer(player)

	if states[player] then
		return states[player]
	end

	local state =
		newState()

	local success, saved =
		pcall(function()

			return progressStore:GetAsync(
				playerKey(player)
			)

		end)

	if success then

		state =
			sanitizeState(saved)

	else

		warn(
			"[DecisionTree] Could not load progress for",
			player.Name,
			saved
		)

	end

	states[player] =
		state

	player:SetAttribute(
		"DecisionTreeCompleted",
		finalComplete(state)
	)

	return state
end

--------------------------------------------------
-- SAVE
--------------------------------------------------

local function savePlayer(player)

	local state =
		states[player]

	if not state then
		return
	end

	local currentRoot =
		copyTrueMap(
			state.RootDone
		)

	local currentFinal =
		copyTrueMap(
			state.FinalDone
		)

	local success, err =
		pcall(function()

			progressStore:UpdateAsync(
				playerKey(player),

				function(old)

					local merged =
					sanitizeState(old)

					for objectId
						in pairs(currentRoot)
					do

						merged.RootDone[objectId] =
						true

					end

					for objectId
						in pairs(currentFinal)
					do

						merged.FinalDone[objectId] =
						true

					end

					return merged
				end
			)

		end)

	if not success then

		warn(
			"[DecisionTree] Could not save progress for",
			player.Name,
			err
		)

	end
end

--------------------------------------------------
-- EXACT SAVE
-- Used by manual restart because normal save
-- only adds progress and never removes it.
--------------------------------------------------

local function saveExactPlayerState(player)

	local state =
		states[player]

	if not state then
		return false
	end

	local snapshot = {

		RootDone =
			copyTrueMap(
				state.RootDone
			),

		FinalDone =
			copyTrueMap(
				state.FinalDone
			),
	}

	local success, err =
		pcall(function()

			progressStore:SetAsync(
				playerKey(player),
				snapshot
			)

		end)

	if not success then

		warn(
			"[DecisionTree] Could not save exact state for",
			player.Name,
			err
		)

	end

	return success
end

--------------------------------------------------
-- DEBOUNCED SAVE
--------------------------------------------------

local function markDirty(player)

	dirty[player] =
		true

	if saveScheduled[player] then
		return
	end

	saveScheduled[player] =
		true

	task.delay(
		2,

		function()

			saveScheduled[player] =
				nil

			if not states[player] then
				return
			end

			if dirty[player] then

				dirty[player] =
					false

				savePlayer(player)

			end
		end
	)

end

--------------------------------------------------
-- ACTIVE CHECK
--------------------------------------------------

local function isActive(player)

	return
		player:GetAttribute(
			"TreeLevelInside"
		) == true

		and

		player:GetAttribute(
			"TreeLevelActiveSublevel"
		) == 1

end

--------------------------------------------------
-- AVAILABILITY
--------------------------------------------------

local function isObjectAvailable(
	state,
	objectId,
	sourceNode
)

	if not Config.Objects[objectId] then
		return false
	end

	if sourceNode == "Root" then

		return
			state.RootDone[objectId]
			~= true

	end

	if sourceNode == "Left"
		or sourceNode == "Right"
	then

		if not rootComplete(state) then
			return false
		end

		if state.RootDone[objectId]
			~= true
		then

			return false
		end

		if state.FinalDone[objectId]
			== true
		then

			return false
		end

		local expectedMiddle =
			Config.GetExpectedTarget(
				objectId,
				"Root"
			)

		return
			expectedMiddle
			== sourceNode

	end

	return false
end

--------------------------------------------------
-- PUBLIC HELD OBJECT
--------------------------------------------------

local function publicHeld(held)

	if not held then
		return nil
	end

	local data =
		Config.Objects[
	held.ObjectId
	]

	return {

		ObjectId =
			held.ObjectId,

		SourceNode =
			held.SourceNode,

		X =
			data.X,

		Y =
			data.Y,

		ConditionText =
			Config.GetConditionText(
				held.SourceNode
			),
	}
end

--------------------------------------------------
-- RPC
--------------------------------------------------

rpc.OnServerInvoke =
	function(
		player,
		action,
		payload
	)

	local state =
		states[player]
		or loadPlayer(player)

	--------------------------------------------------
	-- BEGIN SUBLEVEL
	-- Continue from existing progress.
	--------------------------------------------------

	if action == "Begin" then

		if not isActive(player) then

			return {
				Ok = false,
				Error = "Decision tree level is not active",
			}

		end

		-- Nothing stays in the player's hand
		-- after leaving/re-entering the zone.
		heldObjects[player] = nil

		player:SetAttribute(
			"DecisionTreeCompleted",
			finalComplete(state)
		)

		return {

			Ok = true,

			State =
				publicState(
					state
				),

			Held = nil,
		}
	end

	--------------------------------------------------
	-- RESTART
	--------------------------------------------------

	if action == "Restart" then

		if not isActive(player) then

			return {
				Ok = false,
				Error = "Decision tree level is not active",
			}

		end

		state =
			resetDecisionTree(
				player
			)

		heldObjects[player] = nil

		-- Restart must also overwrite saved progress.
		saveExactPlayerState(
			player
		)

		return {

			Ok = true,

			State =
				publicState(
					state
				),

			Held = nil,
		}
	end

	--------------------------------------------------
	-- STATE
	--------------------------------------------------



	if action == "GetState" then

		return {

			Ok = true,

			State =
				publicState(
					state
				),

			Held = nil,
		}
	end

	--------------------------------------------------
	-- EVERYTHING ELSE REQUIRES ACTIVE LEVEL
	--------------------------------------------------

	if not isActive(player) then

		heldObjects[player] =
			nil

		return {

			Ok = false,
			Error = "Decision tree level is not active",
		}
	end

	--------------------------------------------------
	-- PICK
	--------------------------------------------------

	if action == "Pick" then

		if type(payload)
			~= "table"
		then

			return {
				Ok = false,
				Error = "Invalid payload",
			}
		end

		local objectId =
			payload.ObjectId

		local sourceNode =
			payload.SourceNode

		if type(objectId)
			~= "string"
			or
			type(sourceNode)
			~= "string"
		then

			return {
				Ok = false,
				Error = "Invalid object",
			}
		end

		local physical =
			partByNode[sourceNode]
			and
			partByNode[sourceNode][objectId]

		if not physical then

			return {
				Ok = false,
				Error = "Physical object not found",
			}
		end

		if not isObjectAvailable(
			state,
			objectId,
			sourceNode
			)
		then

			return {
				Ok = false,
				Error = "Object is not available",
			}
		end

		--------------------------------------------------
		-- Replaces previous held object.
		--------------------------------------------------

		heldObjects[player] = {

			ObjectId =
				objectId,

			SourceNode =
				sourceNode,
		}

		return {

			Ok = true,

			Held =
				publicHeld(
					heldObjects[player]
				),

			State =
				publicState(
					state
				),
		}
	end

	--------------------------------------------------
	-- PLACE
	--------------------------------------------------

	if action == "Place" then

		if type(payload)
			~= "table"
		then

			return {
				Ok = false,
				Error = "Invalid payload",
			}
		end

		local targetNode =
			payload.TargetNode

		if type(targetNode)
			~= "string"
		then

			return {
				Ok = false,
				Error = "Invalid target",
			}
		end

		local held =
			heldObjects[player]

		if not held then

			return {
				Ok = false,
				Error = "Nothing is held",
			}
		end

		--------------------------------------------------
		-- Revalidate availability server-side.
		--------------------------------------------------

		if not isObjectAvailable(
			state,
			held.ObjectId,
			held.SourceNode
			)
		then

			heldObjects[player] =
				nil

			return {
				Ok = false,
				Error = "Held object is no longer available",
			}
		end

		local expectedTarget =
			Config.GetExpectedTarget(
				held.ObjectId,
				held.SourceNode
			)

		--------------------------------------------------
		-- INCORRECT
		--------------------------------------------------

		if targetNode
			~= expectedTarget
		then

			return {

				Ok = true,

				Correct = false,

				Held =
					publicHeld(
						held
					),

				State =
					publicState(
						state
					),
			}
		end

		--------------------------------------------------
		-- CORRECT ROOT
		--------------------------------------------------

		if held.SourceNode
			== "Root"
		then

			state.RootDone[
			held.ObjectId
			] = true

			--------------------------------------------------
			-- CORRECT SECOND LAYER
			--------------------------------------------------

		elseif held.SourceNode
			== "Left"
			or
			held.SourceNode
			== "Right"
		then

			state.FinalDone[
			held.ObjectId
			] = true

		else

			return {

				Ok = false,
				Error = "Invalid source node",
			}
		end

		--------------------------------------------------
		-- Correct placement removes held object.
		--------------------------------------------------

		heldObjects[player] =
			nil

		markDirty(player)

		local completed =
			finalComplete(
				state
			)

		if completed then

			player:SetAttribute(
				"DecisionTreeCompleted",
				true
			)

		end

		return {

			Ok = true,

			Correct = true,

			Completed =
				completed,

			Held = nil,

			State =
				publicState(
					state
				),
		}
	end

	--------------------------------------------------
	-- CLEAR HELD
	--------------------------------------------------

	if action == "ClearHeld" then

		heldObjects[player] =
			nil

		return {
			Ok = true,
		}
	end

	return {

		Ok = false,
		Error = "Unknown action",
	}
end

--------------------------------------------------
-- PLAYER
--------------------------------------------------

local function bindPlayer(player)

	local state =
		loadPlayer(player)

	player:SetAttribute(
		"DecisionTreeCompleted",
		finalComplete(state)
	)

	local function clearHeldIfInactive()

		if not isActive(player) then

			heldObjects[player] =
				nil

			--------------------------------------------------
			-- SAVE PARTIAL PROGRESS WHEN LEAVING SUBLEVEL
			--------------------------------------------------

			if dirty[player] then

				dirty[player] =
					nil

				savePlayer(player)

			end
		end
	end

	player:GetAttributeChangedSignal(
		"TreeLevelInside"
	):Connect(
		clearHeldIfInactive
	)

	player:GetAttributeChangedSignal(
		"TreeLevelActiveSublevel"
	):Connect(
		clearHeldIfInactive
	)

end

Players.PlayerAdded:Connect(
	bindPlayer
)

for _, player
	in ipairs(
		Players:GetPlayers()
	)
do

	task.spawn(
		bindPlayer,
		player
	)

end

Players.PlayerRemoving:Connect(
	function(player)

		savePlayer(player)

		states[player] =
			nil

		heldObjects[player] =
			nil

		dirty[player] =
			nil

		saveScheduled[player] =
			nil

	end
)

--------------------------------------------------
-- SHUTDOWN
--------------------------------------------------

game:BindToClose(
	function()

		for _, player
			in ipairs(
				Players:GetPlayers()
			)
		do

			savePlayer(player)

		end
	end
)