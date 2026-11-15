// Game rules: player physics, spawning, collisions. No drawing here.
// World x grows to the right; the camera (run.cam) follows the player once he has left the temple.
// y grows downward: 0 is the top of the play area, GROUND the floor.
// All values are in "logical" units; the renderer divides them by PIXEL to get art pixels.

export const VIEW_H = 720;      // height of the play area shown on screen
export const GROUND = 630;      // floor line
export const PX = 200;          // player's screen x once the camera follows him
export const CEIL = 24;         // flight ceiling
export const PPM = 40;          // logical units per metre
export const PIXEL = 2.25;      // logical units per art pixel (720 units = 320 art pixels)
export const BIOME_LEN = 400;   // metres between two changes of scenery
export const BIOME_COUNT = 4;
export const HEARTS = 1;         // one life: the first blow ends the run (Cœur en plus gives a second)

const HERO_H = 80, HERO_HALF = 14;      // hitbox, smaller than the sprite: forgiving
const CRATE = { w: 63, h: 52 }, SPIKY = { w: 68, h: 54 }, FLY = { w: 64, h: 54 }, PLAT_W = 254;

// Raised ways: a stone slab on pillars (a cave underneath) and a hollow log (a tunnel inside).
// `t` is how thick the roof is: the hero can run under it, and bumps his head if he jumps there.
export const SLAB = { h: 100, t: 50 }, LOG = { h: 106, t: 48, w: 520 };
const TOUCH_H = 130;            // scenery only reacts to a hero running past, not flying far above
const MONKEY_H = 230;           // how high the hero must be to greet a monkey

const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

const DASH_CD = [0, 14, 10, 7];
const SLOW_TIME = [0, 3, 4.5];
const SLOW_CD = 20;
const MAGNET = [0, 110, 170, 240];
const DRUNK = [0, 0.06, 0.1, 0.15];     // Faune alcoolisée: share of the creatures that are harmless
const FLAP = 430;                       // how fast the leaf rotor climbs
export const SPEED = { base: 280, gain: 5, sprint: 160 };   // units per second: at the door, gained each second (for ever), added by Sprint
const SPIDER = { w: 60, h: 56, ahead: 0.9 };   // it drops when the hero is `ahead` seconds away

// Mounts: rare friendly animals waiting on the path. Running into one puts the hero on its back until
// something hits them: the animal takes the blow and vanishes. Each one plays its own game, and the
// path ahead is laid out for it (see spawnRide):
// - the gorilla jumps a little higher, and its second jump always carries it up to the vines along
//   the top of the screen, where it swings on until a press lets go. Floor and vines, nothing between.
// - the rhino barely hops, runs faster and faster, and smashes crates. Everything on the floor.
// - the Moskito flies: held, it climbs; let go, it sinks. The whole sky.
// `half` and `tall` are the hitbox with the hero on its back.
export const MOUNTS = {
  gorilla: { name: 'Gorille', jump: -820, half: 34, tall: 118 },
  rhino: { name: 'Rhino', jump: -560, half: 34, tall: 104, smash: true, grab: { w: 78, h: 150 } },   // grab: it sweeps up coins well above its back
  moskito: { name: 'Moskito', fly: true, half: 28, tall: 92 },
};
export const HANG_Y = 190;              // where the gorilla's feet are when it hangs from the vines
const friend = (up) => 1 + 0.25 * (up.nature || 0);      // Ami de la nature: mounts come that much sooner

// Follower monsters: mosquitoes line up at the right edge of the screen, one per lane, show which
// lanes they will take, then rush across. The air above the floor is cut into FM.lanes lanes of
// FM.step each; the longer the run, the more of them are taken (see wave). Nothing else blocks the
// way meanwhile.
export const FM = { w: 90, h: 64, rush: 1150, lanes: 5, step: 110 };

// Gems: what each colour is worth, and how often each turns up.
export const GEMS = { y: 5, r: 10, b: 20 };
const gemKind = () => pick('yyyyyyrrrb');
const SCATTER = [0, 0.012, 0.022, 0.035];   // Gemmes dispersées: share of the coins that become gems
const HEART_GOLD = 25;                      // what a heart is worth to someone who has all his lives
const BLAST_COINS = 30;                     // thrown out of the temple when its doorway blows: they can be picked up

// Groups of coins drawn as text in assets/patterns.txt (see that file). Each character is one cell of
// CELL units; the bottom row sits at running height, `base` cells higher if asked. A shape is only laid
// where the hero can reach its top with what he owns: on foot, with the double jump, flying.
const CELL = 44, REACH = [230, 400, 600];
let SHAPES = [];
export function setShapes(text) {
  const found = []; let cur = null;
  for (const raw of String(text || '').split(/\r?\n/)) {
    const line = raw.replace(/\s+$/, '');
    if (line.startsWith('#') || !line.trim()) continue;
    if (line.startsWith('=')) { const m = /base\s+(\d+)/.exec(line); cur = { name: line.slice(1).split(',')[0].trim(), base: m ? Math.min(12, Number(m[1])) : 0, rows: [] }; found.push(cur); }
    else if (cur && cur.rows.length < 14) cur.rows.push(line.slice(0, 40));
  }
  SHAPES = found.filter((s) => s.rows.some((r) => /[^. ]/.test(r)));
  for (const s of SHAPES) { s.cols = Math.max(...s.rows.map((r) => r.length)); s.top = 40 + (s.base + s.rows.length - 1) * CELL; }
}
function layShape(run, s, x, lift = 0) {
  s.rows.forEach((row, r) => {
    const h = 40 + lift + (s.base + s.rows.length - 1 - r) * CELL;
    [...row].forEach((ch, k) => {
      if (ch === '.' || ch === ' ') return;
      const c = { x: x + k * CELL, y: floorAt(run, x + k * CELL) - h };
      if ('yrb'.includes(ch)) c.gem = ch;                // y, r, b: a yellow, red or blue gem; anything else is a coin
      run.coins.push(c);
    });
  });
  return s.cols * CELL;
}

// Tight places, for the Sphère power only: a hollow trunk standing behind the path, a gallery dug
// under it. Whoever has the power rolls in by himself; everyone else just runs past. They only ever
// hold rewards. GALLERY is how deep the ball rolls under the floor.
export const GALLERY = 58;

