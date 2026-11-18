// The web version's offline cache is gone: since 18/11/2026 the game at this address is the Godot one
// (index.html, with its own offline cache, index.service.worker.js). Phones that still run the old
// cached web version fetch this file on their next visit: it clears the old copies, steps aside and
// reloads the page, which then comes from the network (the Godot game).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k.startsWith('jungle-loop-')) await caches.delete(k);
    await self.registration.unregister();
    for (const c of await self.clients.matchAll({ type: 'window' })) {
      const path = new URL(c.url).pathname;
      if (path.endsWith('/') || path.endsWith('/index.html')) c.navigate(c.url);   // the game's address only
    }
  })());
});
