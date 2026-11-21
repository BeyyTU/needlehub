# BeyyHub — Search for the Needle

The active Roblox modules and supporting tools for **BeyyHub / Search for the Needle**.

## Main loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/loader.lua?refresh=" .. tostring(os.time())))()
```

The main loader detects the current Roblox PlaceId and loads the appropriate module. **Keep the filenames below stable:** some are downloaded at runtime, and renaming them without updating their callers would break features.

## Gameplay modules

| Place | PlaceId | Module |
| --- | --- | --- |
| Lobby | `77108422251420` | [`lobby.lua`](lobby.lua) |
| Chapter 1 | `108628039999641` | [`chapter1.lua`](chapter1.lua) |
| Chapter 2 | `83445806734780` | [`chapter2.lua`](chapter2.lua) |
| Chapter 3 | `82626725163709` | [`chapter3.lua`](chapter3.lua) |
| Chapter 4 | `102537610748607` | [`chapter4.lua`](chapter4.lua) |
| Chapter 5 | `85675194070288` | [`chapter5.lua`](chapter5.lua) |
| Winter | `87963815262778` | [`winter.lua`](winter.lua) |

## Other entrypoints and test tools

- [`ch1-fast-start.lua`](ch1-fast-start.lua): optional Chapter 1 launcher. Its pinned fallback is `chapter1-tnt3-20261116.lua`.
- [`arcade-boss-standalone.lua`](arcade-boss-standalone.lua): separate arcade/boss experiment.
- [`arcade-two-round-test.lua`](arcade-two-round-test.lua): read-only two-round arcade reward diagnostic with Start/Stop and JSON export.
- [`needle-cloud/`](needle-cloud/): independently deployed Discord/cloud tracker, Docker and gateway files.

## Supporting runtime files — do not rename or delete casually

| Used by | Required files |
| --- | --- |
| `loader.lua` and `ch1-fast-start.lua` | `chapter1-tnt3-20261116.lua` (pinned known-good Chapter 1 snapshot/fallback) |
| `chapter1.lua` | `chapter1-live-diagnostics.lua` |
| `chapter2.lua` | `chapter2-no-levers-cutscene-test.lua`, `chapter2-cutscene-deferred-invisible-skip-test.lua`, `chapter2-puzzle-position-diagnostic.lua`, `chapter2-no-levers-puzzles-keypad-confirm-test.lua` |
| `lobby.lua` | `lobby-arcade-full-audit-v3.lua`, `lobby-arcade-remote-capture-v1.lua`, `lobby-full-inventory-v1.lua` |

Although some runtime files have “test” in their filenames, the active code still references them. They were deliberately retained at their existing paths.

## Archive and restoration

- **[2026-11-21 pre-cleanup backup](https://github.com/BeyyTU/needlehub/tree/archive/pre-cleanup-2026-11-21):** complete main-branch snapshot before this cleanup, including superseded `chapter1-tnt5-20261116.lua` and `chapter1-tnt8-20261115.lua`.
- **[2026-11-15 original cleanup archive](https://github.com/BeyyTU/needlehub/tree/archive/pre-cleanup-2026-11-15):** older experimental and diagnostic files from the original cleanup.

Only unused historical TNT5/TNT8 snapshots were removed from the active branch; they remain in the dated backup branch and Git history. The current loader, gameplay modules, pinned TNT3 fallback, diagnostic paths and cloud tracker were **not** modified as part of this cleanup.

For a full dependency guide, see [docs/REPOSITORY_MAP.md](docs/REPOSITORY_MAP.md).

*This was a repository/source dependency review, not an in-game test.*
