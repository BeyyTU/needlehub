-- Beyy Chapter 2 No-Levers Puzzle Worker v26
-- Runs only Picture, Color and Number puzzle actions.
-- Camera, intro Skip, cutscenes and upgrades belong to their own modules.
local CHAPTER2=83445806734780
if game.PlaceId~=CHAPTER2 then
    warn("[CH2 PUZZLES] Only Chapter 2 supported")
    return
end
local SKIP_LEVERS_TEST=true
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local env=_G
if type(getgenv)=="function" then
    local ok,g=pcall(getgenv)
    if ok and type(g)=="table" then env=g end
end
if type(env.__BEYY_CH2_COMBO_STOP)=="function" then
    pcall(env.__BEYY_CH2_COMBO_STOP,"restarting puzzle worker")
end

local started=os.clock()
print("[CH2 PUZZLES] v26 NO-LEVERS puzzle worker loaded; working cutscene v4 has exclusive camera control")
local timeout=95
local player=nil
local alive=true
local connections={}
local eventLines={}
local firstTimes={}
local attrs={}
local outputPath="BeyyHub/chapter2_no_levers_cutscene_result.txt"
local renderName="BeyyCh2NoLeversCamera"
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
local doorCutsceneMayOverlapIntro=false
local leverBypassUntil=-math.huge
local puzzleBypassUntil=-math.huge
local bypassVisuals={}
local restoreBypassVisuals=nil
local lastMaskAt=-math.huge
local lastInputAt=-math.huge
local bypassCamFrames=0
local bypassInputFixes=0
local bypassMasks=0
local bypassStage="none"
local bypassFinalProtected=false
local hayReturnStatus="not attempted"
local hayReturnSource="none"
local hayReturnAttempts=0
local hayReturnPositionError=nil
local hayReturnFacingDot=nil
local hayReturnCameraStatus="not attempted"
local hayReturnMonitorDone=true
local hayReturnMonitorSamples=0
local hayReturnDriftCorrections=0
local hayReturnFinalDistance=nil
local hayReturnFinalFacing=nil
local hayReturnCameraObstructions=0
local hayReturnReleaseObserved=false
local lastBypassAuditAt=-math.huge
local hayPreviewCameraCF=nil
local puzzleRoomCameraAnchor=nil
local lastPuzzleRoomViewWarning=-math.huge
local puzzleRoomCinematicViewFrames=0
local hayPreviewFrames=0
local hayPostReleaseCorrections=0
local hayEarlySnapbacks=0
local hayReturnFinalCameraDot=nil
local hayReturnFinalFacingRestores=0
local positionTrace={}
local positionTraceTarget=nil
local positionTraceRoomOrigin=nil
local positionTraceUntil=0
local positionTraceJumps=0
local positionTraceSnapbacks=0
local positionTraceSelfWrites=0
local positionTraceLastWriteAt=-math.huge
local positionTraceWriteName="none"
local positionTraceSamples={}
local positionTraceTrackedRoot=nil
local positionTraceLastSummaryAt=-math.huge

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

