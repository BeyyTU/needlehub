-- Beyy Chapter 2 Early Full Puzzles Test v3
-- Standalone experimental combination:
-- (1) Hide the visible CutsceneFade.Black overlay,
-- (2) allow mouse-driven camera before the first native Skip button,
-- (3) release camera and click that normal Skip button instantly.
-- No puzzle remotes, forced attributes, character teleports, or Main edits.
-- Start from lobby; this copy is queued verbatim for the Chapter 2 teleport.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-early-full-puzzles-test.lua"
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
        and body:find("Beyy Chapter 2 Early Full Puzzles Test v3",1,true)
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
local timeout=95
local player=nil
local alive=true
local connections={}
local eventLines={}
local firstTimes={}
local attrs={}
local outputPath="BeyyHub/chapter2_early_full_puzzles_result.txt"
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
local puzzleStarted=false
local puzzleFinished=false
local puzzlePassed=false
local puzzleErr=nil
local puzzleDetails={}
local tryStartPuzzles=nil
local doorBypassActive=false
local doorBypassSeen=false
local doorBypassFinished=false
local doorBypassStartedAt=-math.huge
local doorBypassCamera=false
local doorCameraReleasedAt=nil

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
        "CHAPTER 2 EARLY FULL PUZZLES TEST v3",
        "Times relative to the test executing in Chapter 2.",
        "Actions: blackout GUI/camera, native intro Skip, early native lever and Picture/Color/Number puzzle actions.",
        "Skip attempts: "..tostring(attempts),
        "Lever test started: "..tostring(leverStarted)..", finished: "..tostring(leverFinished),
        "Puzzle started: "..tostring(puzzleStarted)..", finished: "..tostring(puzzleFinished),
        "Puzzle success: "..tostring(puzzlePassed).." error="..tostring(puzzleErr),
        "Door bypass observed: "..tostring(doorBypassSeen).." finished: "..tostring(doorBypassFinished),
        "Door bypass restores local camera only; server cinematic time is not shortened.",
        "Native intro Skip can be used even after Picture/Color/Number puzzles progress.",
        "Stopped: "..tostring(stopReason or "in progress"),
        "=== MILESTONES ==="
    }
    for _,name in ipairs({"player","loaded","character","leversReady","cutsceneActive",
        "overlayFound","overlayHidden","leverStarted","threeLeversConfirmed","puzzlesStarted","puzzlesFinished","cameraStarted","cameraMoved","skipVisible",
        "cameraReleased","firstClick","cutsceneCleared","introFinished","doorBypassStarted","doorBypassFinished",
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
    result[#result+1]="=== PUZZLE STATUS ==="
    for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do
        result[#result+1]=name.."="..tostring(puzzleDetails[name] or "not confirmed")
    end
    result[#result+1]="Native requests="..tostring(puzzleDetails.requests or 0)
    result[#result+1]="Color position recoveries="..tostring(puzzleDetails.colorRootRecoveries or 0)
    result[#result+1]="Final player position="..tostring(puzzleDetails.positionAtEnd or "N/A")
    result[#result+1]="Puzzle seconds="..tostring(puzzleDetails.seconds or "N/A")
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
    -- Puzzles now start BEFORE native intro Skip. SolvedPuzzleCount can
    -- be 1-3 before IntroCutsceneFinished=true: do NOT suppress Skip.
    -- Restrict targeting to the actual intro Skip button and continue
    -- protecting the final ending and other unrelated UI.
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local holder=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    if not (fade and holder and button:IsDescendantOf(holder)
        and button:IsDescendantOf(fade)) then return false end
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
        if not puzzleStarted and type(tryStartPuzzles)=="function" then
            local all=true
            for j=1,3 do if not pulled(j) then all=false;break end end
            if all then
                first("threeLeversConfirmed","native state confirms all levers pulled")
                tryStartPuzzles()
            end
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


-- Original Main Chapter2 concurrent puzzle routine, without re-running levers.
-- This is a separate experiment; concurrentPuzzles block copied byte-for-byte.
tryStartPuzzles=function()
    if puzzleStarted or not alive then return end
    puzzleStarted=true
    first("puzzlesStarted","3 levers confirmed; starting Picture/Color/Number worker")
    task.spawn(function()
        local P=player
        local C=P and P.Character
        local root=C and C:FindFirstChild("HumanoidRootPart")
        local W=Workspace:FindFirstChild("Puzzles")
        local F=ReplicatedStorage:FindFirstChild("Puzzles")
        local start=os.clock()
        local floorY=root and root.Position.Y or 0
        local T={requests={},observations={},stages={},state={},connections={}}
        local codeFound=nil
        local feedback={}
        local temporaryUnanchor=false
        local function elapsed() return os.clock()-start end
        local function guard()
            assert(alive and P and root and root.Parent and P.Character==C,
                "character changed / test stopped")
            assert(P:GetAttribute("NeedleRoundComplete")~=true
                and P:GetAttribute("NeedleOwned")~=true,
                "Final ending protected")
        end
        local function valid(code)
            return type(code)=="string" and #code==4 and code:match("^%d+$")~=nil
        end
        local function observe(name,data)
            T.observations[#T.observations+1]={name=name,time=elapsed()}
            if name=="concurrent_missing" then
                emit("PUZZLE","Unconfirmed action: "..tostring(data.puzzle).."/"..tostring(data.step))
            end
        end
        local function waitFor(fn,timeout)
            local deadline=os.clock()+timeout
            repeat
                guard()
                if fn() then return true end
                task.wait(0.02)
            until os.clock()>=deadline
            return fn()
        end
        local function go(target,settle)
            guard()
            if root.Anchored then
                assert(P:GetAttribute("CutsceneActive")==true
                    or P:GetAttribute("Chapter2ReleaseActive")==true,
                    "Anchored outside non-final cinematic")
                temporaryUnanchor=true
                root.Anchored=false
            end
            root.CFrame=CFrame.new(target)*root.CFrame.Rotation
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
            task.wait(settle or 0.28)
            observe("movement",{position=target,
                error=(root.Position-target).Magnitude})
        end
local function concurrentPuzzles()
             local began=os.clock()
             local boardModel,board,rotationFolder,gemModel,numberModel,posters,keypad
             local function targetsReady()
              W=workspace:FindFirstChild("Puzzles") or W
              local picture=W and W:FindFirstChild("PicturePuzzle")
              boardModel=picture and picture:FindFirstChild("PicturePuzzle")
              board=boardModel and boardModel:FindFirstChild("BoardPart")
              rotationFolder=boardModel and boardModel:FindFirstChild("State")
              gemModel=W and W:FindFirstChild("ColorPuzzle")
              numberModel=W and W:FindFirstChild("NumberPuzzle")
              posters=numberModel and numberModel:FindFirstChild("Posters")
              keypad=numberModel and numberModel:FindFirstChild("Keypad")
              if not (board and rotationFolder and gemModel and posters and keypad) then return false end
              local pedestals=gemModel:FindFirstChild("Folder")
              if not pedestals then return false end
              for i=1,3 do if not pedestals:FindFirstChild("Pedestal"..i) then return false end end
              for _,name in ipairs({"Red","Purple","Green"}) do
               if not gemModel:FindFirstChild(name.."Gems") then return false end
              end
              return true
             end
             local targetDeadline=os.clock()+4
             while not targetsReady() and os.clock()<targetDeadline do guard() task.wait(0.05) end
             assert(targetsReady(),"Puzzle-room targets did not replicate after Lever 3")
             print("[AutoPuzzles] Lever 3 confirmed; puzzle-room targets ready")
             local S={started=elapsed(),mode="probe",pendingMissing=0,acknowledgements=0,initialRotations={},gemTargets={},postersSent=0,postersAcknowledged=0,numberMoves=0}
             T.stages.concurrent=S
             local pic={} local colors={} local papers={}
             for i=1,16 do
              local ref=rotationFolder:FindFirstChild("Rotation"..i)
              assert(ref,"Missing Rotation"..i)
              S.initialRotations[i]=ref.Value
              table.insert(pic,{puzzle="PicturePuzzle",step="Tile"..i,ref=ref,attempts=0})
             end
             for i,name in ipairs({"Red","Purple","Green"}) do
              local count=0 for _,g in ipairs(gemModel[name.."Gems"]:GetChildren()) do if g:GetAttribute("ColorPuzzleVisible")==true then count=count+1 end end
              assert(count>=1 and count<=5,"Invalid gem count")
              S.gemTargets[name]=count
              table.insert(colors,{puzzle="ColorPuzzle",step=name,target=count,model=gemModel.Folder["Pedestal"..i],attempts=0})
             end
             for _,p in ipairs(posters:GetChildren()) do
              local index=p:GetAttribute("PosterIndex")
              if p:IsA("BasePart") and type(index)=="number" then table.insert(papers,{puzzle="NumberPuzzle",step="Poster",index=index,part=p,attempts=0}) end
             end
             S.initialPosters=#papers
             local function distance(a,b) return (a-b).Magnitude end
             local best=nil local bestCount=-1 local bestMargin=-math.huge
             local keypadPosition=keypad:GetPivot().Position
             local gemPositions={}
             for i,c in ipairs(colors) do gemPositions[i]=c.model:GetPivot().Position end
             local mean=(keypadPosition+gemPositions[2])*0.5
             for dx=-7,7,0.25 do for dz=-7,7,0.25 do
              local p=Vector3.new(mean.X+dx,floorY,mean.Z+dz)
              local dk=distance(p,keypadPosition)
              local db=distance(p,board.Position)
              local maxGem=0 for _,gemPosition in ipairs(gemPositions) do maxGem=math.max(maxGem,distance(p,gemPosition)) end
              if dk<=9.2 and db<=28 and maxGem<=13.3 then
               local count=0 for _,paper in ipairs(papers) do if distance(p,paper.part.Position)<9 then count=count+1 end end
               local margin=math.min(10-dk,14-maxGem,30-db)
               if count>bestCount or count==bestCount and margin>bestMargin then best=p bestCount=count bestMargin=margin end
              end
             end end
             assert(best,"No verified puzzle-room position; unsafe midpoint fallback disabled")
             if bestCount==0 then
              print("[AutoPuzzles] No nearby untouched posters; keeping verified puzzle-room position")
             end
             local roomAnchor=best
             local roomKeypadPosition=keypad:GetPivot().Position
             local nextNumberMoveAt=0
             local lastUnsafePosterNotice=-math.huge
             S.anchor=tostring(best) S.initialPostersInRange=bestCount
             print("[AutoPuzzles] Teleporting into puzzle room at "..tostring(best))
             local finalMoveError=math.huge
             for attempt=1,4 do
              guard()
              assert(not finalEndingProtected and P:GetAttribute("NeedleRoundComplete")~=true,"Final ending is protected")
              if root.Anchored then
               if temporaryUnanchor==nil then temporaryUnanchor=true end
               root.Anchored=false
              end
              root.CFrame=CFrame.new(best)*root.CFrame.Rotation
              root.AssemblyLinearVelocity=Vector3.zero
              root.AssemblyAngularVelocity=Vector3.zero
              task.wait(attempt==1 and 0.10 or 0.18)
              finalMoveError=(root.Position-best).Magnitude
              if finalMoveError<=4 then break end
              print(("[AutoPuzzles] Puzzle-room movement retry %d; error=%.2f studs anchored=%s"):format(
               attempt,finalMoveError,tostring(root.Anchored)))
             end
             assert(finalMoveError<=4,("Puzzle-room teleport did not hold (%.2f studs)"):format(finalMoveError))
             print(("[AutoPuzzles] Puzzle-room teleport confirmed; error=%.2f studs"):format(finalMoveError))
             local function taken(item)
              local n=T.state.NumberPuzzle local a=n and n.taken
              return feedback[item.index]~=nil or a and (a[item.index]==true or a[tostring(item.index)]==true)
             end
             local function value(item)
              if item.ref then return item.ref.Value end
              local s=T.state.ColorPuzzle
              return s and s.values and s.values[item.step]
             end
             local function solved(name) return T.state[name] and T.state[name].completed==true end
             local function needed(item)
              if item.index then return item.part.Parent~=nil and not taken(item) and not valid(codeFound) end
              if solved(item.puzzle) then return false end
              local v=value(item)
              if item.ref then return v%4~=0 end
              return v~=item.target
             end
             local nextBy={PicturePuzzle=0,ColorPuzzle=0,NumberPuzzle=0}
             local intervals={PicturePuzzle=0.14,ColorPuzzle=0.14,NumberPuzzle=0.20}
             local nextAny=0
             local pending={} local totalSent=0
             local lastStateRefreshAt=-math.huge
             local recoveryUntil=0
             local lastRecoveryLogAt=-math.huge
             local lastColorTargetScan=-math.huge
             local lastColorTrace=-math.huge
             local lastColorRootRecovery=-math.huge
             local colorRootRecoveries=0
             local colorNoProgress=0
             local lastColorValue=nil
             S.stateRefreshes=0 S.recoveryBackoffs=0 S.lateChecks=0
             -- When the intro/door cinematic snaps the character back to
             -- spawn, ColorPuzzle's server range check can reject every
             -- Red/Purple/Green request. Main's dispatch lacks the distance
             -- guard it already uses for Picture and Number.
             -- In this standalone test only, recover a safe point within
             -- 7.5 studs of the relevant pedestal before sending Color.
             local function recoverColorPosition(item)
              local pedestal=item.model and item.model:GetPivot().Position
              if not pedestal then return false end
              local dist=(root.Position-pedestal).Magnitude
              local fromAnchor=(roomAnchor-pedestal)
              local flat=Vector3.new(fromAnchor.X,0,fromAnchor.Z)
              local direction=flat.Magnitude>0.1 and flat.Unit or Vector3.new(0,0,1)
              if dist>8.0 then
               local candidate=Vector3.new(pedestal.X,floorY,pedestal.Z)+direction*3.0
               local candidateDistance=(candidate-pedestal).Magnitude
               if candidateDistance>8.0 or (candidate-roomAnchor).Magnitude>19.0 then
                emit("PUZZLE","Color "..item.step.." distance recovery rejected: unsafe point")
                return false
               end
               if os.clock()-lastColorRootRecovery>0.12 then
                lastColorRootRecovery=os.clock()
                colorRootRecoveries+=1
                emit("PUZZLE",string.format("Color %s out of range: %.2f studs; near-pedestal move #%d; CutsceneActive=%s introFinished=%s",
                 item.step,dist,colorRootRecoveries,tostring(P:GetAttribute("CutsceneActive")),
                 tostring(P:GetAttribute("IntroCutsceneFinished"))))
               end
               go(candidate,0.12)
               dist=(root.Position-pedestal).Magnitude
              end
              if os.clock()-lastColorTrace>1.75 then
               lastColorTrace=os.clock()
               local state=T.state.ColorPuzzle
               local current=state and state.values and state.values[item.step]
               emit("PUZZLE",string.format("COLOR TRACE %s distance=%.2f target=%s serverValue=%s roomDrift=%.2f anchored=%s cutscene=%s introDone=%s",
                item.step,dist,tostring(item.target),tostring(current),
                (root.Position-roomAnchor).Magnitude,tostring(root.Anchored),
                tostring(P:GetAttribute("CutsceneActive")),tostring(P:GetAttribute("IntroCutsceneFinished"))))
              end
              return dist<=9.0
             end
             local function refreshColorTargets()
              if os.clock()-lastColorTargetScan<0.8 then return end
              lastColorTargetScan=os.clock()
              for _,item in ipairs(colors) do
               local gems=gemModel:FindFirstChild(item.step.."Gems")
               if gems then
                local count=0
                for _,g in ipairs(gems:GetChildren()) do
                 if g:GetAttribute("ColorPuzzleVisible")==true then count+=1 end
                end
                if count>=1 and count<=5 and count~=item.target then
                 emit("PUZZLE","Color target updated "..item.step.." "..item.target.." -> "..count)
                 item.target=count
                end
               end
              end
             end
             local function dispatch(item)
              guard()
              if item.puzzle=="ColorPuzzle" then
               if not recoverColorPosition(item) then
                item.retryAfter=os.clock()+0.25
                return nil
               end
              end
              local d={t=elapsed(),puzzle=item.puzzle,step=item.step,arg=item.index or item.arg,interval=intervals[item.puzzle],mode=S.mode,position=tostring(root.Position)}
              local before=not item.index and not item.submit and value(item) or nil
              if item.index or item.arg then F.PuzzleAction:FireServer(item.puzzle,item.step,item.index or item.arg) else F.PuzzleAction:FireServer(item.puzzle,item.step) end
              table.insert(T.requests,d)
              local request={item=item,before=before,at=os.clock(),request=d}
              table.insert(pending,request)
              item.pending=request item.lastDispatch=os.clock() item.attempts=(item.attempts or 0)+1
              nextBy[item.puzzle]=os.clock()+intervals[item.puzzle]
              nextAny=os.clock()+0.14
              if item.index then S.postersSent=S.postersSent+1 end
              totalSent=totalSent+1 assert(totalSent<150,"Bounded request limit")
              return request
             end
             local function acknowledged(request)
              if solved(request.item.puzzle) then return true end
              if request.item.submit then return solved("NumberPuzzle") end
              if request.item.index then return taken(request.item) end
              return value(request.item)~=request.before
             end
             local function poll()
              local paperPending=0
              for i=#pending,1,-1 do
               local request=pending[i]
               if acknowledged(request) then
                S.acknowledgements=S.acknowledgements+1
                request.confirmed=true
                observe("concurrent_ack",{puzzle=request.item.puzzle,step=request.item.step,index=request.item.index,seconds=os.clock()-request.at})
                if request.item.index then S.postersAcknowledged=S.postersAcknowledged+1 end
                request.item.pending=nil table.remove(pending,i)
               elseif os.clock()-request.at>0.70 then
                local now=os.clock()
                if not request.lateCheck then
                 request.lateCheck=true
                 S.lateChecks=S.lateChecks+1
                 if now-lastStateRefreshAt>=1 then
                  lastStateRefreshAt=now
                  if pcall(function() F.PuzzleState:FireServer() end) then
                   S.stateRefreshes=S.stateRefreshes+1
                  end
                 end
                 if request.item.index then paperPending=paperPending+1 end
                elseif now-request.at>1.20 then
                 S.pendingMissing=S.pendingMissing+1 request.missing=true
                 observe("concurrent_missing",{puzzle=request.item.puzzle,step=request.item.step,index=request.item.index})
                 request.item.pending=nil request.item.retryAfter=now+0.12
                 recoveryUntil=math.max(recoveryUntil,now+3)
                 S.recoveryBackoffs=S.recoveryBackoffs+1
                 if now-lastRecoveryLogAt>=6 then
                  lastRecoveryLogAt=now
                  print("[AutoPuzzles] Puzzle confirmations delayed; temporarily spacing requests")
                 end
                 if not request.expectedProbeFailure then
                  if request.item.puzzle=="PicturePuzzle" and intervals.PicturePuzzle<0.14 then intervals.PicturePuzzle=0.14 S.pictureBurstBackedOff=true
                  else intervals[request.item.puzzle]=math.min(0.24,intervals[request.item.puzzle]+0.02) end
                 end
                 table.remove(pending,i)
                elseif request.item.index then paperPending=paperPending+1 end
               elseif request.item.index then paperPending=paperPending+1 end
              end
              return paperPending
             end
             S.mode="independent-per-puzzle-queues"
             S.pictureSameTileMinimum=0.32
             S.confirmedProfile={picture=0.14,color=0.14,posters=0.20,posterPendingLimit=2}
             S.exploratoryProbesDisabled=true
             print("[AutoPuzzles] Confirmed request cadence with shorter movement waits; server acknowledgements required")
             local cursorPic=0 local cursorColor=0 local typeCursor=0
             local submit={puzzle="NumberPuzzle",step="Submit",submit=true,attempts=0}
             local function nextPic()
              for offset=1,#pic do local i=((cursorPic+offset-1)%#pic)+1 local item=pic[i]
               if needed(item) and not item.pending and (not item.retryAfter or os.clock()>=item.retryAfter) and (not item.lastDispatch or os.clock()-item.lastDispatch>=0.32) then cursorPic=i return item end
              end
             end
             local function nextColor()
              for offset=1,#colors do local i=((cursorColor+offset-1)%#colors)+1 local item=colors[i]
               if needed(item) and not item.pending and (not item.retryAfter or os.clock()>=item.retryAfter) then cursorColor=i return item end
              end
             end
             local function nearPaper()
              local bestPaper=nil local closest=math.huge
              for _,item in ipairs(papers) do
               if item.part.Parent and needed(item) and not item.pending and item.attempts<2 and (not item.retryAfter or os.clock()>=item.retryAfter) then
                local d=distance(root.Position,item.part.Position)
                if d<9 and d<closest then bestPaper=item closest=d end
               end
              end
              return bestPaper
             end
             local deadline=os.clock()+45
             while not (solved("PicturePuzzle") and solved("ColorPuzzle") and solved("NumberPuzzle")) and os.clock()<deadline do
              guard()
              local paperPending=poll()
              refreshColorTargets()
              for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do
               if solved(name) and not S[name.."ConfirmedAt"] then S[name.."ConfirmedAt"]=elapsed() end
              end
              if solved("ColorPuzzle") and paperPending==0 then
               if not valid(codeFound) and not nearPaper() and os.clock()>=nextNumberMoveAt then
                nextNumberMoveAt=os.clock()+0.55
                local point=nil local most=-1 local closest=math.huge
                for _,item in ipairs(papers) do if item.part.Parent and needed(item) and item.attempts<2 then
                 local posterPosition=item.part.Position
                 local flatPoster=Vector3.new(posterPosition.X,roomAnchor.Y,posterPosition.Z)
                 local fromAnchor=flatPoster-roomAnchor
                 local away=fromAnchor.Magnitude
                 if away<=16 and math.abs(posterPosition.Y-roomAnchor.Y)<=7 then
                  local p=roomAnchor
                  if away>0.01 then
                   p=roomAnchor+fromAnchor.Unit*math.min(7.5,math.max(0,away-7.5))
                  end
                  if distance(p,posterPosition)<9 and distance(p,roomAnchor)<=7.5
                   and distance(p,roomKeypadPosition)<=16 and distance(p,board.Position)<29 then
                   local count=0
                   for _,candidate in ipairs(papers) do
                    if candidate.part.Parent and needed(candidate) and candidate.attempts<2
                     and distance(candidate.part.Position,p)<8.8 then count=count+1 end
                   end
                   local d=distance(root.Position,p)
                   if count>most or (count==most and d<closest) then point=p most=count closest=d end
                  end
                 end
                end end
                if point then
                 if distance(root.Position,point)>1.75 then
                  print("[AutoPuzzles] Number poster reposition inside puzzle room: "..tostring(point))
                  go(point,0.10) S.numberMoves=S.numberMoves+1
                 end
                elseif os.clock()-lastUnsafePosterNotice>=5 then
                 lastUnsafePosterNotice=os.clock()
                 print("[AutoPuzzles] Skipping posters outside puzzle-room safe range; no remote cage teleport")
                end
               elseif valid(codeFound) and not solved("NumberPuzzle") and not submit.pending
                and distance(root.Position,roomKeypadPosition)>8.5 and os.clock()>=nextNumberMoveAt then
                nextNumberMoveAt=os.clock()+0.55
                local towards=roomAnchor-roomKeypadPosition
                local flat=Vector3.new(towards.X,0,towards.Z)
                local keypadPoint=roomAnchor
                if flat.Magnitude>0.01 then
                 keypadPoint=Vector3.new(roomKeypadPosition.X,roomAnchor.Y,roomKeypadPosition.Z)
                  +flat.Unit*math.min(7.5,flat.Magnitude)
                end
                if distance(keypadPoint,roomAnchor)<=7.5 and distance(keypadPoint,board.Position)<29 then
                 print("[AutoPuzzles] Adjusting within verified keypad range")
                 go(keypadPoint,0.10)
                 S.numberMoves=S.numberMoves+1
                end
               end
              end
              for offset=1,3 do
               local index=((typeCursor+offset-1)%3)+1
               local name=({"PicturePuzzle","ColorPuzzle","NumberPuzzle"})[index]
               if os.clock()>=nextBy[name] and
                (os.clock()>=recoveryUntil or (os.clock()>=nextAny and #pending<5)) then
                local item=nil
                if name=="PicturePuzzle" and distance(root.Position,board.Position)<29 then item=nextPic()
                elseif name=="ColorPuzzle" then item=nextColor()
                elseif name=="NumberPuzzle" and not solved("NumberPuzzle") then
                 if valid(codeFound) and not submit.pending and submit.attempts<2 and distance(root.Position,keypad:GetPivot().Position)<9.3 then
                  submit.arg=codeFound item=submit
                 elseif not valid(codeFound) and paperPending<2 then item=nearPaper() end
                end
                if item then dispatch(item) typeCursor=index end
               end
              end
              task.wait(0.005)
             end
             poll()
             S.seconds=os.clock()-began S.ended=elapsed()
             S.picturePassed=solved("PicturePuzzle") S.colorPassed=solved("ColorPuzzle") S.numberPassed=solved("NumberPuzzle")
             S.actualCode=codeFound S.finalIntervals=intervals S.colorRootRecoveries=colorRootRecoveries
             emit("PUZZLE","END STATE picture="..tostring(S.picturePassed)..
                " color="..tostring(S.colorPassed).." number="..tostring(S.numberPassed)..
                " ColorRootRecoveries="..tostring(colorRootRecoveries)..
                " playerPos="..tostring(root.Position)..
                " roomAnchor="..tostring(roomAnchor)..
                " IntroFinished="..tostring(P:GetAttribute("IntroCutsceneFinished")))
             for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do if solved(name) and not S[name.."ConfirmedAt"] then S[name.."ConfirmedAt"]=elapsed() end end
             assert(S.picturePassed and S.colorPassed and S.numberPassed,"Concurrent pass incomplete")
             print("[AutoPuzzles] All puzzles confirmed in "..string.format("%.3f",S.seconds).."s, missing="..S.pendingMissing)
            end
            
        local function run()
            guard()
            assert(F and W,"Native puzzle folders unavailable")
            local stateRemote=F:FindFirstChild("PuzzleState")
            assert(stateRemote and stateRemote:IsA("RemoteEvent"),"PuzzleState not found")
            local feedbackRemote=F:FindFirstChild("PuzzleFeedback")
            T.connections[#T.connections+1]=stateRemote.OnClientEvent:Connect(function(snapshot)
                if type(snapshot)~="table" then return end
                T.state=snapshot
                local n=T.state.NumberPuzzle
                if n and valid(n.code) then codeFound=n.code end
            end)
            if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
                T.connections[#T.connections+1]=feedbackRemote.OnClientEvent:Connect(
                    function(puzzle,step,index,correct,code)
                        if puzzle=="NumberPuzzle" and step=="Poster" then
                            feedback[tonumber(index)]={t=elapsed(),correct=correct,code=code}
                            if valid(code) then codeFound=code end
                        end
                    end)
            end
            emit("PUZZLE","Worker dispatched beforeIntro="..
                tostring(P:GetAttribute("IntroCutsceneFinished")~=true)..
                " cutscene="..tostring(P:GetAttribute("CutsceneActive")))
            F.PuzzleState:FireServer()
            if not waitFor(function()return type(T.state.NumberPuzzle)=="table"end,2.0) then
                emit("PUZZLE","No early PuzzleState: retry native state after intro")
                local deadline=os.clock()+12
                while P:GetAttribute("IntroCutsceneFinished")~=true
                    and os.clock()<deadline do guard();task.wait(0.05) end
                F.PuzzleState:FireServer()
                assert(waitFor(function()return type(T.state.NumberPuzzle)=="table"end,2.0),
                    "No native puzzle state")
            end
            local success,reason=pcall(concurrentPuzzles)
            if not success then
                emit("PUZZLE","First solver pass stopped: "..tostring(reason))
                if P:GetAttribute("IntroCutsceneFinished")~=true then
                    local deadline=os.clock()+12
                    while P:GetAttribute("IntroCutsceneFinished")~=true
                        and os.clock()<deadline do guard();task.wait(0.05) end
                    F.PuzzleState:FireServer()
                    task.wait(0.3)
                    emit("PUZZLE","Retrying original solver after Skip")
                    success,reason=pcall(concurrentPuzzles)
                end
            end
            assert(success,tostring(reason))
            assert(waitFor(function()
                return F:GetAttribute("LeverPuzzleSolved")==true and
                    (tonumber(F:GetAttribute("SolvedPuzzleCount")) or 0)>=3
            end,1.5),"Final replicated puzzle count incomplete")
        end
        local passed,why=xpcall(run,function(e)return tostring(e)end)
        for _,connection in ipairs(T.connections) do
            pcall(function()connection:Disconnect()end)
        end
        if temporaryUnanchor and root and root.Parent
            and P and P:GetAttribute("NeedleRoundComplete")~=true
            and P:GetAttribute("CutsceneActive")==true then
            root.Anchored=true
        end
        puzzlePassed=passed
        puzzleErr=not passed and why or nil
        puzzleDetails.requests=#T.requests
        puzzleDetails.seconds=string.format("%.3f",elapsed())
        puzzleDetails.colorRootRecoveries=T.stages.concurrent
            and T.stages.concurrent.colorRootRecoveries or 0
        puzzleDetails.positionAtEnd=root and tostring(root.Position) or "missing"
        for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do
            local state=T.state[name]
            puzzleDetails[name]=(state and state.completed==true)
                and "server-confirmed" or "not-confirmed"
        end
        puzzleFinished=true
        first("puzzlesFinished","passed="..tostring(passed))
        emit("PUZZLE","RESULT passed="..tostring(passed)..
            " requests="..tostring(puzzleDetails.requests)..
            " seconds="..puzzleDetails.seconds..
            " error="..tostring(puzzleErr))
    end)
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


-- Chapter 2 Main bypasses the unskippable door-opening cinematic locally:
-- it restores a usable camera and controls, but never changes server timers.
-- Reuse the same camera driver after native intro Skip, only for lever-door
-- phase. Final needle ending and the separate puzzle-release phase are excluded.
local function threeLeversConfirmed()
    local f=ReplicatedStorage:FindFirstChild("Puzzles")
    if f and f:GetAttribute("LeverPuzzleSolved")==true then return true end
    for i=1,3 do
        local info=leverResults[i]
        if not (info and info.ok) then return false end
    end
    return true
end
local function stopDoorBypass(reason)
    if not doorBypassActive then return end
    doorBypassActive=false
    doorBypassFinished=true
    doorCameraReleasedAt=seconds()
    releaseCamera(reason or "door-opening cinematic ended")
    first("doorBypassFinished",reason)
    emit("DOOR","Local camera bypass released; native camera restored")
end
local function updateDoorBypass(done,cutscene,root)
    local finishedOrProtected=not alive or
        player:GetAttribute("NeedleRoundComplete")==true or
        player:GetAttribute("NeedleOwned")==true or
        player:GetAttribute("Chapter2ReleaseActive")==true
    if doorBypassActive then
        if finishedOrProtected or not cutscene or
            seconds()-doorBypassStartedAt>8 then
            stopDoorBypass(finishedOrProtected and "final/release objective protected"
                or not cutscene and "CutsceneActive cleared"
                or "8-second local bypass bound")
        end
        return
    end
    if doorBypassSeen or finishedOrProtected or not done or
        not cutscene or not root or not threeLeversConfirmed() then return end
    doorBypassSeen=true
    doorBypassActive=true
    doorBypassStartedAt=seconds()
    cameraReleased=false
    enableCamera(root)
    doorBypassCamera=cameraActive
    first("doorBypassStarted","door cutscene detected; camera/mouse locally restored")
    emit("DOOR","CutsceneActive after intro Skip + 3/3 levers; camera bypass active, SERVER timer untouched")
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
                if not overlayRestored and black.Visible and
                    (not done or doorBypassActive
                        or (introCompletedAt and not doorBypassFinished
                            and seconds()-introCompletedAt<8)) then
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
            -- Door opening begins after the intro, even if the levers were
            -- completed during the blackout. Enable the local camera bypass
            -- only for that cinematic, and release when CutsceneActive clears.
            if introCompletedAt then
                updateDoorBypass(done,cutscene,root)
            end
            local visibleSkip=skip and isVisible(skip) or false
            if visibleSkip and not skipSeen then
                skipSeen=true
                first("skipVisible","native intro Skip GUI ready")
                local remotes=ReplicatedStorage:FindFirstChild("Puzzles")
                emit("SKIP","Native intro Skip visible, SolvedPuzzleCount="..
                    tostring(remotes and remotes:GetAttribute("SolvedPuzzleCount"))..
                    " introDone="..tostring(done))
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
            if introCompletedAt and not overlayRestored and
                (doorBypassFinished or
                    (not doorBypassSeen and seconds()-introCompletedAt>=8)) then
                restoreOverlay(doorBypassFinished and "door cinematic completed"
                    or "no door cinematic detected within 8s")
            end
        end)
        if not ok then changed("WatchError",err) end
        if alive and introCompletedAt and overlayRestored
            and seconds()-introCompletedAt>=2.0
            and (not leverStarted or leverFinished)
            and (not puzzleStarted or puzzleFinished)
            and not doorBypassActive then
            stop("intro finished; lever and puzzle results captured")
            return
        end
        if alive and seconds()>15 and lastSaveAt<15 then save(false) end
        if alive and seconds()>25 and lastSaveAt<25 then save(false) end
        if alive and seconds()>60 and lastSaveAt<60 then save(false) end
        task.wait(seconds()<19 and 0.035 or 0.12)
    end
    if alive then stop("95s test ended; puzzle results captured") end
end)
