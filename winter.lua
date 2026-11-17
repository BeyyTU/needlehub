-- BeyyHub v103.00 | Winter / Christmas event | Yeti King Main Hub v4.24 critical-feedback approach and enraged-phase damage
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
local vacuumCritTelemetry={
    weak=0,body=0,aimedFrames=0,aimErrors=0,
    lastTarget=nil,lastSource=nil,lastAimAt=-math.huge,
    lastStatus="idle",lastFeedback="none",
    aimSource=nil,aimOffsetIndex=1,bodyStreak=0,
    lastOffsetShift=-math.huge,
}
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
    -- Confirmed by the winter captures: YetiKing spawns directly in Workspace.
    -- A recursive search every 0.12s would traverse tens of thousands of
    -- hay parts and make auto TNT/drone/needle workers lag badly.
    local target=WS:FindFirstChild("YetiKing")
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
-- Server fight events announce attack telegraphs. Track only known impact
-- moves, then evade normally using character movement; never modify stun flags.
local bossHazard={
    kind=nil,untilAt=0,startAt=0,dodgeSign=1,lastReportAt=0,
    orbitAngle=nil,orbiting=false,
}
-- Pitchfork feedback calibration stays on the native server cooldown; it
-- never spams multi-shot remotes or moves the player's own camera.
local critAssist={
    spot=nil,offsetIndex=1,pendingAt=0,pendingSpot=nil,
    sentAt=0,serverCrits=0,serverBodyHits=0,unconfirmed=0,
    lastResult="none",
}
-- Move gradually toward the active critical spot if the server does not
-- confirm a Pitchfork/Vacuum critical quickly. Never override attack dodges.
local critProximity={
    source=nil,windowKey=nil,seenAt=0,lastConfirmedAt=-math.huge,
    nextStepAt=0,level=0,maxLevel=3,hitThisWindow=false,
    lastStatus="idle",lastLogAt=-math.huge,approaches=0,
}
local function classifyBossAttack(payload,depth)
    if (depth or 0)>3 then return nil end
    if type(payload)=="string" then
        local name=payload:lower()
        if name:find("slam",1,true) or name:find("groundpound",1,true)
            or name:find("jump",1,true) then return "Slam" end
        if name:find("ring",1,true) and not name:find("during",1,true) then
            return "Ring"
        end
        -- The native winter config names the snowball volley "Barrage".
        -- A separate "Throw"/snowball knockdown also appears in config.
        if name:find("barrage",1,true)
            or name:find("snowball",1,true)
            or name=="throw" or name=="snowthrow" then return "Snowball" end
        if name:find("icicle",1,true)
            or name:find("icefall",1,true)
            or name:find("icespike",1,true)
            or name:find("ice_spike",1,true)
            or name:find("ice spike",1,true)
            or name:find("fallingice",1,true) then return "Icicle" end
    elseif type(payload)=="table" then
        for _,key in ipairs({"Name","name","Attack","attack","AttackType",
            "attackType","Type","type","Move","move","Kind","kind"}) do
            if rawget(payload,key)~=nil then
                local found=classifyBossAttack(rawget(payload,key),(depth or 0)+1)
                if found then return found end
            end
        end
        local traversed=0
        for key,value in pairs(payload) do
            traversed+=1
            if traversed>24 then break end
            local fromKey=classifyBossAttack(key,(depth or 0)+1)
            if fromKey then return fromKey end
            local found=classifyBossAttack(value,(depth or 0)+1)
            if found then return found end
        end
    end
    return nil
end
-- Enrage is still a DAMAGEABLE combat phase in Winter. The replicated
-- shield/vulnerable flags may lag the phase transition; only the native
-- server can decide whether the next hit is actually accepted.
local function bossEnraged(target)
    if not target then return false end
    if target:GetAttribute("BossEnraged")==true
        or target:GetAttribute("Enraged")==true then return true end
    local stateName=tostring(target:GetAttribute("BossState") or ""):lower()
    local phaseName=tostring(target:GetAttribute("BossPhase") or ""):lower()
    return stateName:find("enrag",1,true)~=nil
        or stateName:find("raging",1,true)~=nil
        or phaseName:find("enrag",1,true)~=nil
        or phaseName=="rage"
end
local function bossInCombat(target)
    if not target then return false end
    local name=tostring(target:GetAttribute("BossState") or ""):lower()
    if name=="fighting" or name=="enraged"
        or name=="enrage" or name=="raging" or name=="rage" then
        return true
    end
    return bossEnraged(target)
        and name~="defeated" and name~="sleeping"
        and name~="intro" and name~="unavailable"
        and name~="falling" and name~="rising"
end
local function bossDamageable(target)
    if bossEnraged(target) then return true end
    return target and target:GetAttribute("BossShielded")~=true
        and target:GetAttribute("BossHidden")~=true
        and target:GetAttribute("BossVulnerable")~=false
end
local function bindBoss(target)
    if target==boss then return end
    clearBossConnections()
    boss=target
    lastAttackAt=-math.huge
    sentAttacks=0
    playerPitchforkHits=0
    critAssist.spot=nil
    critAssist.offsetIndex=1
    critAssist.pendingAt=0
    critAssist.pendingSpot=nil
    critAssist.lastResult="new boss"
    critProximity.source=nil
    critProximity.windowKey=nil
    critProximity.seenAt=0
    critProximity.lastConfirmedAt=-math.huge
    critProximity.nextStepAt=0
    critProximity.level=0
    critProximity.hitThisWindow=false
    critProximity.lastStatus="new boss"
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
            if packed[1]=="Attack" or packed[1]=="Snowball"
                or packed[1]=="Icicle" or packed[1]=="IcicleAttack"
                or packed[1]=="Icefall" then
                local kind=classifyBossAttack(packed[2])
                    or classifyBossAttack(packed[1])
                if kind then
                    local now=os.clock()
                    bossHazard.kind=kind
                    bossHazard.startAt=now
                    local char=player.Character
                    local characterRoot=char and char:FindFirstChild("HumanoidRootPart")
                    local bRoot=boss and boss:FindFirstChild("RootPart")
                    if characterRoot and bRoot and bRoot:IsA("BasePart") then
                        local radial=characterRoot.Position-bRoot.Position
                        local flat=Vector3.new(radial.X,0,radial.Z)
                        bossHazard.dodgeSign=radial:Dot(
                            bRoot.CFrame.RightVector)>=0 and -1 or 1
                        if flat.Magnitude<=0.5 then
                            local right=bRoot.CFrame.RightVector
                            flat=Vector3.new(right.X,0,right.Z)
                        end
                        bossHazard.orbitAngle=math.atan2(flat.Z,flat.X)
                    else
                        bossHazard.dodgeSign=1
                        bossHazard.orbitAngle=nil
                    end
                    bossHazard.orbiting=false
                    -- Barrage contains 3-5 throws spaced by ~0.55s, with
                    -- ~1.15s flight time; stay evasive through the volley.
                    local dangerTime=kind=="Snowball" and 4.6
                        or (kind=="Icicle" and 4.4
                        or (kind=="Ring" and 3.5 or 2.5))
                    bossHazard.untilAt=now+dangerTime
                    logEvent("boss.attackTelegraph",{
                        kind=kind,duration=dangerTime,
                        event=tostring(packed[1]),dodgeMode="horizontal orbit",
                    })
                end
            end
            if packed[1]=="BossHp" and tonumber(packed[4])==player.UserId then
                local damage=tonumber(packed[5]) or 0
                local tool=tostring(packed[8] or "Unknown")
                playerDamage+=math.max(0,damage)
                local tag=tostring(packed[7] or ""):upper()
                local weak=(tag:find("WEAK SPOT",1,true)~=nil
                    or tag:find("CRITICAL",1,true)~=nil)
                if tool=="Pitchfork" then
                    playerPitchforkHits+=1
                    if weak then
                        critAssist.serverCrits+=1
                        critAssist.lastResult="confirmed weak"
                    else
                        critAssist.serverBodyHits+=1
                        critAssist.lastResult="confirmed body"
                        if critAssist.pendingAt>0
                            and critAssist.pendingSpot==critAssist.spot then
                            -- Only calibrate from a body hit while a real
                            -- weak-point request is pending; unrelated body
                            -- hits must not move our critical aim offsets.
                            critAssist.offsetIndex=critAssist.offsetIndex%7+1
                        end
                    end
                    critAssist.pendingAt=0
                end
                if tool=="TNT" then playerTntHits+=1 end
                if tool=="Vacuum" then
                    playerVacuumHits+=1
                    if weak then
                        vacuumCritTelemetry.weak+=1
                        vacuumCritTelemetry.bodyStreak=0
                    else
                        vacuumCritTelemetry.body+=1
                        if vacuumCritTelemetry.aimSource
                            and vacuumCritTelemetry.aimSource:find("live ",1,true)==1 then
                            vacuumCritTelemetry.bodyStreak+=1
                            local now=os.clock()
                            if vacuumCritTelemetry.bodyStreak>=3
                                and now-vacuumCritTelemetry.lastOffsetShift>0.5 then
                                vacuumCritTelemetry.aimOffsetIndex=
                                    vacuumCritTelemetry.aimOffsetIndex%7+1
                                vacuumCritTelemetry.lastOffsetShift=now
                                vacuumCritTelemetry.bodyStreak=0
                                logEvent("boss.vacuumAimCalibrate",{
                                    spot=vacuumCritTelemetry.aimSource,
                                    offset=vacuumCritTelemetry.aimOffsetIndex,
                                })
                            end
                        end
                    end
                    vacuumCritTelemetry.lastFeedback=weak
                        and "server confirmed weak" or "server confirmed body"
                    if playerVacuumHits<=8 or playerVacuumHits%12==0 then
                        logEvent("boss.vacuumFeedback",{
                            weak=weak,damage=damage,
                            tool=tool,weakConfirmed=vacuumCritTelemetry.weak,
                            bodyConfirmed=vacuumCritTelemetry.body,
                            mouseTarget=vacuumCritTelemetry.lastSource,
                            aimState=vacuumCritTelemetry.lastStatus,
                        })
                    end
                end
                if weak then
                    playerWeakHits+=1
                    if (tool=="Pitchfork" or tool=="Vacuum")
                        and critProximity.source then
                        local now=os.clock()
                        critProximity.hitThisWindow=true
                        critProximity.lastConfirmedAt=now
                        critProximity.nextStepAt=now+1.15
                        if critProximity.level>0 then
                            logEvent("boss.critApproachSuccess",{
                                tool=tool,spot=critProximity.source,
                                previousLevel=critProximity.level,
                                timeSinceExposed=now-critProximity.seenAt,
                            })
                        end
                        critProximity.level=0
                        critProximity.lastStatus="confirmed critical; returning overhead"
                    end
                end
                logEvent("boss.damage.confirmed",{amount=damage,tool=tool,
                    weak=weak,health=tonumber(packed[2]),
                    nextPitchforkOffset=critAssist.offsetIndex})
            elseif packed[1]=="End" then
                defeated=true
                status("Yeti King defeated; awaiting next encounter")
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
-- Read only the known, client-replicated WinterBoss.Config. The captured
-- config provides actual boss ranges and weak point local positions.
local winterConfigCached=nil
local function winterConfig()
    if winterConfigCached then return winterConfigCached end
    local folder=RS:FindFirstChild("WinterBoss")
    local module=folder and folder:FindFirstChild("Config")
    if not module or not module:IsA("ModuleScript") then return nil end
    local ok,config=pcall(require,module)
    if ok and type(config)=="table" then winterConfigCached=config end
    return winterConfigCached
end
local function pitchforkBossReach()
    local config=winterConfig()
    local reach=config and config.Tools and tonumber(config.Tools.PitchforkRange)
    -- WinterBoss.Config Tools.PitchforkRange was 13 in the captured map;
    -- character PitchforkReach (4.2) belongs to ordinary hay attacks.
    return math.max(0.1,reach or tonumber(player:GetAttribute("PitchforkReach")) or 4.2)
