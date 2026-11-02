-- Standalone passive transition observer. Does not teleport, click, or fire gameplay remotes.
if game.GameId~=10770110947 then return end
local E=getgenv();local H=game:GetService("HttpService");local P=game:GetService("Players").LocalPlayer
if not P then warn("[Geode Transition] Local player unavailable");return end
if E.GeodeTransitionRecorder and E.GeodeTransitionRecorder.Stop then E.GeodeTransitionRecorder.Stop("Replaced",true)end
if not isfolder("Geode")then makefolder("Geode")end
local enabledPath="Geode/transition_enabled.txt"
local logPath="Geode/transition_events.jsonl"
local latestPath="Geode/transition_latest.json"
local old
pcall(function()old=H:JSONDecode(readfile(latestPath))end)
local api={Running=true,SessionId=H:GenerateGUID(false),QueuedArrival=E.__GeodeTransitionQueuedArrival==true}
E.__GeodeTransitionQueuedArrival=nil;E.GeodeTransitionRecorder=api
local connections={};local events={};local lastKey;local lastSnapshot
local function snapshot()
    local mtg=game:GetService("ReplicatedStorage"):FindFirstChild("MTG")
    local state=mtg and mtg:FindFirstChild("State");local hub=E.GeodeHub
    return {PlaceId=game.PlaceId,JobId=game.JobId,Role=mtg and mtg:GetAttribute("Role"),Phase=state and state:GetAttribute("Phase"),
        RunStart=state and state:GetAttribute("RunStart"),Ended=state and state:GetAttribute("Ended"),Escaped=P:GetAttribute("Escaped"),
        HubVersion=hub and hub.Version,HubRunning=hub and hub.Running}
end
local function record(kind,data)
    local row={Kind=kind,WallTimeMs=DateTime.now().UnixTimestampMillis,SessionId=api.SessionId,Data=data,State=snapshot()}
    events[#events+1]=row;if #events>80 then table.remove(events,1)end
    pcall(function()
        local line=H:JSONEncode(row).."\n"
        if isfile(logPath)and type(appendfile)=="function"then appendfile(logPath,line)
        elseif not isfile(logPath)then writefile(logPath,line)
        else local lines={};for _,e in ipairs(events)do lines[#lines+1]=H:JSONEncode(e)end;writefile(logPath,table.concat(lines,"\n").."\n")end
        writefile(latestPath,H:JSONEncode({SessionId=api.SessionId,QueuedArrival=api.QueuedArrival,Last=row,Events=events}))
    end)
    print("[Geode Transition] "..H:JSONEncode(row))
end
writefile(enabledPath,"true")
connections[#connections+1]=P.OnTeleport:Connect(function(state,place)
    record("OnTeleport",{TeleportState=tostring(state),DestinationPlaceId=place})
end)
connections[#connections+1]=P.CharacterAdded:Connect(function()record("CharacterAdded",{})end)
connections[#connections+1]=game:GetService("TeleportService").TeleportInitFailed:Connect(function(player,result,message,place)
    if player==P then record("TeleportInitFailed",{Result=tostring(result),Message=tostring(message),DestinationPlaceId=place})end
end)
local queue=queue_on_teleport or queueonteleport or E.queue_on_teleport or E.queueonteleport
if type(queue)~="function"and type(syn)=="table"then queue=syn.queue_on_teleport end
local stamp=game.JobId..":"..tostring(game.PlaceId)
api.QueueInstalled=E.__GeodeTransitionQueuedJob==stamp
if not api.QueueInstalled and type(queue)=="function"then
    local ok,result=pcall(queue,[==[
task.spawn(function()
    if not game:IsLoaded()then game.Loaded:Wait()end
    if game.GameId~=10770110947 then return end
    local e=getgenv()
    if e.__GeodeTransitionBootJob==game.JobId then return end
    local enabledOK,enabled=pcall(readfile,"Geode/transition_enabled.txt")
    if not enabledOK or enabled~="true"then return end
    local ok,source=pcall(readfile,"Geode/transition_recorder.lua")
    if not ok or type(source)~="string"or #source<1000 then
        ok,source=pcall(function()return game:HttpGet("https://raw.githubusercontent.com/sceneton/geode/main/transition-recorder.lua?refresh="..tostring(os.time()))end)
    end
    if not ok or type(source)~="string"or #source<1000 or not source:find("Standalone passive transition observer",1,true)then return end
    local fn=loadstring(source)
    if fn then e.__GeodeTransitionBootJob=game.JobId;e.__GeodeTransitionQueuedArrival=true;fn()end
end)
]==])
    api.QueueInstalled=ok and result~=false
    if api.QueueInstalled then E.__GeodeTransitionQueuedJob=stamp end
end
function api.Stop(reason,keepEnabled)
    if not api.Running then return end
    record("Stopped",{Reason=reason or"Stopped by user"});api.Running=false
    for _,c in ipairs(connections)do c:Disconnect()end
    if not keepEnabled then pcall(writefile,enabledPath,"false")end
end
record("ObserverStarted",{QueuedArrival=api.QueuedArrival,QueueInstalled=api.QueueInstalled,PreviousJobId=old and old.Last and old.Last.State and old.Last.State.JobId})
task.spawn(function()
    while api.Running and E.GeodeTransitionRecorder==api do
        local current=snapshot();local key=H:JSONEncode(current)
        if key~=lastKey then
            local sameJob=lastSnapshot and current.JobId==lastSnapshot.JobId
            record("StateChanged",{SameJobAsPrevious=sameJob,Previous=lastSnapshot,
                RunStartChanged=sameJob and current.RunStart~=lastSnapshot.RunStart or false})
            lastKey=key;lastSnapshot=current
        end
        task.wait(.25)
    end
end)
return api