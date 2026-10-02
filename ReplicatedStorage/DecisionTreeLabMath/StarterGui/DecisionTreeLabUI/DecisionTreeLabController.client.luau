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
local batchTotal=20 -- сколько партий в test-датасете уровня (сервер присылает Total)
local batch
local metric
local success=false
local status="Построй дерево: выбери лист, добавь развилку и настрой обе ветви. Потом пройди окончательную проверку на всём test-датасете уровня."
local statusColor=muted
local forestCount,forestDepth=5,3
local forestRandom=true
local forestView -- ответ ForestExplain для «лес голосует»
local boostRound,boostDepth,boostRate=0,2,0.2
local boostView -- ответ BoostExplain для «бустинг по раундам»
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
label("BatchTitle",sidebar,"ПАРТИЯ УРОЖАЯ (1 строка test-датасета)",UDim2.new(1,-26,0,29),UDim2.fromOffset(14,12),16,warm,true)
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
        forestView=nil; boostView=nil; boostRound=0
        local value=request("GetBatch",tab,nil,sampleIndex)
        if value then batch=value; batchTotal=value.Total or batchTotal end
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
    if tab=="Forest" then return {Count=forestCount,Depth=forestDepth,RandomFeatures=forestRandom} end
    return {Rounds=boostRound,Depth=boostDepth,Rate=boostRate}
end
local function percent(value) return string.format("%.1f%%",value*100) end
local function questionText(q)
    if not q then return "лист без вопроса" end
    return string.format("%s ≤ %."..q.Decimals.."f ?",q.Feature,q.Threshold)
end
-- A · «Лес голосует»: каждое дерево — своя корзина партий и свой голос за выбранную партию урожая
local function explainForest()
    status="Лес собирается: каждое дерево получает свою корзину из 1080 учебных партий..."
    statusColor=muted; renderPanels()
    local result=request("ForestExplain","Forest",configuration(),sampleIndex)
    if not result then return end
    forestView=result
    local right=result.Forest==result.Actual
    status="Партия "..result.Id..": лес проголосовал за "..result.Forest..", истинный класс "..result.Actual..
        (right and " — верно." or " — ошибка.").."\nЛистай партии ◀ ▶ — голоса обновятся."
    statusColor=right and green or Color3.fromRGB(243,180,78)
    renderMain(); renderPanels()
end
-- B · «Бустинг исправляет ошибки»: раунд за раундом, каждое новое дерево учится на остатках ошибок
local function explainBoost()
    local result=request("BoostExplain","Boost",configuration(),sampleIndex)
    if not result then return end
    boostView=result
    if result.Round==0 then
        status="Раунд 0: модель знает только, какие классы встречаются чаще. Нажми «+1 РАУНД»."
        statusColor=muted
    else
        local right=result.Guess==result.Actual
        status="Раунд "..result.Round..": партия "..result.Id.." → "..result.Guess..", истинный класс "..result.Actual..
            (right and " — верно." or " — пока ошибка.").." Ошибок на обучении: "..result.Wrong.." из "..result.TrainTotal.."."
        statusColor=right and green or Color3.fromRGB(243,180,78)
    end
    renderMain(); renderPanels()
end
local function setBoostRound(value)
    boostRound=math.clamp(value,0,60); metric=nil; success=false
    explainBoost()
end
-- «Пройти окончательную проверку»: сервер прогоняет модель по ВСЕМ партиям test-датасета уровня
local function evaluate()
    status="Окончательная проверка: модель сортирует все "..batchTotal.." партий test-датасета уровня..."
    if tab=="Boost" and boostRound==0 then
        status="Сначала обучи хотя бы один раунд бустинга (+1 РАУНД)."
        statusColor=Color3.fromRGB(243,180,78); renderPanels()
        return
    end
    statusColor=muted; renderPanels()
    local result=request("Evaluate",tab,configuration())
    if not result then return end
    metric=result.Metrics
    success=result.Success
    unlocked=result.Unlocked
    persistent=result.Persistent
    if success then
        status="SUCCESS — окончательная проверка пройдена на всех "..metric.Total.." партиях! "..(unlocked<=3 and "Следующий уровень открыт." or "Все уровни пройдены.")
        statusColor=green
    else
        status="Окончательная проверка не пройдена ("..metric.Total.." партий). Измени модель и повтори."
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
-- «Посмотреть на test-датасете»: прогноз модели для ОДНОЙ выбранной партии (одной строки датасета)
local function simulate()
    status="Модель сортирует партию "..sampleIndex.." из "..batchTotal.."..."
    statusColor=muted; renderPanels()
    local result=request("Simulate",tab,configuration(),sampleIndex)
    if not result then return end
    local verdict=result.Guess==result.Actual and "верно" or "ошибка"
    status="Партия "..result.Id.." ("..sampleIndex.." из "..batchTotal.."): маршрут "..result.Guess.."; истинный класс "..result.Actual.." — "..verdict..
        ".\nЭто одна партия — одна строка датасета. Чтобы пройти уровень, нужна окончательная проверка по всем "..batchTotal.." партиям."
    statusColor=result.Guess==result.Actual and green or Color3.fromRGB(243,180,78)
    showBeacon(result.Guess)
    renderPanels()
