local Players =
	game:GetService("Players")

local DataStoreService =
	game:GetService("DataStoreService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local MAX_SUBLEVEL =
	4

local CHECK_INTERVAL =
	0.15

--------------------------------------------------
-- ZONE
--------------------------------------------------

local zone =
	workspace:FindFirstChild(
		"TreeLevelZone",
		true
	)

if not zone then

	error(
		"[TreeLevel] TreeLevelZone was not found"
	)

end

if not zone:IsA("BasePart") then

	error(
		"[TreeLevel] TreeLevelZone must be a BasePart"
	)

end

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage
	:WaitForChild("Remotes")

local completeRemote =
	remotes
	:WaitForChild(
		"TreeSublevelCompleted"
	)

local debugProgressRemote =
	remotes
	:WaitForChild(
		"TreeLevelDebugChangeProgress"
	)

--------------------------------------------------
-- NAVIGATION REMOTE
--------------------------------------------------

local navigateRemote =
	remotes:FindFirstChild(
		"TreeLevelNavigate"
	)

if not navigateRemote then

	navigateRemote =
		Instance.new(
			"RemoteFunction"
		)

	navigateRemote.Name =
		"TreeLevelNavigate"

	navigateRemote.Parent =
		remotes

end

if not navigateRemote:IsA(
	"RemoteFunction"
	)
then

	error(
		"[TreeLevel] TreeLevelNavigate must be RemoteFunction"
	)

end

--------------------------------------------------
-- DATASTORE
--------------------------------------------------

local progressStore =
	DataStoreService:GetDataStore(
		"TreeLevelProgress_v1"
	)

--------------------------------------------------
-- RUNTIME
--------------------------------------------------

local progress = {}
local insideZone = {}
local activeSublevel = {}
local loaded = {}
local lastSaved = {}

--------------------------------------------------
-- REPLAY STATE
--------------------------------------------------

local replayReturn = {}
local replayRestartTarget = {}
local replayToken = {}

--------------------------------------------------
-- KEY
--------------------------------------------------

local function getKey(player)

	return
		"player_"
		.. player.UserId

end

--------------------------------------------------
-- SAVE
--------------------------------------------------

local function saveValue(
	player,
	value
)

	local success, savedValue =
		pcall(function()

			return
			progressStore:UpdateAsync(

				getKey(player),

				function(oldValue)

					oldValue =
					tonumber(
						oldValue
					) or 0

					oldValue =
					math.clamp(
						math.floor(
							oldValue
						),
						0,
						MAX_SUBLEVEL
					)

					return
					math.max(
						oldValue,
						value
					)

				end
			)

		end)

	if success then

		lastSaved[player] =
			tonumber(
				savedValue
			) or value

	else

		warn(
			"[TreeLevel] Could not save:",
			player.Name,
			savedValue
		)

	end

	return success
end

--------------------------------------------------
-- DEBUG SAVE
--------------------------------------------------

local function saveDebugValue(
	player,
	value
)

	if not RunService:IsStudio() then
		return false
	end

	value =
		math.clamp(
			math.floor(
				value
			),
			0,
			MAX_SUBLEVEL
		)

	local success, err =
		pcall(function()

			progressStore:SetAsync(
				getKey(player),
				value
			)

		end)

	if not success then

		warn(
			"[TreeLevelDebug]",
			err
		)

		return false
	end

	lastSaved[player] =
		value

	return true
end

--------------------------------------------------
-- SAVE IF NEEDED
--------------------------------------------------

local function saveIfNeeded(player)

	local value =
		progress[player]

	if value == nil then
		return
	end

	if lastSaved[player] == value then
		return
	end

	task.spawn(
		function()

			saveValue(
				player,
				value
			)

		end
	)

end

--------------------------------------------------
-- CLEAR REPLAY
--------------------------------------------------

local function clearReplay(player)

	replayReturn[player] =
		nil

	replayRestartTarget[player] =
		nil

	player:SetAttribute(
		"TreeLevelReplayReturn",
		0
	)

	player:SetAttribute(
		"TreeLevelReplayRestartTarget",
		0
	)

end

--------------------------------------------------
-- LOAD
--------------------------------------------------

local function loadPlayer(player)

	player:SetAttribute(
		"TreeLevelInside",
		false
	)

	player:SetAttribute(
		"TreeLevelActiveSublevel",
		0
	)

	player:SetAttribute(
		"TreeLevelReplayReturn",
		0
	)

	player:SetAttribute(
		"TreeLevelReplayRestartTarget",
		0
	)

	player:SetAttribute(
		"TreeLevelReplayToken",
		0
	)

	local value =
		0

	local success, savedValue =
		pcall(function()

			return
			progressStore:GetAsync(
				getKey(player)
			)

		end)

	if success then

		value =
			tonumber(
				savedValue
			) or 0

		value =
			math.clamp(
				math.floor(
					value
				),
				0,
				MAX_SUBLEVEL
			)

		lastSaved[player] =
			value

	else

		warn(
			"[TreeLevel] Load failed:",
			player.Name
		)

	end

	progress[player] =
		value

	player:SetAttribute(
		"TreeLevelProgress",
		value
	)

	loaded[player] =
		true

	print(
		"[TreeLevel]",
		player.Name,
		"progress =",
		value
	)

end

--------------------------------------------------
-- INSIDE ZONE?
--------------------------------------------------

local function isPlayerInsideZone(player)

	local character =
		player.Character

	if not character then
		return false
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not humanoid
		or not root
	then

		return false

	end

	if humanoid.Health <= 0 then
		return false
	end

	local localPosition =
		zone.CFrame
		:PointToObjectSpace(
			root.Position
		)

	local halfSize =
		zone.Size * 0.5

	return
		math.abs(
			localPosition.X
		) <= halfSize.X

		and

		math.abs(
			localPosition.Y
		) <= halfSize.Y

		and

		math.abs(
			localPosition.Z
		) <= halfSize.Z

end

--------------------------------------------------
-- START NEXT
--------------------------------------------------

local function startNextSublevel(player)

	local completed =
		progress[player] or 0

	if completed >= MAX_SUBLEVEL then

		activeSublevel[player] =
			nil

		player:SetAttribute(
			"TreeLevelActiveSublevel",
			0
		)

		return
	end

	local nextSublevel =
		completed + 1

	activeSublevel[player] =
		nextSublevel

	player:SetAttribute(
		"TreeLevelActiveSublevel",
		nextSublevel
	)

	print(
		"[TreeLevel] START",
		nextSublevel
	)

end

--------------------------------------------------
-- ENTER
--------------------------------------------------

local function onEnterZone(player)

	insideZone[player] =
		true

	player:SetAttribute(
		"TreeLevelInside",
		true
	)

	startNextSublevel(
		player
	)

end

--------------------------------------------------
-- EXIT
--------------------------------------------------

local function onExitZone(player)

	insideZone[player] =
		false

	activeSublevel[player] =
		nil

	clearReplay(
		player
	)

	player:SetAttribute(
		"TreeLevelInside",
		false
	)

	player:SetAttribute(
		"TreeLevelActiveSublevel",
		0
	)

	saveIfNeeded(
		player
	)

end

--------------------------------------------------
-- PREVIOUS / RESUME REPLAY
--------------------------------------------------

navigateRemote.OnServerInvoke =
	function(
		player,
		action
	)

	if not loaded[player] then

		return {
			Ok = false,
			Error = "Not loaded",
		}

	end

	if insideZone[player] ~= true then

		return {
			Ok = false,
			Error = "Outside level zone",
		}

	end

	--------------------------------------------------
	-- PREVIOUS
	--------------------------------------------------

	if action == "Previous" then

		local current =
			activeSublevel[player]
			or 0

		if current <= 1 then

			return {
				Ok = false,
				Error = "No previous sublevel",
			}

		end

		local target =
			current - 1

		replayReturn[player] =
			current

		replayRestartTarget[player] =
			target

		replayToken[player] =
			(replayToken[player] or 0)
			+ 1

		player:SetAttribute(
			"TreeLevelReplayReturn",
			current
		)

		player:SetAttribute(
			"TreeLevelReplayRestartTarget",
			target
		)

		player:SetAttribute(
			"TreeLevelReplayToken",
			replayToken[player]
		)

		activeSublevel[player] =
			target

		player:SetAttribute(
			"TreeLevelActiveSublevel",
			target
		)

		print(
			"[TreeLevel] PREVIOUS:",
			current,
			"->",
			target
		)

		return {
			Ok = true,
			TargetSublevel = target,
		}

	end

	--------------------------------------------------
	-- FINISHED REPLAY
	--------------------------------------------------

	if action == "ResumeReplay" then

		local returnTo =
			replayReturn[player]

		if not returnTo then

			return {
				Ok = false,
				Error = "No replay active",
			}

		end

		clearReplay(
			player
		)

		activeSublevel[player] =
			returnTo

		player:SetAttribute(
			"TreeLevelActiveSublevel",
			returnTo
		)

		print(
			"[TreeLevel] REPLAY FINISHED ->",
			returnTo
		)

		return {
			Ok = true,
			TargetSublevel = returnTo,
		}

	end

	--------------------------------------------------
	-- NEXT COMPLETED SUBLEVEL
	--------------------------------------------------

	if action == "Next" then

		local current =
			activeSublevel[player]
			or 0

		local completed =
			progress[player]
			or 0

		--------------------------------------------------
		-- The current sublevel must already be completed.
		-- This prevents skipping unfinished content.
		--------------------------------------------------

		if current < 1
			or current > completed
			or current >= MAX_SUBLEVEL
		then

			return {
				Ok = false,
				Error = "Next sublevel is locked",
			}

		end

		local target =
			current + 1

		--------------------------------------------------
		-- If NEXT reaches the sublevel from which replay
		-- started, replay mode is finished normally.
		--------------------------------------------------

		local returnTo =
			replayReturn[player]

		if returnTo
			and target >= returnTo
		then

			clearReplay(
				player
			)

		end

		activeSublevel[player] =
			target

		player:SetAttribute(
			"TreeLevelActiveSublevel",
			target
		)

		print(
			"[TreeLevel] NEXT:",
			current,
			"->",
			target
		)

		return {
			Ok = true,
			TargetSublevel = target,
		}

	end

	return {
		Ok = false,
		Error = "Unknown action",
	}

end

--------------------------------------------------
-- NORMAL COMPLETION
--------------------------------------------------

completeRemote.OnServerEvent:Connect(
	function(
		player,
		sublevelNumber
	)

		if not loaded[player] then
			return
		end

		if insideZone[player] ~= true then
			return
		end

		if type(
			sublevelNumber
			) ~= "number"
		then

			return

		end

		sublevelNumber =
			math.floor(
				sublevelNumber
			)

		--------------------------------------------------
		-- DECISION TREE MUST REALLY BE COMPLETE
		--------------------------------------------------

		if sublevelNumber == 1 then

			if player:GetAttribute(
				"DecisionTreeCompleted"
				) ~= true
			then

				warn(
					"[TreeLevel] Tree completion rejected"
				)

				return

			end
		end

		local completed =
			progress[player] or 0

		local expected =
			completed + 1

		if sublevelNumber ~= expected then

			warn(
				"[TreeLevel] expected",
				expected,
				"got",
				sublevelNumber
			)

			return
		end

		if activeSublevel[player]
			~= expected
		then

			return

		end

		--------------------------------------------------
		-- COMPLETE
		--------------------------------------------------

		progress[player] =
			expected

		player:SetAttribute(
			"TreeLevelProgress",
			expected
		)

		activeSublevel[player] =
			nil

		player:SetAttribute(
			"TreeLevelActiveSublevel",
			0
		)

		print(
			"[TreeLevel] COMPLETED",
			expected
		)

		saveIfNeeded(
			player
		)

		if expected >= MAX_SUBLEVEL then
			return
		end

		--------------------------------------------------
		-- START NEXT AFTER SHORT TRANSITION
		--------------------------------------------------

		task.delay(
			0.5,

			function()

				if player.Parent
					~= Players
				then

					return

				end

				if insideZone[player]
					~= true
				then

					return

				end

				if progress[player]
					~= expected
				then

					return

				end

				startNextSublevel(
					player
				)

			end
		)

	end
)

--------------------------------------------------
-- DEBUG K / L
--------------------------------------------------

debugProgressRemote.OnServerEvent:Connect(
	function(
		player,
		delta
	)

		if not RunService:IsStudio() then
			return
		end

		if not loaded[player] then
			return
		end

		if delta ~= 1
			and delta ~= -1
		then

			return

		end

		local oldProgress =
			progress[player] or 0

		local newProgress =
			math.clamp(
				oldProgress + delta,
				0,
				MAX_SUBLEVEL
			)

		if newProgress == oldProgress then
			return
		end

		if not saveDebugValue(
			player,
			newProgress
			)
		then

			return

		end

		clearReplay(
			player
		)

		progress[player] =
			newProgress

		player:SetAttribute(
			"TreeLevelProgress",
			newProgress
		)

		if insideZone[player] then

			if newProgress >= MAX_SUBLEVEL then

				activeSublevel[player] =
					nil

				player:SetAttribute(
					"TreeLevelActiveSublevel",
					0
				)

			else

				activeSublevel[player] =
					newProgress + 1

				player:SetAttribute(
					"TreeLevelActiveSublevel",
					newProgress + 1
				)

			end

		else

			activeSublevel[player] =
				nil

			player:SetAttribute(
				"TreeLevelActiveSublevel",
				0
			)

		end

	end
)

--------------------------------------------------
-- ZONE LOOP
--------------------------------------------------

task.spawn(
	function()

		while true do

			for _, player
				in ipairs(
					Players:GetPlayers()
				)
			do

				if loaded[player] then

					local nowInside =
						isPlayerInsideZone(
							player
						)

					local wasInside =
						insideZone[player]
						== true

					if nowInside
						and not wasInside
					then

						onEnterZone(
							player
						)

					elseif not nowInside
						and wasInside
					then

						onExitZone(
							player
						)

					end
				end
			end

			task.wait(
				CHECK_INTERVAL
			)

		end

	end
)

--------------------------------------------------
-- PLAYERS
--------------------------------------------------

Players.PlayerAdded:Connect(
	loadPlayer
)

for _, player
	in ipairs(
		Players:GetPlayers()
	)
do

	task.spawn(
		loadPlayer,
		player
	)

end

Players.PlayerRemoving:Connect(
	function(player)

		if progress[player] ~= nil then

			saveValue(
				player,
				progress[player]
			)

		end

		progress[player] =
			nil

		insideZone[player] =
			nil

		activeSublevel[player] =
			nil

		loaded[player] =
			nil

		lastSaved[player] =
			nil

		replayReturn[player] =
			nil

		replayRestartTarget[player] =
			nil

		replayToken[player] =
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

			if progress[player] ~= nil then

				saveValue(
					player,
					progress[player]
				)

			end
		end
	end
)
