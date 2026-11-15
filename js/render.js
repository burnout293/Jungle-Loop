// Everything drawn on the canvas, from the pixel-art assets in assets/img.
// Every coordinate here is in art pixels: logical units from game.js divided by PIXEL. The canvas
// holds Q x Q real pixels for each art pixel (see setQuality): sprites keep their sharp squares,
// but they can stand and scroll at any Q-th of a pixel, which is what keeps a fast run steady,
// and the browser smooths the picture's edges when it fits the canvas to the screen.

import { GROUND, PIXEL, VIEW_H, PROP, PROP_CELL as CELL_UNITS, FM, MOUNTS, LOG, GALLERY, propAt, floorAt, flatAt, biomeAt } from './game.js';
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

const DIR = 'assets/img/';
const NAMES = ['fore', 'temple', 'hero-body', 'hero-ball', 'hero-rotor', 'hero-fist', 'hero-shoe', 'mount-gorilla', 'mount-gorilla-hang', 'mount-rhino', 'mount-moskito', 'mosquito', 'fly', 'spiky', 'coin', 'gem', 'gem-y', 'gem-r', 'gem-b', 'heart', 'monkey'];
const IMG = {};
let meta = {
  fly: { frames: 1 }, coin: { frames: 1 }, mosquito: { frames: 4 },
  rig: { body: { w: 39, h: 40, hx: 30, hy: 24, tx: 26 }, rotor: { w: 58, h: 34, hx: 28, hy: 16, tx: 29, blade: 12 }, fist: { w: 8, h: 8 }, shoe: { w: 12, h: 9 } },
  mounts: { gorilla: { frames: 4, seatX: 41, seatY: 21 }, rhino: { frames: 4, seatX: 41, seatY: 20 }, moskito: { frames: 4, seatX: 33, seatY: 39 },
    'gorilla-hang': { frames: 4, seatX: 46, seats: [[28, 54], [32, 59], [33, 56], [32, 52]] } },
};
let SCENE = [];                                        // per scenery, what is ready to draw (see buildScene)
let HAZ = {};                                          // what hurts, outlined so it stands out, and its harmless ghost
let FAR = {};                                          // the hero's far fist and shoe, in the shade of his body
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
const baked = async (im) => { try { return im && window.createImageBitmap ? await createImageBitmap(im) : im; } catch { return im; } };

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
  for (const [k, frames] of [['spiky', 1], ['fly', meta.fly.frames], ['mosquito', meta.mosquito.frames]])
    HAZ[k] = { im: rim(IMG[k], frames), ghost: rim(tinted(IMG[k], 'rgba(110,215,255,.55)'), frames, '#d8f6ff'), frames };
  FAR = { fist: tinted(IMG['hero-fist'], 'rgba(16,12,40,.38)'), shoe: tinted(IMG['hero-shoe'], 'rgba(16,12,40,.38)') };
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
// The colour of the first solid pixel found on a row of an image (row < 0 counts from the bottom).
function rowColour(im, row, fallback) {
  if (!im) return fallback;
  const c = canvasOf(im.width, 1).getContext('2d');
  c.drawImage(im, 0, row < 0 ? im.height + row : row, im.width, 1, 0, 0, im.width, 1);
  const d = c.getImageData(0, 0, im.width, 1).data;
  for (let x = im.width >> 1; x < im.width; x++) if (d[x * 4 + 3] > 200) return `rgb(${d[x * 4]},${d[x * 4 + 1]},${d[x * 4 + 2]})`;
  return fallback;
}

const DIM = 'rgba(16,12,40,.3)';                       // the veil over scenery that stands where obstacles do

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
  let fore = IMG.fore;
  if (fore && b.shade) fore = tinted(fore, b.shade);   // elsewhere than the jungle the edge leaves are plain shadows
  // Props and pillars stand on the path, right where crates and creatures do, but are only there to
  // be looked at: they are darkened a little so the eye does not take them for something to dodge.
  const props = [];
  for (let i = 0; i < b.props; i++) props.push(tinted(IMG[b.prop + i], DIM));
  return {
    platform: IMG[b.platform], pillar: tinted(IMG[b.pillar], DIM), crate: IMG[b.crate], stacks: [], slab: IMG[b.slab], tunnel: shortened(IMG[b.tunnel], Math.round(LOG.w / PIXEL)),
    platTop: b.platTop, slabTop: b.slabTop, hollow: b.hollow,
    bg: IMG[b.bg], mid: IMG[b.mid], ground: { pieces, len, soil: rowColour(kinds[0], -2, '#2a1c2c') }, props, fore,
    sky: rowColour(IMG[b.bg], 0, '#7fb9ec'), base: rowColour(IMG[b.mid], -1, '#1c2c3a'),
  };
}

