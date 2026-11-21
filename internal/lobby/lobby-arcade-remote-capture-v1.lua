-- BEYY_ARCADE_REMOTE_CAPTURE_V1
-- Search for the Needle lobby: passive Arcade remote and gameplay recorder.
-- Does not invoke any game remote or change gameplay/rewards.
-- Optional executor outgoing-namecall observer passes calls through unchanged.
local PLACE_ID=77108422251420
if game.PlaceId~=PLACE_ID then
    warn("[Arcade Remotes] Lobby only (PlaceId="..tostring(game.PlaceId)..")")
    return
end
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local HttpService=game:GetService("HttpService")
local LocalPlayer=Players.LocalPlayer
if not LocalPlayer then return warn("[Arcade Remotes] LocalPlayer missing") end
local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end
if type(env.BeyyArcadeRemoteCaptureStop)=="function" then
    pcall(env.BeyyArcadeRemoteCaptureStop)
end

local running=true
local started=os.clock()
local connections={}
local seenRemotes={}
local lastStateSignature=nil
local MAX_EVENTS=2500
local output={
    signature="BEYY_ARCADE_REMOTE_CAPTURE_V1",
    placeId=game.PlaceId,
    placeVersion=game.PlaceVersion,
    startedUnix=os.time(),
    description="Client-visible Arcade remote activity while playing, including available outbound namecall attempts.",
    limitations={
        "OnClientEvent shows incoming RemoteEvents only.",
        "Outgoing RemoteEvent/RemoteFunction calls may be visible if executor supports hookmetamethod and getnamecallmethod; other call paths may not be captured.",
        "RemoteFunction results and private server validation are not observable by this recorder.",
        "FireServer returns no acknowledgment of reward acceptance.",
        "Only Arcade-related remote payloads are included. Other remote paths are recorded without payloads to avoid logging unrelated private data.",
    },
    outgoingMode="not_attempted",
    remotes={},
    events={},
    snapshots={},
    counts={incoming=0,outgoing=0,hubEvents=0,dropped=0},
}
local function ts()
    return math.floor((os.clock()-started)*1000+0.5)/1000
end
local function fullPath(obj)
    local ok,v=pcall(function() return obj:GetFullName() end)
    return ok and tostring(v) or tostring(obj)
end
local function connect(signal,callback)
    local ok,c=pcall(function() return signal:Connect(callback) end)
    if ok and c then table.insert(connections,c) end
