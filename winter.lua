-- BeyyHub v103.00 | Winter / Christmas event | Yeti King compatibility v2
local __BEYY_MODULE = "Winter"
local __BEYY_SCRIPT_VERSION = "103.00"
if game.PlaceId ~= 87963815262778 then
    warn("[BeyyHub Winter] Expected Christmas! place 87963815262778, got "..tostring(game.PlaceId))
    return
end

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")
local HS=game:GetService("HttpService")
local player=Players.LocalPlayer
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.BeyyWinterStop)=="function" then pcall(env.BeyyWinterStop) end

-- Confirmed in the November 14 winter capture:
-- Workspace.YetiKing (RootPart, BossHitbox)
-- BossHealth, BossState, BossPhase, BossShielded, BossDizzy, BossStagger
-- ReplicatedStorage.WinterBoss.Remotes: Fight, Throw, Lobby, ToolFeedback
-- The outgoing WinterBoss remote argument formats are NOT known. Never guess
-- them or treat this as a finished automatic winter boss controller.
local alive=true
local attackEnabled=false
local connections={}
local bossConnections={}
local boss=nil
local eventLog={}
local sentAttacks=0
local observedHealthDrops=0
local missedWindows=0
local lastAttackAt=-math.huge
local nextBossScan=0
local lastHealth=nil
local lastWarningAt=-math.huge
local labelStatus=function(_) end
local labelTelemetry=function(_) end
local labelToggle=function(_) end

local function safeValue(v)
    local kind=typeof(v)
    if kind=="Instance" then return {type=v.ClassName,path=v:GetFullName()} end
    if kind=="Vector3" or kind=="CFrame" or kind=="Color3" or kind=="BrickColor" then
        return tostring(v)
    end
    if kind=="string" then return string.sub(v,1,250) end
    if kind=="number" or kind=="boolean" or kind=="nil" then return v end
    return tostring(v):sub(1,250)
end
local function attrValues(obj)
    local result={}
    if not obj then return result end
    for key,value in pairs(obj:GetAttributes()) do
        if type(key)=="string" and #key<90 then
            result[key]=safeValue(value)
        end
    end
    return result
