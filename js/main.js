// Glue: screens, input, HUD and the frame loop.

import { newRun, update, launch, setShapes, PIXEL, VIEW_H, MOUNTS } from './game.js';
import { draw, loadAssets, setQuality, quality, BIOMES } from './render.js';
import { showDemo, drawDemo, DEMO_W, DEMO_H } from './demo.js';
import { audio } from './audio.js';
import * as S from './save.js';
import * as P from './progress.js';

const $ = (id) => document.getElementById(id);
const cv = $('c'), ctx = cv.getContext('2d', { alpha: false });   // nothing shows through it: one layer less to blend
const demoCv = $('demo'), demoCtx = demoCv.getContext('2d');
const SCREENS = ['menu', 'intro', 'shop', 'settings', 'over', 'pause'];

let save = S.load();
let state = 'menu';                    // menu | intro | shop | settings | play | pause | over
let run = null;                        // the current escape
const still = newRun({});              // never updated: the frozen temple scene behind the menus
let deadFor = 0, bannerTimer = 0;
let lastDist = 0, hintStep = 0, hintTimer = 0;      // hintStep: 0 none, 1 "tap to jump", 2 "hold to jump higher"
let picked = S.UPGRADES[0].id;         // the upgrade shown in the preview
let tab = 'up';                        // which list the Améliorations screen shows: 'up' (to equip) or 'power' (always on)
const view = { w: 569, top: 0, logicalW: 1280 };   // art pixels, plus the width in game units
const CAP_KEY = 'jungle-loop-cap';     // the finest canvas this device has proved it can keep up with
const CAP_START = window.matchMedia('(pointer: coarse)').matches ? 3 : 4;   // a phone's chip fills far fewer pixels than a PC's
let cap = CAP_START;
try { cap = Math.max(1, Math.min(4, Number(localStorage.getItem(CAP_KEY)) || CAP_START)); } catch { /* private mode */ }
const input = { pressed: false, hold: false, dash: false, slow: false };

audio.setVolumes(save.musicVol, save.sfxVol);
let inRun = false;                     // the settings were opened from the pause screen: the run waits behind them

// The game's own pixel typeface, or a plain rounded one for whoever reads it better (a setting).
// `fk` evens out their sizes: Silkscreen is wide and all capitals, Fredoka is narrower.
function applyFont() {
  const [name, fk] = save.pixelFont ? ['Silkscreen', 0.82] : ['Fredoka', 0.95];
  $('stage').style.setProperty('--font', `"${name}", "Trebuchet MS", system-ui, sans-serif`);
  $('stage').style.setProperty('--fk', fk);
}
applyFont();
if (new URLSearchParams(location.search).has('bac')) window.__run = () => run;   // test bench only: lets a script look at the run

// Trying a typeface: "?font=Jersey 15&fk=1.3" loads it from Google Fonts for this visit only
// (fk corrects its size). Used by mockups/polices.html to show the real game in each candidate.
const trial = new URLSearchParams(location.search);
if (trial.get('font')) {
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = 'https://fonts.googleapis.com/css2?family=' + encodeURIComponent(trial.get('font')).replace(/%20/g, '+') + '&display=swap';
  document.head.append(link);
  $('stage').style.setProperty('--font', `"${trial.get('font')}", system-ui, sans-serif`);
  $('stage').style.setProperty('--fk', Number(trial.get('fk')) || 1);
}

// ---------- layout ----------

