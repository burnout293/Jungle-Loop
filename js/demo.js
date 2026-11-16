// The animated preview of an upgrade, in the Améliorations screen.
// Not a video: a real, tiny run of the game with only that upgrade on, a hand-placed stretch of
// jungle and a scripted player, restarted every five seconds. It always shows the real behaviour.

import { newRun, update, addDecor, addSpiky, addHover, LOW, HEAD, coinLine, GROUND, PX, PIXEL, PPM, HANG_Y, LOG } from './game.js';
import { draw, quality } from './render.js';

const LOOP = 5;                                  // seconds
const START = 4000;                              // far from the temple, which only stands at the origin
export const DEMO_W = 284, DEMO_H = 170;         // art pixels shown: the bottom of the play area

// For each upgrade: `build` places what the hero will meet (x is counted from where he starts),
// `play` decides the input from the distance to the next obstacle (`ahead`) and the time `t`.
const SCENES = {
  doubleJump: {
    build(run, x) { addHover(run, x + 760, HEAD); addHover(run, x + 760, LOW); coinLine(run, x + 700, GROUND - 215, 5); addHover(run, x + 1500, HEAD); addHover(run, x + 1500, LOW); },
    play: (run, ahead, t, inp) => {
      const p = run.p;
      if (p.ground && ahead < 200) inp.pressed = true;                      // short hops, so it stays in frame
      else if (!p.ground && p.jumps === 1 && p.vy > -120) inp.pressed = true;
    },
  },
  magnet: {
    build(run, x) { coinLine(run, x + 450, GROUND - 125, 8); coinLine(run, x + 950, GROUND - 40, 6); coinLine(run, x + 1350, GROUND - 125, 8); },
    play: () => {},
  },
  breaker: {
    build(run, x) { addDecor(run, x + 600); addDecor(run, x + 950); addDecor(run, x + 1400); },
    play: () => {},
  },
  dash: {
    build(run, x) { addSpiky(run, x + 760); addSpiky(run, x + 860); addSpiky(run, x + 960); },
    play: (run, ahead, t, inp) => { if (ahead < 130) inp.dash = true; },
  },
  slow: {
    build(run, x) { addSpiky(run, x + 800); addSpiky(run, x + 1250); addHover(run, x + 1900, HEAD); },
    play: (run, ahead, t, inp) => {
      if (t > 0.7 && t < 0.8) inp.slow = true;
      const next = run.obs.find((o) => o.kind === 'spiky' && o.x + o.w > run.cam + run.sx);
      if (run.p.ground && next && next.x - run.cam - run.sx < 120) inp.pressed = true;
    },
  },
  flight: {
    build(run, x) { addHover(run, x + 900, LOW); addHover(run, x + 900, HEAD); coinLine(run, x + 840, GROUND - 215, 5); },
    play: (run, ahead, t, inp) => {
      const p = run.p, near = ahead < 330 && ahead > -90;
      if (p.ground && near) inp.pressed = true;                             // one press on foot: a jump
      else if (!p.ground && near && !p.rotor && p.vy > -150 && p.y > GROUND - 200) inp.pressed = true;   // one press in the air: up he goes
      inp.hold = near && p.y > GROUND - 230;                                // let go above the wall: he drops
    },
  },
  spring: {
    build(run, x) { addSpiky(run, x + 760); coinLine(run, x + 700, GROUND - 235, 5); addSpiky(run, x + 1500); },
    play: (run, ahead, t, inp) => { if (run.p.ground && ahead < 190) inp.pressed = true; inp.hold = true; },
  },
  sprint: {
    build(run, x) { coinLine(run, x + 450, GROUND - 40, 10); coinLine(run, x + 1200, GROUND - 40, 10); coinLine(run, x + 1950, GROUND - 40, 10); },
    play: () => {},
  },
  sphere: {
    build(run, x) {
      run.zones.push({ x: x + 520, w: LOG.w, kind: 'log' });
      for (let i = 0; i < 9; i++) run.coins.push({ x: x + 600 + i * 40, y: GROUND - 24, tight: 'log', gem: i % 6 === 3 ? 'r' : undefined });
    },
    play: () => {},
  },
  scatter: {
    build(run, x) { for (let k = 0; k < 4; k++) { coinLine(run, x + 400 + k * 480, GROUND - 40, 8); run.coins[run.coins.length - 3 - k].gem = 'yrby'[k]; } },
    play: () => {},
  },
  lucky: {
    build(run, x) { for (let k = 0; k < 5; k++) { coinLine(run, x + 400 + k * 380, GROUND - 40, 4); run.coins.push({ x: x + 620 + k * 380, y: GROUND - 60, gem: true }); } },
    play: () => {},
  },
  heart: {
    build(run, x) { addSpiky(run, x + 600); addSpiky(run, x + 1500); },
    play: () => {},
  },
  drunk: {
    build(run, x) { addSpiky(run, x + 600); addSpiky(run, x + 1000); addHover(run, x + 1700, LOW); for (const o of run.obs) o.ghost = true; },
    play: () => {},
  },
  nature: {
    build(run, x) { run.items.push({ x: x + 520, kind: 'rhino', ph: 0 }); addDecor(run, x + 1000); addDecor(run, x + 1500); coinLine(run, x + 1000, GROUND - 40, 14); for (const o of run.obs) o.ghost = false; },
    play: () => {},
  },
  lastLeap: {
    build(run, x) { run.hearts = 1; addSpiky(run, x + 600); for (const o of run.obs) o.ghost = false; },
    play: () => {},
  },
  // the mounts, shown from the Montures family: the animal waits a few steps ahead
  'm-gorilla': {
    build(run, x) { run.items.push({ x: x + 300, kind: 'gorilla', ph: 0 }); coinLine(run, x + 900, HANG_Y - 50, 12); addSpiky(run, x + 1100); },
    play: (run, ahead, t, inp) => {                    // up to the vines in two jumps, along them, then down
      for (const [k, at] of [['a', 1.3], ['b', 1.55], ['c', 3.9]]) if (t > at && !run['_' + k]) { run['_' + k] = true; inp.pressed = true; }
    },
  },
  'm-rhino': {
    build(run, x) { run.items.push({ x: x + 300, kind: 'rhino', ph: 0 }); addDecor(run, x + 900); addDecor(run, x + 1400); coinLine(run, x + 800, GROUND - 40, 18); for (const o of run.obs) o.ghost = false; },
    play: () => {},
  },
  'm-dragonfly': {
    build(run, x) { run.items.push({ x: x + 300, kind: 'dragonfly', ph: 0 }); for (let i = 0; i < 24; i++) run.coins.push({ x: x + 700 + i * 44, y: GROUND - 160 - Math.sin(i * 0.45) * 90 }); },
    play: (run, ahead, t, inp) => { inp.hold = Math.sin(t * 3.2 - 1.4) > 0; },
  },
  jammer: {                                    // the one change of scenery, the relic flickering
    build(run, x) { run.nextBiomeAt = START / PPM + 1; coinLine(run, x + 450, GROUND - 40, 10); coinLine(run, x + 1300, GROUND - 40, 10); },
    play: () => {},
  },
  rewind: {
    build(run, x) { run.hearts = 1; addSpiky(run, x + 760); addSpiky(run, x + 1500); },
    play: (run, ahead, t, inp) => { if (run.p.ground && run.rewindLeft === 0 && ahead < 120) inp.pressed = true; },
  },
};