end
-- Подвал: ◀ ▶ — листать партии урожая test-датасета; «Посмотреть» — прогноз для одной партии;
-- «Окончательная проверка» — все партии test-датасета уровня (только она открывает следующий уровень).
local function stepBatch(delta)
    sampleIndex=(sampleIndex-1+delta)%batchTotal+1
    local value=request("GetBatch",tab,nil,sampleIndex)
    if value then
        batch=value
        batchTotal=value.Total or batchTotal
        status="Партия "..value.Id.." ("..sampleIndex.." из "..batchTotal.."). Истинный класс скрыт, пока модель её не отсортирует."
        statusColor=muted
        renderPanels()
        if tab=="Forest" and forestView then explainForest() end
        if tab=="Boost" and boostView then explainBoost() end
    end
end
button("Prev",footer,"◀ ПАРТИЯ",UDim2.new(0.13,-10,0,40),UDim2.fromOffset(10,9),
    Color3.fromRGB(74,80,90),white,function() stepBatch(-1) end)
button("Next",footer,"ПАРТИЯ ▶",UDim2.new(0.13,-10,0,40),UDim2.new(0.13,5,0,9),
    Color3.fromRGB(74,80,90),white,function() stepBatch(1) end)
button("Simulate",footer,"ПОСМОТРЕТЬ НА TEST-ДАТАСЕТЕ",UDim2.new(0.34,-10,0,40),UDim2.new(0.26,0,0,9),
    Color3.fromRGB(97,114,84),white,simulate)
button("Evaluate",footer,"ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ",UDim2.new(0.40,-10,0,40),UDim2.new(0.60,0,0,9),
    Color3.fromRGB(196,139,34),dark,evaluate)