// The game is always shown in 16:9: 569 x 320 art pixels, as large as the window allows, with dark
// bars around it otherwise. One art pixel = --ui screen pixels, and the whole interface is measured
// in that unit, so nothing ever moves or stretches from one screen to another.
const STAGE_W = Math.round(VIEW_H / PIXEL * 16 / 9), STAGE_H = Math.round(VIEW_H / PIXEL);
function resize() {
  const ui = Math.min(window.innerWidth / STAGE_W, window.innerHeight / STAGE_H);
  const stage = $('stage');
  stage.style.width = (STAGE_W * ui).toFixed(2) + 'px';
  stage.style.height = (STAGE_H * ui).toFixed(2) + 'px';
  stage.style.setProperty('--ui', ui.toFixed(4) + 'px');
  // The pixel typeface is only sharp when one of its own pixels covers a whole number of the screen's:
  // its sizes are brought to the nearest such size (it is drawn on a grid of 8). The rounded typeface
  // keeps the sizes of style.css.
  const dpr = window.devicePixelRatio || 1;
  for (const [name, base] of [['--t-s', 11], ['--t-m', 14], ['--t-l', 19], ['--t-xl', 26]]) {
    if (!save.pixelFont) { stage.style.removeProperty(name); continue; }
    const dev = base * 0.82 * ui * dpr;
    stage.style.setProperty(name, (Math.max(8, Math.round(dev / 8 - 0.12) * 8) / dpr).toFixed(3) + 'px');
  }
  view.w = STAGE_W; view.logicalW = STAGE_W * PIXEL;
  // The canvas holds q x q real pixels per art pixel. `want` is what the screen can show (4 at most):
  // sprites then scroll by fractions of an art pixel and the browser softens the stair-steps when it
  // fits the picture to the screen. That is "smooth". It costs: a phone has to fill sixteen times the
  // pixels. So "auto" starts there and comes down as far as it takes to keep the frame rate (see
  // watch); "sharp" settles for 2 and shows them as hard squares, the lightest and crispest picture.
  const real = ui * (window.devicePixelRatio || 1), want = Math.max(1, Math.min(4, Math.ceil(real - 0.01)));
  const q = save.quality === 'sharp' ? Math.max(1, Math.min(2, Math.floor(real + 0.01))) : save.quality === 'smooth' ? want : Math.min(want, cap);
  setQuality(q);
  // A canvas finer than the screen is fitted smoothly. A coarser one (2 or less) is shown as hard
  // squares instead: stretched smoothly it would only look out of focus.
  stage.classList.toggle('smooth', save.quality !== 'sharp' && (q >= real - 0.01 || q > 2));
  cv.width = STAGE_W * q; cv.height = STAGE_H * q;
  demoCv.width = DEMO_W * q; demoCv.height = DEMO_H * q;
  ctx.imageSmoothingEnabled = demoCtx.imageSmoothingEnabled = false;
}
window.addEventListener('resize', resize);
resize();

// "auto" quality: while playing, frames are timed. Two slow spells in a row (under 48 a second) and
// the canvas goes down one step (slow: under 54 frames a second). If that changed nothing, the device is simply capped (battery saver,
// 30 Hz screen): the step is given back and nothing more is tried. What was found is kept for this device.
const perf = { n: 0, sum: 0, bad: 0, before: 0, locked: false, fps: 0 };
function watch(ms) {
  if (state !== 'play' || ms > 100 || !run || run.t < 2) return;
  perf.n++; perf.sum += ms;
  if (perf.n < 90) return;
  const avg = perf.sum / perf.n;
  perf.n = perf.sum = 0; perf.fps = Math.round(1000 / avg);
  if (save.quality !== 'auto' || perf.locked) return;
  if (perf.before) {                                   // just came down a step: was it worth it?
    if (avg > perf.before * 0.9) { cap = quality() + 1; perf.locked = true; }
    perf.before = 0; perf.bad = 0;
  } else if (avg > 18.5 && quality() > 1) {
    if (++perf.bad < 2) return;
    cap = quality() - 1; perf.before = avg;
  } else { perf.bad = 0; return; }
  try { localStorage.setItem(CAP_KEY, cap); } catch { /* not kept, found again next time */ }
  resize();
}

// Full screen, where the browser has it (not on iPhone, where the game must be added to the home
// screen instead). A phone turns to landscape with it. Installed as an app it already fills the screen.
const canFull = !!document.documentElement.requestFullscreen && document.fullscreenEnabled !== false
  && !window.matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches;
async function fullscreen(on) {
  try {
    if (on && !document.fullscreenElement) {
      await document.documentElement.requestFullscreen({ navigationUI: 'hide' });
      try { await screen.orientation.lock('landscape'); } catch { /* desktop, or not allowed: no matter */ }
    } else if (!on && document.fullscreenElement) await document.exitFullscreen();
  } catch { /* refused: the game stays as it is */ }
}
document.addEventListener('fullscreenchange', () => { resize(); if (state === 'settings') refreshSettings(); });
$('row-full').hidden = !canFull;

