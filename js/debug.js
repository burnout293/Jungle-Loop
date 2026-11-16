// The debug menu: opened by touching the level badge of the home screen five times in a row.
// Plain on purpose. It changes the save (coins, level, purchases), what the next runs start with,
// and a few of the game's numbers. Its own settings are kept on this device only.

import { SPEED, FROM, BOSS, JUMP, PPM, MOUNTS, GROUND, PX } from './game.js';
import { BIOMES } from './render.js';
import * as S from './save.js';
import * as P from './progress.js';

const KEY = 'jungle-loop-debug';
// The game's own numbers as they are written in game.js, before anything here changes them.
const ORIGIN = { base: SPEED.base, gain: SPEED.gain, sprint: SPEED.sprint, boss: BOSS.at, ...Object.fromEntries(Object.entries(FROM).map(([k, v]) => ['from_' + k, v])) };
const BLANK = { fps: false, info: false, god: false, start: 0, biome: 0, mount: '', fm: false, ...ORIGIN };
export const dbg = { ...BLANK };
// Only the game numbers changed by hand here are kept and applied: the others always follow game.js,
// even when a new version of the game changes them.
const changed = new Set();
try {
  const kept = JSON.parse(localStorage.getItem(KEY)) || {};
  for (const k of Array.isArray(kept.changed) ? kept.changed : []) if (k in ORIGIN) changed.add(k);
  for (const [k, v] of Object.entries(kept)) if (k in BLANK && typeof v === typeof BLANK[k] && (!(k in ORIGIN) || changed.has(k))) dbg[k] = v;
} catch { /* nothing kept */ }

function apply() {
  SPEED.base = dbg.base; SPEED.gain = dbg.gain; SPEED.sprint = dbg.sprint; BOSS.at = dbg.boss;
  for (const k of Object.keys(FROM)) FROM[k] = dbg['from_' + k];
  try { localStorage.setItem(KEY, JSON.stringify({ ...dbg, changed: [...changed] })); } catch { /* not kept */ }
}
apply();

// What the next run starts with: called by main.js right after the run is made.
export function debugRun(run) {
  run.god = dbg.god;
  if (dbg.biome) run.biome = run.prevBiome = dbg.biome;
  if (changed.has('boss')) run.bossAt = BOSS.at;       // a boss set by hand comes exactly there
  if (dbg.god || dbg.start || dbg.biome || dbg.mount || dbg.fm) run.events.push('debug');   // said on screen: nothing should look normal by mistake
  if (dbg.start > 0) {                                  // as if the first metres had already been run
    const D = dbg.start * PPM, g = SPEED.gain;
    run.t = g ? (-run.base + Math.sqrt(run.base * run.base + 2 * g * D)) / g : D / run.base;   // the speed it would have reached
    run.cam = D; run.dist = dbg.start; run.nextX = D + 1500;
    run.terrain = [{ x: -1e9, y: GROUND }];
    run.nextMount += dbg.start; run.nextFM += dbg.start;
  }
  if (dbg.mount) run.items.push({ x: run.cam + PX + 700, kind: dbg.mount, ph: 0 });
  if (dbg.fm) run.nextFM = run.dist + 40;
}

// ---------- the panel ----------

let host = null;      // { save, store, changed, fps } given by main.js

const tag = (name, props = {}, ...kids) => { const e = Object.assign(document.createElement(name), props); e.append(...kids); return e; };
const row = (label, ...kids) => tag('div', { className: 'row' }, tag('span', { textContent: label }), ...kids);
const num = (value, step = 1) => tag('input', { type: 'number', value, step });
const btn = (text, fn) => { const b = tag('button', { textContent: text }); b.addEventListener('click', fn); return b; };
const box = (key, after) => { const c = tag('input', { type: 'checkbox', checked: !!dbg[key] }); c.addEventListener('change', () => { dbg[key] = c.checked; apply(); if (after) after(); }); return c; };
const pickOne = (key, options) => {
  const s = tag('select', {}, ...options.map(([v, t]) => tag('option', { value: v, textContent: t })));
  s.value = String(dbg[key]); s.addEventListener('change', () => { dbg[key] = typeof BLANK[key] === 'number' ? Number(s.value) : s.value; apply(); });
  return s;
};
// A number of the game: typed in the unit shown, kept in the game's own (`k` units per shown unit).
const tune = (label, key, unit, k = 1, step = 1) => {
  const i = num(+(dbg[key] / k).toFixed(3), step);
  i.addEventListener('change', () => { const v = Number(i.value); if (Number.isFinite(v) && v >= 0) { dbg[key] = v * k; if (key in ORIGIN) changed.add(key); apply(); } });
  return row(label, i, tag('small', { textContent: unit + (key in ORIGIN ? ` (origine ${+(ORIGIN[key] / k).toFixed(3)})` : '') }));
};

