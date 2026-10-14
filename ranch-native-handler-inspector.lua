-- BeyyHub Ranch native handler inspection (separate, read-only diagnostic)
-- Run in Ranch after the UFO puzzle clients have loaded.
-- No clicks, no remote submissions, no monkey-patching, no game state writes.
-- Only queries the named LocalScripts and optional executor inspection APIs.
-- Copies its full report to clipboard automatically when available.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts", 8)
if not scripts then
    warn("[Ranch Handler] PlayerScripts unavailable; report will still be exported")
end

local function available(name)
    if name == "setclipboard" and type(setclipboard) == "function" then return setclipboard end
    if name == "toclipboard" and type(toclipboard) == "function" then return toclipboard end
    if name == "writefile" and type(writefile) == "function" then return writefile end
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
record("This checks whether the executor returns real Luau source or bytecode; API presence alone is not proof of support.")

local seen = {}
for _,name in ipairs(allNames) do
    local scriptObject = scripts and scripts:FindFirstChild(name, true)
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
                -- A 31-byte return is often an executor placeholder, not Luau.
                -- Show the exact short response so we can distinguish support
                -- messages from real decompiled code without guessing.
                if #source <= 200 then
                    local preview=source:gsub("[%c]",function(char)
                        if char=="\\n" then return "\\n" end
                        if char=="\\r" then return "\\r" end
                        return string.format("\\x%02X",string.byte(char))
                    end)
                    record(name.." decompiler raw response: "..preview)
                end
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
        -- Read-only capability probe: this is just bytecode metadata.
        -- Do not place arbitrary binary into the clipboard or reports.
        if getscriptbytecode then
            local ok, data=pcall(getscriptbytecode,scriptObject)
            if not ok then
                record(name.." getscriptbytecode error: "..tostring(data):sub(1,200))
            elseif type(data)=="string" then
                local first={}
                for i=1,math.min(8,#data) do
                    first[#first+1]=string.format("%02X",string.byte(data,i))
                end
                record(name.." bytecode probe: bytes="..#data..
                    " prefixHex="..table.concat(first," ")..
                    " (metadata only; contents not exported)")
            else
                record(name.." getscriptbytecode returned "..type(data))
            end
        else
            record(name.." getscriptbytecode API unavailable")
        end
    else
        record(name.." not found as a LocalScript (possibly not loaded yet)")
    end
end

record("FINISHED. No native game functions or puzzle remotes were called.")
local path = "beyyhub-ranch-native-handler-report.txt"
local write = available("writefile")
if write then
    local ok, err = pcall(write, path, table.concat(output, "\n"))
    record(ok and ("Saved report using executor writefile: "..path)
        or ("Report file write failed: "..tostring(err)))
else
    record("No writefile API; clipboard and console are the available report channels")
end

local clipboard = available("setclipboard") or available("toclipboard")
if clipboard then
    local ok, err = pcall(clipboard, table.concat(output, "\n"))
    if ok then
        print("[Ranch Handler] Full report copied to clipboard. Press Ctrl+V to paste.")
    else
        warn("[Ranch Handler] Clipboard copy failed: "..tostring(err).."; check file/console.")
    end
else
    warn("[Ranch Handler] Clipboard API unavailable; use report file or console.")
end
