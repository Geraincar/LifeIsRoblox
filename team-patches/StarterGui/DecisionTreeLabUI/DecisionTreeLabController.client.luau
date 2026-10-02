local RS=game:GetService("ReplicatedStorage")
local M=require(RS:WaitForChild("DecisionTreeLabMath"))
local rpc=RS:WaitForChild("DecisionTreeLabRPC")
local lab=workspace:WaitForChild("DecisionTreeLab_2026")
local prompt=lab:WaitForChild("SorterTerminal"):WaitForChild("OpenDecisionTreeLab")
local gui=script.Parent
local labels=M.Labels
local colors={
    Color3.fromRGB(53,148,231),Color3.fromRGB(78,185,102),
    Color3.fromRGB(244,184,47),Color3.fromRGB(229,90,135)}
local bg=Color3.fromRGB(23,25,31)
local panel=Color3.fromRGB(39,43,52)
local warm=Color3.fromRGB(253,195,63)
local white=Color3.fromRGB(246,247,249)
local dark=Color3.fromRGB(43,49,58)
local muted=Color3.fromRGB(167,175,185)
local green=Color3.fromRGB(63,198,102)
local selectedId=1
local nextId=2
local graph={root=1,nodes={["1"]={kind="leaf",class=1}}}
local tab="Tree"
local unlocked=1
local persistent=false
local sampleIndex=1
local batch
local metric
local success=false
local status="Построй дерево: выбери лист, добавь развилку и настрой обе ветви."
local statusColor=muted
local forestCount,forestDepth=5,3
local boostRounds,boostDepth=20,2
local renderMain,renderPanels

local function frame(name,parent,size,pos,color,radius)
    local x=Instance.new("Frame")
    x.Name=name; x.Size=size; x.Position=pos; x.BackgroundColor3=color
    x.BorderSizePixel=0; x.Parent=parent
    if radius then local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,radius); corner.Parent=x end
    return x
end
local function label(name,parent,value,size,pos,textSize,color,bold,center)
    local x=Instance.new("TextLabel")
    x.Name=name; x.Size=size; x.Position=pos; x.BackgroundTransparency=1
    x.Text=value; x.TextSize=textSize; x.TextColor3=color
    x.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    x.TextWrapped=true
    x.TextXAlignment=center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    x.TextYAlignment=Enum.TextYAlignment.Center
    x.Parent=parent
    return x
end
local function button(name,parent,value,size,pos,color,textColor,callback)
    local x=Instance.new("TextButton")
    x.Name=name; x.Size=size; x.Position=pos; x.BackgroundColor3=color
    x.BorderSizePixel=0; x.Text=value; x.TextColor3=textColor; x.TextSize=15
    x.Font=Enum.Font.GothamBold; x.TextWrapped=true; x.AutoButtonColor=true
    x.Parent=parent
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,9); corner.Parent=x
    x.MouseButton1Click:Connect(callback)
    return x
end
local function clearGenerated(parent)
    for _,child in ipairs(parent:GetChildren()) do
        if not child:IsA("UICorner") and not child:IsA("UIListLayout") then child:Destroy() end
    end
end
local function request(action,mode,config,index)
    local ok,result=pcall(function() return rpc:InvokeServer(action,mode,config,index) end)
    if not ok then
        status="Ошибка сервера: "..tostring(result)
        statusColor=Color3.fromRGB(243,102,96)
        if renderPanels then renderPanels() end
        return nil
    end
    return result
