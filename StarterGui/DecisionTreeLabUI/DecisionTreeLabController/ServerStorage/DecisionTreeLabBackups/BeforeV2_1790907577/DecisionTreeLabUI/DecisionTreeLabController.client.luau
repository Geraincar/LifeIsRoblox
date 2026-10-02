local RS = game:GetService("ReplicatedStorage")
local M = require(RS:WaitForChild("DecisionTreeLabMath"))
local rpc = RS:WaitForChild("DecisionTreeLabRPC")
local gui = script.Parent
local lab = workspace:WaitForChild("DecisionTreeLab_2026")
local prompt = lab:WaitForChild("SorterTerminal"):WaitForChild("OpenDecisionTreeLab")
local train = M.Generate(101,48)
local hidden = M.Generate(303,20)
local rules = {
    {Feature="water_pct", Threshold=38, Op=">"},
    {Feature="sugar_pct", Threshold=60, Op="<"},
    {Feature="acidity", Threshold=4.2, Op="<"},
}
local leaves = {"A","B","C","D"}
local className = {A="Dryer Bees — очень влажный",B="Standard Bees — обычный",C="Dense Bees — густой",D="Royal Bees — ценный"}
local classColor = {A=Color3.fromRGB(239,110,111),B=Color3.fromRGB(133,140,250),C=Color3.fromRGB(90,216,151),D=Color3.fromRGB(250,195,76)}
local tab,sampleIndex = "Tree",1
local forestCount,forestDepth = 5,3
local boostRounds,boostDepth = 5,2
local forest,boost,metric
local status="Настройте правила, затем проверьте модель на validation."
local ink=Color3.fromRGB(14,21,29)
local panel=Color3.fromRGB(23,32,42)
local panel2=Color3.fromRGB(30,43,54)
local cyan=Color3.fromRGB(91,224,231)
local pale=Color3.fromRGB(230,240,243)
local muted=Color3.fromRGB(160,183,193)
local function box(name,parent,size,pos,color)
    local x=Instance.new("Frame")
    x.Name=name; x.Size=size; x.Position=pos; x.BackgroundColor3=color or panel
    x.BorderSizePixel=0; x.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=x
    return x
end
local function text(name,parent,value,size,pos,fontSize,color,bold)
    local x=Instance.new("TextLabel")
    x.Name=name; x.Size=size; x.Position=pos; x.BackgroundTransparency=1
    x.Text=value; x.TextColor3=color or pale; x.TextSize=fontSize or 16
    x.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    x.TextXAlignment=Enum.TextXAlignment.Left; x.TextYAlignment=Enum.TextYAlignment.Center
    x.TextWrapped=true; x.Parent=parent
    return x
end
local function button(name,parent,value,size,pos,click,color)
    local x=Instance.new("TextButton")
    x.Name=name; x.Size=size; x.Position=pos; x.BackgroundColor3=color or panel2
    x.BorderSizePixel=0; x.Text=value; x.TextColor3=pale; x.TextSize=15
    x.Font=Enum.Font.GothamBold; x.AutoButtonColor=true; x.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=x
    x.MouseButton1Click:Connect(click)
    return x
