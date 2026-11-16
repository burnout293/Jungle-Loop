// Long-term progress: the player's level and the objectives.
// Both live in the save and are fed with what happened during the last frame of a run.

// ---------- level: one point of experience per metre run, plus what the objectives pay ----------

const LEVEL_BASE = 200, LEVEL_STEP = 150;      // level 1 → 2 takes 200 points, each next level 150 more

export function levelInfo(xp) {
  let level = 1, need = LEVEL_BASE, into = xp;
  while (into >= need) { into -= need; level++; need += LEVEL_STEP; }
  return { level, into: Math.floor(into), need };
}

export const levelReward = (level) => 20 * level;

// Adds experience; returns the levels reached on the way (usually none), their coins already paid.
export function addXp(save, points) {
  const before = levelInfo(save.xp).level;
  save.xp += points;
  const after = levelInfo(save.xp).level, gained = [];
  for (let l = before + 1; l <= after; l++) { save.coins += levelReward(l); gained.push(l); }
  return gained;
}

// ---------- objectives ----------

// stat: which counter feeds it. single: must be done within one run (progress restarts with each run).
// safe: progress restarts when a heart is lost. needs: only offered once one of these skills is owned.
export const KINDS = {
  dist1: { stat: 'dist', single: true, base: 150, step: 75, text: (n) => `Cours ${n} m en une seule course` },
  distT: { stat: 'dist', base: 400, step: 250, text: (n) => `Cours ${n} m en tout` },
  coins1: { stat: 'coins', single: true, base: 25, step: 15, text: (n) => `Ramasse ${n} pièces en une seule course` },
  coinsT: { stat: 'coins', base: 80, step: 50, text: (n) => `Ramasse ${n} pièces en tout` },
  gems: { stat: 'gems', base: 2, step: 1, text: (n) => `Trouve ${n} gemmes` },
  jumps: { stat: 'jumps', base: 30, step: 20, text: (n) => `Saute ${n} fois` },
  plats: { stat: 'plats', base: 3, step: 2, text: (n) => `Atterris sur ${n} plateformes` },
  safe: { stat: 'dist', single: true, safe: true, base: 80, step: 50, text: (n) => `Cours ${n} m sans te faire toucher` },
  runs: { stat: 'runs', base: 3, step: 1, text: (n) => `Lance ${n} courses` },
  shrooms: { stat: 'shrooms', base: 5, step: 3, text: (n) => `Frôle ${n} champignons bleus` },
  monkeys: { stat: 'monkeys', single: true, base: 2, step: 1, text: (n) => `Salue ${n} singes en une seule course` },
  breaks: { stat: 'breaks', base: 4, step: 3, needs: ['breaker', 'dash'], text: (n) => `Casse ${n} obstacles` },
  mounts: { stat: 'mounts', base: 1, step: 1, text: (n) => (n > 1 ? `Chevauche ${n} montures` : 'Chevauche une monture') },
  dodges: { stat: 'dodges', base: 2, step: 1, text: (n) => `Esquive ${n} nuées` },
};

export const MAX_ACTIVE = 3;
const MAX_TIER = 12;

export const questText = (q) => KINDS[q.k].text(q.goal);

// Keeps three objectives going: each new one is of a kind not already on the list.
// They get harder, and pay more (coins and experience), as the player completes them.
export function fill(save) {
  while (save.quests.length < MAX_ACTIVE) {
    const tier = Math.min(MAX_TIER, Math.floor(save.questsDone / 3));
    const free = Object.keys(KINDS).filter((k) =>
      !save.quests.some((q) => q.k === k) && k !== save.lastQuest
      && (!KINDS[k].needs || KINDS[k].needs.some((id) => save.upgrades[id])));
    const k = free[Math.floor(Math.random() * free.length)];
    save.quests.push({ k, goal: KINDS[k].base + KINDS[k].step * tier, p: 0, reward: 30 + 15 * tier, xp: 40 + 20 * tier });
  }
}

export function startRun(save) {
  for (const q of save.quests) if (KINDS[q.k].single) q.p = 0;
}

// `stats` holds what just happened: { dist, coins, gems, jumps, plats, breaks, runs, hurt }.
// Returns the objectives completed by it; each one is replaced at once and its coins are paid
// (the caller adds their experience, to announce any level gained).
export function feed(save, stats) {
  const done = [];
  for (const q of save.quests) {
    const kind = KINDS[q.k];
    if (stats.hurt && kind.safe) q.p = 0;
    q.p = Math.min(q.goal, q.p + (stats[kind.stat] || 0));
    if (q.p >= q.goal) done.push(q);
  }
  for (const q of done) {
    save.quests.splice(save.quests.indexOf(q), 1);
    save.coins += q.reward; save.questsDone++; save.lastQuest = q.k;
  }
  if (done.length) fill(save);
  return done;
}
