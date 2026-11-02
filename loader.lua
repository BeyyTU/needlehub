-- Crack the Geode! loader v2. Validates downloads before replacing the cached hub.
if not game:IsLoaded()then game.Loaded:Wait()end
if game.GameId~=10770110947 then warn("[Geode Hub] This loader is for Crack the Geode!");return end
local path="GeodeHub/main.lua"
local backup="GeodeHub/main.backup.lua"
local url="https://raw.githubusercontent.com/sceneton/geode/main/main.lua"
local function validateGeodeHubSource(source)
    if type(source)~="string"or #source<4000 then return nil,"empty or incomplete source"end
    for _,marker in ipairs({"-- Beyy Geode Hub | Crack the Geode!","createNativeUI","Auto Geode Pickup","return Hub"})do
        if not source:find(marker,1,true)then return nil,"hub marker missing: "..marker end
    end
    local fn,err=loadstring(source)
    if not fn then return nil,"compile failed: "..tostring(err)end
    return fn
end
local function readSource(file)
    local ok,source=pcall(readfile,file)
    if not ok then return nil end
    return source
end
local onlineOK,online=pcall(function()return game:HttpGet(url.."?refresh="..tostring(os.time()))end)
local function sourceVersion(source)
    local version=source:match('local geodeVersion="([%d%.]+)"')or source:match('Version="([%d%.]+)"')or"0.0.0"
    local numbers={};for number in version:gmatch("%d+")do table.insert(numbers,tonumber(number))end
    return numbers
end
local function newer(a,b)
    local av,bv=sourceVersion(a),sourceVersion(b)
    for i=1,math.max(#av,#bv)do
        if(av[i]or 0)~=(bv[i]or 0)then return(av[i]or 0)>(bv[i]or 0)end
    end
    return false
end
local compiled,reason=validateGeodeHubSource(onlineOK and online or nil)
local source,origin=compiled and online or nil,compiled and"online"or nil
local cached,backed=readSource(path),readSource(backup)
for _,candidate in ipairs({{cached,"cache"},{backed,"backup"}})do
    local fn=validateGeodeHubSource(candidate[1])
    if fn and(not compiled or newer(candidate[1],source))then
        source,origin,compiled=candidate[1],candidate[2],fn
    end
end
if compiled then
    pcall(function()
        if not isfolder("GeodeHub")then makefolder("GeodeHub")end
        if source~=cached then
            -- Preserve the previous valid primary only if that would not downgrade
            -- a newer backup (for example when a stale CDN response arrives).
            if validateGeodeHubSource(cached)and(not validateGeodeHubSource(backed)or newer(cached,backed))then writefile(backup,cached)
            elseif not validateGeodeHubSource(backed)then writefile(backup,source)end
            writefile(path,source)
        end
    end)
end
if not compiled then warn("[Geode Hub] No valid online, cached or backup hub. Online source: "..tostring(reason));return end
print("[Geode Hub] Loading "..origin.." source ("..#source.." bytes)")
local ok,result=pcall(compiled)
if not ok then warn("[Geode Hub] Startup failed: "..tostring(result));return end
if type(result)~="table"or(result.Running~=true and result.Pending~=true)then warn("[Geode Hub] Startup returned without a running hub; check module-load messages.")end
return result