end
local function remoteClass(obj)
    return typeof(obj)=="Instance" and
       (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent"))
end
local function isArcadePath(p)
    local low=p:lower()
    return low:find("arcade",1,true)~=nil
        or low:find("blaster",1,true)~=nil
end
local function scrub(v,depth,seen)
    depth=depth or 0
    local typ=typeof(v)
    if typ=="nil" or typ=="boolean" or typ=="number" then return v end
    if typ=="string" then return v:sub(1,400) end
    if typ=="Instance" then return {class=v.ClassName,path=fullPath(v)} end
    if typ=="Vector2" or typ=="Vector3" or typ=="CFrame" or typ=="UDim2"
        or typ=="UDim" or typ=="Color3" or typ=="EnumItem" then return tostring(v) end
    if typ~="table" then return "<"..tostring(typ)..">" end
    if depth>=3 then return "<table-depth-limit>" end
    seen=seen or {}
    if seen[v] then return "<circular>" end
    seen[v]=true
    local result,n={},0
    for k,value in pairs(v) do
        n+=1
        if n>24 then result.__truncated=true break end
        local key=tostring(k)
        local lower=key:lower()
        if lower:find("token",1,true) or lower:find("secret",1,true)
            or lower:find("password",1,true) or lower:find("cookie",1,true)
            or lower:find("auth",1,true) or lower:find("sessionkey",1,true) then
            result[key]="<redacted>"
        else
            result[key]=scrub(value,depth+1,seen)
        end
    end
    seen[v]=nil
    return result
end
local function argPreview(...)
    local n=select("#",...)
    local values={}
    for i=1,math.min(12,n) do
        local arg=select(i,...)
        values[tostring(i)]=scrub(arg)
    end
    return values,n
end
local function event(name,data)
    if not running then return end
    if #output.events>=MAX_EVENTS then
        output.counts.dropped+=1
        return
    end
    table.insert(output.events,{t=ts(),name=name,data=data})
end
local function attrs(obj)
    local result={}
    if not obj then return result end
    local ok,raw=pcall(function() return obj:GetAttributes() end)
    if ok then
        for k,v in pairs(raw) do
            local low=k:lower()
            if not (low:find("token",1,true) or low:find("secret",1,true)
                or low:find("password",1,true)) then
                result[k]=scrub(v)
            end
        end
    end
    return result
end
local function summaryState()
    local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local screen=pg and pg:FindFirstChild("ArcadeScreen")
    local arena=screen and screen:FindFirstChild("Arena")
    local hud=arena and arena:FindFirstChild("HUD")
    local machine=Workspace:FindFirstChild("Arcade Machine")
    local prompt=machine and machine:FindFirstChild("PlayPrompt",true)
    local out={
        playing=LocalPlayer:GetAttribute("ArcadePlaying"),
        inputLocked=LocalPlayer:GetAttribute("NeedleInputLocked"),
        gems=LocalPlayer:GetAttribute("SpinUsableGems"),
        machineArcadePlayers=machine and machine:GetAttribute("ArcadePlayers"),
        screenEnabled=screen and screen:IsA("ScreenGui") and screen.Enabled or false,
        arenaVisible=arena and arena:IsA("GuiObject") and arena.Visible or false,
        promptEnabled=prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled or false,
    }
    if hud then
        for _,label in ipairs({"Score","Wave","Health"}) do
            local f=hud:FindFirstChild(label)
            if f then
                local strings={}
                for _,ch in ipairs(f:GetChildren()) do
                    if ch:IsA("TextLabel") or ch:IsA("TextButton") then
                        table.insert(strings,ch.Text:sub(1,180))
                    end
                end
                out[label]=strings
            end
        end
    end
    if arena then
        local overlay=arena:FindFirstChild("Overlay")
        local dim=overlay and overlay:FindFirstChild("Dim")
        local panel=dim and dim:FindFirstChild("Panel")
        local leave=panel and panel:FindFirstChild("LEAVE")
        out.pauseOverlay=dim and dim:IsA("GuiObject") and dim.Visible or false
        out.leaveText=leave and leave:IsA("TextButton") and leave.Text or nil
    end
    return out
end
local function snapshot(label)
    local state=summaryState()
    table.insert(output.snapshots,{t=ts(),label=label,state=state})
    event("state_"..label,state)
end
local function listeningNow()
    local p=LocalPlayer:GetAttribute("ArcadePlaying")
    if p==true then return true end
    local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local gui=pg and pg:FindFirstChild("ArcadeScreen")
    return gui and gui:IsA("ScreenGui") and gui.Enabled==true or false
end
local function trackRemote(obj)
    if not running or not remoteClass(obj) or seenRemotes[obj] then return end
    seenRemotes[obj]=true
    local p=fullPath(obj)
    table.insert(output.remotes,{path=p,class=obj.ClassName,attributes=attrs(obj)})
    if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") then
        connect(obj.OnClientEvent,function(...)
            if not running then return end
            if not isArcadePath(p) and not listeningNow() then return end
            output.counts.incoming+=1
            local args,n
            if isArcadePath(p) then args,n=argPreview(...) else n=select("#",...) end
            event("incoming",{remote=p,class=obj.ClassName,argc=n,
                args=args,privacyMode=isArcadePath(p) and "arcade_payload" or "metadata_only"})
        end)
    end
end
local function trackTree(root)
    if not root then return end
    for _,obj in ipairs(root:GetDescendants()) do
        if remoteClass(obj) then trackRemote(obj) end
    end
    connect(root.DescendantAdded,function(obj)
        if remoteClass(obj) then
            trackRemote(obj)
            event("remote_added",{path=fullPath(obj),class=obj.ClassName})
        end
    end)
    connect(root.DescendantRemoving,function(obj)
        if remoteClass(obj) then
            event("remote_removed",{path=fullPath(obj),class=obj.ClassName})
        end
    end)
end

-- This callback records only actions announced by BeyyHub's own worker.
-- Does not generate, modify, or transmit remote calls.
local function hubAction(stage,details)
    output.counts.hubEvents+=1
    event("beyyhub_"..tostring(stage),scrub(details))
end
env.BeyyArcadeRemoteTraceEvent=hubAction
_G.BeyyArcadeRemoteTraceEvent=hubAction

-- Optional interception of outbound namecall attempts. One pass-through
-- observer per executor process. No spoofing or change to remote args/results.
local hookState=env.BeyyArcadeRemoteCaptureHook
local function outgoing(obj,method,...)
    if not running or not remoteClass(obj) then return end
    local p=fullPath(obj)
    if not isArcadePath(p) and not listeningNow() then return end
    output.counts.outgoing+=1
    local args,n
    if isArcadePath(p) then args,n=argPreview(...) else n=select("#",...) end
    local origin="unknown"
    if type(checkcaller)=="function" then
        local ok,result=pcall(checkcaller)
        if ok then origin=result and "executor_hint" or "game_hint" end
    end
    event("outgoing",{remote=p,class=obj.ClassName,method=method,argc=n,
        args=args,privacyMode=isArcadePath(p) and "arcade_payload" or "metadata_only",
        originHint=origin})
end
if type(hookState)=="table" and hookState.installed then
    hookState.listener=outgoing
    output.outgoingMode="existing_pass_through_hook"
elseif type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
    local newState={installed=false,listener=outgoing}
    local previous
    local function observer(self,...)
        local method=getnamecallmethod()
        if method=="FireServer" or method=="InvokeServer" then
            local callback=newState.listener
            if callback then pcall(callback,self,method,...) end
        end
        return previous(self,...)
    end
    local wrapped=observer
    if type(newcclosure)=="function" then
        local ok,result=pcall(newcclosure,observer)
        if ok and type(result)=="function" then wrapped=result end
    end
    local ok,original=pcall(hookmetamethod,game,"__namecall",wrapped)
    if ok and type(original)=="function" then
        previous=original
        newState.installed=true
        env.BeyyArcadeRemoteCaptureHook=newState
        output.outgoingMode="outbound_namecalls_observed"
    else
        -- Failed hooks cannot be assumed active. A successful hook always
        -- returns its previous callable so network calls pass through.
        newState.listener=nil
        output.outgoingMode="outbound_hook_unavailable"
        warn("[Arcade Remotes] Outgoing hook unavailable; incoming and BeyyHub events still record.")
    end
else
    output.outgoingMode="outbound_hook_unsupported"
    warn("[Arcade Remotes] Executor does not support outgoing namecall observation.")
end
local function export()
    snapshot("stop")
    output.endedUnix=os.time()
    output.durationSeconds=ts()
    local ok,data=pcall(function() return HttpService:JSONEncode(output) end)
    if not ok then
        warn("[Arcade Remotes] Failed to encode JSON: "..tostring(data))
        return
    end
    env.BeyyArcadeRemoteCaptureLastJSON=data
    local fileNames={"BeyyHub/arcade_remote_capture_v1.json","arcade_remote_capture_v1.json"}
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then makefolder("BeyyHub") end
        end)
    end
    for _,filename in ipairs(fileNames) do
        if type(writefile)=="function" then
            local written,err=pcall(writefile,filename,data)
            if written and type(readfile)=="function" then
                local verified,readBack=pcall(readfile,filename)
                written=verified and readBack==data
            end
            print("[Arcade Remotes] file="..filename.." verified="..tostring(written))
            if not written then warn("[Arcade Remotes] Save issue: "..tostring(err)) end
        end
    end
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    local copied=false
    if clip then copied=pcall(clip,data) end
    print(string.format("[Arcade Remotes] Export %d bytes; incoming=%d outgoing=%d hub=%d dropped=%d clipboard=%s mode=%s",
        #data,output.counts.incoming,output.counts.outgoing,output.counts.hubEvents,
        output.counts.dropped,tostring(copied),output.outgoingMode))
