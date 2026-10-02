local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = require(script.Parent:WaitForChild("ImpurityLevelUI"))

local Runner = {}
Runner.__index = Runner

local YELLOW = Color3.fromRGB(255, 225, 70)

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

function Runner.new(config)
	local self = setmetatable({}, Runner)
	self.Config = config
	self.Player = Players.LocalPlayer
	self.Mouse = self.Player:GetMouse()
	self.Tree = workspace:WaitForChild("DecisionTree")
	self.CompleteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TreeSublevelCompleted")

	while self.Tree:GetAttribute("DT_SetupReady") ~= true do
		self.Tree:GetAttributeChangedSignal("DT_SetupReady"):Wait()
	end

	self.UI = UI.new(self.Player:WaitForChild("PlayerGui"), {
		GuiName = config.GuiName,
		Title = config.Title,
		Formula = config.Formula,
		Explanation = config.Explanation,
		AccentColor = config.AccentColor or YELLOW,
		Classes = config.Classes,
		FormulaKind = config.FormulaKind,
	})

	self.Nodes = {}
	self.TaskNodes = {}
	self.Active = false
	self.Started = false
	self.RunToken = 0
	self.NodeIndex = 0
	self.StageIndex = 0
	self.CurrentNode = nil
	self.CurrentStage = nil
	self.Selected = {}
	self.CurrentCount = 0
	self.Goal = 0
	self.Transitioning = false

	self:_buildNodes()
	self:_connect()
	self:_refreshCompletedResults()
	self:_refreshActivation()
	return self
end

function Runner:_isActive()
	return self.Player:GetAttribute("TreeLevelInside") == true
		and tonumber(self.Player:GetAttribute("TreeLevelActiveSublevel")) == self.Config.Sublevel
end

function Runner:_tokenIsCurrent(token)
	return self.Active and self.Started and self:_isActive() and token == self.RunToken
end

