local Visuals = {}
Visuals.__index = Visuals

local EXPECTED_OBJECT_COUNT = 30

--------------------------------------------------
-- CREATE
--------------------------------------------------

function Visuals.new(
	player,
	tree,
	Config
)

	local self =
		setmetatable(
			{},
			Visuals
		)

	self.Player =
		player

	self.Tree =
		tree

	self.Config =
		Config

	self.State =
		nil

	self.Active =
		false

	self.ShowTree =
		false

	self.Parts =
		{}

	self.PartIndex = {

		Root = {},
		Left = {},
		Right = {},

		ClassA = {},
		ClassB = {},
		ClassC = {},
		ClassD = {},
	}

	self.HeldVisual =
		nil

	--------------------------------------------------
	-- WAIT FOR ALL 30 TAGGED OBJECTS
	--------------------------------------------------

	local deadline =
		os.clock() + 10

	repeat

		self:RefreshParts()

		if #self.Parts
			>= EXPECTED_OBJECT_COUNT
		then

			break
		end

		task.wait(0.1)

	until os.clock() >= deadline

	warn(
		"[DecisionTreeVisuals] Found tagged objects:",
		#self.Parts,
		"/",
		EXPECTED_OBJECT_COUNT
	)

	--------------------------------------------------
	-- HIDE EVERYTHING INITIALLY
	--------------------------------------------------

	self:HideAll()

	--------------------------------------------------
	-- FINAL BOX STYLE
	--------------------------------------------------

	self:NormalizeFinalBoxes()

	return self
end

--------------------------------------------------
-- REFRESH OBJECT CACHE
--------------------------------------------------

function Visuals:RefreshParts()

	self.Parts =
		{}

	self.PartIndex = {

		Root = {},
		Left = {},
		Right = {},

		ClassA = {},
		ClassB = {},
		ClassC = {},
		ClassD = {},
	}

	for _, descendant
		in ipairs(
			self.Tree:GetDescendants()
		)
	do

		if descendant:IsA("BasePart")
			and
			descendant:GetAttribute(
				"DT_IsDataObject"
			) == true
		then

			table.insert(
				self.Parts,
				descendant
			)

			local node =
				descendant:GetAttribute(
					"DT_SourceNode"
				)

			local objectId =
				descendant:GetAttribute(
					"DT_ObjectId"
				)

			if node
				and objectId
				and self.PartIndex[node]
			then

				self.PartIndex[node][objectId] =
					descendant

			end
		end
	end
end

--------------------------------------------------
-- FINAL BOX APPEARANCE
--------------------------------------------------

function Visuals:NormalizeFinalBoxes()

	local layer3 =
		self.Tree:FindFirstChild(
			"Layer3"
		)

	if not layer3 then
		return
	end

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

	local floorNames = {

		"ClassAFloor",
		"ClassBFloor",
		"ClassCFloor",
		"ClassDFloor",
	}

	for _, floorName
		in ipairs(floorNames)
	do

		local floor =
			layer3:FindFirstChild(
				floorName
			)

		if floor then

			--------------------------------------------------
			-- GRAY FLOOR
			--------------------------------------------------

			floor.Color =
				gray

			--------------------------------------------------
			-- BLACK CLASS TITLE
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
				and label:IsA(
					"TextLabel"
				)
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
-- HIDE ALL DATA OBJECTS
--------------------------------------------------

function Visuals:HideAll()

	self:RefreshParts()

	for _, part
		in ipairs(
			self.Parts
		)
	do

		part.LocalTransparencyModifier =
			1

		part.CanQuery =
			false

	end
end

--------------------------------------------------
-- GET ONE PHYSICAL COPY
--------------------------------------------------

function Visuals:GetPart(
	node,
	objectId
)

	local nodeTable =
		self.PartIndex[node]

	local part =
		nodeTable
		and nodeTable[objectId]

	--------------------------------------------------
	-- FALLBACK:
	-- Refresh if attributes replicated later
	--------------------------------------------------

	if not part then

		self:RefreshParts()

		nodeTable =
			self.PartIndex[node]

		part =
			nodeTable
			and nodeTable[objectId]

	end

	return part
end

--------------------------------------------------
-- VISIBILITY
--------------------------------------------------

