--!nonstrict
-- Мок Roblox API для headless-прогона клиентского кода модуля «Регрессия» в standalone luau.
-- Не эмулятор: только то, что нужно сценарным тестам. Зато строгий там, где ошибки дороги:
--   • свойства Instance и их типы проверяются по reflection-базе rbx-dom (tests/mock/Reflection.luau);
--   • Enum.X.Y — только существующие элементы;
--   • неизвестный метод/событие Instance → ошибка (список ниже);
--   • время виртуальное: os.clock, task.delay/wait/defer, RenderStepped двигает тест (M.step).
-- Загрузчик M.mount(dir) превращает дерево src/ в Instance'ы (Rojo-правила имён), require — по ModuleScript.

local Reflection = require("./Reflection")

local M = {}

-- ───────────────────────── время и планировщик ─────────────────────────

local now = 0
local queue = {} -- { t, fn, args }
local function schedule(t, fn, ...)
	table.insert(queue, { t = t, fn = fn, args = table.pack(...) })
end
local function runThread(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)), 0)
	end
	return co
end

local task = {}
function task.spawn(fn, ...)
	return runThread(fn, ...)
end
function task.defer(fn, ...)
	schedule(now, fn, ...)
end
function task.delay(t, fn, ...)
	schedule(now + (t or 0), fn, ...)
end
function task.wait(t)
	local co = coroutine.running()
	schedule(now + (t or 0), co)
	coroutine.yield()
	return t or 0
end
function task.cancel() end

local function flushQueue()
	local guard = 0
	while true do
		table.sort(queue, function(a, b)
			return a.t < b.t
		end)
		local first = queue[1]
		if not first or first.t > now + 1e-9 then
			break
		end
		table.remove(queue, 1)
		runThread(first.fn, table.unpack(first.args, 1, first.args.n))
		guard += 1
		assert(guard < 100000, "scheduler runaway")
	end
end

-- ───────────────────────── сигналы ─────────────────────────

local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ name = name, handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local entry = { fn = fn, connected = true }
	table.insert(self.handlers, entry)
	return {
		Connected = true,
		Disconnect = function(c)
			entry.connected = false
			c.Connected = false
		end,
	}
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end
function Signal:Fire(...)
	for _, h in table.clone(self.handlers) do
		if h.connected then
			h.fn(...)
		end
	end
end
M.Signal = Signal

-- ───────────────────────── типы данных ─────────────────────────

local TYPE = setmetatable({}, { __mode = "k" }) -- значение → имя типа для typeof
local function mark(v, t)
	TYPE[v] = t
	return v
