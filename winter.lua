-- BeyyHub v103.00 | Winter / Christmas event | Yeti King native combat v3
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
local walkEnabled=false
local weakAimEnabled=false
local connections={}
local bossConnections={}
local boss=nil
local eventLog={}
local sentAttacks=0
local observedHealthDrops=0
local playerPitchforkHits=0
local playerTntHits=0
local playerWeakHits=0
local playerDamage=0
local defeated=false
local lastWalkAt=-math.huge
local lastAttackAt=-math.huge
local nextBossScan=0
local lastHealth=nil
local lastWarningAt=-math.huge
local labelStatus=function(_) end
local labelTelemetry=function(_) end
local labelToggle=function(_) end
local labelWalk=function(_) end
local labelWeak=function(_) end

local function safeValue(v, depth, seen)
    local kind=typeof(v)
    depth=depth or 0
    if kind=="Instance" then return {type=v.ClassName,path=v:GetFullName()} end
    if kind=="Vector3" or kind=="CFrame" or kind=="Color3" or kind=="BrickColor" then
        return tostring(v)
    end
    if kind=="nil" then return "<nil>" end
    if kind=="string" then return string.sub(v,1,250) end
    if kind=="number" or kind=="boolean" then return v end
    if kind=="table" then
        if depth>=3 then return "<nested table>" end
        seen=seen or {}
        if seen[v] then return "<cycle>" end
        seen[v]=true
        local result={}
        local count=0
        for key,inner in pairs(v) do
            if count>=24 then result.__truncated=true; break end
            local label=tostring(key)
            if #label<=90 then
                result[label]=safeValue(inner,depth+1,seen)
                count+=1
            end
        end
        seen[v]=nil
        return result
    end
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
    if #eventLog>850 then table.remove(eventLog,1) end
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
        local packed=table.pack(...)
        local args={}
        for i=1,math.min(packed.n,12) do args[i]=safeValue(packed[i]) end
        logEvent("remote.in."..label,{args=args,count=packed.n})
        if label=="WinterBoss.Fight" then
            if packed[1]=="BossHp" and tonumber(packed[4])==player.UserId then
                local damage=tonumber(packed[5]) or 0
                local tool=tostring(packed[8] or "Unknown")
                playerDamage+=math.max(0,damage)
                if tool=="Pitchfork" then playerPitchforkHits+=1 end
                if tool=="TNT" then playerTntHits+=1 end
                if packed[7]=="WEAK SPOT!" then playerWeakHits+=1 end
                logEvent("boss.damage.confirmed",{amount=damage,tool=tool,
                    weak=packed[7]=="WEAK SPOT!",health=tonumber(packed[2])})
            elseif packed[1]=="End" then
                defeated=true
                attackEnabled=false
                labelToggle(false)
                status("Yeti King defeated; server ending event received")
                logEvent("boss.end",safeValue(packed[2]))
            end
        end
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
        for _,name in ipairs({"PitchforkDug","TntAction","TntExploded","IcicleShatter","NeedleRoundCompleted"}) do
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
-- Yeti visible geometry is stored in ReplicatedStorage.WinterBoss.Yeti.
-- The live combat model exposes RootPart/BossHitbox but not named weak-point
-- parts. We only project template geometry into the live rig on explicit opt-in.
local visualAliases={
    RightArm={"Bone_ArmR","UpperArmR","ForearmR"},
    LeftArm={"Bone_ArmL","UpperArmL","ForearmL"},
    RightShoulder={"ShoulderR","Bone_ArmR"},
    LeftShoulder={"ShoulderL","Bone_ArmL"},
    Back={"Hump","BackCrystalR1","BackCrystalL1"},
    DizzyHead={"Bone_Head","Skull","Face"},
    Head={"Bone_Head","Skull"},
}
local function aimPoint(hitbox, head)
    local origin=head.Position
    local fallback=hitbox.Position
    local ok,surface=pcall(function() return hitbox:GetClosestPointOnSurface(origin) end)
    if ok and typeof(surface)=="Vector3" then fallback=surface end
    local name=boss and boss:GetAttribute("BossWeakPoint")
    if not weakAimEnabled or type(name)~="string" or not visualAliases[name] then
        return fallback,"boss hitbox"
    end
    local root=boss and boss:FindFirstChild("RootPart")
    local folder=RS:FindFirstChild("WinterBoss")
    local template=folder and folder:FindFirstChild("Yeti")
    local templateRoot=template and template:FindFirstChild("RootPart")
    if root and root:IsA("BasePart") and templateRoot and templateRoot:IsA("BasePart") then
        for _,partName in ipairs(visualAliases[name]) do
            local visual=template:FindFirstChild(partName,true)
            if visual and visual:IsA("BasePart") then
                local projected=root.CFrame:PointToWorldSpace(
                    templateRoot.CFrame:PointToObjectSpace(visual.Position))
                if (projected-root.Position).Magnitude<=35 then
                    return projected,"visual template "..partName
                end
            end
        end
    end
    return fallback,"boss hitbox (weak-point geometry unavailable)"
