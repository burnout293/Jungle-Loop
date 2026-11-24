-- 0.58: the style of each player's record board, as his friends see it on their road. Run once on the live base:
--   npx wrangler d1 execute jungle-loop --remote --file=migrate-058.sql   (from server/)
-- Nothing is changed or removed: one table more.
CREATE TABLE IF NOT EXISTS looks (
  player TEXT PRIMARY KEY,
  sign TEXT NOT NULL DEFAULT ''
);
