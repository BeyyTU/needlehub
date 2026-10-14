-- BeyyHub Ranch client bytecode exporter (read-only).
-- Exports exactly three puzzle LocalScripts to ONE local Base64 text file.
-- Does not call puzzle remotes, simulate input, or alter gameplay.
-- The bytecode is NOT uploaded to GitHub by this script.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local scriptFolder = player:WaitForChild("PlayerScripts", 10)
local names = {"UfoVentClient", "UfoWireClient", "UfoAlignClient"}
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local filename = "beyyhub-ranch-native-bytecode-bundle.txt"
local lines = {"BEYYHUB_RANCH_BYTECODE_BUNDLE_V1"}
local summary = {"[Ranch Bytecode Export] Complete native bytecode bundle diagnostic"}
local function add(message)
    summary[#summary+1] = "[Ranch Bytecode Export] " .. tostring(message)
    print(summary[#summary])
end
local function api(name)
    if name=="getscriptbytecode" and type(getscriptbytecode)=="function" then return getscriptbytecode end
    if name=="writefile" and type(writefile)=="function" then return writefile end
    if name=="readfile" and type(readfile)=="function" then return readfile end
    if name=="setclipboard" and type(setclipboard)=="function" then return setclipboard end
    if name=="toclipboard" and type(toclipboard)=="function" then return toclipboard end
    local global=rawget(_G,name)
    if type(global)=="function" then return global end
    if type(getgenv)=="function" then
        local ok,env=pcall(getgenv)
        if ok and type(env)=="table" and type(rawget(env,name))=="function" then
            return rawget(env,name)
        end
    end
    return nil
end
local function encode64(s)
    local chunks, count = {}, 0
    for i=1,#s,3 do
        local a,b,c = s:byte(i,i+2)
        local value = a*65536+(b or 0)*256+(c or 0)
        local i1 = math.floor(value/262144)%64+1
        local i2 = math.floor(value/4096)%64+1
        local i3 = math.floor(value/64)%64+1
        local i4 = value%64+1
        count+=1
        chunks[count]=alphabet:sub(i1,i1)..alphabet:sub(i2,i2)..
            (b and alphabet:sub(i3,i3) or "=")..
            (c and alphabet:sub(i4,i4) or "=")
    end
    return table.concat(chunks)
end
add("Checking Solara getscriptbytecode and local writefile...")
local getBytecode = api("getscriptbytecode")
if not scriptFolder then
    add("FAILED: PlayerScripts not present")
elseif not getBytecode then
    add("FAILED: getscriptbytecode unavailable")
else
    local added = 0
    for _,name in ipairs(names) do
        local scriptObject=scriptFolder:FindFirstChild(name,true)
        if not scriptObject or not scriptObject:IsA("LocalScript") then
            add(name.." NOT FOUND")
        else
            local ok,bytes=pcall(getBytecode,scriptObject)
            if ok and type(bytes)=="string" and #bytes>100 then
                local b64=encode64(bytes)
                lines[#lines+1]="BEGIN_SCRIPT "..name.." "..#bytes.." "..#b64
                lines[#lines+1]=b64
                lines[#lines+1]="END_SCRIPT "..name
                added+=1
                add(name..": "..#bytes.." bytecode bytes, base64="..#b64.." chars")
            else
                add(name.." FAILED: "..(ok and "bytecode unavailable/empty" or tostring(bytes)))
            end
        end
    end
    if added>0 then
        lines[#lines+1]="END_BUNDLE"
        local bundle=table.concat(lines,"\n").."\n"
        local write=api("writefile")
        local saved=false
        if write then
            local ok,err=pcall(write,filename,bundle)
            if ok then
                saved=true
                add("SAVED "..filename.." ("..#bundle.." characters)")
                local read=api("readfile")
                if read then
                    local check,actual=pcall(read,filename)
                    add(check and type(actual)=="string" and #actual==#bundle
                        and "Read-back verified complete" or "Read-back not confirmed; please inspect saved file")
                end
            else
                add("SAVE FAILED: "..tostring(err))
            end
        else
            add("writefile unavailable")
        end
        add("Exported "..added.."/3 puzzle clients. No gameplay interaction performed.")
        if saved then
            add("Upload the saved .txt file to ChatGPT; the clipboard contains the small summary.")
        else
            add("File save unavailable; attempting full Base64 bundle on clipboard as fallback.")
        end
        local clipboard=api("setclipboard") or api("toclipboard")
        if clipboard then
            local payload=saved and table.concat(summary,"\n") or bundle
            local ok,err=pcall(clipboard,payload)
            if ok then
                print("[Ranch Bytecode Export] Copied "..(saved and "summary" or "bundle").." to clipboard.")
            else
                warn("[Ranch Bytecode Export] Clipboard copy failed: "..tostring(err))
            end
        else
            add("No clipboard API available.")
        end
    else
        add("No readable puzzle client bytecode; no bundle created.")
    end
end
