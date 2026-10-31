-- Beyy Chapter 2 No-Levers + Working Cutscene v24
-- Standalone experimental combination:
-- (1) Hide the visible CutsceneFade.Black overlay,
-- (2) allow mouse-driven camera before the first native Skip button,
-- (3) release camera and click that normal Skip button instantly.
-- No puzzle remotes, forced attributes, character teleports, or Main edits.
-- Start from lobby; this copy is queued verbatim for the Chapter 2 teleport.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local SKIP_LEVERS_TEST=true -- Diagnostic: send NO lever actions
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
            return game:HttpGet(URL.."?preload=v24-v4port-"..tostring(os.time())..
                "-"..tostring(math.random(10000,99999)).."-"..tostring(attempt))
        end)
        if ok and type(source)=="string"
            and source:find("Beyy Chapter 2 No-Levers + Working Cutscene v24",1,true) then
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
        warn("[CH2 COMBO] v24 NO-LEVERS + CUTSCENE NOT queued: "..tostring(compileError))
        warn("[CH2 COMBO] No online fallback will execute. Retry in the lobby.")
        return
    end
    local armed,err=pcall(queue,body)
    if armed then
        print("[CH2 COMBO] Preloaded and compiled v24 NO-LEVERS + CUTSCENE ("..tostring(#body)..
            " bytes). Enter Chapter 2.")
    else
        warn("[CH2 COMBO] Failed to queue v24: "..tostring(err))
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

-- The confirmed-working Chapter2 cutscene-only v4 is embedded as a
-- separate, independently compiled chunk. This avoids Luau's 200-local limit
-- and prevents a second GitHub request during Chapter2 initialization.
-- Cutscene v4 is the ONLY camera/intro/skip/noclip controller in this script.
local __BEYY_CH2_CUTSCENE_V4_SOURCE=[==========[
-- Beyy Chapter 2 Cutscene-Only Standalone v4
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
            return game:HttpGet(URL.."?preload=cutscene-v4-main-port-"..tostring(os.time())..
                "-"..tostring(math.random(10000,99999)).."-"..tostring(attempt))
        end)
        if ok and type(body)=="string"
            and body:find("Beyy Chapter 2 Cutscene-Only Standalone v4",1,true) then
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
        print("[CH2 CUTSCENE] Compiled and queued cutscene-only v4 (Main controller + noclip). Enter Chapter 2.")
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

-- This controller is copied from Chapter2 Main (launchCutsceneBypass),
-- with only its Main/UI dependencies replaced by standalone state.
-- It runs separately from the native intro Skip/blackout handler.
local finalEndingProtected=false
local needleBusy=false
local leverRunning=false
local colourRunning=false
local gemCutsceneCameraAim=nil
local hubWindow={Closed=true}
local leverBypassUntil=0
local puzzleBypassUntil=0
local cutsceneBypassRefresh=nil
local cutsceneBypassStop=nil
local puzzleNoclipActive=false
local puzzleNoclipUsed=false
local puzzleNoclipStartedAt=-math.huge
local puzzleNoclipUntil=-math.huge
local puzzleNoclipCharacter=nil
local puzzleNoclipSaved={}
local puzzleNoclipFloor=nil
local puzzleNoclipFloorY=nil
local puzzleNoclipFrames=0
local puzzleNoclipActivations=0

local function shouldYieldCutsceneBypass()
    -- Standalone combined test: while the separate puzzle worker is
    -- targeting native Picture/Color/Number stages, release our cutscene
    -- camera so its proximity/input actions cannot be disrupted.
    return not alive or endingProtected() or introCameraActive
        or env.__BEYY_CH2_COMBO_PUZZLE_RUNNING==true
end
local function setCutsceneBypassActive(on)
    local was=bypassActive
    bypassActive=on==true
    if bypassActive and not was then
        bypassCount+=1
        emit("MAIN CUTSCENE","Playable camera activated")
    elseif was and not bypassActive then
        emit("MAIN CUTSCENE","Native camera restored")
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
    if not alive or introCameraActive or introCameraReleased
        or bypassActive or not player or endingProtected()
        or player:GetAttribute("IntroCutsceneFinished")==true then return end
    if not enableCamera() then return end
    introCameraActive=true
    emit("CAMERA","Pre-Skip mouse camera enabled")
end
local function finishIntroCamera(reason)
    if not introCameraActive then return end
    introCameraActive=false
    introCameraReleased=true
    restoreNativeCamera()
    emit("CAMERA","Pre-Skip camera released: "..tostring(reason))
end
local function driveCamera()
    if not alive or not introCameraActive or endingProtected() then return end
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
    local desired=focus-dir*cameraDistance
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char}
    params.RespectCanCollide=true
    local hit=Workspace:Raycast(focus,desired-focus,params)
    if hit then desired=focus-dir*math.max(0.45,(hit.Position-focus).Magnitude-0.3) end
    cam.CameraType=Enum.CameraType.Scriptable
    cam.CFrame=CFrame.lookAt(desired,focus,Vector3.yAxis)
    cam.Focus=CFrame.new(focus)
    introCameraFrames+=1
end

-- Non-final puzzle-release noclip only. Original collision state is
-- captured per avatar part and restored on release, ending, stop, or death.
-- A temporary local floor follows X/Z to prevent falling through the map.
local function endPuzzleNoclip(reason)
    if not puzzleNoclipActive and not puzzleNoclipFloor then return end
    puzzleNoclipActive=false
    for part,original in pairs(puzzleNoclipSaved) do
        if part.Parent then pcall(function()part.CanCollide=original end) end
        puzzleNoclipSaved[part]=nil
    end
    if puzzleNoclipFloor then
        pcall(function()puzzleNoclipFloor:Destroy()end)
        puzzleNoclipFloor=nil
    end
    puzzleNoclipCharacter=nil
    puzzleNoclipFloorY=nil
    emit("NOCLIP","OFF "..tostring(reason)..
        " frames="..tostring(puzzleNoclipFrames))
end
local function beginPuzzleNoclip(root)
    if puzzleNoclipActive or puzzleNoclipUsed
        or not alive or not player
        or player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("IntroCutsceneFinished")~=true then return end
    local char=player.Character
    if not (char and root and root.Parent==char) then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    puzzleNoclipUsed=true
    puzzleNoclipActive=true
    puzzleNoclipCharacter=char
    puzzleNoclipStartedAt=os.clock()
    puzzleNoclipUntil=os.clock()+14
    puzzleNoclipFrames=0
    puzzleNoclipActivations+=1
    local floorY=root.Position.Y-(hum.HipHeight+root.Size.Y*0.5)
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances={char}
    local hit=Workspace:Raycast(root.Position,Vector3.new(0,-9,0),rayParams)
    if hit and math.abs(hit.Position.Y-floorY)<4 then
        floorY=hit.Position.Y
    end
    puzzleNoclipFloorY=floorY
    local support=Instance.new("Part")
    support.Name="BeyyCh2_NoclipLocalFloor"
    support.Anchored=true
    support.CanCollide=true
    support.CanTouch=false
    -- Keep CanQuery at its default: Roblox requires it when CanCollide=true.
    support.Transparency=1
    support.Size=Vector3.new(4,0.3,4)
    support.CFrame=CFrame.new(root.Position.X,floorY-0.16,root.Position.Z)
    support.Parent=Workspace
    puzzleNoclipFloor=support
    emit("NOCLIP",string.format(
        "ON for puzzle-release cinematic, max 14s; floorY=%.2f; no teleport",
        floorY))
end
hook(RunService.Stepped,function()
    if not puzzleNoclipActive then return end
    local char=puzzleNoclipCharacter
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not alive or endingProtected()
        or not char or char~=player.Character or not root
        or os.clock()>=puzzleNoclipUntil then
        endPuzzleNoclip("expired, ending, or character changed")
        return
    end
    -- Keep every avatar collider disabled. Tools and map geometry are not
    -- touched, and every previous CanCollide value is restored afterward.
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if puzzleNoclipSaved[obj]==nil then
                puzzleNoclipSaved[obj]=obj.CanCollide
            end
            if obj.CanCollide then obj.CanCollide=false end
        end
    end
    if puzzleNoclipFloor then
        puzzleNoclipFloor.CFrame=CFrame.new(
            root.Position.X,puzzleNoclipFloorY-0.16,root.Position.Z)
    end
    puzzleNoclipFrames+=1
end)


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
        local renderId = "BeyyCh2CutsceneOnly_MainCamera"
        local renderPriority = Enum.RenderPriority.Last.Value + 2000
        local RECOVERY_GRACE_SECONDS = 0.16
        local INTRO_SETTLE_SECONDS = 0.12
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
local function report()
    local list={
        "CHAPTER 2 CUTSCENE-ONLY STANDALONE v4",
        "No lever/puzzle/needle remotes sent. No teleport performed.",
        "Intro Skip attempts: "..tostring(introClicks),
        "Intro early camera frames: "..tostring(introCameraFrames),
        "Last non-final signal: "..tostring(lastSceneSignal),
        "Imported Chapter2 Main controller active: "..tostring(cutsceneBypassStop~=nil),
        "Main puzzle-release noclip activations: "..tostring(puzzleNoclipActivations),
        "Main puzzle-release noclip frames: "..tostring(puzzleNoclipFrames),
        "Main noclip currently active: "..tostring(puzzleNoclipActive),
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
    endPuzzleNoclip("standalone stopped")
    if cutsceneBypassStop then
        pcall(cutsceneBypassStop)
        cutsceneBypassStop=nil
    end
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
-- The combined puzzle test owns F8 and merges both reports.
-- Do not attach a second clipboard hotkey here.
pcall(function()RunService:UnbindFromRenderStep(bindName)end)
RunService:BindToRenderStep(bindName,Enum.RenderPriority.Last.Value+2100,driveCamera)
emit("READY","Cutscene-only v4. Chapter2 Main cinematic camera/HUD/input + puzzle noclip + native intro Skip. F8 copies report.")
if not launchCutsceneBypass() then
    emit("ERROR","Imported Chapter2 Main bypass failed to initialize")
end
if type(env.__BEYY_CH2_COMBO_STOP)=="function" then
    emit("READY","Embedded companion to the no-levers puzzle worker")
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
                finalEndingProtected=true
            endPuzzleNoclip("final ending protected")
            if cutsceneBypassRefresh then cutsceneBypassRefresh() end
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
            -- Main cutscene controller reads these native/replicated signals.
            -- We only extend a short local grace; no puzzle actions are sent.
            if introDone then
                local signal=nil
                if release then signal="Chapter2ReleaseActive"
                elseif cutscene then signal="CutsceneActive"
                elseif locked and (solved>0 or leverSolved) then
                    signal="NeedleInputLocked during puzzle/lever scene"
                elseif (lastPuzzleCount~=nil and solved>lastPuzzleCount)
                    or (lastLeverSolved==false and leverSolved) then
                    signal="replicated puzzle/lever completion"
                end
                if signal then
                    if release or solved>0 then
                        puzzleBypassUntil=math.max(puzzleBypassUntil,os.clock()+2.0)
                    else
                        leverBypassUntil=math.max(leverBypassUntil,os.clock()+2.0)
                    end
                    if signal~=lastSceneSignal then
                        lastSceneSignal=signal
                        emit("NONFINAL","Main bypass signal: "..signal)
                    end
                end
            end
            lastPuzzleCount=solved
            lastLeverSolved=leverSolved
            finalEndingProtected=endingProtected()
            -- Direct port of Main's single-use, bounded noclip behavior.
            -- Only trigger for the puzzle-release cinematic, never intro or
            -- final ending. It alters collisions locally, not server position.
            local puzzleReleaseWindow=introDone and
                (release or (solved>=3 and
                    (cutscene or os.clock()<puzzleBypassUntil)))
            if puzzleReleaseWindow and not finalEndingProtected
                and not puzzleNoclipUsed then
                local char=player.Character
                local root=char and char:FindFirstChild("HumanoidRootPart")
                if root then beginPuzzleNoclip(root) end
            end
            if puzzleNoclipActive and (finalEndingProtected
                or (not release and not cutscene
                    and os.clock()>=puzzleBypassUntil)) then
                endPuzzleNoclip(finalEndingProtected
                    and "final ending protected" or "puzzle release ended")
            end
            if cutsceneBypassRefresh then
                cutsceneBypassRefresh()
            end
            local nonfinal=introDone and
                (cutscene or release or os.clock()<puzzleBypassUntil
                    or os.clock()<leverBypassUntil)
            if wasNonfinal~=nonfinal then
                emit("STATE","Main cinematic window="..tostring(nonfinal)..
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
]==========]
local __BEYY_CH2_CUTSCENE_V4_STARTED=false
local function startWorkingCutsceneV4()
    if __BEYY_CH2_CUTSCENE_V4_STARTED then return true end
    local fn,err=loadstring(__BEYY_CH2_CUTSCENE_V4_SOURCE)
    if type(fn)~="function" then
        warn("[CH2 COMBO] Embedded working cutscene v4 compile failed: "..tostring(err))
        return false
    end
    __BEYY_CH2_CUTSCENE_V4_STARTED=true
    task.spawn(function()
        local ok,why=pcall(fn)
        if not ok then
            __BEYY_CH2_CUTSCENE_V4_STARTED=false
            warn("[CH2 COMBO] Embedded working cutscene v4 runtime error: "..tostring(why))
        end
    end)
    print("[CH2 COMBO] Working v4 Main cutscene/noclip controller embedded and launched")
    return true
end
startWorkingCutsceneV4()


local started=os.clock()
print("[CH2 COMBO] v24 NO-LEVERS + CUTSCENE loaded: native intro Skip + non-final cutscene bypass + direct puzzles")
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
        "CHAPTER 2 NO-LEVERS + WORKING CUTSCENE v24",
        "Times relative to the test executing in Chapter 2.",
        "Actions: blackout removal, native intro Skip, three puzzles WITHOUT pulling levers, local non-final cinematic bypass.",
        "NO LEVERS MODE: "..tostring(SKIP_LEVERS_TEST).." (no LeverPuzzle actions sent by this test).",
        "No-levers worker + verified v4 Main cutscene/noclip controller.",
        "Embedded v4 controller launched: "..tostring(__BEYY_CH2_CUTSCENE_V4_STARTED),
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
    if not done or not root or (not SKIP_LEVERS_TEST and not threeLeversConfirmed()) then return end
    local now=os.clock()
    local release=player:GetAttribute("Chapter2ReleaseActive")==true
    local stage=(now<puzzleBypassUntil or release
        or (SKIP_LEVERS_TEST and puzzleStarted
            and player:GetAttribute("CutsceneActive")==true)) and "THREE PUZZLES"
        or (not SKIP_LEVERS_TEST and now<leverBypassUntil and "THREE LEVERS" or nil)
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
        " after intro Skip; playable camera and input, server timer unchanged; NO-LEVERS="..
        tostring(SKIP_LEVERS_TEST))
    restoreBypassInput()
    hideNonfinalCutsceneVisuals()
end

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
emit("BOOT","Combined v24 started: 0 lever requests + direct 3 puzzles + working Main-derived v4 cutscene/noclip.")
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
