// Jungle Loop's small server, for Cloudflare Workers with a D1 database (schema.sql).
// What it keeps: players (a pseudonym and a friend code, no e-mail), their best distances (all time and
// this week, per mode), who is friends with whom, the rooms where phones meet before a run together (the
// messages of their WebRTC handshake, a few minutes at most): a coop room holds two, a race room (0.48) the
// host and three more; and the invitations to such a room sent to a friend (two minutes at most).
//
// Every request is a POST of JSON to /api/<route>. A player proves who they are with the secret given at
// creation (only its hash is kept). Nothing here is needed to play: the game works without it.
//
//   player        {name}                                  -> {id, code, secret}
//   player/name   {id, secret, name}                       -> {name}
//   player/delete {id, secret}                             -> {ok}              (0.48: everything about him goes)
//   score         {id, secret, mode, dist}                 -> {best, week}
//   friends/add   {id, secret, code}                       -> {code, name, pending | friends}   (0.57: a request;
//                                                                                friends at once if he had asked me)
//   friends/requests {id, secret}                          -> {incoming: [{code, name, at}], outgoing: [...]}  (0.57)
//   friends/answer {id, secret, code, yes}                 -> {ok, code, name}  (0.57: a request accepted or refused)
//   friends/remove {id, secret, code}                      -> {ok}              (both stop being friends)
//   friends       {id, secret}                             -> {me, friends: [{code, name, best, week, endless, endless_week}]}
//   room          {id, secret, seed}                       -> {room}            (for two)
//   race          {id, secret, seed}                       -> {room}            (0.48: for four, the host and three)
//   room/join     {id, secret, room}                       -> {seed, host, kind, slot}   (kind: coop | race)
//   room/leave    {id, secret, room}                       -> {ok}              (a race guest leaves: his place is free)
//   signal        {id, secret, room, data, to?}            -> {seq}             (to: a friend code; none: the host,
//                                                                                or the other one for two)
//   signals       {id, secret, room, since}                -> {items: [{seq, from, code, name, data}]}
//   ice           {id, secret}                             -> {iceServers: [{urls, username, credential}]}
//   invite        {id, secret, code, room}                 -> {name}            (to a friend, into my room)
//   invites       {id, secret}                             -> {items: [{room, name, code}]}
//   invite/no     {id, secret, room}                       -> {ok}              (the host reads {"t":"no"})
//   room/close    {id, secret, room}                       -> {ok}              (the host left: room and invitation go)
//   feedback      {id, secret, text, version}              -> {ok}              (0.66: a player's word, 5 an hour at most)
//   match         {id, secret}                             -> {room} | {}       (0.66: « Partie rapide »: a room waiting for
//                                                                                players, or none: open one, then match/open)
//   match/open    {id, secret, room}                       -> {ok}              (0.66: my race room waits for players)
//
// ice: the relay (TURN) that carries a coop run when the two phones cannot reach each other directly
// (a 4G / 5G network often forbids it). Cloudflare Realtime's TURN, with short-lived credentials made
// here from two secrets set once by server/turn.ps1 (TURN_KEY_ID, TURN_KEY_TOKEN); without them, an
// empty list (the phones try with STUN only).

const MODES = ['story', 'endless'];
const ROOM_LIFE = 10 * 60 * 1000;          // a room lasts ten minutes (the phones linked stay linked: it is
                                           // only for meeting)
const QUEUE_LIFE = 2 * 60 * 1000;          // 0.66: a quick match's room waits this long without being renewed
const RACE_GUESTS = 3;                     // a race: the host and three more
const INVITE_LIFE = 2 * 60 * 1000;         // an invitation waits two minutes
const TURN_TTL = 4 * 3600;                 // seconds a relay credential lasts: longer than any run for two
const CODE_LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   // no 0/O, 1/I: read aloud without mistakes

const json = (data, status = 200, origin = '*') => new Response(JSON.stringify(data), {
  status,
  headers: { 'content-type': 'application/json', 'access-control-allow-origin': origin, 'access-control-allow-headers': 'content-type' },
});

function letters(n) {
  const b = crypto.getRandomValues(new Uint8Array(n));
  return [...b].map((x) => CODE_LETTERS[x % CODE_LETTERS.length]).join('');
}

async function hash(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((x) => x.toString(16).padStart(2, '0')).join('');
}

