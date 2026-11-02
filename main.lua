-- Beyy Geode Hub | Crack the Geode! | native menu and range-limited pickup
if not game:IsLoaded()then game.Loaded:Wait()end
if game.GameId~=10770110947 then warn("[Geode Hub] This script is for Crack the Geode!");return end
local env=getgenv()
-- Claim startup before module initialization can yield. The shared instance also
-- covers queued chunks whose executor globals are isolated from one another.
local geodeVersion="1.10.9"
local geodePlayer=game:GetService("Players").LocalPlayer
if not geodePlayer then error("Local player unavailable")end
local geodeGui=geodePlayer:WaitForChild("PlayerGui",15)
assert(geodeGui,"PlayerGui did not load")
local boot=geodeGui:FindFirstChild("GeodeHubSession")
if boot and boot:GetAttribute("JobId")==game.JobId then
    if boot:GetAttribute("Stage")=="Ready"and boot:GetAttribute("Version")==geodeVersion then
        return env.GeodeHub or {Running=true,Reused=true}
    end
    if boot:GetAttribute("Stage")=="Starting"and os.clock()-(boot:GetAttribute("StartedAt")or 0)<60 then
        return {Pending=true}
    end
    local stop=boot:FindFirstChild("Unload")
    if stop and stop:IsA("BindableFunction")then pcall(function()stop:Invoke()end)end