// Every "fly" block leaves towards, and comes back from, the edge of the frame it sits closest to.
// Worked out once, from where the block really is, before any screen has been slid away.
function aimFlyers() {
  const s = $('stage').getBoundingClientRect();
  for (const f of document.querySelectorAll('.fly')) {
    const r = f.getBoundingClientRect();
    const gaps = { left: r.left - s.left, right: s.right - r.right, top: r.top - s.top, bottom: s.bottom - r.bottom };
    f.dataset.from = Object.keys(gaps).reduce((a, b) => (gaps[b] < gaps[a] ? b : a));
  }
}

// ---------- small helpers ----------

const DEATHS = [
  'La boucle se referme…', 'Aïe. On rembobine.', 'Retour au temple !', 'Presque. Enfin… non.',
  'La jungle : 1 — Toi : 0', 'Ça piquait, hein ?', 'Encore ! Encore !', 'Le temps te rattrape.',
];
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};
const icon = (name) => { const im = el('img'); im.src = `assets/img/${name}.png`; im.alt = ''; return im; };

// The title is split into letters so each one can hop on its own.
[...'Jungle Loop'].forEach((ch, i) => {
  const s = el('span', ch === ' ' ? 'gap' : '', ch);
  s.style.setProperty('--i', i);
  $('title').append(s);
});

function confetti(count) {
  const colors = ['#ffd35c', '#5cf2e0', '#e0456b', '#7bd13c', '#fff8e6'];
  for (let i = 0; i < count; i++) {
    const c = el('i', 'confetti');
    c.style.left = Math.random() * 100 + '%';
    c.style.background = pick(colors);
    c.style.animationDuration = 1.4 + Math.random() * 1.6 + 's';
    c.style.animationDelay = Math.random() * 0.5 + 's';
    c.addEventListener('animationend', () => c.remove());
    $('stage').append(c);
  }
}

// Counts a number up on screen, with a tick sound: more satisfying than a static total.
function countUp(to, render) {
  const t0 = performance.now(), dur = Math.min(1100, 250 + to * 12);
  let lastTick = 0;
  (function step(now) {
    const k = Math.min(1, (now - t0) / dur);
    render(Math.round(to * (1 - Math.pow(1 - k, 3))));
    if (now - lastTick > 60 && k < 1) { audio.sfx('tick'); lastTick = now; }
    if (k < 1) requestAnimationFrame(step);
  })(t0);
}

// A short notice at the top of the screen: objective done, level gained.
function toast(ico, text, coins, xp) {
  const t = el('div', 'toast');
  t.append(icon(ico), text);
  if (coins) t.append(el('b', '', '+' + coins), icon('coin-icon'));
  if (xp) t.append(el('b', '', '+' + xp + ' XP'));
  t.addEventListener('animationend', () => t.remove());
  $('toasts').append(t);
}

function hint(step) {
  hintStep = step;
  $('hint').hidden = !step;
  if (step === 1) $('hint').textContent = 'Touche l\'écran pour sauter !';
  if (step === 2) { $('hint').textContent = 'Reste appuyé : tu sautes plus haut'; hintTimer = 3.5; }
}

// `full` adds the points count, where there is room for it.
function levelBar(id, full) {
  const info = P.levelInfo(save.xp), bar = el('span', 'bar'), fill = el('i');
  fill.style.width = (100 * info.into / info.need).toFixed(1) + '%';
  bar.append(fill);
  $(id).replaceChildren(icon('ico-star'), (full ? 'Niveau ' : 'Niv. ') + info.level, bar);
  if (full) $(id).append(el('small', '', `${info.into} / ${info.need} XP`));
}

// The three objectives, as cards: text, rewards, progress.
function questCards(id) {
  $(id).replaceChildren(...save.quests.map((q) => {
    const card = el('div', 'quest');
    const reward = el('b', '', '+' + q.reward + ' ◈');
    reward.append(el('i', '', '+' + q.xp + ' XP'));
    const bar = el('span', 'bar'), fill = el('i');
    fill.style.width = (100 * q.p / q.goal).toFixed(1) + '%';
    bar.append(fill);
    card.append(el('span', '', `${P.questText(q)} (${Math.floor(q.p)}/${q.goal})`), reward, bar);
    return card;
  }));
}