end
local function stop()
    if not running then return end
    export()
    running=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    if env.BeyyArcadeRemoteTraceEvent==hubAction then env.BeyyArcadeRemoteTraceEvent=nil end
    if _G.BeyyArcadeRemoteTraceEvent==hubAction then _G.BeyyArcadeRemoteTraceEvent=nil end
    if type(env.BeyyArcadeRemoteCaptureHook)=="table"
        and env.BeyyArcadeRemoteCaptureHook.listener==outgoing then
        env.BeyyArcadeRemoteCaptureHook.listener=nil
    end
    env.BeyyArcadeRemoteCaptureStop=nil
    print("[Arcade Remotes] Stopped")
end
env.BeyyArcadeRemoteCaptureStop=stop
-- Incoming remote inventory includes non-Arcade remote paths but only
-- records payloads from Arcade-named remotes.
trackTree(ReplicatedStorage)
trackTree(Workspace)
local machine=Workspace:FindFirstChild("Arcade Machine")
if machine then
    connect(machine:GetAttributeChangedSignal("ArcadePlayers"),function()
        event("machine_players",{count=machine:GetAttribute("ArcadePlayers")})
    end)
end
for _,name in ipairs({"ArcadePlaying","NeedleInputLocked","SpinUsableGems"}) do
    connect(LocalPlayer:GetAttributeChangedSignal(name),function()
        event("attribute_changed",{name=name,value=scrub(LocalPlayer:GetAttribute(name))})
        snapshot("attribute_"..name)
    end)
end
snapshot("start")
task.spawn(function()
    while running do
        local state=summaryState()
        local ok,signature=pcall(function()return HttpService:JSONEncode(state)end)
        if ok and signature~=lastStateSignature then
            lastStateSignature=signature
            event("arcade_ui_changed",state)
        end
        task.wait(0.15)
    end
end)
print("[Arcade Remotes] Recording incoming/outgoing observed remotes; mode="..output.outgoingMode)
print("[Arcade Remotes] Start before arcade play, then stop via BeyyHub button after exiting.")
task.delay(120,function()
    if running then
        print("[Arcade Remotes] Auto export after 120 seconds.")
        stop()
    end
end)
-- END BEYY_ARCADE_REMOTE_CAPTURE_V1