-- BeyyHub Ranch / Vent short-pull teleport diagnostic v1.
-- Standalone, VENT ONLY. Does not touch Align/Wires or the production hub.
-- A single move event teleports the cursor while the left mouse button is held.
-- Fallbacks: longer teleport, then the previously verified 0.34 classic drag.
-- DOES NOT fire game remotes, directly modify puzzle UI or call native closures.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer

local launched=os.clock()
local report={}
local mouseHeld=false
local maxRuntime=600

local function api(name)
    if name=="setclipboard" and type(setclipboard)=="function" then return setclipboard end
    if name=="toclipboard" and type(toclipboard)=="function" then return toclipboard end
    if name=="writefile" and type(writefile)=="function" then return writefile end
    local f=rawget(_G,name)
    if type(f)=="function" then return f end
    if type(getgenv)=="function" then
        local ok,env=pcall(getgenv)
        if ok and type(env)=="table" and type(rawget(env,name))=="function" then
            return rawget(env,name)
        end
    end
end
local function log(message)
    local text=string.format("[Ranch Vent Teleport] +%.2fs %s",os.clock()-launched,tostring(message))
    report[#report+1]=text
    print(text)
end
local function export(reason)
    local payload=table.concat(report,"\n")
    local write=api("writefile")
    if write then
        local ok,err=pcall(write,"beyyhub-ranch-vent-teleport-report.txt",payload)
        if not ok then warn("[Ranch Vent Teleport] Save error: "..tostring(err)) end
    end
    local copy=api("setclipboard") or api("toclipboard")
    if copy then
        local ok,err=pcall(copy,payload)
        if ok then
            print("[Ranch Vent Teleport] Full report copied ("..reason.."). Paste into ChatGPT.")
        else
            warn("[Ranch Vent Teleport] Copy error: "..tostring(err))
        end
    end
end
local function active(gui)
    if not gui or not gui.Parent or not gui:IsA("ScreenGui") or not gui.Enabled then return false end
    local panel=gui:FindFirstChild("Panel")
    return panel and panel:IsA("GuiObject") and panel.Visible
end
local function currentVent()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local gui=pg and pg:FindFirstChild("UfoVentMinigame")
    return active(gui) and gui or nil
end
local function center(gui)
    local p,s=gui.AbsolutePosition,gui.AbsoluteSize
    return Vector2.new(p.X+s.X*0.5,p.Y+s.Y*0.5)
end
local function numberCounter(clip)
    local counter=clip:FindFirstChild("Counter")
    local t=counter and counter.Text or "missing"
    return tonumber(t:match("^(%d+)")),t
end
local function clamp(n,a,b)
    return math.max(a,math.min(b,n))
end
local function inPanel(panel,p)
    local a,s=panel.AbsolutePosition,panel.AbsoluteSize
    return p.X>=a.X-8 and p.X<=a.X+s.X+8
        and p.Y>=a.Y-8 and p.Y<=a.Y+s.Y+8
end
local function mouseMove(p)
    VirtualInputManager:SendMouseMoveEvent(math.floor(p.X+0.5),math.floor(p.Y+0.5),game)
end
local function mouseButton(p,down)
    VirtualInputManager:SendMouseButtonEvent(
        math.floor(p.X+0.5),math.floor(p.Y+0.5),0,down,game,0)
end
local function emergencyRelease()
    if not mouseHeld then return end
    mouseHeld=false
    local p=UserInputService:GetMouseLocation()
    pcall(function()mouseButton(p,false)end)
end
local function insetY()
    local ok,pos=pcall(function()return GuiService:GetGuiInset()end)
    return ok and pos.Y or 0
end

-- User-requested gesture: mouse down at Grab; immediately jump to destination;
-- allow one RenderStepped for InputChanged/RenderStep; release at destination.
-- "Teleport" means ONE VirtualInputManager mouse-move event, not cursor memory hacking.
local function teleportPull(gui,from,to,inset)
    if not active(gui) then return false,"GUI inactive" end
    local offset=Vector2.new(0,inset or 0)
    local first,last=from+offset,to+offset
    local began=false
    local ok,err=pcall(function()
        mouseMove(first)
        RunService.RenderStepped:Wait()
        if not active(gui) then return end
        mouseButton(first,true)
        began=true
        mouseHeld=true
        RunService.RenderStepped:Wait() -- native InputBegan must see held state
        if active(gui) then
            mouseMove(last)             -- direct jump; NO intermediary movement
            RunService.RenderStepped:Wait()
        end
    end)
    if began then
        pcall(function()mouseButton(last,false)end)
        mouseHeld=false
    end
    if not ok then return false,tostring(err) end
    return began,nil
end

-- Proven v4 fallback; intentionally left at the established 0.32s/20-step input.
local function classicPull(gui,from,to,inset)
    if not active(gui) then return false,"GUI inactive" end
    local offset=Vector2.new(0,inset or 0)
    local first,last=from+offset,to+offset
    local began=false
    local ok,err=pcall(function()
        mouseMove(first)
        RunService.RenderStepped:Wait()
        if not active(gui) then return end
        mouseButton(first,true)
        began=true
        mouseHeld=true
        RunService.RenderStepped:Wait()
        for step=1,20 do
            if not active(gui) then break end
            mouseMove(first:Lerp(last,step/20))
            task.wait(0.32/20)
        end
        if active(gui) then
            mouseMove(last)
            task.wait(0.09)
        end
    end)
    if began then
        pcall(function()mouseButton(last,false)end)
        mouseHeld=false
    end
    if not ok then return false,tostring(err) end
    return began,nil
end

-- The native removal threshold is reported as >0.20 clip heights, so
-- half the old .34 would be below it. Probe .25, then .29, then proven .34.
local function destination(panel,clip,from,fraction)
    local d=clip.AbsoluteSize.Y*fraction
    local p,s=panel.AbsolutePosition,panel.AbsoluteSize
    local margin=8
    local options={
        Vector2.new(clamp(from.X+d,p.X+margin,p.X+s.X-margin),from.Y),
        Vector2.new(clamp(from.X-d,p.X+margin,p.X+s.X-margin),from.Y),
        Vector2.new(from.X,clamp(from.Y+d,p.Y+margin,p.Y+s.Y-margin)),
        Vector2.new(from.X,clamp(from.Y-d,p.Y+margin,p.Y+s.Y-margin)),
    }
    local best,dist=options[1],-1
    for _,pt in ipairs(options) do
        local n=(pt-from).Magnitude
        if n>dist then best,dist=pt,n end
    end
    return best,dist/math.max(clip.AbsoluteSize.Y,1)
end
local function samples(strands)
    local out={}
    for _,obj in ipairs(strands:GetChildren()) do
        if obj:IsA("GuiObject") then
            local grab=obj:FindFirstChild("Grab")
            if grab and grab:IsA("GuiObject") then
                out[obj]={pos=center(grab),visible=obj.Visible,
                    grabVisible=grab.Visible,hitPos=grab.AbsolutePosition,
                    hitSize=grab.AbsoluteSize,z=grab.ZIndex}
            end
        end
    end
    return out
end
local function candidates(strands,consumed)
    local out={}
    for obj,info in pairs(samples(strands)) do
        if info.visible and info.grabVisible and not consumed[obj] then
            local grab=obj:FindFirstChild("Grab")
            if grab then out[#out+1]={strand=obj,grab=grab} end
        end
    end
    table.sort(out,function(a,b)
        if a.strand.ZIndex==b.strand.ZIndex then
            return a.strand.Name>b.strand.Name
        end
        return a.strand.ZIndex>b.strand.ZIndex
    end)
    return out
end
local profiles={
    {label="SHORT-JUMP",fraction=0.25,mode="teleport",inset=false},
    {label="MID-JUMP",fraction=0.29,mode="teleport",inset=true},
    {label="PROVEN-DRAG",fraction=0.34,mode="classic",inset=true},
}
local function solveVent(gui)
    local panel=gui:FindFirstChild("Panel")
    local clip=panel and panel:FindFirstChild("Clip")
    local strands=clip and clip:FindFirstChild("Strands")
    if not clip or not strands then return false,"Clip/Strands missing" end
    local initial,t=numberCounter(clip)
    if not initial then return false,"Counter unreadable" end
    local pulled={}
    local visits={}
    local inset=insetY()
    local start=os.clock()
    local progress,stalls,overlaps,redirects=0,0,0,0
    local profileStats={}
    for i,v in ipairs(profiles) do profileStats[i]={count=0,success=0,time=0} end
    local function metrics(reason)
        local v={}
        for i,p in ipairs(profiles) do
            local stat=profileStats[i]
            v[#v+1]=string.format("%s=%d/%d avgInput=%.3fs",
                p.label,stat.success,stat.count,
                stat.count>0 and stat.time/stat.count or 0)
        end
        log("VENT TOTAL "..reason..
            " removed="..progress.."/"..initial..
            " stalls="..stalls..
            " overlaps="..overlaps..
            " redirected="..redirects..
            " counter="..select(2,numberCounter(clip))..
            " | "..table.concat(v," | "))
    end
    log("VENT OPEN counter="..t.." insetY="..inset..
        " | short 0.25 jump, mid 0.29 jump, classic 0.34 fallback")
    for trial=1,math.max(initial*3,45) do
        if not active(gui) then metrics("GUI CLOSED");return true,"GUI closed" end
        if os.clock()-start>=27 then
            metrics("TIMEOUT")
            return false,"27s safety budget ended; normal AFK solver available"
        end
        local before,beforeText=numberCounter(clip)
        if before and before<=0 then
            metrics("ZERO COUNTER")
            return true,"All "..initial.." strands removed"
        end
        local list=candidates(strands,pulled)
        local chosen,minAttempts=nil,math.huge
        for _,item in ipairs(list) do
            local pt=center(item.grab)
            local n=visits[item.strand] or 0
            if inPanel(panel,pt) and n<#profiles and n<minAttempts then
                chosen,minAttempts=item,n
                if n==0 then break end
            end
        end
        if not chosen then
            metrics("NO ELIGIBLE STRAND")
            local details={}
            for _,item in ipairs(list) do
                if #details==8 then break end
                local p=center(item.grab)
                details[#details+1]=string.format("%s@(%.0f,%.0f)/%d",
                    item.strand.Name,p.X,p.Y,visits[item.strand] or 0)
            end
            log("VENT REMAINING candidates="..table.concat(details,","))
            return false,"No eligible remaining Grab, counter="..tostring(beforeText)
        end
        local strand=chosen.strand
        local n=(visits[strand] or 0)+1
        visits[strand]=n
        local config=profiles[n]
        local startPos=center(chosen.grab)
        local goal,realFraction=destination(panel,clip,startPos,config.fraction)
        local beforeSamples=samples(strands)
        local hits={}
        for obj,info in pairs(beforeSamples) do
            if info.visible and info.grabVisible and
                startPos.X>=info.hitPos.X and startPos.X<=info.hitPos.X+info.hitSize.X and
                startPos.Y>=info.hitPos.Y and startPos.Y<=info.hitPos.Y+info.hitSize.Y then
                hits[#hits+1]=obj.Name
            end
        end
        table.sort(hits)
        if #hits>1 then overlaps+=1 end
        local appliedInset=config.inset and inset or 0
        log(string.format("VENT TRIAL %d target=%s mode=%s visit=%d effectivePull=%.3f oldCounter=%s inset=%d overlap=%d [%s]",
            trial,strand.Name,config.label,n,realFraction,beforeText,appliedInset,
            #hits,table.concat(hits,",")))
        if realFraction<=0.205 then
            visits[strand]=#profiles
            log("VENT SKIP: normalized pull too short at this screen position")
        else
            local dragStart=os.clock()
            local ok,err
            if config.mode=="teleport" then
                ok,err=teleportPull(gui,startPos,goal,appliedInset)
            else
                ok,err=classicPull(gui,startPos,goal,appliedInset)
            end
            local inputTime=os.clock()-dragStart
            local stats=profileStats[n]
            stats.count+=1
            stats.time+=inputTime
            if not ok then
                metrics("INPUT ERROR")
                return false,"Input error: "..tostring(err)
            end
            local releaseAt=os.clock()
            local after,afterText=numberCounter(clip)
            local deadline=releaseAt+0.22
            while active(gui) and (not after or not before or after>=before)
                and os.clock()<deadline do
                task.wait(0.015)
                after,afterText=numberCounter(clip)
            end
            local waitTime=os.clock()-releaseAt
            if after and before and after<before then
                local delta=before-after
                progress+=delta
                stats.success+=1
                local moved={}
                local current=samples(strands)
                for obj,old in pairs(beforeSamples) do
                    if not pulled[obj] then
                        local now=current[obj]
                        local pixels=now and (now.pos-old.pos).Magnitude or 0
                        local vanished=old.visible and (not now or not now.visible)
                        if pixels>85 or vanished then
                            pulled[obj]=true
                            moved[#moved+1]=obj.Name.."("..math.floor(pixels).."px)"
                        end
                    end
                end
                table.sort(moved)
                if #moved>0 and not pulled[strand] then redirects+=1 end
                log(string.format("VENT PICKED %s counter=%s -> %s actual=[%s] input=%.3fs counterWait=%.3fs total=%d/%d",
                    config.label,beforeText,afterText,table.concat(moved,","),
                    inputTime,waitTime,progress,initial))
                task.wait(0.025)
            else
                stalls+=1
                log(string.format("VENT MISS %s target=%s input=%.3fs wait=%.3fs counter=%s; rotate candidates",
                    config.label,strand.Name,inputTime,waitTime,afterText))
                task.wait(0.21) -- permit native strand snapback animation
                if not inPanel(panel,center(chosen.grab)) then
                    visits[strand]=#profiles
                    log("VENT EXCLUDED OFFSCREEN "..strand.Name)
                end
            end
        end
    end
    metrics("ATTEMPTS EXHAUSTED")
    return false,"Bounded attempt budget exhausted"
end

log("STARTED. VENT ONLY. Wires and Alignment pilots remain untouched.")
log("Press-and-hold, one cursor jump, release; short pull before proven drag fallback.")
log("Do NOT run the main BeyyHub script or previous GUI pilots at the same time.")
local last=nil
local busy=false
while os.clock()-launched<maxRuntime do
    local gui=currentVent()
    if gui~=last then
        if last then
            log("VENT UI CLOSED/CHANGED")
            export("puzzle closed")
        end
        last=gui
        if gui then
            log("VENT UI OPEN")
            if not busy then
                busy=true
                task.spawn(function()
                    local opened=os.clock()
                    local ok,complete,details=pcall(solveVent,gui)
                    emergencyRelease()
                    if ok then
                        log("VENT RESULT success="..tostring(complete)..
                            " details="..tostring(details)..
                            " elapsed="..string.format("%.2f",os.clock()-opened).."s")
                    else
                        log("VENT EXCEPTION "..tostring(complete))
                    end
                    export("solve attempted")
                    busy=false
                end)
            end
        end
    end
    task.wait(0.11)
end
emergencyRelease()
log("FINISHED 10-minute test window")
export("final")
