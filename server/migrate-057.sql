-- 0.57: friend requests (adding someone asks him first). Run once on the live base:
--   npx wrangler d1 execute jungle-loop --remote --file=server/migrate-057.sql
-- Nothing is changed or removed: one table more.
CREATE TABLE IF NOT EXISTS requests (
  asker TEXT NOT NULL,
  target TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (asker, target)
);
