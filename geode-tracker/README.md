# Crack the Geode Discord Tracker

Separate bot and passive BeyyHub companion for experience **10770110947**.

## What is ready

- Watches `ReplicatedStorage.MTG.Remotes.PetEvents` (secret announcements) and `PetDrop` (boss announcements), including remotes that appear after startup.
- Saves actual `Name`, `Pet`, `User`, `Odds`, `Type`, `Global`, and `Serial` values. Does not guess odds denominators or assume `Name` means the player.
- Separate Discord channels for boss pets, secrets and global leaderboards.
- Secret announcements and secret history are hidden by default. A server manager can use `/geode-settings show-secrets: true` to show them or `false` to hide them again. Hidden announcements are retained in the database but are not posted later when re-enabled. Previously posted Discord messages are unchanged.
- Pet cards show a display name, username, discovery serial and odds where provided. Numeric player IDs and raw transport fields are not shown.
- The collector captures available artwork from the game's `PetPortrait.rect` helper and pet definitions. The server crops sprite-sheet portraits and serves cached PNG thumbnails. Private assets use Roblox's public thumbnails where possible; unknown atlas dimensions or unavailable portraits fall back to text without substituting decorative UI art.
- SQLite pet history, restart-safe pending Discord deliveries, editable global leaderboard messages, paginated slash-command results.
- Each hub execution captures the current global boards and updates the existing leaderboard messages, even if the hub instance is reused. Routine polling also edits those messages in place. Missing/deleted messages are recreated. If lobby boards are unavailable, the last stored global snapshots keep their original observation times. Pending repost jobs from the previous behavior are cancelled.
- `/geode-leaderboards`, `/geode-leaderboard`, `/geode-hatches`, `/geode-petstats`, `/geode-setup`, `/geode-settings`.
- Can connect before being invited. Invite to `jhit inc`, then use `/geode-setup` with Manage Server permission to select boss, secret and leaderboard text channels. This configuration persists in SQLite.
- Current-server numeric `leaderstats` snapshots. These are labelled **server-only** and available through slash commands.
- Built-in adapters for Top Miners, Deepest Endless, Fastest Hard, Fastest Escapes and Top Wins. Duplicate label names are resolved by column positions; ranks, team labels, rounded scores and race times are preserved as displayed.
- Automatic startup/unload integration in BeyyHub's Geode loader v5 (collector v4). Private settings are read from the executor's `Geode/tracker_config.json`, never published with the hub. The main gameplay module is unchanged.

## What still needs live confirmation

The supplied leaderboard capture identifies all five native lobby board paths. Native adapters now run automatically when those objects are present. In run places where the lobby boards do not exist, the tracker retains the last observed snapshots rather than fabricating fresh scores. It observes the active loaded board view without switching tabs or firing remotes. It does not independently fetch every All Players/F2P/cavern tab.

The actual pet field meanings still need confirmation from live awards. Unknown scalar/table fields are preserved; odds are not guessed.

This is an observed-event feed, not server-authoritative inventory verification. It only sees announcements delivered to a running collector. A `Global` field does not establish complete coverage. It cannot recover hatches that happened while no collector was online. Counts are observed announcements, not all-time game totals.

Boss deduplication uses pet + serial; secrets without a stable ID use matching fields within 15 seconds. Two identical legitimate hatches in that interval may merge. Discord sends retry from SQLite; an outage between send and database acknowledgement may rarely duplicate a message beyond Discord's nonce window. Unknown/malformed captures are saved locally for inspection.

## First step: collect actual values and board structure

The normal Geode `loader-beyy.lua` includes the collector, so a second loadstring is unnecessary. Reload the normal loader after this update to capture available pet names and portrait metadata. A private upload configuration was installed on the connected Potassium client. On other devices, configure `Geode/tracker_config.json` with the service URL and upload key. With no upload key, capture-only mode writes locally and uploads nothing.

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
    GlobalBoards = {}, -- optional additional adapters; five native adapters are built in
}
-- Execute collector.lua after this configuration.
```

The local pending queue holds up to 200 captures, persists if executor filesystem APIs exist, and uploads observations up to 24 hours old. Re-execution disconnects the previous observer. Rerun after teleports or join it to your existing teleport loader. It does not add automatic teleport execution itself.

## Global GUI adapter format

The built-in native adapters emit `format: display`, with each row's `rank`, `label`, and `displayValue`. This preserves team names and times as well as rounded scores without claiming exact totals.

Optional additional numeric adapters need `Id`, `Title`, `RowsPath`, `UsernamePath`, `ValuePath`, and optional `TemplateName`. Paths are arrays of exact names. Numeric adapters still require full integer scores and plain usernames; use the native displayed-row format for abbreviations, teams and times.

## Local verification

Requires Node.js 24+. Run `npm ci`, then `npm test`. Tests cover uploads, deduplication, snapshot ordering, displayed board values, command acknowledgements, server restrictions, secret visibility, clean pet formatting and safe image cropping/caching. Run with `node --env-file=.env server.mjs` after copying `.env.example` to a private `.env`.

Railway startup and Discord command handling have been verified live. The native board parser also has in-client fixture checks; full live board refresh needs lobby boards to be present. The existing Needle deployment is unchanged.

References: [Discord.js documentation](https://discord.js.org/docs/packages/discord.js/main), [Discord application commands](https://discord.com/developers/docs/interactions/application-commands). This executor collector is not a standard Roblox LocalScript; standard server-side [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService) is a different integration path.