// The week a score counts for: Monday 00:00 UTC.
function weekOf(now) {
  const d = new Date(now);
  const day = (d.getUTCDay() + 6) % 7;
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() - day);
  return d.toISOString().slice(0, 10);
}

const cleanName = (s) => String(s || '').replace(/[^\p{L}\p{N} _\-'.]/gu, '').trim().slice(0, 16) || 'Pépito';

// The room `code` (still fresh) if `me` is in it: {r, role: host | guest | member}; else null.
async function inRoom(db, code, me, now) {
  const r = await db.prepare('SELECT code, host, guest, seed, created, kind FROM rooms WHERE code = ?').bind(code).first();
  if (!r || r.created < now - ROOM_LIFE) return null;
  if (r.host === me.id) return { r, role: 'host' };
  if (r.guest === me.id) return { r, role: 'guest' };
  const m = await db.prepare('SELECT 1 FROM members WHERE room = ? AND player = ?').bind(code, me.id).first();
  return m ? { r, role: 'member' } : null;
}

const roomCode = (s) => String(s || '').toUpperCase().trim();

async function who(db, body) {
  if (!body.id || !body.secret) return null;
  const p = await db.prepare('SELECT id, code, name, secret_hash FROM players WHERE id = ?').bind(String(body.id)).first();
  if (!p || p.secret_hash !== await hash(String(body.secret))) return null;
  return p;
}

// A new room for a run on `seed` (kind coop: two phones; race: the host and three more).
async function openRoom(db, body, now, me, kind) {
  await db.prepare('DELETE FROM rooms WHERE created < ?').bind(now - ROOM_LIFE).run();
  await db.prepare('DELETE FROM signals WHERE at < ?').bind(now - ROOM_LIFE).run();
  await db.prepare('DELETE FROM members WHERE at < ?').bind(now - ROOM_LIFE).run();
  const seed = Math.max(0, Math.floor(Number(body.seed) || 0)) % 2147483647;
  for (let tries = 0; tries < 8; tries++) {
    const room = letters(4);
    const taken = await db.prepare('SELECT 1 FROM rooms WHERE code = ?').bind(room).first();
    if (taken) continue;
    await db.prepare('INSERT INTO rooms (code, host, guest, seed, created, kind) VALUES (?, ?, NULL, ?, ?, ?)').bind(room, me.id, seed, now, kind).run();
    return { room };
  }
  return { error: 'busy' };
}

// 0.57: two players become friends (both ways), and the requests between them go.
async function befriend(db, x, y, now) {
  for (const [a, b] of [[x, y], [y, x]]) {
    await db.prepare('INSERT OR IGNORE INTO friends (a, b, since) VALUES (?, ?, ?)').bind(a, b, now).run();
  }
  await db.prepare('DELETE FROM requests WHERE (asker = ? AND target = ?) OR (asker = ? AND target = ?)').bind(x, y, y, x).run();
}

const routes = {
  async 'player'(db, body, now) {
    const id = crypto.randomUUID();
    const secret = letters(24);
    for (let tries = 0; tries < 8; tries++) {
      const code = 'PEPI-' + letters(4);
      const taken = await db.prepare('SELECT 1 FROM players WHERE code = ?').bind(code).first();
      if (taken) continue;
      await db.prepare('INSERT INTO players (id, code, name, secret_hash, created) VALUES (?, ?, ?, ?, ?)')
        .bind(id, code, cleanName(body.name), await hash(secret), now).run();
      return { id, code, secret };
    }
    return { error: 'busy' };
  },

  async 'player/name'(db, body, now, me) {
    const name = cleanName(body.name);
    await db.prepare('UPDATE players SET name = ? WHERE id = ?').bind(name, me.id).run();
    return { name };
  },

  // 0.58: the style of his record's board as his friends see it on their road (a cosmetic of the urns' « social »
  // family: its id, letters, digits and dashes only; '' the wooden one).
  async 'player/look'(db, body, now, me) {
    const sign = String(body.sign || '').toLowerCase().replace(/[^a-z0-9-]/g, '').slice(0, 24);
    await db.prepare('INSERT INTO looks (player, sign) VALUES (?, ?) ON CONFLICT(player) DO UPDATE SET sign = excluded.sign').bind(me.id, sign).run();
    return { sign };
  },

  // 0.48: « Effacer mes données en ligne » (Réglages): the player, his records, friendships, rooms, invitations.
  async 'player/delete'(db, body, now, me) {
    await db.prepare('DELETE FROM friends WHERE a = ? OR b = ?').bind(me.id, me.id).run();
    await db.prepare('DELETE FROM requests WHERE asker = ? OR target = ?').bind(me.id, me.id).run();
    await db.prepare('DELETE FROM scores WHERE player = ?').bind(me.id).run();
    await db.prepare('DELETE FROM looks WHERE player = ?').bind(me.id).run();
    await db.prepare('DELETE FROM invites WHERE guest = ? OR host = ?').bind(me.id, me.id).run();
    await db.prepare('DELETE FROM members WHERE player = ?').bind(me.id).run();
    await db.prepare('DELETE FROM signals WHERE sender = ? OR dest = ?').bind(me.id, me.id).run();
    await db.prepare('DELETE FROM rooms WHERE host = ?').bind(me.id).run();
    await db.prepare('UPDATE rooms SET guest = NULL WHERE guest = ?').bind(me.id).run();
    await db.prepare('DELETE FROM feedback WHERE player = ?').bind(me.id).run();
    await db.prepare('DELETE FROM queue WHERE player = ?').bind(me.id).run();
    await db.prepare('DELETE FROM players WHERE id = ?').bind(me.id).run();
    return { ok: true };
  },

  async 'score'(db, body, now, me) {
    const mode = MODES.includes(body.mode) ? body.mode : 'story';
    const dist = Math.max(0, Math.min(1e6, Math.floor(Number(body.dist) || 0)));
    const week = weekOf(now);
    const old = await db.prepare('SELECT best, week, week_best FROM scores WHERE player = ? AND mode = ?').bind(me.id, mode).first();
    const best = Math.max(dist, old ? old.best : 0);
    const weekBest = old && old.week === week ? Math.max(dist, old.week_best) : dist;
    await db.prepare('INSERT INTO scores (player, mode, best, week, week_best) VALUES (?, ?, ?, ?, ?) ' +
      'ON CONFLICT (player, mode) DO UPDATE SET best = excluded.best, week = excluded.week, week_best = excluded.week_best')
      .bind(me.id, mode, best, week, weekBest).run();
    return { best, week: weekBest };
  },

  // 0.57: adding someone asks him first (a request he accepts or refuses); if he had asked me already, we
  // are friends at once.
  async 'friends/add'(db, body, now, me) {
    const code = String(body.code || '').toUpperCase().trim();
    const f = await db.prepare('SELECT id, code, name FROM players WHERE code = ?').bind(code).first();
    if (!f) return { error: 'unknown' };
    if (f.id === me.id) return { error: 'self' };
    const pal = await db.prepare('SELECT 1 FROM friends WHERE a = ? AND b = ?').bind(me.id, f.id).first();
    if (pal) return { code: f.code, name: f.name, friends: true };
    const asked = await db.prepare('SELECT 1 FROM requests WHERE asker = ? AND target = ?').bind(f.id, me.id).first();
    if (asked) {
      await befriend(db, me.id, f.id, now);
      return { code: f.code, name: f.name, friends: true };
    }
    await db.prepare('INSERT OR REPLACE INTO requests (asker, target, at) VALUES (?, ?, ?)').bind(me.id, f.id, now).run();
    return { code: f.code, name: f.name, pending: true };
  },

  async 'friends/requests'(db, body, now, me) {
    const inc = await db.prepare('SELECT p.code, p.name, r.at FROM requests r JOIN players p ON p.id = r.asker WHERE r.target = ? ORDER BY r.at DESC').bind(me.id).all();
    const out = await db.prepare('SELECT p.code, p.name, r.at FROM requests r JOIN players p ON p.id = r.target WHERE r.asker = ? ORDER BY r.at DESC').bind(me.id).all();
    return { incoming: inc.results, outgoing: out.results };
  },

  async 'friends/answer'(db, body, now, me) {
    const f = await db.prepare('SELECT id, code, name FROM players WHERE code = ?').bind(roomCode(body.code)).first();
    if (!f) return { error: 'unknown' };
    const asked = await db.prepare('SELECT 1 FROM requests WHERE asker = ? AND target = ?').bind(f.id, me.id).first();
    if (!asked) return { error: 'none' };
    if (body.yes === true) await befriend(db, me.id, f.id, now);
    else await db.prepare('DELETE FROM requests WHERE asker = ? AND target = ?').bind(f.id, me.id).run();
    return { ok: true, code: f.code, name: f.name };
  },

  async 'friends/remove'(db, body, now, me) {
    const f = await db.prepare('SELECT id FROM players WHERE code = ?').bind(roomCode(body.code)).first();
    if (!f) return { ok: true };
    await db.prepare('DELETE FROM friends WHERE (a = ? AND b = ?) OR (a = ? AND b = ?)').bind(me.id, f.id, f.id, me.id).run();
    await db.prepare('DELETE FROM requests WHERE (asker = ? AND target = ?) OR (asker = ? AND target = ?)').bind(me.id, f.id, f.id, me.id).run();
    await db.prepare('DELETE FROM invites WHERE (guest = ? AND host = ?) OR (guest = ? AND host = ?)').bind(me.id, f.id, f.id, me.id).run();
    return { ok: true };
  },

  async 'friends'(db, body, now, me) {
    const week = weekOf(now);
    const rows = await db.prepare(
      'SELECT p.id, p.code, p.name, s.mode, s.best, s.week, s.week_best, l.sign FROM players p ' +
      'LEFT JOIN scores s ON s.player = p.id LEFT JOIN looks l ON l.player = p.id ' +
      'WHERE p.id = ? OR p.id IN (SELECT b FROM friends WHERE a = ?)').bind(me.id, me.id).all();
    const by = new Map();
    for (const r of rows.results) {
      const e = by.get(r.id) || { code: r.code, name: r.name, best: 0, week: 0, endless: 0, endless_week: 0, sign: r.sign || '', me: r.id === me.id };
      if (r.mode === 'story') { e.best = r.best; e.week = r.week === week ? r.week_best : 0; }
      if (r.mode === 'endless') { e.endless = r.best; e.endless_week = r.week === week ? r.week_best : 0; }
      by.set(r.id, e);
    }
    const all = [...by.values()];
    return { me: all.find((e) => e.me), friends: all.filter((e) => !e.me).sort((x, y) => y.week - x.week || y.best - x.best) };
  },

  async 'room'(db, body, now, me) {
    return openRoom(db, body, now, me, 'coop');
  },

  async 'race'(db, body, now, me) {
    return openRoom(db, body, now, me, 'race');
  },

  async 'room/join'(db, body, now, me) {
    const room = roomCode(body.room);
    const r = await db.prepare('SELECT code, host, guest, seed, created, kind FROM rooms WHERE code = ?').bind(room).first();
    if (!r || r.created < now - ROOM_LIFE) return { error: 'unknown' };
    if (r.host === me.id) return { error: 'self' };
    const host = await db.prepare('SELECT name FROM players WHERE id = ?').bind(r.host).first();
    if (r.kind === 'race') {
      const mine = await db.prepare('SELECT slot FROM members WHERE room = ? AND player = ?').bind(room, me.id).first();
      let slot = mine ? mine.slot : 0;
      if (!slot) {
        const taken = (await db.prepare('SELECT slot FROM members WHERE room = ?').bind(room).all()).results.map((x) => x.slot);
        for (let i = 1; i <= RACE_GUESTS && !slot; i++) if (!taken.includes(i)) slot = i;
        if (!slot) return { error: 'full' };
        await db.prepare('INSERT INTO members (room, player, slot, at) VALUES (?, ?, ?, ?)').bind(room, me.id, slot, now).run();
      }
      await db.prepare('DELETE FROM invites WHERE room = ? AND guest = ?').bind(room, me.id).run();
      return { seed: r.seed, host: host ? host.name : '', kind: 'race', slot };
    }
    if (r.guest && r.guest !== me.id) return { error: 'full' };
    await db.prepare('UPDATE rooms SET guest = ? WHERE code = ?').bind(me.id, room).run();
    await db.prepare('DELETE FROM invites WHERE room = ?').bind(room).run();
    return { seed: r.seed, host: host ? host.name : '', kind: 'coop', slot: 1 };
  },

  async 'room/leave'(db, body, now, me) {
    await db.prepare('DELETE FROM members WHERE room = ? AND player = ?').bind(roomCode(body.room), me.id).run();
    return { ok: true };
  },

  async 'signal'(db, body, now, me) {
    const room = roomCode(body.room);
    const at = await inRoom(db, room, me, now);
    if (!at) return { error: 'unknown' };
    let dest = null;                                   // for two: the other one (whoever is not the sender)
    if (body.to) {                                     // a race: the host speaks to one of them, by his code
      const p = await db.prepare('SELECT id FROM players WHERE code = ?').bind(roomCode(body.to)).first();
      if (!p) return { error: 'unknown' };
      dest = p.id;
    } else if (at.r.kind === 'race' && at.role !== 'host') {
      dest = at.r.host;                                // a race guest only ever speaks to the host
    }
    const data = String(body.data || '').slice(0, 8000);
    const res = await db.prepare('INSERT INTO signals (room, sender, data, at, dest) VALUES (?, ?, ?, ?, ?)').bind(room, me.id, data, now, dest).run();
    return { seq: res.meta.last_row_id };
  },

  async 'signals'(db, body, now, me) {
    const room = roomCode(body.room);
    const at = await inRoom(db, room, me, now);
    if (!at) return { error: 'unknown' };
    const rows = await db.prepare(
      'SELECT s.seq, s.sender, s.data, p.code, p.name FROM signals s JOIN players p ON p.id = s.sender ' +
      'WHERE s.room = ? AND s.seq > ? AND s.sender != ? AND (s.dest IS NULL OR s.dest = ?) ORDER BY s.seq')
      .bind(room, Math.floor(Number(body.since) || 0), me.id, me.id).all();
    return { items: rows.results.map((x) => ({ seq: x.seq, from: x.sender === at.r.host ? 'host' : 'guest', code: x.code, name: x.name, data: x.data })) };
  },

  async 'invite'(db, body, now, me) {
    const code = String(body.code || '').toUpperCase().trim();
    const room = String(body.room || '').toUpperCase().trim();
    const f = await db.prepare('SELECT id, name FROM players WHERE code = ?').bind(code).first();
    if (!f) return { error: 'unknown' };
    const pal = await db.prepare('SELECT 1 FROM friends WHERE a = ? AND b = ?').bind(me.id, f.id).first();
    if (!pal) return { error: 'friend' };
    const r = await db.prepare('SELECT host, guest, created, kind FROM rooms WHERE code = ?').bind(room).first();
    if (!r || r.host !== me.id || r.created < now - ROOM_LIFE) return { error: 'room' };
    if (r.kind === 'race') {
      const n = await db.prepare('SELECT COUNT(*) AS n FROM members WHERE room = ?').bind(room).first();
      if (n.n >= RACE_GUESTS) return { error: 'full' };
    } else if (r.guest) return { error: 'full' };
    await db.prepare('INSERT OR REPLACE INTO invites (guest, host, room, at) VALUES (?, ?, ?, ?)').bind(f.id, me.id, room, now).run();
    return { name: f.name };
  },

  async 'invites'(db, body, now, me) {
    await db.prepare('DELETE FROM invites WHERE at < ?').bind(now - INVITE_LIFE).run();
    const rows = await db.prepare(
      'SELECT i.room, p.name, p.code, r.kind FROM invites i JOIN players p ON p.id = i.host JOIN rooms r ON r.code = i.room ' +
      "WHERE i.guest = ? AND r.host = i.host AND ((r.kind = 'race' AND (SELECT COUNT(*) FROM members m WHERE m.room = r.code) < ?) " +
      "OR (r.kind != 'race' AND r.guest IS NULL)) ORDER BY i.at DESC").bind(me.id, RACE_GUESTS).all();
    return { items: rows.results.map((x) => ({ room: x.room, name: x.name, code: x.code, kind: x.kind })) };
  },

  async 'invite/no'(db, body, now, me) {
    const room = String(body.room || '').toUpperCase().trim();
    const i = await db.prepare('SELECT host FROM invites WHERE guest = ? AND room = ?').bind(me.id, room).first();
    if (!i) return { ok: true };
    await db.prepare('DELETE FROM invites WHERE guest = ? AND room = ?').bind(me.id, room).run();
    await db.prepare('INSERT INTO signals (room, sender, data, at, dest) VALUES (?, ?, ?, ?, ?)').bind(room, me.id, JSON.stringify({ t: 'no' }), now, i.host).run();
    return { ok: true };
  },

  async 'room/close'(db, body, now, me) {
    const room = String(body.room || '').toUpperCase().trim();
    const r = await db.prepare('SELECT 1 FROM rooms WHERE code = ? AND host = ?').bind(room, me.id).first();
    if (!r) return { ok: true };
    await db.prepare('DELETE FROM invites WHERE room = ? AND host = ?').bind(room, me.id).run();
    await db.prepare('DELETE FROM members WHERE room = ?').bind(room).run();
    await db.prepare('DELETE FROM rooms WHERE code = ? AND host = ?').bind(room, me.id).run();
    await db.prepare('DELETE FROM queue WHERE player = ?').bind(me.id).run();
    return { ok: true };
  },

  // 0.66: a player's word about the game, kept for the author (read with wrangler d1 execute).
  async 'feedback'(db, body, now, me) {
    const text = String(body.text || '').replace(/[\u0000-\u001f]/g, ' ').trim().slice(0, 600);
    if (!text) return { error: 'empty' };
    const recent = await db.prepare('SELECT COUNT(*) AS n FROM feedback WHERE player = ? AND at > ?').bind(me.id, now - 3600 * 1000).first();
    if (recent && recent.n >= 5) return { error: 'busy' };
    await db.prepare('INSERT INTO feedback (player, version, text, at) VALUES (?, ?, ?, ?)')
      .bind(me.id, String(body.version || '').slice(0, 16), text, now).run();
    return { ok: true };
  },

  // 0.66: « Partie rapide »: a race room waiting for players (not mine, fresh, not full), else nothing.
  async 'match'(db, body, now, me) {
    await db.prepare('DELETE FROM queue WHERE at < ?').bind(now - QUEUE_LIFE).run();
    const rows = (await db.prepare('SELECT q.room AS room FROM queue q JOIN rooms r ON r.code = q.room WHERE q.player != ? AND r.kind = ? ORDER BY q.at LIMIT 8').bind(me.id, 'race').all()).results;
    for (const row of rows) {
      const n = await db.prepare('SELECT COUNT(*) AS n FROM members WHERE room = ?').bind(row.room).first();
      if (!n || n.n < RACE_GUESTS) return { room: row.room };
    }
    return {};
  },

  async 'match/open'(db, body, now, me) {
    const room = roomCode(body.room);
    const r = await db.prepare('SELECT 1 FROM rooms WHERE code = ? AND host = ? AND kind = ?').bind(room, me.id, 'race').first();
    if (!r) return { error: 'unknown' };
    await db.prepare('INSERT OR REPLACE INTO queue (player, room, at) VALUES (?, ?, ?)').bind(me.id, room, now).run();
    return { ok: true };
  },

  async 'ice'(db, body, now, me, env) {
    const id = String(env.TURN_KEY_ID || '').trim();
    const token = String(env.TURN_KEY_TOKEN || '').trim();
    if (!id || !token) return { iceServers: [], turn: 'off' };
    let r;
    try {
      r = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(id)}/credentials/generate-ice-servers`, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ ttl: TURN_TTL }),
      });
    } catch {
      return { iceServers: [], turn: 'unreachable' };
    }
    if (!r.ok) return { iceServers: [], turn: 'refused ' + r.status };
    const data = await r.json();
    // Port 53 is blocked by browsers: such an address would only make them wait (Cloudflare's advice).
    const servers = (data.iceServers || [])
      .map((s) => ({ ...s, urls: [].concat(s.urls || []).filter((u) => !/:53(\?|$)/.test(u)) }))
      .filter((s) => s.urls.length);
    return { iceServers: servers, turn: 'on' };
  },
};

export default {
  async fetch(request, env) {
    const origin = env.ORIGIN || '*';
    if (request.method === 'OPTIONS') {          // a browser asking first (CORS): a 204 has no body
      return new Response(null, { status: 204, headers: { 'access-control-allow-origin': origin, 'access-control-allow-headers': 'content-type', 'access-control-allow-methods': 'POST', 'access-control-max-age': '86400' } });
    }
    const url = new URL(request.url);
    const route = url.pathname.replace(/^\/api\//, '');
    if (request.method !== 'POST' || !routes[route]) return json({ error: 'not found' }, 404, origin);
    let body;
    try { body = await request.json(); } catch { return json({ error: 'bad json' }, 400, origin); }
    const now = Date.now();
    let me = null;
    if (route !== 'player') {
      me = await who(env.DB, body);
      if (!me) return json({ error: 'who' }, 403, origin);
    }
    const out = await routes[route](env.DB, body, now, me, env);
    return json(out, out && out.error ? 400 : 200, origin);
  },
};

export { weekOf, cleanName };
