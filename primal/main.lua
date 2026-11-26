-- BeyyHub | PRIMAL: Evolved v0.2.3
-- Independent client menu. No remote invocation or anti-cheat bypass.
local VERSION = "0.2.3"
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
    crosshair=false, circle=false, fps=false, flySpeed=30, aimRadius=150, speed=false, speedMultiplier=1.25}
local connections, marks, refreshers = {}, {}, {}
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
local visuals=tab("Visuals")
local combat=tab("Combat")
local settings=tab("Settings")

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

-- Visual markers are created locally and removed on disable/unload.
local function clearMarks()
    for model,mark in pairs(marks) do mark:Destroy(); marks[model]=nil end
end
local function refreshESP()
    local wanted={}
    if state.playerESP then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player and p.Character then wanted[p.Character]=C.red end
        end
    end
    if state.creatureESP then
        local folder=workspace:FindFirstChild("BadWaveCreatures")
        if folder then
            for _,model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then wanted[model]=C.amber end
            end
        end
    end
    for model,mark in pairs(marks) do
        if not wanted[model] or not model.Parent then mark:Destroy(); marks[model]=nil end
    end
    for model,color in pairs(wanted) do
        if not marks[model] then
            marks[model]=node("Highlight",gui,{Adornee=model,FillColor=color,OutlineColor=color,
                FillTransparency=.78,OutlineTransparency=.1,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop})
        end
    end
end
toggle(visuals,"Player ESP","playerESP",refreshESP)
toggle(visuals,"Creature ESP","creatureESP",refreshESP)
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
toggle(visuals,"Crosshair","crosshair",function(on) cross.Visible=on end)
toggle(visuals,"Aim FOV circle","circle",function(on) circle.Visible=on end)
local fpsLabel=text(overlay,"FPS: --",UDim2.fromOffset(145,24),UDim2.fromOffset(12,72),14,C.green)
fpsLabel.Visible=false
toggle(visuals,"FPS counter","fps",function(on) fpsLabel.Visible=on end)

-- Camera-only aim assistance, while holding RMB. No weapon or remote calls.
toggle(combat,"Aim assist (players)","aim")
stepper(combat,"Aim radius (px)","aimRadius",50,400,25)
note(combat,"Hold right mouse button with menu hidden. Only targets visible to the camera.")
local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater=true
local function getTarget(cam)
    local viewport=cam.ViewportSize
    local center=viewport*.5
    local best,bestDistance=nil,state.aimRadius
    rayParams.FilterDescendantsInstances=player.Character and {player.Character} or {}
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player and (not player.Team or player.Team~=other.Team or player.Neutral or other.Neutral) then
            local char=other.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local part=char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            if hum and hum.Health>0 and part and part:IsA("BasePart") then
                local screen,visible=cam:WorldToViewportPoint(part.Position)
                local distance=(Vector2.new(screen.X,screen.Y)-center).Magnitude
                if visible and screen.Z>0 and distance<bestDistance then
                    local origin=cam.CFrame.Position
                    local hit=workspace:Raycast(origin,part.Position-origin,rayParams)
                    if not hit or hit.Instance:IsDescendantOf(char) then
                        best,bestDistance=part,distance
                    end
                end
            end
        end
    end
    return best
end
local frames,elapsed=0,0
RunService:BindToRenderStep(RENDER_NAME,Enum.RenderPriority.Camera.Value+5,function(dt)
    if not alive then return end
    frames+=1; elapsed+=dt
    if elapsed>=.5 then
        fpsLabel.Text="FPS: "..tostring(math.floor(frames/elapsed+.5))
        frames,elapsed=0,0
    end
    circle.Size=UDim2.fromOffset(state.aimRadius*2,state.aimRadius*2)
    if not state.aim or panel.Visible or UIS:GetFocusedTextBox()
        or not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local cam=workspace.CurrentCamera
    if not cam then return end
    local target=getTarget(cam)
    if target then
        local current=cam.CFrame
        cam.CFrame=current:Lerp(CFrame.lookAt(current.Position,target.Position),math.clamp(dt*18,0,1))
    end
end)
note(settings,"Place: "..tostring(game.PlaceId).."  |  Build: "..tostring(game.PlaceVersion))
note(settings,"All gameplay features default to OFF. Close to unload and restore flight controls.")
local reset=button(settings,"Disable all features",UDim2.new(1,0,0,36),UDim2.new())
connect(reset.Activated,function()
    for key,refresh in pairs(refreshers) do state[key]=false; refresh() end
    stopFly(); stopSpeed(); clearMarks(); cross.Visible=false; circle.Visible=false; fpsLabel.Visible=false
end)
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
    RunService:UnbindFromRenderStep(RENDER_NAME)
    stopFly(); stopSpeed(); clearMarks()
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
end)
task.spawn(function()
    while alive do
        task.wait(.5)
        if alive and (state.playerESP or state.creatureESP) then refreshESP() end
    end
end)
print("[PRIMAL] v"..VERSION.." loaded; RightControl toggles menu.")
