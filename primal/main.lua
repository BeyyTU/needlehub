-- BeyyHub | PRIMAL: Evolved v0.4.3
-- Independent client menu. No remote invocation or anti-cheat bypass.
local VERSION = "0.4.3"
if game.GameId ~= 10775092853 then
    warn("[PRIMAL] Unsupported universe: " .. tostring(game.GameId))
    return
end
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local pg = player and player:WaitForChild("PlayerGui", 10)
if not pg then return end
local GUI_NAME = "BeyyHub_PRIMAL_Status"
local RENDER_NAME = "BeyyHub_PRIMAL_Render"
local previous = pg:FindFirstChild(GUI_NAME)
if previous then previous:Destroy() end
RunService:UnbindFromRenderStep(RENDER_NAME)
local C = {
    bg=Color3.fromRGB(20,22,27), row=Color3.fromRGB(32,35,42),
    text=Color3.fromRGB(231,234,240), muted=Color3.fromRGB(155,166,183),
    accent=Color3.fromRGB(58,104,153), green=Color3.fromRGB(92,210,141),
    red=Color3.fromRGB(244,109,109), amber=Color3.fromRGB(244,186,100)
}
local state = {fly=false, playerESP=false, creatureESP=false, aim=false,
    crosshair=false, circle=false, fps=false, flySpeed=30, aimRadius=150, aimResponse=18, dinoRadius=150, dinoResponse=18,
    targetLock=false, prediction=false, playerLead=0, dinoLead=0,
    aimPriority="Crosshair", playerPoint="Head", dinoPoint="Hitbox", speed=false, speedMultiplier=1.25, creatureAim=false, creatureRange=1500, creatureLimit=25, playerRange=1500,
    pHighlight=true,pName=true,pDistance=true,pHealth=true,pLevel=false,pTeam=false,
    cHighlight=true,cName=true,cDistance=true,cLevel=true,cHealth=true,cTorpor=true,
    cStamina=false,cFood=false,cWeight=false,cMelee=false,cSpeed=false,cSex=false,
    cTamed=false,cTaming=false,cImprint=false,cMature=false}
