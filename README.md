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

The original v103.00 release had compile and mocked-loader tests. The stricter freshness-failsafe modification was reviewed for correct source references and revision-gated cache behavior; it has not been tested in live Roblox gameplay or teleport execution. A GitHub outage or rate limit can now prevent the hub from launching by design.

This README was prepared for publication because the original generated README was not supplied.

## Overview & Settings update

Saved-config selection, refresh, load and save controls are available under Overview & Settings in every module. Chapter 1 combines its previous Main and Settings tabs there. In the lobby, Chapter 1 round creation and Auto Farm Wins have moved from Lobby to Overview & Settings; Lobby Tools remains separate. Shared configs retain settings for other chapters when saved. Existing config files remain in WindUI/BeyyHub/config/. The updated router uses v103_00_tabs3_ script caches; rerun the normal online loader once to fetch this UI revision. Live UI interaction has not been verified in Roblox.

### Auto Farm Wins continuation across rounds

Lobby and Chapter 1 now share the last explicit Auto Farm Wins setting through `BeyyHub/autofarmwins_preference_v2.txt`, with `BeyyHub/autofarmwins_shared.txt` synchronized for compatibility. Once a config is loaded or saved, `BeyyHub/active_config.txt` records the chosen profile so Chapter 1 can auto-load that same profile after teleporting. On startup, the order for Auto Farm Wins is: explicit persisted setting, active named/default config, then legacy shared setting. Config startup callbacks in Chapter 1 no longer overwrite the saved toggle with a default false state. The lobby round creator resumes when the restored setting is true. If you previously used only a non-default named profile, select **Load Selected Config** once in the lobby or Chapter 1 to establish the remembered profile. These updates have been inspected and mocked for state restoration; live teleport behavior is not yet verified.

## Reference rotations and cutscene control

Chapter 1 uses the v101.57 reference four-band sweep at 48 degrees per second: 22, 18, 14 and 8 stud bands with fixed measured hay surfaces, smooth band transitions, and matching character movement. A lap takes about 7.5 seconds and the four-band cycle about 30 seconds at normal frame rates.

Every module includes an optional Unskippable Cutscene Bypass under Overview & Settings, saved in named configs. It uses the reference camera/movement controller with generalized CutsceneActive detection and Chapter2ReleaseActive support. It yields to explicit unfinished intros, visible Skip/results UI, the hub menu, and active needle/puzzle automation. Scenes without these replicated attributes cannot be identified automatically. This changes local camera, controls and cutscene overlays only; server timers and progression are unchanged. Turning it off or unloading cleans up its callbacks and restores the camera/HUD. Live compatibility with individual chapter scenes is not yet verified.

Rerun the normal online loader to select the new v103_00_tabs3_ script cache. Saved configs are retained.

## GitHub revision detection

The latest successfully validated revision is saved in BeyyHub/github_revision.txt for change notices and cache cleanup, never as an unverified fallback. On each launch and teleport the loader retries GitHub's main-branch revision check up to three times. The first launch redirects to the exact latest commit's loader, avoiding stale main-branch loader content; then it loads only a module belonging to the latest verified revision and rechecks main before executing. If a new commit arrives mid-load, it retries against the newer revision. If freshness cannot be verified (including GitHub outages/rate limits), the loader fails closed and does not execute an older cached script. Existing running instances are not hot-swapped; these checks take place at launch and teleport. There is no absolute guarantee against a new commit occurring milliseconds after the final check.
