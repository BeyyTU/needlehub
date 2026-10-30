-- Beyy Chapter 2 Early Intro Levers Test v2
-- Standalone experimental combination:
-- (1) Hide the visible CutsceneFade.Black overlay,
-- (2) allow mouse-driven camera before the first native Skip button,
-- (3) release camera and click that normal Skip button instantly.
-- No puzzle remotes, forced attributes, character teleports, or Main edits.
-- Start from lobby; this copy is queued verbatim for the Chapter 2 teleport.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-early-intro-levers-test.lua"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local env=_G
if type(getgenv)=="function" then
    local ok,res=pcall(getgenv)
    if ok and type(res)=="table" then env=res end
end
if game.PlaceId==LOBBY then
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then
        queue=syn.queue_on_teleport
    end
    if type(queue)~="function" then
        warn("[CH2 COMBO] queue_on_teleport unavailable; execute again immediately on entering Chapter 2.")
        return
    end
    local ok,body=pcall(function()
        return game:HttpGet(URL.."?preload="..tostring(os.time()).."-"..tostring(math.random(10000,99999)))
    end)
    local valid=ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Early Intro Levers Test v2",1,true)
        and type(loadstring)=="function" and type(loadstring(body))=="function"
    local payload=valid and body or
        ('loadstring(game:HttpGet("'..URL..'?queued="..tostring(os.time())))()')
    local armed,err=pcall(queue,payload)
    if armed then
        print("[CH2 COMBO] Combined black-screen + camera + instant Skip test queued ("..
            (valid and "preloaded" or "online fallback").."). Enter Chapter 2.")
    else
        warn("[CH2 COMBO] Failed to queue: "..tostring(err))
    end
    return
end
if game.PlaceId~=CHAPTER2 then
    warn("[CH2 COMBO] Only lobby or Chapter 2 supported; place="..tostring(game.PlaceId))
    return
end
if type(env.__BEYY_CH2_COMBO_STOP)=="function" then
    pcall(env.__BEYY_CH2_COMBO_STOP)
end

local started=os.clock()
local timeout=42
local player=nil
local alive=true
local connections={}
local eventLines={}
local firstTimes={}
local attrs={}
local outputPath="BeyyHub/chapter2_early_intro_levers_result.txt"
local renderName="BeyyCh2CombinedPreSkipCamera"
local overlay,overlayOriginalVisible=nil,nil
local cameraActive,cameraReleased=false,false
local yaw,pitch,followDistance=nil,-0.18,4
local previousCameraLook=nil
local skipSeen=false
local attempts=0
local lastAttemptAt=-math.huge
local clickRunning=false
local lastSaveAt=0
local lastCameraDeltaAt=-math.huge
local introCompletedAt=nil
local stopReason=nil
local leverStarted=false
local leverFinished=false
local leverResults={}