end
local shade=frame("Shade",gui,UDim2.fromScale(1,1),UDim2.fromScale(0,0),Color3.fromRGB(3,5,8))
shade.BackgroundTransparency=0.18; shade.Visible=false
local card=frame("Laboratory",shade,UDim2.new(0.94,0,0.9,0),UDim2.fromScale(0.5,0.5),bg,16)
card.AnchorPoint=Vector2.new(0.5,0.5)
local maxSize=Instance.new("UISizeConstraint"); maxSize.MaxSize=Vector2.new(1320,830); maxSize.Parent=card
label("Title",card,"NECTAR SORTER  ·  ЛАБОРАТОРИЯ ДЕРЕВЬЕВ",UDim2.new(1,-95,0,35),UDim2.fromOffset(22,14),23,warm,true)
label("Subtitle",card,"От своего дерева решений — к лесу и градиентному бустингу",UDim2.new(1,-95,0,24),UDim2.fromOffset(22,50),14,muted,false)
button("Close",card,"×",UDim2.fromOffset(40,38),UDim2.new(1,-54,0,18),panel,white,function() shade.Visible=false end)
local tabs=frame("Tabs",card,UDim2.new(1,-36,0,46),UDim2.fromOffset(18,84),panel,10)
local main=frame("Main",card,UDim2.new(0.72,-24,1,-222),UDim2.fromOffset(18,140),panel,12)
local sidebar=Instance.new("ScrollingFrame")
sidebar.Name="Sidebar"; sidebar.Size=UDim2.new(0.28,-18,1,-222)
sidebar.Position=UDim2.new(0.72,0,0,140); sidebar.BackgroundColor3=panel
sidebar.BorderSizePixel=0; sidebar.ScrollBarThickness=6
sidebar.CanvasSize=UDim2.fromOffset(0,635); sidebar.Parent=card
local sidebarCorner=Instance.new("UICorner"); sidebarCorner.CornerRadius=UDim.new(0,12); sidebarCorner.Parent=sidebar
local footer=frame("Footer",card,UDim2.new(1,-36,0,58),UDim2.new(0,18,1,-70),panel,10)
local canvas=Instance.new("ScrollingFrame")
canvas.Name="TreeCanvas"; canvas.Size=UDim2.new(1,-210,1,-24)
canvas.Position=UDim2.fromOffset(12,12); canvas.BackgroundColor3=white
canvas.BorderSizePixel=0; canvas.ScrollBarThickness=8
canvas.ScrollingDirection=Enum.ScrollingDirection.XY
canvas.CanvasSize=UDim2.fromOffset(680,480); canvas.Parent=main
local canvasCorner=Instance.new("UICorner"); canvasCorner.CornerRadius=UDim.new(0,10); canvasCorner.Parent=canvas
local inspector=frame("TreeInspector",main,UDim2.new(0,184,1,-24),UDim2.new(1,-196,0,12),white,10)
local alternate=Instance.new("ScrollingFrame")
alternate.Name="ModelControls"; alternate.Size=UDim2.new(1,-24,1,-24)
alternate.Position=UDim2.fromOffset(12,12); alternate.BackgroundTransparency=1
alternate.BorderSizePixel=0; alternate.ScrollBarThickness=6
alternate.AutomaticCanvasSize=Enum.AutomaticSize.Y; alternate.CanvasSize=UDim2.fromOffset(0,0)
alternate.Visible=false; alternate.Parent=main
local alternateLayout=Instance.new("UIListLayout")
alternateLayout.Padding=UDim.new(0,10); alternateLayout.SortOrder=Enum.SortOrder.LayoutOrder
alternateLayout.Parent=alternate
label("BatchTitle",sidebar,"ПАРТИЯ / ДАННЫЕ",UDim2.new(1,-26,0,29),UDim2.fromOffset(14,12),16,warm,true)
local batchText=label("BatchText",sidebar,"",UDim2.new(1,-28,0,240),UDim2.fromOffset(14,48),14,white,false)
batchText.TextYAlignment=Enum.TextYAlignment.Top
local metricsText=label("Metrics",sidebar,"",UDim2.new(1,-28,0,190),UDim2.fromOffset(14,290),14,white,false)
metricsText.TextYAlignment=Enum.TextYAlignment.Top
local statusText=label("Status",sidebar,"",UDim2.new(1,-28,0,120),UDim2.fromOffset(14,490),14,muted,false)
statusText.TextYAlignment=Enum.TextYAlignment.Top
local tabDefs={{"Tree","1 · ДЕРЕВО"},{"Forest","2 · СЛУЧАЙНЫЙ ЛЕС"},{"Boost","3 · ГРАДИЕНТНЫЙ БУСТИНГ"}}
for i,item in ipairs(tabDefs) do
    button("Tab"..item[1],tabs,item[2],UDim2.new(1/3,-8,0,34),UDim2.new((i-1)/3,5,0,6),dark,white,function()
        if i>unlocked then
            status="Уровень закрыт: сначала получи зелёный SUCCESS на предыдущем."
            statusColor=Color3.fromRGB(243,180,78)
            renderPanels()
            return
        end
        tab=item[1]; sampleIndex=1; metric=nil; success=false
        local value=request("GetBatch",tab,nil,sampleIndex)
        if value then batch=value end
        status="Уровень "..i.." открыт."
        statusColor=muted
        renderMain(); renderPanels()
    end)
