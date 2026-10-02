--!strict
--!native
--!optimize 2
-- PartPool (Class): reuses parts in place for the viewport renderers. Parts keep their parent between
-- updates and only change properties, because reparenting hundreds of parts every update makes a
-- ViewportFrame drop frames. Whether a part is attached is tracked here, so no update reads Parent back.

-- ─── Types ───────────────────────────────────────────────────────────────────

type Entry = { Parts: { Instance }, Used: number, Detached: { boolean } }

type Fields = {
	_Entries: { [Instance]: { [string]: Entry } }, -- [Parent][Type]
}

local PartPool = {}
PartPool.__index = PartPool

export type PartPool = typeof(setmetatable({} :: Fields, PartPool))

-- ─── Construction ────────────────────────────────────────────────────────────

function PartPool.new(): PartPool
	const self = setmetatable({} :: Fields, PartPool)
	self._Entries = {}
	return self
end

-- ─── API ─────────────────────────────────────────────────────────────────────

-- Starts an update: every part becomes available again
function PartPool.Begin(self: PartPool)
	for _, Types in self._Entries do
		for _, Entry in Types do
			Entry.Used = 0
		end
	end
end

-- The next part of Type under Parent, cloned from Template when the pool runs out
function PartPool.Get(self: PartPool, Parent: Instance, Type: string, Template: Instance): Instance
	local Types = self._Entries[Parent]
	if not Types then
		Types = {}
		self._Entries[Parent] = Types
	end
	local Entry = Types[Type]
	if not Entry then
		Entry = { Parts = {}, Used = 0, Detached = {} }
		Types[Type] = Entry
	end

	Entry.Used += 1
	const Used = Entry.Used
	const Existing = Entry.Parts[Used] :: Instance?
	if Existing then
		if Entry.Detached[Used] then
			Existing.Parent = Parent
			Entry.Detached[Used] = false
		end
		return Existing
	end

	const Part = Template:Clone()
	Part.Name = Type
	Part.Parent = Parent
	Entry.Parts[Used] = Part
	Entry.Detached[Used] = false
	return Part
end

-- Ends an update: parts that went unused leave the tree but stay pooled
function PartPool.Finish(self: PartPool)
	for _, Types in self._Entries do
		for _, Entry in Types do
			for Position = Entry.Used + 1, #Entry.Parts do
				if not Entry.Detached[Position] then
					Entry.Parts[Position].Parent = nil
					Entry.Detached[Position] = true
				end
			end
		end
	end
end

-- Drops the parts under a parent that is about to be destroyed
function PartPool.Forget(self: PartPool, Parent: Instance)
	self._Entries[Parent] = nil
end

function PartPool.Destroy(self: PartPool)
	for _, Types in self._Entries do
		for _, Entry in Types do
			for _, Part in Entry.Parts do
				Part:Destroy()
			end
		end
	end
	table.clear(self._Entries)
end

return PartPool
