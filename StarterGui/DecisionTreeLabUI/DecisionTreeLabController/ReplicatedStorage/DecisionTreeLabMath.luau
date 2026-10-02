local M={}
M.Features={
    {Id="water_pct",Name="Вода",Min=20,Max=55,Step=0.1,Decimals=2},
    {Id="sugar_pct",Name="Сахар",Min=35,Max=80,Step=0.1,Decimals=2},
    {Id="acidity",Name="Кислотность",Min=2.5,Max=5.5,Step=0.01,Decimals=3},
    {Id="viscosity",Name="Вязкость",Min=0.2,Max=0.9,Step=0.01,Decimals=3},
    {Id="temperature",Name="Температура",Min=20,Max=36,Step=0.1,Decimals=2},
    {Id="aroma",Name="Аромат",Min=0,Max=1,Step=0.01,Decimals=3},
    {Id="color",Name="Цвет",Min=0,Max=1,Step=0.01,Decimals=3},
    {Id="pollen_density",Name="Пыльца",Min=0,Max=1,Step=0.01,Decimals=3},
}
M.Labels={"A","B","C","D"}
local scales={100,100,1000,1000,100,1000,1000,1000}
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local valueByByte={}
for i=1,#alphabet do valueByByte[string.byte(alphabet,i)]=i-1 end

