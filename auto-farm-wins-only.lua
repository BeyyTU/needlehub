-- Beyy Auto Farm Wins ONLY (standalone, shareable)
-- Beyy Hybrid Replay recovery v1
-- Does NOT load the BeyyHub interface, other chapter modules, or configs.
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
local modeFile="BeyyHub/standalone_mode.txt"
local mode="Wins"
do
    local stored=env.__BEYY_STANDALONE_MODE
    if type(readfile)=="function" then
        local ok,value=pcall(readfile,modeFile)
        if ok and (value=="Wins" or value=="Hay" or value=="Off") then stored=value end
    end
    if stored=="Wins" or stored=="Hay" or stored=="Off" then mode=stored end
end
local enabled=mode~="Off"
local menuOpen=false
local modeEpoch=0
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
local Unloaded=false
local needlePickupActive=false
local autoUiMouseBusy=false
local needleStop=nil
local function needlePriority() return false end
local function needleLocked() return needlePriority() or needlePickupActive end
local statusGui=nil
local uiDispose=nil
local function createStatus()
    local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",12)
    if not pg then return end
    local stale=pg:FindFirstChild("BeyyAutoWinsOnlyStatus")
    if stale then stale:Destroy() end
    local ui=Instance.new("ScreenGui")
    ui.Name="BeyyAutoWinsOnlyStatus"
    ui.ResetOnSpawn=false
    ui.IgnoreGuiInset=true
    ui.DisplayOrder=800
    local text=Instance.new("TextLabel")
    text.Name="Status"
    text.AnchorPoint=Vector2.new(0.5,0)
    text.Position=UDim2.new(0.5,0,0,12)
    text.Size=UDim2.fromOffset(248,32)
    text.BackgroundColor3=Color3.fromRGB(18,26,25)
    text.BackgroundTransparency=0.12
    text.BorderSizePixel=0
    text.TextColor3=Color3.fromRGB(154,249,193)
    text.Font=Enum.Font.GothamSemibold
    text.TextSize=13
    text.Text="AUTO FARM "..(mode=="Hay" and "HAY" or "WINS").."  •  "..(enabled and "ACTIVE" or "PAUSED")
    text.Parent=ui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=text
    ui.Parent=pg
    statusGui=ui
end
createStatus()
local function log(message) print("[Beyy Auto Wins] "..tostring(message)) end
local function getRoot()
    local character=player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function on()
    return alive and enabled and not menuOpen
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
    Unloaded=true
    if needleStop then pcall(needleStop) end
    releaseMouse()
    restoreCamera()
    if uiDispose then pcall(uiDispose);uiDispose=nil end
    if statusGui and statusGui.Parent then statusGui:Destroy() end
    for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end) end
    table.clear(connections)
    log("Stopped; mouse released and camera restored.")
end
local api={}
local tntTiming={LightCooldown=0,ThrowDelay=0.5}
api.TntTiming=tntTiming
function api.Stop() stop() end
function api.IsEnabled() return on() end
function api.GetRounds() return rounds end
env.BeyyAutoFarmWinsOnly=api
local function setMode(nextMode)
    if not alive or (nextMode~="Wins" and nextMode~="Hay" and nextMode~="Off") or mode==nextMode then return end
    mode=nextMode
    enabled=mode~="Off"
    modeEpoch+=1
    env.__BEYY_STANDALONE_MODE=mode
    if type(writefile)=="function" then pcall(function()
        if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder("BeyyHub")) then makefolder("BeyyHub") end
        writefile(modeFile,mode)
    end) end
    releaseMouse()
    restoreCamera()
    local status=statusGui and statusGui:FindFirstChild("Status")
    if status then status.Text="AUTO FARM "..(mode=="Hay" and "HAY" or "WINS").."  •  "..(enabled and "ACTIVE" or "PAUSED") end
    log("Mode changed: "..mode)