// Speed and time at a given distance, from the numbers in force (and with the Sprint).
function calc() {
  const at = num(1000, 100), out = tag('small');
  const show = () => {
    const D = Math.max(0, Number(at.value) || 0) * PPM, g = SPEED.gain;
    const line = (b) => { const t = g ? (-b + Math.sqrt(b * b + 2 * g * D)) / g : D / b; return `${((b + g * t) / PPM).toFixed(1)} m/s après ${Math.floor(t / 60)} min ${Math.round(t % 60)} s`; };
    out.textContent = `à pied : ${line(SPEED.base)} · avec Sprint : ${line(SPEED.base + SPEED.sprint)}`;
  };
  at.addEventListener('input', show); show();
  return row('Vitesse à (m)', at, out);
}
// How high each jump goes, in metres, from the numbers of game.js (Ressort: +10 % of push per level).
function jumps() {
  const h = (v, g) => v * v / (2 * g) / PPM, f = (x) => x.toFixed(2) + ' m';
  const rows = [0, 1, 2].map((lvl) => {
    const k = 1 + 0.1 * lvl, v = JUMP.v * k, d = JUMP.double * k;
    return `${lvl ? 'Ressort ' + lvl : 'Sans Ressort'} : bref ${f(h(v, JUMP.gravity))}, maintenu ${f(h(v, JUMP.held))}, avec double saut jusqu'à ${f(h(v, JUMP.held) + h(d, JUMP.held))}`;
  });
  rows.push(`Montures : gorille ${f(h(-MOUNTS.gorilla.jump, JUMP.gravity))} (maintenu ${f(h(-MOUNTS.gorilla.jump, JUMP.held))}), rhino ${f(h(-MOUNTS.rhino.jump, JUMP.gravity))} (maintenu ${f(h(-MOUNTS.rhino.jump, JUMP.held))})`);
  return tag('div', {}, tag('div', { className: 'row' }, tag('span', { textContent: 'Hauteurs de saut' })), ...rows.map((r) => tag('div', { className: 'row' }, tag('small', { textContent: r }))));
}

function build() {
  const save = host.save();
  const coins = num(save.coins), level = num(P.levelInfo(save.xp).level);
  const say = tag('p', { className: 'say' });
  const done = (text) => { host.store(); host.changed(); say.textContent = text; };
  const panel = tag('div', { id: 'debug' },
    tag('div', { className: 'head' }, btn('Fermer', close), tag('b', { textContent: 'Debug' })),
    say,
    tag('h3', { textContent: 'Partie' }),
    row('Pièces', coins, btn('Appliquer', () => { host.save().coins = Math.max(0, Math.floor(Number(coins.value) || 0)); done('Pièces changées.'); })),
    row('Niveau', level, btn('Appliquer', () => {
      const want = Math.max(1, Math.floor(Number(level.value) || 1)); let xp = 0;
      while (P.levelInfo(xp).level < want) { const i = P.levelInfo(xp); xp += i.need - i.into; }
      host.save().xp = xp; done('Niveau ' + want + '.');
    })),
    row('Achats', btn('Tout débloquer', () => { const s = host.save(); for (const u of S.UPGRADES) s.upgrades[u.id] = u.costs.length; done('Tout est acheté, au niveau maximum.'); }),
      btn('Tout remettre à zéro', () => { const s = host.save(); s.upgrades = {}; s.equipped = []; s.powersOff = []; done('Plus aucun achat.'); })),
    row('Défis', btn('Nouveaux défis', () => { const s = host.save(); s.quests = []; P.fill(s); done('Trois nouveaux défis.'); })),
    tag('h3', { textContent: 'Affichage' }),
    row('Images par seconde', box('fps', () => host.fps(dbg.fps))),
    row('Mesures en jeu', box('info', () => host.info(dbg.info)), tag('small', { textContent: 'vitesse, vitesse propre, distance, hauteur, hauteur max' })),
    tag('h3', { textContent: 'Calculs' }),
    calc(),
    jumps(),
    tag('h3', { textContent: 'Prochaines courses' }),
    row('Invincible', box('god')),
    tune('Départ à', 'start', 'm'),
    row('Décor de départ', pickOne('biome', BIOMES.map((b, i) => [i, b.name]))),
    row('Monture au départ', pickOne('mount', [['', 'Aucune'], ...Object.entries(MOUNTS).map(([k, m]) => [k, m.name])])),
    row('Moustiques dès le départ', box('fm')),
    tag('h3', { textContent: 'Valeurs du jeu' }),
    tune('Vitesse de départ', 'base', 'm/s', PPM, 0.5),
    tune('Accélération', 'gain', 'm/s par seconde', PPM, 0.025),
    tune('Bonus du Sprint', 'sprint', 'm/s', PPM, 0.5),
    tune('Suspendus bas dès', 'from_low', 'm'),
    tune('Suspendus hauts dès', 'from_mid', 'm'),
    tune('Boss à', 'boss', 'm'),
    row('', btn('Valeurs d\'origine', () => { Object.assign(dbg, ORIGIN); changed.clear(); apply(); open(host); say.textContent = 'Valeurs d\'origine remises.'; })),
  );
  return panel;
}

export function open(h) {
  host = h;
  document.getElementById('debug')?.remove();
  document.body.append(build());
}
function close() { document.getElementById('debug')?.remove(); host.changed(); }
