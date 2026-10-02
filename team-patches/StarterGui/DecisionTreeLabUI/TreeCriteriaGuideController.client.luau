local gui=script.Parent
local function child(parent,name)
    local found=parent:WaitForChild(name,30)
    assert(found,"Criteria guide could not find "..name)
    return found
end
local shade=child(gui,"Shade")
local card=child(shade,"Laboratory")
local sidebar=child(card,"Sidebar")
local tabs=child(card,"Tabs")
local treeTab=child(tabs,"TabTree")
local batchTitle=child(sidebar,"BatchTitle")
local batchText=child(sidebar,"BatchText")
local metricsText=child(sidebar,"Metrics")
local statusText=child(sidebar,"Status")

if sidebar:FindFirstChild("TreeCriteriaGuide") then return end

local function frame(name,parent,size,position,color,radius)
    local item=Instance.new("Frame")
    item.Name=name
    item.Size=size
    item.Position=position
    item.BackgroundColor3=color
    item.BorderSizePixel=0
    item.Parent=parent
    if radius then
        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,radius)
        corner.Parent=item
    end
    return item
end
local function label(name,parent,value,size,position,textSize,color,bold)
    local item=Instance.new("TextLabel")
    item.Name=name
    item.Size=size
    item.Position=position
    item.BackgroundTransparency=1
    item.Text=value
    item.TextColor3=color
    item.TextSize=textSize
    item.TextScaled=false
    item.TextWrapped=true
    item.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    item.TextXAlignment=Enum.TextXAlignment.Left
    item.TextYAlignment=Enum.TextYAlignment.Center
    item.Parent=parent
    return item
end

local white=Color3.fromRGB(246,247,249)
local muted=Color3.fromRGB(185,192,201)
local amber=Color3.fromRGB(253,195,63)
local guide=frame("TreeCriteriaGuide",sidebar,UDim2.new(1,-20,0,372),
    UDim2.fromOffset(10,10),Color3.fromRGB(47,52,61),10)
label("Heading",guide,"КРИТЕРИИ СОРТИРОВЩИКОВ",UDim2.new(1,-20,0,25),
    UDim2.fromOffset(10,8),15,amber,true)
label("Intro",guide,"Какие партии принимает каждый выход:",UDim2.new(1,-20,0,18),
    UDim2.fromOffset(10,32),12,muted,false)

local rules={
    {"A","вода > 38%",Color3.fromRGB(53,148,231),54,45},
    {"B","вода ≤ 38%\nсахар < 60%",Color3.fromRGB(78,185,102),103,55},
    {"C","вода ≤ 38%\nсахар ≥ 60%\nкислотность < 4,2",Color3.fromRGB(244,184,47),162,70},
    {"D","вода ≤ 38%\nсахар ≥ 60%\nкислотность ≥ 4,2",Color3.fromRGB(229,90,135),236,70},
}
for _,rule in ipairs(rules) do
    local letter,value,color,y,height=rule[1],rule[2],rule[3],rule[4],rule[5]
    local row=frame("Sorter"..letter,guide,UDim2.new(1,-20,0,height),
        UDim2.fromOffset(10,y),Color3.fromRGB(33,38,47),7)
    frame("Color",row,UDim2.fromOffset(5,height),UDim2.fromOffset(0,0),color,3)
    label("Letter",row,letter,UDim2.fromOffset(25,height),UDim2.fromOffset(12,0),18,color,true)
    label("Rule",row,value,UDim2.new(1,-45,1,-4),UDim2.fromOffset(42,2),13,white,false)
end
local note=label("Note",guide,
    "Это учебные ориентиры. В CSV есть исключения; результат проверяется на validation.",
    UDim2.new(1,-20,0,55),UDim2.fromOffset(10,310),12,muted,false)
note.TextYAlignment=Enum.TextYAlignment.Top

local activeColor=Color3.fromRGB(204,145,35)
local lastActive=nil
local function sync()
    local active=treeTab.BackgroundColor3==activeColor
    if active==lastActive then return end
    lastActive=active
    local shift=active and 382 or 0
    guide.Visible=active
    batchTitle.Position=UDim2.fromOffset(14,12+shift)
    batchText.Position=UDim2.fromOffset(14,48+shift)
    metricsText.Position=UDim2.fromOffset(14,290+shift)
    statusText.Position=UDim2.fromOffset(14,490+shift)
    sidebar.CanvasSize=UDim2.fromOffset(0,635+shift)
    sidebar.CanvasPosition=Vector2.new(0,0)
end
treeTab:GetPropertyChangedSignal("BackgroundColor3"):Connect(sync)
sync()
