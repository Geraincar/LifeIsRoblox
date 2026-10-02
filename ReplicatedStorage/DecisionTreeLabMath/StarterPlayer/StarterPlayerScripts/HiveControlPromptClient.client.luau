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


local openRemote =
	ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild(
			"HiveControlPromptOpen"
		)



--------------------------------------------------
-- OPEN HIVE CONTROL
--------------------------------------------------

local function openHive()

	local gui =
		playerGui:FindFirstChild(
			"HiveControlUI"
		)


	if not gui then

		warn(
			"[HiveControl] HiveControlUI missing"
		)

		return

	end


	local overlay =
		gui:FindFirstChild(
			"Overlay"
		)


	if not overlay then
		return
	end


	--------------------------------
	-- Close old prototype panels
	-- if they happen to be open.
	--------------------------------

	local mainUI =
		playerGui:FindFirstChild(
			"MainUI"
		)


	if mainUI then

		local data =
			mainUI:FindFirstChild(
				"DataPanel"
			)


		if data
			and data:IsA(
				"GuiObject"
			)
		then

			data.Visible =
				false

		end


		local lesson =
			mainUI:FindFirstChild(
				"WorldLessonPanel"
			)


		if lesson
			and lesson:IsA(
				"GuiObject"
			)
		then

			lesson.Visible =
				false

		end

	end


	--------------------------------
	-- Remove stale impact message
	-- when opened manually.
	--------------------------------

	local window =
		overlay:FindFirstChild(
			"Window"
		)


	if window then

		local impact =
			window:FindFirstChild(
				"ImpactLabel"
			)


		if impact then

			impact.Text =
				""

		end

	end


	overlay.Visible =
		true


	print(
		"[HiveControl] Opened from hive"
	)

end



openRemote.OnClientEvent:Connect(
	openHive
)