export function newRun(upgrades) {
  return {
    up: upgrades, viewW: 960,
    t: 0, cam: 0, sx: 10, base: SPEED.base + (upgrades.sprint ? SPEED.sprint : 0), speed: SPEED.base, dist: 0, gold: 0, gems: 0,
    hearts: HEARTS + (upgrades.heart ? 1 : 0), maxHearts: HEARTS + (upgrades.heart ? 1 : 0),
    p: { y: GROUND, vy: 0, ground: true, plat: null, jumps: 0, buf: 0, phase: 0, flying: false, rotor: false, spin: 0, roll: 0, inv: 0, squash: 0, hang: false, vineLeap: false, ball: null },
    obs: [], coins: [], plats: [], parts: [], events: [],
    nextX: 1500,
    biome: 0, prevBiome: 0, blend: 1, nextBiomeAt: BIOME_LEN, glitch: 0,
    dash: { t: 0, cd: 0, max: DASH_CD[upgrades.dash || 0] },
    slow: { t: 0, cd: 0, max: SLOW_CD },
    rewindLeft: upgrades.rewind ? 1 : 0,
    dead: false, shake: 0, flash: 0,
    wait: 0, exploded: false, boom: 0,           // the blast that opens the temple (see launch)
    biomeX: -1e9,                                // world x where the current scenery begins
    touched: new Map(), monkeys: [],             // scenery that reacted, and who is up in the vines
    terrain: [{ x: -1e9, y: GROUND }],           // the floor's outline, see floorAt
    zones: [],                                   // tight places ahead (see GALLERY)
    items: [], mount: null, gone: null, vine: 0,             // mounts waiting ahead, the one ridden, how far the vines have come down
    nextMount: rnd(300, 480) / friend(upgrades),  // in metres: mounts are a rare treat
    fm: null, fmDue: false, nextFM: rnd(150, 230), blockEnd: 0,   // follower monster; where the last blocking pattern ends
    leap: null,                                  // Dernier élan: the bounces after the last heart
  };
}

// ---------- the floor ----------

// The floor is a line through run.terrain's points. It stays at GROUND almost everywhere: now and
// then it rises one level onto a ledge of earth or sinks one level into a hollow, for a good
// stretch, and always comes back. Never two levels. The camera never moves up or down.
// Everything that stands on the ground asks floorAt for its height.
export function floorAt(run, x) {
  const T = run.terrain;
  let i = T.length - 1;
  while (i > 0 && T[i].x > x) i--;
  const a = T[i], b = T[i + 1];
  if (!b || x <= a.x) return a.y;
  return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x);
}
const STEP = 135, HOLLOW = 66;       // height of a ledge, depth of a hollow
// Adds a stretch of relief: `pts` are [distance from x, height above the ground] pairs.
function relief(run, x, pts) { for (const [dx, h] of pts) run.terrain.push({ x: x + dx, y: GROUND - h }); }
export const flatAt = (run, x, w) => Math.abs(floorAt(run, x) - floorAt(run, x + w)) < 1 && Math.abs(floorAt(run, x) - floorAt(run, x + w / 2)) < 1;
// Which scenery a spot belongs to: the new one begins at run.biomeX and scrolls in.
export const biomeAt = (run, x) => (x >= run.biomeX ? run.biome : run.prevBiome);

// The hero starts shut inside the temple: a short rumble, then the doorway blows out and he runs.
export function launch(run) { run.wait = 0.75; run.events.push('rumble'); }

// ---------- scenery the hero can brush past ----------

// Which prop stands in which cell is a pure function of the cell number, so the rules (here) and
// the drawing (render.js) always agree without sharing any state.
export const PROP_CELL = 150 * PIXEL, PROP_KINDS = 9;
export const PROP = { FERN: 3, FLOWER: 4, SHROOM: 5, LANTERN: 6 };
const h01 = (i, s) => { const x = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); };
export function propAt(i) {
  if (i < 2 || h01(i, 21) < 0.42) return null;
  return { kind: Math.floor(h01(i, 33) * PROP_KINDS), x: i * PROP_CELL + h01(i, 47) * 60 * PIXEL, flip: h01(i, 59) > 0.5 };
}
const REACTS = { [PROP.FERN]: ['#7bd13c', 5], [PROP.FLOWER]: ['#d98cff', 7], [PROP.SHROOM]: ['#7dfff0', 12], [PROP.LANTERN]: ['#7dfff0', 8] };

// ---------- helpers ----------

function addObs(run, x, y, w, h, kind, fragile) {
  const o = { x, y, w, h, kind, fragile };
  // Faune alcoolisée: some creatures are tipsy ghosts of themselves and hurt nobody
  if (!fragile && run.up.drunk && Math.random() < DRUNK[run.up.drunk]) o.ghost = true;
  run.obs.push(o);
  return o;
}

export function addCrates(run, x, n) { addObs(run, x, floorAt(run, x) - CRATE.h * n, CRATE.w, CRATE.h * n, 'crate', true).n = n; }
export function addSpiky(run, x) { addObs(run, x, floorAt(run, x) - SPIKY.h, SPIKY.w, SPIKY.h, 'spiky', false); }

// A spider waits curled up at the top of the screen and drops on its thread as the hero comes.
// Low, it stops just above the floor and must be jumped (the thread hurts nobody); high, it stops at
// head height of a jump: the thing to do is to stay down.
export function addSpider(run, x, low) {
  const o = addObs(run, x, 14, SPIDER.w, SPIDER.h, 'spider', false);
  o.rest = floorAt(run, x) - (low ? SPIDER.h + 8 : 270); o.vy = 0;
  return o;
}

export function addFlyer(run, x, alt) {
  const o = addObs(run, x, floorAt(run, x) - alt - FLY.h / 2, FLY.w, FLY.h, 'fly', false);
  o.baseY = o.y; o.ph = rnd(0, 6);
  return o;
}

export function coinLine(run, x, y, n) {
  for (let i = 0; i < n; i++) run.coins.push({ x: x + i * 44, y });
}

function coinArc(run, x, peak, n, span) {
  for (let i = 0; i < n; i++) {
    const k = i / (n - 1);
    run.coins.push({ x: x + span * k, y: floorAt(run, x + span * k) - 40 - peak * 4 * k * (1 - k) });
  }
}

export function burst(run, x, y, color, n, spd = 220) {
  for (let i = 0; i < n; i++) {
    const a = rnd(0, Math.PI * 2), v = rnd(spd * 0.3, spd);
    run.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 80, life: 0, max: rnd(0.3, 0.7), c: color, s: rnd(4, 9), g: 700 });
  }
}

// ---------- spawning ----------

// One pattern at run.nextX, then a gap sized on the current speed so it stays fair.
// What can appear depends on what the player owns: nothing asks for a skill not bought yet.
// A tight place and what it holds: coins all along, a few gems, once in a blue moon a heart.
function tight(run, kind, x, w, y) {
  run.zones.push({ x, w, kind });
  const count = Math.floor((w - 160) / 40);
  for (let i = 0; i < count; i++) {
    const c = { x: x + 80 + i * 40, y, tight: kind };
    if (i % 6 === 3) c.gem = gemKind();
    run.coins.push(c);
  }
  if (Math.random() < 0.03) run.coins.push({ x: x + w - 70, y, tight: kind, heart: true });
}

// Gemmes dispersées: among the coins just laid, a few turn into gems.
function scatter(run, from) {
  const rate = SCATTER[run.up.scatter || 0];
  if (rate) for (let i = from; i < run.coins.length; i++) { const c = run.coins[i]; if (!c.gem && !c.heart && Math.random() < rate) c.gem = gemKind(); }
}