end
local function maybeWalkTo(point,head,reach)
    if not walkEnabled then return false end
    if os.clock()-lastWalkAt<0.65 then return true end
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    local humanoid=c and c:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health<=0 then return false end
    lastWalkAt=os.clock()
    -- Ground-level MoveTo only; no teleporting, flying or CFrame manipulation.
    local delta=Vector3.new(point.X-root.Position.X,0,point.Z-root.Position.Z)
    if delta.Magnitude<0.45 then
        humanoid:MoveTo(root.Position)
        return true
    end
    local destination=root.Position+delta.Unit*math.max(0,delta.Magnitude-reach*0.70)
    humanoid:MoveTo(destination)
    logEvent("boss.walk",{range=reach,groundDistance=delta.Magnitude,
        destination=tostring(destination)})
    return true
end
local function blocked()
    for _,key in ipairs({"CutsceneActive","NeedleInputLocked","BossHeld",
        "BossRagdolled","BossRagdollRecovering","BossKnockdownCamera","BossGrabbed"}) do
        if player:GetAttribute(key)==true then return key end
    end
    return nil
end
local function attackTick()
    if not attackEnabled then return end
    if player:GetAttribute("InWinterBoss")~=true then
        status("Waiting for the Yeti King encounter");return
    end
    if not boss or not boss.Parent then
        status(defeated and "Yeti defeated" or "YetiKing not replicated");return
    end
    local state=tostring(boss:GetAttribute("BossState") or "")
    local hp=tonumber(boss:GetAttribute("BossHealth"))
    if state=="Defeated" or (hp and hp<=0) then
        defeated=true
        attackEnabled=false
        labelToggle(false)
        status("Yeti defeated (health zero)")
        return
    end
    if state~="Fighting" then
        status("Waiting for verified combat state: "..state);return
    end
    if not hp then status("Waiting for BossHealth");return end
    local lock=blocked()
    if lock then status("Waiting for "..lock.." to clear");return end
    if boss:GetAttribute("BossShielded")==true or boss:GetAttribute("BossHidden")==true
        or boss:GetAttribute("BossVulnerable")==false then
        status("Waiting for Yeti shield / vulnerable phase");return
    end
    if player:GetAttribute("PitchforkOwned")~=true then
        status("Pitchfork not owned");return
    end
    local remote=nativePitchfork()
    if not remote then status("NeedleHaystack.PitchforkDig unavailable");return end
    local head=headAndHumanoid()
    local hitbox=boss:FindFirstChild("BossHitbox") or boss:FindFirstChild("RootPart")
    if not head or not hitbox or not hitbox:IsA("BasePart") then
        status("Missing character head / Yeti BossHitbox");return
    end
    local point,source=aimPoint(hitbox,head)
    local offset=point-head.Position
    local reach=math.max(0.1,tonumber(player:GetAttribute("PitchforkReach")) or 4.2)
    if offset.Magnitude>reach then
        if maybeWalkTo(point,head,reach) then
            status(string.format("Walking toward Yeti (%s; %.1f / %.1f studs)",
                source,offset.Magnitude,reach))
        else
            status(string.format("Move closer (%s; %.1f / %.1f studs)",
                source,offset.Magnitude,reach))
        end
        return
    end
    if offset.Magnitude<0.01 then return end
    if sentAttacks>=12 and playerPitchforkHits==0 then
        attackEnabled=false
        labelToggle(false)
        status("Paused: 12 requests without player-attributed pitchfork damage")
        logEvent("attack.paused","No attributable Pitchfork BossHp feedback after 12 sends")
        return
    end
    local t=os.clock()
    local interval=math.max(0.1,tonumber(player:GetAttribute("PitchforkCooldown")) or 0.85)
    if t-lastAttackAt<interval then return end
    lastAttackAt=t
    local success,err=pcall(function()
        remote:FireServer("Boss",head.Position,offset.Unit)
    end)
    logEvent("remote.out.PitchforkDig",{
        success=success,bossState=state,shielded=boss:GetAttribute("BossShielded"),
        bossHealth=hp,reach=reach,distance=offset.Magnitude,
        weakSpot=safeValue(boss:GetAttribute("BossWeakPoint")),targetSource=source,
        error=not success and tostring(err) or nil,
    })
    if success then
        sentAttacks+=1
        status(string.format("Pitchfork %d requests / %d server-confirmed hits; target=%s",
            sentAttacks,playerPitchforkHits,source))
    else
        status("Pitchfork request failed: "..tostring(err))
    end
end

