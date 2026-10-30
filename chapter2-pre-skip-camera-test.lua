-- Beyy Chapter 2 Pre-Skip Free Camera Visual Test v1
-- STANDALONE, local-only: hide intro blackout and give a mouse-driven
-- camera while waiting for the native Skip. On Skip appearance, hand
-- camera and cursor back to Roblox so normal auto/manual Skip still works.
-- DOES NOT fire server remotes, change character state, or solve puzzles.
-- Queue from Lobby before starting Chapter 2.
local LOBBY=77108422251420
local CH2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-pre-skip-camera-test.lua"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local WS=game:GetService("Workspace")
local env=_G
if type(getgenv)=="function" then
    local ok,e=pcall(getgenv)
    if ok and type(e)=="table" then env=e end
end
if game.PlaceId==LOBBY then
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then
        warn("[CH2 CAMERA TEST] queue_on_teleport unavailable. Execute manually on map load.")
        return
    end
    local ok,body=pcall(function()
        return game:HttpGet(URL.."?preload="..tostring(os.time()).."-"..tostring(math.random(10000,99999)))
    end)
    local valid=ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Pre-Skip Free Camera Visual Test v1",1,true)
        and type(loadstring)=="function" and type(loadstring(body))=="function"
    local payload=valid and body or
        ('loadstring(game:HttpGet("'..URL..'?fallback="..tostring(os.time())))()')
    local armed,err=pcall(queue,payload)
    if armed then
        print("[CH2 CAMERA TEST] Preloaded camera experiment queued; enter Chapter 2.")
    else warn("[CH2 CAMERA TEST] Queue failed: "..tostring(err)) end
    return
end
if game.PlaceId~=CH2 then
    warn("[CH2 CAMERA TEST] Only Chapter 2 is supported.")
    return
end
if type(env.__BEYY_CH2_PRESKIP_CAMERA_STOP)=="function" then
    pcall(env.__BEYY_CH2_PRESKIP_CAMERA_STOP)
end

