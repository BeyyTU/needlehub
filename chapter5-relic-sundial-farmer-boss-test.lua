-- BeyyHub Chapter 5 standalone AUTOMATION TEST v2 (live tile-angle sundial solver)
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
    if not alive then return true end
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
        "CHAPTER 5 AUTO TEST v2",
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
    buyTool("Tnt","TntOwned")
    buyTool("Pitchfork","PitchforkOwned")
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
    while alive and stage~="BOSS" and not defeated() do
        task.wait(0.12)
        if blocked() then continue end
        if truth(att(sundial,"Solved")) then stageTo("POTION");break end
        if allRelicsTaken()<3 then
            stageTo("RELICS")
            for _,name in ipairs({"SandTablet","ClayTablet","SlateTablet"}) do
                if not alive or blocked() then break end
                local t=relics:FindFirstChild(name)
                if t and not truth(att(t,"Taken")) then
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
        while alive and os.clock()<untilAt and not defeated() do
            task.wait(0.12)
            if bossReady() then
                stats.potionHandInConfirmed+=1
                reportMessage("POTION_CONFIRMED","Native Farmer encounter active; hand-in requests="..
                    stats.potionHandInRequests.." initialNeedleOwned="..tostring(startingOwned))
                stageTo("BOSS")
                break
            end
            if blocked() then continue end
            local npcs=WS:FindFirstChild("NPC")
            local actualFarmer=npcs and npcs:FindFirstChild("Farmer_NPC")
                or WS:FindFirstChild("Farmer_NPC")
            local target=actualFarmer or hander or farmerMark
            if not target then
                if os.clock()-lastReport>=3 then
                    lastReport=os.clock()
                    reportMessage("POTION_WAIT","No Farmer NPC or PotionScene target replicated")
                end
                continue
            end
            if os.clock()-lastMove>=0.9 then
                lastMove=os.clock()
                stats.potionApproaches+=1
                local ok,why=moveNear(target,actualFarmer and 7 or 4.5)
                if not ok and os.clock()-lastReport>=3 then
                    lastReport=os.clock()
                    reportMessage("POTION_WAIT","Approach "..target:GetFullName()..
                        " failed: "..tostring(why))
                end
            end
            local hrp=root()
            local part=getPart(target)
            local dist=hrp and part and (hrp.Position-part.Position).Magnitude or math.huge
            if dist<=12 and os.clock()>=nextRequest then
                nextRequest=os.clock()+0.45
                native=native or folder:FindFirstChild("NeedleHandIn")
                if native and native:IsA("RemoteEvent") then
                    local ok,err=pcall(function()native:FireServer()end)
                    if ok then
                        stats.potionHandInRequests+=1
                        if stats.potionHandInRequests<=4 or stats.potionHandInRequests%8==0 then
                            reportMessage("POTION_HANDIN","Request "..stats.potionHandInRequests..
                                " sent; distance="..string.format("%.1f",dist)..
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
            if stats.potionHandInRequests>0 and deadline==0 then
                deadline=now+35
                reportMessage("POTION_SKIP","Watching for native Skip button")
            end
            if deadline==0 or now>deadline then continue end
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
    local weak=att(boss,"BossWeakPoint")
    local mapping={Head="FB_Head",Chest="FB_Body",Belly="FB_Body"}
    local part=boss:FindFirstChild(mapping[weak] or "BossHitbox")
        or boss:FindFirstChild("FB_Body") or boss:FindFirstChild("RootPart")
    return part,weak
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
local function aimAt(pos)
    local camera=WS.CurrentCamera
    if not camera then return end
    camera.CFrame=CFrame.lookAt(camera.CFrame.Position,pos)
end
task.spawn(function()
    local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
        Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
        Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
    local lastEquip=-math.huge
    local lastFollow=-math.huge
    while alive do
        task.wait(0.08)
        if defeated() then stageTo("DONE");releaseVacuum();break end
        if not bossReady() or blocked() then releaseVacuum();continue end
        stageTo("BOSS")
        local target,weak=bossAim()
        if target then
            local rr=root()
            -- Reposition at most every 2.5 seconds, using floor checks.
            -- Keep the player at native PitchforkReach distance instead
            -- of spamming attacks from outside the server's hit range.
            if rr and os.clock()-lastFollow>=2.5 then
                local reach=math.clamp(n(att(player,"PitchforkReach")),13,24)
                local distance=(rr.Position-target.Position).Magnitude
                if distance>reach-1.5 and distance<75 then
                    lastFollow=os.clock()
                    releaseVacuum()
                    local ok,why=moveNear(target,math.min(reach-2,12))
                    if ok then
                        reportMessage("BOSS_MOVE","Positioned near "..tostring(weak or "body"))
                    else
                        reportMessage("BOSS_MOVE","Approach unavailable: "..tostring(why))
                    end
                end
            end
            aimAt(target.Position)
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
        if not bossReady() or blocked() or not truth(att(player,"PitchforkOwned")) then continue end
        local target,weak=bossAim()
        local h=head()
        local reach=math.clamp(n(att(player,"PitchforkReach")),13,24)
        if target and h and os.clock()>=nextPitchforkAt then
            local direction=target.Position-h.Position
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
        if not bossReady() or blocked() or not truth(att(player,"TntOwned")) then continue end
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
                local target=bossAim()
                local camera=WS.CurrentCamera
                if target and camera then
                    local origin=camera.CFrame.Position
                    local toTarget=target.Position-origin
                    if toTarget.Magnitude>1 then
                        local direction=toTarget.Unit
                        local cf=CFrame.lookAt(origin,target.Position)
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
reportMessage("READY","Standalone v2: relic prompts + live-angle sundial turns, potion approach, boss TNT+pitchfork+vacuum. F8 report/F9 stop.")