// Feeds the objectives and the level with what just happened, and announces what it unlocked.
// Experience: one point per metre, plus what each completed objective pays.
function progress(stats) {
  const done = P.feed(save, stats);
  let xp = stats.dist || 0;
  for (const q of done) { toast('ico-target', 'Défi réussi !', q.reward, q.xp); xp += q.xp; }
  const levels = xp ? P.addXp(save, xp) : [];
  for (const l of levels) toast('ico-star', 'Niveau ' + l + ' !', P.levelReward(l));
  if (done.length || levels.length) { audio.sfx(levels.length ? 'level' : 'quest'); S.store(save); }
}

function banner(text) {
  const b = $('banner');
  b.textContent = text; b.classList.add('on'); bannerTimer = 2.4;
}

// ---------- screens ----------

// name: one of SCREENS, or null for the game itself (only the HUD shows).
function show(name) {
  for (const s of SCREENS) $('screen-' + s).classList.toggle('on', s === name);
  $('hud').classList.toggle('on', name === null);
}

function refreshMenu() {
  levelBar('menu-level');
  $('menu-coins').replaceChildren(icon('coin-icon'), String(save.coins));
  questCards('menu-quests');
  // the three slots: what goes on the next run
  $('menu-loadout').replaceChildren(...[0, 1, 2].map((i) => {
    const id = save.equipped[i], slot = el('div', id ? 'slot full' : 'slot', id ? undefined : '+');
    if (id) slot.append(icon('ico-' + S.UPGRADES.find((u) => u.id === id).icon));
    // an empty slot leads to the shop; a filled one only says what it holds
    slot.addEventListener('click', (e) => { audio.sfx('click'); if (!id) { tab = 'up'; go('shop'); return; } e.stopPropagation(); slotInfo(id, slot); });
    return slot;
  }));
}

// The card that names an equipped item, above the three slots. A second touch, or one anywhere else, puts it away.
function slotInfo(id, slot) {
  const box = $('menu-info'), u = S.UPGRADES.find((x) => x.id === id);
  if (!box.hidden && box.dataset.id === id) { box.hidden = true; return; }
  box.dataset.id = id;
  box.replaceChildren(el('b', '', u.name + (u.costs.length > 1 ? '  ' + '●'.repeat(S.level(save, id)) + '○'.repeat(u.costs.length - S.level(save, id)) : '')), el('span', '', u.desc));
  box.hidden = false;
  for (const s of document.querySelectorAll('#menu-loadout .slot')) s.classList.toggle('sel', s === slot);
}
document.addEventListener('click', () => { $('menu-info').hidden = true; for (const s of document.querySelectorAll('#menu-loadout .slot')) s.classList.remove('sel'); });

function refreshSettings() {
  for (const [id, on] of [['tg-font', save.pixelFont], ['tg-full', !!document.fullscreenElement]]) {
    $(id).textContent = on ? 'Oui' : 'Non';
    $(id).className = (on ? 'on' : 'plain') + ' small';
  }
  $('tg-smooth').textContent = { auto: 'Auto', smooth: 'Maximum', sharp: 'Net' }[save.quality];
  $('tg-smooth').className = 'on small';
  for (const [id, v] of [['vol-music', save.musicVol], ['vol-sfx', save.sfxVol]]) $(id).querySelector('i').style.width = v * 10 + '%';
}

