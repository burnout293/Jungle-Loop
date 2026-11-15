// Offline cache. Bump VERSION at each release so players get the new files.
const VERSION = 'jungle-loop-0.11.0';
// The code is fetched up front; images and music are kept as the game asks for them,
// so this list never has to follow the art.
const FILES = ['./', 'index.html', 'style.css', 'icon.svg', 'manifest.webmanifest',
  'js/main.js', 'js/game.js', 'js/render.js', 'js/audio.js', 'js/save.js', 'js/progress.js', 'js/ambient.js', 'js/demo.js'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request, { ignoreSearch: true }).then((hit) => hit || fetch(e.request).then((res) => {
    if (res.ok && new URL(e.request.url).pathname.includes('/assets/')) {
      const copy = res.clone();
      caches.open(VERSION).then((c) => c.put(e.request, copy));
    }
    return res;
  })));
});
