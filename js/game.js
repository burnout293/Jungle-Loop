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
const CRATE = { w: 63, h: 52 }, SPIKY = { w: 68, h: 54 }, PLAT_W = 254;

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
export const SPEED = { base: 280, gain: 5, sprint: 160 };
// A jump: the push of a press (units per second), of the double jump, and gravity, lighter while the
// press is held on the way up. (The debug menu works out heights from these.)
const RAMP = 70;
export const JUMP = { v: 760, double: 700, gravity: 2400, held: 1500 };   // units per second: at the door, gained each second (for ever), added by Sprint
// The dangers are four roles, each drawn its own way in each scenery (render.js picks the picture from
// the obstacle's `biome`):
// - the spiky one sits on the floor: jump it (hedgehog, ball of brambles, bear trap, mine);
// - the flyer: a "!" at the right edge shows the height it will come at, DART.warn seconds before it
//   crosses the whole screen in one go (beetle, vulture, arrow, missile);
// - the hanging one stays still in mid-air, never touching floor or ceiling (spider, stone idol, bat,
//   drone): low, it is jumped; at head height (from HOVER.from.mid metres), the hero stays down;
// - the swarm, the follower monster (see FM).
const DART = { w: 64, h: 40, warn: 1.0, speed: 800 };   // `speed`: how fast it flies, on top of the hero's own
const HOVER = { w: 60, h: 56 };
// Not before this many metres: the hanging dangers, low then at head height.
export const FROM = { low: 500, mid: 1500 };   // (the debug menu may change these)

// Mounts: rare friendly animals waiting on the path. Running into one puts the hero on its back until
// something hits them: the animal takes the blow and vanishes. Each one plays its own game, and the
// path ahead is laid out for it (see spawnRide):
// - the gorilla jumps a little higher, and its second jump always carries it up to the vines along
//   the top of the screen, where it swings on until a press lets go. Floor and vines, nothing between.
// - the rhino barely hops, runs faster and faster, and smashes crates. Everything on the floor.
// - the dragonfly flies: held, it climbs; let go, it sinks. The whole sky.
// `half` and `tall` are the hitbox with the hero on its back. `speed`: each animal has its own pace,
// which starts low when it is caught (`base`, units per second) and keeps rising (`gain` each second).
// The hero's own speed goes on rising meanwhile, and takes over again once the animal is gone.
// `wait` is how it waits to be caught, and can be missed: the gorilla swings along the vines high up
// (a high jump reaches it), the rhino grazes on the path (run into it, do not jump over it), the
// dragonfly zigzags ahead in the air (be where it is). `ahead` is how fast they move on, as a share of
// the hero's speed.
export const MOUNTS = {
  gorilla: { name: 'Gorille', jump: -820, half: 34, tall: 118, speed: { base: 300, gain: 24 }, ahead: 0.45 },
  rhino: { name: 'Rhino', jump: -560, half: 34, tall: 104, smash: true, grab: { w: 78, h: 150 }, speed: { base: 300, gain: 44 }, ahead: 0 },   // grab: it sweeps up coins well above its back
  dragonfly: { name: 'Libellule', fly: true, half: 28, tall: 92, speed: { base: 320, gain: 28 }, ahead: 0.5 },
};
// The boss, Vorace: a giant carnivorous plant. Around BOSS.at metres, in the forest only, it comes in on
// the right and keeps pace with the hero, who runs at BOSS.speed meanwhile; the relic in his backpack
// lights up as it comes. Its tentacles crawl on the floor around it, and it attacks from every side:
// blobs of acid lobbed onto the path (puddles to jump), balls along a low lane (jump), a middle one (stay
// down) or a high one (no big jump), two balls at once, a rain of drops from the sky (their shadows show
// where), a tentacle slithering along the floor (jump). Every attack is announced (jaws open and glow,
// shadows) and every pair leaves a way through. What it throws depends on what the hero rides. After
// BOSS.fight seconds a tree falls on it and crushes it into the ground; the hero runs straight on over a
// line of blue gems. It stands behind the floor and crawls on its root-legs (see render.js): BOSS.w is how
// wide it is on screen, the mouth where its acid comes from (from its left edge, and from the top).
export const BOSS = { at: 2000, speed: 560, fight: 26, w: 420, mouthX: 40, mouthY: 310 };
const LANE = { low: 28, mid: 115, high: 250, vine: 470 };
// The heights a flyer may come at (its middle, above the floor), by what the hero owns: on foot, double jump, flight.
const DART_ALTS = [[46, 170], [46, 170, 290], [46, 170, 290, 400, 510]];   // height of a ball's centre above the floor
const ACID = { ball: 36, puddle: 120, closing: 650 };
// How high above the floor the waiting gorilla's feet hang: right up in the vines, out of reach of a
// plain jump. Flying gets there, and the double jump with a Ressort.
export const PERCH = 400;
const ZIG = { low: 70, high: 230, period: 1.6 };   // the waiting dragonfly's zigzag: heights of its body, seconds per zig and zag
export const HANG_Y = 190;              // where the gorilla's feet are when it hangs from the vines
const friend = (up) => 1 + 0.25 * (up.nature || 0);      // Ami de la nature: mounts come that much sooner

