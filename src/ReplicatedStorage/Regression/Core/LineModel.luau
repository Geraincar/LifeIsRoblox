--!strict
-- LineModel: всё, что табло и клумба показывают о прямой y = m·x + c. Числа — только из MathCore.
-- Прямая вращается вокруг точки (x̄; h) — центра клумбы, поэтому c = h − x̄·m.

export type Snapshot = {
	m: number, h: number, c: number,
	yhat: { number }, e: { number }, sq: { number },
	L: number, mse: number, n: number,
}

local LineModel = {}
LineModel.__index = LineModel

function LineModel.new(MathCore: any, fb: any)
	local self = setmetatable({}, LineModel)
	self.MathCore = MathCore
	self.x = fb.x_m :: { number }
	self.y = fb.y_m :: { number }
	self.n = #fb.x_m
	self.pivotX = fb.pivot_x_m :: number
	self.W = fb.bed_length_m :: number
	self.H = fb.bed_width_m :: number
	local o = MathCore.ols1d(self.x, self.y)
	self.mOpt = o.b1 :: number -- 0,33
	self.cOpt = o.b0 :: number -- 0,675
	self.hOpt = (o.b0 + o.b1 * self.pivotX) :: number -- = ȳ = 1,5
	return self
end

function LineModel.compute(self: any, m: number, h: number): Snapshot
	local MathCore = self.MathCore
	local c = MathCore.lineFromPivot(m, h, self.pivotX)
	local yhat, e, sq = table.create(self.n), table.create(self.n), table.create(self.n)
	for i = 1, self.n do
		yhat[i] = m * self.x[i] + c
		e[i] = self.y[i] - yhat[i]
		sq[i] = e[i] * e[i]
	end
	local mse = MathCore.mseLine(self.x, self.y, m, c)
	return { m = m, h = h, c = c, yhat = yhat, e = e, sq = sq, L = mse * self.n, mse = mse, n = self.n }
end

return LineModel
