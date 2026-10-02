local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("DBSCAN_Config"))
local Remotes = ReplicatedStorage:WaitForChild("DBSCAN_Remotes")

-- ========== State ==========
local dbscanLevel = Workspace:WaitForChild("DBSCANLevel", 10)
local beesFolder = dbscanLevel and dbscanLevel:WaitForChild("Bees", 5)
if not beesFolder then
	warn("[BeeManager] DBSCANLevel/Bees folder not found!")
	return
end

local clusters = {}          -- { [id] = { id, color, name, coreBees={}, borderBees={} } }
local nextClusterId = 1
local analyzedBees = {}      -- { [beeId] = true } -- bees the player has analyzed at least once
local noiseSentBees = {}    -- { [beeId] = true }
local eduPanelsShown = {}    -- track which educational panels have been shown

-- ========== Helpers ==========

local function getBeeById(id)
	for _, bee in beesFolder:GetChildren() do
		if bee:IsA("BasePart") and bee:GetAttribute("BeeId") == id then
			return bee
		end
	end
	return nil
end

local function getAllBees()
	local list = {}
	for _, bee in beesFolder:GetChildren() do
		if bee:IsA("BasePart") and bee:GetAttribute("BeeId") then
			table.insert(list, bee)
		end
	end
	return list
end

local function getBeeState(bee)
	return bee:GetAttribute("BeeState") or "Unassigned"
end

local function setBeeState(bee, state, clusterId)
	bee:SetAttribute("BeeState", state)
	if clusterId ~= nil then
		bee:SetAttribute("ClusterId", clusterId)
	end
	Remotes.BeeStateUpdate:FireAllClients(bee:GetAttribute("BeeId"), state, clusterId or bee:GetAttribute("ClusterId"))
end

-- 2D distance (X and Z only) between two bee positions
local function distance2D(pos1, pos2)
	local dx = pos1.X - pos2.X
	local dz = pos1.Z - pos2.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Find all bees within epsilon of the given bee (excluding itself)
local function findNeighbors(bee, epsilon)
	local beeType = bee:GetAttribute("BeeType")
	local pos = bee.Position
	local neighbors = {}
	local similarNeighbors = {}
	
	for _, other in ipairs(getAllBees()) do
		if other ~= bee and getBeeState(other) ~= "Sent" then
			local dist = distance2D(pos, other.Position)
			if dist <= epsilon then
				table.insert(neighbors, other)
				if other:GetAttribute("BeeType") == beeType then
					table.insert(similarNeighbors, other)
				end
			end
		end
	end
	
	return neighbors, similarNeighbors
end

-- Check if a bee is a Core point: has >= MinPts similar neighbors within epsilon
local function isCore(bee, epsilon)
	local _, similarNeighbors = findNeighbors(bee, epsilon)
	return #similarNeighbors >= Config.MIN_PTS, #similarNeighbors
end

-- Get serializable info about a list of bees for client
local function serializeBees(beeList)
	local result = {}
	for _, bee in ipairs(beeList) do
		table.insert(result, {
			id = bee:GetAttribute("BeeId"),
			type = bee:GetAttribute("BeeType"),
			typeName = bee:GetAttribute("BeeTypeName"),
			position = { bee.Position.X, bee.Position.Y, bee.Position.Z },
		})
	end
	return result
end

-- ========== Educational Panel Trigger ==========
local function showEduPanel(panelId)
	if eduPanelsShown[panelId] then return end
	eduPanelsShown[panelId] = true
	Remotes.ShowEduPanel:FireAllClients(panelId)
end

-- ========== Analyze Bee (client clicked a bee) ==========
local function onAnalyzeBee(player, beeId, _, clientEpsilon)
	local bee = getBeeById(beeId)
	if not bee then return end
	if getBeeState(bee) == "Sent" then return end
	
	local epsilon = clientEpsilon or Config.DEFAULT_EPSILON
	if type(epsilon) ~= "number" then epsilon = Config.DEFAULT_EPSILON end
	epsilon = math.clamp(epsilon, Config.EPSILON_MIN, Config.EPSILON_MAX)
	local beeType = bee:GetAttribute("BeeType")
	local neighbors, similarNeighbors = findNeighbors(bee, epsilon)
	local isCoreBee, similarCount = isCore(bee, epsilon)
	
	-- Mark as analyzed
	analyzedBees[beeId] = true
	
	-- Show first-time educational panel
	showEduPanel("intro")
	
	-- Serialize neighbor info for client
	local neighborInfo = {}
	for _, n in ipairs(neighbors) do
		table.insert(neighborInfo, {
			id = n:GetAttribute("BeeId"),
			type = n:GetAttribute("BeeType"),
			typeName = n:GetAttribute("BeeTypeName"),
			distance = distance2D(bee.Position, n.Position),
			isSimilar = (n:GetAttribute("BeeType") == beeType),
			position = { n.Position.X, n.Position.Y, n.Position.Z },
		})
	end
	
	-- Send analysis result to client
	Remotes.BeeAnalysisResult:FireClient(player, {
		beeId = beeId,
		beeType = beeType,
		typeName = bee:GetAttribute("BeeTypeName"),
		epsilon = epsilon,
		totalNeighbors = #neighbors,
		similarNeighbors = similarCount,
		isCore = isCoreBee,
		currentState = getBeeState(bee),
		clusterId = bee:GetAttribute("ClusterId"),
		neighbors = neighborInfo,
		beePosition = { bee.Position.X, bee.Position.Y, bee.Position.Z },
	})
