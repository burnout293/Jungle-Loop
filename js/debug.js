// The debug menu: opened by touching the level badge of the home screen five times in a row.
// Plain on purpose. It changes the save (coins, level, purchases), what the next runs start with,
// and a few of the game's numbers. Its own settings are kept on this device only.
// As soon as anything here differs from the game's own state, the game is "in debug": a thin red strip
// along the top of the screen says so, above everything, and no record is kept (see main.js). Whatever
// was changed is shown in red; « Stopper le débogage » puts every field back.

import { SPEED, FROM, BOSS, JUMP, PPM, MOUNTS, GROUND, PX } from './game.js';
import { BIOMES } from './render.js';
import * as S from './save.js';
import * as P from './progress.js';

const KEY = 'jungle-loop-debug';
// The game's own numbers as they are written in game.js, before anything here changes them.
const ORIGIN = { base: SPEED.base, gain: SPEED.gain, sprint: SPEED.sprint, boss: BOSS.at, ...Object.fromEntries(Object.entries(FROM).map(([k, v]) => ['from_' + k, v])) };
// `edits`: what was changed in the save from here (coins, level, purchases, objectives).
const BLANK = { info: false, god: false, start: 0, biome: 0, mount: '', fm: false, edits: [], ...ORIGIN };
export const dbg = { ...BLANK, edits: [] };
// Only the game numbers changed by hand here are kept and applied: the others always follow game.js,
// even when a new version of the game changes them.
const changed = new Set();
try {
  const kept = JSON.parse(localStorage.getItem(KEY)) || {};
  for (const k of Array.isArray(kept.changed) ? kept.changed : []) if (k in ORIGIN) changed.add(k);
  for (const [k, v] of Object.entries(kept)) if (k in BLANK && typeof v === typeof BLANK[k] && (!(k in ORIGIN) || changed.has(k))) dbg[k] = v;
  if (!Array.isArray(dbg.edits)) dbg.edits = [];
} catch { /* nothing kept */ }

// Is a field away from the game's own value?
const SETTINGS = ['info', 'god', 'start', 'biome', 'mount', 'fm'];
const differs = (k) => (k in ORIGIN ? changed.has(k) : dbg[k] !== BLANK[k]);
export function debugOn() { return dbg.edits.length > 0 || changed.size > 0 || SETTINGS.some(differs); }

// The thin red strip at the top of the screen, above everything (even this menu).
const strip = Object.assign(document.createElement('div'), { id: 'debug-strip', textContent: 'DEBUG' });
document.body.append(strip);

let marks = [];                                    // [row, test]: the rows to show in red when changed
function apply() {
  SPEED.base = dbg.base; SPEED.gain = dbg.gain; SPEED.sprint = dbg.sprint; BOSS.at = dbg.boss;
  for (const k of Object.keys(FROM)) FROM[k] = dbg['from_' + k];
  try { localStorage.setItem(KEY, JSON.stringify({ ...dbg, changed: [...changed] })); } catch { /* not kept */ }
  strip.hidden = !debugOn();
  for (const [r, test] of marks) r.classList.toggle('mod', test());
}
apply();

// What the next run starts with: called by main.js right after the run is made.
export function debugRun(run) {
  run.god = dbg.god;
  run.debug = debugOn();                                // no record for this run
  if (dbg.biome) run.biome = run.prevBiome = dbg.biome;
  if (changed.has('boss') && run.mode !== 'endless') run.bossAt = BOSS.at;   // a boss set by hand comes exactly there (never in the Run illimitée)
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

let host = null;      // { save, store, changed, info } given by main.js

const tag = (name, props = {}, ...kids) => { const e = Object.assign(document.createElement(name), props); e.append(...kids); return e; };
// A row, shown in red while `test` says it is changed.
const row = (label, test, ...kids) => {
  const r = tag('div', { className: 'row' }, tag('span', { textContent: label }), ...kids);
  if (test) { marks.push([r, test]); r.classList.toggle('mod', test()); }
  return r;
};
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
  return row(label, () => differs(key), i, tag('small', { textContent: unit + (key in ORIGIN ? ` (origine ${+(ORIGIN[key] / k).toFixed(3)})` : '') }));
};
const edited = (what) => () => dbg.edits.includes(what);

