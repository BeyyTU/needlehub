-- BeyyHub Chapter 1 COMPLETE PASSIVE DUMP v1
-- Standalone, read-only; run in Potassium alongside Chapter 1 main script.
-- All replicated remotes and relevant objects; inbound remote events; hand-in, camera, replay.
-- F6 rescan, F7 stop/save, F8 copy summary, F9 save one JSON report.
local PLACE=108628039999641
if game.PlaceId~=PLACE then
    warn("[CH1 DUMP] Wrong place: "..game.PlaceId.." (expected "..PLACE..")")
    return
end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end
if type(env.__BEYY_CH1_FULL_DUMP_STOP)=="function" then
    pcall(env.__BEYY_CH1_FULL_DUMP_STOP)
end
local OUTPUT="BeyyHub/chapter1_complete_dump.json"
if type(makefolder)=="function" then
    pcall(function()
        if type(isfolder)~="function" or not isfolder("BeyyHub") then makefolder("BeyyHub") end
    end)
end
local active=true
local scanning=false
local saving=false
local started=os.clock()
local snapshotCount=0
local connections={}
local remoteConnected=setmetatable({}, {__mode="k"})
local tracked=0
local previousDiagnostic=nil
local ownDiagnostic=nil
local lastOwned,lastComplete,lastResult,lastLaunch=false,false,false,false
local lastSignature=nil
local nextSave=0
local report={
    version="CH1 complete passive remote and hand-in dump v1",
    placeId=PLACE,jobId=tostring(game.JobId),
    startedUTC=os.date("!%Y-%m-%dT%H:%M:%SZ"),
    limits="Client-visible instances only. Server-side remote handlers, unseen remote calls, and source code are inaccessible passively. No remotes fired or invoked.",
    snapshots={},events={},handInSamples={},remoteCounts={},
    latestRemotes={},latestObjects={},latestHierarchy={},latestScripts={},
    latestInteractions={},latestUI={},latestNeedles={},
    classCounts={},latestState={},tags={},errors={},summary=""
}
local function path(obj)
    local ok,s=pcall(function() return obj:GetFullName() end)
    return ok and s or tostring(obj)
end
local function short(v,n)
    local s=tostring(v)
    n=n or 250
    return #s>n and s:sub(1,n).." [truncated]" or s
end
local function safe(v,depth)
    depth=depth or 0
    local ty=typeof(v)
    if ty=="string" then return short(v,320) end
    if ty=="number" or ty=="boolean" or ty=="nil" then return v end
    if ty=="Instance" then return path(v) end
    if ty=="table" then
        if depth>=2 then return "[table depth limit]" end
        local out,count={},0
        for k,x in pairs(v) do
            count+=1
            if count>25 then out._truncated=true;break end
            out[short(k,45)]=safe(x,depth+1)
        end
        return out
    end
    return short(v,250)
end
local function attrs(obj)
    if not obj then return {} end
    local ok,a=pcall(function() return obj:GetAttributes() end)
    if not ok then return {} end
    local result={}
    for k,v in pairs(a) do
        local name=tostring(k):lower()
        if name:find("password",1,true) or name:find("token",1,true)
            or name:find("secret",1,true) or name:find("authorization",1,true) then
            result[k]="[redacted]"
        else
            result[k]=safe(v)
        end
    end
    return result
end
local function prop(obj,k)
    local ok,v=pcall(function()return obj[k]end)
    return ok and safe(v) or nil
end
local function row(obj)
    local r={class=obj.ClassName,name=obj.Name,path=path(obj)}
    local a=attrs(obj)
    if next(a) then r.attributes=a end
    local ok,tags=pcall(function()return CollectionService:GetTags(obj)end)
    if ok and #tags>0 then r.tags=tags end
    if obj:IsA("BasePart") then
        for _,key in ipairs({"CFrame","Position","Size","Orientation","Anchored","CanCollide","CanTouch","CanQuery","Transparency"}) do
            r[key]=prop(obj,key)
        end
    elseif obj:IsA("Model") then
        local yes,p=pcall(function()return obj:GetPivot()end)
        if yes then r.pivot=tostring(p) end
    elseif obj:IsA("ValueBase") then r.Value=prop(obj,"Value")
    elseif obj:IsA("ProximityPrompt") then
        for _,key in ipairs({"ActionText","ObjectText","Enabled","HoldDuration","MaxActivationDistance","RequiresLineOfSight"}) do
            r[key]=prop(obj,key)
        end
    elseif obj:IsA("ClickDetector") then r.MaxActivationDistance=prop(obj,"MaxActivationDistance")
    elseif obj:IsA("ScreenGui") then r.Enabled=prop(obj,"Enabled")
    elseif obj:IsA("GuiObject") then
        r.Visible=prop(obj,"Visible")
        r.AbsoluteSize=prop(obj,"AbsoluteSize")
        if obj:IsA("TextButton") or obj:IsA("TextLabel") then r.Text=prop(obj,"Text") end
    end
    return r
