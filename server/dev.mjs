// The server on this computer, without Cloudflare: the same worker.js, its D1 database played by
// Node's own SQLite (node:sqlite, Node 22+), behind a plain HTTP server.
//   node server/dev.mjs [port]         (8787 by default; the data lives in memory, gone when it stops)
import http from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker from './worker.js';

// A D1 look-alike: prepare(sql).bind(...).first() / .all() / .run()
export function memoryD1() {
  const db = new DatabaseSync(':memory:');
  db.exec(readFileSync(new URL('./schema.sql', import.meta.url), 'utf8'));
  return {
    prepare(sql) {
      let args = [];
      const stmt = db.prepare(sql);
      return {
        bind(...a) { args = a; return this; },
        async first() { return stmt.get(...args) ?? null; },
        async all() { return { results: stmt.all(...args) }; },
        async run() { const r = stmt.run(...args); return { meta: { last_row_id: Number(r.lastInsertRowid), changes: r.changes } }; },
      };
    },
  };
}

export function serve(port = 8787) {
  const env = { DB: memoryD1(), ORIGIN: '*' };
  const server = http.createServer(async (req, res) => {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const request = new Request(`http://localhost:${port}${req.url}`, {
      method: req.method, headers: req.headers, body: ['GET', 'HEAD'].includes(req.method) ? undefined : Buffer.concat(chunks),
    });
    const out = await worker.fetch(request, env);
    res.writeHead(out.status, Object.fromEntries(out.headers));
    res.end(Buffer.from(await out.arrayBuffer()));
  });
  return new Promise((ok) => server.listen(port, '127.0.0.1', () => ok(server)));
}

if (import.meta.url === `file://${process.argv[1].replace(/\\/g, '/')}` || process.argv[1].endsWith('dev.mjs')) {
  const port = Number(process.argv[2]) || 8787;
  serve(port).then(() => console.log(`Jungle Loop server on http://127.0.0.1:${port}/api/ (memory only)`));
}