local connections, marks, refreshers, valueRefreshers = {}, {}, {}, {}
local alive = true
local function connect(signal, callback)
    local c=signal:Connect(callback); connections[#connections+1]=c; return c
end
local function node(class, parent, props)
    local item=Instance.new(class)
    for k,v in pairs(props or {}) do item[k]=v end
    item.Parent=parent
    return item
end
local function round(item, n)
    node("UICorner",item,{CornerRadius=UDim.new(0,n or 6)})
end
local gui=node("ScreenGui",pg,{Name=GUI_NAME,ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local panel=node("Frame",gui,{Size=UDim2.fromOffset(500,350),
    Position=UDim2.new(.5,-250,.5,-175),BackgroundColor3=C.bg,BorderSizePixel=0})
round(panel,10)
node("UIStroke",panel,{Color=Color3.fromRGB(66,75,90)})
local function text(parent, title, size, position, height, color)
    return node("TextLabel",parent,{Text=title,Size=size,Position=position,
        TextSize=height or 14,TextColor3=color or C.text,Font=Enum.Font.Gotham,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(parent,title,size,pos)
    local b=node("TextButton",parent,{Text=title,Size=size,Position=pos,
        BackgroundColor3=C.row,BorderSizePixel=0,TextColor3=C.text,
        Font=Enum.Font.Gotham,TextSize=13,AutoButtonColor=true})
    round(b,6); return b
end
local header=node("Frame",panel,{Size=UDim2.new(1,0,0,56),BackgroundTransparency=1,Active=true})
local title=text(header,"BeyyHub  /  PRIMAL",UDim2.new(1,-80,0,28),UDim2.fromOffset(15,5),19)
title.Font=Enum.Font.GothamBold
text(header,"v"..VERSION.."  |  RightControl",UDim2.new(1,-80,0,18),UDim2.fromOffset(15,31),11,C.muted)
local hide=button(header,"–",UDim2.fromOffset(30,29),UDim2.new(1,-72,0,12))
local close=button(header,"X",UDim2.fromOffset(30,29),UDim2.new(1,-36,0,12))
-- A visible modal button asks Roblox's standard camera controls to release the cursor.
close.Modal=true
local cursorState=nil
local function syncMenuCursor(open)
    if open then
        if not cursorState then
            cursorState={behavior=UIS.MouseBehavior,icon=UIS.MouseIconEnabled}
        end
        if UIS.MouseBehavior~=Enum.MouseBehavior.Default then
            UIS.MouseBehavior=Enum.MouseBehavior.Default
        end
        if not UIS.MouseIconEnabled then UIS.MouseIconEnabled=true end
    elseif cursorState then
        local previous=cursorState
        cursorState=nil
        UIS.MouseBehavior=previous.behavior
        UIS.MouseIconEnabled=previous.icon
    end
end
connect(panel:GetPropertyChangedSignal("Visible"),function()
    syncMenuCursor(panel.Visible)
end)
local sidebar=node("Frame",panel,{Position=UDim2.fromOffset(10,62),Size=UDim2.fromOffset(116,278),
    BackgroundTransparency=1})
node("UIListLayout",sidebar,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local pages={}
local function selectPage(chosen)
    for _,p in ipairs(pages) do
        p.page.Visible=p==chosen
        p.nav.BackgroundColor3=p==chosen and C.accent or C.row
    end
end
local function tab(name)
    local nav=button(sidebar,name,UDim2.new(1,0,0,33),UDim2.new())
    nav.LayoutOrder=#pages+1
    local page=node("ScrollingFrame",panel,{Position=UDim2.fromOffset(136,62),
        Size=UDim2.new(1,-146,1,-72),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,
        CanvasSize=UDim2.new(),Visible=false})
    node("UIListLayout",page,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
    node("UIPadding",page,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
    local p={nav=nav,page=page}; pages[#pages+1]=p
    connect(nav.Activated,function() selectPage(p) end)
    if #pages==1 then selectPage(p) end
    return page
end
local function row(page,label)
    local r=node("Frame",page,{Size=UDim2.new(1,0,0,38),BackgroundColor3=C.row,BorderSizePixel=0})
    round(r,6)
    text(r,label,UDim2.new(1,-115,1,0),UDim2.fromOffset(10,0),13)
    return r
end
local function toggle(page,label,key,changed)
    local r=row(page,label)
    local b=button(r,"OFF",UDim2.fromOffset(64,26),UDim2.new(1,-72,0,6))
    local function refresh()
        b.Text=state[key] and "ON" or "OFF"
        b.BackgroundColor3=state[key] and C.accent or C.bg
    end
    refreshers[key]=refresh
    connect(b.Activated,function()
        state[key]=not state[key]
        if changed then changed(state[key]) end
        refresh()
    end)
    refresh()
end
local function stepper(page,label,key,minimum,maximum,step,changed,format)
    local r=row(page,label)
    local minus=button(r,"-",UDim2.fromOffset(26,26),UDim2.new(1,-100,0,6))
    local value=text(r,format and format(state[key]) or tostring(state[key]),UDim2.fromOffset(36,26),UDim2.new(1,-73,0,6),13)
    value.TextXAlignment=Enum.TextXAlignment.Center
    valueRefreshers[key]=function() value.Text=format and format(state[key]) or tostring(state[key]) end
    local plus=button(r,"+",UDim2.fromOffset(26,26),UDim2.new(1,-34,0,6))
    local function change(delta)
        state[key]=math.clamp(state[key]+delta,minimum,maximum)
        value.Text=format and format(state[key]) or tostring(state[key])
        if changed then changed(state[key]) end
    end
    connect(minus.Activated,function() change(-step) end)
    connect(plus.Activated,function() change(step) end)
end
local function note(page, value)
    local t=text(page,value,UDim2.new(1,0,0,34),UDim2.new(),12,C.muted)
    t.TextWrapped=true
    return t
end
local movement=tab("Movement")
local visuals=tab("ESP")
local combat=tab("Combat")
local settings=tab("Settings")
local configs=tab("Config")

-- Local flight: smooth, force-limited movement of the local character.
-- Does not write position or attempt to override server corrections.
local flight
local function stopFly()
    local f=flight
    if not f then return end
    flight=nil
    for _,key in ipairs({"velocity","orientation","attachment"}) do
        local instance=f[key]
        if instance then instance:Destroy() end
    end
    if f.humanoid and f.humanoid.Parent then
        f.humanoid.AutoRotate=f.oldRotate
        f.humanoid.PlatformStand=f.oldStand
    end
end
local function disableFly(reason)
    state.fly=false
    stopFly()
    if refreshers.fly then refreshers.fly() end
    if reason then warn("[PRIMAL Flight] "..reason) end
end
local function startFly()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 or root.Anchored or hum.SeatPart then
        return false,"Character not available or is seated."
    end
    if flight and flight.root==root then return true end
    stopFly()
    local f={root=root,humanoid=hum,oldRotate=hum.AutoRotate,
        oldStand=hum.PlatformStand,command=root.AssemblyLinearVelocity}
    flight=f
    local success,reason=pcall(function()
        local mass=math.max(root.AssemblyMass,1)
        local look=root.CFrame.LookVector
        local flat=Vector3.new(look.X,0,look.Z)
        flat=flat.Magnitude>.001 and flat.Unit or Vector3.new(0,0,-1)
        f.attachment=node("Attachment",root,{Name="PRIMAL_FlightAttachment"})
        f.velocity=node("LinearVelocity",root,{
            Name="PRIMAL_FlightVelocity",Attachment0=f.attachment,
            RelativeTo=Enum.ActuatorRelativeTo.World,
            VelocityConstraintMode=Enum.VelocityConstraintMode.Vector,
            ForceLimitsEnabled=true,ForceLimitMode=Enum.ForceLimitMode.Magnitude,
            MaxForce=mass*(workspace.Gravity+100),VectorVelocity=f.command})
        -- Hold a single upright heading, rather than chasing camera yaw every frame.
        f.orientation=node("AlignOrientation",root,{
            Name="PRIMAL_FlightOrientation",Attachment0=f.attachment,
            Mode=Enum.OrientationAlignmentMode.OneAttachment,
            RigidityEnabled=false,MaxTorque=mass*3000,
            MaxAngularVelocity=5,Responsiveness=7,
            CFrame=CFrame.lookAt(Vector3.zero,flat)})
        hum.AutoRotate=false
        hum.PlatformStand=true
    end)
    if not success then stopFly(); return false,tostring(reason) end
    return true
end
-- Ground speed: a manual local WalkSpeed change, never a continuous override.
local speedSession
local function stopSpeed()
    local f=speedSession
    speedSession=nil
    if not f then return end
    if f.connection then f.connection:Disconnect() end
    if f.humanoid.Parent and math.abs(f.humanoid.WalkSpeed-f.applied)<.001 then
        f.humanoid.WalkSpeed=f.original
    end
end
local function disableSpeed(reason)
    state.speed=false
    stopSpeed()
    if refreshers.speed then refreshers.speed() end
    if reason then warn("[PRIMAL Speed] "..reason) end
end
local function applySpeed()
    if not state.speed then return end
    local f=speedSession
    if not f or not f.humanoid.Parent or f.humanoid.Health<=0 or f.humanoid.SeatPart then
        disableSpeed("Character unavailable or seated.")
        return
    end
    if math.abs(f.humanoid.WalkSpeed-f.applied)>=.001 then
        disableSpeed("Movement speed changed by another controller; released override.")
        return
    end
    f.applied=f.original*state.speedMultiplier
    f.humanoid.WalkSpeed=f.applied
end
local function startSpeed()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if state.fly or not hum or hum.Health<=0 or hum.SeatPart or hum.WalkSpeed<=0 then
        disableSpeed("Ground character unavailable; disable flight first.")
        return
    end
    stopSpeed()
    local f={humanoid=hum,original=hum.WalkSpeed,applied=hum.WalkSpeed}
    speedSession=f
    f.connection=hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if speedSession==f and math.abs(hum.WalkSpeed-f.applied)>=.001 then
            disableSpeed("Movement speed changed by another controller; released override.")
        end
    end)
    applySpeed()
end
toggle(movement,"Speed multiplier","speed",function(on)
    if on then startSpeed() else stopSpeed() end
end)
stepper(movement,"Ground speed","speedMultiplier",1,3,.25,applySpeed,function(v)
    return string.format("%gx",v)
end)
note(movement,"Uses current WalkSpeed as baseline. Stops if the game changes it.")
connect(player.CharacterRemoving,function() disableSpeed() end)
connect(RunService.Heartbeat,function()
    local f=speedSession
    if f and (not f.humanoid.Parent or f.humanoid.Health<=0 or f.humanoid.SeatPart) then
        disableSpeed()
    end
end)

toggle(movement,"Fly","fly",function(on)
    if on then
        disableSpeed()
        local ok,reason=startFly()
        if not ok then disableFly(reason) end
    else
        stopFly()
    end
end)
stepper(movement,"Fly speed","flySpeed",10,150,10)
note(movement,"Smooth flight: WASD, Space up, LeftControl down. Default speed 30. Server corrections may still occur.")
connect(player.CharacterRemoving,function()
    disableFly()
end)
connect(RunService.PreSimulation,function(dt)
    if not state.fly or not flight then return end
    local f=flight
    if not f.root.Parent or not f.humanoid.Parent or f.humanoid.Health<=0
        or f.root.Anchored or f.humanoid.SeatPart
        or not f.velocity.Parent or not f.orientation.Parent then
        disableFly("Character or flight constraints are no longer available.")
        return
    end
    -- Do not fight another controller if it restores the humanoid's controls.
    if not f.humanoid.PlatformStand or f.humanoid.AutoRotate then
        disableFly("Another character controller changed the flight state.")
        return
    end
    local cam=workspace.CurrentCamera
    local dir=Vector3.zero
    if cam and not UIS:GetFocusedTextBox() then
        local look=cam.CFrame.LookVector
        local flat=Vector3.new(look.X,0,look.Z)
        flat=flat.Magnitude>.001 and flat.Unit or Vector3.new(0,0,-1)
        local right=flat:Cross(Vector3.yAxis)
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=flat end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=flat end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=right end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=right end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.yAxis end
    end
    local target=dir.Magnitude>0 and dir.Unit*state.flySpeed or Vector3.zero
    local delta=target-f.command
    local rate=dir.Magnitude>0 and 70 or 90
    local maxChange=rate*math.clamp(dt,0,.1)
    if delta.Magnitude>maxChange then
        f.command+=delta.Unit*maxChange
    else
        f.command=target
    end
    f.velocity.VectorVelocity=f.command
end)

-- One-shot local position test; no retries, server calls, or correction override.
local teleportButton=button(movement,"Teleport to nearest player",UDim2.new(1,0,0,36),UDim2.new())
local teleportStatus=note(movement,"One-shot test. Server may reject movement or disconnect you.")
connect(teleportButton.Activated,function()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not hum or hum.Health<=0 or root.Anchored or hum.SeatPart then
        teleportStatus.Text="Local character unavailable or seated."
        return
    end
    local nearest,nearestDistance=nil,math.huge
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player then
            local target=other.Character
            local part=target and target:FindFirstChild("HumanoidRootPart")
            local targetHum=target and target:FindFirstChildOfClass("Humanoid")
            if part and part:IsA("BasePart") and targetHum and targetHum.Health>0 and target:IsDescendantOf(workspace) then
                local distance=(part.Position-root.Position).Magnitude
                if distance<nearestDistance then
                    nearest,nearestDistance=part,distance
                end
            end
        end
    end
    if not nearest then
        teleportStatus.Text="No other loaded, living player found."
        return
    end
    disableFly()
    disableSpeed()
    local destination=nearest.Position+Vector3.new(4,0,0)
    local ok,reason=pcall(function()
        char:PivotTo(char:GetPivot()+(destination-root.Position))
    end)
    if ok then
        teleportStatus.Text=string.format("Local move attempted (%.0f studs). Server acceptance unknown.",nearestDistance)
    else
        teleportStatus.Text="Local move failed."
        warn("[PRIMAL Teleport] "..tostring(reason))
    end
end)

-- Creature catalog and filtered, read-only stat overlays.
local function collapsible(page,titleText,opened)
    local section=node("Frame",page,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,BorderSizePixel=0})
    node("UIListLayout",section,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
    local heading=button(section,"",UDim2.new(1,0,0,34),UDim2.new())
    heading.LayoutOrder=0
    local body=node("Frame",section,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Visible=opened,LayoutOrder=1})
    node("UIListLayout",body,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
    local function update()
        heading.Text=(body.Visible and "-  " or "+  ")..titleText
        heading.BackgroundColor3=body.Visible and C.accent or C.row
    end
    connect(heading.Activated,function() body.Visible=not body.Visible; update() end)
    update()
    return body
end
local playerESPPage=collapsible(visuals,"Player ESP",false)
local creatureESPPage=collapsible(visuals,"Creature ESP",true)
local selectedSpecies={}
local allSpecies=true
local function speciesKey(value)
    return string.lower(tostring(value)):gsub("[^%w]","")
end
local function creaturePart(model)
    local part=model:FindFirstChild("Hitbox")
    if part and part:IsA("BasePart") then return part end
    return model.PrimaryPart
end
local function creatureFolder()
    return workspace:FindFirstChild("BadWaveCreatures")
end
local function speciesAllowed(model)
    return allSpecies or selectedSpecies[speciesKey(model.Name)]==true
end
local function localRoot()
    local char=player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function destroyMark(mark)
    if mark.highlight then mark.highlight:Destroy() end
    if mark.billboard then mark.billboard:Destroy() end
end
local function clearMarks()
    for model,mark in pairs(marks) do destroyMark(mark); marks[model]=nil end
end
-- Attribute and direct ValueBase names below are candidate aliases, not a verified schema.
local function statMap(model,part)
    local values={}
    local function read(source)
        if not source then return end
        for k,v in pairs(source:GetAttributes()) do
            local key=speciesKey(k)
            if values[key]==nil and (type(v)=="number" or type(v)=="string" or type(v)=="boolean") then
                values[key]=v
            end
        end
        for _,child in ipairs(source:GetChildren()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") or child:IsA("BoolValue") then
                local key=speciesKey(child.Name)
                if values[key]==nil then values[key]=child.Value end
            end
        end
    end
    read(model); read(part)
    for _,name in ipairs({"Stats","Attributes","CreatureStats","Status","Data"}) do
        local folder=model:FindFirstChild(name)
        if folder and folder:IsA("Folder") then read(folder) end
    end
    return values
end
local function stat(values,...)
    for _,name in ipairs({...}) do
        local value=values[speciesKey(name)]
        if value~=nil then return value end
    end
end
local function numeric(values,...)
    local value=tonumber(stat(values,...))
    if value and value==value and math.abs(value)<math.huge then return value end
end
local function fmt(value)
    if value==nil then return "?" end
    if type(value)=="number" then return string.format("%.0f",value) end
    if type(value)=="boolean" then return value and "Yes" or "No" end
    return tostring(value):sub(1,40)
end
local function pairStat(current,maximum)
    if maximum~=nil then return fmt(current).."/"..fmt(maximum) end
    return fmt(current)
end
-- ESP-only anchors: handle partially streamed rigs without changing targeting logic.
local espContainer=node("Folder",workspace,{Name="BeyyHub_PRIMAL_LocalHighlights"})
local function espPart(model,isCreature)
    local names=isCreature and {"Hitbox","RootPart","HumanoidRootPart","Head"} or {"Head","HumanoidRootPart"}
    for _,name in ipairs(names) do
        local part=model:FindFirstChild(name,true)
        if part and part:IsA("BasePart") then return part end
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end
local function espInfo(model,entry)
    local v=statMap(model,entry.part)
    local hum=model:FindFirstChildOfClass("Humanoid")
    local health=numeric(v,"Health","CurrentHealth","HP","CurrentHP")
    local maxHealth=numeric(v,"MaxHealth","HealthMax","MaxHP")
    if hum then
        if health==nil then health=hum.Health end
        if maxHealth==nil then maxHealth=hum.MaxHealth end
    end
    local fields={}
    local function field(enabled,value)
        if enabled then fields[#fields+1]=value end
    end
    if entry.player then
        local p=entry.player
        field(state.pName,p.DisplayName==p.Name and p.Name or (p.DisplayName.." (@"..p.Name..")"))
        field(state.pDistance,fmt(entry.distance).." st")
        field(state.pHealth,"HP "..pairStat(health,maxHealth))
        field(state.pLevel,"Lv "..fmt(numeric(v,"Level","PlayerLevel","CurrentLevel","Lvl")))
        field(state.pTeam,"Team "..(p.Team and p.Team.Name or "None"))
    else
        field(state.cName,model.Name)
        field(state.cDistance,fmt(entry.distance).." st")
        field(state.cLevel,"Lv "..fmt(numeric(v,"Level","CreatureLevel","DinoLevel","CurrentLevel","TotalLevel","Lvl")))
        field(state.cHealth,"HP "..pairStat(health,maxHealth))
        field(state.cTorpor,"Torpor "..pairStat(numeric(v,"Torpor","CurrentTorpor","Torpidity","CurrentTorpidity"),numeric(v,"MaxTorpor","TorporMax","MaxTorpidity")))
        field(state.cStamina,"Stam "..pairStat(numeric(v,"Stamina","CurrentStamina"),numeric(v,"MaxStamina","StaminaMax")))
        field(state.cFood,"Food "..pairStat(numeric(v,"Food","CurrentFood"),numeric(v,"MaxFood","FoodMax")))
        field(state.cWeight,"Weight "..pairStat(numeric(v,"Weight","CurrentWeight"),numeric(v,"MaxWeight","WeightMax")))
        field(state.cMelee,"Melee "..fmt(numeric(v,"MeleeDamage","Melee")))
        field(state.cSpeed,"Speed "..fmt(numeric(v,"MovementSpeed")))
        field(state.cSex,"Sex "..fmt(stat(v,"Gender","Sex")))
        local tamed=stat(v,"IsTamed","Tamed")
        field(state.cTamed,type(tamed)=="boolean" and (tamed and "Tamed" or "Wild") or "Tamed ?")
        field(state.cTaming,"Taming "..fmt(numeric(v,"TamingProgress","TameProgress")))
        field(state.cImprint,"Imprint "..fmt(numeric(v,"Imprint","ImprintProgress")))
        field(state.cMature,"Mature "..fmt(numeric(v,"Maturation","MaturationProgress")))
    end
    local lines={}
    for i=1,#fields,2 do
        local second=fields[i+1]
        lines[#lines+1]=second and (fields[i].."  |  "..second) or fields[i]
    end
    return table.concat(lines,"\n"),#lines
end
local function createMark(model,part,color)
    local mark={part=part}
    -- Keep billboard and outline independent; a missing visual rig must not prevent labels.
    mark.billboard=node("BillboardGui",pg,{Name="PRIMAL_ESPLabel",Adornee=part,
        AlwaysOnTop=true,Size=UDim2.fromOffset(320,24),
        StudsOffsetWorldSpace=Vector3.new(0,math.clamp(part.Size.Y/2+1,2,20),0),
        MaxDistance=5000,LightInfluence=0,ResetOnSpawn=false})
    mark.label=node("TextLabel",mark.billboard,{Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,TextColor3=color,TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=.1,Font=Enum.Font.GothamBold,TextSize=13,TextWrapped=true})
    return mark
end
local espStatus
local playerStatus
local lastESPError
local function refreshESP()
    local wanted={}
    local root=localRoot()
    local cam=workspace.CurrentCamera
    local origin=root and root.Position or (cam and cam.CFrame.Position)
    local candidates={}
    local loaded,anchored,matching=0,0,0
    local folder=creatureFolder()
    if state.creatureESP and folder then
        for _,model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") then
                loaded+=1
                local part=espPart(model,true)
                if part then
                    anchored+=1
                    if speciesAllowed(model) then
                        matching+=1
                        if origin then
                            local distance=(part.Position-origin).Magnitude
                            if distance<=state.creatureRange then
                                candidates[#candidates+1]={model=model,part=part,distance=distance}
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(candidates,function(a,b) return a.distance<b.distance end)
    local visibleCreatures=math.min(#candidates,state.creatureLimit)
    for i=1,visibleCreatures do local e=candidates[i]; wanted[e.model]=e end
    local playerCandidates={}
    if state.playerESP and origin then
        for _,p in ipairs(Players:GetPlayers()) do
            local char=p.Character
            if p~=player and char and char:IsDescendantOf(workspace) then
                local part=espPart(char,false)
                if part then
                    local distance=(part.Position-origin).Magnitude
                    if distance<=state.playerRange then
                        playerCandidates[#playerCandidates+1]={model=char,part=part,distance=distance,player=p}
                    end
                end
            end
        end
    end
    table.sort(playerCandidates,function(a,b) return a.distance<b.distance end)
    for _,entry in ipairs(playerCandidates) do wanted[entry.model]=entry end
    for model,mark in pairs(marks) do
        local entry=wanted[model]
        if not entry or not model.Parent or mark.part~=entry.part then
            destroyMark(mark); marks[model]=nil
        end
    end
    -- Limit outlines independently of text labels to avoid exhausting engine highlight slots.
    local highlightCandidates={}
    for _,entry in pairs(wanted) do
        if (entry.player and state.pHighlight) or (not entry.player and state.cHighlight) then
            highlightCandidates[#highlightCandidates+1]=entry
        end
    end
    table.sort(highlightCandidates,function(a,b) return a.distance<b.distance end)
    local outline={}
    for i=1,math.min(30,#highlightCandidates) do outline[highlightCandidates[i].model]=true end
    for model,mark in pairs(marks) do
        if mark.highlight and not outline[model] then mark.highlight:Destroy(); mark.highlight=nil end
    end
    local errors,renderedPlayers,renderedCreatures=0,0,0
    for model,entry in pairs(wanted) do
        local ok,err=pcall(function()
            local color=entry.player and C.red or C.amber
            local mark=marks[model]
            if not mark then mark=createMark(model,entry.part,color); marks[model]=mark end
            local label,lines=espInfo(model,entry)
            mark.label.Text=label
            mark.billboard.Enabled=lines>0
            mark.billboard.Size=UDim2.fromOffset(320,math.max(24,lines*20))
            mark.billboard.MaxDistance=entry.player and state.playerRange or state.creatureRange
            if outline[model] and not mark.highlight then
                local rig=not entry.player and model:FindFirstChild("Rig") or nil
                mark.highlight=node("Highlight",espContainer,{Adornee=rig or model,FillColor=color,
                    OutlineColor=color,FillTransparency=.82,OutlineTransparency=.1,
                    DepthMode=Enum.HighlightDepthMode.AlwaysOnTop})
            end
        end)
        if ok then
            if entry.player then renderedPlayers+=1 else renderedCreatures+=1 end
        else
            errors+=1
            local reason=tostring(err)
            if reason~=lastESPError then warn("[PRIMAL ESP] "..reason); lastESPError=reason end
        end
    end
    if playerStatus then
        playerStatus.Text=state.playerESP and string.format("Players: %d / %d in range.",renderedPlayers,#playerCandidates) or "Player ESP is off."
    end
    if espStatus then
        if not state.creatureESP then espStatus.Text="Creature ESP is off."
        elseif not folder then espStatus.Text="Creature folder not loaded."
        else espStatus.Text=string.format("Loaded %d | anchors %d | matched %d\nIn range %d | markers %d | errors %d",loaded,anchored,matching,#candidates,renderedCreatures,errors) end
    end
end
toggle(playerESPPage,"Enable player ESP","playerESP",refreshESP)
stepper(playerESPPage,"Range (studs)","playerRange",250,5000,250,refreshESP)
for _,item in ipairs({{"Outline","pHighlight"},{"Name","pName"},{"Distance","pDistance"},
    {"Health","pHealth"},{"Level","pLevel"},{"Team","pTeam"}}) do
    toggle(playerESPPage,item[1],item[2],refreshESP)
end
playerStatus=note(playerESPPage,"Player ESP is off.")
toggle(creatureESPPage,"Enable creature ESP","creatureESP",refreshESP)
stepper(creatureESPPage,"Range (studs)","creatureRange",250,5000,250,refreshESP)
stepper(creatureESPPage,"Max creature labels","creatureLimit",5,30,5,refreshESP)
espStatus=note(creatureESPPage,"Creature ESP is off.")
note(creatureESPPage,"? = selected stat not exposed by recognized replicated values.")
for _,item in ipairs({{"Outline","cHighlight"},{"Species name","cName"},{"Distance","cDistance"},
    {"Level","cLevel"},{"Health","cHealth"},{"Torpor","cTorpor"},{"Stamina","cStamina"},
    {"Food","cFood"},{"Weight","cWeight"},{"Melee","cMelee"},{"Movement speed","cSpeed"},
    {"Sex","cSex"},{"Wild / tamed","cTamed"},{"Taming progress","cTaming"},
    {"Imprint","cImprint"},{"Maturation","cMature"}}) do
    toggle(creatureESPPage,item[1],item[2],refreshESP)
end
local speciesPage=collapsible(creatureESPPage,"Species filters",false)
local filterMode=button(speciesPage,"Species: ALL",UDim2.new(1,0,0,32),UDim2.new())
local speciesSearch=node("TextBox",speciesPage,{Size=UDim2.new(1,0,0,32),Text="",PlaceholderText="Search species...",
    ClearTextOnFocus=false,BackgroundColor3=C.row,TextColor3=C.text,PlaceholderColor3=C.muted,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0})
round(speciesSearch,6)
local list=node("ScrollingFrame",speciesPage,{Size=UDim2.new(1,0,0,145),BackgroundColor3=C.bg,
    BorderSizePixel=0,ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
node("UIListLayout",list,{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder})
local speciesButtons={}
local function redrawSpecies()
    local count=0
    for _ in pairs(selectedSpecies) do count+=1 end
    filterMode.Text=allSpecies and "Species: ALL (click for selected)" or ("Species: SELECTED ("..count..")")
    local query=speciesKey(speciesSearch.Text)
    for key,b in pairs(speciesButtons) do
        local chosen=selectedSpecies[key]==true
        b.Text=(chosen and "[+] " or "[ ] ")..b:GetAttribute("DisplayName")
        b.BackgroundColor3=chosen and C.accent or C.row
        b.Visible=query=="" or string.find(key,query,1,true)~=nil
    end
end
local function refreshCatalog()
    local catalog={}
    local function add(name)
        local key=speciesKey(name)
        if key~="" and not string.find(string.upper(name),"SADDLE",1,true) then catalog[key]=name end
    end
    local storage=game:GetService("ReplicatedStorage")
    local bw=storage:FindFirstChild("BadWave")
    local art=bw and bw:FindFirstChild("CreatureArt")
    if art then
        for _,model in ipairs(art:GetChildren()) do
            if model:IsA("Model") then add(model.Name) end
        end
    end
    local folder=creatureFolder()
    if folder then
        for _,model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") then add(model.Name) end
        end
    end
    local keys={}
    for key in pairs(catalog) do keys[#keys+1]=key end
    table.sort(keys)
    for i,key in ipairs(keys) do
        local b=speciesButtons[key]
        if not b then
            b=button(list,"",UDim2.new(1,-8,0,28),UDim2.new())
            speciesButtons[key]=b
            local species=key
            connect(b.Activated,function()
                selectedSpecies[species]=not selectedSpecies[species] and true or nil
                allSpecies=false
                redrawSpecies(); refreshESP()
            end)
        end
        b:SetAttribute("DisplayName",catalog[key])
        b.LayoutOrder=i
    end
    redrawSpecies()
end
connect(speciesSearch:GetPropertyChangedSignal("Text"),redrawSpecies)
connect(filterMode.Activated,function() allSpecies=not allSpecies; redrawSpecies(); refreshESP() end)
local clearSelection=button(speciesPage,"Clear selected species",UDim2.new(1,0,0,32),UDim2.new())
connect(clearSelection.Activated,function()
    table.clear(selectedSpecies); allSpecies=false; redrawSpecies(); refreshESP()
end)
refreshCatalog()
local overlay=node("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false,ZIndex=0})
local cross=node("Frame",overlay,{Size=UDim2.fromOffset(16,16),Position=UDim2.fromScale(.5,.5),
    AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Visible=false})
node("Frame",cross,{Size=UDim2.fromOffset(16,2),Position=UDim2.fromScale(.5,.5),
    AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.text,BorderSizePixel=0})
node("Frame",cross,{Size=UDim2.fromOffset(2,16),Position=UDim2.fromScale(.5,.5),
    AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.text,BorderSizePixel=0})
local circle=node("Frame",overlay,{Size=UDim2.fromOffset(300,300),Position=UDim2.fromScale(.5,.5),
    AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Visible=false})
node("UICorner",circle,{CornerRadius=UDim.new(1,0)})
node("UIStroke",circle,{Color=C.text,Thickness=1,Transparency=.35})
local otherVisuals=collapsible(visuals,"Other visuals",false)
toggle(otherVisuals,"Crosshair","crosshair",function(on) cross.Visible=on end)
local fpsLabel=text(overlay,"FPS: --",UDim2.fromOffset(145,24),UDim2.fromOffset(12,72),14,C.green)
fpsLabel.Visible=false
toggle(otherVisuals,"FPS counter","fps",function(on) fpsLabel.Visible=on end)

-- Camera-only aim assistance; never changes projectile or weapon requests.
local dinoCircle=node("Frame",overlay,{Size=UDim2.fromOffset(300,300),Position=UDim2.fromScale(.5,.5),
    AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Visible=false})
node("UICorner",dinoCircle,{CornerRadius=UDim.new(1,0)})
node("UIStroke",dinoCircle,{Color=C.amber,Thickness=1,Transparency=.25})
local lockedModel
local function updateCircles()
    circle.Visible=state.circle and (state.aim or not state.creatureAim)
    dinoCircle.Visible=state.circle and state.creatureAim
    circle.Size=UDim2.fromOffset(state.aimRadius*2,state.aimRadius*2)
    dinoCircle.Size=UDim2.fromOffset(state.dinoRadius*2,state.dinoRadius*2)
end
local function resetLock()
    lockedModel=nil
    updateCircles()
end
toggle(combat,"Aim assist (players)","aim",resetLock)
toggle(combat,"Aim assist (dinosaurs)","creatureAim",resetLock)
toggle(combat,"Aim FOV circles","circle",updateCircles)
toggle(combat,"Retain target (RMB)","targetLock",resetLock)
local function choice(label,key,options)
    local r=row(combat,label)
    local b=button(r,tostring(state[key]),UDim2.fromOffset(104,26),UDim2.new(1,-112,0,6))
    valueRefreshers[key]=function() b.Text=tostring(state[key]) end
    connect(b.Activated,function()
        local i=table.find(options,state[key]) or 1
        state[key]=options[i%#options+1]
        b.Text=tostring(state[key])
        resetLock()
    end)
end
choice("Target priority","aimPriority",{"Crosshair","Nearest"})
local function editableRadius(label,key)
    local r=row(combat,label)
    local minus=button(r,"-",UDim2.fromOffset(26,26),UDim2.new(1,-100,0,6))
    local value=node("TextBox",r,{
        Text=tostring(state[key]),Size=UDim2.fromOffset(36,26),Position=UDim2.new(1,-73,0,6),
        BackgroundColor3=C.bg,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=12,
        ClearTextOnFocus=false,BorderSizePixel=0})
    round(value,4)
    valueRefreshers[key]=function() value.Text=tostring(state[key]) end
    local plus=button(r,"+",UDim2.fromOffset(26,26),UDim2.new(1,-34,0,6))
    local function setRadius(input)
        local n=tonumber(input)
        if n and n==n and math.abs(n)<math.huge then
            state[key]=math.clamp(math.floor(n+.5),5,500)
        end
        value.Text=tostring(state[key])
        updateCircles()
    end
    connect(minus.Activated,function() setRadius(state[key]-5) end)
    connect(plus.Activated,function() setRadius(state[key]+5) end)
    connect(value.FocusLost,function() setRadius(value.Text) end)
end
note(combat,"PLAYER SETTINGS | white FOV circle")
editableRadius("Player FOV (px)","aimRadius")
stepper(combat,"Player response","aimResponse",2,40,2)
choice("Player aim point","playerPoint",{"Head","Torso"})
note(combat,"DINOSAUR SETTINGS | amber FOV circle")
editableRadius("Dino FOV (px)","dinoRadius")
stepper(combat,"Dino response","dinoResponse",2,40,2)
choice("Dino aim point","dinoPoint",{"Hitbox","Head"})
note(combat,"Dinosaurs use your ESP species and distance filters. Head falls back to hitbox.")
toggle(combat,"Camera motion lead","prediction")
stepper(combat,"Player lead (ms)","playerLead",0,250,10)
stepper(combat,"Dino lead (ms)","dinoLead",0,250,10)
note(combat,"Optional manual motion lead; zero by default. Not a verified ballistic model.")
note(combat,"Hold RMB with menu hidden. Targets must be visible and within their FOV.")
local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater=true
local function findPart(model,names,recursive)
    for _,name in ipairs(names) do
        local p=model:FindFirstChild(name,recursive==true)
        if p and p:IsA("BasePart") then return p end
    end
end
local function getTarget(cam)
    local center=cam.ViewportSize*.5
    local best,bestScore,retained=nil,math.huge,nil
    rayParams.FilterDescendantsInstances=player.Character and {player.Character} or {}
    local origin=cam.CFrame.Position
    local root=localRoot()
    local reference=root and root.Position or origin
    local function consider(model,part,isDino)
        if not part or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then return end
        local screen,visible=cam:WorldToViewportPoint(part.Position)
        if not visible or screen.Z<=0 then return end
        local pixels=(Vector2.new(screen.X,screen.Y)-center).Magnitude
        local radius=isDino and state.dinoRadius or state.aimRadius
        if pixels>radius then return end
        local score=state.aimPriority=="Nearest" and (part.Position-reference).Magnitude or pixels
        local keep=state.targetLock and model==lockedModel
        if not keep and score>=bestScore then return end
        local hit=workspace:Raycast(origin,part.Position-origin,rayParams)
        if hit and not hit.Instance:IsDescendantOf(model) then return end
        local candidate={model=model,part=part,isDino=isDino}
        if keep then retained=candidate end
        if score<bestScore then best,bestScore=candidate,score end
    end
    if state.aim then
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and (not player.Team or player.Team~=other.Team or player.Neutral or other.Neutral) then
                local char=other.Character
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health>0 then
                    local names=state.playerPoint=="Torso" and {"UpperTorso","Torso","HumanoidRootPart","Head"}
                        or {"Head","HumanoidRootPart"}
                    consider(char,findPart(char,names),false)
                end
            end
        end
    end
    if state.creatureAim then
        local folder=creatureFolder()
        if folder and root then
            for _,model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and speciesAllowed(model) then
                    local base=creaturePart(model)
                    if base and (base.Position-root.Position).Magnitude<=state.creatureRange then
                        local hum=model:FindFirstChildOfClass("Humanoid")
                        if not hum or hum.Health>0 then
                            local part=state.dinoPoint=="Head" and findPart(model,{"Head","head"},true) or base
                            consider(model,part or base,true)
                        end
                    end
                end
            end
        end
    end
    return retained or best
end
local frames,elapsed=0,0
RunService:BindToRenderStep(RENDER_NAME,Enum.RenderPriority.Camera.Value+5,function(dt)
    if not alive then return end
    frames+=1; elapsed+=dt
    if elapsed>=.5 then
        fpsLabel.Text="FPS: "..tostring(math.floor(frames/elapsed+.5))
        frames,elapsed=0,0
    end
    updateCircles()
    if panel.Visible then syncMenuCursor(true) end
    if not (state.aim or state.creatureAim) or panel.Visible or UIS:GetFocusedTextBox()
        or not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        lockedModel=nil; return
    end
    local cam=workspace.CurrentCamera
    if not cam then lockedModel=nil; return end
    local target=getTarget(cam)
    if not target then lockedModel=nil; return end
    lockedModel=state.targetLock and target.model or nil
    local current=cam.CFrame
    local point=target.part.Position
    local response=target.isDino and state.dinoResponse or state.aimResponse
    if state.prediction then
        local lead=(target.isDino and state.dinoLead or state.playerLead)/1000
        local offset=target.part.AssemblyLinearVelocity*lead
        if offset.Magnitude>10 then offset=offset.Unit*10 end
        local predicted=point+offset
        local hit=workspace:Raycast(current.Position,predicted-current.Position,rayParams)
        local screen,visible=cam:WorldToViewportPoint(predicted)
        local radius=target.isDino and state.dinoRadius or state.aimRadius
        if visible and screen.Z>0 and (Vector2.new(screen.X,screen.Y)-cam.ViewportSize*.5).Magnitude<=radius
            and (not hit or hit.Instance:IsDescendantOf(target.model)) then point=predicted end
    end
    if (point-current.Position).Magnitude>.001 then
        cam.CFrame=current:Lerp(CFrame.lookAt(current.Position,point),1-math.exp(-response*math.max(dt,0)))
    end
end)
note(settings,"Place: "..tostring(game.PlaceId).."  |  Build: "..tostring(game.PlaceVersion))
note(settings,"Features default to OFF unless a config is loaded. Flight and speed always start OFF.")
local reset=button(settings,"Disable all features",UDim2.new(1,0,0,36),UDim2.new())
connect(reset.Activated,function()
    for key,refresh in pairs(refreshers) do state[key]=false; refresh() end
    stopFly(); stopSpeed(); clearMarks(); if espStatus then espStatus.Text="Creature ESP is off." end; if playerStatus then playerStatus.Text="Player ESP is off." end; cross.Visible=false; circle.Visible=false; dinoCircle.Visible=false; lockedModel=nil; fpsLabel.Visible=false
end)
-- Named local profiles. No network transfer or executable configuration data.
do
    local http=game:GetService("HttpService")
    local folder="PRIMAL/configs"
    local activePath="PRIMAL/active_config.json"
    local available=type(writefile)=="function" and type(readfile)=="function" and type(makefolder)=="function"
    local function ensure(path)
        if type(isfolder)=="function" and isfolder(path) then return true end
        local ok=pcall(makefolder,path)
        return ok or (type(isfolder)=="function" and isfolder(path))
    end
    if available then available=ensure("PRIMAL") and ensure(folder) end
    local status=note(configs,available and "Choose or save a named profile." or "Config storage unavailable in this executor.")
    local function message(value)
        status.Text=value
        print("[PRIMAL Config] "..value)
    end
    local function validName(name)
        return type(name)=="string" and #name>=1 and #name<=40 and name:match("^[%w_%-]+$")~=nil
    end
    local function readJSON(path)
        if not available then return nil end
        local ok,data=pcall(function()
            local raw=readfile(path)
            if type(raw)~="string" or #raw>262144 then return nil end
            return http:JSONDecode(raw)
        end)
        if ok and type(data)=="table" then return data end
    end
    local function writeJSON(path,data)
        if not available then return false end
        local ok,result=pcall(function()
            local raw=http:JSONEncode(data)
            local result=writefile(path,raw)
            if result==false then return false end
            return readfile(path)==raw
        end)
        return ok and result==true
    end
    local profileName="default"
    local autoload=false
    local meta=readJSON(activePath)
    if meta and validName(meta.name) then
        profileName=meta.name
        autoload=meta.autoload==true
    end
    local nameBox=node("TextBox",configs,{Size=UDim2.new(1,0,0,34),Text=profileName,
        PlaceholderText="Profile name",ClearTextOnFocus=false,BackgroundColor3=C.row,
        TextColor3=C.text,PlaceholderColor3=C.muted,Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0})
    round(nameBox,6)
    local function typedName()
        local name=nameBox.Text
        if validName(name) then return name end
        message("Use 1-40 letters, numbers, underscores or hyphens.")
    end
    local names={}
    local selectButton=button(configs,"Select saved profile",UDim2.new(1,0,0,34),UDim2.new())
    local function refreshList()
        local known={}
        if available and type(listfiles)=="function" then
            local ok,files=pcall(listfiles,folder)
            if ok and type(files)=="table" then
                for _,path in ipairs(files) do
                    if type(path)=="string" then
                        local base=path:gsub(string.char(92),"/"):match("([^/]+)%.json$")
                        if validName(base) then known[base]=true end
                    end
                end
            end
        end
        if readJSON(folder.."/"..profileName..".json") then known[profileName]=true end
        table.clear(names)
        for name in pairs(known) do names[#names+1]=name end
        table.sort(names)
        selectButton.Text=#names>0 and ("Cycle saved profiles ("..#names..")") or "No listed profiles (type a name)"
    end
    connect(selectButton.Activated,function()
        if #names==0 then message("Type a profile name to save or load."); return end
        local i=table.find(names,nameBox.Text) or 0
        nameBox.Text=names[i%#names+1]
    end)
    local refreshButton=button(configs,"Refresh profile list",UDim2.new(1,0,0,32),UDim2.new())
    connect(refreshButton.Activated,refreshList)
    local boolKeys={"playerESP","creatureESP","crosshair","circle","fps","aim","creatureAim","targetLock","prediction",
        "pHighlight","pName","pDistance","pHealth","pLevel","pTeam",
        "cHighlight","cName","cDistance","cLevel","cHealth","cTorpor","cStamina","cFood","cWeight",
        "cMelee","cSpeed","cSex","cTamed","cTaming","cImprint","cMature"}
    local bounds={
        flySpeed={10,150,10},speedMultiplier={1,3,.25},
        aimRadius={5,500,1},dinoRadius={5,500,1},
        aimResponse={2,40,2},dinoResponse={2,40,2},
        playerLead={0,250,10},dinoLead={0,250,10},
        creatureRange={250,5000,250},creatureLimit={5,30,5},playerRange={250,5000,250}
    }
    local choices={aimPriority={"Crosshair","Nearest"},playerPoint={"Head","Torso"},dinoPoint={"Hitbox","Head"}}
    local function snapshot()
        local values={}
        for _,key in ipairs(boolKeys) do values[key]=state[key] end
        for key in pairs(bounds) do values[key]=state[key] end
        for key in pairs(choices) do values[key]=state[key] end
        local species={}
        for key,enabled in pairs(selectedSpecies) do if enabled then species[#species+1]=key end end
        table.sort(species)
        return {schema=1,hub="PRIMAL",values=values,allSpecies=allSpecies,species=species}
    end
    local function restore(data)
        if type(data)~="table" or data.schema~=1 or data.hub~="PRIMAL" or type(data.values)~="table" then
            return false
        end
        local values=data.values
        state.fly=false; state.speed=false
        stopFly(); stopSpeed()
        for _,key in ipairs(boolKeys) do
            if type(values[key])=="boolean" then state[key]=values[key] end
        end
        for key,range in pairs(bounds) do
            local n=values[key]
            if type(n)=="number" and n==n and math.abs(n)<math.huge then
                n=math.clamp(n,range[1],range[2])
                state[key]=math.clamp(range[1]+math.floor((n-range[1])/range[3]+.5)*range[3],range[1],range[2])
            end
        end
        for key,options in pairs(choices) do
            if table.find(options,values[key]) then state[key]=values[key] end
        end
        if type(data.allSpecies)=="boolean" and type(data.species)=="table" then
            allSpecies=data.allSpecies
            table.clear(selectedSpecies)
            for i,key in ipairs(data.species) do
                if i>1000 then break end
                if type(key)=="string" and #key<=100 and key:match("^%w+$") then selectedSpecies[key]=true end
            end
        end
        for _,refresh in pairs(refreshers) do refresh() end
        for _,refresh in pairs(valueRefreshers) do refresh() end
        lockedModel=nil
        cross.Visible=state.crosshair; fpsLabel.Visible=state.fps
        updateCircles(); redrawSpecies(); refreshESP()
        return true
    end
    local autoButton=button(configs,"",UDim2.new(1,0,0,34),UDim2.new())
    local function updateAuto()
        autoButton.Text="Auto-load active profile: "..(autoload and "ON" or "OFF")
        autoButton.BackgroundColor3=autoload and C.accent or C.row
    end
    local function remember(name,auto)
        if not writeJSON(activePath,{name=name,autoload=auto}) then return false end
        profileName=name; autoload=auto; updateAuto()
        return true
    end
    local saveButton=button(configs,"Save profile",UDim2.new(1,0,0,34),UDim2.new())
    connect(saveButton.Activated,function()
        local name=typedName(); if not name then return end
        if not writeJSON(folder.."/"..name..".json",snapshot()) then message("Save failed; check executor file access."); return end
        local activeSaved=remember(name,autoload)
        refreshList()
        message(activeSaved and ("Saved "..name) or ("Saved "..name.."; active profile not remembered."))
    end)
    local loadButton=button(configs,"Load profile",UDim2.new(1,0,0,34),UDim2.new())
    local function loadProfile(name)
        local data=readJSON(folder.."/"..name..".json")
        if not restore(data) then message("Missing or invalid profile: "..name); return end
        nameBox.Text=name
        local activeSaved=remember(name,autoload)
        message(activeSaved and ("Loaded "..name.."; movement OFF.") or ("Loaded "..name.."; active profile not remembered."))
    end
    connect(loadButton.Activated,function()
        local name=typedName(); if name then loadProfile(name) end
    end)
    connect(autoButton.Activated,function()
        if not autoload and not readJSON(folder.."/"..profileName..".json") then
            message("Save or load a profile before enabling auto-load."); return
        end
        if remember(profileName,not autoload) then
            message(autoload and ("Auto-load enabled: "..profileName) or "Auto-load disabled.")
        else message("Could not save auto-load preference.") end
    end)
    note(configs,"Profiles save feature toggles, tuning and species. Flight and speed never auto-enable.")
    note(configs,"Save replaces the same name. Auto-load is opt-in and uses the last saved or loaded profile.")
    refreshList(); updateAuto()
    if available and autoload then loadProfile(profileName) end
end
local drag,dragStart,startPos
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true; dragStart=input.Position; startPos=panel.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if drag and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-dragStart
        panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,
            startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)
connect(hide.Activated,function() panel.Visible=false end)
connect(close.Activated,function() gui:Destroy() end)
connect(UIS.InputBegan,function(input,processed)
    if not processed and not UIS:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
    end
end)
gui.Destroying:Connect(function()
    alive=false
    syncMenuCursor(false)
    RunService:UnbindFromRenderStep(RENDER_NAME)
    stopFly(); stopSpeed(); clearMarks(); espContainer:Destroy()
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
end)
task.spawn(function()
    local ticks=0
    while alive do
        task.wait(.5)
        if not alive then break end
        ticks+=1
        if state.playerESP or state.creatureESP then refreshESP() end
        if ticks%10==0 then refreshCatalog() end
    end
end)
syncMenuCursor(panel.Visible)
print("[PRIMAL] v"..VERSION.." loaded; RightControl toggles menu and cursor.")