end

local function freshGraph()
    graph={root=1,nodes={["1"]={kind="leaf",class=1}}}
    selectedId=1; nextId=2; metric=nil; success=false
end
local function prune(id)
    local node=graph.nodes[tostring(id)]
    if not node then return end
    if node.kind=="split" then prune(node.yes); prune(node.no) end
    graph.nodes[tostring(id)]=nil
end
local function currentNode()
    return graph.nodes[tostring(selectedId)]
end
local function changeNodeToLeaf()
    local node=currentNode()
    if node.kind=="split" then prune(node.yes); prune(node.no) end
    graph.nodes[tostring(selectedId)]={kind="leaf",class=1}
    metric=nil; success=false
    renderMain(); renderPanels()
end
local function addSplit()
    local node=currentNode()
    if node.kind~="leaf" then
        status="Сначала выбери лист, который нужно превратить в развилку."
        statusColor=Color3.fromRGB(243,180,78); renderPanels(); return
    end
    local total=0
    for _ in pairs(graph.nodes) do total=total+1 end
    if total+2>255 then
        status="Достигнут технический предел: 255 узлов дерева."
        statusColor=Color3.fromRGB(243,180,78); renderPanels(); return
    end
    local yesId,noId=nextId,nextId+1
    nextId=nextId+2
    graph.nodes[tostring(selectedId)]={kind="split",feature=1,op=">",threshold=38,yes=yesId,no=noId}
    graph.nodes[tostring(yesId)]={kind="leaf",class=1}
    graph.nodes[tostring(noId)]={kind="leaf",class=2}
    metric=nil; success=false
    renderMain(); renderPanels()
end

local function selectedDepth(id,target,depth)
    if id==target then return depth end
    local node=graph.nodes[tostring(id)]
    if node and node.kind=="split" then
        return selectedDepth(node.yes,target,depth+1) or selectedDepth(node.no,target,depth+1)
    end
    return nil
end
local function line(parent,x1,y1,x2,y2,color)
    local dx,dy=x2-x1,y2-y1
    local length=math.sqrt(dx*dx+dy*dy)
    local part=frame("Connector",parent,UDim2.fromOffset(length,2),
        UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),color)
    part.AnchorPoint=Vector2.new(0.5,0.5)
    part.Rotation=math.deg(math.atan2(dy,dx))
    part.ZIndex=1
end
local function pill(parent,value,x,y,color)
    local item=frame("BranchLabel",parent,UDim2.fromOffset(40,22),UDim2.fromOffset(x,y),color,11)
    item.ZIndex=3
    label("Text",item,value,UDim2.fromScale(1,1),UDim2.fromScale(0,0),12,dark,true,true).ZIndex=4
