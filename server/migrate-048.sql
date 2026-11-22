-- Jungle Loop 0.48: the race for four and friends taken off. Run once on a database made before 0.48:
--   npx wrangler d1 execute jungle-loop --remote --file=server/migrate-048.sql
-- (schema.sql has it all for a new database.)
ALTER TABLE rooms ADD COLUMN kind TEXT NOT NULL DEFAULT 'coop';
ALTER TABLE signals ADD COLUMN dest TEXT;
CREATE TABLE IF NOT EXISTS members (
  room TEXT NOT NULL,
  player TEXT NOT NULL,
  slot INTEGER NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (room, player)
);
