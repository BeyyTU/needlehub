-- Beyy Chapter 2 Cutscene-Only Standalone v2
-- Intro: click only the game's native opening Skip button.
-- Non-final lever/puzzle cinematics: local camera/input/overlay recovery only.
-- No puzzle or lever actions, hay teleport, progression remotes, or final-ending bypass.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-cutscene-only.lua"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

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
        warn("[CH2 CUTSCENE] queue_on_teleport unavailable; run again upon joining Chapter 2.")
        return
    end
    local payload,reason=nil,"no response"
    for attempt=1,3 do
        local ok,body=pcall(function()
            return game:HttpGet(URL.."?preload=cutscene-v2-"..tostring(os.time())..
                "-"..tostring(math.random(10000,99999)).."-"..tostring(attempt))
        end)
        if ok and type(body)=="string"
            and body:find("Beyy Chapter 2 Cutscene-Only Standalone v2",1,true) then
            local fn,err=loadstring(body)
            if fn then
                payload=body
                break
            end
            reason=tostring(err)
        else
            reason=ok and "wrong version/invalid source" or tostring(body)
        end
        task.wait(0.25)
    end
    if not payload then
        warn("[CH2 CUTSCENE] NOT queued; source failed preflight: "..reason)
        return
    end
    local ok,err=pcall(queue,payload)
    if ok then
        print("[CH2 CUTSCENE] Compiled and queued cutscene-only v2. Enter Chapter 2.")
    else
        warn("[CH2 CUTSCENE] Queue failed: "..tostring(err))
    end
    return
end
if game.PlaceId~=CHAPTER2 then
    warn("[CH2 CUTSCENE] Only Chapter 2 or the lobby is supported.")
    return
end

if type(env.__BEYY_CH2_CUTSCENE_ONLY_STOP)=="function" then
    pcall(env.__BEYY_CH2_CUTSCENE_ONLY_STOP,"restarted")
end
local started=os.clock()
local alive=true
local player=Players.LocalPlayer
local events={}
local connections={}
local bindName="BeyyCh2CutsceneOnly_"..tostring(player and player.UserId or 0)
local outputPath="BeyyHub/chapter2_cutscene_only_result.txt"
local stopReason="running"
local introClicks=0
local nextClickAt=0
local introCameraActive=false
local introCameraFrames=0
local introCameraReleased=false
local nonfinalGraceUntil=0
local lastSceneSignal="none"
local lastFlagState=nil
local lastPuzzleCount=nil
local lastLeverSolved=nil
local lastSignalLoggedAt=-math.huge
local introBlack=nil
local blackOriginal=nil
local introBlackHidden=false
local introBlackRestored=false
local bypassActive=false
local bypassCount=0
local bypassFrames=0
local inputRestores=0
local bypassStartedAt=0
local releaseGraceUntil=0
local finalProtectedLogged=false
local masked={}
local lastMaskAt=-math.huge
local lastInputAt=-math.huge
local lastReportAt=-math.huge
local yaw,pitch=0,-0.18
local cameraDistance=4
local stop

local function seconds()
    return os.clock()-started
