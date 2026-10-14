-- BeyyHub Ranch native puzzle observer (read-only)
-- Do not run BeyyHub's auto solver during this observation.
-- No mouse input, FireServer calls, remote hooks, or GUI changes.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
local names={"UfoVentMinigame","UfoWireMinigame","UfoAlignMinigame"}
local maxSeconds=180
local interval=0.15
local start=os.clock()
local active=nil
local inputs=0
local connections={}
local seenRemotes={}
local lastGui=nil
local remoteCounts={}
local function log(message)
    print(string.format("[Ranch Native AFK] +%.2fs %s",os.clock()-start,message))
end
local function nameOf(instance)
    local ok,result=pcall(function() return instance:GetFullName() end)
    return ok and result or tostring(instance)
end
local function center(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then return nil end
    local p,s=guiObject.AbsolutePosition,guiObject.AbsoluteSize
    return Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
end
local function posString(v)
    if not v then return "missing" end
    return string.format("%.1f,%.1f",v.X,v.Y)
end
local function activePuzzle()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil,nil end
    for _,name in ipairs(names) do
        local gui=pg:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local panel=gui:FindFirstChild("Panel")
            if panel and panel:IsA("GuiObject") and panel.Visible then
                return name,gui
            end
        end
    end
    return nil,nil
end
local function wireEndpoints(panel)
    local entries={}
    for _,side in ipairs({"Left","Right"}) do
        local group=panel and panel:FindFirstChild(side)
        if group then
            for _,item in ipairs(group:GetChildren()) do
                local color=item:GetAttribute("Wire")
                local tip=item:FindFirstChild("Tip")
                if color and tip and tip:IsA("GuiObject") then
                    entries[#entries+1]=tostring(side)..":"..tostring(color).."@"..posString(center(tip))
                end
            end
        end
    end
    table.sort(entries)
    return table.concat(entries," | ")
end
local function snapshot(name,gui)
    local panel=gui:FindFirstChild("Panel")
    if not panel then return "panel missing" end
    if name=="UfoVentMinigame" then
        local clip=panel:FindFirstChild("Clip")
        local strands=clip and clip:FindFirstChild("Strands")
        local counter=clip and clip:FindFirstChild("Counter")
        local visible=0
        if strands then
            for _,strand in ipairs(strands:GetChildren()) do
                if strand:IsA("GuiObject") and strand.Visible then visible+=1 end
            end
        end
        return string.format("vent visibleStrands=%d counter=%s",visible,
            counter and counter:IsA("TextLabel") and counter.Text or "missing")
    elseif name=="UfoWireMinigame" then
        local lines=panel:FindFirstChild("Lines")
        return string.format("wires linesChildren=%s",lines and tostring(#lines:GetChildren()) or "missing")
    elseif name=="UfoAlignMinigame" then
        local arrow=panel:FindFirstChild("Arrow")
        local track=panel:FindFirstChild("Track")
        return string.format("align arrowCenter=%s trackCenterX=%s trackCenterY=%s radius=%s",
            posString(center(arrow)),
            track and tostring(track:GetAttribute("CenterX")) or "missing",
            track and tostring(track:GetAttribute("CenterY")) or "missing",
            track and tostring(track:GetAttribute("Radius")) or "missing")
    end
    return "unknown puzzle"
end
local function nativeScripts(gui)
    local items={}
    local roots={gui,player:FindFirstChild("PlayerScripts"),
        ReplicatedStorage:FindFirstChild("UfoCrash")}
    for _,root in ipairs(roots) do
        if root then
            for _,child in ipairs(root:GetDescendants()) do
                if child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    local lower=string.lower(child.Name)
                    if root==gui or string.find(lower,"ufo",1,true)
                        or string.find(lower,"puzzle",1,true)
                        or string.find(lower,"vent",1,true)
                        or string.find(lower,"wire",1,true)
                        or string.find(lower,"align",1,true) then
                        items[#items+1]=child.ClassName..":"..nameOf(child)
                        if #items>=30 then break end
                    end
                end
            end
        end
    end
    log("Script candidates (names only; Source is not accessible): "..(#items==0 and "none found" or table.concat(items,"; ")))
end
local function listenRemotes()
    local crash=ReplicatedStorage:FindFirstChild("UfoCrash")
    local remotes=crash and crash:FindFirstChild("Remotes")
    if not remotes then return end
    for _,remote in ipairs(remotes:GetChildren()) do
        if remote:IsA("RemoteEvent") and not seenRemotes[remote] then
            seenRemotes[remote]=true
            local ok,connection=pcall(function()
                return remote.OnClientEvent:Connect(function(...)
                    remoteCounts[remote.Name]=(remoteCounts[remote.Name] or 0)+1
                    if remoteCounts[remote.Name]<=15 then
                        local values={}
                        for i=1,math.min(select("#",...),5) do
                            local a=select(i,...)
                            values[#values+1]=typeof(a)=="Instance" and nameOf(a) or tostring(a)
                        end
                        log("Incoming server event "..remote.Name.." ("..table.concat(values,", ")..")")
                    end
                end)
            end)
            if ok and connection then table.insert(connections,connection) end
        end
    end
end
table.insert(connections,UserInputService.InputBegan:Connect(function(input,processed)
    if active and (input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton2) then
        inputs+=1
        log("Player input observed: "..input.UserInputType.Name..
            " processed="..tostring(processed))
    end
end))
log("PASSIVE OBSERVER STARTED. Open a UFO puzzle and leave it untouched. No solver inputs will be sent.")
local previous=""
while os.clock()-start<maxSeconds do
    listenRemotes()
    local name,gui=activePuzzle()
    if gui~=lastGui then
        if active then
            local elapsed=os.clock()-active.since
            log(string.format("%s CLOSED after %.2fs; playerInputs=%d; lastState=%s",
                active.name,elapsed,inputs,previous))
            log("Closure does NOT prove server completion; verify UFO progression.")
            active=nil
        end
        lastGui=gui
        previous=""
        if gui then
            active={name=name,since=os.clock()}
            inputs=0
            log(name.." OPENED")
            nativeScripts(gui)
            if name=="UfoWireMinigame" then
                log("Native wire tip positions: "..wireEndpoints(gui:FindFirstChild("Panel")))
            end
        end
    end
    if active and gui then
        local current=snapshot(name,gui)
        if current~=previous then
            log(string.format("%s @%.2fs: %s",name,os.clock()-active.since,current))
            previous=current
        end
    end
    task.wait(interval)
end
for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
if active then log(active.name.." still open when observation ended") end
log("OBSERVER FINISHED. Only native GUI state and incoming events were observed.")