// Follower monsters: mosquitoes line up at the right edge of the screen, one per lane, show which
// lanes they will take, then rush across. The air above the floor is cut into FM.lanes lanes of
// FM.step each; the longer the run, the more of them are taken (see wave). Nothing else blocks the
// way meanwhile.
export const FM = { w: 90, h: 64, rush: 1150, lanes: 5, step: 110 };
// The city's drones: their lasers burn from LASER.on to LASER.off seconds after they stop aiming, LASER.h thick.
export const LASER = { on: 0.25, off: 0.7, end: 0.95, h: 40 };

// Gems: what each colour is worth, and how often each turns up.
export const GEMS = { y: 5, r: 10, b: 20 };
const gemKind = () => pick('yyyyyyrrrb');
// Gems only turn up for whoever wears Gemmes dispersées (and as the boss's prize): elsewhere, a coin.
const gem = (run) => (run.up.scatter ? gemKind() : undefined);
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
      if ('yrb'.includes(ch) && run.up.scatter) c.gem = ch;   // y, r, b: a yellow, red or blue gem (with Gemmes dispersées); anything else is a coin
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
    biome: 0, prevBiome: 0, blend: 1, nextBiomeAt: Infinity, glitch: 0,   // the scenery only changes once a boss is beaten
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
    nextMount: rnd(700, 1000) / friend(upgrades), // in metres: mounts are a rare treat
    fm: null, fmDue: false, nextFM: rnd(150, 230), blockEnd: 0,   // follower monster; where the last blocking pattern ends
    leap: null,                                  // Dernier élan: the bounces after the last heart
    boss: null, bossDone: false, pits: [],       // Vorace, the giant plant, and the hole it falls into
    bossAt: BOSS.at + rnd(-100, 100),            // where it comes, in metres
    relic: 0,                                    // how bright the relic in his backpack shines (1: flaring)
    own: 0, h: 0, maxH: 0,                       // measures: his own speed, his height above the floor and the highest this run
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
export function addSpiky(run, x) { addObs(run, x, floorAt(run, x) - SPIKY.h, SPIKY.w, SPIKY.h, 'spiky', false).biome = biomeAt(run, x); }

// A hanging danger, still in mid-air: low (`h` above the floor of its middle: jump it) or at head height.
export function addHover(run, x, h) {
  const o = addObs(run, x, floorAt(run, x) - h - HOVER.h / 2, HOVER.w, HOVER.h, 'hover', false);
  o.biome = biomeAt(run, x); o.ph = rnd(0, 6); o.mid = h > 100;
  return o;
}
export const LOW = 64, HEAD = 165;                     // the two heights of a hanging danger