end
local shade=box("Shade",gui,UDim2.fromScale(1,1),UDim2.fromScale(0,0),Color3.fromRGB(3,8,13))
shade.BackgroundTransparency=0.22; shade.Visible=false
local card=box("Laboratory",shade,UDim2.new(0.9,0,0.84,0),UDim2.fromScale(0.5,0.5),ink)
card.AnchorPoint=Vector2.new(0.5,0.5)
local cap=Instance.new("UISizeConstraint"); cap.MaxSize=Vector2.new(1180,760); cap.Parent=card
text("Title",card,"NECTAR SORTER  /  ЛАБОРАТОРИЯ МОДЕЛЕЙ",UDim2.new(1,-110,0,30),UDim2.fromOffset(24,15),24,cyan,true)
text("Subtitle",card,"Построй дерево, сравни его с лесом и бустингом — затем отсортируй партию нектара",UDim2.new(1,-100,0,26),UDim2.fromOffset(24,47),14,muted,false)
button("Close",card,"×",UDim2.fromOffset(42,40),UDim2.new(1,-58,0,20),function() shade.Visible=false end,Color3.fromRGB(55,66,78))
local tabs=box("Tabs",card,UDim2.new(1,-36,0,46),UDim2.fromOffset(18,84),panel)
local content=Instance.new("ScrollingFrame")
content.Name="LessonContent"; content.Position=UDim2.fromOffset(18,142)
content.Size=UDim2.new(0.68,-24,1,-212); content.BackgroundTransparency=1
content.BorderSizePixel=0; content.ScrollBarThickness=5; content.ScrollBarImageColor3=cyan
content.AutomaticCanvasSize=Enum.AutomaticSize.Y; content.CanvasSize=UDim2.fromOffset(0,0); content.Parent=card
local side=Instance.new("ScrollingFrame")
side.Name="BatchPanel"; side.Size=UDim2.new(0.32,-24,1,-212); side.Position=UDim2.new(0.68,6,0,142)
side.BackgroundColor3=panel; side.BorderSizePixel=0; side.CanvasSize=UDim2.fromOffset(0,610)
side.ScrollBarThickness=5; side.ScrollBarImageColor3=cyan; side.Parent=card
local sideCorner=Instance.new("UICorner"); sideCorner.CornerRadius=UDim.new(0,10); sideCorner.Parent=side
text("BatchHeader",side,"ПАРТИЯ  /  ДАННЫЕ",UDim2.new(1,-30,0,30),UDim2.fromOffset(16,14),17,cyan,true)
local featureText=text("Features",side,"",UDim2.new(1,-30,0,222),UDim2.fromOffset(16,52),14,pale,false)
featureText.TextYAlignment=Enum.TextYAlignment.Top; featureText.TextWrapped=false
box("Line",side,UDim2.new(1,-32,0,1),UDim2.fromOffset(16,286),Color3.fromRGB(68,87,99))
local metricText=text("Metrics",side,"",UDim2.new(1,-30,0,160),UDim2.fromOffset(16,302),15,pale,false)
metricText.TextYAlignment=Enum.TextYAlignment.Top
local statusText=text("Status",side,"",UDim2.new(1,-30,0,100),UDim2.fromOffset(16,486),14,muted,false)
statusText.TextYAlignment=Enum.TextYAlignment.Top
local footer=box("Footer",card,UDim2.new(1,-36,0,54),UDim2.new(0,18,1,-66),panel)
local render
local function config()
    return {Rules=rules,Leaves=leaves,ForestCount=forestCount,ForestDepth=forestDepth,BoostRounds=boostRounds,BoostDepth=boostDepth}
end
local function callServer(action,index)
    local ok,result=pcall(function() return rpc:InvokeServer(action,tab,config(),index) end)
    if not ok then status="Ошибка проверки: "..tostring(result); render(); return nil end
    return result
