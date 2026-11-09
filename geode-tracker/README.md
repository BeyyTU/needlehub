# Crack the Geode Discord Tracker

Separate bot and passive BeyyHub companion for experience **10770110947**.

## What is ready

- Watches `ReplicatedStorage.MTG.Remotes.PetEvents` (secret announcements) and `PetDrop` (boss announcements), including remotes that appear after startup.
- Saves actual `Name`, `Pet`, `User`, `Odds`, `Type`, `Global`, and `Serial` values. Does not guess odds denominators or assume `Name` means the player.
- Separate Discord channels for boss pets, secrets and global leaderboards.
- SQLite pet history, restart-safe pending Discord deliveries, editable global leaderboard messages, paginated slash-command results.
- `/geode-leaderboards`, `/geode-leaderboard`, `/geode-hatches`, `/geode-petstats`, `/geode-setup`.
- Can connect before being invited. Invite to `jhit inc`, then use `/geode-setup` with Manage Server permission to select boss, secret and leaderboard text channels. This configuration persists in SQLite.
- Current-server numeric `leaderstats` snapshots. These are labelled **server-only** and available through slash commands.
- Configurable global GUI board adapters and a GUI discovery export.

## What still needs live confirmation

The supplied chat identifies remote names and field names, but contains neither original JSON capture. The actual pet field types and global leaderboard GUI paths are unconfirmed. No global board adapter is enabled by default. Global boards are **not yet connected**.

This is an observed-event feed, not server-authoritative inventory verification. It only sees announcements delivered to a running collector. A `Global` field does not establish complete coverage. It cannot recover hatches that happened while no collector was online. Counts are observed announcements, not all-time game totals.

Boss deduplication uses pet + serial; secrets without a stable ID use matching fields within 15 seconds. Two identical legitimate hatches in that interval may merge. Discord sends retry from SQLite; an outage between send and database acknowledgement may rarely duplicate a message beyond Discord's nonce window. Unknown/malformed captures are saved locally for inspection.

## First step: collect actual values and board structure

Run `roblox/collector.lua` alongside your hub, without credentials. Capture-only mode writes to the executor's `Geode/` folder; nothing is uploaded.

1. Leave the collector running when a boss/secret popup appears.
2. Retrieve `Geode/last_boss_event.json` and `Geode/last_secret_event.json`.
3. Open the game's global leaderboards and run:

```lua
getgenv().GeodeTracker.ExportBoards()
```

4. Share `Geode/leaderboard_gui_capture.json` to map the actual rows. Inspect before sharing: it contains visible player names and UI text. No remote is invoked.

Status: `getgenv().GeodeTracker` exposes `Sent`, `Queued`, `Captured`, `LastError` and `Stop()`.

## Separate Discord bot setup

Create a new application/bot in the Discord Developer Portal. Invite it to your server with the `bot` and `applications.commands` scopes, and View Channels, Send Messages, Embed Links and Read Message History permissions in the three tracker channels. Privileged message-content intent is unnecessary.

Put the token directly into the hosting service's secret variables. Never paste it into chat, Lua, GitHub, screenshots or this README. Supply the guild ID and three channel IDs as ordinary configuration. Developer Mode in Discord exposes Copy ID.

## Railway deployment

Use a **new service** rather than modifying the existing Needle service. Source: this directory. Build with its Dockerfile. Mount a Railway volume at `/data`, use **one replica**, health check `/health`, and generate a public HTTPS domain.

Required variables:

| Variable | Value |
| --- | --- |
| `DISCORD_BOT_TOKEN` | New Geode bot token, stored as a secret |
| `DISCORD_TARGET_GUILD_NAME` | `jhit inc` (default); initial setup restricted to this server name |
| `GEODE_UPLOAD_KEY` | At least 32 random characters |
| `TRACKER_DATA_DIR` | `/data` |

Generate an upload key locally with `node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"`. It authorizes collector submissions only; keep it out of public scripts. A client-held upload key cannot certify awards against a malicious collector.

Alternatively, preconfigure `DISCORD_GUILD_ID`, `GEODE_BOSS_CHANNEL_ID`, `GEODE_SECRET_CHANNEL_ID`, and `GEODE_LEADERBOARD_CHANNEL_ID`. Persisted `/geode-setup` configuration takes precedence. The bot uses no privileged intents and requests no administrator permission.

Configure the collector locally before executing its source:

```lua
getgenv().GeodeTrackerConfig = {
    Url = "https://YOUR-SERVICE.up.railway.app/upload",
    Key = "YOUR_PRIVATE_UPLOAD_KEY",
    BoardInterval = 120,
    GlobalBoards = {}, -- fill using real GUI capture, not assumed paths
}
-- Execute collector.lua after this configuration.
```

The local pending queue holds up to 200 captures, persists if executor filesystem APIs exist, and uploads observations up to 24 hours old. Re-execution disconnects the previous observer. Rerun after teleports or join it to your existing teleport loader. It does not add automatic teleport execution itself.

## Global GUI adapter format

Each configured board needs `Id`, `Title`, `RowsPath`, `UsernamePath`, `ValuePath`, and optional `TemplateName`. All paths are arrays of exact instance names. `RowsPath` starts at `game`; the other paths start at each row. Configure only after identifying the actual GUI. Visible rows must contain plain Roblox usernames and full nonnegative integer scores; commas are supported. Abbreviated values such as `1.2M` are deliberately rejected to avoid publishing guessed scores. Only loaded rows are captured. Displayed Discord placement is score order within those loaded rows; it is not a certified all-game rank.

## Local verification

Requires Node.js 24+. Run `npm ci`, then `npm test`. Six tests cover upload authentication, invalid data, deduplication, pending delivery state, snapshot ordering and payload formatting. Run with `node --env-file=.env server.mjs` after copying `.env.example` to a private `.env`.

Live Roblox event capture and Discord/Railway delivery have not yet been tested. The existing Needle deployment is unchanged.

References: [Discord.js documentation](https://discord.js.org/docs/packages/discord.js/main), [Discord application commands](https://discord.com/developers/docs/interactions/application-commands). This executor collector is not a standard Roblox LocalScript; standard server-side [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService) is a different integration path.