// Left: the list. Right: the preview of the upgrade picked in the list.
function refreshShop(justBought) {
  levelBar('shop-level', true);
  $('shop-coins').replaceChildren(icon('coin-icon'), String(save.coins));
  const full = save.equipped.length >= S.MAX_EQUIPPED;
  const shown = S.UPGRADES.filter((u) => !!u.power === (tab === 'power'));
  if (!shown.some((u) => u.id === picked)) picked = shown[0].id;
  for (const b of document.querySelectorAll('#shop-tabs .tab')) b.classList.toggle('sel', b.dataset.tab === tab);
  $('shop-list').replaceChildren(...shown.map((u) => {
    const lvl = S.level(save, u.id), cost = S.nextCost(save, u), on = save.equipped.includes(u.id);
    const locked = u.needs && !S.level(save, u.needs);
    const row = el('div', 'shop-row' + (u.id === picked ? ' sel' : '') + (on || (u.power && lvl && !save.powersOff.includes(u.id)) ? ' equipped' : '') + (u.id === justBought ? ' bought' : ''));
    const pips = u.costs.length > 1 ? ' ' + '●'.repeat(lvl) + '○'.repeat(u.costs.length - lvl) : '';
    const status = locked ? 'Demande : ' + S.UPGRADES.find((x) => x.id === u.needs).name
      : u.power ? (!lvl ? 'Pouvoir permanent' : save.powersOff.includes(u.id) ? 'Désactivé' : 'Actif') : on ? 'Équipé' + pips : lvl ? 'Possédé' + pips : (u.kind === 'actif' ? 'Bouton en jeu' : 'Toujours actif');
    row.append(icon('ico-' + u.icon), el('b', '', u.name), el('small', '', status));
    row.addEventListener('click', () => { picked = u.id; refreshShop(); });

    // one action per row: buy it, then put it on or take it off (levels are bought from the preview side)
    const btn = el('button', 'small');
    if (!lvl) {
      btn.textContent = '◈ ' + cost; btn.classList.add('gold');
      btn.disabled = locked || save.coins < cost;
      btn.addEventListener('click', (e) => { e.stopPropagation(); buy(u); });
    } else if (u.power) {                              // a power takes no slot: it is just switched off or on
      const off = save.powersOff.includes(u.id);
      btn.textContent = off ? 'Activer' : 'Désactiver';
      btn.classList.add(off ? 'on' : 'plain');
      btn.addEventListener('click', (e) => { e.stopPropagation(); picked = u.id; S.togglePower(save, u.id); refreshShop(); });
    } else {
      btn.textContent = on ? 'Retirer' : 'Équiper';
      btn.classList.add(on ? 'plain' : 'on');
      btn.disabled = !on && full;
      btn.addEventListener('click', (e) => { e.stopPropagation(); picked = u.id; S.toggleEquip(save, u.id); refreshShop(); });
    }
    row.append(btn);
    return row;
  }));

  const u = S.UPGRADES.find((x) => x.id === picked), lvl = S.level(save, u.id), cost = S.nextCost(save, u);
  $('demo-name').textContent = u.name;
  $('demo-desc').textContent = u.desc;
  const slots = $('demo-slots');
  slots.textContent = u.power ? 'Pouvoir : sans emplacement, désactivable' : `Équipements : ${save.equipped.length} / ${S.MAX_EQUIPPED}`;
  if (lvl && cost !== null) {                           // already owned, a stronger level is for sale
    const up = el('button', 'small gold', `Niveau ${lvl + 1} · ◈ ${cost}`);
    up.disabled = save.coins < cost; up.style.marginLeft = '1em';
    up.addEventListener('click', () => buy(u));
    slots.append(up);
  }
  showDemo(u.id, lvl);
}

function buy(u) {
  const ok = S.buy(save, u);
  audio.sfx(ok ? 'buy' : 'no');
  if (ok) { confetti(14); picked = u.id; }
  refreshShop(ok ? u.id : null);
}

// Puts the run's coins in the bank and saves. Called once per run, whatever ends it.
function bank() {
  if (!run || run.banked) return;
  run.banked = true;
  save.coins += run.gold;
  save.loops++;
  save.best = Math.max(save.best, Math.floor(run.dist));
  S.store(save);
}

