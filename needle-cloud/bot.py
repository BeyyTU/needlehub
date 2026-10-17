"""Local Discord leaderboard publisher. Python 3.10+, standard library only."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.request

UTC = dt.timezone.utc


def validate(data):
    if not isinstance(data, dict):
        raise ValueError("Snapshot must be a JSON object")
    if data.get("version") != 1 or data.get("status") != "ok":
        raise ValueError("Collector is waiting; keep WEEKLY wins loaded")
    if data.get("period") != "WEEKLY" or data.get("placeId") != 77108422251420:
        raise ValueError("Snapshot is not the lobby WEEKLY leaderboard")
    stamp = dt.datetime.fromisoformat(data["observedAt"].replace("Z", "+00:00"))
    if stamp.tzinfo is None or stamp > dt.datetime.now(UTC) + dt.timedelta(seconds=60):
        raise ValueError("Invalid observation time")
    rows = data["rows"]
    if not isinstance(rows, list) or not 1 <= len(rows) <= 1000:
        raise ValueError("Invalid row count")
    users = set()
    expected_rank = 0
    previous_wins = None
    for i, row in enumerate(rows, 1):
        if not re.fullmatch(r"[A-Za-z0-9_]{1,30}", row["username"]):
            raise ValueError("Invalid Roblox username")
        if row["username"].lower() in users:
            raise ValueError("Duplicate username")
        users.add(row["username"].lower())
        if type(row["wins"]) is not int or row["wins"] < 0:
            raise ValueError("Invalid wins")
        if i > 1 and rows[i-2]["wins"] < row["wins"]:
            raise ValueError("Wins are not sorted")
        if previous_wins is None or row["wins"] != previous_wins:
            expected_rank += 1
        if type(row["rank"]) is not int or row["rank"] != expected_rank:
            raise ValueError("Ranks must match the board: equal wins share a rank")
        previous_wins = row["wins"]
    return stamp


def payloads(data, issue=None):
    stamp = validate(data)
    pages = []
    chunks = [data["rows"][offset:offset+25] for offset in range(0, len(data["rows"]), 25)]
    for page, rows in enumerate(chunks, 1):
        lines = ["```text", "Rank  Player                   Weekly wins"]
        for row in rows:
            placement = "#" + str(row["rank"])
            lines.append(f'{placement:>4}  {row["username"]:<24} {row["wins"]:>8,}')
        lines.append("```")
        lines.append(f'All {len(data["rows"])} loaded players • Page {page}/{len(chunks)}')
        lines.append(f'Last observed: <t:{int(stamp.timestamp())}:R>')
        pages.append({"allowed_mentions": {"parse": []}, "embeds": [{
            "title": f"Search for the Needle — Weekly Wins ({page}/{len(chunks)})",
            "description": "\n".join(lines), "color": 0xE6AD35 if issue else 0x41A572,
        }]})
    return pages


def payload(data, issue=None):
    """First-page preview kept for callers of the original helper."""
    return payloads(data, issue)[0]


def clan_payloads(data):
    clans = data.get("clans")
    if not isinstance(clans, dict) or clans.get("status") != "ok" or clans.get("scope") != "CLAN_MEMBERS":
        unavailable = "Clan members were not available in this capture. Run the updated lobby script to capture the member list under Clan → Clan."
        if isinstance(clans, dict) and clans.get("status") == "not_in_clan":
            unavailable = "This Roblox account is not currently in a clan."
        return [{"allowed_mentions": {"parse": []}, "embeds": [{
            "title": "Search for the Needle — Clan Wins",
            "description": unavailable,
            "color": 0xE6AD35,
        }]}]
    rows = clans.get("rows")
    if not isinstance(rows, list) or not 1 <= len(rows) <= 1000:
        raise ValueError("Invalid clan row count")
    identities = set()
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("displayName"), str) or not 1 <= len(row["displayName"]) <= 100:
            raise ValueError("Invalid clan member name")
        if type(row.get("wins")) is not int or row["wins"] < 0:
            raise ValueError("Invalid clan member wins")
        identity = row.get("userId")
        if not isinstance(identity, str) or not re.fullmatch(r"\d{1,20}", identity):
            raise ValueError("Invalid clan member identity")
        if identity in identities:
            raise ValueError("Duplicate clan member")
        identities.add(identity)
    def display(value):
        return " ".join(str(value).replace("`", "'").split())
    rows = sorted(rows, key=lambda row: (-row["wins"], row["displayName"].casefold(), row["userId"]))
    clan_name = display(clans.get("clanName", "Your clan"))[:150]
    stamp = dt.datetime.fromisoformat(clans.get("observedAt", data["observedAt"]).replace("Z", "+00:00"))
    chunks = [rows[offset:offset+25] for offset in range(0, len(rows), 25)]
    pages = []
    rank, previous_wins = 0, None
    for index, chunk in enumerate(chunks, 1):
        lines = ["```text", "Rank  Member                   Role         Wins"]
        for row in chunk:
            if row["wins"] != previous_wins:
                rank += 1
            previous_wins = row["wins"]
            name = display(row["displayName"])
            name = name if len(name) <= 24 else name[:23] + "…"
            role = display(row.get("role", "MEMBER"))[:8]
            placement = "#" + str(rank)
            lines.append(f'{placement:>4}  {name:<24} {role:<8} {row["wins"]:>8,}')
        lines += ["```", f'{len(rows)} clan members • {sum(row["wins"] for row in rows):,} combined wins • Page {index}/{len(chunks)}',
            f'Last observed: <t:{int(stamp.timestamp())}:R>']
        pages.append({"allowed_mentions": {"parse": []}, "embeds": [{
            "title": f"Clan Wins — {clan_name} ({index}/{len(chunks)})",
            "description": "\n".join(lines), "color": 0x8064CA,
        }]})
    return pages


def leaderboard_tabs(data):
    return {"players": payloads(data), "clans": clan_payloads(data)}


def as_tabs(pages):
    if isinstance(pages, list):
        return {"players": pages, "clans": clan_payloads({})}
    return pages


def initialize_messages(db):
    db.execute("CREATE TABLE IF NOT EXISTS messages (channel TEXT PRIMARY KEY, message TEXT)")
    db.execute("CREATE TABLE IF NOT EXISTS message_pages (channel TEXT, page INTEGER, message TEXT, retired INTEGER DEFAULT 0, PRIMARY KEY(channel, page))")
    db.execute("CREATE TABLE IF NOT EXISTS pager_state (channel TEXT PRIMARY KEY, message TEXT, pages TEXT, page INTEGER)")
    db.execute("CREATE TABLE IF NOT EXISTS pager_tabs (channel TEXT PRIMARY KEY, tab TEXT, players_page INTEGER, clans_page INTEGER)")
    db.execute("CREATE TABLE IF NOT EXISTS pager_history (channel TEXT PRIMARY KEY, digest TEXT)")
    # Reuse the old top-20 message as page one instead of posting another header.
    db.execute("INSERT OR IGNORE INTO message_pages(channel,page,message) SELECT channel,0,message FROM messages")
    db.commit()


def navigation_payload(pages, page, tab="players"):
    tabs = as_tabs(pages)
    pages = tabs[tab]
    page = max(0, min(page, len(pages) - 1))
    body = json.loads(json.dumps(pages[page]))
    for embed in body.get("embeds", []):
        embed.pop("footer", None)
        if "description" in embed:
            embed["description"] = "\n".join(line for line in embed["description"].splitlines()
                if line != "Observation time reflects the collector, not a confirmed game refresh.")
    def button(label, action, disabled=False, style=2):
        return {"type": 2, "style": style, "label": label,
                "custom_id": "needle:" + action, "disabled": disabled}
    body["components"] = [{"type": 1, "components": [
        button("First", "first", page == 0),
        button("Previous", "previous", page == 0),
        button(f"Page {page+1} / {len(pages)}", "page", True),
        button("Next", "next", page == len(pages)-1, 1),
        button("Last", "last", page == len(pages)-1),
    ]}, {"type": 1, "components": [
        button("Player Wins", "tab_players", tab == "players", 3 if tab == "players" else 2),
        button("Clan Wins", "tab_clans", tab == "clans", 3 if tab == "clans" else 2),
    ]}, {"type": 1, "components": [
        button("Older snapshot", "older_snapshot"),
        button("Latest", "latest_snapshot", False, 1),
        button("Newer snapshot", "newer_snapshot"),
    ]}]
    return body


def select_page(current, count, action):
    choices = {"first": 0, "previous": current-1, "next": current+1, "last": count-1}
    if action not in choices:
        raise ValueError("Unknown page action")
    return max(0, min(choices[action], count-1))


def publish_pages(db, token, channel, pages, start_page=0, start_tab="players", reset_tabs=True, snapshot_digest=None, force_new=False):
    """Publish one interactive message, retaining all pages locally for its buttons."""
    path = f"/channels/{channel}/messages"
    page = max(0, min(start_page, len(as_tabs(pages)[start_tab])-1))
    record = db.execute("SELECT message FROM messages WHERE channel=?", (channel,)).fetchone()
    payload = navigation_payload(pages, page, start_tab)
    previous_message = record[0] if record else None
    try:
        result = discord_request(token, "POST" if force_new or not record else "PATCH",
            path if force_new or not record else path + "/" + record[0], payload)
    except urllib.error.HTTPError as exc:
        if exc.code != 404 or not record:
            raise
        # A saved Discord message can be deleted or become inaccessible between
        # deployments. Clear only its pointer and recreate it immediately so a
        # stale message ID cannot hold captures or /lastlog for the retry delay.
        db.execute("DELETE FROM messages WHERE channel=?", (channel,))
        db.execute("DELETE FROM pager_state WHERE channel=?", (channel,))
        db.execute("DELETE FROM message_pages WHERE channel=? AND page=0", (channel,))
        db.commit()
        result = discord_request(token, "POST", path, payload)
    message = result["id"]
    db.execute("INSERT OR REPLACE INTO messages VALUES (?,?)", (channel,message))
    db.execute("INSERT OR REPLACE INTO message_pages VALUES (?,0,?,0)", (channel,message))
    db.execute("INSERT OR REPLACE INTO pager_state VALUES (?,?,?,?)", (channel,message,json.dumps(pages),page))
    if reset_tabs:
        db.execute("INSERT OR REPLACE INTO pager_tabs VALUES (?,?,?,?)", (channel,start_tab,
            page if start_tab == "players" else 0, page if start_tab == "clans" else 0))
    else:
        db.execute("INSERT OR IGNORE INTO pager_tabs VALUES (?,?,?,?)", (channel,start_tab,
            page if start_tab == "players" else 0, page if start_tab == "clans" else 0))
    if snapshot_digest:
        db.execute("INSERT OR REPLACE INTO pager_history VALUES (?,?)", (channel,snapshot_digest))
    db.commit()
    # Resending replaces the old interactive post. Cleanup is best-effort: a failed
    # delete must never turn a successfully sent leaderboard into a slash-command error.
    old_messages = []
    if force_new and previous_message and previous_message != message:
        old_messages.append((0, previous_message))
    # Remove only this bot's old additional leaderboard messages, identified by saved IDs.
    old_messages.extend(db.execute("SELECT page,message FROM message_pages WHERE channel=? AND page>0", (channel,)).fetchall())
    for old_page, old_message in old_messages:
        if old_message == message:
            if old_page > 0:
                db.execute("DELETE FROM message_pages WHERE channel=? AND page=?", (channel,old_page))
                db.commit()
            continue
        try:
            discord_request(token, "DELETE", path + "/" + old_message)
        except urllib.error.HTTPError as exc:
            if exc.code != 404:
                print(f"Could not remove previous leaderboard message ({exc.code}); new message is active.", flush=True)
        except OSError as exc:
            print("Could not remove previous leaderboard message (" + type(exc).__name__ + "); new message is active.", flush=True)
        if old_page > 0:
            db.execute("DELETE FROM message_pages WHERE channel=? AND page=?", (channel,old_page))
            db.commit()


def discord_request(token, method, path, body=None):
    request = urllib.request.Request("https://discord.com/api/v10" + path,
        data=json.dumps(body).encode() if body is not None else None, method=method, headers={
            "Authorization": "Bot " + token, "Content-Type": "application/json",
            "User-Agent": "DiscordBot (https://discord.com/developers/docs, 1.0)",
        })
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read()
        return json.loads(raw) if raw else None


def discord_error_summary(exc):
    if isinstance(exc, urllib.error.HTTPError):
        try:
            payload = json.loads(exc.read())
            code = payload.get("code")
            message = str(payload.get("message", "request rejected"))[:180]
            return f"Discord HTTP {exc.code} (code {code}): {message}"
        except (ValueError, TypeError, OSError):
            return f"Discord HTTP {exc.code}: request rejected"
    detail = str(exc).strip()
    return type(exc).__name__ + (": " + detail[:140] if detail else "")


def verify_destination(token, channel, guild=None):
    identity = discord_request(token, "GET", "/users/@me")
    if identity.get("id") != "1560471076054634537" or not identity.get("bot"):
        raise ValueError("Use the token for Needle Weekly Tracker, not another bot.")
    destination = discord_request(token, "GET", f"/channels/{channel}")
    if destination.get("type") not in (0, 5, 10, 11, 12):
        raise ValueError("Use a text channel, announcement channel, or thread ID. Forum channels need a thread ID.")
    if not destination.get("guild_id") or (guild and destination["guild_id"] != guild):
        raise ValueError("Channel does not match the server in your link.")
    print("Verified Needle Weekly Tracker -> destination channel " + channel)


def initialize_deliveries(db):
    db.execute("CREATE TABLE IF NOT EXISTS snapshots (observed_at TEXT PRIMARY KEY, digest TEXT, body TEXT)")
    db.execute("CREATE TABLE IF NOT EXISTS snapshot_deliveries (channel TEXT, digest TEXT, PRIMARY KEY(channel,digest))")
    initialize_messages(db)
    db.execute("CREATE TABLE IF NOT EXISTS pager_state (channel TEXT PRIMARY KEY, message TEXT, pages TEXT, page INTEGER)")
    db.commit()


def handle_navigation(db, token, channel, event):
    if event.get("channel") != channel:
        return False
    record = db.execute("SELECT message,pages,page FROM pager_state WHERE channel=?", (channel,)).fetchone()
    if not record or event.get("message") != record[0]:
        return False
    pages = json.loads(record[1])
    tabs = as_tabs(pages)
    saved = db.execute("SELECT tab,players_page,clans_page FROM pager_tabs WHERE channel=?", (channel,)).fetchone()
    tab, player_page, clan_page = saved or ("players", record[2], 0)
    action = event.get("action")
    if action in ("older_snapshot", "newer_snapshot", "latest_snapshot"):
        history = db.execute("SELECT digest,body FROM snapshots ORDER BY observed_at,digest").fetchall()
        if not history:
            return False
        pointer = db.execute("SELECT digest FROM pager_history WHERE channel=?", (channel,)).fetchone()
        current = next((i for i, item in enumerate(history) if pointer and item[0] == pointer[0]), len(history)-1)
        target = len(history)-1 if action == "latest_snapshot" else max(0, min(len(history)-1,
            current + (-1 if action == "older_snapshot" else 1)))
        digest, body = history[target]
        publish_pages(db, token, channel, leaderboard_tabs(json.loads(body)), start_tab=tab, snapshot_digest=digest)
        return True
    if action in ("tab_players", "tab_clans"):
        tab = action.removeprefix("tab_")
        page = min(player_page if tab == "players" else clan_page, len(tabs[tab])-1)
    else:
        page = select_page(record[2], len(tabs[tab]), action)
    discord_request(token, "PATCH", f"/channels/{channel}/messages/{record[0]}", navigation_payload(pages,page,tab))
    db.execute("UPDATE pager_state SET page=? WHERE channel=?", (page,channel))
    db.execute("INSERT OR REPLACE INTO pager_tabs VALUES (?,?,?,?)", (channel,tab,
        page if tab == "players" else player_page, page if tab == "clans" else clan_page))
    db.commit()
    return True


def restore_saved_view(db, token, channel):
    state = db.execute("SELECT pages,page FROM pager_state WHERE channel=?", (channel,)).fetchone()
    pointer = db.execute("SELECT digest FROM pager_history WHERE channel=?", (channel,)).fetchone()
    saved = db.execute("SELECT body,digest FROM snapshots WHERE digest=?", (pointer[0],)).fetchone() if pointer else None
    if not saved:
        saved = db.execute("SELECT body,digest FROM snapshots ORDER BY observed_at DESC LIMIT 1").fetchone()
    if not state and not saved:
        return False
    tab = db.execute("SELECT tab FROM pager_tabs WHERE channel=?", (channel,)).fetchone()
    rendered = leaderboard_tabs(json.loads(saved[0])) if saved else json.loads(state[0])
    publish_pages(db, token, channel, rendered, start_page=state[1] if state else 0,
        start_tab=tab[0] if tab else "players", reset_tabs=False, snapshot_digest=saved[1] if saved else None)
    return True


def register_commands(token, guilds=()):
    # Upsert this command alone, preserving any other application commands.
    command = {
        "name": "lastlog", "description": "Show the latest saved Player Wins and Clan Wins capture",
        "type": 1, "integration_types": [0], "contexts": [0]}
    discord_request(token, "POST", "/applications/1560471076054634537/commands", command)
    for guild in guilds:
        if str(guild).isdigit():
            discord_request(token, "POST", f"/applications/1560471076054634537/guilds/{guild}/commands", command)


def clear_old_lastlog_links(token, channel):
    """Delete this bot's old slash-command link notices from the channel."""
    try:
        recent = discord_request(token, "GET", f"/channels/{channel}/messages?limit=100")
    except Exception as exc:
        print("Could not check old /lastlog notices (" + discord_error_summary(exc) + ").", flush=True)
        return
    for message in recent or []:
        author = message.get("author") or {}
        if author.get("id") != "1560471076054634537":
            continue
        if not str(message.get("content", "")).startswith("Latest saved leaderboard:"):
            continue
        try:
            discord_request(token, "DELETE", f"/channels/{channel}/messages/{message['id']}")
        except urllib.error.HTTPError as exc:
            if exc.code != 404:
                print(f"Could not delete an old /lastlog link ({exc.code}).", flush=True)
        except Exception as exc:
            print("Could not delete an old /lastlog link (" + type(exc).__name__ + ").", flush=True)