end
local function emit(kind,value)
    local msg=string.format("+%.3fs [%s] %s",seconds(),tostring(kind),tostring(value))
    events[#events+1]=msg
    if #events>240 then table.remove(events,1) end
    print("[CH2 CUTSCENE] "..msg)
end
local function hook(signal,callback)
    local connection=signal:Connect(callback)
    connections[#connections+1]=connection
    return connection
end
local function endingProtected()
    if not player then return true end
    if player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("NeedleOwned")==true then return true end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local ending=gui and gui:FindFirstChild("NeedleEndingUI")
    local results=ending and ending:FindFirstChild("ReturnToLobby",true)
    if not (ending and ending:IsA("ScreenGui") and ending.Enabled
        and results and results:IsA("GuiObject")) then return false end
    local node=results
    while node and node~=ending do
        if node:IsA("GuiObject") and not node.Visible then return false end
        node=node.Parent
    end
    return node==ending
end
local function nativeIntroSkip()
    if not player or endingProtected()
        or player:GetAttribute("IntroCutsceneFinished")==true then return nil end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local fade=gui and gui:FindFirstChild("CutsceneFade")
    local holder=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    local button=holder and holder:FindFirstChild("Button",true)
    if not (fade and holder and button and button:IsA("GuiButton")
        and button.Visible and button.AbsoluteSize.X>8
        and button.AbsoluteSize.Y>8) then return nil end
    local obj=button
    while obj and obj~=gui do
        if obj:IsA("GuiObject") and not obj.Visible then return nil end
        if obj:IsA("ScreenGui") and not obj.Enabled then return nil end
        obj=obj.Parent
    end
    return obj==gui and button or nil
end
local function hideIntroBlack()
    if not player or player:GetAttribute("IntroCutsceneFinished")==true
        or endingProtected() then return end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local fade=gui and gui:FindFirstChild("CutsceneFade")
    local black=fade and fade:FindFirstChild("Black",true)
    if not (black and black:IsA("GuiObject")) then return end
    if black~=introBlack then
        introBlack=black
        blackOriginal=black.Visible
    end
    if black.Visible then
        local ok=pcall(function()black.Visible=false end)
        if ok and not introBlackHidden then
            introBlackHidden=true
            emit("INTRO","Blackout hidden; no game actions sent")
        end
    end
end
local function restoreIntroBlack()
    if introBlackRestored then return end
    introBlackRestored=true
    -- The game may leave CutsceneFade enabled after native Skip. Forcing the
    -- originally visible Black overlay back then would cover gameplay.
    -- During cleanup before Skip, however, undo our temporary intro mask.
    if player and player:GetAttribute("IntroCutsceneFinished")==true then
        emit("INTRO","Opening blackout retained hidden after native Skip")
        return
    end
    if introBlack and introBlack.Parent and blackOriginal~=nil then
        pcall(function()introBlack.Visible=blackOriginal end)
    end
end
local function clickIntroSkip(button)
    if not alive or not button or not nativeIntroSkip() then return end
    -- Release pre-Skip camera mouse lock before synthetic GUI input.
    if introCameraActive then
        introCameraActive=false
        introCameraReleased=true
        local cam=Workspace.CurrentCamera
        if cam then cam.CameraType=Enum.CameraType.Custom end
        pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.Default end)
        emit("CAMERA","Released early camera for native Skip button")
    end
    local centre=button.AbsolutePosition+button.AbsoluteSize/2
    local inset=GuiService:GetGuiInset()
    local p=centre+(introClicks==1 and inset or Vector2.zero)
    local pressed=false
    local ok,err=pcall(function()
        VirtualInputManager:SendMouseMoveEvent(p.X,p.Y,game)
        task.wait(0.035)
        if not alive or not nativeIntroSkip() then return end
        VirtualInputManager:SendMouseButtonEvent(p.X,p.Y,0,true,game,0)
        pressed=true
        task.wait(0.075)
    end)
    if pressed then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(p.X,p.Y,0,false,game,0)
        end)
    end
    emit("INTRO",ok and ("Native Skip click #"..introClicks.." sent="..tostring(pressed))
        or ("Native Skip click failed: "..tostring(err)))
end
local function restoreMasked()
    for obj,props in pairs(masked) do
        if obj.Parent then
            for property,value in pairs(props) do
                pcall(function()obj[property]=value end)
            end
        end
        masked[obj]=nil
    end
end
local function maskNonfinalVisuals()
    if os.clock()-lastMaskAt<0.18 or not player then return end
    lastMaskAt=os.clock()
    local gui=player:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    local function mask(obj,key)
        local ok,value=pcall(function()return obj[key] end)
        if not ok or type(value)~="number" or value>=1 then return end
        local saved=masked[obj]
        if not saved then saved={};masked[obj]=saved end
        if saved[key]==nil then saved[key]=value end
        pcall(function()obj[key]=1 end)
    end
    for _,screen in ipairs(gui:GetChildren()) do
        if screen:IsA("ScreenGui") then
            local name=screen.Name:lower()
            if (name=="cutscenefade" or name:find("cutscene",1,true)
                or name:find("cinematic",1,true)
                or name:find("chapter2release",1,true))
                and not name:find("needle",1,true)
                and not name:find("ending",1,true) then
                for _,obj in ipairs(screen:GetDescendants()) do
                    if obj:IsA("GuiObject") then
                        mask(obj,"BackgroundTransparency")
                        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                            mask(obj,"ImageTransparency")
                        elseif obj:IsA("TextLabel") or obj:IsA("TextButton")
                            or obj:IsA("TextBox") then
                            mask(obj,"TextTransparency")
                            mask(obj,"TextStrokeTransparency")
                        end
                    elseif obj:IsA("UIStroke") then
                        mask(obj,"Transparency")
                    end
                end
            end
        end
    end
