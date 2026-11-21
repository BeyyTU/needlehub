# Needle Hub repository map

This document describes the files expected to exist on `main` and the reasons not to move certain legacy-named helpers.

## Active entrypoint

`loader.lua` loads `lobby.lua`, `chapter1.lua` … `chapter5.lua` or `winter.lua` based on `game.PlaceId`. It includes cached-module and teleport reload behavior; changing its imports requires live Roblox testing.

## Dependency map

```text
loader.lua
├── lobby.lua
│   ├── lobby-arcade-full-audit-v3.lua
│   ├── lobby-arcade-remote-capture-v1.lua
│   └── lobby-full-inventory-v1.lua
├── chapter1.lua
│   └── chapter1-live-diagnostics.lua
├── chapter2.lua
│   ├── chapter2-no-levers-cutscene-test.lua
│   ├── chapter2-cutscene-deferred-invisible-skip-test.lua
│   ├── chapter2-puzzle-position-diagnostic.lua
│   └── chapter2-no-levers-puzzles-keypad-confirm-test.lua
├── chapter3.lua
├── chapter4.lua
├── chapter5.lua
└── winter.lua

loader.lua / ch1-fast-start.lua
└── chapter1-tnt3-20261116.lua (pinned fallback)

Independent tools:
├── arcade-boss-standalone.lua
├── arcade-two-round-test.lua
└── needle-cloud/ (separate cloud / Discord runtime)
```

These are **source-level filename references**, not guaranteed execution paths in every game state.

## Maintenance guidelines

1. **Update callers first** when renaming a runtime-loaded file. For this repository, Chapter 2 helper names and the Chapter 1 pinned backup are still referenced.
2. **Don't change gameplay in cleanup-only commits.** Preserve loader/cache logic, auto-farm, replay, camera, cutscene, boss scripts and cloud tooling.
3. **Keep standalone test URLs stable while they are in use.** Previous loadstrings point directly to their current root paths.
4. **Archive rather than overwrite historical snapshots.** The branch `archive/pre-cleanup-2026-11-21` captures the repo as it existed before the 2026-11-21 cleanup.
5. **Avoid committing runtime exports** (`BeyyHub/`, local arcade audit JSON, logs, secrets, or personal credentials).
6. **Validate both source and runtime after functional changes.** A source-only audit can't establish successful Roblox replay, payout or teleport behavior.

## Previous cleanup (2026-11-21)

The unused, dated `chapter1-tnt5-20261116.lua` and `chapter1-tnt8-20261115.lua` were removed from `main` after confirming they were not referenced by the checked current modules and support entrypoints. The referenced TNT3 fallback stays at the root. Both removed snapshots are preserved unchanged in `archive/pre-cleanup-2026-11-21`.
