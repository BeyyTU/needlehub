# BeyyHub — PRIMAL: Evolved

Target place: `125688046049749` ([Roblox experience](https://www.roblox.com/games/125688046049749/PRIMAL-Evolved)).

This directory keeps PRIMAL work separate from other projects. Each utility is an independent Luau file, with its own version and entry point. No existing project loader imports this directory.

## Files

- `place_check.lua` — read-only place identity and game version check using standard Roblox properties.

## Conventions

- Keep one purpose per script; avoid implicit dependencies.
- Use explicit versions and place checks where relevant.
- Public gameplay notes and authorized Studio diagnostics are separate from live gameplay.
- Do not commit credentials, private player data, or private game source.

This project contains no gameplay modifications or remote invocation.
