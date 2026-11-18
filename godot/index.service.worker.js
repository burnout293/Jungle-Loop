// The Godot version's trial (godot/) is over: the game is at the main address. This replaces the trial's
// offline cache: it steps aside and reloads, and the page sends to the main address.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    await self.registration.unregister();
    for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url);
  })());
});
