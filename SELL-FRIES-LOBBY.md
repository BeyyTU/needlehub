# Sell Fries! — Lobby support (BeyyHub v0.4.0)

The same loadstring works in the **lobby (94891079210424)** and the **main kitchen match (139542527731344)** within Roblox universe 10767380385.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/loader-sell-fries.lua?refresh=" .. tostring(os.time())))()
```

## How to use

1. Run the loadstring while you are still in the Sell Fries! lobby.
2. The BeyyHub menu should open; lobby capture automatically begins and saves `BeyyHub/sell_fries_lobby_map.json` when your executor supports file writes.
3. Join a game through the **normal PLAY station**. If your executor supports teleport queue, BeyyHub is queued to reload automatically. If not, execute the same loadstring once more in the gameplay place.
4. Inside the main kitchen, BeyyHub's existing automation and game-capture module load. The main capture saves `BeyyHub/sell_fries_game_map.json`.
5. When the same local executor filesystem persists across teleports, the loader automatically merges the lobby and kitchen snapshots into the **single final file** `BeyyHub/sell_fries_game_map.json`. Its `Places` field contains both Roblox place IDs.

The lobby does **not** run Butter (which explicitly rejects the lobby). If the main kitchen ID changes, non-matching places use capture-only mode for identification rather than attempting unsafe, incompatible farming interactions.

## Limitations

The exporter records client-visible hierarchy, remote names/classes, module metadata, prompts, UI structure, scene objects, positions and attributes. It does not export server code, Lua bytecode, private user inputs, or unknown remote call arguments. Automatic teleport continuation requires an executor-specific queue function, and a combined file requires persistent `readfile`/`writefile` storage. Live testing in Roblox is still needed.
