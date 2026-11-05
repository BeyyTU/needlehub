-- BeyyHub | Sell Fries! | Lobby capture v0.4.0
-- Captures the lobby and queues the SAME loader for the next gameplay teleport.
if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId~=10767380385 then warn("[BeyyHub Fries] Wrong Roblox experience");return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui",15)
if not pg then warn("[BeyyHub Fries] PlayerGui missing");return end
local env=type(getgenv)=="function" and getgenv() or _G
if type(env.BeyyFriesHub)=="table" and type(env.BeyyFriesHub.Unload)=="function" then
    pcall(env.BeyyFriesHub.Unload)
end
local gui=Instance.new("ScreenGui")
gui.Name="BeyyFriesNativeHub"
gui.ResetOnSpawn=false
gui.DisplayOrder=10000
gui.Parent=pg
local function make(cls,parent,props)
    local o=Instance.new(cls)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local colors={bg=Color3.fromRGB(20,22,27),row=Color3.fromRGB(32,35,42),
    text=Color3.fromRGB(231,234,240),accent=Color3.fromRGB(58,104,153)}
local base=make("Frame",gui,{Size=UDim2.fromOffset(640,480),AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=colors.bg,BorderSizePixel=0})
local scale=make("UIScale",base,{Scale=1})
local function fit()
    scale.Scale=math.min(1,math.max(0.1,(gui.AbsoluteSize.X-12)/640),
        math.max(0.1,(gui.AbsoluteSize.Y-12)/480))
end
local connections={}
local function on(signal,fn)
    local c=signal:Connect(fn)
    connections[#connections+1]=c
    return c
end
on(gui:GetPropertyChangedSignal("AbsoluteSize"),fit);fit()
local header=make("TextLabel",base,{Position=UDim2.fromOffset(12,4),
    Size=UDim2.new(1,-55,0,29),BackgroundTransparency=1,
    Text="BeyyHub | Sell Fries!  Lobby v0.4.0",TextColor3=colors.text,
    TextSize=18,Font=Enum.Font.SourceSansBold,TextXAlignment=Enum.TextXAlignment.Left})
local close=make("TextButton",base,{Position=UDim2.new(1,-37,0,5),Size=UDim2.fromOffset(28,24),
    Text="X",TextColor3=colors.text,TextSize=16,BackgroundColor3=colors.row})
local sidebar=make("Frame",base,{Position=UDim2.fromOffset(5,38),
    Size=UDim2.new(0,174,1,-74),BackgroundTransparency=1})
make("UIListLayout",sidebar,{Padding=UDim.new(0,7)})
local pages={}
local tabs={}
local function switch(page)
    for _,p in ipairs(pages)do p.Visible=p==page end
    for _,v in ipairs(tabs)do v.Button.BackgroundColor3=v.Page==page and colors.accent or colors.row end
end
local window={Gui=gui}
function window:Tab(opts)
    local tab={}
    local nav=make("TextButton",sidebar,{
        Size=UDim2.new(1,0,0,34),Text=tostring(opts.Title or "Tab"),
        BackgroundColor3=colors.row,TextColor3=colors.text,TextSize=15,
        BorderSizePixel=0})
    local pane=make("ScrollingFrame",base,{Position=UDim2.fromOffset(190,38),
        Size=UDim2.new(1,-198,1,-79),BackgroundTransparency=1,
        BorderSizePixel=0,ScrollBarThickness=4,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Visible=false})
    make("UIListLayout",pane,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
    make("UIPadding",pane,{PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),
        PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,8)})
    table.insert(pages,pane)
    table.insert(tabs,{Page=pane,Button=nav})
    on(nav.Activated,function()switch(pane)end)
    if #pages==1 then switch(pane)end
    function tab:Section(o)
        return make("TextLabel",pane,{Size=UDim2.new(1,-5,0,29),
            BackgroundTransparency=1,Text=tostring(o.Title or ""),
            Font=Enum.Font.SourceSansBold,TextSize=17,TextColor3=colors.text,
            TextXAlignment=Enum.TextXAlignment.Left})
    end
    function tab:Button(o)
        local b=make("TextButton",pane,{Size=UDim2.new(1,-4,0,34),
            BackgroundColor3=colors.row,BorderSizePixel=0,
            Text=tostring(o.Title or ""),TextColor3=colors.text,TextSize=15})
        on(b.Activated,function()
            if type(o.Callback)=="function" then
                local ok,err=pcall(o.Callback)
                if not ok then warn("[BeyyHub Fries] Button error: "..tostring(err))end
            end
        end)
        return b
    end
    function tab:Paragraph(o)
        local label=make("TextLabel",pane,{Size=UDim2.new(1,-4,0,104),
            BackgroundColor3=colors.row,BorderSizePixel=0,
            TextColor3=colors.text,TextSize=14,TextWrapped=true,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
            Text=tostring(o.Desc or "")})
        local item={}
        function item:SetDesc(text) label.Text=tostring(text)end
        return item
    end
    return tab
