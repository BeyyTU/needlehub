-- Beyy Chapter 2 Teleport-Hold and Return Diagnostic v6
-- Combined test follows the puzzle worker's proven room anchor instead of
-- forcing the diagnostic's weaker 4/5 candidate. Standalone F6 remains manual.
-- Maintains room position for <=30s and returns to captured Chapter2 start
-- only after server-replicated SolvedPuzzleCount >=3, then stops corrections.
-- F5 rescan, F6 manual diagnostic TP, F7 restore, F9 report, F12 release.
-- Does not send puzzle/lever remotes. Main and solver files remain unchanged.
-- WARNING: the server may continue seeing a different position; only server
-- puzzle acknowledgements can prove this approach actually works.
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
local PathfindingService=game:GetService("PathfindingService")
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
local holdSerial=0
local holdActive=false
local holdGoal=nil
local holdStarted=0
local holdEnded=0
local holdDuration=30
local holdApplied=0
local holdCorrections=0
local holdAdoptions=0
local holdPhaseChanges=0
local holdLastCorrectionAt=-math.huge
local holdLastObservedSolved=nil
local holdResult="not attempted"
local holdEvents={}
local followSolver=env.__BEYY_CH2_HOLD_FOLLOW_SOLVER==true
local originCF=nil
local originCharacter=nil
local originSource="not captured"
local returnedHome=false
local homeReturnAttempts=0
local homeReturnResult="not requested"
local homeReturnDistance=nil
local navigationSerial=0
local navigationActive=false
local navigationReports={}
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
local function captureOriginal()
    if originCF then return true end
    local char,root=getRoot()
    local recorded=env.__BEYY_CH2_HOLD_CAPTURE
    if type(recorded)=="table" and typeof(recorded.CFrame)=="CFrame"
        and recorded.Character==char then
        originCF=recorded.CFrame
        originCharacter=char
        originSource="combined bootstrap (before cutscene/puzzle/hold)"
    elseif char and root then
        originCF=root.CFrame
        originCharacter=char
        originSource="diagnostic start (before automatic test)"
    end
    if originCF then
        log("ORIGIN","Saved original Chapter2 start="..tostring(originCF.Position)..
            " source="..originSource)
        return true
    end
    return false