local started=os.clock()
local duration=35
local alive=true
local player
local cameraActive=false
local cameraReleased=false
local capturedCam
local origMouse
local yaw,pitch,distance
local black
local originalBlackVisible
local connections={}
local events={}
local first={}
local maxEvents=450
local path="BeyyHub/chapter2_pre_skip_camera_test.txt"
local renderName="BeyyCh2PreSkipCameraTest"
local currentSkip=false
local reportSaved=false
local function elapsed() return os.clock()-started end
local function log(kind,msg)
    local entry=string.format("+%.3fs [%s] %s",elapsed(),kind,tostring(msg))
    events[#events+1]=entry
    if #events>maxEvents then table.remove(events,1) end
    print("[CH2 CAMERA TEST] "..entry)
end
local function milestone(name,msg)
    if first[name]~=nil then return end
    first[name]=elapsed()
    log("FIRST",name..": "..tostring(msg or ""))
end
local function connect(signal,cb)
    local ok,conn=pcall(function()return signal:Connect(cb)end)
    if ok and conn then connections[#connections+1]=conn end
end
local function report()
    local out={"CHAPTER 2 PRE-SKIP FREE CAMERA TEST v1",
        "Only local blackout GUI and camera/mouse are modified; no gameplay remotes.",
        "Times relative to script start.",
        "=== MILESTONES ==="}
    for _,key in ipairs({"localPlayer","blackFound","blackHidden","cameraStarted",
        "cameraInputObserved","cameraMoved","skipAvailable","cameraReleased",
        "introFinished","userCameraWorksF6","userCameraNotWorkingF7"}) do
        out[#out+1]=key.." = "..(first[key] and string.format("+%.3fs",first[key])
            or "NOT OBSERVED")
    end
    out[#out+1]="=== EVENTS ==="
    out[#out+1]=table.concat(events,"\n")
    return table.concat(out,"\n")
end
local function save(copy)
    local text=report()
    if type(writefile)=="function" then
        if type(makefolder)=="function" then pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then makefolder("BeyyHub") end
        end) end
        local ok,err=pcall(writefile,path,text)
        if ok then print("[CH2 CAMERA TEST] Saved "..path)
        else warn("[CH2 CAMERA TEST] Save error: "..tostring(err)) end
    end
    if copy and type(setclipboard)=="function" then
        local ok,err=pcall(setclipboard,text)
        if ok then print("[CH2 CAMERA TEST] Copied report to clipboard")
        else warn("[CH2 CAMERA TEST] Clipboard failed: "..tostring(err)) end
    end
end
local function releaseCamera(reason)
    if cameraReleased then return end
    cameraReleased=true
    if cameraActive then
        local cam=WS.CurrentCamera
        if cam then
            local hum=player and player.Character
            hum=hum and hum:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function()cam.CameraSubject=hum end) end
            pcall(function()cam.CameraType=Enum.CameraType.Custom end)
        end
        pcall(function()UIS.MouseBehavior=Enum.MouseBehavior.Default end)
        cameraActive=false
    end
    milestone("cameraReleased",reason)
end
local function restoreOverlay()
    if black and black.Parent and originalBlackVisible~=nil then
        pcall(function()black.Visible=originalBlackVisible end)
    end
end
local function stop()
    if not alive then return end
    releaseCamera("test cleanup")
    restoreOverlay()
    alive=false
    pcall(function()RunService:UnbindFromRenderStep(renderName)end)
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
    save(false)
end
env.__BEYY_CH2_PRESKIP_CAMERA_STOP=stop
env.__BEYY_CH2_PRESKIP_CAMERA_COPY=function()save(true)end
env.__BEYY_CH2_PRESKIP_CAMERA_REPORT=report

local function visible(obj)
    local p=obj
    while p do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        if p:IsA("PlayerGui") then return true end
        p=p.Parent
    end
    return false
end
local function skipVisible(pg)
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local holder=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    local b=holder and holder:FindFirstChild("Button",true)
    return b and b:IsA("GuiButton") and visible(b) or false
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function initializeCamera(root)
    if cameraActive or cameraReleased then return end
    local cam=WS.CurrentCamera
    if not cam then return end
    local front=root.CFrame.LookVector
    local flat=Vector3.new(front.X,0,front.Z)
    if flat.Magnitude<0.1 then flat=Vector3.new(0,0,-1) end
    yaw=math.atan2(flat.X,flat.Z)
    pitch=-0.18
    distance=4
    capturedCam=cam
    origMouse=UIS.MouseBehavior
    cameraActive=true
    milestone("cameraStarted","manual mouse camera active, 4-stud follow; until native Skip")
end
local lastView
local lastDeltaReport=-math.huge
local function driveCamera()
    if not alive or not cameraActive or cameraReleased then return end
    local ch=player and player.Character
    local root=ch and ch:FindFirstChild("HumanoidRootPart")
    local cam=WS.CurrentCamera
    if not root or not cam then return end
    local hum=ch:FindFirstChildOfClass("Humanoid")
    pcall(function() UIS.MouseBehavior=Enum.MouseBehavior.LockCenter end)
    local ok,delta=pcall(function()return UIS:GetMouseDelta()end)
    if ok and delta and UIS:GetFocusedTextBox()==nil then
        if math.abs(delta.X)>0.1 or math.abs(delta.Y)>0.1 then
            milestone("cameraInputObserved","GetMouseDelta responds")
            if elapsed()-lastDeltaReport>1.5 then
                log("MOUSE","delta="..tostring(delta))
                lastDeltaReport=elapsed()
            end
            yaw=yaw-delta.X*0.004
            pitch=clamp(pitch-delta.Y*0.004,-1,0.85)
        end
    end
    local cp=math.cos(pitch)
    local dir=Vector3.new(math.sin(yaw)*cp,math.sin(pitch),math.cos(yaw)*cp)
    local target=root.Position+Vector3.new(0,1.6,0)
    local desired=target-dir*distance
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={ch}
    params.RespectCanCollide=true
    local ray=WS:Raycast(target,desired-target,params)
    if ray then
        local gap=(ray.Position-target).Magnitude
        desired=target-dir*math.max(0.45,gap-0.3)
    end
    cam.CameraType=Enum.CameraType.Scriptable
    if hum then cam.CameraSubject=hum end
    cam.CFrame=CFrame.lookAt(desired,target,Vector3.yAxis)
    cam.Focus=CFrame.new(target)
    local cf=cam.CFrame
    if lastView and math.abs(cf.LookVector:Dot(lastView.LookVector))<0.999 then
        milestone("cameraMoved","camera rotation changed")
    end
    lastView=cf
end
connect(UIS.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F6 then
        milestone("userCameraWorksF6","user confirms mouse rotates view")
    elseif input.KeyCode==Enum.KeyCode.F7 then
        milestone("userCameraNotWorkingF7","user reports mouse camera still locked")
    elseif input.KeyCode==Enum.KeyCode.F8 then save(true) end
end)
log("BOOT","F6=I can rotate camera, F7=still locked, F8=copy report. Do not run alongside previous camera test.")
pcall(function()RunService:UnbindFromRenderStep(renderName)end)
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+2100,driveCamera)

task.spawn(function()
    while alive and elapsed()<duration do
        local t=elapsed()
        if Players.LocalPlayer and not player then
            player=Players.LocalPlayer
            milestone("localPlayer","player present")
        end
        if player then
            local pg=player:FindFirstChildOfClass("PlayerGui")
            local fade=pg and pg:FindFirstChild("CutsceneFade")
            local candidate=fade and fade:FindFirstChild("Black",true)
            if candidate and candidate:IsA("GuiObject") and candidate~=black then
                black=candidate
                originalBlackVisible=black.Visible
                milestone("blackFound","CutsceneFade.Black exists")
            end
            local introDone=player:GetAttribute("IntroCutsceneFinished")==true
            if introDone then
                milestone("introFinished","IntroCutsceneFinished=true")
                releaseCamera("intro finished")
            end
            local shown=skipVisible(pg)
            if shown and not currentSkip then
                currentSkip=true
                milestone("skipAvailable","native Skip now visible")
                releaseCamera("native Skip visible; releasing cursor for click")
            end
            if black and not introDone and black.Visible then
                local ok,err=pcall(function()black.Visible=false end)
                if ok then milestone("blackHidden","CutsceneFade.Black suppressed")
                else log("WARN","Hide failed: "..tostring(err))end
            end
            if not cameraActive and not cameraReleased and
                player:GetAttribute("CutsceneActive")==true and not shown and not introDone then
                local ch=player.Character
                local root=ch and ch:FindFirstChild("HumanoidRootPart")
                if root then initializeCamera(root) end
            end
            if introDone and black and t> (first.introFinished or t)+0.6 then
                restoreOverlay()
            end
        end
        if t>=15 and not reportSaved then
            reportSaved=true
            save(false)
        end
        task.wait(t<18 and 0.035 or 0.12)
    end
    if alive then
        log("DONE","35s test completed")
        save(true)
        stop()
    end
end)
