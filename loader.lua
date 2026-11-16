-- BeyyHub v103.00 | direct-branch loader with AFK replay recovery
-- CH1_TNT_SPAWN_GATE_LOADER_V4 | rejects stale Chapter 1 TNT modules
-- Resolves the current revision and keeps validated AFK recovery caches.
local VERSION = "103.00"
local BASE = "https://raw.githubusercontent.com/BeyyTU/needlehub/main/"
-- Known-good immutable source contains the eight-second Chapter 1 TNT gate.
local CH1_SAFE_COMMIT = "36d51d0df9803669174c247432fc3e27a25825b2"
local CH1_SAFE_BLOB = "3a0aa23fc05dae035048cb874f885a48639c6d3a"
local MODULES = {
    [77108422251420] = {file="lobby.lua", name="Lobby"},
    [108628039999641] = {file="chapter1.lua", name="Chapter1"},
    [83445806734780] = {file="chapter2.lua", name="Chapter2"},
    [82626725163709] = {file="chapter3.lua", name="Chapter3"},
    [102537610748607] = {file="chapter4.lua", name="Chapter4"},
    [85675194070288] = {file="chapter5.lua", name="Chapter5"},
    [87963815262778] = {file="winter.lua", name="Winter"},
}
local target = MODULES[game.PlaceId]
if not target then
    warn("[BeyyHub] Unsupported PlaceId: " .. tostring(game.PlaceId))
    return
end

local CACHE_FOLDER = "BeyyHub"
local LOADER_CACHE = CACHE_FOLDER.."/afk_replay_loader_v103.lua"
local moduleCache = (target.name=="Chapter1" or target.name=="Lobby" or target.name=="Chapter5" or target.name=="Winter")
    and (CACHE_FOLDER.."/afk_replay_module_v103_"..target.name..".lua") or nil
pcall(function()
    if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder(CACHE_FOLDER)) then makefolder(CACHE_FOLDER) end
end)
local function validRevision(value)
    return type(value)=="string" and #value==40 and value:match("^%x+$")~=nil
end
local selectedRevision=...
if not validRevision(selectedRevision) then
    local ok,info=pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(
            "https://api.github.com/repos/BeyyTU/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
    end)
    selectedRevision=ok and type(info)=="table" and info.sha or nil
end
local revisionPath=CACHE_FOLDER.."/afk_replay_revision_v103.txt"
if validRevision(selectedRevision) then
    if type(writefile)=="function" then pcall(writefile,revisionPath,selectedRevision) end
elseif type(readfile)=="function" then
    local ok,value=pcall(readfile,revisionPath)
    selectedRevision=ok and validRevision(value) and value or nil
end
local DOWNLOAD_BASE=validRevision(selectedRevision)
    and ("https://raw.githubusercontent.com/BeyyTU/needlehub/"..selectedRevision.."/") or BASE
-- Chapter 1 fixes must not be pinned indefinitely to a previous replay
-- revision when the revision lookup failed. Prefer current main for Chapter 1;
-- keep the pinned revision and validated module cache as offline fallbacks.
local PRIMARY_BASE=(target.name=="Chapter1" or target.name=="Chapter5" or target.name=="Winter")
    and BASE or DOWNLOAD_BASE
local begin = os.clock()
local requests, compileSeconds = 0, 0
local lastModuleFailure = nil
local function fetch(url)
    requests += 1
    local sep=url:find("?",1,true) and "&" or "?"
    return game:HttpGet(url .. sep .. "refresh=" .. tostring(os.time()) .. "-" ..
        tostring(math.random(1,1000000000)))
end
-- GitHub's API returns the file as base64 JSON. Decode it ourselves to
-- avoid depending on executor-specific base64 functions.
local CH1_B64_ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local CH1_B64={}
for i=1,#CH1_B64_ALPHABET do
    CH1_B64[CH1_B64_ALPHABET:sub(i,i)]=i-1