function Visuals:IsVisible(
	node,
	objectId
)

	--------------------------------------------------
	-- OUTSIDE TREE LEVEL
	--------------------------------------------------

	if not self.ShowTree
		or not self.State
	then

		return false

	end

	--------------------------------------------------
	-- COMPLETED:
	-- SHOW ALL 30 PHYSICAL COPIES
	--------------------------------------------------

	if self.State.Completed == true then

		return true

	end

	--------------------------------------------------
	-- UNFINISHED TREE IS ONLY SHOWN
	-- WHILE SUBLEVEL 1 IS ACTIVE
	--------------------------------------------------

	if not self.Active then

		return false

	end

	--------------------------------------------------
	-- ROOT
	--
	-- Visible until successfully sent
	-- to Left/Right.
	--------------------------------------------------

	if node == "Root" then

		return
			self.State.RootDone[objectId]
			~= true

	end

	--------------------------------------------------
	-- LEFT / RIGHT
	--
	-- Visible after Root placement.
	--
	-- Disappears after placement into
	-- final class.
	--------------------------------------------------

	if node == "Left"
		or node == "Right"
	then

		if self.State.RootDone[objectId]
			~= true
		then

			return false

		end

		if self.State.FinalDone[objectId]
			== true
		then

			return false

		end

		return
			self.Config.GetExpectedTarget(
				objectId,
				"Root"
			)
			== node

	end

	--------------------------------------------------
	-- FINAL CLASS
	--------------------------------------------------

	if node == "ClassA"
		or node == "ClassB"
		or node == "ClassC"
		or node == "ClassD"
	then

		if self.State.FinalDone[objectId]
			~= true
		then

			return false

		end

		return
			self.Config.GetFinalTarget(
				objectId
			)
			== node

	end

	return false
end

--------------------------------------------------
-- AVAILABILITY
--------------------------------------------------

function Visuals:IsAvailable(
	node,
	objectId
)

	if not self.Active
		or not self.State
	then

		return false

	end

	--------------------------------------------------
	-- COMPLETED TREE:
	-- NOTHING CAN BE PICKED
	--------------------------------------------------

	if self.State.Completed == true then

		return false

	end

	--------------------------------------------------
	-- ROOT
	--------------------------------------------------

	if node == "Root" then

		return
			self.State.RootDone[objectId]
			~= true

	end

	--------------------------------------------------
	-- LEFT / RIGHT
	--------------------------------------------------

	if node == "Left"
		or node == "Right"
	then

		--------------------------------------------------
		-- SECOND LAYER LOCKED UNTIL ROOT
		-- IS COMPLETELY SORTED
		--------------------------------------------------

		if self.State.RootComplete
			~= true
		then

			return false

		end

		--------------------------------------------------
		-- MUST HAVE PASSED ROOT
		--------------------------------------------------

		if self.State.RootDone[objectId]
			~= true
		then

			return false

		end

		--------------------------------------------------
		-- ALREADY IN FINAL CLASS
		--------------------------------------------------

		if self.State.FinalDone[objectId]
			== true
		then

			return false

		end

		--------------------------------------------------
		-- MUST ACTUALLY BELONG TO THIS NODE
		--------------------------------------------------

		return
			self.Config.GetExpectedTarget(
				objectId,
				"Root"
			)
			== node

	end

	return false
end

--------------------------------------------------
-- APPLY SERVER STATE
--------------------------------------------------

function Visuals:SetState(
	state,
	showTree,
	active
)

	self.State =
		state

	self.ShowTree =
		showTree == true

	self.Active =
		active == true

	--------------------------------------------------
	-- ALWAYS REFRESH CACHE
	--------------------------------------------------

	self:RefreshParts()

	for _, part
		in ipairs(
			self.Parts
		)
	do

		local node =
			part:GetAttribute(
				"DT_SourceNode"
			)

		local objectId =
			part:GetAttribute(
				"DT_ObjectId"
			)

		local visible =
			self:IsVisible(
				node,
				objectId
			)

		if visible then

			part.LocalTransparencyModifier =
				0

			part.CanQuery =
				true

		else

			part.LocalTransparencyModifier =
				1

			part.CanQuery =
				false

		end
	end
end

--------------------------------------------------
-- GET DATA OBJECT FROM MOUSE TARGET
--------------------------------------------------

function Visuals:GetDataPart(target)

	if not target
		or not target:IsA(
			"BasePart"
		)
	then

		return nil

	end

	if target:GetAttribute(
		"DT_IsDataObject"
		) == true
	then

		return target

	end

	return nil
end

--------------------------------------------------
-- CHECK WHETHER CLICKED DATA OBJECT
-- CAN BE PICKED
--------------------------------------------------

function Visuals:IsAvailablePart(part)

	if not part then

		return false

	end

	return self:IsAvailable(

		part:GetAttribute(
			"DT_SourceNode"
		),

		part:GetAttribute(
			"DT_ObjectId"
		)
	)
