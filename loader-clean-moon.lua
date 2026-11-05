-- BeyyHub | Clean the Moon | loadstring entry v1.0.0
-- Target game URL: https://www.roblox.com/games/77902310012360/Moon
if not game:IsLoaded() then game.Loaded:Wait() end
local TARGET=77902310012360
local env=type(getgenv)=="function" and getgenv() or _G
local sameUniverse=game.GameId~=0 and tonumber(env.BeyyMoonContinuationUniverse)==game.GameId
if game.PlaceId~=TARGET and not sameUniverse then
    warn("[BeyyHub Moon] Please run inside the linked Moon place (77902310012360). Current place: "..tostring(game.PlaceId))
    return
end
local directory="CleanMoonHub"
local filename=directory.."/clean-moon.lua"
local backup=directory.."/clean-moon.backup.lua"
local remote="https://raw.githubusercontent.com/BeyyTU/needlehub/clean-the-moon/clean-moon.lua"
local function exists(path)
    if type(readfile)~="function" then return nil end
    local ok,content=pcall(readfile,path)
    return ok and content or nil
end
local function valid(text)
    if type(text)~="string" or #text<28000 then return nil,"empty or incomplete code" end
    for _,marker in ipairs({
        "-- BeyyHub Clean the Moon v1.0.0",
        "local function createNativeUI()",
        "installCapture()",
        "function state.Unload()",
        "return state"
    }) do
        if not text:find(marker,1,true)then return nil,"missing "..marker end
    end
    if type(loadstring)~="function" then return nil,"loadstring is unavailable" end
    return loadstring(text)
end
local onlineOk,online=pcall(function()
    return game:HttpGet(remote.."?refresh="..tostring(os.time()))
end)
local compiled,reason=valid(onlineOk and online or nil)
local previous=exists(filename)
local origin="online"
if not compiled then
    compiled,reason=valid(previous)
    origin="local cache"
end
if not compiled then
    compiled,reason=valid(exists(backup))
    origin="backup"
end
if not compiled then
    warn("[BeyyHub Moon] No usable online or local script: "..tostring(reason))
    return
end
if onlineOk and online and origin=="online" and type(writefile)=="function" then
    pcall(function()
        if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder(directory) then
            makefolder(directory)
        elseif type(isfolder)~="function" and type(makefolder)=="function" then
            pcall(makefolder,directory)
        end
        if previous~=online then
            if valid(previous) then writefile(backup,previous)end
            writefile(filename,online)
        end
    end)
end
print("[BeyyHub Moon] Loaded "..origin.." loader for place "..tostring(game.PlaceId))
local ok,script=pcall(compiled)
if not ok then
    warn("[BeyyHub Moon] Startup error: "..tostring(script))
    return
end
return script
