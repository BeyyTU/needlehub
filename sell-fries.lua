-- BeyyHub | Sell Fries! | v0.3.0
-- Native BeyyHub user interface + official Butter launcher + independent assists.
-- Butter is distributed by kode-sec and uses a separate key/protected code.
-- This script DOES NOT bypass that key or claim to control Butter's internal settings.
if not game:IsLoaded() then game.Loaded:Wait() end
local MAIN_PLACE = 139542527731344
local LOBBY_PLACE = 94891079210424
if game.PlaceId ~= MAIN_PLACE then
    warn("[BeyyHub Fries] Join the main Sell Fries! game, not the lobby. Current place: "..tostring(game.PlaceId))
    return
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PromptService = game:GetService("ProximityPromptService")
local localPlayer = Players.LocalPlayer
if not localPlayer then warn("[BeyyHub Fries] Player is not available"); return end
local playerGui = localPlayer:WaitForChild("PlayerGui",15)
if not playerGui then warn("[BeyyHub Fries] PlayerGui missing"); return end
local env = type(getgenv) == "function" and getgenv() or _G
if type(env.BeyyFriesHub) == "table" and type(env.BeyyFriesHub.Unload) == "function" then
    pcall(env.BeyyFriesHub.Unload)
end
for _,parent in ipairs({playerGui,game:GetService("CoreGui")}) do
    pcall(function()
        for _,old in ipairs(parent:GetChildren()) do
            if old:IsA("ScreenGui") and old.Name == "BeyyFriesNativeHub" then old:Destroy() end
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
        local gui=node("ScreenGui",parent,{Name="BeyyFriesNativeHub",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
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
        w.ConfigManager=configManager(options.Folder or "BeyyFriesHub")
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


local version = "0.3.0"
local state = {
    Running=true, Version=version, ButterStatus="Not launched",
    ButterLaunching=false, ButterLoaded=false,
    PromptAssist=false, AntiAFK=false, Paused=false, SpeedMultiplier=1,
    PromptAttempts=0, PromptFailures=0, Logs={}, Started=os.clock()
}
env.BeyyFriesHub = state
local connections = {}
local promptVisible = setmetatable({}, {__mode="k"})
local lastPrompt = setmetatable({}, {__mode="k"})
local currentHumanoid, baseSpeed
local window, statusPanel, settingControls
local function on(signal, fn)
    local c=signal:Connect(fn); connections[#connections+1]=c; return c
end
local function log(kind, detail)
    local entry={Seconds=math.floor((os.clock()-state.Started)*10)/10, Kind=kind, Detail=tostring(detail or "")}
    state.Logs[#state.Logs+1]=entry
    if #state.Logs>110 then table.remove(state.Logs,1) end
    print("[BeyyHub Fries] "..entry.Kind..": "..entry.Detail)
end
local function notify(title,msg)
    if window and window.Notice then
        window.Notice.Text=tostring(title or "BeyyHub")..": "..tostring(msg or "")
    end
end
local function humanoid()
    local character=localPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end
local function maintainSpeed()
    local h=humanoid()
    if h~=currentHumanoid then
        currentHumanoid=h
        baseSpeed=h and h.WalkSpeed or nil
    end
    if not h or not baseSpeed or h.Health<=0 then return end
    if state.SpeedMultiplier <= 1 then
        if state._speedApplied then
            h.WalkSpeed=baseSpeed
            state._speedApplied=false
        else
            baseSpeed=h.WalkSpeed
        end
        return
    end
    local target=math.clamp(baseSpeed*state.SpeedMultiplier,1,100)
    if math.abs(h.WalkSpeed-target)>0.05 then h.WalkSpeed=target end
    state._speedApplied=true
end
local function restoreSpeed()
    if currentHumanoid and currentHumanoid.Parent and baseSpeed then
        pcall(function()currentHumanoid.WalkSpeed=baseSpeed end)
    end
end
local keywords={"potato","crate","peel","fry","fries","cook","collect","vacuum","scoop","serve","food","tray"}
local function productionPrompt(prompt)
    local words=(tostring(prompt.Name).." "..tostring(prompt.ActionText).." "..tostring(prompt.ObjectText)):lower()
    for _,part in ipairs(keywords) do
        if words:find(part,1,true) then return true end
    end
    return false
end
local function rootPart()
    local character=localPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function promptPosition(prompt)
    local p=prompt.Parent
    if not p then return nil end
    if p:IsA("Attachment") then p=p.Parent end
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Model") then return p:GetPivot().Position end
    return nil
end
on(PromptService.PromptShown,function(prompt) promptVisible[prompt]=true end)
on(PromptService.PromptHidden,function(prompt) promptVisible[prompt]=nil end)
on(localPlayer.Idled,function()
    if not state.Running or not state.AntiAFK or state.Paused then return end
    pcall(function()
        local virtual=game:GetService("VirtualUser")
        virtual:CaptureController()
        virtual:ClickButton2(Vector2.new())
    end)
end)
local function attemptProductionPrompt()
    if not state.PromptAssist or state.Paused or type(fireproximityprompt)~="function" then return end
    local root=rootPart()
    if not root then return end
    local now=os.clock()
    for prompt in pairs(promptVisible) do
        if prompt.Parent and prompt.Enabled and productionPrompt(prompt) then
            local position=promptPosition(prompt)
            local distance=position and (root.Position-position).Magnitude or math.huge
            if distance<=prompt.MaxActivationDistance+1 and now-(lastPrompt[prompt] or 0)>1.25 then
                lastPrompt[prompt]=now
                local ok=pcall(fireproximityprompt,prompt)
                if ok then state.PromptAttempts=state.PromptAttempts+1
                else state.PromptFailures=state.PromptFailures+1 end
            end
        end
    end
end

local BUTTER_LOADER="https://raw.githubusercontent.com/kode-sec/Butter/refs/heads/main/main.lua"
local function launchButter()
    if not state.Running or state.ButterLaunching then return end
    if state.ButterLoaded then
        notify("Butter","Already launched in this session; open its own window to configure production")
        return
    end
    state.ButterLaunching=true
    state.ButterStatus="Loading official Butter script / waiting for key if requested"
    log("ButterLaunch","Fetching official kode-sec/Butter loader")
    task.spawn(function()
        local ok,err=pcall(function()
            local scriptSource=game:HttpGet(BUTTER_LOADER.."?refresh="..tostring(os.time()))
            assert(type(scriptSource)=="string" and #scriptSource>300,"Butter download was incomplete")
            local fn,compileErr=loadstring(scriptSource)
            assert(fn,"Butter compile error: "..tostring(compileErr))
            fn()
        end)
        if not state.Running then return end
        state.ButterLaunching=false
        if ok then
            state.ButterLoaded=true
            state.ButterStatus="Loader returned; confirm farming in the Butter UI"
            log("ButterLaunch","Official loader completed (features not independently verified)")
            notify("Butter","Loader completed; its separate UI controls the farming settings")
        else
            state.ButterStatus="Launch failed: "..tostring(err):sub(1,150)
            log("ButterError",tostring(err):sub(1,600))
            notify("Butter","Could not load; check Status & Logs")
        end
    end)
end
local function findMoney()
    local stats=localPlayer:FindFirstChild("leaderstats")
    if not stats then return "not found" end
    for _,name in ipairs({"Cash","Money","Coins","Dollars"}) do
        local value=stats:FindFirstChild(name)
        if value and value:IsA("ValueBase") then return tostring(value.Value) end
    end
    return "not found"
end
local function snapshot()
    local remoteInfo,promptInfo={},{}
    local totalRemotes,totalPrompts=0,0
    for _,desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnreliableRemoteEvent") then
            totalRemotes=totalRemotes+1
            if #remoteInfo<180 then
                remoteInfo[#remoteInfo+1]={Class=desc.ClassName,Path=desc:GetFullName()}
            end
        end
    end
    for _,desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            totalPrompts=totalPrompts+1
            if #promptInfo<180 then
                promptInfo[#promptInfo+1]={
                    Path=desc:GetFullName(),Action=desc.ActionText,Object=desc.ObjectText,
                    Enabled=desc.Enabled,Hold=desc.HoldDuration,MaxDistance=desc.MaxActivationDistance
                }
            end
        end
    end
    return {
        Hub="BeyyHub Sell Fries",Version=version,
        Timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),PlaceId=game.PlaceId,
        ButterStatus=state.ButterStatus,
        ButterLoaded=state.ButterLoaded,ButterLaunching=state.ButterLaunching,
        Settings={AntiAFK=state.AntiAFK,PromptAssist=state.PromptAssist,SpeedMultiplier=state.SpeedMultiplier,Paused=state.Paused},
        Attempts=state.PromptAttempts,PromptFailures=state.PromptFailures,
        ExtrasStatus=state.ExtrasStatus,ExtrasStats=state.ExtrasStats,
        Money=findMoney(),RemoteCount=totalRemotes,PromptCount=totalPrompts,
        RemoteSamples=remoteInfo,PromptSamples=promptInfo,Logs=state.Logs
    }
end
local function exportDiagnostics()
    local ok,encoded=pcall(function() return Http:JSONEncode(snapshot()) end)
    if not ok then log("ExportError",encoded);notify("Diagnostics","Could not encode diagnostic data");return end
    local copied=false
    if type(setclipboard)=="function" then copied=pcall(setclipboard,encoded) end
    local saved=false
    if type(writefile)=="function" then
        local okWrite=pcall(function()
            if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder("BeyyHub") then makefolder("BeyyHub") end
            writefile("BeyyHub/sell_fries_diagnostics.json",encoded)
        end)
        saved=okWrite
    end
    log("Diagnostics",saved and "Saved as BeyyHub/sell_fries_diagnostics.json" or copied and "Copied JSON to clipboard" or "No save/clipboard API available")
    notify("Diagnostics",saved and "Saved JSON diagnostics to BeyyHub/sell_fries_diagnostics.json" or copied and "Copied diagnostics JSON" or "No writefile/setclipboard; use console")
    if not saved and not copied then print(encoded) end
end

local UI=createNativeUI()
window=UI:CreateWindow({Title="BeyyHub | Sell Fries!  v"..version,Folder="BeyyFriesHub"})
window:SetToggleKey(Enum.KeyCode.RightControl)
local main=window:Tab({Title="Main"})
main:Section({Title="Butter Engine"})
main:Button({Title="Launch Butter Hub (official)",Callback=launchButter})
main:Button({Title="Check Butter status",Callback=function()notify("Butter",state.ButterStatus)end})
main:Section({Title="BeyyHub quick controls"})
local pauseToggle=main:Toggle({Title="Pause BeyyHub assists",Value=false,Callback=function(v)
    state.Paused=v;log("Assists",v and "Paused" or "Resumed")
end})
local antiAFKToggle=main:Toggle({Title="Anti AFK",Value=false,Callback=function(v)
    state.AntiAFK=v;log("AntiAFK",v and "Enabled" or "Disabled")
end})
local promptToggle
promptToggle=main:Toggle({Title="Nearby production prompt assist",Value=false,Callback=function(v)
    if v and type(fireproximityprompt)~="function" then
        state.PromptAssist=false
        notify("Prompt assist","Executor has no fireproximityprompt support")
        task.defer(function()
            if state.Running and promptToggle then promptToggle:Set(false) end
        end)
    else
        state.PromptAssist=v
        log("PromptAssist",v and "Enabled (only visible nearby production prompts)" or "Disabled")
    end
end})

local assist=window:Tab({Title="Assist"})
assist:Section({Title="Movement & prompts"})
local speedSlider=assist:Slider({Title="Walk speed multiplier",Value={Min=1,Max=4,Default=1},Step=0.25,Callback=function(v)
    state.SpeedMultiplier=v;log("Speed",tostring(v).."x")
end})
assist:Button({Title="Restore normal walk speed",Callback=function()
    speedSlider:Set(1);restoreSpeed();notify("Speed","Restored")
end})
assist:Button({Title="Scan nearby prompts",Callback=function()
    local root=rootPart()
    if not root then notify("Prompts","Character is not ready");return end
    local descriptions={}
    for prompt in pairs(promptVisible) do
        if prompt.Parent then descriptions[#descriptions+1]=prompt.ActionText.." / "..prompt.ObjectText end
    end
    table.sort(descriptions)
    notify("Prompts",#descriptions>0 and (table.concat(descriptions,", ")):sub(1,175) or "No visible proximity prompts")
end})

local status=window:Tab({Title="Status & Logs"})
status:Section({Title="Session"})
statusPanel=status:Paragraph({Title="Session",Desc="Initializing..."})
status:Button({Title="Export Debug Diagnostics",Callback=exportDiagnostics})
status:Button({Title="Save Config",Callback=function()
    if not settingControls then return end
    local ok,err=settingControls:Save()
    notify("Config",ok and "Saved 'sell-fries' settings" or "Save failed: "..tostring(err))
end})
status:Button({Title="Load Config",Callback=function()
    if not settingControls then return end
    local ok,err=settingControls:Load(false,false)
    notify("Config",ok and "Loaded 'sell-fries' settings" or "Load failed: "..tostring(err))
end})
status:Button({Title="Unload BeyyHub (not Butter)",Callback=function()state.Unload()end})

settingControls=window.ConfigManager:CreateConfig("sell-fries")
settingControls:Register("PauseAssists",pauseToggle)
settingControls:Register("AntiAFKFries",antiAFKToggle)
settingControls:Register("ProductionPromptAssist",promptToggle)
settingControls:Register("SpeedMultiplier",speedSlider)

local function installFriesExtras()
    local url="https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/sell-fries-extras.lua"
    state.ExtrasStatus="Downloading BeyyHub Fries enhancements"
    local okDownload,source=pcall(function()
        return game:HttpGet(url.."?refresh="..tostring(os.time()))
    end)
    if not okDownload or type(source)~="string" or #source<15000 then
        state.ExtrasStatus="Extras download failed (basic BeyyHub still works)"
        log("ExtrasError",tostring(source))
        return
    end
    local installer,compileError=loadstring(source)
    if not installer then
        state.ExtrasStatus="Extras compile failed"
        log("ExtrasError",tostring(compileError))
        return
    end
    local okBuild,install=pcall(installer)
    if not okBuild or type(install)~="function" then
        state.ExtrasStatus="Extras setup failed"
        log("ExtrasError",tostring(install))
        return
    end
    local okInstall,result=pcall(install,{
        state=state,window=window,config=settingControls,player=localPlayer,
        notify=notify,log=log,on=on
    })
    if not okInstall then
        state.ExtrasStatus="Extras install error"
        log("ExtrasError",tostring(result))
    else
        state.ExtrasStatus="Game-specific extras installed (requires live testing)"
    end
end
installFriesExtras()

local function installFriesCapture()
    local url="https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/sell-fries-capture.lua"
    state.FullCaptureStatus="Loading game map exporter"
    local downloaded,source=pcall(function()
        return game:HttpGet(url.."?refresh="..tostring(os.time()))
    end)
    if not downloaded or type(source)~="string" or #source<8000 then
        state.FullCaptureStatus="Game exporter download failed; hub still usable"
        log("CaptureError",tostring(source):sub(1,160))
        return
    end
    local fn,compileError=loadstring(source)
    if not fn then
        state.FullCaptureStatus="Exporter compile error"
        log("CaptureError",tostring(compileError):sub(1,160))
        return
    end
    local okCreate,installer=pcall(fn)
    if not okCreate or type(installer)~="function" then
        state.FullCaptureStatus="Exporter setup failed"
        log("CaptureError",tostring(installer):sub(1,160))
        return
    end
    local okInstall,err=pcall(installer,{
        player=localPlayer,state=state,window=window,notify=notify,log=log,on=on
    })
    if not okInstall then
        state.FullCaptureStatus="Exporter installation failed"
        log("CaptureError",tostring(err):sub(1,200))
    end
end
installFriesCapture()

local function statusText()
    local h=humanoid()
    local hp=h and math.floor(h.Health) or 0
    return table.concat({
        "BeyyHub version: "..version,
        "Butter: "..state.ButterStatus,
        "Fries extras: "..tostring(state.ExtrasStatus or "none"),
        "Game capture: "..tostring(state.FullCaptureStatus or "not started"),
        "Last extras action: "..tostring(state.ExtrasStats and state.ExtrasStats.LastAction or "idle"),
        "Cash: "..findMoney().." | HP: "..tostring(hp),
        "Prompt attempts: "..state.PromptAttempts.." | Errors: "..state.PromptFailures,
        "Assists: "..(state.Paused and "PAUSED" or "active").." | Anti AFK: "..tostring(state.AntiAFK),
        "RightControl: show/hide BeyyHub",
        "Important: Butter uses its OWN UI and official key; BeyyHub cannot control its protected internal settings."
    },"\n")
end
function state.Unload()
    if not state.Running then return end
    state.Running=false
    state.PromptAssist=false
    state.AntiAFK=false
    state.SpeedMultiplier=1
    if type(state.ExtrasUnload)=="function" then pcall(state.ExtrasUnload) end
    if type(state.CaptureUnload)=="function" then pcall(state.CaptureUnload) end
    restoreSpeed()
    for _,connection in ipairs(connections)do pcall(function()connection:Disconnect()end)end
    if window then window:Destroy()end
    if env.BeyyFriesHub==state then env.BeyyFriesHub=nil end
    print("[BeyyHub Fries] Unloaded Beyy controls. Butter (if running) is unaffected.")
end
state.LaunchButter=launchButter
state.ExportDiagnostics=exportDiagnostics
state.Snapshot=snapshot
state.Pause=function(v)state.Paused=(v==true)end
task.spawn(function()
    while state.Running do
        if not state.Paused then
            pcall(maintainSpeed)
            pcall(attemptProductionPrompt)
        end
        if statusPanel then
            local ok,desc=pcall(statusText)
            if ok then statusPanel:SetDesc(desc)end
        end
        task.wait(0.45)
    end
end)
log("Ready","Native BeyyHub UI ready; open Butter's own UI for the protected farming settings")
notify("Ready","Launch Butter via Main tab; RightControl toggles this menu")
return state
