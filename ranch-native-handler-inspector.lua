-- BeyyHub Ranch native handler inspection (separate, read-only diagnostic)
-- Run in Ranch after the UFO puzzle clients have loaded.
-- No clicks, no remote submissions, no monkey-patching, no game state writes.
-- Only queries the named LocalScripts and optional executor inspection APIs.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts", 8)
if not scripts then
    warn("[Ranch Handler] PlayerScripts unavailable")
    return
end

local function available(name)
    local value = rawget(_G, name)
    if type(value) == "function" then return value end
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            value = rawget(env, name)
            if type(value) == "function" then return value end
        end
    end
    return nil
end

local decompiler = available("decompile")
local getsenvFunction = available("getsenv")
local getscriptbytecode = available("getscriptbytecode")
local getgcFunction = available("getgc")
local debugGetConstants = available("getconstants")
local allNames = {
    "UfoVentClient", "UfoWireClient", "UfoAlignClient",
    "UfoPartsClient", "UfoEventClient",
}
local terms = {
    "auto", "idle", "timeout", "delay", "task.wait", "task.delay",
    "puzzledone", "ventpuzzle", "wirepuzzle", "alignpuzzle",
    "fir eserver", "fireserver", "tween", "complete", "solve", "counter",
    "connection", "timer", "clock", "20", "10", "15",
}
local output = {}
local function record(line)
    local message = tostring(line)
    table.insert(output, message)
    print("[Ranch Handler] "..message)
end
record("READ-ONLY INSPECTION START | decompile="..tostring(decompiler~=nil)
    .." getsenv="..tostring(getsenvFunction~=nil)
    .." getscriptbytecode="..tostring(getscriptbytecode~=nil)
    .." getgc="..tostring(getgcFunction~=nil)
    .." getconstants="..tostring(debugGetConstants~=nil))
record("Source is protected by Roblox. A complete native handler can only be inspected if your executor supports safe script inspection.")

local seen = {}
for _,name in ipairs(allNames) do
    local scriptObject = scripts:FindFirstChild(name, true)
    if scriptObject and scriptObject:IsA("LocalScript") and not seen[scriptObject] then
        seen[scriptObject] = true
        record(name.." FOUND ("..scriptObject:GetFullName()..")")
        local okAttrs, attrs = pcall(function() return scriptObject:GetAttributes() end)
        if okAttrs then
            local attributeSummary = {}
            for key,value in pairs(attrs) do
                table.insert(attributeSummary, tostring(key).."="..tostring(value))
            end
            table.sort(attributeSummary)
            record(name.." attributes: "..(#attributeSummary>0 and table.concat(attributeSummary,", ") or "none"))
        end
        if getsenvFunction then
            local ok, env = pcall(getsenvFunction, scriptObject)
            if ok and type(env) == "table" then
                local exposed = {}
                for key,value in pairs(env) do
                    if type(key) == "string" and (type(value) == "function" or
                        string.find(string.lower(key),"puzzle",1,true) or
                        string.find(string.lower(key),"auto",1,true) or
                        string.find(string.lower(key),"vent",1,true)) then
                        exposed[#exposed+1] = key..":"..type(value)
                    end
                end
                table.sort(exposed)
                record(name.." visible script-env keys: "..
                    (#exposed>0 and table.concat(exposed,", ",1,math.min(#exposed,35)) or "none"))
            else
                record(name.." getsenv unavailable for this script")
            end
        end
        if decompiler then
            local ok, source = pcall(decompiler, scriptObject)
            if not ok then
                record(name.." decompile error: "..tostring(source):sub(1,200))
            elseif type(source) ~= "string" or #source == 0 then
                record(name.." decompile returned no text")
            else
                record(name.." decompiled text available; bytes="..#source)
                local hits, total, lineNumber = 0, 0, 0
                for line in (source.."\n"):gmatch("(.-)\n") do
                    lineNumber += 1
                    local lower = string.lower(line)
                    local matched = false
                    for _,term in ipairs(terms) do
                        if string.find(lower,term,1,true) then
                            matched = true
                            break
                        end
                    end
                    if matched then
                        total += 1
                        if hits < 30 then
                            hits += 1
                            record(name.." L"..lineNumber..": "..line:sub(1,230))
                        end
                    end
                end
                record(name.." relevant source lines="..total.."; displayed="..hits..
                    " (no complete game-source dump)")
            end
        else
            record(name.." cannot inspect handler logic because decompile is unavailable")
        end
    else
        record(name.." not found as a LocalScript (possibly not loaded yet)")
    end
end

local write = available("writefile")
if write then
    local path = "beyyhub-ranch-native-handler-report.txt"
    local ok, err = pcall(write, path, table.concat(output, "\n"))
    record(ok and ("Saved report using executor writefile: "..path)
        or ("Report file write failed: "..tostring(err)))
else
    record("No writefile API; copy console lines beginning [Ranch Handler]")
end
record("FINISHED. No native game functions or puzzle remotes were called.")
