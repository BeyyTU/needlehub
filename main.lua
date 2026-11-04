-- Beyy Geode Hub | Crack the Geode! | native menu and range-limited pickup
if not game:IsLoaded()then game.Loaded:Wait()end
if game.GameId~=10770110947 then warn("[Geode Hub] This script is for Crack the Geode!");return end
local env=getgenv()
-- Claim startup before module initialization can yield. The shared instance also
-- covers queued chunks whose executor globals are isolated from one another.
local geodeVersion="1.10.45"
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
                local automation={AutoGeodePickup=true,AutoOpenHauntedEgg=true,AutoCrackAndSell=true,AutoUpgradeMagnet=true,AutoEscape=true,AutoEndless=true,AutoSelectPerk=true,AutoFarmEscapes=true}
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
local api={Running=true,Enabled=false,EarlyIntroEnabled=true,EarlyIntroStatus="Not attempted",EarlyAttempts=0,EarlyConfirmed=0,
    FastPickup=true,MinRange=0,MaxRange=math.min(26,Game.Collect.Reach),
    Requests=0,Feedback=0,Items=0,ZeroReplies=0,Timeouts=0,
    Searches=0,LastSearchMs=0,SearchRays=0,LastCooldown=0,LastReplyMs=0}
env.GeodeAutoPickup=api
local events,connections={},{}
local startedAt=os.clock()
local lastPhaseSignature
local nextReadinessCheck=0
local nextSend=0;local pending;local avoided={};local dirty=false;local deadline
local earlySession,earlyStage="","idle"
local lastIntroRole,lastIntroPhase,lastIntroCharacter
local introProvider
local status="Paused"
local screen,statusLabel,toggle,rangeBox
local function log(kind,data)
    events[#events+1]={Kind=kind,At=os.clock(),WallTimeMs=DateTime.now().UnixTimestampMillis,Data=data}
    if #events>160 then table.remove(events,1)end
    dirty=true
    -- Frequent collection logs stay in the bounded JSON event ring; printing
    -- each request/response stalls the client and executor console.
    if kind~="BagChanged"and kind~="Request"and kind~="ServerPickupFeedback"
        and kind~="OtherPickupFeedback"and kind~="NoConfirmation"then
        print("[Geode Pickup] "..kind.." "..H:JSONEncode(data or{}))
    end
end
local function earlyStatus(value)
    if api.EarlyIntroStatus~=value then
        api.EarlyIntroStatus=value
        log("EarlyPickupStatus",{Status=value,Session=tostring(earlySession)})
    end
end
local function setStatus(text)
    if status==text then return end
    status=text;api.Status=text
    if statusLabel then statusLabel.Text=text end
end
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
function api.SetFastPickup(value)
    api.FastPickup=value==true
    nextSend=0
    log("FastModeChanged",{Enabled=api.FastPickup})
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
        FastPickup=api.FastPickup,ZeroReplies=api.ZeroReplies,Timeouts=api.Timeouts,
        Searches=api.Searches,LastSearchMs=api.LastSearchMs,SearchRays=api.SearchRays,
        LastCooldown=api.LastCooldown,LastReplyMs=api.LastReplyMs,
        NativeHeldOwner=api.NativeHeldOwner~=nil,
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
end
local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include;overlap.MaxParts=512
local rays=RaycastParams.new();rays.FilterType=Enum.RaycastFilterType.Include
local filteredFolder
local function targetFor(root)
    local folder=Render.Folder
    if not folder or not folder.Parent then return end
    if folder~=filteredFolder then
        filteredFolder=folder
        overlap.FilterDescendantsInstances={folder}
        rays.FilterDescendantsInstances={folder}
    end
    local started=os.clock()
    api.Searches+=1
    local position=root.Position
    local maxRange2=api.MaxRange*api.MaxRange
    local candidates={}
    -- The old loop decoded every nearby mound part before sorting (up to
    -- 512 Render.target calls per search). Sort by cheap squared distance
    -- first, then decode only the nearest likely targets.
    for _,part in ipairs(World:GetPartBoundsInRadius(position,api.MaxRange,overlap))do
        if part.CanQuery and part.Transparency<1 then
            local vector=part.Position-position
            local distance2=vector:Dot(vector)
            if distance2<=maxRange2 then
                candidates[#candidates+1]={Part=part,Distance2=distance2}
            end
        end
    end
    table.sort(candidates,function(a,b)return a.Distance2<b.Distance2 end)
    local now=os.clock()
    local maxRays=api.FastPickup and 24 or 32
    local used=0
    local chosen
    for i=1,#candidates do
        local candidate=candidates[i]
        local col,id=Render.target(candidate.Part)
        if col~=nil and id~=nil then
            local direction=candidate.Part.Position-position
            if candidate.Distance2>.000001 then
                used+=1
                local hit=World:Raycast(position,direction*1.05,rays)
                if hit then
                    local hitCol,hitId=Render.target(hit.Instance)
                    local distance=(hit.Position-position).Magnitude
                    local key=hitCol~=nil and hitId~=nil
                        and(tostring(hitCol)..":"..tostring(hitId))
                    if key and distance>=api.MinRange and distance<=api.MaxRange
                        and(not avoided[key]or avoided[key]<now)then
                        chosen={Col=hitCol,Id=hitId,Position=hit.Position,
                            Distance=distance,Key=key}
                        break
                    end
                end
                if used>=maxRays then break end
            end
        end
    end
    api.LastSearchMs=math.floor((os.clock()-started)*1000*10+.5)/10
    api.SearchRays+=used
    return chosen
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
    api.LastReplyMs=math.floor((os.clock()-pending.At)*1000+.5)
    if count==0 then
        api.ZeroReplies+=1
        -- A zero-item response *is* a server response. Don't keep this
        -- empty target pending for 1.5s; move on to another cell immediately.
        avoided[pending.Target.Key]=os.clock()+.45
    end
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
    -- Acknowledged requests are finished regardless of item count.
    pending=nil
end)
connections[#connections+1]=player:GetAttributeChangedSignal("BagCount"):Connect(function()
    if not api.NativeHeldOwner then log("BagChanged",{Count=player:GetAttribute("BagCount")})end
end)
task.spawn(function()
        while api.Running and env.GeodeAutoPickup==api do
        local now=os.clock()
        local tryingEarly=false
        if now>=nextReadinessCheck then
            nextReadinessCheck=now+(api.FastPickup and .4 or .1)
            local traceOK,traceErr=pcall(logTransition)
            if not traceOK then setStatus("Readiness diagnostic error: "..tostring(traceErr))end
        end
        if deadline and now>=deadline then api.Stop()end
        local ok,err=pcall(function()
            if pending and now-pending.At>(pending.Timeout or (pending.Early and .8 or 1.5))then
                api.Timeouts+=1
                avoided[pending.Target.Key]=now+(api.FastPickup and .55 or 1)
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
            -- Arm once on transition into a *new* chapter Waiting phase.
            -- RunStart may update while already in Waiting; that alone must
            -- not permit additional unsuccessful early requests.
            local freshIntro=role=="Game"and phase=="Waiting"
                and (lastIntroRole~="Game" or lastIntroPhase~="Waiting"
                    or lastIntroCharacter~=player.Character)
            if freshIntro then
                earlySession=tostring(currentRun or "not-started").."|"..tostring(player.Character)
                earlyStage="idle"
                earlyStatus("Armed for current intro")
            elseif role~="Game"then
                earlyStage="idle"
            end
            lastIntroRole,lastIntroPhase,lastIntroCharacter=role,phase,player.Character
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
            api.LastCooldown=cooldown
            local target=targetFor(root)
            if not target then
                setStatus(earlyWindow and "Hidden intro: waiting for target geometry"or("No targets within "..api.MaxRange.." studs"))
                nextSend=now+(api.FastPickup and .075 or .2);return
            end
            local origin=Render.origin()
            if typeof(origin)~="Vector3"then setStatus("Waiting for mound data");return end
            local offset=target.Position-origin
            -- Native argument order is tool, column, local X, local Z, local Y, cell ID.
            nextSend=now+cooldown
            if earlyWindow and earlyStage=="idle" then
                earlyStage="pending";api.EarlyAttempts+=1
                earlyStatus("Testing one early pickup during hidden intro")
            end
            local earlyRequest=earlyWindow
            pending={At=os.clock(),Target=target,Tool=tool,Early=earlyRequest,
                Timeout=earlyRequest and .8 or (api.FastPickup and math.max(.7,cooldown*2+.3) or 1.5),
                BagBefore=tonumber(player:GetAttribute("BagCount"))or 0}
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
        -- Pickup telemetry stays in memory until explicit export.
        task.wait(api.Enabled and api.FastPickup and not api.NativeHeldOwner
            and not api.Suspended and .012 or .05)
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
    function api.Unload()unload()end
    task.spawn(function()
                while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Stop("Hatch loop error: "..tostring(err))end
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
    local api={Running=true,Enabled=false,Busy=false,FastTravel=true,Turbo=true,Stage="Idle",Status="Paused",Interval=1,Continuous=false,RepeatInterval=10,Cycles=0,Sales=0,CashGained=0,OneShotCompleted=false,LastTripSeconds=0,LastTripTeleports=0,LastTripMovesSaved=0,TotalTeleports=0,
        PromptRetries=0,LastPromptFailure="",LastFailureStage="",LastSaleConfirmed=false,
        AutoResumeBlocked=false,EndlessBossInterruptions=0,EndlessRestarts=0}
    local armedAt;local lastBag;local observedIdentity
    local deadline=0;local readyAt=0;local identity;local cracked=false;local sold=false;local saleBefore=0
    local tripStartedAt,stageStartedAt
    local retries={Deposit=0,Station=0,Sell=0};local retryAt=0
    local saleWasConfirmed=false
    local function record(kind,data)if options.Record then pcall(options.Record,kind,data)end end
    local function stage(name,status,timeout)
        local now=options.Now()
        if stageStartedAt then
            record("StageDuration",{Stage=api.Stage,Seconds=math.floor((now-stageStartedAt)*1000+.5)/1000})
        end
        api.Stage=name;api.Status=status;deadline=now+(timeout or 4)
        stageStartedAt=now
        record("Stage",{Stage=name,Status=status})
    end
    local function finish(reason)
        if api.Busy then
            local ok,err=pcall(options.Finish)
            if not ok then
                api.AutoResumeBlocked=true
                api.LastPromptFailure="Camp cleanup failed: "..tostring(err)
                record("CleanupError",{Error=tostring(err)})
            end
        end
        api.Busy=false;identity=nil;api.Stage="Idle";api.Status=reason or"Waiting for more geodes"
        armedAt=nil;stageStartedAt=nil;tripStartedAt=nil
    end
    function api.Start(managed)
        if not api.Running or api.Enabled or (managed and api.AutoResumeBlocked)then return false end
        -- Explicit user Starts clear previous failures; automatic Endless
        -- restarts cannot silently conceal a failed camp transaction.
        if not managed then api.AutoResumeBlocked=false end
        local c=options.Context();lastBag=c.BagCount;observedIdentity=c.Identity
        api.OneShotCompleted=false
        api.Enabled=true;api.PendingStopReason=nil;armedAt=nil
        api.Status=api.Continuous and "Continuous Crack & Sell armed"or"Waiting for first bag count change"
        record("Started",{Managed=managed==true,Continuous=api.Continuous,
            RepeatInterval=api.RepeatInterval,AutoResumeBlocked=api.AutoResumeBlocked})
        return true
    end
    function api.ArmExistingBag(reason)
        if not api.Enabled or api.Busy or armedAt then return false end
        local c=options.Context()
        if (c.BagCount or 0)<=0 and(c.CrateCount or 0)<=0
            and (c.BinCount or 0)<=0 and (c.BinValue or 0)<=0 then return false end
        armedAt=options.Now()
        record("ExistingInventoryArmed",{Reason=reason or"Existing inventory",Bag=c.BagCount,
            Crates=c.CrateCount,Bin=c.BinCount,WaitSeconds=api.Interval})
        return true
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
    function api.Stop(reason,allowAutoResume)
        if api.Busy and reason then api.LastFailureStage=api.Stage end
        -- A real failure or manual pause must not trigger an endless
        -- automatic restart loop. A normal boss-phase interruption may.
        if not allowAutoResume then api.AutoResumeBlocked=true end
        if allowAutoResume and api.Continuous
            and (reason=="Paused for Endless boss"
                or reason=="Cycle stopped: character or mining phase changed")then
            api.EndlessBossInterruptions+=1
        end
        api.Enabled=false;api.PendingStopReason=nil;finish(reason or"Paused")
        record("Stopped",{Reason=api.Status,FailureStage=api.LastFailureStage,
            AutoResumeBlocked=api.AutoResumeBlocked,Recoverable=allowAutoResume==true})
    end
    function api.Unload()if not api.Running then return end;api.Stop();api.Running=false end
    function api.SetFastTravel(value)
        api.FastTravel=value==true
    end
    function api.SetTurbo(value)
        api.Turbo=value==true
        record("TurboModeChanged",{Enabled=api.Turbo})
    end
    function api.SetInterval(value)
        value=tonumber(value)
        if value and value==value then api.Interval=math.clamp(value,.10,60)end
    end
    function api.SetContinuous(value)
        local enabled=value==true
        if api.Continuous==enabled then return end
        api.Continuous=enabled
        if enabled then api.PendingStopReason=nil;api.AutoResumeBlocked=false end
        if not api.Busy then armedAt=nil end
        record("ContinuousModeChanged",{Enabled=enabled,RepeatInterval=api.RepeatInterval})
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
        elseif kind=="Sold"and(api.Stage=="SellWait"or api.Stage=="SaleSettle")then sold=true end
    end
    local function hasBin(c)return c.BinCount>0 or c.BinValue>0 end
    local function approach(target)
        local ok,reason,alreadyNear=options.MoveTo(target)
        if not ok then api.Stop(reason or("Could not approach "..target));return false end
        stage(target.."Approach","Approaching "..target:lower(),4)
        readyAt=options.Now()+(alreadyNear and 0 or (api.FastTravel and (api.Turbo and .10 or .18) or .2))
        return true
    end
    local function retryInteraction(kind,reason)
        retries[kind]=(retries[kind]or 0)+1
        api.PromptRetries+=1
        api.LastPromptFailure=tostring(reason or "No server confirmation")
        record("PromptRetry",{Kind=kind,Attempt=retries[kind],Reason=api.LastPromptFailure})
        if retries[kind]>2 then
            api.Stop(kind.." prompt failed after retries: "..api.LastPromptFailure)
            return
        end
        local destination=kind=="Station"and "Station"or kind
        if approach(destination)then readyAt=math.max(readyAt,options.Now()+(api.Turbo and .18 or .25))end
    end
    local function sendPrompt(kind,fn,nextStage,nextStatus)
        -- Arm the acknowledgement stage before firing the prompt. A very fast
        -- server response must not be discarded by api.Notify as "wrong stage".
        stage(nextStage,nextStatus,4)
        retryAt=options.Now()+(api.Turbo and .95 or 1.2)
        local ok,err=pcall(fn)
        if not ok then
            retryInteraction(kind,err)
            return
        end
        record("PromptSent",{Kind=kind,Retry=retries[kind]or 0})
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
        api.LastTripSeconds=tripStartedAt and math.floor((options.Now()-tripStartedAt)*1000+.5)/1000 or 0
        api.LastSaleConfirmed=saleWasConfirmed
        record("CycleComplete",{Cycles=api.Cycles,Cash=c.Cash,TripSeconds=api.LastTripSeconds,
            Teleports=api.LastTripTeleports,SkippedMoves=api.LastTripMovesSaved})
        local stopReason=not api.Continuous and api.PendingStopReason
        finish("Cycle complete — returned to pickup position")
        if api.AutoResumeBlocked then
            api.Stop("Camp cleanup failed — repeating disabled; check diagnostics")
            return
        end
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
    local function confirmSale(c)
        api.Sales+=1
        api.CashGained+=math.max(0,c.Cash-saleBefore)
        saleWasConfirmed=true
        record("SaleConfirmed",{By=sold and "ServerSold"or"ReplicatedCash",
            CashIncrease=math.max(0,c.Cash-saleBefore)})
        completed(c)
    end
    function api.Tick()
        if not api.Running or not api.Enabled then return end
        local c=options.Context()
        if not c.Valid then
            if api.Busy then
                local safeBossTransition=c.Role=="Game"
                    and c.Mode=="Endless"and c.Phase=="Mother"
                api.Stop("Cycle stopped: character or mining phase changed",safeBossTransition)
            else api.Status="Waiting for a mining run"end
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
                api.Status=string.format("Collecting — camp visit in %.2fs",armedAt+interval-now)
                return
            end
            if c.Cracking then api.Status="Waiting for your manual station session to end";return end
            if c.BagCount<=0 and c.CrateCount<=0 and not hasBin(c)then armedAt=nil;api.Status="Waiting for geodes";return end
            if(c.BagCount>0 or c.CrateCount>0)and not c.CanCrack and not hasBin(c)then api.Status="Crack All pass or credits required";return end
            if(c.BagCount>0 or c.CrateCount>0)and not c.FreeStation then api.Status="Waiting for a free station";return end
            api.Busy=true;identity=c.Identity
            tripStartedAt=now;stageStartedAt=nil
            api.LastTripTeleports=0;api.LastTripMovesSaved=0
            retries={Deposit=0,Station=0,Sell=0};retryAt=0;saleWasConfirmed=false
            api.LastFailureStage="";api.LastPromptFailure=""
            local ok,reason=options.Begin()
            if not ok then api.Stop(reason or"Could not start cycle");return end
            record("CycleBegin",{Bag=c.BagCount,Crate=c.CrateCount,Bin=c.BinCount,Cash=c.Cash})
            if c.BagCount>0 then approach("Deposit")else proceed(c)end
            return
        end
        if now>=deadline then api.Stop("Timed out during "..api.Stage);return end
        if api.Stage=="DepositApproach"and now>=readyAt then
            if c.BagCount<=0 then stage("DepositSettle","Waiting for deposited crates",2);return end
            sendPrompt("Deposit",options.Deposit,"DepositWait","Waiting for deposit confirmation")
        elseif api.Stage=="DepositWait"then
            if c.BagCount<=0 then
                stage("DepositSettle","Waiting for deposited crates",2)
            elseif now>=retryAt then
                retryInteraction("Deposit","Bag count did not decrease")
            end
        elseif api.Stage=="DepositSettle"then
            if c.CrateCount>0 or hasBin(c)then
                proceed(c)
            elseif now>=deadline-.3 then
                api.Stop("Deposit emptied bag but no crates or sale bin appeared")
            end
        elseif api.Stage=="StationApproach"and now>=readyAt then
            if not c.CanCrack then api.Stop("Crack All pass or credits required");return end
            if c.CrateCount<=0 then
                if hasBin(c)then approach("Sell")
                else api.Stop("Crates disappeared before Crack All confirmation")end
                return
            end
            sendPrompt("Station",options.Enter,"EnterWait","Waiting for station entry")
        elseif api.Stage=="EnterWait"then
            if c.Cracking and c.StationOurs then
                if not c.CanCrack then api.Stop("Crack All entitlement changed");return end
                cracked=false;stage("CrackWait","Waiting for Crack All confirmation",8)
                options.Crack()
            elseif now>=retryAt then
                retryInteraction("Station","Station entry was not acknowledged")
            end
        elseif api.Stage=="CrackWait"then
            -- Do not leave merely because an event arrived before the crate/bin
            -- replicated; the next step depends on the sale bin really existing.
            if (cracked or c.CrateCount<=0)and hasBin(c)then
                stage("LeaveWait","Leaving station after confirmed crack",3);options.Leave()
            elseif cracked and c.CrateCount<=0 and not hasBin(c)and stageStartedAt
                and now-stageStartedAt>=1 then
                api.Stop("Crack reported success but nothing reached sale bin")
            end
        elseif api.Stage=="LeaveWait"then
            if not c.Cracking then
                if hasBin(c)then approach("Sell")
                else api.Stop("Station exited without sale bin contents")end
            end
        elseif api.Stage=="SellApproach"and now>=readyAt then
            if not hasBin(c)then
                api.Stop("Sale bin emptied before sale request was sent")
                return
            end
            saleBefore=c.Cash;sold=false
            sendPrompt("Sell",options.Sell,"SellWait","Waiting for sale confirmation")
        elseif api.Stage=="SellWait"then
            if sold or c.Cash>saleBefore then
                -- A server Sold event or replicated cash change already
                -- confirms the sale: no fixed client-side grace needed.
                confirmSale(c)
            elseif not hasBin(c)then
                -- An empty bin alone is never treated as confirmed sale.
                stage("SaleSettle","Waiting for server sale confirmation",2)
                readyAt=now+(api.Turbo and .10 or .55)
            elseif now>=retryAt then
                retryInteraction("Sell","Bin still has contents and sale was not acknowledged")
            end
        elseif api.Stage=="SaleSettle"then
            if sold or c.Cash>saleBefore then
                confirmSale(c)
            elseif now>=readyAt and not hasBin(c)then
                api.Status="Bin empty; waiting for server Sold event or cash"
            end
        end
    end
    return api
end

local function createLiveCrackSell(Pickup)
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local Bench=require(P.PlayerScripts.MTGClient.Bench)
    local State=require(P.PlayerScripts.MTGClient.State)
    local remote=MTG.Remotes:WaitForChild("Bench")
    local camp,character,identity,station,entry,deposit,sell
    local savedPose,savedCharacter,savedCamp;local enteredByUs=false;local events={};local dirty=false;local generation=0
    local api
    local wake
    local campConnections={}
    local function root()return P.Character and P.Character:FindFirstChild("HumanoidRootPart")end
    local function refresh()
        local map=workspace:FindFirstChild("CaveMap")
        local current=map and map:FindFirstChild("Camp")
        if current~=camp then
            for _,connection in ipairs(campConnections)do connection:Disconnect()end
            table.clear(campConnections)
            if current then
                for _,attribute in ipairs({"CrateCount","BinCount","BinValue"})do
                    campConnections[#campConnections+1]=current:GetAttributeChangedSignal(attribute):Connect(function()
                        if wake then wake()end
                    end)
                end
            end
        end
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
    local function safeLanding(prompt,desired)
        if near(prompt,desired)then return desired end
        local center=prompt.Parent.Position
        local vector=desired-center
        local maxRadius=math.max(0,(tonumber(prompt.MaxActivationDistance)or 0)-1.4)
        if maxRadius<.25 or vector.Magnitude<.01 then return center end
        return center+vector.Unit*math.min(maxRadius,vector.Magnitude)
    end
    local function moveTo(target)
        local r=root();if not r then return false,"Character unavailable"end
        local prompt=target=="Deposit"and deposit or(target=="Sell"and sell or entry)
        if target=="Station"and(not station or not station.Parent or(station:GetAttribute("Occupant")or 0)~=0)then
            station,entry=chooseStation();prompt=entry
        end
        if not prompt or not prompt.Parent or not prompt.Enabled then return false,target.." interaction unavailable"end
        if near(prompt,r.Position)then
            if api then api.LastTripMovesSaved+=1 end
            return true,nil,true
        end
        local combined=entry and entry.Parent and entry.Parent.Position+Vector3.new(-3.6,1.5,6)
        local point=combined and near(prompt,combined)and combined
            or safeLanding(prompt,prompt.Parent.Position+Vector3.new(-4,1.5,0))
        if api and api.FastTravel then
            -- Candidate positions are filtered through the native prompt's
            -- current activation radius, avoiding speculative long-range use.
            -- Only select the camp's existing offset landing points. Avoid
            -- teleporting to untested geometric midpoints inside stations or walls.
            local candidates={point}
            local prompts={}
            for _,other in pairs({Deposit=deposit,Station=entry,Sell=sell})do
                if other and other.Parent and other.Parent:IsA("BasePart")then
                    prompts[#prompts+1]=other
                    if other.Enabled then
                        candidates[#candidates+1]=other.Parent.Position+Vector3.new(-4,1.5,0)
                    end
                end
            end
            if combined then candidates[#candidates+1]=combined end
            local bestScore=-math.huge
            for _,candidate in ipairs(candidates)do
                if near(prompt,candidate)then
                    local coverage=0
                    for _,other in ipairs(prompts)do
                        if other.Enabled and near(other,candidate)then coverage+=1 end
                    end
                    local score=coverage*100-(candidate-r.Position).Magnitude*.1
                    if score>bestScore then point=candidate;bestScore=score end
                end
            end
        end
        if not near(prompt,point)then
            point=safeLanding(prompt,point)
        end
        if not near(prompt,point)then
            return false,target.." prompt had no reachable landing point"
        end
        r.CFrame=CFrame.new(point)*r.CFrame.Rotation
        r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
        if api then
            api.LastTripTeleports+=1
            api.TotalTeleports+=1
        end
        return true
    end
    local function trigger(prompt)
        if type(fireproximityprompt)~="function"then error("Executor prompt support unavailable")end
        local r=root()
        if not r or not prompt or not prompt.Enabled or not near(prompt,r.Position)then error("Interaction is disabled or out of range")end
        fireproximityprompt(prompt)
    end
    api=createCrackSellController({Now=os.clock,Context=function()
        refresh()
        local free=chooseStation()
        return {Valid=valid(),Identity=identity,
            Role=State.role(),Phase=State.run("Phase"),Mode=State.run("Mode"),
            BagCount=tonumber(P:GetAttribute("BagCount"))or 0,
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
    local ticking=false
    local function safeTick()
        if ticking then return end
        ticking=true
        local ok,err=pcall(api.Tick)
        ticking=false
        if not ok then
            api.LastFailureStage=api.Stage
            events[#events+1]={Kind="CycleError",WallTimeMs=DateTime.now().UnixTimestampMillis,
                Data={Stage=api.Stage,Error=tostring(err)}}
            if #events>100 then table.remove(events,1)end
            dirty=true
            api.Stop("Cycle error: "..tostring(err))
        end
    end
    local wakeScheduled=false
    wake=function()
        if not api.Running or not api.Enabled or wakeScheduled then return end
        wakeScheduled=true
        task.defer(function()
            wakeScheduled=false
            if api.Running and api.Enabled then safeTick()end
        end)
    end
    local connection=remote.OnClientEvent:Connect(function(data)
        if type(data)~="table"or not api.Busy then return end
        api.Notify(data.Type)
        local row={Type=data.Type};for k,v in pairs(data)do if type(v)=="number"or type(v)=="boolean"or type(v)=="string"then row[k]=v end end
        events[#events+1]={Kind="ServerEvent",WallTimeMs=DateTime.now().UnixTimestampMillis,Data=row}
        if #events>100 then table.remove(events,1)end;dirty=true
        wake()
    end)
    local bagConnection=P:GetAttributeChangedSignal("BagCount"):Connect(function()
        api.BagChanged(P:GetAttribute("BagCount"))
        wake()
    end)
    local cashConnection=P:GetAttributeChangedSignal("Cash"):Connect(wake)
    function api.Export()
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_crack_sell_diagnostics.json",H:JSONEncode({Version=1,Enabled=api.Enabled,Stage=api.Stage,
                Status=api.Status,Cycles=api.Cycles,Sales=api.Sales,CashGained=api.CashGained,Interval=api.Interval,Continuous=api.Continuous,RepeatInterval=api.RepeatInterval,OneShotCompleted=api.OneShotCompleted,PendingStopReason=api.PendingStopReason,FastTravel=api.FastTravel,Turbo=api.Turbo,
                PromptRetries=api.PromptRetries,LastPromptFailure=api.LastPromptFailure,LastFailureStage=api.LastFailureStage,LastSaleConfirmed=api.LastSaleConfirmed,
                AutoResumeBlocked=api.AutoResumeBlocked,EndlessBossInterruptions=api.EndlessBossInterruptions,
                EndlessRestarts=api.EndlessRestarts,CurrentRetries=retries,
                LastTripSeconds=api.LastTripSeconds,LastTripTeleports=api.LastTripTeleports,
                LastTripMovesSaved=api.LastTripMovesSaved,TotalTeleports=api.TotalTeleports,Events=events}))
        end)
        if ok then dirty=false end
        return ok,err
    end
    local unload=api.Unload
    function api.Unload()
        if not api.Running then return end
        unload()
        connection:Disconnect();bagConnection:Disconnect();cashConnection:Disconnect()
        for _,connection in ipairs(campConnections)do connection:Disconnect()end
        table.clear(campConnections)
    end
    task.spawn(function()
                while api.Running do
            safeTick()
            task.wait(api.Busy and (api.FastTravel and (api.Turbo and .012 or .02) or .03) or .1)
        end
    end)
    return api
end

local CrackSell=createLiveCrackSell(Pickup)
local function createMagnetUpgradeController(options)
    local ids={"MagPower","MagSpeed"};local cursor=1;local pending;local nextRequest=0
    local api={Running=true,Enabled=false,PowerFirst=true,FastPurchases=true,
        InFlight=false,Status="Paused",Confirmed=0,Requests=0,BusyResponses=0,
        LastRequestMs=0,LastConfirmationMs=0}
    function api.SetPowerFirst(value)api.PowerFirst=value==true end
    function api.SetFastPurchases(value)api.FastPurchases=value==true end
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
                api.Confirmed+=1
                api.LastConfirmationMs=math.floor((now-pending.SentAt)*1000+.5)
                record("Confirmed",{Id=pending.Id,Level=pending.Level,
                    ConfirmationMs=api.LastConfirmationMs})
                cursor=pending.NextCursor;pending=nil
            elseif now>=pending.Deadline then api.Stop("Upgrade confirmation timed out");return
            else api.Status="Waiting for "..pending.Id.." confirmation";return end
        end
        if now<nextRequest then return end
        if not context.Allowed then api.Status="Waiting for mining and the camp cycle to finish";return end
        if not context.Owned then api.Status="Waiting for GEO-MAG 3000 ownership";return end
        local selected,maxed=nil,0
        for offset=0,1 do
            local id=api.PowerFirst and ids[offset+1] or ids[(cursor-1+offset)%2+1]
            local def=context.Tracks[id];local level=context.Levels[id]or 0
            if def and level>=def.Max then maxed+=1
            elseif def and def.Cost and def.Cost<=context.Cash and not selected then selected={Id=id,Level=level+1,Cost=def.Cost,NextCursor=((cursor-1+offset)%2+1)%2+1}end
        end
        if maxed==2 then api.Status="Both GEO-MAG upgrades are maxed";return end
        if not selected then api.Status="Waiting for enough cash";return end
        api.InFlight=true;api.Requests+=1
        local sentAt=options.Now()
        record("Request",{Id=selected.Id,Level=selected.Level,Cost=selected.Cost,
            Fast=api.FastPurchases})
        local ok,result=pcall(options.Invoke,selected.Id)
        local responseAt=options.Now()
        api.LastRequestMs=math.floor((responseAt-sentAt)*1000+.5)
        api.InFlight=false
        -- Continue promptly after the server responds, but never overlap
        -- a purchase that is still awaiting replicated level confirmation.
        nextRequest=responseAt+(api.FastPurchases and .05 or .15)
        if not ok then record("Error",{Error=tostring(result)});api.Stop("Purchase request failed; check upgrade state before retrying");return end
        record("Response",{Id=selected.Id,Result=result,RequestMs=api.LastRequestMs})
        if type(result)~="table"then api.Stop("Unexpected upgrade response");return end
        if result.Ok then
            pending={Id=selected.Id,Level=tonumber(result.Level)or selected.Level,
                Cost=selected.Cost,NextCursor=selected.NextCursor,SentAt=responseAt,Deadline=responseAt+3}
            api.Status="Waiting for "..selected.Id.." confirmation"
        elseif result.Busy then
            api.BusyResponses+=1
            -- Honor the shop's advertised backoff, if provided.
            nextRequest=responseAt+math.max(api.FastPurchases and .25 or 1,
                tonumber(result.Wait)or 0)
            api.Status=tostring(result.Msg or"Shop busy")
        elseif result.Msg=="Not enough cash"then
            -- Re-check sooner when farming deposits cash; no extra remote
            -- request is sent until the new price is actually affordable.
            nextRequest=responseAt+math.max(api.FastPurchases and .15 or 1,
                tonumber(result.Wait)or 0)
            api.Status="Waiting for enough cash"
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
                Confirmed=api.Confirmed,PowerFirst=api.PowerFirst,FastPurchases=api.FastPurchases,
                Requests=api.Requests,BusyResponses=api.BusyResponses,
                LastRequestMs=api.LastRequestMs,LastConfirmationMs=api.LastConfirmationMs,
                RequestedGapSeconds=api.FastPurchases and .05 or .15,
                PollIntervalSeconds=api.FastPurchases and .025 or .1,
                Levels=State.ctx().Upg,Cash=P:GetAttribute("Cash"),Events=events}))
        end)
        if ok then dirty=false end;return ok,err
    end
    local unload=api.Unload
    function api.Unload()unload()end
    task.spawn(function()
                while api.Running do
            local ok,err=pcall(function()
                if CrackSell.Enabled and not CrackSell.Continuous and api.IsMaxed()then
                    CrackSell.RequestStopAfterSale("Both GEO-MAG upgrades are maxed — final collection complete")
                end
                api.Tick()
            end)
            if not ok then api.Stop("Upgrade loop error: "..tostring(err))end
            task.wait(api.Enabled and api.FastPurchases and .025 or .1)
        end
    end)
    return api
end

local MagnetUpgrades=createLiveMagnetUpgrades(CrackSell)
local function createEscapeController(options)
    -- One optimized escape path. Only enter the actual native lift after
    -- LiftOpen replicates; speculative pre-opening movement is unsafe.
    local api={Running=true,Enabled=false,InEscape=false,Status="Paused",Attempts=0,
        StageMoves=0,GateOpens=0,Failures=0,LastError="",
        EscapeStartedAt=0,GateOpenedAt=0,ConfirmedSeconds=0,LastEnterAt=0,FirstEnterDelay=0,
        LastDistance=0,LastStageDistance=0,LastGateOpen=false,EndedDuringEscape=false}
    local identity,run
    local nextMove=0;local lastEnter=0
    local gateSeen=false
    local function record(kind,data)
        if options.Record then pcall(options.Record,kind,data)end
    end
    function api.Start()
        if not api.Running then return end
        api.Enabled=true;api.Status="Waiting for Escape phase"
    end
    function api.Stop()
        api.Enabled=false;api.Status="Paused"
        identity=nil;run=nil;gateSeen=false
        api.Attempts=0;nextMove=0;lastEnter=0;api.InEscape=false
    end
    function api.Unload()api.Stop();api.Running=false end
    function api.Tick()
        if not api.Running or not api.Enabled then return end
        local c=options.Context()
        local now=options.Now()
        api.InEscape=c.InEscape==true
        api.LastDistance=c.Distance
        api.LastStageDistance=c.StageDistance
        api.LastGateOpen=c.LiftOpen==true
        api.EndedDuringEscape=c.Ended==true and c.InEscape==true
        if identity~=c.Identity or run~=c.Run then
            identity=c.Identity;run=c.Run
            gateSeen=false;nextMove=0;lastEnter=0
            api.Attempts=0;api.StageMoves=0;api.EscapeStartedAt=0;api.GateOpenedAt=0
            api.ConfirmedSeconds=0;api.LastEnterAt=0;api.FirstEnterDelay=0
            record("RunReset",{Run=tostring(run)})
        end
        if c.Escaped then
            if api.Status~="Escape confirmed by server"then
                api.ConfirmedSeconds=api.GateOpenedAt>0 and now-api.GateOpenedAt or 0
                record("Escaped",{GateToConfirmationSeconds=api.ConfirmedSeconds,
                    EnterAttempts=api.Attempts,StagingMoves=api.StageMoves})
            end
            api.Status="Escape confirmed by server"
            return
        end
        -- Some game versions flag the round as Ended during the Escape
        -- transition. That alone must not suppress entry to an open lift.
        if c.Ended and not c.InEscape then api.Status="Round ended";return end
        if not c.Alive then api.Status="Waiting for a living character";return end
        if not c.InEscape then
            api.Status="Waiting for Escape phase"
            return
        end
        if api.EscapeStartedAt==0 then
            api.EscapeStartedAt=now
            record("EscapePhase",{LiftOpen=c.LiftOpen,ExitFound=c.ExitFound})
        end
        if not c.ExitFound then
            api.Status="Waiting for the lift geometry";return
        end
        if not c.Ready then
            if gateSeen then
                gateSeen=false;lastEnter=0;nextMove=0
                record("LiftClosedAgain",{LiftOpen=c.LiftOpen})
            end
            -- Don't move until the replicated gate opens. This is the
            -- reliable path; no external or guessed staging position.
            api.Status="Waiting for the server to open the lift"
            return
        end
        if not gateSeen then
            gateSeen=true;api.GateOpens+=1;api.GateOpenedAt=now;lastEnter=0;nextMove=0;api.FirstEnterDelay=0
            record("LiftOpened",{Distance=c.Distance,
                TimeSinceEscapePhase=now-api.EscapeStartedAt})
        end
        if now<nextMove then return end
        -- Preserve time for the first legitimate entry to register, then
        -- retry a little sooner if confirmation never arrives. After several
        -- misses, slow down rather than continually resetting the character.
        local grace=api.Attempts<=1 and .50 or (api.Attempts<10 and .40 or .90)
        if lastEnter>0 and c.Distance<=4 and now-lastEnter<grace then
            api.Status="Inside open lift; awaiting server escape confirmation"
            return
        end
        local maxAttempts=20
        if api.Attempts>=maxAttempts then
            api.Status="Lift entry not confirmed after "..tostring(maxAttempts).." attempts"
            return
        end
        if api.Attempts>=10 and lastEnter>0 and now-lastEnter<.90 then
            api.Status="Lift entry recovery — waiting for server confirmation"
            return
        end
        local ok,err=pcall(options.Move,"Enter")
        nextMove=now+.06
        if not ok then
            api.Failures+=1;api.LastError=tostring(err)
            api.Status="Lift entry failed: "..api.LastError
            record("EnterFailed",{Error=api.LastError})
            return
        end
        if api.Attempts==0 then api.FirstEnterDelay=now-api.GateOpenedAt end
        api.Attempts+=1;lastEnter=now;api.LastEnterAt=now
        api.Status="Lift entry movement sent; waiting for server confirmation"
        record("EnterLift",{Attempt=api.Attempts,
            DistanceBefore=c.Distance,TimeSinceGateOpened=now-api.GateOpenedAt})
    end
    return api
end

local function createLiveEscape(CrackSell)
    local player=game:GetService("Players").LocalPlayer
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local State=require(player.PlayerScripts.MTGClient.State)
    local Http=game:GetService("HttpService")
    local events={}
    local connections={}
    local function record(kind,data)
        events[#events+1]={AtMs=DateTime.now().UnixTimestampMillis,Kind=kind,Data=data}
        if #events>100 then table.remove(events,1)end
    end
    local function destination(root,humanoid,kind)
        local map=workspace:FindFirstChild("CaveMap")
        local lift=map and map:FindFirstChild("Lift")
        local floor=lift and lift:FindFirstChild("Floor")
        local inside=lift and lift:FindFirstChild("Inside")
        local base=floor and floor:IsA("BasePart")and floor or inside
        if not base or not base:IsA("BasePart")then return nil end
        local clearance=humanoid and humanoid.HipHeight+(root and root.Size.Y/2 or 1)or 3
        local center=base.CFrame:PointToWorldSpace(Vector3.new(0,
            (base==floor and base.Size.Y/2 or 0)+clearance,0))
        return center
    end
    -- Passive elevator timer / movement-lock recorder. Never edits state,
    -- UI text, collision, humanoid properties, or server countdown values.
    local timerSamples,timerChanges={},{}
    local timerStateKeys,timerLiftKeys={},{}
    local timerRun,timerTracking,timerCompletedRun=nil,false,nil
    local timerSawEscapePhase=false
    local timerCapturedAt,timerSavedAt,timerStartedAt=0,0,0
    local timerGuiAt,timerPartsAt=0,0
    local timerGui,timerParts={},{}
    local lastTimerSignature=nil
    local lastPosition=nil
    local function positionData(point)
        if not point then return nil end
        local function round(n)return math.floor(n*100+.5)/100 end
        return {X=round(point.X),Y=round(point.Y),Z=round(point.Z)}
    end
    local function relevantAttributes(instance)
        local result={}
        if not instance then return result end
        local ok,attributes=pcall(function()return instance:GetAttributes()end)
        if not ok or type(attributes)~="table"then return result end
        local found=0
        for name,value in pairs(attributes)do
            local lower=type(name)=="string"and name:lower()or""
            if lower:find("time",1,true)or lower:find("count",1,true)
                or lower:find("lock",1,true)or lower:find("wait",1,true)
                or lower:find("lift",1,true)or lower:find("elev",1,true)
                or lower:find("escap",1,true)or lower:find("door",1,true)
                or lower:find("open",1,true)or lower:find("freez",1,true)
                or lower:find("ready",1,true)or lower:find("end",1,true)
                or lower:find("phase",1,true)then
                local kind=type(value)
                if kind=="boolean"or kind=="number"then
                    result[name]=value;found+=1
                elseif kind=="string"then
                    result[name]=value:sub(1,80);found+=1
                end
            end
            if found>=40 then break end
        end
        return result
    end
    local function attributeNames(instance)
        local names={}
        if not instance then return names end
        local ok,attributes=pcall(function()return instance:GetAttributes()end)
        if ok and type(attributes)=="table"then
            for name in pairs(attributes)do
                if type(name)=="string"and #names<120 then names[#names+1]=name end
            end
        end
        table.sort(names)
        return names
    end
    local function visibleTimerTexts()
        local texts={}
        local gui=player:FindFirstChild("PlayerGui")
        local map=workspace:FindFirstChild("CaveMap")
        local lift=map and map:FindFirstChild("Lift")
        -- Some countdowns live in PlayerGui; others are SurfaceGuis on lift parts.
        local sources={}
        if gui then sources[#sources+1]=gui end
        if lift then sources[#sources+1]=lift end
        for _,source in ipairs(sources)do
            if source then
                local inspected=0
                for _,object in ipairs(source:GetDescendants())do
                    inspected+=1
                    if inspected>2200 or #texts>=20 then break end
                    if (object:IsA("TextLabel")or object:IsA("TextButton"))
                        and object.Visible and not object:FindFirstAncestor("GeodeNativeHub")then
                        local current=object.Parent;local shown=true
                        while current and current~=source do
                            if current:IsA("ScreenGui")and not current.Enabled then shown=false;break end
                            if current:IsA("GuiObject")and not current.Visible then shown=false;break end
                            current=current.Parent
                        end
                        if shown then
                            local value=tostring(object.Text or""):gsub("%s+"," "):sub(1,120)
                            local lower=value:lower()
                            local path=object:GetFullName():sub(-150)
                            local pathLower=path:lower()
                            if #value>0 and
                                (lower:find("elev",1,true)or lower:find("lift",1,true)
                                    or lower:find("escape",1,true)
                                    or lower:find("countdown",1,true)
                                    or lower:find("unlock",1,true)
                                    or lower:find("wait",1,true)
                                    or lower:find("remaining",1,true)
                                    or lower:find("second",1,true)
                                    or value:match("^%s*%d+:%d%d%s*$")
                                    or value:match("^%s*%d+%.?%d*%s*[sS]%s*$")
                                    or (value:match("^%s*%d+%.?%d*%s*$")
                                        and (pathLower:find("timer",1,true)
                                            or pathLower:find("count",1,true)
                                            or pathLower:find("escape",1,true)
                                            or pathLower:find("lift",1,true))))then
                                texts[#texts+1]={Text=value,Path=path}
                            end
                        end
                    end
                end
            end
        end
        return texts
    end
    local function liftPartStates(lift)
        local result={}
        if not lift then return result end
        local inspected=0
        for _,part in ipairs(lift:GetDescendants())do
            inspected+=1
            if inspected>750 or #result>=16 then break end
            if part:IsA("BasePart")then
                local name=part.Name:lower()
                if name:find("door",1,true)or name:find("gate",1,true)
                    or name:find("floor",1,true)or name:find("inside",1,true)
                    or name:find("lock",1,true)or name:find("wall",1,true)then
                    result[#result+1]={Path=part:GetFullName():sub(-130),
                        Anchored=part.Anchored,CanCollide=part.CanCollide,
                        Transparency=part.Transparency,Attributes=relevantAttributes(part)}
                end
            end
        end
        return result
    end
    local function captureElevatorTimer(api,force)
        local now=os.clock()
        local role,phase=State.role(),State.run("Phase","")
        local escaped=player:GetAttribute("Escaped")==true
        local run=tostring(State.run("RunStart",""))
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local liftPosition=destination(root,humanoid,"Enter")
        local nearLift=root and liftPosition and
            (root.Position-liftPosition).Magnitude<=12
        local liftOpen=State.run("LiftOpen",false)==true
        -- A newly added lock may begin before the Phase changes to Escape.
        local inEscape=role=="Game"and
            (phase=="Escape"or (State.run("Mode","")~="Endless"
                and (phase=="Waiting"or phase=="Mother")and nearLift
                and (liftOpen or root.Anchored or
                    (humanoid and humanoid.WalkSpeed<=.01))))
        if not inEscape and not timerTracking and not force then return false end
        if timerCompletedRun==run and not force then return false end
        if force and not timerTracking and timerRun~=run then
            timerSamples={};timerChanges={}
            timerStateKeys={};timerLiftKeys={}
            timerRun=run;timerStartedAt=now;timerCapturedAt=0
            timerGuiAt=0;timerPartsAt=0;timerGui={};timerParts={}
            lastTimerSignature=nil;lastPosition=nil;timerSawEscapePhase=false
        end
        if inEscape and not timerTracking and not force then
            timerSamples={};timerChanges={}
            timerStateKeys={};timerLiftKeys={}
            timerRun=run;timerTracking=true;timerStartedAt=now
            timerCapturedAt=0;timerSavedAt=0;timerGuiAt=0;timerPartsAt=0
            timerGui={};timerParts={};lastTimerSignature=nil;lastPosition=nil
            timerSawEscapePhase=false
            record("ElevatorTimerCaptureStarted",{Run=run})
        end
        if not force and now-timerCapturedAt<.25 then return false end
        timerCapturedAt=now
        if phase=="Escape"then timerSawEscapePhase=true end
        local map=workspace:FindFirstChild("CaveMap")
        local lift=map and map:FindFirstChild("Lift")
        local state=MTG:FindFirstChild("State")
        if #timerStateKeys==0 then timerStateKeys=attributeNames(state)end
        if #timerLiftKeys==0 then timerLiftKeys=attributeNames(lift)end
        if now-timerGuiAt>=.65 or force then
            timerGui=visibleTimerTexts();timerGuiAt=now
        end
        if now-timerPartsAt>=.85 or force then
            timerParts=liftPartStates(lift);timerPartsAt=now
        end
        local point=root and root.Position
        local exit=destination(root,humanoid,"Enter")
        local movement=point and lastPosition and(point-lastPosition).Magnitude or 0
        lastPosition=point
        local attributes={
            State=relevantAttributes(state),MTG=relevantAttributes(MTG),
            Player=relevantAttributes(player),Character=relevantAttributes(character),
            Root=relevantAttributes(root),Humanoid=relevantAttributes(humanoid),
            Lift=relevantAttributes(lift)}
        local sample={
            WallMs=DateTime.now().UnixTimestampMillis,
            ServerTime=workspace:GetServerTimeNow(),
            Elapsed=math.floor((now-timerStartedAt)*1000+.5)/1000,
            Role=role,Phase=phase,Run=run,
            LiftOpen=State.run("LiftOpen",false)==true,
            Ended=State.run("Ended",false)==true,
            Escaped=escaped,AutoEscapeEnabled=api.Enabled,
            AutoEscapeStatus=api.Status,EntryAttempts=api.Attempts,
            SecondsSinceLastEntry=api.LastEnterAt>0 and now-api.LastEnterAt or nil,
            DistanceToLift=point and exit and(point-exit).Magnitude or nil,
            RootPosition=positionData(point),MovementSinceSample=movement,
            RootAnchored=root and root.Anchored or false,
            RootLinearSpeed=root and root.AssemblyLinearVelocity.Magnitude or nil,
            RootCanCollide=root and root.CanCollide or nil,
            WalkSpeed=humanoid and humanoid.WalkSpeed or nil,
            JumpPower=humanoid and humanoid.JumpPower or nil,
            PlatformStand=humanoid and humanoid.PlatformStand or nil,
            Sit=humanoid and humanoid.Sit or nil,
            MoveDirection=humanoid and humanoid.MoveDirection.Magnitude or nil,
            Attributes=attributes,VisibleCountdown=timerGui,
            LiftParts=now-timerPartsAt<.3 and timerParts or nil
        }
        timerSamples[#timerSamples+1]=sample
        if #timerSamples>620 then table.remove(timerSamples,31)end
        -- Record changes to visible timer, server flags and movement lock
        -- separately from periodic samples, retaining the earliest changes.
        local signature=Http:JSONEncode({Phase=phase,LiftOpen=sample.LiftOpen,
            Escaped=escaped,Anchored=sample.RootAnchored,
            PlatformStand=sample.PlatformStand,Attributes=attributes,
            VisibleCountdown=timerGui})
        if signature~=lastTimerSignature then
            timerChanges[#timerChanges+1]={WallMs=sample.WallMs,
                Elapsed=sample.Elapsed,Phase=phase,LiftOpen=sample.LiftOpen,
                RootAnchored=sample.RootAnchored,Attributes=attributes,
                VisibleCountdown=timerGui}
            if #timerChanges>180 then table.remove(timerChanges,2)end
            lastTimerSignature=signature
        end
        if timerTracking and (escaped or not inEscape)then
            timerTracking=false
            -- A tentative pre-Escape lock disappearing must not prevent
            -- recording the actual Escape phase later in this same round.
            if escaped or timerSawEscapePhase then timerCompletedRun=run end
            record("ElevatorTimerCaptureFinished",{Run=run,Escaped=escaped,
                Elapsed=now-timerStartedAt,Samples=#timerSamples})
            return true
        end
        return false
    end
    local api=createEscapeController({Now=os.clock,Context=function()
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local exit=destination(root,humanoid,"Enter")
        local role,phase,mode=State.role(),State.run("Phase",""),State.run("Mode","")
        local inEscape=role=="Game"and mode~="Endless"and phase=="Escape"
        local liftOpen=State.run("LiftOpen",false)==true
        return {Identity=character,Run=State.run("RunStart",""),
            InEscape=inEscape,LiftOpen=liftOpen,ExitFound=exit~=nil,
            Ready=exit~=nil and inEscape and liftOpen,
            Escaped=player:GetAttribute("Escaped")==true,Ended=State.run("Ended",false)==true,
            Alive=root~=nil and humanoid~=nil and humanoid.Health>0,
            Distance=root and exit and(root.Position-exit).Magnitude or math.huge,
            StageDistance=0}
    end,Move=function(kind)
        if CrackSell.Enabled or CrackSell.Busy then CrackSell.Stop("Stopped for auto escape")end
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        assert(root,"Character root unavailable")
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        local exit=assert(destination(root,humanoid,kind),"Current map lift unavailable")
        local before=root.Position
        root.CFrame=CFrame.new(exit)*root.CFrame.Rotation
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        record("ElevatorEntryMovement",{From=positionData(before),
            Intended=positionData(exit),After=positionData(root.Position),
            RootAnchored=root.Anchored})
    end,Record=record})
    function api.Export()
        -- Manual exports also collect the current lift state, even when an
        -- update uses a new phase name or the escape automation is disabled.
        local sampled,err=pcall(captureElevatorTimer,api,true)
        if not sampled then record("ElevatorTimerSampleError",{Error=tostring(err)})end
        return pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_escape_diagnostics.json",Http:JSONEncode({
                Version=2,Enabled=api.Enabled,Mode="Optimized",
                Status=api.Status,Attempts=api.Attempts,StageMoves=api.StageMoves,
                GateOpens=api.GateOpens,Failures=api.Failures,LastError=api.LastError,
                InEscape=api.InEscape,EndedDuringEscape=api.EndedDuringEscape,
                LastDistance=api.LastDistance,LastStageDistance=api.LastStageDistance,
                LastGateOpen=api.LastGateOpen,
                EscapeStartedAt=api.EscapeStartedAt,GateOpenedAt=api.GateOpenedAt,
                FirstEnterDelay=api.FirstEnterDelay,
                ConfirmedSeconds=api.ConfirmedSeconds,
                Run=tostring(State.run("RunStart","")),
                Phase=State.run("Phase",""),LiftOpen=State.run("LiftOpen",false),
                Escaped=player:GetAttribute("Escaped")==true,Events=events,
                ElevatorTimerReport="Geode/elevator_lock_diagnostics.json",
                Note="Manual lift export captures the current UI/lift snapshot only. No passive countdown recorder is active. Server LiftOpen and Escaped remain authoritative."
            }))
            writefile("Geode/elevator_lock_diagnostics.json",Http:JSONEncode({
                Version=2,Build=geodeVersion,Mode="Manual lift snapshot (no passive recording)",
                Run=timerRun,Tracking=timerTracking,LastFinishedRun=timerCompletedRun,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                LastStatus=api.Status,AutoEscapeEnabled=api.Enabled,
                CurrentPhase=State.run("Phase",""),
                CurrentLiftOpen=State.run("LiftOpen",false),
                ServerEscaped=player:GetAttribute("Escaped")==true,
                ObservedStateAttributeNames=timerStateKeys,
                ObservedLiftAttributeNames=timerLiftKeys,
                Samples=timerSamples,Changes=timerChanges,
                Notes="Captured only when Export Debug Diagnostics selects Escape / Elevator. Includes a current snapshot, not a history of earlier lift countdowns. Does not change timers, collisions, or server state."
            }))
        end)
    end
    local pending=false
    local function wake()
        if pending or not api.Running or not api.Enabled then return end
        pending=true
        task.defer(function()
            pending=false
            if api.Running and api.Enabled then
                local ok,err=pcall(api.Tick)
                if not ok then record("Error",{Error=tostring(err)}) end
            end
        end)
    end
    -- Enabling Auto Escape during an already-open lift starts a check right
    -- away instead of waiting for the next periodic pass.
    local nativeStart=api.Start
    function api.Start()
        nativeStart()
        wake()
    end
    local state=MTG:FindFirstChild("State")
    if state then
        for _,attr in ipairs({"Phase","LiftOpen","RunStart","Ended"})do
            connections[#connections+1]=state:GetAttributeChangedSignal(attr):Connect(wake)
        end
    end
    connections[#connections+1]=MTG:GetAttributeChangedSignal("Role"):Connect(wake)
    connections[#connections+1]=player:GetAttributeChangedSignal("Escaped"):Connect(wake)
    connections[#connections+1]=player.CharacterAdded:Connect(wake)
    local unload=api.Unload
    function api.Unload()
        if not api.Running then return end
        unload()
        for _,connection in ipairs(connections)do connection:Disconnect()end
    end
    -- No passive HUD countdown scanning or automatic diagnostic writes.
    -- The normal fast escape controller continues to run unchanged;
    -- a manual Escape debug export captures the current lift snapshot.
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then
                api.Status="Escape check error: "..tostring(err)
                record("Error",{Error=tostring(err)})
            end
            task.wait(api.Enabled and (api.InEscape and .03 or .12) or .25)
        end
    end)
    return api
end

local Escape=createLiveEscape(CrackSell)
-- Anti-idle is independent of the active game role, character and UI.
-- It does not modify movement, tools, camera CFrame, game remotes or AFK flags.
local function createAntiIdleController()
    local Players=game:GetService("Players")
    local Input=game:GetService("UserInputService")
    local Http=game:GetService("HttpService")
    local player=Players.LocalPlayer
    local okVU,virtualUser=pcall(function()return game:GetService("VirtualUser")end)
    local api={Running=true,Enabled=true,Status="Armed in lobby and all rounds",
        Attempts=0,Successes=0,Failures=0,LastSource="None",LastAtMs=0,LastError=nil}
    local connections={}
    local lastHumanInput=os.clock()
    local lastAttempt=os.clock()
    local busy=false
    local function noteInput()
        if api.Running then lastHumanInput=os.clock()end
    end
    local function perform(source)
        if not api.Running or not api.Enabled or busy then return end
        busy=true
        lastAttempt=os.clock()
        api.Attempts+=1
        api.LastSource=source
        local ok,err=pcall(function()
            assert(okVU and virtualUser,"VirtualUser unavailable in this executor")
            local camera=workspace.CurrentCamera
            local cameraFrame=camera and camera.CFrame or CFrame.new()
            virtualUser:CaptureController()
            virtualUser:Button2Down(Vector2.zero,cameraFrame)
            task.wait(.06)
            virtualUser:Button2Up(Vector2.zero,cameraFrame)
        end)
        api.LastAtMs=DateTime.now().UnixTimestampMillis
        if ok then
            api.Successes+=1
            api.LastError=nil
            api.Status="Anti-idle input sent ("..source..")"
        else
            api.Failures+=1
            api.LastError=tostring(err)
            api.Status="Anti-idle input failed: "..api.LastError
            warn("[Geode Anti AFK] "..api.LastError)
        end
        busy=false
    end
    -- The engine's own idle event is the primary trigger.
    connections[#connections+1]=player.Idled:Connect(function()
        if api.Running and api.Enabled then task.spawn(perform,"Player.Idled")end
    end)
    -- Observe genuine user activity so that periodic recovery touches do not
    -- interfere while the user is playing or navigating the game menu.
    connections[#connections+1]=Input.InputBegan:Connect(noteInput)
    connections[#connections+1]=Input.InputChanged:Connect(noteInput)
    -- Some executor/window states can miss the Idled signal; periodic fallback
    -- only sends a keepalive after 90 seconds with no user input.
    task.spawn(function()
        while api.Running do
            if api.Enabled and os.clock()-lastHumanInput>=90
                and os.clock()-lastAttempt>=75 then
                perform("idle watchdog")
            end
            task.wait(15)
        end
    end)
    function api.SetEnabled(value)
        api.Enabled=value==true
        if api.Enabled then
            api.Status="Armed in lobby and all rounds"
            lastAttempt=os.clock()
        else
            api.Status="Disabled"
        end
    end
    function api.Export()
        local ok,err=pcall(function()
            assert(type(writefile)=="function","File export unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"and not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/anti_afk_diagnostics.json",Http:JSONEncode({
                Enabled=api.Enabled,Running=api.Running,Status=api.Status,
                Attempts=api.Attempts,Successes=api.Successes,Failures=api.Failures,
                LastSource=api.LastSource,LastAtMs=api.LastAtMs,LastError=api.LastError,
                SecondsSinceUserInput=math.floor(os.clock()-lastHumanInput),
                Note="Attempts virtual idle input only. Cannot prevent network failures, server shutdowns, moderation kicks, or executor suspensions."
            }))
        end)
        return ok,err
    end
    function api.Unload()
        if not api.Running then return end
        api.Running=false;api.Enabled=false;api.Status="Unloaded"
        for _,connection in ipairs(connections)do connection:Disconnect()end
    end
    return api
end

local AntiAFK=createAntiIdleController()
-- Independently enforces 4x native walking speed during live game play.
-- Baselines are captured per Humanoid and refreshed when game code changes
-- WalkSpeed; our own modified value is never multiplied a second time.
local function createGameWalkSpeedController()
    local P=game:GetService("Players").LocalPlayer
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local api={Running=true,Enabled=true,Multiplier=4,Status="Waiting for game",Base=0,Applied=0}
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
                    -- value as the baseline rather than multiplying our 4x again.
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
    local api={Running=true,Enabled=false,EscapeFarm=false,BossAssist=true,RapidBoss=false,RapidBossInterval=0.05,RapidBossPulses=0,Stage="Paused",Status="Paused",Hover=6.5,Laps=0,Hits=0,WeakHits=0}
    function api.SetEscapeFarm(value)
        local enabled=value==true
        if api.EscapeFarm==enabled then return end
        api.EscapeFarm=enabled
        if not enabled and not api.Enabled then
            options.Release()
            api.Stage="Paused";api.Status="Paused"
        end
    end
    function api.SetRapidBoss(value)api.RapidBoss=value==true end
    function api.SetRapidBossInterval(value)
        value=tonumber(value)
        if value and value==value then api.RapidBossInterval=math.clamp(value,.05,.25)end
    end
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
        local normalSweep=not api.Enabled and api.EscapeFarm and c.Role=="Game"
            and c.Mode~="Endless" and c.Phase=="Mining" and not c.Ended and c.Alive and c.Owned
        local bossOnly=not api.Enabled and (api.BossAssist or api.EscapeFarm) and c.Role=="Game"
            and c.Phase=="Mother" and c.HP>0 and not c.Ended and c.Alive and c.Owned
        if not api.Enabled and not bossOnly and not normalSweep then
            -- Release orbit/camera ownership immediately on Escape/results.
            -- Otherwise the former Mining target would keep moving the player
            -- back to the pile and fight Auto Escape's lift movement.
            if api.Stage=="Boss"or api.Stage=="Mining"or api.Stage=="Camp"then
                options.Release();api.Stage="Paused";api.Status="Waiting for next combat phase"
            end
            return
        end
        if normalSweep then
            if c.CampBusy then
                options.Release();api.Stage="Camp";api.Status="Auto escapes: camp visit"
            else
                api.Stage="Mining";api.Status="Auto escapes: sweeping geodes"
                options.Update(api,c)
            end
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
            if not managed or managedRun~=c.Run or(c.Phase=="Mining"and previousPhase~="Mining")then
                options.Manage();managed=true;managedRun=c.Run
            end
            -- Keep Cracking & Selling can be enabled after a prior one-shot
            -- sale or during an Endless depth. Re-arm it in active Mining,
            -- not during a boss or while another camp visit owns movement.
            if c.Phase=="Mining"and not c.CampBusy then options.SyncCrackSell(c)end
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
        api.Requests+=1;record("AbilityRequested",{Skill=c.SkillId,Cooldown=c.Stats.Cooldown,
            Phase=c.Phase,Mode=c.Mode,MotherHP=c.MotherHP,ReadyAt=c.ReadyAt})
        local ok,err=pcall(options.Activate)
        if not ok then pending=nil;retryAt=now+5;api.Status="Ability error: "..tostring(err);record("AbilityError",tostring(err))
        else api.Status="Waiting for Overcharge confirmation"end
    end
    return api
end

-- Boss-first skill policy: avoid consuming Overcharge during mining
-- while waiting for the Mother encounter.
local abilityPrefs={NormalMining=true,BossOnSpawn=true,ReserveForBoss=true,EscapeFarmAlways=true}
local function createLiveEndless(Pickup,CrackSell,MagnetUpgrades,prefs)
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
    local plan,planDepth,planRun,profileCenter,pendingBand;local nextPlan=0;local angle=0;local band=1
    -- Shared 10x mining rotation for Auto Endless and Auto Farm Escapes.
    -- The native GEO-MAG, bottom-ring geometry and boss targeting are
    -- unchanged. Camera responsiveness scales with the current rotation.
    local orbitSpeedMultiplier=10
    local orbitLapSeconds=14/orbitSpeedMultiplier
    local orbitRadiansPerSecond=(math.pi*2)/orbitLapSeconds
    -- Mode-specific camera pitches are independent of the farming heights.
    -- Current debugged angles are 14 degrees Win Farm and 9 Endless.
    local endlessMiningPitchDegrees=9
    local winFarmMiningPitchDegrees=14
    local winInnerSpeed=orbitSpeedMultiplier*.8
    local winMaximumSpeed=orbitSpeedMultiplier*1.2
    -- Auto Win Farm sweeps the outer ring at both existing heights,
    -- then moves close to the boss center for the leftover pillar.
    -- This third pass is a smaller RADIUS, not another high exterior ring.
    local winSecondRingRise=2
    local winCoreSpeed=orbitSpeedMultiplier*.8
    local winSweep={Run=nil,Mode="Outer",Speed=orbitSpeedMultiplier,RadiusScale=1,
        WindowAt=0,WindowItems=0,WindowShots=0,LastAcceptedAt=0,
        LastSwitchAt=0,Rate=0,Accepted=0,Shots=0,Active=false,InnerPasses=0,
        HeightRing=1,CompletedLaps=0,RingLaps={0,0,0},RingItems={0,0,0},
        CoreRadius=0,CoreRise=0,CorePasses=0,OuterSpeed=orbitSpeedMultiplier,
        -- The orbit angle only advances once GEO-MAG is held/ready.
        FireReady=false,ReadySince=0,ReadyShotBase=0,FirstFireWaitMs=nil,
        PausedBeforeReady=0,PassStartAt=0,PassStartItems=0,PassStartShots=0,
        EarlyCoreSkips=0,PassStats={}}
    local function winCoreGeometry()
        -- The generated mound plan uses the boss/body XZ as its axis.
        -- Pull the native magnet within 3-12 studs of the central pillar.
        -- Vertical rise is based on the mound height, not an arbitrary
        -- teleport to the top (and uses the same working lowest ring).
        local base=plan and plan.Bands and plan.Bands[1]
        if not base then return 8,8 end
        local outerRadius=base.Radius+1.5
        local radius=math.max(3,math.min(12,outerRadius-3,outerRadius*.35))
        local height=math.max(0,(plan.Top or base.Y)-base.Y)
        local rise=math.clamp(height*.38,4,20)
        return radius,rise
    end
    local function winPassGeometry()
        if winSweep.HeightRing==3 then
            local radius,rise=winCoreGeometry()
            winSweep.CoreRadius=radius;winSweep.CoreRise=rise
            return radius,rise
        end
        local b=plan.Bands[1]
        return b.Radius*winSweep.RadiusScale+1.5,
            (winSweep.HeightRing-1)*winSecondRingRise
    end
    local function preserveWinSweep(reason)
        if not winSweep.Run then return end
        local items=table.clone(winSweep.RingItems)
        if winSweep.CompletedLaps==0 and (items[1]or 0)+(items[2]or 0)+(items[3]or 0)==0 then return end
        api.LastWinSweep={
            Run=winSweep.Run,Reason=reason,CapturedAtMs=DateTime.now().UnixTimestampMillis,
            CompletedLaps=winSweep.CompletedLaps,RingLaps=table.clone(winSweep.RingLaps),
            RingItems=items,CoreConfirmedItems=items[3]or 0,
            OuterBaseConfirmedItems=items[1]or 0,OuterRaisedConfirmedItems=items[2]or 0,
            CorePasses=winSweep.CorePasses,CoreRadiusStuds=winSweep.CoreRadius,
            CoreRiseStuds=winSweep.CoreRise,LastPass=api.WinSweepCoveragePass,
            EarlyCoreSkips=winSweep.EarlyCoreSkips,FirstFireWaitMs=winSweep.FirstFireWaitMs,
            PassStats=table.clone(winSweep.PassStats),
            FinalBagCount=P:GetAttribute("BagCount"),NativeItemsTotal=api.NativeItems,
            TotalItemsCounted=(items[1]or 0)+(items[2]or 0)+(items[3]or 0)
        }
    end
    local function resetWinSweep(run)
        if winSweep.Run and winSweep.Run~=tostring(run)then
            preserveWinSweep("New mining run")
        end
        local now=os.clock()
        winSweep.Run=tostring(run);winSweep.Mode="Outer";winSweep.Speed=orbitSpeedMultiplier
        winSweep.HeightRing=1;winSweep.CompletedLaps=0
        winSweep.RingLaps={0,0,0};winSweep.RingItems={0,0,0}
        winSweep.CoreRadius=0;winSweep.CoreRise=0;winSweep.CorePasses=0
        winSweep.OuterSpeed=orbitSpeedMultiplier
        winSweep.FireReady=false;winSweep.ReadySince=0;winSweep.ReadyShotBase=0
        winSweep.FirstFireWaitMs=nil;winSweep.PausedBeforeReady=0
        winSweep.PassStartAt=0;winSweep.PassStartItems=0
        winSweep.PassStartShots=0;winSweep.EarlyCoreSkips=0;winSweep.PassStats={}
        -- Always complete a genuine first full lap on the base ring,
        -- including after replay or when entering the farm mid-run.
        angle=0
        winSweep.RadiusScale=1;winSweep.WindowAt=now
        winSweep.WindowItems=api.NativeItems or 0
        winSweep.WindowShots=api.NativeFireEvents or 0
        winSweep.LastAcceptedAt=now;winSweep.LastSwitchAt=now
        winSweep.Rate=0;winSweep.Accepted=0;winSweep.Shots=0
        winSweep.Active=false;winSweep.InnerPasses=0
        api.WinSweepMode=winSweep.Mode;api.WinSweepSpeed=winSweep.Speed
        api.WinSweepItemsPerSecond=0;api.WinSweepRadiusScale=1
        api.WinSweepHeightRing=1;api.WinSweepHeightOffset=0
        api.WinSweepCoveragePass="Base outer";api.WinSweepCoreRadius=0
        api.WinSweepCoreItems=0;api.WinSweepCompletedLaps=0
        api.WinSweepEarlyCoreSkips=0;api.WinSweepFirstFireWaitMs=0
        api.WinSweepFireReady=false
    end
    local nextEquip=0
    local nextRapidPulse=0
    local bossRateAt=0;local bossRateHits=0;local bossRateHP=nil
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
            Phase=S.run("Phase"),Mode=S.run("Mode"),MotherHP=S.run("MotherHP",0),
            Allowed=api and api.Enabled and S.role()=="Game"and S.run("Mode")=="Endless"
                and (
                    (api.Stage=="Mining"and not (prefs.BossOnSpawn and prefs.ReserveForBoss)
                        and S.run("Phase")=="Mining"and S.run("MoundLocked",false)~=true and api.NativeHeldActive)
                    or (prefs.BossOnSpawn and api.Stage=="Boss"and S.run("Phase")=="Mother"and S.run("MotherHP",0)>0)
                )
                and S.set("Tools").Magnet==true and HUD.equipped()=="Magnet"
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
        -- Single fixed lowest ring for both standard Escape Farm and Endless.
        -- Extra upper rings were unproductive for standard geodes.
        local fitted=ringPlanner.Build(columns,profileCenter,{Fractions={.12},Circular=true})
        if fitted and #fitted.Bands>0 then return fitted end
    end
    api=createEndlessController({Context=function()
        local char=P.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
        return {Role=S.role(),Mode=S.run("Mode",""),Endless=S.role()=="Game"and S.run("Mode","")=="Endless",Phase=S.run("Phase"),
            Run=S.run("RunStart"),Depth=S.run("Depth"),HP=S.run("MotherHP",0),Ended=S.run("Ended",false)==true or S.run("EndlessOver",false)==true,
            Alive=hum~=nil and hum.Health>0 and char:FindFirstChild("HumanoidRootPart")~=nil,
            Owned=S.set("Tools").Magnet==true,CampBusy=CrackSell.Busy or Bench.isCracking()}
    end,Manage=function()
        if not previous then previous={Pickup=Pickup.Enabled,Upgrade=MagnetUpgrades.Enabled,Crack=CrackSell.Enabled}end
        if not Pickup.Enabled then Pickup.Start()end
        if not MagnetUpgrades.Enabled then MagnetUpgrades.Start()end
        record("RunManaged",{})
    end,SyncCrackSell=function(c)
        if CrackSell.Enabled or CrackSell.Busy or CrackSell.AutoResumeBlocked then return end
        local allowed=CrackSell.Continuous
            or (not CrackSell.OneShotCompleted and not MagnetUpgrades.IsMaxed())
        if not allowed then return end
        if CrackSell.Start(true)then
            CrackSell.EndlessRestarts+=1
            record("EndlessCrackArmed",{Continuous=CrackSell.Continuous,
                RepeatInterval=CrackSell.RepeatInterval,
                OneShotCompleted=CrackSell.OneShotCompleted,Phase=c.Phase})
        end
    end,Finish=function()
        if previous then
            if not previous.Crack then CrackSell.Stop("Auto Endless stopped",true)end
            if not previous.Upgrade then MagnetUpgrades.Stop()end
            if not previous.Pickup then Pickup.Stop()end
        end
        previous=nil;plan=nil;planDepth=nil;profileCenter=nil;pendingBand=nil
    end,Release=release,Update=function(self,c)
        local now=os.clock()
        if self.EscapeFarm and not self.Enabled and c.Phase=="Mining"
            and winSweep.Run~=tostring(c.Run)then
            resetWinSweep(c.Run)
        end
        if HUD.equipped()~="Magnet"then
            release()
            if now>=nextEquip then
                -- Escapes restart with Hand equipped in some rounds. Retry
                -- equip more promptly without flooding UI selection.
                nextEquip=now+(self.EscapeFarm and not self.Enabled and .25 or 1)
                HUD.selectTool("Magnet")
            end
            self.Status="Equipping GEO-MAG 3000";return
        end
        if c.Phase=="Mining"then
            if c.Depth~=planDepth or c.Run~=planRun then
                plan=nil;profileCenter=nil;pendingBand=nil
                planDepth=c.Depth;planRun=c.Run;band=1;nextPlan=now+.2
            end
            -- Full generated geometry pins one circular path for the whole depth.
            -- Depleted sectors cannot pull the radius/height inward or reset angle.
            if not plan and now>=nextPlan then plan=buildPlan();nextPlan=now+1 end
            if pendingBand then
                band=1
                pendingBand=nil
            end
            if not plan then
                if movementStage~="Mining"then release()end
                self.Status="Waiting for mound geometry";return
            end
            band=1
            self.RingCount=#plan.Bands;self.RingName=plan.Bands[1].Name
            -- Heartbeat is the sole writer of mining position/focus. Seed only
            -- while entering mining so the held-fire gate has a valid target.
            if movementStage~="Mining"or not target then
                local b=plan.Bands[band]
                local standardFarm=self.EscapeFarm and not self.Enabled
                local radius,heightRise
                if standardFarm then radius,heightRise=winPassGeometry()
                else radius=b.Radius+1.5;heightRise=0 end
                local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
                target=Vector3.new(plan.Origin.X,b.Y+self.Hover+heightRise,plan.Origin.Z)+radial*radius
                focus=Vector3.new(plan.Origin.X,b.Y+heightRise,plan.Origin.Z)+radial*math.max(0,radius-7)
                cameraOutward=radial
            end
        else
            if CrackSell.Busy then
                -- Finish/leave the camp safely before boss movement; allow
                -- continuous mode to re-arm when the next Mining depth starts.
                CrackSell.Stop("Paused for Endless boss",true)
                record("EndlessCrackPausedForBoss",{Continuous=CrackSell.Continuous})
            end
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
    api.OrbitSpeedMultiplier=orbitSpeedMultiplier;api.OrbitLapSeconds=orbitLapSeconds
    api.WinSweepMode="Off";api.WinSweepSpeed=orbitSpeedMultiplier;api.WinSweepRadiusScale=1;api.WinSweepItemsPerSecond=0
    api.WinSweepHeightRing=1;api.WinSweepHeightOffset=0;api.WinSweepCompletedLaps=0
    api.WinSweepCoveragePass="Off";api.WinSweepCoreRadius=0;api.WinSweepCoreItems=0
    api.WinSweepEarlyCoreSkips=0;api.WinSweepFirstFireWaitMs=0;api.WinSweepFireReady=false
    api.LastWinSweep=nil
    local function tuneWinSweep(now)
        if not winSweep.Run then return end
        local elapsed=now-winSweep.WindowAt
        -- An entire 10x outer lap is only ~1.4 seconds: the former 3s
        -- window was reset on every ring switch and could never tune speed.
        if elapsed<.75 then return end
        local newItems=math.max(0,api.NativeItems-winSweep.WindowItems)
        local shots=math.max(0,api.NativeFireEvents-winSweep.WindowShots)
        winSweep.Rate=newItems/math.max(.1,elapsed)
        winSweep.Accepted+=newItems;winSweep.Shots+=shots
        winSweep.WindowAt=now;winSweep.WindowItems=api.NativeItems
        winSweep.WindowShots=api.NativeFireEvents
        if winSweep.HeightRing==3 then
            -- Keep this short center pass independent of outer ring
            -- zero-feedback/radius changes. Return to the outer ring
            -- without misclassifying central collection as outer success.
            api.WinSweepItemsPerSecond=winSweep.Rate
            return
        end
        local reason=nil
        if winSweep.Mode=="Inner"and now-winSweep.LastSwitchAt>=5.2 then
            winSweep.Mode="Outer";winSweep.RadiusScale=1
            winSweep.Speed=orbitSpeedMultiplier;winSweep.LastSwitchAt=now
            reason="Inner coverage pass finished; returning to outermost arc"
        elseif newItems==0 and shots>=2
            and now-winSweep.LastAcceptedAt>=3.3 and
            now-winSweep.LastSwitchAt>=3 then
            if winSweep.Mode=="Outer"then
                winSweep.Mode="Inner";winSweep.RadiusScale=.72
                winSweep.Speed=winInnerSpeed;winSweep.InnerPasses+=1
                reason="No accepted geodes from outer arc; same-height inner coverage pass"
            else
                winSweep.Mode="Outer";winSweep.RadiusScale=1
                winSweep.Speed=orbitSpeedMultiplier
                reason="No accepted geodes from inner arc; trying outer coverage again"
            end
            winSweep.LastSwitchAt=now
        elseif newItems>=8 and winSweep.Mode=="Outer"
            and winSweep.Speed<winMaximumSpeed then
            winSweep.Speed=math.min(winMaximumSpeed,winSweep.Speed+.5)
            reason="Positive server pickup feedback; accelerating sweep"
        end
        if reason then
            record("EscapeFarmSweepAdjusted",{Reason=reason,Mode=winSweep.Mode,
                Speed=winSweep.Speed,RadiusScale=winSweep.RadiusScale,
                ItemsInWindow=newItems,NativeShotsInWindow=shots,
                AcceptedItemsPerSecond=winSweep.Rate})
        end
        api.WinSweepMode=winSweep.Mode;api.WinSweepSpeed=winSweep.Speed
        api.WinSweepRadiusScale=winSweep.RadiusScale
        api.WinSweepItemsPerSecond=winSweep.Rate
    end
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
        if held.Active and id==P.UserId and tool=="Magnet"and typeof(packed)=="buffer"then
            local count=math.floor(buffer.len(packed)/5)
            api.NativeItems+=count
            if count>0 and api.EscapeFarm and not api.Enabled and api.Stage=="Mining"then
                winSweep.LastAcceptedAt=os.clock()
                local ring=winSweep.HeightRing
                winSweep.RingItems[ring]=(winSweep.RingItems[ring]or 0)+count
                api.WinSweepCoreItems=winSweep.RingItems[3]
            end
        end
    end)
    function api.Export()
        return pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_endless_diagnostics.json",H:JSONEncode({Enabled=api.Enabled,EscapeFarm=api.EscapeFarm,BossAssist=api.BossAssist,ActiveBossSpot=api.ActiveBossSpot,ActiveBossSpotId=api.ActiveBossSpotId,Stage=api.Stage,Status=api.Status,Hover=api.Hover,
                Laps=api.Laps,Hits=api.Hits,WeakHits=api.WeakHits,Depth=S.run("Depth"),Phase=S.run("Phase"),Profile=plan,Ring=band,
                NativeHeldActive=held.Active,NativeFireEvents=api.NativeFireEvents,NativeItems=api.NativeItems,HeldStarts=held.Starts,HeldReleases=held.Releases,NativeFireRecoveries=held.Recoveries,
                RapidBoss=api.RapidBoss,RapidBossInterval=api.RapidBossInterval,RapidBossPulses=api.RapidBossPulses,
                BossObservedHitsPerSecond=api.BossObservedHitsPerSecond,BossHPChangePerSecond=api.BossHPChangePerSecond,
                AbilityRequests=ability.Requests,AbilityConfirmed=ability.Confirmed,AbilityStatus=ability.Status,AbilityStats=ability.Stats,
                CrackSellContinuous=CrackSell.Continuous,CrackSellEnabled=CrackSell.Enabled,
                CrackSellBusy=CrackSell.Busy,CrackSellStage=CrackSell.Stage,
                CrackSellBlocked=CrackSell.AutoResumeBlocked,
                CrackSellRestarts=CrackSell.EndlessRestarts,
                CrackSellBossInterruptions=CrackSell.EndlessBossInterruptions,
                ReserveOverchargeForBoss=prefs.ReserveForBoss,BossOverchargeEnabled=prefs.BossOnSpawn,
                FrameInterval=api.FrameInterval,MiningAimPitchOffset=endlessMiningPitchDegrees,
                WinFarmMiningAimPitchOffset=winFarmMiningPitchDegrees,
                CurrentMiningAimPitchOffset=api.EscapeFarm and not api.Enabled and winFarmMiningPitchDegrees or endlessMiningPitchDegrees,
                OrbitOutwardOffset=1.5,OrbitSpeedMultiplier=orbitSpeedMultiplier,OrbitRadiansPerSecond=orbitRadiansPerSecond,OrbitLapSeconds=orbitLapSeconds,
                EscapeFarmSweep={Mode=winSweep.Mode,Run=tostring(winSweep.Run),
                    BaselineSpeedMultiplier=orbitSpeedMultiplier,
                    MaximumOuterSpeedMultiplier=winMaximumSpeed,
                    InnerSpeedMultiplier=winInnerSpeed,
                    SpeedMultiplier=winSweep.Speed,RadiusScale=winSweep.RadiusScale,
                    AcceptedItemsPerSecond=winSweep.Rate,AcceptedItems=winSweep.Accepted,
                    NativeShots=winSweep.Shots,InnerPasses=winSweep.InnerPasses,
                    LastAcceptedAgo=winSweep.LastAcceptedAt>0 and os.clock()-winSweep.LastAcceptedAt or nil,
                    BaseContourOnly=false,SecondRingRiseStuds=winSecondRingRise,
                    HeightRing=winSweep.HeightRing,
                    HeightOffsetStuds=api.WinSweepHeightOffset,
                    CoveragePass=api.WinSweepCoveragePass,
                    CoreRadiusStuds=winSweep.CoreRadius,CoreRiseStuds=winSweep.CoreRise,
                    CorePasses=winSweep.CorePasses,
                    CompletedLaps=winSweep.CompletedLaps,
                    RingLaps=winSweep.RingLaps,RingItems=winSweep.RingItems,
                    CoreConfirmedItems=winSweep.RingItems[3],
                    FireReady=winSweep.FireReady,
                    FirstFireWaitMs=winSweep.FirstFireWaitMs,
                    EarlyCoreSkips=winSweep.EarlyCoreSkips,
                    PassStats=winSweep.PassStats,
                    RaisedSkipThresholdItems=64,RaisedSkipAtLapFraction=.72,
                    RaisedMinimumNativeShots=4,
                    SwitchAfterEachFullLap=true,NativeFiringOnly=true},
                LastCompletedWinSweep=api.LastWinSweep,
                CircularOrbit=true,AimMode=api.AimMode,Events=events}))
        end)
    end
    local movement=R.Heartbeat:Connect(function(dt)
        local holdOK,holdError=pcall(function()
            api.FrameInterval=api.FrameInterval*.95+math.clamp(dt,.001,.1)*.05
            local char=P.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
            local bossAssist=(api.BossAssist or api.EscapeFarm) and not api.Enabled and api.Stage=="Boss"
            local normalSweep=api.EscapeFarm and not api.Enabled and api.Stage=="Mining"
                and S.run("Mode")~="Endless"
            local owner=(api.Enabled and S.run("Mode")=="Endless" or normalSweep or bossAssist)
                and S.role()=="Game"and S.run("Ended",false)~=true and S.run("EndlessOver",false)~=true
            local mining=api.Stage=="Mining"and S.run("Phase")=="Mining"and S.run("MoundLocked",false)~=true and plan~=nil
            local boss=api.Stage=="Boss"and S.run("Phase")=="Mother"and S.run("MotherHP",0)>0
            local allowed=owner and(mining or boss)and movementStage==api.Stage
                and target~=nil and hum~=nil and hum.Health>0 and HUD.equipped()=="Magnet"and not CrackSell.Busy and not Bench.isCracking()
                and not Pickup.Suspended and not UIKit.cursorFree()and P:GetAttribute("PerkPending")~=true and not Tools.Blocked and not Tools.DevPaused
            held.Update(owner,allowed)
            api.NativeHeldActive=held.Active
            api.NativeFireRecoveries=held.Recoveries
            if not api.EscapeFarm and winSweep.Run~=nil then
                preserveWinSweep("Auto Win Farm stopped or escaped")
                winSweep.Run=nil;winSweep.Active=false;winSweep.Mode="Outer"
                winSweep.Speed=orbitSpeedMultiplier;winSweep.RadiusScale=1
                winSweep.HeightRing=1;winSweep.CompletedLaps=0
                winSweep.RingLaps={0,0,0};winSweep.RingItems={0,0,0}
                winSweep.CoreRadius=0;winSweep.CoreRise=0;winSweep.CorePasses=0
                winSweep.FireReady=false;winSweep.ReadySince=0
                api.WinSweepFireReady=false
                api.WinSweepMode="Off";api.WinSweepSpeed=orbitSpeedMultiplier
                api.WinSweepItemsPerSecond=0;api.WinSweepRadiusScale=1
                api.WinSweepHeightRing=1;api.WinSweepHeightOffset=0;api.WinSweepCompletedLaps=0
                api.WinSweepCoveragePass="Off";api.WinSweepCoreRadius=0;api.WinSweepCoreItems=0
            end
            local standardFarm=api.EscapeFarm and not api.Enabled and api.Stage=="Mining"
                and S.run("Phase")=="Mining"and S.run("MoundLocked",false)~=true
            if standardFarm and held.Active then
                local now=os.clock()
                if not winSweep.Active then
                    -- Resuming in the middle of the core pass must keep
                    -- the compact pass speed rather than resetting to 10x.
                    winSweep.Active=true
                    winSweep.Speed=winSweep.HeightRing==3 and winCoreSpeed
                        or math.max(orbitSpeedMultiplier,winSweep.OuterSpeed)
                    winSweep.ReadySince=now
                    winSweep.ReadyShotBase=api.NativeFireEvents
                    winSweep.FireReady=false
                    winSweep.WindowAt=now
                    winSweep.WindowItems=api.NativeItems
                    winSweep.WindowShots=api.NativeFireEvents
                end
                if not winSweep.FireReady and
                    (api.NativeFireEvents>winSweep.ReadyShotBase
                        or now-winSweep.ReadySince>=.25)then
                    -- Native tool callbacks are authoritative; the brief
                    -- timeout prevents deadlock when no columns are in range.
                    winSweep.FireReady=true
                    if winSweep.FirstFireWaitMs==nil then
                        winSweep.FirstFireWaitMs=math.floor((now-winSweep.ReadySince)*1000+.5)
                        api.WinSweepFirstFireWaitMs=winSweep.FirstFireWaitMs
                    end
                    if winSweep.PassStartAt==0 then
                        winSweep.PassStartAt=now
                        winSweep.PassStartItems=winSweep.RingItems[winSweep.HeightRing]or 0
                        winSweep.PassStartShots=api.NativeFireEvents
                    end
                    record("EscapeFarmNativeSweepReady",{
                        Pass=winSweep.HeightRing,WaitMs=(now-winSweep.ReadySince)*1000,
                        FirstShotObserved=api.NativeFireEvents>winSweep.ReadyShotBase})
                end
                api.WinSweepFireReady=winSweep.FireReady
                if winSweep.FireReady then tuneWinSweep(now)end
            elseif winSweep.Active then
                -- During equip, menus, camp or input interruption, do not
                -- count inactive revolutions as completed farming coverage.
                winSweep.Active=false;winSweep.FireReady=false
                api.WinSweepFireReady=false
                winSweep.PausedBeforeReady+=1
            end
            -- Experimental, opt-in repeated native input only during a live
            -- boss fight. Does NOT call unverified boss remotes or bypass
            -- Stats.tool cooldown / server validation.
            if boss and held.Active and api.RapidBoss and os.clock()>=nextRapidPulse then
                nextRapidPulse=os.clock()+api.RapidBossInterval
                Tools.setUse(true,"button")
                api.RapidBossPulses+=1
            end
            if boss and held.Active then
                local t=os.clock()
                if bossRateAt==0 then
                    bossRateAt=t;bossRateHits=api.Hits
                    bossRateHP=tonumber(S.run("MotherHP",0))
                elseif t-bossRateAt>=1.5 then
                    local elapsed=t-bossRateAt
                    api.BossObservedHitsPerSecond=math.max(0,api.Hits-bossRateHits)/elapsed
                    local hp=tonumber(S.run("MotherHP",0))
                    if hp and bossRateHP then
                        api.BossHPChangePerSecond=math.max(0,bossRateHP-hp)/elapsed
                    end
                    bossRateAt=t;bossRateHits=api.Hits;bossRateHP=hp
                end
            elseif bossRateAt~=0 then
                bossRateAt=0;bossRateHP=nil
            end
        end)
        if not holdOK then api.Stop();api.Status="Native fire error: "..tostring(holdError);record("NativeFireError",tostring(holdError));return end
        if CrackSell.Busy or Bench.isCracking()then release();return end
        if not (api.Enabled or (api.EscapeFarm and api.Stage=="Mining")
            or ((api.BossAssist or api.EscapeFarm) and api.Stage=="Boss")) or not target then return end
        local ok,err=pcall(function()
            local char=P.Character;local root=char and char:FindFirstChild("HumanoidRootPart");local hum=char and char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health<=0 then release();return end
            if char~=ownedCharacter then release();return end
            if api.Stage=="Mining"and plan then
                local standardFarm=api.EscapeFarm and not api.Enabled
                if standardFarm and held.Active and winSweep.FireReady then
                    -- Advance angle BEFORE writing the character CFrame.
                    -- Ring 2 starts on the exact Heartbeat that completes
                    -- lap 1, rather than after a timer or .125s controller poll.
                    local speed=winSweep.Speed
                    angle+=math.min(dt,.1)*(math.pi*2)/(14/speed)
                    local now=os.clock()
                    local oldRing=winSweep.HeightRing
                    local passItems=math.max(0,(winSweep.RingItems[oldRing]or 0)
                        -(winSweep.PassStartItems or 0))
                    local passShots=math.max(0,api.NativeFireEvents
                        -(winSweep.PassStartShots or 0))
                    local passSeconds=winSweep.PassStartAt>0
                        and now-winSweep.PassStartAt or 0
                    local fullLap=angle>=math.pi*2
                    -- The very first base lap ALWAYS finishes. For the
                    -- raised lap, prefer useful collection, but when >72%
                    -- of the raised arc has yielded at most 64 items after
                    -- real tool shots, go to the proven central pillar now.
                    -- Productive raised laps still run to a full 360.
                    local earlyCore=oldRing==2 and not fullLap
                        and angle>=math.pi*2*.72
                        and passSeconds>=.55 and passShots>=4
                        and passItems<=64
                    if fullLap or earlyCore then
                        if fullLap then
                            angle%=math.pi*2
                            api.Laps+=1
                            winSweep.CompletedLaps+=1
                            winSweep.RingLaps[oldRing]+=1
                        else
                            angle=0
                            winSweep.EarlyCoreSkips+=1
                            api.WinSweepEarlyCoreSkips=winSweep.EarlyCoreSkips
                        end
                        local stat={
                            AtMs=DateTime.now().UnixTimestampMillis,
                            Pass=oldRing,FullLap=fullLap,EarlyCoreSwitch=earlyCore,
                            LapFraction=fullLap and 1 or .72,
                            Items=passItems,NativeShots=passShots,
                            DurationSeconds=passSeconds,SpeedMultiplier=winSweep.Speed
                        }
                        winSweep.PassStats[#winSweep.PassStats+1]=stat
                        if #winSweep.PassStats>24 then
                            table.remove(winSweep.PassStats,1)
                        end
                        -- The raised ring starts directly after one full
                        -- base lap; only demonstrably weak raised coverage
                        -- can finish early. The compact core always gets a
                        -- full lap before returning to the base exterior.
                        local nextRing=oldRing==1 and 2 or(oldRing==2 and 3 or 1)
                        if nextRing==3 then
                            winSweep.OuterSpeed=winSweep.Speed
                            winSweep.Speed=winCoreSpeed
                            winSweep.CorePasses+=1
                        elseif oldRing==3 then
                            winSweep.Speed=math.max(orbitSpeedMultiplier,
                                winSweep.OuterSpeed or orbitSpeedMultiplier)
                        end
                        winSweep.HeightRing=nextRing
                        local nextRadius,nextRise=winPassGeometry()
                        api.WinSweepHeightRing=nextRing
                        api.WinSweepHeightOffset=nextRise
                        api.WinSweepCoveragePass=nextRing==1 and "Base outer"
                            or(nextRing==2 and "Raised outer"or"Boss-center core")
                        api.WinSweepCoreRadius=winSweep.CoreRadius
                        api.WinSweepCoreItems=winSweep.RingItems[3]
                        api.WinSweepSpeed=winSweep.Speed
                        api.WinSweepCompletedLaps=winSweep.CompletedLaps
                        winSweep.PassStartAt=now
                        winSweep.PassStartItems=winSweep.RingItems[nextRing]or 0
                        winSweep.PassStartShots=api.NativeFireEvents
                        winSweep.WindowAt=now
                        winSweep.WindowItems=api.NativeItems
                        winSweep.WindowShots=api.NativeFireEvents
                        -- LastSwitchAt tracks radius-tuner changes, NOT
                        -- routine coverage changes. Its 3s cooldown would
                        -- otherwise never elapse on 1.4s laps.
                        record("EscapeFarmCoveragePassChanged",{
                            FinishedLap=winSweep.CompletedLaps,From=oldRing,To=nextRing,
                            Pass=api.WinSweepCoveragePass,Radius=nextRadius,
                            HeightOffsetStuds=nextRise,Speed=winSweep.Speed,
                            EarlyCoreSwitch=earlyCore,PassItems=passItems,
                            NativeShotsInPass=passShots,PassDurationSeconds=passSeconds,
                            RingLaps=table.clone(winSweep.RingLaps),
                            AcceptedItemsPerRing=table.clone(winSweep.RingItems)})
                    end
                end
                local b=plan.Bands[band]
                local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
                local radius,heightRise
                if standardFarm then radius,heightRise=winPassGeometry()
                else radius=b.Radius+1.5;heightRise=0 end
                target=Vector3.new(plan.Origin.X,b.Y+api.Hover+heightRise,plan.Origin.Z)+radial*radius
                focus=Vector3.new(plan.Origin.X,b.Y+heightRise,plan.Origin.Z)+radial*math.max(0,radius-7)
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
            if api.Stage=="Mining"and plan and not (api.EscapeFarm and not api.Enabled)
                and not pendingBand then
                -- Auto Endless retains its original fixed single-height loop.
                angle+=math.min(dt,.1)*orbitRadiansPerSecond
                if angle>=math.pi*2 then
                    angle%=math.pi*2;api.Laps+=1;pendingBand=band+1
                    record("LapComplete",{Ring=band,Laps=api.Laps})
                end
            end
        end)
        if not ok then api.Stop();record("MovementError",tostring(err))end
    end)
    local renderName="GeodeEndlessCamera_"..tostring(P.UserId)
    R:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+10,function(dt)
        if not (api.Enabled or (api.EscapeFarm and api.Stage=="Mining")
            or ((api.BossAssist or api.EscapeFarm)and api.Stage=="Boss")) or not target or not focus
            or CrackSell.Busy or Bench.isCracking()then return end
        local cam=workspace.CurrentCamera;if not cam then return end
        if not savedCamera or savedCamera.Camera~=cam then savedCamera={Camera=cam,Type=cam.CameraType,Subject=cam.CameraSubject};smoothedCameraRotation=nil end
        local direction=api.Stage=="Mining"and cameraOutward or(target-focus).Unit
        if not direction then return end
        local cameraPosition=target+direction*3+Vector3.new(0,2,0)
        cam.CameraType=Enum.CameraType.Scriptable
        local desired=CFrame.lookAt(cameraPosition,focus)
        if api.Stage=="Mining"then
            local pitch=api.EscapeFarm and not api.Enabled
                and winFarmMiningPitchDegrees or endlessMiningPitchDegrees
            desired=desired*CFrame.Angles(math.rad(pitch),0,0)
            smoothedCameraRotation=smoothedCameraRotation or cam.CFrame.Rotation
            local frameDt=math.clamp(tonumber(dt)or 1/60,0,.1)
            local _,difference=smoothedCameraRotation:ToObjectSpace(desired.Rotation):ToAxisAngle()
            local currentSpeed=api.EscapeFarm and not api.Enabled and winSweep.Speed or orbitSpeedMultiplier
            local alpha=math.min(1-math.exp(-8*currentSpeed*frameDt),math.rad(70*currentSpeed)*frameDt/math.max(math.abs(difference),.000001))
            smoothedCameraRotation=smoothedCameraRotation:Lerp(desired.Rotation,alpha)
            cam.CFrame=CFrame.new(cameraPosition)*smoothedCameraRotation
        else smoothedCameraRotation=nil;cam.CFrame=desired end
        api.AimMode=api.Stage=="Mining"and"AOE sweep"or"Boss"
    end)
    local unload=api.Unload
    function api.Unload()unload();movement:Disconnect();nativeFired:Disconnect();nativeBossHit:Disconnect();nativeFeedback:Disconnect();R:UnbindFromRenderStep(renderName)end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(function()
                -- Capture character restoration values before Update creates a target.
                local standaloneBoss=(api.BossAssist or api.EscapeFarm) and S.role()=="Game"and S.run("Phase")=="Mother"
                    and S.run("MotherHP",0)>0 and S.run("Ended",false)~=true
                local escapeMining=api.EscapeFarm and not api.Enabled and S.role()=="Game"
                    and S.run("Mode")~="Endless"and S.run("Phase")=="Mining"
                if (api.Enabled or standaloneBoss or escapeMining)and(P.Character~=ownedCharacter or not ownedHumanoid)then
                    release()
                    ownedCharacter=P.Character
                    ownedHumanoid=ownedCharacter and ownedCharacter:FindFirstChildOfClass("Humanoid")
                    autoRotate=ownedHumanoid and ownedHumanoid.AutoRotate
                end
                api.Tick()
                local bossReserved=prefs.BossOnSpawn and prefs.ReserveForBoss
                local allowAbility=api.Enabled and (
                    (api.Stage=="Mining" and not bossReserved)
                    or (api.Stage=="Boss" and prefs.BossOnSpawn))
                ability.Tick(allowAbility)
                if bossReserved and api.Stage=="Mining" then
                    ability.Status="Overcharge reserved for Mother boss"
                end
                api.AbilityAvailable=ability.Available;api.AbilityStats=ability.Stats;api.AbilityStatus=ability.Status
                api.AbilityRequests=ability.Requests;api.AbilityConfirmed=ability.Confirmed
            end)
            if not ok then api.Stop();api.Status="Endless error: "..tostring(err);record("Error",tostring(err))end
            task.wait(api.Stage=="Boss" and .04 or .125)
        end
    end)
    return api
end

local Endless=createLiveEndless(Pickup,CrackSell,MagnetUpgrades,abilityPrefs)
-- Native GEO-MAG skill automation outside managed Endless mining.
-- Does not change server damage, tool cooldown, or phase; all activation
-- attempts pass through the existing game's MasteryHUD.useSkill().
local function createLiveOtherModeAbility(endless,prefs,CrackSell)
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local M=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local C=P:WaitForChild("PlayerScripts"):WaitForChild("MTGClient")
    local S=require(C.State)
    local HUD=require(C.RunHUD)
    local Tools=require(C.Tools)
    local Mastery=require(C.Mastery)
    local MasteryHUD=require(C.MasteryHUD)
    local UIKit=require(C.UIKit)
    local Bench=require(C.Bench)
    local events={}
    local api={Running=true,Enabled=true,Status="Waiting for eligible mining or boss phase",
        Available=false,Requests=0,Confirmed=0,EscapeFarmActive=false}
    local escapeFarmProvider
    function api.SetEscapeFarmProvider(fn)
        escapeFarmProvider=type(fn)=="function"and fn or nil
    end
    local function escapeFarmActive()
        if not prefs.EscapeFarmAlways or not escapeFarmProvider then return false end
        local ok,active=pcall(escapeFarmProvider)
        return ok and active==true
    end
    -- Escape farming intentionally uses Overcharge in both eligible phases,
    -- regardless of ordinary non-Endless mining / boss reservation settings.
    -- Other modes keep the user's existing boss-first behavior unchanged.
    local function phaseEligibility()
        local phase,mode=S.run("Phase"),S.run("Mode")
        local farm=escapeFarmActive()and mode~="Endless"
        local boss=(farm or prefs.BossOnSpawn)and phase=="Mother"
            and S.run("MotherHP",0)>0
        local mining=(farm or (prefs.NormalMining
            and not (prefs.BossOnSpawn and prefs.ReserveForBoss)))
            and phase=="Mining"and mode~="Endless"
        return phase,mode,boss,mining,farm
    end
    local function record(kind,data)
        events[#events+1]={Kind=kind,At=os.clock(),Phase=S.run("Phase"),Mode=S.run("Mode"),Data=data}
        if #events>80 then table.remove(events,1)end
    end
    local controller=createEndlessAbilityController({
        Now=function()return workspace:GetServerTimeNow()end,
        Context=function()
            local stats=Mastery.skillStats("Magnet")
            local buff,remaining=Mastery.buff()
            local now=workspace:GetServerTimeNow()
            local phase,mode,boss,mining=phaseEligibility()
            local char=P.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local allowed=not endless.Enabled and S.role()=="Game" and (boss or mining)
                and hum~=nil and hum.Health>0 and S.set("Tools").Magnet==true
                and HUD.equipped()=="Magnet"
                and (not mining or S.run("MoundLocked",false)~=true)
                and not CrackSell.Busy and not Bench.isCracking()
                and not UIKit.cursorFree()and P:GetAttribute("PerkPending")~=true
                and P:GetAttribute("Escaped")~=true and S.run("Ended",false)~=true
                and not Tools.Blocked and not Tools.DevPaused
            api.LastEligibility={
                EscapeFarmActive=escapeFarmActive(),Phase=phase,Mode=mode,
                EligiblePhase=boss or mining,Allowed=allowed,
                ToolOwned=S.set("Tools").Magnet==true,
                ToolEquipped=HUD.equipped()=="Magnet",
                CharacterAlive=hum~=nil and hum.Health>0,
                CampBusy=CrackSell.Busy or Bench.isCracking(),
                MenuOpen=UIKit.cursorFree(),
                MoundLocked=S.run("MoundLocked",false)==true,
                Ended=S.run("Ended",false)==true,Escaped=P:GetAttribute("Escaped")==true,
                ToolsBlocked=Tools.Blocked==true,DevPaused=Tools.DevPaused==true,
                PerkPending=P:GetAttribute("PerkPending")==true
            }
            return {
                Stats=stats,SkillId=stats and stats.Id,
                Unlocked=stats~=nil and Mastery.level("Tool:Magnet")>=Mastery.SkillLevel,
                ReadyAt=Mastery.skillReadyAt("Magnet"),
                BuffId=buff,BuffUntil=buff and now+(tonumber(remaining)or 0)or 0,
                Phase=phase,Mode=mode,MotherHP=S.run("MotherHP",0),
                Allowed=allowed
            }
        end,
        Activate=function()MasteryHUD.useSkill()end,
        Record=record
    })
    function api.Unload()api.Running=false end
    function api.Export()
        return pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/non_perk_damage_diagnostics.json",H:JSONEncode({
                Status=api.Status,Available=api.Available,Requests=api.Requests,Confirmed=api.Confirmed,
                NormalMining=prefs.NormalMining,BossOnSpawn=prefs.BossOnSpawn,
                ReserveForBoss=prefs.ReserveForBoss,EscapeFarmAlways=prefs.EscapeFarmAlways,
                EscapeFarmActive=escapeFarmActive(),EndlessEnabled=endless.Enabled,
                CampBusy=CrackSell.Busy,Role=S.role(),Phase=S.run("Phase"),Mode=S.run("Mode"),
                Stats=controller.Stats,Eligibility=api.LastEligibility,Events=events,
                Note="Uses native GEO-MAG mastery skill; server decides damage and activation. No guaranteed critical hits."
            }))
        end)
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(function()
                local phase,mode,boss,mining,farm=phaseEligibility()
                api.EscapeFarmActive=farm
                local active=not endless.Enabled and S.role()=="Game"and (boss or mining)
                controller.Tick(active)
                api.Requests=controller.Requests;api.Confirmed=controller.Confirmed
                api.Available=controller.Available
                api.Status=active and controller.Status
                    or boss and "Endless controller owns ability"
                    or farm and "Escape Farm: waiting for mining or Mother boss"
                    or prefs.BossOnSpawn and prefs.ReserveForBoss and phase=="Mining"
                        and "Overcharge reserved for Mother boss"
                    or "Waiting for non-Endless mining / boss"
            end)
            if not ok then api.Status="Native ability check error: "..tostring(err)end
            task.wait(.04)
        end
    end)
    return api
end

local OtherModeAbility=createLiveOtherModeAbility(Endless,abilityPrefs,CrackSell)

-- Standard-mode escape loop. Reuses one-shot camp handling, five-band native
-- mining, verified boss weak points, and the existing server-confirmed Escape.
-- Replay uses only recognizable native UI buttons, with retry bounds.
local function createAutoFarmEscapesController()
    local Players=game:GetService("Players")
    local Http=game:GetService("HttpService")
    local player=Players.LocalPlayer
    local State=require(player.PlayerScripts.MTGClient.State)
    local api={Running=true,Enabled=false,Stage="Paused",Status="Paused",Rounds=0,
        Replays=0,Clicks=0,ReplayTransitions=0,TurnIns=0,LastClick="",LastError="",RoundStartedAt=0}
    local events={}
    local replayAttempts=0;local nextReplayAt=0;local buttonPollAt=0
    local modeSelection=false;local lastObservedRole="";local lastObservedPhase=""
    local turnInCompleted=false;local roundActive=false
    local activeRun=nil
    local previousContinuousMode=nil
    local attachedWindow=nil
    local enableTeleportQueue=nil
    local lastReplayRequestedRun=nil
    local lastReplayRequestedAt=0
    local nextWaitingSnapshot=0
    local waitingEquipAttempts=0;local nextWaitingEquip=0;local wasWaiting=false
    local okVIM,vim=pcall(function()return game:GetService("VirtualInputManager")end)
    local okCore,coreGui=pcall(function()return game:GetService("CoreGui")end)
    local function record(kind,data)
        events[#events+1]={Kind=kind,AtMs=DateTime.now().UnixTimestampMillis,Data=data}
        if #events>100 then table.remove(events,1)end
    end
    local function setStage(stage,status)
        if api.Stage~=stage then record("Stage",{From=api.Stage,To=stage})end
        api.Stage=stage;api.Status=status or stage
    end
    -- The results panel's green PLAY AGAIN graphic may be an ImageButton
    -- with a separate TextLabel sibling. Match *both* clickables and text
    -- labels, then choose a real button under the visible label when possible.
    local okVU,virtualUser=pcall(function()return game:GetService("VirtualUser")end)
    local function visible(obj)
        if not obj or not obj:IsA("GuiObject")or not obj.Visible
            or obj.AbsoluteSize.X<8 or obj.AbsoluteSize.Y<8 then return false end
        local node=obj
        while node and node~=player.PlayerGui and node~=coreGui do
            if node:IsA("GuiObject")and not node.Visible then return false end
            if node:IsA("ScreenGui")and not node.Enabled then return false end
            node=node.Parent
        end
        return node==player.PlayerGui or (okCore and node==coreGui)
    end
    local function normalized(v)
        return tostring(v or ""):lower():gsub("<[^>]*>",""):gsub("[^%w]","")
    end
    local function guiText(obj)
        return (obj:IsA("TextButton")or obj:IsA("TextLabel"))and obj.Text or ""
    end
    local function buttonName(button)
        if not button then return ""end
        local str=guiText(button)
        if #str>0 then return str end
        for _,child in ipairs(button:GetDescendants())do
            if (child:IsA("TextLabel")or child:IsA("TextButton"))
                and child.Visible and #child.Text>0 then
                return child.Text
            end
        end
        return ""
    end
    local function replayName(value)
        local text=normalized(value)
        return text=="playagain"or text=="playagainbutton"
            or text=="replay"or text=="replaybutton"
    end
    local function candidateList(kind)
        local matched,available={},{}
        local buttons,labels={},{}
        local resultsVisible=false
        local count=0
        -- The literal PLAY AGAIN label can belong to a TextLabel (or even
        -- an image-backed button). Inspect both game GUI roots; no invented
        -- coordinates or guessed remotes.
        local roots={player.PlayerGui}
        if okCore and coreGui then roots[#roots+1]=coreGui end
        local labelPreview={}
        for _,root in ipairs(roots)do
            -- Access to CoreGui descendants differs by executor; never let
            -- an unavailable root disable PlayerGui replay detection.
            local okDesc,descendants=pcall(function()return root:GetDescendants()end)
            if not okDesc then descendants={}end
            for _,obj in ipairs(descendants)do
                if obj:IsA("GuiObject")and visible(obj)then
                    local name=normalized(obj.Name)
                    if obj:IsA("GuiButton")then
                        buttons[#buttons+1]=obj
                        count+=1
                        if #available<40 then
                            available[#available+1]={Name=obj.Name,Class=obj.ClassName,
                                Text=buttonName(obj),Active=obj.Active,
                                Path=obj:GetFullName()}
                        end
                    end
                    local rawText=guiText(obj)
                    if #rawText>0 then
                        local text=normalized(rawText)
                        if text:find("youescaped",1,true)or
                            text:find("backtocamp",1,true)or
                            name:find("escaperesult",1,true)then
                            resultsVisible=true
                        end
                        local isReplay=replayName(rawText)or text:sub(1,9)=="playagain"
                        if isReplay or
                            (kind=="Lobby"and text=="play")or
                            (kind=="Solo"and text=="solo")then
                            labels[#labels+1]=obj
                            if #labelPreview<12 then
                                labelPreview[#labelPreview+1]={Name=obj.Name,Class=obj.ClassName,
                                    Text=rawText,Path=obj:GetFullName(),Width=obj.AbsoluteSize.X,
                                    Height=obj.AbsoluteSize.Y}
                            end
                        end
                    end
                end
            end
        end
        local seen={}
        local function add(button,target,method,text,position)
            if not target or seen[target]then return end
            seen[target]=true
            matched[#matched+1]={Button=button,Target=target,Match=method,Text=text,
                Name=button and button.Name or target.Name,Path=target:GetFullName(),
                Position=position}
        end
        for _,button in ipairs(buttons)do
            local title=normalized(buttonName(button))
            local name=normalized(button.Name)
            local hit=kind=="Replay"and(replayName(title)or replayName(name))
                or kind=="Lobby"and(title=="play"or name=="play"or name=="playbutton")
                or kind=="Solo"and(title=="solo"or name=="solo"or name=="solobutton")
            if hit then add(button,button,"button",buttonName(button))end
        end
        for _,label in ipairs(labels)do
            local title=normalized(guiText(label))
            local wanted=kind=="Replay"and(replayName(title)or title:sub(1,9)=="playagain")
                or kind=="Lobby"and title=="play"
                or kind=="Solo"and title=="solo"
            if wanted then
                local owner=label.Parent
                while owner and owner~=player.PlayerGui and owner~=coreGui do
                    if owner:IsA("GuiButton")and visible(owner)then break end
                    owner=owner.Parent
                end
                if not owner or not owner:IsA("GuiButton")then
                    owner=nil
                    local center=label.AbsolutePosition+label.AbsoluteSize*.5
                    local smallest=math.huge
                    for _,button in ipairs(buttons)do
                        local pos,size=button.AbsolutePosition,button.AbsoluteSize
                        local inside=center.X>=pos.X-2 and center.X<=pos.X+size.X+2
                            and center.Y>=pos.Y-2 and center.Y<=pos.Y+size.Y+2
                        local area=size.X*size.Y
                        if inside and area<smallest
                            and area<label.AbsoluteSize.X*label.AbsoluteSize.Y*12 then
                            smallest=area;owner=button
                        end
                    end
                end
                local position=label.AbsolutePosition+label.AbsoluteSize*.5
                if owner then add(owner,owner,"label-button",guiText(label),position)
                else add(nil,label,"label-center",guiText(label),position)end
            end
        end
        table.sort(matched,function(a,b)
            local function priority(v)
                if v.Match=="label-button"then return 1 end
                if v.Match=="button"then return 2 end
                return 3
            end
            return priority(a)<priority(b)
        end)
        api.VisibleReplayLabels=labelPreview
        return matched,available,count,resultsVisible
    end
    local function click(candidate,attempt)
        local obj=candidate and candidate.Target
        if not obj or not obj.Parent then return false,"Missing replay target","none"end
        -- Close only our own overlay; this does not dismiss the game's result.
        if attachedWindow and not attachedWindow.Closed then attachedWindow:Close()end
        if not visible(obj)then return false,"Replay target hidden","none"end
        local position=candidate.Position or (obj.AbsolutePosition+obj.AbsoluteSize*.5)
        local camera=workspace.CurrentCamera
        local frame=camera and camera.CFrame or CFrame.new()
        -- The actual Play Again UI might listen for Activated instead of
        -- MouseButton1Click, or have no GuiButton ancestor at all.
        -- Send only one successful input per attempt; wait for a server/state
        -- transition before trying the next method.
        local plans=attempt==1 and {"activated","vim","virtual-user","click"}
            or attempt==2 and {"click","activated","vim","virtual-user"}
            or attempt==3 and {"vim","click","activated","virtual-user"}
            or attempt==4 and {"virtual-user","vim","activated","click"}
            or {"vim","activated","click","virtual-user"}
        local lastFailure="No supported input backend"
        for _,method in ipairs(plans)do
            local ok,err=pcall(function()
                if method=="activated"then
                    assert(candidate.Button and type(firesignal)=="function",
                        "Activated signal unavailable")
                    firesignal(candidate.Button.Activated)
                elseif method=="click"then
                    assert(candidate.Button and type(firesignal)=="function",
                        "Click signal unavailable")
                    firesignal(candidate.Button.MouseButton1Click)
                elseif method=="vim"then
                    assert(okVIM and vim,"VirtualInputManager unavailable")
                    -- Move first: some GUI activation logic requires hover.
                    pcall(function()vim:SendMouseMoveEvent(position.X,position.Y,game)end)
                    vim:SendMouseButtonEvent(position.X,position.Y,0,true,game,0)
                    task.wait(.065)
                    vim:SendMouseButtonEvent(position.X,position.Y,0,false,game,0)
                elseif method=="virtual-user"then
                    assert(okVU and virtualUser,"VirtualUser unavailable")
                    virtualUser:CaptureController()
                    virtualUser:Button1Down(position,frame)
                    task.wait(.065)
                    virtualUser:Button1Up(position,frame)
                end
            end)
            if ok then return true,nil,method,position end
            lastFailure=method..": "..tostring(err)
        end
        return false,lastFailure,"none",position
    end
    local function stopOwned()
        Endless.SetEscapeFarm(false)
        if CrackSell.Busy or CrackSell.Enabled then CrackSell.Stop("Auto escapes stopped")end
        if Pickup.Enabled then Pickup.Stop()end
        if Escape.Enabled then Escape.Stop()end
    end
    function api.SetWindow(value)attachedWindow=value end
    function api.SetQueueEnabler(value)enableTeleportQueue=type(value)=="function"and value or nil end
    function api.Start()
        if not api.Running or api.Enabled then return end
        if Endless.Enabled then Endless.Stop()end
        previousContinuousMode=CrackSell.Continuous
        api.PreviousContinuousMode=previousContinuousMode
        api.Enabled=true
        if enableTeleportQueue then
            local ok,err=pcall(enableTeleportQueue)
            if not ok then record("TeleportQueueError",{Error=tostring(err)})end
        end
        api.LastError=""
        replayAttempts=0;nextReplayAt=0;buttonPollAt=0;modeSelection=false
        nextWaitingSnapshot=0
        activeRun=nil;turnInCompleted=false;roundActive=false
        lastReplayRequestedRun=nil;lastReplayRequestedAt=0
        if player:GetAttribute("Escaped")==true then
            setStage("Replay","Escape already confirmed; searching for Play Again")
        else
            setStage("AwaitingRound","Auto escapes armed; waiting to enter a standard game")
        end
        record("Started",{PlaceId=game.PlaceId})
    end
    function api.Stop(reason)
        if not api.Enabled and api.Stage=="Paused"then return end
        api.Enabled=false
        stopOwned()
        -- Escape Farm deliberately performs exactly one turn-in per round.
        -- Restore the user's saved continuous-camp preference when returning
        -- to Auto Endless, rather than silently leaving Keep Selling OFF.
        if previousContinuousMode~=nil then
            CrackSell.SetContinuous(previousContinuousMode)
            previousContinuousMode=nil
        end
        roundActive=false
        setStage("Paused",reason or "Paused")
        record("Stopped",{Reason=api.Status})
    end
    function api.Unload()
        if not api.Running then return end
        api.Stop();api.Running=false
    end
    local function beginRound(run)
        if Endless.Enabled then Endless.Stop()end
        if CrackSell.Enabled or CrackSell.Busy then CrackSell.Stop("Starting single-turn-in escape cycle")end
        CrackSell.SetContinuous(false)
        -- Keep the configured bag-change delay (including 0.25 seconds).
        -- The existing 1-second default remains unchanged.
        if not Escape.Enabled then Escape.Start()end
        if not Pickup.Enabled then Pickup.Start()end
        CrackSell.Start()
        -- An approved early-intro pickup may already have filled the bag
        -- before the Mining phase. Treat that existing inventory as a valid
        -- first-trip trigger instead of waiting forever for another bag delta.
        if (tonumber(player:GetAttribute("BagCount"))or 0)>0 then
            CrackSell.ArmExistingBag("Items collected during Waiting before mining")
        end
        Endless.SetEscapeFarm(true)
        activeRun=run
        turnInCompleted=false;roundActive=true
        api.RoundStartedAt=os.clock()
        replayAttempts=0;modeSelection=false
        api.VisibleButtons=nil;api.VisibleButtonCount=nil
        setStage("Collecting","Mining geodes; one Crack & Sell trip after first bag change")
        record("RoundStarted",{Run=tostring(run),Bag=player:GetAttribute("BagCount"),
            CrackDelaySeconds=CrackSell.Interval,
            EarlyPickupStatus=Pickup.EarlyIntroStatus,
            EarlyPickupAttempts=Pickup.EarlyAttempts,
            EarlyPickupConfirmed=Pickup.EarlyConfirmed})
    end
    local function stopRound()
        Endless.SetEscapeFarm(false)
        if Pickup.Enabled then Pickup.Stop()end
        if CrackSell.Enabled or CrackSell.Busy then CrackSell.Stop("Round finished")end
        roundActive=false
    end
    local function tryClick(kind,prefetched,available,total,resultsVisible)
        local now=os.clock()
        if now<buttonPollAt or now<nextReplayAt then return end
        buttonPollAt=now+.08
        local matching=prefetched
        if not matching then
            matching,available,total,resultsVisible=candidateList(kind)
        end
        api.VisibleButtonCount=total or 0
        api.VisibleButtons=available or{}
        api.ResultPanelVisible=resultsVisible==true
        api.MatchingButtons={}
        for index,item in ipairs(matching)do
            if index<=10 then
                api.MatchingButtons[index]={Name=item.Name,Text=item.Text,
                    Match=item.Match,Path=item.Path}
            end
        end
        if #matching==0 then
            api.Status="Waiting for "..(kind=="Replay"and"Play Again"or kind=="Solo"and"Solo"or"Play").." control"
            return
        end
        if replayAttempts>=5 then
            api.Status="Replay click limit reached; inspect escape farm diagnostics"
            return
        end
        replayAttempts+=1
        -- Escape summary auto-returns to camp after a few seconds: five
        -- escalating attempts fit within that results window.
        nextReplayAt=now+(kind=="Replay"and .55 or 2)
        local candidate=matching[1]
        api.LastClick=kind..": "..tostring(candidate.Text~=""and candidate.Text or candidate.Name)
        record("ReplayClickAttempt",{Kind=kind,Name=candidate.Name,Text=candidate.Text,
            Match=candidate.Match,Path=candidate.Path,Attempt=replayAttempts,
            ResultPanelVisible=resultsVisible==true})
        local success,err,method,position=click(candidate,replayAttempts)
        api.LastClickMethod=method
        if success then
            api.Clicks+=1
            if kind=="Replay"then
                api.Replays+=1
                lastReplayRequestedRun=tostring(State.run("RunStart"))
                lastReplayRequestedAt=os.clock()
            end
            if kind=="Lobby"then modeSelection=true end
            api.Status="Replay input sent ("..method..") — awaiting transition"
            record("ReplayClickSent",{Kind=kind,Method=method,Attempt=replayAttempts,
                X=position and position.X,Y=position and position.Y})
        else
            api.LastError=tostring(err)
            api.Status="Cannot click "..kind..": "..api.LastError
            record("ReplayClickError",{Kind=kind,Method=method,Error=api.LastError})
        end
    end
    function api.Tick()
        if not api.Running or not api.Enabled then return end
        local role,phase,mode=State.role(),State.run("Phase"),State.run("Mode")
        if Endless.Enabled then
            Endless.Stop()
            record("AutoEndlessStopped",{Reason="Auto Farm Escapes runs standard mode"})
        end
        local escaped=player:GetAttribute("Escaped")==true
        local run=State.run("RunStart")
        -- The current game frequently starts Mining with Hand equipped.
        -- Prime GEO-MAG using its normal tool selector while Waiting, if
        -- the client already exposes an owned tool. Never assume this
        -- bypasses the server's Mining or MoundLocked pickup rules.
        local waiting=role=="Game"and mode~="Endless"and phase=="Waiting"and not escaped
        if waiting and not wasWaiting then
            waitingEquipAttempts=0;nextWaitingEquip=0
        end
        wasWaiting=waiting
        if waiting and waitingEquipAttempts<4 and os.clock()>=nextWaitingEquip
            and State.set("Tools").Magnet==true and HUD.equipped()~="Magnet"
            and not CrackSell.Busy and not UIKit.cursorFree()then
            waitingEquipAttempts+=1
            nextWaitingEquip=os.clock()+1
            local selected,err=pcall(HUD.selectTool,"Magnet")
            record("EarlyMagnetEquipAttempt",{
                Attempt=waitingEquipAttempts,Called=selected,
                Error=not selected and tostring(err)or nil,
                EquippedAfter=HUD.equipped()})
        end
        api.WaitingEquipAttempts=waitingEquipAttempts
        api.WaitingMagnetEquipped=waiting and HUD.equipped()=="Magnet"
        -- Movement during the hidden intro is not proof of server mining.
        -- Record actual pickup feedback and replicated mound permission so
        -- early countdown improvements can be compared to genuine progress.
        if role=="Game"and mode~="Endless"and phase=="Waiting"
            and os.clock()>=nextWaitingSnapshot then
            nextWaitingSnapshot=os.clock()+5
            local char=player.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            record("RoundStartPickupProbe",{
                MoundLocked=State.run("MoundLocked",false),
                BagCount=player:GetAttribute("BagCount"),
                EarlyIntroStatus=Pickup.EarlyIntroStatus,
                EarlyPickupAttempts=Pickup.EarlyAttempts,
                EarlyPickupConfirmed=Pickup.EarlyConfirmed,
                PickupRequests=Pickup.Requests,PickupFeedback=Pickup.Feedback,
                PickupItems=Pickup.Items,PickupEnabled=Pickup.Enabled,
                RootAnchored=root and root.Anchored or nil,
                WalkSpeed=hum and hum.WalkSpeed or nil})
        end
        if lastReplayRequestedAt>0 and role=="Game"and not escaped
            and (phase=="Waiting"or phase=="Mining")
            and tostring(run)~=lastReplayRequestedRun then
            api.ReplayTransitions+=1
            record("ReplayAccepted",{Run=tostring(run),Role=role,Phase=phase,
                SinceInputSeconds=os.clock()-lastReplayRequestedAt})
            lastReplayRequestedAt=0
        end
        -- Check the results UI BEFORE routing by Role/Phase. The escape
        -- overlay can briefly coexist with Lobby state during the countdown.
        local replayMatches,replayAvailable,replayCount,resultsVisible={},{},0,false
        -- The full HUD scan is unnecessary while a normal mining round is
        -- active; check frequently again on Escape/results/Lobby phases.
        if phase~="Mining"or escaped or not roundActive then
            replayMatches,replayAvailable,replayCount,resultsVisible=candidateList("Replay")
        end
        api.ResultPanelVisible=resultsVisible
        if resultsVisible or (#replayMatches>0 and
            (escaped or api.Stage=="Escaping"or api.Stage=="Replay"or phase=="Escape"))then
            if roundActive then
                stopRound()
                api.Rounds+=1
                record("EscapeResultsDetected",{Rounds=api.Rounds,Run=tostring(activeRun),
                    EscapedFlag=escaped,Phase=phase,Role=role,ResultsVisible=resultsVisible})
            end
            setStage("Replay","Escape results visible — clicking Play Again")
            tryClick("Replay",replayMatches,replayAvailable,replayCount,resultsVisible)
            -- In-memory replay attempts, no disk writes.
            return
        end
        if role~=lastObservedRole or phase~=lastObservedPhase then
            record("Phase",{Role=role,Phase=phase,Mode=mode,Escaped=escaped,Run=tostring(run)})
            lastObservedRole,lastObservedPhase=role,phase
        end
        if role=="Game"and mode=="Endless"then
            setStage("WaitingStandard","Auto Farm Escapes requires a standard round, not Endless")
            return
        elseif api.Stage=="WaitingStandard"and role=="Lobby"then
            setStage("Lobby","Waiting to join a standard round")
        end
        if role=="Game"and phase=="Mining"and not escaped and
            (not roundActive or api.Stage=="Replay"or api.Stage=="AwaitingRound"or api.Stage=="Lobby")then
            beginRound(run)
        end
        -- Enabling the loop mid-boss or mid-escape cannot retroactively turn
        -- in a bag, but should still complete the current escape and replay.
        if not roundActive and role=="Game"and not escaped
            and (phase=="Mother"or phase=="Escape")then
            roundActive=true;activeRun=run;turnInCompleted=false
            if not Escape.Enabled then Escape.Start()end
            if phase=="Mother"then Endless.SetEscapeFarm(true)end
            setStage(phase=="Mother"and"Boss"or"Escaping",
                "Joined an active round; completing escape before starting full cycles")
            record("JoinedLate",{Phase=phase,Run=tostring(run)})
        end
        if roundActive then
            if phase=="Mining" then
                if CrackSell.OneShotCompleted and not turnInCompleted then
                    turnInCompleted=true;api.TurnIns+=1
                    setStage("Sweeping","Single turn-in complete; returning to the lowest ring")
                    record("OneTimeSale",{CashGained=CrackSell.CashGained,TripSeconds=CrackSell.LastTripSeconds})
                elseif not turnInCompleted and not CrackSell.Enabled and not CrackSell.Busy then
                    local reason="One-time Crack & Sell failed: "..CrackSell.Status
                    record("TurnInBlocked",{Reason=reason})
                    api.Stop(reason)
                    return
                elseif not turnInCompleted then
                    api.Status="Collecting and completing the single turn-in: "..CrackSell.Status
                else
                    local count=tonumber(player:GetAttribute("BagCount"))or 0
                    local cap=tonumber(player:GetAttribute("BagCap"))or -1
                    if cap>=0 and count>=cap then
                        if api.Stage~="BagFull"then
                            record("BagFullAfterSingleSale",{Count=count,Capacity=cap})
                            Endless.SetEscapeFarm(false)
                        end
                        setStage("BagFull","Bag full after one turn-in; needs more capacity or another deposit")
                    else
                        if not Endless.EscapeFarm then Endless.SetEscapeFarm(true)end
                        setStage("Sweeping","Farming the lowest ring until Mother appears")
                    end
                end
            elseif phase=="Mother"and (State.run("MotherHP",0)or 0)>0 then
                if not Endless.EscapeFarm then Endless.SetEscapeFarm(true)end
                setStage("Boss","Fighting Mother boss using native GEO-MAG critical targeting")
            elseif phase=="Escape" then
                setStage("Escaping","Boss defeated; moving to exit")
                if not Escape.Enabled then Escape.Start()end
            end
            if escaped then
                stopRound()
                api.Rounds+=1
                setStage("Replay","Escape confirmed; waiting for Play Again")
                record("Escaped",{Rounds=api.Rounds,Run=tostring(activeRun)})
            end
        end
        if api.Stage=="Replay"then
            if role=="Lobby"then
                replayAttempts=0;nextReplayAt=0
                setStage("Lobby","Escaped; joining next round")
            elseif role=="Game"and phase=="Waiting"and not escaped then
                setStage("AwaitingRound","Next round loading")
            else
                tryClick("Replay",replayMatches,replayAvailable,replayCount,resultsVisible)
                -- Export replay details manually as needed.
            end
        elseif api.Stage=="Lobby"or api.Stage=="AwaitingRound"then
            if role=="Lobby"then
                if modeSelection then
                    local solo=candidateList("Solo")
                    if #solo>0 then tryClick("Solo")else tryClick("Lobby")end
                else
                    local play=candidateList("Lobby")
                    if #play>0 then tryClick("Lobby")
                    else
                        local solo=candidateList("Solo")
                        if #solo>0 then tryClick("Solo")
                        else tryClick("Lobby")end
                    end
                end
            elseif role=="Game"and phase=="Waiting"and mode~="Endless"then
                -- Arm native, server-verified intro pickup while the new
                -- round countdown runs. The pickup module permits only one
                -- trial before Mining unless the bag increase is confirmed.
                if not Pickup.Enabled then Pickup.Start()end
                setStage("AwaitingRound","Round-start countdown; testing early geode pickup if allowed")
            end
        end
    end
    function api.Export()
        return pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_farm_escapes_diagnostics.json",Http:JSONEncode({
                Version=1,Enabled=api.Enabled,Stage=api.Stage,Status=api.Status,
                Rounds=api.Rounds,Replays=api.Replays,ReplayTransitions=api.ReplayTransitions,
                Clicks=api.Clicks,TurnIns=api.TurnIns,
                LastClick=api.LastClick,LastError=api.LastError,Role=State.role(),
                Phase=State.run("Phase"),Mode=State.run("Mode"),
                Escaped=player:GetAttribute("Escaped")==true,Run=tostring(State.run("RunStart")),
                ActiveRun=tostring(activeRun),RoundActive=roundActive,
                OneShotCompleted=CrackSell.OneShotCompleted,CrackSellStatus=CrackSell.Status,
                SweepActive=Endless.EscapeFarm,SweepMode=Endless.WinSweepMode,
                SweepSpeed=Endless.WinSweepSpeed,SweepItemsPerSecond=Endless.WinSweepItemsPerSecond,
                SweepRadiusScale=Endless.WinSweepRadiusScale,
                SweepHeightRing=Endless.WinSweepHeightRing,
                SweepHeightOffset=Endless.WinSweepHeightOffset,
                SweepCoveragePass=Endless.WinSweepCoveragePass,
                SweepCoreRadius=Endless.WinSweepCoreRadius,
                SweepCoreItems=Endless.WinSweepCoreItems,
                SweepCompletedLaps=Endless.WinSweepCompletedLaps,
                SweepEarlyCoreSkips=Endless.WinSweepEarlyCoreSkips,
                SweepFirstFireWaitMs=Endless.WinSweepFirstFireWaitMs,
                SweepFireReady=Endless.WinSweepFireReady,
                LastCompletedWinSweep=Endless.LastWinSweep,
                IntroPickupStatus=Pickup.EarlyIntroStatus,
                IntroPickupAttempts=Pickup.EarlyAttempts,
                IntroPickupConfirmed=Pickup.EarlyConfirmed,
                IntroPickupItems=Pickup.Items,
                WaitingEquipAttempts=api.WaitingEquipAttempts,
                WaitingMagnetEquipped=api.WaitingMagnetEquipped,
                OwnedMagnet=State.set("Tools").Magnet==true,
                ReplayAttempts=replayAttempts,VisibleButtonCount=api.VisibleButtonCount,
                VisibleButtons=api.VisibleButtons,MatchingButtons=api.MatchingButtons,
                VisibleReplayLabels=api.VisibleReplayLabels,
                ResultPanelVisible=api.ResultPanelVisible,LastClickMethod=api.LastClickMethod,
                ReplayLastInputRun=lastReplayRequestedRun,ReplayLastInputAt=lastReplayRequestedAt,
                ClickBackends={VirtualInputManager=okVIM and vim~=nil,
                    VirtualUser=okVU and virtualUser~=nil,Firesignal=type(firesignal)=="function"},
                Events=events,
                Note="Replay controls may be ImageButtons, separate labels or label-only click targets. The system prioritizes visible YOU ESCAPED/PLAY AGAIN UI before role/phase changes, tries several input backends and caps each replay at five attempts. A ClickSent event is not proof of an accepted replay; check whether the game transitions. Teleport queue depends on executor support."
            }))
        end)
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then
                api.LastError=tostring(err)
                api.Status="Escape loop check error: "..api.LastError
                record("Error",api.LastError)
            end
            task.wait((api.Stage=="Replay"or api.Stage=="Escaping")and .055 or .12)
        end
    end)
    return api