end
api.GetMode=function() return mode end
api.SetMode=setMode
env.__BEYY_STANDALONE_MODE=mode
local function makeStandaloneUI()
    local input=game:GetService("UserInputService")
    local pg=player:WaitForChild("PlayerGui",12)
    if not pg then return end
    local parent=pg
    if type(gethui)=="function" then local ok,h=pcall(gethui);if ok and h then parent=h end end
    local previous=parent:FindFirstChild("BeyyStandaloneNativeUI")
    if previous then previous:Destroy() end
    local colors={bg=Color3.fromRGB(20,22,27),row=Color3.fromRGB(32,35,42),
        text=Color3.fromRGB(231,234,240),accent=Color3.fromRGB(58,104,153)}
    local function node(class,root,props)
        local obj=Instance.new(class)
        for k,v in pairs(props or {}) do obj[k]=v end
        obj.Parent=root
        return obj
    end
    local gui=node("ScreenGui",parent,{Name="BeyyStandaloneNativeUI",ResetOnSpawn=false,
        DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    local root=node("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(560,300),BackgroundColor3=colors.bg,BorderSizePixel=0,Visible=false})
    node("UICorner",root,{CornerRadius=UDim.new(0,8)})
    local scale=node("UIScale",root,{Scale=1})
    local hooks={}
    local function connect(signal,fn)
        hooks[#hooks+1]=signal:Connect(fn)
    end
    local function fit()
        local viewport=gui.AbsoluteSize
        scale.Scale=math.min(1,math.max(.25,(viewport.X-12)/560),math.max(.25,(viewport.Y-12)/300))
    end
    connect(gui:GetPropertyChangedSignal("AbsoluteSize"),fit)
    fit()
    local function label(t,pos,size,fontSize)
        return node("TextLabel",root,{Text=t,Position=pos,Size=size,BackgroundTransparency=1,
            TextColor3=colors.text,TextSize=fontSize or 16,Font=Enum.Font.SourceSans,
            TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
    end
    local function button(t,pos,size)
        return node("TextButton",root,{Text=t,Position=pos,Size=size,
            BackgroundColor3=colors.row,BorderSizePixel=0,AutoButtonColor=false,
            TextColor3=colors.text,TextSize=15,Font=Enum.Font.SourceSans})
    end
    label(" Beyy Hub Standalone ",UDim2.fromOffset(12,4),UDim2.new(1,-55,0,32),21)
    local close=button("X",UDim2.new(1,-38,0,7),UDim2.fromOffset(28,25))
    local tab=button("Farming",UDim2.fromOffset(8,42),UDim2.fromOffset(145,34))
    tab.BackgroundColor3=colors.accent
    label("Farming Mode",UDim2.fromOffset(172,45),UDim2.new(1,-180,0,28),20)
    label("Auto Farm Wins",UDim2.fromOffset(174,86),UDim2.fromOffset(190,32))
    local wins=button("",UDim2.fromOffset(424,87),UDim2.fromOffset(100,28))
    label("Auto Farm Hay",UDim2.fromOffset(174,128),UDim2.fromOffset(190,32))
    local hay=button("",UDim2.fromOffset(424,129),UDim2.fromOffset(100,28))
    local desc=label("",UDim2.fromOffset(174,168),UDim2.new(1,-185,0,65),14)
    label("RightControl to show / hide",UDim2.fromOffset(174,252),UDim2.new(1,-185,0,30),13)
    local function refresh()
        wins.Text=mode=="Wins" and "ON" or "OFF"
        hay.Text=mode=="Hay" and "ON" or "OFF"
        wins.BackgroundColor3=mode=="Wins" and colors.accent or colors.row
        hay.BackgroundColor3=mode=="Hay" and colors.accent or colors.row
        desc.Text=mode=="Hay" and "Impossible: clear hay, upgrade tools, finish needle, Replay."
            or mode=="Wins" and "Normal: original fast win farming and in-match Replay."
            or "Both farming modes paused. Choose a mode to resume."
    end
    connect(wins.Activated,function()setMode(mode=="Wins" and "Off" or "Wins");refresh()end)
    connect(hay.Activated,function()setMode(mode=="Hay" and "Off" or "Hay");refresh()end)
    local cursorBound=false
    local cursorName="BeyyStandaloneCursor_"..player.UserId
    local previousBehavior,previousIcon
    local function cursor(visible)
        if visible and not cursorBound then
            previousBehavior,previousIcon=input.MouseBehavior,input.MouseIconEnabled
            cursorBound=true
            RunService:BindToRenderStep(cursorName,Enum.RenderPriority.Last.Value+100,function()
                input.MouseBehavior=Enum.MouseBehavior.Default;input.MouseIconEnabled=true
            end)
        elseif not visible and cursorBound then
            RunService:UnbindFromRenderStep(cursorName)
            cursorBound=false
            input.MouseBehavior=previousBehavior;input.MouseIconEnabled=previousIcon
        end
    end
    local function open(visible)
        menuOpen=visible
        root.Visible=visible
        if visible then releaseMouse();restoreCamera();refresh() end
        cursor(visible)
    end
    connect(close.Activated,function()open(false)end)
    connect(input.InputBegan,function(event,processed)
        if not processed and not input:GetFocusedTextBox() and event.KeyCode==Enum.KeyCode.RightControl then open(not menuOpen) end
    end)
    local dragStart,oldPosition
    connect(root.InputBegan,function(event)
        if event.UserInputType==Enum.UserInputType.MouseButton1 then dragStart,oldPosition=event.Position,root.Position end
    end)
    connect(input.InputChanged,function(event)
        if dragStart and event.UserInputType==Enum.UserInputType.MouseMovement then
            local d=event.Position-dragStart
            root.Position=UDim2.new(oldPosition.X.Scale,oldPosition.X.Offset+d.X,oldPosition.Y.Scale,oldPosition.Y.Offset+d.Y)
        end
    end)
    connect(input.InputEnded,function(event)
        if event.UserInputType==Enum.UserInputType.MouseButton1 then dragStart=nil end
    end)
    refresh()
    uiDispose=function()
        cursor(false)
        for _,c in ipairs(hooks) do pcall(function()c:Disconnect()end) end
        gui:Destroy()
    end
end
local uiOK,uiError=pcall(makeStandaloneUI)
if not uiOK then warn("[Beyy Standalone] Native UI error: "..tostring(uiError)) end
do
    local virtualUser = game:GetService("VirtualUser")
    local beyyAntiAfkConnection = player.Idled:Connect(function()
        if not on() then return end
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
    connections[#connections+1] = beyyAntiAfkConnection
end


-- Queue only this standalone file, with a validated offline continuation.
local replayReload=(function()
    local queue=type(queue_on_teleport)=="function" and queue_on_teleport or nil
    for _,name in ipairs({"queue_on_teleport","queueonteleport","queue_on_tp"}) do
        local value=rawget(env,name) or rawget(_G,name)
        if type(value)=="function" then queue=value;break end
    end
    if not queue and type(syn)=="table" and type(syn.queue_on_teleport)=="function" then queue=syn.queue_on_teleport end
    local armed=false
    local cache="BeyyHub/afk_replay_standalone_v103.lua"
    local function valid(value)
        return type(value)=="string" and value:find("Beyy Hybrid Replay recovery v1",1,true)
            and value:find("Beyy Auto Farm Wins ONLY",1,true) and loadstring(value)
    end
    local payload=[====[
        local cache="BeyyHub/afk_replay_standalone_v103.lua"
        local function valid(value)
            return type(value)=="string" and value:find("Beyy Hybrid Replay recovery v1",1,true)
                and value:find("Beyy Auto Farm Wins ONLY",1,true) and loadstring(value)
        end
        local revision
        local resolved,info=pcall(function()
            return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://api.github.com/repos/BeyyTU/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
        end)
        if resolved and type(info)=="table" and type(info.sha)=="string" and #info.sha==40 and info.sha:match("^%x+$") then revision=info.sha end
        local url="https://raw.githubusercontent.com/BeyyTU/needlehub/"..(revision or "main").."/auto-farm-wins-only.lua"
        local body
        for attempt=1,3 do
            local ok,value=pcall(function()
                return game:HttpGet(url.."?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000)))
            end)
            if ok and valid(value) then body=value;break end
            if attempt<3 then task.wait(attempt*0.5) end
        end
        if not body and type(readfile)=="function" then
            local ok,value=pcall(readfile,cache)
            if ok and valid(value) then body=value end
        end
        if not body then warn("[Beyy Auto Wins] No validated online or cached standalone after teleport");return end
        if type(writefile)=="function" then pcall(writefile,cache,body) end
        local fn=loadstring(body)
        local ok,err=pcall(fn)
        if not ok then warn("[Beyy Auto Wins] Standalone reload failed: "..tostring(err)) end
    ]====]
    -- Test-branch-only continuation; production keeps its current main-branch reload.
    if env.__BEYY_AF_WINS_TEST_BRANCH=="test/sceneton-auto-farm-wins-port" then
        local sourceRef=env.__BEYY_AF_WINS_TEST_BRANCH
        local sourceUrl="https://raw.githubusercontent.com/BeyyTU/needlehub/"..sourceRef.."/auto-farm-wins-only.lua"
        payload=string.format([==[
            local env=(type(getgenv)=="function" and getgenv()) or _G
            env.__BEYY_AF_WINS_TEST_BRANCH=%q
            local url=%q
            local body
            for attempt=1,3 do
                local ok,source=pcall(function()
                    return game:HttpGet(url.."?refresh="..tostring(os.time()))
                end)
                if ok and type(source)=="string"
                    and source:find("Beyy Auto Farm Wins ONLY",1,true)
                    and source:find("Beyy Hybrid Replay recovery v1",1,true)
                    and loadstring(source) then body=source;break end
                task.wait(0.5)
            end
            if not body then warn("[AFK Test] Could not reload standalone branch");return end
            local fn=loadstring(body)
            local ok,err=pcall(fn)
            if not ok then warn("[AFK Test] Standalone crashed: "..tostring(err)) end
        ]==],sourceRef,sourceUrl)
    end
    local function arm()
        if armed or _G.__BEYY_STANDALONE_RELOAD_JOB==game.JobId then armed=true;return true end
        if not on() then return false,"standalone is stopped" end
        if not queue then return false,"queue_on_teleport is unavailable" end
        local cached
        if type(readfile)=="function" then local ok,value=pcall(readfile,cache);if ok then cached=value end end
        if not valid(cached) and type(writefile)=="function" then
            local revision
            local resolved,info=pcall(function()
                return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://api.github.com/repos/BeyyTU/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
            end)
            if resolved and type(info)=="table" and type(info.sha)=="string" and #info.sha==40 and info.sha:match("^%x+$") then revision=info.sha end
            local url="https://raw.githubusercontent.com/BeyyTU/needlehub/"..(revision or "main").."/auto-farm-wins-only.lua"
            local ok,value=pcall(function()
                return game:HttpGet(url.."?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000)))
            end)
            if ok and valid(value) then
                pcall(function()
                    if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder("BeyyHub")) then makefolder("BeyyHub") end
                    writefile(cache,value)
                end)
            end
        end
        if not on() then return false,"standalone was stopped during reload preparation" end
        local ok,err=pcall(queue,payload)
        armed=ok
        if ok then _G.__BEYY_STANDALONE_RELOAD_JOB=game.JobId end
        if ok then log("Standalone online/cached reload armed for the next teleport")
        else warn("[Beyy Auto Wins] Teleport queue failed: "..tostring(err)) end
        return ok,tostring(err)
    end
    arm()
    connections[#connections+1]=player.OnTeleport:Connect(function(value)
        if on() and value==Enum.TeleportState.Started then arm() end
    end)
    return {Ensure=arm}
end)()

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
    if not on() or needleLocked() or autoUiMouseBusy or not guiVisible(obj)
        or not obj:IsA("GuiObject") then return false end
    autoUiMouseBusy=true
    local p,s=obj.AbsolutePosition,obj.AbsoluteSize
    if s.X<=0 or s.Y<=0 then autoUiMouseBusy=false;return false end
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
    autoUiMouseBusy=false
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
    log("Lobby: selected-mode one-player round creation enabled.")
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
        local wanted=mode=="Hay" and "ImpossibleMode" or "NormalMode"
        local target=select and select:FindFirstChild(wanted)
        if not target and mode=="Hay" and select then
            for _,obj in ipairs(select:GetDescendants()) do
                if obj:IsA("GuiButton") and
                    (obj.Name:lower():find("impossible",1,true)
                    or (obj:IsA("TextButton") and obj.Text:lower():find("impossible",1,true))) then
                    target=obj
                    break
                end
            end
        end
        if not target or not click(target) then
            log("Cannot choose "..wanted.." in party UI; refusing wrong difficulty")
            return false
        end
        task.wait(0.12)
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
    while alive and game.PlaceId==LOBBY do
        task.wait(0.5)
        if not alive then break end
            if not on() then continue end
        if not busy then
            busy=true
            local ok,err=pcall(function()
                for _,entry in ipairs(getCircles()) do
                    if not alive then break end
            if not on() then continue end
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

-- Farmhouse: sceneton eight-route 48-degree/s orbit with half-time highest ring.
local impossibleCleared=false
local impossible={
    plan=nil,building=false,ring=1,sweep=0,angle=0,lastAt=0,
    remaining=nil,revision=nil,zeroChecks=0,roundSerial=0,
    lastQuery=0,queryPending=false,observed=false
}
local IMPOSSIBLE_FRACTIONS={0.04,0.13,0.22,0.31,0.40,0.49,0.58,0.67,0.76,0.85,0.93,0.99}
local function resetImpossible()
    impossibleCleared=false
    impossible.plan=nil
    impossible.building=false
    impossible.ring=1
    impossible.sweep=0
    impossible.angle=0
    impossible.lastAt=0
    impossible.remaining=nil
    impossible.revision=nil
    impossible.zeroChecks=0
    impossible.roundSerial+=1
    impossible.lastQuery=0
    impossible.queryPending=false
    impossible.observed=false
end
local BANDS={
    { name = "base", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = 3.0 },
    { name = "base-transition", radius = 20.0, standoff = 2.1, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = 2.0 },
    { name = "lower-middle", radius = 18.0, standoff = 2.0, characterInset = 1.5, cameraLift = 5.0, focusYOffset = -0.1 },
    { name = "middle-transition", radius = 16.0, standoff = 1.95, characterInset = 1.5, cameraLift = 5.1, focusYOffset = -0.8 },
    { name = "upper-middle", radius = 14.0, standoff = 1.9, characterInset = 1.5, cameraLift = 5.2, focusYOffset = -1.5 },
    { name = "upper-transition", radius = 11.0, standoff = 1.8, characterInset = 1.0, cameraLift = 5.6, focusYOffset = -0.75 },
    { name = "peak", radius = 8.0, standoff = 1.7, cameraLift = 6.0, focusYOffset = 0.0 },
    { name = "inner-peak", radius = 5.0, standoff = 1.6, cameraLift = 6.0, focusYOffset = 0.2 },
}
local orbit={
    axis=nil,center=nil,angle=0,lap=0,progress=0,surface=nil,
    surfaces=nil,top=nil,radius=nil,lift=nil,focus=nil,
    ready=false,targetReady=false,replay=true,startedAt=os.clock(),
    candidate=nil,candidateCount=0,candidateStable=0,candidateSource=nil,
    lastSample=0,lastHayScan=0,lastSurfaceSample=0,
    scanBusy=false,scanGeneration=0,lastAdvanceAt=os.clock(),
    calibrationUntil=0,prevCount=0,prevSpan=0,lastCorrectionAt=0,
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
local physicalPileConfigChecked=false
local physicalPileConfiguredCenter=nil
local function physicalPileCenter()
    if not physicalPileConfigChecked then
        local needle=game:GetService("ReplicatedStorage"):FindFirstChild("NeedleHaystack")
        local module=needle and needle:FindFirstChild("Config")
        if module and module:IsA("ModuleScript") then
            physicalPileConfigChecked=true
            local ok,config=pcall(require,module)
            if ok and type(config)=="table" and typeof(config.PILE_CENTER)=="Vector3" then
                physicalPileConfiguredCenter=config.PILE_CENTER
            end
        end
    end
    if physicalPileConfiguredCenter then
        return physicalPileConfiguredCenter,1000000,"game-config"
    end
    for _,candidate in ipairs({
        {name="HayUnderMatClient",minimum=10000,isHay=false},
        {name="HaystackClient",minimum=12000,isHay=true},
    }) do
        local folder=Workspace:FindFirstChild(candidate.name)
        local children=folder and folder:GetChildren()
        if children and #children>=candidate.minimum then
            local xs,zs={},{}
            for _,part in ipairs(children) do
                if part:IsA("BasePart") and (not candidate.isHay or pileHay(part)) then
                    local p=part.Position
                    xs[#xs+1]=p.X
                    zs[#zs+1]=p.Z
                end
            end
            if #xs>=candidate.minimum then
                table.sort(xs)
                table.sort(zs)
                local lo=math.max(1,math.ceil(#xs*0.01))
                local hi=math.min(#xs,math.floor(#xs*0.99))
                return Vector3.new((xs[lo]+xs[hi])*0.5,0,(zs[lo]+zs[hi])*0.5),#xs,candidate.name
            end
        end
    end
    return nil,0,"waiting-for-full-pile"
end

local function computeSurfaces(center)
    local needle=game:GetService("ReplicatedStorage"):FindFirstChild("NeedleHaystack")
    local configModule=needle and needle:FindFirstChild("Config")
    local config
    if configModule and configModule:IsA("ModuleScript") then
        local ok,value=pcall(require,configModule)
        if ok and type(value)=="table" then config=value end
    end
    if config and typeof(config.PILE_CENTER)=="Vector3"
        and tonumber(config.PILE_HEIGHT) and tonumber(config.PILE_HEIGHT)>0 then
        local floorY=config.PILE_CENTER.Y+(tonumber(config.PILE_BASE_Y) or 0)
        local height=tonumber(config.PILE_HEIGHT)
        local fractions={0.12,0.24,0.36,0.495,0.63,0.755,0.88,0.97}
        local heights,labels={},{}
        for i,band in ipairs(BANDS) do
            heights[i]=floorY+height*fractions[i]+(band.heightOffset or 0)
            labels[i]=string.format("%s=%.1f",band.name,heights[i])
        end
        heights[1]=heights[2]
        labels[1]=string.format("%s=%.1f",BANDS[1].name,heights[1])
        log("Configured sceneton eight-route heights: "..table.concat(labels," "))
        return heights,floorY+height
    end
    local folder=hayFolder()
    local samples={}
    for i=1,#BANDS do samples[i]={} end
    local low,high=math.huge,-math.huge
    if folder then
        for _,part in ipairs(folder:GetChildren()) do
            if pileHay(part) then
                local p=part.Position
                local top=p.Y+part.Size.Y*0.5
                low=math.min(low,p.Y-part.Size.Y*0.5)
                high=math.max(high,top)
                local dx,dz=p.X-center.X,p.Z-center.Z
                local radius=math.sqrt(dx*dx+dz*dz)
                for i,band in ipairs(BANDS) do
                    if math.abs(radius-band.radius)<=5.5 then
                        local radialTops=samples[i]
                        radialTops[#radialTops+1]=top
                    end
                end
            end
        end
    end
    if low==math.huge then low=center.Y-4 end
    if high==-math.huge then high=center.Y+8 end
    local fractions={0.12,0.24,0.36,0.495,0.63,0.755,0.88,0.97}
    local heights={}
    for i,atRadius in ipairs(samples) do
        local baseline=low+(high-low)*fractions[i]
        if #atRadius>=6 then
            table.sort(atRadius)
            heights[i]=math.clamp(atRadius[math.max(1,math.ceil(#atRadius*0.90))],low,high)
        else
            heights[i]=baseline
        end
        if i>1 then heights[i]=math.max(heights[i],heights[i-1]) end
    end
    for i,band in ipairs(BANDS) do heights[i]+=band.heightOffset or 0 end
    heights[1]=heights[2]
    local labels={}
    for i,band in ipairs(BANDS) do labels[i]=string.format("%s=%.1f",band.name,heights[i]) end
    log("Sceneton eight-route heights: "..table.concat(labels," "))
    return heights,high
end

local function resetRound(reason)
    releaseMouse()
    restoreCamera()
    orbit.center=nil
    orbit.angle,orbit.lap,orbit.progress=0,0,0
    orbit.lastAdvanceAt=os.clock()
    orbit.ready,orbit.targetReady=false,false
    orbit.replay=true
    orbit.startedAt=os.clock()
    orbit.candidate,orbit.candidateCount,orbit.candidateStable,orbit.candidateSource=nil,0,0,nil
    orbit.lastSample=0
    orbit.lastHayScan=0
    orbit.scanGeneration+=1
    orbit.targetReady=false
    orbit.lastSurfaceSample=0
    orbit.surfaces=nil
    orbit.surface=nil
    orbit.prevCount,orbit.prevSpan,orbit.lastCorrectionAt=0,0,0
    orbit.calibrationUntil=0
    resetImpossible()
    log("Round reset: "..tostring(reason).." (fixed pile X/Z retained)")
    task.delay(3,function()
        if not on() then return end
        log("Replay orbit check: ending="..tostring(endingVisible())..
            " needle="..tostring(needleLocked())..
            " hay="..tostring(select(2,pileCenter()))..
            " ready="..tostring(orbit.ready)..
            " camera="..tostring(cameraBound))
    end)
end
local function calibrate()
    -- Match Chapter 1 AFK camera: CutsceneActive/NeedleInputLocked alone do
    -- not suppress the camera orbit after Replay.
    if not on() or endingVisible() or needleLocked() then return end
    local now=os.clock()
    if now-orbit.lastSample<0.45 then return end
    orbit.lastSample=now
    local live,liveCount,liveSpan=pileCenter()
    local point,count,span,source
    if orbit.axis then
        if live and liveCount>=25 then
            point=Vector3.new(orbit.axis.X,live.Y,orbit.axis.Z)
            count,span,source=liveCount,liveSpan,"pinned-replay"
        end
    else
        local physical,seen,kind=physicalPileCenter()
        if physical and live then
            point=Vector3.new(physical.X,live.Y,physical.Z)
            count,span,source=seen,liveSpan,kind
        end
    end
    if not point or count<25 then
        orbit.candidate=nil
        orbit.candidateSource=nil
        orbit.candidateStable=0
        return
    end
    local valid=true
    if orbit.candidate then
        local prev=orbit.candidate
        local shift=Vector3.new(point.X-prev.X,0,point.Z-prev.Z).Magnitude
        local populationChange=math.abs(count-orbit.candidateCount)/
            math.max(1,orbit.candidateCount)
        valid=source==orbit.candidateSource and shift<=0.75 and populationChange<=0.30
    end
    orbit.candidateStable=valid and orbit.candidateStable+1 or 1
    orbit.candidate,orbit.candidateCount,orbit.candidateSource=point,count,source
    if orbit.candidateStable<2 then return end
    if not orbit.axis then
        orbit.axis=Vector3.new(point.X,point.Y,point.Z)
    end
    orbit.center=Vector3.new(orbit.axis.X,point.Y,orbit.axis.Z)
    orbit.surfaces,orbit.top=computeSurfaces(orbit.center)
    local band=BANDS[1]
    orbit.radius=band.radius+band.standoff
    orbit.lift=band.cameraLift
    orbit.focus=band.focusYOffset
    orbit.surface=orbit.surfaces[1]
    orbit.ready,orbit.replay=true,false
    orbit.lastAdvanceAt=os.clock()
    orbit.prevCount=count
    orbit.prevSpan=span
    orbit.lastCorrectionAt=now
    orbit.lastSurfaceSample=now
    orbit.calibrationUntil=now+16
    log(string.format("Physical pile center confirmed: %s parts=%s axis=(%.2f,%.2f); fixed eight rings ready",
        tostring(source),tostring(count),orbit.axis.X,orbit.axis.Z))
end
local function canAdvanceScenetonRoute()
    if not orbit.ready or not orbit.center or not orbit.radius or not orbit.surface then return false end
    local root=getRoot()
    if not root then return false end
    local band=BANDS[(orbit.lap%#BANDS)+1]
    local radius=orbit.radius-(band.characterInset or 0)
    local wanted=Vector3.new(orbit.center.X+math.cos(orbit.angle)*radius,
        orbit.surface+3.25,orbit.center.Z+math.sin(orbit.angle)*radius)
    return (root.Position-wanted).Magnitude<=3
end
local function resetOrbitToBase()
    local base=BANDS[1]
    orbit.radius=base.radius+base.standoff
    orbit.surface=(orbit.surfaces and orbit.surfaces[1]) or orbit.top or orbit.center.Y
    orbit.lift=base.cameraLift
    orbit.focus=base.focusYOffset
    orbit.targetReady=false
end
local function bindCamera()
    if cameraBound or not orbit.ready then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    cameraPrevious, cameraType, cameraSubject, cameraFrame=
        cam,cam.CameraType,cam.CameraSubject,cam.CFrame
    local ok,err=pcall(function()
        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+10,function(dt)
            if not on() or not orbit.ready or endingVisible()
                or needleLocked() then return end
            local camera=Workspace.CurrentCamera
            local center=orbit.center
            if not camera or not center then return end
            dt=math.clamp(dt,0,0.25)
            local now=os.clock()
            local advance=canAdvanceScenetonRoute()
            if advance then
                orbit.lastAdvanceAt=now
            elseif orbit.lap%#BANDS>=#BANDS-2 and now-orbit.lastAdvanceAt>=6 then
                orbit.lap+=#BANDS-(orbit.lap%#BANDS)
                orbit.progress=0
                orbit.lastAdvanceAt=now
                resetOrbitToBase()
                log("Upper route stalled for 6s; returning to base")
            end
            local speed=(orbit.lap%#BANDS==#BANDS-1) and 96 or 48
            local travel=math.rad(speed)*(advance and dt or 0)
            local progress=orbit.progress+travel
            local theta=orbit.angle+travel
            if progress>=math.pi*2 then
                orbit.lap+=1
                if orbit.lap%#BANDS==0 then
                    resetOrbitToBase()
                end
            end
            orbit.progress=progress%(math.pi*2)
            orbit.angle=theta%(math.pi*2)
            local index=(orbit.lap%#BANDS)+1
            local band=BANDS[index]
            local k=1-math.exp(-3*dt)
            local r=band.radius+band.standoff
            orbit.radius+=(r-orbit.radius)*k
            local y=(orbit.surfaces and orbit.surfaces[index]) or orbit.top or center.Y
            orbit.surface+=(y-orbit.surface)*k
            orbit.lift=band.cameraLift
            orbit.focus+=(band.focusYOffset-orbit.focus)*k
            local radial=Vector3.new(math.cos(orbit.angle),0,math.sin(orbit.angle))
            local cpos=Vector3.new(center.X+radial.X*(orbit.radius+0.6),
                orbit.surface+orbit.lift,
                center.Z+radial.Z*(orbit.radius+0.6))
            local look=Vector3.new(center.X+radial.X*math.max(0,orbit.radius-5),
                orbit.surface+orbit.focus,
                center.Z+radial.Z*math.max(0,orbit.radius-5))
            camera.CameraType=Enum.CameraType.Scriptable
            camera.CFrame=CFrame.lookAt(cpos,look,Vector3.yAxis)
        end)
    end)
    if ok then cameraBound=true;log("Sceneton eight-route orbit active (48 deg/s, final route 96 deg/s, 22/20/18/16/14/11/8/5 rings)")
    else warn("[Beyy Auto Wins] Camera bind failed: "..tostring(err)) end
end
local function followAndProbe()
    if not on() or not orbit.ready or endingVisible() or needleLocked() then
        orbit.targetReady=false
        return
    end
    local char=player.Character
    local root=getRoot()
    local c=orbit.center
    if not char or not root or not c then return end
    local radial=Vector3.new(math.cos(orbit.angle),0,math.sin(orbit.angle))
    local radius=orbit.radius-(BANDS[(orbit.lap%#BANDS)+1].characterInset or 0)
    local dest=Vector3.new(c.X+radial.X*radius,orbit.surface+3.25,
        c.Z+radial.Z*radius)
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
    if not orbit.scanBusy and now-orbit.lastHayScan>=0.45 then
        orbit.lastHayScan=now
        orbit.scanBusy=true
        local index=(orbit.lap%#BANDS)+1
        local band=BANDS[index]
        local angle=orbit.angle
        local center=c
        local surface=orbit.surface
        local generation=orbit.scanGeneration or 0
        task.spawn(function()
            local nearby=false
            local ok,err=pcall(function()
                local folder=hayFolder()
                if not folder then return end
                local probe=center+Vector3.new(math.cos(angle),0,math.sin(angle))*band.radius
                local slice=os.clock()
                local checked=0
                for _,part in ipairs(folder:GetChildren()) do
                    checked+=1
                    if part.Parent==folder and part:IsA("BasePart") then
                        local position=part.Position
                        local dx,dz=position.X-probe.X,position.Z-probe.Z
                        if dx*dx+dz*dz<=144 and math.abs(position.Y-surface)<=12 and pileHay(part) then
                            nearby=true
                            break
                        end
                    end
                    if checked%64==0 and os.clock()-slice>=0.001 then
                        task.wait()
                        slice=os.clock()
                        if not on() or orbit.scanGeneration~=generation or orbit.center~=center
                            or BANDS[(orbit.lap%#BANDS)+1]~=band or endingVisible()
                            or needleLocked() then return end
                    end
                end
                if on() and orbit.scanGeneration==generation and orbit.center==center
                    and BANDS[(orbit.lap%#BANDS)+1]==band and not endingVisible()
                    and not needleLocked() then
                    orbit.targetReady=nearby
                end
            end)
            orbit.scanBusy=false
            if not ok then warn("[Beyy Auto Wins] Hay scan error: "..tostring(err)) end
        end)
    end
end
local function heat()
    local raw=tonumber(player:GetAttribute("VacuumHeat"))
    if raw and raw==raw and raw>=0 and raw<=1 then return raw end
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
-- Farmhouse-only win workers. Fixed presets; no controls or config files.
-- The needle pickup algorithm below is sourced from the working main Chapter 1.
local function installFarmhouseWinWorkers()
    local RS=game:GetService("ReplicatedStorage")
    local folder=RS:FindFirstChild("NeedleHaystack") or RS:WaitForChild("NeedleHaystack",30)
    if not folder or not on() then
        warn("[Beyy Auto Wins] NeedleHaystack remotes unavailable")
        return
    end
    local function remote(name)
        -- The main Chapter 1 waits for each remote to replicate.
        -- A plain FindFirstChild here could permanently disable the tool
        -- or hand-in worker when the standalone starts too early.
        local obj=folder:FindFirstChild(name)
            or folder:WaitForChild(name,12)
        if obj and obj:IsA("RemoteEvent") then return obj end
        warn("[Beyy Auto Wins] Missing remote: "..name)
        return nil
    end
    local PickHay=remote("PickHay")
    local PickDroppedHay=remote("PickDroppedHay")
    local SellHay=remote("SellHay")
    local PitchforkDig=remote("PitchforkDig")
    local TntAction=remote("TntAction")
    local DeployDrone=remote("DeployDrone")
    local NeedleHandIn=remote("NeedleHandIn")
    local BuyShopItem=remote("BuyShopItem")
    local BuyUpgrade=remote("BuyUpgrade")
    local LocalPlayer=player
    local IN_GAME=true
    local State={AutoPickupNeedle=true,AutoHandInNeedle=true,AutoFarmWins=true}
    local function afkFarmModeActive()return on()end
    local function roundEndingVisible()return endingVisible()end
    local function getHRP()return getRoot()end
    local function enterNeedleCamera()
        releaseMouse()
        restoreCamera()
    end
    local function findExposedNeedlePart()
        local server=Workspace:FindFirstChild("NeedleObjectiveServer")
        local partFolder=server and server:FindFirstChild("Needle")
        if not partFolder then return nil end
        for _,part in ipairs(partFolder:GetDescendants()) do
            if part:IsA("BasePart")
                and part:GetAttribute("IsNeedleObjective")==true
                and (part:GetAttribute("HIDDEN_WITHIN")==nil
                    or part:GetAttribute("HIDDEN_WITHIN")==false) then
                return part
            end
        end
        return nil
    end
    needlePriority=function()
        if not on() or endingVisible() then return false end
        if mode=="Hay" and not impossibleCleared then return false end
        if needlePickupActive then return true end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then return true end
        return findExposedNeedlePart()~=nil
    end
    local function own(attr)
        return LocalPlayer:GetAttribute(attr)==true
    end
    local function closestHay()
        local folder=hayFolder()
        local root=getRoot()
        if not folder or not root then return nil end
        local hoveredId=LocalPlayer:GetAttribute("HoveredHayId")
        if hoveredId~=nil then
            for _,part in ipairs(folder:GetChildren()) do
                if pileHay(part) and part:GetAttribute("HayId")==hoveredId and (part.Position-root.Position).Magnitude<30 then
                    return part
                end
            end
        end
        local best,dist=nil,30
        for _,part in ipairs(folder:GetChildren()) do
            if pileHay(part) then
                local d=(part.Position-root.Position).Magnitude
                if d<dist then best,dist=part,d end
            end
        end
        return best
    end
    local function grabCandidates(part)
        local out={}
        local radius=tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
        if not part or radius<=0 then return out end
        local folder=hayFolder()
        if not folder then return out end
        for _,other in ipairs(folder:GetChildren()) do
            if other~=part and pileHay(other)
                and (other.Position-part.Position).Magnitude<=radius+1 then
                out[#out+1]=other:GetAttribute("HayId")
                if #out>=6 then break end
            end
        end
        return out
    end
    local function nearestDropped()
        local folder=Workspace:FindFirstChild("DroppedHay")
        local root=getRoot()
        if not folder or not root then return nil end
        local best,dist=nil,28
        for _,obj in ipairs(folder:GetChildren()) do
            local part=obj:IsA("BasePart") and obj
                or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local distance=(part.Position-root.Position).Magnitude
                if distance<dist then best,dist=obj,distance end
            end
        end
        return best
    end
    -- Matches main Chapter 1's AutoFindNeedle: PickHay(id,candidates)
    -- until objective is revealed, but never steal the needle's input.
    task.spawn(function()
        while alive do
            task.wait(0.30)
            if not alive then break end
            if not on() then continue end
            if not endingVisible() and not inputLocked()
                and not needlePriority() then
                local held=tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0
                local cap=tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25
                if held>=cap then
                    if SellHay then pcall(function()SellHay:FireServer()end) end
                else
                    local part=closestHay()
                    local id=part and part:GetAttribute("HayId")
                    if type(id)=="number" and PickHay then
                        local others=grabCandidates(part)
                        pcall(function()PickHay:FireServer(id,others)end)
                    end
                end
                if PickDroppedHay then
                    local dropped=nearestDropped()
                    if dropped then
                        pcall(function()PickDroppedHay:FireServer(dropped)end)
                    end
                end
            end
        end
    end)
    local function findOrbitHayTarget(anchor)
        local folder=hayFolder()
        if not folder or not anchor then return nil end
        local radius=BANDS[(orbit.lap%#BANDS)+1].radius
        local x=anchor.X+math.cos(orbit.angle)*radius*0.82
        local z=anchor.Z+math.sin(orbit.angle)*radius*0.82
        local best,score=nil,math.huge
        for _,part in ipairs(folder:GetChildren()) do
            if pileHay(part) then
                local dx,dz=part.Position.X-anchor.X,part.Position.Z-anchor.Z
                local distance=math.sqrt(dx*dx+dz*dz)
                if distance>3 and distance<=radius*1.45 then
                    local xx,zz=part.Position.X-x,part.Position.Z-z
                    local sc=xx*xx+zz*zz
                    if sc<score then best,score=part,sc end
                end
            end
        end
        return best
    end
    local function orbitTntThrow(root,anchor)
        local origin=root.Position+Vector3.new(0,1.5,0)
        local radius=BANDS[(orbit.lap%#BANDS)+1].radius
        local radial=Vector3.new(math.cos(orbit.angle),0,math.sin(orbit.angle))
        local part=findOrbitHayTarget(anchor)
        local target=anchor+radial*radius*0.82+Vector3.new(0,1,0)
        if part then
            target=part.Position+Vector3.new(0,math.max(0.5,part.Size.Y*0.5),0)
        end
        local displacement=target-origin
        if displacement.Magnitude<1.5 then
            local flat=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
            if flat.Magnitude<0.1 then flat=Vector3.new(0,0,-1) end
            displacement=flat.Unit*4+Vector3.new(0,-2,0)
            target=origin+displacement
        end
        local up=math.abs(displacement.Unit:Dot(Vector3.yAxis))>0.97
            and Vector3.zAxis or Vector3.yAxis
        local duration=0.45
        local velocity=displacement/duration
            +Vector3.new(0,0.5*Workspace.Gravity*duration,0)
        return CFrame.lookAt(origin,target,up),velocity
    end
    do
local function createTntController(d)
    local state={nextLight=0}
    local stopped=false
    local function now() return d.now and d.now() or os.clock() end
    local function allowed() return not stopped and d.enabled() end
    local self={}
    function self:Stop() stopped=true;state.pending=nil;state.throwAt=nil end
    function self:GetState() return {pending=state.pending,throwAt=state.throwAt,nextLight=state.nextLight} end
    function self:Reply(kind,value)
        if stopped or not state.pending then return end
        local t=now()
        if kind=="lit" then
            state.pending=nil
            state.throwAt=t+math.max(0,tonumber(d.lightTime()) or 0.50)
            state.nextLight=t+math.max(0.5,tonumber(d.cooldown()) or 20)
        elseif kind=="denied" then
            state.pending=nil;state.throwAt=nil
            state.nextLight=t+math.max(0.25,tonumber(value) or 1)
        end
    end
    function self:Step()
        local t=now()
        if not allowed() then state.pending=nil;state.throwAt=nil;return end
        if state.pending then
            if t-state.pending>=2 then state.pending=nil end
            return
        end
        if state.throwAt then
            if t<state.throwAt then return end
            state.throwAt=nil
            if allowed() then pcall(d.throw) end
            return
        end
        if t<state.nextLight then return end
        state.pending=t
        state.nextLight=t+math.max(0.5,tonumber(d.cooldown()) or 20)
        local ok,sent=pcall(d.light)
        if not ok or sent==false then state.pending=nil;state.nextLight=t+1 end
    end
    return self
end
        if TntAction then
            local function allowed()
                return on() and not endingVisible() and not inputLocked() and not needlePriority()
                    and own("TntOwned") and orbit.ready and getRoot()~=nil and orbit.center~=nil
            end
            local controller=createTntController({
                enabled=allowed,
                cooldown=function()
                    return math.max(0.5,tonumber(LocalPlayer:GetAttribute("TntCooldown")) or 20,
                        tonumber(tntTiming.LightCooldown) or 0)
                end,
                lightTime=function() return tonumber(tntTiming.ThrowDelay) or 0.5 end,
                light=function() return pcall(function() TntAction:FireServer("light") end) end,
                throw=function()
                    if not allowed() then return end
                    local cf,velocity=orbitTntThrow(getRoot(),orbit.center)
                    TntAction:FireServer("throw",cf,velocity)
                end,
            })
            connections[#connections+1]=TntAction.OnClientEvent:Connect(function(kind,value) controller:Reply(kind,value) end)
            local oldStop=api.Stop
            api.Stop=function() controller:Stop();oldStop() end
            task.spawn(function()
                while alive do task.wait(0.05);if not alive then break end;if on() then controller:Step() end end
            end)
        end
    end
    task.spawn(function()
        while alive do
            task.wait(0.5)
            if not alive then break end
            if not on() then continue end
            if not endingVisible() and not inputLocked() and not needlePriority() then
                if PitchforkDig and own("PitchforkOwned") and not needlePriority() then
                    local hay=closestHay()
                    local id=hay and hay:GetAttribute("HayId")
                    if type(id)=="number" then
                        pcall(function()PitchforkDig:FireServer(id)end)
                    end
                end
                if DeployDrone and own("DroneOwned")
                    and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                    pcall(function()DeployDrone:FireServer()end)
                end
            end
        end
    end)
    task.spawn(function()
        while alive do
            task.wait(1)
            if not alive then break end
            if not on() then continue end
            if not endingVisible() and BuyShopItem then
                for _,item in ipairs({
                    {item="Pitchfork",attr="PitchforkOwned"},
                    {item="Tnt",attr="TntOwned"},
                    {item="Drone",attr="DroneOwned"},
                }) do
                    if not own(item.attr) then
                        pcall(function()BuyShopItem:FireServer(item.item)end)
                    end
                end
            end
        end
    end)
    -- Four requested auto-upgrades plus the main hub's default ON
    -- VacuumRuntime. Same cash, level, and next-cost checks as tryBuyTrack
    -- in Chapter 1; only the missing standalone worker is new.
    task.spawn(function()
        local cfg=folder:FindFirstChild("Config")
            or folder:WaitForChild("Config",15)
        local GameConfig=nil
        if cfg and cfg:IsA("ModuleScript") then
            local ok,loaded=pcall(require,cfg)
            if ok and type(loaded)=="table" then GameConfig=loaded
            else warn("[Beyy Auto Wins] Upgrade Config require failed: "..tostring(loaded)) end
        end
        if not GameConfig or type(GameConfig.UPGRADE_TRACKS)~="table" then
            warn("[Beyy Auto Wins] Cash upgrade tracks unavailable; other farming continues")
            return
        end
        if not BuyUpgrade then
            warn("[Beyy Auto Wins] BuyUpgrade remote missing; other farming continues")
            return
        end
        local function cash()
            local stats=LocalPlayer:FindFirstChild("leaderstats")
            local value=stats and stats:FindFirstChild("Cash")
            return value and tonumber(value.Value) or 0
        end
        local upgradePurchaseAttempts={}
        local function tryBuyTrack(trackName)
            local track=GameConfig.UPGRADE_TRACKS[trackName]
            if not track or type(track.Levels)~="table" then return end
            local current=tonumber(LocalPlayer:GetAttribute("HayUpgrade"..trackName)) or 1
            if current>=#track.Levels then return end
            local nextLevel=track.Levels[current+1]
            if not nextLevel then return end
            if cash() >= (nextLevel.Cost or 0) then
                local now=os.clock()
                local pending=upgradePurchaseAttempts[trackName]
                if pending and pending.level==current and now-pending.time<0.7 then return end
                upgradePurchaseAttempts[trackName]={level=current,time=now}
                local ok=pcall(function() BuyUpgrade:FireServer(trackName) end)
                if not ok then upgradePurchaseAttempts[trackName]=nil end
            end
        end
        local tracks={}
        for name,track in pairs(GameConfig.UPGRADE_TRACKS) do
            if type(track)=="table" and type(track.Levels)=="table" and #track.Levels>1 then
                tracks[#tracks+1]=name
            end
        end
        table.sort(tracks)
        log("Auto-upgrading all available cash tracks: "..table.concat(tracks,", "))
        while alive do
            task.wait(1.5)
            if not alive then break end
            if not on() then continue end
            if on() then
                for _,trackName in ipairs(tracks) do
                    tryBuyTrack(trackName)
                end
            end
        end
    end)

    task.spawn(function()
        local shared=RS:FindFirstChild("Shared")
        local configs=shared and shared:FindFirstChild("Configs")
        local module=configs and configs:FindFirstChild("UpgradeConfig")
        if not module or not BuyUpgrade then return end
        local ok,upgradeConfig=pcall(require,module)
        if not ok or type(upgradeConfig)~="table" then return end
        for _,method in ipairs({"getUpgrade","getMaxLevel","getPrice"}) do
            if type(upgradeConfig[method])~="function" then return end
        end
        local names={"ExtraHoldAmount","ExtraTakeAmount","GemValue","ExtraHayValuePercentage"}
        while alive do
            task.wait(2)
            if not alive then break end
            if not on() or endingVisible() then continue end
            local gems=tonumber(player:GetAttribute("Gems")) or 0
            for _,name in ipairs(names) do
                local valid,upgrade=pcall(function()return upgradeConfig.getUpgrade(name)end)
                if valid and upgrade then
                    local level=tonumber(player:GetAttribute("Upgrade"..name)) or 0
                    local maxOk,maxLevel=pcall(function()return upgradeConfig:getMaxLevel(upgrade)end)
                    if maxOk and tonumber(maxLevel) and level<maxLevel then
                        local costOK,cost=pcall(function()return upgradeConfig:getPrice(upgrade,level)end)
                        if costOK and tonumber(cost) and gems>=cost then
                            pcall(function()BuyUpgrade:FireServer(name)end)
                        end
                    end
                end
            end
        end
    end)
    -- Main Chapter 1 Farmer_NPC hand-in, with a closer approach and a
    -- bounded positioning cadence. Keep retrying the real remote until
    -- server-owned NeedleOwned clears or the results screen appears.
    if NeedleHandIn then
        local lastHandIn=0
        local lastMove=0
        local lastLog=-math.huge
        local ownedPreviously=false
        local handInSent=false
        local positioned=false
        connections[#connections+1]=RunService.Heartbeat:Connect(function()
            if not on() or needlePickupActive or endingVisible() then return end
            if mode=="Hay" and not impossibleCleared then return end
            local owned=LocalPlayer:GetAttribute("NeedleOwned")==true
            if not owned then
                if ownedPreviously and handInSent then
                    log("NeedleOwned cleared after hand-in attempts; awaiting round ending")
                end
                ownedPreviously=false
                handInSent=false
                positioned=false
                return
            end
            if not ownedPreviously then
                log("NeedleOwned confirmed; prioritizing Farmer hand-in")
                ownedPreviously=true
                positioned=false
                lastHandIn=0
            end
            local now=os.clock()
            local root=getRoot()
            local npcs=Workspace:FindFirstChild("NPC")
            local farmer=npcs and npcs:FindFirstChild("Farmer_NPC")
            if not root or not root.Parent or not farmer then
                if now-lastLog>=8 then
                    lastLog=now
                    warn("[Beyy Auto Wins] Needle hand-in waiting for Farmer_NPC / HumanoidRootPart")
                end
                return
            end
            local target=farmer:GetPivot().Position
            local distance=(root.Position-target).Magnitude
            -- The main hub uses the Farmer's local +Z four-stud offset.
            -- Approach once even if the player is inside the older 15-stud
            -- threshold, because server acceptance may require closer range.
            if (not positioned or distance>8) and now-lastMove>=0.25 then
                lastMove=now
                local moved,movementError=pcall(function()
                    root.CFrame=farmer:GetPivot()*CFrame.new(0,0,4)
                    root.AssemblyLinearVelocity=Vector3.zero
                    root.AssemblyAngularVelocity=Vector3.zero
                end)
                if moved then positioned=true
                elseif now-lastLog>=8 then
                    lastLog=now
                    warn("[Beyy Auto Wins] Farmer hand-in approach failed: "..tostring(movementError))
                end
            end
            if now-lastMove>=0.20 and now-lastHandIn>=1.2 then
                lastHandIn=now
                local ok,remoteError=pcall(function()NeedleHandIn:FireServer()end)
                if ok then handInSent=true
                elseif now-lastLog>=8 then
                    lastLog=now
                    warn("[Beyy Auto Wins] NeedleHandIn remote failed: "..tostring(remoteError))
                end
                if now-lastLog>=4 then
                    lastLog=now
                    log("Needle hand-in pending; distance="..
                        string.format("%.1f",(root.Position-target).Magnitude)..
                        " studs, remoteSent="..tostring(handInSent))
                end
            end
        end)
    end
    -- Exact pickup/hover/camera/filter routine taken from Chapter 1.
    -- Only its _G hub cleanup registration is mapped to this standalone Stop.
    local function installMainNeedlePickup()
    local SETTINGS = { HeightAboveNeedle = 2.5, HorizontalOffsetStuds = 2.0, MaxClicks = 8, MousePressSeconds = 0.085, OwnershipWaitSeconds = 0.055, RetryDelay = 0.16,
        FilterRadiusPixels = 50, FilterNeedleRadiusStuds = 8, FilterMaxParts = 400 }
    local busy = false
    local lastAttempt = -math.huge
    local trackedNeedle = nil
    local confirmedNeedlePart, confirmedNeedleId = nil, nil
    local activeCleanup = nil
    local renderName = "BeyyV103_00NeedleAimHover_" .. tostring(LocalPlayer.UserId)
    local lastPrerequisiteWarnAt = -math.huge
    local lastPickupFailureWarnAt = -math.huge
    local function reportPrerequisite(reason)
        if os.clock() - lastPrerequisiteWarnAt >= 30 then
            lastPrerequisiteWarnAt = os.clock()
            warn("[Needle] Pickup waiting: " .. reason .. " (retrying automatically; warnings limited to once every 30s)")
        end
    end
    local function owned() return LocalPlayer:GetAttribute("NeedleOwned") == true end
    local function tryPickup(needle)
        if busy or Unloaded or roundEndingVisible() or not State.AutoPickupNeedle or owned() or not needle or not needle.Parent then return false end
        busy = true
        needlePickupActive = true
        local started = os.clock()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        local needleId = needle:GetAttribute("HayId")
        if not char or not char.Parent or not root or not root.Parent then
            reportPrerequisite("character or HumanoidRootPart unavailable")
            busy = false
            needlePickupActive = false
            return false
        end
        if not cam then
            reportPrerequisite("Workspace.CurrentCamera unavailable")
            busy = false
            needlePickupActive = false
            return false
        end
        if type(needleId) ~= "number" and needle:GetAttribute("IsNeedleObjective") ~= true then
            reportPrerequisite("needle HayId invalid (type=" .. type(needleId) .. "); refreshing target")
            trackedNeedle = nil
            busy = false
            needlePickupActive = false
            return false
        end
        local initialPivot = char:GetPivot()
        local originalHover = LocalPlayer:GetAttribute("HoveredHayId")
        local previousPickupCameraType, previousPickupCameraSubject, previousPickupCameraCFrame
        local pickupCameraCaptured = false
        local mouseDown, bound, cleaned, success = false, false, false, false
        local observedOwnership = false
        local clicks = 0
        local filteredParts = {}
        local queryStats = { filtered = 0 }
        local failureReason = "No NeedleOwned confirmation"
        local function restoreQueryFilter()
            for part, previous in pairs(filteredParts) do
                local ok = pcall(function()
                    if part.Parent then
                        part.CanQuery = previous.query
                        part.CanCollide = previous.collide
                    end
                end)
                filteredParts[part] = nil
            end
        end
        local function applyQueryFilter()
            local activeCamera = Workspace.CurrentCamera
            if not activeCamera or not needle.Parent then return end
            local screenSize = activeCamera.ViewportSize
            if screenSize.Y <= 0 then return end
            local middle = screenSize / 2
            local projectedNeedle = activeCamera:WorldToViewportPoint(needle.Position)
            local focalLength = screenSize.Y / (2 * math.tan(math.rad(activeCamera.FieldOfView / 2)))

            for pass = 1, 2 do
                if queryStats.filtered >= SETTINGS.FilterMaxParts then break end
                for _, folderName in ipairs({"HaystackClient", "HaystackCollision"}) do
                    local folder = Workspace:FindFirstChild(folderName)
                    if folder then
                        for _, part in ipairs(folder:GetDescendants()) do
                            if queryStats.filtered >= SETTINGS.FilterMaxParts then break end
                            if Unloaded or not State.AutoPickupNeedle or observedOwnership then return end
                            if part:IsA("BasePart") and part ~= needle
                                and part:GetAttribute("IsNeedleObjective") ~= true
                                and part.CanQuery and not filteredParts[part] then
                                local nearNeedle = (part.Position - needle.Position).Magnitude
                                    <= SETTINGS.FilterNeedleRadiusStuds + math.min(part.Size.Magnitude * 0.5, 4)
                                local qualifies = (pass == 1 and nearNeedle)
                                if pass == 2 and not nearNeedle then
                                    local screen = activeCamera:WorldToViewportPoint(part.Position)
                                    if screen.Z > 0 and screen.Z < 45 then
                                        local radius = (part.Size.Magnitude * 0.5) * focalLength / screen.Z
                                        local distanceFromClick = (Vector2.new(screen.X, screen.Y) - middle).Magnitude
                                        local distanceFromNeedle = (Vector2.new(screen.X, screen.Y)
                                            - Vector2.new(projectedNeedle.X, projectedNeedle.Y)).Magnitude
                                        qualifies = distanceFromClick <= SETTINGS.FilterRadiusPixels + radius
                                            or (projectedNeedle.Z > 0 and distanceFromNeedle <= SETTINGS.FilterRadiusPixels + radius)
                                    end
                                end
                                if qualifies then
                                    local originalQuery, originalCollide = part.CanQuery, part.CanCollide
                                    local ok = pcall(function()
                                        if part.CanCollide then part.CanCollide = false end
                                        part.CanQuery = false
                                    end)
                                    if ok and not part.CanQuery then
                                        filteredParts[part] = { query = originalQuery, collide = originalCollide }
                                        queryStats.filtered += 1
                                    else
                                        pcall(function()
                                            part.CanQuery = originalQuery
                                            part.CanCollide = originalCollide
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local ownershipConnection
        local function captureOwnership()
            if not observedOwnership and owned() then
                observedOwnership = true
            end
        end
        ownershipConnection = LocalPlayer:GetAttributeChangedSignal("NeedleOwned"):Connect(captureOwnership)
        captureOwnership()
        local function releaseMouse()
            if not mouseDown then return end
            local center = cam.ViewportSize / 2
            pcall(function() VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0) end)
            mouseDown = false
        end
        local function waitForConfirmation(seconds)
            local deadline = os.clock() + seconds
            while not Unloaded and State.AutoPickupNeedle and os.clock() < deadline do
                captureOwnership()
                if observedOwnership then return true end
                task.wait(0.025)
            end
            captureOwnership()
            return observedOwnership
        end
        local function cleanup()
            if cleaned then return end
            cleaned = true
            releaseMouse()
            if bound then
                pcall(function() RunService:UnbindFromRenderStep(renderName) end)
                bound = false
            end
            if pickupCameraCaptured and cam.Parent then
                pcall(function()

                    local restoreType = afkFarmModeActive() and Enum.CameraType.Custom
                        or previousPickupCameraType or Enum.CameraType.Custom
                    cam.CameraType = restoreType
                    if previousPickupCameraSubject and previousPickupCameraSubject.Parent then
                        cam.CameraSubject = previousPickupCameraSubject
                    else
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid then cam.CameraSubject = humanoid end
                    end
                    if restoreType == Enum.CameraType.Scriptable and previousPickupCameraCFrame then
                        cam.CFrame = previousPickupCameraCFrame
                    end
                end)
            end
            if ownershipConnection then
                ownershipConnection:Disconnect()
                ownershipConnection = nil
            end
            restoreQueryFilter()
            captureOwnership()
            success = success or observedOwnership
            pcall(function()
                if LocalPlayer:GetAttribute("HoveredHayId") == needleId then
                    LocalPlayer:SetAttribute("HoveredHayId", originalHover)
                end
            end)
            if success then
                confirmedNeedlePart, confirmedNeedleId = needle, needleId
            elseif char.Parent then
                pcall(function() char:PivotTo(initialPivot) end)
            end
            local elapsed = os.clock() - started
            if success then
                print(string.format("[Needle] Picked up HayId=%s in %.2fs (%d clicks)",
                    tostring(needleId), elapsed, clicks))
            elseif os.clock() - lastPickupFailureWarnAt >= 2 then
                lastPickupFailureWarnAt = os.clock()
                warn(string.format("[Needle] Pickup unconfirmed HayId=%s after %.2fs: %s (%d clicks); retrying",
                    tostring(needleId), elapsed, tostring(failureReason), clicks))
            end
            activeCleanup = nil
            busy = false
            needlePickupActive = false
            lastAttempt = os.clock()
        end
        activeCleanup = cleanup
        local ok, err = xpcall(function()

            if afkFarmModeActive() then enterNeedleCamera() end
            previousPickupCameraType = cam.CameraType
            previousPickupCameraSubject = cam.CameraSubject
            previousPickupCameraCFrame = cam.CFrame
            pickupCameraCaptured = true
            local inputDeadline = os.clock() + 0.8
            while autoUiMouseBusy and os.clock() < inputDeadline and not Unloaded do task.wait(0.01) end
            if autoUiMouseBusy then failureReason = "UI click still owns mouse"; return end
            if Unloaded or not State.AutoPickupNeedle then failureReason = "Pickup cancelled before teleport"; return end
            local rootToPivot = root.CFrame:ToObjectSpace(char:GetPivot())

            local cameraForward = cam.CFrame.LookVector
            local horizontalForward = Vector3.new(cameraForward.X, 0, cameraForward.Z)
            if horizontalForward.Magnitude < 0.05 then
                local rootForward = root.CFrame.LookVector
                horizontalForward = Vector3.new(rootForward.X, 0, rootForward.Z)
            end
            if horizontalForward.Magnitude < 0.05 then
                horizontalForward = Vector3.new(0, 0, -1)
            end
            horizontalForward = horizontalForward.Unit
            local targetRootPosition = needle.Position - horizontalForward * SETTINGS.HorizontalOffsetStuds
                + Vector3.new(0, SETTINGS.HeightAboveNeedle, 0)
            local intendedDistance = (targetRootPosition - needle.Position).Magnitude
            local correctionLimit = intendedDistance + 0.35
            local retryLimit = intendedDistance + 0.80
            local function placeNearNeedle()

                local lookTarget = Vector3.new(needle.Position.X, targetRootPosition.Y, needle.Position.Z)
                local targetRoot = CFrame.lookAt(targetRootPosition, lookTarget)
                char:PivotTo(targetRoot * rootToPivot)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end

            -- Use the native objective protocol first; preserve click pickup as fallback.
            placeNearNeedle()
            task.wait(0.20)
            if Unloaded or not State.AutoPickupNeedle or roundEndingVisible() or not needle.Parent then
                failureReason = "Pickup cancelled before native request"; return
            end
            captureOwnership()
            if observedOwnership then success = true; return end
            local pickupRemote = PickHay
            if pickupRemote then
                local sent = pcall(function() pickupRemote:FireServer("Objective") end)
                if sent and waitForConfirmation(0.50) then
                    success = true
                    return
                end
            end

            local cameraPosition = targetRootPosition - horizontalForward * 3.5
                + Vector3.new(0, 3.5, 0)
            local function aimAtNeedle()
                if Unloaded or not needle.Parent or observedOwnership or roundEndingVisible() then return end
                if Workspace.CurrentCamera ~= cam then return end
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.lookAt(cameraPosition, needle.Position, Vector3.yAxis)
            end
            placeNearNeedle()
            captureOwnership()
            if observedOwnership then success = true; return end
            local function forceHover()
                if not Unloaded and State.AutoPickupNeedle and needle.Parent and not observedOwnership then
                    aimAtNeedle()
                    if LocalPlayer:GetAttribute("HoveredHayId") ~= needleId then
                        LocalPlayer:SetAttribute("HoveredHayId", needleId)
                    end
                end
            end
            LocalPlayer:SetAttribute("HoveredHayId", needleId)
            aimAtNeedle()
            RunService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value + 30, forceHover)
            bound = true
            RunService.RenderStepped:Wait()
            applyQueryFilter()

            RunService.RenderStepped:Wait()
            for i = 1, SETTINGS.MaxClicks do
                captureOwnership()
                if observedOwnership then success = true; break end
                if Unloaded or not State.AutoPickupNeedle or roundEndingVisible() then failureReason = "Pickup cancelled at round end"; break end
                if not needle.Parent then failureReason = "Needle disappeared before confirmation"; break end
                if not char.Parent or not root.Parent then failureReason = "Character disappeared"; break end
                local distance = (root.Position - needle.Position).Magnitude
                if distance > correctionLimit then
                    placeNearNeedle()
                    distance = (root.Position - needle.Position).Magnitude
                end
                if distance > retryLimit then
                    failureReason = string.format("Root drifted beyond diagonal target (%.2f studs; target %.2f)", distance, intendedDistance)
                    break
                end
                forceHover()

                local center = cam.ViewportSize / 2
                pcall(function() VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game) end)
                RunService.RenderStepped:Wait()
                forceHover()
                local hoverMatches = LocalPlayer:GetAttribute("HoveredHayId") == needleId
                local projectedNeedle, onScreen = cam:WorldToViewportPoint(needle.Position)
                local screenOffset = onScreen and (Vector2.new(projectedNeedle.X, projectedNeedle.Y) - center).Magnitude or -1
                if not hoverMatches then
                    LocalPlayer:SetAttribute("HoveredHayId", needleId)
                    RunService.RenderStepped:Wait()
                    forceHover()
                    hoverMatches = LocalPlayer:GetAttribute("HoveredHayId") == needleId
                end
                if not hoverMatches then
                    failureReason = "HoveredHayId temporarily lost; re-aiming"
                    if i < SETTINGS.MaxClicks then continue end
                    break
                end
                if not onScreen or screenOffset > 15 then
                    failureReason = "Needle camera off-centre; re-aiming"
                    if i < SETTINGS.MaxClicks then
                        placeNearNeedle()
                        RunService.RenderStepped:Wait()
                        forceHover()
                        continue
                    end
                    break
                end
                local pressed, pressErr = pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                end)
                if not pressed then failureReason = "VIM press failed: " .. tostring(pressErr); break end
                clicks += 1
                mouseDown = true
                task.wait(i <= 2 and SETTINGS.MousePressSeconds or 0.10)
                releaseMouse()
                if waitForConfirmation(i <= 2 and SETTINGS.OwnershipWaitSeconds or 0.10) then success = true; break end
                if i == 4 then applyQueryFilter() end
            end
            captureOwnership()
            success = success or observedOwnership
        end, function(e) return tostring(e) end)
        if not ok then failureReason = "Runtime error: " .. tostring(err) end
        cleanup()
        return success
    end
    needleStop=function()
        if activeCleanup then pcall(activeCleanup) end
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    end
    task.spawn(function()
        while not Unloaded do
            task.wait(0.05)
        if Unloaded then break end
            if not IN_GAME or not on() or (mode=="Hay" and not impossibleCleared)
                or roundEndingVisible() or not State.AutoPickupNeedle or owned() then
                trackedNeedle = nil
            else
                if not trackedNeedle or not trackedNeedle.Parent
                    or (trackedNeedle:GetAttribute("HIDDEN_WITHIN") ~= nil
                        and trackedNeedle:GetAttribute("HIDDEN_WITHIN") ~= false)
                    or trackedNeedle:GetAttribute("IsNeedleObjective") ~= true
                    then
                    trackedNeedle = findExposedNeedlePart()
                end
                if trackedNeedle and trackedNeedle == confirmedNeedlePart
                    and trackedNeedle:GetAttribute("HayId") == confirmedNeedleId then
                    continue
                end
                if trackedNeedle and not busy and (os.clock() - lastAttempt) >= SETTINGS.RetryDelay then
                    lastAttempt = os.clock()
                    local target = trackedNeedle
                    task.spawn(function() tryPickup(target) end)
                end
            end
        end
    end)
    end
    installMainNeedlePickup()

end

local function farmhouseWorker()
    log("Farmhouse: sceneton eight-route AFK sweep, heat-controlled vacuum, Skip and Replay enabled.")
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
            and not needleLocked() and not autoUiMouseBusy
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
    local function skipButton()
        local pg=player:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        for _,obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("GuiButton") and guiVisible(obj) then
                local text=obj.Name:lower()
                if obj:IsA("TextButton") then text=text.." "..obj.Text:lower() end
                local parent=obj.Parent
                for _=1,3 do
                    if not parent or parent==pg then break end
                    text=text.." "..parent.Name:lower()
                    parent=parent.Parent
                end
                if text:find("skip",1,true) then return obj end
            end
        end
        return nil
    end
    local function createReplayRecovery(d)
        local state={}
        local stopped=false
        local function now() return d.now and d.now() or os.clock() end
        local function reset()
            state={attempts=0,recoveries=0,nextAttempt=0}
        end
        reset()
        local function emit(phase,message)
            if state.phase~=phase or state.message~=message then
                state.phase,state.message=phase,message
                if d.status then pcall(d.status,message,{phase=phase,attempts=state.attempts,recoveries=state.recoveries}) end
            end
        end
        local self={}
        function self:Reset() reset() end
        function self:Stop() stopped=true reset() end
        function self:GetStatus()
            return {phase=state.phase,message=state.message,attempts=state.attempts,recoveries=state.recoveries,
                firstSeen=state.firstSeen,launchAt=state.launchAt,pending=state.pending,nextAttempt=state.nextAttempt}
        end
        function self:TeleportState(value)
            if stopped or not state.firstSeen then return end
            if tostring(value):find("Failed",1,true) then self:TeleportFailed(tostring(value)); return end
            state.teleporting=true
            state.launchAt=state.launchAt or now()
            emit("launching","Replay teleport in progress")
        end
        function self:TeleportFailed(message)
            if stopped or not state.firstSeen or not d.enabled() or not d.ending() then return end
            state.teleporting=false
            state.launchAt=nil
            state.nextAttempt=now()+15
            emit("retry","Replay teleport failed; staying in Chapter 1 and waiting to retry: "..tostring(message))
        end
        local function snapshot()
            local ok,value=pcall(d.snapshot)
            return ok and type(value)=="table" and value or nil
        end
        function self:Step(button,ready)
            if stopped then return end
            if not d.enabled() or not d.ending() then
                if state.firstSeen then reset() end
                return
            end
            local t=now()
            state.firstSeen=state.firstSeen or t
            local vote=snapshot()
            if not vote then emit("waiting","Replay state unavailable");return end
            -- A live server launch is authoritative; never cancel an active vote.
            if vote.launching==true then
                state.launchAt=state.launchAt or t
                emit("launching","Server launching Replay; waiting for next round")
                return
            end
            state.launchAt=nil
            if state.button~=button then
                state.button=button
                state.buttonSeen=t
            end
            local count,total
            if button then
                local text=""
                if button:IsA("TextButton") then text=button.Text end
                for _,child in ipairs(button:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        text=text.." "..child.Text
                    end
                end
                count,total=text:match("(%d+)%s*/%s*(%d+)")
                count,total=tonumber(count),tonumber(total)
            end
            if vote.voted==true or (total and total>0 and count and count>=total)
                or (state.confirmed and vote.voted~=false) then
                state.confirmed=true
                emit("voted","Replay vote registered; waiting for next round")
                return
            end
            if state.confirmed then
                if count==0 and vote.voted==false and t-(state.confirmedAt or t)>5 then
                    state.confirmed=false
                else
                    emit("voted","Replay vote registered; waiting for next round")
                    return
                end
            end
            if not button then emit("waiting","Waiting for native Replay button");return end
            if ready==false then emit("waiting","Waiting for hub menu to close");return end
            if t-(state.buttonSeen or t)<0.25 or t<state.nextAttempt then return end
            state.attempts+=1
            local before=count
            if d.ensureReload then pcall(d.ensureReload) end
            local ok,sent=pcall(d.fallback,button,"click")
            local cooldown=state.attempts<2 and 0.8 or state.attempts<5 and 1.5
                or state.attempts<10 and 3 or 6
            state.nextAttempt=now()+cooldown
            if ok and sent==true then
                local deadline=os.clock()+0.8
                repeat
                    if not d.ending() then state.confirmed=true;break end
                    local updated=snapshot()
                    if updated and (updated.launching or updated.voted) then
                        state.confirmed=true
                        break
                    end
                    if before~=nil then
                        local labels={}
                        if button:IsA("TextButton") then labels[#labels+1]=button.Text end
                        for _,child in ipairs(button:GetDescendants()) do
                            if child:IsA("TextLabel") or child:IsA("TextButton") then
                                labels[#labels+1]=child.Text
                            end
                        end
                        local advanced=tonumber(table.concat(labels," "):match("(%d+)%s*/%s*%d+"))
                        if advanced and advanced>before then
                            state.confirmed=true
                            break
                        end
                    end
                    task.wait(0.05)
                until os.clock()>=deadline
                if state.confirmed then state.confirmedAt=now() end
            end
            emit(state.confirmed and "voted" or "requesting",
                string.format("Replay GUI click %d (%s); shared votes=%s/%s",
                    state.attempts,state.confirmed and "confirmed" or
                    (ok and sent==true and "sent, awaiting confirmation" or "not sent"),
                    tostring(count),tostring(total)))
        end
        return self
    end    local function replayVoteRemote()
        local folder=game:GetService("ReplicatedStorage"):FindFirstChild("NeedleHaystack")
        local remote=folder and folder:FindFirstChild("ReplayVote")
        return remote and remote:IsA("RemoteEvent") and remote or nil
    end
    local function replaySnapshot()
        local remote=replayVoteRemote()
        return {available=remote~=nil,voted=player:GetAttribute("ReplayVoted")==true,
            launching=remote and remote:GetAttribute("Launching")==true or false}
    end
    local function replayActionAllowed()
        local state=replaySnapshot()
        return on() and endingVisible() and not state.voted and not state.launching
    end
    local function verifiedReplayActivation(button)
        if not replayActionAllowed() or type(getconnections)~="function" then return false end
        for _,connection in ipairs(getconnections(button.Activated)) do
            local fn=connection.Function
            if connection.Enabled~=false and type(fn)=="function" then
                local ok,source=pcall(function() return debug.info(fn,"s") end)
                if ok and type(source)=="string" and source:find("ReplayButtonClient",1,true) then
                    if not replayActionAllowed() then return false end
                    return pcall(fn)
                end
            end
        end
        return false
    end
    local function replayFallback(button,method)
        if not button or not guiVisible(button) or not replayActionAllowed() then return false end
        if method=="activated" then return verifiedReplayActivation(button) end
        -- Click the native Replay UI only while no launch or input worker is active.
        if autoUiMouseBusy or needlePickupActive then return false end
        local pos,size=button.AbsolutePosition,button.AbsoluteSize
        local inset=GuiService:GetGuiInset()
        local x,y=pos.X+size.X/2+inset.X,pos.Y+size.Y/2+inset.Y
        if not x then return false end
        autoUiMouseBusy=true
        local down=false
        local ok=pcall(function()
            VirtualInputManager:SendMouseMoveEvent(x,y,game)
            RunService.RenderStepped:Wait()
            if not replayActionAllowed() then return end
            VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0)
            down=true
            task.wait(0.085)
        end)
        if down then pcall(function() VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0) end) end
        autoUiMouseBusy=false
        return ok and down
    end
    local replayRecovery=createReplayRecovery({
        enabled=on,ending=endingVisible,snapshot=replaySnapshot,
        fallback=replayFallback,ensureReload=replayReload.Ensure,
        status=function(message) log("Replay: "..message) end,
    })
    api.GetReplayStatus=function() return replayRecovery:GetStatus() end
    local previousReplayStop=api.Stop
    api.Stop=function() replayRecovery:Stop();previousReplayStop() end
    connections[#connections+1]=player.OnTeleport:Connect(function(value)
        replayRecovery:TeleportState(tostring(value))
    end)
    connections[#connections+1]=game:GetService("TeleportService").TeleportInitFailed:Connect(function(who,result,message)
        if who==player then replayRecovery:TeleportFailed(message) end
    end)
    local function executeReplay()
        local ok,err=pcall(function() replayRecovery:Step(replayButtonLookup(),true) end)
        if not ok then log("Replay scan failed; retrying next scan: "..tostring(err)) end
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
            replayRecovery:Reset()
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
        while alive do
            task.wait(0.06)
            if not alive then break end
            if not on() then continue end
            updateRounds()
            if not endingVisible() then
                if needleLocked() then
                    releaseMouse()
                    if cameraBound then restoreCamera() end
                elseif not orbit.ready then
                    calibrate()
                else
                    if not cameraBound then bindCamera() end
                    followAndProbe()
                    local now=os.clock()
                    if orbit.calibrationUntil>now
                        and now-orbit.lastSurfaceSample>=1.25 then
                        orbit.lastSurfaceSample=now
                        local center,count,span=pileCenter()
                        if center and count>=25
                            and now-orbit.lastCorrectionAt>=1.1 then
                            local growth=count>=orbit.prevCount*1.25
                            local heightGrowth=span>=orbit.prevSpan+3
                            local mostlyIntact=count>=orbit.prevCount*0.75
                            if mostlyIntact and (growth or heightGrowth) then
                                orbit.prevCount,orbit.prevSpan=count,span
                                orbit.lastCorrectionAt=now
                                local current=orbit.center
                                -- Refresh Y heights only; keep the fixed physical X/Z axis.
                                local pinned=Vector3.new(orbit.axis.X,current.Y,orbit.axis.Z)
                                orbit.center=pinned
                                orbit.surfaces,orbit.top=computeSurfaces(pinned)
                                orbit.targetReady=false
                                log("Replay pile layers refreshed; original X/Z axis pinned")
                            end
                        end
                    end
                end
            end
        end
    end)
    task.spawn(function()
        while alive do
            task.wait(0.06)
            if not alive then break end
            if not on() then continue end
            if not canVacuum() then
                if holding then finishVacuum() end
                continue
            end
            local current=heat()
            local coolingSeconds=upgradeLevel("VacuumCooling")==0
                and 13 or math.max(7,12-upgradeLevel("VacuumCooling"))
            coolingSeconds=tonumber(player:GetAttribute("VacuumCoolTime")) or coolingSeconds
            local runtime=tonumber(player:GetAttribute("VacuumHeatTime")) or (30+3*upgradeLevel("VacuumRuntime"))
            if player:GetAttribute("VacuumState")=="Overheated" or (current and current>=0.999) then
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
    while alive and game.PlaceId==FARMHOUSE do
        task.wait(0.22)
        if not alive then break end
            if not on() then continue end
        if updateRounds() then
            if holding then finishVacuum() end
            executeReplay()
        elseif not needleLocked() and os.clock()>=nextSkip then
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
    task.spawn(function()
        installFarmhouseWinWorkers()
        if on() then farmhouseWorker() end
    end)
end
log("Standalone Auto Farm Wins: full win process ON, no settings or hub modules.")

-- Halt local automation after a real disconnect; do not attempt unauthenticated teleports.
task.spawn(function()
    while alive do
        task.wait(0.5)
        if not alive then break end
            if not on() then continue end
        local ok,message=pcall(function() return game:GetService("GuiService"):GetErrorMessage() end)
        if ok and type(message)=="string" and message~="" then
            warn("[Beyy] Connection lost; stopping automation: "..message)
            api.Stop()
            return
        end
    end
end)
