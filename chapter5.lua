-- BeyyHub v103.00 | Chapter5 main module | PlaceId 85675194070288
-- Integrated from the standalone Chapter 5 v4 automation (unmodified workers).
-- RightControl opens a minimal Main control panel. F8 report, F9 stop workers.
local __BEYY_MODULE = "Chapter5"
local __BEYY_SCRIPT_VERSION = "103.00"
local __BEYY_BOOT_T0 = os.clock()
if game.PlaceId~=85675194070288 then
    warn("[BeyyHub] Refusing to load Chapter5 module in another place")
    return
end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if _G.__BEYY_HUB_LOADED then
    local prior=_G.__BEYY_HUB_CLEANUP
    if type(prior)=="function" then pcall(prior) end
end
_G.__BEYY_HUB_LOADED=true
local unloaded=false
local connections={}
local moduleStateFile="BeyyHub/chapter5_main_enabled.txt"
local enabled=true
if type(readfile)=="function" then
    local ok,setting=pcall(readfile,moduleStateFile)
    if ok and setting=="OFF" then enabled=false end
end
local function saveEnabled()
    if type(writefile)~="function" then return end
    pcall(function()
        if type(makefolder)=="function" and
            (type(isfolder)~="function" or not isfolder("BeyyHub")) then
            makefolder("BeyyHub")
        end
        writefile(moduleStateFile,enabled and "ON" or "OFF")
    end)
