-- Beyy Auto Farm Wins ONLY (standalone, shareable)
-- Does NOT load BeyyHub, WindUI, other chapter modules, or configs.
-- Extracted behavior: Lobby one-player Normal round, Farmhouse 4-band AFK
-- vacuum sweep and automatic Skip / Replay. Other chapters intentionally excluded.
-- Execute once in Lobby or Farmhouse. Potassium queue_on_teleport supported when available.
-- Stop from console: getgenv().BeyyAutoFarmWinsOnly.Stop()

if not game:IsLoaded() then game.Loaded:Wait() end
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local player=Players.LocalPlayer
if not player then warn("[Beyy Auto Wins] LocalPlayer unavailable") return end

local LOBBY=77108422251420
local FARMHOUSE=108628039999641
if game.PlaceId~=LOBBY and game.PlaceId~=FARMHOUSE then
    warn("[Beyy Auto Wins] This standalone feature supports only Lobby and Farmhouse (Chapter 1).")
    return
end

local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.BeyyAutoFarmWinsOnly)=="table"
    and type(env.BeyyAutoFarmWinsOnly.Stop)=="function" then
    pcall(env.BeyyAutoFarmWinsOnly.Stop)
end
local alive=true
local enabled=true
local connections={}
local holding=false
local downX,downY=0,0
local cameraBound=false
local cameraPrevious=nil
local cameraType=nil
local cameraSubject=nil
local cameraFrame=nil
local renderName="BeyyStandaloneAutoWinsOrbit_"..tostring(player.UserId)
local rounds=0
local function log(message) print("[Beyy Auto Wins] "..tostring(message)) end
local function getRoot()
    local character=player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function on()
    return alive and enabled
end
local function releaseMouse()
    if holding then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(downX,downY,0,false,game,0)
        end)
        holding=false
    end
end
local function restoreCamera()
    if cameraBound then
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
        cameraBound=false
    end
    if cameraPrevious and cameraPrevious.Parent then
        pcall(function()
            cameraPrevious.CameraType=cameraType or Enum.CameraType.Custom
            if cameraSubject and cameraSubject.Parent then
                cameraPrevious.CameraSubject=cameraSubject
            end
            if cameraType==Enum.CameraType.Scriptable and cameraFrame then
                cameraPrevious.CFrame=cameraFrame
            end
        end)
    end
    cameraPrevious,cameraType,cameraSubject,cameraFrame=nil,nil,nil,nil
end
local function stop()
    if not alive then return end
    alive=false
    enabled=false
    releaseMouse()
    restoreCamera()
    for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end) end
    table.clear(connections)
    log("Stopped; mouse released and camera restored.")
end
local api={}
function api.Stop() stop() end
function api.IsEnabled() return on() end
function api.GetRounds() return rounds end
env.BeyyAutoFarmWinsOnly=api

-- Queue only this standalone file on real Roblox teleports, never the main hub.
local queue=nil
for _,name in ipairs({"queue_on_teleport","queueonteleport"}) do
    local value=rawget(env,name)
    if type(value)~="function" then value=rawget(_G,name) end
    if type(value)=="function" then queue=value break end
end
if not queue and type(syn)=="table" and type(syn.queue_on_teleport)=="function" then
    queue=syn.queue_on_teleport
