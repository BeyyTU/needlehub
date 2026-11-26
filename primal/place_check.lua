-- BeyyHub PRIMAL | place check v1.0.0
-- Read-only utility using standard Roblox properties.
local TARGET_PLACE_ID = 125688046049749
local actual = game.PlaceId
print("[PRIMAL] PlaceId:", actual)
print("[PRIMAL] UniverseId:", game.GameId)
print("[PRIMAL] PlaceVersion:", game.PlaceVersion)
if actual == TARGET_PLACE_ID then
    print("[PRIMAL] Target place confirmed.")
else
    warn("[PRIMAL] Place differs from the listed PRIMAL entry place.")
end
