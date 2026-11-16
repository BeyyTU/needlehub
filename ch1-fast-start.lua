-- BeyyHub Chapter 1 Fast Start | cached three-second TNT release
-- FAST_CH1_TNT3_R2: no commit API, no main-branch revision checks.
-- First launch fetches the release once; later launches read a validated local cache.
if game.PlaceId ~= 108628039999641 then
    warn("[BeyyHub Fast Ch1] This launcher is only for Chapter 1.")
    return
end

local started=os.clock()
local CACHE_DIR="BeyyHub"
local CACHE_PATH=CACHE_DIR.."/chapter1_tnt3_fast_release_r2.lua"
local RELEASE_SHA="9fc71e6fa420e434457b57541e62a0c9441f13f0"
local FILE="chapter1-tnt3-20261116.lua"
local MARKER="CH1_TNT3_FRESH_20261116"
local GATE="CH1_TNT_SPAWN_GATE_V3"
local SOURCE_URLS={
    "https://raw.githubusercontent.com/BeyyTU/needlehub/"..RELEASE_SHA.."/"..FILE,
    "https://cdn.jsdelivr.net/gh/BeyyTU/needlehub@"..RELEASE_SHA.."/"..FILE,
}
local function valid(body)
    return type(body)=="string"
        and #body>200000
        and body:find(MARKER,1,true)~=nil
        and body:find(GATE,1,true)~=nil
        and body:find("CH1_REGISTER_SCOPED_ARCADE_20261115",1,true)~=nil
        and body:find('local __BEYY_MODULE = "Chapter1"',1,true)~=nil
        and body:find("firstHayWaitUntil=now+3",1,true)~=nil
end
local function compile(body)
    if not valid(body) then return nil,"source failed release validation" end
    local ok,fn=pcall(loadstring,body)
    if not ok or type(fn)~="function" then
        return nil,tostring(fn)
    end
    return fn,nil
end

local fn,sourceUsed
if type(readfile)=="function" then
    local ok,body=pcall(readfile,CACHE_PATH)
    if ok then
        fn=compile(body)
        if fn then sourceUsed="local cache" end
    end
end
if not fn then
    for index,url in ipairs(SOURCE_URLS) do
        local began=os.clock()
        local ok,body=pcall(function()
            return game:HttpGet(url.."?t="..tostring(os.time()).."-"..tostring(math.random(1,10000000)))
        end)
        if ok then
            local err
            fn,err=compile(body)
            if fn then
                sourceUsed=index==1 and "GitHub release" or "CDN release"
                print(("[BeyyHub Fast Ch1] Downloaded %d KB in %.2fs from %s"):format(
                    math.floor(#body/1024),os.clock()-began,sourceUsed))
                if type(writefile)=="function" then
                    pcall(function()
                        if type(makefolder)=="function"
                            and (type(isfolder)~="function" or not isfolder(CACHE_DIR)) then
                            makefolder(CACHE_DIR)
                        end
                        writefile(CACHE_PATH,body)
                    end)
                end
                break
            else
                warn("[BeyyHub Fast Ch1] Source rejected: "..tostring(err))
            end
        else
            warn("[BeyyHub Fast Ch1] Download failed: "..tostring(body))
        end
    end
end
if not fn then
    warn("[BeyyHub Fast Ch1] No validated module available. Online access or writefile/readfile is required.")
    return
end
print(("[BeyyHub Fast Ch1] %s compiled and ready in %.2fs"):format(
    sourceUsed,os.clock()-started))
local ran,err=pcall(fn)
if not ran then warn("[BeyyHub Fast Ch1] Chapter1 runtime error: "..tostring(err)) end
print(("[BeyyHub Fast Ch1] Module initialized after %.2fs total"):format(
    os.clock()-started))
