# BeyyHub — Search for the Needle

This is the **active** BeyyHub codebase. Old standalone experiments and one-off debug scripts were removed from the `main` branch to keep it easy to navigate. They are preserved in the [pre-cleanup archive branch](https://github.com/BeyyTU/needlehub/tree/archive/pre-cleanup-2026-11-15).

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/loader.lua?refresh=" .. tostring(os.time())))()
```

`loader.lua` selects the matching gameplay module by Roblox PlaceId:

| Place | PlaceId | Active file |
| --- | --- | --- |
| Lobby | `77108422251420` | `lobby.lua` |
| Chapter 1 | `108628039999641` | `chapter1.lua` |
| Chapter 2 | `83445806734780` | `chapter2.lua` |
| Chapter 3 | `82626725163709` | `chapter3.lua` |
| Chapter 4 | `102537610748607` | `chapter4.lua` |
| Chapter 5 | `85675194070288` | `chapter5.lua` |
| Winter | `87963815262778` | `winter.lua` |

## Files retained on `main`

- **Gameplay:** `loader.lua`, `lobby.lua`, `chapter1.lua` through `chapter5.lua`, and `winter.lua`.
- **Chapter 2 runtime dependencies:** `chapter2-no-levers-cutscene-test.lua`, `chapter2-cutscene-deferred-invisible-skip-test.lua`, `chapter2-puzzle-position-diagnostic.lua`, and `chapter2-no-levers-puzzles-keypad-confirm-test.lua`. Despite their legacy names, `chapter2.lua` downloads these when it runs.
- **Chapter 1 runtime diagnostics:** `chapter1-live-diagnostics.lua`, downloaded automatically by the current Chapter 1 module.
- **Lobby diagnostic actions:** `lobby-arcade-full-audit-v3.lua`, `lobby-arcade-remote-capture-v1.lua`, and `lobby-full-inventory-v1.lua`, still linked from the lobby interface.
- **Discord/cloud tracker:** `needle-cloud/` (Dockerfile, bot, server, gateway and Docker ignore file), independent of the Roblox loader.

The names of certain legacy Chapter 2 helpers are intentionally unchanged so the running `chapter2.lua` can still find them. No gameplay logic was modified as part of this repository cleanup.

## Archive and recovery

The [archive branch](https://github.com/BeyyTU/needlehub/tree/archive/pre-cleanup-2026-11-15) contains **all 71 tracked files** that existed immediately before cleanup, including the old test loaders, Chapter 2 experiments, ranch probes, and Winter inspector. These files remain accessible and can be restored individually if necessary. The Git commit history also remains intact.

**Note:** This cleanup is a source-file/dependency audit, not an in-game runtime test. If you still use a standalone loadstring pointing directly to one of the archived experimental files, update it to the normal loader or target the archive branch explicitly.