end
local cachedControls=nil
local function restoreMovement()
    if not player or endingProtected()
        or os.clock()-lastInputAt<0.14 then return end
    lastInputAt=os.clock()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local changed=false
    if hum then
        if hum.PlatformStand then hum.PlatformStand=false;changed=true end
        if hum.Sit then hum.Sit=false;changed=true end
        if hum.WalkSpeed<=0 then hum.WalkSpeed=16;changed=true end
        if hum.JumpPower<=0 then hum.JumpPower=50;changed=true end
    end
    if root and root.Anchored
        and (player:GetAttribute("CutsceneActive")==true
            or player:GetAttribute("Chapter2ReleaseActive")==true) then
        root.Anchored=false
        changed=true
    end
    if not cachedControls then
        local ps=player:FindFirstChild("PlayerScripts")
        local module=ps and ps:FindFirstChild("PlayerModule")
        if module then
            local ok,controls=pcall(function()return require(module):GetControls()end)
            if ok then cachedControls=controls end
        end
    end
    if cachedControls then
        pcall(function()cachedControls:Enable()end)
    end
    if player:GetAttribute("NeedleInputLocked")==true then
        pcall(function()player:SetAttribute("NeedleInputLocked",nil)end)
        changed=true
    end
    if changed then
        inputRestores+=1
        if inputRestores<=4 then emit("CONTROL","Non-final movement restored") end
    end
end
local function enableCamera()
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not (root and cam) then return false end
    local look=root.CFrame.LookVector
    yaw=math.atan2(look.X,look.Z)
    pitch=-0.18
    return true
end
local function restoreNativeCamera()
    introCameraActive=false
    local cam=Workspace.CurrentCamera
    if cam then
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function()cam.CameraSubject=hum end) end
        pcall(function()cam.CameraType=Enum.CameraType.Custom end)
    end
    pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.Default end)
end
local function beginIntroCamera()
    if not alive or introCameraActive or introCameraReleased or bypassActive
        or not player or endingProtected()
        or player:GetAttribute("IntroCutsceneFinished")==true then return end
    if not enableCamera() then return end
    introCameraActive=true
    emit("CAMERA","Early mouse camera ON during opening blackout; no game actions")
end
local function finishIntroCamera(reason)
    if not introCameraActive then return end
    introCameraActive=false
    introCameraReleased=true
    restoreNativeCamera()
    emit("CAMERA","Early mouse camera OFF: "..tostring(reason))
end
local function beginBypass()
    if bypassActive or endingProtected() then return end
    finishIntroCamera("non-final cinematic taking over")
    if not enableCamera() then return end
    bypassActive=true
    bypassCount+=1
    bypassStartedAt=os.clock()
    emit("NONFINAL","Playable camera/input/visual bypass ON; server cutscene timer unchanged")
end
local function endBypass(reason)
    if not bypassActive then return end
    bypassActive=false
    restoreNativeCamera()
    restoreMasked()
    emit("NONFINAL","Bypass OFF: "..tostring(reason))
