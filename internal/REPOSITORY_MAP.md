# Needle Hub · Supporting modules

The repository root contains only the main loader, lobby, chapter scripts, Winter module and the `internal/` and `needle-cloud/` folders.

## Dependency map

```text
loader.lua
├─ lobby.lua
│  ├─ internal/lobby/lobby-arcade-full-audit-v3.lua
│  ├─ internal/lobby/lobby-arcade-remote-capture-v1.lua
│  └─ internal/lobby/lobby-full-inventory-v1.lua
├─ chapter1.lua
│  └─ internal/chapter1/chapter1-live-diagnostics.lua
├─ chapter2.lua
│  ├─ internal/chapter2/chapter2-no-levers-cutscene-test.lua
│  ├─ internal/chapter2/chapter2-cutscene-deferred-invisible-skip-test.lua
│  ├─ internal/chapter2/chapter2-puzzle-position-diagnostic.lua
│  └─ internal/chapter2/chapter2-no-levers-puzzles-keypad-confirm-test.lua
├─ chapter3.lua
├─ chapter4.lua
├─ chapter5.lua
└─ winter.lua

loader.lua (Chapter 1 fallback)
└─ internal/chapter1/chapter1-tnt3-20261116.lua
   └─ internal/chapter1/chapter1-live-diagnostics.lua

internal/tools/
├─ ch1-fast-start.lua (uses its original pinned immutable release)
├─ arcade-boss-standalone.lua
└─ arcade-two-round-test.lua

needle-cloud/
└─ original cloud and Discord tracker files (unmodified)
```

## Maintenance

- Core module filenames are stable and remain in the repository root.
- Preserve the exact support paths above or update every downloading caller when relocating files.
- `chapter2-no-levers-cutscene-test.lua` is an existing optional standalone bootstrap and separately references an older upgrade helper. This path was not modernized during the organizational cleanup.
- The optional `ch1-fast-start.lua` remains pinned to an older immutable release. Its contents were moved unchanged.
- Existing direct `main/<old-root-tool>.lua` URLs do **not** redirect: use `main/internal/tools/<file>.lua` for standalone tools, or load the old file through the [backup branch](https://github.com/BeyyTU/needlehub/tree/archive/pre-simplified-root-2026-11-21).
- Cloud deployment files are unchanged; the independent cloud service can keep its established build/deploy context.

This was a dependency-path/source audit, not a runtime Roblox test.