function Runner:_getObjects(sourceNode)
	local objects = {}
	for _, descendant in ipairs(self.Tree:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("DT_IsDataObject") == true
			and descendant:GetAttribute("DT_SourceNode") == sourceNode
		then
			table.insert(objects, descendant)
		end
	end
	return objects
end

function Runner:_countClasses(objects)
	local counts = {}
	local measureClasses = self.Config.MeasureClasses or self.Config.Classes
	for _, className in ipairs(measureClasses) do
		counts[className] = 0
	end
	for _, part in ipairs(objects) do
		local className = part:GetAttribute("DT_Class")
		if counts[className] ~= nil then
			counts[className] += 1
		end
	end
	return counts
end

function Runner:_createHighlights(node)
	node.Highlights = {}
	for _, descendant in ipairs(node.Layer:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("DT_IsDataObject") ~= true
			and startsWith(descendant.Name, node.Prefix)
		then
			local highlight = Instance.new("Highlight")
			highlight.Name = self.Config.Symbol .. "BoxHighlight"
			highlight.Adornee = descendant
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillColor = YELLOW
			highlight.FillTransparency = 0.68
			highlight.OutlineColor = YELLOW
			highlight.OutlineTransparency = 0
			highlight.Enabled = false
			highlight.Parent = descendant
			table.insert(node.Highlights, highlight)
		end
	end
end

function Runner:_createOverheadResult(node)
	local old = node.Floor:FindFirstChild(self.Config.Symbol .. "OverheadResult")
	if old then
		old:Destroy()
	end

	local overhead = Instance.new("BillboardGui")
	overhead.Name = self.Config.Symbol .. "OverheadResult"
	overhead.Adornee = node.Floor
	overhead.Size = UDim2.fromOffset(220, 68)
	overhead.StudsOffset = self.Config.ResultOffset or Vector3.new(0, 5.5, 0)
	overhead.AlwaysOnTop = true
	overhead.Enabled = false
	overhead.Parent = node.Floor

	local overheadText = Instance.new("TextLabel")
	overheadText.Size = UDim2.fromScale(1, 1)
	overheadText.BackgroundTransparency = 1
	overheadText.Text = ""
	overheadText.TextColor3 = self.Config.ResultColor or YELLOW
	overheadText.TextStrokeColor3 = Color3.fromRGB(18, 23, 34)
	overheadText.TextStrokeTransparency = 0.15
	overheadText.TextScaled = true
	overheadText.Font = Enum.Font.GothamBold
	overheadText.Parent = overhead

	node.OverheadGui = overhead
	node.OverheadText = overheadText
end

function Runner:_buildNodes()
	for _, definition in ipairs(self.Config.Nodes) do
		local layer = self.Tree:WaitForChild(definition.Layer)
		local node = {
			Id = definition.Id,
			SourceNode = definition.SourceNode,
			Title = definition.Title,
			Prefix = definition.Prefix,
			Layer = layer,
			Floor = layer:WaitForChild(definition.FloorName),
		}
		self:_createHighlights(node)
		self:_createOverheadResult(node)
		table.insert(self.Nodes, node)
		if definition.Task ~= false then
			table.insert(self.TaskNodes, node)
		end
	end
end

function Runner:_showAllObjects()
	for _, descendant in ipairs(self.Tree:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("DT_IsDataObject") == true then
			descendant.LocalTransparencyModifier = 0
			descendant.CanQuery = true
		end
		if descendant:IsA("SelectionBox") then
			local adornee = descendant.Adornee
			if descendant.Name == "DT_BlackOutline"
				or descendant.Name == "EntropySelectedBox"
				or (adornee and adornee:GetAttribute("DT_IsDataObject") == true)
			then
				descendant.Visible = false
			end
		end
	end
end

function Runner:_setHighlightedNode(activeNode)
	for _, node in ipairs(self.Nodes) do
		for _, highlight in ipairs(node.Highlights) do
			highlight.Enabled = node == activeNode
		end
	end
end

function Runner:_showOverheadResult(node, value)
	local result = string.format("%s = %.2f", self.Config.Symbol, value)
	node.OverheadText.Text = result
	node.OverheadGui.Enabled = true
end

function Runner:_hideAllOverheadResults()
	for _, node in ipairs(self.Nodes) do
		node.OverheadGui.Enabled = false
	end
end

function Runner:_measureNode(node)
	node.Objects = self:_getObjects(node.SourceNode)
	node.Counts = self:_countClasses(node.Objects)
	return self.Config.Calculate(
		node.Counts,
		#node.Objects,
		self.Config.MeasureClasses or self.Config.Classes
	)
end

function Runner:_refreshCompletedResults()
	local progress = tonumber(self.Player:GetAttribute("TreeLevelProgress")) or 0
	local inside = self.Player:GetAttribute("TreeLevelInside") == true
	local activeSublevel = tonumber(self.Player:GetAttribute("TreeLevelActiveSublevel")) or 0
	local macroF1OwnsTree = activeSublevel == 4 or (progress >= 4 and activeSublevel == 0)
	if not inside or progress < self.Config.Sublevel or macroF1OwnsTree then
		self:_hideAllOverheadResults()
		return
	end
	for _, node in ipairs(self.Nodes) do
		self:_showOverheadResult(node, self:_measureNode(node))
	end
end

function Runner:_finishNode(token)
	if not self:_tokenIsCurrent(token) or not self.CurrentNode then
		return
	end
	local value = self.Config.Calculate(
		self.CurrentNode.Counts,
		#self.CurrentNode.Objects,
		self.Config.MeasureClasses or self.Config.Classes
	)
	self.UI:SetResult(self.Config.Symbol, value)
	self.UI:HighlightStage(nil)
	self.UI:SetPrompt(string.format("Готово: %s = %.2f", self.Config.Symbol, value))

	local nextIndex = self.NodeIndex + 1
	task.delay(1.1, function()
		if not self:_tokenIsCurrent(token) then
			return
		end
		if self.TaskNodes[nextIndex] then
			self:_beginNode(nextIndex, token)
		else
			self:_setHighlightedNode(nil)
			self.UI:SetPrompt("Готово! Значения рассчитаны для трёх узлов.")
			self.UI:SetCounter(0)
			task.delay(1.1, function()
				if self:_tokenIsCurrent(token) then
					self.CompleteRemote:FireServer(self.Config.Sublevel)
				end
			end)
		end
	end)
end

function Runner:_finishStage(token)
	if not self:_tokenIsCurrent(token) or not self.CurrentStage or not self.CurrentNode then
		return
	end
	self.Transitioning = true
	self.UI:SetCounter(self.Goal, self.Goal, true)
	if self.CurrentStage.ClassName then
		self.UI:SetClassValue(self.CurrentStage.ClassName, self.Goal)
	else
		self.UI:SetTotalValue(#self.CurrentNode.Objects)
	end
	task.delay(0.5, function()
		if not self:_tokenIsCurrent(token) then
			return
		end
		self.Transitioning = false
		if self.Stages[self.StageIndex + 1] then
			self:_beginStage(self.StageIndex + 1, token)
		else
			self:_finishNode(token)
		end
	end)
end

function Runner:_beginStage(index, token)
	if not self:_tokenIsCurrent(token) or not self.CurrentNode then
		return
	end
	self.StageIndex = index
	self.CurrentStage = self.Stages[index]
	self.Selected = {}
	self.CurrentCount = 0
	self.Transitioning = false

	if self.CurrentStage.ClassName then
		self.Goal = self.CurrentNode.Counts[self.CurrentStage.ClassName] or 0
	else
		self.Goal = #self.CurrentNode.Objects
	end

	self.UI:SetPrompt(self.CurrentStage.Prompt .. " — " .. self.CurrentNode.Title)
	self.UI:SetCounter(0, self.Goal)
	self.UI:HighlightStage(self.CurrentStage.ClassName or "TOTAL")

	if self.Goal == 0 then
		self.Transitioning = true
		task.delay(0.65, function()
			if self:_tokenIsCurrent(token) and self.CurrentStage == self.Stages[index] then
				self:_finishStage(token)
			end
		end)
	end
end

function Runner:_beginNode(index, token)
	if not self:_tokenIsCurrent(token) then
		return
	end
	self.NodeIndex = index
	self.CurrentNode = self.TaskNodes[index]
	self.CurrentNode.Objects = self:_getObjects(self.CurrentNode.SourceNode)
	self.CurrentNode.Counts = self:_countClasses(self.CurrentNode.Objects)
	self:_setHighlightedNode(self.CurrentNode)
	self.UI:SetTitle(self.Config.Title .. ": " .. self.CurrentNode.Title)
	self.UI:SetResult(self.Config.Symbol, nil)
	self.UI:ResetFormula()
	self:_beginStage(1, token)
end

function Runner:_startTask()
	if not self.Active or not self:_isActive() then
		return
	end
	self.RunToken += 1
	local token = self.RunToken
	self.Started = true
	self.Stages = {}
	for _, className in ipairs(self.Config.Classes) do
		table.insert(self.Stages, {
			ClassName = className,
			Prompt = "Посчитайте объекты класса " .. className,
		})
	end
	table.insert(self.Stages, {
		ClassName = nil,
		Prompt = "Посчитайте все объекты в коробке",
	})
	self:_refreshCompletedResults()
	self:_showAllObjects()
	self.UI:ShowTask()
	self:_beginNode(1, token)
end

function Runner:_startLevel()
	self.Active = true
	self.Started = false
	self.RunToken += 1
	self.UI:SetEnabled(true)
	if self.Config.ShowIntro then
		self.UI:ShowIntro(
			self.Config.IntroTitle,
			self.Config.IntroBody,
			self.Config.Formula,
			function()
				self:_startTask()
			end
		)
	else
		self:_startTask()
	end
end

function Runner:_stopLevel()
	self.RunToken += 1
	self.Active = false
	self.Started = false
	self.CurrentNode = nil
	self.CurrentStage = nil
	self.Selected = {}
	self.Transitioning = false
	self:_setHighlightedNode(nil)
	self.UI:SetEnabled(false)
	self:_refreshCompletedResults()
end

function Runner:_refreshActivation()
	local nowActive = self:_isActive()
	if nowActive and not self.Active then
		self:_startLevel()
	elseif not nowActive and self.Active then
		self:_stopLevel()
	end
end

function Runner:_onClick()
	if not self.Active or not self.Started or self.Transitioning or not self.CurrentNode or not self.CurrentStage then
		return
	end
	local part = self.Mouse.Target
	if not part
		or not part:IsA("BasePart")
		or part:GetAttribute("DT_IsDataObject") ~= true
		or part:GetAttribute("DT_SourceNode") ~= self.CurrentNode.SourceNode
		or self.Selected[part]
	then
		return
	end
	if self.CurrentStage.ClassName and part:GetAttribute("DT_Class") ~= self.CurrentStage.ClassName then
		return
	end

	self.Selected[part] = true
	self.CurrentCount += 1
	self.UI:SetCounter(self.CurrentCount, self.Goal, self.CurrentCount >= self.Goal)
	if self.CurrentStage.ClassName then
		self.UI:SetClassValue(self.CurrentStage.ClassName, self.CurrentCount)
	else
		self.UI:SetTotalValue(self.CurrentCount)
	end
	if self.CurrentCount >= self.Goal then
		self.Transitioning = true
		local token = self.RunToken
		task.delay(0.25, function()
			self:_finishStage(token)
		end)
	end
end

function Runner:_connect()
	self.Mouse.Button1Down:Connect(function()
		self:_onClick()
	end)
	self.Player:GetAttributeChangedSignal("TreeLevelInside"):Connect(function()
		self:_refreshActivation()
		self:_refreshCompletedResults()
	end)
	self.Player:GetAttributeChangedSignal("TreeLevelActiveSublevel"):Connect(function()
		self:_refreshActivation()
		self:_refreshCompletedResults()
	end)
	self.Player:GetAttributeChangedSignal("TreeLevelProgress"):Connect(function()
		self:_refreshCompletedResults()
	end)
	RunService.RenderStepped:Connect(function()
		if self.Active and self.Started and self:_isActive() then
			self:_showAllObjects()
		end
	end)
end

return Runner