end
local function renderTree()
    clearGenerated(canvas)
    local locations={}
    local leaves=0
    local deepest=0
    local function place(id,depth)
        deepest=math.max(deepest,depth)
        local node=graph.nodes[tostring(id)]
        local x
        if node.kind=="leaf" then
            leaves=leaves+1
            x=110+(leaves-1)*188
        else
            local yesX=place(node.yes,depth+1)
            local noX=place(node.no,depth+1)
            x=(yesX+noX)/2
        end
        locations[id]={x=x,y=38+(depth-1)*120}
        return x
    end
    place(graph.root,1)
    canvas.CanvasSize=UDim2.fromOffset(math.max(650,leaves*188+80),math.max(430,deepest*120+35))
    for key,node in pairs(graph.nodes) do
        if node.kind=="split" then
            local id=tonumber(key)
            local origin=locations[id]
            local yesLoc,noLoc=locations[node.yes],locations[node.no]
            local startY=origin.y+73
            line(canvas,origin.x,startY,yesLoc.x,yesLoc.y,Color3.fromRGB(102,117,133))
            line(canvas,origin.x,startY,noLoc.x,noLoc.y,Color3.fromRGB(102,117,133))
            pill(canvas,"ДА",(origin.x+yesLoc.x)/2-20,(startY+yesLoc.y)/2-16,Color3.fromRGB(176,245,176))
            pill(canvas,"НЕТ",(origin.x+noLoc.x)/2-20,(startY+noLoc.y)/2-16,Color3.fromRGB(255,184,199))
        end
    end
    for key,node in pairs(graph.nodes) do
        local id=tonumber(key)
        local location=locations[id]
        local color=node.kind=="leaf" and colors[node.class] or Color3.fromRGB(242,243,246)
        local tile=frame("Node"..key,canvas,UDim2.fromOffset(154,70),
            UDim2.fromOffset(location.x-77,location.y),color,11)
        tile.ZIndex=5
        local outline=Instance.new("UIStroke")
        outline.Color=id==selectedId and warm or Color3.fromRGB(111,125,141)
        outline.Thickness=id==selectedId and 4 or 2
        outline.Parent=tile
        local caption
        if node.kind=="leaf" then caption="🍯  ОБРАБОТЧИК "..labels[node.class]
        else
            local meta=M.Features[node.feature]
            caption=meta.Name.." "..node.op.." "..string.format("%."..meta.Decimals.."f",node.threshold)
        end
        button("Select",tile,caption,UDim2.fromScale(1,1),UDim2.fromScale(0,0),
            color,node.kind=="leaf" and white or dark,function()
                selectedId=id
                renderMain()
            end).ZIndex=6
    end