function go(name) {
  audio.unlock();
  if (inRun) {                                          // leaving the settings opened from the pause: back to the pause
    inRun = false;
    if (name === 'menu') { state = 'pause'; show('pause'); audio.duck(true); return; }
  }
  audio.duck(false);
  if (name === 'settings' && state === 'pause') inRun = true;
  if (name === 'play') {
    if (canFull && save.full && window.matchMedia('(pointer: coarse)').matches) fullscreen(true);   // a phone plays full screen
    if (!save.seenIntro) { save.seenIntro = true; S.store(save); state = 'intro'; show('intro'); return; }
    run = newRun(S.loadout(save));                      // only the three equipped upgrades come along
    run.viewW = view.logicalW;
    launch(run);                                        // rumble, then the doorway blows out
    deadFor = 0; hudState.dist = hudState.gold = hudState.hearts = -1;
    $('hud-hearts').replaceChildren(...Array.from({ length: run.hearts }, () => icon('heart')));
    $('hud-hearts').style.visibility = run.maxHearts > 1 ? '' : 'hidden';   // a single life needs no counter
    lastDist = 0; $('toasts').textContent = '';
    state = 'play'; show(null);
    P.startRun(save);
    progress({ runs: 1 });
    hint(save.loops < 2 ? 1 : 0);                       // the first escapes explain the one control
    $('btn-dash').hidden = !run.up.dash;
    $('btn-slow').hidden = !run.up.slow;
    audio.setBiome(0); audio.music('');                 // silence for the rumble: the theme starts on the blast
    return;
  }
  if (state === 'pause' && !inRun) bank();
  hint(0);
  if (name === 'menu') refreshMenu();
  if (name === 'shop') refreshShop();
  if (name === 'settings') { refreshSettings(); $('save-code').value = ''; $('save-msg').textContent = ''; $('screen-settings').classList.toggle('inrun', inRun); }
  audio.music(name === 'intro' ? '' : inRun ? 'run' : 'menu');
  state = name; show(name);
}

function gameOver() {
  const record = Math.floor(run.dist) > save.best;
  bank();
  $('over-title').textContent = pick(DEATHS);
  hint(0);
  levelBar('over-level', true); questCards('over-quests');
  const dist = Math.floor(run.dist), gold = run.gold;
  countUp(dist, (v) => {
    $('over-dist').textContent = v + ' m';
    $('over-gold').textContent = '+' + Math.round(gold * (dist ? v / dist : 1)) + ' ◈';
  });
  const best = $('over-best');
  best.classList.toggle('record', record);
  best.textContent = record ? '★ Nouveau record ! ★' : `Record : ${save.best} m`;
  if (record) { confetti(60); audio.sfx('record'); }
  audio.music('over');                                  // the run's music winds down into the jingle, which leads to the menu's
  state = 'over'; show('over');
}

function pause() {
  if (state !== 'play' || run.dead) return;
  $('pause-dist').textContent = Math.floor(run.dist) + ' m';
  $('pause-gold').textContent = '+' + run.gold + ' ◈';
  $('pause-best').textContent = `Record : ${save.best} m`;
  levelBar('pause-level', true); questCards('pause-quests');
  state = 'pause'; show('pause'); audio.duck(true);    // the music goes on, quieter
}
function resume() { if (state === 'pause') { state = 'play'; show(null); audio.duck(false); } }

for (const b of document.querySelectorAll('[data-go]')) b.addEventListener('click', () => go(b.dataset.go));
for (const b of document.querySelectorAll('#shop-tabs .tab')) b.addEventListener('click', () => { tab = b.dataset.tab; refreshShop(); });
$('btn-resume').addEventListener('click', resume);
$('btn-pause').addEventListener('click', pause);

// ---------- settings ----------

for (const [id, key] of [['vol-music', 'musicVol'], ['vol-sfx', 'sfxVol']])
  for (const b of $(id).querySelectorAll('button')) b.addEventListener('click', () => {
    save[key] = Math.max(0, Math.min(10, save[key] + Number(b.dataset.d)));
    audio.setVolumes(save.musicVol, save.sfxVol); S.store(save); refreshSettings();
    if (key === 'musicVol') audio.music(inRun ? 'run' : 'menu'); else audio.sfx('coin');   // heard at once
  });
$('tg-font').addEventListener('click', () => { save.pixelFont = !save.pixelFont; S.store(save); applyFont(); resize(); refreshSettings(); });
$('tg-smooth').addEventListener('click', () => {      // choosing again also forgets what "auto" had settled for
  save.quality = S.QUALITIES[(S.QUALITIES.indexOf(save.quality) + 1) % S.QUALITIES.length];
  cap = CAP_START; perf.locked = false; perf.bad = perf.before = 0;
  try { localStorage.removeItem(CAP_KEY); } catch { /* nothing kept */ }
  S.store(save); resize(); refreshSettings();
});
$('tg-full').addEventListener('click', () => { save.full = !document.fullscreenElement; S.store(save); fullscreen(save.full); });
const msg = (t) => { $('save-msg').textContent = t; };