end

-- ========== Create a new cluster from a Core bee ==========
local function createCluster(coreBee, epsilon, player)
	local clusterId = nextClusterId
	nextClusterId += 1
	local color = Config.CLUSTER_COLORS[(clusterId - 1) % #Config.CLUSTER_COLORS + 1]
	
	local cluster = {
		id = clusterId,
		color = color,
		name = "Кластер " .. clusterId,
		coreBees = {},
		borderBees = {},
	}
	clusters[clusterId] = cluster
	
	-- Mark the core bee
	setBeeState(coreBee, "Core", clusterId)
	table.insert(cluster.coreBees, coreBee)
	
	-- Show Core educational panel
	showEduPanel("core")
	
	-- Expand: check neighbors of this core
	local neighbors = findNeighbors(coreBee, epsilon)
	local expandedBees = { coreBee }
	
	for _, neighbor in ipairs(neighbors) do
		local nState = getBeeState(neighbor)
		if nState == "Unassigned" or nState == "Noise" then
			-- Only consider similar bees for cluster membership
			if neighbor:GetAttribute("BeeType") == coreBee:GetAttribute("BeeType") then
				local nIsCore, nSimilarCount = isCore(neighbor, epsilon)
				if nIsCore then
					-- Also a core - add to cluster and expand from it too
					setBeeState(neighbor, "Core", clusterId)
					if not table.find(cluster.coreBees, neighbor) then
						table.insert(cluster.coreBees, neighbor)
					end
					table.insert(expandedBees, neighbor)
				else
					-- Border bee (same type, in range of Core, but not Core itself)
					setBeeState(neighbor, "Border", clusterId)
					if not table.find(cluster.borderBees, neighbor) then
						table.insert(cluster.borderBees, neighbor)
					end
					showEduPanel("border")
				end
			end
		end
	end
	
	-- Recursively expand from newly found core bees
	local function expandFromCores(coresToCheck, depth)
		if depth > 10 then return end -- safety limit
		local newCores = {}
		for _, core in ipairs(coresToCheck) do
			local coreNeighbors = findNeighbors(core, epsilon)
			for _, n in ipairs(coreNeighbors) do
				local nState = getBeeState(n)
				if nState == "Unassigned" or nState == "Noise" then
					if n:GetAttribute("BeeType") == coreBee:GetAttribute("BeeType") then
						local nIsCore = isCore(n, epsilon)
						if nIsCore then
							setBeeState(n, "Core", clusterId)
							if not table.find(cluster.coreBees, n) then
								table.insert(cluster.coreBees, n)
							end
							table.insert(expandedBees, n)
							table.insert(newCores, n)
						else
							setBeeState(n, "Border", clusterId)
							if not table.find(cluster.borderBees, n) then
								table.insert(cluster.borderBees, n)
							end
						end
					end
				end
			end
			end
		if #newCores > 0 then
			expandFromCores(newCores, depth + 1)
		end
	end
	
	-- Find the newly added cores (excluding the original)
	local newCores = {}
	for i = 2, #expandedBees do
		if getBeeState(expandedBees[i]) == "Core" then
			table.insert(newCores, expandedBees[i])
		end
	end
	if #newCores > 0 then
		expandFromCores(newCores, 1)
	end
	
	-- Notify all clients
	local clusterInfo = {
		id = clusterId,
		color = color,
		name = cluster.name,
		coreBeeIds = {},
		borderBeeIds = {},
	}
	for _, b in ipairs(cluster.coreBees) do
		table.insert(clusterInfo.coreBeeIds, b:GetAttribute("BeeId"))
	end
	for _, b in ipairs(cluster.borderBees) do
		table.insert(clusterInfo.borderBeeIds, b:GetAttribute("BeeId"))
	end
	
	Remotes.ClusterCreated:FireAllClients(clusterInfo)
	
	return cluster
end

-- ========== Handle marking a bee as Noise ==========
local function onSendNoiseBee(player, beeId)
	local bee = getBeeById(beeId)
	if not bee then return end
	
	local state = getBeeState(bee)
	-- Only allow sending bees that are Unassigned or already marked Noise
	if state == "Core" or state == "Border" then
		return -- Can't send clustered bees
	end
	if state == "Sent" then return end
	
	-- Mark as noise if not already
	if state ~= "Noise" then
		setBeeState(bee, "Noise", -1)
	end
	
	showEduPanel("noise")
	
	-- Animate: tween bee to hive
	local hivePos = Config.HIVE_POSITION
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(bee, tweenInfo, { Position = hivePos })
	
	-- Make bee non-interactive during flight
	bee.CanCollide = false
	local cd = bee:FindFirstChild("BeeClick")
	if cd then cd.MaxActivationDistance = 0 end
	
	tween:Play()
	tween.Completed:Connect(function()
		setBeeState(bee, "Sent", -1)
		noiseSentBees[beeId] = true
		Remotes.NoiseSent:FireAllClients(beeId)
	end)
end

-- ========== Check Level Completion ==========
local function onCheckComplete(player)
	local allBees = getAllBees()
	local unassignedCount = 0
	local noiseCount = 0
	local sentCount = 0
	local coreCount = 0
	local borderCount = 0
	local complete = true
	
	for _, bee in ipairs(allBees) do
		local state = getBeeState(bee)
		if state == "Unassigned" then
			unassignedCount += 1
			complete = false
		elseif state == "Noise" then
			noiseCount += 1
			complete = false -- noise bees must be sent, not just marked
		elseif state == "Sent" then
			sentCount += 1
		elseif state == "Core" then
			coreCount += 1
		elseif state == "Border" then
			borderCount += 1
		end
	end
	
	Remotes.LevelComplete:FireClient(player, {
		complete = complete,
		clustersFound = #clusters,
		coreCount = coreCount,
		borderCount = borderCount,
		noiseSent = sentCount,
		unassigned = unassignedCount,
		noiseNotSent = noiseCount,
	})
end

-- ========== Name Cluster ==========
local function onNameCluster(player, clusterId, name)
	local cluster = clusters[clusterId]
	if cluster and name and #name > 0 and #name <= 30 then
		cluster.name = name
		Remotes.ClusterNamed:FireAllClients(clusterId, name)
	end
end

-- ========== Reset Level ==========
local function onResetLevel(player)
	-- Reset all state
	clusters = {}
	nextClusterId = 1
	analyzedBees = {}
	noiseSentBees = {}
	eduPanelsShown = {}
	
	-- Reset all bees
	for _, bee in ipairs(getAllBees()) do
		-- Restore original position from stored attributes
		local origX = bee:GetAttribute("OriginalPosX")
		local origY = bee:GetAttribute("OriginalPosY")
		local origZ = bee:GetAttribute("OriginalPosZ")
		if origX and origY and origZ then
			bee.Position = Vector3.new(origX, origY, origZ)
		end
		bee:SetAttribute("BeeState", "Unassigned")
		bee:SetAttribute("ClusterId", -1)
		local cd = bee:FindFirstChild("BeeClick")
		if cd then cd.MaxActivationDistance = 30 end
	end
	
	Remotes.LevelReset:FireAllClients()
end

-- ========== Remote Connections ==========
Remotes.AnalyzeBee.OnServerEvent:Connect(onAnalyzeBee)
Remotes.SendNoiseBee.OnServerEvent:Connect(onSendNoiseBee)
Remotes.CheckComplete.OnServerEvent:Connect(onCheckComplete)
Remotes.NameCluster.OnServerEvent:Connect(onNameCluster)
Remotes.ResetLevel.OnServerEvent:Connect(onResetLevel)

-- ========== Auto-expand when a Core is found via analysis ==========
-- We need to handle the case where the player analyzes a Core bee and it should create a cluster
Remotes.AnalyzeBee.OnServerEvent:Connect(function(player, beeId, action, clientEpsilon)
	-- This second connection handles the "confirm cluster" action
	-- The client sends action = "confirm" when the player wants to create a cluster from a Core bee
	if action == "confirm" then
		local bee = getBeeById(beeId)
		if not bee then return end
		if getBeeState(bee) == "Unassigned" or getBeeState(bee) == "Noise" then
			local eps = clientEpsilon or Config.DEFAULT_EPSILON
			if type(eps) ~= "number" then eps = Config.DEFAULT_EPSILON end
			eps = math.clamp(eps, Config.EPSILON_MIN, Config.EPSILON_MAX)
			local isCoreBee = isCore(bee, eps)
			if isCoreBee then
				createCluster(bee, eps, player)
			end
		end
	end
end)

print("[BeeManager] DBSCAN Bee Manager initialized with " .. #getAllBees() .. " bees")

-- Also store original positions on each bee for reset
for _, bee in ipairs(getAllBees()) do
	bee:SetAttribute("OriginalPosX", bee.Position.X)
	bee:SetAttribute("OriginalPosY", bee.Position.Y)
	bee:SetAttribute("OriginalPosZ", bee.Position.Z)
end