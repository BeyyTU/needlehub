-- Beyy Geode Hub | Crack the Geode! | native menu and range-limited pickup
if not game:IsLoaded()then game.Loaded:Wait()end
if game.GameId~=10770110947 then warn("[Geode Hub] This script is for Crack the Geode!");return end
local env=getgenv()
-- Claim startup before module initialization can yield. The shared instance also
-- covers queued chunks whose executor globals are isolated from one another.
local geodeVersion="1.10.105"
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
                local automation={AutoGeodePickup=true,AutoOpenHauntedEgg=true,AutoCrackAndSell=true,AutoUpgradeMagnet=true,AutoUpgradeCrackPower=true,AutoEscape=true,AutoEndless=true,AutoSelectPerk=true,AutoFarmEscapes=true}
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
function api.HasPendingPickup()
    -- Read only: used to avoid a fixed held-fire handoff delay when
    -- no direct pickup response is in flight.
    return pending~=nil
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

-- On-demand, read-only snapshot of live lobby egg/hatch configuration.
-- We do not guess paid remote methods or send unverified purchases.
local function createLavaEggLobbyInspector()
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local M=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local api={Status="Not captured",LastExportMs=0,LastError=nil,LastCounts={}}
    local function interested(name)
        local v=tostring(name or""):lower()
        return v:find("lava",1,true)or v:find("egg",1,true)
            or v:find("pet",1,true)or v:find("hatch",1,true)
            or v:find("open",1,true)or v:find("multi",1,true)
            or v:find("pass",1,true)or v:find("product",1,true)
            or v:find("shop",1,true)or v:find("20x",1,true)
    end
    local function safePath(inst)
        local ok,name=pcall(function()return inst:GetFullName()end)
        return ok and tostring(name):sub(1,250)or tostring(inst.Name)
    end
    local function captureValue(value,depth,seen,budget)
        budget.Count+=1
        if budget.Count>8500 then return "[node limit]"end
        local kind=typeof(value)
        if kind=="nil"then return nil end
        if kind=="boolean"then return value end
        if kind=="string"then return #value<=500 and value or(value:sub(1,500).." [truncated]")end
        if kind=="number"then
            return value==value and value~=math.huge and value~=-math.huge and value or nil
        end
        if kind=="Vector3"then return {X=value.X,Y=value.Y,Z=value.Z}end
        if kind=="Vector2"then return {X=value.X,Y=value.Y}end
        if kind=="Instance"then return {Class=value.ClassName,Name=value.Name,Path=safePath(value)}end
        if kind=="table"then
            if depth>=7 then return "[depth limit]"end
            if seen[value]then return "[repeated table]"end
            seen[value]=true
            local out={};local n=0
            for key,item in pairs(value)do
                n+=1
                if n>450 then out["__truncated"]="More than 450 fields";break end
                local kt=type(key)
                if kt=="string"or kt=="number"then
                    local k=kt=="number"and key or tostring(key):sub(1,140)
                    local itemType=typeof(item)
                    if itemType=="function"then
                        out[k]="[function]"
                    elseif itemType=="thread"or itemType=="userdata"then
                        out[k]="["..itemType.."]"
                    else
                        out[k]=captureValue(item,depth+1,seen,budget)
                    end
                end
            end
            seen[value]=nil
            return out
        end
        return tostring(value):sub(1,160)
    end
    function api.Export()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","File export unsupported by executor")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local state=M:FindFirstChild("State")
            local role=M:GetAttribute("Role")
            local phase=state and state:GetAttribute("Phase")
            local report={
                Version=1,HubVersion=geodeVersion,PlaceId=game.PlaceId,
                GameId=game.GameId,Role=role,Phase=phase,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                ReadOnly=true,PurchaseRequestsSent=0,
                Goal="Investigate native Lava Egg method, single vs 20x hatch, animation, cooldown and server gating",
                KnownWorkingHauntedReference={Remote="MTG.Remotes.Pets",Action="Open3",Egg="Haunted"},
                Warning="Haunted Open3 does not prove that Lava supports Open3, Open20, skipping animation, or concurrent requests.",
                PlayerAttributes={},ConfigModules={},Remotes={},ClientModules={},
                EggObjects={},RelevantGui={},PetsUI={},Limits={
                    TableDepth=7,TableFields=450,TotalSerializedNodes=8500,
                    MaxConfigs=32,MaxGui=300,MaxWorld=220
                }
            }
            for key,value in pairs(P:GetAttributes())do
                if interested(key)or key=="Cash"or key=="Gems"or key=="Candy"then
                    report.PlayerAttributes[key]=captureValue(value,0,{}, {Count=0})
                end
            end
            local config=M:FindFirstChild("Config")
            local configCount=0
            if config then
                for _,mod in ipairs(config:GetDescendants())do
                    if mod:IsA("ModuleScript")and interested(mod.Name)then
                        configCount+=1
                        if configCount<=32 then
                            local entry={Name=mod.Name,Path=safePath(mod)}
                            local success,data=pcall(require,mod)
                            entry.Success=success
                            if success then
                                entry.Data=captureValue(data,0,{}, {Count=0})
                            else
                                entry.Error=tostring(data):sub(1,220)
                            end
                            report.ConfigModules[#report.ConfigModules+1]=entry
                        end
                    end
                end
            end
            local remoteRoot=M:FindFirstChild("Remotes")
            if remoteRoot then
                for _,remote in ipairs(remoteRoot:GetDescendants())do
                    if remote:IsA("RemoteEvent")or remote:IsA("RemoteFunction")or
                        remote:IsA("UnreliableRemoteEvent")then
                        if #report.Remotes<180 then
                            report.Remotes[#report.Remotes+1]={
                                Name=remote.Name,Class=remote.ClassName,
                                Path=safePath(remote),
                                EggRelated=interested(remote.Name)
                            }
                        end
                    end
                end
            end
            local scripts=P:FindFirstChild("PlayerScripts")
            local client=scripts and scripts:FindFirstChild("MTGClient")
            if client then
                for _,module in ipairs(client:GetDescendants())do
                    if (module:IsA("ModuleScript")or module:IsA("LocalScript"))
                        and interested(module.Name)and #report.ClientModules<100 then
                        report.ClientModules[#report.ClientModules+1]={
                            Name=module.Name,Class=module.ClassName,
                            Path=safePath(module)
                        }
                    end
                end
                local ui=client:FindFirstChild("PetsUI")
                if ui and ui:IsA("ModuleScript")then
                    local success,export=pcall(require,ui)
                    report.PetsUI.Available=success
                    if success and type(export)=="table"then
                        report.PetsUI.Exports={}
                        for key,value in pairs(export)do
                            if type(key)=="string"then
                                report.PetsUI.Exports[key]=typeof(value)
                            end
                        end
                        if type(export.isOpening)=="function"then
                            local okOpening,opening=pcall(export.isOpening)
                            if okOpening then report.PetsUI.IsOpening=opening end
                        end
                    elseif not success then
                        report.PetsUI.Error=tostring(export):sub(1,220)
                    end
                end
            end
            local gui=P:FindFirstChild("PlayerGui")
            if gui then
                for _,obj in ipairs(gui:GetDescendants())do
                    if obj:IsA("GuiObject")and #report.RelevantGui<300 then
                        local displayedText=""
                        if obj:IsA("TextLabel")or obj:IsA("TextButton")
                            or obj:IsA("TextBox")then
                            displayedText=tostring(obj.Text or"")
                        end
                        if interested(obj.Name)or interested(displayedText)
                            or interested(obj.Parent and obj.Parent.Name)then
                            local item={
                                Name=obj.Name,Class=obj.ClassName,
                                Path=safePath(obj),Visible=obj.Visible,
                                Text=displayedText:sub(1,220),
                                Position={X=obj.AbsolutePosition.X,Y=obj.AbsolutePosition.Y},
                                Size={X=obj.AbsoluteSize.X,Y=obj.AbsoluteSize.Y}
                            }
                            if obj:IsA("GuiButton")then item.Active=obj.Active end
                            report.RelevantGui[#report.RelevantGui+1]=item
                        end
                    end
                end
            end
            for _,obj in ipairs(workspace:GetDescendants())do
                if interested(obj.Name)and #report.EggObjects<220 then
                    local item={Name=obj.Name,Class=obj.ClassName,
                        Path=safePath(obj)}
                    if obj:IsA("BasePart")then
                        item.Position={X=obj.Position.X,Y=obj.Position.Y,Z=obj.Position.Z}
                    end
                    report.EggObjects[#report.EggObjects+1]=item
                end
            end
            report.Counts={
                MatchingConfigModules=configCount,
                CapturedConfigModules=#report.ConfigModules,
                Remotes=#report.Remotes,
                ClientModules=#report.ClientModules,
                RelevantGui=#report.RelevantGui,
                EggWorldObjects=#report.EggObjects
            }
            local path="Geode/lava_egg_lobby_diagnostics.json"
            writefile(path,H:JSONEncode(report))
            return {Path=path,Role=role,Phase=phase,Counts=report.Counts}
        end)
        if not ok then
            api.LastError=tostring(result)
            api.Status="Lobby egg capture failed: "..api.LastError
            return false,api.LastError
        end
        api.LastError=nil;api.LastCounts=result.Counts
        api.LastExportMs=DateTime.now().UnixTimestampMillis
        api.Status="Saved "..result.Path.." (role="..tostring(result.Role)
            ..", config modules="..tostring(result.Counts.CapturedConfigModules)..")"
        return true,result.Path
    end
    return api
end

local LavaEggInspector=createLavaEggLobbyInspector()

-- Fast Lava Egg test: one native 20-egg request, then optional bounded
-- repetitions. Remote action "Open20" is a hypothesis based on the
-- existing working Open3 action; do not enable auto until a full 20-result
-- server confirmation proves it. Requests are paid and not speculative.
local function createLavaEggFastHatch()
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local M=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local Pets=require(M.Config.Pets)
    local PetsUI=require(P.PlayerScripts.MTGClient.PetsUI)
    local remote=M.Remotes:WaitForChild("Pets")
    local stormModule=P.PlayerScripts.MTGClient:FindFirstChild("HatchStorm")
    local storm=stormModule and require(stormModule)or nil
    local revamp=require(M.Config.PetsRevamp)
    local cooldownPad=tonumber(revamp.Storm and revamp.Storm.CooldownPad)or .05
    if cooldownPad~=cooldownPad or cooldownPad<0 then cooldownPad=.05 end
    local lava=Pets.GeodeById and Pets.GeodeById.Lava
    local price=tonumber(lava and lava.Price)or 0
    local cooldown=Pets.HatchCooldown or{}
    local batch=math.min(20,tonumber(Pets.HatchMax)or 0)
    local baseCooldown=math.min(tonumber(cooldown.Max)or 3.5,
        (tonumber(cooldown.Base)or 1.5)
            +(tonumber(cooldown.PerEgg)or .1)*batch)
    -- Confirmed in decompiled HatchStorm.askHatch:
    -- u17.Ask("Hatch", geodeId, eggCount), forwarded by PetsUI.ask
    -- to MTG.Remotes.Pets:InvokeServer(action, geodeId, eggCount).
    local action="Hatch"
    -- The 3.5s + pad in HatchStorm.noteCooldown is a CLIENT delay.
    -- Learn whether the server accepts shorter gaps without spamming it:
    -- initially 0.25s faster; decrease only after accepted batches;
    -- the first Busy/Wait locks timing to a server-observed boundary.
    local nativeGap=baseCooldown+cooldownPad
    local initialFastGap=math.max(.75,math.min(nativeGap,baseCooldown-.25))
    local minFastGap=.75
    local gap=initialFastGap
    local lastAcceptedAt=nil
    local consecutiveAccepted=0
    local learnedBoundary=false
    local api={
        Running=true,Enabled=false,Verified=false,InFlight=false,
        BatchSize=batch,UnitPrice=price,BatchCost=price*batch,
        ConfiguredCooldown=baseCooldown,NativeGap=nativeGap,
        AdaptiveSpeed=true,AdaptiveGap=gap,MinFastGap=minFastGap,
        ProbeSteps=0,TimingBackoffs=0,LastAcceptedInterval=0,
        MaxBatches=10,SessionBatches=0,
        Requests=0,AcceptedBatches=0,Opened=0,
        BusyReplies=0,LastCount=0,LastResponseMs=0,LastWait=0,
        Status="Native Hatch (Lava, 20) verified in client; paid trial required"
    }
    local history={};local nextAt=0;local consecutiveBusy=0
    local function record(kind,data)
        history[#history+1]={AtMs=DateTime.now().UnixTimestampMillis,
            Kind=kind,Data=data}
        if #history>65 then table.remove(history,1)end
    end
    function api.SetMaxBatches(value)
        value=tonumber(value)
        if value then api.MaxBatches=math.floor(math.clamp(value,1,100))end
    end
    function api.SetAdaptiveSpeed(value)
        api.AdaptiveSpeed=value==true
        gap=api.AdaptiveSpeed and initialFastGap or nativeGap
        consecutiveAccepted=0;learnedBoundary=false
        api.AdaptiveGap=gap
        api.Status=api.AdaptiveSpeed
            and string.format("Adaptive timing armed: %.2fs initial gap (min %.2fs)",gap,minFastGap)
            or string.format("Native timing selected: %.2fs gap",nativeGap)
    end
    local function eligibility()
        if M:GetAttribute("Role")~="Lobby"then
            return false,"Only available in Lobby"
        end
        if P:GetAttribute("UnlockPets")~=true then
            return false,"Pets are not unlocked"
        end
        local firstClears=P:GetAttribute("FirstClears")
        if type(firstClears)~="string"or firstClears==""then
            return false,"Complete HARD mode to unlock Lava Eggs"
        end
        local cleared,clearData=pcall(H.JSONDecode,H,firstClears)
        if not cleared or type(clearData)~="table"
            or clearData.Hard~=true then
            return false,"Complete HARD mode to unlock Lava Eggs"
        end
        if batch~=20 or price<=0 or lava==nil then
            return false,"20x Lava config missing or invalid"
        end
        local passes=tostring(P:GetAttribute("Passes")or"")
        if not passes:find("MultiHatch",1,true)
            and not passes:find("AllPasses",1,true)then
            return false,"Multi Hatch pass required"
        end
        -- No guessing about mixed credit/gem payment rules; require
        -- one complete paid batch or 20 actual Lava credits.
        local gems=tonumber(P:GetAttribute("Gems"))or 0
        local credits=tonumber(P:GetAttribute("LavaEggCredits"))or 0
        if gems<api.BatchCost and credits<20 then
            return false,"Insufficient gems (20x price "..api.BatchCost..")"
        end
        local openingOK,opening=pcall(function()
            return (type(PetsUI.isOpening)=="function"and PetsUI.isOpening())
                or(storm and type(storm.isActive)=="function"and storm.isActive())
        end)
        if openingOK and opening then
            return false,"Waiting for the game's active hatch UI"
        end
        return true
    end
    local function request(trial)
        if not api.Running or api.InFlight then return false,"Request in flight"end
        local now=os.clock()
        if now<nextAt then
            api.Status=string.format("Cooldown %.2fs remaining",nextAt-now)
            return false,api.Status
        end
        local ready,why=eligibility()
        if not ready then
            api.Status=why
            if not trial and why~="Waiting for the game\'s active hatch UI"then
                api.Enabled=false
            end
            return false,why
        end
        api.InFlight=true;api.Requests+=1
        local start=os.clock()
        record("Request",{Action=action,Egg="Lava",Batch=batch,
            Trial=trial,GemsBefore=P:GetAttribute("Gems"),
            CreditsBefore=P:GetAttribute("LavaEggCredits"),
            ConfigCooldown=baseCooldown,AdaptiveSpeed=api.AdaptiveSpeed,
            ScheduledGap=api.AdaptiveSpeed and gap or nativeGap})
        -- Do not invoke PetsUI.hatch/showOpening. This avoids waiting
        -- for local hatch visuals, but cannot bypass server cooldown.
        local ok,response=pcall(function()
            return remote:InvokeServer(action,"Lava",batch)
        end)
        api.LastResponseMs=math.floor((os.clock()-start)*1000+.5)
        api.InFlight=false
        if not ok then
            api.Enabled=false
            api.Status="20x remote error: "..tostring(response)
            record("Error",{Message=api.Status})
            return false,api.Status
        end
        if type(response)~="table"then
            api.Enabled=false
            api.Status="Unexpected response; stopped before further purchases"
            record("Unexpected",{Type=typeof(response),Value=tostring(response)})
            return false,api.Status
        end
        local count=type(response.Results)=="table"and #response.Results
            or(response.Pet and 1 or 0)
        local wait=tonumber(response.Wait)or 0
        if wait~=wait or wait<0 or wait==math.huge then wait=0 end
        api.LastWait=wait;api.LastCount=count
        local responseAt=os.clock()
        if response.Busy==true then
            -- Server Wait is authoritative. One early probe is enough to
            -- learn the boundary; stop reducing the gap after any Busy.
            local backoff=math.clamp(wait>0 and wait or .3,.1,4)
            nextAt=responseAt+backoff+.06
            consecutiveAccepted=0
            if api.AdaptiveSpeed then
                local observed=lastAcceptedAt
                    and(responseAt-lastAcceptedAt)+backoff+.05
                    or nativeGap
                gap=math.max(gap,math.min(nativeGap,observed))
                learnedBoundary=true
                api.AdaptiveGap=gap
                api.TimingBackoffs+=1
                record("TimingBackoff",{ServerWait=wait,RetryIn=backoff+.06,
                    LearnedGap=gap,AfterLastAccepted=lastAcceptedAt
                        and(responseAt-lastAcceptedAt)or nil})
            end
        else
            nextAt=responseAt+(api.AdaptiveSpeed and gap or nativeGap)
        end
        record("Response",{
            Ok=response.Ok,Busy=response.Busy,
            Count=count,Wait=wait,ResponseMs=api.LastResponseMs,
            Gap=api.AdaptiveSpeed and gap or nativeGap,
            NextIn=math.max(0,nextAt-responseAt),
            Message=tostring(response.Msg or""):sub(1,240),
            GemsAfter=P:GetAttribute("Gems"),
            CreditsAfter=P:GetAttribute("LavaEggCredits")})
        if response.Busy==true then
            consecutiveBusy+=1;api.BusyReplies+=1
            if consecutiveBusy>=3 then
                api.Enabled=false;api.Status="Three server Busy replies; auto stopped"
            else
                api.Status=string.format(
                    "Server Busy; waiting %.2fs, calibrated gap %.2fs",
                    math.max(0,nextAt-responseAt),gap)
            end
            return false,api.Status
        end
        consecutiveBusy=0
        if response.Ok~=true then
            api.Enabled=false
            api.Status="Server rejected Hatch(Lava,20): "..tostring(response.Msg or"Unknown")
            return false,api.Status
        end
        api.AcceptedBatches+=1;api.Opened+=count
        -- A successful server reply with fewer than 20 results must not
        -- enable paid auto-opening, even if the server charged for eggs.
        if count~=20 then
            api.Enabled=false
            api.Status="Accepted "..count.." of 20; unsafe to automate"
            return false,api.Status
        end
        api.Verified=true;api.SessionBatches+=1
        if lastAcceptedAt then
            api.LastAcceptedInterval=responseAt-lastAcceptedAt
        end
        lastAcceptedAt=responseAt
        consecutiveAccepted+=1
        -- Only explore after two accepted 20x batches and never again
        -- after the server has signaled Busy while probing.
        if api.AdaptiveSpeed and not learnedBoundary
            and consecutiveAccepted>=2 and gap>minFastGap then
            local oldGap=gap
            gap=math.max(minFastGap,gap-.25)
            consecutiveAccepted=0
            api.ProbeSteps+=1
            record("TimingProbe",{PreviousGap=oldGap,NextGap=gap,
                MinGap=minFastGap,AcceptedBatches=api.AcceptedBatches})
        end
        api.AdaptiveGap=gap
        nextAt=responseAt+(api.AdaptiveSpeed and gap or nativeGap)
        api.Status=string.format(
            "Opened 20 Lava Eggs in %dms; next gap %.2fs%s",
            api.LastResponseMs,api.AdaptiveSpeed and gap or nativeGap,
            learnedBoundary and" (server-calibrated)"or"")
        return true,api.Status
    end
    function api.TestOnce()
        -- Each click sends at most one paid Hatch(Lava,20) request.
        -- Required before auto hatch; the server determines actual cost.
        api.Enabled=false
        return request(true)
    end
    function api.Start()
        if not api.Verified then
            api.Enabled=false
            api.Status="Run one paid native 20x trial first; confirm 20 Results"
            return false,api.Status
        end
        if not api.Running or api.InFlight then
            api.Enabled=false
            api.Status="A hatch request is already in flight"
            return false,api.Status
        end
        api.Enabled=true;api.SessionBatches=0;consecutiveBusy=0
        -- Continue honoring nextAt from the successful test request.
        api.Status="Auto native 20x Lava hatch armed (max "
            ..api.MaxBatches.." batches)"
        return true,api.Status
    end
    function api.Stop(reason)
        api.Enabled=false
        api.Status=reason or"Paused; no new egg batches will be sent"
    end
    function api.Unload()api.Stop("Unloaded");api.Running=false end
    function api.Export()
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/lava_egg_hatch_diagnostics.json",H:JSONEncode({
                Version=2,HubVersion=geodeVersion,
                Action=action,Egg="Lava",Remote="MTG.Remotes.Pets",
                BatchSize=batch,CooldownPad=cooldownPad,
                AdaptiveSpeed=api.AdaptiveSpeed,AdaptiveGap=gap,
                NativeGap=nativeGap,MinFastGap=minFastGap,
                ProbeSteps=api.ProbeSteps,TimingBackoffs=api.TimingBackoffs,
                LastAcceptedInterval=api.LastAcceptedInterval,
                ServerTimingBoundaryObserved=learnedBoundary,
                PaidGemCost=api.BatchCost,UnitPrice=price,
                ConfiguredCooldown=baseCooldown,
                Verified=api.Verified,Enabled=api.Enabled,
                MaxBatches=api.MaxBatches,SessionBatches=api.SessionBatches,
                Requests=api.Requests,AcceptedBatches=api.AcceptedBatches,
                Opened=api.Opened,BusyReplies=api.BusyReplies,
                LastCount=api.LastCount,LastResponseMs=api.LastResponseMs,
                LastWait=api.LastWait,Status=api.Status,Events=history,
                Note="Native Hatch(Lava,20) was confirmed by a live paid trial. Adaptive mode probes a shorter client gap only after accepted batches; the first server Busy/Wait calibrates and stops further shortening. All requests remain sequential, honor server Wait, do not animate, and auto purchases require explicit opt-in and a successful trial in this session."
            }))
        end)
        return ok,err
    end
    
    -- Manual-only, read-only introspection of the game's native hatch API.
    -- Captures function arities and non-sensitive bytecode constants when
    -- executor debug introspection is available; never invokes the functions.
    function api.InspectNative()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","File export unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local dbg=type(debug)=="table"and debug or{}
            local getConstants=type(dbg.getconstants)=="function"
                and dbg.getconstants or(type(getconstants)=="function"and getconstants or nil)
            local getProtos=type(dbg.getprotos)=="function"
                and dbg.getprotos or(type(getprotos)=="function"and getprotos or nil)
            local getUpvalues=type(dbg.getupvalues)=="function"
                and dbg.getupvalues or(type(getupvalues)=="function"and getupvalues or nil)
            local sourceDecompiler=type(decompile)=="function"and decompile or nil
            local info={
                Version=2,HubVersion=geodeVersion,TimeMs=DateTime.now().UnixTimestampMillis,
                ReadOnly=true,RemoteCalls=0,PurchaseRequests=0,
                PreviousTest={Action="Open20",Requests=4,Accepted=0,
                    ServerMessage="Unknown request"},
                Role=M:GetAttribute("Role"),
                Config={
                    HatchMax=Pets.HatchMax,HatchCooldown=Pets.HatchCooldown,
                    MultiHatchPass=P:GetAttribute("Passes")
                        and tostring(P:GetAttribute("Passes")):find("MultiHatch",1,true)~=nil,
                    LavaEggId=lava and lava.Id,
                    LavaPrice=lava and lava.Price
                },
                DebugCapabilities={
                    GetConstants=getConstants~=nil,
                    GetProtos=getProtos~=nil,
                    GetUpvalues=getUpvalues~=nil,
                    FunctionArity=type(debug)=="table"and type(debug.info)=="function",
                    Decompile=sourceDecompiler~=nil
                },
                Functions={},Tables={},HatchStorm={},ClientSource={},
                Note="Native hatch module introspection only. Does not call purchase remotes, attempt Open20, open eggs, change animation state, or bypass purchase checks. Source decompile is optional and limited to the game's replicated PetsUI and HatchStorm client modules."
            }
            local count=0
            local function inspect(fn,label,depth)
                if type(fn)~="function"or count>=110 then return end
                count+=1
                local row={Name=label,Type="function",Depth=depth}
                local ai,arity,vararg=pcall(function()
                    return debug.info(fn,"a")
                end)
                if ai then
                    row.Args=arity;row.Vararg=vararg
                end
                if getConstants then
                    local success,constants=pcall(getConstants,fn)
                    row.ConstantsAvailable=success and type(constants)=="table"
                    if row.ConstantsAvailable then
                        local values={}
                        for _,value in pairs(constants)do
                            local t=type(value)
                            if (t=="string"or t=="number"or t=="boolean")
                                and #values<180 then
                                if t~="string"or #value<=200 then
                                    values[#values+1]=value
                                end
                            end
                        end
                        row.Constants=values
                    elseif not success then
                        row.ConstantsError=tostring(constants):sub(1,170)
                    end
                end
                if getUpvalues then
                    local success,upvalues=pcall(getUpvalues,fn)
                    if success and type(upvalues)=="table"then
                        local names={};local n=0
                        for key,value in pairs(upvalues)do
                            n+=1;if n>45 then break end
                            local vtype=typeof(value)
                            local summary={Name=tostring(key):sub(1,90),Type=vtype}
                            -- Never dump arbitrary game state, personal
                            -- inventory, player objects or huge closures.
                            if vtype=="string"and
                                (#value<=100)and(value:lower():find("open",1,true)
                                    or value:lower():find("hatch",1,true)
                                    or value:lower():find("lava",1,true)
                                    or value:lower():find("pet",1,true))then
                                summary.Value=value
                            elseif vtype=="Instance"then
                                summary.InstanceClass=value.ClassName
                                summary.InstanceName=value.Name
                            end
                            names[#names+1]=summary
                        end
                        row.UpvalueTypes=names
                    end
                end
                info.Functions[#info.Functions+1]=row
                if depth<1 and getProtos then
                    local success,protos=pcall(getProtos,fn)
                    if success and type(protos)=="table"then
                        row.NestedPrototypeCount=#protos
                        local j=0
                        for _,proto in ipairs(protos)do
                            j+=1
                            if j>12 then break end
                            inspect(proto,label.."#proto"..j,depth+1)
                        end
                    end
                end
            end
            for key,value in pairs(PetsUI)do
                if type(key)=="string"then
                    if type(value)=="function"then
                        inspect(value,"PetsUI."..key,0)
                    elseif type(value)=="table"and
                        (key=="_O"or key=="_U"or key=="HW")then
                        local output={Name="PetsUI."..key,Keys={}}
                        local n=0
                        for subkey,subvalue in pairs(value)do
                            n+=1;if n>80 then break end
                            output.Keys[#output.Keys+1]={
                                Name=tostring(subkey):sub(1,100),
                                Type=typeof(subvalue)
                            }
                            if type(subvalue)=="function"then
                                inspect(subvalue,"PetsUI."..key
                                    .."."..tostring(subkey),0)
                            end
                        end
                        info.Tables[#info.Tables+1]=output
                    end
                end
            end

            -- The native _hatchN path references a separate HatchStorm
            -- module for 10x/20x. Capture that module's public API and
            -- closure constants, which were missing from the first report.
            local moduleRoot=P:FindFirstChild("PlayerScripts")
            local client=moduleRoot and moduleRoot:FindFirstChild("MTGClient")
            local petsModule=client and client:FindFirstChild("PetsUI",true)
            local stormModule=client and client:FindFirstChild("HatchStorm",true)
            if not stormModule then
                stormModule=M:FindFirstChild("HatchStorm",true)
            end
            local function moduleSummary(module)
                if not module or not module:IsA("ModuleScript")then
                    return {Found=false}
                end
                local okName,name=pcall(function()return module:GetFullName()end)
                return {Found=true,Path=okName and name or module.Name}
            end
            info.HatchStorm.Module=moduleSummary(stormModule)
            info.HatchStorm.PetsUIModule=moduleSummary(petsModule)
            if stormModule and stormModule:IsA("ModuleScript")then
                local okModule,exports=pcall(require,stormModule)
                info.HatchStorm.Loaded=okModule
                if okModule and type(exports)=="table"then
                    info.HatchStorm.Exports={}
                    for key,value in pairs(exports)do
                        if #info.HatchStorm.Exports>=120 then break end
                        local name=tostring(key):sub(1,80)
                        info.HatchStorm.Exports[#info.HatchStorm.Exports+1]={
                            Name=name,Type=typeof(value)
                        }
                        if type(value)=="function"then
                            inspect(value,"HatchStorm."..name,0)
                        elseif type(value)=="table"then
                            local n=0
                            for subkey,subvalue in pairs(value)do
                                n+=1;if n>30 then break end
                                if type(subvalue)=="function"then
                                    inspect(subvalue,"HatchStorm."..name
                                        .."."..tostring(subkey),0)
                                end
                            end
                        end
                    end
                elseif okModule and type(exports)=="function"then
                    inspect(exports,"HatchStorm.moduleReturn",0)
                else
                    info.HatchStorm.Error=okModule and
                        ("Unexpected exports: "..typeof(exports))or
                        tostring(exports):sub(1,240)
                end
            end
            -- Avoid copying player's inventory: only inspect native UI state.
            local U=PetsUI._U
            local O=PetsUI._O
            info.NativeHatchState={
                Opening=type(PetsUI.isOpening)=="function"
                    and PetsUI.isOpening()or nil,
                AutoMulti=type(U)=="table"and U.AutoMulti or nil,
                Busy=type(U)=="table"and U.Busy or nil,
                LastAsk=type(U)=="table"and U.LastAsk or nil,
                Fast=type(O)=="table"and O.Fast or nil,
                Skip=type(O)=="table"and O.Skip or nil,
                StatePhase=type(O)=="table"and O.Phase or nil
            }
            if type(U)=="table"then
                for _,name in ipairs({"Hooks","Auto","Arm"})do
                    local tbl=U[name]
                    if type(tbl)=="table"then
                        local fields={}
                        local n=0
                        for key,value in pairs(tbl)do
                            n+=1;if n>70 then break end
                            fields[#fields+1]={Name=tostring(key):sub(1,100),
                                Type=typeof(value)}
                            if type(value)=="function"then
                                inspect(value,"PetsUI._U."..name
                                    .."."..tostring(key),0)
                            end
                        end
                        info.Tables[#info.Tables+1]={
                            Name="PetsUI._U."..name,Keys=fields
                        }
                    end
                end
            end
            -- Optional read-only client-side decompile. Never execute
            -- obtained code or invoke a paid hatch.
            if sourceDecompiler then
                for _,item in ipairs({
                    {Module=petsModule,Path="Geode/lava_native_PetsUI.lua",Label="PetsUI"},
                    {Module=stormModule,Path="Geode/lava_native_HatchStorm.lua",Label="HatchStorm"}
                })do
                    if item.Module and item.Module:IsA("ModuleScript")then
                        local success,source=pcall(sourceDecompiler,item.Module)
                        if success and type(source)=="string"and #source>0 then
                            local truncated=#source>190000
                            local output=truncated and source:sub(1,190000)or source
                            local written,writeError=pcall(writefile,item.Path,output)
                            info.ClientSource[#info.ClientSource+1]={
                                Module=item.Label,Decompiled=true,
                                Saved=written,Path=written and item.Path or nil,
                                Bytes=#source,Truncated=truncated,
                                Error=not written and tostring(writeError):sub(1,170)or nil
                            }
                        else
                            info.ClientSource[#info.ClientSource+1]={
                                Module=item.Label,Decompiled=false,
                                Reason=tostring(source):sub(1,170)
                            }
                        end
                    end
                end
            end
            local filename="Geode/lava_hatch_native_api_diagnostics.json"
            writefile(filename,H:JSONEncode(info))
            return {File=filename,Count=#info.Functions,
                Constants=getConstants~=nil,Protos=getProtos~=nil}
        end)
        if not ok then
            api.Status="Native hatch inspector error: "..tostring(result)
            return false,api.Status
        end
        api.Status="Saved "..result.File.." ("..result.Count
            .." functions, constants="..tostring(result.Constants)
            ..", prototypes="..tostring(result.Protos)..")"
        return true,result.File
    end

    task.spawn(function()
        while api.Running do
            if api.Enabled and not api.InFlight then
                if api.SessionBatches>=api.MaxBatches then
                    api.Stop("Batch limit reached ("..api.MaxBatches..")")
                elseif os.clock()>=nextAt then
                    local ok,err=request(false)
                    if not ok and not api.Enabled then
                        record("Stopped",{Reason=err})
                    end
                end
            end
            task.wait(api.Enabled and .04 or .2)
        end
    end)
    return api
end
local LavaFastHatch=createLavaEggFastHatch()

-- Manual read-only investigation of any replicated admin/spectator feature.
-- No feature activation, camera swapping, remote invocation, permission
-- changes, other-player attribute collection or client module execution.
local function createAdminSpectateInspector()
    local Players=game:GetService("Players")
    local P=Players.LocalPlayer
    local H=game:GetService("HttpService")
    local RS=game:GetService("ReplicatedStorage")
    local api={Status="Not captured",LastPath=nil,LastCounts=nil,LastError=nil}
    local function relevant(value)
        local s=tostring(value or""):lower()
        for _,word in ipairs({
            "spectat","admin","moder","freecam","observer",
            "observe","watchplayer","watch_player","camera",
            "staff","permission","gmcommand","playerlist",
            "privilege","servercmd","debugcam","followtarget"
        })do
            if s:find(word,1,true)then return true end
        end
        return false
    end
    local function path(inst)
        local ok,name=pcall(function()return inst:GetFullName()end)
        if not ok then return tostring(inst.Name)end
        -- Do not needlessly put the local username in the exported paths.
        return tostring(name):gsub(P.Name,"LocalPlayer"):sub(1,250)
    end
    local function simple(value)
        local typ=typeof(value)
        if typ=="boolean"or typ=="string"then
            local v=tostring(value)
            if typ=="boolean"then return value end
            return v:sub(1,200)
        end
        if typ=="number"and value==value and value~=math.huge
            and value~=-math.huge then return value end
        return nil
    end
    local function matchedAttributes(obj)
        local out={}
        local ok,attrs=pcall(function()return obj:GetAttributes()end)
        if ok then
            for k,v in pairs(attrs)do
                if relevant(k)or k=="Role"or k=="Phase"or k=="Mode"then
                    out[k]=simple(v)
                end
            end
        end
        return out
    end
    local function guiLabel(obj)
        if obj:IsA("TextLabel")or obj:IsA("TextButton")
            or obj:IsA("TextBox")then
            return tostring(obj.Text or""):sub(1,200)
        end
        return ""
    end
    function api.Export()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","Executor does not support diagnostic files")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local mtg=RS:FindFirstChild("MTG")
            local state=mtg and mtg:FindFirstChild("State")
            local report={
                Version=2,HubVersion=geodeVersion,
                PlaceId=game.PlaceId,GameId=game.GameId,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                Role=mtg and mtg:GetAttribute("Role"),
                Phase=state and state:GetAttribute("Phase"),
                Mode=state and state:GetAttribute("Mode"),
                ReadOnly=true,RemoteCalls=0,CameraChanges=0,
                PermissionChanges=0,
                PlayerFlags=matchedAttributes(P),
                StateFlags=state and matchedAttributes(state)or{},
                MTGFlags=mtg and matchedAttributes(mtg)or{},
                Camera={},RelevantModules={},RelevantScripts={},
                RelevantRemotes={},OtherRemoteNames={},
                RelevantGui={},BoundActions={},RelevantWorldObjects={},
                RootScans={},AdminConfigModules={},DevActionMetadata={},
                Note="Read-only snapshot of client-visible admin/spectate modules, summarized config and native camera state. Membership lists, identifiers and secrets are redacted; no DevAction invocation or admin access claims. Absence of a feature does not prove the server has none."
            }
            local camera=workspace.CurrentCamera
            if camera then
                local subject=camera.CameraSubject
                report.Camera={
                    CameraType=camera.CameraType.Name,
                    FieldOfView=camera.FieldOfView,
                    SubjectClass=subject and subject.ClassName or nil,
                    SubjectIsLocalCharacter=subject and P.Character
                        and subject:IsDescendantOf(P.Character)or false,
                    SubjectIsPlayerCharacter=false
                }
                if subject then
                    for _,other in ipairs(Players:GetPlayers())do
                        if other~=P and other.Character and
                            subject:IsDescendantOf(other.Character)then
                            report.Camera.SubjectIsPlayerCharacter=true
                            break
                        end
                    end
                end
            end
            local services={
                RS,
                game:GetService("ReplicatedFirst"),
                P:FindFirstChild("PlayerScripts"),
                P:FindFirstChild("PlayerGui"),
                game:GetService("StarterGui"),
                game:GetService("StarterPlayer"),
                workspace
            }
            for _,root in ipairs(services)do
                if root then
                    local scan={Root=path(root),Visited=0,Truncated=false}
                    local okDesc,descendants=pcall(function()
                        return root:GetDescendants()
                    end)
                    if not okDesc then
                        scan.Error="Descendant inspection unavailable"
                    else
                        for _,obj in ipairs(descendants)do
                            scan.Visited+=1
                            if scan.Visited>22000 then
                                scan.Truncated=true;break
                            end
                            local name=obj.Name
                            local hit=relevant(name)
                            if (obj:IsA("RemoteEvent")or
                                obj:IsA("RemoteFunction")or
                                obj:IsA("UnreliableRemoteEvent"))then
                                if hit and #report.RelevantRemotes<130 then
                                    report.RelevantRemotes[#report.RelevantRemotes+1]={
                                        Name=name,Class=obj.ClassName,
                                        Path=path(obj),
                                        Attributes=matchedAttributes(obj)
                                    }
                                elseif #report.OtherRemoteNames<220 then
                                    report.OtherRemoteNames[#report.OtherRemoteNames+1]={
                                        Name=name,Class=obj.ClassName,
                                        Path=path(obj)
                                    }
                                end
                            elseif obj:IsA("ModuleScript")and hit
                                and #report.RelevantModules<170 then
                                report.RelevantModules[#report.RelevantModules+1]={
                                    Name=name,Class=obj.ClassName,
                                    Path=path(obj),Attributes=matchedAttributes(obj)
                                }
                            elseif (obj:IsA("LocalScript")or obj:IsA("Script"))
                                and hit and #report.RelevantScripts<130 then
                                report.RelevantScripts[#report.RelevantScripts+1]={
                                    Name=name,Class=obj.ClassName,Path=path(obj),
                                    Enabled=not obj.Disabled
                                }
                            end
                            if root==P.PlayerGui then
                                local isGui=obj:IsA("GuiObject")
                                    or obj:IsA("ScreenGui")
                                if isGui and #report.RelevantGui<300 then
                                    local text=isGui and obj:IsA("GuiObject")
                                        and guiLabel(obj)or""
                                    if hit or relevant(text)
                                        or relevant(obj.Parent and obj.Parent.Name)then
                                        local row={
                                            Name=name,Class=obj.ClassName,
                                            Path=path(obj),Text=text,
                                            Attributes=matchedAttributes(obj)
                                        }
                                        if obj:IsA("ScreenGui")then
                                            row.Enabled=obj.Enabled
                                        else
                                            row.Visible=obj.Visible
                                            if obj:IsA("GuiButton")then
                                                row.Active=obj.Active
                                            end
                                        end
                                        report.RelevantGui[#report.RelevantGui+1]=row
                                    end
                                end
                            elseif root==workspace and hit
                                and #report.RelevantWorldObjects<110 then
                                report.RelevantWorldObjects[#report.RelevantWorldObjects+1]={
                                    Name=name,Class=obj.ClassName,Path=path(obj)
                                }
                            end
                        end
                    end
                    report.RootScans[#report.RootScans+1]=scan
                end
            end
            local okActions,actions=pcall(function()
                return game:GetService("ContextActionService"):GetAllBoundActionInfo()
            end)
            if okActions and type(actions)=="table"then
                for name,info in pairs(actions)do
                    local title=type(info)=="table"and info.title or nil
                    if (relevant(name)or relevant(title))
                        and #report.BoundActions<100 then
                        report.BoundActions[#report.BoundActions+1]={
                            Name=tostring(name):sub(1,150),
                            Title=title and tostring(title):sub(1,180)or nil,
                            Priority=type(info)=="table"and
                                tonumber(info.priorityLevel)or nil
                        }
                    end
                end
            end

            -- The first in-game dump revealed MTG.Config.Admin and
            -- MTG.Config.AdminReveal, but only recorded their names.
            -- Capture their safe configuration structure, retaining
            -- non-sensitive game feature flags and redact all identity,
            -- membership and credential values.
            local function protectedField(name)
                local key=tostring(name or""):lower()
                for _,term in ipairs({
                    "userid","user_id","username","password","secret",
                    "token","apikey","api_key","credential","whitelist",
                    "allowlist","banlist","owner","devids","adminids",
                    "moderatorids","staffids","groupid","group_id",
                    "members","accountids","authorizedusers",
                    "admins","moderators","developers","stafflist",
                    "staffusers","userlist","permitted","authorized",
                    "trustedusers","accesslist","superusers"
                })do
                    if key:find(term,1,true)then return true end
                end
                return false
            end
            local safeCount=0
            local function safeSummary(value,depth,seen,key)
                safeCount+=1
                if safeCount>1600 then return "[node limit]"end
                local kind=typeof(value)
                if protectedField(key)then
                    return "[redacted: identity/permission membership]"
                end
                if kind=="string"then return value:sub(1,160)end
                if kind=="number"or kind=="boolean"then return simple(value)end
                if kind=="function"then
                    local meta={Type="function"}
                    local dbg=type(debug)=="table"and debug or{}
                    if type(dbg.info)=="function"then
                        local ok,argc,variadic=pcall(dbg.info,value,"a")
                        if ok then meta.Arguments=argc;meta.Vararg=variadic end
                    end
                    local constantsFn=type(dbg.getconstants)=="function"
                        and dbg.getconstants or nil
                    if constantsFn then
                        local ok,constants=pcall(constantsFn,value)
                        if ok and type(constants)=="table"then
                            meta.FeatureConstants={}
                            for _,constant in pairs(constants)do
                                if type(constant)=="string"and #constant<=90
                                    and relevant(constant)
                                    and #meta.FeatureConstants<35 then
                                    meta.FeatureConstants[#meta.FeatureConstants+1]=constant
                                end
                            end
                        end
                    end
                    return meta
                end
                if kind=="Instance"then
                    return {Type=kind,Class=value.ClassName,Name=value.Name}
                end
                if kind~="table"then return {Type=kind}end
                if seen[value]then return "[repeated table]"end
                if depth>=4 then
                    local count=0
                    for _ in pairs(value)do count+=1 end
                    return {Type="table",Entries=count,Truncated=true}
                end
                seen[value]=true
                local output={};local total=0
                for subkey,item in pairs(value)do
                    total+=1
                    if total>140 then output.__truncated=true;break end
                    local name=tostring(subkey)
                    if type(subkey)=="string"or type(subkey)=="number"then
                        local target=type(subkey)=="number"and
                            tostring(subkey)or name:sub(1,100)
                        output[target]=safeSummary(item,depth+1,seen,name)
                    end
                end
                seen[value]=nil
                return output
            end
            local config=mtg and mtg:FindFirstChild("Config")
            for _,name in ipairs({"Admin","AdminReveal"})do
                local mod=config and config:FindFirstChild(name)
                local entry={Name=name,Found=mod~=nil,
                    Type=mod and mod.ClassName or nil}
                if mod and mod:IsA("ModuleScript")then
                    entry.Path=path(mod)
                    local success,result=pcall(require,mod)
                    entry.Loaded=success
                    if success then
                        entry.ExportType=typeof(result)
                        entry.Structure=safeSummary(result,0,{},"")
                    else
                        entry.Error=tostring(result):sub(1,160)
                    end
                end
                report.AdminConfigModules[#report.AdminConfigModules+1]=entry
            end
            -- A DevAction RemoteFunction exists, but its name does not
            -- imply usable privileges or a spectator feature. No calls.
            local remoteRoot=mtg and mtg:FindFirstChild("Remotes")
            local dev=remoteRoot and remoteRoot:FindFirstChild("DevAction")
            report.DevActionMetadata={
                Found=dev~=nil,Class=dev and dev.ClassName or nil,
                Path=dev and path(dev)or nil,
                Attributes=dev and matchedAttributes(dev)or{}
            }
            report.Counts={
                RelevantModules=#report.RelevantModules,
                RelevantScripts=#report.RelevantScripts,
                RelevantRemotes=#report.RelevantRemotes,
                OtherRemoteNames=#report.OtherRemoteNames,
                RelevantGui=#report.RelevantGui,
                BoundActions=#report.BoundActions,
                RelevantWorldObjects=#report.RelevantWorldObjects
            }
            local file="Geode/admin_spectate_diagnostics.json"
            writefile(file,H:JSONEncode(report))
            return {File=file,Counts=report.Counts,Role=report.Role}
        end)
        if not ok then
            api.LastError=tostring(result)
            api.Status="Spectate dump failed: "..api.LastError
            return false,api.LastError
        end
        api.LastError=nil;api.LastPath=result.File
        api.LastCounts=result.Counts
        api.Status="Saved "..result.File
            .." (modules "..tostring(result.Counts.RelevantModules)
            ..", relevant remotes "..tostring(result.Counts.RelevantRemotes)
            ..", UI "..tostring(result.Counts.RelevantGui)..")"
        return true,result.File
    end

    -- Targeted investigation of the actual developer FreeCam/LiveRuns
    -- CLIENT wiring. Never invokes DevAction/teleport, spectates players,
    -- changes camera or writes admin privileges. Only this manual button
    -- scans decompilable client scripts; avoid dumping unrelated code.
    function api.ExportSpectatePaths()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","Executor file writing unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local mtg=RS:FindFirstChild("MTG")
            local config=mtg and mtg:FindFirstChild("Config")
            local adminModule=config and config:FindFirstChild("Admin")
            local state=mtg and mtg:FindFirstChild("State")
            local report={
                Version=1,HubVersion=geodeVersion,
                TimeMs=DateTime.now().UnixTimestampMillis,
                Phase=state and state:GetAttribute("Phase"),
                Role=mtg and mtg:GetAttribute("Role"),
                ReadOnly=true,RemoteCalls=0,CameraChanges=0,
                Teleports=0,PermissionChanges=0,
                Config={},ClientScripts={},CandidateCount=0,
                InspectedCount=0,DecompileFailures=0,
                MatchedScripts=0,MatchedLines=0,
                ScanLimit=75,ScanTruncated=false,
                HasDecompiler=type(decompile)=="function",
                Note="Examines native client scripts for developer FreeCam and LiveRuns references. No admin access, spectator mode, free-camera activation, DevAction or teleport calls. Sensitive membership fields, long identifiers and unrelated source are not exported. No spectating permission is inferred."
            }
            if adminModule and adminModule:IsA("ModuleScript")then
                local loaded,cfg=pcall(require,adminModule)
                report.Config.Loaded=loaded
                if loaded and type(cfg)=="table"then
                    local free=type(cfg.FreeCam)=="table"and cfg.FreeCam or{}
                    local runs=type(cfg.LiveRuns)=="table"and cfg.LiveRuns or{}
                    local cooldowns=type(cfg.Cooldowns)=="table"
                        and cfg.Cooldowns or{}
                    report.Config.FreeCam={
                        Present=type(cfg.FreeCam)=="table",
                        Speed=tonumber(free.Speed),Smooth=tonumber(free.Smooth),
                        Fov=tonumber(free.Fov),
                        FovMin=tonumber(free.FovMin),
                        FovMax=tonumber(free.FovMax)
                    }
                    report.Config.LiveRuns={
                        Present=type(cfg.LiveRuns)=="table",
                        Enabled=runs.Enabled==true,
                        Beat=tonumber(runs.Beat),
                        MenuRefresh=tonumber(runs.MenuRefresh),
                        DevWait=tonumber(runs.DevWait),
                        Expire=tonumber(runs.Expire),
                        MaxList=tonumber(runs.MaxList),
                        TeleportTries=tonumber(runs.TeleportTries)
                    }
                    report.Config.WatchRunCooldown=tonumber(cooldowns.WatchRun)
                    report.Config.ShowButton=cfg.ShowButton==true
                    report.Config.MinRank=tonumber(cfg.MinRank)
                end
            end
            local scanTerms={
                "watchrun","liveruns","freecam","spectat",
                "watch player","watchplayer","devaction",
                "watch_run","runwatch","live_run",
                "followtarget","followplayer","adminpanel",
                "adminmenu","adminclient"
            }
            local excludeName={
                ["Fusion"]=true,["AdminReveal"]=true,
                ["PlayerModule"]=true
            }
            local candidates,seen={},{}
            local function addCandidate(scriptObj,source)
                if seen[scriptObj]then return end
                if not(scriptObj:IsA("LocalScript")
                    or scriptObj:IsA("ModuleScript"))then return end
                seen[scriptObj]=true
                local name=scriptObj.Name:lower()
                local score=source=="LocalClient"and 12 or 0
                if name:find("admin",1,true)
                    or name:find("spect",1,true)
                    or name:find("freecam",1,true)
                    or name:find("watch",1,true)
                    or name:find("live",1,true)then
                    score+=120
                elseif name:find("dev",1,true)
                    or name:find("camera",1,true)
                    or name:find("run",1,true)
                    or name:find("boot",1,true)
                    or name:find("client",1,true)
                    or name:find("main",1,true)then
                    score+=65
                elseif name:find("menu",1,true)
                    or name:find("hud",1,true)
                    or name:find("ui",1,true)then
                    score+=20
                end
                if scriptObj==adminModule then return end
                candidates[#candidates+1]={
                    Object=scriptObj,Source=source,Score=score,
                    Name=scriptObj.Name,Path=path(scriptObj)
                }
            end
            local scripts=P:FindFirstChild("PlayerScripts")
            local roots={
                {Inst=scripts and scripts:FindFirstChild("MTGClient"),
                    Source="LocalClient"},
                {Inst=mtg and mtg:FindFirstChild("Modules"),
                    Source="ReplicatedModules"},
                {Inst=config,Source="ReplicatedConfig"}
            }
            for _,item in ipairs(roots)do
                if item.Inst then
                    if item.Inst:IsA("ModuleScript")
                        or item.Inst:IsA("LocalScript")then
                        addCandidate(item.Inst,item.Source)
                    end
                    local okDesc,desc=pcall(function()
                        return item.Inst:GetDescendants()
                    end)
                    if okDesc then
                        for _,obj in ipairs(desc)do
                            if obj:IsA("ModuleScript")
                                or obj:IsA("LocalScript")then
                                local skip=false
                                local ancestor=obj.Parent
                                while ancestor and ancestor~=item.Inst do
                                    if excludeName[ancestor.Name]then
                                        skip=true;break
                                    end
                                    ancestor=ancestor.Parent
                                end
                                if not skip then addCandidate(obj,item.Source)end
                            end
                        end
                    end
                end
            end
            table.sort(candidates,function(a,b)
                if a.Score==b.Score then return a.Path<b.Path end
                return a.Score>b.Score
            end)
            report.CandidateCount=#candidates
            report.ScanTruncated=#candidates>report.ScanLimit
            local decompiler=type(decompile)=="function"and decompile or nil
            if decompiler then
                for index=1,math.min(#candidates,report.ScanLimit)do
                    local item=candidates[index]
                    local success,source=pcall(decompiler,item.Object)
                    report.InspectedCount+=1
                    if not success or type(source)~="string"then
                        report.DecompileFailures+=1
                    else
                        local found={}
                        local lineNumber=0
                        for line in (source.."\n"):gmatch("(.-)\n")do
                            lineNumber+=1
                            local low=line:lower()
                            local terms={}
                            for _,term in ipairs(scanTerms)do
                                if low:find(term,1,true)then
                                    terms[#terms+1]=term
                                end
                            end
                            if #terms>0 and #found<24 then
                                local excerpt=line:sub(1,260)
                                -- Never export identity or membership values
                                -- from decompiled admin client literals.
                                if low:find("userid",1,true)
                                    or low:find("username",1,true)
                                    or low:find("ownerid",1,true)
                                    or low:find("adminids",1,true)
                                    or low:find("password",1,true)
                                    or low:find("secret",1,true)
                                    or low:find("token",1,true)then
                                    excerpt="[redacted sensitive client line]"
                                else
                                    excerpt=excerpt:gsub("%d%d%d%d%d%d%d%d+", "[numeric-id]")
                                end
                                found[#found+1]={
                                    Line=lineNumber,Terms=terms,Excerpt=excerpt
                                }
                            end
                        end
                        if #found>0 then
                            report.MatchedScripts+=1
                            report.MatchedLines+=#found
                            report.ClientScripts[#report.ClientScripts+1]={
                                Name=item.Name,Path=item.Path,
                                Source=item.Source,Bytes=#source,
                                Matches=found
                            }
                        end
                    end
                    if index%4==0 then task.wait()end
                end
            end
            local file="Geode/spectate_client_paths_diagnostics.json"
            writefile(file,H:JSONEncode(report))
            return {File=file,Scanned=report.InspectedCount,
                Matches=report.MatchedScripts,
                HasDecompiler=report.HasDecompiler}
        end)
        if not ok then
            api.Status="Spectate client scan failed: "..tostring(result)
            return false,api.Status
        end
        api.Status="Saved "..result.File.." (scanned "
            ..tostring(result.Scanned).." scripts, matched "
            ..tostring(result.Matches)
            ..", decompiler="..tostring(result.HasDecompiler)..")"
        return true,result.File
    end

    -- Exact source for the two CONFIRMED native spectator modules.
    -- Manual, read-only export, no camera alteration or remote invocations.
    function api.ExportNativeSpectator()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","File export unavailable")
            assert(type(decompile)=="function",
                "Native client decompiler unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local scripts=P:FindFirstChild("PlayerScripts")
            local client=scripts and scripts:FindFirstChild("MTGClient")
            local report={
                Version=1,HubVersion=geodeVersion,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                ReadOnly=true,RemoteCalls=0,CameraChanges=0,
                PermissionChanges=0,Teleports=0,
                LocalSpectator=P:GetAttribute("Spectator")==true,
                HasSpectateTargetAttribute=
                    P:GetAttribute("SpectateTarget")~=nil,
                Modules={},Saved=0,
                Note="Exports two native client-local spectator implementations for code review only. No DevAction call, camera changes, forced Spectator attribute, teleport or permission modification. No player IDs or player lists in metadata. Exported source is for inspection, not execution."
            }
            for _,spec in ipairs({
                {Name="WatchRun",
                    File="Geode/spectate_native_WatchRun.lua"},
                {Name="DevTools",
                    File="Geode/spectate_native_DevTools.lua"}
            })do
                local module=client and client:FindFirstChild(spec.Name)
                local row={Name=spec.Name,
                    Found=module~=nil,
                    Class=module and module.ClassName or nil}
                if module and(module:IsA("ModuleScript")
                    or module:IsA("LocalScript"))then
                    local good,source=pcall(decompile,module)
                    row.Decompiled=good and type(source)=="string"
                        and #source>0
                    if row.Decompiled then
                        row.SourceBytes=#source
                        -- Both observed decompilations fit below this cap.
                        -- An unexpected larger build is marked truncated.
                        row.Truncated=#source>130000
                        local output=row.Truncated and
                            source:sub(1,130000)or source
                        -- Preserve executable-looking syntax for review,
                        -- but mask long numerical account identifiers.
                        output=output:gsub("%d%d%d%d%d%d%d%d+",
                            "[redacted-numeric-id]")
                        local wrote,err=pcall(writefile,spec.File,output)
                        row.Saved=wrote
                        if wrote then
                            row.File=spec.File
                            report.Saved+=1
                        else
                            row.Error=tostring(err):sub(1,180)
                        end
                    else
                        row.Error=tostring(source):sub(1,180)
                    end
                end
                report.Modules[#report.Modules+1]=row
            end
            local output="Geode/spectate_native_modules_diagnostics.json"
            writefile(output,H:JSONEncode(report))
            return {File=output,Saved=report.Saved}
        end)
        if not ok then
            api.Status="Native spectator export failed: "..tostring(result)
            return false,api.Status
        end
        api.Status="Saved "..result.File.." and "
            ..tostring(result.Saved).."/2 native spectator modules"
        return true,result.File
    end
    return api
end
local AdminSpectateInspector=createAdminSpectateInspector()

-- Native DevTools.spectate is local camera-follow only; it has no server
-- permission check or DevAction call. WatchRun is a separate server-granted
-- mode that requires player Spectator=true and must not be spoofed.
local function createLocalSpectateController()
    local Players=game:GetService("Players")
    local P=Players.LocalPlayer
    local api={
        Running=true,Active=false,FreeCam=false,
        TargetName=nil,SelectedName=nil,Status="Idle — own camera",
        LastError=nil
    }
    local native=nil
    local ownsSpectate=false
    local ownsFreeCam=false
    local function getNative()
        if native then return native end
        local ps=P:FindFirstChild("PlayerScripts")
        local client=ps and ps:FindFirstChild("MTGClient")
        local module=client and client:FindFirstChild("DevTools")
        if not module or not module:IsA("ModuleScript")then
            return nil,"Native DevTools module is unavailable"
        end
        local ok,result=pcall(require,module)
        if not ok or type(result)~="table"
            or type(result.spectate)~="function"
            or type(result.setFreeCam)~="function"
            or type(result.State)~="table"then
            return nil,"Native DevTools cannot be loaded"
        end
        native=result
        return native
    end
    local function available()
        local names={}
        for _,player in ipairs(Players:GetPlayers())do
            if player~=P and player:GetAttribute("Spectator")~=true then
                names[#names+1]=player.Name
            end
        end
        table.sort(names)
        return names
    end
    function api.PlayerNames()
        local names=available()
        if #names==0 then return {"(No eligible players in server)"}end
        return names
    end
    function api.Select(name)
        if type(name)~="string"then return end
        api.SelectedName=name
    end
    local function stopSpectating()
        local wasOwning=ownsSpectate
        ownsSpectate=false
        api.Active=false
        api.TargetName=nil
        if wasOwning and native and type(native.spectate)=="function"then
            pcall(native.spectate,nil)
        end
    end
    local function stopFreeCam()
        local wasOwning=ownsFreeCam
        ownsFreeCam=false
        api.FreeCam=false
        if wasOwning and native and type(native.setFreeCam)=="function"then
            pcall(native.setFreeCam,false)
        end
    end
    function api.Stop()
        stopSpectating()
        stopFreeCam()
        api.Status="Own camera restored"
        api.LastError=nil
        return true,api.Status
    end
    local function notInOfficialMode()
        if P:GetAttribute("Spectator")==true then
            api.LastError="Official WatchRun spectator state is active; use its own controls"
            api.Status=api.LastError
            return false
        end
        return true
    end
    function api.Start(name)
        if not api.Running then return false,"Spectate controller unloaded"end
        if not notInOfficialMode()then return false,api.LastError end
        name=type(name)=="string"and name or api.SelectedName
        local target=name and Players:FindFirstChild(name)or nil
        if not target or target==P or target:GetAttribute("Spectator")==true then
            api.Status="Select a non-spectator player in your current server"
            return false,api.Status
        end
        if not(target.Character and
            target.Character:FindFirstChildOfClass("Humanoid"))then
            api.Status="Target character is not spawned yet"
            return false,api.Status
        end
        local tools,err=getNative()
        if not tools then api.Status=err;return false,err end
        if tools.State.Photo then
            api.Status="Exit the game's photo mode before spectating"
            return false,api.Status
        end
        if tools.State.FreeCam and not ownsFreeCam then
            api.Status="Exit the game's existing FreeCam first"
            return false,api.Status
        end
        if tools.State.Spectating and not ownsSpectate then
            api.Status="Another spectator camera is already active"
            return false,api.Status
        end
        -- Only undo FreeCam when this BeyyHub controller enabled it.
        if ownsFreeCam then stopFreeCam()end
        local ok,why=pcall(tools.spectate,target)
        if not ok or tools.State.Spectating~=target then
            api.Status="Native camera follow failed: "..tostring(why)
            api.LastError=api.Status
            if ownsSpectate then stopSpectating()end
            return false,api.Status
        end
        ownsSpectate=true
        api.Active=true;api.FreeCam=false
        api.SelectedName=target.Name;api.TargetName=target.Name
        api.Status="Locally watching @"..target.Name
            .." (same server, camera only)"
        api.LastError=nil
        return true,api.Status
    end
    function api.Cycle(step)
        if not api.Running then return false,"Controller unloaded"end
        local names=available()
        if #names==0 then
            api.Status="No eligible players in this server"
            return false,api.Status
        end
        local current=api.TargetName or api.SelectedName
        local at=table.find(names,current)or 0
        local offset=tonumber(step)or 1
        local index
        if at==0 then
            index=offset<0 and #names or 1
        else
            index=(at-1+offset)%#names+1
        end
        return api.Start(names[index])
    end
    function api.SetFreeCam(value)
        if not api.Running then return false,"Controller unloaded"end
        if value~=true then
            stopFreeCam()
            api.Status=api.Active and("Locally watching @"..tostring(api.TargetName))
                or"Local FreeCam off — own camera"
            return true,api.Status
        end
        if not notInOfficialMode()then return false,api.LastError end
        local tools,err=getNative()
        if not tools then api.Status=err;return false,err end
        if tools.State.Photo then
            api.Status="Exit the game's photo mode before FreeCam"
            return false,api.Status
        end
        if tools.State.FreeCam and not ownsFreeCam then
            api.Status="FreeCam is already controlled by the game"
            return false,api.Status
        end
        if tools.State.Spectating and not ownsSpectate then
            api.Status="Another spectator mode owns the camera"
            return false,api.Status
        end
        if ownsSpectate then stopSpectating()end
        local ok,why=pcall(tools.setFreeCam,true)
        if not ok or tools.State.FreeCam~=true then
            api.Status="Native FreeCam failed: "..tostring(why)
            api.LastError=api.Status
            return false,api.Status
        end
        ownsFreeCam=true
        api.FreeCam=true;api.Active=false;api.TargetName=nil
        api.Status="Local FreeCam on (camera only)"
        api.LastError=nil
        return true,api.Status
    end
    function api.Tick()
        if not api.Running or not native then return end
        if P:GetAttribute("Spectator")==true then
            -- The game's own server-controlled WatchRun takes priority.
            if ownsSpectate then stopSpectating()end
            if ownsFreeCam then stopFreeCam()end
            api.Status="Official WatchRun spectator mode is active"
            return
        end
        if ownsSpectate then
            local target=native.State.Spectating
            if not target or target.Parent~=Players
                or target:GetAttribute("Spectator")==true then
                stopSpectating()
                api.Status="Spectated player left or camera was restored"
            else
                api.Active=true;api.TargetName=target.Name
            end
        end
        if ownsFreeCam and native.State.FreeCam~=true then
            ownsFreeCam=false;api.FreeCam=false
            api.Status="Local FreeCam turned off"
        end
    end
    function api.Unload()
        api.Stop()
        api.Running=false
    end
    return api
end
local LocalSpectate=createLocalSpectateController()
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
    local api={Running=true,Enabled=false,Busy=false,FastTravel=true,FlyTravel=true,FlySpeed=16,FlightActive=false,FlightDistance=0,FlightTrips=0,Turbo=true,Stage="Idle",Status="Paused",Interval=1,WinFarmFast=false,WinFarmDelay=.10,Continuous=false,RepeatInterval=10,Cycles=0,Sales=0,CashGained=0,OneShotCompleted=false,LastTripSeconds=0,LastTripTeleports=0,LastTripMovesSaved=0,TotalTeleports=0,
        PromptRetries=0,LastPromptFailure="",LastFailureStage="",LastSaleConfirmed=false,
        AutoResumeBlocked=false,EndlessBossInterruptions=0,EndlessRestarts=0}
    local armedAt;local lastBag;local observedIdentity
    local deadline=0;local readyAt=0;local identity;local cracked=false;local sold=false;local saleBefore=0
    local tripStartedAt,stageStartedAt
    local retries={Deposit=0,Station=0,Sell=0};local retryAt=0
    local saleWasConfirmed=false
    local activeBagDelay -- Forward declaration: bag callbacks use this before its definition.
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
            Crates=c.CrateCount,Bin=c.BinCount,WaitSeconds=activeBagDelay()})
        return true
    end
    function api.BagChanged(value)
        value=tonumber(value)or 0
        local changed=lastBag~=nil and lastBag~=value
        lastBag=value
        if api.Running and api.Enabled and not api.Busy and changed and not armedAt then
            armedAt=options.Now()
            record("CollectionWindowStarted",{BagCount=value,WaitSeconds=activeBagDelay()})
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
    function api.SetFlyTravel(value)
        local useFly=value==true
        if api.FlyTravel~=useFly and api.Busy then
            api.Stop("Camp movement mode changed")
        end
        api.FlyTravel=useFly
    end
    function api.SetFlySpeed(value)
        local speed=tonumber(value)
        if speed and speed==speed then api.FlySpeed=math.clamp(speed,4,29)end
    end
    function api.SetTurbo(value)
        api.Turbo=value==true
        record("TurboModeChanged",{Enabled=api.Turbo})
    end
    function api.SetInterval(value)
        value=tonumber(value)
        if value and value==value then api.Interval=math.clamp(value,.10,60)end
    end
    function api.SetWinFarmFast(value)
        -- Auto Win Farm only: preserve the user's normal Crack Delay.
        -- Restore the ordinary delay when Win Farm exits; the sale itself
        -- still waits for real bag feedback and native server confirmation.
        api.WinFarmFast=value==true
    end
    activeBagDelay=function()
        return api.WinFarmFast and math.min(api.Interval,api.WinFarmDelay)
            or api.Interval
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
        local ok,reason,alreadyNear,eta=options.MoveTo(target)
        if not ok then api.Stop(reason or("Could not approach "..target));return false end
        local timeout=api.FlyTravel and math.max(7,(eta or 0)*1.5+5)or 4
        stage(target.."Approach",api.FlyTravel and ("Flying to "..target:lower())or("Approaching "..target:lower()),timeout)
        readyAt=options.Now()+(alreadyNear and 0 or (api.FlyTravel and .05 or (api.FastTravel and (api.Turbo and .10 or .18) or .2)))
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
    local function finalizeCycle(reason)
        api.LastTripSeconds=tripStartedAt and
            math.floor((options.Now()-tripStartedAt)*1000+.5)/1000 or 0
        record("CycleComplete",{Cycles=api.Cycles,TripSeconds=api.LastTripSeconds,
            Teleports=api.LastTripTeleports,SkippedMoves=api.LastTripMovesSaved,
            FlightTrips=api.FlightTrips})
        finish("Cycle complete — returned to pickup position")
        if api.AutoResumeBlocked then
            api.Stop("Camp cleanup failed — repeating disabled; check diagnostics")
        elseif reason then
            api.Stop(reason)
        elseif not api.Continuous then
            api.OneShotCompleted=true
            api.Enabled=false
            api.Status="Single Crack & Sell cycle completed — toggle on for another"
            record("OneShotComplete",{Cycles=api.Cycles,Sales=api.Sales})
        end
    end
    local function completed(c)
        api.Cycles+=1
        api.LastSaleConfirmed=saleWasConfirmed
        local stopReason=not api.Continuous and api.PendingStopReason
        if api.FlyTravel and options.MoveTo then
            local ok,reason,alreadyNear,eta=options.MoveTo("Return")
            if not ok then
                api.Stop(reason or "Could not fly back to pickup position")
                return
            end
            if not alreadyNear then
                api.ReturnStopReason=stopReason
                stage("ReturnApproach","Flying back to pickup position",
                    math.max(7,(eta or 0)*1.5+5))
                return
            end
        end
        finalizeCycle(stopReason)
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
            local interval=api.Continuous and api.RepeatInterval or activeBagDelay()
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
        if api.Stage=="ReturnApproach"then
            if options.NearTarget and options.NearTarget("Return")then
                local reason=api.ReturnStopReason;api.ReturnStopReason=nil
                finalizeCycle(reason)
            else
                api.Status="Flying back to pickup position"
            end
            return
        end
        if api.Stage=="DepositApproach"and now>=readyAt then
            if api.FlyTravel and options.NearTarget and not options.NearTarget("Deposit")then
                return
            end
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
            if api.FlyTravel and options.NearTarget and not options.NearTarget("Station")then
                return
            end
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
            if api.FlyTravel and options.NearTarget and not options.NearTarget("Sell")then
                return
            end
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
    local RunService=game:GetService("RunService")
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local Bench=require(P.PlayerScripts.MTGClient.Bench)
    local State=require(P.PlayerScripts.MTGClient.State)
    local remote=MTG.Remotes:WaitForChild("Bench")
    local camp,character,identity,station,entry,deposit,sell
    local savedPose,savedCharacter,savedCamp;local enteredByUs=false;local events={};local dirty=false;local generation=0
    local api
    local wake
    local campConnections={}
    local stopFlight -- Cleanup must also be callable from earlier camp finish().
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
        stopFlight()
        local r=root()
        local poseToRestore=savedPose and savedCharacter==P.Character and savedCamp==camp and valid()and r and savedPose
        savedPose=nil;savedCharacter=nil;savedCamp=nil
        if poseToRestore and leaveOK and not api.NoTeleport and not api.FlyTravel then r.CFrame=poseToRestore;r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero end
        if not leaveOK then error(leaveError)end
    end
    local function near(prompt,point)
        return prompt and prompt.Parent and prompt.Parent:IsA("BasePart")
            and(point-prompt.Parent.Position).Magnitude<=math.max(0,prompt.MaxActivationDistance-1)
    end

    local flightRoot,flightAttachment,flightConstraint,flightTarget,flightPrompt
    local priorCollisions={}
    stopFlight=function()
        flightTarget=nil;flightPrompt=nil
        if flightConstraint then
            pcall(function()flightConstraint.VectorVelocity=Vector3.zero end)
            flightConstraint:Destroy();flightConstraint=nil
        end
        if flightAttachment then flightAttachment:Destroy();flightAttachment=nil end
        flightRoot=nil
        for part,old in pairs(priorCollisions)do
            if part.Parent then part.CanCollide=old end
        end
        table.clear(priorCollisions)
        if api then api.FlightActive=false;api.FlightDistance=0 end
    end
    local function beginFlight(target,prompt)
        local r=root();if not r then return false end
        if flightRoot~=r or not flightConstraint or flightConstraint.Parent~=r then
            stopFlight()
            flightRoot=r
            flightAttachment=Instance.new("Attachment")
            flightAttachment.Name="BeyyCrackSellFlightAttachment"
            flightAttachment.Parent=r
            flightConstraint=Instance.new("LinearVelocity")
            flightConstraint.Name="BeyyCrackSellFlight"
            flightConstraint.Attachment0=flightAttachment
            flightConstraint.RelativeTo=Enum.ActuatorRelativeTo.World
            flightConstraint.ForceLimitsEnabled=false
            flightConstraint.VectorVelocity=Vector3.zero
            flightConstraint.Parent=r
        end
        flightTarget=target;flightPrompt=prompt
        if api then api.FlightActive=true;api.FlightTrips+=1 end
        return true
    end
    local function nearTarget(destination)
        local r=root();if not r then return false end
        if destination=="Return"then
            return savedPose==nil or (r.Position-savedPose.Position).Magnitude<=2
        end
        local prompt=destination=="Deposit"and deposit
            or(destination=="Sell"and sell or entry)
        return near(prompt,r.Position)
    end
    local flightHeartbeat=RunService.Heartbeat:Connect(function()
        if not api or not api.Running or not api.Busy
            or not api.FlyTravel or not flightTarget then return end
        local r=root()
        local hum=P.Character and P.Character:FindFirstChildOfClass("Humanoid")
        if r~=flightRoot or not flightConstraint or not hum or hum.Health<=0 then
            stopFlight();return
        end
        local offset=flightTarget-r.Position
        local distance=offset.Magnitude
        api.FlightDistance=distance
        if distance<=1.5 or (flightPrompt and near(flightPrompt,r.Position))
            or hum.Sit or r.Anchored then
            stopFlight();return
        end
        for _,obj in ipairs(P.Character:GetDescendants())do
            if obj:IsA("BasePart")then
                if priorCollisions[obj]==nil then priorCollisions[obj]=obj.CanCollide end
                if obj.CanCollide then obj.CanCollide=false end
            end
        end
        local speed=math.min(api.FlySpeed,29,distance*3.2)
        flightConstraint.VectorVelocity=offset.Unit*speed
    end)

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
        if target=="Return"then
            if not savedPose or (r.Position-savedPose.Position).Magnitude<=2 then
                stopFlight();return true,nil,true,0
            end
            if api.FlyTravel then
                local distance=(r.Position-savedPose.Position).Magnitude
                if not beginFlight(savedPose.Position,nil)then
                    return false,"Could not start return flight"
                end
                return true,nil,false,distance/math.max(4,api.FlySpeed)
            end
            return true,nil,true,0
        end
        local prompt=target=="Deposit"and deposit or(target=="Sell"and sell or entry)
        if target=="Station"and(not station or not station.Parent or(station:GetAttribute("Occupant")or 0)~=0)then
            station,entry=chooseStation();prompt=entry
        end
        if not prompt or not prompt.Parent or not prompt.Enabled then return false,target.." interaction unavailable"end
        if near(prompt,r.Position)then
            stopFlight()
            if api then api.LastTripMovesSaved+=1 end
            return true,nil,true,0
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
        if api.FlyTravel then
            local distance=(point-r.Position).Magnitude
            if not beginFlight(point,prompt)then return false,"Could not start camp flight"end
            return true,nil,false,distance/math.max(4,api.FlySpeed)
        end
        if api.NoTeleport then return false,"Safe Auto Endless blocks camp teleport travel"end
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
    end,MoveTo=moveTo,NearTarget=nearTarget,Deposit=function()trigger(deposit)end,Enter=function()enteredByUs=true;trigger(entry)end,
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
                WinFarmFast=api.WinFarmFast,EffectiveBagDelay=activeBagDelay(),FlyTravel=api.FlyTravel,FlySpeed=api.FlySpeed,FlightActive=api.FlightActive,FlightDistance=api.FlightDistance,FlightTrips=api.FlightTrips,LastTripSeconds=api.LastTripSeconds,LastTripTeleports=api.LastTripTeleports,
                LastTripMovesSaved=api.LastTripMovesSaved,TotalTeleports=api.TotalTeleports,Events=events}))
        end)
        if ok then dirty=false end
        return ok,err
    end
    local unload=api.Unload
    function api.Unload()
        if not api.Running then return end
        unload()
        stopFlight()
        flightHeartbeat:Disconnect()
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
local upgradeShopBusy=false
local function createMagnetUpgradeController(options)
    local ids={"MagPower","MagSpeed"};local cursor=1;local pending;local nextRequest=0;local requestEpoch=0
    local api={Running=true,Enabled=false,PowerFirst=true,FastPurchases=true,
        InFlight=false,Status="Paused",Confirmed=0,Requests=0,BusyResponses=0,
        LastRequestMs=0,LastConfirmationMs=0,LastConfirmedTrack=nil,LastRequestedTrack=nil,LastCost=nil,DefinitionErrors=0,ConfirmationTimeouts=0}
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
    function api.Start()
        if not api.Running then return end
        requestEpoch+=1;pending=nil;nextRequest=0
        api.Enabled=true;api.Status="Checking GEO-MAG upgrades"
    end
    function api.Stop(reason)
        requestEpoch+=1
        api.Enabled=false;pending=nil
        api.Status=reason or"Paused"
        record("Stopped",{Reason=api.Status})
    end
    function api.Unload()if not api.Running then return end;api.Stop();api.Running=false end
    function api.Tick()
        if not api.Running or not api.Enabled or api.InFlight then return end
        local now=options.Now();local context=options.Context()
        if pending then
            if(context.Levels[pending.Id]or 0)>=pending.Level then
                api.Confirmed+=1
                api.LastConfirmedTrack=pending.Id
                api.LastConfirmationMs=math.floor((now-pending.SentAt)*1000+.5)
                record("Confirmed",{Id=pending.Id,Level=pending.Level,
                    ConfirmationMs=api.LastConfirmationMs})
                cursor=pending.NextCursor;pending=nil
            elseif now>=pending.Deadline then
                api.ConfirmationTimeouts+=1
                record("ConfirmationTimeout",{Id=pending.Id,Expected=pending.Level,Observed=context.Levels[pending.Id]or 0})
                api.Stop("GEO-MAG "..pending.Id.." confirmation timed out");return
            else api.Status="Waiting for "..pending.Id.." confirmation";return end
        end
        if now<nextRequest then return end
        if not context.Allowed then api.Status="Waiting for mining and the camp cycle to finish";return end
        if not context.Owned then api.Status="Waiting for GEO-MAG 3000 ownership";return end
        local selected,maxed,missing=nil,0,false
        for offset=0,1 do
            local id=api.PowerFirst and ids[offset+1]
                or ids[(cursor-1+offset)%2+1]
            local def=context.Tracks[id]
            local level=tonumber(context.Levels[id])or 0
            if not def or not def.Valid then
                missing=true
            elseif level>=def.Max then
                maxed+=1
            elseif def.Cost and def.Cost<=context.Cash and not selected then
                selected={
                    Id=id,Level=level+1,Cost=def.Cost,
                    NextCursor=api.PowerFirst and cursor
                        or ((cursor-1+offset)%2+1)%2+1
                }
            end
        end
        if missing then
            api.DefinitionErrors+=1
            api.Status="GEO-MAG upgrade definition or price unavailable"
            return
        end
        if maxed==2 then api.Status="Both GEO-MAG upgrades are maxed";return end
        if not selected then api.Status="Waiting for enough cash";return end
        if upgradeShopBusy then api.Status="Other upgrade request in flight";return end
        local epoch=requestEpoch
        upgradeShopBusy=true
        api.InFlight=true;api.Requests+=1
        api.LastRequestedTrack=selected.Id;api.LastCost=selected.Cost
        local sentAt=options.Now()
        record("Request",{Id=selected.Id,Level=selected.Level,Cost=selected.Cost,
            Fast=api.FastPurchases})
        local ok,result=pcall(options.Invoke,selected.Id)
        local responseAt=options.Now()
        api.LastRequestMs=math.floor((responseAt-sentAt)*1000+.5)
        api.InFlight=false;upgradeShopBusy=false
        if epoch~=requestEpoch or not api.Enabled then return end
        -- Continue promptly after the server responds, but never overlap
        -- a purchase that is still awaiting replicated level confirmation.
        nextRequest=responseAt+(api.FastPurchases and .05 or .15)
        if not ok then record("Error",{Error=tostring(result)});api.Stop("Purchase request failed; check upgrade state before retrying");return end
        record("Response",{Id=selected.Id,Result=result,RequestMs=api.LastRequestMs})
        if type(result)~="table"then api.Stop("Unexpected upgrade response");return end
        if result.Ok==true then
            pending={Id=selected.Id,Level=math.max(selected.Level,tonumber(result.Level)or 0),
                Cost=selected.Cost,NextCursor=selected.NextCursor,SentAt=responseAt,Deadline=responseAt+6}
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
        local state=State.ctx()
        local levels=type(state)=="table"and type(state.Upg)=="table"
            and state.Upg or {}
        local tracks={}
        for _,id in ipairs({"MagPower","MagSpeed"})do
            local def=Upgrades.ById and Upgrades.ById[id]
            local costs=def and def.Costs
            local level=tonumber(levels[id])or 0
            local valid=type(costs)=="table"and #costs>0
            local raw=valid and costs[level+1]or nil
            local ok,price=true,nil
            if raw then ok,price=pcall(Mode.price,raw)end
            price=ok and tonumber(price)or nil
            tracks[id]={Max=valid and #costs or 0,
                Cost=price,Valid=valid and (level>=#costs or price~=nil)}
        end
        local owned=State.set("Tools")
        return {Allowed=State.role()=="Game"
                and State.run("Phase")=="Mining"and not CrackSell.Busy,
            Owned=type(owned)=="table"and owned.Magnet==true,
            Levels=levels,Tracks=tracks,
            Cash=tonumber(P:GetAttribute("Cash"))or 0}
    end,Invoke=function(id)return remote:InvokeServer("Upgrade",id)end,Record=function(kind,data)
        events[#events+1]={Kind=kind,WallTimeMs=DateTime.now().UnixTimestampMillis,Data=data}
        if #events>80 then table.remove(events,1)end;dirty=true
    end})
    function api.Export()
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/magnet_upgrade_diagnostics.json",H:JSONEncode({Version=2,HubVersion=geodeVersion,Enabled=api.Enabled,Status=api.Status,
                Confirmed=api.Confirmed,PowerFirst=api.PowerFirst,FastPurchases=api.FastPurchases,
                Requests=api.Requests,BusyResponses=api.BusyResponses,
                LastRequestedTrack=api.LastRequestedTrack,LastConfirmedTrack=api.LastConfirmedTrack,
                LastCost=api.LastCost,DefinitionErrors=api.DefinitionErrors,
                ConfirmationTimeouts=api.ConfirmationTimeouts,
                LastRequestMs=api.LastRequestMs,LastConfirmationMs=api.LastConfirmationMs,
                RequestedGapSeconds=api.FastPurchases and .05 or .15,
                PollIntervalSeconds=api.FastPurchases and .025 or .1,
                Levels=State.ctx()and State.ctx().Upg,Cash=P:GetAttribute("Cash"),
                Tracks=(function()
                    local info={}
                    local state=State.ctx()
                    local levels=state and state.Upg or {}
                    for _,id in ipairs({"MagPower","MagSpeed"})do
                        local def=Upgrades.ById and Upgrades.ById[id]
                        local level=tonumber(levels[id])or 0
                        local price=def and def.Costs and def.Costs[level+1]
                        local ok,cost=pcall(function()
                            return price and Mode.price(price)
                        end)
                        info[id]={Level=level,Max=def and def.Costs and #def.Costs or nil,
                            NextCost=ok and tonumber(cost)or nil}
                    end
                    return info
                end)(),Events=events}))
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

-- Opt-in native Crack Power upgrades: never submit a second purchase
-- before the previous upgrade level is confirmed by State.ctx().Upg.
local function createLiveCrackPowerUpgrades()
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local S=require(P.PlayerScripts.MTGClient.State)
    local UpgradeConfig=require(MTG.Config.Upgrades)
    local Mode=require(MTG.Modules.Mode)
    local ShopRemote=MTG.Remotes:WaitForChild("Shop")
    local api={Running=true,Enabled=false,Status="Paused",Level=0,MaxLevel=0,
        InFlight=false,Requests=0,Confirmed=0,BusyResponses=0,
        LastRequestMs=0,LastConfirmationMs=0}
    local pending,nextAt,epoch=nil,0,0
    local events={}
    local function record(kind,details)
        events[#events+1]={Kind=kind,AtMs=DateTime.now().UnixTimestampMillis,Data=details}
        if #events>60 then table.remove(events,1)end
    end
    function api.Start()
        if not api.Running then return end
        epoch+=1;api.Enabled=true;api.Status="Checking Crack Power"
    end
    function api.Stop(reason)
        epoch+=1;api.Enabled=false;pending=nil;api.Status=reason or"Paused"
    end
    function api.Unload()api.Stop();api.Running=false end
    function api.Export()
        return pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/crack_power_upgrade_diagnostics.json",H:JSONEncode({
                Version=1,HubVersion=geodeVersion,Enabled=api.Enabled,Status=api.Status,
                Level=api.Level,MaxLevel=api.MaxLevel,InFlight=api.InFlight,
                Requests=api.Requests,Confirmed=api.Confirmed,BusyResponses=api.BusyResponses,
                LastRequestMs=api.LastRequestMs,LastConfirmationMs=api.LastConfirmationMs,
                Cash=P:GetAttribute("Cash"),Events=events
            }))
        end)
    end
    local function tick()
        if not api.Enabled or api.InFlight then return end
        local now=os.clock()
        local ctx=S.ctx()
        local level=tonumber(ctx and ctx.Upg and ctx.Upg.Power)or 0
        local def=UpgradeConfig.ById.Power
        api.Level=level
        if not def or type(def.Costs)~="table"then api.Stop("Power definition unavailable");return end
        api.MaxLevel=#def.Costs
        if pending then
            if level>=pending.Level then
                api.Confirmed+=1
                api.LastConfirmationMs=math.floor((now-pending.At)*1000+.5)
                record("Confirmed",{Level=level,Ms=api.LastConfirmationMs})
                pending=nil
            elseif now>=pending.Deadline then
                api.Stop("Power level confirmation timed out");return
            else api.Status="Awaiting replicated Power level";return end
        end
        if level>=api.MaxLevel then api.Status="Crack Power maxed";return end
        if now<nextAt then return end
        local phase=S.run("Phase")
        if S.role()~="Game"or(phase~="Mining"and phase~="Mother")
            or S.run("Ended",false)==true or S.run("EndlessOver",false)==true then
            api.Status="Waiting for active Mining/Mother phase";return
        end
        if upgradeShopBusy then api.Status="Other upgrade request in flight";return end
        local cost=tonumber(Mode.price(def.Costs[level+1]))
        if not cost then api.Stop("Power price unavailable");return end
        if (tonumber(P:GetAttribute("Cash"))or 0)<cost then
            api.Status="Waiting for $"..tostring(cost).." for Power level "..(level+1)
            return
        end
        local requestEpoch=epoch
        upgradeShopBusy=true;api.InFlight=true;api.Requests+=1
        record("Request",{Id="Power",Level=level+1,Cost=cost,Phase=phase})
        local started=os.clock()
        local ok,result=pcall(function()return ShopRemote:InvokeServer("Upgrade","Power")end)
        local responded=os.clock()
        api.LastRequestMs=math.floor((responded-started)*1000+.5)
        api.InFlight=false;upgradeShopBusy=false
        nextAt=responded+.05
        if requestEpoch~=epoch then return end
        if not ok then api.Stop("Shop error: "..tostring(result));return end
        if type(result)~="table"then api.Stop("Unexpected Shop response");return end
        record("Response",{Ok=result.Ok==true,Busy=result.Busy==true,
            Level=result.Level,Msg=tostring(result.Msg or""),Ms=api.LastRequestMs})
        if result.Ok==true then
            pending={Level=math.max(level+1,tonumber(result.Level)or 0),
                At=responded,Deadline=responded+3}
            api.Status="Purchase accepted; checking Power level"
        elseif result.Busy==true then
            api.BusyResponses+=1
            nextAt=responded+math.max(.3,tonumber(result.Wait)or 0)
            api.Status="Shop busy; waiting"
        elseif result.Msg=="Not enough cash"then
            nextAt=responded+math.max(.3,tonumber(result.Wait)or 0)
            api.Status="Waiting for cash"
        else api.Stop("Power rejected: "..tostring(result.Msg or"Unknown"))end
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(tick)
            if not ok then api.Stop("Power loop error: "..tostring(err))end
            task.wait(api.Enabled and .04 or .15)
        end
    end)
    return api
end
local CrackPowerUpgrades=createLiveCrackPowerUpgrades()

-- Native client Rusty Chisel attack cooldown tuning.
-- No boss RemoteEvents are sent here: the game's original held-fire pipeline
-- handles aim, combo steps, and server-directed hit packets. Server validation
-- may reject any attacks that exceed its own allowed rate.
local function createFastChiselController()
    local P=game:GetService("Players").LocalPlayer
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local S=require(P.PlayerScripts.MTGClient.State)
    local Gear=require(MTG.Config.Gear)
    local Weapon=Gear.Weapon
    local style=Weapon and Weapon.Styles and Weapon.Styles.Chisel
    local original=style and tonumber(style.Cooldown)
    local api={Running=true,Enabled=true,Multiplier=.60,Status="Ready — waiting for Rusty Chisel boss phase",
        BaseCooldown=original or 0,TargetCooldown=0,Applied=false,
        Failures=0,Style="Chisel",ServerRateUnverified=true}
    local function restore()
        if api.Applied and style and original then
            local ok,err=pcall(function()style.Cooldown=original end)
            if not ok then
                api.Failures+=1;api.Status="Cannot restore native Chisel timing: "..tostring(err)
                return
            end
        end
        api.Applied=false;api.TargetCooldown=0
    end
    function api.SetEnabled(value)
        api.Enabled=value==true
        if not api.Enabled then
            restore()
            api.Status="Disabled — original Rusty Chisel timing restored"
        end
    end
    function api.SetMultiplier(value)
        local n=tonumber(value)
        if n and n==n then api.Multiplier=math.clamp(n,.4,1)end
    end
    function api.Tick()
        if not api.Running or not api.Enabled then return end
        if not style or not original or original<=0 then
            api.Status="Native Rusty Chisel cooldown unavailable";return
        end
        local phase=S.run("Phase")
        local crusher=P:GetAttribute("BestCracker")or"Chisel"
        if S.role()~="Game"or phase~="Mother"or crusher~="Chisel" then
            if api.Applied then restore()end
            api.Status=crusher~="Chisel"and"Waiting for Rusty Chisel style"
                or"Waiting for Mother boss phase"
            return
        end
        local newCooldown=original*api.Multiplier
        if not api.Applied or math.abs((tonumber(style.Cooldown)or 0)-newCooldown)>1e-4 then
            local ok,err=pcall(function()style.Cooldown=newCooldown end)
            if not ok then
                api.Failures+=1;api.Status="Native cooldown is read-only: "..tostring(err)
                return
            end
            api.Applied=true;api.TargetCooldown=newCooldown
        end
        api.Status=string.format("Native Chisel %.3fs -> %.3fs (%.0f%% cooldown). Server rate unverified",
            original,newCooldown,api.Multiplier*100)
    end
    function api.Unload()
        if not api.Running then return end
        api.Running=false;api.Enabled=false;restore()
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(api.Tick)
            if not ok then
                api.Failures+=1;api.Status="Chisel timing error: "..tostring(err)
            end
            task.wait(api.Enabled and .1 or .5)
        end
    end)
    return api
end
local FastChisel=createFastChiselController()


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
-- Observes the native game-defined WalkSpeed without writing to it.
-- No fixed maximum, speed multiplier, or forced reset is applied by BeyyHub.
-- This does not remove speed restrictions enforced by the Roblox game server.
local function createGameWalkSpeedController()
    local P=game:GetService("Players").LocalPlayer
    local MTG=game:GetService("ReplicatedStorage"):WaitForChild("MTG")
    local api={Running=true,Enabled=true,Status="Monitoring game movement (no hub cap)",Base=0,Applied=0}
    function api.SetEnabled(value)
        api.Enabled=value==true
        if not api.Enabled then api.Status="Monitoring disabled (no WalkSpeed override)"end
    end
    function api.Unload()
        api.Running=false
    end
    task.spawn(function()
        while api.Running do
            local ok,err=pcall(function()
                local character=P.Character
                local hum=character and character:FindFirstChildOfClass("Humanoid")
                local inGame=MTG:GetAttribute("Role")=="Game"
                if not api.Enabled then
                    api.Status="Monitoring disabled (no WalkSpeed override)"
                elseif not inGame then
                    api.Status="Waiting for game (no WalkSpeed override)"
                elseif not hum or hum.Health<=0 then
                    api.Status="Waiting for living character (no WalkSpeed override)"
                else
                    local current=hum.WalkSpeed
                    api.Base=current
                    api.Applied=current
                    api.Status=string.format("Native WalkSpeed: %.1f (no hub speed cap)",current)
                end
            end)
            if not ok then api.Status="WalkSpeed monitor error: "..tostring(err)end
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
    local api={Running=true,Enabled=false,EscapeFarm=false,BossAssist=true,RapidBoss=false,RapidBossInterval=0.05,RapidBossPulses=0,Stage="Paused",Status="Paused",Hover=6.5,Laps=0,Hits=0,WeakHits=0,
        BossToolId=nil,BossToolReady=false,BossEquipAttempts=0,
        BossToolStatus="Waiting for Rusty Chisel boss phase",
        SafeMovement=true,WinFarmFly=true,SafeMoveCommands=0,SafeMoveDistance=0,
        SafeMovementStatus="Experimental fly + noclip (16 studs/s)",
        FlySpeed=16,FlySpeedLimit=29,FlyActive=false,FlyActualSpeed=0,
        FlyNoclipParts=0,FlightErrors=0,ServerMovePauses=0,
        OrbitFlightMode="Approach",OrbitRadius=0,OrbitRadialError=0,
        OrbitHeightError=0,OrbitAngleDegrees=0,OrbitLapSeconds=0}
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
    function api.SetSafeMovement(value)api.SafeMovement=value~=false end
    function api.SetWinFarmFly(value)
        local nextValue=value~=false
        if api.WinFarmFly~=nextValue and not api.Enabled then options.Release()end
        api.WinFarmFly=nextValue
    end
    function api.SetFlySpeed(value)
        value=tonumber(value)
        if value and value==value then
            api.FlySpeed=math.clamp(value,4,api.FlySpeedLimit)
        end
    end
    function api.SetRapidBossInterval(value)
        value=tonumber(value)
        if value and value==value then api.RapidBossInterval=math.clamp(value,.05,.25)end
    end
    local managedRun;local managed=false;local previousPhase
    function api.Start()
        if not api.Running then return end
        local context=options.Context()
        if api.SafeMovement and context.CampBusy then
            api.Status="Safe Endless cannot start during an active camp trip; finish the trip first"
            return
        end
        if api.SafeMovement and options.SetNoTeleport then options.SetNoTeleport(true)end
        api.Enabled=true
        api.Status="Auto Endless: experimental fly + noclip at "..tostring(api.FlySpeed).." studs/s"
    end
    function api.Stop()
        api.Enabled=false;api.Stage="Paused";api.Status="Paused"
        options.Release()
        if managed then options.Finish()end
        if options.SetNoTeleport then options.SetNoTeleport(false)end
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
        -- Boss uses Rusty Chisel (native starter ID likely Hand), not the
        -- GEO-MAG mining tool. Ownership of GEO-MAG is not a boss gate.
        local bossOnly=not api.Enabled and (api.BossAssist or api.EscapeFarm) and c.Role=="Game"
            and c.Phase=="Mother" and c.HP>0 and not c.Ended and c.Alive
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
        elseif not c.Owned and c.Phase~="Mother" then
            stage,status="Waiting","GEO-MAG 3000 ownership required for mining"
        else
            if not managed or managedRun~=c.Run or(c.Phase=="Mining"and previousPhase~="Mining")then
                options.Manage();managed=true;managedRun=c.Run
            end
            -- Keep Cracking & Selling can be enabled after a prior one-shot
            -- sale or during an Endless depth. Re-arm it in active Mining,
            -- not during a boss or while another camp visit owns movement.
            if c.Phase=="Mining"and not c.CampBusy
                and (not api.SafeMovement or CrackSell.FlyTravel)then options.SyncCrackSell(c)end
            if c.CampBusy then stage,status="Camp","Camp cycle owns movement"
            elseif c.Phase=="Mining"then stage,status="Mining",api.SafeMovement and "Flying the existing mound orbit (camp teleport disabled)" or "Hovering around the mound"
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
            -- The prior unconditional .2s wait slowed every mining
            -- handoff, even when no direct request was in flight.
            -- Keep the full grace period only for a real pending request.
            local pending=options.PendingDirectPickup and options.PendingDirectPickup()
            readyAt=options.Now()+(pending and .2 or .02)
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
    local Gear=require(MTG.Config.Gear)
    local Bench=require(C.Bench)
    local UIKit=require(C.UIKit)
    local Mastery=require(C.Mastery)
    local MasteryHUD=require(C.MasteryHUD)
    local held;local api
    held=createNativeHeldFire({Now=os.clock,SetUse=function(value,source)Tools.setUse(value,source)end,
        PendingDirectPickup=function()return Pickup.HasPendingPickup()end,
        Progress=function()return api and(api.NativeFireEvents+api.Hits)or 0 end,
        Suppress=function(value)
            if value then Pickup.NativeHeldOwner=held
            elseif Pickup.NativeHeldOwner==held then Pickup.NativeHeldOwner=nil end
        end})
    local target,focus,ownedCharacter,ownedHumanoid,autoRotate,cameraOutward,movementStage
    local smoothedCameraRotation
    local collision={};local savedCamera;local previous
    -- Flight is driven by a physics constraint, never by direct position writes.
    -- The existing circular orbit target and MotherSpot targeting are unchanged.
    local flightRoot,flightAttachment,flightConstraint
    local flightPreviousPosition,flightPreviousAt,flightPauseUntil=nil,0,0
    local orbitEngaged=false
    local orbitLastAngle=nil
    local orbitProgress=0
    local orbitLapAt=0
    local winFlightObserved=nil
    local winFlightProgress=0
    local function clearFlight()
        if flightConstraint then
            pcall(function()flightConstraint.VectorVelocity=Vector3.zero end)
            flightConstraint:Destroy()
            flightConstraint=nil
        end
        if flightAttachment then
            flightAttachment:Destroy()
            flightAttachment=nil
        end
        flightRoot=nil
        flightPreviousPosition=nil;flightPreviousAt=0;flightPauseUntil=0
        orbitEngaged=false;orbitLastAngle=nil;orbitProgress=0;orbitLapAt=0
        winFlightObserved=nil;winFlightProgress=0
        if api then
            api.FlyActive=false;api.FlyActualSpeed=0
            api.OrbitFlightMode="Approach"
        end
    end
    local function ensureFlight(root)
        if flightRoot==root and flightConstraint and flightConstraint.Parent==root then return flightConstraint end
        clearFlight()
        flightRoot=root
        flightAttachment=Instance.new("Attachment")
        flightAttachment.Name="BeyyHubEndlessFlightAttachment"
        flightAttachment.Parent=root
        flightConstraint=Instance.new("LinearVelocity")
        flightConstraint.Name="BeyyHubEndlessFlight"
        flightConstraint.Attachment0=flightAttachment
        flightConstraint.RelativeTo=Enum.ActuatorRelativeTo.World
        flightConstraint.ForceLimitsEnabled=false
        flightConstraint.VectorVelocity=Vector3.zero
        flightConstraint.Parent=root
        api.FlyActive=true
        return flightConstraint
    end
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
    -- Auto Endless remains 10x. Hard Win Farm sweeps the same proven
    -- contour faster only while real pickup feedback stays productive.
    -- Standard Win Farm speed only: faster complete base orbit, then
    -- accelerate top-down if native GEO-MAG confirms useful pickups.
    -- Auto Endless retains its original independent 10x rotation.
    local winOuterInitialSpeed=orbitSpeedMultiplier*1.7
    local winMaximumSpeed=orbitSpeedMultiplier*2.2
    local winTransitionSpeedFloor=20
    local winRapidBoostMinimumItems=500
    local winRapidBoostMinimumShots=8
    local winRapidBoostStep=2
    -- Move the single base orbit slightly outward and lower, aiming
    -- at the lowest outer lip instead of another center sweep.
    local winBottomEdgeOutwardStuds=2.25
    local winBottomEdgeHoverDropStuds=2
    local winBottomEdgeAimInsetStuds=5
    local winBottomEdgeAimDropStuds=1.75
    -- Two-stage Auto Win Farm: one full base lap, then continuous
    -- straight-down orbital GEO-MAG coverage within native range 26.
    local winSecondRingRise=2
    local winCoreSpeed=orbitSpeedMultiplier*.95
    local winCoreMaximumSpeed=orbitSpeedMultiplier*1.25
    -- Slightly wider continuous top-down orbit improves outer lip reach.
    local topOrbitRadiusRatio=.58
    local topOrbitRadiusMinimum=14
    local topOrbitRadiusMaximum=22
    local topOrbitRiseStuds=2
    local winSweep={Run=nil,Mode="Outer",Speed=orbitSpeedMultiplier,RadiusScale=1,
        WindowAt=0,WindowItems=0,WindowShots=0,LastAcceptedAt=0,
        LastSwitchAt=0,Rate=0,Accepted=0,Shots=0,Active=false,InnerPasses=0,
        HeightRing=1,CompletedLaps=0,RingLaps={0,0,0},RingItems={0,0,0},
        CoreRadius=0,CoreRise=0,CorePasses=0,OuterSpeed=orbitSpeedMultiplier,
        CoreSpeedBoosts=0,PlanBuildWaitMs=0,PlanBuildAttempts=0,PlanRequestedAt=0,
        -- The orbit angle only advances once GEO-MAG is held/ready.
        FireReady=false,ReadySince=0,ReadyShotBase=0,FirstFireWaitMs=nil,
        PausedBeforeReady=0,PassStartAt=0,PassStartItems=0,PassStartShots=0,
        EarlyCoreSkips=0,EarlyBaseSkips=0,PassStats={},
        StartedAt=0,FirstToolFireAt=nil,NextStartupProbeAt=0,StartupSamples={},
        TotalActiveSeconds=0,PassActiveSeconds=0,
        TopFallback=false,TopDownTrials=0,TopDownSuccesses=0,
        TopDownFallbacks=0,TopDownItems=0,TopDownAttemptLog={}}
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
    local function isTopDownPass()
        return api.TopDownSecondPass and api.EscapeFarm and not api.Enabled
            and winSweep.HeightRing==2
    end
    local function winPassGeometry()
        if isTopDownPass()then
            local b=plan.Bands[1]
            local radius=math.clamp((b.Radius+1.5)*topOrbitRadiusRatio,
                topOrbitRadiusMinimum,topOrbitRadiusMaximum)
            -- Low enough for the 26-stud GEO-MAG to reach bottom columns
            -- even while the camera and tool aim straight down.
            local rise=math.min(topOrbitRiseStuds,
                math.max(0,(plan.Top or b.Y)-b.Y-api.Hover-6))
            return radius,rise
        end
        if winSweep.HeightRing==3 then
            local radius,rise=winCoreGeometry()
            winSweep.CoreRadius=radius;winSweep.CoreRise=rise
            return radius,rise
        end
        local b=plan.Bands[1]
        local radius=b.Radius*winSweep.RadiusScale+1.5
        if api.TopDownSecondPass and api.EscapeFarm and not api.Enabled
            and winSweep.HeightRing==1 then
            -- Work along the lower outside rim; never hover below 2 studs.
            local drop=math.min(winBottomEdgeHoverDropStuds,
                math.max(0,api.Hover-2))
            return radius+winBottomEdgeOutwardStuds,-drop
        end
        return radius,(winSweep.HeightRing-1)*winSecondRingRise
    end
    local function preserveWinSweep(reason)
        if not winSweep.Run then return end
        local items=table.clone(winSweep.RingItems)
        if winSweep.CompletedLaps==0 and (items[1]or 0)+(items[2]or 0)+(items[3]or 0)==0 then return end
        local passStats=table.clone(winSweep.PassStats)
        -- Mother can spawn before the core completes a full lap. Preserve
        -- its real server-confirmed pickups and elapsed time too, instead
        -- of exporting the previous run as "LastCompletedWinSweep".
        if winSweep.PassStartAt>0 then
            local ring=winSweep.HeightRing
            passStats[#passStats+1]={
                AtMs=DateTime.now().UnixTimestampMillis,
                Pass=ring,Partial=true,FullLap=false,
                LapFraction=math.clamp(angle/(math.pi*2),0,1),
                Items=math.max(0,(winSweep.RingItems[ring]or 0)-(winSweep.PassStartItems or 0)),
                NativeShots=math.max(0,api.NativeFireEvents-(winSweep.PassStartShots or 0)),
                DurationSeconds=math.max(0,os.clock()-winSweep.PassStartAt),
                ActiveSeconds=winSweep.PassActiveSeconds,
                SpeedMultiplier=winSweep.Speed
            }
        end
        api.LastWinSweep={
            Run=winSweep.Run,Reason=reason,CapturedAtMs=DateTime.now().UnixTimestampMillis,
            CompletedLaps=winSweep.CompletedLaps,RingLaps=table.clone(winSweep.RingLaps),
            RingItems=items,CoreConfirmedItems=items[3]or 0,
            OuterBaseConfirmedItems=items[1]or 0,OuterRaisedConfirmedItems=items[2]or 0,
            CorePasses=winSweep.CorePasses,CoreRadiusStuds=winSweep.CoreRadius,
            CoreRiseStuds=winSweep.CoreRise,LastPass=api.WinSweepCoveragePass,
            EarlyCoreSkips=winSweep.EarlyCoreSkips,
            EarlyBaseSkips=winSweep.EarlyBaseSkips,
            TopDownEnabled=api.TopDownSecondPass,
            TopDownTrials=winSweep.TopDownTrials,
            TopDownSuccesses=winSweep.TopDownSuccesses,
            TopDownFallbacks=winSweep.TopDownFallbacks,
            TopDownItems=winSweep.TopDownItems,
            TopDownAttempts=table.clone(winSweep.TopDownAttemptLog),
            FirstFireWaitMs=winSweep.FirstFireWaitMs,
            CoreSpeedBoosts=winSweep.CoreSpeedBoosts,PlanBuildWaitMs=winSweep.PlanBuildWaitMs,
            PlanBuildAttempts=winSweep.PlanBuildAttempts,
            PassStats=passStats,TotalActiveSeconds=winSweep.TotalActiveSeconds,
            FirstPickupClock=winSweep.FirstPickupAt,
            FirstFireClock=api.WinSweepFirstFireClock,
            FirstToolFireDelayMs=winSweep.FirstToolFireAt and
                math.floor((winSweep.FirstToolFireAt-winSweep.StartedAt)*1000+.5)or nil,
            StartupSamples=table.clone(winSweep.StartupSamples),
            FinalBagCount=P:GetAttribute("BagCount"),NativeItemsTotal=api.NativeItems,
            TotalItemsCounted=(items[1]or 0)+(items[2]or 0)+(items[3]or 0)
        }
    end
    local function resetWinSweep(run)
        if winSweep.Run and winSweep.Run~=tostring(run)
            and not winSweep.SnapshotTaken then
            preserveWinSweep("New mining run")
        end
        local now=os.clock()
        winSweep.Run=tostring(run);winSweep.Mode="Outer";winSweep.Speed=winOuterInitialSpeed
        winSweep.StartedAt=now;winSweep.FirstToolFireAt=nil
        winSweep.NextStartupProbeAt=now;winSweep.StartupSamples={}
        winSweep.HeightRing=1;winSweep.CompletedLaps=0
        winSweep.RingLaps={0,0,0};winSweep.RingItems={0,0,0}
        winSweep.CoreRadius=0;winSweep.CoreRise=0;winSweep.CorePasses=0
        winSweep.OuterSpeed=winOuterInitialSpeed
        winSweep.CoreSpeedBoosts=0;winSweep.PlanBuildWaitMs=0
        winSweep.PlanBuildAttempts=0;winSweep.PlanRequestedAt=0
        winSweep.FireReady=false;winSweep.ReadySince=0;winSweep.ReadyShotBase=0
        winSweep.FirstFireWaitMs=nil;winSweep.PausedBeforeReady=0
        winSweep.PassStartAt=0;winSweep.PassStartItems=0
        winSweep.PassStartShots=0;winSweep.EarlyCoreSkips=0
        winSweep.EarlyBaseSkips=0;winSweep.PassStats={}
        winSweep.TotalActiveSeconds=0;winSweep.PassActiveSeconds=0
        winSweep.TopFallback=false;winSweep.TopDownTrials=0
        winSweep.TopDownSuccesses=0;winSweep.TopDownFallbacks=0
        winSweep.TopDownItems=0;winSweep.TopDownAttemptLog={}
        -- Keep the first base contour unless real tool feedback supports
        -- the already-protected low-yield shortcut.
        -- including after replay or when entering the farm mid-run.
        angle=0;winFlightObserved=nil;winFlightProgress=0
        winSweep.RadiusScale=1;winSweep.WindowAt=now
        winSweep.WindowItems=api.NativeItems or 0
        winSweep.WindowShots=api.NativeFireEvents or 0
        winSweep.LastAcceptedAt=now;winSweep.LastSwitchAt=now
        winSweep.Rate=0;winSweep.Accepted=0;winSweep.Shots=0
        winSweep.Active=false;winSweep.InnerPasses=0
        winSweep.SnapshotTaken=false;winSweep.FirstPickupAt=nil
        api.WinSweepFirstFireClock=0;api.WinSweepFirstPickupClock=0
        api.WinSweepMode=winSweep.Mode;api.WinSweepSpeed=winSweep.Speed
        api.WinSweepItemsPerSecond=0;api.WinSweepRadiusScale=1
        api.WinSweepHeightRing=1;api.WinSweepHeightOffset=0
        api.WinSweepCoveragePass="Base outer";api.WinSweepCoreRadius=0
        api.WinSweepCoreItems=0;api.WinSweepCompletedLaps=0
        api.WinSweepEarlyCoreSkips=0;api.WinSweepEarlyBaseSkips=0
        api.WinSweepTopDownFallbacks=0;api.WinSweepTopDownSuccesses=0
        api.WinSweepTopDownItems=0
        api.WinSweepFirstFireWaitMs=0
        api.WinSweepPlanBuildWaitMs=0;api.WinSweepCoreSpeedBoosts=0
        api.WinSweepFireReady=false
    end
    local nextEquip=0
    local bossEquipIndex=1
    local bossEquipAttemptsForId=0
    -- Native FIGHT slot, not the Hand mining tool. BestCracker selects its style.
    local bossWeaponId=Gear.Weapon and Gear.Weapon.Id
    local bossToolCandidates={}
    if type(bossWeaponId)=="string"and bossWeaponId~=""then bossToolCandidates[1]=bossWeaponId end
    local bossToolSet={}
    for _,name in ipairs(bossToolCandidates)do bossToolSet[name]=true end
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
        clearFlight()
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
    end,SetNoTeleport=function(value)CrackSell.NoTeleport=value==true end,Manage=function()
        if not CrackPowerUpgrades.Enabled then CrackPowerUpgrades.Start()end
        if api.SafeMovement and CrackSell.Enabled and not CrackSell.FlyTravel then
            -- Auto Endless must not initiate direct CFrame camp trips.
            -- Only stop an idle controller; an already active trip is allowed
            -- to finish under its own safety checks.
            if not CrackSell.Busy then CrackSell.Stop("Safe Endless: camp teleports disabled",true)end
        end
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
        local equipped=HUD.equipped()
        local bossPhase=c.Phase=="Mother"
        if bossPhase then
            if #bossToolCandidates==0 then
                self.BossToolReady=false;self.BossToolId=nil
                self.BossToolStatus="Native fight-weapon ID unavailable"
                release();self.Status=self.BossToolStatus
                return
            end
            if not bossToolSet[equipped]then
                -- Never force GEO-MAG while Mother is active.
                self.BossToolReady=false;self.BossToolId=nil
                release()
                if now>=nextEquip then
                    local candidate=bossToolCandidates[bossEquipIndex]
                    nextEquip=now+.35
                    local ok,err=pcall(HUD.selectTool,candidate)
                    self.BossEquipAttempts+=1
                    self.BossToolStatus="Trying Rusty Chisel ("..candidate..")"
                    record("RustyChiselEquipAttempt",{
                        Candidate=candidate,Called=ok,
                        Error=not ok and tostring(err)or nil,
                        Before=equipped,After=HUD.equipped()})
                    bossEquipAttemptsForId+=1
                    if bossEquipAttemptsForId>=2 then
                        bossEquipAttemptsForId=0
                        bossEquipIndex=bossEquipIndex%#bossToolCandidates+1
                    end
                end
                self.Status="Equipping Rusty Chisel for Mother boss"
                return
            end
            self.BossToolId=equipped
            self.BossToolReady=true
            self.BossToolStatus="Boss weapon equipped ("..equipped.."; "..tostring(P:GetAttribute("BestCracker")or"Chisel").." style)"
            bossEquipIndex=1;bossEquipAttemptsForId=0
        else
            self.BossToolReady=false;self.BossToolId=nil
            bossEquipIndex=1;bossEquipAttemptsForId=0
            if equipped~="Magnet"then
                release()
                if now>=nextEquip then
                    -- GEO-MAG remains the mining tool, never the boss tool.
                    nextEquip=now+(self.EscapeFarm and not self.Enabled and .25 or 1)
                    HUD.selectTool("Magnet")
                end
                self.Status="Equipping GEO-MAG 3000 for mining"
                return
            end
        end
        if c.Phase=="Mining"then
            if c.Depth~=planDepth or c.Run~=planRun then
                plan=nil;profileCenter=nil;pendingBand=nil
                orbitEngaged=false;orbitLastAngle=nil;orbitProgress=0;orbitLapAt=0
                planDepth=c.Depth;planRun=c.Run;band=1;nextPlan=now
                if self.EscapeFarm and not self.Enabled then
                    winSweep.PlanRequestedAt=now
                    winSweep.PlanBuildAttempts=0
                end
            end
            -- Full generated geometry pins one circular path for the whole depth.
            -- Depleted sectors cannot pull the radius/height inward or reset angle.
            if not plan and now>=nextPlan then
                plan=buildPlan()
                -- Retry a not-yet-replicated mound quickly; successful
                -- plans are still pinned for the full Mining phase.
                nextPlan=now+(self.EscapeFarm and not self.Enabled and .12 or 1)
                if self.EscapeFarm and not self.Enabled then
                    winSweep.PlanBuildAttempts+=1
                    if plan and winSweep.PlanRequestedAt>0 then
                        winSweep.PlanBuildWaitMs=math.floor(
                            (now-winSweep.PlanRequestedAt)*1000+.5)
                        api.WinSweepPlanBuildWaitMs=winSweep.PlanBuildWaitMs
                        record("EscapeFarmPlanReady",{
                            Attempts=winSweep.PlanBuildAttempts,
                            WaitMs=winSweep.PlanBuildWaitMs,
                            BaseRadius=plan.Bands[1].Radius})
                    end
                end
            end
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
    api.WinSweepHeightRing=1;api.WinSweepHeightOffset=0;api.WinSweepActiveRadius=0;api.WinSweepCompletedLaps=0
    api.WinSweepCoveragePass="Off";api.WinSweepCoreRadius=0;api.WinSweepCoreItems=0
    api.WinSweepEarlyCoreSkips=0;api.WinSweepEarlyBaseSkips=0
    api.TopDownSecondPass=true
    api.WinSweepTopDownFallbacks=0;api.WinSweepTopDownSuccesses=0
    api.WinSweepTopDownItems=0
    api.WinSweepFirstFireWaitMs=0;api.WinSweepFireReady=false
    api.WinSweepPlanBuildWaitMs=0;api.WinSweepCoreSpeedBoosts=0
    api.WinSweepFirstFireClock=0;api.WinSweepFirstPickupClock=0
    api.LastWinSweep=nil
    function api.SetTopDownSecondPass(value)
        api.TopDownSecondPass=value==true
    end
    local function tuneWinSweep(now)
        if not winSweep.Run then return end
        local elapsed=now-winSweep.WindowAt
        -- Last Hard diagnostics: 4,709 geodes in base and 7,660 raised,
        -- but a .65s window allowed only one boost per ~1.1s raised lap.
        -- Use sub-lap samples with a minimum real-shot count. Never infer
        -- acceptance from the position or tool-fire event alone.
        local sampleSeconds=.25
        if elapsed<sampleSeconds then return end
        local newItems=math.max(0,api.NativeItems-winSweep.WindowItems)
        local shots=math.max(0,api.NativeFireEvents-winSweep.WindowShots)
        winSweep.Rate=newItems/math.max(.1,elapsed)
        winSweep.Accepted+=newItems;winSweep.Shots+=shots
        winSweep.WindowAt=now;winSweep.WindowItems=api.NativeItems
        winSweep.WindowShots=api.NativeFireEvents
        -- Both orbiting stages use feedback-based speed tuning.
        if winSweep.HeightRing==3 then
            -- The center pillar produced thousands of accepted items in
            -- earlier tests. Speed up this compact pass ONLY when native
            -- firing and server-confirmed pickup prove it productive.
            -- Fall back to the proven 8x if acceptance becomes weak.
            local reason=nil
            if newItems>=110 and shots>=4
                and winSweep.Speed<winCoreMaximumSpeed then
                winSweep.Speed=math.min(winCoreMaximumSpeed,winSweep.Speed+1)
                winSweep.CoreSpeedBoosts+=1
                api.WinSweepCoreSpeedBoosts=winSweep.CoreSpeedBoosts
                reason="Server-confirmed core pickups; safely accelerating compact sweep"
            elseif newItems<=10 and shots>=4
                and winSweep.Speed>winCoreSpeed then
                winSweep.Speed=winCoreSpeed
                reason="Weak core pickup feedback; returning to proven 8x"
            end
            if reason then
                record("EscapeFarmCoreSpeedAdjusted",{
                    Reason=reason,Speed=winSweep.Speed,
                    AcceptedItemsInWindow=newItems,NativeShotsInWindow=shots,
                    AcceptedItemsPerSecond=winSweep.Rate})
            end
            api.WinSweepSpeed=winSweep.Speed
            api.WinSweepItemsPerSecond=winSweep.Rate
            return
        end
        local reason=nil
        if not isTopDownPass()and winSweep.Mode=="Inner"and now-winSweep.LastSwitchAt>=5.2 then
            winSweep.Mode="Outer";winSweep.RadiusScale=1
            winSweep.Speed=winOuterInitialSpeed;winSweep.LastSwitchAt=now
            reason="Inner coverage pass finished; returning to outermost arc"
        elseif not isTopDownPass()and newItems==0 and shots>=2
            and now-winSweep.LastAcceptedAt>=3.3 and
            now-winSweep.LastSwitchAt>=3 then
            if winSweep.Mode=="Outer"then
                winSweep.Mode="Inner";winSweep.RadiusScale=.72
                winSweep.Speed=winInnerSpeed;winSweep.InnerPasses+=1
                reason="No accepted geodes from outer arc; same-height inner coverage pass"
            else
                winSweep.Mode="Outer";winSweep.RadiusScale=1
                winSweep.Speed=winOuterInitialSpeed
                reason="No accepted geodes from inner arc; trying outer coverage again"
            end
            winSweep.LastSwitchAt=now
        elseif newItems<=25 and shots>=6 and winSweep.Mode=="Outer"
            and winSweep.Speed>winOuterInitialSpeed
            and (not isTopDownPass() or winSweep.RingLaps[2]<1)then
            -- Don't slow the almost-empty third top-down lap. That
            -- wasted precious mining time in the v1.10.54 diagnostics.
            winSweep.Speed=winOuterInitialSpeed
            reason="Weak server pickup feedback early; cautious speed"
        elseif newItems>=180 and shots>=6 and winSweep.Mode=="Outer"
            and winSweep.Speed<winMaximumSpeed then
            local rapid=newItems>=winRapidBoostMinimumItems
                and shots>=winRapidBoostMinimumShots
            winSweep.Speed=math.min(winMaximumSpeed,
                winSweep.Speed+(rapid and winRapidBoostStep or 1))
            reason=rapid
                and "Strong confirmed GEO-MAG yield; accelerating by 2x"
                or "Confirmed GEO-MAG yield; accelerating by 1x"
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
        if held.Active and tool=="Magnet" and api.Stage=="Mining"then
            api.NativeFireEvents+=1
            if winSweep.Run and api.EscapeFarm and not api.Enabled
                and api.Stage=="Mining"and not winSweep.FirstToolFireAt then
                winSweep.FirstToolFireAt=os.clock()
            end
        elseif held.Active and api.Stage=="Boss"
            and api.BossToolReady and tool==api.BossToolId then
            api.BossNativeFires=(api.BossNativeFires or 0)+1
        end
    end)
    local nativeBossHit=Tools.MotherHit.Event:Connect(function(_,_,tool,spot)
        if held.Active and api.Stage=="Boss"and api.BossToolReady then
            -- The native callback confirms a Mother hit; it may report a
            -- canonical weapon alias other than the HUD's equipped ID.
            api.Hits+=1
            if spot~=nil and spot~=0 then api.WeakHits+=1 end
            api.BossLastHitTool=tool
            api.BossLastHitSpot=spot
            if tool~=api.BossToolId then
                api.BossToolAliasHits=(api.BossToolAliasHits or 0)+1
            end
        end
    end)
    local nativeFeedback=MTG.Remotes.Pick.OnClientEvent:Connect(function(id,tool,packed)
        if held.Active and id==P.UserId and tool=="Magnet"and typeof(packed)=="buffer"then
            local count=math.floor(buffer.len(packed)/5)
            api.NativeItems+=count
            if count>0 and api.EscapeFarm and not api.Enabled and api.Stage=="Mining"then
                local now=os.clock()
                winSweep.LastAcceptedAt=now
                if not winSweep.FirstPickupAt then
                    winSweep.FirstPickupAt=now
                    api.WinSweepFirstPickupClock=now
                end
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
                Laps=api.Laps,Hits=api.Hits,WeakHits=api.WeakHits,
                SafeMovement=api.SafeMovement,WinFarmFly=api.WinFarmFly,WinFarmAngularProgress=winFlightProgress,SafeMoveCommands=api.SafeMoveCommands,
                SafeMoveDistance=api.SafeMoveDistance,SafeMovementStatus=api.SafeMovementStatus,
                FlySpeed=api.FlySpeed,FlySpeedLimit=api.FlySpeedLimit,
                FlyActive=api.FlyActive,FlyActualSpeed=api.FlyActualSpeed,
                FlyNoclipParts=api.FlyNoclipParts,FlightErrors=api.FlightErrors,
                OrbitFlightMode=api.OrbitFlightMode,
                OrbitRadius=api.OrbitRadius,OrbitRadialError=api.OrbitRadialError,
                OrbitHeightError=api.OrbitHeightError,
                OrbitAngleDegrees=api.OrbitAngleDegrees,
                OrbitLapSeconds=api.OrbitLapSeconds,
                ServerMovePauses=api.ServerMovePauses,
                SafeCampTeleportDisabled=api.SafeMovement,
                BossToolId=api.BossToolId,BossToolReady=api.BossToolReady,
                BossToolStatus=api.BossToolStatus,BossEquipAttempts=api.BossEquipAttempts,
                BossToolCandidates=bossToolCandidates,BossLastHitTool=api.BossLastHitTool,
                BossLastHitSpot=api.BossLastHitSpot,
                BossNativeFires=api.BossNativeFires or 0,
                BossToolAliasHits=api.BossToolAliasHits or 0,
                BossToolNote="Uses the native Gear.Weapon.Id FIGHT slot. BestCracker chooses Rusty Chisel or another unlocked style. MotherSpot auto critical targeting is unchanged; GEO-MAG is mining only.",
                BossWeaponNativeId=bossWeaponId,BossWeaponStyle=P:GetAttribute("BestCracker")or"Chisel",
                BossWeaponSlotAvailable=bossWeaponId and HUD.slot(bossWeaponId)~=nil or false,
                Depth=S.run("Depth"),Phase=S.run("Phase"),Profile=plan,Ring=band,
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
                    InitialOuterSpeedMultiplier=winOuterInitialSpeed,
                    MaximumOuterSpeedMultiplier=winMaximumSpeed,
                    InnerSpeedMultiplier=winInnerSpeed,
                    MinimumCoreSpeedMultiplier=winCoreSpeed,
                    MaximumCoreSpeedMultiplier=winCoreMaximumSpeed,
                    CoreFeedbackWindowSeconds=.25,OuterFeedbackWindowSeconds=.25,
                    MinimumCoreItemsToBoost=110,MinimumOuterItemsToBoost=180,
                    NativeShotsRequiredForOuterBoost=6,
                    CoreSpeedBoosts=winSweep.CoreSpeedBoosts,
                    PlanBuildWaitMs=winSweep.PlanBuildWaitMs,
                    PlanBuildAttempts=winSweep.PlanBuildAttempts,
                    SpeedMultiplier=winSweep.Speed,RadiusScale=winSweep.RadiusScale,
                    AcceptedItemsPerSecond=winSweep.Rate,AcceptedItems=winSweep.Accepted,
                    NativeShots=winSweep.Shots,InnerPasses=winSweep.InnerPasses,
                    LastAcceptedAgo=winSweep.LastAcceptedAt>0 and os.clock()-winSweep.LastAcceptedAt or nil,
                    BaseContourOnly=false,SecondRingRiseStuds=winSecondRingRise,
                    HeightRing=winSweep.HeightRing,
                    HeightOffsetStuds=api.WinSweepHeightOffset,
                    ActiveOrbitRadiusStuds=api.WinSweepActiveRadius,
                    CoveragePass=api.WinSweepCoveragePass,
                    CoreRadiusStuds=winSweep.CoreRadius,CoreRiseStuds=winSweep.CoreRise,
                    CorePasses=winSweep.CorePasses,
                    TopDownEnabled=api.TopDownSecondPass,
                    TopDownCurrentlyActive=isTopDownPass(),
                    TopDownTrials=winSweep.TopDownTrials,
                    TopDownSuccesses=winSweep.TopDownSuccesses,
                    TopDownFallbacks=winSweep.TopDownFallbacks,
                    TopDownItems=winSweep.TopDownItems,
                    TopDownAttempts=winSweep.TopDownAttemptLog,
                    TopDownContinuous=api.TopDownSecondPass,
                    TopDownRadiusRatio=topOrbitRadiusRatio,
                    TopDownMinimumRadiusStuds=topOrbitRadiusMinimum,
                    TopDownMaximumRadiusStuds=topOrbitRadiusMaximum,
                    TopDownRiseStuds=topOrbitRiseStuds,
                    BaseOuterExtraRadiusStuds=winBottomEdgeOutwardStuds,
                    BaseHoverDropStuds=winBottomEdgeHoverDropStuds,
                    BaseAimInsetStuds=winBottomEdgeAimInsetStuds,
                    BaseAimDropStuds=winBottomEdgeAimDropStuds,
                    BaseToTopSpeedFloor=winTransitionSpeedFloor,
                    RapidBoostMinimumItems=winRapidBoostMinimumItems,
                    RapidBoostMinimumNativeShots=winRapidBoostMinimumShots,
                    RapidBoostStep=winRapidBoostStep,
                    PreventLateTopDownSpeedDrop=true,
                    TopDownMaximumSeconds=0,
                    CompletedLaps=winSweep.CompletedLaps,
                    RingLaps=winSweep.RingLaps,RingItems=winSweep.RingItems,
                    CoreConfirmedItems=winSweep.RingItems[3],
                    FireReady=winSweep.FireReady,
                    FirstFireWaitMs=winSweep.FirstFireWaitMs,
                    EarlyCoreSkips=winSweep.EarlyCoreSkips,
                    EarlyBaseSkips=winSweep.EarlyBaseSkips,
                    PassStats=winSweep.PassStats,
                    TotalActiveSeconds=winSweep.TotalActiveSeconds,
                    ActiveCurrentPassSeconds=winSweep.PassActiveSeconds,
                    StartupSamples=winSweep.StartupSamples,
                    FirstToolFireDelayMs=winSweep.FirstToolFireAt and
                        math.floor((winSweep.FirstToolFireAt-winSweep.StartedAt)*1000+.5)or nil,
                    FirstBaseSkipAtLapFraction=.55,
                    FirstBaseMaximumAcceptedItems=32,
                    FirstBaseMinimumNativeShots=3,
                    RaisedSkipThresholdItems=64,RaisedSkipAtLapFraction=.72,
                    FirstRaisedSkipAtLapFraction=.58,FirstRaisedMaximumItems=48,
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
            local equipped=HUD.equipped()
            local correctTool=(mining and equipped=="Magnet")
                or(boss and api.BossToolReady and api.BossToolId~=nil
                    and equipped==api.BossToolId)
            local allowed=owner and(mining or boss)and movementStage==api.Stage
                and target~=nil and hum~=nil and hum.Health>0 and correctTool
                and not CrackSell.Busy and not Bench.isCracking()
                and not Pickup.Suspended and not UIKit.cursorFree()and P:GetAttribute("PerkPending")~=true and not Tools.Blocked and not Tools.DevPaused
            -- During the first few seconds of a standard Mining round,
            -- sample local permission gates only until the first real
            -- tool-fire callback. This identifies the source of the
            -- observed ~2.88-second delay without printing per frame.
            local now=os.clock()
            if api.EscapeFarm and not api.Enabled and winSweep.Run
                and winSweep.StartedAt>0 and not winSweep.FirstToolFireAt
                and now-winSweep.StartedAt<=6
                and now>=winSweep.NextStartupProbeAt then
                winSweep.NextStartupProbeAt=now+.20
                local sample={
                    ElapsedMs=math.floor((now-winSweep.StartedAt)*1000+.5),
                    Owner=owner==true,Allowed=allowed==true,
                    HeldActive=held.Active,Phase=S.run("Phase"),
                    Stage=api.Stage,MovementStage=movementStage,
                    MoundPlanReady=plan~=nil,
                    MoundLocked=S.run("MoundLocked",false)==true,
                    Equipped=HUD.equipped(),
                    CrackBusy=CrackSell.Busy,BenchBusy=Bench.isCracking(),
                    PickupSuspended=Pickup.Suspended==true,
                    MenuBlocking=UIKit.cursorFree()==true,
                    PerkPending=P:GetAttribute("PerkPending")==true,
                    ToolsBlocked=Tools.Blocked==true,
                    DevPaused=Tools.DevPaused==true,
                    HumanoidAlive=hum~=nil and hum.Health>0,
                    TargetReady=target~=nil
                }
                winSweep.StartupSamples[#winSweep.StartupSamples+1]=sample
                if #winSweep.StartupSamples>30 then
                    table.remove(winSweep.StartupSamples,1)
                end
            end
            held.Update(owner,allowed)
            api.NativeHeldActive=held.Active
            api.NativeFireRecoveries=held.Recoveries
            if winSweep.Run and not winSweep.SnapshotTaken
                and S.run("Phase")~="Mining" then
                preserveWinSweep("Mining phase finished: "..tostring(S.run("Phase")))
                winSweep.SnapshotTaken=true
            end
            if not api.EscapeFarm and winSweep.Run~=nil then
                if not winSweep.SnapshotTaken then
                    preserveWinSweep("Auto Win Farm stopped or escaped")
                end
                winSweep.Run=nil;winSweep.Active=false;winSweep.Mode="Outer"
                winSweep.Speed=winOuterInitialSpeed;winSweep.RadiusScale=1
                winSweep.HeightRing=1;winSweep.CompletedLaps=0
                winSweep.RingLaps={0,0,0};winSweep.RingItems={0,0,0}
                winSweep.CoreRadius=0;winSweep.CoreRise=0;winSweep.CorePasses=0
                winSweep.FireReady=false;winSweep.ReadySince=0
                api.WinSweepFireReady=false
                api.WinSweepMode="Off";api.WinSweepSpeed=orbitSpeedMultiplier
                api.WinSweepItemsPerSecond=0;api.WinSweepRadiusScale=1
                api.WinSweepHeightRing=1;api.WinSweepHeightOffset=0;api.WinSweepActiveRadius=0;api.WinSweepCompletedLaps=0
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
                    -- Preserve the speed already earned by confirmed pickup
                    -- feedback if the camera/tool is briefly interrupted.
                    winSweep.Speed=winSweep.HeightRing==3
                        and math.clamp(winSweep.Speed,winCoreSpeed,winCoreMaximumSpeed)
                        or math.clamp(winSweep.Speed,winOuterInitialSpeed,winMaximumSpeed)
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
                        api.WinSweepFirstFireClock=now
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
                if (api.Enabled and api.SafeMovement)
                    or (standardFarm and api.WinFarmFly)then
                    -- Measure real character angular progress for fly-based
                    -- Endless and Win Farm. Never credit stationary orbit laps.
                    local ring=plan.Bands[band]
                    local dx=root.Position.X-plan.Origin.X
                    local dz=root.Position.Z-plan.Origin.Z
                    local radius=ring.Radius+1.5
                    if dx*dx+dz*dz>.25 then
                        local observed=math.atan2(dz,dx)%(math.pi*2)
                        local prior=standardFarm and winFlightObserved
                            or orbitLastAngle
                        if orbitEngaged and prior~=nil then
                            local deltaAngle=(observed-prior+math.pi)%(math.pi*2)-math.pi
                            local plausible=(api.FlySpeed/math.max(radius,1))
                                *math.min(math.max(dt,.001),.1)*3+.04
                            if deltaAngle>0 and deltaAngle<=plausible then
                                if standardFarm then
                                    if held.Active and winSweep.FireReady then
                                        winFlightProgress+=deltaAngle
                                    end
                                else
                                    orbitProgress+=deltaAngle
                                    if orbitProgress>=math.pi*2 then
                                        orbitProgress-=math.pi*2
                                        api.Laps+=1
                                        api.OrbitLapSeconds=orbitLapAt>0
                                            and os.clock()-orbitLapAt or 0
                                        orbitLapAt=os.clock()
                                        record("SmoothFlightOrbitLap",{
                                            Laps=api.Laps,Radius=radius,
                                            LapSeconds=api.OrbitLapSeconds,
                                            SpeedLimit=api.FlySpeed})
                                    end
                                end
                            end
                        end
                        angle=observed
                        if standardFarm then winFlightObserved=observed
                        else orbitLastAngle=observed end
                        api.OrbitAngleDegrees=math.deg(observed)
                    end
                end
                if standardFarm and held.Active and winSweep.FireReady then
                    -- Flight tracks ACTUAL angular coverage; legacy orbit
                    -- still uses timed rotation when fly mode is disabled.
                    local speed=winSweep.Speed
                    local activeDt=math.min(dt,.1)
                    winSweep.TotalActiveSeconds+=activeDt
                    winSweep.PassActiveSeconds+=activeDt
                    local topDown=isTopDownPass()
                    -- A continuous, moving orbit, including top-down.
                    if not api.WinFarmFly then
                        angle+=activeDt*(math.pi*2)/(14/speed)
                    end
                    local lapAngle=api.WinFarmFly and winFlightProgress or angle
                    local now=os.clock()
                    local oldRing=winSweep.HeightRing
                    local passItems=math.max(0,(winSweep.RingItems[oldRing]or 0)
                        -(winSweep.PassStartItems or 0))
                    local passShots=math.max(0,api.NativeFireEvents
                        -(winSweep.PassStartShots or 0))
                    local passSeconds=winSweep.PassStartAt>0
                        and now-winSweep.PassStartAt or 0
                    local fullLap=lapAngle>=math.pi*2
                    -- No top-down timeout, collection threshold or fallback:
                    -- the second orbit persists until Mining ends.
                    -- For the FIRST base lap only, a mostly empty arc
                    -- need not waste an entire orbit. Require real native
                    -- tool shots and at most 32 server-confirmed items.
                    -- Later base laps keep full coverage to collect late
                    -- exterior geodes. Productive first laps also stay full.
                    local earlyBase=oldRing==1 and not fullLap
                        and not api.TopDownSecondPass
                        and winSweep.CorePasses==0
                        and winSweep.RingLaps[1]==0
                        and lapAngle>=math.pi*2*.55
                        and passSeconds>=.50 and passShots>=3
                        and passItems<=32
                    -- The FIRST raised pass may also shortcut sooner when
                    -- almost empty. Once the core was visited, preserve the
                    -- proven .72 coverage requirement for future raised laps.
                    local firstRaised=oldRing==2 and winSweep.CorePasses==0
                    local raisedFraction=firstRaised and .58 or .72
                    local raisedMaximum=firstRaised and 48 or 64
                    local earlyCore=oldRing==2 and not topDown and not fullLap
                        and lapAngle>=math.pi*2*raisedFraction
                        and passSeconds>=.45 and passShots>=4
                        and passItems<=raisedMaximum
                    if fullLap or earlyBase or earlyCore then
                        local completedFraction=fullLap and 1
                            or math.min(1,lapAngle/(math.pi*2))
                        if fullLap then
                            if api.WinFarmFly then winFlightProgress=math.max(0,winFlightProgress-math.pi*2)
                            else angle%=math.pi*2 end
                            api.Laps+=1
                            winSweep.CompletedLaps+=1
                            winSweep.RingLaps[oldRing]+=1
                            if topDown then
                                winSweep.TopDownSuccesses+=1
                                api.WinSweepTopDownSuccesses=winSweep.TopDownSuccesses
                                winSweep.TopDownItems+=passItems
                                api.WinSweepTopDownItems=winSweep.TopDownItems
                                record("EscapeFarmTopDownOrbitLap",{
                                    Lap=winSweep.TopDownSuccesses,Items=passItems,
                                    NativeShots=passShots,
                                    ActiveSeconds=winSweep.PassActiveSeconds})
                            end
                        else
                            if api.WinFarmFly then winFlightProgress=0
                            else angle=0 end
                            if earlyBase then
                                winSweep.EarlyBaseSkips+=1
                                api.WinSweepEarlyBaseSkips=winSweep.EarlyBaseSkips
                            else
                                winSweep.EarlyCoreSkips+=1
                                api.WinSweepEarlyCoreSkips=winSweep.EarlyCoreSkips
                            end
                        end
                        local stat={
                            AtMs=DateTime.now().UnixTimestampMillis,
                            Pass=oldRing,FullLap=fullLap,
                            EarlyBaseSwitch=earlyBase,EarlyCoreSwitch=earlyCore,
                            TopDownSecondPass=topDown,
                            LapFraction=completedFraction,
                            Items=passItems,NativeShots=passShots,
                            DurationSeconds=passSeconds,
                            ActiveSeconds=winSweep.PassActiveSeconds,
                            SpeedMultiplier=winSweep.Speed
                        }
                        winSweep.PassStats[#winSweep.PassStats+1]=stat
                        if #winSweep.PassStats>24 then
                            table.remove(winSweep.PassStats,1)
                        end
                        -- One base lap followed by ongoing top-down laps.
                        -- The previous three-stage route remains available
                        -- only when the top-down toggle is turned off.
                        local nextRing=api.TopDownSecondPass
                            and (oldRing==1 and 2 or 2)
                            or (oldRing==1 and 2 or(oldRing==2 and 3 or 1))
                        if api.TopDownSecondPass and oldRing==1 and nextRing==2
                            and passItems>=400 and passShots>=8 then
                            -- Same-Heartbeat transition; preserve fast orbit
                            -- speed on a productive base lap, no extra wait.
                            winSweep.Speed=math.max(winSweep.Speed,
                                winTransitionSpeedFloor)
                        end
                        if nextRing==3 then
                            winSweep.OuterSpeed=winSweep.Speed
                            winSweep.Speed=winCoreSpeed
                            winSweep.CorePasses+=1
                        elseif oldRing==3 then
                            winSweep.Speed=math.max(winOuterInitialSpeed,
                                winSweep.OuterSpeed or winOuterInitialSpeed)
                        end
                        winSweep.HeightRing=nextRing
                        if nextRing==2 and oldRing~=2 then
                            winSweep.TopFallback=false
                            if api.TopDownSecondPass then
                                winSweep.TopDownTrials+=1
                            end
                        end
                        local nextRadius,nextRise=winPassGeometry()
                        api.WinSweepHeightRing=nextRing
                        api.WinSweepHeightOffset=nextRise
                        api.WinSweepCoveragePass=nextRing==1 and "Base outer"
                            or(nextRing==2 and (isTopDownPass() and "Continuous top-down orbit" or "Raised outer")
                                or "Boss-center core")
                        api.WinSweepCoreRadius=winSweep.CoreRadius
                        api.WinSweepCoreItems=winSweep.RingItems[3]
                        api.WinSweepSpeed=winSweep.Speed
                        api.WinSweepCompletedLaps=winSweep.CompletedLaps
                        winSweep.PassStartAt=now
                        winSweep.PassActiveSeconds=0
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
                            EarlyBaseSwitch=earlyBase,
                            TopDownSecondPass=topDown,
                            EarlyCoreSwitch=earlyCore,PassItems=passItems,
                            NativeShotsInPass=passShots,PassDurationSeconds=passSeconds,
                            RingLaps=table.clone(winSweep.RingLaps),
                            AcceptedItemsPerRing=table.clone(winSweep.RingItems)})
                    end
                end
                local b=plan.Bands[band]
                local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
                local radius,heightRise
                if standardFarm then
                    radius,heightRise=winPassGeometry()
                    api.WinSweepHeightOffset=heightRise
                    api.WinSweepActiveRadius=radius
                else
                    radius=b.Radius+1.5;heightRise=0
                end
                target=Vector3.new(plan.Origin.X,b.Y+api.Hover+heightRise,plan.Origin.Z)+radial*radius
                if standardFarm and isTopDownPass()then
                    -- Camera points straight down at the moving orbit.
                    focus=target-Vector3.new(0,12,0)
                elseif standardFarm and api.TopDownSecondPass
                    and winSweep.HeightRing==1 then
                    -- Aim near the bottom outside lip, not into the center,
                    -- for this one complete low-and-wide base revolution.
                    local floorY=math.max(plan.Bottom or b.Y-3,
                        b.Y-winBottomEdgeAimDropStuds)
                    focus=Vector3.new(plan.Origin.X,floorY,plan.Origin.Z)
                        +radial*math.max(0,radius-winBottomEdgeAimInsetStuds)
                else
                    focus=Vector3.new(plan.Origin.X,b.Y+heightRise,plan.Origin.Z)+radial*math.max(0,radius-7)
                end
                cameraOutward=radial
            end
            local winFarmFlight=api.EscapeFarm and not api.Enabled
                and api.WinFarmFly and (api.Stage=="Mining"or api.Stage=="Boss")
            local flightMode=(api.Enabled and api.SafeMovement)or winFarmFlight
            if flightMode then
                -- Noclip is limited to owned farming flight; preserve
                -- original part collision settings for release/unload.
                local noclipCount=0
                for _,part in ipairs(char:GetDescendants())do
                    if part:IsA("BasePart")then
                        if collision[part]==nil then collision[part]=part.CanCollide end
                        if part.CanCollide then part.CanCollide=false end
                        noclipCount+=1
                    end
                end
                api.FlyNoclipParts=noclipCount
                hum.AutoRotate=true
            else
                for _,part in ipairs(char:GetChildren())do
                    if part:IsA("BasePart")then
                        if collision[part]==nil then collision[part]=part.CanCollide end
                        part.CanCollide=false
                    end
                end
                hum.AutoRotate=false
            end
            local facing=focus
            if api.Stage=="Mining"then
                if api.EscapeFarm and not api.Enabled and isTopDownPass()then
                    facing=Vector3.new(plan.Origin.X,target.Y,plan.Origin.Z)
                else
                    facing=plan and Vector3.new(plan.Origin.X,target.Y,plan.Origin.Z)
                        or(target+Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z))
                end
            end
            if flightMode then
                local now=os.clock()
                local origin=root.Position
                local offset=target-origin
                local distance=offset.Magnitude
                api.SafeMoveDistance=distance
                local flight=ensureFlight(root)
                -- Pause command input after unexpected external relocation
                -- instead of immediately fighting the game's own movement.
                if flightPreviousPosition and flightPreviousAt>0 then
                    local elapsed=now-flightPreviousAt
                    local moved=(origin-flightPreviousPosition).Magnitude
                    if elapsed>0 and elapsed<.25 and moved>6
                        and moved/math.max(elapsed,.016)>20
                        and now>=flightPauseUntil then
                        flightPauseUntil=now+.75
                        api.ServerMovePauses+=1
                        record("EndlessExternalMovePause",{
                            Distance=moved,Seconds=elapsed,Delay=.75,
                            Phase=S.run("Phase")})
                    end
                end
                flightPreviousPosition=origin;flightPreviousAt=now
                api.FlyActualSpeed=root.AssemblyLinearVelocity.Magnitude
                local blocked=root.Anchored or hum.Sit
                    or UIKit.cursorFree()or Tools.Blocked or Tools.DevPaused
                    or P:GetAttribute("PerkPending")==true
                if blocked or now<flightPauseUntil then
                    flight.VectorVelocity=Vector3.zero
                    api.SafeMovementStatus="Flight paused for game state/server movement"
                elseif api.Stage=="Mining"and plan then
                    -- Follow the original bottom outer-ring geometry without
                    -- stopping at each angular waypoint. A tangent component
                    -- keeps movement circular; position feedback corrects
                    -- radial/height drift, with fly speed independent of normal WalkSpeed.
                    local speed=math.min(api.FlySpeed,api.FlySpeedLimit)
                    local ring=plan.Bands[band]
                    local ringRadius=math.sqrt((target.X-plan.Origin.X)^2+
                        (target.Z-plan.Origin.Z)^2)
                    local ringY=target.Y
                    local dx=origin.X-plan.Origin.X
                    local dz=origin.Z-plan.Origin.Z
                    local actualRadius=math.sqrt(dx*dx+dz*dz)
                    local radialError=actualRadius-ringRadius
                    local heightError=origin.Y-ringY
                    api.OrbitRadius=ringRadius
                    api.OrbitRadialError=radialError
                    api.OrbitHeightError=heightError
                    if not orbitEngaged then
                        local approachDistance=offset.Magnitude
                        api.OrbitFlightMode="Approach"
                        if approachDistance<=1.5 then
                            orbitEngaged=true
                            orbitProgress=0;orbitLapAt=os.clock()
                            orbitLastAngle=angle
                        else
                            local approachSpeed=math.min(speed,approachDistance*2.5)
                            flight.VectorVelocity=approachSpeed>0
                                and offset.Unit*approachSpeed or Vector3.zero
                            api.SafeMoveCommands+=1
                            api.SafeMovementStatus=string.format(
                                "Flying to ring: %.1f studs away @ %.1f studs/s",
                                approachDistance,approachSpeed)
                        end
                    end
                    if orbitEngaged then
                        api.OrbitFlightMode="Continuous circle"
                        local currentAngle=math.atan2(dz,dx)
                        local tangent=Vector3.new(-math.sin(currentAngle),0,
                            math.cos(currentAngle))
                        -- The target is the nearest point on the original
                        -- ring at the current angle, not a frozen waypoint.
                        local correction=(target-origin)*2.5
                        local commanded=tangent*speed+correction
                        if commanded.Magnitude>speed and speed>0 then
                            commanded=commanded.Unit*speed
                        end
                        flight.VectorVelocity=commanded
                        api.SafeMoveCommands+=1
                        api.SafeMovementStatus=string.format(
                            "%s circular flight @ %.1f studs/s; ring R=%.1f",
                            standardFarm and "Win Farm" or "Endless",
                            speed,ringRadius)
                    end
                elseif distance>.6 then
                    -- Keep original direct flight assistance for Mother boss:
                    -- only the mining ring uses continuous tangent control.
                    -- Keep fly velocity independent of normal walking speed.
                    local speed=math.min(api.FlySpeed,api.FlySpeedLimit)
                    local slowApproach=math.min(speed,distance*3)
                    flight.VectorVelocity=slowApproach>0 and offset.Unit*slowApproach or Vector3.zero
                    api.SafeMoveCommands+=1
                    api.OrbitFlightMode="Boss target"
                    api.SafeMovementStatus=string.format("Flying to boss @ %.1f studs/s",speed)
                else
                    flight.VectorVelocity=Vector3.zero
                    api.SafeMovementStatus="Holding boss target"
                end
            else
                root.CFrame=CFrame.lookAt(target,facing)
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
            end
            movementStage=api.Stage
            if api.Stage=="Mining"and plan and not (api.EscapeFarm and not api.Enabled)
                and not pendingBand and not (api.Enabled and api.SafeMovement)then
                -- Legacy non-flight controller only. Smooth flight counts
                -- laps from real angular progress above and never stops at waypoints.
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
        if ((api.Enabled and api.SafeMovement)or
            (api.EscapeFarm and not api.Enabled and api.WinFarmFly))then
            local char=P.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            -- Camera also follows the real character rather than the
            -- hypothetical orbit target, avoiding misleading aim angles.
            local topDown=api.Stage=="Mining"and api.EscapeFarm
                and not api.Enabled and isTopDownPass()
            local eye=root.Position+Vector3.new(0,topDown and 3 or 2,0)
            cam.CameraType=Enum.CameraType.Scriptable
            if topDown then
                cam.CFrame=CFrame.lookAt(eye,eye-Vector3.new(0,12,0),
                    Vector3.new(0,0,-1))
            else
                local view=focus-eye
                if view.Magnitude>.1 then cam.CFrame=CFrame.lookAt(eye,focus)end
            end
            api.AimMode=topDown and "Win Farm flight / top-down"
                or "Fly + noclip / actual character position"
            return
        end
        local topCamera=api.Stage=="Mining"and api.EscapeFarm
            and not api.Enabled and isTopDownPass()
        if topCamera then
            -- True 90-degree downward view tracking the moving orbit
            -- without the original 14-degree pitch or smoothing lag.
            local eye=target+Vector3.new(0,3,0)
            cam.CameraType=Enum.CameraType.Scriptable
            cam.CFrame=CFrame.lookAt(eye,focus,Vector3.new(0,0,-1))
            smoothedCameraRotation=nil
            api.AimMode="Top-down GEO-MAG"
            return
        end
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
            -- Standard farm formerly waited .125s between Mining / Boss
            -- checks, delaying ownership when a new phase begins.
            -- Keep the slower legacy cadence for unmanaged/Endless runs.
            task.wait(api.Stage=="Boss"and .04
                or (api.EscapeFarm and not api.Enabled)and .04 or .125)
        end
    end)
    return api
end

local Endless=createLiveEndless(Pickup,CrackSell,MagnetUpgrades,abilityPrefs)

-- On-demand, READ-ONLY Rusty Chisel and Crack Power investigator.
-- The existing GEO-MAG shop loop covers only MagPower/MagSpeed.
-- Do not guess a Crack Power ID or call the Shop remote before
-- the real game upgrade definition and native client purchase code
-- have been independently verified.
local function createChiselCrackPowerInspector()
    local P=game:GetService("Players").LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local H=game:GetService("HttpService")
    local api={Status="Not captured",LastPath=nil,Snapshots=0,
        SavedSources=0,LastError=nil}
    local function simplify(value,depth,seen)
        local kind=typeof(value)
        if kind=="number"or kind=="boolean"then return value end
        if kind=="string"then return value:sub(1,150)end
        if kind=="Vector3"or kind=="Vector2"or kind=="CFrame"then
            return tostring(value)
        end
        if kind=="Instance"then
            return {Name=value.Name,Class=value.ClassName}
        end
        if kind~="table"then return kind end
        if depth>=3 then return "[nested table]"end
        if seen[value]then return "[repeated table]"end
        seen[value]=true
        local out,n={},0
        for key,item in pairs(value)do
            n+=1
            if n>65 then out.__truncated=true;break end
            if type(key)=="string"or type(key)=="number"then
                local id=tostring(key):sub(1,90)
                out[id]=simplify(item,depth+1,seen)
            end
        end
        seen[value]=nil
        return out
    end
    local function inspect()
        local M=RS:WaitForChild("MTG")
        local C=P:WaitForChild("PlayerScripts"):WaitForChild("MTGClient")
        local S=require(C:WaitForChild("State"))
        local HUD=require(C:WaitForChild("RunHUD"))
        local Tools=require(C:WaitForChild("Tools"))
        local Stats=require(M.Modules:WaitForChild("Stats"))
        local Gear=require(M.Config:WaitForChild("Gear"))
        local Game=require(M.Config:WaitForChild("Game"))
        local Upgrades=require(M.Config:WaitForChild("Upgrades"))
        local Mode=require(M.Modules:WaitForChild("Mode"))
        local ctx=S.ctx()
        local state=M:FindFirstChild("State")
        local equipped=HUD.equipped()
        local owned=S.set("Tools")
        local report={
            Version=1,HubVersion=geodeVersion,
            CapturedAtMs=DateTime.now().UnixTimestampMillis,
            ReadOnly=true,RemoteCalls=0,PurchaseRequests=0,
            ToolEquips=0,CameraChanges=0,
            Role=S.role(),Phase=S.run("Phase"),Mode=S.run("Mode"),
            CurrentTool=equipped,
            ToolOwnership={},ToolStatistics={},
            CrackPower={},UpgradeIds={},UpgradeDetails={},
            MatchingUpgradeIds={},UpgradeLevels={},
            MatchingClientModules={},ClientModuleExports={},
            ShopClient={},
            Boss={
                MotherHP=S.run("MotherHP",0),
                MotherMax=S.run("MotherMax",0),
                ActiveSpot=Endless.ActiveBossSpot,
                ActiveSpotId=Endless.ActiveBossSpotId,
                BossToolId=Endless.BossToolId,
                WeaponId=Gear.Weapon and Gear.Weapon.Id,
                BestCracker=P:GetAttribute("BestCracker")or"Chisel",
                WeaponSlotAvailable=Gear.Weapon and HUD.slot(Gear.Weapon.Id)~=nil or false,
                DamageCurveExponent=Game.Mother and Game.Mother.DamageCurve and Game.Mother.DamageCurve.Exponent,
                FastChiselEnabled=FastChisel.Enabled,
                FastChiselApplied=FastChisel.Applied,
                FastChiselMultiplier=FastChisel.Multiplier,
                FastChiselBaseCooldown=FastChisel.BaseCooldown,
                FastChiselTargetCooldown=FastChisel.TargetCooldown,
                FastChiselStatus=FastChisel.Status,
                BossToolReady=Endless.BossToolReady,
                BossToolStatus=Endless.BossToolStatus,
                BossEquipAttempts=Endless.BossEquipAttempts,
                NativeBossFires=Endless.BossNativeFires or 0,
                NativeBossHits=Endless.Hits,
                NativeWeakHits=Endless.WeakHits,
                LastMotherHitTool=Endless.BossLastHitTool,
                LastMotherHitSpot=Endless.BossLastHitSpot,
                AutoCritical=Endless.BossAssist,
                RapidBoss=Endless.RapidBoss
            },
            Balances={Cash=P:GetAttribute("Cash")},
            Note="This inspector is read-only. Crack Power (upgrade ID Power) purchases automatically when enabled and affordable; fast Chisel mode alters native CLIENT attack cooldown, but server acceptance and actual HP damage must be tested. Client estimated weapon DPS is not proof of accepted boss damage."
        }
        local function relevant(id)
            id=tostring(id):lower()
            for _,term in ipairs({
                "crack","power","damage","hand","chisel","boss","mother",
                "pick","crit","strength"
            })do
                if id:find(term,1,true)then return true end
            end
            return false
        end
        local toolNames={}
        if type(owned)=="table"then
            for name,has in pairs(owned)do
                if type(name)=="string"and type(has)=="boolean"then
                    report.ToolOwnership[name]=has
                    if has then toolNames[name]=true end
                end
            end
        end
        for _,id in ipairs({
            "Hand","Chisel","RustyChisel","Rusty Chisel","Magnet"
        })do toolNames[id]=true end
        if type(equipped)=="string"then toolNames[equipped]=true end
        for id in pairs(toolNames)do
            if #report.ToolStatistics>=30 then break end
            local ok,value=pcall(Stats.tool,ctx,id)
            report.ToolStatistics[#report.ToolStatistics+1]={
                Id=id,Ok=ok,Stats=ok and simplify(value,0,{})or nil,
                Error=not ok and tostring(value):sub(1,180)or nil
            }
        end
        table.sort(report.ToolStatistics,function(a,b)return a.Id<b.Id end)
        local okPower,power=pcall(Stats.crackPower,ctx)
        report.CrackPower.Current=okPower and simplify(power,0,{})or nil
        report.CrackPower.Level=tonumber(ctx.Upg and ctx.Upg.Power)or 0
        report.CrackPower.BonusPercent=Upgrades.value("Power",report.CrackPower.Level)
        local okDps,dps=pcall(Stats.weaponDps,ctx)
        report.Boss.EstimatedWeaponDps=okDps and dps or nil
        local okHit,hit=pcall(Stats.motherHit,ctx,Gear.Weapon.Id)
        report.Boss.EstimatedWeaponHit=okHit and hit or nil
        report.CrackPower.Error=not okPower and tostring(power):sub(1,180)or nil
        report.CrackPower.Modifiers=simplify(ctx.Mods or{},0,{})
        report.UpgradeLevels=simplify(ctx.Upg or{},0,{})
        local byId=type(Upgrades)=="table"and Upgrades.ById or nil
        if type(byId)=="table"then
            for key,def in pairs(byId)do
                if type(key)=="string"then
                    report.UpgradeIds[#report.UpgradeIds+1]=key
                    if relevant(key)
                        or(type(def)=="table"
                            and relevant(def.Name or def.Title or""))then
                        local level=tonumber((ctx.Upg or{})[key])or 0
                        local entry={Id=key,Level=level,
                            Name=type(def)=="table"and tostring(def.Name or def.Title or key)or key}
                        if type(def)=="table"then
                            local scalars={}
                            for field,value in pairs(def)do
                                if field~="Costs"and(type(value)=="number"
                                    or type(value)=="boolean"
                                    or type(value)=="string")then
                                    scalars[tostring(field):sub(1,65)]=simplify(value,0,{})
                                end
                            end
                            entry.Fields=scalars
                            local costs=type(def.Costs)=="table"and def.Costs or{}
                            entry.MaxLevel=#costs
                            local rows={}
                            for i=1,math.min(#costs,25)do
                                local raw=costs[i]
                                local success,priced=pcall(Mode.price,raw)
                                rows[#rows+1]={Level=i,
                                    Raw=simplify(raw,0,{}),
                                    ModePrice=success and simplify(priced,0,{})or nil,
                                    PriceError=not success
                                        and tostring(priced):sub(1,100)or nil}
                            end
                            entry.Costs=rows
                            entry.NextCostIndex=level+1
                            entry.NextCost=costs[level+1]
                                and simplify(costs[level+1],0,{})or nil
                        else
                            entry.Type=typeof(def)
                        end
                        report.UpgradeDetails[#report.UpgradeDetails+1]=entry
                        report.MatchingUpgradeIds[#report.MatchingUpgradeIds+1]=key
                    end
                end
            end
            table.sort(report.UpgradeIds)
            table.sort(report.MatchingUpgradeIds)
            table.sort(report.UpgradeDetails,function(a,b)return a.Id<b.Id end)
        end
        for i=1,4 do
            local key="MotherSpot"..i
            report.Boss[key]={
                Direction=tostring(S.run(key)),
                Id=S.run(key.."Id",0),
                Hits=S.run(key.."Hits",0)
            }
        end
        local uiMatches={}
        local okGui,items=pcall(function()
            return P.PlayerGui:GetDescendants()
        end)
        if okGui then
            for _,obj in ipairs(items)do
                if #uiMatches>=90 then break end
                if obj:IsA("TextLabel")or obj:IsA("TextButton")
                    or obj:IsA("ImageButton")then
                    local title=(obj:IsA("TextLabel")or obj:IsA("TextButton"))
                        and obj.Text or""
                    if relevant(obj.Name)or relevant(title)then
                        uiMatches[#uiMatches+1]={
                            Class=obj.ClassName,Name=obj.Name,
                            Text=type(title)=="string"and title:sub(1,130)or"",
                            Visible=obj.Visible,
                            Parent=obj.Parent and obj.Parent.Name or nil
                        }
                    end
                end
            end
        end
        report.MatchingUI=uiMatches
        local keyModules={
            {Root=C,Name="Tools"},
            {Root=C,Name="RunHUD"},
            {Root=C,Name="ShopUI"},
            {Root=C,Name="UpgradesUI"},
            {Root=M.Config,Name="Upgrades"},
            {Root=M.Modules,Name="Stats"},
            {Root=M.Modules,Name="Mode"}
        }
        for _,item in ipairs(keyModules)do
            local module=item.Root:FindFirstChild(item.Name)
            report.MatchingClientModules[#report.MatchingClientModules+1]={
                Name=item.Name,Found=module~=nil,
                Class=module and module.ClassName or nil,
                Path=module and module:GetFullName()or nil
            }
        end
        -- This diagnostic also reports known native attack events without
        -- subscribing to them or making an in-game attack.
        report.NativeToolAPI={
            MotherHitSignal=typeof(Tools.MotherHit),
            FiredSignal=typeof(Tools.Fired),
            DevPaused=Tools.DevPaused==true,
            Blocked=Tools.Blocked==true,
            HasSetUse=type(Tools.setUse)=="function",
            HasSelectTool=type(HUD.selectTool)=="function"
        }
        return report
    end
    function api.Export(label)
        local ok,filename=pcall(function()
            assert(type(writefile)=="function","File writing unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local data=inspect()
            local suffix=label=="before"and"_before"or
                label=="after"and"_after"or""
            local file="Geode/chisel_crack_power"..suffix.."_diagnostics.json"
            data.Snapshot=label or"current"
            writefile(file,H:JSONEncode(data))
            api.Snapshots+=1
            api.LastPath=file
            return file
        end)
        if not ok then
            api.LastError=tostring(filename)
            api.Status="Chisel / Crack Power inspection failed: "..api.LastError
            return false,api.Status
        end
        api.LastError=nil
        api.Status="Saved "..filename.." ("..api.Snapshots.." snapshots)"
        return true,filename
    end
    function api.ExportNative()
        local ok,response=pcall(function()
            assert(type(decompile)=="function",
                "Your executor does not expose decompile(ModuleScript)")
            assert(type(writefile)=="function","File writing unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local M=RS:WaitForChild("MTG")
            local scripts=P:FindFirstChild("PlayerScripts")
            local C=scripts and scripts:FindFirstChild("MTGClient")
            local manifest={Version=1,HubVersion=geodeVersion,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                ReadOnly=true,RemoteCalls=0,PurchaseRequests=0,
                Modules={},Saved=0}
            for _,spec in ipairs({
                {Module=C and C:FindFirstChild("Tools"),
                    Name="Tools",File="Geode/chisel_native_Tools.lua"},
                {Module=C and C:FindFirstChild("RunHUD"),
                    Name="RunHUD",File="Geode/chisel_native_RunHUD.lua"},
                {Module=C and C:FindFirstChild("ShopUI"),
                    Name="ShopUI",File="Geode/chisel_native_ShopUI.lua"},
                {Module=C and C:FindFirstChild("UpgradesUI"),
                    Name="UpgradesUI",File="Geode/chisel_native_UpgradesUI.lua"},
                {Module=M.Config and M.Config:FindFirstChild("Upgrades"),
                    Name="Upgrades",File="Geode/chisel_native_Upgrades.lua"},
                {Module=M.Modules and M.Modules:FindFirstChild("Stats"),
                    Name="Stats",File="Geode/chisel_native_Stats.lua"}
            })do
                local entry={Name=spec.Name,
                    Found=spec.Module~=nil,
                    Class=spec.Module and spec.Module.ClassName or nil}
                if spec.Module and spec.Module:IsA("ModuleScript")then
                    local good,src=pcall(decompile,spec.Module)
                    if good and type(src)=="string"and #src>0 then
                        entry.SourceBytes=#src
                        entry.Truncated=#src>180000
                        local content=entry.Truncated and src:sub(1,180000)or src
                        -- Keep code syntax usable for reading; mask long
                        -- numeric IDs that could identify individual users.
                        content=content:gsub("%d%d%d%d%d%d%d%d+","[redacted-id]")
                        local wrote,err=pcall(writefile,spec.File,content)
                        entry.Saved=wrote
                        if wrote then
                            entry.File=spec.File
                            manifest.Saved+=1
                        else entry.Error=tostring(err):sub(1,160)end
                    else
                        entry.Error=tostring(src):sub(1,160)
                    end
                end
                manifest.Modules[#manifest.Modules+1]=entry
            end
            local path="Geode/chisel_crack_native_modules_diagnostics.json"
            writefile(path,H:JSONEncode(manifest))
            return {Path=path,Saved=manifest.Saved}
        end)
        if not ok then
            api.LastError=tostring(response)
            api.Status="Native client inspection failed: "..api.LastError
            return false,api.Status
        end
        api.SavedSources=response.Saved
        api.Status="Saved "..response.Path.." and "
            ..tostring(response.Saved).." native client modules"
        return true,response.Path
    end
    return api
end
local ChiselCrackInspector=createChiselCrackPowerInspector()
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
    function api.SetEnabled(value)
        api.Enabled=value==true
        if not api.Enabled then api.Status="Paused by farm safety";api.Available=false end
    end
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
                if not api.Enabled then
                    controller.Tick(false)
                    api.Available=false;api.EscapeFarmActive=false
                    api.Status="Paused by farm safety"
                    return
                end
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
    -- Pre-equip was introduced in v1.10.45 but HUD/UIKit were never
    -- declared in this controller, causing repeated nil-index errors
    -- throughout the entire Waiting phase.
    local HUD=require(player.PlayerScripts.MTGClient.RunHUD)
    local UIKit=require(player.PlayerScripts.MTGClient.UIKit)
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
    -- Waiting normally lasts about 14s; keep the low-rate, native
    -- owned-tool equip attempt alive until Mining actually begins.
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
        CrackSell.SetWinFarmFast(false)
        if Pickup.Enabled then Pickup.Stop()end
        if Escape.Enabled then Escape.Stop()end
    end
    function api.SetWindow(value)attachedWindow=value end
    function api.SetQueueEnabler(value)enableTeleportQueue=type(value)=="function"and value or nil end
    function api.Start()
        if not api.Running or api.Enabled then return end
        if not CrackPowerUpgrades.Enabled then CrackPowerUpgrades.Start()end
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
        -- Max-time Win Farm: start the SINGLE camp trip 0.10s after the
        -- first genuine bag change. Normal/manual Crack Delay is preserved
        -- and returns when this farm stops.
        CrackSell.SetWinFarmFast(true)
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
            EffectiveCrackDelaySeconds=CrackSell.WinFarmFast
                and math.min(CrackSell.Interval,CrackSell.WinFarmDelay)
                or CrackSell.Interval,
            FastWinFarmSale=CrackSell.WinFarmFast,
            EarlyPickupStatus=Pickup.EarlyIntroStatus,
            EarlyPickupAttempts=Pickup.EarlyAttempts,
            EarlyPickupConfirmed=Pickup.EarlyConfirmed})
    end
    local function stopRound()
        Endless.SetEscapeFarm(false)
        if Pickup.Enabled then Pickup.Stop()end
        if CrackSell.Enabled or CrackSell.Busy then CrackSell.Stop("Round finished")end
        CrackSell.SetWinFarmFast(false)
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
        local availableTools=waiting and State.set("Tools")or nil
        local equipped=HUD.equipped()
        if waiting and waitingEquipAttempts<24 and os.clock()>=nextWaitingEquip
            and type(availableTools)=="table"and availableTools.Magnet==true
            and equipped~="Magnet"
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
                WinFarmFastSale=CrackSell.WinFarmFast,
                WinFarmEffectiveCrackDelay=CrackSell.WinFarmFast
                    and math.min(CrackSell.Interval,CrackSell.WinFarmDelay)
                    or CrackSell.Interval,
                SweepActive=Endless.EscapeFarm,SweepMode=Endless.WinSweepMode,
                SweepSpeed=Endless.WinSweepSpeed,SweepItemsPerSecond=Endless.WinSweepItemsPerSecond,
                SweepRadiusScale=Endless.WinSweepRadiusScale,
                SweepHeightRing=Endless.WinSweepHeightRing,
                SweepHeightOffset=Endless.WinSweepHeightOffset,
                SweepCoveragePass=Endless.WinSweepCoveragePass,
                SweepCoreRadius=Endless.WinSweepCoreRadius,
                SweepCoreItems=Endless.WinSweepCoreItems,
                SweepCompletedLaps=Endless.WinSweepCompletedLaps,
                SweepEarlyBaseSkips=Endless.WinSweepEarlyBaseSkips,
                SweepEarlyCoreSkips=Endless.WinSweepEarlyCoreSkips,
                TopDownSecondPassEnabled=Endless.TopDownSecondPass,
                TopDownSuccesses=Endless.WinSweepTopDownSuccesses,
                TopDownFallbacks=Endless.WinSweepTopDownFallbacks,
                TopDownItems=Endless.WinSweepTopDownItems,
                SweepFirstFireWaitMs=Endless.WinSweepFirstFireWaitMs,
                MiningToNativeFireMs=api.RoundStartedAt>0
                    and (Endless.WinSweepFirstFireClock or 0)>api.RoundStartedAt
                    and math.floor((Endless.WinSweepFirstFireClock-api.RoundStartedAt)*1000+.5)
                    or nil,
                MiningToFirstConfirmedPickupMs=api.RoundStartedAt>0
                    and (Endless.WinSweepFirstPickupClock or 0)>api.RoundStartedAt
                    and math.floor((Endless.WinSweepFirstPickupClock-api.RoundStartedAt)*1000+.5)
                    or nil,
                SweepPlanBuildWaitMs=Endless.WinSweepPlanBuildWaitMs,
                SweepCoreSpeedBoosts=Endless.WinSweepCoreSpeedBoosts,
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
                -- Previously every rarity of Shortcut earned the same
                -- strategic priority even when the offered stack gain
                -- was larger. Stronger offers should be distinguishable.
                prefer(91+mineWeight*48+math.min(16,depthTime/8)
                    +math.min(24,math.max(0,stacks-1)*5),
                    "Less mound work per depth; adjusts for offered stacks")
            elseif id=="ChainReaction"then
                prefer(83+mineWeight*48,"Splash damage clears geodes earlier")
            elseif id=="WideSweep"then
                local radius=math.max(0,tonumber(mods.Radius)or 0)
                local addedRadius=math.max(0,tonumber(bonus.Radius)or 0)*stacks
                prefer(70+mineWeight*40+math.min(22,addedRadius*.2)
                    -math.min(25,radius*.12),
                    "Collection reach accounts for offered radius and existing reach")
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
                local extraRecurring=15*stacks
                local deficit=math.max(0,burnPerDepth-recurring)
                if deficit>0 then
                    local coverage=math.min(1,extraRecurring/math.max(1,deficit))
                    prefer(78+timerPressure*95+coverage*36,
                        "Offered recurring fuel ("..tostring(extraRecurring)
                        .."/depth) closes "..math.floor(coverage*100+.5)
                        .."% of the measured fuel deficit")
                end
            elseif id=="EternalFlame"then
                prefer(88+timerPressure*100+math.min(18,math.max(0,stacks-1)*4),
                    "Slower lantern consumption, scaled for offered stacks")
            elseif id=="LanternWick"then
                prefer(67+timerPressure*75+math.min(15,math.max(0,stacks-1)*3),
                    "Reduced fuel drain across depths, scaled for offered stacks")
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
        record("Selection",{Choice=best,Ranking=ranking,Offer=c.Offer,
            RankContext={Depth=c.Depth,Phase=c.Phase,OilRunway=c.OilRunway,
                OilLeft=c.OilLeft,OilPerDepth=c.OilPerDepth,
                DepthSeconds=c.DepthSeconds,LastBossSeconds=c.LastBossSeconds,
                NativeCooldown=c.NativeCooldown,RequestFloor=c.RequestFloor,
                BagCapacity=c.BagCapacity,MagnetMaxed=c.MagnetMaxed,
                AbilitiesActive=c.AbilitiesActive,SkillUnlocked=c.SkillUnlocked,
                Adaptive=c.Adaptive,DamageFocus=c.DamageFocus}})
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
    local Mastery=require(C.Mastery)
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
        -- Read actual mastery unlock, not Endless.AbilityAvailable: that
        -- cached flag is intentionally not refreshed during boss-reserved
        -- Mining and is often false just when perk offers appear.
        local skill=Mastery.skillStats("Magnet")
        local skillUnlocked=skill~=nil
            and Mastery.level("Tool:Magnet")>=Mastery.SkillLevel
        local autoAbilityRelevant=Endless~=nil and Endless.Enabled
            and skillUnlocked
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
            AbilitiesActive=autoAbilityRelevant,AbilityStats=skill,
            SkillUnlocked=skillUnlocked,AbilityRuntimeAvailable=Endless and Endless.AbilityAvailable,
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
            local c=context();local all={};local critFields={};local catalog={}
            for _,def in ipairs(E.Perks)do
                all[#all+1]={Id=def.Id,Rarity=def.Rarity}
                -- Capture every current game-defined perk, not just our
                -- hardcoded known IDs. Keep only JSON-safe scalar fields
                -- and numeric/string modifier effects.
                local summary={}
                for key,value in pairs(def)do
                    if type(key)=="string"then
                        if type(value)=="string"or type(value)=="number"
                            or type(value)=="boolean"then
                            summary[key]=value
                        elseif key=="Mods"and type(value)=="table"then
                            local modifiers={}
                            for mod,amount in pairs(value)do
                                if type(mod)=="string"and
                                    (type(amount)=="number"or type(amount)=="string"
                                        or type(amount)=="boolean")then
                                    modifiers[mod]=amount
                                end
                            end
                            summary.Mods=modifiers
                        end
                    end
                end
                catalog[#catalog+1]=summary
                local fields={}
                for key,value in pairs(def.Mods or {})do
                    if type(key)=="string"and key:lower():find("crit",1,true)then
                        fields[#fields+1]={Key=key,Value=value}
                    end
                end
                if #fields>0 then critFields[#critFields+1]={Id=def.Id,Name=def.Name,Fields=fields}end
            end
            local _,ranking=choose(all,c)
            local _,currentRanking=choose(c.Cards or{},c)
            if not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/auto_perk_diagnostics.json",H:JSONEncode({Version=1,Enabled=api.Enabled,Status=api.Status,Requests=api.Requests,Confirmed=api.Confirmed,
                LastChoice=api.LastChoice,LastOfferRanking=api.LastRanking,DefaultRarityRanking=ranking,
                GamePerkCatalog=catalog,GamePerkCount=#catalog,
                CurrentOfferCards=c.Cards,CurrentOfferRanking=currentRanking,
                DamageFocus=api.DamageFocus,Adaptive=api.Adaptive,FocusMode=api.FocusMode,GameDefinedCriticalPerks=critFields,
                Context={DamageFocus=c.DamageFocus,Adaptive=c.Adaptive,Phase=c.Phase,Depth=c.Depth,
                    SkillUnlocked=c.SkillUnlocked,AbilityRuntimeAvailable=c.AbilityRuntimeAvailable,
                    OilLeft=c.OilLeft,OilRunway=c.OilRunway,LanternRate=c.LanternRate,LastBossSeconds=c.LastBossSeconds,ObservedTimerAttributes=observedTimerAttributes(),NativeCooldown=c.NativeCooldown,RequestFloor=c.RequestFloor,
                    BagCapacity=c.BagCapacity,MagnetMaxed=c.MagnetMaxed,CrackPowerPercent=c.CrackPowerPercent,OilPerDepth=c.OilPerDepth,DepthSeconds=c.DepthSeconds,Owned=c.Owned,Mods=c.Mods,AbilitiesActive=c.AbilitiesActive,AbilityStats=c.AbilityStats},Events=events,
                Note="Exports all E.Perks game-defined IDs and scalar/modifier values; current and last offered rankings include reasons, while selection events capture conditions at pick time. Ability relevancy uses direct mastery unlock instead of an intermittently stale cached flag. Strategic fuel and Shortcut scores now account for offered stack count. Lantern runway is not a verified boss deadline. Unrecognized special effects may still require manual interpretation. One native card selection per offer; no rerolls."}))
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

-- Client-only safety interlock. It is intentionally NOT an anti-moderation
-- bypass: it reacts to the local player's authoritative spectator flag and,
-- optionally, explicit local restriction flags. Server-only admin actions
-- are not observable and are never intercepted or altered.
local function createFarmSafetyController()
    local Players=game:GetService("Players")
    local P=Players.LocalPlayer
    local H=game:GetService("HttpService")
    local api={
        Running=true,Enabled=true,Stopped=false,
        WatchOfficial=true,WatchRestrictions=false,
        Status="Armed — monitoring official spectator state",
        LastTrigger=nil,TriggeredAtMs=nil,Triggers=0,
        OnStop=nil
    }
    local restrictions={
        "AdminFrozen","AdminJailed","AdminPaused",
        "ModerationHold","AdminRestricted"
    }
    local connection=P:GetAttributeChangedSignal("Spectator"):Connect(function()
        -- Trigger in next task so the complete controller is initialized.
        task.defer(function()if api.Running then api.Check()end end)
    end)
    local function observedRestriction()
        for _,name in ipairs(restrictions)do
            if P:GetAttribute(name)==true then
                return name
            end
        end
        -- Tools.DevPaused is a client-visible state referenced by the
        -- game's own native ability code. It is not proved to mean moderation.
        local ok,paused=pcall(function()
            local ps=P:FindFirstChild("PlayerScripts")
            local client=ps and ps:FindFirstChild("MTGClient")
            local module=client and client:FindFirstChild("Tools")
            if not module then return false end
            local tools=require(module)
            return type(tools)=="table"and tools.DevPaused==true
        end)
        if ok and paused then return "Native Tools.DevPaused"end
        return nil
    end
    function api.StopAll(reason)
        if not api.Running or api.Stopped then
            return false,"Safety stop already active"
        end
        api.Stopped=true
        api.Triggers+=1
        api.LastTrigger=tostring(reason or"Manual emergency stop"):sub(1,180)
        api.TriggeredAtMs=DateTime.now().UnixTimestampMillis
        api.Status="STOPPED — "..api.LastTrigger
            ..". Manually re-arm before starting a new farm."
        -- Stop the owning farm first: its Stop() releases
        -- Endless firing, pickup, auto-cracking and replay controls.
        local stopList={
            {"Auto Farm Escapes",function()FarmEscapes.Stop("Safety stop")end},
            {"Endless",function()
                Endless.SetEscapeFarm(false)
                Endless.SetBossAssist(false)
                Endless.Stop()
            end},
            {"Crack & Sell",function()CrackSell.Stop("Safety stop")end},
            {"Pickup",function()Pickup.Stop()end},
            {"Escape",function()Escape.Stop()end},
            {"GEO-MAG upgrades",function()MagnetUpgrades.Stop("Safety stop")end},
            {"Crack Power upgrades",function()CrackPowerUpgrades.Stop("Safety stop")end},
            {"Fast Rusty Chisel",function()FastChisel.SetEnabled(false)end},
            {"Auto Perks",function()AutoPerks.Stop()end},
            {"Class Mutations",function()ClassMutations.Stop("Safety stop")end},
            {"Haunted Eggs",function()Eggs.Stop()end},
            {"Lava Eggs",function()LavaFastHatch.Stop("Safety stop")end},
            {"WalkSpeed",function()GameWalkSpeed.SetEnabled(false)end},
            {"Anti AFK",function()AntiAFK.SetEnabled(false)end},
            {"Overcharge",function()OtherModeAbility.SetEnabled(false)end}
        }
        for _,item in ipairs(stopList)do
            local ok,err=pcall(item[2])
            if not ok then warn("[BeyyHub safety] Stop "..item[1]..": "..tostring(err))end
        end
        if type(api.OnStop)=="function"then
            pcall(api.OnStop,api.LastTrigger)
        end
        return true,api.Status
    end
    function api.Check()
        if not api.Running or not api.Enabled or api.Stopped then return end
        if api.WatchOfficial and P:GetAttribute("Spectator")==true then
            return api.StopAll("Official WatchRun spectator state activated")
        end
        if api.WatchRestrictions then
            local restriction=observedRestriction()
            if restriction then
                return api.StopAll("Explicit local restriction: "..restriction)
            end
        end
    end
    function api.SetEnabled(value)
        api.Enabled=value==true
        if not api.Stopped then
            api.Status=api.Enabled and "Armed — monitoring local signals"
                or"Automatic safety monitoring disabled"
        end
        if api.Enabled then api.Check()end
    end
    function api.SetWatchOfficial(value)
        api.WatchOfficial=value==true
        api.Check()
    end
    function api.SetWatchRestrictions(value)
        api.WatchRestrictions=value==true
        api.Check()
    end
    function api.Rearm()
        if not api.Running then return false,"Controller unloaded"end
        if api.WatchOfficial and P:GetAttribute("Spectator")==true then
            return false,"Official WatchRun is still active"
        end
        if api.WatchRestrictions and observedRestriction()then
            return false,"A selected local restriction flag is still active"
        end
        api.Stopped=false
        api.Enabled=true
        OtherModeAbility.SetEnabled(true)
        api.Status="Re-armed — automation remains OFF until manually started"
        -- Never automatically restart farming after an interruption.
        return true,api.Status
    end
    function api.Export()
        local ok,err=pcall(function()
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            writefile("Geode/farm_safety_diagnostics.json",H:JSONEncode({
                Version=1,HubVersion=geodeVersion,
                Monitoring=api.Enabled,Stopped=api.Stopped,
                WatchOfficial=api.WatchOfficial,
                WatchRestrictions=api.WatchRestrictions,
                LocalSpectator=P:GetAttribute("Spectator")==true,
                RestrictionNamesChecked=restrictions,
                RestrictionActive=api.WatchRestrictions and observedRestriction()or nil,
                LastTrigger=api.LastTrigger,TriggeredAtMs=api.TriggeredAtMs,
                Triggers=api.Triggers,Status=api.Status,
                FarmStatus={
                    EscapeFarm=FarmEscapes.Enabled,
                    Endless=Endless.Enabled,
                    Crack=CrackSell.Enabled,
                    Pickup=Pickup.Enabled,AutoEscape=Escape.Enabled,
                    Lava=LavaFastHatch.Enabled
                },
                Note="Passive own-client safety signals and local emergency stop only. No other users are scanned; no DevAction invocation, camera interference, anti-admin bypass or remote hook. Server-only commands cannot be detected."
            }))
        end)
        return ok,err
    end
    function api.Unload()
        api.Running=false
        connection:Disconnect()
    end
    task.spawn(function()
        while api.Running do
            api.Check()
            task.wait(.20)
        end
    end)
    return api
end
local FarmSafety=createFarmSafetyController()
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

-- Opt-in, read-only client-visible movement recorder. The Roblox server's
-- private anti-cheat rules, verdicts and logs are NOT available from a client.
-- Frequent local snapshots survive ordinary script stop/disconnect better than
-- exporting only after an incident; no server remotes are hooked or modified.
local function createClientMovementDiagnostics()
    local Players=game:GetService("Players")
    local P=Players.LocalPlayer
    local RunService=game:GetService("RunService")
    local LogService=game:GetService("LogService")
    local Http=game:GetService("HttpService")
    local MTG=game:GetService("ReplicatedStorage"):FindFirstChild("MTG")
    -- v1.10.83 referenced State from a different function's local scope,
    -- making every movement sample fail before reaching the ring telemetry.
    -- Load the native State module in THIS recorder scope; keep sampling
    -- even if the module is temporarily unavailable or throws on a read.
    local gameClient=P:FindFirstChild("PlayerScripts")
    gameClient=gameClient and gameClient:FindFirstChild("MTGClient")
    local stateModule=gameClient and gameClient:FindFirstChild("State")
    local nativeState
    if stateModule then
        local ok,value=pcall(require,stateModule)
        if ok and type(value)=="table"then nativeState=value end
    end
    local function getPhaseOrMode(key)
        if not nativeState or type(nativeState.run)~="function"then return nil end
        local ok,value=pcall(nativeState.run,key)
        if ok then return value end
        return nil
    end
    local path="Geode/anticheat_client_diagnostics.json"
    local api={Running=true,Enabled=false,Status="Off — opt in before reproducing",
        Path=path,Samples=0,Alerts=0,Events=0,Logs=0,Writes=0,Failures=0,
        SampleFailures=0,PersistenceFailures=0,LastSampleError=nil,
        LastPersistenceError=nil,
        CurrentSpeed=0,MaxObservedSpeed=0,LastError=nil,LastSavedMs=0,
        SampleInterval=.08,SaveInterval=.6}
    local samples,events,logs={},{},{}
    local heartbeat,logConnection,teleportConnection
    local previousPosition,previousCharacter,previousAt
    local previousSignature,previousFlight
    local sampleAt,saveAt=0,0
    local writerBusy=false
    local clientCandidates
    local function cappedAdd(collection,item,maxCount)
        collection[#collection+1]=item
        if #collection>maxCount then table.remove(collection,1)end
    end
    local function vector(value)
        if not value then return nil end
        return {X=math.floor(value.X*1000+.5)/1000,
            Y=math.floor(value.Y*1000+.5)/1000,
            Z=math.floor(value.Z*1000+.5)/1000}
    end
    local function event(kind,details)
        cappedAdd(events,{AtMs=DateTime.now().UnixTimestampMillis,
            Kind=kind,Data=details},150)
        api.Events+=1
    end
    local function clientScriptCandidates()
        if clientCandidates then return clientCandidates end
        local results={}
        local checked=0
        local sources={}
        local scripts=P:FindFirstChild("PlayerScripts")
        if scripts then sources[#sources+1]=scripts end
        if MTG then sources[#sources+1]=MTG end
        for _,source in ipairs(sources)do
            if source then
                for _,obj in ipairs(source:GetDescendants())do
                    checked+=1
                    if checked>3500 or #results>=70 then break end
                    if obj:IsA("LuaSourceContainer")or obj:IsA("RemoteEvent")
                        or obj:IsA("RemoteFunction")then
                        local name=obj.Name:lower()
                        if name:find("anti",1,true)or name:find("security",1,true)
                            or name:find("speed",1,true)or name:find("movement",1,true)
                            or name:find("teleport",1,true)or name:find("physics",1,true)
                            or name:find("validator",1,true)or name:find("kick",1,true)then
                            local pathOK,fullPath=pcall(function()return obj:GetFullName()end)
                            results[#results+1]={Name=obj.Name,Class=obj.ClassName,
                                Path=pathOK and fullPath:sub(1,220)or obj.Name}
                        end
                    end
                end
            end
        end
        clientCandidates=results
        return results
    end
    local function makeSample()
        local now=os.clock()
        local wall=DateTime.now().UnixTimestampMillis
        local char=P.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local role=MTG and MTG:GetAttribute("Role")or nil
        local phase=getPhaseOrMode("Phase")
        local mode=getPhaseOrMode("Mode")
        local rootPosition=root and root.Position
        local fromPosition=previousPosition
        local delta,elapsed,speed,horizontal=0,0,0,0
        if rootPosition and previousPosition and previousCharacter==char and previousAt then
            elapsed=now-previousAt
            if elapsed>.001 then
                local offset=rootPosition-previousPosition
                delta=offset.Magnitude
                speed=delta/elapsed
                horizontal=Vector3.new(offset.X,0,offset.Z).Magnitude/elapsed
            end
        end
        previousPosition=rootPosition
        previousCharacter=char
        previousAt=now
        api.CurrentSpeed=speed
        api.MaxObservedSpeed=math.max(api.MaxObservedSpeed,speed)
        local state=hum and hum:GetState()
        local anchored=root and root.Anchored or false
        local flying=Endless.Enabled and Endless.FlyActive==true
        local description=tostring(role).."/"..tostring(mode).."/"..tostring(phase)
            .."|anchored="..tostring(anchored)
            .."|humanoid="..tostring(state)
        if description~=previousSignature or flying~=previousFlight then
            event("GameOrMovementStateChanged",{Role=role,Mode=mode,Phase=phase,
                Anchored=anchored,HumanoidState=state and state.Name or nil,
                FlyActive=flying,EndlessStage=Endless.Stage})
            previousSignature=description;previousFlight=flying
        end
        local nativeWalkSpeed=hum and hum.WalkSpeed or nil
        if elapsed>.001 and (delta>=8 or
            speed>math.max(24,(nativeWalkSpeed or 16)*1.6))then
            api.Alerts+=1
            event("ClientMovementAnomaly_NotServerVerdict",{
                Distance=delta,Seconds=elapsed,ObservedStudsPerSecond=speed,
                HorizontalStudsPerSecond=horizontal,
                NativeWalkSpeed=nativeWalkSpeed,
                From=vector(fromPosition),
                To=vector(rootPosition),
                FlyActive=flying,FlightCommand=Endless.FlySpeed})
        end
        local serverTime
        local ok,reply=pcall(function()return workspace:GetServerTimeNow()end)
        if ok then serverTime=reply end
        local sample={
            WallMs=wall,ServerTime=serverTime,ClientClock=now,
            Role=role,Mode=mode,Phase=phase,
            CharacterPresent=char~=nil,
            RootPresent=root~=nil,HumanoidPresent=hum~=nil,
            Position=vector(rootPosition),
            DeltaStuds=delta,DeltaSeconds=elapsed,
            CalculatedSpeed=speed,CalculatedHorizontalSpeed=horizontal,
            NativeWalkSpeed=nativeWalkSpeed,
            RootVelocity=root and vector(root.AssemblyLinearVelocity)or nil,
            RootVelocityMagnitude=root and root.AssemblyLinearVelocity.Magnitude or nil,
            RootAngularVelocityMagnitude=root and root.AssemblyAngularVelocity.Magnitude or nil,
            RootAnchored=anchored,RootCanCollide=root and root.CanCollide,
            HumanoidState=state and state.Name or nil,
            FloorMaterial=hum and hum.FloorMaterial.Name or nil,
            HumanoidSit=hum and hum.Sit or false,
            PlatformStand=hum and hum.PlatformStand or false,
            MoveDirectionMagnitude=hum and hum.MoveDirection.Magnitude or nil,
            GameWalkSpeedMonitorEnabled=GameWalkSpeed.Enabled,
            AutoEndless=Endless.Enabled,EndlessStage=Endless.Stage,
            EndlessFlightActive=Endless.FlyActive,
            FlightCommandSpeed=Endless.FlySpeed,
            FlightMeasuredVelocity=Endless.FlyActualSpeed,
            NoclipParts=Endless.FlyNoclipParts,
            FlightStatus=Endless.SafeMovementStatus,
            AutoFarmEscapes=FarmEscapes.Enabled,
            CrackSellBusy=CrackSell.Busy,
            FarmSafetyStopped=FarmSafety.Stopped
        }
        cappedAdd(samples,sample,360)
        api.Samples+=1
    end
    local function snapshot(reason)
        local latest=samples[#samples]
        return {
            Version=1,Build=geodeVersion,Source="Read-only local client observation",
            ServerPrivateLogsAvailable=false,
            Note="Not a dump of the server's anti-cheat. Sampled displacement and flagged anomalies are client estimates, not evidence of server rules or verdicts.",
            Reason=reason or "Manual",SavedAtMs=DateTime.now().UnixTimestampMillis,
            PlaceId=game.PlaceId,GameId=game.GameId,
            SessionJobId=game.JobId,
            CaptureEnabled=api.Enabled,SampleInterval=api.SampleInterval,
            SaveInterval=api.SaveInterval,
            CapturedSamples=api.Samples,CapturedAlerts=api.Alerts,
            CapturedEvents=api.Events,CapturedMatchingClientLogs=api.Logs,
            PersistenceWrites=api.Writes,PersistenceFailures=api.PersistenceFailures,
            SamplingFailures=api.SampleFailures,
            LastSamplingError=api.LastSampleError,
            LastPersistenceError=api.LastPersistenceError,
            StateReaderAvailable=nativeState~=nil,
            CurrentSpeed=api.CurrentSpeed,MaxObservedSpeed=api.MaxObservedSpeed,
            RecentSample=latest,Samples=samples,
            Events=events,MatchingClientOutput=logs,
            PotentiallyRelevantClientScriptPaths=clientScriptCandidates(),
            Controls={FlyEnabled=Endless.Enabled,FlySpeed=Endless.FlySpeed,
                FlyActualSpeed=Endless.FlyActualSpeed,
                FlyNoclipParts=Endless.FlyNoclipParts,
                GameWalkSpeedMonitor=GameWalkSpeed.Enabled,
                AutoFarmEscapes=FarmEscapes.Enabled},
            Limitations="Cannot access server movement snapshots, kicks/ban reasons beyond client-visible UI, private anti-cheat code or server log files. Disconnect can occur before the next local .6s autosave."
        }
    end
    local function persist(reason)
        if writerBusy then return false,"A snapshot write is already in progress"end
        writerBusy=true
        local ok,err=pcall(function()
            if not isfolder("Geode")then makefolder("Geode")end
            writefile(path,Http:JSONEncode(snapshot(reason)))
        end)
        writerBusy=false
        if ok then
            api.Writes+=1;api.LastSavedMs=DateTime.now().UnixTimestampMillis
            saveAt=os.clock()
            api.Status=api.Enabled and "Recording — auto-saving to "..path
                or "Saved latest client movement snapshot to "..path
            return true,path
        end
        api.Failures+=1;api.PersistenceFailures+=1
        api.LastPersistenceError=tostring(err)
        api.LastError="Persistence: "..tostring(err)
        api.Status="Save failed: "..tostring(err)
        return false,tostring(err)
    end
    function api.Export()
        if not api.Enabled then
            local ok,err=pcall(makeSample)
            if not ok then
                api.SampleFailures+=1;api.Failures+=1
                api.LastSampleError=tostring(err)
                api.LastError="Manual sample: "..tostring(err)
                event("SampleError",{Error=tostring(err)})
            end
        end
        return persist("Manual debug export")
    end
    function api.SetEnabled(value)
        local enabled=value==true
        if not api.Running or api.Enabled==enabled then return end
        if enabled then
            api.Enabled=true
            previousPosition=nil;previousCharacter=nil;previousAt=nil
            previousSignature=nil;previousFlight=nil
            event("RecorderStarted",{Build=geodeVersion,Path=path})
            heartbeat=RunService.Heartbeat:Connect(function()
                local now=os.clock()
                if now-sampleAt<api.SampleInterval then return end
                sampleAt=now
                local ok,err=pcall(makeSample)
                if not ok then
                    api.Failures+=1;api.SampleFailures+=1
                    api.LastSampleError=tostring(err)
                    api.LastError="Sampling: "..tostring(err)
                    if api.SampleFailures<=3 or api.SampleFailures%100==0 then
                        event("SampleError",{Error=tostring(err),Attempts=api.SampleFailures})
                    end
                end
            end)
            logConnection=LogService.MessageOut:Connect(function(message,messageType)
                local msg=tostring(message or "")
                local lower=msg:lower()
                if lower:find("anticheat",1,true)or lower:find("anti-cheat",1,true)
                    or lower:find("teleport",1,true)or lower:find("too fast",1,true)
                    or lower:find("speed",1,true)or lower:find("noclip",1,true)
                    or lower:find("movement",1,true)or lower:find("kicked",1,true)
                    or lower:find("fly",1,true)then
                    api.Logs+=1
                    cappedAdd(logs,{AtMs=DateTime.now().UnixTimestampMillis,
                        Level=tostring(messageType),Text=msg:sub(1,400)},80)
                end
            end)
            teleportConnection=P.OnTeleport:Connect(function()
                persist("Roblox teleport transition")
            end)
            local ok,err=pcall(makeSample)
            if not ok then
                api.SampleFailures+=1;api.Failures+=1
                api.LastSampleError=tostring(err)
                api.LastError="First sample: "..tostring(err)
                event("SampleError",{Error=tostring(err),Attempts=api.SampleFailures})
            end
            persist("Capture enabled")
        else
            event("RecorderStopped",{Samples=api.Samples,Alerts=api.Alerts})
            if heartbeat then heartbeat:Disconnect();heartbeat=nil end
            if logConnection then logConnection:Disconnect();logConnection=nil end
            if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
            api.Enabled=false
            persist("Capture disabled / final snapshot")
        end
    end
    function api.Unload()
        if api.Enabled then api.SetEnabled(false)end
        api.Running=false
    end
    task.spawn(function()
        while api.Running do
            if api.Enabled and not writerBusy
                and os.clock()-saveAt>=api.SaveInterval then
                persist("Opt-in periodic snapshot")
            end
            task.wait(.20)
        end
    end)
    return api
end
local MovementDiagnostics=createClientMovementDiagnostics()

-- On-demand inventory of replicated/native client objects. It neither invokes
-- remotes nor hooks their traffic and cannot read private server-side checks.
local function createAntiCheatRemoteInventory()
    local RS=game:GetService("ReplicatedStorage")
    local RF=game:GetService("ReplicatedFirst")
    local P=game:GetService("Players").LocalPlayer
    local H=game:GetService("HttpService")
    local CS=game:GetService("CollectionService")
    local filename="Geode/anticheat_remote_inventory.json"
    local api={Status="Not exported",Path=filename,Exports=0,
        RemoteCount=0,ScriptCount=0,CandidateCount=0,Scanned=0}
    local keywords={"anticheat","anti-cheat","anti","cheat","guard",
        "security","validate","validation","integrity","watchdog",
        "movement","velocity","speed","teleport","position","physics",
        "noclip","fly","kick","exploit","sanity","desync","report",
        "monitor","clientwatch","heartbeat"}
    local attributeKeys={"role","phase","mode","run","state","lock",
        "walkspeed","speed","velocity","move","teleport","flight",
        "hover","kick","restrict","security","guard","validate"}
    local function shortPath(instance)
        local ok,value=pcall(function()return instance:GetFullName()end)
        return ok and tostring(value):sub(1,320)or tostring(instance.Name)
    end
    local function hits(text,terms)
        local lower=tostring(text or ""):lower()
        local found={}
        for _,term in ipairs(terms)do
            if lower:find(term,1,true)then found[#found+1]=term end
        end
        return found
    end
    local function valueForJson(value)
        local kind=typeof(value)
        if kind=="boolean"or kind=="number"then
            if kind=="number" and (value~=value or value==math.huge or value==-math.huge)then
                return tostring(value)
            end
            return value
        end
        if kind=="string"then return value:sub(1,150)end
        if kind=="Vector3"or kind=="Vector2"or kind=="CFrame"
            or kind=="EnumItem"then return tostring(value)end
        return "["..kind.."]"
    end
    local function safeAttributes(instance)
        if not instance then return nil end
        local ok,attrs=pcall(function()return instance:GetAttributes()end)
        if not ok then return {Error=tostring(attrs)}end
        local selected,matched={},0
        for key,value in pairs(attrs)do
            if #hits(key,attributeKeys)>0 then
                selected[tostring(key)]=valueForJson(value)
                matched+=1
                if matched>=60 then break end
            end
        end
        return selected
    end
    local function item(instance,source)
        local entry={
            Name=instance.Name,Class=instance.ClassName,
            Path=shortPath(instance),Source=source,
            Parent=instance.Parent and shortPath(instance.Parent)or nil
        }
        local matched=hits(entry.Name.." "..entry.Path,keywords)
        if #matched>0 then
            entry.CandidateKeywords=matched
            local ok,tags=pcall(function()return CS:GetTags(instance)end)
            if ok and #tags>0 then entry.CollectionTags=tags end
        end
        return entry,#matched>0
    end
    local function isRemote(instance)
        return instance:IsA("RemoteEvent")or instance:IsA("RemoteFunction")
            or instance:IsA("UnreliableRemoteEvent")
    end
    local function isLocalSignal(instance)
        return instance:IsA("BindableEvent")or instance:IsA("BindableFunction")
    end
    local function isScript(instance)
        return instance:IsA("ModuleScript")or instance:IsA("LocalScript")
            or instance:IsA("Script")
    end
    function api.Export()
        api.Status="Scanning client-visible objects (read-only)"
        local ok,result=pcall(function()
            local remoteEntries,scriptEntries,signals,candidates={},{},{},{}
            local roots={}
            local function addRoot(instance,name,maxCount)
                if instance then
                    roots[#roots+1]={Object=instance,Name=name,MaxCount=maxCount}
                end
            end
            addRoot(RS,"ReplicatedStorage",7500)
            addRoot(RF,"ReplicatedFirst",2000)
            addRoot(P:FindFirstChild("PlayerScripts"),"LocalPlayer.PlayerScripts",3500)
            addRoot(P:FindFirstChild("PlayerGui"),"LocalPlayer.PlayerGui",2000)
            addRoot(P.Character,"LocalPlayer.Character",1200)
            addRoot(workspace,"Workspace (limited scan)",5000)
            local totalScanned=0
            local maxAll=17000
            local scanResults={}
            for _,scan in ipairs(roots)do
                local queue={scan.Object}
                local cursor,tail=1,1
                local seen=0
                local foundRemotes,foundScripts=0,0
                while cursor<=tail and seen<scan.MaxCount
                    and totalScanned<maxAll do
                    local obj=queue[cursor]
                    queue[cursor]=nil
                    cursor+=1;seen+=1;totalScanned+=1
                    local remote=isRemote(obj)
                    local signal=isLocalSignal(obj)
                    local script=isScript(obj)
                    if remote or script or signal then
                        local entry,matched=item(obj,scan.Name)
                        local kept=false
                        if remote and #remoteEntries<800 then
                            remoteEntries[#remoteEntries+1]=entry
                            foundRemotes+=1;kept=true
                        elseif script and #scriptEntries<1000 then
                            scriptEntries[#scriptEntries+1]=entry
                            foundScripts+=1;kept=true
                        elseif signal and #signals<350 then
                            signals[#signals+1]=entry;kept=true
                        end
                        if kept and matched and #candidates<260 then
                            local kind=remote and "Remote"or script and "Script/Module"or "Bindable"
                            candidates[#candidates+1]={Kind=kind,
                                Name=entry.Name,Class=entry.Class,Path=entry.Path,
                                KeywordMatches=entry.CandidateKeywords}
                        end
                    end
                    local childOK,children=pcall(function()return obj:GetChildren()end)
                    if childOK and type(children)=="table"then
                        for _,child in ipairs(children)do
                            tail+=1
                            queue[tail]=child
                        end
                    end
                end
                scanResults[#scanResults+1]={Root=scan.Name,Scanned=seen,
                    RemotesFound=foundRemotes,ScriptsFound=foundScripts,
                    Truncated=cursor<=tail,
                    Limit=scan.MaxCount}
            end
            table.sort(remoteEntries,function(a,b)return a.Path<b.Path end)
            table.sort(scriptEntries,function(a,b)return a.Path<b.Path end)
            table.sort(signals,function(a,b)return a.Path<b.Path end)
            table.sort(candidates,function(a,b)return a.Path<b.Path end)
            local mtg=RS:FindFirstChild("MTG")
            local char=P.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local cave=workspace:FindFirstChild("CaveMap")
            local snapshot={
                Version=1,HubVersion=geodeVersion,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                GameId=game.GameId,PlaceId=game.PlaceId,
                Scope="Client-visible replicated instances only; read-only metadata",
                ServerAntiCheatSourceAvailable=false,
                PrivateServerLogsAvailable=false,
                LiveRemoteTrafficIntercepted=false,
                RemoteMethodsInvoked=false,
                Warning="Candidate terms are name/path matches, not evidence of anti-cheat function. Security checks may exist only on the server or in scripts with unrelated names.",
                CollectionLimits={
                    MaxVisitedInstances=maxAll,MaxRemotes=800,
                    MaxScriptEntries=1000,MaxBindables=350,
                    MaxCandidates=260
                },
                ScannedObjects=totalScanned,ScanResults=scanResults,
                Counts={Remotes=#remoteEntries,ClientScriptsAndModules=#scriptEntries,
                    Bindables=#signals,NameMatchedCandidates=#candidates},
                AllVisibleRemotes=remoteEntries,
                ClientScriptsAndModules=scriptEntries,
                LocalBindables=signals,
                PossibleMovementOrSecurityCandidates=candidates,
                RelevantLocalAttributes={
                    MTG=safeAttributes(mtg),
                    LocalPlayer=safeAttributes(P),
                    Character=safeAttributes(char),
                    Humanoid=safeAttributes(hum),
                    HumanoidRootPart=safeAttributes(root),
                    CaveMap=safeAttributes(cave),
                    Workspace=safeAttributes(workspace)
                },
                LiveClientMovement={
                    NativeWalkSpeed=hum and hum.WalkSpeed or nil,
                    RootVelocity=root and tostring(root.AssemblyLinearVelocity)or nil,
                    RootPosition=root and tostring(root.Position)or nil,
                    FlyEnabled=Endless.Enabled,FlySpeed=Endless.FlySpeed,
                    FlyActualSpeed=Endless.FlyActualSpeed,
                    FlightMode=Endless.OrbitFlightMode,
                    FarmSafetyStopped=FarmSafety.Stopped,
                    MovementRecorderEnabled=MovementDiagnostics.Enabled
                },
                Note="Only records names, classes, paths and selected local attributes. Does not inspect script bytecode, decompile private code, hook remotes, scan other players, or attempt to evade detection."
            }
            if not isfolder("Geode")then makefolder("Geode")end
            writefile(filename,H:JSONEncode(snapshot))
            api.RemoteCount=#remoteEntries
            api.ScriptCount=#scriptEntries
            api.CandidateCount=#candidates
            api.Scanned=totalScanned
            api.Exports+=1
            api.Status=string.format("Saved %d remotes, %d scripts, %d name-matched candidates",
                api.RemoteCount,api.ScriptCount,api.CandidateCount)
            return filename
        end)
        if not ok then
            api.Status="Inventory export failed: "..tostring(result)
            return false,tostring(result)
        end
        return true,result
    end
    return api
end
local AntiCheatInventory=createAntiCheatRemoteInventory()

-- User-requested on-demand Dev Menu investigator. Only reads local
-- replicated client objects; never activates GUIs, calls DevAction,
-- changes permissions, or opens any restricted menus.
local function createDevMenuInspector()
    local Players=game:GetService("Players")
    local P=Players.LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local H=game:GetService("HttpService")
    local CAS=game:GetService("ContextActionService")
    local api={Status="Not captured",Exports=0,LastPath=nil,
        CandidateModules=0,VisibleControls=0,MatchedSourceFiles=0,
        LastError=nil}
    local outputPath="Geode/dev_menu_diagnostics.json"
    local words={"devmenu","dev_menu","dev menu","devwidget","devtool",
        "developer","admin","moderator","staff","debug","watchrun",
        "freecam","spectat","command","live run","liverun","live_runs",
        "runwatch","gmtool","gmcommand"}
    local codeWords={"devmenu","dev_menu","dev menu","devwidget","devtool",
        "developer","admin","moderator","staff","freecam",
        "watchrun","devaction","liveruns","live_runs",
        "contextactionservice","keycode","command"}
    local secrets={"userid","user_id","username","password","token",
        "secret","apikey","api_key","cookie","authorization",
        "whitelist","allowlist","membership","permitted",
        "ownerid","groupid","adminids","staffids","devids",
        "userlist","banlist","authorized","superusers"}
    local function sensitive(value)
        local str=tostring(value or ""):lower()
        for _,term in ipairs(secrets)do
            if str:find(term,1,true)then return true end
        end
        return false
    end
    local function cleanText(value)
        local str=tostring(value or "")
        if sensitive(str)then return "[redacted: identity / permission / credential]"end
        str=str:gsub("https?://%S+","[url]")
            :gsub("%d%d%d%d%d%d%d%d+","[numeric-id]")
        return str:sub(1,200)
    end
    local function matches(value,terms)
        local lower=tostring(value or ""):lower()
        local match={}
        for _,word in ipairs(terms or words)do
            if lower:find(word,1,true)then match[#match+1]=word end
        end
        return match
    end
    local function path(instance)
        local ok,result=pcall(function()return instance:GetFullName()end)
        return cleanText((ok and tostring(result)or instance.Name)
            :gsub(P.Name,"LocalPlayer"))
    end
    local function attrs(instance)
        local out={}
        if not instance then return out end
        local ok,items=pcall(function()return instance:GetAttributes()end)
        if not ok then return out end
        for name,value in pairs(items)do
            if not sensitive(name)
                and (#matches(name)>0 or name=="Role"or name=="Phase"
                    or name=="Mode"or name=="DevLocked"or name=="Spectator")then
                local typ=typeof(value)
                if typ=="boolean"or typ=="number"then
                    out[name]=value
                elseif typ=="string"then
                    out[name]=cleanText(value)
                end
            end
        end
        return out
    end
    local function isModule(obj)
        return obj:IsA("ModuleScript")or obj:IsA("LocalScript")
            or obj:IsA("Script")
    end
    local function guiText(obj)
        if obj:IsA("TextLabel")or obj:IsA("TextButton")
            or obj:IsA("TextBox")then return cleanText(obj.Text)end
        return nil
    end
    local function isEffectiveVisible(obj)
        local visible=true
        local curr=obj
        while curr and curr~=game do
            if curr:IsA("ScreenGui") and not curr.Enabled then
                visible=false;break
            elseif curr:IsA("GuiObject") and not curr.Visible then
                visible=false;break end
            curr=curr.Parent
        end
        return visible
    end
    local function guiRow(obj,reason)
        local row={Name=cleanText(obj.Name),Class=obj.ClassName,
            Path=path(obj),Match=reason,
            EffectiveVisible=isEffectiveVisible(obj)}
        if obj:IsA("ScreenGui") then row.Enabled=obj.Enabled end
        if obj:IsA("GuiObject")then
            row.Visible=obj.Visible
            row.Active=obj.Active
            if obj:IsA("GuiButton")then row.Interactable=obj.Interactable end
        end
        local txt=guiText(obj)
        if txt and txt~=""then row.Text=txt end
        return row
    end
    function api.Export()
        api.Status="Inspecting developer menu objects (read-only)"
        local ok,result=pcall(function()
            assert(type(writefile)=="function","File writing unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local mtg=RS:FindFirstChild("MTG")
            local clientScripts=P:FindFirstChild("PlayerScripts")
            local mtgClient=clientScripts and clientScripts:FindFirstChild("MTGClient")
            local config=mtg and mtg:FindFirstChild("Config")
            local remoteRoot=mtg and mtg:FindFirstChild("Remotes")
            local report={
                Version=1,HubVersion=geodeVersion,AtMs=DateTime.now().UnixTimestampMillis,
                GameId=game.GameId,PlaceId=game.PlaceId,ReadOnly=true,
                DevActionsCalled=0,PermissionChanges=0,MenuVisibilityChanges=0,
                CameraChanges=0,RemoteTrafficHooked=false,
                Note="Read-only client-visible Dev Menu inspection. No privileges are implied by a visible menu or remote name. Server permissions, security checks and private code cannot be retrieved.",
                LocalState={
                    MTG=attrs(mtg),LocalPlayer=attrs(P),
                    MTGState=attrs(mtg and mtg:FindFirstChild("State")),
                    StudioMode=cleanText(workspace:GetAttribute("StudioMode")or""),
                    StudioRole=cleanText(workspace:GetAttribute("StudioRole")or""),
                    LocalSpectator=P:GetAttribute("Spectator")==true,
                    HasSpectateTarget=P:GetAttribute("SpectateTarget")~=nil
                },
                DevAction={
                    Exists=remoteRoot and remoteRoot:FindFirstChild("DevAction")~=nil or false
                },
                MenuCandidates={},GuiControls={},Actions={},RemoteCandidates={},
                ScriptCandidates={},SourceMatches={},ScanResults={},
                Limitations={
                    MenuRoots=6,MaxInstancesPerRoot=9000,
                    MaxAllGuiControls=320,MaxModuleEntries=220,
                    MaxRelatedRemotes=90,MaxSourceModules=24,
                    MaxSourceLinesPerModule=28,
                    DoesNotInspectServer=true
                }
            }
            local devRemote=remoteRoot and remoteRoot:FindFirstChild("DevAction")
            if devRemote then
                report.DevAction.Class=devRemote.ClassName
                report.DevAction.Path=path(devRemote)
            end
            local roots={
                {Name="PlayerGui",Object=P:FindFirstChild("PlayerGui"),Max=9000},
                {Name="PlayerScripts",Object=clientScripts,Max=3500},
                {Name="ReplicatedStorage.MTG",Object=mtg,Max=4000},
                {Name="ReplicatedFirst",Object=game:GetService("ReplicatedFirst"),Max=1000},
                {Name="StarterGui",Object=game:GetService("StarterGui"),Max=3500},
                {Name="LocalCharacter",Object=P.Character,Max=1200}
            }
            local candidates={}
            local seenModule={}
            local controlSeen={}
            local function addCandidate(obj,source)
                if seenModule[obj] or #report.ScriptCandidates>=220 then return end
                seenModule[obj]=true
                local row={Name=cleanText(obj.Name),Class=obj.ClassName,
                    Path=path(obj),Source=source}
                local terms=matches(obj.Name.." "..row.Path)
                row.Match=terms
                report.ScriptCandidates[#report.ScriptCandidates+1]=row
                candidates[#candidates+1]={Object=obj,Info=row,Score=#terms}
            end
            local function addGui(obj,rootName,related)
                if controlSeen[obj] or #report.GuiControls>=320 then return end
                controlSeen[obj]=true
                local text=guiText(obj)or""
                local terms=matches(obj.Name.." "..text.." "..path(obj))
                local row=guiRow(obj,terms)
                row.Root=rootName
                row.BecauseAncestorMatched=related
                report.GuiControls[#report.GuiControls+1]=row
            end
            for _,root in ipairs(roots)do
                if root.Object then
                    local queue={root.Object}
                    local first,last=1,1
                    local count=0
                    while first<=last and count<root.Max do
                        local obj=queue[first]
                        queue[first]=nil
                        first+=1;count+=1
                        local objName=obj.Name
                        local isMenu=obj:IsA("ScreenGui")
                            or (obj:IsA("GuiObject")
                                and (obj:IsA("Frame") or obj:IsA("ScrollingFrame")))
                        local nameHit=#matches(objName)>0
                        local isGui=obj:IsA("GuiObject")or obj:IsA("ScreenGui")
                        if isGui and (root.Name=="PlayerGui"or root.Name=="StarterGui")then
                            local text=guiText(obj)or""
                            local pathHit=#matches(path(obj))>0
                            local parentHit=obj.Parent and #matches(obj.Parent.Name)>0
                            if isMenu and (nameHit or pathHit)then
                                if #report.MenuCandidates<90 then
                                    report.MenuCandidates[#report.MenuCandidates+1]=guiRow(obj,"Name or ancestor")
                                end
                            end
                            if (nameHit or #matches(text)>0 or pathHit or parentHit)
                                and (obj:IsA("GuiButton")or obj:IsA("TextLabel")
                                    or obj:IsA("TextBox")or obj:IsA("Frame")
                                    or obj:IsA("ScrollingFrame")or obj:IsA("ScreenGui"))then
                                addGui(obj,root.Name,pathHit or parentHit)
                            end
                        end
                        if isModule(obj) then
                            local pth=path(obj)
                            if #matches(objName.." "..pth)>0 then
                                addCandidate(obj,root.Name)
                            end
                        elseif obj:IsA("RemoteEvent")
                            or obj:IsA("RemoteFunction")
                            or obj:IsA("UnreliableRemoteEvent")then
                            if #matches(objName)>0 and #report.RemoteCandidates<90 then
                                report.RemoteCandidates[#report.RemoteCandidates+1]={
                                    Name=cleanText(objName),Class=obj.ClassName,
                                    Path=path(obj),Attributes=attrs(obj)}
                            end
                        end
                        local childOk,children=pcall(function()return obj:GetChildren()end)
                        if childOk then
                            for _,child in ipairs(children)do
                                last+=1;queue[last]=child
                            end
                        end
                    end
                    report.ScanResults[#report.ScanResults+1]={
                        Root=root.Name,Visited=count,Limit=root.Max,
                        Truncated=first<=last
                    }
                else
                    report.ScanResults[#report.ScanResults+1]={
                        Root=root.Name,Missing=true
                    }
                end
            end
            -- Ensure known menu/spectator client modules are checked even
            -- when their names do not contain one of our search terms.
            for _,name in ipairs({"DevWidgets","DevTools","WatchRun",
                "Admin","AdminReveal"})do
                local mod=mtgClient and mtgClient:FindFirstChild(name)
                    or config and config:FindFirstChild(name)
                if mod and isModule(mod)then
                    addCandidate(mod,"Known native developer module")
                end
            end
            local gotActions,actions=pcall(function()
                return CAS:GetAllBoundActionInfo()
            end)
            if gotActions and type(actions)=="table"then
                for name,info in pairs(actions)do
                    local title=type(info)=="table"and info.title or""
                    if (#matches(name.." "..tostring(title))>0)
                        and #report.Actions<100 then
                        report.Actions[#report.Actions+1]={
                            Name=cleanText(name),Title=cleanText(title),
                            Priority=tonumber(info.priorityLevel)}
                    end
                end
            end
            table.sort(candidates,function(a,b)
                if a.Score==b.Score then return a.Info.Path<b.Info.Path end
                return a.Score>b.Score
            end)
            report.SourceDecompilerAvailable=type(decompile)=="function"
            local maxCode=math.min(#candidates,24)
            if type(decompile)=="function"then
                for i=1,maxCode do
                    local candidate=candidates[i]
                    local mod=candidate.Object
                    local good,code=pcall(decompile,mod)
                    local entry={Name=candidate.Info.Name,Path=candidate.Info.Path,
                        DecompilationSucceeded=good and type(code)=="string"}
                    if entry.DecompilationSucceeded then
                        entry.TotalBytes=#code
                        local lineno=0
                        local matched=0
                        local matchRows={}
                        for line in (code.."\n"):gmatch("(.-)\n")do
                            lineno+=1
                            local found=matches(line,codeWords)
                            if #found>0 then
                                matched+=1
                                if #matchRows<28 then
                                    matchRows[#matchRows+1]={
                                        Line=lineno,Terms=found,
                                        Excerpt=cleanText(line)}
                                end
                            end
                        end
                        entry.TotalMatches=matched
                        entry.Excerpts=matchRows
                    else
                        entry.Error="Decompiler unavailable for this client module"
                    end
                    report.SourceMatches[#report.SourceMatches+1]=entry
                    if i%5==0 then task.wait()end
                end
            end
            report.Counts={
                Menus=#report.MenuCandidates,GuiControls=#report.GuiControls,
                RelatedScripts=#report.ScriptCandidates,
                RelatedRemotes=#report.RemoteCandidates,
                MatchedSourceModules=#report.SourceMatches,
                BoundActions=#report.Actions
            }
            api.CandidateModules=#report.ScriptCandidates
            api.VisibleControls=#report.GuiControls
            api.MatchedSourceFiles=#report.SourceMatches
            writefile(outputPath,H:JSONEncode(report))
            api.Exports+=1
            api.LastPath=outputPath
            api.Status=string.format("Saved dev menu dump: %d menus, %d controls, %d scripts",
                report.Counts.Menus,report.Counts.GuiControls,
                report.Counts.RelatedScripts)
            return outputPath
        end)
        if not ok then
            api.LastError=tostring(result)
            api.Status="Dev menu export error: "..tostring(result)
            return false,tostring(result)
        end
        api.LastError=nil
        return true,result
    end
    return api
end
local DevMenuInspector=createDevMenuInspector()

-- Manual native DevWidgets structure export. This analyzes client-visible
-- local UI wiring without executing developer modules, changing access
-- flags, opening menus, invoking DevAction or exposing credentials.
local function createDevWidgetsStructureInspector()
    local P=game:GetService("Players").LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local H=game:GetService("HttpService")
    local api={Status="Not captured",LastPath=nil,LastError=nil,
        Exports=0,AnalyzedModules=0,Matches=0}
    local filename="Geode/dev_widgets_diagnostics.json"
    local categories={
        UIConstruction={"instance.new","screengui","frame","textbutton",
            "textlabel","textbox","uicorner","uilistlayout",
            "createwindow","createbutton","makebutton","createelement",
            "createpanel","createtab","addbutton","settext","section"},
        InputAndHotkeys={"inputbegan","inputended","userinputservice",
            "contextactionservice","bindaction","keycode","buttonselect",
            "mousebutton1click","activated","f2","f3"},
        MenuLifecycle={"init","initialize","start","mount","open",
            "close","show","hide","visible","enabled","destroy",
            "toggle","render","update","connect","function"},
        ServerInteraction={"devaction","invokeserver","fireserver",
            "onclientevent","onclientinvoke","remoteevent","remotefunction"},
        PermissionOrCredentialReference={"access","permission","authorized",
            "authorize","staff","admin","role","rank","whitelist",
            "allowlist","password","passcode","secret","token","userid",
            "owner","developer","devlocked"}
    }
    local sensitiveWords={"password","passcode","secret","token",
        "credential","apikey","api_key","cookie","privatekey",
        "authorization","authheader","userid","username","ownerid",
        "adminids","staffids","devids","whitelist","allowlist",
        "banlist","authorizedusers","memberships","groupid","webhook"}
    local maxExcerpt=150
    local function hasAny(text,words)
        local low=tostring(text or ""):lower()
        for _,term in ipairs(words)do
            if low:find(term,1,true)then return true end
        end
        return false
    end
    local function safePreview(line)
        local trimmed=tostring(line or ""):gsub("^%s+",""):gsub("%s+$","")
        if #trimmed==0 then return nil end
        if hasAny(trimmed,sensitiveWords)then
            return "[redacted: credential, account or membership reference]"
        end
        -- Access checks and native developer remote wiring are summarized
        -- as counts/line numbers; never export callable command arguments.
        if hasAny(trimmed,{"devaction","invokeserver","fireserver",
            "onclientinvoke","require(","getfenv","loadstring"})then
            return "[redacted: native remote/module invocation]"
        end
        trimmed=trimmed:gsub("https?://%S+","[url]")
            :gsub("%d%d%d%d%d%d%d%d+","[numeric-id]")
        return trimmed:sub(1,maxExcerpt)
    end
    local function fullPath(obj)
        local ok,res=pcall(function()return obj:GetFullName()end)
        return (ok and tostring(res)or tostring(obj.Name))
            :gsub(P.Name,"LocalPlayer"):sub(1,220)
    end
    local function inspectModule(obj)
        local row={Name=obj and obj.Name or "Unavailable",
            Found=obj~=nil,Class=obj and obj.ClassName or nil,
            Path=obj and fullPath(obj)or nil,
            DecompilerAvailable=type(decompile)=="function",
            DecompilationSucceeded=false,
            CategoryCounts={},CategoryLines={},Preview={},
            SourceBytes=0,TotalLines=0,Truncated=false}
        if not obj or not obj:IsA("ModuleScript")then
            row.Reason="Client ModuleScript not replicated in this session"
            return row
        end
        if type(decompile)~="function"then
            row.Reason="Executor does not expose decompile"
            return row
        end
        local ok,code=pcall(decompile,obj)
        if not ok or type(code)~="string"or #code==0 then
            row.Reason="Decompiler returned no readable source"
            return row
        end
        row.DecompilationSucceeded=true;row.SourceBytes=#code
        if #code>140000 then
            code=code:sub(1,140000)
            row.Truncated=true
        end
        local totalPreview=0
        for line in (code.."\n"):gmatch("(.-)\n")do
            row.TotalLines+=1
            if row.TotalLines>3500 then row.Truncated=true;break end
            local low=line:lower()
            local matched={}
            for name,terms in pairs(categories)do
                if hasAny(low,terms)then
                    row.CategoryCounts[name]=(row.CategoryCounts[name]or 0)+1
                    local nums=row.CategoryLines[name]or{}
                    if #nums<40 then nums[#nums+1]=row.TotalLines end
                    row.CategoryLines[name]=nums
                    matched[#matched+1]=name
                end
            end
            if #matched>0 and totalPreview<110 then
                -- Preserve a small, redacted syntactic excerpt showing UI
                -- structure; do not publish raw passwords or command payloads.
                local excerpt=safePreview(line)
                if excerpt then
                    row.Preview[#row.Preview+1]={
                        Line=row.TotalLines,
                        Categories=matched,Excerpt=excerpt
                    }
                    totalPreview+=1
                end
            end
        end
        return row
    end
    local function summarizeUI()
        local gui=P:FindFirstChild("PlayerGui")
        local result={Scanned=0,Truncated=false,
            RelevantPanels={},RelevantControls={}}
        if not gui then return result end
        local queue={gui};local index,tail=1,1
        while index<=tail and result.Scanned<14000 do
            local obj=queue[index]
            queue[index]=nil;index+=1;result.Scanned+=1
            if obj:IsA("GuiObject")or obj:IsA("ScreenGui")then
                local name=obj.Name:lower()
                local significant=hasAny(name,{"dev","admin","debug",
                    "staff","spectat","command"})
                if significant then
                    local visible=true
                    local cursor=obj
                    while cursor and cursor~=game do
                        if cursor:IsA("ScreenGui")and not cursor.Enabled then
                            visible=false;break
                        end
                        if cursor:IsA("GuiObject")and not cursor.Visible then
                            visible=false;break
                        end
                        cursor=cursor.Parent
                    end
                    local entry={
                        Name=obj.Name,Class=obj.ClassName,
                        Path=fullPath(obj),EffectiveVisible=visible
                    }
                    if obj:IsA("ScreenGui")and #result.RelevantPanels<80 then
                        result.RelevantPanels[#result.RelevantPanels+1]=entry
                    elseif #result.RelevantControls<120 then
                        if obj:IsA("TextButton")or obj:IsA("TextLabel")then
                            entry.Label=safePreview(obj.Text)
                        end
                        result.RelevantControls[#result.RelevantControls+1]=entry
                    end
                end
            end
            local ok,children=pcall(function()return obj:GetChildren()end)
            if ok and type(children)=="table"then
                for _,child in ipairs(children)do
                    tail+=1;queue[tail]=child
                end
            end
        end
        result.Truncated=index<=tail
        return result
    end
    function api.Export()
        api.Status="Inspecting DevWidgets structure (read only)"
        local success,result=pcall(function()
            assert(type(writefile)=="function","Executor writefile unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local scripts=P:FindFirstChild("PlayerScripts")
            local client=scripts and scripts:FindFirstChild("MTGClient")
            local mtg=RS:FindFirstChild("MTG")
            local config=mtg and mtg:FindFirstChild("Config")
            local remotes=mtg and mtg:FindFirstChild("Remotes")
            local modules={}
            for _,name in ipairs({"DevWidgets","DevTools","WatchRun"})do
                local obj=client and client:FindFirstChild(name)
                modules[#modules+1]=inspectModule(obj)
            end
            -- Config Admin only provides context, and is never required.
            -- Scan metadata, not full config or membership/password lists.
            local admin=config and config:FindFirstChild("Admin")
            local action=remotes and remotes:FindFirstChild("DevAction")
            local gui=summarizeUI()
            local report={
                Version=1,HubVersion=geodeVersion,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                GameId=game.GameId,PlaceId=game.PlaceId,
                Source="Read-only native client structure, targeted decompiler excerpts",
                ClientSourcesExecuted=false,DeveloperCommandsInvoked=false,
                ChangedPrivileges=false,ChangedMenuVisibility=false,
                AccessGrantedOrVerified=false,
                Note="Source excerpts show only sanitized UI structure and control-flow clues. Permission/credential references and developer remote invocations are redacted. No server-only Dev Menu code, password, or authorization verdict is accessible.",
                KeybindingHints={ReportedByPreviousConfigDump={"F2","F3","ButtonSelect"},
                    HintsAreNotProofOfUsablePrivileges=true},
                KnownRelatedObjects={
                    ConfigAdminPresent=admin~=nil,
                    ConfigAdminPath=admin and fullPath(admin)or nil,
                    DevActionPresent=action~=nil,
                    DevActionClass=action and action.ClassName or nil,
                    DevActionPath=action and fullPath(action)or nil,
                    NativeClientPresent=client~=nil
                },
                NativeClientModules=modules,
                LocalDevUI=gui,
                Limits={MaxDecompiledBytesPerModule=140000,
                    MaxDecompiledLinesPerModule=3500,
                    MaxExcerptsPerModule=110,
                    MaxExcerptCharacters=maxExcerpt,
                    GuiScanLimit=14000},
                Interpretation="UI construction/hotkey lines alone cannot establish the ability to open a developer menu. A missing DevTools module is reported as unavailable rather than created. All remote and authorization actions remain untouched."
            }
            writefile(filename,H:JSONEncode(report))
            local analyzed,matched=0,0
            for _,row in ipairs(modules)do
                if row.DecompilationSucceeded then analyzed+=1 end
                matched+=#row.Preview
            end
            api.AnalyzedModules=analyzed
            api.Matches=matched
            api.Exports+=1
            api.LastPath=filename
            api.Status=string.format("Saved DevWidgets report: %d module(s), %d excerpts, GUI scanned %d",
                analyzed,matched,gui.Scanned)
            return filename
        end)
        if not success then
            api.LastError=tostring(result)
            api.Status="DevWidgets export failed: "..api.LastError
            return false,api.LastError
        end
        api.LastError=nil
        return true,result
    end
    return api
end
local DevWidgetsStructureInspector=createDevWidgetsStructureInspector()

-- Read-only discovery of native client modules that reference DevWidgets,
-- bind the admin-config F2 shortcut, or build developer UI. Does not run any
-- inspected module, use DevAction, infer password values or change privileges.
local function createDevMenuControllerDiscovery()
    local P=game:GetService("Players").LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local RF=game:GetService("ReplicatedFirst")
    local Http=game:GetService("HttpService")
    local CAS=game:GetService("ContextActionService")
    local path="Geode/dev_menu_controller_diagnostics.json"
    local api={Status="Not captured",LastPath=nil,LastError=nil,
        Scanned=0,Decompiled=0,Failed=0,ControllerCandidates=0,Exports=0}
    local patterns={
        DevWidgetsReference={"devwidgets","dev_widgets"},
        F2Binding={"enum.keycode.f2","keycode.f2","enum.keycode.buttonselect",
            "gamepadkey","photokey"},
        InputRegistration={"inputbegan","inputended","bindaction",
            "userinputservice","contextactionservice"},
        DevMenuConstruction={"devsection","dev menu","devmenu","dev_menu",
            "devpanel","devwidget","screenGui","uibuilder"},
        UIConstruction={"instance.new(\"screengui\"","uikit.frame",
            "uikit.button","uikit.section","uikit.input","uibutton",
            "createwindow","createbutton","buildmenu","createmenu"},
        DevActionReference={"devaction"},
        AccessReference={"whitelist","allowlist","adminids","staffids",
            "permission","authorized","password","passcode","token",
            "secret","authcheck","devlocked"}
    }
    local sensitive={"password","passcode","token","secret","credential",
        "userid","username","ownerid","adminids","staffids","devids",
        "whitelist","allowlist","authorization","authorized",
        "permission","membership","devaction","invokeserver","fireserver",
        "apikey","api_key","privatekey","cookie","webhook"}
    local function hits(text,terms)
        local low=tostring(text or ""):lower()
        for _,word in ipairs(terms)do
            if low:find(word:lower(),1,true)then return true end
        end
        return false
    end
    local function stripPath(inst)
        local ok,result=pcall(function()return inst:GetFullName()end)
        local value=ok and tostring(result)or tostring(inst.Name)
        return value:gsub(P.Name,"LocalPlayer"):sub(1,240)
    end
    local function safeExcerpt(text)
        local str=tostring(text or "")
        if hits(str,sensitive)or hits(str,{"loadstring","getfenv",
            "getconstants","decompile","debug.getupvalue"})then
            return "[redacted: authentication/command or sensitive reference]"
        end
        str=str:gsub("%d%d%d%d%d%d%d%d+","[numeric-id]")
            :gsub("https?://%S+","[url]")
            :gsub("^%s+","")
        return str:sub(1,170)
    end
    local function inspect(obj,origin)
        local row={Name=obj.Name,Class=obj.ClassName,Path=stripPath(obj),
            Origin=origin,SourceBytes=0,Lines=0,Truncated=false,
            Decompiled=false,Categories={},LineNumbers={},UiExcerpts={}}
        if type(decompile)~="function"then
            row.Error="No client decompiler exposed"
            return row
        end
        local ok,source=pcall(decompile,obj)
        if not ok or type(source)~="string"or #source==0 then
            row.Error="Client source could not be decompiled"
            return row
        end
        row.Decompiled=true;row.SourceBytes=#source
        if #source>160000 then
            source=source:sub(1,160000)
            row.Truncated=true
        end
        for line in (source.."\n"):gmatch("(.-)\n")do
            row.Lines+=1
            if row.Lines>4000 then row.Truncated=true;break end
            local foundUi=false
            for category,terms in pairs(patterns)do
                if hits(line,terms)then
                    row.Categories[category]=(row.Categories[category]or 0)+1
                    local numbers=row.LineNumbers[category]or{}
                    if #numbers<32 then numbers[#numbers+1]=row.Lines end
                    row.LineNumbers[category]=numbers
                    if category=="UIConstruction"or category=="DevMenuConstruction"
                        or category=="InputRegistration"or category=="F2Binding"
                        or category=="DevWidgetsReference"then
                        foundUi=true
                    end
                end
            end
            if foundUi and #row.UiExcerpts<16 then
                -- UI-only structure; credential/permission and developer
                -- remote call lines are replaced, never saved as source.
                row.UiExcerpts[#row.UiExcerpts+1]={
                    Line=row.Lines,Text=safeExcerpt(line)}
            end
        end
        local c=row.Categories
        row.ToolboxOnly=obj.Name=="DevWidgets"
        row.Score=(c.DevWidgetsReference or 0)*12
            +(c.F2Binding or 0)*10
            +(c.DevActionReference or 0)*7
            +(c.DevMenuConstruction or 0)*4
            +(c.InputRegistration or 0)*2
            +(c.UIConstruction or 0)
        if row.ToolboxOnly then row.Score=0 end
        return row
    end
    function api.Export()
        api.Status="Finding DevWidgets dependencies and menu controller (read-only)"
        local ok,result=pcall(function()
            assert(type(writefile)=="function","File writing unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local playerScripts=P:FindFirstChild("PlayerScripts")
            local native=playerScripts and playerScripts:FindFirstChild("MTGClient")
            local mtg=RS:FindFirstChild("MTG")
            local config=mtg and mtg:FindFirstChild("Config")
            local moduleRoot=mtg and mtg:FindFirstChild("Modules")
            local candidates,seen={},{}
            local discovery={}
            local function add(obj,origin)
                if not obj or seen[obj] then return end
                if not (obj:IsA("ModuleScript")or obj:IsA("LocalScript"))then return end
                seen[obj]=true
                candidates[#candidates+1]={Instance=obj,Origin=origin}
            end
            local function scanRoot(root,label,maxObjects,onlyRelated)
                if not root then
                    discovery[#discovery+1]={Root=label,Missing=true}
                    return
                end
                add(root,label)
                local descendants=root:GetDescendants()
                local count=math.min(#descendants,maxObjects)
                for i=1,count do
                    local obj=descendants[i]
                    if not onlyRelated or hits(obj.Name,{
                        "admin","dev","ui","menu","input","client",
                        "camera","watch","run","spectat","tool"})then
                        add(obj,label)
                    end
                end
                discovery[#discovery+1]={Root=label,
                    Visited=count,Available=#descendants,
                    Truncated=#descendants>maxObjects}
            end
            scanRoot(playerScripts,"PlayerScripts",2800,false)
            scanRoot(RF,"ReplicatedFirst",650,false)
            scanRoot(moduleRoot,"Replicated MTG modules (named subset)",1600,true)
            local rows={}
            local attempts=math.min(#candidates,240)
            local succeeded,failures=0,0
            for i=1,attempts do
                local candidate=candidates[i]
                local row=inspect(candidate.Instance,candidate.Origin)
                rows[#rows+1]=row
                if row.Decompiled then succeeded+=1 else failures+=1 end
                if i%5==0 then task.wait()end
            end
            local ranked={}
            local countStrong=0
            local definiteDevWidgets,definiteF2=0,0
            for _,row in ipairs(rows)do
                if row.Decompiled then
                    if (row.Categories.DevWidgetsReference or 0)>0 and
                        not row.ToolboxOnly then definiteDevWidgets+=1 end
                    if (row.Categories.F2Binding or 0)>0 then definiteF2+=1 end
                    if row.Score>0 then
                        countStrong+=1
                        ranked[#ranked+1]=row
                    end
                end
            end
            table.sort(ranked,function(a,b)
                if a.Score==b.Score then return a.Path<b.Path end
                return a.Score>b.Score
            end)
            local top={}
            for i=1,math.min(45,#ranked)do
                top[#top+1]=ranked[i]
            end
            local list={}
            for _,row in ipairs(rows)do
                -- Small complete index helps establish that a missing
                -- controller was actually checked; no raw code emitted.
                list[#list+1]={
                    Name=row.Name,Path=row.Path,
                    Decompiled=row.Decompiled,
                    SourceBytes=row.SourceBytes,
                    HasDevWidgetsReference=(row.Categories.DevWidgetsReference or 0)>0,
                    HasF2Binding=(row.Categories.F2Binding or 0)>0,
                    HasDevActionReference=(row.Categories.DevActionReference or 0)>0,
                    AccessCheckMentions=row.Categories.AccessReference or 0,
                    Score=row.Score or 0,Error=row.Error
                }
            end
            local hotkeys={}
            local actionOk,allActions=pcall(function()
                return CAS:GetAllBoundActionInfo()
            end)
            if actionOk and type(allActions)=="table"then
                for name,info in pairs(allActions)do
                    local label=tostring(name or "")
                    local title=type(info)=="table"and tostring(info.title or "")or""
                    if hits(label.." "..title,{"dev","admin","freecam","spectat","debug"})then
                        hotkeys[#hotkeys+1]={
                            Name=safeExcerpt(label),Title=safeExcerpt(title)}
                        if #hotkeys>=35 then break end
                    end
                end
            end
            local adminModule=config and config:FindFirstChild("Admin")
            local remoteRoot=mtg and mtg:FindFirstChild("Remotes")
            local action=remoteRoot and remoteRoot:FindFirstChild("DevAction")
            local report={
                Version=1,HubVersion=geodeVersion,
                PlaceId=game.PlaceId,GameId=game.GameId,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                Scope="Read-only native client module dependency and hotkey scan",
                SourceModulesExecuted=false,DevActionCalled=false,
                PermissionsChanged=false,MenuVisibilityChanged=false,
                AccessGrantedOrTested=false,
                KeybindingConfigContext={
                    PriorConfigDumpReportsF2=true,
                    PriorConfigDumpReportsF3=true,
                    CurrentConfigAdminPresent=adminModule~=nil,
                    DoesNotReadPasswordOrMembership=true
                },
                NativeMTGClientFound=native~=nil,
                DevWidgetsFound=native and native:FindFirstChild("DevWidgets")~=nil or false,
                DevActionRemotePresent=action~=nil,
                DecompilerAvailable=type(decompile)=="function",
                SourceFolders=discovery,
                Counts={
                    FoundScripts=#candidates,Attempted=attempts,
                    Decompiled=succeeded,Failures=failures,
                    ModulesReferencingDevWidgets=definiteDevWidgets,
                    ModulesWithF2BindingReferences=definiteF2,
                    RankedCandidates=countStrong
                },
                TopLikelyMenuControllers=top,
                CompleteClientSourceIndex=list,
                RelevantBoundActions=hotkeys,
                Limits={
                    MaxDecompilations=240,TopCandidates=45,
                    MaxUiExcerptsPerModule=16,MaxLineReferencesPerCategory=32,
                    MaxSourceBytesPerModule=160000
                },
                Note="Covers client-visible modules, not server-only menu code. Line matches alone cannot prove authentication, admin access or the true controller. Password and permission data and developer remote calls are deliberately omitted."
            }
            writefile(path,Http:JSONEncode(report))
            api.LastPath=path;api.Scanned=attempts
            api.Decompiled=succeeded;api.Failed=failures
            api.ControllerCandidates=countStrong;api.Exports+=1
            api.Status=string.format(
                "Saved controller scan: %d modules, %d DevWidgets references, %d ranked candidates",
                succeeded,definiteDevWidgets,countStrong)
            return path
        end)
        if not ok then
            api.LastError=tostring(result)
            api.Status="Controller scan failed: "..api.LastError
            return false,api.LastError
        end
        api.LastError=nil
        return true,result
    end
    return api
end
local DevMenuControllerDiscovery=createDevMenuControllerDiscovery()

-- Focused MTGClient startup inspection. Only decompiles the public-to-this-
-- client entry script and reads named local instance metadata. No require,
-- login attempt, DevAction call, remote interception or permission changes.
local function createDevMenuStartupInspector()
    local LogService=game:GetService("LogService")
    local Players=game:GetService("Players")
    local P=Players.LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local Http=game:GetService("HttpService")
    local file="Geode/dev_menu_startup_diagnostics.json"
    local api={Status="Not captured",LastPath=nil,LastError=nil,
        Exports=0,References=0,SourceLines=0}
    local sensitive={"password","passcode","secret","token","credential",
        "privatekey","apikey","api_key","cookie","authheader",
        "userid","user_id","username","ownerid","adminids",
        "staffids","devids","whitelist","allowlist","banlist",
        "membership","webhook"}
    local function contains(str,what)
        return tostring(str):lower():find(what:lower(),1,true)~=nil
    end
    local function privateLine(str)
        for _,term in ipairs(sensitive)do
            if contains(str,term)then return true end
        end
        return false
    end
    local function safeLine(str)
        local value=tostring(str or "")
        if privateLine(value)then
            return "[redacted: authentication, membership or credential]"
        end
        value=value:gsub("%d%d%d%d%d%d%d%d+","[numeric-id]")
            :gsub("https?://%S+","[url]")
        return value:sub(1,200)
    end
    local function pathOf(obj)
        local ok,value=pcall(function()return obj:GetFullName()end)
        return (ok and tostring(value)or tostring(obj.Name))
            :gsub(P.Name,"LocalPlayer"):sub(1,200)
    end
    -- Retrieves already-retained F9 client console history. No LogService
    -- hooks or simulated errors; history may have truncated early startup.
    local function collectStartupConsole()
        local out={
            Available=false,Source="LogService:GetLogHistory()",
            HistoryCount=0,Inspected=0,Selected=0,
            RelatedGameMessages=0,DevMenuMessages=0,
            RobloxCoreGuiMessages=0,Warnings=0,Errors=0,
            Truncated=false,HistoryMayOmitEarlierStartup=true,
            Messages={},AvailabilityError=nil,
            Note="Read-only snapshot of retained client F9 messages, not private server logs. Only related startup lines and surrounding context are included. Absence of a DevMenu message is not proof of a successful menu load."
        }
        local ok,history=pcall(function()return LogService:GetLogHistory()end)
        if not ok or type(history)~="table"then
            out.AvailabilityError="F9 history unavailable to this client/executor"
            return out
        end
        out.Available=true;out.HistoryCount=#history
        local start=math.max(1,#history-1100)
        out.Truncated=start>1
        out.Inspected=#history-start+1
        local selected={}
        local types={}
        local scores={}
        local candidates={}
        for i=start,#history do
            local row=history[i]
            local message=type(row)=="table"and
                tostring(row.message or row.Message or"")or""
            local lower=message:lower()
            local isDev=lower:find("devmenu",1,true)
                or lower:find("devwidgets",1,true)
                or lower:find("devtools",1,true)
                or lower:find("mtgclient",1,true)
            local isGame=lower:find("[mtg]",1,true)
                or lower:find("[uikit]",1,true)
            local isCore=lower:find("coregui",1,true)
                or lower:find("settingshub",1,true)
                or lower:find("getserverchannelremote",1,true)
            local isStartup=lower:find("client ready",1,true)
                or lower:find("lobby",1,true)
                or lower:find("startup",1,true)
                or lower:find("init",1,true)
            local mt=type(row)=="table"and(row.messageType or row.MessageType)or nil
            local mtStr=tostring(mt or"")
            local isError=mtStr:find("Error",1,true)~=nil
            local isWarning=mtStr:find("Warning",1,true)~=nil
            local isRelevantError=(isError or isWarning)
                and (isGame or isDev or isCore or isStartup
                    or lower:find("require",1,true)
                    or lower:find("nil value",1,true))
            if isDev then out.DevMenuMessages+=1 end
            if isGame then out.RelatedGameMessages+=1 end
            if isCore then out.RobloxCoreGuiMessages+=1 end
            if isError then out.Errors+=1 end
            if isWarning then out.Warnings+=1 end
            local category=isDev and "DevMenuOrClient"
                or isGame and "GameClient"
                or isCore and "RobloxCoreGui"
                or isRelevantError and "StartupWarningOrError"
                or isStartup and "StartupContext"
                or nil
            if category then
                scores[i]=isDev and 4 or isGame and 3
                    or isRelevantError and 2 or 1
                types[i]=category
                candidates[#candidates+1]=i
                for neighbor=math.max(start,i-1),math.min(#history,i+1)do
                    selected[neighbor]=true
                end
            end
        end
        local indices={}
        for i in pairs(selected)do indices[#indices+1]=i end
        table.sort(indices,function(a,b)
            local sa=scores[a]or 0
            local sb=scores[b]or 0
            if sa==sb then return a>b end
            return sa>sb
        end)
        local maxOut=220
        if #indices>maxOut then out.Truncated=true end
        local chosen={}
        for i=1,math.min(#indices,maxOut)do
            chosen[#chosen+1]=indices[i]
        end
        table.sort(chosen)
        for _,i in ipairs(chosen)do
            local row=history[i]
            local raw=type(row)=="table"and
                tostring(row.message or row.Message or"")or""
            -- General F9 output may include non-game sensitive values;
            -- restrict to a short redacted excerpt and never save raw logs.
            local clean=safeLine(raw:gsub(P.Name,"LocalPlayer"))
            local mt=type(row)=="table"and(row.messageType or row.MessageType)or nil
            local tm=type(row)=="table"and(row.timestamp or row.Timestamp)or nil
            local record={
                Index=i,Type=tostring(mt or"Unknown"),
                Category=types[i]or"AdjacentContext",
                Text=clean,
                Time=type(tm)=="number"and tm or nil
            }
            out.Messages[#out.Messages+1]=record
        end
        out.Selected=#out.Messages
        return out
    end
    -- Record ClientError changes beginning at hub startup (not earlier).
    local clientErrorHistory={
        StartedAtMs=DateTime.now().UnixTimestampMillis,
        InitialPresent=P:GetAttribute("ClientError")~=nil,
        InitialValue=nil,Changes={},ChangeCount=0
    }
    local initialError=P:GetAttribute("ClientError")
    if initialError~=nil then
        clientErrorHistory.InitialValue=safeLine(tostring(initialError):gsub(P.Name,"LocalPlayer"))
    end
    local clientErrorConnection=P:GetAttributeChangedSignal("ClientError"):Connect(function()
        clientErrorHistory.ChangeCount+=1
        if #clientErrorHistory.Changes>=50 then return end
        local value=P:GetAttribute("ClientError")
        clientErrorHistory.Changes[#clientErrorHistory.Changes+1]={
            CapturedAtMs=DateTime.now().UnixTimestampMillis,
            Present=value~=nil,
            Value=value~=nil and safeLine(tostring(value):gsub(P.Name,"LocalPlayer"))or nil
        }
    end)
    -- The native client awaits PlayerGui.MTGDevKit and its Count of child
    -- modules before attempting to load DevMenu. Observe without creating
    -- objects, invoking code, or modifying a native developer interface.
    local devKitEvents={}
    local devKitLastSignature=nil
    api.Monitoring=false
    api.OnMonitorUpdate=nil
    local function devKitSnapshot()
        local gui=P:FindFirstChild("PlayerGui")
        local kit=gui and gui:FindFirstChild("MTGDevKit")
        local scripts=P:FindFirstChild("PlayerScripts")
        local client=scripts and scripts:FindFirstChild("MTGClient")
        local attribute=kit and kit:GetAttribute("Count") or nil
        local expected=tonumber(attribute)
        local snap={
            Found=kit~=nil,Class=kit and kit.ClassName or nil,
            CountAttribute=attribute~=nil and safeLine(tostring(attribute)) or nil,
            ExpectedChildren=expected,ChildCount=0,ModuleCount=0,
            Children={},ChildrenTruncated=false,
            ClientFound=client~=nil,ClientModuleCount=0,
            ClientDevMenuFound=client and client:FindFirstChild("DevMenu")~=nil or false,
            ClientDevWidgetsFound=client and client:FindFirstChild("DevWidgets")~=nil or false,
            CountConditionMet=false,Status="Waiting for MTGDevKit",
            Note="A readiness snapshot does not establish developer authorization or imply the menu is safe to force-open."
        }
        if kit then
            local children=kit:GetChildren()
            snap.ChildCount=#children
            snap.CountConditionMet=#children>=(expected or 3)
            for _,child in ipairs(children)do
                if child:IsA("ModuleScript")then snap.ModuleCount+=1 end
                if #snap.Children<40 then
                    snap.Children[#snap.Children+1]={
                        Name=safeLine(child.Name),Class=child.ClassName
                    }
                else
                    snap.ChildrenTruncated=true
                end
            end
            table.sort(snap.Children,function(a,b)return a.Name<b.Name end)
        end
        if client then
            for _,child in ipairs(client:GetChildren())do
                if child:IsA("ModuleScript")then snap.ClientModuleCount+=1 end
            end
        end
        if snap.ClientDevMenuFound then
            snap.Status="DevMenu module replicated; authorization still unknown"
        elseif not kit then
            snap.Status="Waiting for PlayerGui.MTGDevKit"
        elseif not snap.CountConditionMet then
            snap.Status="MTGDevKit present; waiting for expected children"
        else
            snap.Status="MTGDevKit count met; DevMenu module not visible"
        end
        return snap
    end
    api.InspectDevKit=devKitSnapshot
    api.DevKitSnapshot=devKitSnapshot()
    local function recordDevKit(snap)
        local signature=table.concat({
            snap.Found and "1" or "0",
            tostring(snap.ExpectedChildren or "nil"),
            tostring(snap.ChildCount),
            tostring(snap.ModuleCount),
            snap.ClientDevMenuFound and "1" or "0",
            snap.ClientDevWidgetsFound and "1" or "0"
        },"|")
        if signature==devKitLastSignature then return end
        devKitLastSignature=signature
        if #devKitEvents>=60 then table.remove(devKitEvents,1)end
        devKitEvents[#devKitEvents+1]={
            AtMs=DateTime.now().UnixTimestampMillis,
            Status=snap.Status,KitPresent=snap.Found,
            ExpectedChildren=snap.ExpectedChildren,
            ChildCount=snap.ChildCount,ModuleCount=snap.ModuleCount,
            ClientDevMenuFound=snap.ClientDevMenuFound
        }
        if type(api.OnMonitorUpdate)=="function"then
            pcall(api.OnMonitorUpdate,snap)
        end
    end
    function api.SetDevKitMonitor(enabled)
        enabled=enabled==true
        if api.Monitoring==enabled then return end
        api.Monitoring=enabled
        if not enabled then return end
        local current=devKitSnapshot()
        api.DevKitSnapshot=current
        recordDevKit(current)
        task.spawn(function()
            while api.Monitoring do
                local snapshot=devKitSnapshot()
                api.DevKitSnapshot=snapshot
                recordDevKit(snapshot)
                task.wait(0.5)
            end
        end)
    end
    function api.Stop()
        api.Monitoring=false
        api.OnMonitorUpdate=nil
        if clientErrorConnection then
            clientErrorConnection:Disconnect()
            clientErrorConnection=nil
        end
    end
    function api.Export()
        api.Status="Inspecting MTGClient startup, ClientError attribute and F9 history (read-only)"
        local success,result=pcall(function()
            assert(type(writefile)=="function","Executor cannot write local diagnostics")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local playerScripts=P:FindFirstChild("PlayerScripts")
            local client=playerScripts and playerScripts:FindFirstChild("MTGClient")
            local mtg=RS:FindFirstChild("MTG")
            local remoteRoot=mtg and mtg:FindFirstChild("Remotes")
            local devAction=remoteRoot and remoteRoot:FindFirstChild("DevAction")
            local devMenu=client and client:FindFirstChild("DevMenu")
            local devWidgets=client and client:FindFirstChild("DevWidgets")
            local report={
                Version=5,HubVersion=geodeVersion,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                PlaceId=game.PlaceId,GameId=game.GameId,
                ReadOnly=true,ClientScriptsExecuted=false,
                DeveloperCommandsCalled=false,PrivilegesModified=false,
                AuthenticationAttempted=false,MenuActivated=false,
                ClientEntry={
                    Found=client~=nil,Class=client and client.ClassName or nil,
                    Path=client and pathOf(client)or nil,
                    Decompiled=false,SourceBytes=0,LineCount=0
                },
                ChildModules={
                    DevMenu={Found=devMenu~=nil,
                        Class=devMenu and devMenu.ClassName or nil},
                    DevWidgets={Found=devWidgets~=nil,
                        Class=devWidgets and devWidgets.ClassName or nil}
                },
                ClientState={
                    Role=mtg and mtg:GetAttribute("Role")or nil,
                    DevLocked=mtg and mtg:GetAttribute("DevLocked")or nil
                },
                DevActionPresent=devAction~=nil,
                DevActionClass=devAction and devAction.ClassName or nil,
                ClientErrorState={
                    Present=P:GetAttribute("ClientError")~=nil,
                    Value=P:GetAttribute("ClientError")~=nil
                        and safeLine(tostring(P:GetAttribute("ClientError")):gsub(P.Name,"LocalPlayer"))or nil,
                    ObserverStartedAtMs=clientErrorHistory.StartedAtMs,
                    InitialPresent=clientErrorHistory.InitialPresent,
                    InitialValue=clientErrorHistory.InitialValue,
                    ChangeCount=clientErrorHistory.ChangeCount,Changes={},
                    Note="Only the latest ClientError is retained by Roblox. Earlier errors can be overwritten; the observer starts with BeyyHub."
                },
                ExecutionEvidence={
                    ClientScriptEnabled=client and client:IsA("LocalScript")and client.Enabled or nil,
                    LookupContext={},BootContexts={},ClientReadyLogged=false,
                    DevMenuMessageLogged=false,
                    Assessment="Static references alone do not prove DevMenu boot executed."
                },
                DecompilerAvailable=type(decompile)=="function",
                ReferenceCategories={},ReferenceLines={},ContextLines={},
                 StartupReportRouting={Definitions={},CallLines={},PossibleOutputs={},ContextLines={},Truncated=false,
                     Note="Static inspection of client-visible report() definitions and related output calls. Possible outputs are not proof of delivery to F9 or to a server."},
                ContextTruncated=false,SourceTruncated=false,
                ClientConsoleHistory={},
                DevKitInspection=devKitSnapshot(),
                DevKitMonitoring={Enabled=api.Monitoring,Events={},EventCount=#devKitEvents},
                StartupChecks={
                    HasDevMenuFindFirstChild=false,
                    HasDevMenuBootCall=false,
                    HasProtectedDevMenuLoad=false,
                    HasDevMenuReport=false,
                    HasExplicitF2Handler=false
                },
                Note="A missing replicated DevMenu child may be intentional; this report cannot determine server-side permission checks or retrieve passwords. Context contains only small sanitized snippets around client startup references."
            }
            for _,event in ipairs(clientErrorHistory.Changes)do
                report.ClientErrorState.Changes[#report.ClientErrorState.Changes+1]=event
            end
            for _,event in ipairs(devKitEvents)do
                report.DevKitMonitoring.Events[#report.DevKitMonitoring.Events+1]=event
            end
            if client and (client:IsA("LocalScript")
                or client:IsA("ModuleScript"))
                and type(decompile)=="function"then
                local ok,code=pcall(decompile,client)
                if ok and type(code)=="string"and #code>0 then
                    report.ClientEntry.Decompiled=true
                    report.ClientEntry.SourceBytes=#code
                    if #code>160000 then
                        code=code:sub(1,160000)
                        report.SourceTruncated=true
                    end
                    local lines={}
                    for line in (code.."\n"):gmatch("(.-)\n")do
                        lines[#lines+1]=line
                        if #lines>=2500 then
                            report.SourceTruncated=true
                            break
                        end
                    end
                    report.ClientEntry.LineCount=#lines
                    -- A small static look at the conditional path; never run inspected code.
                    local execution=report.ExecutionEvidence
                    local function captureContext(target,first,last,cap)
                        for j=math.max(1,first),math.min(#lines,last)do
                            if #target>=cap then return end
                            target[#target+1]={Line=j,Text=safeLine(lines[j])}
                        end
                    end
                    for i,line in ipairs(lines)do
                        local lower=line:lower()
                        if lower:find('findfirstchild("devmenu"',1,true)then
                            captureContext(execution.LookupContext,i-28,i+13,65)
                        elseif lower:find('boot("devmenu"',1,true)then
                            captureContext(execution.BootContexts,i-8,i+12,60)
                        end
                    end
                    -- Trace only the client-visible report() error-handling
                    -- routine. Never execute the function or invoke remotes.
                    local route=report.StartupReportRouting
                    local seenOutputs={}
                    local outputPatterns={
                        {"warn(","warn"},{"print(","print"},
                        {"error(","error"},{"logservice","LogService"},
                        {"messageout","MessageOut"}
                    }
                    for i,rawLine in ipairs(lines)do
                        local lower=rawLine:lower()
                        if lower:find("devmenu",1,true)
                            and lower:find("report(",1,true)
                            and #route.CallLines<16 then
                            route.CallLines[#route.CallLines+1]=i
                        end
                        local isDefinition=lower:match("^%s*local%s+function%s+report%s*%(")
                            or lower:match("^%s*function%s+report%s*%(")
                            or lower:find("report = function(",1,true)
                        if isDefinition and #route.Definitions<4 then
                            route.Definitions[#route.Definitions+1]=i
                            for j=i,math.min(i+28,#lines)do
                                local excerpt=lines[j]
                                if #route.ContextLines<96 then
                                    route.ContextLines[#route.ContextLines+1]={
                                        Line=j,Text=safeLine(excerpt)}
                                else
                                    route.Truncated=true
                                    break
                                end
                                local scan=excerpt:lower()
                                for _,pattern in ipairs(outputPatterns)do
                                    if scan:find(pattern[1],1,true)
                                        and not seenOutputs[pattern[2]]then
                                        seenOutputs[pattern[2]]=true
                                        route.PossibleOutputs[#route.PossibleOutputs+1]=pattern[2]
                                    end
                                end
                            end
                        end
                    end
                    local selected={}
                    local refs=0
                    local function mark(label,lineNum)
                        local arr=report.ReferenceLines[label]or{}
                        if #arr<36 then arr[#arr+1]=lineNum end
                        report.ReferenceLines[label]=arr
                        report.ReferenceCategories[label]=(report.ReferenceCategories[label]or 0)+1
                    end
                    for i,line in ipairs(lines)do
                        local low=line:lower()
                        local devRef=low:find("devmenu",1,true)~=nil
                        local widgetsRef=low:find("devwidgets",1,true)~=nil
                        local f2Ref=low:find("keycode.f2",1,true)~=nil
                        local mention=devRef or widgetsRef or f2Ref
                        if devRef then
                            mark("DevMenuReference",i)
                            if low:find("findfirstchild",1,true)then
                                report.StartupChecks.HasDevMenuFindFirstChild=true
                                mark("DevMenuChildLookup",i)
                            end
                            if low:find("boot(",1,true)then
                                report.StartupChecks.HasDevMenuBootCall=true
                                mark("DevMenuBoot",i)
                            end
                            if low:find("pcall",1,true)and
                                low:find("require",1,true)then
                                report.StartupChecks.HasProtectedDevMenuLoad=true
                                mark("ProtectedDevMenuLoad",i)
                            end
                            if low:find("report(",1,true)then
                                report.StartupChecks.HasDevMenuReport=true
                                mark("DevMenuStartupReport",i)
                            end
                        end
                        if widgetsRef then mark("DevWidgetsDependency",i)end
                        if f2Ref then
                            mark("NativeF2Reference",i)
                            report.StartupChecks.HasExplicitF2Handler=true
                        end
                        if mention then
                            refs+=1
                            for j=math.max(1,i-4),math.min(#lines,i+4)do
                                selected[j]=true
                            end
                        end
                    end
                    api.References=refs
                    api.SourceLines=#lines
                    local saved=0
                    for i=1,#lines do
                        if selected[i]then
                            saved+=1
                            if saved<=130 then
                                report.ContextLines[#report.ContextLines+1]={
                                    Line=i,Text=safeLine(lines[i]),
                                    IsDirectMatch=contains(lines[i],"DevMenu")
                                        or contains(lines[i],"DevWidgets")
                                        or contains(lines[i],"KeyCode.F2")}
                            else
                                report.ContextTruncated=true
                                break
                            end
                        end
                    end
                else
                    report.ClientEntry.Error="Client source not readable using decompile"
                end
            elseif not client then
                report.ClientEntry.Error="MTGClient not replicated in this session"
            else
                report.ClientEntry.Error="No client-side decompiler available"
            end
            report.ClientConsoleHistory=collectStartupConsole()
            for _,entry in ipairs(report.ClientConsoleHistory.Messages or {})do
                local lower=tostring(entry.Text or ""):lower()
                if lower:find("[mtg] client ready",1,true)then
                    report.ExecutionEvidence.ClientReadyLogged=true
                end
                if lower:find("devmenu",1,true)then
                    report.ExecutionEvidence.DevMenuMessageLogged=true
                end
            end
            if report.ClientErrorState.Present then
                report.ExecutionEvidence.Assessment=
                    "ClientError attribute present; inspect redacted value. Only the latest error is retained, not a complete startup trace."
            elseif report.ExecutionEvidence.ClientReadyLogged then
                report.ExecutionEvidence.Assessment=
                    "Client-ready message seen, no current ClientError. This does not establish whether optional DevMenu boot ran."
            else
                report.ExecutionEvidence.Assessment=
                    "No definitive runtime evidence of DevMenu boot; the F9 log and ClientError history may be incomplete."
            end
            writefile(file,Http:JSONEncode(report))
            api.LastPath=file;api.Exports+=1
            api.Status=string.format(
                "Saved DevMenu startup: %d references, menu child %s, F9 %d selected / %d history%s",
                api.References,devMenu and "present"or"missing",
                report.ClientConsoleHistory.Selected or 0,
                report.ClientConsoleHistory.HistoryCount or 0,
                report.ClientConsoleHistory.Available and""or" (unavailable)")
            return file
        end)
        if not success then
            api.LastError=tostring(result)
            api.Status="DevMenu startup export failed: "..api.LastError
            return false,api.LastError
        end
        api.LastError=nil
        return true,result
    end
    return api
end
local DevMenuStartupInspector=createDevMenuStartupInspector()

-- Explicit F2 input diagnostics, independent of MTGDevKit. Observe only.
local function createF2KeyInspector()
    local UIS=game:GetService("UserInputService")
    local CAS=game:GetService("ContextActionService")
    local Players=game:GetService("Players")
    local Http=game:GetService("HttpService")
    local P=Players.LocalPlayer
    local file="Geode/f2_key_diagnostics.json"
    local api={Enabled=false,Status="OFF",Presses=0,Events={},
        StartedAtMs=nil,OnChange=nil,LastPath=nil,LastError=nil,
        LifecycleEvents={},LifecycleEventCount=0,LifecycleTruncated=false,
        ObservedObjects=0}
    local connection=nil
    local guiConnections={}
    local propertyConnections={}
    local watched={}
    local watchUntil=0
    local function nameSafe(value)
        return tostring(value or ""):gsub(P.Name,"LocalPlayer")
            :gsub("https?://%S+","[url]")
            :gsub("%d%d%d%d%d%d%d%d+","[id]"):sub(1,95)
    end
    local function shortPath(obj)
        local parts={}
        local node=obj
        for _=1,16 do
            if not node then break end
            table.insert(parts,1,nameSafe(node.Name))
            if node.Name=="PlayerGui"then break end
            node=node.Parent
        end
        return table.concat(parts,".")
    end
    local function relevantName(obj)
        local s=tostring(obj.Name):lower()
        return s:find("dev",1,true)or s:find("admin",1,true)
            or s:find("password",1,true)or s:find("login",1,true)
            or s:find("access",1,true)or s:find("prompt",1,true)
            or s:find("dialog",1,true)or s:find("popup",1,true)
            or s:find("modal",1,true)or s:find("menu",1,true)
    end
    local function guiRoot(obj)
        local node=obj
        for _=1,20 do
            if not node then break end
            if node:IsA("ScreenGui")then return node end
            node=node.Parent
        end
        return nil
    end
    local function guiAncestry(obj)
        local entries={}
        local node=obj
        for _=1,14 do
            if not node then break end
            table.insert(entries,1,{
                Name=nameSafe(node.Name),Class=node.ClassName,
                Visible=node:IsA("ScreenGui")and node.Enabled
                    or (node:IsA("GuiObject")and node.Visible)or nil
            })
            if node.Name=="PlayerGui"then break end
            node=node.Parent
        end
        return entries
    end
    local function siblingSummary(obj)
        local siblings={}
        local parent=obj.Parent
        if not parent then return siblings end
        for _,child in ipairs(parent:GetChildren())do
            if child~=obj and (child:IsA("GuiObject")or child:IsA("ScreenGui"))then
                if #siblings>=18 then break end
                siblings[#siblings+1]={
                    Name=nameSafe(child.Name),Class=child.ClassName,
                    Visible=child:IsA("ScreenGui")and child.Enabled
                        or (child:IsA("GuiObject")and child.Visible)or false
                }
            end
        end
        table.sort(siblings,function(a,b)return a.Name<b.Name end)
        return siblings
    end
    local function meta(obj)
        local root=guiRoot(obj)
        local parent=obj.Parent
        local record={
            Name=nameSafe(obj.Name),Class=obj.ClassName,
            Path=shortPath(obj),
            RootGui=root and nameSafe(root.Name)or nil,
            RootGuiEnabled=root and root.Enabled or nil,
            ParentName=parent and nameSafe(parent.Name)or nil,
            ParentClass=parent and parent.ClassName or nil
        }
        if obj:IsA("ScreenGui")then
            record.Visible=obj.Enabled
        elseif obj:IsA("GuiObject")then
            record.Visible=obj.Visible
        end
        -- Never inspect TextBox.Text or any typed input.
        if obj:IsA("TextBox")then record.InputField=true end
        return record
    end
    local function track(kind,obj)
        if not api.Enabled or os.clock()>watchUntil then return end
        api.LifecycleEventCount+=1
        if #api.LifecycleEvents>=160 then
            api.LifecycleTruncated=true
            return
        end
        api.LifecycleEvents[#api.LifecycleEvents+1]={
            AtMs=DateTime.now().UnixTimestampMillis,Kind=kind,
            Object=meta(obj)
        }
    end
    local function toastSnapshot(pg)
        local info={LaneFound=false,ToastFound=false,ToastObjects={},
            ToastObjectCount=0,Truncated=false}
        if not pg then return info end
        local lane=pg:FindFirstChild("MTG_Lane")
        info.LaneFound=lane~=nil
        if not lane then return info end
        local toast=lane:FindFirstChild("Toast",true)
        if not toast then return info end
        info.ToastFound=true
        info.ToastRoot=meta(toast)
        for _,obj in ipairs(toast:GetDescendants())do
            info.ToastObjectCount+=1
            if #info.ToastObjects<32 then
                if obj:IsA("GuiObject")then
                    info.ToastObjects[#info.ToastObjects+1]=meta(obj)
                end
            else
                info.Truncated=true
            end
        end
        return info
    end
    local function guiSnapshot()
        local pg=P:FindFirstChild("PlayerGui")
        local snap={Found=pg~=nil,ScreenGuiCount=0,EnabledScreenGuis=0,
            ScreenGuis={},RelevantGuiObjects={},InputFields={},
            LaneToast=toastSnapshot(pg),
            Scanned=0,Truncated=false}
        if not pg then return snap end
        for _,child in ipairs(pg:GetChildren())do
            if child:IsA("ScreenGui")then
                snap.ScreenGuiCount+=1
                if child.Enabled then snap.EnabledScreenGuis+=1 end
                if #snap.ScreenGuis<40 then
                    snap.ScreenGuis[#snap.ScreenGuis+1]={
                        Name=nameSafe(child.Name),Enabled=child.Enabled
                    }
                else
                    snap.Truncated=true
                end
            end
        end
        table.sort(snap.ScreenGuis,function(a,b)return a.Name<b.Name end)
        for _,obj in ipairs(pg:GetDescendants())do
            snap.Scanned+=1
            if snap.Scanned>20000 then
                snap.Truncated=true
                break
            end
            if obj:IsA("GuiObject")or obj:IsA("ScreenGui")then
                if relevantName(obj)then
                    if #snap.RelevantGuiObjects<80 then
                        snap.RelevantGuiObjects[#snap.RelevantGuiObjects+1]=meta(obj)
                    else
                        snap.Truncated=true
                    end
                end
                if obj:IsA("TextBox")then
                    if #snap.InputFields<40 then
                        local item=meta(obj)
                        local ok,focused=pcall(function()return obj:IsFocused()end)
                        item.Focused=ok and focused==true
                        item.Ancestors=guiAncestry(obj)
                        item.SiblingControls=siblingSummary(obj)
                        item.TextContentCaptured=false
                        snap.InputFields[#snap.InputFields+1]=item
                    else
                        snap.Truncated=true
                    end
                end
            end
        end
        table.sort(snap.RelevantGuiObjects,function(a,b)return a.Path<b.Path end)
        table.sort(snap.InputFields,function(a,b)return a.Path<b.Path end)
        return snap
    end
    local function boundF2()
        local result={Available=false,Matches={},TotalActions=0,
            Truncated=false,Error=nil}
        local ok,bindings=pcall(function()return CAS:GetAllBoundActionInfo()end)
        if not ok or type(bindings)~="table"then
            result.Error="Unable to inspect ContextActionService bindings"
            return result
        end
        result.Available=true
        for action,info in pairs(bindings)do
            result.TotalActions+=1
            local actionName=nameSafe(action)
            local lower=actionName:lower()
            local matches=lower:find("dev",1,true)
                or lower:find("admin",1,true)
                or lower:find("debug",1,true)
            local keys={}
            if type(info)=="table"and type(info.inputTypes)=="table"then
                for _,key in ipairs(info.inputTypes)do
                    local label=tostring(key)
                    if label=="Enum.KeyCode.F2"then matches=true end
                    if #keys<12 then keys[#keys+1]=label end
                end
            end
            if matches then
                if #result.Matches<30 then
                    result.Matches[#result.Matches+1]={
                        Action=actionName,Inputs=keys
                    }
                else result.Truncated=true end
            end
        end
        table.sort(result.Matches,function(a,b)return a.Action<b.Action end)
        return result
    end
    -- Trace only static client-visible toast construction references.
    -- Do not run any inspected module or include secret/access source lines.
    local function toastSourceHints()
        local report={Available=type(decompile)=="function",
            Sources={},LinesMatched=0,Truncated=false,
            Note="Static source references are not evidence that the referenced code ran."}
        if not report.Available then return report end
        local scripts=P:FindFirstChild("PlayerScripts")
        local client=scripts and scripts:FindFirstChild("MTGClient")
        if not client then return report end
        for _,name in ipairs({"Lane","LaneUI","LobbyUI","Notify","Notifications","MTGClient"})do
            local module=name=="MTGClient"and client or client:FindFirstChild(name)
            if module and (module:IsA("ModuleScript")or module:IsA("LocalScript"))then
                local entry={Module=name,References={},Count=0}
                local ok,code=pcall(decompile,module)
                if ok and type(code)=="string"then
                    local lineNo=0
                    for line in (code:sub(1,180000).."\n"):gmatch("(.-)\n")do
                        lineNo+=1
                        if lineNo>5000 then report.Truncated=true;break end
                        local lower=line:lower()
                        if lower:find("toast",1,true)
                            or lower:find("mtg_lane",1,true)then
                            entry.Count+=1
                            report.LinesMatched+=1
                            local blocked=lower:find("password",1,true)
                                or lower:find("passcode",1,true)
                                or lower:find("secret",1,true)
                                or lower:find("token",1,true)
                                or lower:find("credential",1,true)
                                or lower:find("api_key",1,true)
                                or lower:find("adminid",1,true)
                                or lower:find("whitelist",1,true)
                            if #entry.References<15 then
                                entry.References[#entry.References+1]={
                                    Line=lineNo,
                                    Text=blocked and "[redacted: access-sensitive line]"
                                        or nameSafe(line):sub(1,160)
                                }
                            else report.Truncated=true end
                        end
                    end
                else
                    entry.Error="Client module source unavailable"
                end
                if entry.Count>0 or entry.Error then
                    report.Sources[#report.Sources+1]=entry
                end
            end
        end
        return report
    end
    local function toastTiming()
        local out={ToastEvents={},Count=0,Note=
            "Time proximity to F2 is not proof that the key triggered the toast."}
        for _,event in ipairs(api.LifecycleEvents)do
            local obj=event.Object or{}
            if tostring(obj.Path or ""):find("MTG_Lane.Toast",1,true)then
                out.Count+=1
                local latest=nil
                for _,key in ipairs(api.Events)do
                    if key.AtMs<=event.AtMs
                        and (not latest or key.AtMs>latest.AtMs)then
                        latest=key
                    end
                end
                if #out.ToastEvents<35 then
                    out.ToastEvents[#out.ToastEvents+1]={
                        Event=event,
                        NearestPriorF2Press=latest and latest.Press or nil,
                        MillisecondsAfterF2=latest and event.AtMs-latest.AtMs or nil
                    }
                end
            end
        end
        return out
    end
    local function capture()
        return {
            AtMs=DateTime.now().UnixTimestampMillis,
            TextInputFocused=UIS:GetFocusedTextBox()~=nil,
            NativeBindings=boundF2(),Gui=guiSnapshot()
        }
    end
    local function notify()
        if type(api.OnChange)=="function"then
            pcall(api.OnChange,api.Status)
        end
    end
    local function watchObject(obj)
        if watched[obj]or api.ObservedObjects>=250 then return end
        if obj:IsA("ScreenGui")then
            watched[obj]=true
            api.ObservedObjects+=1
            propertyConnections[#propertyConnections+1]=
                obj:GetPropertyChangedSignal("Enabled"):Connect(function()
                    track("ScreenGuiEnabledChanged",obj)
                end)
        elseif obj:IsA("GuiObject")and
            (relevantName(obj)or obj:IsA("TextBox")
                or (obj.Parent and obj.Parent:IsA("ScreenGui")))then
            watched[obj]=true
            api.ObservedObjects+=1
            propertyConnections[#propertyConnections+1]=
                obj:GetPropertyChangedSignal("Visible"):Connect(function()
                    track("GuiVisibilityChanged",obj)
                end)
            if obj:IsA("TextBox")then
                propertyConnections[#propertyConnections+1]=
                    obj.Focused:Connect(function()
                        track("InputFieldFocused",obj)
                    end)
            end
        end
    end
    local function stopWatchers()
        if connection then connection:Disconnect();connection=nil end
        for _,c in ipairs(guiConnections)do c:Disconnect()end
        for _,c in ipairs(propertyConnections)do c:Disconnect()end
        guiConnections={};propertyConnections={};watched={}
        api.ObservedObjects=0
        watchUntil=0
    end
    function api.SetEnabled(enabled)
        enabled=enabled==true
        if enabled==api.Enabled then return end
        api.Enabled=enabled
        if not enabled then
            stopWatchers()
            api.Status="OFF | F2 presses recorded: "..tostring(api.Presses)
            notify()
            return
        end
        api.StartedAtMs=DateTime.now().UnixTimestampMillis
        api.Events={};api.Presses=0
        api.LifecycleEvents={};api.LifecycleEventCount=0
        api.LifecycleTruncated=false
        api.Status="ON | Press F2, then export F2 + popup diagnostics"
        local pg=P:FindFirstChild("PlayerGui")
        if pg then
            for _,obj in ipairs(pg:GetDescendants())do watchObject(obj)end
            for _,child in ipairs(pg:GetChildren())do watchObject(child)end
            guiConnections[#guiConnections+1]=pg.DescendantAdded:Connect(function(obj)
                if obj:IsA("GuiObject")or obj:IsA("ScreenGui")then
                    track("GuiCreated",obj)
                    watchObject(obj)
                end
            end)
            guiConnections[#guiConnections+1]=pg.DescendantRemoving:Connect(function(obj)
                if obj:IsA("GuiObject")or obj:IsA("ScreenGui")then
                    track("GuiRemoved",obj)
                end
            end)
        end
        connection=UIS.InputBegan:Connect(function(input,gameProcessed)
            if input.KeyCode~=Enum.KeyCode.F2 then return end
            watchUntil=os.clock()+5
            api.Presses+=1
            local event={
                Press=api.Presses,AtMs=DateTime.now().UnixTimestampMillis,
                GameProcessed=gameProcessed==true,OnKeyDown=capture()
            }
            if #api.Events>=12 then table.remove(api.Events,1)end
            api.Events[#api.Events+1]=event
            api.Status="ON | F2 presses: "..tostring(api.Presses)
            notify()
            task.delay(0.05,function()
                if api.Enabled then event.After50ms=capture()end
            end)
            task.delay(0.2,function()
                if api.Enabled then event.After200ms=capture()end
            end)
            task.delay(1,function()
                if api.Enabled then event.After1000ms=capture()end
            end)
            task.delay(3,function()
                if api.Enabled then event.After3000ms=capture()end
            end)
        end)
        notify()
    end
    function api.Export()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","No writefile support")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local report={
                Version=3,HubVersion=geodeVersion,ReadOnly=true,
                CapturedAtMs=DateTime.now().UnixTimestampMillis,
                Enabled=api.Enabled,Presses=api.Presses,
                StartedAtMs=api.StartedAtMs,Events=api.Events,
                GuiLifecycle={Events=api.LifecycleEvents,
                    TotalObserved=api.LifecycleEventCount,
                    Truncated=api.LifecycleTruncated,
                    PropertyWatchers=api.ObservedObjects},
                Current=capture(),
                ToastTiming=toastTiming(),
                ToastSourceHints=toastSourceHints(),
                Note="Opt-in F2 and targeted MTG_Lane.Toast, text-box ancestry/sibling GUI metadata only. Static source references do not prove execution. No UI text, TextBox contents, passwords, keys beyond F2, or privileged actions recorded."
            }
            writefile(file,Http:JSONEncode(report))
            return file
        end)
        if ok then
            api.Status="Saved "..tostring(result)
            api.LastPath=result;api.LastError=nil
            notify()
            return true,result
        end
        api.LastError=tostring(result)
        api.Status="F2 export failed: "..api.LastError
        notify()
        return false,api.LastError
    end
    function api.Stop()
        api.SetEnabled(false)
        api.OnChange=nil
    end
    return api
end
local F2KeyInspector=createF2KeyInspector()


-- Evidence-first native developer feature inventory. No guessed shortcuts,
-- code/password trials, module execution, or privileged calls.
local function createDeveloperEntryInventory()
    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local CAS=game:GetService("ContextActionService")
    local Http=game:GetService("HttpService")
    local P=Players.LocalPlayer
    local api={Status="Not checked",LastPath=nil,LastError=nil,LastSnapshot=nil}
    local function safeName(value)
        local name=tostring(value or "")
        local lower=name:lower()
        if lower:find("password",1,true)or lower:find("token",1,true)
            or lower:find("secret",1,true)or lower:find("credential",1,true)then
            return "[sensitive name]"
        end
        return name:gsub("%d%d%d%d%d%d%d%d+","[id]"):sub(1,80)
    end
    local function findPath(root,children)
        local obj=root
        for _,name in ipairs(children)do
            obj=obj and obj:FindFirstChild(name)
            if not obj then return nil end
        end
        return obj
    end
    local function inspectGui(pg)
        local out={Found=pg~=nil,ScreenGuiCount=0,DeveloperNamedGuis={},OtherGuiNames={},Truncated=false}
        if not pg then return out end
        for _,obj in ipairs(pg:GetChildren())do
            if obj:IsA("ScreenGui")then
                out.ScreenGuiCount+=1
                local name=tostring(obj.Name)
                local lower=name:lower()
                local entry={Name=safeName(name),Enabled=obj.Enabled}
                local dev=lower:find("dev",1,true)
                    or lower:find("admin",1,true)
                    or lower:find("debug",1,true)
                    or lower:find("staff",1,true)
                    or lower:find("freecam",1,true)
                local arr=dev and out.DeveloperNamedGuis or out.OtherGuiNames
                if #arr<40 then arr[#arr+1]=entry else out.Truncated=true end
            end
        end
        table.sort(out.DeveloperNamedGuis,function(a,b)return a.Name<b.Name end)
        table.sort(out.OtherGuiNames,function(a,b)return a.Name<b.Name end)
        return out
    end
    local function inspectClient(client)
        local out={Found=client~=nil,ModuleCount=0,RelatedModules={},Truncated=false}
        if not client then return out end
        for _,obj in ipairs(client:GetChildren())do
            if obj:IsA("ModuleScript")then
                out.ModuleCount+=1
                local name=tostring(obj.Name)
                local lower=name:lower()
                if lower:find("dev",1,true)or lower:find("admin",1,true)
                    or lower:find("debug",1,true)
                    or lower:find("watchrun",1,true)
                    or lower:find("freecam",1,true)
                    or lower:find("spectate",1,true)then
                    if #out.RelatedModules<40 then
                        out.RelatedModules[#out.RelatedModules+1]=safeName(name)
                    else out.Truncated=true end
                end
            end
        end
        table.sort(out.RelatedModules)
        return out
    end
    local function inspectActions()
        local out={Available=false,Total=0,F2BoundActions={},Truncated=false}
        local ok,actions=pcall(function()return CAS:GetAllBoundActionInfo()end)
        if not ok or type(actions)~="table"then return out end
        out.Available=true
        for action,info in pairs(actions)do
            out.Total+=1
            if type(info)=="table"and type(info.inputTypes)=="table"then
                for _,key in ipairs(info.inputTypes)do
                    if key==Enum.KeyCode.F2 then
                        if #out.F2BoundActions<20 then
                            out.F2BoundActions[#out.F2BoundActions+1]=safeName(action)
                        else out.Truncated=true end
                        break
                    end
                end
            end
        end
        table.sort(out.F2BoundActions)
        return out
    end
    -- Name and hierarchy only. Never inspect Text/TextBox.Text or activate UI.
    local function adminButtonCandidates(pg)
        local out={Scanned=0,Matches={},TotalMatches=0,
            Truncated=false,Limit=16000,
            Note="Object names and class metadata only; a match is not proof of an authorized admin button."}
        if not pg then return out end
        for _,obj in ipairs(pg:GetDescendants())do
            out.Scanned+=1
            if out.Scanned>out.Limit then out.Truncated=true;break end
            if obj:IsA("GuiButton")or obj:IsA("ScreenGui")
                or obj:IsA("Frame")then
                local label=tostring(obj.Name):lower()
                local dev=label:find("admin",1,true)
                    or label:find("developer",1,true)
                    or label:find("devmenu",1,true)
                    or label:find("devtools",1,true)
                    or label:find("staff",1,true)
                    or label:find("freecam",1,true)
                local p=obj.Parent
                local parentName=p and tostring(p.Name):lower()or""
                local inherited=parentName:find("admin",1,true)
                    or parentName:find("devmenu",1,true)
                    or parentName:find("devtools",1,true)
                if dev or inherited then
                    out.TotalMatches+=1
                    if #out.Matches<45 then
                        local root=obj
                        for _=1,16 do
                            if not root or root:IsA("ScreenGui")then break end
                            root=root.Parent
                        end
                        local visible=obj:IsA("ScreenGui")and obj.Enabled
                            or(obj:IsA("GuiObject")and obj.Visible)or false
                        out.Matches[#out.Matches+1]={
                            Name=safeName(obj.Name),Class=obj.ClassName,
                            Parent=p and safeName(p.Name)or nil,
                            GuiRoot=root and root:IsA("ScreenGui")
                                and safeName(root.Name)or nil,
                            Visible=visible,
                            Clickable=obj:IsA("GuiButton")
                        }
                    else out.Truncated=true end
                end
            end
        end
        table.sort(out.Matches,function(a,b)
            return (a.GuiRoot or"")..a.Name < (b.GuiRoot or"")..b.Name
        end)
        return out
    end
    -- Static client-source metadata; never execute source, reveal identities,
    -- read credentials, or use DevAction.
    local function adminEntryReferences(client,admin)
        local out={DecompilerAvailable=type(decompile)=="function",
            InspectedModules=0,Entries={},Truncated=false,
            Note="Line numbers are static hints only and do not prove that any client handler executed."}
        if not out.DecompilerAvailable then return out end
        local checks={
            {Name="AdminConfig",Object=admin},
            {Name="MTGClient",Object=client},
            {Name="LobbyUI",Object=client and client:FindFirstChild("LobbyUI")},
            {Name="UIKit",Object=client and client:FindFirstChild("UIKit")},
            {Name="LobbyWorld",Object=client and client:FindFirstChild("LobbyWorld")},
            {Name="DevWidgets",Object=client and client:FindFirstChild("DevWidgets")},
            {Name="Prompts",Object=client and client:FindFirstChild("Prompts")}
        }
        local patterns={
            ShowButton="ShowButton",
            DeveloperKit="MTGDevKit",
            DevMenu="DevMenu",
            DevAction="DevAction",
            ConfigAdmin="Config.Admin",
            F2Key="Enum.KeyCode.F2"
        }
        for _,target in ipairs(checks)do
            local obj=target.Object
            if obj and (obj:IsA("LocalScript")or obj:IsA("ModuleScript"))then
                out.InspectedModules+=1
                local info={Name=target.Name,SourceAvailable=false,
                    LineNumbers={},Hits={}}
                for k in pairs(patterns)do
                    info.LineNumbers[k]={}
                    info.Hits[k]=0
                end
                local ok,src=pcall(decompile,obj)
                if ok and type(src)=="string"then
                    info.SourceAvailable=true
                    local lineNo=0
                    for line in (src:sub(1,240000).."\n"):gmatch("(.-)\n")do
                        lineNo+=1
                        if lineNo>5500 then out.Truncated=true;break end
                        for key,needle in pairs(patterns)do
                            if line:find(needle,1,true)then
                                info.Hits[key]+=1
                                if #info.LineNumbers[key]<12 then
                                    table.insert(info.LineNumbers[key],lineNo)
                                else out.Truncated=true end
                            end
                        end
                    end
                    if #src>240000 then out.Truncated=true end
                else
                    info.Error="Source not available"
                end
                out.Entries[#out.Entries+1]=info
            end
        end
        return out
    end
    function api.Capture()
        local pg=P:FindFirstChild("PlayerGui")
        local scripts=P:FindFirstChild("PlayerScripts")
        local client=scripts and scripts:FindFirstChild("MTGClient")
        local mtg=RS:FindFirstChild("MTG")
        local config=mtg and mtg:FindFirstChild("Config")
        local remote=mtg and mtg:FindFirstChild("Remotes")
        local kit=pg and pg:FindFirstChild("MTGDevKit")
        local menu=client and client:FindFirstChild("DevMenu")
        local widgets=client and client:FindFirstChild("DevWidgets")
        local admin=config and config:FindFirstChild("Admin")
        local devAction=remote and remote:FindFirstChild("DevAction")
        local actions=inspectActions()
        local gui=inspectGui(pg)
        local role=mtg and mtg:GetAttribute("Role")or "unknown"
        local buttons=adminButtonCandidates(pg)
        local references=adminEntryReferences(client,admin)
        local report={
            Version=2,HubVersion=geodeVersion,ReadOnly=true,
            CapturedAtMs=DateTime.now().UnixTimestampMillis,
            ClientRole=role,
            Modules={Client=inspectClient(client),MTGDevKitPresent=kit~=nil,
                MTGDevKitChildCount=kit and #kit:GetChildren()or 0,
                DevMenuPresent=menu~=nil,DevWidgetsPresent=widgets~=nil},
            Configuration={AdminConfigPresent=admin~=nil,
                DevActionRemotePresent=devAction~=nil,
                DevActionClass=devAction and devAction.ClassName or nil,
                AccessVerified=false,DevActionCalled=false},
            Input=actions,Gui=gui,
            AdminButtonCandidates=buttons,
            AdminEntrySourceReferences=references,
            CodeRedemptionUI={
                Found=findPath(pg,{"MTG_LobbyMenus","Codes"})~=nil,
                Note="Game redemption UI is not a confirmed developer login"
            },
            HistoricalClues={
                AdminConfigF2SettingPreviouslyObserved=true,
                Interpretation="F2 is a configuration hint, not a confirmed working menu shortcut"
            },
            Note="Client-visible native admin-button evidence. UI names, not labels or input contents; static decompiled line numbers only. No server permission checks, spoofing, credentials, authentication attempts, or developer commands. Missing UI does not prove a feature never exists."
        }
        report.Assessment=menu and "DevMenu module is present; developer authorization unverified"
            or kit and "MTGDevKit is present, but DevMenu is missing"
            or "No client-visible native DevMenu entry point confirmed"
        api.Status=report.Assessment
            .." | F2 bindings="..tostring(#actions.F2BoundActions)
            .." | Developer GUIs="..tostring(#gui.DeveloperNamedGuis)
            .." | Button candidates="..tostring(buttons.TotalMatches)
        api.LastSnapshot=report
        return report
    end
    function api.Export()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","writefile unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local snapshot=api.Capture()
            local role=tostring(snapshot.ClientRole):lower()
            role=role:find("lobby",1,true)and"lobby"
                or(role:find("game",1,true)and"game"or"other")
            local file="Geode/dev_access_evidence_"..role..".json"
            writefile(file,Http:JSONEncode(snapshot))
            return file
        end)
        if ok then
            api.LastPath=result;api.LastError=nil
            return true,result
        end
        api.LastError=tostring(result)
        api.Status="Evidence export failed: "..api.LastError
        return false,api.LastError
    end
    return api
end
local DeveloperEntryInventory=createDeveloperEntryInventory()


-- Separate LOCAL developer-style workspace. Not the game's DevMenu.
-- Read-only client inspection, private to BeyyHub; no DevAction, spoofing,
-- admin/auth tests, native MTGDevKit assembly, or game permission changes.
local function createLocalDeveloperConsole()
    local Players=game:GetService("Players")
    local UIS=game:GetService("UserInputService")
    local CAS=game:GetService("ContextActionService")
    local LS=game:GetService("LogService")
    local RS=game:GetService("ReplicatedStorage")
    local Http=game:GetService("HttpService")
    local P=Players.LocalPlayer
    local api={Open=false,Page="Overview",LastExport=nil,LastError=nil}
    local gui,root,content,headerStatus=nil,nil,nil,nil
    local nav={}
    local connections={}
    local pageConnections={}
    local currentGuiName=nil
    local page="Overview"
    local moduleShowAll=false
    local palette={
        bg=Color3.fromRGB(16,20,27),
        surface=Color3.fromRGB(28,34,45),
        line=Color3.fromRGB(43,55,72),
        accent=Color3.fromRGB(81,149,217),
        text=Color3.fromRGB(232,239,247),
        muted=Color3.fromRGB(157,177,196),
        caution=Color3.fromRGB(225,179,106)
    }
    local function node(class,parent,props)
        local obj=Instance.new(class)
        for key,val in pairs(props or {})do obj[key]=val end
        obj.Parent=parent
        return obj
    end
    local function corner(obj,r)
        node("UICorner",obj,{CornerRadius=UDim.new(0,r or 6)})
    end
    local function connect(signal,fn,pageOnly)
        local c=signal:Connect(fn)
        table.insert(pageOnly and pageConnections or connections,c)
        return c
    end
    local function sanitized(value)
        local text=tostring(value or "")
        local low=text:lower()
        if low:find("password",1,true)
            or low:find("secret",1,true)
            or low:find("token",1,true)
            or low:find("credential",1,true)then
            return "[sensitive name]"
        end
        return text:gsub("%d%d%d%d%d%d%d%d+","[id]"):sub(1,90)
    end
    local function capture()
        local pg=P:FindFirstChild("PlayerGui")
        local ps=P:FindFirstChild("PlayerScripts")
        local mtg=RS:FindFirstChild("MTG")
        local client=ps and ps:FindFirstChild("MTGClient")
        local remotes=mtg and mtg:FindFirstChild("Remotes")
        local character=P.Character
        local hrp=character and character:FindFirstChild("HumanoidRootPart")
        local camera=workspace.CurrentCamera
        local data={
            Version=1,HubVersion=geodeVersion,LocalOnly=true,
            CapturedAtMs=DateTime.now().UnixTimestampMillis,
            GameId=game.GameId,PlaceId=game.PlaceId,
            Role=mtg and tostring(mtg:GetAttribute("Role")or"unknown")or"unavailable",
            Phase=mtg and tostring(mtg:GetAttribute("Phase")or"unknown")or"unavailable",
            MTGClientPresent=client~=nil,
            NativeDevMenuPresent=client and client:FindFirstChild("DevMenu")~=nil or false,
            NativeMTGDevKitPresent=pg and pg:FindFirstChild("MTGDevKit")~=nil or false,
            DevWidgetsPresent=client and client:FindFirstChild("DevWidgets")~=nil or false,
            DevActionRemotePresent=remotes and remotes:FindFirstChild("DevAction")~=nil or false,
            AuthorizationChecked=false,DevActionInvoked=false,
            Position=hrp and {
                X=math.floor(hrp.Position.X*100)/100,
                Y=math.floor(hrp.Position.Y*100)/100,
                Z=math.floor(hrp.Position.Z*100)/100
            }or nil,
            CameraFov=camera and math.floor(camera.FieldOfView*10)/10 or nil,
            Gui={Count=0,Enabled=0,Entries={},Truncated=false},
            ClientModules={Count=0,Entries={},Truncated=false},
            BoundActions={Available=false,Count=0,Entries={},Truncated=false},
            Console={Available=false,Scanned=0,Warnings=0,Errors=0},
            Note="Local-only module, GUI, input, camera and log-count metadata. No GUI text, textbox contents, raw console messages, credentials, developer menu, or privileged remote calls."
        }
        if pg then
            for _,obj in ipairs(pg:GetChildren())do
                if obj:IsA("ScreenGui")and obj.Name~="BeyyLocalDeveloperConsole"then
                    data.Gui.Count+=1
                    if obj.Enabled then data.Gui.Enabled+=1 end
                    if #data.Gui.Entries<65 then
                        data.Gui.Entries[#data.Gui.Entries+1]={
                            Name=sanitized(obj.Name),Enabled=obj.Enabled,
                            DisplayOrder=obj.DisplayOrder
                        }
                    else data.Gui.Truncated=true end
                end
            end
            table.sort(data.Gui.Entries,function(a,b)return a.Name<b.Name end)
        end
        if client then
            for _,obj in ipairs(client:GetChildren())do
                if obj:IsA("ModuleScript")or obj:IsA("LocalScript")then
                    data.ClientModules.Count+=1
                    if #data.ClientModules.Entries<170 then
                        data.ClientModules.Entries[#data.ClientModules.Entries+1]={
                            Name=sanitized(obj.Name),Class=obj.ClassName
                        }
                    else data.ClientModules.Truncated=true end
                end
            end
            table.sort(data.ClientModules.Entries,function(a,b)return a.Name<b.Name end)
        end
        local bindingsOK,bindings=pcall(function()return CAS:GetAllBoundActionInfo()end)
        if bindingsOK and type(bindings)=="table"then
            data.BoundActions.Available=true
            for name,info in pairs(bindings)do
                data.BoundActions.Count+=1
                if #data.BoundActions.Entries<45 then
                    local keys={}
                    if type(info)=="table"and type(info.inputTypes)=="table"then
                        for _,key in ipairs(info.inputTypes)do
                            if #keys<12 then keys[#keys+1]=tostring(key)end
                        end
                    end
                    data.BoundActions.Entries[#data.BoundActions.Entries+1]={
                        Action=sanitized(name),Inputs=keys
                    }
                else data.BoundActions.Truncated=true end
            end
            table.sort(data.BoundActions.Entries,function(a,b)
                return a.Action<b.Action
            end)
        end
        local ok,history=pcall(function()return LS:GetLogHistory()end)
        if ok and type(history)=="table"then
            data.Console.Available=true
            local first=math.max(1,#history-499)
            data.Console.Scanned=#history-first+1
            for n=first,#history do
                local item=history[n]
                local kind=type(item)=="table"
                    and tostring(item.messageType or item.MessageType or"")or""
                if kind:find("Error",1,true)then
                    data.Console.Errors+=1
                elseif kind:find("Warning",1,true)then
                    data.Console.Warnings+=1
                end
            end
        end
        return data
    end
    local function clearPage()
        for _,conn in ipairs(pageConnections)do conn:Disconnect()end
        pageConnections={}
        if not content then return end
        for _,child in ipairs(content:GetChildren())do
            if child:IsA("GuiObject")then child:Destroy()end
        end
        content.CanvasPosition=Vector2.new(0,0)
    end
    local function line(text,kind)
        local isTitle=kind=="title"
        local isMuted=kind=="muted"
        local t=node("TextLabel",content,{
            Size=UDim2.new(1,-2,0,isTitle and 30 or 24),
            AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,
            Font=isTitle and Enum.Font.GothamBold or Enum.Font.Code,
            TextSize=isTitle and 17 or 13,
            TextColor3=isMuted and palette.muted
                or(isTitle and palette.accent or palette.text),
            TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center,
            TextWrapped=true,
            RichText=false,Text=tostring(text)
        })
        return t
    end
    local function action(text,callback)
        local b=node("TextButton",content,{
            Size=UDim2.new(1,-2,0,31),
            BackgroundColor3=palette.surface,
            BorderSizePixel=0,
            Font=Enum.Font.Code,TextSize=13,
            TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left,
            Text="  "..tostring(text),AutoButtonColor=true
        })
        corner(b,5)
        connect(b.Activated,callback,true)
        return b
    end
    local function display(pageName)
        if not gui or not gui.Parent then return end
        page=pageName or page
        api.Page=page
        clearPage()
        for name,button in pairs(nav)do
            button.BackgroundColor3=name==page and palette.accent
                or palette.surface
        end
        local data=capture()
        headerStatus.Text="LOCAL ONLY  |  "..data.Role
            .."  |  Native DevMenu: "
            ..(data.NativeDevMenuPresent and "present" or "unavailable")
        if page=="Overview"then
            line("LOCAL DEVELOPER CONSOLE","title")
            line("BeyyHub client diagnostics — not the game's restricted DevMenu.","muted")
            line("Game phase: "..data.Role.." / "..data.Phase)
            line("Place: "..tostring(data.PlaceId))
            line("Game MTGClient: "..tostring(data.MTGClientPresent))
            line("Native MTGDevKit: "..tostring(data.NativeMTGDevKitPresent))
            line("Native DevMenu: "..tostring(data.NativeDevMenuPresent))
            line("DevWidgets toolkit: "..tostring(data.DevWidgetsPresent))
            line("DevAction remote exists: "..tostring(data.DevActionRemotePresent))
            line("GUI screens: "..data.Gui.Count.." ("..data.Gui.Enabled.." enabled)")
            line("Client scripts: "..tostring(data.ClientModules.Count))
            if data.Position then
                local p=data.Position
                line(("Position: %.2f / %.2f / %.2f"):format(p.X,p.Y,p.Z))
                action("Copy current position (local)",function()
                    local rootpart=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
                    if not rootpart then return end
                    local v=rootpart.Position
                    local value=("%.2f, %.2f, %.2f"):format(v.X,v.Y,v.Z)
                    if type(setclipboard)=="function"then
                        pcall(setclipboard,value)
                    end
                end)
            end
            line("Camera FOV: "..tostring(data.CameraFov or"unknown"))
            line("No developer identity or server permissions are modified.","muted")
        elseif page=="UI Explorer"then
            line("UI EXPLORER","title")
            line("ScreenGui objects from your current PlayerGui. Click to inspect structural children; contents are not read.","muted")
            if currentGuiName then
                local pg=P:FindFirstChild("PlayerGui")
                local selected=pg and pg:FindFirstChild(currentGuiName)
                if selected and selected:IsA("ScreenGui")then
                    line("Selected: "..sanitized(selected.Name),"title")
                    line("Enabled: "..tostring(selected.Enabled)
                        .." | DisplayOrder: "..tostring(selected.DisplayOrder))
                    local names={}
                    local numButtons,numInputs=0,0
                    local descendants=selected:GetDescendants()
                    for i,obj in ipairs(descendants)do
                        if i>2200 then break end
                        if obj:IsA("GuiButton")then numButtons+=1 end
                        if obj:IsA("TextBox")then numInputs+=1 end
                        if obj.Parent==selected and #names<24 then
                            table.insert(names,sanitized(obj.Name).." ["..obj.ClassName.."]")
                        end
                    end
                    line("Inspected up to 2,200 descendants | Buttons: "
                        ..numButtons.." | TextBoxes: "..numInputs)
                    for _,name in ipairs(names)do line("  "..name)end
                else
                    line("Selected screen is no longer present.","muted")
                end
            end
            for _,entry in ipairs(data.Gui.Entries)do
                local name=entry.Name
                -- Sensitive names are intentionally not selectable.
                if name~="[sensitive name]"then
                    action((entry.Enabled and "[ON]  "or"[OFF] ")..name,function()
                        currentGuiName=name
                        display("UI Explorer")
                    end)
                end
            end
        elseif page=="Client Scripts"then
            line("CLIENT SCRIPTS","title")
            line("Current MTGClient child modules — names only. Nothing is executed or decompiled.","muted")
            line("Discovered: "..data.ClientModules.Count)
            line("Native DevMenu: "..(data.NativeDevMenuPresent and"present"or"missing"))
            local count=moduleShowAll and #data.ClientModules.Entries
                or math.min(42,#data.ClientModules.Entries)
            for i=1,count do
                local entry=data.ClientModules.Entries[i]
                line("  "..entry.Name.."  ("..entry.Class..")")
            end
            if #data.ClientModules.Entries>42 then
                action(moduleShowAll and "Show fewer modules"or"Show all modules",function()
                    moduleShowAll=not moduleShowAll
                    display("Client Scripts")
                end)
            end
        elseif page=="Input Bindings"then
            line("INPUT BINDINGS","title")
            line("Current ContextActionService bindings, not a keyboard recorder.","muted")
            line("Actions: "..data.BoundActions.Count)
            if not data.BoundActions.Available then
                line("Action metadata unavailable.","muted")
            end
            local f2=0
            for _,entry in ipairs(data.BoundActions.Entries)do
                local joined=table.concat(entry.Inputs,", ")
                if joined:find("Enum.KeyCode.F2",1,true)then f2+=1 end
                line("  "..entry.Action.."  |  "..(joined~=""and joined or"none"))
            end
            line("Visible F2 bindings: "..f2)
        elseif page=="Console Stats"then
            line("CONSOLE & RUNTIME","title")
            line("Only aggregate F9 message counts; no log message text is collected.","muted")
            line("Client log history accessible: "..tostring(data.Console.Available))
            line("Recent entries scanned: "..data.Console.Scanned)
            line("Warnings: "..data.Console.Warnings)
            line("Errors: "..data.Console.Errors)
            line("Camera FOV: "..tostring(data.CameraFov or"unknown"))
            line("PlayerGui screens: "..data.Gui.Count)
            line("Client modules: "..data.ClientModules.Count)
            line("Use Export to save metadata for further review.","muted")
        end
    end
    local function build()
        if gui and gui.Parent then return end
        local parent=P:FindFirstChild("PlayerGui")or P:WaitForChild("PlayerGui")
        if type(gethui)=="function"then
            local ok,value=pcall(gethui)
            if ok and value then parent=value end
        end
        gui=node("ScreenGui",parent,{
            Name="BeyyLocalDeveloperConsole",Enabled=false,
            ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=10001,
            ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        })
        root=node("Frame",gui,{
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.fromScale(0.5,0.5),
            Size=UDim2.fromOffset(690,510),
            BackgroundColor3=palette.bg,BorderSizePixel=0
        })
        corner(root,10)
        local outline=node("UIStroke",root,{
            Color=palette.line,Thickness=1
        })
        local scale=node("UIScale",root,{Scale=1})
        local function fit()
            local v=gui.AbsoluteSize
            if v.X>0 and v.Y>0 then
                scale.Scale=math.min(1,math.max(.35,(v.X-16)/690),
                    math.max(.35,(v.Y-16)/510))
            end
        end
        connect(gui:GetPropertyChangedSignal("AbsoluteSize"),fit)
        fit()
        local top=node("Frame",root,{
            Position=UDim2.fromOffset(0,0),
            Size=UDim2.new(1,0,0,53),
            BackgroundColor3=palette.surface,
            BorderSizePixel=0
        })
        corner(top,9)
        node("TextLabel",top,{
            BackgroundTransparency=1,Position=UDim2.fromOffset(16,5),
            Size=UDim2.new(1,-100,0,24),Text="BEYY / LOCAL DEVELOPER CONSOLE",
            TextColor3=palette.text,Font=Enum.Font.GothamBold,TextSize=16,
            TextXAlignment=Enum.TextXAlignment.Left
        })
        headerStatus=node("TextLabel",top,{
            BackgroundTransparency=1,Position=UDim2.fromOffset(16,29),
            Size=UDim2.new(1,-100,0,18),Text="LOCAL ONLY",
            TextColor3=palette.muted,Font=Enum.Font.Code,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left
        })
        local close=node("TextButton",top,{
            Position=UDim2.new(1,-45,0,9),Size=UDim2.fromOffset(33,33),
            BackgroundColor3=palette.line,BorderSizePixel=0,
            Font=Enum.Font.GothamBold,Text="×",TextSize=20,
            TextColor3=palette.text
        })
        corner(close,6)
        connect(close.Activated,function()
            gui.Enabled=false;api.Open=false
        end)
        local tabs=node("Frame",root,{
            Position=UDim2.fromOffset(12,63),
            Size=UDim2.new(1,-24,0,39),
            BackgroundTransparency=1
        })
        node("UIListLayout",tabs,{
            FillDirection=Enum.FillDirection.Horizontal,
            HorizontalAlignment=Enum.HorizontalAlignment.Center,
            Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder
        })
        for _,name in ipairs({"Overview","UI Explorer","Client Scripts",
            "Input Bindings","Console Stats"})do
            local b=node("TextButton",tabs,{
                Size=UDim2.new(0,124,0,34),
                BackgroundColor3=palette.surface,
                BorderSizePixel=0,AutoButtonColor=true,
                Font=Enum.Font.Gotham,TextSize=12,
                TextColor3=palette.text,Text=name
            })
            corner(b,5)
            nav[name]=b
            connect(b.Activated,function()display(name)end)
        end
        content=node("ScrollingFrame",root,{
            Position=UDim2.fromOffset(15,111),
            Size=UDim2.new(1,-30,1,-163),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ScrollBarThickness=5,
            ScrollBarImageColor3=palette.accent,
            AutomaticCanvasSize=Enum.AutomaticSize.Y,
            CanvasSize=UDim2.new()
        })
        node("UIListLayout",content,{
            Padding=UDim.new(0,6),
            SortOrder=Enum.SortOrder.LayoutOrder
        })
        node("UIPadding",content,{
            PaddingBottom=UDim.new(0,12),
            PaddingRight=UDim.new(0,8)
        })
        local bottom=node("Frame",root,{
            Position=UDim2.new(0,15,1,-43),
            Size=UDim2.new(1,-30,0,34),
            BackgroundTransparency=1
        })
        local function bottomButton(title,atX,width,handler)
            local b=node("TextButton",bottom,{
                Position=UDim2.fromOffset(atX,0),
                Size=UDim2.fromOffset(width,33),
                BackgroundColor3=palette.surface,
                BorderSizePixel=0,Font=Enum.Font.Gotham,
                TextSize=12,TextColor3=palette.text,
                Text=title
            })
            corner(b,5)
            connect(b.Activated,handler)
        end
        bottomButton("Refresh page",0,139,function()display(page)end)
        bottomButton("Export JSON",147,139,function()
            local ok,result=api.Export()
            if ok then
                headerStatus.Text="Saved "..tostring(result)
            else
                headerStatus.Text="Export failed: "..tostring(result)
            end
        end)
        node("TextLabel",bottom,{
            Position=UDim2.new(1,-275,0,0),
            Size=UDim2.fromOffset(270,34),BackgroundTransparency=1,
            Text="Client-side inspection only • no admin powers",
            Font=Enum.Font.Gotham,TextSize=10,
            TextColor3=palette.caution,TextXAlignment=Enum.TextXAlignment.Right
        })
    end
    function api.Toggle()
        local ok,result=pcall(function()
            build()
            gui.Enabled=not gui.Enabled
            api.Open=gui.Enabled
            if api.Open then display(page)end
            return api.Open
        end)
        if not ok then api.LastError=tostring(result);return false,result end
        return true,result
    end
    function api.Refresh()
        if gui and gui.Parent and gui.Enabled then display(page)end
    end
    function api.Export()
        local ok,result=pcall(function()
            assert(type(writefile)=="function","writefile unavailable")
            if type(isfolder)=="function"and type(makefolder)=="function"
                and not isfolder("Geode")then makefolder("Geode")end
            local path="Geode/local_developer_console_diagnostics.json"
            writefile(path,Http:JSONEncode(capture()))
            return path
        end)
        if ok then
            api.LastExport=result;api.LastError=nil
            return true,result
        end
        api.LastError=tostring(result)
        return false,api.LastError
    end
    function api.Destroy()
        for _,conn in ipairs(pageConnections)do pcall(function()conn:Disconnect()end)end
        for _,conn in ipairs(connections)do pcall(function()conn:Disconnect()end)end
        pageConnections={};connections={}
        if gui then gui:Destroy();gui=nil end
        root=nil;content=nil;headerStatus=nil;nav={}
        api.Open=false
    end
    return api
end
local LocalDeveloperConsole=createLocalDeveloperConsole()

local NativeUI=createNativeUI()
local Window=NativeUI:CreateWindow({Title="Beyy Hub | Crack the Geode!",Folder="GeodeHub"})
Window:SetToggleKey(Enum.KeyCode.RightControl)
FarmEscapes.SetWindow(Window)
local Hub={Running=true,Version="1.10.105",Window=Window,Pickup=Pickup,Eggs=Eggs,LavaEggInspector=LavaEggInspector,LavaFastHatch=LavaFastHatch,ChiselCrackInspector=ChiselCrackInspector,AdminSpectateInspector=AdminSpectateInspector,LocalSpectate=LocalSpectate,FarmSafety=FarmSafety,ClassMutations=ClassMutations,CrackSell=CrackSell,MagnetUpgrades=MagnetUpgrades,CrackPowerUpgrades=CrackPowerUpgrades,FastChisel=FastChisel,Escape=Escape,Endless=Endless,OtherModeAbility=OtherModeAbility,AbilityPrefs=abilityPrefs,GameWalkSpeed=GameWalkSpeed,IntroVisuals=IntroVisuals,AntiAFK=AntiAFK,AutoPerks=AutoPerks,FarmEscapes=FarmEscapes,MovementDiagnostics=MovementDiagnostics,AntiCheatInventory=AntiCheatInventory,DevMenuInspector=DevMenuInspector,DevWidgetsStructureInspector=DevWidgetsStructureInspector,DevMenuControllerDiscovery=DevMenuControllerDiscovery,DevMenuStartupInspector=DevMenuStartupInspector,F2KeyInspector=F2KeyInspector,DeveloperEntryInventory=DeveloperEntryInventory,LocalDeveloperConsole=LocalDeveloperConsole}
Window.Gui:SetAttribute("GeodeSessionVersion",Hub.Version)
env.GeodeHub=Hub
function Hub.Unload()
    if not Hub.Running then return end
    Hub.Running=false
    F2KeyInspector.Stop()
    LocalDeveloperConsole.Destroy()
    DevMenuStartupInspector.Stop()
    MovementDiagnostics.Unload()
    FarmSafety.Unload()
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
    CrackPowerUpgrades.Unload()
    FastChisel.Unload()
    CrackSell.Unload()
    Pickup.Unload()
    Eggs.Unload()
    LavaFastHatch.Unload()
    LocalSpectate.Unload()
    Window:Destroy()
    releaseGeodeBoot()
end
stop.OnInvoke=Hub.Unload
local overview=Window:Section({Title="Overview"})
local main=overview:Tab({Title="Main"})
local endlessTab=overview:Tab({Title="Endless"})
local eggs=overview:Tab({Title="Eggs"})
local spectateTab=overview:Tab({Title="Spectate"})
local mutations=overview:Tab({Title="Class Mutations"})
local statusTab=overview:Tab({Title="Status & Logs"})
local localDevTab=overview:Tab({Title="Local DevTools"})
-- Group the dense Status & Logs diagnostics while retaining all live
-- status bindings, existing export callbacks and file destinations.
statusTab:Section({Title="Live Dashboard"})
local session=statusTab:Paragraph({Title="Session",Desc="Crack the Geode!"})
local statusOverview=statusTab:Paragraph({
    Title="Live Overview Status",Desc="Idle | Enable farming in Main or Endless."
})
local statusFarmingGroup=statusTab:CollapsibleGroup({
    Title="Farming — Pickup, Crack & Escape",Opened=false
})
local statusCombatGroup=statusTab:CollapsibleGroup({
    Title="Boss, Upgrades & Abilities",Opened=false
})
local statusUtilityGroup=statusTab:CollapsibleGroup({
    Title="Movement, Safety & Utilities",Opened=false
})
local statusMovementGroup=statusTab:CollapsibleGroup({
    Title="Movement / Anti-Cheat Diagnostics",Opened=false
})
local statusDeveloperGroup=statusTab:CollapsibleGroup({
    Title="DevMenu Startup Diagnostics",Opened=true
})

local settings=overview:Tab({Title="Settings"})

spectateTab:Section({Title="Local Camera Spectating"})
spectateTab:Paragraph({Title="Same-Server Spectator",Desc="Uses the game's native DevTools.spectate camera routine. Follow any current-server player who isn't a spectator. Does not invoke DevAction, set your Spectator attribute, enter developer LiveRuns, or move your character. Official WatchRun is separately server-controlled."})
local localSpectatePlayer=spectateTab:Dropdown({
    Title="Player to Watch",Values=LocalSpectate.PlayerNames(),
    Value="Select a player",Callback=LocalSpectate.Select
})
local localSpectateStatus=spectateTab:Paragraph({
    Title="Camera Status",Desc="Idle — own camera"
})
spectateTab:Button({Title="Refresh Players",Callback=function()
    local names=LocalSpectate.PlayerNames()
    localSpectatePlayer:Refresh(names)
    local current=localSpectatePlayer.Value
    if not table.find(names,current)then
        localSpectatePlayer:Select(names[1])
    end
    localSpectateStatus:SetDesc("Player list refreshed; "..#names.." option(s)")
end})
spectateTab:Button({Title="Spectate Selected Player",Callback=function()
    local ok,message=LocalSpectate.Start(localSpectatePlayer.Value)
    localSpectateStatus:SetDesc(LocalSpectate.Status)
    if not ok then
        NativeUI:Notify({Title="Local Spectate",Content=tostring(message)})
    end
end})
spectateTab:Button({Title="Previous Player",Callback=function()
    local ok,message=LocalSpectate.Cycle(-1)
    localSpectateStatus:SetDesc(LocalSpectate.Status)
    if not ok then
        NativeUI:Notify({Title="Local Spectate",Content=tostring(message)})
    end
end})
spectateTab:Button({Title="Next Player",Callback=function()
    local ok,message=LocalSpectate.Cycle(1)
    localSpectateStatus:SetDesc(LocalSpectate.Status)
    if not ok then
        NativeUI:Notify({Title="Local Spectate",Content=tostring(message)})
    end
end})
spectateTab:Button({Title="Return to My Camera",Callback=function()
    LocalSpectate.Stop()
    localSpectateStatus:SetDesc(LocalSpectate.Status)
end})
spectateTab:Section({Title="Free Camera"})
spectateTab:Paragraph({Title="Local FreeCam",Desc="Optional native developer camera controls without server admin access: WASD to move, E / Q for vertical motion, mouse to look, Shift for faster movement. Disable to restore your character camera. This changes only the client camera, not server position or role."})
local localFreeCamToggle=spectateTab:Toggle({
    Title="Local FreeCam (Camera Only)",Value=false,Callback=function(on)
        local ok,message=LocalSpectate.SetFreeCam(on)
        localSpectateStatus:SetDesc(LocalSpectate.Status)
        if not ok then
            NativeUI:Notify({Title="Local FreeCam",Content=tostring(message)})
        end
    end
})
endlessTab:Section({Title="Endless Farming"})
local endlessToggle=endlessTab:Toggle({Title="Auto Endless Mode",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then Endless.Start()
    elseif not value then Endless.Stop()end
end})
local hoverHeight=endlessTab:Slider({Title="Endless Hover Clearance (studs)",Step=.5,Value={Min=2,Max=20,Default=6.5},Callback=function(value)Endless.SetHover(value)end})
local endlessFlySpeed=endlessTab:Slider({Title="Flight Speed — Endless / Win Farm / Crack & Sell (studs/s)",Step=1,Value={Min=4,Max=29,Default=16},Callback=function(value)
    Endless.SetFlySpeed(value)
    CrackSell.SetFlySpeed(value)
end})
local endlessStatus=endlessTab:Paragraph({Title="Endless Status",Desc="Experimental continuous circular Fly + Noclip: approach the original low pile ring, then maintain smooth tangential flight with radial/height correction. The angle follows actual character movement, not frozen teleport waypoints. Flight defaults to 16 studs/s (selectable 4–29), independent of native Humanoid WalkSpeed. The game server may still restrict movement; camp teleport/cash trips remain disabled."})
endlessTab:Paragraph({Title="Movement Validation Warning",Desc="This feature avoids direct position teleports in Auto Endless and restores collisions when stopped. Fly/noclip itself may violate the game movement rules, especially at higher requested speeds; if kicked again, stop using it."})
local bossCritToggle=endlessTab:Toggle({Title="Auto Boss Criticals",Value=true,Callback=function(value)
    Endless.SetBossAssist(value==true and not FarmSafety.Stopped)
end})
endlessTab:Paragraph({Title="Boss Assistance",Desc="Auto criticals remain enabled, with or without Auto Endless. Mother boss fights equip the game-defined Gear.Weapon.Id FIGHT slot and aim at exposed MotherSpot weak points. BestCracker determines the equipped style. GEO-MAG stays in mining."})
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
endlessTab:Paragraph({Title="Damage Priority",Desc="Legacy damage focus applies only when Adaptive Timed Perk Selection is OFF. The default adaptive scorer now reads direct mastery unlock and adjusts recurring fuel, Shortcut and radius utility for offered stacks. Ranking reasons and all game-defined perk effects are in Auto Perks debug export."})
local perkToggle=endlessTab:Toggle({Title="Auto Select Perk",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then AutoPerks.Start()
    elseif not value then AutoPerks.Stop()end
end})
local adaptivePerksToggle=endlessTab:Toggle({Title="Adaptive Timed Perk Selection",Value=true,Callback=function(value)
    AutoPerks.SetAdaptive(value)
end})
local perkStatus=endlessTab:Paragraph({Title="Perk Selection Status",Desc="Scores the actual three Endless cards for depth speed and fuel survival. Exports the complete live perk catalog, offered-card rankings, and context at each selection for diagnosing unexpected choices."})
main:Section({Title="Auto Farm Escapes"})
local farmEscapesToggle=main:Toggle({Title="Auto Farm Escapes",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then FarmEscapes.Start()
    elseif not value then FarmEscapes.Stop()end
end})
local farmEscapesStatus=main:Paragraph({Title="Auto Farm Escapes Status",Desc="Paused. 17x–22x adaptive rotation: one full low outer-edge lap then continuous top-down orbit. Strong server-confirmed pickups accelerate by 2x; later low-yield laps no longer slow down. Auto Endless unchanged."})
local topDownSecondToggle=main:Toggle({Title="Continuous Top-Down Orbit (After Base)",Value=true,Callback=function(value)
    Endless.SetTopDownSecondPass(value)
end})
local winFarmFlightToggle=main:Toggle({
    Title="Win Farm Fly + Noclip (No Teleport)",Value=true,
    Callback=function(value)Endless.SetWinFarmFly(value)end
})
main:Paragraph({Title="Win Farm Movement",Desc="Fly + Noclip ON: actual movement follows the low-ring then top-down coverage using the independent 4–29 studs/s flight controller. Laps advance from observed movement, not camera-only rotation. This may be slower than the previous teleport orbit; server validation still applies. OFF: legacy orbit."})
main:Section({Title="Character Movement"})
local walkSpeedToggle=main:Toggle({Title="Monitor Native WalkSpeed (No Hub Cap)",Value=true,Callback=function(value)
    GameWalkSpeed.SetEnabled(value==true and not FarmSafety.Stopped)
end})
local walkSpeedStatus=statusUtilityGroup:Paragraph({Title="WalkSpeed Status",Desc="Read-only monitoring of the game-defined WalkSpeed. BeyyHub does not set a maximum or multiply walking speed. Game-server movement limits still apply."})
main:Section({Title="Geode Collection"})
local pickupToggle=main:Toggle({Title="Auto Geode Pickup",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then Pickup.Start()
    elseif not value then Pickup.Stop()end
end})
local collectionExtras=main:CollapsibleGroup({Title="Advanced Pickup Options",Opened=false})
local fastPickupToggle=collectionExtras:Toggle({Title="Fast Geode Pickup",Value=true,Callback=function(value)
    Pickup.SetFastPickup(value)
end})
local pickupRange=collectionExtras:Slider({Title="Pickup Range (studs)",Step=1,Value={Min=1,Max=26,Default=26},Callback=function(value)
    Pickup.SetRange(0,value)
end})
local live=statusFarmingGroup:Paragraph({Title="Pickup Status",Desc="Paused — enable Auto Geode Pickup to begin."})
main:Section({Title="Cracking & Selling"})
local crackToggle=main:Toggle({Title="Auto Crack and Sell",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then CrackSell.Start()
    elseif not value and CrackSell.Enabled then
        CrackSell.Stop("Manually paused Crack & Sell")
    end
end})
local cycleInterval=main:Slider({Title="Crack Delay (seconds)",Step=.05,Value={Min=.10,Max=60,Default=1},Callback=function(value)
    CrackSell.SetInterval(value)
end})
local continuousCrack=main:Toggle({Title="Keep Cracking & Selling",Value=false,Callback=function(value)
    CrackSell.SetContinuous(value)
end})
local crackExtras=main:CollapsibleGroup({Title="Advanced Crack & Sell Options",Opened=false})
local crackFlyTravel=crackExtras:Toggle({
    Title="Crack & Sell Fly + Noclip (No Teleport)",Value=true,
    Callback=function(value)CrackSell.SetFlyTravel(value)end
})
local fastCrackTravel=crackExtras:Toggle({Title="Legacy Fast Camp Teleport (Fly OFF)",Value=true,Callback=function(value)
    CrackSell.SetFastTravel(value)
end})
local turboCrack=crackExtras:Toggle({Title="Turbo Crack & Sell",Value=true,Callback=function(value)
    CrackSell.SetTurbo(value)
end})
local repeatInterval=crackExtras:Slider({Title="Repeat Delay (seconds)",Step=1,Value={Min=1,Max=60,Default=10},Callback=function(value)
    CrackSell.SetRepeatInterval(value)
end})
local crackStatus=statusFarmingGroup:Paragraph({Title="Crack & Sell Status",Desc="Paused — returns to your pickup position after each cycle."})
main:Paragraph({Title="Crack & Sell Travel",Desc="Default Fly + Noclip: real LinearVelocity travel between deposit, cracking station, sale bin, and pickup position, with in-range prompt checks, collision restore, and no CFrame teleports. Uses the shared flight-speed slider. Slower than teleport on long trips; turn OFF to restore legacy teleport. Turbo affects prompt timing; server responses confirm each stage."})
main:Section({Title="Escape"})
local escapeToggle=main:Toggle({Title="Auto Escape",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then Escape.Start()
    elseif not value then Escape.Stop()end
end})
local escapeStatus=statusFarmingGroup:Paragraph({Title="Escape Status",Desc="Auto Escape uses the server-open lift. Lift diagnostics are available through the manual Export Debug Diagnostics button."})
eggs:Section({Title="Candy Shop"})
main:Section({Title="GEO-MAG 3000 Upgrades"})
local upgradeToggle=main:Toggle({Title="Auto GEO-MAG Upgrades",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then MagnetUpgrades.Start()
    elseif not value then MagnetUpgrades.Stop()end
end})
local upgradeExtras=main:CollapsibleGroup({Title="Advanced Upgrade Options",Opened=false})
local powerFirstToggle=upgradeExtras:Toggle({Title="Prioritize Pull Power",Value=true,Callback=function(value)
    MagnetUpgrades.SetPowerFirst(value)
end})
local fastUpgradeToggle=upgradeExtras:Toggle({Title="Fast Upgrade Purchases",Value=true,Callback=function(value)
    MagnetUpgrades.SetFastPurchases(value)
end})
local upgradeStatus=statusCombatGroup:Paragraph({Title="Magnet Upgrade Status",Desc="GEO-MAG Power/Speed purchases use current game prices and server responses, then require replicated level confirmation. Shop requests never overlap. Check the export for price, track and timeout details."})
upgradeExtras:Button({
    Title="Export GEO-MAG Upgrade Diagnostics",
    Callback=function()
        task.spawn(function()
            local ok,err=MagnetUpgrades.Export()
            NativeUI:Notify({
                Title="GEO-MAG Upgrades",
                Content=ok and "Saved Geode/magnet_upgrade_diagnostics.json"
                    or ("Export failed: "..tostring(err))
            })
        end)
    end
})
main:Section({Title="Automatic Rusty Chisel Upgrades & Fast Attacks"})
local crackPowerToggle=main:Toggle({Title="Auto Buy Crack Power (Boss Damage)",Value=true,Callback=function(value)
    if value and not FarmSafety.Stopped then CrackPowerUpgrades.Start()
    elseif not value then CrackPowerUpgrades.Stop()end
end})
main:Paragraph({Title="Crack Power Purchases",Desc="ON by default. Automatically upgrades the Rusty Chisel through the native Power upgrade during Mining/Mother phases when cash allows. Confirms each purchase and avoids overlapping GEO-MAG upgrade requests. Switch OFF to stop."})
local fastChiselToggle=main:Toggle({Title="Fast Rusty Chisel Boss Attacks (Experimental)",Value=true,Callback=function(value)
    FastChisel.SetEnabled(value==true and not FarmSafety.Stopped)
end})
local fastChiselSpeed=main:Slider({Title="Rusty Chisel Cooldown Multiplier",Step=.05,Value={Min=.4,Max=1,Default=.60},Callback=function(value)
    FastChisel.SetMultiplier(value)
end})
main:Paragraph({Title="Chisel Timing",Desc="In Mother fights, tries a 40% faster client Chisel cooldown by default (60% of normal). Native combo and auto critical tracking remain in place; server hit-rate enforcement may still cap damage. Turn OFF to restore the game cooldown."})
local fastChiselStatus=statusCombatGroup:Paragraph({Title="Fast Rusty Chisel Status",Desc="Waiting for boss phase."})
local crackPowerStatus=statusCombatGroup:Paragraph({Title="Crack Power Upgrade Status",Desc="Paused — opt in under Main."})
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
local otherAbilityStatus=statusCombatGroup:Paragraph({Title="GEO-MAG Ability Status",Desc="Waiting for eligible mode. Uses native server-confirmed activation."})
local eggToggle=eggs:Toggle({Title="Auto Open Haunted Egg",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then Eggs.Start()
    elseif not value then Eggs.Stop()end
end})
local eggStatus=eggs:Paragraph({Title="Egg Status",Desc="Paused. Existing Haunted Egg opener uses confirmed three-egg batches. Lava 20x is experimental and must pass a paid trial."})
eggs:Section({Title="Fast Lava Eggs — Native Hatch"})
eggs:Paragraph({Title="Native 20x Server Request",Desc="Native Hatch(Lava,20) returned 20 eggs in 81ms in a live test. The 3.5s+pad native wait is on the client; Adaptive Speed probes modestly shorter gaps. Server Busy/Wait always controls retries. Auto stays OFF until a paid 20-result trial in this session; batches still cost 50,000 gems unless the server applies credits."})
local lavaFastStatus=eggs:Paragraph({Title="Fast Lava Egg Status",Desc="Ready for one paid native 20x Lava batch test."})
eggs:Button({Title="Test One Native 20x Lava Batch (50,000 Gems)",Callback=function()
    if FarmSafety.Stopped then
        NativeUI:Notify({Title="Farm Safety",Content="Re-arm before starting any paid hatch"})
        return
    end
    task.spawn(function()
        local ok,reason=LavaFastHatch.TestOnce()
        lavaFastStatus:SetDesc(LavaFastHatch.Status)
        NativeUI:Notify({Title="Native Lava 20x Trial",
            Content=ok and"20 Lava pets confirmed. Auto 20x is now available."or tostring(reason)})
    end)
end})
local lavaMaxBatches=eggs:Slider({Title="Max Automatic 20x Batches",Step=1,
    Value={Min=1,Max=100,Default=10},Callback=LavaFastHatch.SetMaxBatches})
local lavaAdaptiveToggle=eggs:Toggle({Title="Adaptive Fast Lava Timing (Experimental)",Value=true,
    Callback=LavaFastHatch.SetAdaptiveSpeed})
eggs:Paragraph({Title="Adaptive Timing",Desc="Starts at about 3.25s between batches, shortens by 0.25s after two accepted 20x results, and learns from the first server Busy/Wait instead of repeatedly probing. Disable to use the game's normal ~3.55s client spacing. Never sends parallel requests."})
local lavaAutoToggle=eggs:Toggle({Title="Auto Open Native Lava Eggs 20x (Paid)",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then
        local ok=LavaFastHatch.Start()
        if not ok then NativeUI:Notify({Title="Lava Auto Hatch",Content=LavaFastHatch.Status})end
    else
        if LavaFastHatch.Enabled then LavaFastHatch.Stop()end
    end
end})
eggs:Button({Title="Inspect Native Lava Hatch API (Read Only)",Callback=function()
    local ok,reason=LavaFastHatch.InspectNative()
    lavaFastStatus:SetDesc(LavaFastHatch.Status)
    NativeUI:Notify({Title="Native Lava Hatch API",Content=ok and("Saved "..tostring(reason))or tostring(reason)})
end})
eggs:Paragraph({Title="Native API Dump File",Desc="Upload Geode/lava_hatch_native_api_diagnostics.json. V2 also inspects HatchStorm and optionally saves Geode/lava_native_HatchStorm.lua and lava_native_PetsUI.lua if the executor supports decompile. No egg requests are sent."})
eggs:Paragraph({Title="Manual Hatch Diagnostics",Desc="The genuine server action is Hatch, with 'Lava' and quantity 20. Export after your paid trial to verify acceptance, server Wait, gem changes and response duration. Auto stops on rejections, unexpected or partial results."})
eggs:Button({Title="Export Lava Egg Post-Test Reports",Callback=function()
    local okHatch,errHatch=LavaFastHatch.Export()
    local okLobby,errLobby=LavaEggInspector.Export()
    local summary="Hatch response: "..(okHatch and "saved"or tostring(errHatch))
        .." | Lobby configuration: "..(okLobby and "saved"or tostring(errLobby))
    lavaFastStatus:SetDesc(LavaFastHatch.Status.."\n"..summary)
    NativeUI:Notify({Title="Lava Egg Post-Test Reports",Content=summary})
end})
eggs:Paragraph({Title="Post-Test Files",Desc="Upload Geode/lava_egg_hatch_diagnostics.json after the single paid test. The response log confirms the exact number of pets, server cooldown/Busy and whether gems changed."})
eggs:Section({Title="Lava Egg Investigation"})
eggs:Paragraph({Title="Read-Only Lobby Redump",Desc="While in the game Lobby, capture actual Lava/Pets egg configuration, PetsUI API, visible hatch buttons (including 20x), relevant remotes and egg objects. No purchases, hatch requests, animation modifications, or automatic file writes."})
local lavaEggDumpStatus=eggs:Paragraph({Title="Lava Egg Redump",Desc="Not captured. Press the button in the Lobby."})
eggs:Button({Title="Redump Lava Eggs (Lobby)",Callback=function()
    local ok,path=LavaEggInspector.Export()
    lavaEggDumpStatus:SetDesc(LavaEggInspector.Status)
    NativeUI:Notify({Title="Lava Egg Redump",Content=ok and("Saved "..tostring(path))or LavaEggInspector.Status})
end})
mutations:Section({Title="Class Mutation Rolls"})
local mutationClass=mutations:Dropdown({Title="Class to Mutate",Values=ClassMutations.ClassOptions(),Value=ClassMutations.Class,Callback=ClassMutations.SetClass})
mutations:Button({Title="Refresh Owned Classes",Callback=function()mutationClass:Refresh(ClassMutations.ClassOptions())end})
local mutationScroll=mutations:Dropdown({Title="Mutation Scroll Type",Values={"Normal","Lucky"},Value="Normal",Callback=ClassMutations.SetScrollType})
local mutationTarget=mutations:Dropdown({Title="Stop at Mutation",Values=ClassMutations.TargetOptions(),Value="Glitched",Callback=ClassMutations.SetTarget})
local mutationLimit=mutations:Slider({Title="Maximum Rolls per Start",Step=1,Value={Min=1,Max=1000,Default=10},Callback=ClassMutations.SetLimit})
local mutationToggle=mutations:Toggle({Title="Auto Roll Class Mutation",Value=false,Callback=function(value)
    if value and not FarmSafety.Stopped then ClassMutations.Start()
    elseif not value and ClassMutations.Enabled then ClassMutations.Stop()end
end})
mutations:Paragraph({Title="Mutation Rolling",Desc="Uses one selected scroll per accepted roll. Keeps the better mutation. Stops at the target or higher, the roll limit, no scrolls, or a server error. One request at a time, without the roll animation. Settings apply on the next start; rolling starts off after reloading."})
local mutationStatus=mutations:Paragraph({Title="Class Mutation Status",Desc="Paused"})
settings:Section({Title="Farm Safety / Intervention Stop"})
settings:Paragraph({Title="Local-Only Safety Interlock",Desc="Stops all farm automation if the game activates your official WatchRun Spectator state. Optional experimental checks watch only explicit local admin restriction flags and native Tools.DevPaused. Server-only moderation commands cannot be detected. This cannot interfere with or bypass another player's camera, game or permissions."})
local farmSafetyEnableToggle=settings:Toggle({
    Title="Auto-stop on Local Intervention",Value=true,
    Callback=FarmSafety.SetEnabled
})
local farmSafetyOfficialToggle=settings:Toggle({
    Title="Stop on Official Spectator State",Value=true,
    Callback=FarmSafety.SetWatchOfficial
})
local farmSafetyRestrictionToggle=settings:Toggle({
    Title="Also Check Local Admin Restriction Flags (Experimental)",
    Value=false,Callback=FarmSafety.SetWatchRestrictions
})
local farmSafetyStatus=statusUtilityGroup:Paragraph({
    Title="Farm Safety / Admin Intervention Status",
    Desc="Armed — watching server-controlled local Spectator state"
})
settings:Button({Title="EMERGENCY STOP ALL AUTOMATION",Callback=function()
    local ok,reason=FarmSafety.StopAll("Manual emergency stop")
    farmSafetyStatus:SetDesc(FarmSafety.Status)
    NativeUI:Notify({Title="Farm Safety",Content=FarmSafety.Status})
end})
settings:Button({Title="Re-arm Farming Manually",Callback=function()
    local ok,reason=FarmSafety.Rearm()
    farmSafetyStatus:SetDesc(FarmSafety.Status)
    NativeUI:Notify({Title="Farm Safety",Content=ok and FarmSafety.Status or tostring(reason)})
end})
settings:Button({Title="Export Farm Safety Diagnostics",Callback=function()
    local ok,err=FarmSafety.Export()
    NativeUI:Notify({Title="Farm Safety Dump",
        Content=ok and"Saved Geode/farm_safety_diagnostics.json"or tostring(err)})
end})
settings:Section({Title="AFK Protection"})
local antiAfkToggle=settings:Toggle({Title="Anti AFK (Lobby & All Rounds)",Value=true,Callback=function(value)
    AntiAFK.SetEnabled(value)
end})
local antiAfkStatus=statusUtilityGroup:Paragraph({Title="Anti AFK Status",Desc="Armed in lobby and all rounds; uses an idle-triggered virtual input and a quiet-activity watchdog."})
settings:Section({Title="Loading Cutscene"})
local skipIntroToggle=settings:Toggle({Title="Hide Chapter Loading Cutscene",Value=true,Callback=function(value)
    IntroVisuals.SetEnabled(value)
end})
local introStatus=statusUtilityGroup:Paragraph({Title="Intro Suppression Status",Desc="Moves loading and intro visuals offscreen without disabling the game's UI."})
local introExtras=settings:CollapsibleGroup({Title="Experimental Intro Pickup",Opened=false})
local earlyPickupToggle=introExtras:Toggle({Title="Try Pickup During Intro",Value=true,Callback=function(value)
    Pickup.SetEarlyIntro(value)
end})
local earlyPickupStatus=statusUtilityGroup:Paragraph({Title="Early Pickup Status",Desc="One test request while Waiting. Continues only if the bag increases before normal Mining; otherwise waits and resumes when Mining starts."})
settings:Section({Title="Configuration"})
local config=Window.ConfigManager:CreateConfig("default")
local autoLoad=settings:Toggle({Title="Auto-load Saved Config",Value=true,Callback=function()end})
config:Register("AutoLoadConfig",autoLoad)
config:Register("FarmSafetyEnabled",farmSafetyEnableToggle)
config:Register("FarmSafetyWatchOfficial",farmSafetyOfficialToggle)
config:Register("FarmSafetyWatchRestrictions",farmSafetyRestrictionToggle)
config:Register("TopDownSecondPass",topDownSecondToggle)
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
config:Register("AutoUpgradeCrackPower",crackPowerToggle)
config:Register("FastRustyChisel",fastChiselToggle)
config:Register("RustyChiselCooldownMultiplier",fastChiselSpeed)
config:Register("PowerFirst",powerFirstToggle)
config:Register("FastUpgradePurchases",fastUpgradeToggle)
config:Register("NormalMiningAbility",normalAbilityToggle)
config:Register("BossSpawnAbility",bossAbilityToggle)
config:Register("ReserveBossAbility",reserveBossAbilityToggle)
config:Register("EscapeFarmOvercharge",escapeOverchargeToggle)
config:Register("AutoEscape",escapeToggle)
config:Register("EndlessHover",hoverHeight)
config:Register("EndlessFlySpeed16",endlessFlySpeed)
config:Register("WinFarmFly",winFarmFlightToggle)
config:Register("CrackSellFlyTravel",crackFlyTravel)
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
statusMovementGroup:Section({Title="Client Movement Recorder"})
statusMovementGroup:Paragraph({Title="What Can Be Recorded",Desc="The server's private anti-cheat logs and actual kick verdicts are not accessible. An opt-in rolling recorder samples your own observed movement, velocity, phase, Fly + Noclip, client-visible movement-related output, and potential movement/security script names. It writes locally to Geode/anticheat_client_diagnostics.json about every 0.6s while ON, so a disconnect may leave useful pre-kick evidence."})
local movementDiagnosticStatus=statusMovementGroup:Paragraph({
    Title="Movement Recorder Status",Desc="OFF. Enable before trying Auto Endless. Only local observations are captured."
})
local movementRecorderToggle=statusMovementGroup:Toggle({
    Title="Record Pre-Kick Movement (Opt-in)",Value=false,
    Callback=function(value)
        MovementDiagnostics.SetEnabled(value)
    end
})
-- Older on-demand dump buttons are intentionally retired from Status &
-- Logs. The underlying inspectors and exports remain in the Hub for
-- compatibility, and existing files in Geode/ are not deleted.
statusDeveloperGroup:Section({Title="Native MTGClient DevMenu Boot"})
local devKitReadinessStatus=statusDeveloperGroup:Paragraph({
    Title="MTGDevKit Readiness",
    Desc="Not monitored — export diagnostics for a one-time snapshot."
})
DevMenuStartupInspector.OnMonitorUpdate=function(snap)
    devKitReadinessStatus:SetDesc(snap.Status..
        " | Kit modules: "..tostring(snap.ModuleCount)..
        " | Children: "..tostring(snap.ChildCount)..
        "/"..tostring(snap.ExpectedChildren or 3))
end
statusDeveloperGroup:Toggle({
    Title="Monitor Native DevMenu Readiness (Read Only)",
    Value=false,
    Callback=function(value)
        DevMenuStartupInspector.SetDevKitMonitor(value)
        if not value then
            devKitReadinessStatus:SetDesc("Monitoring OFF — manual export still captures a snapshot.")
        end
    end
})
statusDeveloperGroup:Paragraph({
    Title="DevMenu Access",
    Desc="No developer-menu activation control: the native module and authorization have not been confirmed. Monitoring does not grant access."
})
local devMenuStartupStatus=statusDeveloperGroup:Paragraph({
    Title="DevMenu Startup Status",
    Desc="Not captured — inspect native MTGClient startup and relevant retained F9 console messages."
})
statusDeveloperGroup:Button({
    Title="Inspect DevMenu Startup + MTGDevKit + F9 (Read Only)",
    Callback=function()
        devMenuStartupStatus:SetDesc("Checking MTGClient DevMenu startup and retained F9 console history...")
        task.spawn(function()
            local ok,file=DevMenuStartupInspector.Export()
            devMenuStartupStatus:SetDesc(DevMenuStartupInspector.Status)
            NativeUI:Notify({Title="DevMenu Startup",
                Content=ok and("Saved "..tostring(file))
                    or("Failed: "..tostring(file))})
        end)
    end
})
-- Local-only diagnostic tools: this is not the game's developer menu.
-- Never clone, move, require, invoke or manufacture native DevKit modules.
localDevTab:Section({Title="Beyy Local Developer Console"})
localDevTab:Paragraph({
    Title="Separate Local Interface",
    Desc="Open a reconstructed, local-only console with Overview, UI Explorer, Client Scripts, Input Bindings, and Console Stats pages. This is NOT the native MTGDevKit or DevMenu; no server or developer commands."
})
localDevTab:Button({
    Title="Open / Close Local Developer Console",
    Callback=function()
        local ok,opened=LocalDeveloperConsole.Toggle()
        if not ok then
            NativeUI:Notify({
                Title="Local Developer Console",
                Content="Failed: "..tostring(opened)
            })
        end
    end
})
localDevTab:Button({
    Title="Export Local Console Snapshot",
    Callback=function()
        task.spawn(function()
            local ok,path=LocalDeveloperConsole.Export()
            NativeUI:Notify({
                Title="Local Developer Console",
                Content=ok and ("Saved "..tostring(path))
                    or ("Failed: "..tostring(path))
            })
        end)
    end
})
localDevTab:Paragraph({
    Title="Local Console File",
    Desc="Geode/local_developer_console_diagnostics.json | Read-only UI names, client script names, input action names, camera/position, and aggregate F9 warning/error counts. No console text or password contents."
})
localDevTab:Section({Title="Local Developer Tools"})
localDevTab:Paragraph({
    Title="Access",
    Desc="F2 was only found as an Admin configuration hint. No working shortcut or password prompt has been confirmed. This is a local inspector, not a way to bypass game developer permissions."
})
local nativeDevStatus=localDevTab:Paragraph({
    Title="Native DevMenu",
    Desc="Not checked yet. Click Refresh Client State."
})
local guiInspectorStatus=localDevTab:Paragraph({
    Title="Local UI",
    Desc="Not inspected yet."
})
local function localDevRefresh()
    local snapshot=DevMenuStartupInspector.InspectDevKit()
    local player=game:GetService("Players").LocalPlayer
    local playerGui=player and player:FindFirstChild("PlayerGui")
    local mtg=game:GetService("ReplicatedStorage"):FindFirstChild("MTG")
    local errorValue=player and player:GetAttribute("ClientError")
    local role=mtg and mtg:GetAttribute("Role")
    nativeDevStatus:SetDesc(snapshot.Status
        .." | MTGDevKit="..(snapshot.Found and "present"or"missing")
        .." | Count="..tostring(snapshot.ChildCount)
        .."/"..tostring(snapshot.ExpectedChildren or 3)
        .." | Role="..tostring(role or "unknown")
        .." | ClientError="..(errorValue==nil and "none"or"present"))
    local guiCount=0
    local visibleCount=0
    local visibleNames={}
    if playerGui then
        for _,child in ipairs(playerGui:GetChildren())do
            if child:IsA("ScreenGui")then
                guiCount+=1
                if child.Enabled then
                    visibleCount+=1
                    if #visibleNames<8 then
                        local name=tostring(child.Name)
                        if not name:lower():find("password",1,true)
                            and not name:lower():find("token",1,true)then
                            visibleNames[#visibleNames+1]=name:sub(1,55)
                        end
                    end
                end
            end
        end
    end
    guiInspectorStatus:SetDesc("Client GUIs: "..tostring(guiCount)
        .." | Enabled: "..tostring(visibleCount)
        .." | Names: "..(#visibleNames>0 and table.concat(visibleNames,", ") or "none"))
end
localDevTab:Button({
    Title="Refresh Client State (Read Only)",
    Callback=localDevRefresh
})
localDevTab:Button({
    Title="Export DevMenu Startup + DevKit Diagnostics",
    Callback=function()
        task.spawn(function()
            local ok,path=DevMenuStartupInspector.Export()
            localDevRefresh()
            NativeUI:Notify({
                Title="Local DevTools",
                Content=ok and ("Saved "..tostring(path)) or tostring(path)
            })
        end)
    end
})

localDevTab:Section({Title="Developer Entry Point Evidence"})
local entryStatus=localDevTab:Paragraph({
    Title="Current Evidence",
    Desc="Not checked; identifies available native modules, developer-named GUIs and actual F2 action bindings."
})
localDevTab:Button({
    Title="Inspect Native Developer Entry Points (Read Only)",
    Callback=function()
        task.spawn(function()
            local ok,err=pcall(DeveloperEntryInventory.Capture)
            entryStatus:SetDesc(ok and DeveloperEntryInventory.Status
                or ("Inventory unavailable: "..tostring(err)))
        end)
    end
})
localDevTab:Button({
    Title="Export Admin Button + Access Evidence (Read Only)",
    Callback=function()
        task.spawn(function()
            local ok,path=DeveloperEntryInventory.Export()
            entryStatus:SetDesc(DeveloperEntryInventory.Status)
            NativeUI:Notify({
                Title="Developer Entry Evidence",
                Content=ok and ("Saved "..tostring(path))
                    or ("Failed: "..tostring(path))
            })
        end)
    end
})
localDevTab:Paragraph({
    Title="Compare Game Phases",
    Desc="Export in Lobby and Game. Reports include read-only admin-button GUI candidates, bounded static references to ShowButton/DevMenu, and missing modules. No login or developer action is attempted."
})
localDevTab:Section({Title="Optional F2 Diagnostics (Shortcut Unverified)"})
localDevTab:Paragraph({
    Title="F2 + Temporary Popup Trace",
    Desc="Observes F2 input, UI creation/removal, brief visibility changes, input-field focus (never contents), and native F2 bindings. Also supports taking a manual snapshot while a prompt is visible. Read only."
})
local f2Status=localDevTab:Paragraph({
    Title="F2 Recorder Status",
    Desc="OFF | Enable the monitor, press F2, then export."
})
F2KeyInspector.OnChange=function(status)
    f2Status:SetDesc(status)
end
localDevTab:Toggle({
    Title="Monitor F2 + Popups (Read Only)",
    Value=false,
    Callback=function(value)
        F2KeyInspector.SetEnabled(value)
    end
})
localDevTab:Button({
    Title="Export F2 + Toast + Input GUI Diagnostics",
    Callback=function()
        task.spawn(function()
            local ok,path=F2KeyInspector.Export()
            NativeUI:Notify({
                Title="F2 Key Diagnostics",
                Content=ok and ("Saved "..tostring(path)) or tostring(path)
            })
        end)
    end
})
localDevTab:Button({
    Title="Snapshot Current Prompt UI (Read Only)",
    Callback=function()
        task.spawn(function()
            local ok,path=F2KeyInspector.Export()
            NativeUI:Notify({
                Title="Prompt UI Snapshot",
                Content=ok and ("Saved "..tostring(path)) or tostring(path)
            })
        end)
    end
})
localDevTab:Paragraph({
    Title="Targeted F2 Export",
    Desc="Geode/f2_key_diagnostics.json | Turn on the monitor, close BeyyHub, press F2, wait 3 seconds, reopen and export. The report links toast creation times to F2 presses and shows input-field parent/sibling GUI names without capturing any text."
})
localDevTab:Paragraph({
    Title="No Privilege Elevation",
    Desc="No DevAction requests, synthetic MTGDevKit, password recovery, menu injection or privileged commands."
})
settings:Section({Title="Menu"})
local menuKey=settings:Keybind({Title="Menu Toggle Key",Value="RightControl",Callback=function(value)Window:SetToggleKey(value)end})
config:Register("MenuToggleKey",menuKey)
local continuation
local queueToggle=settings:Toggle({Title="Queue on Teleport",Value=true,Callback=function(value)
    if continuation then continuation.SetEnabled(value==true and not FarmSafety.Stopped)end
end})
config:Register("QueueOnTeleport",queueToggle)
continuation=createLiveGeodeTeleport(function()
    return {Pickup=Pickup.Enabled,FastPickup=Pickup.FastPickup,Range=Pickup.MaxRange,WalkSpeedTriple=GameWalkSpeed.Enabled,AntiAFK=AntiAFK.Enabled,HideChapterIntro=IntroVisuals.Enabled,EarlyIntroPickup=Pickup.EarlyIntroEnabled,Eggs=Eggs.Enabled,CrackSell=CrackSell.Enabled,
        BagDelay=CrackSell.Interval,CrackSellContinuous=(FarmEscapes.Enabled
            and FarmEscapes.PreviousContinuousMode~=nil)
            and FarmEscapes.PreviousContinuousMode or CrackSell.Continuous,
        FastCrackTravel=CrackSell.FastTravel,CrackSellFlyTravel=CrackSell.FlyTravel,WinFarmFly=Endless.WinFarmFly,TurboCrackSell=CrackSell.Turbo,CrackSellRepeatInterval=CrackSell.RepeatInterval,MagnetUpgrades=MagnetUpgrades.Enabled,CrackPowerUpgrades=CrackPowerUpgrades.Enabled,FastRustyChisel=FastChisel.Enabled,RustyChiselCooldownMultiplier=FastChisel.Multiplier,PowerFirst=MagnetUpgrades.PowerFirst,FastUpgradePurchases=MagnetUpgrades.FastPurchases,NormalMiningAbility=abilityPrefs.NormalMining,BossSpawnAbility=abilityPrefs.BossOnSpawn,ReserveBossAbility=abilityPrefs.ReserveForBoss,EscapeFarmOvercharge=abilityPrefs.EscapeFarmAlways,Escape=Escape.Enabled,AutoFarmEscapes=FarmEscapes.Enabled,TopDownSecondPass=Endless.TopDownSecondPass,Endless=Endless.Enabled,EndlessHover=Endless.Hover,EndlessFlySpeed16=Endless.FlySpeed,BossAssist=Endless.BossAssist,RapidBoss=Endless.RapidBoss,RapidBossInterval=Endless.RapidBossInterval,AutoPerks=AutoPerks.Enabled,DamagePerks=AutoPerks.DamageFocus,AdaptivePerks=AutoPerks.Adaptive,LastWinSweep=Endless.LastWinSweep,MenuKey=Window.ToggleKey.Name,MenuClosed=Window.Closed}
end)
Hub.Teleport=continuation
FarmSafety.OnStop=function(reason)
    if continuation and continuation.Enabled then
        -- Stop queueing/reloading without permanently unloading the queue
        -- controller, so manual re-arming can restore the user's preference.
        continuation.SetEnabled(false)
        if queueToggle then queueToggle:Set(false)end
    end
    NativeUI:Notify({Title="Farm Safety",Content="Automation stopped: "..tostring(reason)})
end
if FarmSafety.Stopped then FarmSafety.OnStop(FarmSafety.LastTrigger)end
FarmEscapes.SetQueueEnabler(function()
    if FarmSafety.Stopped then return end
    if not continuation.Enabled then queueToggle:Set(true)end
end)
settings:Button({Title="Unload Hub",Callback=Hub.Unload})
local resumed=env.__GeodeTeleportResume
env.__GeodeTeleportResume=nil
local loaded,loadError=config:Load(true,type(resumed)=="table"and resumed.GameId==10770110947)
-- This release enables both new Chisel improvements by default, including
-- saved pre-v1.10.74 configs that left the old opt-in Power toggle OFF.
if not FarmSafety.Stopped then
    crackPowerToggle:Set(true)
    fastChiselToggle:Set(true)
end
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
    crackFlyTravel:Set(resumed.CrackSellFlyTravel~=false)
    winFarmFlightToggle:Set(resumed.WinFarmFly~=false)
    fastCrackTravel:Set(resumed.FastCrackTravel~=false)
    turboCrack:Set(resumed.TurboCrackSell~=false)
    repeatInterval:Set(tonumber(resumed.CrackSellRepeatInterval)or 10)
    hoverHeight:Set(tonumber(resumed.EndlessHover)or 6.5)
    endlessFlySpeed:Set(tonumber(resumed.EndlessFlySpeed16)or 16)
    bossCritToggle:Set(resumed.BossAssist~=false)
    topDownSecondToggle:Set(resumed.TopDownSecondPass~=false)
    rapidBossToggle:Set(resumed.RapidBoss==true)
    rapidBossInterval:Set(tonumber(resumed.RapidBossInterval)or .05)
    damageFocusToggle:Set(resumed.DamagePerks==true)
    adaptivePerksToggle:Set(resumed.AdaptivePerks~=false)
    if type(resumed.LastWinSweep)=="table"then
        Endless.LastWinSweep=resumed.LastWinSweep
    end
    if type(resumed.MenuKey)=="string"and Enum.KeyCode[resumed.MenuKey]then menuKey:Set(resumed.MenuKey)end
    pickupToggle:Set(resumed.Pickup==true)
    eggToggle:Set(resumed.Eggs==true)
    crackToggle:Set(resumed.CrackSell==true)
    upgradeToggle:Set(resumed.MagnetUpgrades==true)
    crackPowerToggle:Set(resumed.CrackPowerUpgrades~=false)
    fastChiselSpeed:Set(tonumber(resumed.RustyChiselCooldownMultiplier)or .6)
    fastChiselToggle:Set(resumed.FastRustyChisel~=false)
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
        FarmSafety.Check()
        farmSafetyStatus:SetDesc(FarmSafety.Status
            .."\nTrigger: "..tostring(FarmSafety.LastTrigger or"None")
            .." | Stopped: "..tostring(FarmSafety.Stopped)
            .." | Experimental flags: "..tostring(FarmSafety.WatchRestrictions))
        if bossCritToggle.Value~=Endless.BossAssist then
            bossCritToggle:Set(Endless.BossAssist)
        end
        if walkSpeedToggle.Value~=GameWalkSpeed.Enabled then
            walkSpeedToggle:Set(GameWalkSpeed.Enabled)
        end
        if antiAfkToggle.Value~=AntiAFK.Enabled then
            antiAfkToggle:Set(AntiAFK.Enabled)
        end
        if perkToggle.Value~=AutoPerks.Enabled then perkToggle:Set(AutoPerks.Enabled)end
        if farmEscapesToggle.Value~=FarmEscapes.Enabled then farmEscapesToggle:Set(FarmEscapes.Enabled)end
        farmEscapesStatus:SetDesc(FarmEscapes.Stage..": "..FarmEscapes.Status
            .."\nEscapes: "..FarmEscapes.Rounds.." | Turn-ins: "..FarmEscapes.TurnIns
            .." | Confirmed replays: "..FarmEscapes.ReplayTransitions
            .."\nLowest-ring sweep: "..tostring(Endless.WinSweepMode).." @ "
            ..string.format("%.1fx",Endless.WinSweepSpeed or 10)
            .." | Confirmed geodes/s: "..string.format("%.1f",Endless.WinSweepItemsPerSecond or 0)
            .."\nSweep pass: "..tostring(Endless.WinSweepHeightRing or 1)..(Endless.TopDownSecondPass and "/2 - " or "/3 - ")
            ..tostring(Endless.WinSweepCoveragePass or"Base outer")
            .." | Height offset: "..string.format("%+.1f",Endless.WinSweepHeightOffset or 0)
            .." | Core radius: "..string.format("%.1f",Endless.WinSweepCoreRadius or 0)
            .." | Core pickups: "..tostring(Endless.WinSweepCoreItems or 0)
            .." | Completed laps: "..tostring(Endless.WinSweepCompletedLaps or 0)
            .." | Early base switches: "..tostring(Endless.WinSweepEarlyBaseSkips or 0)
            .." | Early core switches: "..tostring(Endless.WinSweepEarlyCoreSkips or 0)
            .." | Top-down laps: "..tostring(Endless.WinSweepTopDownSuccesses or 0)
            .." | Top fallbacks: "..tostring(Endless.WinSweepTopDownFallbacks or 0)
            .." | Top items: "..tostring(Endless.WinSweepTopDownItems or 0)
            .." | Core boosts: "..tostring(Endless.WinSweepCoreSpeedBoosts or 0)
            .."\nMound plan ready: "..tostring(Endless.WinSweepPlanBuildWaitMs or 0).."ms"
            .." | GEO-MAG sweep ready: "..tostring(Endless.WinSweepFireReady)
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
        endlessStatus:SetDesc(Endless.Status.."\nRing: "..tostring(Endless.RingName or"Waiting").." / "..tostring(Endless.RingCount or 0).." | Hover: "..Endless.Hover.." studs\nHeld fire: "..(Endless.NativeHeldActive and"Active"or"Paused").." | Native shots: "..Endless.NativeFireEvents.." | Items: "..Endless.NativeItems.."\nAbility: "..tostring(Endless.AbilityStatus or"Waiting").." | Confirmed uses: "..tostring(Endless.AbilityConfirmed or 0).."\nOrbit: "..string.format("%.1fx (~%.2fs/lap)",Endless.OrbitSpeedMultiplier or 10,Endless.OrbitLapSeconds or 1.4).." | Laps: "..Endless.Laps.." | Boss hits: "..Endless.Hits.." | Weak hits: "..Endless.WeakHits.." | Critical target: "..tostring(Endless.ActiveBossSpot or "None").."\nBoss tool: "..tostring(Endless.BossToolId or"Waiting").." | Ready: "..tostring(Endless.BossToolReady).." | Equip tries: "..tostring(Endless.BossEquipAttempts).."\nCrack & Sell: "..(CrackSell.Continuous and "Continuous" or "One trip").." | "..CrackSell.Status
            .."\nEscape farm sweep: "..tostring(Endless.WinSweepMode).." @ "..string.format("%.1fx",Endless.WinSweepSpeed or 10)
            .." | Accepted items/s: "..string.format("%.1f",Endless.WinSweepItemsPerSecond or 0)
            .." | Radius scale: "..string.format("%.2f",Endless.WinSweepRadiusScale or 1)
            .." | Win Farm coverage: "..tostring(Endless.WinSweepHeightRing or 1).."/3"
            .."\nSmooth flight: "..tostring(Endless.OrbitFlightMode or "Idle").." | Ring radius: "..string.format("%.1f",Endless.OrbitRadius or 0).." | Radial error: "..string.format("%+.1f",Endless.OrbitRadialError or 0).." | Height error: "..string.format("%+.1f",Endless.OrbitHeightError or 0).." | Last lap: "..string.format("%.1fs",Endless.OrbitLapSeconds or 0)
            .."\nRapid boss pulses: "..Endless.RapidBossPulses.." | Observed boss hits/s: "..string.format("%.2f",Endless.BossObservedHitsPerSecond or 0).." | Boss HP decrease/s: "..string.format("%.2f",Endless.BossHPChangePerSecond or 0))
        if escapeToggle.Value~=Escape.Enabled then escapeToggle:Set(Escape.Enabled)end
        escapeStatus:SetDesc(Escape.Status.."\nOpen-lift entries: "..Escape.Attempts.." | Lift openings: "..Escape.GateOpens.." | Failures: "..Escape.Failures
            .." | Gate-to-first-entry: "..string.format("%.2fs",Escape.FirstEnterDelay or 0)
            .." | Gate-to-escape: "..string.format("%.2fs",Escape.ConfirmedSeconds or 0)
            .."\nElevator lock diagnostics: Geode/elevator_lock_diagnostics.json (manual export only)")
        if pickupToggle.Value~=Pickup.Enabled then pickupToggle:Set(Pickup.Enabled)end
        if eggToggle.Value~=Eggs.Enabled then eggToggle:Set(Eggs.Enabled)end
        LocalSpectate.Tick()
        if LocalSpectate.SelectedName
            and localSpectatePlayer.Value~=LocalSpectate.SelectedName then
            localSpectatePlayer:Set(LocalSpectate.SelectedName)
        end
        if localFreeCamToggle.Value~=LocalSpectate.FreeCam then
            localFreeCamToggle:Set(LocalSpectate.FreeCam)
        end
        localSpectateStatus:SetDesc(LocalSpectate.Status
            .."\nTarget: "..tostring(LocalSpectate.TargetName or"None")
            .." | Active: "..tostring(LocalSpectate.Active)
            .." | FreeCam: "..tostring(LocalSpectate.FreeCam))
        if lavaAutoToggle.Value~=LavaFastHatch.Enabled then
            lavaAutoToggle:Set(LavaFastHatch.Enabled)
        end
        lavaFastStatus:SetDesc(LavaFastHatch.Status
            .."\nOpened: "..LavaFastHatch.Opened.." | Accepted batches: "
            ..LavaFastHatch.AcceptedBatches.." | Server Busy: "
            ..LavaFastHatch.BusyReplies.." | Last batch: "
            ..LavaFastHatch.LastCount.." | Response: "
            ..LavaFastHatch.LastResponseMs.."ms"
            .."\nAdaptive: "..tostring(LavaFastHatch.AdaptiveSpeed)
            .." | Gap: "..string.format("%.2fs",LavaFastHatch.AdaptiveGap or 0)
            .." | Probes: "..tostring(LavaFastHatch.ProbeSteps)
            .." | Timing backoffs: "..tostring(LavaFastHatch.TimingBackoffs)
            .." | Accepted interval: "..string.format("%.2fs",
                LavaFastHatch.LastAcceptedInterval or 0))
        if crackToggle.Value~=CrackSell.Enabled then crackToggle:Set(CrackSell.Enabled)end
        if upgradeToggle.Value~=MagnetUpgrades.Enabled then upgradeToggle:Set(MagnetUpgrades.Enabled)end
        if crackPowerToggle.Value~=CrackPowerUpgrades.Enabled then crackPowerToggle:Set(CrackPowerUpgrades.Enabled)end
        if fastChiselToggle.Value~=FastChisel.Enabled then fastChiselToggle:Set(FastChisel.Enabled)end
        fastChiselStatus:SetDesc(FastChisel.Status.." | Multiplier: "..string.format("%.2f",FastChisel.Multiplier)
            .." | Native failures: "..FastChisel.Failures)
        local player=game:GetService("Players").LocalPlayer
        local mtg=game:GetService("ReplicatedStorage"):FindFirstChild("MTG")
        local state=mtg and mtg:FindFirstChild("State")
        walkSpeedStatus:SetDesc(GameWalkSpeed.Status)
        movementDiagnosticStatus:SetDesc(MovementDiagnostics.Status
            .." | Samples: "..MovementDiagnostics.Samples
            .." | Sample errors: "..MovementDiagnostics.SampleFailures
            .." | File errors: "..MovementDiagnostics.PersistenceFailures
            .." | Possible spikes: "..MovementDiagnostics.Alerts
            .." | Saves: "..MovementDiagnostics.Writes
            .." | Last measured: "..string.format("%.1f",MovementDiagnostics.CurrentSpeed).." studs/s"
            ..(MovementDiagnostics.LastSampleError and (" | Last sample error: "..MovementDiagnostics.LastSampleError) or ""))
        antiAfkStatus:SetDesc(AntiAFK.Status.." | Successful inputs: "..AntiAFK.Successes.." | Failures: "..AntiAFK.Failures.." | Last: "..AntiAFK.LastSource)
        introStatus:SetDesc(IntroVisuals.Status.." | Visual relocations: "..IntroVisuals.Hidden)
        earlyPickupStatus:SetDesc(Pickup.EarlyIntroStatus.." | Attempts: "..Pickup.EarlyAttempts.." | Server replies with items: "..Pickup.EarlyConfirmed)
        crackPowerStatus:SetDesc(CrackPowerUpgrades.Status.." | Level: "..CrackPowerUpgrades.Level.."/"..CrackPowerUpgrades.MaxLevel
            .." | Confirmed: "..CrackPowerUpgrades.Confirmed.." | Requests: "..CrackPowerUpgrades.Requests
            .." | Busy: "..CrackPowerUpgrades.BusyResponses)
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
        local activeFarm=FarmEscapes.Enabled and "Auto Farm Escapes"
            or Endless.Enabled and "Auto Endless"
            or Pickup.Enabled and "Auto Pickup" or "Idle"
        statusOverview:SetDesc("Farm: "..activeFarm
            .." | Stage: "..tostring(FarmEscapes.Enabled and FarmEscapes.Stage or Endless.Stage)
            .."\nGeodes: "..tostring(Pickup.Items or 0)
            .." | Endless pickups: "..tostring(Endless.NativeItems or 0)
            .." | Critical hits: "..tostring(Endless.WeakHits or 0)
            .."\nCrack cycles: "..tostring(CrackSell.Cycles or 0)
            .." | Escapes: "..tostring(FarmEscapes.Rounds or 0)
            .." | Recorder: "..(MovementDiagnostics.Enabled and "ON" or "Off")
            .."\nMovement samples: "..tostring(MovementDiagnostics.Samples or 0)
            .." | Sample errors: "..tostring(MovementDiagnostics.SampleFailures or 0))
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