def handle_lastlog(db, token, event):
    channel = event["channel"]
    saved = db.execute("SELECT body,digest FROM snapshots ORDER BY observed_at DESC,digest DESC LIMIT 1").fetchone()
    response = "/webhooks/1560471076054634537/" + event["response_token"] + "/messages/@original"
    if not saved:
        discord_request(token, "PATCH", response, {
            "content": "No leaderboard captures have been saved yet. Run the lobby collector first.",
            "allowed_mentions": {"parse": []}})
        return False

    pages = leaderboard_tabs(json.loads(saved[0]))
    publish_pages(db, token, channel, pages, snapshot_digest=saved[1], force_new=True)
    # Remove legacy link notices, then remove this command's now-unneeded deferred reply.
    clear_old_lastlog_links(token, channel)
    try:
        discord_request(token, "DELETE", response)
    except Exception as exc:
        print("Could not remove the /lastlog acknowledgement (" + discord_error_summary(exc) + ").", flush=True)
        # The channel already has the interactive board; finish the interaction cleanly.
        try:
            discord_request(token, "PATCH", response, {
                "content": "Leaderboard posted in this channel.",
                "allowed_mentions": {"parse": []}})
        except Exception as finish_exc:
            print("/lastlog acknowledgement completion failed: " + discord_error_summary(finish_exc), flush=True)
    return True


