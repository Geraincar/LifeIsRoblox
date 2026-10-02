local PopulationModel = {}


local function clamp01(value)
	return math.clamp(value, 0, 1)
end


function PopulationModel.Compute(population)

	local aliveCount = 0

	local workforceSum = 0
	local forageSum = 0
	local hiveWorkSum = 0

	local consumptionSum = 0
	local healthRiskSum = 0


	for _, bee in pairs(population.Bees) do

		if bee.Alive then

			aliveCount += 1


			local productivity =
				clamp01(bee.Productivity)

			local consumptionMultiplier = 1


			if bee.CurrentJob == "Forage" then

				workforceSum += productivity
				forageSum += productivity


			elseif bee.CurrentJob == "HiveWork" then

				workforceSum += productivity
				hiveWorkSum += productivity


			elseif bee.CurrentJob == "Rest" then

				consumptionMultiplier = 0.75


			elseif bee.CurrentJob == "Quarantine" then

				consumptionMultiplier = 0.6

			end


			consumptionSum +=
				bee.Consumption
				* consumptionMultiplier


			local healthRisk =
				1 - clamp01(bee.Health)


			-- Изолированная пчела создаёт
			-- гораздо меньший риск для улья.
			if bee.CurrentJob == "Quarantine" then
				healthRisk *= 0.2
			end


			healthRiskSum += healthRisk

		end

	end


	if aliveCount == 0 then

		return {
			Workforce = 0,
			Supply = 0,
			Processing = 0,
			Consumption = 1,
			HealthRisk = 0,
		}

	end


	return {

		Workforce =
			workforceSum / aliveCount,

		Supply =
			forageSum / aliveCount,

		Processing =
			hiveWorkSum / aliveCount,

		Consumption =
			consumptionSum / aliveCount,

		HealthRisk =
			healthRiskSum / aliveCount,

	}

end


return PopulationModel