function spawnPattern(run) {
  const laid = run.coins.length;
  if (run.mount && !run.fm && !run.fmDue) { spawnRide(run); scatter(run, laid); return; }
  const up = run.up, x = run.nextX, G = GROUND;
  const tier = up.flight ? 2 : up.doubleJump ? 1 : 0;
  const riding = run.mount || run.items.length;                       // a mount in play: nothing with a roof
  // The first metres are a warm-up: one obstacle at a time, nothing in the air.
  let opts = x < 70 * PPM ? ['crate', 'spiky', 'coins', 'plat']
    : ['crate', 'spiky', 'spiky', 'double', 'fly', 'coins', 'plat', 'cave', 'log', 'gallery', 'stairs', 'ledge', 'ledge', 'hollow'];
  if (x >= 70 * PPM) opts.push('spider', 'spider');
  if (tier >= 1 && x >= 70 * PPM) opts.push('stack', 'fly');
  if (tier >= 2 && x >= 70 * PPM) opts.push('wall', 'swarm', 'swarm');
  const shapes = SHAPES.filter((s) => s.top <= REACH[tier]);
  if (shapes.length && x >= 70 * PPM) opts.push('shape', 'shape');
  if (riding) opts = opts.filter((k) => k !== 'cave');
  if (run.fm || run.fmDue) opts = ['coins'];                          // a follower monster needs a clear road
  else if (!riding && x > 70 * PPM && x / PPM >= run.nextMount) opts = ['mount'];
  const kind = pick(opts);
  let len = 0;

  switch (kind) {
    case 'crate': addCrates(run, x, 1); len = CRATE.w; break;
    case 'spiky': addSpiky(run, x); len = SPIKY.w; break;
    case 'shape': len = layShape(run, pick(shapes), x); break;         // a drawing made of coins
    case 'spider':
      if (Math.random() < 0.6) addSpider(run, x, true);
      else { addSpider(run, x + 88, false); coinLine(run, x, floorAt(run, x) - 40, 5); }   // high: coins underneath, for whoever stays down
      len = 220; break;
    case 'double': {
      const d = run.speed + 90;
      if (Math.random() < 0.5) addCrates(run, x, 1); else addSpiky(run, x);
      addSpiky(run, x + d);
      len = d + SPIKY.w; break;
    }
    case 'stack': addCrates(run, x, 2); len = CRATE.w; break;          // needs a held jump or the double jump
    case 'wall': addCrates(run, x, 4); coinLine(run, x - 30, G - 290, 3); len = CRATE.w; break;   // fly over it
    case 'fly': addFlyer(run, x + 250, tier === 2 ? pick([175, 290, 400, 510]) : tier ? pick([175, 290]) : 175); len = 250; break;
    case 'swarm': {
      const alts = [175, 290, 400, 510];
      alts.splice(Math.floor(Math.random() * 4), 2);
      addFlyer(run, x + 250, alts[0]); addFlyer(run, x + 420, alts[1]);
      len = 420; break;
    }
    case 'plat': {                                                     // a ledge to hop on, with a reward
      const y = G - 135;
      run.plats.push({ x, y, w: PLAT_W });
      coinLine(run, x + 40, y - 40, 4);
      if (Math.random() < 0.35 + 0.2 * (up.lucky || 0)) run.coins.push({ x: x + PLAT_W / 2, y: y - 110, gem: gemKind() });
      len = PLAT_W; break;
    }
    case 'cave': {                                                     // two ways: down through the hollow, or over its roof
      const R = 70, w = Math.round(rnd(800, 1200)), y = G - SLAB.h;    // slope length, flat bottom, roof height
      relief(run, x, [[0, 0], [R, -HOLLOW], [R + w, -HOLLOW], [2 * R + w, 0]]);
      run.plats.push({ x: x + R, y, w, t: SLAB.t, kind: 'slab' });     // the roof only covers the deep part: headroom everywhere
      coinLine(run, x + R + w * 0.25, G + HOLLOW - 40, Math.floor(w * 0.5 / 44));         // below: no room to jump, so only coins
      coinLine(run, x + R + 70, y - 40, Math.min(16, Math.floor((w - 140) / 60)));        // above: the bigger reward
      run.coins.push({ x: x + R + w - 60, y: y - 110, gem: gemKind() });
      run.monkeys.push({ x: x + R + w * rnd(0.3, 0.7), ph: rnd(0, 6) });
      len = 2 * R + w; break;
    }
    case 'hollow': {                                                   // one level down for a while, coins at the bottom
      const R = 70, w = Math.round(rnd(600, 950));
      relief(run, x, [[0, 0], [R, -HOLLOW], [R + w, -HOLLOW], [2 * R + w, 0]]);
      coinLine(run, x + R + 30, G + HOLLOW - 40, Math.floor((w * 0.4) / 44));
      if (x > 70 * PPM) addCrates(run, x + R + w * 0.7, 1);
      len = 2 * R + w; break;
    }
    case 'ledge': {                                                    // one level up for a while
      const R = 150, w = Math.round(rnd(700, 1100));
      relief(run, x, [[0, 0], [R, STEP], [R + w, STEP], [2 * R + w, 0]]);
      if (x > 70 * PPM && Math.random() < 0.6) addSpiky(run, x + R + w * 0.55); else coinLine(run, x + R + 60, G - STEP - 40, 6);
      len = 2 * R + w; break;
    }
    case 'log':                                                        // a hollow trunk behind the path: only a ball gets in
      tight(run, 'log', x, LOG.w, G - 24);
      len = LOG.w; break;
    case 'gallery': {                                                  // a gallery under the path: the same
      const w = Math.round(rnd(800, 1200));
      tight(run, 'gallery', x, w, G + GALLERY - 22);
      len = w; break;
    }
    case 'stairs': {                                                   // three ledges climbing to the canopy
      for (let k = 0; k < 3; k++) {
        const px = x + k * 300, py = G - 120 - k * 112;
        run.plats.push({ x: px, y: py, w: PLAT_W });
        coinLine(run, px + 60, py - 40, 3);
      }
      run.coins.push({ x: x + 600 + PLAT_W / 2, y: G - 344 - 110, gem: gemKind() });
      run.monkeys.push({ x: x + 600 + PLAT_W * 0.6, ph: rnd(0, 6) });
      addSpiky(run, x + 420);
      len = 600 + PLAT_W; break;
    }
    case 'mount': {                                                    // an animal waiting: a trail of coins leads to it
      coinLine(run, x, G - 40, 5);
      run.items.push({ x: x + 330, kind: pick(Object.keys(MOUNTS)), ph: rnd(0, 6) });
      run.nextMount = x / PPM + rnd(650, 950) / friend(up);
      len = 460; break;
    }
  }
  // Under a roof nobody can jump, so nothing there may have to be jumped over.
  for (const pl of run.plats) if (pl.t) for (const o of run.obs)
    if (o.x + o.w > pl.x - 30 && o.x < pl.x + pl.w + 30 && o.y + o.h > pl.y + pl.t) o.gone = true;
  if (kind !== 'coins' && kind !== 'mount') run.blockEnd = x + len;

  const gap = (run.speed * 0.7 + 150) * rnd(0.85, 1.4) * (kind === 'coins' ? 1.3 : 1);
  if (kind === 'coins' || Math.random() < 0.55) {
    const n = Math.min(8, Math.floor((gap - 200) / 44));
    const cx = x + len + 100;
    if (n >= 3) {
      const style = pick(tier === 2 && !run.fm && !run.fmDue ? ['line', 'arc', 'wave', 'wave'] : ['line', 'arc']);
      if (style === 'arc') coinArc(run, cx, tier ? 200 : 110, n, (n - 1) * 44);
      else for (let i = 0; i < n; i++) {
        const wx = cx + i * 44;
        run.coins.push({ x: wx, y: floorAt(run, wx) - (style === 'line' ? 40 : 320 - Math.sin(i * 0.7) * 130) });
      }
      if (up.lucky && Math.random() < 0.12 * up.lucky) run.coins.push({ x: cx + n * 44 + 30, y: floorAt(run, cx + n * 44 + 30) - 110, gem: gemKind() });
    }
  }
  run.nextX = x + len + gap;
  scatter(run, laid);
}

