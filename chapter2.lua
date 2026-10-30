-- beyy v103.00 | Chapter2 module | PlaceId 83445806734780
local __BEYY_MODULE = "Chapter2"
local __BEYY_SCRIPT_VERSION = "103.00"
-- Confirmed parallel puzzle queues and native key pickup/turn-in.
local __BEYY_BOOT_T0 = os.clock()
if game.PlaceId ~= 83445806734780 then
    warn("[BeyyHub] Refusing to load Chapter2 module in another place")
    return
end

-- Direct, self-contained port of the verified standalone Chapter 2 v22
-- lever + Picture/Color/Number + intro/cutscene controller. No network fetch.
-- This is the only automatic Chapter 2 puzzle sequence. In particular, the
-- source deliberately does not invoke the old saved-hay-return function.
local __BEYY_CH2_V22_SOURCE = [==========[
-- Beyy Chapter 2 Early Full Puzzles Test v22
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
    -- Never queue a network fallback string: it can be malformed or stale.
    -- Compile exactly the full source that will run in the destination.
    local body,compileError=nil,nil
    for attempt=1,3 do
        local ok,source=pcall(function()
            return game:HttpGet(URL.."?preload=v22-"..tostring(os.time())..
                "-"..tostring(math.random(10000,99999)).."-"..tostring(attempt))
        end)
        if ok and type(source)=="string"
            and source:find("Beyy Chapter 2 Early Full Puzzles Test v22",1,true) then
            local compiled,fnOrError=pcall(loadstring,source)
            if compiled and type(fnOrError)=="function" then
                body=source
                break
            end
            compileError=compiled and "loadstring returned nil" or tostring(fnOrError)
            -- A nil compile result may include a second error return.
            if compiled and type(fnOrError)~="function" then
                local _,err=loadstring(source)
                compileError=tostring(err)
            end
        else
            compileError=ok and "old/invalid raw GitHub response" or tostring(source)
        end
        task.wait(0.25)
    end
    if not body then
        warn("[CH2 COMBO] v22 NOT queued: "..tostring(compileError))
        warn("[CH2 COMBO] No online fallback will execute. Retry in the lobby.")
        return
    end
    local armed,err=pcall(queue,body)
    if armed then
        print("[CH2 COMBO] Preloaded and compiled v22 ("..tostring(#body)..
            " bytes). Enter Chapter 2.")
    else
        warn("[CH2 COMBO] Failed to queue v22: "..tostring(err))
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
print("[CH2 COMBO] v22 loaded: hay-return disabled; stay in puzzle room")
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
        "CHAPTER 2 EARLY FULL PUZZLES TEST v22",
        "Times relative to the test executing in Chapter 2.",
        "Actions: blackout GUI/camera, native intro Skip, early native lever and Picture/Color/Number puzzle actions.",
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
    hayPreviewCameraCF=nil
    puzzleRoomCameraAnchor=nil
    doorBypassActive=false
    releaseCamera("test cleanup")
    if restoreBypassVisuals then restoreBypassVisuals() end
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
    local requestTimes={}
    local initialRequestAckWait=0.115
    local retryAckGrace=0.40
    local snapbackRecoveries=0
    local earlySnapbackCorrections=0
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
                leverBypassUntil=math.max(leverBypassUntil,os.clock()+9)
                emit("CUTSCENE","Lever-door bypass grace armed as soon as 3/3 levers confirmed")
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
        -- Lever2 is susceptible to collision/cinematic snapback.
        -- Check it midway through the existing settle interval, and
        -- correct one large reset before the request. This is bounded:
        -- there is no loop or additional native request.
        if i==2 and settle>=0.09 then
            local midpoint=math.min(settle,0.06)
            task.wait(midpoint)
            if safe() and not check(i,"movement-midpoint confirmation") and
                (root.Position-target).Magnitude>10 then
                earlySnapbackCorrections+=1
                emit("LEVER","Lever2 mid-settle snapback detected; correcting before native request #"..
                    tostring(earlySnapbackCorrections))
                root.CFrame=CFrame.new(target)*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
            end
            task.wait(math.max(0,settle-midpoint))
        else
            task.wait(settle)
        end
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
        requestTimes[i]=lastRequest
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
    -- Fast first pass: give each server request a short acknowledgement
    -- window and move to the next lever without waiting the old full 0.28s
    -- for a response. The PuzzleState connection collects late replies
    -- asynchronously while subsequent levers are attempted.
    local firstPassStarted=os.clock()
    for i=1,3 do
        if not safe() or p:GetAttribute("IntroCutsceneFinished")==true then break end
        -- Lever2's 2-stud approach was server-confirmed in the v10
        -- recovery, at 5.13 studs from its pivot, vs ~6.3 studs at
        -- the original 3-stud approach. Test it on the first pass.
        local initialOffset=i==2 and 2.0 or 3.0
        -- A slightly longer first-pass settle for Lever1/3 costs 0.08s
        -- total, but may reduce the 0.4-1s retry penalties seen in v15.
        local firstSettle=i==2 and 0.10 or 0.14
        if not check(i,"already-pulled") and move(i,firstSettle,initialOffset) then
            send(i,"early-blackout")
            ack(i,initialRequestAckWait)
        end
    end
    emit("LEVER",string.format("FAST FIRST PASS finished in %.3fs; late server acknowledgements still monitored",
        os.clock()-firstPassStarted))
    local lateAckDeadline=os.clock()+0.12
    while safe() and os.clock()<lateAckDeadline do
        local all=true
        for i=1,3 do
            if not check(i,"first-pass-late-reply") then all=false end
        end
        if all then break end
        task.wait(0.01)
    end
    local early=0
    for i=1,3 do if check(i,"end early phase") then early+=1 end end
    emit("LEVER","INITIAL EARLY PHASE: "..early.."/3 confirmed before Skip")
    -- Only recover missing levers. Avoid prematurely repeating an in-flight
    -- native request: give its PuzzleState reply 0.4s before the same-lever
    -- retry. Maintain up to two bounded additional pre-Skip attempts.
    -- Lever2 now starts with the proven close approach; try the old
    -- 3-stud position only on the second pre-Skip retry.
    local earlyOffsets={2.0,3.0}
    for retry=1,2 do
        if not safe() or skipSeen or p:GetAttribute("IntroCutsceneFinished")==true then break end
        for i=1,3 do
            if not safe() or skipSeen
                or p:GetAttribute("IntroCutsceneFinished")==true then break end
            if not check(i,"early retry check") then
                local prior=requestTimes[i]
                if prior then
                    while safe() and not skipSeen
                        and p:GetAttribute("IntroCutsceneFinished")~=true
                        and os.clock()-prior<retryAckGrace
                        and not check(i,"in-flight confirmation") do
                        task.wait(0.01)
                    end
                end
                if not check(i,"grace confirmation") then
                    local offset=(i==2) and earlyOffsets[retry] or 3.0
                    emit("LEVER","PRE-SKIP RETRY "..retry.." Lever"..i..
                        " offset="..offset.." priorAge="..
                        string.format("%.3f",prior and (os.clock()-prior) or -1))
                    local moved=move(i,retry==1 and 0.12 or 0.17,offset)
                    -- Cinematic snapback sometimes moves the character
                    -- 70+ studs during the settle window. Preserve the
                    -- >10-stud safety guard, but recover immediately once
                    -- instead of discarding the entire retry.
                    if not moved and safe() and not skipSeen
                        and not check(i,"snapback-late-ack")
                        and p:GetAttribute("IntroCutsceneFinished")~=true then
                        snapbackRecoveries+=1
                        emit("LEVER","SNAPBACK RECOVERY Lever"..i..
                            " local reposition #"..snapbackRecoveries)
                        moved=move(i,0.10,offset)
                    end
                    if moved and not skipSeen
                        and not check(i,"pre-retry confirmation")
                        and p:GetAttribute("IntroCutsceneFinished")~=true then
                        send(i,"pre-skip-retry-"..retry)
                        ack(i,retry==1 and 0.27 or 0.35)
                    end
                end
            end
        end
    end
    emit("LEVER","Snapback correction moves="..snapbackRecoveries..
        " mid-settle corrections="..earlySnapbackCorrections)
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


-- Standalone saved hay-pile return point. The exact target is captured by
-- chapter2-hay-return-capture.lua while standing at the intended hay pile.
-- Do not invent a target or move the player if the capture is missing.
local function returnToCapturedHay(P,C,root)
    if not alive or not P or not C or not root or P.Character~=C then return end
    if P:GetAttribute("NeedleRoundComplete")==true
        or P:GetAttribute("NeedleOwned")==true then
        hayReturnStatus="final ending protected"
        emit("HAY RETURN","Aborted: final needle ending protected")
        return
    end
    local HttpService=game:GetService("HttpService")
    local files={"BeyyHub/chapter2_hay_return.json",
        "BeyyHub_chapter2_hay_return.json"}
    local data=nil
    if type(readfile)=="function" then
        for _,path in ipairs(files) do
            local ok,raw=pcall(readfile,path)
            if ok and type(raw)=="string" and #raw>0 then
                local parsed,decoded=pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if parsed and type(decoded)=="table" then
                    data=decoded
                    hayReturnSource=path
                    break
                end
            end
        end
    end
    if not data then
        hayReturnStatus="no saved destination"
        emit("HAY RETURN",
            "No saved Chapter 2 hay-pile location. Stand at the pile and run chapter2-hay-return-capture.lua once; no teleport performed.")
        return
    end
    local arr=data.characterCFrame
    local function finite(n)
        return type(n)=="number" and n==n and math.abs(n)<10000000
    end
    if data.version~=1 or data.placeId~=CHAPTER2
        or type(arr)~="table" or #arr~=12 then
        hayReturnStatus="invalid destination"
        emit("HAY RETURN","Saved capture has wrong version/place or incomplete character CFrame; no teleport.")
        return
    end
    for i=1,12 do
        if not finite(arr[i]) then
            hayReturnStatus="invalid destination"
            emit("HAY RETURN","Invalid CFrame value at index "..i.."; no teleport.")
            return
        end
    end
    local okCF,target=pcall(function()
        return CFrame.new(table.unpack(arr))
    end)
    if not okCF then
        hayReturnStatus="invalid destination"
        emit("HAY RETURN","Saved CFrame could not be reconstructed; no teleport.")
        return
    end
    if not alive or P.Character~=C or not root.Parent then return end
    first("hayReturn","server-confirmed puzzles and final SolvedPuzzleCount; saved hay return requested")
    positionTraceTarget=target.Position
    positionTraceRoomOrigin=root.Position
    positionTraceUntil=seconds()+38
    positionTraceLog("ARMED room="..positionTraceVector(positionTraceRoomOrigin)..
        " hay="..positionTraceVector(positionTraceTarget)..
        " " .. positionTraceState(root,"arm","read-only"))
    emit("HAY RETURN",string.format(
        "Saved target %.3f, %.3f, %.3f, facing %.3f/%.3f/%.3f source=%s",
        target.Position.X,target.Position.Y,target.Position.Z,
        target.LookVector.X,target.LookVector.Y,target.LookVector.Z,hayReturnSource))
    -- The server owns character positioning throughout Chapter2ReleaseActive.
    -- Do not perform the physical return during that cinematic: its immediate
    -- snapback is expected, and a transient 0-stud check is not success.
    local savedHayCamCF=nil
    local releaseActiveAtStart=P:GetAttribute("Chapter2ReleaseActive")==true
        or P:GetAttribute("CutsceneActive")==true
    hayReturnStatus=releaseActiveAtStart
        and "waiting for server cinematic release" or "attempting"
    if releaseActiveAtStart then
        emit("HAY RETURN","v21 DIAG: hay return held until release; passive position tracing armed")
    else
    for attempt=1,2 do
        if not alive or P.Character~=C or not root.Parent
            or P:GetAttribute("NeedleRoundComplete")==true
            or P:GetAttribute("NeedleOwned")==true then
            hayReturnStatus="aborted by character or ending state"
            break
        end
        if root.Anchored then
            if P:GetAttribute("CutsceneActive")==true
                or P:GetAttribute("Chapter2ReleaseActive")==true then
                root.Anchored=false
            else
                hayReturnStatus="anchored outside nonfinal cinematic"
                break
            end
        end
        hayReturnAttempts=attempt
        positionTraceMarkWrite("initial-attempt-"..attempt,root)
        root.CFrame=target
        positionTraceAfterWrite(root)
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        task.wait(attempt==1 and 0.12 or 0.16)
        hayReturnPositionError=(root.Position-target.Position).Magnitude
        hayReturnFacingDot=root.CFrame.LookVector:Dot(target.LookVector)
        emit("HAY RETURN",string.format(
            "Check #%d distance=%.3f studs facingDot=%.4f anchored=%s",
            attempt,hayReturnPositionError,hayReturnFacingDot,tostring(root.Anchored)))
        if hayReturnPositionError<=3 and hayReturnFacingDot>=0.96 then
            hayReturnStatus="returned to hay pile"
            break
        end
        hayReturnStatus="server/cinematic reposition or facing drift"
    end
    end -- optional immediate return, only when no server cutscene is running
    if hayReturnStatus=="returned to hay pile" or releaseActiveAtStart then
        -- Reapply the captured camera direction without changing the
        -- working cinematic camera mode or replacing the camera controller.
        -- During the local bypass its RenderStep uses yaw/pitch; update
        -- those inputs rather than fighting RenderStep with a CFrame write.
        local rel=data.cameraRelativeCFrame
        if type(rel)=="table" and #rel==12 then
            local allFinite=true
            for i=1,12 do
                if not finite(rel[i]) then allFinite=false;break end
            end
            if allFinite then
                local okCamera,savedCam=pcall(function()
                    return target*CFrame.new(table.unpack(rel))
                end)
                if okCamera then
                    savedHayCamCF=savedCam
                    local dir=savedCam.LookVector
                    if cameraActive and not cameraReleased then
                        yaw=math.atan2(dir.X,dir.Z)
                        pitch=math.max(-1,math.min(0.85,math.asin(
                            math.max(-1,math.min(1,dir.Y)))))
                        followDistance=math.max(2.0,math.min(10.0,
                            (savedCam.Position-target.Position).Magnitude))
                        hayReturnCameraStatus="bypass camera aim restored"
                    else
                        local liveCamera=Workspace.CurrentCamera
                        if liveCamera then
                            pcall(function() liveCamera.CFrame=savedCam end)
                            hayReturnCameraStatus="camera CFrame set once; native camera may override"
                        end
                    end
                    if P:GetAttribute("Chapter2ReleaseActive")==true
                        and P:GetAttribute("NeedleRoundComplete")~=true
                        and P:GetAttribute("NeedleOwned")~=true then
                        -- The server is still moving the actual avatar
                        -- through its puzzle-release cinematic. Instead
                        -- of following that forced movement, show the
                        -- previously captured hay-pile view until release.
                        -- This is a VISUAL preview, not a server skip.
                        hayPreviewCameraCF=savedCam
                        emit("CUTSCENE","Hay-pile visual preview armed during server-controlled puzzle release; no server timer changed")
                    end
                    emit("HAY RETURN","Camera facing applied: "..hayReturnCameraStatus)
                else
                    hayReturnCameraStatus="saved camera CFrame reconstruction failed"
                end
            end
        end
        if releaseActiveAtStart then
            emit("HAY RETURN","v21 DIAG: view preview only; physical return deferred")
        else
            emit("HAY RETURN","Initial character position and facing matched the saved point.")
        end
    else
        emit("HAY RETURN","Initial teleport not confirmed; monitoring short-lived cinematic snapback.")
    end

    -- The puzzle-release scene still controls position until its replicated
    -- flags clear. v15 spent both snapback retries DURING the cinematic,
    -- causing the game to immediately undo them. Monitor that interval,
    -- but reserve the two corrections for AFTER the release has ended.
    hayReturnMonitorDone=false
    local startedMonitoring=os.clock()
    local nextSampleAt=os.clock()+0.70
    local wasReleaseActive=P:GetAttribute("Chapter2ReleaseActive")==true
        or P:GetAttribute("CutsceneActive")==true
    local sawRelease=wasReleaseActive
    local userMoved=false
    local movementKeys={
        Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
        Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right,
        Enum.KeyCode.Space
    }
    local movementKeySet={}
    for _,key in ipairs(movementKeys) do movementKeySet[key]=true end
    local acceptManualInput=false
    local newManualKeyAfterRelease=nil
    local movementConnection=UserInputService.InputBegan:Connect(function(input)
        -- Inputs held or pressed DURING the cinematic must not cancel
        -- the deferred hay return. Only a fresh post-release keypress
        -- is treated as the player taking over movement.
        if acceptManualInput and movementKeySet[input.KeyCode] then
            newManualKeyAfterRelease=input.KeyCode.Name
        end
    end)
    local function samplePostReturn(stage)
        hayReturnMonitorSamples+=1
        hayReturnFinalDistance=(root.Position-target.Position).Magnitude
        hayReturnFinalFacing=root.CFrame.LookVector:Dot(target.LookVector)
        local cam=Workspace.CurrentCamera
        local cameraType=cam and cam.CameraType.Name or "nil"
        if cam and savedHayCamCF then
            hayReturnFinalCameraDot=cam.CFrame.LookVector:Dot(savedHayCamCF.LookVector)
        end
        local obstructed="unknown"
        if cam then
            local origin=root.Position+Vector3.new(0,1.6,0)
            local toward=cam.CFrame.Position-origin
            if toward.Magnitude>0.45 then
                local params=RaycastParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={C}
                params.RespectCanCollide=true
                local hit=Workspace:Raycast(origin,toward,params)
                if hit and hit.Instance then
                    hayReturnCameraObstructions+=1
                    obstructed=hit.Instance:GetFullName()
                else
                    obstructed="none"
                end
            end
        end
        emit("HAY RETURN",string.format(
            "MONITOR %s #%d distance=%.2f facing=%.3f camera=%s cameraAim=%.3f obstruction=%s cutscene=%s release=%s locked=%s",
            stage,hayReturnMonitorSamples,hayReturnFinalDistance,
            hayReturnFinalFacing,cameraType,hayReturnFinalCameraDot or -1,tostring(obstructed),
            tostring(P:GetAttribute("CutsceneActive")),
            tostring(P:GetAttribute("Chapter2ReleaseActive")),
            tostring(P:GetAttribute("NeedleInputLocked"))))
        return hayReturnFinalDistance
    end
    local lastPostReleaseMoveAt=-math.huge
    local hayCameraHandedOff=false
    local function restorePostReleaseAim(stage)
        if not alive or P.Character~=C or not root.Parent
            or P:GetAttribute("NeedleRoundComplete")==true
            or P:GetAttribute("NeedleOwned")==true
            or P:GetAttribute("Chapter2ReleaseActive")==true
            or P:GetAttribute("CutsceneActive")==true then return end
        if (root.Position-target.Position).Magnitude>4 then return end
        local before=root.CFrame.LookVector:Dot(target.LookVector)
        -- Restore direction only, without moving the avatar a second time.
        if before<0.998 and hayReturnFinalFacingRestores<math.max(1,hayPostReleaseCorrections) then
            root.CFrame=CFrame.new(root.Position)*target.Rotation
            root.AssemblyAngularVelocity=Vector3.zero
            hayReturnFinalFacingRestores+=1
        end
        local cam=Workspace.CurrentCamera
        if cam and not doorBypassActive then
            -- Do not leave a frozen Scriptable camera after the teleport.
            -- Hand native Roblox camera control back to the player's Humanoid.
            local hum=C:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject=hum end
            if savedHayCamCF and not hayCameraHandedOff then
                local desired=savedHayCamCF+(root.Position-target.Position)
                cam.CFrame=desired
                cam.Focus=CFrame.new(desired.Position+desired.LookVector*12)
            end
            cam.CameraType=Enum.CameraType.Custom
            hayCameraHandedOff=true
            pcall(function()
                UserInputService.MouseBehavior=Enum.MouseBehavior.Default
            end)
            hayReturnFinalCameraDot=savedHayCamCF
                and cam.CFrame.LookVector:Dot(savedHayCamCF.LookVector) or nil
            hayReturnCameraStatus="native Custom camera control restored after saved heading"
        end
        emit("HAY RETURN",string.format(
            "POST-RELEASE AIM %s facingBefore=%.4f facingAfter=%.4f cameraDot=%s cameraType=%s",
            tostring(stage),before,root.CFrame.LookVector:Dot(target.LookVector),
            tostring(hayReturnFinalCameraDot or "pending"),
            tostring(cam and cam.CameraType or "nil")))
    end
    local function correctionAfterRelease()
        if not alive or P.Character~=C or not root.Parent
            or P:GetAttribute("NeedleRoundComplete")==true
            or P:GetAttribute("NeedleOwned")==true then return false end
        if P:GetAttribute("Chapter2ReleaseActive")==true
            or P:GetAttribute("CutsceneActive")==true then
            return false
        end
        if root.Anchored then
            hayReturnStatus="post-release root still anchored"
            emit("HAY RETURN","Post-release correction deferred: root still anchored")
            return false
        end
        lastPostReleaseMoveAt=os.clock()
        hayReturnDriftCorrections+=1
        hayPostReleaseCorrections+=1
        hayReturnAttempts+=1
        emit("HAY RETURN",string.format(
            "POST-RELEASE TELEPORT #%d from %.2f studs away; saved hay coordinates",
            hayPostReleaseCorrections,(root.Position-target.Position).Magnitude))
        positionTraceMarkWrite("post-release-"..hayPostReleaseCorrections,root)
        root.CFrame=target
        positionTraceAfterWrite(root)
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        -- One smooth landing: orient once, then return camera control to Roblox.
        task.wait(0.12)
        restorePostReleaseAim("landing")
        samplePostReturn("post-release-correction")
        return true
    end
    local releaseClearedAt=nil
    while alive and P.Character==C and root.Parent
        and os.clock()-startedMonitoring<24.0 do
        task.wait(0.22)
        if P:GetAttribute("NeedleRoundComplete")==true
            or P:GetAttribute("NeedleOwned")==true then
            hayReturnStatus="final ending protected during return"
            break
        end
        local now=os.clock()
        local activeRelease=P:GetAttribute("Chapter2ReleaseActive")==true
            or P:GetAttribute("CutsceneActive")==true
        if activeRelease then sawRelease=true end
        if wasReleaseActive and not activeRelease then
            hayReturnReleaseObserved=true
            releaseClearedAt=now
            hayPreviewCameraCF=nil
            emit("CUTSCENE","Server puzzle-release flags ended; disabling hay visual preview before final teleport")
        end
        wasReleaseActive=activeRelease
        -- Only new key presses after the first verified physical return
        -- mean a player is taking over. During the cinematic, ignore all.
        acceptManualInput=not activeRelease and hayPostReleaseCorrections>0
            and (root.Position-target.Position).Magnitude<=3
        if newManualKeyAfterRelease then
            userMoved=true
            hayReturnStatus="new manual movement after release; stopped auto correction"
            emit("HAY RETURN","New post-release movement key "..newManualKeyAfterRelease..
                " detected; allowing manual control and ending hay corrections.")
            break
        end
        if now>=nextSampleAt or releaseClearedAt==now then
            local d=samplePostReturn(activeRelease and "pre-release" or "after-release")
            if activeRelease and d>8 then
                hayEarlySnapbacks+=1
                hayReturnStatus="waiting for server release; no wasted early correction"
            end
            nextSampleAt=now+1.30
        end
        if not activeRelease and (releaseClearedAt
            or (not sawRelease and now-startedMonitoring>=1.5)) then
            if not releaseClearedAt then releaseClearedAt=now end
            local releasedFor=now-releaseClearedAt
            -- Server camera/character may snap back around one second AFTER
            -- release. Allow 2.2 seconds before the first physical return.
            -- A second return is allowed only after another 1.6s and a
            -- confirmed large snapback (not minor physics position drift).
            local distance=(root.Position-target.Position).Magnitude
            local doFirst=hayPostReleaseCorrections==0 and releasedFor>=2.2
            local doRetry=hayPostReleaseCorrections==1 and releasedFor>=4.0
                and now-lastPostReleaseMoveAt>=1.6 and distance>8
            if distance>3 and (doFirst or doRetry) then
                correctionAfterRelease()
            end
            if releasedFor>=3.0 and (root.Position-target.Position).Magnitude<=3
                and not doorBypassActive and
                (not hayCameraHandedOff or (Workspace.CurrentCamera
                    and Workspace.CurrentCamera.CameraType~=Enum.CameraType.Custom)) then
                restorePostReleaseAim("native-handoff")
            end
            if releasedFor>=4.2 then
                local remaining=samplePostReturn("final-after-release")
                local closeEnough=remaining<=3
                local stableSinceLastMove=now-lastPostReleaseMoveAt>=1.6
                if (closeEnough and stableSinceLastMove)
                    or releasedFor>=6.0 then
                    break
                end
            end
        end
    end
    movementConnection:Disconnect()
    hayPreviewCameraCF=nil
    if not userMoved and alive and P.Character==C and root.Parent then
        if hayReturnFinalDistance==nil then samplePostReturn("monitor-timeout") end
        if hayReturnFinalDistance<=3 then
            hayReturnStatus=hayReturnReleaseObserved
                and "confirmed after server release"
                or "near target; server release not confirmed"
        else
            hayReturnStatus="final position drift; return unconfirmed"
        end
    end
    emit("HAY RETURN","FINAL MONITOR status="..hayReturnStatus..
        " samples="..hayReturnMonitorSamples..
        " preReleaseSnapbacks="..hayEarlySnapbacks..
        " postReleaseCorrections="..hayPostReleaseCorrections..
        " releaseObserved="..tostring(hayReturnReleaseObserved))
    hayReturnMonitorDone=true
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
    if hayPreviewCameraCF
        and player:GetAttribute("Chapter2ReleaseActive")==true
        and player:GetAttribute("NeedleOwned")~=true
        and player:GetAttribute("NeedleRoundComplete")~=true then
        -- Keep the camera pointed at the saved hay-pile view instead of
        -- following server-driven cinematic character repositioning.
        -- Rendering only: actual avatar returns after the release ends.
        cam.CameraType=Enum.CameraType.Scriptable
        cam.CFrame=hayPreviewCameraCF
        cam.Focus=CFrame.new(hayPreviewCameraCF.Position+
            hayPreviewCameraCF.LookVector*12)
        hayPreviewFrames+=1
        return
    end
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
    local viewPosition=root.Position
    if doorBypassActive and puzzleStarted and not puzzleFinished
        and puzzleRoomCameraAnchor
        and (root.Position-puzzleRoomCameraAnchor).Magnitude>30 then
        -- The server's lever cinematic has temporarily relocated the
        -- actual character outside the puzzle room. Show the verified
        -- room until the avatar is back, without faking its position
        -- or changing native progression.
        viewPosition=puzzleRoomCameraAnchor
        puzzleRoomCinematicViewFrames+=1
        if os.clock()-lastPuzzleRoomViewWarning>=2.0 then
            lastPuzzleRoomViewWarning=os.clock()
            emit("CUTSCENE",string.format(
                "LEVER VISUAL BYPASS: character forced %.1f studs away; camera holding verified puzzle-room view",
                (root.Position-puzzleRoomCameraAnchor).Magnitude))
        end
    end
    local target=viewPosition+Vector3.new(0,1.6,0)
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
    if doorBypassActive then
        bypassCamFrames+=1
        -- Keep arrow/WASD movement usable when the game's cinematic
        -- disables normal controls. Do not drive the avatar unless
        -- the user is actually holding a movement key.
        if not UserInputService:GetFocusedTextBox() then
            local function down(key)return UserInputService:IsKeyDown(key) end
            local x=(down(Enum.KeyCode.D) and 1 or 0)-(down(Enum.KeyCode.A) and 1 or 0)
            local z=(down(Enum.KeyCode.W) and 1 or 0)-(down(Enum.KeyCode.S) and 1 or 0)
            if hum and (x~=0 or z~=0) then
                local front=Vector3.new(math.sin(yaw),0,math.cos(yaw))
                local right=Vector3.new(-front.Z,0,front.X)
                local movement=front*z+right*x
                if movement.Magnitude>1 then movement=movement.Unit end
                pcall(function()hum:Move(movement,false)end)
            end
        end
    end
    cam.CFrame=CFrame.lookAt(desired,target,Vector3.yAxis)
    cam.Focus=CFrame.new(target)
    if previousCameraLook and cam.CFrame.LookVector:Dot(previousCameraLook)<0.999 then
        first("cameraMoved","mouse/rotation changed view")
    end
    previousCameraLook=cam.CFrame.LookVector
end


-- v5: lever/door and puzzle cinematics overlap the skippable intro.
-- Waiting for IntroCutsceneFinished *and* CutsceneActive misses them.
-- Main's real bypass is client camera/input/HUD recovery; it does not
-- shorten server timers. Arm bounded windows from confirmed game state.
local function endingProtected()
    if not player then return true end
    if player:GetAttribute("NeedleRoundComplete")==true or
        player:GetAttribute("NeedleOwned")==true then return true end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local ending=pg and pg:FindFirstChild("NeedleEndingUI")
    local results=ending and ending:FindFirstChild("ReturnToLobby",true)
    return ending and ending:IsA("ScreenGui") and ending.Enabled
        and results and results:IsA("GuiObject") and results.Visible or false
end
local function threeLeversConfirmed()
    local F=ReplicatedStorage:FindFirstChild("Puzzles")
    if F and F:GetAttribute("LeverPuzzleSolved")==true then return true end
    for i=1,3 do
        if not (leverResults[i] and leverResults[i].ok) then return false end
    end
    return true
end
restoreBypassVisuals=function()
    for instance,props in pairs(bypassVisuals) do
        if instance.Parent then
            for key,value in pairs(props) do
                pcall(function()instance[key]=value end)
            end
        end
        bypassVisuals[instance]=nil
    end
end
local function hideNonfinalCutsceneVisuals()
    if os.clock()-lastMaskAt<0.16 then return end
    lastMaskAt=os.clock()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local function mask(obj,key)
        local ok,val=pcall(function()return obj[key]end)
        if not ok or type(val)~="number" or val>=1 then return end
        local record=bypassVisuals[obj]
        if not record then record={};bypassVisuals[obj]=record end
        if record[key]==nil then record[key]=val end
        if pcall(function()obj[key]=1 end) then bypassMasks+=1 end
    end
    for _,gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local n=gui.Name:lower()
            if (n=="cutscenefade" or n:find("cutscene",1,true)
                or n:find("cinematic",1,true)
                or n:find("chapter2release",1,true))
                and not n:find("ending",1,true)
                and not n:find("needle",1,true) then
                for _,obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("GuiObject") then
                        mask(obj,"BackgroundTransparency")
                        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                            mask(obj,"ImageTransparency")
                        elseif obj:IsA("TextLabel") or obj:IsA("TextButton")
                            or obj:IsA("TextBox") then
                            mask(obj,"TextTransparency")
                            mask(obj,"TextStrokeTransparency")
                        end
                    elseif obj:IsA("UIStroke") then mask(obj,"Transparency") end
                end
            end
        end
    end
end
local cachedControls=nil
local function restoreBypassInput()
    if os.clock()-lastInputAt<0.10 or endingProtected() then return end
    lastInputAt=os.clock()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local change=false
    if hum then
        if hum.PlatformStand then hum.PlatformStand=false;change=true end
        if hum.Sit then hum.Sit=false;change=true end
        if hum.WalkSpeed<=0 then hum.WalkSpeed=16;change=true end
        if hum.JumpPower<=0 then hum.JumpPower=50;change=true end
    end
    if root and root.Anchored and (player:GetAttribute("CutsceneActive")==true
        or player:GetAttribute("Chapter2ReleaseActive")==true) then
        root.Anchored=false;change=true
    end
    if not cachedControls then
        local ps=player:FindFirstChild("PlayerScripts")
        local module=ps and ps:FindFirstChild("PlayerModule")
        if module then
            local ok,controls=pcall(function()return require(module):GetControls()end)
            if ok then cachedControls=controls end
        end
    end
    if cachedControls and cachedControls.enabled==false then
        pcall(function()cachedControls:Enable()end)
        change=true
    end
    -- Main clears the local input-lock flag during its lever/puzzle
    -- cinematic bypass. v5 restored only Humanoid movement and missed it.
    if player:GetAttribute("NeedleInputLocked")==true then
        pcall(function()player:SetAttribute("NeedleInputLocked",nil)end)
        change=true
        emit("CUTSCENE","Cleared local non-final NeedleInputLocked; cinematic controller may set it again")
    end
    if change then
        bypassInputFixes+=1
        emit("CUTSCENE","Native movement restored during non-final cinematic; count="..bypassInputFixes)
    end
end
local function stopDoorBypass(reason)
    if not doorBypassActive then return end
    doorBypassActive=false
    doorBypassFinished=true
    doorCameraReleasedAt=seconds()
    releaseCamera(reason or "non-final cinematic ended")
    restoreBypassVisuals()
    first("doorBypassFinished",reason)
    emit("CUTSCENE","BYPASS RELEASED: "..tostring(reason))
end
local function updateDoorBypass(done,cutscene,root)
    if not player then return end
    if endingProtected() then
        bypassFinalProtected=true
        if doorBypassActive then stopDoorBypass("final needle ending protected") end
        return
    end
    if not done or not root or not threeLeversConfirmed() then return end
    local now=os.clock()
    local release=player:GetAttribute("Chapter2ReleaseActive")==true
    local stage=(now<puzzleBypassUntil or release) and "THREE PUZZLES"
        or (now<leverBypassUntil and "THREE LEVERS" or nil)
    if not stage then
        if doorBypassActive then stopDoorBypass("bounded cinematic grace expired") end
        return
    end
    if doorBypassActive then
        if now-lastBypassAuditAt>=2.5 then
            lastBypassAuditAt=now
            local liveCamera=Workspace.CurrentCamera
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            emit("CUTSCENE",string.format(
                "BYPASS AUDIT stage=%s cameraType=%s cameraActive=%s renderedFrames=%d rootAnchored=%s inputLocked=%s controlsEnabled=%s serverReleaseActive=%s",
                tostring(stage),tostring(liveCamera and liveCamera.CameraType),
                tostring(cameraActive),bypassCamFrames,
                tostring(root and root.Anchored),
                tostring(player:GetAttribute("NeedleInputLocked")),
                tostring(hum and hum.WalkSpeed>0),
                tostring(release)))
        end
        if stage~=bypassStage then
            bypassStage=stage
            emit("CUTSCENE","Stage changed to "..stage)
        end
        restoreBypassInput()
        hideNonfinalCutsceneVisuals()
        return
    end
    doorBypassSeen=true
    doorBypassFinished=false
    doorBypassActive=true
    doorBypassStartedAt=seconds()
    bypassStage=stage
    cameraReleased=false
    enableCamera(root)
    doorBypassCamera=cameraActive
    first("doorBypassStarted","non-final cinematic local camera/input bypass enabled")
    emit("CUTSCENE","BYPASS ENABLED: "..stage..
        " after intro Skip; playable camera and input, server timer unchanged")
    restoreBypassInput()
    hideNonfinalCutsceneVisuals()
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
                    for _,key in ipairs({"CutsceneActive","IntroCutsceneFinished",
                        "Chapter2ReleaseActive","NeedleInputLocked","NeedleOwned",
                        "NeedleRoundComplete"}) do
                        hook(player:GetAttributeChangedSignal(key),function()
                            local value=player:GetAttribute(key)
                            changed(key,value)
                            if value==true then
                                if key=="Chapter2ReleaseActive" then
                                    puzzleBypassUntil=math.max(puzzleBypassUntil,os.clock()+11)
                                    emit("CUTSCENE","Puzzle-release flag event caught; local bypass grace extended")
                                elseif key=="CutsceneActive" and firstTimes.threeLeversConfirmed
                                    and player:GetAttribute("IntroCutsceneFinished")==true
                                    and player:GetAttribute("NeedleOwned")~=true
                                    and player:GetAttribute("NeedleRoundComplete")~=true then
                                    local phase=puzzleFinished and "puzzles" or "levers"
                                    if puzzleFinished then
                                        puzzleBypassUntil=math.max(puzzleBypassUntil,os.clock()+9)
                                    else
                                        leverBypassUntil=math.max(leverBypassUntil,os.clock()+7)
                                    end
                                    emit("CUTSCENE","Immediate short CutsceneActive event caught after intro: "..phase)
                                end
                            end
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
            -- Local non-final recovery is armed on 3/3 confirmed levers
            -- and 3/3 puzzles; it does not require a long-lived cutscene flag.
            if introCompletedAt then
                updateDoorBypass(done,cutscene,root)
            end
            if not doorCutsceneMayOverlapIntro and cutscene and not done
                and firstTimes.threeLeversConfirmed then
                doorCutsceneMayOverlapIntro=true
                emit("DOOR","Lever cutscene may overlap intro; pre-Skip camera already active. No distinct post-intro cutscene established.")
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
                not doorBypassActive and
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
            and hayReturnMonitorDone
            and not doorBypassActive
            and os.clock()>=leverBypassUntil and os.clock()>=puzzleBypassUntil then
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
]==========]
local __BEYY_CH2_V22_STARTED = false
local __BEYY_CH2_V22_FAILED = false
local function __BEYY_CH2_V22_SOLVING()
    if not __BEYY_CH2_V22_STARTED or __BEYY_CH2_V22_FAILED then return false end
    local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Puzzles")
    if not folder then return true end
    return folder:GetAttribute("LeverPuzzleSolved") ~= true
        or (tonumber(folder:GetAttribute("SolvedPuzzleCount")) or 0) < 3
end
local function __BEYY_CH2_V22_STOP()
    local env = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then env = result end
    end
    local stop = env.__BEYY_CH2_COMBO_STOP
    if type(stop) == "function" then pcall(stop, "BeyyHub unload / user stop") end
    __BEYY_CH2_V22_STARTED = false
end
local function __BEYY_CH2_V22_START()
    if __BEYY_CH2_V22_STARTED then return true end
    if __BEYY_CH2_V22_FAILED then return false end
    local compiled, err = loadstring(__BEYY_CH2_V22_SOURCE)
    if type(compiled) ~= "function" then
        __BEYY_CH2_V22_FAILED = true
        warn("[BeyyHub Chapter2] Embedded v22 failed compilation: " .. tostring(err))
        return false
    end
    __BEYY_CH2_V22_STARTED = true
    task.spawn(function()
        local ok, result = pcall(compiled)
        if not ok then
            __BEYY_CH2_V22_FAILED = true
            __BEYY_CH2_V22_STARTED = false
            warn("[BeyyHub Chapter2] Embedded v22 runtime error: " .. tostring(result))
        end
    end)
    print("[BeyyHub Chapter2] Embedded standalone v22 started; no hay return teleport")
    return true
end
__BEYY_CH2_V22_START()

local CACHE_FOLDER = "BeyyHub"

pcall(function()
    if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(CACHE_FOLDER)) then
        makefolder(CACHE_FOLDER)
    end
end)

local function safeRead(path)
    if type(readfile) ~= "function" then return nil end
    local ok, content = pcall(readfile, path)
    if ok and type(content) == "string" and #content > 0 then return content end
    return nil
end

local function safeWrite(path, content)
    if not content or #content == 0 or type(writefile) ~= "function" then return false end
    local ok, result = pcall(writefile, path, content)
    return ok and result ~= false
end

local __BEYY_CONFIG_PATH = "WindUI/BeyyHub/config/"
local __BEYY_CONFIG_TELEPORT_KEY = "BeyyHub_ActiveConfig_v103"
local __BEYY_CONFIG_HTTP = game:GetService("HttpService")
local __BEYY_CONFIG_TELEPORT = game:GetService("TeleportService")
local __BEYY_CONFIG_PLAYER_FOLDER = "__BeyyHubSessionConfigV103"
local __beyyConfigEnv = _G
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then __beyyConfigEnv = env end
end
if type(__beyyConfigEnv.__BEYY_CONFIG_SESSION_V103) ~= "table" then
    __beyyConfigEnv.__BEYY_CONFIG_SESSION_V103 = {}
end
local __beyyConfigSession = __beyyConfigEnv.__BEYY_CONFIG_SESSION_V103
local function __beyyConfigDecode(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local ok, result = pcall(function() return __BEYY_CONFIG_HTTP:JSONDecode(raw) end)
    if ok and type(result) == "table" and type(result.__elements or result) == "table" then return result end
    return nil
end
local function __beyyPlayerConfigFolder(create)
    local player = game:GetService("Players").LocalPlayer
    if not player then return nil end
    local folder = player:FindFirstChild(__BEYY_CONFIG_PLAYER_FOLDER)
    if folder and not folder:IsA("Folder") then return nil end
    if not folder and create then
        folder = Instance.new("Folder")
        folder.Name = __BEYY_CONFIG_PLAYER_FOLDER
        folder.Parent = player
    end
    return folder
end
local function __beyyPlayerConfigValue(name, create)
    local folder = __beyyPlayerConfigFolder(create)
    if not folder then return nil end
    local value = folder:FindFirstChild(name)
    if value and not value:IsA("StringValue") then return nil end
    if not value and create then
        value = Instance.new("StringValue")
        value.Name = name
        value.Parent = folder
    end
    return value
end
local function __beyyReadConfig(name)
    if type(name) ~= "string" or not name:match("^[%w_%-%s]+$") then return nil, "invalid name" end
    local live = __beyyPlayerConfigValue(name, false)
    if live and __beyyConfigDecode(live.Value) then
        __beyyConfigSession[name] = live.Value
        return live.Value, "player-session"
    end
    local memory = __beyyConfigSession[name]
    if __beyyConfigDecode(memory) then return memory, "executor-session" end
    local ok, packet = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(__BEYY_CONFIG_TELEPORT_KEY)
    end)
    if ok and type(packet) == "table" and packet.name == name and __beyyConfigDecode(packet.json) then
        __beyyConfigSession[name] = packet.json
        return packet.json, "teleport"
    end
    local disk = safeRead(__BEYY_CONFIG_PATH .. name .. ".json")
    if __beyyConfigDecode(disk) then return disk, "disk" end
    return nil, "unavailable"
end
local function __beyyActiveConfigName()
    local folder = __beyyPlayerConfigFolder(false)
    local active = folder and folder:GetAttribute("ActiveName")
    if type(active) == "string" and active:match("^[%w_%-%s]+$") then return active end
    local ok, packet = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(__BEYY_CONFIG_TELEPORT_KEY)
    end)
    if ok and type(packet) == "table" and type(packet.name) == "string"
        and packet.name:match("^[%w_%-%s]+$") and __beyyConfigDecode(packet.json) then
        return packet.name
    end
    local disk = safeRead("BeyyHub/active_config.txt")
    if type(disk) == "string" and disk:match("^[%w_%-%s]+$") then return disk end
    return "default"