// Speed and time at a given distance, from the numbers in force (and with the Sprint).
function calc() {
  const at = num(1000, 100), out = tag('small');
  const show = () => {
    const D = Math.max(0, Number(at.value) || 0) * PPM, g = SPEED.gain;
    const line = (b) => { const t = g ? (-b + Math.sqrt(b * b + 2 * g * D)) / g : D / b; return `${((b + g * t) / PPM).toFixed(1)} m/s après ${Math.floor(t / 60)} min ${Math.round(t % 60)} s`; };
    out.textContent = `à pied : ${line(SPEED.base)} · avec Sprint : ${line(SPEED.base + SPEED.sprint)}`;
  };
  at.addEventListener('input', show); show();
  return row('Vitesse à (m)', null, at, out);
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
  marks = [];
  const save = host.save();
  const coins = num(save.coins), level = num(P.levelInfo(save.xp).level);
  const say = tag('p', { className: 'say' });
  // a change made to the save: kept, said, and remembered as a debug change
  const done = (what, text) => { if (!dbg.edits.includes(what)) dbg.edits = [...dbg.edits, what]; apply(); host.store(); host.changed(); say.textContent = text; };
  const panel = tag('div', { id: 'debug' },
    tag('div', { className: 'head' }, tag('span', {}, btn('Fermer', close), ' ', btn('Stopper le débogage', stop)), tag('b', { textContent: 'Debug' })),
    say,
    tag('h3', { textContent: 'Partie' }),
    row('Pièces', edited('coins'), coins, btn('Appliquer', () => { host.save().coins = Math.max(0, Math.floor(Number(coins.value) || 0)); done('coins', 'Pièces changées.'); })),
    row('Niveau', edited('level'), level, btn('Appliquer', () => {
      const want = Math.max(1, Math.floor(Number(level.value) || 1)); let xp = 0;
      while (P.levelInfo(xp).level < want) { const i = P.levelInfo(xp); xp += i.need - i.into; }
      host.save().xp = xp; done('level', 'Niveau ' + want + '.');
    })),
    row('Achats', edited('buys'), btn('Tout débloquer', () => { const s = host.save(); for (const u of S.UPGRADES) s.upgrades[u.id] = u.costs.length; done('buys', 'Tout est acheté, au niveau maximum.'); }),
      btn('Tout remettre à zéro', () => { const s = host.save(); s.upgrades = {}; s.equipped = []; s.powersOff = []; done('buys', 'Plus aucun achat.'); })),
    row('Défis', edited('quests'), btn('Nouveaux défis', () => { const s = host.save(); s.quests = []; P.fill(s); done('quests', 'Trois nouveaux défis.'); })),
    tag('h3', { textContent: 'Affichage' }),
    row('Mesures en jeu', () => differs('info'), box('info', () => host.info(dbg.info)), tag('small', { textContent: 'vitesse, vitesse propre, distance, hauteur, hauteur max' })),
    tag('small', { textContent: 'Les images par seconde sont dans les Réglages (Affichage).' }),
    tag('h3', { textContent: 'Calculs' }),
    calc(),
    jumps(),
    tag('h3', { textContent: 'Prochaines courses' }),
    row('Invincible', () => differs('god'), box('god')),
    tune('Départ à', 'start', 'm'),
    row('Décor de départ', () => differs('biome'), pickOne('biome', BIOMES.map((b, i) => [i, b.name]))),
    row('Monture au départ', () => differs('mount'), pickOne('mount', [['', 'Aucune'], ...Object.entries(MOUNTS).map(([k, m]) => [k, m.name])])),
    row('Moustiques dès le départ', () => differs('fm'), box('fm')),
    tag('h3', { textContent: 'Valeurs du jeu' }),
    tune('Vitesse de départ', 'base', 'm/s', PPM, 0.5),
    tune('Accélération', 'gain', 'm/s par seconde', PPM, 0.025),
    tune('Bonus du Sprint', 'sprint', 'm/s', PPM, 0.5),
    tune('Suspendus bas dès', 'from_low', 'm'),
    tune('Suspendus hauts dès', 'from_mid', 'm'),
    tune('Boss à', 'boss', 'm'),
    row('', null, btn('Valeurs d\'origine', () => { Object.assign(dbg, ORIGIN); changed.clear(); apply(); open(host); document.querySelector('#debug .say').textContent = 'Valeurs d\'origine remises.'; })),
  );
  return panel;
}

// Every field back to the game's own: the strip goes, records count again. (What was done to the save,
// coins or purchases, stays: it is the save.)
function stop() {
  Object.assign(dbg, BLANK, { edits: [] });
  changed.clear();
  apply();
  host.info(false);
  open(host);
  document.querySelector('#debug .say').textContent = 'Débogage arrêté : tous les champs sont revenus à l\'origine.';
}

export function open(h) {
  host = h;
  document.getElementById('debug')?.remove();
  document.body.append(build());
  apply();
}
function close() { document.getElementById('debug')?.remove(); marks = []; host.changed(); }