class ButtonConnectionUnavailable(RuntimeError):
    pass


def start_buttons(db, lock, token, channel):
    register_commands(token)
    bundled = Path(r"C:\Users\Josht\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe")
    executable = str(bundled) if bundled.is_file() else shutil.which("node")
    helper = Path(__file__).with_name("gateway.mjs")
    if not helper.is_file():
        helper = Path(r"C:\Users\Josht\Documents\Codex\2026-10-15\co\outputs\needle-discord-tracker\gateway.mjs")
    if not executable or not helper.is_file():
        raise SystemExit("Button listener files missing. Extract the updated complete tracker package.")
    settings = os.environ.copy()
    settings.update(DISCORD_BOT_TOKEN=token, DISCORD_CHANNEL_ID=channel)
    with lock:
        known_channels = {row[0] for row in db.execute("SELECT channel FROM messages")}
    settings["DISCORD_BUTTON_CHANNEL_IDS"] = ",".join(sorted(known_channels | {channel}))
    worker = subprocess.Popen([executable, str(helper)], env=settings, stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    ready, failure = threading.Event(), []
    def read_events():
        for line in worker.stdout:
            try:
                event = json.loads(line)
            except ValueError:
                continue  # Do not print raw packets or runtime errors that might contain secrets.
            if event.get("kind") in ("ready", "status", "fatal"):
                print(event.get("message", "Button listener status changed."), flush=True)
                if event["kind"] == "ready":
                    register_commands(token, event.get("guilds", ()))
                    print("/lastlog registered in connected servers.", flush=True)
                    ready.set()
                if event["kind"] == "fatal": failure.append(True); ready.set()
            elif event.get("kind") == "lastlog":
                try:
                    with lock:
                        handle_lastlog(db, token, event)
                except Exception as exc:
                    print("/lastlog failed: " + discord_error_summary(exc), flush=True)
                    # The gateway already deferred the public interaction. Always finish
                    # that response, even if rendering or channel state fails.
                    fallback = "/webhooks/1560471076054634537/" + event["response_token"] + "/messages/@original"
                    try:
                        discord_request(token, "PATCH", fallback, {
                            "content": "I couldn't display the leaderboard. Please try `/lastlog` again in a moment.",
                            "allowed_mentions": {"parse": []}})
                    except Exception as fallback_exc:
                        print("/lastlog fallback failed: " + discord_error_summary(fallback_exc), flush=True)
            elif event.get("kind") == "navigate":
                for attempt in range(3):
                    try:
                        with lock:
                            target = event.get("channel")
                            if db.execute("SELECT 1 FROM messages WHERE channel=?", (target,)).fetchone():
                                handle_navigation(db, token, target, event)
                        break
                    except urllib.error.HTTPError as exc:
                        if exc.code == 429 and attempt < 2:
                            try:
                                retry = max(1, float(json.loads(exc.read()).get("retry_after", 5)))
                            except (ValueError, TypeError):
                                retry = 5
                            time.sleep(retry)
                        else:
                            print("Page change failed. Please click the button again.", flush=True)
                            break
                    except (OSError, ValueError, KeyError, TypeError):
                        print("Page change interrupted. Please click the button again.", flush=True)
                        break
        if not ready.is_set(): failure.append(True); ready.set()
    threading.Thread(target=read_events, daemon=True).start()
    connected = ready.wait(25)
    if not connected or failure:
        worker.stdin.close()
        worker.terminate()
        if failure:
            raise SystemExit("Button listener rejected or could not start. Check the status above.")
        raise ButtonConnectionUnavailable("Button connection delayed; retrying automatically.")
    worker.button_failure = failure
    return worker


def consume_snapshot(db, token, channel, source):
    """Claim one input, publish all pages, then delete only that claimed input.

    Atomic rename protects a newer lobby file arriving while Discord is updating.
    Failed Discord calls leave the claimed file intact for the next retry.
    """
    pending = source.with_name(source.stem + ".processing" + source.suffix)
    if not pending.exists():
        try:
            source.replace(pending)
        except FileNotFoundError:
            return False
    raw = pending.read_bytes()
    data = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(data, dict):
        raise ValueError("Snapshot must be a JSON object")
    if data.get("status") == "waiting" and not data.get("rows"):
        pending.unlink()  # Old collector status packet, not a leaderboard snapshot.
        print("Waiting for a successful lobby capture.")
        return False
    validate(data)
    digest = hashlib.sha256(raw).hexdigest()
    delivered = db.execute("SELECT 1 FROM snapshot_deliveries WHERE channel=? AND digest=?", (channel,digest)).fetchone()
    if not delivered:
        pages = leaderboard_tabs(data)
        publish_pages(db, token, channel, pages, snapshot_digest=digest)
        # Commit the receipt before cleanup so a restart after a failed unlink
        # does not republish this capture. All captured rows remain in history.
        db.execute("INSERT OR REPLACE INTO snapshots VALUES (?,?,?)",
            (data["observedAt"], digest, json.dumps(data)))
        db.execute("INSERT OR IGNORE INTO snapshot_deliveries VALUES (?,?)", (channel,digest))
        db.commit()
        print(f"Updated {len(data['rows'])} players; Player Wins and Clan Wins tabs ready.")
    pending.unlink()
    print("Used input file removed. Waiting for the next lobby capture.")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, default=Path(os.environ["LOCALAPPDATA"]) /
        "Potassium/workspace/needle-weekly-live.json" if "LOCALAPPDATA" in os.environ
        else Path("needle-weekly-live.json"))
    parser.add_argument("--queue", type=Path, help="Process uploaded lobby captures from this directory")
    parser.add_argument("--preview", action="store_true", help="Print Discord payload without posting")
    args = parser.parse_args()
    if args.preview:
        print(json.dumps(leaderboard_tabs(json.loads(args.snapshot.read_text(encoding="utf-8-sig"))), indent=2))
        return
    token = os.environ.get("DISCORD_BOT_TOKEN", "").strip()
    channel = os.environ.get("DISCORD_CHANNEL_ID", "").strip()
    if not token or not channel.isdigit():
        parser.error("Set DISCORD_BOT_TOKEN and DISCORD_CHANNEL_ID locally first")
    try:
        verify_destination(token, channel, os.environ.get("DISCORD_GUILD_ID"))
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"Discord setup check failed (HTTP {exc.code}). Check bot token and channel access.")
    except (OSError, ValueError, KeyError) as exc:
        raise SystemExit("Discord setup check failed: " + str(exc))
    database_path = Path(os.environ.get("TRACKER_DB_PATH", str(Path(__file__).with_name("history.sqlite3"))))
    database_path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(database_path, check_same_thread=False)
    initialize_deliveries(db)
    lock = threading.RLock()
    gateway = None
    needs_restore = True
    print("Tracker ready. Watching for new lobby captures every 5 seconds.")
    while True:
        delay = 5
        try:
            if gateway is not None and gateway.button_failure:
                raise SystemExit("Discord rejected the button connection. Check the status above.")
            if gateway is None or gateway.poll() is not None:
                if gateway is not None:
                    gateway.stdin.close()
                    print("Button listener stopped unexpectedly; restarting it automatically.", flush=True)
                gateway = start_buttons(db, lock, token, channel)
            with lock:
                # Restore buttons from history even when the input JSON was already consumed.
                if needs_restore:
                    restore_saved_view(db, token, channel)
                    needs_restore = False
                if args.queue:
                    args.queue.mkdir(parents=True, exist_ok=True)
                    for queued in sorted(args.queue.glob("*.json")):
                        source = queued.with_name(queued.name.replace(".processing.json", ".json"))
                        consume_snapshot(db, token, channel, source)
                else:
                    consume_snapshot(db, token, channel, args.snapshot)
        except ButtonConnectionUnavailable as exc:
            print(str(exc), flush=True)
            delay = 10
        except urllib.error.HTTPError as exc:
            print("Discord HTTP status:", exc.code, "— input retained for retry.")
            if exc.code in (401, 403):
                raise SystemExit("Check bot token and channel permissions locally.")
            delay = 60
            if exc.code == 429:
                try:
                    delay = max(60, float(json.loads(exc.read())["retry_after"]) + 1)
                except (ValueError, KeyError, TypeError):
                    delay = 120
        except (OSError, ValueError, KeyError, TypeError) as exc:
            print("Input retained; waiting to retry:", type(exc).__name__)
        time.sleep(delay)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Stopped.")

