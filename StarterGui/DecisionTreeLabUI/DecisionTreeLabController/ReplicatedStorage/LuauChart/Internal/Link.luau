--!strict
--!native
--!optimize 2
-- Link (Class): keeps several Cartesian charts panning and zooming together and mirrors the cursor between
-- them, for a price chart with a volume pane underneath. Axes picks which view axes stay in step.

-- ─── Services ────────────────────────────────────────────────────────────────

const GuiService = game:GetService("GuiService")

-- ─── Configuration ───────────────────────────────────────────────────────────

const GuiInset = GuiService:GetGuiInset()
const X_DRIVERS = { "ViewXMin", "ViewXMax" }
const Y_DRIVERS = { "ViewYMin", "ViewYMax" }

-- ─── Types ───────────────────────────────────────────────────────────────────

export type Options = {
	Cursor: boolean?, -- mirror hover positions across the charts by their X fraction; default true
	Axes: { X: boolean?, Y: boolean? }?, -- which view axes stay in step; default X only
}

type Fields = {
	Charts: { any },
	_Connections: { RBXScriptConnection },
	_Syncing: boolean,
}

local Link = {}
Link.__index = Link

export type Link = typeof(setmetatable({} :: Fields, Link))

-- ─── Construction ────────────────────────────────────────────────────────────

function Link.new(Charts: { any }, Options: Options?): Link
	const self = setmetatable({} :: Fields, Link)
	self.Charts = Charts
	self._Connections = {}
	self._Syncing = false

	const MirrorCursor = if Options and Options.Cursor ~= nil then Options.Cursor else true
	local Axes: { X: boolean?, Y: boolean? } = { X = true }
	if Options and Options.Axes then
		Axes = Options.Axes
	end
	const Names: { string } = {}
	if Axes.X then
		table.move(X_DRIVERS, 1, #X_DRIVERS, #Names + 1, Names)
	end
	if Axes.Y then
		table.move(Y_DRIVERS, 1, #Y_DRIVERS, #Names + 1, Names)
	end

	for _, Chart in Charts do
		for _, Name in Names do
			const Driver: NumberValue = Chart._ViewDrivers[Name]
			table.insert(self._Connections, Driver.Changed:Connect(function(Value: number)
				-- The guard stops the mirrored charts from mirroring back
				if self._Syncing then
					return
				end
				self._Syncing = true
				for _, Other in Charts do
					if Other ~= Chart then
						Other._ViewDrivers[Name].Value = Value
					end
				end
				self._Syncing = false
			end))
		end

		if MirrorCursor then
			const UI: GuiObject = Chart.UI
			table.insert(self._Connections, UI.MouseMoved:Connect(function(X: number)
				const Size = UI.AbsoluteSize
				if Size.X <= 0 then
					return
				end
				const Alpha = (X - UI.AbsolutePosition.X - GuiInset.X) / Size.X
				for _, Other in Charts do
					const Cursor = Other.Cursor
					if Other ~= Chart and Cursor and Cursor.Enabled and Cursor.UI then
						const OtherSize: Vector2 = Other.UI.AbsoluteSize
						Cursor._Hovering = true
						Cursor:_RefreshVisibility()
						Cursor:SetPosition(Vector2.new(Alpha * OtherSize.X, OtherSize.Y / 2))
					end
				end
			end))
			table.insert(self._Connections, UI.MouseLeave:Connect(function()
				for _, Other in Charts do
					const Cursor = Other.Cursor
					if Other ~= Chart and Cursor and Cursor.UI then
						Cursor._Hovering = false
						Cursor:_RefreshVisibility()
					end
				end
			end))
		end
	end

	return self
end

-- ─── API ─────────────────────────────────────────────────────────────────────

function Link.Destroy(self: Link)
	for _, Connection in self._Connections do
		Connection:Disconnect()
	end
	table.clear(self._Connections)
end

return Link