// Coins along the sides of a regular shape: 4 sides is a diamond (or a square, turned), 12 a circle.
function shape(run, cx, cy, r, sides, each, turn) {
  for (let k = 0; k < sides; k++) {
    const a = turn + k * 2 * Math.PI / sides, b = turn + (k + 1) * 2 * Math.PI / sides;
    for (let i = 0; i < each; i++) {
      const t = i / each;
      run.coins.push({ x: cx + r * (Math.sin(a) + (Math.sin(b) - Math.sin(a)) * t), y: cy - r * (Math.cos(a) + (Math.cos(b) - Math.cos(a)) * t) });
    }
  }
}

// What comes while a mount is ridden. The gorilla plays on the floor and under the vines, with coins
// in straight lines and diagonals; the rhino on the floor only, with lines and heaps; the Moskito
// everywhere, with zigzags and shapes. Flat ground throughout, and creatures that keep their place.
function spawnRide(run) {
  const x = run.nextX, G = GROUND, v = run.speed, kind = run.mount.kind;
  const onFloor = (at) => (Math.random() < 0.5 ? addSpiky(run, at) : addCrates(run, at, 1));
  const still = (at, alt) => { addFlyer(run, at, alt).still = true; };
  let len = 0;

  if (kind === 'gorilla') {
    const top = HANG_Y - 50, vines = G - HANG_Y + 62;                  // coins and creatures along the vines
    const reach = v * 0.9 + 280;                                       // room to get from the floor to the vines, or back
    switch (pick(['low', 'low', 'high', 'high', 'both', 'both', 'diag', 'diag', 'line'])) {
      case 'low': onFloor(x + 120); coinLine(run, x, top, 8); len = 320; break;
      case 'high': still(x + 120, vines); coinLine(run, x, G - 40, 8); len = 320; break;
      case 'both':
        if (Math.random() < 0.5) { onFloor(x); still(x + reach, vines); } else { still(x, vines); onFloor(x + reach); }
        len = reach + 70; break;
      case 'diag': {
        const up = Math.random() < 0.5;
        for (let i = 0; i < 10; i++) run.coins.push({ x: x + i * 44, y: G - 40 + (top - G + 40) * (up ? i / 9 : 1 - i / 9) });
        len = 400; break;
      }
      case 'line': coinLine(run, x, Math.random() < 0.5 ? top : G - 40, 10); len = 400; break;
    }
  } else if (kind === 'rhino') {
    switch (pick(['crates', 'crates', 'spiky', 'spiky', 'mix', 'line', 'heap', 'heap'])) {
      case 'crates': {                                                 // piles to charge through, coins inside
        const count = 1 + Math.floor(Math.random() * 3);
        for (let k = 0; k < count; k++) addCrates(run, x + k * 170, 1 + Math.floor(Math.random() * 3));
        coinLine(run, x + 30, G - 40, count * 4 - 1);
        len = count * 170; break;
      }
      case 'spiky': addSpiky(run, x); len = SPIKY.w; break;
      case 'mix': addCrates(run, x, 2); addSpiky(run, x + v * 0.7 + 260); len = v * 0.7 + 260 + SPIKY.w; break;
      case 'line': coinLine(run, x, G - 40, 12); len = 500; break;
      case 'heap':                                                     // a heap of coins: two rows at a run, the third for a hop
        coinLine(run, x, G - 40, 5); coinLine(run, x + 22, G - 78, 4); coinLine(run, x + 44, G - 116, 3);
        len = 200; break;
    }
  } else {
    const lanes = [70, 180, 290, 400, 510];                            // heights above the floor
    switch (pick(['flyers', 'flyers', 'gate', 'gate', 'tower', 'zigzag', 'zigzag', 'shape', 'shape'])) {
      case 'flyers': {
        const mixed = lanes.slice().sort(() => Math.random() - 0.5).slice(0, Math.random() < 0.4 ? 3 : 2);
        mixed.forEach((alt, k) => still(x + k * 260, alt));
        len = mixed.length * 260; break;
      }
      case 'gate': {                                                   // a column of creatures with a wide opening
        const open = Math.floor(Math.random() * 4);
        lanes.forEach((alt, k) => { if (k !== open && k !== open + 1) still(x + 200, alt); });
        coinLine(run, x, G - (lanes[open] + lanes[open + 1]) / 2, 8);
        len = 360; break;
      }
      case 'tower': {
        const count = 3 + Math.floor(Math.random() * 3);
        addCrates(run, x + 110, count); coinLine(run, x, G - count * CRATE.h - 100, 6);
        len = 260; break;
      }
      case 'zigzag': {                                                 // each slope lasts over a second, whatever the speed: the Moskito keeps up
        const half = Math.max(7, Math.ceil(v * 1.2 / 44)), count = half * 3;
        for (let i = 0; i < count; i++) { const k = i % (2 * half); run.coins.push({ x: x + i * 44, y: 150 + (G - 250) * (k < half ? k / half : (2 * half - k) / half) }); }
        len = count * 44; break;
      }
      case 'shape': {
        const drawn = SHAPES.filter((s) => s.top <= REACH[2] - 80);        // one from the file, lifted into the sky, or a plain figure
        if (drawn.length && Math.random() < 0.6) { const s = pick(drawn); len = layShape(run, s, x, rnd(0, REACH[2] - 80 - s.top)); break; }
        const [sides, each, turn] = pick([[4, 3, 0], [4, 3, Math.PI / 4], [3, 4, 0], [12, 1, 0]]);
        shape(run, x + 100, rnd(210, G - 190), 96, sides, each, turn);
        len = 200; break;
      }
    }
  }
  run.blockEnd = x + len;
  run.nextX = x + len + (v * 0.7 + 220) * rnd(0.9, 1.3);
}

// ---------- update ----------

// A coin thrown out of something broken: it pops up ahead of the hero, then flies to him (see update).
function loot(run, x, y) { run.coins.push({ x: x + rnd(-10, 10), y, vx: rnd(40, 360), vy: rnd(-560, -260), loot: 0 }); }

