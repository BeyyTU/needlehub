# BeyyHub — Sell Fries! (v0.1.0)

A first-pass integration for **Sell Fries!** that uses the native BeyyHub interface already used in Crack the Geode. This work is isolated on the `sell-fries` branch of `BeyyTU/needlehub`.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/sell-fries/loader-sell-fries.lua?refresh=" .. tostring(os.time())))()
```

Run this **inside the main game** (place `139542527731344`), not the Sell Fries lobby (place `94891079210424`).

## Main

- **Launch Butter Hub (official)** loads the unmodified `kode-sec/Butter` entry point. Butter may ask for its own official key.
- Butter's protected automation operates through **Butter's own GUI**. BeyyHub does not control its internal auto kitchen, upgrades, repairs, perks, or other switches. It does not bypass Butter's key system.
- BeyyHub controls: pause BeyyHub assists, anti-AFK, nearby production ProximityPrompt assist, walk-speed multiplier (1–4x), prompt scan, config save/load.
- The BeyyHub panel toggles with **RightControl** and can be unloaded without unloading Butter.
- **Status & Logs → Export Debug Diagnostics** writes `BeyyHub/sell_fries_diagnostics.json` when `writefile` is supported, or copies JSON to clipboard when `setclipboard` is supported. It records visible prompt metadata and ReplicatedStorage remote names for future diagnosis. Export contains no keys.
- The proximity prompt assist is **not** a complete auto-farming loop. It only tries supported nearby, visible, production-related prompts and requires `fireproximityprompt`.

## Compatibility and verification

This is an **initial untested game integration**, not a verified replacement for Butter's internal interface. Script files are static and checked for basic source completeness, but have not been executed inside Roblox. Butter's gameplay code is obfuscated and key protected, so a unified UI for Butter's toggles cannot be accurately implemented from the public entry point alone.

## Files

- `loader-sell-fries.lua` — loadstring entry with validated download/cache fallback.
- `sell-fries.lua` — BeyyHub native UI, official Butter launcher, independent assists, diagnostics.