end
local function driveCamera()
    if not alive or not (bypassActive or introCameraActive)
        or endingProtected() then return end
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not (root and cam) then return end
    local ok,delta=pcall(function()return UserInputService:GetMouseDelta()end)
    if not UserInputService:GetFocusedTextBox() then
        pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter end)
        if ok and delta then
            yaw-=delta.X*0.004
            pitch=math.clamp(pitch-delta.Y*0.004,-1,0.85)
        end
    end
    local cp=math.cos(pitch)
    local dir=Vector3.new(math.sin(yaw)*cp,math.sin(pitch),math.cos(yaw)*cp)
    local focus=root.Position+Vector3.new(0,1.6,0)
    local behind=focus-dir*cameraDistance
    local cast=RaycastParams.new()
    cast.FilterType=Enum.RaycastFilterType.Exclude
    cast.FilterDescendantsInstances={char}
    cast.RespectCanCollide=true
    local hit=Workspace:Raycast(focus,behind-focus,cast)
    if hit then behind=focus-dir*math.max(0.45,(hit.Position-focus).Magnitude-0.3) end
    cam.CameraType=Enum.CameraType.Scriptable
    cam.CFrame=CFrame.lookAt(behind,focus,Vector3.yAxis)
    cam.Focus=CFrame.new(focus)
    if bypassActive then bypassFrames+=1
    else introCameraFrames+=1 end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if bypassActive and hum and not UserInputService:GetFocusedTextBox() then
        local function down(key)return UserInputService:IsKeyDown(key) end
        local x=(down(Enum.KeyCode.D) and 1 or 0)-(down(Enum.KeyCode.A) and 1 or 0)
        local z=(down(Enum.KeyCode.W) and 1 or 0)-(down(Enum.KeyCode.S) and 1 or 0)
        if x~=0 or z~=0 then
            local front=Vector3.new(math.sin(yaw),0,math.cos(yaw))
            local right=Vector3.new(-front.Z,0,front.X)
            local movement=front*z+right*x
            if movement.Magnitude>1 then movement=movement.Unit end
            pcall(function()hum:Move(movement,false)end)
        end
    end
end
local function report()
    local list={
        "CHAPTER 2 CUTSCENE-ONLY STANDALONE v2",
        "No lever/puzzle/needle remotes sent. No teleport performed.",
        "Intro Skip attempts: "..tostring(introClicks),
        "Intro early camera frames: "..tostring(introCameraFrames),
        "Last non-final signal: "..tostring(lastSceneSignal),
        "Blackout hidden: "..tostring(introBlackHidden),
        "Non-final bypass activations: "..tostring(bypassCount),
        "Non-final camera frames: "..tostring(bypassFrames),
        "Movement restores: "..tostring(inputRestores),
        "Final ending protected: "..tostring(finalProtectedLogged),
        "Only local non-final cinematic visuals/input changed; server timers not modified.",
        "Stopped: "..stopReason,
        "=== EVENTS ===",
        table.concat(events,"\n"),
    }
    return table.concat(list,"\n")
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
        if not ok then warn("[CH2 CUTSCENE] Report write failed: "..tostring(err)) end
    end
    if copy and type(setclipboard)=="function" then
        local ok=pcall(setclipboard,body)
        if ok then print("[CH2 CUTSCENE] F8 copied report to clipboard") end
    end
end
stop=function(reason)
    if not alive then return end
    stopReason=tostring(reason or "manual stop")
    alive=false
    endBypass("cleanup")
    finishIntroCamera("cleanup")
    restoreIntroBlack()
    restoreNativeCamera()
    pcall(function()RunService:UnbindFromRenderStep(bindName)end)
    for _,connection in ipairs(connections) do
        pcall(function()connection:Disconnect()end)
    end
    table.clear(connections)
    emit("DONE",stopReason)
    save(false)
end
env.__BEYY_CH2_CUTSCENE_ONLY_STOP=stop
env.__BEYY_CH2_CUTSCENE_ONLY_REPORT=report
hook(UserInputService.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F8 then save(true) end
end)
pcall(function()RunService:UnbindFromRenderStep(bindName)end)
RunService:BindToRenderStep(bindName,Enum.RenderPriority.Last.Value+2100,driveCamera)
emit("READY","Cutscene-only v2. Early manual camera + native intro Skip + timed non-final bypass. F8 copies report.")
if type(env.__BEYY_CH2_COMBO_STOP)=="function" then
    emit("WARNING","Another Chapter 2 combo puzzle controller is present; do not run Main and this standalone together.")