// Breaking an obstacle. A crate bursts into four spinning pieces of itself (the renderer cuts them out
// of its picture), splinters and dust, and lets go two coins; a pile does so crate by crate.
function destroy(run, o) {
  o.gone = true;
  const cx = o.x + o.w / 2;
  if (o.kind !== 'crate') {
    burst(run, cx, o.y + o.h / 2, '#b04a8f', 14, 320);
    loot(run, cx, o.y + o.h / 2);
    run.shake = Math.max(run.shake, 0.25);
    run.events.push('break');
    return;
  }
  const biome = biomeAt(run, o.x), count = o.n || 1;
  for (let k = 0; k < count; k++) {
    const cy = o.y + o.h - (k + 0.5) * CRATE.h;
    for (let q = 0; q < 4; q++) run.parts.push({ x: cx + (q % 2 ? 14 : -14), y: cy + (q < 2 ? -12 : 12), vx: run.speed * rnd(0.45, 1.25), vy: rnd(-560, -140), life: 0, max: rnd(0.6, 0.95), g: 1700, shard: q, biome, rot: 0, vr: rnd(-13, 13) });
    for (let i = 0; i < 5; i++) run.parts.push({ x: cx + rnd(-24, 24), y: cy + rnd(-20, 20), vx: run.speed * rnd(0.3, 0.9), vy: rnd(-90, 30), life: 0, max: rnd(0.3, 0.55), c: pick(['#e9dcc0', '#cbb894', '#fff6dc']), s: rnd(10, 20), g: -80 });   // dust
    loot(run, cx, cy); loot(run, cx, cy);
  }
  burst(run, cx, o.y + o.h / 2, '#e8c890', 8 + 3 * count, 420);      // splinters
  run.shake = Math.max(run.shake, 0.26 + 0.06 * count);
  run.events.push('crate');
}

// Hit on a mount: the animal takes the blow in the hero's place and vanishes in a puff.
function dismount(run) {
  const p = run.p, px = run.cam + run.sx;
  for (let i = 0; i < 24; i++) run.parts.push({ x: px + rnd(-60, 60), y: p.y - rnd(0, 110), vx: rnd(-160, 160), vy: rnd(-220, -20), life: 0, max: rnd(0.4, 0.9), c: pick(['#f4f0e0', '#cfd3e6', '#9aa0b8']), s: rnd(9, 20), g: -120 });
  run.gone = { kind: run.mount.kind, hang: p.hang, x: px, y: p.y, t: 0 };   // drawn for a moment more: it tumbles away and fades
  run.mount = null;
  p.hang = false; p.vineLeap = false; p.jumps = 1;
  p.inv = 1.5; run.shake = 0.5; run.flash = 0.6;
  run.nextMount = Math.max(run.nextMount, run.dist + rnd(350, 550) / friend(run.up));
  run.events.push('unmount');
}

// Losing a heart leaves a moment of invincibility; the last one ends the run (or triggers the rewind).
// On a mount nothing is lost: the animal vanishes instead.
function hit(run, o) {
  o.gone = true;
  if (run.mount) { dismount(run); return; }
  run.hearts--;
  run.shake = 0.6; run.flash = 1;
  if (run.hearts > 0) {
    run.p.inv = 1.6;
    burst(run, run.cam + run.sx, run.p.y - 40, '#ff4d6d', 12, 300);
    run.events.push('hurt');
    return;
  }
  if (run.rewindLeft > 0) {
    run.rewindLeft--;
    run.hearts = run.maxHearts;
    run.p.inv = 2;
    run.glitch = 1;
    run.obs = run.obs.filter((q) => q.x > run.cam + run.viewW);
    run.fm = null; run.fmDue = false; run.nextFM = run.dist + rnd(170, 300);
    run.events.push('rewind');
    return;
  }
  if (run.up.lastLeap) {                        // Dernier élan: knocked out, he still bounces a few metres further
    const p = run.p;
    run.leap = { n: run.up.lastLeap, v: Math.max(420, run.speed) };
    p.vy = -640; p.ground = false; p.plat = null; p.rotor = false;
    burst(run, run.cam + run.sx, p.y - 40, '#ff4d6d', 14, 320);
    run.events.push('hurt', 'bounce');
    return;
  }
  die(run);
}

function die(run) {
  run.dead = true;
  run.shake = 1;
  burst(run, run.cam + run.sx, run.p.y - 40, '#5cf2e0', 26, 420);
  run.events.push('hit');
}

function jump(run, v) {
  const p = run.p;
  p.vy = v; p.ground = false; p.plat = null; p.jumps++; p.buf = 0;
  run.events.push('jump');
}

// A new line-up of mosquitoes. How many lanes they take grows with the distance run, with some luck
// either way: one lane, then two, then all but two neighbouring ones, then all but one. A lane the
// hero can reach with what he owns is always left free.
function wave(run) {
  const f = run.fm, up = run.up, N = FM.lanes;
  const reach = up.flight ? N : up.doubleJump ? 3 : 2;
  const level = Math.max(0, Math.min(3, Math.floor(run.dist / 450 + rnd(-0.6, 0.6))));
  const safe = Math.floor(Math.random() * reach);
  f.act = Array(N).fill(false);
  if (level < 2) {                                                     // one or two lanes, among those he is likely to be in
    const low = [0, 1, 2].filter((k) => k !== safe).sort(() => Math.random() - 0.5);
    for (const k of low.slice(0, level + 1)) f.act[k] = true;
  } else {
    const twin = level === 3 ? -1 : safe + 1 < N && (safe === 0 || Math.random() < 0.5) ? safe + 1 : safe - 1;
    for (let k = 0; k < N; k++) f.act[k] = k !== safe && k !== twin;
  }
  f.level = level;
  f.phase = 'aim'; f.t = 0; f.sx = run.viewW + 90; f.hit = false;
  f.ghost = !!run.up.drunk && Math.random() < DRUNK[run.up.drunk];
  run.events.push('fm');
}

function followers(run, d, box, dashing) {
  const p = run.p, px = run.cam + run.sx;
  if (!run.fm) {
    if (run.mount) { run.fmDue = false; run.nextFM = Math.max(run.nextFM, run.dist + 100); return; }   // never on top of a ride
    if (!run.fmDue && run.dist >= run.nextFM) run.fmDue = true;          // from now on only coins are laid ahead
    if (!run.fmDue || px < run.blockEnd + 60) return;                    // waits until the road is clear
    run.fm = { kind: 'mosquito', waves: 1 + (run.dist > 450 && Math.random() < 0.6 ? 1 : 0) + (run.dist > 900 && Math.random() < 0.5 ? 1 : 0), aim: 1.7 };
    wave(run);
  }
  const f = run.fm;
  f.t += d;
  if (f.phase === 'aim') {                                               // they follow the hero from the right edge
    f.sx += (run.viewW - 110 - f.sx) * Math.min(1, d * 5);
    if (f.t >= f.aim) { f.phase = 'rush'; f.t = 0; run.events.push('rush'); }
    return;
  }
  f.sx += (f.t < 0.14 ? 260 : -FM.rush) * d;                             // a short recoil, then the charge
  const x0 = run.cam + f.sx - FM.w / 2;
  if (!f.hit && !f.ghost && x0 + 8 < box.R && x0 + FM.w - 8 > box.L) for (let k = 0; k < FM.lanes; k++) {
    const y0 = GROUND - (k + 0.5) * FM.step - FM.h / 2;
    if (!f.act[k] || y0 + 6 > box.B || y0 + FM.h - 6 < box.T) continue;
    if (dashing) { f.hit = true; f.sx = -999; run.gold += 3; burst(run, px + 40, y0 + FM.h / 2, '#7fe0c8', 18, 340); run.shake = Math.max(run.shake, 0.3); run.events.push('break'); }
    else if (p.inv === 0) { f.hit = true; hit(run, {}); if (run.dead || run.leap || !run.fm) return; }
    break;
  }
  if (f.sx > -FM.w) return;
  if (!f.hit) run.events.push('dodge');
  f.aim = 1.15;
  if (--f.waves > 0) { wave(run); return; }
  run.fm = null; run.fmDue = false;
  run.nextFM = run.dist + rnd(170, 300);
  run.nextX = Math.max(run.nextX, run.cam + run.viewW + 150);            // obstacles come back from beyond the screen
}