// A pile of `count` crates as one outlined picture, made the first time it is needed.
function stack(S, count) {
  if (!S.stacks[count]) {
    const im = S.crate, c = canvasOf(im.width, count * (im.height - 1) + 1), x = c.getContext('2d');
    for (let k = 0; k < count; k++) x.drawImage(im, 0, k * (im.height - 1));
    S.stacks[count] = rim(c);
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
        const y = out ? null : n(floorAt(run, (cam + px + k + Math.min(SLICE, w - k) / 2) * PIXEL)) - 4;
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

function drawProps(ctx, run, cam, width, t) {
  const first = Math.floor(cam / PROP_CELL) - 1, last = Math.floor((cam + width) / PROP_CELL) + 1;
  for (let i = first; i <= last; i++) {
    const pr = propAt(i);
    if (!pr || !flatAt(run, pr.x, CELL_UNITS * 0.6)) continue;        // nothing grows on a slope
    const biome = biomeAt(run, pr.x), set = SCENE[biome].props, im = set[pr.kind % set.length];
    if (!im) continue;
    const x = snap(pr.x / PIXEL - cam), y = n(floorAt(run, pr.x)) - im.height + 3;
    if (biome) { blit(ctx, im, x, y, pr.flip); continue; }
    // brushed by the hero a moment ago: it shakes hard, then settles
    const since = run.touched.has(i) ? run.t - run.touched.get(i) : 9, shiver = since < 1 ? 1 - since : 0;
    if (shiver) swayBlit(ctx, im, x, y, pr.flip, t * 7, i, 5 * shiver);
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

// The leaves that close the frame: a strip along the bottom edge and the same strip turned upside
// down along the top, both swaying and moving faster than the floor.
function edges(ctx, im, cam, t, width) {
  if (!im) return;
  const off = cam * 1.35;
  for (let i = Math.floor(off / im.width); i * im.width - off < width; i++)
    swayBlit(ctx, im, snap(i * im.width - off), VH - im.height + 26, i & 1, t, 0, 2.5, 8);
  const top = cam * 1.2 + 230;
  ctx.save(); ctx.translate(0, 30); ctx.scale(1, -1);
  for (let i = Math.floor(top / im.width); i * im.width - top < width; i++)
    swayBlit(ctx, im, snap(i * im.width - top), 0, i & 1, t, 2, 2, 8);
  ctx.restore();
}

// Two sceneries meet at `edge` (screen x). Each is painted on a spare canvas and made to fade out,
// or in, across `soft` pixels on each side of the edge: the new place grows out of the old one
// instead of switching on.
function blend(ctx, run, v, edge, soft, paint) {
  const A = SCENE[run.prevBiome], B = SCENE[run.biome];
  if (A === B || edge <= -soft) { paint(ctx, B); return; }
  if (edge - soft >= v.w) { paint(ctx, A); return; }
  const q = Math.min(Q, 2), W = Math.ceil(v.w * q), H = VH * q;      // far scenery, mid-fade: half the detail is plenty
  if (!scratch || scratch.width !== W || scratch.height !== H) scratch = canvasOf(W, H);
  const s = scratch.getContext('2d');
  s.setTransform(q, 0, 0, q, 0, 0); s.imageSmoothingEnabled = false;
  const g = s.createLinearGradient(edge - soft, 0, edge + soft, 0);
  g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, '#000');
  // the old one fades out to the right of the edge, the new one fades in: both have see-through parts
  for (const [S, op] of [[A, 'destination-out'], [B, 'destination-in']]) {
    s.globalCompositeOperation = 'source-over'; s.clearRect(0, 0, v.w + 1, VH);
    paint(s, S);
    s.globalCompositeOperation = op; s.fillStyle = g; s.fillRect(0, 0, v.w + 1, VH);
    ctx.drawImage(scratch, 0, 0, W / q, VH);
  }
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
  if (!rot) { ctx.drawImage(im, snap(cx - im.width / 2), snap(cy - im.height / 2)); return; }
  ctx.save(); ctx.translate(cx, cy); ctx.rotate(rot); soft(ctx); ctx.drawImage(im, -im.width / 2, -im.height / 2); ctx.restore();
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
    ctx.drawImage(im, -im.width / 2, -im.height / 2);
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
    ctx.drawImage(body, 0, 0, B.w, B.blade, snap(B.hx - B.tx - B.hx * w), -B.h, snap(bw), B.blade);
    ctx.drawImage(body, 0, B.blade, B.w, B.h - B.blade, -B.tx, -B.h + B.blade, B.w, B.h - B.blade);
  } else ctx.drawImage(body, snap(-B.tx), -B.h);
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
const LOG_ROOF = 30, LOG_FLOOR = 68, LOG_WINDOW = 54, LOG_RIB = 20;
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
  blend(ctx, run, v, edge, 150, (c, S) => { if (S.bg) strip(c, S.bg, cam * 0.18, VH - S.bg.height, v.w); });
  drawSky(ctx, t, v.w);
  blend(ctx, run, v, edge, 70, (c, S) => {
    if (!S.mid) return;
    const y = GN + 20 - S.mid.height;
    strip(c, S.mid, cam * 0.5, y, v.w);
    c.fillStyle = S.base; c.fillRect(0, y + S.mid.height, v.w, VH);  // seen only where the path dips
  });

  drawProps(ctx, run, cam, v.w, t);
  const cut = Math.max(0, Math.min(v.w, edge));        // the floor changes exactly where the new place begins
  if (run.prevBiome !== run.biome) drawGround(ctx, run, SCENE[run.prevBiome].ground, cam, 0, cut, VH + 8);
  drawGround(ctx, run, now.ground, cam, run.prevBiome !== run.biome ? cut : 0, v.w, VH + 8);
  drawLife(ctx, cam, t, v.w, floorPx);

  const templeX = snap(TEMPLE_X - cam), inTemple = IMG.temple && templeX > -IMG.temple.width;
  if (inTemple) ctx.drawImage(IMG.temple, templeX, GN - IMG.temple.height + 3);
  if (inTemple && run.exploded) drawBlast(ctx, templeX);

  if (inTemple && !run.exploded) {                     // the way out is walled up with fallen stones, until the blast
    for (let r = 0; r < 6; r++) for (let k = 0; k < 4; k++) {
      const w = 9 + Math.round(h01(r * 4 + k, 91) * 5), bx = templeX + 82 + k * 11 + (r & 1 ? 4 : 0) + Math.round(h01(r * 4 + k, 93) * 3), by = GN - 14 - r * 11 - Math.round(h01(r * 4 + k, 95) * 3);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(bx - 1, by - 1, w + 2, 12);
      ctx.fillStyle = ['#6a6f8c', '#8a8fa8', '#4a4f6c', '#7a7f9a'][(r + k) % 4]; ctx.fillRect(bx, by, w, 10);
      ctx.fillStyle = 'rgba(255,255,255,.18)'; ctx.fillRect(bx, by, w, 2);
      if (h01(r * 4 + k, 97) > 0.7) { ctx.fillStyle = '#7bd13c'; ctx.fillRect(bx + 1, by - 1, 4, 2); }
    }
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
  for (const it of run.items) {
    const x = sx(it.x), f = floorPx(x), fly = MOUNTS[it.kind].fly, im = IMG['mount-' + it.kind];
    if (x > v.w + 60 || x < -80 || !im) continue;
    const foot = fly ? f - 34 + Math.round(Math.sin(t * 3 + it.ph) * 4) : f;             // the Moskito hovers
    const g = ctx.createRadialGradient(x + 10, foot - 28, 4, x + 10, foot - 28, 62);
    g.addColorStop(0, `rgba(255,224,120,${0.42 + 0.14 * Math.sin(t * 5)})`); g.addColorStop(1, 'rgba(255,224,120,0)');
    ctx.fillStyle = g; ctx.fillRect(x - 54, foot - 92, 128, 100);
    shadow(ctx, x + 12, f - 1, fly ? 30 : 64);
    drawMount(ctx, it.kind, fly ? Math.floor(t * 16) % 4 : 1, x, foot, fly ? 0 : Math.round(Math.sin(t * 3 + it.ph)));
    chevron(ctx, x + 6, foot - im.height - 6 - Math.round(Math.abs(Math.sin(t * 5)) * 6), 1, '#ffd35c', 6);
  }

  for (const o of run.obs) {
    const x = sx(o.x), y = n(o.y), foot = n(o.y + o.h);
    if (x > v.w + 10 || x < -80) continue;
    if (o.kind === 'crate') {
      const S = SCENE[biomeAt(run, o.x)], im = stack(S, o.n);
      shadow(ctx, x + im.width / 2 - 1, foot - 1, im.width + 2);
      ctx.drawImage(im, x - 1, foot - im.height + 1);
      continue;
    }
    const H = HAZ[o.kind], frame = o.kind === 'fly' ? Math.floor(t * 14 + o.ph) % H.frames : 0;
    if (o.ghost) {                                     // tipsy and harmless: pale, see-through, swaying, hiccuping bubbles
      const sway = Math.sin(t * 4 + o.x) * 2;
      ctx.globalAlpha = 0.78 + 0.1 * Math.sin(t * 6 + o.x);
      sheet(ctx, H.ghost, H.frames, frame, snap(x - 1 + sway), o.kind === 'fly' ? y - 1 : foot - H.ghost.height + 1);
      ctx.fillStyle = '#eafcff';
      for (let k = 0; k < 3; k++) { const up = (t * 14 + k * 9 + o.x) % 22; ctx.globalAlpha = 0.7 * (1 - up / 22); ctx.fillRect(x + 8 + k * 7 + Math.round(Math.sin(up * 0.6 + k) * 2), y - 2 - up, 2, 2); }
      ctx.globalAlpha = 1;
    } else if (o.kind === 'spiky') {
      shadow(ctx, x + IMG.spiky.width / 2, foot - 1, IMG.spiky.width);
      ctx.drawImage(H.im, x - 1, foot - IMG.spiky.height - 1 + (Math.sin(t * 6 + o.x) > 0.6 ? -1 : 0));
    } else {
      const f = floorPx(x + 16);
      shadow(ctx, x + 16, f - 1, Math.max(8, 22 - ((f - y) >> 4)));
      sheet(ctx, H.im, H.frames, frame, x - 1, y - 1);
    }
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
      else if (MOUNTS[M.kind].fly) s = drawMount(ctx, M.kind, Math.floor(t * 18) % 4, hx, n(p.y) + 8, 0);
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

  // the follower monsters: one mosquito per lane taken, a flashing band along each of those lanes, then the rush
  if (run.fm) {
    const f = run.fm, H = HAZ.mosquito, cx = n(f.sx), aiming = f.phase === 'aim';
    const fw = H.im.width / H.frames, step = n(FM.step), pulse = Math.sin(t * 12) ** 2;
    f.act.forEach((on, k) => {
      if (!on) return;
      const top = GN - (k + 1) * step, cy = top + step / 2;
      if (aiming && f.t > 0.3 && !f.ghost) {
        ctx.fillStyle = `rgba(255,70,70,${0.12 + 0.1 * pulse})`; ctx.fillRect(0, top + 3, cx - 24, step - 6);
        ctx.fillStyle = `rgba(255,96,96,${0.55 + 0.35 * pulse})`;
        for (let x = -((t * 60) % 16); x < cx - 24; x += 16) { ctx.fillRect(snap(x), top + 3, 9, 2); ctx.fillRect(snap(x), top + step - 5, 9, 2); }
      }
      if (f.ghost) ctx.globalAlpha = 0.78;
      const jx = Math.sin(t * 9 + k * 2.1) * 2.5, jy = Math.cos(t * 11 + k * 1.7) * 2.5;
      const frame = aiming ? [0, 1, 2, 1][Math.floor(t * 22 + k) % 4] : Math.floor(t * 24 + k) % 2 ? 3 : 1;
      sheet(ctx, f.ghost ? H.ghost : H.im, H.frames, frame, snap(cx + jx - fw / 2), snap(cy + jy - H.im.height / 2));
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
    if (q.shard !== undefined) {                       // a quarter of a crate's own picture, spinning
      const im = SCENE[q.biome].crate, hw = im.width / 2, hh = im.height / 2;
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