end
local antiAfkOn=true
local idleConnection=player.Idled:Connect(function()
    if unloaded or not antiAfkOn then return end
    pcall(function()
        local virtual=game:GetService("VirtualUser")
        virtual:CaptureController()
        virtual:ClickButton2(Vector2.zero)
    end)
end)
connections[#connections+1]=idleConnection


-- Chapter 5 Main settings. Boss/puzzle defaults preserve standalone behavior.
local ch5Defaults={
    AntiAFK=true,
    AutoRelics=true,AutoSundial=true,AutoPotion=true,AutoPotionSkip=true,AutoIntroSkip=true,
    AutoBossFight=true,AutoBossPitchfork=true,AutoBossTNT=true,AutoBossVacuum=true,
    AutoPickHay=false,AutoCollectDroppedHay=false,AutoCollectGems=false,CollectInterval=0.5,
    AutoSellHay=false,SellThreshold=25,SellOnlyIfFull=false,
    AutoUseTNT=false,AutoUsePitchfork=false,AutoDeployDrone=false,AutoUseVacuum=false,
    TntLightCooldown=0,TntThrowDelay=0.4,VacuumHotbarSlot=5,ToolInterval=0.5,
    AutoBuyTools=false,BuyToolsList={"Pitchfork"},BuyInterval=1,
    UpgBagSize=false,UpgExtraTake=false,UpgGemValue=false,UpgHayValue=false,PermInterval=0.5,
    UpgCapacity=false,UpgHandSpeed=false,UpgHandGrab=false,UpgHandHold=false,
    UpgTntLuck=false,UpgTntCooldown=false,UpgTntPower=false,
    UpgPitchCooldown=false,UpgPitchHold=false,UpgPitchSweep=false,
    UpgDroneSpeed=false,UpgDroneGrab=false,UpgDroneCapacity=false,
    UpgVacPower=false,UpgVacCooling=false,UpgVacRuntime=true
}
local featureState={}
for k,v in pairs(ch5Defaults) do featureState[k]=type(v)=="table" and table.clone(v) or v end
local HttpService=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local VIM=game:GetService("VirtualInputManager")
local featurePath="BeyyHub/chapter5_main_settings.json"
local sharedFarmPath="BeyyHub/farming_inventory_shared.json"
local function loadSettingsFrom(path,onlyFarming)
    if type(readfile)~="function" then return end
    local ok,raw=pcall(readfile,path)
    if not ok or type(raw)~="string" then return end
    local parsed,settings=pcall(function()return HttpService:JSONDecode(raw)end)
    if not parsed or type(settings)~="table" then return end
    settings=settings.__elements or settings
    for k,default in pairs(ch5Defaults) do
        if not onlyFarming or not ({
            AutoRelics=true,AutoSundial=true,AutoPotion=true,AutoPotionSkip=true,AutoIntroSkip=true,
            AutoBossFight=true,AutoBossPitchfork=true,AutoBossTNT=true,AutoBossVacuum=true
        })[k] then
            local v=settings[k]
            if type(v)=="table" and v.__type then v=v.value end
            if type(v)==type(default) then
                featureState[k]=type(v)=="table" and table.clone(v) or v
            end
        end
    end
end
loadSettingsFrom(sharedFarmPath,true)
loadSettingsFrom(featurePath,false)
antiAfkOn=featureState.AntiAFK~=false
local function saveFeatures()
    if type(writefile)~="function" then return end
    pcall(function()
        if type(makefolder)=="function" and
            (type(isfolder)~="function" or not isfolder("BeyyHub")) then
            makefolder("BeyyHub")
        end
        writefile(featurePath,HttpService:JSONEncode(featureState))
    end)
end
env.__BEYY_CH5_FEATURES=featureState

-- Catch the first native Skip before Chapter 5 workers wait on replication.
-- Exits on the first successful click/disappearance, objective progress, or timeout.
do
    local started=os.clock()
    task.spawn(function()
        local clicked=false
        local nextClick=0
        local attempts=0
        while not unloaded and os.clock()-started<120 do
            task.wait(0.08)
            if not enabled or not featureState.AutoIntroSkip then continue end
            local relics=WS:FindFirstChild("RelicTablets")
            if relics then
                local beganRelics=false
                for _,tablet in ipairs(relics:GetChildren()) do
                    if tablet:GetAttribute("Taken")==true or tablet:GetAttribute("Placed")==true then
                        beganRelics=true;break
                    end
                end
                if beganRelics then return end
            end
            local sundial=WS:FindFirstChild("Sundial")
            local boss=WS:FindFirstChild("FarmerBoss")
            if (sundial and sundial:GetAttribute("Solved")==true)
                or (boss and boss:GetAttribute("FightStartedAt")~=nil) then return end
            local pg=player:FindFirstChildOfClass("PlayerGui")
            local found=nil
            if pg then
                for _,btn in ipairs(pg:GetDescendants()) do
                    if btn:IsA("GuiButton") and btn.AbsoluteSize.X>0 and btn.AbsoluteSize.Y>0 then
                        local label=btn.Name:lower()
                        if btn:IsA("TextButton") then label=label.." "..btn.Text:lower() end
                        local node=btn.Parent
                        for _=1,3 do
                            if not node or node==pg then break end
                            label=label.." "..node.Name:lower()
                            node=node.Parent
                        end
                        if label:find("skip",1,true) and not label:find("replay",1,true)
                            and not label:find("lobby",1,true) then
                            local visible=true
                            node=btn
                            while node do
                                if node:IsA("GuiObject") and not node.Visible then visible=false;break end
                                if node:IsA("ScreenGui") and not node.Enabled then visible=false;break end
                                if node==pg then break end
                                node=node.Parent
                            end
                            if visible then found=btn;break end
                        end
                    end
                end
            end
            if clicked and not found then
                print("[BeyyHub CH5 INTRO] Opening Skip disappeared after click")
                return
            end
            if found and os.clock()>=nextClick then
                nextClick=os.clock()+0.4
                attempts+=1
                local pos,size=found.AbsolutePosition,found.AbsoluteSize
                local inset=game:GetService("GuiService"):GetGuiInset()
                local x,y=pos.X+size.X/2+inset.X,pos.Y+size.Y/2+inset.Y
                local ok=pcall(function()
                    VIM:SendMouseMoveEvent(x,y,game)
                    VIM:SendMouseButtonEvent(x,y,0,true,game,0)
                    task.wait(0.05)
                    VIM:SendMouseButtonEvent(x,y,0,false,game,0)
                end)
                local signal=false
                if type(firesignal)=="function" then signal=pcall(function()firesignal(found.Activated)end) end
                clicked=clicked or ok or signal
                print(("[BeyyHub CH5 INTRO] Native opening Skip #%d mouse=%s signal=%s"):format(
                    attempts,tostring(ok),tostring(signal)))
                if attempts>=20 then return end
            end
        end
    end)
end

-- Read native TNT throw-speed limits once available; read upgraded cooldown
-- freshly on each light request, including its server acknowledgment.
local nativeTntConfig=nil
local nativeTntConfigRetry=0
local function ch5TntConfig()
    if nativeTntConfig then return nativeTntConfig end
    if os.clock()<nativeTntConfigRetry then return nil end
    nativeTntConfigRetry=os.clock()+3
    local shared=RS:FindFirstChild("Shared")
    local configs=shared and shared:FindFirstChild("Configs")
    local module=configs and configs:FindFirstChild("GameConfig")
    if module then
        local ok,config=pcall(require,module)
        if ok and type(config)=="table" then nativeTntConfig=config end
    end
    return nativeTntConfig
end
local function ch5TntCooldown()
    local seconds=tonumber(player:GetAttribute("TntCooldown"))
    if not seconds or seconds<=0 then seconds=20 end
    return math.max(0.5,seconds,tonumber(featureState.TntLightCooldown) or 0)
end
local function ch5TntVelocity(origin,target)
    local cfg=ch5TntConfig()
    local minSpeed=cfg and tonumber(cfg.TNT_MIN_THROW_SPEED) or 20
    local maxSpeed=cfg and tonumber(cfg.TNT_MAX_THROW_SPEED) or 65
    if not minSpeed or not maxSpeed or minSpeed<=0 or maxSpeed<minSpeed then
        minSpeed,maxSpeed=20,65
    end
    local delta=target-origin
    if delta.Magnitude<0.1 then return nil,nil end
    for i=3,32 do
        local flight=i*0.025
        local velocity=delta/flight+Vector3.new(0,WS.Gravity*flight*0.5,0)
        if velocity.Magnitude>=minSpeed and velocity.Magnitude<=maxSpeed then
            return velocity,flight
        end
    end
    return delta.Unit*math.clamp(40,minSpeed,maxSpeed)+Vector3.new(0,8,0),nil
end

-- Keep the v4 standalone gameplay logic inside a local scope, so the Main
-- UI does not compete for either the native Skip button or combat input.
local function startChapter5Workers()
    -- BeyyHub Chapter 5 standalone AUTOMATION TEST v4 (safe ground-level potion hand-in)
    -- Relics -> Sundial -> farmer potion scene -> Farmer boss tools.
    -- Isolated test: does not load or change BeyyHub Main (Chapters 1-4).
    -- Native prompts require the executor's fireproximityprompt or input fallback.
    -- All actions are checked against replicated game state. F8 report, F9 stop.
    local PLACE=85675194070288
    if game.PlaceId~=PLACE then warn("[CH5 TEST] Join Chapter 5 first.");return end
    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local WS=game:GetService("Workspace")
    local UIS=game:GetService("UserInputService")
    local VIM=game:GetService("VirtualInputManager")
    local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
    local env=_G
    if type(getgenv)=="function" then
        local ok,value=pcall(getgenv)
        if ok and type(value)=="table" then env=value end
    end
    if type(env.__BEYY_CH5_TEST_STOP)=="function" then
        pcall(env.__BEYY_CH5_TEST_STOP,"restart")
    end
    local alive=true
    local stage="WAIT_RELICS"
    local began=os.clock()
    local connections={}
    local events={}
    local stats={relicPrompts=0,relicConfirmed=0,turnPrompts=0,turnConfirmed=0,
        potionApproaches=0,potionHandInRequests=0,potionHandInConfirmed=0,
        potionSkipAttempts=0,potionSkipConfirmed=0,bossHits=0,bossDamage=0,
        pitchforkRequests=0,tntLights=0,tntThrows=0,tntDenied=0,
        toolPurchases=0,failedMoves=0}
    local lastReportAt=0
    local lastEvent=""
    local folder=RS:WaitForChild("NeedleHaystack",10)
    local relics=WS:WaitForChild("RelicTablets",10)
    local sundial=WS:WaitForChild("Sundial",10)
    local boss=WS:WaitForChild("FarmerBoss",10)
    if not folder or not relics or not sundial or not boss then
        warn("[CH5 TEST] Required Chapter 5 objects did not replicate.")
        return
    end
    local function att(obj,name)
        if not obj then return nil end
        return obj:GetAttribute(name)
    end
    local function truth(value)
        return value==true or value=="true" or value==1
    end
    local function reportMessage(label,msg)
        local text=string.format("+%.2fs [%s] %s",os.clock()-began,label,tostring(msg))
        events[#events+1]=text
        if #events>380 then table.remove(events,1) end
        if text~=lastEvent then print("[CH5 TEST] "..text);lastEvent=text end
    end
    local function stageTo(value)
        if stage~=value then
            reportMessage("STAGE",stage.." -> "..value)
            stage=value
        end
    end
    local function root()
        local c=player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function head()
        local c=player.Character
        return c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
    end
    local function blocked()
        if not alive or (type(env.__BEYY_CH5_UI_OPEN)=="function"
            and env.__BEYY_CH5_UI_OPEN()) then return true end
        for _,key in ipairs({"NeedleInputLocked","CutsceneActive","BossHeld","BossRagdolled",
            "BossRagdollRecovering","BossKnockdownCamera","BossGrabbed"}) do
            if truth(att(player,key)) then return true end
        end
        local c=player.Character
        local human=c and c:FindFirstChildOfClass("Humanoid")
        return not human or human.Health<=0
    end
    local function getPart(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj end
        return obj:FindFirstChildWhichIsA("BasePart",true)
    end
    local function floorAt(v)
        local c=player.Character
        local rayParams=RaycastParams.new()
        rayParams.FilterType=Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances={c,WS:FindFirstChild("FarmerBossLocalEffects")}
        local hit=WS:Raycast(v+Vector3.new(0,18,0),Vector3.new(0,-80,0),rayParams)
        if not hit or hit.Normal.Y<0.65 or not hit.Instance.CanCollide then return nil end
        return hit.Position+Vector3.new(0,3.1,0)
    end
    local function moveNear(obj,range)
        if blocked() then return false,"blocked" end
        local rr=root()
        local part=getPart(obj)
        if not rr or not part then return false,"no root/part" end
        if (rr.Position-part.Position).Magnitude<=range then return true end
        local delta=rr.Position-part.Position
        local horizontal=Vector3.new(delta.X,0,delta.Z)
        if horizontal.Magnitude<0.5 then horizontal=Vector3.new(1,0,0) end
        local toward=part.Position+horizontal.Unit*math.min(4,math.max(2,range-1.5))
        local dest=floorAt(toward)
        if not dest then
            for _,offset in ipairs({
                Vector3.new(4,0,0),Vector3.new(-4,0,0),
                Vector3.new(0,0,4),Vector3.new(0,0,-4)}) do
                dest=floorAt(part.Position+offset)
                if dest then break end
            end
        end
        if not dest then stats.failedMoves+=1;return false,"no safe floor" end
        rr.CFrame=CFrame.lookAt(dest,Vector3.new(part.Position.X,dest.Y,part.Position.Z))
        rr.AssemblyLinearVelocity=Vector3.zero
        rr.AssemblyAngularVelocity=Vector3.zero
        task.wait(0.13)
        rr=root()
        if rr and (rr.Position-part.Position).Magnitude<=range then return true end
        stats.failedMoves+=1
        return false,"out of prompt range after moving"
    end
    local function activatePrompt(prompt,range)
        if not alive or blocked() or not prompt or not prompt.Parent then return false,"blocked/missing" end
        if not prompt.Enabled then return false,"prompt disabled by game" end
        local ok,why=moveNear(prompt.Parent,range or math.max(3,math.min(7,prompt.MaxActivationDistance-1)))
        if not ok then return false,why end
        if type(fireproximityprompt)=="function" then
            local fired,errorMsg=pcall(fireproximityprompt,prompt)
            return fired,fired and "executor prompt" or tostring(errorMsg)
        end
        -- Fallback: use the prompt's bound input key at its actual location.
        local key=prompt.KeyboardKeyCode
        if key==Enum.KeyCode.Unknown then key=Enum.KeyCode.E end
        local hold=math.max(0.10,tonumber(prompt.HoldDuration) or 0)
        local success,errorMsg=pcall(function()
            VIM:SendKeyEvent(true,key,false,game)
            task.wait(hold+0.05)
            VIM:SendKeyEvent(false,key,false,game)
        end)
        return success,success and "native key input" or tostring(errorMsg)
    end
    local function n(x) return tonumber(x) or 0 end
    local function allRelicsPlaced()
        local count=0
        for _,name in ipairs({"SandTablet","ClayTablet","SlateTablet"}) do
            local t=relics:FindFirstChild(name)
            if t and truth(att(t,"Placed")) then count+=1 end
        end
        return count
    end
    local function allRelicsTaken()
        local count=0
        for _,name in ipairs({"SandTablet","ClayTablet","SlateTablet"}) do
            local t=relics:FindFirstChild(name)
            if t and truth(att(t,"Taken")) then count+=1 end
        end
        return count
    end
    local function bossReady()
        local s=tostring(att(boss,"BossState") or "")
        local hp=n(att(boss,"BossHealth"))
        return hp>0 and not ({
            Sleeping=true,Intro=true,Rising=true,Falling=true,Defeated=true,
            Unavailable=true,PhaseTransition=true
        })[s]
    end
    local function defeated()
        return tostring(att(boss,"BossState"))=="Defeated"
            or (att(boss,"FightStartedAt") and n(att(boss,"BossHealth"))<=0)
    end
    local function textReport()
        local lines={
            "CHAPTER 5 AUTO TEST v4",
            "Stage: "..stage,
            "Elapsed: "..string.format("%.1fs",os.clock()-began),
            "Relics taken/placed: "..allRelicsTaken().."/"..allRelicsPlaced(),
            "Sundial solved: "..tostring(att(sundial,"Solved")),
            "Boss state/health/phase: "..tostring(att(boss,"BossState")).." / "..
                tostring(att(boss,"BossHealth")).." / "..tostring(att(boss,"BossPhase")),
            "Boss weak point/vulnerable: "..tostring(att(boss,"BossWeakPoint"))..
                " / "..tostring(att(boss,"BossVulnerable")),
            "Relic prompt attempts: "..stats.relicPrompts,
            "Sundial turn attempts/confirmed: "..stats.turnPrompts.." / "..stats.turnConfirmed,
            "Potion approaches/requests/confirmed: "..stats.potionApproaches.." / "..
                stats.potionHandInRequests.." / "..stats.potionHandInConfirmed,
            "Potion Skip attempts/disappearances: "..stats.potionSkipAttempts.." / "..
                stats.potionSkipConfirmed,
            "TNT light/throw/denied: "..stats.tntLights.." / "..stats.tntThrows.." / "..stats.tntDenied,
            "Boss pitchfork requests/hits/damage: "..stats.pitchforkRequests.." / "..
                stats.bossHits.." / "..stats.bossDamage,
            "Tool purchase attempts: "..stats.toolPurchases,
            "Movement failures: "..stats.failedMoves,
            "--- Timeline ---",
            table.concat(events,"\n")
        }
        return table.concat(lines,"\n")
    end
    local function saveReport(copy)
        local txt=textReport()
        if type(writefile)=="function" then
            pcall(function()
                if type(makefolder)=="function" and
                    (type(isfolder)~="function" or not isfolder("BeyyHub")) then
                    makefolder("BeyyHub")
                end
                writefile("BeyyHub/chapter5_automation_test_log.txt",txt)
            end)
        end
        if copy and type(setclipboard)=="function" then pcall(setclipboard,txt) end
    end
    local vacuumHeld=false
    local vacuumPoint=Vector2.zero
    local vacuumStarted=0
    local vacuumRestUntil=0
    local function releaseVacuum()
        if vacuumHeld then
            vacuumHeld=false
            pcall(function()
                VIM:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
            end)
        end
    end
    local function stop(reason)
        if not alive then return end
        alive=false
        stageTo("STOPPED")
        releaseVacuum()
        reportMessage("STOP",reason or "manual")
        for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
        saveReport(false)
        env.__BEYY_CH5_TEST_STOP=nil
    end
    env.__BEYY_CH5_TEST_STOP=stop
    env.__BEYY_CH5_TEST_REPORT=textReport
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,consumed)
        if consumed then return end
        if input.KeyCode==Enum.KeyCode.F8 then
            saveReport(true);reportMessage("REPORT","F8 saved/copied report")
        elseif input.KeyCode==Enum.KeyCode.F9 then stop("F9")
        end
    end)
    local function buyTool(tool,attribute)
        if truth(att(player,attribute)) then return end
        local remote=folder:FindFirstChild("BuyShopItem")
        if not remote then return end
        stats.toolPurchases+=1
        pcall(function() remote:FireServer(tool) end)
    end
    local function ensureTools()
        if featureState.AutoBossTNT then buyTool("Tnt","TntOwned") end
        if featureState.AutoBossPitchfork then buyTool("Pitchfork","PitchforkOwned") end
        -- Vacuum is normally unlocked by the chapter.
    end
    -- Puzzle worker: server confirmation, bounded retries, no fixed solution.
    task.spawn(function()
        local retry={}
        local function attemptPrompt(p,key,range,timeout,confirmed)
            local nextAt=retry[key] or 0
            if os.clock()<nextAt then return false end
            local ok,reason=activatePrompt(p,range)
            retry[key]=os.clock()+(ok and 0.55 or 1.5)
            if not ok then reportMessage("PROMPT",key..": "..tostring(reason));return false end
            local untilAt=os.clock()+(timeout or 0.60)
            while alive and os.clock()<untilAt do
                if confirmed() then return true end
                task.wait(0.04)
            end
            reportMessage("PENDING",key.." action sent; no state confirmation yet")
            return false
        end
        -- Sundial parallel v2: the three cranks form a triangle whose
        -- circumradius (~8.30 studs) exceeds the native 8-stud prompt range.
        -- A single position can only reach TWO at once, so select a valid
        -- pair midpoint and dispatch two native prompts without waiting between.
        -- Keep the proven sequential solver for any remaining ring.
        local pairPending={}
        local nextPairMove=0
        local lastPairDiagnostic=-math.huge
        local function pairDiagnostic(message)
            if os.clock()-lastPairDiagnostic>=3.5 then
                lastPairDiagnostic=os.clock()
                reportMessage("SUNDIAL_PAIR_WAIT",message)
            end
        end
        local function tryParallelSundial()
            if type(fireproximityprompt)~="function" or allRelicsPlaced()<3 then
                return false
            end
            local pedestals=sundial:FindFirstChild("Pedestals")
            local rings=sundial:FindFirstChild("Rings")
            local pointer=sundial:FindFirstChild("Pointer")
            local rr=root()
            if not (pedestals and rings and pointer and rr) then return false end
            local allTargets={}
            local now=os.clock()
            local waiting=false
            for i,name in ipairs({"SandTablet","ClayTablet","SlateTablet"}) do
                local tablet=relics:FindFirstChild(name)
                local ped=pedestals:FindFirstChild("Pedestal"..i)
                local ring=rings:FindFirstChild("Ring"..i)
                local prompt=ped and ped:FindFirstChild("TurnPrompt",true)
                local part=prompt and getPart(prompt.Parent)
                if not (tablet and ped and ring and prompt and part) then
                    return false
                end
                local record=pairPending[i]
                if record then
                    local turns=n(att(ped,"Turns"))
                    local tileMoved=record.Tile.Parent
                        and (record.Tile.Position-record.Position).Magnitude>0.15
                    if (turns>record.Turns or tileMoved) and not record.Confirmed then
                        record.Confirmed=true
                        -- Let the 60-degree tile rotation settle before using
                        -- the tile geometry to compute another step.
                        record.ReleaseAt=now+0.45
                        stats.turnConfirmed+=1
                        reportMessage("SUNDIAL_PAIR","Ring"..i..
                            " server turn confirmed; waiting for tile animation")
                    end
                    if record.Confirmed and now>=record.ReleaseAt then
                        pairPending[i]=nil
                    elseif not record.Confirmed and now>=record.Until then
                        pairPending[i]=nil
                        pairDiagnostic("Ring"..i.." request not confirmed; sequential retry allowed")
                    else
                        waiting=true
                    end
                end
                local want=att(tablet,"Glyph") or att(ring,"Want")
                local tile=nil
                for _,obj in ipairs(ring:GetChildren()) do
                    if obj:IsA("BasePart") and obj.Name:match("^Tile%d+$")
                        and att(obj,"Glyph")==want then
                        tile=obj
                        break
                    end
                end
                if not tile then return waiting end
                local origin=ring:GetPivot().Position
                local a=math.atan2((tile.Position-origin).Z,(tile.Position-origin).X)
                local b=math.atan2((pointer.Position-origin).Z,(pointer.Position-origin).X)
                local steps=math.floor(((a-b)%(math.pi*2))/(math.pi/3)+0.5)%6
                if steps>0 and prompt.Enabled and not pairPending[i] then
                    allTargets[#allTargets+1]={
                        Index=i,Prompt=prompt,Part=part,Ped=ped,Tile=tile,
                        Turns=n(att(ped,"Turns"))
                    }
                end
            end
            -- Do not let the sequential solver fire a second request while a
            -- paired native interaction is awaiting confirmation.
            if waiting then return true end
            if #allTargets<2 then return false end
            local function within(position,entry)
                local radius=(tonumber(entry.Prompt.MaxActivationDistance) or 0)-0.25
                return radius>0 and (position-entry.Part.Position).Magnitude<=radius
            end
            -- Determine a playable position actually in range of both.
            -- Prefer a valid location near the current character.
            local best,bestTravel=nil,math.huge
            for i=1,#allTargets-1 do
                for j=i+1,#allTargets do
                    local first,second=allTargets[i],allTargets[j]
                    local middle=(first.Part.Position+second.Part.Position)*0.5
                    local candidate=rr.Position
                    if not (within(candidate,first) and within(candidate,second)) then
                        candidate=floorAt(middle)
                    end
                    if candidate and within(candidate,first) and within(candidate,second) then
                        local travel=(rr.Position-candidate).Magnitude
                        if travel<bestTravel then
                            best={First=first,Second=second,Position=candidate}
                            bestTravel=travel
                        end
                    end
                end
            end
            if not best then
                local first,second=allTargets[1],allTargets[2]
                pairDiagnostic(("No safe pair position; prompt ranges %s/%s; separation %.2f"):format(
                    tostring(first.Prompt.MaxActivationDistance),
                    tostring(second.Prompt.MaxActivationDistance),
                    (first.Part.Position-second.Part.Position).Magnitude))
                return false
            end
            if bestTravel>0.15 then
                if now<nextPairMove then return true end
                nextPairMove=now+0.8
                if blocked() then return true end
                rr.CFrame=CFrame.new(best.Position)*rr.CFrame.Rotation
                rr.AssemblyLinearVelocity=Vector3.zero
                rr.AssemblyAngularVelocity=Vector3.zero
                task.wait(0.10)
                rr=root()
                if not rr or not within(rr.Position,best.First)
                    or not within(rr.Position,best.Second) then
                    pairDiagnostic("Position failed server-range check; using sequential fallback")
                    return false
                end
            end
            if blocked() or truth(att(sundial,"Solved")) then return true end
            local sent=0
            local indices={}
            for _,target in ipairs({best.First,best.Second}) do
                if target.Prompt.Enabled and not pairPending[target.Index] then
                    pairPending[target.Index]={
                        Turns=target.Turns,Tile=target.Tile,Position=target.Tile.Position,
                        Until=os.clock()+0.85,Confirmed=false
                    }
                    stats.turnPrompts+=1
                    local ok,err=pcall(fireproximityprompt,target.Prompt)
                    if ok then
                        sent+=1
                        indices[#indices+1]=tostring(target.Index)
                    else
                        pairPending[target.Index]=nil
                        reportMessage("SUNDIAL_PAIR_WAIT",
                            "Ring"..target.Index.." prompt failed: "..tostring(err))
                    end
                end
            end
            if sent>0 then
                reportMessage("SUNDIAL_PAIR","Dispatched "..sent..
                    " simultaneous native turn requests on Rings "..table.concat(indices,"+"))
            end
            return sent>0
        end
        while alive and stage~="BOSS" and not defeated() do
            task.wait(0.12)
            if blocked() then continue end
            if truth(att(sundial,"Solved")) then stageTo("POTION");break end
            if allRelicsTaken()<3 then
                stageTo("RELICS")
                for _,name in ipairs({"SandTablet","ClayTablet","SlateTablet"}) do
                    if not alive or blocked() then break end
                    local t=relics:FindFirstChild(name)
                    if featureState.AutoRelics and t and not truth(att(t,"Taken")) then
                        local slab=t:FindFirstChild("Slab")
                        local prompt=slab and slab:FindFirstChild("TakePrompt")
                        if prompt and prompt.Enabled then
                            stats.relicPrompts+=1
                            local ok=attemptPrompt(prompt,name.."-Take",7,0.55,
                                function()return truth(att(t,"Taken"))end)
                            if ok then
                                stats.relicConfirmed+=1
                                reportMessage("RELIC","Taken "..name.." glyph="..tostring(att(t,"Glyph")))
                            end
                        end
                    end
                end
            else
                stageTo("SUNDIAL")
                if not featureState.AutoSundial then continue end
                if tryParallelSundial() then continue end
                -- The pedestal Glyph is the tablet's ANSWER, not the ring's
                -- current alignment. Comparing those two glyph attributes
                -- prevented every rotation in v1.
                -- Calculate the clockwise 60-degree steps from the target tile's
                -- live world position to the Sundial Pointer. Previous completed
                -- round: Ring1 2 turns, Ring2 3, Ring3 2, each validated against
                -- its actual Tile Position before/after.
                local pedestals=sundial:FindFirstChild("Pedestals")
                local rings=sundial:FindFirstChild("Rings")
                local pointer=sundial:FindFirstChild("Pointer")
                local progressed=false
                local missingPlace=nil
                for i,name in ipairs({"SandTablet","ClayTablet","SlateTablet"}) do
                    if not alive or blocked() or truth(att(sundial,"Solved")) then break end
                    local tablet=relics:FindFirstChild(name)
                    local ped=pedestals and pedestals:FindFirstChild("Pedestal"..i)
                    local ring=rings and rings:FindFirstChild("Ring"..i)
                    local prompt=ped and ped:FindFirstChild("TurnPrompt",true)
                    if not (tablet and ped and ring and pointer) then
                        if os.clock()-(retry["ringMissing"..i] or -math.huge)>=4 then
                            retry["ringMissing"..i]=os.clock()
                            reportMessage("SUNDIAL_WAIT","Ring"..i.." missing tablet/pedestal/ring/pointer")
                        end
                        continue
                    end
                    local want=att(tablet,"Glyph") or att(ring,"Want")
                    local tile=nil
                    for _,obj in ipairs(ring:GetChildren()) do
                        if obj:IsA("BasePart") and obj.Name:match("^Tile%d+$") and att(obj,"Glyph")==want then
                            tile=obj
                            break
                        end
                    end
                    if not tile or not want then
                        if os.clock()-(retry["tileMissing"..i] or -math.huge)>=4 then
                            retry["tileMissing"..i]=os.clock()
                            reportMessage("SUNDIAL_WAIT","Ring"..i.." target glyph="..
                                tostring(want).." not found among its tiles")
                        end
                        continue
                    end
                    local center=ring:GetPivot().Position
                    local toTile=tile.Position-center
                    local toPointer=pointer.Position-center
                    local a=math.atan2(toTile.Z,toTile.X)
                    local b=math.atan2(toPointer.Z,toPointer.X)
                    local relative=(a-b)%(math.pi*2)
                    local steps=math.floor(relative/(math.pi/3)+0.5)%6
                    local turns=n(att(ped,"Turns"))
                    local placed=truth(att(tablet,"Placed"))
                    if not placed and not missingPlace then
                        missingPlace={name=name,ped=ped,tablet=tablet}
                    end
                    if os.clock()-(retry["snapshot"..i] or -math.huge)>=4 then
                        retry["snapshot"..i]=os.clock()
                        reportMessage("SUNDIAL_STATE","Ring"..i.." target="..tostring(want)..
                            " turns="..turns.." stepsRemaining="..steps..
                            " taken="..tostring(att(tablet,"Taken"))..
                            " placed="..tostring(placed)..
                            " prompt="..tostring(prompt and prompt.Enabled)..
                            " ringSteps="..tostring(att(ring,"Steps"))..
                            " pedGlyph="..tostring(att(ped,"Glyph")))
                    end
                    if steps>0 and prompt and prompt.Enabled then
                        local beforePosition=tile.Position
                        local beforeTurns=turns
                        stats.turnPrompts+=1
                        local ok=attemptPrompt(prompt,"Ring"..i.."-turn",5.7,0.70,function()
                            return n(att(ped,"Turns"))~=beforeTurns
                                or (tile.Parent and (tile.Position-beforePosition).Magnitude>0.15)
                        end)
                        if ok then
                            stats.turnConfirmed+=1
                            reportMessage("SUNDIAL","Ring"..i.." +1 turn CONFIRMED; target="..
                                tostring(want).." turns="..tostring(att(ped,"Turns"))..
                                " previousRemaining="..steps)
                        else
                            if os.clock()-(retry["turnStalled"..i] or -math.huge)>=3 then
                                retry["turnStalled"..i]=os.clock()
                                reportMessage("SUNDIAL_WAIT","Ring"..i..
                                    " turn not confirmed; placed="..tostring(placed)..
                                    " promptEnabled="..tostring(prompt.Enabled))
                            end
                        end
                        progressed=ok
                        break -- one crank attempt per pass; unplaced tablet gets slot approach
                    end
                    -- A tablet may still be pending placement after its Take
                    -- prompt succeeded. Approach its REAL slot (<=3.3 studs)
                    -- instead of the old 7-stud radius; inspect native state.
                    if steps>0 and prompt and not prompt.Enabled and
                        os.clock()-(retry["promptDisabled"..i] or -math.huge)>=4 then
                        retry["promptDisabled"..i]=os.clock()
                        reportMessage("SUNDIAL_WAIT","Ring"..i.." crank prompt disabled; waiting for tablet placement")
                    end
                end
                if not progressed and missingPlace and
                    os.clock()-(retry[missingPlace.name.."Slot"] or -math.huge)>=0.9 then
                    retry[missingPlace.name.."Slot"]=os.clock()
                    local target=missingPlace.ped:FindFirstChild("Slot")
                        or missingPlace.ped:FindFirstChild("Body")
                    if target then
                        local ok,why=moveNear(target,3.3)
                        if ok then
                            reportMessage("PLACE","Approached "..missingPlace.name..
                                " within 3.3 studs of slot; Taken="..
                                tostring(att(missingPlace.tablet,"Taken")).." Placed="..
                                tostring(att(missingPlace.tablet,"Placed")))
                        elseif os.clock()-(retry[missingPlace.name.."SlotFail"] or -math.huge)>=4 then
                            retry[missingPlace.name.."SlotFail"]=os.clock()
                            reportMessage("PLACE","Failed approach "..missingPlace.name..
                                ": "..tostring(why))
                        end
                    end
                end
            end
            if truth(att(sundial,"Solved")) then
                reportMessage("SOLVED","Sundial Solved=true confirmed by server")
                stageTo("POTION")
                break
            end
        end
        if not alive then return end
        if stage=="POTION" then
            -- Chapter 5 replicates NeedleHaystack.NeedleHandIn. The previous
            -- script only walked to cinematic staging marks and never called it.
            local native=folder:FindFirstChild("NeedleHandIn")
            local scene=WS:FindFirstChild("PotionScene")
            local marks=scene and scene:FindFirstChild("Marks")
            local hander=marks and marks:FindFirstChild("Hander")
            local farmerMark=marks and marks:FindFirstChild("Farmer")
            local untilAt=os.clock()+45
            local nextRequest,lastMove,lastReport=0,0,0
            local startingOwned=att(player,"NeedleOwned")
            local lastFarmerState=tostring(att(boss,"BossState"))
            local groundHold=0
            -- The previous generic moveNear() used the first collidable hit
            -- below the NPC/cinematic marker, sometimes the GATE TOP. The map
            -- confirms Hander is a non-collidable ground marker at Y=2.5,
            -- next to BossFightGateWall (which stands 60 studs tall).
            -- Never raycast onto the gate or select the NPC's elevated model.
            local function potionGroundPosition()
                if not (hander and hander:IsA("BasePart")) then
                    return nil,"PotionScene.Marks.Hander unavailable"
                end
                local marker=hander.Position
                local origin=marker+Vector3.new(0,7,0)
                local excluded={}
                for _,item in ipairs({
                    player.Character,WS:FindFirstChild("Gate"),
                    WS:FindFirstChild("BossFightGateWall"),
                    WS:FindFirstChild("FarmerBoss"),
                    WS:FindFirstChild("FarmerBossLocalEffects")
                }) do
                    if item then excluded[#excluded+1]=item end
                end
                local params=RaycastParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances=excluded
                local hit=WS:Raycast(origin,Vector3.new(0,-17,0),params)
                -- Reject high ledges, props, and any surface inconsistent with
                -- the known ground marker. Preserve marker's ground Y if unsure.
                local feetY=marker.Y
                if hit and hit.Normal.Y>=0.80
                    and math.abs(hit.Position.Y-marker.Y)<=1.8 then
                    feetY=hit.Position.Y
                end
                local position=Vector3.new(marker.X,feetY+2.65,marker.Z)
                return position,hit and hit.Instance:GetFullName() or "marker Y fallback"
            end
            reportMessage("POTION_GROUND",
                "Using Hander on playable ground, never Farmer_NPC or gate roof")
            while alive and os.clock()<untilAt and not defeated() do
                task.wait(0.12)
                if bossReady() then
                    stats.potionHandInConfirmed+=1
                    reportMessage("POTION_CONFIRMED","Native Farmer encounter active; hand-in requests="..
                        stats.potionHandInRequests.." initialNeedleOwned="..tostring(startingOwned))
                    stageTo("BOSS")
                    break
                end
                local state=tostring(att(boss,"BossState"))
                if state~=lastFarmerState then
                    lastFarmerState=state
                    reportMessage("POTION_STATE","FarmerBoss state="..state..
                        " requests="..stats.potionHandInRequests)
                end
                -- Never teleport during the potion cinematic, player locks or
                -- after any active boss transition. Native Skip worker owns UI.
                if not featureState.AutoPotion or blocked() or (state~="Sleeping" and state~="nil"
                    and state~="Unavailable") then
                    continue
                end
                local hrp=root()
                local desired,surface=potionGroundPosition()
                if not (hrp and desired) then
                    if os.clock()-lastReport>=3 then
                        lastReport=os.clock()
                        reportMessage("POTION_WAIT",tostring(surface))
                    end
                    continue
                end
                local horizontal=Vector3.new(hrp.Position.X-desired.X,0,hrp.Position.Z-desired.Z).Magnitude
                local vertical=math.abs(hrp.Position.Y-desired.Y)
                -- Stand still once safely on the ground; the prior worker kept
                -- teleporting on top of the gate while requests were in flight.
                if (horizontal>1.65 or vertical>2.0) and os.clock()-lastMove>=1 then
                    lastMove=os.clock()
                    stats.potionApproaches+=1
                    local look=farmerMark and getPart(farmerMark)
                    local face=look and look.Position or desired+Vector3.new(-1,0,0)
                    local faceFlat=Vector3.new(face.X,desired.Y,face.Z)
                    local ok,why=pcall(function()
                        hrp.CFrame=CFrame.lookAt(desired,faceFlat)
                        hrp.AssemblyLinearVelocity=Vector3.zero
                        hrp.AssemblyAngularVelocity=Vector3.zero
                    end)
                    if ok then
                        groundHold=os.clock()+0.15
                        reportMessage("POTION_GROUND","Moved off gate to Hander; rootY="..
                            string.format("%.2f",desired.Y).." horizontalBefore="..
                            string.format("%.2f",horizontal).." groundSurface="..tostring(surface))
                    elseif os.clock()-lastReport>=3 then
                        lastReport=os.clock()
                        reportMessage("POTION_WAIT","Ground positioning failed: "..tostring(why))
                    end
                end
                hrp=root()
                local groundDist=hrp and (hrp.Position-desired).Magnitude or math.huge
                if groundDist<=3.3 and os.clock()>=groundHold and os.clock()>=nextRequest then
                    nextRequest=os.clock()+0.45
                    native=native or folder:FindFirstChild("NeedleHandIn")
                    if native and native:IsA("RemoteEvent") then
                        local ok,err=pcall(function()native:FireServer()end)
                        if ok then
                            stats.potionHandInRequests+=1
                            if stats.potionHandInRequests<=4 or stats.potionHandInRequests%8==0 then
                                reportMessage("POTION_HANDIN","Request "..stats.potionHandInRequests..
                                    " sent from GROUND; dist="..string.format("%.2f",groundDist)..
                                    " rootY="..string.format("%.2f",hrp.Position.Y)..
                                    " owned="..tostring(att(player,"NeedleOwned")))
                            end
                        else reportMessage("POTION_WAIT","Hand-in remote error: "..tostring(err)) end
                    elseif os.clock()-lastReport>=3 then
                        lastReport=os.clock()
                        reportMessage("POTION_WAIT","NeedleHandIn RemoteEvent missing")
                    end
                end
            end
            if stage=="POTION" then
                if defeated() then stageTo("DONE")
                else
                    stageTo("POTION_UNCONFIRMED")
                    reportMessage("POTION_WAIT","No server-confirmed boss activation; requests="..
                        stats.potionHandInRequests)
                end
            end
        end
    end)
    
    -- Native potion cutscene Skip. Only acts after the native hand-in is sent;
    -- never skips the final boss-ending cutscene or clicks Replay/Lobby buttons.
    do
        local deadline=0
        local nextClick=0
        local seenButton=nil
        local skipSent=false
        local function isVisible(button)
            local p=button
            while p do
                if p:IsA("GuiObject") and not p.Visible then return false end
                if p:IsA("ScreenGui") and not p.Enabled then return false end
                if p:IsA("PlayerGui") then return true end
                p=p.Parent
            end
            return false
        end
        local function findSkip()
            local pg=player:FindFirstChildOfClass("PlayerGui")
            if not pg then return nil end
            for _,btn in ipairs(pg:GetDescendants()) do
                if btn:IsA("GuiButton") and isVisible(btn) then
                    local label=btn.Name:lower()
                    if btn:IsA("TextButton") then label=label.." "..btn.Text:lower() end
                    local parent=btn.Parent
                    for _=1,3 do
                        if not parent or parent==pg then break end
                        label=label.." "..parent.Name:lower()
                        parent=parent.Parent
                    end
                    if label:find("skip",1,true) and
                        not label:find("replay",1,true) and
                        not label:find("lobby",1,true) then return btn end
                end
            end
        end
        task.spawn(function()
            while alive do
                task.wait(0.14)
                if defeated() or stage=="DONE" then return end
                local now=os.clock()
                local encounterState=tostring(att(boss,"BossState"))
            local nativePotionScene=(truth(att(sundial,"Solved")) and
                (encounterState=="Intro" or encounterState=="Rising"))
            if featureState.AutoPotionSkip and
                (stats.potionHandInRequests>0 or nativePotionScene) and deadline==0 then
                    deadline=now+35
                    reportMessage("POTION_SKIP","Watching for native Skip button")
                end
                if not featureState.AutoPotionSkip or deadline==0 or now>deadline then continue end
                local button=findSkip()
                if button and now>=nextClick then
                    seenButton=button
                    nextClick=now+0.7
                    local pos,size=button.AbsolutePosition,button.AbsoluteSize
                    if size.X>0 and size.Y>0 then
                        local inset=game:GetService("GuiService"):GetGuiInset()
                        local x,y=pos.X+size.X/2+inset.X,pos.Y+size.Y/2+inset.Y
                        local ok,err=pcall(function()
                            VIM:SendMouseMoveEvent(x,y,game)
                            task.wait(0.03)
                            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
                            task.wait(0.07)
                            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
                        end)
                        stats.potionSkipAttempts+=1
                        skipSent=ok
                        reportMessage("POTION_SKIP","Native Skip click #"..stats.potionSkipAttempts..
                            " sent="..tostring(ok).." "..tostring(err))
                        if type(firesignal)=="function" then
                            pcall(function()firesignal(button.Activated)end)
                        end
                    end
                elseif not button and seenButton and skipSent then
                    stats.potionSkipConfirmed+=1
                    reportMessage("POTION_SKIP","Skip disappeared after click (client observation)")
                    return
                end
            end
        end)
    end
    -- Fight worker: two independent attacks plus vacuum mouse hold.
    -- Pitchfork and TNT use the same native game action patterns as Ch3 and Ch4.
    local tntRemote=folder:FindFirstChild("TntAction")
    local pitchforkRemote=folder:FindFirstChild("PitchforkDig")
    local tntPhase=nil
    local tntLitAt=0
    local tntFuse=2.9
    local tntNextAt=0
    local tntAttempts=0
    if tntRemote and tntRemote:IsA("RemoteEvent") then
        connections[#connections+1]=tntRemote.OnClientEvent:Connect(function(kind,value)
            if kind=="lit" and tntPhase=="lighting" then
                tntPhase="lit";tntLitAt=os.clock()
                local fuse=tonumber(value)
                if fuse and fuse>0.1 and fuse<15 then tntFuse=fuse end
                reportMessage("TNT","Server acknowledged light; fuse="..tostring(tntFuse))
            elseif kind=="denied" then
                stats.tntDenied+=1;tntPhase=nil
                tntNextAt=os.clock()+math.max(0.5,tonumber(value) or 1)
                reportMessage("TNT","Server denied lighting; retry after cooldown")
            end
        end)
    end
    local feedback=RS:FindFirstChild("FarmerBoss")
    feedback=feedback and feedback:FindFirstChild("Feedback")
    if feedback and feedback:IsA("RemoteEvent") then
        connections[#connections+1]=feedback.OnClientEvent:Connect(function(...)
            local values={}
            for i=1,math.min(select("#",...),4) do values[i]=tostring(select(i,...)) end
            local text=table.concat(values," | ")
            if #text>280 then text=text:sub(1,280) end
            reportMessage("BOSS_FEEDBACK",text)
        end)
    end
    local function bossAim()
        -- Sceneton Chapter 3 technique: server-aimed pitchfork rays from the
        -- player's head to the animated weak-point Bone, not to camera LookVector.
        local weak=att(boss,"BossWeakPoint")
        local boneName=weak=="Head" and "Head" or
            (weak=="Belly" and "Hips" or "Torso")
        local rig=boss:FindFirstChild("RootPart")
        local bone=rig and rig:FindFirstChild(boneName,true)
        if bone and bone:IsA("Bone") then
            return bone,weak,bone.TransformedWorldCFrame.Position
        end
        local mapping={Head="FB_Head",Chest="FB_Body",Belly="FB_Body"}
        local part=boss:FindFirstChild(mapping[weak] or "BossHitbox")
            or boss:FindFirstChild("FB_Body") or boss:FindFirstChild("RootPart")
        return part,weak,part and part.Position
    end
    local lastBossHealth=n(att(boss,"BossHealth"))
    connections[#connections+1]=boss:GetAttributeChangedSignal("BossHealth"):Connect(function()
        local current=n(att(boss,"BossHealth"))
        if current<lastBossHealth then
            local dmg=lastBossHealth-current
            stats.bossDamage+=dmg;stats.bossHits+=1
            reportMessage("BOSS_HIT","Server health reduced by "..dmg.." -> "..current)
        end
        lastBossHealth=current
    end)
    task.spawn(function()
        local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
            Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
            Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
        local lastEquip=-math.huge
        local lastFollow=-math.huge
        while alive do
            task.wait(0.08)
            if defeated() then stageTo("DONE");releaseVacuum();break end
            if not featureState.AutoBossFight or not featureState.AutoBossVacuum
                or not bossReady() or blocked() then releaseVacuum();continue end
            stageTo("BOSS")
            local target,weak,targetPosition=bossAim()
            if targetPosition then
                local rr=root()
                -- Reposition at most every 2.5 seconds, using floor checks.
                -- Keep the player at native PitchforkReach distance instead
                -- of spamming attacks from outside the server's hit range.
                if rr and os.clock()-lastFollow>=2.5 then
                    local reach=math.clamp(n(att(player,"PitchforkReach")),13,24)
                    local distance=(rr.Position-targetPosition).Magnitude
                    if distance>reach-1.5 and distance<75 then
                        lastFollow=os.clock()
                        releaseVacuum()
                        local groundTarget=boss:FindFirstChild("BossHitbox") or boss:FindFirstChild("RootPart")
                        local ok,why=moveNear(groundTarget,math.min(reach-2,12))
                        if ok then
                            reportMessage("BOSS_MOVE","Positioned near "..tostring(weak or "body"))
                        else
                            reportMessage("BOSS_MOVE","Approach unavailable: "..tostring(why))
                        end
                    end
                end
            end
            if os.clock()-lastEquip>=10 then
                ensureTools()
                lastEquip=os.clock()
            end
            -- Vacuum shares Mouse1 with the camera, but NOT pitchfork remotes.
            local heat=tonumber(att(player,"VacuumHeat"))
            local cooling=truth(att(player,"VacuumOverheated"))
            if not cooling and heat and heat>=0.98 then cooling=true end
            if cooling or os.clock()<vacuumRestUntil then
                releaseVacuum()
                if cooling then vacuumRestUntil=os.clock()+0.4 end
            elseif not vacuumHeld then
                local char=player.Character
                local equipped=false
                if char then
                    for _,x in ipairs(char:GetChildren()) do
                        if x:IsA("Tool") and x.Name:lower():find("vacuum",1,true) then
                            equipped=true
                            break
                        end
                    end
                end
                if not equipped then
                    local key=hotbar[5]
                    pcall(function()VIM:SendKeyEvent(true,key,false,game)end)
                    task.wait(0.05)
                    pcall(function()VIM:SendKeyEvent(false,key,false,game)end)
                    task.wait(0.12)
                end
                local camera=WS.CurrentCamera
                if camera then
                    vacuumPoint=camera.ViewportSize/2
                    pcall(function()
                        VIM:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,true,game,0)
                    end)
                    vacuumHeld=true;vacuumStarted=os.clock()
                end
            elseif heat==nil and os.clock()-vacuumStarted>=25 then
                releaseVacuum();vacuumRestUntil=os.clock()+12
            end
        end
        releaseVacuum()
    end)
    task.spawn(function()
        local nextPitchforkAt=0
        while alive do
            task.wait(0.07)
            if defeated() then return end
            if not featureState.AutoBossFight or not featureState.AutoBossPitchfork
                or not bossReady() or blocked() or not truth(att(player,"PitchforkOwned")) then continue end
            local target,weak,targetPosition=bossAim()
            local h=head()
            local reach=math.clamp(n(att(player,"PitchforkReach")),13,24)
            if targetPosition and h and os.clock()>=nextPitchforkAt then
                local direction=targetPosition-h.Position
                if direction.Magnitude<=reach and direction.Magnitude>0.1 then
                    local remote=pitchforkRemote or folder:FindFirstChild("PitchforkDig")
                    if remote and remote:IsA("RemoteEvent") then
                        local ok,why=pcall(function()
                            remote:FireServer("Boss",h.Position,direction.Unit)
                        end)
                        stats.pitchforkRequests+=ok and 1 or 0
                        nextPitchforkAt=os.clock()+math.max(0.16,n(att(player,"PitchforkCooldown")))
                        if not ok then reportMessage("PITCHFORK","Failed: "..tostring(why)) end
                    end
                end
            end
        end
    end)
    task.spawn(function()
        while alive do
            task.wait(0.08)
            if defeated() then return end
            if not featureState.AutoBossFight or not featureState.AutoBossTNT
                or not bossReady() or blocked() or not truth(att(player,"TntOwned")) then continue end
            local tnt=tntRemote or folder:FindFirstChild("TntAction")
            if not tnt or not tnt:IsA("RemoteEvent") then continue end
            local now=os.clock()
            if tntPhase=="lighting" and now-tntLitAt>=2 then
                tntPhase=nil
                tntNextAt=now+math.max(1,n(att(player,"TntCooldown")))
                reportMessage("TNT","No server lighting ACK; throttle retry")
            end
            if tntPhase=="lit" then
                if now>=tntLitAt+tntFuse-0.1 then
                    tntPhase=nil
                    reportMessage("TNT","Fuse expired before throw")
                elseif now>=tntLitAt+0.25 then
                    local target,weak,targetPosition=bossAim()
                    local camera=WS.CurrentCamera
                    if targetPosition and camera then
                        local origin=camera.CFrame.Position
                        local toTarget=targetPosition-origin
                        if toTarget.Magnitude>1 then
                            local direction=toTarget.Unit
                            local cf=CFrame.lookAt(origin,targetPosition)
                            local velocity=direction*40+Vector3.new(0,8,0)
                            tntPhase=nil
                            local ok,why=pcall(function()
                                tnt:FireServer("throw",cf,velocity)
                            end)
                            if ok then
                                stats.tntThrows+=1
                                reportMessage("TNT","Thrown toward Farmer; health confirmation pending")
                            else reportMessage("TNT","Throw error: "..tostring(why)) end
                        end
                    end
                end
            elseif tntPhase==nil and now>=tntNextAt then
                -- Reserve the request BEFORE FireServer so a very fast server
                -- "lit" callback cannot be lost during the remote call.
                tntPhase="lighting"
                tntLitAt=now
                tntNextAt=now+math.max(1,n(att(player,"TntCooldown")))
                local ok,why=pcall(function()tnt:FireServer("light")end)
                if ok then
                    stats.tntLights+=1
                else
                    tntPhase=nil
                    tntNextAt=now+1
                    reportMessage("TNT","Light request error: "..tostring(why))
                end
            end
        end
    end)
    task.spawn(function()
        while alive do
            task.wait(5)
            saveReport(false)
        end
    end)
    reportMessage("READY","Standalone v4: ground-level potion hand-in (gate avoidance), native Skip, relics/sundial and boss tools. Vacuum native Mouse1; F8 report/F9 stop.")

end

local function running()
    return type(env.__BEYY_CH5_TEST_STOP)=="function"
end
local function stopWorkers(reason)
    local stop=env.__BEYY_CH5_TEST_STOP
    if type(stop)=="function" then pcall(stop,reason or "main menu disabled") end
end
local function startWorkers()
    if unloaded or running() then return end
    task.spawn(function()
        if unloaded or not enabled then return end
        local ok,err=xpcall(startChapter5Workers,function(message)return tostring(message)end)
        if not ok then warn("[BeyyHub Chapter5] Automation worker error: "..tostring(err)) end
    end)
end

local hubWindow=nil
local hubNativeUI=nil
local registry={}
local cacheNotes={}
local function logUI(message)
    print("[BeyyHub Chapter5 Main] "..tostring(message))
end
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
        if self.Window and not self.Window.Destroyed then self.Window.Notice.Text=tostring(options.Title or "Beyy")..": "..tostring(options.Content or "") end
    end
    function UI:CreateWindow(options)
        local w={Closed=false,Destroyed=false,Connections={},Tabs={},ToggleKey=Enum.KeyCode.RightControl}
        self.Window=w
        local parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        if type(gethui)=="function" then local ok,value=pcall(gethui); if ok and value then parent=value end end
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
        local bind="BeyyNativeCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
        local previousBehavior,previousIcon,cursorBound
        local function releaseCursor()
            if cursorBound then return end
            previousBehavior,previousIcon=input.MouseBehavior,input.MouseIconEnabled
            cursorBound=true
            run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+100,function()
                input.MouseBehavior=Enum.MouseBehavior.Default; input.MouseIconEnabled=true
            end)
        end
        local function restoreCursor()
            if not cursorBound then return end
            run:UnbindFromRenderStep(bind); cursorBound=false
            input.MouseBehavior=previousBehavior; input.MouseIconEnabled=previousIcon
        end
        function w:Open() if self.Destroyed then return end; self.Closed=false; gui.Enabled=true; releaseCursor() end
        function w:Close() self.Closed=true; gui.Enabled=false; self.Capture=nil; dragInput=nil; restoreCursor() end
        function w:SetToggleKey(key) self.ToggleKey=typeof(key)=="EnumItem" and key or Enum.KeyCode[tostring(key)] or Enum.KeyCode.RightControl end
        function w:EditOpenButton() end
        function w:Destroy()
            if self.Destroyed then return end
            self:Close(); self.Destroyed=true
            for _,c in ipairs(self.Connections) do c:Disconnect() end
            table.clear(self.Connections); gui:Destroy()
        end
        connect(close.Activated,function() w:Close() end)
        connect(input.InputBegan,function(event,processed)
            if w.Capture and event.UserInputType==Enum.UserInputType.Keyboard and event.KeyCode~=Enum.KeyCode.Unknown then
                local capture=w.Capture; w.Capture=nil; capture:Set(event.KeyCode.Name); return
            end
            if not processed and not input:GetFocusedTextBox() and event.KeyCode==w.ToggleKey then if w.Closed then w:Open() else w:Close() end end
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
                function el:SetDesc(v) desc.Text=tostring(v or "") end
                function el:SetTitle(v) heading.Text=tostring(v or "") end
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

hubNativeUI=createNativeUI()
hubWindow=hubNativeUI:CreateWindow({
    Title=" Beyy Hub Main ",Author="by beyy",Icon="search",
    Folder="BeyyHubChapter5",Size=UDim2.fromOffset(640,480),
    Theme="Dark",HideSearchBar=true,OpenButton={Enabled=false}
})
hubWindow:SetToggleKey(Enum.KeyCode.RightControl)
hubWindow:Close()
env.__BEYY_CH5_UI_OPEN=function()
    return not unloaded and hubWindow and not hubWindow.Closed
end
local function toggleControl(tab,key,title,desc)
    local element=tab:Toggle({
        Title=title,Desc=desc,Value=featureState[key]==true,
        Callback=function(value)
            featureState[key]=value==true
            if key=="AntiAFK" then antiAfkOn=featureState.AntiAFK end
            saveFeatures()
        end
    })
    registry[key]=element
    return element
end
local function sliderControl(tab,key,title,min,max,step)
    local element=tab:Slider({
        Title=title,Value={Min=min,Max=max,Default=featureState[key]},
        Step=step,Callback=function(value)
            featureState[key]=tonumber(value) or ch5Defaults[key]
            saveFeatures()
        end
    })
    registry[key]=element
    return element
end
local overview=hubWindow:Tab({Title="Overview & Settings",Icon="house"})
overview:Section({Title="Chapter 5 • Farmer / Sundial"})
local session=overview:Paragraph({Title="Session Status",Desc="Loading Chapter 5..."})
overview:Keybind({Title="Menu keybind",Value="RightControl",Callback=function(value)
    local key=Enum.KeyCode[tostring(value)]
    if key then hubWindow:SetToggleKey(key) end
end})
toggleControl(overview,"AntiAFK","Anti-AFK (all chapters)")
overview:Button({Title="Start Chapter 5 Automation",Callback=function()
    enabled=true
    saveEnabled()
    startWorkers()
end})
overview:Button({Title="Stop Chapter 5 Automation",Callback=function()
    enabled=false
    saveEnabled()
    stopWorkers("Chapter 5 overview stop")
end})
overview:Button({Title="Unload Hub",Callback=function()
    if type(_G.__BEYY_HUB_CLEANUP)=="function" then _G.__BEYY_HUB_CLEANUP() end
end})
local farm=hubWindow:Section({Title="Farming",Icon="wheat",Opened=true})
local collecting=farm:Tab({Title="Collecting",Icon="wheat"})
local selling=farm:Tab({Title="Selling",Icon="coins"})
local tools=farm:Tab({Title="Tools",Icon="hammer"})
local needle=farm:Tab({Title="Needle & Relics",Icon="search"})
local inventory=hubWindow:Section({Title="Inventory",Icon="backpack",Opened=true})
local shop=inventory:Tab({Title="Shop Items",Icon="shopping-cart"})
local upgrades=inventory:Tab({Title="Upgrades",Icon="trending-up"})
local progress=hubWindow:Section({Title="Chapter 5",Icon="sun",Opened=true})
local puzzle=progress:Tab({Title="Relics & Sundial",Icon="puzzle"})
local bossTab=progress:Tab({Title="Farmer Boss",Icon="swords"})

collecting:Section({Title="Resource Collecting"})
toggleControl(collecting,"AutoPickHay","Auto Pick Hay")
toggleControl(collecting,"AutoCollectDroppedHay","Auto Collect Dropped Hay")
toggleControl(collecting,"AutoCollectGems","Auto Collect Gems")
sliderControl(collecting,"CollectInterval","Collection Interval (s)",0.1,3,0.1)
selling:Section({Title="Selling"})
toggleControl(selling,"AutoSellHay","Auto Sell Hay")
sliderControl(selling,"SellThreshold","Sell When Hay >=",1,250,1)
toggleControl(selling,"SellOnlyIfFull","Only Sell If Full")
tools:Section({Title="Normal hay tools (boss handled separately)"})
toggleControl(tools,"AutoUseTNT","Auto Use TNT")
sliderControl(tools,"TntLightCooldown","TNT Light Cooldown (s)",0,60,0.05)
sliderControl(tools,"TntThrowDelay","TNT Throw Delay (s)",0,5,0.05)
toggleControl(tools,"AutoUsePitchfork","Auto Use Pitchfork")
toggleControl(tools,"AutoDeployDrone","Auto Deploy Drone")
toggleControl(tools,"AutoUseVacuum","Auto Use Vacuum")
sliderControl(tools,"VacuumHotbarSlot","Vacuum Hotbar Slot",1,9,1)
sliderControl(tools,"ToolInterval","Tool Interval (s)",0.2,5,0.1)
needle:Section({Title="Chapter 5 replaces needle with relic tablets"})
needle:Paragraph({Title="Relic Status",Desc="Chapter 5 uses tablets instead of a needle. Controls are in Relics & Sundial."})
shop:Section({Title="Purchasing"})
registry.BuyToolsList=shop:Dropdown({
    Title="Buy Tools Selection",
    Values={"Pitchfork","TNT","Drone","Infinite Bag","Capacity Bag"},
    Value=featureState.BuyToolsList,Multi=true,AllowNone=true,
    Callback=function(v)
        featureState.BuyToolsList=v
        saveFeatures()
    end
})
toggleControl(shop,"AutoBuyTools","Auto Buy Selected Tools")
sliderControl(shop,"BuyInterval","Buy Interval (s)",0.5,5,0.1)
upgrades:Section({Title="Permanent (Gems)"})
toggleControl(upgrades,"UpgBagSize","Auto Upgrade Bag Size")
toggleControl(upgrades,"UpgExtraTake","Auto Upgrade Hand Grab")
toggleControl(upgrades,"UpgGemValue","Auto Upgrade Gem Value")
toggleControl(upgrades,"UpgHayValue","Auto Upgrade Hay Value")
sliderControl(upgrades,"PermInterval","Permanent Upgrade Interval (s)",0.5,5,0.1)
for _,category in ipairs({
    {"Hand (Cash)",{{"UpgHandSpeed","Auto Hand Speed"},{"UpgHandGrab","Auto Hand Grasp"},{"UpgHandHold","Auto Hand Hold"}}},
    {"TNT (Cash)",{{"UpgTntLuck","Auto TNT Lucky Blast"},{"UpgTntCooldown","Auto TNT Cooldown"},{"UpgTntPower","Auto TNT Power"}}},
    {"Pitchfork (Cash)",{{"UpgPitchCooldown","Auto Pitchfork Cooldown"},{"UpgPitchHold","Auto Pitchfork Hold"},{"UpgPitchSweep","Auto Pitchfork Sweep"}}},
    {"Drone (Cash)",{{"UpgDroneSpeed","Auto Drone Speed"},{"UpgDroneGrab","Auto Drone Grasp"},{"UpgDroneCapacity","Auto Drone Capacity"}}},
    {"Vacuum (Cash)",{{"UpgVacPower","Auto Vacuum Power"},{"UpgVacCooling","Auto Vacuum Cooling"},{"UpgVacRuntime","Auto Vacuum Runtime"}}},
    {"Capacity (Cash)",{{"UpgCapacity","Auto Upgrade Carry Capacity"}}}
}) do
    upgrades:Section({Title=category[1]})
    for _,item in ipairs(category[2]) do toggleControl(upgrades,item[1],item[2]) end
end
local upgradeStatus=upgrades:Paragraph({Title="Upgrade Status",Desc="Waiting for replicated upgrade configuration"})
puzzle:Section({Title="Native Chapter 5 progression"})
toggleControl(puzzle,"AutoIntroSkip","Auto Skip Opening Cutscene")
toggleControl(puzzle,"AutoRelics","Auto Grab Relics")
toggleControl(puzzle,"AutoSundial","Auto Solve Sundial")
toggleControl(puzzle,"AutoPotion","Auto Turn In Potion")
toggleControl(puzzle,"AutoPotionSkip","Auto Skip Potion Intro")
puzzle:Paragraph({Title="Puzzle Status",Desc="Sundial positions are solved using live glyph tiles."})
bossTab:Section({Title="Native Farmer boss controls"})
toggleControl(bossTab,"AutoBossFight","Auto Boss Fight")
toggleControl(bossTab,"AutoBossPitchfork","Auto Weakpoint Pitchfork (no camera aim)")
toggleControl(bossTab,"AutoBossTNT","Auto Boss TNT")
toggleControl(bossTab,"AutoBossVacuum","Auto Boss Vacuum (native Mouse1)")
bossTab:Button({Title="Export Chapter 5 Diagnostics (F8)",Callback=function()
    local fn=env.__BEYY_CH5_TEST_REPORT
    if type(fn)=="function" then
        local ok,value=pcall(fn)
        if ok and type(value)=="string" then
            if type(setclipboard)=="function" then pcall(setclipboard,value) end
            print("[BeyyHub Chapter5 Report]\n"..value)
        end
    end
end})
bossTab:Button({Title="Stop Chapter 5 Automation (F9)",Callback=function()
    enabled=false
    saveEnabled()
    stopWorkers("Chapter 5 boss menu stop")
end})
bossTab:Button({Title="Start Chapter 5 Automation",Callback=function()
    enabled=true
    saveEnabled()
    startWorkers()
end})

local config=overview:CollapsibleGroup({Title="Config",Opened=false})
local configName="default"
local pasted=""
config:Input({Title="Config Name",Value="default",Callback=function(v)
    if type(v)=="string" and v:match("^[%w_%-]+$") then configName=v end
end})
local function buildConfig()
    local cfg=hubWindow.ConfigManager:CreateConfig(configName)
    for key,element in pairs(registry) do cfg:Register(key,element) end
    return cfg
end
config:Button({Title="Save Config",Callback=function()
    local ok,errorMessage=pcall(function()return buildConfig():Save()end)
    logUI(ok and ("Saved configuration "..configName) or ("Config save failed: "..tostring(errorMessage)))
end})
config:Button({Title="Load Config",Callback=function()
    local ok,result=pcall(function()return buildConfig():Load()end)
    logUI(ok and ("Loaded configuration "..configName) or ("Config load failed: "..tostring(result)))
end})
config:Button({Title="Copy Config JSON",Callback=function()
    local content=HttpService:JSONEncode({__version=1.2,__elements=(function()
        local elements={}
        for key,el in pairs(registry) do
            local val=el.Value
            if el.__type=="Slider" then val=val.Default end
            elements[key]={__type=el.__type,value=val}
        end
        return elements
    end)()})
    if type(setclipboard)=="function" then pcall(setclipboard,content) end
    print("[BeyyHub Chapter5 Config Export] "..content)
end})
config:Input({Title="Paste Config JSON",Value="",Callback=function(value)
    pasted=tostring(value or "")
end})
config:Button({Title="Import Config JSON",Callback=function()
    local raw=pasted
    if raw=="" and type(getclipboard)=="function" then
        local ok,value=pcall(getclipboard)
        if ok then raw=tostring(value) end
    end
    local success,data=pcall(function()return HttpService:JSONDecode(raw)end)
    if not success or type(data)~="table" then
        warn("[BeyyHub Chapter5 Config] Invalid JSON")
        return
    end
    for key,entry in pairs(data.__elements or data) do
        local el=registry[key]
        if el and type(entry)=="table" and entry.__type==el.__type then
            if el.__type=="Dropdown" then el:Select(entry.value)
            else el:Set(entry.value) end
        end
    end
    saveFeatures()
    logUI("Configuration JSON imported")
end})

-- One central cash upgrade queue, copied verbatim from Chapter 3.
local function createAutoUpgradeRuntime(options)
    local config, configModule, pending
    local idle,waitKey=true,"upgrades"
    local tracks = {
        {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
        {"UpgVacRuntime","VacuumRuntime"},
        {"UpgTntPower","TntPower"},{"UpgTntLuck","TntLuck"},
        {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
        {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
        {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
        {"UpgTntCooldown","TntCooldown"},
    }
    local lastStatus
    local function status(text)
        if text~=lastStatus then lastStatus=text;options.Status(text) end
    end
    local function level(name) return tonumber(options.Player:GetAttribute("HayUpgrade"..name)) or 1 end
    local function cost(name, entry)
        local price=tonumber(entry.Cost)
        if not price or price<0 or price~=price or price==math.huge then return nil end
        price*=tonumber(options.Player:GetAttribute("UpgradeCostMultiplier")) or 1
        if name:sub(1,9)=="Pitchfork" then price*=tonumber(options.Player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
        return math.round(price*100)/100
    end
    local function tick()
        idle,waitKey=true,"upgrades"
        local folder=options.Folder()
        local module=folder and folder:FindFirstChild("Config")
        local remote=folder and folder:FindFirstChild("BuyUpgrade")
        if not module or not remote or not remote:IsA("RemoteEvent") then status("Waiting for upgrade config / remote"); return end
        if configModule~=module or not config then
            local loaded=require(module)
            assert(type(loaded)=="table" and type(loaded.UPGRADE_TRACKS)=="table","Invalid upgrade config")
            config,configModule=loaded,module
            if options.OnConfig then options.OnConfig(loaded) end
        end
        if pending then
            idle=false
            local confirmedLevel=level(pending.Name)
            if confirmedLevel~=pending.Level or not options.State[pending.Flag] then
                if confirmedLevel>pending.Level and options.OnConfirmed then options.OnConfirmed(pending,confirmedLevel) end
                pending=nil
            elseif os.clock()<pending.Until then status("Waiting for "..pending.Name.." purchase confirmation"); return
            else
                status("Server did not confirm "..pending.Name.."; retrying")
                pending=nil
            end
        end
        local cash=tonumber(options.Cash()) or 0
        local selected, available, vacuum, power, earlyTnt, lateTnt=0,{},nil,nil,nil,nil
        for _,entry in ipairs(tracks) do
            if options.State[entry[1]] then
                selected+=1
                local track=config.UPGRADE_TRACKS[entry[2]]
                local current=level(entry[2])
                local nextLevel=track and track.Levels and track.Levels[current+1]
                local price=nextLevel and cost(entry[2],nextLevel)
                if price then
                    local target={Flag=entry[1],Name=entry[2],Level=current,Cost=price}
                    if entry[2]=="TntCooldown" then
                        -- Tracks start at L1: two purchases reach L3.
                        if current<3 then earlyTnt=target else lateTnt=target end
                    else
                        available[#available+1]=target
                    end
                    if entry[2]=="VacuumPower" then power=target end
                    if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                end
            end
        end
        if selected==0 then status("No cash upgrades enabled"); return end
        if #available==0 and not earlyTnt and not lateTnt then status("Selected cash upgrades are maxed or unavailable"); return end
        local target
        if earlyTnt then
            if cash<earlyTnt.Cost then waitKey="upgrades-cash";status(string.format("Saving for TntCooldown: $%.2f / $%.2f",cash,earlyTnt.Cost)); return end
            target=earlyTnt
        elseif power then
            if cash<power.Cost then waitKey="upgrades-cash";status(string.format("Saving for VacuumPower: $%.2f / $%.2f",cash,power.Cost)); return end
            target=power
        elseif vacuum and cash>=vacuum.Cost*0.75 then
            if cash<vacuum.Cost then waitKey="upgrades-cash";status(string.format("Saving for %s: $%.2f / $%.2f",vacuum.Name,cash,vacuum.Cost)); return end
            target=vacuum
        else
            for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
            -- Remaining TNT speed levels wait until all other enabled tracks finish.
            if #available==0 and lateTnt and cash>=lateTnt.Cost then target=lateTnt end
        end
        if not target then
            waitKey="upgrades-cash"
            local cheapest=available[1] or lateTnt
            for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
            status(string.format("Waiting for cash: $%.2f / $%.2f (%s)",cash,cheapest.Cost,cheapest.Name)); return
        end
        idle=false
        -- Reserve before sending: replication may confirm the purchase immediately.
        pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Started=os.clock(),Until=os.clock()+0.25}
        remote:FireServer(target.Name)
        if options.OnRequested then options.OnRequested(pending) end
        status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
    end
    return {IsIdle=function()return idle end,WaitKey=function()return waitKey end,Tick=function()
        local ok,err=pcall(tick)
        if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
    end}
end




local function cash()
    local ls=player:FindFirstChild("leaderstats")
    local value=ls and ls:FindFirstChild("Cash")
    return value and tonumber(value.Value) or 0
end
local function gameRemote(name)
    local folder=RS:FindFirstChild("NeedleHaystack")
    local remote=folder and folder:FindFirstChild(name)
    return remote and remote:IsA("RemoteEvent") and remote or nil
end
local function sendFarmRemote(name,...)
    local remote=gameRemote(name)
    if not remote then return false end
    local args=table.pack(...)
    return pcall(function()remote:FireServer(table.unpack(args,1,args.n))end)
end
local function bossEngaged()
    local b=WS:FindFirstChild("FarmerBoss")
    local state=b and tostring(b:GetAttribute("BossState"))
    local hp=b and tonumber(b:GetAttribute("BossHealth")) or 0
    return hp>0 and state~="Sleeping" and state~="Intro" and state~="Rising"
        and state~="Unavailable" and state~="Falling" and state~="Defeated"
end
local function objectiveStage()
    local fn=env.__BEYY_CH5_TEST_REPORT
    if type(fn)~="function" then return "WAIT" end
    local ok,value=pcall(fn)
    return ok and type(value)=="string"
        and (value:match("Stage:%s*([^\n]+)") or "WAIT") or "WAIT"
end
local function farmAvailable()
    if unloaded or not enabled or not running() or not hubWindow.Closed
        or bossEngaged() then return false end
    local state=objectiveStage()
    if state=="SUNDIAL" or state=="POTION" or state=="BOSS" then return false end
    for _,flag in ipairs({"NeedleInputLocked","CutsceneActive","HintViewerOpen"}) do
        if player:GetAttribute(flag)==true then return false end
    end
    return true
end
local function bagFull()
    return (tonumber(player:GetAttribute("HayHeld")) or 0)
        >=(tonumber(player:GetAttribute("HayCapacity")) or 25)
end
local function closestInFolder(name,idName,limit)
    local folder=WS:FindFirstChild(name)
    local c=player.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if not folder or not r then return nil,nil end
    local nearest,id,distance=nil,nil,limit
    for _,obj in ipairs(folder:GetChildren()) do
        local part=obj:IsA("BasePart") and obj
            or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)))
        if part then
            local objId=idName=="Dropped" and obj or
                (part:GetAttribute(idName) or obj:GetAttribute(idName))
            local d=(part.Position-r.Position).Magnitude
            if objId and d<distance then nearest,id,distance=part,objId,d end
        end
    end
    return nearest,id
end
local function runWorker(seconds,fn)
    task.spawn(function()
        while not unloaded do
            task.wait(seconds)
            local ok,err=pcall(fn)
            if not ok then warn("[BeyyHub Ch5 Worker] "..tostring(err)) end
        end
    end)
end
runWorker(0.10,function()
    if not farmAvailable() then return end
    local now=os.clock()
    if now<(cacheNotes.collectAt or 0) then return end
    cacheNotes.collectAt=now+math.max(0.10,tonumber(featureState.CollectInterval) or 0.5)
    if featureState.AutoPickHay and not bagFull() then
        local part,id=closestInFolder("HaystackClient","HayId",30)
        if id then sendFarmRemote("PickHay",id,{}) end
    end
    if featureState.AutoCollectDroppedHay and not bagFull() then
        local _,obj=closestInFolder("DroppedHay","Dropped",28)
        if obj then sendFarmRemote("PickDroppedHay",obj) end
    end
    if featureState.AutoCollectGems then
        local _,id=closestInFolder("GemsClient","GemId",35)
        if id then sendFarmRemote("CollectGem",id) end
    end
end)
runWorker(0.30,function()
    if not farmAvailable() or not featureState.AutoSellHay then return end
    local held=tonumber(player:GetAttribute("HayHeld")) or 0
    local canSell=featureState.SellOnlyIfFull and bagFull()
        or (not featureState.SellOnlyIfFull and held>=featureState.SellThreshold)
    if held>0 and canSell then sendFarmRemote("SellHay") end
end)
runWorker(0.10,function()
    if not farmAvailable() then return end
    local now=os.clock()
    if now<(cacheNotes.toolsAt or 0) then return end
    cacheNotes.toolsAt=now+math.max(0.2,tonumber(featureState.ToolInterval) or 0.5)
    if featureState.AutoUsePitchfork and player:GetAttribute("PitchforkOwned")==true then
        local _,id=closestInFolder("HaystackClient","HayId",30)
        if id then sendFarmRemote("PitchforkDig",id) end
    end
    if featureState.AutoDeployDrone and player:GetAttribute("DroneOwned")==true
        and player:GetAttribute("DroneDeployed")~=true then
        sendFarmRemote("DeployDrone")
    end
end)
runWorker(0.10,function()
    if not farmAvailable() or not featureState.AutoUseTNT
        or player:GetAttribute("TntOwned")~=true then return end
    local now=os.clock()
    if now<(cacheNotes.tntAt or 0) then return end
    local cool=tonumber(player:GetAttribute("TntCooldown")) or 20
    cacheNotes.tntAt=now+math.max(0.5,cool,tonumber(featureState.TntLightCooldown) or 0)
    if sendFarmRemote("TntAction","light") then
        task.wait(math.max(0,tonumber(featureState.TntThrowDelay) or 0.4))
        if farmAvailable() and featureState.AutoUseTNT then
            local cam=WS.CurrentCamera
            if cam then
                sendFarmRemote("TntAction","throw",cam.CFrame,
                    cam.CFrame.LookVector*40+Vector3.new(0,8,0))
            end
        end
    end
end)
local sharedVacuumHeld=false
local sharedVacuumPoint=Vector2.zero
local sharedVacuumNext=0
local function releaseSharedVacuum()
    if not sharedVacuumHeld then return end
    sharedVacuumHeld=false
    pcall(function()
        VIM:SendMouseButtonEvent(sharedVacuumPoint.X,sharedVacuumPoint.Y,0,false,game,0)
    end)
end
runWorker(0.10,function()
    if not farmAvailable() or not featureState.AutoUseVacuum then
        releaseSharedVacuum()
        return
    end
    if player:GetAttribute("VacuumOverheated")==true or
        (tonumber(player:GetAttribute("VacuumHeat")) or 0)>=0.98 then
        releaseSharedVacuum()
        sharedVacuumNext=os.clock()+0.45
        return
    end
    if sharedVacuumHeld or os.clock()<sharedVacuumNext then return end
    local camera=WS.CurrentCamera
    if not camera then return end
    local character=player.Character
    local equipped=false
    for _,item in ipairs(character and character:GetChildren() or {}) do
        if item:IsA("Tool") and item.Name:lower():find("vacuum",1,true) then equipped=true end
    end
    if not equipped then
        local slot=math.clamp(math.floor(tonumber(featureState.VacuumHotbarSlot) or 5),1,9)
        local key=Enum.KeyCode[({"One","Two","Three","Four","Five","Six","Seven","Eight","Nine"})[slot]]
        VIM:SendKeyEvent(true,key,false,game)
        task.wait(0.05)
        VIM:SendKeyEvent(false,key,false,game)
        task.wait(0.10)
    end
    if not farmAvailable() then return end
    sharedVacuumPoint=camera.ViewportSize/2
    VIM:SendMouseButtonEvent(sharedVacuumPoint.X,sharedVacuumPoint.Y,0,true,game,0)
    sharedVacuumHeld=true
end)
runWorker(0.10,function()
    if not enabled or not running() or not featureState.AutoBuyTools then return end
    -- Chapter 3 reserves cash for enabled Vacuum Power before buying tools.
    -- Keep the same priority when Chapter 5 shared shop automation is enabled.
    if featureState.UpgVacPower then
        local folder=RS:FindFirstChild("NeedleHaystack")
        local configModule=folder and folder:FindFirstChild("Config")
        if configModule then
            local ok,config=pcall(require,configModule)
            local track=ok and config and config.UPGRADE_TRACKS and
                config.UPGRADE_TRACKS.VacuumPower
            local level=tonumber(player:GetAttribute("HayUpgradeVacuumPower")) or 1
            local cost=track and track.Levels and track.Levels[level+1]
            if cost then return end
        end
    end
    local now=os.clock()
    if now<(cacheNotes.shopAt or 0) then return end
    cacheNotes.shopAt=now+math.max(0.5,tonumber(featureState.BuyInterval) or 1)
    local selected=featureState.BuyToolsList or {}
    for key,value in pairs(selected) do
        local name=type(key)=="number" and value or (value==true and key or nil)
        if name=="Pitchfork" and player:GetAttribute("PitchforkOwned")~=true then
            sendFarmRemote("BuyShopItem","Pitchfork")
        elseif name=="TNT" and player:GetAttribute("TntOwned")~=true then
            sendFarmRemote("BuyShopItem","Tnt")
        elseif name=="Drone" and player:GetAttribute("DroneOwned")~=true then
            sendFarmRemote("BuyShopItem","Drone")
        elseif name=="Infinite Bag" and player:GetAttribute("InfiniteBagOwned")~=true then
            sendFarmRemote("BuyShopItem","InfiniteBag")
        end
    end
end)
local permConfig=nil
local permAttempt={}
runWorker(0.10,function()
    if not enabled or not running() then return end
    local now=os.clock()
    if now<(cacheNotes.permAt or 0) then return end
    cacheNotes.permAt=now+math.max(0.5,tonumber(featureState.PermInterval) or 0.5)
    if not permConfig then
        local shared=RS:FindFirstChild("Shared")
        local config=shared and shared:FindFirstChild("Configs")
        config=config and config:FindFirstChild("UpgradeConfig")
        if config then permConfig=require(config) end
    end
    if not permConfig then return end
    local mapping={UpgBagSize="ExtraHoldAmount",UpgExtraTake="ExtraTakeAmount",
        UpgGemValue="GemValue",UpgHayValue="ExtraHayValuePercentage"}
    for flag,name in pairs(mapping) do
        if featureState[flag] then
            local upgrade=permConfig.getUpgrade(name)
            if upgrade then
                local level=tonumber(player:GetAttribute("Upgrade"..name)) or 0
                local max=permConfig:getMaxLevel(upgrade)
                local cost=permConfig:getPrice(upgrade,level)
                if level<max and cost and
                    (tonumber(player:GetAttribute("Gems")) or 0)>=cost and
                    (not permAttempt[name] or now-permAttempt[name]>=0.5) then
                    permAttempt[name]=now
                    sendFarmRemote("BuyUpgrade",name)
                end
            end
        end
    end
end)
local upgradesRuntime=createAutoUpgradeRuntime({
    State=featureState,Player=player,Cash=cash,
    Folder=function()return RS:FindFirstChild("NeedleHaystack")end,
    Status=function(message)
        if not unloaded and upgradeStatus then upgradeStatus:SetDesc(message) end
        if message~=cacheNotes.lastUpgradeStatus then
            cacheNotes.lastUpgradeStatus=message
            if message~="No cash upgrades enabled" then
                print("[BeyyHub Chapter5 Upgrade] "..message)
            end
        end
    end,
    OnConfirmed=function(pending,current)
        print(("[BeyyHub Chapter5 Upgrade] %s L%d->%d confirmed in %.3fs"):format(
            pending.Name,pending.Level,current,os.clock()-pending.Started))
    end
})
runWorker(0.05,function()
    if enabled and running() then upgradesRuntime.Tick() end
end)
-- Stop toggles and handlers also clear held shared vacuum input.
local priorCleanup=_G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP=function()
    releaseSharedVacuum()
    if priorCleanup then priorCleanup() end
end

-- Add native profile/session status and cache cleanup.
task.spawn(function()
    while not unloaded do
        task.wait(1)
        if session then
            local report=env.__BEYY_CH5_TEST_REPORT
            local stage="Waiting"
            if type(report)=="function" then
                local ok,txt=pcall(report)
                if ok and type(txt)=="string" then stage=txt:match("Stage:%s*([^\n]+)") or stage end
            end
            local boss=WS:FindFirstChild("FarmerBoss")
            session:SetDesc("Place "..tostring(game.PlaceId)..
                " | Mode "..(running() and "RUNNING" or "STOPPED")..
                " | Stage "..stage..
                " | Boss HP "..tostring(boss and boss:GetAttribute("BossHealth"))..
                "\nAnti AFK active | F8 diagnostics | RightControl closes/opens")
        end
    end
end)
_G.__BEYY_HUB_CLEANUP=function()
    if unloaded then return end
    unloaded=true
    releaseSharedVacuum()
    stopWorkers("Chapter 5 Main unloaded")
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    if hubWindow then pcall(function()hubWindow:Destroy()end)end
    if env.__BEYY_CH5_UI_OPEN then env.__BEYY_CH5_UI_OPEN=nil end
    if env.__BEYY_CH5_FEATURES==featureState then env.__BEYY_CH5_FEATURES=nil end
    _G.__BEYY_HUB_LOADED=false
end
if enabled then startWorkers() end
print("[BeyyHub] v103.00 Chapter5 FULL NATIVE module loaded (RightControl to open)")
print("[BeyyHub Chapter5] Chapters 2-4 style Farming, Inventory, Upgrades, Config and Chapter5 controls ready")