end
local function __beyyRememberConfig(name, raw)
    if not __beyyConfigDecode(raw) then return false, false end
    __beyyConfigSession[name] = raw
    local playerVerified = false
    local okPlayer, errorPlayer = pcall(function()
        local entry = __beyyPlayerConfigValue(name, true)
        if not entry then return end
        entry.Value = raw
        local folder = __beyyPlayerConfigFolder(false)
        if not folder then return end
        folder:SetAttribute("ActiveName", name)
        playerVerified = entry.Parent == folder and entry.Value == raw
            and folder:GetAttribute("ActiveName") == name
    end)
    if not okPlayer then
        warn("[BeyyHub Config] Player-session save failed: " .. tostring(errorPlayer))
    end
    local teleportOK, teleportError = pcall(function()
        __BEYY_CONFIG_TELEPORT:SetTeleportSetting(__BEYY_CONFIG_TELEPORT_KEY, {name = name, json = raw})
    end)
    if not teleportOK then
        warn("[BeyyHub Config] Teleport persistence unavailable: " .. tostring(teleportError))
    end
    return playerVerified, teleportOK
end
local function __beyySameJSON(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not __beyySameJSON(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local __beyyInitialConfig = __beyyReadConfig(__beyyActiveConfigName())

if _G.__BEYY_HUB_LOADED then
    pcall(function()
        if type(_G.__BEYY_HUB_CLEANUP) == "function" then _G.__BEYY_HUB_CLEANUP() end
    end)
    task.wait(0.5)
end
_G.__BEYY_HUB_LOADED = true

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local waited = 0
    while not Players.LocalPlayer and waited < 10 do
        task.wait(0.05)
        waited = waited + 0.05
    end
    LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
    warn("[BeyyHub] LocalPlayer never became available.")
    return
end

print("[BeyyHub] LocalPlayer ready: ".. LocalPlayer.Name)

local BEYY_PLACE_IDS = {
    Lobby = 77108422251420,
    Chapter1 = 108628039999641,
    Chapter2 = 83445806734780,
    Chapter3 = 82626725163709,
}
local BEYY_CHAPTER = "Unknown"
for chapter, placeId in pairs(BEYY_PLACE_IDS) do
    if game.PlaceId == placeId then
        BEYY_CHAPTER = chapter
        break
    end
end
print(string.format("[BeyyHub] Place %s -> %s", tostring(game.PlaceId), BEYY_CHAPTER))


do
    local hubUnloaded = false
    local beyyAntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if hubUnloaded then return end
        pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
    local hubWindow
    local hubNativeUI
    local hubRestoreAction = nil
    local hubCursorCleanup = nil
    _G.__BEYY_HUB_CLEANUP = function()
        hubUnloaded = true
        __BEYY_CH2_V22_STOP()
        beyyAntiAfkConnection:Disconnect()
        if hubRestoreAction then pcall(hubRestoreAction) end
        if hubCursorCleanup then pcall(hubCursorCleanup) end
        if hubWindow then pcall(function() hubWindow:Destroy() end) end
    end
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
            if type(makefolder)=="function" then
                for _,path in ipairs({"WindUI","WindUI/"..folder,manager.Path}) do
                    pcall(function() if type(isfolder)~="function" or not isfolder(path) then makefolder(path) end end)
                end
            end
            function manager:AllConfigs()
                local names={}
                if type(listfiles)=="function" then
                    local ok,files=pcall(listfiles,self.Path)
                    if ok then for _,path in ipairs(files) do local name=path:match("([^/\\]+)%.json$"); if name then table.insert(names,name) end end end
                end
                return names
            end
            function manager:CreateConfig(name)
                assert(type(name)=="string" and name~="" and not name:find("[/\\]"),"Invalid config name")
                local cfg={Path=self.Path..name..".json",Elements={},CustomData={},Version=1.2,AutoLoad=false}
                function cfg:Register(key,el) self.Elements[key]=el end
                function cfg:Save()
                    assert(type(writefile)=="function","Config saving requires writefile")
                    local saved={__version=self.Version,__elements={},__custom=self.CustomData,__autoload=self.AutoLoad}
                    for key,el in pairs(self.Elements) do
                        local value=el.Value
                        if el.__type=="Slider" then value=value.Default end
                        saved.__elements[key]={__type=el.__type,value=value}
                    end
                    writefile(self.Path,http:JSONEncode(saved))
                    return saved
                end
                function cfg:Load()
                    if type(readfile)~="function" then return false,"Config loading requires readfile" end
                    local ok,data=pcall(function() return http:JSONDecode(readfile(self.Path)) end)
                    if not ok or type(data)~="table" then return false,"Failed to read config" end
                    for key,entry in pairs(data.__elements or data) do
                        local el=self.Elements[key]
                        if el and type(entry)=="table" and entry.__type==el.__type then
                            if el.__type=="Dropdown" then el:Select(entry.value) else el:Set(entry.value) end
                        end
                    end
                    self.CustomData=data.__custom or {}
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
            local gui=node("ScreenGui",parent,{Name="BeyyNativeHub",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
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
            local bind="BeyyNativeCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
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
            w.ConfigManager=configManager(options.Folder or "BeyyHub")
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
    hubNativeUI = createNativeUI()
    hubWindow = hubNativeUI:CreateWindow({
        Title = " Beyy Hub Main ",
        Author = "by beyy",
        Icon = "search",
        Folder = "BeyyHub",
        Size = UDim2.fromOffset(640, 480),
        Theme = "Dark",
        Transparent = false,
        Resizable = true,
        SideBarWidth = 200,
        HideSearchBar = true,
        OpenButton = { Enabled = false },
    })
    print(("[BeyyHub Startup] %s window constructed after %.2fs in module"):format(
        BEYY_CHAPTER, os.clock() - __BEYY_BOOT_T0))
    pcall(function() hubWindow:SetToggleKey(Enum.KeyCode.RightControl) end)
    pcall(function() hubWindow:EditOpenButton({ Enabled = false }) end)

    local function hideNonFarmMenu()
        if not hubUnloaded and hubWindow and not hubWindow.Closed then
            pcall(function() hubWindow:Close() end)
        end
    end
    hideNonFarmMenu()

    if BEYY_CHAPTER == "Chapter2" or BEYY_CHAPTER == "Chapter3" then
        hubCursorCleanup = function() hubWindow:Close() end
    end

    local overviewTab = hubWindow:Tab({ Title = "Overview & Settings", Icon = "house" })
    overviewTab:Section({ Title = "Detected chapter" })
    overviewTab:Paragraph({
        Title = BEYY_CHAPTER .. " (Place ID " .. tostring(game.PlaceId) .. ")",
        Desc = "Farming and Inventory are available in every chapter. Right Ctrl opens or closes the menu.",
    })
    overviewTab:Section({ Title = "Shared menu" })
    overviewTab:Keybind({
        Title = "Menu keybind", Value = "RightControl",
        Callback = function(value)
            local key = typeof(value) == "EnumItem" and value or Enum.KeyCode[value]
            if key then pcall(function() hubWindow:SetToggleKey(key) end) end
        end,
    })
    overviewTab:Button({
        Title = "Unload Hub",
        Callback = function() pcall(_G.__BEYY_HUB_CLEANUP) end,
    })

    local Registry = {}
    local autoCutsceneEnableAfterLevers
    local autoCutsceneDisableAfterHandIn
    local cutscenePlayable = false
    local cutsceneBypassRefresh = nil
    local gemCutsceneCameraAim = nil
    local autoCutsceneSignals = {}
    local sharedFarmPuzzleBusy = function() return false end
    local keyPuzzleCameraBusy = function() return sharedFarmPuzzleBusy() end
    local postPuzzleKeyPriority = false
    local keyObjectiveLatched = false
    local finalEndingProtected = false
    local puzzleReleaseObserved = LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
    local leverBypassUntil = 0
    local puzzleBypassUntil = 0
    local keyObjectivePhase = function() return keyObjectiveLatched end
    local sharedFarmDefaults = {
        AutoPickHay=false, AutoCollectDroppedHay=false, AutoCollectGems=false, CollectInterval=0.5,
        AutoSellHay=false, SellThreshold=25, SellOnlyIfFull=false,
        AutoUseTNT=false, AutoUsePitchfork=false, AutoDeployDrone=false,
        TntLightCooldown=0, TntThrowDelay=0.4,
        AutoUseVacuum=false, VacuumHotbarSlot=5, ToolInterval=0.5,
        AutoFindNeedle=false, AutoPickupNeedle=false, AutoHandInNeedle=false, NeedleInterval=1,
        AutoBuyTools=false, BuyToolsList={"Pitchfork"}, BuyInterval=1,
        UpgBagSize=false, UpgExtraTake=false, UpgGemValue=false, UpgHayValue=false, PermInterval=0.5,
        UpgCapacity=false, UpgHandSpeed=false, UpgHandGrab=false, UpgHandHold=false,
        UpgTntLuck=false, UpgTntCooldown=false, UpgTntPower=false,
        UpgPitchCooldown=false, UpgPitchHold=false, UpgPitchSweep=false,
        UpgDroneSpeed=false, UpgDroneGrab=false, UpgDroneCapacity=false,
        UpgVacPower=false, UpgVacCooling=false, UpgVacRuntime=true,
    }
    local sharedFarmState = {}
    for key, value in pairs(sharedFarmDefaults) do sharedFarmState[key] = value end
    local sharedFarmPath = CACHE_FOLDER .. "/farming_inventory_shared.json"
    local httpService = game:GetService("HttpService")
    local function importSharedFarmSettings()
        local raw = safeRead(sharedFarmPath)
        if not raw then return end
        local ok, decoded = pcall(function() return httpService:JSONDecode(raw) end)
        if not ok or type(decoded) ~= "table" then return end
        local sourceSettings = decoded.__elements or decoded
        for key, default in pairs(sharedFarmDefaults) do
            local value = sourceSettings[key]
            if type(value) == "table" and value.__type then value = value.value end
            if type(default) == "boolean" and type(value) == "boolean" then
                sharedFarmState[key] = value
            elseif type(default) == "number" and type(value) == "number" then
                sharedFarmState[key] = value
            elseif type(default) == "table" and type(value) == "table" then
                sharedFarmState[key] = value
            end
        end
    end
    importSharedFarmSettings()
    -- Restore enabled tool toggles before workers start, even when Solara
    -- cannot read the separate shared-farming disk file.
    local farmTeleportKey = "BeyyHub_FarmTools_v103"
    local configSnapshot = __beyyConfigDecode(__beyyInitialConfig)
    local configElements = configSnapshot and (configSnapshot.__elements or configSnapshot)
    if type(configElements) == "table" then
        for key, default in pairs(sharedFarmDefaults) do
            local entry = configElements[key]
            local value = type(entry) == "table" and entry.__type and entry.value or entry
            if type(value) == type(default) then sharedFarmState[key] = value end
        end
    end
    local teleportOK, farmTeleportState = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(farmTeleportKey)
    end)
    if teleportOK and type(farmTeleportState) == "table" then
        for key, default in pairs(sharedFarmDefaults) do
            local value = farmTeleportState[key]
            if type(value) == type(default) then sharedFarmState[key] = value end
        end
    end
    print("[BeyyHub Tools] Restored state: TNT=" .. tostring(sharedFarmState.AutoUseTNT) ..
        " Pitchfork=" .. tostring(sharedFarmState.AutoUsePitchfork) ..
        " Drone=" .. tostring(sharedFarmState.AutoDeployDrone) ..
        " Vacuum=" .. tostring(sharedFarmState.AutoUseVacuum))
    local function saveSharedFarmSettings()
        pcall(function() safeWrite(sharedFarmPath, httpService:JSONEncode(sharedFarmState)) end)
        pcall(function() __BEYY_CONFIG_TELEPORT:SetTeleportSetting(farmTeleportKey, sharedFarmState) end)
    end
    local farmingSection = hubWindow:Section({ Title = "Farming", Icon = "wheat", Opened = true })
    local collectingTab = farmingSection:Tab({ Title = "Collecting", Icon = "wheat" })
    local sellingTab = farmingSection:Tab({ Title = "Selling", Icon = "coins" })
    local toolsTab = farmingSection:Tab({ Title = "Tools", Icon = "hammer" })
    local needleTab = farmingSection:Tab({ Title = "Needle", Icon = "search" })
    local inventorySection = hubWindow:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
    local shopTab = inventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
    local upgradesTab = inventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
    local function farmToggle(tab, key, title, desc)
        local element = tab:Toggle({
            Title=title, Desc=desc, Value=sharedFarmState[key],
            Callback=function(enabled)
                sharedFarmState[key] = enabled == true
                saveSharedFarmSettings()
            end,
        })
        Registry[key] = element
        return element
    end
    local function farmSlider(tab, key, title, low, high, step, desc)
        local element = tab:Slider({
            Title=title, Desc=desc, Step=step,
            Value={Min=low, Max=high, Default=sharedFarmState[key]},
            Callback=function(value)
                sharedFarmState[key] = tonumber(value) or sharedFarmDefaults[key]
                saveSharedFarmSettings()
            end,
        })
        Registry[key] = element
        return element
    end
    collectingTab:Section({ Title="Resource Collecting" })
    farmToggle(collectingTab,"AutoPickHay","Auto Pick Hay")
    farmToggle(collectingTab,"AutoCollectDroppedHay","Auto Collect Dropped Hay")
    farmToggle(collectingTab,"AutoCollectGems","Auto Collect Gems")
    farmSlider(collectingTab,"CollectInterval","Loop Interval (s)",0.1,3,0.1)
    sellingTab:Section({ Title="Selling" })
    farmToggle(sellingTab,"AutoSellHay","Auto Sell Hay")
    farmSlider(sellingTab,"SellThreshold","Sell When Hay >=",1,250,1)
    farmToggle(sellingTab,"SellOnlyIfFull","Only Sell If Full")
    toolsTab:Section({ Title="Auto Tool Usage" })
    toolsTab:Paragraph({ Title="Tools operate when the chapter supplies the required hay and tool remotes." })
    farmToggle(toolsTab,"AutoUseTNT","Auto Use TNT")
    farmSlider(toolsTab,"TntLightCooldown","TNT Light Cooldown (s)",0,60,0.05)
    farmSlider(toolsTab,"TntThrowDelay","TNT Throw Delay After Lighting (s)",0,5,0.05)
    farmToggle(toolsTab,"AutoUsePitchfork","Auto Use Pitchfork")
    farmToggle(toolsTab,"AutoDeployDrone","Auto Deploy Drone")
    farmToggle(toolsTab,"AutoUseVacuum","Auto Use Vacuum (live heat + cooldown)",
        "Releases suction during menus, cutscenes and needle interactions.")
    farmSlider(toolsTab,"VacuumHotbarSlot","Vacuum Hotbar Slot (fallback)",1,9,1)
    farmSlider(toolsTab,"ToolInterval","Tool Interval (s)",0.2,5,0.1)
    needleTab:Section({ Title="Needle (TOP PRIORITY)" })
    needleTab:Paragraph({ Title="When a needle is exposed, harvesting pauses automatically." })
    farmToggle(needleTab,"AutoFindNeedle","Auto Find Needle","Also picks up an exposed key automatically (no separate pickup toggle required).")
    farmToggle(needleTab,"AutoPickupNeedle","Auto Pick Up Needle")
    local pickupStatus = needleTab:Paragraph({ Title="Key / Needle Pickup Status", Desc="Waiting for the next pickup scan." })
    local lastPickupStatus
    local function setPickupStatus(message)
        if message == lastPickupStatus then return end
        lastPickupStatus = message
        pcall(function() pickupStatus:SetDesc(message) end)
    end
    farmToggle(needleTab,"AutoHandInNeedle","Auto Hand In Needle")
    farmSlider(needleTab,"NeedleInterval","Needle Scan Interval (s)",0.2,3,0.1)
    shopTab:Section({ Title="Purchasing" })
    Registry.BuyToolsList = shopTab:Dropdown({
        Title="Buy Tools Selection",
        Values={"Pitchfork","TNT","Drone","Infinite Bag","Capacity Bag"},
        Value=sharedFarmState.BuyToolsList, Multi=true, AllowNone=true,
        Callback=function(value)
            sharedFarmState.BuyToolsList=value
            saveSharedFarmSettings()
        end,
    })
    farmToggle(shopTab,"AutoBuyTools","Auto Buy Selected Tools")
    farmSlider(shopTab,"BuyInterval","Buy Interval (s)",0.5,5,0.1)
    upgradesTab:Section({ Title="Permanent (Gems)" })
    farmToggle(upgradesTab,"UpgBagSize","Auto Upgrade Bag Size")
    farmToggle(upgradesTab,"UpgExtraTake","Auto Upgrade Hand Grab Amount")
    farmToggle(upgradesTab,"UpgGemValue","Auto Upgrade Gem Value")
    farmToggle(upgradesTab,"UpgHayValue","Auto Upgrade Hay Value")
    farmSlider(upgradesTab,"PermInterval","Permanent Loop (s)",0.5,5,0.1)
    upgradesTab:Section({ Title="Hand (Cash)" })
    farmToggle(upgradesTab,"UpgHandSpeed","Auto Hand Speed")
    farmToggle(upgradesTab,"UpgHandGrab","Auto Hand Grasp")
    farmToggle(upgradesTab,"UpgHandHold","Auto Hand Hold")
    upgradesTab:Section({ Title="TNT (Cash)" })
    farmToggle(upgradesTab,"UpgTntLuck","Auto TNT Lucky Blast")
    farmToggle(upgradesTab,"UpgTntCooldown","Auto TNT Cooldown")
    farmToggle(upgradesTab,"UpgTntPower","Auto TNT Power")
    upgradesTab:Section({ Title="Pitchfork (Cash)" })
    farmToggle(upgradesTab,"UpgPitchCooldown","Auto Pitchfork Cooldown")
    farmToggle(upgradesTab,"UpgPitchHold","Auto Pitchfork Hold")
    farmToggle(upgradesTab,"UpgPitchSweep","Auto Pitchfork Sweep")
    upgradesTab:Section({ Title="Drone (Cash)" })
    farmToggle(upgradesTab,"UpgDroneSpeed","Auto Drone Speed")
    farmToggle(upgradesTab,"UpgDroneGrab","Auto Drone Grasp")
    farmToggle(upgradesTab,"UpgDroneCapacity","Auto Drone Capacity")
    upgradesTab:Section({ Title="Vacuum (Cash)" })
    farmToggle(upgradesTab,"UpgVacPower","Auto Vacuum Power")
    farmToggle(upgradesTab,"UpgVacCooling","Auto Vacuum Cooling")
    farmToggle(upgradesTab,"UpgVacRuntime","Auto Vacuum Runtime")
    upgradesTab:Section({ Title="Capacity (Cash)" })
    farmToggle(upgradesTab,"UpgCapacity","Auto Upgrade Carry Capacity")

    local needleFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local sharedGameConfig, sharedUpgradeConfig
    if needleFolder then
        pcall(function() sharedGameConfig=require(needleFolder:WaitForChild("Config",2)) end)
        pcall(function()
            local shared=ReplicatedStorage:FindFirstChild("Shared")
            local configs=shared and shared:FindFirstChild("Configs")
            local module=configs and configs:FindFirstChild("UpgradeConfig")
            if module then sharedUpgradeConfig=require(module) end
        end)
    end
    local function farmRemote(name)
        local folder=ReplicatedStorage:FindFirstChild("NeedleHaystack")
        local result=folder and folder:FindFirstChild(name)
        return result and result:IsA("RemoteEvent") and result or nil
    end
    local function sendFarmRemote(name,...)
        local remote=farmRemote(name)
        if not remote then return false end
        local args=table.pack(...)
        return pcall(function() remote:FireServer(table.unpack(args,1,args.n)) end)
    end
    local function farmRoot()
        local character=LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end
    local function farmBlocked()
        return hubUnloaded or BEYY_CHAPTER=="Lobby"
            or (BEYY_CHAPTER=="Chapter2" and (sharedFarmPuzzleBusy() or keyObjectivePhase()))
            or LocalPlayer:GetAttribute("NeedleInputLocked")==true
            or LocalPlayer:GetAttribute("CutsceneActive")==true
            or LocalPlayer:GetAttribute("HintViewerOpen")==true
    end
    local function keyInteractionBlocked()
        -- Release flags are normal while the exposed Chapter 2 key is ready.
        -- Keep lever/colour camera control and hint-viewer safety intact.
        local ready = BEYY_CHAPTER=="Chapter2" and keyObjectivePhase()
        return hubUnloaded or BEYY_CHAPTER=="Lobby" or keyPuzzleCameraBusy()
            or (not ready and LocalPlayer:GetAttribute("NeedleInputLocked")==true)
            or (not ready and LocalPlayer:GetAttribute("CutsceneActive")==true)
            or (not ready and LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true)
            or LocalPlayer:GetAttribute("HintViewerOpen")==true
    end
    local cachedExposedNeedle = nil
    local nextNeedleFullScanAt = 0
    local lastKeyIdWarningAt = -math.huge
    local function keyHayId(part)
        if not part then return nil end
        local value = tonumber(part:GetAttribute("HayId"))
        if value ~= nil then return value end
        local parent = part.Parent
        if parent and parent:IsA("Model") then
            return tonumber(parent:GetAttribute("HayId"))
        end
        return nil
    end
    local function exposedNeedle()
        local rootFolder=Workspace:FindFirstChild("NeedleObjectiveServer")
        local folder=rootFolder
        local cached=cachedExposedNeedle
        if folder and cached and cached.Parent and cached:IsDescendantOf(folder) then
            local hidden=cached:GetAttribute("HIDDEN_WITHIN")
            if cached:GetAttribute("IsNeedleObjective")==true
                and (hidden == nil or hidden == false)
                and keyHayId(cached) ~= nil then
                return cached
            end
        end
        local now=os.clock()
        if now < nextNeedleFullScanAt then return nil end
        nextNeedleFullScanAt=now+(BEYY_CHAPTER=="Chapter2" and 0.01 or 0.14)
        cachedExposedNeedle=nil
        if not folder then return nil end
        for _,item in ipairs(folder:GetDescendants()) do
            if item:IsA("BasePart") and item:GetAttribute("IsNeedleObjective")==true then
                local hidden=item:GetAttribute("HIDDEN_WITHIN")
                if hidden == nil or hidden == false then
                    if keyHayId(item) ~= nil then
                        cachedExposedNeedle=item
                        return item
                    elseif now - lastKeyIdWarningAt >= 5 then
                        lastKeyIdWarningAt = now
                        print("[BeyyHub Key] Visible objective found; waiting for numeric HayId replication")
                    end
                end
            end
        end
    end
    keyObjectivePhase = function()
        if BEYY_CHAPTER~="Chapter2" then return false end
        -- Pending key hand-in stays prioritized even after bypass shutdown.
        if keyObjectiveLatched then return true end
        if finalEndingProtected then return false end
        -- Completed puzzles do NOT mean the key has emerged yet. Continue
        -- tool use to expose it; only preempt tools once exposed/owned.
        if (postPuzzleKeyPriority or puzzleReleaseObserved
            or LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true)
            and (LocalPlayer:GetAttribute("NeedleOwned")==true or exposedNeedle()~=nil) then
            postPuzzleKeyPriority = true
            keyObjectiveLatched = true
            print("[BeyyHub Key] Objective exposed/owned; pausing tools for immediate pickup and hand-in")
            return true
        end
        return false
    end
    local needleBusy=false
    local function pickupRequested()
        return sharedFarmState.AutoFindNeedle == true or sharedFarmState.AutoPickupNeedle == true
            or keyObjectivePhase()
    end
    local function handInRequested()
        return sharedFarmState.AutoHandInNeedle == true or keyObjectivePhase()
    end
    local function needlePriority()
        if needleBusy or keyObjectivePhase() then return true end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then
            return sharedFarmState.AutoHandInNeedle or sharedFarmState.AutoPickupNeedle
        end
        return pickupRequested() and exposedNeedle()~=nil
    end
    -- Tool remotes do not need the camera/mouse during Number and Picture.
    -- Full farmBlocked() includes allPuzzlesRunning, so auto-start otherwise
    -- prevents tools from EVER running before the key phase.
    local function toolBlockReason()
        if hubUnloaded or BEYY_CHAPTER=="Lobby" then return "hub inactive" end
        if BEYY_CHAPTER=="Chapter2" then
            if finalEndingProtected then return "final ending" end
            if LocalPlayer:GetAttribute("IntroCutsceneFinished")~=true then return "intro" end
            if keyPuzzleCameraBusy() then return "lever/colour camera" end
            if keyObjectivePhase() or needleBusy or LocalPlayer:GetAttribute("NeedleOwned")==true
                or needlePriority() then return "exposed key" end
            if LocalPlayer:GetAttribute("HintViewerOpen")==true then return "hint viewer" end
            -- CutsceneActive / Chapter2ReleaseActive are not themselves a
            -- reason to block remote tools while the key is still hidden.
            -- The lever/colour controllers and actual key pickup are protected.
            return nil
        end
        if farmBlocked() or needlePriority() then return "gameplay blocked" end
        return nil
    end
    -- Share the hay-list snapshot between nearby hay search and tool workers.
    -- An expired entry is ignored until refresh; no stale entry is interacted
    -- with because Parent/attribute checks below are still live.
    local hayChildrenSnapshot, haySnapshotFolder = nil, nil
    local nextHaySnapshotAt = -math.huge
    local recentKeyHayAttempts = {}
    local function closestInFolder(folderName,idName,limit,avoidRecent)
        local folder=Workspace:FindFirstChild(folderName)
        local root=farmRoot()
        if not folder or not root then return nil,nil end
        local now=os.clock()
        local children
        if folderName=="HaystackClient" then
            if haySnapshotFolder~=folder or now>=nextHaySnapshotAt then
                haySnapshotFolder=folder
                hayChildrenSnapshot=folder:GetChildren()
                nextHaySnapshotAt=now+0.65
            end
            children=hayChildrenSnapshot
        else
            children=folder:GetChildren()
        end
        local best,bestId,bestSquared=nil,nil,limit*limit
        local origin=root.Position
        for _,obj in ipairs(children) do
            if obj.Parent==folder then
                local part=obj:IsA("BasePart") and obj or
                    (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)))
                if part and part.Parent then
                    local id=part:GetAttribute(idName) or obj:GetAttribute(idName)
                    if idName=="Dropped" then id=obj end
                    if id and (not avoidRecent or (recentKeyHayAttempts[id] or 0)<=now) then
                        local delta=part.Position-origin
                        local squared=delta:Dot(delta)
                        if squared<bestSquared then best,bestId,bestSquared=part,id,squared end
                    end
                end
            end
        end
        return best,bestId
    end
    local function bagFull()
        return (tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0)
            >= (tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25)
    end
    local function postPuzzleKeySearch()
        return BEYY_CHAPTER=="Chapter2" and not hubUnloaded and not finalEndingProtected
            and (postPuzzleKeyPriority or puzzleReleaseObserved)
            and LocalPlayer:GetAttribute("NeedleOwned") ~= true
            and not keyPuzzleCameraBusy() and not needlePriority()
            and LocalPlayer:GetAttribute("HintViewerOpen") ~= true
    end
    local lastKeySearchNotice = -math.huge
    local nextKeyHayRequestAt, nextKeySellRequestAt = 0, 0
    local lastKeyAttemptPruneAt, totalKeyHayRequests = 0, 0
    task.spawn(function()
        while not hubUnloaded do
            -- Keep key pickup on its separate fast 50ms loop. Hidden-key hay
            -- requests have a 650ms minimum to limit full-world scans.
            local interval = math.max(0.1, tonumber(sharedFarmState.CollectInterval) or 0.5)
            if BEYY_CHAPTER=="Chapter2" and (postPuzzleKeyPriority or puzzleReleaseObserved)
                and not finalEndingProtected then
                interval = math.min(interval, 0.35)
            end
            task.wait(interval)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local ordinaryFarm = not farmBlocked() and not needlePriority()
            local findHiddenKey = postPuzzleKeySearch()
            if needleFolder and (ordinaryFarm or findHiddenKey) then
                -- Finding a concealed key remains enabled after the puzzle
                -- cutscene, regardless of the separate AutoPickHay switch.
                -- Actual exposed-key pickup preempts this loop immediately.
                local now=os.clock()
                if findHiddenKey and bagFull() and now>=nextKeySellRequestAt then
                    nextKeySellRequestAt=now+1.5
                    sendFarmRemote("SellHay")
                end
                if findHiddenKey and now-lastKeyAttemptPruneAt>=8 then
                    lastKeyAttemptPruneAt=now
                    for hayId,expires in pairs(recentKeyHayAttempts) do
                        if expires<=now then recentKeyHayAttempts[hayId]=nil end
                    end
                end
                if ((ordinaryFarm and sharedFarmState.AutoPickHay)
                    or ((sharedFarmState.AutoFindNeedle or findHiddenKey) and not exposedNeedle()))
                    and not bagFull() and (not findHiddenKey or now>=nextKeyHayRequestAt) then
                    local hay,id=closestInFolder("HaystackClient","HayId",30,findHiddenKey)
                    if id then
                        local nearby={}
                        local radius=tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                        if radius>0 and hay then
                            local folder=Workspace:FindFirstChild("HaystackClient")
                            if folder then
                                for _,other in ipairs(hayChildrenSnapshot or folder:GetChildren()) do
                                    if other.Parent==folder and other~=hay and other:IsA("BasePart")
                                        and other:GetAttribute("HayId")
                                        and (other.Position-hay.Position).Magnitude<=radius+1 then
                                        nearby[#nearby+1]=other:GetAttribute("HayId")
                                        if #nearby>=6 then break end
                                    end
                                end
                            end
                        end
                        if findHiddenKey then
                            nextKeyHayRequestAt=now+0.65
                            recentKeyHayAttempts[id]=now+1.8
                        end
                        if sendFarmRemote("PickHay",id,nearby) and findHiddenKey then
                            totalKeyHayRequests+=1
                        end
                    end
                end
                if findHiddenKey and now-lastKeySearchNotice>=15 then
                    lastKeySearchNotice=now
                    print("[BeyyHub Key] Hidden-key search active | hay requests=" ..
                        tostring(totalKeyHayRequests) .. " | exposed-key pickup remains on fast scan")
                end
                if ordinaryFarm and sharedFarmState.AutoCollectDroppedHay and not bagFull() then
                    local _,d=closestInFolder("DroppedHay","Dropped",28)
                    if d then sendFarmRemote("PickDroppedHay",d) end
                end
                if ordinaryFarm and sharedFarmState.AutoCollectGems then
                    local _,id=closestInFolder("GemsClient","GemId",35)
                    if id then sendFarmRemote("CollectGem",id) end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(1)
            if needleFolder and not farmBlocked() and not needlePriority() and sharedFarmState.AutoSellHay then
                local held=tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0
                local threshold=tonumber(sharedFarmState.SellThreshold) or 25
                if held>0 and ((sharedFarmState.SellOnlyIfFull and bagFull())
                    or (not sharedFarmState.SellOnlyIfFull and held>=threshold)) then
                    sendFarmRemote("SellHay")
                end
            end
        end
    end)
    task.spawn(function()
        local lastToolsNote = -math.huge
        local function toolNote(message)
            if os.clock() - lastToolsNote >= 8 then
                lastToolsNote = os.clock()
                print("[BeyyHub Tools] " .. message)
            end
        end
        local lastEnabled = nil
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            local enabled = sharedFarmState.AutoUsePitchfork or sharedFarmState.AutoDeployDrone
                or sharedFarmState.AutoUseTNT
            if enabled ~= lastEnabled then
                lastEnabled = enabled
                print("[BeyyHub Tools] Remote tools " .. (enabled and "ENABLED" or "OFF") ..
                    " | TNT=" .. tostring(sharedFarmState.AutoUseTNT) ..
                    " Pitchfork=" .. tostring(sharedFarmState.AutoUsePitchfork) ..
                    " Drone=" .. tostring(sharedFarmState.AutoDeployDrone))
            end
            if enabled then
                needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                local reason = toolBlockReason()
                if not needleFolder then
                    toolNote("Waiting for NeedleHaystack remotes")
                elseif reason then
                    toolNote("Paused: " .. reason)
                else
                    local attempted = false
                    if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                        local _,id=closestInFolder("HaystackClient","HayId",30)
                        if id then
                            attempted = sendFarmRemote("PitchforkDig",id) or attempted
                        end
                    end
                    if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                        and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                        attempted = sendFarmRemote("DeployDrone") or attempted
                    end
                    if attempted then
                        toolNote("Tool remote request sent (server activation not yet confirmed)")
                    else
                        toolNote("No tool request: check tool ownership, nearby hay, and enabled toggles")
                    end
                end
            end
        end
    end)
    task.spawn(function()
        local nextTntLightAt=0
        while not hubUnloaded do
            task.wait(0.1)
            if sharedFarmState.AutoUseTNT and LocalPlayer:GetAttribute("TntOwned")==true
                and os.clock()>=nextTntLightAt then
                needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                if needleFolder and not toolBlockReason() then
                    local cooldown=tonumber(LocalPlayer:GetAttribute("TntCooldown")) or 20
                    nextTntLightAt=os.clock()+math.max(0.5,cooldown,tonumber(sharedFarmState.TntLightCooldown) or 0)
                    if sendFarmRemote("TntAction","light") then
                        task.wait(math.max(0,tonumber(sharedFarmState.TntThrowDelay) or 0.4))
                        if not hubUnloaded and sharedFarmState.AutoUseTNT and not toolBlockReason() then
                            local camera=Workspace.CurrentCamera
                            if camera then
                                sendFarmRemote("TntAction","throw",camera.CFrame,
                                    camera.CFrame.LookVector*40+Vector3.new(0,8,0))
                            end
                        end
                    end
                end
            end
        end
    end)
    local vacuumHeld=false
    local vacuumPoint=Vector2.zero
    local vacuumStart=0
    local vacuumCooldown=0
    local vacuumCooling=false
    local function releaseSharedVacuum()
        if vacuumHeld then
            vacuumHeld=false
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
            end)
        end
    end
    local oldCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        releaseSharedVacuum()
        if oldCleanup then pcall(oldCleanup) end
    end
    task.spawn(function()
        local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
            Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
            Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
        local lastVacuumEnabled = nil
        while not hubUnloaded do
            task.wait(0.08)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            if sharedFarmState.AutoUseVacuum ~= lastVacuumEnabled then
                lastVacuumEnabled = sharedFarmState.AutoUseVacuum
                print("[BeyyHub Tools] Vacuum " .. (lastVacuumEnabled and "ENABLED" or "OFF"))
            end
            local active=needleFolder and BEYY_CHAPTER~="Lobby" and sharedFarmState.AutoUseVacuum
                and not toolBlockReason() and hubWindow.Closed==true
            if not active then
                releaseSharedVacuum()
            elseif os.clock()>=vacuumCooldown then
                local cam=Workspace.CurrentCamera
                local point=cam and cam.ViewportSize/2
                if point then
                    local gui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    local hud=gui and gui:FindFirstChild("HUD")
                    local heat=hud and hud:FindFirstChild("Overheat")
                    local fill=heat and heat:FindFirstChild("Fill")
                    local level=fill and fill:IsA("GuiObject") and fill.Size.Y.Scale or nil
                    if level and level>=0.999 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    elseif vacuumCooling and (not level or level>0.001) then
                        releaseSharedVacuum()
                    elseif not vacuumHeld then
                        vacuumCooling=false
                        local slot=math.clamp(math.floor(tonumber(sharedFarmState.VacuumHotbarSlot) or 5),1,9)
                        local key=hotbar[slot]
                        pcall(function() VirtualInputManager:SendKeyEvent(true,key,false,game) end)
                        task.wait(0.05)
                        pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
                        task.wait(0.15)
                        if not toolBlockReason() and hubWindow.Closed and not needlePriority() then
                            vacuumPoint=point
                            local pressed=pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
                            end)
                            if pressed then vacuumHeld=true; vacuumStart=os.clock() end
                        end
                    elseif not level and os.clock()-vacuumStart>=30 then
                        releaseSharedVacuum()
                        vacuumCooldown=os.clock()+13.5
                    elseif level and level>=0.98 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    end
                end
            end
        end
        releaseSharedVacuum()
    end)
    local handInBusy = false
    local lastHandInWarning = -math.huge
    local function handInWarning(message)
        if os.clock() - lastHandInWarning >= 5 then
            lastHandInWarning = os.clock()
            warn("[BeyyHub] Needle turn-in: " .. tostring(message))
        end
    end
    -- Chapter 2 uses the native objective actions verified in fresh-round tests.
    -- Keep these locals in a separate scope to avoid the enclosing Luau local limit.
    local chapter2KeyActions = (function()
        local function waitUntil(predicate,seconds)
            local deadline=os.clock()+seconds
            repeat
                if predicate() then return true end
                if hubUnloaded then return false end
                task.wait(0.01)
            until os.clock()>=deadline
            return predicate()
        end
        local function handIn()
            if BEYY_CHAPTER~="Chapter2" or handInBusy or needleBusy or hubUnloaded
                or not handInRequested() or keyInteractionBlocked()
                or LocalPlayer:GetAttribute("NeedleOwned")~=true then return false end
            local puzzles=ReplicatedStorage:FindFirstChild("Puzzles")
            if not puzzles or puzzles:GetAttribute("EscapeReady")~=true then return false end
            local laser=Workspace:FindFirstChild("Laser")
            local root=farmRoot()
            local completedRemote=farmRemote("NeedleRoundCompleted")
            if not root or not laser or not laser:IsA("Model") or not completedRemote then return false end
            handInBusy=true
            local completed=false
            local connection=completedRemote.OnClientEvent:Connect(function(userId)
                if tonumber(userId)==LocalPlayer.UserId then completed=true end
            end)
            local started=os.clock()
            local attempts=0
            local ok,err=xpcall(function()
                releaseSharedVacuum()
                root.CFrame=CFrame.new(laser:GetPivot().Position-Vector3.new(0,2.5,0))*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                task.wait(0.05)
                for attempt=1,3 do
                    if completed or hubUnloaded or not handInRequested() then break end
                    if keyInteractionBlocked() or farmRoot()~=root then break end
                    if LocalPlayer:GetAttribute("NeedleOwned")~=true then
                        waitUntil(function() return completed end,0.70)
                        break
                    end
                    -- Disable the existing bypass before sending the request
                    -- that starts the final cinematic.
                    if autoCutsceneDisableAfterHandIn then
                        autoCutsceneDisableAfterHandIn("NeedleHandIn requested")
                    else finalEndingProtected=true end
                    attempts=attempt
                    assert(sendFarmRemote("NeedleHandIn"),"NeedleHandIn remote unavailable")
                    if waitUntil(function() return completed end,0.70) then break end
                    if not hubUnloaded then task.wait(0.15) end
                end
            end,function(e) return tostring(e) end)
            connection:Disconnect()
            handInBusy=false
            if completed then
                finalEndingProtected=true
                postPuzzleKeyPriority=false
                keyObjectiveLatched=false
                print(("[BeyyHub Key] Turn-in confirmed by NeedleRoundCompleted in %.3fs (%d requests)"):format(os.clock()-started,attempts))
            elseif not hubUnloaded then
                handInWarning(ok and "native round-completion event not confirmed; waiting to retry" or tostring(err))
            end
            return completed
        end
        local function pickup(needle,root)
            if needleBusy or handInBusy or hubUnloaded or keyInteractionBlocked()
                or not pickupRequested() then return false end
            needleBusy=true
            local started=os.clock()
            local attempts=0
            local id=keyHayId(needle)
            local ok,err=xpcall(function()
                releaseSharedVacuum()
                root.CFrame=CFrame.new(needle.Position+Vector3.new(0,2.5,3))*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                task.wait(0.05)
                for attempt=1,3 do
                    if LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                    if hubUnloaded or keyInteractionBlocked() or not pickupRequested() or farmRoot()~=root then break end
                    if not needle.Parent then break end
                    attempts=attempt
                    assert(sendFarmRemote("PickHay","Objective"),"PickHay remote unavailable")
                    if waitUntil(function() return LocalPlayer:GetAttribute("NeedleOwned")==true end,0.55) then break end
                end
            end,function(e) return tostring(e) end)
            needleBusy=false
            local collected=LocalPlayer:GetAttribute("NeedleOwned")==true
            if collected then
                setPickupStatus("Key collected; automatic turn-in ready")
                print(("[BeyyHub Key] Native objective pickup confirmed HayId=%s in %.3fs (%d requests)"):format(tostring(id),os.clock()-started,attempts))
                -- Chain directly into hand-in without another polling delay.
                if handInRequested() then handIn() end
            elseif not hubUnloaded then
                setPickupStatus(ok and "Pickup not confirmed; waiting to retry" or "Pickup error: "..tostring(err))
            end
            return collected
        end
        return {pickup=pickup,handIn=handIn}
    end)()

    task.spawn(function()
        while not hubUnloaded do
            task.wait(BEYY_CHAPTER=="Chapter2" and 0.01 or (handInRequested() and 0.12 or 0.5))
            if needleFolder and not keyInteractionBlocked() and handInRequested()
                and not needleBusy and not handInBusy
                and LocalPlayer:GetAttribute("NeedleOwned")==true then
                handInBusy = true
                local ok, err = pcall(function()
                    local root = farmRoot()
                    if not root then return end
                    if BEYY_CHAPTER == "Chapter2" then
                        -- The native controller owns its busy flag and verifies
                        -- NeedleRoundCompleted instead of ownership loss alone.
                        handInBusy=false
                        chapter2KeyActions.handIn()
                    else
                        local npc = Workspace:FindFirstChild("NPC")
                        local farmer = npc and npc:FindFirstChild("Farmer_NPC")
                        if farmer then
                            local location = farmer:GetPivot()
                            if (root.Position - location.Position).Magnitude > 15 then
                                root.CFrame = location * CFrame.new(0, 0, 4)
                            end
                            sendFarmRemote("NeedleHandIn")
                        end
                    end
                end)
                if not ok then handInWarning(err) end
                handInBusy = false
            end
        end
    end)
    local KEY_SCAN_ACTIVE = BEYY_CHAPTER=="Chapter2" and 0.01 or 0.05
    local KEY_SCAN_IDLE = BEYY_CHAPTER=="Chapter2" and 0.05 or 0.30
    local KEY_MOUSE_HOLD = 0.085
    local KEY_OWNERSHIP_WAIT = 0.10
    local lastKeyPickupFailureLogAt = -math.huge
    local lastKeyRemoteFallbackAt = -math.huge
    local function pickupBlockReason()
        if hubUnloaded then return "Hub unloaded" end
        if not pickupRequested() then return "Auto pickup / find is off" end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then return "Key / needle collected" end
        if not needleFolder then return "Waiting for NeedleHaystack to replicate" end
        if keyPuzzleCameraBusy() then return "Waiting for an active lever/colour controller to release the camera" end
        if LocalPlayer:GetAttribute("CutsceneActive")==true and not keyObjectivePhase() then
            return "Waiting for CutsceneActive to clear"
        end
        if LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true and not keyObjectivePhase() then
            return "Waiting for puzzle-release objective to appear"
        end
        if LocalPlayer:GetAttribute("NeedleInputLocked")==true and not keyObjectivePhase() then
            return "Waiting for NeedleInputLocked to clear"
        end
        if LocalPlayer:GetAttribute("HintViewerOpen")==true then return "Close the hint viewer to pick up the key" end
        if needleBusy then return "Pickup in progress" end
        return nil
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait((pickupRequested() or postPuzzleKeyPriority or puzzleReleaseObserved)
                and KEY_SCAN_ACTIVE or KEY_SCAN_IDLE)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local blocked = pickupBlockReason()
            if blocked then
                setPickupStatus(blocked)
            else
                local needle=exposedNeedle()
                local root=farmRoot()
                local camera=Workspace.CurrentCamera
                if not needle then
                    setPickupStatus("Waiting for an exposed objective with a numeric HayId")
                elseif not root or not camera then
                    setPickupStatus("Waiting for the character and camera")
                elseif BEYY_CHAPTER=="Chapter2" then
                    chapter2KeyActions.pickup(needle,root)
                else
                    needleBusy=true
                    local pickupStart=os.clock()
                    local clicksSent=0
                    releaseSharedVacuum()
                    local previousRoot=root.CFrame
                    local previousCameraType=camera.CameraType
                    local previousCameraCF=camera.CFrame
                    local previousHover=LocalPlayer:GetAttribute("HoveredHayId")
                    local renderName="BeyySharedNeedleAim_"..tostring(LocalPlayer.UserId)
                    local bound=false
                    local mouseDown=false
                    local moved=false
                    local cameraCaptured=false
                    local filteredParts = {}
                    local function restoreQueryFilter()
                        for part, old in pairs(filteredParts) do
                            if part.Parent then
                                pcall(function()
                                    part.CanQuery = old.query
                                    part.CanCollide = old.collide
                                end)
                            end
                            filteredParts[part] = nil
                        end
                    end
                    local function filterKeyBlockers()
                        local count = 0
                        for _, folderName in ipairs({"HaystackClient", "HaystackCollision"}) do
                            local folder = Workspace:FindFirstChild(folderName)
                            if folder then
                                for _, part in ipairs(folder:GetDescendants()) do
                                    if count >= 32 then break end
                                    if part:IsA("BasePart") and part ~= needle and part.CanQuery
                                        and part:GetAttribute("IsNeedleObjective") ~= true
                                        and (part.Position - needle.Position).Magnitude <=
                                            7 + math.min(part.Size.Magnitude * 0.5, 4) then
                                        local old = { query = part.CanQuery, collide = part.CanCollide }
                                        local ok = pcall(function()
                                            if part.CanCollide then part.CanCollide = false end
                                            part.CanQuery = false
                                        end)
                                        if ok and not part.CanQuery then
                                            filteredParts[part] = old
                                            count += 1
                                        else
                                            pcall(function()
                                                part.CanQuery = old.query
                                                part.CanCollide = old.collide
                                            end)
                                        end
                                    end
                                end
                            end
                        end
                        return count
                    end
                    local function clear()
                        restoreQueryFilter()
                        if mouseDown then
                            mouseDown=false
                            local center=camera.ViewportSize/2
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            end)
                        end
                        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
                        if cameraCaptured and camera then
                            pcall(function()
                                camera.CameraType=previousCameraType
                                camera.CFrame=previousCameraCF
                            end)
                        end
                        if moved and root and root.Parent then pcall(function() root.CFrame=previousRoot end) end
                        pcall(function() LocalPlayer:SetAttribute("HoveredHayId",previousHover) end)
                        needleBusy=false
                    end
                    local ok,err=xpcall(function()
                        if hubWindow.Closed~=true then
                            setPickupStatus("Closing the menu for key pickup")
                            hubWindow:Close()
                        end
                        local menuDeadline=os.clock()+1
                        repeat
                            RunService.RenderStepped:Wait()
                        until hubWindow.Closed==true or hubUnloaded or os.clock()>=menuDeadline
                        if hubWindow.Closed~=true then error("Menu did not close; pickup will retry") end
                        RunService.RenderStepped:Wait()
                        if hubUnloaded or keyInteractionBlocked() or not pickupRequested()
                            or not needle.Parent or not root.Parent then return end
                        if Workspace.CurrentCamera~=camera then error("Camera changed; pickup will retry") end
                        previousCameraType=camera.CameraType
                        previousCameraCF=camera.CFrame
                        cameraCaptured=true
                        setPickupStatus("Teleporting beside the key / needle")
                        local id=keyHayId(needle)
                        if id == nil then error("Key HayId not yet replicated; retrying") end
                        local forward=camera.CFrame.LookVector
                        local flat=Vector3.new(forward.X,0,forward.Z)
                        if flat.Magnitude < 0.05 then
                            forward=root.CFrame.LookVector
                            flat=Vector3.new(forward.X,0,forward.Z)
                        end
                        if flat.Magnitude < 0.05 then flat=Vector3.new(0,0,-1) end
                        flat=flat.Unit
                        local spot=needle.Position-flat*1.75+Vector3.new(0,2.3,0)
                        root.CFrame=CFrame.lookAt(spot,Vector3.new(needle.Position.X,spot.Y,needle.Position.Z))
                        moved=true
                        root.AssemblyLinearVelocity=Vector3.zero
                        root.AssemblyAngularVelocity=Vector3.zero
                        camera.CameraType=Enum.CameraType.Scriptable
                        local cameraSpot=needle.Position-flat*4+Vector3.new(0,3.3,0)
                        camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+1000,function()
                            if needle.Parent then
                                camera.CameraType=Enum.CameraType.Scriptable
                                camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                                LocalPlayer:SetAttribute("HoveredHayId",id)
                            end
                        end)
                        bound=true
                        RunService.RenderStepped:Wait()
                        local filtered=filterKeyBlockers()
                        RunService.RenderStepped:Wait()
                        local projected,onScreen=camera:WorldToViewportPoint(needle.Position)
                        local middle=camera.ViewportSize/2
                        if not onScreen or (Vector2.new(projected.X,projected.Y)-middle).Magnitude > 18 then
                            error("Key aim did not reach the centre of the viewport")
                        end
                        if filtered > 0 then
                            setPickupStatus("Cleared " .. filtered .. " temporary hay blockers before key pickup")
                        end
                        setPickupStatus("Clicking the objective; waiting for ownership confirmation")
                        for _=1,8 do
                            if hubUnloaded or keyInteractionBlocked() or not pickupRequested()
                                or not needle.Parent or LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            local center=camera.ViewportSize/2
                            LocalPlayer:SetAttribute("HoveredHayId",id)
                            VirtualInputManager:SendMouseMoveEvent(center.X,center.Y,game)
                            RunService.RenderStepped:Wait()
                            if hubUnloaded or keyInteractionBlocked() or LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,true,game,0)
                            mouseDown=true
                            task.wait(KEY_MOUSE_HOLD)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            mouseDown=false
                            clicksSent+=1
                            local confirmUntil=os.clock()+KEY_OWNERSHIP_WAIT
                            while os.clock()<confirmUntil and not hubUnloaded and not keyInteractionBlocked()
                                and pickupRequested() and needle.Parent
                                and LocalPlayer:GetAttribute("NeedleOwned")~=true do
                                task.wait(0.025)
                            end
                            if LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            if clicksSent == 2 and not hubUnloaded and needle.Parent
                                and not keyInteractionBlocked()
                                and os.clock()-lastKeyRemoteFallbackAt>=1.5 then
                                -- Do not waste six further clicks before trying
                                -- the existing server-side pickup fallback.
                                lastKeyRemoteFallbackAt = os.clock()
                                if sendFarmRemote("PickHay", id, {}) then
                                    local fastConfirmUntil = os.clock()+0.12
                                    while os.clock()<fastConfirmUntil and not hubUnloaded
                                        and LocalPlayer:GetAttribute("NeedleOwned")~=true do
                                        task.wait(0.025)
                                    end
                                    if LocalPlayer:GetAttribute("NeedleOwned")==true then
                                        print("[BeyyHub Key] Early PickHay confirmed HayId="..tostring(id))
                                        break
                                    end
                                end
                            end
                        end
                        if not hubUnloaded and needle.Parent
                            and LocalPlayer:GetAttribute("NeedleOwned")~=true
                            and not keyInteractionBlocked()
                            and os.clock()-lastKeyRemoteFallbackAt>=1.5 then
                            -- If VIM does not register on an exposed key, try
                            -- the game's existing PickHay action once before
                            -- resetting the camera and retrying.
                            lastKeyRemoteFallbackAt=os.clock()
                            if sendFarmRemote("PickHay", id, {}) then
                                print("[BeyyHub Key] VIM pickup unconfirmed; trying PickHay for exposed HayId="..tostring(id))
                                task.wait(0.18)
                            end
                        end
                    end,function(e) return tostring(e) end)
                    clear()
                    local duration=os.clock()-pickupStart
                    if not ok then
                        setPickupStatus("Pickup error: "..tostring(err))
                        warn(("[BeyyHub Key] Pickup error after %.2fs (%d clicks): %s"):format(
                            duration,clicksSent,tostring(err)))
                    elseif LocalPlayer:GetAttribute("NeedleOwned")==true then
                        setPickupStatus("Key / needle collected")
                        print(("[BeyyHub Key] Picked up HayId=%s in %.2fs (%d clicks)"):format(
                            tostring(needle:GetAttribute("HayId")),duration,clicksSent))
                    else
                        setPickupStatus("Pickup not confirmed; retrying on the next scan")
                        if clicksSent>0 and os.clock()-lastKeyPickupFailureLogAt>=4 then
                            lastKeyPickupFailureLogAt=os.clock()
                            warn(("[BeyyHub Key] Not confirmed after %.2fs (%d clicks); will retry"):format(
                                duration,clicksSent))
                        end
                    end
                end
            end
        end
    end)
    local function owned(attr) return LocalPlayer:GetAttribute(attr)==true end
    local function cash()
        local ls=LocalPlayer:FindFirstChild("leaderstats")
        local value=ls and ls:FindFirstChild("Cash")
        return value and tonumber(value.Value) or 0
    end
    local function createWorkerWake(player)
        local api={}
        local alive=true
        local waiters,connections={},{}
        local cashFolder,cashValue,cashConnections=nil,nil,{}
        local function finish(token,cancelTimer)
            if token.Done then return end
            token.Done=true;waiters[token]=nil
            if cancelTimer and token.Timer then pcall(task.cancel,token.Timer)end
            task.defer(token.Thread)
        end
        function api.Wake(key)
            for token in pairs(waiters)do
                if key==nil or token.Key==key or(key=="upgrades"and token.Key=="upgrades-cash")then finish(token,true)end
            end
        end
        local function syncCash()
            local folder=player:FindFirstChild("leaderstats")
            local value=folder and folder:FindFirstChild("Cash")
            if folder==cashFolder and value==cashValue then return end
            for _,connection in ipairs(cashConnections)do connection:Disconnect()end
            table.clear(cashConnections);cashFolder,cashValue=folder,value
            if folder then
                cashConnections[#cashConnections+1]=folder.ChildAdded:Connect(function()syncCash();api.Wake("upgrades-cash")end)
                cashConnections[#cashConnections+1]=folder.ChildRemoved:Connect(function()syncCash();api.Wake("upgrades-cash")end)
            end
            if value then cashConnections[#cashConnections+1]=value:GetPropertyChangedSignal("Value"):Connect(function()api.Wake("upgrades-cash")end)end
        end
        connections[1]=player.AttributeChanged:Connect(function(name)
            if name:sub(1,10)=="HayUpgrade"or name=="UpgradeCostMultiplier"or name=="PitchforkUpgradeCostMultiplier"then api.Wake("upgrades")end
        end)
        connections[2]=player.ChildAdded:Connect(function(child)if child.Name=="leaderstats"then syncCash();api.Wake("upgrades")end end)
        connections[3]=player.ChildRemoved:Connect(function(child)if child==cashFolder then syncCash();api.Wake("upgrades")end end)
        function api.Wait(interval,idle,key)
            if not alive then return end
            if not idle then task.wait(interval);return end
            if key=="upgrades"or key=="upgrades-cash"then syncCash()end
            local token={Thread=coroutine.running(),Key=key}
            waiters[token]=true
            token.Timer=task.delay(1,function()finish(token,false)end)
            coroutine.yield()
        end
        function api.Stop()
            if not alive then return end
            alive=false
            for _,connection in ipairs(connections)do connection:Disconnect()end
            for _,connection in ipairs(cashConnections)do connection:Disconnect()end
            for token in pairs(waiters)do finish(token,true)end
            table.clear(connections);table.clear(cashConnections)
            cashFolder,cashValue=nil,nil
        end
        local previous=_G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP=function()api.Stop();if previous then previous()end end
        return api
    end
    
    
    local function createAutoUpgradeRuntime(options)
        local config, configModule, pending
        local idle,waitKey=true,"upgrades"
        local tracks = {
            {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
            {"UpgVacRuntime","VacuumRuntime"},
            {"UpgTntPower","TntPower"},{"UpgTntLuck","TntLuck"},
            {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
            {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
            {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
            {"UpgTntCooldown","TntCooldown"},
        }
        local lastStatus
        local function status(text)
            if text~=lastStatus then lastStatus=text;options.Status(text) end
        end
        local function level(name) return tonumber(options.Player:GetAttribute("HayUpgrade"..name)) or 1 end
        local function cost(name, entry)
            local price=tonumber(entry.Cost)
            if not price or price<0 or price~=price or price==math.huge then return nil end
            price*=tonumber(options.Player:GetAttribute("UpgradeCostMultiplier")) or 1
            if name:sub(1,9)=="Pitchfork" then price*=tonumber(options.Player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
            return math.round(price*100)/100
        end
        local function tick()
            idle,waitKey=true,"upgrades"
            local folder=options.Folder()
            local module=folder and folder:FindFirstChild("Config")
            local remote=folder and folder:FindFirstChild("BuyUpgrade")
            if not module or not remote or not remote:IsA("RemoteEvent") then status("Waiting for upgrade config / remote"); return end
            if configModule~=module or not config then
                local loaded=require(module)
                assert(type(loaded)=="table" and type(loaded.UPGRADE_TRACKS)=="table","Invalid upgrade config")
                config,configModule=loaded,module
                if options.OnConfig then options.OnConfig(loaded) end
            end
            if pending then
                idle=false
                local confirmedLevel=level(pending.Name)
                if confirmedLevel~=pending.Level or not options.State[pending.Flag] then
                    if confirmedLevel>pending.Level and options.OnConfirmed then options.OnConfirmed(pending,confirmedLevel) end
                    pending=nil
                elseif os.clock()<pending.Until then status("Waiting for "..pending.Name.." purchase confirmation"); return
                else
                    status("Server did not confirm "..pending.Name.."; retrying")
                    pending=nil
                end
            end
            local cash=tonumber(options.Cash()) or 0
            local selected, available, vacuum, power, earlyTnt, lateTnt=0,{},nil,nil,nil,nil
            for _,entry in ipairs(tracks) do
                if options.State[entry[1]] then
                    selected+=1
                    local track=config.UPGRADE_TRACKS[entry[2]]
                    local current=level(entry[2])
                    local nextLevel=track and track.Levels and track.Levels[current+1]
                    local price=nextLevel and cost(entry[2],nextLevel)
                    if price then
                        local target={Flag=entry[1],Name=entry[2],Level=current,Cost=price}
                        if entry[2]=="TntCooldown" then
                            -- Tracks start at L1: two purchases reach L3.
                            if current<3 then earlyTnt=target else lateTnt=target end
                        else
                            available[#available+1]=target
                        end
                        if entry[2]=="VacuumPower" then power=target end
                        if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                    end
                end
            end
            if selected==0 then status("No cash upgrades enabled"); return end
            if #available==0 and not earlyTnt and not lateTnt then status("Selected cash upgrades are maxed or unavailable"); return end
            local target
            if earlyTnt then
                if cash<earlyTnt.Cost then waitKey="upgrades-cash";status(string.format("Saving for TntCooldown: $%.2f / $%.2f",cash,earlyTnt.Cost)); return end
                target=earlyTnt
            elseif power then
                if cash<power.Cost then waitKey="upgrades-cash";status(string.format("Saving for VacuumPower: $%.2f / $%.2f",cash,power.Cost)); return end
                target=power
            elseif vacuum and cash>=vacuum.Cost*0.75 then
                if cash<vacuum.Cost then waitKey="upgrades-cash";status(string.format("Saving for %s: $%.2f / $%.2f",vacuum.Name,cash,vacuum.Cost)); return end
                target=vacuum
            else
                for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
                -- Remaining TNT speed levels wait until all other enabled tracks finish.
                if #available==0 and lateTnt and cash>=lateTnt.Cost then target=lateTnt end
            end
            if not target then
                waitKey="upgrades-cash"
                local cheapest=available[1] or lateTnt
                for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
                status(string.format("Waiting for cash: $%.2f / $%.2f (%s)",cash,cheapest.Cost,cheapest.Name)); return
            end
            idle=false
            -- Reserve before sending: replication may confirm the purchase immediately.
            pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Started=os.clock(),Until=os.clock()+0.05}
            remote:FireServer(target.Name)
            if options.OnRequested then options.OnRequested(pending) end
            status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
        end
        return {IsIdle=function()return idle end,WaitKey=function()return waitKey end,Tick=function()
            local ok,err=pcall(tick)
            if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
        end}
    end
    
    
    
    local upgradePurchaseAttempts={}
    local permanentPurchaseAttempts={}
    local lastUpgradeConfirmedAt
    local function logUpgradeConfirmation(category,name,pending,level)
        local now=os.clock()
        local spacing=lastUpgradeConfirmedAt and string.format(" interval=%.3fs",now-lastUpgradeConfirmedAt) or ""
        lastUpgradeConfirmedAt=now
        print(string.format("[BeyyHub Upgrade] %s %s L%d->L%d confirmed after %.3fs%s",
            category,name,pending.level,level,now-pending.at,spacing))
    end
    local function tryTrack(name)
        if not sharedGameConfig then return end
        local track=sharedGameConfig.UPGRADE_TRACKS and sharedGameConfig.UPGRADE_TRACKS[name]
        if not track then return end
        local level=tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1
        local previous=upgradePurchaseAttempts[name]
        if previous and level~=previous.level then
            if level>previous.level then logUpgradeConfirmation("Cash",name,previous,level) end
            upgradePurchaseAttempts[name]=nil
        end
        if level>=#track.Levels then return end
        local nextLevel=track.Levels[level+1]
        if nextLevel then
            local price=(tonumber(nextLevel.Cost) or 0)*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)
            if name:sub(1,9)=="Pitchfork" then price*=tonumber(LocalPlayer:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
            if cash()<price then return end
            local now=os.clock()
            local pending=upgradePurchaseAttempts[name]
            if pending and pending.level==level and now-pending.at<0.05 then return end
            upgradePurchaseAttempts[name]={level=level,at=now}
            if not sendFarmRemote("BuyUpgrade",name) then upgradePurchaseAttempts[name]=nil end
        end
    end
    local function tryPermanent(name)
        if not sharedUpgradeConfig then return end
        local ok,upgrade=pcall(function() return sharedUpgradeConfig.getUpgrade(name) end)
        if not ok or not upgrade then return end
        local level=tonumber(LocalPlayer:GetAttribute("Upgrade"..name)) or 0
        local previous=permanentPurchaseAttempts[name]
        if previous and level~=previous.level then
            if level>previous.level then logUpgradeConfirmation("Permanent",name,previous,level) end
            permanentPurchaseAttempts[name]=nil
        end
        local levelOK,maxLevel=pcall(function() return sharedUpgradeConfig:getMaxLevel(upgrade) end)
        if not levelOK or level>=maxLevel then return end
        local priceOK,price=pcall(function() return sharedUpgradeConfig:getPrice(upgrade,level) end)
        if priceOK and price and (tonumber(LocalPlayer:GetAttribute("Gems")) or 0)>=price then
            local now=os.clock()
            local pending=permanentPurchaseAttempts[name]
            if pending and pending.level==level and now-pending.at<0.25 then return end
            permanentPurchaseAttempts[name]={level=level,at=now}
            if not sendFarmRemote("BuyUpgrade",name) then permanentPurchaseAttempts[name]=nil end
        end
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.BuyInterval) or 1))
            if needleFolder and sharedFarmState.AutoBuyTools and BEYY_CHAPTER~="Lobby" then
                local selected=sharedFarmState.BuyToolsList or {}
                local choices={}
                for k,value in pairs(selected) do
                    if type(k)=="number" and type(value)=="string" then
                        choices[#choices+1]=value
                    elseif type(k)=="string" and value then
                        choices[#choices+1]=k
                    end
                end
                for _,name in ipairs(choices) do
                    if name=="Pitchfork" and not owned("PitchforkOwned") then
                        sendFarmRemote("BuyShopItem","Pitchfork")
                    elseif name=="TNT" and not owned("TntOwned") then
                        sendFarmRemote("BuyShopItem","Tnt")
                    elseif name=="Drone" and not owned("DroneOwned") then
                        sendFarmRemote("BuyShopItem","Drone")
                    elseif name=="Infinite Bag" and not owned("InfiniteBagOwned") then
                        sendFarmRemote("BuyShopItem","InfiniteBag")
                    elseif name=="Capacity Bag" then
                        tryTrack("Capacity")
                    end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.PermInterval) or 0.5))
            if needleFolder and BEYY_CHAPTER~="Lobby" then
                local mapped={UpgBagSize="ExtraHoldAmount",UpgExtraTake="ExtraTakeAmount",
                    UpgGemValue="GemValue",UpgHayValue="ExtraHayValuePercentage"}
                for key,name in pairs(mapped) do
                    if sharedFarmState[key] then tryPermanent(name) end
                end
            end
        end
    end)
    do
        local upgrades=createAutoUpgradeRuntime({
            State=sharedFarmState,Player=LocalPlayer,Cash=cash,
            Folder=function()
                needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                return needleFolder
            end,
            OnConfig=function(config)sharedGameConfig=config end,
            Status=function()end,
            OnConfirmed=function(pending,current)
                logUpgradeConfirmation("Cash",pending.Name,
                    {level=pending.Level,at=pending.Started},current)
            end
        })
        task.spawn(function()
            local wake=createWorkerWake(LocalPlayer)
            while not hubUnloaded do
                upgrades.Tick()
                wake.Wait(0.05,upgrades.IsIdle(),upgrades.WaitKey())
            end
            wake.Stop()
        end
    end)


        local puzzleTab = hubWindow:Tab({ Title = "Puzzles", Icon = "puzzle" })
        local function countVisibleColourGems(folder)
            local count, total = 0, 0
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") and child.Name == "Shard" then
                    total += 1
                    for _, obj in ipairs(child:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Transparency < 0.98
                            and obj.LocalTransparencyModifier < 0.98 then
                            count += 1
                            break
                        end
                    end
                end
            end
            return count, total
        end
        local function readVisibleColourCounts(puzzle)
            local counts, summaries = {}, {}
            local firstProblem
            for index, name in ipairs({ "Red", "Purple", "Green" }) do
                local folder = puzzle:FindFirstChild(name .. "Gems")
                if not folder then return nil, nil, name .. "Gems folder missing" end
                local visible, slots = countVisibleColourGems(folder)
                counts[index] = visible
                summaries[index] = string.format("%s: %d visible / %d slots", name, visible, slots)
                if visible == 0 and not firstProblem then
                    firstProblem = name .. " has 0 visible Shards"
                end
            end
            if firstProblem then return nil, summaries, firstProblem end
            return counts, summaries
        end
        local puzzleControllerBusy = false
        local colourRunning = false
        local colourCancel = false
        local colourLastRunInputClicks = 0
        local COLOUR_RENDER_BIND = "BeyyV103_00ColourAim_" .. tostring(LocalPlayer.UserId)

        local COLOUR_CAMERA_SETTLE = 0.12
        local COLOUR_MOUSE_SETTLE = 0.025
        local COLOUR_CLICK_HOLD = 0.085
        local COLOUR_CLICK_GAP = 0.11
        local COLOUR_BETWEEN_PEDESTALS = 0.06
        local lastColourStatus = nil
        local function colourStatus(message)
            -- Gem was previously silent when all clicks were sent but the
            -- server did not confirm completion. Surface the exact stage.
            if message == lastColourStatus then return end
            lastColourStatus = message
            print("[BeyyHub Gem] " .. tostring(message))
        end
        local function readColourPuzzle()
            local puzzles = Workspace:FindFirstChild("Puzzles")
            local puzzle = puzzles and puzzles:FindFirstChild("ColorPuzzle")
            if not puzzle then return nil, nil, "ColorPuzzle not found" end
            local base = puzzle:FindFirstChild("Folder")
            if not base then return nil, nil, "ColorPuzzle.Folder (pedestals) not found" end
            local counts, summaries, problem = readVisibleColourCounts(puzzle)
            if not counts then
                return nil, nil, problem
            end
            local pedestals = {}
            for index = 1, 3 do
                if counts[index] < 1 or counts[index] > 5 then
                    return nil, nil, string.format("Gem count %d outside expected 1-5 for pedestal %d; not clicking", counts[index], index)
                end
                local pedestal = base:FindFirstChild("Pedestal" .. tostring(index))
                if not pedestal or not pedestal:IsA("Model") then
                    return nil, nil, "Pedestal" .. index .. " model missing"
                end
                pedestals[index] = pedestal
            end

            if counts[1] == 5 and counts[2] == 5 and counts[3] == 5 then
                return nil, nil, "All 15 slot models appear visible; cannot verify the gem counts"
            end
            return counts, pedestals
        end
        local function clickPartForPedestal(pedestal)
            local parts = {}
            for _, item in ipairs(pedestal:GetDescendants()) do
                if item:IsA("ClickDetector") and item.Parent and item.Parent:IsA("BasePart") then
                    return item.Parent, "ClickDetector"
                end
                if item:IsA("BasePart") and item.CanQuery then
                    parts[#parts + 1] = item
                end
            end
            local names = { "click", "hitbox", "button", "top", "main", "pad", "pedestal" }
            for _, name in ipairs(names) do
                for _, item in ipairs(parts) do
                    if item.Name:lower():find(name, 1, true) then return item, name end
                end
            end
            return parts[1], parts[1] and "first queryable part" or "no queryable BasePart"
        end
        local function pedestalView(pedestal, target, character)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { character }
            rayParams.IgnoreWater = true
            local forward = Vector3.new(target.CFrame.LookVector.X, 0, target.CFrame.LookVector.Z)
            if forward.Magnitude < 0.05 then forward = Vector3.new(0, 0, 1) end
            forward = forward.Unit
            local side = Vector3.new(-forward.Z, 0, forward.X)
            local directions = {
                forward, -forward, side, -side,
                (forward + side).Unit, (forward - side).Unit,
                (-forward + side).Unit, (-forward - side).Unit,
            }
            local best, bestScore = nil, -1
            for _, radius in ipairs({ 3.5, 4.5, 5.5, 7 }) do
                for _, vertical in ipairs({ 1.5, 0.5, 2.5, -0.3 }) do
                    for _, dir in ipairs(directions) do
                        local cameraAt = target.Position + dir * radius + Vector3.new(0, vertical, 0)
                        local ray = target.Position - cameraAt
                        local hit = Workspace:Raycast(cameraAt, ray.Unit * (ray.Magnitude + 0.25), rayParams)
                        local score = hit and (hit.Instance == target and 3
                            or (hit.Instance:IsDescendantOf(pedestal) and 2 or 0)) or 0
                        if score > bestScore then
                            bestScore = score
                            best = { cameraAt = cameraAt, lookAt = target.Position, score = score }
                        end
                        if score == 3 then return best, rayParams end
                    end
                end
            end
            return best, rayParams
        end
        local function runColourPuzzle(earlyAttempt)
            if hubUnloaded or colourRunning then return end
            if puzzleControllerBusy then colourStatus("Another puzzle controller is active; wait for it to finish") return end
            colourRunning = true
            puzzleControllerBusy = true
            colourCancel = false
            colourLastRunInputClicks = 0
            local cam = Workspace.CurrentCamera
            local previousPivot, previousCFrame, previousType, previousSubject
            local colourCompletedAllClicks = false

            local colourServerCompleted = false
            local colourStateSeen = false
            local puzzleRemotes = ReplicatedStorage:FindFirstChild("Puzzles")
            local colourStateRemote = puzzleRemotes and puzzleRemotes:FindFirstChild("PuzzleState")
            local colourSolvedRemote = puzzleRemotes and puzzleRemotes:FindFirstChild("PuzzleSolved")
            local colourStateConnection, colourSolvedConnection
            if colourStateRemote and colourStateRemote:IsA("RemoteEvent") then
                colourStateConnection = colourStateRemote.OnClientEvent:Connect(function(snapshot)
                    local entry = type(snapshot) == "table" and snapshot.ColorPuzzle
                    if type(entry) == "table" then
                        colourStateSeen = true
                        if entry.completed == true or entry.solved == true then
                            colourServerCompleted = true
                        end
                    end
                end)
            end
            if colourSolvedRemote and colourSolvedRemote:IsA("RemoteEvent") then
                colourSolvedConnection = colourSolvedRemote.OnClientEvent:Connect(function(puzzleName)
                    if puzzleName == "ColorPuzzle" then
                        colourServerCompleted = true
                    elseif type(puzzleName) == "table" and
                        (puzzleName.puzzle == "ColorPuzzle" or puzzleName.puzzleName == "ColorPuzzle") then
                        colourServerCompleted = true
                    end
                end)
            end
            local function colourWorldSolved()
                local puzzles = Workspace:FindFirstChild("Puzzles")
                local colour = puzzles and puzzles:FindFirstChild("ColorPuzzle")
                return colour ~= nil and (colour:GetAttribute("Solved") == true or colour:GetAttribute("Completed") == true)
            end
            local mouseDown = false
            local lastClick = Vector2.new(0, 0)
            local previousMouse = UserInputService:GetMouseLocation()
            local previousMouseBehavior = UserInputService.MouseBehavior
            local reopenMenu = hubWindow and hubWindow.Closed == false
            local function releaseMouse()
                if mouseDown then
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(lastClick.X, lastClick.Y, 0, false, game, 0)
                    end)
                    mouseDown = false
                end
            end
            local function restore()
                releaseMouse()
                gemCutsceneCameraAim = nil
                pcall(function() RunService:UnbindFromRenderStep(COLOUR_RENDER_BIND) end)
                pcall(function() UserInputService.MouseBehavior = previousMouseBehavior end)
                local character = LocalPlayer.Character
                if previousPivot and character and character.Parent then
                    pcall(function() character:PivotTo(previousPivot) end)
                end
                if cam and cam.Parent then
                    pcall(function()
                        if previousType then cam.CameraType = previousType end
                        if previousSubject then cam.CameraSubject = previousSubject end
                        if previousCFrame then cam.CFrame = previousCFrame end
                    end)
                end
                pcall(function()
                    VirtualInputManager:SendMouseMoveEvent(previousMouse.X, previousMouse.Y, game)
                end)
                hubRestoreAction = nil
            end
            hubRestoreAction = restore
            local ok, err = xpcall(function()
                local counts, pedestals, problem = readColourPuzzle()
                if not counts then colourStatus("Stopped: " .. tostring(problem)) return end
                colourStatus(string.format("Round gems: red=%d, purple=%d, green=%d", counts[1], counts[2], counts[3]))
                pcall(function() colourCountStatus:SetDesc(string.format("Red: %d | Purple: %d | Green: %d", counts[1], counts[2], counts[3])) end)
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not character or not root or not cam then
                    colourStatus("Character root or camera unavailable") return
                end

                if reopenMenu then
                    pcall(function() hubWindow:Close() end)
                    task.wait(0.12)
                end
                previousPivot = character:GetPivot()
                previousCFrame = cam.CFrame
                previousType = cam.CameraType
                previousSubject = cam.CameraSubject
                local rootToPivot = root.CFrame:ToObjectSpace(previousPivot)

                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                local total = 0
                for i, colour in ipairs({ "Red", "Purple", "Green" }) do
                    if hubUnloaded or colourCancel then break end
                    local pedestal = pedestals[i]
                    local target, reason = clickPartForPedestal(pedestal)
                    if not target then
                        colourStatus("Stopped: Pedestal" .. i .. " has " .. tostring(reason))
                        break
                    end
                    local view, rayParams = pedestalView(pedestal, target, character)
                    if not view or view.score < 2 then
                        colourStatus("Stopped: no clear sightline to Pedestal" .. i .. "; don't guess clicks")
                        break
                    end

                    local rootPosition = view.cameraAt - Vector3.new(0, 1.6, 0)
                    local horizontalLook = Vector3.new(target.Position.X, rootPosition.Y, target.Position.Z)
                    character:PivotTo(CFrame.lookAt(rootPosition, horizontalLook) * rootToPivot)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero

                    local lockedCamera = CFrame.lookAt(view.cameraAt, target.Position, Vector3.yAxis)
                    local function aim()
                        if hubUnloaded or colourCancel or Workspace.CurrentCamera ~= cam then return end
                        cam.CameraType = Enum.CameraType.Scriptable
                        cam.CFrame = lockedCamera
                        cam.Focus = CFrame.new(target.Position)
                        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                    end
                    pcall(function() RunService:UnbindFromRenderStep(COLOUR_RENDER_BIND) end)
                    gemCutsceneCameraAim = aim
                    RunService:BindToRenderStep(COLOUR_RENDER_BIND, Enum.RenderPriority.Last.Value + 30, aim)
                    aim()
                    task.wait(math.max(COLOUR_CAMERA_SETTLE, 0.24))
                    for _ = 1, 3 do
                        RunService.RenderStepped:Wait()
                        aim()
                    end
                    local center = cam.ViewportSize * 0.5
                    local sent = 0
                    for clickIndex = 1, counts[i] do
                        if hubUnloaded or colourCancel then break end
                        aim()
                        RunService.RenderStepped:Wait()
                        aim()
                        local hit = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 25, rayParams)
                        if not hit or not hit.Instance:IsDescendantOf(pedestal) then
                            colourStatus(string.format("Stopped at %s %d/%d: centre ray blocked by %s",
                                colour, clickIndex, counts[i], hit and hit.Instance:GetFullName() or "nothing"))
                            break
                        end
                        local moved, moveError = pcall(function()
                            VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game)
                        end)
                        if not moved then
                            colourStatus("Stopped: could not move cursor: " .. tostring(moveError))
                            break
                        end
                        RunService.RenderStepped:Wait()
                        task.wait(math.max(COLOUR_MOUSE_SETTLE, 0.045))
                        aim()

                        aim()
                        local down, pressError = pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                        end)
                        if not down then
                            colourStatus("Stopped: VIM Mouse1 press failed: " .. tostring(pressError))
                            break
                        end
                        mouseDown = true
                        colourLastRunInputClicks += 1
                        lastClick = center
                        task.wait(COLOUR_CLICK_HOLD)
                        aim()
                        releaseMouse()
                        sent += 1
                        total += 1

                        task.wait(clickIndex < counts[i] and COLOUR_CLICK_GAP or 0.12)
                    end
                    pcall(function() RunService:UnbindFromRenderStep(COLOUR_RENDER_BIND) end)
                    gemCutsceneCameraAim = nil
                    colourStatus(string.format("%s pedestal: %d/%d clicks sent", colour, sent, counts[i]))
                    if sent < counts[i] then break end
                    task.wait(COLOUR_BETWEEN_PEDESTALS)
                end
                colourCompletedAllClicks = not hubUnloaded and not colourCancel
                    and total == counts[1] + counts[2] + counts[3]
                if colourCompletedAllClicks then

                    if colourStateRemote and colourStateRemote:IsA("RemoteEvent") then
                        pcall(function() colourStateRemote:FireServer() end)
                    end
                    -- Early cutscene clicks may be acknowledged on the next
                    -- server puzzle-state update. Wait briefly for the REAL
                    -- event/attribute rather than repeating any clicks.
                    local confirmationBudget = earlyAttempt and 0.9 or 0.25
                    local confirmStart = os.clock()
                    colourStatus(string.format("All %d clicks sent; awaiting server confirmation (%.2fs max)...",
                        total, confirmationBudget))
                    while not colourServerCompleted and not colourWorldSolved()
                        and not hubUnloaded and not colourCancel
                        and os.clock()-confirmStart < confirmationBudget do
                        task.wait(0.04)
                    end
                    if colourServerCompleted or colourWorldSolved() then
                        colourStatus(string.format("CONFIRMED: ColorPuzzle after %.2fs acknowledgement (%d clicks sent).",
                            os.clock()-confirmStart, total))
                    else
                        colourCompletedAllClicks = false
                        colourStatus(string.format(
                            "NOT CONFIRMED after %.2fs (%d clicks sent, state received=%s). Do not automatically repeat possibly accepted clicks.",
                            os.clock()-confirmStart, total, tostring(colourStateSeen)))
                    end
                else
                    colourStatus(string.format("Incomplete: %d VIM clicks sent. Remaining stages will not run automatically.", total))
                end
            end, function(e) return tostring(e) end)
            restore()
            if colourStateConnection then colourStateConnection:Disconnect() end
            if colourSolvedConnection then colourSolvedConnection:Disconnect() end
            if not ok then colourStatus("ERROR: " .. tostring(err)) end
            colourRunning = false
            puzzleControllerBusy = false

            if reopenMenu and not hubUnloaded and hubWindow then
                pcall(function() hubWindow:Open() end)
            end
            return ok and colourCompletedAllClicks and not hubUnloaded and not colourCancel
        end
        local leverRunning = false
        local leverCancelled = false
        local function leverFolder()
            local puzzles = Workspace:FindFirstChild("Puzzles")
            local puzzle = puzzles and puzzles:FindFirstChild("LeverPuzzle")
            return puzzle and puzzle:FindFirstChild("Levers")
        end

        local PICTURE_REQUEST_INTERVAL = 0.14
        local PICTURE_MAX_BACKOFF_INTERVAL = 0.24
        local PICTURE_REPOSITION_SETTLE = 0.25
        local pictureRunning = false
        local pictureFinished = false
        local pictureSuccess = false
        local pictureCancelled = false
        local pictureAllowReposition = false
        local lastPictureMessage, lastPictureLog = nil, -math.huge
        local function pictureStatus(message)
            -- Only report meaningful phase transitions; avoid flooding the
            -- console on the many per-tile acknowledgement polls.
            local now = os.clock()
            if message:find("Waiting for proximity", 1, true) then return end
            if message:find("No acknowledgement", 1, true) and now - lastPictureLog < 3 then return end
            if message ~= lastPictureMessage or now - lastPictureLog >= 3 then
                lastPictureMessage, lastPictureLog = message, now
                print("[BeyyHub Picture] " .. tostring(message))
            end
        end
        local function runPicturePuzzle()
            if pictureRunning then
                pictureStatus("Already running; not starting duplicate workers")
                return false
            end
            pictureRunning = true
            pictureFinished = false
            pictureSuccess = false
            local savedPivot = nil
            local pictureMovedPlayer = false
            local pictureRepositions = 0
            local lastPictureMoveAt = -math.huge
            local function cancelled()
                return hubUnloaded or pictureCancelled
            end
            local function pause(seconds)
                local stopAt = os.clock() + math.max(0, seconds)
                while os.clock() < stopAt do
                    if cancelled() then return false end
                    task.wait(math.min(0.05, math.max(0.01, stopAt - os.clock())))
                end
                return not cancelled()
            end
            local function main()
                local pf = Workspace:FindFirstChild("Puzzles")
                local room = pf and pf:FindFirstChild("PicturePuzzle")
                local puzzle = room and room:FindFirstChild("PicturePuzzle")
                local state = puzzle and puzzle:FindFirstChild("State")
                local board = puzzle and puzzle:FindFirstChild("BoardPart")
                local rf = ReplicatedStorage:FindFirstChild("Puzzles")
                local action = rf and rf:FindFirstChild("PuzzleAction")
                if not (puzzle and state and board and action and action:IsA("RemoteEvent")) then
                    pictureStatus("Cannot start: PicturePuzzle State/BoardPart or PuzzleAction missing")
                    return false
                end
                local values = {}
                for i = 1, 16 do
                    values[i] = state:FindFirstChild("Rotation" .. i)
                    if not (values[i] and values[i]:IsA("IntValue")) then
                        pictureStatus("Missing Rotation" .. i)
                        return false
                    end
                end
                local interactDistance = tonumber(puzzle:GetAttribute("MaxInteractDistance")) or 30
                pcall(function()
                    local config = require(rf:WaitForChild("PuzzleConfig"))
                    local entry = config and config.Puzzles and config.Puzzles.PicturePuzzle
                    if entry then
                        interactDistance = tonumber(entry.InteractDistance) or interactDistance
                    end
                end)
                local totalSent = 0
                local totalConfirmed = 0
                local totalNoAck = 0
                local pending = {}
                local retryAfter = {}
                local cursor = 0
                local nextSendAt = 0
                local noRangeLogged = false
                local startedAt = os.clock()
                local maxUntil = startedAt + 160
                local requestInterval = PICTURE_REQUEST_INTERVAL
                local consecutiveAcknowledgements = 0
                local outsideRangeAt, outsideRangeSeconds = nil, 0

                -- Preserve the conservative timeout to avoid late server acks
                -- producing unintended extra rotations on retries.
                local acknowledgementTimeout = 2.25
                local function closeEnough()
                    local c = LocalPlayer.Character
                    local root = c and c:FindFirstChild("HumanoidRootPart")
                    return root and (root.Position - board.Position).Magnitude <= interactDistance
                end
                local function checkSolved()
                    return puzzle:GetAttribute("Solved") == true
                end
                local function getNearBoardAfterOtherStages()
                    -- Only relocate after the other puzzle camera/teleports have
                    -- completed. If another script displaces us afterwards,
                    -- permit a limited recovery rather than stalling for 160s.
                    if not pictureAllowReposition or pictureRepositions >= 3
                        or os.clock() - lastPictureMoveAt < 0.8
                        or leverRunning or colourRunning then return false end
                    local character = LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if not root then return false end

                    if not savedPivot then savedPivot = character:GetPivot() end
                    lastPictureMoveAt = os.clock()
                    local spot = board.CFrame:PointToWorldSpace(Vector3.new(0, -2.5, -8))
                    local target = Vector3.new(board.Position.X, spot.Y, board.Position.Z)
                    local moved = pcall(function()
                        character:PivotTo(CFrame.lookAt(spot, target))
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end)
                    if moved then
                        pictureMovedPlayer = true
                        pictureRepositions += 1
                        pictureStatus("Moved within picture-board range (attempt " .. pictureRepositions .. ")")
                        pause(PICTURE_REPOSITION_SETTLE)
                    elseif not pictureMovedPlayer then
                        savedPivot = nil
                    end
                    return moved
                end
                local function readState()
                    local unfinished = 0
                    for i = 1, 16 do
                        local v = values[i].Value
                        if type(v) ~= "number" or v < 0 or v > 3 then
                            return nil, "Unexpected Rotation" .. i .. " value " .. tostring(v)
                        end
                        if v ~= 0 then unfinished += 1 end
                    end
                    return unfinished
                end
                local function updatePending(now)
                    for i, request in pairs(pending) do
                        local current = values[i].Value
                        if current ~= request.before then
                            totalConfirmed += 1
                            pending[i] = nil
                            retryAfter[i] = nil
                            consecutiveAcknowledgements += 1
                            if consecutiveAcknowledgements >= 8 then
                                requestInterval = math.max(PICTURE_REQUEST_INTERVAL, requestInterval - 0.01)
                                consecutiveAcknowledgements = 0
                            end
                        elseif now - request.sentAt >= acknowledgementTimeout then
                            pending[i] = nil
                            retryAfter[i] = now + 0.55
                            totalNoAck += 1
                            consecutiveAcknowledgements = 0
                            requestInterval = math.min(PICTURE_MAX_BACKOFF_INTERVAL, requestInterval + 0.025)
                            pictureStatus(string.format("No acknowledgement for Tile%d (%.2fs); total no-acks %d; slowing sends to %.3fs",
                                i, acknowledgementTimeout, totalNoAck, requestInterval))
                        end
                    end
                end
                local function chooseTarget(now)

                    for offset = 1, 16 do
                        local i = ((cursor + offset - 1) % 16) + 1
                        if values[i].Value ~= 0 and not pending[i] and
                            (not retryAfter[i] or now >= retryAfter[i]) then
                            return i
                        end
                    end
                    return nil
                end
                pictureStatus(string.format("Starting: %.3fs fast cadence, adaptive on missing acks | %.1f stud range",
                    PICTURE_REQUEST_INTERVAL, interactDistance))
                local allZeroAt = nil
                while not cancelled() and os.clock() < maxUntil do
                    if checkSolved() then
                        local waitSeconds = outsideRangeSeconds +
                            (outsideRangeAt and os.clock() - outsideRangeAt or 0)
                        pictureStatus(string.format("SOLVED=true | %.2fs total (%.2fs out of range) | sent %d, confirmed %d, no-ack %d",
                            os.clock() - startedAt, waitSeconds, totalSent, totalConfirmed, totalNoAck))
                        return true
                    end
                    local now = os.clock()
                    updatePending(now)
                    local unfinished, reason = readState()
                    if unfinished == nil then
                        pictureStatus("Stopped: " .. tostring(reason))
                        return false
                    end
                    if unfinished == 0 then
                        allZeroAt = allZeroAt or now
                        if now - allZeroAt >= 4.0 then
                            pictureStatus("All rotations zero, but Solved=true not replicated")
                            return false
                        end
                        if not pause(0.04) then break end
                    elseif not closeEnough() then
                        allZeroAt = nil
                        if not outsideRangeAt then outsideRangeAt = now end
                        local moved = false
                        if pictureAllowReposition then
                            moved = getNearBoardAfterOtherStages()
                        elseif not noRangeLogged then
                            pictureStatus("Waiting for proximity while Number/Colour operate")
                            noRangeLogged = true
                        end
                        if not pause(moved and 0.015 or 0.10) then break end
                    else
                        if outsideRangeAt then
                            outsideRangeSeconds += now - outsideRangeAt
                            outsideRangeAt = nil
                        end
                        allZeroAt = nil
                        noRangeLogged = false
                        if now >= nextSendAt then
                            local i = chooseTarget(now)
                            if i then
                                local before = values[i].Value
                                local ok, err = pcall(function()
                                    action:FireServer("PicturePuzzle", "Tile" .. i)
                                end)

                                if ok then
                                    pending[i] = {before = before, sentAt = os.clock()}
                                    totalSent += 1
                                    cursor = i
                                    nextSendAt = os.clock() + requestInterval
                                else
                                    pictureStatus("Tile" .. i .. " FireServer failed: " .. tostring(err))
                                    retryAfter[i] = os.clock() + 0.55
                                end
                            end
                        end
                        if not pause(0.012) then break end
                    end
                end
                if not cancelled() then
                    local waitSeconds = outsideRangeSeconds +
                        (outsideRangeAt and os.clock() - outsideRangeAt or 0)
                    pictureStatus(string.format("Timed out | %.2fs elapsed (%.2fs out of range) | sent %d, confirmed %d, no-ack %d",
                        os.clock() - startedAt, waitSeconds, totalSent, totalConfirmed, totalNoAck))
                end
                return false
            end
            local ok, outcome = xpcall(main, function(e) return tostring(e) end)
            if pictureMovedPlayer and savedPivot then
                local char = LocalPlayer.Character
                if char and char.Parent then
                    pcall(function() char:PivotTo(savedPivot) end)
                end
            end
            pictureSuccess = ok and outcome == true
            pictureFinished = true
            pictureRunning = false
            if not ok then pictureStatus("ERROR: " .. tostring(outcome)) end
            if pictureCancelled then pictureStatus("Cancelled") end
            return pictureSuccess
        end

        puzzleTab:Section({ Title = "Full Chapter 2 automation" })
        local allPuzzlesRunning = false
        sharedFarmPuzzleBusy = function()
            return __BEYY_CH2_V22_SOLVING() or allPuzzlesRunning or puzzleControllerBusy
        end
        keyPuzzleCameraBusy = function()
            return __BEYY_CH2_V22_SOLVING() or leverRunning or colourRunning or puzzleControllerBusy
        end
        local allPuzzlesCancel = false
        local allPuzzlesStage = "Idle"
        local function allStatus(message)
            allPuzzlesStage = message
            print("[AutoPuzzles] " .. tostring(message))
        end
        local isNumberStageCancelled = function()
            return hubUnloaded or allPuzzlesCancel
        end
        local function runNumberPuzzleInHub()
            local numberCode = [===[

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local PLACE_ID = 83445806734780

local REUSE_DISTANCE = 7.0
local TELEPORT_SETTLE = 0.18
local REUSE_SETTLE = 0.055
local RETRY_SETTLE = 0.53
local FIRST_FEEDBACK_WAIT = 1.00
local RETRY_FEEDBACK_WAIT = 1.55
local BETWEEN_POSTERS = 0.05
local KEYPAD_SETTLE = 0.32
local KEYPAD_RETRY_SETTLE = 0.70
local KEYPAD_FEEDBACK_WAIT = 2.20
local KEYPAD_RETRY_FEEDBACK_WAIT = 2.90
local PREFIX = "[NumberSolver] "

if not player then
    warn(PREFIX .. "LocalPlayer unavailable")
    return
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__BEYY_NUMBER_FINDER_CLOSE) == "function" then
    pcall(env.__BEYY_NUMBER_FINDER_CLOSE)
end

local connections = {}
local running, cancelled, closed = false, false, false
local pending, pendingSubmit, latestState, foundCode, foundIndex, correctPosterIndex
local runSerial = 0
local codeLength = 4
local config, numberConfig, actionRemote, feedbackRemote, stateRemote

local function safeString(value)
    if value == nil then return "nil" end
    return tostring(value):gsub("[\r\n]", " ")
end

local function log(message)
    if type(__beNumberStatus) == "function" then
        pcall(__beNumberStatus, safeString(message))
    end
end

local function getRoot()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return root and root:IsA("BasePart") and root or nil
end

local function getPosterFolder()
    local puzzles = workspace:FindFirstChild("Puzzles")
    local folder = puzzles and puzzles:FindFirstChild((numberConfig and numberConfig.Folder) or "NumberPuzzle")
    local path = (numberConfig and numberConfig.Posters) or "Posters"
    for piece in tostring(path):gmatch("[^/]+") do
        folder = folder and folder:FindFirstChild(piece)
    end
    return folder
end

local function getKeypad()
    local puzzles = workspace:FindFirstChild("Puzzles")
    local folder = puzzles and puzzles:FindFirstChild((numberConfig and numberConfig.Folder) or "NumberPuzzle")
    local path = (numberConfig and numberConfig.Keypad) or "Keypad"
    for piece in tostring(path):gmatch("[^/]+") do
        folder = folder and folder:FindFirstChild(piece)
    end
    return folder
end

local function puzzleCompleted()
    return latestState and latestState.completed == true or false
end

local function isTaken(index)
    local taken = latestState and latestState.taken
    return type(taken) == "table" and
        (taken[index] == true or taken[tostring(index)] == true) or false
end

local function availablePosters()
    local result, folder = {}, getPosterFolder()
    if not folder then return result end
    local attributeName = (config and config.PosterIndexAttribute) or "PosterIndex"
    local seen = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") then
            local index = child:GetAttribute(attributeName)
            if type(index) == "number" and index >= 1 and not seen[index] and not isTaken(index) then
                seen[index] = true
                result[#result + 1] = {index = index, part = child}
            end
        end
    end
    table.sort(result, function(a, b) return a.index < b.index end)
    return result
end

local function orderByNearest(posters, startPosition)
    local remaining, route, cursor = {}, {}, startPosition
    for _, item in ipairs(posters) do remaining[#remaining + 1] = item end
    while #remaining > 0 do
        local best, bestDistance = 1, math.huge
        for i, item in ipairs(remaining) do
            local distance = (item.part.Position - cursor).Magnitude
            if distance < bestDistance then
                best, bestDistance = i, distance
            end
        end
        local nextPoster = table.remove(remaining, best)
        route[#route + 1] = nextPoster
        cursor = nextPoster.part.Position
    end
    return route
end

local function validCode(value)
    return type(value) == "string" and #value == codeLength and value:match("^%d+$") ~= nil
end

local function readGuiCode()
    local pg = player:FindFirstChild("PlayerGui")
    local note = pg and pg:FindFirstChild("NumberPuzzleNote")
    local paper = note and note:FindFirstChild("Paper")
    local code = paper and paper:FindFirstChild("Code")
    if code and code:IsA("TextLabel") then return code.Text end
    return nil
end

local function registerCode(value, source, index)
    if not validCode(value) then return false end
    if foundCode ~= value then
        foundCode = value
        foundIndex = index or foundIndex
        log("CODE FOUND: " .. value .. " | via " .. safeString(source) ..
            " | poster=" .. safeString(foundIndex))
    end
    return true
end

local function readKnownCode(source)
    if validCode(foundCode) then return true end
    if latestState and registerCode(latestState.code, source .. " PuzzleState") then return true end
    return registerCode(readGuiCode(), source .. " GUI")
end

local function restorePosition(origin)
    local root = getRoot()
    if root and origin then
        local ok, err = pcall(function()
            root.CFrame = origin
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        log(ok and "Returned to original location" or ("Could not restore position: " .. safeString(err)))
    else
        log("Could not restore original location (character changed or root missing)")
    end
end

local function close()
    if closed then return end
    closed = true
    cancelled = true
    runSerial = runSerial + 1
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    if env.__BEYY_NUMBER_FINDER_CLOSE == close then
        env.__BEYY_NUMBER_FINDER_CLOSE = nil
    end
end

env.__BEYY_NUMBER_FINDER_CLOSE = close

local function waitForFeedback(target, seconds, serial)
    local started = os.clock()
    while os.clock() - started < seconds do
        if closed or cancelled or runSerial ~= serial then return "cancel" end
        if validCode(foundCode) then return "found" end
        if target.feedback then return "feedback" end
        if isTaken(target.index) then return "taken" end
        task.wait(0.025)
    end
    if readKnownCode("timeout") then return "found" end
    return "timeout"
end

local function teleportNear(poster)
    local root = getRoot()
    if not root or not poster or not poster.Parent then return false, "root/poster missing" end

    local destination = poster.Position + Vector3.new(0, 2.65, 0)
    local ok, err = pcall(function()
        root.CFrame = CFrame.new(destination) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not ok then return false, safeString(err) end
    return true, "moved"
end

local function moveToPosterIfNecessary(poster, maxDistance)
    local root = getRoot()
    local reuseLimit = math.min(REUSE_DISTANCE, maxDistance - 2.0)
    if root and reuseLimit > 0 and (root.Position - poster.Position).Magnitude <= reuseLimit then
        return true, "within range", false
    end
    local ok, reason = teleportNear(poster)
    return ok, reason, ok
end

local function teleportNearKeypad(keypad)
    local root = getRoot()
    if not root then return false, "HumanoidRootPart missing" end
    if not keypad or not keypad.Parent then return false, "keypad missing" end
    if not (keypad:IsA("Model") or keypad:IsA("BasePart")) then
        return false, "unexpected keypad class: " .. keypad.ClassName
    end
    local pivot = keypad:GetPivot()
    local destination = pivot.Position - pivot.LookVector * 4.0 + Vector3.new(0, 2.5, 0)
    local ok, err = pcall(function()
        root.CFrame = CFrame.new(destination) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not ok then return false, safeString(err) end
    return true, "moved"
end

local function submitDiscoveredCode(serial)
    if not validCode(foundCode) then
        log("KEYPAD STOP: no valid " .. tostring(codeLength) .. "-digit code")
        return false
    end
    if puzzleCompleted() then
        log("KEYPAD SKIPPED: NumberPuzzle already completed")
        return true
    end
    local keypad = getKeypad()
    if not keypad then
        log("KEYPAD STOP: Workspace.Puzzles.NumberPuzzle.Keypad unavailable (not streamed?)")
        return false
    end
    local range = (numberConfig and numberConfig.InteractDistance) or 10
    if type(range) ~= "number" or range <= 0 then range = 10 end
    log("CODE FOUND: " .. foundCode .. " | approaching keypad | max interaction range=" .. tostring(range))
    for attempt = 1, 2 do
        if cancelled or closed or serial ~= runSerial then
            log("KEYPAD CANCELLED before attempt " .. tostring(attempt))
            return false
        end
        if puzzleCompleted() then
            log("KEYPAD CONFIRMED: PuzzleState completed=true")
            return true
        end
        local moved, reason = teleportNearKeypad(keypad)
        if not moved then
            log("KEYPAD STOP: teleport failed: " .. safeString(reason))
            return false
        end
        task.wait(attempt == 1 and KEYPAD_SETTLE or KEYPAD_RETRY_SETTLE)
        if cancelled or closed or serial ~= runSerial then return false end
        local root = getRoot()
        local distance = root and (root.Position - keypad:GetPivot().Position).Magnitude or math.huge
        if distance >= range - 0.5 then
            log(string.format("KEYPAD STOP: too far from keypad (%.2f / %.2f studs)", distance, range))
            return false
        end

        local probe = {received = false, accepted = nil}
        pendingSubmit = probe
        log(string.format("KEYPAD SUBMIT attempt %d/2 | code=%s | distance=%.2f | FireServer", attempt, foundCode, distance))
        local fired, fireErr = pcall(function()
            actionRemote:FireServer("NumberPuzzle", "Submit", foundCode)
        end)
        if not fired then
            pendingSubmit = nil
            log("KEYPAD STOP: FireServer failed: " .. safeString(fireErr))
            return false
        end
        local started = os.clock()
        local timeout = attempt == 1 and KEYPAD_FEEDBACK_WAIT or KEYPAD_RETRY_FEEDBACK_WAIT
        local gotCompletion, gotFeedback, wasAccepted = false, false, false
        while os.clock() - started < timeout do
            if cancelled or closed or serial ~= runSerial then
                pendingSubmit = nil
                return false
            end
            if puzzleCompleted() then
                gotCompletion = true
                break
            end
            if probe.received then
                gotFeedback, wasAccepted = true, probe.accepted == true
                break
            end
            task.wait(0.03)
        end
        pendingSubmit = nil
        if gotCompletion then
            log("KEYPAD SUCCESS: PuzzleState confirms completed=true")
            return true
        end
        if gotFeedback then
            if wasAccepted then
                log("KEYPAD SUCCESS: server PuzzleFeedback Submit=true")

                for _ = 1, 12 do
                    if closed or cancelled or runSerial ~= serial or puzzleCompleted() then break end
                    task.wait(0.05)
                end
                if not puzzleCompleted() then
                    log("Submit accepted, but no completed state observed yet (feedback is authoritative)")
                end
                return true
            end
            log("KEYPAD REJECTED: server PuzzleFeedback Submit=false. Not retrying an explicit rejection")
            return false
        end
        log("KEYPAD TIMEOUT attempt " .. attempt .. ": no Submit feedback or completed state")
        if attempt == 1 then

            pcall(function() stateRemote:FireServer() end)
            task.wait(0.25)
            if puzzleCompleted() then
                log("KEYPAD SUCCESS: state refresh confirmed completed=true")
                return true
            end
            log("Retrying keypad once with a longer teleport settle")
        end
    end
    log("KEYPAD UNCONFIRMED: no response after two attempts; check keypad distance or server requirements")
    return false
end

local function runFinder()
    if running then log("Finder is already running"); return end
    if closed then return end
    if game.PlaceId ~= PLACE_ID then
        log("Wrong place: join Chapter 2 (PlaceId " .. tostring(PLACE_ID) .. ")")
        return
    end
    if not actionRemote or not feedbackRemote or not stateRemote then
        log("PuzzleAction/PuzzleFeedback/PuzzleState are missing")
        return
    end
    local startRoot = getRoot()
    if not startRoot then log("HumanoidRootPart missing; wait for character to spawn"); return end
    if puzzleCompleted() then
        log("NumberPuzzle already completed; nothing to solve")
        return
    end
    local existingCode = readKnownCode("startup")
    local candidates = {}
    if existingCode then
        log("Existing code detected; skipping poster search and going straight to the keypad")
    else
        local folder = getPosterFolder()
        if not folder then log("Poster folder missing; wait for puzzle to stream in"); return end
        candidates = availablePosters()
        if #candidates == 0 then log("No uncollected indexed poster parts remain"); return end
        candidates = orderByNearest(candidates, startRoot.Position)
    end

    local originalCFrame = startRoot.CFrame
    running, cancelled = true, false
    runSerial = runSerial + 1
    local serial = runSerial
    local range = (numberConfig and numberConfig.PosterDistance) or 10
    log("START FULL AUTO v1.2 | " .. tostring(#candidates) .. " posters | range=" .. safeString(range) ..
        " | code length=" .. tostring(codeLength) .. " | route=nearest | reuse <=" .. tostring(math.min(REUSE_DISTANCE, range - 2.0)) .. " studs")

    do
        local attempted, accepted, skipped = 0, 0, 0
        local teleports, reused = 0, 0
        local ok, err = pcall(function()
            for _, item in ipairs(candidates) do
                if cancelled or closed or runSerial ~= serial or readKnownCode("between posters") then break end
                if latestState and latestState.completed then
                    log("Puzzle already completed according to PuzzleState")
                    break
                end
                local index, poster = item.index, item.part
                if not poster or not poster.Parent or isTaken(index) then
                    log("Skipping index " .. tostring(index) .. " (gone/taken)")
                else
                    attempted = attempted + 1

                    local matched = false

                    for attempt = 1, 2 do
                        if cancelled or closed or runSerial ~= serial then break end
                        if not poster.Parent or isTaken(index) then break end
                        local moved, reason, didTeleport
                        if attempt == 1 then
                            moved, reason, didTeleport = moveToPosterIfNecessary(poster, range)
                        else

                            moved, reason = teleportNear(poster)
                            didTeleport = moved
                        end
                        if not moved then
                            log("Poster #" .. index .. " positioning failed: " .. reason)
                            break
                        end
                        if didTeleport then teleports = teleports + 1 else reused = reused + 1 end

                        task.wait(attempt == 1 and (didTeleport and TELEPORT_SETTLE or REUSE_SETTLE) or RETRY_SETTLE)
                        if cancelled or closed or runSerial ~= serial then break end
                        local root = getRoot()
                        local distance = root and (root.Position - poster.Position).Magnitude or math.huge
                        if distance > range - 0.75 then
                            log(string.format("Poster #%d still %.2f studs away; repositioning", index, distance))
                            teleportNear(poster)
                            task.wait(0.20)
                            root = getRoot()
                            distance = root and (root.Position - poster.Position).Magnitude or math.huge
                        end
                        if distance > range - 0.3 then
                            log("Skipping poster #" .. index .. ": cannot reach interaction range (" ..
                                string.format("%.2f", distance) .. " studs)")
                            break
                        end
                        local target = {index = index, feedback = false, correct = nil}
                        pending = target
                        local fired, fireError = pcall(function()
                            actionRemote:FireServer("NumberPuzzle", "Poster", index)
                        end)
                        if not fired then
                            log("PuzzleAction failed for #" .. index .. ": " .. safeString(fireError))
                            pending = nil
                            break
                        end
                        local outcome = waitForFeedback(target, attempt == 1 and FIRST_FEEDBACK_WAIT or RETRY_FEEDBACK_WAIT, serial)
                        pending = nil
                        if outcome == "feedback" or outcome == "taken" or outcome == "found" then
                            matched = true
                            accepted = accepted + 1

                            if target.correct == true and not validCode(foundCode) then
                                for waitIndex = 1, 10 do
                                    if cancelled or closed or runSerial ~= serial then break end
                                    if waitIndex == 3 then
                                        pcall(function() stateRemote:FireServer() end)
                                    end
                                    task.wait(0.20)
                                    if readKnownCode("correct feedback wait") then break end
                                end
                            end
                            break
                        elseif outcome == "cancel" then
                            break
                        else
                            log("No response for poster #" .. index ..
                                (attempt == 1 and "; retrying with longer settle" or "; skipping"))
                        end
                    end
                    if not matched and not validCode(foundCode) then skipped = skipped + 1 end
                    if validCode(foundCode) or correctPosterIndex then break end
                    task.wait(BETWEEN_POSTERS)
                end
            end
        end)
        if not ok then log("SCAN ERROR: " .. safeString(err)) end
        pending = nil
        local submitted = false
        if ok and not cancelled and not closed and runSerial == serial and validCode(foundCode) then
            local submitOK, submitResult = pcall(submitDiscoveredCode, serial)
            if submitOK then
                submitted = submitResult == true
            else
                log("KEYPAD ERROR: " .. safeString(submitResult))
            end
        end
        pendingSubmit = nil
        restorePosition(originalCFrame)
        running = false
        if submitted then
            log("FULL AUTO SUCCESS | code=" .. foundCode .. " | poster=" .. safeString(foundIndex) ..
                " | visited=" .. attempted .. " | processed=" .. accepted ..
                " | teleports=" .. teleports .. " | reused=" .. reused)
        elseif cancelled or closed then
            log("SOLVER CANCELLED | visited=" .. attempted .. " | processed=" .. accepted)
        elseif validCode(foundCode) then
            log("CODE FOUND BUT KEYPAD NOT CONFIRMED | code=" .. foundCode ..
                " | press START to retry keypad without searching notes")
        elseif correctPosterIndex then
            log("CORRECT POSTER FOUND (#" .. correctPosterIndex ..
                ") but its code was not exposed yet; examine PuzzleState / NumberPuzzleNote UI")
        else
            log("SCAN FINISHED WITHOUT CODE | visited=" .. attempted .. " | processed=" .. accepted ..
                " | no-confirmation=" .. skipped .. " | check logs; server may have denied some requests")
        end
        log("Movement summary: teleports=" .. teleports .. " | reused position=" .. reused)
        return submitted
    end
end

local puzzles = ReplicatedStorage:FindFirstChild("Puzzles") or ReplicatedStorage:WaitForChild("Puzzles", 10)
local configModule = puzzles and puzzles:FindFirstChild("PuzzleConfig")
if configModule and configModule:IsA("ModuleScript") then
    local ok, value = pcall(require, configModule)
    if ok and type(value) == "table" then
        config = value
        numberConfig = value.Puzzles and value.Puzzles.NumberPuzzle
        if numberConfig and type(numberConfig.CodeLength) == "number" then
            codeLength = numberConfig.CodeLength
        end
    else
        log("Runtime PuzzleConfig require failed: " .. safeString(value))
    end
end

actionRemote = puzzles and puzzles:FindFirstChild("PuzzleAction")
feedbackRemote = puzzles and puzzles:FindFirstChild("PuzzleFeedback")
stateRemote = puzzles and puzzles:FindFirstChild("PuzzleState")
if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
    connections[#connections + 1] = feedbackRemote.OnClientEvent:Connect(function(puzzle, action, index, correct, returnedCode)
        if closed or puzzle ~= "NumberPuzzle" then return end
        if action == "Submit" then
            if pendingSubmit then
                pendingSubmit.received = true
                pendingSubmit.accepted = (index == true)
                log("KEYPAD FEEDBACK | Submit=" .. safeString(index))
            else
                log("Unsolicited keypad Submit feedback=" .. safeString(index))
            end
            return
        end
        if action ~= "Poster" then return end
        local numericIndex = tonumber(index)
        if pending and numericIndex == pending.index then
            pending.feedback = true
            pending.correct = correct
            log("MATCHING FEEDBACK | poster=" .. safeString(index) ..
                " | correct=" .. safeString(correct) ..
                " | returnedCode=" .. (validCode(returnedCode) and returnedCode or "(none)"))
            if correct == true and not validCode(returnedCode) then
                log("Correct poster confirmed, but code not in feedback. Checking puzzle state/GUI")
            end
        end
        if correct == true then
            foundIndex = numericIndex or foundIndex
            correctPosterIndex = numericIndex or correctPosterIndex
        end
        if validCode(returnedCode) then
            registerCode(returnedCode, "PuzzleFeedback", numericIndex)
        end
    end)
else
    log("PuzzleFeedback RemoteEvent unavailable")
end
if stateRemote and stateRemote:IsA("RemoteEvent") then
    connections[#connections + 1] = stateRemote.OnClientEvent:Connect(function(payload)
        if closed or type(payload) ~= "table" or type(payload.NumberPuzzle) ~= "table" then return end
        latestState = payload.NumberPuzzle
        if not validCode(foundCode) then
            registerCode(latestState.code, "PuzzleState")
        end
    end)
else
    log("PuzzleState RemoteEvent unavailable")
end

log("Integrated full-auto number solver starting")
if stateRemote and stateRemote:IsA("RemoteEvent") then
    pcall(function() stateRemote:FireServer() end)
end
task.wait(0.18)
local watcherActive = true
task.spawn(function()
    while watcherActive do
        if type(__beCancelled) == "function" and __beCancelled() then
            cancelled = true
            break
        end
        task.wait(0.05)
    end
end)
local solved = false
local worked, result = xpcall(runFinder, function(err) return tostring(err) end)
watcherActive = false
if worked then
    solved = result == true
else
    log("INTEGRATED RUN ERROR: " .. tostring(result))
end
close()
return solved]===]
            local runner, compileErr = loadstring(
                "return function(__beNumberStatus, __beCancelled)\n" .. numberCode .. "\nend")
            if not runner then
                allStatus("Number solver compile failed: " .. tostring(compileErr))
                return false
            end
            local okFactory, entry = pcall(runner)
            if not okFactory or type(entry) ~= "function" then
                allStatus("Number solver initialization failed: " .. tostring(entry))
                return false
            end
            local ok, solved = pcall(entry, function(message)
                allStatus("Number: " .. tostring(message))
            end, isNumberStageCancelled)
            if not ok then
                allStatus("Number solver runtime error: " .. tostring(solved))
                return false
            end
            return solved == true
        end
        local function waitAll(seconds)
            local endAt = os.clock() + seconds
            while os.clock() < endAt do
                if isNumberStageCancelled() then return false end
                task.wait(0.06)
            end
            return not isNumberStageCancelled()
        end

        -- Confirmed live profile: parallel puzzle queues, bounded retries, native acknowledgements.
        local function runConfirmedPuzzles()
            local H=game:GetService("HttpService")
            local R=game:GetService("ReplicatedStorage")
            local Players=game:GetService("Players")
            local Run=game:GetService("RunService")
            local P=Players.LocalPlayer
            assert(game.PlaceId==83445806734780,"Chapter 2 required")
            local C=P.Character
            local root=C and C:FindFirstChild("HumanoidRootPart")
            local F=R:FindFirstChild("Puzzles")
            local W=workspace:FindFirstChild("Puzzles")
            assert(root and F and W,"World/character not ready")
            assert(P:GetAttribute("IntroCutsceneFinished")==true,"Finish intro before testing")
            local origin=root.CFrame
            local floorY=root.Position.Y
            local start=os.clock()
            local T={version="main-confirmed-profile",jobId=game.JobId,placeId=tostring(game.PlaceId),startedUtc=os.date("!%Y-%m-%dT%H:%M:%SZ"),requests={},events={},observations={},stages={},state={},connections={},cadence=0.12,leverSettle=0.10}
            local nextSend=0
            local stateVersion=0
            local codeFound=nil
            local temporaryUnanchor=nil
            local function elapsed() return os.clock()-start end
            local function guard()
             assert(not hubUnloaded and not allPuzzlesCancel,"Puzzle sequence cancelled")
             assert(P.Character==C and root.Parent,"Character changed")
            end
            local function safe(v,depth)
             local ty=typeof(v)
             if ty=="nil" then return nil end
             if ty=="string" or ty=="boolean" or ty=="number" then return v end
             if ty=="Instance" then return {path=v:GetFullName(),class=v.ClassName} end
             if ty=="table" and (depth or 5)>0 then local a={} for k,x in pairs(v) do a[tostring(k)]=safe(x,(depth or 5)-1) end return a end
             return tostring(v)
            end
            local function observe(name,v) table.insert(T.observations,{t=elapsed(),name=name,value=safe(v)}) end
            local function waitFor(fn,seconds)
             local deadline=os.clock()+seconds
             repeat guard() if fn() then return true end task.wait(0.01) until os.clock()>=deadline
             return fn()
            end
            local function valid(s) return type(s)=="string" and #s==4 and s:match("^%d+$")~=nil end
            local feedback={}
            for _,name in ipairs({"PuzzleState","PuzzleFeedback","PuzzleSolved","Chapter2Release"}) do
             local remote=F:FindFirstChild(name)
             if remote then table.insert(T.connections,remote.OnClientEvent:Connect(function(...)
              local a=table.pack(...)
              if name=="PuzzleState" and type(a[1])=="table" then
               T.state=a[1] stateVersion=stateVersion+1
               local n=T.state.NumberPuzzle
               if n and valid(n.code) then codeFound=n.code end
              elseif name=="PuzzleFeedback" and a[1]=="NumberPuzzle" and a[2]=="Poster" then
               feedback[tonumber(a[3])]={t=elapsed(),correct=a[4],code=a[5]}
               if valid(a[5]) then codeFound=a[5] end
              end
              -- State is read from native replies; no persistent event recorder.
             end)) end
            end
            local function stateSnapshot()
             return {attributes=safe(F:GetAttributes()),state=safe(T.state),position=tostring(root.Position),player={locked=P:GetAttribute("NeedleInputLocked"),cutscene=P:GetAttribute("CutsceneActive"),release=P:GetAttribute("Chapter2ReleaseActive"),owned=P:GetAttribute("NeedleOwned")}}
            end
            local function send(puzzle,step,arg)
             while os.clock()<nextSend do guard() task.wait(0.005) end
             guard()
             local d={t=elapsed(),puzzle=puzzle,step=step,arg=arg,cadence=T.cadence,position=tostring(root.Position),stateVersion=stateVersion}
             if arg~=nil then F.PuzzleAction:FireServer(puzzle,step,arg) else F.PuzzleAction:FireServer(puzzle,step) end
             nextSend=os.clock()+T.cadence
             table.insert(T.requests,d)
             return d
            end
            local function go(pos,settle)
             guard()
             assert(not finalEndingProtected,"Final ending is protected")
             if root.Anchored then
              assert(P:GetAttribute("NeedleRoundComplete")~=true,"Final ending has started")
              assert(P:GetAttribute("CutsceneActive")==true or P:GetAttribute("Chapter2ReleaseActive")==true,"Character anchored outside puzzle cutscene")
              if temporaryUnanchor==nil then temporaryUnanchor=true end
              root.Anchored=false
              observe("temporary_nonfinal_cutscene_movement","Unanchored character only; no source, camera, or cutscene flags changed")
             end
             root.CFrame=CFrame.new(pos)*root.CFrame.Rotation
             root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
             task.wait(settle or 0.28)
             observe("movement",{destination=tostring(pos),error=(root.Position-pos).Magnitude,settle=settle or 0.28})
            end
            local function lever(i)
             local began=os.clock()
             local folder=W:FindFirstChild("LeverPuzzle")
             folder=folder and folder:FindFirstChild("Levers")
             local model=folder and folder:FindFirstChild("Lever"..i)
             assert(model,"Missing Lever"..i)
             local result={index=i,attempts={},initialSettle=0.10}
             table.insert(T.stages.levers.items,result)
             local function pulled()
              local state=T.state.LeverPuzzle
              return F:GetAttribute("Lever"..i.."Pulled")==true or state and state.steps and state.steps["Lever"..i]==true
             end
             if pulled() then result.already=true result.passed=true return end
             local position=model:GetPivot().Position
             go(Vector3.new(position.X,floorY,position.Z+3),0.10)
             for attempt=1,3 do
              guard()
              if pulled() then break end
              local requestedAt=os.clock()
              send("LeverPuzzle","Lever"..i)
              local timeout=attempt==1 and 0.28 or 0.35
              local confirmed=waitFor(pulled,timeout)
              table.insert(result.attempts,{attempt=attempt,confirmed=confirmed,seconds=os.clock()-requestedAt,timeout=timeout})
              if confirmed then break end
              -- Retain the proven approximate 0.40-second movement-to-request fallback.
              if attempt==1 then
               local untilAt=began+0.405
               while os.clock()<untilAt and not pulled() do task.wait(0.005) end
              else task.wait(0.08) end
             end
             if not pulled() then
              result.recoveryTriggered=true
              print("[AutoPuzzles] Lever"..i.." confirmation delayed after 3 requests; checking late server state (players="..#Players:GetPlayers()..")")
              if not waitFor(pulled,0.75) then
               for recovery=1,2 do
                guard()
                if pulled() then break end
                go(Vector3.new(position.X,floorY,position.Z+3),0.22)
                if pulled() then break end
                local requestedAt=os.clock()
                send("LeverPuzzle","Lever"..i)
                local timeout=recovery==1 and 0.75 or 0.90
                local confirmed=waitFor(pulled,timeout)
                table.insert(result.attempts,{attempt=3+recovery,confirmed=confirmed,seconds=os.clock()-requestedAt,timeout=timeout,recovery=true})
                if confirmed then break end
                task.wait(0.15)
               end
              end
             end
             result.passed=pulled() result.seconds=os.clock()-began
             result.fastFirstAttemptPassed=result.attempts[1] and result.attempts[1].confirmed or false
             assert(result.passed,"Lever"..i.." not confirmed after bounded recovery; stopped before puzzle actions")
             print("[AutoPuzzles] Fast lever"..i.." confirmed in "..string.format("%.3f",result.seconds).."s attempts="..#result.attempts..
              (result.recoveryTriggered and " (multiplayer recovery)" or ""))
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
             S.stateRefreshes=0 S.recoveryBackoffs=0 S.lateChecks=0
             local function dispatch(item)
              guard()
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
             S.actualCode=codeFound S.finalIntervals=intervals
             for _,name in ipairs({"PicturePuzzle","ColorPuzzle","NumberPuzzle"}) do if solved(name) and not S[name.."ConfirmedAt"] then S[name.."ConfirmedAt"]=elapsed() end end
             assert(S.picturePassed and S.colorPassed and S.numberPassed,"Concurrent pass incomplete")
             print("[AutoPuzzles] All puzzles confirmed in "..string.format("%.3f",S.seconds).."s, missing="..S.pendingMissing)
            end
            local function run()
             local initialSource="state-request"
             pcall(function()
              for _,connection in ipairs(getconnections(F.PuzzleState.OnClientEvent)) do
               local f=connection.Function
               if type(f)=="function" then for _,value in pairs(debug.getupvalues(f)) do
                if type(value)=="table" and type(value.NumberPuzzle)=="table" and type(value.LeverPuzzle)=="table" and type(value.PicturePuzzle)=="table" and type(value.ColorPuzzle)=="table" then T.state=value initialSource="existing-native-callback-state" break end
               end end
               if initialSource~="state-request" then break end
              end
             end)
             if initialSource=="state-request" then F.PuzzleState:FireServer() assert(waitFor(function() return T.state.NumberPuzzle~=nil end,2),"No initial state") end
             T.initialStateSource=initialSource T.before=stateSnapshot()
             T.stages.levers={items={},started=elapsed()}
             leverRunning=true
             lever(1) lever(2) lever(3)
             leverRunning=false
             if autoCutsceneEnableAfterLevers then autoCutsceneEnableAfterLevers("all three fast lever requests confirmed") end
             T.stages.levers.ended=elapsed()
             concurrentPuzzles()
             local all=waitFor(function() return F:GetAttribute("LeverPuzzleSolved")==true and F:GetAttribute("SolvedPuzzleCount")==3 end,1)
             T.result={passed=all,allPuzzlesAndLeversSeconds=elapsed(),scope="All three levers; early lever requests with confirmation fallback; confirmed parallel puzzle queues without exploratory probes",confirmedProfile=true}
             assert(all,"Final replicated completion not confirmed")
            end
            local ok,err=xpcall(run,function(e) return tostring(e) end)
            leverRunning=false
            T.executionOk=ok T.error=not ok and err or nil
            T.after=stateSnapshot()
            T.totalSeconds=elapsed()
            for _,c in ipairs(T.connections) do pcall(function() c:Disconnect() end) end
            T.connections=nil
            if temporaryUnanchor and root.Parent and P:GetAttribute("NeedleRoundComplete")~=true and (P:GetAttribute("CutsceneActive")==true or P:GetAttribute("Chapter2ReleaseActive")==true) then
             root.Anchored=true T.temporaryAnchorRestored=true
            end
            local solverSucceeded=ok and T.result and T.result.passed==true
            if not solverSucceeded and P.Character==C and root.Parent and P:GetAttribute("CutsceneActive")~=true and P:GetAttribute("Chapter2ReleaseActive")~=true and P:GetAttribute("NeedleRoundComplete")~=true then
             root.CFrame=origin root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero T.positionRestored=true
            else
             T.positionRestored=false
             if solverSucceeded then print("[AutoPuzzles] Puzzles confirmed; keeping current position for post-puzzle objectives") end
            end
            
            local report={
             passed=ok and T.result and T.result.passed==true or false,error=T.error,
             seconds=T.result and T.result.allPuzzlesAndLeversSeconds or T.totalSeconds,
             leverSeconds=T.stages.levers and T.stages.levers.ended and T.stages.levers.ended-T.stages.levers.started,
             missingPuzzleRequests=T.stages.concurrent and T.stages.concurrent.pendingMissing,
             stateRefreshes=T.stages.concurrent and T.stages.concurrent.stateRefreshes,
             lateChecks=T.stages.concurrent and T.stages.concurrent.lateChecks,
             recoveryBackoffs=T.stages.concurrent and T.stages.concurrent.recoveryBackoffs,
             posterRequests=T.stages.concurrent and T.stages.concurrent.postersSent,
             leverAttempts={}
            }
            if T.stages.levers then for _,item in ipairs(T.stages.levers.items) do
             table.insert(report.leverAttempts,{lever=item.index,requests=#item.attempts,confirmed=item.passed})
            end end
            _G.__BEYY_CH2_LAST_RESULT=report
            print("[AutoPuzzlesResult] "..H:JSONEncode(report))
            return report.passed,T.error
            
        end

        puzzleTab:Paragraph({
            Title = "Fast Puzzle Automation",
            Desc = "Complete the levers, solve the three puzzles together, then collect and turn in the exposed key.",
        })
        local function stopAllPuzzles()
            if not allPuzzlesRunning then
                allStatus("No complete puzzle sequence is running")
                return
            end
            allPuzzlesCancel = true
            leverCancelled = true
            colourCancel = true
            pictureCancelled = true
            allStatus("Stop requested; restoring controls and position")
        end
        local originalHubCleanup = _G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP = function()
            allPuzzlesCancel = true
            leverCancelled = true
            colourCancel = true
            pictureCancelled = true
            if originalHubCleanup then originalHubCleanup() end
        end
        local function waitForHubMenuClear()
            if not hubWindow then
                allStatus("Stopped: menu window unavailable; cannot safely aim at Lever 1")
                return false
            end
            local function windUIOverCrosshair()
                local camera = Workspace.CurrentCamera
                if not camera then return true end
                local centre = camera.ViewportSize * 0.5
                local inset = GuiService:GetGuiInset()
                local x, y = centre.X, centre.Y - inset.Y
                local guiRoots = { game:GetService("CoreGui") }
                local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if playerGui then guiRoots[#guiRoots + 1] = playerGui end
                for _, root in ipairs(guiRoots) do
                    if root then
                        local ok, objects = pcall(function()
                            return root:GetGuiObjectsAtPosition(x, y)
                        end)
                        if ok then
                            for _, gui in ipairs(objects) do
                                local ancestor = gui
                                while ancestor do
                                    if ancestor:IsA("ScreenGui") then
                                        local name = string.lower(ancestor.Name)
                                        if string.find(name, "windui", 1, true)
                                            or string.find(name, "beyy", 1, true) then
                                            return true
                                        end
                                        break
                                    end
                                    ancestor = ancestor.Parent
                                end
                            end
                        end
                    end
                end
                return false
            end
            if hubWindow.Closed ~= true then
                local ok, err = pcall(function() hubWindow:Close() end)
                if not ok then
                    allStatus("Stopped: could not close menu: " .. tostring(err))
                    return false
                end
            end
            local deadline = os.clock() + 4.0
            local clearSince = nil
            local clearFrames = 0
            while not hubUnloaded and not allPuzzlesCancel and os.clock() < deadline do
                if hubWindow.Closed == true and not windUIOverCrosshair() then
                    clearSince = clearSince or os.clock()
                    clearFrames += 1
                    if clearFrames >= 2 and os.clock() - clearSince >= 0.05 then
                        RunService.RenderStepped:Wait()
                        if hubWindow.Closed == true and not windUIOverCrosshair() then
                            return true
                        end
                        clearSince = nil
                        clearFrames = 0
                    end
                else
                    clearSince = nil
                    clearFrames = 0
                end
                RunService.RenderStepped:Wait()
            end
            if not hubUnloaded and not allPuzzlesCancel then
                allStatus("Stopped: menu not fully hidden after 4s; Lever 1 was not attempted")
            end
            return false
        end
        local function runAllPuzzles()
            -- The former Main solver is retired: standalone v22 is now
            -- embedded and exclusively owns automatic puzzle progression.
            allStatus("Standalone v22 owns automatic levers and all puzzles")
            __BEYY_CH2_V22_START()
            -- Legacy implementation retained only as inert reference.
            if false then
            if allPuzzlesRunning then allStatus("Already running"); return end
            if hubUnloaded or puzzleControllerBusy or leverRunning or colourRunning then
                allStatus("Cannot start while another puzzle controller is active")
                return
            end
            if LocalPlayer:GetAttribute("NeedleRoundComplete")==true then
                allStatus("Round already complete")
                return
            end
            allPuzzlesRunning, allPuzzlesCancel = true, false
            pictureCancelled, leverCancelled, colourCancel = false, false, false
            local reopenAfter = hubWindow and hubWindow.Closed == false
            local started = os.clock()
            local ok, err = xpcall(function()
                if not waitForHubMenuClear() or isNumberStageCancelled() then return end
                puzzleControllerBusy = true
                allStatus("Completing levers and solving picture, gem, and number puzzles together")
                local solved, detail = runConfirmedPuzzles()
                if not solved then
                    if not isNumberStageCancelled() then allStatus("Stopped: "..tostring(detail or "server completion was not confirmed")) end
                    return
                end
                postPuzzleKeyPriority = true
                allStatus(string.format("All puzzles and levers confirmed in %.2fs; automatic key pickup and turn-in ready",os.clock()-started))
            end,function(e) return tostring(e) end)
            leverRunning, puzzleControllerBusy, allPuzzlesRunning = false, false, false
            if not ok then allStatus("ERROR: "..tostring(err)) end
            if allPuzzlesCancel or hubUnloaded then allStatus("Sequence cancelled") end
            if reopenAfter and not hubUnloaded and hubWindow
                and LocalPlayer:GetAttribute("CutsceneActive")~=true
                and LocalPlayer:GetAttribute("Chapter2ReleaseActive")~=true
                and not keyObjectivePhase() then
                pcall(function() hubWindow:Open() end)
            end
            end -- disabled legacy full solver
        end
        puzzleTab:Button({
            Title = "Auto Solve Puzzles",
            Desc = "Uses embedded v22 to complete levers and all three puzzles during the intro; native key collection remains separate.",
            Callback = function()
                __BEYY_CH2_V22_START()
                allStatus("Embedded v22 is responsible for auto puzzles")
            end,
        })
        puzzleTab:Button({
            Title = "Stop Auto Solve Puzzles",
            Desc = "Cancel any remaining stages and restore movement/camera when safe.",
            Callback = function()
                __BEYY_CH2_V22_STOP()
                stopAllPuzzles()
                allStatus("Embedded v22 auto puzzle controller stopped")
            end,
        })
        puzzleTab:Paragraph({
            Title = "Number puzzle integrated into v22",
            Desc = "Number, Picture, and Color run together. Previous independent auto-number worker is disabled.",
        })

        -- Automatic Basement entry: skip the skippable intro first, then
        -- execute the EXISTING complete puzzle controller once the server
        -- confirms the intro is over and the lever targets are replicated.
        -- No lever, number, colour, or picture logic is duplicated.
        local function introSkipAllowed()
            if finalEndingProtected or postPuzzleKeyPriority
                or LocalPlayer:GetAttribute("IntroCutsceneFinished") == true
                or LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
                or LocalPlayer:GetAttribute("NeedleOwned") == true then return false end
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local ending = pg and pg:FindFirstChild("NeedleEndingUI")
            if ending and ending:IsA("ScreenGui") and ending.Enabled then return false end
            -- Re-executing the loader late in a match must not mistake the
            -- finishing cutscene's SKIP button for the opening intro.
            local puzzleFolder = Workspace:FindFirstChild("Puzzles")
            if puzzleFolder then
                for _, puzzleName in ipairs({"LeverPuzzle", "NumberPuzzle", "ColorPuzzle", "PicturePuzzle"}) do
                    local holder = puzzleFolder:FindFirstChild(puzzleName)
                    local puzzle = holder and (holder:FindFirstChild(puzzleName) or holder)
                    if puzzle and (puzzle:GetAttribute("Solved") == true
                        or puzzle:GetAttribute("Completed") == true) then
                        return false
                    end
                end
            end
            return true
        end
        local function findVisibleIntroSkip()
            if not introSkipAllowed() then return nil end
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if not pg then return nil end
            local ending = pg:FindFirstChild("NeedleEndingUI")
            for _, button in ipairs(pg:GetDescendants()) do
                if button:IsA("GuiButton") and button.Visible
                    and not (ending and button:IsDescendantOf(ending)) then
                    local name = button.Name:lower()
                    local marked = name:find("skip", 1, true) ~= nil
                    if not marked and button:IsA("TextButton") then
                        marked = button.Text:lower():find("skip", 1, true) ~= nil
                    end
                    if not marked then
                        for _, child in ipairs(button:GetChildren()) do
                            if child:IsA("TextLabel") and child.Text:lower():find("skip", 1, true) then
                                marked = true
                                break
                            end
                        end
                    end
                    if marked then
                        local current, visible, underHub = button, true, false
                        while current and current ~= pg do
                            if current:IsA("GuiObject") and not current.Visible then visible = false; break end
                            if current:IsA("ScreenGui") and not current.Enabled then visible = false; break end
                            if current.Name == "BeyyNativeHub" then underHub = true; break end
                            current = current.Parent
                        end
                        if visible and not underHub and current == pg then return button end
                    end
                end
            end
            return nil
        end
        local function clickIntroSkip(button)
            if not button or hubUnloaded or not introSkipAllowed() then return false end
            local pos, size = button.AbsolutePosition, button.AbsoluteSize
            if size.X <= 0 or size.Y <= 0 then return false end
            if hubWindow and not hubWindow.Closed then
                pcall(function() hubWindow:Close() end)
            end
            local inset = GuiService:GetGuiInset()
            local x, y = pos.X + size.X * 0.5 + inset.X, pos.Y + size.Y * 0.5 + inset.Y
            local pressed = false
            local ok, err = pcall(function()
                VirtualInputManager:SendMouseMoveEvent(x, y, game)
                RunService.RenderStepped:Wait()
                if hubUnloaded or not introSkipAllowed() then return end
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                pressed = true
                task.wait(0.065)
            end)
            if pressed then
                pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
            end
            if not ok then warn("[AutoPuzzles] Intro Skip input failed: " .. tostring(err)) end
            return ok and pressed
        end

        -- The legacy intro Skip / post-intro auto-solver is replaced by
        -- the embedded v22 worker that starts before the Main UI initializes.
        if false then
        task.spawn(function()
            local lastSkipAttemptAt = -math.huge
            local lastWaitNoticeAt = os.clock()
            local skipClicks = 0
            while not hubUnloaded do
                if allPuzzlesRunning then
                    print("[AutoPuzzles] Auto-start yielded to an already running puzzle controller")
                    return
                end
                if finalEndingProtected or keyObjectivePhase()
                    or LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true then
                    print("[AutoPuzzles] Puzzle-release/key/ending phase active; stopping intro watcher")
                    return
                end
                if LocalPlayer:GetAttribute("IntroCutsceneFinished") == true then
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and leverFolder()
                        and LocalPlayer:GetAttribute("CutsceneActive") ~= true
                        and not leverRunning and not colourRunning and not puzzleControllerBusy then
                        print("[AutoPuzzles] Intro completed; automatically starting full Basement solver")
                        runAllPuzzles()
                        return
                    end
                elseif os.clock() - lastSkipAttemptAt >= 0.55 then
                    local skipButton = findVisibleIntroSkip()
                    if skipButton then
                        lastSkipAttemptAt = os.clock()
                        if clickIntroSkip(skipButton) then
                            skipClicks += 1
                            print("[AutoPuzzles] Skippable intro: Skip click sent (attempt " .. skipClicks .. ")")
                        end
                    end
                end
                if os.clock() - lastWaitNoticeAt >= 8 then
                    lastWaitNoticeAt = os.clock()
                    if LocalPlayer:GetAttribute("IntroCutsceneFinished") ~= true then
                        print("[AutoPuzzles] Waiting for intro completion / visible Skip button")
                    else
                        print("[AutoPuzzles] Waiting for lever targets and cutscene flags to become ready")
                    end
                end
                task.wait(0.08)
            end
        end)
        end -- retired Main auto-intro worker; v22 owns it exclusively

    do
        local overview = overviewTab
local function cutsceneResultsVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    if not (ending and ending:IsA("ScreenGui") and ending.Enabled) then return false end
    -- Some rounds keep NeedleEndingUI enabled before its actual ending
    -- controls become visible. Never suppress the puzzle bypass on that alone.
    local results = ending:FindFirstChild("ReturnToLobby", true)
    if not (results and results:IsA("GuiObject")) then return false end
    local node = results
    while node and node ~= ending do
        if node:IsA("GuiObject") and not node.Visible then return false end
        node = node.Parent
    end
    return node == ending
end
local function shouldYieldCutsceneBypass()
    if __BEYY_CH2_V22_STARTED then return true end
    if hubUnloaded or finalEndingProtected or not hubWindow.Closed
        or needleBusy or LocalPlayer:GetAttribute("NeedleOwned") == true
        or cutsceneResultsVisible() then return true end
    -- Levers are confirmed locally before the server's CutsceneActive flag
    -- necessarily replicates. A brief post-lever grace makes the bypass start
    -- immediately instead of being blocked by allPuzzlesRunning.
    local inUnskippable = LocalPlayer:GetAttribute("CutsceneActive") == true
        or LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
        or os.clock() < leverBypassUntil or os.clock() < puzzleBypassUntil
    if inUnskippable then return leverRunning or colourRunning end
    return sharedFarmPuzzleBusy()
end
local function setCutsceneBypassActive(active)
    cutscenePlayable = active == true and not finalEndingProtected
end
local cutsceneBypassStop = nil
local function launchCutsceneBypass()
    if cutsceneBypassStop then return true end
    local ok, result = pcall(function()

        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

        local env = _G
        if type(getgenv) == "function" then
            local ok, tbl = pcall(getgenv)
            if ok and type(tbl) == "table" then env = tbl end
        end
        local older = env.__BEYY_CUTSCENE_BYPASS_STOP or _G.__BEYY_CUTSCENE_BYPASS_STOP
        if type(older) == "function" then pcall(older) end

        local alive, enabled, active = true, true, false
        local scene = nil
        local recoveryEnd = 0
        local lastNormalDistance, lastNormalYaw, lastNormalPitch = 0.6, nil, nil
        local normalFirstPerson, cameraFirstPerson = true, true
        local yaw, pitch, distance = nil, -0.18, 0.6
        local lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil
        local controls, cachedCamera = nil, nil
        local originalMouseBehavior = nil
        local lastControlEnableAt = 0
        local connections = {}
        local hudEnabled = true
        local faceCameraEnabled = true
        local hudNormal, hudForced = {}, {}
        local headTransparencyBefore = {}
        local finalVisualsEnabled = true
        local finalVisualBefore = {}
        local cameraWatch = nil
        local inCameraWrite, cameraErrorWarned = false, false
        local renderId = "BeyyCutsceneCameraV103Last"
        local renderPriority = Enum.RenderPriority.Last.Value + 2000
        local RECOVERY_GRACE_SECONDS = 0.035
        local INTRO_SETTLE_SECONDS = 1.0
        local introConfirmedAt = player:GetAttribute("IntroCutsceneFinished") == true and (os.clock() - 2) or nil
        local introNeutralSeen = introConfirmedAt ~= nil and player:GetAttribute("CutsceneActive") ~= true
        local chapter2ReleaseSeen = player:GetAttribute("Chapter2ReleaseActive") == true
        local yieldingToEnding = false
        local lastEndingSkipScan, lastEndingSkipVisible = 0, false
        local skipCandidates = setmetatable({}, { __mode = "k" })
        local skipGui, skipGuiAddedConnection = nil, nil
        local lastSkipFallbackScan = 0
        local lastFinalVisualMaskAt = -math.huge
        local lastRenderTime = os.clock()

        local function log(s)
            if type(s) ~= "string" then return end
            if s:find("READY:", 1, true)
                or s:find("CUTSCENE DETECTED:", 1, true)
                or s:find("PLAYABLE CAMERA ENABLED:", 1, true)
                or s:find("ROBLOX CAMERA RETURNED:", 1, true)
                or s == "STOPPED" then
                print("[BeyyHub Cutscene] " .. s)
            end
        end
        local function hook(c)
            if c then connections[#connections+1] = c end
        end
        local function humanoid()
            local char = player.Character
            return char and char:FindFirstChildOfClass("Humanoid")
        end
        local function root()
            local char = player.Character
            return char and char:FindFirstChild("HumanoidRootPart")
        end
        local function camera()
            return workspace.CurrentCamera
        end
        local function getControls()
            if controls then return controls end
            local ps = player:FindFirstChild("PlayerScripts")
            local pm = ps and ps:FindFirstChild("PlayerModule")
            if not pm then return nil end
            local ok, mod = pcall(require, pm)
            if not ok or type(mod) ~= "table" then return nil end
            local ok2, obj = pcall(function() return mod:GetControls() end)
            if ok2 then controls = obj end
            return controls
        end
        local function rememberGameplay()
            local hum = humanoid()
            if hum then
                if hum.WalkSpeed > 0 then lastSavedSpeed = hum.WalkSpeed end
                if hum.JumpPower > 0 then lastSavedJump = hum.JumpPower end
                lastSavedRotate = hum.AutoRotate
            end
            local cam, rt = camera(), root()
            if cam and rt and cam.CameraType == Enum.CameraType.Custom then
                local look = cam.CFrame.LookVector
                if look.Magnitude > 0.5 then
                    local planar = Vector3.new(look.X, 0, look.Z)
                    if planar.Magnitude > 0.1 then
                        lastNormalYaw = math.atan2(planar.X, planar.Z)
                    end
                    lastNormalPitch = math.asin(math.max(-0.97, math.min(0.97, look.Y)))
                end
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local eye = head and head.Position or (rt.Position + Vector3.new(0, 1.6, 0))
                local d = (cam.CFrame.Position - eye).Magnitude
                if d <= 22 then
                    lastNormalDistance = d
                    normalFirstPerson = (d < 2.5 or player.CameraMode == Enum.CameraMode.LockFirstPerson)
                end
            end
        end
        local function kind()
            if shouldYieldCutsceneBypass() then return nil end
            if player:GetAttribute("IntroCutsceneFinished") ~= true then return nil end
            if introConfirmedAt and os.clock() - introConfirmedAt < INTRO_SETTLE_SECONDS then return nil end
            if yieldingToEnding or finalEndingProtected then return nil end
            if player:GetAttribute("Chapter2ReleaseActive") == true
                or os.clock() < puzzleBypassUntil then return "THREE PUZZLES" end
            if player:GetAttribute("CutsceneActive") == true
                or os.clock() < leverBypassUntil then return "THREE LEVERS" end
            return nil
        end
        local function clamp(v, lo, hi)
            return math.max(lo, math.min(hi, v))
        end
        local function setupPlayableCamera()
            local rt = root()
            local facing = rt and rt.CFrame.LookVector or Vector3.new(0,0,-1)
            local planar = Vector3.new(facing.X, 0, facing.Z)
            if planar.Magnitude < 0.01 then planar = Vector3.new(0,0,-1) end
            yaw = lastNormalYaw or math.atan2(planar.X, planar.Z)
            pitch = clamp(lastNormalPitch or -0.16, -1.20, 1.05)
            cameraFirstPerson = normalFirstPerson or player.CameraMode == Enum.CameraMode.LockFirstPerson
            distance = clamp(lastNormalDistance or 0.6, 0.0, 22)
            log(string.format("Normal camera calibration: %s d=%.2f pitch=%.2f (no forced 6+ stud zoom)",
                cameraFirstPerson and "FIRST PERSON" or "THIRD PERSON", distance, pitch))
            cameraErrorWarned = false
            if originalMouseBehavior == nil then originalMouseBehavior = UserInputService.MouseBehavior end
        end
        local function lookVector()
            local cp = math.cos(pitch)
            return Vector3.new(math.sin(yaw)*cp, math.sin(pitch), math.cos(yaw)*cp)
        end
        local function hideHeadForFirstPerson()
            if not cameraFirstPerson then return end
            local char = player.Character
            if not char then return end
            local function hidePart(inst)
                if not inst or not inst:IsA("BasePart") then return end
                if headTransparencyBefore[inst] == nil then
                    headTransparencyBefore[inst] = inst.LocalTransparencyModifier
                end
                inst.LocalTransparencyModifier = 1
            end
            hidePart(char:FindFirstChild("Head"))
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Accessory") then
                    hidePart(item:FindFirstChild("Handle"))
                end
            end
        end
        local function restoreHeadTransparency()
            for part, before in pairs(headTransparencyBefore) do
                if part.Parent then
                    pcall(function() part.LocalTransparencyModifier = before end)
                end
                headTransparencyBefore[part] = nil
            end
        end
        local function forceCamera()
            if not alive or not enabled or not active or inCameraWrite or shouldYieldCutsceneBypass() then return end
            local cam, rt = camera(), root()
            if not cam or not rt or not yaw then return end
            inCameraWrite = true
            local safe, err = pcall(function()
                local vec = lookVector()
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local eye = head and head.Position or (rt.Position + Vector3.new(0, 1.6, 0))
                local result, focus
                if cameraFirstPerson then
                    result = CFrame.lookAt(eye, eye + vec * 8, Vector3.yAxis)
                    focus = eye + vec * 8
                    hideHeadForFirstPerson()
                else
                    local target = rt.Position + Vector3.new(0, 1.6, 0)
                    local desired = target - vec * distance
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = char and {char} or {}
                    params.RespectCanCollide = true
                    local hit = workspace:Raycast(target, desired - target, params)
                    if hit then
                        local hitDistance = (hit.Position - target).Magnitude
                        desired = target - vec * math.max(0.35, math.min(distance, hitDistance - 0.40))
                    end
                    result = CFrame.lookAt(desired, target, Vector3.yAxis)
                    focus = target
                end
                cam.CameraType = Enum.CameraType.Scriptable
                local hum = humanoid()
                if hum then cam.CameraSubject = hum end
                cam.CFrame = result
                cam.Focus = CFrame.new(focus)
            end)
            inCameraWrite = false
            if not safe and not cameraErrorWarned then
                cameraErrorWarned = true
                warn("[BeyyHub Cutscene] Camera write failed: " .. tostring(err))
            end
        end
        local function unwatchLeverCamera()
            if cameraWatch then pcall(function() cameraWatch:Disconnect() end) end
            cameraWatch, cachedCamera = nil, nil
        end
        local function watchLeverCamera()
            if not alive or not enabled or not active or scene ~= "THREE LEVERS" then
                unwatchLeverCamera()
                return
            end
            local cam = camera()
            if cam == cachedCamera and cameraWatch then return end
            unwatchLeverCamera()
            cachedCamera = cam
            if not cam then return end
            cameraWatch = cam:GetPropertyChangedSignal("CFrame"):Connect(function()
                if alive and enabled and active and scene == "THREE LEVERS" and not inCameraWrite then
                    forceCamera()
                end
            end)
        end
        hook(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if active and scene == "THREE LEVERS" then watchLeverCamera() end
        end))

        local SAFE_HUD_NAMES = { hud = true, needlehud = true, notifications = true }
        local function isGameplayHud(gui)
            if not gui:IsA("ScreenGui") then return false end
            local name = gui.Name:lower()
            if name:find("ending", 1, true) or name:find("cutscene", 1, true)
                or name:find("cinematic", 1, true) or name:find("intro", 1, true)
                or name:find("puzzle", 1, true) or name:find("skip", 1, true) then return false end
            return SAFE_HUD_NAMES[name] or name:find("hud", 1, true) ~= nil
                or name:find("hotbar", 1, true) ~= nil
                or name:find("inventory", 1, true) ~= nil
                or name:find("toolbar", 1, true) ~= nil
        end
        local function rememberGameplayHud()
            if active or scene then return end
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if isGameplayHud(gui) and gui.Enabled then
                    local before = hudNormal[gui]
                    if not before or not before.enabled or before.order ~= gui.DisplayOrder then
                        hudNormal[gui] = { enabled = true, order = gui.DisplayOrder }
                    end
                end
            end
        end
        local lastHudDiscoveryAt = -math.huge
        local function showGameplayHud()
            if not hudEnabled then return end
            -- Newly recreated hotbar/HUD ScreenGuis may have been disabled by
            -- the server before the initial baseline could record them.
            local now = os.clock()
            if now - lastHudDiscoveryAt >= 0.35 then
                lastHudDiscoveryAt = now
                local pg = player:FindFirstChildOfClass("PlayerGui")
                if pg then
                    for _, gui in ipairs(pg:GetChildren()) do
                        if isGameplayHud(gui) and not hudNormal[gui] then
                            hudNormal[gui] = { enabled = true, order = gui.DisplayOrder }
                        end
                    end
                end
            end
            for gui, before in pairs(hudNormal) do
                if gui.Parent and before.enabled then
                    if not hudForced[gui] then hudForced[gui] = { enabled = gui.Enabled, order = gui.DisplayOrder } end
                    if not gui.Enabled then
                        pcall(function() gui.Enabled = true end)
                    end
                    local targetOrder = math.max(before.order or 0, 10000)
                    if gui.DisplayOrder ~= targetOrder then
                        pcall(function() gui.DisplayOrder = targetOrder end)
                    end
                end
            end
        end
        local function restoreGameplayHud()
            for gui, saved in pairs(hudForced) do
                if gui.Parent then
                    local wasNormal = hudNormal[gui]
                    pcall(function()
                        gui.DisplayOrder = saved.order
                        if wasNormal and wasNormal.enabled then gui.Enabled = true end
                    end)
                end
                hudForced[gui] = nil
            end
        end

        local function isFinalOverlay(gui)
            if not gui:IsA("ScreenGui") then return false end
            local name = gui.Name:lower()
            if name:find("ending", 1, true) or name:find("needle", 1, true) then return false end
            return name == "cutscenefade" or name:find("cutscene", 1, true) ~= nil
                or name:find("cinematic", 1, true) ~= nil
                or name:find("chapter2release", 1, true) ~= nil
        end
        local function maskFinalProperty(inst, key)
            local ok, previous = pcall(function() return inst[key] end)
            if not ok or type(previous) ~= "number" or previous >= 1 then return end
            local saved = finalVisualBefore[inst]
            if not saved then saved = {}; finalVisualBefore[inst] = saved end
            if saved[key] == nil then saved[key] = previous end
            pcall(function() inst[key] = 1 end)
        end
        local function hideFinalCutsceneVisuals()
            if not finalVisualsEnabled or not scene then return end
            -- Full overlay descendant scans are unnecessary every frame.
            -- The scene poll still catches dynamically added cutscene graphics.
            local now = os.clock()
            if now - lastFinalVisualMaskAt < 0.16 then return end
            lastFinalVisualMaskAt = now
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if isFinalOverlay(gui) then
                    for _, el in ipairs(gui:GetDescendants()) do
                        if el:IsA("GuiObject") then
                            maskFinalProperty(el, "BackgroundTransparency")
                            if el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox") then
                                maskFinalProperty(el, "TextTransparency")
                                maskFinalProperty(el, "TextStrokeTransparency")
                            end
                            if el:IsA("ImageLabel") or el:IsA("ImageButton") then
                                maskFinalProperty(el, "ImageTransparency")
                            end
                        elseif el:IsA("UIStroke") then
                            maskFinalProperty(el, "Transparency")
                        end
                    end
                end
            end
        end
        local function restoreFinalCutsceneVisuals()
            for inst, props in pairs(finalVisualBefore) do
                if inst.Parent then
                    for key, original in pairs(props) do
                        pcall(function() inst[key] = original end)
                    end
                end
                finalVisualBefore[inst] = nil
            end
        end

        local function indexSkipCandidate(inst)
            if not inst then return end
            local btn = nil
            if inst:IsA("GuiButton") then
                btn = inst
            elseif inst:IsA("TextLabel") and inst.Text:lower():find("skip", 1, true) then
                local ancestor = inst.Parent
                while ancestor and not ancestor:IsA("GuiButton") do
                    ancestor = ancestor.Parent
                end
                btn = ancestor
            end
            if not btn then return end
            local name = btn.Name:lower()
            local text = btn:IsA("TextButton") and btn.Text:lower() or ""
            local marked = name:find("skip", 1, true) or text:find("skip", 1, true)
            if not marked then
                for _, child in ipairs(btn:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text:lower():find("skip", 1, true) then
                        marked = true
                        break
                    end
                end
            end
            if marked then skipCandidates[btn] = true end
        end
        local function scanSkipCandidates(pg)
            for _, obj in ipairs(pg:GetDescendants()) do indexSkipCandidate(obj) end
        end
        local function watchSkipGui()
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if pg == skipGui and skipGuiAddedConnection then return pg end
            if skipGuiAddedConnection then pcall(function() skipGuiAddedConnection:Disconnect() end) end
            skipGuiAddedConnection, skipGui = nil, pg
            if pg then
                scanSkipCandidates(pg)
                skipGuiAddedConnection = pg.DescendantAdded:Connect(indexSkipCandidate)
            end
            return pg
        end
        local function skipButtonVisible(pg)
            local ending = pg:FindFirstChild("NeedleEndingUI")
            if not ending or not ending.Enabled then return false end
            for btn in pairs(skipCandidates) do
                if not btn.Parent or not btn:IsDescendantOf(pg) then
                    skipCandidates[btn] = nil
                elseif btn:IsDescendantOf(ending) then
                    local visible, parent = true, btn
                    while parent and parent ~= pg do
                        if parent:IsA("GuiObject") and not parent.Visible then visible = false; break end
                        if parent:IsA("ScreenGui") and not parent.Enabled then visible = false; break end
                        parent = parent.Parent
                    end
                    if visible then return true end
                end
            end
            return false
        end
        local function skipButtonOnScreen()
            -- The ending is not eligible until our hand-in starts. This
            -- avoids unrelated/early Skip elements suppressing puzzle bypass.
            if not finalEndingProtected then
                lastEndingSkipVisible = false
                return false
            end
            local now = os.clock()
            if now - lastEndingSkipScan < 0.08 then return lastEndingSkipVisible end
            lastEndingSkipScan = now
            local pg = watchSkipGui()
            if not pg then lastEndingSkipVisible = false; return false end
            lastEndingSkipVisible = skipButtonVisible(pg)
            local endingUI = pg:FindFirstChild("NeedleEndingUI")
            if not (endingUI and endingUI:IsA("ScreenGui") and endingUI.Enabled) then
                lastEndingSkipVisible = false
                return false
            end
            -- Ownership of the needle/key alone is not an ending cutscene.
            -- Added GUI objects are indexed immediately by DescendantAdded.
            local endingVisible = endingUI and endingUI.Enabled == true
            local fallbackEvery = endingVisible and 0.5 or (scene and 1.0 or 4.0)
            if not lastEndingSkipVisible and now - lastSkipFallbackScan >= fallbackEvery then
                lastSkipFallbackScan = now
                scanSkipCandidates(pg)
                lastEndingSkipVisible = skipButtonVisible(pg)
            end
            return lastEndingSkipVisible
        end
        local function releaseEndingCursor()
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
            pcall(function() UserInputService.MouseIconEnabled = true end)
        end

        local function restoreInputs()
            local hum = humanoid()
            if hum then
                if hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
                if hum.Sit then pcall(function() hum.Sit = false end) end
                if hum.WalkSpeed <= 0 then hum.WalkSpeed = lastSavedSpeed or 16 end
                if hum.JumpPower <= 0 then hum.JumpPower = lastSavedJump or 50 end
                if not faceCameraEnabled and lastSavedRotate ~= nil and hum.AutoRotate ~= lastSavedRotate then
                    hum.AutoRotate = lastSavedRotate
                end
            end
            local rt = root()
            if scene and rt and rt.Anchored then
                pcall(function() rt.Anchored = false end)
            end
            local ctrl = getControls()
            local now = os.clock()
            if ctrl and (ctrl.enabled == false or now - lastControlEnableAt >= 0.25) then
                lastControlEnableAt = now
                pcall(function() ctrl:Enable() end)
            end
            if player:GetAttribute("NeedleInputLocked") == true then
                pcall(function() player:SetAttribute("NeedleInputLocked", nil) end)
            end
        end
        local function alignCharacterFacing()
            if not alive or not enabled or not active or not faceCameraEnabled then return end
            local hum, rt = humanoid(), root()
            if not hum or not rt or rt.Anchored or not yaw then return end
            local forward = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
            local oldLook = rt.CFrame.LookVector
            local flatOld = Vector3.new(oldLook.X, 0, oldLook.Z)
            local dot = flatOld.Magnitude > 0.01 and flatOld.Unit:Dot(forward) or 0
            if hum.AutoRotate then hum.AutoRotate = false end
            if dot < 0.9995 then
                local desired = CFrame.lookAt(rt.Position, rt.Position + forward, Vector3.yAxis)
                pcall(function() rt.CFrame = rt.CFrame:Lerp(desired, 0.35) end)
            end
        end
        local function directMovement()
            local hum = humanoid()
            if not hum or UserInputService:GetFocusedTextBox() then return end
            local function down(key)
                return UserInputService:IsKeyDown(key)
            end
            local x = (down(Enum.KeyCode.D) and 1 or 0) - (down(Enum.KeyCode.A) and 1 or 0)
            local z = (down(Enum.KeyCode.W) and 1 or 0) - (down(Enum.KeyCode.S) and 1 or 0)
            if x ~= 0 or z ~= 0 then
                if not yaw then return end
                local front = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
                local right = Vector3.new(-front.Z, 0, front.X)
                local motion = front*z + right*x
                if motion.Magnitude > 1 then motion = motion.Unit end
                pcall(function() hum:Move(motion, false) end)
            end
            if down(Enum.KeyCode.Space) then pcall(function() hum.Jump = true end) end
        end
        local function restoreCamera()
            restoreHeadTransparency()
            local cam = camera()
            if cam then
                local hum = humanoid()
                if hum then pcall(function() cam.CameraSubject = hum end) end
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            end
            local hum = humanoid()
            if hum and lastSavedRotate ~= nil then
                pcall(function() hum.AutoRotate = lastSavedRotate end)
            end
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            if originalMouseBehavior then
                pcall(function() UserInputService.MouseBehavior = originalMouseBehavior end)
                originalMouseBehavior = nil
            end
        end
        local function enablePlayableCamera(reason)
            if active then return end
            setCutsceneBypassActive(true)
            active = true
            setupPlayableCamera()
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            log("PLAYABLE CAMERA ENABLED: " .. tostring(reason))
            if scene == "THREE LEVERS" then watchLeverCamera() end
            forceCamera()
        end
        local function disablePlayableCamera(reason)
            unwatchLeverCamera()
            if not active then return end
            active = false
            restoreCamera()
            setCutsceneBypassActive(false)
            log("ROBLOX CAMERA RETURNED: " .. tostring(reason))
        end
        local function updateScene()
            if not alive then return end
            -- Needle and puzzle VIM routines own the camera. During Gem,
            -- recover cutscene movement/input and HUD, but NEVER restore or
            -- force a second camera over the Gem solver's targeting.
            if needleBusy or leverRunning or colourRunning then
                if colourRunning and enabled and not finalEndingProtected
                    and hubWindow.Closed == true then restoreInputs() end
                if active then showGameplayHud() end
                return
            end
            local now = os.clock()
            if player:GetAttribute("Chapter2ReleaseActive") == true then chapter2ReleaseSeen = true end
            local hasSkip = skipButtonOnScreen()
            if not hasSkip then yieldingToEnding = false end
            if hasSkip and not yieldingToEnding then
                yieldingToEnding = true
                recoveryEnd = 0
                log("SKIPPABLE NEEDLE ENDING DETECTED — camera bypass released; mouse unlocked for SKIP / hub AutoSkip")
            end
            local current = enabled and kind() or nil
            if current then
                if current ~= scene then
                    scene = current
                    if current == "THREE PUZZLES" then
                        unwatchLeverCamera()
                        log("CHAPTER 2 RELEASE: camera/movement override; optional transparency-only cutscene visual mask")
                    end
                    log("CUTSCENE DETECTED: " .. current)
                    if current == "THREE PUZZLES" then
                        print("[BeyyHub Cutscene] Puzzle-release cinematic bypass active (final needle ending remains protected)")
                    end
                    recoveryEnd = 0
                    if not active then enablePlayableCamera(current) end
                end
            elseif scene then
                log("CUTSCENE FLAG CLEARED: " .. scene .. " — restoring Roblox camera in " .. RECOVERY_GRACE_SECONDS .. "s")
                restoreFinalCutsceneVisuals()
                unwatchLeverCamera()
                scene = nil
                recoveryEnd = now + RECOVERY_GRACE_SECONDS
                task.delay(RECOVERY_GRACE_SECONDS + 0.008, function()
                    if alive then updateScene() end
                end)
            end
            local shouldKeep = enabled and not yieldingToEnding and (current ~= nil or now < recoveryEnd)
            if shouldKeep then
                if not active then enablePlayableCamera("recovery / F7") end
                restoreInputs()
                showGameplayHud()
                hideFinalCutsceneVisuals()
            else
                restoreFinalCutsceneVisuals()
                restoreGameplayHud()
                if active then disablePlayableCamera("recovered / bypass disabled") end
            end
            if yieldingToEnding and lastEndingSkipVisible then releaseEndingCursor() end
        end
        cutsceneBypassRefresh = function()
            if alive then updateScene() end
        end

        hook(UserInputService.InputBegan:Connect(function(input, processed)
            if processed or UserInputService:GetFocusedTextBox() or shouldYieldCutsceneBypass() then return end
            if input.KeyCode == Enum.KeyCode.F3 then
                finalVisualsEnabled = not finalVisualsEnabled
                if not finalVisualsEnabled then restoreFinalCutsceneVisuals() end
                log("F3: final cinematic visual masking " .. (finalVisualsEnabled and "ENABLED" or "DISABLED"))
            elseif input.KeyCode == Enum.KeyCode.F4 then
                faceCameraEnabled = not faceCameraEnabled
                local hum = humanoid()
                if hum and not faceCameraEnabled and lastSavedRotate ~= nil then
                    pcall(function() hum.AutoRotate = lastSavedRotate end)
                end
                log("F4: camera-facing character alignment " .. (faceCameraEnabled and "ENABLED" or "DISABLED"))
                if faceCameraEnabled then alignCharacterFacing() end
            elseif input.KeyCode == Enum.KeyCode.F5 then
                hudEnabled = not hudEnabled
                if not hudEnabled then restoreGameplayHud() end
                log("F5: gameplay HUD preservation " .. (hudEnabled and "ENABLED" or "DISABLED"))
            elseif input.KeyCode == Enum.KeyCode.F7 then
                recoveryEnd = 0
                log("F7: Roblox camera recovery requested")
                updateScene()
            end
        end))
        hook(UserInputService.InputChanged:Connect(function(input)
            if not active or shouldYieldCutsceneBypass() then return end
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                if not cameraFirstPerson then
                    distance = clamp(distance - input.Position.Z * 1.5, 0.4, 22)
                end
            end
        end))
        hook(player.AttributeChanged:Connect(function(attr)
            if attr == "IntroCutsceneFinished" then
                if player:GetAttribute("IntroCutsceneFinished") == true and not introConfirmedAt then
                    introConfirmedAt = os.clock()
                    introNeutralSeen = player:GetAttribute("CutsceneActive") ~= true
                    log("SKIPPABLE INTRO COMPLETED — waiting for clean lever trigger; intro ignored")
                elseif player:GetAttribute("IntroCutsceneFinished") ~= true then
                    introConfirmedAt, introNeutralSeen = nil, false
                    chapter2ReleaseSeen, yieldingToEnding = false, false
                    lastEndingSkipScan, lastEndingSkipVisible = 0, false
                end
            elseif attr == "CutsceneActive" and player:GetAttribute("CutsceneActive") ~= true
                and introConfirmedAt then
                introNeutralSeen = true
            end
            if attr == "CutsceneActive" or attr == "Chapter2ReleaseActive" or
                attr == "IntroCutsceneFinished" or attr == "NeedleInputLocked" or attr == "NeedleOwned" then
                task.defer(updateScene)
            end
        end))
        hook(player.CharacterAdded:Connect(function()
            controls, lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil, nil
            task.delay(0.4, function() if alive and not active then rememberGameplay() end end)
        end))

        local function handleCameraInput()
            if not alive or not enabled or not active or not yaw then return end
            pcall(function()
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                end
            end)
            local ok, md = pcall(function() return UserInputService:GetMouseDelta() end)
            if ok and md then
                if math.abs(md.X) > 0 or math.abs(md.Y) > 0 then
                    yaw = yaw - md.X * 0.004
                    pitch = clamp(pitch - md.Y * 0.004, -1.0, 0.85)
                end
            end
            local now = os.clock()
            local dt = clamp(now - lastRenderTime, 0, 0.08)
            lastRenderTime = now
            local function down(key) return UserInputService:IsKeyDown(key) end
            if not UserInputService:GetFocusedTextBox() then
                local h = (down(Enum.KeyCode.Right) and 1 or 0) - (down(Enum.KeyCode.Left) and 1 or 0)
                local v = (down(Enum.KeyCode.Up) and 1 or 0) - (down(Enum.KeyCode.Down) and 1 or 0)
                if h ~= 0 or v ~= 0 then
                    yaw = yaw - h * dt * 1.9
                    pitch = clamp(pitch + v * dt * 1.3, -1.0, 0.85)
                end
            end
        end
        RunService:BindToRenderStep(renderId, renderPriority, function()
            if alive and yieldingToEnding and skipButtonOnScreen() then
                if active then updateScene() end
                releaseEndingCursor()
            end
            if alive and enabled and colourRunning and not finalEndingProtected
                and hubWindow.Closed == true and not yieldingToEnding
                and (os.clock() < leverBypassUntil
                    or os.clock() < puzzleBypassUntil
                    or player:GetAttribute("CutsceneActive") == true
                    or player:GetAttribute("Chapter2ReleaseActive") == true) then
                -- This late render callback runs after the cinematic's camera
                -- script AND after Gem's normal aim callback, so Gem wins the
                -- camera contest without the bypass fighting its teleports.
                restoreInputs()
                if gemCutsceneCameraAim then gemCutsceneCameraAim() end
                showGameplayHud()
                lastRenderTime = os.clock()
            elseif alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then
                -- Camera, input and HUD need last-render-priority enforcement
                -- during cinematic scripts; expensive descendant scans stay
                -- throttled in updateScene.
                restoreInputs()
                handleCameraInput()
                forceCamera()
                alignCharacterFacing()
                directMovement()
                showGameplayHud()
            else
                lastRenderTime = os.clock()
            end
        end)
        local simulationSignal = RunService.PreSimulation or RunService.Heartbeat
        hook(simulationSignal:Connect(function()
            if alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then
                restoreInputs()
                directMovement()
            end
        end))

        local function stop()
            if not alive then return end
            cutsceneBypassRefresh = nil
            local wasActive = active
            alive, enabled, active = false, false, false
            pcall(function() RunService:UnbindFromRenderStep(renderId) end)
            unwatchLeverCamera()
            if skipGuiAddedConnection then pcall(function() skipGuiAddedConnection:Disconnect() end) end
            skipGuiAddedConnection = nil
            restoreGameplayHud()
            restoreFinalCutsceneVisuals()
            for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
            if wasActive then restoreCamera() end
            setCutsceneBypassActive(false)
            if env.__BEYY_CUTSCENE_BYPASS_STOP == stop then env.__BEYY_CUTSCENE_BYPASS_STOP = nil end
            if _G.__BEYY_CUTSCENE_BYPASS_STOP == stop then _G.__BEYY_CUTSCENE_BYPASS_STOP = nil end
            if lastEndingSkipVisible then releaseEndingCursor() end
            log("STOPPED")
        end

        rememberGameplay()
        rememberGameplayHud()
        updateScene()
        task.spawn(function()
            while alive do
                task.wait((active or scene) and 0.1 or 0.35)
                if not active and not scene then
                    rememberGameplay()
                    rememberGameplayHud()
                end
                updateScene()
            end
        end)
        log("READY: three-lever and three-puzzle cutscenes only; intro and needle ending excluded")
        log("F3 visual mask | F4 facing | F5 HUD | F7 restore | Exploit-tab toggle controls enable/disable")
        log("Mouse / arrows aim, WASD moves. Normal camera restores immediately after cutscenes.")
        log("Visual/client-side bypass only; no server cutscene timers or progression changed.")

        env.__BEYY_CUTSCENE_BYPASS_STOP = stop
        return stop
    end)
    if not ok or type(result) ~= "function" then
        warn("[BeyyHub] Cutscene bypass failed to start: " .. tostring(result))
        return false
    end
    cutsceneBypassStop = result
    return true
end
local function shutdownCutsceneBypass()
    local stopFn = cutsceneBypassStop
    cutsceneBypassStop = nil
    if stopFn then pcall(stopFn) end
end
local previousCutsceneHubCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    for _, connection in ipairs(autoCutsceneSignals) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(autoCutsceneSignals)
    shutdownCutsceneBypass()
    if previousCutsceneHubCleanup then pcall(previousCutsceneHubCleanup) end
end

    overview:Section({ Title = "Cutscenes" })
    Registry.CutsceneBypass = overview:Toggle({
        Title = "Unskippable Cutscene Bypass", Value = false,
        Desc = "Auto ON after all three levers; OFF BEFORE needle hand-in. No effect on the server's timer.",
        Callback = function(enabled)
            if enabled then
                if __BEYY_CH2_V22_STARTED then
                    print("[BeyyHub Cutscene] Embedded v22 owns non-final cutscene camera; duplicate bypass suppressed")
                    task.defer(function()
                        if Registry.CutsceneBypass and Registry.CutsceneBypass.Value == true then
                            Registry.CutsceneBypass:Set(false)
                        end
                    end)
                    return
                end
                if finalEndingProtected then
                    task.defer(function()
                        local toggle = Registry.CutsceneBypass
                        if toggle and toggle.Value == true then toggle:Set(false) end
                    end)
                    return
                end
                if not launchCutsceneBypass() then warn("[BeyyHub] Cutscene bypass could not start") end
            else shutdownCutsceneBypass() end
        end,
    })

    -- Run this small cutscene-cycle setup in its own Luau function scope.
    -- It had exceeded the enclosing Chapter2 function's 200-local limit.
    -- Synchronous call preserves all toggles, listeners and callbacks.
    do
        (function()
    local autoBypassCycleActive = false
    local ownedNeedleDuringCycle = LocalPlayer:GetAttribute("NeedleOwned") == true
    local needleOwnedPrevious = ownedNeedleDuringCycle

    autoCutsceneEnableAfterLevers = function(reason)
        if __BEYY_CH2_V22_STARTED then return end
        -- The coordinated solver has just confirmed all three levers.
        -- Do not let a prematurely replicated release flag suppress it.
        -- Generic CutsceneActive listeners are guarded separately.
        if hubUnloaded or autoBypassCycleActive or finalEndingProtected
            or postPuzzleKeyPriority
            or LocalPlayer:GetAttribute("NeedleOwned") == true
            or cutsceneResultsVisible() then return end
        leverBypassUntil = math.max(leverBypassUntil, os.clock() + 6.5)
        print("[BeyyHub Cutscene] Lever bypass grace started (6.5s); " .. tostring(reason))
        local toggle = Registry.CutsceneBypass
        if not toggle then return end
        if toggle.Value ~= true then toggle:Set(true) end
        if toggle.Value == true and type(cutsceneBypassStop) == "function" then
            autoBypassCycleActive = true
            ownedNeedleDuringCycle = LocalPlayer:GetAttribute("NeedleOwned") == true
            if cutsceneBypassRefresh then
                local okRefresh, refreshErr = pcall(cutsceneBypassRefresh)
                if not okRefresh then warn("[BeyyHub Cutscene] Lever activation refresh: "..tostring(refreshErr)) end
            end
            print("[BeyyHub Cutscene] AUTO ON after " .. tostring(reason))
        else
            warn("[BeyyHub Cutscene] Auto-enable failed; manual toggle remains available")
            if toggle.Value == true then toggle:Set(false) end
        end
    end

    autoCutsceneDisableAfterHandIn = function(reason)
        if hubUnloaded then return end
        finalEndingProtected = true
        leverBypassUntil = 0
        puzzleBypassUntil = 0
        local wasActive = autoBypassCycleActive
        autoBypassCycleActive = false
        ownedNeedleDuringCycle = false
        local toggle = Registry.CutsceneBypass
        if toggle and toggle.Value == true then toggle:Set(false)
        else shutdownCutsceneBypass() end
        print("[BeyyHub Cutscene] Final ending protected; bypass OFF after " ..
            tostring(reason) .. (wasActive and " (automatic cycle)" or ""))
    end

    table.insert(autoCutsceneSignals, LocalPlayer:GetAttributeChangedSignal("Chapter2ReleaseActive"):Connect(function()
        if LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
            and not finalEndingProtected and LocalPlayer:GetAttribute("NeedleOwned") ~= true then
            puzzleReleaseObserved = true
            puzzleBypassUntil = math.max(puzzleBypassUntil, os.clock() + 6.5)
            print("[BeyyHub Cutscene] Puzzle-release flag observed; bypass grace 6.5s (final ending excluded)")
        end
    end))
    table.insert(autoCutsceneSignals, LocalPlayer:GetAttributeChangedSignal("CutsceneActive"):Connect(function()
        if __BEYY_CH2_V22_STARTED then return end
        if hubUnloaded or leverRunning or autoBypassCycleActive or finalEndingProtected
            or postPuzzleKeyPriority or puzzleReleaseObserved
            or LocalPlayer:GetAttribute("NeedleOwned") == true
            or cutsceneResultsVisible() then return end
        if LocalPlayer:GetAttribute("CutsceneActive") == true
            and LocalPlayer:GetAttribute("IntroCutsceneFinished") == true
            and LocalPlayer:GetAttribute("Chapter2ReleaseActive") ~= true
            and leverFolder() then
            autoCutsceneEnableAfterLevers("post-lever cutscene (manual levers)")
        end
    end))

    table.insert(autoCutsceneSignals, LocalPlayer:GetAttributeChangedSignal("NeedleOwned"):Connect(function()
        if hubUnloaded then return end
        local owned = LocalPlayer:GetAttribute("NeedleOwned") == true
        if autoBypassCycleActive then
            if owned then
                ownedNeedleDuringCycle = true
            elseif needleOwnedPrevious and ownedNeedleDuringCycle then
                local laser = Workspace:FindFirstChild("Laser")
                local root = farmRoot()
                local nearHandIn = laser and laser:IsA("Model") and root
                    and (root.Position - laser:GetPivot().Position).Magnitude <= 30
                if nearHandIn or cutsceneResultsVisible()
                    or LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true then
                    finalEndingProtected = true
                    autoCutsceneDisableAfterHandIn("needle ownership cleared at hand-in")
                end
            end
        end
        needleOwnedPrevious = owned
    end))
        end)()
    end
    end

    do
        -- Keep config setup synchronous while isolating its locals from
        -- the near-limit Chapter 2 module scope.
        (function()
        local SettingsTab = overviewTab
        local ConfigManager = hubWindow.ConfigManager
        local function Header(tab, title) tab:Section({ Title = title }) end
        local function Notify(title, content, duration, icon)
            pcall(function() hubNativeUI:Notify({ Title=title, Content=content, Duration=duration or 3, Icon=icon }) end)
        end
    local ConfigTab = SettingsTab:CollapsibleGroup({ Title = "Config", Opened = false })
    local saveConfigName = "default"
    local selectedConfigName = nil
    local configDropdown = nil
    local EMPTY_CONFIG = "(No saved configs)"
    local configCache = {}
    local function buildConfig(name)
        local cfg = ConfigManager:CreateConfig(name)
        for key, element in pairs(Registry) do cfg:Register(key, element) end
        function cfg:Snapshot()
            local previous = __beyyConfigDecode(__beyyReadConfig(name))
            local saved = {
                __version = 1.2,
                __elements = {},
                __custom = previous and previous.__custom or self.CustomData or {},
                __autoload = previous and previous.__autoload == true or false,
            }
            if previous then
                for key, entry in pairs(previous.__elements or previous) do
                    if type(entry) == "table" and type(entry.__type) == "string" then
                        saved.__elements[key] = entry
                    end
                end
            end
            for key, el in pairs(self.Elements) do
                local value = el.Value
                if el.__type == "Slider" then
                    value = type(value) == "table" and value.Default or value
                end
                if type(value) == "boolean" or type(value) == "string" or type(value) == "number"
                    or type(value) == "table" then
                    saved.__elements[key] = {__type = el.__type, value = value}
                end
            end
            return saved
        end
        function cfg:Save()
            local saved = self:Snapshot()
            local raw = __BEYY_CONFIG_HTTP:JSONEncode(saved)
            local playerStored, teleportStored = __beyyRememberConfig(name, raw)
            local diskOK = false
            if safeWrite(self.Path, raw) then
                for attempt = 1, 4 do
                    local check = __beyyConfigDecode(safeRead(self.Path))
                    if check and __beyySameJSON(check, saved) then
                        diskOK = true
                        break
                    end
                    if attempt < 4 then task.wait(0.1) end
                end
            end
            local storage = diskOK and "disk" or (playerStored and "session"
                or (teleportStored and "teleport" or "runtime"))
            if not diskOK then
                warn("[BeyyHub Config] " .. name .. " disk write unverified; session=" ..
                    tostring(playerStored) .. " teleport=" .. tostring(teleportStored) ..
                    ". Export JSON before closing Roblox.")
            end
            print("[BeyyHub Config] Saved " .. name .. " (storage=" .. storage .. ")")
            return saved, storage
        end
        function cfg:Load()
            local raw, source = __beyyReadConfig(name)
            local data = __beyyConfigDecode(raw)
            if not data then return false, "No readable config: " .. name end
            local applied = 0
            for key, el in pairs(self.Elements) do
                local entry = (data.__elements or data)[key]
                if type(entry) == "table" and entry.__type == el.__type then
                    local ok, err = pcall(function()
                        if el.__type == "Dropdown" then el:Select(entry.value)
                        else el:Set(entry.value) end
                    end)
                    if ok then applied += 1
                    else warn("[BeyyHub Config] Could not restore " .. tostring(key) .. ": " .. tostring(err)) end
                end
            end
            self.CustomData = data.__custom or {}
            __beyyRememberConfig(name, raw)
            print("[BeyyHub Config] Loaded " .. name .. " from " .. source .. " (" .. applied .. " controls)")
            return self.CustomData, source
        end
        function cfg:Export()
            return __BEYY_CONFIG_HTTP:JSONEncode(self:Snapshot())
        end
        function cfg:Import(raw)
            if type(raw) ~= "string" or #raw > 250000 then return false, "Invalid JSON size" end
            local data = __beyyConfigDecode(raw)
            if not data then return false, "Invalid BeyyHub JSON" end
            __beyyRememberConfig(name, __BEYY_CONFIG_HTTP:JSONEncode(data))
            return self:Load()
        end
        return cfg
    end
    local function getConfigNames()
        local ok, names = pcall(function() return ConfigManager:AllConfigs() end)
        if not ok or type(names) ~= "table" then
            warn("[Config] Unable to list saved configs: ".. tostring(names))
            names = {}
        end
        local result, seen = {}, {}
        local sessionFolder = __beyyPlayerConfigFolder(false)
        if sessionFolder then
            for _, savedEntry in ipairs(sessionFolder:GetChildren()) do
                if savedEntry:IsA("StringValue") and __beyyConfigDecode(savedEntry.Value)
                    and not seen[savedEntry.Name] then
                    seen[savedEntry.Name] = true
                    table.insert(result, savedEntry.Name)
                end
            end
        end
        for rememberedName, rememberedJSON in pairs(__beyyConfigSession) do
            if __beyyConfigDecode(rememberedJSON) and not seen[rememberedName] then
                seen[rememberedName] = true
                table.insert(result, rememberedName)
            end
        end
        for _, name in ipairs(names) do
            if type(name) == "string" and #name > 0 and not seen[name] then
                seen[name] = true
                table.insert(result, name)
            end
        end
        table.sort(result, function(a, b) return a:lower() < b:lower() end)
        return result
    end
    local function containsConfig(list, name)
        for _, entry in ipairs(list) do if entry == name then return true end end
        return false
    end
    local function refreshConfigDropdown(preferredName)
        local names = getConfigNames()
        local chosen = nil
        if preferredName and containsConfig(names, preferredName) then
            chosen = preferredName
        elseif selectedConfigName and containsConfig(names, selectedConfigName) then
            chosen = selectedConfigName
        elseif containsConfig(names, "default") then
            chosen = "default"
        else
            chosen = names[1]
        end
        selectedConfigName = chosen
        if configDropdown then
            local values = #names > 0 and names or { EMPTY_CONFIG }
            local ok, err = pcall(function()
                configDropdown:Refresh(values)
                configDropdown:Select(chosen or EMPTY_CONFIG)
            end)
            if not ok then warn("[Config] Dropdown refresh failed: ".. tostring(err)) end
        end
        return #names
    end
    if ConfigManager then
        local saved = getConfigNames()
        local activeSavedName = __beyyActiveConfigName()
        local initialConfig = containsConfig(saved, activeSavedName) and activeSavedName
            or (containsConfig(saved, "default") and "default" or saved[1])
        selectedConfigName = initialConfig
        configDropdown = ConfigTab:Dropdown({
            Title = "Select Config to Load",
            Desc = "Choose from your saved config files",
            Values = #saved > 0 and saved or { EMPTY_CONFIG },
            Value = initialConfig or EMPTY_CONFIG,
            AllowNone = false,
            Callback = function(value)
                selectedConfigName = (type(value) == "string" and value ~= EMPTY_CONFIG) and value or nil
            end,
        })
        ConfigTab:Button({
            Title = "Refresh Config List",
            Callback = function()
                local count = refreshConfigDropdown()
                Notify("Config", "Found ".. tostring(count).. " saved config(s)", 3, "refresh-cw")
            end,
        })
        ConfigTab:Button({
            Title = "Load Selected Config",
            Callback = function()
                local name = selectedConfigName
                if not name or not containsConfig(getConfigNames(), name) then
                    Notify("Config", "Select an existing config first", 3, "x")
                    return
                end
                local ok, loaded, err = pcall(function() return buildConfig(name):Load() end)
                local success = ok and loaded ~= false and loaded ~= nil
                Notify("Config", success and ("Loaded: ".. name) or ("Failed: ".. tostring(ok and err or loaded)), 3, success and "check" or "x")
            end,
        })
        ConfigTab:Input({
            Title = "Save Config As", Value = saveConfigName, Placeholder = "default",
            Callback = function(value)
                if type(value) == "string" and value:match("%S") then saveConfigName = value end
            end,
        })
        ConfigTab:Button({
            Title = "Save Config",
            Callback = function()
                local name = saveConfigName
                if not name or not name:match("^[%w_%-%s]+$") then
                    Notify("Config", "Use letters, numbers, spaces, _ or -", 3, "x")
                    return
                end
                local ok, savedData, storage = pcall(function() return buildConfig(name):Save() end)
                local success = ok and type(savedData) == "table"
                if success then refreshConfigDropdown(name) end
                Notify("Config", success and (storage == "disk" and ("Saved to disk: ".. name)
                    or (storage == "session" and ("Session saved: ".. name .. " (copy JSON for restart)")
                    or ("Runtime/teleport only: " .. name .. " (copy JSON)")))
                    or ("Failed: ".. tostring(ok and storage or savedData)), 5, success and "check" or "x")
            end,
        })
        local pastedConfigJSON = ""
        ConfigTab:Input({
            Title = "Paste Config JSON for import", Value = "", Placeholder = "Paste exported JSON here",
            Callback = function(value) pastedConfigJSON = tostring(value or "") end,
        })
        ConfigTab:Button({
            Title = "Copy Config JSON",
            Callback = function()
                local name = saveConfigName
                local ok, raw = pcall(function() return buildConfig(name):Export() end)
                if not ok then Notify("Config", "Export failed: " .. tostring(raw), 4, "x"); return end
                if type(setclipboard) == "function" then
                    local copied = pcall(setclipboard, raw)
                    Notify("Config", copied and ("Copied " .. name .. " JSON; keep it outside Roblox for restarts.") or
                        "Could not copy JSON", 5, copied and "check" or "x")
                else
                    print("[BeyyHub Config Export] " .. raw)
                    Notify("Config", "Clipboard unavailable; JSON printed to console", 4)
                end
            end,
        })
        ConfigTab:Button({
            Title = "Import Config JSON",
            Callback = function()
                local raw = pastedConfigJSON
                if raw == "" and type(getclipboard) == "function" then
                    local ok, value = pcall(getclipboard)
                    if ok and type(value) == "string" then raw = value end
                end
                local name = saveConfigName
                local ok, result, detail = pcall(function() return buildConfig(name):Import(raw) end)
                local success = ok and result ~= false and result ~= nil
                if success then refreshConfigDropdown(name) end
                Notify("Config", success and ("Imported " .. name .. " for this session. Save to try disk.") or
                    ("Import failed: " .. tostring(ok and detail or result)), 5, success and "check" or "x")
            end,
        })
        task.defer(function()
            if hubUnloaded then return end
            local startConfig = __beyyActiveConfigName()
            local raw = __beyyReadConfig(startConfig)
            if not raw and startConfig ~= "default" then
                startConfig = "default"
                raw = __beyyReadConfig(startConfig)
            end
            local cfg = buildConfig(startConfig)
            if not raw then
                warn("[BeyyHub] Chapter 2 default config unavailable at " .. tostring(cfg.Path))
                return
            end
            local ok, decoded = pcall(function() return httpService:JSONDecode(raw) end)
            if not ok or type(decoded) ~= "table" then
                warn("[BeyyHub] Chapter 2 default config is unreadable")
                return
            end
            local loadedOK, loaded, err = pcall(function() return cfg:Load() end)
            if not loadedOK or loaded == false or loaded == nil then
                warn("[BeyyHub] Chapter 2 default config load failed: " .. tostring(err or loaded))
                return
            end
            print("[BeyyHub] Chapter 2 latest default config applied synchronously")
        end)
    else
        ConfigTab:Paragraph({ Title = "Configs unavailable", Desc = "Saving configs requires filesystem support in your environment." })
    end
        end)()
    end

    task.defer(function()
        if not hubUnloaded then hideNonFarmMenu() end
    end)
    print("[BeyyHub] v103.00 " .. BEYY_CHAPTER .. " module loaded (RightControl to open)")
    print(("[BeyyHub Startup] %s controls and features registered after %.2fs in module"):format(
        BEYY_CHAPTER, os.clock() - __BEYY_BOOT_T0))
end
