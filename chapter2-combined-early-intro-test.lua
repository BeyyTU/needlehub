-- Beyy Chapter 2 Combined Early Intro Test v1
-- Standalone experimental combination:
-- (1) Hide the visible CutsceneFade.Black overlay,
-- (2) allow mouse-driven camera before the first native Skip button,
-- (3) release camera and click that normal Skip button instantly.
-- No puzzle remotes, forced attributes, character teleports, or Main edits.
-- Start from lobby; this copy is queued verbatim for the Chapter 2 teleport.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-combined-early-intro-test.lua"
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
        and body:find("Beyy Chapter 2 Combined Early Intro Test v1",1,true)
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
local timeout=36
local player=nil
local alive=true
local connections={}
local eventLines={}
local firstTimes={}
local attrs={}
local outputPath="BeyyHub/chapter2_combined_early_intro_result.txt"
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
        "CHAPTER 2 COMBINED EARLY INTRO TEST v1",
        "Times relative to the test executing in Chapter 2.",
        "Only CutsceneFade.Black visibility, local camera/mouse, and native Skip GUI clicks are modified.",
        "Attempts: "..tostring(attempts),
        "Stopped: "..tostring(stopReason or "in progress"),
        "=== MILESTONES ==="
    }
    for _,name in ipairs({"player","loaded","character","leversReady","cutsceneActive",
        "overlayFound","overlayHidden","cameraStarted","cameraMoved","skipVisible",
        "cameraReleased","firstClick","cutsceneCleared","introFinished",
        "overlayRestored","userCameraWorksF6","userCameraLockedF7"}) do
        result[#result+1]=name.." = "..(firstTimes[name] and
            string.format("+%.3fs",firstTimes[name]) or "NOT OBSERVED")
    end
    if firstTimes.firstClick and firstTimes.introFinished then
        result[#result+1]=string.format("Time click -> intro complete = %.3fs",
            firstTimes.introFinished-firstTimes.firstClick)
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
    if remotes and (remotes:GetAttribute("LeverPuzzleSolved")==true
        or (tonumber(remotes:GetAttribute("SolvedPuzzleCount")) or 0)>0) then
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
            and seconds()-introCompletedAt>=2.0 then
            stop("intro finished; results captured")
            return
        end
        if alive and seconds()>15 and lastSaveAt<15 then save(false) end
        if alive and seconds()>25 and lastSaveAt<25 then save(false) end
        task.wait(seconds()<19 and 0.035 or 0.12)
    end
    if alive then stop("36s test ended; intro completion not confirmed") end
end)
