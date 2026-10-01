--!strict
-- Store: плоское состояние модуля + подписки по ключам. Без Roblox API.
--   store:get(key), store:set(key, value), store:patch({...})
--   store.Changed:Connect(key, fn)  → { Disconnect = fn }; key "*" — любые изменения
-- Таблицы (records, threads) заменяются целиком, а не мутируются, — так подписчики не пропустят изменение.

local Store = {}
Store.__index = Store

local PERSISTENT = { "m", "h", "scene", "threads", "records", "parabola", "honey", "predictions", "scene2d", "notes" }

function Store.new(initial: { [string]: any }?)
	local self = setmetatable({}, Store)
	self.state = table.clone(initial or {}) :: { [string]: any }
	self.listeners = {} :: { [string]: { (any, string) -> () } }
	local store = self
	self.Changed = {
		Connect = function(_, key: string, fn: (any, string) -> ())
			local list = store.listeners[key]
			if not list then
				list = {}
				store.listeners[key] = list
			end
			table.insert(list, fn)
			return {
				Disconnect = function()
					local i = table.find(list, fn)
					if i then
						table.remove(list, i)
					end
				end,
			}
		end,
	}
	return self
end

function Store.get(self: any, key: string): any
	return self.state[key]
end

function Store.set(self: any, key: string, value: any)
	if self.state[key] == value and type(value) ~= "table" then
		return
	end
	self.state[key] = value
	for _, k in { key, "*" } do
		local list = self.listeners[k]
		if list then
			for _, fn in (table.clone(list) :: { (any, string) -> () }) do
				fn(value, key)
			end
		end
	end
end

function Store.patch(self: any, t: { [string]: any })
	for k, v in t do
		self:set(k, v)
	end
end

-- Для будущего DataStore (вне рамок ТЗ): только то, что нужно восстановить
function Store.serialize(self: any): { [string]: any }
	local out = {}
	for _, k in PERSISTENT do
		local v = self.state[k]
		out[k] = if type(v) == "table" then table.clone(v) else v
	end
	return out
end

return Store
