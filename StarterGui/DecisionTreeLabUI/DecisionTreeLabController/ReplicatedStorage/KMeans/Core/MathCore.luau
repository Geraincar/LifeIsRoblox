
local MathCore = {}


-- ============================================================
-- SQUARED EUCLIDEAN DISTANCE
-- ============================================================

function MathCore.dist2(a, b)

	local dx =
		a.X - b.X

	local dy =
		a.Y - b.Y


	return
		dx * dx
		+
		dy * dy

end


-- ============================================================
-- ASSIGN POINTS TO NEAREST CENTROID
-- ============================================================

function MathCore.assign(points, centers)

	local labels =
		table.create(
			#points
		)

	local inertia = 0


	for i, point in ipairs(points) do

		local bestCluster = 1

		local bestDistance =
			MathCore.dist2(
				point,
				centers[1]
			)


		for cluster = 2, #centers do

			local distance =
				MathCore.dist2(
					point,
					centers[cluster]
				)


			if distance < bestDistance then

				bestDistance =
					distance

				bestCluster =
					cluster

			end

		end


		labels[i] =
			bestCluster


		inertia +=
			bestDistance

	end


	return
		labels,
		inertia

end


-- ============================================================
-- CALCULATE CLUSTER MEANS
-- ============================================================

function MathCore.means(
	points,
	labels,
	k,
	fallbackCenters
)

	local sumX = {}
	local sumY = {}
	local counts = {}


	for cluster = 1, k do

		sumX[cluster] = 0
		sumY[cluster] = 0
		counts[cluster] = 0

	end


	for i, point in ipairs(points) do

		local cluster =
			labels[i]


		if cluster then

			sumX[cluster] +=
				point.X

			sumY[cluster] +=
				point.Y

			counts[cluster] +=
				1

		end

	end


	local means = {}


	for cluster = 1, k do

		if counts[cluster] > 0 then

			means[cluster] =
				Vector2.new(
					sumX[cluster]
						/
						counts[cluster],

					sumY[cluster]
						/
						counts[cluster]
				)

		else

			means[cluster] =
				fallbackCenters[cluster]

		end

	end


	return
		means,
		counts

end


-- ============================================================
-- COUNT CHANGED ASSIGNMENTS
-- ============================================================

function MathCore.changedCount(
	oldLabels,
	newLabels
)

	local changed = 0


	for i = 1, #newLabels do

		if
			oldLabels[i]
			~=
			newLabels[i]
		then

			changed += 1

		end

	end


	return changed

end


-- ============================================================
-- INERTIA FOR EXISTING LABELS
-- ============================================================

function MathCore.inertia(
	points,
	labels,
	centers
)

	local total = 0


	for i, point in ipairs(points) do

		local cluster =
			labels[i]


		if cluster then

			total +=
				MathCore.dist2(
					point,
					centers[cluster]
				)

		end

	end


	return total

end


return MathCore

