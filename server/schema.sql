-- Jungle Loop's server database (Cloudflare D1, SQLite). Load it once:
--   npx wrangler d1 execute jungle-loop --remote --file=server/schema.sql
CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,         -- the friend code, PEPI-XXXX
  name TEXT NOT NULL,                -- a pseudonym, 16 characters at most
  secret_hash TEXT NOT NULL,         -- SHA-256 of the secret only the player's device holds
  created INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS scores (
  player TEXT NOT NULL,
  mode TEXT NOT NULL,                -- story | endless
  best INTEGER NOT NULL,
  week TEXT NOT NULL,                -- the Monday (UTC) the weekly best belongs to
  week_best INTEGER NOT NULL,
  PRIMARY KEY (player, mode)
);
CREATE TABLE IF NOT EXISTS friends (
  a TEXT NOT NULL,
  b TEXT NOT NULL,
  since INTEGER NOT NULL,
  PRIMARY KEY (a, b)
);
CREATE TABLE IF NOT EXISTS requests (
  asker TEXT NOT NULL,               -- 0.57: who asked to be friends
  target TEXT NOT NULL,              -- ... with whom (he accepts or refuses)
  at INTEGER NOT NULL,
  PRIMARY KEY (asker, target)
);
CREATE TABLE IF NOT EXISTS rooms (
  code TEXT PRIMARY KEY,             -- four letters, said aloud or typed
  host TEXT NOT NULL,
  guest TEXT,
  seed INTEGER NOT NULL,             -- the road both phones will run
  created INTEGER NOT NULL,
  kind TEXT NOT NULL DEFAULT 'coop'  -- coop (two phones) | race (0.48: the host and three more, see members)
);
CREATE TABLE IF NOT EXISTS signals (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  room TEXT NOT NULL,
  sender TEXT NOT NULL,
  data TEXT NOT NULL,                -- a WebRTC offer, answer or ICE candidate
  at INTEGER NOT NULL,
  dest TEXT                          -- whom it is for (a race); NULL: the other one of the two
);
CREATE INDEX IF NOT EXISTS signals_room ON signals (room, seq);
CREATE TABLE IF NOT EXISTS invites (
  guest TEXT NOT NULL,               -- the friend invited
  host TEXT NOT NULL,                -- who invites, into his room
  room TEXT NOT NULL,
  at INTEGER NOT NULL,               -- it waits two minutes
  PRIMARY KEY (guest, host)
);
CREATE TABLE IF NOT EXISTS members (
  room TEXT NOT NULL,                -- a race room's guests (0.48)
  player TEXT NOT NULL,
  slot INTEGER NOT NULL,             -- 1 to 3 (the host is 0)
  at INTEGER NOT NULL,
  PRIMARY KEY (room, player)
);
-- 0.58: the style of a player's record board, as his friends see it (a cosmetic id; '' the wooden one)
CREATE TABLE IF NOT EXISTS looks (
  player TEXT PRIMARY KEY,
  sign TEXT NOT NULL DEFAULT ''
);
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
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- 0.68: the site's form (retours.html): no identity, a pseudonym typed in
  pseudo TEXT NOT NULL,
  version TEXT NOT NULL,
  os TEXT NOT NULL,
  bug TEXT NOT NULL,
  idea TEXT NOT NULL,
  level INTEGER NOT NULL,            -- 0 on s'en fout, 1 un peu chiant, 2 relou, 3 bloquant
  ip TEXT NOT NULL,                  -- a hash of the address salted with the day (5 an hour at most)
  at INTEGER NOT NULL
);
