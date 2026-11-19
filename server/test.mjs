// Every route of worker.js against the in-memory database:   node server/test.mjs
import assert from 'node:assert/strict';
import worker, { weekOf, cleanName } from './worker.js';
import { memoryD1 } from './dev.mjs';

const env = { DB: memoryD1(), ORIGIN: '*' };
const call = async (route, body) => {
  const r = await worker.fetch(new Request('http://x/api/' + route, { method: 'POST', body: JSON.stringify(body) }), env);
  return { status: r.status, ...(await r.json()) };
};
let n = 0;
const ok = (what) => { n++; console.log('ok  ', what); };

const a = await call('player', { name: 'Léa <script>' });
assert.equal(a.status, 200); assert.match(a.code, /^PEPI-[A-Z2-9]{4}$/); assert.equal(a.secret.length, 24);
ok('a player is made, with a friend code');
const b = await call('player', { name: 'Buly' });
assert.notEqual(a.code, b.code);
ok('two players, two codes');

assert.equal((await call('player/name', { id: b.id, secret: b.secret, name: 'Buly!!' })).name, 'Buly');
assert.equal((await call('player/name', { id: b.id, secret: 'nope', name: 'X' })).status, 403);
ok('a player changes their pseudonym (cleaned), only with their secret');

assert.equal((await call('score', { id: a.id, secret: 'wrong', mode: 'story', dist: 10 })).status, 403);
ok('a wrong secret is refused');

assert.deepEqual((await call('score', { id: a.id, secret: a.secret, mode: 'story', dist: 1200.7 })).best, 1200);
assert.deepEqual((await call('score', { id: a.id, secret: a.secret, mode: 'story', dist: 800 })).best, 1200);
assert.deepEqual((await call('score', { id: a.id, secret: a.secret, mode: 'endless', dist: 3000 })).best, 3000);
await call('score', { id: b.id, secret: b.secret, mode: 'story', dist: 1500 });
ok('the best distance is kept, per mode');

assert.equal((await call('friends/add', { id: a.id, secret: a.secret, code: 'PEPI-ZZZZ' })).error, 'unknown');
assert.equal((await call('friends/add', { id: a.id, secret: a.secret, code: a.code })).error, 'self');
const added = await call('friends/add', { id: a.id, secret: a.secret, code: b.code.toLowerCase() });
assert.equal(added.name, 'Buly');
ok('a friend is added by code (any case), not oneself nor an unknown code');

const fa = await call('friends', { id: a.id, secret: a.secret });
assert.equal(fa.me.best, 1200); assert.equal(fa.me.endless, 3000);
assert.equal(fa.friends.length, 1); assert.equal(fa.friends[0].best, 1500); assert.equal(fa.friends[0].week, 1500);
const fb = await call('friends', { id: b.id, secret: b.secret });
assert.equal(fb.friends[0].name, cleanName('Léa <script>'));
ok('friends see each other, with their bests and this week\'s');

const room = await call('room', { id: a.id, secret: a.secret, seed: 4242 });
assert.match(room.room, /^[A-Z2-9]{4}$/);
assert.equal((await call('room/join', { id: a.id, secret: a.secret, room: room.room })).error, 'self');
const join = await call('room/join', { id: b.id, secret: b.secret, room: room.room.toLowerCase() });
assert.equal(join.seed, 4242); assert.equal(join.host, cleanName('Léa <script>'));
const c = await call('player', { name: 'Third' });
assert.equal((await call('room/join', { id: c.id, secret: c.secret, room: room.room })).error, 'full');
ok('a room: made by the host, joined by one guest, who gets the seed');

await call('signal', { id: a.id, secret: a.secret, room: room.room, data: '{"type":"offer"}' });
await call('signal', { id: a.id, secret: a.secret, room: room.room, data: '{"candidate":1}' });
const got = await call('signals', { id: b.id, secret: b.secret, room: room.room, since: 0 });
assert.equal(got.items.length, 2); assert.equal(got.items[0].from, 'host');
const mine = await call('signals', { id: a.id, secret: a.secret, room: room.room, since: 0 });
assert.equal(mine.items.length, 0);
const later = await call('signals', { id: b.id, secret: b.secret, room: room.room, since: got.items[1].seq });
assert.equal(later.items.length, 0);
assert.equal((await call('signal', { id: c.id, secret: c.secret, room: room.room, data: 'x' })).error, 'unknown');
ok('the handshake: each side reads only the other\'s messages, from where it left off; strangers are kept out');

