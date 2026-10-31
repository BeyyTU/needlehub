-- Beyy Chapter 2 Teammate PAPER-ONLY Collector v1
-- Independent teammate client: collect NumberPuzzle posters only.
-- No Color/Picture/lever actions, no Number Submit, no upgrades, no hand-in.
-- Safe floor-verified repositioning; native feedback/state confirmations.
-- Uses optional existing CINEFIX3 cutscene-only camera/Skip controller.
-- Re-queues this loader on each Chapter 2 replay teleport.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-teammate-papers.lua"
local CINE_URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-cutscene-deferred-invisible-skip-test.lua"
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
local env=_G
if type(getgenv)=="function" then
    local ok,r=pcall(getgenv)
    if ok and type(r)=="table" then env=r end
end
local function say(s) print("[CH2 TEAM PAPERS] "..tostring(s)) end
local function warnP(s) warn("[CH2 TEAM PAPERS] "..tostring(s)) end

local function queueReplay()
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then
        warnP("Replay auto-load unavailable: queue_on_teleport unsupported by executor")
        return false
    end
    local payload=[==[
-- Beyy Chapter 2 teammate papers: replay continuation
local src="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-teammate-papers.lua"
local players=game:GetService("Players")
for attempt=1,10 do
    if not game:IsLoaded() or not players.LocalPlayer then task.wait(0.2) end
    local ok,body=pcall(function()
        return game:HttpGet(src.."?paper-replay="..os.time().."-"..attempt)
    end)
    if ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Teammate PAPER-ONLY Collector v1",1,true) then
        local fn=loadstring(body)
        if fn then
            local ran,err=pcall(fn)
            if ran then return end
            warn("[CH2 TEAM PAPERS] Replay loader error: "..tostring(err))
        end
    end
    task.wait(0.35)
end
warn("[CH2 TEAM PAPERS] Replay loader unable to download script")
]==]
    local ok,err=pcall(queue,payload)
    if not ok then warnP("Replay autoload queue failure: "..tostring(err)); return false end
    say("REPLAY AUTOLOAD ARMED for teammate paper collector")
    return true
end
if game.PlaceId==LOBBY then
    queueReplay()
    say("Lobby: queued paper-only collector for Chapter 2")
    return
end
if game.PlaceId~=CHAPTER2 then warnP("Only Chapter 2 or its lobby is supported"); return end
if type(env.__BEYY_CH2_TEAM_PAPERS_STOP)=="function" then
    pcall(env.__BEYY_CH2_TEAM_PAPERS_STOP,"restarted")
end
if env.__BEYY_CH2_HOLD_FOLLOW_SOLVER==true or env.__BEYY_CH2_COMBO_PUZZLE_RUNNING==true then
    warnP("Another solver is running on THIS client. Run this on your teammate's separate Roblox account.")
    return
