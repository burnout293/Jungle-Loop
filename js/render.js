// Everything drawn on the canvas, from the pixel-art assets in assets/img.
// Every coordinate here is in art pixels: logical units from game.js divided by PIXEL. The canvas
// holds Q x Q real pixels for each art pixel (see setQuality): sprites keep their sharp squares,
// but they can stand and scroll at any Q-th of a pixel, which is what keeps a fast run steady,
// and the browser smooths the picture's edges when it fits the canvas to the screen.

import { GROUND, PIXEL, VIEW_H, PROP, PROP_CELL as CELL_UNITS, FM, LASER, MOUNTS, LOG, GALLERY, PERCH, BOSS, DECOR_W, propAt, floorAt, flatAt, biomeAt } from './game.js';
import { drawSky, drawLife, drawWeather, swayBlit, setStep } from './ambient.js';

// Each scenery has its own far background, middle distance, floor, props, and its own version of
// everything that is built in it: ledge, pillar, crate, bridge slab and hollow pipe (the jungle's
// is a tree trunk). `shade` is the colour of the leaves along the frame's edges there (null: the
// jungle's own leaves); `hollow` the colours inside a pipe: rim, far wall, floor, shade under the roof.
const built = (id, platTop, slabTop, hollow) => ({ platform: id + '-platform', pillar: id + '-pillar', crate: id + '-crate', slab: id + '-slab', tunnel: id + '-tunnel', platTop, slabTop, hollow });
export const BIOMES = [
  { id: 'jungle', name: 'Jungle mystique', bg: 'bg-far', mid: 'mid', grounds: ['ground-0', 'ground-1', 'ground-2'], prop: 'prop-', props: 9, shade: null,
    platform: 'platform', pillar: 'pillar', crate: 'crate', slab: 'slab', tunnel: 'log', platTop: 13, slabTop: 5, hollow: ['#3b2014', '#24120f', '#4d2d1a', '#160b0c'] },
  { id: 'ruins', name: 'Ruines oubliées', bg: 'ruins-bg', mid: 'ruins-mid', grounds: ['ruins-ground'], prop: 'ruins-prop-', props: 4, shade: '#3b2331',
    ...built('ruins', 2, 5, ['#6b3a22', '#2c1611', '#8a5632', '#1c0e0b']) },
  { id: 'city', name: 'Cité du futur', bg: 'city-bg', mid: 'city-mid', grounds: ['city-ground'], prop: 'city-prop-', props: 4, shade: '#120c2c',
    ...built('city', 2, 2, ['#2c2152', '#0f0a22', '#3fd9e6', '#080514']) },
  { id: 'dungeon', name: 'Donjon sans fin', bg: 'dungeon-bg', mid: 'dungeon-mid', grounds: ['dungeon-ground'], prop: 'dungeon-prop-', props: 4, shade: '#0b0b1c',
    ...built('dungeon', 2, 2, ['#4a3026', '#140d0d', '#5c4636', '#0a0707']) },
];

const DIR = new URL('../assets/img/', import.meta.url).href;   // from this file: pages in mockups/ load the same pictures
const NAMES = ['fore', 'temple', 'temple-rubble', 'vorace-legs', 'vorace-head', 'vorace-body', 'vorace-log', 'crate-big', 'spikebot', 'spider-low', 'spider-mid', 'bat', 'thornball', 'beartrap', 'vulture', 'arrow', 'missile', 'idol', 'drone', 'wasp', 'drone-big', 'hero-body', 'hero-ball', 'hero-rotor', 'hero-fist', 'hero-shoe', 'mount-gorilla', 'mount-gorilla-hang', 'mount-rhino', 'mount-dragonfly', 'mosquito', 'fly', 'spiky', 'coin', 'gem', 'gem-y', 'gem-r', 'gem-b', 'heart', 'monkey'];
const IMG = {};
let meta = {
  fly: { frames: 1 }, coin: { frames: 1 }, mosquito: { frames: 4 },
  rig: { body: { w: 39, h: 40, hx: 30, hy: 24, tx: 26 }, rotor: { w: 58, h: 34, hx: 28, hy: 16, tx: 29, blade: 12 }, fist: { w: 8, h: 8 }, shoe: { w: 12, h: 9 } },
  mounts: { gorilla: { frames: 4, seatX: 41, seatY: 21 }, rhino: { frames: 4, seatX: 41, seatY: 20 }, dragonfly: { frames: 4, seatX: 40, seatY: 30 },
    'gorilla-hang': { frames: 4, seatX: 46, seats: [[28, 54], [32, 59], [33, 56], [32, 52]] } },
};
let SCENE = [];                                        // per scenery, what is ready to draw (see buildScene)
let HAZ = {};                                          // what hurts, outlined so it stands out, and its harmless ghost
let FAR = {};                                          // the hero's far fist and shoe, in the shade of his body
let DECOR = [];                                        // per scenery, the picture of what can be smashed
let ready = false;
let scratch = null;                                    // spare canvas: one scenery is faded in over another on it

// Drawing steps per art pixel. 1 is the plain pixel-art canvas; main.js raises it to match the screen.
let Q = 1;
export function setQuality(q) { Q = q; scratch = null; setStep(q); }
export const quality = () => Q;
const snap = (v) => Math.round(v * Q) / Q;             // to the nearest spot the canvas can show
const n = (v) => Math.round(v / PIXEL * Q) / Q;        // the same, from game units

// A picture handed to the graphics chip once and for all: decoded now rather than in the middle of
// a run, and never uploaded again. Works on images and on the canvases made from them.
// (They used to be turned into ImageBitmaps here. On some phones' chips the large ones came out as
// noise, so images and canvases are now drawn as they are; an image is only decoded ahead of time.)
// decode() can wait for as long as the page is hidden (a phone locked while the game loads): never more
// than a second here, the picture is drawn anyway.
const baked = async (im) => {
  try { if (im && im.decode) await Promise.race([im.decode(), new Promise((ok) => setTimeout(ok, 1000))]); } catch { /* drawn anyway */ }
  return im;
};

function load(name) {
  return new Promise((done) => {
    const im = new Image();
    im.onload = async () => { IMG[name] = await baked(im); done(); };
    im.onerror = done;                                 // a missing image is skipped, not fatal
    im.src = DIR + name + '.png';
  });
}

export async function loadAssets() {
  try { meta = { ...meta, ...(await (await fetch(DIR + 'meta.json', { cache: 'no-cache' })).json()) }; } catch { /* defaults */ }
  const names = [...NAMES];
  for (const b of BIOMES) {
    names.push(b.bg, b.mid, ...b.grounds, b.platform, b.pillar, b.crate, b.slab, b.tunnel);
    for (let i = 0; i < b.props; i++) names.push(b.prop + i);
  }
  await Promise.all(names.map(load));
  SCENE = BIOMES.map(buildScene);
  buildHaz();
  // the forest's big crate, the ruins' jar, the city's crates, the dungeon's barrel
  DECOR = [IMG['crate-big'], IMG['ruins-prop-1'], IMG['city-prop-3'], IMG['dungeon-prop-1']];
  FAR = { fist: tinted(IMG['hero-fist'], 'rgba(16,12,40,.38)'), shoe: tinted(IMG['hero-shoe'], 'rgba(16,12,40,.38)') };
  // the hero's pieces, redrawn four times finer with their stair-steps rounded off (see rounded)
  for (const k of ['hero-body', 'hero-rotor', 'hero-fist', 'hero-shoe', 'hero-ball']) if (IMG[k]) HI.set(IMG[k], rounded(rounded(IMG[k])));
  for (const k of ['fist', 'shoe']) HI.set(FAR[k], tinted(HI.get(IMG['hero-' + k]), 'rgba(16,12,40,.38)'));
  // everything made above is a canvas: turned into ready pictures too
  const jobs = [];
  const bake = (o, k) => jobs.push(baked(o[k]).then((b) => { o[k] = b; }));
  for (const S of SCENE) {
    for (const k of ['pillar', 'fore', 'tunnel']) bake(S, k);
    S.props.forEach((_, i) => bake(S.props, i));
    for (const g of S.ground.pieces) bake(g, 'im');
  }
  for (const H of Object.values(HAZ)) { bake(H, 'im'); bake(H, 'ghost'); }
  bake(FAR, 'fist'); bake(FAR, 'shoe');
  await Promise.all(jobs);
  ready = true;
}

// Deterministic pseudo-random in [0,1): the same index always gives the same result.
const h01 = (i, s) => { const x = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); };

function canvasOf(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }

// A drawing twice as fine, its diagonals smoothed the way pixel artists do it by hand (the "Scale2x"
// rule): a pixel's corner takes the colour of its two neighbours on that side when they agree and the
// opposite ones do not. No new colour appears, nothing gets blurry; done twice, a staircase of 1-pixel
// steps becomes a slope of quarter steps. HI keeps these finer versions; put() draws them at the
// original's size, so the rest of the code never sees the difference.
const HI = new Map(), HI_K = 4;
function rounded(im) {
  const w = im.width, h = im.height, src = canvasOf(w, h), sx = src.getContext('2d');
  sx.drawImage(im, 0, 0);
  const s = new Uint32Array(sx.getImageData(0, 0, w, h).data.buffer), out = canvasOf(w * 2, h * 2), ox = out.getContext('2d');
  const img = ox.createImageData(w * 2, h * 2), d = new Uint32Array(img.data.buffer);
  const at = (x, y) => { if (x < 0 || y < 0 || x >= w || y >= h) return 0; const v = s[y * w + x]; return v >>> 24 < 128 ? 0 : v; };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const P = at(x, y), A = at(x, y - 1), B = at(x + 1, y), C = at(x - 1, y), D = at(x, y + 1), i = (y * 2) * (w * 2) + x * 2;
    d[i] = C === A && C !== D && A !== B ? A : P;
    d[i + 1] = A === B && A !== C && B !== D ? B : P;
    d[i + w * 2] = D === C && D !== B && C !== A ? C : P;
    d[i + w * 2 + 1] = B === D && B !== A && D !== C ? D : P;
  }
  ox.putImageData(img, 0, 0);
  return out;
}
// drawImage, for images that may have a finer version: same arguments, in the original's own pixels.
function put(ctx, im, a, b, c, d, e, f, g, h) {
  const hi = HI.get(im), k = hi ? HI_K : 1;
  if (c === undefined) ctx.drawImage(hi || im, a, b, im.width, im.height);
  else ctx.drawImage(hi || im, a * k, b * k, c * k, d * k, e, f, g, h);
}
function mirrored(im) {
  const c = canvasOf(im.width, im.height), x = c.getContext('2d');
  x.translate(im.width, 0); x.scale(-1, 1); x.drawImage(im, 0, 0);
  return c;
}
// A copy of an image with a veil of colour over its own pixels. A dark veil pushes scenery back
// (see buildScene), a pale one makes the ghost of a creature.
function tinted(im, colour) {
  if (!im) return im;
  const c = canvasOf(im.width, im.height), x = c.getContext('2d');
  x.drawImage(im, 0, 0); x.globalCompositeOperation = 'source-atop'; x.fillStyle = colour; x.fillRect(0, 0, c.width, c.height);
  return c;
}
// A copy of a sprite sheet with a pale line all around each frame (frames become 2 pixels larger):
// what can hurt is told from the scenery at a glance, even at full speed.
function rim(im, frames = 1, colour = '#fff2c8') {
  if (!im) return im;
  const fw = im.width / frames, c = canvasOf((fw + 2) * frames, im.height + 2), x = c.getContext('2d');
  const one = canvasOf(fw + 2, im.height + 2), o = one.getContext('2d');
  for (let f = 0; f < frames; f++) {
    o.globalCompositeOperation = 'source-over'; o.clearRect(0, 0, one.width, one.height);
    for (const [dx, dy] of [[0, 1], [2, 1], [1, 0], [1, 2]]) o.drawImage(im, f * fw, 0, fw, im.height, dx, dy, fw, im.height);
    o.globalCompositeOperation = 'source-in'; o.fillStyle = colour; o.fillRect(0, 0, one.width, one.height);
    o.globalCompositeOperation = 'source-over'; o.drawImage(im, f * fw, 0, fw, im.height, 1, 1, fw, im.height);
    x.drawImage(one, f * (fw + 2), 0);
  }
  return c;
}
// The first row of an image that is solid nearly all the way across: where a floor piece really begins,
// under whatever grass or rubble sticks out of it.
function surface(im) {
  if (!im) return 3;
  const c = canvasOf(im.width, 16).getContext('2d'); c.drawImage(im, 0, 0);
  const d = c.getImageData(0, 0, im.width, 16).data;
  for (let y = 0; y < 16; y++) { let n = 0; for (let x = 0; x < im.width; x++) if (d[(y * im.width + x) * 4 + 3] > 128) n++; if (n > im.width * 0.8) return y; }
  return 3;
}
// The colour of the first solid pixel found on a row of an image (row < 0 counts from the bottom).
function rowColour(im, row, fallback) {
  if (!im) return fallback;
  const c = canvasOf(im.width, 1).getContext('2d');
  c.drawImage(im, 0, row < 0 ? im.height + row : row, im.width, 1, 0, 0, im.width, 1);
  const d = c.getImageData(0, 0, im.width, 1).data;
  for (let x = im.width >> 1; x < im.width; x++) if (d[x * 4 + 3] > 200) return `rgb(${d[x * 4]},${d[x * 4 + 1]},${d[x * 4 + 2]})`;
  return fallback;
}

