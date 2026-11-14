-- BeyyHub v103.00 | Winter / Christmas event | Yeti King Main Hub v4.2 cutscene and combat gate repair
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
local isMenuOpen=function() return false end
local connections={}
local bossConnections={}
local boss=nil
local eventLog={}
local sentAttacks=0
local observedHealthDrops=0
local playerPitchforkHits=0
local playerTntHits=0
local playerVacuumHits=0
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
    if boss and boss:GetAttribute("BossState")~="Defeated"
        and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0 then defeated=false end
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
                if tool=="Vacuum" then playerVacuumHits+=1 end
                if packed[7]=="WEAK SPOT!" then playerWeakHits+=1 end
                logEvent("boss.damage.confirmed",{amount=damage,tool=tool,
                    weak=packed[7]=="WEAK SPOT!",health=tonumber(packed[2])})
            elseif packed[1]=="End" then
                defeated=true
                attackEnabled=false
                labelToggle(false,"boss")
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
-- Capture lock transitions: end-of-fight scans showed these flags enabled,
-- but they may have been clear during active combat.
for _,key in ipairs({"InWinterBoss","NeedleInputLocked","CutsceneActive",
    "BossHeld","BossRagdolled","BossRagdollRecovering","BossGrabbed"}) do
    local attr=key
    connections[#connections+1]=player:GetAttributeChangedSignal(attr):Connect(function()
        if alive then logEvent("player."..attr,safeValue(player:GetAttribute(attr))) end
    end)
end

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
    -- Winter replicates CutsceneActive/NeedleInputLocked even during a full
    -- server-verified Fighting phase. Never use those stale flags to suppress
    -- confirmed Yeti combat. All actual stun/ragdoll/grab gates still apply.
    local fighting=boss and boss.Parent
        and boss:GetAttribute("BossState")=="Fighting"
        and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0
        and player:GetAttribute("InWinterBoss")==true
    if not fighting then
        if player:GetAttribute("CutsceneActive")==true then return "CutsceneActive" end
        if player:GetAttribute("NeedleInputLocked")==true then return "NeedleInputLocked" end
    end
    for _,key in ipairs({"BossHeld","BossRagdolled","BossRagdollRecovering",
        "BossKnockdownCamera","BossGrabbed"}) do
        if player:GetAttribute(key)==true then return key end
    end
    local char=player.Character
    local human=char and char:FindFirstChildOfClass("Humanoid")
    if not human or human.Health<=0 then return "Character incapacitated" end
    return nil
end
local function attackTick()
    if not attackEnabled or isMenuOpen() then return end
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
        labelToggle(false,"boss")
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
    if offset.Magnitude>reach and source:find("visual template",1,true) then
        -- Prioritize reaching the exposed spot while its replicated timer is live.
        local ends=tonumber(boss:GetAttribute("BossWeakPointEndsAt"))
        local stillOpen=ends and (ends-WS:GetServerTimeNow())>0.45
        if stillOpen and walkEnabled and offset.Magnitude<25 then
            maybeWalkTo(point,head,reach)
            status(string.format("Approaching critical %s (%.1f studs)",source,offset.Magnitude))
            return
        end
        -- If the spot cannot be reached in time, keep native body DPS alive.
        local ok,near=pcall(function() return hitbox:GetClosestPointOnSurface(head.Position) end)
        if ok and typeof(near)=="Vector3" and (near-head.Position).Magnitude<=reach then
            point=near
            offset=point-head.Position
            source="hitbox fallback (weak spot not reachable)"
        end
    end
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
        labelToggle(false,"pitchfork")
        status("Paused pitchfork: 12 requests without player-attributed damage")
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
        marker="BEYY_WINTER_SCAN_V4",timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        placeId=game.PlaceId, bossAttackMode="confirmed native PitchforkDig",
        bossPitchforkAttempts=sentAttacks,bossHealthDecreases=observedHealthDrops,
        playerPitchforkConfirmed=playerPitchforkHits,playerTntConfirmed=playerTntHits,
        playerVacuumConfirmed=playerVacuumHits,
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
        saved=pcall(writefile,"BeyyHub/winter_map_capture_v4.json",json)
    end
    status("Scan "..(copied and "copied" or "clipboard unavailable")
        .." / "..(saved and "saved as winter_map_capture_v4.json" or "file not saved"))
end