end
captureOriginal()
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
        "CHAPTER 2 TELEPORT HOLD / RETURN DIAGNOSTIC v6",
        "In combined mode, follow existing puzzle worker's server-tested room anchor.",
        "Return to recorded start on 3/3 replicated puzzles, then release.",
        "F12 stops hold without forced return; F7 manual return.",
        "Following puzzle worker: "..tostring(followSolver),
        "Origin source: "..originSource,
        "Original position: "..tostring(originCF and originCF.Position),
        "Return requested: "..tostring(returnedHome),
        "Return attempt count: "..tostring(homeReturnAttempts),
        "Return outcome: "..homeReturnResult,
        "Return distance: "..tostring(homeReturnDistance),
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
    lines[#lines+1]="=== POSITION HOLD / RELEASE ==="
    lines[#lines+1]="Hold active: "..tostring(holdActive)
    lines[#lines+1]="Hold goal: "..tostring(holdGoal)
    lines[#lines+1]="Hold duration cap: "..tostring(holdDuration).."s"
    lines[#lines+1]="Hold elapsed: "..string.format("%.2f",holdActive and os.clock()-holdStarted or holdEnded)
    lines[#lines+1]="Position reapplications: "..tostring(holdApplied)
    lines[#lines+1]="Large corrections (>25 studs): "..tostring(holdCorrections)
    lines[#lines+1]="Intentional in-room move adoptions: "..tostring(holdAdoptions)
    lines[#lines+1]="Keypad phase changes: "..tostring(holdPhaseChanges)
    lines[#lines+1]="Last replicated puzzle count: "..tostring(holdLastObservedSolved)
    lines[#lines+1]="Hold result: "..holdResult
    for _,v in ipairs(holdEvents) do lines[#lines+1]=v end
    lines[#lines+1]="=== MOVE / SERVER SNAPBACK ==="
    for _,v in ipairs(travelResults) do lines[#lines+1]=v end
    lines[#lines+1]="=== OPTIONAL F10/F11 WALK NAVIGATION ==="
    lines[#lines+1]="Navigation active: "..tostring(navigationActive)
    for _,v in ipairs(navigationReports) do lines[#lines+1]=v end
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
local function holdLog(message)
    log("HOLD",message)
    holdEvents[#holdEvents+1]=string.format("+%.2fs %s",os.clock()-started,message)
    if #holdEvents>45 then table.remove(holdEvents,1) end
end
local function releaseHold(reason)
    if not holdActive then return end
    holdActive=false
    holdSerial+=1
    holdEnded=os.clock()-holdStarted
    holdResult=tostring(reason)
    holdLog(string.format(
        "RELEASE after %.2fs: %s | reapplies=%d, large corrections=%d, in-room moves=%d, phase changes=%d, puzzles=%s. Return only on 3/3 confirmed.",
        holdEnded,holdResult,holdApplied,holdCorrections,holdAdoptions,
        holdPhaseChanges,tostring(holdLastObservedSolved)))
    -- Do not teleport on release. Measure whether the server returns us
    -- toward the previous hay/spawn position on its own.
    local _,root=getRoot()
    local originalGoal=holdGoal
    task.spawn(function()
        for _,duration in ipairs({0.5,1.2}) do
            task.wait(duration)
            if not alive or not root or not root.Parent then return end
            holdLog(string.format("Post-release %.1fs: position=%s offsetFromGoal=%.2f",
                duration,tostring(root.Position),
                originalGoal and (root.Position-originalGoal).Magnitude or -1))
        end
    end)
end
local function returnToOrigin(reason)
    if returnedHome then return end
    if not originCF or not originCharacter then
        homeReturnResult="No original Chapter2 position was captured"
        holdLog("RETURN failed: "..homeReturnResult)
        return
    end
    local char,root=getRoot()
    if char~=originCharacter or not root
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("NeedleOwned")==true then
        homeReturnResult="Character changed or final/needle state protected"
        holdLog("RETURN skipped: "..homeReturnResult)
        return
    end
    returnedHome=true
    homeReturnResult="return requested after "..tostring(reason)
    local goal=originCF
    holdLog("RETURN: sending character back to original hay/start "..
        tostring(goal.Position).." after 3/3 puzzles")
    task.spawn(function()
        -- Bounded 7-second confirmation spans the non-final puzzle-release
        -- cinematic, which can begin after the third puzzle was confirmed.
        -- Never anchor/unanchor or fight the final ending; no infinite loop.
        local deadline=os.clock()+7
        local stableSince=nil
        local lastCorrectionLog=-math.huge
        while alive and os.clock()<deadline do
            if char~=player.Character or not root.Parent then
                homeReturnResult="character changed during return"
                break
            end
            if player:GetAttribute("NeedleRoundComplete")==true
                or player:GetAttribute("NeedleOwned")==true then
                homeReturnResult="final/needle state interrupted return"
                break
            end
            local now=os.clock()
            local distance=(root.Position-goal.Position).Magnitude
            homeReturnDistance=distance
            if distance<=4 then
                stableSince=stableSince or now
                local releaseActive=player:GetAttribute("Chapter2ReleaseActive")==true
                    or player:GetAttribute("CutsceneActive")==true
                if now-stableSince>=1.2 and not releaseActive then
                    homeReturnResult="confirmed stable at original start for 1.2s"
                    break
                end
            else
                stableSince=nil
                if not root.Anchored and homeReturnAttempts<18 then
                    homeReturnAttempts+=1
                    local ok,err=pcall(function()
                        root.CFrame=goal
                        root.AssemblyLinearVelocity=Vector3.zero
                        root.AssemblyAngularVelocity=Vector3.zero
                    end)
                    if not ok then
                        homeReturnResult="return CFrame error: "..tostring(err)
                        break
                    end
                    if homeReturnAttempts<=3 or now-lastCorrectionLog>1.4 then
                        lastCorrectionLog=now
                        holdLog(string.format(
                            "RETURN correction #%d: gap=%.2f studs, cutscene=%s, release=%s",
                            homeReturnAttempts,distance,
                            tostring(player:GetAttribute("CutsceneActive")),
                            tostring(player:GetAttribute("Chapter2ReleaseActive"))))
                    end
                end
            end
            task.wait(0.12)
        end
        if root and root.Parent and char==player.Character then
            homeReturnDistance=(root.Position-goal.Position).Magnitude
            if homeReturnDistance<=4 then
                homeReturnResult="at original start, final offset "..
                    string.format("%.2f",homeReturnDistance).." studs"
            elseif homeReturnResult=="return requested after "..tostring(reason) then
                homeReturnResult="not stable: server/cinematic correction; offset "..
                    string.format("%.2f",homeReturnDistance).." studs"
            end
            holdLog("RETURN verification: "..homeReturnResult..
                " | pos="..tostring(root.Position)..
                " | attempts="..homeReturnAttempts)
        end
    end)
end
local function beginHold(char,root,goal,source)
    releaseHold("restarted")
    holdSerial+=1
    local serial=holdSerial
    holdActive=true
    holdGoal=goal
    holdStarted=os.clock()
    holdEnded=0
    holdApplied,holdCorrections,holdAdoptions,holdPhaseChanges=0,0,0,0
    holdLastCorrectionAt=-math.huge
    holdLastObservedSolved=nil
    holdResult="running"
    holdLog(source.." started local hold at "..tostring(goal)..
        " for at most "..holdDuration..
        "s. This does not guarantee server-side position.")
    task.spawn(function()
        local nextTick=0
        local nextInfo=0
        local secondPhase=false
        local lastReadAt=-math.huge
        local puzzleFolder=ReplicatedStorage:FindFirstChild("Puzzles")
        while alive and holdActive and serial==holdSerial do
            task.wait(0.03)
            local now=os.clock()
            if now<nextTick then continue end
            nextTick=now+0.035
            if player.Character~=char or not root.Parent then
                releaseHold("character changed")
                break
            end
            if player:GetAttribute("NeedleOwned")==true
                or player:GetAttribute("NeedleRoundComplete")==true then
                releaseHold("key owned / ending protected")
                break
            end
            if now-holdStarted>=holdDuration then
                releaseHold("30-second safety timeout, regardless of puzzle state")
                break
            end
            if not puzzleFolder or not puzzleFolder.Parent then
                puzzleFolder=ReplicatedStorage:FindFirstChild("Puzzles")
            end
            local solved=puzzleFolder
                and tonumber(puzzleFolder:GetAttribute("SolvedPuzzleCount")) or 0
            if solved~=holdLastObservedSolved then
                holdLastObservedSolved=solved
                holdLog("Server replicated SolvedPuzzleCount="..tostring(solved))
            end
            if solved>=3 then
                releaseHold("3/3 server-replicated puzzles completed")
                returnToOrigin("3/3 server-replicated puzzles")
                break
            end
            if not followSolver and not secondPhase and solved>=2 and bestPair
                and snapshot and holdGoal
                and (holdGoal-snapshot.keypad).Magnitude>LIMIT.Keypad then
                -- Switch once when nearly finished: use the endpoint
                -- geometrically capable of reaching the keypad.
                local a,b=bestPair.a,bestPair.b
                local da=(a.pos-snapshot.keypad).Magnitude
                local db=(b.pos-snapshot.keypad).Magnitude
                local target=da<=db and a or b
                if (target.pos-snapshot.keypad).Magnitude<=LIMIT.Keypad then
                    holdGoal=target.pos
                    holdPhaseChanges+=1
                    secondPhase=true
                    holdLog("2 puzzles done: switching to Number keypad-compatible point "..
                        tostring(holdGoal))
                else
                    secondPhase=true
                    holdLog("No keypad-compatible pair endpoint; retaining current target")
                end
            end
            if root.Anchored then
                -- Don't unanchor a native cinematic. Reconsider next tick.
                if now>=nextInfo then
                    nextInfo=now+2
                    holdLog("Root anchored: not writing CFrame until released")
                end
                continue
            end
            local dist=(root.Position-holdGoal).Magnitude
            if dist>0.75 then
                -- Accept deliberate in-room relocations from the existing
                -- puzzle worker. Without this, hold fights Number-poster
                -- recovery moves. The 60-stud return to hay is out of range.
                local inRoom=best and (root.Position-best.pos).Magnitude<=25
                if dist>(followSolver and 1.8 or 5) and dist<=23 and inRoom and
                    now-holdStarted>(followSolver and 0.12 or 0.5) and
                    now-holdLastCorrectionAt>0.12 then
                    local floorOk=false
                    local _,_,hum=getRoot()
                    if hum and snapshot then
                        local p=floorCandidate(root.Position.X,root.Position.Z,
                            snapshot,root,hum)
                        floorOk=p and math.abs(root.Position.Y-p.Y)<=5
                    end
                    if floorOk then
                        holdGoal=root.Position
                        holdAdoptions+=1
                        if now>=nextInfo then
                            nextInfo=now+0.8
                            holdLog("Adopted in-room movement by puzzle solver at "..
                                tostring(holdGoal))
                        end
                        continue
                    end
                end
                if dist>25 then
                    holdCorrections+=1
                    holdLastCorrectionAt=now
                    if holdCorrections<=5 or now>=nextInfo then
                        nextInfo=now+2
                        holdLog(string.format(
                            "Large position reset #%d: %.2f studs from held target; restoring local pose",
                            holdCorrections,dist))
                    end
                end
                local ok,errorText=pcall(function()
                    root.CFrame=CFrame.new(holdGoal)*root.CFrame.Rotation
                end)
                if ok then
                    holdApplied+=1
                else
                    releaseHold("CFrame write failed: "..tostring(errorText))
                    break
                end
            end
        end
    end)
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
    -- F6 manual teleport keeps original bootstrap capture intact.
    captureOriginal()
    restoreCF=originCF or root.CFrame
    restoreCharacter=originCharacter or char
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
        "; hold starts now; F12 releases for natural snapback; F7 restores manually")
    beginHold(char,root,goal,source)
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
    releaseHold("F7 manual restore")
    local _,root=getRoot()
    local homeCF=originCF or restoreCF
    local homeChar=originCharacter or restoreCharacter
    if not homeCF or player.Character~=homeChar or not root
        or player:GetAttribute("NeedleRoundComplete")==true then
        log("RESTORE","No safe F6 teleport to undo")
        return
    end
    moveSerial+=1 -- stop reporting snapback against a deliberately undone TP
    root.CFrame=homeCF
    root.AssemblyLinearVelocity=Vector3.zero
    restoreCF,restoreCharacter=nil,nil
    log("RESTORE","F7 returned to captured original Chapter2 start")
end

-- Unlike the 60-stud direct CFrame write, this optional test requests
-- regular Humanoid movement through a navmesh route. It neither bypasses
-- obstacles nor forces client position. Server movement acceptance can be
-- verified at each waypoint. Run without Main controlling the character.
local function navigationLog(message)
    local text=string.format("+%.2fs %s",os.clock()-started,tostring(message))
    navigationReports[#navigationReports+1]=text
    if #navigationReports>80 then table.remove(navigationReports,1) end
    log("PATH",message)
end
local function cancelNavigation(reason)
    navigationSerial+=1
    local was=navigationActive
    navigationActive=false
    local _,root,hum=getRoot()
    if hum and root then
        pcall(function()hum:MoveTo(root.Position)end)
    end
    if was then navigationLog("STOP: "..tostring(reason or "manual F12")) end
end
local function walkToPair(which)
    if navigationActive then
        navigationLog("F"..(which=="A" and "10" or "11")..
            " ignored: navigation already in progress (F12 to stop)")
        return
    end
    if not bestPair then
        navigationLog("Cannot walk: F5 scan and acquire two-position plan first")
        return
    end
    local candidate=(which=="A") and bestPair.a or bestPair.b
    if not candidate then return end
    local char,root,hum=getRoot()
    if not root or not hum or hum.Health<=0 or root.Anchored
        or player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("NeedleInputLocked")==true then
        navigationLog("Cannot path: character unavailable, anchored, input-locked, or final ending")
        return
    end
    if env.__BEYY_CH2_COMBO_PUZZLE_RUNNING==true then
        navigationLog("Cannot path while combined puzzle worker is active")
        return
    end
    navigationSerial+=1
    local serial=navigationSerial
    navigationActive=true
    local goal=candidate.pos
    local startAt=os.clock()
    local path
    local created,err=pcall(function()
        path=PathfindingService:CreatePath({
            AgentRadius=2,
            AgentHeight=5,
            AgentCanJump=true,
            WaypointSpacing=4,
        })
        path:ComputeAsync(root.Position,goal)
    end)
    if not created or not path or path.Status~=Enum.PathStatus.Success then
        navigationLog("Pathfinding "..which.." failed: "..tostring(
            created and path and path.Status or err)..
            " | start="..tostring(root.Position).." goal="..tostring(goal))
        navigationActive=false
        return
    end
    local waypoints=path:GetWaypoints()
    local pathLength=0
    for i=2,#waypoints do
        pathLength+=(waypoints[i].Position-waypoints[i-1].Position).Magnitude
    end
    navigationLog(string.format(
        "F%s path to %s: %d waypoints, %.2f studs route vs %.2f straight",
        which=="A" and "10" or "11",which,#waypoints,pathLength,
        (root.Position-goal).Magnitude))
    local reached=true
    for i,waypoint in ipairs(waypoints) do
        if not alive or serial~=navigationSerial
            or player.Character~=char or not root.Parent or hum.Health<=0
            or player:GetAttribute("NeedleRoundComplete")==true then
            reached=false
            navigationLog("Path "..which.." stopped: character changed, ending, or F12")
            break
        end
        if waypoint.Action==Enum.PathWaypointAction.Jump then
            pcall(function()hum.Jump=true end)
        end
        local ok,why=pcall(function()hum:MoveTo(waypoint.Position)end)
        if not ok then
            reached=false
            navigationLog("MoveTo error: "..tostring(why))
            break
        end
        local begin=os.clock()
        local startDist=(root.Position-waypoint.Position).Magnitude
        local maxWait=math.clamp(startDist/math.max(5,hum.WalkSpeed)+3,3,9)
        local distance=startDist
        repeat
            task.wait(0.12)
            distance=(root.Position-waypoint.Position).Magnitude
        until not alive or serial~=navigationSerial
            or distance<=3.0 or os.clock()-begin>maxWait
        if not alive or serial~=navigationSerial then reached=false;break end
        if distance>3.0 then
            reached=false
            navigationLog(string.format(
                "Path %s stuck at waypoint %d/%d: distance %.2f; ended %.2fs",
                which,i,#waypoints,distance,os.clock()-startAt))
            break
        end
    end
    local final=(root.Position-goal).Magnitude
    local ev=snapshot and evaluate(root.Position,snapshot)
    navigationLog(string.format(
        "Path %s complete=%s final offset %.2f studs core=%s posters=%s elapsed=%.2fs",
        which,tostring(reached),final,
        ev and ev.core.."/5" or "?",
        ev and ev.covered.."/"..ev.posterTotal or "?",
        os.clock()-startAt))
    navigationActive=false
end

local function stop(reason)
    if not alive then return end
    releaseHold("diagnostic stopped")
    cancelNavigation("diagnostic stopped")
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
    elseif input.KeyCode==Enum.KeyCode.F10 then
        task.spawn(walkToPair,"A")
    elseif input.KeyCode==Enum.KeyCode.F11 then
        task.spawn(walkToPair,"B")
    elseif input.KeyCode==Enum.KeyCode.F12 then
        releaseHold("F12 manual release")
        cancelNavigation("F12")
    end
end)
log("READY","v6: combined mode follows solver location; returns to original start on 3/3. F9 report, F12 abort.")
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
    -- Teleport once after scan, then hold locally for a bounded time.
    -- Do not force unanchor while a native cutscene is controlling movement.
    -- Snapback reports and server puzzle confirmations remain separate.
    captureOriginal()
    automaticMoveAttempted=true
    if followSolver then
        -- Only the existing puzzle worker decides where to stand. Previous
        -- v5 held the diagnostic's (worse) 4/5 point and fought its moves.
        holdLog("SOLVER-ANCHOR MODE: waiting for puzzle worker to reach room; no diagnostic teleport")
        local deadline=os.clock()+25
        while alive and os.clock()<deadline do
            local char,root=getRoot()
            if char and root and not root.Anchored
                and player:GetAttribute("NeedleRoundComplete")~=true then
                local inRoom=best and (root.Position-best.pos).Magnitude<=22
                local farFromStart=originCF
                    and (root.Position-originCF.Position).Magnitude>25
                if env.__BEYY_CH2_COMBO_PUZZLE_RUNNING==true
                    and inRoom and farFromStart then
                    automaticMoveSucceeded=true
                    autoMoveAt=os.clock()-started
                    holdLog("Observed puzzle worker's first in-room point: "..tostring(root.Position))
                    beginHold(char,root,root.Position,"SOLVER")
                    return
                end
            end
            task.wait(0.025)
        end
        holdLog("No verified puzzle-worker in-room position observed in 25s; no competing TP started")
        return
    end
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