end
local notice=make("TextLabel",base,{Position=UDim2.new(0,10,1,-32),
    Size=UDim2.new(1,-20,0,27),BackgroundTransparency=1,TextColor3=colors.text,
    TextSize=14,Text="Lobby capture loading",TextXAlignment=Enum.TextXAlignment.Left})
window.Notice=notice
local state={Running=true,Version="0.4.0",PlaceId=game.PlaceId,Logs={},Started=os.clock(),
    FullCaptureStatus="Initializing exporter"}
env.BeyyFriesHub=state
local function notify(title,msg)
    notice.Text=tostring(title)..": "..tostring(msg):sub(1,120)
end
local function log(kind,msg)
    state.Logs[#state.Logs+1]={Kind=tostring(kind),Detail=tostring(msg):sub(1,180),At=os.clock()}
    if #state.Logs>80 then table.remove(state.Logs,1)end
    print("[BeyyHub Fries Lobby] "..tostring(kind).." "..tostring(msg))
end
local queued=false
local function queueNext()
    local q=queue_on_teleport
    if type(q)~="function" then q=queueonteleport end
    if type(q)~="function" and type(syn)=="table" then q=syn.queue_on_teleport end
    if type(q)~="function" and type(fluxus)=="table" then q=fluxus.queue_on_teleport end
    if type(q)~="function" and type(env.queue_on_teleport)=="function" then q=env.queue_on_teleport end
    if type(q)~="function" then return false,"Executor has no teleport-queue API"end
    local code='loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/loader-sell-fries.lua?refresh=" .. tostring(os.time())))()'
    local ok,err=pcall(q,code)
    return ok,ok and "Auto-reload queued for the next teleport" or tostring(err)
end
local okQueue,msg=queueNext()
queued=okQueue
log("TeleportQueue",msg)
local main=window:Tab({Title="Lobby"})
main:Section({Title="Sell Fries lobby"})
local explanation=main:Paragraph({Title="Lobby mode",Desc="Lobby place: "..game.PlaceId
    .."\nThe game map exporter captures lobby objects here. Use the normal PLAY station to join a match."
    .."\nTeleport continuation: "..(queued and "Queued" or "Unavailable")})
main:Button({Title="Queue BeyyHub on next teleport",Callback=function()
    local ok,msg=queueNext()
    queued=ok;notify("Teleport",msg)
end})
main:Button({Title="Show capture status",Callback=function()notify("Capture",state.FullCaptureStatus)end})
local function createCapture()
    local url="https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/sell-fries-capture.lua"
    local ok,source=pcall(function()return game:HttpGet(url.."?refresh="..tostring(os.time()))end)
    if not ok or type(source)~="string" or #source<8000 then
        state.FullCaptureStatus="Could not download exporter"
        log("CaptureError",tostring(source))
        return
    end
    local old='local exportPath="BeyyHub/sell_fries_game_map.json"'
    if not source:find(old,1,true)then
        state.FullCaptureStatus="Exporter format changed; update required"
        return
    end
    source=source:gsub(old,'local exportPath="BeyyHub/sell_fries_lobby_map.json"',1)
    local fn,err=loadstring(source)
    if not fn then
        state.FullCaptureStatus="Exporter syntax error"
        log("CaptureError",tostring(err))
        return
    end
    local success,installer=pcall(fn)
    if not success or type(installer)~="function" then
        state.FullCaptureStatus="Exporter module invalid"
        log("CaptureError",tostring(installer))
        return
    end
    local installed,why=pcall(installer,{player=player,state=state,window=window,notify=notify,log=log,on=on})
    if not installed then
        state.FullCaptureStatus="Could not install exporter"
        log("CaptureError",tostring(why))
        return
    end
    -- The lobby does not have the main game's Remotes/Controllers. Export early.
    task.delay(1.3,function()
        if state.Running and type(state.CaptureFull)=="function"then
            state.CaptureFull()
        end
    end)
end
createCapture()
local showing=true
on(close.Activated,function()
    showing=false;gui.Enabled=false
end)
on(UIS.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        showing=not showing
        gui.Enabled=showing
    end
end)
function state.Unload()
    if not state.Running then return end
    state.Running=false
    if type(state.CaptureUnload)=="function" then pcall(state.CaptureUnload)end
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    gui:Destroy()
    if env.BeyyFriesHub==state then env.BeyyFriesHub=nil end
end
notify("BeyyHub",queued and "Lobby capture on; teleport continuation queued" or
    "Lobby capture on; rerun loader after joining a match")
return state
