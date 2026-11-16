// Offline cache. Bump VERSION at each release so players get the new files (and VERSION in js/main.js with it).
const VERSION = 'jungle-loop-0.15.0';
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
  // lists anyone may edit (coin patterns, music): the network first, the kept copy only when offline
  if (/\.(txt|json)$/.test(new URL(e.request.url).pathname)) {
    e.respondWith(fetch(e.request).then((res) => { const copy = res.clone(); caches.open(VERSION).then((c) => c.put(e.request, copy)); return res; }).catch(() => caches.match(e.request, { ignoreSearch: true })));
    return;
  }
  e.respondWith(caches.match(e.request, { ignoreSearch: true }).then((hit) => hit || fetch(e.request).then((res) => {
    if (res.ok && new URL(e.request.url).pathname.includes('/assets/')) {
      const copy = res.clone();
      caches.open(VERSION).then((c) => c.put(e.request, copy));
    }
    return res;
  })));
});