-- Native BeyyHub main UI, reused verbatim from the Chapter 4 module.
-- Winter-specific controllers below keep all non-winter chapters untouched.
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
        if self.Window and not self.Window.Destroyed then
            local text=tostring(options.Title or "Beyy")..": "..tostring(options.Content or "")
            if self.Window.Notice.Text~=text then self.Window.Notice.Text=text end
        end
    end
    function UI:CreateWindow(options)
        local w={Closed=false,Destroyed=false,Connections={},Tabs={},ToggleKey=Enum.KeyCode.RightControl}
        self.Window=w
        local parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        if type(gethui)=="function" then local ok,value=pcall(gethui); if ok and value then parent=value end end
        -- Recover from a partially failed previous load that left an old menu.
        local stale=parent:FindFirstChild("BeyyNativeHub")
        if stale then pcall(function()stale:Destroy()end) end
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
        -- Keep an independent, always-accessible recovery button. Closing the
        -- panel never disables the whole ScreenGui, so a swallowed Ctrl press
        -- cannot strand the user without mouse access.
        local reopen=button(gui,"OPEN BEYYHUB  •  RIGHT CTRL",
            UDim2.fromOffset(200,34),UDim2.new(0,12,0,12))
        reopen.ZIndex=100
        reopen.Visible=false
        local bind="BeyyWinterCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
        local cursorBound=false
        local cursorFallback=nil
        local cursorWatchdog=nil
        local function forceCursor()
            if w.Destroyed or w.Closed then return end
            pcall(function()
                input.MouseBehavior=Enum.MouseBehavior.Default
                input.MouseIconEnabled=true
            end)
        end
        local function releaseCursor()
            forceCursor() -- immediate, rather than waiting for a render frame
            if cursorBound or cursorFallback then return end
            -- A previous crashed module can leave an old named render binding.
            pcall(function()run:UnbindFromRenderStep(bind)end)
            local ok,err=pcall(function()
                run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+150,forceCursor)
            end)
            if ok then
                cursorBound=true
            else
                warn("[BeyyHub Winter UI] Render cursor binding unavailable: "..tostring(err))
                cursorFallback=run.RenderStepped:Connect(forceCursor)
            end
            cursorWatchdog=run.Heartbeat:Connect(function()
                if not w.Closed and (input.MouseBehavior~=Enum.MouseBehavior.Default
                    or input.MouseIconEnabled~=true) then
                    forceCursor()
                end
            end)
        end
        local function restoreCursor()
            if cursorBound then
                pcall(function()run:UnbindFromRenderStep(bind)end)
                cursorBound=false
            end
            if cursorFallback then cursorFallback:Disconnect();cursorFallback=nil end
            if cursorWatchdog then cursorWatchdog:Disconnect();cursorWatchdog=nil end
            pcall(function()
                input.MouseBehavior=Enum.MouseBehavior.Default
                input.MouseIconEnabled=true
            end)
        end
        function w:Open()
            if self.Destroyed then return end
            self.Closed=false
            gui.Enabled=true
            root.Visible=true
            reopen.Visible=false
            dragInput=nil
            if type(self.OnVisibilityChanged)=="function" then
                local ok,err=pcall(self.OnVisibilityChanged,true)
                if not ok then warn("[BeyyHub Winter UI] Open callback: "..tostring(err)) end
            end
            releaseCursor()
        end
        function w:Close()
            if self.Destroyed then return end
            self.Closed=true
            -- Hide only the main panel. Keep the recovery button active.
            gui.Enabled=true
            root.Visible=false
            reopen.Visible=true
            self.Capture=nil
            dragInput=nil
            local focused=input:GetFocusedTextBox()
            if focused and focused:IsDescendantOf(gui) then
                pcall(function() focused:ReleaseFocus() end)
            end
            if type(self.OnVisibilityChanged)=="function" then
                local ok,err=pcall(self.OnVisibilityChanged,false)
                if not ok then warn("[BeyyHub Winter UI] Close callback: "..tostring(err)) end
            end
            restoreCursor()
        end
        function w:SetToggleKey(_key)
            -- Winter: RightControl is the only keyboard open/close shortcut.
            self.ToggleKey=Enum.KeyCode.RightControl
        end
        function w:EditOpenButton() end
        function w:Destroy()
            if self.Destroyed then return end
            self:Close()
            self.Destroyed=true
            for _,c in ipairs(self.Connections) do c:Disconnect() end
            table.clear(self.Connections)
            gui:Destroy()
        end
        connect(close.Activated,function() w:Close() end)
        connect(reopen.Activated,function() w:Open() end)
        local lastToggleAt=-math.huge
        local rightControlDown=false
        -- InputBegan fires even for gameProcessed input (e.g. Roblox camera).
        -- Right Ctrl is intentionally the ONLY keyboard menu toggle. Ignore
        -- the processed flag, but accept only one toggle per key-down cycle.
        connect(input.InputBegan,function(event,_processed)
            if event.UserInputType~=Enum.UserInputType.Keyboard
                or event.KeyCode==Enum.KeyCode.Unknown then return end
            if w.Capture then
                local capture=w.Capture
                w.Capture=nil
                capture:Set(event.KeyCode.Name)
                return
            end
            if event.KeyCode~=Enum.KeyCode.RightControl then return end
            if rightControlDown then return end
            rightControlDown=true
            local now=os.clock()
            if now-lastToggleAt<0.10 then return end
            lastToggleAt=now
            -- The RightControl toggle must work even when a slider TextBox
            -- has keyboard focus; w:Close releases that focus safely.
            if w.Closed then w:Open() else w:Close() end
        end)
        connect(input.InputEnded,function(event)
            if event.KeyCode==Enum.KeyCode.RightControl then
                rightControlDown=false
            end
        end)
        connect(input.WindowFocusReleased,function()
            rightControlDown=false
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
                function el:SetDesc(v) local text=tostring(v or ""); if desc.Text~=text then desc.Text=text end end
                function el:SetTitle(v) local text=tostring(v or ""); if heading.Text~=text then heading.Text=text end end
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


local nativeUI=createNativeUI()
local hubWindow=nativeUI:CreateWindow({
    Title=" Beyy Hub Main • WINTER ",Author="by beyy",
    Folder="BeyyHub",Theme="Dark",SideBarWidth=200,
    OpenButton={Enabled=false},
})
hubWindow:SetToggleKey(Enum.KeyCode.RightControl)
isMenuOpen=function() return hubWindow and not hubWindow.Destroyed and not hubWindow.Closed end

local defaults={
    BossFight=false,BossPitchfork=true,BossVacuum=true,BossWalk=true,
    BossWeakAim=true,BossCameraAim=true,AutoSkipCutscenes=true,
    AutoPickHay=false,AutoCollectDroppedHay=false,AutoCollectGems=false,
    CollectInterval=0.5,AutoSellHay=false,SellThreshold=25,SellOnlyIfFull=false,
    AutoUseTNT=false,AutoUsePitchfork=false,AutoDeployDrone=false,
    AutoUseVacuum=false,TntThrowDelay=0.4,TntLightCooldown=0,
    VacuumHotbarSlot=5,ToolInterval=0.5,
    AutoFindNeedle=false,AutoPickupNeedle=false,AutoHandInNeedle=false,
    AutoBuyTools=false,BuyToolsList={"Pitchfork"},BuyInterval=1,
    UpgBagSize=false,UpgExtraTake=false,UpgGemValue=false,UpgHayValue=false,
    PermInterval=0.5,UpgCapacity=false,UpgHandSpeed=false,
    UpgHandGrab=false,UpgHandHold=false,UpgTntLuck=false,
    UpgTntCooldown=false,UpgTntPower=false,UpgPitchCooldown=false,
    UpgPitchHold=false,UpgPitchSweep=false,UpgDroneSpeed=false,
    UpgDroneGrab=false,UpgDroneCapacity=false,UpgVacPower=false,
    UpgVacCooling=false,UpgVacRuntime=false,AntiIdle=false,
}
local settingsPath="BeyyHub/winter_main_settings_v1.json"
local state={}
for key,v in pairs(defaults) do
    state[key]=type(v)=="table" and table.clone(v) or v
end
local function hydrate(path)
    if type(readfile)~="function" then return false end
    local ok,value=pcall(readfile,path)
    if not ok or type(value)~="string" then return false end
    local decodedOk,decoded=pcall(HS.JSONDecode,HS,value)
    if not decodedOk or type(decoded)~="table" then return false end
    decoded=decoded.__elements or decoded
    for key,initial in pairs(defaults) do
        local value=decoded[key]
        if type(value)=="table" and value.__type then value=value.value end
        if type(value)==type(initial) then state[key]=value end
    end
    return true
end
if not hydrate(settingsPath) then
    -- Import previously chosen collecting/shop/upgrades preferences only.
    hydrate("BeyyHub/farming_inventory_shared.json")
end
-- Never launch a VIM-powered boss fight merely because a past configuration
-- file had it on. The user opts in explicitly per session.
state.BossFight=false
local function saveSettings()
    if type(writefile)~="function" then return end
    pcall(function()
        if type(makefolder)=="function" and
            (type(isfolder)~="function" or not isfolder("BeyyHub")) then
            makefolder("BeyyHub")
        end
        writefile(settingsPath,HS:JSONEncode(state))
    end)
end

local registry={}
local forceSkipUntil=0
local function syncBoss()
    attackEnabled=state.BossFight and state.BossPitchfork and not defeated
    walkEnabled=state.BossWalk
    weakAimEnabled=state.BossWeakAim
end
syncBoss()
labelToggle=function(value,which)
    if which=="pitchfork" then
        state.BossPitchfork=false
        if registry.BossPitchfork then registry.BossPitchfork:Set(false) end
    else
        state.BossFight=false
        if registry.BossFight then registry.BossFight:Set(false) end
    end
    syncBoss()
    saveSettings()
end
local function change(key,value)
    state[key]=value
    syncBoss()
    saveSettings()
    if key=="BossFight" then
        logEvent("boss.autofight",value)
        if value and hubWindow and not hubWindow.Destroyed then
            task.defer(function()
                if alive and state.BossFight and not hubWindow.Destroyed then
                    hubWindow:Close()
                end
            end)
        end
    end
end
local function toggle(tab,key,title,desc)
    registry[key]=tab:Toggle({
        Title=title,Desc=desc,Value=state[key]==true,
        Callback=function(v) change(key,v==true) end,
    })
    return registry[key]
end
local function slider(tab,key,title,lo,hi,step)
    registry[key]=tab:Slider({
        Title=title,Step=step,
        Value={Min=lo,Max=hi,Default=tonumber(state[key]) or lo},
        Callback=function(v) change(key,tonumber(v) or defaults[key]) end,
    })
    return registry[key]
end

local overview=hubWindow:Tab({Title="Overview & Settings",Icon="house"})
local bossTab=hubWindow:Tab({Title="Winter Boss",Icon="swords"})
local collectingTab=hubWindow:Tab({Title="Collecting",Icon="wheat"})
local sellingTab=hubWindow:Tab({Title="Selling",Icon="coins"})
local toolsTab=hubWindow:Tab({Title="Tools",Icon="hammer"})
local needleTab=hubWindow:Tab({Title="Needle",Icon="target"})
local shopTab=hubWindow:Tab({Title="Shop Items",Icon="shopping-cart"})
local upgradeTab=hubWindow:Tab({Title="Upgrades",Icon="trending-up"})
local utilityTab=hubWindow:Tab({Title="Utilities",Icon="settings"})

overview:Section({Title="Detected map"})
overview:Paragraph({Title="Status",Desc="Winter Christmas! • Place ID "..tostring(game.PlaceId)})
toggle(overview,"AntiIdle","Anti-AFK","Keep the client active when idle; native input is used where available.")
toggle(overview,"AutoSkipCutscenes","Auto Skip Winter Cutscenes",
    "Use native Skip buttons; if none is offered, restore local gameplay view during the intro.")
overview:Button({Title="Skip Current Winter Intro",Callback=function()
    forceSkipUntil=os.clock()+15
    hubWindow:Close() -- Native skip input must not click the menu
end})
local sessionPanel=overview:Paragraph({Title="Session",Desc="Awaiting game stats"})
overview:Button({Title="Unload Hub",Callback=function() if type(env.BeyyWinterStop)=="function" then env.BeyyWinterStop() end end})
overview:Button({Title="Close Menu (RightControl to reopen)",Callback=function()hubWindow:Close()end})

bossTab:Section({Title="The Yeti King"})
toggle(bossTab,"BossFight","Auto Boss Fight (Vacuum + Crit Pitchfork)",
    "Starts both workers together. Closes menu for native vacuum input; stops on confirmed defeat.")
toggle(bossTab,"BossVacuum","Auto Boss Vacuum",
    "Equips vacuum, aims at the Yeti and holds native Mouse1 while cooled.")
toggle(bossTab,"BossPitchfork","Auto Boss Critical Pitchfork",
    "Attempts weak-point hits using native PitchforkDig and live cooldown.")
toggle(bossTab,"BossWeakAim","Aim at Yeti Weak Points",
    "Approximate arm, shoulder, back and dizzy-head locations using the replicated Yeti model.")
toggle(bossTab,"BossWalk","Auto Follow Boss (Walking)",
    "Uses Humanoid:MoveTo only, within normal physics.")
toggle(bossTab,"BossCameraAim","Aim Camera While Vacuuming",
    "Camera follows the Yeti; automatically restores when disabled.")
local bossStatus=bossTab:Paragraph({Title="Boss Status",Desc="Waiting for Yeti King"})

collectingTab:Section({Title="Resource Collecting"})
toggle(collectingTab,"AutoPickHay","Auto Pick Hay")
toggle(collectingTab,"AutoCollectDroppedHay","Auto Collect Dropped Hay")
toggle(collectingTab,"AutoCollectGems","Auto Collect Gems")
slider(collectingTab,"CollectInterval","Collect Interval (s)",0.1,3,0.1)

sellingTab:Section({Title="Selling"})
toggle(sellingTab,"AutoSellHay","Auto Sell Hay")
slider(sellingTab,"SellThreshold","Sell When Hay >=",1,250,1)
toggle(sellingTab,"SellOnlyIfFull","Only Sell If Full")

toolsTab:Section({Title="Normal Hay Tools"})
toggle(toolsTab,"AutoUseTNT","Auto Use TNT")
slider(toolsTab,"TntLightCooldown","Minimum TNT Light Cooldown (s)",0,60,0.05)
slider(toolsTab,"TntThrowDelay","TNT Delay After Lighting (s)",0,5,0.05)
toggle(toolsTab,"AutoUsePitchfork","Auto Use Pitchfork on Hay")
toggle(toolsTab,"AutoDeployDrone","Auto Deploy Drone")
toggle(toolsTab,"AutoUseVacuum","Auto Vacuum for Hay")
slider(toolsTab,"VacuumHotbarSlot","Vacuum Hotbar Slot (Farm & Boss)",1,9,1)
slider(toolsTab,"ToolInterval","Tool Interval (s)",0.2,5,0.1)
local vacuumStatus=toolsTab:Paragraph({Title="Vacuum Status",Desc="Idle"})

needleTab:Section({Title="Needle Objectives"})
toggle(needleTab,"AutoFindNeedle","Auto Find Exposed Needle")
toggle(needleTab,"AutoPickupNeedle","Auto Pick Up Needle")
toggle(needleTab,"AutoHandInNeedle","Auto Hand In Needle")
local needleStatus=needleTab:Paragraph({Title="Needle Status",Desc="Waiting for objective"})

shopTab:Section({Title="Purchasing"})
registry.BuyToolsList=shopTab:Dropdown({
    Title="Buy Tools Selection",
    Values={"Pitchfork","TNT","Drone","Infinite Bag","Capacity Bag"},
    Value=state.BuyToolsList,Multi=true,AllowNone=true,
    Callback=function(v) change("BuyToolsList",v) end,
})
toggle(shopTab,"AutoBuyTools","Auto Buy Selected Tools")
slider(shopTab,"BuyInterval","Buy Interval (s)",0.5,5,0.1)

upgradeTab:Section({Title="Permanent (Gems)"})
for _,entry in ipairs({
    {"UpgBagSize","Auto Upgrade Bag Size"},
    {"UpgExtraTake","Auto Upgrade Hand Grab Amount"},
    {"UpgGemValue","Auto Upgrade Gem Value"},
    {"UpgHayValue","Auto Upgrade Hay Value"},
}) do toggle(upgradeTab,entry[1],entry[2]) end
slider(upgradeTab,"PermInterval","Permanent Loop (s)",0.5,5,0.1)
for _,group in ipairs({
    {name="Hand (Cash)",items={{"UpgHandSpeed","Hand Speed"},{"UpgHandGrab","Hand Grasp"},{"UpgHandHold","Hand Hold"}}},
    {name="TNT (Cash)",items={{"UpgTntLuck","TNT Luck"},{"UpgTntCooldown","TNT Cooldown"},{"UpgTntPower","TNT Power"}}},
    {name="Pitchfork (Cash)",items={{"UpgPitchCooldown","Pitchfork Cooldown"},{"UpgPitchHold","Pitchfork Hold"},{"UpgPitchSweep","Pitchfork Sweep"}}},
    {name="Drone (Cash)",items={{"UpgDroneSpeed","Drone Speed"},{"UpgDroneGrab","Drone Grasp"},{"UpgDroneCapacity","Drone Capacity"}}},
    {name="Vacuum (Cash)",items={{"UpgVacPower","Vacuum Power"},{"UpgVacCooling","Vacuum Cooling"},{"UpgVacRuntime","Vacuum Runtime"}}},
    {name="Capacity (Cash)",items={{"UpgCapacity","Carry Capacity"}}},
}) do
    upgradeTab:Section({Title=group.name})
    for _,entry in ipairs(group.items) do toggle(upgradeTab,entry[1],"Auto "..entry[2]) end
end
local upgradeStatus=upgradeTab:Paragraph({Title="Upgrade Status",Desc="No upgrades enabled"})

utilityTab:Section({Title="Settings"})
utilityTab:Button({Title="Save Winter Config",Callback=function()
    saveSettings()
    nativeUI:Notify({Title="Winter",Content="Settings saved when writefile is available"})
end})
utilityTab:Button({Title="Stop All Automation",Callback=function()
    if registry.BossFight then registry.BossFight:Set(false) end
    for key,value in pairs(state) do
        if key:sub(1,4)=="Auto" or key:sub(1,3)=="Upg" then
            if type(value)=="boolean" then
                state[key]=false
                if registry[key] then registry[key]:Set(false) end
            end
        end
    end
    attackEnabled=false
    saveSettings()
end})
labelStatus=function(s) pcall(function()bossStatus:SetDesc(s)end) end
-- Keep the menu visible on initial startup; enabling Auto Boss Fight closes it.

-- Native remotes, same names and payload shapes as BeyyHub Chapters 1-5.
local function nativeFarm(name)
    local folder=RS:FindFirstChild("NeedleHaystack")
    local remote=folder and folder:FindFirstChild(name)
    return remote and remote:IsA("RemoteEvent") and remote or nil
end
local function farmSend(name,...)
    local remote=nativeFarm(name)
    if not remote then return false end
    return pcall(remote.FireServer,remote,...)
end
local function root()
    local c=player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function gameBlocked()
    if not alive or not hubWindow.Closed then return true end
    if state.BossFight or player:GetAttribute("InWinterBoss")==true then return true end
    if player:GetAttribute("NeedleRoundComplete")==true then return true end
    for _,key in ipairs({"NeedleInputLocked","CutsceneActive","HintViewerOpen"}) do
        if player:GetAttribute(key)==true then return true end
    end
    return false
end
local function bagFull()
    local held=tonumber(player:GetAttribute("HayHeld")) or 0
    local capacity=tonumber(player:GetAttribute("HayCapacity")) or 25
    return held>=capacity
end
local function nearest(folderName,attribute,limit)
    local folder=WS:FindFirstChild(folderName)
    local hrp=root()
    if not folder or not hrp then return nil,nil end
    local closest,id,distance=nil,nil,limit or 24
    local count=0
    for _,obj in ipairs(folder:GetChildren()) do
        if obj:IsA("BasePart") then
            local value=attribute and obj:GetAttribute(attribute) or obj
            if value~=nil then
                local d=(obj.Position-hrp.Position).Magnitude
                if d<distance then closest,id,distance=obj,value,d end
            end
        end
        count+=1
        if count%2000==0 then task.wait() end
        if count>=12000 then break end
    end
    return closest,id
end
local function winterNeedle()
    local folder=WS:FindFirstChild("HaystackClient")
    if not folder then return nil end
    for _,part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective")==true
            and part:GetAttribute("HIDDEN_WITHIN")~=true then
            return part
        end
    end
    return nil
end

local okVim,VIM=pcall(function()return game:GetService("VirtualInputManager")end)
if not okVim then VIM=nil end
local hotbar={
    Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
    Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
    Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine,
}
local vacuumHeld=false
local vacuumPoint=Vector2.zero
local vacuumStarted=0
local vacuumRestUntil=0
local vacuumCooling=false
local lastEquipAt=-math.huge
local camSnapshot=nil
local function releaseVacuum()
    if vacuumHeld then
        vacuumHeld=false
        if VIM then pcall(function()
            VIM:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
        end) end
    end
end
local function restoreCamera()
    if not camSnapshot then return end
    local old=camSnapshot
    camSnapshot=nil
    pcall(function()
        if old.Camera and old.Camera.Parent then
            old.Camera.CameraType=old.Type
            if old.Subject and old.Subject.Parent then old.Camera.CameraSubject=old.Subject end
        end
    end)
end
-- Opening the UI must immediately release synthetic Mouse1 and any scriptable
-- boss camera before the player tries to click a tab or control.
hubWindow.OnVisibilityChanged=function(open)
    logEvent("ui.visibility",open and "open" or "closed")
    if open then
        releaseVacuum()
        restoreCamera()
        pcall(function()
            UIS.MouseBehavior=Enum.MouseBehavior.Default
            UIS.MouseIconEnabled=true
        end)
    end
end
local function bossReady()
    return state.BossFight and boss and boss.Parent
        and boss:GetAttribute("BossState")=="Fighting"
        and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0
        and boss:GetAttribute("BossShielded")~=true
        and boss:GetAttribute("BossHidden")~=true
        and boss:GetAttribute("BossVulnerable")~=false
        and player:GetAttribute("InWinterBoss")==true
        and not blocked() and not defeated
end
local function vacuumMode()
    if not alive or not hubWindow.Closed then return nil end
    -- The fight gate decides whether stale cinematic attributes matter.
    if bossReady() and state.BossVacuum then return "boss" end
    if blocked() then return nil end
    if not gameBlocked() and state.AutoUseVacuum then return "farm" end
    return nil
end
-- Camera aiming feeds the native mouse-held vacuum; pitchfork remotes keep
-- their independent head-to-weakpoint vector even while vacuum is held.
local function cameraTick()
    if vacuumMode()~="boss" or not state.BossCameraAim then
        restoreCamera()
        return
    end
    local camera=WS.CurrentCamera
    local head=headAndHumanoid()
    local hitbox=boss and (boss:FindFirstChild("BossHitbox") or boss:FindFirstChild("RootPart"))
    if not camera or not head or not hitbox or not hitbox:IsA("BasePart") then return end
    local point=aimPoint(hitbox,head)
    if not camSnapshot or camSnapshot.Camera~=camera then
        restoreCamera()
        camSnapshot={Camera=camera,Type=camera.CameraType,Subject=camera.CameraSubject}
    end
    pcall(function()
        camera.CameraType=Enum.CameraType.Scriptable
        local from=camera.CFrame.Position
        if (from-point).Magnitude>0.05 then
            camera.CFrame=CFrame.lookAt(from,point,Vector3.yAxis)
        end
    end)
end
local function vacuumHeat()
    local value=tonumber(player:GetAttribute("VacuumHeat"))
    if value and value==value and value>=0 and value<=1 then return value end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local hud=pg and pg:FindFirstChild("HUD")
    local heat=hud and hud:FindFirstChild("Overheat")
    local fill=heat and heat:FindFirstChild("Fill")
    return fill and fill:IsA("GuiObject") and fill.Size.Y.Scale or nil
end
local function selectVacuum(slot)
    if not VIM then return false end
    local character=player.Character
    if character then
        for _,tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("vacuum",1,true) then
                return true
            end
        end
    end
    slot=math.clamp(math.floor(tonumber(slot) or 5),1,9)
    local key=hotbar[slot]
    local ok=pcall(function()
        VIM:SendKeyEvent(true,key,false,game)
        task.wait(0.045)
        VIM:SendKeyEvent(false,key,false,game)
    end)
    return ok
end
local lastVacuumStatus=""
local function setVacStatus(message)
    if message~=lastVacuumStatus then
        lastVacuumStatus=message
        pcall(function()vacuumStatus:SetDesc(message)end)
    end
end
task.spawn(function()
    while alive do
        task.wait(0.06)
        local mode=vacuumMode()
        if not mode then
            releaseVacuum()
            restoreCamera()
            setVacStatus("Idle; input released")
            continue
        end
        if not VIM then
            setVacStatus("VirtualInputManager unavailable; native vacuum cannot start")
            continue
        end
        cameraTick()
        if player:GetAttribute("VacuumOwned")~=true then
            releaseVacuum()
            setVacStatus("Vacuum is not owned")
            continue
        end
        local heat=vacuumHeat()
        local overheated=player:GetAttribute("VacuumOverheated")==true
            or (heat~=nil and heat>=0.98)
        if overheated then
            vacuumCooling=true
            vacuumRestUntil=math.max(vacuumRestUntil,os.clock()+0.4)
            releaseVacuum()
        end
        if vacuumCooling then
            if (heat==nil or heat>0.02)
                and player:GetAttribute("VacuumState")~="Ready" then
                setVacStatus("Cooling vacuum")
                continue
            elseif heat~=nil and heat>0.02 then
                setVacStatus("Cooling vacuum "..string.format("%.0f%%",heat*100))
                continue
            end
            vacuumCooling=false
        end
        if os.clock()<vacuumRestUntil then continue end
        if vacuumHeld then
            if heat==nil and os.clock()-vacuumStarted>=25 then
                releaseVacuum()
                vacuumRestUntil=os.clock()+tonumber(player:GetAttribute("VacuumCoolTime") or 13.5)
            elseif player:GetAttribute("VacuumActive")~=true
                and os.clock()-vacuumStarted>3.5 and heat~=nil and heat<0.02 then
                releaseVacuum()
                vacuumRestUntil=os.clock()+0.7
                lastEquipAt=-math.huge
                setVacStatus("Vacuum input not confirmed; reselecting")
            else
                setVacStatus(mode=="boss" and "Vacuum attacking Yeti" or "Vacuum harvesting hay")
            end
            continue
        end
        if os.clock()-lastEquipAt>=1.2 then
            lastEquipAt=os.clock()
            local equipped=selectVacuum(state.VacuumHotbarSlot)
            if not equipped then
                setVacStatus("Could not equip vacuum")
                continue
            end
            task.wait(0.10)
            if vacuumMode()~=mode then continue end
        end
        local camera=WS.CurrentCamera
        if camera then
            vacuumPoint=camera.ViewportSize/2
            local pressed=pcall(function()
                VIM:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,true,game,0)
            end)
            if pressed then
                vacuumHeld=true
                vacuumStarted=os.clock()
                logEvent("vacuum.hold",{mode=mode,heat=heat})
            end
        end
    end
    releaseVacuum()
    restoreCamera()
end)