end
local function cycleFeature(i)
    local current=1
    for j,f in ipairs(M.Features) do if f.Id==rules[i].Feature then current=j; break end end
    local nextFeature=M.Features[current%#M.Features+1]
    rules[i].Feature=nextFeature.Id
    rules[i].Threshold=math.floor((nextFeature.Min+nextFeature.Max)/2/nextFeature.Step+0.5)*nextFeature.Step
    metric=nil; render()
end
local function adjustThreshold(i,dir)
    local feature
    for _,f in ipairs(M.Features) do if f.Id==rules[i].Feature then feature=f; break end end
    rules[i].Threshold=math.clamp(math.floor((rules[i].Threshold+dir*feature.Step)/feature.Step+0.5)*feature.Step,feature.Min,feature.Max)
    metric=nil; render()
end
local function cycleLeaf(i)
    for j,label in ipairs(M.Labels) do if label==leaves[i] then leaves[i]=M.Labels[j%4+1]; break end end
    metric=nil; render()
end
local function addLine(value,height,color,bold)
    local row=box("TextRow",content,UDim2.new(1,-10,0,height),UDim2.fromOffset(0,0),panel)
    row.LayoutOrder=#content:GetChildren()+1
    local t=text("Text",row,value,UDim2.new(1,-28,1,-8),UDim2.fromOffset(14,4),15,color or pale,bold)
    t.TextYAlignment=Enum.TextYAlignment.Center
    return row
end
local function addSplit(i)
    local rule=rules[i]
    local row=box("Split"..i,content,UDim2.new(1,-10,0,82),UDim2.fromOffset(0,0),panel)
    row.LayoutOrder=#content:GetChildren()+1
    text("Caption",row,"РАЗВИЛКА "..i.."  ·  если условие верно → класс "..leaves[i],UDim2.new(1,-20,0,24),UDim2.fromOffset(12,7),14,muted,true)
    local featureName=rule.Feature
    for _,f in ipairs(M.Features) do if f.Id==rule.Feature then featureName=f.Name; break end end
    button("Feature",row,featureName,UDim2.new(0.42,-4,0,35),UDim2.fromOffset(12,36),function() cycleFeature(i) end)
    text("Op",row,rule.Op,UDim2.fromOffset(20,35),UDim2.new(0.42,14,0,36),18,cyan,true)
    button("Minus",row,"−",UDim2.fromOffset(35,35),UDim2.new(0.42,40,0,36),function() adjustThreshold(i,-1) end)
    text("Threshold",row,string.format("%.2f",rule.Threshold),UDim2.fromOffset(56,35),UDim2.new(0.42,78,0,36),15,pale,true)
    button("Plus",row,"+",UDim2.fromOffset(35,35),UDim2.new(0.42,135,0,36),function() adjustThreshold(i,1) end)
    button("Leaf",row,leaves[i],UDim2.fromOffset(44,35),UDim2.new(1,-57,0,36),function() cycleLeaf(i) end,classColor[leaves[i]])
end
local function addControl(caption,value,down,up)
    local row=box("Control",content,UDim2.new(1,-10,0,64),UDim2.fromOffset(0,0),panel)
    row.LayoutOrder=#content:GetChildren()+1
    text("Caption",row,caption,UDim2.new(1,-180,1,0),UDim2.fromOffset(14,0),16,pale,true)
    button("Minus",row,"−",UDim2.fromOffset(38,38),UDim2.new(1,-157,0,13),down)
    text("Value",row,tostring(value),UDim2.fromOffset(52,38),UDim2.new(1,-111,0,13),18,cyan,true)
    button("Plus",row,"+",UDim2.fromOffset(38,38),UDim2.new(1,-50,0,13),up)
end
local function showBeacon(label)
    local beacon=lab:FindFirstChild("ClassBeacon_"..label)
    if not beacon then return end
    local highlight=Instance.new("Highlight")
    highlight.FillColor=classColor[label]; highlight.OutlineColor=Color3.new(1,1,1)
    highlight.FillTransparency=0.15; highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent=beacon
    task.delay(2,function() if highlight.Parent then highlight:Destroy() end end)
end
local function evaluate()
    if tab=="Forest" and not forest then status="Сначала обучите случайный лес."; render(); return end
    if tab=="Boost" and (not boost or #boost==0) then status="Сначала обучите бустинг."; render(); return end
    local result=callServer("Evaluate")
    if not result then return end
    metric=result; status="Проверено на 24 новых партиях сервером. Train и validation не смешиваются."
    render()
end
local function simulate()
    if tab=="Forest" and not forest then status="Сначала обучите случайный лес."; render(); return end
    if tab=="Boost" and (not boost or #boost==0) then status="Сначала обучите бустинг."; render(); return end
    local result=callServer("Simulate",sampleIndex)
    if not result then return end
    local verdict=result.Guess==result.Actual and "верно" or "ошибка"
    status="Партия "..result.Id..": сортировщик выбрал "..result.Guess.." ("..className[result.Guess].."). Истинный класс: "..result.Actual..". "..verdict.."."
    showBeacon(result.Guess); render()
end
button("Evaluate",footer,"ПРОВЕРИТЬ VALIDATION",UDim2.new(0.39,-10,0,38),UDim2.fromOffset(10,8),evaluate,Color3.fromRGB(32,113,124))
button("Simulate",footer,"СИМУЛИРОВАТЬ СОРТИРОВКУ",UDim2.new(0.40,-10,0,38),UDim2.new(0.39,6,0,8),simulate,Color3.fromRGB(108,78,31))
button("Next",footer,"СЛЕДУЮЩАЯ →",UDim2.new(0.21,-16,0,38),UDim2.new(0.79,0,0,8),function()
    sampleIndex=sampleIndex%#hidden+1
    status="Выбрана новая скрытая партия "..hidden[sampleIndex].Id..". Истинный класс откроется после симуляции."
    render()
end)
local tabDefs={{"Tree","ДЕРЕВО"},{"Forest","СЛУЧАЙНЫЙ ЛЕС"},{"Boost","БУСТИНГ"}}
for i,entry in ipairs(tabDefs) do
    button("Tab"..entry[1],tabs,entry[2],UDim2.new(1/3,-9,0,34),UDim2.new((i-1)/3,6,0,6),function()
        tab=entry[1]; content.CanvasPosition=Vector2.zero; side.CanvasPosition=Vector2.zero
        metric=nil; status="Выбрана модель: "..entry[2].."."; render()
    end,panel2)
end
render=function()
    for _,child in ipairs(content:GetChildren()) do child:Destroy() end
    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,8); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=content
    for _,entry in ipairs(tabDefs) do
        local b=tabs:FindFirstChild("Tab"..entry[1])
        b.BackgroundColor3=tab==entry[1] and Color3.fromRGB(37,119,131) or panel2
    end
    if tab=="Tree" then
        addLine("1  /  ПОСТРОЙ ДЕРЕВО РЕШЕНИЙ",48,cyan,true)
        addLine("Каждая развилка проверяет признак. Если условие ложно — партия идёт к следующей развилке. Нажимай на имя признака, порог и класс, чтобы менять дерево.",76,pale,false)
        for i=1,3 do addSplit(i) end
        local row=box("LastLeaf",content,UDim2.new(1,-10,0,58),UDim2.fromOffset(0,0),panel)
        row.LayoutOrder=#content:GetChildren()+1
        text("Caption",row,"ЕСЛИ НИ ОДНО УСЛОВИЕ НЕ СРАБОТАЛО →",UDim2.new(1,-84,1,0),UDim2.fromOffset(14,0),14,pale,true)
        button("Leaf",row,leaves[4],UDim2.fromOffset(50,36),UDim2.new(1,-64,0,11),function() cycleLeaf(4) end,classColor[leaves[4]])
        addLine(string.format("Train: 48 партий  ·  Энтропия: %.2f  ·  Gini: %.2f",M.Impurity(train,"Entropy"),M.Impurity(train,"Gini")),56,muted,false)
        addLine("Подсказка: A — water > 38; B — water ≤ 38 и sugar < 60; C — далее acidity < 4.2; D — остальные. Ошибки в учебных данных добавлены намеренно.",75,muted,false)
    elseif tab=="Forest" then
        addLine("2  /  СЛУЧАЙНЫЙ ЛЕС",48,cyan,true)
        addLine("Каждое дерево обучается на случайной выборке train и рассматривает случайное подмножество признаков. Итоговый класс выбирается большинством голосов.",88,pale,false)
        addControl("Количество деревьев",forestCount,function() forestCount=math.max(3,forestCount-2); forest=nil; metric=nil; render() end,function() forestCount=math.min(11,forestCount+2); forest=nil; metric=nil; render() end)
        addControl("Максимальная глубина",forestDepth,function() forestDepth=math.max(2,forestDepth-1); forest=nil; metric=nil; render() end,function() forestDepth=math.min(5,forestDepth+1); forest=nil; metric=nil; render() end)
        local row=box("Train",content,UDim2.new(1,-10,0,62),UDim2.fromOffset(0,0),panel)
        row.LayoutOrder=#content:GetChildren()+1
        button("TrainButton",row,"ОБУЧИТЬ ЛЕС",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,10),function()
            forest=M.TrainForest(train,forestCount,forestDepth)
            local result=callServer("Evaluate")
            if not result then return end
            metric=result
            local _,votes=M.PredictForest(hidden[sampleIndex],forest)
            status=string.format("Лес обучен. Голоса за партию: A %d · B %d · C %d · D %d.",votes.A,votes.B,votes.C,votes.D)
            render()
        end,Color3.fromRGB(32,113,124))
        addLine("Вычислительная нагрузка (условные единицы): "..forestCount*(2^forestDepth)..". Больше деревьев и глубина требуют больше расчётов.",70,muted,false)
    else
        addLine("3  /  БУСТИНГ: ИДЕЯ",48,cyan,true)
        addLine("Здесь учебная многоклассовая модель SAMME. Слабые деревья обучаются последовательно: ошибки предыдущего этапа получают больший вес. Это иллюстрация бустинга, не промышленная система.",105,pale,false)
        addControl("Число этапов",boostRounds,function() boostRounds=math.max(3,boostRounds-2); boost=nil; metric=nil; render() end,function() boostRounds=math.min(9,boostRounds+2); boost=nil; metric=nil; render() end)
        addControl("Глубина слабого дерева",boostDepth,function() boostDepth=math.max(2,boostDepth-1); boost=nil; metric=nil; render() end,function() boostDepth=math.min(4,boostDepth+1); boost=nil; metric=nil; render() end)
        local row=box("Train",content,UDim2.new(1,-10,0,62),UDim2.fromOffset(0,0),panel)
        row.LayoutOrder=#content:GetChildren()+1
        button("TrainButton",row,"ОБУЧИТЬ БУСТИНГ",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,10),function()
            boost=M.TrainBoost(train,boostRounds,boostDepth)
            if #boost==0 then status="Не удалось обучить этапы на этих данных."; render(); return end
            local result=callServer("Evaluate")
            if not result then return end
            metric=result
            local errors={}
            for i,stage in ipairs(boost) do errors[i]=string.format("%d: %.0f%%",i,stage.Error*100) end
            status="Этапы и взвешенная доля ошибок: "..table.concat(errors,"  ·  ")
            render()
        end,Color3.fromRGB(32,113,124))
        addLine("Вычислительная нагрузка (условные единицы): "..boostRounds*(2^boostDepth)..". Обученные этапы работают последовательно.",70,muted,false)
    end
    local row=hidden[sampleIndex]
    featureText.Text=string.format("ID: %s  ·  hidden test\n\nwater_pct       %.1f%%\nsugar_pct        %.1f%%\nacidity             %.1f\nviscosity          %.1f\ntemperature  %.1f°C\naroma              %.1f\ncolor                %.1f\npollen_density %.1f",row.Id,row.water_pct,row.sugar_pct,row.acidity,row.viscosity,row.temperature,row.aroma,row.color,row.pollen_density)
    if metric then
        metricText.Text=string.format("VALIDATION · %d ПАРТИИ\nТочность: %.0f%% (%d/%d)\nMacro-F1: %.2f\n\nF1 по классам:\nA %.2f    B %.2f\nC %.2f    D %.2f",metric.Total,metric.Accuracy*100,metric.Correct,metric.Total,metric.MacroF1,metric.ByClass.A.F1,metric.ByClass.B.F1,metric.ByClass.C.F1,metric.ByClass.D.F1)
    else metricText.Text="VALIDATION\n\nНажми «Проверить» или обучи модель, чтобы увидеть точность и Macro-F1." end
    statusText.Text=status
end
render()
local openButton=button("OpenLab",gui,"🌳  ЛАБОРАТОРИЯ ДЕРЕВЬЕВ",UDim2.fromOffset(245,44),UDim2.new(0,18,1,-60),function() shade.Visible=true end,Color3.fromRGB(27,99,108))
openButton.ZIndex=2
prompt.Triggered:Connect(function() shade.Visible=true end)
