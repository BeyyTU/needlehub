-- BEYY_ARCADE_TWO_ROUND_TEST_V1
-- Passive test. Start before two ordinary Arcade rounds, stop after payout.
-- Never calls ArcadeReport, ArcadeSession, or changes the game's score.
local PLACE_ID=77108422251420
if game.PlaceId~=PLACE_ID then
    warn("[Arcade Two-Round Test] Run this in Search for the Needle Lobby.")
    return
end

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HS=game:GetService("HttpService")
local LocalPlayer=Players.LocalPlayer
local playerGui=LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not LocalPlayer or not playerGui then
    warn("[Arcade Two-Round Test] PlayerGui unavailable.")
    return
end
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
local previous=env.__BEYY_ARCADE_TWO_ROUND_TEST
if type(previous)=="table" and type(previous.Destroy)=="function" then
    pcall(previous.Destroy)
end

local running=false
local disposed=false
local connections={}
local uiConnections={}
local started=0
local lastStateSignature=""
local lastPlaying=false
local activeRound=nil
local lastJSON=nil
local lastFile=nil
local lastFrameAt=0
local MAX_EVENTS=1400
local MAX_SAMPLES=950
local report=nil
local hookSlot="__BEYY_ARCADE_TWO_ROUND_OBSERVER"
local arcadeFolder=RS:FindFirstChild("Arcade")

local function stamp()
    return running and math.floor((os.clock()-started)*1000+0.5)/1000 or 0
end
local function fullPath(obj)
    local ok,p=pcall(function()return obj:GetFullName()end)
    return ok and tostring(p) or tostring(obj)
end
local function valueOf(name)
    local value=tonumber(LocalPlayer:GetAttribute(name))
    if value~=nil then return value end
    if name=="SpinUsableGems" then
        value=tonumber(LocalPlayer:GetAttribute("Gems"))
        if value~=nil then return value end
        local stats=LocalPlayer:FindFirstChild("leaderstats")
        local gems=stats and stats:FindFirstChild("Gems")
        if gems then return tonumber(gems.Value) end
    end
    return nil
end
local function safe(value,depth)
    depth=depth or 0
    local kind=typeof(value)
    if kind=="nil" then return "<nil>" end
    if kind=="boolean" or kind=="number" then return value end
    if kind=="string" then return value:sub(1,180) end
    if kind=="Instance" then return {class=value.ClassName,path=fullPath(value)} end
    if kind=="Vector3" or kind=="Vector2" or kind=="CFrame" or kind=="EnumItem" then
        return tostring(value)
    end
    if kind~="table" then return "<"..tostring(kind)..">" end
    if depth>=2 then return "<nested>" end
    local out,count={},0
    for key,child in pairs(value) do
        count+=1
        if count>12 then out.__truncated=true break end
        local k=tostring(key):sub(1,60)
        local low=k:lower()
        if low:find("token",1,true) or low:find("secret",1,true)
            or low:find("password",1,true) or low:find("cookie",1,true)
            or low:find("auth",1,true) then
            out[k]="<redacted>"
        else
            out[k]=safe(child,depth+1)
        end
    end
    return out
end
local function packedArgs(...)
    local n=select("#",...)
    local a={}
    for i=1,math.min(n,10) do a[tostring(i)]=safe(select(i,...)) end
    return a,n
