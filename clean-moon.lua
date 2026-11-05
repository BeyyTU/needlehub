-- BeyyHub Clean the Moon v1.0.0 | native game mapper
-- Target is exactly the Moon place from the user's URL, not another game with a similar name.
if not game:IsLoaded() then game.Loaded:Wait() end
local TARGET_PLACE=77902310012360
local env=type(getgenv)=="function" and getgenv() or _G
local continuity=tonumber(env.BeyyMoonContinuationUniverse)==game.GameId and game.GameId~=0
if game.PlaceId~=TARGET_PLACE and not continuity then
    warn("[BeyyHub Moon] This loader targets Roblox place 77902310012360. Current place: "..tostring(game.PlaceId))
    return
end
local Players=game:GetService("Players")
local localPlayer=Players.LocalPlayer
if not localPlayer then warn("[BeyyHub Moon] LocalPlayer missing");return end
local pGui=localPlayer:WaitForChild("PlayerGui",15)
if not pGui then warn("[BeyyHub Moon] PlayerGui missing");return end
if type(env.BeyyMoonHub)=="table" and type(env.BeyyMoonHub.Unload)=="function" then
    pcall(env.BeyyMoonHub.Unload)
end
local Http=game:GetService("HttpService")
for _,parent in ipairs({pGui,game:GetService("CoreGui")}) do
    pcall(function()
        for _,child in ipairs(parent:GetChildren())do
            if child:IsA("ScreenGui") and child.Name=="BeyyMoonNativeHub" then child:Destroy() end
        end
    end)
end

