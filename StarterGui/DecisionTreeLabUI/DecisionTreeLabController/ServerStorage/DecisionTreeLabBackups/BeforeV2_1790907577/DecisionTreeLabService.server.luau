local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local M = require(RS:WaitForChild("DecisionTreeLabMath"))
local rpc = RS:WaitForChild("DecisionTreeLabRPC")
local train = M.Generate(101,48)
local validation = M.Generate(202,24)
local hidden = M.Generate(303,20)
local lastCall = {}
local featureById = {}
for _,feature in ipairs(M.Features) do featureById[feature.Id] = feature end
local validLabel = {A=true,B=true,C=true,D=true}
local function integer(value,low,high)
    return type(value)=="number" and value%1==0 and value>=low and value<=high
end
local function validated(mode,config)
    assert(type(config)=="table", "Invalid configuration")
    if mode=="Tree" then
        assert(type(config.Rules)=="table" and #config.Rules==3, "Three rules required")
        assert(type(config.Leaves)=="table" and #config.Leaves==4, "Four leaves required")
        for _,rule in ipairs(config.Rules) do
            assert(type(rule)=="table", "Invalid rule")
            local feature=featureById[rule.Feature]
            assert(feature, "Invalid feature")
            assert(rule.Op==">" or rule.Op=="<", "Invalid comparison")
            assert(type(rule.Threshold)=="number" and rule.Threshold==rule.Threshold and rule.Threshold>=feature.Min and rule.Threshold<=feature.Max, "Invalid threshold")
        end
        for _,label in ipairs(config.Leaves) do assert(validLabel[label], "Invalid class") end
        return function(row) return M.PredictManual(row,config.Rules,config.Leaves) end
    elseif mode=="Forest" then
        assert(integer(config.ForestCount,3,11) and integer(config.ForestDepth,2,5), "Invalid forest limits")
        local trees=M.TrainForest(train,config.ForestCount,config.ForestDepth)
        return function(row) return M.PredictForest(row,trees) end
    elseif mode=="Boost" then
        assert(integer(config.BoostRounds,3,9) and integer(config.BoostDepth,2,4), "Invalid boost limits")
        local stages=M.TrainBoost(train,config.BoostRounds,config.BoostDepth)
        assert(#stages>0, "No boosting stages trained")
        return function(row) return M.PredictBoost(row,stages) end
    end
    error("Unknown model")
end
rpc.OnServerInvoke=function(player,action,mode,config,index)
    assert(action=="Evaluate" or action=="Simulate", "Unknown action")
    local now=os.clock()
    assert(not lastCall[player] or now-lastCall[player]>=0.15, "Please wait before trying again")
    lastCall[player]=now
    local predict=validated(mode,config)
    if action=="Evaluate" then return M.Evaluate(validation,predict) end
    assert(integer(index,1,#hidden), "Invalid batch")
    local row=hidden[index]
    local guess,details=predict(row)
    return {Guess=guess,Actual=row.Label,Details=details,Id=row.Id}
end
Players.PlayerRemoving:Connect(function(player) lastCall[player]=nil end)