const DIM = 'rgba(16,12,40,.38)';                      // the veil over scenery that stands where obstacles do

// Each role of danger looks different in each scenery (jungle, ruins, city, dungeon: the order of
// BIOMES). The hanging one of the jungle is a spider, yellow when low, red at head height.
const ROLE = {
  spiky: ['spiky', 'thornball', 'spikebot', 'beartrap'],
  dart: ['fly', 'vulture', 'missile', 'arrow'],
  hover: ['spider', 'idol', 'drone', 'bat'],
  swarm: ['mosquito', 'wasp', 'drone-big', 'wisp'],
};
const HAZ_FRAMES = { spiky: 1, thornball: 1, beartrap: 2, spikebot: 1, fly: 4, vulture: 2, arrow: 1, missile: 1, 'spider-low': 2, 'spider-mid': 2, idol: 1, bat: 3, drone: 1, mosquito: 4, wasp: 1, 'drone-big': 1 };
const RED = '#ff3b4e';
let RIM = false;                                       // the red outline around everything that hurts (a setting)
// Ways of making the dangers stand out from the scenery, shown side by side in mockups/lisibilite.html:
// 0 as it is; 1 a thick dark outline; 2 a lit edge (light from the top left) inside a dark outline;
// 3 a warm glow behind; 4 the scenery much darker; 5 = 2 + 4, the one chosen for the game (16/11).
let LOOK = 5;
export const LOOKS = 6;
export function setLook(n) { LOOK = n; if (ready) { SCENE = BIOMES.map(buildScene); buildHaz(); } }
const DARK = '#0d0614';
// A sprite sheet with its top-left edges lit and a dark outline round it (frames 2 pixels larger).
function litEdge(im, frames) {
  const out = rim(im, frames, DARK), fw = im.width / frames, x = out.getContext('2d');
  const e = canvasOf(im.width, im.height), ex = e.getContext('2d');
  ex.drawImage(im, 0, 0); ex.globalCompositeOperation = 'destination-out'; ex.drawImage(im, 1, 1);
  ex.globalCompositeOperation = 'source-in'; ex.fillStyle = 'rgba(255,246,216,.9)'; ex.fillRect(0, 0, e.width, e.height);
  for (let f = 0; f < frames; f++) x.drawImage(e, f * fw, 0, fw, im.height, f * (fw + 2) + 1, 1, fw, im.height);
  return out;
}
// The dangers as drawn: plain, or outlined in red (then one pixel larger all round: `pad`). Their
// harmless ghost (Faune alcoolisée) always keeps its pale outline.
function buildHaz() {
  for (const [k, n0] of Object.entries(HAZ_FRAMES)) {
    const frames = k === 'fly' ? meta.fly.frames : k === 'mosquito' ? meta.mosquito.frames : n0;
    if (!IMG[k]) continue;
    let im = IMG[k], pad = 0;
    if (LOOK === 1) { im = rim(rim(im, frames, DARK), frames, DARK); pad = 2; }
    else if (LOOK === 2 || LOOK === 5) { im = litEdge(im, frames); pad = 1; }
    if (RIM) { im = rim(im, frames, RED); pad++; }
    HAZ[k] = { im, ghost: rim(tinted(IMG[k], 'rgba(110,215,255,.55)'), frames, '#d8f6ff'), frames, pad };
  }
  for (const S of SCENE) S.stacks = [];
}
export function setDangerRim(on) { RIM = !!on; if (ready) buildHaz(); }

// The far scenery pushed back: less colour, a little darker, so that what is in play stands out.
function recede(im, grey, dark) {
  if (!im) return im;
  const c = canvasOf(im.width, im.height), x = c.getContext('2d');
  x.drawImage(im, 0, 0);
  const d = x.getImageData(0, 0, c.width, c.height), a = d.data;
  for (let i = 0; i < a.length; i += 4) {
    const l = 0.3 * a[i] + 0.59 * a[i + 1] + 0.11 * a[i + 2];
    for (let k = 0; k < 3; k++) a[i + k] = (a[i + k] + (l - a[i + k]) * grey) * dark;
  }
  x.putImageData(d, 0, 0);
  return c;
}

// The same the other way: `cut` rows taken out around row `at`, top and bottom whole.
const LOG_CUT = 12;
function lowered(im, cut, at) {
  if (!im) return im;
  const c = canvasOf(im.width, im.height - cut), x = c.getContext('2d'), a = at - (cut >> 1);
  x.drawImage(im, 0, 0, im.width, a, 0, 0, im.width, a);
  x.drawImage(im, 0, a + cut, im.width, im.height - a - cut, 0, a, im.width, im.height - a - cut);
  return c;
}
// A long drawing made shorter by taking out its middle: both ends stay whole.
function shortened(im, w) {
  if (!im || im.width <= w) return im;
  const c = canvasOf(w, im.height), x = c.getContext('2d'), half = w >> 1;
  x.drawImage(im, 0, 0, half, im.height, 0, 0, half, im.height);
  x.drawImage(im, im.width - (w - half), 0, w - half, im.height, half, 0, w - half, im.height);
  return c;
}

function buildScene(b) {
  // The floor is a long fixed sequence of the ground pieces, some mirrored, repeated only every few
  // thousand pixels: far too long for the eye to catch the pattern at running speed.
  const kinds = b.grounds.map((g) => IMG[g]).filter(Boolean), pieces = [];
  let len = 0, last = -1;
  for (let i = 0; i < 24 && kinds.length; i++) {
    let k = Math.floor(h01(i, 5) * kinds.length);
    if (k === last && kinds.length > 1) k = (k + 1) % kinds.length;
    last = k;
    // a single strip is mirrored every other time (its ends then always match); ragged pieces overlap a little
    const flip = kinds.length > 1 ? h01(i, 9) > 0.5 : i & 1;
    pieces.push({ im: flip ? mirrored(kinds[k]) : kinds[k], x: len });
    len += kinds[k].width - (kinds.length > 1 ? 3 : 0);
  }
  const fore = silhouettes(b.shade || '#16224a');
  // Props and pillars stand on the path, right where crates and creatures do, but are only there to
  // be looked at: they are darkened a little so the eye does not take them for something to dodge.
  const props = [];
  const veil = LOOK >= 4 ? 'rgba(10,8,30,.55)' : DIM;
  for (let i = 0; i < b.props; i++) props.push(tinted(IMG[b.prop + i], veil));
  return {
    platform: IMG[b.platform], pillar: tinted(IMG[b.pillar], DIM), crate: IMG[b.crate], stacks: [], slab: IMG[b.slab], tunnel: tinted(lowered(shortened(IMG[b.tunnel], Math.round(LOG.w / PIXEL)), LOG_CUT, 49), DIM),
    platTop: b.platTop, slabTop: b.slabTop, hollow: b.hollow,
    // `top`: how far above the floor line a piece is drawn, so that its solid surface is what feet stand on
    bg: recede(IMG[b.bg], LOOK >= 4 ? 0.6 : 0.35, LOOK >= 4 ? 0.58 : 0.82), mid: recede(IMG[b.mid], LOOK >= 4 ? 0.55 : 0.3, LOOK >= 4 ? 0.62 : 0.86), ground: { pieces, len, soil: rowColour(kinds[0], -2, '#2a1c2c'), top: kinds.length > 1 ? 4 : surface(kinds[0]) + 1 }, props, fore,
    sky: rowColour(IMG[b.bg], 0, '#7fb9ec'), base: rowColour(IMG[b.mid], -1, '#1c2c3a'),
  };
}