end
local alive=true
local started=os.clock()
local events={}
local connections={}
local stats={requests=0,confirmed=0,moves=0,failures=0,refreshes=0}
local feedback={}
local snapshot={}
local code=nil
local running=false
local status="initializing"
local maxAttempts=5
local posterParts={}
local lastStateLog=-math.huge
local function emit(tag,msg)
    local line=string.format("+%.3fs [%s] %s",os.clock()-started,tag,tostring(msg))
    if #events>120 then table.remove(events,1) end
    events[#events+1]=line
    say(line)
end
local function validCode(v) return type(v)=="string" and v:match("^%d%d%d%d$")~=nil end
local function finished()
    return player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("NeedleRoundCompleted")==true
end
local function root()
    local c=player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function isTaken(index)
    local n=snapshot.NumberPuzzle
    local taken=n and n.taken
    return feedback[index]==true or
        (taken and (taken[index]==true or taken[tostring(index)]==true)) or false
end
local function confirmedCount()
    local total=0
    for i in pairs(posterParts) do if isTaken(i) then total+=1 end end
    return total
end
local function report()
    return table.concat({
        "CHAPTER 2 TEAMMATE PAPER-ONLY v1",
        "Status: "..status,
        "Worker active: "..tostring(alive),
        "Number Poster requests / confirmed: "..stats.requests.." / "..stats.confirmed,
        "Repositions / rejected requests: "..stats.moves.." / "..stats.failures,
        "Acknowledged papers: "..confirmedCount().." / "..tostring((function()
            local c=0 for _ in pairs(posterParts) do c+=1 end return c end)()),
        "Number code obtained: "..tostring(validCode(code)),
        "Code (share with Main player if game does not replicate it): "..tostring(code or "not yet available"),
        "PuzzleState refreshes: "..stats.refreshes,
        "Server Number completed: "..tostring(snapshot.NumberPuzzle and snapshot.NumberPuzzle.completed),
        "Other puzzle or Submit remotes sent: NONE",
        "Elapsed: "..string.format("%.2fs",os.clock()-started),
        "=== EVENTS ===",
        table.concat(events,"\n")
    },"\n")
end
local function save(copy)
    local body=report()
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then makefolder("BeyyHub") end
        end)
    end
    if type(writefile)=="function" then pcall(writefile,"BeyyHub/chapter2_teammate_papers.txt",body) end
    if copy and type(setclipboard)=="function" then pcall(setclipboard,body) end
    if copy then say("F10 report copied/saved when executor supports it") end
end
local function stop(reason)
    if not alive then return end
    status=tostring(reason or "stopped")
    alive=false
    for _,con in ipairs(connections) do pcall(function()con:Disconnect()end) end
    if env.__BEYY_CH2_TEAM_PAPERS_STOP==stop then env.__BEYY_CH2_TEAM_PAPERS_STOP=nil end
    save(false)
    emit("STOP",status)
end
env.__BEYY_CH2_TEAM_PAPERS_STOP=stop
env.__BEYY_CH2_TEAM_PAPERS_REPORT=report
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.F10 then save(true)
    elseif input.KeyCode==Enum.KeyCode.F11 then stop("manual F11") end
end))
queueReplay()

-- The native intro Skip and non-final cinematic camera are handled by the
-- proven independent CINEFIX3 controller; it sends no puzzle requests.
task.spawn(function()
    if not alive then return end
    local ok,body=pcall(function() return game:HttpGet(CINE_URL.."?team-paper-cinefix3="..tostring(os.time())) end)
    if ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST",1,true) then
        local fn,compileErr=loadstring(body)
        if fn and alive then
            local ran,runErr=pcall(fn)
            if ran then emit("CINEMATIC","CINEFIX3 standalone companion started")
            else warnP("Cutscene companion runtime: "..tostring(runErr)) end
        else warnP("Cutscene companion compile: "..tostring(compileErr)) end
    else
        warnP("Cutscene controller unavailable; paper collection will still attempt native poster actions")
    end
end)

