-- BeyyHub Ranch Native-Geometry GUI Pilot v4
-- Standalone experiment. Run in Ranch WITHOUT loading regular BeyyHub.
-- Sends GUI mouse input only: NEVER calls puzzle remotes or edits GUI state.
-- Uses thresholds/geometry found in the 3 native client bytecodes.
-- Captures a clipboard report after every puzzle and on exit.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local player=Players.LocalPlayer
local started=os.clock()
local report={}
local maxSeconds=600
local active=nil
local mouseHeld=false

local function api(name)
    if name=="setclipboard" and type(setclipboard)=="function" then return setclipboard end
    if name=="toclipboard" and type(toclipboard)=="function" then return toclipboard end
    if name=="writefile" and type(writefile)=="function" then return writefile end
    local fn=rawget(_G,name)
    if type(fn)=="function" then return fn end
    if type(getgenv)=="function" then
        local ok,env=pcall(getgenv)
        if ok and type(env)=="table" and type(rawget(env,name))=="function" then
            return rawget(env,name)
        end
    end
    return nil
end
local function log(message)
    local line=string.format("[Ranch GUI Pilot] +%.2fs %s",os.clock()-started,tostring(message))
    report[#report+1]=line
    print(line)
end
local function export(reason)
    local data=table.concat(report,"\n")
    local write=api("writefile")
    if write then
        local ok,err=pcall(write,"beyyhub-ranch-gui-pilot-report.txt",data)
        if not ok then warn("[Ranch GUI Pilot] writefile failed: "..tostring(err)) end
    end
    local copy=api("setclipboard") or api("toclipboard")
    if copy then
        local ok,err=pcall(copy,data)
        if ok then
            print("[Ranch GUI Pilot] Cumulative report copied ("..reason.."). Press Ctrl+V.")
        else
            warn("[Ranch GUI Pilot] Clipboard failed: "..tostring(err))
        end
    end
end
local function guiActive(gui)
    if not gui or not gui.Parent or not gui:IsA("ScreenGui") or not gui.Enabled then return false end
    local panel=gui:FindFirstChild("Panel")
    return panel and panel:IsA("GuiObject") and panel.Visible
end
local function currentPuzzle()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil,nil end
    for _,name in ipairs({"UfoAlignMinigame","UfoWireMinigame","UfoVentMinigame"}) do
        local gui=pg:FindFirstChild(name)
        if guiActive(gui) then return name,gui end
    end
    return nil,nil
end
local function midpoint(g)
    local p,s=g.AbsolutePosition,g.AbsoluteSize
    return Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
end
local function clamp(n,low,high)
    return math.max(low,math.min(high,n))
end
local function move(point)
    VirtualInputManager:SendMouseMoveEvent(math.floor(point.X+0.5),math.floor(point.Y+0.5),game)
end
local function press(point,down)
    VirtualInputManager:SendMouseButtonEvent(math.floor(point.X+0.5),math.floor(point.Y+0.5),
        0,down,game,0)
end
local function release()
    if not mouseHeld then return end
    mouseHeld=false
    local pos=UserInputService:GetMouseLocation()
    pcall(function() press(pos,false) end)
end
local function drag(gui,origin,dest,duration,steps,inset,hold)
    if not guiActive(gui) then return false end
    local offset=Vector2.new(0,inset or 0)
    local first,final=origin+offset,dest+offset
    local began=false
    local ok,err=pcall(function()
        move(first)
        RunService.RenderStepped:Wait()
        if not guiActive(gui) then return end
        press(first,true)
        began=true
        mouseHeld=true
        RunService.RenderStepped:Wait()
        for n=1,steps do
            if not guiActive(gui) then break end
            move(first:Lerp(final,n/steps))
            task.wait(duration/steps)
        end
        if guiActive(gui) then
            move(final)
            task.wait(hold or 0.09)
        end
    end)
    if began then
        pcall(function() press(final,false) end)
        mouseHeld=false
    end
    if not ok then log("Drag input exception: "..tostring(err)) end
    return ok and began
end
local function getInsetY()
    local ok,a=pcall(function() return GuiService:GetGuiInset() end)
    return ok and math.floor(a.Y+0.5) or 0
end
local function waitForClose(gui,timeout)
    local deadline=os.clock()+timeout
    while os.clock()<deadline do
        if not guiActive(gui) then return true end
        task.wait(0.06)
    end
    return not guiActive(gui)
end
local function insidePanel(panel,point,margin)
    local p,s=panel.AbsolutePosition,panel.AbsoluteSize
    margin=margin or 10
    return point.X>=p.X-margin and point.X<=p.X+s.X+margin
        and point.Y>=p.Y-margin and point.Y<=p.Y+s.Y+margin
end
local function solveAlign(gui)
    local panel=gui:FindFirstChild("Panel")
    local track=panel and panel:FindFirstChild("Track")
    local arrow=panel and panel:FindFirstChild("Arrow")
    if not track or not arrow then return false,"Track or Arrow missing" end
    local cy=tonumber(track:GetAttribute("CenterY"))
    if not cy then return false,"CenterY attribute missing" end
    local origin=midpoint(arrow)
    -- Native angleFromScreen: deg(asin(clamp(((pointerY-trackY)/trackHeight-centerY)/radius,-1,1))).
    -- Hence angle=0 is exactly trackY+centerY*trackHeight. X does not enter this formula.
    local y=track.AbsolutePosition.Y+cy*track.AbsoluteSize.Y
    local target=Vector2.new(clamp(origin.X,
        track.AbsolutePosition.X+4,track.AbsolutePosition.X+track.AbsoluteSize.X-4),y)
    local inset=getInsetY()
    log(string.format("ALIGN targetY=%.1f start=(%.1f,%.1f), target=(%.1f,%.1f) inset=%d",
        y,origin.X,origin.Y,target.X,target.Y,inset))
    -- Preserve inset-first targeting, proven successful in v2.
    -- Faster first move, then exact v2 timing if the faster move misses.
    local choices={
        {offset=inset,duration=0.26,steps=15,hold=0.045,window=1.55},
        {offset=inset,duration=0.42,steps=22,hold=0.09,window=1.70},
    }
    if inset==0 then
        choices[2].offset=0
    end
    for attempt,choice in ipairs(choices) do
        if not guiActive(gui) then return true,"GUI already closed" end
        log(string.format("ALIGN attempt=%d duration=%.2f steps=%d insetY=%d",
            attempt,choice.duration,choice.steps,choice.offset))
        local ok=drag(gui,midpoint(arrow),target,
            choice.duration,choice.steps,choice.offset,choice.hold)
        if not ok then return false,"mouse drag could not be sent" end
        if waitForClose(gui,choice.window) then
            return true,"GUI closed following angle-zero attempt "..attempt
        end
        log(string.format("ALIGN still open after attempt %d arrow=(%.1f,%.1f)",
            attempt,midpoint(arrow).X,midpoint(arrow).Y))
    end
    return false,"GUI remains open after calculated zero-angle drag; native AFK remains available"
end
local function wirePairs(panel)
    local left=panel:FindFirstChild("Left")
    local right=panel:FindFirstChild("Right")
    if not left or not right then return nil,"Left/Right wire groups missing" end
    local pairs={}
    for _,wire in ipairs(left:GetChildren()) do
        local color=wire:GetAttribute("Wire")
        local tip=wire:FindFirstChild("Tip")
        if type(color)=="string" and tip and tip:IsA("GuiObject") then
            for _,other in ipairs(right:GetChildren()) do
                if other:GetAttribute("Wire")==color then
                    local rightTip=other:FindFirstChild("Tip")
                    if rightTip and rightTip:IsA("GuiObject") then
                        pairs[#pairs+1]={color=color,start=tip,goal=rightTip}
                        break
                    end
                end
            end
        end
    end
    table.sort(pairs,function(a,b)
        return a.start.AbsolutePosition.Y<b.start.AbsolutePosition.Y
    end)
    if #pairs~=4 then return nil,"Expected four matching wire pairs, got "..#pairs end
    return pairs
end
local function solveWires(gui)
    local panel=gui:FindFirstChild("Panel")
    if not panel then return false,"Panel missing" end
    local pairs,err=wirePairs(panel)
    if not pairs then return false,err end
    local lines=panel:FindFirstChild("Lines")
    if not lines then return false,"Lines container missing" end
    local last=#lines:GetChildren()
    local completionCount=#pairs+1
    local inset=getInsetY()
    local newConnections=0
    log("WIRES initial Lines children="..last..
        " full visual count="..completionCount.." insetY="..inset)
    for _,pair in ipairs(pairs) do
        if not guiActive(gui) then
            return true,"GUI closed after "..newConnections.." new connections"
        end
        if #lines:GetChildren()>=completionCount then
            log("WIRES reached expected 5 lines; avoiding already-connected wire drag")
            break
        end
        local advanced=false
        local attempts={
            {duration=0.23,steps=14,hold=0.045,settle=0.12},
            {duration=0.38,steps=22,hold=0.09,settle=0.20},
        }
        for attempt,params in ipairs(attempts) do
            if not guiActive(gui) then return true,"GUI closed during wire inputs" end
            local from,to=midpoint(pair.start),midpoint(pair.goal)
            log(string.format("WIRE %s attempt=%d start=(%.0f,%.0f) goal=(%.0f,%.0f) inset=%d duration=%.2f",
                pair.color,attempt,from.X,from.Y,to.X,to.Y,inset,params.duration))
            if not drag(gui,from,to,params.duration,params.steps,inset,params.hold) then
                return false,"Wire drag failed for "..pair.color
            end
            task.wait(params.settle)
            local count=#lines:GetChildren()
            if count>last then
                log("WIRE "..pair.color.." new line registered on attempt "..attempt..
                    "; count="..count)
                newConnections+=count-last
                last=count
                advanced=true
                break
            elseif not guiActive(gui) then
                return true,"GUI closed following "..pair.color.." drag"
            else
                log("WIRE "..pair.color.." not yet registered; count="..count)
            end
        end
        if not advanced and #lines:GetChildren()<completionCount then
            return false,"WIRE "..pair.color.." did not register on fast or proven timing; stopped"
        end
    end
    local final=#lines:GetChildren()
    if final>=completionCount then
        log("WIRES all "..#pairs.." connections visually present; waiting for close")
        if waitForClose(gui,1.45) then
            return true,"GUI closed after "..newConnections.." new connections"
        end
        return true,"All visual lines complete; GUI still open, verify progression"
    end
    return false,"Only "..final.."/"..completionCount.." lines present"
end
local function ventCounter(clip)
    local counter=clip:FindFirstChild("Counter")
    return counter and counter:IsA("TextLabel") and counter.Text or "missing"
end
local function ventItems(strands,spent)
    local candidates={}
    for _,strand in ipairs(strands:GetChildren()) do
        -- A successfully yanked strand can stay Visible while it flies off.
        -- Skip it by INSTANCE identity rather than selecting its moving Grab again.
        if strand:IsA("GuiObject") and strand.Visible and not spent[strand] then
            local grab=strand:FindFirstChild("Grab")
            if grab and grab:IsA("GuiObject") and grab.Visible then
                candidates[#candidates+1]={strand=strand,grab=grab}
            end
        end
    end
    table.sort(candidates,function(a,b)
        if a.strand.ZIndex==b.strand.ZIndex then
            return a.strand.Name>b.strand.Name
        end
        return a.strand.ZIndex>b.strand.ZIndex
    end)
    return candidates
end
local function counterNumber(str)
    return tonumber(tostring(str):match("^(%d+)"))
end
local function ventGoal(panel,clip,start)
    -- The game's mouse input is normalized by clip.AbsoluteSize.Y.
    -- Native release requires a >0.2 normalized displacement from home.
    local distance=clip.AbsoluteSize.Y*0.34
    local p,s=panel.AbsolutePosition,panel.AbsoluteSize
    local margin=8
    local options={
        Vector2.new(clamp(start.X+distance,p.X+margin,p.X+s.X-margin),start.Y),
        Vector2.new(clamp(start.X-distance,p.X+margin,p.X+s.X-margin),start.Y),
        Vector2.new(start.X,clamp(start.Y+distance,p.Y+margin,p.Y+s.Y-margin)),
        Vector2.new(start.X,clamp(start.Y-distance,p.Y+margin,p.Y+s.Y-margin))
    }
    local best,bestDistance=options[1],0
    for _,target in ipairs(options) do
        local d=(target-start).Magnitude
        if d>bestDistance then best,bestDistance=target,d end
    end
    return best,bestDistance/ math.max(1,clip.AbsoluteSize.Y)
end
local function solveVent(gui)
    local panel=gui:FindFirstChild("Panel")
    local clip=panel and panel:FindFirstChild("Clip")
    local strands=clip and clip:FindFirstChild("Strands")
    if not clip or not strands then return false,"Vent Clip/Strands missing" end
    local initial=counterNumber(ventCounter(clip))
    if not initial then return false,"Vent counter unreadable" end
    local verifiedFlight={}  -- only if there is visual evidence: moved/hid on counter decrement
    local tries={}           -- rotate fresh first, retry max 3 times
    local inset=getInsetY()
    local progress=0
    local failures=0
    local inferred=0
    local maxAttempts=math.max(36,initial*3)
    local maxVentTime=25
    local ventStart=os.clock()
    local function snapshot()
        local samples={}
        for _,strand in ipairs(strands:GetChildren()) do
            if strand:IsA("GuiObject") then
                local grab=strand:FindFirstChild("Grab")
                if grab and grab:IsA("GuiObject") then
                    samples[strand]={
                        pos=midpoint(grab),visible=strand.Visible,
                        grabVisible=grab.Visible
                    }
                end
            end
        end
        return samples
    end
    log("VENT v4 initial counter="..ventCounter(clip)..
        " | track actual movement, NOT assumed target names")
    for index=1,maxAttempts do
        if not guiActive(gui) then return true,"GUI closed" end
        if os.clock()-ventStart>maxVentTime then
            return false,"Vent input budget elapsed; counter="..ventCounter(clip)..
                " | native AFK will remain available"
        end
        local oldText=ventCounter(clip)
        local beforeCount=counterNumber(oldText)
        if beforeCount and beforeCount<=0 then
            return true,"Vent counter reached zero"
        end
        local candidates=ventItems(strands,verifiedFlight)
        local top,bestTries
        bestTries=math.huge
        local visibleCount,onPanelCount=0,0
        for _,entry in ipairs(candidates) do
            visibleCount+=1
            local pos=midpoint(entry.grab)
            if insidePanel(panel,pos,8) then
                onPanelCount+=1
                local count=tries[entry.strand] or 0
                if count<3 and count<bestTries then
                    top=entry
                    bestTries=count
                    if count==0 then break end
                end
            end
        end
        if not top then
            -- Diagnostic distinguishes no-visible-strands from ones displaced
            -- outside the hit area, and preserves the actual counter value.
            local details={}
            for _,entry in ipairs(candidates) do
                if #details>=10 then break end
                local pos=midpoint(entry.grab)
                details[#details+1]=entry.strand.Name..
                    string.format("@(%.0f,%.0f)",pos.X,pos.Y)..
                    "/tries="..(tries[entry.strand] or 0)
            end
            log("VENT NO TARGET counter="..oldText..
                " unverifiedVisible="..visibleCount..
                " candidates="..table.concat(details,", "))
            return false,"Vent has no eligible on-screen candidate; counter="..
                oldText.." progress="..progress..
                " verifiedMoved="..tostring(inferred)
        end
        local strand=top.strand
        local prior=tries[strand] or 0
        tries[strand]=prior+1
        local source=midpoint(top.grab)
        local target,normalDistance=ventGoal(panel,clip,source)
        local offset=prior==0 and 0 or inset
        local oldSnapshots=snapshot()
        log(string.format("VENT trial=%d target=%s visit=%d normalPull=%.2f from=(%.0f,%.0f) to=(%.0f,%.0f) inset=%d remaining=%d",
            index,strand.Name,prior+1,normalDistance,source.X,source.Y,
            target.X,target.Y,offset,beforeCount or -1))
        if normalDistance<=0.20 then
            log("VENT under-threshold target, not dragging")
            failures+=1
        elseif not drag(gui,source,target,0.32,20,offset) then
            return false,"Vent mouse input failed"
        else
            task.wait(0.12)
            local newText=ventCounter(clip)
            local afterCount=counterNumber(newText)
            if afterCount and beforeCount and afterCount<beforeCount then
                progress+=beforeCount-afterCount
                -- Identify the real pulled strand by which Grab moved,
                -- not by the intended target name. Overlapping strands
                -- can intercept the GUI input.
                local motion={}
                local newSnapshots=snapshot()
                for obj,was in pairs(oldSnapshots) do
                    if not verifiedFlight[obj] then
                        local now=newSnapshots[obj]
                        local delta=now and (now.pos-was.pos).Magnitude or 0
                        local disappeared=was.visible and
                            (not now or not now.visible)
                        if disappeared or delta>85 then
                            verifiedFlight[obj]=true
                            inferred+=1
                            motion[#motion+1]=obj.Name..
                                string.format("(shift=%.0f,hidden=%s)",
                                    delta,tostring(disappeared))
                        end
                    end
                end
                table.sort(motion)
                if #motion==0 then
                    log("VENT PROGRESS "..oldText.." -> "..newText..
                        " but target "..strand.Name..
                        " was not confirmed moving; retain candidate")
                else
                    log("VENT PROGRESS "..oldText.." -> "..newText..
                        " actual moving candidates: "..table.concat(motion,", "))
                end
                log("VENT registered removals="..progress..
                    " | verified visual movements="..inferred)
                task.wait(0.10)
            else
                failures+=1
                local shift=(midpoint(top.grab)-source).Magnitude
                log(string.format("VENT STALLED target=%s counter=%s shift=%.0f (rotate to another)",
                    strand.Name,newText,shift))
                task.wait(0.24)  -- native .18s snapback
                local settled=midpoint(top.grab)
                if not insidePanel(panel,settled,8) then
                    tries[strand]=3
                    log(string.format("VENT OFFSCREEN target=%s after settle=(%.0f,%.0f); skip temporarily",
                        strand.Name,settled.X,settled.Y))
                end
            end
        end
    end
    return false,"Vent attempt budget reached; counter="..
        ventCounter(clip).." registered="..progress..
        " verifiedMovement="..inferred.." stalls="..failures
end
local solvers={
    UfoAlignMinigame=solveAlign,
    UfoWireMinigame=solveWires,
    UfoVentMinigame=solveVent
}
log("STARTED v4. Align/Wires are identical to v3; Vent visual-correlation solver. No remotes.")
log("Do not run regular BeyyHub simultaneously. Keep Roblox focused; minimize Solara's overlay.")
local known=nil
local finishedCount=0
local busy=false
while os.clock()-started<maxSeconds do
    local name,gui=currentPuzzle()
    if gui~=known then
        if known then
            log("CLOSED/CHANGED "..(active and active.name or "unknown")..
                "; previous result="..(active and active.outcome or "not recorded")..
                (busy and " (solver may still be finishing)" or ""))
            export("puzzle closed")
        end
        known=gui
        active=nil
        if gui then
            active={gui=gui,name=name,opened=os.clock(),outcome="not attempted"}
            log("OPENED "..name)
            if busy then
                log("Solver already running; not starting an overlapping attempt")
            else
                busy=true
                local session=active
                task.spawn(function()
                    local fn=solvers[session.name]
                    local ok,good,msg=pcall(fn,session.gui)
                    release()
                    session.outcome=ok and tostring(msg) or ("EXCEPTION: "..tostring(good))
                    log(session.name.." RESULT success="..tostring(ok and good)..
                        " details="..session.outcome..
                        " elapsed="..string.format("%.2f",os.clock()-session.opened).."s")
                    export("solver attempt completed")
                    busy=false
                end)
            end
        end
    end
    task.wait(0.12)
end
release()
log("FINISHED: 10 minute diagnostic window ended.")
export("final")