end
task.spawn(function()
    local wasNonfinal=false
    local lastSaveAt=0
    while alive and seconds()<480 do
        local ok,err=pcall(function()
            if not player then player=Players.LocalPlayer end
            if not player then return end
            if endingProtected() then
                if not finalProtectedLogged then
                    finalProtectedLogged=true
                    emit("FINAL","Final needle ending protected; no bypass or Skip clicks")
                end
                endBypass("final ending protected")
                restoreIntroBlack()
                return
            end
            local introDone=player:GetAttribute("IntroCutsceneFinished")==true
            local cutscene=player:GetAttribute("CutsceneActive")==true
            local release=player:GetAttribute("Chapter2ReleaseActive")==true
            local locked=player:GetAttribute("NeedleInputLocked")==true
            local folder=ReplicatedStorage:FindFirstChild("Puzzles")
            local solved=folder and tonumber(folder:GetAttribute("SolvedPuzzleCount")) or 0
            local leverSolved=folder and folder:GetAttribute("LeverPuzzleSolved")==true or false
            if not introDone then
                hideIntroBlack()
                local skip=nativeIntroSkip()
                if skip then
                    finishIntroCamera("native intro Skip visible")
                elseif cutscene and player.Character
                    and not introCameraReleased then
                    beginIntroCamera()
                end
                if skip and introClicks<2 and seconds()<42
                    and seconds()>=nextClickAt then
                    introClicks+=1
                    nextClickAt=seconds()+1
                    task.spawn(clickIntroSkip,skip)
                end
            else
                finishIntroCamera("IntroCutsceneFinished")
                restoreIntroBlack()
            end

            -- Watch replicated flags/puzzle progress without sending game actions.
            -- Short cinematics can pulse or overlap the intro.
            local state=tostring(introDone).."/"..tostring(cutscene).."/"..
                tostring(release).."/"..tostring(locked).."/"..
                tostring(solved).."/"..tostring(leverSolved)
            if state~=lastFlagState then
                if os.clock()-lastSignalLoggedAt>=0.16 then
                    emit("STATE","intro/cutscene/release/inputLock/solved/lever="..state)
                    lastSignalLoggedAt=os.clock()
                end
                lastFlagState=state
            end
            if introDone then
                local signal=nil
                if release then
                    signal="Chapter2ReleaseActive"
                elseif cutscene then
                    signal="CutsceneActive"
                elseif locked and (solved>0 or leverSolved) then
                    signal="NeedleInputLocked during puzzle/lever cinematic"
                elseif (lastPuzzleCount~=nil and solved>lastPuzzleCount)
                    or (lastLeverSolved==false and leverSolved) then
                    signal="replicated puzzle/lever completion"
                end
                if signal then
                    nonfinalGraceUntil=os.clock()+2.0
                    if signal~=lastSceneSignal then
                        lastSceneSignal=signal
                        emit("NONFINAL","Signal "..signal.."; short visual/input grace armed")
                    end
                end
            end
            lastPuzzleCount=solved
            lastLeverSolved=leverSolved
            local nonfinal=introDone and
                (cutscene or release or os.clock()<nonfinalGraceUntil)
            if nonfinal then
                releaseGraceUntil=os.clock()+0.55
                beginBypass()
            elseif bypassActive and os.clock()>releaseGraceUntil then
                endBypass("non-final flags and 2s grace cleared")
            end
            if bypassActive then
                restoreMovement()
                maskNonfinalVisuals()
            end
            if wasNonfinal~=nonfinal then
                emit("STATE","Non-final bypass window="..tostring(nonfinal)..
                    " cutscene="..tostring(cutscene)..
                    " release="..tostring(release)..
                    " solved="..tostring(solved))
                wasNonfinal=nonfinal
            end
        end)
        if not ok then
            emit("ERROR",tostring(err))
        end
        if seconds()-lastSaveAt>20 then
            lastSaveAt=seconds()
            save(false)
        end
        task.wait(seconds()<25 and 0.04 or 0.11)
    end
    if alive then stop("8-minute monitoring limit") end
end)
