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

const pre = await worker.fetch(new Request('http://x/api/score', { method: 'OPTIONS' }), env);
assert.equal(pre.status, 204); assert.equal(pre.headers.get('access-control-allow-origin'), '*'); assert.equal(await pre.text(), '');
ok('a browser asking first (CORS) gets an empty 204');

assert.equal(weekOf(Date.UTC(2026, 10, 18, 15)), '2026-11-16');
assert.equal(weekOf(Date.UTC(2026, 10, 22, 23)), '2026-11-16');
assert.equal(weekOf(Date.UTC(2026, 10, 23, 0)), '2026-11-23');
ok('weeks start on Monday');

console.log(`\n${n} checks passed`);
