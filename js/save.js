// Save data, shop catalogue, export / import.

import { KINDS, MAX_ACTIVE, fill, levelInfo } from './progress.js';

// "?bac" in the address plays on a separate, throw-away save: for trying things without touching the real one.
const KEY = 'jungle-loop-save-v1' + (new URLSearchParams(location.search).has('bac') ? '-bac' : '');
const PREFIX = 'JL1.';

// The shop's catalogue. The ones to equip are called « Équipements » in the game, the others « Pouvoirs ».
// costs[n] = price of level n+1. `needs` = upgrade required first. `icon` = assets/img/ico-<icon>.png.
// `unlock` = the player's level from which it can be bought (what was bought before stays).
// Two families. Upgrades are chosen for each run: only three can be equipped. Powers (`power: true`)
// are bought once and then on without taking a slot, unless the player switches them off (save.powersOff).
export const UPGRADES = [
  { id: 'doubleJump', unlock: 2, icon: 'jump', kind: 'passif', name: 'Double saut', desc: 'Un second saut en l\'air.', costs: [480] },
  { id: 'spring', unlock: 3, icon: 'spring', kind: 'passif', name: 'Ressort', desc: 'Saute plus haut.', costs: [1000, 2400] },
  { id: 'magnet', unlock: 2, icon: 'magnet', kind: 'passif', name: 'Aimant', desc: 'Attire les pièces proches.', costs: [600, 1600, 3600] },
  { id: 'lucky', unlock: 4, icon: 'lucky', kind: 'passif', name: 'Trèfle', desc: 'Avec Gemmes dispersées, les gemmes apparaissent plus souvent.', costs: [1200, 3200] },
  { id: 'scatter', unlock: 6, icon: 'gems', kind: 'passif', name: 'Gemmes dispersées', desc: 'De temps en temps, une gemme prend la place d\'une pièce. Jaune : 5 pièces, rouge : 10, bleue : 20.', costs: [2000, 4800, 10000] },
  { id: 'breaker', unlock: 3, icon: 'break', kind: 'passif', name: 'Brise-tout', desc: 'Les caisses, jarres et tonneaux du décor volent en éclats sur ton passage et lâchent 4 pièces.', costs: [1400] },
  { id: 'heart', unlock: 7, icon: 'heart', kind: 'passif', name: 'Cœur en plus', desc: 'Un second cœur : le premier coup ne t\'arrête plus.', costs: [3600] },
  { id: 'drunk', unlock: 5, icon: 'drunk', kind: 'passif', name: 'Faune alcoolisée', desc: 'De rares créatures deviennent éthérées : pâles et titubantes, elles ne font aucun dégât.', costs: [1600, 3600, 7200] },
  { id: 'nature', unlock: 4, icon: 'nature', kind: 'passif', name: 'Ami de la nature', desc: 'Les montures, rares, se montrent un peu plus souvent.', costs: [1200, 2800, 6000] },
  { id: 'jammer', unlock: 8, icon: 'jammer', kind: 'passif', name: 'Gros sac à dos', desc: 'Pépito a prévu un sac plus grand pour la relique. Ça réduira peut-être ses effets… ou pas.', costs: [2400] },
  { id: 'dash', unlock: 5, icon: 'dash', kind: 'actif', name: 'Ruée', desc: 'Fonce, invincible, en pulvérisant tout. Recharge plus vite à chaque niveau.', costs: [1200, 2800, 5600] },
  { id: 'slow', unlock: 7, icon: 'slow', kind: 'actif', name: 'Sablier', desc: 'Ralentit le temps quelques secondes.', costs: [1800, 4000] },
  { id: 'lastLeap', unlock: 6, icon: 'leap', kind: 'passif', name: 'Dernier élan', desc: 'Au dernier cœur perdu, tu rebondis encore pour gagner quelques mètres.', costs: [1600, 3600, 7200] },
  { id: 'flight', unlock: 10, icon: 'flight', kind: 'passif', power: true, name: 'Vol', desc: 'En l\'air, chaque appui te fait remonter d\'un coup d\'hélice. Relâche : tu retombes.', costs: [4800] },
  { id: 'sprint', unlock: 8, icon: 'shoes', kind: 'passif', power: true, name: 'Sprint', desc: 'Cours plus vite dès le départ, les jambes en tourbillon.', costs: [4000] },
  { id: 'sphere', unlock: 10, icon: 'sphere', kind: 'passif', power: true, name: 'Sphère', desc: 'Roule en boule dans les endroits exigus, troncs creux et galeries : il n\'y a que des trésors là-dedans.', costs: [6000] },
  { id: 'rewind', unlock: 12, icon: 'rewind', kind: 'passif', name: 'Rembobinage', desc: 'Une fois par course, la relique annule ta chute.', costs: [10000] },
];

export const QUALITIES = ['auto', 'smooth', 'sharp'];   // how the picture is drawn, see resize in main.js
export const MAX_EQUIPPED = 3;   // owning is not enough: only three upgrades go on a run
export const isPower = (id) => !!UPGRADES.find((u) => u.id === id && u.power);

function blank() {
  // best: the record of the Histoire mode (the older saves knew only that one); bestEndless: the Run illimitée's
  return { v: 1, coins: 0, best: 0, bestEndless: 0, mode: 'story', loops: 0, upgrades: {}, musicVol: 7, sfxVol: 7, pixelFont: true, dangerRim: false, alertShift: false, showFps: false, quality: 'auto', full: true, seenIntro: false,
    equipped: [], powersOff: [], xp: 0, quests: [], questsDone: 0, lastQuest: '' };
}

