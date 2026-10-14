-- BeyyHub Ranch native puzzle observer (read-only)
-- Do not run BeyyHub's auto solver during this observation.
-- No mouse input, FireServer calls, remote hooks, or GUI changes.
-- Cumulative text report automatically copies to clipboard after each puzzle and on exit.
-- writefile is a backup when the executor exposes it.
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
local sessionConnections={}
local reportLines={}
local function executorFunction(name)
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
    local line=string.format("[Ranch Native AFK] +%.2fs %s",os.clock()-start,message)
    reportLines[#reportLines+1]=line
    print(line)
end
local function publishReport(reason)
    local report=table.concat(reportLines,"\n")
    local write=executorFunction("writefile")
    if write then
        local path="beyyhub-ranch-native-afk-report.txt"
        local ok,err=pcall(write,path,report)
        if ok then
            print("[Ranch Native AFK] Saved cumulative report to "..path)
        else
            warn("[Ranch Native AFK] File save failed: "..tostring(err))
        end
    end
    local clipboard=executorFunction("setclipboard") or executorFunction("toclipboard")
    if clipboard then
        local ok,err=pcall(clipboard,report)
        if ok then
            print("[Ranch Native AFK] Cumulative report copied to clipboard ("..reason.."). Press Ctrl+V to paste.")
        else
            warn("[Ranch Native AFK] Clipboard copy failed: "..tostring(err).."; check report file/console.")
        end
    else
        warn("[Ranch Native AFK] Clipboard API unavailable; use saved report file or console.")
    end
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
local function clearSessionConnections()
    for _,connection in ipairs(sessionConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(sessionConnections)
end
local function observeSignal(signal,callback)
    local ok,connection=pcall(function() return signal:Connect(callback) end)
    if ok and connection then table.insert(sessionConnections,connection) end
end
local function watchNativeGui(name,gui)
    local panel=gui:FindFirstChild("Panel")
    observeSignal(gui:GetPropertyChangedSignal("Enabled"),function()
        log("NATIVE GUI Enabled="..tostring(gui.Enabled))
    end)
    if not panel then return end
    observeSignal(panel:GetPropertyChangedSignal("Visible"),function()
        log("NATIVE Panel Visible="..tostring(panel.Visible))
    end)
    if name=="UfoVentMinigame" then
        local clip=panel:FindFirstChild("Clip")
        local strands=clip and clip:FindFirstChild("Strands")
        local counter=clip and clip:FindFirstChild("Counter")
        if counter and counter:IsA("TextLabel") then
            observeSignal(counter:GetPropertyChangedSignal("Text"),function()
                log("NATIVE VENT counter changed: "..counter.Text)
            end)
        end
        if strands then
            observeSignal(strands.ChildRemoved,function(child)
                log("NATIVE VENT strand removed: "..child.Name)
            end)
            observeSignal(strands.ChildAdded,function(child)
                log("NATIVE VENT strand added: "..child.Name)
            end)
            for _,strand in ipairs(strands:GetChildren()) do
                if strand:IsA("GuiObject") then
                    observeSignal(strand:GetPropertyChangedSignal("Visible"),function()
                        log("NATIVE VENT "..strand.Name.." Visible="..tostring(strand.Visible))
                    end)
                end
            end
        end
    elseif name=="UfoWireMinigame" then
        local lines=panel:FindFirstChild("Lines")
        if lines then
            observeSignal(lines.ChildAdded,function(child)
                log("NATIVE WIRES connection line added: "..child.Name)
            end)
            observeSignal(lines.ChildRemoved,function(child)
                log("NATIVE WIRES connection line removed: "..child.Name)
            end)
        end
    elseif name=="UfoAlignMinigame" then
        local arrow=panel:FindFirstChild("Arrow")
        if arrow and arrow:IsA("GuiObject") then
            local lastLogged=-math.huge
            observeSignal(arrow:GetPropertyChangedSignal("Position"),function()
                if os.clock()-lastLogged>=0.10 then
                    lastLogged=os.clock()
                    log("NATIVE ALIGN arrow moved to "..posString(center(arrow)))
                end
            end)
        end
    end
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
            clearSessionConnections()
            local elapsed=os.clock()-active.since
            log(string.format("%s CLOSED after %.2fs; playerInputs=%d; lastState=%s",
                active.name,elapsed,inputs,previous))
            log("Closure does NOT prove server completion; verify UFO progression.")
            publishReport(active.name.." closed")
            active=nil
        end
        lastGui=gui
        previous=""
        if gui then
            active={name=name,since=os.clock()}
            inputs=0
            log(name.." OPENED")
            nativeScripts(gui)
            watchNativeGui(name,gui)
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
clearSessionConnections()
for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
if active then log(active.name.." still open when observation ended") end
log("OBSERVER FINISHED. Only native GUI state and incoming events were observed.")
publishReport("observer finished")
