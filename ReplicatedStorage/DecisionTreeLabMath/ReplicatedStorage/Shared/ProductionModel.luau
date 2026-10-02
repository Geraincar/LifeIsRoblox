local ProductionModel = {}


local function clamp01(value)
	return math.clamp(value, 0, 1)
end


function ProductionModel.Compute(state)

	local baseRate =
		state.Production.BaseHoneyRate

	local efficiency =
		state.Stats.Efficiency


	local workforce =
		clamp01(
			state.Stats.Workforce
		)

	local supply =
		clamp01(
			state.Stats.Supply
		)

	local processing =
		clamp01(
			state.Stats.Processing
		)

	local healthRisk =
		clamp01(
			state.Stats.HealthRisk
		)

	local consumption =
		math.max(
			state.Stats.Consumption,
			0.1
		)


	-- Если много сборщиков, но некому
	-- обрабатывать сырьё, возникает bottleneck.
	
	-- HIVE_OPTIMIZATION_PATCH
	local optimization = state.Optimization or {}
	supply = math.clamp(supply * (optimization.SupplyFactor or 1), 0, 1)
	processing = math.clamp(processing * (optimization.ProcessingFactor or 1), 0, 1)

local flow =
		math.min(
			supply,
			processing
		)


	-- Оставляем небольшой базовый output,
	-- чтобы производство никогда резко не стало 0.
	local flowFactor =
		0.25
		+ 0.75 * flow


	local workforceFactor =
		0.5
		+ 0.5 * workforce


	local healthFactor =
		1
	- 0.5 * healthRisk


	local consumptionFactor =
		1 / math.max(
			0.75,
			consumption
		)


	local honeyRate =
		baseRate
		* efficiency
		* flowFactor
		* workforceFactor
		* healthFactor
		* consumptionFactor


	return {

		HoneyRate = honeyRate,

	}

end


return ProductionModel