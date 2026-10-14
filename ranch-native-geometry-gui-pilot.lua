-- BeyyHub Ranch Native-Geometry GUI Pilot v2
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
local function drag(gui,origin,dest,duration,steps,inset)
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
            task.wait(0.09)
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
    -- In the prior live test inset=0 missed, while inset=58 closed the GUI.
    -- Try the actual Roblox GUI inset FIRST. Use zero only as fallback.
    local offsets=inset~=0 and {inset,0} or {0}
    for attempt,adjust in ipairs(offsets) do
        if not guiActive(gui) then return true,"GUI already closed" end
        log("ALIGN drag attempt "..attempt.." (insetY="..adjust..")")
        local ok=drag(gui,midpoint(arrow),target,0.42,22,adjust)
        if not ok then return false,"mouse drag could not be sent" end
        task.wait(1.6)
        if not guiActive(gui) then
            return true,"GUI closed promptly after zero-angle drag (insetY="..adjust..")"
        end
        log(string.format("ALIGN after attempt %d arrow=(%.1f,%.1f)",
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
    -- Native baseline has one non-connection line; four connections bring
    -- Lines children to five. The previous test began with TWO children.
    local completionCount=#pairs+1
    local inset=getInsetY()
    local offsets=inset~=0 and {inset,0} or {0}
    local newConnections=0
    log("WIRES initial Lines children="..last..
        " expected full visual count="..completionCount..
        " insetY="..inset)
    for _,pair in ipairs(pairs) do
        if not guiActive(gui) then
            return true,"GUI closed after "..newConnections.." new connections"
        end
        if #lines:GetChildren()>=completionCount then
            log("WIRES reached expected 5 line objects; no more drags required")
            break
        end
        local advanced=false
        for attempt,offset in ipairs(offsets) do
            if not guiActive(gui) then
                return true,"GUI closed during wire inputs"
            end
            local from,to=midpoint(pair.start),midpoint(pair.goal)
            -- Use destination tip CENTER, not an extended point.
            -- First try with inset because the previous inset=0 attempts missed.
            log(string.format("WIRE %s attempt=%d start=(%.0f,%.0f) goal=(%.0f,%.0f) inset=%d",
                pair.color,attempt,from.X,from.Y,to.X,to.Y,offset))
            if not drag(gui,from,to,0.38,22,offset) then
                return false,"Wire drag failed for "..pair.color
            end
            task.wait(0.20)
            local count=#lines:GetChildren()
            if count>last then
                log("WIRE "..pair.color.." new line registered; count="..count)
                newConnections+=count-last
                last=count
                advanced=true
                break
            elseif not guiActive(gui) then
                return true,"GUI closed following "..pair.color.." drag"
            else
                log("WIRE "..pair.color.." no new line; count="..count)
            end
        end
        if not advanced and #lines:GetChildren()<completionCount then
            return false,"Wire "..pair.color..
                " did not register; "..#lines:GetChildren()..
                "/"..completionCount.." visual lines; stopped"
        end
    end
    local final=#lines:GetChildren()
    if final>=completionCount then
        log("WIRES all connection slots appear filled ("..final..
            " lines including native extra); waiting for native close animation")
        task.wait(1.25)
        if not guiActive(gui) then
            return true,"GUI closed after "..newConnections..
                " new connections; already-connected pair(s) skipped"
        end
        return true,"Visual line count complete ("..final..
            "); GUI still open, confirm actual game progression"
    end
    return false,"Only "..final.."/"..completionCount.." line objects"
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
    local spent={}
    local inset=getInsetY()
    local progress=0
    log("VENT initial counter="..ventCounter(clip)..
        " (track pulled strand identities to avoid flying pieces)")
    for index=1,initial do
        if not guiActive(gui) then return true,"GUI closed" end
        local currentText=ventCounter(clip)
        local before=counterNumber(currentText)
        if before and before<=0 then
            return true,"Vent counter reached zero; awaiting native completion"
        end
        local items=ventItems(strands,spent)
        if #items==0 then
            return false,"No unpulled visible strands remain; counter="..currentText
        end
        local top=items[1]
        local succeeded=false
        for attempt=1,3 do
            if not guiActive(gui) then return true,"GUI closed" end
            -- The native source considers motion relative to the original
            -- Grab hitbox; start from Grab's current center for each attempt.
            local source=midpoint(top.grab)
            local target,normalDistance=ventGoal(panel,clip,source)
            local offset=attempt==3 and inset or 0
            if attempt==3 and inset==0 then break end
            log(string.format("VENT pull=%d %s attempt=%d normalPull=%.2f start=(%.0f,%.0f) to=(%.0f,%.0f) inset=%d",
                index,top.strand.Name,attempt,normalDistance,source.X,source.Y,
                target.X,target.Y,offset))
            if not drag(gui,source,target,0.32,20,offset) then
                return false,"Vent mouse drag could not be sent"
            end
            task.wait(0.16)
            local afterText=ventCounter(clip)
            local after=counterNumber(afterText)
            if after and before and after<before then
                -- CRITICAL: the removed visual may remain visible during
                -- flight; NEVER re-target this same strand.
                spent[top.strand]=true
                progress+=before-after
                log("VENT confirmed "..top.strand.Name..
                    " consumed; counter "..currentText.." -> "..afterText..
                    "; unique removed="..progress)
                succeeded=true
                task.wait(0.12)
                break
            else
                log("VENT no counter change: "..afterText..
                    " | selected strand="..top.strand.Name)
                -- Only retry within controlled bounds; don't chase the
                -- moving strand from the old version of this diagnostic.
                task.wait(0.12)
            end
        end
        if not succeeded then
            local nextNames={}
            for i,item in ipairs(ventItems(strands,spent)) do
                if i>4 then break end
                nextNames[#nextNames+1]=item.strand.Name
            end
            log("VENT available candidates: "..table.concat(nextNames,", "))
            return false,"Vent unchanged after three attempts for "..top.strand.Name..
                "; stopped; unique removed="..progress
        end
    end
    return true,"Vent pass registered "..progress..
        " unique removals; final counter="..ventCounter(clip)
end
local solvers={
    UfoAlignMinigame=solveAlign,
    UfoWireMinigame=solveWires,
    UfoVentMinigame=solveVent
}
log("STARTED v2. Inset-first wires/alignment; exclude yanked Vent strands. No remotes.")
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