end
if boot then boot:Destroy()end
if env.GeodeHub and type(env.GeodeHub.Unload)=="function"then pcall(env.GeodeHub.Unload)end
boot=Instance.new("Folder")
boot.Name="GeodeHubSession"
boot:SetAttribute("JobId",game.JobId)
boot:SetAttribute("Version",geodeVersion)
boot:SetAttribute("Stage","Starting")
boot:SetAttribute("StartedAt",os.clock())
boot.Parent=geodeGui
local stop=Instance.new("BindableFunction")
stop.Name="Unload"
stop.Parent=boot
-- Retire menus from releases predating the shared session marker. Invoke only
-- our own Unload Hub control so its workers and event connections stop as well.
local function retireGeodeMenus(keep)
local parents={geodeGui}
if type(gethui)=="function"then local ok,p=pcall(gethui);if ok and p then table.insert(parents,p)end end
pcall(function()table.insert(parents,game:GetService("CoreGui"))end)
local seen={}
for _,parent in ipairs(parents)do
    if not seen[parent]then
        seen[parent]=true
        for _,gui in ipairs(parent:GetChildren())do
            if gui~=keep and gui.Name=="GeodeNativeHub"and gui:IsA("ScreenGui")then
                if type(getconnections)=="function"and debug and type(debug.getupvalues)=="function"then
                    for _,button in ipairs(gui:GetDescendants())do
                        if button:IsA("TextButton")and button.Text=="Unload Hub"then
                            pcall(function()
                                for _,connection in ipairs(getconnections(button.Activated))do
                                    if type(connection.Function)=="function"then
                                        for _,value in pairs(debug.getupvalues(connection.Function))do
                                            if type(value)=="table"and value.Title=="Unload Hub"and type(value.Callback)=="function"then pcall(value.Callback)end
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end
                gui:Destroy()
            end
        end
    end
end
end
retireGeodeMenus(nil)
local function releaseGeodeBoot()
    if boot.Parent then boot:Destroy()end
end

local success,result=pcall(function()
local geodeScripts=geodePlayer:WaitForChild("PlayerScripts",15)
assert(geodeScripts and geodeScripts:WaitForChild("MTGClient",15),"Game client did not load")
-- Beyy native UI. Embedded into each module; no remote UI dependency.
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
        local manager={Path="WindUI/"..folder.."/config/"}
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
                    for _,path in ipairs({"WindUI","WindUI/"..folder,manager.Path})do
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
                local automation={AutoGeodePickup=true,AutoOpenHauntedEgg=true,AutoCrackAndSell=true,AutoUpgradeMagnet=true,AutoEscape=true,AutoEndless=true,AutoSelectPerk=true}
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
        local gui=node("ScreenGui",parent,{Name="GeodeNativeHub",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
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
        local bind="GeodeNativeCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
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
        w.ConfigManager=configManager(options.Folder or "GeodeHub")
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

local Pickup=(function()
-- Crack the Geode! Standalone range-limited pickup. No movement, camera writes, purchases or teleport queue.
local Players=game:GetService("Players")
local World=game:GetService("Workspace")
local Storage=game:GetService("ReplicatedStorage")
local H=game:GetService("HttpService")
local player=Players.LocalPlayer
local client=player and player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("MTGClient")
local mtg=Storage:FindFirstChild("MTG")
if not client or not mtg then warn("[Geode Pickup] Game modules are not available yet.");return end
local State=require(client.State)
local Render=require(client.MoundRender)
local HUD=require(client.RunHUD)
local Tools=require(client.Tools)
local Stats=require(mtg.Modules.Stats)
local Game=require(mtg.Config.Game)
local remote=mtg.Remotes:FindFirstChild("Pick")
if not remote then warn("[Geode Pickup] Pick remote unavailable.");return end
local env=getgenv()
if env.GeodeAutoPickup and type(env.GeodeAutoPickup.Unload)=="function"then env.GeodeAutoPickup.Unload()end
local api={Running=true,Enabled=false,EarlyIntroEnabled=true,EarlyIntroStatus="Not attempted",EarlyAttempts=0,EarlyConfirmed=0,MinRange=0,MaxRange=math.min(26,Game.Collect.Reach),Requests=0,Feedback=0,Items=0}
env.GeodeAutoPickup=api
local events,connections={},{}
local startedAt=os.clock()
local lastPhaseSignature
local nextSend=0;local pending;local avoided={};local dirty=false;local deadline
local earlySession,earlyStage="","idle"
local earlySentAt=0
local introProvider
local function earlyStatus(value)
    if api.EarlyIntroStatus~=value then
        api.EarlyIntroStatus=value
        log("EarlyPickupStatus",{Status=value,Session=tostring(earlySession)})
    end
end
local status="Paused"
local screen,statusLabel,toggle,rangeBox
local function log(kind,data)
    events[#events+1]={Kind=kind,At=os.clock(),WallTimeMs=DateTime.now().UnixTimestampMillis,Data=data}
    if #events>160 then table.remove(events,1)end
    dirty=true
    if kind~="BagChanged"then print("[Geode Pickup] "..kind.." "..H:JSONEncode(data or{}))end
end
local function setStatus(text)status=text;api.Status=text;if statusLabel then statusLabel.Text=text end end
local function snapshot()
    local state=mtg:FindFirstChild("State")
    local okRole,moduleRole=pcall(State.role)
    local okPhase,modulePhase=pcall(function()return State.run("Phase")end)
    local okLocked,moduleLocked=pcall(function()return State.run("MoundLocked",false)end)
    local okTool,tool=pcall(HUD.equipped)
    local lockedValue=okLocked and moduleLocked or nil
    if okLocked and moduleLocked==false then lockedValue=false end
    if not okLocked then lockedValue="unavailable" end
    return {
        SecondsSinceLoad=math.floor((os.clock()-startedAt)*10+.5)/10,
        ModuleRole=okRole and tostring(moduleRole)or "unavailable",
        ReplicatedRole=mtg:GetAttribute("Role")or "nil",
        ModulePhase=okPhase and tostring(modulePhase)or "unavailable",
        ReplicatedPhase=state and tostring(state:GetAttribute("Phase"))or "State missing",
        MoundLocked=lockedValue,
        StateExists=state~=nil,
        MoundFolderExists=Render.Folder~=nil and Render.Folder.Parent~=nil,
        EquippedTool=okTool and tostring(tool)or "unavailable",
        PickupSuspended=api.Suspended==true,
        NativeHeldOwner=api.NativeHeldOwner~=nil,
        PlayerBagCount=player:GetAttribute("BagCount"),
    }
end
local function logTransition()
    local info=snapshot()
    local signature=table.concat({
        tostring(info.ModuleRole),tostring(info.ReplicatedRole),tostring(info.ModulePhase),
        tostring(info.ReplicatedPhase),tostring(info.MoundLocked),tostring(info.StateExists),
        tostring(info.MoundFolderExists)
    },"|")
    if signature~=lastPhaseSignature then
        lastPhaseSignature=signature
        log("ReadinessChanged",info)
    end
end
function api.SetIntroProvider(fn)
    introProvider=type(fn)=="function" and fn or nil
end
function api.SetEarlyIntro(value)
    api.EarlyIntroEnabled=value==true
    if not api.EarlyIntroEnabled then earlyStatus("Disabled")end
end
function api.SetRange(minimum,maximum)
    minimum=tonumber(minimum);maximum=tonumber(maximum)
    if not minimum or not maximum or minimum~=minimum or maximum~=maximum then return false end
    local cap=math.min(26,Game.Collect.Reach)
    if minimum<0 or maximum>cap or minimum>maximum then return false end
    api.MinRange=minimum;api.MaxRange=maximum
    if rangeBox then rangeBox.Text=tostring(maximum)end
    log("RangeChanged",{Min=minimum,Max=maximum});return true
end
function api.Start(seconds)
    api.Enabled=true;deadline=seconds and(os.clock()+math.max(0,seconds))or nil
    if toggle then toggle.Text="Pause pickup"end
    log("Started",{Min=api.MinRange,Max=api.MaxRange,Duration=seconds});setStatus("Looking for nearby targets")
end
function api.Stop()
    api.Enabled=false;deadline=nil
    if toggle then toggle.Text="Start pickup"end
    log("Paused",{Requests=api.Requests,Feedback=api.Feedback,Items=api.Items});setStatus("Paused")
end
function api.Export()
    local report={Version=1,PlaceId=game.PlaceId,GameId=game.GameId,JobId=game.JobId,Enabled=api.Enabled,
        Range={Min=api.MinRange,Max=api.MaxRange},Requests=api.Requests,Feedback=api.Feedback,Items=api.Items,
        BagCount=player:GetAttribute("BagCount"),Status=status,Events=events,
        EarlyIntroEnabled=api.EarlyIntroEnabled,EarlyIntroStatus=api.EarlyIntroStatus,
        EarlyAttempts=api.EarlyAttempts,EarlyConfirmed=api.EarlyConfirmed,EarlySession=tostring(earlySession),EventsNote="Early pickup is limited to one initial server-checked request per intro. Native phase is never modified.",
        SnapshotAtMs=DateTime.now().UnixTimestampMillis,Readiness=snapshot(),
        Note="Pick feedback identifies the player and item count, not a unique request. Manual clicks can also contribute. Initial export may be from Lobby before Mining; later exports include current readiness and transitions."}
    local ok,err=pcall(function()
        if not isfolder("Geode")then makefolder("Geode")end
        writefile("Geode/auto_pickup_diagnostics.json",H:JSONEncode(report))
    end)
    if ok then dirty=false end
    return ok,err
end
function api.Unload()
    if not api.Running then return end
    api.Stop();api.Running=false
    for _,c in ipairs(connections)do c:Disconnect()end
    if screen then screen:Destroy()end
    api.Export()
end
local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include;overlap.MaxParts=512
local rays=RaycastParams.new();rays.FilterType=Enum.RaycastFilterType.Include
local function targetFor(root)
    local folder=Render.Folder
    if not folder or not folder.Parent then return end
    overlap.FilterDescendantsInstances={folder};rays.FilterDescendantsInstances={folder}
    local candidates={}
    for _,part in ipairs(World:GetPartBoundsInRadius(root.Position,api.MaxRange,overlap))do
        if part.Transparency<1 and part.CanQuery then
            local col,id=Render.target(part)
            if col~=nil and id~=nil then
                local distance=(part.Position-root.Position).Magnitude
                if distance<=api.MaxRange then candidates[#candidates+1]={Part=part,Distance=distance}end
            end
        end
    end
    table.sort(candidates,function(a,b)return a.Distance<b.Distance end)
    local now=os.clock()
    for i=1,math.min(32,#candidates)do
        local direction=candidates[i].Part.Position-root.Position
        if direction.Magnitude>0.001 then
            local hit=World:Raycast(root.Position,direction*1.05,rays)
            if hit then
                local col,id=Render.target(hit.Instance)
                local distance=(hit.Position-root.Position).Magnitude
                local key=col~=nil and id~=nil and(tostring(col)..":"..tostring(id))
                if key and distance>=api.MinRange and distance<=api.MaxRange
                    and(not avoided[key]or avoided[key]<now)then
                    return {Col=col,Id=id,Position=hit.Position,Distance=distance,Key=key}
                end
            end
        end
    end
end
connections[#connections+1]=remote.OnClientEvent:Connect(function(userId,tool,packed,gems)
    if userId~=player.UserId then return end
    local count=typeof(packed)=="buffer"and math.floor(buffer.len(packed)/5)or 0
    -- Pets use the same remote; their collections must not confirm our tool request.
    if not pending or tool~=pending.Tool then
        if api.Enabled and not api.NativeHeldOwner then log("OtherPickupFeedback",{Tool=tool,Items=count})end
        return
    end
    api.Feedback+=1;api.Items+=count
    local wasEarly=pending.Early==true
    log("ServerPickupFeedback",{Tool=tool,Items=count,Gems=gems,SinceRequestMs=pending and(os.clock()-pending.At)*1000,
        BagCount=player:GetAttribute("BagCount"),Target=pending and pending.Target.Key,Early=wasEarly})
    if wasEarly and earlyStage=="pending"then
        if count>0 then
            local before=tonumber(pending.BagBefore)or 0
            -- Remote feedback can also arrive from native tool fire. Confirm
            -- actual bag progress while the game still reports Waiting.
            task.delay(.15,function()
                if not api.Running or earlyStage~="pending"then return end
                local after=tonumber(player:GetAttribute("BagCount"))or 0
                if after>before and State.role()=="Game"and State.run("Phase")=="Waiting"then
                    earlyStage="confirmed";api.EarlyConfirmed+=1
                    earlyStatus("Bag increased during Waiting — early pickup permitted")
                else
                    earlyStage="blocked"
                    earlyStatus("Early pickup unproven; waiting for normal Mining")
                end
            end)
        else
            earlyStage="blocked";earlyStatus("Early pickup had zero items — waiting for Mining")
        end
    elseif wasEarly and count==0 and earlyStage=="confirmed"then
        earlyStage="blocked";earlyStatus("Early pickup stopped after zero-item reply")
    end
    if count>0 or wasEarly then pending=nil end
end)
connections[#connections+1]=player:GetAttributeChangedSignal("BagCount"):Connect(function()
    if not api.NativeHeldOwner then log("BagChanged",{Count=player:GetAttribute("BagCount")})end
end)
task.spawn(function()
    local nextSave=0
    while api.Running and env.GeodeAutoPickup==api do
        local now=os.clock()
        local tryingEarly=false
        local traceOK,traceErr=pcall(logTransition)
        if not traceOK then setStatus("Readiness diagnostic error: "..tostring(traceErr))end
        if deadline and now>=deadline then api.Stop()end
        local ok,err=pcall(function()
            if pending and now-pending.At>(pending.Early and .8 or 1.5)then
                avoided[pending.Target.Key]=now+1
                if pending.Early and earlyStage=="pending" then
                    earlyStage="blocked"
                    earlyStatus("No early pickup response — waiting for Mining")
                end
                log("NoConfirmation",{Target=pending.Target.Key,WaitMs=(now-pending.At)*1000,Early=pending.Early==true})
                pending=nil
            end
            if not api.Enabled then return end
            if api.NativeHeldOwner then setStatus("Auto Endless: native held fire");return end
            if api.Suspended then setStatus("Auto Crack and Sell is active");return end
            local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health<=0 then setStatus("Waiting for character");return end
            local role=State.role()
            local phase=State.run("Phase")
            local moundLocked=State.run("MoundLocked",false)
            local currentRun=State.run("RunStart")
            local session=tostring(currentRun or "not-started").."|"..tostring(player.Character)
            if session~=earlySession or role~="Game"then
                earlySession=session
                earlyStage="idle"
                if role=="Game"then earlyStatus("Armed for current intro")end
            end
            local regular=role=="Game"and phase=="Mining"and not moundLocked
            local introActive=false
            if introProvider then
                local providerOK,allowed=pcall(introProvider)
                introActive=providerOK and allowed==true
            end
            local earlyWindow=not regular and api.EarlyIntroEnabled and introActive
                and role=="Game"and phase=="Waiting"and not moundLocked
            tryingEarly=earlyWindow
            if not regular then
                if not earlyWindow then
                    setStatus("Waiting for mining phase (role="..tostring(role)..", phase="..tostring(phase)..", locked="..tostring(moundLocked)..")")
                    return
                end
                if earlyStage=="blocked" then
                    setStatus("Early pickup not confirmed — waiting for normal Mining")
                    return
                end
                if earlyStage=="pending" then
                    setStatus("Testing early geode pickup — awaiting server response")
                    return
                end
            end
            local cap=State.get("BagCap",0);local count=State.get("BagCount",0)
            if cap>=0 and count>=cap then setStatus("Bag full — deposit geodes");return end
            if pending or now<nextSend then return end
            local tool=HUD.equipped()
            if not tool or not State.set("Tools")[tool]then setStatus("Equip an owned mining tool");return end
            local stats=Stats.tool(State.ctx(),tool)
            local cooldown=math.max(0.05,stats.Cooldown*Tools.paceMult(tool))
            local target=targetFor(root)
            if not target then
                setStatus(earlyWindow and "Hidden intro: waiting for target geometry"or("No targets within "..api.MaxRange.." studs"))
                nextSend=now+0.2;return
            end
            local origin=Render.origin()
            if typeof(origin)~="Vector3"then setStatus("Waiting for mound data");return end
            local offset=target.Position-origin
            -- Native argument order is tool, column, local X, local Z, local Y, cell ID.
            nextSend=now+cooldown
            if earlyWindow and earlyStage=="idle" then
                earlyStage="pending";api.EarlyAttempts+=1;earlySentAt=now
                earlyStatus("Testing one early pickup during hidden intro")
            end
            local earlyRequest=earlyWindow
            pending={At=os.clock(),Target=target,Tool=tool,Early=earlyRequest,BagBefore=tonumber(player:GetAttribute("BagCount"))or 0}
            api.Requests+=1
            log("Request",{Tool=tool,Col=target.Col,Id=target.Id,Distance=target.Distance,Range=api.MaxRange,
                Cooldown=cooldown,BagBefore=count,Early=earlyRequest,Position={target.Position.X,target.Position.Y,target.Position.Z}})
            remote:FireServer(tool,target.Col,offset.X,offset.Z,offset.Y,target.Id)
            setStatus(earlyRequest and "Early intro pickup request sent"or("Picking up | "..string.format("%.1f",target.Distance).." studs | received "..api.Items))
        end)
        if not ok then
            log("Error",{Message=tostring(err),Early=tryingEarly})
            if tryingEarly then
                earlyStage="blocked";earlyStatus("Early mining data not ready — waiting for normal Mining")
                setStatus("Early pickup check failed; will resume automatically in Mining")
            else
                api.Stop();setStatus("Paused after error — see log")
            end
        end
        -- Refresh the on-disk status even when zero pickup requests are made.
        -- This prevents an early Lobby snapshot from appearing to be current.
        if now>=nextSave and (dirty or api.Enabled) then nextSave=now+3;api.Export()end
        task.wait(0.05)
    end
end)
log("Loaded",{Min=api.MinRange,Max=api.MaxRange,PlaceId=game.PlaceId})
api.Status="Paused"
return api

end)()
if not Pickup then return end
local function createHauntedEggController(options)
    local api={Running=true,Enabled=false,InFlight=false,Busy=false,Status="Paused",Requests=0,Opened=0,Accepted=0,BusyReplies=0}
    local nextRequest=0
    local function record(kind,data)if options.Record then pcall(options.Record,kind,data)end end
    function api.Start()
        if not api.Running then return end
        api.Enabled=true;api.Status="Checking candy and event availability"
        record("Started",{Batch=3})
    end
    function api.Stop(reason)
        api.Enabled=false;api.Status=reason or"Paused"
        record("Stopped",{Reason=api.Status})
    end
    function api.Unload()if not api.Running then return end;api.Stop();api.Running=false end
    function api.Tick()
        if not api.Running or not api.Enabled or api.InFlight or options.Now()<nextRequest then return end
        local context=options.Context()
        local price=tonumber(context.Price)
        api.Price=price and math.floor(price)*3 or nil
        api.Candy=tonumber(context.Candy)or 0
        if not context.Active then api.Stop("Halloween event is inactive");return end
        if not context.Unlocked then api.Status="Waiting for pets to unlock";return end
        if not api.Price or api.Price<=0 then api.Stop("Egg price unavailable");return end
        if context.Opening then api.Status="Waiting for the game's hatch animation";return end
        if api.Candy<api.Price then api.Status="Waiting for candy (need "..api.Price..")";return end
        local before=api.Candy
        api.InFlight=true;api.Requests+=1;api.Status="Opening 3 Haunted Eggs"
        record("Request",{Action="Open3",Egg="Haunted",CandyBefore=before,Price=api.Price})
        local started=options.Now()
        local ok,result=pcall(options.Invoke)
        api.InFlight=false
        local elapsed=(options.Now()-started)*1000
        if not ok then
            record("RequestError",{Error=tostring(result),ResponseMs=elapsed})
            api.Stop("Request failed; stopped to avoid an uncertain repeat purchase")
            return
        end
        if type(result)~="table"then api.Stop("Unexpected server response");return end
        api.Busy=result.Busy==true
        record("Response",{Result=result,ResponseMs=elapsed})
        -- The server has no separate readable Busy flag. Retry rejected Busy replies
        -- at the native client's 0.3s minimum, or the longer server-supplied Wait.
        local waitTime=tonumber(result.Wait)or 0
        if waitTime~=waitTime or waitTime==math.huge or waitTime==-math.huge then waitTime=0 end
        nextRequest=options.Now()+math.max(0.3,waitTime)
        if api.Busy then
            api.BusyReplies+=1
            if api.Enabled then api.Status="Server busy — waiting to retry"end
            return
        end
        if result.Ok~=true then api.Stop(tostring(result.Msg or"Server rejected egg opening"));return end
        local count=type(result.Results)=="table"and #result.Results or(result.Pet and 1 or 0)
        api.Accepted+=1;api.Opened+=count;api.LastResults=result.Results or{result}
        if tonumber(result.Candy)then api.Candy=tonumber(result.Candy)end
        if api.Enabled then api.Status="Opened "..count.." eggs — checking next batch"end
    end
    return api
end

local function createLiveHauntedEggs()
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local Event=require(MTG.Modules.Halloween)
    local Config=require(MTG.Config.HalloweenPets)
    local Pets=require(MTG.Config.Pets)
    local PetsUI=require(P.PlayerScripts.MTGClient.PetsUI)
    local remote=MTG.Remotes:WaitForChild("Pets")
    local events={};local dirty=false
    local api=createHauntedEggController({Now=os.clock,Context=function()
        return {Active=Event.active(),Unlocked=P:GetAttribute("UnlockPets")==true,
            Candy=P:GetAttribute("Candy"),Price=Config.Egg.Candy,Opening=PetsUI.isOpening and PetsUI.isOpening()}
    end,Invoke=function()return remote:InvokeServer("Open3","Haunted",nil)end,
    Record=function(kind,data)
        events[#events+1]={Kind=kind,WallTimeMs=DateTime.now().UnixTimestampMillis,Data=data}
        if #events>80 then table.remove(events,1)end
        dirty=true
    end})
    api.Price=math.floor(Config.Egg.Candy)*3;api.Candy=tonumber(P:GetAttribute("Candy"))or 0
    function api.Export()
        local report={Version=1,PlaceId=game.PlaceId,Enabled=api.Enabled,Requests=api.Requests,Accepted=api.Accepted,
            Opened=api.Opened,BusyReplies=api.BusyReplies,Candy=P:GetAttribute("Candy"),Batch=3,Price=api.Price,Status=api.Status,Events=events}
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/haunted_egg_diagnostics.json",H:JSONEncode(report))
        end)
        if ok then dirty=false end
        return ok,err
    end
    function api.ResultText()
        local names={}
        for _,r in ipairs(api.LastResults or{})do
            local def=Pets.ById[tostring(r.Pet)]
            names[#names+1]=def and def.Name or tostring(r.Pet)
        end
        return #names>0 and table.concat(names,", ")or"No eggs opened this session"
    end
    local unload=api.Unload
    function api.Unload()unload();api.Export()end
    task.spawn(function()
        local nextSave=0
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Stop("Hatch loop error: "..tostring(err))end
            if dirty and os.clock()>=nextSave then nextSave=os.clock()+2;api.Export()end
            task.wait(.05)
        end
    end)
    return api
end

local Eggs=createLiveHauntedEggs()
local function createClassMutationController(options)
    local api={Running=true,Enabled=false,Busy=false,Class=options.DefaultClass or"Rookie",ScrollType="Normal",Target="Glitched",Limit=10,
        Requests=0,Accepted=0,SessionRequests=0,Status="Paused",LastRolled="—"}
    local session;local nextRequest=0
    function api.SetClass(value)if type(value)=="string"then api.Class=value end end
    function api.SetScrollType(value)if value=="Normal"or value=="Lucky"then api.ScrollType=value end end
    function api.SetTarget(value)if options.Tier(value)>0 then api.Target=value end end
    function api.SetLimit(value)
        value=tonumber(value)
        if value and value==value then api.Limit=math.floor(math.clamp(value,1,1000))end
    end
    function api.Stop(reason)api.Enabled=false;api.Status=reason or"Paused"end
    function api.Start()
        if not api.Running or api.Enabled then return end
        if api.Busy then api.Status="Waiting for previous roll response";return end
        session={Class=api.Class,ScrollType=api.ScrollType,Target=api.Target,Limit=api.Limit}
        api.SessionRequests=0;api.Enabled=true;nextRequest=0;api.Status="Checking class and scrolls"
    end
    function api.Unload()api.Stop();api.Running=false end
    function api.Tick()
        if not api.Running or not api.Enabled or api.Busy or options.Now()<nextRequest then return end
        local c=options.Context(session.Class,session.ScrollType)
        if not c.Owned then api.Stop("Selected class is not owned");return end
        if options.Tier(c.Mutation)>=options.Tier(session.Target)then api.Stop("Target reached: "..tostring(c.Mutation));return end
        if api.SessionRequests>=session.Limit then api.Stop("Roll limit reached");return end
        if c.Scrolls<1 then api.Stop("No "..session.ScrollType.." Scrolls remaining");return end
        api.Busy=true;api.Requests+=1;api.SessionRequests+=1
        api.Status="Rolling "..session.Class.." ("..api.SessionRequests.."/"..session.Limit..")"
        nextRequest=options.Now()+math.max(.12,options.RollRate or .12)
        local ok,result=pcall(options.Roll,session.Class,session.ScrollType)
        api.Busy=false
        if not ok or type(result)~="table"or result.Ok~=true then
            api.Stop("Roll stopped: "..tostring(ok and type(result)=="table"and result.Msg or result));return
        end
        api.Accepted+=1;api.LastRolled=tostring(result.Rolled or"Unknown");api.LastMutation=result.Mut
        if not api.Running or not api.Enabled then return end
        if options.Tier(result.Mut)>=options.Tier(session.Target)then api.Stop("Target reached: "..tostring(result.Mut))
        elseif api.SessionRequests>=session.Limit then api.Stop("Roll limit reached")
        else api.Status="Rolled "..api.LastRolled.." — kept "..tostring(result.Mut)end
    end
    return api
end

local function createLiveClassMutations()
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local M=game:GetService("ReplicatedStorage").MTG
    local config=require(M.Config.Mutations)
    local function decode(name)
        local ok,value=pcall(H.JSONDecode,H,P:GetAttribute(name)or"{}")
        return ok and type(value)=="table"and value or{}
    end
    local function tier(id)local def=config.ById[id];return def and def.Tier or 0 end
    local api=createClassMutationController({DefaultClass=P:GetAttribute("Class")or"Rookie",Now=os.clock,Tier=tier,RollRate=config.RollRate,
        Context=function(class,scroll)
            local owned=class=="Rookie"or class==P:GetAttribute("Class")
                or(","..tostring(P:GetAttribute("Classes"))..","):find(","..class..",",1,true)~=nil
            return {Owned=owned,Mutation=decode("ClassMuts")[class],Scrolls=tonumber(decode("Scrolls")[scroll=="Lucky"and"L"or"N"])or 0}
        end,Roll=function(class,scroll)return M.Remotes.Mutations:InvokeServer("Roll","Class",class,scroll)end})
    function api.ClassOptions()
        local set={Rookie=true};local values={}
        for class in tostring(P:GetAttribute("Classes")or""):gmatch("[^,]+")do set[class]=true end
        set[P:GetAttribute("Class")or"Rookie"]=true
        for class in pairs(set)do values[#values+1]=class end;table.sort(values);return values
    end
    function api.TargetOptions()local values={};for _,def in ipairs(config.List)do values[#values+1]=def.Id end;return values end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Busy=false;api.Stop("Mutation error: "..tostring(err))end
            task.wait(.05)
        end
    end)
    return api
end

local ClassMutations=createLiveClassMutations()
local function createCrackSellController(options)
    local api={Running=true,Enabled=false,Busy=false,Stage="Idle",Status="Paused",Interval=1,Continuous=false,RepeatInterval=10,Cycles=0,Sales=0,CashGained=0,OneShotCompleted=false}
    local armedAt;local lastBag;local observedIdentity
    local deadline=0;local readyAt=0;local identity;local cracked=false;local sold=false;local saleBefore=0
    local function record(kind,data)if options.Record then pcall(options.Record,kind,data)end end
    local function stage(name,status,timeout)
        api.Stage=name;api.Status=status;deadline=options.Now()+(timeout or 4)
        record("Stage",{Stage=name,Status=status})
    end
    local function finish(reason)
        if api.Busy then
            local ok,err=pcall(options.Finish)
            if not ok then record("CleanupError",{Error=tostring(err)})end
        end
        api.Busy=false;identity=nil;api.Stage="Idle";api.Status=reason or"Waiting for more geodes"
        armedAt=nil
    end
    function api.Start()
        if not api.Running or api.Enabled then return end
        local c=options.Context();lastBag=c.BagCount;observedIdentity=c.Identity
        api.OneShotCompleted=false -- An explicit restart arms one new sale cycle.
        api.Enabled=true;api.PendingStopReason=nil;armedAt=nil;api.Status="Waiting for first bag count change"
    end
    function api.BagChanged(value)
        value=tonumber(value)or 0
        local changed=lastBag~=nil and lastBag~=value
        lastBag=value
        if api.Running and api.Enabled and not api.Busy and changed and not armedAt then
            armedAt=options.Now()
            record("CollectionWindowStarted",{BagCount=value,WaitSeconds=api.Interval})
        end
    end
    function api.Stop(reason)
        api.Enabled=false;api.PendingStopReason=nil;finish(reason or"Paused")
        record("Stopped",{Reason=api.Status})
    end
    function api.Unload()if not api.Running then return end;api.Stop();api.Running=false end
    function api.SetInterval(value)
        value=tonumber(value)
        if value and value==value then api.Interval=math.clamp(value,1,60)end
    end
    function api.SetContinuous(value)
        api.Continuous=value==true
        if api.Continuous then api.PendingStopReason=nil end
        if not api.Busy then armedAt=nil end
    end
    function api.RequestStopAfterSale(reason)
        if not api.Enabled or api.Continuous or api.PendingStopReason then return end
        api.PendingStopReason=reason or"Final sale completed"
        -- Finish any remaining bag/crate/bin even when pickups have stopped.
        if not api.Busy and not armedAt then armedAt=options.Now()end
        record("StopAfterSaleRequested",{Reason=api.PendingStopReason})
    end
    function api.SetRepeatInterval(value)
        value=tonumber(value)
        if value and value==value then api.RepeatInterval=math.clamp(value,1,60)end
    end
    function api.Notify(kind)
        if not api.Busy then return end
        if kind=="CrackAll"and api.Stage=="CrackWait"then cracked=true
        elseif kind=="Sold"and api.Stage=="SellWait"then sold=true end
    end
    local function hasBin(c)return c.BinCount>0 or c.BinValue>0 end
    local function approach(target)
        local ok,reason,alreadyNear=options.MoveTo(target)
        if not ok then api.Stop(reason or("Could not approach "..target));return false end
        stage(target.."Approach","Approaching "..target:lower(),4)
        readyAt=options.Now()+(alreadyNear and 0 or .15)
        return true
    end
    local function proceed(c)
        if c.CrateCount>0 and c.CanCrack then
            approach("Station")
        elseif hasBin(c)then approach("Sell")
        elseif c.CrateCount>0 then api.Stop("Crack All pass or credits required")
        else finish("Nothing left to crack or sell")end
    end
    local function completed(c)
        api.Cycles+=1
        record("CycleComplete",{Cycles=api.Cycles,Cash=c.Cash})
        local stopReason=not api.Continuous and api.PendingStopReason
        finish("Cycle complete — returned to pickup position")
        if stopReason then api.Stop(stopReason)
        elseif not api.Continuous then
            -- One trip per activation. Pickups after returning cannot silently
            -- start another two-second countdown until re-enabled manually.
            api.OneShotCompleted=true
            api.Enabled=false
            api.Status="Single Crack & Sell cycle completed — toggle on for another"
            record("OneShotComplete",{Cycles=api.Cycles,Sales=api.Sales})
        end
    end
    function api.Tick()
        if not api.Running or not api.Enabled then return end
        local c=options.Context()
        if not c.Valid then
            if api.Busy then api.Stop("Cycle stopped: character or mining phase changed")else api.Status="Waiting for a mining run"end
            armedAt=nil;lastBag=c.BagCount
            return
        end
        if api.Busy and c.Identity~=identity then api.Stop("Cycle stopped: character or camp changed");return end
        if observedIdentity~=c.Identity then armedAt=nil;lastBag=c.BagCount;observedIdentity=c.Identity end
        api.BagChanged(c.BagCount)
        local now=options.Now()
        if api.Stage=="Idle"then
            if api.PendingStopReason and c.BagCount<=0 and c.CrateCount<=0 and not hasBin(c)then
                api.Stop(api.PendingStopReason);return
            end
            if(api.Continuous or api.PendingStopReason)and not armedAt then armedAt=now end
            if not armedAt then api.Status="Waiting for first bag count change";return end
            local interval=api.Continuous and api.RepeatInterval or api.Interval
            if now<armedAt+interval then
                api.Status=string.format("Collecting — camp visit in %.1fs",armedAt+interval-now)
                return
            end
            if c.Cracking then api.Status="Waiting for your manual station session to end";return end
            if c.BagCount<=0 and c.CrateCount<=0 and not hasBin(c)then armedAt=nil;api.Status="Waiting for geodes";return end
            if(c.BagCount>0 or c.CrateCount>0)and not c.CanCrack and not hasBin(c)then api.Status="Crack All pass or credits required";return end
            if(c.BagCount>0 or c.CrateCount>0)and not c.FreeStation then api.Status="Waiting for a free station";return end
            api.Busy=true;identity=c.Identity
            local ok,reason=options.Begin()
            if not ok then api.Stop(reason or"Could not start cycle");return end
            record("CycleBegin",{Bag=c.BagCount,Crate=c.CrateCount,Bin=c.BinCount,Cash=c.Cash})
            if c.BagCount>0 then approach("Deposit")else proceed(c)end
            return
        end
        if now>=deadline then api.Stop("Timed out during "..api.Stage);return end
        if api.Stage=="DepositApproach"and now>=readyAt then
            if c.BagCount<=0 then proceed(c);return end
            options.Deposit();stage("DepositWait","Waiting for deposit confirmation",4)
        elseif api.Stage=="DepositWait"then
            if c.BagCount<=0 then proceed(c)end
        elseif api.Stage=="StationApproach"and now>=readyAt then
            if not c.CanCrack then api.Stop("Crack All pass or credits required");return end
            if c.CrateCount<=0 then if hasBin(c)then approach("Sell")else completed(c)end;return end
            options.Enter();stage("EnterWait","Waiting for station entry",4)
        elseif api.Stage=="EnterWait"then
            if c.Cracking and c.StationOurs then
                if not c.CanCrack then api.Stop("Crack All entitlement changed");return end
                cracked=false;stage("CrackWait","Waiting for Crack All confirmation",8)
                options.Crack()
            end
        elseif api.Stage=="CrackWait"then
            if cracked or c.CrateCount<=0 then
                stage("LeaveWait","Leaving station",3);options.Leave()
            end
        elseif api.Stage=="LeaveWait"then
            if not c.Cracking then
                if hasBin(c)then approach("Sell")else completed(c)end
            end
        elseif api.Stage=="SellApproach"and now>=readyAt then
            if not hasBin(c)then completed(c);return end
            saleBefore=c.Cash;sold=false;stage("SellWait","Waiting for sale confirmation",4)
            options.Sell()
        elseif api.Stage=="SellWait"then
            if sold or not hasBin(c)then
                stage("SaleSettle","Confirming sale balance",2);readyAt=now+0.2
            end
        elseif api.Stage=="SaleSettle"and(c.Cash>saleBefore or now>=readyAt)then
            api.Sales+=1;api.CashGained+=math.max(0,c.Cash-saleBefore)
            completed(c)
        end
    end
    return api
end

local function createLiveCrackSell(Pickup)
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local Bench=require(P.PlayerScripts.MTGClient.Bench)
    local remote=MTG.Remotes:WaitForChild("Bench")
    local camp,character,identity,station,entry,deposit,sell
    local savedPose,savedCharacter,savedCamp;local enteredByUs=false;local events={};local dirty=false;local generation=0
    local function root()return P.Character and P.Character:FindFirstChild("HumanoidRootPart")end
    local function refresh()
        local map=workspace:FindFirstChild("CaveMap")
        local current=map and map:FindFirstChild("Camp")
        if current~=camp or character~=P.Character then
            camp=current;character=P.Character;identity={}
            deposit=camp and camp:FindFirstChild("MTG_Deposit",true)
            sell=camp and camp:FindFirstChild("MTG_Sell",true)
        end
    end
    local function chooseStation()
        local stations=camp and camp:FindFirstChild("Stations")
        if not stations then return end
        for _,name in ipairs({"Station2","Station3","Station1","Station4"})do
            local s=stations:FindFirstChild(name);local prompt=s and s:FindFirstChild("MTG_Crack",true)
            if prompt and prompt.Enabled and(s:GetAttribute("Occupant")or 0)==0 then return s,prompt end
        end
    end
    local function canCrack()
        for pass in tostring(P:GetAttribute("Passes")or""):gmatch("[^,]+")do if pass=="CrackAll"then return true end end
        return(tonumber(P:GetAttribute("CrackAllCredits"))or 0)>0
    end
    local function valid()
        local state=MTG:FindFirstChild("State")
        local hum=P.Character and P.Character:FindFirstChildOfClass("Humanoid")
        return camp~=nil and root()~=nil and hum~=nil and hum.Health>0 and MTG:GetAttribute("Role")=="Game"
            and state~=nil and state:GetAttribute("Phase")=="Mining"
    end
    local function ownsStation()
        return station and station.Parent and station:GetAttribute("Occupant")==P.UserId
    end
    local function leave()
        if enteredByUs and ownsStation()and Bench.isCracking()then Bench._ui.doLeave()end
        enteredByUs=false
    end
    local function finish()
        local pendingEntry=enteredByUs and not Bench.isCracking()
        local pendingStation=station
        local pendingGeneration=generation
        local leaveOK,leaveError=pcall(leave)
        Pickup.Suspended=false
        -- An already-triggered station prompt may be acknowledged after Stop/Unload.
        if pendingEntry then task.spawn(function()
            local untilAt=os.clock()+4
            repeat
                if generation~=pendingGeneration then return end
                if pendingStation and pendingStation.Parent and pendingStation:GetAttribute("Occupant")==P.UserId and Bench.isCracking()then
                    Bench._ui.doLeave();return
                end
                task.wait(.05)
            until os.clock()>=untilAt
        end)end
        refresh()
        local r=root()
        local poseToRestore=savedPose and savedCharacter==P.Character and savedCamp==camp and valid()and r and savedPose
        savedPose=nil;savedCharacter=nil;savedCamp=nil
        if poseToRestore and leaveOK then r.CFrame=poseToRestore;r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero end
        if not leaveOK then error(leaveError)end
    end
    local function near(prompt,point)
        return prompt and prompt.Parent and prompt.Parent:IsA("BasePart")
            and(point-prompt.Parent.Position).Magnitude<=math.max(0,prompt.MaxActivationDistance-1)
    end
    local function moveTo(target)
        local r=root();if not r then return false,"Character unavailable"end
        local prompt=target=="Deposit"and deposit or(target=="Sell"and sell or entry)
        if target=="Station"and(not station or not station.Parent or(station:GetAttribute("Occupant")or 0)~=0)then
            station,entry=chooseStation();prompt=entry
        end
        if not prompt or not prompt.Parent or not prompt.Enabled then return false,target.." interaction unavailable"end
        if near(prompt,r.Position)then return true,nil,true end
        local combined=entry and entry.Parent.Position+Vector3.new(-3.6,1.5,6)
        local point=combined and near(prompt,combined)and combined or prompt.Parent.Position+Vector3.new(-4,1.5,0)
        r.CFrame=CFrame.new(point)*r.CFrame.Rotation
        r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
        return true
    end
    local function trigger(prompt)
        if type(fireproximityprompt)~="function"then error("Executor prompt support unavailable")end
        local r=root()
        if not r or not prompt or not prompt.Enabled or not near(prompt,r.Position)then error("Interaction is disabled or out of range")end
        fireproximityprompt(prompt)
    end
    local api=createCrackSellController({Now=os.clock,Context=function()
        refresh()
        local free=chooseStation()
        return {Valid=valid(),Identity=identity,BagCount=tonumber(P:GetAttribute("BagCount"))or 0,
            CrateCount=camp and(tonumber(camp:GetAttribute("CrateCount"))or 0)or 0,
            BinCount=camp and(tonumber(camp:GetAttribute("BinCount"))or 0)or 0,
            BinValue=camp and(tonumber(camp:GetAttribute("BinValue"))or 0)or 0,
            Cash=tonumber(P:GetAttribute("Cash"))or 0,CanCrack=canCrack(),FreeStation=free~=nil,
            Cracking=Bench.isCracking(),StationOurs=ownsStation()and true or false}
    end,Begin=function()
        if type(fireproximityprompt)~="function"then return false,"Executor prompt support unavailable"end
        refresh();local r=root();if not r then return false,"Character unavailable"end
        generation+=1
        station,entry=chooseStation()
        savedPose=r.CFrame;savedCharacter=P.Character;savedCamp=camp;enteredByUs=false
        Pickup.Suspended=true
        return true
    end,MoveTo=moveTo,Deposit=function()trigger(deposit)end,Enter=function()enteredByUs=true;trigger(entry)end,
    Crack=function()remote:FireServer("CrackAll")end,Leave=leave,Sell=function()trigger(sell)end,Finish=finish,
    Record=function(kind,data)
        events[#events+1]={Kind=kind,WallTimeMs=DateTime.now().UnixTimestampMillis,Data=data}
        if #events>100 then table.remove(events,1)end
        dirty=true
    end})
    local connection=remote.OnClientEvent:Connect(function(data)
        if type(data)~="table"or not api.Busy then return end
        api.Notify(data.Type)
        local row={Type=data.Type};for k,v in pairs(data)do if type(v)=="number"or type(v)=="boolean"or type(v)=="string"then row[k]=v end end
        events[#events+1]={Kind="ServerEvent",WallTimeMs=DateTime.now().UnixTimestampMillis,Data=row}
        if #events>100 then table.remove(events,1)end;dirty=true
    end)
    local bagConnection=P:GetAttributeChangedSignal("BagCount"):Connect(function()
        api.BagChanged(P:GetAttribute("BagCount"))
    end)
    function api.Export()
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_crack_sell_diagnostics.json",H:JSONEncode({Version=1,Enabled=api.Enabled,Stage=api.Stage,
                Status=api.Status,Cycles=api.Cycles,Sales=api.Sales,CashGained=api.CashGained,Interval=api.Interval,Continuous=api.Continuous,RepeatInterval=api.RepeatInterval,OneShotCompleted=api.OneShotCompleted,PendingStopReason=api.PendingStopReason,Events=events}))
        end)
        if ok then dirty=false end
        return ok,err
    end
    local unload=api.Unload
    function api.Unload()if not api.Running then return end;unload();connection:Disconnect();bagConnection:Disconnect();api.Export()end
    task.spawn(function()
        local nextSave=0
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Stop("Cycle error: "..tostring(err))end
            if dirty and os.clock()>=nextSave then nextSave=os.clock()+2;api.Export()end
            task.wait(api.Busy and .03 or .1)
        end
    end)
    return api
end

local CrackSell=createLiveCrackSell(Pickup)
local function createMagnetUpgradeController(options)
    local ids={"MagPower","MagSpeed"};local cursor=1;local pending;local nextRequest=0
    local api={Running=true,Enabled=false,InFlight=false,Status="Paused",Confirmed=0}
    function api.IsMaxed()
        local context=options.Context()
        if not context.Owned then return false end
        for _,id in ipairs(ids)do
            local def=context.Tracks[id]
            if not def or type(def.Max)~="number"or def.Max<=0 or(context.Levels[id]or 0)<def.Max then return false end
        end
        return true
    end
    local function record(kind,data)if options.Record then pcall(options.Record,kind,data)end end
    function api.Start()if not api.Running then return end;api.Enabled=true;api.Status="Checking GEO-MAG upgrades"end
    function api.Stop(reason)api.Enabled=false;api.Status=reason or"Paused";record("Stopped",{Reason=api.Status})end
    function api.Unload()if not api.Running then return end;api.Stop();api.Running=false end
    function api.Tick()
        if not api.Running or not api.Enabled or api.InFlight then return end
        local now=options.Now();local context=options.Context()
        if pending then
            if(context.Levels[pending.Id]or 0)>=pending.Level then
                api.Confirmed+=1;record("Confirmed",pending);cursor=pending.NextCursor;pending=nil
            elseif now>=pending.Deadline then api.Stop("Upgrade confirmation timed out");return
            else api.Status="Waiting for "..pending.Id.." confirmation";return end
        end
        if now<nextRequest then return end
        if not context.Allowed then api.Status="Waiting for mining and the camp cycle to finish";return end
        if not context.Owned then api.Status="Waiting for GEO-MAG 3000 ownership";return end
        local selected,maxed=nil,0
        for offset=0,1 do
            local id=ids[(cursor-1+offset)%2+1];local def=context.Tracks[id];local level=context.Levels[id]or 0
            if def and level>=def.Max then maxed+=1
            elseif def and def.Cost and def.Cost<=context.Cash and not selected then selected={Id=id,Level=level+1,Cost=def.Cost,NextCursor=((cursor-1+offset)%2+1)%2+1}end
        end
        if maxed==2 then api.Status="Both GEO-MAG upgrades are maxed";return end
        if not selected then api.Status="Waiting for enough cash";return end
        api.InFlight=true;record("Request",selected)
        local ok,result=pcall(options.Invoke,selected.Id)
        api.InFlight=false;nextRequest=options.Now()+0.15
        if not ok then record("Error",{Error=tostring(result)});api.Stop("Purchase request failed; check upgrade state before retrying");return end
        record("Response",{Id=selected.Id,Result=result})
        if type(result)~="table"then api.Stop("Unexpected upgrade response");return end
        if result.Ok then
            pending={Id=selected.Id,Level=tonumber(result.Level)or selected.Level,Cost=selected.Cost,NextCursor=selected.NextCursor,Deadline=options.Now()+3}
            api.Status="Waiting for "..selected.Id.." confirmation"
        elseif result.Busy or result.Msg=="Not enough cash"then
            nextRequest=options.Now()+math.max(1,tonumber(result.Wait)or 0);api.Status=tostring(result.Msg or"Shop busy")
        else api.Stop(tostring(result.Msg or"Upgrade rejected"))end
    end
    return api
end

local function createLiveMagnetUpgrades(CrackSell)
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local State=require(P.PlayerScripts.MTGClient.State)
    local Upgrades=require(MTG.Config.Upgrades)
    local Mode=require(MTG.Modules.Mode)
    local remote=MTG.Remotes:WaitForChild("Shop")
    local events={};local dirty=false
    local api=createMagnetUpgradeController({Now=os.clock,Context=function()
        local levels=State.ctx().Upg
        local tracks={}
        for _,id in ipairs({"MagPower","MagSpeed"})do
            local def=Upgrades.ById[id];local cost=def.Costs[(levels[id]or 0)+1]
            tracks[id]={Max=#def.Costs,Cost=cost and Mode.price(cost)}
        end
        return {Allowed=State.role()=="Game"and State.run("Phase")=="Mining"and not CrackSell.Busy,
            Owned=State.set("Tools").Magnet==true,Levels=levels,Tracks=tracks,Cash=tonumber(P:GetAttribute("Cash"))or 0}
    end,Invoke=function(id)return remote:InvokeServer("Upgrade",id)end,Record=function(kind,data)
        events[#events+1]={Kind=kind,WallTimeMs=DateTime.now().UnixTimestampMillis,Data=data}
        if #events>80 then table.remove(events,1)end;dirty=true
    end})
    function api.Export()
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/magnet_upgrade_diagnostics.json",H:JSONEncode({Version=1,Enabled=api.Enabled,Status=api.Status,
                Confirmed=api.Confirmed,Levels=State.ctx().Upg,Cash=P:GetAttribute("Cash"),Events=events}))
        end)
        if ok then dirty=false end;return ok,err
    end
    local unload=api.Unload
    function api.Unload()unload();api.Export()end
    task.spawn(function()
        local nextSave=0
        while api.Running do
            local ok,err=pcall(function()
                if CrackSell.Enabled and not CrackSell.Continuous and api.IsMaxed()then
                    CrackSell.RequestStopAfterSale("Both GEO-MAG upgrades are maxed — final collection complete")
                end
                api.Tick()
            end)
            if not ok then api.Stop("Upgrade loop error: "..tostring(err))end
            if dirty and os.clock()>=nextSave then nextSave=os.clock()+2;api.Export()end
            task.wait(.1)
        end
    end)
    return api
end

local MagnetUpgrades=createLiveMagnetUpgrades(CrackSell)
local function createEscapeController(options)
    local api={Running=true,Enabled=false,Status="Paused",Attempts=0}
    local identity;local run;local nextMove=0;local arrived=false
    function api.Start()api.Enabled=true;api.Status="Waiting for the exit to open"end
    function api.Stop()api.Enabled=false;api.Status="Paused";identity=nil;api.Attempts=0;arrived=false end
    function api.Unload()api.Stop();api.Running=false end
    function api.Tick()
        if not api.Running or not api.Enabled then return end
        local c=options.Context()
        if identity~=c.Identity or run~=c.Run then identity=c.Identity;run=c.Run;api.Attempts=0;nextMove=0;arrived=false end
        if c.Escaped then api.Status="Escape confirmed by server";return end
        if c.Ended then api.Status="Round ended";return end
        if not c.Ready then api.Status="Waiting for the exit to open";return end
        if not c.Alive then api.Status="Waiting for a living character";return end
        if arrived and c.Distance<=4 then api.Status="At exit — waiting for server confirmation";return end
        if options.Now()<nextMove then return end
        if api.Attempts>=10 then api.Status="Escape not confirmed after 10 attempts";return end
        local ok,err=pcall(options.Move)
        nextMove=options.Now()+1
        if not ok then api.Status="Exit movement failed: "..tostring(err);return end
        api.Attempts+=1;arrived=true
        api.Status="At exit — waiting for server confirmation"
    end
    return api
end

local function createLiveEscape(CrackSell)
    local player=game:GetService("Players").LocalPlayer
    local State=require(player.PlayerScripts.MTGClient.State)
    local function destination(root,humanoid)
        local map=workspace:FindFirstChild("CaveMap")
        local lift=map and map:FindFirstChild("Lift")
        local floor=lift and lift:FindFirstChild("Floor")
        local inside=lift and lift:FindFirstChild("Inside")
        local base=floor and floor:IsA("BasePart")and floor or inside
        if not base or not base:IsA("BasePart")then return nil end
        local clearance=humanoid and humanoid.HipHeight+(root and root.Size.Y/2 or 1)or 3
        return base.CFrame:PointToWorldSpace(Vector3.new(0,(base==floor and base.Size.Y/2 or 0)+clearance,0))
    end
    local api=createEscapeController({Now=os.clock,Context=function()
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local exit=destination(root,humanoid)
        return {Identity=character,Run=State.run("RunStart",""),
            Ready=exit~=nil and State.role()=="Game"and State.run("Mode","")~="Endless"and State.run("Phase","")=="Escape"and State.run("LiftOpen",false)==true,
            Escaped=player:GetAttribute("Escaped")==true,Ended=State.run("Ended",false)==true,
            Alive=root~=nil and humanoid~=nil and humanoid.Health>0,
            Distance=root and exit and(root.Position-exit).Magnitude or math.huge}
    end,Move=function()
        if CrackSell.Enabled or CrackSell.Busy then CrackSell.Stop("Stopped for auto escape")end
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        assert(root,"Character root unavailable")
        local exit=assert(destination(root,player.Character:FindFirstChildOfClass("Humanoid")),"Current map lift unavailable")
        root.CFrame=CFrame.new(exit)*root.CFrame.Rotation
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end})
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Stop();api.Status="Escape error: "..tostring(err);warn("[Geode Escape] "..tostring(err))end
            task.wait(.25)
        end
    end)
    return api
end

local Escape=createLiveEscape(CrackSell)
-- Independently enforces 3x native walking speed during live game play.
-- Baselines are captured per Humanoid and refreshed when game code changes
-- WalkSpeed; our own modified value is never multiplied a second time.
local function createGameWalkSpeedController()
    local P=game:GetService("Players").LocalPlayer
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local api={Running=true,Enabled=true,Multiplier=3,Status="Waiting for game",Base=0,Applied=0}
    local humanoid,base,desired,active
    local function restore()
        if humanoid and humanoid.Parent and active and base then
            local current=humanoid.WalkSpeed
            if math.abs(current-(desired or 0))<.1 then
                humanoid.WalkSpeed=base
            end
        end
        active=false;desired=nil
        api.Applied=0
    end
    function api.SetEnabled(value)
        api.Enabled=value==true
        if not api.Enabled then restore();api.Status="Disabled"end
    end
    function api.Unload()
        api.Running=false
        restore()
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(function()
                local character=P.Character
                local hum=character and character:FindFirstChildOfClass("Humanoid")
                if hum~=humanoid then
                    restore()
                    humanoid=hum
                    base=hum and hum.WalkSpeed or nil
                end
                local inGame=MTG:GetAttribute("Role")=="Game"
                if not api.Enabled or not inGame or not hum or hum.Health<=0 then
                    if active then restore() end
                    api.Status=not api.Enabled and "Disabled" or not inGame and "Waiting for game" or "Waiting for living character"
                    return
                end
                local current=hum.WalkSpeed
                if not active then
                    base=current
                    active=true
                elseif desired and math.abs(current-desired)>.1 then
                    -- Game changed/restored movement speed. Treat the new native
                    -- value as the baseline rather than multiplying our 3x again.
                    base=current
                end
                desired=math.max(0,base*api.Multiplier)
                api.Base=base;api.Applied=desired
                if math.abs(current-desired)>.1 then hum.WalkSpeed=desired end
                api.Status=string.format("In game: %.1f -> %.1f WalkSpeed",base,desired)
            end)
            if not ok then api.Status="WalkSpeed error: "..tostring(err)end
            task.wait(.1)
        end
    end)
    return api
end

local GameWalkSpeed=createGameWalkSpeedController()
-- Hides only the three verified chapter-intro UI layers. This does not
-- change RunStart, the server's Waiting phase, or gameplay progression.
local function createIntroVisualController()
    local P=game:GetService("Players").LocalPlayer
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local gui=P:WaitForChild("PlayerGui")
    local api={Running=true,Enabled=true,Active=false,Hidden=0,Status="Waiting for chapter load"}
    local names={"MTG_Loading","MTG_LoadingHud","MTG_Intro"}
    local originalPositions={}
    local offscreen=UDim2.fromScale(100,100)
    local roleBefore,phaseBefore,runBefore,miningAt
    local active=false
    local function restore()
        for object,position in pairs(originalPositions)do
            if object and object.Parent and object.Position==offscreen then
                pcall(function()object.Position=position end)
            end
            originalPositions[object]=nil
        end
    end
    local function hideObject(object)
        if not object or not object.Parent or not object:IsA("GuiObject") then return end
        if object.Position~=offscreen then
            -- Keep updating the saved position if the native cutscene
            -- is tweening it; do not interfere with Enabled/Visible state.
            originalPositions[object]=object.Position
            object.Position=offscreen
            api.Hidden+=1
        end
    end
    local function suppress()
        for _,name in ipairs(names)do
            local layer=gui:FindFirstChild(name)
            if layer then
                if layer:IsA("ScreenGui") then
                    for _,child in ipairs(layer:GetChildren())do hideObject(child)end
                else hideObject(layer)end
            end
        end
    end
    function api.SetEnabled(value)
        api.Enabled=value==true
        if not api.Enabled then
            if active then restore()end
            active=false;api.Active=false
            api.Status="Disabled"
        end
    end
    function api.Unload()
        api.Running=false
        if active then restore()end
        active=false;api.Active=false
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(function()
                local state=MTG:FindFirstChild("State")
                local role=MTG:GetAttribute("Role")
                local phase=state and state:GetAttribute("Phase")
                local run=state and state:GetAttribute("RunStart")
                if role~=roleBefore or (run~=nil and run~=runBefore)then
                    miningAt=nil
                end
                if phase=="Mining"and phaseBefore~="Mining"then miningAt=os.clock()end
                roleBefore,phaseBefore,runBefore=role,phase,run
                local duringIntro=role=="Game" and
                    (phase=="Waiting" or (phase=="Mining"and miningAt~=nil and os.clock()-miningAt<4))
                if api.Enabled and duringIntro then
                    active=true;api.Active=true
                    suppress()
                    api.Status="Hiding chapter visuals without disabling game UI ("..tostring(phase)..")"
                else
                    if active then restore();active=false end
                    api.Active=false
                    api.Status=not api.Enabled and "Disabled"
                        or role=="Game" and "Intro passed — normal gameplay"
                        or "Waiting for chapter load"
                end
            end)
            if not ok then api.Status="Intro suppression error: "..tostring(err)end
            task.wait(.04)
        end
    end)
    return api
end
local IntroVisuals=createIntroVisualController()
Pickup.SetIntroProvider(function()return IntroVisuals.Enabled and IntroVisuals.Active end)
local function createEndlessController(options)
    local api={Running=true,Enabled=false,BossAssist=true,Stage="Paused",Status="Paused",Hover=6.5,Laps=0,Hits=0,WeakHits=0}
    local managedRun;local managed=false;local previousPhase
    function api.Start()if api.Running then api.Enabled=true end end
    function api.Stop()
        api.Enabled=false;api.Stage="Paused";api.Status="Paused"
        options.Release()
        if managed then options.Finish()end
        managed=false;managedRun=nil;previousPhase=nil
    end
    function api.Unload()api.Stop();api.Running=false end
    function api.SetBossAssist(value)
        api.BossAssist=value==true
        if not api.BossAssist and not api.Enabled then
            options.Release();api.Stage="Paused";api.Status="Paused"
        end
    end
    function api.SetHover(value)
        value=tonumber(value)
        if value and value==value then api.Hover=math.clamp(value,2,20)end
    end
    function api.Tick()
        if not api.Running then return end
        local c=options.Context()
        local bossOnly=not api.Enabled and api.BossAssist and c.Role=="Game"
            and c.Phase=="Mother" and c.HP>0 and not c.Ended and c.Alive and c.Owned
        if not api.Enabled and not bossOnly then
            if api.Stage=="Boss" then options.Release();api.Stage="Paused";api.Status="Waiting for boss" end
            return
        end
        if bossOnly then
            -- Assist live boss encounters without enabling Endless mining,
            -- crack/sell, magnet upgrades, or other automations.
            api.Stage="Boss";api.Status="Auto boss: targeting exposed weak points"
            options.Update(api,c)
            return
        end
        if managed and(not c.Endless or c.Ended)then options.Release();options.Finish();managed=false;managedRun=nil end
        local stage,status
        if not c.Endless then stage,status="Waiting","Waiting for Endless mode"
        elseif c.Ended then stage,status="Waiting","Endless run ended"
        elseif not c.Alive then stage,status="Waiting","Waiting for a living character"
        elseif not c.Owned then stage,status="Waiting","GEO-MAG 3000 ownership required"
        else
            if not managed or managedRun~=c.Run or(c.Phase=="Mining"and previousPhase~="Mining")then options.Manage();managed=true;managedRun=c.Run end
            if c.CampBusy then stage,status="Camp","Camp cycle owns movement"
            elseif c.Phase=="Mining"then stage,status="Mining","Hovering around the mound"
            elseif c.Phase=="Mother"and c.HP>0 then stage,status="Boss","Targeting boss weak points"
            else stage,status="Waiting","Waiting for the next mining depth"end
        end
        api.Stage,api.Status=stage,status
        previousPhase=c.Phase
        if stage=="Mining"or stage=="Boss"then options.Update(api,c)else options.Release()end
    end
    return api
end

-- Fits horizontal contours to all active column stacks. No Roblox dependencies.
local function createPileRingPlanner()
    local planner={}
    function planner.Build(columns,center,options)
        options=options or {}
        local fractions=options.Fractions or{.12,.34,.56,.78,.94}
        local sectors=options.Sectors or 16
        local low,top=math.huge,-math.huge;local active={}
        for _,c in ipairs(columns)do
            if c.Count>0 and c.Top>=c.Base then
                active[#active+1]=c;low=math.min(low,c.Base);top=math.max(top,c.Top)
            end
        end
        if #active==0 then return nil end
        local bands={};local height=math.max(1,top-low)
        for index,fraction in ipairs(fractions)do
            local y=low+height*fraction;local bins={};local radii={}
            for s=1,sectors do bins[s]={}end
            for _,c in ipairs(active)do
                if c.Base<=y+1.5 and c.Top>=y-1.5 then
                    local dx,dz=c.X-center.X,c.Z-center.Z
                    local radius=math.sqrt(dx*dx+dz*dz)
                    local angle=math.atan2(dz,dx)%(math.pi*2)
                    local sector=math.floor(angle/(math.pi*2)*sectors+.5)%sectors+1
                    table.insert(bins[sector],radius);table.insert(radii,radius)
                end
            end
            if #radii==0 then continue end
            table.sort(radii)
            local overall=radii[math.max(1,math.ceil(#radii*.97))]+1.25
            local profile={}
            for s=1,sectors do
                local bin=bins[s];table.sort(bin)
                if #bin>0 then profile[s]=bin[math.max(1,math.ceil(#bin*.97))]+1.25 end
            end
            for s=1,sectors do if not profile[s]then
                -- Empty sectors retain the measured contour, never pull the axis
                -- toward a surviving cluster on one side of the mound.
                for offset=1,math.floor(sectors/2)do
                    local left=(s-1-offset)%sectors+1;local right=(s-1+offset)%sectors+1
                    if #bins[left]>0 or #bins[right]>0 then profile[s]=math.max(profile[left]or 0,profile[right]or 0);break end
                end
                profile[s]=profile[s]or overall
            end end
            local smooth={}
            for s=1,sectors do smooth[s]=math.clamp((profile[(s-2)%sectors+1]+profile[s]*2+profile[s%sectors+1])/4,3,60)end
            if options.Circular then for s=1,sectors do smooth[s]=math.clamp(overall,3,60)end end
            bands[#bands+1]={Name=({"Base","Lower slope","Middle","Upper slope","Crown"})[index]or("Ring "..index),
                Y=y,Radius=math.clamp(overall,3,60),Radii=smooth,Columns=#radii}
        end
        return {Origin={X=center.X,Y=low,Z=center.Z},Bands=bands,Columns=#active,Top=top,Bottom=low,Sectors=sectors}
    end
    function planner.RadiusAt(band,angle)
        local radii=band.Radii
        if not radii or #radii==0 then return band.Radius end
        local position=(angle%(math.pi*2))/(math.pi*2)*#radii
        local index=math.floor(position)
        local alpha=position-index
        return radii[index%#radii+1]*(1-alpha)+radii[(index+1)%#radii+1]*alpha
    end
    return planner
end

-- Owns only the native button source and an independent direct-pickup gate.
local function createNativeHeldFire(options)
    local api={Owned=false,Active=false,Starts=0,Releases=0,Recoveries=0}
    local readyAt=0
    local lastProgress;local progressAt=0
    function api.ReleaseFire()
        if not api.Active then return end
        api.Active=false;api.Releases+=1
        lastProgress=nil
        options.SetUse(false,"button")
    end
    function api.Stop()
        local ok,err=pcall(api.ReleaseFire)
        if api.Owned then api.Owned=false;options.Suppress(false)end
        if not ok then error(err)end
    end
    function api.Update(owner,allowed)
        if not owner then api.Stop();return end
        if not api.Owned then
            options.Suppress(true);api.Owned=true
            -- Let an existing direct request/feedback finish before held fire.
            readyAt=options.Now()+.2
        end
        if not allowed then api.ReleaseFire();return end
        if not api.Active and options.Now()>=readyAt then
            api.Active=true;api.Starts+=1
            progressAt=options.Now();lastProgress=options.Progress and options.Progress()
            options.SetUse(true,"button")
        elseif api.Active and options.Progress then
            local now=options.Now();local progress=options.Progress()
            if progress~=lastProgress then lastProgress=progress;progressAt=now
            elseif now-progressAt>=1.5 then
                -- Native focus/input resets can clear the game's hold while our
                -- ownership remains active. Reassert only after firing stalls,
                -- and only through the normal allowed-input guards above.
                progressAt=now;api.Recoveries+=1
                options.SetUse(true,"button")
            end
        end
    end
    return api
end

-- Native skill activation with replicated confirmation and cooldown backoff.
local function createEndlessAbilityController(options)
    local api={Requests=0,Confirmed=0,Available=false,Status="Waiting for Auto Endless"}
    local pending;local readyAt=0;local retryAt=0
    local function record(kind,data)if options.Record then options.Record(kind,data)end end
    function api.Tick(enabled)
        if not enabled and not pending then return end
        local c=options.Context();local now=options.Now()
        api.Available=c.Unlocked==true;api.Stats=c.Stats
        local buffActive=c.BuffId==c.SkillId and(c.BuffUntil or 0)>now
        if buffActive and c.Stats then
            -- Covers skills activated manually with Q, as well as our own casts.
            readyAt=math.max(readyAt,c.ReadyAt or 0,c.BuffUntil+(c.Stats.Cooldown or 45)-(c.Stats.Duration or 5))
        end
        if pending then
            if(c.ReadyAt or 0)>pending.BeforeReady+.01 or(buffActive and c.BuffUntil>pending.BeforeBuff+.01)then
                api.Confirmed+=1
                readyAt=math.max(readyAt,(c.ReadyAt or 0)>pending.At and c.ReadyAt or pending.At+pending.Cooldown)
                record("AbilityConfirmed",{Skill=c.SkillId,ReadyAt=readyAt});pending=nil
            elseif now>=pending.Deadline then
                record("AbilityUnconfirmed",{Skill=c.SkillId});pending=nil;retryAt=now+5
                api.Status="Activation unconfirmed — backing off"
            end
        end
        if not enabled then api.Status="Auto ability paused";return end
        if not c.Unlocked then api.Status="GEO-MAG ability not unlocked";return end
        if not c.Allowed then api.Status="Ability waits for active mining";return end
        if pending then api.Status="Waiting for Overcharge confirmation";return end
        if buffActive then api.Status="Overcharge active";return end
        local remaining=math.max(readyAt,c.ReadyAt or 0,retryAt)-now
        if remaining>0 then api.Status=string.format("Overcharge ready in %.1f s",remaining);return end
        pending={At=now,BeforeReady=c.ReadyAt or 0,BeforeBuff=c.BuffUntil or 0,Cooldown=c.Stats.Cooldown,Deadline=now+5}
        api.Requests+=1;record("AbilityRequested",{Skill=c.SkillId,Cooldown=c.Stats.Cooldown})
        local ok,err=pcall(options.Activate)
        if not ok then pending=nil;retryAt=now+5;api.Status="Ability error: "..tostring(err);record("AbilityError",tostring(err))
        else api.Status="Waiting for Overcharge confirmation"end
    end
    return api
end

local function createLiveEndless(Pickup,CrackSell,MagnetUpgrades)
    local P=game:GetService("Players").LocalPlayer
    local R=game:GetService("RunService")
    local H=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage").MTG
    local C=P.PlayerScripts.MTGClient
    local S=require(C.State)
    local Render=require(C.MoundRender)
    local Grid=require(MTG.Modules.Mound)
    local ringPlanner=createPileRingPlanner()
    local Tools=require(C.Tools)
    local HUD=require(C.RunHUD)
    local Bench=require(C.Bench)
    local UIKit=require(C.UIKit)
    local Mastery=require(C.Mastery)
    local MasteryHUD=require(C.MasteryHUD)
    local held;local api
    held=createNativeHeldFire({Now=os.clock,SetUse=function(value,source)Tools.setUse(value,source)end,
        Progress=function()return api and(api.NativeFireEvents+api.Hits)or 0 end,
        Suppress=function(value)
            if value then Pickup.NativeHeldOwner=held
            elseif Pickup.NativeHeldOwner==held then Pickup.NativeHeldOwner=nil end
        end})
    local target,focus,ownedCharacter,ownedHumanoid,autoRotate,cameraOutward,movementStage
    local smoothedCameraRotation
    local collision={};local savedCamera;local previous
    local plan,planDepth,profileCenter,pendingBand;local nextPlan=0;local angle=0;local band=1
    local nextEquip=0
    local events={}
    local function record(kind,data)
        events[#events+1]={Kind=kind,At=os.time(),Depth=S.run("Depth"),Data=data}
        if #events>100 then table.remove(events,1)end
    end
    local ability=createEndlessAbilityController({Now=function()return workspace:GetServerTimeNow()end,Context=function()
        local stats=Mastery.skillStats("Magnet")
        local buff,remaining=Mastery.buff()
        local now=workspace:GetServerTimeNow()
        return {Stats=stats,SkillId=stats and stats.Id,Unlocked=stats~=nil and Mastery.level("Tool:Magnet")>=Mastery.SkillLevel,
            ReadyAt=Mastery.skillReadyAt("Magnet"),BuffId=buff,BuffUntil=buff and now+remaining or 0,
            Allowed=api and api.Enabled and api.Stage=="Mining"and api.NativeHeldActive and S.role()=="Game"and S.run("Mode")=="Endless"
                and S.run("Phase")=="Mining"and S.run("MoundLocked",false)~=true and HUD.equipped()=="Magnet"
                and not CrackSell.Busy and not Bench.isCracking()and not UIKit.cursorFree()and P:GetAttribute("PerkPending")~=true
                and not Tools.Blocked and not Tools.DevPaused}
    end,Activate=function()MasteryHUD.useSkill()end,Record=record})
    local function release()
        held.ReleaseFire()
        target=nil;focus=nil
        cameraOutward=nil;movementStage=nil;smoothedCameraRotation=nil
        for part,value in pairs(collision)do if part.Parent then part.CanCollide=value end end
        collision={}
        if ownedHumanoid and ownedHumanoid.Parent then ownedHumanoid.AutoRotate=autoRotate end
        ownedCharacter=nil;ownedHumanoid=nil
        if savedCamera then
            if savedCamera.Camera==workspace.CurrentCamera then
                savedCamera.Camera.CameraType=savedCamera.Type
                savedCamera.Camera.CameraSubject=savedCamera.Subject
            end
            savedCamera=nil
        end
    end
    local function buildPlan()
        local origin=Render.origin()
        if not origin then return nil end
        if not profileCenter then
            local map=workspace:FindFirstChild("CaveMap");local mother=map and map:FindFirstChild("Mother");local body=mother and mother:FindFirstChild("Body")
            profileCenter=body and{X=body.Position.X,Z=body.Position.Z}or{X=origin.X,Z=origin.Z}
        end
        local columns={}
        for col=1,Grid.N do
            local count=Grid.Max[col]or 0
            if count>0 then columns[#columns+1]={X=origin.X+Grid.X[col],Z=origin.Z+Grid.Z[col],Base=origin.Y+Grid.Base[col],
                Top=origin.Y+Grid.topY(col,count),Count=count}end
        end
        local fitted=ringPlanner.Build(columns,profileCenter,{Fractions={.12},Circular=true})
        if fitted and #fitted.Bands>0 then return fitted end
    end
    api=createEndlessController({Context=function()
        local char=P.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
        return {Role=S.role(),Endless=S.role()=="Game"and S.run("Mode","")=="Endless",Phase=S.run("Phase"),
            Run=S.run("RunStart"),Depth=S.run("Depth"),HP=S.run("MotherHP",0),Ended=S.run("Ended",false)==true or S.run("EndlessOver",false)==true,
            Alive=hum~=nil and hum.Health>0 and char:FindFirstChild("HumanoidRootPart")~=nil,
            Owned=S.set("Tools").Magnet==true,CampBusy=CrackSell.Busy or Bench.isCracking()}
    end,Manage=function()
        if not previous then previous={Pickup=Pickup.Enabled,Upgrade=MagnetUpgrades.Enabled,Crack=CrackSell.Enabled}end
        if not Pickup.Enabled then Pickup.Start()end
        if not MagnetUpgrades.Enabled then MagnetUpgrades.Start()end
        if(CrackSell.Continuous or not MagnetUpgrades.IsMaxed())and not CrackSell.Enabled and not CrackSell.OneShotCompleted then CrackSell.Start()end
        record("RunManaged",{})
    end,Finish=function()
        if previous then
            if not previous.Crack then CrackSell.Stop("Auto Endless stopped")end
            if not previous.Upgrade then MagnetUpgrades.Stop()end
            if not previous.Pickup then Pickup.Stop()end
        end
        previous=nil;plan=nil;planDepth=nil;profileCenter=nil;pendingBand=nil
    end,Release=release,Update=function(self,c)
        local now=os.clock()
        if HUD.equipped()~="Magnet"then
            release()
            if now>=nextEquip then nextEquip=now+1;HUD.selectTool("Magnet")end
            self.Status="Equipping GEO-MAG 3000";return
        end
        if c.Phase=="Mining"then
            if c.Depth~=planDepth then plan=nil;profileCenter=nil;pendingBand=nil;planDepth=c.Depth;band=1;nextPlan=now+.2 end
            -- Full generated geometry pins one circular path for the whole depth.
            -- Depleted sectors cannot pull the radius/height inward or reset angle.
            if not plan and now>=nextPlan then plan=buildPlan();nextPlan=now+1 end
            if pendingBand then band=1;pendingBand=nil end
            if not plan then
                if movementStage~="Mining"then release()end
                self.Status="Waiting for mound geometry";return
            end
            band=(band-1)%#plan.Bands+1
            self.RingCount=#plan.Bands;self.RingName=plan.Bands[band].Name
            -- Heartbeat is the sole writer of mining position/focus. Seed only
            -- while entering mining so the held-fire gate has a valid target.
            if movementStage~="Mining"or not target then
                local b=plan.Bands[band];local radius=b.Radius+1.5;local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
                target=Vector3.new(plan.Origin.X,b.Y+self.Hover,plan.Origin.Z)+radial*radius
                focus=Vector3.new(plan.Origin.X,b.Y,plan.Origin.Z)+radial*math.max(0,radius-7)
                cameraOutward=radial
            end
        else
            if CrackSell.Enabled or CrackSell.Busy then CrackSell.Stop("Paused for Endless boss")end
            local map=workspace:FindFirstChild("CaveMap");local mother=map and map:FindFirstChild("Mother");local body=mother and mother:FindFirstChild("Body")
            if not body then release();self.Status="Waiting for boss body";return end
            local bestIndex,bestDir,bestHits,bestId
            for i=1,4 do
                local dir=S.run("MotherSpot"..i)
                local id=S.run("MotherSpot"..i.."Id",0)
                local hits=tonumber(S.run("MotherSpot"..i.."Hits",0))or 0
                if typeof(dir)=="Vector3"and dir.Magnitude>.5 and id~=0 and hits>0 then
                    -- Favor an existing, still-valid weak point so small changes
                    -- in other counters do not cause our aim to jump between spots.
                    if not bestIndex or i==self.ActiveBossSpot and bestIndex~=self.ActiveBossSpot
                        or (bestIndex~=self.ActiveBossSpot and hits>bestHits)then
                        bestIndex,bestDir,bestHits,bestId=i,dir.Unit,hits,id
                    end
                end
            end
            if bestIndex then
                -- Place the player directly along the active weak-point normal
                -- and keep the camera aimed at that point, not the boss center.
                local radius=body.Size.X/2
                local weakPoint=body.Position+bestDir*radius
                target=weakPoint+bestDir*math.max(2.5,self.Hover)-Vector3.new(0,1.5,0)
                focus=weakPoint
                if self.ActiveBossSpot~=bestIndex then
                    record("BossWeakPointTarget",{Index=bestIndex,Id=bestId,HitsRemaining=bestHits})
                end
                self.ActiveBossSpot=bestIndex;self.ActiveBossSpotId=bestId
                self.Status="Tracking exposed critical point "..tostring(bestIndex)
            else
                self.ActiveBossSpot=nil;self.ActiveBossSpotId=nil
                local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
                target=body.Position+radial*(body.Size.X/2+self.Hover);focus=body.Position
                self.Status="Boss vulnerable spots unavailable — using normal hits"
            end
        end
    end})
    local stop=api.Stop
    function api.Stop()
        local ok,err=pcall(held.Stop);api.NativeHeldActive=false
        stop()
        if not ok then record("NativeReleaseError",tostring(err))end
    end
    api.NativeFireEvents=0;api.NativeItems=0;api.FrameInterval=1/60
    local nativeFired=Tools.Fired.Event:Connect(function(tool)
        if held.Active and tool=="Magnet"then
            api.NativeFireEvents+=1
        end
    end)
    local nativeBossHit=Tools.MotherHit.Event:Connect(function(_,_,tool,spot)
        if held.Active and api.Stage=="Boss"and tool=="Magnet"then
            api.Hits+=1;if spot~=nil and spot~=0 then api.WeakHits+=1 end
        end
    end)
    local nativeFeedback=MTG.Remotes.Pick.OnClientEvent:Connect(function(id,tool,packed)
        if held.Active and id==P.UserId and tool=="Magnet"and typeof(packed)=="buffer"then api.NativeItems+=math.floor(buffer.len(packed)/5)end
    end)
    function api.Export()
        return pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_endless_diagnostics.json",H:JSONEncode({Enabled=api.Enabled,BossAssist=api.BossAssist,ActiveBossSpot=api.ActiveBossSpot,ActiveBossSpotId=api.ActiveBossSpotId,Stage=api.Stage,Status=api.Status,Hover=api.Hover,
                Laps=api.Laps,Hits=api.Hits,WeakHits=api.WeakHits,Depth=S.run("Depth"),Phase=S.run("Phase"),Profile=plan,Ring=band,
                NativeHeldActive=held.Active,NativeFireEvents=api.NativeFireEvents,NativeItems=api.NativeItems,HeldStarts=held.Starts,HeldReleases=held.Releases,NativeFireRecoveries=held.Recoveries,
                AbilityRequests=ability.Requests,AbilityConfirmed=ability.Confirmed,AbilityStatus=ability.Status,AbilityStats=ability.Stats,
                FrameInterval=api.FrameInterval,MiningAimPitchOffset=10,OrbitOutwardOffset=1.5,OrbitRadiansPerSecond=math.pi*2/14,OrbitLapSeconds=14,
                CircularOrbit=true,AimMode=api.AimMode,Events=events}))
        end)
    end
    local movement=R.Heartbeat:Connect(function(dt)
        local holdOK,holdError=pcall(function()
            api.FrameInterval=api.FrameInterval*.95+math.clamp(dt,.001,.1)*.05
            local char=P.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
            local bossAssist=api.BossAssist and not api.Enabled and api.Stage=="Boss"
            local owner=(api.Enabled and S.run("Mode")=="Endless" or bossAssist)
                and S.role()=="Game"and S.run("Ended",false)~=true and S.run("EndlessOver",false)~=true
            local mining=api.Stage=="Mining"and S.run("Phase")=="Mining"and S.run("MoundLocked",false)~=true and plan~=nil
            local boss=api.Stage=="Boss"and S.run("Phase")=="Mother"and S.run("MotherHP",0)>0
            local allowed=owner and(mining or boss)and movementStage==api.Stage
                and target~=nil and hum~=nil and hum.Health>0 and HUD.equipped()=="Magnet"and not CrackSell.Busy and not Bench.isCracking()
                and not Pickup.Suspended and not UIKit.cursorFree()and P:GetAttribute("PerkPending")~=true and not Tools.Blocked and not Tools.DevPaused
            held.Update(owner,allowed)
            api.NativeHeldActive=held.Active
            api.NativeFireRecoveries=held.Recoveries
        end)
        if not holdOK then api.Stop();api.Status="Native fire error: "..tostring(holdError);record("NativeFireError",tostring(holdError));return end
        if CrackSell.Busy or Bench.isCracking()then release();return end
        if not (api.Enabled or (api.BossAssist and api.Stage=="Boss")) or not target then return end
        local ok,err=pcall(function()
            local char=P.Character;local root=char and char:FindFirstChild("HumanoidRootPart");local hum=char and char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health<=0 then release();return end
            if char~=ownedCharacter then release();return end
            if api.Stage=="Mining"and plan then
                local b=plan.Bands[band];local radial=Vector3.new(math.cos(angle),0,math.sin(angle));local radius=b.Radius+1.5
                target=Vector3.new(plan.Origin.X,b.Y+api.Hover,plan.Origin.Z)+radial*radius
                focus=Vector3.new(plan.Origin.X,b.Y,plan.Origin.Z)+radial*math.max(0,radius-7)
                cameraOutward=radial
            end
            for _,part in ipairs(char:GetChildren())do if part:IsA("BasePart")then if collision[part]==nil then collision[part]=part.CanCollide end;part.CanCollide=false end end
            hum.AutoRotate=false
            local facing=focus
            if api.Stage=="Mining"then
                facing=plan and Vector3.new(plan.Origin.X,target.Y,plan.Origin.Z)or(target+Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z))
            end
            root.CFrame=CFrame.lookAt(target,facing)
            movementStage=api.Stage
            root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
            if api.Stage=="Mining"and plan and not pendingBand then
                angle+=math.min(dt,.1)*(math.pi*2/14)
                if angle>=math.pi*2 then
                    angle=0;api.Laps+=1;pendingBand=band+1
                    record("LapComplete",{Ring=band,Laps=api.Laps})
                end
            end
        end)
        if not ok then api.Stop();record("MovementError",tostring(err))end
    end)
    local renderName="GeodeEndlessCamera_"..tostring(P.UserId)
    R:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+10,function(dt)
        if not (api.Enabled or (api.BossAssist and api.Stage=="Boss")) or not target or not focus or CrackSell.Busy or Bench.isCracking()then return end
        local cam=workspace.CurrentCamera;if not cam then return end
        if not savedCamera or savedCamera.Camera~=cam then savedCamera={Camera=cam,Type=cam.CameraType,Subject=cam.CameraSubject};smoothedCameraRotation=nil end
        local direction=api.Stage=="Mining"and cameraOutward or(target-focus).Unit
        if not direction then return end
        local cameraPosition=target+direction*3+Vector3.new(0,2,0)
        cam.CameraType=Enum.CameraType.Scriptable
        local desired=CFrame.lookAt(cameraPosition,focus)
        if api.Stage=="Mining"then
            desired=desired*CFrame.Angles(math.rad(10),0,0)
            smoothedCameraRotation=smoothedCameraRotation or cam.CFrame.Rotation
            local frameDt=math.clamp(tonumber(dt)or 1/60,0,.1)
            local _,difference=smoothedCameraRotation:ToObjectSpace(desired.Rotation):ToAxisAngle()
            local alpha=math.min(1-math.exp(-8*frameDt),math.rad(70)*frameDt/math.max(math.abs(difference),.000001))
            smoothedCameraRotation=smoothedCameraRotation:Lerp(desired.Rotation,alpha)
            cam.CFrame=CFrame.new(cameraPosition)*smoothedCameraRotation
        else smoothedCameraRotation=nil;cam.CFrame=desired end
        api.AimMode=api.Stage=="Mining"and"AOE sweep"or"Boss"
    end)
    local unload=api.Unload
    function api.Unload()unload();movement:Disconnect();nativeFired:Disconnect();nativeBossHit:Disconnect();nativeFeedback:Disconnect();R:UnbindFromRenderStep(renderName);api.Export()end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(function()
                -- Capture character restoration values before Update creates a target.
                local standaloneBoss=api.BossAssist and S.role()=="Game"and S.run("Phase")=="Mother"
                    and S.run("MotherHP",0)>0 and S.run("Ended",false)~=true
                if (api.Enabled or standaloneBoss)and(P.Character~=ownedCharacter or not ownedHumanoid)then
                    release()
                    ownedCharacter=P.Character
                    ownedHumanoid=ownedCharacter and ownedCharacter:FindFirstChildOfClass("Humanoid")
                    autoRotate=ownedHumanoid and ownedHumanoid.AutoRotate
                end
                api.Tick()
                ability.Tick(api.Enabled)
                api.AbilityAvailable=ability.Available;api.AbilityStats=ability.Stats;api.AbilityStatus=ability.Status
                api.AbilityRequests=ability.Requests;api.AbilityConfirmed=ability.Confirmed
            end)
            if not ok then api.Stop();api.Status="Endless error: "..tostring(err);record("Error",tostring(err))end
            task.wait(api.Stage=="Boss" and .04 or .125)
        end
    end)
    return api
end

local Endless=createLiveEndless(Pickup,CrackSell,MagnetUpgrades)
-- GEO-MAG Endless priorities. Heuristic scores, adjusted for the actual card,
-- current cooldown floor, existing modifiers, oil and replicated bag capacity.
local function createGeodePerkRanker()
    local ranker={}
    function ranker.Score(def,stacks,c)
        stacks=math.max(1,tonumber(stacks)or 1)
        local id=def.Id;local mods=c.Mods or{};local bonus=def.Mods or{}
        local amount=tonumber((c.Owned or{})[id])or 0
        if def.Max and amount>=def.Max then return nil,"Already at maximum stacks"end
        if def.Max then stacks=math.min(stacks,def.Max-amount)end
        local floor=c.RequestFloor or .05
        local speedUseful=(c.NativeCooldown or 1)>floor+.0001
        local capped=not speedUseful
        local early=not c.MagnetMaxed
        local score,reason=10,"Low-impact fallback for this tool"
        if id=="Shortcut"then score,reason=100,"Less mining required for every depth"
        elseif id=="OilFlask"then
            score,reason=96,"Recurring oil on every cleared depth"
            if(c.OilPerDepth or 0)>=(c.DepthSeconds or 60)*(c.LanternRate or 1)+5 and(c.OilLeft or 0)>120 then score,reason=59,"Existing recurring oil covers the recent depth pace"end
        elseif id=="EternalFlame"then score,reason=94,"30% slower lantern consumption for the run"
        elseif id=="WideSweep"then score,reason=92-math.min(18,math.max(0,mods.Radius or 0)*.15),"Larger magnet collection radius"
        elseif id=="ChainReaction"then score,reason=83,"Splash damage can help clear neighbouring pile geodes"
        elseif id=="GoldenHaul"then score,reason=79,"Protects the haul and increases haul gems"
        elseif id=="BossHunter"then score,reason=74,"Extra chest from every boss"
        elseif id=="SecondLantern"then score,reason=72,"One emergency lantern relight"
        elseif id=="LanternWick"then score,reason=70,"Lower oil consumption over many depths"
        elseif id=="TreasureMap"then score,reason=61,"Recurring bonus chests every ten depths"
        elseif id=="EchoGrab"then score,reason=42,"Extra collected rewards; faster depth clearing is not assumed"
        elseif id=="TreasureSense"then score,reason=48,"Improves haul gem rewards"
        elseif id=="HaulHunter"then score,reason=30+math.min(35,1.5*stacks*2),"Rarity-scaled haul reward gain"
        elseif id=="GemFinder"then score,reason=44,"More gems, without directly accelerating depth clears"
        elseif id=="DeepDiver"then score,reason=early and 62 or 23,"Value scales with depth; primarily useful before magnet upgrades are finished"
        elseif id=="Midas"then score,reason=early and 63 or 24,"Cash generation matters most before magnet upgrades are finished"
        elseif id=="Polish"or id=="DeepProfit"then score,reason=early and 38 or 14,"Crystal value is secondary after cash upgrades are maxed"
        elseif id=="ProspectorMap"then score,reason=early and 42 or 27,"Crystal rarity and income rather than direct mining progress"
        elseif id=="KeenEye"or id=="BottomlessLuck"then score,reason=early and 30 or 17,"Luck mainly improves rewards"
        elseif id=="DeepPockets"then score,reason=c.BagCapacity==-1 and 0 or 55,c.BagCapacity==-1 and"Unlimited bag: no capacity benefit"or"Fewer capacity interruptions"
        elseif id=="TunedTumbler"then score,reason=2,"Current automation uses Crack All instead of waiting on tumbler speed"
        elseif id=="SafetyRope"then score,reason=((c.Owned or{}).GoldenHaul or 0)>0 and 0 or 34,"Loss protection; Golden Haul makes it redundant"
        elseif id=="Cartographer"then score,reason=19,"Useful for manual rerolls; auto selection does not reroll"
        elseif id=="MasteryBooster"then score,reason=6,"Future mastery progress rather than current-run depth speed"
        elseif id=="SpareOil"or id=="SecondWind"then
            local oil=math.min(def.Oil or 0,math.max(0,(c.OilMax or 600)-(c.OilLeft or 0)))
            score,reason=oil>0 and 20+oil/20 or 0,"One-time oil refill"
            if(c.OilLeft or 600)/math.max(.1,c.LanternRate or 1)<60 and oil>0 then score,reason=220+oil/10,"Emergency oil: less than a minute of burn time remains"end
        elseif id=="LastStand"then score,reason=33,"Conditional low-oil damage bonus; avoid deliberately running out of oil"
        elseif def.NeedsSkill then
            if c.AbilitiesActive then
                score=({AbilityDuration=75,AbilityCooldown=73,AbilitySize=68,AbilityDamage=65})[id]or 55
                reason="Improves automatic Overcharge during mining"
                if id=="AbilityCooldown"and c.AbilityStats and c.AbilityStats.Cooldown<=15.75 then score,reason=0,"Overcharge cooldown has reached its configured minimum"end
            else score,reason=0,"Automatic Overcharge is unavailable or disabled"end
        end
        if bonus.PileDamage then
            local gain=bonus.PileDamage*stacks/math.max(10,100+(mods.PileDamage or 0))
            score=math.max(score,40+math.min(55,gain*200))
            reason="Direct pile damage; adjusted for existing damage bonuses and card stacks"
        end
        if bonus.BossDamage then
            local gain=bonus.BossDamage*stacks/math.max(10,100+(mods.BossDamage or 0))
            score=math.max(score,((c.Depth or 1)>=20 and 55 or 40)+math.min(40,gain*200))
            reason="Direct boss damage, with higher priority at later depths"
        end
        if bonus.Power or def.BossPower then
            local power=(bonus.Power or def.BossPower)*stacks
            local total=math.max(1,c.CrackPowerPercent or 100)
            local gain=math.sqrt((total+power)/total)-1
            score=math.max(score,((c.Depth or 1)>=20 and 55 or 40)+math.min(40,gain*200))
            reason="Boss benefit follows the square-root crack-power damage curve"
        end
        if bonus.PickSpeed or id=="Momentum"then
            local speed=bonus.PickSpeed or 20
            if not capped then
                local old=c.NativeCooldown or 1
                local projected=math.max(floor,old*(100+(mods.PickSpeed or 0))/(100+(mods.PickSpeed or 0)+speed*stacks))
                local gain=math.max(0,old/projected-1)
                score=math.max(score,50+math.min(42,gain*220))
                reason="Tool speed still reduces the actual pickup interval"
            elseif not bonus.Power and not bonus.PileDamage then
                score=(id=="Frenzy"and c.BagCapacity~=-1)and 32 or 0
                reason="Speed is already limited by the active firing loop's timing floor"
            end
        end
        return score,reason
    end
    function ranker.Choose(cards,definitions,context,stackCount)
        local rows={};local best
        for index,card in ipairs(cards or{})do
            local def=definitions[card.Id]
            if def then
                local stacks=stackCount(def,card.Rarity)
                local score,reason=ranker.Score(def,stacks,context)
                if score then
                    local row={Index=index,Id=def.Id,Name=def.Name,Score=score,Reason=reason,Stacks=stacks,Rarity=card.Rarity or def.Rarity}
                    rows[#rows+1]=row
                    if not best or score>best.Score then best=row end
                end
            end
        end
        table.sort(rows,function(a,b)if a.Score==b.Score then return a.Index<b.Index end;return a.Score>b.Score end)
        return best,rows
    end
    return ranker
end

local function createAutoPerkController(options)
    local api={Running=true,Enabled=false,Status="Paused",Requests=0,Confirmed=0}
    local pending;local seen={};local order={}
    local function record(kind,data)if options.Record then pcall(options.Record,kind,data)end end
    local function remember(key)
        seen[key]=true;order[#order+1]=key
        if #order>128 then seen[table.remove(order,1)]=nil end
    end
    function api.Start()if api.Running then api.Enabled=true;api.Status="Waiting for perk cards"end end
    function api.Stop()api.Enabled=false;api.Status="Paused"end
    function api.Unload()api.Stop();api.Running=false end
    function api.Confirm(message)
        if not pending then return end
        if message.Offer~=nil and tostring(message.Offer)~=tostring(pending.Offer)then return end
        if message.Perk~=nil and message.Perk~=pending.Id then return end
        if message.Index~=nil and tonumber(message.Index)~=pending.Index then return end
        if message.Perk==nil and message.Index==nil then return end
        api.Confirmed+=1;api.Status="Confirmed: "..pending.Name;record("Confirmed",pending);pending=nil
    end
    function api.Tick()
        if not api.Running then return end
        if not api.Enabled and not pending then return end
        local c=options.Context();local now=options.Now()
        if pending then
            if((c.Owned or{})[pending.Id]or 0)>pending.Before then api.Confirm({Perk=pending.Id})
            elseif now>=pending.Deadline then record("Unconfirmed",pending);pending=nil;api.Status="Last selection unconfirmed; waiting for a new offer"end
        end
        if not api.Enabled or pending then return end
        if not c.Endless then api.Status="Waiting for Endless mode";return end
        if not c.ToolOwned then api.Status="GEO-MAG 3000 ownership required";return end
        if not c.Ready or not c.Key or not c.Offer or c.Test then return end
        if c.Until and c.Until<=c.ServerNow then return end
        if seen[c.Key]then return end
        local best,ranking=options.Choose(c.Cards,c)
        if not best then api.Status="Unrecognised perk offer — choose manually";return end
        remember(c.Key)
        pending={Offer=c.Offer,Index=best.Index,Id=best.Id,Name=best.Name,Before=(c.Owned or{})[best.Id]or 0,Deadline=now+6}
        api.LastChoice=best;api.LastRanking=ranking;api.Requests+=1
        record("Selection",{Choice=best,Ranking=ranking,Offer=c.Offer})
        local ok,err=pcall(options.Submit,best.Index,c)
        if not ok then record("Error",tostring(err));pending=nil;api.Stop();api.Status="Perk selection failed: "..tostring(err);return end
        if pending then api.Status="Selected "..best.Name.." — waiting for server confirmation"end
    end
    return api
end

local function createLiveAutoPerks(MagnetUpgrades,Endless)
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local M=game:GetService("ReplicatedStorage").MTG
    local C=P.PlayerScripts.MTGClient
    local S=require(C.State)
    local Cards=require(C.PerkCards)
    local E=require(M.Config.Endless)
    local Stats=require(M.Modules.Stats)
    local Tools=require(C.Tools)
    local ranker=createGeodePerkRanker()
    local events={};local dirty=false;local ownedRaw;local owned={}
    local lastDepth;local depthAt=os.clock();local depthSeconds=60
    local function context()
        local raw=P:GetAttribute("Perks")or"{}"
        if raw~=ownedRaw then
            ownedRaw=raw
            local ok,data=pcall(H.JSONDecode,H,raw);owned=ok and type(data)=="table"and data or {}
        end
        local depth=S.run("Depth",1)
        if lastDepth and lastDepth~=depth then depthSeconds=math.clamp(os.clock()-depthAt,1,180);depthAt=os.clock()end
        lastDepth=depth
        local ctx=S.ctx();local tool=Stats.tool(ctx,"Magnet")
        local plus=table.clone(ctx);plus.Mods=table.clone(ctx.Mods or{});plus.Mods.Power=(plus.Mods.Power or 0)+100
        local power=Stats.crackPower(ctx);local delta=Stats.crackPower(plus)-power
        local state=Cards._debug and Cards._debug.P
        local offer=state and state.Offer
        return {Endless=S.role()=="Game"and S.run("Mode")=="Endless"and S.run("Ended",false)~=true and S.run("EndlessOver",false)~=true,ToolOwned=S.set("Tools").Magnet==true,
            Ready=state and state.Open and state.Ready and not state.Picked,
            Offer=offer and offer.Offer,Key=offer and offer.Offer~=nil and(game.JobId..":"..tostring(S.run("RunStart"))..":"..tostring(offer.Offer)..":"..tostring(state.Token)),
            Test=offer and offer.Test,Cards=offer and offer.Cards,Until=offer and tonumber(offer.Until),ServerNow=workspace:GetServerTimeNow(),
            Owned=owned,Mods=ctx.Mods,Depth=depth,OilLeft=tonumber(S.run("LanternLeft",0))or 0,OilMax=E.Lantern.Max,
            LanternRate=tonumber(S.run("LanternRate",1))or 1,OilPerDepth=(owned.OilFlask or 0)*15,DepthSeconds=depthSeconds,
            BagCapacity=P:GetAttribute("BagCap"),NativeCooldown=tool.Cooldown*Tools.paceMult("Magnet"),
            RequestFloor=Endless and Endless.Enabled and S.run("Mode")=="Endless"and math.clamp(Endless.FrameInterval or 1/60,.001,.1)or .05,
            AbilitiesActive=Endless and Endless.Enabled and Endless.AbilityAvailable,AbilityStats=Endless and Endless.AbilityStats,
            CrackPowerPercent=delta>0 and power*100/delta or 100,MagnetMaxed=MagnetUpgrades.IsMaxed()}
    end
    local function choose(cards,c)return ranker.Choose(cards,E.PerkById,c,function(def,rarity)return E.cardStacks(def,rarity)end)end
    local api=createAutoPerkController({Now=os.clock,Context=context,Choose=choose,Submit=function(index,c)
        -- Native _pick checks readiness, sends Pick with the offer token, and
        -- handles the card animation/input cleanup. No reroll action is sent.
        local current=context()
        assert(current.Ready and current.Key==c.Key,"Perk offer changed before selection")
        Cards._pick(index,false)
    end,Record=function(kind,data)
        events[#events+1]={Kind=kind,At=os.time(),Data=data};if #events>100 then table.remove(events,1)end;dirty=true
    end})
    local connection=M.Remotes.Endless.OnClientEvent:Connect(function(message)
        if type(message)=="table"and message.Type=="Picked"then api.Confirm(message)end
    end)
    function api.Export()
        return pcall(function()
            local c=context();local all={}
            for _,def in ipairs(E.Perks)do all[#all+1]={Id=def.Id,Rarity=def.Rarity}end
            local _,ranking=choose(all,c)
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_perk_diagnostics.json",H:JSONEncode({Version=1,Enabled=api.Enabled,Status=api.Status,Requests=api.Requests,Confirmed=api.Confirmed,
                LastChoice=api.LastChoice,LastOfferRanking=api.LastRanking,DefaultRarityRanking=ranking,
                Context={Depth=c.Depth,OilLeft=c.OilLeft,LanternRate=c.LanternRate,NativeCooldown=c.NativeCooldown,RequestFloor=c.RequestFloor,
                    BagCapacity=c.BagCapacity,MagnetMaxed=c.MagnetMaxed,CrackPowerPercent=c.CrackPowerPercent,OilPerDepth=c.OilPerDepth,DepthSeconds=c.DepthSeconds,Owned=c.Owned,Mods=c.Mods,AbilitiesActive=c.AbilitiesActive,AbilityStats=c.AbilityStats},Events=events,
                Note="Heuristic GEO-MAG depth-survival ranking. Actual offered rarity/stacks, current caps and automatic Overcharge availability affect each choice. No rerolls."}))
            dirty=false
        end)
    end
    local unload=api.Unload
    function api.Unload()unload();connection:Disconnect();api.Export()end
    task.spawn(function()
        local nextSave=0
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Stop();api.Status="Perk error: "..tostring(err)end
            if dirty and os.clock()>=nextSave then nextSave=os.clock()+2;api.Export()end
            task.wait(.25)
        end
    end)
    return api
end

local AutoPerks=createLiveAutoPerks(MagnetUpgrades,Endless)
local function createGeodeTeleportContinuation(options)
    local api={Enabled=true,Running=true,Installed=false}
    function api.Save()
        if not api.Running or not api.Enabled then return false end
        local state=options.GetState()
        state.Schema=1;state.GameId=10770110947;state.SourceJobId=options.JobId;state.SavedAt=options.Now()
        return options.WriteState(state)
    end
    function api.SetEnabled(value)
        api.Enabled=value==true
        options.WriteEnabled(api.Enabled)
        if api.Enabled and api.Running then
            if not options.HasQueued()then
                local ok,result=pcall(options.Queue)
                api.Installed=ok and result~=false
                if api.Installed then options.MarkQueued()end
            else api.Installed=true end
            api.Save()
        end
    end
    function api.Stop()
        if not api.Running then return end
        api.SetEnabled(false);api.Running=false
    end
    api.SetEnabled(true)
    return api
end

local function createLiveGeodeTeleport(getState)
    local H=game:GetService("HttpService")
    local P=game:GetService("Players").LocalPlayer
    local env=getgenv()
    local previous=env.__GeodeTeleportContinuation
    if previous and type(previous.Stop)=="function"then previous.Stop()end
    local enabledPath="GeodeHub/teleport_enabled.txt"
    local statePath="GeodeHub/teleport_state.json"
    pcall(function()if not isfolder("GeodeHub")then makefolder("GeodeHub")end end)
    local payload=[==[
task.spawn(function()
    if not game:IsLoaded()then game.Loaded:Wait()end
    if game.GameId~=10770110947 then return end
    local env=getgenv()
    local enabledOK,enabled=pcall(function()return readfile("GeodeHub/teleport_enabled.txt")end)
    if not enabledOK or enabled~="true"then return end
    if env.__GeodeQueuedBootJob==game.JobId then return end
    env.__GeodeQueuedBootJob=game.JobId
    local stateOK,state=pcall(function()return game:GetService("HttpService"):JSONDecode(readfile("GeodeHub/teleport_state.json"))end)
    if stateOK and type(state)=="table"and state.GameId==game.GameId
        and state.SourceJobId~=game.JobId and type(state.SavedAt)=="number"
        and os.time()-state.SavedAt>=0 and os.time()-state.SavedAt<900 then
        env.__GeodeTeleportResume=state
    end
    local function compileSource(source,isLoader)
        if type(source)~="string"or #source<(isLoader and 500 or 4000)then return nil end
        if isLoader then
            if not source:find("Crack the Geode! loader v2",1,true)or not source:find("validateGeodeHubSource",1,true)then return nil end
        elseif not source:find("-- Beyy Geode Hub | Crack the Geode!",1,true)or not source:find("return Hub",1,true)
            or not source:find("createNativeUI",1,true)or not source:find("Auto Geode Pickup",1,true)then return nil end
        return loadstring(source)
    end
    local ok,source=pcall(function()return readfile("GeodeHub/loader.lua")end)
    local compiled=ok and compileSource(source,true)
    if not compiled then
        ok,source=pcall(function()return game:HttpGet("https://raw.githubusercontent.com/sceneton/geode/main/loader.lua?refresh="..tostring(os.time()))end)
        compiled=ok and compileSource(source,true)
    end
    if not compiled then
        ok,source=pcall(function()return readfile("GeodeHub/main.lua")end)
        compiled=ok and compileSource(source,false)
    end
    if not compiled then
        ok,source=pcall(function()return readfile("GeodeHub/main.backup.lua")end)
        compiled=ok and compileSource(source,false)
    end
    if compiled then
        local success,err=pcall(compiled)
        if not success then warn("[Geode Hub] Teleport reload failed: "..tostring(err))end
    else warn("[Geode Hub] Teleport reload could not find an online or cached hub")end
end)
]==]
    local queue=queue_on_teleport or queueonteleport or env.queue_on_teleport or env.queueonteleport
    if type(queue)~="function"and type(syn)=="table"then queue=syn.queue_on_teleport end
    local stamp=tostring(game.PlaceId)..":"..game.JobId
    local api=createGeodeTeleportContinuation({GetState=getState,JobId=game.JobId,Now=os.time,
        WriteEnabled=function(value)pcall(writefile,enabledPath,value and"true"or"false")end,
        WriteState=function(state)return pcall(writefile,statePath,H:JSONEncode(state))end,
        Queue=function()if type(queue)~="function"then return false end;return queue(payload)end,
        HasQueued=function()return env.__GeodeQueuedJob==stamp end,
        MarkQueued=function()env.__GeodeQueuedJob=stamp end})
    local connection=P.OnTeleport:Connect(function()api.Save()end)
    local stop=api.Stop
    function api.Stop()stop();connection:Disconnect()end
    env.__GeodeTeleportContinuation=api
    return api
end

local NativeUI=createNativeUI()
local Window=NativeUI:CreateWindow({Title="Beyy Hub | Crack the Geode!",Folder="GeodeHub"})
Window:SetToggleKey(Enum.KeyCode.RightControl)
local Hub={Running=true,Version="1.10.9",Window=Window,Pickup=Pickup,Eggs=Eggs,ClassMutations=ClassMutations,CrackSell=CrackSell,MagnetUpgrades=MagnetUpgrades,Escape=Escape,Endless=Endless,GameWalkSpeed=GameWalkSpeed,IntroVisuals=IntroVisuals,AutoPerks=AutoPerks}
Window.Gui:SetAttribute("GeodeSessionVersion",Hub.Version)
env.GeodeHub=Hub
function Hub.Unload()
    if not Hub.Running then return end
    Hub.Running=false
    ClassMutations.Unload()
    AutoPerks.Unload()
    Endless.Unload()
    GameWalkSpeed.Unload()
    IntroVisuals.Unload()
    Escape.Unload()
    if Hub.Teleport then Hub.Teleport.Stop()end
    MagnetUpgrades.Unload()
    CrackSell.Unload()
    Pickup.Unload()
    Eggs.Unload()
    Window:Destroy()
    releaseGeodeBoot()
end
stop.OnInvoke=Hub.Unload
local overview=Window:Section({Title="Overview"})
local main=overview:Tab({Title="Main"})
local endlessTab=overview:Tab({Title="Endless"})
local eggs=overview:Tab({Title="Eggs"})
local mutations=overview:Tab({Title="Class Mutations"})
local settings=overview:Tab({Title="Configs & Settings"})
endlessTab:Section({Title="Endless Farming"})
local endlessToggle=endlessTab:Toggle({Title="Auto Endless Mode",Value=false,Callback=function(value)
    if value then Endless.Start()else Endless.Stop()end
end})
local hoverHeight=endlessTab:Slider({Title="Endless Hover Clearance (studs)",Step=.5,Value={Min=2,Max=20,Default=6.5},Callback=function(value)Endless.SetHover(value)end})
local endlessStatus=endlessTab:Paragraph({Title="Endless Status",Desc="Paused — manages pickup, camp visits, upgrades and boss weak points in Endless mode."})
local bossCritToggle=endlessTab:Toggle({Title="Auto Boss Critical Hits (Always On)",Value=true,Callback=function(value)
    Endless.SetBossAssist(value)
end})
endlessTab:Paragraph({Title="Boss Assistance",Desc="Active whenever this hub is loaded, even with Auto Endless off. Targets exposed Mother weak points and fires normally while waiting for one. Requires GEO-MAG 3000."})
local perkToggle=endlessTab:Toggle({Title="Auto Select Perk",Value=false,Callback=function(value)
    if value then AutoPerks.Start()else AutoPerks.Stop()end
end})
local perkStatus=endlessTab:Paragraph({Title="Perk Selection Status",Desc="Prioritises GEO-MAG depth survival, emergency oil and effective damage/radius. Accounts for speed caps and card rarity. No automatic rerolls."})
endlessTab:Button({Title="Export Perk Ranking & Diagnostics",Callback=function()
    local ok,err=AutoPerks.Export()
    NativeUI:Notify({Title="Perk Ranking",Content=ok and"Saved Geode/auto_perk_diagnostics.json"or tostring(err)})
end})
endlessTab:Button({Title="Export Endless Diagnostics",Callback=function()
    local ok,err=Endless.Export()
    NativeUI:Notify({Title="Endless Diagnostics",Content=ok and"Saved to Geode/auto_endless_diagnostics.json"or tostring(err)})
end})
main:Section({Title="Character Movement"})
local walkSpeedToggle=main:Toggle({Title="3x WalkSpeed During Game",Value=true,Callback=function(value)
    GameWalkSpeed.SetEnabled(value)
end})
local walkSpeedStatus=main:Paragraph({Title="WalkSpeed Status",Desc="Automatically triples normal walking speed while playing; restores when leaving the game."})
main:Section({Title="Geode Collection"})
local pickupToggle=main:Toggle({Title="Auto Geode Pickup",Value=false,Callback=function(value)
    if value then Pickup.Start()else Pickup.Stop()end
end})
local pickupRange=main:Slider({Title="Pickup Range (studs)",Step=1,Value={Min=1,Max=26,Default=26},Callback=function(value)
    Pickup.SetRange(0,value)
end})
local live=main:Paragraph({Title="Pickup Status",Desc="Paused — enable Auto Geode Pickup to begin."})
main:Button({Title="Export Pickup Diagnostics",Callback=function()
    local ok,err=Pickup.Export()
    NativeUI:Notify({Title="Diagnostics",Content=ok and"Saved to Geode/auto_pickup_diagnostics.json"or tostring(err)})
end})
main:Section({Title="Cracking & Selling"})
local crackToggle=main:Toggle({Title="Auto Crack and Sell",Value=false,Callback=function(value)
    if value then CrackSell.Start()elseif CrackSell.Enabled then CrackSell.Stop()end
end})
local cycleInterval=main:Slider({Title="Wait After Bag Change (seconds)",Step=1,Value={Min=1,Max=60,Default=1},Callback=function(value)
    CrackSell.SetInterval(value)
end})
local continuousCrack=main:Toggle({Title="Keep Cracking & Selling",Value=false,Callback=function(value)
    CrackSell.SetContinuous(value)
end})
local repeatInterval=main:Slider({Title="Repeat Crack & Sell Delay (seconds)",Step=1,Value={Min=1,Max=60,Default=10},Callback=function(value)
    CrackSell.SetRepeatInterval(value)
end})
local crackStatus=main:Paragraph({Title="Crack & Sell Status",Desc="Paused — returns to your pickup position after each cycle."})
main:Paragraph({Title="Crack & Sell Timing",Desc="Default: one deposit, crack and sale after the first bag change (1 second), then automatic shutdown to prevent repeated return trips. Keep Cracking & Selling explicitly enables repeating cycles."})
main:Section({Title="Escape"})
local escapeToggle=main:Toggle({Title="Auto Escape",Value=false,Callback=function(value)
    if value then Escape.Start()else Escape.Stop()end
end})
local escapeStatus=main:Paragraph({Title="Escape Status",Desc="Paused — waits for Escape phase and the open lift, then moves to your saved exit position."})
main:Button({Title="Export Crack & Sell Diagnostics",Callback=function()
    local ok,err=CrackSell.Export()
    NativeUI:Notify({Title="Crack & Sell Diagnostics",Content=ok and"Saved to Geode/auto_crack_sell_diagnostics.json"or tostring(err)})
end})
eggs:Section({Title="Candy Shop"})
main:Section({Title="GEO-MAG 3000 Upgrades"})
local upgradeToggle=main:Toggle({Title="Auto Upgrade GEO-MAG 3000",Value=false,Callback=function(value)
    if value then MagnetUpgrades.Start()else MagnetUpgrades.Stop()end
end})
local upgradeStatus=main:Paragraph({Title="Magnet Upgrade Status",Desc="Paused — buys Pull Power and Pulse Speed with cash."})
local eggToggle=eggs:Toggle({Title="Auto Open Haunted Egg",Value=false,Callback=function(value)
    if value then Eggs.Start()else Eggs.Stop()end
end})
local eggStatus=eggs:Paragraph({Title="Egg Status",Desc="Paused. Opens 3 eggs per batch for 180 candy."})
eggs:Button({Title="Export Egg Diagnostics",Callback=function()
    local ok,err=Eggs.Export()
    NativeUI:Notify({Title="Egg Diagnostics",Content=ok and"Saved to Geode/haunted_egg_diagnostics.json"or tostring(err)})
end})
mutations:Section({Title="Class Mutation Rolls"})
local mutationClass=mutations:Dropdown({Title="Class to Mutate",Values=ClassMutations.ClassOptions(),Value=ClassMutations.Class,Callback=ClassMutations.SetClass})
mutations:Button({Title="Refresh Owned Classes",Callback=function()mutationClass:Refresh(ClassMutations.ClassOptions())end})
local mutationScroll=mutations:Dropdown({Title="Mutation Scroll Type",Values={"Normal","Lucky"},Value="Normal",Callback=ClassMutations.SetScrollType})
local mutationTarget=mutations:Dropdown({Title="Stop at Mutation",Values=ClassMutations.TargetOptions(),Value="Glitched",Callback=ClassMutations.SetTarget})
local mutationLimit=mutations:Slider({Title="Maximum Rolls per Start",Step=1,Value={Min=1,Max=1000,Default=10},Callback=ClassMutations.SetLimit})
local mutationToggle=mutations:Toggle({Title="Auto Roll Class Mutation",Value=false,Callback=function(value)
    if value then ClassMutations.Start()elseif ClassMutations.Enabled then ClassMutations.Stop()end
end})
mutations:Paragraph({Title="Mutation Rolling",Desc="Uses one selected scroll per accepted roll. Keeps the better mutation. Stops at the target or higher, the roll limit, no scrolls, or a server error. One request at a time, without the roll animation. Settings apply on the next start; rolling starts off after reloading."})
local mutationStatus=mutations:Paragraph({Title="Class Mutation Status",Desc="Paused"})
settings:Section({Title="Loading Cutscene"})
local skipIntroToggle=settings:Toggle({Title="Hide Chapter Loading Cutscene",Value=true,Callback=function(value)
    IntroVisuals.SetEnabled(value)
end})
local introStatus=settings:Paragraph({Title="Intro Suppression",Desc="Moves loading and intro visuals offscreen without disabling the game's UI."})
local earlyPickupToggle=settings:Toggle({Title="Try Geode Pickup During Hidden Intro",Value=true,Callback=function(value)
    Pickup.SetEarlyIntro(value)
end})
local earlyPickupStatus=settings:Paragraph({Title="Early Pickup",Desc="One test request while Waiting. Continues only if the bag increases before normal Mining; otherwise waits and resumes when Mining starts."})
settings:Section({Title="Configuration"})
local config=Window.ConfigManager:CreateConfig("default")
local autoLoad=settings:Toggle({Title="Auto-load Saved Config",Value=true,Callback=function()end})
config:Register("AutoLoadConfig",autoLoad)
config:Register("WalkSpeedTriple",walkSpeedToggle)
config:Register("HideChapterIntro",skipIntroToggle)
config:Register("EarlyIntroPickup",earlyPickupToggle)
config:Register("AutoGeodePickup",pickupToggle)
config:Register("PickupRange",pickupRange)
config:Register("AutoOpenHauntedEgg",eggToggle)
config:Register("AutoCrackAndSell",crackToggle)
config:Register("CrackSellBagDelay",cycleInterval)
config:Register("CrackSellContinuous",continuousCrack)
config:Register("CrackSellRepeatInterval",repeatInterval)
config:Register("AutoUpgradeMagnet",upgradeToggle)
config:Register("AutoEscape",escapeToggle)
config:Register("EndlessHover",hoverHeight)
config:Register("AutoEndless",endlessToggle)
config:Register("AutoBossCrit",bossCritToggle)
config:Register("AutoSelectPerk",perkToggle)
config:Register("MutationClass",mutationClass)
config:Register("MutationScrollType",mutationScroll)
config:Register("MutationTarget",mutationTarget)
config:Register("MutationRollLimit",mutationLimit)
settings:Button({Title="Save Config",Callback=function()
    local result,err=config:Save()
    NativeUI:Notify({Title="Config",Content=result and"Saved default config"or("Save failed: "..tostring(err))})
end})
settings:Button({Title="Load Config",Callback=function()
    local result,err=config:Load()
    NativeUI:Notify({Title="Config",Content=result and"Loaded default config"or(err or"Could not load config")})
end})
settings:Section({Title="Menu"})
local menuKey=settings:Keybind({Title="Menu Toggle Key",Value="RightControl",Callback=function(value)Window:SetToggleKey(value)end})
config:Register("MenuToggleKey",menuKey)
local continuation
local queueToggle=settings:Toggle({Title="Queue on Teleport",Value=true,Callback=function(value)
    if continuation then continuation.SetEnabled(value)end
end})
config:Register("QueueOnTeleport",queueToggle)
continuation=createLiveGeodeTeleport(function()
    return {Pickup=Pickup.Enabled,Range=Pickup.MaxRange,WalkSpeedTriple=GameWalkSpeed.Enabled,HideChapterIntro=IntroVisuals.Enabled,EarlyIntroPickup=Pickup.EarlyIntroEnabled,Eggs=Eggs.Enabled,CrackSell=CrackSell.Enabled,
        BagDelay=CrackSell.Interval,CrackSellContinuous=CrackSell.Continuous,CrackSellRepeatInterval=CrackSell.RepeatInterval,MagnetUpgrades=MagnetUpgrades.Enabled,Escape=Escape.Enabled,Endless=Endless.Enabled,EndlessHover=Endless.Hover,BossAssist=Endless.BossAssist,AutoPerks=AutoPerks.Enabled,MenuKey=Window.ToggleKey.Name,MenuClosed=Window.Closed}
end)
Hub.Teleport=continuation
settings:Button({Title="Unload Hub",Callback=Hub.Unload})
local session=settings:Paragraph({Title="Session",Desc="Crack the Geode!"})
local resumed=env.__GeodeTeleportResume
env.__GeodeTeleportResume=nil
local loaded,loadError=config:Load(true,type(resumed)=="table"and resumed.GameId==10770110947)
if type(resumed)=="table"and resumed.GameId==10770110947 then
    walkSpeedToggle:Set(resumed.WalkSpeedTriple~=false)
    skipIntroToggle:Set(resumed.HideChapterIntro~=false)
    earlyPickupToggle:Set(resumed.EarlyIntroPickup~=false)
    pickupRange:Set(tonumber(resumed.Range)or 26)
    cycleInterval:Set(tonumber(resumed.BagDelay)or 1)
    continuousCrack:Set(resumed.CrackSellContinuous==true)
    repeatInterval:Set(tonumber(resumed.CrackSellRepeatInterval)or 10)
    hoverHeight:Set(tonumber(resumed.EndlessHover)or 6.5)
    bossCritToggle:Set(resumed.BossAssist~=false)
    if type(resumed.MenuKey)=="string"and Enum.KeyCode[resumed.MenuKey]then menuKey:Set(resumed.MenuKey)end
    pickupToggle:Set(resumed.Pickup==true)
    eggToggle:Set(resumed.Eggs==true)
    crackToggle:Set(resumed.CrackSell==true)
    upgradeToggle:Set(resumed.MagnetUpgrades==true)
    escapeToggle:Set(resumed.Escape==true)
    endlessToggle:Set(resumed.Endless==true)
    perkToggle:Set(resumed.AutoPerks==true)
    if resumed.MenuClosed then Window:Close()end
end
continuation.Save()
boot:SetAttribute("Stage","Ready")
retireGeodeMenus(Window.Gui)
NativeUI:Notify({Title="Geode Hub",Content=type(resumed)=="table"and"Previous options restored after teleport."or(loaded and"Default config restored. Right Ctrl opens or closes the menu."or("Right Ctrl opens or closes the menu. "..tostring(loadError)))})
task.spawn(function()
    while Hub.Running and env.GeodeHub==Hub and not Window.Destroyed do
        local uiOK,uiError=pcall(function()
        if perkToggle.Value~=AutoPerks.Enabled then perkToggle:Set(AutoPerks.Enabled)end
        if mutationToggle.Value~=ClassMutations.Enabled then mutationToggle:Set(ClassMutations.Enabled)end
        mutationStatus:SetDesc(ClassMutations.Status.."\nRequests this start: "..ClassMutations.SessionRequests.." | Accepted this session: "..ClassMutations.Accepted.."\nLast rolled: "..ClassMutations.LastRolled)
        perkStatus:SetDesc(AutoPerks.Status.."\nChoices sent: "..AutoPerks.Requests.." | Confirmed: "..AutoPerks.Confirmed)
        if endlessToggle.Value~=Endless.Enabled then endlessToggle:Set(Endless.Enabled)end
        endlessStatus:SetDesc(Endless.Status.."\nRing: "..tostring(Endless.RingName or"Waiting").." / "..tostring(Endless.RingCount or 0).." | Hover: "..Endless.Hover.." studs\nHeld fire: "..(Endless.NativeHeldActive and"Active"or"Paused").." | Native shots: "..Endless.NativeFireEvents.." | Items: "..Endless.NativeItems.."\nAbility: "..tostring(Endless.AbilityStatus or"Waiting").." | Confirmed uses: "..tostring(Endless.AbilityConfirmed or 0).."\nLaps: "..Endless.Laps.." | Boss hits: "..Endless.Hits.." | Weak hits: "..Endless.WeakHits.." | Critical target: "..tostring(Endless.ActiveBossSpot or "None"))
        if escapeToggle.Value~=Escape.Enabled then escapeToggle:Set(Escape.Enabled)end
        escapeStatus:SetDesc(Escape.Status.."\nExit moves this round: "..Escape.Attempts)
        if pickupToggle.Value~=Pickup.Enabled then pickupToggle:Set(Pickup.Enabled)end
        if eggToggle.Value~=Eggs.Enabled then eggToggle:Set(Eggs.Enabled)end
        if crackToggle.Value~=CrackSell.Enabled then crackToggle:Set(CrackSell.Enabled)end
        if upgradeToggle.Value~=MagnetUpgrades.Enabled then upgradeToggle:Set(MagnetUpgrades.Enabled)end
        local player=game:GetService("Players").LocalPlayer
        local mtg=game:GetService("ReplicatedStorage"):FindFirstChild("MTG")
        local state=mtg and mtg:FindFirstChild("State")
        walkSpeedStatus:SetDesc(GameWalkSpeed.Status)
        introStatus:SetDesc(IntroVisuals.Status.." | Visual relocations: "..IntroVisuals.Hidden)
        earlyPickupStatus:SetDesc(Pickup.EarlyIntroStatus.." | Attempts: "..Pickup.EarlyAttempts.." | Server replies with items: "..Pickup.EarlyConfirmed)
        upgradeStatus:SetDesc(MagnetUpgrades.Status.."\nConfirmed upgrades this session: "..MagnetUpgrades.Confirmed)
        crackStatus:SetDesc(string.format("%s\nCompleted cycles: %d | Sales: %d | Cash gained: %.2f\nPickup pauses during camp visits; returns afterward.",
            CrackSell.Status,CrackSell.Cycles,CrackSell.Sales,CrackSell.CashGained))
        eggStatus:SetDesc(string.format("%s\n3 eggs per batch | Cost: %d candy | Balance: %s\nOpened: %d | Requests: %d | Busy replies: %d\nLast: %s",
            Eggs.Status,Eggs.Price or 180,tostring(player:GetAttribute("Candy")or 0),Eggs.Opened,Eggs.Requests,Eggs.BusyReplies,Eggs.ResultText()))
        live:SetDesc(string.format("%s\nRange: 0–%d studs | Requests: %d | Tool feedback: %d | Items: %d\nBag: %s / %s",
            Pickup.Status or"Paused",Pickup.MaxRange,Pickup.Requests,Pickup.Feedback,Pickup.Items,
            tostring(player:GetAttribute("BagCount")or 0),(player:GetAttribute("BagCap")==-1 and"Unlimited"or tostring(player:GetAttribute("BagCap")or"—"))))
        session:SetDesc("Role: "..tostring(mtg and mtg:GetAttribute("Role")or"Loading").." | Phase: "..tostring(state and state:GetAttribute("Phase")or"Lobby").."\nVersion "..Hub.Version.." | Teleport queue: "..(not continuation.Enabled and"Off"or(continuation.Installed and"Ready"or"Unavailable")))
        end)
        if not uiOK then warn("[Geode UI] Status update failed: "..tostring(uiError))end
        task.wait(0.5)
    end
    if Hub.Running then Hub.Unload()end
end)
print("[Geode Hub] Native menu loaded; RightControl toggles the menu. Teleport queue="..tostring(continuation.Installed))
return Hub

end)
if not success then
    if env.GeodeHub and env.GeodeHub.Window and env.GeodeHub.Window.Gui:GetAttribute("GeodeSessionVersion")==geodeVersion then pcall(env.GeodeHub.Unload)end
    releaseGeodeBoot()
    error(result)
end
if not result then releaseGeodeBoot()end
return result -- return Hub is inside the protected constructor