end

local FarmEscapes=createAutoFarmEscapesController()
OtherModeAbility.SetEscapeFarmProvider(function()return FarmEscapes.Enabled end)
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
        if c.Adaptive then
            -- Compare the real cards and their game-defined effects against
            -- the run's current bottleneck, rather than using a fixed card list.
            local neutral=table.clone(c)
            neutral.Adaptive=false;neutral.DamageFocus=false
            local fallback=ranker.Score(def,stacks,neutral)or 0
            local runway=math.max(0,tonumber(c.OilRunway)or 0)
            local depthTime=math.max(10,tonumber(c.DepthSeconds)or 60)
            local previousBoss=math.max(0,tonumber(c.LastBossSeconds)or 0)
            local timerPressure=math.clamp((depthTime*2.8-runway)/(depthTime*2.8),0,1)
            local bossPressure=math.max(
                math.clamp(((tonumber(c.Depth)or 1)-10)/60,0,1),
                math.clamp((previousBoss-10)/35,0,1))
            local bossWeight=math.clamp(.54+.26*bossPressure+.14*timerPressure,.54,.9)
            if c.Phase=="Mother"then bossWeight=.95 end
            local mineWeight=1-bossWeight
            local pileGain=math.max(0,tonumber(bonus.PileDamage)or 0)*stacks/
                math.max(10,100+(tonumber(mods.PileDamage)or 0))
            local bossGain=math.max(0,tonumber(bonus.BossDamage)or 0)*stacks/
                math.max(10,100+(tonumber(mods.BossDamage)or 0))
            local extraPower=(tonumber(bonus.Power)or tonumber(def.BossPower)or 0)*stacks
            local currentPower=math.max(1,tonumber(c.CrackPowerPercent)or 100)
            local powerGain=extraPower>0 and
                math.max(0,math.sqrt((currentPower+extraPower)/currentPower)-1)or 0
            local speed=tonumber(bonus.PickSpeed)or(id=="Momentum"and 20 or 0)
            local rateGain=0
            if speed>0 and not capped then
                local old=math.max(floor,tonumber(c.NativeCooldown)or floor)
                local oldBonus=math.max(1,100+(tonumber(mods.PickSpeed)or 0))
                local projected=math.max(floor,old*oldBonus/(oldBonus+speed*stacks))
                rateGain=math.max(0,old/projected-1)
            end
            local critGain=0
            for modifier,value in pairs(bonus)do
                if type(modifier)=="string"and modifier:lower():find("crit",1,true)
                    and type(value)=="number"and value>0 then
                    critGain=critGain+value*stacks/math.max(10,100+(tonumber(mods[modifier])or 0))
                end
            end
            -- Each stat uses diminishing relative returns from the live build.
            -- Boss strength matters increasingly as measured boss fights lengthen.
            local mineGain=pileGain+powerGain+rateGain
            local fightGain=bossGain+powerGain+rateGain+critGain*.7
            local effective=mineWeight*mineGain+bossWeight*fightGain
            local score=math.max(0,fallback*.50)
            local reason="Low immediate impact on timed Endless progression"
            local function prefer(value,why)
                if value>score then score,reason=value,why end
            end
            if effective>.0001 then
                local tag=fightGain>mineGain and
                    "Boss damage / attack throughput"or"Mining speed / damage throughput"
                prefer(85+math.min(170,effective*490),
                    string.format("%s (boss %.0f%%, mine %.0f%% priority; timer pressure %.0f%%)",
                        tag,bossWeight*100,mineWeight*100,timerPressure*100))
            end
            if id=="Shortcut"then
                prefer(91+mineWeight*48+math.min(16,depthTime/8),
                    "Less mound work before each timed boss encounter")
            elseif id=="ChainReaction"then
                prefer(83+mineWeight*48,"Splash damage clears geodes earlier")
            elseif id=="WideSweep"then
                local radius=math.max(0,tonumber(mods.Radius)or 0)
                prefer(70+mineWeight*40-math.min(25,radius*.12),
                    "Collection reach can reduce mining time")
            end
            if c.AbilitiesActive then
                if id=="AbilityDamage"then
                    prefer(112+bossWeight*54,"More native Overcharge damage against bosses")
                elseif id=="AbilityCooldown"and
                    (not c.AbilityStats or (tonumber(c.AbilityStats.Cooldown)or math.huge)>15.75)then
                    prefer(99+bossWeight*42,"More Overcharge uses before time expires")
                elseif id=="AbilityDuration"then
                    prefer(88+bossWeight*35,"Longer Overcharge uptime")
                elseif id=="AbilitySize"then
                    prefer(76+mineWeight*35,"Overcharge covers more geodes")
                end
            end
            local oilLeft=math.max(0,tonumber(c.OilLeft)or 0)
            local maxOil=math.max(1,tonumber(c.OilMax)or 600)
            local shortage=math.max(0,maxOil-oilLeft)
            if id=="SpareOil"or id=="SecondWind"then
                local refill=math.min(math.max(0,tonumber(def.Oil)or 0),shortage)
                if refill>0 and runway<math.max(90,depthTime*1.35)then
                    prefer(285+math.min(60,refill/8),
                        "Emergency: immediate fuel prevents the Endless timer expiring")
                else
                    prefer(refill>0 and 18+math.min(45,refill/15)or 0,
                        "One-time lantern refill; save priority for when time is critical")
                end
            elseif id=="OilFlask"then
                local burnPerDepth=depthTime*math.max(.05,tonumber(c.LanternRate)or 1)
                local recurring=math.max(0,tonumber(c.OilPerDepth)or 0)
                if recurring<burnPerDepth then
                    prefer(85+timerPressure*100+math.min(30,15/math.max(1,burnPerDepth)*45),
                        "Recurring lantern fuel offsets the per-depth timer")
                end
            elseif id=="EternalFlame"then
                prefer(88+timerPressure*100,
                    "Slower lantern consumption extends time for future bosses")
            elseif id=="LanternWick"then
                prefer(67+timerPressure*75,
                    "Reduced fuel drain preserves time across depths")
            elseif id=="SecondLantern"then
                prefer(48+timerPressure*65,
                    "Emergency lantern backup for a long timed run")
            end
            if id=="DeepPockets"and c.BagCapacity==-1 then
                return 0,"Unlimited bag already owned; no capacity gain"
            end
            if id=="AbilityCooldown"and c.AbilityStats and
                (tonumber(c.AbilityStats.Cooldown)or math.huge)<=15.75 then
                return 0,"Overcharge cooldown already at its minimum"
            end
            return score,reason
        end
        if c.DamageFocus then
            -- Experimental maximum-DPS rankings use the game's actual perk
            -- modifier fields. No client damage or critical-hit values are
            -- fabricated; the server still determines attack outcomes.
            local pile=tonumber(bonus.PileDamage)or 0
            local boss=tonumber(bonus.BossDamage)or 0
            local power=tonumber(bonus.Power)or tonumber(def.BossPower)or 0
            local speed=tonumber(bonus.PickSpeed)or (id=="Momentum"and 20 or 0)
            local depth=tonumber(c.Depth)or 1
            local score,reason=5,"Not a direct damage or attack-rate increase"
            local function best(value,description)
                if value>score then score,reason=value,description end
            end
            local pileGain=math.max(0,pile)*stacks/math.max(10,100+(tonumber(mods.PileDamage)or 0))
            local bossGain=math.max(0,boss)*stacks/math.max(10,100+(tonumber(mods.BossDamage)or 0))
            -- Discover crit-related modifier fields from the game itself
            -- rather than assuming a particular critical-hit property exists.
            for modifier,value in pairs(bonus)do
                if type(modifier)=="string"and modifier:lower():find("crit",1,true)
                    and type(value)=="number"and value>0 then
                    local current=tonumber(mods[modifier])or 0
                    local gain=value*stacks/math.max(10,100+current)
                    best(175+math.min(75,gain*260),"Game-defined critical modifier: "..modifier)
                end
            end
            if pileGain>0 then
                best(135+math.min(85,pileGain*240),"More direct geode/pile damage")
            end
            if bossGain>0 then
                best((depth>=20 and 138 or 123)+math.min(85,bossGain*240),"More direct boss damage")
            end
            if power>0 then
                local effective=math.max(1,tonumber(c.CrackPowerPercent)or 100)
                local relative=math.sqrt((effective+power*stacks)/effective)-1
                best((depth>=20 and 132 or 125)+math.min(80,math.max(0,relative)*260),
                    "Higher attack power and boss crack damage")
            end
            if speed>0 and not capped then
                local old=math.max(floor,tonumber(c.NativeCooldown)or floor)
                local oldBonus=100+(tonumber(mods.PickSpeed)or 0)
                local projected=math.max(floor,old*oldBonus/math.max(1,oldBonus+speed*stacks))
                local rateGain=math.max(0,old/projected-1)
                if rateGain>.0001 then
                    best(140+math.min(80,rateGain*250),"Higher native attack rate; respects cooldown floor")
                end
            end
            if id=="ChainReaction"then best(128,"Nearby geode splash damage")end
            if id=="AbilityDamage"and c.AbilitiesActive then
                best(145,"Higher Overcharge damage")
            elseif id=="AbilityCooldown"and c.AbilitiesActive
                and c.AbilityStats and c.AbilityStats.Cooldown>15.75 then
                best(130,"More frequent Overcharge uses")
            elseif id=="AbilityDuration"and c.AbilitiesActive then
                best(122,"Longer Overcharge uptime")
            elseif id=="AbilitySize"and c.AbilitiesActive then
                best(115,"Larger Overcharge damage area")
            end
            -- Preserve the existing emergency oil decision: a prevented run
            -- failure is worth more than a small DPS boost.
            if id=="SpareOil"or id=="SecondWind"then
                local oil=math.min(tonumber(def.Oil)or 0,math.max(0,(c.OilMax or 600)-(c.OilLeft or 0)))
                if oil>0 and (c.OilLeft or 600)/math.max(.1,c.LanternRate or 1)<60 then
                    best(300+oil/10,"Emergency lantern oil to keep the run alive")
                end
            end
            return score,reason
        end
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
    local damageFocus=false
    local adaptive=true
    local events={};local dirty=false;local ownedRaw;local owned={}
    local lastDepth;local depthAt=os.clock();local depthSeconds=60
    local lastRun;local lastPhase;local bossEnteredAt;local lastBossSeconds
    local function focusLabel()
        if adaptive then return "Adaptive: timed Endless" end
        return damageFocus and "Legacy maximum damage" or "Legacy balanced"
    end
    local function observedTimerAttributes()
        -- Passive diagnostic only: timer-like attribute names are not assumed
        -- to represent a boss deadline until the game semantics are verified.
        local state=M:FindFirstChild("State")
        local values={}
        if state then
            for name,value in pairs(state:GetAttributes())do
                local lower=name:lower()
                if type(value)=="number"and
                    (lower:find("timer",1,true)or lower:find("timeleft",1,true)
                        or lower:find("deadline",1,true)or lower:find("remaining",1,true))then
                    values[name]=value
                end
            end
        end
        return values
    end
    local function context()
        local raw=P:GetAttribute("Perks")or"{}"
        if raw~=ownedRaw then
            ownedRaw=raw
            local ok,data=pcall(H.JSONDecode,H,raw);owned=ok and type(data)=="table"and data or {}
        end
        local run=S.run("RunStart","")
        local phase=S.run("Phase","")
        local now=os.clock()
        if run~=lastRun then
            lastRun=run;lastDepth=nil;lastPhase=nil
            depthAt=now;depthSeconds=60;bossEnteredAt=nil;lastBossSeconds=nil
        end
        local depth=tonumber(S.run("Depth",1))or 1
        if lastDepth and lastDepth~=depth then
            depthSeconds=math.clamp(now-depthAt,1,180)
            depthAt=now
        end
        lastDepth=depth
        if phase=="Mother"then
            if (tonumber(S.run("MotherHP",0))or 0)>0 then
                if not bossEnteredAt then bossEnteredAt=now end
            elseif bossEnteredAt then
                lastBossSeconds=math.clamp(now-bossEnteredAt,1,180)
                bossEnteredAt=nil
            end
        elseif lastPhase=="Mother"and bossEnteredAt then
            lastBossSeconds=math.clamp(now-bossEnteredAt,1,180)
            bossEnteredAt=nil
        end
        lastPhase=phase
        local ctx=S.ctx();local tool=Stats.tool(ctx,"Magnet")
        local plus=table.clone(ctx);plus.Mods=table.clone(ctx.Mods or{});plus.Mods.Power=(plus.Mods.Power or 0)+100
        local power=Stats.crackPower(ctx);local delta=Stats.crackPower(plus)-power
        local state=Cards._debug and Cards._debug.P
        local offer=state and state.Offer
        return {Endless=S.role()=="Game"and S.run("Mode")=="Endless"and S.run("Ended",false)~=true and S.run("EndlessOver",false)~=true,ToolOwned=S.set("Tools").Magnet==true,
            Ready=state and state.Open and state.Ready and not state.Picked,
            Offer=offer and offer.Offer,Key=offer and offer.Offer~=nil and(game.JobId..":"..tostring(S.run("RunStart"))..":"..tostring(offer.Offer)..":"..tostring(state.Token)),
            Test=offer and offer.Test,Cards=offer and offer.Cards,Until=offer and tonumber(offer.Until),ServerNow=workspace:GetServerTimeNow(),
            Owned=owned,Mods=ctx.Mods,Depth=depth,Phase=phase,
            OilLeft=tonumber(S.run("LanternLeft",0))or 0,OilMax=E.Lantern.Max,
            LanternRate=tonumber(S.run("LanternRate",1))or 1,
            OilRunway=(tonumber(S.run("LanternLeft",0))or 0)/math.max(.05,tonumber(S.run("LanternRate",1))or 1),
            OilPerDepth=(owned.OilFlask or 0)*15,DepthSeconds=depthSeconds,
            LastBossSeconds=lastBossSeconds,
            BagCapacity=P:GetAttribute("BagCap"),NativeCooldown=tool.Cooldown*Tools.paceMult("Magnet"),
            RequestFloor=Endless and Endless.Enabled and S.run("Mode")=="Endless"and math.clamp(Endless.FrameInterval or 1/60,.001,.1)or .05,
            AbilitiesActive=Endless and Endless.Enabled and Endless.AbilityAvailable,AbilityStats=Endless and Endless.AbilityStats,
            CrackPowerPercent=delta>0 and power*100/delta or 100,MagnetMaxed=MagnetUpgrades.IsMaxed(),
            DamageFocus=damageFocus,Adaptive=adaptive}
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
    api.DamageFocus=false
    api.Adaptive=true
    function api.SetAdaptive(value)
        adaptive=value==true
        api.Adaptive=adaptive
        api.FocusMode=focusLabel()
    end
    function api.SetDamageFocus(value)
        damageFocus=value==true
        api.DamageFocus=damageFocus
        api.FocusMode=focusLabel()
    end
    api.FocusMode=focusLabel()
    local connection=M.Remotes.Endless.OnClientEvent:Connect(function(message)
        if type(message)=="table"and message.Type=="Picked"then api.Confirm(message)end
    end)
    function api.Export()
        return pcall(function()
            local c=context();local all={};local critFields={}
            for _,def in ipairs(E.Perks)do
                all[#all+1]={Id=def.Id,Rarity=def.Rarity}
                local fields={}
                for key,value in pairs(def.Mods or {})do
                    if type(key)=="string"and key:lower():find("crit",1,true)then
                        fields[#fields+1]={Key=key,Value=value}
                    end
                end
                if #fields>0 then critFields[#critFields+1]={Id=def.Id,Name=def.Name,Fields=fields}end
            end
            local _,ranking=choose(all,c)
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_perk_diagnostics.json",H:JSONEncode({Version=1,Enabled=api.Enabled,Status=api.Status,Requests=api.Requests,Confirmed=api.Confirmed,
                LastChoice=api.LastChoice,LastOfferRanking=api.LastRanking,DefaultRarityRanking=ranking,
                DamageFocus=api.DamageFocus,Adaptive=api.Adaptive,FocusMode=api.FocusMode,GameDefinedCriticalPerks=critFields,
                Context={DamageFocus=c.DamageFocus,Adaptive=c.Adaptive,Phase=c.Phase,Depth=c.Depth,
                    OilLeft=c.OilLeft,OilRunway=c.OilRunway,LanternRate=c.LanternRate,LastBossSeconds=c.LastBossSeconds,ObservedTimerAttributes=observedTimerAttributes(),NativeCooldown=c.NativeCooldown,RequestFloor=c.RequestFloor,
                    BagCapacity=c.BagCapacity,MagnetMaxed=c.MagnetMaxed,CrackPowerPercent=c.CrackPowerPercent,OilPerDepth=c.OilPerDepth,DepthSeconds=c.DepthSeconds,Owned=c.Owned,Mods=c.Mods,AbilitiesActive=c.AbilitiesActive,AbilityStats=c.AbilityStats},Events=events,
                Note="Adaptive mode evaluates the offered three server-defined cards by estimated tool damage, boss-vs-mining bottlenecks, depth, lantern time remaining, prior boss duration, cooldown floors and oil emergencies. LanternLeft/LanternRate is a measured fuel runway, not an independently verified boss deadline. Legacy modes remain optional. No rerolls or guaranteed critical hits."}))
            dirty=false
        end)
    end
    local unload=api.Unload
    function api.Unload()unload();connection:Disconnect()end
    task.spawn(function()
                while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then api.Stop();api.Status="Perk error: "..tostring(err)end
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
        ok,source=pcall(function()return game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/geode-mirror/loader-beyy.lua?refresh="..tostring(os.time()))end)
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
FarmEscapes.SetWindow(Window)
local Hub={Running=true,Version="1.10.45",Window=Window,Pickup=Pickup,Eggs=Eggs,ClassMutations=ClassMutations,CrackSell=CrackSell,MagnetUpgrades=MagnetUpgrades,Escape=Escape,Endless=Endless,OtherModeAbility=OtherModeAbility,AbilityPrefs=abilityPrefs,GameWalkSpeed=GameWalkSpeed,IntroVisuals=IntroVisuals,AntiAFK=AntiAFK,AutoPerks=AutoPerks,FarmEscapes=FarmEscapes}
Window.Gui:SetAttribute("GeodeSessionVersion",Hub.Version)
env.GeodeHub=Hub
function Hub.Unload()
    if not Hub.Running then return end
    Hub.Running=false
    FarmEscapes.Unload()
    ClassMutations.Unload()
    AutoPerks.Unload()
    OtherModeAbility.Unload()
    Endless.Unload()
    GameWalkSpeed.Unload()
    IntroVisuals.Unload()
    AntiAFK.Unload()
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
local statusTab=overview:Tab({Title="Status & Logs"})
local settings=overview:Tab({Title="Settings"})
endlessTab:Section({Title="Endless Farming"})
local endlessToggle=endlessTab:Toggle({Title="Auto Endless Mode",Value=false,Callback=function(value)
    if value then Endless.Start()else Endless.Stop()end
end})
local hoverHeight=endlessTab:Slider({Title="Endless Hover Clearance (studs)",Step=.5,Value={Min=2,Max=20,Default=6.5},Callback=function(value)Endless.SetHover(value)end})
local endlessStatus=endlessTab:Paragraph({Title="Endless Status",Desc="Paused — manages pickup, camp visits, upgrades and boss weak points in Endless mode."})
local bossCritToggle=endlessTab:Toggle({Title="Auto Boss Criticals",Value=true,Callback=function(value)
    Endless.SetBossAssist(value)
end})
endlessTab:Paragraph({Title="Boss Assistance",Desc="Active whenever this hub is loaded, even with Auto Endless off. Targets exposed Mother weak points and fires normally while waiting for one. Requires GEO-MAG 3000."})
local endlessExtras=endlessTab:CollapsibleGroup({Title="Advanced Boss & Perk Options",Opened=false})
local rapidBossToggle=endlessExtras:Toggle({Title="Rapid Boss Attacks (Test)",Value=false,Callback=function(value)
    Endless.SetRapidBoss(value)
end})
local rapidBossInterval=endlessExtras:Slider({Title="Boss Input Interval (seconds)",Step=.05,Value={Min=.05,Max=.25,Default=.05},Callback=function(value)
    Endless.SetRapidBossInterval(value)
end})
endlessTab:Paragraph({Title="Rapid Boss Test",Desc="Reasserts the native attack-held input up to 20 times/sec during a boss fight. Does not send direct boss RemoteEvents or guarantee extra server hits. Compare observed hits/second with the toggle off and on."})
local damageFocusToggle=endlessExtras:Toggle({Title="Legacy Damage Ranking (Adaptive Off)",Value=false,Callback=function(value)
    AutoPerks.SetDamageFocus(value)
end})
endlessTab:Paragraph({Title="Damage Priority",Desc="Only changes future Auto Select Perk decisions in Endless mode. Prefers direct damage, boss damage, power and useful tool speed; preserves emergency oil. Does not force critical hits."})
local perkToggle=endlessTab:Toggle({Title="Auto Select Perk",Value=false,Callback=function(value)
    if value then AutoPerks.Start()else AutoPerks.Stop()end
end})
local adaptivePerksToggle=endlessTab:Toggle({Title="Adaptive Timed Perk Selection",Value=true,Callback=function(value)
    AutoPerks.SetAdaptive(value)
end})
local perkStatus=endlessTab:Paragraph({Title="Perk Selection Status",Desc="Scores the three actual cards for timed Endless runs: boss damage, clear speed and fuel survival; logs each ranked choice."})
main:Section({Title="Auto Farm Escapes"})
local farmEscapesToggle=main:Toggle({Title="Auto Farm Escapes",Value=false,Callback=function(value)
    if value then FarmEscapes.Start()else FarmEscapes.Stop()end
end})
local farmEscapesStatus=main:Paragraph({Title="Auto Farm Escapes Status",Desc="Paused. Outer base lap, +2-stud lap, then a tight boss-center pillar pass. Repeats automatically with native GEO-MAG pickup confirmation. Win Farm mining pitch is 14 degrees; Endless remains 9 degrees."})
main:Section({Title="Character Movement"})
local walkSpeedToggle=main:Toggle({Title="4x WalkSpeed",Value=true,Callback=function(value)
    GameWalkSpeed.SetEnabled(value)
end})
local walkSpeedStatus=statusTab:Paragraph({Title="WalkSpeed Status",Desc="Automatically quadruples normal walking speed while playing; restores when leaving the game."})
main:Section({Title="Geode Collection"})
local pickupToggle=main:Toggle({Title="Auto Geode Pickup",Value=false,Callback=function(value)
    if value then Pickup.Start()else Pickup.Stop()end
end})
local collectionExtras=main:CollapsibleGroup({Title="Advanced Pickup Options",Opened=false})
local fastPickupToggle=collectionExtras:Toggle({Title="Fast Geode Pickup",Value=true,Callback=function(value)
    Pickup.SetFastPickup(value)
end})
local pickupRange=collectionExtras:Slider({Title="Pickup Range (studs)",Step=1,Value={Min=1,Max=26,Default=26},Callback=function(value)
    Pickup.SetRange(0,value)
end})
local live=statusTab:Paragraph({Title="Pickup Status",Desc="Paused — enable Auto Geode Pickup to begin."})
main:Section({Title="Cracking & Selling"})
local crackToggle=main:Toggle({Title="Auto Crack and Sell",Value=false,Callback=function(value)
    if value then CrackSell.Start()elseif CrackSell.Enabled then CrackSell.Stop("Manually paused Crack & Sell")end
end})
local cycleInterval=main:Slider({Title="Crack Delay (seconds)",Step=.05,Value={Min=.10,Max=60,Default=1},Callback=function(value)
    CrackSell.SetInterval(value)
end})
local continuousCrack=main:Toggle({Title="Keep Cracking & Selling",Value=false,Callback=function(value)
    CrackSell.SetContinuous(value)
end})
local crackExtras=main:CollapsibleGroup({Title="Advanced Crack & Sell Options",Opened=false})
local fastCrackTravel=crackExtras:Toggle({Title="Fast Camp Teleport",Value=true,Callback=function(value)
    CrackSell.SetFastTravel(value)
end})
local turboCrack=crackExtras:Toggle({Title="Turbo Crack & Sell",Value=true,Callback=function(value)
    CrackSell.SetTurbo(value)
end})
local repeatInterval=crackExtras:Slider({Title="Repeat Delay (seconds)",Step=1,Value={Min=1,Max=60,Default=10},Callback=function(value)
    CrackSell.SetRepeatInterval(value)
end})
local crackStatus=statusTab:Paragraph({Title="Crack & Sell Status",Desc="Paused — returns to your pickup position after each cycle."})
main:Paragraph({Title="Crack & Sell Timing",Desc="Choose a bag-change delay from 0.10 seconds (default 1). Turbo responds to server acknowledgements and cash updates immediately; empty bins alone never confirm a sale. Disable Turbo if prompts are missed. Auto Farm Escapes uses the same delay; one trip per activation unless continuous mode is enabled."})
main:Section({Title="Escape"})
local escapeToggle=main:Toggle({Title="Auto Escape",Value=false,Callback=function(value)
    if value then Escape.Start()else Escape.Stop()end
end})
local escapeStatus=statusTab:Paragraph({Title="Escape Status",Desc="Auto Escape uses the server-open lift. Lift diagnostics are available through the manual Export Debug Diagnostics button."})
eggs:Section({Title="Candy Shop"})
main:Section({Title="GEO-MAG 3000 Upgrades"})
local upgradeToggle=main:Toggle({Title="Auto GEO-MAG Upgrades",Value=false,Callback=function(value)
    if value then MagnetUpgrades.Start()else MagnetUpgrades.Stop()end
end})
local upgradeExtras=main:CollapsibleGroup({Title="Advanced Upgrade Options",Opened=false})
local powerFirstToggle=upgradeExtras:Toggle({Title="Prioritize Pull Power",Value=true,Callback=function(value)
    MagnetUpgrades.SetPowerFirst(value)
end})
local fastUpgradeToggle=upgradeExtras:Toggle({Title="Fast Upgrade Purchases",Value=true,Callback=function(value)
    MagnetUpgrades.SetFastPurchases(value)
end})
local upgradeStatus=statusTab:Paragraph({Title="Magnet Upgrade Status",Desc="Fast mode checks confirmations every 0.025s and requests the next affordable upgrade at least 0.05s after the previous response, without overlapping purchases."})
main:Section({Title="Native GEO-MAG Ability"})
local abilityExtras=main:CollapsibleGroup({Title="Overcharge Preferences",Opened=false})
local normalAbilityToggle=abilityExtras:Toggle({Title="Overcharge in Mining",Value=true,Callback=function(value)
    abilityPrefs.NormalMining=value==true
end})
local bossAbilityToggle=abilityExtras:Toggle({Title="Overcharge on Boss Spawn",Value=true,Callback=function(value)
    abilityPrefs.BossOnSpawn=value==true
end})
local reserveBossAbilityToggle=abilityExtras:Toggle({Title="Reserve Overcharge for Boss",Value=true,Callback=function(value)
    abilityPrefs.ReserveForBoss=value==true
end})
local escapeOverchargeToggle=abilityExtras:Toggle({Title="Escape Farm: Auto Overcharge",Value=true,Callback=function(value)
    abilityPrefs.EscapeFarmAlways=value==true
end})
main:Paragraph({Title="Ability Timing",Desc="Auto Farm Escapes uses native Overcharge whenever eligible in Mining or Mother (default ON), ignoring boss reservation only for escape farming. Normal play and Auto Endless keep the boss-first setting. Cooldowns, unlock requirements, camp, menu and server acceptance remain authoritative."})
local otherAbilityStatus=statusTab:Paragraph({Title="GEO-MAG Ability Status",Desc="Waiting for eligible mode. Uses native server-confirmed activation."})
local eggToggle=eggs:Toggle({Title="Auto Open Haunted Egg",Value=false,Callback=function(value)
    if value then Eggs.Start()else Eggs.Stop()end
end})
local eggStatus=eggs:Paragraph({Title="Egg Status",Desc="Paused. Opens 3 eggs per batch for 180 candy."})
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
settings:Section({Title="AFK Protection"})
local antiAfkToggle=settings:Toggle({Title="Anti AFK (Lobby & All Rounds)",Value=true,Callback=function(value)
    AntiAFK.SetEnabled(value)
end})
local antiAfkStatus=statusTab:Paragraph({Title="Anti AFK Status",Desc="Armed in lobby and all rounds; uses an idle-triggered virtual input and a quiet-activity watchdog."})
settings:Section({Title="Loading Cutscene"})
local skipIntroToggle=settings:Toggle({Title="Hide Chapter Loading Cutscene",Value=true,Callback=function(value)
    IntroVisuals.SetEnabled(value)
end})
local introStatus=statusTab:Paragraph({Title="Intro Suppression",Desc="Moves loading and intro visuals offscreen without disabling the game's UI."})
local introExtras=settings:CollapsibleGroup({Title="Experimental Intro Pickup",Opened=false})
local earlyPickupToggle=introExtras:Toggle({Title="Try Pickup During Intro",Value=true,Callback=function(value)
    Pickup.SetEarlyIntro(value)
end})
local earlyPickupStatus=statusTab:Paragraph({Title="Early Pickup",Desc="One test request while Waiting. Continues only if the bag increases before normal Mining; otherwise waits and resumes when Mining starts."})
settings:Section({Title="Configuration"})
local config=Window.ConfigManager:CreateConfig("default")
local autoLoad=settings:Toggle({Title="Auto-load Saved Config",Value=true,Callback=function()end})
config:Register("AutoLoadConfig",autoLoad)
config:Register("WalkSpeedTriple",walkSpeedToggle)
config:Register("AntiAFK",antiAfkToggle)
config:Register("HideChapterIntro",skipIntroToggle)
config:Register("EarlyIntroPickup",earlyPickupToggle)
config:Register("AutoGeodePickup",pickupToggle)
config:Register("FastGeodePickup",fastPickupToggle)
config:Register("PickupRange",pickupRange)
config:Register("AutoOpenHauntedEgg",eggToggle)
config:Register("AutoCrackAndSell",crackToggle)
config:Register("CrackSellBagDelay",cycleInterval)
config:Register("CrackSellContinuous",continuousCrack)
config:Register("FastCrackTravel",fastCrackTravel)
config:Register("TurboCrackSell",turboCrack)
config:Register("CrackSellRepeatInterval",repeatInterval)
config:Register("AutoUpgradeMagnet",upgradeToggle)
config:Register("PowerFirst",powerFirstToggle)
config:Register("FastUpgradePurchases",fastUpgradeToggle)
config:Register("NormalMiningAbility",normalAbilityToggle)
config:Register("BossSpawnAbility",bossAbilityToggle)
config:Register("ReserveBossAbility",reserveBossAbilityToggle)
config:Register("EscapeFarmOvercharge",escapeOverchargeToggle)
config:Register("AutoEscape",escapeToggle)
config:Register("EndlessHover",hoverHeight)
config:Register("AutoEndless",endlessToggle)
config:Register("AutoBossCrit",bossCritToggle)
config:Register("RapidBossInput",rapidBossToggle)
config:Register("RapidBossInterval",rapidBossInterval)
config:Register("AutoSelectPerk",perkToggle)
config:Register("AdaptivePerks",adaptivePerksToggle)
config:Register("AutoFarmEscapes",farmEscapesToggle)
config:Register("MaximumDamagePerks",damageFocusToggle)
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
statusTab:Section({Title="On-Demand Diagnostics"})
-- This is the investigation currently being worked on. Changing the focus
-- selects relevant existing reports; it NEVER enables background file writes.
local debugChoices={
    "Auto Win Farm / Center Geodes","Auto / Current Active Feature",
    "Auto Endless / Farming","Pickup / Intro Countdown",
    "Replay / Play Again","Crack & Sell / Upgrades",
    "Escape / Elevator","Boss / Overcharge","Auto Perks",
    "Haunted Eggs","Anti AFK","Everything (Manual)"
}
local debugFocus=statusTab:Dropdown({Title="Debug Focus",Values=debugChoices,
    Value="Auto Win Farm / Center Geodes",
    Callback=function(value)Hub.DebugFocus=value end})
Hub.DebugFocus=debugFocus.Value
statusTab:Paragraph({Title="Export Only When Requested",
    Desc="No diagnostic autosave, no repeated replay exports and no passive elevator/HUD recorder. Choose the current problem, then press Export Debug Diagnostics. The button writes only those relevant reports and a small manifest to Geode/."})
statusTab:Button({Title="Export Debug Diagnostics",Callback=function()
    local source={
        Farm={Name="Auto Win Farm",Export=FarmEscapes.Export,Files={"auto_farm_escapes_diagnostics.json"}},
        Endless={Name="Orbit and center pillar",Export=Endless.Export,Files={"auto_endless_diagnostics.json"}},
        Pickup={Name="Pickup",Export=Pickup.Export,Files={"auto_pickup_diagnostics.json"}},
        Crack={Name="Crack & Sell",Export=CrackSell.Export,Files={"auto_crack_sell_diagnostics.json"}},
        Upgrade={Name="GEO-MAG Upgrades",Export=MagnetUpgrades.Export,Files={"magnet_upgrade_diagnostics.json"}},
        Escape={Name="Escape and Lift",Export=Escape.Export,Files={"auto_escape_diagnostics.json","elevator_lock_diagnostics.json"}},
        Perks={Name="Perks",Export=AutoPerks.Export,Files={"auto_perk_diagnostics.json"}},
        Eggs={Name="Haunted Eggs",Export=Eggs.Export,Files={"haunted_egg_diagnostics.json"}},
        Boss={Name="Overcharge",Export=OtherModeAbility.Export,Files={"non_perk_damage_diagnostics.json"}},
        AFK={Name="Anti AFK",Export=AntiAFK.Export,Files={"anti_afk_diagnostics.json"}}
    }
    local routes={
        ["Auto Win Farm / Center Geodes"]={"Farm","Endless","Pickup"},
        ["Auto Endless / Farming"]={"Endless","Pickup"},
        ["Pickup / Intro Countdown"]={"Pickup","Farm"},
        ["Replay / Play Again"]={"Farm","Escape"},
        ["Crack & Sell / Upgrades"]={"Crack","Upgrade"},
        ["Escape / Elevator"]={"Escape"},
        ["Boss / Overcharge"]={"Endless","Boss"},
        ["Auto Perks"]={"Perks"},
        ["Haunted Eggs"]={"Eggs"},
        ["Anti AFK"]={"AFK"},
        ["Everything (Manual)"]={"Farm","Endless","Pickup","Crack","Upgrade",
            "Escape","Boss","Perks","Eggs","AFK"}
    }
    local focus=debugFocus.Value
    if focus=="Auto / Current Active Feature"then
        if FarmEscapes.Enabled then focus="Auto Win Farm / Center Geodes"
        elseif Endless.Enabled then focus="Auto Endless / Farming"
        elseif CrackSell.Enabled or CrackSell.Busy then focus="Crack & Sell / Upgrades"
        elseif Escape.Enabled and State.run("Phase")=="Escape"then focus="Escape / Elevator"
        else focus="Pickup / Intro Countdown"end
    end
    local keys=routes[focus]or routes["Auto Win Farm / Center Geodes"]
    local saved,files,failures=0,{},{}
    for _,key in ipairs(keys)do
        local entry=source[key]
        local ok,result,reason=pcall(entry.Export)
        if ok and result then
            saved+=1
            for _,name in ipairs(entry.Files)do files[#files+1]=name end
        else
            failures[#failures+1]=entry.Name..": "..tostring(ok and reason or result)
        end
    end
    local manifestOK,manifestError=pcall(function()
        if not isfolder("Geode")then makefolder("Geode")end
        writefile("Geode/debug_capture_manifest.json",
            game:GetService("HttpService"):JSONEncode({
                Build=geodeVersion,RequestedFocus=debugFocus.Value,ResolvedFocus=focus,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                Phase=State.run("Phase"),Mode=State.run("Mode"),
                FarmStage=FarmEscapes.Stage,
                Run=tostring(State.run("RunStart")),Reports=files,
                ReportFunctionsSucceeded=saved,ReportFunctionsRequested=#keys,
                Errors=failures,LastCompletedWinSweep=Endless.LastWinSweep,
                CaptureMode="Manual button only; no background diagnostic file writes"
            }))
    end)
    if not manifestOK then failures[#failures+1]="Manifest: "..tostring(manifestError)end
    local message=string.format("%s: %d/%d reports saved to Geode/",
        focus,saved,#keys)
    if manifestOK then message=message.." + debug_capture_manifest.json"end
    if #failures>0 then message=message.."; "..table.concat(failures,"; ")end
    NativeUI:Notify({Title="Debug Export",Content=message})
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
    return {Pickup=Pickup.Enabled,FastPickup=Pickup.FastPickup,Range=Pickup.MaxRange,WalkSpeedTriple=GameWalkSpeed.Enabled,AntiAFK=AntiAFK.Enabled,HideChapterIntro=IntroVisuals.Enabled,EarlyIntroPickup=Pickup.EarlyIntroEnabled,Eggs=Eggs.Enabled,CrackSell=CrackSell.Enabled,
        BagDelay=CrackSell.Interval,CrackSellContinuous=(FarmEscapes.Enabled
            and FarmEscapes.PreviousContinuousMode~=nil)
            and FarmEscapes.PreviousContinuousMode or CrackSell.Continuous,
        FastCrackTravel=CrackSell.FastTravel,TurboCrackSell=CrackSell.Turbo,CrackSellRepeatInterval=CrackSell.RepeatInterval,MagnetUpgrades=MagnetUpgrades.Enabled,PowerFirst=MagnetUpgrades.PowerFirst,FastUpgradePurchases=MagnetUpgrades.FastPurchases,NormalMiningAbility=abilityPrefs.NormalMining,BossSpawnAbility=abilityPrefs.BossOnSpawn,ReserveBossAbility=abilityPrefs.ReserveForBoss,EscapeFarmOvercharge=abilityPrefs.EscapeFarmAlways,Escape=Escape.Enabled,AutoFarmEscapes=FarmEscapes.Enabled,Endless=Endless.Enabled,EndlessHover=Endless.Hover,BossAssist=Endless.BossAssist,RapidBoss=Endless.RapidBoss,RapidBossInterval=Endless.RapidBossInterval,AutoPerks=AutoPerks.Enabled,DamagePerks=AutoPerks.DamageFocus,AdaptivePerks=AutoPerks.Adaptive,DebugFocus=debugFocus.Value,LastWinSweep=Endless.LastWinSweep,MenuKey=Window.ToggleKey.Name,MenuClosed=Window.Closed}
end)
Hub.Teleport=continuation
FarmEscapes.SetQueueEnabler(function()
    if not continuation.Enabled then queueToggle:Set(true)end
end)
settings:Button({Title="Unload Hub",Callback=Hub.Unload})
local session=statusTab:Paragraph({Title="Session",Desc="Crack the Geode!"})
local resumed=env.__GeodeTeleportResume
env.__GeodeTeleportResume=nil
local loaded,loadError=config:Load(true,type(resumed)=="table"and resumed.GameId==10770110947)
if type(resumed)=="table"and resumed.GameId==10770110947 then
    walkSpeedToggle:Set(resumed.WalkSpeedTriple~=false)
    antiAfkToggle:Set(resumed.AntiAFK~=false)
    skipIntroToggle:Set(resumed.HideChapterIntro~=false)
    earlyPickupToggle:Set(resumed.EarlyIntroPickup~=false)
    fastPickupToggle:Set(resumed.FastPickup~=false)
    powerFirstToggle:Set(resumed.PowerFirst~=false)
    fastUpgradeToggle:Set(resumed.FastUpgradePurchases~=false)
    normalAbilityToggle:Set(resumed.NormalMiningAbility~=false)
    bossAbilityToggle:Set(resumed.BossSpawnAbility~=false)
    reserveBossAbilityToggle:Set(resumed.ReserveBossAbility~=false)
    escapeOverchargeToggle:Set(resumed.EscapeFarmOvercharge~=false)
    pickupRange:Set(tonumber(resumed.Range)or 26)
    cycleInterval:Set(tonumber(resumed.BagDelay)or 1)
    continuousCrack:Set(resumed.CrackSellContinuous==true)
    fastCrackTravel:Set(resumed.FastCrackTravel~=false)
    turboCrack:Set(resumed.TurboCrackSell~=false)
    repeatInterval:Set(tonumber(resumed.CrackSellRepeatInterval)or 10)
    hoverHeight:Set(tonumber(resumed.EndlessHover)or 6.5)
    bossCritToggle:Set(resumed.BossAssist~=false)
    rapidBossToggle:Set(resumed.RapidBoss==true)
    rapidBossInterval:Set(tonumber(resumed.RapidBossInterval)or .05)
    damageFocusToggle:Set(resumed.DamagePerks==true)
    adaptivePerksToggle:Set(resumed.AdaptivePerks~=false)
    if type(resumed.DebugFocus)=="string"and table.find(debugChoices,resumed.DebugFocus)then
        debugFocus:Select(resumed.DebugFocus)
    end
    if type(resumed.LastWinSweep)=="table"then
        Endless.LastWinSweep=resumed.LastWinSweep
    end
    if type(resumed.MenuKey)=="string"and Enum.KeyCode[resumed.MenuKey]then menuKey:Set(resumed.MenuKey)end
    pickupToggle:Set(resumed.Pickup==true)
    eggToggle:Set(resumed.Eggs==true)
    crackToggle:Set(resumed.CrackSell==true)
    upgradeToggle:Set(resumed.MagnetUpgrades==true)
    escapeToggle:Set(resumed.Escape==true)
    endlessToggle:Set(resumed.Endless==true and resumed.AutoFarmEscapes~=true)
    perkToggle:Set(resumed.AutoPerks==true)
    farmEscapesToggle:Set(resumed.AutoFarmEscapes==true)
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
        if farmEscapesToggle.Value~=FarmEscapes.Enabled then farmEscapesToggle:Set(FarmEscapes.Enabled)end
        farmEscapesStatus:SetDesc(FarmEscapes.Stage..": "..FarmEscapes.Status
            .."\nEscapes: "..FarmEscapes.Rounds.." | Turn-ins: "..FarmEscapes.TurnIns
            .." | Confirmed replays: "..FarmEscapes.ReplayTransitions
            .."\nLowest-ring sweep: "..tostring(Endless.WinSweepMode).." @ "
            ..string.format("%.1fx",Endless.WinSweepSpeed or 10)
            .." | Confirmed geodes/s: "..string.format("%.1f",Endless.WinSweepItemsPerSecond or 0)
            .."\nSweep pass: "..tostring(Endless.WinSweepHeightRing or 1).."/3 - "
            ..tostring(Endless.WinSweepCoveragePass or"Base outer")
            .." | Height offset: +"..string.format("%.1f",Endless.WinSweepHeightOffset or 0)
            .." | Core radius: "..string.format("%.1f",Endless.WinSweepCoreRadius or 0)
            .." | Core pickups: "..tostring(Endless.WinSweepCoreItems or 0)
            .." | Completed laps: "..tostring(Endless.WinSweepCompletedLaps or 0)
            .." | Early core switches: "..tostring(Endless.WinSweepEarlyCoreSkips or 0)
            .."\nGEO-MAG sweep ready: "..tostring(Endless.WinSweepFireReady)
            .." | Initial hold wait: "..tostring(Endless.WinSweepFirstFireWaitMs or 0).."ms"
            .." | Mining camera pitch: 14°"
            .."\nEarly countdown pickup: "..tostring(Pickup.EarlyIntroStatus)
            .." | Accepted tests: "..tostring(Pickup.EarlyConfirmed)
            .." | Pre-equip attempts: "..tostring(FarmEscapes.WaitingEquipAttempts or 0)
            .."\nLast replay: "..FarmEscapes.LastClick
            .." | Teleport queue: "..(continuation.Enabled and (continuation.Installed and"Ready"or"Unavailable")or"Disabled"))
        if mutationToggle.Value~=ClassMutations.Enabled then mutationToggle:Set(ClassMutations.Enabled)end
        mutationStatus:SetDesc(ClassMutations.Status.."\nRequests this start: "..ClassMutations.SessionRequests.." | Accepted this session: "..ClassMutations.Accepted.."\nLast rolled: "..ClassMutations.LastRolled)
        perkStatus:SetDesc(AutoPerks.Status.."\nMode: "..AutoPerks.FocusMode.." | Choices sent: "..AutoPerks.Requests.." | Confirmed: "..AutoPerks.Confirmed)
        if endlessToggle.Value~=Endless.Enabled then endlessToggle:Set(Endless.Enabled)end
        endlessStatus:SetDesc(Endless.Status.."\nRing: "..tostring(Endless.RingName or"Waiting").." / "..tostring(Endless.RingCount or 0).." | Hover: "..Endless.Hover.." studs\nHeld fire: "..(Endless.NativeHeldActive and"Active"or"Paused").." | Native shots: "..Endless.NativeFireEvents.." | Items: "..Endless.NativeItems.."\nAbility: "..tostring(Endless.AbilityStatus or"Waiting").." | Confirmed uses: "..tostring(Endless.AbilityConfirmed or 0).."\nOrbit: "..string.format("%.1fx (~%.2fs/lap)",Endless.OrbitSpeedMultiplier or 10,Endless.OrbitLapSeconds or 1.4).." | Laps: "..Endless.Laps.." | Boss hits: "..Endless.Hits.." | Weak hits: "..Endless.WeakHits.." | Critical target: "..tostring(Endless.ActiveBossSpot or "None").."\nCrack & Sell: "..(CrackSell.Continuous and "Continuous" or "One trip").." | "..CrackSell.Status
            .."\nEscape farm sweep: "..tostring(Endless.WinSweepMode).." @ "..string.format("%.1fx",Endless.WinSweepSpeed or 10)
            .." | Accepted items/s: "..string.format("%.1f",Endless.WinSweepItemsPerSecond or 0)
            .." | Radius scale: "..string.format("%.2f",Endless.WinSweepRadiusScale or 1)
            .." | Win Farm coverage: "..tostring(Endless.WinSweepHeightRing or 1).."/3"
            .."\nRapid boss pulses: "..Endless.RapidBossPulses.." | Observed boss hits/s: "..string.format("%.2f",Endless.BossObservedHitsPerSecond or 0).." | Boss HP decrease/s: "..string.format("%.2f",Endless.BossHPChangePerSecond or 0))
        if escapeToggle.Value~=Escape.Enabled then escapeToggle:Set(Escape.Enabled)end
        escapeStatus:SetDesc(Escape.Status.."\nOpen-lift entries: "..Escape.Attempts.." | Lift openings: "..Escape.GateOpens.." | Failures: "..Escape.Failures
            .." | Gate-to-first-entry: "..string.format("%.2fs",Escape.FirstEnterDelay or 0)
            .." | Gate-to-escape: "..string.format("%.2fs",Escape.ConfirmedSeconds or 0)
            .."\nElevator lock diagnostics: Geode/elevator_lock_diagnostics.json (manual export only)")
        if pickupToggle.Value~=Pickup.Enabled then pickupToggle:Set(Pickup.Enabled)end
        if eggToggle.Value~=Eggs.Enabled then eggToggle:Set(Eggs.Enabled)end
        if crackToggle.Value~=CrackSell.Enabled then crackToggle:Set(CrackSell.Enabled)end
        if upgradeToggle.Value~=MagnetUpgrades.Enabled then upgradeToggle:Set(MagnetUpgrades.Enabled)end
        local player=game:GetService("Players").LocalPlayer
        local mtg=game:GetService("ReplicatedStorage"):FindFirstChild("MTG")
        local state=mtg and mtg:FindFirstChild("State")
        walkSpeedStatus:SetDesc(GameWalkSpeed.Status)
        antiAfkStatus:SetDesc(AntiAFK.Status.." | Successful inputs: "..AntiAFK.Successes.." | Failures: "..AntiAFK.Failures.." | Last: "..AntiAFK.LastSource)
        introStatus:SetDesc(IntroVisuals.Status.." | Visual relocations: "..IntroVisuals.Hidden)
        earlyPickupStatus:SetDesc(Pickup.EarlyIntroStatus.." | Attempts: "..Pickup.EarlyAttempts.." | Server replies with items: "..Pickup.EarlyConfirmed)
        upgradeStatus:SetDesc(MagnetUpgrades.Status.."\nMode: "..(MagnetUpgrades.FastPurchases and "Fast" or "Standard")
            .." | Confirmed: "..MagnetUpgrades.Confirmed.." | Requests: "..MagnetUpgrades.Requests
            .." | Busy: "..MagnetUpgrades.BusyResponses.." | Last confirmation: "..MagnetUpgrades.LastConfirmationMs.."ms")
        otherAbilityStatus:SetDesc((OtherModeAbility.EscapeFarmActive and "Escape Farm | "or "")..OtherModeAbility.Status
            .." | Native skill confirmations: "..OtherModeAbility.Confirmed
            .." | Requests: "..OtherModeAbility.Requests)
        crackStatus:SetDesc(string.format("%s\nCompleted cycles: %d | Sales: %d | Cash gained: %.2f\nLast trip: %.2fs | Teleports: %d | Reused position: %d | Prompt retries: %d\nEndless restarts: %d | Boss interruptions: %d | Auto-resume blocked: %s\nPickup pauses during camp visits; returns afterward.",
            CrackSell.Status,CrackSell.Cycles,CrackSell.Sales,CrackSell.CashGained,CrackSell.LastTripSeconds,CrackSell.LastTripTeleports,CrackSell.LastTripMovesSaved,CrackSell.PromptRetries,
            CrackSell.EndlessRestarts,CrackSell.EndlessBossInterruptions,
            CrackSell.AutoResumeBlocked and "YES" or "NO"))
        eggStatus:SetDesc(string.format("%s\n3 eggs per batch | Cost: %d candy | Balance: %s\nOpened: %d | Requests: %d | Busy replies: %d\nLast: %s",
            Eggs.Status,Eggs.Price or 180,tostring(player:GetAttribute("Candy")or 0),Eggs.Opened,Eggs.Requests,Eggs.BusyReplies,Eggs.ResultText()))
        live:SetDesc(string.format("%s\nRange: 0–%d studs | Requests: %d | Tool feedback: %d | Items: %d\nBag: %s / %s\nPickup: %s | Cooldown: %.3fs | Last search: %.1fms | Zero replies: %d | Timeouts: %d",
            Pickup.Status or"Paused",Pickup.MaxRange,Pickup.Requests,Pickup.Feedback,Pickup.Items,
            tostring(player:GetAttribute("BagCount")or 0),(player:GetAttribute("BagCap")==-1 and"Unlimited"or tostring(player:GetAttribute("BagCap")or"—")),
            Pickup.NativeHeldOwner and "Native Endless fire" or (Pickup.FastPickup and "Fast" or "Standard"),
            Pickup.LastCooldown,Pickup.LastSearchMs,Pickup.ZeroReplies,Pickup.Timeouts))
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