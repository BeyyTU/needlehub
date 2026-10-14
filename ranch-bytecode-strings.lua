-- BeyyHub Ranch bytecode string-table diagnostic (read only)
-- Does not modify puzzle state, inspect live function closures or call remotes.
-- Extracts indexed string literals from the three native client bytecodes.
-- Auto-copies concise results; optionally saves full strings to a text file.

local Players=game:GetService("Players")
local player=Players.LocalPlayer
local scripts=player:WaitForChild("PlayerScripts",10)
local names={"UfoVentClient","UfoWireClient","UfoAlignClient"}
local function api(name)
    if name=="getscriptbytecode" and type(getscriptbytecode)=="function" then return getscriptbytecode end
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
local brief={"BeyyHub Ranch native bytecode strings | v1"}
local full={"BeyyHub Ranch complete native bytecode string tables | v1"}
local function add(s)
    brief[#brief+1]=s
    print("[Ranch Bytecode] "..s)
end
local function addFull(s)
    full[#full+1]=s
end
local function readVarint(data,index)
    local number,shift=0,0
    for _=1,5 do
        local b=data:byte(index)
        if not b then return nil,index,"Unexpected end of bytecode" end
        index+=1
        number+=(b%128)*(2^shift)
        if b<128 then return number,index end
        shift+=7
    end
    return nil,index,"Invalid variable-length integer"
end
local function stringTable(data)
    if type(data)~="string" or #data<4 then return nil,"Missing bytecode header" end
    local version=data:byte(1)
    local typesVersion=data:byte(2)
    if version<4 or version>30 then
        return nil,"Unexpected Luau bytecode version "..tostring(version)
    end
    local index=3
    local count,err
    count,index,err=readVarint(data,index)
    if not count then return nil,err end
    if count>8000 then return nil,"Implausibly large string table: "..count end
    local strings={}
    for i=1,count do
        local size
        size,index,err=readVarint(data,index)
        if not size then return nil,"String #"..i..": "..err end
        if size>65536 or index+size-1>#data then
            return nil,"String #"..i..": length out of bounds"
        end
        strings[i]=data:sub(index,index+size-1)
        index+=size
    end
    return {version=version,typesVersion=typesVersion,count=count,strings=strings,afterTable=index}
end
local keywords={
    "auto","idle","afk","complete","done","finish","task","wait",
    "delay","timer","time","vent","wire","align","puzzle","stran",
    "grab","pull","line","connect","arrow","angle","center","radius",
    "remote","server","fire","success","target","threshold","counter",
    "click","mouse","touch","input","tween","anim","progress","solv",
    "state","return","part","distance","lock","move"
}
local function interesting(str)
    local lower=string.lower(str)
    for _,term in ipairs(keywords) do
        if string.find(lower,term,1,true) then return true end
    end
    return false
end
local function printable(s)
    local out={}
    for i=1,math.min(#s,180) do
        local code=s:byte(i)
        if code>=32 and code<=126 and code~=92 then
            out[#out+1]=string.char(code)
        elseif code==92 then out[#out+1]="\\"
        elseif code==10 then out[#out+1]="\\n"
        elseif code==13 then out[#out+1]="\\r"
        else out[#out+1]=string.format("\\x%02X",code) end
    end
    if #s>180 then out[#out+1]="... [truncated]" end
    return table.concat(out)
end
local bytecodeFn=api("getscriptbytecode")
if not scripts then
    add("PlayerScripts unavailable; cannot continue.")
elseif not bytecodeFn then
    add("getscriptbytecode unavailable in this executor.")
else
    for _,name in ipairs(names) do
        add("---- "..name.." ----")
        local obj=scripts:FindFirstChild(name,true)
        if not obj or not obj:IsA("LocalScript") then
            add("Not found or not a LocalScript.")
        else
            local ok,blob=pcall(bytecodeFn,obj)
            if not ok then
                add("getscriptbytecode error: "..tostring(blob):sub(1,180))
            elseif type(blob)~="string" then
                add("Unexpected bytecode result type: "..type(blob))
            else
                local decoded,err=stringTable(blob)
                if not decoded then
                    add("Cannot parse string table ("..#blob.." bytes): "..err)
                else
                    add(string.format("bytecode=%d bytes | Luau version=%d types=%d | strings=%d",
                        #blob,decoded.version,decoded.typesVersion,decoded.count))
                    local selected={}
                    for i,value in ipairs(decoded.strings) do
                        addFull(string.format("%s [%03d] %s",name,i,printable(value)))
                        if interesting(value) then
                            for j=math.max(1,i-1),math.min(decoded.count,i+1) do
                                selected[j]=true
                            end
                        end
                    end
                    local shown,total=0,0
                    for i=1,decoded.count do
                        if selected[i] then
                            total+=1
                            if shown<150 then
                                shown+=1
                                add(string.format("[%03d] %s",i,printable(decoded.strings[i])))
                            end
                        end
                    end
                    add(string.format("Relevant/context strings=%d | copied=%d; full table in saved report when writefile works",
                        total,shown))
                end
            end
        end
    end
end
add("Finished; this reveals script symbols, not native function bodies or remote arguments.")
local write=api("writefile")
if write then
    local attempts={
        {"beyyhub-ranch-bytecode-summary.txt",table.concat(brief,"\n")},
        {"beyyhub-ranch-bytecode-all-strings.txt",table.concat(full,"\n")}
    }
    for _,entry in ipairs(attempts) do
        local ok,err=pcall(write,entry[1],entry[2])
        if ok then print("[Ranch Bytecode] Saved "..entry[1])
        else warn("[Ranch Bytecode] Could not save "..entry[1]..": "..tostring(err)) end
    end
end
local clipboard=api("setclipboard") or api("toclipboard")
if clipboard then
    local ok,err=pcall(clipboard,table.concat(brief,"\n"))
    if ok then print("[Ranch Bytecode] Summary copied to clipboard. Paste it directly in ChatGPT.")
    else warn("[Ranch Bytecode] Clipboard failed: "..tostring(err)) end
else
    warn("[Ranch Bytecode] Clipboard API unavailable; use text file backups or console.")
end