end
-- The live boss exposes RootPart/BossHitbox; weak points are configured
-- separately in WinterBoss.Config, with rendered-model aliases as a fallback.
-- Chapter 3 uses the live rig. The Yeti's Spots vectors are LOCAL TO
-- RootPart, just like its replicated Bone positions; do not transform a local
-- offset through the model template's world-space CFrame first.
local boneAliases={
    Chest={"Torso"},Belly={"Hips"},Face={"Head"},
    Head={"Head"},DizzyHead={"Head","HeadTop"},
    LeftArm={"LeftHand","LeftArmTop"},RightArm={"RightHand","RightArmTop"},
    LeftShoulder={"LeftArmTop"},RightShoulder={"RightArmTop"},
    Back={"Torso"},
}
local function aimPoint(hitbox, head)
    local origin=head.Position
    local fallback=hitbox.Position
    local ok,surface=pcall(function() return hitbox:GetClosestPointOnSurface(origin) end)
    if ok and typeof(surface)=="Vector3" then fallback=surface end
    if not weakAimEnabled then return fallback,"boss hitbox" end
    local root=boss and boss:FindFirstChild("RootPart")
    if not root or not root:IsA("BasePart") then return fallback,"boss hitbox" end
    local name=boss:GetAttribute("BossWeakPoint")
    local dizzy=boss:GetAttribute("BossWeakPointDizzy")==true
        or boss:GetAttribute("BossDizzy")==true
    local targetName=dizzy and "DizzyHead" or name
    if type(targetName)~="string" or targetName=="" then
        return fallback,"boss hitbox (no exposed weak point)"
    end
    local untilAt=tonumber(boss:GetAttribute("BossWeakPointEndsAt"))
    if untilAt and WS:GetServerTimeNow()>=untilAt and not dizzy then
        return fallback,"boss hitbox (weak window ended)"
    end
    local config=winterConfig()
    local weak=config and config.WeakPoint
    local spot=targetName=="DizzyHead" and weak and weak.DizzyHead
        or (weak and weak.Spots and weak.Spots[targetName])
    if typeof(spot)=="Vector3" then
        -- WinterBoss.Config.WeakPoint.Spots contains offsets such as
        -- Face=(0,22.5,-7.6); the live RootPart rotates/translates them.
        local worldSpot=root.CFrame:PointToWorldSpace(spot)
        if (worldSpot-root.Position).Magnitude<=40 then
            return worldSpot,"live config weak point "..targetName
        end
    end
    -- Chapter 3 fallback: inspect the ACTUAL replicated rig Bones,
    -- not the static ReplicatedStorage.Yeti template.
    for _,boneName in ipairs(boneAliases[targetName] or {}) do
        local bone=root:FindFirstChild(boneName,true)
        if bone and bone:IsA("Bone") then
            return bone.TransformedWorldCFrame.Position,"live bone "..boneName
        end
    end
    return fallback,"boss hitbox (weak point unavailable)"
end
local function liveCritSource(source)
    return type(source)=="string" and
        (source:find("live config weak point ",1,true)==1
            or source:find("live bone ",1,true)==1)
