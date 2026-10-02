local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function findModule(wantedName)
	local exact = script.Parent:FindFirstChild(wantedName)
	if exact and exact:IsA("ModuleScript") then
		return exact
	end

	for _, child in ipairs(script.Parent:GetChildren()) do
		if child:IsA("ModuleScript") then
			local trimmedName = string.match(child.Name, "^%s*(.-)%s*$")
			if trimmedName == wantedName then
				warn(string.format(
					"[Macro-F1] ModuleScript '%s' has spaces in its name. Rename it to '%s'.",
					child.Name,
					wantedName
					))
				return child
			end
		end
	end

	error(string.format(
		"[Macro-F1] ModuleScript '%s' was not found inside %s",
		wantedName,
		script.Parent:GetFullName()
		))
end

local Config = require(findModule("MacroF1Config"))
local UI = require(findModule("MacroF1UI"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tree = workspace:WaitForChild("DecisionTree")
local completeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TreeSublevelCompleted")

while tree:GetAttribute("DT_SetupReady") ~= true do
	tree:GetAttributeChangedSignal("DT_SetupReady"):Wait()
end

local ui = UI.new(player:WaitForChild("PlayerGui"))
local metrics, macroF1 = Config.GetAllMetrics()

local floorByNode = {
	Root = tree:WaitForChild("Layer1"):WaitForChild("RootNodeFloor"),
	Left = tree:WaitForChild("Layer2"):WaitForChild("LeftConditionNodeFloor"),
	Right = tree:WaitForChild("Layer2"):WaitForChild("RightConditionNodeFloor"),
	ClassA = tree:WaitForChild("Layer3"):WaitForChild("ClassAFloor"),
	ClassB = tree:WaitForChild("Layer3"):WaitForChild("ClassBFloor"),
	ClassC = tree:WaitForChild("Layer3"):WaitForChild("ClassCFloor"),
	ClassD = tree:WaitForChild("Layer3"):WaitForChild("ClassDFloor"),
}

local active = false
local started = false
local completedView = false
local completing = false
local validationFolder = nil
local resultGuis = {}
local resultButtons = {}
local originalState = {}
local phaseIndex = 0
local selectedIds = {}
local counts = { TP = 0, FP = 0, FN = 0 }
local macroSelected = {}
local celebrationFolder = nil
local celebrationBees = {}
local celebrationElapsed = 0
local celebrationBase = nil

local phases = {
	{ Name = "TP", Goal = 2, Node = "ClassA", Ids = { A1 = true, A2 = true } },
	{ Name = "FP", Goal = 1, Node = "ClassA", Ids = { B1 = true } },
	{ Name = "FN", Goal = 1, Node = "ClassB", Ids = { A3 = true } },
}

local BEE_COUNT = 600
local FORMATION_SPEED = 7
local FORMATION_THICKNESS = 0.9
local FORMATION_DEPTH = 0.7
local FORMATION_OFFSET = Vector3.new(0, 8.5, 0)

-- Эти линии и скорость повторяют пасхалку 67 из AmbientBeeController.
local PATH_6_POINTS = {
	Vector3.new(-2, 8, 0),
	Vector3.new(-6, 8, 0),
	Vector3.new(-9, 7, 0),
	Vector3.new(-10, 4, 0),
	Vector3.new(-10, 0, 0),
	Vector3.new(-9, -4, 0),
	Vector3.new(-6, -6, 0),
	Vector3.new(-2, -6, 0),
	Vector3.new(0, -4, 0),
	Vector3.new(0, 0, 0),
	Vector3.new(-2, 3, 0),
	Vector3.new(-5, 4, 0),
	Vector3.new(-10, 4, 0),
}

local PATH_7_POINTS = {
	Vector3.new(3, 8, 0),
	Vector3.new(12, 8, 0),
	Vector3.new(10, 5, 0),
	Vector3.new(8, 2, 0),
	Vector3.new(6, -1, 0),
	Vector3.new(4, -4, 0),
	Vector3.new(3, -6, 0),
}

local function centeredRandom()
	return math.random() + math.random() - 1
end

local function buildPath(points)
	local path = {
		points = points,
		segments = {},
		totalLength = 0,
	}
	for index = 1, #points - 1 do
		local pointA = points[index]
		local pointB = points[index + 1]
		local length = (pointB - pointA).Magnitude
		table.insert(path.segments, {
			a = pointA,
			b = pointB,
			length = length,
			startDistance = path.totalLength,
		})
		path.totalLength += length
	end
	return path
end

local function samplePath(path, distance)
	distance = math.clamp(distance, 0, path.totalLength)
	for _, segment in ipairs(path.segments) do
		local segmentEnd = segment.startDistance + segment.length
		if distance <= segmentEnd then
			local localDistance = distance - segment.startDistance
			local alpha = segment.length > 0 and localDistance / segment.length or 0
			local position = segment.a:Lerp(segment.b, alpha)
			local direction = segment.b - segment.a
			direction = direction.Magnitude > 0 and direction.Unit or Vector3.new(1, 0, 0)
			return position, direction
		end
	end
	local lastSegment = path.segments[#path.segments]
	return lastSegment.b, (lastSegment.b - lastSegment.a).Unit
end

local path6 = buildPath(PATH_6_POINTS)
local path7 = buildPath(PATH_7_POINTS)

local function getBeeParts(object)
	local parts = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function calculateFormationPosition(beeData, formationElapsed)
	local path = beeData.formationPath
	local pathLength = path.totalLength
	local travelledDistance = beeData.formationStartDistance + formationElapsed * FORMATION_SPEED
	local fullCycle = pathLength * 2
	local cycleDistance = travelledDistance % fullCycle
	local actualDistance
	local movementDirection

	if cycleDistance <= pathLength then
		actualDistance = cycleDistance
		movementDirection = 1
	else
		actualDistance = fullCycle - cycleDistance
		movementDirection = -1
	end

	local point, pathDirection = samplePath(path, actualDistance)
	pathDirection *= movementDirection

	local sideDirection = Vector3.new(-pathDirection.Y, pathDirection.X, 0)
	if sideDirection.Magnitude > 0.001 then
		sideDirection = sideDirection.Unit
	else
		sideDirection = Vector3.new(1, 0, 0)
	end

	local wobble = math.sin(formationElapsed * 4 + beeData.phase) * 0.15
	local localPosition = point
		+ FORMATION_OFFSET
		+ sideDirection * (beeData.formationSideOffset + wobble)
		+ Vector3.new(0, 0, beeData.formationDepthOffset)

	local worldPosition = celebrationBase:PointToWorldSpace(localPosition)
	local worldDirection = celebrationBase:VectorToWorldSpace(pathDirection)
	return worldPosition, worldDirection
end

local function startBee67Celebration()
	if celebrationFolder and celebrationFolder.Parent then
		return
	end

	local beeTemplate = ReplicatedStorage
		:WaitForChild("Assets")
		:WaitForChild("Bees")
		:WaitForChild("AmbientBee")

	celebrationFolder = Instance.new("Folder")
	celebrationFolder.Name = "Bee67Celebration"
	celebrationFolder.Parent = workspace
	table.clear(celebrationBees)

	local classA = floorByNode.ClassA
	local classD = floorByNode.ClassD
	local horizontal = classD.Position - classA.Position
	horizontal = Vector3.new(horizontal.X, 0, horizontal.Z)
	local right = horizontal.Magnitude > 0.01 and horizontal.Unit or Vector3.new(1, 0, 0)
	local up = Vector3.new(0, 1, 0)
	local back = right:Cross(up).Unit
	local center = (classA.Position + classD.Position) / 2
	local groundY = math.min(classA.Position.Y, classD.Position.Y)
	celebrationBase = CFrame.fromMatrix(
		Vector3.new(center.X, groundY, center.Z),
		right,
		up,
		back
	)

	local combinedPathLength = path6.totalLength + path7.totalLength
	local path6Probability = path6.totalLength / combinedPathLength

	for index = 1, BEE_COUNT do
		local bee = beeTemplate:Clone()
		bee.Name = "Bee67_" .. index
		bee.Parent = celebrationFolder
		local parts = getBeeParts(bee)
		if #parts == 0 then
			bee:Destroy()
		else
			local rootPart = parts[1]
			for _, part in ipairs(parts) do
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
			end

			local partOffsets = {}
			for _, part in ipairs(parts) do
				partOffsets[part] = rootPart.CFrame:ToObjectSpace(part.CFrame)
			end

			local formationPath
			if math.random() < path6Probability then
				formationPath = path6
			else
				formationPath = path7
			end

			table.insert(celebrationBees, {
				rootPart = rootPart,
				parts = parts,
				partOffsets = partOffsets,
				phase = math.random() * math.pi * 2,
				formationPath = formationPath,
				formationStartDistance = math.random() * formationPath.totalLength,
				formationSideOffset = centeredRandom() * FORMATION_THICKNESS,
				formationDepthOffset = centeredRandom() * FORMATION_DEPTH,
			})
		end
	end

	celebrationElapsed = 0
end

local function updateBee67Celebration(dt)
	if not celebrationFolder or not celebrationFolder.Parent or not celebrationBase then
		return
	end

	celebrationElapsed += dt

	for _, beeData in ipairs(celebrationBees) do
		local rootPart = beeData.rootPart
		if rootPart and rootPart.Parent then
			local finalPosition, finalDirection = calculateFormationPosition(beeData, celebrationElapsed)
			if finalDirection.Magnitude > 0.001 then
				finalDirection = finalDirection.Unit
			else
				finalDirection = celebrationBase.RightVector
			end

			local rootCFrame = CFrame.lookAt(finalPosition, finalPosition + finalDirection)
			for _, part in ipairs(beeData.parts) do
				if part and part.Parent then
					local offset = beeData.partOffsets[part]
					part.CFrame = rootCFrame * offset
				end
			end
		end
	end
end

local function isInside()
	return player:GetAttribute("TreeLevelInside") == true
end

local function activeSublevel()
	return tonumber(player:GetAttribute("TreeLevelActiveSublevel")) or 0
end

local function progress()
	return tonumber(player:GetAttribute("TreeLevelProgress")) or 0
end

local function wantsTask()
	return isInside() and activeSublevel() == 4
end

local function wantsCompletedView()
	return isInside() and activeSublevel() == 0 and progress() >= 4
end

local function isOriginalObject(part)
	return part:IsA("BasePart")
		and part:GetAttribute("DT_IsDataObject") == true
		and part:GetAttribute("F1_IsValidationObject") ~= true
end

local function rememberAndHideOriginals()
	for _, descendant in ipairs(tree:GetDescendants()) do
		if isOriginalObject(descendant) then
			if originalState[descendant] == nil then
				originalState[descendant] = {
					Transparency = descendant.LocalTransparencyModifier,
					CanQuery = descendant.CanQuery,
				}
			end
			descendant.LocalTransparencyModifier = 1
			descendant.CanQuery = false
		end
	end
end

local function restoreOriginals()
	for part, state in pairs(originalState) do
		if part and part.Parent then
			part.LocalTransparencyModifier = state.Transparency
			part.CanQuery = state.CanQuery
		end
	end
	table.clear(originalState)
end

local function findTemplates()
	local templates = {}
	for _, descendant in ipairs(tree:GetDescendants()) do
		if isOriginalObject(descendant) then
			local className = descendant:GetAttribute("DT_Class")
			if Config.ClassColors[className] and not templates[className] then
				templates[className] = descendant
			end
		end
	end
	for _, className in ipairs(Config.Classes) do
		assert(templates[className], "Macro-F1: no honey template for class " .. className)
	end
	return templates
end

local function cleanClone(part)
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("BillboardGui")
			or child:IsA("SurfaceGui")
			or child:IsA("SelectionBox")
			or child:IsA("Highlight")
			or child:IsA("ClickDetector")
			or child:IsA("ProximityPrompt")
		then
			child:Destroy()
		end
	end
end

local function placeGroup(floor, parts)
	local amount = #parts
	if amount == 0 then
		return
	end
	local columns = math.ceil(math.sqrt(amount * math.max(floor.Size.X, 1) / math.max(floor.Size.Z, 1)))
	columns = math.clamp(columns, 1, amount)
	local rows = math.ceil(amount / columns)
	local usableX = math.max(1, floor.Size.X - 1.8)
	local usableZ = math.max(1, floor.Size.Z - 1.8)
	local stepX = columns == 1 and 0 or math.min(2.15, usableX / (columns - 1))
	local stepZ = rows == 1 and 0 or math.min(2.15, usableZ / (rows - 1))

	for index, part in ipairs(parts) do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local x = (column - (columns - 1) / 2) * stepX
		local z = (row - (rows - 1) / 2) * stepZ
		local y = floor.Size.Y / 2 + part.Size.Y / 2 + 0.08
		part.CFrame = floor.CFrame * CFrame.new(x, y, z)
	end
end

local function destroyValidationTree()
	if validationFolder then
		validationFolder:Destroy()
		validationFolder = nil
	end
end

local function buildValidationTree()
	destroyValidationTree()
	local templates = findTemplates()
	validationFolder = Instance.new("Folder")
	validationFolder.Name = "MacroF1ValidationObjects"
	validationFolder.Parent = tree

	local groups = {}
	for nodeName in pairs(floorByNode) do
		groups[nodeName] = {}
	end

	for _, row in ipairs(Config.Data) do
		for _, nodeName in ipairs(Config.GetNodes(row)) do
			local clone = templates[row.TrueClass]:Clone()
			cleanClone(clone)
			clone.Name = "F1_" .. row.Id .. "_" .. nodeName
			clone.Color = Config.ClassColors[row.TrueClass]
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = true
			clone.LocalTransparencyModifier = 0
			clone:SetAttribute("DT_IsDataObject", false)
			clone:SetAttribute("F1_IsValidationObject", true)
			clone:SetAttribute("F1_ObjectId", row.Id)
			clone:SetAttribute("F1_X", row.X)
			clone:SetAttribute("F1_Y", row.Y)
			clone:SetAttribute("F1_TrueClass", row.TrueClass)
			clone:SetAttribute("F1_PredictedClass", row.PredictedClass)
			clone:SetAttribute("F1_DisplayNode", nodeName)
			clone.Parent = validationFolder
			table.insert(groups[nodeName], clone)
		end
	end

	for nodeName, parts in pairs(groups) do
		table.sort(parts, function(a, b)
			return a:GetAttribute("F1_ObjectId") < b:GetAttribute("F1_ObjectId")
		end)
		placeGroup(floorByNode[nodeName], parts)
	end
end

local function destroyResults()
	for _, gui in pairs(resultGuis) do
		if gui then
			gui:Destroy()
		end
	end
	table.clear(resultGuis)
	table.clear(resultButtons)
end

local function chooseMacroClass(className)
	if not active
		or not started
		or completing
		or phases[phaseIndex] ~= nil
		or macroSelected[className]
	then
		return
	end

	local value = metrics[className]
	if not value then
		return
	end

	macroSelected[className] = true
	ui:AddMacroValue(className, value.F1)

	local worldButton = resultButtons[className]
	if worldButton then
		worldButton.BackgroundColor3 = Config.ClassColors[className]
		worldButton.BackgroundTransparency = 0.04
		worldButton.TextColor3 = Color3.fromRGB(20, 25, 34)
		worldButton.Active = false
		worldButton.AutoButtonColor = false
	end

	local selectedCount = 0
	for _ in pairs(macroSelected) do
		selectedCount += 1
	end
	if selectedCount == #Config.Classes then
		completing = true
		active = false
		started = false
		destroyResults()
		destroyValidationTree()
		restoreOriginals()
		ui:ShowCompletionSequence(function()
			if not wantsTask() then
				ui:SetEnabled(false)
				return
			end
			completedView = true
			ui:SetEnabled(false)
			startBee67Celebration()
			completeRemote:FireServer(4)
		end)
	end
end

local function showResults(clickable)
	destroyResults()
	for _, className in ipairs(Config.Classes) do
		local value = metrics[className]
		local button = Instance.new("TextButton")
		button.Name = "F1Result" .. className
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Size = UDim2.fromOffset(180, 46)
		button.Position = UDim2.fromOffset(-1000, -1000)
		button.BackgroundColor3 = Color3.fromRGB(20, 28, 43)
		button.BackgroundTransparency = 0.12
		button.TextColor3 = Config.ClassColors[className]
		button.TextStrokeColor3 = Color3.fromRGB(5, 8, 14)
		button.TextStrokeTransparency = 0.7
		button.Text = string.format("F1 %s = %.2f", className, value.F1)
		button.TextSize = 20
		button.Font = Enum.Font.GothamMedium
		button.AutoButtonColor = clickable
		button.Active = clickable
		button.Selectable = clickable
		button.Visible = false
		button.ZIndex = 35
		button.Parent = ui.Gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button
		local outline = Instance.new("UIStroke")
		outline.Color = Config.ClassColors[className]
		outline.Thickness = 2
		outline.Parent = button

		if clickable then
			button.Activated:Connect(function()
				chooseMacroClass(className)
			end)
		end
		resultGuis[className] = button
		resultButtons[className] = button
	end
end

local function updateResultPositions()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for className, button in pairs(resultButtons) do
		local floor = floorByNode["Class" .. className]
		local worldPosition = floor.Position + Vector3.new(0, floor.Size.Y / 2 + 6.4, 0)
		local viewportPosition, onScreen = camera:WorldToViewportPoint(worldPosition)
		button.Position = UDim2.fromOffset(viewportPosition.X, viewportPosition.Y)
		button.Visible = onScreen and viewportPosition.Z > 0
	end
end

local function updatePhasePrompt()
	local phase = phases[phaseIndex]
	if phase then
		local current = counts[phase.Name]
		ui:SetPhase(phase.Name, current, phase.Goal)
		ui:SetCounts(counts.TP, counts.FP, counts.FN)
	end
end

local function finishClassA()
	ui:ShowClassAMetrics(metrics.A)
	showResults(false)
	task.delay(1.25, function()
		if active and started and not completing and not phases[phaseIndex] then
			showResults(true)
			ui:ShowMacro(metrics, chooseMacroClass)
		end
	end)
end

local function beginPhase(index)
	phaseIndex = index
	table.clear(selectedIds)
	if phases[index] then
		updatePhasePrompt()
	else
		finishClassA()
	end
end

local function beginTask()
	if not active or not wantsTask() then
		return
	end
	started = true
	completing = false
	table.clear(macroSelected)
	counts = { TP = 0, FP = 0, FN = 0 }
	ui:ShowClassATask()
	beginPhase(1)
end

local function startLevel()
	active = true
	started = false
	completedView = false
	completing = false
	table.clear(macroSelected)
	rememberAndHideOriginals()
	buildValidationTree()
	ui:SetEnabled(true)
	ui:ShowIntro(beginTask)
end

local function showCompletedView()
	active = false
	started = false
	completedView = true
	rememberAndHideOriginals()
	buildValidationTree()
	showResults(false)
	ui:SetEnabled(true)
	ui:ShowCompleted(metrics, macroF1)
end

local function stopLevel()
	active = false
	started = false
	completedView = false
	completing = false
	ui:SetEnabled(false)
	destroyResults()
	destroyValidationTree()
	restoreOriginals()
end

local function refreshMode()
	if progress() >= 4 then
		startBee67Celebration()
	end
	if wantsTask() then
		if not active then
			stopLevel()
			startLevel()
		end
	elseif wantsCompletedView() then
		if not completedView then
			stopLevel()
			showCompletedView()
		end
	elseif active or completedView or validationFolder then
		stopLevel()
	end
end

local function clickedValidationObject()
	if not active or not started or completing then
		return
	end
	local phase = phases[phaseIndex]
	if not phase then
		return
	end
	local part = mouse.Target
	if not part or part:GetAttribute("F1_IsValidationObject") ~= true then
		return
	end
	local objectId = part:GetAttribute("F1_ObjectId")
	if part:GetAttribute("F1_DisplayNode") ~= phase.Node
		or phase.Ids[objectId] ~= true
		or selectedIds[objectId]
	then
		return
	end

	selectedIds[objectId] = true
	counts[phase.Name] += 1
	updatePhasePrompt()
	if counts[phase.Name] >= phase.Goal then
		local finishedPhase = phaseIndex
		task.delay(0.35, function()
			if active and started and phaseIndex == finishedPhase then
				beginPhase(finishedPhase + 1)
			end
		end)
	end
end

mouse.Button1Down:Connect(clickedValidationObject)

player:GetAttributeChangedSignal("TreeLevelInside"):Connect(refreshMode)
player:GetAttributeChangedSignal("TreeLevelActiveSublevel"):Connect(refreshMode)
player:GetAttributeChangedSignal("TreeLevelProgress"):Connect(refreshMode)

RunService.RenderStepped:Connect(function(dt)
	updateBee67Celebration(dt)
	if active or completedView then
		updateResultPositions()
		rememberAndHideOriginals()
		local target = mouse.Target
		if target and target:GetAttribute("F1_IsValidationObject") == true then
			local row = Config.ById[target:GetAttribute("F1_ObjectId")]
			ui:SetHover(row, mouse.X, mouse.Y)
		else
			ui:SetHover(nil)
		end
	end
end)

refreshMode()