end
local continuation=[[loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/auto-farm-wins-only.lua?t="..tostring(os.time())))()]]
if queue then
    connections[#connections+1]=player.OnTeleport:Connect(function(status)
        if on() and status==Enum.TeleportState.Started then
            local ok,err=pcall(queue,continuation)
            if ok then log("Queued standalone Auto Farm Wins for next place")
            else warn("[Beyy Auto Wins] Teleport queue failed: "..tostring(err)) end
        end
    end)
else
    warn("[Beyy Auto Wins] No queue_on_teleport detected. Re-execute the SAME link after a real Roblox teleport.")
end

local function guiVisible(obj)
    if not obj then return false end
    local current=obj
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current:IsA("PlayerGui") then return true end
        current=current.Parent
    end
    return false
end
local function click(obj,mode)
    if not on() or not guiVisible(obj) or not obj:IsA("GuiObject") then return false end
    local p,s=obj.AbsolutePosition,obj.AbsoluteSize
    if s.X<=0 or s.Y<=0 then return false end
    local inset=GuiService:GetGuiInset()
    local x,y=p.X+s.X*0.5,p.Y+s.Y*0.5
    if mode~="raw" then x+=inset.X;y+=inset.Y end
    local down=false
    local ok,err=pcall(function()
        VirtualInputManager:SendMouseMoveEvent(x,y,game)
        RunService.RenderStepped:Wait()
        if not on() or not guiVisible(obj) then return end
        VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0)
        down=true
        task.wait(0.075)
    end)
    if down then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
    end
    if not ok then warn("[Beyy Auto Wins] UI click: "..tostring(err)) end
    return ok and down
end
local function endingVisible()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local ending=pg and pg:FindFirstChild("NeedleEndingUI")
    return guiVisible(ending and ending:FindFirstChild("ReturnToLobby"))
end
local function inputLocked()
    return player:GetAttribute("NeedleInputLocked")==true
        or player:GetAttribute("CutsceneActive")==true
end

local function lobbyWorker()
    log("Lobby: automatic one-player Normal round creation enabled.")
    local occupied={}
    local busy=false
    local function getCircles()
        local teleporter=Workspace:FindFirstChild("Teleporter")
        local root=getRoot()
        if not teleporter or not root then return {} end
        local list={}
        for _,part in ipairs(teleporter:GetChildren()) do
            if part:IsA("BasePart") and part.Name=="InnerCylinder" then
                local dist=(part.Position-root.Position).Magnitude
                list[#list+1]={part=part,dist=dist}
            end
        end
        table.sort(list,function(a,b)return a.dist<b.dist end)
        return list
    end
    local function occupiedByOther(part)
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then
                local c=other.Character
                local r=c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    local d=r.Position-part.Position
                    if Vector3.new(d.X,0,d.Z).Magnitude<5 then return true end
                end
            end
        end
        return false
    end
    local function container()
        local pg=player:FindFirstChildOfClass("PlayerGui")
        local ui=pg and pg:FindFirstChild("CreatePartyUI")
        local main=ui and ui:FindFirstChild("Main")
        return main and main:FindFirstChild("Container")
    end
    local function attempt(part)
        local c=player.Character
        local root=getRoot()
        local hum=c and c:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return false end
        local goal=Vector3.new(part.Position.X,root.Position.Y,part.Position.Z)
        hum:MoveTo(goal)
        local deadline=os.clock()+3.5
        local panel=container()
        while on() and os.clock()<deadline and not (panel and panel.Visible) do
            if (root.Position-goal).Magnitude>4 then hum:MoveTo(goal) end
            task.wait(0.08)
            panel=container()
        end
        if not on() or not panel or not panel.Visible then return false end
        log("Party creation UI opened")
        local select=panel:FindFirstChild("DifficultyChoosingFrame")
        local normal=select and select:FindFirstChild("NormalMode")
        if normal then click(normal);task.wait(0.12) end
        local number=panel:FindFirstChild("Number")
        local minus=panel:FindFirstChild("Minus")
        if number and minus then
            for _=1,6 do
                if not on() then return false end
                local size=tonumber(number.Text)
                if not size or size<=1 then break end
                click(minus)
                task.wait(0.10)
            end
        end
        local create=panel:FindFirstChild("Create")
        if not create then return false end
        for attemptNumber=1,6 do
            if not on() or not panel.Visible then break end
            local success=click(create,attemptNumber%2==0 and "raw" or "inset")
            if success then log("Create round attempt "..attemptNumber) end
            local due=os.clock()+0.9
            while on() and os.clock()<due and panel.Visible do
                if getRoot() and (getRoot().Position-goal).Magnitude>4 then
                    hum:MoveTo(goal)
                end
                task.wait(0.06)
            end
            if not panel.Visible then log("Round creation GUI dismissed");return true end
        end
        return false
    end
    while on() and game.PlaceId==LOBBY do
        task.wait(0.5)
        if not busy then
            busy=true
            local ok,err=pcall(function()
                for _,entry in ipairs(getCircles()) do
                    if not on() then break end
                    if os.clock()>=(occupied[entry.part] or 0)
                        and not occupiedByOther(entry.part) then
                        if attempt(entry.part) then break end
                        occupied[entry.part]=os.clock()+4
                    elseif occupiedByOther(entry.part) then
                        occupied[entry.part]=os.clock()+15
                    end
                end
            end)
            if not ok then warn("[Beyy Auto Wins] Lobby attempt error: "..tostring(err)) end
            busy=false
        end
    end
end

-- Farmhouse: original BeyyHub four-level 48-degree/s orbit and vacuum follower.
local BANDS={
    {name="base",radius=22,standoff=2.2,lift=5.0,focus=1.5},
    {name="lower-middle",radius=18,standoff=2.0,lift=5.0,focus=-0.1},
    {name="upper-middle",radius=14,standoff=1.9,lift=5.2,focus=-1.5},
    {name="peak",radius=8,standoff=1.7,lift=6.0,focus=0.0},
}
local orbit={
    axis=nil,center=nil,angle=0,lap=0,surface=nil,
    surfaces=nil,top=nil,radius=nil,lift=nil,focus=nil,
    ready=false,targetReady=false,replay=true,startedAt=os.clock(),
    candidate=nil,candidateCount=0,candidateStable=0,
    lastSample=0,lastHayScan=0,calibrationUntil=0,prevCount=0,
}
local function pileHay(obj)
    if not obj or not obj:IsA("BasePart") or obj:GetAttribute("HayId")==nil then return false end
    if obj:GetAttribute("IsHeld")==true or obj:GetAttribute("Held")==true then return false end
    return not (player.Character and obj:IsDescendantOf(player.Character))
end
local function hayFolder()
    return Workspace:FindFirstChild("HaystackClient")
end
local function pileCenter()
    local folder=hayFolder()
    if not folder then return nil,0,0 end
    local all=folder:GetChildren()
    local step=math.max(1,math.ceil(#all/512))
    local xs,zs,ys={},{},{}
    local low,high=math.huge,-math.huge
    for i=1,#all,step do
        local p=all[i]
        if pileHay(p) then
            xs[#xs+1]=p.Position.X
            zs[#zs+1]=p.Position.Z
            ys[#ys+1]=p.Position.Y
            low=math.min(low,p.Position.Y-p.Size.Y*0.5)
            high=math.max(high,p.Position.Y+p.Size.Y*0.5)
        end
    end
    local n=#xs
    if n==0 then return nil,0,0 end
    table.sort(xs);table.sort(zs);table.sort(ys)
    local lo=math.max(1,math.ceil(n*0.10))
    local hi=math.min(n,math.ceil(n*0.90))
    return Vector3.new((xs[lo]+xs[hi])/2,ys[math.ceil(n*0.5)],
        (zs[lo]+zs[hi])/2),n*step,high-low
end
local function computeSurfaces(center)
    local folder=hayFolder()
    local sample={{},{},{},{}}
    local low,high=math.huge,-math.huge
    if folder then
        for _,part in ipairs(folder:GetChildren()) do
            if pileHay(part) then
                local top=part.Position.Y+part.Size.Y*0.5
                low=math.min(low,part.Position.Y-part.Size.Y*0.5)
                high=math.max(high,top)
                local dx=part.Position.X-center.X
                local dz=part.Position.Z-center.Z
                local r=math.sqrt(dx*dx+dz*dz)
                for i,band in ipairs(BANDS) do
                    if math.abs(r-band.radius)<=5.5 then
                        sample[i][#sample[i]+1]=top
                    end
                end
            end
        end
    end
    if low==math.huge then low=center.Y-4 end
    if high==-math.huge then high=center.Y+8 end
    local fractions={0.12,0.36,0.63,0.88}
    local heights={}
    for i,heightsAtRadius in ipairs(sample) do
        local baseline=low+(high-low)*fractions[i]
        if #heightsAtRadius>=6 then
            table.sort(heightsAtRadius)
            heights[i]=math.clamp(
                heightsAtRadius[math.max(1,math.ceil(#heightsAtRadius*0.90))],low,high)
        else
            heights[i]=baseline
        end
        if i>1 then heights[i]=math.max(heights[i],heights[i-1]) end
    end
    return heights,high
end
local function resetRound(reason)
    releaseMouse()
    restoreCamera()
    orbit.center=nil
    orbit.angle,orbit.lap=0,0
    orbit.ready,orbit.targetReady=false,false
    orbit.replay=true
    orbit.startedAt=os.clock()
    orbit.candidate,orbit.candidateCount,orbit.candidateStable=nil,0,0
    orbit.lastSample=0
    orbit.surfaces=nil
    orbit.calibrationUntil=0
    log("Round reset: "..tostring(reason).." (fixed pile X/Z retained)")
end
local function calibrate()
    if not on() or endingVisible() or inputLocked() then return end
    local now=os.clock()
    if now-orbit.lastSample<0.45 then return end
    orbit.lastSample=now
    local point,count,span=pileCenter()
    if not point or count<math.min(25,now-orbit.startedAt>5 and 8 or 25) then return end
    local valid=true
    if orbit.candidate then
        local prev=orbit.candidate
        local shift=Vector3.new(point.X-prev.X,0,point.Z-prev.Z).Magnitude
        local populationChange=math.abs(count-orbit.candidateCount)/
            math.max(1,orbit.candidateCount)
        valid=shift<=2 and populationChange<=0.30
    end
    orbit.candidateStable=valid and orbit.candidateStable+1 or 1
    orbit.candidate,orbit.candidateCount=point,count
    if orbit.candidateStable<2 and now-orbit.startedAt<4 then return end
    if not orbit.axis then
        orbit.axis=Vector3.new(point.X,point.Y,point.Z)
    end
    orbit.center=Vector3.new(orbit.axis.X,point.Y,orbit.axis.Z)
    orbit.surfaces,orbit.top=computeSurfaces(orbit.center)
    local band=BANDS[1]
    orbit.radius=band.radius+band.standoff
    orbit.lift=band.lift
    orbit.focus=band.focus
    orbit.surface=orbit.surfaces[1]
    orbit.ready,orbit.replay=true,false
    orbit.prevCount=count
    orbit.calibrationUntil=now+16
    log(string.format("Pile stable: hay=%d; axis=(%.1f,%.1f); four-band vacuum sweep ready",
        count,orbit.axis.X,orbit.axis.Z))
end
local function bindCamera()
    if cameraBound or not orbit.ready then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    cameraPrevious, cameraType, cameraSubject, cameraFrame=
        cam,cam.CameraType,cam.CameraSubject,cam.CFrame
    local ok,err=pcall(function()
        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+10,function(dt)
            if not on() or not orbit.ready or endingVisible() or inputLocked() then return end
            local camera=Workspace.CurrentCamera
            local center=orbit.center
            if not camera or not center then return end
            dt=math.clamp(dt,0,0.25)
            local theta=orbit.angle+math.rad(48)*dt
            if theta>=math.pi*2 then
                orbit.lap+=1
            end
            orbit.angle=theta%(math.pi*2)
            local index=(orbit.lap%#BANDS)+1
            local band=BANDS[index]
            local k=1-math.exp(-3*dt)
            local r=band.radius+band.standoff
            orbit.radius+=(r-orbit.radius)*k
            local y=(orbit.surfaces and orbit.surfaces[index]) or orbit.top or center.Y
            orbit.surface+=(y-orbit.surface)*k
            orbit.lift+=(band.lift-orbit.lift)*k
            orbit.focus+=(band.focus-orbit.focus)*k
            local radial=Vector3.new(math.cos(orbit.angle),0,math.sin(orbit.angle))
            local cpos=Vector3.new(center.X+radial.X*(orbit.radius+2.6),
                orbit.surface+orbit.lift,
                center.Z+radial.Z*(orbit.radius+2.6))
            local look=Vector3.new(center.X+radial.X*math.max(0,orbit.radius-5),
                orbit.surface+orbit.focus,
                center.Z+radial.Z*math.max(0,orbit.radius-5))
            camera.CameraType=Enum.CameraType.Scriptable
            camera.CFrame=CFrame.lookAt(cpos,look,Vector3.yAxis)
        end)
    end)
    if ok then cameraBound=true;log("Camera orbit active (48 deg/s, 22/18/14/8 rings)")
    else warn("[Beyy Auto Wins] Camera bind failed: "..tostring(err)) end
end
local function followAndProbe()
    if not on() or not orbit.ready or endingVisible() or inputLocked() then
        orbit.targetReady=false
        return
    end
    local char=player.Character
    local root=getRoot()
    local c=orbit.center
    if not char or not root or not c then return end
    local radial=Vector3.new(math.cos(orbit.angle),0,math.sin(orbit.angle))
    local dest=Vector3.new(c.X+radial.X*orbit.radius,orbit.surface+3.25,
        c.Z+radial.Z*orbit.radius)
    if (root.Position-dest).Magnitude>0.4 then
        local toRoot=root.CFrame:ToObjectSpace(char:GetPivot())
        local face=Vector3.new(c.X,dest.Y-1.25,c.Z)
        pcall(function()
            if on() and not endingVisible() and char.Parent and root.Parent then
                char:PivotTo(CFrame.lookAt(dest,face,Vector3.yAxis)*toRoot)
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
            end
        end)
    end
    local now=os.clock()
    if now-orbit.lastHayScan>=0.45 then
        orbit.lastHayScan=now
        orbit.targetReady=false
        local folder=hayFolder()
        if folder then
            local index=(orbit.lap%#BANDS)+1
            local probe=c+radial*BANDS[index].radius
            for _,part in ipairs(folder:GetChildren()) do
                if pileHay(part) then
                    local dx=part.Position.X-probe.X
                    local dz=part.Position.Z-probe.Z
                    if dx*dx+dz*dz<=144
                        and math.abs(part.Position.Y-orbit.surface)<=12 then
                        orbit.targetReady=true
                        break
                    end
                end
            end
        end
    end
end
local function heat()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local hud=pg and pg:FindFirstChild("HUD")
    local overheat=hud and hud:FindFirstChild("Overheat")
    local fill=overheat and overheat:FindFirstChild("Fill")
    if not fill or not fill:IsA("GuiObject") then return nil end
    local value=fill.Size.Y.Scale
    if type(value)~="number" or value~=value or value< -0.05 or value>1.05 then
        return nil
    end
    return math.clamp(value,0,1)
end
local function upgradeLevel(name)
    return math.max(0,math.floor(tonumber(player:GetAttribute("HayUpgrade"..name)) or 0))
end
local function hotbarVacuum()
    local c=player.Character
    if not c then return false end
    local backpack=player:FindFirstChildOfClass("Backpack")
    local tool=nil
    for _,container in ipairs({c,backpack}) do
        if container then
            for _,t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("vacuum",1,true) then
                    tool=t;break
                end
            end
        end
        if tool then break end
    end
    if tool and tool.Parent==c then return true end
    local key=Enum.KeyCode.Five
    pcall(function() VirtualInputManager:SendKeyEvent(true,key,false,game) end)
    task.wait(0.07)
    pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
    task.wait(0.20)
    if tool and tool.Parent==backpack then
        local hum=c:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()hum:EquipTool(tool)end)
            task.wait(0.08)
        end
    end
    return on() and not inputLocked()
end
local function farmhouseWorker()
    log("Farmhouse: four-band AFK sweep, heat-controlled vacuum, Skip and Replay enabled.")
    local nextSkip,nextReplay=0,0
    local replayStreak=0
    local resultsWasVisible=false
    local replayButtonSeenAt=0
    local replayButton=nil
    local cooling=false
    local heatReadyAt=0
    local suckedAt=0
    local lastHeatRise=os.clock()
    local previousHeat=nil
    local vacuumStarted=false
    local function finishVacuum(cooldown)
        releaseMouse()
        if cooldown then
            cooling=true
            heatReadyAt=os.clock()+cooldown
        end
        vacuumStarted=false
        previousHeat=nil
    end
    local function canVacuum()
        return on() and orbit.ready and orbit.targetReady
            and not endingVisible() and not inputLocked()
    end
    local function replayButtonLookup()
        local pg=player:FindFirstChildOfClass("PlayerGui")
        local ending=pg and pg:FindFirstChild("NeedleEndingUI")
        local frame=ending and ending:FindFirstChild("ReturnToLobby")
        local btn=frame and frame:FindFirstChild("ReplayButton")
        if not guiVisible(btn) then return nil end
        if btn:IsA("GuiButton") then return btn end
        for _,child in ipairs(btn:GetDescendants()) do
            if child:IsA("GuiButton") and guiVisible(child) then return child end
        end
        return nil
    end
    local function locallyVoted(btn)
        if not btn then return false end
        local list={btn}
        for _,c in ipairs(btn:GetDescendants()) do list[#list+1]=c end
        for _,part in ipairs(list) do
            for _,name in ipairs({"Voted","HasVoted","IsVoted","Selected"}) do
                if part:GetAttribute(name)==true then return true end
            end
            if part:IsA("TextLabel") or part:IsA("TextButton") then
                local t=part.Text:lower()
                if t:find("you voted",1,true)
                    or t:match("^%s*voted[%s%d%p]*$")
                    or t:match("^%s*selected[%s%d%p]*$") then
                    return true
                end
            end
        end
        return false
    end
    local function skipButton()
        local pg=player:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        for _,obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("GuiButton") and guiVisible(obj) then
                local t=obj.Name:lower()
                if obj:IsA("TextButton") then t=t.." "..obj.Text:lower() end
                if t:find("skip",1,true) then return obj end
            end
        end
        return nil
    end
    local function replayCooldown()
        if replayStreak<2 then return 1 end
        if replayStreak<5 then return 1.5 end
        if replayStreak<12 then return 3 end
        if replayStreak<30 then return 10 end
        return 30
    end
    local function executeReplay()
        local btn=replayButtonLookup()
        if not btn then return end
        if btn~=replayButton then
            replayButton=btn
            replayButtonSeenAt=os.clock()
            replayStreak=0
        end
        if locallyVoted(btn) then return end
        local now=os.clock()
        if now-replayButtonSeenAt<0.20 or now<nextReplay then return end
        local method=replayStreak%6
        local success=false
        if (method==3 or method==4) and type(firesignal)=="function" then
            local sig=method==3 and btn.MouseButton1Click or btn.Activated
            success=pcall(function()firesignal(sig)end)
        end
        if not success then
            success=click(btn,(method==2 or method==5) and "raw" or "inset")
        end
        if success then
            replayStreak+=1
            log("Replay attempt "..replayStreak.."; awaiting local vote confirmation")
        end
        nextReplay=now+replayCooldown()
    end
    local function updateRounds()
        local ending=endingVisible()
        if ending and not resultsWasVisible then
            resultsWasVisible=true
            rounds+=1
            finishVacuum()
            restoreCamera()
            log("Round results visible; attempting Replay")
        elseif not ending and resultsWasVisible then
            resultsWasVisible=false
            replayButton=nil
            replayStreak=0
            nextReplay=0
            resetRound("Replay/results dismissed")
        end
        return ending
    end
    -- One light scheduler for state; separate vacuum input loop prevents
    -- blocking Skip/Replay while a suction cycle is held.
    task.spawn(function()
        while on() do
            task.wait(0.06)
            updateRounds()
            if not endingVisible() then
                if not orbit.ready then
                    calibrate()
                else
                    if not cameraBound then bindCamera() end
                    followAndProbe()
                    if orbit.calibrationUntil>os.clock()
                        and os.clock()-orbit.lastSample>=1.25 then
                        orbit.lastSample=os.clock()
                        local center,count,span=pileCenter()
                        if center and count>=orbit.prevCount*1.25 then
                            orbit.prevCount=count
                            local current=orbit.center
                            orbit.center=Vector3.new(orbit.axis.X,current.Y,orbit.axis.Z)
                            orbit.surfaces,orbit.top=computeSurfaces(orbit.center)
                            log("Replay pile layers refreshed without moving X/Z axis")
                        end
                    end
                end
            end
        end
    end)
    task.spawn(function()
        while on() do
            task.wait(0.06)
            if not canVacuum() then
                if holding then finishVacuum() end
                continue
            end
            local current=heat()
            local coolingSeconds=upgradeLevel("VacuumCooling")==0
                and 13 or math.max(7,12-upgradeLevel("VacuumCooling"))
            local runtime=30+3*upgradeLevel("VacuumRuntime")
            if current and current>=0.999 then
                finishVacuum(coolingSeconds+0.5)
                continue
            end
            if cooling then
                if (current and current<=0.001)
                    or (not current and os.clock()>=heatReadyAt) then
                    cooling=false
                else
                    continue
                end
            end
            if not holding then
                if not hotbarVacuum() or not canVacuum() then continue end
                local cam=Workspace.CurrentCamera
                if not cam then continue end
                local viewport=cam.ViewportSize
                local x,y=viewport.X/2,viewport.Y/2
                local ok=pcall(function()
                    VirtualInputManager:SendMouseMoveEvent(x,y,game)
                    VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0)
                end)
                if not ok then continue end
                holding=true
                downX,downY=x,y
                vacuumStarted=true
                suckedAt=os.clock()
                previousHeat=current
                lastHeatRise=suckedAt
                log("Vacuum suction started")
            else
                local now=os.clock()
                if current and previousHeat and current>previousHeat+0.0002 then
                    lastHeatRise=now
                end
                if current~=nil then
                    if now-lastHeatRise>4 then
                        finishVacuum()
                        heatReadyAt=now+0.5
                        log("Vacuum heat stalled; retrying equip")
                    end
                elseif now-suckedAt>=runtime+1 then
                    finishVacuum(coolingSeconds+0.5)
                end
                previousHeat=current
            end
        end
        releaseMouse()
    end)
    while on() and game.PlaceId==FARMHOUSE do
        task.wait(0.22)
        if updateRounds() then
            if holding then finishVacuum() end
            executeReplay()
        elseif not inputLocked() and os.clock()>=nextSkip then
            local btn=skipButton()
            if btn then
                releaseMouse()
                if click(btn) then
                    log("Skip button clicked")
                    nextSkip=os.clock()+1.4
                end
            end
        end
    end
end

if game.PlaceId==LOBBY then
    task.spawn(lobbyWorker)
else
    task.spawn(farmhouseWorker)
end
log("Standalone Auto Farm Wins started. No BeyyHub UI or other modules loaded.")