// invitations: Léa (a) invites her friend Buly (b) into a new room; Third (c) is nobody's friend
const r2 = await call('room', { id: a.id, secret: a.secret, seed: 7 });
assert.equal((await call('invite', { id: a.id, secret: a.secret, code: c.code, room: r2.room })).error, 'friend');
assert.equal((await call('invite', { id: c.id, secret: c.secret, code: a.code, room: r2.room })).error, 'friend');
assert.equal((await call('invite', { id: a.id, secret: a.secret, code: b.code, room: 'ZZZZ' })).error, 'room');
assert.equal((await call('invite', { id: a.id, secret: a.secret, code: b.code.toLowerCase(), room: r2.room.toLowerCase() })).name, 'Buly');
let inv = await call('invites', { id: b.id, secret: b.secret });
assert.equal(inv.items.length, 1); assert.equal(inv.items[0].room, r2.room); assert.equal(inv.items[0].code, a.code);
assert.equal((await call('invites', { id: c.id, secret: c.secret })).items.length, 0);
assert.equal((await call('invites', { id: a.id, secret: a.secret })).items.length, 0);
ok('an invitation goes to a friend only, into the inviter\'s own room; only he sees it');

await call('invite/no', { id: b.id, secret: b.secret, room: r2.room });
assert.equal((await call('invites', { id: b.id, secret: b.secret })).items.length, 0);
const told = await call('signals', { id: a.id, secret: a.secret, room: r2.room, since: 0 });
assert.equal(told.items.length, 1); assert.equal(JSON.parse(told.items[0].data).t, 'no');
ok('« Pas maintenant »: the invitation goes and the host reads {"t":"no"} in his room');

const r3 = await call('room', { id: a.id, secret: a.secret, seed: 8 });
await call('invite', { id: a.id, secret: a.secret, code: b.code, room: r3.room });
assert.equal((await call('room/join', { id: b.id, secret: b.secret, room: r3.room })).seed, 8);
assert.equal((await call('invites', { id: b.id, secret: b.secret })).items.length, 0);
const r4 = await call('room', { id: a.id, secret: a.secret, seed: 9 });
await call('invite', { id: a.id, secret: a.secret, code: b.code, room: r4.room });
await call('room/close', { id: b.id, secret: b.secret, room: r4.room });
assert.equal((await call('invites', { id: b.id, secret: b.secret })).items.length, 1);
await call('room/close', { id: a.id, secret: a.secret, room: r4.room });
assert.equal((await call('invites', { id: b.id, secret: b.secret })).items.length, 0);
assert.equal((await call('room/join', { id: b.id, secret: b.secret, room: r4.room })).error, 'unknown');
ok('an invitation goes once accepted, or when its host closes the room (no one else can close it)');

const off = await call('ice', { id: a.id, secret: a.secret });
assert.equal(off.status, 200); assert.deepEqual(off.iceServers, []); assert.equal(off.turn, 'off');
assert.equal((await call('ice', { id: a.id, secret: 'nope' })).status, 403);
const realFetch = globalThis.fetch;
let asked = null;
globalThis.fetch = async (url, init) => {
  asked = { url: String(url), auth: init.headers.authorization, body: JSON.parse(init.body) };
  return new Response(JSON.stringify({ iceServers: [
    { urls: ['stun:stun.cloudflare.com:3478', 'stun:stun.cloudflare.com:53'] },
    { urls: ['turn:turn.cloudflare.com:3478?transport=udp', 'turn:turn.cloudflare.com:53?transport=udp', 'turns:turn.cloudflare.com:5349?transport=tcp', 'turns:turn.cloudflare.com:443?transport=tcp'], username: 'u', credential: 'c' },
  ] }), { status: 201 });
};
env.TURN_KEY_ID = 'key123'; env.TURN_KEY_TOKEN = 'tok456\r\n';
const on = await call('ice', { id: a.id, secret: a.secret });
globalThis.fetch = realFetch; delete env.TURN_KEY_ID; delete env.TURN_KEY_TOKEN;
assert.equal(asked.url, 'https://rtc.live.cloudflare.com/v1/turn/keys/key123/credentials/generate-ice-servers');
assert.equal(asked.auth, 'Bearer tok456'); assert.equal(asked.body.ttl, 4 * 3600);
assert.equal(on.turn, 'on');
assert.deepEqual(on.iceServers[0].urls, ['stun:stun.cloudflare.com:3478']);
assert.deepEqual(on.iceServers[1].urls, ['turn:turn.cloudflare.com:3478?transport=udp', 'turns:turn.cloudflare.com:5349?transport=tcp', 'turns:turn.cloudflare.com:443?transport=tcp']);
assert.equal(on.iceServers[1].username, 'u'); assert.equal(on.iceServers[1].credential, 'c');
ok('the relay: nothing until its two secrets are set; then short-lived credentials, port 53 left out');

const pre = await worker.fetch(new Request('http://x/api/score', { method: 'OPTIONS' }), env);
assert.equal(pre.status, 204); assert.equal(pre.headers.get('access-control-allow-origin'), '*'); assert.equal(await pre.text(), '');
ok('a browser asking first (CORS) gets an empty 204');

assert.equal(weekOf(Date.UTC(2026, 10, 18, 15)), '2026-11-16');
assert.equal(weekOf(Date.UTC(2026, 10, 22, 23)), '2026-11-16');
assert.equal(weekOf(Date.UTC(2026, 10, 23, 0)), '2026-11-23');
ok('weeks start on Monday');

console.log(`\n${n} checks passed`);
