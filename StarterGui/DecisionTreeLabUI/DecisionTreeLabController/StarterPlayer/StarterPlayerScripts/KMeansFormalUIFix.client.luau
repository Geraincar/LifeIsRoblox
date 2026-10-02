
local Players =
	game:GetService("Players")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


-- ============================================================
-- HELPERS
-- ============================================================

local function findTextObject(
	parent,
	test
)

	for _, object in ipairs(
		parent:GetDescendants()
	) do

		if
			(
				object:IsA("TextLabel")
				or
				object:IsA("TextButton")
			)
			and test(object)
		then

			return object

		end

	end

	return nil
end


local function startsWith(text, prefix)

	return
		string.sub(
			text,
			1,
			#prefix
		)
		==
		prefix

end


-- ============================================================
-- PATCH FORMAL PANEL
-- ============================================================

local function patchFormalPanel(hud)

	local formal =
		hud:FindFirstChild(
			"FormalPanel",
			true
		)

	if not formal
		or not formal:IsA("Frame")
	then

		warn(
			"[KMeansFormalUI] FormalPanel not found"
		)

		return
	end


	-- ========================================================
	-- MAIN PANEL
	-- ========================================================

	formal.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	formal.Position =
		UDim2.fromScale(
			0.5,
			0.53
		)

	formal.Size =
		UDim2.fromOffset(
			820,
			500
		)


	-- ========================================================
	-- HEADER
	-- ========================================================

	local header =
		findTextObject(
			formal,

			function(object)

				return
					object:IsA("TextLabel")
					and
					string.find(
						object.Text,
						"K-MEANS",
						1,
						true
					)
					~= nil

			end
		)


	if header then

		header.Position =
			UDim2.fromOffset(
				28,
				18
			)

		header.Size =
			UDim2.new(
				1,
				-56,
				0,
				34
			)

		header.TextSize =
			25

	end


	-- ========================================================
	-- PAGE TITLE
	-- ========================================================

	local pageTitle =
		findTextObject(
			formal,

			function(object)

				if not object:IsA("TextLabel") then
					return false
				end

				return
					string.find(
						object.Text,
						"Assignment step",
						1,
						true
					)
					or
					string.find(
						object.Text,
						"Update step",
						1,
						true
					)
					or
					string.find(
						object.Text,
						"Objective",
						1,
						true
					)

			end
		)


	if pageTitle then

		pageTitle.Position =
			UDim2.fromOffset(
				28,
				66
			)

		pageTitle.Size =
			UDim2.new(
				1,
				-56,
				0,
				32
			)

		pageTitle.TextSize =
			20

	end


	-- ========================================================
	-- FORMULA
	-- ========================================================

	local formula =
		findTextObject(
			formal,

			function(object)

				if not object:IsA("TextLabel") then
					return false
				end

				return
					string.find(
						object.Text,
						"argmin",
						1,
						true
					)
					or
					string.find(
						object.Text,
						"μ",
						1,
						true
					)
					or
					string.find(
						object.Text,
						"Σ",
						1,
						true
					)

			end
		)


	if formula then

		formula.Position =
			UDim2.fromOffset(
				28,
				112
			)

		formula.Size =
			UDim2.new(
				1,
				-56,
				0,
				58
			)

		formula.TextSize =
			27

		formula.TextXAlignment =
			Enum.TextXAlignment.Center

	end


	-- ========================================================
	-- BODY TEXT
	-- ========================================================

	local body =
		findTextObject(
			formal,

			function(object)

				if not object:IsA("TextLabel") then
					return false
				end

				return
					string.find(
						object.Text,
						"Для каждой точки",
						1,
						true
					)
					or
					string.find(
						object.Text,
						"После assignment",
						1,
						true
					)
					or
					string.find(
						object.Text,
						"K-means повторяет",
						1,
						true
					)

			end
		)


	if body then

		body.Position =
			UDim2.fromOffset(
				36,
				183
			)

		body.Size =
			UDim2.new(
				1,
				-72,
				0,
				92
			)

		body.TextSize =
			17

		body.TextYAlignment =
			Enum.TextYAlignment.Top

	end


	-- ========================================================
	-- PYTHON CODE BLOCK
	-- ========================================================

	local code =
		findTextObject(
			formal,

			function(object)

				if not object:IsA("TextLabel") then
					return false
				end

				return
					string.find(
						object.Text,
						"sklearn",
						1,
						true
					)
					~= nil

			end
		)


	-- Code is empty on pages 1 and 2 when the patch runs,
	-- so if not found by content, find the Code-font label.

	if not code then

		for _, object in ipairs(
			formal:GetDescendants()
		) do

			if
				object:IsA("TextLabel")
				and
				object.Font == Enum.Font.Code
			then

				code =
					object

				break

			end

		end

	end


	if code then

		code.Position =
			UDim2.fromOffset(
				36,
				286
			)

		code.Size =
			UDim2.new(
				1,
				-72,
				0,
				125
			)

		code.TextSize =
			15

		code.TextYAlignment =
			Enum.TextYAlignment.Top

	end


	-- ========================================================
	-- CLOSE BUTTON
	-- ========================================================

	local close =
		findTextObject(
			formal,

			function(object)

				return
					object:IsA("TextButton")
					and
					object.Text == "Закрыть"

			end
		)


	if close then

		close.AnchorPoint =
			Vector2.new(
				0,
				0
			)

		close.Position =
			UDim2.fromOffset(
				28,
				435
			)

		close.Size =
			UDim2.fromOffset(
				125,
				44
			)

		close.TextSize =
			16

	end


	-- ========================================================
	-- NEXT BUTTON
	-- ========================================================

	local nextButton =
		findTextObject(
			formal,

			function(object)

				return
					object:IsA("TextButton")
					and
					(
						object.Text == "Дальше"
						or
						object.Text == "Готово"
					)

			end
		)


	if nextButton then

		nextButton.AnchorPoint =
			Vector2.new(
				1,
				0
			)

		nextButton.Position =
			UDim2.new(
				1,
				-28,
				0,
				435
			)

		nextButton.Size =
			UDim2.fromOffset(
				165,
				44
			)

		nextButton.TextSize =
			17

	end


	print(
		"[KMeansFormalUI] Formal UI patched"
	)

end


-- ============================================================
-- APPLY WHEN HUD EXISTS
-- ============================================================

local patched = {}


local function patchHud(hud)

	if patched[hud] then
		return
	end

	patched[hud] =
		true


	task.wait()


	patchFormalPanel(
		hud
	)

end


local current =
	playerGui:FindFirstChild(
		"KMeansHUD"
	)


if current then

	task.defer(
		patchHud,
		current
	)

end


playerGui.ChildAdded:Connect(
	function(child)

		if child.Name
			==
			"KMeansHUD"
		then

			task.delay(
				0.05,
				patchHud,
				child
			)

		end

	end
)