end
local function event(kind,data)
    if not running or not report then return end
    if #report.events>=MAX_EVENTS then
        report.counts.dropped+=1
        return
    end
    report.events[#report.events+1]={t=stamp(),kind=kind,data=data}
end
local function connect(signal,fn)
    local ok,c=pcall(function()return signal:Connect(fn)end)
    if ok and c then connections[#connections+1]=c end
end
local function arcadeRemote(obj)
    return typeof(obj)=="Instance"
        and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
        and obj.Parent~=nil and obj:IsDescendantOf(RS)
        and (obj.Name=="ArcadeReport" or obj.Name=="ArcadeSession")
        and obj.Parent.Name=="Arcade"
end

local function textsUnder(obj,max)
    local result={}
    if not obj then return result end
    local descendants=obj:GetDescendants()
    for i=1,math.min(#descendants,max or 120) do
        local x=descendants[i]
        if (x:IsA("TextLabel") or x:IsA("TextButton"))
            and type(x.Text)=="string" and x.Text~="" then
            result[#result+1]=x.Text:sub(1,130)
        end
    end
    return result
end
local function labelText(obj)
    return table.concat(textsUnder(obj,18)," | ")
end
local function parseNumber(text,word)
    local raw=tostring(text or "")
    local found=raw:match(word.."%s*:?%s*([%d,]+)")
    if not found then found=raw:match("([%d,]+)%s*"..word) end
    return found and tonumber(found:gsub(",","")) or nil
end
local function state()
    local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local screen=pg and pg:FindFirstChild("ArcadeScreen")
    local arena=screen and screen:FindFirstChild("Arena")
    local hud=arena and arena:FindFirstChild("HUD")
    local overlay=arena and arena:FindFirstChild("Overlay")
    local dim=overlay and overlay:FindFirstChild("Dim")
    local panel=dim and dim:FindFirstChild("Panel")
    local scoreText=labelText(hud and hud:FindFirstChild("Score"))
    local waveText=labelText(hud and hud:FindFirstChild("Wave"))
    local leave=panel and panel:FindFirstChild("LEAVE")
    local leaveText=leave and leave:IsA("TextButton") and leave.Text
        or labelText(leave)
    local pointsText,rewardText=nil,nil
    if screen then
        local nodes=screen:GetDescendants()
        for i=1,math.min(#nodes,450) do
            local n=nodes[i]
            if n:IsA("TextLabel") or n:IsA("TextButton") then
                local txt=tostring(n.Text or "")
                if not pointsText and (txt:match("%d+%s*PTS")
                    or txt:match("%d+%s*POINTS")) then pointsText=txt:sub(1,130) end
                if not rewardText and txt:upper():find("GEM",1,true)
                    and (txt:find("+",1,true) or txt:lower():find("leave",1,true)) then
                    rewardText=txt:sub(1,130)
                end
            end
        end
    end
    return {
        playing=LocalPlayer:GetAttribute("ArcadePlaying")==true,
        screenEnabled=screen and screen:IsA("ScreenGui") and screen.Enabled or false,
        arenaVisible=arena and arena:IsA("GuiObject") and arena.Visible or false,
        pauseVisible=dim and dim:IsA("GuiObject") and dim.Visible or false,
        gemBalance=valueOf("SpinUsableGems"),
        gemAttribute=LocalPlayer:GetAttribute("Gems"),
        score=parseNumber(scoreText:upper(),"SCORE"),
        wave=parseNumber(waveText:upper(),"WAVE"),
        points=parseNumber(tostring(pointsText or ""):upper(),"PTS")
            or parseNumber(tostring(pointsText or ""):upper(),"POINTS"),
        scoreText=scoreText,waveText=waveText,
        pointsText=pointsText,leaveText=leaveText,rewardText=rewardText,
    }
end
local function addSample(why,force)
    if not running or not report then return end
    local current=state()
    local signature=table.concat({
        tostring(current.playing),tostring(current.screenEnabled),
        tostring(current.gemBalance),tostring(current.score),
        tostring(current.wave),tostring(current.points),
        tostring(current.leaveText),tostring(current.rewardText)
    },"|")
    if force or signature~=lastStateSignature then
        lastStateSignature=signature
        if #report.samples<MAX_SAMPLES then
            report.samples[#report.samples+1]={t=stamp(),why=why,state=current}
        else
            report.counts.dropped+=1
        end
    end
    if not lastPlaying and current.playing then
        local round={
            number=#report.rounds+1,startedAt=stamp(),
            gemsBefore=current.gemBalance,
            maxScore=current.score or 0,maxWave=current.wave or 0,
            maxPoints=current.points or 0,
        }
        report.rounds[#report.rounds+1]=round
        activeRound=round
        event("round_started",{round=round.number,gems=round.gemsBefore})
    elseif lastPlaying and not current.playing then
        if activeRound then
            activeRound.finishedAt=stamp()
            activeRound.gemsAfter=current.gemBalance
            if activeRound.gemsAfter and activeRound.gemsBefore then
                activeRound.gemDelta=activeRound.gemsAfter-activeRound.gemsBefore
            end
            activeRound=nil
        end
        event("round_finished",{gems=current.gemBalance})
    end
    lastPlaying=current.playing
    if activeRound then
        activeRound.maxScore=math.max(activeRound.maxScore or 0,current.score or 0)
        activeRound.maxWave=math.max(activeRound.maxWave or 0,current.wave or 0)
        activeRound.maxPoints=math.max(activeRound.maxPoints or 0,current.points or 0)
        if current.leaveText and current.leaveText~="" then
            activeRound.lastLeaveText=current.leaveText
        end
        if current.pointsText then activeRound.lastPointsText=current.pointsText end
    end
    return current
end
local function unbind()
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
    table.clear(connections)
    local hook=env[hookSlot]
    if type(hook)=="table" and hook.listener then hook.listener=nil end
end
local function hookOutgoing()
    local existing=env[hookSlot]
    local function record(obj,method,...)
        if not running or not arcadeRemote(obj) then return end
        report.counts.outgoing+=1
        local args,n=packedArgs(...)
        event("outgoing",{path=fullPath(obj),method=method,args=args,argc=n})
    end
    if type(existing)=="table" and existing.installed then
        existing.listener=record
        report.outgoingMode="reused pass-through observer"
        return
    end
    if type(hookmetamethod)~="function" or type(getnamecallmethod)~="function" then
        report.outgoingMode="not supported by executor"
        return
    end
    local slot={installed=false,listener=record}
    local prior
    local function observer(obj,...)
        local method=getnamecallmethod()
        if (method=="FireServer" or method=="InvokeServer") and slot.listener then
            pcall(slot.listener,obj,method,...)
        end
        return prior(obj,...)
    end
    local handler=observer
    if type(newcclosure)=="function" then
        local ok,v=pcall(newcclosure,observer)
        if ok and type(v)=="function" then handler=v end
    end
    local ok,original=pcall(hookmetamethod,game,"__namecall",handler)
    if ok and type(original)=="function" then
        prior=original
        slot.installed=true
        env[hookSlot]=slot
        report.outgoingMode="pass-through namecall observer"
    else
        slot.listener=nil
        report.outgoingMode="hook unavailable"
    end
end
local function watchRemotes()
    local arcade=RS:FindFirstChild("Arcade")
    if not arcade then
        event("arcade_folder_missing")
        return
    end
    for _,name in ipairs({"ArcadeSession","ArcadeReport"}) do
        local remote=arcade:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            report.remotes[#report.remotes+1]={
                path=fullPath(remote),class=remote.ClassName,
            }
            connect(remote.OnClientEvent,function(...)
                if not running then return end
                report.counts.incoming+=1
                local args,n=packedArgs(...)
                event("incoming",{path=fullPath(remote),argc=n,args=args})
            end)
        end
    end
end
local function captureConfig()
    local arcade=RS:FindFirstChild("Arcade")
    local module=arcade and arcade:FindFirstChild("ArcadeConfig")
    if not module or not module:IsA("ModuleScript") then return end
    local ok,config=pcall(require,module)
    if not ok or type(config)~="table" then return end
    local rewards=config.Rewards
    if type(rewards)=="table" then
        local keys={"PointsPerKill","PointsPerBoss","PointsPerGem",
            "MaxKillsPerReport","MaxKillsPerWindow","MaxBossesPerWindow",
            "WindowSeconds","KillAllowance","MinSecondsPerBoss"}
        report.configRewards={}
        for _,key in ipairs(keys) do
            report.configRewards[key]=rewards[key]
        end
    end
end

local gui=Instance.new("ScreenGui")
gui.Name="BeyyArcadeTwoRoundTest"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=500
gui.Parent=playerGui
local frame=Instance.new("Frame")
frame.Name="Panel"
frame.Size=UDim2.fromOffset(340,185)
frame.AnchorPoint=Vector2.new(1,1)
frame.Position=UDim2.new(1,-18,1,-22)
frame.BackgroundColor3=Color3.fromRGB(25,29,38)
frame.BorderSizePixel=0
frame.Parent=gui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,9)
corner.Parent=frame
local function makeLabel(name,text,size,y,height,color)
    local v=Instance.new("TextLabel")
    v.Name=name
    v.Size=UDim2.new(1,-20,0,height)
    v.Position=UDim2.fromOffset(10,y)
    v.BackgroundTransparency=1
    v.Font=Enum.Font.Gotham
    v.TextColor3=color or Color3.fromRGB(230,235,244)
    v.TextSize=size
    v.TextWrapped=true
    v.TextXAlignment=Enum.TextXAlignment.Left
    v.TextYAlignment=Enum.TextYAlignment.Center
    v.Text=text
    v.Parent=frame
    return v
end
makeLabel("Heading","ARCADE · 2-ROUND REWARD TEST",15,8,24)
local instruction=makeLabel("Instruction",
    "Start before round 1. Play both rounds normally. Stop after the gem payout.",
    12,34,40,Color3.fromRGB(181,196,212))
local status=makeLabel("Status","READY · Nothing is recording",13,80,28,
    Color3.fromRGB(147,228,174))
local detail=makeLabel("Detail","Captures Arcade UI, gem changes and remote events.",11,
    110,23,Color3.fromRGB(166,181,198))
local function makeButton(name,label,x,width,color)
    local b=Instance.new("TextButton")
    b.Name=name;b.Text=label
    b.Size=UDim2.fromOffset(width,35)
    b.Position=UDim2.fromOffset(x,143)
    b.BackgroundColor3=color
    b.BorderSizePixel=0
    b.TextColor3=Color3.new(1,1,1)
    b.TextSize=12
    b.Font=Enum.Font.GothamBold
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,6);c.Parent=b
    b.Parent=frame
    return b
end
local startButton=makeButton("Start","START RECORDING",10,153,
    Color3.fromRGB(37,137,96))
local stopButton=makeButton("Stop","STOP & EXPORT",176,154,
    Color3.fromRGB(145,76,77))
stopButton.AutoButtonColor=false
stopButton.BackgroundColor3=Color3.fromRGB(68,75,86)

local function updateStatus(current)
    if not running then return end
    current=current or state()
    status.Text=string.format("RECORDING · %.0fs · %d round(s)",stamp(),#report.rounds)
    detail.Text="Gems "..tostring(report.initialGems or "?")
        .." → "..tostring(current.gemBalance or "?")
        .."  |  Score "..tostring(current.score or "?")
        .."  |  Wave "..tostring(current.wave or "?")
end
local function start()
    if disposed or running then return end
    unbind()
    started=os.clock()
    lastStateSignature=""
    lastPlaying=false
    activeRound=nil
    report={
        signature="BEYY_ARCADE_TWO_ROUND_TEST_V1",
        placeId=game.PlaceId,placeVersion=game.PlaceVersion,
        startedUnix=os.time(),
        purpose="Record TWO normal player-controlled Arcade games and the resulting gem reward.",
        limitations={
            "Read-only. Does not send gameplay or reward requests.",
            "Outgoing remote calls require executor namecall support and may miss some call styles.",
            "FireServer success is not server acceptance; rewards are confirmed only by gem balance.",
            "State is sampled periodically, so transient UI values can be missed."
        },
        initialGems=valueOf("SpinUsableGems"),
        outgoingMode="not attempted",configRewards=nil,
        remotes={},events={},samples={},rounds={},
        counts={incoming=0,outgoing=0,dropped=0},
    }
    running=true
    watchRemotes()
    captureConfig()
    hookOutgoing()
    for _,name in ipairs({"ArcadePlaying","SpinUsableGems","Gems"}) do
        connect(LocalPlayer:GetAttributeChangedSignal(name),function()
            if not running then return end
            event("player_attribute",{name=name,value=safe(LocalPlayer:GetAttribute(name))})
            local current=addSample("attribute "..name,true)
            updateStatus(current)
        end)
    end
    local initial=addSample("START",true)
    updateStatus(initial)
    startButton.Text="RECORDING..."
    startButton.AutoButtonColor=false
    startButton.BackgroundColor3=Color3.fromRGB(63,88,85)
    stopButton.AutoButtonColor=true
    stopButton.Text="STOP & EXPORT"
    stopButton.BackgroundColor3=Color3.fromRGB(169,69,69)
    instruction.Text="Play both arcade rounds. Leave the machine normally, then STOP & EXPORT."
    print("[Arcade Two-Round Test] Started. Play 2 rounds. Press STOP & EXPORT after payout.")
    task.spawn(function()
        while running and not disposed do
            local current=addSample("poll",false)
            if os.clock()-lastFrameAt>=0.75 then
                lastFrameAt=os.clock()
                updateStatus(current)
            end
            task.wait(0.20)
        end
    end)
end
local function stop()
    if disposed or not running then return end
    addSample("STOP",true)
    report.endedUnix=os.time()
    report.durationSeconds=stamp()
    report.finalGems=valueOf("SpinUsableGems")
    report.gemDelta=(report.initialGems and report.finalGems)
        and (report.finalGems-report.initialGems) or nil
    if activeRound then
        activeRound.endedByRecorder=true
        activeRound.gemsAfter=report.finalGems
        activeRound.gemDelta=(activeRound.gemsBefore and report.finalGems)
            and (report.finalGems-activeRound.gemsBefore) or nil
    end
    running=false
    unbind()
    local ok,json=pcall(HS.JSONEncode,HS,report)
    if not ok then
        status.Text="ERROR: JSON export failed"
        warn("[Arcade Two-Round Test] JSON export error: "..tostring(json))
        return
    end
    lastJSON=json
    env.BeyyArcadeTwoRoundLastJSON=json
    local folder="BeyyHub"
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder(folder) then
                makefolder(folder)
            end
        end)
    end
    local filename=folder.."/arcade_two_round_test_"..os.date("!%Y%m%d_%H%M%S")..".json"
    local paths={filename,"arcade_two_round_test_latest.json"}
    local saved=false
    if type(writefile)=="function" then
        for _,path in ipairs(paths) do
            local written=pcall(writefile,path,json)
            if written then
                saved=true
                lastFile=path
                if type(readfile)=="function" then
                    local verify,data=pcall(readfile,path)
                    if not verify or data~=json then
                        warn("[Arcade Two-Round Test] Could not verify "..path)
                    end
                end
                if path==filename then break end
            end
        end
    end
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard or nil)
    local copied=clip and pcall(clip,json) or false
    local count=#report.rounds
    status.Text="FINISHED · "..count.." round(s) · gem delta "
        ..(type(report.gemDelta)=="number"
            and string.format("%+d",report.gemDelta) or "?")
    detail.Text=(saved and ("Saved: "..tostring(lastFile))
        or (copied and "JSON copied to clipboard" or "No file/clipboard API"))
    instruction.Text="Attach exported JSON to ChatGPT to compare both rounds and the +1 gem."
    startButton.Text="START NEW TEST"
    startButton.AutoButtonColor=true
    startButton.BackgroundColor3=Color3.fromRGB(37,137,96)
    stopButton.Text="COPY LAST JSON"
    stopButton.BackgroundColor3=Color3.fromRGB(68,100,149)
    print("[Arcade Two-Round Test] EXPORT "..#json.." bytes"
        .." | rounds="..count
        .." | gems "..tostring(report.initialGems).." → "..tostring(report.finalGems)
        .." | delta="..tostring(report.gemDelta)
        .." | saved="..tostring(saved)
        .." | clipboard="..tostring(copied)
        .." | outgoing="..tostring(report.outgoingMode))
    if saved then print("[Arcade Two-Round Test] File: "..tostring(lastFile)) end
end
local function copyLast()
    if type(lastJSON)~="string" then return end
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard or nil)
    local ok=clip and pcall(clip,lastJSON) or false
    detail.Text=ok and "Export JSON copied to clipboard"
        or ("File: "..tostring(lastFile or "unavailable"))
end
uiConnections[#uiConnections+1]=startButton.MouseButton1Click:Connect(function()
    if not running then start() end
end)
uiConnections[#uiConnections+1]=stopButton.MouseButton1Click:Connect(function()
    if running then stop() else copyLast() end
end)
local function destroy()
    if disposed then return end
    if running then stop() end
    disposed=true
    unbind()
    for _,c in ipairs(uiConnections) do pcall(function()c:Disconnect()end)end
    table.clear(uiConnections)
    pcall(function()gui:Destroy()end)
end
env.__BEYY_ARCADE_TWO_ROUND_TEST={Destroy=destroy}
print("[Arcade Two-Round Test] UI loaded. Click START before round 1, STOP after round 2 payout.")