local function seconds() return os.clock()-started end
local function emit(kind,message)
    local line=string.format("+%.3fs [%s] %s",seconds(),kind,tostring(message))
    eventLines[#eventLines+1]=line
    if #eventLines>550 then table.remove(eventLines,1) end
    print("[CH2 COMBO] "..line)
end
local function first(key,value)
    if firstTimes[key]~=nil then return end
    firstTimes[key]=seconds()
    emit("FIRST",key..": "..tostring(value or ""))
end
local function changed(key,value)
    local v=tostring(value)
    if attrs[key]~=v then
        attrs[key]=v
        emit("STATE",key.."="..v)
    end
end
local function hook(signal,callback)
    local ok,c=pcall(function()return signal:Connect(callback)end)
    if ok and c then connections[#connections+1]=c end
end
local function report()
    local result={
        "CHAPTER 2 EARLY INTRO LEVERS TEST v2",
        "Times relative to the test executing in Chapter 2.",
        "Test actions: local blackout GUI/camera, native intro Skip click, and BeyyHub-derived lever movement / PuzzleAction requests.",
        "Skip attempts: "..tostring(attempts),
        "Lever test started: "..tostring(leverStarted)..", finished: "..tostring(leverFinished),
        "Stopped: "..tostring(stopReason or "in progress"),
        "=== MILESTONES ==="
    }
    for _,name in ipairs({"player","loaded","character","leversReady","cutsceneActive",
        "overlayFound","overlayHidden","leverStarted","cameraStarted","cameraMoved","skipVisible",
        "cameraReleased","firstClick","cutsceneCleared","introFinished",
        "overlayRestored","userCameraWorksF6","userCameraLockedF7"}) do
        result[#result+1]=name.." = "..(firstTimes[name] and
            string.format("+%.3fs",firstTimes[name]) or "NOT OBSERVED")
    end
    if firstTimes.firstClick and firstTimes.introFinished then
        result[#result+1]=string.format("Time click -> intro complete = %.3fs",
            firstTimes.introFinished-firstTimes.firstClick)
    end
    result[#result+1]="=== LEVER RESULTS ==="
    for i=1,3 do
        local v=leverResults[i]
        result[#result+1]=v and string.format("Lever%d early=%s postIntro=%s final=%s attempts=%d",
            i,tostring(v.early),tostring(v.after),tostring(v.ok),v.attempts) or
            ("Lever"..i.." NOT TESTED")
    end
    result[#result+1]="=== EVENTS ==="
    result[#result+1]=table.concat(eventLines,"\n")
    return table.concat(result,"\n")
end
local function save(copy)
    local body=report()
    if type(writefile)=="function" then
        if type(makefolder)=="function" then
            pcall(function()
                if type(isfolder)~="function" or not isfolder("BeyyHub") then
                    makefolder("BeyyHub")
                end
            end)
        end
        local ok,err=pcall(writefile,outputPath,body)
        if ok then print("[CH2 COMBO] Saved "..outputPath)
        else warn("[CH2 COMBO] Save error: "..tostring(err)) end
    else
        print("[CH2 COMBO] writefile unavailable; capture console output.")
    end
    if copy then
        if type(setclipboard)=="function" then
            local ok,err=pcall(setclipboard,body)
            if ok then print("[CH2 COMBO] Full report COPIED to clipboard")
            else warn("[CH2 COMBO] Clipboard error: "..tostring(err)) end
        else
            print("[CH2 COMBO] setclipboard unavailable; report saved if writefile exists.")
        end
    end
    lastSaveAt=seconds()
end
local function releaseCamera(reason)
    if cameraReleased then return end
    cameraReleased=true
    if cameraActive then
        cameraActive=false
        local cam=Workspace.CurrentCamera
        if cam then
            local char=player and player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function()cam.CameraSubject=hum end) end
            pcall(function()cam.CameraType=Enum.CameraType.Custom end)
        end
        pcall(function()
            UserInputService.MouseBehavior=Enum.MouseBehavior.Default
        end)
    end
    first("cameraReleased",reason)
end
local overlayRestored=false
local function restoreOverlay(reason)
    if overlayRestored then return end
    overlayRestored=true
    if overlay and overlay.Parent and overlayOriginalVisible~=nil then
        pcall(function()overlay.Visible=overlayOriginalVisible end)
    end
    first("overlayRestored",reason)
end
local function stop(reason)
    if not alive then return end
    stopReason=reason or "manual stop"
    releaseCamera("test cleanup")
    restoreOverlay("test cleanup")
    alive=false
    pcall(function()RunService:UnbindFromRenderStep(renderName)end)
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    table.clear(connections)
    emit("DONE",stopReason)
    save(true)
end
env.__BEYY_CH2_COMBO_STOP=stop
env.__BEYY_CH2_COMBO_REPORT=report
env.__BEYY_CH2_COMBO_COPY=function()save(true)end

local function isVisible(element)
    local node=element
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        if node:IsA("PlayerGui") then return true end
        node=node.Parent
    end
    return false
end
local function guiObjects()
    local pg=player and player:FindFirstChildOfClass("PlayerGui")
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local black=fade and fade:FindFirstChild("Black",true)
    local holder=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    local skip=holder and holder:FindFirstChild("Button",true)
    if skip and not skip:IsA("GuiButton") then skip=nil end
    return pg,fade,black,skip
end
local function safeToSkip(button)
    if not alive or not player or not button or not isVisible(button)
        or seconds()>19 or player:GetAttribute("CutsceneActive")~=true
        or player:GetAttribute("IntroCutsceneFinished")==true
        or player:GetAttribute("Chapter2ReleaseActive")==true
        or player:GetAttribute("NeedleRoundComplete")==true then return false end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local ending=pg and pg:FindFirstChild("NeedleEndingUI")
    if ending and ending:IsA("ScreenGui") and ending.Enabled then return false end
    local remotes=ReplicatedStorage:FindFirstChild("Puzzles")
    -- The early lever test may already have solved LeverPuzzle during
    -- the intro. Do not let that success suppress the native intro Skip.
    -- Keep the protection against having begun the three room puzzles.
    if remotes and (tonumber(remotes:GetAttribute("SolvedPuzzleCount")) or 0)>0 then
        return false
    end
    return button.AbsoluteSize.X>8 and button.AbsoluteSize.Y>8
end

local function clickSkip(button,attempt)
    local pos,size=button.AbsolutePosition,button.AbsoluteSize
    local inset=GuiService:GetGuiInset()
    local x,y=pos.X+size.X/2,pos.Y+size.Y/2
    local method="inset"
    if attempt==1 then
        x+=inset.X
        y+=inset.Y
    else
        method="raw"
    end
    emit("ACTION",string.format("Click #%d %s at %.0f, %.0f; blackout hidden=%s",
        attempt,method,x,y,tostring(overlay and overlay.Visible==false)))
    local down=false
    local ok,err=pcall(function()
        VirtualInputManager:SendMouseMoveEvent(x,y,game)
        task.wait(0.035)
        if not safeToSkip(button) then return end
        VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0)
        down=true
        task.wait(0.075)
    end)
    if down then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
    end
    emit("ACTION",ok and ("Mouse click sent; down="..tostring(down)..
        "; awaiting IntroCutsceneFinished") or ("Mouse input failed: "..tostring(err)))
end


-- Native fast-lever method from Main Chapter2's runConfirmedPuzzles:
-- move beside LeverN at (pivot.X, player floorY, pivot.Z + 3), settle .10s,
-- FireServer("LeverPuzzle","LeverN") with .12s cadence, and confirm from
-- replicated "LeverNPulled" attributes or PuzzleState.LeverPuzzle.steps.
-- Experimental change: one request per lever during the black screen,
-- then TWO targeted pre-Skip retries on any unconfirmed lever.
-- If denied, the bounded Main-like 3+2 retries happen after native Skip.
local function runEarlyLevers()
    local p=player
    local char=p and p.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local w=Workspace:FindFirstChild("Puzzles")
    local models=w and w:FindFirstChild("LeverPuzzle")
    local folder=models and models:FindFirstChild("Levers")
    local f=ReplicatedStorage:FindFirstChild("Puzzles")
    local action=f and f:FindFirstChild("PuzzleAction")
    if not (p and char and root and folder and f
        and action and action:IsA("RemoteEvent")) then
        emit("LEVER","Missing native character/lever/remote, test skipped")
        leverFinished=true
        return
    end
    local floorY=root.Position.Y
    local originalPosition=root.CFrame
    local lastRequest=-math.huge
    local state={}
    local hadTemporaryUnanchor=false
    for i=1,3 do
        leverResults[i]={early=false,after=false,ok=false,attempts=0}
    end
    local function safe()
        return alive and p.Character==char and root.Parent~=nil
            and p:GetAttribute("NeedleRoundComplete")~=true
            and p:GetAttribute("Chapter2ReleaseActive")~=true
    end
    local function pulled(i)
        local l=state.LeverPuzzle
        local steps=type(l)=="table" and l.steps or nil
        return f:GetAttribute("Lever"..i.."Pulled")==true
            or (type(steps)=="table" and steps["Lever"..i]==true)
    end
    local function check(i,stage)
        if not pulled(i) then return false end
        local v=leverResults[i]
        -- Record the FIRST confirmed stage; don't incorrectly label a
        -- lever completed during the intro as completed after Skip too.
        if not v.ok then
            v.ok=true
            local beforeIntro=p:GetAttribute("IntroCutsceneFinished")~=true
            v.early=beforeIntro
            v.after=not beforeIntro
            emit("LEVER","Lever"..i.." SERVER CONFIRMED in "..stage..
                " beforeIntro="..tostring(beforeIntro))
        end
        return true
    end
    local stateRemote=f:FindFirstChild("PuzzleState")
    if stateRemote and stateRemote:IsA("RemoteEvent") then
        hook(stateRemote.OnClientEvent,function(snapshot)
            if type(snapshot)~="table" then return end
            state=snapshot
            for i=1,3 do check(i,"PuzzleState event") end
        end)
        pcall(function()stateRemote:FireServer()end)
    end
    local function move(i,settle,offset)
        if not safe() then return false end
        local model=folder:FindFirstChild("Lever"..i)
        if not model then emit("LEVER","Lever"..i.." missing");return false end
        local pivot=model:GetPivot().Position
        local zOffset=offset or 3
        local target=Vector3.new(pivot.X,floorY,pivot.Z+zOffset)
        if root.Anchored then
            if p:GetAttribute("CutsceneActive")~=true then
                emit("LEVER","Lever"..i.." anchored outside intro, move cancelled")
                return false
            end
            hadTemporaryUnanchor=true
            root.Anchored=false
        end
        root.CFrame=CFrame.new(target)*root.CFrame.Rotation
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        task.wait(settle)
        local deviation=(root.Position-target).Magnitude
        local leverDistance=(root.Position-pivot).Magnitude
        emit("LEVER",string.format("Lever%d target settle=%.2fs offset=%.1f posError=%.2f leverDistance=%.2f anchored=%s introDone=%s",
            i,settle,zOffset,deviation,leverDistance,tostring(root.Anchored),
            tostring(p:GetAttribute("IntroCutsceneFinished")==true)))
        -- A >10-stud snapback means the server or cinematic repositioned
        -- the character. Don't send a stale remote from that location.
        return safe() and deviation<=10
    end
    local function send(i,phase)
        if not safe() then return false end
        while safe() and os.clock()-lastRequest<0.12 do task.wait(0.01) end
        if not safe() then return false end
        local v=leverResults[i]
        v.attempts+=1
        emit("LEVER","Lever"..i.." REQUEST #"..v.attempts.." "..phase..
            " beforeIntro="..tostring(p:GetAttribute("IntroCutsceneFinished")~=true))
        local success,errorMessage=pcall(function()
            action:FireServer("LeverPuzzle","Lever"..i)
        end)
        lastRequest=os.clock()
        if not success then emit("ERROR","Lever"..i.." request failed: "..tostring(errorMessage))end
        return success
    end
    local function ack(i,timeout)
        local deadline=os.clock()+timeout
        while safe() and os.clock()<deadline do
            if check(i,"server acknowledgement") then return true end
            task.wait(0.01)
        end
        return check(i,"late acknowledgement")
    end

    emit("LEVER","START early probes. Intro not required, native actions only.")
    -- Probe each lever independently; don't abandon the others just because
    -- lever 1's remote is ignored during the intro.
    for i=1,3 do
        if not safe() or p:GetAttribute("IntroCutsceneFinished")==true then break end
        if not check(i,"already-pulled") and move(i,0.10) then
            send(i,"early-blackout")
            ack(i,0.28)
        end
    end
    local early=0
    for i=1,3 do if check(i,"end early phase") then early+=1 end end
    emit("LEVER","INITIAL EARLY PHASE: "..early.."/3 confirmed before Skip")
    -- Recover early while the intro is still playing, rather than sitting
    -- idle until Skip. Try each missing lever at most twice before Skip;
    -- for Lever2 use slightly different offsets to test local collision.
    local earlyOffsets={3.0,2.0}
    for retry=1,2 do
        if not safe() or skipSeen or p:GetAttribute("IntroCutsceneFinished")==true then break end
        for i=1,3 do
            if not safe() or skipSeen
                or p:GetAttribute("IntroCutsceneFinished")==true then break end
            if not check(i,"early retry check") then
                local offset=(i==2) and earlyOffsets[retry] or 3.0
                emit("LEVER","PRE-SKIP RETRY "..retry.." Lever"..i.." offset="..offset)
                if move(i,retry==1 and 0.17 or 0.22,offset)
                    and not skipSeen
                    and p:GetAttribute("IntroCutsceneFinished")~=true then
                    send(i,"pre-skip-retry-"..retry)
                    ack(i,retry==1 and 0.32 or 0.40)
                end
            end
        end
    end
    early=0
    for i=1,3 do if check(i,"final pre-Skip check") then early+=1 end end
    emit("LEVER","EARLY PHASE TOTAL: "..early.."/3 server-confirmed before Skip")
    if safe() and p:GetAttribute("IntroCutsceneFinished")~=true then
        local deadline=os.clock()+16
        while safe() and p:GetAttribute("IntroCutsceneFinished")~=true
            and os.clock()<deadline do task.wait(0.05) end
    end
    if safe() and p:GetAttribute("IntroCutsceneFinished")==true then
        emit("LEVER","POST-SKIP bounded Main-like recovery for any missing levers")
        for i=1,3 do
            if not safe() then break end
            if not check(i,"pre-retry") then
                for attempt=1,5 do
                    if not safe() or check(i,"retry-precheck") then break end
                    if move(i,attempt<=3 and 0.10 or 0.22) then
                        send(i,attempt<=3 and "main-retry" or "main-recovery")
                        if ack(i,attempt==1 and 0.28 or
                            attempt<=3 and 0.35 or
                            attempt==4 and 0.75 or 0.90) then break end
                    end
                    task.wait(attempt<=3 and 0.08 or 0.15)
                end
            end
        end
    else
        emit("LEVER","Post-intro fallback skipped: intro still active/character changed")
    end
    local confirmed=0
    for i=1,3 do if check(i,"final check") then confirmed+=1 end end
    -- Main restores temporary cutscene anchor if it unanchored explicitly.
    if hadTemporaryUnanchor and safe() and
        p:GetAttribute("CutsceneActive")==true then
        root.Anchored=true
        emit("LEVER","Restored temporary cutscene anchor")
    end
    if confirmed==0 and safe() and p:GetAttribute("IntroCutsceneFinished")==true
        and p:GetAttribute("CutsceneActive")~=true then
        root.CFrame=originalPosition
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        emit("LEVER","No server confirmations; restored pre-test spawn position")
    end
    leverFinished=true
    emit("LEVER","DONE: "..confirmed.."/3 server-confirmed levers")
end

local function clamp(x,min,max)return math.max(min,math.min(max,x))end
local function enableCamera(root)
    if cameraActive or cameraReleased then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local front=root.CFrame.LookVector
    local flat=Vector3.new(front.X,0,front.Z)
    if flat.Magnitude<0.1 then flat=Vector3.new(0,0,-1) end
    yaw=math.atan2(flat.X,flat.Z)
    pitch=-0.18
    followDistance=4
    cameraActive=true
    first("cameraStarted","mouse-driven 4-stud view; until Skip appears")
end
local function driveCamera()
    if not alive or not cameraActive or cameraReleased or not player then return end
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not root or not cam or not yaw then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    pcall(function()
        UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter
    end)
    local ok,delta=pcall(function()return UserInputService:GetMouseDelta()end)
    if ok and delta and not UserInputService:GetFocusedTextBox() then
        if math.abs(delta.X)>0.1 or math.abs(delta.Y)>0.1 then
            if seconds()-lastCameraDeltaAt>2 then
                emit("MOUSE","delta="..tostring(delta))
                lastCameraDeltaAt=seconds()
            end
            yaw-=delta.X*0.004
            pitch=clamp(pitch-delta.Y*0.004,-1,0.85)
        end
    end
    local cp=math.cos(pitch)
    local dir=Vector3.new(math.sin(yaw)*cp,math.sin(pitch),math.cos(yaw)*cp)
    local target=root.Position+Vector3.new(0,1.6,0)
    local desired=target-dir*followDistance
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char}
    params.RespectCanCollide=true
    local hit=Workspace:Raycast(target,desired-target,params)
    if hit then
        desired=target-dir*math.max(0.45,(hit.Position-target).Magnitude-0.3)
    end
    cam.CameraType=Enum.CameraType.Scriptable
    if hum then cam.CameraSubject=hum end
    cam.CFrame=CFrame.lookAt(desired,target,Vector3.yAxis)
    cam.Focus=CFrame.new(target)
    if previousCameraLook and cam.CFrame.LookVector:Dot(previousCameraLook)<0.999 then
        first("cameraMoved","mouse/rotation changed view")
    end
    previousCameraLook=cam.CFrame.LookVector
end

hook(UserInputService.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F6 then
        first("userCameraWorksF6","user confirms view rotation")
    elseif input.KeyCode==Enum.KeyCode.F7 then
        first("userCameraLockedF7","user reports camera locked")
    elseif input.KeyCode==Enum.KeyCode.F8 then
        save(true)
    end
end)
if game:IsLoaded() then first("loaded","already loaded")
else hook(game.Loaded,function()first("loaded","game.Loaded fired")end) end
pcall(function()RunService:UnbindFromRenderStep(renderName)end)
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+2100,driveCamera)
emit("BOOT","Combined experiment started. F6=camera works, F7=locked, F8=copy.")

task.spawn(function()
    while alive and seconds()<timeout do
        local ok,err=pcall(function()
            if not player then
                player=Players.LocalPlayer
                if player then
                    first("player","LocalPlayer available")
                    for _,key in ipairs({"CutsceneActive","IntroCutsceneFinished"}) do
                        hook(player:GetAttributeChangedSignal(key),function()
                            changed(key,player:GetAttribute(key))
                        end)
                    end
                end
            end
            if not player then return end
            local char=player.Character
            if char then first("character","spawned") end
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local workspacePuzzles=Workspace:FindFirstChild("Puzzles")
            local leverPuzzle=workspacePuzzles and workspacePuzzles:FindFirstChild("LeverPuzzle")
            local leverFolder=leverPuzzle and leverPuzzle:FindFirstChild("Levers")
            if leverFolder then first("leversReady","#"..tostring(#leverFolder:GetChildren())) end
            local done=player:GetAttribute("IntroCutsceneFinished")==true
            local cutscene=player:GetAttribute("CutsceneActive")==true
            if cutscene then first("cutsceneActive","true") end
            if done and not introCompletedAt then
                introCompletedAt=seconds()
                first("introFinished","flag true")
                releaseCamera("intro finished")
            elseif firstTimes.cutsceneActive and not cutscene then
                first("cutsceneCleared","CutsceneActive cleared")
            end
            local _,fade,black,skip=guiObjects()
            if black and black:IsA("GuiObject") then
                if black~=overlay then
                    overlay=black
                    overlayOriginalVisible=black.Visible
                    first("overlayFound","CutsceneFade.Black initially "..tostring(overlayOriginalVisible))
                end
                if not done and not overlayRestored and black.Visible then
                    local success,hideError=pcall(function()black.Visible=false end)
                    if success then first("overlayHidden","blackout removed")
                    else changed("OverlayHideError",hideError) end
                end
                if firstTimes.overlayHidden and not leverStarted and
                    cutscene and root and leverFolder then
                    leverStarted=true
                    first("leverStarted","native lever controller immediately after blackout removal")
                    task.spawn(function()
                        local success,errorMessage=pcall(runEarlyLevers)
                        if not success then
                            leverFinished=true
                            emit("ERROR","Lever test failed: "..tostring(errorMessage))
                        end
                    end)
                end
            end
            local visibleSkip=skip and isVisible(skip) or false
            if visibleSkip and not skipSeen then
                skipSeen=true
                first("skipVisible","native intro Skip GUI ready")
                releaseCamera("native Skip appeared; unlock cursor")
            end
            if not done and not visibleSkip and not cameraReleased and cutscene and root then
                enableCamera(root)
            end
            if not done and visibleSkip and not clickRunning and attempts<2
                and safeToSkip(skip)
                and (attempts==0 or seconds()-lastAttemptAt>=1.0) then
                clickRunning=true
                attempts+=1
                lastAttemptAt=seconds()
                first("firstClick","native Skip mouse click attempted")
                local n=attempts
                task.spawn(function()
                    local success,clickError=pcall(clickSkip,skip,n)
                    if not success then emit("ERROR","Click crash: "..tostring(clickError))end
                    clickRunning=false
                end)
            end
            if introCompletedAt and not overlayRestored
                and seconds()-introCompletedAt>=0.65 then
                restoreOverlay("intro complete + 0.65s")
            end
        end)
        if not ok then changed("WatchError",err) end
        if alive and introCompletedAt and overlayRestored
            and seconds()-introCompletedAt>=2.0
            and (not leverStarted or leverFinished) then
            stop("intro finished; lever results captured")
            return
        end
        if alive and seconds()>15 and lastSaveAt<15 then save(false) end
        if alive and seconds()>25 and lastSaveAt<25 then save(false) end
        task.wait(seconds()<19 and 0.035 or 0.12)
    end
    if alive then stop("42s test ended; lever/intro results collected") end
end)
