local M = {}
M.Labels = {"A", "B", "C", "D"}
M.Features = {
    {Id="water_pct", Name="Влажность, %", Min=20, Max=50, Step=1},
    {Id="sugar_pct", Name="Сахар, %", Min=40, Max=80, Step=1},
    {Id="acidity", Name="Кислотность", Min=3, Max=5.5, Step=0.1},
    {Id="viscosity", Name="Вязкость", Min=0.2, Max=0.9, Step=0.05},
    {Id="temperature", Name="Температура", Min=25, Max=37, Step=1},
    {Id="aroma", Name="Аромат", Min=0, Max=1, Step=0.05},
    {Id="color", Name="Цвет", Min=0, Max=1, Step=0.05},
    {Id="pollen_density", Name="Пыльца", Min=0, Max=1, Step=0.05},
}
local ids = {}
for _, feature in ipairs(M.Features) do table.insert(ids, feature.Id) end
local function rounded(x) return math.floor(x*10+0.5)/10 end
function M.Generate(seed, count)
    local rng, rows = Random.new(seed), {}
    for i=1,count do
        local row = {
            Id = string.format("B-%03d", i),
            water_pct = rounded(rng:NextNumber(25,49)),
            sugar_pct = rounded(rng:NextNumber(45,76)),
            acidity = rounded(rng:NextNumber(3.2,5.2)),
            viscosity = rounded(rng:NextNumber(0.2,0.8)),
            temperature = rounded(rng:NextNumber(28,34)),
            aroma = rounded(rng:NextNumber(0,1)),
            color = rounded(rng:NextNumber(0,1)),
            pollen_density = rounded(rng:NextNumber(0,1)),
            Weight = 1,
        }
        if row.water_pct > 38 then row.Label = "A"
        elseif row.sugar_pct < 60 then row.Label = "B"
        elseif row.acidity < 4.2 then row.Label = "C"
        else row.Label = "D" end
        if rng:NextNumber() < 0.06 then row.Label = M.Labels[rng:NextInteger(1,4)] end
        rows[i] = row
    end
    return rows
