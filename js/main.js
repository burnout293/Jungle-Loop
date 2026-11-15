// Glue: screens, input, HUD and the frame loop.

import { newRun, update, launch, PIXEL, VIEW_H, MOUNTS } from './game.js';
import { draw, loadAssets, setQuality, quality, BIOMES } from './render.js';
import { showDemo, drawDemo, DEMO_W, DEMO_H } from './demo.js';
import { audio } from './audio.js';
import * as S from './save.js';
import * as P from './progress.js';

const $ = (id) => document.getElementById(id);
const cv = $('c'), ctx = cv.getContext('2d');
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
const input = { pressed: false, hold: false, dash: false, slow: false };

audio.musicOn = save.music; audio.sfxOn = save.sfx;

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
  view.w = STAGE_W; view.logicalW = STAGE_W * PIXEL;
  // Smoothing: the canvas gets as many real pixels per art pixel as the screen shows (4 at most),
  // so sprites can scroll by fractions of an art pixel and the browser softens the stair-steps when
  // it fits the picture to the screen. Without it: one canvas pixel per art pixel, hard squares.
  const q = save.smooth ? Math.max(1, Math.min(4, Math.ceil(ui * (window.devicePixelRatio || 1) - 0.01))) : 1;
  setQuality(q);
  stage.classList.toggle('smooth', q > 1);
  cv.width = STAGE_W * q; cv.height = STAGE_H * q;
  demoCv.width = DEMO_W * q; demoCv.height = DEMO_H * q;
  ctx.imageSmoothingEnabled = demoCtx.imageSmoothingEnabled = false;
}
window.addEventListener('resize', resize);
resize();

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
    const id = save.equipped[i], slot = el('div', 'slot', id ? undefined : '+');
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
  for (const [id, on] of [['tg-music', save.music], ['tg-sfx', save.sfx], ['tg-font', save.pixelFont], ['tg-smooth', save.smooth]]) {
    $(id).textContent = on ? 'Oui' : 'Non';
    $(id).className = on ? 'on' : 'plain';
  }
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
  if (name === 'play') {
    if (!save.seenIntro) { save.seenIntro = true; S.store(save); state = 'intro'; show('intro'); return; }
    run = newRun(S.loadout(save));                      // only the three equipped upgrades come along
    run.viewW = view.logicalW;
    launch(run);                                        // rumble, then the doorway blows out
    deadFor = 0; hudState.dist = hudState.gold = hudState.hearts = -1;
    $('hud-hearts').replaceChildren(...Array.from({ length: run.hearts }, () => icon('heart')));   // three, or four with Cœur en plus
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
  if (state === 'pause') bank();
  hint(0);
  if (name === 'menu') refreshMenu();
  if (name === 'shop') refreshShop();
  if (name === 'settings') { refreshSettings(); $('save-code').value = ''; $('save-msg').textContent = ''; }
  audio.music(name === 'intro' ? '' : 'menu');
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
  audio.music('menu');
  state = 'over'; show('over');
}

function pause() {
  if (state !== 'play' || run.dead) return;
  $('pause-dist').textContent = Math.floor(run.dist) + ' m';
  $('pause-gold').textContent = '+' + run.gold + ' ◈';
  $('pause-best').textContent = `Record : ${save.best} m`;
  levelBar('pause-level', true); questCards('pause-quests');
  state = 'pause'; show('pause'); audio.music('');
}
function resume() { if (state === 'pause') { state = 'play'; show(null); audio.music('run'); } }

for (const b of document.querySelectorAll('[data-go]')) b.addEventListener('click', () => go(b.dataset.go));
for (const b of document.querySelectorAll('#shop-tabs .tab')) b.addEventListener('click', () => { tab = b.dataset.tab; refreshShop(); });
$('btn-resume').addEventListener('click', resume);
$('btn-pause').addEventListener('click', pause);

// ---------- settings ----------

$('tg-music').addEventListener('click', () => { save.music = audio.musicOn = !save.music; S.store(save); refreshSettings(); audio.music('menu'); });
$('tg-sfx').addEventListener('click', () => { save.sfx = audio.sfxOn = !save.sfx; S.store(save); refreshSettings(); });
$('tg-font').addEventListener('click', () => { save.pixelFont = !save.pixelFont; S.store(save); applyFont(); refreshSettings(); });
$('tg-smooth').addEventListener('click', () => { save.smooth = !save.smooth; S.store(save); resize(); refreshSettings(); });
const msg = (t) => { $('save-msg').textContent = t; };

function applyImport(code) {
  const s = S.importCode(code);
  if (!s) { msg('Code invalide : rien n\'a été changé.'); return; }
  if (!confirm(`Remplacer la partie actuelle par celle-ci ?\n◈ ${s.coins} · record ${s.best} m · ${s.loops} courses`)) return;
  save = s; S.store(save);
  audio.musicOn = save.music; audio.sfxOn = save.sfx;
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
  save = S.reset(); S.store(save); applyFont(); resize(); refreshSettings(); msg('Progression effacée.');
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
document.addEventListener('pointerdown', () => { audio.unlock(); if (state !== 'play' && state !== 'pause' && state !== 'intro') audio.music('menu'); }, true);
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
  else if (k === 'escape' || k === 'p') { if (state === 'play') pause(); else if (state === 'pause') resume(); }
});
window.addEventListener('keyup', (e) => {
  const k = e.key.toLowerCase();
  if (e.code === 'Space' || k === 'arrowup' || k === 'z' || k === 'w') input.hold = false;
});
document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
// Closing the tab mid-run still keeps the coins picked up so far.
window.addEventListener('pagehide', () => { if (state === 'play' || state === 'pause') bank(); });

// ---------- HUD ----------

function cooldown(btn, a) {
  const cd = a.max ? a.cd / a.max : 0;
  btn.style.setProperty('--cd', cd.toFixed(3));
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

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.033, (now - last) / 1000);
  last = now;

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
  const shown = state === 'play' || state === 'pause' || state === 'over' ? run : still;
  ctx.setTransform(quality(), 0, 0, quality(), 0, 0);
  draw(ctx, shown, view, now / 1000);
  if (state === 'shop') drawDemo(demoCtx, dt, now / 1000);
  requestAnimationFrame(frame);
}

refreshMenu();
aimFlyers();           // before the first show(): every block is still at its resting place
loadAssets();
requestAnimationFrame(frame);
requestAnimationFrame(() => show('menu'));   // one frame later, so the menu slides in rather than pops

// Offline support, only once published: a service worker on localhost would serve stale files while developing.
if ('serviceWorker' in navigator && !['localhost', '127.0.0.1'].includes(location.hostname)) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