end
local function renderInspector()
    clearGenerated(inspector)
    label("Title",inspector,"TREE BUILDER",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,8),15,dark,true)
    label("Help",inspector,"Выбери узел. Ветви ДА и НЕТ настраиваются отдельно.",
        UDim2.new(1,-16,0,55),UDim2.fromOffset(8,40),12,Color3.fromRGB(95,105,118),false)
    local node=currentNode()
    if node.kind=="split" then
        local meta=M.Features[node.feature]
        label("FeatureLabel",inspector,"ПРИЗНАК",UDim2.new(1,-16,0,22),UDim2.fromOffset(8,102),12,dark,true)
        button("Feature",inspector,meta.Name.."  ▾",UDim2.new(1,-16,0,38),UDim2.fromOffset(8,126),
            Color3.fromRGB(227,233,239),dark,function()
                node.feature=node.feature%#M.Features+1
                node.threshold=math.floor((M.Features[node.feature].Min+M.Features[node.feature].Max)/2*100+0.5)/100
                metric=nil; success=false; renderMain(); renderPanels()
            end)
        label("ConditionLabel",inspector,"УСЛОВИЕ",UDim2.new(1,-16,0,22),UDim2.fromOffset(8,170),12,dark,true)
        local operations={">",">=","<","<="}
        button("Operator",inspector,node.op,UDim2.fromOffset(48,38),UDim2.fromOffset(8,194),
            Color3.fromRGB(227,233,239),dark,function()
                for i,op in ipairs(operations) do
                    if op==node.op then node.op=operations[i%4+1]; break end
                end
                metric=nil; success=false; renderMain(); renderPanels()
            end)
        local input=Instance.new("TextBox")
        input.Name="Threshold"; input.Size=UDim2.new(1,-72,0,38)
        input.Position=UDim2.fromOffset(64,194)
        input.BackgroundColor3=Color3.fromRGB(227,233,239)
        input.BorderSizePixel=0; input.Text=tostring(node.threshold)
        input.TextSize=15; input.TextColor3=dark; input.Font=Enum.Font.Gotham
        input.ClearTextOnFocus=false; input.Parent=inspector
        local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=input
        input.FocusLost:Connect(function()
            local value=tonumber(input.Text)
            local active=M.Features[node.feature]
            if value and value>=active.Min and value<=active.Max then
                node.threshold=value; metric=nil; success=false
                renderMain(); renderPanels()
            else
                status="Порог должен быть от "..active.Min.." до "..active.Max.."."
                statusColor=Color3.fromRGB(237,105,96)
                input.Text=tostring(node.threshold); renderPanels()
            end
        end)
        label("BranchHint",inspector,"Нажми лист на схеме, чтобы выбрать обработчик A/B/C/D.",
            UDim2.new(1,-16,0,78),UDim2.fromOffset(8,238),12,Color3.fromRGB(95,105,118),false)
    else
        label("ClassLabel",inspector,"ОБРАБОТЧИК ЛИСТА",UDim2.new(1,-16,0,28),UDim2.fromOffset(8,110),12,dark,true)
        for i=1,4 do
            local row=math.floor((i-1)/2)
            local col=(i-1)%2
            button("Class"..i,inspector,labels[i],UDim2.new(0.5,-12,0,40),
                UDim2.new(col*0.5,8,0,143+row*48),colors[i],white,function()
                    node.class=i; metric=nil; success=false
                    renderMain(); renderPanels()
                end)
        end
        label("LeafHint",inspector,"Этот лист — конечный маршрут партии нектара.",
            UDim2.new(1,-16,0,70),UDim2.fromOffset(8,250),12,Color3.fromRGB(95,105,118),false)
    end
    button("AddSplit",inspector,"＋ Развилка",UDim2.new(1,-16,0,38),UDim2.new(0,8,1,-177),
        Color3.fromRGB(255,213,99),dark,function()
            if (selectedDepth(graph.root,selectedId,1) or 32)>=32 then
                status="Технический предел глубины — 32 уровня."
                statusColor=Color3.fromRGB(243,180,78); renderPanels(); return
            end
            addSplit()
        end)
    button("AddLeaf",inspector,"＋ Лист",UDim2.new(1,-16,0,38),UDim2.new(0,8,1,-133),
        Color3.fromRGB(225,232,239),dark,changeNodeToLeaf)
    button("Delete",inspector,"Удалить ветку",UDim2.new(1,-16,0,38),UDim2.new(0,8,1,-89),
        Color3.fromRGB(225,232,239),dark,changeNodeToLeaf)
    button("Reset",inspector,"Сбросить дерево",UDim2.new(1,-16,0,38),UDim2.new(0,8,1,-45),
        Color3.fromRGB(225,232,239),dark,function()
            freshGraph(); renderMain(); renderPanels()
        end)
end

local function alternateLine(value,height,color,bold)
    local row=frame("Info",alternate,UDim2.new(1,-12,0,height),UDim2.fromOffset(0,0),dark,9)
    row.LayoutOrder=#alternate:GetChildren()+1
    label("Text",row,value,UDim2.new(1,-26,1,-8),UDim2.fromOffset(13,4),
        16,color or white,bold)
    return row
end
local function alternateControl(title,value,down,up)
    local row=frame("Control",alternate,UDim2.new(1,-12,0,65),UDim2.fromOffset(0,0),dark,9)
    row.LayoutOrder=#alternate:GetChildren()+1
    label("Caption",row,title,UDim2.new(1,-180,1,0),UDim2.fromOffset(14,0),16,white,true)
    button("Minus",row,"−",UDim2.fromOffset(38,38),UDim2.new(1,-154,0,13),panel,white,down)
    label("Value",row,tostring(value),UDim2.fromOffset(52,38),UDim2.new(1,-108,0,13),18,warm,true,true)
    button("Plus",row,"+",UDim2.fromOffset(38,38),UDim2.new(1,-48,0,13),panel,white,up)
end
local function configuration()
    if tab=="Tree" then return {Graph=graph} end
    if tab=="Forest" then return {Count=forestCount,Depth=forestDepth} end
    return {Rounds=boostRounds,Depth=boostDepth}