// ---------- Vorace ----------
// The queen flower in three layers cut from one picture (tools/import_vorace.py), drawn back to front:
// legs, head, body. Each layer is a sheet of poses, all in the frame of that one picture, so a pose
// never shifts its part: the body's leaf collar covers the stem and its belly covers the top of the
// legs, and nothing can show between the parts whatever they do.
// Legs: four steps of a walk, then collapsed. Head: shut, opening, open (acid boiling), spitting,
// crushed by the trunk, broken. Body: whole, then cracked. She stands behind the floor: her feet sink
// into it a little. Her end: a trunk drops flat onto her crown (0.9 s), the urn cracks, the legs give
// way and she slumps onto them, then everything goes down behind the floor, the trunk with her.
let dirt = [], dirtT = 0;
const VORACE_SINK = 4;                                   // how far her feet go into the floor (pixels)
export function voraceFrame(run, t) {                    // which pose of each layer, and the body's offsets
  const b = run.boss, fall = b.phase === 'fall', bt = b.t;
  const step = Math.floor(t * 7) % 4;
  const L = fall && bt >= 1.15 ? 4 : step;
  const H = fall ? (bt < 0.9 ? 1 : bt < 1.5 ? 4 : 5)
    : b.open > 0 ? 3 : b.wind > 0 ? (b.wind > 0.22 ? 1 : 2) : 0;
  const B = fall && bt >= 1.0 ? 1 : 0;
  // a step lifts her a pixel; when the legs give way she slumps onto them as far as their stump went down
  const drop = (meta.vorace && meta.vorace.legs.drop[4]) || 40;
  const bob = fall ? (bt >= 1.15 ? Math.round(drop * Math.min(1, (bt - 1.15) / 0.22) ** 2) : 0) : (step % 2 ? -1 : 0);
  const breathe = !fall && H === 0 ? Math.round(Math.sin(t * 2.4)) : 0;  // her head rising and falling while she waits
  const lunge = H === 3 ? -2 : 0;                                         // the spit throws her head a little further
  const sink = fall && bt > 1.6 ? (bt - 1.6) ** 2 * 320 : 0;
  return { L, H, B, step, bob, breathe, lunge, sink };
}
function drawVorace(ctx, run, t) {
  const b = run.boss, V = meta.vorace, legs = IMG['vorace-legs'], head = IMG['vorace-head'], body = IMG['vorace-body'];
  if (!V || !legs || !head || !body) return;
  const f = voraceFrame(run, t), fall = b.phase === 'fall';
  const left = snap(n(b.sx)), top = Math.round(GN + VORACE_SINK - V.ground + f.sink);
  const layer = (im, P, frame, dx, dy) => ctx.drawImage(im, frame * P.w, 0, P.w, P.h, left + P.x + dx, top + P.y + dy, P.w, P.h);
  if (!fall && b.lastStep !== f.step && (f.step === 0 || f.step === 2)) {          // a foot comes down: earth flies
    for (const fx of V.feet[f.step === 0 ? 0 : 1]) for (let q = 0; q < 4; q++) dirt.push({ x: left + fx + Math.random() * 8 - 4 + n(run.cam), y: GN - 2, vx: (Math.random() - 0.5) * 60, vy: -40 - Math.random() * 60, life: 0.5 });
  }
  b.lastStep = f.step;
  layer(legs, V.legs, f.L, 0, f.L === 4 ? 0 : Math.max(0, f.bob));
  if (b.wind > 0 || b.open > 0) {                    // the acid glowing in its throat: something is coming
    const mx = left + V.mouth[0] + f.lunge, my = top + V.mouth[1] + f.bob, r = 30 + (b.open > 0 ? 10 : 0), g = ctx.createRadialGradient(mx, my, 2, mx, my, r);
    g.addColorStop(0, `rgba(168,255,60,${0.5 + 0.3 * Math.sin(t * 30)})`); g.addColorStop(1, 'rgba(168,255,60,0)');
    ctx.fillStyle = g; ctx.fillRect(mx - r, my - r, r * 2, r * 2);
  }
  layer(head, V.head, f.H, f.lunge, f.bob + f.breathe);
  layer(body, V.body, f.B, 0, f.bob);
  const log = IMG['vorace-log'];
  if (fall && log) {                                    // the trunk drops flat onto the crown, then goes down with her
    const rest = f.H === 5 ? V.body.y + 6 : V.head.tops[f.H] + 4;          // on the crushed head, then on the collar
    const land = top + rest + f.bob, k = Math.min(1, (b.t / 0.9) ** 2);
    const y = Math.round(-log.height + (land + log.height) * k) - log.height;  // its underside comes down from above the screen
    ctx.drawImage(log, left + V.crown[0] - (log.width >> 1), b.t >= 0.9 ? land - log.height : y);
  }
}
// The earth thrown up by Vorace's legs: in front of the floor.
function drawDirt(ctx, cam, t) {
  const dt = Math.min(0.05, Math.max(0, t - dirtT)); dirtT = t;
  for (const d of dirt) { d.life -= dt; d.vy += 300 * dt; d.x += d.vx * dt; d.y += d.vy * dt; }
  dirt = dirt.filter((d) => d.life > 0);
  for (const d of dirt) { ctx.fillStyle = d.life > 0.25 ? '#5a3a24' : '#7a5236'; ctx.fillRect(snap(d.x - cam), snap(d.y), 2, 2); }
}

// The warning of a flyer about to cross: a red "!" at the right edge, blinking, an arrow pointing in.
function warnMark(ctx, x, y, t) {
  if (Math.floor(t * 8) % 2) return;
  ctx.fillStyle = '#1a1024'; ctx.fillRect(x - 5, y - 10, 11, 21);
  ctx.fillStyle = RED; ctx.fillRect(x - 4, y - 9, 9, 19);
  ctx.fillStyle = '#ffffff'; ctx.fillRect(x - 1, y - 7, 3, 9); ctx.fillRect(x - 1, y + 4, 3, 3);
  chevronLeft(ctx, x - 9, y);
}
function chevronLeft(ctx, x, y) {
  for (const [c, g] of [['#1a1024', 1], [RED, 0]]) { ctx.fillStyle = c; for (let k = 0; k < 4; k++) ctx.fillRect(x + k - g, y - k - g, 1 + 2 * g, 2 * k + 1 + 2 * g); }
}

// A pile of `count` crates as one outlined picture, made the first time it is needed.
function stack(S, count) {
  if (!S.stacks[count]) {
    const im = S.crate, c = canvasOf(im.width, count * (im.height - 1) + 1), x = c.getContext('2d');
    for (let k = 0; k < count; k++) x.drawImage(im, 0, k * (im.height - 1));
    S.stacks[count] = RIM ? rim(c, 1, RED) : c;
  }
  return S.stacks[count];
}

function blit(ctx, im, x, y, flip) {
  if (flip) { ctx.save(); ctx.translate(x + im.width, y); ctx.scale(-1, 1); ctx.drawImage(im, 0, 0); ctx.restore(); }
  else ctx.drawImage(im, x, y);
}

// An endless strip made of one image: every other copy is mirrored, so the joins never show.
function strip(ctx, im, offset, y, width) {
  const w = im.width, first = Math.floor(offset / w);
  for (let i = first; i * w - offset < width; i++) blit(ctx, im, snap(i * w - offset), y, i & 1);
}

const VH = Math.round(VIEW_H / PIXEL);                 // play area height, in art pixels
const GN = Math.round(GROUND / PIXEL);                 // floor line where the path is at its starting level
const TEMPLE_X = -64, DOOR_X = 29;                     // temple's left edge and doorway, at camera 0
const PROP_CELL = CELL_UNITS / PIXEL;                  // one possible prop per cell, see propAt in game.js
const EARTH = 24;                                      // rows of a ground piece reused as plain earth below it
const SLICE = 4;                                       // the floor is drawn in columns this wide, each at its own height

// The floor follows the path's relief: every column of every piece sits at the height floorAt gives,
// with plain earth underneath down to the bottom of the picture. Only x0..x1 is drawn.
function drawGround(ctx, run, G, cam, x0, x1, bottom) {
  if (!G.len || x1 <= x0) return;
  ctx.save(); ctx.beginPath(); ctx.rect(x0, -400, x1 - x0, 1200); ctx.clip();
  ctx.fillStyle = G.soil;
  const start = ((cam % G.len) + G.len) % G.len;
  for (let base = -start; base < x1; base += G.len)
    for (const g of G.pieces) {
      const px = snap(base + g.x), w = g.im.width, h = g.im.height;
      if (px >= x1 || px + w <= x0) continue;
      // Columns standing at the same height are drawn as one block: on the flat, which is nearly
      // everywhere, a whole piece goes down in a single call instead of one per column.
      let a = Math.max(0, Math.floor((x0 - px) / SLICE) * SLICE), ya = null;
      for (let k = a; ; k += SLICE) {
        const out = k >= w || px + k >= x1;
        const y = out ? null : n(floorAt(run, (cam + px + k + Math.min(SLICE, w - k) / 2) * PIXEL)) - G.top;
        if (y === ya && !out) continue;
        if (ya !== null) {
          const cw = Math.min(k, w) - a, x = px + a;
          ctx.drawImage(g.im, a, 0, cw, h, x, ya, cw, h);
          // under a raised stretch: the earth of the piece's lower half again, as often as needed
          for (let yy = ya + h - 1; yy < VH; yy += EARTH) ctx.drawImage(g.im, a, h - EARTH - 2, cw, EARTH, x, yy, cw, EARTH);
          if (ya + h < bottom && ya + h >= VH) ctx.fillRect(x, ya + h, cw, bottom - ya - h);
        }
        if (out) break;
        a = k; ya = y;
      }
    }
  ctx.restore();
}

// Scenery props stand on the floor behind the action. Which one stands where comes from the
// cell number alone, so the same stretch always looks the same within a run.
const SWAYING = [PROP.FERN, PROP.FLOWER];              // jungle props that bend in the wind

const SMASH = [-1, 1, 3, 1];                          // in each scenery, the prop that is now the one to smash (never mere scenery)
function drawProps(ctx, run, cam, width, t) {
  const first = Math.floor(cam / PROP_CELL) - 1, last = Math.floor((cam + width) / PROP_CELL) + 1;
  for (let i = first; i <= last; i++) {
    const pr = propAt(i);
    if (!pr || !flatAt(run, pr.x, CELL_UNITS * 0.6)) continue;        // nothing grows on a slope
    const biome = biomeAt(run, pr.x), set = SCENE[biome].props, im = set[pr.kind % set.length];
    if (!im || pr.kind % set.length === SMASH[biome]) continue;
    if (run.boss && meta.vorace) { const bx = n(run.boss.sx), px = pr.x / PIXEL - cam; if (px + im.width > bx && px < bx + meta.vorace.w) continue; }   // nothing stands in front of Vorace
    const x = snap(pr.x / PIXEL - cam), y = n(floorAt(run, pr.x)) - im.height + 3;
    if (biome) { blit(ctx, im, x, y, pr.flip); continue; }
    // brushed by the hero a moment ago: it shakes hard, then settles
    const since = run.touched.has(i) ? run.t - run.touched.get(i) : 9, shiver = since < 1 ? 1 - since : 0;
    if (shiver && pr.kind !== PROP.LANTERN) swayBlit(ctx, im, x, y, pr.flip, t * 7, i, 5 * shiver);   // a lantern lights up, it does not shake
    else if (SWAYING.includes(pr.kind)) swayBlit(ctx, im, x, y, pr.flip, t, i, 2);
    else blit(ctx, im, x, y, pr.flip);
    if (pr.kind === PROP.LANTERN || (pr.kind === PROP.SHROOM && shiver)) {   // the flame breathes, the caps light up
      ctx.globalAlpha = pr.kind === PROP.SHROOM ? 0.35 * shiver : 0.16 + 0.12 * Math.sin(t * 5 + i) ** 2 + 0.3 * shiver;
      ctx.fillStyle = '#7dfff0';
      ctx.fillRect(x + (im.width >> 1) - 12, y + im.height - (pr.kind === PROP.SHROOM ? 66 : 34), 24, pr.kind === PROP.SHROOM ? 40 : 20);
      ctx.globalAlpha = 1;
    }
  }
}

