-- BeyyHub Ranch native-closure capability diagnostic (passive)
-- Checks whether Solara can inspect native client signal callbacks.
-- DOES NOT call returned callbacks, fire remotes, edit upvalues, or modify GUIs.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local report={}
local function log(s)
    local line="[Ranch Closure Probe] "..tostring(s)
    report[#report+1]=line
    print(line)
end
local function api(name)
    if name=="getconnections" and type(getconnections)=="function" then return getconnections end
    if name=="getupvalues" and type(getupvalues)=="function" then return getupvalues end
    if name=="getupvalue" and type(getupvalue)=="function" then return getupvalue end
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
local debugTable=type(debug)=="table" and debug or {}
local getconnectionsFn=api("getconnections")
local getupvaluesFn=api("getupvalues") or debugTable.getupvalues
local getupvalueFn=api("getupvalue") or debugTable.getupvalue
local infoFn=debugTable.info
log("PASSIVE CAPABILITY TEST START")
log("getconnections="..tostring(type(getconnectionsFn)=="function")
    .." getupvalues="..tostring(type(getupvaluesFn)=="function")
    .." getupvalue="..tostring(type(getupvalueFn)=="function")
    .." debug.info="..tostring(type(infoFn)=="function"))
local root=ReplicatedStorage:FindFirstChild("UfoCrash")
local remotes=root and root:FindFirstChild("Remotes")
if not remotes then
    log("Remotes folder not found. Must execute while in Ranch.")
elseif not getconnectionsFn then
    log("Cannot inspect native callbacks: getconnections is not available.")
else
    for _,name in ipairs({"VentPuzzle","WirePuzzle","AlignPuzzle"}) do
        local obj=remotes:FindFirstChild(name)
        if not obj or not obj:IsA("RemoteEvent") then
            log(name..": RemoteEvent not found")
        else
            local ok,connections=pcall(getconnectionsFn,obj.OnClientEvent)
            if not ok then
                log(name..": getconnections error="..tostring(connections):sub(1,140))
            elseif type(connections)~="table" then
                log(name..": getconnections returned "..type(connections))
            else
                log(name..": "..#connections.." connections visible")
                for i=1,math.min(3,#connections) do
                    local connection=connections[i]
                    local fn
                    local okFn,value=pcall(function()return connection.Function end)
                    if okFn then fn=value end
                    log(name.." connection "..i.." callbackType="..type(fn))
                    if type(fn)=="function" then
                        if type(infoFn)=="function" then
                            local okInfo,source=pcall(infoFn,fn,"sn")
                            if okInfo then
                                log(name.." connection "..i.." debug.info="..tostring(source):sub(1,120))
                            end
                        end
                        if type(getupvaluesFn)=="function" then
                            local okUp,up=pcall(getupvaluesFn,fn)
                            if okUp and type(up)=="table" then
                                local keys={}
                                for k,v in pairs(up) do
                                    if #keys<12 then keys[#keys+1]=tostring(k)..":"..type(v) end
                                end
                                table.sort(keys)
                                log(name.." connection "..i.." upvalues(types only): "..table.concat(keys,", "))
                            else
                                log(name.." connection "..i.." upvalues unreadable: "..tostring(up):sub(1,100))
                            end
                        elseif type(getupvalueFn)=="function" then
                            local okUp,key,value=pcall(getupvalueFn,fn,1)
                            log(name.." connection "..i.." firstUpvalue="..
                                (okUp and (tostring(key)..":"..type(value)) or "unreadable"))
                        end
                    end
                end
            end
        end
    end
end
log("FINISHED. No callbacks, remotes, GUI objects or client variables were modified.")
local result=table.concat(report,"\n")
local write=api("writefile")
if write then
    local ok,err=pcall(write,"beyyhub-ranch-closure-capabilities.txt",result)
    if not ok then warn("[Ranch Closure Probe] Save failed: "..tostring(err)) end
end
local clipboard=api("setclipboard") or api("toclipboard")
if clipboard then
    local ok,err=pcall(clipboard,result)
    if ok then print("[Ranch Closure Probe] Full report copied to clipboard.")
    else warn("[Ranch Closure Probe] Clipboard copy failed: "..tostring(err)) end
else
    warn("[Ranch Closure Probe] No clipboard API; use saved text file or console.")
end
