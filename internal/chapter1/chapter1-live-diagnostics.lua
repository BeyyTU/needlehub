-- BeyyHub Chapter 1 FULL-ROUND AUTO DIAGNOSTICS v2
-- Passive Main/Standalone monitor: upgrades, intro Skip, needle and hand-in.
-- Streams important events immediately to Potassium/Roblox print console and
-- prints a full state heartbeat every 15s, including upgrade affordability.
-- Still saves every 2s and copies round reports on results/teleport.
-- F10 prints/exports a full diagnostic report; F11 stops diagnostics only.
return function(options)
    options=options or {}
    local source=options.Source=="standalone" and "standalone" or "main"
    local player=game:GetService("Players").LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local WS=game:GetService("Workspace")
    local UIS=game:GetService("UserInputService")
    local Http=game:GetService("HttpService")
    if type(_G.__BEYY_CH1_DIAG_STOP)=="function" then
        pcall(_G.__BEYY_CH1_DIAG_STOP)
    end
    local alive=true
    local started=os.clock()
    local path="BeyyHub/chapter1_"..source.."_diagnostics.txt"
    local events,connections,previous={},{},{}
    -- Forward declaration: native Main/Standalone result signals can trigger
    -- export immediately instead of waiting for a periodic GUI sample.
    local finalizeRound
    -- Retain the tail of earlier replay sessions in the same report file.
    -- Cap retained bytes to avoid unbounded disk growth during long AFK runs.
    local earlier=""
    if type(readfile)=="function" then
        local ok,old=pcall(readfile,path)
        if ok and type(old)=="string" and #old>0 then
            earlier=old:sub(-140000)
        end
    end
    local lastSave=-math.huge
    local lastBeat=-math.huge
    local round=1
    local roundStarted=os.clock()
    local roundFinalized=false
    local resultsLast=false
    local findings={}
    local alerted={}
    local lastUpgradeStatus="(none)"
    local upgradeRequestedAt=nil
    local upgradeConfirmedAt=nil
    local upgradeRequestedName=nil
    local upgradeRequests=0
    local upgradeConfirmations=0
    local upgradeFirstRequestAt=nil
    local previousLevels={}
    local skipFirstAt=nil
    local skipAttempts=0
    local skipLastAttemptAt=nil
    local needleFirstAt=nil
    local needleResultAt=nil
    local ownedFirstAt=nil
    local handinAttempts=0
    local handinLastAt=nil
    local affordabilityFirstAt=nil
    local lastClipboardStatus="not copied"
    local roundReports={}
    local lastStatusConsoleAt=-math.huge
    local lastStateConsoleAt={}
    local function consoleLine(message)
        -- Ordinary print/warn writes directly to the executor's Roblox console.
        print("[CH1 DIAG]["..source.."] "..tostring(message))
    end
    local function sinceRound()
        return math.max(0,os.clock()-roundStarted)
    end
    local tracks={
        {"UpgTntCooldown","TntCooldown"},{"UpgVacPower","VacuumPower"},
        {"UpgTntPower","TntPower"},{"UpgVacRuntime","VacuumRuntime"},
        {"UpgVacCooling","VacuumCooling"},{"UpgTntLuck","TntLuck"},
        {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},
        {"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
        {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},
        {"UpgPitchSweep","Pitchfork"},{"UpgDroneSpeed","DroneSpeed"},
        {"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
    }
    local function safe(f,default)
        local ok,res=pcall(f)
        return ok and res or default
    end
    local function record(kind,message)
        if not alive then return end
        local msg=tostring(message)
        if #msg>700 then msg=msg:sub(1,700).."..." end
        local entry=string.format("ROUND %d +%.2fs [%-18s] %s",round,sinceRound(),kind,msg)
        events[#events+1]=entry
        if #events>2000 then table.remove(events,1) end
        local now=os.clock()
        if kind=="UPGRADE_STATUS" then
            lastUpgradeStatus=msg
        elseif kind=="UPGRADE_REQUEST" then
            upgradeFirstRequestAt=upgradeFirstRequestAt or now
            upgradeRequestedAt=now;upgradeRequestedName=msg
            upgradeRequests+=1
        elseif kind=="UPGRADE_CONFIRMED" then
            upgradeConfirmedAt=now
            upgradeConfirmations+=1
            upgradeRequestedAt=nil
        elseif kind=="SKIP_ATTEMPT" then
            skipAttempts+=1;skipLastAttemptAt=now
        elseif kind=="NEEDLE_RESULT" then
            needleResultAt=now
        elseif kind=="HANDIN_REQUEST" then
            handinAttempts+=1;handinLastAt=now
        end
        if kind=="ROUND_RESULTS" and finalizeRound and not roundFinalized then
            task.defer(finalizeRound,"native results controller")
        end
        -- Live Potassium console output. Do not print every cash change: it
        -- can update dozens of times per second during vacuum farming.
        local important={
            POSSIBLE_ISSUE=true,ROUND_END=true,ROUND_START=true,ROUND_RESULTS=true,
            UPGRADE_REQUEST=true,UPGRADE_CONFIRMED=true,
            SKIP_SEEN=true,SKIP_ATTEMPT=true,NEEDLE_RESULT=true,
            HANDIN_READY=true,HANDIN_POSITION=true,HANDIN_REQUEST=true,
            HANDIN_CONFIRMED=true,HANDIN_WAIT=true,
            TELEPORT=true,EXPORT=true,STOP=true,
            ERROR=true,START=true
        }
        if important[kind] then
            consoleLine(entry)
        elseif kind=="HEARTBEAT" then
            consoleLine("[15s STATUS] "..msg:sub(1,2400))
        elseif kind=="UPGRADE_STATUS" then
            -- The scheduler already deduplicates status changes; console-limit
            -- bursts from retries without hiding their latest state.
            if now-lastStatusConsoleAt>=4 or msg:find("error",1,true)
                or msg:find("No cash upgrades",1,true) then
                lastStatusConsoleAt=now
                consoleLine(entry)
            end
        elseif kind=="STATE" then
            local field=msg:match("^(%w+) = ")
            if field and field~="upgrades" and field~="farmerDistance"
                and field~="hoveredHayId" then
                if not lastStateConsoleAt[field] or
                    now-lastStateConsoleAt[field]>=3 or
                    field=="mode" or field=="needleOwned" or field=="results" then
                    lastStateConsoleAt[field]=now
                    consoleLine(entry)
                end
            end
        end
    end
    local function issue(key,message)
        local id=tostring(round)..":"..key
        if alerted[id] then return end
        alerted[id]=true
        local line="ROUND "..round.." +"
            ..string.format("%.2fs",sinceRound()).." "..tostring(message)
        findings[#findings+1]=line
        if #findings>120 then table.remove(findings,1) end
        record("POSSIBLE_ISSUE",message)
    end
    local function visible(obj)
        while obj do
            if obj:IsA("GuiObject") and not obj.Visible then return false end
            if obj:IsA("ScreenGui") and not obj.Enabled then return false end
            if obj:IsA("PlayerGui") then return true end
            obj=obj.Parent
        end
        return false
    end
    local function skipStatus()
        local pg=player and player:FindFirstChildOfClass("PlayerGui")
        if not pg then return "PlayerGui unavailable" end
        local names={}
        for _,obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("GuiButton") then
                local text=obj.Name
                if obj:IsA("TextButton") then text=text.." "..obj.Text end
                local parent=obj.Parent
                for _=1,3 do
                    if not parent or parent==pg then break end
                    text=text.." "..parent.Name
                    parent=parent.Parent
                end
                if text:lower():find("skip",1,true) then
                    names[#names+1]=obj:GetFullName()..
                        (visible(obj) and ":VISIBLE" or ":HIDDEN")
                    if #names>=4 then break end
                end
            end
        end
        return #names>0 and table.concat(names,"; ") or "no Skip GUI candidate"
    end
    local function needleStatus()
        local server=WS:FindFirstChild("NeedleObjectiveServer")
        local folder=server and server:FindFirstChild("Needle")
        if not folder then return "NeedleObjectiveServer.Needle not replicated" end
        local exposed,hidden,total=0,0,0
        local detail=""
        for _,part in ipairs(folder:GetDescendants()) do
            if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective")==true then
                total+=1
                local hiddenFlag=part:GetAttribute("HIDDEN_WITHIN")
                if hiddenFlag==nil or hiddenFlag==false then
                    exposed+=1
                    detail="HayId="..tostring(part:GetAttribute("HayId"))..
                        " Pos="..tostring(part.Position)
                else
                    hidden+=1
                end
            end
        end
        return string.format("total=%d exposed=%d hidden=%d %s",total,exposed,hidden,detail)
    end
    local function upgradeStatus()
        local folder=RS:FindFirstChild("NeedleHaystack")
        local module=folder and folder:FindFirstChild("Config")
        local cfg=module and safe(function()return require(module)end,nil)
        local ls=player and player:FindFirstChild("leaderstats")
        local cash=ls and ls:FindFirstChild("Cash")
        local amount=cash and tonumber(cash.Value) or 0
        local rows={}
        local enabledCount,affordableCount=0,0
        for _,item in ipairs(tracks) do
            local selected=options.Enabled and safe(function()return options.Enabled(item[1])end,false)
            if selected then
                enabledCount+=1
                local level=tonumber(player:GetAttribute("HayUpgrade"..item[2])) or 1
                local track=cfg and cfg.UPGRADE_TRACKS and cfg.UPGRADE_TRACKS[item[2]]
                local nextLevel=track and track.Levels and track.Levels[level+1]
                local cost=nextLevel and tonumber(nextLevel.Cost)
                if cost then
                    cost*=tonumber(player:GetAttribute("UpgradeCostMultiplier")) or 1
                    if item[2]:sub(1,9)=="Pitchfork" then
                        cost*=tonumber(player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1
                    end
                    cost=math.round(cost*100)/100
                    if amount>=cost then affordableCount+=1 end
                end
                rows[#rows+1]=item[2].." L"..level..
                    (cost and (" next=$"..cost.." ["..(amount>=cost and "AFFORDABLE" or "SAVING").."]") or " MAX/NO CONFIG")
            end
        end
        return string.format("cash=%.2f remote=%s enabled=%d affordable=%d %s",
            amount,tostring(folder and folder:FindFirstChild("BuyUpgrade")~=nil),
            enabledCount,affordableCount,
            #rows>0 and table.concat(rows," | ") or "NO ENABLED UPGRADE TRACKS"),
            enabledCount,affordableCount
    end
    local function snapshot()
        local pg=player and player:FindFirstChildOfClass("PlayerGui")
        local ending=pg and pg:FindFirstChild("NeedleEndingUI")
        local results=ending and ending:FindFirstChild("ReturnToLobby")
        local npc=WS:FindFirstChild("NPC")
        local farmer=npc and npc:FindFirstChild("Farmer_NPC")
        local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local distance=(farmer and hrp) and safe(function()
            return string.format("%.1f studs",(farmer:GetPivot().Position-hrp.Position).Magnitude)
        end,"distance unavailable") or "Farmer_NPC/HRP missing"
        local upgradeText,enabledCount,affordableCount=upgradeStatus()
        local skip=skipStatus()
        local needle=needleStatus()
        return {
            mode=options.Mode and safe(options.Mode,"unknown") or "unknown",
            upgrades=upgradeText,
            enabledUpgradeCount=enabledCount,
            affordableUpgradeCount=affordableCount,
            needle=needle,
            exposedNeedleCount=tonumber(needle:match("exposed=(%d+)")) or 0,
            visibleSkip=skip:find(":VISIBLE",1,true)~=nil,
            resultsVisible=results and visible(results) or false,
            needleOwned=tostring(player:GetAttribute("NeedleOwned")),
            hoveredHayId=tostring(player:GetAttribute("HoveredHayId")),
            needlePickupBusy=options.PickupBusy and tostring(safe(options.PickupBusy,false)) or "unknown",
            pickupEnabled=options.NeedleEnabled and safe(options.NeedleEnabled,false)==true
                or false,
            handinEnabled=options.HandInEnabled and safe(options.HandInEnabled,false)==true
                or false,
            uiMouseBusy=options.MouseBusy and tostring(safe(options.MouseBusy,false)) or "unknown",
            farmerDistance=distance,
            skip=skip,
            results=tostring(results and visible(results) or false),
            cutscene=tostring(player:GetAttribute("CutsceneActive")),
            needleInputLocked=tostring(player:GetAttribute("NeedleInputLocked")),
        }
    end
    local fields={"mode","upgrades","needle","needleOwned","hoveredHayId",
        "needlePickupBusy","uiMouseBusy","farmerDistance","skip","results",
        "cutscene","needleInputLocked"}
    local function report(currentRoundOnly)
        local current=safe(snapshot,{})
        local lines={"BeyyHub Chapter 1 FULL-ROUND DIAGNOSTICS v2",
            "Mode="..source.." PlaceId="..tostring(game.PlaceId)..
                " JobId="..tostring(game.JobId),
            "Elapsed="..string.format("%.2f",os.clock()-started).."s"..
                " | Round="..round.." | RoundSeconds="..string.format("%.1f",sinceRound()),
            "UpgradeRequests="..upgradeRequests.." Confirmations="..upgradeConfirmations..
                " LastStatus="..lastUpgradeStatus,
            "PickupEnabled="..tostring(current.pickupEnabled)..
                " HandInEnabled="..tostring(current.handinEnabled),
            "SkipAttempts="..skipAttempts.." HandInAttempts="..handinAttempts..
                " Clipboard="..lastClipboardStatus,
            "=== AUTOMATIC POSSIBLE-ISSUE FINDINGS ===" }
        if #findings==0 then lines[#lines+1]="No specific stall conditions detected yet." end
        for _,finding in ipairs(findings) do lines[#lines+1]=finding end
        lines[#lines+1]="=== LIVE STATE ==="
        for _,key in ipairs(fields) do
            lines[#lines+1]=key.." = "..tostring(current[key])
        end
        if earlier~="" and not currentRoundOnly then
            lines[#lines+1]="=== PRIOR REPLAY SESSION HISTORY (RETAINED TAIL) ==="
            lines[#lines+1]=earlier
        end
        lines[#lines+1]="=== CURRENT SESSION TIMELINE ==="
        for _,entry in ipairs(events) do
            if not currentRoundOnly or entry:find("^ROUND "..round.." ",1)==1 then
                lines[#lines+1]=entry
            end
        end
        local body=table.concat(lines,"\n")
        if currentRoundOnly and #body>70000 then
            -- Clipboard backends sometimes reject very large strings.
            -- Preserve findings plus early/late events. Disk keeps all events.
            body=body:sub(1,35000)..
                "\n=== MIDDLE EVENTS OMITTED FROM CLIPBOARD; FULL ROUND SAVED TO FILE ===\n"..
                body:sub(-30000)
        end
        return body
    end
    local function save()
        if type(writefile)~="function" then return false end
        local ok=pcall(function()
            if type(makefolder)=="function" and
                (type(isfolder)~="function" or not isfolder("BeyyHub")) then
                makefolder("BeyyHub")
            end
            writefile(path,report(false))
        end)
        return ok
    end
    local function printFullConsoleReport(content)
        -- F10 also prints a bounded, chunked report into Potassium's console.
        -- Per-line chunking avoids the console silently dropping huge prints.
        local maxSize=38000
        local text=tostring(content or "")
        local clipped=false
        if #text>maxSize then
            text=text:sub(1,18000)..
                "\n=== MIDDLE EVENTS OMITTED IN CONSOLE (FULL FILE STILL SAVED) ===\n"..
                text:sub(-18000)
            clipped=true
        end
        consoleLine("=== F10 FULL REPORT START | "..#text.." chars"..(clipped and " (bounded)" or "").." ===")
        for line in (text.."\n"):gmatch("(.-)\n") do
            if line~="" then
                for i=1,#line,1100 do
                    consoleLine(line:sub(i,i+1099))
                end
            end
        end
        consoleLine("=== F10 FULL REPORT END | file="..path.." ===")
    end
    local function copyToClipboard(content)
        local providers={}
        if type(setclipboard)=="function" then
            providers[#providers+1]={"setclipboard",setclipboard}
        end
        if type(toclipboard)=="function" and toclipboard~=setclipboard then
            providers[#providers+1]={"toclipboard",toclipboard}
        end
        if type(set_clipboard)=="function" and set_clipboard~=setclipboard then
            providers[#providers+1]={"set_clipboard",set_clipboard}
        end
        if #providers==0 then return false,"executor has no clipboard function" end
        local problems={}
        for _,candidate in ipairs(providers) do
            local ok,err=pcall(candidate[2],content)
            if ok then
                if type(getclipboard)=="function" then
                    local verified,value=pcall(getclipboard)
                    if verified and type(value)=="string" and value~=content then
                        problems[#problems+1]=candidate[1].." returned but read-back differs"
                        continue
                    end
                end
                return true,candidate[1]
            end
            problems[#problems+1]=candidate[1]..": "..tostring(err)
        end
        return false,table.concat(problems,"; ")
    end
    finalizeRound=function(trigger)
        if roundFinalized then return end
        roundFinalized=true
        record("ROUND_END","trigger="..tostring(trigger).." duration="..
            string.format("%.2fs",sinceRound())..
            " upgradeRequests="..upgradeRequests.." confirmations="..upgradeConfirmations..
            " skipAttempts="..skipAttempts.." handInAttempts="..handinAttempts)
        -- Copy a useful complete-round timeline BEFORE replay and also
        -- persist the unrestricted report; never assume a clipboard worked.
        local exported=report(true)
        local copied,method=copyToClipboard(exported)
        lastClipboardStatus=copied
            and ("round "..round.." copied via "..method.." ("..#exported.." bytes)")
            or ("round "..round.." copy failed: "..tostring(method))
        record("EXPORT",lastClipboardStatus)
        local written=save()
        consoleLine("ROUND "..round.." COMPLETE | duration="..
            string.format("%.1fs",sinceRound())..
            " requests="..upgradeRequests.." confirmed="..upgradeConfirmations..
            " skipAttempts="..skipAttempts.." handInAttempts="..handinAttempts..
            " findings="..#findings.." | clipboard="..tostring(copied)..
            " | saved="..tostring(written).." | "..path)
        if #findings==0 then
            consoleLine("ROUND "..round.." analysis: no automatic stall conditions flagged")
        else
            for _,finding in ipairs(findings) do
                if finding:find("^ROUND "..round.." ",1)==1 then
                    consoleLine("[ROUND FINDING] "..finding)
                end
            end
        end
        if not copied then
            warn("[CH1 DIAG] Automatic clipboard failed: "..tostring(method)..
                ". Use "..path.." or F10 to export.")
        end
    end
    local function beginRound()
        round+=1
        roundStarted=os.clock()
        roundFinalized=false
        skipFirstAt=nil;skipLastAttemptAt=nil;skipAttempts=0
        needleFirstAt=nil;needleResultAt=nil
        ownedFirstAt=nil;handinAttempts=0;handinLastAt=nil
        upgradeRequests=0;upgradeConfirmations=0
        upgradeRequestedAt=nil;upgradeConfirmedAt=nil
        upgradeFirstRequestAt=nil
        affordabilityFirstAt=nil
        record("ROUND_START","New Chapter 1 round after results dismissed")
        save()
    end
    local function stop()
        if not alive then return end
        record("STOP","Diagnostic stopped; incomplete round saved without clipboard overwrite")
        alive=false
        for _,connection in ipairs(connections) do
            pcall(function()connection:Disconnect()end)
        end
        save()
        if _G.__BEYY_CH1_DIAG_EVENT==record then
            _G.__BEYY_CH1_DIAG_EVENT=nil
        end
        if _G.__BEYY_CH1_DIAG_STOP==stop then
            _G.__BEYY_CH1_DIAG_STOP=nil
        end
    end
    _G.__BEYY_CH1_DIAG_EVENT=record
    _G.__BEYY_CH1_DIAG_STOP=stop
    local teleportSeen=false
    connections[#connections+1]=player.OnTeleport:Connect(function(status)
        if not alive or teleportSeen then return end
        if status~=Enum.TeleportState.Started and
            status~=Enum.TeleportState.InProgress then return end
        teleportSeen=true
        record("TELEPORT","Replay teleport state="..tostring(status))
        finalizeRound("Replay teleport")
    end)
    _G.__BEYY_CH1_DIAG_REPORT=report
    connections[#connections+1]=UIS.InputBegan:Connect(function(key,used)
        if used then return end
        if key.KeyCode==Enum.KeyCode.F10 then
            local saved=save()
            local content=report(true)
            local copied,method=copyToClipboard(content)
            printFullConsoleReport(content)
            consoleLine("Manual report: clipboard="..tostring(copied)..
                " method="..tostring(method).." saved="..tostring(saved)..
                " file="..path)
        elseif key.KeyCode==Enum.KeyCode.F11 then
            stop()
            print("[CH1 DIAG] Diagnostics stopped, automation left running.")
        end
    end)
    task.spawn(function()
        record("START","Full round automatic monitor active: upgrades, Skip, needle, hand-in")
        record("ROUND_START","Round telemetry started in Chapter 1; no hotkeys required")
        while alive and not (options.Stopped and safe(options.Stopped,false)) do
            local ok,current=pcall(snapshot)
            if ok then
                local now=os.clock()
                local workingMode=tostring(current.mode)
                local monitoring=workingMode~="Off"
                if current.resultsVisible and not resultsLast then
                    finalizeRound("results screen became visible")
                elseif not current.resultsVisible and resultsLast and roundFinalized then
                    beginRound()
                end
                resultsLast=current.resultsVisible
                if monitoring and not current.resultsVisible and not roundFinalized then
                    -- Detect upgrade selection and request/confirmation stalls.
                    if current.enabledUpgradeCount==0 and (workingMode=="Wins" or workingMode=="Hay") then
                        issue("upgrade-no-selection","NO CASH UPGRADE TOGGLES enabled during "..workingMode..
                            " mode. Chapter 1 now uses Chapter 3's explicit per-track toggles.")
                    end
                    if current.affordableUpgradeCount>0 then
                        affordabilityFirstAt=affordabilityFirstAt or now
                        if now-affordabilityFirstAt>5 and
                            (not upgradeRequestedAt or now-upgradeRequestedAt>5) and
                            (not upgradeConfirmedAt or now-upgradeConfirmedAt>5) then
                            issue("upgrade-no-request","One or more enabled upgrades affordable for 5s; "..
                                "no recent purchase request/confirmation. Status="..lastUpgradeStatus)
                        end
                    else affordabilityFirstAt=nil end
                    if upgradeFirstRequestAt and upgradeRequests>=7 and
                        upgradeConfirmations==0 and now-upgradeFirstRequestAt>=4 then
                        issue("upgrade-retries-unconfirmed",
                            "At least "..upgradeRequests..
                            " cash-upgrade purchase requests and zero confirmations over "..
                            string.format("%.1fs",now-upgradeFirstRequestAt)..
                            "; latest="..tostring(upgradeRequestedName)..
                            " status="..lastUpgradeStatus)
                    end
                    if upgradeRequestedAt and now-upgradeRequestedAt>2.5 then
                        issue("upgrade-unconfirmed-"..tostring(upgradeRequestedName),
                            "Last purchase request has no confirmation after 2.5s: "..
                            tostring(upgradeRequestedName).." status="..lastUpgradeStatus)
                    end
                    -- Intro Skip can be present but suppressed by needle priority.
                    if current.visibleSkip then
                        skipFirstAt=skipFirstAt or now
                        if now-skipFirstAt>6 then
                            issue("skip-still-visible","Skip UI stayed visible for over 6s; "..
                                "attempts="..skipAttempts.." needleOwned="..
                                current.needleOwned.." pickupBusy="..current.needlePickupBusy..
                                " mouseBusy="..current.uiMouseBusy)
                        end
                    else skipFirstAt=nil end
                    -- Detect exposed needle with neither pickup nor ownership.
                    if current.pickupEnabled and current.exposedNeedleCount>0 and
                        current.needleOwned=="false" then
                        needleFirstAt=needleFirstAt or now
                        if now-needleFirstAt>8 then
                            issue("needle-exposed-uncollected",
                                "Needle exposed for 8+s but not owned; "..
                                current.needle.." pickupBusy="..current.needlePickupBusy..
                                " lastResult="..tostring(needleResultAt))
                        end
                    else needleFirstAt=nil end
                    -- Server-owned NeedleOwned should clear after Farmer hand-in.
                    if current.handinEnabled and current.needleOwned=="true" then
                        ownedFirstAt=ownedFirstAt or now
                        if now-ownedFirstAt>8 and handinAttempts==0 then
                            issue("handin-no-requests",
                                "NeedleOwned true for 8+s; no Farmer hand-in request observed. "..
                                "Farmer distance="..current.farmerDistance)
                        end
                        if now-ownedFirstAt>12 and handinAttempts>=3 then
                            issue("handin-not-accepted",
                                "NeedleOwned still true after "..handinAttempts..
                                " hand-in requests; distance="..current.farmerDistance)
                        end
                    else ownedFirstAt=nil end
                end
                for _,field in ipairs(fields) do
                    local value=tostring(current[field])
                    if previous[field]~=value then
                        previous[field]=value
                        if field~="farmerDistance" then
                            record("STATE",field.." = "..value)
                        end
                    end
                end
            else record("ERROR","Failed to sample: "..tostring(current)) end
            if os.clock()-lastBeat>=15 then
                lastBeat=os.clock()
                record("HEARTBEAT",tostring(previous.mode)..
                    " | "..tostring(previous.upgrades)..
                    " | needle="..tostring(previous.needle)..
                    " | owned="..tostring(previous.needleOwned)..
                    " | skip="..tostring(previous.skip)..
                    " | farmer="..tostring(ok and current.farmerDistance or "unavailable"))
            end
            if os.clock()-lastSave>=2 then lastSave=os.clock();save() end
            task.wait(1)
        end
        stop()
    end)
    consoleLine("LIVE Potassium console diagnostics ON | every 15s full status"..
        " | auto-round summaries | F10 prints full report | F11 stops diagnostics"..
        " | TXT backup="..path)
    consoleLine("Monitoring: upgrades, Skip button, needle discovery/pickup,"..
        " Farmer hand-in, and replay/round transitions")
end
