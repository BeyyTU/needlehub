-- BeyyHub | Sell Fries! loader v0.3.0
-- Loads our native BeyyHub interface without changing the official Butter key system.
if not game:IsLoaded() then game.Loaded:Wait() end
if game.PlaceId ~= 139542527731344 then
    warn("[BeyyHub Fries] Execute inside the MAIN Sell Fries! game (place 139542527731344), not the lobby.")
    return
end
local url="https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/sell-fries.lua"
local primary="BeyyHub/sell-fries.lua"
local backup="BeyyHub/sell-fries.backup.lua"
local function read(path)
    if type(readfile)~="function" then return nil end
    local ok,v=pcall(readfile,path)
    return ok and v or nil
end
local function compile(source)
    if type(source)~="string" or #source<25000 then return nil,"incomplete hub code" end
    for _,marker in ipairs({"-- BeyyHub | Sell Fries! | v0.3.0","local function createNativeUI()","installFriesCapture()","function state.Unload()","return state"}) do
        if not source:find(marker,1,true) then return nil,"missing marker: "..marker end
    end
    if type(loadstring)~="function" then return nil,"executor has no loadstring" end
    return loadstring(source)
end
local onlineOk,online=pcall(function()return game:HttpGet(url.."?refresh="..tostring(os.time())) end)
local onlineFn,reason=compile(onlineOk and online or nil)
local old=read(primary)
local fn,source,origin=onlineFn,online,"online"
if not fn then
    fn,reason=compile(old)
    source,origin=old,"cache"
end
if not fn then
    source=read(backup)
    fn,reason=compile(source)
    origin="backup"
end
if not fn then
    warn("[BeyyHub Fries] Could not load online, cached or backed-up hub: "..tostring(reason))
    return
end
if onlineFn and type(writefile)=="function" then
    pcall(function()
        if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder("BeyyHub") then makefolder("BeyyHub")end
        if old~=online then
            if compile(old) then writefile(backup,old)end
            writefile(primary,online)
        end
    end)
end
print("[BeyyHub Fries] Starting "..origin.." version of native UI")
local ok,result=pcall(fn)
if not ok then warn("[BeyyHub Fries] Startup error: "..tostring(result));return end
return result