export function update(run, dt, input) {
  // Particles and screen effects keep living after death.
  run.shake = Math.max(0, run.shake - dt * 2.5);
  run.glitch = Math.max(0, run.glitch - dt * 1.6);
  run.flash = Math.max(0, run.flash - dt * 4);
  run.p.squash = Math.max(0, run.p.squash - dt * 7);
  run.boom = Math.max(0, run.boom - dt * 2.2);
  run.blend = Math.min(1, run.blend + dt / 1.2);
  const ts = run.slow.t > 0 ? 0.45 : 1;       // the Sablier slows the world, not the timers
  const d = dt * ts;
  if (run.gone && (run.gone.t += dt) > 0.7) run.gone = null;
  for (const q of run.parts) {
    q.life += d; q.vy += q.g * d; q.x += q.vx * d; q.y += q.vy * d;
    if (q.shard === undefined && q.coin === undefined) continue;
    if (q.vr) q.rot += q.vr * d;                     // a piece of crate tumbles; like a thrown coin, it bounces
    const f = floorAt(run, q.x) - 8;
    if (q.y > f && q.vy > 0) { q.y = f; q.vy *= -0.5; if (q.vr) { q.vx *= 0.7; q.vr *= 0.6; } }
  }
  run.parts = run.parts.filter((q) => q.life < q.max);
  if (run.dead) return;

  if (run.wait > 0) {                           // still inside: the temple shakes, dust falls from the lintel
    run.wait -= dt; run.shake = Math.max(run.shake, 0.22);
    if (Math.random() < 0.6) run.parts.push({ x: rnd(60, 125), y: GROUND - rnd(195, 225), vx: rnd(-20, 40), vy: rnd(20, 120), life: 0, max: 0.5, c: '#cfd3e6', s: rnd(4, 8), g: 500 });
    if (run.wait > 0) return;
    run.exploded = true; run.shake = 1; run.boom = 1;
    for (let i = 0; i < 46; i++) {              // the doorway bursts outward in blocks of stone and moss
      run.parts.push({ x: rnd(60, 130), y: GROUND - rnd(40, 220), vx: rnd(80, 900), vy: rnd(-760, -40), life: 0, max: rnd(0.8, 1.7),
        c: pick(['#8a8fa8', '#6a6f8c', '#4a4f6c', '#7bd13c', '#cfd3e6']), s: rnd(8, 22), g: 1500 });
    }
    for (let i = 0; i < BLAST_COINS; i++) {     // and the temple's gold flies out towards the jungle: real coins, which bounce and wait on the path
      run.coins.push({ x: rnd(70, 130), y: GROUND - rnd(50, 200), toss: { vx: rnd(420, 1500), vy: rnd(-820, -120) } });
    }
    run.events.push('boom');
  }

  const p = run.p, up = run.up;

  // --- actives ---
  run.dash.t = Math.max(0, run.dash.t - dt); run.dash.cd = Math.max(0, run.dash.cd - dt);
  run.slow.t = Math.max(0, run.slow.t - dt); run.slow.cd = Math.max(0, run.slow.cd - dt);
  if (!run.leap && input.dash && up.dash && run.dash.cd === 0) {
    run.dash.t = 0.55; run.dash.cd = run.dash.max; run.events.push('dash');
  }
  if (!run.leap && input.slow && up.slow && run.slow.cd === 0) {
    run.slow.t = SLOW_TIME[up.slow]; run.slow.cd = SLOW_CD; run.events.push('slow');
  }
  const dashing = run.dash.t > 0;

  // --- scrolling: the hero first runs out of the temple, then the camera follows him ---
  run.t += d;
  run.speed = run.base + run.t * SPEED.gain
    + (run.mount && run.mount.kind === 'rhino' ? Math.min(420, run.mount.t * 20) : 0);   // the rhino only ever gathers speed
  run.vine = Math.max(0, Math.min(1, run.vine + (run.mount && run.mount.kind === 'gorilla' ? 1 : -1) * dt * 2.5));
  if (run.leap) run.leap.v = Math.max(160, run.leap.v - 170 * d);       // knocked out: he only slows down
  // he is thrown out of the temple faster than he runs
  const move = (run.leap ? run.leap.v : run.speed * (dashing ? 1.7 : 1) * (run.exploded && run.sx < PX ? 1.8 : 1)) * d;
  if (run.sx < PX) run.sx = Math.min(PX, run.sx + move);
  else run.cam += move;
  run.dist = run.cam / PPM;
  const px = run.cam + run.sx;
  const fl = floorAt(run, px);                   // the floor right under him

  if (run.leap) {                                // --- Dernier élan: a rag doll bouncing along, nothing can touch him ---
    p.vy += 2000 * d; p.y += p.vy * d; p.roll += d * 11; p.flying = false;
    if (p.y >= fl) {
      p.y = fl;
      for (let i = 0; i < 8; i++) run.parts.push({ x: px + rnd(-20, 20), y: fl - 2, vx: rnd(-160, 160), vy: rnd(-110, -20), life: 0, max: 0.35, c: '#f4f0e0', s: rnd(4, 9), g: 0 });
      if (run.leap.n-- > 0) { p.vy = -520 - 50 * run.leap.n; run.shake = Math.max(run.shake, 0.3); run.events.push('bounce'); }
      else { die(run); return; }
    }
  } else {
    // --- player ---
    const M = run.mount && MOUNTS[run.mount.kind], gorilla = run.mount && run.mount.kind === 'gorilla';
    const spring = 1 + 0.1 * (up.spring || 0);
    p.inv = Math.max(0, p.inv - dt);
    p.buf = Math.max(0, p.buf - dt);
    p.spin = Math.max(0, p.spin - dt);
    p.flying = false;
    const half = M ? M.half : HERO_HALF, tall = M ? M.tall : HERO_H;
    // curling up and uncurling: a puff of leaves hides the change
    const puff = () => { for (let i = 0; i < 12; i++) run.parts.push({ x: px + rnd(-22, 22), y: p.y - rnd(8, 60), vx: rnd(-180, 120), vy: rnd(-200, 40), life: 0, max: rnd(0.3, 0.6), c: pick(['#8fd14a', '#c9e86a', '#5fae3a', '#f4f0e0']), s: rnd(5, 11), g: 300 }); };
    if (p.ball && px > p.ball.x + p.ball.w) { p.ball = null; p.y = fl; puff(); run.events.push('unroll'); }      // out at the far end, back on his feet
    if (!p.ball && up.sphere && !M && p.ground && !p.plat) {                   // the Sphère: a tight place begins here, in he rolls
      p.ball = run.zones.find((z) => px >= z.x && px < z.x + 110) || null;
      if (p.ball) { p.balled = 0; puff(); run.events.push('roll'); }
    }
    if (p.ball) {
      const z = p.ball, k = Math.min(1, (px - z.x) / 70, (z.x + z.w - px) / 70);
      p.ground = true; p.plat = null; p.vy = 0; p.rotor = false; p.jumps = 0;
      p.y = fl + (z.kind === 'gallery' ? GALLERY * Math.max(0, k) : 0);
      p.roll += run.speed * d / 26; p.balled += dt;
    } else if (M && M.fly) {
      // the Moskito: held, it climbs; let go, it sinks. It turns round at once, no run-up either way.
      p.ground = false; p.plat = null; p.rotor = false;
      p.vy += ((input.hold ? -480 : 440) - p.vy) * Math.min(1, d * 16);
      p.y += p.vy * d;
      if (p.y > fl - 12) { p.y = fl - 12; p.vy = Math.min(p.vy, 0); }
      if (p.y - tall < CEIL) { p.y = CEIL + tall; p.vy = Math.max(p.vy, 0); }
    } else if (p.hang) {
      // the gorilla under the vines: it swings from one to the next until a press lets go
      p.y = HANG_Y; p.vy = 0;
      p.phase += 1.5 * Math.PI * 2 * d;
      if (input.pressed) { p.hang = false; p.vy = 160; p.jumps = 1; run.events.push('drop'); }
    } else {
      if (input.pressed) {
        if (p.ground) jump(run, (M ? M.jump : -760) * spring);     // on foot, a press is a plain jump
        else if (gorilla && p.jumps < 2) {                         // the gorilla's second jump goes as high as it takes to reach the vines
          jump(run, -Math.sqrt(2 * 2400 * Math.max(80, p.y - HANG_Y + 40))); p.vineLeap = true;
          burst(run, px, p.y, '#ffffff', 8, 160);
        } else if (!M && up.doubleJump && p.jumps < 2) { jump(run, -700 * spring); burst(run, px, p.y, '#ffffff', 6, 120); p.rotor = !!up.flight; }
        else if (!M && up.flight) {                                // in the air, every press lifts him at once
          p.rotor = true; p.spin = 0.22; p.vy = Math.min(p.vy, -FLAP);
          run.events.push('flap');
        } else p.buf = 0.12;                                       // pressed just before landing: remembered
      }
      if (!input.hold) p.rotor = false;                            // released: he drops straight away
      if (p.ground && p.plat && (px < p.plat.x - HERO_HALF || px > p.plat.x + p.plat.w + HERO_HALF)) {
        p.ground = false; p.plat = null; p.jumps = 1;          // ran off the end of a ledge
      }
      if (p.ground && !p.plat) p.y = fl;             // on a slope he simply follows it
      if (!p.ground) {
        const before = p.y;
        if (p.rotor) p.vy = Math.min(-FLAP, p.vy + 2400 * d);    // the leaf rotor: a steady climb for as long as it is held
        else p.vy += (input.hold && p.vy < 0 && !p.vineLeap ? 1500 : 2400) * d;   // holding makes the jump higher
        p.flying = p.rotor || p.spin > 0;
        if (p.flying && Math.random() < 0.25) run.parts.push({ x: px + rnd(-40, 40), y: p.y - 105, vx: rnd(-160, -40), vy: rnd(-40, 60), life: 0, max: 0.6, c: pick(['#8fd14a', '#c9e86a', '#5fae3a']), s: rnd(4, 8), g: 300 });   // leaves shaken off his rotor
        p.y += p.vy * d;
        if (p.vineLeap && p.y <= HANG_Y) {                       // the vines: caught
          p.y = HANG_Y; p.vy = 0; p.hang = true; p.vineLeap = false; p.jumps = 0;
          run.events.push('grab');
        }
        if (p.y - tall < CEIL) { p.y = CEIL + tall; if (p.vy < 0) p.vy = 0; }
        for (const pl of run.plats) {                           // under a cave roof or inside a log: he bumps his head
          const under = pl.y + (pl.t || 0);
          if (pl.t && px > pl.x && px < pl.x + pl.w && p.y > under + HERO_H * 0.6 && p.y - HERO_H < under) { p.y = under + HERO_H; if (p.vy < 0) p.vy = 0; }
        }
        let land = p.y >= fl ? fl : null, on = null;
        if (p.vy > 0) for (const pl of run.plats) {            // ledges only catch a falling hero
          if (before <= pl.y && p.y >= pl.y && px > pl.x - HERO_HALF && px < pl.x + pl.w + HERO_HALF) { land = pl.y; on = pl; break; }
        }
        if (land !== null) {
          p.y = land; p.vy = 0; p.ground = true; p.plat = on; p.jumps = 0; p.squash = 1; p.rotor = false; p.spin = 0; p.vineLeap = false;
          for (let i = 0; i < 5; i++) run.parts.push({ x: px + rnd(-16, 16), y: land - 2, vx: rnd(-140, 140), vy: rnd(-70, -20), life: 0, max: 0.3, c: '#f4f0e0', s: rnd(4, 8), g: 0 });
          if (on) run.events.push('land');
          if (p.buf > 0) jump(run, (M ? M.jump : -760) * spring);
        }
      } else {
        // strides per second: quicker as he speeds up, but never a blur
        p.phase += (1.75 + (Math.min(900, run.speed) - 360) / 600) * Math.PI * 2 * d * (dashing ? 1.4 : 1);
        if (Math.random() < 0.25) run.parts.push({ x: px - 30, y: p.y - 2, vx: rnd(-90, -30), vy: rnd(-50, -10), life: 0, max: 0.35, c: '#f4f0e0', s: rnd(4, 8), g: 0 });
      }
    }
    if (dashing && Math.random() < 0.8) run.parts.push({ x: px - 20, y: p.y - rnd(5, 75), vx: -300, vy: 0, life: 0, max: 0.25, c: '#ffd35c', s: rnd(4, 8), g: 0 });

    // --- mounts: the ones ahead wait to be touched ---
    if (run.mount) run.mount.t += dt;
    for (const it of run.items) {
      if (run.mount || Math.abs(px - it.x) > 75 || p.y < floorAt(run, it.x) - (MOUNTS[it.kind].fly ? 300 : 170)) continue;   // close enough to touch it
      run.mount = { kind: it.kind, t: 0 };
      it.gone = true; p.rotor = false; p.hang = false; p.vineLeap = false; p.inv = Math.max(p.inv, 0.5);
      if (MOUNTS[it.kind].fly) { p.ground = false; p.plat = null; p.vy = -200; p.y = Math.min(p.y, floorAt(run, it.x) - 60); }
      burst(run, it.x, p.y - 70, '#ffd35c', 16, 260);
      run.events.push('mount');
    }

    // --- obstacles ---
    const box = { L: px - half, R: px + half, T: p.y - tall + 6, B: p.y - 2 };
    for (const o of run.obs) {
      if (p.ball) break;                           // nothing reaches him in there
      if (o.kind === 'fly') { if (!o.still) o.x -= 120 * d; o.y = o.baseY + Math.sin(run.t * 3 + o.ph) * 12; }
      if (o.kind === 'spider') {                   // down it comes, with a little bounce at the end of its thread
        if (!o.dropped && o.x - px < run.speed * SPIDER.ahead) { o.dropped = true; run.events.push('spider'); }
        if (o.dropped && (o.y < o.rest || o.vy)) {
          o.vy += 2600 * d; o.y += o.vy * d;
          if (o.y >= o.rest) { o.y = o.rest; o.vy = o.vy > 160 ? -o.vy * 0.3 : 0; }
        }
      }
      if (o.gone || o.x + 6 > box.R || o.x + o.w - 6 < box.L || o.y + 6 > box.B || o.y + o.h - 6 < box.T) continue;
      if (dashing) destroy(run, o);
      else if (o.ghost) { if (!o.passed) { o.passed = true; burst(run, o.x + o.w / 2, o.y + o.h / 2, '#c9f3ff', 6, 120); } }
      else if (M && M.smash && o.kind === 'crate') destroy(run, o);
      else if (o.fragile && up.breaker) destroy(run, o);
      else if (p.inv === 0) { hit(run, o); if (run.dead) return; break; }
    }
    if (!run.leap) followers(run, d, box, dashing);
    if (run.dead) return;
  }
  run.items = run.items.filter((it) => !it.gone && it.x > run.cam - 200);
  run.zones = run.zones.filter((z) => z.x + z.w > run.cam - 200 || z === p.ball);
  run.obs = run.obs.filter((o) => !o.gone && o.x + o.w > run.cam - 120);
  run.plats = run.plats.filter((pl) => pl.x + pl.w > run.cam - 120);

  while (run.terrain.length > 2 && run.terrain[1].x < run.cam - 300) run.terrain.shift();

  // --- spawning ---
  const edge = run.cam + run.viewW + 200;
  while (run.nextX < edge) spawnPattern(run);

  // --- scenery change ---
  if (run.dist >= run.nextBiomeAt) {
    run.prevBiome = run.biome;
    run.biome = (run.biome + 1 + Math.floor(Math.random() * (BIOME_COUNT - 1))) % BIOME_COUNT;
    run.biomeX = run.cam + run.viewW + 400;       // the new scenery starts ahead, off screen, and scrolls in
    run.nextBiomeAt += BIOME_LEN;
    run.events.push('biome');
  }

  if (!run.leap) {
    // --- scenery reacting as he runs past: it shivers and lets something go ---
    const cell = Math.floor(px / PROP_CELL);
    for (const i of [cell - 1, cell]) {
      const pr = propAt(i), react = pr && REACTS[pr.kind];
      if (!react || run.touched.has(i) || p.y < fl - TOUCH_H || biomeAt(run, pr.x) !== 0 || !flatAt(run, pr.x, PROP_CELL * 0.6)) continue;
      const cx = pr.x + 34 * PIXEL;
      if (px < cx - 20 || px > cx + 90) continue;
      run.touched.set(i, run.t);
      for (let k = 0; k < react[1]; k++) run.parts.push({ x: cx + rnd(-40, 40), y: fl - rnd(60, 150), vx: rnd(-50, 90), vy: rnd(-150, -30), life: 0, max: rnd(0.7, 1.4), c: react[0], s: rnd(4, 8), g: 90 });
      run.events.push(pr.kind === PROP.SHROOM ? 'shroom' : 'rustle');
    }
    for (const [i, when] of run.touched) if (run.t - when > 6) run.touched.delete(i);

    // --- monkeys in the vines: climb high enough under one and it waves back ---
    for (const m of run.monkeys) {
      if (!m.seen && Math.abs(px - m.x) < 70 && p.y < GROUND - MONKEY_H) {
        m.seen = run.t; run.events.push('monkey');
        burst(run, m.x, 150, '#ffd35c', 10, 200);
      }
    }
  }
  run.monkeys = run.monkeys.filter((m) => m.x > run.cam - 200);

  // --- coins and gems ---
  const reach = MAGNET[up.magnet || 0], cy = p.y - (p.ball ? 20 : 40);
  const grab = run.mount && MOUNTS[run.mount.kind].grab;
  for (const c of run.coins) {
    if (c.tight && !p.ball) continue;                // inside a tight place: for the ball only
    if (c.toss) {                                    // thrown by the blast: it falls, bounces lower each time, then stays at running height
      const q = c.toss, f = floorAt(run, c.x) - 40;
      q.vy += 1000 * d; c.x += q.vx * d; c.y += q.vy * d;
      if (c.y > f && q.vy > 0) { c.y = f; q.vy *= -0.45; q.vx *= 0.55; if (q.vy > -70) c.toss = null; }
    }
    const dx = px - c.x, dy = cy - c.y, dist = Math.hypot(dx, dy);
    if (c.loot !== undefined) {                      // out of a crate: thrown up and ahead, then drawn to the hero
      c.loot += d;
      if (c.loot < 0.32) { c.vy += 1500 * d; c.x += (c.vx + run.speed) * d; c.y += c.vy * d; continue; }
      if (dist >= 44) { c.x += dx / dist * 1000 * d + run.speed * d; c.y += dy / dist * 1000 * d; continue; }
    }
    if (grab ? Math.abs(dx) < grab.w && c.y > p.y - grab.h && c.y < p.y + 10 : dist < 44) {
      c.gone = true;
      if (c.heart) {                                 // a heart found: a life back, or its worth in gold when none is missing
        if (run.hearts < run.maxHearts) run.hearts++; else run.gold += HEART_GOLD;
        run.events.push('heart'); burst(run, c.x, c.y, '#ff6b8a', 14, 260);
      }
      else if (c.gem) { run.gold += GEMS[c.gem] || 10; run.gems++; run.events.push('gem'); burst(run, c.x, c.y, { y: '#ffe36a', r: '#ff6b6b' }[c.gem] || '#5cc8ff', 10, 220); }
      else { run.gold++; run.events.push('coin'); burst(run, c.x, c.y, '#fff3a8', 4, 150); }
      continue;
    }
    if (dist < reach) { c.x += dx / dist * 700 * d + run.speed * d; c.y += dy / dist * 700 * d; }
  }
  run.coins = run.coins.filter((c) => !c.gone && c.x > run.cam - 60);
}