// A flyer: it waits beyond the right edge until the screen reaches it, shows a "!" at its height, then crosses.
export function addDart(run, x, alt) {
  const o = addObs(run, x, floorAt(run, x) - alt - DART.h / 2, DART.w, DART.h, 'dart', false);
  o.biome = biomeAt(run, x); o.state = 'wait'; o.t = 0; o.ph = rnd(0, 6);
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
    if (i % 6 === 3) c.gem = gem(run);
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
  if (run.mount && !run.fm && !run.fmDue && !run.boss) { spawnRide(run); scatter(run, laid); return; }
  const up = run.up, x = run.nextX, G = GROUND;
  const tier = up.flight ? 2 : up.doubleJump ? 1 : 0;
  const riding = run.mount || run.items.length;                       // a mount in play: nothing with a roof
  // The first metres are a warm-up: one obstacle at a time, nothing in the air.
  let opts = x < 70 * PPM ? ['crate', 'spiky', 'coins', 'plat']
    : ['crate', 'spiky', 'spiky', 'double', 'fly', 'coins', 'plat', 'cave', 'log', 'gallery', 'stairs', 'ledge', 'ledge', 'hollow'];
  if (x / PPM >= FROM.low) opts.push('hover', 'hover', 'hover');       // the hanging ones
  if (tier >= 1 && x >= 70 * PPM) opts.push('stack', 'fly');
  if (tier >= 2 && x >= 70 * PPM) opts.push('wall', 'swarm', 'swarm');
  const shapes = SHAPES.filter((s) => s.top <= REACH[tier]);
  if (shapes.length && x >= 70 * PPM) opts.push('shape', 'shape');
  if (riding) opts = opts.filter((k) => k !== 'cave');
  if (run.fm || run.fmDue || run.boss) opts = ['coins'];             // a follower monster, or the boss, needs a clear road
  else if (!riding && x > 70 * PPM && x / PPM >= run.nextMount) opts = ['mount'];
  const kind = pick(opts);
  let len = 0;

  switch (kind) {
    case 'crate': addCrates(run, x, 1); len = CRATE.w; break;
    case 'spiky': addSpiky(run, x); len = SPIKY.w; break;
    case 'shape': len = layShape(run, pick(shapes), x); break;         // a drawing made of coins
    case 'hover':
      if (x / PPM < FROM.mid || Math.random() < 0.6) addHover(run, x, LOW);
      else { addHover(run, x + 88, HEAD); coinLine(run, x, floorAt(run, x) - 40, 5); }   // at head height: coins underneath, for whoever stays down
      len = 220; break;
    case 'double': {
      const d = run.speed + 90;
      if (Math.random() < 0.5) addCrates(run, x, 1); else addSpiky(run, x);
      addSpiky(run, x + d);
      len = d + SPIKY.w; break;
    }
    case 'stack': addCrates(run, x, 2); len = CRATE.w; break;          // needs a held jump or the double jump
    case 'wall': addCrates(run, x, 4); coinLine(run, x - 30, G - 290, 3); len = CRATE.w; break;   // fly over it
    case 'fly': addDart(run, x, pick(DART_ALTS[tier])); len = 120; break;          // low: jump; higher: stay down
    case 'swarm': {                                                    // two flyers, one after the other, at different heights
      const [a, b] = DART_ALTS[2].slice().sort(() => Math.random() - 0.5);
      addDart(run, x, a); addDart(run, x + 520, b);
      len = 520; break;
    }
    case 'plat': {                                                     // a ledge to hop on, with a reward
      const y = G - 135;
      run.plats.push({ x, y, w: PLAT_W });
      coinLine(run, x + 40, y - 40, 4);
      if (Math.random() < 0.35 + 0.2 * (up.lucky || 0)) run.coins.push({ x: x + PLAT_W / 2, y: y - 110, gem: gem(run) });
      len = PLAT_W; break;
    }
    case 'cave': {                                                     // two ways: down through the hollow, or over its roof
      const R = 70, w = Math.round(rnd(800, 1200)), y = G - SLAB.h;    // slope length, flat bottom, roof height
      relief(run, x, [[0, 0], [R, -HOLLOW], [R + w, -HOLLOW], [2 * R + w, 0]]);
      run.plats.push({ x: x + R, y, w, t: SLAB.t, kind: 'slab' });     // the roof only covers the deep part: headroom everywhere
      coinLine(run, x + R + w * 0.25, G + HOLLOW - 40, Math.floor(w * 0.5 / 44));         // below: no room to jump, so only coins
      coinLine(run, x + R + 70, y - 40, Math.min(16, Math.floor((w - 140) / 60)));        // above: the bigger reward
      run.coins.push({ x: x + R + w - 60, y: y - 110, gem: gem(run) });
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
      run.coins.push({ x: x + 600 + PLAT_W / 2, y: G - 344 - 110, gem: gem(run) });
      run.monkeys.push({ x: x + 600 + PLAT_W * 0.6, ph: rnd(0, 6) });
      addSpiky(run, x + 420);
      len = 600 + PLAT_W; break;
    }
    case 'mount': {                                                    // an animal waiting: a trail of coins leads to it
      coinLine(run, x, G - 40, 5);
      run.items.push({ x: x + 330, kind: pick(Object.keys(MOUNTS)), ph: rnd(0, ZIG.period * 2), y: G - ZIG.low });
      run.nextMount = x / PPM + rnd(1300, 1800) / friend(up);
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
      if (up.lucky && up.scatter && Math.random() < 0.12 * up.lucky) run.coins.push({ x: cx + n * 44 + 30, y: floorAt(run, cx + n * 44 + 30) - 110, gem: gem(run) });
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
// in straight lines and diagonals; the rhino on the floor only, with lines and heaps; the dragonfly
// everywhere, with zigzags and shapes. Flat ground throughout, and creatures that keep their place.
function spawnRide(run) {
  const x = run.nextX, G = GROUND, v = run.speed, kind = run.mount.kind;
  const onFloor = (at) => (Math.random() < 0.5 ? addSpiky(run, at) : addCrates(run, at, 1));
  const still = (at, alt) => { addHover(run, at, alt); };
  let len = 0;
  const from = run.obs.length;

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
      case 'zigzag': {                                                 // each slope lasts over a second, whatever the speed: the dragonfly keeps up
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
  // laid for the ride: if the animal is lost, what was laid for it goes too (see dismount)
  for (let i = from; i < run.obs.length; i++) run.obs[i].ride = true;
  run.blockEnd = x + len;
  run.nextX = x + len + (v * 0.7 + 220) * rnd(0.9, 1.3);
}

// ---------- the boss ----------

function boss(run, d) {
  const p = run.p;
  if (!run.boss) {
    if (run.bossDone || run.dist < run.bossAt || run.biome !== 0 || run.prevBiome !== 0) return;   // only ever in the forest
    run.boss = { phase: 'enter', t: 0, sx: run.viewW + 60, next: 1.2, wind: 0, attack: '', open: 0 };
    run.items.length = 0;                                                  // no mount waiting during the fight
    for (const o of run.obs) if (!o.gone && o.x + o.w > run.cam + run.sx + 40) {   // nor any other danger: Vorace alone
      o.gone = true;
      for (let i = 0; i < 6; i++) run.parts.push({ x: o.x + rnd(0, o.w), y: o.y + rnd(0, o.h), vx: rnd(-80, 80), vy: rnd(-160, -20), life: 0, max: rnd(0.3, 0.6), c: pick(['#f4f0e0', '#cfd3e6']), s: rnd(6, 14), g: -60 });
    }
    run.relic = 1; run.shake = Math.max(run.shake, 0.6); run.events.push('boss');
    return;
  }
  const b = run.boss, mouth = { x: run.cam + b.sx + BOSS.mouthX, y: BOSS.mouthY };
  const ball = (h) => {                                                  // a ball along a lane, h above the floor
    const o = addObs(run, mouth.x, mouth.y, ACID.ball, ACID.ball, 'acid', false);
    o.ghost = false; o.ball = true; o.lane = GROUND - h - ACID.ball / 2; o.vx = run.speed - ACID.closing;
  };
  const lob = (ahead, T = 0.9) => {                                      // a blob that lands on the path, `ahead` of the hero
    const land = run.cam + run.sx + ahead + run.speed * T, g = 1600;
    const o = addObs(run, mouth.x, mouth.y, ACID.ball, ACID.ball, 'acid', false);
    o.ghost = false; o.lob = true; o.vx = (land - mouth.x) / T; o.vy = (GROUND - ACID.ball - mouth.y - 0.5 * g * T * T) / T; o.g = g;
  };
  b.t += d; b.open = Math.max(0, b.open - d);
  if (b.phase === 'enter') {                                             // it slides in from the right edge
    b.sx += (run.viewW - BOSS.w - b.sx) * Math.min(1, d * 2.5);
    if (b.t > 1.6) { b.phase = 'fight'; b.t = 0; }
    return;
  }
  if (b.phase === 'fight') {
    if (b.wind > 0) {                                                    // its jaws open, acid glows: then it fires
      if ((b.wind -= d) <= 0) {
        b.open = 0.35;
        switch (b.attack) {
          case 'puddle': lob(rnd(380, 640)); run.events.push('spit'); break;
          case 'spray': lob(320); lob(760); run.events.push('spit'); break;          // two puddles, room to land between them
          case 'low': case 'mid': case 'high': case 'vine': ball(LANE[b.attack]); run.events.push('acid'); break;
          case 'pair': ball(LANE.high); ball(pick([LANE.low, LANE.mid])); run.events.push('acid'); break;   // a short jump or staying down gets through
          case 'fan': {                                                  // on the dragonfly: every lane but two neighbours
            const free = Math.floor(Math.random() * 4);
            [70, 180, 290, 400, 510].forEach((h, k) => { if (k !== free && k !== free + 1) ball(h); });
            run.events.push('acid'); break;
          }
          case 'rain':                                                   // drops from the sky, their shadows on the floor first
            for (const ahead of [420, 860]) {
              const x = run.cam + run.sx + ahead + run.speed * 0.9, o = addObs(run, x, -60, ACID.ball, ACID.ball, 'acid', false);
              o.ghost = false; o.drop = true; o.vx = 0; o.vy = 0; o.g = 2 * (GROUND - ACID.ball + 60) / (0.9 * 0.9);
            }
            run.events.push('spit'); break;
          case 'tentacle': {                                             // a tentacle slithering along the floor towards him
            const o = addObs(run, run.cam + b.sx + 40, GROUND - 30, 150, 30, 'acid', false);
            o.ghost = false; o.tentacle = true; o.vx = run.speed - 330; o.ph = rnd(0, 6);
            run.events.push('slither'); break;
          }
        }
      }
    } else if ((b.next -= d) <= 0) {
      // what it throws depends on how he gets about
      const M = run.mount && run.mount.kind;
      const set = M === 'dragonfly' ? ['fan', 'fan', 'rain', 'low', 'high', 'mid']
        : M === 'rhino' ? ['puddle', 'spray', 'low', 'low', 'high', 'rain', 'tentacle']
          : ['puddle', 'spray', 'low', 'low', 'mid', 'high', 'pair', 'rain', 'tentacle', ...(p.hang ? ['vine', 'vine'] : [])];
      b.attack = pick(set);
      b.wind = 0.45; b.next = Math.max(0.7, 1.2 - b.t * 0.025);   // more and more often
    }
    if (b.t > BOSS.fight && b.wind <= 0) {                               // a tree comes down on it
      b.phase = 'fall'; b.t = 0; b.wx = run.cam + b.sx; b.crushed = false;
      // the reward: blue gems all along the path, at running height: nothing to do but run on
      for (let k = 0; k < 16; k++) run.coins.push({ x: run.cam + run.sx + 320 + k * 48, y: GROUND - 40, gem: 'b' });
      run.nextX = Math.max(run.nextX, run.cam + run.viewW + 900);
      run.events.push('timber');
    }
    return;
  }
  // falling: it stays where it stood; the tree lands at 0.9 s and drives it into the ground
  b.sx = b.wx - run.cam;
  if (!b.crushed && b.t >= 0.9) { b.crushed = true; run.shake = 1; run.events.push('bossfall'); }
  if (b.t > 2.6) {                                                       // gone under the ground: the fight is won
    run.boss = null; run.bossDone = true;
    for (let i = 0; i < 24; i++) loot(run, run.cam + run.sx + rnd(40, 400), GROUND - rnd(80, 300));
    for (const g of 'yrb') { loot(run, run.cam + run.sx + rnd(100, 300), GROUND - 200); run.coins[run.coins.length - 1].gem = g; }   // and a gem of each colour
    // and the world moves on, unless the Gros sac à dos muffles the relic (one time in two)
    if (!(run.up.jammer && Math.random() < 0.5)) run.nextBiomeAt = run.dist;
    run.events.push('bossdown');
  }
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
  // What was laid ahead for the ride (towers of crates, creatures up in the
  // sky) may be out of reach on foot: it vanishes in a puff. The coins stay.
  for (const o of run.obs) if (o.ride && !o.gone && o.x + o.w > px) {
    o.gone = true;
    for (let i = 0; i < 8; i++) run.parts.push({ x: o.x + rnd(0, o.w), y: o.y + rnd(0, o.h), vx: rnd(-80, 80), vy: rnd(-160, -20), life: 0, max: rnd(0.3, 0.6), c: pick(['#f4f0e0', '#cfd3e6']), s: rnd(6, 14), g: -60 });
  }
  run.mount = null;
  p.hang = false; p.vineLeap = false; p.jumps = 1;
  p.inv = 1.5; run.shake = 0.5; run.flash = 0.6;
  run.nextMount = Math.max(run.nextMount, run.dist + rnd(900, 1200) / friend(run.up));
  run.events.push('unmount');
}

// Losing a heart leaves a moment of invincibility; the last one ends the run (or triggers the rewind).
// On a mount nothing is lost: the animal vanishes instead.
function hit(run, o) {
  o.gone = true;
  if (run.mount) { dismount(run); return; }
  if (!run.god) run.hearts--;                   // the debug menu's invincibility: the blow is felt, no heart goes
  run.shake = 0.6; run.flash = 1;
  if (run.hearts > 0 || run.god) {
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
  if (!run.fm && run.boss) { run.fmDue = false; run.nextFM = Math.max(run.nextFM, run.dist + 150); return; }
  if (!run.fm) {
    if (run.mount) { run.fmDue = false; run.nextFM = Math.max(run.nextFM, run.dist + 100); return; }   // never on top of a ride
    if (!run.fmDue && run.dist >= run.nextFM) run.fmDue = true;          // from now on only coins are laid ahead
    if (!run.fmDue || px < run.blockEnd + 60) return;                    // waits until the road is clear
    run.fm = { biome: biomeAt(run, px), waves: 1 + (run.dist > 450 && Math.random() < 0.6 ? 1 : 0) + (run.dist > 900 && Math.random() < 0.5 ? 1 : 0), aim: 1.7 };
    wave(run);
  }
  const f = run.fm;
  f.t += d;
  if (f.phase === 'aim') {                                               // they follow the hero from the right edge
    f.sx += (run.viewW - 110 - f.sx) * Math.min(1, d * 5);
    if (f.t >= f.aim) { f.phase = f.biome === 2 ? 'fire' : 'rush'; f.t = 0; run.events.push(f.phase === 'fire' ? 'laser' : 'rush'); }
    return;
  }
  if (f.phase === 'fire') {                                              // the city's drones stay put and fire along their lanes
    if (!f.hit && !f.ghost && f.t > LASER.on && f.t < LASER.off) for (let k = 0; k < FM.lanes; k++) {
      const y0 = GROUND - (k + 0.5) * FM.step - LASER.h / 2;
      if (!f.act[k] || y0 + 4 > box.B || y0 + LASER.h - 4 < box.T) continue;
      if (dashing) break;
      if (p.inv === 0) { f.hit = true; hit(run, {}); if (run.dead || run.leap || !run.fm) return; }
      break;
    }
    if (f.t < LASER.end) return;
    f.sx = -999;                                                         // gone: the wave is over
  } else f.sx += (f.t < 0.14 ? 260 : -FM.rush) * d;                      // a short recoil, then the charge
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
  // The hero's own speed grows for ever; a mount, then the boss, impose theirs while they last.
  const own = run.base + run.t * SPEED.gain, R = run.mount && MOUNTS[run.mount.kind].speed;
  const pace = run.boss ? BOSS.speed : R ? R.base + R.gain * run.mount.t : own;
  // Slowing down is quick; speeding back up (after a mount or the boss) is gradual: RAMP units per
  // second each second, so a big gap takes a few seconds to close.
  run.speed = pace > run.speed ? Math.min(pace, run.speed + RAMP * dt) : run.speed + (pace - run.speed) * Math.min(1, dt * 3);
  run.own = own; run.relic = Math.max(0, run.relic - dt * 0.6);
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
      // the dragonfly: held, it climbs; let go, it sinks. It turns round at once, no run-up either way.
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
        if (p.ground) jump(run, (M ? M.jump : -JUMP.v) * spring);     // on foot, a press is a plain jump
        else if (gorilla && p.jumps < 2) {                         // the gorilla's second jump goes as high as it takes to reach the vines
          jump(run, -Math.sqrt(2 * 2400 * Math.max(80, p.y - HANG_Y + 40))); p.vineLeap = true;
          burst(run, px, p.y, '#ffffff', 8, 160);
        } else if (!M && up.doubleJump && p.jumps < 2) { jump(run, -JUMP.double * spring); burst(run, px, p.y, '#ffffff', 6, 120); p.rotor = !!up.flight; }
        else if (!M && up.flight) {                                // in the air, every press lifts him at once
          p.rotor = true; p.spin = 0.22; p.vy = Math.min(p.vy, -FLAP);
          run.events.push('flap');
        } else p.buf = 0.12;                                       // pressed just before landing: remembered
      }
      if (!input.hold) p.rotor = false;                            // released: he drops straight away
      if (p.ground && p.plat && (px < p.plat.x - HERO_HALF || px > p.plat.x + p.plat.w + HERO_HALF)) {
        p.ground = false; p.plat = null; p.jumps = 1;          // ran off the end of a ledge
      }
      if (p.ground && !p.plat) {                     // on a slope he simply follows it; where the floor gives way, he falls
        if (fl - p.y > 40) { p.ground = false; p.jumps = Math.max(p.jumps, 1); } else p.y = fl;
      }
      if (!p.ground) {
        const before = p.y;
        if (p.rotor) p.vy = Math.min(-FLAP, p.vy + 2400 * d);    // the leaf rotor: a steady climb for as long as it is held
        else p.vy += (input.hold && p.vy < 0 && !p.vineLeap ? JUMP.held : JUMP.gravity) * d;   // holding makes the jump higher
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
          if (p.buf > 0) jump(run, (M ? M.jump : -JUMP.v) * spring);
        }
      } else {
        // strides per second: quicker as he speeds up, but never a blur
        p.phase += (1.75 + (Math.min(900, run.speed) - 360) / 600) * Math.PI * 2 * d * (dashing ? 1.4 : 1);
        if (Math.random() < 0.25) run.parts.push({ x: px - 30, y: p.y - 2, vx: rnd(-90, -30), vy: rnd(-50, -10), life: 0, max: 0.35, c: '#f4f0e0', s: rnd(4, 8), g: 0 });
      }
    }
    if (dashing && Math.random() < 0.8) run.parts.push({ x: px - 20, y: p.y - rnd(5, 75), vx: -300, vy: 0, life: 0, max: 0.25, c: '#ffd35c', s: rnd(4, 8), g: 0 });

    // --- mounts: the ones ahead wait to be touched, and may be missed ---
    if (run.mount) run.mount.t += dt;
    for (const it of run.items) {
      it.x += run.speed * MOUNTS[it.kind].ahead * d;
      const f = floorAt(run, it.x);
      if (it.kind === 'dragonfly') { const k = ((run.t + it.ph) / ZIG.period) % 2; it.y = f - ZIG.low - (ZIG.high - ZIG.low) * (k < 1 ? k : 2 - k); }
      if (run.mount || Math.abs(px - it.x) > 70) continue;
      const reach = it.kind === 'gorilla' ? p.y - HERO_H < f - PERCH + 24              // up to the gorilla: a high jump
        : it.kind === 'rhino' ? p.y > f - 50                                        // the rhino: at its level, not over it
          : Math.abs(p.y - HERO_H / 2 - it.y) < 64;                                 // the dragonfly: where it flies
      if (!reach) continue;
      run.mount = { kind: it.kind, t: 0 };
      it.gone = true; p.rotor = false; p.hang = false; p.vineLeap = false; p.inv = Math.max(p.inv, 0.5);
      if (MOUNTS[it.kind].fly) { p.ground = false; p.plat = null; p.vy = -200; p.y = Math.min(p.y, floorAt(run, it.x) - 60); }
      else if (!p.ground) { p.vy = Math.max(p.vy, 0); p.jumps = 1; }      // caught in the air: they come down together
      burst(run, it.x, p.y - 70, '#ffd35c', 16, 260);
      run.events.push('mount');
    }

    run.h = Math.max(0, (floorAt(run, px) - p.y) / PPM); run.maxH = Math.max(run.maxH, run.h);

    // --- obstacles ---
    const box = { L: px - half, R: px + half, T: p.y - tall + 6, B: p.y - 2 };
    for (const o of run.obs) {
      if (p.ball) break;                           // nothing reaches him in there
      if (o.kind === 'dart') {                     // waiting beyond the edge, then the warning, then across in one go
        if (o.state === 'wait' && o.x <= run.cam + run.viewW + 40) { o.state = 'warn'; o.t = 0; run.events.push('warn'); }
        if (o.state === 'warn') { o.x = run.cam + run.viewW + 60; if ((o.t += d) >= DART.warn) { o.state = 'go'; run.events.push('dart'); } }
        if (o.state === 'go') o.x -= DART.speed * d;
      }
      if (o.kind === 'acid') {
        o.x += o.vx * d;
        if (o.lob) {                                 // a blob in the air: where it lands, a puddle of acid stays
          o.vy += o.g * d; o.y += o.vy * d;
          const f = floorAt(run, o.x + o.w / 2);
          if (o.y + o.h >= f) {
            o.lob = false; o.vx = 0; o.x -= (ACID.puddle - o.w) / 2; o.w = ACID.puddle; o.h = 22; o.y = f - o.h; o.puddle = true;
            for (let i = 0; i < 10; i++) run.parts.push({ x: o.x + rnd(10, o.w - 10), y: f - 6, vx: rnd(-160, 160), vy: rnd(-320, -80), life: 0, max: rnd(0.3, 0.6), c: pick(['#a8ff3c', '#5cf25c', '#e8ffb0']), s: rnd(5, 10), g: 1200 });
            run.events.push('splash');
          }
        } else if (o.ball) o.y += (o.lane - o.y) * Math.min(1, d * 4);
        else if (o.drop) {                           // a drop from the sky: a small puddle where it lands
          o.vy += o.g * d; o.y += o.vy * d;
          const f = floorAt(run, o.x + o.w / 2);
          if (o.y + o.h >= f) { o.drop = false; o.x -= 27; o.w = 90; o.h = 22; o.y = f - o.h; o.puddle = true; run.events.push('splash'); }
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
    if (!run.leap) boss(run, d);
    // fallen into a hole: a heart goes, and he is put back on the far side
    if (p.y > GROUND + 150) {
      const pit = run.pits.find((h) => px > h.x0 - 60 && px < h.x1 + 60);
      if (pit) { run.cam = pit.x1 + 40 - run.sx; p.y = GROUND; p.vy = 0; p.ground = true; p.jumps = 0; p.inv = 0; }
      else p.y = floorAt(run, run.cam + run.sx);
      p.inv = 0; hit(run, {}); if (run.god) p.inv = 0.5;
      if (run.dead) return;
    }
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
    run.nextBiomeAt = Infinity;                                        // until the next boss
    run.relic = 1; run.glitch = Math.max(run.glitch, 0.5);             // the relic flares: it is what moves the world
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