task.spawn(function()
    while alive do
        task.wait(math.max(0.1,tonumber(state.CollectInterval) or 0.5))
        if gameBlocked() then continue end
        if state.AutoPickHay and not bagFull() then
            local hay,id=nearest("HaystackClient","HayId",22)
            if id~=nil and hay and hay:GetAttribute("IsNeedleObjective")~=true then
                farmSend("PickHay",id,{})
            end
        end
        if state.AutoCollectDroppedHay and not bagFull() then
            local _,obj=nearest("DroppedHay",nil,28)
            if obj then farmSend("PickDroppedHay",obj) end
        end
        if state.AutoCollectGems then
            local _,id=nearest("GemsClient","GemId",35)
            if id~=nil then farmSend("CollectGem",id) end
        end
    end
end)
task.spawn(function()
    while alive do
        task.wait(0.75)
        if gameBlocked() or not state.AutoSellHay then continue end
        local held=tonumber(player:GetAttribute("HayHeld")) or 0
        if held>0 and ((state.SellOnlyIfFull and bagFull())
            or (not state.SellOnlyIfFull and held>=state.SellThreshold)) then
            farmSend("SellHay")
        end
    end
end)

-- Normal farming TNT: the game's "lit" acknowledgement gates each throw.
local tntState={phase="idle",readyAt=0,litAt=0,fuse=2.9}
local tntConnection
local tntRemote
local function bindTnt()
    local remote=nativeFarm("TntAction")
    if tntRemote==remote then return remote end
    if tntConnection then tntConnection:Disconnect()end
    tntRemote=remote
    if remote then
        tntConnection=remote.OnClientEvent:Connect(function(kind,value)
            if kind=="lit" and tntState.phase=="lighting" then
                tntState.phase="lit"
                tntState.litAt=os.clock()
                tntState.fuse=tonumber(value) or 2.9
            elseif kind=="denied" then
                tntState.phase="idle"
                tntState.readyAt=math.max(tntState.readyAt,os.clock()+(tonumber(value) or 1))
            end
        end)
    end
    return remote