end
function M.PredictManual(row, rules, leaves)
    for i, rule in ipairs(rules) do
        local value = row[rule.Feature]
        if value then
            local match = rule.Op == ">" and value > rule.Threshold or rule.Op == "<" and value < rule.Threshold
            if match then return leaves[i] end
        end
    end
    return leaves[#rules+1]
end
local function majority(rows)
    local weights = {A=0,B=0,C=0,D=0}
    for _, row in ipairs(rows) do weights[row.Label] += row.Weight or 1 end
    local best, maxWeight = "A", -1
    for _, label in ipairs(M.Labels) do
        if weights[label] > maxWeight then best, maxWeight = label, weights[label] end
    end
    return best
end
local function gini(rows)
    local counts, total = {A=0,B=0,C=0,D=0}, 0
    for _, row in ipairs(rows) do
        local w = row.Weight or 1
        counts[row.Label] += w
        total += w
    end
    if total == 0 then return 0, 0 end
    local value = 1
    for _, label in ipairs(M.Labels) do value -= (counts[label]/total)^2 end
    return value, total
end
function M.Impurity(rows, kind)
    local counts = {A=0,B=0,C=0,D=0}
    for _, row in ipairs(rows) do counts[row.Label] += 1 end
    local n = #rows
    if n == 0 then return 0 end
    local result = kind == "Entropy" and 0 or 1
    for _, label in ipairs(M.Labels) do
        local p = counts[label]/n
        if p > 0 then
            if kind == "Entropy" then result -= p*math.log(p,2)
            else result -= p*p end
        end
    end
    return result
end
local function build(rows, depth, maxDepth, rng, randomized)
    local baseScore, baseWeight = gini(rows)
    local fallback = {Leaf=majority(rows)}
    if depth >= maxDepth or #rows < 4 or baseScore < 0.001 then return fallback end
    local features = table.clone(ids)
    if randomized then
        for i=#features,2,-1 do
            local j = rng:NextInteger(1,i)
            features[i],features[j] = features[j],features[i]
        end
    end
    local featureLimit = randomized and 3 or #features
    local bestScore, bestFeature, bestThreshold, bestLeft, bestRight = baseScore
    for fi=1,featureLimit do
        local feature = features[fi]
        local sorted = table.create(#rows)
        for i,row in ipairs(rows) do sorted[i] = row[feature] end
        table.sort(sorted)
        for i=1,#sorted-1 do
            if sorted[i] < sorted[i+1] then
                local threshold = (sorted[i]+sorted[i+1])/2
                local left,right = {},{}
                for _,row in ipairs(rows) do
                    if row[feature] <= threshold then table.insert(left,row)
                    else table.insert(right,row) end
                end
                if #left > 0 and #right > 0 then
                    local lg,lw = gini(left)
                    local rg,rw = gini(right)
                    local score = (lg*lw + rg*rw)/baseWeight
                    if score < bestScore - 0.000001 then
                        bestScore,bestFeature,bestThreshold,bestLeft,bestRight = score,feature,threshold,left,right
                    end
                end
            end
        end
    end
    if not bestFeature then return fallback end
    return {
        Feature=bestFeature, Threshold=bestThreshold,
        Left=build(bestLeft,depth+1,maxDepth,rng,randomized),
        Right=build(bestRight,depth+1,maxDepth,rng,randomized),
    }
end
function M.PredictTree(row, node)
    while node and not node.Leaf do
        node = row[node.Feature] <= node.Threshold and node.Left or node.Right
    end
    return node and node.Leaf or "A"
end
function M.TrainForest(rows, count, depth)
    local rng = Random.new(1841 + count*17 + depth)
    local trees = {}
    for i=1,count do
        local sample = {}
        for j=1,#rows do table.insert(sample, rows[rng:NextInteger(1,#rows)]) end
        trees[i] = build(sample,1,depth,rng,true)
    end
    return trees
end
function M.PredictForest(row, trees)
    local votes = {A=0,B=0,C=0,D=0}
    for _,tree in ipairs(trees) do votes[M.PredictTree(row,tree)] += 1 end
    local best,maxVotes = "A",-1
    for _,label in ipairs(M.Labels) do
        if votes[label] > maxVotes then best,maxVotes = label,votes[label] end
    end
    return best,votes
end
function M.TrainBoost(rows, rounds, depth)
    local weighted = {}
    for i,row in ipairs(rows) do
        weighted[i] = table.clone(row)
        weighted[i].Weight = 1/#rows
    end
    local stages = {}
    for i=1,rounds do
        local tree = build(weighted,1,depth,nil,false)
        local errorRate = 0
        for _,row in ipairs(weighted) do
            if M.PredictTree(row,tree) ~= row.Label then errorRate += row.Weight end
        end
        if errorRate >= 0.75 then break end
        local alpha = errorRate < 0.000001 and 5 or math.log((1-errorRate)/errorRate)+math.log(3)
        table.insert(stages,{Tree=tree,Alpha=alpha,Error=errorRate})
        if errorRate < 0.000001 then break end
        local total = 0
        for _,row in ipairs(weighted) do
            if M.PredictTree(row,tree) ~= row.Label then row.Weight *= math.exp(alpha) end
            total += row.Weight
        end
        for _,row in ipairs(weighted) do row.Weight /= total end
    end
    return stages
end
function M.PredictBoost(row, stages)
    local scores = {A=0,B=0,C=0,D=0}
    for _,stage in ipairs(stages) do scores[M.PredictTree(row,stage.Tree)] += stage.Alpha end
    local best,maxScore = "A",-math.huge
    for _,label in ipairs(M.Labels) do
        if scores[label] > maxScore then best,maxScore = label,scores[label] end
    end
    return best,scores
end
function M.Evaluate(rows,predict)
    local tp,fp,fn = {A=0,B=0,C=0,D=0},{A=0,B=0,C=0,D=0},{A=0,B=0,C=0,D=0}
    local correct = 0
    for _,row in ipairs(rows) do
        local guess = predict(row)
        if guess == row.Label then correct += 1; tp[guess] += 1
        else
            if fp[guess] then fp[guess] += 1 end
            fn[row.Label] += 1
        end
    end
    local byClass,macro = {},0
    for _,label in ipairs(M.Labels) do
        local precision = tp[label]+fp[label] > 0 and tp[label]/(tp[label]+fp[label]) or 0
        local recall = tp[label]+fn[label] > 0 and tp[label]/(tp[label]+fn[label]) or 0
        local f1 = precision+recall > 0 and 2*precision*recall/(precision+recall) or 0
        byClass[label] = {Precision=precision,Recall=recall,F1=f1,TP=tp[label],FP=fp[label],FN=fn[label]}
        macro += f1/4
    end
    return {Accuracy=correct/#rows,MacroF1=macro,ByClass=byClass,Correct=correct,Total=#rows}
end
return M