// What is left of the doorway once it has blown out: a ragged hole and rubble on the steps.
function drawBlast(ctx, x) {
  ctx.fillStyle = '#0d0a18';
  ctx.fillRect(x + 84, GN - 100, 42, 84); ctx.fillRect(x + 80, GN - 88, 4, 60); ctx.fillRect(x + 126, GN - 92, 5, 66);
  ctx.fillRect(x + 90, GN - 106, 28, 6); ctx.fillRect(x + 76, GN - 60, 4, 22); ctx.fillRect(x + 131, GN - 70, 3, 30);
  for (const [dx, dy, w, h, c] of [[70, 14, 12, 8, '#6a6f8c'], [96, 10, 9, 7, '#8a8fa8'], [118, 15, 14, 9, '#4a4f6c'], [140, 8, 8, 6, '#6a6f8c'], [154, 12, 11, 8, '#8a8fa8'], [108, 20, 7, 5, '#7bd13c']]) {
    ctx.fillStyle = '#1a1024'; ctx.fillRect(x + dx - 1, GN - dy - 1, w + 2, h + 2);
    ctx.fillStyle = c; ctx.fillRect(x + dx, GN - dy, w, h);
  }
}

// What passes in front of the picture, along its bottom and top edges: plain shadows that never move
// on their own, in two depths (a bluish row behind, a black one in front that scrolls faster). Each
// edge only shows what belongs there: plants growing up from the bottom, foliage and creepers hanging
// from the top. They stay low: `peak` is the most a row may reach into the picture.
const FORE_W = 640;
function lowRow(colour, seed, count, scale, peak) {
  const c = canvasOf(FORE_W, peak), x = c.getContext('2d'), plants = [3, 4, 5, 3].map((k) => IMG['prop-' + k]).filter(Boolean);
  for (let i = 0; i < count && plants.length; i++) {
    const im = plants[Math.floor(h01(i, seed) * plants.length)], k = scale * (0.7 + 0.5 * h01(i, seed + 1));
    const w = Math.round(im.width * k), h = Math.round(im.height * k), px = Math.round(i * FORE_W / count + h01(i, seed + 2) * 24);
    const top = peak - Math.min(peak, Math.round(h * (0.45 + 0.3 * h01(i, seed + 3))));      // sunk into the edge, more or less
    for (const dx of [0, -FORE_W]) x.drawImage(im, px + dx, top, w, h);
  }
  return tinted(c, colour);
}
function highRow(colour, seed, peak) {
  const c = canvasOf(FORE_W, peak), x = c.getContext('2d');
  x.fillStyle = colour;
  const disc = (cx, cy, r) => { for (let dy = -r; dy <= r; dy++) { const half = Math.round(Math.sqrt(r * r - dy * dy)); for (const dx of [0, -FORE_W, FORE_W]) x.fillRect(cx - half + dx, cy + dy, half * 2, 1); } };
  for (let i = 0; i < 46; i++) disc(Math.round(h01(i, seed) * FORE_W), Math.round(h01(i, seed + 1) * 5) - 2, 5 + Math.round(h01(i, seed + 2) * 7));   // the canopy's underside
  for (let i = 0; i < 15; i++) {                       // creepers hanging from it, a leaf on either side every few pixels
    const cx = Math.round((i + h01(i, seed + 3)) * FORE_W / 15), len = 8 + Math.round(h01(i, seed + 4) * (peak - 10));
    for (let y = 0; y < len; y++) {
      const wx = cx + Math.round(Math.sin(y * 0.35 + i) * 1.2);
      x.fillRect(wx, y, 2, 1);
      if (y % 5 === 3) x.fillRect(wx + (y % 10 === 3 ? -3 : 2), y, 3, 2);
    }
    disc(cx + 1, len, 2);
  }
  return c;
}
function silhouettes(shade) {
  const black = '#0b0916';
  return { low: [lowRow(shade, 11, 13, 0.55, 22), lowRow(black, 31, 8, 0.8, 30)], high: [highRow(shade, 51, 24), highRow(black, 71, 30)] };
}
function edges(ctx, F, cam, t, width) {
  if (!F) return;
  const lay = (im, par, y) => { const off = cam * par; for (let i = Math.floor(off / im.width); i * im.width - off < width; i++) ctx.drawImage(im, snap(i * im.width - off), y); };
  lay(F.high[0], 1.1, -3); lay(F.low[0], 1.15, VH - F.low[0].height + 2);
  lay(F.high[1], 1.45, -5); lay(F.low[1], 1.6, VH - F.low[1].height + 3);
}

// Two sceneries meet at `edge` (screen x). The far scenery changes tile by tile, like a picture
// loading: each tile of the screen has its own moment, up to SPREAD pixels before or after the edge,
// and flashes as it turns. The new scenery is painted once on a spare canvas and copied tile by tile;
// what is well past the edge on either side is painted straight, so a change costs little more than none.
const TILE = 16, SPREAD = 120;
function mosaic(ctx, run, v, edge, paint) {
  const A = SCENE[run.prevBiome], B = SCENE[run.biome];
  if (A === B || edge <= -SPREAD) { paint(ctx, B); return; }
  if (edge - SPREAD >= v.w) { paint(ctx, A); return; }
  paint(ctx, A);
  const q = Math.min(Q, 2), W = Math.ceil(v.w * q), H = VH * q;      // far scenery: half the detail is plenty
  if (!scratch || scratch.width !== W || scratch.height !== H) scratch = canvasOf(W, H);
  const s = scratch.getContext('2d');
  s.setTransform(q, 0, 0, q, 0, 0); s.imageSmoothingEnabled = false;
  s.fillStyle = B.sky; s.fillRect(0, 0, v.w + 1, VH);
  paint(s, B);
  const left = Math.max(0, Math.floor((edge - SPREAD) / TILE) * TILE), right = Math.min(Math.ceil(v.w / TILE) * TILE, Math.ceil((edge + SPREAD) / TILE) * TILE);
  if (right < v.w) ctx.drawImage(scratch, right * q, 0, W - right * q, H, right, 0, (W - right * q) / q, VH);
  const lit = [];
  for (let x = left; x < right; x += TILE) for (let y = 0; y < VH; y += TILE) {
    const at = edge + (h01(x / TILE + 31 * (y / TILE), 2) - 0.5) * 2 * SPREAD;
    if (x > at) ctx.drawImage(scratch, x * q, y * q, TILE * q, TILE * q, x, y, TILE, TILE);
    else if (x > at - 14) lit.push(x, y);
  }
  ctx.fillStyle = 'rgba(210,255,250,.8)';
  for (let i = 0; i < lit.length; i += 2) ctx.fillRect(lit[i], lit[i + 1], TILE, TILE);
}

function sheet(ctx, im, frames, frame, x, y) {
  const fw = im.width / frames;
  ctx.drawImage(im, fw * frame, 0, fw, im.height, x, y, fw, im.height);
  return fw;
}

// A soft blob on the floor under whatever stands or flies above it: it ties sprites to the ground
// and tells the player how high things are.
function shadow(ctx, cx, y, w) {
  const x = snap(cx - w / 2);
  ctx.fillStyle = 'rgba(14,8,34,.34)';
  ctx.fillRect(x + 2, y - 1, w - 4, 1); ctx.fillRect(x, y, w, 2); ctx.fillRect(x + 2, y + 2, w - 4, 1);
}

// ---------- the hero ----------
// He is not a sheet of poses but four loose pieces: a body, two fists, two shoes. Where each one
// is comes from a formula, so he moves as smoothly as the screen refreshes, at any speed.

// An image centred on a point, turned by `rot` (radians, clockwise).
function part(ctx, im, cx, cy, rot) {
  if (!rot) { put(ctx, im, snap(cx - im.width / 2), snap(cy - im.height / 2)); return; }
  ctx.save(); ctx.translate(cx, cy); ctx.rotate(rot); soft(ctx); put(ctx, im, -im.width / 2, -im.height / 2); ctx.restore();
}
// Anything drawn turned: its pixels no longer fall on the canvas's own, so their edges are blended
// instead of breaking into stair-steps. Call between save() and restore(), which puts it back.
function soft(ctx) { if (Q > 1) { ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'low'; } }
const mix = (a, b, k) => a + (b - a) * k;

// One shoe of the run: half a turn in the air swinging forward, half a turn on the floor going back.
function stride(th) {
  const up = Math.max(0, Math.sin(th));
  return { x: -1 - 8 * Math.cos(th), y: -4.5 - 6 * up, r: up ? 0.5 * Math.sin(2 * th) : 0 };
}

