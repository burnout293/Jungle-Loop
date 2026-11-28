-- 0.66: feedback and the quick match queue.
--   npx --yes wrangler@4 d1 execute jungle-loop --remote --file=migrate-066.sql
CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- 0.66: what a player sends from the game (Réglages → Envoyer un retour)
  player TEXT NOT NULL,
  version TEXT NOT NULL,
  text TEXT NOT NULL,                -- 600 characters at most
  at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS queue (
  player TEXT PRIMARY KEY,           -- 0.66: « Partie rapide »: a host waiting for players, in his race room
  room TEXT NOT NULL,
  at INTEGER NOT NULL                -- renewed while he waits; forgotten after two minutes
);