function applyImport(code) {
  const s = S.importCode(code);
  if (!s) { msg('Code invalide : rien n\'a été changé.'); return; }
  if (!confirm(`Remplacer la partie actuelle par celle-ci ?\n◈ ${s.coins} · record ${s.best} m · ${s.loops} courses`)) return;
  save = s; S.store(save);
  audio.setVolumes(save.musicVol, save.sfxVol);
  applyFont(); resize(); refreshSettings();
  msg('Partie importée.');
}

$('save-copy').addEventListener('click', async () => {
  const code = S.exportCode(save);
  $('save-code').value = code;
  try { await navigator.clipboard.writeText(code); msg('Code copié.'); } catch { msg('Code prêt : sélectionne-le pour le copier.'); }
});
$('save-file').addEventListener('click', () => {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([S.exportCode(save)], { type: 'text/plain' }));
  a.download = 'jungle-loop-sauvegarde.txt';
  a.click();
  URL.revokeObjectURL(a.href);
});
$('save-import').addEventListener('click', () => applyImport($('save-code').value));
$('save-open').addEventListener('click', () => $('save-input').click());
$('save-input').addEventListener('change', async (e) => {
  const f = e.target.files[0];
  if (f) applyImport(await f.text());
  e.target.value = '';
});
$('save-reset').addEventListener('click', () => {
  if (!confirm('Effacer toute la progression ? C\'est définitif.')) return;
  save = S.reset(); S.store(save); audio.setVolumes(save.musicVol, save.sfxVol); applyFont(); resize(); refreshSettings(); msg('Progression effacée.');
});

// ---------- input ----------

function press() { audio.unlock(); if (state === 'play') { input.pressed = true; input.hold = true; } }

// While playing, a touch anywhere on the frame is a jump (the HUD's buttons keep their own job).
$('stage').addEventListener('pointerdown', (e) => { if (!e.target.closest('button')) press(); });
window.addEventListener('pointerup', () => { input.hold = false; });
window.addEventListener('pointercancel', () => { input.hold = false; });
$('stage').addEventListener('contextmenu', (e) => e.preventDefault());

$('btn-dash').addEventListener('pointerdown', (e) => { e.preventDefault(); input.dash = true; });
$('btn-slow').addEventListener('pointerdown', (e) => { e.preventDefault(); input.slow = true; });

// Browsers only allow sound after a first gesture: the menu's music starts with it.
document.addEventListener('pointerdown', () => { audio.unlock(); if (state !== 'play' && state !== 'pause' && state !== 'intro') audio.music(inRun ? 'run' : 'menu'); }, true);
document.addEventListener('click', (e) => { if (e.target.closest('button')) audio.sfx('click'); }, true);

window.addEventListener('keydown', (e) => {
  if (e.target.tagName === 'TEXTAREA') return;
  const k = e.key.toLowerCase();
  if (e.code === 'Space' || k === 'arrowup' || k === 'z' || k === 'w') {
    e.preventDefault();
    if (e.repeat) return;
    if (state === 'play') press();
    else if (state === 'menu' || state === 'over' || state === 'intro') go('play');
    else if (state === 'pause') resume();
  } else if (k === 'shift' || k === 'e') input.dash = true;
  else if (k === 'a' || k === 'q') input.slow = true;
  else if (k === 'escape' || k === 'p') { if (state === 'play') pause(); else if (state === 'pause') resume(); else if (inRun) go('menu'); }
});
window.addEventListener('keyup', (e) => {
  const k = e.key.toLowerCase();
  if (e.code === 'Space' || k === 'arrowup' || k === 'z' || k === 'w') input.hold = false;
});
document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); audio.sleep(document.hidden); });
// Closing the tab mid-run still keeps the coins picked up so far.
window.addEventListener('pagehide', () => { if (state === 'play' || state === 'pause' || inRun) bank(); });

// ---------- HUD ----------

function cooldown(btn, a) {
  const cd = (a.max ? a.cd / a.max : 0).toFixed(2);
  if (btn.dataset.cd === cd) return;                   // the page is only touched when something changed
  btn.dataset.cd = cd;
  btn.style.setProperty('--cd', cd);
  btn.classList.toggle('cooling', cd > 0);
}