let run = null, scene = null, clock = 0, shown = '', level = 1;

function restart() {
  run = newRun({ [shown]: level });
  run.cam = START; run.sx = PX; run.viewW = DEMO_W * PIXEL;
  run.nextX = run.nextFM = Infinity;             // nothing random: only what the scene places
  scene.build(run, START + PX);
  clock = 0;
}

// Call when another upgrade is selected (or its level changes).
export function showDemo(id, lvl) {
  if (!SCENES[id]) return;
  shown = id; level = Math.max(1, lvl); scene = SCENES[id];
  restart();
}

export function drawDemo(ctx, dt, t) {
  if (!run) return;
  if ((clock += dt) > LOOP) restart();
  const px = run.cam + run.sx, next = run.obs.find((o) => o.x + o.w > px - 20);
  const inp = { pressed: false, hold: false, dash: false, slow: false };
  scene.play(run, next ? next.x - px : Infinity, clock, inp);
  update(run, dt, inp);
  run.events.length = 0;                         // silent, and it earns nothing
  const q = quality();
  ctx.setTransform(q, 0, 0, q, 0, (DEMO_H - Math.round(720 / PIXEL)) * q);   // keep the floor at the bottom
  draw(ctx, run, { w: DEMO_W, top: 0 }, t);
}