// Keeps only known fields with sane types: an imported code is untrusted text.
function sanitize(raw) {
  const s = blank();
  if (!raw || typeof raw !== 'object') { fill(s); return s; }
  const int = (x) => (Number.isFinite(x) && x > 0 ? Math.floor(x) : 0);
  s.coins = int(raw.coins);
  s.best = int(raw.best);
  s.bestEndless = int(raw.bestEndless);
  s.mode = raw.mode === 'endless' ? 'endless' : 'story';
  s.loops = int(raw.loops);
  // volumes go from 0 (off) to 10; older saves only knew on and off
  const vol = (v, on) => (Number.isInteger(v) && v >= 0 && v <= 10 ? v : on === false ? 0 : 7);
  s.musicVol = vol(raw.musicVol, raw.music);
  s.sfxVol = vol(raw.sfxVol, raw.sfx);
  s.pixelFont = raw.pixelFont !== false;
  s.dangerRim = raw.dangerRim === true;
  s.alertShift = raw.alertShift === true;
  s.showFps = raw.showFps === true;
  s.quality = QUALITIES.includes(raw.quality) ? raw.quality : 'auto';
  s.full = raw.full !== false;
  s.seenIntro = !!raw.seenIntro;
  for (const u of UPGRADES) {
    const lvl = int(raw.upgrades && raw.upgrades[u.id]);
    if (lvl) s.upgrades[u.id] = Math.min(lvl, u.costs.length);
  }
  // saves from before the three-slot rule: the first three owned upgrades are put on
  const wanted = Array.isArray(raw.equipped) ? raw.equipped : Object.keys(s.upgrades);
  for (const id of wanted) if (s.upgrades[id] && !isPower(id) && !s.equipped.includes(id) && s.equipped.length < MAX_EQUIPPED) s.equipped.push(id);
  for (const id of Array.isArray(raw.powersOff) ? raw.powersOff : []) if (isPower(id) && !s.powersOff.includes(id)) s.powersOff.push(id);
  s.xp = Number.isFinite(raw.xp) && raw.xp > 0 ? raw.xp : 0;
  s.questsDone = int(raw.questsDone);
  if (typeof raw.lastQuest === 'string' && KINDS[raw.lastQuest]) s.lastQuest = raw.lastQuest;
  for (const q of Array.isArray(raw.quests) ? raw.quests.slice(0, MAX_ACTIVE) : []) {
    if (!q || !KINDS[q.k] || s.quests.some((x) => x.k === q.k) || !int(q.goal)) continue;
    s.quests.push({ k: q.k, goal: int(q.goal), p: Math.min(int(q.goal), Number.isFinite(q.p) && q.p > 0 ? q.p : 0), reward: int(q.reward), xp: int(q.xp) || 40 });
  }
  fill(s);
  return s;
}

export function load() {
  try { return sanitize(JSON.parse(localStorage.getItem(KEY))); } catch { return sanitize(null); }
}

export function store(save) {
  try { localStorage.setItem(KEY, JSON.stringify(save)); } catch { /* private mode: play without saving */ }
}

export function reset() {
  try { localStorage.removeItem(KEY); } catch { /* nothing to remove */ }
  return sanitize(null);
}

export function exportCode(save) {
  const bytes = new TextEncoder().encode(JSON.stringify(save));
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return PREFIX + btoa(bin);
}

// Returns a save, or null when the code is not valid.
export function importCode(code) {
  try {
    const txt = String(code).trim();
    if (!txt.startsWith(PREFIX)) return null;
    const bin = atob(txt.slice(PREFIX.length));
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
    const raw = JSON.parse(new TextDecoder().decode(bytes));
    if (!raw || raw.v !== 1) return null;
    return sanitize(raw);
  } catch { return null; }
}

export function level(save, id) { return save.upgrades[id] || 0; }

export const unlocked = (save, u) => !u.unlock || levelInfo(save.xp).level >= u.unlock || level(save, u.id) > 0;

export function nextCost(save, u) {
  const lvl = level(save, u.id);
  return lvl < u.costs.length ? u.costs[lvl] : null;
}

export function buy(save, u) {
  const cost = nextCost(save, u);
  if (cost === null || save.coins < cost) return false;
  if (u.needs && !level(save, u.needs)) return false;
  if (!unlocked(save, u)) return false;
  save.coins -= cost;
  save.upgrades[u.id] = level(save, u.id) + 1;
  if (!u.power && !save.equipped.includes(u.id) && save.equipped.length < MAX_EQUIPPED) save.equipped.push(u.id);
  store(save);
  return true;
}

// What a run starts with: the equipped upgrades, at the level owned, and every power bought.
export function loadout(save) {
  const up = {};
  for (const id of save.equipped) up[id] = save.upgrades[id];
  for (const u of UPGRADES) if (u.power && save.upgrades[u.id] && !save.powersOff.includes(u.id)) up[u.id] = save.upgrades[u.id];
  return up;
}

// Switches an owned power off, or back on.
export function togglePower(save, id) {
  const i = save.powersOff.indexOf(id);
  if (i >= 0) save.powersOff.splice(i, 1); else save.powersOff.push(id);
  store(save);
}

// Puts an owned upgrade on or takes it off. Returns false when the three slots are taken.
export function toggleEquip(save, id) {
  const i = save.equipped.indexOf(id);
  if (isPower(id)) return false;
  if (i >= 0) save.equipped.splice(i, 1);
  else if (save.upgrades[id] && save.equipped.length < MAX_EQUIPPED) save.equipped.push(id);
  else return false;
  store(save);
  return true;
}