function M.DecodeDataset(encoded,expected)
    local bytes={}
    local accumulator,bitCount=0,0
    for i=1,#encoded do
        local value=valueByByte[string.byte(encoded,i)]
        if value then
            accumulator=accumulator*64+value
            bitCount=bitCount+6
            if bitCount>=8 then
                bitCount=bitCount-8
                local divisor=2^bitCount
                bytes[#bytes+1]=math.floor(accumulator/divisor)
                accumulator=accumulator%divisor
            end
        end
    end
    assert(#bytes==expected*17,"Dataset byte count mismatch")
    local data={train={},validation={},test={}}
    local splits={"train","validation","test"}
    local cursor=1
    for i=1,expected do
        local features={}
        for f=1,8 do
            local high,low=bytes[cursor],bytes[cursor+1]
            features[f]=(high*256+low)/scales[f]
            cursor=cursor+2
        end
        local code=bytes[cursor]
        cursor=cursor+1
        local label=code%4+1
        local split=splits[math.floor(code/4)+1]
        assert(split and label>=1 and label<=4,"Dataset class or split invalid")
        local row={f=features,y=label,id=string.format("B%05d",i)}
        table.insert(data[split],row)
    end
    return data
end

local function isInteger(n,low,high)
    return type(n)=="number" and n%1==0 and n>=low and n<=high
end
local function matches(value,op,threshold)
    if op==">" then return value>threshold end
    if op==">=" then return value>=threshold end
    if op=="<" then return value<threshold end
    return value<=threshold
end
function M.ValidateGraph(graph)
    assert(type(graph)=="table" and type(graph.nodes)=="table" and isInteger(graph.root,1,100000),"Invalid tree")
    local nodes=graph.nodes
    local visited={}
    local count=0
    local function visit(id,depth)
        assert(isInteger(id,1,100000) and depth<=32 and not visited[id],"Tree is too deep or cyclic")
        local node=nodes[tostring(id)]
        assert(type(node)=="table","Missing tree node")
        visited[id]=true
        count=count+1
        assert(count<=255,"Tree has more than 255 nodes")
        if node.kind=="leaf" then
            assert(isInteger(node.class,1,4),"Invalid leaf processor")
        elseif node.kind=="split" then
            assert(isInteger(node.feature,1,8),"Invalid split feature")
            assert(node.op==">" or node.op==">=" or node.op=="<" or node.op=="<=","Invalid split operator")
            local meta=M.Features[node.feature]
            assert(type(node.threshold)=="number" and node.threshold==node.threshold and node.threshold>=meta.Min and node.threshold<=meta.Max,"Invalid split threshold")
            visit(node.yes,depth+1)
            visit(node.no,depth+1)
        else error("Unknown tree node kind") end
    end
    visit(graph.root,1)
    local supplied=0
    for _ in pairs(nodes) do supplied=supplied+1 end
    assert(supplied==count,"Orphan tree nodes are not allowed")
    return graph
end
function M.PredictGraph(row,graph)
    local id=graph.root
    while true do
        local node=graph.nodes[tostring(id)]
        if node.kind=="leaf" then return node.class end
        id=matches(row.f[node.feature],node.op,node.threshold) and node.yes or node.no
    end
end
function M.Metrics(rows,predict)
    assert(#rows>0,"Empty evaluation split")
    local tp,fp,fn={0,0,0,0},{0,0,0,0},{0,0,0,0}
    local correct=0
    for _,row in ipairs(rows) do
        local guessed=predict(row)
        assert(isInteger(guessed,1,4),"Model returned invalid class")
        if guessed==row.y then
            correct=correct+1
            tp[guessed]=tp[guessed]+1
        else
            fp[guessed]=fp[guessed]+1
            fn[row.y]=fn[row.y]+1
        end
    end
    local byClass,macro={},0
    for c=1,4 do
        local denominator=2*tp[c]+fp[c]+fn[c]
        local f1=denominator>0 and 2*tp[c]/denominator or 0
        byClass[c]=f1
        macro=macro+f1/4
    end
    return {Accuracy=correct/#rows,MacroF1=macro,ByClass=byClass,Correct=correct,Total=#rows}
end

local function classificationTree(rows,depth,maxDepth,rng,randomized)
    local counts={0,0,0,0}
    for _,row in ipairs(rows) do counts[row.y]=counts[row.y]+1 end
    local majority,bestCount=1,-1
    for c=1,4 do if counts[c]>bestCount then majority,bestCount=c,counts[c] end end
    if depth>=maxDepth or #rows<8 or bestCount==#rows then return {leaf=majority} end
    local candidates={1,2,3,4,5,6,7,8}
    if randomized then
        for i=8,2,-1 do
            local j=rng:NextInteger(1,i)
            candidates[i],candidates[j]=candidates[j],candidates[i]
        end
    end
    local bestScore=math.huge
    local bestFeature,bestThreshold
    local featureCount=randomized and 3 or 8
    for ci=1,featureCount do
        local feature=candidates[ci]
        local ordered=table.clone(rows)
        table.sort(ordered,function(a,b) return a.f[feature]<b.f[feature] end)
        local left={0,0,0,0}
        local right=table.clone(counts)
        for i=1,#ordered-1 do
            local label=ordered[i].y
            left[label]=left[label]+1
            right[label]=right[label]-1
            local nLeft,nRight=i,#ordered-i
            if ordered[i].f[feature]<ordered[i+1].f[feature] and nLeft>=4 and nRight>=4 then
                local leftSquare,rightSquare=0,0
                for c=1,4 do
                    leftSquare=leftSquare+left[c]*left[c]
                    rightSquare=rightSquare+right[c]*right[c]
                end
                local score=nLeft-leftSquare/nLeft+nRight-rightSquare/nRight
                if score<bestScore-0.0000001 then
                    bestScore=score
                    bestFeature=feature
                    bestThreshold=(ordered[i].f[feature]+ordered[i+1].f[feature])/2
                end
            end
        end
    end
    if not bestFeature then return {leaf=majority} end
    local leftRows,rightRows={},{}
    for _,row in ipairs(rows) do
        if row.f[bestFeature]<=bestThreshold then table.insert(leftRows,row)
        else table.insert(rightRows,row) end
    end
    return {feature=bestFeature,threshold=bestThreshold,
        left=classificationTree(leftRows,depth+1,maxDepth,rng,randomized),
        right=classificationTree(rightRows,depth+1,maxDepth,rng,randomized)}
end
function M.TrainForest(rows,count,depth)
    assert(isInteger(count,3,11) and isInteger(depth,2,5),"Invalid forest controls")
    local rng=Random.new(1841+count*17+depth)
    local trees={}
    for i=1,count do
        local sample={}
        for j=1,#rows do sample[j]=rows[rng:NextInteger(1,#rows)] end
        trees[i]=classificationTree(sample,0,depth,rng,true)
        if i%2==0 then task.wait() end
    end
    return trees
end
local function predictClassification(row,node)
    while not node.leaf do
        node=row.f[node.feature]<=node.threshold and node.left or node.right
    end
    return node.leaf
end
function M.PredictForest(row,trees)
    local votes={0,0,0,0}
    for _,tree in ipairs(trees) do
        local label=predictClassification(row,tree)
        votes[label]=votes[label]+1
    end
    local best=1
    for c=2,4 do if votes[c]>votes[best] then best=c end end
    return best,votes
end

local function regressionTree(rows,indices,targets,depth,maxDepth)
    local total=0
    for _,index in ipairs(indices) do total=total+targets[index] end
    local mean=total/#indices
    if depth>=maxDepth or #indices<30 then return {value=mean} end
    local bestGain=0.00000001
    local bestFeature,bestThreshold
    local bins=16
    for feature=1,8 do
        local meta=M.Features[feature]
        local span=meta.Max-meta.Min
        local binCounts,binSums={},{}
        for b=1,bins do binCounts[b],binSums[b]=0,0 end
        for _,index in ipairs(indices) do
            local value=rows[index].f[feature]
            local bucket=math.clamp(math.floor((value-meta.Min)/span*bins)+1,1,bins)
            binCounts[bucket]=binCounts[bucket]+1
            binSums[bucket]=binSums[bucket]+targets[index]
        end
        local leftCount,leftSum=0,0
        for b=1,bins-1 do
            leftCount=leftCount+binCounts[b]
            leftSum=leftSum+binSums[b]
            local rightCount=#indices-leftCount
            if leftCount>=15 and rightCount>=15 then
                local rightSum=total-leftSum
                local gain=leftSum*leftSum/leftCount+rightSum*rightSum/rightCount-total*total/#indices
                if gain>bestGain then
                    bestGain=gain
                    bestFeature=feature
                    bestThreshold=meta.Min+span*b/bins
                end
            end
        end
    end
    if not bestFeature then return {value=mean} end
    local left,right={},{}
    for _,index in ipairs(indices) do
        if rows[index].f[bestFeature]<bestThreshold then table.insert(left,index)
        else table.insert(right,index) end
    end
    if #left<15 or #right<15 then return {value=mean} end
    return {feature=bestFeature,threshold=bestThreshold,
        left=regressionTree(rows,left,targets,depth+1,maxDepth),
        right=regressionTree(rows,right,targets,depth+1,maxDepth)}
end
local function predictRegression(row,node)
    while node.value==nil do
        node=row.f[node.feature]<node.threshold and node.left or node.right
    end
    return node.value
end
function M.TrainGradientBoosting(rows,rounds,depth)
    assert(isInteger(rounds,10,60) and rounds%10==0 and isInteger(depth,1,3),"Invalid gradient boosting controls")
    local priors={0,0,0,0}
    for _,row in ipairs(rows) do priors[row.y]=priors[row.y]+1 end
    local base={}
    for c=1,4 do base[c]=math.log(math.max(priors[c]/#rows,0.000001)) end
    local logits={}
    local indices={}
    for i=1,#rows do logits[i]=table.clone(base); indices[i]=i end
    local stages={}
    local rate=0.2
    for round=1,rounds do
        local residuals={{},{},{},{}}
        for i,row in ipairs(rows) do
            local maximum=math.max(logits[i][1],logits[i][2],logits[i][3],logits[i][4])
            local exponents={}
            local denominator=0
            for c=1,4 do
                exponents[c]=math.exp(logits[i][c]-maximum)
                denominator=denominator+exponents[c]
            end
            for c=1,4 do residuals[c][i]=(row.y==c and 1 or 0)-exponents[c]/denominator end
        end
        local stage={}
        for c=1,4 do
            local tree=regressionTree(rows,indices,residuals[c],0,depth)
            stage[c]=tree
            for i,row in ipairs(rows) do
                logits[i][c]=logits[i][c]+rate*predictRegression(row,tree)
            end
        end
        stages[round]=stage
        if round%5==0 then task.wait() end
    end
    return {base=base,stages=stages,rate=rate}
end
function M.PredictGradientBoosting(row,model)
    local scores=table.clone(model.base)
    for _,stage in ipairs(model.stages) do
        for c=1,4 do scores[c]=scores[c]+model.rate*predictRegression(row,stage[c]) end
    end
    local best=1
    for c=2,4 do if scores[c]>scores[best] then best=c end end
    return best,scores
end
------------------------------------------------------------------------
-- Наглядное обучение (лаборатория, уровни 2 и 3)
-- ForestTrace: «лес голосует» — корзины деревьев (бэггинг), голос каждого дерева,
--   точность одного дерева и леса из k деревьев на test, согласие деревьев между собой.
-- BoostTrace: «бустинг исправляет ошибки» — обучение по раундам с историей:
--   точность train/test после каждого раунда, уверенность в истинном классе для каждой учебной партии.
-- Алгоритмы те же, что в TrainForest / TrainGradientBoosting (при шаге 0,2 бустинг совпадает с ним).
------------------------------------------------------------------------
local function argmax4(v)
    local best=1
    for c=2,4 do if v[c]>v[best] then best=c end end
    return best
end
local function softmax4(scores)
    local maximum=math.max(scores[1],scores[2],scores[3],scores[4])
    local e,sum={},0
    for c=1,4 do e[c]=math.exp(scores[c]-maximum); sum=sum+e[c] end
    for c=1,4 do e[c]=e[c]/sum end
    return e
end
M.Softmax=softmax4
M.LearningRates={0.05,0.1,0.2,0.5}

-- Первый вопрос дерева: {Feature=номер признака, Threshold=порог} или nil, если дерево — один лист
local function rootQuestion(node)
    if node.leaf or node.value~=nil then return nil end
    return {Feature=node.feature,Threshold=node.threshold}
end
M.RootQuestion=rootQuestion

function M.ForestTrace(train,test,count,depth,randomFeatures)
    assert(isInteger(count,1,11) and isInteger(depth,2,5),"Invalid forest controls")
    local rng=Random.new(1841+count*17+depth+(randomFeatures and 0 or 977))
    local trees,bags={},{}
    for i=1,count do
        local sample,seen,unique,classes={},{},0,{0,0,0,0}
        for j=1,#train do
            local k=rng:NextInteger(1,#train)
            sample[j]=train[k]
            if not seen[k] then seen[k]=true; unique=unique+1 end
            classes[train[k].y]=classes[train[k].y]+1
        end
        trees[i]=classificationTree(sample,0,depth,rng,randomFeatures)
        bags[i]={Size=#train,Unique=unique,Classes=classes}
        if i%2==0 then task.wait() end
    end
    local perTree={}
    for i,tree in ipairs(trees) do
        local preds,correct={},0
        for r,row in ipairs(test) do
            local guess=predictClassification(row,tree)
            preds[r]=guess
            if guess==row.y then correct=correct+1 end
        end
        perTree[i]={Accuracy=correct/#test,Preds=preds}
    end
    -- точность леса из первых k деревьев (те же правила голосования, что в PredictForest)
    local accByCount={}
    for k=1,count do
        local correct=0
        for r,row in ipairs(test) do
            local votes={0,0,0,0}
            for i=1,k do local g=perTree[i].Preds[r]; votes[g]=votes[g]+1 end
            if argmax4(votes)==row.y then correct=correct+1 end
        end
        accByCount[k]=correct/#test
    end
    -- насколько деревья похожи: доля партий, на которых пара деревьев голосует одинаково
    local agreement,pairsCount=0,0
    for i=1,count do
        for j=i+1,count do
            local same=0
            for r=1,#test do
                if perTree[i].Preds[r]==perTree[j].Preds[r] then same=same+1 end
            end
            agreement=agreement+same/#test
            pairsCount=pairsCount+1
        end
    end
    return {Trees=trees,Bags=bags,PerTree=perTree,AccByCount=accByCount,
        Agreement=pairsCount>0 and agreement/pairsCount or 1}
end
function M.PredictForestTrace(row,trace)
    local votes,ballots={0,0,0,0},{}
    for i,tree in ipairs(trace.Trees) do
        local guess=predictClassification(row,tree)
        ballots[i]=guess
        votes[guess]=votes[guess]+1
    end
    return argmax4(votes),votes,ballots
end

function M.BoostTrace(train,test,rounds,depth,rate)
    assert(isInteger(rounds,1,60) and isInteger(depth,1,3),"Invalid gradient boosting controls")
    assert(table.find(M.LearningRates,rate),"Invalid learning rate")
    local priors={0,0,0,0}
    for _,row in ipairs(train) do priors[row.y]=priors[row.y]+1 end
    local base={}
    for c=1,4 do base[c]=math.log(math.max(priors[c]/#train,0.000001)) end
    local logits,indices,testLogits={},{},{}
    for i=1,#train do logits[i]=table.clone(base); indices[i]=i end
    for i=1,#test do testLogits[i]=table.clone(base) end
    local trainAcc,testAcc,pTrue={},{},{}
    local function record(round)
        local correct,probs=0,{}
        for i,row in ipairs(train) do
            if argmax4(logits[i])==row.y then correct=correct+1 end
            probs[i]=softmax4(logits[i])[row.y]
        end
        trainAcc[round+1]=correct/#train
        pTrue[round+1]=probs
        local tc=0
        for i,row in ipairs(test) do
            if argmax4(testLogits[i])==row.y then tc=tc+1 end
        end
        testAcc[round+1]=tc/#test
    end
    record(0)
    local stages={}
    for round=1,rounds do
        local residuals={{},{},{},{}}
        for i,row in ipairs(train) do
            local p=softmax4(logits[i])
            for c=1,4 do residuals[c][i]=(row.y==c and 1 or 0)-p[c] end
        end
        local stage={}
        for c=1,4 do
            local tree=regressionTree(train,indices,residuals[c],0,depth)
            stage[c]=tree
            for i,row in ipairs(train) do logits[i][c]=logits[i][c]+rate*predictRegression(row,tree) end
            for i,row in ipairs(test) do testLogits[i][c]=testLogits[i][c]+rate*predictRegression(row,tree) end
        end
        stages[round]=stage
        record(round)
        if round%5==0 then task.wait() end
    end
    -- TrainAcc/TestAcc/PTrue: индекс 1 — до обучения (раунд 0), индекс r+1 — после раунда r
    return {base=base,stages=stages,rate=rate,TrainAcc=trainAcc,TestAcc=testAcc,PTrue=pTrue}
end
-- Прогноз после первых rounds раундов: класс и вероятности классов
function M.PredictBoostAt(row,trace,rounds)
    local scores=table.clone(trace.base)
    for r=1,math.min(rounds,#trace.stages) do
        local stage=trace.stages[r]
        for c=1,4 do scores[c]=scores[c]+trace.rate*predictRegression(row,stage[c]) end
    end
    local probs=softmax4(scores)
    return argmax4(scores),probs
end

return M