// `seat`: where he sits when he rides, { x, y, k } with k going 0 -> 1 while he hops into the saddle.
function drawHero(ctx, run, t, seat) {
  const p = run.p, R = meta.rig, dashing = run.dash.t > 0;
  let ox = n(run.sx), oy = n(p.y);
  if (dashing) {                                       // the relic's aura
    const col = '255,211,92', r = 30 + Math.sin(t * 30) * 2;
    const g = ctx.createRadialGradient(ox, oy - 18, 2, ox, oy - 18, r);
    g.addColorStop(0, `rgba(${col},.6)`); g.addColorStop(1, `rgba(${col},0)`);
    ctx.fillStyle = g; ctx.fillRect(ox - r, oy - 18 - r, r * 2, r * 2);
  }
  if (p.inv > 0 && !run.leap && !(seat && seat.k < 1) && Math.floor(t * 14) % 2) return;   // blinking while invincible
  if (p.ball) {                                        // the Sphère: a ball of leaves, rolling. It swells out of a puff as he curls up.
    const im = IMG['hero-ball'], k = Math.min(1, (p.balled || 0) / 0.18), s = 0.55 + 0.45 * k + 0.18 * Math.sin(Math.PI * k);
    if (!im) return;
    ctx.save(); ctx.translate(ox, oy - im.height / 2 + 1); ctx.rotate(p.roll); ctx.scale(s, s); soft(ctx);
    put(ctx, im, -im.width / 2, -im.height / 2);
    ctx.restore();
    return;
  }

  // The pose: body (bx, by = where the bottom of his trunk is, tilt), shoes and fists, far then near.
  let body = IMG['hero-body'], B = R.body, bx = -1, by = -11, tilt = 0, shoes, fists, spin = 0;
  if (seat) {                                          // riding: sitting, one leg over, both hands on the reins
    const hop = Math.sin(Math.PI * seat.k) * 14;
    ox = mix(ox, seat.x, seat.k); oy = mix(oy, seat.y + 11, seat.k) - hop;
    shoes = [null, { x: 4, y: -5, r: 0.25 }];
    fists = [{ x: 8, y: -19 }, { x: 10, y: -18 }];
  } else if (p.flying && !run.leap) {                  // the leaf rotor: he hangs under it, feet dangling
    const sway = Math.sin(t * 9) * 1.5;
    body = IMG['hero-rotor']; B = R.rotor; spin = 1;
    shoes = [{ x: -5 - sway, y: -4, r: 0.15 }, { x: 3 - sway, y: -5, r: -0.1 }];
    fists = [{ x: -9, y: -17 + sway * 0.5 }, { x: 9, y: -17 - sway * 0.5 }];
  } else if (!p.ground) {                              // jumping (k = 1) then falling (k = 0): one pose slides into the other
    const k = Math.max(0, Math.min(1, 0.5 - p.vy / 900));
    shoes = [{ x: mix(-4, -9, k), y: mix(-4, -7, k), r: mix(-0.2, 0.6, k) }, { x: mix(5, 1, k), y: mix(-5, -3, k), r: mix(-0.35, 0.45, k) }];
    fists = [{ x: mix(-9, -8, k), y: mix(-33, -19, k) }, { x: mix(10, 9, k), y: mix(-34, -30, k) }];
    tilt = mix(0.1, -0.12, k);
  } else {                                             // running
    const th = p.phase, sq = p.squash * 2;
    shoes = [stride(th + Math.PI), stride(th)];
    fists = [{ x: 2 - 7 * Math.cos(th), y: -21 - 2 * Math.abs(Math.cos(th)) }, { x: 2 + 7 * Math.cos(th), y: -21 - 2 * Math.abs(Math.cos(th)) }];
    by += 1.5 * Math.abs(Math.sin(th)) + sq;
    shoes[0].x -= sq; shoes[1].x += sq;
    if (run.up.sprint) shoes = [null, null];             // Sprint: no strides any more, a wheel of legs (below)
  }

  ctx.save(); ctx.translate(ox, oy);
  if (run.leap) { ctx.translate(0, -20); ctx.rotate(p.roll); ctx.translate(0, 20); soft(ctx); }     // knocked out: he tumbles
  if (shoes[0]) part(ctx, FAR.shoe, shoes[0].x, shoes[0].y, shoes[0].r);
  part(ctx, FAR.fist, fists[0].x, fists[0].y, 0);
  ctx.save(); ctx.translate(snap(bx), snap(by)); if (tilt) ctx.rotate(tilt);
  if (spin) {                                          // the blades are squeezed sideways, back and forth: they spin
    const w = 0.25 + 0.75 * Math.abs(Math.cos(t * 26)), bw = B.w * w;
    put(ctx, body, 0, 0, B.w, B.blade, snap(B.hx - B.tx - B.hx * w), -B.h, snap(bw), B.blade);
    put(ctx, body, 0, B.blade, B.w, B.h - B.blade, -B.tx, -B.h + B.blade, B.w, B.h - B.blade);
  } else {
    // His leaves live: the picture is cut in thin rows that the wind moves, more and more towards the
    // tips, pulled back harder the faster he goes. His head, his trunk and the backpack with the relic
    // (the columns behind him, up to the relic) stay still.
    if (tilt) soft(ctx);
    const x0 = snap(-B.tx), y0 = -B.h, w = body.width, h = body.height, hair = Math.round(B.hy - 6), pack = Math.round((B.gx || 0) + 5);
    const pull = Math.min(1, run.speed / 700), air = p.ground ? 0 : Math.max(-1, Math.min(1, p.vy / 700));
    put(ctx, body, 0, hair, w, h - hair, x0, y0 + hair, w, h - hair);
    put(ctx, body, 0, 0, pack, hair, x0, y0, pack, hair);
    for (let r = 0; r < hair; r += 2) {
      const up = 1 - r / hair, dx = (Math.sin(t * 8 + r * 0.4) * 1.3 - 1.6 * pull) * up * up, dy = -air * 2.5 * up;
      put(ctx, body, pack, r, w - pack, 2, x0 + pack + snap(dx), y0 + r + snap(dy), w - pack, 2);
    }
  }
  // the relic in his backpack: a soft glow, which flares when it moves the world (a boss coming, a new place)
  if (B.gx !== undefined) {
    const gx = -B.tx + B.gx, gy = -B.h + B.gy, k = run.relic || 0, r = 7 + 16 * k;
    const g = ctx.createRadialGradient(gx, gy, 1, gx, gy, r);
    g.addColorStop(0, `rgba(160,250,255,${0.3 + 0.12 * Math.sin(t * 3) + 0.6 * k})`); g.addColorStop(1, 'rgba(92,242,224,0)');
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = g; ctx.fillRect(gx - r, gy - r, r * 2, r * 2); ctx.restore();
    if (k > 0.2) {
      ctx.fillStyle = '#eaffff';
      for (let i = 0; i < 5; i++) { const a = t * 3 + i * 1.26, d = 6 + 10 * k + 3 * Math.sin(t * 9 + i); ctx.fillRect(snap(gx + Math.cos(a) * d), snap(gy + Math.sin(a) * d), 1, 1); }
    }
  }
  ctx.restore();
  if (shoes[1]) part(ctx, IMG['hero-shoe'], shoes[1].x, shoes[1].y, shoes[1].r);
  else if (!shoes[0]) {                                // the cartoon whirl: shoes chasing each other round a blur, streaks flying off it
    const a = t * 34;
    ctx.fillStyle = 'rgba(255,255,255,.28)'; ctx.beginPath(); ctx.ellipse(-1, -7, 11, 8, 0, 0, Math.PI * 2); ctx.fill();
    ctx.lineWidth = 1.5; ctx.strokeStyle = 'rgba(255,255,255,.8)';
    for (let k = 0; k < 3; k++) { ctx.beginPath(); ctx.ellipse(-1, -7, 11 - k * 3, 8 - k * 2.2, 0, a * (1 + k * 0.3) + k * 2, a * (1 + k * 0.3) + k * 2 + 1.9); ctx.stroke(); }
    ctx.globalAlpha = 0.85;
    for (let k = 0; k < 4; k++) { const b = a + k * Math.PI / 2; part(ctx, IMG['hero-shoe'], -1 + Math.cos(b) * 8, -7 + Math.sin(b) * 5.5, b + Math.PI / 2); }
    ctx.globalAlpha = 1;
  }
  part(ctx, IMG['hero-fist'], fists[1].x, fists[1].y, 0);
  ctx.restore();
}

// ---------- mounts ----------
// Draws one frame of a mount standing on `floor` (its saddle above x) and returns where a rider's trunk rests.
function drawMount(ctx, kind, frame, x, floor, bob) {
  const im = IMG['mount-' + kind], M = meta.mounts[kind];
  if (!im) return null;
  const cw = im.width / M.frames, top = floor + 1 - im.height + bob;
  ctx.drawImage(im, cw * frame, 0, cw, im.height, snap(x - M.seatX), snap(top), cw, im.height);
  return { x, y: top + M.seatY - 3 };
}

// A flying mount is placed by its saddle, whatever the size of its drawing (wings up and down make
// a tall picture): the floor to give drawMount so that the saddle is at `seat`.
const seatFloor = (kind, seat) => { const im = IMG['mount-' + kind], M = meta.mounts[kind]; return im ? seat - M.seatY + 2 + im.height : seat; };

// The gorilla hanging from the vines: its gripping fist stays put at the top, the body swings under it.
function drawHang(ctx, frame, x) {
  const im = IMG['mount-gorilla-hang'], M = meta.mounts['gorilla-hang'];
  if (!im) return null;
  const cw = im.width / M.frames, left = snap(x + 12 - M.seatX);
  ctx.drawImage(im, cw * frame, 0, cw, im.height, left, 5, cw, im.height);
  return { x: left + M.seats[frame][0], y: M.seats[frame][1] + 2 };
}

// The vines the gorilla travels along: one long liana sagging from knot to knot across the top of
// the frame, a strand hanging from each knot. `k` slides them in from above (0 hidden, 1 down).
const VINE = 72;                                       // pixels from one knot to the next
let liana = null;                                      // one sagging stretch of it, drawn once
function drawVines(ctx, cam, t, width, k) {
  if (!liana) {
    liana = canvasOf(VINE, 12); const c = liana.getContext('2d');
    for (let u = 0; u < VINE; u += 2) {
      const y = Math.round(Math.sin(u / VINE * Math.PI) * 4);
      c.fillStyle = '#1a1024'; c.fillRect(u, y, 2, 7);
      c.fillStyle = '#5d8a2c'; c.fillRect(u, y + 1, 2, 5);
      c.fillStyle = '#a4d64a'; c.fillRect(u, y + 1, 2, 1);
    }
  }
  const dy = Math.round((k - 1) * 50), first = Math.floor(cam / VINE);
  for (let i = first - 1; i * VINE - cam < width; i++) {
    const x0 = snap(i * VINE - cam);
    ctx.drawImage(liana, x0, dy + 7);
    const len = 18 + Math.round(h01(i, 81) * 26);      // the strand under the knot, swaying from its top
    for (let v = 0; v < len; v += 2) {
      const sway = Math.round(Math.sin(t * 1.6 + i) * 2.5 * v / len);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(x0 - 2 + sway, dy + 13 + v, 4, 2);
      ctx.fillStyle = v % 8 < 2 ? '#a4d64a' : '#4f7d2a'; ctx.fillRect(x0 - 1 + sway, dy + 13 + v, 2, 2);
    }
    ctx.fillStyle = '#1a1024'; ctx.fillRect(x0 - 5, dy + 5, 10, 9);                      // the knot, with two leaves
    ctx.fillStyle = '#3f8f3a'; ctx.fillRect(x0 - 4, dy + 6, 8, 7);
    ctx.fillStyle = '#7bd13c'; ctx.fillRect(x0 - 3, dy + 7, 3, 3); ctx.fillRect(x0 + 1, dy + 9, 2, 2);
  }
}

// A small arrow head whose tip is at (x, y), pointing up (dir -1) or down (dir 1), `size` rows tall.
function chevron(ctx, x, y, dir, colour, size = 4) {
  for (const [c, grow] of [['#1a1024', 1], [colour, 0]]) {
    ctx.fillStyle = c;
    for (let k = 0; k < size; k++) ctx.fillRect(x - k - 1 - grow, y - dir * k - grow, 2 * k + 2 + 2 * grow, 1 + 2 * grow);
  }
}

// A hollow log or pipe is shown cut open: bark all around, and openings through which the hero is seen
// running inside. LOG_ROOF and LOG_FLOOR are the rows of the sprite between which the tunnel lies.
const LOG_ROOF = 30, LOG_FLOOR = 68 - LOG_CUT, LOG_WINDOW = 54, LOG_RIB = 20;
function logWindows(pl, x0) { const out = []; for (let x = x0 + 34; x + LOG_WINDOW < x0 + n(pl.w) - 30; x += LOG_WINDOW + LOG_RIB) out.push(x); return out; }

const SWARM = [[0, 0], [-15, -7], [13, -8], [-10, 9], [15, 7], [-26, 2], [27, -1]];   // where each mosquito of a swarm flies