local function scan()
    local report={
        marker="BEYY_WINTER_SCAN_V3",timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        placeId=game.PlaceId, bossAttackMode="confirmed native PitchforkDig",
        bossPitchforkAttempts=sentAttacks,bossHealthDecreases=observedHealthDrops,
        playerPitchforkConfirmed=playerPitchforkHits,playerTntConfirmed=playerTntHits,
        playerWeakSpotConfirmed=playerWeakHits,playerAttributedDamage=playerDamage,
        bossDefeated=defeated,walkEnabled=walkEnabled,weakAimEnabled=weakAimEnabled,
        playerState={InWinterBoss=player:GetAttribute("InWinterBoss"),
            NeedleInputLocked=player:GetAttribute("NeedleInputLocked"),
            CutsceneActive=player:GetAttribute("CutsceneActive"),
            PitchforkOwned=player:GetAttribute("PitchforkOwned"),
            PitchforkCooldown=player:GetAttribute("PitchforkCooldown"),
            PitchforkReach=player:GetAttribute("PitchforkReach"),
            TntOwned=player:GetAttribute("TntOwned"),
            TntCooldown=player:GetAttribute("TntCooldown")},
        boss=nil,remotes={},winterObjects={},eventLog=eventLog,guiHints={},
        winterConfig=nil,
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
    local config=folder and folder:FindFirstChild("Config")
    if config and config:IsA("ModuleScript") then
        local ok,data=pcall(require,config)
        if ok then report.winterConfig=safeValue(data) 
        else report.winterConfig="<Config require failed: "..tostring(data):sub(1,120)..">" end
    end
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
        saved=pcall(writefile,"BeyyHub/winter_map_capture_v3.json",json)
    end
    status("Scan "..(copied and "copied" or "clipboard unavailable")
        .." / "..(saved and "saved as winter_map_capture_v3.json" or "file not saved"))
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
panel.Size=UDim2.fromOffset(398,438)
panel.Position=UDim2.new(0.5,-199,0.4,-219)
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
txt("Yeti King • Confirmed native combat • Experimental targeting",38,24,12)
local bossLabel=txt("Waiting for Workspace.YetiKing",67,52,12,Color3.fromRGB(194,214,234))
local toggle=button("Auto Yeti Pitchfork: OFF",125,42)
labelToggle=function(checked)
    toggle.Text="Auto Yeti Pitchfork: "..(checked and "ON" or "OFF")
    toggle.BackgroundColor3=checked and Color3.fromRGB(37,88,79)
        or Color3.fromRGB(48,58,80)
end
connections[#connections+1]=toggle.MouseButton1Click:Connect(function()
    attackEnabled=not attackEnabled
    if attackEnabled then
        sentAttacks=0
        -- Each toggle begins a fresh attempt window; confirmations are read
        -- from native BossHp feedback for this player, not from global HP alone.
        playerPitchforkHits=0
        lastAttackAt=-math.huge
        logEvent("attack.enabled","user enabled server-confirmed native pitchfork protocol")
    end
    labelToggle(attackEnabled)
    status(attackEnabled and "Native PitchforkDig on active, unshielded Yeti within real reach"
        or "Auto Yeti Pitchfork disabled")
end)
local walkToggle=button("Auto Approach by Walking: OFF",173,38)
labelWalk=function(v) walkToggle.Text="Auto Approach by Walking: "..(v and "ON" or "OFF") end
connections[#connections+1]=walkToggle.MouseButton1Click:Connect(function()
    walkEnabled=not walkEnabled
    labelWalk(walkEnabled)
    status(walkEnabled and "Will use Humanoid:MoveTo when out of range" or "Walking approach disabled")
end)
local weakToggle=button("Try Model-Based Weak Spot Aim: OFF",216,38)
labelWeak=function(v) weakToggle.Text="Try Model-Based Weak Spot Aim: "..(v and "ON" or "OFF") end
connections[#connections+1]=weakToggle.MouseButton1Click:Connect(function()
    weakAimEnabled=not weakAimEnabled
    labelWeak(weakAimEnabled)
    status(weakAimEnabled and "Using mapped visual Yeti bones when possible" or "Using proven boss-hitbox aim")
end)
local actionStatus=txt("Winter Boss: automatic pitchfork confirmed. Winter Fight/Throw remote args are unverified.",263,55,12,Color3.fromRGB(176,197,226))
labelStatus=function(s) actionStatus.Text=s end
local statsLabel=txt("Local hits: 0 • Weak spots: 0 • Damage: 0",327,28,12,Color3.fromRGB(194,214,234))
local scanButton=button("Copy / Save Winter Combat Scan V3",360,39)
scanButton.BackgroundColor3=Color3.fromRGB(53,81,130)
connections[#connections+1]=scanButton.MouseButton1Click:Connect(copyScan)
txt("RightControl: show/hide • Walk/weak-spot options start OFF",407,26,11)
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
        statsLabel.Text=string.format("Local hits %d | Weak %d | TNT %d | Damage %d",
            playerPitchforkHits,playerWeakHits,playerTntHits,playerDamage)
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
            bossLabel.Text=defeated and "Yeti King defeated — ending observed"
                or "Waiting for Workspace.YetiKing"
        end
    end
end)
print("[BeyyHub Winter] v3 confirmed pitchfork combat, optional walking/weak-spot geometry, detailed WinterBoss telemetry and scan loaded")