-- Diagnostic only: no teleport, camera, input, anchor, or remote writes.
-- The tracer runs in named Roblox frame phases so a later reset can be
-- compared against our own explicit CFrame write and native physics ticks.
local function positionTraceLog(message)
    local line=string.format("+%.3fs %s",seconds(),message)
    positionTrace[#positionTrace+1]=line
    if #positionTrace>140 then table.remove(positionTrace,1) end
    print("[CH2 TRACE] "..line)
end
local function positionTraceVector(v)
    if not v then return "nil" end
    return string.format("(%.2f,%.2f,%.2f)",v.X,v.Y,v.Z)
end
local function positionTraceOwner(root)
    local ok,owner=pcall(function() return root:GetNetworkOwner() end)
    if not ok then return "unavailable" end
    if owner==nil then return "nil/server-possible" end
    return owner==player and "local-player" or "other-player"
end
local function positionTraceState(root,phase,from)
    local p=player
    local hum=root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
    local cam=Workspace.CurrentCamera
    local originDistance=positionTraceRoomOrigin
        and (root.Position-positionTraceRoomOrigin).Magnitude or -1
    local targetDistance=positionTraceTarget
        and (root.Position-positionTraceTarget).Magnitude or -1
    local vel=root.AssemblyLinearVelocity
    local hstate=hum and hum:GetState()
    local receiveAge="unavailable"
    pcall(function() receiveAge=string.format("%.3f",root.ReceiveAge) end)
    return string.format(
        "phase=%s %s pos=%s fromRoom=%.2f fromHay=%.2f vel=%.1f"..
        " anchored=%s hum=%s platform=%s autoRotate=%s cut=%s release=%s"..
        " locked=%s cam=%s ownership=%s receiveAge=%s lastWrite=%s age=%.2f",
        tostring(phase),tostring(from),positionTraceVector(root.Position),
        originDistance,targetDistance,vel.Magnitude,tostring(root.Anchored),
        tostring(hstate),tostring(hum and hum.PlatformStand),
        tostring(hum and hum.AutoRotate),
        tostring(p and p:GetAttribute("CutsceneActive")),
        tostring(p and p:GetAttribute("Chapter2ReleaseActive")),
        tostring(p and p:GetAttribute("NeedleInputLocked")),
        tostring(cam and cam.CameraType),positionTraceOwner(root),
        receiveAge,positionTraceWriteName,seconds()-positionTraceLastWriteAt)
end
local function positionTraceSample(phase)
    if not alive or seconds()>positionTraceUntil or positionTraceUntil==0
        or not player then return end
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if root~=positionTraceTrackedRoot then
        positionTraceTrackedRoot=root
        positionTraceSamples={}
        positionTraceLog("ROOT CONNECTED "..positionTraceState(root,phase,"new character"))
        -- Changed may not fire for physics or replication updates; phase
        -- snapshots remain the primary evidence even if it never fires.
        hook(root:GetPropertyChangedSignal("CFrame"),function()
            if root==positionTraceTrackedRoot then
                positionTraceSample("CFrameChanged")
            end
        end)
    end
    local pos=root.Position
    local t=seconds()
    local prev=positionTraceSamples[phase]
    if prev then
        local d=(pos-prev.position).Magnitude
        if d>=8 then
            positionTraceJumps+=1
            local nearOld=positionTraceRoomOrigin
                and (pos-positionTraceRoomOrigin).Magnitude<2.5
            local nearHay=positionTraceTarget
                and (prev.position-positionTraceTarget).Magnitude<3.5
            local snap=nearOld and nearHay
            if snap then positionTraceSnapbacks+=1 end
            positionTraceLog(string.format(
                "%s JUMP #%d delta=%.2f dt=%.3f from=%s to=%s; %s",
                snap and "SAVED-ROOM SNAPBACK" or "POSITION",
                positionTraceJumps,d,t-prev.time,
                positionTraceVector(prev.position),positionTraceVector(pos),
                positionTraceState(root,phase,"observed")))
        end
    end
    positionTraceSamples[phase]={time=t,position=pos}
    if phase=="Heartbeat" and t-positionTraceLastSummaryAt>=1.0 then
        positionTraceLastSummaryAt=t
        positionTraceLog("SAMPLE "..positionTraceState(root,phase,"periodic"))
    end
end
local function positionTraceMarkWrite(label,root)
    positionTraceSelfWrites+=1
    positionTraceLastWriteAt=seconds()
    positionTraceWriteName=label
    positionTraceLog("SCRIPT WRITE #"..positionTraceSelfWrites.." "..label..
        " BEFORE "..positionTraceState(root,"explicit-write","ours"))
end
local function positionTraceAfterWrite(root)
    positionTraceLog("SCRIPT WRITE AFTER "..
        positionTraceState(root,"explicit-write","ours"))
end
hook(RunService.Heartbeat,function()positionTraceSample("Heartbeat")end)
hook(RunService.Stepped,function()positionTraceSample("Stepped")end)
local preSimOk,preSim=pcall(function()return RunService.PreSimulation end)
if preSimOk and preSim then
    hook(preSim,function()positionTraceSample("PreSimulation")end)
end
local preRenderOk,preRender=pcall(function()return RunService.PreRender end)
if preRenderOk and preRender then
    hook(preRender,function()positionTraceSample("PreRender")end)
end

local function report()
    local result={
        "CHAPTER 2 NO-LEVERS + WORKING CUTSCENE + UPGRADES v26",
        "Times relative to the test executing in Chapter 2.",
        "Actions: blackout removal, native intro Skip, three puzzles WITHOUT pulling levers, local non-final cinematic bypass.",
        "NO LEVERS MODE: "..tostring(SKIP_LEVERS_TEST).." (no LeverPuzzle actions sent by this test).",
        "No-levers worker + verified v4 Main cutscene/noclip controller.",
        "Embedded v4 controller launched: "..tostring(type(env.__BEYY_CH2_CUTSCENE_ONLY_REPORT)=="function"),
        "=== AUTO-UPGRADES REPORT ===",
        (type(env.__BEYY_CH2_AUTO_UPGRADES_REPORT)=="function"
            and env.__BEYY_CH2_AUTO_UPGRADES_REPORT()
            or "Upgrade worker not yet initialized"),
        "=== WORKING V4 CUTSCENE REPORT ===",
        (type(env.__BEYY_CH2_CUTSCENE_ONLY_REPORT)=="function"
            and env.__BEYY_CH2_CUTSCENE_ONLY_REPORT() or "v4 report not yet available"),
        "Skip attempts: "..tostring(attempts),
        "Lever test started: "..tostring(leverStarted)..", finished: "..tostring(leverFinished),
        "Puzzle started: "..tostring(puzzleStarted)..", finished: "..tostring(puzzleFinished),
        "Puzzle success: "..tostring(puzzlePassed).." error="..tostring(puzzleErr),
        "Door bypass observed: "..tostring(doorBypassSeen).." finished: "..tostring(doorBypassFinished),
        "Lever cinematic may overlap intro: "..tostring(doorCutsceneMayOverlapIntro),
        "Non-final cinematic bypass restores local camera, movement, and overlay transparency.",
        "Camera bypass frames: "..tostring(bypassCamFrames),
        "Movement restores: "..tostring(bypassInputFixes),
        "Masked overlay properties: "..tostring(bypassMasks),
        "Final ending protected: "..tostring(bypassFinalProtected),
        "Server cutscene timers are NOT modified.",
        "Native intro Skip can be used even after Picture/Color/Number puzzles progress.",
        "Hay return status: "..tostring(hayReturnStatus),
        "Hay return source: "..tostring(hayReturnSource),
        "Hay return movement attempts: "..tostring(hayReturnAttempts),
        "Hay return position error: "..tostring(hayReturnPositionError or "not recorded"),
        "Hay return facing dot: "..tostring(hayReturnFacingDot or "not recorded"),
        "Hay return camera: "..tostring(hayReturnCameraStatus),
        "Hay return monitor samples: "..tostring(hayReturnMonitorSamples),
        "Hay return snapback corrections: "..tostring(hayReturnDriftCorrections),
        "Hay return final distance: "..tostring(hayReturnFinalDistance or "not recorded"),
        "Hay return final facing dot: "..tostring(hayReturnFinalFacing or "not recorded"),
        "Hay return camera look dot: "..tostring(hayReturnFinalCameraDot or "not recorded"),
        "Hay return post-release facing restores: "..tostring(hayReturnFinalFacingRestores),
        "Hay return release observed: "..tostring(hayReturnReleaseObserved),
        "Hay return camera obstruction hits: "..tostring(hayReturnCameraObstructions),
        "Hay return visual preview frames: "..tostring(hayPreviewFrames),
        "Lever-cinematic room view frames: "..tostring(puzzleRoomCinematicViewFrames),
        "Hay return pre-release snapbacks: "..tostring(hayEarlySnapbacks),
        "Hay return post-release corrections: "..tostring(hayPostReleaseCorrections),
        "Passive trace snapbacks to room: "..tostring(positionTraceSnapbacks),
        "Passive trace large position changes: "..tostring(positionTraceJumps),
        "Passive trace marked script teleports: "..tostring(positionTraceSelfWrites),
        "Stopped: "..tostring(stopReason or "in progress"),
        "=== MILESTONES ==="
    }
    for _,name in ipairs({"player","loaded","character","leversReady","cutsceneActive",
        "overlayFound","overlayHidden","leverStarted","threeLeversConfirmed","puzzlesStarted","puzzlesFinished","hayReturn","cameraStarted","cameraMoved","skipVisible",
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
    result[#result+1]="Picture position recoveries="..tostring(puzzleDetails.pictureRootRecoveries or 0)
    result[#result+1]="Color moves inside Picture range="..tostring(puzzleDetails.colorBoardCompatibleMoves or 0)
    result[#result+1]="Color moves outside Picture range="..tostring(puzzleDetails.colorBoardProximityWarnings or 0)
    result[#result+1]="Number position recoveries="..tostring(puzzleDetails.numberRootRecoveries or 0)
    result[#result+1]="Number poster-area moves="..tostring(puzzleDetails.numberPosterAreaMoves or 0)
    result[#result+1]="Number blocked poster candidates="..tostring(puzzleDetails.numberPosterBlocked or 0)
    result[#result+1]="Poster coordination deferrals="..tostring(puzzleDetails.coordinatedPosterDeferrals or 0)
    result[#result+1]="Shared-compatible poster moves="..tostring(puzzleDetails.sharedPosterMoves or 0)
    result[#result+1]="Fallback poster moves="..tostring(puzzleDetails.fallbackPosterMoves or 0)
    result[#result+1]="Number verified path steps="..tostring(puzzleDetails.verifiedPosterMoves or 0)
    result[#result+1]="Number floor/path rejections="..tostring(puzzleDetails.rejectedFloorMoves or 0)
    result[#result+1]="Puzzle-room standing-height corrections="..tostring(puzzleDetails.roomHeightCorrections or 0)
    result[#result+1]="Puzzle-room final standing Y="..tostring(puzzleDetails.roomStandingY or "not recorded")
    result[#result+1]="Poster requests / acks="..tostring(puzzleDetails.postersSent or 0).." / "..tostring(puzzleDetails.postersAcknowledged or 0)
    result[#result+1]="Number submit attempts="..tostring(puzzleDetails.submitAttempts or 0)
    result[#result+1]="Number 4-digit code found="..tostring(puzzleDetails.validNumberCode or false)
    result[#result+1]="Number final diagnostic="..tostring(puzzleDetails.numberStatus or "not recorded")
    result[#result+1]="Final player position="..tostring(puzzleDetails.positionAtEnd or "N/A")
    result[#result+1]="Puzzle seconds="..tostring(puzzleDetails.seconds or "N/A")
    result[#result+1]="=== EVENTS ==="
    result[#result+1]=table.concat(eventLines,"\n")
    result[#result+1]="=== PASSIVE POSITION TRACE (v21) ==="
    result[#result+1]=table.concat(positionTrace,"\n")
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
    env.__BEYY_CH2_COMBO_PUZZLE_RUNNING=false
    hayPreviewCameraCF=nil
    puzzleRoomCameraAnchor=nil
    doorBypassActive=false
    -- v4 owns the camera and intro overlay; the puzzle worker must never
    -- reset them during the cutscene or after its diagnostic timeout.
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
    -- Three puzzles may finish before the native intro Skip appears.
    -- Their release flags can change CutsceneActive while the intro's
    -- actual Skip button remains valid. Validate that exact GUI instead
    -- of requiring the older intro-only attribute combination.
    if not alive or not player or not button or not isVisible(button)
        or seconds()>40
        or player:GetAttribute("IntroCutsceneFinished")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("NeedleOwned")==true then return false end
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


-- v24: unused lever actions and hay-room return retired; working v4 standalone owns all cutscene behavior.

-- Original Main Chapter2 concurrent puzzle routine, without re-running levers.
-- This is a separate experiment; concurrentPuzzles block copied byte-for-byte.
tryStartPuzzles=function()
    if puzzleStarted or not alive then return end
    puzzleStarted=true
    env.__BEYY_CH2_COMBO_PUZZLE_RUNNING=true
    first("puzzlesStarted",SKIP_LEVERS_TEST
        and "no lever actions; start Picture/Color/Number immediately after blackout"
        or "3 levers confirmed; starting Picture/Color/Number worker")
    local f=ReplicatedStorage:FindFirstChild("Puzzles")
    emit("NO-LEVERS","Puzzle worker started; LeverPuzzleSolved="..
        tostring(f and f:GetAttribute("LeverPuzzleSolved"))..
        " SolvedPuzzleCount="..tostring(f and f:GetAttribute("SolvedPuzzleCount")))
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
             assert(targetsReady(),"Puzzle-room targets did not replicate (no-levers test)")
             print("[AutoPuzzles] NO LEVERS requested; puzzle-room targets ready")
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
             -- The actual avatar may be server-snapped ~69 studs during
             -- the lever cinematic even while the puzzles continue.
             -- Keep the local bypass camera in the verified puzzle room
             -- only during such an out-of-room cinematic jump.
             puzzleRoomCameraAnchor=best
             local roomKeypadPosition=keypad:GetPivot().Position
             local nextNumberMoveAt=0
             local lastUnsafePosterNotice=-math.huge
             local posterAreaMoveCount=0
             local blockedPosterPlans=0
             local coordinatedPosterDeferrals=0
             local sharedPosterMoves=0
             local fallbackPosterMoves=0
             local lastCoordinationLog=-math.huge
             local lastPosterAreaMovement=-math.huge
             local verifiedPosterMoves=0
             local rejectedFloorMoves=0
             local roomHeightCorrections=0
             local lastHeightCorrectionAt=-math.huge
             local lastNumberPostersSent=-math.huge
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
             -- Poster and Submit acknowledgements can be delayed during the
             -- overlapping intro/door camera cinematic. The original 2-
             -- attempt cap permanently stranded Number when both failed.
             local POSTER_MAX_ATTEMPTS=5
             local SUBMIT_MAX_ATTEMPTS=5
             local numberRootRecoveries=0
             local lastNumberTrace=-math.huge
             local lastNumberMove=-math.huge
             local failedPosterChecks=0
             local submitAttemptTrace=0
             local lastStateRefreshAt=-math.huge
             local recoveryUntil=0
             local lastRecoveryLogAt=-math.huge
             local lastColorTargetScan=-math.huge
             local lastColorTrace=-math.huge
             local lastColorRootRecovery=-math.huge
             local colorRootRecoveries=0
             local pictureRootRecoveries=0
             local lastPictureRecovery=-math.huge
             local lastPictureTrace=-math.huge
             local colorNoProgress=0
             local lastColorValue=nil
             S.stateRefreshes=0 S.recoveryBackoffs=0 S.lateChecks=0
             local colorBoardCompatibleMoves=0
             local colorBoardProximityWarnings=0
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
               -- Keep Color within native range but nearer to Picture's
               -- common anchor, rather than approaching the pedestal at
               -- the unnecessarily-close 3-stud offset.
               local dy=math.abs(floorY-pedestal.Y)
               local maxHorizontal=math.sqrt(math.max(0,7.4*7.4-dy*dy))
               local offset=math.min(6.0,maxHorizontal)
               local candidate=Vector3.new(pedestal.X,floorY,pedestal.Z)+direction*offset
               local candidateDistance=(candidate-pedestal).Magnitude
               if candidateDistance>7.6 or (candidate-roomAnchor).Magnitude>19.0 then
                emit("PUZZLE","Color "..item.step.." distance recovery rejected: unsafe point")
                return false
               end
               local candidateBoardDistance=(candidate-board.Position).Magnitude
               if candidateBoardDistance<=26.5 then
                colorBoardCompatibleMoves+=1
               else
                colorBoardProximityWarnings+=1
               end
               if os.clock()-lastColorRootRecovery>0.12 then
                lastColorRootRecovery=os.clock()
                colorRootRecoveries+=1
                emit("PUZZLE",string.format("Color %s out of range: %.2f studs; toward-anchor move #%d offset=%.2f colorDist=%.2f boardDist=%.2f CutsceneActive=%s introFinished=%s",
                 item.step,dist,colorRootRecoveries,offset,candidateDistance,candidateBoardDistance,
                 tostring(P:GetAttribute("CutsceneActive")),tostring(P:GetAttribute("IntroCutsceneFinished"))))
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
             -- When the cinematic returns us to spawn after the puzzle room
             -- teleport, Main's Picture branch silently stops queuing tiles
             -- if the board becomes farther than 29 studs. Recover to a
             -- verified in-room anchor in this standalone test only.
             local function recoverPicturePosition()
              local dist=(root.Position-board.Position).Magnitude
              if dist>26.5 and pictureRootRecoveries<6
                  and os.clock()-lastPictureRecovery>=0.65 then
               lastPictureRecovery=os.clock()
               if (roomAnchor-board.Position).Magnitude<28.5 then
                pictureRootRecoveries+=1
                emit("PUZZLE",string.format("PICTURE RECOVERY #%d boardDist=%.2f roomDrift=%.2f CutsceneActive=%s",
                 pictureRootRecoveries,dist,(root.Position-roomAnchor).Magnitude,
                 tostring(P:GetAttribute("CutsceneActive"))))
                go(roomAnchor,0.12)
                dist=(root.Position-board.Position).Magnitude
               else
                emit("PUZZLE","PICTURE RECOVERY REJECTED: room anchor outside board range")
               end
              end
              if os.clock()-lastPictureTrace>=2.5 then
               lastPictureTrace=os.clock()
               local unsolved={}
               for n=1,16 do
                local part=rotationFolder:FindFirstChild("Rotation"..n)
                if part and part:IsA("ValueBase") and type(part.Value)=="number"
                    and part.Value%4~=0 then
                 unsolved[#unsolved+1]="Tile"..n..":"..tostring(part.Value)
                end
               end
               emit("PUZZLE",string.format("PICTURE TRACE boardDist=%.2f roomDrift=%.2f unsolvedTiles={%s} stateCompleted=%s",
                dist,(root.Position-roomAnchor).Magnitude,table.concat(unsolved,","),
                tostring(T.state.PicturePuzzle and T.state.PicturePuzzle.completed)))
              end
              return dist<28.0
             end
             local numberFloorRay=RaycastParams.new()
             numberFloorRay.FilterType=Enum.RaycastFilterType.Exclude
             numberFloorRay.FilterDescendantsInstances={C}
             numberFloorRay.RespectCanCollide=true
             local function puzzleFloor(at)
              return Workspace:Raycast(Vector3.new(at.X,roomAnchor.Y+5,at.Z),
                  Vector3.new(0,-12,0),numberFloorRay)
             end
             local anchorFloor=puzzleFloor(roomAnchor)
             -- A root spawned low can rise ~2.8 studs after teleporting
             -- into the puzzle room. The original movement guard then
             -- rejected all otherwise-safe poster destinations.
             -- Rebase only Y after verifying the same walkable floor.
             local function syncRoomStandingHeight(phase)
              if roomHeightCorrections>=2 or
                  os.clock()-lastHeightCorrectionAt<0.6 then return false end
              if not root or not root.Parent then return false end
              local pos=root.Position
              local lateral=(Vector3.new(pos.X,0,pos.Z)
                  -Vector3.new(roomAnchor.X,0,roomAnchor.Z)).Magnitude
              local delta=pos.Y-roomAnchor.Y
              if lateral>16.2 or math.abs(delta)<=1.5
                  or math.abs(delta)>3.8 then return false end
              local base=puzzleFloor(roomAnchor)
              local current=puzzleFloor(pos)
              if not base or not current or base.Normal.Y<0.8
                  or current.Normal.Y<0.8
                  or not base.Instance.CanCollide
                  or not current.Instance.CanCollide
                  or math.abs(base.Position.Y-current.Position.Y)>2.5 then
               return false
              end
              if base.Instance~=current.Instance
                  and base.Instance.Parent~=current.Instance.Parent then
               return false
              end
              local standingHeight=pos.Y-current.Position.Y
              if standingHeight<0.5 or standingHeight>5.4 then
               return false
              end
              local priorY=roomAnchor.Y
              roomAnchor=Vector3.new(roomAnchor.X,pos.Y,roomAnchor.Z)
              puzzleRoomCameraAnchor=roomAnchor
              floorY=pos.Y
              anchorFloor=puzzleFloor(roomAnchor)
              roomHeightCorrections+=1
              lastHeightCorrectionAt=os.clock()
              S.anchor=tostring(roomAnchor)
              emit("NUMBER",string.format(
                  "ROOM HEIGHT REBASE #%d phase=%s oldY=%.3f newY=%.3f delta=%.3f physicalFloorY=%.3f lateral=%.2f",
                  roomHeightCorrections,tostring(phase),priorY,pos.Y,delta,
                  current.Position.Y,lateral))
              return true
             end
             syncRoomStandingHeight("initial puzzle-room arrival")
             local function withinRoomFloor(at)
              local planar=(Vector3.new(at.X,0,at.Z)
                  -Vector3.new(roomAnchor.X,0,roomAnchor.Z)).Magnitude
              if planar>16.2 or math.abs(at.Y-roomAnchor.Y)>1.5 then return false end
              local hit=puzzleFloor(at)
              if not anchorFloor or not hit or hit.Normal.Y<0.8
                  or not hit.Instance.CanCollide or
                  math.abs(hit.Position.Y-anchorFloor.Position.Y)>2.5 then return false end
              local a,b=anchorFloor.Instance,hit.Instance
              if a~=b and a.Parent~=b.Parent then return false end
              local n=b.Name:lower()
              return not (n:find("cage",1,true) or
                  n:find("alien",1,true) or n:find("boss",1,true))
             end
             local function moveToNumberPoint(target)
              if not withinRoomFloor(target) then
               rejectedFloorMoves+=1
               return false
              end
              local old=root.Position
              if (Vector3.new(target.X,0,target.Z)-Vector3.new(old.X,0,old.Z)).Magnitude>23 then
               go(roomAnchor,0.10)
               old=root.Position
              end
              local flat=(Vector3.new(target.X,0,target.Z)-Vector3.new(old.X,0,old.Z)).Magnitude
              local steps=math.max(1,math.ceil(flat/7.6))
              if steps>4 then return false end
              for i=1,steps do
               local alpha=i/steps
               local point=Vector3.new(old.X+(target.X-old.X)*alpha,
                   roomAnchor.Y,old.Z+(target.Z-old.Z)*alpha)
               if not withinRoomFloor(point) then
                rejectedFloorMoves+=1
                return false
               end
               go(point,0.09)
               verifiedPosterMoves+=1
              end
              return (root.Position-target).Magnitude<4
             end
             -- Keep Number interactions inside their native range and
             -- strictly inside the verified puzzle-room footprint.
             -- Never teleport to posters outside that footprint.
             local function ensureNumberPosition(item)
              local target=item.index and item.part and item.part.Position
                  or (not item.index and keypad:GetPivot().Position)
              if not target then return false end
              local dist=(root.Position-target).Magnitude
              local maxRange=item.index and 8.0 or 8.2
              local posterFlat=Vector3.new(target.X,roomAnchor.Y,target.Z)
              local flatToAnchor=Vector3.new(roomAnchor.X-posterFlat.X,0,roomAnchor.Z-posterFlat.Z)
              if item.index and ((posterFlat-roomAnchor).Magnitude>22
                  or math.abs(target.Y-roomAnchor.Y)>7) then
               if item.attempts==0 then
                emit("NUMBER","Poster index "..tostring(item.index).." outside verified puzzle-room footprint; skipped")
               end
               return false
              end
              if dist>maxRange or item.attempts>=2 and dist>6.5 then
               if os.clock()-lastNumberMove<0.35 then return false end
               lastNumberMove=os.clock()
               local direction=flatToAnchor.Magnitude>0.01
                   and flatToAnchor.Unit or Vector3.new(0,0,1)
               local candidate=Vector3.new(target.X,roomAnchor.Y,target.Z)
                   +direction*math.min(5.5,flatToAnchor.Magnitude)
               if (candidate-roomAnchor).Magnitude>15 or
                   (candidate-board.Position).Magnitude>=29 or
                   (candidate-target).Magnitude>7.5 then
                emit("NUMBER","Rejected out-of-range "..tostring(item.step).." reposition, preserving safe room")
                return false
               end
               numberRootRecoveries+=1
               emit("NUMBER",string.format("Near-target recovery #%d %s index=%s beforeDistance=%.2f attempts=%d",
                   numberRootRecoveries,item.step,tostring(item.index),
                   dist,item.attempts or 0))
               go(candidate,0.12)
               dist=(root.Position-target).Magnitude
              end
              return dist<8.8
             end
             local function dispatch(item)
              guard()
              if item.puzzle=="NumberPuzzle" and not ensureNumberPosition(item) then
               item.retryAfter=os.clock()+0.3
               return nil
              end
              if item.puzzle=="PicturePuzzle" and not recoverPicturePosition() then
               item.retryAfter=os.clock()+0.3
               return nil
              end
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
              if item.puzzle=="NumberPuzzle" then
               if item.submit then
                submitAttemptTrace+=1
                emit("NUMBER","Submit request #"..submitAttemptTrace..
                    " validCode="..tostring(valid(codeFound))..
                    " distance="..string.format("%.2f",(root.Position-keypad:GetPivot().Position).Magnitude))
               elseif item.index then
                emit("NUMBER","Poster request index="..tostring(item.index)..
                    " attempt="..tostring((item.attempts or 0)+1)..
                    " distance="..string.format("%.2f",(root.Position-item.part.Position).Magnitude))
               end
              end
              local request={item=item,before=before,at=os.clock(),request=d}
              table.insert(pending,request)
              item.pending=request item.lastDispatch=os.clock() item.attempts=(item.attempts or 0)+1
              nextBy[item.puzzle]=os.clock()+intervals[item.puzzle]
              nextAny=os.clock()+0.14
              if item.index then
               S.postersSent=S.postersSent+1
               lastNumberPostersSent=os.clock()
              end
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
                if request.item.index then
                S.postersAcknowledged=S.postersAcknowledged+1
                emit("NUMBER","Poster index "..tostring(request.item.index).." acknowledged")
               elseif request.item.submit then
                emit("NUMBER","Keypad Submit acknowledged by completed NumberPuzzle state")
               end
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
                 if request.item.puzzle=="NumberPuzzle" then
                  failedPosterChecks+=1
                  emit("NUMBER","Number request missing acknowledgement, step="..
                    request.item.step.." index="..tostring(request.item.index)..
                    " attempts="..tostring(request.item.attempts)..
                    " validCode="..tostring(valid(codeFound)))
                 end
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
               if item.part.Parent and needed(item) and not item.pending
                   and item.attempts<POSTER_MAX_ATTEMPTS
                   and (not item.retryAfter or os.clock()>=item.retryAfter) then
                local d=distance(root.Position,item.part.Position)
                -- After one rejected request, allow the near-target guard
                -- in dispatch() to relocate to safer, closer proximity.
                if d<9 and d<closest then bestPaper=item closest=d end
               end
              end
              return bestPaper
             end
             local function numberTrace(why)
              if os.clock()-lastNumberTrace<2.5 then return end
              lastNumberTrace=os.clock()
              local data=T.state.NumberPuzzle or {}
              local status={}
              for _,paper in ipairs(papers) do
               if paper.part.Parent then
                local d=(root.Position-paper.part.Position).Magnitude
                status[#status+1]=string.format("%s:%dtry/%.1fstud/taken=%s",
                    tostring(paper.index),paper.attempts,d,tostring(taken(paper)))
               end
              end
              local textLine=string.format("why=%s codeReady=%s keypadDistance=%.2f submitAttempts=%d posters=[%s] NumberCompleted=%s",
                  tostring(why),tostring(valid(codeFound)),
                  (root.Position-keypad:GetPivot().Position).Magnitude,
                  submit.attempts,table.concat(status,","),tostring(data.completed))
              puzzleDetails.numberStatus=textLine
              emit("NUMBER","STATUS "..textLine)
             end
             local deadline=os.clock()+45
             while not (solved("PicturePuzzle") and solved("ColorPuzzle") and solved("NumberPuzzle")) and os.clock()<deadline do
              guard()
              local paperPending=poll()
              -- Repeat a bounded check if the avatar only settles after
              -- the initial room arrival wait or after the native Skip.
              syncRoomStandingHeight("puzzle loop")
              refreshColorTargets()
              -- Picture movement only occurs when a tile is actually ready.
              if not solved("NumberPuzzle") then numberTrace("ongoing") end
              for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do
               if solved(name) and not S[name.."ConfirmedAt"] then S[name.."ConfirmedAt"]=elapsed() end
              end
              -- The Number poster search must NOT wait for ColorPuzzle.
              -- v7 exhausted every poster within the initial 9-stud range,
              -- then idled for ~40s because this whole movement branch was
              -- gated by solved("ColorPuzzle"). Continue poster sampling
              -- independently while Picture/Color are still being solved.
              if not solved("NumberPuzzle") and paperPending==0 then
               -- Nearby posters are still sampled immediately. Only a
               -- *long-distance* poster-area move needs coordination with
               -- the Color/Picture workers. Their ranges can be invalidated
               -- by moving the avatar away to another poster cluster.
               local now=os.clock()
               local activeColor=not solved("ColorPuzzle")
               local activePicture=not solved("PicturePuzzle")
               local sinceStarted=now-began
               local allowAreaMove=(not activeColor and not activePicture)
                   or (sinceStarted>=2.2
                       and (sinceStarted>=4.2 or
                           now-lastNumberPostersSent>0.35))
               if not valid(codeFound) and not nearPaper()
                   and now>=nextNumberMoveAt and
                   now-lastPosterAreaMovement>=1.00 and allowAreaMove then
                nextNumberMoveAt=os.clock()+0.70
                local bestMove=nil
                local bestCount=-1
                local bestTravel=math.huge
                local bestShared=-math.huge
                -- First seek destinations which still serve unfinished
                -- Color/Picture. If none exists, permit the original v9
                -- wider Number recovery after a bounded 4.2s grace.
                local sharedOnly=(activeColor or activePicture)
                    and sinceStarted<4.2
                local candidates=0
                local reachable=0
                local verticalY=root.Position.Y
                local anchor=Vector3.new(roomAnchor.X,verticalY,roomAnchor.Z)
                for _,item in ipairs(papers) do
                 if item.part.Parent and needed(item)
                     and item.attempts<POSTER_MAX_ATTEMPTS
                     and not item.pending
                     and (not item.retryAfter or os.clock()>=item.retryAfter) then
                  candidates+=1
                  local posterPos=item.part.Position
                  local targetFlat=Vector3.new(posterPos.X,verticalY,posterPos.Z)
                  local delta=targetFlat-anchor
                  local away=delta.Magnitude
                  if away<=22 and math.abs(posterPos.Y-verticalY)<=7 then
                   -- The shallowest move which puts the poster within
                   -- 7.5 studs, without ever leaving the puzzle room.
                   local moveAlong=math.min(16,math.max(0,away-6.2))
                   local point=away>0.01 and anchor+delta.Unit*moveAlong or anchor
                   if distance(point,posterPos)<8.1
                       and distance(point,anchor)<=16.2
                       and distance(point,roomKeypadPosition)<26
                       and (solved("PicturePuzzle") or distance(point,board.Position)<28.8)
                       and withinRoomFloor(point) then
                    reachable+=1
                    local count=0
                    for _,other in ipairs(papers) do
                     if other.part.Parent and needed(other)
                         and other.attempts<POSTER_MAX_ATTEMPTS
                         and distance(other.part.Position,point)<8.4 then
                      count+=1
                     end
                    end
                    local travel=distance(root.Position,point)
                    local pictureCompatible=not activePicture
                        or distance(point,board.Position)<=26.5
                    local colorsAccessible=0
                    if activeColor then
                     for _,color in ipairs(colors) do
                      if needed(color) and distance(point,color.model:GetPivot().Position)<=8.8 then
                       colorsAccessible+=1
                      end
                     end
                    end
                    local colorCompatible=not activeColor or colorsAccessible>0
                    local shared=pictureCompatible and colorCompatible
                    local sharedValue=shared and (5+colorsAccessible*2) or 0
                    local score=count+sharedValue
                    -- During the first few seconds, favor a poster group
                    -- which doesn't force the two other workers to undo
                    -- our movement. The timed fallback always recovers
                    -- distant Number posters if shared locations run out.
                    if not sharedOnly or shared then
                     if score>bestShared or (score==bestShared and
                         (count>bestCount or (count==bestCount and travel<bestTravel))) then
                      bestMove=point
                      bestCount=count
                      bestTravel=travel
                      bestShared=score
                     end
                    end
                   end
                  end
                 end
                end
                if bestMove then
                 if distance(root.Position,bestMove)>0.9 then
                  posterAreaMoveCount+=1
                  emit("NUMBER",string.format(
                   "POSTER AREA MOVE #%d candidatePosters=%d reachable=%d pickups=%d travel=%.2f colorSolved=%s pictureSolved=%s",
                   posterAreaMoveCount,candidates,reachable,bestCount,bestTravel,
                   tostring(solved("ColorPuzzle")),tostring(solved("PicturePuzzle"))))
                  if moveToNumberPoint(bestMove) then
                   S.numberMoves+=1
                   lastPosterAreaMovement=os.clock()
                   if sharedOnly then sharedPosterMoves+=1
                   else fallbackPosterMoves+=1 end
                   emit("NUMBER","Verified poster-area move reached target; strategy="..
                       (sharedOnly and "shared-active-puzzle" or "v9-fallback"))
                  else
                   emit("NUMBER","Poster-area move refused: unverified floor/path")
                  end
                 else
                  if os.clock()-lastUnsafePosterNotice>2.5 then
                   lastUnsafePosterNotice=os.clock()
                   emit("NUMBER","Poster area candidate already near character; recheck range on next loop")
                  end
                 end
                elseif sharedOnly then
                 if now-lastCoordinationLog>=1.5 then
                  lastCoordinationLog=now
                  coordinatedPosterDeferrals+=1
                  emit("COORD","No joint Color/Picture-compatible poster group; waiting until 4.2s fallback. candidatePosters="..
                      tostring(candidates).." reachable="..tostring(reachable))
                 end
                elseif os.clock()-lastUnsafePosterNotice>=3 then
                 lastUnsafePosterNotice=os.clock()
                 blockedPosterPlans+=1
                 emit("NUMBER",string.format(
                  "NO SAFE POSTER MOVE: remaining=%d reachable=%d pos=%s anchor=%s colorSolved=%s",
                  candidates,reachable,tostring(root.Position),tostring(roomAnchor),
                  tostring(solved("ColorPuzzle"))))
                 emit("NUMBER",string.format(
                    "POSTER FLOOR DIAGNOSTIC rootY=%.3f anchorY=%.3f verticalGap=%.3f rebaseCount=%d",
                    root.Position.Y,roomAnchor.Y,
                    root.Position.Y-roomAnchor.Y,roomHeightCorrections))
                end
               elseif not allowAreaMove and not valid(codeFound)
                   and not nearPaper() and now-lastCoordinationLog>=1.5 then
                lastCoordinationLog=now
                coordinatedPosterDeferrals+=1
                emit("COORD","Deferring long-distance posters while Color/Picture progress; elapsed="..
                    string.format("%.2f",sinceStarted).."s")
               elseif valid(codeFound) and not submit.pending
                   and distance(root.Position,roomKeypadPosition)>8.5
                   and os.clock()>=nextNumberMoveAt then
                nextNumberMoveAt=os.clock()+0.55
                local towards=roomAnchor-roomKeypadPosition
                local flat=Vector3.new(towards.X,0,towards.Z)
                local keypadPoint=roomAnchor
                if flat.Magnitude>0.01 then
                 keypadPoint=Vector3.new(roomKeypadPosition.X,roomAnchor.Y,roomKeypadPosition.Z)
                     +flat.Unit*math.min(7.5,flat.Magnitude)
                end
                if distance(keypadPoint,roomAnchor)<=7.5
                    and distance(keypadPoint,board.Position)<29 then
                 emit("NUMBER","Code ready; reposition near verified keypad location")
                 go(keypadPoint,0.10)
                 S.numberMoves+=1
                end
               end
              end
              for offset=1,3 do
               local index=((typeCursor+offset-1)%3)+1
               local name=({"PicturePuzzle","ColorPuzzle","NumberPuzzle"})[index]
               if os.clock()>=nextBy[name] and
                (os.clock()>=recoveryUntil or (os.clock()>=nextAny and #pending<5)) then
                local item=nil
                if name=="PicturePuzzle" then
                 local tile=nextPic()
                 if tile and recoverPicturePosition() then item=tile end
                elseif name=="ColorPuzzle" then item=nextColor()
                elseif name=="NumberPuzzle" and not solved("NumberPuzzle") then
                 if valid(codeFound) and not submit.pending
                     and submit.attempts<SUBMIT_MAX_ATTEMPTS
                     and (not submit.retryAfter or os.clock()>=submit.retryAfter) then
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
             S.colorBoardCompatibleMoves=colorBoardCompatibleMoves
             S.colorBoardProximityWarnings=colorBoardProximityWarnings
             S.pictureRootRecoveries=pictureRootRecoveries
             S.numberRootRecoveries=numberRootRecoveries
             S.numberPosterAreaMoves=posterAreaMoveCount
             S.numberPosterBlocked=blockedPosterPlans
             S.coordinatedPosterDeferrals=coordinatedPosterDeferrals
             S.sharedPosterMoves=sharedPosterMoves
             S.fallbackPosterMoves=fallbackPosterMoves
             S.verifiedPosterMoves=verifiedPosterMoves
             S.rejectedFloorMoves=rejectedFloorMoves
             S.roomHeightCorrections=roomHeightCorrections
             S.roomStandingY=roomAnchor.Y
             S.submitAttempts=submit.attempts
             numberTrace("end-of-window")
             emit("PUZZLE","END STATE picture="..tostring(S.picturePassed)..
                " color="..tostring(S.colorPassed).." number="..tostring(S.numberPassed)..
                " ColorRootRecoveries="..tostring(colorRootRecoveries)..
                " PictureRootRecoveries="..tostring(pictureRootRecoveries)..
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
                -- A no-lever experiment must not accidentally require the
                -- very gate we are testing. Confirm each puzzle from the
                -- server snapshot as well as replicated completion count.
                local allThree=true
                for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do
                    local state=T.state[name]
                    if not (type(state)=="table" and state.completed==true) then
                        allThree=false
                        break
                    end
                end
                return (SKIP_LEVERS_TEST or F:GetAttribute("LeverPuzzleSolved")==true)
                    and allThree
                    and (tonumber(F:GetAttribute("SolvedPuzzleCount")) or 0)>=3
            end,1.5),"Final replicated 3-puzzle completion incomplete without levers")
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
        emit("NO-LEVERS","Worker result="..tostring(passed)..
            " leverSolved="..tostring(F and F:GetAttribute("LeverPuzzleSolved"))..
            " solvedCount="..tostring(F and F:GetAttribute("SolvedPuzzleCount"))..
            " (no lever requests were sent)")
        if passed then
            puzzleBypassUntil=math.max(puzzleBypassUntil,os.clock()+11)
            emit("CUTSCENE","Puzzle release bypass grace armed on 3/3 server-confirmed puzzles")
            -- Leave the character in the puzzle room after completion.
            -- The saved hay-return routine is intentionally not started.
            hayReturnStatus="disabled; staying in puzzle room"
        end
        puzzleDetails.requests=#T.requests
        puzzleDetails.seconds=string.format("%.3f",elapsed())
        puzzleDetails.colorRootRecoveries=T.stages.concurrent
            and T.stages.concurrent.colorRootRecoveries or 0
        puzzleDetails.pictureRootRecoveries=T.stages.concurrent
            and T.stages.concurrent.pictureRootRecoveries or 0
        puzzleDetails.colorBoardCompatibleMoves=T.stages.concurrent
            and T.stages.concurrent.colorBoardCompatibleMoves or 0
        puzzleDetails.colorBoardProximityWarnings=T.stages.concurrent
            and T.stages.concurrent.colorBoardProximityWarnings or 0
        puzzleDetails.positionAtEnd=root and tostring(root.Position) or "missing"
        puzzleDetails.numberRootRecoveries=T.stages.concurrent
            and T.stages.concurrent.numberRootRecoveries or 0
        puzzleDetails.numberPosterAreaMoves=T.stages.concurrent
            and T.stages.concurrent.numberPosterAreaMoves or 0
        puzzleDetails.numberPosterBlocked=T.stages.concurrent
            and T.stages.concurrent.numberPosterBlocked or 0
        puzzleDetails.coordinatedPosterDeferrals=T.stages.concurrent
            and T.stages.concurrent.coordinatedPosterDeferrals or 0
        puzzleDetails.sharedPosterMoves=T.stages.concurrent
            and T.stages.concurrent.sharedPosterMoves or 0
        puzzleDetails.fallbackPosterMoves=T.stages.concurrent
            and T.stages.concurrent.fallbackPosterMoves or 0
        puzzleDetails.verifiedPosterMoves=T.stages.concurrent
            and T.stages.concurrent.verifiedPosterMoves or 0
        puzzleDetails.rejectedFloorMoves=T.stages.concurrent
            and T.stages.concurrent.rejectedFloorMoves or 0
        puzzleDetails.roomHeightCorrections=T.stages.concurrent
            and T.stages.concurrent.roomHeightCorrections or 0
        puzzleDetails.roomStandingY=T.stages.concurrent
            and T.stages.concurrent.roomStandingY or nil
        puzzleDetails.submitAttempts=T.stages.concurrent
            and T.stages.concurrent.submitAttempts or 0
        puzzleDetails.postersSent=T.stages.concurrent
            and T.stages.concurrent.postersSent or 0
        puzzleDetails.postersAcknowledged=T.stages.concurrent
            and T.stages.concurrent.postersAcknowledged or 0
        puzzleDetails.validNumberCode=valid(codeFound)
        for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do
            local state=T.state[name]
            puzzleDetails[name]=(state and state.completed==true)
                and "server-confirmed" or "not-confirmed"
        end
        puzzleFinished=true
        env.__BEYY_CH2_COMBO_PUZZLE_RUNNING=false
        first("puzzlesFinished","passed="..tostring(passed))
        emit("PUZZLE","RESULT passed="..tostring(passed)..
            " requests="..tostring(puzzleDetails.requests)..
            " seconds="..puzzleDetails.seconds..
            " error="..tostring(puzzleErr))
    end)
end

-- v24: unused legacy cutscene and camera overrides retired; working v4 standalone owns all cutscene behavior.

-- v24: only diagnostic/puzzle work remains active in this older test.
-- Native intro Skip, blackout, camera, cutscene, noclip and movement recovery
-- are all delegated to the embedded verified cutscene-only v4 controller.
hook(UserInputService.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F8 then save(true) end
end)
if game:IsLoaded() then
    first("loaded","already loaded")
else
    hook(game.Loaded,function()first("loaded","game.Loaded fired")end)
end
emit("BOOT","Puzzle-only worker v26 started: no levers; cutscene v4 and upgrades handled by separate modules.")
task.spawn(function()
    while alive and seconds()<timeout do
        local ok,err=pcall(function()
            if not player then
                player=Players.LocalPlayer
                if player then first("player","LocalPlayer available") end
            end
            if not player then return end
            local char=player.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if root then first("character","root available") end
            local done=player:GetAttribute("IntroCutsceneFinished")==true
            local cutscene=player:GetAttribute("CutsceneActive")==true
            if done and not introCompletedAt then
                introCompletedAt=seconds()
                first("introFinished","intro finished; v4 owns camera")
            end
            if player:GetAttribute("NeedleRoundComplete")==true
                or player:GetAttribute("NeedleOwned")==true then return end
            if not puzzleStarted and root then
                local pg=player:FindFirstChildOfClass("PlayerGui")
                local fade=pg and pg:FindFirstChild("CutsceneFade")
                local black=fade and fade:FindFirstChild("Black",true)
                local overlayCleared=black and black:IsA("GuiObject")
                    and black.Visible==false
                if (cutscene and overlayCleared) or done then
                    leverFinished=true
                    first("overlayHidden","working v4 cutscene controller hidden blackout")
                    emit("NO-LEVERS","Launching direct Picture/Color/Number puzzle worker, no lever requests")
                    tryStartPuzzles()
                end
            end
        end)
        if not ok then changed("WatchError",err) end
        if alive and seconds()>15 and lastSaveAt<15 then save(false) end
        if alive and seconds()>25 and lastSaveAt<25 then save(false) end
        if alive and seconds()>60 and lastSaveAt<60 then save(false) end
        if puzzleFinished and introCompletedAt
            and seconds()-introCompletedAt>=15 then
            stop("3 puzzle results captured; v4 cutscene/noclip companion remains active")
            return
        end
        task.wait(seconds()<19 and 0.035 or 0.12)
    end
    if alive then stop("95s no-levers puzzle test complete; v4 cutscene companion may continue") end
end)