task.spawn(function()
    local F=RS:WaitForChild("Puzzles",12)
    if not alive then return end
    local stateRemote=F and F:FindFirstChild("PuzzleState")
    local feedbackRemote=F and F:FindFirstChild("PuzzleFeedback")
    local action=F and F:FindFirstChild("PuzzleAction")
    if not stateRemote or not action or not action:IsA("RemoteEvent") then
        stop("native puzzle remotes unavailable");return
    end
    table.insert(connections,stateRemote.OnClientEvent:Connect(function(data)
        if type(data)~="table" then return end
        snapshot=data
        local n=data.NumberPuzzle
        if n and validCode(n.code) then code=n.code end
    end))
    if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
        table.insert(connections,feedbackRemote.OnClientEvent:Connect(function(puzzle,step,index,correct,newCode)
            if puzzle=="NumberPuzzle" and step=="Poster" and type(tonumber(index))=="number" then
                feedback[tonumber(index)]=true
                if validCode(newCode) then code=newCode end
            end
        end))
    end
    local folder=nil
    for i=1,100 do
        folder=Workspace:FindFirstChild("Puzzles")
        folder=folder and folder:FindFirstChild("NumberPuzzle")
        folder=folder and folder:FindFirstChild("Posters")
        if folder and #folder:GetChildren()>0 then break end
        task.wait(0.08)
    end
    if not folder or #folder:GetChildren()==0 then stop("Number posters not replicated");return end
    for _,p in ipairs(folder:GetChildren()) do
        local idx=p:GetAttribute("PosterIndex")
        if p:IsA("BasePart") and type(idx)=="number" then posterParts[idx]=p end
    end
    if not next(posterParts) then stop("no indexed posters found");return end
    stateRemote:FireServer()
    stats.refreshes+=1
    local limit=os.clock()+4
    while alive and os.clock()<limit and type(snapshot.NumberPuzzle)~="table" do task.wait(0.04) end
    local r=root()
    if not r then stop("no character HumanoidRootPart");return end
    local c=player.Character
    local param=RaycastParams.new()
    param.FilterType=Enum.RaycastFilterType.Exclude
    local allPuzzle=Workspace:FindFirstChild("Puzzles")
    param.FilterDescendantsInstances={c,allPuzzle}
    param.RespectCanCollide=true
    local sum,count=Vector3.zero,0
    for _,p in pairs(posterParts) do sum+=p.Position; count+=1 end
    local center=sum/count
    local function floorAt(x,z)
        local ray=Workspace:Raycast(Vector3.new(x,center.Y+25,z),Vector3.new(0,-72,0),param)
        if not ray or ray.Normal.Y<0.8 or not ray.Instance.CanCollide then return nil end
        local name=ray.Instance.Name:lower()
        if name:find("cage",1,true) or name:find("alien",1,true)
            or name:find("boss",1,true) then return nil end
        return Vector3.new(x,ray.Position.Y+3.1,z),ray.Instance
    end
    local best,anchorFloor,score=nil,nil,-math.huge
    for dx=-12,12,1.5 do
        for dz=-12,12,1.5 do
            local candidate,hit=floorAt(center.X+dx,center.Z+dz)
            if candidate then
                local coverage=0
                for _,p in pairs(posterParts) do
                    if (p.Position-candidate).Magnitude<8.0 then coverage+=1 end
                end
                local rating=coverage*100-(candidate-center).Magnitude
                if rating>score then score=rating;best=candidate;anchorFloor=hit end
            end
        end
    end
    if not best then stop("no verified floor in puzzle room");return end
    local function safePoint(x,z)
        local candidate,hit=floorAt(x,z)
        if not candidate or (candidate-best).Magnitude>28 then return nil end
        if hit~=anchorFloor and hit.Parent~=anchorFloor.Parent then return nil end
        return candidate
    end
    local function moveTo(pos)
        if not alive or finished() then return false end
        local rr=root()
        if not rr or player.Character~=c then return false end
        if rr.Anchored and (player:GetAttribute("CutsceneActive")==true
            or player:GetAttribute("Chapter2ReleaseActive")==true) then
            rr.Anchored=false
        end
        if rr.Anchored then return false end
        -- Large room entry may be one movement; subsequent jumps use short,
        -- floor-checked steps without reaching the cage/boss area.
        local from=rr.Position
        local dist=(Vector3.new(from.X,0,from.Z)-Vector3.new(pos.X,0,pos.Z)).Magnitude
        if dist>30 and (from-best).Magnitude<30 then return false end
        local steps=dist>30 and 1 or math.max(1,math.ceil(dist/7.5))
        for k=1,steps do
            local t=k/steps
            local target
            if steps==1 then target=pos
            else target=safePoint(from.X+(pos.X-from.X)*t,from.Z+(pos.Z-from.Z)*t) end
            if not target or not alive or finished() then return false end
            rr.CFrame=CFrame.new(target)*rr.CFrame.Rotation
            rr.AssemblyLinearVelocity=Vector3.zero
            rr.AssemblyAngularVelocity=Vector3.zero
            stats.moves+=1
            task.wait(0.11)
            if (rr.Position-target).Magnitude>5 then return false end
        end
        return (rr.Position-pos).Magnitude<5
    end
    if (r.Position-best).Magnitude>15 then
        if not moveTo(best) then
            emit("MOVE","Initial puzzle-room approach failed; retrying on next poster")
        end
    end
    status="collecting posters (no other puzzle remotes)"
    emit("READY",string.format("Indexed posters=%d, verified floor anchor=%s; native Poster requests only",
        count,tostring(best)))
    local attempts={}
    local nextTry={}
    local loopUntil=os.clock()+75
    while alive and os.clock()<loopUntil do
        if finished() then stop("final ending / needle hand-in protected");return end
        if validCode(code) then
            emit("DONE","4-digit paper code server-confirmed: "..code.."; Main can submit")
            stop("code confirmed; paper-only worker finished")
            return
        end
        if snapshot.NumberPuzzle and snapshot.NumberPuzzle.completed==true then
            stop("Number puzzle server-confirmed complete");return
        end
        if os.clock()-lastStateLog>0.65 then
            lastStateLog=os.clock()
            pcall(function()stateRemote:FireServer();stats.refreshes+=1 end)
        end
        local rr=root()
        if rr and player.Character==c then
            local candidate=nil
            local destination=nil
            local bestCost=math.huge
            for index,p in pairs(posterParts) do
                if p.Parent and not isTaken(index)
                    and (attempts[index] or 0)<maxAttempts
                    and os.clock()>=(nextTry[index] or 0) then
                    local dest,dist=nil,(rr.Position-p.Position).Magnitude
                    if dist<7.6 then dest=rr.Position
                    else
                        local d=Vector3.new(best.X-p.Position.X,0,best.Z-p.Position.Z)
                        if d.Magnitude>0.1 then
                            local px=p.Position.X+d.Unit.X*5.35
                            local pz=p.Position.Z+d.Unit.Z*5.35
                            dest=safePoint(px,pz)
                        end
                    end
                    if dest and (dest-p.Position).Magnitude<8 then
                        local travel=(rr.Position-dest).Magnitude
                        local cost=travel+(attempts[index] or 0)*3
                        if cost<bestCost then bestCost=cost;candidate=index;destination=dest end
                    end
                end
            end
            if candidate and destination then
                if (rr.Position-destination).Magnitude<=1.5 or moveTo(destination) then
                    rr=root()
                    local dist=(rr.Position-posterParts[candidate].Position).Magnitude
                    if dist<=8.15 then
                        local old=confirmedCount()
                        attempts[candidate]=(attempts[candidate] or 0)+1
                        stats.requests+=1
                        action:FireServer("NumberPuzzle","Poster",candidate)
                        emit("POSTER",string.format("Request index=%s attempt=%d distance=%.2f",
                            tostring(candidate),attempts[candidate],dist))
                        local deadline=os.clock()+1.20
                        while alive and os.clock()<deadline and not isTaken(candidate)
                            and not validCode(code) do task.wait(0.04) end
                        if isTaken(candidate) then
                            stats.confirmed+=1
                            emit("ACK",string.format("Poster index=%s confirmed (%d -> %d shared taken)",
                                tostring(candidate),old,confirmedCount()))
                        elseif validCode(code) then
                            emit("ACK","Poster request supplied valid code")
                        else
                            stats.failures+=1
                            nextTry[candidate]=os.clock()+0.30
                            emit("RETRY","No server confirmation for poster "..tostring(candidate))
                        end
                    end
                else
                    nextTry[candidate]=os.clock()+0.6
                end
            else
                -- No safe reachable poster: wait for remote/teammate progress.
                task.wait(0.45)
            end
        else
            task.wait(0.15)
        end
    end
    stop("paper scan timeout: see F10 report for server acknowledgements")
end)
say("PAPER-ONLY v1 ACTIVE: NumberPuzzle Poster pickups; no Picture, Color, levers or Submit. F10 report, F11 stop.")