end

--------------------------------------------------
-- GET NODE ID FROM CLICKED BOX
--------------------------------------------------

function Visuals:GetNodeFromTarget(
	target
)

	if not target
		or not target:IsA(
			"BasePart"
		)
	then

		return nil

	end

	return
		target:GetAttribute(
			"DT_NodeId"
		)
end

--------------------------------------------------
-- RAYCAST THROUGH DATA OBJECTS
--
-- Needed when an object visually blocks
-- the box floor underneath it.
--------------------------------------------------

function Visuals:RaycastNodeIgnoringObjects(
	mouse
)

	local filter = {}

	for _, part
		in ipairs(
			self.Parts
		)
	do

		table.insert(
			filter,
			part
		)

	end

	if self.Player.Character then

		table.insert(
			filter,
			self.Player.Character
		)

	end

	if self.HeldVisual then

		table.insert(
			filter,
			self.HeldVisual
		)

	end

	local params =
		RaycastParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances =
		filter

	local ray =
		mouse.UnitRay

	local result =
		workspace:Raycast(
			ray.Origin,
			ray.Direction * 1000,
			params
		)

	if not result then

		return nil

	end

	return
		result.Instance:GetAttribute(
			"DT_NodeId"
		)
end

--------------------------------------------------
-- DESTROY HELD VISUAL
--------------------------------------------------

function Visuals:DestroyHeldVisual()

	if self.HeldVisual then

		self.HeldVisual:Destroy()

		self.HeldVisual =
			nil

	end
end

--------------------------------------------------
-- CREATE VISUAL OBJECT IN PLAYER'S HAND
--------------------------------------------------

function Visuals:CreateHeldVisual(
	sourceNode,
	objectId
)

	--------------------------------------------------
	-- REMOVE PREVIOUS HELD VISUAL
	--------------------------------------------------

	self:DestroyHeldVisual()

	--------------------------------------------------
	-- REFRESH INDEX
	--------------------------------------------------

	self:RefreshParts()

	local source =
		self:GetPart(
			sourceNode,
			objectId
		)

	if not source then

		warn(
			"[DecisionTreeVisuals] Cannot find held source:",
			sourceNode,
			objectId
		)

		return
	end

	--------------------------------------------------
	-- CHARACTER
	--------------------------------------------------

	local character =
		self.Player.Character

	if not character then

		warn(
			"[DecisionTreeVisuals] Character not found"
		)

		return
	end

	--------------------------------------------------
	-- RIGHT HAND
	--------------------------------------------------

	local hand =
		character:FindFirstChild(
			"RightHand"
		)

		or

		character:FindFirstChild(
			"Right Arm"
		)

		or

		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not hand then

		warn(
			"[DecisionTreeVisuals] Hand not found"
		)

		return
	end

	--------------------------------------------------
	-- CLONE SOURCE OBJECT
	--------------------------------------------------

	local clone =
		source:Clone()

	clone.Name =
		"DecisionTreeHeldObject"

	--------------------------------------------------
	-- REMOVE SERVER/CLIENT HELPER OBJECTS
	-- FROM CLONE
	--------------------------------------------------

	for _, descendant
		in ipairs(
			clone:GetDescendants()
		)
	do

		if descendant:IsA(
			"Highlight"
			)
				or descendant:IsA(
					"SelectionBox"
				)
				or descendant:IsA(
					"Script"
				)
				or descendant:IsA(
					"LocalScript"
				)
		then

			descendant:Destroy()

		end
	end

	--------------------------------------------------
	-- PHYSICS
	--------------------------------------------------

	clone.Anchored =
		false

	clone.CanCollide =
		false

	clone.CanTouch =
		false

	clone.CanQuery =
		false

	clone.Massless =
		true

	clone.Transparency =
		0

	clone.LocalTransparencyModifier =
		0

	clone.Parent =
		character

	--------------------------------------------------
	-- POSITION
	--------------------------------------------------

	clone.CFrame =
		hand.CFrame
		*
		CFrame.new(
			0,
			-0.4,
			-0.9
		)

	--------------------------------------------------
	-- WELD TO HAND
	--------------------------------------------------

	local weld =
		Instance.new(
			"WeldConstraint"
		)

	weld.Part0 =
		hand

	weld.Part1 =
		clone

	weld.Parent =
		clone

	self.HeldVisual =
		clone

	print(
		"[DecisionTreeVisuals] Held visual created:",
		objectId,
		"from",
		sourceNode
	)
end

return Visuals