end
local function evaluate()
    status="Сервер оценивает модель на validation..."
    statusColor=muted; renderPanels()
    local result=request("Evaluate",tab,configuration())
    if not result then return end
    metric=result.Metrics
    success=result.Success
    unlocked=result.Unlocked
    persistent=result.Persistent
    if success then
        status="SUCCESS — уровень пройден! "..(unlocked<=3 and "Следующий уровень открыт." or "Все уровни пройдены.")
        statusColor=green
    else
        status="Пока не пройдено. Измени модель и повтори проверку."
        statusColor=Color3.fromRGB(243,180,78)
    end
    renderPanels()
end
local function showBeacon(letter)
    local beacon=lab:FindFirstChild("ClassBeacon_"..letter)
    if not beacon then return end
    local highlight=Instance.new("Highlight")
    local index=table.find(labels,letter) or 1
    highlight.FillColor=colors[index]
    highlight.OutlineColor=Color3.new(1,1,1)
    highlight.FillTransparency=0.15
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent=beacon
    task.delay(2,function() if highlight.Parent then highlight:Destroy() end end)
end
local function simulate()
    status="Сортировка партии..."
    statusColor=muted; renderPanels()
    local result=request("Simulate",tab,configuration(),sampleIndex)
    if not result then return end
    local verdict=result.Guess==result.Actual and "верно" or "ошибка"
    status="Партия "..result.Id..": маршрут "..result.Guess.."; истинный класс "..result.Actual.." — "..verdict.."."
    statusColor=result.Guess==result.Actual and green or Color3.fromRGB(243,180,78)
    showBeacon(result.Guess)
    renderPanels()
end
button("Evaluate",footer,"ПРОВЕРИТЬ VALIDATION",UDim2.new(0.37,-10,0,40),UDim2.fromOffset(10,9),
    Color3.fromRGB(196,139,34),dark,evaluate)
button("Simulate",footer,"СОРТИРОВАТЬ ПАРТИЮ",UDim2.new(0.39,-10,0,40),UDim2.new(0.37,5,0,9),
    Color3.fromRGB(97,114,84),white,simulate)
button("Next",footer,"СЛЕДУЮЩАЯ →",UDim2.new(0.24,-15,0,40),UDim2.new(0.76,0,0,9),
    Color3.fromRGB(74,80,90),white,function()
        sampleIndex=sampleIndex%20+1
        local value=request("GetBatch",tab,nil,sampleIndex)
        if value then
            batch=value
            status="Выбрана партия "..value.Id..". Истинный класс скрыт до сортировки."
            statusColor=muted
            renderPanels()
        end
    end)