local function createNativeUI()
    local UI = {}
    local input = game:GetService("UserInputService")
    local run = game:GetService("RunService")
    local http = game:GetService("HttpService")
    local colors = {bg=Color3.fromRGB(20,22,27), row=Color3.fromRGB(32,35,42), text=Color3.fromRGB(231,234,240), accent=Color3.fromRGB(58,104,153)}
    local function node(class, parent, props)
        local obj = Instance.new(class)
        for k,v in pairs(props or {}) do obj[k]=v end
        obj.Parent=parent
        return obj
    end
    local function label(parent, text, height)
        return node("TextLabel", parent, {Size=UDim2.new(1,0,0,height or 24), BackgroundTransparency=1, Text=tostring(text or ""), TextColor3=colors.text, TextSize=14, Font=Enum.Font.SourceSans, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left})
    end
    local function button(parent,text,size,pos)
        return node("TextButton",parent,{Size=size or UDim2.new(1,0,0,28),Position=pos or UDim2.new(),BackgroundColor3=colors.row,BorderSizePixel=0,AutoButtonColor=false,Text=tostring(text or ""),TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans})
    end
    local function layout(parent)
        node("UIListLayout",parent,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        node("UIPadding",parent,{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
    end
    local function configManager(folder)
        local manager={Path="CleanMoonHub/config/"}
        function manager:CreateConfig(name)
            assert(type(name)=="string"and name~=""and not name:find("[/\\]"),"Invalid config name")
            local cfg={Path=self.Path..name..".json",Elements={},Order={},CustomData={},Version=1.3}
            function cfg:Register(key,el)
                if not self.Elements[key]then table.insert(self.Order,key)end
                self.Elements[key]=el
            end
            function cfg:Read()
                if type(readfile)~="function"then return nil,"Config loading requires readfile"end
                local ok,data=pcall(function()return http:JSONDecode(readfile(self.Path))end)

                if not ok or type(data)~="table"or type(data.__elements)~="table"then return nil,"No readable saved config"end
                return data
            end
            function cfg:Save()
                local ok,result=pcall(function()
                    assert(type(writefile)=="function"and type(readfile)=="function","Config saving requires writefile/readfile")
                    for _,path in ipairs({"CleanMoonHub",manager.Path})do
                        if not isfolder(path)then makefolder(path)end
                    end
                    local saved={__version=self.Version,__elements={},__custom=self.CustomData}
                    for key,el in pairs(self.Elements)do
                        local value=el.__type=="Slider"and el.Value.Default or el.Value
                        saved.__elements[key]={__type=el.__type,value=value}
                    end
                    local encoded=http:JSONEncode(saved)
                    writefile(self.Path,encoded)
                    assert(readfile(self.Path)==encoded,"Saved config read-back did not match")
                    return saved
                end)
                if not ok then return false,tostring(result)end
                return result
            end
            function cfg:Load(startup,skipAutomation)
                local data,err=self:Read()
                if not data then return false,err end
                local auto=data.__elements.AutoLoadConfig
                if startup and auto and auto.value==false then return false,"Auto-load disabled"end
                -- Parameters and continuation settings precede automation toggles.
                local automation={} -- Diagnostics-only; no automatic farming toggles
                for pass=1,2 do
                    for _,key in ipairs(self.Order)do
                        if (automation[key]==true)==(pass==2)and not(skipAutomation and automation[key])then
                            local el,entry=self.Elements[key],data.__elements[key]
                            if type(entry)=="table"and entry.__type==el.__type then
                                local value=entry.value
                                local valid=(el.__type=="Toggle"and type(value)=="boolean")or(el.__type=="Slider"and type(value)=="number"and value==value and math.abs(value)<math.huge)or(el.__type=="Keybind"and type(value)=="string"and Enum.KeyCode[value]~=nil)
                                if valid then el:Set(value)end
                            end
                        end
                    end
                end
                self.CustomData=type(data.__custom)=="table"and data.__custom or {}
                return self.CustomData
            end
            return cfg
        end
        return manager
    end

    function UI:Notify(options)
        if self.Window and not self.Window.Destroyed then self.Window.Notice.Text=tostring(options.Title or "Beyy")..": "..tostring(options.Content or "") end
    end
    function UI:CreateWindow(options)
        local w={Closed=false,Destroyed=false,Connections={},Tabs={},ToggleKey=Enum.KeyCode.RightControl}
        self.Window=w
        local parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        if type(gethui)=="function" then local ok,value=pcall(gethui); if ok and value then parent=value end end
        local gui=node("ScreenGui",parent,{Name="BeyyMoonNativeHub",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
        w.Gui=gui
        local root=node("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(640,480),BackgroundColor3=colors.bg,BorderSizePixel=0})
        node("UISizeConstraint",root,{MaxSize=Vector2.new(640,480),MinSize=Vector2.new(320,240)})
        -- UIScale keeps the fixed panel inside small screens, without layout animation.
        local scale=node("UIScale",root,{Scale=1})
        local function fit()
            local viewport=gui.AbsoluteSize
            scale.Scale=math.min(1,math.max(.1,(viewport.X-12)/640),math.max(.1,(viewport.Y-12)/480))
        end
        local function connect(signal,fn) local c=signal:Connect(fn); table.insert(w.Connections,c); return c end
        connect(gui:GetPropertyChangedSignal("AbsoluteSize"),fit); fit()
        local title=label(root,options.Title or "Beyy Hub",30); title.Position=UDim2.fromOffset(10,0); title.Size=UDim2.new(1,-48,0,30)
        title.Active=true
        local dragInput,dragX,dragY,dragPosition
        connect(title.InputBegan,function(event)
            if w.Closed or dragInput then return end
            if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
                dragInput=event; dragX=event.Position.X; dragY=event.Position.Y; dragPosition=root.Position
            end
        end)
        connect(input.InputChanged,function(event)
            if not dragInput or w.Closed then return end
            local mouse=dragInput.UserInputType==Enum.UserInputType.MouseButton1
            if (mouse and event.UserInputType~=Enum.UserInputType.MouseMovement) or (not mouse and event~=dragInput) then return end
            local viewport=gui.AbsoluteSize
            local halfWidth,halfHeight=320*scale.Scale,240*scale.Scale
            local x=dragPosition.X.Scale*viewport.X+dragPosition.X.Offset+event.Position.X-dragX
            local y=dragPosition.Y.Scale*viewport.Y+dragPosition.Y.Offset+event.Position.Y-dragY
            x=math.clamp(x,halfWidth,math.max(halfWidth,viewport.X-halfWidth))
            y=math.clamp(y,halfHeight,math.max(halfHeight,viewport.Y-halfHeight))
            root.Position=UDim2.new(dragPosition.X.Scale,x-dragPosition.X.Scale*viewport.X,dragPosition.Y.Scale,y-dragPosition.Y.Scale*viewport.Y)
        end)
        connect(input.InputEnded,function(event)
            if event==dragInput or (dragInput and dragInput.UserInputType==Enum.UserInputType.MouseButton1 and event.UserInputType==Enum.UserInputType.MouseButton1) then dragInput=nil end
        end)
        local close=button(root,"X",UDim2.fromOffset(28,24),UDim2.new(1,-34,0,3))
        local sidebar=node("ScrollingFrame",root,{Position=UDim2.fromOffset(0,34),Size=UDim2.new(0,180,1,-72),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
        layout(sidebar)
        w.Notice=label(root,"",32); w.Notice.Position=UDim2.new(0,10,1,-34); w.Notice.Size=UDim2.new(1,-20,0,32)
        local bind="CleanMoonNativeCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
        local previousBehavior,previousIcon,cursorBound
        local function releaseCursor()
            if cursorBound then return end
            previousBehavior,previousIcon=input.MouseBehavior,input.MouseIconEnabled
            cursorBound=true
            run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+100,function()
                input.MouseBehavior=Enum.MouseBehavior.Default; input.MouseIconEnabled=true
            end)
        end
        local function restoreCursor()
            if not cursorBound then return end
            run:UnbindFromRenderStep(bind); cursorBound=false
            input.MouseBehavior=previousBehavior; input.MouseIconEnabled=previousIcon
        end
        function w:Open() if self.Destroyed then return end; self.Closed=false; gui.Enabled=true; releaseCursor() end
        function w:Close() self.Closed=true; gui.Enabled=false; self.Capture=nil; dragInput=nil; restoreCursor() end
        function w:SetToggleKey(key) self.ToggleKey=typeof(key)=="EnumItem" and key or Enum.KeyCode[tostring(key)] or Enum.KeyCode.RightControl end
        function w:EditOpenButton() end
        function w:Destroy()
            if self.Destroyed then return end
            self:Close(); self.Destroyed=true
            for _,c in ipairs(self.Connections) do c:Disconnect() end
            table.clear(self.Connections); gui:Destroy()
        end
        connect(close.Activated,function() w:Close() end)
        connect(input.InputBegan,function(event,processed)
            if w.Capture and event.UserInputType==Enum.UserInputType.Keyboard and event.KeyCode~=Enum.KeyCode.Unknown then
                local capture=w.Capture; w.Capture=nil; capture:Set(event.KeyCode.Name); return
            end
            if not processed and not input:GetFocusedTextBox() and event.KeyCode==w.ToggleKey then if w.Closed then w:Open() else w:Close() end end
        end)
        w.ConfigManager=configManager(options.Folder or "CleanMoonHub")
        function w:Tab(opts)
            local tab={Window=self}
            local nav=button(sidebar,opts.Title)
            local page=node("ScrollingFrame",root,{Position=UDim2.fromOffset(184,34),Size=UDim2.new(1,-190,1,-72),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false})
            layout(page)
            tab.Page=page; tab.Nav=nav; table.insert(self.Tabs,tab)
            function tab:Select() for _,other in ipairs(w.Tabs) do other.Page.Visible=other==self; other.Nav.BackgroundColor3=other==self and colors.accent or colors.row end end
            connect(nav.Activated,function() tab:Select() end)
            if #self.Tabs==1 then tab:Select() end
            local function row(opts,height)
                local frame=node("Frame",page,{Size=UDim2.new(1,-2,0,height or 42),BackgroundColor3=colors.row,BorderSizePixel=0})
                local heading=label(frame,opts.Title,24); heading.Position=UDim2.fromOffset(8,2); heading.Size=UDim2.new(1,-160,0,24)
                return frame
            end
            local function control(kind,opts,value)
                local el={__type=kind,Value=value}
                function el:Callback(v)
                    if opts.Callback then local ok,err=pcall(opts.Callback,v); if not ok then UI:Notify({Title="Control error",Content=tostring(err)}) end end
                end
                return el
            end
            function tab:Section(opts) return label(page,opts.Title,26) end
            function tab:CollapsibleGroup(opts)
                local title=tostring(opts.Title or "Settings")
                local expanded=opts.Opened==true
                local trigger=button(page,"",UDim2.new(1,-2,0,30))
                local body=node("Frame",page,{
                    Size=UDim2.new(1,-2,0,0),
                    AutomaticSize=Enum.AutomaticSize.Y,
                    BackgroundTransparency=1,Visible=expanded
                })
                layout(body)
                local function redraw()
                    trigger.Text=(expanded and "▼ " or "▶ ")..title
                    body.Visible=expanded
                end
                connect(trigger.Activated,function()
                    expanded=not expanded
                    redraw()
                end)
                redraw()
                local group={}
                for _,kind in ipairs({"Section","Paragraph","Button","Toggle","Slider","Input","Keybind","Dropdown"}) do
                    group[kind]=function(_,options)
                        local existing={}
                        for _,child in ipairs(page:GetChildren()) do existing[child]=true end
                        local element=tab[kind](tab,options)
                        for _,child in ipairs(page:GetChildren()) do
                            if not existing[child] and child:IsA("GuiObject") then
                                child.Parent=body
                            end
                        end
                        return element
                    end
                end
                return group
            end

            function tab:Paragraph(opts)
                -- Static help paragraphs are omitted; live status panels remain.
                local live=opts.Title=="Session" or tostring(opts.Title):find("Status",1,true)~=nil
                if not live and opts.Title~="Configs unavailable" then
                    return {SetDesc=function() end,SetTitle=function() end}
                end
                local frame=node("Frame",page,{Size=UDim2.new(1,-2,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
                layout(frame)
                local heading=label(frame,opts.Title); heading.AutomaticSize=Enum.AutomaticSize.Y
                local desc=label(frame,live and opts.Desc or ""); desc.AutomaticSize=Enum.AutomaticSize.Y
                local el={}
                function el:SetDesc(v) desc.Text=tostring(v or "") end
                function el:SetTitle(v) heading.Text=tostring(v or "") end
                return el
            end
            function tab:Button(opts)
                local b=button(page,opts.Title)
                connect(b.Activated,function() if opts.Callback then local ok,err=pcall(opts.Callback); if not ok then UI:Notify({Title="Action error",Content=tostring(err)}) end end end)
                return b
            end
            function tab:Toggle(opts)
                local el=control("Toggle",opts,opts.Value==true)
                local frame=row(opts); local b=button(frame,"",UDim2.fromOffset(100,28),UDim2.new(1,-108,0,5))
                local function redraw() b.Text=el.Value and "ON" or "OFF"; b.BackgroundColor3=el.Value and colors.accent or colors.bg end
                function el:Set(v) self.Value=v==true; redraw(); self:Callback(self.Value) end
                connect(b.Activated,function() el:Set(not el.Value) end); redraw(); return el
            end
            function tab:Slider(opts)
                local spec=opts.Value or {}
                local el=control("Slider",opts,{Min=spec.Min or 0,Max=spec.Max or 100,Default=spec.Default or 0})
                local step=tonumber(opts.Step) or 1
                local fraction=tostring(step):match("%.(%d+)")
                local decimals=math.min(6,fraction and #fraction or 0)
                local function displayNumber(value)
                    local shown=string.format("%."..decimals.."f",value)
                    if decimals>0 then
                        shown=shown:gsub("0+$","")
                        shown=shown:gsub("%.$","")
                    end
                    return shown
                end
                local frame=row(opts)
                local field=node("TextBox",frame,{
                    Size=UDim2.fromOffset(64,28),Position=UDim2.new(1,-100,0,5),
                    Text=displayNumber(el.Value.Default),BackgroundColor3=colors.bg,
                    TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans,
                    ClearTextOnFocus=false
                })
                function el:Set(v)
                    local n=tonumber(v)
                    if not n or n~=n or n==math.huge or n==-math.huge then
                        field.Text=displayNumber(self.Value.Default)
                        return
                    end
                    if step>0 then n=self.Value.Min+math.round((n-self.Value.Min)/step)*step end
                    n=math.clamp(n,self.Value.Min,self.Value.Max)
                    local shown=displayNumber(n)
                    self.Value.Default=tonumber(shown) or n
                    field.Text=shown
                    self:Callback(self.Value.Default)
                end
                local minus=button(frame,"-",UDim2.fromOffset(26,28),UDim2.new(1,-130,0,5))
                local plus=button(frame,"+",UDim2.fromOffset(26,28),UDim2.new(1,-32,0,5))
                connect(minus.Activated,function() el:Set(el.Value.Default-step) end)
                connect(plus.Activated,function() el:Set(el.Value.Default+step) end)
                connect(field.FocusLost,function() el:Set(field.Text) end)
                return el
            end
            function tab:Input(opts)
                local el=control("Input",opts,tostring(opts.Value or "")); local frame=row(opts,70)
                local field=node("TextBox",frame,{Position=UDim2.fromOffset(8,32),Size=UDim2.new(1,-16,0,28),Text=el.Value,PlaceholderText=opts.Placeholder or "",BackgroundColor3=colors.bg,TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans,ClearTextOnFocus=false})
                function el:Set(v) self.Value=tostring(v or ""); field.Text=self.Value; self:Callback(self.Value) end
                connect(field.FocusLost,function() el:Set(field.Text) end); return el
            end
            function tab:Keybind(opts)
                local initial=opts.Value or "RightControl"; if typeof(initial)=="EnumItem" then initial=initial.Name end
                local el=control("Keybind",opts,initial); local frame=row(opts)
                local b=button(frame,initial,UDim2.fromOffset(140,28),UDim2.new(1,-148,0,5))
                function el:Set(v) self.Value=typeof(v)=="EnumItem" and v.Name or tostring(v); b.Text=self.Value; self:Callback(self.Value) end
                connect(b.Activated,function() w.Capture=el; b.Text="Press a key" end); return el
            end
            function tab:Dropdown(opts)
                local el=control("Dropdown",opts,opts.Value or (opts.Multi and {} or ""))
                local frame=row(opts); local b=button(frame,"",UDim2.fromOffset(140,28),UDim2.new(1,-148,0,5))
                local choices=node("ScrollingFrame",page,{Size=UDim2.new(1,-2,0,160),Visible=false,BackgroundColor3=colors.bg,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y}); layout(choices)
                local choiceButtons={}; local choiceConnections={}
                local function selected(value) if type(el.Value)~="table" then return el.Value==value end; for k,v in pairs(el.Value) do if v==value or (k==value and v==true) then return true end end; return false end
                local function redraw()
                    local values={}; if type(el.Value)=="table" then for k,v in pairs(el.Value) do table.insert(values,tostring(v==true and k or v)) end else table.insert(values,tostring(el.Value)) end
                    b.Text=#values>0 and table.concat(values,", ") or "Choose"
                    for value,cb in pairs(choiceButtons) do cb.Text=(selected(value) and "[x] " or "[ ] ")..tostring(value) end
                end
                function el:Select(v) self.Value=opts.Multi and (type(v)=="table" and table.clone(v) or {v}) or v; redraw(); self:Callback(self.Value) end
                el.Set=el.Select
                function el:Refresh(values)
                    for _,c in ipairs(choiceConnections) do
                        c:Disconnect()
                        local index=table.find(w.Connections,c)
                        if index then table.remove(w.Connections,index) end
                    end
                    table.clear(choiceConnections)
                    for _,cb in pairs(choiceButtons) do cb:Destroy() end; table.clear(choiceButtons)
                    for _,value in ipairs(values or {}) do
                        local cb=button(choices,tostring(value)); choiceButtons[value]=cb
                        local c=cb.Activated:Connect(function()
                            if opts.Multi then
                                local nextValues={}; for _,candidate in ipairs(values) do if (candidate==value and not selected(candidate)) or (candidate~=value and selected(candidate)) then table.insert(nextValues,candidate) end end
                                el:Select(nextValues)
                            else el:Select(value); choices.Visible=false end
                        end)
                        table.insert(choiceConnections,c); table.insert(w.Connections,c)
                    end
                    redraw()
                end
                connect(b.Activated,function() choices.Visible=not choices.Visible end); el:Refresh(opts.Values); return el
            end
            return tab
        end
        function w:Section(opts)
            label(sidebar,opts.Title,24)
            local group={}; function group:Tab(tabOpts) return w:Tab(tabOpts) end
            return group
        end
        w:Open()
        return w
    end
    return UI
end



local version="1.0.0"
local state={
    Running=true,Version=version,Started=os.clock(),Logs={},
    CaptureStatus="Waiting for export module",ModuleReady=false,
    CurrentPlaceId=game.PlaceId,CurrentUniverseId=game.GameId,
    TeleportQueued=false,LastResult="Not started"
}
env.BeyyMoonHub=state
local function log(kind,detail)
    local event={At=math.round((os.clock()-state.Started)*10)/10,
        Kind=tostring(kind or ""),Detail=tostring(detail or ""):sub(1,240)}
    state.Logs[#state.Logs+1]=event
    if #state.Logs>80 then table.remove(state.Logs,1) end
    print("[BeyyHub Moon] "..event.Kind.." "..event.Detail)
end
local UI=createNativeUI()
local window=UI:CreateWindow({Title="BeyyHub | Clean the Moon!  v"..version,Folder="CleanMoonHub"})
window:SetToggleKey(Enum.KeyCode.RightControl)
local function notify(title,msg)
    if window and window.Notice then window.Notice.Text=tostring(title)..": "..tostring(msg):sub(1,185) end
end
local function exportPaths()
    return "CleanMoonHub/clean_moon_game_map.json\nCleanMoonHub/clean_moon_diagnostics.json"
end
local function queueTeleport()
    local q=queue_on_teleport
    if type(q)~="function" then q=queueonteleport end
    if type(q)~="function" and type(syn)=="table" then q=syn.queue_on_teleport end
    if type(q)~="function" and type(fluxus)=="table" then q=fluxus.queue_on_teleport end
    if type(q)~="function" and type(env.queue_on_teleport)=="function" then q=env.queue_on_teleport end
    if type(q)~="function" then
        state.TeleportQueued=false
        return false,"Teleport queue API unavailable; rerun the loadstring after teleporting"
    end
    local loader='loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/clean-the-moon/loader-clean-moon.lua?refresh=" .. tostring(os.time())))()'
    if game.GameId==0 then return false,"Game universe ID unavailable; rerun after teleporting" end
    local code='local e=type(getgenv)=="function" and getgenv() or _G; e.BeyyMoonContinuationUniverse='..tostring(game.GameId).."\n"..loader
    local ok,err=pcall(q,code)
    state.TeleportQueued=ok
    return ok,ok and "Auto-reload queued for this experience" or tostring(err)
end
local function installCapture()
    state.CaptureStatus="Fetching clean moon capture module"
    local url="https://raw.githubusercontent.com/BeyyTU/needlehub/clean-the-moon/clean-moon-capture.lua"
    local fetched,source=pcall(function()
        return game:HttpGet(url.."?refresh="..tostring(os.time()))
    end)
    if not fetched or type(source)~="string" or #source<15000
        or not source:find("return function(context)",1,true) then
        state.CaptureStatus="Unable to download capture module"
        log("CaptureError",tostring(source):sub(1,220))
        return
    end
    local loaded,compileErr=loadstring(source)
    if not loaded then
        state.CaptureStatus="Capture module compile error"
        log("CaptureError",tostring(compileErr))
        return
    end
    local valid,factory=pcall(loaded)
    if not valid or type(factory)~="function" then
        state.CaptureStatus="Invalid capture module"
        log("CaptureError",tostring(factory))
        return
    end
    local installed,err=pcall(factory,{
        player=localPlayer,state=state,notify=notify,log=log
    })
    if not installed then
        state.CaptureStatus="Capture module setup failed"
        log("CaptureError",tostring(err))
        return
    end
    state.ModuleReady=true
    state.CaptureStatus="Auto scan scheduled"
    log("Ready","Client-only inspection module installed")
end
local function captureNow(tag)
    if not state.ModuleReady or type(state.CaptureNow)~="function" then
        notify("Capture",state.CaptureStatus);return
    end
    state.CaptureNow(tag or "Manual")
end
local home=window:Tab({Title="Overview"})
home:Section({Title="Clean the Moon | Game inspection"})
local summary=home:Paragraph({Title="Session",Desc="Initializing..."})
home:Button({Title="Export full game map now",Callback=function()captureNow("Manual")end})
home:Button({Title="Export again after 15 seconds",Callback=function()
    notify("Capture","Second snapshot scheduled in 15 seconds of game time")
    task.delay(15,function()
        if state.Running then captureNow("Delayed") end
    end)
end})
home:Button({Title="Show export location",Callback=function()notify("Files",exportPaths())end})
local captures=window:Tab({Title="Game Capture"})
captures:Section({Title="All client-visible game metadata"})
local captureInfo=captures:Paragraph({Title="Capture Status",Desc="Starting..."})
captures:Button({Title="Capture remotes, scripts, UI, tools & world",Callback=function()captureNow("FullManual")end})
captures:Button({Title="Capture after performing a sell or upgrade",Callback=function()
    notify("Capture","Perform one action within 15 seconds; then a new snapshot will run")
    task.delay(15,function()if state.Running then captureNow("AfterAction")end end)
end})
captures:Button({Title="Copy diagnostic file paths",Callback=function()
    if type(setclipboard)=="function" then
        local ok=pcall(setclipboard,exportPaths())
        notify("Capture",ok and "Copied Potassium file paths" or exportPaths())
    else notify("Capture",exportPaths())end
end})
local sessions=window:Tab({Title="Session Tools"})
sessions:Section({Title="Teleport and debugging"})
local sessionText=sessions:Paragraph({Title="Session",Desc="Starting..."})
sessions:Button({Title="Queue BeyyHub after teleport",Callback=function()
    local ok,msg=queueTeleport()
    log("Teleport",msg)
    notify("Teleport",msg)
end})
sessions:Button({Title="Report current capture status",Callback=function()
    local status=state.CaptureStatus
    if type(state.CaptureReport)=="function" then status=status.." | "..state.CaptureReport() end
    notify("Capture",status)
end})
sessions:Button({Title="Unload BeyyHub",Callback=function()
    if type(state.Unload)=="function" then state.Unload()end
end})
function state.Unload()
    if not state.Running then return end
    state.Running=false
    if type(state.StopCapture)=="function" then pcall(state.StopCapture)end
    pcall(function()window:Destroy()end)
    if env.BeyyMoonHub==state then env.BeyyMoonHub=nil end
    print("[BeyyHub Moon] Unloaded.")
end
installCapture()
local qOK,qMSG=queueTeleport()
log("Teleport",qMSG)
task.spawn(function()
    while state.Running do
        local summaryText=type(state.CaptureReport)=="function" and state.CaptureReport() or "Waiting for exporter"
        local session=table.concat({
            "Place: "..tostring(game.PlaceId),
            "Universe: "..tostring(game.GameId),
            "Capture: "..tostring(state.CaptureStatus),
            "Result: "..summaryText,
            "Teleport queued: "..tostring(state.TeleportQueued),
            "RightControl: show/hide BeyyHub"
        },"\n")
        if summary then summary:SetDesc(session) end
        if captureInfo then captureInfo:SetDesc("Status: "..tostring(state.CaptureStatus)
            .."\nFull export: CleanMoonHub/clean_moon_game_map.json"
            .."\nCompact: CleanMoonHub/clean_moon_diagnostics.json"
            .."\nThe map is merged by Roblox place ID. No server-only code is included.")end
        if sessionText then sessionText:SetDesc("Game: "..tostring(game.Name)
            .."\nPlace ID: "..tostring(game.PlaceId)
            .."\nAuto continuation: "..tostring(state.TeleportQueued)
            .."\nThe scanner runs automatically after initial loading.")end
        task.wait(0.75)
    end
end)
notify("BeyyHub",state.ModuleReady and "Moon mapper ready; automatic scan will save JSON" or state.CaptureStatus)
return state