renderMain=function()
    local isTree=tab=="Tree"
    canvas.Visible=isTree; inspector.Visible=isTree; alternate.Visible=not isTree
    if isTree then
        renderTree(); renderInspector()
        return
    end
    clearGenerated(alternate)
    local function block(name,height)
        local row=frame(name,alternate,UDim2.new(1,-12,0,height),UDim2.fromOffset(0,0),dark,9)
        row.LayoutOrder=#alternate:GetChildren()+1
        return row
    end
    local function rect(name,parent,size,pos,color)
        local x=frame(name,parent,size,pos,color)
        return x
    end
    local function changed() metric=nil; success=false; renderMain(); renderPanels() end
    local function finalCheck(text)
        local row=block("Train",64)
        button("Start",row,"ПРОЙТИ ОКОНЧАТЕЛЬНУЮ ПРОВЕРКУ",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,11),
            Color3.fromRGB(196,139,34),dark,evaluate)
        alternateLine(text,70,muted,false)
    end
    if tab=="Forest" then
        alternateLine("2 / СЛУЧАЙНЫЙ ЛЕС · ЛЕС ГОЛОСУЕТ",52,warm,true)
        alternateLine("Каждое дерево получает свою корзину: 1080 партий, вытянутых из учебного урожая с возвращением (одни партии попадут дважды, другие — ни разу). Деревья выходят разными, и каждое голосует за класс. Ответ леса — большинство голосов.",104,white,false)
        alternateControl("Деревья",forestCount,function()
            forestCount=math.max(3,forestCount-2); forestView=nil; changed()
        end,function()
            forestCount=math.min(11,forestCount+2); forestView=nil; changed()
        end)
        alternateControl("Глубина",forestDepth,function()
            forestDepth=math.max(2,forestDepth-1); forestView=nil; changed()
        end,function()
            forestDepth=math.min(5,forestDepth+1); forestView=nil; changed()
        end)
        local toggle=block("RandomFeatures",65)
        label("Caption",toggle,"Случайные признаки на развилках",UDim2.new(1,-220,1,0),UDim2.fromOffset(14,0),16,white,true)
        button("Toggle",toggle,forestRandom and "ВКЛ" or "ВЫКЛ",UDim2.fromOffset(190,38),UDim2.new(1,-202,0,13),
            forestRandom and Color3.fromRGB(97,114,84) or Color3.fromRGB(74,80,90),white,function()
            forestRandom=not forestRandom; forestView=nil; changed()
        end)
        local grow=block("Grow",64)
        button("Explain",grow,"СОБРАТЬ ЛЕС И ПОКАЗАТЬ ГОЛОСА",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,11),
            Color3.fromRGB(97,114,84),white,explainForest)
        local view=forestView
        if view then
            local votes={}
            for c=1,4 do votes[c]=labels[c].." "..view.Votes[c] end
            alternateLine("Партия "..view.Id.." ("..view.Index.." из "..view.Total.."): голоса "..table.concat(votes," · ")..
                "  →  лес: "..view.Forest.."   ·   истинный класс: "..view.Actual..(view.Forest==view.Actual and "  ✔" or "  ✘"),
                52,view.Forest==view.Actual and green or Color3.fromRGB(243,180,78),true)
            local columns=4
            local rows=math.ceil(#view.Trees/columns)
            local grid=block("Trees",rows*156+8)
            grid.BackgroundTransparency=1
            for i,tree in ipairs(view.Trees) do
                local col,row=(i-1)%columns,math.floor((i-1)/columns)
                local cardFrame=frame("Tree"..i,grid,UDim2.new(1/columns,-8,0,148),UDim2.new(col/columns,4,0,row*156+4),panel,9)
                local vote=table.find(labels,tree.Vote) or 1
                label("Name",cardFrame,"ДЕРЕВО "..i,UDim2.new(0.6,-10,0,22),UDim2.fromOffset(10,6),14,warm,true)
                local badge=frame("Vote",cardFrame,UDim2.fromOffset(46,30),UDim2.new(1,-54,0,6),colors[vote],8)
                label("Letter",badge,tree.Vote,UDim2.fromScale(1,1),UDim2.fromScale(0,0),18,dark,true,true)
                label("Bag",cardFrame,"Корзина: "..tree.Size.." партий, разных "..tree.Unique,UDim2.new(1,-20,0,20),UDim2.fromOffset(10,38),12,muted,false)
                local strip=frame("Classes",cardFrame,UDim2.new(1,-20,0,12),UDim2.fromOffset(10,60),dark,4)
                local offset=0
                for c=1,4 do
                    local share=tree.Classes[c]/tree.Size
                    rect("Class"..labels[c],strip,UDim2.new(share,0,1,0),UDim2.new(offset,0,0,0),colors[c])
                    offset=offset+share
                end
                label("Root",cardFrame,"1-й вопрос: "..questionText(tree.Root),UDim2.new(1,-20,0,36),UDim2.fromOffset(10,76),12,white,false)
                label("Accuracy",cardFrame,"Одно дерево на test: "..percent(tree.Accuracy),UDim2.new(1,-20,0,22),UDim2.fromOffset(10,116),12,muted,false)
            end
            -- точность леса из первых k деревьев: видно, как голосование выравнивает ошибки отдельных деревьев
            local chart=block("AccuracyByCount",210)
            label("Caption",chart,"Точность на test-датасете: лес из первых k деревьев",UDim2.new(1,-24,0,24),UDim2.fromOffset(12,6),14,warm,true)
            local area=frame("Area",chart,UDim2.new(1,-24,0,150),UDim2.fromOffset(12,40),panel,6)
            local low=0.4
            local function height(value) return math.clamp((value-low)/(1-low),0,1) end
            local gate=rect("Gate",area,UDim2.new(1,0,0,2),UDim2.new(0,0,1-height(0.78),0),warm)
            gate.BackgroundTransparency=0.3
            label("GateText",area,"порог 78%",UDim2.fromOffset(80,16),UDim2.new(1,-84,1-height(0.78),-18),11,warm,false)
            local count=#view.AccByCount
            for k,value in ipairs(view.AccByCount) do
                local h=height(value)
                local column=rect("Count"..k,area,UDim2.new(1/count,-10,h,0),UDim2.new((k-1)/count,5,1-h,0),
                    value>=0.78 and green or Color3.fromRGB(110,140,190))
                label("Value",column,string.format("%d",math.floor(value*100+0.5)),UDim2.new(1,0,0,16),UDim2.fromOffset(0,2),11,dark,true,true)
                label("K",area,tostring(k),UDim2.new(1/count,0,0,14),UDim2.new((k-1)/count,0,1,2),11,muted,false,true)
            end
            alternateLine(string.format("Деревья согласны между собой в %s случаев. Среднее одно дерево: %s, лес из %d: %s. %s",
                percent(view.Agreement),percent(view.Single),count,percent(view.AccByCount[count]),
                view.RandomFeatures and "Случайные признаки делают деревья разными: их ошибки реже совпадают, и голосование их гасит."
                    or "Без случайных признаков деревья похожи друг на друга и часто ошибаются вместе — включи их и сравни."),
                88,white,false)
        else
            alternateLine("Нажми «Собрать лес и показать голоса»: увидишь корзины деревьев, их голоса за выбранную партию и как точность растёт с числом деревьев.",70,muted,false)
        end
        finalCheck("Для SUCCESS нужны точность ≥78% и Macro-F1 ≥0,75 на всём test-датасете уровня ("..batchTotal.." партий).")
    else
        alternateLine("3 / ГРАДИЕНТНЫЙ БУСТИНГ · ИСПРАВЛЕНИЕ ОШИБОК",52,warm,true)
        alternateLine("Модель начинает с догадки «как обычно» и обучается раундами. Каждый раунд маленькое дерево смотрит, где модель ошибается сильнее всего, и сдвигает вероятности классов. Шаг обучения — насколько сильно один раунд меняет ответ.",104,white,false)
        alternateControl("Глубина деревьев",boostDepth,function()
            boostDepth=math.max(1,boostDepth-1); boostView=nil; boostRound=0; changed()
        end,function()
            boostDepth=math.min(3,boostDepth+1); boostView=nil; boostRound=0; changed()
        end)
        local rates=M.LearningRates
        alternateControl("Шаг обучения",boostRate,function()
            local i=table.find(rates,boostRate) or 1
            boostRate=rates[math.max(1,i-1)]; boostView=nil; boostRound=0; changed()
        end,function()
            local i=table.find(rates,boostRate) or 1
            boostRate=rates[math.min(#rates,i+1)]; boostView=nil; boostRound=0; changed()
        end)
        local steps=block("Rounds",65)
        label("Caption",steps,"Раунд "..boostRound.." из 60",UDim2.new(0.3,-14,1,0),UDim2.fromOffset(14,0),17,warm,true)
        local function stepButton(name,text,index,value)
            button(name,steps,text,UDim2.new(0.175,-8,0,38),UDim2.new(0.3+(index-1)*0.175,0,0,13),
                Color3.fromRGB(74,80,90),white,function() setBoostRound(value) end)
        end
        stepButton("Reset","СНАЧАЛА",1,0)
        stepButton("Back","−1",2,boostRound-1)
        stepButton("Step","+1 РАУНД",3,boostRound+1)
        stepButton("Step10","+10",4,boostRound+10)
        local view=boostView
        if view then
            local actual=table.find(labels,view.Actual) or 1
            local probs=block("Probabilities",150)
            label("Caption",probs,"Партия "..view.Id.." ("..view.Index.." из "..view.Total.."): вероятности классов после раунда "..view.Round,
                UDim2.new(1,-24,0,24),UDim2.fromOffset(12,6),14,warm,true)
            for c=1,4 do
                local y=34+(c-1)*28
                local isActual=c==actual
                label("Class"..labels[c],probs,labels[c]..(isActual and " ★" or ""),UDim2.fromOffset(44,24),UDim2.fromOffset(12,y),15,isActual and warm or white,true)
                local track=frame("Track"..labels[c],probs,UDim2.new(1,-150,0,18),UDim2.fromOffset(60,y+3),panel,5)
                rect("Fill",track,UDim2.new(math.clamp(view.Probs[c],0,1),0,1,0),UDim2.fromScale(0,0),colors[c])
                label("P"..labels[c],probs,percent(view.Probs[c]),UDim2.fromOffset(80,24),UDim2.new(1,-84,0,y),14,white,isActual)
            end
            -- вероятность истинного класса этой партии раунд за раундом
            local function pointChart(name,caption,series,colorsBySeries,mark)
                local chart=block(name,190)
                label("Caption",chart,caption,UDim2.new(1,-24,0,24),UDim2.fromOffset(12,6),14,warm,true)
                local area=frame("Area",chart,UDim2.new(1,-24,0,130),UDim2.fromOffset(12,40),panel,6)
                local n=math.max(#series[1]-1,1)
                if mark then
                    local line=rect("Best",area,UDim2.new(0,2,1,0),UDim2.new(mark/n,-1,0,0),warm)
                    line.BackgroundTransparency=0.4
                end
                for s,values in ipairs(series) do
                    for r,value in ipairs(values) do
                        local dot=frame("Dot"..s.."_"..(r-1),area,UDim2.fromOffset(6,6),
                            UDim2.new((r-1)/n,0,1-math.clamp(value,0,1),0),colorsBySeries[s],3)
                        dot.AnchorPoint=Vector2.new(0.5,0.5)
                    end
                end
                label("Axis",chart,"раунд 0 … "..(#series[1]-1),UDim2.new(1,-24,0,16),UDim2.fromOffset(12,172),11,muted,false)
            end
            pointChart("History","Вероятность истинного класса "..view.Actual.." для этой партии по раундам",{view.History},{colors[actual]})
            if view.Round>=1 then
                local parts={}
                for c=1,4 do parts[c]=labels[c]..": "..questionText(view.LastStage[c] or nil) end
                alternateLine("Деревья раунда "..view.Round.." (по одному на класс) спрашивают:\n"..table.concat(parts,"\n"),112,white,false)
            end
            local hard={}
            for k,item in ipairs(view.Hard) do hard[k]=item.Id.." ("..item.Actual..", "..percent(item.P)..")" end
            alternateLine("Ошибок на обучении: "..view.Wrong.." из "..view.TrainTotal..". Самые трудные партии — на них следующие деревья смотрят в первую очередь (класс, вероятность истинного класса):\n"..table.concat(hard,"  ·  "),
                96,white,false)
            pointChart("Overfit","Точность по раундам: ● train (учебный урожай)  ● test (новые партии)",
                {view.TrainAcc,view.TestAcc},{Color3.fromRGB(110,140,190),green},view.BestTestRound)
            local trainNow,testNow=view.TrainAcc[#view.TrainAcc],view.TestAcc[#view.TestAcc]
            alternateLine(string.format("Сейчас: train %s, test %s. Лучший test был на раунде %d (жёлтая черта). %s",
                percent(trainNow),percent(testNow),view.BestTestRound,
                view.Round>view.BestTestRound+5 and "Train ещё растёт, а test — нет: модель начинает заучивать учебный урожай (переобучение)."
                    or "Пока новые раунды помогают и на test."),70,white,false)
        else
            alternateLine("Нажми «+1 РАУНД», чтобы обучить первое дерево и увидеть, как меняются вероятности для выбранной партии.",56,muted,false)
        end
        finalCheck("Окончательная проверка использует модель из "..boostRound.." раундов. Для SUCCESS нужны точность ≥70% и Macro-F1 ≥0,65 на всём test-датасете уровня ("..batchTotal.." партий).")
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
        batchText.Text=string.format("Партия %d из %d · ID %s\n(одна строка test-датасета)\n\nВода             %.2f%%\nСахар           %.2f%%\nКислотность   %.3f\nВязкость        %.3f\nТемпература %.2f°C\nАромат           %.3f\nЦвет               %.3f\nПыльца            %.3f",
            sampleIndex,batchTotal,batch.Id,f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8])
    end
    if metric then
        metricsText.Text=string.format("ОКОНЧАТЕЛЬНАЯ ПРОВЕРКА\nвесь test-датасет уровня · %d партий\nТочность: %.1f%% (%d/%d)\nMacro-F1: %.3f\n\nF1: A %.2f · B %.2f\n     C %.2f · D %.2f",
            metric.Total,metric.Accuracy*100,metric.Correct,metric.Total,
            metric.MacroF1,metric.ByClass[1],metric.ByClass[2],metric.ByClass[3],metric.ByClass[4])
    else
        metricsText.Text="ОКОНЧАТЕЛЬНАЯ ПРОВЕРКА\n\nНажми «Пройти окончательную проверку»: модель отсортирует все "..batchTotal.." партий test-датасета уровня."
    end
    -- прогресс лаборатории намеренно не сохраняется между заходами
    statusText.Text=status
    statusText.TextColor3=statusColor
end
local initial=request("GetState")
if initial then unlocked=initial.Unlocked; persistent=initial.Persistent end
batch=request("GetBatch","Tree",nil,1)
if batch then batchTotal=batch.Total or batchTotal end
renderMain(); renderPanels()
local openButton=button("OpenLab",gui,"ЛАБОРАТОРИЯ ДЕРЕВЬЕВ",UDim2.fromOffset(255,45),
    UDim2.new(0,18,1,-62),Color3.fromRGB(205,146,35),dark,function() shade.Visible=true end)
openButton.ZIndex=2
prompt.Triggered:Connect(function() shade.Visible=true end)
