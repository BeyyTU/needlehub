-- PRIMAL place metadata report v1.0.0
local TARGET_UNIVERSE = 10775092853
if game.GameId ~= TARGET_UNIVERSE then
    warn("[PRIMAL] Not in the PRIMAL universe.")
    return
end
local folder = "PRIMAL"
if type(makefolder) ~= "function" or type(writefile) ~= "function" then
    warn("[PRIMAL] Local file output is unavailable in this environment.")
    return
end
local ok, err = pcall(function()
    if type(isfolder) ~= "function" or not isfolder(folder) then
        local created, reason = pcall(makefolder, folder)
        if not created and not (type(isfolder) == "function" and isfolder(folder)) then
            error(reason)
        end
    end
    local stamp = os.date("!%Y%m%d_%H%M%S")
    local path = folder .. "/place_report_" .. stamp .. ".json"
    local report = {
        reportVersion = "1.0.0",
        capturedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        placeId = tostring(game.PlaceId),
        universeId = tostring(game.GameId),
        placeVersion = game.PlaceVersion
    }
    writefile(path, game:GetService("HttpService"):JSONEncode(report))
    print("[PRIMAL] Saved: " .. path)
end)
if not ok then
    warn("[PRIMAL] Report failed: " .. tostring(err))
end
