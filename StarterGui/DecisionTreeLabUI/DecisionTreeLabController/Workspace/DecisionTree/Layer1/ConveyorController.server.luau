local RunService = game:GetService("RunService")

local tree = script.Parent.Parent
local conveyors = {}
local contacts = {}

local function characterFromPart(part)
	local character = part:FindFirstAncestorOfClass("Model")

	if character
		and character:FindFirstChildOfClass("Humanoid")
	then
		return character
	end

	return nil
end

for _, descendant in tree:GetDescendants() do

	if descendant:IsA("BasePart")
		and descendant:GetAttribute("IsConveyor") == true
	then

		table.insert(
			conveyors,
			descendant
		)

		contacts[descendant] = {}

		descendant.Touched:Connect(
			function(hit)

				local character =
					characterFromPart(hit)

				if not character then
					return
				end

				local characterContacts =
					contacts[descendant][character]

				if not characterContacts then
					characterContacts = {}

					contacts[descendant][character] =
						characterContacts
				end

				characterContacts[hit] = true
			end
		)

		descendant.TouchEnded:Connect(
			function(hit)

				local character =
					characterFromPart(hit)

				if not character then
					return
				end

				local characterContacts =
					contacts[descendant][character]

				if characterContacts then
					characterContacts[hit] = nil

					if next(characterContacts) == nil then
						contacts[descendant][character] = nil
					end
				end
			end
		)
	end
end

RunService.Heartbeat:Connect(
	function()

		local movedCharacters = {}

		for _, conveyor in ipairs(conveyors) do

			local actualTouchingParts = {}

			for _, touchingPart in ipairs(
				conveyor:GetTouchingParts()
			) do

				actualTouchingParts[touchingPart] =
					true

				local character =
					characterFromPart(
						touchingPart
					)

				if character then

					local characterContacts =
						contacts[conveyor][character]

					if not characterContacts then
						characterContacts = {}

						contacts[conveyor][character] =
							characterContacts
					end

					characterContacts[touchingPart] =
						true
				end
			end

			for character, characterContacts
				in pairs(contacts[conveyor])
			do

				for touchingPart
					in pairs(characterContacts)
				do

					if
						not actualTouchingParts[touchingPart]
						or touchingPart.Parent == nil
						or not touchingPart:IsDescendantOf(character)
					then
						characterContacts[touchingPart] = nil
					end
				end

				if
					character.Parent == nil
					or next(characterContacts) == nil
				then

					contacts[conveyor][character] =
						nil

				elseif
					not movedCharacters[character]
				then

					local humanoid =
						character:FindFirstChildOfClass(
							"Humanoid"
						)

					local rootPart =
						character:FindFirstChild(
							"HumanoidRootPart"
						)

					local direction = conveyor.CFrame.LookVector

					local speed =
						conveyor:GetAttribute(
							"ConveyorSpeed"
						)*2

					if
						humanoid
						and humanoid.Health > 0
						and rootPart
						and typeof(direction) == "Vector3"
						and type(speed) == "number"
					then

						local currentVelocity =
							rootPart.AssemblyLinearVelocity

						rootPart.AssemblyLinearVelocity =
							Vector3.new(
								direction.X * speed,
								currentVelocity.Y,
								direction.Z * speed
							)
					end

					movedCharacters[character] =
						true
				end
			end
		end
	end
)
