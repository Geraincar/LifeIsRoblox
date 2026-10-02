-- Автотест логики 3D experience: Format, BedGeometry, Records, LineModel, Store.
-- Контрольные числа — из раскадровки 3D (references/3d-experience.md).
-- run(mods) → checks, fails; mods = { MathCore, Datasets, Format, BedGeometry, Records, LineModel, Store }
return function(mods)
	local MathCore, D = mods.MathCore, mods.Datasets
	local Format, Geo, Records, LineModel, Store = mods.Format, mods.BedGeometry, mods.Records, mods.LineModel, mods.Store

	local checks, fails = 0, 0
	local function ok(name: string, cond: boolean)
		checks += 1
		if not cond then
			fails += 1
			print("FAIL " .. name)
		end
	end
	local function near(name: string, got: number?, want: number, tol: number?)
		ok(name .. (" (got %s, want %s)"):format(tostring(got), tostring(want)), got ~= nil and math.abs(got - want) <= (tol or 1e-4))
	end
	local function eq(name: string, got: any, want: any)
		ok(name .. (" (got %q, want %q)"):format(tostring(got), tostring(want)), got == want)
	end

	local NB, MINUS = "\u{00A0}", "\u{2212}"

	-- Format
	eq("num 0.566", Format.num(0.566, 3), "0,566")
	eq("signed +", Format.signed(0.26), "+0,26")
	eq("signed −", Format.signed(-0.37), MINUS .. "0,37")
	eq("signed −0", Format.signed(-0.001), "0,00")
	eq("mse unit", Format.mse(0.0982), "0,098" .. NB .. "м²")
	eq("len", Format.len(1), "1,00" .. NB .. "м")
	eq("percent", Format.percent(0.04 / 0.491), "8,1" .. NB .. "%")
	eq("lambda 0", Format.lambda(0), "0")

	-- LineModel: контрольные MSE
	local fb = D.flowerbed
	local lm = LineModel.new(MathCore, fb)
	near("mOpt", lm.mOpt, 0.33, 1e-12)
	near("hOpt = ȳ", lm.hOpt, 1.5, 1e-12)
	near("start MSE (m=0, h=1)", lm:compute(0, 1).mse, 0.566, 1e-9)
	near("best MSE (m=0.33, h=1.5)", lm:compute(0.33, 1.5).mse, 0.0982, 1e-9)
	local best = lm:compute(0.33, 1.5)
	for i, e in { 0.26, -0.37, -0.20, 0.47, -0.16 } do
		near("residual " .. i, best.e[i], e, 1e-9)
	end
	near("L at optimum", best.L, 0.491, 1e-9)
	for _, mh in { { -0.7, 0.3 }, { 0.1, 2.4 }, { 1.2, 1.0 }, { 0.33, 0 } } do
		local m, h = mh[1], mh[2]
		near(("closed form m=%g h=%g"):format(m, h), lm:compute(m, h).mse, 2 * m * m - 1.32 * m + 0.316 + (1.5 - h) ^ 2, 1e-9)
	end

	-- Records: пример записей из раскадровки (h = 1,0)
	local list = {}
	for _, m in { -0.2, 0.0, 0.2, 0.5, 0.8 } do
		local v = Records.validate(list, m, 1.0)
		ok("validate m=" .. m, v)
		list = Records.add(list, { m = m, mse = lm:compute(m, 1.0).mse, h = 1.0 })
	end
	local wantMse = { 0.910, 0.566, 0.382, 0.406, 0.790 }
	for i, r in list do
		near("record mse " .. i, r.mse, wantMse[i], 1e-9)
	end
	local P = Records.fit(MathCore, list)
	near("parabola a", P.a, 2.0, 1e-9)
	near("parabola m*", P.tStar, 0.33, 1e-9)
	near("parabola MSE*", P.vStar, 0.3482, 1e-9)
	local full, why = Records.validate(list, 1.2, 1.0)
	ok("full after 5", not full and why == "full")

	local l2 = { { m = 0.2, mse = 0, h = 1.0 } }
	local v1, r1, other = Records.validate(l2, 0.25, 1.0)
	ok("too close", not v1 and r1 == "too_close" and other == l2[1])
	ok("exactly 0.1 is fine", (Records.validate(l2, 0.3, 1.0)))
	ok("other height is free", (Records.validate(l2, 0.2, 1.05)))
	eq("atHeight filters", #Records.atHeight({ { m = 0, mse = 0, h = 1 }, { m = 0, mse = 0, h = 1.05 } }, 1.05), 1)
	ok("oneSide below", Records.oneSide({ { m = 0, mse = 0, h = 1 }, { m = 0.2, mse = 0, h = 1 } }, 0.33))
	ok("not oneSide", not Records.oneSide({ { m = 0, mse = 0, h = 1 }, { m = 0.5, mse = 0, h = 1 } }, 0.33))
	local big = {}
	for i = 1, 25 do
		big = Records.add(big, { m = i * 0.1, mse = 0, h = if i <= 22 then 2.0 else 1.0 })
	end
	ok("cap keeps current height", #big == Records.MAX_TOTAL and #Records.atHeight(big, 1.0) == 3)

	-- BedGeometry
	local x0, y0, x1, y1 = Geo.clipLine(0, 1, 5, 3)
	ok("clip flat", x0 == 0 and y0 == 1 and x1 == 5 and y1 == 1)
	x0, y0, x1, y1 = Geo.clipLine(1.5, 1 - 2.5 * 1.5, 5, 3)
	near("clip steep x0", x0, 1.8333333, 1e-6)
	near("clip steep y0", y0, 0, 1e-9)
	near("clip steep x1", x1, 3.8333333, 1e-6)
	near("clip steep y1", y1, 3, 1e-9)
	ok("clip outside", Geo.clipLine(0, 3.5, 5, 3) == nil)
	local cx, cy, side = Geo.square(0.5, 1.1, 0.84, 2.5, 1)
	near("square1 cx", cx, 0.37, 1e-9)
	near("square1 cy", cy, 0.97, 1e-9)
	near("square1 side", side, 0.26, 1e-9)
	cx = Geo.square(4.5, 2.0, 2.16, 2.5, 1)
	near("square5 goes right", cx, 4.58, 1e-9)
	local _, ty0, _, ty1 = Geo.thread(2.5, 1.3, 1.5, 0.5)
	ok("thread half", ty0 == 1.3 and math.abs(ty1 - 1.4) < 1e-12)
	local a, b, c, d = Geo.clipSegment(-2, 1, 2, 1, -1, 1.5, 0, 2)
	ok("clipSegment", a == -1 and b == 1 and c == 1.5 and d == 1)
	ok("clipSegment outside", Geo.clipSegment(-2, 3, 2, 3, -1, 1.5, 0, 2) == nil)
	near("distToRect inside", Geo.distToRect(3, -2, 10, 6), 0, 1e-12)
	near("distToRect corner", Geo.distToRect(13, 10, 10, 6), 5, 1e-12)

	-- Store
	local st = Store.new({ m = 0, records = {} })
	local seen, any = nil, 0
	local conn = st.Changed:Connect("m", function(v)
		seen = v
	end)
	st.Changed:Connect("*", function()
		any += 1
	end)
	st:set("m", 0.5)
	st:set("m", 0.5) -- без изменений — без события
	eq("store changed", seen, 0.5)
	eq("store * count", any, 1)
	conn.Disconnect()
	st:set("m", 0.7)
	eq("store disconnect", seen, 0.5)
	st:patch({ h = 1.5, honey = 2 })
	local ser = st:serialize()
	ok("serialize", ser.m == 0.7 and ser.h == 1.5 and ser.honey == 2 and ser.records ~= st:get("records"))

	print(("Logic3D: %d/%d проверок пройдено"):format(checks - fails, checks))
	return checks, fails
end
