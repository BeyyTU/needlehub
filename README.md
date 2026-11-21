# BeyyHub · Search for the Needle

A small, focused repository: the **game code stays at the top**, while supporting scripts live in [`internal/`](internal/).

**Start BeyyHub:**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/loader.lua?refresh=" .. tostring(os.time())))()
```

## Core scripts

| File | Purpose |
| --- | --- |
| [`loader.lua`](loader.lua) | Loads the correct module automatically |
| [`lobby.lua`](lobby.lua) | Lobby and arcade |
| [`chapter1.lua`](chapter1.lua) | Chapter 1 |
| [`chapter2.lua`](chapter2.lua) | Chapter 2 |
| [`chapter3.lua`](chapter3.lua) | Chapter 3 |
| [`chapter4.lua`](chapter4.lua) | Chapter 4 |
| [`chapter5.lua`](chapter5.lua) | Chapter 5 |
| [`winter.lua`](winter.lua) | Winter and Yeti |

## Other folders

- [`internal/`](internal/): runtime dependencies, diagnostic scripts, optional fast launcher and standalone arcade tools. Core modules have been updated to download these from their new locations.
- [`needle-cloud/`](needle-cloud/): separate cloud/Discord tracker (unchanged).

The [dependency map](internal/REPOSITORY_MAP.md) lists every supporting file.

**Backup:** [pre-simplification snapshot, November 21, 2026](https://github.com/BeyyTU/needlehub/tree/archive/pre-simplified-root-2026-11-21). The older root-level standalone loadstrings remain available on that branch; on `main`, use the new `internal/tools/` URLs.

Only source URLs/paths and documentation changed. No gameplay logic was intentionally modified; a live Roblox test is still needed to verify the full loader flow.
