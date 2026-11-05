# BeyyHub — Clean the Moon (v1.0.0)

This is an independent project on the `clean-the-moon` branch of `BeyyTU/needlehub`. Previous Geode, Sell Fries!, and Search for the Needle branches remain unchanged.

## Game targeting

**User-supplied link:** https://www.roblox.com/games/77902310012360/Moon

This loader uses **exact place ID `77902310012360`**, and optionally accepts later teleported places in the same Roblox universe when explicitly queued by this loader. Do not swap in another game with a similar title: several different Roblox games are called Clean the Moon. The in-game scan will establish which object hierarchy, remotes, upgrades, interactions and progress values are present in the user's linked version.

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/clean-the-moon/loader-clean-moon.lua?refresh=" .. tostring(os.time())))()
```

## Features

- Same native BeyyHub appearance and RightControl toggle used in the earlier projects.
- Starts an automatic **client-visible game map capture**, then offers one-click manual captures.
- Maps public-to-client **RemoteEvents, RemoteFunctions, UnreliableRemoteEvents** by name, class, and instance path (not call arguments).
- Maps **PlayerScripts controllers**, ModuleScript/LocalScript names, ReplicatedStorage assets and hierarchy. Never reads or decompiles script source.
- Records **workspace objects and parts** relevant to cleaning, dust, junk, debris, selling, upgrades, backpack, tools, robots, conveyors, craters, zones, gates, base progression, vehicles and rebirth mechanics.
- Records **ProximityPrompts, ClickDetectors and touch triggers**, interaction labels/ranges/enabled state.
- Records accessible **tool names and metadata**, current held tools, numeric/boolean player attributes and local leaderstats, GUI button labels and UI structure, and CollectionService tags.
- Adds **cleanable-part clusters**: counts and representative positions of generic parts under dust/debris/collection folders, without exporting tens of thousands of redundant parts. Critical prompts and remotes receive reserved scan space.
- Includes caps and per-section summaries (`Visited`, `Recorded`, `Omitted`, `Truncated`) to avoid extreme scans and make omissions explicit.
- **Single merged full game map** by place ID if later teleporting inside the same experience and local storage remains accessible. Each run replaces the latest full snapshot for its place; up to eight compact before/after observations are retained to compare game-state changes.
- **Compact diagnostic export** for quick verification, with totals and any errors.
- Can queue itself across experience teleports on compatible executors; otherwise rerun the same loadstring after a teleport.
- No farming, remote spamming, decompilation, key scraping, server-side access, or other gameplay mutation. This is a **diagnostics-only first release**.

## Potassium output

```
workspace/
  CleanMoonHub/
    clean_moon_game_map.json      # Full metadata dump, merged by Roblox place
    clean_moon_diagnostics.json   # Small status/coverage/errors summary
    clean-moon.lua                # Loader cache
    clean-moon.backup.lua         # Previous valid cache, when available
    config/                       # Reserved for later UI settings
```

The scan requires the executor's `writefile` and `makefolder` functions to create a file. If file writes are unsupported, it attempts to copy the full JSON to the clipboard using `setclipboard`; it cannot guarantee a persistent file in that case.

## Workflow

1. Run the loadstring in the **linked Moon place**.
2. Open BeyyHub with **RightControl**. Wait until the Status says `Saved CleanMoonHub/clean_moon_game_map.json`, or press **Export full game map now**.
3. Play normally: clean a patch, sell a bag, purchase an upgrade, or move to another zone.
4. In **Game Capture**, select **Capture after performing a sell or upgrade** to capture later state. Each scan overwrites that place's prior snapshot.
5. Find the JSON file inside Potassium's `workspace/CleanMoonHub` folder and upload it to this ChatGPT conversation. We can use the actual instance hierarchy and state as the basis for subsequent automation.

## Limitations

A normal Roblox client cannot reveal server-only code or magically infer remote argument schemas. The export captures the visible interface, not a verified server-call contract. It does not read chat, entered text, access tokens, or other players' attributes. The script has been committed and inspected statically, but execution inside your Roblox game has not been tested by the assistant.

## Related public information (background only, NOT game-specific verified mechanics)

Multiple Roblox experiences share the title Clean the Moon. Descriptions of similarly titled games refer to cleaning dust and debris, selling, upgrades, robots and zones; **those claims are not assumed to apply to place 77902310012360** until the captured game data confirms them.