end
local function entry(kind,message,data,quiet)
    if not active then return end
    local t=math.floor((os.clock()-started)*1000+0.5)/1000
    local e={t=t,kind=kind,message=short(message,550)}
    if data then e.data=data end
    local list=report.events
    list[#list+1]=e
    if #list>3500 then table.remove(list,1) end
    if not quiet then print(string.format("[CH1 DUMP] +%.3fs [%s] %s",t,kind,e.message)) end
end
local function connect(signal,callback)
    local ok,c=pcall(function()return signal:Connect(callback)end)
    if ok then connections[#connections+1]=c end
    return ok
end
local function isRemote(obj)
    return obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
        or obj.ClassName=="UnreliableRemoteEvent"
end
local function inbound(obj)
    return obj:IsA("RemoteEvent") or obj.ClassName=="UnreliableRemoteEvent"
end
local function importantRemote(p)
    p=p:lower()
    for _,word in ipairs({"needle","handin","replay","round","cutscene",
        "skip","key","teleport","objective"}) do
        if p:find(word,1,true) then return true end
    end
    return false
end
local function attachRemote(obj)
    if not active or not isRemote(obj) or remoteConnected[obj] then return end
    remoteConnected[obj]=true
    tracked+=1
    local name=path(obj)
    entry("REMOTE_FOUND",obj.ClassName.." "..name,nil,true)
    if not inbound(obj) then return end
    local ok,err=pcall(function()
        local c=obj.OnClientEvent:Connect(function(...)
            if not active then return end
            local n=(report.remoteCounts[name] or 0)+1
            report.remoteCounts[name]=n
            local priority=importantRemote(name)
            if priority or n<=3 or n%100==0 then
                local values={}
                for i=1,math.min(select("#",...),8) do values[i]=safe(select(i,...)) end
                entry("REMOTE_IN",name.." #"..n.." args="..select("#",...),{
                    remote=name,count=n,arguments=values},not priority)
            end
        end)
        connections[#connections+1]=c
    end)
    if not ok and #report.errors<100 then
        report.errors[#report.errors+1]=name..": "..short(err)
    end
end
local function getFarmer()
    local folder=WS:FindFirstChild("NPC")
    return folder and folder:FindFirstChild("Farmer_NPC")
end
local function getRoot()
    local char=player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getNeedleHaystack()
    return RS:FindFirstChild("NeedleHaystack")
end
local function results()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local ending=pg and pg:FindFirstChild("NeedleEndingUI")
    local frame=ending and ending:FindFirstChild("ReturnToLobby")
    return frame and frame:IsA("GuiObject") and frame.Visible==true or false
end
local function state()
    local root=getRoot()
    local farmer=getFarmer()
    local pivot=farmer and farmer:GetPivot()
    local camera=WS.CurrentCamera
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    local folder=getNeedleHaystack()
    local replay=folder and folder:FindFirstChild("ReplayVote")
    local handin=folder and folder:FindFirstChild("NeedleHandIn")
    local completion=folder and folder:FindFirstChild("NeedleRoundCompleted")
    local r={
        seconds=os.clock()-started,
        owned=player:GetAttribute("NeedleOwned"),
        roundComplete=player:GetAttribute("NeedleRoundComplete"),
        inputLocked=player:GetAttribute("NeedleInputLocked"),
        cutsceneActive=player:GetAttribute("CutsceneActive"),
        hoveredHayId=player:GetAttribute("HoveredHayId"),
        replayVoted=player:GetAttribute("ReplayVoted"),
        replayLaunching=replay and replay:GetAttribute("Launching"),
        resultsVisible=results(),
        NeedleHandInPresent=handin~=nil,
        NeedleRoundCompletedPresent=completion~=nil,
        handInRemoteAttrs=attrs(handin),completionRemoteAttrs=attrs(completion),
        replayRemoteAttrs=attrs(replay),playerAttributes=attrs(player),
        farmerPresent=farmer~=nil,characterPresent=char~=nil
    }
    if root then
        r.position=tostring(root.Position)
        r.CFrame=tostring(root.CFrame)
        r.velocity=tostring(root.AssemblyLinearVelocity)
        r.angularVelocity=tostring(root.AssemblyAngularVelocity)
        r.anchored=root.Anchored
    end
    if humanoid then
        r.humanoidState=tostring(humanoid:GetState())
        r.humanoidHealth=humanoid.Health
        r.autoRotate=humanoid.AutoRotate
    end
    if root and pivot then
        r.farmerDistance=(root.Position-pivot.Position).Magnitude
        r.farmerPivot=tostring(pivot)
        local direction=pivot.Position-root.Position
        local horizontal=Vector3.new(direction.X,0,direction.Z)
        if horizontal.Magnitude>0.01 then
            r.facingDot=root.CFrame.LookVector:Dot(horizontal.Unit)
        end
        if camera and direction.Magnitude>0.01 then
            r.cameraAimDot=camera.CFrame.LookVector:Dot(direction.Unit)
        end
    end
    if camera then
        r.cameraType=tostring(camera.CameraType)
        r.cameraCFrame=tostring(camera.CFrame)
    end
    if char then
        r.characterAttributes=attrs(char)
        local tools={}
        for _,item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then tools[#tools+1]=item.Name end
        end
        r.equippedTools=tools
    end
    return r
end
local function sample(reason)
    local r=state()
    r.reason=reason
    report.latestState=r
    local h=report.handInSamples
    h[#h+1]=r
    if #h>2400 then table.remove(h,1) end
end
local function summary()
    local lines={
        "CH1 COMPLETE PASSIVE REMOTE DUMP v1",
        "PlaceId="..PLACE.." JobId="..tostring(game.JobId),
        string.format("Elapsed=%.1fs scans=%d remotes=%d inboundObserved=%d samples=%d",
            os.clock()-started,snapshotCount,#report.latestRemotes,
            #report.events,#report.handInSamples),
        "Output="..OUTPUT,
        "Native remotes: NeedleHandIn, NeedleRoundCompleted, ReplayVote.",
        "== ALL REPLICATED REMOTES =="
    }
    for _,r in ipairs(report.latestRemotes) do
        lines[#lines+1]=r.class.." "..r.path.." inbound="..
            tostring(report.remoteCounts[r.path] or 0)
    end
    lines[#lines+1]="== RECENT HAND-IN / REPLAY EVENTS =="
    local found=0
    for i=#report.events,1,-1 do
        local e=report.events[i]
        if e.kind=="HUB_DIAG" or e.kind=="OBJECTIVE" or
            e.kind=="TELEPORT" or e.kind=="REMOTE_IN" or e.kind=="REPLAY" then
            lines[#lines+1]=string.format("+%.3f %s %s",e.t,e.kind,e.message)
            found+=1
            if found>=45 then break end
        end
    end
    return table.concat(lines,"\n")
end
local function save()
    if saving or type(writefile)~="function" then return false end
    saving=true
    report.summary=summary()
    report.savedUTC=os.date("!%Y-%m-%dT%H:%M:%SZ")
    report.savedElapsed=os.clock()-started
    local ok,json=pcall(function()return Http:JSONEncode(report)end)
    local wrote,err=false,nil
    if ok then wrote,err=pcall(writefile,OUTPUT,json)
    else err=json end
    saving=false
    if not wrote then warn("[CH1 DUMP] Save failed: "..short(err)) end
    return wrote
end
local words={"needle","farmer","hay","replay","ending","cutscene","skip","result",
    "handin","objective","key","upgrade","tool","vacuum","tnt","pitchfork",
    "drone","teleport","sell","win","gameconfig"}
local function interesting(p)
    p=p:lower()
    for _,word in ipairs(words) do
        if p:find(word,1,true) then return true end
    end
    return false
end
local function scan(reason)
    if not active or scanning then return end
    scanning=true
    snapshotCount+=1
    local t=os.clock()
    local remotes,interactions,scripts,uis,needles,objects,hierarchy={},{},{},{},{},{},{}
    local counts={}
    local total=0
    local maxHierarchy=35000
    local others={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then others[p.Character]=true end
    end
    local excluded={}
    for i,obj in ipairs(game:GetDescendants()) do
        if not active then break end
        if others[obj] or (obj.Parent and excluded[obj.Parent]) then
            excluded[obj]=true
        else
            total+=1
            local p=path(obj)
            counts[obj.ClassName]=(counts[obj.ClassName] or 0)+1
            if #hierarchy<maxHierarchy then
                hierarchy[#hierarchy+1]={path=p,class=obj.ClassName}
            end
            if isRemote(obj) then
                remotes[#remotes+1]=row(obj)
                attachRemote(obj)
            elseif obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector")
                or obj:IsA("TouchTransmitter") then
                interactions[#interactions+1]=row(obj)
            elseif obj:IsA("Script") or obj:IsA("LocalScript")
                or obj:IsA("ModuleScript") then
                scripts[#scripts+1]={path=p,class=obj.ClassName,Enabled=prop(obj,"Enabled"),
                    RunContext=prop(obj,"RunContext")}
            elseif obj:IsA("ScreenGui") or obj:IsA("GuiButton") then
                uis[#uis+1]=row(obj)
            end
            if interesting(p) and #objects<6000 and
                (obj:IsA("Model") or obj:IsA("BasePart") or
                    obj:IsA("ValueBase") or obj:IsA("ProximityPrompt")) then
                objects[#objects+1]=row(obj)
            end
            if obj:IsA("BasePart") and
                (obj.Name:lower()=="needle" or obj:GetAttribute("IsNeedleObjective")==true) then
                needles[#needles+1]=row(obj)
            end
        end
        if i%250==0 then task.wait() end
    end
    if active then
        table.sort(remotes,function(a,b)return a.path<b.path end)
        local ok,tags=pcall(function()return CollectionService:GetAllTags()end)
        if ok then report.tags=tags end
        report.latestRemotes=remotes
        report.latestInteractions=interactions
        report.latestScripts=scripts
        report.latestUI=uis
        report.latestNeedles=needles
        report.latestObjects=objects
        report.latestHierarchy=hierarchy
        report.classCounts=counts
        report.latestState=state()
        report.snapshots[#report.snapshots+1]={
            id=snapshotCount,reason=reason,seconds=os.clock()-started,
            totalObjects=total,hierarchyTruncated=total>maxHierarchy,
            remotes=remotes,needles=needles,
            remoteCount=#remotes,interactionCount=#interactions,
            scriptCount=#scripts,uiCount=#uis,
            state=report.latestState,scanDuration=os.clock()-t
        }
        entry("SNAPSHOT",reason.." objects="..total.." remotes="..#remotes..
            " scripts="..#scripts.." interactions="..#interactions..
            " needles="..#needles)
        if save() then print("[CH1 DUMP] Saved "..OUTPUT) end
    end
    scanning=false
end

-- If BeyyHub's existing live diagnostics are running, forward their HANDIN_REQUEST
-- messages here so client send-to-server timings appear alongside native server events.
-- Never hook game FireServer/namecall or replace a RemoteFunction callback.
local function attachDiagnostic()
    local old=_G.__BEYY_CH1_DIAG_EVENT
    if old==ownDiagnostic then return end
    previousDiagnostic=type(old)=="function" and old or nil
    local previous=previousDiagnostic
    local hook=function(kind,message)
        if active then
            local label=tostring(kind)
            entry("HUB_DIAG",label.." "..short(message,450),nil,
                label~="HANDIN_REQUEST" and label~="HANDIN_READY"
                    and label~="HANDIN_SERVER_EVENT" and label~="HANDIN_CONFIRMED")
            if label:find("HANDIN",1,true) or label=="ROUND_RESULTS" then
                sample(label)
            end
        end
        if previous then pcall(previous,kind,message) end
    end
    ownDiagnostic=hook
    _G.__BEYY_CH1_DIAG_EVENT=hook
end
connect(player.AttributeChanged,function(name)
    if not active then return end
    local key=tostring(name)
    if key:find("Needle",1,true) or key:find("Replay",1,true)
        or key:find("Cutscene",1,true) or key:find("Hay",1,true) then
        entry("PLAYER_ATTR",key.."="..short(player:GetAttribute(name)))
        sample("player_attr_"..key)
        if key=="NeedleOwned" or key=="NeedleRoundComplete" then task.defer(save) end
    end
end)
connect(player.CharacterAdded,function(c)
    entry("CHARACTER","CharacterAdded "..path(c))
end)
connect(player.OnTeleport,function(status)
    entry("TELEPORT",tostring(status))
    sample("on_teleport")
    save()
end)
connect(TeleportService.TeleportInitFailed,function(who,result,message)
    if who==player then
        entry("TELEPORT_FAILED",tostring(result).." "..tostring(message))
        save()
    end
end)
for _,root in ipairs({RS,WS,player}) do
    connect(root.DescendantAdded,function(obj)
        if not active then return end
        if isRemote(obj) then
            attachRemote(obj)
            entry("NEW_REMOTE",obj.ClassName.." "..path(obj))
        elseif interesting(obj.Name) and (obj:IsA("Model")
                or obj:IsA("ValueBase") or obj:IsA("ProximityPrompt")) then
            entry("SPAWN",obj.ClassName.." "..path(obj),nil,true)
        end
    end)
end
local function stop()
    if not active then return end
    sample("stop")
    entry("STOP","Stopped manually, saving final result")
    active=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    if _G.__BEYY_CH1_DIAG_EVENT==ownDiagnostic then
        _G.__BEYY_CH1_DIAG_EVENT=previousDiagnostic
    end
    if env.__BEYY_CH1_FULL_DUMP_STOP==stop then env.__BEYY_CH1_FULL_DUMP_STOP=nil end
    print(save() and "[CH1 DUMP] Complete: "..OUTPUT or
        "[CH1 DUMP] Save unavailable; use F8 to copy summary before stopping.")
end
env.__BEYY_CH1_FULL_DUMP_STOP=stop
connect(UIS.InputBegan,function(input,used)
    if used or not active then return end
    if input.KeyCode==Enum.KeyCode.F6 then task.spawn(scan,"manual_F6")
    elseif input.KeyCode==Enum.KeyCode.F7 then stop()
    elseif input.KeyCode==Enum.KeyCode.F8 then
        local s=summary()
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard
        if copy then
            local ok=pcall(copy,s)
            if ok then print("[CH1 DUMP] Summary copied")
            else print(s) end
        else print(s) end
    elseif input.KeyCode==Enum.KeyCode.F9 then
        print(save() and "[CH1 DUMP] Full JSON saved: "..OUTPUT or
            "[CH1 DUMP] Save unavailable")
    end
end)
entry("START","Read-only Chapter 1 audit, "..tostring(game.JobId))
print("[CH1 DUMP] F6 rescan | F7 stop/save | F8 copy summary | F9 save JSON")
print("[CH1 DUMP] Output: "..OUTPUT.."; run normal Chapter 1 automation for a full round.")
if type(writefile)~="function" then
    warn("[CH1 DUMP] Executor writefile is missing; disk output unavailable.")
end
attachDiagnostic()
task.spawn(scan,"startup")
task.spawn(function()
    while active do
        local owned=player:GetAttribute("NeedleOwned")==true
        local complete=player:GetAttribute("NeedleRoundComplete")==true
        local showing=results()
        local replay=getNeedleHaystack()
        replay=replay and replay:FindFirstChild("ReplayVote")
        local launching=replay and replay:GetAttribute("Launching")==true or false
        if owned~=lastOwned then
            entry("OBJECTIVE","NeedleOwned="..tostring(owned))
            sample("owned_transition");lastOwned=owned
        end
        if complete~=lastComplete then
            entry("OBJECTIVE","NeedleRoundComplete="..tostring(complete))
            sample("complete_transition");lastComplete=complete
            task.defer(save)
        end
        if showing~=lastResult then
            entry("OBJECTIVE","Results visible="..tostring(showing))
            sample("results_transition");lastResult=showing
            task.defer(save)
        end
        if launching~=lastLaunch then
            entry("REPLAY","ReplayVote.Launching="..tostring(launching))
            sample("replay_launch");lastLaunch=launching
            task.defer(save)
        end
        local current=state()
        local signature=table.concat({tostring(current.owned),tostring(current.roundComplete),
            tostring(current.inputLocked),tostring(current.replayLaunching),
            tostring(current.resultsVisible),tostring(current.hoveredHayId),
            tostring(math.floor((current.farmerDistance or -1)*2)/2)},"|")
        if signature~=lastSignature then
            lastSignature=signature
            entry("STATE","owned="..tostring(current.owned)..
                " completed="..tostring(current.roundComplete)..
                " distance="..tostring(current.farmerDistance),nil,true)
        end
        if owned or complete or showing then sample("active_20Hz")
        else report.latestState=current end
        if os.clock()>=nextSave then
            nextSave=os.clock()+10
            save()
        end
        if _G.__BEYY_CH1_DIAG_EVENT~=ownDiagnostic then attachDiagnostic() end
        task.wait((owned or complete or showing) and 0.05 or 0.35)
    end
end)
for _,when in ipairs({15,45,120}) do
    task.delay(when,function()
        if active then task.spawn(scan,"auto_"..when.."s") end
    end)
end