end
-- Offset positions remain inside the configured 2.4-stud weak sphere.
-- Only advance after a real server body-hit or unanswered attack.
local critOffsets={
    {0,0,0},{0.65,0,0},{-0.65,0,0},
    {0,0.65,0},{0,-0.65,0},{0,0,0.65},{0,0,-0.65},
}
local function refinedPitchforkTarget(point,source,bossRoot)
    if not liveCritSource(source) or not bossRoot then return point,1 end
    if critAssist.spot~=source then
        critAssist.spot=source
        critAssist.offsetIndex=1
        critAssist.pendingAt=0
    end
    local index=math.clamp(critAssist.offsetIndex,1,#critOffsets)
    local p=critOffsets[index]
    return point+bossRoot.CFrame:VectorToWorldSpace(
        Vector3.new(p[1],p[2],p[3])),index
end
-- Stay visibly higher above the LIVE Yeti center. Prefer 24 studs above its
-- root; only descend toward the higher minimum for confirmed low weak points,
-- using the actual pitchfork range rather than an arbitrary head-height cap.
local hoverCfg={
    minHeight=18.5,maxHeight=25,preferredHeight=24,tick=0.045,
    maxTravelSpeed=42,maxDodgeSpeed=110,maxReturnSpeed=85,
    -- Emergency = travel OUTSIDE the attack radius, then circle the Yeti.
    -- No airborne altitude boost; normal height remains 18.5-25 studs.
    dodgeRadius={Slam=19,Ring=22,Snowball=21,Icicle=20},
    dodgeAngularRate={Slam=1.5,Ring=1.6,Snowball=2.0,Icicle=1.9},
    recoverUntil=0,priorDanger=nil,
    lastAt=-math.huge,badCorrections=0,lastApplied=nil,suspendedUntil=0,
    lastStateLog=-math.huge,lastGoal=nil,lastActual=nil,
}
-- Critical proximity is tied to the LIVE spot + its ending timestamp,
-- preventing the distance adjustment from leaking into later weak windows.
local function updateCritProximity(source,now,danger)
    if not liveCritSource(source) then
        if critProximity.source then
            logEvent("boss.critApproachReset",{reason="weak point ended",
                spot=critProximity.source,level=critProximity.level})
        end
        critProximity.source=nil
        critProximity.windowKey=nil
        critProximity.level=0
        critProximity.hitThisWindow=false
        critProximity.lastConfirmedAt=-math.huge
        critProximity.lastStatus="no active weak point"
        return 0
    end
    local untilAt=boss and tonumber(boss:GetAttribute("BossWeakPointEndsAt"))
    local windowKey=source..":"..tostring(untilAt or "dizzy")
    if critProximity.windowKey~=windowKey then
        critProximity.source=source
        critProximity.windowKey=windowKey
        critProximity.seenAt=now
        critProximity.lastConfirmedAt=-math.huge
        critProximity.nextStepAt=now+0.70
        critProximity.level=0
        critProximity.hitThisWindow=false
        critProximity.lastStatus="new exposed critical"
        logEvent("boss.critApproachTrack",{
            spot=source,windowEndsAt=untilAt,initialDelay=0.70})
    end
    if danger then
        -- Protect the actual dodge movement and give the game 0.30s
        -- after an attack telegraph before asking to approach again.
        critProximity.nextStepAt=math.max(critProximity.nextStepAt,now+0.30)
        critProximity.lastStatus="evading "..danger
        return 0
    end
    -- This helper is declared before the saved-settings table, so use the
    -- already synchronized combat flag and replicated native ownership.
    local hasTool=(attackEnabled
        and player:GetAttribute("PitchforkOwned")==true)
        or player:GetAttribute("VacuumOwned")==true
    if not hasTool then
        critProximity.lastStatus="waiting for native attack tool"
        return 0
    end
    if now-critProximity.lastConfirmedAt<1.15 then
        critProximity.lastStatus="critical confirmed; normal hover"
        return 0
    end
    if critProximity.level<critProximity.maxLevel
        and now>=critProximity.nextStepAt then
        critProximity.level+=1
        critProximity.approaches+=1
        critProximity.nextStepAt=now+0.55
        critProximity.lastStatus="approaching weakpoint "..critProximity.level
        logEvent("boss.critApproachStep",{
            spot=source,level=critProximity.level,
            elapsed=now-critProximity.seenAt,
            lastCritAge=critProximity.lastConfirmedAt>-math.huge
                and now-critProximity.lastConfirmedAt or nil,
        })
    end
    return critProximity.level
end
local function hoverNearWeakPoint(point,source)
    if not walkEnabled or isMenuOpen() then return false end
    local now=os.clock()
    if now<hoverCfg.suspendedUntil then return false end
    if hoverCfg.suspendedUntil>0 then
        -- A temporary backoff prevents repeated correction loops from
        -- permanently disabling overhead hover for the rest of the fight.
        hoverCfg.suspendedUntil=0
        hoverCfg.badCorrections=0
        hoverCfg.lastApplied=nil
        hoverCfg.lastAt=now-hoverCfg.tick
        logEvent("boss.hoverRecovered","Resuming overhead tracking after backoff")
    end
    local char=player.Character
    local charRoot=char and char:FindFirstChild("HumanoidRootPart")
    local head=char and char:FindFirstChild("Head")
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    local bossRoot=boss and boss:FindFirstChild("RootPart")
    if not char or not charRoot or not head or not humanoid
        or humanoid.Health<=0 or not bossRoot
        or not bossRoot:IsA("BasePart") or typeof(point)~="Vector3" then return false end
    if now-hoverCfg.lastAt<hoverCfg.tick then return true end
    local dt=math.clamp(now-hoverCfg.lastAt,0.016,0.16)
    hoverCfg.lastAt=now
    local delta=Vector3.new(point.X-bossRoot.Position.X,0,
        point.Z-bossRoot.Position.Z)
    if delta.Magnitude<0.05 then
        local forward=bossRoot.CFrame.LookVector
        delta=Vector3.new(forward.X,0,forward.Z)
    end
    if delta.Magnitude<0.05 then delta=Vector3.new(0,0,-1) end
    local outward=delta.Unit
    local relativeHeadHeight=head.Position.Y-charRoot.Position.Y
    local height=hoverCfg.preferredHeight
    local weakReachCeiling=nil
    -- A taller fixed hover can put low weak points outside 13-stud pitchfork
    -- reach. Lower toward our NEW minimum only when a live weak spot exists.
    -- Subtract a small margin from reach to account for hitbox jitter.
    if liveCritSource(source) then
        local reach=math.max(0.1,pitchforkBossReach()-0.85)
        local horizontal=Vector2.new(point.X-bossRoot.Position.X,
            point.Z-bossRoot.Position.Z).Magnitude
        if horizontal<reach then
            local vertical=math.sqrt(math.max(0,reach*reach-horizontal*horizontal))
            weakReachCeiling=point.Y-bossRoot.Position.Y
                +vertical-relativeHeadHeight
            height=math.min(height,weakReachCeiling)
        end
    end
    height=math.clamp(height,hoverCfg.minHeight,hoverCfg.maxHeight)
    local danger=now<bossHazard.untilAt and bossHazard.kind or nil
    local approachLevel=updateCritProximity(source,now,danger)
    -- Overhead by default, but shift toward the actual active weak point
    -- when server critical damage has not arrived quickly enough.
    local desiredPosition=Vector3.new(
        bossRoot.Position.X,
        bossRoot.Position.Y+height,
        bossRoot.Position.Z)
    if not danger and approachLevel>0 and typeof(point)=="Vector3" then
        -- Use the desired HEAD position, not the root, to calculate the
        -- shortest closing vector for true native pitchfork reach.
        local expectedHead=desiredPosition
            +Vector3.new(0,relativeHeadHeight,0)
        local toward=point-expectedHead
        if toward.Magnitude>0.1 then
            local step=math.min(approachLevel*2.25,
                math.max(0,toward.Magnitude-3.8))
            local shifted=desiredPosition+toward.Unit*step
            -- Keep an elevated minimum; do not dive through the Yeti rig.
            desiredPosition=Vector3.new(
                shifted.X,
                math.max(shifted.Y,bossRoot.Position.Y+12.5),
                shifted.Z)
        end
    end
    if danger then
        -- Height alone did not prevent the jump knockdown. Stay at the
        -- ordinary reach-aware hover altitude and move beyond the impact
        -- radius, then continuously orbit so thrown hazards track poorly.
        local radius=hoverCfg.dodgeRadius[danger] or 25
        if danger=="Slam" then
            local config=winterConfig()
            local attacks=config and config.Attacks
            local slam=attacks and attacks.Slam
            if type(slam)=="table" then
                local nativeRadius=tonumber(slam.Radius)
                    or tonumber(slam.DamageRadius)
                    or tonumber(slam.ImpactRadius)
                if nativeRadius then
                    -- The old +8-stud buffer silently enlarged Slam's
                    -- orbit even after reducing the configured radius.
                    radius=math.max(radius,math.min(nativeRadius+5,29))
                end
            end
        end
        local offset=Vector3.new(
            charRoot.Position.X-bossRoot.Position.X,0,
            charRoot.Position.Z-bossRoot.Position.Z)
        local radialDistance=offset.Magnitude
        if not bossHazard.orbitAngle then
            bossHazard.orbitAngle=math.atan2(outward.Z,outward.X)
        end
        -- Go radially outward FIRST, then orbit the ring at a moving angle.
        -- Beginning tangential motion immediately could leave us inside
        -- the native Slam radius for the entire 1.3-second telegraph.
        if radialDistance<radius-2.5 then
            if radialDistance>0.5 then
                bossHazard.orbitAngle=math.atan2(offset.Z,offset.X)
            end
            bossHazard.orbiting=false
        else
            bossHazard.orbiting=true
            local speed=hoverCfg.dodgeAngularRate[danger] or 1.6
            bossHazard.orbitAngle=bossHazard.orbitAngle
                +bossHazard.dodgeSign*speed*dt
        end
        local angle=bossHazard.orbitAngle
        desiredPosition=Vector3.new(
            bossRoot.Position.X+math.cos(angle)*radius,
            bossRoot.Position.Y+height,
            bossRoot.Position.Z+math.sin(angle)*radius)
        hoverCfg.priorDanger=danger
        hoverCfg.recoverUntil=0
        if now-bossHazard.lastReportAt>0.75 then
            bossHazard.lastReportAt=now
            logEvent("boss.evadeAround",{
                attack=danger,altitude=height,
                radius=radius,currentRadius=radialDistance,
                phase=bossHazard.orbiting and "orbit" or "radial escape",
                goal=tostring(desiredPosition),
            })
        end
    elseif hoverCfg.priorDanger then
        local finished=hoverCfg.priorDanger
        hoverCfg.priorDanger=nil
        hoverCfg.recoverUntil=now+2.0
        logEvent("boss.evadeFinished",{
            attack=finished,returnHeight=height,
            actualHeight=charRoot.Position.Y-bossRoot.Position.Y,
        })
    end
    if (charRoot.Position-desiredPosition).Magnitude>90 then
        status("Boss approach too distant; hover withheld")
        return false
    end
    -- Detect large corrections based on the ACTUAL last applied position.
    -- This prevents false suspension when eased movement is deliberately slow.
    if hoverCfg.lastApplied and
        (charRoot.Position-hoverCfg.lastApplied).Magnitude>9 then
        hoverCfg.badCorrections+=1
    else
        hoverCfg.badCorrections=math.max(0,hoverCfg.badCorrections-0.4)
    end
    if hoverCfg.badCorrections>=7 then
        hoverCfg.suspendedUntil=now+3
        hoverCfg.lastApplied=nil
        hoverCfg.badCorrections=0
        warn("[BeyyHub Winter Boss] Server corrected overhead hover repeatedly; retrying after 3s backoff")
        logEvent("boss.hoverBackoff",{seconds=3,reason="Repeated large position correction"})
        return false
    end
    local diff=desiredPosition-charRoot.Position
    local returning=not danger and now<hoverCfg.recoverUntil
    local response=1-math.exp(-dt*(danger and 21 or (returning and 17 or 11)))
    local move=diff*response
    -- High-priority lateral escape and return. Every position delta
    -- remains bounded to avoid a single extreme root.CFrame teleport.
    local maxSpeed=danger and hoverCfg.maxDodgeSpeed
        or (returning and hoverCfg.maxReturnSpeed or hoverCfg.maxTravelSpeed)
    local maxStep=maxSpeed*dt
    if move.Magnitude>maxStep then move=move.Unit*maxStep end
    local nextPos=charRoot.Position+move
    local lookAt=Vector3.new(point.X,nextPos.Y,point.Z)
    if (lookAt-nextPos).Magnitude<0.1 then
        lookAt=nextPos+charRoot.CFrame.LookVector
    end
    local facing=CFrame.lookAt(nextPos,lookAt)
    local orientation=charRoot.CFrame:Lerp(facing,math.clamp(dt*10,0,0.7)).Rotation
    local easedRoot=CFrame.new(nextPos)*orientation
    local rootToPivot=charRoot.CFrame:ToObjectSpace(char:GetPivot())
    local ok,err=pcall(function()
        char:PivotTo(easedRoot*rootToPivot)
        -- Clear residual gravity acceleration without an abrupt hard snap.
        charRoot.AssemblyLinearVelocity=Vector3.zero
        charRoot.AssemblyAngularVelocity=Vector3.zero
    end)
    if not ok then
        logEvent("boss.hoverError",tostring(err))
        return false
    end
    hoverCfg.lastApplied=nextPos
    hoverCfg.lastGoal=desiredPosition
    hoverCfg.lastActual=charRoot.Position
    if now-hoverCfg.lastStateLog>=2 then
        hoverCfg.lastStateLog=now
        logEvent("boss.hoverTelemetry",{
            mode=danger and ("horizontal orbit evade "..danger)
                or (approachLevel>0 and "closing on weakpoint"
                    or (returning and "return overhead" or "elevated above Yeti")),
            height=height,preferredHeight=hoverCfg.preferredHeight,
            weakReachCeiling=weakReachCeiling,weakSource=source,
            approachLevel=approachLevel,approachStatus=critProximity.lastStatus,
            confirmedCritThisWindow=critProximity.hitThisWindow,
            goal=tostring(desiredPosition),actual=tostring(charRoot.Position),
            horizontalError=Vector2.new(
                charRoot.Position.X-bossRoot.Position.X,
                charRoot.Position.Z-bossRoot.Position.Z).Magnitude,
            error=(charRoot.Position-desiredPosition).Magnitude,
        })
    end
    return true
end
local function resetHover()
    hoverCfg.lastAt=-math.huge
    hoverCfg.badCorrections=0
    hoverCfg.lastApplied=nil
    hoverCfg.suspendedUntil=0
    hoverCfg.lastGoal=nil
    hoverCfg.lastActual=nil
    hoverCfg.recoverUntil=0
    hoverCfg.priorDanger=nil
    bossHazard.orbitAngle=nil
    bossHazard.orbiting=false
    bossHazard.kind=nil
    bossHazard.untilAt=0
    bossHazard.startAt=0
end
local function blocked()
    -- Winter replicates CutsceneActive/NeedleInputLocked even during a full
    -- server-verified Fighting phase. Never use those stale flags to suppress
    -- confirmed Yeti combat. All actual stun/ragdoll/grab gates still apply.
    local fighting=boss and boss.Parent
        and bossInCombat(boss)
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
        status("Waiting for Yeti encounter");return
    end
    if not boss or not boss.Parent then
        status("YetiKing not replicated");return
    end
    local phase=tostring(boss:GetAttribute("BossState") or "")
    local hp=tonumber(boss:GetAttribute("BossHealth"))
    if phase=="Defeated" or (hp and hp<=0) then
        defeated=true
        status("Yeti defeated; automation armed for next encounter")
        return
    end
    if not bossInCombat(boss) or not hp then return end
    local lock=blocked()
    if lock then status("Waiting for "..lock);return end
    if os.clock()<bossHazard.untilAt and bossHazard.kind~="Snowball" then
        -- Snowball volleys permit native pitchfork attacks while moving
        -- laterally; only slam/ring dodge briefly interrupts pitchfork.
        status("Dodging Yeti "..tostring(bossHazard.kind).." attack")
        return
    end
    if not bossDamageable(boss) then
        status("Waiting for Yeti vulnerability")
        return
    end
    if player:GetAttribute("PitchforkOwned")~=true then
        status("Pitchfork ownership not replicated")
        return
    end
    local remote=nativePitchfork()
    if not remote then status("NeedleHaystack.PitchforkDig unavailable");return end
    local head=headAndHumanoid()
    local hitbox=boss:FindFirstChild("BossHitbox") or boss:FindFirstChild("RootPart")
    if not head or not hitbox or not hitbox:IsA("BasePart") then return end
    local target,source=aimPoint(hitbox,head)
    local now=os.clock()
    local config=winterConfig()
    local nativeCd=config and config.Tools and tonumber(config.Tools.PitchforkCooldown)
    local cooldown=tonumber(player:GetAttribute("PitchforkCooldown")
        ) or nativeCd or 0.85
    if now-lastAttackAt<math.max(0.1,cooldown) then return end
    if critAssist.pendingAt>0
        and now-critAssist.pendingAt>=math.max(0.9,cooldown*0.9) then
        critAssist.unconfirmed+=1
        critAssist.lastResult="no server feedback"
        critAssist.pendingAt=0
        critAssist.offsetIndex=critAssist.offsetIndex%#critOffsets+1
    end
    local rootPart=boss:FindFirstChild("RootPart")
    local refined,index=refinedPitchforkTarget(target,source,rootPart)
    local delta=refined-head.Position
    local reach=pitchforkBossReach()
    -- Chapters 3 and 4 use the live boss coordinates and a true range gate.
    -- The separate hover worker positions us within range before this send.
    if delta.Magnitude>reach then
        status(string.format("Weak point out of range: %s (%.1f/%.1f)",
            source,delta.Magnitude,reach))
        return
    end
    if delta.Magnitude<0.05 then return end
    lastAttackAt=now
    local ok,err=pcall(remote.FireServer,remote,"Boss",head.Position,delta.Unit)
    if ok then
        critAssist.pendingAt=liveCritSource(source) and now or 0
        critAssist.pendingSpot=source
        critAssist.sentAt=now
        sentAttacks+=1
        if sentAttacks==12 and playerPitchforkHits==0 then
            -- Chapter 3 never permanently disables the pitchfork after
            -- missing telemetry. Log uncertainty but keep attacking.
            warn("[BeyyHub Winter] 12 pitchfork requests without confirmed damage; checking target geometry while continuing")
        end
        if sentAttacks<=5 or sentAttacks%12==0 then
            logEvent("boss.pitchfork",{
                request=sentAttacks,weakPoint=boss:GetAttribute("BossWeakPoint"),
                target=source,distance=delta.Magnitude,reach=reach,
                offsetIndex=index,confirmed=playerPitchforkHits,
                weakConfirmed=critAssist.serverCrits,
                bodyConfirmed=critAssist.serverBodyHits,
            })
        end
        status(string.format("Auto pitchfork %d sent / %d confirmed • %s",
            sentAttacks,playerPitchforkHits,source))
    else
        status("Pitchfork remote error: "..tostring(err))
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
    BossFight=true,BossPitchfork=true,BossVacuum=true,BossTNT=true,BossWalk=true,
    BossWeakAim=true,BossCameraAim=true,AutoSkipCutscenes=true,
    AutoPickHay=false,AutoCollectDroppedHay=false,AutoCollectGems=false,
    CollectInterval=0.5,AutoSellHay=false,SellThreshold=25,SellOnlyIfFull=false,
    AutoUseTNT=false,AutoUsePitchfork=false,AutoDeployDrone=false,
    AutoUseVacuum=false,
    VacuumHotbarSlot=5,ToolInterval=0.5,
    AutoFindNeedle=false,AutoPickupNeedle=false,AutoHandInNeedle=false,
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
-- The hidden boss feature and all its subfeatures start ON on every load.
-- Actual combat is still gated on a replicated Fighting Yeti and active encounter.
for _,key in ipairs({"BossFight","BossPitchfork","BossVacuum",
    "BossTNT","BossWalk","BossWeakAim","BossCameraAim"}) do
    state[key]=true
end
-- Boss camera aim now stays active throughout a confirmed Yeti encounter,
-- including periods while the vacuum is cooling or unequipped.
-- The winter intro skip is opt-out for the current session. Older persisted
-- OFF values must not stop the requested automatic startup behavior.
state.AutoSkipCutscenes=true
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
local collectingTab=hubWindow:Tab({Title="Collecting",Icon="wheat"})
local sellingTab=hubWindow:Tab({Title="Selling",Icon="coins"})
local toolsTab=hubWindow:Tab({Title="Tools",Icon="hammer"})
local needleTab=hubWindow:Tab({Title="Needle",Icon="target"})
local upgradeTab=hubWindow:Tab({Title="Upgrades",Icon="trending-up"})

local sessionPanel=overview:Paragraph({Title="Session",Desc="Awaiting session stats"})
local bossStatus=overview:Paragraph({Title="Boss Status",Desc="Auto boss enabled; waiting for Yeti"})
toggle(overview,"AntiIdle","Anti-AFK")
toggle(overview,"AutoSkipCutscenes","Auto Skip Winter Cutscenes")

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
toggle(toolsTab,"AutoUseTNT","Auto Use TNT on Hay")
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

-- Consistent with other BeyyHub chapters: compact, collapsible named configs.
local configTab=overview:CollapsibleGroup({Title="Config",Opened=false})
local manager=hubWindow.ConfigManager
local configName="default"
local selectedConfig="default"
local pastedJSON=""
local configDropdown
local function configFiles()
    local ok,names=pcall(function() return manager:AllConfigs() end)
    local result=ok and type(names)=="table" and names or {}
    table.sort(result)
    return result
end
local function configFor(name)
    local cfg=manager:CreateConfig(name)
    for key,control in pairs(registry) do cfg:Register(key,control) end
    return cfg
end
local function refreshConfigs(preferred)
    local names=configFiles()
    local values=#names>0 and names or {"(No saved configs)"}
    configDropdown:Refresh(values)
    local chosen=table.find(values,preferred) and preferred
        or (table.find(values,"default") and "default" or values[1])
    configDropdown:Select(chosen)
end
configDropdown=configTab:Dropdown({
    Title="Select Config to Load",
    Values=(function()local n=configFiles();return #n>0 and n or {"(No saved configs)"}end)(),
    Value="default",
    Callback=function(v)selectedConfig=tostring(v or "")end,
})
configTab:Button({Title="Refresh Config List",Callback=function()
    refreshConfigs(selectedConfig)
end})
configTab:Button({Title="Load Selected Config",Callback=function()
    if not table.find(configFiles(),selectedConfig) then
        nativeUI:Notify({Title="Config",Content="Choose a saved config"})
        return
    end
    local ok,result=pcall(function()return configFor(selectedConfig):Load()end)
    if ok and result~=false then saveSettings() end
    nativeUI:Notify({Title="Config",Content=(ok and result~=false)
        and ("Loaded "..selectedConfig) or "Could not load config"})
end})
configTab:Input({Title="Save Config As",Value="default",
    Callback=function(v)configName=tostring(v or "")end})
configTab:Button({Title="Save Config",Callback=function()
    if not configName:match("^[%w_%-%s]+$") or #configName>55 then
        nativeUI:Notify({Title="Config",Content="Invalid config name"})
        return
    end
    local ok,reason=pcall(function()return configFor(configName):Save()end)
    if ok then saveSettings();refreshConfigs(configName) end
    nativeUI:Notify({Title="Config",Content=ok and ("Saved "..configName)
        or ("Save failed: "..tostring(reason))})
end})
configTab:Button({Title="Copy Config JSON",Callback=function()
    local exported={__version=1.2,__elements={}}
    for key,el in pairs(registry) do
        local value=el.Value
        if el.__type=="Slider" then value=value.Default end
        exported.__elements[key]={__type=el.__type,value=value}
    end
    local raw=HS:JSONEncode(exported)
    local cb=type(setclipboard)=="function" and setclipboard
        or (type(toclipboard)=="function" and toclipboard or nil)
    if cb then pcall(cb,raw) end
    print("[BeyyHub Winter Config Export] "..raw)
    nativeUI:Notify({Title="Config",Content="Copied config (also printed)"})
end})
configTab:Input({Title="Paste Config JSON",Value="",
    Callback=function(v)pastedJSON=tostring(v or "")end})
configTab:Button({Title="Import Config JSON",Callback=function()
    local raw=pastedJSON
    if raw=="" and type(getclipboard)=="function" then
        local ok,v=pcall(getclipboard)
        if ok then raw=tostring(v or "") end
    end
    if #raw>250000 then return end
    local ok,decoded=pcall(function()return HS:JSONDecode(raw)end)
    if not ok or type(decoded)~="table" then
        nativeUI:Notify({Title="Config",Content="Invalid JSON"})
        return
    end
    local applied=0
    for key,entry in pairs(decoded.__elements or decoded) do
        local el=registry[key]
        if el and type(entry)=="table" and entry.__type==el.__type then
            local appliedOK=pcall(function()
                if el.__type=="Dropdown" then el:Select(entry.value)
                else el:Set(entry.value) end
            end)
            if appliedOK then applied+=1 end
        end
    end
    saveSettings()
    nativeUI:Notify({Title="Config",Content="Imported "..tostring(applied).." controls"})
end})
configTab:Button({Title="Stop All Automation",Callback=function()
    state.BossFight=false
    for key,value in pairs(state) do
        if type(value)=="boolean" and (key:sub(1,4)=="Auto" or key:sub(1,3)=="Upg") then
            state[key]=false
            if registry[key] then registry[key]:Set(false) end
        end
    end
    attackEnabled=false
    saveSettings()
end})
configTab:Button({Title="Unload Hub",Callback=function()
    if type(env.BeyyWinterStop)=="function" then env.BeyyWinterStop() end
end})
labelStatus=function(s) pcall(function()bossStatus:SetDesc(s)end) end
-- The main menu starts open; only the actual Yeti encounter activates boss attacks.

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
local needleWorking=false
local function needlePriority()
    if needleWorking then return true end
    if player:GetAttribute("NeedleOwned")==true and state.AutoHandInNeedle then return true end
    if not state.AutoPickupNeedle or player:GetAttribute("NeedleOwned")==true then return false end
    local server=WS:FindFirstChild("NeedleObjectiveServer")
    local folder=server and server:FindFirstChild("Needle")
    if not folder then return false end
    for _,part in ipairs(folder:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective")==true then
            local hidden=part:GetAttribute("HIDDEN_WITHIN")
            if hidden==nil or hidden==false then return true end
        end
    end
    return false
end
local function needleActionBlocked()
    if not alive or player:GetAttribute("InWinterBoss")==true
        or player:GetAttribute("NeedleRoundComplete")==true then return true end
    for _,key in ipairs({"NeedleInputLocked","CutsceneActive","HintViewerOpen"}) do
        if player:GetAttribute(key)==true then return true end
    end
    return false
end
local function gameBlocked()
    if needleActionBlocked() or needlePriority() then return true end
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
    local server=WS:FindFirstChild("NeedleObjectiveServer")
    local folder=server and server:FindFirstChild("Needle")
    if not folder then return nil,nil end
    for _,part in ipairs(folder:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective")==true then
            local hidden=part:GetAttribute("HIDDEN_WITHIN")
            if hidden==nil or hidden==false then return part,part:GetAttribute("HayId") end
        end
    end
    return nil,nil
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
local bossCameraAim={
    lastSource=nil,lastAimAt=-math.huge,lastLogAt=-math.huge,
    offset=nil,renderConnection=nil,bindName="BeyyWinterBossCamera_"..tostring(player.UserId),
    boundWithPriority=false,errors=0,
    -- Camera-only smoothing state: keep targeting native live weak spots,
    -- but never snap the entire view every frame as the boss animates.
    smoothPosition=nil,smoothTarget=nil,tickAt=0,
    lastBoss=nil,lastCharacter=nil,
}
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
    bossCameraAim.offset=nil
    bossCameraAim.lastSource=nil
    bossCameraAim.smoothPosition=nil
    bossCameraAim.smoothTarget=nil
    bossCameraAim.tickAt=0
    bossCameraAim.lastBoss=nil
    bossCameraAim.lastCharacter=nil
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
        and bossInCombat(boss)
        and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0
        and bossDamageable(boss)
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
-- The live TNT controller remains independent; its boss ballistic targeting
-- also uses the currently exposed weak point when the config supplies one.
local tntState
-- Keep aiming through the FULL fighting state, even when Vacuum isn't firing
-- and even when the boss is temporarily shielded. Give the UI and cutscenes
-- priority over camera control so players never get trapped in a menu.
local function cameraBossReady()
    return alive and state.BossFight and state.BossCameraAim
        and not isMenuOpen()
        and player:GetAttribute("InWinterBoss")==true
        and boss and boss.Parent
        and bossInCombat(boss)
        and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0
        and not defeated and not blocked()
end
local function vacuumAdjustedWeakPoint(point,source,root)
    if not liveCritSource(source) or not root then
        vacuumCritTelemetry.aimSource=nil
        vacuumCritTelemetry.aimOffsetIndex=1
        vacuumCritTelemetry.bodyStreak=0
        return point
    end
    if vacuumCritTelemetry.aimSource~=source then
        vacuumCritTelemetry.aimSource=source
        vacuumCritTelemetry.aimOffsetIndex=1
        vacuumCritTelemetry.bodyStreak=0
    end
    local offset=critOffsets[vacuumCritTelemetry.aimOffsetIndex]
        or critOffsets[1]
    return point+root.CFrame:VectorToWorldSpace(
        Vector3.new(offset[1],offset[2],offset[3]))
end
local function cameraBossTarget()
    if not cameraBossReady() then return nil,nil end
    local head=headAndHumanoid()
    local hitbox=boss and (boss:FindFirstChild("BossHitbox")
        or boss:FindFirstChild("RootPart"))
    local root=boss and boss:FindFirstChild("RootPart")
    if not head or not hitbox or not hitbox:IsA("BasePart") then return nil,nil end
    local target,source=aimPoint(hitbox,head)
    if typeof(target)~="Vector3" then return nil,nil end
    -- A closest-point-on-surface fallback follows the player rather than
    -- the boss, so it flickers as hover/dodges change the approach angle.
    -- Between real weak windows, hold the fixed native BossHitbox center.
    -- Active live weak spots keep their exact native local/world geometry.
    if liveCritSource(source) then
        target=vacuumAdjustedWeakPoint(target,source,root)
    else
        target=hitbox.Position
    end
    return target,source
end
local function cameraTick()
    if not cameraBossReady() then
        restoreCamera()
        return
    end
    local camera=WS.CurrentCamera
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not camera or not root then
        restoreCamera()
        return
    end
    local target,source=cameraBossTarget()
    if not target then
        restoreCamera()
        return
    end
    if camSnapshot and camSnapshot.Camera~=camera then
        restoreCamera()
    end
    if bossCameraAim.lastBoss~=boss or bossCameraAim.lastCharacter~=character then
        bossCameraAim.lastBoss=boss
        bossCameraAim.lastCharacter=character
        bossCameraAim.smoothPosition=nil
        bossCameraAim.smoothTarget=nil
        bossCameraAim.tickAt=0
        bossCameraAim.lastSource=nil
    end
    if not camSnapshot then
        local offset=camera.CFrame.Position-root.Position
        if offset.Magnitude<4 then
            offset=-camera.CFrame.LookVector*14+Vector3.new(0,4,0)
        end
        if offset.Magnitude<0.05 then
            offset=Vector3.new(0,5,14)
        end
        offset=offset.Unit*math.clamp(offset.Magnitude,9,26)
        camSnapshot={
            Camera=camera,Type=camera.CameraType,
            Subject=camera.CameraSubject,
        }
        bossCameraAim.offset=offset
        logEvent("boss.cameraLocked",{target=source,distance=offset.Magnitude})
    end
    -- WINTER_YETI_STABLE_AIM_V1
    -- Ease the player's camera position and the Yeti aim point separately.
    -- Frame-rate-independent smoothing prevents camera snaps at weak-point
    -- changes and on the sharp lateral dodge/return movements.
    local now=os.clock()
    local dt=math.clamp(bossCameraAim.tickAt>0 and
        (now-bossCameraAim.tickAt) or 1/60,1/240,0.08)
    bossCameraAim.tickAt=now
    local desiredPosition=root.Position+
        (bossCameraAim.offset or Vector3.new(0,5,14))
    if (target-desiredPosition).Magnitude<5 then
        local away=desiredPosition-target
        if away.Magnitude<0.1 then away=Vector3.new(0,3,12) end
        desiredPosition=target+away.Unit*12
    end
    local previousPosition=bossCameraAim.smoothPosition
    if not previousPosition or (desiredPosition-previousPosition).Magnitude>35 then
        bossCameraAim.smoothPosition=desiredPosition
    else
        local alpha=1-math.exp(-dt*20)
        bossCameraAim.smoothPosition=previousPosition:Lerp(desiredPosition,alpha)
        -- Stay close to the actual character during high-speed Yeti dodges.
        local lag=desiredPosition-bossCameraAim.smoothPosition
        if lag.Magnitude>5 then
            bossCameraAim.smoothPosition=desiredPosition-lag.Unit*5
        end
    end
    local previousTarget=bossCameraAim.smoothTarget
    if not previousTarget or (target-previousTarget).Magnitude>60 then
        bossCameraAim.smoothTarget=target
    else
        -- Transition between exposed spots gently; track moving weak points
        -- faster once the source is stable to retain critical-hit accuracy.
        local rate=source==bossCameraAim.lastSource and 25 or 14
        bossCameraAim.smoothTarget=previousTarget:Lerp(
            target,1-math.exp(-dt*rate))
    end
    local cameraPosition=bossCameraAim.smoothPosition
    local aimPosition=bossCameraAim.smoothTarget
    if (aimPosition-cameraPosition).Magnitude<0.5 then
        aimPosition=cameraPosition+camera.CFrame.LookVector*6
    end
    local ok,err=pcall(function()
        camera.CameraType=Enum.CameraType.Scriptable
        camera.CFrame=CFrame.lookAt(cameraPosition,aimPosition,Vector3.yAxis)
    end)
    if not ok then
        bossCameraAim.errors+=1
        if bossCameraAim.errors<=3 then
            logEvent("boss.cameraError",tostring(err))
        end
        return
    end
    bossCameraAim.lastAimAt=os.clock()
    bossCameraAim.lastSource=source
    if os.clock()-bossCameraAim.lastLogAt>3 then
        bossCameraAim.lastLogAt=os.clock()
        logEvent("boss.cameraAim",{
            target=source,weak=liveCritSource(source),
            vacuumWeak=vacuumCritTelemetry.weak,
            vacuumBody=vacuumCritTelemetry.body,
            pitchforkWeak=critAssist.serverCrits,
            pitchforkBody=critAssist.serverBodyHits,
        })
    end
end
-- Bind the camera once, independent of the vacuum holding/cooling state.
-- Run AFTER Roblox's default camera update, and restore on menu or encounter
-- exit. Use RenderStepped only if BindToRenderStep is unavailable.
do
    local run=game:GetService("RunService")
    local ok,err=pcall(function()
        run:BindToRenderStep(
            bossCameraAim.bindName,Enum.RenderPriority.Camera.Value+2,cameraTick)
    end)
    if ok then
        bossCameraAim.boundWithPriority=true
    else
        bossCameraAim.renderConnection=run.RenderStepped:Connect(cameraTick)
        logEvent("boss.cameraBindFallback",tostring(err))
    end
end
-- With a centered Scriptable camera, the native suction center-ray AND
-- injected mouse cursor point at the exposed spot. Critical damage still
-- depends on the server's real range, line-of-sight, and weak-point checks.
local function vacuumWeakMouseTarget(camera)
    if not camera or not bossReady() or not state.BossWeakAim then
        return nil,"weakpoint not active" end
    local head=headAndHumanoid()
    local hitbox=boss and (boss:FindFirstChild("BossHitbox")
        or boss:FindFirstChild("RootPart"))
    if not head or not hitbox or not hitbox:IsA("BasePart") then
        return nil,"boss geometry missing" end
    local target,source=aimPoint(hitbox,head)
    if not liveCritSource(source) or typeof(target)~="Vector3" then
        return nil,"weakpoint unavailable" end
    local bossRoot=boss and boss:FindFirstChild("RootPart")
    target=vacuumAdjustedWeakPoint(target,source,bossRoot)
    local viewport=camera.ViewportSize
    if viewport.X<=0 or viewport.Y<=0 then return nil,"viewport unavailable" end
    local onScreenPoint,visible=camera:WorldToViewportPoint(target)
    if not visible or onScreenPoint.Z<=0 then
        return nil,"weakpoint off screen" end
    return Vector2.new(
        math.clamp(onScreenPoint.X,1,viewport.X-1),
        math.clamp(onScreenPoint.Y,1,viewport.Y-1)),source
end
local function vacuumCritMouseTick(mode,camera,immediate)
    if mode~="boss" or not VIM or not camera then return nil end
    if camSnapshot and camSnapshot.Camera==camera and state.BossCameraAim then
        -- Keep the native vacuum cursor precisely on the live exposed spot
        -- while the camera visually eases into its new orientation.
        local precise,source=vacuumWeakMouseTarget(camera)
        local center=precise or camera.ViewportSize/2
        if center.X>0 and center.Y>0 then
            local ok=pcall(function()
                VIM:SendMouseMoveEvent(center.X,center.Y,game)
            end)
            if ok then
                vacuumPoint=center
                vacuumCritTelemetry.lastStatus=precise and
                    "stabilized camera + live weakpoint cursor" or
                    "stabilized camera centered suction"
                vacuumCritTelemetry.lastSource=source or bossCameraAim.lastSource
                vacuumCritTelemetry.aimedFrames+=1
                return center
            end
        end
    end
    local point,source=vacuumWeakMouseTarget(camera)
    if not point then
        vacuumCritTelemetry.lastStatus=source
        return nil
    end
    local now=os.clock()
    local previous=vacuumCritTelemetry.lastTarget
    local moved=not previous or (point-previous).Magnitude>2
    if not immediate and not moved and now-vacuumCritTelemetry.lastAimAt<0.075 then
        return point
    end
    local ok,err=pcall(function()
        VIM:SendMouseMoveEvent(point.X,point.Y,game)
    end)
    if not ok then
        vacuumCritTelemetry.aimErrors+=1
        vacuumCritTelemetry.lastStatus="mouse move rejected"
        if vacuumCritTelemetry.aimErrors<=3 then
            logEvent("boss.vacuumCursorError",tostring(err))
        end
        return nil
    end
    vacuumPoint=point
    vacuumCritTelemetry.aimedFrames+=1
    vacuumCritTelemetry.lastAimAt=now
    vacuumCritTelemetry.lastTarget=point
    vacuumCritTelemetry.lastSource=source
    vacuumCritTelemetry.lastStatus="cursor tracking "..source
    if vacuumCritTelemetry.aimedFrames<=3
        or vacuumCritTelemetry.aimedFrames%80==0 then
        logEvent("boss.vacuumCursorAim",{
            weakpoint=source,x=math.round(point.X),y=math.round(point.Y),
            weakConfirmed=vacuumCritTelemetry.weak,
            bodyConfirmed=vacuumCritTelemetry.body,
        })
    end
    return point
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
-- Native Chapter 4-style heat/hold recovery for the winter Yeti vacuum.
-- An overheated hold must be RELEASED to allow cooldown to begin. The HUD
-- or VacuumHeat attribute can remain stale at 100% after VacuumState=Ready:
-- do not make the stale reading a permanent block when the game reports
-- readiness. Re-equip safely if native cooling stops progressing.
local vacuumWatch={
    lastHeat=nil,lastProgress=0,coolingSince=0,
    nextReselectAt=0,reselects=0,lastWarning=-math.huge,
}
local function vacuumHudHeat()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local hud=pg and pg:FindFirstChild("HUD")
    local overheat=hud and hud:FindFirstChild("Overheat")
    local fill=overheat and overheat:FindFirstChild("Fill")
    local value=fill and fill:IsA("GuiObject") and fill.Size.Y.Scale
    return type(value)=="number" and value>=0 and value<=1 and value or nil
end
local function vacuumHeatSnapshot()
    local attr=tonumber(player:GetAttribute("VacuumHeat"))
    if attr and (attr<0 or attr>1 or attr~=attr) then attr=nil end
    local hud=vacuumHudHeat()
    local heat=attr and hud and math.min(attr,hud) or (attr or hud)
    return heat,attr,hud
end
local function recoverVacuumEquip()
    if not alive or not VIM or not hubWindow.Closed then return false end
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    releaseVacuum()
    local ok=pcall(function()
        if humanoid then humanoid:UnequipTools() end
    end)
    task.wait(0.10)
    if not alive or not hubWindow.Closed or not vacuumMode() then return false end
    lastEquipAt=-math.huge
    local selected=selectVacuum(state.VacuumHotbarSlot)
    logEvent("vacuum.reselect",{sent=selected,unequipped=ok,
        overheated=player:GetAttribute("VacuumOverheated"),
        state=player:GetAttribute("VacuumState")})
    return selected
end
task.spawn(function()
    while alive do
        task.wait(0.07)
        local mode=vacuumMode()
        if not mode then
            releaseVacuum()
            -- The boss camera is an independent render-step controller.
            -- Cooling/idle vacuum must never unlock it during the fight.
            setVacStatus("Idle; input released")
            continue
        end
        if not VIM then
            setVacStatus("VirtualInputManager unavailable")
            continue
        end
        -- Camera targeting runs separately every render frame, even when
        -- vacuum ownership or cooldown gates prevent Mouse1 presses.
        if player:GetAttribute("VacuumOwned")~=true then
            releaseVacuum()
            setVacStatus("Vacuum is not owned")
            continue
        end
        local now=os.clock()
        local heat,attrHeat,hudHeat=vacuumHeatSnapshot()
        local vacuumState=player:GetAttribute("VacuumState")
        local nativeOverheated=player:GetAttribute("VacuumOverheated")==true
        local nativeReady=vacuumState=="Ready" and not nativeOverheated
        local levelLow=(heat==nil or heat<=0.025) and not nativeOverheated
        local topped=heat~=nil and heat>=0.985
        if heat~=nil and (vacuumWatch.lastHeat==nil
            or math.abs(heat-vacuumWatch.lastHeat)>=0.004) then
            vacuumWatch.lastHeat=heat
            vacuumWatch.lastProgress=now
        end

        if vacuumHeld then
            if mode=="boss" then
                vacuumCritMouseTick(mode,WS.CurrentCamera,false)
            end
            if nativeOverheated or (topped and not nativeReady) then
                releaseVacuum()
                vacuumCooling=true
                vacuumWatch.coolingSince=now
                vacuumWatch.lastProgress=now
                vacuumRestUntil=now+0.15
                logEvent("vacuum.overheatRelease",{
                    heat=heat,attr=attrHeat,hud=hudHeat,
                    state=vacuumState,overheated=nativeOverheated
                })
                setVacStatus("Vacuum overheating; released Mouse1 to cool")
                continue
            end
            local stalled=heat~=nil and now-vacuumWatch.lastProgress>=4.0
                and player:GetAttribute("VacuumActive")~=true
            if stalled or (player:GetAttribute("VacuumActive")==false
                and now-vacuumStarted>=3.0) then
                releaseVacuum()
                vacuumRestUntil=now+0.22
                lastEquipAt=-math.huge
                vacuumWatch.nextReselectAt=now
                logEvent("vacuum.staleHold",{
                    heat=heat,active=player:GetAttribute("VacuumActive"),
                    state=vacuumState,
                })
                setVacStatus("Vacuum stopped responding; releasing and reselecting")
                continue
            end
            if heat==nil and now-vacuumStarted>=25 then
                releaseVacuum()
                vacuumRestUntil=now+(tonumber(player:GetAttribute("VacuumCoolTime")) or 13.5)
                setVacStatus("Waiting native vacuum runtime cooldown")
                continue
            end
            setVacStatus(mode=="boss" and
                ("Vacuum attacking Yeti | "..vacuumCritTelemetry.lastStatus
                    ..string.format(" | weak %d / body %d",
                        vacuumCritTelemetry.weak,vacuumCritTelemetry.body))
                or "Vacuum harvesting hay")
            continue
        end

        if vacuumCooling then
            if nativeReady or levelLow then
                vacuumCooling=false
                vacuumWatch.coolingSince=0
                vacuumRestUntil=now+0.12
                lastEquipAt=-math.huge
                logEvent("vacuum.cooldownReady",{
                    heat=heat,attr=attrHeat,hud=hudHeat,
                    state=vacuumState,nativeReady=nativeReady
                })
            else
                if vacuumWatch.coolingSince==0 then
                    vacuumWatch.coolingSince=now
                end
                local coolingAge=now-vacuumWatch.coolingSince
                local stuck=coolingAge>=4.0
                    and now-vacuumWatch.lastProgress>=3.5
                if stuck and now>=vacuumWatch.nextReselectAt then
                    vacuumWatch.nextReselectAt=now+8
                    vacuumWatch.reselects+=1
                    if now-vacuumWatch.lastWarning>=8 then
                        vacuumWatch.lastWarning=now
                        warn("[Winter Vacuum] Heat stuck during cooling; refreshing native vacuum equip")
                    end
                    logEvent("vacuum.cooldownStalled",{
                        seconds=coolingAge,heat=heat,attr=attrHeat,hud=hudHeat,
                        nativeState=vacuumState,attempt=vacuumWatch.reselects
                    })
                    recoverVacuumEquip()
                    continue
                end
                setVacStatus(string.format(
                    "Vacuum cooling %.0f%% | %s",
                    (heat or 1)*100,tostring(vacuumState or "waiting")))
                continue
            end
        end

        if now<vacuumRestUntil then continue end
        if now>=vacuumWatch.nextReselectAt
            and vacuumWatch.nextReselectAt>0
            and player:GetAttribute("VacuumActive")==false
            and not nativeReady and not levelLow then
            vacuumWatch.nextReselectAt=now+8
            recoverVacuumEquip()
            continue
        end
        if not nativeReady and nativeOverheated then
            vacuumCooling=true
            if vacuumWatch.coolingSince==0 then vacuumWatch.coolingSince=now end
            continue
        end
        if not nativeReady and topped then
            vacuumCooling=true
            if vacuumWatch.coolingSince==0 then vacuumWatch.coolingSince=now end
            continue
        end

        if now-lastEquipAt>=1.2 then
            lastEquipAt=now
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
            local point=vacuumCritMouseTick(mode,camera,true)
            vacuumPoint=point or camera.ViewportSize/2
            local pressed=pcall(function()
                -- Ensure a fresh Mouse1 press after every heat cycle.
                VIM:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
                task.wait(0.035)
                VIM:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,true,game,0)
            end)
            if pressed and vacuumMode()==mode then
                vacuumHeld=true
                vacuumStarted=os.clock()
                vacuumWatch.lastHeat=heat
                vacuumWatch.lastProgress=vacuumStarted
                logEvent("vacuum.hold",{
                    mode=mode,heat=heat,nativeReady=nativeReady,
                    state=vacuumState
                })
            else
                releaseVacuum()
            end
        end
    end
    releaseVacuum()
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

-- Single native TNT controller shared by hay farming and the winter boss.
-- Native TntAction("light") ACK is required before TntAction("throw", cf, velocity).
-- The in-flight TNT stays owned by its original mode, avoiding a competing
-- boss/farm light request or an accidental throw during a scene transition.
tntState={
    phase="idle",mode=nil,nextAt=0,pendingUntil=0,
    fuseExpires=0,attempts=0,throwAttempts=0,retryAt=0,litAt=0,
    sawReplicatedLit=false,throwFeedback=false,
    firstHayWaitUntil=0,firstHayStarted=false,firstHayUsed=false,
}
local tntConnection=nil
local tntRemote=nil
local tntGameConfig=nil
local tntConfigRetry=0
local function nativeTntCooldown()
    local cd=tonumber(player:GetAttribute("TntCooldown"))
    if not cd or cd<=0 or cd~=cd or cd==math.huge then cd=20 end
    -- Follow the game's live upgraded cooldown; never add a user timing override.
    return math.max(0.05,cd)
end
local function getTntGameConfig()
    if tntGameConfig then return tntGameConfig end
    if os.clock()<tntConfigRetry then return nil end
    tntConfigRetry=os.clock()+3
    -- The captured winter client exposes TNT throw limits here;
    -- ReplicatedStorage.Shared.Configs.GameConfig is NOT replicated.
    local needle=RS:FindFirstChild("NeedleHaystack")
    local module=needle and needle:FindFirstChild("Config")
    if module and module:IsA("ModuleScript") then
        local ok,value=pcall(require,module)
        if ok and type(value)=="table" then
            tntGameConfig=value
            return value
        end
    end
    return nil
end
local function tntThrowLimits()
    local config=getTntGameConfig()
    local min=tonumber(config and config.MIN_THROW_SPEED) or 2
    local max=tonumber(config and config.TNT_MAX_THROW_SPEED) or 78
    if min<=0 or max<min or max==math.huge then return 2,78 end
    return min,max
end
local function tntBossReady()
    return state.BossFight and state.BossTNT
        and hubWindow.Closed and bossReady()
end
local function tntFarmReady()
    -- Native remote throws do not need a locked mouse or closed hub menu.
    return state.AutoUseTNT and not gameBlocked()
        and player:GetAttribute("InWinterBoss")~=true
end
local function currentTntMode()
    if tntBossReady() then return "boss" end
    if tntFarmReady() then return "hay" end
    return nil
end
local function tntAim(mode)
    local camera=WS.CurrentCamera
    if not camera then return nil end
    local cf=camera.CFrame
    local forward=cf.LookVector
    if forward.Magnitude<0.5 then return nil end
    local min,max=tntThrowLimits()
    if mode=="boss" and bossReady() then
        local head=headAndHumanoid()
        local hitbox=boss and (boss:FindFirstChild("BossHitbox")
            or boss:FindFirstChild("RootPart"))
        if head and hitbox and hitbox:IsA("BasePart") then
            local point,source=aimPoint(hitbox,head)
            if typeof(point)=="Vector3" and liveCritSource(source) then
                -- The boss is the ONE exception to manual TNT gaze: an
                -- exposed live weak point has priority. Chapter 3's
                -- ballistic arc accounts for gravity, unlike a flat gaze.
                local charHead=player.Character
                    and player.Character:FindFirstChild("Head")
                local origin=charHead and
                    charHead.CFrame*CFrame.new(0.8,-0.8,-1.5) or cf
                local displacement=point-origin.Position
                if displacement.Magnitude>0.25 then
                    for step=9,80 do
                        local flight=step*0.025
                        local velocity=displacement/flight
                            +Vector3.new(0,WS.Gravity*flight*0.5,0)
                        if velocity.Magnitude>=min and velocity.Magnitude<=max then
                            logEvent("tnt.bossCritTrajectory",{
                                spot=source,flight=flight,speed=velocity.Magnitude
                            })
                            return origin,velocity
                        end
                    end
                    logEvent("tnt.bossCritUnavailable",{
                        spot=source,range=displacement.Magnitude
                    })
                end
            end
        end
    end
    -- Hay TNT stays exactly aligned with the live player camera, including
    -- the fixed first-use wait before the light command. Boss falls back to
    -- view direction if no valid critical trajectory is available.
    local velocity=forward.Unit*math.clamp(40,min,max)
    return cf,velocity
end
local function nativeLitPhase()
    local phase=player:GetAttribute("TntPhase")
    if type(phase)~="string" then return "" end
    return phase:lower()
end
local function tntFuseTime()
    local cfg=getTntGameConfig()
    return math.max(0.3,tonumber(cfg and cfg.TNT_FUSE_TIME) or 2.9)
end
local function tntLightTime()
    local cfg=getTntGameConfig()
    return math.max(0,tonumber(cfg and cfg.TNT_LIGHT_TIME) or 0.48)
end
local function tntMarkLit(reason)
    local now=os.clock()
    tntState.phase="lit"
    tntState.litAt=now
    tntState.throwAttempts=0
    tntState.retryAt=now
    tntState.sawReplicatedLit=(nativeLitPhase()=="lit")
    tntState.throwFeedback=false
    -- Preserve any authoritative fuse duration supplied in the server ACK.
    if tntState.fuseExpires<=now then
        tntState.fuseExpires=now+tntFuseTime()
    end
    tntState.nextAt=math.max(tntState.nextAt,now+nativeTntCooldown())
    logEvent("tnt.ready",{mode=tntState.mode,source=reason})
end
local function bindTnt()
    local current=nativeFarm("TntAction")
    if current==tntRemote and tntConnection and tntConnection.Connected then
        return current
    end
    if tntConnection then tntConnection:Disconnect();tntConnection=nil end
    if tntRemote~=current then
        tntState.phase="idle"
        tntState.mode=nil
    end
    tntRemote=current
    if not current then return nil end
    tntConnection=current.OnClientEvent:Connect(function(action,value)
        local now=os.clock()
        if action=="lit" and tntState.phase=="waiting" then
            local fuse=tonumber(value)
            if not fuse or fuse<=0.1 or fuse>15 then fuse=tntFuseTime() end
            tntState.fuseExpires=now+fuse
            tntMarkLit("native lit acknowledgment")
        elseif action=="thrown" or action=="throw" then
            -- Optional native completion feedback (not available every build).
            if tntState.phase=="verify" or tntState.phase=="lit" then
                tntState.throwFeedback=true
                logEvent("tnt.throwFeedback",safeValue(value))
            end
        elseif action=="denied" and tntState.phase=="waiting" then
            tntState.phase="idle"
            tntState.mode=nil
            local retry=math.max(0.25,(tonumber(value) or 1)+0.05)
            tntState.nextAt=now+retry
            logEvent("tnt.denied",{retry=retry})
        end
    end)
    return current
end
task.spawn(function()
    while alive do
        task.wait(0.06)
        local remote=bindTnt()
        if not remote then continue end
        local now=os.clock()
        local nativePhase=nativeLitPhase()
        if nativePhase=="lit" and
            (tntState.phase=="lit" or tntState.phase=="verify") then
            tntState.sawReplicatedLit=true
        end
        if tntState.phase=="idle" and nativePhase=="lit" then
            local mode=currentTntMode()
            if mode then
                tntState.mode=mode
                tntMarkLit("replicated TntPhase (missed lighting ACK)")
            end
        end
        if tntState.phase=="waiting" then
            if nativePhase=="lit" then
                tntMarkLit("replicated TntPhase")
            elseif now>=tntState.pendingUntil then
                tntState.phase="idle"
                tntState.mode=nil
                logEvent("tnt.timeout",{phase=nativePhase})
            end
            continue
        end
        if tntState.phase=="lit" or tntState.phase=="verify" then
            if now>=tntState.fuseExpires-0.1 then
                tntState.phase="idle"
                tntState.mode=nil
                logEvent("tnt.fuseExpired",{phase=nativePhase})
                continue
            end
            -- The tool can become lit while auto-farm changes to boss.
            -- Do not abandon an already-lit charge in the player's hand.
            if tntState.phase=="verify" then
                local visiblyLeftLit=tntState.sawReplicatedLit
                    and nativePhase~="lit" and nativePhase~="lighting"
                    and nativePhase~="primed"
                if tntState.throwFeedback or visiblyLeftLit then
                    logEvent("tnt.throwConfirmed",{phase=nativePhase,
                        attempts=tntState.throwAttempts,
                        feedback=tntState.throwFeedback})
                    tntState.phase="idle"
                    tntState.mode=nil
                    continue
                end
                if now<tntState.retryAt then continue end
                if tntState.throwAttempts>=4 then
                    -- A successful Lua remote call is NOT server confirmation.
                    -- Don't report success just because TntPhase was idle even
                    -- before lighting. Stop bounded retries until fuse expiry.
                    if tntState.throwAttempts==4 then
                        tntState.throwAttempts=5
                        warn("[BeyyHub Winter TNT] Four throw requests sent with no confirmation; check TntAction feedback")
                        logEvent("tnt.throwUnconfirmed",{phase=nativePhase})
                    end
                    continue
                end
                tntState.phase="lit"
            end
            -- Respect the game's native lighting state. Some clients receive
            -- a lit ACK while the replicated "lighting" animation is active.
            if nativePhase=="lighting" and now<tntState.litAt+tntLightTime() then
                continue
            end
            local cf,velocity=tntAim(tntState.mode)
            if not cf or not velocity then
                logEvent("tnt.noThrowVector",{phase=nativePhase})
                continue
            end
            local ok,err=pcall(remote.FireServer,remote,"throw",cf,velocity)
            tntState.throwAttempts+=1
            tntState.retryAt=now+0.23
            if ok then
                tntState.phase="verify"
                logEvent("tnt.throwSent",{mode=tntState.mode,
                    speed=velocity.Magnitude,attempt=tntState.throwAttempts,
                    direction=tostring(cf.LookVector),
                    nativePhase=nativePhase})
            else
                tntState.phase="lit"
                logEvent("tnt.throwError",tostring(err))
            end
            continue
        end
        local mode=currentTntMode()
        if not mode or player:GetAttribute("TntOwned")~=true
            or now<tntState.nextAt then continue end
        if mode=="hay" and not tntState.firstHayUsed then
            if not tntState.firstHayStarted then
                tntState.firstHayStarted=true
                tntState.firstHayWaitUntil=now+5
                print("[BeyyHub Winter TNT] First hay throw: giving you 5 seconds to face the target before lighting")
                logEvent("tnt.initialHayWait",{seconds=5})
            end
            if now<tntState.firstHayWaitUntil then continue end
            -- Delay BEFORE the first ignition, never during an active fuse.
            -- Only the first hay TNT cycle receives this fixed delay.
            tntState.firstHayUsed=true
            logEvent("tnt.initialHayWaitFinished","First hay TNT lighting permitted")
        end
        tntState.phase="waiting"
        tntState.mode=mode
        tntState.pendingUntil=now+2
        tntState.fuseExpires=0
        tntState.nextAt=now+nativeTntCooldown()
        local ok,err=pcall(remote.FireServer,remote,"light")
        if ok then
            tntState.attempts+=1
            logEvent("tnt.light",{mode=mode,attempt=tntState.attempts})
        else
            tntState.phase="idle"
            tntState.mode=nil
            tntState.nextAt=now+0.5
            logEvent("tnt.lightError",tostring(err))
        end
    end
end)
task.spawn(function()
    local lastDroneRequest=-math.huge
    while alive do
        task.wait(math.max(0.2,tonumber(state.ToolInterval) or 0.5))
        if gameBlocked() then continue end
        if state.AutoDeployDrone and player:GetAttribute("DroneOwned")==true
            and player:GetAttribute("DroneDeployed")~=true
            and os.clock()-lastDroneRequest>=1.5 then
            lastDroneRequest=os.clock()
            local ok=farmSend("DeployDrone")
            if not ok then logEvent("drone.deploy","native DeployDrone unavailable") end
        end
        if state.AutoUsePitchfork and player:GetAttribute("PitchforkOwned")==true then
            local _,id=nearest("HaystackClient","HayId",30)
            if id~=nil then farmSend("PitchforkDig",id) end
        end
    end
end)
-- Chapter 1 style needle sequence:
-- (1) teleport to verified revealed needle, (2) native PickHay("Objective"),
-- (3) aimed mouse pickup fallback, (4) teleport to Farmer_NPC and hand in.
-- No Humanoid:MoveTo is used for needle objectives or Farmer turn-in.
-- Chapter 1's pickup/hand-in controllers, Winter map adapters only:
-- 100k-hay spatial filter; native remotes and session state.
local needleRun=game:GetService("RunService")
local needleStop=function()end
local handInKick=function(_)end
do
(function()
    local settings={
        HeightAboveNeedle=2.5,HorizontalOffsetStuds=2.0,
        MaxClicks=8,MousePressSeconds=0.085,OwnershipWaitSeconds=0.055,
        RetryDelay=0.16,FilterRadiusPixels=50,
        FilterNeedleRadiusStuds=8,FilterMaxParts=400,
    }
    local aimRenderName="BeyyWinterCh1Aim_"..tostring(player.UserId)
    local trackedNeedle=nil
    local confirmedNeedlePart,confirmedNeedleId=nil,nil
    local activeNeedleCleanup=nil
    local lastAttempt=-math.huge
    local lastPrerequisiteWarnAt=-math.huge
    local lastPickupFailureWarnAt=-math.huge
    local function reportPrerequisite(reason)
        if os.clock()-lastPrerequisiteWarnAt>=30 then
            lastPrerequisiteWarnAt=os.clock()
            warn("[Winter Needle] Waiting: "..tostring(reason))
        end
    end
    local function owned()return player:GetAttribute("NeedleOwned")==true end
    local function tryPickup(needle)
        if needleWorking or not alive or needleActionBlocked() or not (state.AutoPickupNeedle) or owned() or not needle or not needle.Parent then return false end
        needleWorking = true
        needleWorking = true
        local started = os.clock()
        if not VIM then
            reportPrerequisite("VirtualInputManager unavailable")
            needleWorking=false
            return false
        end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = WS.CurrentCamera
        local needleId = needle:GetAttribute("HayId")
        if not char or not char.Parent or not root or not root.Parent then
            reportPrerequisite("character or HumanoidRootPart unavailable")
            needleWorking = false
            needleWorking = false
            return false
        end
        if not cam then
            reportPrerequisite("WS.CurrentCamera unavailable")
            needleWorking = false
            needleWorking = false
            return false
        end
        if type(needleId) ~= "number" and needle:GetAttribute("IsNeedleObjective") ~= true then
            reportPrerequisite("needle HayId invalid (type=" .. type(needleId) .. "); refreshing target")
            trackedNeedle=nil
            needleWorking = false
            needleWorking = false
            return false
        end
        local initialPivot = char:GetPivot()
        local originalHover = player:GetAttribute("HoveredHayId")
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
            -- Same Chapter 1 two-pass near/screen filter, but spatially
            -- bounded for Winter's approximately 100,000 hay parts.
            local currentCam=WS.CurrentCamera
            if not currentCam or not needle.Parent then return end
            local screen=currentCam.ViewportSize
            if screen.Y<=0 then return end
            local middle=screen/2
            local projectedNeedle=currentCam:WorldToViewportPoint(needle.Position)
            local focal=screen.Y/(2*math.tan(math.rad(currentCam.FieldOfView/2)))
            local folders={}
            for _,name in ipairs({"HaystackClient","HaystackCollision"}) do
                local folder=WS:FindFirstChild(name)
                if folder then folders[#folders+1]=folder end
            end
            if #folders==0 then return end
            local overlap=OverlapParams.new()
            overlap.FilterType=Enum.RaycastFilterType.Include
            overlap.FilterDescendantsInstances=folders
            overlap.MaxParts=700
            local ok,parts=pcall(function()
                return WS:GetPartBoundsInRadius(needle.Position,15,overlap)
            end)
            if not ok then return end
            for pass=1,2 do
                if queryStats.filtered>=settings.FilterMaxParts then break end
                for _,part in ipairs(parts) do
                    if not alive or not state.AutoPickupNeedle or observedOwnership then return end
                    if part:IsA("BasePart") and part~=needle
                        and part:GetAttribute("IsNeedleObjective")~=true
                        and part.CanQuery and not filteredParts[part] then
                        local near=(part.Position-needle.Position).Magnitude
                            <=settings.FilterNeedleRadiusStuds
                            +math.min(part.Size.Magnitude*0.5,4)
                        local qualifies=(pass==1 and near)
                        if pass==2 and not near then
                            local proj=currentCam:WorldToViewportPoint(part.Position)
                            if proj.Z>0 and proj.Z<45 then
                                local radius=(part.Size.Magnitude*0.5)*focal/proj.Z
                                local dc=(Vector2.new(proj.X,proj.Y)-middle).Magnitude
                                local dn=(Vector2.new(proj.X,proj.Y)
                                    -Vector2.new(projectedNeedle.X,projectedNeedle.Y)).Magnitude
                                qualifies=dc<=settings.FilterRadiusPixels+radius
                                    or (projectedNeedle.Z>0
                                        and dn<=settings.FilterRadiusPixels+radius)
                            end
                        end
                        if qualifies then
                            local oldQuery,oldCollide=part.CanQuery,part.CanCollide
                            local changed=pcall(function()
                                if part.CanCollide then part.CanCollide=false end
                                part.CanQuery=false
                            end)
                            if changed and not part.CanQuery then
                                filteredParts[part]={query=oldQuery,collide=oldCollide}
                                queryStats.filtered+=1
                            else
                                pcall(function()
                                    part.CanCollide=oldCollide
                                    part.CanQuery=oldQuery
                                end)
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
        ownershipConnection = player:GetAttributeChangedSignal("NeedleOwned"):Connect(captureOwnership)
        captureOwnership()
        local function releaseMouse()
            if not mouseDown then return end
            local center = cam.ViewportSize / 2
            pcall(function() VIM:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0) end)
            mouseDown = false
        end
        local function waitForConfirmation(seconds)
            local deadline = os.clock() + seconds
            while alive and (state.AutoPickupNeedle) and os.clock() < deadline do
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
                pcall(function() needleRun:UnbindFromRenderStep(aimRenderName) end)
                bound = false
            end
            if pickupCameraCaptured and cam.Parent then
                pcall(function()

                    local restoreType=previousPickupCameraType or Enum.CameraType.Custom
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
                if player:GetAttribute("HoveredHayId") == needleId then
                    player:SetAttribute("HoveredHayId", originalHover)
                end
            end)
            if success then
                confirmedNeedlePart, confirmedNeedleId = needle, needleId
            elseif char.Parent then
                pcall(function() char:PivotTo(initialPivot) end)
            end
            local elapsed = os.clock() - started
            logEvent("needle.ch1Pickup",{success=success,hayId=needleId,
                clicks=clicks,elapsed=elapsed,reason=failureReason,
                filtered=queryStats.filtered})
            if success then
                print(string.format("[Needle] Picked up HayId=%s in %.2fs (%d clicks)",
                    tostring(needleId), elapsed, clicks))
            elseif os.clock() - lastPickupFailureWarnAt >= 2 then
                lastPickupFailureWarnAt = os.clock()
                warn(string.format("[Needle] Pickup unconfirmed HayId=%s after %.2fs: %s (%d clicks); retrying",
                    tostring(needleId), elapsed, tostring(failureReason), clicks))
            end
            activeNeedleCleanup = nil
            needleWorking = false
            if success and state.AutoHandInNeedle then
                -- Start the Farmer sequence after the pickup camera unlocks.
                task.defer(handInKick,"pickup completed")
            end
            lastAttempt = os.clock()
        end
        activeNeedleCleanup = cleanup
        local ok, err = xpcall(function()

            previousPickupCameraType = cam.CameraType
            previousPickupCameraSubject = cam.CameraSubject
            previousPickupCameraCFrame = cam.CFrame
            pickupCameraCaptured = true
            if not hubWindow.Closed then hubWindow:Close() end
            releaseVacuum()
            restoreCamera()
            if not alive or not (state.AutoPickupNeedle) then failureReason = "Pickup cancelled before teleport"; return end
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
            local targetRootPosition = needle.Position - horizontalForward * settings.HorizontalOffsetStuds
                + Vector3.new(0, settings.HeightAboveNeedle, 0)
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
            if not alive or not (state.AutoPickupNeedle) or needleActionBlocked() or not needle.Parent then
                failureReason = "Pickup cancelled before native request"; return
            end
            captureOwnership()
            if observedOwnership then success = true; return end
            local pickupRemote=nativeFarm("PickHay")
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
                if not alive or not needle.Parent or observedOwnership or needleActionBlocked() then return end
                if WS.CurrentCamera ~= cam then return end
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.lookAt(cameraPosition, needle.Position, Vector3.yAxis)
            end
            placeNearNeedle()
            captureOwnership()
            if observedOwnership then success = true; return end
            local function forceHover()
                if alive and (state.AutoPickupNeedle) and needle.Parent and not observedOwnership then
                    aimAtNeedle()
                    if player:GetAttribute("HoveredHayId") ~= needleId then
                        player:SetAttribute("HoveredHayId", needleId)
                    end
                end
            end
            player:SetAttribute("HoveredHayId", needleId)
            aimAtNeedle()
            needleRun:BindToRenderStep(aimRenderName, Enum.RenderPriority.Last.Value + 30, forceHover)
            bound = true
            needleRun.RenderStepped:Wait()
            applyQueryFilter()

            needleRun.RenderStepped:Wait()
            for i = 1, settings.MaxClicks do
                captureOwnership()
                if observedOwnership then success = true; break end
                if not alive or not (state.AutoPickupNeedle) or needleActionBlocked() then failureReason = "Pickup cancelled at round end"; break end
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
                pcall(function() VIM:SendMouseMoveEvent(center.X, center.Y, game) end)
                needleRun.RenderStepped:Wait()
                forceHover()
                local hoverMatches = player:GetAttribute("HoveredHayId") == needleId
                local projectedNeedle, onScreen = cam:WorldToViewportPoint(needle.Position)
                local screenOffset = onScreen and (Vector2.new(projectedNeedle.X, projectedNeedle.Y) - center).Magnitude or -1
                if not hoverMatches then
                    player:SetAttribute("HoveredHayId", needleId)
                    needleRun.RenderStepped:Wait()
                    forceHover()
                    hoverMatches = player:GetAttribute("HoveredHayId") == needleId
                end
                if not hoverMatches then
                    failureReason = "HoveredHayId temporarily lost; re-aiming"
                    if i < settings.MaxClicks then continue end
                    break
                end
                if not onScreen or screenOffset > 15 then
                    failureReason = "Needle camera off-centre; re-aiming"
                    if i < settings.MaxClicks then
                        placeNearNeedle()
                        needleRun.RenderStepped:Wait()
                        forceHover()
                        continue
                    end
                    break
                end
                local pressed, pressErr = pcall(function()
                    VIM:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                end)
                if not pressed then failureReason = "VIM press failed: " .. tostring(pressErr); break end
                clicks += 1
                mouseDown = true
                task.wait(i <= 2 and settings.MousePressSeconds or 0.10)
                releaseMouse()
                if waitForConfirmation(i <= 2 and settings.OwnershipWaitSeconds or 0.10) then success = true; break end
                if i == 4 then applyQueryFilter() end
            end
            captureOwnership()
            success = success or observedOwnership
        end, function(e) return tostring(e) end)
        if not ok then failureReason = "Runtime error: " .. tostring(err) end
        cleanup()
        return success
    end

    task.spawn(function()
        while alive do
            task.wait(0.05)
            if needleActionBlocked() or not state.AutoPickupNeedle or owned() then
                trackedNeedle=nil
            else
                if not trackedNeedle or not trackedNeedle.Parent
                    or trackedNeedle:GetAttribute("IsNeedleObjective")~=true
                    or trackedNeedle:GetAttribute("HIDDEN_WITHIN")==true then
                    trackedNeedle=winterNeedle()
                end
                if trackedNeedle and trackedNeedle==confirmedNeedlePart
                    and trackedNeedle:GetAttribute("HayId")==confirmedNeedleId then
                    continue
                end
                if trackedNeedle and not needleWorking
                    and os.clock()-lastAttempt>=settings.RetryDelay then
                    lastAttempt=os.clock()
                    local target=trackedNeedle
                    task.spawn(function()tryPickup(target)end)
                end
            end
        end
    end)
    -- Fast Winter Farmer turn-in. An ownership/ready event schedules the
    -- first approach directly; bounded early retries cover position
    -- replication without assuming that FireServer means server acceptance.
    local handin={
        ownedAt=0,firstRequestAt=0,lastRequestAt=-math.huge,
        nextRequestAt=0,nextPositionAt=0,positionAt=0,
        positioned=false,character=nil,requests=0,corrections=0,
        readyTransitions=0,remoteErrors=0,lastStatusAt=-math.huge,
        finished=false,
    }
    local function canHandIn()
        return alive and state.AutoHandInNeedle
            and player:GetAttribute("NeedleOwned")==true
            and player:GetAttribute("NeedleRoundComplete")~=true
            and player:GetAttribute("InWinterBoss")~=true
    end
    local function trace(kind,data)
        logEvent("needle.handin."..kind,data)
    end
    local function resetHandIn(reason)
        if handin.firstRequestAt>0 then
            trace("complete",{
                reason=reason,requests=handin.requests,
                corrections=handin.corrections,
                elapsed=os.clock()-handin.firstRequestAt,
                readyTransitions=handin.readyTransitions,
            })
        end
        handin.ownedAt=0
        handin.firstRequestAt=0
        handin.lastRequestAt=-math.huge
        handin.nextRequestAt=0
        handin.nextPositionAt=0
        handin.positionAt=0
        handin.positioned=false
        handin.character=nil
        handin.requests=0
        handin.corrections=0
        handin.readyTransitions=0
        handin.finished=false
    end
    local function farmerPivot()
        local npc=WS:FindFirstChild("NPC")
        local farmer=npc and npc:FindFirstChild("Farmer_NPC")
        return farmer and farmer:GetPivot() or nil
    end
    local function approachFarmer(rootPart,pivot,now)
        local ready=player:GetAttribute("NeedleNpcReady")==true
        local distance=(rootPart.Position-pivot.Position).Magnitude
        local first=not handin.positioned
        local far=distance>8.5
        local reposition=handin.positioned and not ready
            and now-handin.positionAt>=0.48
            and handin.requests>=2 and handin.corrections<3
        if not first and not far and not reposition then
            return true,distance
        end
        if now<handin.nextPositionAt then return false,distance end
        local offsets={3.5,2.6,3.2}
        local step=handin.corrections+1
        local at=(pivot*CFrame.new(0,0,offsets[math.min(step,#offsets)])).Position
        local face=Vector3.new(pivot.Position.X,at.Y,pivot.Position.Z)
        local target=(face-at).Magnitude>0.1 and CFrame.lookAt(at,face)
            or CFrame.new(at)
        local ok,err=pcall(function()
            rootPart.CFrame=target
            rootPart.AssemblyLinearVelocity=Vector3.zero
            rootPart.AssemblyAngularVelocity=Vector3.zero
        end)
        if not ok then
            handin.nextPositionAt=now+0.3
            if now-handin.lastStatusAt>=1 then
                handin.lastStatusAt=now
                warn("[Winter HandIn] Farmer position failed: "..tostring(err))
            end
            return false,distance
        end
        handin.positioned=true
        handin.positionAt=now
        handin.corrections=step
        handin.nextPositionAt=now+0.28
        handin.nextRequestAt=now+0.10
        trace("position",{
            attempt=step,distanceBefore=distance,
            distanceAfter=(rootPart.Position-pivot.Position).Magnitude,
            offset=offsets[math.min(step,#offsets)],ready=ready,
        })
        return true,(rootPart.Position-pivot.Position).Magnitude
    end
    local function attemptHandIn(source)
        if not canHandIn() or needleWorking then return end
        local now=os.clock()
        if handin.ownedAt==0 then
            handin.ownedAt=now
            trace("owned",{source=source,ready=player:GetAttribute("NeedleNpcReady")})
        end
        local char=player.Character
        local rootPart=char and char:FindFirstChild("HumanoidRootPart")
        local pivot=farmerPivot()
        if not rootPart or not pivot then
            if now-handin.lastStatusAt>=1.5 then
                handin.lastStatusAt=now
                trace("waiting",{hasRoot=rootPart~=nil,hasFarmer=pivot~=nil})
            end
            return
        end
        if handin.character~=char then
            handin.character=char
            handin.positioned=false
            handin.nextPositionAt=0
        end
        local placed,distance=approachFarmer(rootPart,pivot,now)
        if not placed or distance>9 then return end
        local ready=player:GetAttribute("NeedleNpcReady")==true
        if source=="npc-ready" then
            if not ready or now-handin.lastRequestAt<0.05 then return end
        elseif now<handin.nextRequestAt then
            return
        end
        -- Let the server observe the new root position before requesting.
        -- A server-provided NPC-ready pulse is immediate proof of proximity.
        if not ready and now-handin.positionAt<0.10 then return end
        local remote=nativeFarm("NeedleHandIn")
        if not remote then
            handin.nextRequestAt=now+0.25
            if now-handin.lastStatusAt>=1 then
                handin.lastStatusAt=now
                warn("[Winter HandIn] Native NeedleHandIn remote missing")
            end
            return
        end
        handin.requests+=1
        handin.lastRequestAt=now
        if handin.firstRequestAt==0 then handin.firstRequestAt=now end
        local sinceOwned=now-handin.ownedAt
        handin.nextRequestAt=now+(sinceOwned<1.1 and 0.15 or 0.25)
        local ok,err=pcall(remote.FireServer,remote)
        if not ok then handin.remoteErrors+=1 end
        if handin.requests<=5 or source=="npc-ready"
            or handin.requests%8==0 or not ok then
            trace("request",{
                attempt=handin.requests,source=source,sent=ok,
                distance=distance,ready=ready,sinceOwned=sinceOwned,
                sinceTeleport=now-handin.positionAt,
                error=not ok and tostring(err) or nil,
            })
        end
        if handin.requests<=2 or source=="npc-ready" then
            pcall(function()
                needleStatus:SetDesc(ready and
                    "Farmer ready • hand-in sent; waiting for server"
                    or "At Farmer • waiting for hand-in confirmation")
            end)
        end
    end
    handInKick=attemptHandIn
    connections[#connections+1]=player:GetAttributeChangedSignal("NeedleOwned"):Connect(function()
        if player:GetAttribute("NeedleOwned")==true then
            task.defer(attemptHandIn,"ownership changed")
        else
            resetHandIn("NeedleOwned cleared")
        end
    end)
    connections[#connections+1]=player:GetAttributeChangedSignal("NeedleNpcReady"):Connect(function()
        if player:GetAttribute("NeedleNpcReady")==true then
            handin.readyTransitions+=1
            if canHandIn() then attemptHandIn("npc-ready") end
        end
    end)
    local folder=RS:FindFirstChild("NeedleHaystack")
    local completed=folder and folder:FindFirstChild("NeedleRoundCompleted")
    if completed and completed:IsA("RemoteEvent") then
        connections[#connections+1]=completed.OnClientEvent:Connect(function(...)
            if alive and handin.firstRequestAt>0 then
                trace("roundEvent",{
                    sinceRequest=os.clock()-handin.firstRequestAt,
                    requests=handin.requests,args=select("#",...),
                })
            end
        end)
    end
    connections[#connections+1]=needleRun.Heartbeat:Connect(function()
        if not alive or not state.AutoHandInNeedle then return end
        if player:GetAttribute("NeedleOwned")~=true then
            if handin.ownedAt>0 then resetHandIn("ownership cleared") end
            return
        end
        if player:GetAttribute("NeedleRoundComplete")==true then
            if not handin.finished and handin.firstRequestAt>0 then
                handin.finished=true
                trace("roundComplete",{
                    seconds=os.clock()-handin.firstRequestAt,
                    requests=handin.requests,corrections=handin.corrections,
                })
            end
            return
        end
        attemptHandIn("heartbeat")
    end)
    needleStop=function()
        if activeNeedleCleanup then pcall(activeNeedleCleanup) end
        pcall(function()needleRun:UnbindFromRenderStep(aimRenderName)end)
    end
end)()
end

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
local autoClosedScene=nil
local function cutscenePhase()
    -- The needle round completes BEFORE WinterBoss starts; the capture shows
    -- NeedleRoundComplete=true DURING Yeti Sleeping and Fighting. Only a
    -- defeated boss ends the winter cutscene sequence.
    if defeated then return nil end
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
    -- NeedleRoundComplete is a valid blocker only outside the Yeti encounter.
    if player:GetAttribute("NeedleRoundComplete")==true then return nil end
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
        local enabled=state.AutoSkipCutscenes or os.clock()<forceSkipUntil
        local scene=cutscenePhase()
        local button=nil
        -- Native Skip is worth checking during winter introductions even when
        -- the underlying needle round has already finished.
        if enabled and not defeated and
            (player:GetAttribute("NeedleRoundComplete")~=true
                or player:GetAttribute("InWinterBoss")==true) then
            button=findNativeSkip()
            -- Some opening Skip buttons appear before the scripted player
            -- attributes replicate. A genuine native Skip is enough evidence.
            if not scene and button then
                local activeBoss=findBoss()
                local bossState=activeBoss and activeBoss:GetAttribute("BossState")
                if not bossInCombat(activeBoss) and bossState~="Defeated" then
                    scene="Winter native intro"
                end
            end
        end
        if scene~=lastScene then
            lastScene=scene
            sceneSince=os.clock()
            skipAttempts=0
            nextSkipClickAt=0
            autoClosedScene=nil
            logEvent("winter.scene",scene or "gameplay")
        end
        if not enabled or not scene then
            stopCutsceneView()
            continue
        end
        -- The main UI starts open. Close it once per introductory scene so
        -- the game-native Skip can receive mouse input without manual setup.
        -- If the player reopens it deliberately, leave the menu open and wait.
        if not hubWindow.Closed then
            if autoClosedScene~=scene then
                autoClosedScene=scene
                hubWindow:Close()
                logEvent("winter.skip","Auto-closed hub for native intro skip")
            else
                stopCutsceneView()
                continue
            end
        end
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

-- Boss automation was previously defined but never scheduled. Bind each new
-- live Yeti, arm pitchfork on respawn, and perform the critical attack worker.
task.spawn(function()
    local lastAutoClosedBoss=nil
    local lastWorkerError=-math.huge
    while alive do
        task.wait(0.055)
        local active=findBoss()
        if active~=boss then
            bindBoss(active)
            resetHover()
            syncBoss()
        end
        if active and alive and state.BossFight
            and player:GetAttribute("InWinterBoss")==true
            and bossInCombat(active)
            and (tonumber(active:GetAttribute("BossHealth")) or 0)>0
            and not defeated then
            if not hubWindow.Closed and lastAutoClosedBoss~=active then
                lastAutoClosedBoss=active
                hubWindow:Close()
            end
            -- Keep a stable off-ground position even between weak-point
            -- windows, and then fire the pitchfork after repositioning.
            if state.BossWalk then
                local head=headAndHumanoid()
                local hitbox=active:FindFirstChild("BossHitbox")
                    or active:FindFirstChild("RootPart")
                if head and hitbox and hitbox:IsA("BasePart")
                    and not blocked() then
                    local point,source=aimPoint(hitbox,head)
                    local moved,reason=pcall(hoverNearWeakPoint,point,source)
                    if not moved and os.clock()-lastWorkerError>=2 then
                        lastWorkerError=os.clock()
                        warn("[BeyyHub Winter Hover] "..tostring(reason))
                    end
                end
            end
            if state.BossPitchfork then
                local ok,err=pcall(attackTick)
                if not ok and os.clock()-lastWorkerError>=2 then
                    lastWorkerError=os.clock()
                    warn("[BeyyHub Winter Boss] "..tostring(err))
                end
            end
        end
    end
end)

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
    needleStop()
    if bossCameraAim.boundWithPriority then
        pcall(function()game:GetService("RunService"):UnbindFromRenderStep(
            bossCameraAim.bindName)end)
    end
    if bossCameraAim.renderConnection then
        pcall(function()bossCameraAim.renderConnection:Disconnect()end)
    end
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
print("[BeyyHub Winter] Main v4.24 installed: adaptive close-range weakpoint approach on missed crits, enrage remains targetable, camera/vacuum/pitchfork preserved")
