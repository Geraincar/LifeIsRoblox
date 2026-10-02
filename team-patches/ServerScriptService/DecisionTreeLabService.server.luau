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
local modelCache={Forest={},Boost={}}
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
local function classifier(mode,config)
    assert(type(config)=="table","Missing model configuration")
    if mode=="Tree" then
        local graph=M.ValidateGraph(config.Graph)
        return function(row) return M.PredictGraph(row,graph) end
    elseif mode=="Forest" then
        local count,depth=config.Count,config.Depth
        assert(integer(count,3,11) and integer(depth,2,5),"Invalid forest controls")
        local cacheKey=count..":"..depth
        local trees=modelCache.Forest[cacheKey]
        if not trees then
            trees=M.TrainForest(data.Forest.train,count,depth)
            modelCache.Forest[cacheKey]=trees
        end
        return function(row) return M.PredictForest(row,trees) end
    elseif mode=="Boost" then
        local rounds,depth=config.Rounds,config.Depth
        assert(integer(rounds,10,60) and rounds%10==0 and integer(depth,1,3),"Invalid gradient boosting controls")
        local cacheKey=rounds..":"..depth
        local model=modelCache.Boost[cacheKey]
        if not model then
            model=M.TrainGradientBoosting(data.Boost.train,rounds,depth)
            modelCache.Boost[cacheKey]=model
        end
        return function(row) return M.PredictGradientBoosting(row,model) end
    end
    error("Unknown lesson level")
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
    assert(action=="Evaluate" or action=="Simulate","Unknown action")
    assert(not busy[player],"Model request already running")
    busy[player]=true
    local success,result=pcall(function()
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
