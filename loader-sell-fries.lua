-- BeyyHub Sell Fries loader v0.4.0 | accepts lobby AND main kitchen
if not game:IsLoaded() then game.Loaded:Wait() end
local UNIVERSE_ID=10767380385
local MAIN_PLACE=139542527731344
local LOBBY_PLACE=94891079210424
if game.GameId~=UNIVERSE_ID then
    warn("[BeyyHub Fries] This loader is for the Sell Fries! experience. Current universe: "..tostring(game.GameId))
    return
end
local inMain=game.PlaceId==MAIN_PLACE
local mode=inMain and "kitchen" or "lobby"
local path=inMain and "sell-fries.lua" or "sell-fries-lobby.lua"
local cache=inMain and "BeyyHub/sell-fries.main.lua" or "BeyyHub/sell-fries.lobby.lua"
local backup=inMain and "BeyyHub/sell-fries.main.backup.lua" or "BeyyHub/sell-fries.lobby.backup.lua"
local url="https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/"..path
local function read(path)
    if type(readfile)~="function" then return nil end
    local ok,data=pcall(readfile,path)
    return ok and data or nil
end
local function validate(source)
    if type(source)~="string" or #source<(inMain and 30000 or 7000) then
        return nil,"source missing or incomplete"
    end
    local markers=inMain and {"-- BeyyHub | Sell Fries! | v0.3.0","local function createNativeUI()","installFriesCapture()","return state"}
        or {"-- BeyyHub | Sell Fries! | Lobby capture","local function createCapture()","return state"}
    for _,marker in ipairs(markers) do
        if not source:find(marker,1,true) then return nil,"missing source marker: "..marker end
    end
    if type(loadstring)~="function" then return nil,"loadstring not supported" end
    return loadstring(source)
end
local onlineOK,online=pcall(function()
    return game:HttpGet(url.."?refresh="..tostring(os.time()))
end)
local onlineFn,reason=validate(onlineOK and online or nil)
local cached=read(cache)
local source,origin,fn=online,"online",onlineFn
if not fn then
    source=cached;origin="cache";fn,reason=validate(source)
end
if not fn then
    source=read(backup);origin="backup";fn,reason=validate(source)
end
if not fn then
    warn("[BeyyHub Fries] Could not start "..mode.." mode: "..tostring(reason))
    return
end
if onlineFn and type(writefile)=="function" then
    pcall(function()
        if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder("BeyyHub") then
            makefolder("BeyyHub")
        end
        if cached~=online then
            if validate(cached)then writefile(backup,cached)end
            writefile(cache,online)
        end
    end)
end
print("[BeyyHub Fries] Starting "..mode.." from "..origin.." (place "..game.PlaceId..")")
local ok,hub=pcall(fn)
if not ok then
    warn("[BeyyHub Fries] Startup error: "..tostring(hub))
    return
end
-- Once the main game's snapshot is written, merge it with the lobby capture
-- into ONE final JSON. Both captures stay client-local.
local function mergeMaps()
    if type(readfile)~="function" or type(writefile)~="function" then return false,"file API unavailable" end
    local Http=game:GetService("HttpService")
    local lobbyRaw=read("BeyyHub/sell_fries_lobby_map.json")
    local gameRaw=read("BeyyHub/sell_fries_game_map.json")
    if type(lobbyRaw)~="string" or type(gameRaw)~="string" then return false,"one capture missing" end
    local okLobby,lobby=pcall(function()return Http:JSONDecode(lobbyRaw)end)
    local okMain,main=pcall(function()return Http:JSONDecode(gameRaw)end)
    if not okLobby or not okMain or type(lobby)~="table" or type(main)~="table" then
        return false,"could not decode snapshots"
    end
    if tonumber(lobby.UniverseId)~=UNIVERSE_ID or tonumber(main.UniverseId)~=UNIVERSE_ID then
        return false,"different Roblox experience"
    end
    local gamePart=type(main.Places)=="table" and main.Places[tostring(MAIN_PLACE)] or main
    if type(gamePart)~="table" or tonumber(gamePart.PlaceId)~=MAIN_PLACE then
        return false,"main game capture not ready"
    end
    local lobbyPart=type(lobby.Places)=="table" and lobby.Places[tostring(lobby.PlaceId)] or lobby
    if type(lobbyPart)~="table" then return false,"lobby snapshot missing" end
    local combined={
        Schema="BeyyHub-SellFries-GameMap-v2",UniverseId=UNIVERSE_ID,
        LastPlaceId=MAIN_PLACE,CapturedAtUTC=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        PlaceCount=2,
        Places={[tostring(lobbyPart.PlaceId)]=lobbyPart,[tostring(MAIN_PLACE)]=gamePart}
    }
    local good,encoded=pcall(function()return Http:JSONEncode(combined)end)
    if not good then return false,"JSON merge encoding failed"end
    local saved,err=pcall(function()writefile("BeyyHub/sell_fries_game_map.json",encoded)end)
    if not saved then return false,tostring(err)end
    return true,tostring(#encoded).." bytes"
end
if inMain and type(hub)=="table" then
    task.spawn(function()
        local last=nil
        while hub.Running==true do
            local summary=hub.FullCaptureSummary
            if summary and summary~=last and summary.Saved then
                last=summary
                task.wait(0.3)
                local merged,detail=mergeMaps()
                if merged then
                    hub.FullCaptureMergedPlaces=2
                    print("[BeyyHub Fries] Combined lobby + main map saved as ONE file: BeyyHub/sell_fries_game_map.json ("..detail..")")
                else
                    hub.FullCaptureMergedPlaces=1
                    print("[BeyyHub Fries] Main capture saved; lobby merge unavailable: "..tostring(detail))
                end
            end
            task.wait(0.7)
        end
    end)
end
return hub
