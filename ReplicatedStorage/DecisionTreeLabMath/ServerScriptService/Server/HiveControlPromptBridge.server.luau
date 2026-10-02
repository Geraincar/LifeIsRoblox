local Players =
	game:GetService("Players")


local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local Workspace =
	game:GetService("Workspace")


local openRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"HiveControlPromptOpen"
		)



--------------------------------------------------
-- FIND HIVE
--------------------------------------------------

local function looksLikeHive(
	object
)

	local name =
		string.lower(
			object.Name
		)


	return
		name == "hive"
		or name == "beehive"
		or name == "улей"
		or string.find(
			name,
			"hive",
			1,
			true
		) ~= nil

end



local function findHive()

	--------------------------------
	-- Best case: exact Hive object
	--------------------------------

	local exact =
		Workspace:FindFirstChild(
			"Hive"
		)


	if exact then
		return exact
	end


	--------------------------------
	-- Search recursively
	--------------------------------

	for _, object in ipairs(
		Workspace:GetDescendants()
	) do

		if looksLikeHive(
			object
		) then

			if object:IsA("Model")
				or object:IsA("BasePart")
				or object:IsA("Folder")
			then

				return object

			end

		end

	end


	return nil

end



--------------------------------------------------
-- FIND A PART FOR A NEW PROMPT
--------------------------------------------------

local function findPart(
	hive
)

	if hive:IsA("BasePart") then
		return hive
	end


	if hive:IsA("Model") then

		if hive.PrimaryPart then
			return hive.PrimaryPart
		end

	end


	for _, object in ipairs(
		hive:GetDescendants()
	) do

		if object:IsA(
			"BasePart"
		) then

			return object

		end

	end


	return nil

end



--------------------------------------------------
-- BIND PROMPT
--------------------------------------------------

local bound = {}


local function bindPrompt(
	prompt
)

	if bound[prompt] then
		return
	end


	bound[prompt] =
		true


	--------------------------------
	-- Russian player-facing text
	--------------------------------

	prompt.ActionText =
		"Открыть управление"


	prompt.ObjectText =
		"Улей"


	prompt.KeyboardKeyCode =
		Enum.KeyCode.E


	prompt.HoldDuration =
		0


	prompt.MaxActivationDistance =
		math.max(
			prompt.MaxActivationDistance,
			12
		)


	prompt.RequiresLineOfSight =
		false


	prompt.Enabled =
		true


	prompt.Triggered:Connect(
		function(player)

			if not player
				or player.Parent
					~= Players
			then

				return

			end


			print(
				"[HiveControl] Hive prompt:",
				player.Name
			)


			openRemote:FireClient(
				player
			)

		end
	)


	print(
		"[HiveControl] Bound prompt:",
		prompt:GetFullName()
	)

end



--------------------------------------------------
-- SETUP
--------------------------------------------------

local hive =
	findHive()


if not hive then

	warn(
		"[HiveControl] Hive object not found"
	)


	--------------------------------
	-- Fallback:
	-- use old DataConsolePrompt if present
	--------------------------------

	for _, object in ipairs(
		Workspace:GetDescendants()
	) do

		if object:IsA(
			"ProximityPrompt"
		)
			and object.Name
				== "DataConsolePrompt"
		then

			bindPrompt(
				object
			)

		end

	end


	return

end


print(
	"[HiveControl] Hive found:",
	hive:GetFullName()
)



--------------------------------------------------
-- USE EXISTING HIVE PROMPTS
--------------------------------------------------

local prompts = {}


for _, object in ipairs(
	hive:GetDescendants()
) do

	if object:IsA(
		"ProximityPrompt"
	) then

		table.insert(
			prompts,
			object
		)

	end

end



--------------------------------------------------
-- IF THERE IS NO PROMPT, CREATE ONE
--------------------------------------------------

if #prompts == 0 then

	local part =
		findPart(
			hive
		)


	if not part then

		warn(
			"[HiveControl] Could not find BasePart inside hive"
		)

		return

	end


	local prompt =
		Instance.new(
			"ProximityPrompt"
		)


	prompt.Name =
		"HiveControlPrompt"


	prompt.Parent =
		part


	table.insert(
		prompts,
		prompt
	)


	print(
		"[HiveControl] Created new prompt on:",
		part:GetFullName()
	)

end



--------------------------------------------------
-- BIND EVERYTHING ALREADY IN THE HIVE
--------------------------------------------------

for _, prompt in ipairs(
	prompts
) do

	bindPrompt(
		prompt
	)

end



--------------------------------------------------
-- ALSO HANDLE PROMPTS CREATED LATER
--------------------------------------------------

hive.DescendantAdded:Connect(
	function(object)

		if object:IsA(
			"ProximityPrompt"
		) then

			task.defer(
				function()

					bindPrompt(
						object
					)

				end
			)

		end

	end
)


print(
	"[HiveControl] World interaction ready"
)
