// The debug menu: opened by touching the level badge of the home screen five times in a row.
// Plain on purpose. It changes the save (coins, level, purchases), what the next runs start with,
// and a few of the game's numbers. Its own settings are kept on this device only.

import { SPEED, FROM, BOSS, PPM, BIOME_LEN, MOUNTS, GROUND, PX } from './game.js';
import { BIOMES } from './render.js';
import * as S from './save.js';
import * as P from './progress.js';

const KEY = 'jungle-loop-debug';
// The game's own numbers as they are written in game.js, before anything here changes them.
const ORIGIN = { base: SPEED.base, gain: SPEED.gain, sprint: SPEED.sprint, boss: BOSS.at, ...Object.fromEntries(Object.entries(FROM).map(([k, v]) => ['from_' + k, v])) };
const BLANK = { fps: false, god: false, start: 0, biome: 0, mount: '', fm: false, ...ORIGIN };
export const dbg = { ...BLANK };
try { Object.assign(dbg, JSON.parse(localStorage.getItem(KEY)) || {}); } catch { /* nothing kept */ }

function apply() {
  SPEED.base = dbg.base; SPEED.gain = dbg.gain; SPEED.sprint = dbg.sprint; BOSS.at = dbg.boss;
  for (const k of Object.keys(FROM)) FROM[k] = dbg['from_' + k];
  try { localStorage.setItem(KEY, JSON.stringify(dbg)); } catch { /* not kept */ }
}
apply();

// What the next run starts with: called by main.js right after the run is made.
export function debugRun(run) {
  run.god = dbg.god;
  if (dbg.biome) run.biome = run.prevBiome = dbg.biome;
  if (dbg.start > 0) {                                  // as if the first metres had already been run
    const D = dbg.start * PPM, g = SPEED.gain;
    run.t = g ? (-run.base + Math.sqrt(run.base * run.base + 2 * g * D)) / g : D / run.base;   // the speed it would have reached
    run.cam = D; run.dist = dbg.start; run.nextX = D + 1500;
    run.terrain = [{ x: -1e9, y: GROUND }];
    run.nextBiomeAt = (Math.floor(dbg.start / BIOME_LEN) + 1) * BIOME_LEN;
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
  i.addEventListener('change', () => { const v = Number(i.value); if (Number.isFinite(v) && v >= 0) { dbg[key] = v * k; apply(); } });
  return row(label, i, tag('small', { textContent: unit + (key in ORIGIN ? ` (origine ${+(ORIGIN[key] / k).toFixed(3)})` : '') }));
};

function build() {
  const save = host.save();
  const coins = num(save.coins), level = num(P.levelInfo(save.xp).level);
  const say = tag('p', { className: 'say' });
  const done = (text) => { host.store(); host.changed(); say.textContent = text; };
  const panel = tag('div', { id: 'debug' },
    tag('div', { className: 'head' }, tag('b', { textContent: 'Debug' }), btn('Fermer', close)),
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
    tune('Araignée jaune dès', 'from_low', 'm'),
    tune('Araignée rouge dès', 'from_mid', 'm'),
    tune('Ronces dès', 'from_brambles', 'm'),
    tune('Geyser dès', 'from_geyser', 'm'),
    tune('Boss à', 'boss', 'm'),
    row('', btn('Valeurs d\'origine', () => { Object.assign(dbg, ORIGIN); apply(); open(host); say.textContent = 'Valeurs d\'origine remises.'; })),
  );
  return panel;
}

export function open(h) {
  host = h;
  document.getElementById('debug')?.remove();
  document.body.append(build());
}
function close() { document.getElementById('debug')?.remove(); host.changed(); }
