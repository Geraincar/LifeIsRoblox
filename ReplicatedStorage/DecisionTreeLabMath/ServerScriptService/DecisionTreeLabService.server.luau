local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local M=require(RS:WaitForChild("DecisionTreeLabMath"))
local rpc=RS:WaitForChild("DecisionTreeLabRPC")
local sources=SS:WaitForChild("DecisionTreeLabDatasetsV2")
local names={Tree="Tree",Forest="Forest",Boost="Boost"}
local data={}
for mode,name in pairs(names) do
    local source=require(sources:WaitForChild(name))
    data[mode]=M.DecodeDataset(source.Encoded,source.Count)
    assert(#data[mode].train>0 and #data[mode].validation>0 and #data[mode].test>0,"Missing dataset split")
end
-- Прогресс лаборатории НЕ сохраняется между заходами: каждый новый заход начинается с уровня 1 (только память сервера).
local progress={}
local busy={}
local stageIndex={Tree=1,Forest=2,Boost=3}
local gates={
    Tree={Accuracy=0.95,MacroF1=0.95},
    Forest={Accuracy=0.78,MacroF1=0.75},
    Boost={Accuracy=0.70,MacroF1=0.65},
}
local function integer(value,minimum,maximum)
    return type(value)=="number" and value%1==0 and value>=minimum and value<=maximum
end
local function stateFor(player)
    if progress[player] then return progress[player] end
    local state={Unlocked=1,Persistent=false}
    progress[player]=state
    return state
end
local function publicState(state)
    return {Unlocked=state.Unlocked,Persistent=state.Persistent}
end
local function authorize(player,mode)
    local index=stageIndex[mode]
    assert(index,"Unknown lesson level")
    local state=stateFor(player)
    assert(index<=state.Unlocked,"Finish the preceding lesson first")
    return state,index
end
-- Модели леса и бустинга обучаются через трассировки (те же алгоритмы, что TrainForest/TrainGradientBoosting,
-- плюс история для наглядных режимов «лес голосует» и «бустинг по раундам») и кешируются на сервере.
local traceCache={Forest={},Boost={}}
local training={}
local function cached(kind,key,build)
    local full=kind..":"..key
    while training[full] do task.wait(0.1) end
    local value=traceCache[kind][key]
    if value then return value end
    training[full]=true
    local ok,result=pcall(build)
    training[full]=nil
    if not ok then error(result) end
    traceCache[kind][key]=result
    return result
end
local function forestConfig(config)
    local count,depth=config.Count,config.Depth
    assert(integer(count,3,11) and integer(depth,2,5),"Invalid forest controls")
    local randomFeatures=config.RandomFeatures~=false
    return count,depth,randomFeatures
end
local function forestTrace(config)
    local count,depth,randomFeatures=forestConfig(config)
    return cached("Forest",count..":"..depth..":"..tostring(randomFeatures),function()
        return M.ForestTrace(data.Forest.train,data.Forest.test,count,depth,randomFeatures)
    end)
end
local function boostConfig(config,allowZero)
    local rounds,depth=config.Rounds,config.Depth
    local rate=config.Rate or 0.2
    assert(integer(rounds,allowZero and 0 or 1,60) and integer(depth,1,3),"Invalid gradient boosting controls")
    assert(table.find(M.LearningRates,rate),"Invalid learning rate")
    return rounds,depth,rate
end
local function boostTrace(depth,rate)
    -- обучаем сразу на все 60 раундов: любой раунд потом — срез без переобучения
    return cached("Boost",depth..":"..rate,function()
        return M.BoostTrace(data.Boost.train,data.Boost.test,60,depth,rate)
    end)
end
local function classifier(mode,config)
    assert(type(config)=="table","Missing model configuration")
    if mode=="Tree" then
        local graph=M.ValidateGraph(config.Graph)
        return function(row) return M.PredictGraph(row,graph) end
    elseif mode=="Forest" then
        local trace=forestTrace(config)
        return function(row) return M.PredictForestTrace(row,trace) end
    elseif mode=="Boost" then
        local rounds,depth,rate=boostConfig(config,false)
        local trace=boostTrace(depth,rate)
        return function(row) return M.PredictBoostAt(row,trace,rounds) end
    end
    error("Unknown lesson level")
end
local function question(node)
    local q=M.RootQuestion(node)
    if not q then return nil end
    local meta=M.Features[q.Feature]
    return {Feature=meta.Name,Threshold=q.Threshold,Decimals=meta.Decimals}
end
-- «Лес голосует»: корзины деревьев, голос каждого дерева за выбранную партию, точность от числа деревьев
local function forestExplain(config,row,index,total)
    local trace=forestTrace(config)
    local guess,votes,ballots=M.PredictForestTrace(row,trace)
    local trees,singleSum={},0
    for i,tree in ipairs(trace.Trees) do
        local bag=trace.Bags[i]
        trees[i]={Unique=bag.Unique,Size=bag.Size,Classes=table.clone(bag.Classes),Root=question(tree),
            Vote=M.Labels[ballots[i]],Accuracy=trace.PerTree[i].Accuracy}
        singleSum=singleSum+trace.PerTree[i].Accuracy
    end
    return {Id=row.id,Index=index,Total=total,Actual=M.Labels[row.y],Forest=M.Labels[guess],Votes=votes,
        Trees=trees,AccByCount=table.clone(trace.AccByCount),Agreement=trace.Agreement,Single=singleSum/#trace.Trees,
        RandomFeatures=config.RandomFeatures~=false}
end
-- «Бустинг по раундам»: что изменил каждый раунд для выбранной партии и для всей обучающей выборки
local function boostExplain(config,row,index,total)
    local rounds,depth,rate=boostConfig(config,true)
    local trace=boostTrace(depth,rate)
    local train=data.Boost.train
    local history={}
    for r=0,rounds do
        local _,probs=M.PredictBoostAt(row,trace,r)
        history[r+1]=probs[row.y]
    end
    local guess,probs=M.PredictBoostAt(row,trace,rounds)
    local pTrue=trace.PTrue[rounds+1]
    local order={}
    for i=1,#train do order[i]=i end
    table.sort(order,function(x,y) return pTrue[x]<pTrue[y] end)
    local hard={}
    for k=1,5 do
        local i=order[k]
        hard[k]={Id=train[i].id,P=pTrue[i],Actual=M.Labels[train[i].y]}
    end
    local lastStage=nil
    if rounds>=1 then
        lastStage={}
        for c=1,4 do lastStage[c]=question(trace.stages[rounds][c]) or false end
    end
    local bestRound,bestAcc=0,-1
    for r=0,rounds do
        if trace.TestAcc[r+1]>bestAcc+0.0005 then bestRound,bestAcc=r,trace.TestAcc[r+1] end
    end
    return {Round=rounds,Depth=depth,Rate=rate,Id=row.id,Index=index,Total=total,Actual=M.Labels[row.y],
        Guess=M.Labels[guess],Probs=probs,History=history,
        TrainAcc=table.move(trace.TrainAcc,1,rounds+1,1,{}),TestAcc=table.move(trace.TestAcc,1,rounds+1,1,{}),
        TrainTotal=#train,Wrong=#train-math.floor(trace.TrainAcc[rounds+1]*#train+0.5),
        Hard=hard,LastStage=lastStage,BestTestRound=bestRound}
end
local function promote(player,state,index)
    if state.Unlocked>index then return end
    state.Unlocked=math.min(index+1,4)
end
-- Партия урожая = ОДНА строка test-датасета уровня. Листать можно все партии test-датасета;
-- окончательная проверка (Evaluate) идёт по ВСЕМУ test-датасету уровня, а не по одной партии.
local function handle(player,action,mode,config,index)
    if action=="GetState" then return publicState(stateFor(player)) end
    local state,stage=authorize(player,mode)
    local total=#data[mode].test
    if action=="GetBatch" then
        assert(integer(index,1,total),"Invalid batch index")
        local row=data[mode].test[index]
        assert(row,"Batch not found")
        return {Id=row.id,Features=table.clone(row.f),Index=index,Total=total}
    end
    assert(action=="Evaluate" or action=="Simulate" or action=="ForestExplain" or action=="BoostExplain","Unknown action")
    assert(not busy[player],"Model request already running")
    busy[player]=true
    local success,result=pcall(function()
        if action=="ForestExplain" or action=="BoostExplain" then
            assert(mode==(action=="ForestExplain" and "Forest" or "Boost"),"Wrong lesson level")
            assert(type(config)=="table","Missing model configuration")
            assert(integer(index,1,total),"Invalid batch index")
            local row=data[mode].test[index]
            if action=="ForestExplain" then return forestExplain(config,row,index,total) end
            return boostExplain(config,row,index,total)
        end
        local predict=classifier(mode,config)
        if action=="Simulate" then
            -- «Посмотреть на test-датасете»: прогноз модели для одной выбранной партии
            assert(integer(index,1,total),"Invalid batch index")
            local row=data[mode].test[index]
            assert(row,"Batch not found")
            local guess,details=predict(row)
            return {Id=row.id,Guess=M.Labels[guess],Actual=M.Labels[row.y],Details=details,Index=index,Total=total}
        end
        -- «Пройти окончательную проверку»: все партии test-датасета уровня
        local metrics=M.Metrics(data[mode].test,predict)
        local required=gates[mode]
        local passed=metrics.Accuracy>=required.Accuracy and metrics.MacroF1>=required.MacroF1
        if passed then promote(player,state,stage) end
        return {Metrics=metrics,Success=passed,Required=required,Dataset="test",Total=total,
            Unlocked=state.Unlocked,Persistent=state.Persistent}
    end)
    busy[player]=nil
    if not success then error(result) end
    return result
end
rpc.OnServerInvoke=handle
Players.PlayerRemoving:Connect(function(player)
    progress[player]=nil
    busy[player]=nil
end)