end
task.spawn(function()
    while alive do
        task.wait(0.12)
        local remote=bindTnt()
        if not remote then continue end
        local now=os.clock()
        if tntState.phase=="lit" then
            if now-tntState.litAt>=math.max(0,tonumber(state.TntThrowDelay) or 0.4)
                and now-tntState.litAt<tntState.fuse-0.15 then
                if not gameBlocked() and state.AutoUseTNT then
                    local camera=WS.CurrentCamera
                    if camera then
                        farmSend("TntAction","throw",camera.CFrame,
                            camera.CFrame.LookVector*40+Vector3.new(0,8,0))
                    end
                end
                tntState.phase="idle"
            elseif now-tntState.litAt>=tntState.fuse-0.15 then
                tntState.phase="idle"
            end
        elseif tntState.phase=="lighting" then
            if now-tntState.litAt>2.3 then tntState.phase="idle" end
        elseif state.AutoUseTNT and not gameBlocked()
            and player:GetAttribute("TntOwned")==true
            and now>=tntState.readyAt then
            tntState.phase="lighting"
            tntState.litAt=now
            tntState.readyAt=now+math.max(0.5,tonumber(state.TntLightCooldown) or 0,
                tonumber(player:GetAttribute("TntCooldown")) or 20)
            farmSend("TntAction","light")
        end
    end
end)
task.spawn(function()
    while alive do
        task.wait(math.max(0.2,tonumber(state.ToolInterval) or 0.5))
        if gameBlocked() then continue end
        if state.AutoDeployDrone and player:GetAttribute("DroneOwned")==true
            and player:GetAttribute("DroneDeployed")~=true then
            farmSend("DeployDrone")
        end
        if state.AutoUsePitchfork and player:GetAttribute("PitchforkOwned")==true then
            local _,id=nearest("HaystackClient","HayId",15)
            if id~=nil then farmSend("PitchforkDig",id) end
        end
    end
end)
task.spawn(function()
    local lastNeedleAt=-math.huge
    local lastMoveAt=-math.huge
    while alive do
        task.wait(0.16)
        if gameBlocked() then continue end
        if player:GetAttribute("NeedleOwned")==true and state.AutoHandInNeedle then
            local npc=WS:FindFirstChild("NPC")
            local farmer=npc and npc:FindFirstChild("Farmer_NPC")
            local hrp=root()
            if farmer and hrp then
                local point=farmer:GetPivot().Position
                local dist=(point-hrp.Position).Magnitude
                if dist>6 and os.clock()-lastMoveAt>0.8 then
                    lastMoveAt=os.clock()
                    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:MoveTo(point) end
                    needleStatus:SetDesc("Walking to Farmer for native hand-in")
                elseif dist<=6 and os.clock()-lastNeedleAt>0.25 then
                    lastNeedleAt=os.clock()
                    farmSend("NeedleHandIn")
                    needleStatus:SetDesc("Hand-in sent; awaiting NeedleOwned / ending confirmation")
                end
            end
        elseif player:GetAttribute("NeedleOwned")~=true
            and (state.AutoFindNeedle or state.AutoPickupNeedle) then
            local needle=winterNeedle()
            local hrp=root()
            if needle and hrp then
                local distance=(needle.Position-hrp.Position).Magnitude
                if distance>7 then
                    needleStatus:SetDesc(string.format("Exposed needle found %.1f studs away",distance))
                elseif os.clock()-lastNeedleAt>0.55 and state.AutoPickupNeedle then
                    lastNeedleAt=os.clock()
                    farmSend("PickHay","Objective")
                    needleStatus:SetDesc("Objective pickup requested")
                end
            end
        end
    end
end)