end
local function logEvent(kind,detail)
    local event={t=math.round(os.clock()*1000)/1000,kind=kind,detail=detail}
    eventLog[#eventLog+1]=event
    if #eventLog>180 then table.remove(eventLog,1) end
end
local lastStatus=""
local function status(s)
    labelStatus(s)
    if s~=lastStatus then
        lastStatus=s
        if os.clock()-lastWarningAt>1 then
            print("[BeyyHub Winter] "..s)
            lastWarningAt=os.clock()
        end
    end
end
local function winterRemotes()
    local folder=RS:FindFirstChild("WinterBoss")
    return folder and folder:FindFirstChild("Remotes")
end
local function nativePitchfork()
    local folder=RS:FindFirstChild("NeedleHaystack")
    local r=folder and folder:FindFirstChild("PitchforkDig")
    return r and r:IsA("RemoteEvent") and r or nil
end
local function findBoss()
    local target=WS:FindFirstChild("YetiKing")
    if target and target:IsA("Model") then return target end
    target=WS:FindFirstChild("YetiKing",true)
    return target and target:IsA("Model") and target or nil
end
local function clearBossConnections()
    for _,c in ipairs(bossConnections) do pcall(function() c:Disconnect() end) end
    table.clear(bossConnections)
end
local bossKeys={
    "BossState","BossPhase","BossHealth","BossMaxHealth","BossShielded",
    "BossDizzy","BossWeakPointDizzy","BossStagger","BossWeakPoint",
    "BossVulnerable","BossHidden","BossWeakPointEndsAt",
}
local function bindBoss(target)
    if target==boss then return end
    clearBossConnections()
    boss=target
    lastHealth=boss and tonumber(boss:GetAttribute("BossHealth")) or nil
    logEvent("boss",boss and ("found "..boss:GetFullName()) or "missing")
    if not boss then return end
    for _,key in ipairs(bossKeys) do
        local attribute=key
        bossConnections[#bossConnections+1]=boss:GetAttributeChangedSignal(attribute):Connect(function()
            if not alive or not boss then return end
            local value=boss:GetAttribute(attribute)
            logEvent("boss."..attribute,safeValue(value))
            if attribute=="BossHealth" then
                local number=tonumber(value)
                if number and lastHealth and number<lastHealth then
                    observedHealthDrops+=1
                end
                lastHealth=number
            end
        end)
    end
end
local function listenIncoming(remote,label)
    if not remote or not remote:IsA("RemoteEvent") then return end
    connections[#connections+1]=remote.OnClientEvent:Connect(function(...)
        if not alive then return end
        local args={}
        local packed=table.pack(...)
        for i=1,math.min(packed.n,8) do args[i]=safeValue(packed[i]) end
        logEvent("remote.in."..label,{args=args,count=packed.n})
    end)
    logEvent("remote.bound",label)
end
local function listenWinterRemotes()
    local remoteFolder=winterRemotes()
    if remoteFolder then
        for _,name in ipairs({"Fight","Throw","Lobby","ToolFeedback"}) do
            listenIncoming(remoteFolder:FindFirstChild(name),"WinterBoss."..name)
        end
    end
    local needle=RS:FindFirstChild("NeedleHaystack")
    if needle then
        for _,name in ipairs({"PitchforkDug","TntExploded","IcicleShatter","NeedleRoundCompleted"}) do
            listenIncoming(needle:FindFirstChild(name),"NeedleHaystack."..name)
        end
    end
end
listenWinterRemotes()

local excluded={
    Sleeping=true,Intro=true,Rising=true,Falling=true,
    Returning=true,Unavailable=true,Defeated=true,PhaseTransition=true,
}
local function headAndHumanoid()
    local c=player.Character
    if not c then return nil end
    local humanoid=c:FindFirstChildOfClass("Humanoid")
    local head=c:FindFirstChild("Head")
    if not humanoid or humanoid.Health<=0 then return nil end
    return head
end
local function attackTick()
    if not attackEnabled then return end
    if player:GetAttribute("InWinterBoss")~=true then
        status("Waiting for the Yeti King encounter");return
    end
    if not boss or not boss.Parent then
        status("YetiKing not replicated");return
    end
    local state=tostring(boss:GetAttribute("BossState") or "")
    local hp=tonumber(boss:GetAttribute("BossHealth"))
    if excluded[state] or not hp or hp<=0 then
        status("Waiting: Yeti King "..state);return
    end
    if player:GetAttribute("CutsceneActive")==true
        or player:GetAttribute("NeedleInputLocked")==true
        or player:GetAttribute("BossHeld")==true
        or player:GetAttribute("BossRagdolled")==true then
        status("Waiting for cutscene / input lock");return
    end
    if boss:GetAttribute("BossShielded")==true or boss:GetAttribute("BossHidden")==true
        or boss:GetAttribute("BossVulnerable")==false then
        status("Waiting for Yeti shield / vulnerable phase");return
    end
    if player:GetAttribute("PitchforkOwned")~=true then
        status("Pitchfork not owned");return
    end
    local remote=nativePitchfork()
    if not remote then
        status("NeedleHaystack.PitchforkDig unavailable");return
    end
    local head=headAndHumanoid()
    local hitbox=boss:FindFirstChild("BossHitbox") or boss:FindFirstChild("RootPart")
    if not head or not hitbox or not hitbox:IsA("BasePart") then
        status("Missing head / Yeti BossHitbox");return
    end
    local point=hitbox.Position
    local ok,closest=pcall(function()return hitbox:GetClosestPointOnSurface(head.Position) end)
    if ok and typeof(closest)=="Vector3" then point=closest end
    local offset=point-head.Position
    local reach=tonumber(player:GetAttribute("PitchforkReach")) or 4.2
    -- Unlike the older winter draft, never increase the actual reach to 13.
    reach=math.max(0.1,reach)
    if offset.Magnitude>reach then
        status(string.format("Move closer: Yeti %.1f / %.1f studs",offset.Magnitude,reach))
        return
    end
    if offset.Magnitude<0.01 then return end
    if sentAttacks>=6 and observedHealthDrops==0 then
        attackEnabled=false
        labelToggle(false)
        status("Paused after 6 requests without damage; export active scan")
        logEvent("attack.paused","no server-observed BossHealth decrease after six attempts")
        return
    end
    local t=os.clock()
    local interval=math.max(0.1,tonumber(player:GetAttribute("PitchforkCooldown")) or 0.85)
    if t-lastAttackAt<interval then return end
    lastAttackAt=t
    -- Experimental hypothesis based on the other five chapter maps ONLY.
    -- Never call unverified WinterBoss.Fight / Throw / Lobby.
    local success,err=pcall(function()
        remote:FireServer("Boss",head.Position,offset.Unit)
    end)
    logEvent("remote.out.PitchforkDig",{
        success=success,bossState=state,shielded=boss:GetAttribute("BossShielded"),
        bossHealth=hp,reach=reach,distance=offset.Magnitude,
        error=not success and tostring(err) or nil,
    })
    if success then
        sentAttacks+=1
        status("Testing native pitchfork vs Yeti; request #"..tostring(sentAttacks))
    else
        status("Native pitchfork send failed: "..tostring(err))
    end
end

local function scan()
    local report={
        marker="BEYY_WINTER_SCAN_V2",timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        placeId=game.PlaceId, bossAttackMode="experimental",
        bossPitchforkAttempts=sentAttacks,bossHealthDecreases=observedHealthDrops,
        playerState={InWinterBoss=player:GetAttribute("InWinterBoss"),
            NeedleInputLocked=player:GetAttribute("NeedleInputLocked"),
            CutsceneActive=player:GetAttribute("CutsceneActive"),
            PitchforkOwned=player:GetAttribute("PitchforkOwned"),
            PitchforkCooldown=player:GetAttribute("PitchforkCooldown"),
            PitchforkReach=player:GetAttribute("PitchforkReach"),
            TntOwned=player:GetAttribute("TntOwned"),
            TntCooldown=player:GetAttribute("TntCooldown")},
        boss=nil,remotes={},winterObjects={},eventLog=eventLog,guiHints={},
    }
    local b=findBoss()
    if b then
        local parts={}
        for _,part in ipairs(b:GetDescendants()) do
            if part:IsA("BasePart") and #parts<80 then
                parts[#parts+1]={name=part.Name,path=part:GetFullName(),
                    position=tostring(part.Position),size=tostring(part.Size)}
            end
        end
        report.boss={path=b:GetFullName(),attributes=attrValues(b),parts=parts}
    end
    local folder=RS:FindFirstChild("WinterBoss")
    if folder then
        for _,node in ipairs(folder:GetDescendants()) do
            if #report.winterObjects>=140 then break end
            report.winterObjects[#report.winterObjects+1]=node:GetFullName().." ["..node.ClassName.."]"
        end
    end
    local rootRemotes=RS:FindFirstChild("NeedleHaystack")
    for _,item in ipairs({folder,rootRemotes}) do
        if item then
            for _,node in ipairs(item:GetDescendants()) do
                if (node:IsA("RemoteEvent") or node:IsA("RemoteFunction"))
                    and #report.remotes<100 then
                    report.remotes[#report.remotes+1]=node:GetFullName().." ["..node.ClassName.."]"
                end
            end
        end
    end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _,node in ipairs(pg:GetDescendants()) do
            if (node:IsA("TextLabel") or node:IsA("TextButton"))
                and type(node.Text)=="string" then
                local lower=node.Text:lower()
                if lower:find("yeti",1,true) or lower:find("winter",1,true)
                    or lower:find("throw",1,true) or lower:find("shield",1,true)
                    or lower:find("frost",1,true) then
                    if #report.guiHints>=60 then break end
                    report.guiHints[#report.guiHints+1]=node:GetFullName().." = "..node.Text:sub(1,160)
                end
            end
        end
    end
    return HS:JSONEncode(report)
end
local function copyScan()
    local ok,json=pcall(scan)
    if not ok then status("Winter scan failed: "..tostring(json));return end
    env.BeyyWinterLastScan=json
    local copied,saved=false,false
    if type(setclipboard)=="function" then copied=pcall(setclipboard,json) end
    if type(writefile)=="function" then
        pcall(function()
            if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder("BeyyHub")) then
                makefolder("BeyyHub")
            end
        end)
        saved=pcall(writefile,"BeyyHub/winter_map_capture_v2.json",json)
    end
    status("Scan "..(copied and "copied" or "clipboard unavailable")
        .." / "..(saved and "saved as winter_map_capture_v2.json" or "file not saved"))
end

-- Small standalone menu, intentionally isolated from all other chapters.
local ok,parent=pcall(function()
    if type(gethui)=="function" then return gethui() end
    return game:GetService("CoreGui")
end)
if not ok or not parent then parent=player:WaitForChild("PlayerGui") end
local ui=Instance.new("ScreenGui")
ui.Name="BeyyHubWinter"
ui.ResetOnSpawn=false
ui.IgnoreGuiInset=true
ui.Parent=parent
local panel=Instance.new("Frame")
panel.Name="WinterPanel"
panel.Size=UDim2.fromOffset(398,328)
panel.Position=UDim2.new(0.5,-199,0.4,-164)
panel.BorderSizePixel=0
panel.BackgroundColor3=Color3.fromRGB(20,23,33)
panel.Parent=ui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,12)
corner.Parent=panel
local border=Instance.new("UIStroke")
border.Color=Color3.fromRGB(64,79,114)
border.Transparency=0.30
border.Parent=panel
local function txt(text,y,h,size,color)
    local t=Instance.new("TextLabel")
    t.Size=UDim2.new(1,-32,0,h)
    t.Position=UDim2.fromOffset(16,y)
    t.BackgroundTransparency=1
    t.Text=text
    t.TextSize=size or 13
    t.TextColor3=color or Color3.fromRGB(235,241,255)
    t.Font=(size or 13)>=16 and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextWrapped=true
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.Parent=panel
    return t
end
local function button(text,y,h)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,-32,0,h)
    b.Position=UDim2.fromOffset(16,y)
    b.BackgroundColor3=Color3.fromRGB(48,58,80)
    b.TextColor3=Color3.fromRGB(241,247,255)
    b.Font=Enum.Font.GothamBold
    b.TextSize=12
    b.Text=text
    b.Parent=panel
    local round=Instance.new("UICorner")
    round.CornerRadius=UDim.new(0,8)
    round.Parent=b
    return b
end
txt("BeyyHub  •  WINTER EVENT",10,28,17)
txt("Yeti King • Phase-aware monitor • Native protocol test",38,24,12)
local bossLabel=txt("Waiting for Workspace.YetiKing",67,45,12,Color3.fromRGB(194,214,234))
local toggle=button("Experimental Yeti Pitchfork: OFF",124,42)
labelToggle=function(checked)
    toggle.Text="Experimental Yeti Pitchfork: "..(checked and "ON" or "OFF")
    toggle.BackgroundColor3=checked and Color3.fromRGB(37,88,79)
        or Color3.fromRGB(48,58,80)
end
connections[#connections+1]=toggle.MouseButton1Click:Connect(function()
    attackEnabled=not attackEnabled
    if attackEnabled then
        sentAttacks=0
        observedHealthDrops=0
        lastAttackAt=-math.huge
        logEvent("attack.enabled","user enabled experimental pitchfork")
    end
    labelToggle(attackEnabled)
    status(attackEnabled and "Testing only when Yeti is active, unshielded and within reach"
        or "Experimental attack disabled")
end)
local actionStatus=txt("The WinterBoss remote arguments are not yet verified.",176,60,12,Color3.fromRGB(176,197,226))
labelStatus=function(s) actionStatus.Text=s end
local scanButton=button("Copy / Save Active Winter Boss Scan",243,39)
scanButton.BackgroundColor3=Color3.fromRGB(53,81,130)
connections[#connections+1]=scanButton.MouseButton1Click:Connect(copyScan)
txt("RightControl: show/hide   •   Fight / Throw / Lobby are observation-only",291,25,11)
local function stop()
    if not alive then return end
    alive=false
    attackEnabled=false
    clearBossConnections()
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(function()ui:Destroy() end)
    if env.BeyyWinterStop==stop then env.BeyyWinterStop=nil end
end
env.BeyyWinterStop=stop
connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
    end
end)
local dragging,dragStart,initial=false,nil,nil
connections[#connections+1]=panel.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragStart=input.Position
        initial=panel.Position
    end
end)
connections[#connections+1]=UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
connections[#connections+1]=UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local d=input.Position-dragStart
        panel.Position=UDim2.new(initial.X.Scale,initial.X.Offset+d.X,
            initial.Y.Scale,initial.Y.Offset+d.Y)
    end
end)

task.spawn(function()
    while alive do
        task.wait(0.15)
        if os.clock()>=nextBossScan then
            nextBossScan=os.clock()+1
            bindBoss(findBoss())
        end
        local ok,err=pcall(attackTick)
        if not ok then logEvent("error.attack",tostring(err));status(tostring(err)) end
    end
end)
task.spawn(function()
    while alive do
        task.wait(0.6)
        if boss then
            bossLabel.Text=string.format("Yeti King | HP %s/%s | Phase %s | %s\nShielded %s • Dizzy %s • Stagger %s",
                tostring(boss:GetAttribute("BossHealth")),
                tostring(boss:GetAttribute("BossMaxHealth")),
                tostring(boss:GetAttribute("BossPhase")),
                tostring(boss:GetAttribute("BossState")),
                tostring(boss:GetAttribute("BossShielded")),
                tostring(boss:GetAttribute("BossDizzy")),
                tostring(boss:GetAttribute("BossStagger")))
        else
            bossLabel.Text="Waiting for Workspace.YetiKing"
        end
    end
end)
print("[BeyyHub Winter] v2 YetiKing detection, WinterBoss remote telemetry, shield-aware experimental native pitchfork and active-scan export loaded")
