-- 0.68: the site's feedback form (retours.html).
--   npx --yes wrangler@4 d1 execute jungle-loop --remote --file=migrate-068.sql
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
