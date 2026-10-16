// Discord button listener using the Node.js runtime already bundled on this PC.
// Interaction credentials are forwarded only over private process IPC, never logged or saved.
import { pathToFileURL } from 'node:url';

export class ButtonGateway {
  constructor({ token, channelId, channelIds = [channelId], emit = value => process.stdout.write(JSON.stringify(value) + '\n'),
                fetchImpl = fetch, Socket = WebSocket, reconnectDelay = 1000, random = Math.random }) {
    Object.assign(this, { token, channelId, emit, fetchImpl, Socket, reconnectDelay, random });
    this.channelIds = new Set(channelIds);
    this.api = 'https://discord.com/api/v10';
    this.stopped = false;
    this.sequence = null;
    this.session = null;
    this.resumeUrl = null;
    this.acked = true;
    this.seen = new Set();
    this.backoff = reconnectDelay;
  }
  send(op, d) {
    if (this.socket?.readyState === 1) this.socket.send(JSON.stringify({ op, d }));
  }
  clearTimers() {
    clearTimeout(this.beatTimer);
    clearTimeout(this.connectTimer);
    clearTimeout(this.handshakeTimer);
    clearInterval(this.watchTimer);
  }
  reconnect(message) {
    const old = this.socket;
    this.socket = null;
    this.clearTimers();
    if (old && old.readyState < 2) old.close(4000, 'Reconnecting');
    if (!this.stopped) {
      this.emit({kind:'status',message});
      this.schedule();
    }
  }
  checkLiveness(now = Date.now()) {
    const resumed = this.lastTick && now - this.lastTick > 15000;
    this.lastTick = now;
    if (resumed || (this.lastPacket && now - this.lastPacket > Math.max(90000, (this.interval || 45000) * 3))) {
      this.reconnect('Page buttons reconnecting after an idle connection or PC wake-up...');
    }
  }
  heartbeat(interval) {
    if (!this.acked) { this.reconnect('Page buttons reconnecting: heartbeat acknowledgement missed.'); return; }
    this.acked = false;
    this.send(1, this.sequence);
    this.beatTimer = setTimeout(() => this.heartbeat(interval), interval);
  }
  schedule(delay = this.backoff) {
    if (this.stopped) return;
    clearTimeout(this.connectTimer);
    this.connectTimer = setTimeout(() => void this.connect(), delay);
    this.backoff = Math.min(30000, Math.max(this.reconnectDelay, this.backoff * 2));
  }
  async connect() {
    if (this.stopped) return;
    try {
      if (!this.url || (!this.session && this.limitReset && Date.now() >= this.limitReset)) {
        const response = await this.fetchImpl(this.api + '/gateway/bot', {
          headers: { Authorization: 'Bot ' + this.token }, signal: AbortSignal.timeout(15000)
        });
        if (response.status === 401 || response.status === 403) {
          this.emit({ kind: 'fatal', message: 'Button listener authentication failed.' }); this.stop(); return;
        }
        if (!response.ok) {
          const body = await response.json().catch(() => ({}));
          this.schedule(Math.max(5000, Number(body.retry_after || 0) * 1000)); return;
        }
        const info = await response.json();
        if (typeof info.url !== 'string' || !info.url.startsWith('wss://')) throw Error('Invalid gateway URL');
        this.url = info.url;
        this.remaining = info.session_start_limit?.remaining ?? 1;
        this.limitReset = Date.now() + (info.session_start_limit?.reset_after ?? 60000);
      }
      if (!this.session && this.remaining <= 0) {
        this.emit({ kind: 'status', message: 'Button listener waiting for Discord session reset.' });
        this.schedule(Math.max(1000, this.limitReset - Date.now() + 100)); return;
      }
      if (this.stopped) return;
      this.acked = true;
      const socket = new this.Socket((this.session ? this.resumeUrl : this.url) + '?v=10&encoding=json');
      this.socket = socket;
      this.lastPacket = this.lastTick = Date.now();
      this.watchTimer = setInterval(() => this.checkLiveness(), 5000);
      this.handshakeTimer = setTimeout(() => this.reconnect('Page button handshake delayed; reconnecting...'), 20000);
      socket.addEventListener('message', event => {
        if (this.socket !== socket || this.stopped) return;
        let packet;
        try { packet = JSON.parse(String(event.data)); } catch { return; }
        this.lastPacket = Date.now();
        if (packet.s != null) this.sequence = packet.s;
        if (packet.op === 10) {
          const interval = packet.d.heartbeat_interval;
          this.interval = interval;
          this.beatTimer = setTimeout(() => this.heartbeat(interval), interval * this.random());
          if (this.session && this.sequence != null) {
            this.send(6, { token: this.token, session_id: this.session, seq: this.sequence });
          } else {
            this.remaining -= 1;
            this.send(2, { token: this.token, intents: 0,
              properties: { os: process.platform, browser: 'needle-tracker', device: 'needle-tracker' } });
          }
        } else if (packet.op === 11) {
          this.acked = true;
        } else if (packet.op === 1) {
          this.send(1, this.sequence);
        } else if (packet.op === 7) {
          this.reconnect('Discord requested a page button reconnect.');
        } else if (packet.op === 9) {
          if (!packet.d) { this.session = null; this.sequence = null; this.resumeUrl = null; }
          this.reconnect('Page button session reset; reconnecting...');
        } else if (packet.op === 0 && packet.t === 'READY') {
          this.session = packet.d.session_id;
          clearTimeout(this.handshakeTimer);
          this.resumeUrl = packet.d.resume_gateway_url;
          this.backoff = this.reconnectDelay;
          this.emit({ kind: 'ready', message: 'Page buttons connected.',
            guilds: Array.isArray(packet.d.guilds) ? packet.d.guilds.map(guild => guild.id).filter(Boolean) : [] });
        } else if (packet.op === 0 && packet.t === 'RESUMED') {
          clearTimeout(this.handshakeTimer);
          this.backoff = this.reconnectDelay;
          this.emit({ kind: 'ready', message: 'Page buttons reconnected.' });
        } else if (packet.op === 0 && packet.t === 'INTERACTION_CREATE') {
          void this.interaction(packet.d);
        }
      });
      socket.addEventListener('error', () => {
        if (this.socket === socket && !this.stopped) this.reconnect('Page button connection error; reconnecting...');
      });
      socket.addEventListener('close', event => {
        if (this.socket !== socket || this.stopped) return;
        this.clearTimers();
        if ([4004, 4010, 4011, 4012, 4013, 4014].includes(event.code)) {
          this.emit({ kind: 'fatal', message: 'Discord rejected the button connection (code ' + event.code + ').' });
          this.stop(); return;
        }
        if ([4007, 4009].includes(event.code)) { this.session = null; this.sequence = null; this.resumeUrl = null; }
        this.emit({ kind: 'status', message: 'Page buttons reconnecting...' });
        this.schedule();
      });
    } catch {
      if (!this.stopped) {
        this.emit({ kind: 'status', message: 'Button connection unavailable; retrying...' });
        this.schedule();
      }
    }
  }
  async interaction(value) {
    const actions = ['needle:first', 'needle:previous', 'needle:next', 'needle:last', 'needle:tab_players', 'needle:tab_clans',
      'needle:older_snapshot', 'needle:newer_snapshot', 'needle:latest_snapshot'];
    const command = value.type === 2 && value.data?.name === 'lastlog' && !!value.guild_id;
    if ((!command && value.type !== 3) || value.application_id !== '1560471076054634537'
        || (!command && (!this.channelIds.has(value.channel_id) || !actions.includes(value.data?.custom_id)
        || !value.message?.id)) || this.seen.has(value.id)) return;
    this.seen.add(value.id);
    if (this.seen.size > 1000) this.seen.delete(this.seen.values().next().value);
    try {
      // Acknowledge immediately, before Python may wait on a snapshot update.
      const response = await this.fetchImpl(this.api + '/interactions/' + encodeURIComponent(value.id)
        + '/' + encodeURIComponent(value.token) + '/callback', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(command ? { type: 5, data: { flags: 64 } } : { type: 6 }), signal: AbortSignal.timeout(2500)
      });
      if (!response.ok) {
        this.emit({ kind: 'status', message: 'Page click could not be acknowledged. Please click again.' }); return;
      }
      if (command) {
        this.channelIds.add(value.channel_id);
        this.emit({kind:'lastlog', channel:value.channel_id, guild:value.guild_id, response_token:value.token});
        return;
      }
      this.emit({ kind: 'navigate', channel: value.channel_id, message: value.message.id,
        action: value.data.custom_id.slice('needle:'.length) });
    } catch {
      this.emit({ kind: 'status', message: 'Page click connection interrupted. Please click again.' });
    }
  }
  stop() {
    this.stopped = true;
    this.clearTimers();
    if (this.socket && this.socket.readyState < 2) this.socket.close(1000, 'Tracker stopped');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const token = process.env.DISCORD_BOT_TOKEN;
  const channelId = process.env.DISCORD_CHANNEL_ID;
  if (!token || !channelId || typeof WebSocket !== 'function') {
    process.stdout.write(JSON.stringify({ kind: 'fatal', message: 'Button listener settings or Node runtime missing.' }) + '\n');
    process.exit(1);
  }
  const channelIds = (process.env.DISCORD_BUTTON_CHANNEL_IDS || channelId).split(',').filter(Boolean);
  const gateway = new ButtonGateway({ token, channelId, channelIds });
  process.stdin.resume();
  process.stdin.on('end', () => { gateway.stop(); process.exit(0); });
  process.on('SIGTERM', () => { gateway.stop(); process.exit(0); });
  void gateway.connect();
}

