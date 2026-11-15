// Life in the scenery: birds, butterflies, small animals, falling leaves, gusts of wind, rain,
// pebbles dropping from the ruins. None of it touches the game rules — it is drawn, nothing more —
// and it runs behind the menus as well as during a run.
// All coordinates are art pixels, like in render.js.

import { GROUND, PIXEL, VIEW_H } from './game.js';

const GN = Math.round(GROUND / PIXEL), VH = Math.round(VIEW_H / PIXEL);
const h01 = (i, s) => { const x = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); };
const mod = (a, n) => ((a % n) + n) % n;
const ramp = (x, a, b) => Math.min(1, Math.max(0, (x - a) / (b - a)));

// Weather, as plain functions of time. A gust rises about every 14 seconds;
// a shower lasts half a minute out of every minute and a half.
export const gust = (t) => Math.max(0, Math.sin(t * 0.45)) ** 8;
export const rain = (t) => { const c = mod(t, 90); return ramp(c, 48, 54) * (1 - ramp(c, 74, 80)); };

// The little that has to be remembered from one frame to the next.
let lastT = 0, wind = 0, stones = [], nextStone = 4;
let floorY = () => GN;                                 // floor height at a screen x, given by the renderer
let Q = 1;                                             // drawing steps per art pixel, set by the renderer
export function setStep(q) { Q = q; }
const snap = (v) => Math.round(v * Q) / Q;

function tick(t, cam, w) {
  const dt = Math.min(0.1, Math.max(0, t - lastT));
  lastT = t;
  wind += dt * (14 + 80 * gust(t));                    // how far the air has travelled: leaves ride on it
  if (t > nextStone) {                                 // a few pebbles come loose somewhere ahead
    nextStone = t + 7 + Math.random() * 8;
    const x = cam + w * (0.25 + Math.random() * 0.7), y = floorY(x - cam) - 170 + Math.random() * 60;
    for (let k = 0; k < 3; k++) stones.push({ x: x + k * 5 - 5, y: y - k * 7, vy: 0, vx: (Math.random() - 0.5) * 16, life: 0, hops: 0 });
  }
  for (const s of stones) {
    s.life += dt; s.vy += 420 * dt; s.x += s.vx * dt; s.y += s.vy * dt;
    const f = floorY(s.x - cam);
    if (s.y > f - 3 && s.vy > 0) { s.y = f - 3; s.vy *= -0.35; s.hops++; }
  }
  stones = stones.filter((s) => s.hops < 3 && s.life < 4);
}

// ---------- far away: birds crossing the sky ----------
export function drawSky(ctx, t, w) {
  for (let f = 0; f < 3; f++) {
    const span = w + 300 + f * 140;
    const x0 = w + 40 - mod(t * (9 + f * 5) + f * 190, span);
    const y0 = 34 + f * 24 + Math.sin(t * 0.3 + f) * 6;
    ctx.fillStyle = ['#f2f8ff', '#3a4a6e', '#2a3350'][f];
    for (let j = 0; j < 3 + f; j++) {
      const x = Math.round(x0 + j * 9), y = Math.round(y0 + Math.abs(j - 1) * 4 + Math.sin(t * 2 + j));
      const up = Math.floor(t * 5 + j * 0.7) % 2 ? -1 : 1;          // wings up, wings down
      ctx.fillRect(x, y, 2, 1);
      ctx.fillRect(x - 2, y + (up < 0 ? -1 : 0), 2, 1); ctx.fillRect(x + 2, y + (up < 0 ? -1 : 0), 2, 1);
      ctx.fillRect(x - 3, y + up * (up < 0 ? 2 : 1), 1, 1); ctx.fillRect(x + 4, y + up * (up < 0 ? 2 : 1), 1, 1);
    }
  }
}

// ---------- on and above the floor, behind the action ----------
const WINGS = ['#ff9d3c', '#5ce0f2', '#ff6fa8', '#f6e65a', '#c58cff'];