renderMain=function()
    local isTree=tab=="Tree"
    canvas.Visible=isTree; inspector.Visible=isTree; alternate.Visible=not isTree
    if isTree then
        renderTree(); renderInspector()
        return
    end
    clearGenerated(alternate)
    if tab=="Forest" then
        alternateLine("2 / СЛУЧАЙНЫЙ ЛЕС",52,warm,true)
        alternateLine("Каждое дерево учится на случайной выборке из 1080 учебных партий. На каждой развилке оно рассматривает случайные признаки. Итог — большинство голосов.",90,white,false)
        alternateControl("Деревья",forestCount,function()
            forestCount=math.max(3,forestCount-2); metric=nil; success=false; renderMain(); renderPanels()
        end,function()
            forestCount=math.min(11,forestCount+2); metric=nil; success=false; renderMain(); renderPanels()
        end)
        alternateControl("Глубина",forestDepth,function()
            forestDepth=math.max(2,forestDepth-1); metric=nil; success=false; renderMain(); renderPanels()
        end,function()
            forestDepth=math.min(5,forestDepth+1); metric=nil; success=false; renderMain(); renderPanels()
        end)
        local row=frame("Train",alternate,UDim2.new(1,-12,0,64),UDim2.fromOffset(0,0),dark,9)
        row.LayoutOrder=#alternate:GetChildren()+1
        button("Start",row,"ОБУЧИТЬ ЛЕС И ПРОВЕРИТЬ",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,11),
            Color3.fromRGB(196,139,34),dark,evaluate)
        alternateLine("Для SUCCESS нужны точность ≥78% и Macro-F1 ≥0,75 на 360 validation-партиях. Увеличение глубины и числа деревьев расходует больше вычислений.",83,muted,false)
    else
        alternateLine("3 / ГРАДИЕНТНЫЙ БУСТИНГ",52,warm,true)
        alternateLine("Настоящий многоклассовый gradient boosting: небольшие регрессионные деревья последовательно исправляют ошибки вероятностей классов. Источник — отдельный CSV из 3200 партий.",94,white,false)
        alternateControl("Этапы",boostRounds,function()
            boostRounds=math.max(10,boostRounds-10); metric=nil; success=false; renderMain(); renderPanels()
        end,function()
            boostRounds=math.min(60,boostRounds+10); metric=nil; success=false; renderMain(); renderPanels()
        end)
        alternateControl("Глубина",boostDepth,function()
            boostDepth=math.max(1,boostDepth-1); metric=nil; success=false; renderMain(); renderPanels()
        end,function()
            boostDepth=math.min(3,boostDepth+1); metric=nil; success=false; renderMain(); renderPanels()
        end)
        local row=frame("Train",alternate,UDim2.new(1,-12,0,64),UDim2.fromOffset(0,0),dark,9)
        row.LayoutOrder=#alternate:GetChildren()+1
        button("Start",row,"ОБУЧИТЬ БУСТИНГ И ПРОВЕРИТЬ",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,11),
            Color3.fromRGB(196,139,34),dark,evaluate)
        alternateLine("Для SUCCESS нужны точность ≥70% и Macro-F1 ≥0,65 на 640 validation-партиях. Больше этапов требуют больше вычислений.",80,muted,false)
    end
end
renderPanels=function()
    for i,item in ipairs(tabDefs) do
        local control=tabs:FindFirstChild("Tab"..item[1])
        if control then
            control.Text=(i>unlocked and "🔒 " or "")..item[2]
            control.BackgroundColor3=tab==item[1] and Color3.fromRGB(204,145,35) or dark
            control.TextColor3=tab==item[1] and dark or (i>unlocked and muted or white)
        end
    end
    if batch then
        local f=batch.Features
        batchText.Text=string.format("ID: %s  ·  test\n\nВода             %.2f%%\nСахар           %.2f%%\nКислотность   %.3f\nВязкость        %.3f\nТемпература %.2f°C\nАромат           %.3f\nЦвет               %.3f\nПыльца            %.3f",
            batch.Id,f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8])
    end
    if metric then
        metricsText.Text=string.format("VALIDATION · %d партий\nТочность: %.1f%% (%d/%d)\nMacro-F1: %.3f\n\nF1: A %.2f · B %.2f\n     C %.2f · D %.2f",
            metric.Total,metric.Accuracy*100,metric.Correct,metric.Total,
            metric.MacroF1,metric.ByClass[1],metric.ByClass[2],metric.ByClass[3],metric.ByClass[4])
    else
        metricsText.Text="VALIDATION\n\nНажми «Проверить», чтобы увидеть точность и Macro-F1."
    end
    statusText.Text=status..(persistent and "" or "\n\nВ Studio сохранение может быть недоступно; сейчас прогресс временный.")
    statusText.Text=status..(persistent and "" or "\n\nСохранение сейчас недоступно; прогресс только на эту сессию.")
    statusText.TextColor3=statusColor
end
local initial=request("GetState")
if initial then unlocked=initial.Unlocked; persistent=initial.Persistent end
batch=request("GetBatch","Tree",nil,1)
renderMain(); renderPanels()
local openButton=button("OpenLab",gui,"ЛАБОРАТОРИЯ ДЕРЕВЬЕВ",UDim2.fromOffset(255,45),
    UDim2.new(0,18,1,-62),Color3.fromRGB(205,146,35),dark,function() shade.Visible=true end)
openButton.ZIndex=2
prompt.Triggered:Connect(function() shade.Visible=true end)
