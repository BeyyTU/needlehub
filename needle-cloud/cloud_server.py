"""Small authenticated upload endpoint for the hosted tracker."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hmac
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

from bot import validate


def make_handler(inbox, upload_key):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass  # Request headers, including the upload key, must never enter logs.

        def reply(self, code, message):
            body = json.dumps({"message": message}).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            self.reply(200, "ready") if self.path == "/health" else self.reply(404, "not found")

        def do_POST(self):
            if self.path != "/upload":
                return self.reply(404, "not found")
            supplied = self.headers.get("Authorization", "")
            if not hmac.compare_digest(supplied, "Bearer " + upload_key):
                return self.reply(401, "unauthorized")
            try:
                length = int(self.headers.get("Content-Length", ""))
            except ValueError:
                return self.reply(400, "invalid length")
            if not 1 <= length <= 1_000_000:
                return self.reply(413, "capture too large")
            raw = self.rfile.read(length)
            try:
                data = json.loads(raw.decode("utf-8-sig"))
                validate(data)
            except (UnicodeError, ValueError, KeyError, TypeError):
                return self.reply(400, "invalid leaderboard capture")
            digest = hashlib.sha256(raw).hexdigest()
            path = inbox / (digest + ".json")
            if not path.exists():
                pending = inbox / (digest + ".uploading")
                pending.write_bytes(raw)
                pending.replace(path)
            self.reply(202, "capture accepted")

    return Handler


def main():
    token = os.environ.get("DISCORD_BOT_TOKEN", "")
    channel = os.environ.get("DISCORD_CHANNEL_ID", "")
    upload_key = os.environ.get("NEEDLE_UPLOAD_KEY", "")
    if not token or not channel.isdigit() or len(upload_key) < 32:
        raise SystemExit("Set DISCORD_BOT_TOKEN, DISCORD_CHANNEL_ID, and a random NEEDLE_UPLOAD_KEY of at least 32 characters")
    data_dir = Path(os.environ.get("TRACKER_DATA_DIR", "/data"))
    inbox = data_dir / "inbox"
    inbox.mkdir(parents=True, exist_ok=True)
    bot_env = os.environ.copy()
    bot_env["TRACKER_DB_PATH"] = str(data_dir / "history.sqlite3")
    bot = subprocess.Popen([sys.executable, str(Path(__file__).with_name("bot.py")), "--queue", str(inbox)], env=bot_env)
    def watch_bot():
        if bot.wait() is not None:
            # Exit the container so the hosting platform can restart it.
            os._exit(1)
    threading.Thread(target=watch_bot, daemon=True).start()
    server = ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), make_handler(inbox, upload_key))
    try:
        server.serve_forever()
    finally:
        bot.terminate()
        bot.wait(timeout=10)


if __name__ == "__main__":
    main()

