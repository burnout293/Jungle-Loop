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
CREATE TABLE IF NOT EXISTS rooms (
  code TEXT PRIMARY KEY,             -- four letters, said aloud or typed
  host TEXT NOT NULL,
  guest TEXT,
  seed INTEGER NOT NULL,             -- the road both phones will run
  created INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS signals (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  room TEXT NOT NULL,
  sender TEXT NOT NULL,
  data TEXT NOT NULL,                -- a WebRTC offer, answer or ICE candidate
  at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS signals_room ON signals (room, seq);
CREATE TABLE IF NOT EXISTS invites (
  guest TEXT NOT NULL,               -- the friend invited
  host TEXT NOT NULL,                -- who invites, into his room
  room TEXT NOT NULL,
  at INTEGER NOT NULL,               -- it waits two minutes
  PRIMARY KEY (guest, host)
);