end
local function decodeCh1Base64(s)
    if type(s)~="string" then return nil end
    s=s:gsub("%s+","")
    if #s==0 or #s%4~=0 then return nil end
    local out={}
    for i=1,#s,4 do
        local a,b,c,d=s:sub(i,i),s:sub(i+1,i+1),s:sub(i+2,i+2),s:sub(i+3,i+3)
        local x,y=CH1_B64[a],CH1_B64[b]
        local z,w=c=="=" and 0 or CH1_B64[c],d=="=" and 0 or CH1_B64[d]
        if x==nil or y==nil or z==nil or w==nil then return nil end
        local n=x*262144+y*4096+z*64+w
        local byte1=math.floor(n/65536)%256
        if c=="=" then
            out[#out+1]=string.char(byte1)
        elseif d=="=" then
            out[#out+1]=string.char(byte1,math.floor(n/256)%256)
        else
            out[#out+1]=string.char(byte1,math.floor(n/256)%256,n%256)
        end
    end
    return table.concat(out)
end
local function fetchCh1Api(url)
    local body=fetch(url)
    local ok,json=pcall(function()return game:GetService("HttpService"):JSONDecode(body)end)
    if not ok or type(json)~="table" then
        error("GitHub API JSON unavailable: "..tostring(body):sub(1,90))
    end
    if json.encoding~="base64" or type(json.content)~="string" then
        error("GitHub API returned "..tostring(json.message or json.encoding))
    end
    local source=decodeCh1Base64(json.content)
    if not source then error("GitHub API base64 could not be decoded") end
    return source,json.sha
end
local function validate(source)
    if type(source) ~= "string" or #source < 1500 then
        lastModuleFailure = "download returned incomplete source"
        return nil
    end
    if not source:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true)
        or not source:find('local __BEYY_MODULE = "' .. target.name .. '"', 1, true) then
        lastModuleFailure = "downloaded module failed version/chapter signature"
        return nil
    end
    if target.name=="Chapter1" and not source:find("createReplayRecovery",1,true) then
        lastModuleFailure = "Chapter1 replay recovery marker missing"
        return nil
    end
    if target.name=="Chapter1" and not source:find("CH1_TNT_SPAWN_GATE_V2",1,true) then
        lastModuleFailure = "Chapter1 8-second spawn TNT gate missing; rejecting stale/cached module"
        return nil
    end
    local started = os.clock()
    local ok, fn, compileError = pcall(loadstring, source)
    compileSeconds += os.clock() - started
    if not ok or type(fn) ~= "function" then
        lastModuleFailure = "compile error: "..tostring(ok and compileError or fn)
        return nil
    end
    lastModuleFailure = nil
    return fn
end

local fn
for attempt = 1, 3 do
    local ok, source = pcall(fetch, PRIMARY_BASE .. target.file)
    if ok then
        if target.name=="Chapter1" then
            print("[BeyyHub Ch1 Loader] raw main attempt "..attempt..
                " bytes="..#source.." has8secondGate="..
                tostring(source:find("CH1_TNT_SPAWN_GATE_V2",1,true)~=nil))
        end
        fn = validate(source)
        if fn then
            if moduleCache and type(writefile)=="function" then pcall(writefile,moduleCache,source) end
            break
        end
    else
        lastModuleFailure = "download error: "..tostring(source)
    end
    if attempt < 3 then task.wait(0.25 * attempt) end
end
-- Raw GitHub responses can contain an older module despite cache busting.
-- Use the separate GitHub API to get content from main, then an immutable
-- blob (exactly the checked version) before trying raw revision fallbacks.
if not fn and target.name=="Chapter1" then
    local apiPaths={
        {name="GitHub contents main",
         url="https://api.github.com/repos/BeyyTU/needlehub/contents/chapter1.lua?ref=main"},
        {name="GitHub immutable blob",
         url="https://api.github.com/repos/BeyyTU/needlehub/git/blobs/"..CH1_SAFE_BLOB,
         sha=CH1_SAFE_BLOB},
    }
    for _,entry in ipairs(apiPaths) do
        local ok,source,actualSha=pcall(fetchCh1Api,entry.url)
        if ok and entry.sha and actualSha~=entry.sha then
            ok=false
            source="blob SHA mismatch: "..tostring(actualSha)
        end
        if ok then
            print("[BeyyHub Ch1 Loader] "..entry.name.." bytes="..#source..
                " has8secondGate="..
                tostring(source:find("CH1_TNT_SPAWN_GATE_V2",1,true)~=nil)..
                " sha="..tostring(actualSha))
            fn=validate(source)
            if fn then
                print("[BeyyHub Ch1 Loader] Verified Chapter 1 source: "..entry.name)
                if moduleCache and type(writefile)=="function" then
                    pcall(writefile,moduleCache,source)
                end
                break
            end
        else
            warn("[BeyyHub Ch1 Loader] "..entry.name.." error: "..tostring(source))
            lastModuleFailure=entry.name..": "..tostring(source)
        end
    end
end
if not fn and target.name=="Chapter1" then
    local url="https://cdn.jsdelivr.net/gh/BeyyTU/needlehub@"..CH1_SAFE_COMMIT.."/chapter1.lua"
    local ok,source=pcall(fetch,url)
    if ok then
        print("[BeyyHub Ch1 Loader] jsDelivr bytes="..#source..
            " has8secondGate="..
            tostring(source:find("CH1_TNT_SPAWN_GATE_V2",1,true)~=nil))
        fn=validate(source)
        if fn and moduleCache and type(writefile)=="function" then
            pcall(writefile,moduleCache,source)
        end
    else
        warn("[BeyyHub Ch1 Loader] jsDelivr failed: "..tostring(source))
    end
end
-- main may serve stale branch content even with randomized cache-busters.
-- A verified immutable revision cannot silently resolve to an old Chapter 1.
if not fn and target.name=="Chapter1" then
    local safeUrl="https://raw.githubusercontent.com/BeyyTU/needlehub/"..CH1_SAFE_COMMIT.."/"..target.file
    for attempt=1,3 do
        local ok,source=pcall(fetch,safeUrl)
        if ok then
            fn=validate(source)
            if fn then
                print("[BeyyHub] Chapter 1 loaded verified 8-second TNT fix: "..CH1_SAFE_COMMIT)
                if moduleCache and type(writefile)=="function" then
                    pcall(writefile,moduleCache,source)
                end
                break
            end
        else
            lastModuleFailure="verified Chapter1 commit download error: "..tostring(source)
        end
        if attempt<3 then task.wait(0.35*attempt) end
    end
end
if not fn and (target.name=="Chapter1" or target.name=="Chapter5" or target.name=="Winter")
    and DOWNLOAD_BASE~=PRIMARY_BASE then
    -- Fresh main may be temporarily unavailable. Try the known revision
    -- before the local AFK cache, retaining existing recovery behavior.
    local ok,source=pcall(fetch,DOWNLOAD_BASE..target.file)
    if ok then
        fn=validate(source)
        if fn and moduleCache and type(writefile)=="function" then
            pcall(writefile,moduleCache,source)
        end
    else
        lastModuleFailure="pinned revision download error: "..tostring(source)
    end
end
if not fn and moduleCache and type(readfile)=="function" then
    local fallbackReason=lastModuleFailure
    local ok,cached=pcall(readfile,moduleCache)
    if ok then
        fn=validate(cached)
        if fn then
            warn("[BeyyHub] Online AFK module unavailable; using last validated recovery cache."..
                " Latest download/compile failure: "..tostring(fallbackReason or "unknown"))
        end
    end
end
if not fn then
    warn("[BeyyHub] Could not download/compile " .. target.name ..
        " or validate its AFK recovery cache. Last reason: " ..
        tostring(lastModuleFailure or "unknown"))
    return
end

-- Warm the lobby backup once so a Chapter 1 watchdog can restart during an outage.
if target.name=="Chapter1" and type(writefile)=="function" then
    local path=CACHE_FOLDER.."/afk_replay_module_v103_Lobby.lua"
    local function validLobby(value)
        return type(value)=="string" and #value>=1500
            and value:find('local __BEYY_SCRIPT_VERSION = "'..VERSION..'"',1,true)
            and value:find('local __BEYY_MODULE = "Lobby"',1,true) and loadstring(value)
    end
    local cached
    if type(readfile)=="function" then local ok,value=pcall(readfile,path);if ok then cached=value end end
    if not validLobby(cached) then
        local ok,value=pcall(fetch,DOWNLOAD_BASE.."lobby.lua")
        if ok and validLobby(value) then pcall(writefile,path,value) end
    end
end

-- Keep a validated first-party router for queued reloads during a download outage.
if type(writefile)=="function" then
    local cached
    if type(readfile)=="function" then local ok,value=pcall(readfile,LOADER_CACHE);if ok then cached=value end end
    local validCache=type(cached)=="string" and cached:find("afk_replay_loader_v103.lua",1,true)
        and cached:find("CH1_TNT_SPAWN_GATE_LOADER_V4",1,true)
        and cached:find('local VERSION = "'..VERSION..'"',1,true) and loadstring(cached)
    if not validCache then
        local ok,value=pcall(fetch,DOWNLOAD_BASE.."loader.lua")
        if ok and type(value)=="string" and value:find("afk_replay_loader_v103.lua",1,true)
            and value:find("CH1_TNT_SPAWN_GATE_LOADER_V4",1,true)
            and value:find('local VERSION = "'..VERSION..'"',1,true) and loadstring(value) then
            pcall(writefile,LOADER_CACHE,value)
        end
    end
end

local env = _G
if type(getgenv) == "function" then
    local ok, candidate = pcall(getgenv)
    if ok and type(candidate) == "table" then env = candidate end
end
local queue = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(env.queue_on_teleport) == "function" and env.queue_on_teleport)
    or (type(env.queueonteleport) == "function" and env.queueonteleport)
    or (type(env.queue_on_tp) == "function" and env.queue_on_tp)
if queue and _G.__BEYY_NEEDLEHUB_RELOAD_JOB~=game.JobId then
    local payload = [==[
        local H=game:GetService("HttpService")
        local revision
        local resolved,info=pcall(function()
            return H:JSONDecode(game:HttpGet("https://api.github.com/repos/BeyyTU/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
        end)
        if resolved and type(info)=="table" and type(info.sha)=="string" and #info.sha==40 and info.sha:match("^%x+$") then revision=info.sha end
        local url="https://raw.githubusercontent.com/BeyyTU/needlehub/"..(revision or "main").."/loader.lua"
        local body
        for attempt=1,3 do
            local ok,source=pcall(function()
                return game:HttpGet(url.."?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000)))
            end)
            if ok and type(source)=="string" and source:find('local VERSION = "103.00"',1,true)
                and source:find("afk_replay_loader_v103.lua",1,true)
                and source:find("CH1_TNT_SPAWN_GATE_LOADER_V4",1,true)
                and loadstring(source) then body=source;break end
            if attempt<3 then task.wait(attempt*0.5) end
        end
        if not body and type(readfile)=="function" then
            local ok,cached=pcall(readfile,"BeyyHub/afk_replay_loader_v103.lua")
            if ok and type(cached)=="string" and cached:find('local VERSION = "103.00"',1,true)
                and cached:find("afk_replay_loader_v103.lua",1,true)
                and cached:find("CH1_TNT_SPAWN_GATE_LOADER_V4",1,true)
                and loadstring(cached) then body=cached end
        end
        if not body then warn("[BeyyHub] No validated online or cached AFK router; reattach and rerun the loader");return end
        if type(writefile)=="function" then pcall(writefile,"BeyyHub/afk_replay_loader_v103.lua",body) end
        local compiled,compileError=loadstring(body)
        if not compiled then warn("[BeyyHub] Teleport loader compile error: "..tostring(compileError));return end
        local succeeded,runtimeError=pcall(compiled,revision)
        if not succeeded then warn("[BeyyHub] Teleport loader error: "..tostring(runtimeError)) end
    ]==]
    local ok, err = pcall(queue, payload)
    if ok then _G.__BEYY_NEEDLEHUB_RELOAD_JOB=game.JobId
    else warn("[BeyyHub] Teleport queue failed: " .. tostring(err)) end
elseif queue then
    print("[BeyyHub] Teleport reload already armed for this session")
else
    warn("[BeyyHub] queue_on_teleport unavailable; rerun after changing chapters")
end

print(string.format("[BeyyHub Fast Startup] %s source=revision-or-cache requests=%d compile=%.3fs loader=%.2fs",
    target.name, requests, compileSeconds, os.clock() - begin))
local moduleBegin = os.clock()
local ok, err = pcall(fn)
if not ok then warn("[BeyyHub] " .. target.name .. " error: " .. tostring(err)) end
print(string.format("[BeyyHub Fast Startup] %s module returned after %.2fs (module=%.2fs)",
    target.name, os.clock() - begin, os.clock() - moduleBegin))