local cashTracks={
    {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
    {"UpgVacRuntime","VacuumRuntime"},{"UpgTntPower","TntPower"},
    {"UpgTntLuck","TntLuck"},{"UpgTntCooldown","TntCooldown"},
    {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},
    {"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
    {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},
    {"UpgPitchSweep","Pitchfork"},{"UpgDroneSpeed","DroneSpeed"},
    {"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
}
local permanentTracks={
    UpgBagSize="ExtraHoldAmount",UpgExtraTake="ExtraTakeAmount",
    UpgGemValue="GemValue",UpgHayValue="ExtraHayValuePercentage",
}
local gameConfig,permanentConfig
local configLastTry=-math.huge
local function loadUpgradeConfig()
    if gameConfig and permanentConfig then return end
    if os.clock()-configLastTry<3 then return end
    configLastTry=os.clock()
    local needle=RS:FindFirstChild("NeedleHaystack")
    local module=needle and needle:FindFirstChild("Config")
    if module and not gameConfig then
        local ok,v=pcall(require,module)
        if ok and type(v)=="table" and type(v.UPGRADE_TRACKS)=="table" then gameConfig=v end
    end
    local shared=RS:FindFirstChild("Shared")
    local configs=shared and shared:FindFirstChild("Configs")
    module=configs and configs:FindFirstChild("UpgradeConfig")
    if module and not permanentConfig then
        local ok,v=pcall(require,module)
        if ok and type(v)=="table" then permanentConfig=v end
    end
end
local function cash()
    local ls=player:FindFirstChild("leaderstats")
    local v=ls and ls:FindFirstChild("Cash")
    return v and tonumber(v.Value) or 0
end
task.spawn(function()
    local pendingName,pendingLevel,pendingUntil=nil,nil,0
    while alive do
        task.wait(0.15)
        loadUpgradeConfig()
        if not gameConfig then continue end
        if pendingName then
            local level=tonumber(player:GetAttribute("HayUpgrade"..pendingName)) or 1
            if level>pendingLevel then
                upgradeStatus:SetDesc("Confirmed "..pendingName.." level "..tostring(level))
                pendingName=nil
            elseif os.clock()<pendingUntil then continue
            else pendingName=nil end
        end
        for _,entry in ipairs(cashTracks) do
            local flag,name=entry[1],entry[2]
            if state[flag] then
                local config=gameConfig.UPGRADE_TRACKS[name]
                local level=tonumber(player:GetAttribute("HayUpgrade"..name)) or 1
                local nextLevel=config and config.Levels and config.Levels[level+1]
                if nextLevel and tonumber(nextLevel.Cost) then
                    local discount=tonumber(player:GetAttribute("UpgradeCostMultiplier")) or 1
                    if name:sub(1,9)=="Pitchfork" then
                        discount*=tonumber(player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1
                    end
                    local price=math.round(nextLevel.Cost*discount*100)/100
                    if cash()>=price then
                        if farmSend("BuyUpgrade",name) then
                            pendingName,pendingLevel,pendingUntil=name,level,os.clock()+0.4
                            upgradeStatus:SetDesc("Requested "..name.." level "..tostring(level+1))
                        end
                    else
                        upgradeStatus:SetDesc(string.format("Saving for %s ($%.2f / $%.2f)",name,cash(),price))
                    end
                    break
                end
            end
        end
    end
end)
task.spawn(function()
    local lastPermanent={}
    while alive do
        task.wait(math.max(0.5,tonumber(state.PermInterval) or 0.5))
        loadUpgradeConfig()
        if not permanentConfig then continue end
        for flag,name in pairs(permanentTracks) do
            if state[flag] then
                local ok,upgrade=pcall(function()return permanentConfig.getUpgrade(name)end)
                if ok and upgrade then
                    local level=tonumber(player:GetAttribute("Upgrade"..name)) or 0
                    local maxOk,max=pcall(function()
                        return permanentConfig:getMaxLevel(upgrade)
                    end)
                    if maxOk and tonumber(max) and level<max then
                        local pOk,price=pcall(function()
                            return permanentConfig:getPrice(upgrade,level)
                        end)
                        local last=lastPermanent[name]
                        if pOk and tonumber(price) and
                            (tonumber(player:GetAttribute("Gems")) or 0)>=price
                            and (not last or last.level~=level or os.clock()-last.at>0.4) then
                            lastPermanent[name]={level=level,at=os.clock()}
                            farmSend("BuyUpgrade",name)
                        end
                    end
                end
            end
        end
    end
end)
task.spawn(function()
    while alive do
        task.wait(math.max(0.5,tonumber(state.BuyInterval) or 1))
        if not state.AutoBuyTools then continue end
        for _,name in pairs(state.BuyToolsList or {}) do
            if type(name)=="string" then
                if name=="Pitchfork" and player:GetAttribute("PitchforkOwned")~=true then
                    farmSend("BuyShopItem","Pitchfork")
                elseif name=="TNT" and player:GetAttribute("TntOwned")~=true then
                    farmSend("BuyShopItem","Tnt")
                elseif name=="Drone" and player:GetAttribute("DroneOwned")~=true then
                    farmSend("BuyShopItem","Drone")
                elseif name=="Infinite Bag" and player:GetAttribute("InfiniteBagOwned")~=true then
                    farmSend("BuyShopItem","InfiniteBag")
                elseif name=="Capacity Bag" then
                    local cfg=gameConfig and gameConfig.UPGRADE_TRACKS.Capacity
                    local lv=tonumber(player:GetAttribute("HayUpgradeCapacity")) or 1
                    local nextLv=cfg and cfg.Levels and cfg.Levels[lv+1]
                    if nextLv and cash()>=(tonumber(nextLv.Cost) or math.huge) then
                        farmSend("BuyUpgrade","Capacity")
                    end
                end
            end
        end
    end
end)


-- Winter cutscene skip. First activate the game's real Skip button if offered.
-- The visual fallback only repairs the local camera; it never changes
-- server-owned CutsceneActive, NeedleInputLocked or boss progression flags.
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local cutsceneCameraBind="BeyyWinterCutsceneView_"..tostring(player.UserId)
local introVisualBound=false
local introVisualCamera=nil
local lastScene=nil
local sceneSince=0
local nextSkipClickAt=0
local skipAttempts=0
local skipMouseDown=false
local function cutscenePhase()
    if player:GetAttribute("NeedleRoundComplete")==true or defeated then return nil end
    local b=findBoss()
    if b and b:IsA("Model") then
        local phase=tostring(b:GetAttribute("BossState") or "")
        if phase=="Defeated" or phase=="Fighting" then return nil end
        if player:GetAttribute("InWinterBoss")==true and
            (phase=="Sleeping" or phase=="Intro" or phase=="Rising" or
             phase=="Waiting" or phase=="Starting" or phase=="Preparing") then
            return "Yeti "..phase
        end
    end
    if player:GetAttribute("IntroCutsceneFinished")~=true and
        (player:GetAttribute("CutsceneActive")==true or
         player:GetAttribute("NeedleInputLocked")==true) then
        return "Winter opening"
    end
    return nil
end
local function skipButtonVisible(btn,pg)
    if not btn or not btn.Parent or not btn:IsDescendantOf(pg) then return false end
    if btn.AbsoluteSize.X<=3 or btn.AbsoluteSize.Y<=3 then return false end
    local node=btn
    while node and node~=pg do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        if node.Name=="BeyyNativeHub" then return false end
        node=node.Parent
    end
    return node==pg
end
local function findNativeSkip()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local examined=0
    for _,node in ipairs(pg:GetDescendants()) do
        if node:IsA("GuiButton") and skipButtonVisible(node,pg) then
            local label=node.Name:lower()
            if node:IsA("TextButton") then label=label.." "..node.Text:lower() end
            for _,child in ipairs(node:GetChildren()) do
                if child:IsA("TextLabel") then
                    label=label.." "..child.Text:lower()
                end
            end
            local parent=node.Parent
            for _=1,2 do
                if not parent or parent==pg then break end
                label=label.." "..parent.Name:lower()
                parent=parent.Parent
            end
            if label:find("skip",1,true)
                and not label:find("replay",1,true)
                and not label:find("lobby",1,true)
                and not label:find("ending",1,true)
                and not label:find("return",1,true)
                and not label:find("vote",1,true)
                and not label:find("results",1,true) then
                return node
            end
        end
        examined+=1
        if examined>6000 then break end
    end
    return nil
end
local function stopCutsceneView()
    if introVisualBound then
        pcall(function()RunService:UnbindFromRenderStep(cutsceneCameraBind)end)
        introVisualBound=false
    end
    if introVisualCamera then
        local camera=introVisualCamera
        introVisualCamera=nil
        pcall(function()
            if camera and camera.Parent then
                local human=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if human then camera.CameraSubject=human end
                camera.CameraType=Enum.CameraType.Custom
            end
        end)
    end
end
local function applyPlayableCutsceneView()
    if not alive or not hubWindow.Closed or not (state.AutoSkipCutscenes or os.clock()<forceSkipUntil)
        or not cutscenePhase() then return end
    local camera=WS.CurrentCamera
    local human=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not camera or not human or human.Health<=0 then return end
    if not introVisualCamera then introVisualCamera=camera end
    pcall(function()
        camera.CameraSubject=human
        camera.CameraType=Enum.CameraType.Custom
    end)
end
local function startCutsceneView()
    if introVisualBound then return end
    local ok,err=pcall(function()
        RunService:BindToRenderStep(cutsceneCameraBind,
            Enum.RenderPriority.Camera.Value+10,applyPlayableCutsceneView)
    end)
    if ok then
        introVisualBound=true
        logEvent("winter.skip","Client camera restored while intro is active")
    else
        warn("[BeyyHub Winter] Cannot restore intro camera: "..tostring(err))
    end
end
local function clickNativeSkip(button)
    if not button or not button.Parent then return false end
    local used=false
    if type(firesignal)=="function" then
        used=pcall(function() firesignal(button.Activated) end)
        -- Also support legacy Click listeners; only if still visible.
        task.wait(0.04)
        local pg=player:FindFirstChildOfClass("PlayerGui")
        if pg and skipButtonVisible(button,pg) then
            pcall(function() firesignal(button.MouseButton1Click) end)
        end
    end
    -- Signal helpers are not available to all clients. Native mouse fallback
    -- only runs while the hub is closed and no vacuum Mouse1 is being held.
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if alive and hubWindow.Closed and pg and skipButtonVisible(button,pg)
        and VIM and not vacuumHeld then
        local pos,size=button.AbsolutePosition,button.AbsoluteSize
        local inset=GuiService:GetGuiInset()
        local x,y=pos.X+size.X/2+inset.X,pos.Y+size.Y/2+inset.Y
        local ok=pcall(function()
            VIM:SendMouseMoveEvent(x,y,game)
            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
            skipMouseDown=true
            task.wait(0.05)
            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
            skipMouseDown=false
        end)
        used=ok or used
        if skipMouseDown then
            pcall(function()VIM:SendMouseButtonEvent(x,y,0,false,game,0)end)
            skipMouseDown=false
        end
    end
    return used
end
task.spawn(function()
    while alive do
        task.wait(0.14)
        local scene=cutscenePhase()
        if scene~=lastScene then
            lastScene=scene
            sceneSince=os.clock()
            skipAttempts=0
            nextSkipClickAt=0
            logEvent("winter.scene",scene or "gameplay")
        end
        local enabled=state.AutoSkipCutscenes or os.clock()<forceSkipUntil
        if not enabled or not scene or not hubWindow.Closed then
            stopCutsceneView()
            continue
        end
        local button=findNativeSkip()
        if button and os.clock()>=nextSkipClickAt and skipAttempts<18 then
            nextSkipClickAt=os.clock()+0.65
            skipAttempts+=1
            local ok,why=pcall(clickNativeSkip,button)
            logEvent("winter.skip.native",{scene=scene,attempt=skipAttempts,
                sent=ok and why==true})
        end
        -- If winter offers no native Skip, bypass only the visual camera.
        -- Server timers and any true character input restrictions remain.
        if (not button or skipAttempts>=4) and os.clock()-sceneSince>=0.85 then
            -- A Skip control can remain visible yet ignore click injection.
            -- Avoid leaving the camera trapped in the cinematic indefinitely.
            startCutsceneView()
        elseif button then
            stopCutsceneView()
        end
    end
    stopCutsceneView()
end)

local antiIdle
antiIdle=player.Idled:Connect(function()
    if not alive or not state.AntiIdle then return end
    local ok,vu=pcall(function()return game:GetService("VirtualUser")end)
    if ok and vu then pcall(function()
        vu:CaptureController()
        vu:ClickButton2(Vector2.new(0,0),WS.CurrentCamera and WS.CurrentCamera.CFrame)
    end) end
end)
connections[#connections+1]=antiIdle

task.spawn(function()
    local began=os.clock()
    while alive do
        task.wait(0.6)
        local gui=player:FindFirstChildOfClass("PlayerGui")
        local stats=gui and gui:FindFirstChild("WinterBossUI")
        sessionPanel:SetDesc(string.format(
            "Session %.0fs | Cash $%s | Gems %s | Hay %s/%s",
            os.clock()-began,tostring(cash()),
            tostring(player:GetAttribute("Gems") or 0),
            tostring(player:GetAttribute("HayHeld") or 0),
            tostring(player:GetAttribute("HayCapacity") or 0)))
        if boss then
            bossStatus:SetDesc(string.format(
                "Yeti HP %s/%s • Phase %s • %s\nShield %s • Dizzy %s • Stagger %s",
                tostring(boss:GetAttribute("BossHealth")),
                tostring(boss:GetAttribute("BossMaxHealth")),
                tostring(boss:GetAttribute("BossPhase")),
                tostring(boss:GetAttribute("BossState")),
                tostring(boss:GetAttribute("BossShielded")),
                tostring(boss:GetAttribute("BossDizzy")),
                tostring(boss:GetAttribute("BossStagger"))))
        else
            bossStatus:SetDesc(defeated and "Yeti King defeated" or "Waiting for Yeti King spawn")
        end
     end
end)

local function stop()
    if not alive then return end
    alive=false
    state.BossFight=false
    attackEnabled=false
    releaseVacuum()
    restoreCamera()
    stopCutsceneView()
    clearBossConnections()
    if tntConnection then tntConnection:Disconnect() end
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()hubWindow:Destroy()end)
    if env.BeyyWinterStop==stop then env.BeyyWinterStop=nil end
    if _G.__BEYY_HUB_CLEANUP==stop then _G.__BEYY_HUB_CLEANUP=nil end
    print("[BeyyHub Winter] Main module stopped; vacuum input and camera released")
end
env.BeyyWinterStop=stop
_G.__BEYY_HUB_CLEANUP=stop
print("[BeyyHub Winter] Main v4.2 installed: clean BeyyHub tabs, winter cutscene skip, repaired Yeti vacuum + crit pitchfork")