end
local function typeof_(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt and rawget(mt, "__type") then
			return mt.__type
		end
		if TYPE[v] then
			return TYPE[v]
		end
	end
	return typeof(v)
end
M.typeof = typeof_

-- Vector3
local Vector3 = {}
local V3 = { __type = "Vector3" }
V3.__index = function(v, k)
	if k == "X" then return v[1] elseif k == "Y" then return v[2] elseif k == "Z" then return v[3]
	elseif k == "Magnitude" then return math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	elseif k == "Unit" then
		local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
		return Vector3.new(v[1] / m, v[2] / m, v[3] / m)
	end
	local f = V3[k]
	if f then return f end
	error("Vector3." .. tostring(k) .. " is not a valid member", 2)
end
function Vector3.new(x, y, z)
	return setmetatable({ x or 0, y or 0, z or 0 }, V3)
end
local function isV3(v) return getmetatable(v) == V3 end
V3.__add = function(a, b) return Vector3.new(a[1] + b[1], a[2] + b[2], a[3] + b[3]) end
V3.__sub = function(a, b) return Vector3.new(a[1] - b[1], a[2] - b[2], a[3] - b[3]) end
V3.__unm = function(a) return Vector3.new(-a[1], -a[2], -a[3]) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector3.new(a[1] * b, a[2] * b, a[3] * b) end
	return Vector3.new(a[1] * b[1], a[2] * b[2], a[3] * b[3])
end
V3.__div = function(a, b)
	if type(b) == "number" then return Vector3.new(a[1] / b, a[2] / b, a[3] / b) end
	return Vector3.new(a[1] / b[1], a[2] / b[2], a[3] / b[3])
end
V3.__eq = function(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
V3.__tostring = function(a) return ("%g, %g, %g"):format(a[1], a[2], a[3]) end
function V3.Dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
function V3.Cross(a, b)
	return Vector3.new(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
end
function V3.Lerp(a, b, t) return a + (b - a) * t end
function V3.Abs(a) return Vector3.new(math.abs(a[1]), math.abs(a[2]), math.abs(a[3])) end
function V3.Min(a, b) return Vector3.new(math.min(a[1], b[1]), math.min(a[2], b[2]), math.min(a[3], b[3])) end
function V3.Max(a, b) return Vector3.new(math.max(a[1], b[1]), math.max(a[2], b[2]), math.max(a[3], b[3])) end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

-- Vector2
local Vector2 = {}
local V2 = { __type = "Vector2" }
V2.__index = function(v, k)
	if k == "X" then return v[1] elseif k == "Y" then return v[2]
	elseif k == "Magnitude" then return math.sqrt(v[1] ^ 2 + v[2] ^ 2)
	elseif k == "Unit" then local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2) return Vector2.new(v[1] / m, v[2] / m) end
	local f = V2[k]
	if f then return f end
	error("Vector2." .. tostring(k) .. " is not a valid member", 2)
end
function Vector2.new(x, y) return setmetatable({ x or 0, y or 0 }, V2) end
V2.__add = function(a, b) return Vector2.new(a[1] + b[1], a[2] + b[2]) end
V2.__sub = function(a, b) return Vector2.new(a[1] - b[1], a[2] - b[2]) end
V2.__unm = function(a) return Vector2.new(-a[1], -a[2]) end
V2.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector2.new(a[1] * b, a[2] * b) end
	return Vector2.new(a[1] * b[1], a[2] * b[2])
end
V2.__div = function(a, b)
	if type(b) == "number" then return Vector2.new(a[1] / b, a[2] / b) end
	return Vector2.new(a[1] / b[1], a[2] / b[2])
end
V2.__eq = function(a, b) return a[1] == b[1] and a[2] == b[2] end
V2.__tostring = function(a) return ("%g, %g"):format(a[1], a[2]) end
function V2.Dot(a, b) return a[1] * b[1] + a[2] * b[2] end
function V2.Lerp(a, b, t) return a + (b - a) * t end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

-- CFrame: позиция p и матрица поворота R (строки)
local CFrame = {}
local CF = { __type = "CFrame" }
local function cfnew(px, py, pz, R)
	return setmetatable({ p = { px, py, pz }, R = R or { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } }, CF)
end
local function matmul(A, B)
	local C = { {}, {}, {} }
	for i = 1, 3 do
		for j = 1, 3 do
			C[i][j] = A[i][1] * B[1][j] + A[i][2] * B[2][j] + A[i][3] * B[3][j]
		end
	end
	return C
end
local function matvec(A, v)
	return A[1][1] * v[1] + A[1][2] * v[2] + A[1][3] * v[3],
		A[2][1] * v[1] + A[2][2] * v[2] + A[2][3] * v[3],
		A[3][1] * v[1] + A[3][2] * v[2] + A[3][3] * v[3]
end
local function transpose(A)
	return { { A[1][1], A[2][1], A[3][1] }, { A[1][2], A[2][2], A[3][2] }, { A[1][3], A[2][3], A[3][3] } }
end
CF.__index = function(c, k)
	if k == "Position" or k == "p" then return Vector3.new(c.p[1], c.p[2], c.p[3])
	elseif k == "X" then return c.p[1] elseif k == "Y" then return c.p[2] elseif k == "Z" then return c.p[3]
	elseif k == "Rotation" then return cfnew(0, 0, 0, c.R)
	elseif k == "LookVector" then return Vector3.new(-c.R[1][3], -c.R[2][3], -c.R[3][3])
	elseif k == "UpVector" then return Vector3.new(c.R[1][2], c.R[2][2], c.R[3][2])
	elseif k == "RightVector" then return Vector3.new(c.R[1][1], c.R[2][1], c.R[3][1])
	elseif k == "XVector" then return Vector3.new(c.R[1][1], c.R[2][1], c.R[3][1])
	elseif k == "YVector" then return Vector3.new(c.R[1][2], c.R[2][2], c.R[3][2])
	elseif k == "ZVector" then return Vector3.new(c.R[1][3], c.R[2][3], c.R[3][3])
	end
	local f = CF[k]
	if f then return f end
	error("CFrame." .. tostring(k) .. " is not a valid member", 2)
end
function CFrame.new(a, b, c, ...)
	if a == nil then return cfnew(0, 0, 0) end
	if isV3(a) then
		if b ~= nil and isV3(b) then return CFrame.lookAt(a, b) end
		return cfnew(a[1], a[2], a[3])
	end
	local r = { ... }
	if #r == 9 then
		return cfnew(a, b, c, { { r[1], r[2], r[3] }, { r[4], r[5], r[6] }, { r[7], r[8], r[9] } })
	end
	return cfnew(a, b or 0, c or 0)
end
function CFrame.lookAt(pos, target, up)
	up = up or Vector3.yAxis
	local look = (target - pos)
	if look.Magnitude < 1e-9 then return cfnew(pos[1], pos[2], pos[3]) end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-9 then right = look:Cross(Vector3.zAxis) end
	right = right.Unit
	local up2 = right:Cross(look)
	local z = -look
	return cfnew(pos[1], pos[2], pos[3], {
		{ right[1], up2[1], z[1] }, { right[2], up2[2], z[2] }, { right[3], up2[3], z[3] },
	})
end
CFrame.lookAlong = function(pos, dir, up) return CFrame.lookAt(pos, pos + dir, up) end
local function rotX(a) local c, s = math.cos(a), math.sin(a) return { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } } end
local function rotY(a) local c, s = math.cos(a), math.sin(a) return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } } end
local function rotZ(a) local c, s = math.cos(a), math.sin(a) return { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } } end
function CFrame.Angles(x, y, z)
	return cfnew(0, 0, 0, matmul(matmul(rotX(x), rotY(y)), rotZ(z)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return cfnew(0, 0, 0, matmul(matmul(rotY(y), rotX(x)), rotZ(z)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(axis, a)
	local u = axis.Unit
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	local x, y, z = u[1], u[2], u[3]
	return cfnew(0, 0, 0, {
		{ t * x * x + c, t * x * y - s * z, t * x * z + s * y },
		{ t * x * y + s * z, t * y * y + c, t * y * z - s * x },
		{ t * x * z - s * y, t * y * z + s * x, t * z * z + c },
	})
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return cfnew(pos[1], pos[2], pos[3], { { vx[1], vy[1], vz[1] }, { vx[2], vy[2], vz[2] }, { vx[3], vy[3], vz[3] } })
end
CFrame.identity = cfnew(0, 0, 0)
CF.__mul = function(a, b)
	if isV3(b) then
		local x, y, z = matvec(a.R, b)
		return Vector3.new(x + a.p[1], y + a.p[2], z + a.p[3])
	end
	local x, y, z = matvec(a.R, b.p)
	return cfnew(x + a.p[1], y + a.p[2], z + a.p[3], matmul(a.R, b.R))
end
CF.__add = function(a, v) return cfnew(a.p[1] + v[1], a.p[2] + v[2], a.p[3] + v[3], a.R) end
CF.__sub = function(a, v) return cfnew(a.p[1] - v[1], a.p[2] - v[2], a.p[3] - v[3], a.R) end
CF.__tostring = function(a) return ("CFrame(%g, %g, %g)"):format(a.p[1], a.p[2], a.p[3]) end
function CF.Inverse(a)
	local Rt = transpose(a.R)
	local x, y, z = matvec(Rt, a.p)
	return cfnew(-x, -y, -z, Rt)
end
function CF.PointToWorldSpace(a, v) return a * v end
function CF.PointToObjectSpace(a, v) return a:Inverse() * v end
function CF.VectorToWorldSpace(a, v) local x, y, z = matvec(a.R, v) return Vector3.new(x, y, z) end
function CF.VectorToObjectSpace(a, v) local x, y, z = matvec(transpose(a.R), v) return Vector3.new(x, y, z) end
function CF.ToWorldSpace(a, b) return a * b end
function CF.ToObjectSpace(a, b) return a:Inverse() * b end
function CF.GetComponents(a)
	local R = a.R
	return a.p[1], a.p[2], a.p[3], R[1][1], R[1][2], R[1][3], R[2][1], R[2][2], R[2][3], R[3][1], R[3][2], R[3][3]
end
CF.components = CF.GetComponents
-- YXZ: R = Ry·Rx·Rz
function CF.ToEulerAnglesYXZ(a)
	local R = a.R
	local x = math.asin(math.clamp(-R[2][3], -1, 1))
	local y = math.atan2(R[1][3], R[3][3])
	local z = math.atan2(R[2][1], R[2][2])
	return x, y, z
end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.ToEulerAnglesXYZ(a)
	local R = a.R
	local y = math.asin(math.clamp(R[1][3], -1, 1))
	local x = math.atan2(-R[2][3], R[3][3])
	local z = math.atan2(-R[1][2], R[1][1])
	return x, y, z
end
function CF.Lerp(a, b, t)
	local p = a.Position:Lerp(b.Position, t)
	local R = if t < 0.5 then a.R else b.R
	return cfnew(p[1], p[2], p[3], R)
end

-- Color3
local Color3 = {}
local C3 = { __type = "Color3" }
C3.__index = function(c, k)
	if k == "R" then return c[1] elseif k == "G" then return c[2] elseif k == "B" then return c[3] end
	local f = C3[k]
	if f then return f end
	error("Color3." .. tostring(k) .. " is not a valid member", 2)
end
function Color3.new(r, g, b) return setmetatable({ r or 0, g or 0, b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(s)
	s = s:gsub("#", "")
	assert(#s == 6, "bad hex " .. s)
	return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end
C3.__eq = function(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
function C3.Lerp(a, b, t) return Color3.new(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t) end
function C3.ToHex(a) return ("%02X%02X%02X"):format(math.round(a[1] * 255), math.round(a[2] * 255), math.round(a[3] * 255)) end
function C3.ToHSV(a) return 0, 0, math.max(a[1], a[2], a[3]) end

-- UDim / UDim2
local UDim = {}
local UD = { __type = "UDim" }
UD.__index = function(u, k)
	if k == "Scale" then return u[1] elseif k == "Offset" then return u[2] end
	error("UDim." .. tostring(k) .. " is not a valid member", 2)
end
function UDim.new(s, o) return setmetatable({ s or 0, o or 0 }, UD) end
UD.__add = function(a, b) return UDim.new(a[1] + b[1], a[2] + b[2]) end
UD.__eq = function(a, b) return a[1] == b[1] and a[2] == b[2] end

local UDim2 = {}
local UD2 = { __type = "UDim2" }
UD2.__index = function(u, k)
	if k == "X" or k == "Width" then return u.x elseif k == "Y" or k == "Height" then return u.y end
	local f = UD2[k]
	if f then return f end
	error("UDim2." .. tostring(k) .. " is not a valid member", 2)
end
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then
		return setmetatable({ x = xs, y = xo }, UD2)
	end
	return setmetatable({ x = UDim.new(xs, xo), y = UDim.new(ys, yo) }, UD2)
end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
UD2.__add = function(a, b) return UDim2.new(a.x + b.x, a.y + b.y) end
UD2.__eq = function(a, b) return a.x == b.x and a.y == b.y end
function UD2.Lerp(a, b, t)
	return UDim2.new(a.x[1] + (b.x[1] - a.x[1]) * t, a.x[2] + (b.x[2] - a.x[2]) * t, a.y[1] + (b.y[1] - a.y[1]) * t, a.y[2] + (b.y[2] - a.y[2]) * t)
end

local function plain(t, fields)
	return function(...)
		local v = {}
		for i, f in fields do
			v[f] = select(i, ...)
		end
		return mark(v, t)
	end
end
local TweenInfo = { new = plain("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" }) }
local NumberRange = { new = plain("NumberRange", { "Min", "Max" }) }
local NumberSequence = { new = plain("NumberSequence", { "Keypoints" }) }
local ColorSequence = { new = plain("ColorSequence", { "Keypoints" }) }
local NumberSequenceKeypoint = { new = plain("NumberSequenceKeypoint", { "Time", "Value", "Envelope" }) }
local ColorSequenceKeypoint = { new = plain("ColorSequenceKeypoint", { "Time", "Value" }) }
local Rect = { new = plain("Rect", { "MinX", "MinY", "MaxX", "MaxY" }) }
local Ray = {
	new = function(o, d)
		return mark({ Origin = o, Direction = d, Unit = { Origin = o, Direction = d.Unit } }, "Ray")
	end,
}
local Font = {
	new = plain("Font", { "Family", "Weight", "Style" }),
	fromEnum = plain("Font", { "Enum" }),
}
local RaycastParams = {
	new = function()
		return mark({ FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }, "RaycastParams")
	end,
}

-- Enum
local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = EnumItemMT
EnumItemMT.__tostring = function(e) return "Enum." .. e.EnumType.Name .. "." .. e.Name end
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local def = Reflection.enums[enumName]
		if not def then error("Enum." .. tostring(enumName) .. " does not exist", 2) end
		local cached = enumCache[enumName]
		if cached then return cached end
		local typeT = { Name = enumName }
		local e = setmetatable({}, {
			__index = function(_, item)
				local v = def[item]
				if v == nil then error(("Enum.%s.%s does not exist"):format(enumName, tostring(item)), 2) end
				return setmetatable({ Name = item, Value = v, EnumType = typeT }, EnumItemMT)
			end,
		})
		-- элементы — синглтоны, чтобы == работал
		local items = {}
		getmetatable(e).__index = function(_, item)
			if item == "GetEnumItems" then
				return function()
					local out = {}
					for name in def do table.insert(out, e[name]) end
					return out
				end
			end
			local v = def[item]
			if v == nil then error(("Enum.%s.%s does not exist"):format(enumName, tostring(item)), 2) end
			if not items[item] then
				items[item] = setmetatable({ Name = item, Value = v, EnumType = typeT }, EnumItemMT)
			end
			return items[item]
		end
		enumCache[enumName] = e
		return e
	end,
})

-- ───────────────────────── Instance ─────────────────────────

local function classProps(className)
	local out, cls = {}, className
	local chain = {}
	while cls do
		local d = Reflection.classes[cls]
		if not d then break end
		table.insert(chain, cls)
		for k, t in d.props do
			if out[k] == nil then out[k] = t end
		end
		cls = d.super
	end
	return out, chain
end
local propCache = {}
local function propsOf(className)
	local c = propCache[className]
	if not c then
		local p, chain = classProps(className)
		c = { props = p, chain = chain }
		propCache[className] = c
	end
	return c
end
local function isA(className, base)
	for _, c in propsOf(className).chain do
		if c == base then return true end
	end
	return false
end

local DEFAULTS = {
	Bool = false, String = "", Float32 = 0, Float64 = 0, Int32 = 0, Int64 = 0, Content = "", ContentId = "",
}
local function defaultFor(t, className, prop)
	if prop == "Size" and isA(className, "BasePart") then return Vector3.new(4, 1, 2) end
	if prop == "Transparency" or prop == "BackgroundTransparency" or prop == "TextTransparency" or prop == "ImageTransparency" then return 0 end
	if prop == "Visible" or prop == "Enabled" or prop == "Archivable" or prop == "Anchored" or prop == "CanCollide" or prop == "CanTouch" or prop == "CanQuery" then return true end
	if prop == "TextSize" then return 14 end
	if prop == "FieldOfView" then return 70 end
	if DEFAULTS[t] ~= nil then return DEFAULTS[t] end
	if t == "Vector3" then return Vector3.zero end
	if t == "Vector2" then return Vector2.zero end
	if t == "CFrame" then return CFrame.identity end
	if t == "Color3" or t == "Color3uint8" then return Color3.new(1, 1, 1) end
	if t == "UDim2" then return UDim2.new(0, 0, 0, 0) end
	if t == "UDim" then return UDim.new(0, 0) end
	if type(t) == "string" and t:sub(1, 5) == "Enum." then
		local def = Reflection.enums[t:sub(6)]
		if def then
			local best, bestV = nil, math.huge
			for name, v in def do if v < bestV then best, bestV = name, v end end
			return (Enum :: any)[t:sub(6)][best]
		end
	end
	return nil
end

local function checkType(className, prop, t, v)
	if v == nil then return end
	local tv = typeof_(v)
	local ok = true
	if t == "Bool" then ok = tv == "boolean"
	elseif t == "String" or t == "Content" or t == "ContentId" then ok = tv == "string"
	elseif t == "Float32" or t == "Float64" or t == "Int32" or t == "Int64" then ok = tv == "number" and v == v
	elseif t == "Vector3" or t == "Vector2" or t == "CFrame" or t == "UDim2" or t == "UDim" then ok = tv == t
	elseif t == "Color3" or t == "Color3uint8" then ok = tv == "Color3"
	elseif t == "Ref" then ok = tv == "Instance"
	elseif type(t) == "string" and t:sub(1, 5) == "Enum." then
		ok = tv == "EnumItem" and v.EnumType.Name == t:sub(6)
	end
	if not ok then
		error(("%s.%s: ожидался %s, получено %s (%s)"):format(className, prop, t, tv, tostring(v)), 3)
	end
end

-- Методы и события, которые разрешено трогать (остальное → ошибка, как опечатка в Roblox)
local EVENTS = {
	Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, AncestryChanged = true, Destroying = true,
	Triggered = true, TriggerEnded = true, PromptShown = true, PromptHidden = true,
	Activated = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseEnter = true, MouseLeave = true, MouseMoved = true, MouseWheelForward = true, MouseWheelBackward = true,
	InputBegan = true, InputEnded = true, InputChanged = true, Completed = true, Touched = true, TouchEnded = true,
	FocusLost = true, Focused = true, OnClientEvent = true, OnServerEvent = true, Event = true,
	CharacterAdded = true, CharacterRemoving = true, Died = true, MoveToFinished = true,
}

local Instance = {}
local IMT = { __type = "Instance" }
local allInstances = setmetatable({}, { __mode = "k" })

local function newInstance(className)
	assert(Reflection.classes[className], "Instance.new: unknown class " .. tostring(className))
	local self = {
		__class = className, __props = { Name = className }, __children = {}, __parent = nil,
		__signals = {}, __propSignals = {}, __attrs = {},
	}
	allInstances[self] = true
	return setmetatable(self, IMT)
end
M.newInstance = newInstance

local methods = {}
IMT.__index = function(self, k)
	if k == "ClassName" then return rawget(self, "__class") end
	if k == "Parent" then return rawget(self, "__parent") end
	local m = methods[k]
	if m then return m end
	local extra0 = rawget(self, "__extra")
	if extra0 and extra0[k] ~= nil then return extra0[k] end
	local props = rawget(self, "__props")
	local cls = rawget(self, "__class")
	if (k == "Position" or k == "Orientation") and isA(cls, "BasePart") then
		local cf = props.CFrame or CFrame.identity
		if k == "Position" then return cf.Position end
		local x, y, z = cf:ToOrientation()
		return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
	end
	local v = props[k]
	if v ~= nil then return v end
	local spec = propsOf(cls).props
	if spec[k] ~= nil or k == "AbsoluteSize" or k == "AbsolutePosition" then
		if k == "AbsoluteSize" or k == "AbsolutePosition" then
			return M.absolute(self, k)
		end
		local d = defaultFor(spec[k], cls, k)
		props[k] = d
		return d
	end
	if EVENTS[k] then
		local s = rawget(self, "__signals")
		s[k] = s[k] or Signal.new(k)
		return s[k]
	end
	local extra = rawget(self, "__extra")
	if extra and extra[k] ~= nil then return extra[k] end
	-- дочерний объект по имени
	for _, c in rawget(self, "__children") do
		if c.Name == k then return c end
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(k), cls, tostring(props.Name)), 2)
end
IMT.__newindex = function(self, k, v)
	local cls = rawget(self, "__class")
	if k == "Parent" then
		local old = rawget(self, "__parent")
		if old == v then return end
		if old then
			local list = rawget(old, "__children")
			local i = table.find(list, self)
			if i then table.remove(list, i) end
		end
		rawset(self, "__parent", v)
		if v then
			table.insert(rawget(v, "__children"), self)
			v.ChildAdded:Fire(self)
		end
		return
	end
	local extra = rawget(self, "__extra")
	if extra and extra[k] ~= nil then
		extra[k] = v
		return
	end
	local spec = propsOf(cls).props
	local t = spec[k]
	if t == nil then
		error(("%s is not a valid member of %s (присваивание)"):format(tostring(k), cls), 2)
	end
	checkType(cls, k, t, v)
	local props = rawget(self, "__props")
	if k == "Position" and isA(cls, "BasePart") then
		k, v = "CFrame", (props.CFrame or CFrame.identity).Rotation + v
	end
	local old = props[k]
	props[k] = v
	if old ~= v then
		local ps = rawget(self, "__propSignals")[k]
		if ps then ps:Fire() end
		local s = rawget(self, "__signals").Changed
		if s then
			-- у ValueBase событие Changed передаёт новое значение, у остальных — имя свойства
			if isA(cls, "ValueBase") then s:Fire(v) else s:Fire(k) end
		end
	end
end
IMT.__tostring = function(self) return rawget(self, "__props").Name end

function methods.IsA(self, c) return isA(rawget(self, "__class"), c) end
function methods.GetChildren(self) return table.clone(rawget(self, "__children")) end
function methods.GetDescendants(self)
	local out = {}
	local function rec(i)
		for _, c in rawget(i, "__children") do
			table.insert(out, c)
			rec(c)
		end
	end
	rec(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "__children") do
		if c.Name == name then return c end
	end
	if recursive then
		for _, c in rawget(self, "__children") do
			local r = c:FindFirstChild(name, true)
			if r then return r end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in rawget(self, "__children") do
		if rawget(c, "__class") == cls then return c end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, cls, recursive)
	for _, c in rawget(self, "__children") do
		if c:IsA(cls) then return c end
	end
	if recursive then
		for _, c in rawget(self, "__children") do
			local r = c:FindFirstChildWhichIsA(cls, true)
			if r then return r end
		end
	end
	return nil
end
function methods.FindFirstAncestor(self, name)
	local p = rawget(self, "__parent")
	while p do
		if p.Name == name then return p end
		p = rawget(p, "__parent")
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(self, cls)
	local p = rawget(self, "__parent")
	while p do
		if p:IsA(cls) then return p end
		p = rawget(p, "__parent")
	end
	return nil
end
function methods.WaitForChild(self, name, timeout)
	local c = self:FindFirstChild(name)
	if c then return c end
	if timeout then return nil end
	error(("WaitForChild: %s не найден в %s (в моке ожидание не поддерживается)"):format(name, self:GetFullName()), 2)
end
function methods.IsDescendantOf(self, other)
	local p = rawget(self, "__parent")
	while p do
		if p == other then return true end
		p = rawget(p, "__parent")
	end
	return false
end
function methods.IsAncestorOf(self, other) return other:IsDescendantOf(self) end
function methods.GetFullName(self)
	local parts = {}
	local p = self
	while p and rawget(p, "__class") ~= "DataModel" do
		table.insert(parts, 1, p.Name)
		p = rawget(p, "__parent")
	end
	return table.concat(parts, ".")
end
function methods.Destroy(self)
	for _, c in table.clone(rawget(self, "__children")) do
		c:Destroy()
	end
	self.Parent = nil
	rawset(self, "__destroyed", true)
end
function methods.ClearAllChildren(self)
	for _, c in table.clone(rawget(self, "__children")) do c:Destroy() end
end
function methods.Clone(self)
	local c = newInstance(rawget(self, "__class"))
	for k, v in rawget(self, "__props") do rawget(c, "__props")[k] = v end
	for _, ch in rawget(self, "__children") do ch:Clone().Parent = c end
	return c
end
function methods.GetPropertyChangedSignal(self, prop)
	local cls = rawget(self, "__class")
	if propsOf(cls).props[prop] == nil and prop ~= "AbsoluteSize" and prop ~= "AbsolutePosition" then
		error(("GetPropertyChangedSignal: %s нет у %s"):format(prop, cls), 2)
	end
	local ps = rawget(self, "__propSignals")
	ps[prop] = ps[prop] or Signal.new(prop)
	return ps[prop]
end
function methods.SetAttribute(self, k, v) rawget(self, "__attrs")[k] = v end
function methods.GetAttribute(self, k) return rawget(self, "__attrs")[k] end
function methods.GetAttributes(self) return table.clone(rawget(self, "__attrs")) end
function methods.GetAttributeChangedSignal(self, k)
	local ps = rawget(self, "__propSignals")
	ps["@" .. k] = ps["@" .. k] or Signal.new(k)
	return ps["@" .. k]
end
-- Model / BasePart
local function modelParts(self)
	local out = {}
	if self:IsA("BasePart") then table.insert(out, self) end
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end
function methods.GetPivot(self)
	if self:IsA("BasePart") then return self.CFrame end
	local pp = rawget(self, "__props").PrimaryPart
	if pp then return pp.CFrame end
	local parts = modelParts(self)
	if #parts > 0 then return CFrame.new(parts[1].Position) end
	return CFrame.identity
end
function methods.PivotTo(self, cf)
	local cur = self:GetPivot()
	local delta = cf * cur:Inverse()
	for _, p in modelParts(self) do
		p.CFrame = delta * p.CFrame
	end
end
function methods.GetBoundingBox(self)
	return self:GetPivot(), Vector3.new(1, 1, 1)
end
function methods.ScaleTo() end
-- GUI
function methods.TweenPosition(self, pos) self.Position = pos return true end
function methods.TweenSize(self, size) self.Size = size return true end
-- Remote
function methods.FireServer(self, ...)
	local log = rawget(self, "__fired") or {}
	rawset(self, "__fired", log)
	table.insert(log, table.pack(...))
end
function methods.FireClient() end
function methods.FireAllClients() end
function methods.Play(self) end

IMT.__eq = rawequal

function Instance.new(className, parent)
	local i = newInstance(className)
	if parent then i.Parent = parent end
	return i
end

-- Абсолютная геометрия GUI (без UIListLayout/AutomaticSize — для графиков хватает)
local SCREEN = Vector2.new(1280, 720)
M.SCREEN = SCREEN
function M.absolute(inst, which)
	local function rec(i)
		local cls = rawget(i, "__class")
		if cls == "ScreenGui" or cls == "PlayerGui" or cls == "BillboardGui" then
			if cls == "BillboardGui" then
				local s = i.Size
				return Vector2.zero, Vector2.new(s.x[2], s.y[2])
			end
			return Vector2.zero, SCREEN
		end
		if cls == "SurfaceGui" then
			local a = i.Adornee or rawget(i, "__parent")
			local pps = i.PixelsPerStud
			if a and a:IsA("BasePart") then
				return Vector2.zero, Vector2.new(a.Size.X * pps, a.Size.Y * pps)
			end
			return Vector2.zero, Vector2.new(800, 600)
		end
		local parent = rawget(i, "__parent")
		if not parent or not isA(cls, "GuiObject") then
			return Vector2.zero, SCREEN
		end
		local pp, ps = rec(parent)
		local size, pos = i.Size, i.Position
		local w = ps.X * size.x[1] + size.x[2]
		local h = ps.Y * size.y[1] + size.y[2]
		local ap = i.AnchorPoint
		local x = pp.X + ps.X * pos.x[1] + pos.x[2] - ap.X * w
		local y = pp.Y + ps.Y * pos.y[1] + pos.y[2] - ap.Y * h
		return Vector2.new(x, y), Vector2.new(w, h)
	end
	local p, s = rec(inst)
	return if which == "AbsoluteSize" then s else p
end

-- ───────────────────────── сервисы ─────────────────────────

local game = newInstance("DataModel")
game.Name = "Game"
local services = {}
local function service(name, extra)
	local s = newInstance(name)
	s.Name = name
	rawset(s, "__extra", extra or {})
	s.Parent = game
	services[name] = s
	return s
end

local workspace_ = service("Workspace", {})
local camera = newInstance("Camera")
camera.Name = "Camera"
camera.Parent = workspace_
camera.CFrame = CFrame.new(0, 10, 20)
rawget(workspace_, "__extra").CurrentCamera = camera
function methods.ScreenPointToRay(self, x, y)
	return Ray.new(self.CFrame.Position, self.CFrame.LookVector)
end
methods.ViewportPointToRay = methods.ScreenPointToRay
function methods.WorldToViewportPoint(self, p)
	return Vector3.new(0, 0, 1), true
end
M.groundY = 0
M.raycastHook = nil
function methods.Raycast(self, origin, dir, params)
	if M.raycastHook then return M.raycastHook(origin, dir, params) end
	if dir.Y < 0 and origin.Y > M.groundY and origin.Y + dir.Y <= M.groundY then
		return { Position = Vector3.new(origin.X, M.groundY, origin.Z), Instance = workspace_, Normal = Vector3.yAxis, Distance = origin.Y - M.groundY }
	end
	return nil
end
function methods.GetPartBoundsInBox() return {} end

local runService = service("RunService", {
	RenderStepped = Signal.new("RenderStepped"), Heartbeat = Signal.new("Heartbeat"), Stepped = Signal.new("Stepped"),
	IsStudio = function() return true end, IsClient = function() return true end, IsServer = function() return false end,
	IsRunning = function() return true end,
})

M.keyboard, M.mouse, M.touch = true, true, false
M.mouseLocation = Vector2.new(640, 360)
local uis = service("UserInputService", {})
local uisExtra = rawget(uis, "__extra")
uisExtra.InputBegan = Signal.new("InputBegan")
uisExtra.InputEnded = Signal.new("InputEnded")
uisExtra.InputChanged = Signal.new("InputChanged")
uisExtra.TouchTap = Signal.new("TouchTap")
uisExtra.TouchPinch = Signal.new("TouchPinch")
uisExtra.TouchStarted = Signal.new("TouchStarted")
uisExtra.TouchEnded = Signal.new("TouchEnded")
uisExtra.TouchMoved = Signal.new("TouchMoved")
uisExtra.LastInputTypeChanged = Signal.new("LastInputTypeChanged")
uisExtra.GetMouseLocation = function() return M.mouseLocation end
uisExtra.GetLastInputType = function() return Enum.UserInputType.MouseButton1 end
uisExtra.IsKeyDown = function() return false end
setmetatable(uisExtra, {
	__index = function(_, k)
		if k == "KeyboardEnabled" then return M.keyboard elseif k == "MouseEnabled" then return M.mouse
		elseif k == "TouchEnabled" then return M.touch elseif k == "GamepadEnabled" then return false end
		return nil
	end,
})

local cas = service("ContextActionService", {})
M.actions = {}
local casExtra = rawget(cas, "__extra")
casExtra.BindActionAtPriority = function(_, name, fn, touchBtn, priority, ...)
	assert(type(name) == "string" and type(fn) == "function", "BindActionAtPriority args")
	assert(type(priority) == "number", "priority must be number")
	M.actions[name] = { fn = fn, keys = { ... } }
end
casExtra.BindAction = function(_, name, fn, touchBtn, ...)
	M.actions[name] = { fn = fn, keys = { ... } }
end
casExtra.UnbindAction = function(_, name) M.actions[name] = nil end
casExtra.GetButton = function() return nil end
casExtra.SetTitle = function() end
casExtra.SetPosition = function() end

local tweenService = service("TweenService", {})
rawget(tweenService, "__extra").Create = function(_, inst, info, goal)
	assert(typeof_(info) == "TweenInfo", "TweenInfo expected")
	local tw = { Completed = Signal.new("Completed") }
	function tw:Play()
		task.delay(info.Time or 0, function()
			for k, v in goal do inst[k] = v end
			tw.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tw:Cancel() end
	function tw:Pause() end
	return tw
end
tweenService.Name = "TweenService"

local players = service("Players", {})
local localPlayer = newInstance("Player")
localPlayer.Name = "Tester"
rawset(localPlayer, "__extra", { UserId = 1, DevEnableMouseLock = true, Character = nil })
localPlayer.Parent = players
rawget(players, "__extra").LocalPlayer = localPlayer
rawget(players, "__extra").GetPlayers = function() return { localPlayer } end
local playerGui = newInstance("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
local playerScripts = newInstance("PlayerScripts")
playerScripts.Name = "PlayerScripts"
playerScripts.Parent = localPlayer
function methods.GetMouse() return { Hit = CFrame.identity, Target = nil, X = 0, Y = 0 } end

service("ReplicatedStorage", {})
service("ServerScriptService", {})
service("StarterPlayer", {})
service("StarterGui", { SetCore = function() end, GetCore = function() return nil end })
service("Lighting", {})
service("SoundService", {})
service("ProximityPromptService", { PromptTriggered = Signal.new("PromptTriggered") })
service("CollectionService", { GetTagged = function() return {} end, AddTag = function() end, HasTag = function() return false end })
service("Debris", { AddItem = function() end })
service("GuiService", { GetGuiInset = function() return Vector2.new(0, 58), Vector2.zero end })
service("HttpService", { JSONEncode = function() return "{}" end, GenerateGUID = function() return "guid" end })

rawset(game, "__extra", {
	GetService = function(_, name)
		local s = services[name]
		if not s then error("GetService: нет сервиса " .. tostring(name) .. " в моке", 2) end
		return s
	end,
	Workspace = workspace_,
})

-- ───────────────────────── загрузка исходников ─────────────────────────

local moduleCache = {}
local env -- окружение для скриптов

local function requireModule(ms)
	if type(ms) == "string" then
		return require(ms)
	end
	assert(typeof_(ms) == "Instance" and ms:IsA("ModuleScript"), "require: ожидался ModuleScript")
	if moduleCache[ms] ~= nil then
		return moduleCache[ms]
	end
	local src = rawget(ms, "__source")
	assert(src, "у ModuleScript нет исходника: " .. ms:GetFullName())
	local fn, err = loadstring(src, "=" .. ms:GetFullName())
	if not fn then error(err, 0) end
	local e = setmetatable({ script = ms }, { __index = env })
	setfenv(fn, e)
	local result = fn()
	assert(result ~= nil, "модуль ничего не вернул: " .. ms:GetFullName())
	moduleCache[ms] = result
	return result
end

local fakeOs = setmetatable({ clock = function() return now end, time = function() return now end }, { __index = os })
env = setmetatable({
	game = game, workspace = workspace_, Workspace = workspace_, script = nil,
	Instance = Instance, Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, Color3 = Color3,
	UDim = UDim, UDim2 = UDim2, Enum = Enum, TweenInfo = TweenInfo, NumberRange = NumberRange,
	NumberSequence = NumberSequence, ColorSequence = ColorSequence, NumberSequenceKeypoint = NumberSequenceKeypoint,
	ColorSequenceKeypoint = ColorSequenceKeypoint, Rect = Rect, Ray = Ray, Font = Font, RaycastParams = RaycastParams,
	task = task, typeof = typeof_, require = requireModule, os = fakeOs, tick = function() return now end,
	time = function() return now end, wait = task.wait, delay = task.delay, spawn = task.spawn,
	warn = function(...) print("WARN", ...) end,
	_G = {}, shared = {},
}, { __index = _G })
M.env = env
M.G = env._G

-- Rojo-правила: папка → Folder, X.luau → ModuleScript, X.client.luau → LocalScript, X.server.luau → Script
function M.mount(files, root)
	for path, src in files do
		local parts = string.split(path, "/")
		local parent = game:GetService(parts[1])
		for i = 2, #parts - 1 do
			local child = parent:FindFirstChild(parts[i])
			if not child then
				child = newInstance("Folder")
				child.Name = parts[i]
				child.Parent = parent
			end
			parent = child
		end
		local fname = parts[#parts]
		local cls, name = "ModuleScript", nil
		if fname:match("%.client%.luau$") then cls, name = "LocalScript", fname:gsub("%.client%.luau$", "")
		elseif fname:match("%.server%.luau$") then cls, name = "Script", fname:gsub("%.server%.luau$", "")
		else name = fname:gsub("%.luau$", "") end
		local inst = newInstance(cls)
		inst.Name = name
		rawset(inst, "__source", src)
		inst.Parent = parent
	end
end

function M.runScript(inst)
	local src = rawget(inst, "__source")
	local fn, err = loadstring(src, "=" .. inst:GetFullName())
	if not fn then error(err, 0) end
	setfenv(fn, setmetatable({ script = inst }, { __index = env }))
	task.spawn(fn)
end

-- ───────────────────────── управление тестом ─────────────────────────

M.game = game
M.player = localPlayer
M.playerGui = playerGui
M.camera = camera
M.task = task
M.Vector3, M.Vector2, M.CFrame, M.Color3, M.UDim2, M.Enum = Vector3, Vector2, CFrame, Color3, UDim2, Enum

function M.now() return now end

-- Продвинуть время на dt секунд кадрами по 1/60
function M.step(dt, frame)
	frame = frame or 1 / 60
	local t = 0
	repeat
		local d = math.min(frame, dt - t)
		now += d
		t += d
		flushQueue()
		runService.RenderStepped:Fire(d)
		runService.Heartbeat:Fire(d)
	until t >= dt - 1e-9
	flushQueue()
end

function M.setCharacter(pos)
	local char = rawget(localPlayer, "__extra").Character
	if not char then
		char = newInstance("Model")
		char.Name = "Tester"
		local root = newInstance("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = char
		local hum = newInstance("Humanoid")
		hum.Parent = char
		char.Parent = workspace_
		rawget(localPlayer, "__extra").Character = char
	end
	char.HumanoidRootPart.CFrame = CFrame.new(pos)
	return char
end

-- Нажатие клавиши через ContextActionService (то, что забиндено) или UserInputService
local function fakeInput(keyCode, state)
	return { KeyCode = keyCode, UserInputState = state, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero, Delta = Vector3.zero }
end
function M.key(keyCode, holdSeconds)
	local handled = false
	for name, a in table.clone(M.actions) do
		for _, k in a.keys do
			if k == keyCode then
				a.fn(name, Enum.UserInputState.Begin, fakeInput(keyCode, Enum.UserInputState.Begin))
				handled = true
				if holdSeconds and holdSeconds > 0 then M.step(holdSeconds) end
				local cur = M.actions[name]
				if cur then cur.fn(name, Enum.UserInputState.End, fakeInput(keyCode, Enum.UserInputState.End)) end
			end
		end
	end
	if not handled then
		uisExtra.InputBegan:Fire(fakeInput(keyCode, Enum.UserInputState.Begin), false)
		if holdSeconds and holdSeconds > 0 then M.step(holdSeconds) end
		uisExtra.InputEnded:Fire(fakeInput(keyCode, Enum.UserInputState.End), false)
	end
	M.step(1 / 60)
	return handled
end

-- Нажать GUI-кнопку
function M.click(btn)
	assert(btn, "click: кнопка nil")
	assert(btn:IsA("GuiButton"), "click: не кнопка " .. btn:GetFullName())
	local s = rawget(btn, "__signals")
	for _, ev in { "Activated", "MouseButton1Click" } do
		if s[ev] then s[ev]:Fire() end
	end
	M.step(1 / 60)
end

-- Удержание GUI-кнопки (InputBegan/InputEnded мышью)
function M.hold(btn, seconds)
	local inp = { UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin, Position = Vector3.zero, KeyCode = Enum.KeyCode.Unknown }
	btn.InputBegan:Fire(inp)
	M.step(seconds)
	inp.UserInputState = Enum.UserInputState.End
	btn.InputEnded:Fire(inp)
	M.step(1 / 60)
end

-- Ввод мышью по GUI: нажать в точке abs (экранные координаты GUI), протащить к to (необязательно), отпустить
local function mouseInput(t, pos, state)
	return { UserInputType = t, UserInputState = state, Position = Vector3.new(pos.X, pos.Y, 0), Delta = Vector3.zero, KeyCode = Enum.KeyCode.Unknown }
end
function M.mouseDrag(gui, from, to, steps)
	local down = mouseInput(Enum.UserInputType.MouseButton1, from, Enum.UserInputState.Begin)
	gui.InputBegan:Fire(down)
	M.step(1 / 60)
	if to then
		steps = steps or 8
		for k = 1, steps do
			local p = from:Lerp(to, k / steps)
			uisExtra.InputChanged:Fire(mouseInput(Enum.UserInputType.MouseMovement, p, Enum.UserInputState.Change), false)
			M.step(1 / 60)
		end
	end
	local up = mouseInput(Enum.UserInputType.MouseButton1, to or from, Enum.UserInputState.End)
	gui.InputEnded:Fire(up)
	uisExtra.InputEnded:Fire(up, false)
	M.step(1 / 60)
end

function M.trigger(prompt)
	assert(prompt and prompt:IsA("ProximityPrompt"), "trigger: не ProximityPrompt")
	assert(prompt.Enabled, "trigger: промпт выключен — " .. prompt:GetFullName())
	assert(prompt.MaxActivationDistance > 0, "trigger: подсказка недоступна (MaxActivationDistance = 0) — " .. prompt:GetFullName())
	prompt.Triggered:Fire(localPlayer)
	M.step(1 / 60)
end

-- Поиск: все видимые TextLabel/TextButton под root с текстом по шаблону
local function visibleChain(i)
	local p = i
	while p do
		local cls = rawget(p, "__class")
		if isA(cls, "GuiObject") and p.Visible == false then return false end
		if (cls == "ScreenGui" or cls == "SurfaceGui" or cls == "BillboardGui") and p.Enabled == false then return false end
		p = rawget(p, "__parent")
	end
	return true
end
M.visible = visibleChain
local function stripRich(s) return (s:gsub("<[^>]->", "")) end
M.stripRich = stripRich
function M.findText(root, pattern, opts)
	opts = opts or {}
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and (opts.hidden or visibleChain(d)) then
			local t = stripRich(d.Text)
			if t:find(pattern, 1, opts.plain) then table.insert(out, d) end
		end
	end
	return out
end
function M.button(root, pattern)
	local list = M.findText(root, pattern, { plain = true })
	for _, b in list do
		if b:IsA("TextButton") then return b end
	end
	return nil
end
function M.allText(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and visibleChain(d) and d.Text ~= "" then
			table.insert(out, stripRich(d.Text))
		end
	end
	return table.concat(out, " | ")
end

return M
