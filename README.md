# Beyy Hub v103.00

Place-specific split release. The four supplied gameplay modules are preserved unchanged.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/loader.lua?refresh=" .. tostring(os.time())))()
```

The loader uses BASE_RAW_URL = https://raw.githubusercontent.com/BeyyTU/needlehub/main (no trailing slash).

| PlaceId | Module |
| --- | --- |
| 77108422251420 | lobby.lua |
| 108628039999641 | chapter1.lua |
| 83445806734780 | chapter2.lua |
| 82626725163709 | chapter3.lua |

Unsupported places return without downloading a module. Each module also checks its PlaceId.
The router validates module length, version and module markers, and compilation before execution.

## Caching and teleport reload

Only the selected gameplay module is fetched. On the first run the router may additionally fetch itself for teleport caching. Modules load WindUI separately from its upstream latest release, with a local cache.

The loader checks GitHub's latest main-branch commit and downloads the current module and router using that exact SHA. Script caches use BeyyHub/v103_00_<commit SHA>_*.lua. After validating a module from a changed revision, it deletes known legacy script caches and the previous revision's five Lua cache files when delfile is available. Revision-specific names prevent stale reuse even without deletion support. Saved config JSON files and WindUI's own cache are not deleted.

Teleport reload is queued when a supported queue function exists; otherwise rerun the loader after changing places. The queued payload independently checks the newest GitHub commit, fetches the corresponding commit-pinned router, rechecks the commit immediately before execution, and retries if the branch changes. A cached router is used only if it is keyed to that same freshly confirmed commit; otherwise the reload stops with a warning rather than executing a known-older release. These environment-provided HTTP, loadstring, filesystem and teleport functions are not a standard Roblox LocalScript interface.

## Verification

The original v103.00 release had compile and mocked-loader tests. The stricter freshness-failsafe modification was reviewed for correct source references and revision-gated cache behavior; it has not been tested in live Roblox gameplay or teleport execution. If GitHub's commit API fails, the loader can still launch from live raw main. If both GitHub API and raw downloads are unreachable, the hub will stop by design.

This README was prepared for publication because the original generated README was not supplied.

## Overview & Settings update

Saved-config selection, refresh, load and save controls are available under Overview & Settings in every module. Chapter 1 combines its previous Main and Settings tabs there. In the lobby, Chapter 1 round creation and Auto Farm Wins have moved from Lobby to Overview & Settings; Lobby Tools remains separate. Shared configs retain settings for other chapters when saved. Existing config files remain in WindUI/BeyyHub/config/. The updated router uses v103_00_tabs3_ script caches; rerun the normal online loader once to fetch this UI revision. Live UI interaction has not been verified in Roblox.

### Auto Farm Wins continuation across rounds

Lobby and Chapter 1 now share the last explicit Auto Farm Wins setting through `BeyyHub/autofarmwins_preference_v2.txt`, with `BeyyHub/autofarmwins_shared.txt` synchronized for compatibility. Once a config is loaded or saved, `BeyyHub/active_config.txt` records the chosen profile for manual selection, but a new lobby or Chapter 1 session always auto-loads `default`. On startup, Auto Farm Wins reads the saved `default` value first, then the teleport setting, then the legacy shared preference files. Config startup callbacks in Chapter 1 no longer overwrite the saved toggle with a default false state. The lobby round creator resumes when the restored setting is true. If you previously used only a non-default named profile, select **Load Selected Config** once in the lobby or Chapter 1 to establish the remembered profile. These updates have been inspected and mocked for state restoration; live teleport behavior is not yet verified.

## Reference rotations and cutscene control

Chapter 1 uses the v101.57 reference four-band sweep at 48 degrees per second: 22, 18, 14 and 8 stud bands with fixed measured hay surfaces, smooth band transitions, and matching character movement. A lap takes about 7.5 seconds and the four-band cycle about 30 seconds at normal frame rates.

Every module includes an optional Unskippable Cutscene Bypass under Overview & Settings, saved in named configs. It uses the reference camera/movement controller with generalized CutsceneActive detection and Chapter2ReleaseActive support. It yields to explicit unfinished intros, visible Skip/results UI, the hub menu, and active needle/puzzle automation. Scenes without these replicated attributes cannot be identified automatically. This changes local camera, controls and cutscene overlays only; server timers and progression are unchanged. Turning it off or unloading cleans up its callbacks and restores the camera/HUD. Live compatibility with individual chapter scenes is not yet verified.

Rerun the normal online loader to select the new v103_00_tabs3_ script cache. Saved configs are retained.

## GitHub revision detection

The latest successfully validated revision is saved in BeyyHub/github_revision.txt for change notices and cache cleanup, never as an unverified fallback. On each launch and teleport the loader retries GitHub's main-branch revision check up to three times. The first launch redirects to the exact latest commit's loader, avoiding stale main-branch loader content; then it loads only a module belonging to the latest verified revision and rechecks main before executing. If a new commit arrives mid-load, it retries against the newer revision. If GitHub's commit API is rate-limited or unavailable, the loader falls back to a cache-busted live download from raw.githubusercontent.com/main, never an unverified older local cache. If the online raw download also fails, it stops rather than launching an outdated release. Existing running instances are not hot-swapped; these checks take place at launch and teleport. There is no absolute guarantee against a new commit occurring milliseconds after the final check.

## AFK farming restart reliability update

Chapter 1 now waits for the game to finish loading and for the `NeedleHaystack` replicated folder before initializing. This fixes a race where a fast teleport loader could permanently classify the chapter as not in-game and disable every autofarm loop. The chosen named/default WindUI profile takes precedence over any stale legacy AFK preference; saving Auto Farm Wins in `default` therefore persists into fresh Chapter 1 servers. The lobby uses the same precedence for round creation. The GitHub loader now handles anonymous API rate limits by downloading the online raw `main` router and module instead of silently stopping the entire round. The module download must still succeed online for unverified revision cases. No gameplay movement, orbit or needle hand-in algorithms were changed. The fix has been reviewed statically and still requires live Roblox verification.

## AFK setting across game teleports

The Chapter 1 log `Startup AutoFarmWins=false (persisted=nil)` showed that the saved Auto Farm Wins value was unavailable when the new game loaded, even though the WindUI default profile loaded. Lobby and Chapter 1 now save an explicit `__elements.AutoFarmWins` toggle in named/default config JSON and also store the last choice using the Roblox client `TeleportService:SetTeleportSetting("BeyyHub_AutoFarmWins_v103", enabled)`. On arrival, the latest saved `default` config takes precedence, followed by `GetTeleportSetting`, the dedicated file, and the legacy shared file. The setting is rewritten on toggle or successful config save/load, with safe fallbacks if TeleportService methods aren't available. The startup console includes the read-back teleport and config values to diagnose any remaining issue. After updating, turn Auto Farm Wins ON and save `default` once to populate the new portable setting. Live Roblox teleport verification is still outstanding.

## Default config autoload and Basement key responsiveness

All four place modules (Lobby, Chapter 1, Chapter 2/Basement, Chapter 3) now automatically try to load `WindUI/BeyyHub/config/default.json` when the module starts. The restore also applies saved toggle values with WindUI callbacks enabled, because the WindUI config loader alone updates control values without necessarily activating the underlying feature. The Basement `Unskippable Cutscene Bypass` therefore starts if `CutsceneBypass=true` is saved in `default`; switching it off and saving `default` keeps it off on the next launch. Normal skippable intro and ending screens remain excluded, and the bypass intentionally yields the camera to active automatic puzzle controllers so it cannot interrupt keypad/lever clicks. The bypass cannot accelerate server-owned cutscene timers.

In Chapter 2, `Auto Find Needle` now also initiates pickup of the exposed key (independently of the separate `Auto Pick Up Needle` toggle). Active pickup and turn-in loops poll every 0.12 seconds, and their click/settle waits were shortened while retaining the existing ownership-confirmation, server-interaction and puzzle-busy safeguards. Settings that are missing from `default` remain unchanged. To enable the new behavior, select the intended toggles and save `default` once in Chapter 2. Code checks passed, but in-game confirmation is still required.

## Faster Basement lever inputs

Chapter 2's Auto All Puzzles startup no longer holds an unobstructed closed menu for 0.85 seconds before Lever 1; it now verifies two unobstructed render frames and a short 0.05-second clear interval. Camera settle, mouse-down, animation sampling, and between-lever waits were shortened while keeping the center-of-screen lever raycast, cancellation checks, and input release/character restoration. Approximate worst-case configured waits dropped from 3.36 seconds to 1.0 second for the three-lever pass, excluding render-frame time and server/network latency; this is not a measured in-game timing guarantee. The rest of the puzzle automation is unchanged. Test a complete lever pass in Roblox before relying on it for unattended automation.

## Basement key targeting and unskippable cutscene fixes

The Chapter 2/Basement key picker now accepts exposed objectives whose `HIDDEN_WITHIN` value is absent or `false`, positions the camera farther back toward the objective, checks the target is within the viewport centre, and temporarily disables nearby haystack parts from mouse ray queries when they obstruct pickup. All touched `CanQuery`/`CanCollide` values are restored after the attempt, even when the click fails. Key pickup and hand-in no longer wait for the entire Auto All Puzzles orchestration to finish once there is no active lever/colour camera controller; they still obey the game's input locks and needle ownership checks.

During the flagged three-lever and three-puzzle unskippable cinematics, the visual/gameplay bypass no longer yields solely because Auto All Puzzles is in progress. It continues to yield to active lever/colour aiming, the skippable ending UI, the hub menu and key pickup. It refreshes locally disabled movement controls and known gameplay HUD/hotbar screens each frame, and locally unanchors the character if the cutscene has anchored it. The normal skippable intro/ending remain excluded. These are client-side attempts only: server cutscene timers, authoritative anchoring and server acceptance of key input cannot be overridden by this code. Source structural checks and mocked guard-state cases pass; live Roblox/SolaraV3 behavior is not yet verified.


## Idle lag and recurring frame hitch reduction

A source audit identified a wasteful idle loop in all four place modules' cutscene controllers: every 0.1 seconds, even during normal gameplay, it resampled the camera, scanned top-level HUD GUIs and created new HUD snapshot tables. Polling is now 0.35 seconds while idle and retains 0.1 seconds during active scenes; attribute-change events still trigger immediate scene transitions. HUD snapshot tables are reused when their enabled/order values have not changed. In Basement, the key objective lookup also caches a still-valid exposed key and limits costly descendant searches when no exposed key has been found to once per 0.15 seconds, preserving the key pickup and server-confirmation routines. This reduces background allocation and repeated tree traversal; it does not guarantee an FPS improvement, because periodic server calls, game assets, graphics and other scripts may also contribute to stalls. No farming algorithms, lever/puzzle timing, or default-config activation logic were intentionally modified. The changes passed source structural checks and a simulated key cache behavior test; live Roblox frame-time testing is pending.


## Reliable default-config updates and reloads

Every place module now reads saved configs directly from the current `WindUI/BeyyHub/config/<name>.json` file when Load is requested. It synchronously applies registered control values and enables toggle callbacks. The hub no longer creates WindUI `CreateConfig` objects for loading or saving, avoiding WindUI's extra asynchronous auto-load for profiles with legacy `__autoload=true` metadata, which could revert recently changed settings after a delay. Successful saves replace values for currently registered controls, retain settings belonging to other places, and explicitly write `__autoload=false` because BeyyHub handles `default` autoload itself. A Save verifies that the file's content was written before reporting success; unreadable existing JSON is not silently overwritten. The saved `default` profile overrides an older Auto Farm Wins teleport preference on new sessions. No gameplay or farming routines are changed by this config-specific fix. Verification covers source syntax structure and simulated save/restore scenarios; live executor file-system behavior remains to be tested.

To verify, enable or disable an obvious setting, select **Save Config As: default**, press **Save Config**, then re-execute the loader in the same place. The last explicitly saved value should be restored; manual unsaved changes intentionally do not replace the existing saved profile.
