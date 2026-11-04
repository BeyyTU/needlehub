# BeyyHub — Sell Fries! (v0.2.0)

A **separate** Sell Fries! branch for `BeyyTU/needlehub`. Reuses the exact native BeyyHub-style interface extracted from our Geode build. The original Search for the Needle and Geode scripts are unchanged.

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/loader-sell-fries.lua?refresh=" .. tostring(os.time())))()
```

Execute **inside the Sell Fries! main place** `139542527731344`. Butter's launcher will not run from the lobby `94891079210424`.

## Installed features

**Main:** Official Butter launcher (Butter's own key and GUI remain necessary), Anti AFK, nearby production prompt assist, pause controls, 1–4x walk speed and config save/load.

**Fries Farming:** Auto potato pile -> crate (uses live cells from the game's PileController when exposed), optional return to previous position, collect one potato, deposit carried potatoes, optional local instant-peel flag (may not bypass a server-side unlock), auto tycoon-pad contacts if the executor supports `firetouchinterest`.

**Fries Survival:** Auto repair Power Box 1 when `PowerBroken` is true, anomaly-aware shutter close/reopen, manual shutter toggle, red/green traffic ESP, fullbright, optional local anti-jumpscare guard.

**Fries Travel:** Teleport shortcuts for kitchen, pile, crate, drive-thru, power box, shops and basement padlock. Infinite jump and noclip.

**Status & Logs:** Compatibility scan (`RemovePotato`, `CratePut`, `PowerCable`, `ShutterPress` + pile cells), live status, JSON diagnostics export, config save/load, unload.

## How auto pile/crate operates

BeyyHub seeks **real** part/cell tuples exposed by the game's `PlayerScripts.Controllers.PileController`. It uses `ReplicatedStorage.Remotes.RemovePotato` with those coordinates and waits to observe increases in `CarryCount`. When carry capacity is reached, it sends `CratePut`. If the genuine cell state is not exposed by this executor/game version, **it skips scooping** rather than fabricating target cells.

The current auto farm only supplies the crate. For the rest of the production chain—peeling, fryer management, drive-thru serving, repairs and machine upgrades—Butter offers its own independent automation in its own protected menu. Running two programs for the same action can conflict; start with the other auto-farm toggles off if using Butter's Full Auto.

## Source research

- [Butter](https://github.com/kode-sec/Butter) — official key-protected automation engine. Its main loader routes place ID `139542527731344` to `fries.lua`.
- [MoonHub's readable Sell Fries feature implementation](https://github.com/DarkMooN-SYS/Scripts/blob/main/Games/Sell%20fries/Features.lua) — game-specific remote names, world paths, pile cells, survival detection, and location references. BeyyHub independently reimplements this logic; it does not execute the MoonHub loader.
- [MoonHub public script listing](https://www.xenoscripts.com/script/sell-fries-half-auto-farm) — published feature claims; not a current independent functional test of every toggle.
- [Overflow ScriptBlox listing](https://scriptblox.com/script/Sell-Fries-Anomaly-Overflow-Auto-Kitchen-Auto-peel-Instant-Peel-and-More-232046) — lists more kitchen and progression features but its protected loader is not auditable.

### Verification limits

File commits and basic content checks pass. **We have not executed this script inside a live Roblox game**. The source code and listings show that features exist, not that game servers currently accept each request. Look at `Fries Farming → Check game feature compatibility`, and then `Status & Logs → Export Debug Diagnostics` to confirm which paths and interactions actually work in your client.

The extras module is hosted at `sell-fries-extras.lua` and loaded separately, with its own error status. The native UI can still open if extras are unavailable.

Script automation can conflict with other scripts or with a game's rules.