// `v.w` is the visible width, in art pixels. The caller has set y = 0 at the top of the play area.
export function draw(ctx, run, v, t) {
  if (!ready) { ctx.fillStyle = '#0b2530'; ctx.fillRect(0, 0, v.w, VH); return; }
  const cam = run.cam / PIXEL;
  const now = SCENE[run.biome], edge = snap(run.biomeX / PIXEL - cam);
  const sx = (wx) => snap(wx / PIXEL - cam);
  const floorPx = (x) => n(floorAt(run, (cam + x) * PIXEL));          // floor height under a screen x
  const fast = Math.max(0, Math.min(1, (run.speed - 480) / 380));     // 0 at a jog, 1 at full speed
  ctx.save();
  if (run.shake > 0) ctx.translate(Math.round((Math.random() - 0.5) * run.shake * 7), Math.round((Math.random() - 0.5) * run.shake * 7));

  // three depths of scenery
  ctx.fillStyle = now.sky; ctx.fillRect(0, -8, v.w, VH + 16);
  mosaic(ctx, run, v, edge, (c, S) => {
    if (S.bg) strip(c, S.bg, cam * 0.18, VH - S.bg.height, v.w);
    if (!S.mid) return;
    const y = GN + 20 - S.mid.height;
    strip(c, S.mid, cam * 0.5, y, v.w);
    c.fillStyle = S.base; c.fillRect(0, y + S.mid.height, v.w, VH);  // seen only where the path dips
  });
  drawSky(ctx, t, v.w);

  if (run.boss) drawVorace(ctx, run, t);           // behind the floor: its legs plunge into it
  drawProps(ctx, run, cam, v.w, t);
  for (const dc of run.decor || []) {               // the scenery that can be smashed; with Brise-tout it glints
    const im = DECOR[dc.biome]; if (dc.broken || !im) continue;
    const x = snap(sx(dc.x + DECOR_W / 2) - im.width / 2), y = floorPx(x + im.width / 2) - im.height + 3;
    if (x > v.w || x + im.width < 0) continue;
    ctx.drawImage(im, x, y);
    if (run.up.breaker && Math.sin(t * 4 + dc.x) > 0.7) { ctx.fillStyle = '#fff8d8'; const gx = x + im.width * 0.7, gy = y + 4; ctx.fillRect(snap(gx), gy - 2, 1, 5); ctx.fillRect(snap(gx) - 2, gy, 5, 1); }
  }
  const cut = Math.max(0, Math.min(v.w, edge));        // the floor changes exactly where the new place begins
  if (run.prevBiome !== run.biome) drawGround(ctx, run, SCENE[run.prevBiome].ground, cam, 0, cut, VH + 8);
  drawGround(ctx, run, now.ground, cam, run.prevBiome !== run.biome ? cut : 0, v.w, VH + 8);
  drawLife(ctx, cam, t, v.w, floorPx);
  drawDirt(ctx, cam, t);
  for (const h of run.pits) {                          // a hole where the floor gave way: dark, ragged rims, no bottom
    const x0 = sx(h.x0), x1 = sx(h.x1);
    if (x1 < 0 || x0 > v.w) continue;
    const g = ctx.createLinearGradient(0, GN - 4, 0, VH);
    g.addColorStop(0, '#1c1430'); g.addColorStop(0.25, '#0a0712'); g.addColorStop(1, '#000');
    ctx.fillStyle = g; ctx.fillRect(x0, GN - 4, x1 - x0, VH - GN + 8);
    ctx.fillStyle = '#1a1024';
    for (let y = GN - 4; y < VH; y += 6) { const k = Math.round(h01(y, 7) * 4); ctx.fillRect(x0 - 2, y, 2 + k, 6); ctx.fillRect(x1 - k, y, k + 2, 6); }
  }

  const templeX = snap(TEMPLE_X - cam), inTemple = IMG.temple && templeX > -IMG.temple.width;
  if (inTemple) ctx.drawImage(IMG.temple, templeX, GN - IMG.temple.height + 3);
  if (inTemple && run.exploded) drawBlast(ctx, templeX);

  if (inTemple && !run.exploded && IMG['temple-rubble']) {   // the jungle has closed the way out: boulders held in roots, until the blast
    const im = IMG['temple-rubble'];
    ctx.drawImage(im, templeX + 105 - (im.width >> 1), GN - 14 - im.height);
  }

  // tight places, for the ball only. The hollow trunk stands behind the path: its openings show what
  // rolls inside. The gallery is a burrow cut into the earth under the path.
  const coinAt = (c) => {
    const bob = Math.round(Math.sin(t * 5 + c.x * 0.02) * 1.5), im = c.heart ? IMG.heart : c.gem ? IMG['gem-' + c.gem] || IMG.gem : null;
    if (im) { ctx.drawImage(im, sx(c.x) - (im.width >> 1), n(c.y) - (im.height >> 1) + bob); return; }
    const f = meta.coin.frames, fw = IMG.coin.width / f;
    sheet(ctx, IMG.coin, f, Math.floor(t * 10 + c.x * 0.01) % f, sx(c.x) - (fw >> 1), n(c.y) - (IMG.coin.height >> 1) + (f > 1 ? 0 : bob));
  };
  const ribs = (z, roof) => {                          // the trunk again, over what is inside: between the openings, and its roof
    const im = SCENE[biomeAt(run, z.x)].tunnel, x = sx(z.x), y = n(GROUND - LOG.h) - 8, w = im.width;
    if (roof) ctx.drawImage(im, 0, 0, w, LOG_ROOF, x, y, w, LOG_ROOF);
    let from = x;
    for (const wx of [...logWindows(z, x), x + w]) {
      ctx.drawImage(im, from - x, LOG_ROOF, wx - from, im.height - LOG_ROOF, from, y + LOG_ROOF, wx - from, im.height - LOG_ROOF);
      from = wx + LOG_WINDOW;
    }
  };
  for (const z of run.zones) {
    const x = sx(z.x), w = n(z.w), S = SCENE[biomeAt(run, z.x)];
    if (x > v.w || x + w < -10) continue;
    if (z.kind === 'log') {
      const y = n(GROUND - LOG.h);
      ctx.drawImage(S.tunnel, x, y - 8);
      const top = y - 8 + LOG_ROOF, h = LOG_FLOOR - LOG_ROOF, [rimC, wall, floor, dark] = S.hollow;
      for (const wx of logWindows(z, x)) {             // each opening: a rounded hole with a dark rim, the far wall, the floor
        for (const [inset, col] of [[0, '#1a1024'], [1, rimC], [2, wall]]) {
          ctx.fillStyle = col;
          ctx.fillRect(wx + inset + 3, top + inset, LOG_WINDOW - 2 * inset - 6, h - 2 * inset);
          ctx.fillRect(wx + inset + 1, top + inset + 1, LOG_WINDOW - 2 * inset - 2, h - 2 * inset - 2);
          ctx.fillRect(wx + inset, top + inset + 3, LOG_WINDOW - 2 * inset, h - 2 * inset - 6);
        }
        ctx.fillStyle = dark; ctx.fillRect(wx + 5, top + 2, LOG_WINDOW - 10, 5);              // shade under the roof
        ctx.fillStyle = floor; ctx.fillRect(wx + 5, top + h - 5, LOG_WINDOW - 10, 3);         // the worn floor inside
      }
      for (const c of run.coins) if (c.tight === 'log' && c.x >= z.x && c.x < z.x + z.w) coinAt(c);
      ribs(z, false);
    } else {
      if (z.im === undefined || z.of !== S) {            // the burrow is drawn once, then kept with its zone
        const deep = Math.round(GALLERY / PIXEL), ramp = Math.round(70 / PIXEL), [rimC, wall, floor] = S.hollow, W = Math.ceil(w);
        z.im = canvasOf(W, deep + 4); z.of = S;
        const c = z.im.getContext('2d');
        for (let k = 0; k < W; k += 2) {
          const kk = Math.max(0, Math.min(1, k / ramp, (W - k) / ramp)), bottom = 2 + Math.round(deep * kk), top = Math.max(1, bottom - 23);
          c.fillStyle = '#1a1024'; c.fillRect(k, top - 1, 2, bottom - top + 2);
          c.fillStyle = wall; c.fillRect(k, top, 2, bottom - top);
          c.fillStyle = rimC; c.fillRect(k, top, 2, 2);
          c.fillStyle = floor; c.fillRect(k, bottom - 2, 2, 2);
        }
      }
      ctx.drawImage(z.im, x, GN);
    }
  }

  for (const pl of run.plats) {
    const x = sx(pl.x), y = n(pl.y), w = n(pl.w), S = SCENE[biomeAt(run, pl.x)];
    if (pl.kind === 'slab') {                          // a bridge over the hollow, the cave below in its shade
      ctx.fillStyle = 'rgba(12,8,30,.4)';
      for (let k = 0; k < w; k += SLICE) { const f = floorPx(x + k + 2); if (f > y + 18) ctx.fillRect(x + k, y + 18, Math.min(SLICE, w - k), f - y - 18); }
      const pillar = S.pillar;
      if (pillar) for (const px of [x + 2, x + w - pillar.width - 2]) {             // a pillar under each end, down to the floor
        const h = Math.min(pillar.height, floorPx(px + pillar.width / 2) - y - 12);
        if (h > 0) ctx.drawImage(pillar, 0, 0, pillar.width, h, px, y + 14, pillar.width, h);
      }
      // both ends of the drawing are kept whole, its middle is repeated in between
      const im = S.slab, cap = 26, mid = im.width - 2 * cap, top = y - S.slabTop;
      ctx.drawImage(im, 0, 0, cap, im.height, x, top, cap, im.height);
      for (let k = cap; k < w - cap; k += mid) {
        const part = Math.min(mid, w - cap - k);
        ctx.drawImage(im, cap, 0, part, im.height, x + k, top, part, im.height);
      }
      ctx.drawImage(im, im.width - cap, 0, cap, im.height, x + w - cap, top, cap, im.height);
    } else ctx.drawImage(S.platform, x, y - S.platTop);
  }

  for (const c of run.coins) if (c.tight !== 'log') coinAt(c);

  if (run.vine > 0) drawVines(ctx, cam, t, v.w, run.vine);

  // mounts waiting on the path: a warm glow and a bouncing arrow say "come here", not "watch out"
  // Each one waits its own way: the gorilla swings along a vine high up, the rhino grazes, the
  // dragonfly zigzags ahead. Missed, it is gone.
  for (const it of run.items) {
    const x = sx(it.x), f = floorPx(x), im = IMG['mount-' + it.kind];
    if (x > v.w + 80 || x < -100 || !im) continue;
    const glow = (cx, cy) => {
      const g = ctx.createRadialGradient(cx, cy, 4, cx, cy, 60);
      g.addColorStop(0, `rgba(255,224,120,${0.42 + 0.14 * Math.sin(t * 5)})`); g.addColorStop(1, 'rgba(255,224,120,0)');
      ctx.fillStyle = g; ctx.fillRect(cx - 60, cy - 60, 120, 120);
    };
    const bounce = Math.round(Math.abs(Math.sin(t * 5)) * 6);
    if (it.kind === 'gorilla') {
      const H = IMG['mount-gorilla-hang'], M = meta.mounts['gorilla-hang'];
      if (!H) continue;
      const cw = H.width / M.frames, top = f - n(PERCH) - H.height, left = snap(x + 12 - M.seatX);
      glow(x + 12, top + H.height * 0.6);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(snap(x + 11), -8, 4, top + 14);                  // the vine it hangs from
      ctx.fillStyle = '#5d8a2c'; ctx.fillRect(snap(x + 12), -8, 2, top + 14);
      ctx.drawImage(H, cw * (Math.floor(t * 6 + it.ph) % 4), 0, cw, H.height, left, top, cw, H.height);
      chevron(ctx, x + 12, top + H.height + 8 + bounce, -1, '#ffd35c', 6);                     // an arrow under it: up there
      continue;
    }
    if (it.kind === 'rhino') {                         // head down in the grass, nibbling
      glow(x + 6, f - 28);
      shadow(ctx, x + 12, f - 1, 64);
      ctx.save(); ctx.translate(x - 30, f); ctx.rotate(0.06 + 0.03 * Math.sin(t * 6 + it.ph)); soft(ctx);
      drawMount(ctx, 'rhino', 1, 30, 0, 0);
      ctx.restore();
      ctx.fillStyle = '#7bd13c';
      for (let k = 0; k < 3; k++) { const up = (t * 9 + k * 2.3 + it.ph) % 3; ctx.fillRect(snap(x + 30 + k * 3), f - 3 - Math.round(up * 2), 1, 3); }
      chevron(ctx, x + 6, f - im.height - 6 - bounce, 1, '#ffd35c', 6);
      continue;
    }
    const foot = seatFloor(it.kind, n(it.y) - 10);    // the dragonfly, zigzagging on ahead
    glow(x + 6, n(it.y) - 14);
    shadow(ctx, x + 6, f - 1, 30);
    drawMount(ctx, it.kind, Math.floor(t * 16) % 4, x, foot, 0);
    chevron(ctx, x + 6, n(it.y) - 52 - bounce, 1, '#ffd35c', 6);
  }

  for (const o of run.obs) {
    const x = sx(o.x), y = n(o.y), foot = n(o.y + o.h);
    if ((x > v.w + 10 && !(o.kind === 'dart' && o.state === 'warn')) || x < -80) continue;   // a fonceur waiting off screen still shows its warning
    if (o.kind === 'acid') {                           // the plant's acid: a glowing ball in the air, a bubbling puddle on the floor
      const w = n(o.w), cx = x + w / 2;
      if (o.tentacle) {                                // a root of Vorace slithering along the floor, its pointed end first:
        // drawn pixel by pixel in the colours of her legs, so it stays sharp (outline, lit top, thorns)
        const C = ['#1a1024', '#2c4f1c', '#4c8a2c', '#86c048', '#f0e2c0'];
        for (let u = 0; u < w; u++) {
          const th = Math.min(5, 2 + (u / 5 | 0)), yy = Math.round(foot - 5 - th - Math.sin(t * 12 + u * 0.18 + o.ph) * 2.5), xx = x + u;
          ctx.fillStyle = C[0]; ctx.fillRect(xx, yy - 1, 1, th + 2);
          ctx.fillStyle = C[2]; ctx.fillRect(xx, yy, 1, th);
          ctx.fillStyle = C[3]; ctx.fillRect(xx, yy, 1, 1);
          ctx.fillStyle = C[1]; ctx.fillRect(xx, yy + th - 1, 1, 1);
          if (u % 11 === 6 && th >= 4) { ctx.fillStyle = C[0]; ctx.fillRect(xx - 1, yy - 4, 3, 3); ctx.fillStyle = C[4]; ctx.fillRect(xx, yy - 3, 1, 2); }
        }
        continue;
      }
      if (o.drop) {                                    // its shadow on the floor shows where it will land
        const f = floorPx(cx), k = Math.max(0, Math.min(1, (y + 60) / (f + 20)));
        ctx.fillStyle = `rgba(20,40,6,${0.25 + 0.4 * k})`; ctx.fillRect(snap(cx - 4 - 10 * k), f - 2, snap(8 + 20 * k), 3);
        ctx.fillStyle = `rgba(168,255,60,${0.2 + 0.4 * k})`; ctx.fillRect(snap(cx - 2 - 6 * k), f - 1, snap(4 + 12 * k), 1);
      }
      if (o.puddle) {
        const g = ctx.createRadialGradient(x + w / 2, foot - 4, 2, x + w / 2, foot - 4, w * 0.7);   // a sickly glow around it
        g.addColorStop(0, `rgba(168,255,60,${0.35 + 0.15 * Math.sin(t * 6 + o.x)})`); g.addColorStop(1, 'rgba(168,255,60,0)');
        ctx.fillStyle = g; ctx.fillRect(x - w * 0.2, foot - 30, w * 1.4, 34);
        ctx.fillStyle = '#1a1024'; ctx.fillRect(x + 4, foot - 11, w - 8, 12); ctx.fillRect(x, foot - 8, w, 9);
        ctx.fillStyle = '#5cd23c'; ctx.fillRect(x + 5, foot - 10, w - 10, 10); ctx.fillRect(x + 1, foot - 7, w - 2, 7);
        ctx.fillStyle = '#a8ff3c'; ctx.fillRect(x + 7, foot - 10, w - 14, 3);
        ctx.fillStyle = '#e8ffb0'; ctx.fillRect(x + 10, foot - 10, w - 20, 1);
        for (let k = 0; k < 4; k++) { const up = (t * 2.5 + k * 0.29 + o.x * 0.01) % 1; ctx.globalAlpha = 1 - up; ctx.fillStyle = '#e8ffb0'; ctx.fillRect(snap(x + 8 + k * (w - 16) / 3), foot - 12 - Math.round(up * 12), 3, 3); }
        ctx.globalAlpha = 1;
      } else {
        const r = w / 2, cy = y + r, g = ctx.createRadialGradient(cx - 2, cy - 2, 1, cx, cy, r + 6);
        g.addColorStop(0, '#f4ffc8'); g.addColorStop(0.5, '#8cf03c'); g.addColorStop(0.8, '#2f9a2a'); g.addColorStop(1, 'rgba(47,154,42,0)');
        ctx.fillStyle = '#1a1024'; ctx.beginPath(); ctx.arc(cx, cy, r + 1, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, r + 6, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = 'rgba(168,255,60,.5)'; for (let k = 1; k < 4; k++) ctx.fillRect(snap(cx + k * 6), snap(cy - 1 + Math.sin(t * 20 + k) * 2), 3, 3);   // dripping trail
      }
      continue;
    }
    const role = ROLE[o.kind];
    if (!role) continue;
    const name = o.kind === 'hover' && !o.biome ? (o.mid ? 'spider-mid' : 'spider-low') : role[o.biome || 0], H = HAZ[name];
    if (!H) continue;
    const im = o.ghost ? H.ghost : H.im, pad = o.ghost ? 1 : H.pad, fw = im.width / H.frames, cx = x + n(o.w) / 2, cy = y + n(o.h) / 2;
    if (LOOK === 3 && !o.ghost && !(o.kind === 'dart' && o.state !== 'go')) {   // a warm glow behind what hurts
      const r = Math.max(fw, im.height) * 0.95, g = ctx.createRadialGradient(cx, cy, 2, cx, cy, r);
      g.addColorStop(0, 'rgba(255,190,90,.5)'); g.addColorStop(1, 'rgba(255,190,90,0)');
      ctx.fillStyle = g; ctx.fillRect(cx - r, cy - r, r * 2, r * 2);
    }
    if (o.ghost) ctx.globalAlpha = 0.78 + 0.1 * Math.sin(t * 6 + o.x);
    if (o.kind === 'spiky') {                          // on the floor
      const shut = name === 'beartrap' && Math.abs(cx - n(run.sx)) < 30;          // the trap snaps as he goes over it
      const hop = name === 'spiky' && Math.sin(t * 6 + o.x) > 0.6 ? -1 : 0;
      shadow(ctx, cx, foot - 1, fw - 2 * pad);
      sheet(ctx, im, H.frames, shut ? 1 : 0, snap(cx - fw / 2), foot - im.height + pad + hop);
      if (name === 'spikebot' && Math.sin(t * 8 + o.x) > 0) {                     // its eye, blinking
        const g = ctx.createRadialGradient(cx, foot - im.height + 3, 1, cx, foot - im.height + 3, 9);
        g.addColorStop(0, 'rgba(90,240,255,.8)'); g.addColorStop(1, 'rgba(90,240,255,0)');
        ctx.fillStyle = g; ctx.fillRect(cx - 9, foot - im.height - 6, 18, 18);
      }
    } else if (o.kind === 'dart') {                    // a "!" at the edge, at its height; then across in one go
      if (o.state === 'warn') warnMark(ctx, v.w - 12, cy, t);
      else if (o.state === 'go') {
        const frame = H.frames > 1 ? Math.floor(t * (name === 'fly' ? 14 : 9) + o.ph) % H.frames : 0, x0 = snap(cx - fw / 2);
        ctx.fillStyle = 'rgba(255,255,255,.45)';
        for (let k = 0; k < 3; k++) ctx.fillRect(x0 + fw - 4 + k * 6, snap(cy - 6 + k * 6), 14 + k * 4, 1);       // the wind it leaves behind
        if (name === 'missile') { ctx.fillStyle = Math.floor(t * 30) % 2 ? '#ffd35c' : '#ff7a2a'; ctx.fillRect(x0 + fw - 2, snap(cy - 2), 4 + Math.round(Math.random() * 4), 4); }
        sheet(ctx, im, H.frames, frame, x0, snap(cy - im.height / 2));
      }
    } else {                                           // hanging still in mid-air, alive all the same
      const bob = Math.sin(t * 3 + o.ph) * 2, top = snap(cy - im.height / 2 + bob);
      let frame = 0;
      if (name.startsWith('spider')) { ctx.fillStyle = 'rgba(235,240,255,.8)'; ctx.fillRect(snap(cx), -8, 1, top + 10); frame = Math.floor(t * 3 + o.ph) % 2; }
      if (name === 'bat') frame = 1 + (Math.floor(t * 12 + o.ph) & 1);
      if (name === 'idol') {                           // the glow of its eyes and runes
        const g = ctx.createRadialGradient(cx, top + im.height * 0.4, 2, cx, top + im.height * 0.4, 20);
        g.addColorStop(0, `rgba(255,150,40,${0.35 + 0.15 * Math.sin(t * 4 + o.ph)})`); g.addColorStop(1, 'rgba(255,150,40,0)');
        ctx.fillStyle = g; ctx.fillRect(cx - 20, top - 10, 40, im.height + 20);
      }
      shadow(ctx, cx, floorPx(cx) - 1, Math.max(8, 20 - ((floorPx(cx) - top) >> 4)));
      sheet(ctx, im, H.frames, frame, snap(cx - fw / 2), top);
      if (name === 'drone') { ctx.fillStyle = 'rgba(220,240,255,.5)'; const w = 6 + Math.round(Math.abs(Math.sin(t * 40)) * 5); ctx.fillRect(snap(cx - fw / 2 + 2), top + 1, w, 1); ctx.fillRect(snap(cx + fw / 2 - 2 - w), top + 1, w, 1); }
    }
    if (o.ghost) {                                     // tipsy and harmless: hiccuping bubbles
      ctx.fillStyle = '#eafcff';
      for (let k = 0; k < 3; k++) { const up = (t * 14 + k * 9 + o.x) % 22; ctx.globalAlpha = 0.7 * (1 - up / 22); ctx.fillRect(snap(cx - 8 + k * 7 + Math.sin(up * 0.6 + k) * 2), y - 2 - up, 2, 2); }
    }
    ctx.globalAlpha = 1;
  }

  if (!run.dead) {
    const p = run.p, hx = n(run.sx), floor = p.plat ? n(p.plat.y) : floorPx(hx), M = run.mount;
    const aloft = M && (p.hang || MOUNTS[M.kind].fly);
    if (!inTemple || hx > DOOR_X + 8) shadow(ctx, hx - 2 + (M && !aloft ? 8 : 0), floor - 1, aloft ? 26 : M ? 62 : Math.max(8, 20 - ((floor - n(p.y)) >> 3)));
    if (run.gone) {                                    // the mount that just took a blow: it tumbles back, shrinks and fades
      const g = run.gone, k = Math.min(1, g.t / 0.7), key = g.kind + (g.hang ? '-hang' : ''), im = IMG['mount-' + key], K = meta.mounts[key];
      if (im) {
        const cw = im.width / K.frames;
        ctx.save(); ctx.globalAlpha = 1 - k * k;
        ctx.translate(sx(g.x), n(g.y) - im.height / 2 - 46 * Math.sin(k * Math.PI * 0.6)); ctx.rotate(-k * 1.4); ctx.scale(1 - 0.55 * k, 1 - 0.55 * k); soft(ctx);
        ctx.drawImage(im, 0, 0, cw, im.height, -cw / 2, -im.height / 2, cw, im.height);
        ctx.restore();
      }
    }
    let seat = null;
    if (M) {
      let s;
      if (p.hang) s = drawHang(ctx, Math.floor(p.phase / (Math.PI * 2) * 4) % 4, hx);          // hand over hand under the vines
      else if (MOUNTS[M.kind].fly) s = drawMount(ctx, M.kind, Math.floor(t * 18) % 4, hx, seatFloor(M.kind, n(p.y) - 34), 0);
      else {                                           // it gallops under him; in the air it stretches out
        const frame = !p.ground ? (M.kind === 'gorilla' ? 3 : 0) : Math.floor(p.phase / (Math.PI * 2) * 4) % 4;
        s = drawMount(ctx, M.kind, frame, hx, n(p.y), p.ground ? -Math.abs(Math.sin(p.phase * 2)) * 1.5 : 0);
      }
      if (s) seat = { ...s, k: Math.min(1, M.t / 0.32) };
    }
    if (inTemple && run.cam === 0) {                   // he steps out of the doorway: hidden while still inside
      ctx.save(); ctx.beginPath(); ctx.rect(DOOR_X, -400, v.w, 1200); ctx.clip();
      drawHero(ctx, run, t, seat); ctx.restore();
    } else drawHero(ctx, run, t, seat);
  }

  if (run.p.ball && run.p.ball.kind === 'log' && !run.dead) ribs(run.p.ball, true);     // he rolls inside the trunk, not in front of it

  // the follower monsters: one per lane taken, a flashing band along each of those lanes, then the
  // rush; in the city, drones that stay put and fire a laser along their lanes
  if (run.fm) {
    const f = run.fm, name = ROLE.swarm[f.biome || 0], H = HAZ[name], cx = n(f.sx), aiming = f.phase === 'aim';
    const step = n(FM.step), pulse = Math.sin(t * 12) ** 2;
    f.act.forEach((on, k) => {
      if (!on || cx < -60) return;
      const top = GN - (k + 1) * step, cy = top + step / 2;
      if (aiming && f.t > 0.3 && !f.ghost) {           // a band that fades in from the left, runs under them, and fades out behind
        const end = cx + 40, fade = (x) => Math.max(0, Math.min(1, x / (end * 0.5), (end - x) / 60));
        const a = 0.12 + 0.1 * pulse, g = ctx.createLinearGradient(0, 0, end, 0);
        g.addColorStop(0, 'rgba(255,70,70,0)'); g.addColorStop(0.5, `rgba(255,70,70,${a})`); g.addColorStop(Math.max(0.5, 1 - 60 / end), `rgba(255,70,70,${a})`); g.addColorStop(1, 'rgba(255,70,70,0)');
        ctx.fillStyle = g; ctx.fillRect(0, top + 3, end, step - 6);
        for (let x = -((t * 60) % 16); x < end; x += 16) {
          ctx.fillStyle = `rgba(255,96,96,${(0.55 + 0.35 * pulse) * fade(x)})`;
          ctx.fillRect(snap(x), top + 3, 9, 2); ctx.fillRect(snap(x), top + step - 5, 9, 2);
        }
      }
      if (f.phase === 'fire' && !f.ghost) {           // the laser: a flicker while it charges, then the beam
        const h = n(LASER.h), x1 = cx - 18;
        if (f.t < LASER.on) { if (Math.floor(t * 40) % 2) { ctx.fillStyle = 'rgba(255,90,120,.8)'; ctx.fillRect(0, snap(cy), x1, 1); } }
        else if (f.t < LASER.end) {
          const k2 = f.t < LASER.off ? 1 : 1 - (f.t - LASER.off) / (LASER.end - LASER.off), hh = h * k2;
          ctx.fillStyle = `rgba(255,40,90,${0.45 * k2})`; ctx.fillRect(0, snap(cy - hh / 2 - 2), x1, hh + 4);
          ctx.fillStyle = `rgba(255,140,170,${0.9 * k2})`; ctx.fillRect(0, snap(cy - hh / 4), x1, hh / 2);
          ctx.fillStyle = `rgba(255,255,255,${k2})`; ctx.fillRect(0, snap(cy - 1), x1, 2);
        }
      }
      if (f.ghost) ctx.globalAlpha = 0.78;
      const jx = Math.sin(t * 9 + k * 2.1) * 2.5, jy = Math.cos(t * 11 + k * 1.7) * 2.5;
      if (name === 'wisp' || !H) {                     // a will-o'-the-wisp: a flame of pale light
        const r = 9 + Math.sin(t * 9 + k) * 1.5, g = ctx.createRadialGradient(cx + jx, cy + jy, 1, cx + jx, cy + jy, r * 2);
        g.addColorStop(0, f.ghost ? 'rgba(220,250,255,.9)' : 'rgba(230,255,250,.95)'); g.addColorStop(0.35, 'rgba(120,255,220,.7)'); g.addColorStop(1, 'rgba(60,200,255,0)');
        ctx.fillStyle = g; ctx.fillRect(cx + jx - r * 2, cy + jy - r * 2, r * 4, r * 4);
        ctx.fillStyle = '#1a1024'; ctx.fillRect(snap(cx + jx - 4), snap(cy + jy - 2), 2, 3); ctx.fillRect(snap(cx + jx + 2), snap(cy + jy - 2), 2, 3);   // two dark eyes
      } else {
        const im = f.ghost ? H.ghost : H.im, fw = im.width / H.frames;
        const frame = H.frames > 1 ? (aiming ? [0, 1, 2, 1][Math.floor(t * 22 + k) % 4] : Math.floor(t * 24 + k) % 2 ? 3 : 1) : 0;
        const still = name === 'drone-big' ? 0.4 : 1;
        sheet(ctx, im, H.frames, frame, snap(cx + jx * still - fw / 2), snap(cy + jy * still - im.height / 2));
        if (name === 'wasp') { ctx.fillStyle = 'rgba(235,245,255,.55)'; ctx.fillRect(snap(cx + jx - 4), snap(cy + jy - im.height / 2 - 2 + (Math.floor(t * 30) % 2) * 2), 10, 2); }
      }
      ctx.globalAlpha = 1;
    });
  }

  for (const q of run.parts) {
    if (q.coin !== undefined) {                        // the temple's gold thrown out by the blast
      const f = meta.coin.frames, fw = IMG.coin.width / f;
      ctx.globalAlpha = 1;
      sheet(ctx, IMG.coin, f, Math.floor(t * 16 + q.coin) % f, sx(q.x) - (fw >> 1), n(q.y) - (IMG.coin.height >> 1));
      continue;
    }
    if (q.shard !== undefined) {                       // a quarter of the smashed scenery's own picture, spinning
      const im = DECOR[q.biome], hw = im.width / 2, hh = im.height / 2;
      ctx.globalAlpha = Math.min(1, 3 * (1 - q.life / q.max));
      ctx.save(); ctx.translate(sx(q.x), n(q.y)); ctx.rotate(q.rot); soft(ctx);
      ctx.drawImage(im, (q.shard % 2) * hw, (q.shard >> 1) * hh, hw, hh, -hw / 2, -hh / 2, hw, hh);
      ctx.restore();
      continue;
    }
    ctx.globalAlpha = 1 - q.life / q.max; ctx.fillStyle = q.c;
    const s = Math.max(1, Math.round(q.s / PIXEL));
    ctx.fillRect(sx(q.x), n(q.y), s, s);
  }
  ctx.globalAlpha = 1;

  for (const m of run.monkeys) {                       // up in the vines at the top of the frame; they wave once greeted
    const fw = IMG.monkey.width / 2, greeted = m.seen !== undefined && run.t - m.seen < 2.5;
    const frame = Math.floor(t * (greeted ? 7 : 1.6) + m.ph) % 2;
    ctx.drawImage(IMG.monkey, frame * fw, 0, fw, IMG.monkey.height, sx(m.x) - (fw >> 1), greeted ? -2 + (frame ? 3 : 0) : -2, fw, IMG.monkey.height);
  }

  // closest layer: weather, then the leaves along the bottom and top edges. The faster the run, the
  // fainter these leaves: they race past the eye and would hide what is coming.
  drawWeather(ctx, cam, t, v.w);
  ctx.globalAlpha = 1 - 0.7 * fast;
  if (run.prevBiome !== run.biome && edge > 0 && edge < v.w) {
    ctx.save(); ctx.beginPath(); ctx.rect(0, -8, edge, VH + 16); ctx.clip(); edges(ctx, SCENE[run.prevBiome].fore, cam, t, v.w); ctx.restore();
    ctx.save(); ctx.beginPath(); ctx.rect(edge, -8, v.w, VH + 16); ctx.clip(); edges(ctx, now.fore, cam, t, v.w); ctx.restore();
  } else edges(ctx, (edge >= v.w ? SCENE[run.prevBiome] : now).fore, cam, t, v.w);
  ctx.globalAlpha = 1;
  ctx.restore();

  if (run.boom > 0) { ctx.fillStyle = `rgba(255,244,214,${run.boom * 0.8})`; ctx.fillRect(0, 0, v.w, VH); }
  if (run.flash > 0) { ctx.fillStyle = `rgba(255,70,90,${run.flash * 0.3})`; ctx.fillRect(0, 0, v.w, VH); }
  if (run.slow.t > 0) { ctx.fillStyle = 'rgba(120,200,255,.16)'; ctx.fillRect(0, 0, v.w, VH); }
  if (run.glitch > 0) {                                // time tear
    const g = run.glitch;
    ctx.fillStyle = `rgba(255,255,255,${g * 0.45})`; ctx.fillRect(0, 0, v.w, VH);
    ctx.fillStyle = `rgba(92,242,224,${g * 0.5})`;
    for (let k = 0; k < 6; k++) ctx.fillRect(0, Math.round(Math.random() * VH), v.w, 1 + Math.round(Math.random() * 6));
  }
}
