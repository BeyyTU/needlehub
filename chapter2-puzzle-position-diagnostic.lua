-- Beyy Chapter 2 Shared-Position and Waypoint Diagnostic v3
-- Automatically test-teleports ONCE to the best scanned position (>=4/5 core).
-- F5 rescan, F6 manually retry teleport, F7 undo, F9 copy/save.
-- Does not send any puzzle or lever remotes; leaves Main unchanged.
-- The TP is diagnostic only: snapback and range acceptance are measured.
local CHAPTER2=83445806734780
if game.PlaceId~=CHAPTER2 then
    warn("[CH2 SPOT] Run after entering Chapter 2; no lobby queue used.")
    return
end
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local env=_G
if type(getgenv)=="function" then
    local ok,e=pcall(getgenv)
    if ok and type(e)=="table" then env=e end
end
if type(env.__BEYY_CH2_SPOT_STOP)=="function" then
    pcall(env.__BEYY_CH2_SPOT_STOP,"restarted")
end

local alive=true
local started=os.clock()
local connections={}
local best=nil
local snapshot=nil
local bestScore=nil
local bestPair=nil
local posterRoute=nil
local scanBusy=false
local automaticMoveAttempted=false
local automaticMoveSucceeded=false
local autoMoveAt=nil
local moveSerial=0
local scanCount=0
local lastStatus="awaiting puzzle-room geometry"
local samples={}
local restoreCF=nil
local restoreCharacter=nil
local travelResults={}
local lastSamplePosition=nil
local lastSampleSolved=-1
local lastSampleFlags=""
local output="BeyyHub/chapter2_puzzle_position_diagnostic.txt"
local LIMIT={Color=7.6,Picture=26.5,Keypad=8.2,Poster=8.3}
local function log(kind,detail)
    local line=string.format("+%.2fs [%s] %s",os.clock()-started,kind,tostring(detail))
    print("[CH2 SPOT] "..line)
    samples[#samples+1]=line
    if #samples>120 then table.remove(samples,1) end
end
local function hook(signal,fn)
    local conn=signal:Connect(fn)
    connections[#connections+1]=conn
    return conn
end
local function getRoot()
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    return char,root,hum
end
local function fetchTargets()
    local world=Workspace:FindFirstChild("Puzzles")
    local pic=world and world:FindFirstChild("PicturePuzzle")
    local picModel=pic and pic:FindFirstChild("PicturePuzzle")
    local board=picModel and picModel:FindFirstChild("BoardPart")
    local colors=world and world:FindFirstChild("ColorPuzzle")
    local pedFolder=colors and colors:FindFirstChild("Folder")
    local number=world and world:FindFirstChild("NumberPuzzle")
    local keypad=number and number:FindFirstChild("Keypad")
    local posters=number and number:FindFirstChild("Posters")
    if not (board and board:IsA("BasePart") and pedFolder
        and keypad and posters) then
        return nil,"Waiting for BoardPart, Color pedestals, Number keypad/posters"
    end
    local pedestals={}
    for i,name in ipairs({"Red","Purple","Green"}) do
        local obj=pedFolder:FindFirstChild("Pedestal"..i)
        if not obj then return nil,"Waiting for "..name.." pedestal" end
        local ok,pos=pcall(function()return obj:GetPivot().Position end)
        if not ok then return nil,"Could not read pedestal pivot" end
        pedestals[#pedestals+1]={label=name,pos=pos}
    end
    local paper={}
    for _,obj in ipairs(posters:GetChildren()) do
        if obj:IsA("BasePart") and type(obj:GetAttribute("PosterIndex"))=="number" then
            paper[#paper+1]={index=obj:GetAttribute("PosterIndex"),pos=obj.Position}
        end
    end
    table.sort(paper,function(a,b)return a.index<b.index end)
    if #paper==0 then return nil,"Waiting for indexed Number posters" end
    local ok,keyPos=pcall(function()return keypad:GetPivot().Position end)
    if not ok then return nil,"Could not read keypad pivot" end
    return {folder=world,board=board.Position,keypad=keyPos,
        colors=pedestals,posters=paper},nil
end
local function evaluate(pos,targets)
    local passed=0
    local overflow,maxOverflow=0,0
    local minimumMargin=math.huge
    local distances={}
    local coreMask=0
    local coreBit=1
    local posterSet={}
    local function add(label,vec,limit)
        local d=(pos-vec).Magnitude
        local excess=math.max(0,d-limit)
        if d<=limit then
            passed+=1
            coreMask+=coreBit
        end
        coreBit*=2
        overflow+=excess
        maxOverflow=math.max(maxOverflow,excess)
        minimumMargin=math.min(minimumMargin,limit-d)
        distances[label]=d
    end
    add("Picture",targets.board,LIMIT.Picture)
    add("Keypad",targets.keypad,LIMIT.Keypad)
    for _,p in ipairs(targets.colors) do
        add("Color "..p.label,p.pos,LIMIT.Color)
    end
    local covered,posterMax,posterDistances=0,0,{}
    for _,p in ipairs(targets.posters) do
        local dist=(pos-p.pos).Magnitude
        posterDistances[#posterDistances+1]={index=p.index,dist=dist}
        if dist<=LIMIT.Poster then
            covered+=1
            posterSet[p.index]=true
        end
        posterMax=math.max(posterMax,dist)
    end
    return {pos=pos,core=passed,coreMask=coreMask,
        posterSet=posterSet,coreOverflow=overflow,
        coreMaxOverflow=maxOverflow,margin=minimumMargin,
        covered=covered,posterTotal=#targets.posters,
        worstPoster=posterMax,dist=distances,posters=posterDistances}
end
local function better(a,b)
    if not b then return true end
    if a.core~=b.core then return a.core>b.core end
    if math.abs(a.coreOverflow-b.coreOverflow)>0.05 then
        return a.coreOverflow<b.coreOverflow
    end
    if a.covered~=b.covered then return a.covered>b.covered end
    if math.abs(a.margin-b.margin)>0.02 then return a.margin>b.margin end
    if math.abs(a.worstPoster-b.worstPoster)>0.02 then
        return a.worstPoster<b.worstPoster
    end
    return false
end
local CORE_NAMES={"Picture","Keypad","Color Red","Color Purple","Color Green"}
local function missingCore(candidate)
    if not candidate then return "unavailable" end
    local missing={}
    for i,name in ipairs(CORE_NAMES) do
        if bit32.band(candidate.coreMask,bit32.lshift(1,i-1))==0 then
            missing[#missing+1]=name..
                string.format(" %.2f studs",candidate.dist[name] or -1)
        end
    end
    return #missing==0 and "none" or table.concat(missing,", ")
end
local function coreCount(mask)
    local n=0
    for i=0,4 do
        if bit32.band(mask,bit32.lshift(1,i))~=0 then n+=1 end
    end
    return n
end
local function scorePair(a,b,targets)
    local union=bit32.bor(a.coreMask,b.coreMask)
    local posters=0
    for _,item in ipairs(targets.posters) do
        if a.posterSet[item.index] or b.posterSet[item.index] then posters+=1 end
    end
    return {a=a,b=b,core=coreCount(union),posters=posters,
        travel=(a.pos-b.pos).Magnitude,
        overlap=a.covered+b.covered-posters}
end
local function betterPair(a,b)
    if not b then return true end
    if a.core~=b.core then return a.core>b.core end
    if a.posters~=b.posters then return a.posters>b.posters end
    if math.abs(a.travel-b.travel)>0.25 then
        return a.travel<b.travel end
    return a.overlap<b.overlap
end
local function routeForPosters(first,second,pool,targets)
    local route={}
    local done={}
    local remaining=#targets.posters
    local function add(candidate)
        if not candidate then return end
        local added=0
        for _,poster in ipairs(targets.posters) do
            if candidate.posterSet[poster.index] and not done[poster.index] then
                done[poster.index]=true
                added+=1
            end
        end
        remaining-=added
        route[#route+1]={pos=candidate.pos,added=added,remaining=remaining,
            core=candidate.core}
    end
    add(first)
    if second and second~=first then add(second) end
    while remaining>0 and #route<10 do
        local winner,coverage=nil,0
        for _,candidate in ipairs(pool) do
            local count=0
            for _,poster in ipairs(targets.posters) do
                if not done[poster.index] and candidate.posterSet[poster.index] then
                    count+=1
                end
            end
            if count>coverage then winner,coverage=candidate,count end
        end
        if not winner then break end
        add(winner)
    end
    return {stops=route,uncovered=remaining,total=#targets.posters}
end
local function floorCandidate(x,z,room,root,hum)
    -- Exclude puzzle components so raycasts hit the supporting room floor,
    -- rather than decorative pedestals, wall posters, or puzzle boards.
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={room.folder,player.Character}
    params.RespectCanCollide=true
    local refY=room.colors[2].pos.Y
    local startY=math.max(refY+13,root.Position.Y+7)
    local hit=Workspace:Raycast(
        Vector3.new(x,startY,z),Vector3.new(0,-65,0),params)
    if not hit then return nil end
    local standY=hit.Position.Y+hum.HipHeight+root.Size.Y*0.5
    -- Reject different-floor levels and roofs. No unverified teleport target.
    if math.abs(standY-refY)>12 then return nil end
    return Vector3.new(x,standY,z)
end
local function rescan()
    if not alive or scanBusy then return end
    scanBusy=true
    local success,reason=pcall(function()
    local char,root,hum=getRoot()
    if not (char and root and hum) then
        lastStatus="Waiting for character/root/humanoid"
        return
    end
    local t,err=fetchTargets()
    if not t then lastStatus=err;return end
    scanCount+=1
    local middle=(t.keypad
        +t.colors[1].pos+t.colors[2].pos+t.colors[3].pos)/4
    local bestFound=nil
    local evaluated=0
    local accepted=0
    local totalPosters=#t.posters
    local candidates={}
    local candidateByMask={}
    local function trackCandidate(ev)
        candidates[#candidates+1]=ev
        local bucket=candidateByMask[ev.coreMask]
        if not bucket then
            bucket={}
            candidateByMask[ev.coreMask]=bucket
        end
        -- Retain both range-correct and poster-rich candidates for two
        -- waypoint planning, not only the best initial anchor.
        bucket[#bucket+1]=ev
        table.sort(bucket,function(a,b)
            if a.covered~=b.covered then return a.covered>b.covered end
            if math.abs(a.coreOverflow-b.coreOverflow)>0.05 then
                return a.coreOverflow<b.coreOverflow
            end
            return a.margin>b.margin
        end)
        if #bucket>6 then table.remove(bucket) end
    end
    -- Sample the central room footprint, then refine local maxima.
    for dx=-25,25,1.5 do
        for dz=-25,25,1.5 do
            local spot=floorCandidate(middle.X+dx,middle.Z+dz,t,root,hum)
            if spot then
                accepted+=1
                local ev=evaluate(spot,t)
                evaluated+=1
                if better(ev,bestFound) then bestFound=ev end
                trackCandidate(ev)
            end
        end
        if not alive then return end
        task.wait() -- keep scan from freezing the main puzzle worker
    end
    if bestFound then
        local coarse=bestFound.pos
        for dx=-1.5,1.5,0.25 do
            for dz=-1.5,1.5,0.25 do
                local spot=floorCandidate(coarse.X+dx,coarse.Z+dz,t,root,hum)
                if spot then
                    local ev=evaluate(spot,t)
                    evaluated+=1
                    if better(ev,bestFound) then bestFound=ev end
                    trackCandidate(ev)
                end
            end
            task.wait()
        end
    end
    -- Keep the original solver's midpoint as a comparison; it searches
    -- loose Color <=13.3 and board <=28, which may force recovery moves.
    local solverMean=(t.keypad+t.colors[2].pos)*0.5
    local solverCount,solverBestMargin=-1,-math.huge
    local solverPoint=nil
    for dx=-7,7,0.5 do
        for dz=-7,7,0.5 do
            local p=Vector3.new(solverMean.X+dx,root.Position.Y,solverMean.Z+dz)
            local keypadD=(p-t.keypad).Magnitude
            local boardD=(p-t.board).Magnitude
            local maxColor=0
            for _,cp in ipairs(t.colors) do
                maxColor=math.max(maxColor,(p-cp.pos).Magnitude)
            end
            if keypadD<=9.2 and boardD<=28 and maxColor<=13.3 then
                local posterCount=0
                for _,paper in ipairs(t.posters) do
                    if (p-paper.pos).Magnitude<9 then posterCount+=1 end
                end
                local margin=math.min(10-keypadD,14-maxColor,30-boardD)
                if posterCount>solverCount
                    or (posterCount==solverCount and margin>solverBestMargin) then
                    solverCount,solverBestMargin,solverPoint=
                        posterCount,margin,p
                end
            end
        end
        task.wait()
    end
    snapshot=t
    best=bestFound
    bestScore=bestFound and evaluate(root.Position,t) or nil
    t.originalSolverPoint=solverPoint
    t.originalScore=solverPoint and evaluate(solverPoint,t) or nil
    t.candidateCount=evaluated
    t.validFloors=accepted
    local fullCandidates=0
    for _,ev in ipairs(candidates) do
        if ev.core==5 and ev.covered==totalPosters then
            fullCandidates+=1
        end
    end
    t.fullCoverCandidates=fullCandidates
    local pairPool={}
    for _,bucket in pairs(candidateByMask) do
        for _,ev in ipairs(bucket) do pairPool[#pairPool+1]=ev end
    end
    local bestTwo=nil
    for i=1,#pairPool do
        local a=pairPool[i]
        for j=i+1,#pairPool do
            local trial=scorePair(a,pairPool[j],t)
            if betterPair(trial,bestTwo) then bestTwo=trial end
        end
    end
    bestPair=bestTwo
    posterRoute=routeForPosters(
        bestTwo and bestTwo.a or bestFound,
        bestTwo and bestTwo.b or nil,
        candidates,t)
    if not bestFound then
        lastStatus="No verified floor positions near the shared puzzle targets"
        log("SCAN",lastStatus)
        return
    end
    local full=bestFound.core==5 and bestFound.covered==totalPosters
    lastStatus=full and "ONE-SPOT FEASIBLE UNDER INFERRED RANGES"
        or (bestFound.core==5 and "all core targets reached at one sampled point; some posters out of range"
        or "NO SAMPLED SINGLE POSITION REACHED ALL FIVE CORE TARGETS")
    log("SCAN",string.format(
        "%s | best=%s | 5 core=%d/5 posters=%d/%d floorCandidates=%d",
        lastStatus,tostring(bestFound.pos),bestFound.core,
        bestFound.covered,totalPosters,evaluated))
    log("MISSING","Best single point out-of-range target(s): "..missingCore(bestFound))
    if bestTwo then
        log("PAIR",string.format(
            "Best sampled two positions: core=%d/5 posters=%d/%d travel=%.2f; A=%s B=%s",
            bestTwo.core,bestTwo.posters,totalPosters,bestTwo.travel,
            tostring(bestTwo.a.pos),tostring(bestTwo.b.pos)))
    end
    if posterRoute then
        log("ROUTE",string.format(
            "Poster coverage plan: %d stops, %d/%d posters covered; not all posters may be required",
            #posterRoute.stops,totalPosters-posterRoute.uncovered,
            totalPosters))
    end
    if t.originalScore then
        log("COMPARE",string.format(
            "Existing solver anchor: core=%d/5 posters=%d/%d; proposed core=%d/5 posters=%d/%d",
            t.originalScore.core,t.originalScore.covered,totalPosters,
            bestFound.core,bestFound.covered,totalPosters))
    end
    end)
    scanBusy=false
    if not success then
        lastStatus="SCAN ERROR: "..tostring(reason)
        log("ERROR",lastStatus)
    end
end

local function report()
    local lines={
        "CHAPTER 2 SHARED POSITION/ROUTE DIAGNOSTIC v3",
        "One automatic best-position diagnostic teleport after scan; F7 undo.",
        "No puzzle or lever remotes sent.",
        "Auto move attempted: "..tostring(automaticMoveAttempted),
        "Auto move sent: "..tostring(automaticMoveSucceeded),
        "Auto move at: "..tostring(autoMoveAt),
        "Interaction radii are inferred from the current solver, NOT verified server rules.",
        "Limit: Color="..LIMIT.Color.." Picture="..LIMIT.Picture..
            " Keypad="..LIMIT.Keypad.." Posters="..LIMIT.Poster,
        "Status: "..lastStatus,
        "Scans: "..scanCount,
    }
    local char,root=getRoot()
    if root then
        lines[#lines+1]="Current root: "..tostring(root.Position)
        lines[#lines+1]="Root anchored: "..tostring(root.Anchored)
    end
    if player then
        for _,name in ipairs({"IntroCutsceneFinished","CutsceneActive",
            "Chapter2ReleaseActive","NeedleInputLocked","NeedleOwned"}) do
            lines[#lines+1]="Player "..name..": "..tostring(player:GetAttribute(name))
        end
    end
    local folder=ReplicatedStorage:FindFirstChild("Puzzles")
    if folder then
        lines[#lines+1]="SolvedPuzzleCount: "..tostring(folder:GetAttribute("SolvedPuzzleCount"))
        lines[#lines+1]="LeverPuzzleSolved: "..tostring(folder:GetAttribute("LeverPuzzleSolved"))
    end
    if snapshot then
        lines[#lines+1]="Verified floor samples: "..tostring(snapshot.validFloors)
        lines[#lines+1]="Evaluated candidates: "..tostring(snapshot.candidateCount)
        lines[#lines+1]="Full-overlap sample count: "..tostring(snapshot.fullCoverCandidates)
        lines[#lines+1]="Board: "..tostring(snapshot.board)
        lines[#lines+1]="Keypad: "..tostring(snapshot.keypad)
        for _,p in ipairs(snapshot.colors) do
            lines[#lines+1]="Pedestal "..p.label..": "..tostring(p.pos)
        end
        for _,p in ipairs(snapshot.posters) do
            lines[#lines+1]="Poster "..p.index..": "..tostring(p.pos)
        end
    end
    local function writeCandidate(label,c)
        if not c then
            lines[#lines+1]=label..": not available"
            return
        end
        lines[#lines+1]=label..": "..tostring(c.pos)
        lines[#lines+1]=string.format(
            "  core %d/5, overflow %.2f, max overflow %.2f, min margin %.2f, posters %d/%d, worst poster %.2f",
            c.core,c.coreOverflow,c.coreMaxOverflow,c.margin,
            c.covered,c.posterTotal,c.worstPoster)
        for _,name in ipairs({"Picture","Keypad",
            "Color Red","Color Purple","Color Green"}) do
            lines[#lines+1]=string.format(
                "  %s distance %.2f (limit %.1f)",
                name,c.dist[name] or -1,
                name=="Picture" and LIMIT.Picture
                or name=="Keypad" and LIMIT.Keypad or LIMIT.Color)
        end
        for _,p in ipairs(c.posters) do
            lines[#lines+1]=string.format(
                "  Poster %s distance %.2f (limit %.1f) %s",
                tostring(p.index),p.dist,LIMIT.Poster,
                p.dist<=LIMIT.Poster and "IN RANGE" or "OUT OF RANGE")
        end
    end
    writeCandidate("OPTIMIZED FLOOR CANDIDATE",best)
    lines[#lines+1]="Best single missing: "..missingCore(best)
    if bestPair then
        lines[#lines+1]=string.format(
            "TWO-POSITION PLAN: core %d/5, union posters %d/%d, travel %.2f studs",
            bestPair.core,bestPair.posters,snapshot and #snapshot.posters or 0,
            bestPair.travel)
        writeCandidate("PAIR A",bestPair.a)
        writeCandidate("PAIR B",bestPair.b)
    end
    if posterRoute then
        lines[#lines+1]="NUMBER POSTER COVERAGE ROUTE (inferred; may not need every poster)"
        for index,stop in ipairs(posterRoute.stops) do
            lines[#lines+1]=string.format(
                "  Stop %d at %s | new posters=%d remaining=%d core=%d/5",
                index,tostring(stop.pos),stop.added,stop.remaining,stop.core)
        end
        lines[#lines+1]="Posters not covered by planned route: "..posterRoute.uncovered
    end
    if snapshot then
        writeCandidate("EXISTING SOLVER SELECTED POINT",snapshot.originalScore)
    end
    writeCandidate("CURRENT CHARACTER POSITION",
        snapshot and root and evaluate(root.Position,snapshot) or bestScore)
    lines[#lines+1]="=== F6 MOVE / SERVER SNAPBACK ==="
    for _,v in ipairs(travelResults) do lines[#lines+1]=v end
    lines[#lines+1]="=== EVENTS ==="
    for _,v in ipairs(samples) do lines[#lines+1]=v end
    return table.concat(lines,"\n")
end
local function save()
    local data=report()
    if type(setclipboard)=="function" then pcall(setclipboard,data) end
    if type(writefile)=="function" then
        if type(makefolder)=="function" then
            pcall(function()
                if type(isfolder)~="function" or not isfolder("BeyyHub") then
                    makefolder("BeyyHub")
                end
            end)
        end
        local ok,err=pcall(writefile,output,data)
        if not ok then warn("[CH2 SPOT] Report write failed: "..tostring(err)) end
    end
    log("REPORT","F9 copied/saved "..tostring(#data).." bytes")
end
local function moveBest(source)
    source=source or "F6"
    -- Use the best floor-supported 4/5 (or better) spot for a bounded test.
    -- It is not guaranteed that every puzzle is server-reachable there.
    if not best or not snapshot or best.core<4 then
        log("MOVE",source.." rejected: no floor-supported point meeting 4/5 core targets")
        return false
    end
    if player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true then
        log("MOVE",source.." rejected: protected ending")
        return false
    end
    local char,root=getRoot()
    if not root or root.Anchored then
        log("MOVE",source.." rejected: root absent/anchored")
        return false
    end
    restoreCF=root.CFrame
    restoreCharacter=char
    local goal=best.pos
    local prior=(root.Position-goal).Magnitude
    moveSerial+=1
    local serial=moveSerial
    local ok,err=pcall(function()
        root.CFrame=CFrame.new(goal)*root.CFrame.Rotation
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end)
    if not ok then
        log("ERROR",source.." teleport write failed: "..tostring(err))
        return false
    end
    if source=="AUTO" then
        automaticMoveSucceeded=true
        autoMoveAt=os.clock()-started
    end
    log("MOVE",source.." teleport to "..tostring(goal)..
        string.format(" (from %.2f studs; %d/5 core; missing %s)",
            prior,best.core,missingCore(best))..
        "; F7 restores; no puzzle actions")
    task.spawn(function()
        local moveAt=os.clock()
        for _,elapsed in ipairs({0.15,0.50,1.0,2.0}) do
            task.wait(math.max(0,moveAt+elapsed-os.clock()))
            if not alive or serial~=moveSerial
                or player.Character~=char or not root.Parent then break end
            local d=(root.Position-goal).Magnitude
            local entry=string.format("%s after %.2fs: offset %.3f studs, anchored=%s",
                source,elapsed,d,tostring(root.Anchored))
            travelResults[#travelResults+1]=entry
            log("SNAPBACK",entry)
        end
    end)
    return true
end
local function undo()
    local _,root=getRoot()
    if not restoreCF or player.Character~=restoreCharacter or not root
        or player:GetAttribute("NeedleRoundComplete")==true then
        log("RESTORE","No safe F6 teleport to undo")
        return
    end
    moveSerial+=1 -- stop reporting snapback against a deliberately undone TP
    root.CFrame=restoreCF
    root.AssemblyLinearVelocity=Vector3.zero
    restoreCF,restoreCharacter=nil,nil
    log("RESTORE","F7 returned to pre-diagnostic position")
end
local function stop(reason)
    if not alive then return end
    alive=false
    for _,conn in ipairs(connections) do
        pcall(function()conn:Disconnect()end)
    end
    table.clear(connections)
    log("STOP",reason or "manual")
    if env.__BEYY_CH2_SPOT_STOP==stop then env.__BEYY_CH2_SPOT_STOP=nil end
end
env.__BEYY_CH2_SPOT_STOP=stop
env.__BEYY_CH2_SPOT_REPORT=report
hook(UserInputService.InputBegan,function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.F5 then
        task.spawn(rescan)
    elseif input.KeyCode==Enum.KeyCode.F6 then
        task.spawn(moveBest)
    elseif input.KeyCode==Enum.KeyCode.F7 then
        task.spawn(undo)
    elseif input.KeyCode==Enum.KeyCode.F9 then
        save()
    end
end)
log("READY","v3: AUTO teleport once after first scan; F5 rescan; F6 retry; F7 undo; F9 report.")
task.spawn(function()
    local attempts=0
    while alive and not best and attempts<65 do
        attempts+=1
        rescan()
        if best then break end
        task.wait(1)
    end
    if not best then
        log("WAIT","Targets/floor not resolved; use F5 to rescan after room loads")
        return
    end
    -- Teleport once after a successful scan, as requested. Wait for a
    -- non-anchored avatar instead of force-unanchoring an active cinematic.
    -- Do not auto-repeat if the server snaps the player back: record it.
    automaticMoveAttempted=true
    if best.core<4 then
        log("AUTO","No verified 4/5 floor position; not teleporting. F9 includes missing ranges.")
        return
    end
    local deadline=os.clock()+30
    while alive and os.clock()<deadline do
        local _,root=getRoot()
        if root and not root.Anchored
            and player:GetAttribute("NeedleOwned")~=true
            and player:GetAttribute("NeedleRoundComplete")~=true then
            if moveBest("AUTO") then return end
        end
        task.wait(0.20)
    end
    if alive then
        log("AUTO","No safe unanchored avatar before 30s deadline; press F6 to retry.")
    end
end)
task.spawn(function()
    while alive do
        task.wait(0.28)
        local _,root=getRoot()
        local folder=ReplicatedStorage:FindFirstChild("Puzzles")
        local solved=folder and tonumber(folder:GetAttribute("SolvedPuzzleCount")) or -1
        local flags=tostring(player:GetAttribute("CutsceneActive")).."/"..
            tostring(player:GetAttribute("Chapter2ReleaseActive")).."/"..
            tostring(player:GetAttribute("NeedleInputLocked"))
        if root and (not lastSamplePosition or
            (root.Position-lastSamplePosition).Magnitude>4
            or lastSampleSolved~=solved or lastSampleFlags~=flags) then
            local score=snapshot and evaluate(root.Position,snapshot)
            log("TRACE",string.format(
                "root=%s core=%s posters=%s solved=%s cutscene/release/lock=%s",
                tostring(root.Position),
                score and score.core.."/5" or "?",
                score and score.covered.."/"..score.posterTotal or "?",
                tostring(solved),flags))
            lastSamplePosition=root.Position
            lastSampleSolved=solved
            lastSampleFlags=flags
        end
    end
end)
