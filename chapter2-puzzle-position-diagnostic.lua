-- Beyy Chapter 2 Single-Spot Puzzle Position Diagnostic v1
-- Passive measurement by default. Does NOT send any puzzle/lever remotes.
-- F5 rescan, F6 opt-in one-time best-position TP, F7 undo, F9 copy/save.
-- Compatible with running Chapter2 Main: the passive scan does not write
-- camera, character, input locks, or puzzle state.
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
    local function add(label,vec,limit)
        local d=(pos-vec).Magnitude
        local excess=math.max(0,d-limit)
        passed+=d<=limit and 1 or 0
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
        if dist<=LIMIT.Poster then covered+=1 end
        posterMax=math.max(posterMax,dist)
    end
    return {pos=pos,core=passed,coreOverflow=overflow,
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
    if not alive then return end
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
    -- Sample the central room footprint, then refine local maxima.
    for dx=-25,25,1.5 do
        for dz=-25,25,1.5 do
            local spot=floorCandidate(middle.X+dx,middle.Z+dz,t,root,hum)
            if spot then
                accepted+=1
                local ev=evaluate(spot,t)
                evaluated+=1
                if better(ev,bestFound) then bestFound=ev end
                if ev.core==5 and ev.covered==totalPosters then
                    candidates[#candidates+1]=ev
                end
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
    t.fullCoverCandidates=#candidates
    if not bestFound then
        lastStatus="No verified floor positions near the shared puzzle targets"
        log("SCAN",lastStatus)
        return
    end
    local full=bestFound.core==5 and bestFound.covered==totalPosters
    lastStatus=full and "ONE-SPOT GEOMETRICALLY FEASIBLE"
        or (bestFound.core==5 and "all core targets reachable; some posters require moving"
        or "no single point met all 5 core range limits")
    log("SCAN",string.format(
        "%s | best=%s | 5 core=%d/5 posters=%d/%d floorCandidates=%d",
        lastStatus,tostring(bestFound.pos),bestFound.core,
        bestFound.covered,totalPosters,evaluated))
    if t.originalScore then
        log("COMPARE",string.format(
            "Existing solver anchor: core=%d/5 posters=%d/%d; proposed core=%d/5 posters=%d/%d",
            t.originalScore.core,t.originalScore.covered,totalPosters,
            bestFound.core,bestFound.covered,totalPosters))
    end
end

local function report()
    local lines={
        "CHAPTER 2 SINGLE-SPOT POSITION DIAGNOSTIC v1",
        "Passive by default. No puzzle or lever remotes sent.",
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
local function moveBest()
    if not best or not snapshot or best.core<5 then
        log("MOVE","F6 rejected: no verified common core position")
        return
    end
    if player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true then
        log("MOVE","F6 rejected: protected ending")
        return
    end
    local char,root=getRoot()
    if not root or root.Anchored then
        log("MOVE","F6 rejected: root absent/anchored")
        return
    end
    restoreCF=root.CFrame
    restoreCharacter=char
    local goal=best.pos
    root.CFrame=CFrame.new(goal)*root.CFrame.Rotation
    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero
    log("MOVE","F6 one test TP to "..tostring(goal)..
        " (use F7 to restore; no puzzle actions)")
    task.spawn(function()
        for _,delay in ipairs({0.15,0.5,1.0,2.0}) do
            task.wait(delay)
            if not alive or player.Character~=char or not root.Parent then break end
            local d=(root.Position-goal).Magnitude
            local entry=string.format("After %.2fs: offset %.3f studs, anchored=%s",
                delay,d,tostring(root.Anchored))
            travelResults[#travelResults+1]=entry
            log("SNAPBACK",entry)
        end
    end)
end
local function undo()
    local _,root=getRoot()
    if not restoreCF or player.Character~=restoreCharacter or not root
        or player:GetAttribute("NeedleRoundComplete")==true then
        log("RESTORE","No safe F6 teleport to undo")
        return
    end
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
log("READY","Passive scan + position logging. F5 rescan; F6 optional one TP; F7 undo; F9 report.")
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