const hudState = { dist: -1, gold: -1, hearts: -1 };
function hud() {
  const d = Math.floor(run.dist);
  if (d !== hudState.dist) { hudState.dist = d; $('hud-dist').textContent = d + ' m'; }
  if (run.gold !== hudState.gold) {
    hudState.gold = run.gold;
    const c = $('hud-coins');
    c.textContent = run.gold;
    c.classList.remove('pop'); void c.offsetWidth; c.classList.add('pop');   // restart the little bounce
  }
  if (run.hearts !== hudState.hearts) {
    hudState.hearts = run.hearts;
    [...$('hud-hearts').children].forEach((h, i) => h.classList.toggle('lost', i >= run.hearts));
  }
  cooldown($('btn-dash'), run.dash);
  cooldown($('btn-slow'), run.slow);
}

// ---------- loop ----------

let last = performance.now(), fpsTick = 0;
// "?fps" in the address shows the frame rate and the canvas in a corner: for checking a phone
const fpsBox = new URLSearchParams(location.search).has('fps') ? $('stage').appendChild(el('div')) : null;
if (fpsBox) fpsBox.id = 'fps';
function frame(now) {
  const dt = Math.min(0.033, (now - last) / 1000);
  watch(now - last);
  last = now;
  if (fpsBox && (fpsTick = (fpsTick + 1) % 30) === 0) fpsBox.textContent = `${perf.fps || '…'} i/s · x${quality()} · ${cv.width}x${cv.height} · ${save.quality}`;

  if (state === 'play' || state === 'over') {
    run.viewW = view.logicalW;
    update(run, dt, input);
    const stats = { dist: run.dist - lastDist, coins: 0, gems: 0, jumps: 0, plats: 0, breaks: 0, shrooms: 0, monkeys: 0, mounts: 0, dodges: 0, hurt: false };
    lastDist = run.dist;
    for (const ev of run.events) {
      audio.sfx(ev);
      if (ev === 'biome') { banner(BIOMES[run.biome].name); audio.setBiome(run.biome); }
      if (ev === 'rewind') banner('Rembobinage');
      if (ev === 'coin') stats.coins++;
      if (ev === 'gem') stats.gems++;
      if (ev === 'jump') stats.jumps++;
      if (ev === 'land') stats.plats++;
      if (ev === 'break' || ev === 'crate') stats.breaks++;
      if (ev === 'shroom') stats.shrooms++;
      if (ev === 'monkey') stats.monkeys++;
      if (ev === 'mount') { stats.mounts++; banner(MOUNTS[run.mount.kind].name + ' !'); }
      if (ev === 'dodge') stats.dodges++;
      if (ev === 'fm' && run.fm && !run.fm.seen) { run.fm.seen = true; banner('Moustiques !'); }
      if (ev === 'boom') { audio.music('run'); banner('Cours !'); }
      if (ev === 'hurt' || ev === 'rewind' || ev === 'hit') stats.hurt = true;
    }
    run.events.length = 0;
    progress(stats);
    if (hintStep === 1 && stats.jumps) hint(2);
    else if (hintStep === 2 && (hintTimer -= dt) <= 0) hint(0);
    hud();
    if (state === 'play' && run.dead && (deadFor += dt) > 0.9) gameOver();
  }
  input.pressed = input.dash = input.slow = false;

  if (bannerTimer > 0 && (bannerTimer -= dt) <= 0) $('banner').classList.remove('on');

  // Behind the menus: the temple, frozen. The hero only appears once the run starts.
  const shown = state === 'play' || state === 'pause' || state === 'over' || inRun ? run : still;
  ctx.setTransform(quality(), 0, 0, quality(), 0, 0);
  draw(ctx, shown, view, now / 1000);
  if (state === 'shop') drawDemo(demoCtx, dt, now / 1000);
  requestAnimationFrame(frame);
}

// The groups of coins drawn in assets/patterns.txt: anyone can add theirs there.
fetch('assets/patterns.txt', { cache: 'no-cache' }).then((r) => (r.ok ? r.text() : '')).then(setShapes).catch(() => {});

refreshMenu();
aimFlyers();           // before the first show(): every block is still at its resting place
loadAssets();
requestAnimationFrame(frame);
requestAnimationFrame(() => show('menu'));   // one frame later, so the menu slides in rather than pops

// Offline support, only once published: a service worker on localhost would serve stale files while developing.
if ('serviceWorker' in navigator && !['localhost', '127.0.0.1'].includes(location.hostname)) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