function butterflies(ctx, cam, t, w) {
  const span = w + 60;
  for (let i = 0; i < 6; i++) {
    const x = snap(mod(h01(i, 13) * span - cam * 0.9 + t * (h01(i, 17) - 0.5) * 12 + Math.sin(t * 0.9 + i * 2) * 14, span)) - 30;
    const y = Math.round(floorY(x) - 26 - h01(i, 19) * 70 + Math.sin(t * 1.3 + i) * 9 + Math.sin(t * 3.1 + i * 4) * 3);
    ctx.fillStyle = WINGS[i % WINGS.length];
    if (Math.floor(t * 9 + i) % 2) { ctx.fillRect(x - 2, y - 1, 2, 3); ctx.fillRect(x + 1, y - 1, 2, 3); }
    else { ctx.fillRect(x - 1, y - 2, 1, 3); ctx.fillRect(x + 1, y - 2, 1, 3); }
    ctx.fillStyle = '#1a1024'; ctx.fillRect(x, y - 1, 1, 3);
  }
}

// Small animals pottering about on the moss. Each has a home spot in the world and strolls around it.
function critters(ctx, cam, t, w) {
  const CELL = 230, first = Math.floor(cam / CELL) - 1, last = Math.floor((cam + w) / CELL) + 1;
  for (let i = Math.max(1, first); i <= last; i++) {
    if (h01(i, 71) < 0.4) continue;
    const walk = Math.sin(t * 0.4 + i * 3) * 36, dir = Math.cos(t * 0.4 + i * 3) > 0 ? 1 : -1;
    const x = snap(i * CELL + 60 + walk - cam), step = Math.floor(t * 8 + i) % 2;
    if (h01(i, 73) < 0.5) {                            // a scarab with a shiny shell
      const y = floorY(x) - 6;
      ctx.fillStyle = '#1a1024'; ctx.fillRect(x - 1, y, 8, 4);
      ctx.fillStyle = '#23b39a'; ctx.fillRect(x, y, 5, 3);
      ctx.fillStyle = '#a8fff0'; ctx.fillRect(x + 1, y, 2, 1);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(dir > 0 ? x + 5 : x - 1, y + 1, 2, 2);
      ctx.fillRect(x + step, y + 4, 1, 1); ctx.fillRect(x + 2 + step, y + 4, 1, 1); ctx.fillRect(x + 4 + step, y + 4, 1, 1);
    } else {                                           // a small bird hopping along
      const y = floorY(x) - 9 - (step ? 1 : 0);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(x - 1, y - 1, 8, 7);
      ctx.fillStyle = '#ffb347'; ctx.fillRect(x, y, 6, 5);
      ctx.fillStyle = '#fff3c4'; ctx.fillRect(x + 1, y + 3, 4, 2);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(dir > 0 ? x + 4 : x + 1, y + 1, 1, 1);
      ctx.fillStyle = '#e0456b'; ctx.fillRect(dir > 0 ? x + 6 : x - 2, y + 2, 2, 1);
      ctx.fillStyle = '#1a1024'; ctx.fillRect(x + 1 + step, y + 6, 1, 2); ctx.fillRect(x + 4 - step, y + 6, 1, 2);
    }
  }
}

function fireflies(ctx, cam, t, w) {
  const span = w + 40;
  for (let i = 0; i < 14; i++) {
    const x = snap(mod(h01(i, 3) * span - cam * 0.7 + t * (3 + h01(i, 5) * 6), span)) - 20;
    const y = Math.round(50 + h01(i, 7) * 190 + Math.sin(t * 0.8 + i * 2.1) * 9);
    const glow = Math.sin(t * 1.7 + i * 1.3) ** 2;
    ctx.globalAlpha = glow * 0.22; ctx.fillStyle = '#d9ff7a'; ctx.fillRect(x - 1, y - 1, 3, 3);
    ctx.globalAlpha = 0.35 + glow * 0.65; ctx.fillStyle = '#f6ffc4'; ctx.fillRect(x, y, 1, 1);
  }
  ctx.globalAlpha = 1;
}

