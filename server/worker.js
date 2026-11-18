// Jungle Loop's small server, for Cloudflare Workers with a D1 database (schema.sql).
// What it keeps: players (a pseudonym and a friend code, no e-mail), their best distances (all time and
// this week, per mode), who is friends with whom, and the rooms where two phones meet before a coop
// run (the messages of their WebRTC handshake, a few minutes at most).
//
// Every request is a POST of JSON to /api/<route>. A player proves who they are with the secret given at
// creation (only its hash is kept). Nothing here is needed to play: the game works without it.
//
//   player        {name}                                  -> {id, code, secret}
//   score         {id, secret, mode, dist}                 -> {best, week}
//   friends/add   {id, secret, code}                       -> {code, name}
//   friends       {id, secret}                             -> {me, friends: [{code, name, best, week, endless, endless_week}]}
//   room          {id, secret, seed}                       -> {room}
//   room/join     {id, secret, room}                       -> {seed, host}
//   signal        {id, secret, room, data}                 -> {seq}
//   signals       {id, secret, room, since}                -> {items: [{seq, from, data}]}

const MODES = ['story', 'endless'];
const ROOM_LIFE = 10 * 60 * 1000;          // a room lasts ten minutes
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

async function who(db, body) {
  if (!body.id || !body.secret) return null;
  const p = await db.prepare('SELECT id, code, name, secret_hash FROM players WHERE id = ?').bind(String(body.id)).first();
  if (!p || p.secret_hash !== await hash(String(body.secret))) return null;
  return p;
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

  async 'friends/add'(db, body, now, me) {
    const code = String(body.code || '').toUpperCase().trim();
    const f = await db.prepare('SELECT id, code, name FROM players WHERE code = ?').bind(code).first();
    if (!f) return { error: 'unknown' };
    if (f.id === me.id) return { error: 'self' };
    for (const [a, b] of [[me.id, f.id], [f.id, me.id]]) {
      await db.prepare('INSERT OR IGNORE INTO friends (a, b, since) VALUES (?, ?, ?)').bind(a, b, now).run();
    }
    return { code: f.code, name: f.name };
  },

  async 'friends'(db, body, now, me) {
    const week = weekOf(now);
    const rows = await db.prepare(
      'SELECT p.id, p.code, p.name, s.mode, s.best, s.week, s.week_best FROM players p ' +
      'LEFT JOIN scores s ON s.player = p.id ' +
      'WHERE p.id = ? OR p.id IN (SELECT b FROM friends WHERE a = ?)').bind(me.id, me.id).all();
    const by = new Map();
    for (const r of rows.results) {
      const e = by.get(r.id) || { code: r.code, name: r.name, best: 0, week: 0, endless: 0, endless_week: 0, me: r.id === me.id };
      if (r.mode === 'story') { e.best = r.best; e.week = r.week === week ? r.week_best : 0; }
      if (r.mode === 'endless') { e.endless = r.best; e.endless_week = r.week === week ? r.week_best : 0; }
      by.set(r.id, e);
    }
    const all = [...by.values()];
    return { me: all.find((e) => e.me), friends: all.filter((e) => !e.me).sort((x, y) => y.week - x.week || y.best - x.best) };
  },

  async 'room'(db, body, now, me) {
    await db.prepare('DELETE FROM rooms WHERE created < ?').bind(now - ROOM_LIFE).run();
    await db.prepare('DELETE FROM signals WHERE at < ?').bind(now - ROOM_LIFE).run();
    const seed = Math.max(0, Math.floor(Number(body.seed) || 0)) % 2147483647;
    for (let tries = 0; tries < 8; tries++) {
      const room = letters(4);
      const taken = await db.prepare('SELECT 1 FROM rooms WHERE code = ?').bind(room).first();
      if (taken) continue;
      await db.prepare('INSERT INTO rooms (code, host, guest, seed, created) VALUES (?, ?, NULL, ?, ?)').bind(room, me.id, seed, now).run();
      return { room };
    }
    return { error: 'busy' };
  },

  async 'room/join'(db, body, now, me) {
    const room = String(body.room || '').toUpperCase().trim();
    const r = await db.prepare('SELECT code, host, guest, seed, created FROM rooms WHERE code = ?').bind(room).first();
    if (!r || r.created < now - ROOM_LIFE) return { error: 'unknown' };
    if (r.guest && r.guest !== me.id) return { error: 'full' };
    if (r.host === me.id) return { error: 'self' };
    await db.prepare('UPDATE rooms SET guest = ? WHERE code = ?').bind(me.id, room).run();
    const host = await db.prepare('SELECT name FROM players WHERE id = ?').bind(r.host).first();
    return { seed: r.seed, host: host ? host.name : '' };
  },

  async 'signal'(db, body, now, me) {
    const r = await db.prepare('SELECT host, guest FROM rooms WHERE code = ?').bind(String(body.room || '').toUpperCase()).first();
    if (!r || (r.host !== me.id && r.guest !== me.id)) return { error: 'unknown' };
    const data = String(body.data || '').slice(0, 8000);
    const res = await db.prepare('INSERT INTO signals (room, sender, data, at) VALUES (?, ?, ?, ?)').bind(String(body.room).toUpperCase(), me.id, data, now).run();
    return { seq: res.meta.last_row_id };
  },

  async 'signals'(db, body, now, me) {
    const room = String(body.room || '').toUpperCase();
    const r = await db.prepare('SELECT host, guest FROM rooms WHERE code = ?').bind(room).first();
    if (!r || (r.host !== me.id && r.guest !== me.id)) return { error: 'unknown' };
    const rows = await db.prepare('SELECT seq, sender, data FROM signals WHERE room = ? AND seq > ? AND sender != ? ORDER BY seq').bind(room, Math.floor(Number(body.since) || 0), me.id).all();
    return { items: rows.results.map((x) => ({ seq: x.seq, from: x.sender === r.host ? 'host' : 'guest', data: x.data })) };
  },
};

export default {
  async fetch(request, env) {
    const origin = env.ORIGIN || '*';
    if (request.method === 'OPTIONS') return json({}, 204, origin);
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
    const out = await routes[route](env.DB, body, now, me);
    return json(out, out && out.error ? 400 : 200, origin);
  },
};

export { weekOf, cleanName };