export function drawLife(ctx, cam, t, w, floor) {
  if (floor) floorY = floor;
  tick(t, cam, w);
  fireflies(ctx, cam, t, w);
  for (const s of stones) {
    const x = snap(s.x - cam), y = Math.round(s.y);
    ctx.fillStyle = '#1a1024'; ctx.fillRect(x - 1, y - 1, 4, 4);
    ctx.fillStyle = '#9aa0b8'; ctx.fillRect(x, y, 2, 2);
    if (s.hops && s.life < 4) { ctx.globalAlpha = 0.5; ctx.fillStyle = '#e8e4d4'; ctx.fillRect(x - 3, y + 1, 2, 1); ctx.fillRect(x + 3, y, 2, 1); ctx.globalAlpha = 1; }
  }
  critters(ctx, cam, t, w);
  butterflies(ctx, cam, t, w);
}

// ---------- in front of everything: leaves on the wind, gusts, rain ----------
const LEAVES = ['#8fd14a', '#c9e86a', '#e8c84a', '#5fae3a'];

export function drawWeather(ctx, cam, t, w) {
  const g = gust(t), r = rain(t), span = w + 40;

  for (let i = 0; i < 18; i++) {
    const x = snap(mod(h01(i, 23) * span - wind * (0.6 + h01(i, 29)) - cam * 1.1, span) + Math.sin(t * 2 + i) * 4) - 20;
    const y = Math.round(mod(h01(i, 31) * (GN + 10) + t * (9 + h01(i, 37) * 9), GN + 10));
    ctx.fillStyle = LEAVES[i % LEAVES.length];
    if (Math.floor(t * 4 + i) % 2) ctx.fillRect(x, y, 2, 1); else ctx.fillRect(x, y, 1, 2);
  }

  if (g > 0.04) {                                      // the gust itself: a few pale streaks racing by
    ctx.fillStyle = '#ffffff'; ctx.globalAlpha = g * 0.4;
    for (let i = 0; i < 7; i++) {
      const len = 14 + Math.round(h01(i, 41) * 24);
      const x = Math.round(mod(h01(i, 43) * (span + 200) - wind * 5, span + 200)) - 60;
      const y = Math.round(40 + h01(i, 47) * 210 + Math.sin(x * 0.03 + i) * 4);
      ctx.fillRect(x, y, len, 1); ctx.fillRect(x - 3, y + 1, 4, 1);
    }
    ctx.globalAlpha = 1;
  }

  if (r > 0) {
    ctx.fillStyle = `rgba(22,36,78,${0.26 * r})`; ctx.fillRect(0, 0, w, VH);     // the light drops under the clouds
    ctx.fillStyle = 'rgba(205,228,255,.6)';
    const H = VH + 20, n = Math.round(110 * r);
    for (let i = 0; i < n; i++) {
      const q = mod(h01(i, 53) * H + t * (380 + h01(i, 59) * 140), H);
      const x = Math.round(mod(h01(i, 61) * (w + 90) - q * 0.28 - cam * 0.4, w + 90)) - 10;
      if (q > GN - 5 && h01(i, 67) > 0.4) { ctx.fillRect(x - 1, GN - 4, 1, 1); ctx.fillRect(x + 1, GN - 5, 1, 1); ctx.fillRect(x + 3, GN - 4, 1, 1); }
      else { ctx.fillRect(x, Math.round(q), 1, 3); ctx.fillRect(x - 1, Math.round(q) + 3, 1, 2); }
    }
  }
}

// Draws an image in thin horizontal bands, the top ones pushed sideways by the wind:
// the plant bends from its foot instead of sliding as a block.
export function swayBlit(ctx, im, x, y, flip, t, seed, amp) {
  const k = amp * (1 + 2.5 * gust(t)), h = im.height;
  ctx.save();
  ctx.translate(flip ? x + im.width : x, y);
  if (flip) ctx.scale(-1, 1);
  for (let b = 0; b < h; b += 4) {
    const dx = Math.round(Math.sin(t * 1.7 + seed + b * 0.06) * k * (1 - b / h) ** 1.5), bh = Math.min(4, h - b);
    ctx.drawImage(im, 0, b, im.width, bh, flip ? -dx : dx, b, im.width, bh);
  }
  ctx.restore();
}
